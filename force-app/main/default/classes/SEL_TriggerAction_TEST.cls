// SPDX-License-Identifier: Apache-2.0
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
 * @date February 2026, October 2026
 */
@IsTest(seeAllData=false)
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
private class SEL_TriggerAction_TEST
{
	/**
	 * @description A fixed federation identifier stamped on the user created in the test setup. The tests use it to
	 * find that one user again, because no other user in the org carries this value.
	 */
	private static final String TEST_FEDERATION_ID = 'e09587c0-1f50-4f21-90cf-a8bbafc24492';

	/**
	 * @description Developer name of the one trigger action the package registers for Foobar__c. It runs before insert,
	 * and the selection tests check that the selector returns it with every field it selects.
	 */
	private static final String SET_FOOBAR_DEFAULTS_ACTION = 'SetFoobarDefaults_BeforeInsert';

	/**
	 * @description The Order__c value the package gives the Foobar__c before insert action.
	 */
	private static final Decimal SET_FOOBAR_DEFAULTS_ORDER = 1000;

	/**
	 * @description The Description__c value the package gives the Foobar__c before insert action.
	 */
	private static final String SET_FOOBAR_DEFAULTS_DESCRIPTION = 'Sample Trigger Action for Test class and coverage';

	/**
	 * @description Creates one standard user marked with TEST_FEDERATION_ID. The tests that check which trigger
	 * actions a user gets run as this user, so the result does not depend on the permissions of whoever runs the
	 * test.
	 */
	@TestSetup
	private static void setup()
	{
		User newUser = TST_Factory.newUser(SEL_Profile.PROFILE_STANDARD_USER);
		newUser.FederationIdentifier = TEST_FEDERATION_ID;
		TST_Factory.insertUsers(new List<User> {newUser});
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
	 * @description A standard user with no permission set gets the Foobar__c before insert action the package registers,
	 * with every field the selector selects. The result does not depend on the permissions of the user who asks.
	 *
	 * @see SEL_TriggerAction.findActiveByObjectNameAndTriggerOperation
	 */
	@IsTest
	private static void shouldGiveAStandardUserTheConfiguredActionWithSelectedFields()
	{
		SEL_FeatureFlag.allDeveloperNames = null;
		User runAsUser = new SEL_User().findByFederationId(TEST_FEDERATION_ID);

		List<TriggerAction__mdt> actions = findActionsAsUser(runAsUser);

		assertSetFoobarDefaultsSelected(actions);
	}

	/**
	 * @description Before insert returns the Foobar__c action registered for that event, and after update, for which
	 * Foobar__c registers no action, returns an empty list.
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

		Assert.areEqual(1, beforeInsertActions.size(), 'Expected one before insert action for Foobar__c, got ' + beforeInsertActions.size());
		Assert.areEqual(SET_FOOBAR_DEFAULTS_ACTION, beforeInsertActions[0].DeveloperName, 'Expected the before insert action, got ' + beforeInsertActions[0].DeveloperName);
		Assert.areEqual(0, afterUpdateActions.size(), 'Expected no after update action for Foobar__c, got ' + afterUpdateActions.size());
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
	 * @description A user given the Kern administrator permission set gets the same Foobar__c before insert action, with
	 * every field the selector selects, as a standard user does: holding the permission set neither adds nor removes an
	 * action.
	 *
	 * @see SEL_TriggerAction.findActiveByObjectNameAndTriggerOperation
	 */
	@IsTest
	private static void shouldGiveAUserWithTheAdministratorPermissionSetTheConfiguredActionWithSelectedFields()
	{
		User runAsUser = new SEL_User().findByFederationId(TEST_FEDERATION_ID);
		TST_Factory.createPermissionSetAssignments(new List<User> {runAsUser}, SEL_PermissionSet.ADMIN_PERMISSION_SET_API_NAME);

		List<TriggerAction__mdt> actions = findActionsAsUser(runAsUser);

		assertSetFoobarDefaultsSelected(actions);
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
	 * @description Checks that the selector returned exactly the Foobar__c before insert action the package registers,
	 * and reads every custom field the selector selects for it, comparing each with the value the package ships. A custom
	 * field the selector stops selecting fails here, because reading a field a query did not select throws. The class name
	 * is compared with the package namespace taken off both sides: a package build writes the name on the record with the
	 * namespace in front, an unmanaged deployment leaves it bare, and either spelling names the same class. The two
	 * feature flag names are read through lookups that are empty on this record, and NamespacePrefix is not read, so
	 * this check does not prove that dropping one of those from the selection fails.
	 *
	 * @param actions The trigger actions the selector returned for Foobar__c before insert.
	 */
	private static void assertSetFoobarDefaultsSelected(List<TriggerAction__mdt> actions)
	{
		Assert.areEqual(1, actions.size(), 'Expected exactly one Foobar__c before insert action, got ' + actions.size());
		TriggerAction__mdt action = actions[0];

		Assert.areEqual(SET_FOOBAR_DEFAULTS_ACTION, action.DeveloperName, 'Expected the Foobar__c before insert action, got ' + action.DeveloperName);
		String namespacePrefix = UTIL_System.getManagedPackageNamespacePrefix(UTIL_String.DOT);
		String expectedClassName = TRG_SetFoobarDefaults.class.getName().removeStart(namespacePrefix);
		String actualClassName = action.ApexClassName__c?.removeStart(namespacePrefix);
		Assert.areEqual(expectedClassName, actualClassName, 'Expected the action class ' + expectedClassName + ', got ' + action.ApexClassName__c);
		Assert.areEqual(SEL_TriggerAction.EVENT_BEFORE_INSERT, action.Event__c, 'Expected the before insert event, got ' + action.Event__c);
		Assert.areEqual(SET_FOOBAR_DEFAULTS_ORDER, action.Order__c, 'Expected order ' + SET_FOOBAR_DEFAULTS_ORDER + ', got ' + action.Order__c);
		Assert.isFalse(action.BypassExecution__c, 'Expected the action not to be switched off');
		Assert.isTrue(action.AllowNonSelfInitiated__c, 'Expected the action to allow records it did not start from');
		Assert.isFalse(action.AllowRecursion__c, 'Expected the action not to allow recursion');
		Assert.isFalse(action.ForcePerformanceLogging__c, 'Expected performance logging not to be forced');
		Assert.isFalse(action.SuppressPerformanceLogging__c, 'Expected performance logging not to be suppressed');
		Assert.areEqual(SET_FOOBAR_DEFAULTS_DESCRIPTION, action.Description__c, 'Expected the shipped action description, got ' + action.Description__c);
		Assert.isNull(action.BypassFeatureFlag__c, 'Expected no bypass feature flag, got ' + action.BypassFeatureFlag__c);
		Assert.isNull(action.BypassFeatureFlag__r?.DeveloperName, 'Expected no bypass feature flag name');
		Assert.isNull(action.RequiredFeatureFlag__c, 'Expected no required feature flag, got ' + action.RequiredFeatureFlag__c);
		Assert.isNull(action.RequiredFeatureFlag__r?.DeveloperName, 'Expected no required feature flag name');
		Assert.isNull(action.EntryCriteriaContextClassName__c, 'Expected no entry criteria context class, got ' + action.EntryCriteriaContextClassName__c);
		Assert.isNull(action.EntryCriteriaFormula__c, 'Expected no entry criteria formula, got ' + action.EntryCriteriaFormula__c);
		Assert.isNull(action.FailureAction__c, 'Expected no failure action, got ' + action.FailureAction__c);
		Assert.isNull(action.FlowName__c, 'Expected no flow name, got ' + action.FlowName__c);
		Assert.isNull(action.PerformanceThresholdMs__c, 'Expected no performance threshold, got ' + action.PerformanceThresholdMs__c);
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
	 * @description A feature flag that turns an action off is the subscriber's own setting, and the flag record
	 * already shows it. So the framework skips the action and writes no log entry about it. The test turns one
	 * action off with an enabled bypass flag and another with a disabled required flag, checks both are skipped,
	 * and checks that no log entry was saved.
	 *
	 * @see SEL_TriggerAction.shouldExecute
	 */
	@IsTest
	private static void shouldSkipAnActionTurnedOffByAFlagWithoutLogging()
	{
		LOG_Builder.ignoreTestMode = true;
		TST_Factory.setupLoggerForTest();

		final String bypassFlag = 'TestBypassFlag';
		final String requiredFlag = 'TestActionRequiredFlag';
		setupEnabledFeatureFlag(bypassFlag);
		SEL_FeatureFlag.allDeveloperNames.add(requiredFlag);

		TriggerSetting__mdt triggerSetting = TST_Factory.newTriggerSetting('Account');
		TriggerAction__mdt bypassedAction = TST_Factory.newTriggerAction('BypassedAction', triggerSetting, bypassFlag, null);
		TriggerAction__mdt requiredFlagAction = TST_Factory.newTriggerAction('RequiredFlagAction', triggerSetting, null, requiredFlag);

		Test.startTest();
		Boolean bypassedResult = SEL_TriggerAction.shouldExecute(triggerSetting, bypassedAction);
		Boolean requiredFlagResult = SEL_TriggerAction.shouldExecute(triggerSetting, requiredFlagAction);
		Test.stopTest();

		Assert.isFalse(bypassedResult, 'Expected the action with an enabled bypass flag to be skipped');
		Assert.isFalse(requiredFlagResult, 'Expected the action whose required flag is off to be skipped');
		Assert.isTrue(new SEL_LogEntry().getAll().isEmpty(), 'Expected no log entry, because skipping an action turned off by a flag is silent');
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
	 * @description Verifies that sortByOrder orders rows by Order__c ascending and breaks an Order__c
	 * tie by DeveloperName ascending in a single pass. Rows are supplied out of order, including a pair
	 * sharing an Order__c value in reverse DeveloperName order, so the result proves both the primary
	 * Order__c key and the DeveloperName tiebreak are applied through the reusable UTIL_Comparators
	 * sort chain.
	 *
	 * @see SEL_TriggerAction.sortByOrder
	 */
	@IsTest
	private static void sortByOrderSortsByOrderThenDeveloperNameAscending()
	{
		TriggerAction__mdt order2Zeta = new TriggerAction__mdt(DeveloperName = 'Zeta', Order__c = 2);
		TriggerAction__mdt order1Solo = new TriggerAction__mdt(DeveloperName = 'Solo', Order__c = 1);
		TriggerAction__mdt order2Alpha = new TriggerAction__mdt(DeveloperName = 'Alpha', Order__c = 2);

		List<TriggerAction__mdt> unsorted = new List<TriggerAction__mdt> {order2Zeta, order1Solo, order2Alpha};

		Test.startTest();
		List<TriggerAction__mdt> sorted = SEL_TriggerAction.sortByOrder(unsorted);
		Test.stopTest();

		Assert.areEqual('Solo', sorted[0].DeveloperName, 'Order__c 1 must sort ahead of Order__c 2');
		Assert.areEqual('Alpha', sorted[1].DeveloperName, 'A tied Order__c 2 must break ascending by DeveloperName (Alpha before Zeta)');
		Assert.areEqual('Zeta', sorted[2].DeveloperName, 'A tied Order__c 2 must break ascending by DeveloperName (Zeta after Alpha)');
	}

	/**
	 * @description Verifies that a null Order__c sorts ahead of any numbered action, guarding the
	 * sortByOrder contract that an unset order is treated as the lowest. Exercises the null path
	 * through the reusable UTIL_Comparators sort chain at the selector level.
	 *
	 * @see SEL_TriggerAction.sortByOrder
	 */
	@IsTest
	private static void sortByOrderPlacesNullOrderFirst()
	{
		TriggerAction__mdt nullOrder = new TriggerAction__mdt(DeveloperName = 'NullOrder');
		TriggerAction__mdt order1 = new TriggerAction__mdt(DeveloperName = 'Explicit', Order__c = 1);

		List<TriggerAction__mdt> unsorted = new List<TriggerAction__mdt> {order1, nullOrder};

		Test.startTest();
		List<TriggerAction__mdt> sorted = SEL_TriggerAction.sortByOrder(unsorted);
		Test.stopTest();

		Assert.areEqual('NullOrder', sorted[0].DeveloperName, 'A null Order__c must sort ahead of a numbered action');
		Assert.areEqual('Explicit', sorted[1].DeveloperName, 'A numbered action must sort after a null Order__c');
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

	/**
	 * @description Verifies that resolveObjectName returns ObjectApiNameOverride__c when populated,
	 * taking precedence over the SObjectType__c relationship resolution. This is the CDC registration
	 * path: the relationship cannot reference Change Event entities, so a CDC TriggerSetting populates
	 * the override with the Change Event API name (e.g. AccountChangeEvent). Standard-object values
	 * (Account / AccountChangeEvent) are used so the assertions are namespace-immune when the test
	 * ships with the managed package and runs in a subscriber org.
	 *
	 * @see SEL_TriggerAction.resolveObjectName
	 */
	@IsTest
	private static void resolveObjectNameReturnsOverrideWhenPopulated()
	{
		TriggerSetting__mdt setting = (TriggerSetting__mdt)TST_Builder.of(TriggerSetting__mdt.SObjectType)
				.withOverride(TriggerSetting__mdt.SObjectType__c, 'Account')
				.withOverride(TriggerSetting__mdt.ObjectApiNameOverride__c, 'AccountChangeEvent')
				.withoutInsertion()
				.build();

		Test.startTest();
		String resolved = SEL_TriggerAction.resolveObjectName(setting);
		Test.stopTest();

		Assert.areEqual('AccountChangeEvent', resolved,
				'ObjectApiNameOverride__c should take precedence over SObjectType__c');
	}

	/**
	 * @description Verifies that resolveObjectName falls back to SObjectType__c when the override
	 * field is blank. This preserves the existing behavior for standard objects, custom objects, and
	 * platform events (which the relationship already supports). Uses Account (a standard object)
	 * so the assertion is namespace-immune.
	 *
	 * @see SEL_TriggerAction.resolveObjectName
	 */
	@IsTest
	private static void resolveObjectNameFallsBackToSObjectTypeWhenOverrideBlank()
	{
		TriggerSetting__mdt setting = (TriggerSetting__mdt)TST_Builder.of(TriggerSetting__mdt.SObjectType)
				.withOverride(TriggerSetting__mdt.SObjectType__c, 'Account')
				.withoutInsertion()
				.build();

		Test.startTest();
		String resolved = SEL_TriggerAction.resolveObjectName(setting);
		Test.stopTest();

		Assert.areEqual('Account', resolved,
				'When override is blank, resolveObjectName should fall back to SObjectType__c');
	}

	/**
	 * @description Verifies that resolveObjectName returns null when both the override and
	 * SObjectType__c are blank. Upstream callers silently skip null-keyed rows (lookup miss),
	 * matching the existing degenerate-config behavior.
	 *
	 * @see SEL_TriggerAction.resolveObjectName
	 */
	@IsTest
	private static void resolveObjectNameReturnsNullWhenBothBlank()
	{
		TriggerSetting__mdt setting = (TriggerSetting__mdt)TST_Builder.of(TriggerSetting__mdt.SObjectType)
				.withoutInsertion()
				.build();

		Test.startTest();
		String resolved = SEL_TriggerAction.resolveObjectName(setting);
		Test.stopTest();

		Assert.isNull(resolved, 'When neither override nor SObjectType__c is populated, resolveObjectName returns null');
	}

	/**
	 * @description Verifies that a populated ObjectApiNameOverride__c is normalised to the
	 * platform-canonical API-name casing so the registered map key matches the dispatch-time
	 * lookup key (which is always canonical), and that an override the running context cannot
	 * describe is returned unchanged rather than dropped. Uses a standard object
	 * ('account' → 'Account') so the assertion is namespace-immune and always describable.
	 *
	 * @see SEL_TriggerAction.resolveObjectName
	 */
	@IsTest
	private static void resolveObjectNameCanonicalizesDescribableOverrideAndPreservesUnresolvable()
	{
		TriggerSetting__mdt describable = (TriggerSetting__mdt)TST_Builder.of(TriggerSetting__mdt.SObjectType)
				.withOverride(TriggerSetting__mdt.ObjectApiNameOverride__c, 'account')
				.withoutInsertion()
				.build();
		TriggerSetting__mdt unresolvable = (TriggerSetting__mdt)TST_Builder.of(TriggerSetting__mdt.SObjectType)
				.withOverride(TriggerSetting__mdt.ObjectApiNameOverride__c, 'NoSuchEntity__c')
				.withoutInsertion()
				.build();

		Test.startTest();
		String canonical = SEL_TriggerAction.resolveObjectName(describable);
		String preserved = SEL_TriggerAction.resolveObjectName(unresolvable);
		Test.stopTest();

		Assert.areEqual('Account', canonical,
				'A mis-cased describable override should normalise to the platform-canonical API name');
		Assert.areEqual('NoSuchEntity__c', preserved,
				'An override that does not resolve via describe should be returned unchanged');
	}

	/**
	 * @description Tests that a class name matching a registered row's `ApexClassName__c` counts
	 * as registered regardless of casing, mirroring Apex class-name semantics.
	 *
	 * @see SEL_TriggerAction.isRegisteredActionClassName
	 */
	@IsTest
	private static void isRegisteredActionClassNameMatchesApexClassNameCaseInsensitively()
	{
		TriggerAction__mdt registered = (TriggerAction__mdt)TST_Builder.of(TriggerAction__mdt.SObjectType)
				.withOverride(TriggerAction__mdt.ApexClassName__c, 'TRG_RegisteredAction')
				.withoutInsertion()
				.build();
		QRY_Builder.setMock(TriggerAction__mdt.SObjectType, new List<TriggerAction__mdt> {registered});

		Test.startTest();
		Boolean isRegistered = SEL_TriggerAction.isRegisteredActionClassName('trg_registeredaction');
		Test.stopTest();

		Assert.isTrue(isRegistered, 'A class name matching a registered row (any casing) should count as registered');
	}

	/**
	 * @description Tests that the flow-runner class name counts as registered when any flow-action
	 * row exists: every flow row dispatches through the one runner class, so its name is the
	 * action-level bypass key for all flow actions.
	 *
	 * @see SEL_TriggerAction.isRegisteredActionClassName
	 */
	@IsTest
	private static void isRegisteredActionClassNameMatchesFlowRunnerWhenFlowRowsExist()
	{
		TriggerAction__mdt flowRow = (TriggerAction__mdt)TST_Builder.of(TriggerAction__mdt.SObjectType)
				.withOverride(TriggerAction__mdt.FlowName__c, 'Account_SetDefaults')
				.withoutInsertion()
				.build();
		QRY_Builder.setMock(TriggerAction__mdt.SObjectType, new List<TriggerAction__mdt> {flowRow});

		Test.startTest();
		Boolean isRegistered = SEL_TriggerAction.isRegisteredActionClassName(TRG_InvokeFlow.class.getName());
		Test.stopTest();

		Assert.isTrue(isRegistered, 'The flow-runner class name should count as registered when any flow-action row exists');
	}

	/**
	 * @description Tests that unknown and blank class names do not count as registered.
	 *
	 * @see SEL_TriggerAction.isRegisteredActionClassName
	 */
	@IsTest
	private static void isRegisteredActionClassNameReturnsFalseForUnknownOrBlankNames()
	{
		TriggerAction__mdt registered = (TriggerAction__mdt)TST_Builder.of(TriggerAction__mdt.SObjectType)
				.withOverride(TriggerAction__mdt.ApexClassName__c, 'TRG_RegisteredAction')
				.withoutInsertion()
				.build();
		QRY_Builder.setMock(TriggerAction__mdt.SObjectType, new List<TriggerAction__mdt> {registered});

		Test.startTest();
		Boolean unknownRegistered = SEL_TriggerAction.isRegisteredActionClassName('TRG_UnknownAction');
		Boolean blankRegistered = SEL_TriggerAction.isRegisteredActionClassName('');
		Test.stopTest();

		Assert.isFalse(unknownRegistered, 'An unregistered class name should not count as registered');
		Assert.isFalse(blankRegistered, 'A blank class name should not count as registered');
	}
}