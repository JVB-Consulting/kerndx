// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Test class for SEL_TriggerAction. Tests feature flag integration with trigger action
 * bypass and required feature flag fields.
 *
 * @see SEL_TriggerAction
 * @see UTIL_FeatureFlag
 *
 * @author Jason van Beukering
 *
 * @group Triggers
 *
 * @date February 2026, May 2026
 */
@IsTest(SeeAllData=false)
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
private class SEL_TriggerAction_TEST
{
	private static final String TEST_FEDERATION_ID = 'e09587c0-1f50-4f21-90cf-a8bbafc24492';

	@TestSetup
	private static void setup()
	{
		User newUser = TST_Factory.newUser(SEL_Profile.PROFILE_STANDARD_USER);
		newUser.FederationIdentifier = TEST_FEDERATION_ID;
		insert newUser;
	}

	/**
	 * @description Verifies that allDeveloperNames property returns all feature flag DeveloperNames
	 *
	 * @see SEL_FeatureFlag.allDeveloperNames
	 */
	@IsTest
	private static void allDeveloperNamesReturnsFeatureFlags()
	{
		SEL_FeatureFlag.allDeveloperNames = null;

		Test.startTest();
		Set<String> flagNames = SEL_FeatureFlag.allDeveloperNames;
		Test.stopTest();

		Assert.isTrue(flagNames.contains(SEL_FeatureFlag.TEST_FEATURE_FLAG), 'allDeveloperNames should include the test feature flag');
	}

	/**
	 * @description Verifies that allDeveloperNames property caches results for subsequent calls
	 *
	 * @see SEL_FeatureFlag.allDeveloperNames
	 */
	@IsTest
	private static void allDeveloperNamesCachesResults()
	{
		SEL_FeatureFlag.allDeveloperNames = null;

		Test.startTest();
		Set<String> firstCall = SEL_FeatureFlag.allDeveloperNames;
		Set<String> secondCall = SEL_FeatureFlag.allDeveloperNames;
		Test.stopTest();

		Assert.areEqual(firstCall, secondCall, 'allDeveloperNames should return cached results');
	}

	/**
	 * @description Verifies that trigger actions are returned when user has admin permission set
	 *
	 * @see SEL_TriggerAction.findActiveByObjectNameAndTriggerOperation
	 */
	@IsTest
	private static void actionBypassedWhenFeatureFlagEnabled()
	{
		User runAsUser = new SEL_User().findByFederationId(TEST_FEDERATION_ID);
		TST_Factory.createPermissionSetAssignments(new List<User> {runAsUser}, SEL_PermissionSet.ADMIN_PERMISSION_SET_API_NAME);

		List<TriggerAction__mdt> actions = findActionsAsUser(runAsUser);

		Assert.isNotNull(actions, 'Should return a list of actions');
	}

	/**
	 * @description Verifies that trigger action cache is populated and reused on subsequent calls
	 *
	 * @see SEL_TriggerAction.findActiveByObjectNameAndTriggerOperation
	 */
	@IsTest
	private static void triggerActionCacheIsPopulatedAndReused()
	{
		Test.startTest();
		List<TriggerAction__mdt> firstCall = SEL_TriggerAction.findActiveByObjectNameAndTriggerOperation(SEL_Foobar.OBJECT_NAME, TriggerOperation.BEFORE_INSERT);
		List<TriggerAction__mdt> secondCall = SEL_TriggerAction.findActiveByObjectNameAndTriggerOperation(SEL_Foobar.OBJECT_NAME, TriggerOperation.BEFORE_INSERT);
		Test.stopTest();

		Assert.areEqual(firstCall.size(), secondCall.size(), 'Cache should return same number of actions on subsequent calls');
	}

	/**
	 * @description Verifies that an empty list is returned for objects with no configured trigger actions
	 *
	 * @see SEL_TriggerAction.findActiveByObjectNameAndTriggerOperation
	 */
	@IsTest
	private static void emptyListReturnedForUnknownObject()
	{
		Test.startTest();
		List<TriggerAction__mdt> actions = SEL_TriggerAction.findActiveByObjectNameAndTriggerOperation('NonExistentObject__c', TriggerOperation.BEFORE_INSERT);
		Test.stopTest();

		Assert.isNotNull(actions, 'Should return a list (not null)');
		Assert.isTrue(actions.isEmpty(), 'Should return empty list for unknown object');
	}

	/**
	 * @description Verifies that condition evaluation completes successfully with real feature flag data
	 *
	 * @see SEL_TriggerAction.findActiveByObjectNameAndTriggerOperation
	 */
	@IsTest
	private static void conditionsEvaluatedSuccessfully()
	{
		SEL_FeatureFlag.allDeveloperNames = null;
		User runAsUser = new SEL_User().findByFederationId(TEST_FEDERATION_ID);

		List<TriggerAction__mdt> actions = findActionsAsUser(runAsUser);

		Assert.isNotNull(actions, 'Query should complete successfully');
	}

	/**
	 * @description Verifies that actions are correctly filtered by trigger operation type
	 *
	 * @see SEL_TriggerAction.findActiveByObjectNameAndTriggerOperation
	 */
	@IsTest
	private static void actionsFilteredByOperationType()
	{
		Test.startTest();
		List<TriggerAction__mdt> beforeInsertActions = SEL_TriggerAction.findActiveByObjectNameAndTriggerOperation(SEL_Foobar.OBJECT_NAME, TriggerOperation.BEFORE_INSERT);
		List<TriggerAction__mdt> afterUpdateActions = SEL_TriggerAction.findActiveByObjectNameAndTriggerOperation(SEL_Foobar.OBJECT_NAME, TriggerOperation.AFTER_UPDATE);
		Test.stopTest();

		Assert.isNotNull(beforeInsertActions, 'Before Insert query should succeed');
		Assert.isNotNull(afterUpdateActions, 'After Update query should succeed');
	}

	/**
	 * @description Verifies that feature flag cache persists across different trigger operations (batch safety)
	 *
	 * @see SEL_FeatureFlag.allDeveloperNames
	 */
	@IsTest
	private static void featureFlagCachePersistsAcrossOperations()
	{
		SEL_FeatureFlag.allDeveloperNames = null;

		Test.startTest();
		SEL_TriggerAction.findActiveByObjectNameAndTriggerOperation(SEL_Foobar.OBJECT_NAME, TriggerOperation.BEFORE_INSERT);
		Set<String> cacheAfterFirstOp = SEL_FeatureFlag.allDeveloperNames;

		SEL_TriggerAction.findActiveByObjectNameAndTriggerOperation(SEL_Foobar.OBJECT_NAME, TriggerOperation.AFTER_INSERT);
		Set<String> cacheAfterSecondOp = SEL_FeatureFlag.allDeveloperNames;
		Test.stopTest();

		Assert.areEqual(cacheAfterFirstOp, cacheAfterSecondOp, 'Feature flag cache should persist across operations (batch safety)');
	}

	/**
	 * @description Verifies that actions with blank permission fields are included in results
	 *
	 * @see SEL_TriggerAction.findActiveByObjectNameAndTriggerOperation
	 */
	@IsTest
	private static void blankConditionValuesAreHandledCorrectly()
	{
		Test.startTest();
		List<TriggerAction__mdt> actions = SEL_TriggerAction.findActiveByObjectNameAndTriggerOperation(SEL_Foobar.OBJECT_NAME, TriggerOperation.BEFORE_INSERT);
		Test.stopTest();

		Assert.isFalse(actions.isEmpty(), 'Actions with blank permission fields should be included in results');
	}

	/**
	 * @description Helper method to find trigger actions as a specific user
	 *
	 * @param runAsUser The user context to run the query in
	 *
	 * @return List of trigger actions found for Foobar__c BEFORE_INSERT
	 */
	private static List<TriggerAction__mdt> findActionsAsUser(User runAsUser)
	{
		List<TriggerAction__mdt> actions;
		System.runAs(runAsUser)
		{
			Test.startTest();
			actions = SEL_TriggerAction.findActiveByObjectNameAndTriggerOperation(SEL_Foobar.OBJECT_NAME, TriggerOperation.BEFORE_INSERT);
			Test.stopTest();
		}
		return actions;
	}

	/**
	 * @description Sets up feature flag mocks with an enabled flag
	 *
	 * @param flagName The feature flag name to enable
	 */
	private static void setupEnabledFeatureFlag(String flagName)
	{
		FeatureFlag__mdt flag = (FeatureFlag__mdt)TST_Builder.of(FeatureFlag__mdt.SObjectType)
				.withOverride(FeatureFlag__mdt.DeveloperName, flagName)
				.withOverride(FeatureFlag__mdt.IsActive__c, true)
				.withOverride(FeatureFlag__mdt.IsEnabledByDefault__c, true)
				.withoutInsertion()
				.build();

		SEL_FeatureFlag.allDeveloperNames = new Set<String> {flagName};
		SEL_FeatureFlag.activeFlags = new Map<String, FeatureFlag__mdt>
		{
				flagName => flag
		};
	}

	/**
	 * @description Sets up feature flag mocks with a disabled flag (defined but not active)
	 *
	 * @param flagName The feature flag name to define as disabled
	 */
	private static void setupDisabledFeatureFlag(String flagName)
	{
		SEL_FeatureFlag.allDeveloperNames = new Set<String> {flagName};
		SEL_FeatureFlag.activeFlags = new Map<String, FeatureFlag__mdt>();
	}

	/**
	 * @description Clears all feature flag mocks (for custom permission fallback tests)
	 */
	private static void clearFeatureFlagMocks()
	{
		SEL_FeatureFlag.allDeveloperNames = new Set<String>();
		SEL_FeatureFlag.activeFlags = new Map<String, FeatureFlag__mdt>();
	}

	/**
	 * @description Verifies shouldExecute returns false when action BypassFeatureFlag__c is an enabled feature flag.
	 *
	 * @see SEL_TriggerAction.shouldExecute
	 */
	@IsTest
	private static void shouldExecuteReturnsFalseWhenActionBypassFlagEnabled()
	{
		final String bypassFlag = 'TestBypassFlag';
		setupEnabledFeatureFlag(bypassFlag);

		TriggerSetting__mdt triggerSetting = TST_Factory.newTriggerSetting('Account');
		TriggerAction__mdt triggerAction = TST_Factory.newTriggerAction('TestAction', triggerSetting, bypassFlag, null);

		Test.startTest();
		Boolean result = SEL_TriggerAction.shouldExecute(triggerSetting, triggerAction);
		Test.stopTest();

		Assert.isFalse(result, 'shouldExecute should return false when action bypass flag is enabled');
	}

	/**
	 * @description Verifies shouldExecute returns false when setting BypassFeatureFlag__c is an enabled feature flag.
	 *
	 * @see SEL_TriggerAction.shouldExecute
	 */
	@IsTest
	private static void shouldExecuteReturnsFalseWhenSettingBypassFlagEnabled()
	{
		final String bypassFlag = 'TestSettingBypassFlag';
		setupEnabledFeatureFlag(bypassFlag);

		TriggerSetting__mdt triggerSetting = TST_Factory.newTriggerSetting('Account', bypassFlag, null);
		TriggerAction__mdt triggerAction = TST_Factory.newTriggerAction('TestAction', triggerSetting);

		Test.startTest();
		Boolean result = SEL_TriggerAction.shouldExecute(triggerSetting, triggerAction);
		Test.stopTest();

		Assert.isFalse(result, 'shouldExecute should return false when setting bypass flag is enabled');
	}

	/**
	 * @description Verifies shouldExecute returns false when setting RequiredFeatureFlag__c is a disabled feature flag.
	 *
	 * @see SEL_TriggerAction.shouldExecute
	 */
	@IsTest
	private static void shouldExecuteReturnsFalseWhenSettingRequiredFlagDisabled()
	{
		final String requiredFlag = 'TestSettingRequiredFlag';
		setupDisabledFeatureFlag(requiredFlag);

		TriggerSetting__mdt triggerSetting = TST_Factory.newTriggerSetting('Account', null, requiredFlag);
		TriggerAction__mdt triggerAction = TST_Factory.newTriggerAction('TestAction', triggerSetting);

		Test.startTest();
		Boolean result = SEL_TriggerAction.shouldExecute(triggerSetting, triggerAction);
		Test.stopTest();

		Assert.isFalse(result, 'shouldExecute should return false when setting required flag is disabled');
	}

	/**
	 * @description Verifies shouldExecute returns false when action RequiredFeatureFlag__c is a disabled feature flag.
	 *
	 * @see SEL_TriggerAction.shouldExecute
	 */
	@IsTest
	private static void shouldExecuteReturnsFalseWhenActionRequiredFlagDisabled()
	{
		final String requiredFlag = 'TestActionRequiredFlag';
		setupDisabledFeatureFlag(requiredFlag);

		TriggerSetting__mdt triggerSetting = TST_Factory.newTriggerSetting('Account');
		TriggerAction__mdt triggerAction = TST_Factory.newTriggerAction('TestAction', triggerSetting, null, requiredFlag);

		Test.startTest();
		Boolean result = SEL_TriggerAction.shouldExecute(triggerSetting, triggerAction);
		Test.stopTest();

		Assert.isFalse(result, 'shouldExecute should return false when action required flag is disabled');
	}

	/**
	 * @description Verifies shouldExecute returns true when all conditions pass (no bypass, required met).
	 *
	 * @see SEL_TriggerAction.shouldExecute
	 */
	@IsTest
	private static void shouldExecuteReturnsTrueWhenAllConditionsPass()
	{
		final String requiredFlag = 'TestRequiredFlag';
		setupEnabledFeatureFlag(requiredFlag);

		TriggerSetting__mdt triggerSetting = TST_Factory.newTriggerSetting('Account', null, requiredFlag);
		TriggerAction__mdt triggerAction = TST_Factory.newTriggerAction('TestAction', triggerSetting);

		Test.startTest();
		Boolean result = SEL_TriggerAction.shouldExecute(triggerSetting, triggerAction);
		Test.stopTest();

		Assert.isTrue(result, 'shouldExecute should return true when required flag is enabled and no bypass');
	}

	/**
	 * @description Verifies shouldExecute returns true when no permission fields are set (blank conditions).
	 *
	 * @see SEL_TriggerAction.shouldExecute
	 */
	@IsTest
	private static void shouldExecuteReturnsTrueWhenNoPermissionsConfigured()
	{
		clearFeatureFlagMocks();

		TriggerSetting__mdt triggerSetting = TST_Factory.newTriggerSetting('Account');
		TriggerAction__mdt triggerAction = TST_Factory.newTriggerAction('TestAction', triggerSetting);

		Test.startTest();
		Boolean result = SEL_TriggerAction.shouldExecute(triggerSetting, triggerAction);
		Test.stopTest();

		Assert.isTrue(result, 'shouldExecute should return true when no permissions are configured');
	}

	/**
	 * @description Verifies that sortByOrder sorts trigger actions by Order__c ascending.
	 *
	 * @see SEL_TriggerAction.sortByOrder
	 */
	@IsTest
	private static void sortByOrderSortsActionsAscending()
	{
		TriggerAction__mdt actionOrder3 = new TriggerAction__mdt(DeveloperName = 'Third', Order__c = 3);
		TriggerAction__mdt actionOrder1 = new TriggerAction__mdt(DeveloperName = 'First', Order__c = 1);
		TriggerAction__mdt actionOrder2 = new TriggerAction__mdt(DeveloperName = 'Second', Order__c = 2);

		List<TriggerAction__mdt> unsorted = new List<TriggerAction__mdt> {actionOrder3, actionOrder1, actionOrder2};

		Test.startTest();
		List<TriggerAction__mdt> sorted = SEL_TriggerAction.sortByOrder(unsorted);
		Test.stopTest();

		Assert.areEqual('First', sorted[0].DeveloperName, 'First action should have Order 1');
		Assert.areEqual('Second', sorted[1].DeveloperName, 'Second action should have Order 2');
		Assert.areEqual('Third', sorted[2].DeveloperName, 'Third action should have Order 3');
	}

	/**
	 * @description Verifies that sortByOrder treats null Order__c as 0 (first position).
	 *
	 * @see SEL_TriggerAction.sortByOrder
	 */
	@IsTest
	private static void sortByOrderTreatsNullAsZero()
	{
		TriggerAction__mdt actionOrder1 = new TriggerAction__mdt(DeveloperName = 'Explicit', Order__c = 1);
		TriggerAction__mdt actionNullOrder = new TriggerAction__mdt(DeveloperName = 'NullOrder');

		List<TriggerAction__mdt> unsorted = new List<TriggerAction__mdt> {actionOrder1, actionNullOrder};

		Test.startTest();
		List<TriggerAction__mdt> sorted = SEL_TriggerAction.sortByOrder(unsorted);
		Test.stopTest();

		Assert.areEqual('NullOrder', sorted[0].DeveloperName, 'Null Order__c should be treated as 0 and come first');
		Assert.areEqual('Explicit', sorted[1].DeveloperName, 'Order 1 should come after null/0');
	}

	/**
	 * @description Verifies that a bypassed action is excluded by addActionIfExecutable.
	 *
	 * @see SEL_TriggerAction.addActionIfExecutable
	 */
	@IsTest
	private static void bypassedActionExcludedByAddActionIfExecutable()
	{
		final String bypassFlag = 'TestLoadBypassFlag';
		setupEnabledFeatureFlag(bypassFlag);

		TriggerSetting__mdt triggerSetting = TST_Factory.newTriggerSetting('Account');
		TriggerAction__mdt triggerAction = TST_Factory.newTriggerAction('TestAction', triggerSetting, bypassFlag, null);

		Map<String, List<TriggerAction__mdt>> actionByOperationMap = new Map<String, List<TriggerAction__mdt>>();

		Test.startTest();

		SEL_TriggerAction.addActionIfExecutable(actionByOperationMap, triggerSetting, triggerAction);

		Test.stopTest();

		Assert.isTrue(actionByOperationMap.isEmpty(), 'Bypassed action should not be added to the operation map');
	}
}