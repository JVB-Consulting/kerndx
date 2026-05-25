// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Tests the behaviour of related DAL class
 *
 * @see TST_Factory
 *
 * @author Jason van Beukering
 *
 * @group Testing
 *
 * @date September 2025, May 2026
 */
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest(SeeAllData=false IsParallel=false)
private class TST_Factory_TEST
{
	/**
	 * @description Checks that permissionset assignments work as expected, to test the scenario where the permissionset name provided
	 * is actually for a permission set group and a test running that we ensure permissionset group calculations are performed
	 *
	 * @see TST_Factory.createPermissionSetAssignments
	 * @see Test.calculatePermissionSetGroup
	 */
	@IsTest
	private static void createPermissionSetAssignments()
	{
		PermissionSetGroup newGroup = new PermissionSetGroup();

		newGroup.MasterLabel = UTIL_Random.randomName();
		newGroup.DeveloperName = newGroup.MasterLabel;

		// PermissionSetGroup / PermissionSetGroupComponent are Setup objects; TST_Builder does not model them and Test.calculatePermissionSetGroup requires real records.
		insert newGroup;

		PermissionSetGroupComponent newComponent = new PermissionSetGroupComponent();

		newComponent.PermissionSetGroupId = newGroup.Id;
		newComponent.PermissionSetId = new SEL_PermissionSet().findByName(SEL_PermissionSet.READ_ONLY_PERMISSION_SET_API_NAME).Id;

		insert newComponent;

		Test.startTest();

		TST_Factory.createPermissionSetAssignments(new List<User> {new SEL_User().getCurrentUser()}, newGroup.DeveloperName);

		Test.stopTest();

		PermissionSetGroup foundGroup = new SEL_PermissionSetGroup().findByName(newGroup.DeveloperName);

		Assert.areEqual(SEL_PermissionSetGroup.STATUS_UPDATED, foundGroup.Status, 'Status was not recalculated');
	}

	/**
	 * @description Tests the base newApiCall() method.
	 *
	 * @see TST_Factory.newApiCall
	 */
	@IsTest
	private static void newApiCall()
	{
		Test.startTest();

		ApiCall__c apiCall = TST_Factory.newApiCall();

		Test.stopTest();

		Assert.isNull(apiCall.Id, 'API call should not be inserted.');
	}

	/**
	 * @description Tests the newApiCall(String) method.
	 *
	 * @see TST_Factory.newApiCall
	 */
	@IsTest
	private static void newApiCallWithServiceName()
	{
		String testServiceName = UTIL_Random.randomName();

		Test.startTest();

		ApiCall__c apiCall = TST_Factory.newApiCall(testServiceName);

		Test.stopTest();

		Assert.isNotNull(apiCall, 'API call should not be null.');
		Assert.isNull(apiCall.Id, 'API call should not be inserted.');
		Assert.areEqual(0, apiCall.Retries__c, 'Retries__c should be 0.');
		Assert.areEqual(SEL_ApiCall.STATUS_QUEUED, apiCall.Status__c, 'Status__c should be Queued.');
		Assert.areEqual(testServiceName, apiCall.ServiceName__c, 'Service__c should be set from the parameter.');
	}

	/**
	 * @description Tests that API calls auto-start correlation when none exists.
	 *
	 * @see TST_Factory.newApiCall
	 */
	@IsTest
	private static void shouldAutoStartCorrelationWhenCreatingApiCall()
	{
		// Clear any existing correlation
		LOG_Builder.setCorrelationId(null);

		Test.startTest();

		ApiCall__c apiCall = TST_Factory.newOutboundApiCall(
				'API_TestService',
				null,
				new Map<String, String> {'param1' => 'value1'}
		);

		Test.stopTest();

		Assert.isNotNull(apiCall.LoggerContext__c, 'Logger context should be captured');
		Assert.isTrue(apiCall.LoggerContext__c.contains('correlationId'), 'Should contain correlationId');
		Assert.isNotNull(LOG_Builder.correlationId, 'Correlation should be auto-started');
	}

	/**
	 * @description Tests that existing correlation is captured in API call.
	 *
	 * @see TST_Factory.newApiCall
	 */
	@IsTest
	private static void shouldCaptureExistingCorrelationInApiCall()
	{
		String existingCorrelation = LOG_Builder.startCorrelation();
		LOG_Builder.setGlobalContext('testKey', 'testValue');

		Test.startTest();

		ApiCall__c apiCall = TST_Factory.newOutboundApiCall(
				'API_TestService',
				null,
				new Map<String, String>()
		);

		Test.stopTest();

		Assert.isNotNull(apiCall.LoggerContext__c, 'Logger context should be captured');
		Assert.isTrue(apiCall.LoggerContext__c.contains(existingCorrelation), 'Should contain existing correlationId');
		Assert.isTrue(apiCall.LoggerContext__c.contains('testKey'), 'Should contain global context');
	}

	/**
	 * @description Tests that all API call creation methods capture logger context.
	 *
	 * @see TST_Factory.newApiCall
	 */
	@IsTest
	private static void shouldCaptureContextInAllApiCallCreationOverloads()
	{
		// Test each overload captures context
		List<ApiCall__c> apiCalls = new List<ApiCall__c>();

		apiCalls.add(TST_Factory.newApiCall());
		apiCalls.add(TST_Factory.newApiCall('API_Test1'));
		apiCalls.add(TST_Factory.newOutboundApiCall('API_Test2'));
		apiCalls.add(TST_Factory.newOutboundApiCall('API_Test3', null, new Map<String, String>()));
		apiCalls.add(TST_Factory.newInboundApiCall('API_Test4'));

		for(ApiCall__c apiCall : apiCalls)
		{
			Assert.isNotNull(apiCall.LoggerContext__c, 'All overloads should capture context: ' + apiCall.ServiceName__c);
		}
	}

	/**
	 * @description Tests that newUser with companyName sets CompanyName correctly.
	 *
	 * @see TST_Factory.newUser
	 */
	@IsTest
	private static void newUserWithCompanyNameShouldSetCompanyName()
	{
		String companyName = 'unit-test-company-' + System.currentTimeMillis();

		Test.startTest();
		User testUser = TST_Factory.newUser(SEL_Profile.PROFILE_STANDARD_USER, companyName);
		Test.stopTest();

		Assert.areEqual(companyName, testUser.CompanyName, 'CompanyName should be set to the provided value');
		Assert.isNotNull(testUser.Email, 'Email should still be generated');
		Assert.isNotNull(testUser.Username, 'Username should still be generated');
	}

	/**
	 * @description Tests that newUserWithPermissionSet commits the user and assigns the permission set,
	 * and that a second call with a different company name yields a distinct Username (no collision).
	 *
	 * @see TST_Factory.newUserWithPermissionSet
	 */
	@IsTest
	private static void newUserWithPermissionSetShouldCommitAndAssign()
	{
		String companyNameA = 'unit-test-admin-a-' + System.currentTimeMillis();
		String companyNameB = 'unit-test-admin-b-' + System.currentTimeMillis();

		Test.startTest();
		User userA = TST_Factory.newUserWithPermissionSet
				(
						SEL_Profile.PROFILE_SYSTEM_ADMIN,
						companyNameA,
						SEL_PermissionSet.ADMIN_PERMISSION_SET_API_NAME
				);
		User userB = TST_Factory.newUserWithPermissionSet
				(
						SEL_Profile.PROFILE_SYSTEM_ADMIN,
						companyNameB,
						SEL_PermissionSet.ADMIN_PERMISSION_SET_API_NAME
				);
		Test.stopTest();

		Assert.isNotNull(userA.Id, 'User A should be committed and have an Id');
		Assert.isNotNull(userB.Id, 'User B should be committed and have an Id');
		Assert.areEqual(companyNameA, userA.CompanyName, 'User A CompanyName should match');
		Assert.areEqual(companyNameB, userB.CompanyName, 'User B CompanyName should match');
		Assert.areNotEqual(userA.Username, userB.Username, 'Usernames should be unique across calls');

		Assert.isTrue
				(
						new SEL_PermissionSetAssignment().isAssigned(SEL_PermissionSet.ADMIN_PERMISSION_SET_API_NAME, userA.Id),
						'Admin permission set should be assigned to user A'
				);
		Assert.isTrue
				(
						new SEL_PermissionSetAssignment().isAssigned(SEL_PermissionSet.ADMIN_PERMISSION_SET_API_NAME, userB.Id),
						'Admin permission set should be assigned to user B'
				);
	}

	/**
	 * @description Tests that newMinimumAccessUser returns an uncommitted user with the Minimum Access
	 * profile and the supplied company name, and that two calls yield distinct Usernames.
	 *
	 * @see TST_Factory.newMinimumAccessUser
	 */
	@IsTest
	private static void newMinimumAccessUserShouldSetProfileAndCompany()
	{
		String companyNameA = 'unit-test-lowpriv-a-' + System.currentTimeMillis();
		String companyNameB = 'unit-test-lowpriv-b-' + System.currentTimeMillis();
		Id minimumAccessProfileId = new SEL_Profile().findByName(SEL_Profile.PROFILE_MINIMUM_ACCESS).Id;

		Test.startTest();
		User userA = TST_Factory.newMinimumAccessUser(companyNameA);
		User userB = TST_Factory.newMinimumAccessUser(companyNameB);
		Test.stopTest();

		Assert.isNull(userA.Id, 'User A should be uncommitted (matching newUser semantics)');
		Assert.isNull(userB.Id, 'User B should be uncommitted (matching newUser semantics)');
		Assert.areEqual(minimumAccessProfileId, userA.ProfileId, 'User A should have the Minimum Access profile');
		Assert.areEqual(minimumAccessProfileId, userB.ProfileId, 'User B should have the Minimum Access profile');
		Assert.areEqual(companyNameA, userA.CompanyName, 'User A CompanyName should match');
		Assert.areEqual(companyNameB, userB.CompanyName, 'User B CompanyName should match');
		Assert.areNotEqual(userA.Username, userB.Username, 'Usernames should be unique across calls');
	}

	/**
	 * @description Tests that newSObjectShare sets OpportunityAccessLevel for AccountShare.
	 *
	 * @see TST_Factory.newSObjectShare
	 */
	@IsTest
	private static void newSObjectShareShouldSetOpportunityAccessLevelForAccount()
	{
		if(UTIL_SObjectDescribe.getSObjectTypeByName(SEL_ObjectShare.OBJECT_ACCOUNT_SHARE) == null)
		{
			return;
		}

		Account account = (Account)TST_Builder.of(Account.SObjectType)
				.withOverride(Account.Name, UTIL_Random.randomName())
				.withOverride(Account.Phone, '555-0100')
				.withOverride(Account.Industry, 'Technology')
				.build();

		SEL_ObjectShare.DTO_ObjectShareDescribe shareDescribe = SEL_ObjectShare.getShareDescribe(account.Id);
		User testUser = TST_Factory.newUser(SEL_Profile.PROFILE_STANDARD_USER);

		Test.startTest();

		SObject shareRecord = TST_Factory.newSObjectShare(shareDescribe, account.Id, 'Edit', testUser.Id);

		Test.stopTest();

		Assert.areEqual
				(
						SEL_ObjectShare.ACCESS_LEVEL_NONE,
						shareRecord.get(SEL_ObjectShare.FIELD_OPPORTUNITY_ACCESS_LEVEL),
						'OpportunityAccessLevel should be set to None for AccountShare'
				);
	}

	/**
	 * @description Tests that newInboundApiSetting creates a mock ApiSetting__mdt with correct field values.
	 *
	 * @see TST_Factory.newInboundApiSetting
	 */
	@IsTest
	private static void newInboundApiSettingShouldCreateMockWithCorrectFields()
	{
		String className = API_Echo.class.getName();
		String endpointPath = '/echo/*';

		Test.startTest();

		ApiSetting__mdt setting = TST_Factory.newInboundApiSetting(className, endpointPath);

		Test.stopTest();

		Assert.isNotNull(setting, 'Setting should not be null');
		Assert.areEqual(className, setting.ClassName__c, 'ClassName should match');
		Assert.areEqual(SEL_ApiSetting.DIRECTION_INBOUND, setting.Direction__c, 'Direction should be Inbound');
		Assert.isTrue(setting.IsActive__c, 'Should be active');
		Assert.areEqual(endpointPath, setting.EndpointPath__c, 'EndpointPath should match');
		Assert.areEqual(100, setting.Priority__c, 'Priority should be 100');
	}

	/**
	 * @description Tests that newOutboundApiSetting creates a mock ApiSetting__mdt with correct field values.
	 *
	 * @see TST_Factory.newOutboundApiSetting
	 */
	@IsTest
	private static void newOutboundApiSettingShouldCreateMockWithCorrectFields()
	{
		String className = API_PostExample.class.getName();

		Test.startTest();

		ApiSetting__mdt setting = TST_Factory.newOutboundApiSetting(className, null);

		Test.stopTest();

		Assert.isNotNull(setting, 'Setting should not be null');
		Assert.areEqual(className, setting.ClassName__c, 'ClassName should match');
		Assert.areEqual(SEL_ApiSetting.DIRECTION_OUTBOUND, setting.Direction__c, 'Direction should be Outbound');
		Assert.isTrue(setting.IsActive__c, 'Should be active');
	}

	/**
	 * @description Tests that newOutboundApiSetting applies field overrides on top of the defaults.
	 *
	 * @see TST_Factory.newOutboundApiSetting
	 */
	@IsTest
	private static void newOutboundApiSettingShouldApplyOverrides()
	{
		String className = API_PostExample.class.getName();
		String flagName = 'TestFlag';

		Test.startTest();

		ApiSetting__mdt setting = TST_Factory.newOutboundApiSetting(className, new Map<SObjectField, Object>
		{
				ApiSetting__mdt.IsActive__c => false,
				ApiSetting__mdt.RequiredFeatureFlag__c => TST_Factory.newFeatureFlag(flagName, false)
		});

		Test.stopTest();

		Assert.isFalse(setting.IsActive__c, 'IsActive override should take precedence');
		Assert.isNotNull(setting.RequiredFeatureFlag__c, 'RequiredFeatureFlag should be set');
		Assert.areEqual(flagName, setting.RequiredFeatureFlag__r?.DeveloperName, 'RequiredFeatureFlag DeveloperName should match');
	}

	/**
	 * @description Tests that newInboundApiSetting with overrides applies field overrides on top of the defaults.
	 *
	 * @see TST_Factory.newInboundApiSetting
	 */
	@IsTest
	private static void newInboundApiSettingShouldApplyOverrides()
	{
		String className = API_Echo.class.getName();
		String endpointPath = '/echo/*';

		Test.startTest();

		ApiSetting__mdt setting = TST_Factory.newInboundApiSetting(className, endpointPath, 100, new Map<SObjectField, Object>
		{
				ApiSetting__mdt.MockingEnabled__c => true
		});

		Test.stopTest();

		Assert.isNotNull(setting, 'Setting should not be null');
		Assert.areEqual(className, setting.ClassName__c, 'ClassName should match');
		Assert.areEqual(SEL_ApiSetting.DIRECTION_INBOUND, setting.Direction__c, 'Direction should be Inbound');
		Assert.isTrue(setting.MockingEnabled__c, 'MockingEnabled override should be applied');
		Assert.areEqual(endpointPath, setting.EndpointPath__c, 'EndpointPath should match');
	}

	/**
	 * @description Tests that newApiMock creates a mock ApiMock__mdt record with correct defaults.
	 *
	 * @see TST_Factory.newApiMock
	 */
	@IsTest
	private static void newApiMockShouldCreateMockWithDefaults()
	{
		Test.startTest();

		ApiMock__mdt mock = TST_Factory.newApiMock(null);

		Test.stopTest();

		Assert.isNotNull(mock, 'Mock should not be null');
		Assert.isTrue(mock.IsActive__c, 'Should be active by default');
		Assert.areEqual(100, mock.Priority__c, 'Default priority should be 100');
		Assert.areEqual(200, mock.StatusCode__c, 'Default status code should be 200');
		Assert.isFalse(mock.IsRegex__c, 'Should not be regex by default');
	}

	/**
	 * @description Tests that newApiMock applies field overrides on top of the defaults.
	 *
	 * @see TST_Factory.newApiMock
	 */
	@IsTest
	private static void newApiMockShouldApplyOverrides()
	{
		Test.startTest();

		ApiMock__mdt mock = TST_Factory.newApiMock(new Map<SObjectField, Object>
		{
				ApiMock__mdt.Priority__c => 10,
				ApiMock__mdt.MatchRequestBodyPattern__c => 'urgent',
				ApiMock__mdt.StatusCode__c => 201,
				ApiMock__mdt.ResponseBody__c => '{"mock":"urgent"}',
				ApiMock__mdt.IsActive__c => false
		});

		Test.stopTest();

		Assert.areEqual(10, mock.Priority__c, 'Priority override should take precedence');
		Assert.areEqual('urgent', mock.MatchRequestBodyPattern__c, 'Pattern should match override');
		Assert.areEqual(201, mock.StatusCode__c, 'StatusCode override should take precedence');
		Assert.areEqual('{"mock":"urgent"}', mock.ResponseBody__c, 'ResponseBody should match override');
		Assert.isFalse(mock.IsActive__c, 'IsActive override should take precedence');
	}

	/**
	 * @description Tests that mockAllApis creates the MockAllAPIs feature flag.
	 *
	 * @see TST_Factory.mockAllApis
	 */
	@IsTest
	private static void mockAllApisShouldActivateMockFeatureFlag()
	{
		Test.startTest();

		TST_Factory.mockAllApis();

		Test.stopTest();

		Assert.isTrue(UTIL_FeatureFlag.isEnabled('MockAllAPIs'), 'MockAllAPIs feature flag should be enabled');
	}

	/**
	 * @description Tests that assignAdministratorPermissionSet assigns the permission set when not already assigned.
	 *
	 * @see TST_Factory.assignAdministratorPermissionSet
	 */
	@IsTest
	private static void assignAdministratorPermissionSetShouldAssignWhenNotAssigned()
	{
		User testUser = TST_Factory.newUser(SEL_Profile.PROFILE_STANDARD_USER);
		// User DML is Setup-object DML; TST_Builder does not own User creation, and System.runAs requires a persisted User.
		insert testUser;

		System.runAs(testUser)
		{
			Test.startTest();

			TST_Factory.assignAdministratorPermissionSet();

			Test.stopTest();

			Boolean isAssigned = QRY_Builder.selectFrom(PermissionSetAssignment.SObjectType)
					.condition(PermissionSetAssignment.AssigneeId).equals(testUser.Id)
					.andCondition(PermissionSetAssignment.PermissionSetId).equals(
					new SEL_PermissionSet().findByName(SEL_PermissionSet.ADMIN_PERMISSION_SET_API_NAME).Id
			)
					.exists();

			Assert.isTrue(isAssigned, 'Administrator permission set should be assigned');
		}
	}

	/**
	 * @description Tests that newFeatureFlag activates a feature flag in the selector cache.
	 *
	 * @see TST_Factory.newFeatureFlag
	 */
	@IsTest
	private static void newFeatureFlagShouldActivateFlag()
	{
		String flagName = 'TestFeatureFlag';

		Test.startTest();

		FeatureFlag__mdt flag = TST_Factory.newFeatureFlag(flagName);

		Test.stopTest();

		Assert.isNotNull(flag, 'Flag should not be null');
		Assert.isTrue(flag.IsActive__c, 'Flag should be active');
		Assert.isTrue(flag.IsEnabledByDefault__c, 'Flag should be enabled by default');
		Assert.isTrue(UTIL_FeatureFlag.isEnabled(flagName), 'Flag should be queryable via UTIL_FeatureFlag');
	}

	/**
	 * @description Verifies that the 3-arg overload builds an uncommitted record without registering
	 * it in `SEL_FeatureFlag.activeFlags` when `registerAsActive = false`. The returned record is
	 * suitable for populating a `MetadataRelationship` lookup field without affecting
	 * `UTIL_FeatureFlag.isEnabled(...)` evaluations elsewhere in the transaction.
	 *
	 * @see TST_Factory.newFeatureFlag
	 */
	@IsTest
	private static void newFeatureFlagShouldBuildUnregisteredRecordWhenRegisterFalse()
	{
		String flagName = 'UnregisteredFlag_' + UTIL_Random.randomAlphabetic(8);

		FeatureFlag__mdt flag = TST_Factory.newFeatureFlag(flagName, false, true);

		Assert.isNotNull(flag, 'Record should be returned even when not registered');
		Assert.areEqual(flagName, flag.DeveloperName, 'DeveloperName should be set on the record');
		Assert.isTrue(flag.IsEnabledByDefault__c, 'Record should stamp the isEnabled argument on IsEnabledByDefault__c');
		Assert.isFalse(SEL_FeatureFlag.activeFlags.containsKey(flagName), 'Flag should NOT be registered in activeFlags when register=false');
		Assert.isFalse(UTIL_FeatureFlag.isEnabled(flagName), 'Unregistered flag should evaluate disabled');
	}

	/**
	 * @description Verifies that the 3-arg overload can register a flag with
	 * `IsEnabledByDefault__c = false` — the post-P6 pattern tests use to explicitly disable
	 * a subscriber-shipped flag whose CMDT default is now true.
	 *
	 * @see TST_Factory.newFeatureFlag
	 */
	@IsTest
	private static void newFeatureFlagShouldRegisterAsDisabledWhenIsEnabledFalse()
	{
		String flagName = 'DisabledFlag_' + UTIL_Random.randomAlphabetic(8);

		FeatureFlag__mdt flag = TST_Factory.newFeatureFlag(flagName, true, false);

		Assert.isNotNull(flag, 'Record should be returned');
		Assert.isFalse(flag.IsEnabledByDefault__c, 'IsEnabledByDefault__c should be false');
		Assert.isTrue(SEL_FeatureFlag.activeFlags.containsKey(flagName), 'Flag should be registered in activeFlags');
		Assert.isFalse(UTIL_FeatureFlag.isEnabled(flagName), 'Registered-but-disabled flag should evaluate disabled');
	}

	/**
	 * @description Verifies that newChainExecution creates an inserted record with the given values.
	 */
	@IsTest
	private static void shouldCreateChainExecution()
	{
		AsyncChainExecution__c execution = TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_RUNNING, 'TestChain');

		Assert.isNotNull(execution.Id, 'Should be inserted');
		Assert.areEqual('TestChain', execution.ChainName__c, 'Chain name should match');
		Assert.areEqual(SEL_AsyncChainExecution.STATUS_RUNNING, execution.Status__c, 'Status should match');
		Assert.isNotNull(execution.CorrelationId__c, 'Correlation ID should be auto-generated');
	}
}