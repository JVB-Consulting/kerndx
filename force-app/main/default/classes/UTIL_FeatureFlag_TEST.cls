// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Test class for UTIL_FeatureFlag. Validates all strategy types, fallback behaviors,
 * error handling, value comparison logic, and Subscriber-First custom permission parsing.
 *
 * @see UTIL_FeatureFlag
 *
 * @author Jason van Beukering
 *
 * @group Feature Flags
 *
 * @date November 2025, May 2026
 */
@IsTest(SeeAllData=false)
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs,PMD.CyclomaticComplexity')
public class UTIL_FeatureFlag_TEST
{
	/**
	 * @description Unique Federation Identifier used to locate the test user across test methods.
	 */
	private static final String TEST_FEDERATION_ID = 'e09587c0-1f50-4f21-90cf-a8bbafc24491';

	/**
	 * @description Flag to verify that the custom strategy class was instantiated and executed.
	 */
	private static Boolean strategyWasExecuted = false;

	/**
	 * @description Static variable to track if user-aware strategy was executed.
	 */
	private static Boolean userAwareStrategyWasExecuted = false;

	/**
	 * @description Static variable to store the userId passed to user-aware strategy.
	 */
	private static Id userAwareStrategyUserId;

	/**
	 * @description Sets up a standard user with a known FederationIdentifier for use in all tests.
	 */
	@TestSetup
	private static void setup()
	{
		User newUser = TST_Factory.newUser(SEL_Profile.PROFILE_STANDARD_USER);
		newUser.FederationIdentifier = TEST_FEDERATION_ID;
		insert newUser;
	}

	/**
	 * @description Verifies that the feature flag is enabled when the running user
	 * is assigned to the Permission Set Group specified in the strategy.
	 *
	 * @see UTIL_FeatureFlag.checkPermissionSetGroup
	 */
	@IsTest
	private static void userInPermissionSetGroupEnablesFlag()
	{
		User runAsUser = new SEL_User().findByFederationId(TEST_FEDERATION_ID);
		TST_Factory.createPermissionSetAssignments(new List<User> {runAsUser}, SEL_PermissionSet.ADMIN_PERMISSION_SET_API_NAME);

		System.runAs(runAsUser)
		{
			assertFlagValue(true);
		}
	}

	/**
	 * @description Verifies that the feature flag is enabled when the user's Profile
	 * matches the target specified in the Profile strategy.
	 *
	 * @see UTIL_FeatureFlag.checkProfile
	 */
	@IsTest
	private static void matchingProfileStrategyEnablesFlag()
	{
		FeatureFlagStrategy__mdt strategy = SEL_FeatureFlag.activeFlags.get(SEL_FeatureFlag.TEST_FEATURE_FLAG).FeatureFlagStrategies__r.iterator().next();

		strategy.Type__c = SEL_FeatureFlagStrategy.TYPE_PROFILE;
		strategy.Target__c = SEL_Profile.PROFILE_STANDARD_USER;

		assertFlagValueWithUser(true);
	}

	/**
	 * @description Asserts that UTIL_FeatureFlag.isEnabled returns the expected boolean value.
	 *
	 * @param expectedValue The expected state of the feature flag
	 */
	private static void assertFlagValue(Boolean expectedValue)
	{
		Test.startTest();

		Boolean isEnabled = UTIL_FeatureFlag.isEnabled(SEL_FeatureFlag.TEST_FEATURE_FLAG);

		Test.stopTest();

		Assert.areEqual(expectedValue, isEnabled, 'Flag should match expected value');
	}

	/**
	 * @description Verifies that the feature flag is disabled when the running user
	 * is not assigned to the Permission Set Group.
	 *
	 * @see UTIL_FeatureFlag.checkPermissionSetGroup
	 */
	@IsTest
	private static void userNotInPermissionSetGroupDisablesFlag()
	{
		assertFlagValueWithUser(false);
	}

	/**
	 * @description Executes assertFlagValue under the context of the test user.
	 *
	 * @param expectedValue The expected flag state
	 */
	private static void assertFlagValueWithUser(Boolean expectedValue)
	{
		User runAsUser = new SEL_User().findByFederationId(TEST_FEDERATION_ID);

		System.runAs(runAsUser)
		{
			assertFlagValue(expectedValue);
		}
	}

	/**
	 * @description Verifies that an invalid Custom Permission strategy results in
	 * the flag being disabled.
	 *
	 * @see UTIL_FeatureFlag.checkCustomPermission
	 */
	@IsTest
	private static void invalidCustomPermissionDisablesFlag()
	{
		FeatureFlagStrategy__mdt strategy = SEL_FeatureFlag.activeFlags.get(SEL_FeatureFlag.TEST_FEATURE_FLAG).FeatureFlagStrategies__r.iterator().next();
		strategy.Type__c = SEL_FeatureFlagStrategy.TYPE_CUSTOM_PERMISSION;
		strategy.Target__c = 'Invalid_Permission';

		System.runAs(new SEL_User().findByFederationId(TEST_FEDERATION_ID))
		{
			TST_Factory.disableAllApis();
			assertFlagValue(false);
		}
	}

	/**
	 * @description Verifies Custom Permission strategy evaluates correctly for a specific (non-running) user.
	 * This tests the SEL_CustomPermission.hasPackagePermission path when userId != running user.
	 *
	 * @see UTIL_FeatureFlag.checkCustomPermission
	 * @see SEL_CustomPermission.hasPackagePermission
	 */
	@IsTest
	private static void customPermissionStrategyEvaluatesForSpecificUser()
	{
		User testUser = new SEL_User().findByFederationId(TEST_FEDERATION_ID);
		TST_Factory.createPermissionSetAssignments(new List<User> {testUser}, SEL_PermissionSet.ADMIN_PERMISSION_SET_API_NAME);

		FeatureFlagStrategy__mdt strategy = SEL_FeatureFlag.activeFlags.get(SEL_FeatureFlag.TEST_FEATURE_FLAG).FeatureFlagStrategies__r.iterator().next();
		strategy.Type__c = SEL_FeatureFlagStrategy.TYPE_CUSTOM_PERMISSION;
		strategy.Target__c = UTIL_FeatureFlag.CORE_PERMISSION_PREFIX + SEL_CustomPermission.FRAMEWORK_TEST_PERMISSION;

		Test.startTest();

		Boolean isEnabled = UTIL_FeatureFlag.isEnabled(SEL_FeatureFlag.TEST_FEATURE_FLAG, testUser.Id);

		Test.stopTest();

		Assert.isTrue(isEnabled, 'Flag should be enabled for user with package permission via Administrator permission set');
	}

	/**
	 * @description Verifies Custom Permission strategy returns false for a user without the permission.
	 * This tests the SEL_CustomPermission.hasPackagePermission path when user lacks the permission.
	 *
	 * @see UTIL_FeatureFlag.checkCustomPermission
	 * @see SEL_CustomPermission.hasPackagePermission
	 */
	@IsTest
	private static void customPermissionStrategyReturnsFalseWhenUserLacksPermission()
	{
		User testUser = new SEL_User().findByFederationId(TEST_FEDERATION_ID);

		FeatureFlagStrategy__mdt strategy = SEL_FeatureFlag.activeFlags.get(SEL_FeatureFlag.TEST_FEATURE_FLAG).FeatureFlagStrategies__r.iterator().next();
		strategy.Type__c = SEL_FeatureFlagStrategy.TYPE_CUSTOM_PERMISSION;
		strategy.Target__c = UTIL_FeatureFlag.CORE_PERMISSION_PREFIX + SEL_CustomPermission.FRAMEWORK_TEST_PERMISSION;

		Test.startTest();

		Boolean isEnabled = UTIL_FeatureFlag.isEnabled(SEL_FeatureFlag.TEST_FEATURE_FLAG, testUser.Id);

		Test.stopTest();

		Assert.isFalse(isEnabled, 'Flag should be disabled for user without package permission');
	}

	/**
	 * @description When no strategies are defined and IsEnabledByDefault__c is true,
	 * the flag should be enabled.
	 *
	 * @see UTIL_FeatureFlag.isEnabled
	 */
	@IsTest
	private static void noStrategiesWithDefaultTrueEnablesFlag()
	{
		FeatureFlag__mdt newFlag = (FeatureFlag__mdt)TST_Builder.of(FeatureFlag__mdt.SObjectType)
				.withoutInsertion()
				.build();
		newFlag.IsEnabledByDefault__c = true;

		SEL_FeatureFlag.activeFlags.put(SEL_FeatureFlag.TEST_FEATURE_FLAG, newFlag);

		assertFlagValueWithUser(true);
	}

	/**
	 * @description When no strategies are defined and IsEnabledByDefault__c is false,
	 * the flag should be disabled.
	 *
	 * @see UTIL_FeatureFlag.isEnabled
	 */
	@IsTest
	private static void noStrategiesWithDefaultFalseDisablesFlag()
	{
		FeatureFlag__mdt newFlag = (FeatureFlag__mdt)TST_Builder.of(FeatureFlag__mdt.SObjectType)
				.withoutInsertion()
				.build();
		newFlag.IsEnabledByDefault__c = false;

		SEL_FeatureFlag.activeFlags.put(SEL_FeatureFlag.TEST_FEATURE_FLAG, newFlag);

		assertFlagValueWithUser(false);
	}

	/**
	 * @description Verifies that the CustomHandler__c field overrides a built-in
	 * strategy type ('Profile') and enables the flag.
	 *
	 * @see UTIL_FeatureFlag.evaluateStrategy
	 */
	@IsTest
	private static void handlerOverrideFieldEnablesFlag()
	{
		FeatureFlagStrategy__mdt strategy = SEL_FeatureFlag.activeFlags.get(SEL_FeatureFlag.TEST_FEATURE_FLAG).FeatureFlagStrategies__r.iterator().next();
		// But the handler override field should be executed instead
		strategy.CustomHandler__c = TestFeatureFlagStrategy.class.getName();

		assertFlagValueWithUser(true);
		Assert.isTrue(strategyWasExecuted, 'Custom Handler was not executed');
	}

	/**
	 * @description Verifies that a Hierarchical Custom Setting field is correctly read
	 * and interpreted as enabling the flag when the value is true.
	 *
	 * @see UTIL_FeatureFlag.checkHierarchicalCustomSetting
	 */
	@IsTest
	private static void hierarchicalSettingDisablesApisEnablesFlag()
	{
		FeatureFlagStrategy__mdt strategy = SEL_FeatureFlag.activeFlags.get(SEL_FeatureFlag.TEST_FEATURE_FLAG).FeatureFlagStrategies__r.iterator().next();
		strategy.Type__c = SEL_FeatureFlagStrategy.TYPE_HIERARCHICAL_CUSTOM_SETTING;

		UTIL_SObjectDescribe objectDescribe = UTIL_SObjectDescribe.getDescribe(ApiRuntimeSwitch__c.SObjectType);
		strategy.Target__c = objectDescribe.getDescribe().name + UTIL_String.DOT + ApiRuntimeSwitch__c.DisableAllApis__c.getDescribe().name;

		System.runAs(new SEL_User().findByFederationId(TEST_FEDERATION_ID))
		{
			QRY_Builder.setMock(ApiRuntimeSwitch__c.SObjectType, new List<SObject>
			{
					new ApiRuntimeSwitch__c(SetupOwnerId = UserInfo.getUserId(), DisableAllApis__c = true)
			});
			assertFlagValue(true);
		}
	}

	/**
	 * @description Verifies that an invalid Hierarchical Custom Setting path
	 * results in the flag being disabled due to graceful error handling.
	 *
	 * @see UTIL_FeatureFlag.checkHierarchicalCustomSetting
	 */
	@IsTest
	private static void invalidHierarchicalSettingPathDisablesFlag()
	{
		FeatureFlagStrategy__mdt strategy = SEL_FeatureFlag.activeFlags.get(SEL_FeatureFlag.TEST_FEATURE_FLAG).FeatureFlagStrategies__r.iterator().next();
		strategy.Type__c = SEL_FeatureFlagStrategy.TYPE_HIERARCHICAL_CUSTOM_SETTING;
		strategy.Target__c = 'BadObjectName.BadFieldName';

		assertFlagValueWithUser(false);
	}

	/**
	 * @description When strategies exist but none match and ResultOnNoMatch__c is true,
	 * the flag should be enabled.
	 *
	 * @see UTIL_FeatureFlag.isEnabled
	 */
	@IsTest
	private static void noMatchingStrategiesWithResultOnNoMatchTrueEnablesFlag()
	{
		FeatureFlag__mdt flag = SEL_FeatureFlag.activeFlags.get(SEL_FeatureFlag.TEST_FEATURE_FLAG);
		flag.ResultOnNoMatch__c = true;
		flag.IsEnabledByDefault__c = false;

		FeatureFlagStrategy__mdt strategy = flag.FeatureFlagStrategies__r.iterator().next();
		strategy.Type__c = SEL_FeatureFlagStrategy.TYPE_PROFILE;
		strategy.Target__c = UTIL_Random.randomName();

		assertFlagValueWithUser(true);
	}

	/**
	 * @description When strategies exist but none match and ResultOnNoMatch__c is false,
	 * the flag should be disabled.
	 *
	 * @see UTIL_FeatureFlag.isEnabled
	 */
	@IsTest
	private static void noMatchingStrategiesWithResultOnNoMatchFalseDisablesFlag()
	{
		FeatureFlag__mdt flag = SEL_FeatureFlag.activeFlags.get(SEL_FeatureFlag.TEST_FEATURE_FLAG);
		flag.ResultOnNoMatch__c = false;
		flag.IsEnabledByDefault__c = true;

		FeatureFlagStrategy__mdt strategy = flag.FeatureFlagStrategies__r.iterator().next();
		strategy.Type__c = SEL_FeatureFlagStrategy.TYPE_PROFILE;
		strategy.Target__c = UTIL_Random.randomName();

		assertFlagValueWithUser(false);
	}

	/**
	 * @description Tests ExpectedValue__c handling on Hierarchical Custom Setting:
	 * 'true' enables flag, 'false' disables, any other value disables.
	 *
	 * @see UTIL_FeatureFlag.checkHierarchicalCustomSetting
	 * @see UTIL_FeatureFlag.areValuesEqual
	 */
	@IsTest
	private static void hierarchicalSettingWithExpectedValueRespectsComparison()
	{
		FeatureFlagStrategy__mdt strategy = SEL_FeatureFlag.activeFlags.get(SEL_FeatureFlag.TEST_FEATURE_FLAG).FeatureFlagStrategies__r.iterator().next();
		strategy.Type__c = SEL_FeatureFlagStrategy.TYPE_HIERARCHICAL_CUSTOM_SETTING;

		System.runAs(new SEL_User().findByFederationId(TEST_FEDERATION_ID))
		{
			QRY_Builder.setMock(ApiRuntimeSwitch__c.SObjectType, new List<SObject>
			{
					new ApiRuntimeSwitch__c(SetupOwnerId = UserInfo.getUserId(), DisableAllApis__c = true)
			});

			UTIL_SObjectDescribe objectDescribe = UTIL_SObjectDescribe.getDescribe(ApiRuntimeSwitch__c.SObjectType);
			strategy.Target__c = objectDescribe.getDescribe().name + UTIL_String.DOT + ApiRuntimeSwitch__c.DisableAllApis__c.getDescribe().name;

			strategy.ExpectedValue__c = 'true';
			Assert.areEqual(true, UTIL_FeatureFlag.isEnabled(SEL_FeatureFlag.TEST_FEATURE_FLAG), 'ExpectedValue "true" should enable flag');

			strategy.ExpectedValue__c = 'false';
			Assert.areEqual(false, UTIL_FeatureFlag.isEnabled(SEL_FeatureFlag.TEST_FEATURE_FLAG), 'ExpectedValue "false" should disable flag');

			strategy.ExpectedValue__c = 'SomeOtherValue';
			Assert.areEqual(false, UTIL_FeatureFlag.isEnabled(SEL_FeatureFlag.TEST_FEATURE_FLAG), 'Unexpected value should disable flag');
		}
	}

	/**
	 * @description Unit tests for the private helper areValuesEqual covering boolean,
	 * numeric, and string comparisons with type coercion.
	 *
	 * @see UTIL_FeatureFlag.areValuesEqual
	 */
	@IsTest
	private static void areValuesEqualHandlesAllSupportedTypesCorrectly()
	{
		Test.startTest();

		Assert.isTrue(UTIL_FeatureFlag.areValuesEqual(true, 'true'), 'Boolean true');
		Assert.isFalse(UTIL_FeatureFlag.areValuesEqual(true, 'false'), 'Boolean mismatch');

		Assert.isTrue(UTIL_FeatureFlag.areValuesEqual(5, '5'), 'Integer match');
		Assert.isTrue(UTIL_FeatureFlag.areValuesEqual(5.0, '5'), 'Decimal/Integer match');
		Assert.isTrue(UTIL_FeatureFlag.areValuesEqual(5, '5.0'), 'Integer/Decimal match');
		Assert.isTrue(UTIL_FeatureFlag.areValuesEqual(123.45, '123.45'), 'Decimal match');
		Assert.isFalse(UTIL_FeatureFlag.areValuesEqual(5, '6'), 'Number mismatch');

		Assert.isTrue(UTIL_FeatureFlag.areValuesEqual('Test', 'test'), 'String case-insensitive match');
		Assert.isFalse(UTIL_FeatureFlag.areValuesEqual('Test', 'SomethingElse'), 'String mismatch');
		Assert.isFalse(UTIL_FeatureFlag.areValuesEqual(null, 'Test'), 'Null vs String');

		Test.stopTest();
	}

	/**
	 * @description Verifies the flag is enabled when the user is a member of the targeted Public Group.
	 *
	 * @see UTIL_FeatureFlag.checkPublicGroup
	 */
	@IsTest
	private static void userInPublicGroupEnablesFlag()
	{
		User runAsUser = createPublicGroupMember();

		System.runAs(runAsUser)
		{
			assertFlagValue(true);
		}
	}

	/**
	 * @description Creates a Public Group and adds the test user as a member.
	 *
	 * @return The test user
	 */
	private static User createPublicGroupMember()
	{
		User runAsUser = new SEL_User().findByFederationId(TEST_FEDERATION_ID);

		String groupName = UTIL_Random.randomName();

		Map<String, Object> overrides = new Map<String, Object>
		{
				'Group.Type' => 'Regular',
				'Group.Name' => groupName,
				GroupMember.UserOrGroupId.getDescribe().name => runAsUser.Id
		};

		TST_Builder.of(GroupMember.SObjectType)
				.withOverrides(overrides)
				.build();

		FeatureFlagStrategy__mdt strategy = SEL_FeatureFlag.activeFlags.get(SEL_FeatureFlag.TEST_FEATURE_FLAG).FeatureFlagStrategies__r.iterator().next();
		strategy.Type__c = SEL_FeatureFlagStrategy.TYPE_PUBLIC_GROUP;
		strategy.Target__c = groupName;
		strategy.ExpectedValue__c = null;

		return runAsUser;
	}

	/**
	 * @description Verifies the flag is disabled when the user is not in the targeted Public Group.
	 *
	 * @see UTIL_FeatureFlag.checkPublicGroup
	 */
	@IsTest
	private static void userNotInPublicGroupDisablesFlag()
	{
		User runAsUser = new SEL_User().findByFederationId(TEST_FEDERATION_ID);

		FeatureFlagStrategy__mdt strategy = SEL_FeatureFlag.activeFlags.get(SEL_FeatureFlag.TEST_FEATURE_FLAG).FeatureFlagStrategies__r.iterator().next();

		strategy.Type__c = SEL_FeatureFlagStrategy.TYPE_PUBLIC_GROUP;
		strategy.Target__c = UTIL_Random.randomName();
		strategy.ExpectedValue__c = null;

		System.runAs(runAsUser)
		{
			assertFlagValue(false);
		}
	}

	/**
	 * @description Tests Public Group strategy with ExpectedValue__c:
	 * 'true' when in group enables flag, 'false' disables.
	 *
	 * @see UTIL_FeatureFlag.checkPublicGroup
	 * @see UTIL_FeatureFlag.getStrategyResult
	 */
	@IsTest
	private static void publicGroupWithExpectedValueRespectsComparison()
	{
		User runAsUser = createPublicGroupMember();
		FeatureFlagStrategy__mdt strategy = SEL_FeatureFlag.activeFlags.get(SEL_FeatureFlag.TEST_FEATURE_FLAG).FeatureFlagStrategies__r.iterator().next();

		System.runAs(runAsUser)
		{
			Test.startTest();

			strategy.ExpectedValue__c = 'true';
			Assert.areEqual(true, UTIL_FeatureFlag.isEnabled(SEL_FeatureFlag.TEST_FEATURE_FLAG), 'In group + ExpectedValue "true" enables flag');

			strategy.ExpectedValue__c = 'false';
			Assert.areEqual(false, UTIL_FeatureFlag.isEnabled(SEL_FeatureFlag.TEST_FEATURE_FLAG), 'In group + ExpectedValue "false" disables flag');

			Test.stopTest();
		}
	}

	/**
	 * @description Verifies Custom Metadata field lookup with ExpectedValue__c comparison works.
	 *
	 * @see UTIL_FeatureFlag.checkCustomMetadataOrSettingRecord
	 */
	@IsTest
	private static void customMetadataFieldMatchesExpectedValueEnablesFlag()
	{
		TriggerAction__mdt foundAction = SEL_TriggerAction.findActiveByObjectNameAndTriggerOperation(SEL_Foobar.OBJECT_NAME, TriggerOperation.BEFORE_INSERT).iterator().next();
		FeatureFlagStrategy__mdt strategy = SEL_FeatureFlag.activeFlags.get(SEL_FeatureFlag.TEST_FEATURE_FLAG).FeatureFlagStrategies__r.iterator().next();

		strategy.Type__c = SEL_FeatureFlagStrategy.TYPE_CUSTOM_METADATA;
		strategy.Target__c = SEL_TriggerAction.OBJECT_NAME_TRIGGER_ACTION +
				UTIL_String.DOT + foundAction.DeveloperName + UTIL_String.DOT + TriggerAction__mdt.AllowNonSelfInitiated__c.getDescribe().name;
		strategy.ExpectedValue__c = 'true';

		assertFlagValueWithUser(true);
	}

	/**
	 * @description Verifies that providing invalid Path for a custom metadata field is treated as "NO_MATCH"
	 *
	 * @see UTIL_FeatureFlag.checkCustomMetadataOrSettingRecord
	 */
	@IsTest
	private static void invalidPathLengthForCustomMetadata()
	{
		FeatureFlag__mdt flag = SEL_FeatureFlag.activeFlags.get(SEL_FeatureFlag.TEST_FEATURE_FLAG);
		flag.ResultOnNoMatch__c = true;

		FeatureFlagStrategy__mdt strategy = flag.FeatureFlagStrategies__r.iterator().next();

		strategy.Type__c = SEL_FeatureFlagStrategy.TYPE_CUSTOM_METADATA;
		strategy.Target__c = UTIL_Random.randomName();

		assertFlagValueWithUser(true);
	}

	/**
	 * @description Verifies that providing invalid Path for a hierarchical setting field is treated as "NO_MATCH"
	 *
	 * @see UTIL_FeatureFlag.checkHierarchicalCustomSetting
	 */
	@IsTest
	private static void invalidPathLengthForHierarchicalSetting()
	{
		FeatureFlag__mdt flag = SEL_FeatureFlag.activeFlags.get(SEL_FeatureFlag.TEST_FEATURE_FLAG);
		flag.ResultOnNoMatch__c = true;

		FeatureFlagStrategy__mdt strategy = flag.FeatureFlagStrategies__r.iterator().next();

		strategy.Type__c = SEL_FeatureFlagStrategy.TYPE_HIERARCHICAL_CUSTOM_SETTING;
		strategy.Target__c = UTIL_Random.randomName();

		assertFlagValueWithUser(true);
	}

	/**
	 * @description Verifies that providing valid path, but no record is found is processed as "NO_MATCH"
	 *
	 * @see UTIL_FeatureFlag.checkCustomMetadataOrSettingRecord
	 */
	@IsTest
	private static void noRecordFoundForCustomMetadata()
	{
		FeatureFlag__mdt flag = SEL_FeatureFlag.activeFlags.get(SEL_FeatureFlag.TEST_FEATURE_FLAG);
		flag.ResultOnNoMatch__c = true;

		FeatureFlagStrategy__mdt strategy = flag.FeatureFlagStrategies__r.iterator().next();

		strategy.Type__c = SEL_FeatureFlagStrategy.TYPE_CUSTOM_METADATA;
		strategy.Target__c = SEL_TriggerAction.OBJECT_NAME_TRIGGER_ACTION +
				UTIL_String.DOT + UTIL_Random.randomName() + UTIL_String.DOT + TriggerAction__mdt.AllowNonSelfInitiated__c.getDescribe().name;

		assertFlagValueWithUser(true);
	}

	/**
	 * @description Verifies that providing valid path, but no record is found is processed as "NO_MATCH"
	 *
	 * @see UTIL_FeatureFlag.checkHierarchicalCustomSetting
	 */
	@IsTest
	private static void noRecordFoundForHierarchicalSetting()
	{
		FeatureFlag__mdt flag = SEL_FeatureFlag.activeFlags.get(SEL_FeatureFlag.TEST_FEATURE_FLAG);
		flag.ResultOnNoMatch__c = true;

		FeatureFlagStrategy__mdt strategy = flag.FeatureFlagStrategies__r.iterator().next();

		UTIL_SObjectDescribe objectDescribe = UTIL_SObjectDescribe.getDescribe(ApiRuntimeSwitch__c.SObjectType);
		strategy.Target__c = objectDescribe.getDescribe().name + UTIL_String.DOT + ApiRuntimeSwitch__c.DisableAllApis__c.getDescribe().name;
		strategy.Type__c = SEL_FeatureFlagStrategy.TYPE_HIERARCHICAL_CUSTOM_SETTING;

		assertFlagValueWithUser(true);
	}

	/**
	 * @description Verifies List Custom Setting record field lookup and string comparison works.
	 *
	 * @see UTIL_FeatureFlag.checkCustomMetadataOrSettingRecord
	 */
	@IsTest
	private static void listCustomSettingRecordMatchesExpectedValueEnablesFlag()
	{
		final String scheduleName = 'TestSchedule';

		TST_Builder.of(ScheduleSetting__c.SObjectType)
				.withOverride(ScheduleSetting__c.Name, scheduleName)
				.build();

		FeatureFlagStrategy__mdt strategy = SEL_FeatureFlag.activeFlags.get(SEL_FeatureFlag.TEST_FEATURE_FLAG).FeatureFlagStrategies__r.iterator().next();

		strategy.Type__c = SEL_FeatureFlagStrategy.TYPE_LIST_CUSTOM_SETTING;
		strategy.Target__c = UTIL_SObjectDescribe.getDescribe(ScheduleSetting__c.SObjectType).getDescribe().name +
				UTIL_String.DOT + scheduleName + UTIL_String.DOT + ScheduleSetting__c.Name.getDescribe().name;
		strategy.ExpectedValue__c = scheduleName;

		assertFlagValueWithUser(true);
	}

	/**
	 * @description When a non-existent flag name is passed, isEnabled must return false.
	 *
	 * @see UTIL_FeatureFlag.isEnabled
	 */
	@IsTest
	private static void unknownFlagNameReturnsFalse()
	{
		Test.startTest();

		Boolean isEnabled = UTIL_FeatureFlag.isEnabled(UTIL_Random.randomName());

		Test.stopTest();

		Assert.isFalse(isEnabled, 'Unknown flag should return false');
	}

	/**
	 * @description Unknown strategy types should be ignored and fall back to ResultOnNoMatch__c.
	 *
	 * @see UTIL_FeatureFlag.isEnabled
	 */
	@IsTest
	private static void unknownStrategyTypeWithResultOnNoMatchTrueEnablesFlag()
	{
		FeatureFlag__mdt flag = SEL_FeatureFlag.activeFlags.get(SEL_FeatureFlag.TEST_FEATURE_FLAG);
		flag.ResultOnNoMatch__c = true;

		FeatureFlagStrategy__mdt strategy = flag.FeatureFlagStrategies__r.iterator().next();
		strategy.Type__c = UTIL_Random.randomName();

		assertFlagValueWithUser(true);
	}

	/**
	 * @description Test implementation of a custom feature flag strategy used by customStrategy test.
	 */
	public class TestFeatureFlagStrategy implements UTIL_FeatureFlag.INT_FeatureFlagStrategy
	{
		/**
		 * @description Evaluates the strategy and sets the execution flag.
		 *
		 * @param flag The parent FeatureFlag__mdt record
		 * @param strategyToEvaluate The strategy record being evaluated
		 *
		 * @return false to disable the flag
		 */
		public Boolean isEnabled(FeatureFlag__mdt flag, FeatureFlagStrategy__mdt strategyToEvaluate)
		{
			strategyWasExecuted = true;
			return true;
		}
	}

	/**
	 * @description Verifies isEnabled(flagName, userId) returns false for null userId.
	 *
	 * @see UTIL_FeatureFlag.isEnabled
	 */
	@IsTest
	private static void isEnabledWithNullUserIdReturnsFalse()
	{
		Test.startTest();

		Boolean isEnabled = UTIL_FeatureFlag.isEnabled(SEL_FeatureFlag.TEST_FEATURE_FLAG, (Id)null);

		Test.stopTest();

		Assert.isFalse(isEnabled, 'Null userId should return false');
	}

	/**
	 * @description Verifies isEnabled(flagName, username) returns false for non-existent username.
	 *
	 * @see UTIL_FeatureFlag.isEnabled
	 */
	@IsTest
	private static void isEnabledWithNonExistentUsernameReturnsFalse()
	{
		Test.startTest();

		Boolean isEnabled = UTIL_FeatureFlag.isEnabled(SEL_FeatureFlag.TEST_FEATURE_FLAG, 'nonexistent@test.invalid.com');

		Test.stopTest();

		Assert.isFalse(isEnabled, 'Non-existent username should return false');
	}

	/**
	 * @description Verifies isEnabled(flagName, username) correctly evaluates for a valid user.
	 *
	 * @see UTIL_FeatureFlag.isEnabled
	 */
	@IsTest
	private static void isEnabledWithUsernameEvaluatesForUser()
	{
		User testUser = new SEL_User().findByFederationId(TEST_FEDERATION_ID);
		TST_Factory.createPermissionSetAssignments(new List<User> {testUser}, SEL_PermissionSet.ADMIN_PERMISSION_SET_API_NAME);

		Test.startTest();

		Boolean isEnabled = UTIL_FeatureFlag.isEnabled(SEL_FeatureFlag.TEST_FEATURE_FLAG, testUser.Username);

		Test.stopTest();

		Assert.isTrue(isEnabled, 'Flag should be enabled for user with permission set');
	}

	/**
	 * @description Verifies isEnabled(flagName, userId) uses UserInfo optimization when userId is the running user.
	 * This tests the optimization path in createUserContext where profileId is loaded from UserInfo instead of querying.
	 * By passing UserInfo.getUserId() to isEnabled(flagName, userId), we trigger the running user optimization.
	 *
	 * @see UTIL_FeatureFlag.createUserContext
	 */
	@IsTest
	private static void isEnabledWithUserIdOptimizesForRunningUser()
	{
		FeatureFlag__mdt newFlag = (FeatureFlag__mdt)TST_Builder.of(FeatureFlag__mdt.SObjectType)
				.withoutInsertion()
				.build();
		newFlag.IsEnabledByDefault__c = true;

		SEL_FeatureFlag.activeFlags.put(SEL_FeatureFlag.TEST_FEATURE_FLAG, newFlag);

		Id runningUserId = UserInfo.getUserId();

		Test.startTest();

		// First verify setup is correct using isEnabled(flagName)
		Boolean controlResult = UTIL_FeatureFlag.isEnabled(SEL_FeatureFlag.TEST_FEATURE_FLAG);
		// Then test isEnabled(flagName, userId) with running user's ID stored in variable
		Boolean testResult = UTIL_FeatureFlag.isEnabled(SEL_FeatureFlag.TEST_FEATURE_FLAG, runningUserId);

		Test.stopTest();

		Assert.isTrue(controlResult, 'Control: Flag should be enabled by default (no strategies)');
		Assert.isTrue(testResult, 'Test: Flag should be enabled when called with running user ID: ' + runningUserId);
	}

	/**
	 * @description Verifies isEnabled(flagName, userId) correctly evaluates Profile strategy for a specific user.
	 *
	 * @see UTIL_FeatureFlag.checkProfile
	 */
	@IsTest
	private static void profileStrategyEvaluatesForSpecificUser()
	{
		User testUser = new SEL_User().findByFederationId(TEST_FEDERATION_ID);

		FeatureFlagStrategy__mdt strategy = SEL_FeatureFlag.activeFlags.get(SEL_FeatureFlag.TEST_FEATURE_FLAG).FeatureFlagStrategies__r.iterator().next();
		strategy.Type__c = SEL_FeatureFlagStrategy.TYPE_PROFILE;
		strategy.Target__c = SEL_Profile.PROFILE_STANDARD_USER;

		Test.startTest();

		Boolean isEnabled = UTIL_FeatureFlag.isEnabled(SEL_FeatureFlag.TEST_FEATURE_FLAG, testUser.Id);

		Test.stopTest();

		Assert.isTrue(isEnabled, 'Flag should be enabled for user with matching profile');
	}

	/**
	 * @description Verifies isEnabled(flagName, userId) correctly evaluates Permission Set Group strategy for a specific user.
	 *
	 * @see UTIL_FeatureFlag.checkPermissionSetGroup
	 */
	@IsTest
	private static void permissionSetGroupStrategyEvaluatesForSpecificUser()
	{
		User testUser = new SEL_User().findByFederationId(TEST_FEDERATION_ID);
		TST_Factory.createPermissionSetAssignments(new List<User> {testUser}, SEL_PermissionSet.ADMIN_PERMISSION_SET_API_NAME);

		Test.startTest();

		Boolean isEnabled = UTIL_FeatureFlag.isEnabled(SEL_FeatureFlag.TEST_FEATURE_FLAG, testUser.Id);

		Test.stopTest();

		Assert.isTrue(isEnabled, 'Flag should be enabled for user with assigned permission set');
	}

	/**
	 * @description Verifies Public Group strategy evaluates correctly for a specific user.
	 *
	 * @see UTIL_FeatureFlag.checkPublicGroup
	 */
	@IsTest
	private static void publicGroupStrategyEvaluatesForSpecificUser()
	{
		User testUser = new SEL_User().findByFederationId(TEST_FEDERATION_ID);
		String groupName = UTIL_Random.randomName();

		Map<String, Object> overrides = new Map<String, Object>
		{
				'Group.Type' => 'Regular',
				'Group.Name' => groupName,
				GroupMember.UserOrGroupId.getDescribe().name => testUser.Id
		};

		TST_Builder.of(GroupMember.SObjectType)
				.withOverrides(overrides)
				.build();

		FeatureFlagStrategy__mdt strategy = SEL_FeatureFlag.activeFlags.get(SEL_FeatureFlag.TEST_FEATURE_FLAG).FeatureFlagStrategies__r.iterator().next();
		strategy.Type__c = SEL_FeatureFlagStrategy.TYPE_PUBLIC_GROUP;
		strategy.Target__c = groupName;
		strategy.ExpectedValue__c = null;

		Test.startTest();

		Boolean isEnabled = UTIL_FeatureFlag.isEnabled(SEL_FeatureFlag.TEST_FEATURE_FLAG, testUser.Id);

		Test.stopTest();

		Assert.isTrue(isEnabled, 'Flag should be enabled for user in the group');
	}

	/**
	 * @description Verifies that INT_UserAwareFeatureFlagStrategy.isEnabledForUser is called
	 * when evaluating for a non-running user.
	 *
	 * @see UTIL_FeatureFlag.evaluateCustomHandler
	 * @see UTIL_FeatureFlag.INT_UserAwareFeatureFlagStrategy
	 */
	@IsTest
	private static void userAwareCustomHandlerReceivesUserId()
	{
		User testUser = new SEL_User().findByFederationId(TEST_FEDERATION_ID);

		FeatureFlagStrategy__mdt strategy = SEL_FeatureFlag.activeFlags.get(SEL_FeatureFlag.TEST_FEATURE_FLAG).FeatureFlagStrategies__r.iterator().next();
		strategy.CustomHandler__c = TestUserAwareFeatureFlagStrategy.class.getName();

		userAwareStrategyWasExecuted = false;
		userAwareStrategyUserId = null;

		Test.startTest();

		Boolean isEnabled = UTIL_FeatureFlag.isEnabled(SEL_FeatureFlag.TEST_FEATURE_FLAG, testUser.Id);

		Test.stopTest();

		Assert.isTrue(userAwareStrategyWasExecuted, 'User-aware strategy should have been executed');
		Assert.areEqual(testUser.Id, userAwareStrategyUserId, 'Strategy should receive the correct userId');
		Assert.isTrue(isEnabled, 'Flag should be enabled based on strategy result');
	}

	/**
	 * @description Verifies that legacy INT_FeatureFlagStrategy uses isEnabled() method
	 * when evaluating for a non-running user (backward compatibility).
	 *
	 * @see UTIL_FeatureFlag.evaluateCustomHandler
	 */
	@IsTest
	private static void legacyCustomHandlerUsesIsEnabledForNonRunningUser()
	{
		User testUser = new SEL_User().findByFederationId(TEST_FEDERATION_ID);

		FeatureFlagStrategy__mdt strategy = SEL_FeatureFlag.activeFlags.get(SEL_FeatureFlag.TEST_FEATURE_FLAG).FeatureFlagStrategies__r.iterator().next();
		strategy.CustomHandler__c = TestFeatureFlagStrategy.class.getName();

		strategyWasExecuted = false;

		Test.startTest();

		Boolean isEnabled = UTIL_FeatureFlag.isEnabled(SEL_FeatureFlag.TEST_FEATURE_FLAG, testUser.Id);

		Test.stopTest();

		Assert.isTrue(strategyWasExecuted, 'Legacy strategy should have been executed');
		Assert.isTrue(isEnabled, 'Flag should be enabled based on strategy result');
	}

	/**
	 * @description Verifies isEnabled(flagName, userId) returns false when userId is null.
	 * This tests the early return in createUserContext.
	 *
	 * @see UTIL_FeatureFlag.createUserContext
	 */
	@IsTest
	private static void isEnabledReturnsFalseWhenUserIdIsNull()
	{
		Test.startTest();

		Boolean isEnabled = UTIL_FeatureFlag.isEnabled(SEL_FeatureFlag.TEST_FEATURE_FLAG, (Id)null);

		Test.stopTest();

		Assert.isFalse(isEnabled, 'Flag should return false when userId is null');
	}

	/**
	 * @description Test implementation of a user-aware custom feature flag strategy.
	 */
	public class TestUserAwareFeatureFlagStrategy implements UTIL_FeatureFlag.INT_UserAwareFeatureFlagStrategy
	{
		/**
		 * @description Evaluates the strategy for the running user.
		 *
		 * @param flag The parent FeatureFlag__mdt record
		 * @param strategyToEvaluate The strategy record being evaluated
		 *
		 * @return true to enable the flag
		 */
		public Boolean isEnabled(FeatureFlag__mdt flag, FeatureFlagStrategy__mdt strategyToEvaluate)
		{
			return isEnabledForUser(flag, strategyToEvaluate, UserInfo.getUserId());
		}

		/**
		 * @description Evaluates the strategy for a specific user.
		 *
		 * @param flag The parent FeatureFlag__mdt record
		 * @param strategyToEvaluate The strategy record being evaluated
		 * @param userId The user to evaluate for
		 *
		 * @return true to enable the flag
		 */
		public Boolean isEnabledForUser(FeatureFlag__mdt flag, FeatureFlagStrategy__mdt strategyToEvaluate, Id userId)
		{
			userAwareStrategyWasExecuted = true;
			userAwareStrategyUserId = userId;
			return true;
		}
	}

	/**
	 * @description Verifies that sortByOrder sorts strategies by Order__c ascending.
	 *
	 * @see UTIL_FeatureFlag.sortByOrder
	 */
	@IsTest
	private static void sortByOrderSortsStrategiesAscending()
	{
		FeatureFlagStrategy__mdt strategyOrder3 = new FeatureFlagStrategy__mdt(DeveloperName = 'Third', Order__c = 3);
		FeatureFlagStrategy__mdt strategyOrder1 = new FeatureFlagStrategy__mdt(DeveloperName = 'First', Order__c = 1);
		FeatureFlagStrategy__mdt strategyOrder2 = new FeatureFlagStrategy__mdt(DeveloperName = 'Second', Order__c = 2);

		List<FeatureFlagStrategy__mdt> unsorted = new List<FeatureFlagStrategy__mdt> {strategyOrder3, strategyOrder1, strategyOrder2};

		Test.startTest();
		List<FeatureFlagStrategy__mdt> sorted = UTIL_FeatureFlag.sortByOrder(unsorted);
		Test.stopTest();

		Assert.areEqual('First', sorted[0].DeveloperName, 'First strategy should have Order 1');
		Assert.areEqual('Second', sorted[1].DeveloperName, 'Second strategy should have Order 2');
		Assert.areEqual('Third', sorted[2].DeveloperName, 'Third strategy should have Order 3');
	}

	/**
	 * @description Verifies that sortByOrder treats null Order__c as 0 (first position).
	 *
	 * @see UTIL_FeatureFlag.sortByOrder
	 */
	@IsTest
	private static void sortByOrderTreatsNullAsZero()
	{
		FeatureFlagStrategy__mdt strategyOrder1 = new FeatureFlagStrategy__mdt(DeveloperName = 'Explicit', Order__c = 1);
		FeatureFlagStrategy__mdt strategyNullOrder = new FeatureFlagStrategy__mdt(DeveloperName = 'NullOrder');

		List<FeatureFlagStrategy__mdt> unsorted = new List<FeatureFlagStrategy__mdt> {strategyOrder1, strategyNullOrder};

		Test.startTest();
		List<FeatureFlagStrategy__mdt> sorted = UTIL_FeatureFlag.sortByOrder(unsorted);
		Test.stopTest();

		Assert.areEqual('NullOrder', sorted[0].DeveloperName, 'Null Order__c should be treated as 0 and come first');
		Assert.areEqual('Explicit', sorted[1].DeveloperName, 'Order 1 should come after null/0');
	}

	/**
	 * @description Verifies that custom permission with core. prefix checks package permissions.
	 * The core. prefix is an explicit alias for package permissions.
	 *
	 * @see UTIL_FeatureFlag.checkCustomPermission
	 * @see UTIL_FeatureFlag.CORE_PERMISSION_PREFIX
	 */
	@IsTest
	private static void customPermissionWithCorePrefixChecksPackagePermission()
	{
		User testUser = new SEL_User().findByFederationId(TEST_FEDERATION_ID);
		TST_Factory.createPermissionSetAssignments(new List<User> {testUser}, SEL_PermissionSet.ADMIN_PERMISSION_SET_API_NAME);

		FeatureFlagStrategy__mdt strategy = SEL_FeatureFlag.activeFlags.get(SEL_FeatureFlag.TEST_FEATURE_FLAG).FeatureFlagStrategies__r.iterator().next();
		strategy.Type__c = SEL_FeatureFlagStrategy.TYPE_CUSTOM_PERMISSION;
		strategy.Target__c = UTIL_FeatureFlag.CORE_PERMISSION_PREFIX + SEL_CustomPermission.FRAMEWORK_TEST_PERMISSION;

		Test.startTest();

		Boolean isEnabled = UTIL_FeatureFlag.isEnabled(SEL_FeatureFlag.TEST_FEATURE_FLAG, testUser.Id);

		Test.stopTest();

		Assert.isTrue(isEnabled, 'Flag should be enabled for user with package permission via core. prefix');
	}

	/**
	 * @description Verifies that custom permission with namespace__ syntax checks namespaced permissions.
	 * This tests the fully-qualified namespaced permission path.
	 *
	 * @see UTIL_FeatureFlag.checkCustomPermission
	 * @see UTIL_FeatureFlag.NAMESPACE_DELIMITER
	 */
	@IsTest
	private static void customPermissionWithNamespaceDelimiterChecksNamespacedPermission()
	{
		User testUser = new SEL_User().findByFederationId(TEST_FEDERATION_ID);

		FeatureFlagStrategy__mdt strategy = SEL_FeatureFlag.activeFlags.get(SEL_FeatureFlag.TEST_FEATURE_FLAG).FeatureFlagStrategies__r.iterator().next();
		strategy.Type__c = SEL_FeatureFlagStrategy.TYPE_CUSTOM_PERMISSION;
		// Use a non-existent namespaced permission - should return false
		strategy.Target__c = 'nonexistent__Some_Permission';

		Test.startTest();

		Boolean isEnabled = UTIL_FeatureFlag.isEnabled(SEL_FeatureFlag.TEST_FEATURE_FLAG, testUser.Id);

		Test.stopTest();

		Assert.isFalse(isEnabled, 'Flag should be disabled for non-existent namespaced permission');
	}

	/**
	 * @description Verifies that unprefixed custom permission checks local/subscriber permissions.
	 * This is the Subscriber-First default behavior.
	 *
	 * @see UTIL_FeatureFlag.checkCustomPermission
	 * @see SEL_CustomPermission.hasLocalPermission
	 */
	@IsTest
	private static void unprefixedCustomPermissionChecksLocalPermission()
	{
		User testUser = new SEL_User().findByFederationId(TEST_FEDERATION_ID);

		FeatureFlagStrategy__mdt strategy = SEL_FeatureFlag.activeFlags.get(SEL_FeatureFlag.TEST_FEATURE_FLAG).FeatureFlagStrategies__r.iterator().next();
		strategy.Type__c = SEL_FeatureFlagStrategy.TYPE_CUSTOM_PERMISSION;
		// Unprefixed permission - should check local/subscriber permissions
		strategy.Target__c = 'Some_Local_Permission';

		Test.startTest();

		Boolean isEnabled = UTIL_FeatureFlag.isEnabled(SEL_FeatureFlag.TEST_FEATURE_FLAG, testUser.Id);

		Test.stopTest();

		Assert.isFalse(isEnabled, 'Flag should be disabled for non-existent local permission');
	}

	/**
	 * @description Verifies that custom permission with blank target returns NO_MATCH.
	 *
	 * @see UTIL_FeatureFlag.checkCustomPermission
	 */
	@IsTest
	private static void customPermissionWithBlankTargetReturnsNoMatch()
	{
		FeatureFlag__mdt flag = SEL_FeatureFlag.activeFlags.get(SEL_FeatureFlag.TEST_FEATURE_FLAG);
		flag.ResultOnNoMatch__c = true;

		FeatureFlagStrategy__mdt strategy = flag.FeatureFlagStrategies__r.iterator().next();
		strategy.Type__c = SEL_FeatureFlagStrategy.TYPE_CUSTOM_PERMISSION;
		strategy.Target__c = '';

		Test.startTest();

		Boolean isEnabled = UTIL_FeatureFlag.isEnabled(SEL_FeatureFlag.TEST_FEATURE_FLAG);

		Test.stopTest();

		Assert.isTrue(isEnabled, 'Blank target should return NO_MATCH, falling back to ResultOnNoMatch');
	}

	/**
	 * @description Verifies that custom permission with null target returns NO_MATCH.
	 *
	 * @see UTIL_FeatureFlag.checkCustomPermission
	 */
	@IsTest
	private static void customPermissionWithNullTargetReturnsNoMatch()
	{
		FeatureFlag__mdt flag = SEL_FeatureFlag.activeFlags.get(SEL_FeatureFlag.TEST_FEATURE_FLAG);
		flag.ResultOnNoMatch__c = true;

		FeatureFlagStrategy__mdt strategy = flag.FeatureFlagStrategies__r.iterator().next();
		strategy.Type__c = SEL_FeatureFlagStrategy.TYPE_CUSTOM_PERMISSION;
		strategy.Target__c = null;

		Test.startTest();

		Boolean isEnabled = UTIL_FeatureFlag.isEnabled(SEL_FeatureFlag.TEST_FEATURE_FLAG);

		Test.stopTest();

		Assert.isTrue(isEnabled, 'Null target should return NO_MATCH, falling back to ResultOnNoMatch');
	}

	/**
	 * @description Verifies namespaced permission uses FeatureManagement for running user.
	 * This tests the optimization path for running user with fully-qualified permission names.
	 *
	 * @see UTIL_FeatureFlag.checkNamespacedPermission
	 */
	@IsTest
	private static void namespacedPermissionUsesFeatureManagementForRunningUser()
	{
		User runAsUser = new SEL_User().findByFederationId(TEST_FEDERATION_ID);

		FeatureFlagStrategy__mdt strategy = SEL_FeatureFlag.activeFlags.get(SEL_FeatureFlag.TEST_FEATURE_FLAG).FeatureFlagStrategies__r.iterator().next();
		strategy.Type__c = SEL_FeatureFlagStrategy.TYPE_CUSTOM_PERMISSION;
		strategy.Target__c = 'somens__Some_Permission';

		System.runAs(runAsUser)
		{
			Test.startTest();

			// For running user, FeatureManagement.checkPermission is used
			Boolean isEnabled = UTIL_FeatureFlag.isEnabled(SEL_FeatureFlag.TEST_FEATURE_FLAG);

			Test.stopTest();

			Assert.isFalse(isEnabled, 'Non-existent namespaced permission should return false');
		}
	}

	/**
	 * @description Verifies core. prefix permission uses FeatureManagement for running user.
	 *
	 * @see UTIL_FeatureFlag.checkPackagePermission
	 */
	@IsTest
	private static void corePermissionUsesFeatureManagementForRunningUser()
	{
		User runAsUser = new SEL_User().findByFederationId(TEST_FEDERATION_ID);
		TST_Factory.createPermissionSetAssignments(new List<User> {runAsUser}, SEL_PermissionSet.ADMIN_PERMISSION_SET_API_NAME);

		FeatureFlagStrategy__mdt strategy = SEL_FeatureFlag.activeFlags.get(SEL_FeatureFlag.TEST_FEATURE_FLAG).FeatureFlagStrategies__r.iterator().next();
		strategy.Type__c = SEL_FeatureFlagStrategy.TYPE_CUSTOM_PERMISSION;
		strategy.Target__c = UTIL_FeatureFlag.CORE_PERMISSION_PREFIX + SEL_CustomPermission.FRAMEWORK_TEST_PERMISSION;

		System.runAs(runAsUser)
		{
			Test.startTest();

			// For running user, FeatureManagement.checkPermission is used
			Boolean isEnabled = UTIL_FeatureFlag.isEnabled(SEL_FeatureFlag.TEST_FEATURE_FLAG);

			Test.stopTest();

			Assert.isTrue(isEnabled, 'Running user with permission should have flag enabled');
		}
	}

	/**
	 * @description Verifies that local (unprefixed) permission always uses SOQL path.
	 * FeatureManagement cannot see subscriber permissions from managed package code.
	 *
	 * @see UTIL_FeatureFlag.checkCustomPermission
	 * @see SEL_CustomPermission.hasLocalPermission
	 */
	@IsTest
	private static void localPermissionAlwaysUsesSOQL()
	{
		User runAsUser = new SEL_User().findByFederationId(TEST_FEDERATION_ID);

		FeatureFlagStrategy__mdt strategy = SEL_FeatureFlag.activeFlags.get(SEL_FeatureFlag.TEST_FEATURE_FLAG).FeatureFlagStrategies__r.iterator().next();
		strategy.Type__c = SEL_FeatureFlagStrategy.TYPE_CUSTOM_PERMISSION;
		strategy.Target__c = 'Local_Permission_Name';

		System.runAs(runAsUser)
		{
			Test.startTest();

			// Local permissions always use SOQL (SEL_CustomPermission.hasLocalPermission)
			Boolean isEnabled = UTIL_FeatureFlag.isEnabled(SEL_FeatureFlag.TEST_FEATURE_FLAG);

			Test.stopTest();

			Assert.isFalse(isEnabled, 'Non-existent local permission should return false');
		}
	}

}