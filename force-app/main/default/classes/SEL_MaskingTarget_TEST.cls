// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Unit tests for SEL_MaskingTarget selector.
 *
 * @see SEL_MaskingTarget
 *
 * @author Jason van Beukering
 *
 * @group Selectors
 *
 * @date April 2026, June 2026
 */
@IsTest(SeeAllData=false IsParallel=true)
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
private class SEL_MaskingTarget_TEST
{
	/**
	 * @description The API name of the Foobar__c test object used to register mock and preset targets.
	 */
	private static final String OBJECT_FOOBAR = UTIL_SObjectDescribe.getObjectNameFromType(Foobar__c.SObjectType);

	/**
	 * @description Tests that `findActiveForSObjectType` returns the test-seam's registered mocks
	 * when `TST_Mock` has MaskingTarget records, preserving the mocking contract used by
	 * `UTIL_FrameworkMasker_TEST`.
	 */
	@IsTest
	private static void shouldReturnMockedTargetsWhenTstMockRegistered()
	{
		TST_Mock.of(MaskingTarget__mdt.SObjectType)
				.withOverride(MaskingTarget__mdt.IsActive__c, true)
				.withOverride(MaskingTarget__mdt.SObjectType__c, OBJECT_FOOBAR)
				.build();

		List<MaskingTarget__mdt> results = new SEL_MaskingTarget().findActiveForSObjectType(Foobar__c.SObjectType);

		Assert.isNotNull(results, 'Should return a list, never null');
		Assert.isFalse(results.isEmpty(), 'Should return the mocked record for the requested type');
	}

	/**
	 * @description Tests that `findActiveForSObjectType` filters mocked records by `IsActive__c` —
	 * inactive mocks are excluded so the engine never applies them.
	 */
	@IsTest
	private static void shouldExcludeInactiveMockedTargets()
	{
		TST_Mock.of(MaskingTarget__mdt.SObjectType)
				.withOverride(MaskingTarget__mdt.IsActive__c, false)
				.withOverride(MaskingTarget__mdt.SObjectType__c, OBJECT_FOOBAR)
				.build();

		List<MaskingTarget__mdt> results = new SEL_MaskingTarget().findActiveForSObjectType(Foobar__c.SObjectType);

		Assert.isTrue(results.isEmpty(), 'Inactive mocked targets should not be returned');
	}

	/**
	 * @description Tests that `findActiveForSObjectType` filters mocked records by
	 * `SObjectType__c` — only mocks for the requested type are returned.
	 */
	@IsTest
	private static void shouldFilterMockedTargetsBySObjectType()
	{
		TST_Mock.of(MaskingTarget__mdt.SObjectType)
				.withOverride(MaskingTarget__mdt.IsActive__c, true)
				.withOverride(MaskingTarget__mdt.SObjectType__c, 'Account')
				.build();

		List<MaskingTarget__mdt> results = new SEL_MaskingTarget().findActiveForSObjectType(Foobar__c.SObjectType);

		Assert.isTrue(results.isEmpty(), 'Mocks for a different SObjectType should not be returned');
	}

	/**
	 * @description Tests that `getFields` returns a populated list with the expected core fields.
	 */
	@IsTest
	private static void shouldReturnDefaultFields()
	{
		List<SObjectField> fields = new SEL_MaskingTarget().getFields();

		Assert.isFalse(fields.isEmpty(), 'getFields should return the default field list');
		Assert.isTrue(fields.contains(MaskingTarget__mdt.Rule__c), 'Default fields should include Rule__c');
		Assert.isTrue(fields.contains(MaskingTarget__mdt.SObjectType__c), 'Default fields should include SObjectType__c');
		Assert.isTrue(fields.contains(MaskingTarget__mdt.Field__c), 'Default fields should include Field__c');
		Assert.isTrue
				(
						fields.contains(MaskingTarget__mdt.NamespacePrefix),
						'Default fields should include NamespacePrefix — namespace-aware consumers key packaged and org-local targets apart'
				);
	}

	/**
	 * @description Tests that `getFieldPaths` includes the manually-assembled EntityDefinition
	 * and FieldDefinition qualified-API-name paths so ad-hoc consumers that build target
	 * queries through `SEL_Base.query` still resolve the entity names without re-deriving
	 * the namespace prefix.
	 */
	@IsTest
	private static void shouldReturnRelationshipFieldPaths()
	{
		List<String> paths = new SEL_MaskingTarget().getFieldPaths();

		Assert.isFalse(paths.isEmpty(), 'getFieldPaths should return a populated list');
		Assert.isTrue(paths.contains(SEL_MaskingTarget.PATH_SOBJECT_TYPE_QUALIFIED_API_NAME), 'Should include SObjectType qualified API name path');
		Assert.isTrue(paths.contains(SEL_MaskingTarget.PATH_FIELD_QUALIFIED_API_NAME), 'Should include Field qualified API name path');
	}

	/**
	 * @description Tests that `systemModeRequired` is true — the selector must always run in
	 * SYSTEM_MODE because subscribers typically don't grant CRUD on `kern__*__mdt` to running
	 * users, so a USER_MODE read would silently return no records.
	 */
	@IsTest
	private static void shouldRequireSystemMode()
	{
		Assert.isTrue(new SEL_MaskingTarget().systemModeRequired(), 'MaskingTarget selector must always run in SYSTEM_MODE');
	}

	/**
	 * @description Tests the production derive-active path — clears the caches and the `TST_Mock` registry
	 * so reading lazily builds `cachedTargetsByType` (one EntityDefinition SOQL) and `cachedRulesById`, then
	 * filters the type's targets to the active subset. `ApiCall__c` carries shipped active targets, so the
	 * active list and both caches populate.
	 */
	@IsTest
	private static void findActiveForSObjectTypeDerivesActiveFromShippedConfiguration()
	{
		SEL_MaskingTarget.cachedTargetsByType = null;
		SEL_MaskingTarget.cachedRulesById = null;
		TST_Mock.clear(MaskingTarget__mdt.SObjectType);

		List<MaskingTarget__mdt> results = new SEL_MaskingTarget().findActiveForSObjectType(ApiCall__c.SObjectType);

		Assert.isFalse(results.isEmpty(), 'Shipped active ApiCall__c targets should be derived');
		for(MaskingTarget__mdt target : results)
		{
			Assert.isTrue(target.IsActive__c, 'Every derived target is active');
		}
		Assert.isNotNull(SEL_MaskingTarget.cachedTargetsByType, 'All-targets cache must populate after a non-mock lookup');
		Assert.isNotNull(SEL_MaskingTarget.cachedRulesById, 'Rule cache must populate when deriving the active subset');
		Assert.isFalse(SEL_MaskingTarget.cachedRulesById.isEmpty(), 'Shipped rules should populate the rule cache');
	}

	/**
	 * @description Tests that `findActiveForSObjectType` returns an empty list for an SObject the shipped
	 * configuration carries no targets for.
	 */
	@IsTest
	private static void findActiveForSObjectTypeReturnsEmptyForSObjectWithoutConfiguredTargets()
	{
		SEL_MaskingTarget.cachedTargetsByType = null;
		SEL_MaskingTarget.cachedRulesById = null;
		TST_Mock.clear(MaskingTarget__mdt.SObjectType);

		List<MaskingTarget__mdt> results = new SEL_MaskingTarget().findActiveForSObjectType(User.SObjectType);

		Assert.isNotNull(results, 'Should return a list, never null');
		Assert.isTrue(results.isEmpty(), 'No shipped target covers User, result should be empty');
	}

	/**
	 * @description Tests the engine-safety invariant: a target that is itself active but bound to an
	 * **inactive** rule is surfaced by `findAllForSObjectType` (so the advisor can offer re-enable) yet
	 * excluded by `findActiveForSObjectType` (so the engine never applies masking the rule has turned off).
	 * The targets cache is preset so the active filter, not DurableId resolution, is what this exercises.
	 */
	@IsTest
	private static void findActiveForSObjectTypeExcludesTargetBoundToInactiveRule()
	{
		MaskingRule__mdt inactiveRule = TST_Factory.newMaskingRule(new Map<SObjectField, Object> {MaskingRule__mdt.IsActive__c => false});
		MaskingTarget__mdt target = TST_Factory.newMaskingTarget(new Map<SObjectField, Object>
		{
				MaskingTarget__mdt.IsActive__c => true,
				MaskingTarget__mdt.Rule__c => inactiveRule.Id
		});
		SEL_MaskingTarget.cachedTargetsByType = new Map<SObjectType, List<MaskingTarget__mdt>>
		{
				Foobar__c.SObjectType => new List<MaskingTarget__mdt> {target}
		};
		SEL_MaskingTarget.allRulesOverrideForTest = new Map<String, MaskingRule__mdt> {'InactiveRule' => inactiveRule};

		Assert.areEqual(1, new SEL_MaskingTarget().findAllForSObjectType(Foobar__c.SObjectType).size(), 'findAll surfaces the target so the advisor can offer re-enable');
		Assert.isTrue(new SEL_MaskingTarget().findActiveForSObjectType(Foobar__c.SObjectType).isEmpty(), 'findActive excludes a target bound to an inactive rule');
	}

	/**
	 * @description Tests that an active target bound to a **missing** rule (an Id no rule matches) is
	 * likewise surfaced by `findAllForSObjectType` but excluded by `findActiveForSObjectType` — the engine
	 * never applies a target whose rule cannot be resolved.
	 */
	@IsTest
	private static void findActiveForSObjectTypeExcludesTargetBoundToMissingRule()
	{
		MaskingTarget__mdt target = TST_Factory.newMaskingTarget(new Map<SObjectField, Object>
		{
				MaskingTarget__mdt.IsActive__c => true,
				MaskingTarget__mdt.Rule__c => UTIL_Random.randomId(MaskingRule__mdt.SObjectType)
		});
		SEL_MaskingTarget.cachedTargetsByType = new Map<SObjectType, List<MaskingTarget__mdt>>
		{
				Foobar__c.SObjectType => new List<MaskingTarget__mdt> {target}
		};
		SEL_MaskingTarget.allRulesOverrideForTest = new Map<String, MaskingRule__mdt>();

		Assert.areEqual(1, new SEL_MaskingTarget().findAllForSObjectType(Foobar__c.SObjectType).size(), 'findAll surfaces the target with the dead rule reference');
		Assert.isTrue(new SEL_MaskingTarget().findActiveForSObjectType(Foobar__c.SObjectType).isEmpty(), 'findActive excludes a target whose rule cannot be resolved');
	}

	/**
	 * @description Tests that `getRuleById` resolves a shipped rule to a fully-populated `MaskingRule__mdt`
	 * — `Mode__c` and `Pattern__c` (the fields the masker reads, and the exact fields the old JSON-rehydrate
	 * path lost in managed runtime) are non-null. Also exercises the rule cache's lazy build and cache-hit
	 * branches across the two lookups.
	 */
	@IsTest
	private static void getRuleByIdResolvesFullyPopulatedShippedRule()
	{
		SEL_MaskingTarget.cachedRulesById = null;

		Map<Id, MaskingRule__mdt> rulesById = new SEL_MaskingTarget().getAllRulesById();
		Assert.isFalse(rulesById.isEmpty(), 'At least one shipped rule must be loaded to exercise getRuleById');

		Id anyRuleId = new List<Id>(rulesById.keySet()).iterator().next();
		MaskingRule__mdt first = SEL_MaskingTarget.getRuleById(anyRuleId);
		MaskingRule__mdt second = SEL_MaskingTarget.getRuleById(anyRuleId);

		Assert.isNotNull(first, 'getRuleById must resolve a loaded rule');
		Assert.areEqual(first, second, 'a second lookup resolves from the populated cache');
		Assert.isNotNull(first.Mode__c, 'Mode__c must be populated — this is the field the rehydrate path used to drop');
		Assert.isNotNull(first.Pattern__c, 'Pattern__c must be populated');
	}

	/**
	 * @description Tests that `getRuleById` returns `null` for a null Id without touching the cache — a
	 * dead or orphaned `Rule__c` reference resolves to null rather than throwing.
	 */
	@IsTest
	private static void getRuleByIdReturnsNullForNullId()
	{
		Assert.isNull(SEL_MaskingTarget.getRuleById(null), 'A null rule Id must resolve to null');
	}

	/**
	 * @description Tests that `getRuleById` returns `null` for a rule Id that isn't loaded — a defensive
	 * path for orphaned `MaskingTarget__mdt.Rule__c` values.
	 */
	@IsTest
	private static void getRuleByIdReturnsNullForUnknownId()
	{
		SEL_MaskingTarget.cachedRulesById = null;

		Id unknown = UTIL_Random.randomId(MaskingRule__mdt.SObjectType);

		Assert.isNull(SEL_MaskingTarget.getRuleById(unknown), 'Unknown rule Id must resolve to null, not throw');
	}

	/**
	 * @description Tests that `getAllTargets` returns inactive targets too — the one behaviour that differs
	 * from `findActiveForSObjectType`. The dead-configuration check needs the inactive ones, so a single
	 * inactive record proves the point.
	 */
	@IsTest
	private static void getAllTargetsIncludesInactiveTargets()
	{
		MaskingTarget__mdt inactiveTarget = TST_Factory.newMaskingTarget(new Map<SObjectField, Object> {MaskingTarget__mdt.IsActive__c => false});
		SEL_MaskingTarget.allTargetsOverrideForTest = new Map<String, MaskingTarget__mdt> {'InactiveTarget' => inactiveTarget};

		List<MaskingTarget__mdt> targets = new SEL_MaskingTarget().getAllTargets();

		Assert.areEqual(1, targets.size(), 'inactive targets are returned unfiltered, unlike findActiveForSObjectType');
		Assert.isFalse(targets[0].IsActive__c, 'the returned target is the inactive one');
	}

	/**
	 * @description Tests that `getAllTargets` reads the shipped CMDT via `getAll()` when no override seam is
	 * set, returning a list rather than null.
	 */
	@IsTest
	private static void getAllTargetsReadsShippedConfigurationByDefault()
	{
		List<MaskingTarget__mdt> targets = new SEL_MaskingTarget().getAllTargets();

		Assert.isNotNull(targets, 'shipped targets are returned, never null');
	}

	/**
	 * @description Tests that `getAllRulesById` keys both active and inactive rules by Id via the
	 * `allRulesOverrideForTest` seam, so callers can distinguish an inactive-rule reference from a
	 * missing-rule reference.
	 */
	@IsTest
	private static void getAllRulesByIdRetainsInactiveRules()
	{
		SEL_MaskingTarget.cachedRulesById = null;
		MaskingRule__mdt inactiveRule = TST_Factory.newMaskingRule(new Map<SObjectField, Object> {MaskingRule__mdt.IsActive__c => false});
		SEL_MaskingTarget.allRulesOverrideForTest = new Map<String, MaskingRule__mdt> {'InactiveRule' => inactiveRule};

		Map<Id, MaskingRule__mdt> rulesById = new SEL_MaskingTarget().getAllRulesById();

		Assert.isTrue(rulesById.containsKey(inactiveRule.Id), 'inactive rules are retained, unlike an active-only sidecar');
	}

	/**
	 * @description Tests that `getAllRulesById` reads the shipped CMDT via `getAll()` when no override seam
	 * is set, returning a map rather than null.
	 */
	@IsTest
	private static void getAllRulesByIdReadsShippedConfigurationByDefault()
	{
		SEL_MaskingTarget.cachedRulesById = null;

		Map<Id, MaskingRule__mdt> rulesById = new SEL_MaskingTarget().getAllRulesById();

		Assert.isNotNull(rulesById, 'shipped rules are returned, never null');
	}

	/**
	 * @description Tests the mock-path branch in `findMockedFor` where a registered mock target carries both
	 * a `Rule__c` Id and a populated `Rule__r` child — the parent rule is primed into the rule cache so
	 * `getRuleById` resolves it. Self-covers this selector without relying on `UTIL_FrameworkMasker_TEST`.
	 */
	@IsTest
	private static void shouldPrimeRuleCacheFromMockTargetRuleRelationship()
	{
		MaskingRule__mdt rule = TST_Factory.newMaskingRule(new Map<SObjectField, Object> {MaskingRule__mdt.IsActive__c => true});
		MaskingTarget__mdt target = TST_Factory.newMaskingTarget(new Map<SObjectField, Object>
		{
				MaskingTarget__mdt.IsActive__c => true,
				MaskingTarget__mdt.SObjectType__c => OBJECT_FOOBAR
		}, rule);
		TST_Mock.register(MaskingTarget__mdt.SObjectType, target);

		new SEL_MaskingTarget().findActiveForSObjectType(Foobar__c.SObjectType);

		Assert.areEqual(rule, SEL_MaskingTarget.getRuleById(rule.Id), 'mock target Rule__r must prime the rule cache');
	}

	/**
	 * @description Tests that `findAllForSObjectType` returns active **and** inactive mocked targets for a
	 * type, where `findActiveForSObjectType` returns only the active one — the diff needs the inactive
	 * targets so the advisor can offer re-enable.
	 */
	@IsTest
	private static void findAllForSObjectTypeReturnsActiveAndInactiveMockedTargets()
	{
		TST_Mock.of(MaskingTarget__mdt.SObjectType)
				.withOverride(MaskingTarget__mdt.IsActive__c, true)
				.withOverride(MaskingTarget__mdt.SObjectType__c, OBJECT_FOOBAR)
				.build();
		TST_Mock.of(MaskingTarget__mdt.SObjectType)
				.withOverride(MaskingTarget__mdt.IsActive__c, false)
				.withOverride(MaskingTarget__mdt.SObjectType__c, OBJECT_FOOBAR)
				.build();

		List<MaskingTarget__mdt> allTargets = new SEL_MaskingTarget().findAllForSObjectType(Foobar__c.SObjectType);
		List<MaskingTarget__mdt> activeTargets = new SEL_MaskingTarget().findActiveForSObjectType(Foobar__c.SObjectType);

		Assert.areEqual(2, allTargets.size(), 'findAllForSObjectType returns active and inactive targets');
		Assert.areEqual(1, activeTargets.size(), 'findActiveForSObjectType still omits the inactive target');
	}

	/**
	 * @description Tests that `findAllForSObjectType` returns the transaction-scoped targets cache when it
	 * is pre-populated, returning the cached list without rebuilding (the lazy property's cache-hit branch).
	 */
	@IsTest
	private static void findAllForSObjectTypeReturnsCachedTargetsWhenCachePopulated()
	{
		MaskingTarget__mdt cached = TST_Factory.newMaskingTarget(new Map<SObjectField, Object>());
		SEL_MaskingTarget.cachedTargetsByType = new Map<SObjectType, List<MaskingTarget__mdt>>
		{
				Foobar__c.SObjectType => new List<MaskingTarget__mdt> {cached}
		};

		List<MaskingTarget__mdt> results = new SEL_MaskingTarget().findAllForSObjectType(Foobar__c.SObjectType);

		Assert.areEqual(1, results.size(), 'returns the cached targets list untouched');
		Assert.areEqual(cached, results[0], 'returns the exact cached instance');
	}

	/**
	 * @description Tests that `findAllForSObjectType` returns an empty list for a type absent from the
	 * populated targets cache.
	 */
	@IsTest
	private static void findAllForSObjectTypeReturnsEmptyListWhenCacheHasNoEntryForType()
	{
		SEL_MaskingTarget.cachedTargetsByType = new Map<SObjectType, List<MaskingTarget__mdt>>
		{
				Account.SObjectType => new List<MaskingTarget__mdt> {TST_Factory.newMaskingTarget(new Map<SObjectField, Object>())}
		};

		List<MaskingTarget__mdt> results = new SEL_MaskingTarget().findAllForSObjectType(Foobar__c.SObjectType);

		Assert.isTrue(results.isEmpty(), 'returns an empty list for a type absent from the cache');
	}

	/**
	 * @description Tests the all-targets production load path — clears the cache and the `TST_Mock` registry
	 * so reading lazily triggers `groupTargetsByType`, which groups every shipped target by SObjectType
	 * through the EntityDefinition DurableId resolution. `ApiCall__c` carries shipped targets, so the type
	 * resolves and the cache populates.
	 */
	@IsTest
	private static void findAllForSObjectTypeLoadsShippedConfigurationViaProductionPath()
	{
		SEL_MaskingTarget.cachedTargetsByType = null;
		TST_Mock.clear(MaskingTarget__mdt.SObjectType);

		List<MaskingTarget__mdt> results = new SEL_MaskingTarget().findAllForSObjectType(ApiCall__c.SObjectType);

		Assert.isNotNull(SEL_MaskingTarget.cachedTargetsByType, 'all-targets cache must populate after a non-mock lookup');
		Assert.isFalse(SEL_MaskingTarget.cachedTargetsByType.isEmpty(), 'shipped targets should be discovered and grouped by type');
		Assert.isFalse(results.isEmpty(), 'shipped ApiCall__c targets are returned');
	}

	/**
	 * @description Covers the "unresolvable EntityDefinition DurableId" branch in `groupTargetsByType`. A
	 * target whose `SObjectType__c` contains a DurableId that no EntityDefinition row matches is dropped
	 * silently rather than cached against a null type, so the type's cache entry is empty.
	 */
	@IsTest
	private static void findAllForSObjectTypeDropsTargetWithUnresolvableDurableId()
	{
		SEL_MaskingTarget.cachedTargetsByType = null;
		TST_Mock.clear(MaskingTarget__mdt.SObjectType);

		MaskingTarget__mdt unresolvableTarget = TST_Factory.newMaskingTarget(new Map<SObjectField, Object>
		{
				MaskingTarget__mdt.IsActive__c => true,
				MaskingTarget__mdt.SObjectType__c => UTIL_Random.randomId(EntityDefinition.SObjectType)
		});
		SEL_MaskingTarget.allTargetsOverrideForTest = new Map<String, MaskingTarget__mdt> {'UnresolvableTarget' => unresolvableTarget};

		List<MaskingTarget__mdt> results = new SEL_MaskingTarget().findAllForSObjectType(Foobar__c.SObjectType);

		Assert.isTrue(results.isEmpty(), 'a target with an unresolvable DurableId is dropped');
		Assert.isTrue(SEL_MaskingTarget.cachedTargetsByType.isEmpty(), 'the unresolvable target must not populate the by-type cache');
	}

	/**
	 * @description Tests that the rule cache degrades to the flat selector read when
	 * `MaskingRule__mdt.getAll()` throws `System.ListException` (an org-local record sharing a packaged
	 * record's DeveloperName bricks the platform call), and that every fallback-loaded rule fingerprints
	 * identically to its getAll()-shaped fast-path counterpart — the supersession shape-parity contract
	 * the baked `ShippedFingerprint__c`/`ReplacesFingerprint__c` constants depend on. MasterLabel and
	 * Category__c parity pins the advisor's read surface, NamespacePrefix the verdict keying.
	 */
	@IsTest
	private static void shouldFallBackToSelectorReadWhenRuleGetAllCollides()
	{
		SEL_MaskingTarget.simulateGetAllCollisionForTest = true;
		SEL_MaskingTarget.cachedRulesById = null;

		Map<Id, MaskingRule__mdt> fallbackRules = new SEL_MaskingTarget().getAllRulesById();

		Assert.isFalse(fallbackRules.isEmpty(), 'the fallback read must still load the shipped rules');

		SEL_MaskingTarget.simulateGetAllCollisionForTest = false;
		SEL_MaskingTarget.cachedRulesById = null;
		Map<Id, MaskingRule__mdt> fastPathRules = new SEL_MaskingTarget().getAllRulesById();

		Assert.areEqual(fastPathRules.keySet(), fallbackRules.keySet(), 'both paths must load the same rule records');
		for(Id ruleId : fastPathRules.keySet())
		{
			MaskingRule__mdt fastPath = fastPathRules.get(ruleId);
			MaskingRule__mdt fallback = fallbackRules.get(ruleId);
			Assert.areEqual(SEL_MaskingRule.computeFingerprint(fastPath), SEL_MaskingRule.computeFingerprint(fallback),
					'a fallback-shaped record must fingerprint identically to the getAll()-shaped record: ' + fastPath.DeveloperName);
			Assert.areEqual(fastPath.MasterLabel, fallback.MasterLabel,
					'the fallback must carry MasterLabel — advisor surfaces label rules from cached records: ' + fastPath.DeveloperName);
			Assert.areEqual(fastPath.Category__c, fallback.Category__c,
					'the fallback must carry Category__c — the advisor rule picker groups on it: ' + fastPath.DeveloperName);
			Assert.areEqual(fastPath.NamespacePrefix, fallback.NamespacePrefix,
					'the fallback must carry NamespacePrefix — supersession verdicts key on it: ' + fastPath.DeveloperName);
		}
	}

	/**
	 * @description Tests that the targets cache degrades to the flat selector read when
	 * `MaskingTarget__mdt.getAll()` collides, and that fallback records keep the getAll() record shape:
	 * any field is readable (a raw SOQL row throws `SObjectException` on un-queried field reads) and
	 * relationship fields stay null, so `resolveQualifiedFieldName` keeps resolving surface keys from
	 * `Field__c` DurableIds exactly as on the fast path. Active derivation crossing both fallback
	 * caches proves the rule sidecar still resolves.
	 */
	@IsTest
	private static void shouldFallBackToSelectorReadWhenTargetGetAllCollides()
	{
		// No TST_Mock.clear here: clear() installs an EMPTY QRY_Builder query mock for the type,
		// which would hijack the very selector fallback query this test exercises.
		SEL_MaskingTarget.simulateGetAllCollisionForTest = true;
		SEL_MaskingTarget.cachedTargetsByType = null;
		SEL_MaskingTarget.cachedRulesById = null;

		List<MaskingTarget__mdt> allTargets = new SEL_MaskingTarget().findAllForSObjectType(ApiCall__c.SObjectType);
		List<MaskingTarget__mdt> activeTargets = new SEL_MaskingTarget().findActiveForSObjectType(ApiCall__c.SObjectType);

		Assert.isFalse(allTargets.isEmpty(), 'the fallback read must still load the shipped ApiCall targets');
		Assert.isFalse(activeTargets.isEmpty(), 'active derivation must still work across the two fallback caches');
		for(MaskingTarget__mdt target : allTargets)
		{
			Assert.isNull(target.SObjectType__r, 'fallback targets must keep the getAll() shape — null relationships, readable fields: ' + target.DeveloperName);
			Assert.isNull(target.Field__r, 'fallback targets must keep the getAll() shape — null relationships, readable fields: ' + target.DeveloperName);
			Assert.isNull(target.Rule__r, 'fallback targets must resolve rules through the sidecar cache, never Rule__r: ' + target.DeveloperName);
		}
	}

	/**
	 * @description Tests that `getAllTargets` — the advisor's raw accessor, the third direct platform
	 * read alongside the two caches — survives a getAll() collision through the same shaped fallback,
	 * so advisor pages keep rendering while the org carries a colliding record.
	 */
	@IsTest
	private static void getAllTargetsFallsBackToSelectorReadWhenGetAllCollides()
	{
		SEL_MaskingTarget.simulateGetAllCollisionForTest = true;

		List<MaskingTarget__mdt> targets = new SEL_MaskingTarget().getAllTargets();

		Assert.isFalse(targets.isEmpty(), 'the fallback read must still return the shipped targets');
	}

	/**
	 * @description Tests that the collision fallback announces itself: one flood-controlled WARN per
	 * CMDT type per transaction, fingerprinted under the masking collision key and naming the type —
	 * rebuilding the cache in the same transaction must not emit twice. The emission itself is masked
	 * through these same selector caches (LOG_Engine masks every LogEntryEvent__e), so a green run also
	 * proves the fallback emission is re-entrancy-safe.
	 */
	@IsTest
	private static void shouldEmitFloodControlledWarningOnCollisionFallback()
	{
		LOG_Builder.ignoreTestMode = true;
		SEL_MaskingTarget.simulateGetAllCollisionForTest = true;
		SEL_MaskingTarget.cachedRulesById = null;
		SEL_MaskingTarget.cachedTargetsByType = null;

		Test.startTest();
		new SEL_MaskingTarget().getAllRulesById();
		SEL_MaskingTarget.cachedRulesById = null;
		new SEL_MaskingTarget().getAllRulesById();
		Test.stopTest();

		String expectedFingerprint = 'detail:masking:cmdt-collision:' + SEL_MaskingRule.OBJECT_NAME;
		Integer warningCount = 0;
		for(LogEntry__c row : new SEL_LogEntry().getAll())
		{
			if(expectedFingerprint.equals(row.Fingerprint__c))
			{
				warningCount++;
				Assert.areEqual(LOG_Engine.LEVEL_WARN, row.LogLevel__c, 'the collision fallback must log at WARN');
				Assert.isTrue(row.Message__c.contains(SEL_MaskingRule.OBJECT_NAME), 'the warning must name the colliding CMDT type');
			}
		}
		Assert.areEqual(1, warningCount, 'exactly one detail WARN per CMDT type per transaction — flood-controlled and re-entrancy-guarded');
	}

	/**
	 * @description Tests that the collision warning names the colliding DeveloperNames when the
	 * fallback records actually contain a cross-namespace duplicate — the admin-facing breadcrumb
	 * for WHICH org-local clone to rename or remove. The fallback query is mocked with two rules
	 * sharing one DeveloperName, the real shape of the production collision.
	 */
	@IsTest
	private static void shouldNameDuplicateDeveloperNamesInCollisionWarning()
	{
		LOG_Builder.ignoreTestMode = true;
		SEL_MaskingTarget.simulateGetAllCollisionForTest = true;
		SEL_MaskingTarget.cachedRulesById = null;
		MaskingRule__mdt packaged = TST_Factory.newMaskingRule(new Map<SObjectField, Object> {MaskingRule__mdt.DeveloperName => 'ClonedRule'});
		MaskingRule__mdt orgLocalClone = TST_Factory.newMaskingRule(new Map<SObjectField, Object> {MaskingRule__mdt.DeveloperName => 'ClonedRule'});
		QRY_Builder.setMock(MaskingRule__mdt.SObjectType, new List<MaskingRule__mdt> {packaged, orgLocalClone});

		Test.startTest();
		new SEL_MaskingTarget().getAllRulesById();
		Test.stopTest();

		String expectedFingerprint = 'detail:masking:cmdt-collision:' + SEL_MaskingRule.OBJECT_NAME;
		for(LogEntry__c row : new SEL_LogEntry().getAll())
		{
			if(expectedFingerprint.equals(row.Fingerprint__c))
			{
				Assert.isTrue(row.Message__c.contains('ClonedRule'), 'the warning must name the duplicated DeveloperName: ' + row.Message__c);
				return;
			}
		}
		Assert.fail('the collision WARN detail row must persist');
	}

	/**
	 * @description Pins the LongTextArea truncation AT the fallback boundary, not just in the
	 * `normaliseToGetAllShape` helper in isolation: a fallback-loaded rule whose Pattern__c exceeds
	 * the getAll() budget must come out of the rule cache truncated to 255 characters, or
	 * supersession fingerprints would differ per load path. Every SHIPPED pattern is under 255
	 * characters (longest 245), so only a mocked oversized rule keeps this contract pinned — without
	 * this test, removing the normalisation call from the fallback would sail through the suite.
	 */
	@IsTest
	private static void shouldTruncateOversizedPatternThroughFallbackBoundary()
	{
		SEL_MaskingTarget.simulateGetAllCollisionForTest = true;
		SEL_MaskingTarget.cachedRulesById = null;
		MaskingRule__mdt oversized = TST_Factory.newMaskingRule(new Map<SObjectField, Object> {MaskingRule__mdt.Pattern__c => '4'.repeat(300)});
		QRY_Builder.setMock(MaskingRule__mdt.SObjectType, new List<MaskingRule__mdt> {oversized});

		Map<Id, MaskingRule__mdt> rules = new SEL_MaskingTarget().getAllRulesById();

		Assert.areEqual('4'.repeat(255), rules.get(oversized.Id).Pattern__c,
				'the fallback boundary must mirror the getAll() LongTextArea truncation — fingerprint shape parity depends on it');
	}

	/**
	 * @description Guards the critical no-brick regression: inserting a framework record through its
	 * trigger (TRG_Dispatcher → UTIL_FrameworkMasker) under a simulated getAll() collision must SUCCEED
	 * and the record must persist. The defect this guards bricked every framework-object insert with the
	 * platform ListException when an org-local CMDT clone collided with a shipped DeveloperName.
	 *
	 * Asserts SURVIVAL only, not the masked value. The masked value under the collision fallback depends
	 * on CMDT MetadataRelationship resolution (SObjectType__c / Rule__c DurableIds) that differs across org
	 * contexts: it resolves consistently in subscriber (foreign-namespace) and no-namespace dev orgs — where
	 * the card IS redacted — but the package's own-namespace validation runtime resolves the flat-SOQL
	 * fallback differently and leaves the value unmasked, so a masked-value assertion is fragile there (a
	 * validation-context artifact, not a subscriber-facing defect). The masked-value-under-collision contract
	 * is proven where it is reliably testable: the mocked UTIL_FrameworkMasker_TEST redaction tests (TST_Mock
	 * seam) and subscriber-side release-test section 77 (the real engine against a deployed clone).
	 */
	@IsTest
	private static void shouldSurviveFrameworkRecordInsertWhenGetAllCollides()
	{
		// No TST_Mock.clear here: clear() installs an EMPTY QRY_Builder query mock for the type,
		// which would hijack the selector fallback query and silently disable masking.
		SEL_MaskingTarget.simulateGetAllCollisionForTest = true;
		SEL_MaskingTarget.cachedTargetsByType = null;
		SEL_MaskingTarget.cachedRulesById = null;

		ApiCall__c apiCall = TST_Factory.newApiCall('card 4111111111111111 saved');
		// Insert through the framework DML in system mode: managed package-validation runs as a user
		// without FLS on the framework's own objects, so a USER_MODE insert of kern__ApiCall__c fails
		// field-accessibility. The collision-fallback path under test still fires in the before-insert
		// trigger regardless of access level — system mode only removes the unrelated FLS variable.
		DML_Builder.newTransaction().doInsert(apiCall).withSystemMode().execute();

		Assert.isNotNull(apiCall.Id,
				'the before-insert trigger must not brick on the getAll() collision — the insert must commit');
		ApiCall__c stored = (ApiCall__c)new SEL_ApiCall().findById(apiCall.Id);
		Assert.isNotNull(stored,
				'the framework record must persist after a collision-fallback insert (no ListException brick)');
	}

}