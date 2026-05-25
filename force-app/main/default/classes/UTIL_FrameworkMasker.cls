// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Orchestrates data masking. Queries `MaskingRule__mdt` and `MaskingTarget__mdt`
 * for applicable wiring's, delegates the actual string transformation to `UTIL_String` masking
 * helpers, and honours the `MaskingFramework_Enabled` kill switch.
 *
 * Package-internal — the log engine, web service framework, async chain framework, and trigger
 * dispatcher call this class to mask records before persistence. Subscribers running their own
 * masking frameworks use their own kill switch and invoke the `UTIL_String` helpers directly.
 *
 * **Probing enablement from subscriber Apex.** This class is intentionally `public` (not `global`),
 * so subscribers cannot reference `UTIL_FrameworkMasker.isMaskingEnabled` directly across the
 * namespace boundary. The supported probe is `kern.UTIL_FeatureFlag.isEnabled('MaskingFramework_Enabled')`
 * — the underlying feature flag that the masker itself reads. `UTIL_FeatureFlag` is `global`, so
 * the call works from subscriber Apex, anonymous Apex, and `@IsTest` classes. Use this when a
 * subscriber test or load script wants to skip masking-dependent assertions if the framework is
 * disabled, or when a health-check page wants to surface "masking is currently enabled" status.
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
 * @date April 2026, May 2026
 *
 * @example
 * ```apex
 * // From subscriber Apex / anon Apex — probe whether masking is currently enabled
 * if(kern.UTIL_FeatureFlag.isEnabled('MaskingFramework_Enabled'))
 * {
 *     // Masking is on — assertions about redacted output are valid
 * }
 * ```
 */
@SuppressWarnings('PMD.CognitiveComplexity,PMD.CyclomaticComplexity,PMD.ExcessiveClassLength')
public inherited sharing class UTIL_FrameworkMasker
{
	/**
	 * @description DeveloperName of the kill-switch feature flag. Matches the
	 * `API_Inbound.FLAG_DISABLE_ALL_INBOUND_APIS` pattern — constant is internal, callers
	 * gate via `isMaskingEnabled`.
	 */
	@TestVisible
	private static final String FLAG_MASKING_FRAMEWORK_ENABLED = 'MaskingFramework_Enabled';

	/**
	 * @description Sentinel value written to a field when its masking rule throws and the
	 * rule's `FailureAction__c = WriteFailureMarker`. Short enough to fit on typical text
	 * fields while still being obviously non-real-data to any admin eyeballing the record.
	 */
	public static final String FAILURE_MARKER = '[MASKING_FAILURE]';

	/**
	 * @description Namespace-safe API name for `LogEntry__c`. Used to suppress LOG_Builder
	 * warnings when a masking target on LogEntry fails, which would otherwise queue a new
	 * LogEntryEvent → new LogEntry__c → trigger-guard → masker → fail → warn cross-transaction
	 * loop.
	 */
	@TestVisible
	private static final String LOG_ENTRY_OBJECT_NAME = UTIL_SObjectDescribe.getObjectNameFromType(LogEntry__c.SObjectType);

	/**
	 * @description Namespace-safe API name for `LogEntryEvent__e`. Partnered with
	 * `LOG_ENTRY_OBJECT_NAME` in the warn-suppression check so the masker can mask events
	 * without recursively publishing more events.
	 */
	@TestVisible
	private static final String LOG_ENTRY_EVENT_OBJECT_NAME = UTIL_SObjectDescribe.getObjectNameFromType(LogEntryEvent__e.SObjectType);

	/**
	 * @description Per-transaction set of rule DeveloperNames that have thrown at least once.
	 * Invalidated rules are filtered out of subsequent `FieldMasker.mask` calls in the same
	 * transaction — one broken rule fails once, then is skipped for the remaining records in
	 * a bulk trigger batch. Statics reset between transactions so admins get another chance
	 * after fixing the rule.
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
	 * @description Reports whether the masking framework's kill switch is engaged. Package
	 * adapters (LOG_Engine, API_Base, UTIL_AsyncChain, trigger dispatcher) gate their masking
	 * invocations on this property. Lazy-initialised per transaction, so transactions that
	 * never read it pay no feature-flag lookup cost.
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
	 * @description Per-transaction cache of active MaskingTarget records keyed by SObjectType.
	 * Lazy-initialised on first read so transactions that never invoke the masker pay no cost.
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
	 * @description Per-transaction cache of the updateable text-shaped fields on each
	 * SObjectType, used to expand wildcard MaskingTarget records (blank Field__c) to the
	 * concrete set of fields to mask. Filters to field types that can hold text (Text / Text
	 * Area / Long Text Area / URL / Email / Phone / Encrypted) and that Apex can write to
	 * (excludes formulas, read-only and system fields).
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
	 * @description Per-transaction cache of pre-computed batch plans keyed by
	 * `sObjectType|callerClassName`. A batch plan resolves the list of qualified fields to
	 * mask and pre-splits each field's applicable targets into JsonKey vs other, so bulk
	 * masking of N records against the same SObjectType and caller pays the target-resolution
	 * and field-discovery cost exactly once per transaction instead of once per record.
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
	 * @description Lazily-built transaction cache mapping text-shaped DisplayType names
	 * (STRING, TEXTAREA, URL, EMAIL, PHONE, ENCRYPTEDSTRING) to their `System.DisplayType`
	 * enum values. Derived from the enum itself via `.name()` — a platform rename surfaces
	 * as a compile error instead of silent string-literal drift. JIT so transactions that
	 * never touch masking do not pay the construction cost or flood class-load debug logs
	 * with six `VARIABLE_ASSIGNMENT` entries.
	 */
	@TestVisible
	private static Map<String, DisplayType> textShapedDisplayTypesByName;

	/**
	 * @description Returns the cached list of active masking targets for an SObjectType,
	 * lazy-loading from SEL_MaskingTarget on the first request.
	 *
	 * @param sObjectType The object whose targets to retrieve
	 *
	 * @return All active MaskingTarget records for this type, empty list if none are configured
	 */
	private static List<MaskingTarget__mdt> getTargetsFor(SObjectType sObjectType)
	{
		if(!cachedTargets.containsKey(sObjectType))
		{
			cachedTargets.put(sObjectType, sortByRuleOrder(removeDuplicateTargets(new SEL_MaskingTarget().findActiveForSObjectType(sObjectType))));
		}

		return cachedTargets.get(sObjectType);
	}

	/**
	 * @description Resolves a target's parent `MaskingRule__mdt`. Production and TST_Mock paths
	 * populate `SEL_MaskingTarget.getRuleById`, which is checked first. Falls back to the
	 * target's own `Rule__r` child only when the sidecar cache doesn't have an entry — that
	 * fallback exists so unit tests that construct a `MaskingTarget__mdt` in-memory and set
	 * `target.Rule__r = rule` directly (without going through TST_Mock) keep working. In
	 * production the production SOQL populates the sidecar cache by Id, and `target.Rule__r`
	 * is never relied on — avoiding the managed-package custom-field drop on nested children.
	 *
	 * @param target The target whose parent rule to resolve.
	 *
	 * @return The fully-populated rule, or `null` if neither source has it.
	 */
	private static MaskingRule__mdt ruleFor(MaskingTarget__mdt target)
	{
		return SEL_MaskingTarget.getRuleById(target.Rule__c) ?? target.Rule__r;
	}

	/**
	 * @description Returns the list of writable, text-shaped fields on an SObjectType that
	 * wildcard MaskingTarget records (blank Field__c) should expand to. Filters out formula,
	 * calculated, and read-only fields so `record.put()` never throws at masking time. Cached
	 * per SObjectType so describe calls happen once per transaction.
	 *
	 * Platform events (`__e` objects) report every field as `isUpdateable() == false` because
	 * they are insert-only — but their fields ARE writable at construction time via `put`. We
	 * detect platform events and switch to `isCreateable()` for the writability check so
	 * wildcard masking still covers event fields.
	 *
	 * @param sObjectType The SObjectType to enumerate
	 *
	 * @return The list of SObjectField tokens for writable Text/TextArea/LongTextArea/URL/Email/Phone/Encrypted fields
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
		Boolean isPlatformEvent = UTIL_SObjectDescribe.getObjectNameFromType(sObjectType).endsWith('__e');

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
	 * @description Sorts masking targets by parent rule `Order__c` ascending so execution is
	 * deterministic. In-Apex sort rather than SOQL ORDER BY because CMDT MetadataRelationship
	 * parent fields aren't supported in SOQL ORDER BY clauses.
	 *
	 * @param targets The deduped target list
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
	 * `RuleDeveloperName | Field | CallerClass` composite key. If an admin (or subscriber)
	 * configures two functionally identical targets, only the first occurrence is kept —
	 * preventing confusing audit output where the same rule appears to match twice.
	 *
	 * @param targets The raw list from the selector
	 *
	 * @return A list with duplicates removed; first-wins by iteration order
	 */
	private static List<MaskingTarget__mdt> removeDuplicateTargets(List<MaskingTarget__mdt> targets)
	{
		Map<String, MaskingTarget__mdt> firstTargetByCompositeKey = new Map<String, MaskingTarget__mdt>();

		for(MaskingTarget__mdt target : targets)
		{
			String ruleName = ruleFor(target).DeveloperName;
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
	 * @description Resolves a MaskingTarget's Field__c to its fully qualified
	 * `ObjectName.FieldName` form. Real deployed CMDT records return the
	 * EntityDefinition/FieldDefinition durable Id through `Field__c`, so the qualified name
	 * has to be assembled from the related SObjectType__r and Field__r QualifiedApiName
	 * fields. Mocked records (TST_Builder) put the already-qualified string directly in
	 * `Field__c`, so the relationship fallback handles both shapes without test plumbing.
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
	 * @description Picks the masking targets that apply to a single field on an SObjectType,
	 * honoring the specific-beats-wildcard precedence rule. For each (rule, caller-class)
	 * combination:
	 *
	 * - if a target exists with a specific `Field__c` equal to the current field, it wins
	 * - otherwise if a target exists with blank `Field__c` (wildcard), it applies
	 * - otherwise the rule does not fire on this field
	 *
	 * Targets whose caller scope does not match or whose rule has been invalidated this
	 * transaction are skipped first.
	 *
	 * @param sObjectType The target SObjectType
	 * @param qualifiedFieldName The `Object.Field` qualified name for the field being masked
	 * @param callerClassName Optional caller-class scope passed by the invoker, may be blank
	 *
	 * @return The subset of active targets that should fire on this field, preserving rule-order from the source list
	 */
	private static List<MaskingTarget__mdt> selectApplicableTargets(SObjectType sObjectType, String qualifiedFieldName, String callerClassName)
	{
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

			if(String.isBlank(resolvedField) || resolvedField == qualifiedFieldName)
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
	 * @description Composite key of `ruleDeveloperName|callerClass` used to determine when a
	 * specific-field target should shadow a wildcard target.
	 *
	 * @param target The target to key
	 *
	 * @return The composite key string
	 */
	private static String ruleAndCallerKey(MaskingTarget__mdt target)
	{
		String ruleName = ruleFor(target).DeveloperName;
		String caller = String.isBlank(target.CallerClass__c) ? UTIL_String.EMPTY : target.CallerClass__c;
		return ruleName + '|' + caller;
	}

	/**
	 * @description Checks whether a MaskingTarget's CallerClass scope matches the caller-class
	 * hint supplied by the invoker. Blank scope matches any caller; a set scope matches only
	 * when the invoker supplied that exact class name.
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
	 * @description Reports whether a rule's `ApplicableFieldTypes__c` filter admits a given Apex
	 * DisplayType. Rules with a blank CSV apply to every text-shaped field (original behaviour).
	 * Rules with a populated CSV apply only to fields whose `DisplayType.name()` appears in the
	 * semicolon-delimited list (case-insensitive, whitespace-trimmed).
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
	 * @description Returns the six text-shaped DisplayTypes keyed by their uppercase name.
	 * Built on first call, cached for the rest of the transaction. Used by
	 * `parseApplicableFieldTypes` to convert incoming CSV tokens to `DisplayType` enum
	 * values so the runtime comparison in `ruleAppliesToFieldType` can use enum equality
	 * rather than string equality.
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
	 * @description Per-transaction cache of parsed `ApplicableFieldTypes__c` sets keyed by
	 * raw CSV string. Ensures split + trim + uppercase + enum resolution runs exactly once
	 * per distinct CSV value per transaction. Bulk triggers on wildcard targets fan the same
	 * CSV across every text-shaped field on every record — without this cache the same CSV
	 * is parsed N-fields × M-records times per DML. Identical CSVs across different rules
	 * share the cached Set.
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
	 * @description Developer names of rules whose `ApplicableFieldTypes__c` contained
	 * unknown DisplayType values. Used to emit the warn log exactly once per rule per
	 * transaction — bulk triggers iterating the same rule N-records times would otherwise
	 * flood the log pipeline.
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
	 * @description Composite keys (`ruleName|qualifiedField`) for specific-field targets dropped
	 * by the rule-level `ApplicableFieldTypes__c` filter. The target explicitly wired the rule
	 * to this field but the rule's type filter excludes the field's DisplayType — silent
	 * skip without this warning. Used to emit the admin-facing misconfiguration warning
	 * exactly once per rule-field pair per transaction.
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
	 * @description Parses a target's `ApplicableFieldTypes__c` CSV into a Set of
	 * `DisplayType` enum values. Cached per transaction by raw CSV string — split + trim +
	 * uppercase + enum resolution runs at most once per distinct CSV value regardless of
	 * how many targets or fields invoke it.
	 *
	 * Unknown tokens (subscriber typos) are dropped from the returned Set and a one-time
	 * warn log per rule records the issue. If every token is unknown the method returns
	 * an empty Set — `ruleAppliesToFieldType` treats empty as "apply to every text-shaped
	 * field", a deliberate secure-by-default fallback so a fully-typed value cannot
	 * silently disable a rule that is protecting sensitive data.
	 *
	 * @param target The target whose rule's CSV to parse
	 *
	 * @return A Set of `DisplayType` enum values; empty Set means "apply to every text-shaped field"
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

		if(!unknownTokens.isEmpty())
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
	 * @description Filters a list of applicable targets by each target rule's
	 * `ApplicableFieldTypes__c`, keeping only targets whose rule admits the candidate field's
	 * DisplayType. Runs once per field per batch-plan build — zero per-record cost. Targets
	 * whose rule leaves `ApplicableFieldTypes__c` blank pass through unchanged.
	 *
	 * @param targets The applicable targets returned by `selectApplicableTargets`
	 * @param field The candidate SObjectField whose type the rules are filtered against
	 *
	 * @return The subset of targets whose rule admits this field's DisplayType
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
	 * @description Emits a one-time warning when the rule-level `ApplicableFieldTypes__c` filter
	 * drops a target that explicitly wires itself to a specific field (`Field__c` non-blank).
	 * The admin's explicit wiring would otherwise be silently overridden by the rule-level
	 * type filter, making misconfiguration invisible. Wildcard targets (`Field__c` blank) are
	 * expected to be filtered across many field types and do not warn.
	 *
	 * @param target The target being dropped from the applicable set.
	 * @param fieldDescribe The candidate field's describe result (for the qualified name in the message).
	 * @param fieldType The candidate field's DisplayType (for the "rejected types" detail).
	 */
	private static void warnSpecificFieldMismatchOnce(MaskingTarget__mdt target, DescribeFieldResult fieldDescribe, DisplayType fieldType)
	{
		if(String.isBlank(target.Field__c))
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
								'\' excludes ' + fieldType + ' fields. The rule will not fire on this field — ' +
								'either widen ApplicableFieldTypes__c to include ' + fieldType + ' or remove the target.'
						)
				.emitAt(UTIL_FrameworkMasker.class.getName() + '.filterTargetsByFieldType');
	}

	/**
	 * @description Records that a rule has thrown and dispatches on its `FailureAction__c`.
	 * Always invalidates the rule for the rest of the transaction, records the failure on
	 * the MaskingResult, and emits a warn log unless the target is a LogEntry type (which
	 * would risk a cross-transaction logging loop). Then acts on the configured action:
	 * LogAndContinue leaves the value alone, WriteFailureMarker substitutes
	 * `FAILURE_MARKER`, and BlockDml throws `MaskingBlockedException` so the surrounding
	 * adapter (usually a trigger guard) aborts the DML.
	 *
	 * @param target The target whose rule threw
	 * @param result The in-progress MaskingResult (mutated with error metadata)
	 *
	 * @throws UTIL_Exceptions.MaskingBlockedException when the rule's FailureAction is BlockDml
	 */
	private static void handleRuleFailure(MaskingTarget__mdt target, MaskingResult result)
	{
		MaskingRule__mdt rule = ruleFor(target);
		String ruleName = rule.DeveloperName;
		invalidatedRuleDeveloperNames.add(ruleName);
		result.hadErrors = true;
		result.failedRuleDeveloperNames.add(ruleName);

		logRuleFailureWarning(target, ruleName);

		String failureAction = rule.FailureAction__c;

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
	 * @description Emits a warn log about a failed masking rule unless the target object is
	 * `LogEntry__c` or `LogEntryEvent__e`. Masking-on-log targets skip the warn because the
	 * log entry LOG_Builder would publish creates a new LogEntry/Event, which re-enters
	 * the masker in a later transaction — easy path to an infinite cross-transaction loop.
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
				.warn('Masking rule ' + ruleName + ' failed; remaining records this transaction will skip this rule')
				.emitAt(UTIL_FrameworkMasker.class.getName() + '.handleRuleFailure');
	}

	/**
	 * @description Reports whether the target points at a LogEntry-family object. Exposed for
	 * tests so the log-recursion guard can be asserted without a live LOG_Builder fixture.
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
	 * @description Applies a single MaskingTarget's rule to a value, dispatching to the
	 * appropriate UTIL_String helper based on the rule's Mode.
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
	 * @description Pre-computed plan for masking one SObjectType under one caller scope.
	 * Holds the resolved fields to mask and each field's rules pre-split into JsonKey vs
	 * other. Built once per `(sObjectType, callerClassName)` per transaction, then reused
	 * across every record in a bulk batch.
	 */
	private class BatchPlan
	{
		/**
		 * @description The per-field execution plan entries, one per field that has at
		 * least one applicable rule.
		 */
		private final List<FieldPlan> fieldPlans = new List<FieldPlan>();
	}

	/**
	 * @description Per-field plan: the field token, its API name, and the two
	 * rule-mode-sorted target buckets. Pre-splitting means `RecordMasker.apply` does
	 * zero per-record target resolution.
	 */
	private class FieldPlan
	{
		/**
		 * @description The SObjectField token for the field being masked. Used for length
		 * lookup and as the API-name source when writing the masked value back on the record.
		 */
		private SObjectField field;

		/**
		 * @description The plain field API name (e.g. `Request__c`) used as the key when
		 * reading from and writing to the SObject via `get`/`put`. Cached so `RecordMasker`
		 * does not re-split the qualified `Object.Field` string on every record.
		 */
		private String fieldApiName;

		/**
		 * @description Pre-filtered list of applicable targets whose rule Mode is JsonKey.
		 * Applied in a single deserialize/serialize pair by `applyJsonKeyBatchStatic`.
		 */
		private final List<MaskingTarget__mdt> jsonKeyTargets = new List<MaskingTarget__mdt>();

		/**
		 * @description Pre-filtered list of applicable targets whose rule Mode is Regex or
		 * ExactMatch. Applied sequentially by `applySingleTargetStatic`.
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
	 * @description Builds the BatchPlan for an SObjectType + caller-scope pair. Resolves
	 * the distinct qualified field set (expanding wildcards via `getUpdateableTextFields`),
	 * then for each field pre-splits the applicable targets into JsonKey vs other buckets.
	 * Fields with no applicable targets are dropped from the plan.
	 *
	 * @param sObjectType The SObjectType to plan for
	 * @param callerClassName Optional caller-class scope
	 *
	 * @return The freshly-built BatchPlan; may be empty if no targets are configured
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
	 * @description Masks one field value using a pre-built FieldPlan. Applies JsonKey rules
	 * in a single deserialize/serialize pair, then applies remaining rules sequentially.
	 * Truncates to the field's max length when anything changed. Callers
	 * (`FieldMasker.mask` and `RecordMasker.applyFieldPlanToRecord`) already skip null/empty
	 * values before invoking this method.
	 *
	 * @param fieldPlan The pre-built field plan
	 * @param rawValue The current field value
	 *
	 * @return The MaskingResult after all rules fire; `maskedValue` equals input when nothing matched
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
	 * @description Applies every JsonKey rule to the value in a single parse/serialize pair.
	 * Uses the `mutated` flag and `replacementCount` on `UTIL_String.JsonKeyMaskResult` to detect
	 * changes instead of serializing before and after each rule — the single most expensive
	 * per-record operation prior to this optimisation. The final serialize runs only when at
	 * least one rule mutated the tree.
	 *
	 * @param jsonKeyTargets Targets in rule-order whose mode is JsonKey
	 * @param result The in-progress MaskingResult (mutated as rules fire)
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
	 * @description Applies a single non-JsonKey target (Regex or ExactMatch) to the in-progress
	 * result. Catches rule exceptions into `hadErrors` / `failedRuleDeveloperNames`.
	 *
	 * @param target The target to apply
	 * @param result The in-progress MaskingResult (mutated as rules fire)
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
		 * @description Constructs a FieldMasker; do not call directly — use `UTIL_FrameworkMasker.forField()`.
		 *
		 * @param targetField The SObjectField being masked
		 */
		private FieldMasker(SObjectField targetField)
		{
			this.targetField = targetField;
		}

		/**
		 * @description Scopes the masking to a specific caller class. Rules whose CallerClass
		 * matches this value or is blank will fire; rules scoped to a different class will not.
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
		 * @description Terminal: masks the value using every applicable MaskingTarget rule.
		 * Iterates targets for the field, filters by CallerClass scope, dispatches each rule
		 * to the appropriate UTIL_String helper, aggregates counts, and truncates the result
		 * to fit the field's length limit if necessary.
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
		 * @description Constructs a RecordMasker; do not call directly — use `UTIL_FrameworkMasker.forRecord()`.
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
		 * @description Terminal: masks every configured text field on the record in place.
		 * Resolves the distinct set of fields configured via `MaskingTarget__mdt` records for
		 * the SObjectType, reads the current value of each populated field, delegates to a
		 * `FieldMasker`, and writes the masked value back on the record. Aggregates match and
		 * failure counts across every masked field.
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
		 * @description Reads, masks, and writes back a single configured field on the record
		 * using a pre-built FieldPlan. Skips null and empty values so unused fields do not
		 * incur regex or JSON work.
		 *
		 * @param fieldPlan The pre-built per-field plan
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
		 * @description Constructs a BulkRecordMasker; do not call directly — use `UTIL_FrameworkMasker.forRecords()`.
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
		 * @description Terminal: masks every configured text field on every record in place.
		 * Delegates per-record to `RecordMasker.apply`, so `MaskingBlockedException` from any
		 * record halts the batch immediately (fast exit).
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
	 * @description Diagnostic result returned by every masking terminal. Holds the masked
	 * value plus audit metadata aggregated across all rules that fired on the value/record.
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