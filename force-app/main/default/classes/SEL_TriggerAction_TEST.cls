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
 * @date February 2026, June 2026
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
	 * @description Confirms the trigger-action skip log is flood-controlled. Two identical
	 * feature-flag-gated skips collapse to ONE detail row carrying a stable
	 * `trigger-action-skip:<object>:<action>` fingerprint plus a rollup counting both, and the entry
	 * persists at DEBUG (a routine skip is not INFO-worthy). Regression guard for the skip-log flood
	 * that defeated flood control on the high-frequency trigger-dispatch path: before this guard each
	 * skip persisted a separate un-fingerprinted INFO row, so change-event redelivery turned a handful
	 * of inserts into thousands of persisted rows.
	 *
	 * @see SEL_TriggerAction.logSkipped
	 */
	@IsTest
	private static void skipLoggingCollapsesToFloodControlledDebugEntry()
	{
		LOG_Builder.ignoreTestMode = true;
		TST_Factory.setupLoggerForTest();

		final String requiredFlag = 'TestActionRequiredFlag';
		setupDisabledFeatureFlag(requiredFlag);

		TriggerSetting__mdt triggerSetting = TST_Factory.newTriggerSetting('Account');
		TriggerAction__mdt triggerAction = TST_Factory.newTriggerAction('TestAction', triggerSetting, null, requiredFlag);

		Test.startTest();
		SEL_TriggerAction.shouldExecute(triggerSetting, triggerAction);
		SEL_TriggerAction.shouldExecute(triggerSetting, triggerAction);
		Test.stopTest();

		String key = SEL_TriggerAction.FINGERPRINT_SKIP_PREFIX + UTIL_String.COLON + 'Account' + UTIL_String.COLON + 'TestAction';
		String detailKey = TRG_PersistLogEntry.PREFIX_DETAIL + key;
		String rollupPrefix = TRG_PersistLogEntry.PREFIX_ROLLUP + key;
		Integer persistedSkipRows = 0;
		Integer detailRows = 0;
		Integer rollupTotal = 0;
		String detailLevel = null;
		for(LogEntry__c row : new SEL_LogEntry().getAll())
		{
			if(SEL_TriggerAction.AT_LOCATION_SHOULD_EXECUTE.equals(row.ClassMethod__c))
			{
				persistedSkipRows++;
			}
			if(row.Fingerprint__c == detailKey)
			{
				detailRows++;
				detailLevel = row.LogLevel__c;
			}
			else if(row.Fingerprint__c != null && row.Fingerprint__c.startsWith(rollupPrefix))
			{
				rollupTotal += row.OccurrenceCount__c?.intValue() ?? 0;
			}
		}

		String evidence = ' (persistedSkipRows=' + persistedSkipRows + ', detailRows=' + detailRows
				+ ', rollupTotal=' + rollupTotal + ', detailLevel=' + detailLevel + ')';
		Assert.areEqual(1, detailRows, 'Identical trigger-action skips must collapse to one detail row' + evidence);
		Assert.areEqual(2, rollupTotal, 'Both skips must be counted in the rollup' + evidence);
		Assert.areEqual('DEBUG', detailLevel, 'A routine flag-gated skip must persist at DEBUG, not INFO' + evidence);
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
	 * field is blank — preserves the existing behavior for standard objects, custom objects, and
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
	 * lookup key (which is always canonical) — and that an override the running context cannot
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
}