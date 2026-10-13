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
 * @date September 2025, October 2026
 */
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs,PMD.KernNoStandardObjectInPackageTests')
@IsTest(seeAllData=false isParallel=false)
private class TST_Factory_TEST
{
	/**
	 * @description The email address used to verify that newFoobarWithEmail carries the given value through.
	 */
	private static final String EMAIL = 'given-address@example.com';

	/**
	 * @description The name of the feature flag that tells every inbound web service to answer with a mock.
	 */
	private static final String MOCK_ALL_INBOUND_APIS_FLAG = 'MockAllInboundAPIs';

	/**
	 * @description A field the factory never sets, used to prove a caller-shaped user is saved as shaped.
	 */
	private static final String SHAPED_USER_TITLE = 'Regional Manager';

	/**
	 * @description The batch size for the saved-batch test; two is the smallest batch that can prove distinct usernames.
	 */
	private static final Integer NUMBER_OF_SAVED_USERS = 2;

	/**
	 * @description The length of the random key stored in the query result memory cache.
	 */
	private static final Integer MEMORY_CACHE_KEY_LENGTH = 20;

	/**
	 * @description The query threshold for the logger settings tests; each log gets a distinct value so a swapped field shows.
	 */
	private static final Integer QUERY_THRESHOLD_MILLISECONDS = 10;

	/**
	 * @description The web service threshold for the logger settings tests.
	 */
	private static final Integer WEBSERVICE_THRESHOLD_MILLISECONDS = 20;

	/**
	 * @description The trigger threshold for the logger settings tests.
	 */
	private static final Integer TRIGGER_THRESHOLD_MILLISECONDS = 30;

	/**
	 * @description The validation threshold for the logger settings tests.
	 */
	private static final Integer VALIDATION_THRESHOLD_MILLISECONDS = 40;

	/**
	 * @description The masking threshold for the logger settings tests.
	 */
	private static final Integer MASKER_THRESHOLD_MILLISECONDS = 50;

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

		// TST_Builder DOES build and insert Setup objects like these (see UTIL_FeatureFlag_TEST); this test keeps
		// direct inserts only to exercise TST_Factory in isolation. Never copy this as a TST_Builder-cannot precedent.
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
	 * @description Tests that a test can save an ordinary record right after newUserWithPermissionSet in the same
	 * transaction: the factory owns the runAs guard around its user and permission-set writes, so the platform never
	 * sees them in the same stretch of the transaction as the Foobar__c insert. Deliberately not wrapped in
	 * Test.startTest and Test.stopTest, so the only thing segmenting the transaction is the factory's guard.
	 *
	 * @see TST_Factory.newUserWithPermissionSet
	 */
	@IsTest
	private static void newUserWithPermissionSetShouldNotCollideWithFollowingRecordDml()
	{
		String companyName = 'unit-test-guard-after-' + System.currentTimeMillis();

		User admin = TST_Factory.newUserWithPermissionSet(SEL_Profile.PROFILE_STANDARD_USER, companyName, SEL_PermissionSet.ADMIN_PERMISSION_SET_API_NAME);
		Foobar__c record = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType).build();

		Assert.isNotNull(admin.Id, 'The user should be saved');
		Assert.isNotNull(record.Id, 'An ordinary record saved after the factory setup writes should not collide with them');
	}

	/**
	 * @description Tests that a permission-set assignment can follow an ordinary record insert in the same
	 * transaction: the factory's guard isolates the assignment write from the Foobar__c insert before it. Not wrapped
	 * in Test.startTest and Test.stopTest, for the same reason as the sibling guard test.
	 *
	 * @see TST_Factory.createPermissionSetAssignments
	 */
	@IsTest
	private static void createPermissionSetAssignmentsShouldNotCollideWithPrecedingRecordDml()
	{
		User testUser = TST_Factory.insertUser(SEL_Profile.PROFILE_STANDARD_USER);
		TST_Builder.of(Foobar__c.SObjectType).build();

		TST_Factory.createPermissionSetAssignments(new List<User> {testUser}, SEL_PermissionSet.ADMIN_PERMISSION_SET_API_NAME);

		Assert.isTrue
				(
						new SEL_PermissionSetAssignment().isAssigned(SEL_PermissionSet.ADMIN_PERMISSION_SET_API_NAME, testUser.Id),
						'The assignment saved after an ordinary record should exist'
				);
	}

	/**
	 * @description Tests that insertUser saves a user on the named profile that System.runAs accepts.
	 *
	 * @see TST_Factory.insertUser
	 */
	@IsTest
	private static void insertUserShouldSaveUserOnProfile()
	{
		Id standardProfileId = new SEL_Profile().findByName(SEL_Profile.PROFILE_STANDARD_USER).Id;

		Test.startTest();
		User testUser = TST_Factory.insertUser(SEL_Profile.PROFILE_STANDARD_USER);
		Test.stopTest();

		Assert.isNotNull(testUser.Id, 'The user should be saved');
		Assert.areEqual(standardProfileId, testUser.ProfileId, 'The user should be on the named profile');
		System.runAs(testUser)
		{
			Assert.areEqual(testUser.Id, UserInfo.getUserId(), 'The saved user should be usable with System.runAs');
			Assert.areEqual(standardProfileId, UserInfo.getProfileId(), 'The persisted user should be on the named profile');
		}
	}

	/**
	 * @description Tests that insertUser with a company name saves the user with that company name, so a later test
	 * method can find it again through SEL_User.findByCompanyName.
	 *
	 * @see TST_Factory.insertUser
	 */
	@IsTest
	private static void insertUserWithCompanyNameShouldSaveWithCompanyName()
	{
		String companyName = 'unit-test-saved-company-' + System.currentTimeMillis();

		Test.startTest();
		User testUser = TST_Factory.insertUser(SEL_Profile.PROFILE_STANDARD_USER, companyName);
		Test.stopTest();

		Assert.isNotNull(testUser.Id, 'The user should be saved');
		Assert.areEqual(companyName, testUser.CompanyName, 'The company name should be set');
		Assert.areEqual(testUser.Id, new SEL_User().findByCompanyName(companyName).Id, 'The saved user should be retrievable by company name');
	}

	/**
	 * @description Tests that insertUsers by count saves the requested number of users with distinct usernames.
	 *
	 * @see TST_Factory.insertUsers
	 */
	@IsTest
	private static void insertUsersByCountShouldSaveDistinctUsers()
	{
		Test.startTest();
		List<User> users = TST_Factory.insertUsers(SEL_Profile.PROFILE_STANDARD_USER, NUMBER_OF_SAVED_USERS);
		Test.stopTest();

		Set<String> usernames = new Set<String>();
		for(User savedUser : users)
		{
			Assert.isNotNull(savedUser.Id, 'Every user should be saved');
			usernames.add(savedUser.Username);
		}
		Assert.areEqual(NUMBER_OF_SAVED_USERS, users.size(), 'The requested number of users should be saved');
		Assert.areEqual(NUMBER_OF_SAVED_USERS, usernames.size(), 'Usernames should be distinct');
	}

	/**
	 * @description Tests that insertUsers saves users the caller shaped, keeping a field the factory never sets, so an
	 * org whose User rules need more than the factory provides can build the user, set its fields and hand it over.
	 *
	 * @see TST_Factory.insertUsers
	 */
	@IsTest
	private static void insertUsersShouldSaveCallerShapedUsers()
	{
		String companyName = 'unit-test-shaped-' + System.currentTimeMillis();
		User shaped = TST_Factory.newUser(SEL_Profile.PROFILE_STANDARD_USER, companyName);
		shaped.Title = SHAPED_USER_TITLE;

		Test.startTest();
		List<User> saved = TST_Factory.insertUsers(new List<User> {shaped});
		Test.stopTest();

		Assert.isNotNull(saved.iterator().next().Id, 'The shaped user should be saved');
		Assert.areEqual(SHAPED_USER_TITLE, new SEL_User().findByCompanyName(companyName).Title, 'The caller-set field should survive the save');
	}

	/**
	 * @description Tests that the logger settings builder turns on exactly the chosen performance logs at their
	 * thresholds and registers the settings with the logger.
	 *
	 * @see TST_Factory.newLoggerSettings
	 */
	@IsTest
	private static void newLoggerSettingsShouldApplyEachChosenLog()
	{
		Test.startTest();
		TST_Factory.newLoggerSettings()
				.withQueryLogging(QUERY_THRESHOLD_MILLISECONDS)
				.withWebserviceLogging(WEBSERVICE_THRESHOLD_MILLISECONDS)
				.withTriggerLogging(TRIGGER_THRESHOLD_MILLISECONDS)
				.withValidationLogging(VALIDATION_THRESHOLD_MILLISECONDS)
				.withMaskerLogging(MASKER_THRESHOLD_MILLISECONDS)
				.apply();
		Test.stopTest();

		LogSetting__c setting = LOG_Engine.logSettingOverride;
		Assert.isTrue(setting.IsEnabled__c, 'The settings should enable the logger');
		Assert.areEqual(LoggingLevel.DEBUG.name(), setting.LogLevelThreshold__c, 'The level threshold should admit every entry');
		Assert.isTrue(setting.EnableQueryPerformanceLogging__c, 'Query logging should be on');
		Assert.areEqual(QUERY_THRESHOLD_MILLISECONDS, setting.QueryPerformanceThresholdMs__c.intValue(), 'The query threshold should be set');
		Assert.isTrue(setting.EnablePerformanceLogging__c, 'Webservice logging should be on');
		Assert.areEqual(WEBSERVICE_THRESHOLD_MILLISECONDS, setting.PerformanceThresholdMs__c.intValue(), 'The webservice threshold should be set');
		Assert.isTrue(setting.EnableTriggerPerformanceLogging__c, 'Trigger logging should be on');
		Assert.areEqual(TRIGGER_THRESHOLD_MILLISECONDS, setting.TriggerPerformanceThresholdMs__c.intValue(), 'The trigger threshold should be set');
		Assert.isTrue(setting.EnableValidationPerformanceLogging__c, 'Validation logging should be on');
		Assert.areEqual(VALIDATION_THRESHOLD_MILLISECONDS, setting.ValidationPerformanceThresholdMs__c.intValue(), 'The validation threshold should be set');
		Assert.isTrue(setting.EnableMaskerPerformanceLogging__c, 'Masker logging should be on');
		Assert.areEqual(MASKER_THRESHOLD_MILLISECONDS, setting.MaskerPerformanceThresholdMs__c.intValue(), 'The masker threshold should be set');
	}

	/**
	 * @description Tests that a performance log the test did not choose stays off.
	 *
	 * @see TST_Factory.newLoggerSettings
	 */
	@IsTest
	private static void newLoggerSettingsShouldLeaveUnchosenLogsOff()
	{
		Test.startTest();
		TST_Factory.newLoggerSettings().withTriggerLogging(TRIGGER_THRESHOLD_MILLISECONDS).apply();
		Test.stopTest();

		LogSetting__c setting = LOG_Engine.logSettingOverride;
		Assert.isTrue(setting.EnableTriggerPerformanceLogging__c, 'Trigger logging should be on');
		Assert.isFalse(setting.EnableQueryPerformanceLogging__c, 'Query logging should stay off');
		Assert.isFalse(setting.EnablePerformanceLogging__c, 'Webservice logging should stay off');
		Assert.isFalse(setting.EnableValidationPerformanceLogging__c, 'Validation logging should stay off');
		Assert.isFalse(setting.EnableMaskerPerformanceLogging__c, 'Masker logging should stay off');
	}

	/**
	 * @description Tests that the flag-and-threshold overloads route through the builder: an enabled log carries its
	 * threshold, a disabled one stays off, and the default overload turns every performance log off.
	 *
	 * @see TST_Factory.setupLoggerForTest
	 */
	@IsTest
	private static void setupLoggerForTestShouldRouteThroughTheBuilder()
	{
		TST_Factory.setupLoggerForTest(true, QUERY_THRESHOLD_MILLISECONDS, false, WEBSERVICE_THRESHOLD_MILLISECONDS);

		LogSetting__c setting = LOG_Engine.logSettingOverride;
		Assert.isTrue(setting.EnableQueryPerformanceLogging__c, 'Query logging should be on');
		Assert.areEqual(QUERY_THRESHOLD_MILLISECONDS, setting.QueryPerformanceThresholdMs__c.intValue(), 'The query threshold should be set');
		Assert.isFalse(setting.EnablePerformanceLogging__c, 'Webservice logging should stay off when not enabled');

		TST_Factory.setupLoggerForTest();

		Assert.isFalse(LOG_Engine.logSettingOverride.EnableQueryPerformanceLogging__c, 'The default settings turn every performance log off');
		Assert.isTrue(LOG_Engine.logSettingOverride.IsEnabled__c, 'The default settings still enable the logger');
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
	 * @description The flag that tells every inbound web service to answer with a mock is off until a test calls
	 * mockAllInboundApis, and on after it.
	 *
	 * @see TST_Factory.mockAllInboundApis
	 */
	@IsTest
	private static void shouldTurnOnTheMockAllInboundApisFlagWhenMockingAllInboundApis()
	{
		Assert.isFalse(UTIL_FeatureFlag.isEnabled(MOCK_ALL_INBOUND_APIS_FLAG), 'Expected the flag to be off before the call');

		TST_Factory.mockAllInboundApis();

		Assert.isTrue(UTIL_FeatureFlag.isEnabled(MOCK_ALL_INBOUND_APIS_FLAG), 'Expected the flag to be on after the call');
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

	/**
	 * @description Verifies that newFoobarWithEmail builds an uncommitted record carrying the given email, so a
	 * test can ask for a value the platform refuses without repeating the builder chain.
	 *
	 * @see TST_Factory.newFoobarWithEmail
	 */
	@IsTest
	private static void shouldCreateFoobarWithEmail()
	{
		Foobar__c foobar = TST_Factory.newFoobarWithEmail(EMAIL);

		Assert.isNull(foobar.Id, 'The record should not be inserted');
		Assert.areEqual(EMAIL, foobar.Email__c, 'The email should be the one given');
	}

	/**
	 * @description Verifies that using TST_Factory keeps a default value provider that was registered
	 * before the factory class loaded — the factory must never replace a registered provider. The
	 * factory call is the test method's first TST_Factory reference, so its static initializer runs
	 * after the registration.
	 *
	 * @see TST_Builder.defaultValueProvider
	 */
	@IsTest
	private static void factoryUseKeepsRegisteredDefaultValueProvider()
	{
		TST_Builder.defaultValueProvider = new RegisteredDefaultValueProvider();

		TST_Factory.newFoobar();

		Assert.isTrue(TST_Builder.defaultValueProvider instanceof RegisteredDefaultValueProvider, 'Using TST_Factory must not replace the registered default value provider.');
	}

	/**
	 * @description Verifies that saving setup records through the factory empties the query result memory cache, since
	 * the factory saves them with a raw insert that does not commit through DML_Transaction.
	 *
	 * @see TST_Factory.insertUser
	 */
	@IsTest
	private static void factoryInsertEmptiesTheMemoryCache()
	{
		String key = UTIL_Random.randomAlphanumeric(MEMORY_CACHE_KEY_LENGTH);
		QRY_Engine.storeCopyInMemoryCache(key, new List<Foobar__c> {TST_Factory.newFoobar()}, QRY_Engine.CacheStatus.MEMORY_STORED);
		Assert.isNotNull(QRY_Engine.getCopyFromMemoryCache(key), 'The key should be stored before the insert');

		TST_Factory.insertUser(SEL_Profile.PROFILE_STANDARD_USER);

		Assert.isNull(QRY_Engine.getCopyFromMemoryCache(key), 'Saving a user through the factory should empty the memory cache');
	}

	/**
	 * @description Marker provider standing in for a provider registered on the
	 * 'TST_Builder.defaultValueProvider' extension point before TST_Factory loads.
	 */
	private class RegisteredDefaultValueProvider extends UTIL_SObjectBuilderDefaultProvider
	{
	}
}