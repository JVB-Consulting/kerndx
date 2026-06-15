// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Selector for the MaskingTarget__mdt custom metadata type. Loads every masking target
 * together with every masking rule in a single transaction, grouped by SObject type token for O(1)
 * lookup by callers.
 *
 * **Two lazy per-transaction caches.** {@see cachedTargetsByType} holds every target (active and
 * inactive) grouped by `SObjectType`; {@see cachedRulesById} holds every rule (active and inactive)
 * keyed by Id. Both build lazily on first read from in-memory `getAll()` — the targets cache adds a
 * single `EntityDefinition WHERE DurableId IN (...)` SOQL to resolve each target's `SObjectType__c`
 * MetadataRelationship DurableId back to its object type. This avoids the platform's
 * MetadataRelationship-joined CMDT query shape (observed at ~900 ms cold per transaction), and avoids
 * the JSON round-trip pattern that silently drops namespaced fields from a nested `Rule__r` child
 * SObject in managed-package runtime.
 *
 * **Active is derived, not separately cached.** `findActiveForSObjectType` — the only target accessor
 * the masking engine (`UTIL_FrameworkMasker`) uses — filters the all-targets cache to the targets that
 * are themselves active *and* bound to an active rule, so the engine never applies a disabled target.
 * `findAllForSObjectType` returns the unfiltered set so the Data Masking Advisor can surface inactive
 * targets a subscriber may re-enable.
 *
 * **Sidecar rule resolution.** Rules are never accessed through `target.Rule__r`. Instead callers
 * (notably `UTIL_FrameworkMasker.ruleFor`) resolve the parent rule via `getRuleById(target.Rule__c)`,
 * which reads {@see cachedRulesById}. Top-level `MaskingRule__mdt` SObjects returned by `getAll()` have
 * every custom field populated in every runtime (unmanaged, managed, and subscriber), so the
 * managed-runtime nested-child field-token drop cannot recur. Mock targets registered via `TST_Mock`
 * prime their own `Rule__r` into the cache so `getRuleById` resolves the mock rule.
 *
 * **Rule-order sorting** is handled downstream in `UTIL_FrameworkMasker.sortByRuleOrder`.
 *
 * **Collision resilience.** `getAll()` itself throws `System.ListException` when an org-local record
 * shares a packaged record's DeveloperName (e.g. a subscriber clones a shipped rule in Setup, whose
 * clone UI pre-fills the name). Every platform read behind the caches and `getAllTargets` degrades to
 * a flat selector query re-materialised to the getAll() record shape (any field readable, relationship
 * fields null, LongTextArea values truncated to the getAll() budget so supersession fingerprints stay
 * identical on both paths), emits one flood-controlled WARN per CMDT type per transaction, and keeps
 * masking running — the unhandled collision used to brick every framework-object DML. Precedent:
 * `SEL_FeatureFlag.allDeveloperNames`.
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
 * @date April 2026, June 2026
 */
@SuppressWarnings('PMD.CognitiveComplexity,PMD.CyclomaticComplexity')
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
	 * @description Fully-qualified API name of the MaskingTarget__mdt object — namespaced
	 * (`kern__MaskingTarget__mdt`) in a subscriber org, un-namespaced (`MaskingTarget__mdt`) in the
	 * framework's dev preview. Used by callers that emit metadata XML referencing the type.
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
	 * @description Per-transaction cache of **every** masking target (active and inactive, regardless of
	 * parent-rule state) grouped by `SObjectType`. Keyed by the type token rather than an API-name string
	 * so lookups skip the describe-to-name conversion they would otherwise pay per call. Lazily built on
	 * first read from `MaskingTarget__mdt.getAll()` (or the `allTargetsOverrideForTest` seam) plus one
	 * `EntityDefinition` SOQL via {@see groupTargetsByType}. `findActiveForSObjectType` filters this to the
	 * active subset; `findAllForSObjectType` returns it unfiltered.
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
	 * @description Per-transaction cache of **every** masking rule (active and inactive) keyed by Id.
	 * Lazily built on first read from `MaskingRule__mdt.getAll()` (or the `allRulesOverrideForTest` seam),
	 * issuing no SOQL. Callers read via `getRuleById(target.Rule__c)` instead of `target.Rule__r.X`
	 * because managed-package CMDT can't populate nested `Rule__r` custom fields through SObject JSON
	 * deserialization. Mock targets prime their own `Rule__r` into this cache through `findMockedFor`.
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
	 * @description Test seam for the `MaskingRule__mdt.getAll()` read behind `cachedRulesById`. When
	 * non-null, the cache uses this map instead of the platform call so tests can exercise edge cases
	 * (inactive rule with active target, rule-less targets) that shipped CMDT doesn't naturally contain.
	 */
	@TestVisible
	private static Map<String, MaskingRule__mdt> allRulesOverrideForTest;

	/**
	 * @description Test seam for the `MaskingTarget__mdt.getAll()` read behind `cachedTargetsByType` and
	 * `getAllTargets`. When non-null, those reads use this map instead of the platform call so tests can
	 * exercise unresolvable DurableIds and API names not present in `Schema.getGlobalDescribe`.
	 */
	@TestVisible
	private static Map<String, MaskingTarget__mdt> allTargetsOverrideForTest;

	/**
	 * @description Test seam forcing the `getAll()` reads behind both caches and `getAllTargets` to
	 * throw the platform's duplicate-DeveloperName `System.ListException`, driving the selector
	 * fallback without deploying a colliding org-local record.
	 */
	@TestVisible
	private static Boolean simulateGetAllCollisionForTest = false;

	/**
	 * @description Collision warnings registered inside the fallback catch, keyed by CMDT type and
	 * drained only AFTER the corresponding cache assignment: the WARN emission is itself masked
	 * through these caches (`LOG_Engine` masks every `LogEntryEvent__e`), so emitting before the
	 * assignment would re-enter the still-cold getter and recurse until the stack overflows.
	 * Lazily initialised on first access, like the caches above.
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
	 * @description CMDT types already warned about in this transaction — one WARN per type per
	 * transaction however often the fallback runs (`getAllTargets` is uncached, and the caches can
	 * be rebuilt mid-transaction), with `LOG_Builder` fingerprint flood control deduplicating
	 * across transactions. Lazily initialised on first access.
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
	 * @description Constructs a MaskingTarget selector.
	 */
	public SEL_MaskingTarget()
	{
		super(MaskingTarget__mdt.SObjectType);
	}

	/**
	 * @description Returns the core fields for MaskingTarget__mdt queries. Used by ad-hoc
	 * consumers that build target queries through `SEL_Base.query`; the in-memory `getAll()`
	 * load path populates these fields directly without an explicit field list. This list also
	 * defines the collision-fallback contract: after a getAll() collision the caches rebuild from
	 * a flat query over exactly these fields, so every field any cache consumer reads must be
	 * listed here (NamespacePrefix keys packaged and org-local targets apart for namespace-aware
	 * consumers).
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
	 * @description Finds the **active** masking targets for a specific SObjectType — the targets that are
	 * themselves active and bound to an active rule. This is the only target accessor the masking engine
	 * (`UTIL_FrameworkMasker`) uses, so a disabled target or a target bound to an inactive rule is never
	 * applied. Mock targets registered via `TST_Mock` shortcut the load path; otherwise the active subset
	 * is filtered from the transaction-scoped all-targets cache.
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
	 * @description Finds **all** masking targets for a specific SObjectType — active **and** inactive,
	 * regardless of parent-rule state. Sibling to {@see findActiveForSObjectType}: the engine only ever
	 * needs the active targets, but the Data Masking Advisor needs the inactive ones too so it can render
	 * existing coverage and offer a disable / re-enable diff. Mock targets registered via `TST_Mock`
	 * shortcut the load path (the mock filter does not drop inactive records here).
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
	 * @description Returns the all-targets cache entry for a type, or an empty list when the type carries
	 * no targets. Triggers the lazy build of `cachedTargetsByType` on first read.
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
	 * @description Filters a target list to the engine-applicable subset: targets that are themselves
	 * active and bound to an active rule. A target bound to an inactive or missing rule masks nothing, so
	 * it is excluded here exactly as a disabled target is.
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
	 * @description Resolves a target's parent `MaskingRule__mdt` via the per-transaction rule cache.
	 * Callers that hold a `MaskingTarget__mdt` (e.g. `UTIL_FrameworkMasker`) read rule fields via this
	 * method instead of `target.Rule__r.X` — the platform can't populate `target.Rule__r` with the full
	 * rule on a managed-package CMDT in a way that survives JSON serialization, so the rule is kept in a
	 * sidecar map and looked up by `Rule__c` Id. Returns null for a null Id or an Id no rule matches.
	 *
	 * @param ruleId The `MaskingTarget__mdt.Rule__c` Id to resolve.
	 *
	 * @return The fully-populated rule, or `null` if no such rule is loaded.
	 */
	public static MaskingRule__mdt getRuleById(Id ruleId)
	{
		return ruleId == null ? null : cachedRulesById.get(ruleId);
	}

	/**
	 * @description Returns every masking target (active and inactive, regardless of parent-rule state) as
	 * a flat list. Unlike {@see findActiveForSObjectType}, which drops targets whose rule is inactive, this
	 * raw accessor preserves them so callers such as the dead-configuration check can detect active targets
	 * bound to an inactive or missing rule — including targets whose `SObjectType__c` DurableId no longer
	 * resolves, which `cachedTargetsByType` omits. Reads the in-memory `MaskingTarget__mdt.getAll()` map
	 * (or the `allTargetsOverrideForTest` seam) — issues no SOQL.
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
	 * @description Returns every masking rule (active and inactive) keyed by record Id, so callers can tell
	 * an inactive-rule reference apart from a missing-rule reference. A snapshot of the transaction's rule
	 * cache — issues no SOQL.
	 *
	 * @return Every masking rule keyed by record Id.
	 */
	@SuppressWarnings('ApexMethodCanBeStatic')
	public Map<Id, MaskingRule__mdt> getAllRulesById()
	{
		return cachedRulesById;
	}

	/**
	 * @description Groups masking targets by their `SObjectType` by resolving each target's `SObjectType__c`
	 * MetadataRelationship DurableId back to its SObject type with a single `EntityDefinition` SOQL. A
	 * target whose DurableId no EntityDefinition row resolves (a since-deleted object) is dropped rather
	 * than cached against a null type.
	 *
	 * @param targets The targets to group.
	 *
	 * @return Targets grouped by resolved SObjectType (unresolvable targets omitted).
	 */
	private static Map<SObjectType, List<MaskingTarget__mdt>> groupTargetsByType(List<MaskingTarget__mdt> targets)
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
	 * @description Test-seam: when `TST_Mock.get(MaskingTarget__mdt.SObjectType)` has records registered,
	 * return those matching the requested SObjectType (by `SObjectType__c` API-name string, and by
	 * `IsActive__c` when `activeOnly`) and prime `cachedRulesById` from the mocks' own `Rule__r`
	 * relationships so `getRuleById` resolves to the mock rule. `findActiveForSObjectType` passes
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
	 * @description Reads every masking rule from `getAll()`, degrading to a flat selector query
	 * re-materialised to the getAll() record shape when the platform call throws on a
	 * cross-namespace DeveloperName collision. Without the fallback, an org-local record cloning a
	 * packaged rule's DeveloperName bricks every framework-object DML. Same hazard and remedy as
	 * `SEL_FeatureFlag.allDeveloperNames`; the flat CMDT query is backed by the same metadata
	 * cache as `getAll()`, so the degraded path stays cheap.
	 *
	 * @return The getAll() map values, or the shaped fallback records after a collision.
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
	 * @description Reads every masking target from `getAll()`, degrading to a flat selector query
	 * re-materialised to the getAll() record shape on a DeveloperName collision. Targets carry no
	 * LongTextArea fields, so the normalisation is pure re-materialisation: any field readable,
	 * relationship fields null, exactly the shape `resolveQualifiedFieldName` and the surface-key
	 * builders already handle on the fast path.
	 *
	 * @return The getAll() map values, or the shaped fallback records after a collision.
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
	 * @description Flat collision-fallback query over `getFields()` only — deliberately NOT the
	 * selector's default `query`, whose `getFieldPaths()` relationship joins are the
	 * MetadataRelationship-joined CMDT shape this class exists to avoid (~900 ms cold) and would
	 * populate relationship fields the getAll() shape keeps null. Runs `systemModeInternal` for
	 * the same reason as {@see systemModeRequired}.
	 *
	 * @return Every masking target, flat-queried.
	 */
	private List<MaskingTarget__mdt> fetchAllFlat()
	{
		return QRY_Builder.selectFrom(MaskingTarget__mdt.SObjectType)
				.fields(getFields())
				.systemModeInternal()
				.toList();
	}

	/**
	 * @description Re-materialises SOQL-sourced targets into the getAll() record shape: fresh
	 * in-memory copies of the `getFields()` field set, so any field is readable (a raw SOQL row
	 * throws `SObjectException` on un-queried field reads — `ruleFor` and
	 * `resolveQualifiedFieldName` probe `Rule__r`/`Field__r`/`SObjectType__r`) and relationship
	 * fields stay null exactly as `getAll()` leaves them.
	 *
	 * @param targets SOQL-sourced targets carrying the `getFields()` field set.
	 *
	 * @return getAll()-shaped in-memory copies, in input order.
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
	 * @description Throws a constructed duplicate-DeveloperName `System.ListException` when the
	 * `simulateGetAllCollisionForTest` seam is set, so tests can drive the fallback path without
	 * deploying a colliding org-local CMDT record.
	 */
	private static void throwIfSimulatedCollision()
	{
		if(!simulateGetAllCollisionForTest)
		{
			return;
		}

		System.ListException simulated = new System.ListException();
		simulated.setMessage('Row with duplicate DeveloperName at index: 0 (simulated by SEL_MaskingTarget test seam)');
		throw simulated;
	}

	/**
	 * @description Bare DeveloperNames appearing more than once in the fallback records — the
	 * colliding names a getAll() collision implies (packaged and org-local records sharing one
	 * name across namespaces).
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
	 * @description Queues the collision warning for a CMDT type. Log-only text (never reaches a
	 * subscriber UI), so no Custom Label. Emission is deferred to
	 * {@see emitPendingCollisionWarnings} after the cache assignment — see
	 * {@see pendingCollisionWarnings} for why emitting here would recurse.
	 *
	 * Types already warned this transaction skip the message build entirely — repeated uncached
	 * fallback reads (`getAllTargets`) would otherwise rebuild a message the drain guard then
	 * discards.
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
	 * @description Emits the queued collision warnings — one flood-controlled WARN per CMDT type
	 * per transaction. The pending queue is reset and the per-type guard marked BEFORE each
	 * emission because the emission itself is masked through these selector caches; the queue
	 * reset plus {@see registerCollision}'s already-warned short-circuit are what terminate that
	 * re-entrance.
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