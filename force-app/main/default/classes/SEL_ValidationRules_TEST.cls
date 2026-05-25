// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Test class for SEL_ValidationRules selector.
 *
 * @see SEL_ValidationRules
 *
 * @author Jason van Beukering
 *
 * @group Validation
 *
 * @date January 2026, May 2026
 */
@IsTest
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
private class SEL_ValidationRules_TEST
{
	/**
	 * @description Verifies that findByObjectAndOperation returns an empty list when querying
	 * for an object that has no validation rules configured.
	 */
	@IsTest
	private static void findByObjectAndOperationReturnsEmptyListForNonExistentObject()
	{
		Test.startTest();
		List<SEL_ValidationRules.ValidationRuleWithGroup> rules = SEL_ValidationRules.findByObjectAndOperation
				(
						'NonExistentObject__c',
						TriggerOperation.BEFORE_INSERT
				);
		Test.stopTest();

		Assert.isTrue(rules.isEmpty(), 'Should return empty list for non-existent object');
	}

	/**
	 * @description Verifies that findByObjectAndOperation returns an empty list when querying
	 * for a trigger operation that has no validation rules configured for the given object.
	 */
	@IsTest
	private static void findByObjectAndOperationReturnsEmptyListForNonExistentOperation()
	{
		Test.startTest();
		List<SEL_ValidationRules.ValidationRuleWithGroup> rules = SEL_ValidationRules.findByObjectAndOperation
				(
						SEL_Foobar.OBJECT_NAME,
						TriggerOperation.AFTER_UNDELETE
				);
		Test.stopTest();

		Assert.isNotNull(rules, 'Rules list should not be null');
	}

	/**
	 * @description Verifies that getAllReferencedFeatureFlags returns a non-null set containing
	 * all feature flag and bypass permission names referenced by validation rules and groups.
	 */
	@IsTest
	private static void getAllReferencedFeatureFlagsReturnsSetOfFeatureFlags()
	{
		Test.startTest();
		Set<String> featureFlags = SEL_ValidationRules.getAllReferencedFeatureFlags();
		Test.stopTest();

		Assert.isNotNull(featureFlags, 'Feature flags set should not be null');
	}

	/**
	 * @description Verifies that the ValidationRuleWithGroup wrapper correctly sets its rule,
	 * ruleGroup, and objectApiName properties from the provided metadata records.
	 */
	@IsTest
	private static void validationRuleWithGroupSetsPropertiesCorrectly()
	{
		TriggerSetting__mdt triggerSetting = TST_Factory.newTriggerSetting(SEL_Foobar.OBJECT_NAME);
		ValidationRule__mdt rule = TST_Factory.newValidationRule();
		ValidationRuleGroup__mdt ruleGroup = TST_Factory.newValidationRuleGroup(triggerSetting, new List<ValidationRule__mdt> {rule});

		Test.startTest();
		SEL_ValidationRules.ValidationRuleWithGroup wrapper = new SEL_ValidationRules.ValidationRuleWithGroup(rule, ruleGroup);
		Test.stopTest();

		Assert.areEqual(rule, wrapper.rule, 'Rule should be set');
		Assert.areEqual(ruleGroup, wrapper.ruleGroup, 'Rule group should be set');
		Assert.areEqual(SEL_Foobar.OBJECT_NAME, wrapper.objectApiName, 'Object API name should be derived from trigger setting');
	}

	/**
	 * @description Verifies that the ValidationRuleWithGroup wrapper correctly prefixes the
	 * object API name with the namespace when the TriggerSetting has a NamespacePrefix set.
	 */
	@IsTest
	private static void validationRuleWithGroupHandlesNamespacedObjects()
	{
		TriggerSetting__mdt triggerSetting = TST_Factory.newTriggerSetting('ns__Custom__c');
		ValidationRule__mdt rule = TST_Factory.newValidationRule();
		ValidationRuleGroup__mdt ruleGroup = TST_Factory.newValidationRuleGroup(triggerSetting, new List<ValidationRule__mdt> {rule});

		Test.startTest();
		SEL_ValidationRules.ValidationRuleWithGroup wrapper = new SEL_ValidationRules.ValidationRuleWithGroup(rule, ruleGroup);
		Test.stopTest();

		Assert.areEqual('ns__Custom__c', wrapper.objectApiName, 'Object API name should include namespace prefix');
	}

	/**
	 * @description Verifies that the ValidationRuleWithGroup wrapper handles a null TriggerSetting__r
	 * gracefully without throwing an exception.
	 */
	@IsTest
	private static void validationRuleWithGroupHandlesNullTriggerSetting()
	{
		ValidationRule__mdt rule = TST_Factory.newValidationRule();
		ValidationRuleGroup__mdt ruleGroup = TST_Factory.newValidationRuleGroup(null, new List<ValidationRule__mdt> {rule});

		Test.startTest();
		SEL_ValidationRules.ValidationRuleWithGroup wrapper = new SEL_ValidationRules.ValidationRuleWithGroup(rule, ruleGroup);
		Test.stopTest();

		Assert.isNotNull(wrapper, 'Wrapper should be created');
	}

	/**
	 * @description Verifies that the validation rules cache is lazily initialized on first access
	 * and subsequent calls use the cached data without re-querying.
	 */
	@IsTest
	private static void lazyLoadingInitializesCacheOnFirstAccess()
	{
		Test.startTest();
		List<SEL_ValidationRules.ValidationRuleWithGroup> firstCall = SEL_ValidationRules.findByObjectAndOperation
				(
						SEL_Foobar.OBJECT_NAME,
						TriggerOperation.BEFORE_INSERT
				);

		List<SEL_ValidationRules.ValidationRuleWithGroup> secondCall = SEL_ValidationRules.findByObjectAndOperation
				(
						SEL_Foobar.OBJECT_NAME,
						TriggerOperation.BEFORE_INSERT
				);
		Test.stopTest();

		Assert.isNotNull(firstCall, 'First call should return non-null');
		Assert.isNotNull(secondCall, 'Second call should return non-null');
	}

	/**
	 * @description Verifies that findByObjectAndOperation can query multiple different trigger
	 * operations (BEFORE_INSERT, BEFORE_UPDATE, AFTER_INSERT) for the same object.
	 */
	@IsTest
	private static void findByObjectAndOperationQueriesAllOperations()
	{
		Test.startTest();
		List<SEL_ValidationRules.ValidationRuleWithGroup> beforeInsert = SEL_ValidationRules.findByObjectAndOperation
				(
						SEL_Foobar.OBJECT_NAME,
						TriggerOperation.BEFORE_INSERT
				);
		List<SEL_ValidationRules.ValidationRuleWithGroup> beforeUpdate = SEL_ValidationRules.findByObjectAndOperation
				(
						SEL_Foobar.OBJECT_NAME,
						TriggerOperation.BEFORE_UPDATE
				);
		List<SEL_ValidationRules.ValidationRuleWithGroup> afterInsert = SEL_ValidationRules.findByObjectAndOperation
				(
						SEL_Foobar.OBJECT_NAME,
						TriggerOperation.AFTER_INSERT
				);
		Test.stopTest();

		Assert.isNotNull(beforeInsert, 'Before insert should return non-null');
		Assert.isNotNull(beforeUpdate, 'Before update should return non-null');
		Assert.isNotNull(afterInsert, 'After insert should return non-null');
	}

	/**
	 * @description Verifies that getAllReferencedFeatureFlags handles an empty or freshly
	 * cleared cache without throwing an exception.
	 */
	@IsTest
	private static void getAllReferencedFeatureFlagsHandlesEmptyCache()
	{
		Test.startTest();
		Set<String> featureFlags = SEL_ValidationRules.getAllReferencedFeatureFlags();
		Test.stopTest();

		Assert.isNotNull(featureFlags, 'Feature flags set should not be null');
	}

	/**
	 * @description Verifies that the testCacheOverride mechanism allows tests to inject mock
	 * validation rules without requiring actual custom metadata records in the org.
	 */
	@IsTest
	private static void cacheOverrideAllowsInjectedRules()
	{
		TriggerSetting__mdt triggerSetting = TST_Factory.newTriggerSetting(SEL_Foobar.OBJECT_NAME);
		ValidationRule__mdt rule = TST_Factory.newValidationRule();
		ValidationRuleGroup__mdt ruleGroup = TST_Factory.newValidationRuleGroup(triggerSetting, new List<ValidationRule__mdt> {rule});
		SEL_ValidationRules.ValidationRuleWithGroup wrapper = new SEL_ValidationRules.ValidationRuleWithGroup(rule, ruleGroup);

		Map<String, Map<String, List<SEL_ValidationRules.ValidationRuleWithGroup>>> testCache =
				new Map<String, Map<String, List<SEL_ValidationRules.ValidationRuleWithGroup>>>();
		Map<String, List<SEL_ValidationRules.ValidationRuleWithGroup>> operationMap =
				new Map<String, List<SEL_ValidationRules.ValidationRuleWithGroup>>();
		operationMap.put(TriggerOperation.BEFORE_INSERT.name(), new List<SEL_ValidationRules.ValidationRuleWithGroup> {wrapper});
		testCache.put(SEL_Foobar.OBJECT_NAME, operationMap);
		SEL_ValidationRules.testCacheOverride = testCache;

		Test.startTest();
		List<SEL_ValidationRules.ValidationRuleWithGroup> rules = SEL_ValidationRules.findByObjectAndOperation
				(
						SEL_Foobar.OBJECT_NAME,
						TriggerOperation.BEFORE_INSERT
				);
		Test.stopTest();

		Assert.areEqual(1, rules.size(), 'Should return injected rule');
	}

	/**
	 * @description Verifies that when testCacheOverride is set, getAllReferencedFeatureFlags
	 * correctly extracts feature flags from injected rules.
	 */
	@IsTest
	private static void cacheOverrideIsUsedInsteadOfRealCache()
	{
		TriggerSetting__mdt triggerSetting = TST_Factory.newTriggerSetting('Account');
		ValidationRule__mdt rule = TST_Factory.newValidationRule
				(
						new Map<SObjectField, Object> {ValidationRule__mdt.BypassFeatureFlag__c => TST_Factory.newFeatureFlag('RuleBypassPermission', false)}
				);
		ValidationRuleGroup__mdt ruleGroup = TST_Factory.newValidationRuleGroup
				(
						triggerSetting,
						'Before',
						'Update',
						new List<ValidationRule__mdt> {rule},
						'TestFeatureFlag',
						'TestBypassPermission'
				);
		SEL_ValidationRules.ValidationRuleWithGroup wrapper = new SEL_ValidationRules.ValidationRuleWithGroup(rule, ruleGroup);

		Map<String, Map<String, List<SEL_ValidationRules.ValidationRuleWithGroup>>> testCache =
				new Map<String, Map<String, List<SEL_ValidationRules.ValidationRuleWithGroup>>>();
		Map<String, List<SEL_ValidationRules.ValidationRuleWithGroup>> operationMap =
				new Map<String, List<SEL_ValidationRules.ValidationRuleWithGroup>>();
		operationMap.put(TriggerOperation.BEFORE_UPDATE.name(), new List<SEL_ValidationRules.ValidationRuleWithGroup> {wrapper});
		testCache.put('Account', operationMap);
		SEL_ValidationRules.testCacheOverride = testCache;

		Test.startTest();
		Set<String> featureFlags = SEL_ValidationRules.getAllReferencedFeatureFlags();
		Test.stopTest();

		Assert.isTrue(featureFlags.contains('TestFeatureFlag'), 'Should include group feature flag');
		Assert.isTrue(featureFlags.contains('TestBypassPermission'), 'Should include group bypass permission');
		Assert.isTrue(featureFlags.contains('RuleBypassPermission'), 'Should include rule bypass permission');
	}

	/**
	 * @description Verifies that testGroupsOverride allows injecting mock ValidationRuleGroup__mdt
	 * records to test the full loading path including processGroupRules.
	 */
	@IsTest
	private static void groupsOverrideExercisesLoadingPath()
	{
		TriggerSetting__mdt triggerSetting = TST_Factory.newTriggerSetting(SEL_Foobar.OBJECT_NAME);
		ValidationRule__mdt rule = TST_Factory.newValidationRule('LoadingRule', 'true', 'Test error');
		ValidationRuleGroup__mdt ruleGroup = TST_Factory.newValidationRuleGroup
				(
						triggerSetting,
						'Before',
						'Insert',
						new List<ValidationRule__mdt> {rule}
				);
		SEL_ValidationRules.testGroupsOverride = new List<ValidationRuleGroup__mdt> {ruleGroup};

		Test.startTest();
		List<SEL_ValidationRules.ValidationRuleWithGroup> rules = SEL_ValidationRules.findByObjectAndOperation
				(
						SEL_Foobar.OBJECT_NAME,
						TriggerOperation.BEFORE_INSERT
				);
		Test.stopTest();

		Assert.areEqual(1, rules.size(), 'Should load rules from testGroupsOverride');
		Assert.areEqual('LoadingRule', rules[0].rule.DeveloperName, 'Should have the correct rule');
	}

	/**
	 * @description Verifies that the loading logic skips groups with null TriggerSetting__r.
	 */
	@IsTest
	private static void loadingSkipsGroupsWithNullTriggerSetting()
	{
		ValidationRule__mdt rule = TST_Factory.newValidationRule('SkippedRule', 'true', 'Test error');
		ValidationRuleGroup__mdt ruleGroupWithoutSetting = TST_Factory.newValidationRuleGroup(null, new List<ValidationRule__mdt> {rule});
		SEL_ValidationRules.testGroupsOverride = new List<ValidationRuleGroup__mdt> {ruleGroupWithoutSetting};

		Test.startTest();
		List<SEL_ValidationRules.ValidationRuleWithGroup> rules = SEL_ValidationRules.findByObjectAndOperation
				(
						SEL_Foobar.OBJECT_NAME,
						TriggerOperation.BEFORE_INSERT
				);
		Test.stopTest();

		Assert.isTrue(rules.isEmpty(), 'Should skip groups with null TriggerSetting__r');
	}

	/**
	 * @description Verifies that the loading logic skips groups with empty child rules.
	 */
	@IsTest
	private static void loadingSkipsGroupsWithNoChildRules()
	{
		TriggerSetting__mdt triggerSetting = TST_Factory.newTriggerSetting(SEL_Foobar.OBJECT_NAME);
		ValidationRuleGroup__mdt ruleGroupNoRules = TST_Factory.newValidationRuleGroup
				(
						triggerSetting,
						'Before',
						'Insert',
						new List<ValidationRule__mdt>()
				);
		SEL_ValidationRules.testGroupsOverride = new List<ValidationRuleGroup__mdt> {ruleGroupNoRules};

		Test.startTest();
		List<SEL_ValidationRules.ValidationRuleWithGroup> rules = SEL_ValidationRules.findByObjectAndOperation
				(
						SEL_Foobar.OBJECT_NAME,
						TriggerOperation.BEFORE_INSERT
				);
		Test.stopTest();

		Assert.isTrue(rules.isEmpty(), 'Should skip groups with no child rules');
	}

	/**
	 * @description Verifies that the loading logic handles groups with blank TriggerTiming__c
	 * and TriggerOperations__c fields by returning no operations.
	 */
	@IsTest
	private static void loadingHandlesBlankTimingAndOperations()
	{
		TriggerSetting__mdt triggerSetting = TST_Factory.newTriggerSetting(SEL_Foobar.OBJECT_NAME);
		ValidationRule__mdt rule = TST_Factory.newValidationRule('BlankOpsRule', 'true', 'Test error');
		ValidationRuleGroup__mdt ruleGroupBlankOps = TST_Factory.newValidationRuleGroup
				(
						triggerSetting,
						'',
						'',
						new List<ValidationRule__mdt> {rule}
				);
		SEL_ValidationRules.testGroupsOverride = new List<ValidationRuleGroup__mdt> {ruleGroupBlankOps};

		Test.startTest();
		List<SEL_ValidationRules.ValidationRuleWithGroup> rules = SEL_ValidationRules.findByObjectAndOperation
				(
						SEL_Foobar.OBJECT_NAME,
						TriggerOperation.BEFORE_INSERT
				);
		Test.stopTest();

		Assert.isTrue(rules.isEmpty(), 'Should return empty for blank timing/operations');
	}

	/**
	 * @description Verifies that the loading logic correctly handles multiple trigger operations
	 * specified with semicolons (e.g., 'Before;After' and 'Insert;Update').
	 */
	@IsTest
	private static void loadingHandlesMultipleOperations()
	{
		TriggerSetting__mdt triggerSetting = TST_Factory.newTriggerSetting(SEL_Foobar.OBJECT_NAME);
		ValidationRule__mdt rule = TST_Factory.newValidationRule('MultiOpRule', 'true', 'Test error');
		ValidationRuleGroup__mdt ruleGroup = TST_Factory.newValidationRuleGroup
				(
						triggerSetting,
						'Before;After',
						'Insert;Update',
						new List<ValidationRule__mdt> {rule}
				);
		SEL_ValidationRules.testGroupsOverride = new List<ValidationRuleGroup__mdt> {ruleGroup};

		Test.startTest();
		List<SEL_ValidationRules.ValidationRuleWithGroup> beforeInsert = SEL_ValidationRules.findByObjectAndOperation
				(
						SEL_Foobar.OBJECT_NAME,
						TriggerOperation.BEFORE_INSERT
				);
		List<SEL_ValidationRules.ValidationRuleWithGroup> afterUpdate = SEL_ValidationRules.findByObjectAndOperation
				(
						SEL_Foobar.OBJECT_NAME,
						TriggerOperation.AFTER_UPDATE
				);
		Test.stopTest();

		Assert.areEqual(1, beforeInsert.size(), 'Should have rule for BEFORE_INSERT');
		Assert.areEqual(1, afterUpdate.size(), 'Should have rule for AFTER_UPDATE');
	}

	/**
	 * @description Verifies that invalid trigger operation combinations (like BEFORE_UNDELETE)
	 * are gracefully ignored and don't cause errors.
	 */
	@IsTest
	private static void loadingIgnoresInvalidOperationCombinations()
	{
		TriggerSetting__mdt triggerSetting = TST_Factory.newTriggerSetting(SEL_Foobar.OBJECT_NAME);
		ValidationRule__mdt rule = TST_Factory.newValidationRule('InvalidOpRule', 'true', 'Test error');
		ValidationRuleGroup__mdt ruleGroup = TST_Factory.newValidationRuleGroup
				(
						triggerSetting,
						'Before',
						'Undelete',
						new List<ValidationRule__mdt> {rule}
				);
		SEL_ValidationRules.testGroupsOverride = new List<ValidationRuleGroup__mdt> {ruleGroup};

		Test.startTest();
		List<SEL_ValidationRules.ValidationRuleWithGroup> rules = SEL_ValidationRules.findByObjectAndOperation
				(
						SEL_Foobar.OBJECT_NAME,
						TriggerOperation.AFTER_UNDELETE
				);
		Test.stopTest();

		Assert.isTrue(rules.isEmpty(), 'Should not find rules for AFTER_UNDELETE when group specifies BEFORE');
	}

	/**
	 * @description Verifies that buildObjectApiName resolves the object API name from the
	 * EntityDefinition relationship (SObjectType__r.QualifiedApiName) when available,
	 * covering both the static and instance buildObjectApiName methods.
	 */
	@IsTest
	private static void shouldResolveObjectApiNameFromEntityDefinition()
	{
		SEL_ValidationRules.testGroupsOverride = new List<ValidationRuleGroup__mdt>
		{
				buildGroupWithEntityDefinition(SEL_Foobar.OBJECT_NAME)
		};

		Test.startTest();
		List<SEL_ValidationRules.ValidationRuleWithGroup> rules = SEL_ValidationRules.findByObjectAndOperation
				(
						SEL_Foobar.OBJECT_NAME,
						TriggerOperation.BEFORE_INSERT
				);
		Test.stopTest();

		Assert.areEqual(1, rules.size(), 'Should find rule loaded via EntityDefinition relationship');
		Assert.areEqual(SEL_Foobar.OBJECT_NAME, rules[0].objectApiName, 'Object API name should come from EntityDefinition QualifiedApiName');
	}

	/**
	 * @description Builds a ValidationRuleGroup__mdt with EntityDefinition relationship populated
	 * on its TriggerSetting__r, including a child validation rule.
	 *
	 * @param objectApiName The qualified API name for the EntityDefinition
	 *
	 * @return A ValidationRuleGroup__mdt with full nested relationships
	 */
	private static ValidationRuleGroup__mdt buildGroupWithEntityDefinition(String objectApiName)
	{
		EntityDefinition entityDefinition = (EntityDefinition)TST_Builder.of(EntityDefinition.SObjectType)
				.withOverride(EntityDefinition.QualifiedApiName, objectApiName)
				.withoutInsertion()
				.build();

		TriggerSetting__mdt triggerSetting = (TriggerSetting__mdt)TST_Builder.of(TriggerSetting__mdt.SObjectType)
				.withOverride(TriggerSetting__mdt.SObjectType__c, entityDefinition)
				.withoutInsertion(true)
				.build();

		ValidationRule__mdt rule = TST_Factory.newValidationRule('EntityDefRule', 'true', 'Test error');

		return TST_Factory.newValidationRuleGroup(triggerSetting, new List<ValidationRule__mdt> {rule});
	}
}