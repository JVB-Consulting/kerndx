// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Selector for the MaskingTarget__mdt custom metadata type. Loads every active
 * target together with every active rule in a single transaction, grouped by SObject API name
 * for O(1) lookup by callers.
 *
 * **Load path — in-memory getAll() + EntityDefinition DurableId resolution.** Uses
 * `MaskingRule__mdt.getAll()` + `MaskingTarget__mdt.getAll()` (both microsecond-fast
 * in-memory calls) plus a single `EntityDefinition WHERE DurableId IN (...)` SOQL to resolve
 * each target's `SObjectType__c` MetadataRelationship value back to its object API name.
 * Avoids the platform's MetadataRelationship-joined CMDT query shape (observed at ~900 ms
 * cold per transaction), and avoids the JSON round-trip pattern that silently drops
 * namespaced fields from a nested `Rule__r` child SObject in managed-package runtime.
 *
 * **Sidecar rule cache.** Rules are never accessed through `target.Rule__r`. Instead they
 * are loaded flat from `MaskingRule__mdt.getAll()` into `cachedRulesById` and callers
 * (notably `UTIL_FrameworkMasker.ruleFor`) resolve the parent rule via
 * `getRuleById(target.Rule__c)`. Top-level `MaskingRule__mdt` SObjects returned by
 * `getAll()` have every custom field populated in every runtime (unmanaged, managed, and
 * subscriber), so the managed-runtime nested-child field-token drop cannot recur.
 *
 * **Rule-order sorting** is handled downstream in `UTIL_FrameworkMasker.sortByRuleOrder`.
 *
 * @see SEL_Base
 * @see SEL_MaskingTarget_TEST
 * @see SEL_MaskingRule
 * @see SEL_EntityDefinition
 * @see MaskingTarget__mdt
 *
 * @author Jason van Beukering
 *
 * @group Data Masking
 *
 * @date April 2026, May 2026
 */
@SuppressWarnings('PMD.CognitiveComplexity')
public inherited sharing class SEL_MaskingTarget extends SEL_Base
{
	/**
	 * @description Namespace-aware relationship path for `SObjectType__r.QualifiedApiName`.
	 * `SObjectType__c` is a MetadataRelationship to `EntityDefinition`, which does not expose a
	 * relationship name via `getDescribe().getRelationshipName()`, so the path is assembled
	 * manually with the package namespace prefix to keep queries valid in subscriber orgs.
	 * Retained for `getFieldPaths()` — ad-hoc consumers that build target queries through
	 * `SEL_Base.query` still get the entity-resolved name without re-deriving it.
	 */
	@TestVisible
	private static final String PATH_SOBJECT_TYPE_QUALIFIED_API_NAME = UTIL_System.getManagedPackageNamespacePrefix() + 'SObjectType__r.QualifiedApiName';

	/**
	 * @description Namespace-aware relationship path for `Field__r.QualifiedApiName`. `Field__c`
	 * is a MetadataRelationship to `FieldDefinition` — same constraint as `SObjectType__c`.
	 */
	@TestVisible
	private static final String PATH_FIELD_QUALIFIED_API_NAME = UTIL_System.getManagedPackageNamespacePrefix() + 'Field__r.QualifiedApiName';

	/**
	 * @description Per-transaction cache of active masking targets keyed by `SObjectType`.
	 * Keyed by the type token rather than an API-name string so lookups from `UTIL_FrameworkMasker`
	 * skip the describe-to-name conversion they would otherwise pay per call. Populated
	 * lazily via `ensureProductionCacheLoaded` on first access from a non-mock path.
	 */
	@TestVisible
	private static Map<SObjectType, List<MaskingTarget__mdt>> cachedActiveTargetsByType;

	/**
	 * @description Per-transaction cache of active masking rules keyed by Id. Populated
	 * alongside `cachedActiveTargetsByType` from `MaskingRule__mdt.getAll()` (production
	 * path), or primed directly from mock targets' `Rule__r` child by `findMockedFor`
	 * (test path). Callers read via `getRuleById(target.Rule__c)` instead of
	 * `target.Rule__r.X` because managed-package CMDT can't populate nested `Rule__r` custom
	 * fields through SObject JSON deserialization.
	 */
	@TestVisible
	private static Map<Id, MaskingRule__mdt> cachedRulesById;

	/**
	 * @description Test seam for the `MaskingRule__mdt.getAll()` call in `loadCache`. When
	 * non-null, the loader uses this map instead of the platform call so tests can exercise
	 * edge cases (inactive rule with active target, rule-less targets) that shipped CMDT
	 * doesn't naturally contain.
	 */
	@TestVisible
	private static Map<String, MaskingRule__mdt> allRulesOverrideForTest;

	/**
	 * @description Test seam for the `MaskingTarget__mdt.getAll()` call in `loadCache`. When
	 * non-null, the loader uses this map instead of the platform call so tests can exercise
	 * unresolvable DurableIds and API names not present in `Schema.getGlobalDescribe`.
	 */
	@TestVisible
	private static Map<String, MaskingTarget__mdt> allTargetsOverrideForTest;

	/**
	 * @description Constructs a MaskingTarget selector.
	 */
	public SEL_MaskingTarget()
	{
		super(MaskingTarget__mdt.SObjectType);
	}

	/**
	 * @description Returns the core fields for MaskingTarget__mdt queries. Used by ad-hoc
	 * consumers that build target queries through `SEL_Base.query`; the in-memory `getAll()`
	 * load path populates these fields directly without an explicit field list.
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
				MaskingTarget__mdt.Rule__c,
				MaskingTarget__mdt.SObjectType__c
		};
	}

	/**
	 * @description Returns relationship traversal field paths for MaskingTarget__mdt queries.
	 * Exposes the SObjectType + Field qualified-API-name paths so ad-hoc callers that build
	 * target queries through `SEL_Base.query` still get the entity-resolved names without
	 * having to re-derive the namespace-prefixed path.
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
	 * @description Framework-internal CMDT selector — always runs in `AccessLevel.SYSTEM_MODE`
	 * regardless of the `UserModeQueries_Enabled` feature flag. Subscribers typically grant
	 * running users no CRUD on `kern__*__mdt` records by design, so USER_MODE reads would
	 * return empty and framework behaviour would silently break.
	 *
	 * @return `true` — this selector requires SYSTEM_MODE.
	 */
	public override Boolean systemModeRequired()
	{
		return true;
	}

	/**
	 * @description Finds active masking targets for a specific SObjectType. Mock targets
	 * registered via `TST_Mock.of(MaskingTarget__mdt.SObjectType).build()` shortcut the load
	 * path. Production path runs `MaskingRule__mdt.getAll()` + `MaskingTarget__mdt.getAll()`
	 * plus one `EntityDefinition` SOQL and caches the result for the rest of the transaction.
	 *
	 * @param sObjectType The object whose targets to find
	 *
	 * @return Active targets for the type (empty list if none)
	 */
	@SuppressWarnings('ApexMethodCanBeStatic')
	public List<MaskingTarget__mdt> findActiveForSObjectType(SObjectType sObjectType)
	{
		List<MaskingTarget__mdt> mocked = findMockedFor(sObjectType);
		if(mocked != null)
		{
			return mocked;
		}

		ensureProductionCacheLoaded();
		return cachedActiveTargetsByType.containsKey(sObjectType) ? cachedActiveTargetsByType.get(sObjectType) : new List<MaskingTarget__mdt>();
	}

	/**
	 * @description Resolves a target's parent `MaskingRule__mdt` via the per-transaction
	 * rule cache. Callers that hold a `MaskingTarget__mdt` (e.g. `UTIL_FrameworkMasker`) read
	 * rule fields via this method instead of `target.Rule__r.X` — the platform can't populate
	 * `target.Rule__r` with the full rule on a managed-package CMDT in a way that survives
	 * JSON serialization, so we keep the rule in a sidecar map and look up by `Rule__c` Id.
	 *
	 * For mock records registered via `TST_Mock`, the rule is sourced from each mock target's
	 * own `Rule__r` child on first access — tests that set `withOverride(Rule__c, fullRuleSObject)`
	 * continue to work unchanged.
	 *
	 * @param ruleId The `MaskingTarget__mdt.Rule__c` Id to resolve.
	 *
	 * @return The fully-populated rule, or `null` if no such rule is loaded.
	 */
	public static MaskingRule__mdt getRuleById(Id ruleId)
	{
		if(cachedRulesById != null && cachedRulesById.containsKey(ruleId))
		{
			return cachedRulesById.get(ruleId);
		}
		ensureProductionCacheLoaded();
		return cachedRulesById.get(ruleId);
	}

	/**
	 * @description Lazy-loads the production target + rule caches on first access from a
	 * non-mock path. Idempotent — subsequent calls are no-ops while the cache is populated.
	 * Mock paths (`findMockedFor`) bypass this helper and populate `cachedRulesById` directly
	 * from mock targets' `Rule__r` so mock-only tests never trigger the EntityDefinition query.
	 */
	private static void ensureProductionCacheLoaded()
	{
		if(cachedActiveTargetsByType == null)
		{
			loadCache();
		}
	}

	/**
	 * @description Populates both transaction caches from in-memory `getAll()` on both CMDT
	 * types plus a single `EntityDefinition` SOQL to resolve each active target's
	 * `SObjectType__c` MetadataRelationship DurableId back to its SObject API name. Targets
	 * whose parent rule is inactive are dropped here so the engine never sees them. The
	 * caches contain fully-populated top-level `MaskingRule__mdt` records (no nested child
	 * SObjects), so the managed-runtime JSON-rehydrate field-drop bug
	 * cannot recur.
	 */
	private static void loadCache()
	{
		Map<String, MaskingRule__mdt> allRules = allRulesOverrideForTest ?? MaskingRule__mdt.getAll();
		Map<String, MaskingTarget__mdt> allTargets = allTargetsOverrideForTest ?? MaskingTarget__mdt.getAll();

		Map<Id, MaskingRule__mdt> activeRulesById = new Map<Id, MaskingRule__mdt>();
		for(MaskingRule__mdt rule : allRules.values())
		{
			if(rule.IsActive__c == true)
			{
				activeRulesById.put(rule.Id, rule);
			}
		}

		List<MaskingTarget__mdt> applicableTargets = new List<MaskingTarget__mdt>();
		Set<String> durableIds = new Set<String>();
		for(MaskingTarget__mdt target : allTargets.values())
		{
			if(target.IsActive__c == true && activeRulesById.containsKey(target.Rule__c))
			{
				applicableTargets.add(target);

				if(String.isNotBlank(target.SObjectType__c))
				{
					durableIds.add(target.SObjectType__c);
				}
			}
		}

		Map<String, String> apiNameByDurableId = new Map<String, String>();

		for(EntityDefinition entity : new SEL_EntityDefinition().findByDurableIds(durableIds))
		{
			apiNameByDurableId.put(entity.DurableId, entity.QualifiedApiName);
		}

		Map<SObjectType, List<MaskingTarget__mdt>> targetsByType = new Map<SObjectType, List<MaskingTarget__mdt>>();
		for(MaskingTarget__mdt target : applicableTargets)
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

		cachedActiveTargetsByType = targetsByType;
		cachedRulesById = activeRulesById;
	}

	/**
	 * @description Test-seam: when `TST_Mock.get(MaskingTarget__mdt.SObjectType)` has records
	 * registered, return only those matching the requested SObjectType (by `IsActive__c` +
	 * `SObjectType__c` API-name string) and prime `cachedRulesById` from the mocks' own
	 * `Rule__r` relationships so `getRuleById` resolves to the mock rule.
	 *
	 * @param sObjectType The object whose targets to filter.
	 *
	 * @return Matching mock targets, or `null` if no mocks are registered.
	 */
	private static List<MaskingTarget__mdt> findMockedFor(SObjectType sObjectType)
	{
		List<SObject> mockedRecords = TST_Mock.get(MaskingTarget__mdt.SObjectType);

		if(mockedRecords == null || mockedRecords.isEmpty())
		{
			return null;
		}

		String sObjectName = UTIL_SObjectDescribe.getObjectNameFromType(sObjectType);
		List<MaskingTarget__mdt> matching = new List<MaskingTarget__mdt>();
		Map<Id, MaskingRule__mdt> ruleCache = cachedRulesById ?? new Map<Id, MaskingRule__mdt>();
		for(SObject mock : mockedRecords)
		{
			MaskingTarget__mdt target = (MaskingTarget__mdt)mock;
			if(target.IsActive__c != true)
			{
				continue;
			}
			if(target.SObjectType__c != sObjectName)
			{
				continue;
			}
			if(target.Rule__r != null && target.Rule__c != null)
			{
				ruleCache.put(target.Rule__c, target.Rule__r);
			}
			matching.add(target);
		}
		cachedRulesById = ruleCache;
		return matching;
	}
}