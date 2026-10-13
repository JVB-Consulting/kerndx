// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Runs data masking. Reads `MaskingRule__mdt` and `MaskingTarget__mdt` to find which rules
 * apply to which fields, hands the string changes to the `UTIL_String` masking helpers, and respects the
 * `MaskingFramework_Enabled` kill switch (the feature flag that turns masking off).
 *
 * Package-internal: the log engine, the web service framework, the async chain framework and the trigger
 * dispatcher call this class to mask records before they are saved. Subscribers that run their own
 * masking use their own kill switch and call the `UTIL_String` helpers directly.
 *
 * **Checking from subscriber Apex whether masking is on.** This class is `public` (not `global`) on
 * purpose, so subscribers cannot reach `UTIL_FrameworkMasker.isMaskingEnabled` across the namespace
 * boundary. The supported check is `kern.UTIL_FeatureFlag.isEnabled('MaskingFramework_Enabled')`,
 * which reads the same feature flag the masker reads. `UTIL_FeatureFlag` is `global`, so the call works
 * from subscriber Apex, anonymous Apex, and `@IsTest` classes. Use it when a subscriber test or load
 * script should skip assertions that depend on masking while masking is off, or when a health check
 * page should show whether masking is on.
 *
 * @see UTIL_String
 * @see UTIL_FeatureFlag
 * @see MaskingRule__mdt
 * @see MaskingTarget__mdt
 * @see SEL_MaskingRule
 * @see SEL_MaskingTarget
 * @see UTIL_FrameworkMasker_TEST
 *
 * @author Jason van Beukering
 *
 * @group Data Masking
 *
 * @date April 2026, October 2026
 *
 * @example
 * ```apex
 * // From subscriber Apex or anonymous Apex: check whether masking is currently on
 * if(kern.UTIL_FeatureFlag.isEnabled('MaskingFramework_Enabled'))
 * {
 *     // Masking is on, so assertions about masked output are valid
 * }
 * ```
 */
@SuppressWarnings('PMD.CognitiveComplexity,PMD.CyclomaticComplexity,PMD.ExcessiveClassLength,PMD.NcssTypeCount')
public inherited sharing class UTIL_FrameworkMasker
{
	/**
	 * @description DeveloperName of the kill-switch feature flag. Follows the same pattern as
	 * `API_Inbound.FLAG_DISABLE_ALL_INBOUND_APIS`: the constant is internal, and callers check
	 * `isMaskingEnabled`.
	 */
	@TestVisible
	private static final String FLAG_MASKING_FRAMEWORK_ENABLED = 'MaskingFramework_Enabled';

	/**
	 * @description Fixed value written to a field when its masking rule throws and the rule's
	 * `FailureAction__c = WriteFailureMarker`. Short enough to fit in most text fields, and clearly
	 * not real data to any admin who looks at the record.
	 */
	public static final String FAILURE_MARKER = '[MASKING_FAILURE]';

	/**
	 * @description Namespace-safe API name for `LogEntry__c`. Used to stop LOG_Builder warnings when
	 * a masking target on LogEntry fails. Otherwise each warning would publish a new LogEntryEvent,
	 * which saves a new LogEntry__c, which runs the trigger and the masker, which fails and warns
	 * again, in an endless loop across transactions.
	 */
	@TestVisible
	private static final String LOG_ENTRY_OBJECT_NAME = UTIL_SObjectDescribe.getObjectNameFromType(LogEntry__c.SObjectType);

	/**
	 * @description Namespace-safe API name for `LogEntryEvent__e`. Used with `LOG_ENTRY_OBJECT_NAME`
	 * in the check that stops warnings, so the masker can mask events without publishing more events
	 * in a loop.
	 */
	@TestVisible
	private static final String LOG_ENTRY_EVENT_OBJECT_NAME = UTIL_SObjectDescribe.getObjectNameFromType(LogEntryEvent__e.SObjectType);

	/**
	 * @description Fields the framework compares for equality to keep its own data correct. A wildcard target (one
	 * with a blank field) never covers them. The chain engine's run key is a token that every process running a
	 * chain run holds a copy of. If masking rewrote the stored copy (the key is random, and about once in several
	 * thousand keys its digit groups look like a payment card), every process of that run would stop without an
	 * error. The run's current job id is what the watchdog reads to tell a live process from a dead one, and a
	 * rewritten id looks dead. Nothing in these fields needs to be hidden. A target that names one of them
	 * explicitly is the administrator's deliberate choice and is applied, as for an identifier field.
	 */
	private static final Set<SObjectField> FRAMEWORK_INTEGRITY_FIELDS = new Set<SObjectField> {AsyncChainExecution__c.RunKey__c, AsyncChainExecution__c.CurrentJobId__c};

	/**
	 * @description DeveloperNames of the rules that have thrown at least once in this transaction and
	 * are not set to block DML. These rules are left out of later `FieldMasker.mask` calls in the same
	 * transaction: a broken rule in warning mode fails once, then is skipped for the other records in
	 * a bulk trigger batch. A rule set to BlockDml never joins this set, because skipping it would let a
	 * later masking call save the value without masking it. Statics reset between transactions, so the
	 * rule runs again after an admin fixes it.
	 */
	@TestVisible
	private static final Set<String> invalidatedRuleDeveloperNames
	{
		get
		{
			if(invalidatedRuleDeveloperNames == null)
			{
				invalidatedRuleDeveloperNames = new Set<String>();
			}
			return invalidatedRuleDeveloperNames;
		}
		set;
	}

	/**
	 * @description Reports whether masking is switched on by its kill switch. The package's own callers
	 * (LOG_Engine, API_Base, UTIL_AsyncChain, the trigger dispatcher) mask only when this is true. Read
	 * once per transaction, on first use, so a transaction that never reads it pays no feature-flag
	 * lookup.
	 *
	 * @example
	 * ```apex
	 * if(UTIL_FrameworkMasker.isMaskingEnabled)
	 * {
	 *     UTIL_FrameworkMasker.forRecords(Trigger.new).apply();
	 * }
	 * ```
	 */
	public static Boolean isMaskingEnabled
	{
		get
		{
			if(isMaskingEnabled == null)
			{
				isMaskingEnabled = UTIL_FeatureFlag.isEnabled(FLAG_MASKING_FRAMEWORK_ENABLED);
			}
			return isMaskingEnabled;
		}
		private set;
	}

	/**
	 * @description Cache, for one transaction, of active MaskingTarget records keyed by SObjectType.
	 * Filled on first read, so a transaction that never calls the masker pays nothing.
	 */
	private static final Map<SObjectType, List<MaskingTarget__mdt>> cachedTargets
	{
		get
		{
			if(cachedTargets == null)
			{
				cachedTargets = new Map<SObjectType, List<MaskingTarget__mdt>>();
			}
			return cachedTargets;
		}
		set;
	}

	/**
	 * @description Cache, for one transaction, of the text fields that Apex can write on each
	 * SObjectType. Used to turn a wildcard MaskingTarget record (blank Field__c) into the real list
	 * of fields to mask. Keeps only field types that can hold text (Text / Text Area / Long Text
	 * Area / URL / Email / Phone / Encrypted) and that Apex can write to (no formulas, read-only or
	 * system fields).
	 */
	private static final Map<SObjectType, List<SObjectField>> cachedUpdateableTextFields
	{
		get
		{
			if(cachedUpdateableTextFields == null)
			{
				cachedUpdateableTextFields = new Map<SObjectType, List<SObjectField>>();
			}
			return cachedUpdateableTextFields;
		}
		set;
	}

	/**
	 * @description Cache, for one transaction, of batch plans keyed by `sObjectType|callerClassName`.
	 * A batch plan holds the list of qualified fields to mask, with each field's targets already split
	 * into JsonKey and other modes. So bulk masking of many records of the same SObjectType, for the
	 * same caller, works out the targets and fields once per transaction instead of once per record.
	 */
	@TestVisible
	private static final Map<String, BatchPlan> cachedBatchPlans
	{
		get
		{
			if(cachedBatchPlans == null)
			{
				cachedBatchPlans = new Map<String, BatchPlan>();
			}
			return cachedBatchPlans;
		}
		set;
	}

	/**
	 * @description Cache, built on first use and kept for the transaction, that maps the names of the
	 * text DisplayTypes (STRING, TEXTAREA, URL, EMAIL, PHONE, ENCRYPTEDSTRING) to their
	 * `System.DisplayType` enum values. Built from the enum itself with `.name()`, so a platform rename
	 * shows as a compile error instead of a string that quietly stops matching. Built only when needed,
	 * so a transaction that never masks does not pay to build it, and the debug log does not fill with
	 * six `VARIABLE_ASSIGNMENT` entries when the class loads.
	 */
	@TestVisible
	private static Map<String, DisplayType> textShapedDisplayTypesByName;

	/**
	 * @description Returns the cached list of active masking targets for an SObjectType, loading it
	 * from SEL_MaskingTarget on the first request.
	 *
	 * @param sObjectType The object whose targets to retrieve
	 *
	 * @return All active MaskingTarget records for this type, empty list if none are configured
	 */
	private static List<MaskingTarget__mdt> getTargetsFor(SObjectType sObjectType)
	{
		if(!cachedTargets.containsKey(sObjectType))
		{
			cachedTargets.put(sObjectType, sortByRuleOrder(suppressSupersededTargets(removeDuplicateTargets(new SEL_MaskingTarget().findActiveForSObjectType(sObjectType)))));
		}

		return cachedTargets.get(sObjectType);
	}

	/**
	 * @description Cache, for one transaction, of the supersession links: each qualified successor name
	 * (a newer rule that replaces an older one) mapped to the qualified names of its predecessors. Every
	 * pair has passed every supersession check. Built once per request, so fingerprints are hashed here
	 * and not each time the target cache is built.
	 */
	private static final Map<String, Set<String>> cachedSupersessionLinks
	{
		get
		{
			if(cachedSupersessionLinks == null)
			{
				cachedSupersessionLinks = SEL_MaskingRule.findSupersessionLinks(new SEL_MaskingTarget().getAllRulesById().values());
			}
			return cachedSupersessionLinks;
		}
		set;
	}

	/**
	 * @description Drops a target of a predecessor rule when one of that rule's own qualifying successors
	 * has an active target on the same field and caller. Each predecessor and successor pair is judged on
	 * its own, by design. A field covered only by the successor of another pair, or by a tuned successor
	 * that failed its own checks, never drops this predecessor. A subscriber target on a field the
	 * successor does not also cover is never dropped. Works on the result of findActiveForSObjectType, so
	 * "active" always means the target is active AND its rule is active. Admins see which targets are
	 * dropped on the advisor pages, which use the same checks.
	 *
	 * @param targets The active targets for one SObjectType, without duplicates
	 *
	 * @return The targets, without the dropped predecessor targets
	 */
	private static List<MaskingTarget__mdt> suppressSupersededTargets(List<MaskingTarget__mdt> targets)
	{
		if(cachedSupersessionLinks.isEmpty())
		{
			return targets;
		}

		Map<String, Set<String>> surfaceKeysByPredecessorName = new Map<String, Set<String>>();

		for(MaskingTarget__mdt target : targets)
		{
			Set<String> predecessorNames = cachedSupersessionLinks.get(SEL_MaskingRule.resolveQualifiedDeveloperName(ruleFor(target)));

			if(predecessorNames == null)
			{
				continue;
			}

			for(String predecessorName : predecessorNames)
			{
				if(!surfaceKeysByPredecessorName.containsKey(predecessorName))
				{
					surfaceKeysByPredecessorName.put(predecessorName, new Set<String>());
				}
				surfaceKeysByPredecessorName.get(predecessorName).add(buildSurfaceKey(target));
			}
		}

		List<MaskingTarget__mdt> kept = new List<MaskingTarget__mdt>();

		for(MaskingTarget__mdt target : targets)
		{
			Set<String> mirroredSurfaceKeys = surfaceKeysByPredecessorName.get(SEL_MaskingRule.resolveQualifiedDeveloperName(ruleFor(target)));

			if(mirroredSurfaceKeys == null || !mirroredSurfaceKeys.contains(buildSurfaceKey(target)))
			{
				kept.add(target);
			}
		}

		return kept;
	}

	/**
	 * @description Combined field|caller key used to match successors to predecessors. A successor
	 * target drops a predecessor target only when both cover exactly the same field and caller.
	 * Targets are already limited to one SObjectType when they are keyed, so wildcard (blank-field)
	 * targets of different objects can never clash.
	 *
	 * @param target The target to key
	 *
	 * @return The combined field|caller key
	 */
	private static String buildSurfaceKey(MaskingTarget__mdt target)
	{
		return (resolveQualifiedFieldName(target) ?? UTIL_String.EMPTY) + '|' + (target.CallerClass__c ?? UTIL_String.EMPTY);
	}

	/**
	 * @description Finds a target's parent `MaskingRule__mdt`. The production and TST_Mock paths fill
	 * `SEL_MaskingTarget.getRuleById`, which is checked first. Falls back to the target's own `Rule__r`
	 * child only when that rule cache has no entry. The fallback exists so unit tests that build a
	 * `MaskingTarget__mdt` in memory and set `target.Rule__r = rule` directly (without TST_Mock) keep
	 * working. In production the rule cache is filled by Id, and `target.Rule__r` is never used, which
	 * avoids the managed-package problem of custom fields missing from nested child records.
	 *
	 * @param target The target whose parent rule to resolve.
	 *
	 * @return The rule with every field filled, or `null` if neither source has it.
	 */
	private static MaskingRule__mdt ruleFor(MaskingTarget__mdt target)
	{
		return SEL_MaskingTarget.getRuleById(target.Rule__c) ?? target.Rule__r;
	}

	/**
	 * @description Returns the writable text fields on an SObjectType that a wildcard MaskingTarget
	 * record (blank Field__c) covers. Leaves out formula, calculated and read-only fields, so
	 * `record.put()` never throws while masking. Cached per SObjectType, so describe calls happen once
	 * per transaction.
	 *
	 * Platform events (`__e` objects) report every field as `isUpdateable() == false`, because events
	 * can only be inserted. But their fields CAN be written with `put` while the event is built. So for
	 * a platform event the check uses `isCreateable()` instead, and wildcard masking still covers event
	 * fields.
	 *
	 * Fields that identify the record (unique keys and external ids) are never covered by a wildcard,
	 * even when they hold text. Masking rewrites the value it matches. On a key, that destroys the key.
	 * On a unique index, the next record whose key masks to the same fixed value fails to insert (a
	 * chain correlation id that carries a long order number looks like a payment card to the shipped
	 * card rule, and `AsyncChainExecution__c.CorrelationId__c` is unique). A target that names such a
	 * field explicitly is the administrator's deliberate choice and is applied; a wildcard must not do
	 * it by accident. The fields the framework needs to keep its own data correct are skipped the same
	 * way (`isExcludedFromWildcard`).
	 *
	 * @param sObjectType The SObjectType to enumerate
	 *
	 * @return The list of SObjectField tokens for writable Text/TextArea/LongTextArea/URL/Email/Phone/Encrypted fields that are neither unique nor external ids
	 */
	@TestVisible
	private static List<SObjectField> getUpdateableTextFields(SObjectType sObjectType)
	{
		if(cachedUpdateableTextFields.containsKey(sObjectType))
		{
			return cachedUpdateableTextFields.get(sObjectType);
		}

		List<SObjectField> fields = new List<SObjectField>();
		Map<String, SObjectField> fieldMap = UTIL_SObjectDescribe.getObjectFieldMap(sObjectType);
		Boolean isPlatformEvent = UTIL_SObjectDescribe.getObjectNameFromType(sObjectType).endsWith(UTIL_SObjectDescribe.PLATFORM_EVENT_SUFFIX);

		for(SObjectField field : fieldMap.values())
		{
			DescribeFieldResult describe = UTIL_SObjectDescribe.getCachedFieldDescribe(field);

			if(!isPlatformEvent && !describe.isUpdateable())
			{
				continue;
			}

			if(isPlatformEvent && !describe.isCreateable())
			{
				continue;
			}

			if(isExcludedFromWildcard(field))
			{
				continue;
			}

			DisplayType fieldType = describe.getType();

			if
			(
					fieldType == DisplayType.STRING
					|| fieldType == DisplayType.TEXTAREA
					|| fieldType == DisplayType.URL
					|| fieldType == DisplayType.EMAIL
					|| fieldType == DisplayType.PHONE
					|| fieldType == DisplayType.ENCRYPTEDSTRING
			)
			{
				fields.add(field);
			}
		}

		cachedUpdateableTextFields.put(sObjectType, fields);
		return fields;
	}

	/**
	 * @description Whether a wildcard target must skip the field: an identifier (a unique key or an external
	 * id, `isIdentifierField`) or one of the fields the framework needs to keep its own data correct. Every
	 * wildcard decision uses this one check (expanding the fields of a record, allowing a wildcard on one
	 * field, and the coverage the advisor reports), so no page can show or apply wildcard masking that
	 * record masking refuses. Safe with null: a field that cannot be found is not skipped.
	 *
	 * @param field The field token to test; may be null.
	 *
	 * @return `true` when a wildcard must not touch the field.
	 */
	public static Boolean isExcludedFromWildcard(SObjectField field)
	{
		return field != null && (FRAMEWORK_INTEGRITY_FIELDS.contains(field) || isIdentifierField(field));
	}

	/**
	 * @description Whether a field identifies its record: a unique key or an external id. One of the two
	 * parts of `isExcludedFromWildcard`. Safe with null: a field that cannot be found is not an identifier.
	 *
	 * @param field The field token to test; may be null.
	 *
	 * @return `true` when the field is unique or an external id.
	 */
	public static Boolean isIdentifierField(SObjectField field)
	{
		return field != null && isIdentifierField(UTIL_SObjectDescribe.getCachedFieldDescribe(field));
	}

	/**
	 * @description The describe-level half of `isIdentifierField(SObjectField)`. Both kinds of field
	 * are left out on purpose. Rewriting a unique key makes the next record fail with a clear error
	 * (DUPLICATE_VALUE on the index). Rewriting an external id that is not unique fails without any
	 * error: later upserts on the real key miss, or update the wrong record, and integrations lose the
	 * link between records.
	 *
	 * @param describe The field describe to test.
	 *
	 * @return `true` when the field is unique or an external id.
	 */
	@TestVisible
	private static Boolean isIdentifierField(DescribeFieldResult describe)
	{
		return describe.isUnique() || describe.isExternalId();
	}

	/**
	 * @description Whether the field that a masking call names by qualified name is one a wildcard must
	 * skip. `selectApplicableTargets` works with the `Object.Field` text; this method turns that text
	 * into a field token and runs the check above.
	 *
	 * @param sObjectType The SObjectType the qualified name belongs to.
	 * @param qualifiedFieldName The `Object.Field` qualified name.
	 *
	 * @return `true` when the named field resolves and is excluded from wildcard masking.
	 */
	private static Boolean isExcludedQualifiedField(SObjectType sObjectType, String qualifiedFieldName)
	{
		return isExcludedFromWildcard(UTIL_SObjectDescribe.getDescribe(sObjectType).getField(qualifiedFieldName.substringAfter(UTIL_String.DOT)));
	}

	/**
	 * @description Sorts masking targets by the parent rule's `Order__c`, lowest first, so they always
	 * run in the same order. Sorted in Apex and not with SOQL ORDER BY, because SOQL ORDER BY does not
	 * support parent fields through a CMDT MetadataRelationship.
	 *
	 * @param targets The target list, without duplicates
	 *
	 * @return The same targets sorted by Rule__r.Order__c ASC
	 */
	private static List<MaskingTarget__mdt> sortByRuleOrder(List<MaskingTarget__mdt> targets)
	{
		Map<Decimal, List<MaskingTarget__mdt>> bucketByOrder = new Map<Decimal, List<MaskingTarget__mdt>>();

		for(MaskingTarget__mdt target : targets)
		{
			Decimal orderValue = ruleFor(target).Order__c ?? 0;

			if(!bucketByOrder.containsKey(orderValue))
			{
				bucketByOrder.put(orderValue, new List<MaskingTarget__mdt>());
			}

			bucketByOrder.get(orderValue).add(target);
		}

		List<Decimal> sortedOrders = new List<Decimal>(bucketByOrder.keySet());
		sortedOrders.sort();

		List<MaskingTarget__mdt> sorted = new List<MaskingTarget__mdt>();

		for(Decimal orderValue : sortedOrders)
		{
			sorted.addAll(bucketByOrder.get(orderValue));
		}

		return sorted;
	}

	/**
	 * @description Removes duplicate MaskingTarget records that share the same
	 * `QualifiedRuleDeveloperName | Field | CallerClass` key. If an admin (or subscriber) sets up two
	 * targets that do the same thing, only the first is kept, so the audit output never shows the same
	 * rule matching twice. The rule name is namespace-qualified, so a packaged rule and an org-local
	 * copy that share a DeveloperName are different targets and never removed as duplicates.
	 *
	 * @param targets The raw list from the selector
	 *
	 * @return A list with duplicates removed; the first one in list order is kept
	 */
	private static List<MaskingTarget__mdt> removeDuplicateTargets(List<MaskingTarget__mdt> targets)
	{
		Map<String, MaskingTarget__mdt> firstTargetByCompositeKey = new Map<String, MaskingTarget__mdt>();

		for(MaskingTarget__mdt target : targets)
		{
			String ruleName = SEL_MaskingRule.resolveQualifiedDeveloperName(ruleFor(target));
			String caller = target.CallerClass__c ?? UTIL_String.EMPTY;
			String compositeKey = ruleName + '|' + resolveQualifiedFieldName(target) + '|' + caller;

			if(!firstTargetByCompositeKey.containsKey(compositeKey))
			{
				firstTargetByCompositeKey.put(compositeKey, target);
			}
		}

		return firstTargetByCompositeKey.values();
	}

	/**
	 * @description Turns a MaskingTarget's Field__c into its fully qualified `ObjectName.FieldName`
	 * form. Real deployed CMDT records return the EntityDefinition/FieldDefinition durable Id in
	 * `Field__c`, so the qualified name has to be built from the related SObjectType__r and Field__r
	 * QualifiedApiName fields. Mocked records (TST_Builder) put the qualified text straight into
	 * `Field__c`, so the fallback to the relationship fields handles both shapes without extra test code.
	 *
	 * @param target The target whose field path to resolve
	 *
	 * @return The qualified field path (e.g. `ApiCall__c.Request__c`)
	 */
	@TestVisible
	private static String resolveQualifiedFieldName(MaskingTarget__mdt target)
	{
		if(target.Field__r != null && target.SObjectType__r != null)
		{
			return target.SObjectType__r.QualifiedApiName + UTIL_String.DOT + target.Field__r.QualifiedApiName;
		}
		return target.Field__c;
	}

	/**
	 * @description Computes the fully qualified `ObjectName.FieldName` string used by
	 * `MaskingTarget__mdt.Field__c` to identify target fields.
	 *
	 * @param field The SObjectField to describe
	 *
	 * @return The qualified field name (e.g. `ApiCall__c.Request__c` or `kern__ApiCall__c.kern__Request__c` in subscriber orgs)
	 */
	private static String getQualifiedFieldName(SObjectField field)
	{
		String objectName = UTIL_SObjectDescribe.getObjectNameFromType(field.getDescribe().getSObjectType());
		return objectName + UTIL_String.DOT + UTIL_SObjectDescribe.getCachedFieldName(field);
	}

	/**
	 * @description Picks the masking targets that apply to one field on an SObjectType. A target
	 * that names the field wins over a wildcard target. For each (rule, caller class) pair:
	 *
	 * - if a target names the current field in `Field__c`, it wins
	 * - otherwise, if a target has a blank `Field__c` (a wildcard), it applies, unless the field
	 *   is a unique key, an external id, or a field the framework needs to keep its own data correct.
	 *   Wildcards never touch those on any path (the same `isExcludedFromWildcard` rule used when
	 *   masking a whole record), so a preview or sample through this path can never show masking that
	 *   record masking refuses
	 * - otherwise the rule does not run on this field
	 *
	 * Targets whose caller does not match, or whose rule has failed and been turned off in this
	 * transaction, are skipped first.
	 *
	 * @param sObjectType The target SObjectType
	 * @param qualifiedFieldName The `Object.Field` qualified name for the field being masked
	 * @param callerClassName Optional caller-class scope passed by the invoker, may be blank
	 *
	 * @return The active targets that should run on this field, in the rule order of the source list
	 */
	private static List<MaskingTarget__mdt> selectApplicableTargets(SObjectType sObjectType, String qualifiedFieldName, String callerClassName)
	{
		Boolean excludedField = isExcludedQualifiedField(sObjectType, qualifiedFieldName);
		List<MaskingTarget__mdt> inScopeTargets = new List<MaskingTarget__mdt>();
		Map<MaskingTarget__mdt, String> resolvedFieldByTarget = new Map<MaskingTarget__mdt, String>();

		for(MaskingTarget__mdt target : getTargetsFor(sObjectType))
		{
			if(!matchesCallerScope(target, callerClassName))
			{
				continue;
			}
			if(invalidatedRuleDeveloperNames.contains(ruleFor(target).DeveloperName))
			{
				continue;
			}

			String resolvedField = resolveQualifiedFieldName(target);
			resolvedFieldByTarget.put(target, resolvedField);

			if((String.isBlank(resolvedField) && !excludedField) || resolvedField == qualifiedFieldName)
			{
				inScopeTargets.add(target);
			}
		}

		Set<String> ruleAndCallerWithSpecific = new Set<String>();

		for(MaskingTarget__mdt target : inScopeTargets)
		{
			if(String.isNotBlank(resolvedFieldByTarget.get(target)))
			{
				ruleAndCallerWithSpecific.add(ruleAndCallerKey(target));
			}
		}

		List<MaskingTarget__mdt> applicableTargets = new List<MaskingTarget__mdt>();

		for(MaskingTarget__mdt target : inScopeTargets)
		{
			if(String.isBlank(resolvedFieldByTarget.get(target)) && ruleAndCallerWithSpecific.contains(ruleAndCallerKey(target)))
			{
				continue;
			}
			applicableTargets.add(target);
		}

		return applicableTargets;
	}

	/**
	 * @description Combined `ruleDeveloperName|callerClass` key, used to decide when a target that
	 * names a field takes precedence over a wildcard target.
	 *
	 * @param target The target to key
	 *
	 * @return The combined key
	 */
	private static String ruleAndCallerKey(MaskingTarget__mdt target)
	{
		String ruleName = ruleFor(target).DeveloperName;
		String caller = String.isBlank(target.CallerClass__c) ? UTIL_String.EMPTY : target.CallerClass__c;
		return ruleName + '|' + caller;
	}

	/**
	 * @description Checks whether a MaskingTarget's CallerClass scope matches the caller-class
	 * name given by the caller. Blank scope matches any caller; a set scope matches only
	 * when the caller gave that exact class name.
	 *
	 * @param target The target whose CallerClass__c to check
	 * @param callerClass The caller class name supplied by the invoker, or null for unscoped calls
	 *
	 * @return True if the target should fire for this caller
	 */
	private static Boolean matchesCallerScope(MaskingTarget__mdt target, String callerClass)
	{
		if(String.isBlank(target.CallerClass__c))
		{
			return true;
		}
		return target.CallerClass__c == callerClass;
	}

	/**
	 * @description Reports whether a rule's `ApplicableFieldTypes__c` filter allows a given Apex
	 * DisplayType. A rule with a blank list applies to every text field (the original behaviour). A
	 * rule with a list applies only to fields whose `DisplayType.name()` is in the semicolon-separated
	 * list (case does not matter, and spaces around each value are ignored).
	 *
	 * @param target The target whose rule's filter to consult
	 * @param fieldType The Apex DisplayType of the candidate field
	 *
	 * @return True if the rule applies to fields of this type, false if excluded
	 */
	private static Boolean ruleAppliesToFieldType(MaskingTarget__mdt target, DisplayType fieldType)
	{
		Set<DisplayType> allowedTypes = parseApplicableFieldTypes(target);
		return allowedTypes.isEmpty() || allowedTypes.contains(fieldType);
	}

	/**
	 * @description Returns the six text DisplayTypes keyed by their upper-case name. Built on the first
	 * call and cached for the rest of the transaction. Used by `parseApplicableFieldTypes` to turn each
	 * value in the list into a `DisplayType` enum value, so `ruleAppliesToFieldType` can compare enums
	 * instead of strings.
	 *
	 * @return Map from `DisplayType.name()` to the `DisplayType` enum value
	 */
	private static Map<String, DisplayType> getTextShapedDisplayTypes()
	{
		if(textShapedDisplayTypesByName == null)
		{
			textShapedDisplayTypesByName = new Map<String, DisplayType>
			{
					DisplayType.STRING.name() => DisplayType.STRING,
					DisplayType.TEXTAREA.name() => DisplayType.TEXTAREA,
					DisplayType.URL.name() => DisplayType.URL,
					DisplayType.EMAIL.name() => DisplayType.EMAIL,
					DisplayType.PHONE.name() => DisplayType.PHONE,
					DisplayType.ENCRYPTEDSTRING.name() => DisplayType.ENCRYPTEDSTRING
			};
		}
		return textShapedDisplayTypesByName;
	}

	/**
	 * @description Cache, for one transaction, of parsed `ApplicableFieldTypes__c` sets, keyed by the
	 * raw text of the list. Splitting, trimming, upper-casing and turning values into enums then runs
	 * once per distinct list per transaction. A bulk trigger with wildcard targets checks the same list
	 * for every text field on every record; without this cache the list would be parsed once per field
	 * per record on every DML. Rules with the same list share one cached Set.
	 */
	@TestVisible
	private static final Map<String, Set<DisplayType>> cachedAllowedTypesByCsv
	{
		get
		{
			if(cachedAllowedTypesByCsv == null)
			{
				cachedAllowedTypesByCsv = new Map<String, Set<DisplayType>>();
			}
			return cachedAllowedTypesByCsv;
		}
		set;
	}

	/**
	 * @description Developer names of rules whose `ApplicableFieldTypes__c` had unknown DisplayType
	 * values. Used to write the warning log only once per rule per transaction; otherwise a bulk
	 * trigger that runs the same rule for every record would flood the log.
	 */
	@TestVisible
	private static final Set<String> warnedInvalidApplicableFieldTypeRules
	{
		get
		{
			if(warnedInvalidApplicableFieldTypeRules == null)
			{
				warnedInvalidApplicableFieldTypeRules = new Set<String>();
			}
			return warnedInvalidApplicableFieldTypeRules;
		}
		set;
	}

	/**
	 * @description Combined keys (`ruleName|qualifiedField`) for targets that name a field but were
	 * dropped by the rule's `ApplicableFieldTypes__c` filter. The target explicitly links the rule to
	 * this field, but the rule's type filter does not allow the field's DisplayType; without a warning
	 * the target would be skipped without notice. Used to write that warning for admins once per rule
	 * and field pair per transaction.
	 */
	@TestVisible
	private static final Set<String> warnedSpecificFieldTypeMismatches
	{
		get
		{
			if(warnedSpecificFieldTypeMismatches == null)
			{
				warnedSpecificFieldTypeMismatches = new Set<String>();
			}
			return warnedSpecificFieldTypeMismatches;
		}
		set;
	}

	/**
	 * @description Parses a target's `ApplicableFieldTypes__c` list into a Set of `DisplayType` enum
	 * values. Cached per transaction by the raw text of the list: splitting, trimming, upper-casing and
	 * turning values into enums runs at most once per distinct list, however many targets or fields use
	 * it.
	 *
	 * Unknown values (subscriber typos) are left out of the returned Set, and one warning log per rule
	 * records the problem. A target on a log entry or the log event writes no warning: a warning written
	 * while a log entry is being built would take that entry's fingerprint, stack trace and exception
	 * type with it. For those targets the masking console's check and test show the mistake instead.
	 * If every value is unknown, the method returns an empty Set. `ruleAppliesToFieldType` reads an empty
	 * Set as "apply to every text field". This is a deliberate safe default: a mistyped value can never
	 * quietly switch off a rule that protects sensitive data.
	 *
	 * @param target The target whose rule's CSV to parse
	 *
	 * @return A Set of `DisplayType` enum values; an empty Set means "apply to every text field"
	 */
	@TestVisible
	private static Set<DisplayType> parseApplicableFieldTypes(MaskingTarget__mdt target)
	{
		String csv = ruleFor(target).ApplicableFieldTypes__c;
		if(String.isBlank(csv))
		{
			return new Set<DisplayType>();
		}

		if(cachedAllowedTypesByCsv.containsKey(csv))
		{
			return cachedAllowedTypesByCsv.get(csv);
		}

		Map<String, DisplayType> knownTypes = getTextShapedDisplayTypes();
		Set<DisplayType> allowedTypes = new Set<DisplayType>();
		Set<String> unknownTokens = new Set<String>();

		for(String token : csv.toUpperCase().split(';'))
		{
			String trimmed = token.trim();
			if(String.isBlank(trimmed))
			{
				continue;
			}
			if(knownTypes.containsKey(trimmed))
			{
				allowedTypes.add(knownTypes.get(trimmed));
			}
			else
			{
				unknownTokens.add(trimmed);
			}
		}

		if(!unknownTokens.isEmpty() && !isLogEntryTarget(target))
		{
			String ruleName = ruleFor(target).DeveloperName;
			if(!warnedInvalidApplicableFieldTypeRules.contains(ruleName))
			{
				warnedInvalidApplicableFieldTypeRules.add(ruleName);
				LOG_Builder.build()
						.warn
								('MaskingRule ' + ruleName + ' has unknown ApplicableFieldTypes__c values that will never match any text-shaped field: ' +
										unknownTokens + '. Accepted values: ' + knownTypes.keySet()
								)
						.emitAt(UTIL_FrameworkMasker.class.getName() + '.parseApplicableFieldTypes');
			}
		}

		cachedAllowedTypesByCsv.put(csv, allowedTypes);
		return allowedTypes;
	}

	/**
	 * @description Filters a list of applicable targets by each target rule's `ApplicableFieldTypes__c`,
	 * keeping only the targets whose rule allows the candidate field's DisplayType. Runs once per field
	 * when a batch plan is built, so it costs nothing per record. Targets whose rule leaves
	 * `ApplicableFieldTypes__c` blank are kept as they are.
	 *
	 * @param targets The applicable targets returned by `selectApplicableTargets`
	 * @param field The candidate SObjectField whose type the rules are filtered against
	 *
	 * @return The targets whose rule allows this field's DisplayType
	 */
	private static List<MaskingTarget__mdt> filterTargetsByFieldType(List<MaskingTarget__mdt> targets, SObjectField field)
	{
		DescribeFieldResult fieldDescribe = UTIL_SObjectDescribe.getCachedFieldDescribe(field);
		DisplayType fieldType = fieldDescribe.getType();
		List<MaskingTarget__mdt> filtered = new List<MaskingTarget__mdt>();

		for(MaskingTarget__mdt target : targets)
		{
			if(ruleAppliesToFieldType(target, fieldType))
			{
				filtered.add(target);
				continue;
			}
			warnSpecificFieldMismatchOnce(target, fieldDescribe, fieldType);
		}

		return filtered;
	}

	/**
	 * @description Writes a warning once when the rule's `ApplicableFieldTypes__c` filter drops a target
	 * that explicitly names a field (`Field__c` not blank). Otherwise the rule's type filter would
	 * quietly override the admin's explicit choice, and the mistake would stay hidden. Wildcard targets
	 * (`Field__c` blank) are expected to be filtered across many field types and do not warn. A target
	 * on a log entry or the log event does not warn either: a warning written while a log entry is being
	 * built would take that entry's fingerprint, stack trace and exception type with it. For those
	 * targets the masking console's check and test show the mistake instead.
	 *
	 * @param target The target being dropped from the applicable set.
	 * @param fieldDescribe The candidate field's describe result (for the qualified name in the message).
	 * @param fieldType The candidate field's DisplayType (for the "rejected types" detail).
	 */
	private static void warnSpecificFieldMismatchOnce(MaskingTarget__mdt target, DescribeFieldResult fieldDescribe, DisplayType fieldType)
	{
		if(String.isBlank(target.Field__c) || isLogEntryTarget(target))
		{
			return;
		}

		MaskingRule__mdt rule = ruleFor(target);
		String ruleName = rule.DeveloperName;
		String compositeKey = ruleName + '|' + fieldDescribe.getName();
		if(warnedSpecificFieldTypeMismatches.contains(compositeKey))
		{
			return;
		}
		warnedSpecificFieldTypeMismatches.add(compositeKey);

		LOG_Builder.build()
				.warn
						('MaskingTarget wires rule ' + ruleName + ' to field ' + target.Field__c +
								' but the rule\'s ApplicableFieldTypes__c = \'' + rule.ApplicableFieldTypes__c +
								'\' excludes ' + fieldType + ' fields. The rule will not run on this field: ' +
								'either widen ApplicableFieldTypes__c to include ' + fieldType + ' or remove the target.'
						)
				.emitAt(UTIL_FrameworkMasker.class.getName() + '.filterTargetsByFieldType');
	}

	/**
	 * @description Records that a rule has thrown, then acts on its `FailureAction__c`. Records the
	 * failure on the MaskingResult and writes a warning log, unless the target is a LogEntry type (which
	 * could start a logging loop across transactions). Then applies the configured action:
	 * LogAndContinue leaves the value alone, WriteFailureMarker writes `FAILURE_MARKER` instead, and
	 * BlockDml throws `MaskingBlockedException` so the caller around it (usually a trigger guard) stops
	 * the DML.
	 *
	 * Turning a rule off only applies to rules in warning mode. A rule that does not block is turned off
	 * for the rest of the transaction, so it cannot write the same warning again and again after it has
	 * failed. A rule set to BlockDml keeps blocking for the whole transaction: every later call that
	 * meets it throws again, because a rule that stopped working after its first failure would let the
	 * next masking call save the value without masking it.
	 *
	 * @param target The target whose rule threw
	 * @param result The MaskingResult being built (the error details are added to it)
	 *
	 * @throws UTIL_Exceptions.MaskingBlockedException when the rule's FailureAction is BlockDml
	 */
	private static void handleRuleFailure(MaskingTarget__mdt target, MaskingResult result)
	{
		MaskingRule__mdt rule = ruleFor(target);
		String ruleName = rule.DeveloperName;
		String failureAction = rule.FailureAction__c;

		if(failureAction != SEL_MaskingRule.FAILURE_BLOCK_DML)
		{
			invalidatedRuleDeveloperNames.add(ruleName);
		}

		result.hadErrors = true;
		result.failedRuleDeveloperNames.add(ruleName);

		logRuleFailureWarning(target, ruleName);

		if(failureAction == SEL_MaskingRule.FAILURE_BLOCK_DML)
		{
			throw new UTIL_Exceptions.MaskingBlockedException('Masking rule ' + ruleName + ' failed and is configured to block DML');
		}

		if(failureAction == SEL_MaskingRule.FAILURE_WRITE_FAILURE_MARKER)
		{
			result.maskedValue = FAILURE_MARKER;
		}
	}

	/**
	 * @description Writes a warning log about a failed masking rule, unless the target object is
	 * `LogEntry__c` or `LogEntryEvent__e`. Targets on log objects skip the warning because the log
	 * entry LOG_Builder would publish creates a new LogEntry or event, which runs the masker again in a
	 * later transaction. That can easily become an endless loop across transactions.
	 *
	 * @param target The target whose rule threw
	 * @param ruleName The rule's DeveloperName
	 */
	private static void logRuleFailureWarning(MaskingTarget__mdt target, String ruleName)
	{
		if(isLogEntryTarget(target))
		{
			return;
		}
		LOG_Builder.build()
				.warn('Masking rule ' + ruleName + ' failed; a blocking rule keeps blocking and a warn-mode rule is skipped for the rest of the transaction')
				.emitAt(UTIL_FrameworkMasker.class.getName() + '.handleRuleFailure');
	}

	/**
	 * @description Reports whether the target points at a log object (`LogEntry__c` or
	 * `LogEntryEvent__e`). Every warning this class writes checks this first, because none of them may
	 * be written while a log entry is being masked. Visible to tests, so the check that stops the
	 * logging loop can be asserted without setting up LOG_Builder.
	 *
	 * @param target The target to inspect
	 *
	 * @return True if `SObjectType__c` identifies `LogEntry__c` or `LogEntryEvent__e`
	 */
	@TestVisible
	private static Boolean isLogEntryTarget(MaskingTarget__mdt target)
	{
		return target.SObjectType__c == LOG_ENTRY_OBJECT_NAME || target.SObjectType__c == LOG_ENTRY_EVENT_OBJECT_NAME;
	}

	/**
	 * @description Applies one MaskingTarget's rule to a value, calling the UTIL_String helper that
	 * matches the rule's Mode.
	 *
	 * @param target The target whose rule to apply
	 * @param value The current value of the field being masked
	 *
	 * @return The value after the rule has been applied, or the input unchanged if the mode is not yet supported
	 */
	private static String applyTargetToValue(MaskingTarget__mdt target, String value)
	{
		MaskingRule__mdt rule = ruleFor(target);
		String mode = rule.Mode__c;
		String rulePattern = rule.Pattern__c;
		String replacement = rule.Replacement__c ?? UTIL_String.EMPTY;
		Boolean caseSensitive = rule.CaseSensitive__c == true;

		if(mode == SEL_MaskingRule.MODE_REGEX)
		{
			return UTIL_String.maskWithRegex(value, rulePattern, replacement, caseSensitive);
		}

		if(mode == SEL_MaskingRule.MODE_CREDIT_CARD)
		{
			return UTIL_String.maskWithLuhnValidatedRegex(value, rulePattern, replacement, caseSensitive);
		}

		if(mode == SEL_MaskingRule.MODE_JSON_KEY)
		{
			return UTIL_String.maskJsonKeys(value, rulePattern, replacement, caseSensitive);
		}

		if(mode == SEL_MaskingRule.MODE_EXACT_MATCH)
		{
			return UTIL_String.maskExactMatch(value, rulePattern, replacement);
		}

		return value;
	}

	/**
	 * @description Plan, worked out in advance, for masking one SObjectType for one caller. Holds the
	 * fields to mask and each field's rules, already split into JsonKey and other modes. Built once per
	 * `(sObjectType, callerClassName)` per transaction, then reused for every record in a bulk batch.
	 */
	private class BatchPlan
	{
		/**
		 * @description The plan entries, one for each field that has at least one applicable rule.
		 */
		private final List<FieldPlan> fieldPlans = new List<FieldPlan>();
	}

	/**
	 * @description Plan for one field: the field token, its API name, and its targets in two
	 * lists by rule mode. Because they are split in advance, `RecordMasker.apply` does not look up
	 * targets for each record.
	 */
	private class FieldPlan
	{
		/**
		 * @description The SObjectField token for the field being masked. Used to look up the field length
		 * and to get the API name when the masked value is written back to the record.
		 */
		private SObjectField field;

		/**
		 * @description The plain field API name (e.g. `Request__c`) used as the key when
		 * reading from and writing to the SObject via `get`/`put`. Cached so `RecordMasker`
		 * does not re-split the qualified `Object.Field` string on every record.
		 */
		private String fieldApiName;

		/**
		 * @description Applicable targets whose rule Mode is JsonKey, filtered in advance. Applied with one
		 * parse and one serialize by `applyJsonKeyBatchStatic`.
		 */
		private final List<MaskingTarget__mdt> jsonKeyTargets = new List<MaskingTarget__mdt>();

		/**
		 * @description Applicable targets, filtered in advance, whose rule Mode is Regex or
		 * ExactMatch. Applied one after another by `applySingleTargetStatic`.
		 */
		private final List<MaskingTarget__mdt> otherTargets = new List<MaskingTarget__mdt>();
	}

	/**
	 * @description Returns the cached batch plan for `(sObjectType, callerClassName)`,
	 * building it on first request.
	 *
	 * @param sObjectType The SObjectType being masked
	 * @param callerClassName Optional caller-class scope, may be blank
	 *
	 * @return The cached BatchPlan, or an empty one if no targets are configured
	 */
	private static BatchPlan getOrBuildBatchPlan(SObjectType sObjectType, String callerClassName)
	{
		String cacheKey = String.valueOf(sObjectType) + '|' + (callerClassName ?? UTIL_String.EMPTY);

		if(cachedBatchPlans.containsKey(cacheKey))
		{
			return cachedBatchPlans.get(cacheKey);
		}

		BatchPlan plan = buildBatchPlan(sObjectType, callerClassName);
		cachedBatchPlans.put(cacheKey, plan);
		return plan;
	}

	/**
	 * @description Builds the BatchPlan for an SObjectType and caller. Finds the distinct qualified
	 * fields (turning wildcards into fields through `getUpdateableTextFields`), then for each field
	 * splits the applicable targets into JsonKey and other lists. Fields with no applicable targets are
	 * left out of the plan.
	 *
	 * @param sObjectType The SObjectType to plan for
	 * @param callerClassName Optional caller-class scope
	 *
	 * @return The new BatchPlan; may be empty if no targets are configured
	 */
	private static BatchPlan buildBatchPlan(SObjectType sObjectType, String callerClassName)
	{
		BatchPlan plan = new BatchPlan();
		List<MaskingTarget__mdt> targets = getTargetsFor(sObjectType);

		if(targets.isEmpty())
		{
			return plan;
		}

		Map<String, SObjectField> fieldMap = UTIL_SObjectDescribe.getObjectFieldMap(sObjectType);
		Set<String> distinctQualifiedFields = new Set<String>();
		Boolean hasWildcardTarget = false;

		for(MaskingTarget__mdt target : targets)
		{
			String resolvedField = resolveQualifiedFieldName(target);

			if(String.isBlank(resolvedField))
			{
				hasWildcardTarget = true;
			}
			else
			{
				distinctQualifiedFields.add(resolvedField);
			}
		}

		if(hasWildcardTarget)
		{
			for(SObjectField wildcardField : getUpdateableTextFields(sObjectType))
			{
				distinctQualifiedFields.add(getQualifiedFieldName(wildcardField));
			}
		}

		for(String qualifiedField : distinctQualifiedFields)
		{
			Integer dotIndex = qualifiedField.indexOf(UTIL_String.DOT);
			if(dotIndex < 0)
			{
				continue;
			}

			String fieldApiName = qualifiedField.substring(dotIndex + 1);
			SObjectField field = fieldMap.get(fieldApiName);
			if(field == null)
			{
				continue;
			}

			List<MaskingTarget__mdt> applicableTargets = selectApplicableTargets(sObjectType, qualifiedField, callerClassName);
			if(applicableTargets.isEmpty())
			{
				continue;
			}

			applicableTargets = filterTargetsByFieldType(applicableTargets, field);
			if(applicableTargets.isEmpty())
			{
				continue;
			}

			FieldPlan fieldPlan = new FieldPlan();
			fieldPlan.field = field;
			fieldPlan.fieldApiName = fieldApiName;

			for(MaskingTarget__mdt applicableTarget : applicableTargets)
			{
				if(ruleFor(applicableTarget).Mode__c == SEL_MaskingRule.MODE_JSON_KEY)
				{
					fieldPlan.jsonKeyTargets.add(applicableTarget);
				}
				else
				{
					fieldPlan.otherTargets.add(applicableTarget);
				}
			}

			plan.fieldPlans.add(fieldPlan);
		}

		return plan;
	}

	/**
	 * @description Masks one field value with a FieldPlan built in advance. Applies the JsonKey rules
	 * with one parse and one serialize, then applies the other rules one after another. Cuts the value
	 * to the field's maximum length when anything changed. The callers (`FieldMasker.mask` and
	 * `RecordMasker.applyFieldPlanToRecord`) already skip null and empty values before they call this
	 * method.
	 *
	 * @param fieldPlan The field plan, built in advance
	 * @param rawValue The current field value
	 *
	 * @return The MaskingResult after all rules run; `maskedValue` equals input when nothing matched
	 */
	private static MaskingResult maskValueWithPlan(FieldPlan fieldPlan, String rawValue)
	{
		MaskingResult result = newResult(rawValue);

		applyJsonKeyBatchStatic(fieldPlan.jsonKeyTargets, result);

		for(MaskingTarget__mdt target : fieldPlan.otherTargets)
		{
			applySingleTargetStatic(target, result);
		}

		if(result.rulesMatched > 0)
		{
			DescribeFieldResult fieldDescribe = UTIL_SObjectDescribe.getCachedFieldDescribe(fieldPlan.field);
			Integer maxLength = fieldDescribe.getLength();

			if(maxLength > 0 && result.maskedValue != null && result.maskedValue.length() > maxLength)
			{
				result.maskedValue = UTIL_String.abbreviate(result.maskedValue, fieldPlan.field);
			}
		}

		result.maskedLength = result.maskedValue?.length() ?? 0;
		return result;
	}

	/**
	 * @description Masks one value with one specific rule, without using the active-target cache, so a
	 * rule with no active MaskingTarget for the field (an unused rule, or one set up elsewhere) can still
	 * be previewed. Builds an in-memory MaskingTarget that carries the rule on its `Rule__r` child (the
	 * fallback `ruleFor` uses when the rule cache has no entry for the Id). It then runs the rule through
	 * the normal field-plan path, so Mode handling, the MinInputLength check, JsonKey batching and length
	 * cutting all behave exactly as they would when masking for real. Reads no configured targets and
	 * performs no DML.
	 *
	 * The `rule` must be a top-level record read in the same transaction (for example from
	 * `SEL_MaskingTarget.getAllRulesById()`). Its fields are read from `Rule__r` in memory, with no JSON
	 * serialization in between, so the managed-package problem of fields missing from nested child records
	 * does not apply here. Do not add a serialize or deserialize step on the built target or on the rule
	 * passed in.
	 *
	 * @param field The field whose value is previewed; supplies the length limit for truncation.
	 * @param rule The rule with every field filled (Mode/Pattern/Replacement/MinInputLength) to apply.
	 * @param value The raw value to mask.
	 *
	 * @return The MaskingResult; `maskedValue` equals the input when the rule did not match (for example
	 *         a JsonKey rule against a non-JSON scalar), and `rulesMatched` shows whether the rule really changed nothing.
	 */
	public static MaskingResult maskValueAgainstRule(SObjectField field, MaskingRule__mdt rule, String value)
	{
		if(field == null || rule == null || String.isEmpty(value))
		{
			return newResult(value);
		}

		MaskingTarget__mdt previewTarget = new MaskingTarget__mdt();
		previewTarget.Rule__r = rule;

		FieldPlan previewPlan = new FieldPlan();
		previewPlan.field = field;

		if(rule.Mode__c == SEL_MaskingRule.MODE_JSON_KEY)
		{
			previewPlan.jsonKeyTargets.add(previewTarget);
		}
		else
		{
			previewPlan.otherTargets.add(previewTarget);
		}

		return maskValueWithPlan(previewPlan, value);
	}

	/**
	 * @description Applies every JsonKey rule to the value with one parse and one serialize. Uses the
	 * `mutated` flag and `replacementCount` on `UTIL_String.JsonKeyMaskResult` to see changes, instead of
	 * serializing before and after each rule (before this change, that was the most expensive step for
	 * each record). The final serialize runs only when at least one rule changed the parsed JSON.
	 *
	 * @param jsonKeyTargets Targets in rule order whose mode is JsonKey
	 * @param result The MaskingResult being built (changed as rules run)
	 */
	private static void applyJsonKeyBatchStatic(List<MaskingTarget__mdt> jsonKeyTargets, MaskingResult result)
	{
		if(jsonKeyTargets.isEmpty())
		{
			return;
		}

		String currentValue = result.maskedValue;
		Object parsed;

		try
		{
			parsed = JSON.deserializeUntyped(currentValue);
		}
		catch(System.JSONException parseError)
		{
			for(MaskingTarget__mdt target : jsonKeyTargets)
			{
				applySingleTargetStatic(target, result);
			}
			return;
		}

		Boolean anyRuleMatched = false;

		for(MaskingTarget__mdt target : jsonKeyTargets)
		{
			MaskingRule__mdt rule = ruleFor(target);
			if(invalidatedRuleDeveloperNames.contains(rule.DeveloperName))
			{
				continue;
			}

			try
			{
				Boolean caseSensitive = rule.CaseSensitive__c == true;
				String keyRegex = rule.Pattern__c;
				String replacement = rule.Replacement__c ?? UTIL_String.EMPTY;

				UTIL_String.JsonKeyMaskResult mutation = UTIL_String.applyJsonKeyRuleToTreeWithCount(parsed, keyRegex, replacement, caseSensitive);
				parsed = mutation.tree;

				if(mutation.mutated)
				{
					anyRuleMatched = true;
					result.rulesMatched++;
					result.valuesRedacted += mutation.replacementCount;
					result.matchedRuleDeveloperNames.add(rule.DeveloperName);
				}
			}
			catch(Exception ruleError)
			{
				handleRuleFailure(target, result);
			}
		}

		if(anyRuleMatched)
		{
			result.maskedValue = JSON.serialize(parsed);
		}
	}

	/**
	 * @description Applies one target that is not JsonKey (Regex or ExactMatch) to the result being
	 * built. Catches rule exceptions and records them in `hadErrors` and `failedRuleDeveloperNames`.
	 *
	 * @param target The target to apply
	 * @param result The MaskingResult being built (changed as rules run)
	 */
	private static void applySingleTargetStatic(MaskingTarget__mdt target, MaskingResult result)
	{
		MaskingRule__mdt rule = ruleFor(target);
		if(invalidatedRuleDeveloperNames.contains(rule.DeveloperName))
		{
			return;
		}

		Decimal minInputLength = rule.MinInputLength__c;
		if(minInputLength != null && minInputLength > 0 && (result.maskedValue == null || result.maskedValue.length() < minInputLength))
		{
			return;
		}

		String beforeRule = result.maskedValue;

		try
		{
			String afterRule = applyTargetToValue(target, beforeRule);

			if(afterRule != beforeRule && afterRule != null)
			{
				result.maskedValue = afterRule;
				result.rulesMatched++;
				result.valuesRedacted++;
				result.matchedRuleDeveloperNames.add(rule.DeveloperName);
			}
		}
		catch(Exception ruleError)
		{
			handleRuleFailure(target, result);
		}
	}

	/**
	 * @description Starts a fluent masking chain targeting a single field.
	 *
	 * @param targetField The SObjectField the value will be persisted to
	 *
	 * @return A FieldMasker ready for optional configuration and a terminal call
	 */
	public static FieldMasker forField(SObjectField targetField)
	{
		return new FieldMasker(targetField);
	}

	/**
	 * @description Starts a fluent masking chain targeting every configured text field on one record.
	 *
	 * @param recordToMask The SObject to mask in place
	 *
	 * @return A RecordMasker ready for optional configuration and a terminal call
	 */
	public static RecordMasker forRecord(SObject recordToMask)
	{
		return new RecordMasker(recordToMask);
	}

	/**
	 * @description Starts a fluent masking chain targeting every configured text field on a list of records.
	 *
	 * @param recordsToMask The SObjects to mask in place
	 *
	 * @return A BulkRecordMasker ready for optional configuration and a terminal call
	 */
	public static BulkRecordMasker forRecords(List<SObject> recordsToMask)
	{
		return new BulkRecordMasker(recordsToMask);
	}

	/**
	 * @description Builds an empty MaskingResult seeded with the input value and its length.
	 *
	 * @param rawValue The input value
	 *
	 * @return A MaskingResult ready for the engine to populate
	 */
	private static MaskingResult newResult(String rawValue)
	{
		MaskingResult result = new MaskingResult();
		result.maskedValue = rawValue;
		result.rulesMatched = 0;
		result.valuesRedacted = 0;
		result.matchedRuleDeveloperNames = new List<String>();
		result.originalLength = rawValue?.length() ?? 0;
		result.maskedLength = result.originalLength;
		result.hadErrors = false;
		result.failedRuleDeveloperNames = new List<String>();
		return result;
	}

	/**
	 * @description Fluent builder for masking a single field value. Queries CMDT for targets
	 * matching the field, then delegates each rule to the appropriate `UTIL_String` helper.
	 */
	public class FieldMasker
	{
		/**
		 * @description The target field used to look up applicable MaskingTarget records.
		 */
		@TestVisible
		private SObjectField targetField;

		/**
		 * @description Optional caller-class scope.
		 */
		@TestVisible
		private String callerClassName;

		/**
		 * @description Constructs a FieldMasker. Do not call it directly: use `UTIL_FrameworkMasker.forField()`.
		 *
		 * @param targetField The SObjectField being masked
		 */
		private FieldMasker(SObjectField targetField)
		{
			this.targetField = targetField;
		}

		/**
		 * @description Scopes the masking to a specific caller class. Rules whose CallerClass
		 * matches this value or is blank will run; rules limited to a different class will not.
		 *
		 * @param apexClassName The Apex class name of the caller (e.g. `API_SendEmail`)
		 *
		 * @return This builder for chaining
		 */
		public FieldMasker calledFrom(String apexClassName)
		{
			this.callerClassName = apexClassName;
			return this;
		}

		/**
		 * @description Final call: masks the value with every applicable MaskingTarget rule. Goes through
		 * the targets for the field, filters them by CallerClass, passes each rule to the matching UTIL_String
		 * helper, adds up the counts, and cuts the result to the field's length limit when needed.
		 *
		 * @param rawValue The raw (unmasked) value
		 *
		 * @return The masked value plus audit metadata
		 */
		public MaskingResult mask(String rawValue)
		{
			MaskingResult result = newResult(rawValue);

			if(String.isEmpty(rawValue))
			{
				return result;
			}

			SObjectType sObjectType = this.targetField.getDescribe().getSObjectType();
			String qualifiedFieldName = getQualifiedFieldName(this.targetField);

			List<MaskingTarget__mdt> applicableTargets = selectApplicableTargets(sObjectType, qualifiedFieldName, this.callerClassName);
			applicableTargets = filterTargetsByFieldType(applicableTargets, this.targetField);

			FieldPlan adhocPlan = new FieldPlan();
			adhocPlan.field = this.targetField;
			adhocPlan.fieldApiName = qualifiedFieldName.substringAfter(UTIL_String.DOT);

			for(MaskingTarget__mdt target : applicableTargets)
			{
				if(ruleFor(target).Mode__c == SEL_MaskingRule.MODE_JSON_KEY)
				{
					adhocPlan.jsonKeyTargets.add(target);
				}
				else
				{
					adhocPlan.otherTargets.add(target);
				}
			}

			return maskValueWithPlan(adhocPlan, rawValue);
		}
	}

	/**
	 * @description Fluent builder for masking every configured text field on a single record in place.
	 */
	public class RecordMasker
	{
		/**
		 * @description The record to mask in place.
		 */
		@TestVisible
		private SObject recordToMask;

		/**
		 * @description Optional caller-class scope.
		 */
		@TestVisible
		private String callerClassName;

		/**
		 * @description Constructs a RecordMasker. Do not call it directly: use `UTIL_FrameworkMasker.forRecord()`.
		 *
		 * @param recordToMask The SObject to mask
		 */
		private RecordMasker(SObject recordToMask)
		{
			this.recordToMask = recordToMask;
		}

		/**
		 * @description Scopes the masking to a specific caller class.
		 *
		 * @param apexClassName The Apex class name of the caller
		 *
		 * @return This builder for chaining
		 */
		public RecordMasker calledFrom(String apexClassName)
		{
			this.callerClassName = apexClassName;
			return this;
		}

		/**
		 * @description Final call: masks every configured text field on the record in place. Finds the
		 * distinct fields set up through `MaskingTarget__mdt` records for the SObjectType, reads the current
		 * value of each filled field, passes it to a `FieldMasker`, and writes the masked value back to the
		 * record. Adds up the match and failure counts across every masked field.
		 *
		 * @return A MaskingResult aggregating the effect across all masked fields on the record
		 *
		 * @throws UTIL_Exceptions.MaskingBlockedException when any rule with FailureAction = BlockDml fails
		 */
		public MaskingResult apply()
		{
			MaskingResult aggregate = newResult(null);

			if(this.recordToMask == null)
			{
				return aggregate;
			}

			SObjectType sObjectType = this.recordToMask.getSObjectType();
			BatchPlan plan = getOrBuildBatchPlan(sObjectType, this.callerClassName);

			if(plan.fieldPlans.isEmpty())
			{
				return aggregate;
			}

			for(FieldPlan fieldPlan : plan.fieldPlans)
			{
				applyFieldPlanToRecord(fieldPlan, aggregate);
			}

			return aggregate;
		}

		/**
		 * @description Reads, masks, and writes back one configured field on the record, using a FieldPlan
		 * built in advance. Skips null and empty values, so unused fields cost no regex or JSON work.
		 *
		 * @param fieldPlan The plan for this field, built in advance
		 * @param aggregate The record-level MaskingResult being built up as fields are processed
		 */
		private void applyFieldPlanToRecord(FieldPlan fieldPlan, MaskingResult aggregate)
		{
			Object currentValue = this.recordToMask.get(fieldPlan.fieldApiName);

			if(currentValue == null)
			{
				return;
			}

			String rawValue = String.valueOf(currentValue);

			if(String.isEmpty(rawValue))
			{
				return;
			}

			MaskingResult fieldResult = maskValueWithPlan(fieldPlan, rawValue);

			if(fieldResult.maskedValue != rawValue && fieldResult.maskedValue != null)
			{
				this.recordToMask.put(fieldPlan.fieldApiName, fieldResult.maskedValue);
			}

			aggregate.rulesMatched += fieldResult.rulesMatched;
			aggregate.valuesRedacted += fieldResult.valuesRedacted;
			aggregate.matchedRuleDeveloperNames.addAll(fieldResult.matchedRuleDeveloperNames);
			aggregate.originalLength += fieldResult.originalLength;
			aggregate.maskedLength += fieldResult.maskedLength;

			if(fieldResult.hadErrors)
			{
				aggregate.hadErrors = true;
				aggregate.failedRuleDeveloperNames.addAll(fieldResult.failedRuleDeveloperNames);
			}
		}
	}

	/**
	 * @description Fluent builder for bulk masking every configured text field on a list of records in place.
	 */
	public class BulkRecordMasker
	{
		/**
		 * @description The records to mask in place.
		 */
		@TestVisible
		private List<SObject> recordsToMask;

		/**
		 * @description Optional caller-class scope.
		 */
		@TestVisible
		private String callerClassName;

		/**
		 * @description Constructs a BulkRecordMasker. Do not call it directly: use `UTIL_FrameworkMasker.forRecords()`.
		 *
		 * @param recordsToMask The SObjects to mask
		 */
		private BulkRecordMasker(List<SObject> recordsToMask)
		{
			this.recordsToMask = recordsToMask;
		}

		/**
		 * @description Scopes the masking to a specific caller class.
		 *
		 * @param apexClassName The Apex class name of the caller
		 *
		 * @return This builder for chaining
		 */
		public BulkRecordMasker calledFrom(String apexClassName)
		{
			this.callerClassName = apexClassName;
			return this;
		}

		/**
		 * @description Final call: masks every configured text field on every record in place. Calls
		 * `RecordMasker.apply` for each record, so a `MaskingBlockedException` from any record stops the
		 * batch at once.
		 *
		 * @return One MaskingResult per input record, in order; empty list if the input was null
		 *
		 * @throws UTIL_Exceptions.MaskingBlockedException when any rule with FailureAction = BlockDml fails
		 */
		public List<MaskingResult> apply()
		{
			List<MaskingResult> results = new List<MaskingResult>();

			if(this.recordsToMask == null)
			{
				return results;
			}

			for(SObject record : this.recordsToMask)
			{
				RecordMasker recordMasker = new RecordMasker(record);
				recordMasker.callerClassName = this.callerClassName;
				results.add(recordMasker.apply());
			}

			return results;
		}
	}

	/**
	 * @description Result returned by every final masking call. Holds the masked value plus audit
	 * details added up across all rules that ran on the value or record.
	 */
	public class MaskingResult
	{
		/**
		 * @description The value after masking (equal to the input when nothing matched).
		 */
		public String maskedValue;

		/**
		 * @description Number of distinct rules that matched during this call.
		 */
		public Integer rulesMatched;

		/**
		 * @description Total number of substring or JSON-value replacements performed across all rules.
		 */
		public Integer valuesRedacted;

		/**
		 * @description DeveloperNames of rules that matched during this call, in execution order.
		 */
		public List<String> matchedRuleDeveloperNames;

		/**
		 * @description Length of the input string before masking.
		 */
		public Integer originalLength;

		/**
		 * @description Length of the output string after masking.
		 */
		public Integer maskedLength;

		/**
		 * @description True if at least one rule failed during this call.
		 */
		public Boolean hadErrors;

		/**
		 * @description DeveloperNames of rules that failed, paired with hadErrors.
		 */
		public List<String> failedRuleDeveloperNames;
	}
}