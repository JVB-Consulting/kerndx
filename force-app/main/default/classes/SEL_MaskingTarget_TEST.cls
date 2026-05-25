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
 * @date April 2026, May 2026
 */
@IsTest(SeeAllData=false IsParallel=true)
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
private class SEL_MaskingTarget_TEST
{
	/**
	 * @description The API name of the Foobar__c test object used to register mock targets.
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
	 * @description Tests that `findActiveForSObjectType` uses the transaction-scoped cache
	 * when it's pre-populated, returning the cached list without hitting the parent-rule SOQL.
	 */
	@IsTest
	private static void shouldReturnCachedTargetsWhenCachePopulated()
	{
		MaskingTarget__mdt cached = new MaskingTarget__mdt();
		SEL_MaskingTarget.cachedActiveTargetsByType = new Map<SObjectType, List<MaskingTarget__mdt>>
		{
				Foobar__c.SObjectType => new List<MaskingTarget__mdt> {cached}
		};

		List<MaskingTarget__mdt> results = new SEL_MaskingTarget().findActiveForSObjectType(Foobar__c.SObjectType);

		Assert.areEqual(1, results.size(), 'Should return the cached target list untouched');
		Assert.areEqual(cached, results[0], 'Should return the exact cached instance');
	}

	/**
	 * @description Tests that `findActiveForSObjectType` returns an empty list for an
	 * SObjectType that has no entry in the cached map.
	 */
	@IsTest
	private static void shouldReturnEmptyListWhenCacheHasNoEntryForType()
	{
		SEL_MaskingTarget.cachedActiveTargetsByType = new Map<SObjectType, List<MaskingTarget__mdt>>
		{
				Account.SObjectType => new List<MaskingTarget__mdt> {new MaskingTarget__mdt()}
		};

		List<MaskingTarget__mdt> results = new SEL_MaskingTarget().findActiveForSObjectType(Foobar__c.SObjectType);

		Assert.isTrue(results.isEmpty(), 'Should return an empty list for a type absent from the cache');
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
	 * @description Tests the production load path — clears the cache and the `TST_Mock`
	 * registry so reading `cachedActiveTargetsByType` lazily triggers `loadCache`, which
	 * runs `MaskingRule__mdt.getAll()` + `MaskingTarget__mdt.getAll()` + one
	 * `EntityDefinition` SOQL and populates both the target-by-type map and the sidecar
	 * rule-by-Id map.
	 */
	@IsTest
	private static void shouldLoadFromGetAllWhenCacheAndMocksEmpty()
	{
		SEL_MaskingTarget.cachedActiveTargetsByType = null;
		SEL_MaskingTarget.cachedRulesById = null;
		TST_Mock.clear(MaskingTarget__mdt.SObjectType);

		new SEL_MaskingTarget().findActiveForSObjectType(ApiCall__c.SObjectType);

		Assert.isNotNull(SEL_MaskingTarget.cachedActiveTargetsByType, 'Production cache must populate after a non-mock lookup');
		Assert.isFalse(SEL_MaskingTarget.cachedActiveTargetsByType.isEmpty(), 'Shipped MaskingTarget records should be discovered');
		Assert.isNotNull(SEL_MaskingTarget.cachedRulesById, 'Sidecar rule map must populate alongside the target cache');
		Assert.isFalse(SEL_MaskingTarget.cachedRulesById.isEmpty(), 'Shipped MaskingRule records should populate the sidecar map');
	}

	/**
	 * @description Tests that `getRuleById` resolves a target's parent rule to a fully-populated
	 * `MaskingRule__mdt` — the whole point of the sidecar pattern. Picks any rule loaded by the
	 * shipped CMDT and verifies Mode__c and Pattern__c are non-null (the fields the masker reads
	 * for dispatch, and the exact fields the old JSON-rehydrate path lost in managed runtime).
	 */
	@IsTest
	private static void shouldResolveFullyPopulatedRuleByIdViaSidecar()
	{
		SEL_MaskingTarget.cachedActiveTargetsByType = null;
		SEL_MaskingTarget.cachedRulesById = null;
		TST_Mock.clear(MaskingTarget__mdt.SObjectType);

		new SEL_MaskingTarget().findActiveForSObjectType(ApiCall__c.SObjectType);

		Map<Id, MaskingRule__mdt> rulesById = SEL_MaskingTarget.cachedRulesById;
		Assert.isNotNull(rulesById, 'findActiveForSObjectType must populate the sidecar rule cache');
		Assert.isFalse(rulesById.isEmpty(), 'At least one shipped rule must be loaded to exercise getRuleById');

		Id anyRuleId = new List<Id>(rulesById.keySet()).iterator().next();
		MaskingRule__mdt resolved = SEL_MaskingTarget.getRuleById(anyRuleId);

		Assert.isNotNull(resolved, 'getRuleById must resolve a loaded rule');
		Assert.isNotNull(resolved.Mode__c, 'Mode__c must be populated — this is the field the rehydrate path used to drop');
		Assert.isNotNull(resolved.Pattern__c, 'Pattern__c must be populated');
	}

	/**
	 * @description Tests that `getRuleById` returns `null` for a rule Id that isn't loaded — a
	 * defensive path for orphaned `MaskingTarget__mdt.Rule__c` values.
	 */
	@IsTest
	private static void shouldReturnNullForUnknownRuleId()
	{
		SEL_MaskingTarget.cachedActiveTargetsByType = null;
		SEL_MaskingTarget.cachedRulesById = null;

		Id unknown = UTIL_Random.randomId(MaskingRule__mdt.SObjectType);

		Assert.isNull(SEL_MaskingTarget.getRuleById(unknown), 'Unknown rule Id must resolve to null, not throw');
	}

	/**
	 * @description Tests that `findActiveForSObjectType` filters the cached map by the requested
	 * SObjectType's API name — targets registered for other objects must not leak into the
	 * returned list.
	 */
	@IsTest
	private static void shouldReturnEmptyListForSObjectWithoutConfiguredTargets()
	{
		SEL_MaskingTarget.cachedActiveTargetsByType = null;
		SEL_MaskingTarget.cachedRulesById = null;
		TST_Mock.clear(MaskingTarget__mdt.SObjectType);

		List<MaskingTarget__mdt> results = new SEL_MaskingTarget().findActiveForSObjectType(User.SObjectType);

		Assert.isNotNull(results, 'Should return a list, never null');
		Assert.isTrue(results.isEmpty(), 'No shipped target covers User, result should be empty');
	}

	/**
	 * @description Covers the "active target whose parent rule is inactive" branch in
	 * `loadCache`. Shipped CMDT has no such pairing (inactive rules tend to have no targets)
	 * so the branch is exercised via the `allRulesOverrideForTest` / `allTargetsOverrideForTest`
	 * seams.
	 */
	@IsTest
	private static void shouldSkipTargetsWhenParentRuleIsInactive()
	{
		SEL_MaskingTarget.cachedActiveTargetsByType = null;
		SEL_MaskingTarget.cachedRulesById = null;
		TST_Mock.clear(MaskingTarget__mdt.SObjectType);

		Id inactiveRuleId = UTIL_Random.randomId(MaskingRule__mdt.SObjectType);
		MaskingRule__mdt inactiveRule = new MaskingRule__mdt(Id = inactiveRuleId, IsActive__c = false);
		MaskingTarget__mdt orphanTarget = new MaskingTarget__mdt(IsActive__c = true, Rule__c = inactiveRuleId);
		SEL_MaskingTarget.allRulesOverrideForTest = new Map<String, MaskingRule__mdt> {'InactiveRule' => inactiveRule};
		SEL_MaskingTarget.allTargetsOverrideForTest = new Map<String, MaskingTarget__mdt> {'OrphanTarget' => orphanTarget};

		List<MaskingTarget__mdt> results = new SEL_MaskingTarget().findActiveForSObjectType(Foobar__c.SObjectType);

		Assert.isTrue(results.isEmpty(), 'Target whose parent rule is inactive must be dropped');
		Assert.isTrue(SEL_MaskingTarget.cachedRulesById.isEmpty(), 'Inactive rule must not populate the sidecar');
	}

	/**
	 * @description Covers the "unresolvable EntityDefinition DurableId" branch in `loadCache`.
	 * A target whose `SObjectType__c` contains a DurableId that no EntityDefinition row
	 * matches must be dropped silently rather than cached against a null API name.
	 */
	@IsTest
	private static void shouldSkipTargetsWithUnresolvableDurableId()
	{
		SEL_MaskingTarget.cachedActiveTargetsByType = null;
		SEL_MaskingTarget.cachedRulesById = null;
		TST_Mock.clear(MaskingTarget__mdt.SObjectType);

		Id activeRuleId = UTIL_Random.randomId(MaskingRule__mdt.SObjectType);
		MaskingRule__mdt activeRule = new MaskingRule__mdt(Id = activeRuleId, IsActive__c = true);
		MaskingTarget__mdt unresolvableTarget = new MaskingTarget__mdt
				(
						IsActive__c = true,
						Rule__c = activeRuleId,
						SObjectType__c = UTIL_Random.randomId(EntityDefinition.SObjectType)
				);
		SEL_MaskingTarget.allRulesOverrideForTest = new Map<String, MaskingRule__mdt> {'ActiveRule' => activeRule};
		SEL_MaskingTarget.allTargetsOverrideForTest = new Map<String, MaskingTarget__mdt> {'UnresolvableTarget' => unresolvableTarget};

		List<MaskingTarget__mdt> results = new SEL_MaskingTarget().findActiveForSObjectType(Foobar__c.SObjectType);

		Assert.isTrue(results.isEmpty(), 'Target with unresolvable DurableId must be dropped');
		Assert.isTrue(SEL_MaskingTarget.cachedActiveTargetsByType.isEmpty(), 'Unresolvable target must not populate the by-type cache');
	}

}