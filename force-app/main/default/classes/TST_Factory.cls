// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Factory class for generating test data, permission set assignments, share records, metadata updates, and failure logs across Salesforce objects.
 *
 * Optimized for unit tests and integration processes, providing methods to create records with random data and configure system settings such as API toggles,
 * triggers, and scheduled jobs.
 *
 * @see TST_Factory_TEST
 *
 * @author Jason van Beukering
 *
 * @group Testing
 *
 * @date February 2026, May 2026
 *
 * @since 1.0
 *
 * @example
 * ```apex
 * TriggerSetting__mdt setting = TST_Factory.newTriggerSetting('Foobar__c');
 * TST_Factory.newTriggerActionForContext('TRG_SetFoobarDefaults', setting, TriggerOperation.BEFORE_INSERT);
 * ```
 */
@SuppressWarnings('PMD.CognitiveComplexity,PMD.CyclomaticComplexity,PMD.ExcessivePublicCount,PMD.ExcessiveClassLength,PMD.AvoidGlobalModifier')
global without sharing class TST_Factory
{
	/**
	 * @description The number of mock users to create for login history testing.
	 */
	@TestVisible
	private static final Integer NUMBER_OF_MOCK_USERS_FOR_LOGIN_HISTORY = 3;

	/**
	 * @description Marker value used to identify users created by TST_Factory in tests.
	 */
	@TestVisible
	private static final String TEST_USER_MARKER = '17f0e4b4-e3f5-4861-95c8-ce8cdbb6545';

	/**
	 * @description The default cron expression for scheduling jobs.
	 */
	private static final String DEFAULT_CHRON_EXPRESSION = '0 0 * * * ?';

	/**
	 * @description Maps TriggerOperation enum values to Event__c picklist values.
	 * Delegates to the canonical map in SEL_TriggerAction.
	 */
	private static final Map<TriggerOperation, String> OPERATION_TO_EVENT = SEL_TriggerAction.OPERATION_TO_EVENT;

	/**
	 * @description Static initializer to set the custom default value provider.
	 * This ensures all User creation requests from this factory
	 * correctly handle license-based permission fields.
	 */
	static
	{
		// Set a custom provider to ignore license-based permission fields
		// This applies for the entire transaction when TST_Factory is loaded.
		TST_Builder.defaultValueProvider = new UserBuilderOptionalFieldsProvider();
	}

	/**
	 * @description Disables all inbound APIs by activating the DisableAllInboundAPIs feature flag.
	 *
	 * @example
	 * ```apex
	 * TST_Factory.disableAllInboundApis();
	 * ```
	 */
	@TestVisible
	private static void disableAllInboundApis()
	{
		newFeatureFlag('DisableAllInboundAPIs');
	}

	/**
	 * @description Disables all outbound APIs by activating the DisableAllOutboundAPIs feature flag.
	 *
	 * @example
	 * ```apex
	 * TST_Factory.disableAllOutboundApis();
	 * ```
	 */
	@TestVisible
	private static void disableAllOutboundApis()
	{
		newFeatureFlag('DisableAllOutboundAPIs');
	}

	/**
	 * @description Disables all APIs by activating the DisableAllAPIs feature flag.
	 *
	 * @example
	 * ```apex
	 * TST_Factory.disableAllApis();
	 * ```
	 */
	@TestVisible
	private static void disableAllApis()
	{
		newFeatureFlag('DisableAllAPIs');
	}

	/**
	 * @description Enables mocking for all outbound APIs by activating the MockAllAPIs feature flag.
	 *
	 * @example
	 * ```apex
	 * TST_Factory.mockAllApis();
	 * ```
	 */
	@TestVisible
	private static void mockAllApis()
	{
		newFeatureFlag('MockAllAPIs');
	}

	/**
	 * @description Enables mocking for all inbound APIs by activating the MockAllInboundAPIs feature flag.
	 *
	 * @example
	 * ```apex
	 * TST_Factory.mockAllInboundApis();
	 * ```
	 */
	@TestVisible
	private static void mockAllInboundApis()
	{
		newFeatureFlag('MockAllInboundAPIs');
	}

	/**
	 * @description Creates and inserts a list of User records with the specified profile.
	 *
	 * @param profileName The name of the profile to assign to the users.
	 * @param numberOfUsers The number of users to create and insert.
	 *
	 * @return A list of committed User records.
	 *
	 * @example
	 * ```apex
	 * List<User> users = TST_Factory.insertUsers('Standard User', 3);
	 * System.debug('Created ' + users.size() + ' users');
	 * ```
	 */
	@TestVisible
	private static List<User> insertUsers(String profileName, Integer numberOfUsers)
	{
		return getUserBuilder(profileName)
				.withCount(numberOfUsers)
				.buildList();
	}

	/**
	 * @description Creates a list of uncommitted User records with the specified profile.
	 *
	 * @param profileName The name of the profile to assign to the users.
	 * @param numberOfUsers The number of users to create.
	 *
	 * @return A list of uncommitted User records.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * List<User> mockUsers = TST_Factory.newUsers('Standard User', 5);
	 * insert mockUsers;
	 * for (User u : mockUsers)
	 * {
	 * System.debug('User Email: ' + u.Email);
	 * }
	 * ```
	 */
	global static List<User> newUsers(String profileName, Integer numberOfUsers)
	{
		return getUserBuilder(profileName)
				.withCount(numberOfUsers)
				.withoutInsertion()
				.buildList();
	}

	/**
	 * @description Creates a single uncommitted User record with the specified profile.
	 *
	 * @param profileName The name of the profile to assign to the user.
	 *
	 * @return An uncommitted User record.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * User testUser = TST_Factory.newUser('System Administrator');
	 * insert testUser;
	 * System.debug('User Email: ' + testUser.Email);
	 * ```
	 */
	global static User newUser(String profileName)
	{
		return newUsers(profileName, 1).iterator().next();
	}

	/**
	 * @description Creates an uncommitted User record with a custom company name.
	 *
	 * The company name can be used as a unique identifier to later retrieve this specific user
	 *
	 * @param profileName The Profile name to assign to the user.
	 * @param companyName A unique company name for this user.
	 *
	 * @return An uncommitted User record with the specified company name.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * @TestSetup
	 * private static void setupTestData()
	 * {
	 *     User testUser = TST_Factory.newUser('Standard User', 'my-test-user');
	 *     insert testUser;
	 * }
	 * private static User getTestUser()
	 * {
	 *     return new SEL_User().findByCompanyName('my-test-user');
	 * }
	 * }
	 */
	global static User newUser(String profileName, String companyName)
	{
		User user = newUser(profileName);
		user.CompanyName = companyName;
		return user;
	}

	/**
	 * @description Creates and inserts a User with the specified profile + company name, then assigns
	 * the named permission set (or permission set group). Composes newUser(profileName, companyName),
	 * insert, and createPermissionSetAssignments(List<User>, String).
	 *
	 * Intended for use in @TestSetup as a committed test admin that test methods reach via
	 * System.runAs. Because runAs re-evaluates permissions for the inner scope, the test admin
	 * receives a fresh permission cache — bypassing the stale-cache issue that affects mutation
	 * of the currently-running user's permission set mid-transaction (the failure mode that made
	 * assignAdministratorPermissionSet() unreliable in the 2GP synthetic validation org).
	 *
	 * @param profileName The Profile name to assign to the user.
	 * @param companyName A unique company name for this user. Used as the retrieval discriminator
	 *                    via SEL_User.findByCompanyName.
	 * @param permissionSetName The API name of the permission set (or permission set group) to assign.
	 *
	 * @return The committed User record with the permission set assigned.
	 *
	 * @throws AssertException If the profile or permission set cannot be resolved for the target org.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * private static final String TEST_ADMIN_COMPANY = 'MyClass_TEST-admin';
	 * @TestSetup
	 * private static void setupTestAdmin()
	 * {
	 *     TST_Factory.newUserWithPermissionSet(
	 *             'System Administrator',
	 *             TEST_ADMIN_COMPANY,
	 *             SEL_PermissionSet.ADMIN_PERMISSION_SET_API_NAME
	 *     );
	 * }
	 * private static User getTestAdmin()
	 * {
	 *     return new SEL_User().findByCompanyName(TEST_ADMIN_COMPANY);
	 * }
	 * @IsTest
	 * private static void shouldDoX()
	 * {
	 *     System.runAs(getTestAdmin())
	 *     {
	 *         // test body
	 *     }
	 * }
	 * ```
	 */
	@SuppressWarnings('PMD.ApexCRUDViolation')
	global static User newUserWithPermissionSet(String profileName, String companyName, String permissionSetName)
	{
		Profile profile = new SEL_Profile().findByName(profileName);
		Assert.isNotNull(profile, 'Profile not found: ' + profileName);
		User user = newUser(profileName, companyName);
		insert user;
		createPermissionSetAssignments(new List<User> {user}, permissionSetName);
		return user;
	}

	/**
	 * @description Creates an uncommitted User with the Minimum Access - Salesforce profile and the
	 * given company name. The returned user lacks FLS on almost every object — ideal for tier-A
	 * in-package tests that wrap framework calls in System.runAs(lowPrivilegeUser) to prove the
	 * framework's "subscribers-without-internal-FLS" contract holds because framework-internal
	 * selectors elevate via systemModeRequired().
	 *
	 * Returns uncommitted so the caller controls the insertion (matching newUser semantics). The
	 * typical pattern is to insert inside @TestSetup alongside a committed test admin user.
	 *
	 * Fails loudly (AssertException) if the profile cannot be resolved in the target org — prevents
	 * the silent "Required fields missing: [ProfileId]" DML error that otherwise masks the root cause
	 * when the profile is deactivated, renamed, or unlicensed.
	 *
	 * @param companyName A unique company name for this user. Used as the retrieval discriminator
	 *                    via SEL_User.findByCompanyName.
	 *
	 * @return An uncommitted User record with the Minimum Access - Salesforce profile.
	 *
	 * @throws AssertException If the 'Minimum Access - Salesforce' profile cannot be resolved.
	 *
	 * @example
	 * ```apex
	 * private static final String LOW_PRIVILEGE_COMPANY = 'MyClass_TEST-low-privilege';
	 * @TestSetup
	 * private static void setupUsers()
	 * {
	 *     User lowPrivilegeUser = TST_Factory.newMinimumAccessUser(LOW_PRIVILEGE_COMPANY);
	 *     insert lowPrivilegeUser;
	 * }
	 * @IsTest
	 * private static void shouldWorkForLowPrivilegeUser()
	 * {
	 *     User lowPrivilegeUser = new SEL_User().findByCompanyName(LOW_PRIVILEGE_COMPANY);
	 *     System.runAs(lowPrivilegeUser)
	 *     {
	 *         // framework call under test
	 *     }
	 * }
	 * ```
	 */
	@TestVisible
	private static User newMinimumAccessUser(String companyName)
	{
		Profile profile = new SEL_Profile().findByName(SEL_Profile.PROFILE_MINIMUM_ACCESS);
		Assert.isNotNull(profile, 'Profile not found: ' + SEL_Profile.PROFILE_MINIMUM_ACCESS);
		return newUser(SEL_Profile.PROFILE_MINIMUM_ACCESS, companyName);
	}

	/**
	 * @description Creates an uncommitted ContentVersion record from file data.
	 *
	 * @param linkToObjectId The Id of the object to link the content version to.
	 * @param fileName The name of the file.
	 * @param body The binary data of the file.
	 *
	 * @return An uncommitted ContentVersion record.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * Account acc = TST_Factory.newAccount();
	 * insert acc;
	 * ContentVersion version = TST_Factory.newContentVersion(acc.Id, 'test.pdf', Blob.valueOf('Test data'));
	 * insert version;
	 * System.debug('ContentVersion Title: ' + version.Title);
	 * ```
	 */
	global static ContentVersion newContentVersion(Id linkToObjectId, String fileName, Blob body)
	{
		ContentVersion newContentVersion = new ContentVersion();
		newContentVersion.FirstPublishLocationId = linkToObjectId;
		newContentVersion.PathOnClient = fileName;
		newContentVersion.Title = fileName;
		newContentVersion.VersionData = body;
		return newContentVersion;
	}

	/**
	 * @description Creates a non-inserted ScheduledJob__c record with parameters. Use for mock registration.
	 *
	 * @param schedulerClassName The fully qualified class name to schedule.
	 * @param parameters The parameter name-value pairs, stored as JSON in Parameters__c.
	 *
	 * @return A non-inserted ScheduledJob__c record with default fields populated.
	 *
	 * @example
	 * ```apex
	 * DTO_NameValues parameters = new DTO_NameValues(new Map<String, String>{'objectName' => 'LogEntry__c'});
	 * ScheduledJob__c job = TST_Factory.newScheduledJob(SCHED_PurgeRecords.class.getName(), parameters);
	 * TST_Mock.register(ScheduledJob__c.SObjectType, new List<ScheduledJob__c>{job});
	 * ```
	 */
	@TestVisible
	private static ScheduledJob__c newScheduledJob(String schedulerClassName, DTO_NameValues parameters)
	{
		return (ScheduledJob__c)getScheduledJobBuilder()
				.withOverride(ScheduledJob__c.ClassName__c, schedulerClassName)
				.withOverride(ScheduledJob__c.Parameters__c, parameters.serialize())
				.withoutInsertion(true)
				.build();
	}

	/**
	 * @description Creates and inserts a ScheduledJob__c record for scheduling a job.
	 *
	 * @param schedulerClassName The name of the class to schedule.
	 *
	 * @return A committed ScheduledJob__c record.
	 *
	 * @example
	 * ```apex
	 * ScheduledJob__c scheduler = TST_Factory.insertScheduledJob('MySchedulerClass');
	 * System.debug('Scheduler Id: ' + scheduler.Id);
	 * ```
	 */
	@TestVisible
	private static ScheduledJob__c insertScheduledJob(String schedulerClassName)
	{
		return (ScheduledJob__c)getScheduledJobBuilder()
				.withOverride(ScheduledJob__c.ClassName__c, schedulerClassName)
				.build();
	}

	/**
	 * @description Creates and inserts a ScheduledJob__c record with parameters.
	 *
	 * @param schedulerClassName The name of the class to schedule.
	 * @param parameters Map of parameter name-value pairs, stored as JSON in Parameters__c.
	 *
	 * @return A committed ScheduledJob__c record.
	 *
	 * @example
	 * ```apex
	 * ScheduledJob__c scheduler = TST_Factory.insertScheduledJob('SCHED_PurgeRecords', new Map<String, String>{'objectName' => 'Foobar__c'});
	 * ```
	 */
	@TestVisible
	private static ScheduledJob__c insertScheduledJob(String schedulerClassName, Map<String, String> parameters)
	{
		return (ScheduledJob__c)getScheduledJobBuilder()
				.withOverride(ScheduledJob__c.ClassName__c, schedulerClassName)
				.withOverride(ScheduledJob__c.Parameters__c, new DTO_NameValues(parameters).serialize())
				.build();
	}

	/**
	 * @description Creates and inserts an inactive ScheduledJob__c record (IsActive__c = false).
	 *
	 * @param schedulerClassName The name of the class to schedule.
	 *
	 * @return A committed inactive ScheduledJob__c record.
	 *
	 * @example
	 * ```apex
	 * ScheduledJob__c scheduler = TST_Factory.insertInactiveScheduledJob('MySchedulerClass');
	 * ```
	 */
	@TestVisible
	private static ScheduledJob__c insertInactiveScheduledJob(String schedulerClassName)
	{
		return (ScheduledJob__c)getScheduledJobBuilder()
				.withOverride(ScheduledJob__c.ClassName__c, schedulerClassName)
				.withOverride(ScheduledJob__c.IsActive__c, false)
				.build();
	}

	/**
	 * @description Creates an uncommitted ApiCall__c record for a web service call.
	 *
	 * @return An uncommitted ApiCall__c record.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * ApiCall__c apiCall = TST_Factory.newApiCall();
	 * insert apiCall;
	 * System.debug('API Call Id: ' + apiCall.Id);
	 * ```
	 */
	global static ApiCall__c newApiCall()
	{
		return (ApiCall__c)getApiCallBuilder()
				.withoutInsertion()
				.build();
	}

	/**
	 * @description Creates an uncommitted ApiCall__c record with a specified service name.
	 *
	 * @param serviceName The name of the web service class.
	 *
	 * @return An uncommitted ApiCall__c record.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * ApiCall__c apiCall = TST_Factory.newApiCall('MyService');
	 * insert apiCall;
	 * System.debug('API Call Service: ' + apiCall.ServiceName__c);
	 * ```
	 */
	global static ApiCall__c newApiCall(String serviceName)
	{
		Map<SObjectField, Object> overrides = new Map<SObjectField, Object>
		{
				ApiCall__c.ServiceName__c => serviceName
		};

		return (ApiCall__c)getApiCallBuilder()
				.withOverrides(overrides)
				.withoutInsertion()
				.build();
	}

	/**
	 * @description Creates an uncommitted ApiCall__c record for an inbound web service call.
	 *
	 * @param serviceName The name of the web service class.
	 *
	 * @return An uncommitted ApiCall__c record.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * ApiCall__c inboundApiCall = TST_Factory.newInboundApiCall('InboundService');
	 * insert inboundApiCall;
	 * System.debug('Inbound API Call Id: ' + inboundApiCall.Id);
	 * ```
	 */
	global static ApiCall__c newInboundApiCall(String serviceName)
	{
		Map<SObjectField, Object> inboundOverrides = new Map<SObjectField, Object>
		{
				ApiCall__c.Request__c => System.RestContext.request?.requestBody?.toString() ?? UTIL_String.EMPTY,
				ApiCall__c.ServiceName__c => serviceName,
				ApiCall__c.Status__c => SEL_ApiCall.STATUS_COMPLETED,
				ApiCall__c.Direction__c => SEL_ApiCall.TYPE_INBOUND
		};

		return (ApiCall__c)getApiCallBuilder()
				.withOverrides(inboundOverrides)
				.withoutInsertion()
				.build();
	}

	/**
	 * @description Creates an uncommitted ApiCall__c record for an outbound web service call.
	 *
	 * @param serviceName The name of the web service class.
	 *
	 * @return An uncommitted ApiCall__c record.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * ApiCall__c outboundApiCall = TST_Factory.newOutboundApiCall('OutboundService');
	 * insert outboundApiCall;
	 * System.debug('Outbound API Call Id: ' + outboundApiCall.Id);
	 * ```
	 */
	global static ApiCall__c newOutboundApiCall(String serviceName)
	{
		Map<SObjectField, Object> outboundOverrides = new Map<SObjectField, Object>
		{
				ApiCall__c.ServiceName__c => serviceName,
				ApiCall__c.Direction__c => SEL_ApiCall.TYPE_OUTBOUND
		};

		return (ApiCall__c)getApiCallBuilder()
				.withOverrides(outboundOverrides)
				.withoutInsertion()
				.build();
	}

	/**
	 * @description Creates an uncommitted ApiCall__c record for an outbound web service call with a triggering object.
	 *
	 * @param serviceName The name of the web service class.
	 * @param recordId The Id of the object triggering the service.
	 *
	 * @return An uncommitted ApiCall__c record.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * Account acc = TST_Factory.newAccount();
	 * insert acc;
	 * ApiCall__c apiCall = TST_Factory.newOutboundApiCall('OutboundService', acc.Id);
	 * insert apiCall;
	 * System.debug('API Call Id: ' + apiCall.Id);
	 * ```
	 */
	global static ApiCall__c newOutboundApiCall(String serviceName, Id recordId)
	{
		Map<SObjectField, Object> outboundOverrides = new Map<SObjectField, Object>
		{
				ApiCall__c.ServiceName__c => serviceName,
				ApiCall__c.TriggeringRecordId__c => recordId,
				ApiCall__c.Direction__c => SEL_ApiCall.TYPE_OUTBOUND
		};

		return (ApiCall__c)getApiCallBuilder()
				.withOverrides(outboundOverrides)
				.withoutInsertion()
				.build();
	}

	/**
	 * @description Creates an uncommitted ApiCall__c record for an outbound web service call with parameters.
	 *
	 * @param serviceName The name of the web service class.
	 * @param recordId The Id of the object triggering the service.
	 * @param requestParameters A map of name-value pairs for request parameters.
	 *
	 * @return An uncommitted ApiCall__c record.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * Account acc = TST_Factory.newAccount();
	 * insert acc;
	 * Map<String, String> params = new Map<String, String>
	 * {
	 *     'key' => 'value'
	 * };
	 * ApiCall__c apiCall = TST_Factory.newOutboundApiCall('OutboundService', acc.Id, params);
	 * insert apiCall;
	 * System.debug('API Call Id: ' + apiCall.Id);
	 * ```
	 */
	global static ApiCall__c newOutboundApiCall(String serviceName, Id recordId, Map<String, String> requestParameters)
	{
		DTO_NameValues dtoNameValues = new DTO_NameValues(requestParameters);
		String requestParams = dtoNameValues.isEmpty() ? null : dtoNameValues.serialize();

		Map<SObjectField, Object> outboundOverrides = new Map<SObjectField, Object>
		{
				ApiCall__c.RequestParameters__c => requestParams,
				ApiCall__c.ServiceName__c => serviceName,
				ApiCall__c.TriggeringRecordId__c => recordId,
				ApiCall__c.Direction__c => SEL_ApiCall.TYPE_OUTBOUND
		};

		return (ApiCall__c)getApiCallBuilder()
				.withOverrides(outboundOverrides)
				.withoutInsertion()
				.build();
	}

	/**
	 * @description Creates an uncommitted ApiCall__c record for an outbound web service call with a single parameter.
	 *
	 * @param serviceName The name of the web service class.
	 * @param recordId The Id of the object triggering the service.
	 * @param parameterName The name of the additional parameter.
	 * @param parameterValue The value of the additional parameter.
	 *
	 * @return An uncommitted ApiCall__c record.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * Account acc = TST_Factory.newAccount();
	 * insert acc;
	 * ApiCall__c apiCall = TST_Factory.newOutboundApiCall('OutboundService', acc.Id, 'key', 'value');
	 * insert apiCall;
	 * System.debug('API Call Id: ' + apiCall.Id);
	 * ```
	 */
	global static ApiCall__c newOutboundApiCall(String serviceName, Id recordId, String parameterName, String parameterValue)
	{
		return newOutboundApiCall(serviceName, recordId, new Map<String, String>
		{
				parameterName => parameterValue
		});
	}

	/**
	 * @description Creates a mock outbound ApiSetting__mdt record via TST_Mock for query interception.
	 * The setting defaults to active and Outbound direction; overrides can replace any field value
	 * including IsActive__c. Pass null when no overrides are needed.
	 *
	 * @param className The fully qualified name of the outbound API handler class
	 * @param overrides Additional field values to apply on top of the defaults (may be null)
	 *
	 * @return A mock ApiSetting__mdt record
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * ApiSetting__mdt setting = TST_Factory.newOutboundApiSetting('API_SendEmail', null);
	 * ```
	 */
	global static ApiSetting__mdt newOutboundApiSetting(String className, Map<SObjectField, Object> overrides)
	{
		return newApiSetting(className, SEL_ApiSetting.DIRECTION_OUTBOUND, overrides);
	}

	/**
	 * @description Creates a mock inbound ApiSetting__mdt record via TST_Mock for test routing.
	 * The setting is registered in the mock cache and will be returned by SEL_ApiSetting queries.
	 *
	 * @param className The fully qualified name of the inbound API handler class
	 * @param endpointPath The URL path pattern for routing (e.g., '/echo/*')
	 *
	 * @return A mock ApiSetting__mdt record
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * ApiSetting__mdt setting = TST_Factory.newInboundApiSetting('API_Echo', '/echo/*');
	 * ```
	 */
	global static ApiSetting__mdt newInboundApiSetting(String className, String endpointPath)
	{
		return newInboundApiSetting(className, endpointPath, 100);
	}

	/**
	 * @description Creates a mock inbound ApiSetting__mdt record with a custom priority, registered
	 * with TST_Mock for query interception.
	 *
	 * @param className The API handler class name
	 * @param endpointPath The URL path pattern for routing (e.g., '/echo/*')
	 * @param priority The routing priority (lower number wins when paths are equal)
	 *
	 * @return A mock ApiSetting__mdt record
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * ApiSetting__mdt setting = TST_Factory.newInboundApiSetting('API_Echo', '/echo/*', 50);
	 * ```
	 */
	global static ApiSetting__mdt newInboundApiSetting(String className, String endpointPath, Integer priority)
	{
		return newInboundApiSetting(className, endpointPath, priority, null);
	}

	/**
	 * @description Creates a mock inbound ApiSetting__mdt record with a custom priority and additional
	 * field overrides, registered with TST_Mock for query interception.
	 *
	 * @param className The API handler class name
	 * @param endpointPath The URL path pattern for routing (e.g., '/echo/*')
	 * @param priority The routing priority (lower number wins when paths are equal)
	 * @param overrides Additional field values to apply on top of the defaults (may be null)
	 *
	 * @return A mock ApiSetting__mdt record
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * ApiSetting__mdt setting = TST_Factory.newInboundApiSetting('API_Echo', '/echo/*', 100, new Map<SObjectField, Object>
	 * {
	 *     ApiSetting__mdt.MockingEnabled__c => true
	 * });
	 * ```
	 */
	global static ApiSetting__mdt newInboundApiSetting(String className, String endpointPath, Integer priority, Map<SObjectField, Object> overrides)
	{
		Map<SObjectField, Object> inboundDefaults = new Map<SObjectField, Object>
		{
				ApiSetting__mdt.EndpointPath__c => endpointPath,
				ApiSetting__mdt.Priority__c => priority
		};

		if(overrides != null)
		{
			inboundDefaults.putAll(overrides);
		}

		return newApiSetting(className, SEL_ApiSetting.DIRECTION_INBOUND, inboundDefaults);
	}

	/**
	 * @description Creates a mock ApiSetting__mdt record with common defaults (ClassName, Direction, IsActive)
	 * and optional field overrides, registered with TST_Mock for query interception.
	 *
	 * @param className The API handler class name
	 * @param direction The API direction (use SEL_ApiSetting.DIRECTION_OUTBOUND or DIRECTION_INBOUND)
	 * @param overrides Additional field values to apply on top of the defaults (may be null)
	 *
	 * @return A mock ApiSetting__mdt record
	 */
	private static ApiSetting__mdt newApiSetting(String className, String direction, Map<SObjectField, Object> overrides)
	{
		return (ApiSetting__mdt)TST_Mock.of(ApiSetting__mdt.SObjectType)
				.withOverride(ApiSetting__mdt.ClassName__c, className)
				.withOverride(ApiSetting__mdt.Direction__c, direction)
				.withOverride(ApiSetting__mdt.IsActive__c, true)
				.withOverrides(overrides)
				.build();
	}

	/**
	 * @description Creates a mock ApiMock__mdt record via TST_Mock for query interception.
	 * The mock defaults to active with priority 100, status 200, and no pattern (catch-all).
	 * Overrides can replace any field value including IsActive__c and Priority__c.
	 *
	 * @param overrides Additional field values to apply on top of the defaults (may be null)
	 *
	 * @return A mock ApiMock__mdt record
	 *
	 * @example
	 * ```apex
	 * TST_Factory.newApiMock(new Map<SObjectField, Object>
	 * {
	 *     ApiMock__mdt.Priority__c => 10,
	 *     ApiMock__mdt.MatchRequestBodyPattern__c => 'urgent',
	 *     ApiMock__mdt.StatusCode__c => 201,
	 *     ApiMock__mdt.ResponseBody__c => '{"mock":"urgent"}'
	 * });
	 * ```
	 */
	@TestVisible
	private static ApiMock__mdt newApiMock(Map<SObjectField, Object> overrides)
	{
		TST_Mock.MockBuilder builder = TST_Mock.of(ApiMock__mdt.SObjectType)
				.withOverride(ApiMock__mdt.IsActive__c, true)
				.withOverride(ApiMock__mdt.Priority__c, 100)
				.withOverride(ApiMock__mdt.StatusCode__c, 200)
				.withOverride(ApiMock__mdt.IsRegex__c, false);

		if(overrides != null)
		{
			builder = builder.withOverrides(overrides);
		}

		return (ApiMock__mdt)builder.build();
	}

	/**
	 * @description Activates a feature flag for testing by injecting it into the selector cache.
	 * `UTIL_FeatureFlag.isEnabled(flagName)` will return `true` after this call.
	 *
	 * @param flagName The developer name of the feature flag to activate.
	 *
	 * @return The activated FeatureFlag__mdt record.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * TST_Factory.newFeatureFlag('MyFeatureFlag');
	 * ```
	 */
	global static FeatureFlag__mdt newFeatureFlag(String flagName)
	{
		return newFeatureFlag(flagName, true);
	}

	/**
	 * @description Builds an in-memory `FeatureFlag__mdt` record for `flagName`, optionally
	 * registering it in `SEL_FeatureFlag.activeFlags` with `IsEnabledByDefault__c = true`.
	 * When `registerAsActive = false`, the returned record can be used to populate a
	 * `MetadataRelationship` lookup field (e.g., `ValidationRule__mdt.BypassFeatureFlag__c`)
	 * without affecting `UTIL_FeatureFlag.isEnabled` evaluations elsewhere in the transaction.
	 *
	 * @param flagName The developer name of the feature flag.
	 * @param registerAsActive When true, puts the record into `SEL_FeatureFlag.activeFlags` so
	 *        `UTIL_FeatureFlag.isEnabled(flagName)` returns true; when false, the record is
	 *        returned without registration.
	 *
	 * @return The FeatureFlag__mdt record (registered when `registerAsActive = true`).
	 */
	@TestVisible
	private static FeatureFlag__mdt newFeatureFlag(String flagName, Boolean registerAsActive)
	{
		return newFeatureFlag(flagName, registerAsActive, true);
	}

	/**
	 * @description Builds an in-memory `FeatureFlag__mdt` record for `flagName` with explicit
	 * registration and enabled-state control. Register+disabled is the combination tests use
	 * to explicitly override a subscriber-shipped flag's default (e.g., to assert "when flag X
	 * is disabled" behaviour regardless of the CMDT record's `IsEnabledByDefault__c` value).
	 *
	 * @param flagName The developer name of the feature flag.
	 * @param registerAsActive When true, puts the record into `SEL_FeatureFlag.activeFlags`.
	 * @param isEnabled The `IsEnabledByDefault__c` value to stamp on the record. When this record
	 *        is registered, `UTIL_FeatureFlag.isEnabled(flagName)` returns this value (assuming
	 *        no strategies are attached).
	 *
	 * @return The FeatureFlag__mdt record (registered when `registerAsActive = true`).
	 */
	@TestVisible
	private static FeatureFlag__mdt newFeatureFlag(String flagName, Boolean registerAsActive, Boolean isEnabled)
	{
		FeatureFlag__mdt flag = (FeatureFlag__mdt)TST_Builder.of(FeatureFlag__mdt.SObjectType)
				.withOverride(FeatureFlag__mdt.DeveloperName, flagName)
				.withOverride(FeatureFlag__mdt.IsActive__c, true)
				.withOverride(FeatureFlag__mdt.IsEnabledByDefault__c, isEnabled)
				.withoutInsertion(true)
				.build();
		if(registerAsActive)
		{
			SEL_FeatureFlag.activeFlags.put(flagName, flag);
		}
		return flag;
	}

	/**
	 * @description Creates and inserts a list of Foobar__c records with initialized fields.
	 * Uses TST_Builder for record creation and insertion.
	 *
	 * @param numberOfItems The number of Foobar__c records to create.
	 *
	 * @return A list of committed Foobar__c records.
	 *
	 * @example
	 * ```apex
	 * List<Foobar__c> foobars = TST_Factory.insertFoobars(3);
	 * System.debug('Created ' + foobars.size() + ' Foobars');
	 * ```
	 */
	public static List<Foobar__c> insertFoobars(Integer numberOfItems)
	{
		return getFoobarBuilder()
				.withCount(numberOfItems)
				.buildList();
	}

	/**
	 * @description Creates a list of uncommitted Foobar__c records with initialized fields.
	 * Uses TST_Builder for record creation in memory.
	 *
	 * @param numberOfItems The number of Foobar__c records to create.
	 *
	 * @return A list of uncommitted Foobar__c records.
	 *
	 * @example
	 * ```apex
	 * List<Foobar__c> foobars = TST_Factory.newFoobars(3);
	 * insert foobars;
	 * System.debug('Created ' + foobars.size() + ' Foobars');
	 * ```
	 */
	public static List<Foobar__c> newFoobars(Integer numberOfItems)
	{
		return getFoobarBuilder()
				.withCount(numberOfItems)
				.withoutInsertion()
				.buildList();
	}

	/**
	 * @description Creates and inserts a single Foobar__c record with initialized fields.
	 * Uses TST_Builder for record creation and insertion.
	 *
	 * @return A committed Foobar__c record.
	 *
	 * @example
	 * ```apex
	 * Foobar__c foobar = TST_Factory.insertFoobar();
	 * System.debug('Foobar Name: ' + foobar.Name);
	 * ```
	 */
	public static Foobar__c insertFoobar()
	{
		return (Foobar__c)getFoobarBuilder().build();
	}

	/**
	 * @description Creates an uncommitted Foobar__c record with random field values.
	 * Uses TST_Builder for record creation in memory.
	 *
	 * @return An uncommitted Foobar__c record.
	 *
	 * @example
	 * ```apex
	 * Foobar__c foobar = TST_Factory.newFoobar();
	 * insert foobar;
	 * System.debug('Foobar Name: ' + foobar.Name);
	 * ```
	 */
	public static Foobar__c newFoobar()
	{
		return (Foobar__c)getFoobarBuilder().withoutInsertion().build();
	}

	/**
	 * @description Creates an uncommitted Foobar__c record with a generated mock ID.
	 * Use this when you need a record with an ID for query mocking scenarios
	 * without performing DML operations.
	 *
	 * @return An uncommitted Foobar__c record with a generated mock ID.
	 *
	 * @example
	 * ```apex
	 * Foobar__c foobar = TST_Factory.newFoobarWithMockId();
	 * System.debug('Foobar Id: ' + foobar.Id); // Mock ID generated
	 * QRY_Builder.setMock(Foobar__c.SObjectType, new List<Foobar__c>{foobar});
	 * ```
	 */
	public static Foobar__c newFoobarWithMockId()
	{
		return (Foobar__c)getFoobarBuilder().withoutInsertion(true).build();
	}

	/**
	 * @description Creates an uncommitted Foobar__c record with a specific name.
	 *
	 * @param name The name to assign to the Foobar record.
	 *
	 * @return An uncommitted Foobar__c record with the specified name.
	 *
	 * @example
	 * ```apex
	 * Foobar__c foobar = TST_Factory.newFoobarWithName('Parent Record');
	 * System.debug('Foobar Name: ' + foobar.Name);
	 * ```
	 */
	public static Foobar__c newFoobarWithName(String name)
	{
		return (Foobar__c)getFoobarBuilder()
				.withOverride(Foobar__c.Name, name)
				.withoutInsertion()
				.build();
	}

	/**
	 * @description Creates an uncommitted ContentVersion record with random data.
	 *
	 * @return An uncommitted ContentVersion record.
	 *
	 * @example
	 * ```apex
	 * ContentVersion version = TST_Factory.newContentVersion();
	 * insert version;
	 * System.debug('ContentVersion Title: ' + version.Title);
	 * ```
	 */
	@TestVisible
	private static ContentVersion newContentVersion()
	{
		return newContentVersion(null);
	}

	/**
	 * @description Creates an uncommitted ContentVersion record with a specified title.
	 *
	 * @param title The title of the content version, or random if blank.
	 *
	 * @return An uncommitted ContentVersion record.
	 *
	 * @example
	 * ```apex
	 * ContentVersion version = TST_Factory.newContentVersion('TestDocument');
	 * insert version;
	 * System.debug('ContentVersion Title: ' + version.Title);
	 * ```
	 */
	@TestVisible
	private static ContentVersion newContentVersion(String title)
	{
		return newContentVersion(null, String.isBlank(title) ? UTIL_Random.randomName() : title, Blob.valueOf(UTIL_Random.randomDescription()));
	}

	/**
	 * @description Publishes log events for testing purposes.
	 *
	 * @param numberOfItems The number of log events to publish.
	 *
	 * @example
	 * ```apex
	 * TST_Factory.publishLogEvents(5);
	 * ```
	 */
	@TestVisible
	private static void publishLogEvents(Integer numberOfItems)
	{
		for(Integer i = 0; i < numberOfItems; i++)
		{
			LOG_Builder.build().info(String.valueOf(i)).at(TST_Factory.class.getName() + '/publishLogEvents').emit();
		}
	}

	/**
	 * @description Creates an uncommitted share record for a specified object.
	 *
	 * @param dtoShareDescribe A DTO containing share object metadata.
	 * @param relatedRecordId The Id of the record to share.
	 * @param accessLevel The access level for the share (e.g., Read, Edit).
	 * @param userOrGroupId The Id of the user or group to grant access to.
	 *
	 * @return An uncommitted share SObject record.
	 *
	 * @example
	 * ```apex
	 * Account acc = TST_Factory.newAccount();
	 * insert acc;
	 * User user = TST_Factory.newUser('Standard User');
	 * insert user;
	 * SEL_ObjectShare.DTO_ObjectShareDescribe shareDescribe = SEL_ObjectShare.getShareDescribe(acc.Id);
	 * SObject share = TST_Factory.newSObjectShare(shareDescribe, acc.Id, 'Edit', user.Id);
	 * insert share;
	 * System.debug('Share Record Created');
	 * ```
	 */
	public static SObject newSObjectShare(SEL_ObjectShare.DTO_ObjectShareDescribe dtoShareDescribe, Id relatedRecordId, String accessLevel, Id userOrGroupId)
	{
		SObject shareObject = dtoShareDescribe.newShareObject();

		shareObject.put(SEL_ObjectShare.FIELD_ROW_CAUSE, SEL_ObjectShare.ROW_CAUSE_MANUAL);
		shareObject.put(SEL_ObjectShare.FIELD_USER_OR_GROUP_ID, userOrGroupId);
		shareObject.put(dtoShareDescribe.accessLevel, accessLevel);
		shareObject.put(dtoShareDescribe.parentIdFieldName, relatedRecordId);
		if(SEL_ObjectShare.OBJECT_ACCOUNT_SHARE.equalsIgnoreCase(dtoShareDescribe.shareObjectName))
		{
			shareObject.put(SEL_ObjectShare.FIELD_OPPORTUNITY_ACCESS_LEVEL, SEL_ObjectShare.ACCESS_LEVEL_NONE);
		}

		return shareObject;
	}

	/**
	 * @description Creates an uncommitted share record for a specified record.
	 *
	 * @param relatedRecordId The Id of the record to share.
	 * @param accessLevel The access level for the share (e.g., Read, Edit).
	 * @param userOrGroupId The Id of the user or group to grant access to.
	 *
	 * @return An uncommitted share SObject record.
	 *
	 * @example
	 * ```apex
	 * Account acc = TST_Factory.newAccount();
	 * insert acc;
	 * User user = TST_Factory.newUser('Standard User');
	 * insert user;
	 * SObject share = TST_Factory.newSObjectShare(acc.Id, 'Edit', user.Id);
	 * insert share;
	 * System.debug('Share Record Created');
	 * ```
	 */
	public static SObject newSObjectShare(Id relatedRecordId, String accessLevel, Id userOrGroupId)
	{
		return newSObjectShare(SEL_ObjectShare.getShareDescribe(relatedRecordId), relatedRecordId, accessLevel, userOrGroupId);
	}

	/**
	 * @description Creates PermissionSetAssignment records for a list of users and a permission set.
	 *
	 * @param users The list of users to assign the permission set to.
	 * @param permissionSetOrGroupName The name of the permission set.
	 *
	 * @throws AssertException If no permission set is found for the specified name.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * List<User> users = TST_Factory.newUsers('Standard User', 2);
	 * insert users;
	 * TST_Factory.createPermissionSetAssignments(users, 'CustomPermissionSet');
	 * System.debug('Permission Set Assignments Created');
	 * ```
	 */
	global static void createPermissionSetAssignments(List<User> users, String permissionSetOrGroupName)
	{
		PermissionSet foundPermissionSet = new SEL_PermissionSet().findByName(permissionSetOrGroupName);
		Assert.isNotNull(foundPermissionSet, 'No permission set found for the following name: ' + permissionSetOrGroupName);

		PermissionSetGroup foundGroup;

		if(Test.isRunningTest() && SEL_PermissionSet.GROUP_TYPE.equalsIgnoreCase(foundPermissionSet.Type))
		{
			foundGroup = new SEL_PermissionSetGroup().findByName(permissionSetOrGroupName);
		}

		createPermissionSetAssignments(users, foundGroup?.Id ?? foundPermissionSet.Id);
	}

	/**
	 * @description Creates PermissionSetAssignment records for a list of users and a permission set Id.
	 *
	 * @param users The list of users to assign the permission set to.
	 * @param permissionSetOrGroupId The Id of the permission set.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * List<User> users = TST_Factory.newUsers('Standard User', 2);
	 * insert users;
	 * PermissionSet permissionSet = [SELECT Id FROM PermissionSet WHERE Name = 'CustomPermissionSet' LIMIT 1];
	 * TST_Factory.createPermissionSetAssignments(users, permissionSet.Id);
	 * System.debug('Permission Set Assignments Created');
	 * ```
	 */
	global static void createPermissionSetAssignments(List<User> users, Id permissionSetOrGroupId)
	{
		SObjectType assignmentObjectType = UTIL_SObjectDescribe.getSObjectTypeById(permissionSetOrGroupId);

		for(User userRecord : users)
		{
			Map<SObjectField, Object> overrides = new Map<SObjectField, Object>
			{
					PermissionSetAssignment.AssigneeId => userRecord.Id
			};

			if(assignmentObjectType == PermissionSet.SObjectType)
			{
				overrides.put(PermissionSetAssignment.PermissionSetId, permissionSetOrGroupId);
			}
			else
			{
				overrides.put(PermissionSetAssignment.PermissionSetGroupId, permissionSetOrGroupId);
			}

			getPermissionSetAssignmentBuilder()
					.withOverrides(overrides)
					.build();
		}
	}

	/**
	 * @description Assigns the Administrator permission set to the current running user if not already assigned.
	 * Intended for SeeAllData=true tests where the running user needs record type visibility
	 * or elevated permissions provided by the package Administrator permission set.
	 */
	public static void assignAdministratorPermissionSet()
	{
		PermissionSet adminPermissionSet = new SEL_PermissionSet().findByName(SEL_PermissionSet.ADMIN_PERMISSION_SET_API_NAME);

		Boolean isAssigned = QRY_Builder.selectFrom(PermissionSetAssignment.SObjectType)
				.condition(PermissionSetAssignment.AssigneeId).equals(UserInfo.getUserId())
				.andCondition(PermissionSetAssignment.PermissionSetId).equals(adminPermissionSet.Id)
				.exists();

		if(!isAssigned)
		{
			createPermissionSetAssignments(new List<User> {new User(Id = UserInfo.getUserId())}, adminPermissionSet.Id);
		}
	}

	/**
	 * @description Creates a list of PROC_LoginFrequencyAggregator.DTO_LoginHistory records for testing login history processing.
	 *
	 * @return A list of uncommitted PROC_LoginFrequencyAggregator.DTO_LoginHistory records.
	 *
	 * @example
	 * ```apex
	 * List<PROC_LoginFrequencyAggregator.DTO_LoginHistory> loginHistories = TST_Factory.getDtoLoginHistories();
	 * System.debug('Created ' + loginHistories.size() + ' Login History DTOs');
	 * ```
	 */
	@TestVisible
	private static List<PROC_LoginFrequencyAggregator.DTO_LoginHistory> getDtoLoginHistories()
	{
		List<SObject> mockUsers = TST_Builder.of(User.SObjectType)
				.withCount(NUMBER_OF_MOCK_USERS_FOR_LOGIN_HISTORY)
				.withoutInsertion(true)
				.buildList();

		List<PROC_LoginFrequencyAggregator.DTO_LoginHistory> dtoLoginHistories = new List<PROC_LoginFrequencyAggregator.DTO_LoginHistory>();

		PROC_LoginFrequencyAggregator.DTO_LoginHistory loginHistory1 = new PROC_LoginFrequencyAggregator.DTO_LoginHistory();
		loginHistory1.userId = mockUsers[0].Id;
		loginHistory1.loginTime = UTIL_Date.dateTimeFromIso8601('2022-05-05T09:57:46.000+0000');
		dtoLoginHistories.add(loginHistory1);

		PROC_LoginFrequencyAggregator.DTO_LoginHistory loginHistory2 = new PROC_LoginFrequencyAggregator.DTO_LoginHistory();
		loginHistory2.userId = mockUsers[0].Id;
		loginHistory2.loginTime = UTIL_Date.dateTimeFromIso8601('2022-05-05T13:45:08.000+0000');
		dtoLoginHistories.add(loginHistory2);

		PROC_LoginFrequencyAggregator.DTO_LoginHistory loginHistory3 = new PROC_LoginFrequencyAggregator.DTO_LoginHistory();
		loginHistory3.userId = mockUsers[1].Id;
		loginHistory3.loginTime = UTIL_Date.dateTimeFromIso8601('2022-05-05T17:55:56.000+0000');
		dtoLoginHistories.add(loginHistory3);

		PROC_LoginFrequencyAggregator.DTO_LoginHistory loginHistory4 = new PROC_LoginFrequencyAggregator.DTO_LoginHistory();
		loginHistory4.userId = mockUsers[1].Id;
		loginHistory4.loginTime = UTIL_Date.dateTimeFromIso8601('2022-05-27T18:24:35.000+0000');
		dtoLoginHistories.add(loginHistory4);

		PROC_LoginFrequencyAggregator.DTO_LoginHistory loginHistory5 = new PROC_LoginFrequencyAggregator.DTO_LoginHistory();
		loginHistory5.userId = mockUsers[2].Id;
		loginHistory5.loginTime = UTIL_Date.dateTimeFromIso8601('2022-05-05T11:44:38.000+0000');
		dtoLoginHistories.add(loginHistory5);

		PROC_LoginFrequencyAggregator.DTO_LoginHistory loginHistory6 = new PROC_LoginFrequencyAggregator.DTO_LoginHistory();
		loginHistory6.userId = mockUsers[2].Id;
		loginHistory6.loginTime = UTIL_Date.dateTimeFromIso8601('2022-06-05T19:23:55.000+0000');
		dtoLoginHistories.add(loginHistory6);

		return dtoLoginHistories;
	}

	/**
	 * @description Creates and inserts LoginFrequency__c records with specified concatenated strings.
	 *
	 * @param numberOfRecords The number of records to create.
	 * @param concatenatedStrings A set of concatenated strings for the CompositeKey__c field.
	 *
	 * @return A list of committed LoginFrequency__c records.
	 *
	 * @example
	 * ```apex
	 * Set<String> strings = new Set<String>
	 * {
	 *     'user1_2022_05',
	 *     'user2_2022_06'
	 * };
	 * List<LoginFrequency__c> loginFrequencies = TST_Factory.createLoginFrequencyRecords(2, strings);
	 * System.debug('Created ' + loginFrequencies.size() + ' LoginFrequency Records');
	 * ```
	 */
	@TestVisible
	@SuppressWarnings('PMD.ApexCRUDViolation')
	private static List<LoginFrequency__c> createLoginFrequencyRecords(Integer numberOfRecords, Set<String> concatenatedStrings)
	{
		List<LoginFrequency__c> newLoginFrequencyRecords = new List<LoginFrequency__c>();
		Iterator<String> concatenatedString = concatenatedStrings.iterator();
		for(Integer i = 0; i < numberOfRecords; i++)
		{
			LoginFrequency__c loginFrequency = new LoginFrequency__c();

			loginFrequency.TotalLoginCount__c = UTIL_Random.randomDecimal(1, 0);
			loginFrequency.UniqueLoginCount__c = UTIL_Random.randomDecimal(1, 0);
			loginFrequency.CompositeKey__c = concatenatedString.next();

			newLoginFrequencyRecords.add(loginFrequency);
		}
		insert newLoginFrequencyRecords;
		return newLoginFrequencyRecords;
	}

	/**
	 * @description Creates and inserts an LogEntry__c record with random data.
	 *
	 * @return A committed LogEntry__c record.
	 *
	 * @example
	 * ```apex
	 * LogEntry__c logEntry = TST_Factory.insertLogEntry();
	 * System.debug('LogEntry Id: ' + logEntry.Id);
	 * ```
	 */
	@TestVisible
	private static LogEntry__c insertLogEntry()
	{
		return (LogEntry__c)getLogEntryBuilder().build();
	}

	/**
	 * @description Creates and inserts a ApiIssue__c record for a web service API call.
	 *
	 * @param apiCall The associated ApiCall__c record.
	 * @param itemHash A hash uniquely identifying the failure.
	 *
	 * @return A committed ApiIssue__c record.
	 *
	 * @example
	 * ```apex
	 * ApiCall__c apiCall = TST_Factory.newApiCall('TestService');
	 * insert apiCall;
	 * ApiIssue__c failure = TST_Factory.insertApiIssue(apiCall, 'uniqueHash');
	 * System.debug('ApiIssue Id: ' + failure.Id);
	 * ```
	 */
	@TestVisible
	private static ApiIssue__c insertApiIssue(ApiCall__c apiCall, String itemHash)
	{
		return (ApiIssue__c)getApiIssueBuilder(apiCall, itemHash)
				.build();
	}

	/**
	 * @description Creates an uncommitted ApiIssue__c record for a web service API call.
	 *
	 * @param apiCall The associated ApiCall__c record.
	 * @param itemHash A hash uniquely identifying the failure.
	 *
	 * @return An uncommitted ApiIssue__c record.
	 *
	 * @example
	 * ```apex
	 * ApiCall__c apiCall = TST_Factory.newApiCall('TestService');
	 * insert apiCall;
	 * ApiIssue__c failure = TST_Factory.newApiIssue(apiCall, 'uniqueHash');
	 * insert failure;
	 * System.debug('ApiIssue Id: ' + failure.Id);
	 * ```
	 */
	public static ApiIssue__c newApiIssue(ApiCall__c apiCall, String itemHash)
	{
		return (ApiIssue__c)getApiIssueBuilder(apiCall, itemHash)
				.withoutInsertion()
				.build();
	}

	/**
	 * @description Creates a list of FLOW_CheckObjectPermissions.DTO_Request records for checking object permissions.
	 *
	 * @param objectApiNames A list of object API names to check permissions for.
	 *
	 * @return A list of uncommitted FLOW_CheckObjectPermissions.DTO_Request records.
	 *
	 * @example
	 * ```apex
	 * List<String> apiNames = new List<String>
	 * {
	 *     'Account',
	 *     'Contact'
	 * };
	 * List<FLOW_CheckObjectPermissions.DTO_Request> requests = TST_Factory.createObjectPermissionCheckRequests(apiNames);
	 * ```
	 */
	@TestVisible
	private static List<FLOW_CheckObjectPermissions.DTO_Request> createObjectPermissionCheckRequests(List<String> objectApiNames)
	{
		List<FLOW_CheckObjectPermissions.DTO_Request> dtoRequests = new List<FLOW_CheckObjectPermissions.DTO_Request>();
		for(String objectApiName : objectApiNames)
		{
			FLOW_CheckObjectPermissions.DTO_Request dtoRequest = new FLOW_CheckObjectPermissions.DTO_Request();
			dtoRequest.objectApiName = objectApiName;
			dtoRequests.add(dtoRequest);
		}
		return dtoRequests;
	}

	/**
	 * @description Creates an uncommitted TriggerSetting__mdt record for testing.
	 *
	 * @param objectApiName The API name of the object this setting applies to
	 *
	 * @return An uncommitted TriggerSetting__mdt record
	 *
	 * @example
	 * ```apex
	 * TriggerSetting__mdt setting = TST_Factory.newTriggerSetting('Account');
	 * ```
	 */
	@TestVisible
	private static TriggerSetting__mdt newTriggerSetting(String objectApiName)
	{
		return newTriggerSetting(objectApiName, new Map<SObjectField, Object>());
	}

	/**
	 * @description Creates an uncommitted TriggerSetting__mdt record for testing with feature flag fields.
	 *
	 * @param objectApiName The API name of the object this setting applies to
	 * @param bypassPermission Optional bypass feature flag DeveloperName (null if not needed)
	 * @param requiredPermission Optional required feature flag DeveloperName (null if not needed)
	 *
	 * @return An uncommitted TriggerSetting__mdt record
	 *
	 * @example
	 * ```apex
	 * TriggerSetting__mdt setting = TST_Factory.newTriggerSetting('Account', 'Bypass_Account_Triggers', null);
	 * ```
	 */
	@TestVisible
	private static TriggerSetting__mdt newTriggerSetting(String objectApiName, String bypassPermission, String requiredPermission)
	{
		Map<SObjectField, Object> fieldOverrides = new Map<SObjectField, Object>();
		if(String.isNotBlank(bypassPermission))
		{
			fieldOverrides.put(TriggerSetting__mdt.BypassFeatureFlag__c, newFeatureFlag(bypassPermission, false));
		}
		if(String.isNotBlank(requiredPermission))
		{
			fieldOverrides.put(TriggerSetting__mdt.RequiredFeatureFlag__c, newFeatureFlag(requiredPermission, false));
		}
		return newTriggerSetting(objectApiName, fieldOverrides);
	}

	/**
	 * @description Creates an uncommitted TriggerSetting__mdt record for testing with additional field overrides.
	 * Base method that all other newTriggerSetting overloads delegate to.
	 *
	 * @param objectApiName The API name of the object this setting applies to
	 * @param fieldOverrides Map of additional field overrides to apply
	 *
	 * @return An uncommitted TriggerSetting__mdt record
	 *
	 * @example
	 * ```apex
	 * TriggerSetting__mdt setting = TST_Factory.newTriggerSetting('Account', new Map<SObjectField, Object>{
	 *     TriggerSetting__mdt.BypassFeatureFlag__c => TST_Factory.newFeatureFlag('Bypass_Account_Triggers'),
	 *     TriggerSetting__mdt.RequiredFeatureFlag__c => TST_Factory.newFeatureFlag('Required_Permission')
	 * });
	 * ```
	 */
	@TestVisible
	private static TriggerSetting__mdt newTriggerSetting(String objectApiName, Map<SObjectField, Object> fieldOverrides)
	{
		return (TriggerSetting__mdt)TST_Builder.of(TriggerSetting__mdt.SObjectType)
				.withOverride(TriggerSetting__mdt.SObjectType__c, objectApiName)
				.withOverrides(fieldOverrides)
				.withoutInsertion(true)
				.build();
	}

	/**
	 * @description Creates an uncommitted TriggerAction__mdt record for testing.
	 * The action is configured for Before Insert context by default.
	 *
	 * @param apexClassName The name of the Apex class that implements the trigger action
	 * @param triggerSetting The TriggerSetting__mdt record to associate with this action
	 *
	 * @return An uncommitted TriggerAction__mdt record
	 *
	 * @example
	 * ```apex
	 * TriggerSetting__mdt setting = TST_Factory.newTriggerSetting('Account');
	 * TriggerAction__mdt action = TST_Factory.newTriggerAction('TRG_AccountSetDefaults', setting);
	 * ```
	 */
	@TestVisible
	private static TriggerAction__mdt newTriggerAction(String apexClassName, TriggerSetting__mdt triggerSetting)
	{
		return newTriggerActionForContext(apexClassName, triggerSetting, TriggerOperation.BEFORE_INSERT);
	}

	/**
	 * @description Creates an uncommitted TriggerAction__mdt record for testing with feature flag fields.
	 * The action is configured for Before Insert context by default.
	 *
	 * @param apexClassName The name of the Apex class that implements the trigger action
	 * @param triggerSetting The TriggerSetting__mdt record to associate with this action
	 * @param bypassPermission Optional bypass feature flag DeveloperName
	 * @param requiredPermission Optional required feature flag DeveloperName
	 *
	 * @return An uncommitted TriggerAction__mdt record
	 *
	 * @example
	 * ```apex
	 * TriggerSetting__mdt setting = TST_Factory.newTriggerSetting('Account');
	 * TriggerAction__mdt action = TST_Factory.newTriggerAction('TRG_AccountSetDefaults', setting, 'Bypass_Set_Defaults', null);
	 * ```
	 */
	@TestVisible
	private static TriggerAction__mdt newTriggerAction(String apexClassName, TriggerSetting__mdt triggerSetting, String bypassPermission, String requiredPermission)
	{
		return newTriggerActionForContext(apexClassName, triggerSetting, TriggerOperation.BEFORE_INSERT, bypassPermission, requiredPermission);
	}

	/**
	 * @description Creates an uncommitted TriggerAction__mdt record for a specific trigger context.
	 * Use this when you need to specify the trigger context (before/after insert/update/delete/undelete).
	 *
	 * @param apexClassName The name of the Apex class that implements the trigger action
	 * @param triggerSetting The TriggerSetting__mdt record to associate with this action
	 * @param context The System.TriggerOperation enum value
	 *
	 * @return An uncommitted TriggerAction__mdt record
	 *
	 * @example
	 * ```apex
	 * TriggerSetting__mdt setting = TST_Factory.newTriggerSetting('Account');
	 * TriggerAction__mdt action = TST_Factory.newTriggerActionForContext('TRG_AccountAfterDelete', setting, TriggerOperation.AFTER_DELETE);
	 * ```
	 */
	@TestVisible
	private static TriggerAction__mdt newTriggerActionForContext(String apexClassName, TriggerSetting__mdt triggerSetting, TriggerOperation context)
	{
		return newTriggerActionForContext(apexClassName, triggerSetting, context, null, null);
	}

	/**
	 * @description Creates an uncommitted TriggerAction__mdt record for a specific trigger context with feature flag fields.
	 *
	 * @param apexClassName The name of the Apex class that implements the trigger action
	 * @param triggerSetting The TriggerSetting__mdt record to associate with this action
	 * @param context The System.TriggerOperation enum value
	 * @param bypassPermission Optional bypass feature flag DeveloperName
	 * @param requiredPermission Optional required feature flag DeveloperName
	 *
	 * @return An uncommitted TriggerAction__mdt record
	 */
	@TestVisible
	@SuppressWarnings('PMD.ExcessiveParameterList')
	private static TriggerAction__mdt newTriggerActionForContext
			(
					String apexClassName,
					TriggerSetting__mdt triggerSetting,
					TriggerOperation context,
					String bypassPermission,
					String requiredPermission
			)
	{
		TST_Builder.Builder builder = TST_Builder.of(TriggerAction__mdt.SObjectType)
				.withOverride(TriggerAction__mdt.TriggerSetting__c, triggerSetting)
				.withOverride(TriggerAction__mdt.ApexClassName__c, apexClassName)
				.withOverride(TriggerAction__mdt.AllowRecursion__c, true)
				.withOverride(TriggerAction__mdt.AllowNonSelfInitiated__c, true)
				.withOverride(TriggerAction__mdt.Order__c, 1)
				.withOverride(TriggerAction__mdt.BypassExecution__c, false)
				.withOverride(TriggerAction__mdt.DeveloperName, apexClassName)
				.withOverride(TriggerAction__mdt.Event__c, OPERATION_TO_EVENT.get(context));
		if(String.isNotBlank(bypassPermission))
		{
			builder = builder.withOverride(TriggerAction__mdt.BypassFeatureFlag__c, newFeatureFlag(bypassPermission, false));
		}
		if(String.isNotBlank(requiredPermission))
		{
			builder = builder.withOverride(TriggerAction__mdt.RequiredFeatureFlag__c, newFeatureFlag(requiredPermission, false));
		}
		return (TriggerAction__mdt)builder.withoutInsertion().build();
	}

	/**
	 * @description Creates a pre-configured SObjectBuilder for LogEntry__c.
	 *
	 * @return A TST_Builder.Builder instance.
	 */
	private static TST_Builder.Builder getLogEntryBuilder()
	{
		List<Object> fieldsToDefault = new List<Object>
		{
				LogEntry__c.ClassMethod__c
		};
		return TST_Builder.of(LogEntry__c.SObjectType)
				.withDefaultedFields(fieldsToDefault);
	}

	/**
	 * @description Creates a pre-configured SObjectBuilder for Foobar__c with
	 * common fields and record type.
	 *
	 * @return A TST_Builder.Builder instance.
	 */
	@TestVisible
	private static TST_Builder.Builder getFoobarBuilder()
	{
		List<Object> fieldsToDefault = new List<Object>
		{
				Foobar__c.Checkbox__c,
				Foobar__c.Datetime__c,
				Foobar__c.Email__c,
				Foobar__c.ExternalId__c,
				Foobar__c.Name,
				Foobar__c.NumberInteger__c,
				Foobar__c.Phone__c,
				Foobar__c.Picklist__c,
				Foobar__c.Text__c
		};

		return TST_Builder.of(Foobar__c.SObjectType)
				.withDefaultedFields(fieldsToDefault)
				.withRecordType(SEL_Foobar.RT_DEFAULT);
	}

	/**
	 * @description Creates a pre-configured SObjectBuilder for ScheduledJob__c.
	 *
	 * @return A TST_Builder.Builder instance.
	 */
	private static TST_Builder.Builder getScheduledJobBuilder()
	{
		List<Object> fieldsToDefault = new List<Object>
		{
				ScheduledJob__c.Description__c,
				ScheduledJob__c.SchedulerName__c
		};

		Map<SObjectField, Object> overrides = new Map<SObjectField, Object>
		{
				ScheduledJob__c.CronExpression__c => DEFAULT_CHRON_EXPRESSION
		};

		return TST_Builder.of(ScheduledJob__c.SObjectType)
				.withDefaultedFields(fieldsToDefault)
				.withOverrides(overrides);
	}

	/**
	 * @description Creates a pre-configured SObjectBuilder for PermissionSetAssignment.
	 *
	 * @return A TST_Builder.Builder instance.
	 */
	private static TST_Builder.Builder getPermissionSetAssignmentBuilder()
	{
		return TST_Builder.of(PermissionSetAssignment.SObjectType);
	}

	/**
	 * @description Creates a pre-configured SObjectBuilder for User.
	 *
	 * @param profileName The Name of the profile to assign to the user.
	 *
	 * @return A TST_Builder.Builder instance.
	 */
	private static TST_Builder.Builder getUserBuilder(String profileName)
	{
		final String emailSeparator = '@';
		Id profileId = new SEL_Profile().findByName(profileName)?.Id;

		// Create a unique base for email/username to avoid org-to-org collision
		String randomEmail = UTIL_Random.randomEmail().toLowerCase();

		String emailPrefix = randomEmail.substringBefore(emailSeparator);
		String emailSuffix = randomEmail.substringAfter(emailSeparator);

		// Create templates using [index] for uniqueness per record
		String emailTemplate = emailPrefix + UTIL_SObjectBuilderDefaultProvider.RECORD_INDEX_REPLACEMENT_TEXT + emailSeparator + emailSuffix;

		// These fields are required or must be set with specific values
		Map<SObjectField, Object> overrides = new Map<SObjectField, Object>
		{
				User.CompanyName => TEST_USER_MARKER,
				User.Email => emailTemplate,
				User.FederationIdentifier => emailTemplate,
				User.IsActive => true,
				User.ProfileId => profileId,
				User.Username => emailTemplate
		};

		return TST_Builder.of(User.SObjectType)
				.withOverrides(overrides);
	}

	/**
	 * @description Creates a pre-configured SObjectBuilder for ApiCall__c
	 * with common fields.
	 *
	 * @return A TST_Builder.Builder instance.
	 */
	@TestVisible
	private static TST_Builder.Builder getApiCallBuilder()
	{
		Map<SObjectField, Object> baseOverrides = new Map<SObjectField, Object>
		{
				ApiCall__c.Retries__c => 0,
				ApiCall__c.Status__c => SEL_ApiCall.STATUS_QUEUED,
				ApiCall__c.LoggerContext__c => captureLoggerContextForApiCall()
		};

		return TST_Builder.of(ApiCall__c.SObjectType)
				.withOverrides(baseOverrides);
	}

	/**
	 * @description Captures current logger context for transfer to async jobs.
	 * Auto-starts a correlation if none exists, ensuring every API call is traceable.
	 *
	 * @return String Serialized logger context JSON
	 */
	private static String captureLoggerContextForApiCall()
	{
		// Auto-start correlation if none exists
		// This ensures every API call has a correlation ID for tracing
		if(String.isBlank(LOG_Builder.correlationId))
		{
			LOG_Builder.startCorrelation();
		}

		return LOG_Builder.serializeContext();
	}

	/**
	 * @description Creates a pre-configured SObjectBuilder for ApiIssue__c.
	 *
	 * @param apiCall The associated ApiCall__c record.
	 * @param itemHash A hash uniquely identifying the failure.
	 *
	 * @return A TST_Builder.Builder instance.
	 */
	private static TST_Builder.Builder getApiIssueBuilder(ApiCall__c apiCall, String itemHash)
	{
		String errorMsg = String.isBlank(apiCall.ErrorMessages__c) ? apiCall.Response__c : apiCall.ErrorMessages__c;

		return TST_Builder.of(ApiIssue__c.SObjectType)
				.withOverride(ApiIssue__c.ErrorMessages__c, errorMsg)
				.withOverride(ApiIssue__c.RequestParametersHash__c, itemHash)
				.withOverride(ApiIssue__c.RequestParameters__c, apiCall.RequestParameters__c)
				.withOverride(ApiIssue__c.ServiceName__c, apiCall.ServiceName__c)
				.withOverride(ApiIssue__c.Status__c, SEL_ApiIssue.STATUS_OPEN)
				.withOverride(ApiIssue__c.TriggeringRecordId__c, apiCall.TriggeringRecordId__c)
				.withOverride(ApiIssue__c.ApiCall__c, apiCall.Id);
	}

	/**
	 * @description Creates an inserted AsyncChainExecution__c record with the given status and chain name.
	 *
	 * @param status The execution status value.
	 * @param chainName The chain name.
	 *
	 * @return The inserted AsyncChainExecution__c record.
	 *
	 * @example
	 * ```apex
	 * AsyncChainExecution__c execution = TST_Factory.newChainExecution('Running', 'MyChain');
	 * ```
	 */
	public static AsyncChainExecution__c newChainExecution(String status, String chainName)
	{
		return (AsyncChainExecution__c)TST_Builder.of(AsyncChainExecution__c.SObjectType)
				.withOverride(AsyncChainExecution__c.ChainName__c, chainName)
				.withOverride(AsyncChainExecution__c.Status__c, status)
				.withOverride(AsyncChainExecution__c.TotalSteps__c, 1)
				.withOverride(AsyncChainExecution__c.CompletedSteps__c, 0)
				.withOverride(AsyncChainExecution__c.CorrelationId__c, UTIL_Random.randomUUID())
				.build();
	}

	/**
	 * @description Creates an inserted AsyncChainExecution__c record with step log, timing, and step counts.
	 * Use this for tests that need to inspect parsed step data or verify duration computation.
	 *
	 * @param status The execution status value.
	 * @param chainName The chain name.
	 * @param stepLog The serialized StepLog JSON (from DTO_StepDefinition list).
	 * @param totalSteps Total number of steps defined in the chain.
	 * @param completedSteps Number of steps that completed successfully.
	 *
	 * @return The inserted AsyncChainExecution__c record.
	 *
	 * @example
	 * ```apex
	 * AsyncChainExecution__c execution = TST_Factory.newChainExecution('Completed', 'MyChain', stepLogJson, 3, 3);
	 * ```
	 */
	@SuppressWarnings('PMD.ExcessiveParameterList')
	public static AsyncChainExecution__c newChainExecution
			(
					String status,
					String chainName,
					String stepLog,
					Integer totalSteps,
					Integer completedSteps
			)
	{
		return (AsyncChainExecution__c)TST_Builder.of(AsyncChainExecution__c.SObjectType)
				.withOverride(AsyncChainExecution__c.ChainName__c, chainName)
				.withOverride(AsyncChainExecution__c.Status__c, status)
				.withOverride(AsyncChainExecution__c.StepLog__c, stepLog)
				.withOverride(AsyncChainExecution__c.TotalSteps__c, totalSteps)
				.withOverride(AsyncChainExecution__c.CompletedSteps__c, completedSteps)
				.withOverride(AsyncChainExecution__c.StartedAt__c, Datetime.now().addMinutes(-5))
				.withOverride(AsyncChainExecution__c.CorrelationId__c, UTIL_Random.randomUUID())
				.build();
	}

	/**
	 * @description Configures the logger for testing with default settings.
	 * Disables all performance logging by default for simple tests that just need
	 * the logger configured but don't need performance metrics.
	 *
	 * @example
	 * ```apex
	 * LOG_Builder.ignoreTestMode = true;
	 * TST_Factory.setupLoggerForTest();
	 * ```
	 */
	public static void setupLoggerForTest()
	{
		setupLoggerForTest(false, 0, false, 0, false, 500);
	}

	/**
	 * @description Configures the logger for testing with performance logging enabled.
	 * Sets both query and webservice logging to the same values.
	 *
	 * @param enablePerformanceLogging Whether performance logging is enabled
	 * @param performanceThresholdMs The threshold in milliseconds
	 *
	 * @example
	 * ```apex
	 * LOG_Builder.ignoreTestMode = true;
	 * TST_Factory.setupLoggerForTest(true, 0);
	 * ```
	 */
	@SuppressWarnings('PMD.AvoidBooleanMethodParameters')
	public static void setupLoggerForTest(Boolean enablePerformanceLogging, Integer performanceThresholdMs)
	{
		setupLoggerForTest(enablePerformanceLogging, performanceThresholdMs, enablePerformanceLogging, performanceThresholdMs);
	}

	/**
	 * @description Configures the logger for testing with separate query and webservice settings.
	 *
	 * @param enableQueryLogging Whether query performance logging is enabled
	 * @param queryThresholdMs The query threshold in milliseconds
	 * @param enableWebserviceLogging Whether webservice performance logging is enabled
	 * @param webserviceThresholdMs The webservice threshold in milliseconds
	 *
	 * @example
	 * ```apex
	 * LOG_Builder.ignoreTestMode = true;
	 * TST_Factory.setupLoggerForTest(true, 0, true, 10000);
	 * ```
	 */
	@SuppressWarnings('PMD.AvoidBooleanMethodParameters')
	public static void setupLoggerForTest
			(
					Boolean enableQueryLogging,
					Integer queryThresholdMs,
					Boolean enableWebserviceLogging,
					Integer webserviceThresholdMs
			)
	{
		setupLoggerForTest(enableQueryLogging, queryThresholdMs, enableWebserviceLogging, webserviceThresholdMs, false, 500);
	}

	/**
	 * @description Configures the logger for testing with query, webservice, and trigger settings.
	 *
	 * @param enableQueryLogging Whether query performance logging is enabled
	 * @param queryThresholdMs The query threshold in milliseconds
	 * @param enableWebserviceLogging Whether webservice performance logging is enabled
	 * @param webserviceThresholdMs The webservice threshold in milliseconds
	 * @param enableTriggerLogging Whether trigger performance logging is enabled
	 * @param triggerThresholdMs The trigger threshold in milliseconds
	 *
	 * @example
	 * ```apex
	 * LOG_Builder.ignoreTestMode = true;
	 * TST_Factory.setupLoggerForTest(true, 0, true, 100, true, 50);
	 * ```
	 */
	@SuppressWarnings('PMD.ExcessiveParameterList,PMD.AvoidBooleanMethodParameters')
	public static void setupLoggerForTest
			(
					Boolean enableQueryLogging,
					Integer queryThresholdMs,
					Boolean enableWebserviceLogging,
					Integer webserviceThresholdMs,
					Boolean enableTriggerLogging,
					Integer triggerThresholdMs
			)
	{
		setupLoggerForTest(enableQueryLogging, queryThresholdMs, enableWebserviceLogging, webserviceThresholdMs, enableTriggerLogging, triggerThresholdMs, false, 0);
	}

	/**
	 * @description Configures the logger for testing with full control over all performance settings.
	 * Includes query, webservice, trigger, and validation performance logging settings.
	 *
	 * @param enableQueryLogging Whether query performance logging is enabled
	 * @param queryThresholdMs The query threshold in milliseconds
	 * @param enableWebserviceLogging Whether webservice performance logging is enabled
	 * @param webserviceThresholdMs The webservice threshold in milliseconds
	 * @param enableTriggerLogging Whether trigger performance logging is enabled
	 * @param triggerThresholdMs The trigger threshold in milliseconds
	 * @param enableValidationLogging Whether validation performance logging is enabled
	 * @param validationThresholdMs The validation threshold in milliseconds
	 *
	 * @example
	 * ```apex
	 * LOG_Builder.ignoreTestMode = true;
	 * TST_Factory.setupLoggerForTest(true, 0, true, 100, true, 50, true, 100);
	 * ```
	 */
	@SuppressWarnings('PMD.ExcessiveParameterList,PMD.AvoidBooleanMethodParameters')
	public static void setupLoggerForTest
			(
					Boolean enableQueryLogging,
					Integer queryThresholdMs,
					Boolean enableWebserviceLogging,
					Integer webserviceThresholdMs,
					Boolean enableTriggerLogging,
					Integer triggerThresholdMs,
					Boolean enableValidationLogging,
					Integer validationThresholdMs
			)
	{
		LogSetting__c setting = new LogSetting__c();
		setting.IsEnabled__c = true;
		setting.LogLevelThreshold__c = 'DEBUG';
		setting.EnablePerformanceLogging__c = enableWebserviceLogging;
		setting.PerformanceThresholdMs__c = webserviceThresholdMs;
		setting.EnableQueryPerformanceLogging__c = enableQueryLogging;
		setting.QueryPerformanceThresholdMs__c = queryThresholdMs;
		setting.EnableTriggerPerformanceLogging__c = enableTriggerLogging;
		setting.TriggerPerformanceThresholdMs__c = triggerThresholdMs;
		setting.EnableValidationPerformanceLogging__c = enableValidationLogging;
		setting.ValidationPerformanceThresholdMs__c = validationThresholdMs;
		LOG_Engine.logSettingOverride = setting;
	}

	/**
	 * @description Creates an uncommitted ValidationRuleGroup__mdt with defaults.
	 * Defaults: Before Insert, auto-generated name, empty child rules.
	 *
	 * @param triggerSetting The TriggerSetting__mdt record to associate with this group
	 *
	 * @return An uncommitted ValidationRuleGroup__mdt record
	 *
	 * @example
	 * ```apex
	 * TriggerSetting__mdt setting = TST_Factory.newTriggerSetting(SEL_Foobar.OBJECT_NAME);
	 * ValidationRuleGroup__mdt ruleGroup = TST_Factory.newValidationRuleGroup(setting);
	 * ```
	 */
	@TestVisible
	private static ValidationRuleGroup__mdt newValidationRuleGroup(TriggerSetting__mdt triggerSetting)
	{
		return newValidationRuleGroup(triggerSetting, 'Before', 'Insert', new List<ValidationRule__mdt>());
	}

	/**
	 * @description Creates an uncommitted ValidationRuleGroup__mdt with child rules.
	 * Defaults: Before Insert, auto-generated name.
	 *
	 * @param triggerSetting The TriggerSetting__mdt record to associate with this group
	 * @param childRules List of ValidationRule__mdt records to include as children
	 *
	 * @return An uncommitted ValidationRuleGroup__mdt record with child rules
	 */
	@TestVisible
	private static ValidationRuleGroup__mdt newValidationRuleGroup
			(
					TriggerSetting__mdt triggerSetting,
					List<ValidationRule__mdt> childRules
			)
	{
		return newValidationRuleGroup(triggerSetting, 'Before', 'Insert', childRules);
	}

	/**
	 * @description Creates an uncommitted ValidationRuleGroup__mdt record for testing.
	 *
	 * @param triggerSetting The TriggerSetting__mdt record to associate with this group
	 * @param triggerTiming The trigger timing ('Before' or 'After', can be semicolon-separated)
	 * @param triggerOperations The trigger operations ('Insert', 'Update', etc., can be semicolon-separated)
	 * @param childRules List of ValidationRule__mdt records to include as children
	 *
	 * @return An uncommitted ValidationRuleGroup__mdt record with child rules
	 */
	@TestVisible
	private static ValidationRuleGroup__mdt newValidationRuleGroup
			(
					TriggerSetting__mdt triggerSetting,
					String triggerTiming,
					String triggerOperations,
					List<ValidationRule__mdt> childRules
			)
	{
		return newValidationRuleGroup(triggerSetting, triggerTiming, triggerOperations, childRules, null, null);
	}

	/**
	 * @description Creates an uncommitted ValidationRuleGroup__mdt record with feature flags.
	 *
	 * @param triggerSetting The TriggerSetting__mdt record to associate with this group
	 * @param triggerTiming The trigger timing
	 * @param triggerOperations The trigger operations
	 * @param childRules List of ValidationRule__mdt records
	 * @param requiredFeatureFlag Optional feature flag name required for this group
	 * @param bypassPermission Optional bypass permission name
	 *
	 * @return An uncommitted ValidationRuleGroup__mdt record
	 */
	@TestVisible
	@SuppressWarnings('PMD.ExcessiveParameterList')
	private static ValidationRuleGroup__mdt newValidationRuleGroup
			(
					TriggerSetting__mdt triggerSetting,
					String triggerTiming,
					String triggerOperations,
					List<ValidationRule__mdt> childRules,
					String requiredFeatureFlag,
					String bypassPermission
			)
	{
		TST_Builder.Builder builder = TST_Builder.of(ValidationRuleGroup__mdt.SObjectType)
				.withoutInsertion()
				.withOverride(SEL_ValidationRules.RELATIONSHIP_TRIGGER_SETTING, triggerSetting)
				.withOverride(ValidationRuleGroup__mdt.TriggerTiming__c, triggerTiming)
				.withOverride(ValidationRuleGroup__mdt.TriggerOperations__c, triggerOperations);

		if(String.isNotBlank(requiredFeatureFlag))
		{
			builder = builder.withOverride(ValidationRuleGroup__mdt.RequiredFeatureFlag__c, newFeatureFlag(requiredFeatureFlag, false));
		}
		if(String.isNotBlank(bypassPermission))
		{
			builder = builder.withOverride(ValidationRuleGroup__mdt.BypassFeatureFlag__c, newFeatureFlag(bypassPermission, false));
		}

		if(childRules != null && !childRules.isEmpty())
		{
			builder = builder.withOverride(SEL_ValidationRules.RELATIONSHIP_VALIDATION_RULES, childRules);
		}

		return (ValidationRuleGroup__mdt)builder.build();
	}

	/**
	 * @description Creates an uncommitted ValidationRuleGroup__mdt record with a context class.
	 * Convenience overload for the common case of just setting ContextClassName__c.
	 *
	 * @param triggerSetting The TriggerSetting__mdt record to associate with this group
	 * @param contextClassName The formula context class name (e.g., 'UTIL_FormulaContext.FoobarContext')
	 *
	 * @return An uncommitted ValidationRuleGroup__mdt record
	 *
	 * @example
	 * ```apex
	 * TriggerSetting__mdt setting = TST_Factory.newTriggerSetting(SEL_Foobar.OBJECT_NAME);
	 * ValidationRuleGroup__mdt ruleGroup = TST_Factory.newValidationRuleGroup(setting, UTIL_FormulaContext.FoobarContext.class.getName());
	 * ```
	 */
	@TestVisible
	private static ValidationRuleGroup__mdt newValidationRuleGroup(TriggerSetting__mdt triggerSetting, String contextClassName)
	{
		return newValidationRuleGroup
				(
						triggerSetting,
						new Map<SObjectField, Object>
						{
								ValidationRuleGroup__mdt.ContextClassName__c => contextClassName
						}
				);
	}

	/**
	 * @description Creates an uncommitted ValidationRuleGroup__mdt record with field overrides.
	 * Calls the base overload and then applies additional field overrides.
	 * Allows any field customization including ContextClassName__c.
	 *
	 * @param triggerSetting The TriggerSetting__mdt record to associate with this group
	 * @param fieldOverrides Map of additional fields to override from defaults
	 *
	 * @return An uncommitted ValidationRuleGroup__mdt record
	 *
	 * @example
	 * ```apex
	 * TriggerSetting__mdt setting = TST_Factory.newTriggerSetting(SEL_Foobar.OBJECT_NAME);
	 * ValidationRuleGroup__mdt ruleGroup = TST_Factory.newValidationRuleGroup(setting, new Map<SObjectField, Object>{
	 *     ValidationRuleGroup__mdt.ContextClassName__c => 'UTIL_FormulaContext.FoobarContext'
	 * });
	 * ```
	 */
	@TestVisible
	private static ValidationRuleGroup__mdt newValidationRuleGroup(TriggerSetting__mdt triggerSetting, Map<SObjectField, Object> fieldOverrides)
	{
		TST_Builder.Builder builder = TST_Builder.of(ValidationRuleGroup__mdt.SObjectType)
				.withoutInsertion()
				.withOverride(SEL_ValidationRules.RELATIONSHIP_TRIGGER_SETTING, triggerSetting)
				.withOverride(ValidationRuleGroup__mdt.TriggerTiming__c, 'Before')
				.withOverride(ValidationRuleGroup__mdt.TriggerOperations__c, 'Insert')
				.withOverrides(fieldOverrides);

		return (ValidationRuleGroup__mdt)builder.build();
	}

	/**
	 * @description Creates an uncommitted ValidationRule__mdt with auto-generated defaults.
	 *
	 * @return An uncommitted ValidationRule__mdt record
	 *
	 * @example
	 * ```apex
	 * ValidationRule__mdt rule = TST_Factory.newValidationRule();
	 * ```
	 */
	@TestVisible
	private static ValidationRule__mdt newValidationRule()
	{
		return (ValidationRule__mdt)TST_Builder.of(ValidationRule__mdt.SObjectType)
				.withoutInsertion()
				.withOverride(ValidationRule__mdt.Severity__c, UTIL_ValidationRule.SEVERITY_ERROR)
				.build();
	}

	/**
	 * @description Creates an uncommitted ValidationRule__mdt record with overrides.
	 *
	 * @param fieldOverrides Map of fields to override from defaults
	 *
	 * @return An uncommitted ValidationRule__mdt record
	 *
	 * @example
	 * ```apex
	 * ValidationRule__mdt rule = TST_Factory.newValidationRule(new Map<SObjectField, Object>{
	 *     ValidationRule__mdt.RuleFormula__c => 'ISBLANK(Email)',
	 *     ValidationRule__mdt.ErrorMessage__c => 'Email is required'
	 * });
	 * ```
	 */
	@TestVisible
	private static ValidationRule__mdt newValidationRule(Map<SObjectField, Object> fieldOverrides)
	{
		TST_Builder.Builder builder = TST_Builder.of(ValidationRule__mdt.SObjectType)
				.withoutInsertion()
				.withOverride(ValidationRule__mdt.Severity__c, UTIL_ValidationRule.SEVERITY_ERROR);

		for(SObjectField field : fieldOverrides.keySet())
		{
			builder = builder.withOverride(field, fieldOverrides.get(field));
		}

		return (ValidationRule__mdt)builder.build();
	}

	/**
	 * @description Creates an uncommitted ValidationRule__mdt record for testing.
	 *
	 * @param developerName The developer name for the rule
	 * @param ruleFormula The formula expression to evaluate
	 * @param errorMessage The error message to display when rule fails
	 *
	 * @return An uncommitted ValidationRule__mdt record
	 *
	 * @example
	 * ```apex
	 * ValidationRule__mdt rule = TST_Factory.newValidationRule('RequireEmail', 'ISBLANK(Email)', 'Email is required');
	 * ```
	 */
	@TestVisible
	private static ValidationRule__mdt newValidationRule(String developerName, String ruleFormula, String errorMessage)
	{
		return newValidationRule
				(
						new Map<SObjectField, Object>
						{
								ValidationRule__mdt.DeveloperName => developerName,
								ValidationRule__mdt.RuleFormula__c => ruleFormula,
								ValidationRule__mdt.ErrorMessage__c => errorMessage
						}
				);
	}

	/**
	 * @description Custom default value provider to handle User creation.
	 * It dynamically marks all 'UserPermissions...' fields as optional
	 * to prevent license-based field integrity exceptions during
	 * test data generation.
	 */
	private class UserBuilderOptionalFieldsProvider extends UTIL_SObjectBuilderDefaultProvider
	{
		/**
		 * @description Overrides the default optional fields definition.
		 *
		 * @param sObjectType The SObjectType to define optional fields for.
		 *
		 * @return A Set of SObjectField tokens to be treated as optional.
		 */
		public override Set<SObjectField> defineSObjectOptionalFields(SObjectType sObjectType)
		{
			Set<SObjectField> optionalFields = super.defineSObjectOptionalFields(sObjectType) ?? new Set<SObjectField>();

			if(sObjectType == User.SObjectType)
			{
				final String userPermissionPrefix = 'UserPermissions';

				Map<String, SObjectField> objectFieldMap = UTIL_SObjectDescribe.getDescribe(User.SObjectType).getFieldsMap();

				for(SObjectField objectField : objectFieldMap.values())
				{
					if(objectField.getDescribe().name.startsWithIgnoreCase(userPermissionPrefix))
					{
						optionalFields.add(objectField);
					}
				}

				return optionalFields;
			}

			return optionalFields;
		}
	}
}