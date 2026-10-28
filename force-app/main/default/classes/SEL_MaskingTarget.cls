// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Selector for the MaskingTarget__mdt custom metadata type. Loads every masking target
 * together with every masking rule once per transaction, grouped by SObject type token so callers can
 * look them up in constant time.
 *
 * **Two caches, built on first use, that last for one transaction.** {@see cachedTargetsByType} holds
 * every target (active and inactive) grouped by `SObjectType`; {@see cachedRulesById} holds every rule
 * (active and inactive) keyed by Id. Both are built on first read from the in-memory `getAll()`. The
 * targets cache adds one `EntityDefinition WHERE DurableId IN (...)` SOQL query, to turn each target's
 * `SObjectType__c` MetadataRelationship DurableId back into its object type. When any target names a
 * field, it also adds one `FieldDefinition WHERE DurableId IN (...)` query, to turn each stored
 * `Field__c` durable Id into its `Object.Field` name ({@see getQualifiedFieldName}). This avoids the slow
 * CMDT query that joins MetadataRelationship fields (about 900 ms per transaction on a cold cache). It
 * also avoids reading the rule through JSON, which in a managed package quietly drops namespaced fields
 * from a nested `Rule__r` child SObject.
 *
 * **Active targets are filtered, not cached separately.** `findActiveForSObjectType` is the only target
 * method the masking engine (`UTIL_FrameworkMasker`) uses. It filters the all-targets cache to the
 * targets that are active themselves *and* linked to an active rule, so the engine never applies a
 * disabled target. `findAllForSObjectType` returns every target, so the Data Masking Advisor can show
 * inactive targets a subscriber may switch back on.
 *
 * **Rules are looked up separately.** Rules are never read through `target.Rule__r`. Instead callers
 * (notably `UTIL_FrameworkMasker.ruleFor`) find the parent rule with `getRuleById(target.Rule__c)`,
 * which reads {@see cachedRulesById}. Top-level `MaskingRule__mdt` SObjects returned by `getAll()` have
 * every custom field filled in every runtime (unmanaged, managed, and subscriber), so fields can no
 * longer go missing from a nested child record in a managed package. Mock targets registered with
 * `TST_Mock` add their own `Rule__r` to the cache, so `getRuleById` finds the mock rule.
 *
 * **Sorting by rule order** happens later, in `UTIL_FrameworkMasker.sortByRuleOrder`.
 *
 * **Duplicate names do not stop masking.** `getAll()` itself throws `System.ListException` when an
 * org-local record has the same DeveloperName as a packaged record (e.g. a subscriber clones a shipped
 * rule in Setup, and the clone page fills in the same name). When that happens, every platform read
 * behind the caches and `getAllTargets` falls back to a flat selector query. The results are copied
 * into the getAll() record shape (every field readable, relationship fields null, LongTextArea values
 * cut to the getAll() length so supersession fingerprints are the same on both paths). The selector
 * writes one flood-controlled WARN per CMDT type per transaction and masking keeps running. Before
 * this fallback, the unhandled error made every DML on a framework object fail. The same approach is
 * used in `SEL_FeatureFlag.allDeveloperNames`.
 *
 * @see SEL_Base
 * @see SEL_MaskingTarget_TEST
 * @see SEL_MaskingRule
 * @see SEL_EntityDefinition
 * @see SEL_FieldDefinition
 * @see MaskingTarget__mdt
 *
 * @author Jason van Beukering
 *
 * @group Data Masking
 *
 * @date April 2026, October 2026
 */
@SuppressWarnings('PMD.CognitiveComplexity,PMD.CyclomaticComplexity')
public inherited sharing class SEL_MaskingTarget extends SEL_Base
{
	/**
	 * @description Namespace-aware relationship path for `SObjectType__r.QualifiedApiName`.
	 * `SObjectType__c` is a MetadataRelationship to `EntityDefinition`, which does not expose a
	 * relationship name via `getDescribe().getRelationshipName()`, so the path is assembled
	 * manually with the package namespace prefix to keep queries valid in subscriber orgs.
	 * Kept for `getFieldPaths()`: callers that build their own target queries through
	 * `SEL_Base.query` still get the object's API name without working out the path again.
	 */
	@TestVisible
	private static final String PATH_SOBJECT_TYPE_QUALIFIED_API_NAME = UTIL_System.getManagedPackageNamespacePrefix() + 'SObjectType__r.QualifiedApiName';

	/**
	 * @description Namespace-aware relationship path for `Field__r.QualifiedApiName`. `Field__c`
	 * is a MetadataRelationship to `FieldDefinition`, with the same limit as `SObjectType__c`.
	 */
	@TestVisible
	private static final String PATH_FIELD_QUALIFIED_API_NAME = UTIL_System.getManagedPackageNamespacePrefix() + 'Field__r.QualifiedApiName';

	/**
	 * @description Fully-qualified API name of the MaskingTarget__mdt object: namespaced
	 * (`kern__MaskingTarget__mdt`) in a subscriber org, without a namespace (`MaskingTarget__mdt`) in
	 * the framework's development org. Used by callers that write metadata XML that refers to the type.
	 */
	public static final String OBJECT_NAME = UTIL_SObjectDescribe.getObjectNameFromType(MaskingTarget__mdt.SObjectType);

	/**
	 * @description Namespace-aware API name of `CallerClass__c`.
	 */
	public static final String FIELD_CALLER_CLASS = UTIL_SObjectDescribe.getCachedFieldName(MaskingTarget__mdt.CallerClass__c);

	/**
	 * @description Namespace-aware API name of `Field__c`.
	 */
	public static final String FIELD_FIELD = UTIL_SObjectDescribe.getCachedFieldName(MaskingTarget__mdt.Field__c);

	/**
	 * @description Namespace-aware API name of `IsActive__c`.
	 */
	public static final String FIELD_IS_ACTIVE = UTIL_SObjectDescribe.getCachedFieldName(MaskingTarget__mdt.IsActive__c);

	/**
	 * @description Namespace-aware API name of `Rule__c`.
	 */
	public static final String FIELD_RULE = UTIL_SObjectDescribe.getCachedFieldName(MaskingTarget__mdt.Rule__c);

	/**
	 * @description Namespace-aware API name of `SObjectType__c`.
	 */
	public static final String FIELD_SOBJECT_TYPE = UTIL_SObjectDescribe.getCachedFieldName(MaskingTarget__mdt.SObjectType__c);

	/**
	 * @description Cache, for one transaction, of **every** masking target (active and inactive, whatever
	 * the state of the parent rule), grouped by `SObjectType`. Keyed by the type token and not by an API
	 * name, so a lookup does not have to turn a describe into a name on every call. Built on first read
	 * from `MaskingTarget__mdt.getAll()` (or the test override `allTargetsOverrideForTest`), plus one
	 * `EntityDefinition` SOQL query through {@see groupTargetsByType}. `findActiveForSObjectType` filters
	 * this to the active targets; `findAllForSObjectType` returns it unfiltered.
	 */
	@TestVisible
	private static Map<SObjectType, List<MaskingTarget__mdt>> cachedTargetsByType
	{
		get
		{
			if(cachedTargetsByType == null)
			{
				cachedTargetsByType = groupTargetsByType(readAllTargets());
				emitPendingCollisionWarnings();
			}
			return cachedTargetsByType;
		}
		set;
	}

	/**
	 * @description Cache, for one transaction, of **every** masking rule (active and inactive), keyed by
	 * Id. Built on first read from `MaskingRule__mdt.getAll()` (or the test override
	 * `allRulesOverrideForTest`), with no SOQL. Callers read through `getRuleById(target.Rule__c)` and
	 * not `target.Rule__r.X`, because a managed-package CMDT cannot fill nested `Rule__r` custom fields
	 * through SObject JSON deserialization. Mock targets add their own `Rule__r` to this cache through
	 * `findMockedFor`.
	 */
	@TestVisible
	private static Map<Id, MaskingRule__mdt> cachedRulesById
	{
		get
		{
			if(cachedRulesById == null)
			{
				cachedRulesById = new Map<Id, MaskingRule__mdt>(readAllRules());
				emitPendingCollisionWarnings();
			}
			return cachedRulesById;
		}
		set;
	}

	/**
	 * @description The `Object.Field` name of each field a target names, keyed by the value stored in the
	 * target's `Field__c`. A deployed target stores the field's durable Id there (the fixed key the platform
	 * gives each field), not its name, and neither the `getAll()` read nor the fallback query fills in the
	 * name. Filled when {@see cachedTargetsByType} is built, from one `FieldDefinition` query, and read through
	 * {@see getQualifiedFieldName}. Empty until then.
	 */
	private static Map<String, String> qualifiedFieldNameByStoredValue = new Map<String, String>();

	/**
	 * @description Test override for the `MaskingRule__mdt.getAll()` read behind `cachedRulesById`. When
	 * it is not null, the cache uses this map instead of the platform call, so tests can cover cases
	 * (an inactive rule with an active target, targets without a rule) that the shipped CMDT does not have.
	 */
	@TestVisible
	private static Map<String, MaskingRule__mdt> allRulesOverrideForTest;

	/**
	 * @description Test override for the `MaskingTarget__mdt.getAll()` read behind `cachedTargetsByType`
	 * and `getAllTargets`. When it is not null, those reads use this map instead of the platform call, so
	 * tests can cover DurableIds that resolve to nothing and API names not in `Schema.getGlobalDescribe`.
	 */
	@TestVisible
	private static Map<String, MaskingTarget__mdt> allTargetsOverrideForTest;

	/**
	 * @description Test flag that makes the `getAll()` reads behind both caches and `getAllTargets`
	 * throw the platform's duplicate-DeveloperName `System.ListException`. Tests use it to run the
	 * selector fallback without deploying an org-local record with a duplicate name.
	 */
	@TestVisible
	private static Boolean simulateGetAllCollisionForTest = false;

	/**
	 * @description Duplicate-name warnings recorded inside the fallback catch block, keyed by CMDT type.
	 * They are written only AFTER the matching cache is assigned. Writing the WARN log entry itself
	 * goes through masking, and so through these caches (`LOG_Engine` masks every `LogEntryEvent__e`).
	 * Writing it before the assignment would call the empty getter again, which would call itself until
	 * the stack overflows. Created on first use, like the caches above.
	 */
	private static Map<SObjectType, String> pendingCollisionWarnings
	{
		get
		{
			if(pendingCollisionWarnings == null)
			{
				pendingCollisionWarnings = new Map<SObjectType, String>();
			}
			return pendingCollisionWarnings;
		}
		set;
	}

	/**
	 * @description CMDT types already warned about in this transaction: one WARN per type per
	 * transaction, however often the fallback runs (`getAllTargets` is not cached, and the caches can
	 * be rebuilt during a transaction). Across transactions, `LOG_Builder` fingerprint flood control
	 * removes the repeats. Created on first use.
	 */
	private static final Set<SObjectType> warnedCollisionTypes
	{
		get
		{
			if(warnedCollisionTypes == null)
			{
				warnedCollisionTypes = new Set<SObjectType>();
			}
			return warnedCollisionTypes;
		}
		set;
	}

	/**
	 * @description Reads the MaskingTarget__mdt custom metadata records. Every query skips the running user's object and field permission checks (system mode). Creating the
	 * selector runs no query and fills no cache.
	 */
	public SEL_MaskingTarget()
	{
		super(MaskingTarget__mdt.SObjectType);
	}

	/**
	 * @description Returns the core fields for MaskingTarget__mdt queries. Used by callers that build
	 * their own target queries through `SEL_Base.query`; the in-memory `getAll()` load fills these
	 * fields directly, without a field list. The fallback read uses the same list: when getAll() fails on
	 * a duplicate name, the caches are rebuilt from a flat query over exactly these fields. So every field
	 * that any reader of the cache uses must be listed here (NamespacePrefix keeps packaged and org-local
	 * targets apart for code that reads the namespace).
	 *
	 * @return List of MaskingTarget__mdt SObjectField tokens
	 */
	public override List<SObjectField> getFields()
	{
		return new List<SObjectField>
		{
				MaskingTarget__mdt.CallerClass__c,
				MaskingTarget__mdt.DeveloperName,
				MaskingTarget__mdt.Field__c,
				MaskingTarget__mdt.IsActive__c,
				MaskingTarget__mdt.NamespacePrefix,
				MaskingTarget__mdt.Rule__c,
				MaskingTarget__mdt.SObjectType__c
		};
	}

	/**
	 * @description Returns the relationship field paths for MaskingTarget__mdt queries: the
	 * qualified API name paths of SObjectType and Field. Callers that build their own target queries
	 * through `SEL_Base.query` then get the object and field API names without working out the
	 * namespace-prefixed path themselves.
	 *
	 * @return List of field path strings
	 */
	public override List<String> getFieldPaths()
	{
		return new List<String>
		{
				PATH_SOBJECT_TYPE_QUALIFIED_API_NAME,
				PATH_FIELD_QUALIFIED_API_NAME
		};
	}

	/**
	 * @description Framework-internal CMDT selector: always runs in `AccessLevel.SYSTEM_MODE`,
	 * whatever the `UserModeQueries_Enabled` feature flag says. Subscribers usually give running
	 * users no access to `kern__*__mdt` records on purpose, so USER_MODE reads would return nothing
	 * and framework behaviour would quietly break.
	 *
	 * @return `true`: this selector requires SYSTEM_MODE.
	 */
	public override Boolean systemModeRequired()
	{
		return true;
	}

	/**
	 * @description Finds the **active** masking targets for an SObjectType: the targets that are active
	 * themselves and linked to an active rule. This is the only target method the masking engine
	 * (`UTIL_FrameworkMasker`) uses, so a disabled target, or a target linked to an inactive rule, is
	 * never applied. Mock targets registered with `TST_Mock` are returned without loading anything;
	 * otherwise the active targets are filtered from the all-targets cache for the transaction.
	 *
	 * @param sObjectType The object whose active targets to find.
	 *
	 * @return Active targets for the type (empty list if none).
	 */
	@SuppressWarnings('ApexMethodCanBeStatic')
	public List<MaskingTarget__mdt> findActiveForSObjectType(SObjectType sObjectType)
	{
		return findMockedFor(sObjectType, true) ?? activeOnly(forType(sObjectType));
	}

	/**
	 * @description Finds **all** masking targets for an SObjectType, active **and** inactive, whatever
	 * the state of the parent rule. Works with {@see findActiveForSObjectType}: the engine only needs
	 * the active targets, but the Data Masking Advisor also needs the inactive ones, so it can show the
	 * existing coverage and offer to switch targets off or back on. Mock targets registered with
	 * `TST_Mock` are returned without loading anything (here the mock filter keeps inactive records).
	 *
	 * @param sObjectType The object whose targets to find.
	 *
	 * @return All targets for the type, active and inactive (empty list if none).
	 */
	@SuppressWarnings('ApexMethodCanBeStatic')
	public List<MaskingTarget__mdt> findAllForSObjectType(SObjectType sObjectType)
	{
		return findMockedFor(sObjectType, false) ?? forType(sObjectType);
	}

	/**
	 * @description Finds **all** masking targets for an SObjectType, active and inactive, without finding
	 * the name of the field each target names. A target that names a field keeps the value stored in its
	 * `Field__c` (for a custom field, a durable Id: the fixed key the platform gives each field), and
	 * {@see getQualifiedFieldName} has no name for it. Only the Data Masking Advisor uses this method, when
	 * {@see findAllForSObjectType} fails because field details (`FieldDefinition`) cannot be read: the
	 * Advisor can still show the targets it knows about. Masking never uses it. When masking cannot find
	 * the field a target names, it must fail, so that a value is never saved without masking. Not cached:
	 * each call reads the targets again and runs one `EntityDefinition` query.
	 *
	 * @param sObjectType The object whose targets to find.
	 *
	 * @return All targets for the type, active and inactive (empty list if none).
	 */
	public List<MaskingTarget__mdt> findAllForSObjectTypeWithoutFieldNames(SObjectType sObjectType)
	{
		Map<SObjectType, List<MaskingTarget__mdt>> targetsByType = groupByObjectType(getAllTargets());
		return targetsByType.containsKey(sObjectType) ? targetsByType.get(sObjectType) : new List<MaskingTarget__mdt>();
	}

	/**
	 * @description Returns the all-targets cache entry for a type, or an empty list when the type has
	 * no targets. The first read builds `cachedTargetsByType`.
	 *
	 * @param sObjectType The object whose cached targets to read.
	 *
	 * @return The cached targets for the type (active and inactive), or an empty list.
	 */
	private static List<MaskingTarget__mdt> forType(SObjectType sObjectType)
	{
		return cachedTargetsByType.containsKey(sObjectType) ? cachedTargetsByType.get(sObjectType) : new List<MaskingTarget__mdt>();
	}

	/**
	 * @description Filters a target list to the targets the engine can apply: targets that are active
	 * themselves and linked to an active rule. A target linked to an inactive or missing rule masks
	 * nothing, so it is left out here, just like a disabled target.
	 *
	 * @param targets The targets to filter (active and inactive).
	 *
	 * @return The active targets bound to an active rule.
	 */
	private static List<MaskingTarget__mdt> activeOnly(List<MaskingTarget__mdt> targets)
	{
		List<MaskingTarget__mdt> active = new List<MaskingTarget__mdt>();
		for(MaskingTarget__mdt target : targets)
		{
			MaskingRule__mdt rule = getRuleById(target.Rule__c);
			if(target.IsActive__c == true && rule?.IsActive__c == true)
			{
				active.add(target);
			}
		}
		return active;
	}

	/**
	 * @description Finds a target's parent `MaskingRule__mdt` in the rule cache for the transaction.
	 * Callers that hold a `MaskingTarget__mdt` (e.g. `UTIL_FrameworkMasker`) read rule fields through
	 * this method and not through `target.Rule__r.X`. In a managed package, the platform cannot fill
	 * `target.Rule__r` with the full rule in a way that survives JSON serialization, so the rules are
	 * kept in a separate map and looked up by the `Rule__c` Id. Returns null for a null Id or an Id that
	 * matches no rule.
	 *
	 * @param ruleId The `MaskingTarget__mdt.Rule__c` Id to resolve.
	 *
	 * @return The rule with every field filled, or `null` if no such rule is loaded.
	 */
	public static MaskingRule__mdt getRuleById(Id ruleId)
	{
		return ruleId == null ? null : cachedRulesById.get(ruleId);
	}

	/**
	 * @description Returns the `Object.Field` name of the field a target names, for a target read from the
	 * target cache. A deployed target stores the field's durable Id in `Field__c` (for a custom field, the
	 * object's durable Id and the field's Id joined by a dot), so callers that compare the target with a
	 * field name must ask here first. Returns null when the target names no field, or when the stored value
	 * is not a durable Id the cache build found (a test mock that already stores `Object.Field`, or a field
	 * that has since been deleted).
	 *
	 * @param target The target whose field name to find.
	 *
	 * @return The field's `Object.Field` name, or `null` when the cache holds none for the stored value.
	 */
	public static String getQualifiedFieldName(MaskingTarget__mdt target)
	{
		return String.isBlank(target.Field__c) ? null : qualifiedFieldNameByStoredValue.get(target.Field__c);
	}

	/**
	 * @description Returns every masking target (active and inactive, whatever the state of the parent
	 * rule) as a flat list. {@see findActiveForSObjectType} drops targets whose rule is inactive; this
	 * method keeps them, so callers such as the dead-configuration check can find active targets linked
	 * to an inactive or missing rule. That includes targets whose `SObjectType__c` DurableId no longer
	 * resolves, which `cachedTargetsByType` leaves out. Reads the in-memory `MaskingTarget__mdt.getAll()`
	 * map (or the test override `allTargetsOverrideForTest`) and runs no SOQL.
	 *
	 * @return Every masking target in the org.
	 */
	@SuppressWarnings('ApexMethodCanBeStatic')
	public List<MaskingTarget__mdt> getAllTargets()
	{
		List<MaskingTarget__mdt> targets = readAllTargets();
		emitPendingCollisionWarnings();
		return targets;
	}

	/**
	 * @description Returns every masking rule (active and inactive) keyed by record Id, so callers can
	 * tell a target whose rule is inactive apart from a target whose rule is missing. A copy of the
	 * transaction's rule cache; runs no SOQL.
	 *
	 * @return Every masking rule keyed by record Id.
	 */
	@SuppressWarnings('ApexMethodCanBeStatic')
	public Map<Id, MaskingRule__mdt> getAllRulesById()
	{
		return cachedRulesById;
	}

	/**
	 * @description Groups masking targets by their `SObjectType`. One `EntityDefinition` SOQL query turns
	 * each target's `SObjectType__c` MetadataRelationship DurableId back into its SObject type. A target
	 * whose DurableId matches no EntityDefinition row (an object that has since been deleted) is dropped,
	 * not cached against a null type. Also finds the field name of every target that names a field, through
	 * {@see resolveFieldNames}.
	 *
	 * @param targets The targets to group.
	 *
	 * @return Targets grouped by resolved SObjectType (unresolvable targets omitted).
	 */
	private static Map<SObjectType, List<MaskingTarget__mdt>> groupTargetsByType(List<MaskingTarget__mdt> targets)
	{
		resolveFieldNames(targets);
		return groupByObjectType(targets);
	}

	/**
	 * @description Groups masking targets by their `SObjectType`, without finding any field names. One
	 * `EntityDefinition` SOQL query turns each target's `SObjectType__c` MetadataRelationship DurableId back
	 * into its SObject type. A target whose DurableId matches no EntityDefinition row (an object that has
	 * since been deleted) is dropped, not kept against a null type.
	 *
	 * @param targets The targets to group.
	 *
	 * @return Targets grouped by resolved SObjectType (unresolvable targets omitted).
	 */
	private static Map<SObjectType, List<MaskingTarget__mdt>> groupByObjectType(List<MaskingTarget__mdt> targets)
	{
		Set<String> durableIds = new Set<String>();
		for(MaskingTarget__mdt target : targets)
		{
			if(String.isNotBlank(target.SObjectType__c))
			{
				durableIds.add(target.SObjectType__c);
			}
		}

		Map<String, String> apiNameByDurableId = new Map<String, String>();
		for(EntityDefinition entity : new SEL_EntityDefinition().findByDurableIds(durableIds))
		{
			apiNameByDurableId.put(entity.DurableId, entity.QualifiedApiName);
		}

		Map<SObjectType, List<MaskingTarget__mdt>> targetsByType = new Map<SObjectType, List<MaskingTarget__mdt>>();
		for(MaskingTarget__mdt target : targets)
		{
			String apiName = apiNameByDurableId.get(target.SObjectType__c);
			SObjectType sObjectType = UTIL_SObjectDescribe.getSObjectTypeByName(apiName);
			if(sObjectType != null)
			{
				if(!targetsByType.containsKey(sObjectType))
				{
					targetsByType.put(sObjectType, new List<MaskingTarget__mdt>());
				}

				targetsByType.get(sObjectType).add(target);
			}
		}

		return targetsByType;
	}

	/**
	 * @description Finds the `Object.Field` name of every field the targets name, and keeps it in
	 * {@see qualifiedFieldNameByStoredValue}. One `FieldDefinition` query reads every stored value at once, and
	 * no query runs when no target names a field. A stored value that matches no field definition gets no
	 * entry: callers then fall back to the stored value itself.
	 *
	 * @param targets The targets whose field names to find.
	 */
	private static void resolveFieldNames(List<MaskingTarget__mdt> targets)
	{
		Set<String> storedValues = new Set<String>();
		for(MaskingTarget__mdt target : targets)
		{
			if(String.isNotBlank(target.Field__c))
			{
				storedValues.add(target.Field__c);
			}
		}

		Map<String, String> resolvedNames = new Map<String, String>();
		for(FieldDefinition field : new SEL_FieldDefinition().findByDurableIds(storedValues))
		{
			resolvedNames.put(field.DurableId, field.EntityDefinition.QualifiedApiName + UTIL_String.DOT + field.QualifiedApiName);
		}
		qualifiedFieldNameByStoredValue = resolvedNames;
	}

	/**
	 * @description Test support: when `TST_Mock.get(MaskingTarget__mdt.SObjectType)` has records registered,
	 * returns those that match the requested SObjectType (by the `SObjectType__c` API name, and by
	 * `IsActive__c` when `activeOnly` is set), and adds the mocks' own `Rule__r` records to
	 * `cachedRulesById` so `getRuleById` finds the mock rule. `findActiveForSObjectType` passes
	 * `activeOnly = true` (the engine never applies inactive targets); `findAllForSObjectType` passes
	 * `false` so the advisor sees inactive targets too.
	 *
	 * @param sObjectType The object whose targets to filter.
	 * @param activeOnly When true, inactive mock targets are excluded.
	 *
	 * @return Matching mock targets, or `null` if no mocks are registered.
	 */
	private static List<MaskingTarget__mdt> findMockedFor(SObjectType sObjectType, Boolean activeOnly)
	{
		List<SObject> mockedRecords = TST_Mock.get(MaskingTarget__mdt.SObjectType);

		if(mockedRecords == null || mockedRecords.isEmpty())
		{
			return null;
		}

		String sObjectName = UTIL_SObjectDescribe.getObjectNameFromType(sObjectType);
		List<MaskingTarget__mdt> matching = new List<MaskingTarget__mdt>();
		for(SObject mock : mockedRecords)
		{
			MaskingTarget__mdt target = (MaskingTarget__mdt)mock;
			if(activeOnly && target.IsActive__c != true)
			{
				continue;
			}
			if(target.SObjectType__c != sObjectName)
			{
				continue;
			}
			if(target.Rule__r != null && target.Rule__c != null)
			{
				cachedRulesById.put(target.Rule__c, target.Rule__r);
			}
			matching.add(target);
		}
		return matching;
	}

	/**
	 * @description Reads every masking rule from `getAll()`. When the platform call throws because an
	 * org-local record and a packaged record share a DeveloperName, falls back to a flat selector query
	 * copied into the getAll() record shape. Without the fallback, an org-local copy of a packaged
	 * rule's DeveloperName makes every DML on a framework object fail. `SEL_FeatureFlag.allDeveloperNames`
	 * has the same problem and the same fix. The flat CMDT query uses the same metadata cache as
	 * `getAll()`, so the fallback stays cheap.
	 *
	 * @return The getAll() map values, or the reshaped fallback records after a duplicate-name error.
	 */
	private static List<MaskingRule__mdt> readAllRules()
	{
		// The override check lives HERE, not as `override?.values() ?? readAllRules()` in the cache
		// getter: on the v67 preview platform, `Map.values()` feeding `??` inline takes the FALLBACK
		// when the map is empty (probed 2026-06-12), silently bypassing an empty test override.
		if(allRulesOverrideForTest != null)
		{
			return allRulesOverrideForTest.values();
		}

		try
		{
			throwIfSimulatedCollision();
			return MaskingRule__mdt.getAll().values();
		}
		catch(System.ListException duplicateName)
		{
			List<MaskingRule__mdt> fallback = SEL_MaskingRule.normaliseToGetAllShape(new SEL_MaskingRule().fetchAllFlat());
			registerCollision(MaskingRule__mdt.SObjectType, collectDuplicateNames(fallback), duplicateName);
			return fallback;
		}
	}

	/**
	 * @description Reads every masking target from `getAll()`. On a duplicate DeveloperName it falls
	 * back to a flat selector query copied into the getAll() record shape. Targets have no LongTextArea
	 * fields, so the copy only reshapes the records: every field readable and relationship fields null,
	 * which is exactly the shape `resolveQualifiedFieldName` and the surface-key builders already handle
	 * on the normal path.
	 *
	 * @return The getAll() map values, or the reshaped fallback records after a duplicate-name error.
	 */
	private static List<MaskingTarget__mdt> readAllTargets()
	{
		// Override check here for the same `Map.values()` + `??` platform quirk as readAllRules.
		if(allTargetsOverrideForTest != null)
		{
			return allTargetsOverrideForTest.values();
		}

		try
		{
			throwIfSimulatedCollision();
			return MaskingTarget__mdt.getAll().values();
		}
		catch(System.ListException duplicateName)
		{
			List<MaskingTarget__mdt> fallback = normaliseToGetAllShape(new SEL_MaskingTarget().fetchAllFlat());
			registerCollision(MaskingTarget__mdt.SObjectType, collectDuplicateNames(fallback), duplicateName);
			return fallback;
		}
	}

	/**
	 * @description Flat fallback query over `getFields()` only. It deliberately does not use the
	 * selector's default `query`: its `getFieldPaths()` relationship joins are the slow CMDT query
	 * this class exists to avoid (about 900 ms on a cold cache), and they would fill relationship
	 * fields that the getAll() shape keeps null. Runs `systemModeInternal` for the same reason as
	 * {@see systemModeRequired}.
	 *
	 * @return Every masking target, from a flat query.
	 */
	private List<MaskingTarget__mdt> fetchAllFlat()
	{
		return QRY_Builder.selectFrom(MaskingTarget__mdt.SObjectType)
				.fields(getFields())
				.systemModeInternal()
				.toList();
	}

	/**
	 * @description Copies targets read by SOQL into the getAll() record shape: new in-memory copies
	 * of the `getFields()` field set, so every field can be read, and relationship fields stay null just
	 * as `getAll()` leaves them. (A raw SOQL row throws `SObjectException` when code reads a field that
	 * was not queried, and `ruleFor` and `resolveQualifiedFieldName` read `Rule__r`, `Field__r` and
	 * `SObjectType__r`.)
	 *
	 * @param targets Targets read by SOQL, carrying the `getFields()` field set.
	 *
	 * @return In-memory copies shaped as getAll() returns them, in input order.
	 */
	private static List<MaskingTarget__mdt> normaliseToGetAllShape(List<MaskingTarget__mdt> targets)
	{
		List<SObjectField> fields = new SEL_MaskingTarget().getFields();
		List<MaskingTarget__mdt> shaped = new List<MaskingTarget__mdt>();

		for(MaskingTarget__mdt target : targets)
		{
			MaskingTarget__mdt copy = new MaskingTarget__mdt(Id = target.Id);
			for(SObjectField field : fields)
			{
				copy.put(field, target.get(field));
			}
			shaped.add(copy);
		}

		return shaped;
	}

	/**
	 * @description Throws a duplicate-DeveloperName `System.ListException`, built here, when the test
	 * flag `simulateGetAllCollisionForTest` is set, so tests can run the fallback path without
	 * deploying an org-local CMDT record with a duplicate name.
	 */
	private static void throwIfSimulatedCollision()
	{
		if(!simulateGetAllCollisionForTest)
		{
			return;
		}

		System.ListException simulated = new System.ListException();
		simulated.setMessage('Row with duplicate DeveloperName at index: 0 (simulated by the SEL_MaskingTarget test flag)');
		throw simulated;
	}

	/**
	 * @description DeveloperNames, without namespace, that appear more than once in the fallback
	 * records. These are the names that made getAll() fail (a packaged record and an org-local record
	 * with the same name in different namespaces).
	 *
	 * @param records The fallback-loaded CMDT records to scan.
	 *
	 * @return The DeveloperNames seen more than once.
	 */
	private static Set<String> collectDuplicateNames(List<SObject> records)
	{
		Set<String> seen = new Set<String>();
		Set<String> duplicates = new Set<String>();

		for(SObject record : records)
		{
			String developerName = (String)record.get('DeveloperName');
			if(!seen.add(developerName))
			{
				duplicates.add(developerName);
			}
		}

		return duplicates;
	}

	/**
	 * @description Queues the duplicate-name warning for a CMDT type. The text only goes to the log
	 * (it never reaches a subscriber screen), so it needs no Custom Label. The warning is written later,
	 * by {@see emitPendingCollisionWarnings}, after the cache is assigned; see
	 * {@see pendingCollisionWarnings} for why writing it here would make the code call itself.
	 *
	 * A type already warned about in this transaction skips building the message: repeated fallback
	 * reads that are not cached (`getAllTargets`) would otherwise build a message that would then be
	 * thrown away.
	 *
	 * @param cmdtType The colliding CMDT type.
	 * @param duplicateNames DeveloperNames found more than once in the fallback records.
	 * @param failure The platform exception the getAll() read threw.
	 */
	private static void registerCollision(SObjectType cmdtType, Set<String> duplicateNames, System.ListException failure)
	{
		if(warnedCollisionTypes.contains(cmdtType))
		{
			return;
		}

		String objectName = UTIL_SObjectDescribe.getObjectNameFromType(cmdtType);
		String duplicateList = duplicateNames.isEmpty()
				? '(none found in the fallback scan)'
				: String.join(new List<String>(duplicateNames), ', ');

		pendingCollisionWarnings.put(cmdtType, objectName + ' getAll() failed on a DeveloperName collision ("' + failure.getMessage()
				+ '"); masking continues on the selector fallback read. Duplicate DeveloperNames: ' + duplicateList
				+ '. Rename or remove the org-local record cloning a packaged name to restore the fast path.');
	}

	/**
	 * @description Writes the queued duplicate-name warnings: one flood-controlled WARN per CMDT type
	 * per transaction. The queue is cleared, and the type is marked as warned, BEFORE each warning is
	 * written, because writing it goes through masking and so through these selector caches. Clearing
	 * the queue, and {@see registerCollision} skipping types already warned about, are what stop the
	 * code from calling itself again.
	 */
	private static void emitPendingCollisionWarnings()
	{
		if(pendingCollisionWarnings.isEmpty())
		{
			return;
		}

		Map<SObjectType, String> draining = pendingCollisionWarnings;
		pendingCollisionWarnings = null;

		for(SObjectType cmdtType : draining.keySet())
		{
			warnedCollisionTypes.add(cmdtType);

			LOG_Builder.build()
					.warn(draining.get(cmdtType))
					.withFingerprintInternal('masking:cmdt-collision:' + UTIL_SObjectDescribe.getObjectNameFromType(cmdtType))
					.emitAt(SEL_MaskingTarget.class.getName() + '.emitPendingCollisionWarnings');
		}
	}
}