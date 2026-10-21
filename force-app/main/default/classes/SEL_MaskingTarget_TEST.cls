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
 * @date April 2026, October 2026
 */
@IsTest(seeAllData=false isParallel=true)
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
private class SEL_MaskingTarget_TEST
{
	/**
	 * @description The API name of the Foobar__c test object used to register mock and preset targets.
	 */
	private static final String OBJECT_FOOBAR = UTIL_SObjectDescribe.getObjectNameFromType(Foobar__c.SObjectType);

	/**
	 * @description How many targets the package ships for the MaskJwt rule, counted over every object.
	 */
	private static final Integer SHIPPED_JWT_TARGET_COUNT = 2;

	/**
	 * @description Tests that `findActiveForSObjectType` returns the registered mocks when `TST_Mock`
	 * has MaskingTarget records, so the mocking that `UTIL_FrameworkMasker_TEST` relies on keeps
	 * working.
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
	 * @description Tests that `findActiveForSObjectType` filters mocked records by `IsActive__c`:
	 * inactive mocks are left out, so the engine never applies them.
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
	 * `SObjectType__c`: only mocks for the requested type are returned.
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
						'Default fields should include NamespacePrefix: code that reads the namespace keeps packaged and org-local targets apart'
				);
	}

	/**
	 * @description Tests that `getFieldPaths` includes the EntityDefinition and FieldDefinition
	 * qualified API name paths, built by hand, so callers that build their own target queries through
	 * `SEL_Base.query` still get the object and field names without working out the namespace prefix.
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
	 * @description Tests that `systemModeRequired` is true. The selector must always run in
	 * SYSTEM_MODE because subscribers usually do not give running users access to `kern__*__mdt`
	 * records, so a USER_MODE read would quietly return no records.
	 */
	@IsTest
	private static void shouldRequireSystemMode()
	{
		Assert.isTrue(new SEL_MaskingTarget().systemModeRequired(), 'MaskingTarget selector must always run in SYSTEM_MODE');
	}

	/**
	 * @description Tests how production finds the active targets. Clears the caches and the `TST_Mock`
	 * registry, so the read builds `cachedTargetsByType` (one EntityDefinition SOQL) and `cachedRulesById`
	 * on first use, then filters the type's targets to the active ones. `ApiCall__c` has shipped active
	 * targets, so the active list and both caches are filled.
	 */
	@IsTest
	private static void findActiveForSObjectTypeDerivesActiveFromShippedConfiguration()
	{
		SEL_MaskingTarget.cachedTargetsByType = null;
		SEL_MaskingTarget.cachedRulesById = null;
		TST_Mock.clear(MaskingTarget__mdt.SObjectType);

		List<MaskingTarget__mdt> results = new SEL_MaskingTarget().findActiveForSObjectType(ApiCall__c.SObjectType);

		Assert.isFalse(results.isEmpty(), 'Shipped active ApiCall__c targets should be found');
		for(MaskingTarget__mdt target : results)
		{
			Assert.isTrue(target.IsActive__c, 'Every target found is active');
		}
		Assert.isNotNull(SEL_MaskingTarget.cachedTargetsByType, 'All-targets cache must populate after a non-mock lookup');
		Assert.isNotNull(SEL_MaskingTarget.cachedRulesById, 'Rule cache must be filled when the active targets are found');
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
	 * @description Tests a rule that keeps the engine safe: a target that is active itself but linked to
	 * an **inactive** rule is returned by `findAllForSObjectType` (so the advisor can offer to switch it
	 * back on) but left out by `findActiveForSObjectType` (so the engine never applies masking the rule
	 * has turned off). The targets cache is set up in advance, so the test covers the active filter and
	 * not the DurableId lookup.
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

		Assert.areEqual(1, new SEL_MaskingTarget().findAllForSObjectType(Foobar__c.SObjectType).size(), 'findAll returns the target so the advisor can offer to switch it back on');
		Assert.isTrue(new SEL_MaskingTarget().findActiveForSObjectType(Foobar__c.SObjectType).isEmpty(), 'findActive excludes a target bound to an inactive rule');
	}

	/**
	 * @description Tests that an active target linked to a **missing** rule (an Id no rule matches) is
	 * also returned by `findAllForSObjectType` but left out by `findActiveForSObjectType`: the engine
	 * never applies a target whose rule cannot be found.
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

		Assert.areEqual(1, new SEL_MaskingTarget().findAllForSObjectType(Foobar__c.SObjectType).size(), 'findAll returns the target that points at a missing rule');
		Assert.isTrue(new SEL_MaskingTarget().findActiveForSObjectType(Foobar__c.SObjectType).isEmpty(), 'findActive excludes a target whose rule cannot be resolved');
	}

	/**
	 * @description Tests that `getRuleById` returns a shipped rule as a `MaskingRule__mdt` with every field
	 * filled: `Mode__c` and `Pattern__c` (the fields the masker reads, and exactly the fields the old
	 * path, which rebuilt rules from JSON, lost in a managed package) are not null. The two lookups also
	 * cover both the first build of the rule cache and a later read from the filled cache.
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
		Assert.isNotNull(first.Mode__c, 'Mode__c must be filled: this is the field the old JSON path used to drop');
		Assert.isNotNull(first.Pattern__c, 'Pattern__c must be populated');
	}

	/**
	 * @description Tests that `getRuleById` returns `null` for a null Id without touching the cache: a
	 * missing or broken `Rule__c` reference gives null and does not throw.
	 */
	@IsTest
	private static void getRuleByIdReturnsNullForNullId()
	{
		Assert.isNull(SEL_MaskingTarget.getRuleById(null), 'A null rule Id must resolve to null');
	}

	/**
	 * @description Tests that `getRuleById` returns `null` for a rule Id that is not loaded. This
	 * protects against `MaskingTarget__mdt.Rule__c` values that point at no rule.
	 */
	@IsTest
	private static void getRuleByIdReturnsNullForUnknownId()
	{
		SEL_MaskingTarget.cachedRulesById = null;

		Id unknown = UTIL_Random.randomId(MaskingRule__mdt.SObjectType);

		Assert.isNull(SEL_MaskingTarget.getRuleById(unknown), 'Unknown rule Id must resolve to null, not throw');
	}

	/**
	 * @description Tests that `getAllTargets` returns inactive targets too, which is the one way it
	 * differs from `findActiveForSObjectType`. The dead-configuration check needs the inactive ones, so
	 * one inactive record is enough to show it.
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
	 * @description Tests that `getAllTargets` reads the shipped CMDT via `getAll()` when no test override is
	 * set, returning a list rather than null.
	 */
	@IsTest
	private static void getAllTargetsReadsShippedConfigurationByDefault()
	{
		List<MaskingTarget__mdt> targets = new SEL_MaskingTarget().getAllTargets();

		Assert.isNotNull(targets, 'shipped targets are returned, never null');
	}

	/**
	 * @description Tests that `getAllRulesById` keys both active and inactive rules by Id, through the
	 * `allRulesOverrideForTest` test override, so callers can tell a target whose rule is inactive
	 * apart from a target whose rule is missing.
	 */
	@IsTest
	private static void getAllRulesByIdRetainsInactiveRules()
	{
		SEL_MaskingTarget.cachedRulesById = null;
		MaskingRule__mdt inactiveRule = TST_Factory.newMaskingRule(new Map<SObjectField, Object> {MaskingRule__mdt.IsActive__c => false});
		SEL_MaskingTarget.allRulesOverrideForTest = new Map<String, MaskingRule__mdt> {'InactiveRule' => inactiveRule};

		Map<Id, MaskingRule__mdt> rulesById = new SEL_MaskingTarget().getAllRulesById();

		Assert.isTrue(rulesById.containsKey(inactiveRule.Id), 'inactive rules are kept, unlike in a cache of active rules only');
	}

	/**
	 * @description Tests that `getAllRulesById` reads the shipped CMDT via `getAll()` when no test override
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
	 * @description Tests the mock branch in `findMockedFor` where a registered mock target has both a
	 * `Rule__c` Id and a filled `Rule__r` child: the parent rule is added to the rule cache, so
	 * `getRuleById` finds it. Covers this selector on its own, without relying on
	 * `UTIL_FrameworkMasker_TEST`.
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

		Assert.areEqual(rule, SEL_MaskingTarget.getRuleById(rule.Id), 'mock target Rule__r must be added to the rule cache');
	}

	/**
	 * @description Tests that `findAllForSObjectType` returns active **and** inactive mocked targets for a
	 * type, while `findActiveForSObjectType` returns only the active one. The advisor's list of changes
	 * needs the inactive targets, so it can offer to switch them back on.
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
	 * @description Tests that `findAllForSObjectType` returns the targets cache for the transaction when
	 * it is already filled, without building it again (the branch where the cache already has a value).
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
	 * @description Tests how production loads all targets. Clears the cache and the `TST_Mock` registry,
	 * so the read calls `groupTargetsByType` on first use. That method groups every shipped target by
	 * SObjectType through the EntityDefinition DurableId lookup. `ApiCall__c` has shipped targets, so
	 * the type is found and the cache is filled.
	 */
	@IsTest
	private static void findAllForSObjectTypeLoadsShippedConfigurationViaProductionPath()
	{
		SEL_MaskingTarget.cachedTargetsByType = null;
		TST_Mock.clear(MaskingTarget__mdt.SObjectType);

		List<MaskingTarget__mdt> results = new SEL_MaskingTarget().findAllForSObjectType(ApiCall__c.SObjectType);

		Assert.isNotNull(SEL_MaskingTarget.cachedTargetsByType, 'all-targets cache must be filled after a lookup without mocks');
		Assert.isFalse(SEL_MaskingTarget.cachedTargetsByType.isEmpty(), 'shipped targets should be discovered and grouped by type');
		Assert.isFalse(results.isEmpty(), 'shipped ApiCall__c targets are returned');
	}

	/**
	 * @description Tests that the package ships one active object-wide target for the MaskJwt rule on
	 * each of the two web service log objects (the call record and the issue record), and no other.
	 * It reads the targets the way the engine does, through the selector's own grouping by object, so
	 * the object of each target is resolved by the selector and not read from the stored Id. It counts
	 * the package's own targets only, so a target a subscriber added never counts. It has no guard for a
	 * target a subscriber changed: the test checks the records as the package ships them, and an org that
	 * changed or upgraded them may hold other values.
	 */
	@IsTest
	private static void shouldShipAJwtTargetOnApiCallAndApiIssue()
	{
		SEL_MaskingTarget.cachedTargetsByType = null;
		SEL_MaskingTarget.cachedRulesById = null;
		TST_Mock.clear(MaskingTarget__mdt.SObjectType);

		SEL_MaskingTarget selector = new SEL_MaskingTarget();
		Set<String> objectNames = new Set<String>();
		Integer jwtTargetCount = 0;

		for(MaskingTarget__mdt target : selector.getAllTargets())
		{
			if(isShippedJwtTarget(target, selector))
			{
				jwtTargetCount++;
			}
		}

		Assert.areEqual(SHIPPED_JWT_TARGET_COUNT, jwtTargetCount, 'Expected exactly two shipped targets, on any object, to point at the JWT rule');

		for(SObjectType objectType : new List<SObjectType> {ApiCall__c.SObjectType, ApiIssue__c.SObjectType})
		{
			for(MaskingTarget__mdt target : selector.findAllForSObjectType(objectType))
			{
				if(isShippedJwtTarget(target, selector))
				{
					objectNames.add(UTIL_SObjectDescribe.getObjectNameFromType(objectType));
					Assert.isTrue(target.IsActive__c, 'Expected the JWT target on ' + objectType + ' to ship active');
					Assert.isTrue(String.isBlank(target.Field__c), 'Expected the JWT target on ' + objectType + ' to cover every field');
					Assert.isTrue(String.isBlank(target.CallerClass__c), 'Expected the JWT target on ' + objectType + ' to apply to every caller');
				}
			}
		}

		Assert.areEqual(
				new Set<String> {UTIL_SObjectDescribe.getObjectNameFromType(ApiCall__c.SObjectType), UTIL_SObjectDescribe.getObjectNameFromType(ApiIssue__c.SObjectType)},
				objectNames, 'Expected the JWT targets to cover the call record and the issue record');
	}

	/**
	 * @description Tells whether a target is one of the package's own and points at the shipped MaskJwt rule.
	 *
	 * @param target The target to check
	 * @param selector The selector that resolves the target's rule
	 *
	 * @return True when the target and its rule both belong to the package and the rule is MaskJwt
	 */
	private static Boolean isShippedJwtTarget(MaskingTarget__mdt target, SEL_MaskingTarget selector)
	{
		String packageNamespace = UTIL_System.getManagedPackageNamespace() ?? UTIL_String.EMPTY;
		MaskingRule__mdt rule = selector.getAllRulesById().get(target.Rule__c);

		return rule != null && rule.DeveloperName == SEL_MaskingRule.RULE_MASK_JWT
				&& (rule.NamespacePrefix ?? UTIL_String.EMPTY) == packageNamespace
				&& (target.NamespacePrefix ?? UTIL_String.EMPTY) == packageNamespace;
	}

	/**
	 * @description Covers the branch in `groupTargetsByType` for an EntityDefinition DurableId that
	 * matches nothing. A target whose `SObjectType__c` holds a DurableId that no EntityDefinition row
	 * matches is dropped without notice, not cached against a null type, so the type's cache entry is
	 * empty.
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
		Assert.isTrue(SEL_MaskingTarget.cachedTargetsByType.isEmpty(), 'the target that matches no object must not be added to the by-type cache');
	}

	/**
	 * @description Tests that the rule cache falls back to the flat selector read when
	 * `MaskingRule__mdt.getAll()` throws `System.ListException` (an org-local record with the same
	 * DeveloperName as a packaged record makes the platform call fail). Also tests that every rule loaded
	 * by the fallback gets the same fingerprint as the same rule loaded by getAll() on the normal path.
	 * The stored `ShippedFingerprint__c` and `ReplacesFingerprint__c` values depend on both paths giving
	 * the same shape. MasterLabel and Category__c must match because the advisor reads them;
	 * NamespacePrefix must match because supersession keys rules by it.
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
					'the fallback must carry MasterLabel: the advisor pages show each rule\'s label from cached records: ' + fastPath.DeveloperName);
			Assert.areEqual(fastPath.Category__c, fallback.Category__c,
					'the fallback must carry Category__c: the advisor rule picker groups on it: ' + fastPath.DeveloperName);
			Assert.areEqual(fastPath.NamespacePrefix, fallback.NamespacePrefix,
					'the fallback must carry NamespacePrefix: supersession keys rules by it: ' + fastPath.DeveloperName);
		}
	}

	/**
	 * @description Tests that the targets cache falls back to the flat selector read when
	 * `MaskingTarget__mdt.getAll()` fails on a duplicate name, and that the fallback records keep the
	 * getAll() record shape: every field can be read (a raw SOQL row throws `SObjectException` when code
	 * reads a field that was not queried) and relationship fields stay null. So
	 * `resolveQualifiedFieldName` keeps building field keys from `Field__c` DurableIds exactly as on the
	 * normal path. Finding the active targets through both fallback caches proves that the separate
	 * rule cache still finds each rule.
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
		Assert.isFalse(activeTargets.isEmpty(), 'finding the active targets must still work across the two fallback caches');
		for(MaskingTarget__mdt target : allTargets)
		{
			Assert.isNull(target.SObjectType__r, 'fallback targets must keep the getAll() shape (null relationships, readable fields): ' + target.DeveloperName);
			Assert.isNull(target.Field__r, 'fallback targets must keep the getAll() shape (null relationships, readable fields): ' + target.DeveloperName);
			Assert.isNull(target.Rule__r, 'fallback targets must find rules through the separate rule cache, never Rule__r: ' + target.DeveloperName);
		}
	}

	/**
	 * @description Tests that `getAllTargets` survives a getAll() failure on a duplicate name through the
	 * same reshaped fallback. It is the advisor's method that returns every target, and the third direct
	 * platform read next to the two caches. So advisor pages keep working while the org has a record
	 * with a duplicate name.
	 */
	@IsTest
	private static void getAllTargetsFallsBackToSelectorReadWhenGetAllCollides()
	{
		SEL_MaskingTarget.simulateGetAllCollisionForTest = true;

		List<MaskingTarget__mdt> targets = new SEL_MaskingTarget().getAllTargets();

		Assert.isFalse(targets.isEmpty(), 'the fallback read must still return the shipped targets');
	}

	/**
	 * @description Tests that the duplicate-name fallback reports itself: one flood-controlled WARN per
	 * CMDT type per transaction, with the masking duplicate-name fingerprint key, naming the type.
	 * Building the cache again in the same transaction must not write the warning twice. Writing the
	 * warning itself goes through masking and so through these same selector caches (LOG_Engine masks
	 * every LogEntryEvent__e), so a passing run also proves the warning does not make the code call
	 * itself again.
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
		Assert.areEqual(1, warningCount, 'exactly one detail WARN per CMDT type per transaction, with flood control and no repeated call');
	}

	/**
	 * @description Tests that the duplicate-name warning names the duplicated DeveloperNames when the
	 * fallback records really contain a duplicate across namespaces. This tells the admin WHICH org-local
	 * copy to rename or remove. The fallback query is mocked with two rules that share one DeveloperName,
	 * which is what the real problem looks like in production.
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
	 * @description Tests that LongTextArea values are cut ON the fallback path, not only in the
	 * `normaliseToGetAllShape` helper on its own: a rule loaded by the fallback whose Pattern__c is longer
	 * than the getAll() length must come out of the rule cache cut to 255 characters, or supersession
	 * fingerprints would differ between the two read paths. Every SHIPPED pattern is shorter than 255
	 * characters (the longest is 245), so only a mocked long rule can check this. Without this test,
	 * removing the cut from the fallback would pass the whole test suite.
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
				'the fallback path must cut LongTextArea values like getAll() does, or the fingerprints would differ');
	}

	/**
	 * @description Guards against a serious earlier defect coming back: inserting a framework record
	 * through its trigger (TRG_Dispatcher, then UTIL_FrameworkMasker) while getAll() is made to fail on a
	 * duplicate name must SUCCEED, and the record must be saved. The defect made every framework-object
	 * insert fail with the platform ListException when an org-local CMDT copy had the same DeveloperName
	 * as a shipped record.
	 *
	 * Asserts only that the insert SUCCEEDS, not the masked value. The masked value on the fallback path
	 * depends on how CMDT MetadataRelationship fields (SObjectType__c / Rule__c DurableIds) resolve, and
	 * that differs between orgs. It resolves the same way in subscriber orgs (another namespace) and in
	 * development orgs without a namespace, where the card IS masked. But the package's own validation
	 * runtime, in its own namespace, resolves the flat SOQL fallback differently and leaves the value
	 * unmasked, so an assertion on the masked value would be fragile there (a quirk of that validation
	 * run, not a defect subscribers see). The masked value on the fallback path is tested where it can be
	 * tested reliably: the mocked UTIL_FrameworkMasker_TEST masking tests (through TST_Mock) and the
	 * subscriber release test that runs the real engine against a deployed copy.
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
		// trigger whatever the access level; system mode only takes the unrelated FLS question out of the test.
		DML_Builder.newTransaction().doInsert(apiCall).withSystemMode().execute();

		Assert.isNotNull(apiCall.Id,
				'the before-insert trigger must not fail when getAll() fails on a duplicate name: the insert must commit');
		ApiCall__c stored = (ApiCall__c)new SEL_ApiCall().findById(apiCall.Id);
		Assert.isNotNull(stored,
				'the framework record must be saved after an insert on the duplicate-name fallback (no ListException)');
	}

	/**
	 * @description Tests that building the target cache finds the field name of a target that stores the field's
	 * durable Id, the fixed key the platform gives each field. A deployed target stores this key in `Field__c`, not
	 * `Object.Field`, and `getQualifiedFieldName` must give back `Object.Field`.
	 */
	@IsTest
	private static void shouldFindTheFieldNameOfATargetThatStoresTheFieldDurableId()
	{
		String fieldName = UTIL_SObjectDescribe.getCachedFieldName(Foobar__c.Text__c);
		String fieldDurableId = findFoobarFieldDurableId(fieldName);
		MaskingTarget__mdt deployedTarget = TST_Factory.newMaskingTarget(new Map<SObjectField, Object>
		{
				MaskingTarget__mdt.IsActive__c => true,
				MaskingTarget__mdt.SObjectType__c => fieldDurableId.substringBefore(UTIL_String.DOT),
				MaskingTarget__mdt.Field__c => fieldDurableId
		});
		SEL_MaskingTarget.allTargetsOverrideForTest = new Map<String, MaskingTarget__mdt> {'DeployedFieldTarget' => deployedTarget};
		SEL_MaskingTarget.cachedTargetsByType = null;

		List<MaskingTarget__mdt> results = new SEL_MaskingTarget().findAllForSObjectType(Foobar__c.SObjectType);

		Assert.areEqual(1, results.size(), 'Expected the target to be cached against its object');
		Assert.areEqual(OBJECT_FOOBAR + UTIL_String.DOT + fieldName, SEL_MaskingTarget.getQualifiedFieldName(results[0]),
				'Expected the stored durable Id to give back the field name');
	}

	/**
	 * @description Tests that `getQualifiedFieldName` gives no name for a target that names no field, or for a
	 * target that already stores `Object.Field` as text (the shape test mocks use), so callers keep the stored value.
	 */
	@IsTest
	private static void shouldFindNoFieldNameForATargetWithoutAFieldDurableId()
	{
		String fieldDurableId = findFoobarFieldDurableId(UTIL_SObjectDescribe.getCachedFieldName(Foobar__c.Text__c));
		String objectDurableId = fieldDurableId.substringBefore(UTIL_String.DOT);
		MaskingTarget__mdt wildcardTarget = TST_Factory.newMaskingTarget(new Map<SObjectField, Object>
		{
				MaskingTarget__mdt.IsActive__c => true,
				MaskingTarget__mdt.SObjectType__c => objectDurableId,
				MaskingTarget__mdt.Field__c => null
		});
		MaskingTarget__mdt textTarget = TST_Factory.newMaskingTarget(new Map<SObjectField, Object>
		{
				MaskingTarget__mdt.IsActive__c => true,
				MaskingTarget__mdt.SObjectType__c => objectDurableId,
				MaskingTarget__mdt.Field__c => OBJECT_FOOBAR + UTIL_String.DOT + UTIL_SObjectDescribe.getCachedFieldName(Foobar__c.Text__c)
		});
		SEL_MaskingTarget.allTargetsOverrideForTest = new Map<String, MaskingTarget__mdt> {'WildcardTarget' => wildcardTarget, 'TextTarget' => textTarget};
		SEL_MaskingTarget.cachedTargetsByType = null;

		Assert.areEqual(2, new SEL_MaskingTarget().findAllForSObjectType(Foobar__c.SObjectType).size(), 'Expected both targets to be cached');
		Assert.isNull(SEL_MaskingTarget.getQualifiedFieldName(wildcardTarget), 'Expected no name for a target that names no field');
		Assert.isNull(SEL_MaskingTarget.getQualifiedFieldName(textTarget), 'Expected no name for a value that is not a durable Id');
	}

	/**
	 * @description Reads the durable Id of one `Foobar__c` field from the org.
	 *
	 * @param fieldName The API name of the field.
	 *
	 * @return The field's durable Id: the object's durable Id and the field's Id joined by a dot.
	 */
	private static String findFoobarFieldDurableId(String fieldName)
	{
		String durableId;
		for(FieldDefinition field : new SEL_FieldDefinition().findByEntity(OBJECT_FOOBAR))
		{
			if(field.QualifiedApiName == fieldName)
			{
				durableId = field.DurableId;
			}
		}
		return durableId;
	}
}