// SPDX-License-Identifier: Apache-2.0
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
 * @see UTIL_Crypto
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
	 * @description Start of the flood-control key on the warning that a rule failed. The rule's developer name
	 * follows, so the first failure of each rule is kept in full and the repeats are counted once a day.
	 */
	private static final String RULE_FAILURE_FINGERPRINT_PREFIX = 'masking:rule-failure:';

	/**
	 * @description Start of the flood-control key on the warning that a rule names a field type that does not exist.
	 * The rule's developer name follows.
	 */
	private static final String UNKNOWN_FIELD_TYPE_FINGERPRINT_PREFIX = 'masking:unknown-field-type:';

	/**
	 * @description Start of the flood-control key on the warning that a target wires a rule to a field whose type the
	 * rule excludes. The rule's developer name and the target's qualified field name (`Object.Field`, both API names)
	 * follow, so the same field name on two objects is two keys. The same key is the once-per-transaction check.
	 */
	private static final String EXCLUDED_FIELD_TYPE_FINGERPRINT_PREFIX = 'masking:excluded-field-type:';

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
	 * @description The field types a wildcard target can cover, because they hold text: Text, Text Area, Long Text
	 * Area, URL, Email, Phone and Encrypted Text.
	 */
	private static final Set<DisplayType> WILDCARD_TEXT_TYPES = new Set<DisplayType>
	{
			DisplayType.STRING,
			DisplayType.TEXTAREA,
			DisplayType.URL,
			DisplayType.EMAIL,
			DisplayType.PHONE,
			DisplayType.ENCRYPTEDSTRING
	};

	/**
	 * @description Start of the flood-control key on the warning that the platform refused to take a masked value for
	 * a field. The field's qualified name (`Object.Field`, both API names) follows.
	 */
	private static final String WRITE_REFUSED_FINGERPRINT_PREFIX = 'masking:write-refused:';

	/**
	 * @description Fields the platform refused to write a masked value to in this transaction. Some standard text
	 * fields are covered by a wildcard target, but no user can change them (for example `Case.ContactEmail`, which the
	 * platform copies from the case's contact). Writing to such a field throws. The record masker adds the field here
	 * on the first refusal and skips it for every later record in the transaction, so no rule runs on it again.
	 * Statics reset between transactions.
	 */
	private static final Set<SObjectField> fieldsThePlatformRefusesToWrite
	{
		get
		{
			if(fieldsThePlatformRefusesToWrite == null)
			{
				fieldsThePlatformRefusesToWrite = new Set<SObjectField>();
			}
			return fieldsThePlatformRefusesToWrite;
		}
		set;
	}

	/**
	 * @description The rule modes that compile a pattern before they run: Regex, CreditCard and JsonKey.
	 * ExactMatch compares plain text, so it has no pattern that can fail to compile.
	 */
	private static final Set<String> PATTERN_MODES = new Set<String> {SEL_MaskingRule.MODE_REGEX, SEL_MaskingRule.MODE_CREDIT_CARD, SEL_MaskingRule.MODE_JSON_KEY};

	/**
	 * @description DeveloperNames of the Log and Continue rules that have thrown at least once in this
	 * transaction. These rules are left out of later masking calls in the same transaction: such a rule
	 * fails once, then is skipped for the other records in a bulk trigger batch, so the later values are
	 * saved as they are. Only Log and Continue rules join this set. A Write Failure Marker rule keeps
	 * running, and a Block DML rule keeps refusing saves, because skipping either one would let a later
	 * masking call save a value without masking it. Statics reset between transactions, so the rule runs
	 * again after an admin fixes it.
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
	 * @description DeveloperNames of the Write Failure Marker rules whose pattern cannot compile, found
	 * in this transaction. Such a rule can never mask anything. Every later value it covers gets
	 * `FAILURE_MARKER` without running the rule, so the cost is one set lookup per value. A blank value
	 * stays as it is, and so does a value the rule would not look at when it works (on the plain-text
	 * path, a value shorter than the rule's `MinInputLength__c`). A Write Failure Marker rule
	 * whose pattern compiles but fails on one value never joins this set: only that value gets the
	 * marker, and the rule keeps running on the other values. Statics reset between transactions.
	 */
	@TestVisible
	private static final Set<String> brokenPatternRuleDeveloperNames
	{
		get
		{
			if(brokenPatternRuleDeveloperNames == null)
			{
				brokenPatternRuleDeveloperNames = new Set<String>();
			}
			return brokenPatternRuleDeveloperNames;
		}
		set;
	}

	/**
	 * @description DeveloperNames of the rules that have already written their failure warning in this
	 * transaction. A rule warns once, on its first failure, however many values it fails on later, so a
	 * bulk trigger batch does not flood the log. Statics reset between transactions.
	 */
	@TestVisible
	private static final Set<String> warnedRuleDeveloperNames
	{
		get
		{
			if(warnedRuleDeveloperNames == null)
			{
				warnedRuleDeveloperNames = new Set<String>();
			}
			return warnedRuleDeveloperNames;
		}
		set;
	}

	/**
	 * @description The values of `SObjectType__c` that point at a log object (`LogEntry__c` or `LogEntryEvent__e`).
	 * A target built in a test stores the object's API name there, so both API names are in the set. A deployed
	 * target stores the object's durable Id instead (the fixed key the platform gives each object; for a custom
	 * object, an Id such as `01I...`), and the API name on its related object is empty when the target is read the
	 * way `SEL_MaskingTarget` reads it. So the set also holds the stored value of every target that the selector
	 * files under a log object. The selector matches those Ids to objects when it loads the targets, so building the
	 * set runs no query of its own. Built on first use and kept for the transaction, so the set is built once per
	 * transaction: a test that swaps the selector's targets must do so before the first warning path runs.
	 */
	private static final Set<String> logObjectTypeValues
	{
		get
		{
			if(logObjectTypeValues == null)
			{
				Set<String> values = new Set<String> {LOG_ENTRY_OBJECT_NAME, LOG_ENTRY_EVENT_OBJECT_NAME};
				SEL_MaskingTarget selector = new SEL_MaskingTarget();
				for(SObjectType logObjectType : new List<SObjectType> {LogEntry__c.SObjectType, LogEntryEvent__e.SObjectType})
				{
					for(MaskingTarget__mdt logObjectTarget : selector.findAllForSObjectType(logObjectType))
					{
						values.add(logObjectTarget.SObjectType__c);
					}
				}
				logObjectTypeValues = values;
			}
			return logObjectTypeValues;
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
	 * @description Cache, for one transaction, of the text fields a wildcard MaskingTarget record (blank Field__c)
	 * covers on each SObjectType (see `getTextFieldsCoveredByWildcard`). The list does not depend on the running
	 * user, so keying it by object alone gives every user in the transaction the same, correct answer.
	 */
	private static final Map<SObjectType, List<SObjectField>> cachedTextFieldsCoveredByWildcard
	{
		get
		{
			if(cachedTextFieldsCoveredByWildcard == null)
			{
				cachedTextFieldsCoveredByWildcard = new Map<SObjectType, List<SObjectField>>();
			}
			return cachedTextFieldsCoveredByWildcard;
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
	 * @description The most characters of whole masked text the masker keeps at one time in a transaction: 1,048,576.
	 * When a masked value is too long for its field, the masker cuts it to fit and keeps the whole masked text, so a
	 * caller can still save all of it in a file (see `takeMaskedValueAnswer`). A text that would take the total past this
	 * number is not kept: the value is answered as DROPPED, and the caller masks the raw value again when it needs the
	 * whole text. The cap keeps the memory used for these copies small next to the heap a transaction can use.
	 */
	public static final Integer REMEMBERED_TEXT_CAP = 1048576;

	/**
	 * @description The longest value the JsonKey rules read as JSON in a synchronous transaction, one that a user or an
	 * API client waits for. Reading JSON takes time: on the slowest shape measured, reading a value of this length one
	 * token at a time takes just under one second, and reading 2,000,000 characters takes about seven seconds. A request
	 * that runs longer than five seconds counts toward a limit the platform sets on long-running requests at the same
	 * time, and new requests are refused once that limit is reached. So in a synchronous transaction a longer value goes
	 * through the quick text search for `"key":"value"` pairs instead (see `UTIL_String.maskJsonKeysViaRegex`). That
	 * search hides every plain value under a matching key. When a matching key holds an object or a list, or the search
	 * cannot read a pair whole, it puts `FAILURE_MARKER` in place of the whole value: the value loses its detail, but nothing secret is saved. A Queueable,
	 * Batch, future or Scheduled job reads the value as JSON at any length.
	 */
	public static final Integer SYNCHRONOUS_JSON_TEXT_PASS_LINE = 196608;

	/**
	 * @description How many characters of whole masked text `rememberedUncutMaskedValuesByKey` holds now. It goes down
	 * when a text is handed over or replaced, so a value masked again is counted once.
	 */
	private static Integer rememberedTextLength = 0;

	/**
	 * @description What the masker did, in this transaction, with each raw value it masked through `FieldMasker.mask` or
	 * the record masker. The key is the field, the caller class (empty when the call named no caller) and the SHA-256
	 * hash of the raw value, so no raw text is kept here. A value is FITTED when its masked text fits in the field (a
	 * value no rule changed included), REMEMBERED when the masked text was cut to fit and the whole text is kept in
	 * `rememberedUncutMaskedValuesByKey`, and DROPPED when it was cut but keeping the whole text would pass the cap. A
	 * value longer than its field that no rule changed has no entry, because the masker cannot say that it fits. Masking
	 * the same raw value again replaces its entry. Read only through `takeMaskedValueAnswer`. Built on first use.
	 */
	private static final Map<String, MaskedValueState> maskedValueStatesByKey
	{
		get
		{
			if(maskedValueStatesByKey == null)
			{
				maskedValueStatesByKey = new Map<String, MaskedValueState>();
			}
			return maskedValueStatesByKey;
		}
		set;
	}

	/**
	 * @description The whole masked text of each value the masker had to cut to fit its field in this transaction, under
	 * the same key as `maskedValueStatesByKey`. Only cut values have an entry, and only while the total stays at or under
	 * the cap. `takeMaskedValueAnswer` hands each text over once and removes it. Built on first use.
	 */
	private static final Map<String, String> rememberedUncutMaskedValuesByKey
	{
		get
		{
			if(rememberedUncutMaskedValuesByKey == null)
			{
				rememberedUncutMaskedValuesByKey = new Map<String, String>();
			}
			return rememberedUncutMaskedValuesByKey;
		}
		set;
	}

	/**
	 * @description The field texts known to be masked already in this transaction. The key is the field, the caller
	 * class (empty when the call named no caller) and the SHA-256 hash of the text, so no text is kept here. Two writers
	 * add to it: `registerMaskedFieldText`, for a text a caller masked itself before the save, and the masker, for the
	 * text it returns or writes after each pass (a value no rule changed included, since masking it again would find
	 * nothing again). Only the record masker reads it: a field whose text is in the set, for the same field and caller,
	 * is left as it is and no rule runs on it. A text that changed since, another field or another caller does not
	 * match, so that text is masked as usual. Built on first use.
	 */
	private static final Set<String> registeredFieldTextKeys
	{
		get
		{
			if(registeredFieldTextKeys == null)
			{
				registeredFieldTextKeys = new Set<String>();
			}
			return registeredFieldTextKeys;
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
	 * @description Returns the text fields on an SObjectType that a wildcard MaskingTarget record (blank Field__c)
	 * covers: every field for which `isCoveredByWildcard` is true. Cached per SObjectType, so describe calls happen
	 * once per transaction.
	 *
	 * The list is the same whoever runs the code. It reads only what each field is, never what the running user may
	 * do with it. The framework saves API calls, API issues and log entries for users who have no access to those
	 * fields (an integration user, for example), so a list built from the user's access would be empty for them, and
	 * their secrets would be stored as they were received.
	 *
	 * A few standard text fields are in the list although no user can change them (for example `Case.ContactEmail`,
	 * which the platform copies from the case's contact). The record masker leaves such a field as it is when the
	 * platform refuses the masked value (see `applyFieldPlanToRecord`).
	 *
	 * @param sObjectType The SObjectType whose fields to list
	 *
	 * @return The fields a wildcard target covers on the SObjectType
	 */
	@TestVisible
	private static List<SObjectField> getTextFieldsCoveredByWildcard(SObjectType sObjectType)
	{
		if(cachedTextFieldsCoveredByWildcard.containsKey(sObjectType))
		{
			return cachedTextFieldsCoveredByWildcard.get(sObjectType);
		}

		List<SObjectField> fields = new List<SObjectField>();

		for(SObjectField field : UTIL_SObjectDescribe.getObjectFieldMap(sObjectType).values())
		{
			if(isCoveredByWildcard(field))
			{
				fields.add(field);
			}
		}

		cachedTextFieldsCoveredByWildcard.put(sObjectType, fields);
		return fields;
	}

	/**
	 * @description Whether a wildcard target (one with a blank `Field__c`) covers the field. All four must be true:
	 *
	 * 1. The field holds text: its type is in `WILDCARD_TEXT_TYPES`.
	 * 2. The field is not a formula, a roll-up or an auto-number. The platform works out those values, and no one
	 *    writes them.
	 * 3. `isExcludedFromWildcard` does not skip it. Unique keys, external ids and the fields the framework needs to
	 *    keep its own data correct are never covered.
	 * 4. On a platform event, the field is a custom field. The platform sets the standard event fields (`ReplayId`,
	 *    `EventUuid`) itself.
	 *
	 * None of these depends on the running user. A field that the running user cannot see or edit is covered in the
	 * same way, because the framework writes the masked value without checking the user's access.
	 *
	 * Fields that identify the record are left out on purpose. Masking rewrites the value it matches. On a key, that
	 * destroys the key. On a unique index, the next record whose key masks to the same fixed value fails to insert (a
	 * chain correlation id that carries a long order number looks like a payment card to the shipped card rule, and
	 * `AsyncChainExecution__c.CorrelationId__c` is unique). A target that names such a field is the administrator's
	 * deliberate choice and is applied; a wildcard must not do it by accident.
	 *
	 * Safe with null: a field that cannot be found is not covered.
	 *
	 * @param field The field token to test; may be null.
	 *
	 * @return `true` when a wildcard target covers the field.
	 */
	public static Boolean isCoveredByWildcard(SObjectField field)
	{
		if(field == null)
		{
			return false;
		}

		DescribeFieldResult describe = UTIL_SObjectDescribe.getCachedFieldDescribe(field);

		return WILDCARD_TEXT_TYPES.contains(describe.getType())
				&& !describe.isCalculated()
				&& !describe.isAutoNumber()
				&& !isExcludedFromWildcard(field)
				&& (describe.isCustom() || !isPlatformEvent(describe.getSObjectType()));
	}

	/**
	 * @description Whether the SObjectType is a platform event (its API name ends in `__e`).
	 *
	 * @param sObjectType The SObjectType to test
	 *
	 * @return `true` for a platform event
	 */
	private static Boolean isPlatformEvent(SObjectType sObjectType)
	{
		return UTIL_SObjectDescribe.getObjectNameFromType(sObjectType).endsWith(UTIL_SObjectDescribe.PLATFORM_EVENT_SUFFIX);
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
	 * form. A deployed target stores the field's durable Id in `Field__c` (the fixed key the platform gives
	 * each field), and neither the selector's normal read nor its fallback query fills in the related
	 * records' API names. So the selector's name for the stored value is used first. A target read by a
	 * query that asks for the API names of SObjectType__r and Field__r uses those, when both names are there.
	 * When either name is missing (a deployed target whose field was deleted reads that way), the stored
	 * `Field__c` value is returned, so the key and the warning text carry the stored durable Ids rather than
	 * `null.null`. Mocked records (TST_Builder) put the qualified text straight into `Field__c`, which is
	 * returned as it is.
	 *
	 * @param target The target whose field path to resolve
	 *
	 * @return The qualified field path (e.g. `ApiCall__c.Request__c`)
	 */
	@TestVisible
	private static String resolveQualifiedFieldName(MaskingTarget__mdt target)
	{
		String selectorName = SEL_MaskingTarget.getQualifiedFieldName(target);
		if(selectorName != null)
		{
			return selectorName;
		}
		if(target.Field__r?.QualifiedApiName != null && target.SObjectType__r?.QualifiedApiName != null)
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
		String objectName = UTIL_SObjectDescribe.getObjectNameFromType(UTIL_SObjectDescribe.getCachedFieldDescribe(field).getSObjectType());
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
	 * Targets whose caller does not match, or whose Log and Continue rule has failed and been turned off
	 * in this transaction, are skipped first.
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
						.withFingerprintInternal(UNKNOWN_FIELD_TYPE_FINGERPRINT_PREFIX + ruleName)
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
			warnSpecificFieldMismatchOnce(target, fieldType);
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
	 * @param fieldType The candidate field's DisplayType (for the "rejected types" detail).
	 */
	private static void warnSpecificFieldMismatchOnce(MaskingTarget__mdt target, DisplayType fieldType)
	{
		if(String.isBlank(target.Field__c) || isLogEntryTarget(target))
		{
			return;
		}

		MaskingRule__mdt rule = ruleFor(target);
		String ruleName = rule.DeveloperName;
		String qualifiedFieldName = resolveQualifiedFieldName(target);
		String warningKey = EXCLUDED_FIELD_TYPE_FINGERPRINT_PREFIX + ruleName + UTIL_String.COLON + qualifiedFieldName;
		if(warnedSpecificFieldTypeMismatches.contains(warningKey))
		{
			return;
		}
		warnedSpecificFieldTypeMismatches.add(warningKey);

		LOG_Builder.build()
				.warn
						('MaskingTarget wires rule ' + ruleName + ' to field ' + qualifiedFieldName +
								' but the rule\'s ApplicableFieldTypes__c = \'' + rule.ApplicableFieldTypes__c +
								'\' excludes ' + fieldType + ' fields. The rule will not run on this field: ' +
								'either widen ApplicableFieldTypes__c to include ' + fieldType + ' or remove the target.'
						)
				.withFingerprintInternal(warningKey)
				.emitAt(UTIL_FrameworkMasker.class.getName() + '.filterTargetsByFieldType');
	}

	/**
	 * @description Skips a field for the rest of the transaction after the platform refused a masked value for it, and
	 * writes a warning. The field joins `fieldsThePlatformRefusesToWrite`, so the record masker returns before any rule
	 * runs on it again. That is also why the warning is written once per field per transaction. No warning is written
	 * while a log entry or a log event is being masked: a warning written then would publish another log event, which
	 * would be masked in turn (the reason `LOG_ENTRY_OBJECT_NAME` gives).
	 *
	 * @param fieldPlan The plan of the field the platform refused to write.
	 * @param sObjectType The type of the record being masked.
	 * @param writeError The error the platform raised.
	 */
	private static void skipFieldThePlatformRefusesToWrite(FieldPlan fieldPlan, SObjectType sObjectType, System.SObjectException writeError)
	{
		fieldsThePlatformRefusesToWrite.add(fieldPlan.field);

		if(sObjectType != LogEntry__c.SObjectType && sObjectType != LogEntryEvent__e.SObjectType)
		{
			LOG_Builder.build()
					.warn
							('The masker could not write the masked value to ' + fieldPlan.qualifiedFieldName + ', because no user can change this field ('
									+ writeError.getMessage() + '). The field keeps its value, and the masker skips it for the rest of this transaction. '
									+ 'A save cannot change the field either, so nothing new is stored without masking.'
							)
					.withFingerprintInternal(WRITE_REFUSED_FINGERPRINT_PREFIX + fieldPlan.qualifiedFieldName)
					.emitAt(UTIL_FrameworkMasker.class.getName() + '.applyFieldPlanToRecord');
		}
	}

	/**
	 * @description Records that a rule has thrown on one value, then acts on its `FailureAction__c`.
	 * Records the failure on the MaskingResult and writes a warning log once per rule per transaction,
	 * unless the target is a LogEntry type (which could start a logging loop across transactions). Then
	 * applies the configured action:
	 *
	 * - Log and Continue (also used when the action is blank): the value is saved as it is, and the rule
	 *   is skipped for the rest of the transaction, so later values it covers are saved as they are too.
	 * - Write Failure Marker: `FAILURE_MARKER` is saved in place of the value, and the rule is never
	 *   skipped. If its pattern cannot compile, the rule can never mask anything, so every later value it
	 *   covers gets the marker without running it. If its pattern compiles, the failure belongs to this
	 *   value only, and the rule keeps running on the other values.
	 * - Block DML: throws `MaskingBlockedException` so the caller around it (usually a trigger guard)
	 *   stops the DML. The rule keeps blocking for the whole transaction: every later call that meets it
	 *   throws again.
	 *
	 * The compile check runs only here, after a failure, so a rule that works pays nothing for it.
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

		recordRuleFailure(ruleName, result);
		logRuleFailureWarning(target, ruleName);

		if(failureAction == SEL_MaskingRule.FAILURE_BLOCK_DML)
		{
			throw new UTIL_Exceptions.MaskingBlockedException('Masking rule ' + ruleName + ' failed and is configured to block DML');
		}

		if(failureAction == SEL_MaskingRule.FAILURE_WRITE_FAILURE_MARKER)
		{
			result.maskedValue = FAILURE_MARKER;

			if(PATTERN_MODES.contains(rule.Mode__c) && !UTIL_String.canCompilePattern(rule.Pattern__c, rule.CaseSensitive__c == true))
			{
				brokenPatternRuleDeveloperNames.add(ruleName);
			}
			return;
		}

		invalidatedRuleDeveloperNames.add(ruleName);
	}

	/**
	 * @description Marks the result as failed by the named rule: sets `hadErrors` and adds the rule to
	 * `failedRuleDeveloperNames`, so a caller that reads the result sees which rule failed.
	 *
	 * @param ruleName The DeveloperName of the rule that failed
	 * @param result The MaskingResult being built
	 */
	private static void recordRuleFailure(String ruleName, MaskingResult result)
	{
		result.hadErrors = true;
		result.failedRuleDeveloperNames.add(ruleName);
	}

	/**
	 * @description Puts `FAILURE_MARKER` in place of the value for a Write Failure Marker rule whose
	 * pattern cannot compile, without running the rule and without warning again. The result records the
	 * error the same way the first failure did. A blank value stays as it is, because there is nothing in
	 * it to hide. An earlier rule on the same value can leave it blank. The caller decides which values
	 * the rule covers, exactly as when the rule works: `applySingleTargetStatic` leaves a value shorter
	 * than the rule's `MinInputLength__c` alone before it gets here, and the JSON path, which does not
	 * read that minimum when a rule works, does not read it here either.
	 *
	 * @param rule The rule whose pattern cannot compile
	 * @param result The MaskingResult being built
	 */
	private static void markValueOfBrokenPatternRule(MaskingRule__mdt rule, MaskingResult result)
	{
		if(String.isBlank(result.maskedValue))
		{
			return;
		}

		result.maskedValue = FAILURE_MARKER;
		recordRuleFailure(rule.DeveloperName, result);
	}

	/**
	 * @description Checks whether a value is shorter than the rule's `MinInputLength__c`. A rule with no
	 * minimum, or a minimum of zero, looks at every value.
	 *
	 * @param rule The rule whose minimum input length to read
	 * @param value The value to measure; a null value counts as shorter when the rule has a minimum
	 *
	 * @return True when the rule has a minimum and the value is shorter than it
	 */
	private static Boolean isShorterThanMinimumInputLength(MaskingRule__mdt rule, String value)
	{
		Decimal minInputLength = rule.MinInputLength__c;
		return minInputLength != null && minInputLength > 0 && (value == null || value.length() < minInputLength);
	}

	/**
	 * @description Writes a warning log about a failed masking rule, once per rule per transaction. Writes
	 * nothing when the target object is `LogEntry__c` or `LogEntryEvent__e`: the log entry LOG_Builder
	 * would publish creates a new LogEntry or event, which runs the masker again in a later transaction,
	 * and that can easily become an endless loop across transactions. The warning says what each failure
	 * action does next, so an admin who reads it knows what was saved. It carries a flood-control key named
	 * after the rule, so a rule that fails on every save fills one detail row and a daily counter, not the log.
	 *
	 * @param target The target whose rule threw
	 * @param ruleName The rule's DeveloperName
	 */
	private static void logRuleFailureWarning(MaskingTarget__mdt target, String ruleName)
	{
		if(isLogEntryTarget(target) || warnedRuleDeveloperNames.contains(ruleName))
		{
			return;
		}
		warnedRuleDeveloperNames.add(ruleName);

		String failureAction = ruleFor(target).FailureAction__c ?? SEL_MaskingRule.FAILURE_LOG_AND_CONTINUE;

		LOG_Builder.build()
				.warn
						('Masking rule ' + ruleName + ' failed. Its failure action is ' + failureAction + '. ' +
								'With LogAndContinue, the value is saved as it is and the rule is skipped for the rest of the transaction. ' +
								'With WriteFailureMarker, ' + FAILURE_MARKER + ' is saved in place of each value the rule fails on, ' +
								'and the rule keeps running on the other values. ' +
								'With BlockDml, this save is refused, and so is every later save the rule meets. ' +
								'This warning is written once for each rule in a transaction.'
						)
				.withFingerprintInternal(RULE_FAILURE_FINGERPRINT_PREFIX + ruleName)
				.emitAt(UTIL_FrameworkMasker.class.getName() + '.handleRuleFailure');
	}

	/**
	 * @description Reports whether the target points at a log object (`LogEntry__c` or
	 * `LogEntryEvent__e`). Every warning this class writes checks this first, because none of them may
	 * be written while a log entry is being masked. It reads the stored value of `SObjectType__c`, which
	 * is an API name on a test target and the object's durable Id on a deployed one. A target with none (the one `maskValueAgainstRule` builds for a preview) is not on a log
	 * object, and the check returns before it loads anything. Visible to tests, so the check that stops
	 * the logging loop can be asserted without setting up LOG_Builder.
	 *
	 * @param target The target to inspect
	 *
	 * @return True if the target's object is `LogEntry__c` or `LogEntryEvent__e`
	 */
	@TestVisible
	private static Boolean isLogEntryTarget(MaskingTarget__mdt target)
	{
		return String.isNotBlank(target.SObjectType__c) && logObjectTypeValues.contains(target.SObjectType__c);
	}

	/**
	 * @description Applies one MaskingTarget's rule to a value, calling the UTIL_String helper that
	 * matches the rule's Mode. A JsonKey rule on a long JSON value in a synchronous transaction calls the
	 * quick text search, `UTIL_String.maskJsonKeysViaRegex`, instead of reading the value as JSON (see
	 * `shouldTakeJsonTextPass`).
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

		if(mode == SEL_MaskingRule.MODE_JSON_KEY && shouldTakeJsonTextPass(value))
		{
			return UTIL_String.maskJsonKeysViaRegex(value, rulePattern, replacement, caseSensitive);
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
		 * @description The field's `Object.Field` name, as `getQualifiedFieldName` builds it. It is the field part of the
		 * keys the masker uses to remember values and registered texts (see `buildMaskedValueKey`). Worked out once per
		 * plan, so the record masker does not describe the field again for every record.
		 */
		private String qualifiedFieldName;

		/**
		 * @description Applicable targets whose rule Mode is JsonKey, filtered in advance. Applied together by
		 * `applyJsonKeyBatchStatic`.
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
	 * fields (turning wildcards into fields through `getTextFieldsCoveredByWildcard`), then for each field
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
			for(SObjectField wildcardField : getTextFieldsCoveredByWildcard(sObjectType))
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
			fieldPlan.qualifiedFieldName = getQualifiedFieldName(field);

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
	 * @description Masks one field value with a FieldPlan built in advance. Applies the JsonKey rules together
	 * (see `applyJsonKeyBatchStatic`), then applies the other rules one after another. Once a rule puts
	 * `FAILURE_MARKER` in place of the value, no later rule runs on it (see `hasFailureMarker`). Cuts the value
	 * to the field's maximum length when a rule matched or when the value holds `FAILURE_MARKER`. The marker is
	 * cut too, so a field shorter than the marker still saves: the value stays hidden and the save does not fail
	 * because the text is too long. The callers (`FieldMasker.mask` and
	 * `RecordMasker.applyFieldPlanToRecord`) already skip null and empty values before they call this
	 * method.
	 *
	 * This method remembers nothing. The masking console's preview (`maskValueAgainstRule`) runs one rule through it,
	 * and a one-rule result must never tell a later pass that a value is already masked. The two real masking calls go
	 * through `maskAndRememberValue`, which runs the same steps and then records what it did.
	 *
	 * @param fieldPlan The field plan, built in advance
	 * @param rawValue The current field value
	 *
	 * @return The MaskingResult after all rules run; `maskedValue` equals input when nothing matched
	 */
	private static MaskingResult maskValueWithPlan(FieldPlan fieldPlan, String rawValue)
	{
		MaskingResult result = applyPlanRules(fieldPlan, rawValue);
		cutToFieldLength(fieldPlan.field, result);
		return result;
	}

	/**
	 * @description Masks one field value with a FieldPlan built in advance, as `maskValueWithPlan` does, and then records
	 * what it did for the rest of the transaction, so a save masks each value once:
	 *
	 * 1. Under the field, the caller and the hash of the raw value, it records whether the masked text fits in the field
	 *    (FITTED), was cut and its whole text is kept (REMEMBERED), or was cut and the whole text would pass the cap
	 *    (DROPPED). See `recordMaskedValueState`; `takeMaskedValueAnswer` reads it.
	 * 2. It registers the hash of the text it returns, under the field and the caller, so a record pass that later finds
	 *    this text in the field leaves it as it is (see `registeredFieldTextKeys`).
	 *
	 * A Block DML rule that fails throws before either step, so nothing is recorded for a value whose save is refused.
	 * A raw value made only of spaces has no hash, so nothing is recorded for it.
	 *
	 * @param fieldPlan The field plan, built in advance, with `qualifiedFieldName` set
	 * @param callerClassName The caller class the plan was built for; null or empty when the call named none
	 * @param rawValue The current field value, never null or empty
	 * @param rawValueHash The SHA-256 hash of `rawValue`, or null when it is only spaces
	 *
	 * @return The MaskingResult after all rules run; `maskedValue` equals input when nothing matched
	 *
	 * @throws UTIL_Exceptions.MaskingBlockedException when a rule with FailureAction = BlockDml fails
	 */
	@SuppressWarnings('PMD.ExcessiveParameterList')
	private static MaskingResult maskAndRememberValue(FieldPlan fieldPlan, String callerClassName, String rawValue, String rawValueHash)
	{
		MaskingResult result = maskAndRegisterValue(fieldPlan, callerClassName, rawValue, rawValueHash);

		if(rawValueHash != null)
		{
			String valueKey = buildMaskedValueKey(fieldPlan.qualifiedFieldName, callerClassName, rawValueHash);
			recordMaskedValueState(valueKey, result.uncutMaskedValue, isWithinFieldLength(fieldPlan.field, result.maskedLength));
		}

		result.uncutMaskedValue = null;
		return result;
	}

	/**
	 * @description Masks one field value as `maskAndRememberValue` does, but hands the whole masked text to the caller
	 * in `MaskingResult.uncutMaskedValue` instead of keeping it, so a text of any length reaches the caller, even one
	 * past `REMEMBERED_TEXT_CAP`. The hash of the returned text is registered as usual. What the masker records about the
	 * raw value:
	 *
	 * - The masked text fits in the field: FITTED, as `maskAndRememberValue` records it.
	 * - The masked text was cut, or the value is longer than the field and no rule changed it: no entry, so the value
	 *   answers NOT_SEEN, as after `takeMaskedValueAnswer` has handed a remembered text over. The caller holds the
	 *   whole text.
	 *
	 * @param fieldPlan The field plan, built in advance, with `qualifiedFieldName` set
	 * @param callerClassName The caller class the plan was built for; null or empty when the call named none
	 * @param rawValue The current field value, never null or empty
	 * @param rawValueHash The SHA-256 hash of `rawValue`, or null when it is only spaces
	 *
	 * @return The MaskingResult after all rules run; `uncutMaskedValue` holds the whole masked text when it was cut
	 *
	 * @throws UTIL_Exceptions.MaskingBlockedException when a rule with FailureAction = BlockDml fails
	 */
	@SuppressWarnings('PMD.ExcessiveParameterList')
	private static MaskingResult maskAndHandOverWholeText(FieldPlan fieldPlan, String callerClassName, String rawValue, String rawValueHash)
	{
		MaskingResult result = maskAndRegisterValue(fieldPlan, callerClassName, rawValue, rawValueHash);

		if(rawValueHash != null)
		{
			String valueKey = buildMaskedValueKey(fieldPlan.qualifiedFieldName, callerClassName, rawValueHash);
			recordMaskedValueState(valueKey, null, result.uncutMaskedValue == null && isWithinFieldLength(fieldPlan.field, result.maskedLength));
		}

		return result;
	}

	/**
	 * @description Runs every rule of a FieldPlan on one value, cuts the result to the field's length when needed and
	 * registers the hash of the text it returns, under the field and the caller, so a record pass that later finds this
	 * text in the field leaves it as it is (see `registeredFieldTextKeys`). When the text was cut, the whole masked text
	 * is put in `MaskingResult.uncutMaskedValue` for the method that called this one. Records nothing about the raw
	 * value: `maskAndRememberValue` and `maskAndHandOverWholeText` do that next.
	 *
	 * @param fieldPlan The field plan, built in advance, with `qualifiedFieldName` set
	 * @param callerClassName The caller class the plan was built for; null or empty when the call named none
	 * @param rawValue The current field value, never null or empty
	 * @param rawValueHash The SHA-256 hash of `rawValue`, or null when it is only spaces
	 *
	 * @return The MaskingResult after all rules run
	 *
	 * @throws UTIL_Exceptions.MaskingBlockedException when a rule with FailureAction = BlockDml fails
	 */
	@SuppressWarnings('PMD.ExcessiveParameterList')
	private static MaskingResult maskAndRegisterValue(FieldPlan fieldPlan, String callerClassName, String rawValue, String rawValueHash)
	{
		MaskingResult result = applyPlanRules(fieldPlan, rawValue);
		String uncutMaskedValue = result.maskedValue;

		if(cutToFieldLength(fieldPlan.field, result))
		{
			result.uncutMaskedValue = uncutMaskedValue;
		}

		String maskedValueHash = rawValue.equals(result.maskedValue) ? rawValueHash : UTIL_Crypto.generateSHA256Hash(result.maskedValue);
		if(maskedValueHash != null)
		{
			registeredFieldTextKeys.add(buildMaskedValueKey(fieldPlan.qualifiedFieldName, callerClassName, maskedValueHash));
		}

		return result;
	}

	/**
	 * @description Runs every rule of a FieldPlan on one value: the JsonKey rules together (see `applyJsonKeyBatchStatic`),
	 * then the other rules one after another. Cuts nothing; `cutToFieldLength` does that next.
	 *
	 * @param fieldPlan The field plan, built in advance
	 * @param rawValue The current field value
	 *
	 * @return The MaskingResult after all rules run, with the masked value not yet cut
	 */
	private static MaskingResult applyPlanRules(FieldPlan fieldPlan, String rawValue)
	{
		MaskingResult result = newResult(rawValue);

		applyJsonKeyBatchStatic(fieldPlan.jsonKeyTargets, result);
		applyTargetsUntilValueIsMarked(fieldPlan.otherTargets, result);

		return result;
	}

	/**
	 * @description Cuts the masked value to the field's maximum length when a rule matched or the value holds
	 * `FAILURE_MARKER`, and sets `maskedLength`. A value no rule changed is never cut, even when it is longer than the
	 * field.
	 *
	 * @param field The field the value is saved to; supplies the length limit
	 * @param result The MaskingResult after all rules ran (changed in place)
	 *
	 * @return True when the masked value was cut
	 */
	private static Boolean cutToFieldLength(SObjectField field, MaskingResult result)
	{
		Boolean wasCut = false;

		if(result.rulesMatched > 0 || hasFailureMarker(result))
		{
			DescribeFieldResult fieldDescribe = UTIL_SObjectDescribe.getCachedFieldDescribe(field);
			Integer maxLength = fieldDescribe.getLength();

			if(maxLength > 0 && result.maskedValue != null && result.maskedValue.length() > maxLength)
			{
				result.maskedValue = UTIL_String.abbreviate(result.maskedValue, field);
				wasCut = true;
			}
		}

		result.maskedLength = result.maskedValue?.length() ?? 0;
		return wasCut;
	}

	/**
	 * @description Checks whether a text of the given length fits in the field. A field that reports no length limit
	 * holds any length.
	 *
	 * @param field The field the text is saved to
	 * @param textLength The number of characters in the text
	 *
	 * @return True when the text fits in the field
	 */
	private static Boolean isWithinFieldLength(SObjectField field, Integer textLength)
	{
		Integer maxLength = UTIL_SObjectDescribe.getCachedFieldDescribe(field).getLength();
		return maxLength <= 0 || textLength <= maxLength;
	}

	/**
	 * @description Records what the masker did with one raw value, under its key, and replaces what was recorded before
	 * under the same key. A text kept before under the key is removed first and its length taken off the total, so a
	 * value masked again (a retry, for example) counts once against the cap.
	 *
	 * - The value was cut and the total stays at or under the cap with its whole text: the text is kept, REMEMBERED.
	 * - The value was cut and its whole text would take the total past the cap: nothing is kept, DROPPED.
	 * - The value was not cut and fits in the field: FITTED.
	 * - The value was not cut and is longer than the field (no rule changed it): no entry, so it answers NOT_SEEN.
	 *
	 * @param valueKey The key from `buildMaskedValueKey` for the field, the caller and the raw value
	 * @param uncutMaskedValue The whole masked text when the value was cut; null when it was not cut
	 * @param fitsInField True when the returned value fits in the field
	 */
	private static void recordMaskedValueState(String valueKey, String uncutMaskedValue, Boolean fitsInField)
	{
		forgetRememberedText(valueKey);
		maskedValueStatesByKey.remove(valueKey);

		if(uncutMaskedValue != null && rememberedTextLength + uncutMaskedValue.length() <= REMEMBERED_TEXT_CAP)
		{
			rememberedUncutMaskedValuesByKey.put(valueKey, uncutMaskedValue);
			rememberedTextLength += uncutMaskedValue.length();
			maskedValueStatesByKey.put(valueKey, MaskedValueState.REMEMBERED);
		}
		else if(uncutMaskedValue != null)
		{
			maskedValueStatesByKey.put(valueKey, MaskedValueState.DROPPED);
		}
		else if(fitsInField)
		{
			maskedValueStatesByKey.put(valueKey, MaskedValueState.FITTED);
		}
	}

	/**
	 * @description Removes the whole masked text kept under a key, if there is one, and takes its length off the total.
	 *
	 * @param valueKey The key from `buildMaskedValueKey`
	 *
	 * @return The text that was kept, or null when none was
	 */
	private static String forgetRememberedText(String valueKey)
	{
		String rememberedText = rememberedUncutMaskedValuesByKey.remove(valueKey);

		if(rememberedText != null)
		{
			rememberedTextLength -= rememberedText.length();
		}

		return rememberedText;
	}

	/**
	 * @description Builds the key under which the masker remembers a value or registers a text: the field's
	 * `Object.Field` name, the caller class and the SHA-256 hash of the text, joined by `|`. A missing caller is written
	 * as the empty string, so a call with no caller and a call with an empty caller name use the same key.
	 *
	 * @param qualifiedFieldName The field's `Object.Field` name, from `getQualifiedFieldName`
	 * @param callerClassName The caller class; null or empty when the call named none
	 * @param textHash The SHA-256 hash of the text
	 *
	 * @return The key
	 */
	private static String buildMaskedValueKey(String qualifiedFieldName, String callerClassName, String textHash)
	{
		return qualifiedFieldName + UTIL_String.PIPE + (callerClassName ?? UTIL_String.EMPTY) + UTIL_String.PIPE + textHash;
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
	 * @description Applies every JsonKey rule to the value. `UTIL_String.maskJsonKeys` takes the same steps except the
	 * second one below: that method never sends a value to the text search because of its length or the kind of
	 * transaction. So a rule gives the same result here and in that method, except for a value longer than
	 * `SYNCHRONOUS_JSON_TEXT_PASS_LINE` in a synchronous transaction, which only this method reads with the text search.
	 *
	 * - A value without the outline of a JSON object or list (see `UTIL_String.hasJsonObjectOrArrayShape`) goes
	 *   through the rules one at a time, each with its text search for `"key":"value"` pairs. This includes a value
	 *   that starts like JSON but has more text after its end; the text search keeps it masked or marked.
	 * - In a synchronous transaction, a value longer than `SYNCHRONOUS_JSON_TEXT_PASS_LINE` goes through the
	 *   rules one at a time, each with the quick text search (see `shouldTakeJsonTextPass`). Reading it as JSON
	 *   would take too long while the user or the API client waits.
	 * - A value with more opening brackets than `UTIL_String.JSON_STRUCTURE_LINE` is read one token at a time
	 *   (see `applyJsonKeyRulesAsStream`).
	 * - Any other value is read once as a whole tree, and every rule walks that tree (see
	 *   `applyJsonKeyRulesToTree`).
	 *
	 * On both JSON paths a rule skips the value when no key name it matches can be in the text (see
	 * `UTIL_String.canHoldMatchingJsonKey`). A Write Failure Marker rule whose pattern cannot compile does not run: the
	 * value gets `FAILURE_MARKER` instead (see `markValueOfBrokenPatternRule`). Once the value holds the marker, the later
	 * rules do not run and no masked JSON is written over the marker.
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

		if(!UTIL_String.hasJsonObjectOrArrayShape(result.maskedValue) || shouldTakeJsonTextPass(result.maskedValue))
		{
			applyTargetsUntilValueIsMarked(jsonKeyTargets, result);
			return;
		}

		if(UTIL_String.exceedsJsonStructureLine(result.maskedValue))
		{
			applyJsonKeyRulesAsStream(jsonKeyTargets, result);
			return;
		}

		applyJsonKeyRulesToTree(jsonKeyTargets, result);
	}

	/**
	 * @description Checks whether a JsonKey rule must use the quick text search on a value instead of reading it as
	 * JSON: the value is longer than `SYNCHRONOUS_JSON_TEXT_PASS_LINE` and the transaction is synchronous (see
	 * `isAsynchronousTransaction`).
	 *
	 * @param value The value to mask
	 *
	 * @return True when the value takes the text search
	 */
	private static Boolean shouldTakeJsonTextPass(String value)
	{
		return value != null && value.length() > SYNCHRONOUS_JSON_TEXT_PASS_LINE && !isAsynchronousTransaction();
	}

	/**
	 * @description Checks whether the running transaction is asynchronous: a Queueable, Batch, future or Scheduled job.
	 * Nobody waits for such a job, so it can take the time to read a long JSON value as JSON. Every other transaction
	 * counts as synchronous. Treating a transaction as synchronous by mistake costs detail (the failure marker in place of
	 * an object under a secret key), never a secret.
	 *
	 * @return True when the platform runs the transaction as a Queueable, Batch, future or Scheduled job
	 */
	private static Boolean isAsynchronousTransaction()
	{
		return System.isQueueable() || System.isBatch() || System.isFuture() || System.isScheduled();
	}

	/**
	 * @description Applies the JsonKey rules to a value with at most `UTIL_String.JSON_STRUCTURE_LINE` opening brackets,
	 * with one parse and one serialize. The value is read as a tree only when the first rule that can match needs it,
	 * so a value in which no rule can match is not read at all. Every rule then walks the same tree, in rule order. The
	 * walk stops 50 levels deep. The `mutated` flag and `replacementCount` on `UTIL_String.JsonKeyMaskResult` show each
	 * rule's changes, and the tree is written back to text once, at the end, only when a rule changed it. When the JSON
	 * reader refuses the value, the rules go one at a time through the text search instead.
	 *
	 * @param jsonKeyTargets Targets in rule order whose mode is JsonKey
	 * @param result The MaskingResult being built (changed as rules run)
	 */
	private static void applyJsonKeyRulesToTree(List<MaskingTarget__mdt> jsonKeyTargets, MaskingResult result)
	{
		String originalValue = result.maskedValue;
		Object parsed = null;
		Boolean isParsed = false;
		Boolean anyRuleMatched = false;

		for(MaskingTarget__mdt target : jsonKeyTargets)
		{
			MaskingRule__mdt rule = ruleFor(target);

			if(!shouldRunJsonKeyRule(rule, result))
			{
				continue;
			}

			if(!isParsed)
			{
				try
				{
					parsed = JSON.deserializeUntyped(originalValue);
					isParsed = true;
				}
				catch(System.JSONException parseError)
				{
					applyTargetsUntilValueIsMarked(jsonKeyTargets, result);
					return;
				}
			}

			try
			{
				Boolean caseSensitive = rule.CaseSensitive__c == true;
				String replacement = rule.Replacement__c ?? UTIL_String.EMPTY;

				UTIL_String.JsonKeyMaskResult mutation = UTIL_String.applyJsonKeyRuleToTreeWithCount(parsed, rule.Pattern__c, replacement, caseSensitive);
				parsed = mutation.tree;

				if(mutation.mutated)
				{
					anyRuleMatched = true;
					recordJsonKeyRuleMatch(rule, mutation.replacementCount, result);
				}
			}
			catch(Exception ruleError)
			{
				handleRuleFailure(target, result);
			}
		}

		if(anyRuleMatched && !hasFailureMarker(result))
		{
			result.maskedValue = JSON.serialize(parsed);
		}
	}

	/**
	 * @description Applies the JsonKey rules to a value with more than `UTIL_String.JSON_STRUCTURE_LINE` opening
	 * brackets. Such a value is never read as a whole tree: a deep one would end the transaction. Each rule reads it
	 * one token at a time with `UTIL_String.maskJsonKeysStreaming`, in rule order, each on the output of the rule before,
	 * so a later rule sees the replacements of an earlier one. Each rule's own number of replacements is counted. One
	 * pass with all patterns together would not show which rule matched a key that two patterns match. When the JSON
	 * reader refuses the value, the rules go one at a time through the text search instead. This can only happen at the
	 * first rule that reads the value, because a rule that reads it to the end has proved the value is valid JSON, so no
	 * rule has changed the value yet.
	 *
	 * @param jsonKeyTargets Targets in rule order whose mode is JsonKey
	 * @param result The MaskingResult being built (changed as rules run)
	 */
	private static void applyJsonKeyRulesAsStream(List<MaskingTarget__mdt> jsonKeyTargets, MaskingResult result)
	{
		for(MaskingTarget__mdt target : jsonKeyTargets)
		{
			MaskingRule__mdt rule = ruleFor(target);

			if(!shouldRunJsonKeyRule(rule, result))
			{
				continue;
			}

			try
			{
				Boolean caseSensitive = rule.CaseSensitive__c == true;
				String replacement = rule.Replacement__c ?? UTIL_String.EMPTY;

				UTIL_String.JsonKeyMaskResult mutation = UTIL_String.maskJsonKeysStreaming(result.maskedValue, rule.Pattern__c, replacement, caseSensitive);

				if(mutation.mutated)
				{
					result.maskedValue = mutation.maskedText;
					recordJsonKeyRuleMatch(rule, mutation.replacementCount, result);
				}
			}
			catch(System.JSONException parseError)
			{
				applyTargetsUntilValueIsMarked(jsonKeyTargets, result);
				return;
			}
			catch(Exception ruleError)
			{
				handleRuleFailure(target, result);
			}
		}
	}

	/**
	 * @description Decides whether a JsonKey rule runs on the value. A rule does not run when the value already holds
	 * `FAILURE_MARKER`, when the rule was set aside for this transaction, or when no key name it matches can be in the
	 * value (see `UTIL_String.canHoldMatchingJsonKey`). A Write Failure Marker rule whose pattern cannot compile does not
	 * run either: it puts `FAILURE_MARKER` in place of the value (see `markValueOfBrokenPatternRule`).
	 *
	 * @param rule The JsonKey rule
	 * @param result The MaskingResult being built (changed when the rule marks the value)
	 *
	 * @return True when the rule must read the value
	 */
	private static Boolean shouldRunJsonKeyRule(MaskingRule__mdt rule, MaskingResult result)
	{
		if(hasFailureMarker(result) || invalidatedRuleDeveloperNames.contains(rule.DeveloperName))
		{
			return false;
		}

		if(brokenPatternRuleDeveloperNames.contains(rule.DeveloperName))
		{
			markValueOfBrokenPatternRule(rule, result);
			return false;
		}

		return UTIL_String.canHoldMatchingJsonKey(result.maskedValue, rule.Pattern__c);
	}

	/**
	 * @description Records on the result that a JsonKey rule replaced values: one more rule matched, its replacements
	 * are added to `valuesRedacted`, and its name is added to `matchedRuleDeveloperNames`.
	 *
	 * @param rule The rule that matched
	 * @param replacementCount How many values the rule replaced
	 * @param result The MaskingResult being built
	 */
	private static void recordJsonKeyRuleMatch(MaskingRule__mdt rule, Integer replacementCount, MaskingResult result)
	{
		result.rulesMatched++;
		result.valuesRedacted += replacementCount;
		result.matchedRuleDeveloperNames.add(rule.DeveloperName);
	}

	/**
	 * @description Checks whether a rule has already put `FAILURE_MARKER` in place of the value. The marker is final:
	 * once a value holds it, no later rule runs on that value, whatever the rule's failure action, and the JSON path
	 * does not write its masked JSON over it. The marker holds no secret, so nothing unmasked is saved when the later
	 * rules do not run. A Block DML rule that is not run here still refuses the next value that is not marked.
	 *
	 * @param result The MaskingResult being built
	 *
	 * @return True when the value now holds the failure marker
	 */
	private static Boolean hasFailureMarker(MaskingResult result)
	{
		return FAILURE_MARKER.equals(result.maskedValue);
	}

	/**
	 * @description Applies the targets one after another, in the order given, and stops as soon as the value holds
	 * `FAILURE_MARKER` (see `hasFailureMarker`). The rules still to run are not run on the marker.
	 *
	 * @param targets The targets to apply, in rule order
	 * @param result The MaskingResult being built (changed as rules run)
	 */
	private static void applyTargetsUntilValueIsMarked(List<MaskingTarget__mdt> targets, MaskingResult result)
	{
		for(MaskingTarget__mdt target : targets)
		{
			if(hasFailureMarker(result))
			{
				return;
			}
			applySingleTargetStatic(target, result);
		}
	}

	/**
	 * @description Applies one target that is not JsonKey (Regex or ExactMatch) to the result being
	 * built. Catches rule exceptions and records them in `hadErrors` and `failedRuleDeveloperNames`. A
	 * Write Failure Marker rule whose pattern cannot compile does not run: the value gets
	 * `FAILURE_MARKER` instead (see `markValueOfBrokenPatternRule`).
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

		if(isShorterThanMinimumInputLength(rule, result.maskedValue))
		{
			return;
		}

		if(brokenPatternRuleDeveloperNames.contains(rule.DeveloperName))
		{
			markValueOfBrokenPatternRule(rule, result);
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
	 * @description Tells a caller what the masker did, earlier in this transaction, with a raw value it masked for the
	 * same field and caller class (through `forField(...).mask` or a record pass). The caller uses the answer to decide
	 * whether it must mask the raw value again, for example to save the whole masked text in a file:
	 *
	 * - NOT_SEEN: no pass masked this raw value for this field and caller, or its whole text was already handed over. A
	 *   value that no rule changed and that is longer than the field answers NOT_SEEN too: the masker keeps nothing for
	 *   it. Mask the raw value again if you need the masked text.
	 * - FITTED: the masked text fits in the field, so the field holds all of it. A value no rule changed that fits in the
	 *   field is FITTED too.
	 * - REMEMBERED: the masked text was cut to fit the field, and `uncutMaskedValue` holds all of it. The text is handed
	 *   over once and then removed, so a second call for the same value answers NOT_SEEN.
	 * - DROPPED: the masked text was cut, but keeping all of it would have passed `REMEMBERED_TEXT_CAP`. Mask the raw
	 *   value again if you need the whole text.
	 *
	 * The masker keeps only a hash of the raw value, never the raw text. A text kept for one field or caller is never
	 * handed over for another field or caller.
	 *
	 * @param field The field the value was masked for
	 * @param callerClassName The caller class the value was masked for; null or empty for a pass that named none
	 * @param rawValue The raw value, exactly as it was masked
	 *
	 * @return The answer, never null; `uncutMaskedValue` is set only when the state is REMEMBERED
	 *
	 * @example
	 * ```apex
	 * UTIL_FrameworkMasker.MaskedValueAnswer answer = UTIL_FrameworkMasker.takeMaskedValueAnswer(ApiCall__c.Request__c, 'API_SendEmail', rawBody);
	 * if(answer.state == UTIL_FrameworkMasker.MaskedValueState.REMEMBERED)
	 * {
	 *     String wholeMaskedBody = answer.uncutMaskedValue;
	 * }
	 * ```
	 */
	public static MaskedValueAnswer takeMaskedValueAnswer(SObjectField field, String callerClassName, String rawValue)
	{
		MaskedValueAnswer answer = new MaskedValueAnswer();
		answer.state = MaskedValueState.NOT_SEEN;

		String rawValueHash = field == null ? null : UTIL_Crypto.generateSHA256Hash(rawValue);
		if(rawValueHash == null)
		{
			return answer;
		}

		String valueKey = buildMaskedValueKey(getQualifiedFieldName(field), callerClassName, rawValueHash);
		answer.state = maskedValueStatesByKey.get(valueKey) ?? MaskedValueState.NOT_SEEN;

		if(answer.state == MaskedValueState.REMEMBERED)
		{
			answer.uncutMaskedValue = forgetRememberedText(valueKey);
			maskedValueStatesByKey.remove(valueKey);
		}

		return answer;
	}

	/**
	 * @description Registers a field text as masked already, for one field and caller class, for the rest of this
	 * transaction. Call it when you masked a value yourself (with `forField(...).mask`) and put the result, or a shorter
	 * form of it, in the field before the save. The record pass in the trigger then finds the text registered and leaves
	 * the field as it is, so the value is not masked a second time.
	 *
	 * Only the record masker reads the registration, and only for the same field, the same caller and the exact same
	 * text. If anything changes the field's text after this call, the new text does not match and is masked as usual. A
	 * record pass for another caller masks the text as usual too, because that caller can have other rules. A text made
	 * only of spaces is not registered. Only a hash of the text is kept.
	 *
	 * @param field The field the text is saved to
	 * @param callerClassName The caller class the record pass will name; null or empty for a pass that names none
	 * @param fieldText The exact text put in the field
	 *
	 * @example
	 * ```apex
	 * String maskedBody = UTIL_FrameworkMasker.forField(ApiCall__c.Request__c).calledFrom('API_SendEmail').mask(rawBody).maskedValue;
	 * apiCall.Request__c = UTIL_String.abbreviate(maskedBody, ApiCall__c.Request__c);
	 * UTIL_FrameworkMasker.registerMaskedFieldText(ApiCall__c.Request__c, 'API_SendEmail', apiCall.Request__c);
	 * ```
	 */
	public static void registerMaskedFieldText(SObjectField field, String callerClassName, String fieldText)
	{
		String fieldTextHash = field == null ? null : UTIL_Crypto.generateSHA256Hash(fieldText);
		if(fieldTextHash != null)
		{
			registeredFieldTextKeys.add(buildMaskedValueKey(getQualifiedFieldName(field), callerClassName, fieldTextHash));
		}
	}

	/**
	 * @description Checks whether a field text is registered as masked already for this field and caller (see
	 * `registeredFieldTextKeys`). Only the record masker calls it.
	 *
	 * @param qualifiedFieldName The field's `Object.Field` name, from `getQualifiedFieldName`
	 * @param callerClassName The caller class of the record pass; null or empty when it named none
	 * @param fieldTextHash The SHA-256 hash of the field's current text, or null when the text is only spaces
	 *
	 * @return True when the exact text is registered for this field and caller
	 */
	private static Boolean isRegisteredFieldText(String qualifiedFieldName, String callerClassName, String fieldTextHash)
	{
		return fieldTextHash != null && registeredFieldTextKeys.contains(buildMaskedValueKey(qualifiedFieldName, callerClassName, fieldTextHash));
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
		result.fieldsSkippedAsAlreadyMasked = 0;
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
		 * helper, adds up the counts, and cuts the result to the field's length limit when needed. It then records, for
		 * the rest of the transaction, what it did with the value (read with `takeMaskedValueAnswer`) and registers the
		 * text it returns, so a record pass for the same field and caller that finds this text leaves it as it is (see
		 * `maskAndRememberValue`).
		 *
		 * @param rawValue The raw (unmasked) value
		 *
		 * @return The masked value plus audit metadata
		 */
		public MaskingResult mask(String rawValue)
		{
			if(String.isEmpty(rawValue))
			{
				return newResult(rawValue);
			}

			return maskAndRememberValue(buildFieldPlan(), callerClassName, rawValue, UTIL_Crypto.generateSHA256Hash(rawValue));
		}

		/**
		 * @description Final call for a caller that saves a text longer than its field in a file: masks the value as
		 * `mask` does, and also returns the whole masked text when it had to be cut to fit the field, in
		 * `MaskingResult.uncutMaskedValue`. `maskedValue` holds the text that fits the field, as with `mask`. The whole
		 * text is handed straight to the caller and is never kept by the masker, so it reaches the caller whatever its
		 * length, even past `REMEMBERED_TEXT_CAP`. Because the caller holds it, a later `takeMaskedValueAnswer` for a cut
		 * value answers NOT_SEEN. The text returned in `maskedValue` is registered as `mask` registers it (see
		 * `maskAndHandOverWholeText`).
		 *
		 * @param rawValue The raw (unmasked) value
		 *
		 * @return The masked value plus audit metadata; `uncutMaskedValue` is set only when the masked text was cut
		 *
		 * @throws UTIL_Exceptions.MaskingBlockedException when a rule with FailureAction = BlockDml fails
		 */
		public MaskingResult maskAndReturnWholeText(String rawValue)
		{
			if(String.isEmpty(rawValue))
			{
				return newResult(rawValue);
			}

			return maskAndHandOverWholeText(buildFieldPlan(), callerClassName, rawValue, UTIL_Crypto.generateSHA256Hash(rawValue));
		}

		/**
		 * @description Builds the field plan for the target field and the caller: the applicable targets, filtered by the
		 * field's type, split into the JsonKey rules and the others.
		 *
		 * @return The field plan
		 */
		private FieldPlan buildFieldPlan()
		{
			SObjectType sObjectType = UTIL_SObjectDescribe.getCachedFieldDescribe(targetField).getSObjectType();
			String qualifiedFieldName = getQualifiedFieldName(targetField);

			List<MaskingTarget__mdt> applicableTargets = selectApplicableTargets(sObjectType, qualifiedFieldName, callerClassName);
			applicableTargets = filterTargetsByFieldType(applicableTargets, targetField);

			FieldPlan adhocPlan = new FieldPlan();
			adhocPlan.field = targetField;
			adhocPlan.fieldApiName = qualifiedFieldName.substringAfter(UTIL_String.DOT);
			adhocPlan.qualifiedFieldName = qualifiedFieldName;

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

			return adhocPlan;
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
		 * record. Adds up the match and failure counts across every masked field. A field whose exact text is registered
		 * as masked already for this caller is left as it is and counted in `fieldsSkippedAsAlreadyMasked` (see
		 * `applyFieldPlanToRecord`).
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
		 * Before any rule runs, it checks whether the field's exact text is registered as masked already for this field
		 * and this caller (by `registerMaskedFieldText`, or by an earlier masking pass that returned or wrote this text).
		 * If it is, the field is left as it is, no rule runs, and the skip is counted in
		 * `aggregate.fieldsSkippedAsAlreadyMasked`. A text that changed, or a registration for another caller, does not
		 * match, so the field is masked as usual and what the pass did is recorded (see `maskAndRememberValue`).
		 *
		 * Some fields a wildcard target covers cannot be changed by anyone, so the platform refuses the masked value
		 * (see `getTextFieldsCoveredByWildcard`). Then the field keeps its value, the record's other fields are still
		 * masked, and the result does not report an error: the save cannot change that field either, so nothing new is
		 * stored without masking. From then on the field is skipped for the rest of the transaction, before any rule
		 * runs on it, and the masker writes one warning about it (see `skipFieldThePlatformRefusesToWrite`). So once
		 * the field is skipped, a Block DML rule on it no longer stops a save: the masker cannot change the field, and
		 * neither can the save. The catch covers only the write and only `System.SObjectException`, so a
		 * `UTIL_Exceptions.MaskingBlockedException` from a rule still reaches the caller.
		 *
		 * @param fieldPlan The plan for this field, built in advance
		 * @param aggregate The record-level MaskingResult being built up as fields are processed
		 *
		 * @throws UTIL_Exceptions.MaskingBlockedException when a rule with FailureAction = BlockDml fails
		 */
		private void applyFieldPlanToRecord(FieldPlan fieldPlan, MaskingResult aggregate)
		{
			if(fieldsThePlatformRefusesToWrite.contains(fieldPlan.field))
			{
				return;
			}

			Object currentValue = recordToMask.get(fieldPlan.fieldApiName);

			if(currentValue == null)
			{
				return;
			}

			String rawValue = String.valueOf(currentValue);

			if(String.isEmpty(rawValue))
			{
				return;
			}

			String rawValueHash = UTIL_Crypto.generateSHA256Hash(rawValue);

			if(isRegisteredFieldText(fieldPlan.qualifiedFieldName, callerClassName, rawValueHash))
			{
				aggregate.fieldsSkippedAsAlreadyMasked++;
				return;
			}

			MaskingResult fieldResult = maskAndRememberValue(fieldPlan, callerClassName, rawValue, rawValueHash);

			if(fieldResult.maskedValue != rawValue && fieldResult.maskedValue != null)
			{
				try
				{
					recordToMask.put(fieldPlan.fieldApiName, fieldResult.maskedValue);
				}
				catch(System.SObjectException writeError)
				{
					skipFieldThePlatformRefusesToWrite(fieldPlan, recordToMask.getSObjectType(), writeError);
					return;
				}
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

		/**
		 * @description Number of fields the record masker left as they were because their exact text was registered as
		 * masked already, for the same field and caller (see `registerMaskedFieldText`). No rule ran on those fields, so
		 * they add nothing to `rulesMatched` or to the lengths. Always zero on the result of a single value.
		 */
		public Integer fieldsSkippedAsAlreadyMasked;

		/**
		 * @description The whole masked text, before it was cut to fit the field. Set only by
		 * `FieldMasker.maskAndReturnWholeText`, and only when the masked text was cut; null otherwise.
		 */
		public String uncutMaskedValue;
	}

	/**
	 * @description What the masker can say about a raw value it may have masked earlier in the transaction, for one
	 * field and caller. Returned in `MaskedValueAnswer.state` by `takeMaskedValueAnswer`.
	 */
	public enum MaskedValueState
	{
		/**
		 * @description No pass in this transaction masked this raw value for this field and caller, or the whole masked
		 * text was already handed over once. The caller masks the raw value again if it needs the masked text.
		 */
		NOT_SEEN,
		/**
		 * @description The masked text fits in the field, so the field holds all of it. A value no rule changed is in
		 * this state too.
		 */
		FITTED,
		/**
		 * @description The masked text was too long for the field and was cut to fit. The masker kept the whole masked
		 * text, and the answer carries it.
		 */
		REMEMBERED,
		/**
		 * @description The masked text was too long for the field and was cut to fit, but the masker did not keep the
		 * whole text, because that would have passed the cap. The caller masks the raw value again if it needs the whole
		 * text.
		 */
		DROPPED
	}

	/**
	 * @description The answer `takeMaskedValueAnswer` gives about one raw value: its state and, only when the state is
	 * REMEMBERED, the whole masked text.
	 */
	public class MaskedValueAnswer
	{
		/**
		 * @description What the masker can say about the value. Never null.
		 */
		public MaskedValueState state;

		/**
		 * @description The whole masked text, before it was cut to fit the field. Set only when `state` is REMEMBERED;
		 * null otherwise.
		 */
		public String uncutMaskedValue;
	}
}