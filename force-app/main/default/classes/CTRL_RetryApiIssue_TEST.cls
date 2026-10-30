// SPDX-License-Identifier: Apache-2.0
/**
 * @description Test Class for CTRL_RetryApiIssue. The class size and complexity warnings are turned off on purpose, as in
 * the other large test classes: the tests of the Retry, resolve, dismiss and replay actions share their helpers here.
 *
 * @see CTRL_RetryApiIssue
 *
 * @author Jason van Beukering
 *
 * @group Controllers
 *
 * @date February 2026, October 2026
 */
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs,PMD.CognitiveComplexity,PMD.CyclomaticComplexity,PMD.NcssCount,PMD.NcssTypeCount')
@IsTest(seeAllData=false isParallel=false)
public class CTRL_RetryApiIssue_TEST
{
	/**
	 * @description The inbound service class name used for routing.
	 */
	private static final String INBOUND_SERVICE_NAME = API_Echo.class.getName();
	/**
	 * @description Test request body payload.
	 */
	private static final String TEST_BODY = '{"hello":"world"}';
	/**
	 * @description Test request path matching the echo route pattern.
	 */
	private static final String TEST_PATH = '/echo/test';
	/**
	 * @description HTTP POST method constant.
	 */
	private static final String HTTP_POST = 'POST';
	/**
	 * @description How many days before the test an already Resolved issue was resolved, when a test dismisses it.
	 */
	private static final Integer DAYS_SINCE_EARLIER_RESOLUTION = 3;
	/**
	 * @description The route pattern of the inbound settings the tests register, so a request to the test path finds them.
	 */
	private static final String ROUTE_PATH = '/echo/*';
	/**
	 * @description The routing priority of the inbound settings the tests register.
	 */
	private static final Integer ROUTE_PRIORITY = 100;
	/**
	 * @description The test handler that records the request it receives.
	 */
	private static final String RECORDING_SERVICE_NAME = ReplayRecordingInbound.class.getName();
	/**
	 * @description The name of the query parameter each inbound test request carries.
	 */
	private static final String PARAMETER_NAME = 'reference';
	/**
	 * @description The value of the query parameter each inbound test request carries.
	 */
	private static final String PARAMETER_VALUE = 'order-42';
	/**
	 * @description The message of the failure the recording handler throws on the first request.
	 */
	private static final String HANDLER_FAILURE_MESSAGE = 'The handler failed on purpose';
	/**
	 * @description The exception the recording handler throws while it is set, or null to let the request succeed.
	 */
	private static Exception handlerFailure;
	/**
	 * @description The request the recording handler last received, or null when it did not run.
	 */
	private static RestRequest receivedRequest;
	/**
	 * @description The test outbound service that records the memory a run is using while it sends.
	 */
	private static final String MEMORY_RECORDING_SERVICE_NAME = MemoryRecordingOutbound.class.getName();
	/**
	 * @description The answer the test callout of the memory recording service gives.
	 */
	private static final String MOCK_RESPONSE_BODY = '{"body": "Some Random Body","id": 101,"title": "{{request.title}}","userId": 9}';
	/**
	 * @description The memory, in bytes, the run was using when the memory recording service sent its call, or null when
	 * it did not send.
	 */
	private static Integer heapUsedWhileSending;
	/**
	 * @description How many open issues the bulk retry test sends together.
	 */
	private static final Integer BULK_ISSUE_COUNT = 3;

	/**
	 * @description How many outbound issues of one request the memory test sends together. Their calls' requests and responses, read
	 * whole, would use more memory than one run may use.
	 */
	private static final Integer FULL_PAYLOAD_ISSUE_COUNT = 30;

	/**
	 * @description The character a full-length request or response is filled with.
	 */
	private static final String PAYLOAD_FILL_CHARACTER = 'x';

	/**
	 * @description The memory test allows the job at most this fraction (one part in this many) of the length of the
	 * calls' requests and responses together while it sends.
	 */
	private static final Integer PAYLOAD_SHARE_DIVISOR = 4;

	/**
	 * @description A job size an administrator could configure that is above the number of callouts one transaction may
	 * make, so the bulk retry must lower it.
	 */
	private static final Integer JOB_SIZE_ABOVE_CALLOUT_LIMIT = 150;

	/**
	 * @description Company name of the test user who holds the Kern API Issue Resolver permission set: a Standard User
	 * with nothing else from the package, so the tests prove what that permission set grants on its own.
	 */
	private static final String API_ISSUE_RESOLVER_USER_COMPANY = 'CTRL_RetryApiIssue_TEST-resolver';

	/**
	 * @description Company name of the test user who holds the Kern Administrator permission set: a Standard User with
	 * no other Kern permission set, so the tests prove that this set grants Retry too (an administrator keeps Retry
	 * after the upgrade).
	 */
	private static final String ADMINISTRATOR_PERMISSION_SET_USER_COMPANY = 'CTRL_RetryApiIssue_TEST-administrator';

	/**
	 * @description Company name of the user who holds no Kern permission set. A package install writes the Retry API
	 * Issue permission into the System Administrator profile, so the user has the Standard User profile, which the
	 * default install does not give the permission to.
	 */
	private static final String USER_WITHOUT_RETRY_PERMISSION_COMPANY = 'CTRL_RetryApiIssue_TEST-no-permission';

	/**
	 * @description Company name of the user who holds the Retry API Issue permission through a permission set the test
	 * builds, with no View All Records on API issues: a user an org could set up with its own permission set.
	 */
	private static final String RETRY_WITHOUT_VIEW_ALL_USER_COMPANY = 'CTRL_RetryApiIssue_TEST-retry-without-view-all';

	/**
	 * @description The API name of the permission set the test builds to grant only the Retry API Issue permission.
	 */
	private static final String RETRY_ONLY_PERMISSION_SET_NAME = 'RetryApiIssueWithoutViewAll';

	/**
	 * @description Creates four Standard Users: one who holds only the Kern API Issue Resolver permission set, one who
	 * holds only the Kern Administrator permission set, one who holds no Kern permission set, and one who holds the Retry
	 * API Issue permission through a permission set built here that grants nothing else. The builder fills no field of that
	 * set on its own, so none of its many system permissions is switched on at random. They are created in setup so that
	 * System.runAs checks their permissions afresh in each test.
	 */
	@TestSetup
	private static void setupUsers()
	{
		TST_Factory.newUserWithPermissionSet(SEL_Profile.PROFILE_STANDARD_USER, API_ISSUE_RESOLVER_USER_COMPANY, CTRL_RetryApiIssue.API_ISSUE_RESOLVER_PERMISSION_SET_NAME);
		TST_Factory.newUserWithPermissionSet(SEL_Profile.PROFILE_STANDARD_USER, ADMINISTRATOR_PERMISSION_SET_USER_COMPANY, SEL_PermissionSet.ADMIN_PERMISSION_SET_API_NAME);
		TST_Factory.insertUser(SEL_Profile.PROFILE_STANDARD_USER, USER_WITHOUT_RETRY_PERMISSION_COMPANY);

		PermissionSet retryOnlyPermissionSet = (PermissionSet)TST_Builder.of(PermissionSet.SObjectType)
				.withOptionalFields(new List<String>(UTIL_SObjectDescribe.getDescribe(PermissionSet.SObjectType).getCreatableRequiredFields()))
				.withOverride(PermissionSet.Name, RETRY_ONLY_PERMISSION_SET_NAME)
				.withOverride(PermissionSet.Label, RETRY_ONLY_PERMISSION_SET_NAME)
				.build();
		TST_Builder.of(SetupEntityAccess.SObjectType)
				.withOverride(SetupEntityAccess.ParentId, retryOnlyPermissionSet.Id)
				.withOverride(SetupEntityAccess.SetupEntityId, SEL_CustomPermission.getCustomPermissionId
						(
								CTRL_RetryApiIssue.RETRY_API_ISSUE_CUSTOM_PERMISSION_NAME,
								UTIL_System.getManagedPackageNamespace()
						))
				.build();
		User retryWithoutViewAllUser = TST_Factory.insertUser(SEL_Profile.PROFILE_STANDARD_USER, RETRY_WITHOUT_VIEW_ALL_USER_COMPANY);
		TST_Factory.createPermissionSetAssignments(new List<User> {retryWithoutViewAllUser}, retryOnlyPermissionSet.Id);
	}

	/**
	 * @description Finds the user who holds the Retry API Issue permission without View All Records on API issues.
	 *
	 * @return The user.
	 */
	private static User getUserWithRetryPermissionWithoutViewAll()
	{
		return new SEL_User().findByCompanyName(RETRY_WITHOUT_VIEW_ALL_USER_COMPANY);
	}

	/**
	 * @description Finds the test user who holds the Kern API Issue Resolver permission set.
	 *
	 * @return The Standard User holding only the Kern API Issue Resolver permission set.
	 */
	private static User getUserWithApiIssueResolverPermissionSet()
	{
		return new SEL_User().findByCompanyName(API_ISSUE_RESOLVER_USER_COMPANY);
	}

	/**
	 * @description Finds the test user who holds the Kern Administrator permission set.
	 *
	 * @return The Standard User holding only the Kern Administrator permission set.
	 */
	private static User getUserWithAdministratorPermissionSet()
	{
		return new SEL_User().findByCompanyName(ADMINISTRATOR_PERMISSION_SET_USER_COMPANY);
	}

	/**
	 * @description Finds the test user who holds no Kern permission set, and asserts that this user does not hold the
	 * Retry API Issue permission. When the package is installed for all users, the install gives the permission to
	 * every profile, so every user holds it. A refusal test in such an org would not be testing a user without the
	 * permission, and the assertion says so instead of changing the org's setup to take the permission away.
	 *
	 * @return The user without the permission, guaranteed to lack the permission.
	 */
	private static User getUserWithoutRetryPermission()
	{
		return assertLacksRetryPermission(new SEL_User().findByCompanyName(USER_WITHOUT_RETRY_PERMISSION_COMPANY));
	}

	/**
	 * @description Asserts that a user does not hold the Retry API Issue permission. When the package is installed for
	 * all users, the install gives the permission to every profile, so every user holds it. A refusal test in such an
	 * org would not be testing a user without the permission, and the assertion says so instead of changing the org's
	 * setup to take the permission away. The bulk retry tests use it too.
	 *
	 * @param user The user who must lack the permission
	 *
	 * @return The same user
	 */
	public static User assertLacksRetryPermission(User user)
	{
		Assert.isFalse
				(
						SEL_CustomPermission.hasPackagePermission(user.Id, CTRL_RetryApiIssue.RETRY_API_ISSUE_CUSTOM_PERMISSION_NAME),
						'This org grants ' + CTRL_RetryApiIssue.RETRY_API_ISSUE_CUSTOM_PERMISSION_NAME +
						' to the Standard User profile (an all-users package install), so no user without the permission exists to test the refusal against; ' +
						'run this suite in an org installed for admins only'
				);
		return user;
	}

	/**
	 * @description Creates an inbound issue made by hand: it links to no call and holds the request in its own fields, as
	 * an issue written before inbound issues linked to their call does. A replay sends the request from those fields to
	 * the echo service.
	 *
	 * @return The inserted ApiIssue__c record
	 */
	private static ApiIssue__c createInboundIssue()
	{
		return (ApiIssue__c)TST_Builder.of(ApiIssue__c.SObjectType)
				.withOverride(ApiIssue__c.Direction__c, SEL_ApiIssue.DIRECTION_INBOUND)
				.withOverride(ApiIssue__c.ServiceName__c, INBOUND_SERVICE_NAME)
				.withOverride(ApiIssue__c.Status__c, SEL_ApiIssue.STATUS_OPEN)
				.withOverride(ApiIssue__c.RequestPath__c, TEST_PATH)
				.withOverride(ApiIssue__c.RequestMethod__c, HTTP_POST)
				.withOverride(ApiIssue__c.RequestBody__c, TEST_BODY)
				.build();
	}

	/**
	 * @description Registers, through the test mock, the inbound setting of a service, routed to the echo path, with Log
	 * Issues and Retry Issues on and the switches that would change the outcome off, so no test depends on a setting
	 * the package ships.
	 *
	 * @param serviceName The handler class the setting names
	 * @param overrides The field values the setting gets on top of those
	 *
	 * @return The registered setting
	 */
	private static ApiSetting__mdt registerInboundSetting(String serviceName, Map<SObjectField, Object> overrides)
	{
		Map<SObjectField, Object> settingOverrides = new Map<SObjectField, Object>
		{
				ApiSetting__mdt.LogIssues__c => true,
				ApiSetting__mdt.RetryIssues__c => true,
				ApiSetting__mdt.ResolveIssues__c => false,
				ApiSetting__mdt.IdempotencyEnabled__c => false,
				ApiSetting__mdt.MockingEnabled__c => false
		};
		settingOverrides.putAll(overrides);
		return TST_Factory.newInboundApiSetting(serviceName, ROUTE_PATH, ROUTE_PRIORITY, settingOverrides);
	}

	/**
	 * @description Sets up a POST request to the echo path, with a body, one query parameter and, when given, an
	 * Idempotency-Key header.
	 *
	 * @param body The body to send
	 * @param idempotencyKey The key to send, or null to send none
	 */
	private static void setupInboundRequest(String body, String idempotencyKey)
	{
		API_InboundTestHelper.setupRestContext();
		RestContext.request.requestURI = TEST_PATH;
		RestContext.request.requestBody = Blob.valueOf(body);
		RestContext.request.addParameter(PARAMETER_NAME, PARAMETER_VALUE);
		if(String.isNotBlank(idempotencyKey))
		{
			RestContext.request.headers.put(API_Base.HEADER_IDEMPOTENCY_KEY, idempotencyKey);
		}
	}

	/**
	 * @description Sends a request to the echo endpoint that fails while it is handled, so the framework writes its
	 * failed call and one open inbound issue, as a live request does. The request context is then replaced with an
	 * unrelated empty request, so a replay must build its own request from the call.
	 *
	 * @param body The body to send
	 * @param idempotencyKey The key to send, or null to send none
	 *
	 * @return The open issue the failure wrote
	 */
	private static ApiIssue__c failEchoRequest(String body, String idempotencyKey)
	{
		setupInboundRequest(body, idempotencyKey);
		API_Inbound.returnErrorResponse = true;
		REST_Echo.echo();
		API_Inbound.returnErrorResponse = false;
		API_InboundTestHelper.setupRestContext();
		return findOnlyOpenIssue(INBOUND_SERVICE_NAME);
	}

	/**
	 * @description Sends a request to the test handler that records what it receives, while the handler fails with the
	 * given exception, so the framework writes the failed call and one open inbound issue. The request context is then
	 * replaced with an unrelated empty request, so a replay must build its own request from the call.
	 *
	 * @param body The body to send
	 * @param idempotencyKey The key to send, or null to send none
	 * @param failure The exception the handler throws
	 *
	 * @return The open issue the failure wrote
	 */
	private static ApiIssue__c failRecordedRequest(String body, String idempotencyKey, Exception failure)
	{
		setupInboundRequest(body, idempotencyKey);
		handlerFailure = failure;
		API_Dispatcher.processInboundService(RECORDING_SERVICE_NAME);
		handlerFailure = null;
		API_InboundTestHelper.setupRestContext();
		return findOnlyOpenIssue(RECORDING_SERVICE_NAME);
	}

	/**
	 * @description Finds the one open issue of a service, and asserts there is exactly one.
	 *
	 * @param serviceName The service
	 *
	 * @return The open issue
	 */
	private static ApiIssue__c findOnlyOpenIssue(String serviceName)
	{
		List<ApiIssue__c> openIssues = new SEL_ApiIssue().findUnresolvedByService(serviceName);
		Assert.areEqual(1, openIssues.size(), 'Expected one open issue for ' + serviceName + ', got ' + openIssues.size());
		return openIssues.get(0);
	}

	/**
	 * @description Finds the calls of a service other than the given one: the calls a retry or a replay made.
	 *
	 * @param serviceName The service
	 * @param originalCallId The call to leave out
	 *
	 * @return The other calls of the service
	 */
	private static List<ApiCall__c> findLaterCalls(String serviceName, Id originalCallId)
	{
		List<ApiCall__c> laterCalls = new List<ApiCall__c>();
		for(ApiCall__c apiCall : new SEL_ApiCall().findByServiceName(serviceName))
		{
			if(apiCall.Id != originalCallId)
			{
				laterCalls.add(apiCall);
			}
		}
		return laterCalls;
	}

	/**
	 * @description Changes one field of a saved record, for example a call the way masking or a cut would have changed it
	 * after it was saved, or an issue's status. Only that field is written.
	 *
	 * @param recordId The id of the saved record
	 * @param field The field to change
	 * @param value The new value
	 */
	@SuppressWarnings('PMD.KernSecurityBypassCallSite')
	private static void updateField(Id recordId, SObjectField field, Object value)
	{
		SObject changedRecord = recordId.getSobjectType().newSObject(recordId);
		changedRecord.put(field, value);
		DML_Builder.newTransaction().withSystemMode().doUpdate(changedRecord).execute();
	}

	/**
	 * @description Saves changes to an issue, as a user who closed it earlier would have.
	 *
	 * @param apiIssue The issue, with the changed field values
	 */
	@SuppressWarnings('PMD.KernSecurityBypassCallSite')
	private static void updateIssue(ApiIssue__c apiIssue)
	{
		DML_Builder.newTransaction().withSystemMode().doUpdate(apiIssue).execute();
	}

	/**
	 * @description Saves an outbound call that failed, so an issue can link to it.
	 *
	 * @param isPermanentFailure Whether the call is marked as a permanent failure
	 *
	 * @return The saved call
	 */
	@SuppressWarnings('PMD.KernSecurityBypassCallSite')
	private static ApiCall__c insertFailedOutboundCall(Boolean isPermanentFailure)
	{
		ApiCall__c apiCall = TST_Factory.newOutboundApiCall(API_PostExample.class.getName(), UserInfo.getUserId(), UTIL_Random.randomName(), UTIL_Random.randomName());
		apiCall.Status__c = SEL_ApiCall.STATUS_FAILED;
		apiCall.IsPermanentFailure__c = isPermanentFailure;
		DML_Builder.newTransaction().withSystemMode().doInsert(apiCall).execute();
		return apiCall;
	}

	/**
	 * @description Saves outbound calls of one request that failed, each with a request and a response at their fields'
	 * full length, and one open issue for each call. Each call has its own short error text, so its issue does not copy the response.
	 * The long texts are shared by every call and go out of use when this method returns.
	 *
	 * @param issueCount How many calls and issues to save
	 *
	 * @return The saved issues
	 */
	@SuppressWarnings('PMD.KernSecurityBypassCallSite')
	private static List<ApiIssue__c> insertOutboundIssuesWithFullLengthPayloads(Integer issueCount)
	{
		String fullLengthRequest = PAYLOAD_FILL_CHARACTER.repeat(SEL_ApiCall.REQUEST_LENGTH);
		String fullLengthResponse = PAYLOAD_FILL_CHARACTER.repeat(SEL_ApiCall.RESPONSE_LENGTH);
		List<ApiCall__c> apiCalls = new List<ApiCall__c>();
		for(Integer index = 0; index < issueCount; index++)
		{
			ApiCall__c apiCall = TST_Factory.newOutboundApiCall(MEMORY_RECORDING_SERVICE_NAME, UserInfo.getUserId(), PARAMETER_NAME, PARAMETER_VALUE);
			apiCall.Status__c = SEL_ApiCall.STATUS_FAILED;
			apiCall.ErrorMessages__c = HANDLER_FAILURE_MESSAGE;
			apiCall.Request__c = fullLengthRequest;
			apiCall.Response__c = fullLengthResponse;
			apiCalls.add(apiCall);
		}
		DML_Builder.newTransaction().withSystemMode().doInsert(apiCalls).execute();
		List<ApiIssue__c> issues = new List<ApiIssue__c>();
		for(ApiCall__c apiCall : apiCalls)
		{
			issues.add(TST_Factory.newApiIssue(apiCall, UTIL_Crypto.generateMD5Hash(apiCall.RequestParameters__c)));
		}
		DML_Builder.newTransaction().withSystemMode().doInsert(issues).execute();
		return issues;
	}

	/**
	 * @description Verifies that retrying a valid API issue succeeds and resolves the issue, as a Standard User holding only
	 * the Kern API Issue Resolver permission set, which is the access the set exists to grant.
	 *
	 * @see CTRL_RetryApiIssue.retry
	 */
	@IsTest
	private static void shouldRetrySuccessfully()
	{
		System.runAs(getUserWithApiIssueResolverPermissionSet())
		{
			ApiCall__c apiCall = TST_Factory.newOutboundApiCall(API_PostExample.class.getName(), UserInfo.getUserId(), UTIL_Random.randomName(), UTIL_Random.randomName());
			ApiIssue__c apiIssue =
					TST_Factory.insertApiIssue(apiCall, UTIL_Crypto.generateMD5Hash(apiCall.RequestParameters__c));

			Test.startTest();

			CTRL_RetryApiIssue.DTO_Response dtoResponse = CTRL_RetryApiIssue.retry(apiIssue.Id);

			Test.stopTest();

			Assert.isTrue(dtoResponse.callSuccessful, 'Retry API issue not successful as expected');

			ApiIssue__c updatedIssue = (ApiIssue__c)new SEL_ApiIssue().findById(apiIssue.Id);
			Assert.areEqual(SEL_ApiIssue.STATUS_RESOLVED, updatedIssue.Status__c, 'ApiIssue should be resolved after successful retry');
			Assert.isNotNull(updatedIssue.ResolvedDate__c, 'Expected the Retry action to set the resolved date');
		}
	}

	/**
	 * @description Verifies that retry fails when the retry setting is not enabled.
	 */
	@IsTest
	private static void shouldFailWhenRetrySettingNotEnabled()
	{
		System.runAs(getUserWithApiIssueResolverPermissionSet())
		{
			ApiCall__c apiCall = TST_Factory.newOutboundApiCall(API_GetPwndPasswords.class.getName(), UserInfo.getUserId(), UTIL_Random.randomName(), UTIL_Random.randomName());
			ApiIssue__c apiIssue =
					TST_Factory.insertApiIssue(apiCall, UTIL_Crypto.generateMD5Hash(apiCall.RequestParameters__c));

			Test.startTest();

			CTRL_RetryApiIssue.DTO_Response dtoResponse = CTRL_RetryApiIssue.retry(apiIssue.Id);

			Test.stopTest();

			Assert.isFalse(dtoResponse.callSuccessful, 'API issue retry did not fail as expected');
			Assert.areEqual(System.Label.RetryApiIssue_RetryNotEnabled, dtoResponse.errorMessage, 'Expected the refusal to come from the label');

			ApiIssue__c updatedIssue = (ApiIssue__c)new SEL_ApiIssue().findById(apiIssue.Id);
			Assert.areEqual(SEL_ApiIssue.STATUS_OPEN, updatedIssue.Status__c, 'ApiIssue should remain open when retry setting is not enabled');
		}
	}

	/**
	 * @description The Retry action makes the same check as Retry Selected and the bulk retry job. While the switch that
	 * disables every API is on, a service whose setting allows retries is paused. So Retry answers with the labelled
	 * message, sends no call, leaves the issue Open and logs no second issue for the same request.
	 */
	@IsTest
	private static void shouldRefuseRetryWhileEveryApiIsDisabled()
	{
		TST_Factory.newFeatureFlag(API_Base.FLAG_DISABLE_ALL_APIS);
		String serviceName = API_PostExample.class.getName();
		ApiCall__c apiCall = TST_Factory.newOutboundApiCall(serviceName, UserInfo.getUserId(), UTIL_Random.randomName(), UTIL_Random.randomName());
		ApiIssue__c apiIssue = TST_Factory.insertApiIssue(apiCall, UTIL_Crypto.generateMD5Hash(apiCall.RequestParameters__c));
		Integer callCountBefore = new SEL_ApiCall().findByServiceName(serviceName).size();
		CTRL_RetryApiIssue.DTO_Response dtoResponse;

		System.runAs(getUserWithApiIssueResolverPermissionSet())
		{
			Test.startTest();
			dtoResponse = CTRL_RetryApiIssue.retry(apiIssue.Id);
			Test.stopTest();
		}

		Assert.isFalse(dtoResponse.callSuccessful, 'Expected Retry to be refused while every API is disabled');
		Assert.areEqual(System.Label.RetryApiIssue_ServiceNotAcceptingRetries, dtoResponse.errorMessage, 'Expected the refusal to come from the label');
		Assert.areEqual(SEL_ApiIssue.STATUS_OPEN, ((ApiIssue__c)new SEL_ApiIssue().findById(apiIssue.Id)).Status__c, 'Expected the issue to stay Open');
		Assert.areEqual(callCountBefore, new SEL_ApiCall().findByServiceName(serviceName).size(), 'Expected no call to be sent');
		Assert.areEqual(1, new SEL_ApiIssue().findUnresolvedByService(serviceName).size(), 'Expected no second issue for the same request');
	}

	/**
	 * @description An issue whose service has no API setting cannot be retried, because Retry Issues can be turned on only
	 * in a setting. Retry answers with the labelled message that says so and leaves the issue Open.
	 */
	@IsTest
	private static void shouldRefuseRetryOfAnIssueWhoseServiceHasNoSetting()
	{
		ApiCall__c apiCall = TST_Factory.newOutboundApiCall(UTIL_Random.randomName(), UserInfo.getUserId(), UTIL_Random.randomName(), UTIL_Random.randomName());
		ApiIssue__c apiIssue = TST_Factory.insertApiIssue(apiCall, UTIL_Crypto.generateMD5Hash(apiCall.RequestParameters__c));
		CTRL_RetryApiIssue.DTO_Response dtoResponse;

		System.runAs(getUserWithApiIssueResolverPermissionSet())
		{
			Test.startTest();
			dtoResponse = CTRL_RetryApiIssue.retry(apiIssue.Id);
			Test.stopTest();
		}

		Assert.isFalse(dtoResponse.callSuccessful, 'Expected Retry to be refused for a service with no setting');
		Assert.areEqual(System.Label.RetryApiIssue_RetryNotEnabled, dtoResponse.errorMessage, 'Expected the refusal to come from the label');
		Assert.areEqual(SEL_ApiIssue.STATUS_OPEN, ((ApiIssue__c)new SEL_ApiIssue().findById(apiIssue.Id)).Status__c, 'Expected the issue to stay Open');
	}

	/**
	 * @description Verifies that retry reports an error when the underlying call fails.
	 */
	@IsTest
	private static void shouldReportErrorWhenRetryFails()
	{
		System.runAs(getUserWithApiIssueResolverPermissionSet())
		{
			ApiCall__c apiCall = TST_Factory.newOutboundApiCall
					(
							API_PostExample.class.getName(),
							null,
							UTIL_Random.randomName(),
							UTIL_Random.randomName()
					);
			ApiIssue__c apiIssue =
					TST_Factory.insertApiIssue(apiCall, UTIL_Crypto.generateMD5Hash(apiCall.RequestParameters__c));

			Test.startTest();

			CTRL_RetryApiIssue.DTO_Response dtoResponse = CTRL_RetryApiIssue.retry(apiIssue.Id);

			Test.stopTest();

			Assert.isFalse(dtoResponse.callSuccessful, 'Retry API issue retry did not fail as expected');

			ApiIssue__c updatedIssue = (ApiIssue__c)new SEL_ApiIssue().findById(apiIssue.Id);
			Assert.areEqual(SEL_ApiIssue.STATUS_OPEN, updatedIssue.Status__c, 'ApiIssue should remain open when retry fails');
		}
	}

	/**
	 * @description Verifies resolveFailure delegates to retry for outbound issues.
	 */
	@IsTest
	private static void shouldResolveOutboundFailureViaResolveAction()
	{
		System.runAs(getUserWithApiIssueResolverPermissionSet())
		{
			ApiCall__c apiCall = TST_Factory.newOutboundApiCall(API_PostExample.class.getName(), UserInfo.getUserId(), UTIL_Random.randomName(), UTIL_Random.randomName());
			ApiIssue__c apiIssue =
					TST_Factory.insertApiIssue(apiCall, UTIL_Crypto.generateMD5Hash(apiCall.RequestParameters__c));

			Test.startTest();

			CTRL_RetryApiIssue.DTO_Response dtoResponse = CTRL_RetryApiIssue.resolveFailure(apiIssue.Id);

			Test.stopTest();

			Assert.isTrue(dtoResponse.callSuccessful, 'Outbound resolve should succeed');

			ApiIssue__c updatedIssue = (ApiIssue__c)new SEL_ApiIssue().findById(apiIssue.Id);
			Assert.areEqual(SEL_ApiIssue.STATUS_RESOLVED, updatedIssue.Status__c, 'ApiIssue should be resolved');
			Assert.isNotNull(updatedIssue.ResolvedDate__c, 'Expected the resolve action to set the resolved date of an outbound issue');
		}
	}

	/**
	 * @description Verifies resolveFailure handles inbound replay successfully.
	 */
	@IsTest
	private static void shouldResolveInboundFailureViaResolveAction()
	{
		registerInboundSetting(INBOUND_SERVICE_NAME, new Map<SObjectField, Object>());
		ApiIssue__c apiIssue = createInboundIssue();
		CTRL_RetryApiIssue.DTO_Response dtoResponse;

		System.runAs(getUserWithApiIssueResolverPermissionSet())
		{
			Test.startTest();
			dtoResponse = CTRL_RetryApiIssue.resolveFailure(apiIssue.Id);
			Test.stopTest();
		}

		Assert.isTrue(dtoResponse.callSuccessful, 'Inbound resolve should succeed');

		ApiIssue__c updatedIssue = (ApiIssue__c)new SEL_ApiIssue().findById(apiIssue.Id);
		Assert.areEqual(SEL_ApiIssue.STATUS_RESOLVED, updatedIssue.Status__c, 'ApiIssue should be resolved after inbound replay');
		Assert.isNotNull(updatedIssue.ResolvedDate__c, 'ResolvedDate should be set');
	}

	/**
	 * @description Verifies resolveFailure reports errors when inbound replay fails.
	 */
	@IsTest
	private static void shouldReportInboundReplayFailure()
	{
		registerInboundSetting(INBOUND_SERVICE_NAME, new Map<SObjectField, Object>());
		ApiIssue__c apiIssue = createInboundIssue();
		API_InboundInvoker.forceException = true;
		CTRL_RetryApiIssue.DTO_Response dtoResponse;

		System.runAs(getUserWithApiIssueResolverPermissionSet())
		{
			Test.startTest();
			dtoResponse = CTRL_RetryApiIssue.resolveFailure(apiIssue.Id);
			Test.stopTest();
		}

		Assert.isFalse(dtoResponse.callSuccessful, 'Should report failure');
		Assert.isNotNull(dtoResponse.errorMessage, 'Should have error message');

		ApiIssue__c updatedIssue = (ApiIssue__c)new SEL_ApiIssue().findById(apiIssue.Id);
		Assert.areEqual(SEL_ApiIssue.STATUS_OPEN, updatedIssue.Status__c, 'ApiIssue should remain open when replay fails');
	}

	/**
	 * @description Verifies resolveFailure uses fallback message when inbound replay fails with blank error text.
	 * This occurs when the service the issue names has a setting but no handler class, so no handler runs and none
	 * reports an error.
	 */
	@SuppressWarnings('PMD.KernSecurityBypassCallSite')
	@IsTest
	private static void shouldUseFallbackMessageWhenReplayHasBlankErrorText()
	{
		String serviceWithoutHandler = UTIL_Random.randomName();
		registerInboundSetting(serviceWithoutHandler, new Map<SObjectField, Object>());
		ApiIssue__c apiIssue = createInboundIssue();
		apiIssue.ServiceName__c = serviceWithoutHandler;
		DML_Builder.newTransaction().withSystemMode().doUpdate(apiIssue).execute();
		CTRL_RetryApiIssue.DTO_Response dtoResponse;

		System.runAs(getUserWithApiIssueResolverPermissionSet())
		{
			Test.startTest();
			dtoResponse = CTRL_RetryApiIssue.resolveFailure(apiIssue.Id);
			Test.stopTest();
		}

		Assert.isFalse(dtoResponse.callSuccessful, 'Should report failure');
		Assert.areEqual(System.Label.RetryApiIssue_InboundReplayFailed, dtoResponse.errorMessage, 'Expected the fallback to come from the label');
	}

	/**
	 * @description A replay whose stored body starts like JSON but is not valid JSON fails and leaves the issue open. The replay
	 * sends a body that starts with { as JSON, so the handler tries to read it while it is created. That fails, the call is ended as Aborted with the reason, and the
	 * issue is not marked Resolved. No handler was created, so the user sees the general replay error and the reason is on the call.
	 */
	@SuppressWarnings('PMD.KernSecurityBypassCallSite')
	@IsTest
	private static void shouldLeaveTheIssueOpenWhenTheStoredBodyCannotBeRead()
	{
		registerInboundSetting(INBOUND_SERVICE_NAME, new Map<SObjectField, Object>());
		ApiIssue__c apiIssue = createInboundIssue();
		apiIssue.RequestBody__c = '{' + UTIL_Random.randomName();
		DML_Builder.newTransaction().withSystemMode().doUpdate(apiIssue).execute();
		CTRL_RetryApiIssue.DTO_Response dtoResponse;

		System.runAs(getUserWithApiIssueResolverPermissionSet())
		{
			Test.startTest();
			dtoResponse = CTRL_RetryApiIssue.resolveFailure(apiIssue.Id);
			Test.stopTest();
		}

		Assert.isFalse(dtoResponse.callSuccessful, 'Expected the replay of a body that starts like JSON but is not valid JSON to fail');
		Assert.areEqual(System.Label.RetryApiIssue_InboundReplayFailed, dtoResponse.errorMessage, 'Expected the failed replay to report the general error');
		ApiIssue__c updatedIssue = (ApiIssue__c)new SEL_ApiIssue().findById(apiIssue.Id);
		Assert.areEqual(SEL_ApiIssue.STATUS_OPEN, updatedIssue.Status__c, 'Expected the issue to stay open when its body cannot be read');
		Assert.isNull(updatedIssue.ResolvedDate__c, 'Expected no resolved date when the replay failed');
		List<ApiCall__c> abortedCalls = QRY_Builder.selectFrom(ApiCall__c.SObjectType)
				.fields(new List<SObjectField> {ApiCall__c.ErrorMessages__c})
				.condition(ApiCall__c.Status__c).equals(SEL_ApiCall.STATUS_ABORTED)
				.withSystemMode()
				.toList();
		Assert.areEqual(1, abortedCalls.size(), 'Expected the replayed call to end as Aborted, got ' + abortedCalls.size() + ' aborted calls');
		Assert.isTrue(String.isNotBlank(abortedCalls[0].ErrorMessages__c), 'Expected the aborted call to keep the reason it could not be read');
	}

	/**
	 * @description Verifies bulk retry reads the callout-safe job size from AsynchronousJobSetting__mdt
	 * and falls back to the default when no record is configured.
	 */
	@IsTest
	private static void shouldUseCalloutSafeJobSizeForBulkRetry()
	{
		Integer jobSize = SEL_AsynchronousJobSetting.getBatchSize(FLOW_CallApiAsync.class.getName(), FLOW_CallApiAsync.DEFAULT_JOB_SIZE);
		Assert.areEqual(FLOW_CallApiAsync.DEFAULT_JOB_SIZE, jobSize, 'Should fall back to default job size when no metadata record exists');
	}

	/**
	 * @description Verifies the bulk retry path caps the job size at MAXIMUM_CALLOUT_JOB_SIZE
	 * even when AsynchronousJobSetting__mdt is configured above the callout governor limit.
	 */
	@IsTest
	private static void shouldCapBulkRetryJobSizeAtCalloutLimit()
	{
		SEL_AsynchronousJobSetting.mockedSetting = (AsynchronousJobSetting__mdt)TST_Builder.of(AsynchronousJobSetting__mdt.SObjectType)
				.withOverride(AsynchronousJobSetting__mdt.BatchSize__c, JOB_SIZE_ABOVE_CALLOUT_LIMIT)
				.withoutInsertion()
				.build();

		Integer jobSize = Math.min(
				SEL_AsynchronousJobSetting.getBatchSize(FLOW_CallApiAsync.class.getName(), FLOW_CallApiAsync.DEFAULT_JOB_SIZE),
				FLOW_CallApiAsync.MAXIMUM_CALLOUT_JOB_SIZE
		);

		Assert.areEqual(FLOW_CallApiAsync.MAXIMUM_CALLOUT_JOB_SIZE, jobSize, 'Expected a job size above the callout limit to be capped at the limit');
	}

	/**
	 * @description Verifies scheduleBulkRetry returns null when no unresolved failures exist.
	 */
	@IsTest
	private static void shouldReturnNullWhenNoFailuresForBulkRetry()
	{
		Id jobId;

		System.runAs(getUserWithApiIssueResolverPermissionSet())
		{
			Test.startTest();
			jobId = CTRL_RetryApiIssue.scheduleBulkRetry(UTIL_Random.randomName(), 5);
			Test.stopTest();
		}

		Assert.isNull(jobId, 'Should return null when no failures found');
	}

	/**
	 * @description Verifies that the idempotency key from ApiIssue__c is preserved when retrying.
	 *
	 * @see CTRL_RetryApiIssue.retry
	 */
	@SuppressWarnings('PMD.KernSecurityBypassCallSite')
	@IsTest
	private static void shouldPreserveIdempotencyKeyOnRetry()
	{
		System.runAs(getUserWithApiIssueResolverPermissionSet())
		{
			ApiCall__c apiCall = TST_Factory.newOutboundApiCall(API_PostExample.class.getName(), UserInfo.getUserId(), UTIL_Random.randomName(), UTIL_Random.randomName());
			ApiIssue__c apiIssue =
					TST_Factory.insertApiIssue(apiCall, UTIL_Crypto.generateMD5Hash(apiCall.RequestParameters__c));

			apiIssue.IdempotencyKey__c = 'preserved-key-12345';
			DML_Builder.newTransaction().withSystemMode().doUpdate(apiIssue).execute();

			Test.startTest();

			CTRL_RetryApiIssue.DTO_Response dtoResponse = CTRL_RetryApiIssue.retry(apiIssue.Id);

			Test.stopTest();

			Assert.isTrue(dtoResponse.callSuccessful, 'Retry should succeed');

			ApiCall__c retryCall = new SEL_ApiCall().findByIdempotencyKey('preserved-key-12345');
			Assert.isNotNull(retryCall, 'Retry API call should exist with preserved idempotency key');
			Assert.areEqual('preserved-key-12345', retryCall.IdempotencyKey__c, 'Idempotency key should be preserved from ApiIssue to retry ApiCall');
		}
	}

	/**
	 * @description Verifies that when the callout budget is exhausted, only the first failure
	 * in a bulk replay batch is processed and the rest are deferred with the dispatcher's warning log.
	 */
	@IsTest
	private static void shouldDeferRemainingFailuresWhenCalloutBudgetExhausted()
	{
		API_Dispatcher.simulateCalloutBudgetExhausted = true;
		LOG_Builder.ignoreTestMode = true;

		ApiCall__c apiCall1 = TST_Factory.newOutboundApiCall(API_PostExample.class.getName(), UserInfo.getUserId(), UTIL_Random.randomName(), UTIL_Random.randomName());
		ApiIssue__c issue1 = TST_Factory.insertApiIssue(apiCall1, UTIL_Crypto.generateMD5Hash(apiCall1.RequestParameters__c));

		ApiCall__c apiCall2 = TST_Factory.newOutboundApiCall(API_PostExample.class.getName(), UserInfo.getUserId(), UTIL_Random.randomName(), UTIL_Random.randomName());
		ApiIssue__c issue2 = TST_Factory.insertApiIssue(apiCall2, UTIL_Crypto.generateMD5Hash(apiCall2.RequestParameters__c));

		ApiCall__c apiCall3 = TST_Factory.newOutboundApiCall(API_PostExample.class.getName(), UserInfo.getUserId(), UTIL_Random.randomName(), UTIL_Random.randomName());
		ApiIssue__c issue3 = TST_Factory.insertApiIssue(apiCall3, UTIL_Crypto.generateMD5Hash(apiCall3.RequestParameters__c));

		List<Object> items = new List<Object> {issue1, issue2, issue3};
		CTRL_RetryApiIssue.FailureReplayProcessor processor = new CTRL_RetryApiIssue.FailureReplayProcessor();

		System.runAs(getUserWithApiIssueResolverPermissionSet())
		{
			Test.startTest();
			processor.execute(toRequestGroups(items));
			Test.stopTest();
		}

		LogEntry__c warningLog = new SEL_LogEntry().findByMethod(API_Dispatcher.class.getName() + '/execute');
		Assert.isNotNull(warningLog, 'Warning log should be emitted for deferred failure replays');
		Assert.isTrue(warningLog.ShortMessage__c.contains('deferred'), 'Warning should mention deferred replays');
		ApiIssue__c firstIssue = (ApiIssue__c)new SEL_ApiIssue().findById(issue1.Id);
		Assert.areEqual(SEL_ApiIssue.STATUS_RESOLVED, firstIssue.Status__c, 'Expected the first failure to be retried and resolved');
		ApiIssue__c deferredIssue = (ApiIssue__c)new SEL_ApiIssue().findById(issue3.Id);
		Assert.areEqual(SEL_ApiIssue.STATUS_OPEN, deferredIssue.Status__c, 'Expected a deferred failure to stay Open');
	}

	/**
	 * @description Verifies scheduleBulkRetry enqueues a job when unresolved failures exist.
	 */
	@IsTest
	private static void shouldScheduleBulkRetry()
	{
		System.runAs(getUserWithApiIssueResolverPermissionSet())
		{
			ApiCall__c apiCall = TST_Factory.newOutboundApiCall(API_PostExample.class.getName(), UserInfo.getUserId(), UTIL_Random.randomName(), UTIL_Random.randomName());
			TST_Factory.insertApiIssue(apiCall, UTIL_Crypto.generateMD5Hash(apiCall.RequestParameters__c));

			Test.startTest();

			Id jobId = CTRL_RetryApiIssue.scheduleBulkRetry(API_PostExample.class.getName(), 0);

			Test.stopTest();

			Assert.isNotNull(jobId, 'Should return job ID when failures exist');
		}
	}

	/**
	 * @description An unattended bulk retry never re-sends a request the remote system may already have processed: of two
	 * open issues of one service, the one marked ExternalSystemMayHaveActed__c is skipped and stays Open with the count logged at
	 * warn, and the other is retried and resolved.
	 */
	@SuppressWarnings('PMD.KernSecurityBypassCallSite')
	@IsTest
	private static void shouldSkipIssuesTheExternalSystemMayHaveProcessedInABulkRetry()
	{
		LOG_Builder.ignoreTestMode = true;
		String serviceName = API_PostExample.class.getName();
		ApiCall__c firstCall = TST_Factory.newOutboundApiCall(serviceName, UserInfo.getUserId(), UTIL_Random.randomName(), UTIL_Random.randomName());
		ApiCall__c secondCall = TST_Factory.newOutboundApiCall(serviceName, UserInfo.getUserId(), UTIL_Random.randomName(), UTIL_Random.randomName());
		ApiIssue__c retriableIssue = TST_Factory.insertApiIssue(firstCall, UTIL_Crypto.generateMD5Hash(firstCall.RequestParameters__c));
		ApiIssue__c actedIssue = TST_Factory.insertApiIssue(secondCall, UTIL_Crypto.generateMD5Hash(secondCall.RequestParameters__c));
		actedIssue.ExternalSystemMayHaveActed__c = true;
		DML_Builder.newTransaction().withSystemMode().doUpdate(actedIssue).execute();

		runJobAsUserWithApiIssueResolverPermissionSet(toRequestGroups(new List<Object> {retriableIssue, actedIssue}));

		ApiIssue__c retriedIssue = (ApiIssue__c)new SEL_ApiIssue().findById(retriableIssue.Id);
		Assert.areEqual(SEL_ApiIssue.STATUS_RESOLVED, retriedIssue.Status__c, 'Expected the issue the remote never saw to be retried and resolved');
		ApiIssue__c skippedIssue = (ApiIssue__c)new SEL_ApiIssue().findById(actedIssue.Id);
		Assert.areEqual(SEL_ApiIssue.STATUS_OPEN, skippedIssue.Status__c, 'Expected the issue the remote may have acted on to stay Open');
		LogEntry__c warningLog = new SEL_LogEntry().findByMethod(CTRL_RetryApiIssue.class.getName() + '/FailureReplayProcessor');
		Assert.isNotNull(warningLog, 'Expected the skipped count to be logged');
		Assert.isTrue(warningLog.ShortMessage__c.contains('skipped'), 'Expected the warning to name the skip');
	}

	/**
	 * @description When the job holds one request whose issues include one the remote system may already have processed,
	 * it sends nothing for that request, not even from the other issue: both stay Open and the skip is logged at warn.
	 */
	@SuppressWarnings('PMD.KernSecurityBypassCallSite')
	@IsTest
	private static void shouldNotSendARequestWithAFlaggedIssueInTheJob()
	{
		LOG_Builder.ignoreTestMode = true;
		String serviceName = API_PostExample.class.getName();
		ApiCall__c apiCall = TST_Factory.newOutboundApiCall(serviceName, UserInfo.getUserId(), UTIL_Random.randomName(), UTIL_Random.randomName());
		String requestHash = UTIL_Crypto.generateMD5Hash(apiCall.RequestParameters__c);
		ApiIssue__c plainIssue = TST_Factory.insertApiIssue(apiCall, requestHash);
		ApiIssue__c flaggedIssue = TST_Factory.insertApiIssue(apiCall, requestHash);
		flaggedIssue.ExternalSystemMayHaveActed__c = true;
		DML_Builder.newTransaction().withSystemMode().doUpdate(flaggedIssue).execute();
		Integer callCountBefore = new SEL_ApiCall().findByServiceName(serviceName).size();

		runJobAsUserWithApiIssueResolverPermissionSet(new List<Object> {new List<Id> {plainIssue.Id, flaggedIssue.Id}});

		Assert.areEqual(callCountBefore, new SEL_ApiCall().findByServiceName(serviceName).size(), 'Expected no call for a request with a flagged issue');
		ApiIssue__c unsentIssue = (ApiIssue__c)new SEL_ApiIssue().findById(plainIssue.Id);
		Assert.areEqual(SEL_ApiIssue.STATUS_OPEN, unsentIssue.Status__c, 'Expected the plain issue to stay Open');
		ApiIssue__c skippedIssue = (ApiIssue__c)new SEL_ApiIssue().findById(flaggedIssue.Id);
		Assert.areEqual(SEL_ApiIssue.STATUS_OPEN, skippedIssue.Status__c, 'Expected the flagged issue to stay Open');
		LogEntry__c warningLog = new SEL_LogEntry().findByMethod(CTRL_RetryApiIssue.class.getName() + '/FailureReplayProcessor');
		Assert.isNotNull(warningLog, 'Expected the skip to be logged');
		Assert.isTrue(warningLog.ShortMessage__c.contains('may already have processed'), 'Expected the may-have-acted reason, got ' + warningLog.ShortMessage__c);
	}

	/**
	 * @description The Retry button is a human's deliberate re-send: an issue marked ExternalSystemMayHaveActed__c is still run
	 * when the operator presses Retry, and resolves when the call succeeds.
	 */
	@SuppressWarnings('PMD.KernSecurityBypassCallSite')
	@IsTest
	private static void shouldStillRunASingleRetryTheOperatorChose()
	{
		ApiCall__c apiCall = TST_Factory.newOutboundApiCall(API_PostExample.class.getName(), UserInfo.getUserId(), UTIL_Random.randomName(), UTIL_Random.randomName());
		ApiIssue__c actedIssue = TST_Factory.insertApiIssue(apiCall, UTIL_Crypto.generateMD5Hash(apiCall.RequestParameters__c));
		actedIssue.ExternalSystemMayHaveActed__c = true;
		DML_Builder.newTransaction().withSystemMode().doUpdate(actedIssue).execute();

		CTRL_RetryApiIssue.DTO_Response dtoResponse;

		System.runAs(getUserWithApiIssueResolverPermissionSet())
		{
			Test.startTest();
			dtoResponse = CTRL_RetryApiIssue.retry(actedIssue.Id);
			Test.stopTest();
		}

		Assert.isTrue(dtoResponse.callSuccessful, 'Expected the operator\'s retry to run');
		ApiIssue__c retriedIssue = (ApiIssue__c)new SEL_ApiIssue().findById(actedIssue.Id);
		Assert.areEqual(SEL_ApiIssue.STATUS_RESOLVED, retriedIssue.Status__c, 'Expected the issue to resolve');
	}

	/**
	 * @description A bulk retry sends its outbound calls together, so no call is refused for work an earlier call left
	 * unsaved: three open issues of a service whose calls succeed all resolve.
	 */
	@IsTest
	private static void shouldResolveEveryOutboundIssueInOneBulkRetry()
	{
		String serviceName = API_PostExample.class.getName();
		List<Object> items = new List<Object>();
		for(Integer index = 0; index < BULK_ISSUE_COUNT; index++)
		{
			ApiCall__c apiCall = TST_Factory.newOutboundApiCall(serviceName, UserInfo.getUserId(), UTIL_Random.randomName(), UTIL_Random.randomName());
			items.add(TST_Factory.insertApiIssue(apiCall, UTIL_Crypto.generateMD5Hash(apiCall.RequestParameters__c)));
		}

		runJobAsUserWithApiIssueResolverPermissionSet(toRequestGroups(items));

		Integer resolvedCount = 0;
		for(Object item : items)
		{
			ApiIssue__c retriedIssue = (ApiIssue__c)new SEL_ApiIssue().findById(((ApiIssue__c)item).Id);
			resolvedCount += retriedIssue.Status__c == SEL_ApiIssue.STATUS_RESOLVED ? 1 : 0;
		}
		Assert.areEqual(BULK_ISSUE_COUNT, resolvedCount, 'Expected every issue of the bulk retry to resolve');
	}

	/**
	 * @description A bulk retry that holds an inbound and an outbound issue sends the outbound call first and then replays
	 * the inbound request, and both issues resolve. The mocked settings answer every settings query, so the outbound
	 * service's own setting is registered first, where a lookup by class name finds it.
	 */
	@IsTest
	private static void shouldResolveInboundAndOutboundIssuesInOneBulkRetry()
	{
		TST_Mock.register(ApiSetting__mdt.SObjectType, new SEL_ApiSetting().findByClassName(API_PostExample.class.getName()));
		registerInboundSetting(INBOUND_SERVICE_NAME, new Map<SObjectField, Object>());
		ApiIssue__c inboundIssue = createInboundIssue();
		ApiCall__c apiCall = TST_Factory.newOutboundApiCall(API_PostExample.class.getName(), UserInfo.getUserId(), UTIL_Random.randomName(), UTIL_Random.randomName());
		ApiIssue__c outboundIssue = TST_Factory.insertApiIssue(apiCall, UTIL_Crypto.generateMD5Hash(apiCall.RequestParameters__c));

		runJobAsUserWithApiIssueResolverPermissionSet(toRequestGroups(new List<Object> {inboundIssue, outboundIssue}));

		ApiIssue__c replayedIssue = (ApiIssue__c)new SEL_ApiIssue().findById(inboundIssue.Id);
		Assert.areEqual(SEL_ApiIssue.STATUS_RESOLVED, replayedIssue.Status__c, 'Expected the inbound issue to resolve');
		ApiIssue__c retriedIssue = (ApiIssue__c)new SEL_ApiIssue().findById(outboundIssue.Id);
		Assert.areEqual(SEL_ApiIssue.STATUS_RESOLVED, retriedIssue.Status__c, 'Expected the outbound issue to resolve');
	}

	/**
	 * @description Many open outbound issues logged for one request, each with its own call that holds a request and a
	 * response at their full length, are sent once and all resolve, and the job does not hold those requests and
	 * responses in memory while it sends. Before it sends, the job checks whether each issue's call failed permanently,
	 * and it keeps that check while it sends; the check reads only that one field of each call. The memory the run uses
	 * while the call is sent is recorded by the test service, and must stay below a quarter of what the calls' requests
	 * and responses together take as text; a check holding them all uses more than that.
	 */
	@IsTest
	private static void shouldNotHoldTheCallsPayloadsWhileTheJobSends()
	{
		TST_Factory.newOutboundApiSetting(MEMORY_RECORDING_SERVICE_NAME, new Map<SObjectField, Object> {ApiSetting__mdt.RetryIssues__c => true});
		List<ApiIssue__c> issues = insertOutboundIssuesWithFullLengthPayloads(FULL_PAYLOAD_ISSUE_COUNT);
		Integer payloadBytes = FULL_PAYLOAD_ISSUE_COUNT * (SEL_ApiCall.REQUEST_LENGTH + SEL_ApiCall.RESPONSE_LENGTH);

		runJobAsUserWithApiIssueResolverPermissionSet(new List<Object> {new List<Id>(UTIL_SObject.extractIds(issues))});

		Integer resolvedCount = 0;
		for(ApiIssue__c retriedIssue : (List<ApiIssue__c>)new SEL_ApiIssue().findById(UTIL_SObject.extractIds(issues)))
		{
			resolvedCount += retriedIssue.Status__c == SEL_ApiIssue.STATUS_RESOLVED ? 1 : 0;
		}
		Assert.areEqual(FULL_PAYLOAD_ISSUE_COUNT, resolvedCount, 'Expected every issue to resolve');
		Assert.isNotNull(heapUsedWhileSending, 'Expected the job to send the call');
		Assert.isTrue
				(
						heapUsedWhileSending < payloadBytes / PAYLOAD_SHARE_DIVISOR,
						'Expected the job not to hold the calls\' payloads while it sends, but it used ' + heapUsedWhileSending + ' bytes'
				);
	}

	/**
	 * @description A bulk retry acts only on issues that are still open when it runs: of two open issues scheduled together,
	 * one resolved by the operator's Retry before the job runs is not sent again, and only the other issue's call is sent.
	 * The operator's Retry runs in its own transaction; a test cannot make that callout after its own inserts, so the
	 * issue is given the Resolved status a successful Retry writes.
	 */
	@SuppressWarnings('PMD.KernSecurityBypassCallSite')
	@IsTest
	private static void shouldNotResendAnIssueResolvedAfterTheBulkRetryWasScheduled()
	{
		String serviceName = API_PostExample.class.getName();
		ApiCall__c firstCall = TST_Factory.newOutboundApiCall(serviceName, UserInfo.getUserId(), UTIL_Random.randomName(), UTIL_Random.randomName());
		ApiCall__c secondCall = TST_Factory.newOutboundApiCall(serviceName, UserInfo.getUserId(), UTIL_Random.randomName(), UTIL_Random.randomName());
		ApiIssue__c resolvedIssue = TST_Factory.insertApiIssue(firstCall, UTIL_Crypto.generateMD5Hash(firstCall.RequestParameters__c));
		ApiIssue__c openIssue = TST_Factory.insertApiIssue(secondCall, UTIL_Crypto.generateMD5Hash(secondCall.RequestParameters__c));
		List<Object> scheduledItems = new List<Object> {resolvedIssue, openIssue};
		ApiIssue__c operatorResolution = resolvedIssue.clone(true);
		operatorResolution.Status__c = SEL_ApiIssue.STATUS_RESOLVED;
		DML_Builder.newTransaction().withSystemMode().doUpdate(operatorResolution).execute();
		List<ApiCall__c> callsBefore = new SEL_ApiCall().findByServiceName(serviceName);

		runJobAsUserWithApiIssueResolverPermissionSet(toRequestGroups(scheduledItems));

		List<ApiCall__c> callsAfter = new SEL_ApiCall().findByServiceName(serviceName);
		Assert.areEqual(callsBefore.size() + 1, callsAfter.size(), 'Expected exactly one call to be sent, got ' + (callsAfter.size() - callsBefore.size()));
		Integer resolvedIssueCallsBefore = countCallsWithParameters(callsBefore, resolvedIssue.RequestParameters__c);
		Integer resolvedIssueCallsAfter = countCallsWithParameters(callsAfter, resolvedIssue.RequestParameters__c);
		Assert.areEqual(resolvedIssueCallsBefore, resolvedIssueCallsAfter, 'Expected no new call for the issue resolved before the job ran');
		ApiIssue__c retriedIssue = (ApiIssue__c)new SEL_ApiIssue().findById(openIssue.Id);
		Assert.areEqual(SEL_ApiIssue.STATUS_RESOLVED, retriedIssue.Status__c, 'Expected the issue still open to be retried and resolved');
		ApiIssue__c untouchedIssue = (ApiIssue__c)new SEL_ApiIssue().findById(resolvedIssue.Id);
		Assert.areEqual(SEL_ApiIssue.STATUS_RESOLVED, untouchedIssue.Status__c, 'Expected the issue resolved earlier to stay Resolved');
	}

	/**
	 * @description Runs the bulk retry job on the given items as the test user who holds the Kern API Issue Resolver permission set, between Test.startTest() and Test.stopTest().
	 *
	 * @param items The groups of issue ids the job holds
	 */
	private static void runJobAsUserWithApiIssueResolverPermissionSet(List<Object> items)
	{
		System.runAs(getUserWithApiIssueResolverPermissionSet())
		{
			Test.startTest();
			new CTRL_RetryApiIssue.FailureReplayProcessor().execute(items);
			Test.stopTest();
		}
	}

	/**
	 * @description Turns issues into the items the bulk retry job holds: one request group per issue, as the launcher
	 * builds for issues logged for different requests.
	 *
	 * @param issues The issues, each its own request
	 *
	 * @return One group of issue ids per issue
	 */
	private static List<Object> toRequestGroups(List<Object> issues)
	{
		List<Object> requestGroups = new List<Object>();
		for(Object issue : issues)
		{
			requestGroups.add(new List<Id> {((ApiIssue__c)issue).Id});
		}
		return requestGroups;
	}

	/**
	 * @description Counts the call rows that carry the given request parameters.
	 *
	 * @param apiCalls The call rows to look through
	 * @param requestParameters The request parameters to match
	 *
	 * @return How many rows carry them
	 */
	private static Integer countCallsWithParameters(List<ApiCall__c> apiCalls, String requestParameters)
	{
		Integer matchCount = 0;
		for(ApiCall__c apiCall : apiCalls)
		{
			matchCount += apiCall.RequestParameters__c == requestParameters ? 1 : 0;
		}
		return matchCount;
	}

	/**
	 * @description When the callout budget is spent, a bulk retry replays the first inbound request and defers the rest,
	 * which stay Open, with the deferred count logged at warn.
	 */
	@IsTest
	private static void shouldDeferInboundReplaysWhenCalloutBudgetExhausted()
	{
		LOG_Builder.ignoreTestMode = true;
		registerInboundSetting(INBOUND_SERVICE_NAME, new Map<SObjectField, Object>());
		ApiIssue__c firstIssue = createInboundIssue();
		ApiIssue__c secondIssue = createInboundIssue();
		API_Dispatcher.simulateCalloutBudgetExhausted = true;

		runJobAsUserWithApiIssueResolverPermissionSet(toRequestGroups(new List<Object> {firstIssue, secondIssue}));

		ApiIssue__c replayedIssue = (ApiIssue__c)new SEL_ApiIssue().findById(firstIssue.Id);
		Assert.areEqual(SEL_ApiIssue.STATUS_RESOLVED, replayedIssue.Status__c, 'Expected the first inbound issue to be replayed and resolved');
		ApiIssue__c deferredIssue = (ApiIssue__c)new SEL_ApiIssue().findById(secondIssue.Id);
		Assert.areEqual(SEL_ApiIssue.STATUS_OPEN, deferredIssue.Status__c, 'Expected the deferred inbound issue to stay Open');
		LogEntry__c warningLog = new SEL_LogEntry().findByMethod(CTRL_RetryApiIssue.class.getName() + '/FailureReplayProcessor');
		Assert.isNotNull(warningLog, 'Expected the deferred count to be logged');
		Assert.isTrue(warningLog.ShortMessage__c.contains('deferred'), 'Expected the warning to name the deferral');
	}

	/**
	 * @description A bulk retry respects each service's Retry Issues setting: an issue of a service that does not allow
	 * retries is not sent and stays Open.
	 */
	@IsTest
	private static void shouldLeaveIssuesOfAServiceWithoutRetryOpenInABulkRetry()
	{
		ApiCall__c apiCall = TST_Factory.newOutboundApiCall(API_GetPwndPasswords.class.getName(), UserInfo.getUserId(), UTIL_Random.randomName(), UTIL_Random.randomName());
		ApiIssue__c apiIssue = TST_Factory.insertApiIssue(apiCall, UTIL_Crypto.generateMD5Hash(apiCall.RequestParameters__c));
		Integer callCountBefore = new SEL_ApiCall().findByServiceName(API_GetPwndPasswords.class.getName()).size();

		runJobAsUserWithApiIssueResolverPermissionSet(toRequestGroups(new List<Object> {apiIssue}));

		ApiIssue__c unsentIssue = (ApiIssue__c)new SEL_ApiIssue().findById(apiIssue.Id);
		Assert.areEqual(SEL_ApiIssue.STATUS_OPEN, unsentIssue.Status__c, 'Expected the issue of a service without retries to stay Open');
		Integer callCountAfter = new SEL_ApiCall().findByServiceName(API_GetPwndPasswords.class.getName()).size();
		Assert.areEqual(callCountBefore, callCountAfter, 'Expected no call to be sent for a service without retries');
	}

	/**
	 * @description An issue deleted after the bulk retry was scheduled is left out when the job runs, and the other issue
	 * of the batch is still sent and resolved.
	 */
	@IsTest
	private static void shouldLeaveOutAnIssueDeletedBeforeTheBulkRetryRuns()
	{
		ApiCall__c apiCall = TST_Factory.newOutboundApiCall(API_PostExample.class.getName(), UserInfo.getUserId(), UTIL_Random.randomName(), UTIL_Random.randomName());
		ApiIssue__c apiIssue = TST_Factory.insertApiIssue(apiCall, UTIL_Crypto.generateMD5Hash(apiCall.RequestParameters__c));
		List<Object> requestGroups = new List<Object> {new List<Id> {UTIL_Random.randomId(ApiIssue__c.SObjectType)}, new List<Id> {apiIssue.Id}};

		runJobAsUserWithApiIssueResolverPermissionSet(requestGroups);

		ApiIssue__c retriedIssue = (ApiIssue__c)new SEL_ApiIssue().findById(apiIssue.Id);
		Assert.areEqual(SEL_ApiIssue.STATUS_RESOLVED, retriedIssue.Status__c, 'Expected the issue still present to be sent and resolved');
	}

	/**
	 * @description The job makes the scheduling check again: while the switch that disables every API is on, an issue of a
	 * service that accepts retries is not sent when the job runs and stays Open.
	 */
	@IsTest
	private static void shouldLeaveIssuesOpenInABulkRetryWhileEveryApiIsDisabled()
	{
		TST_Factory.newFeatureFlag(API_Base.FLAG_DISABLE_ALL_APIS);
		String serviceName = API_PostExample.class.getName();
		ApiCall__c apiCall = TST_Factory.newOutboundApiCall(serviceName, UserInfo.getUserId(), UTIL_Random.randomName(), UTIL_Random.randomName());
		ApiIssue__c apiIssue = TST_Factory.insertApiIssue(apiCall, UTIL_Crypto.generateMD5Hash(apiCall.RequestParameters__c));
		Integer callCountBefore = new SEL_ApiCall().findByServiceName(serviceName).size();

		runJobAsUserWithApiIssueResolverPermissionSet(toRequestGroups(new List<Object> {apiIssue}));

		ApiIssue__c unsentIssue = (ApiIssue__c)new SEL_ApiIssue().findById(apiIssue.Id);
		Assert.areEqual(SEL_ApiIssue.STATUS_OPEN, unsentIssue.Status__c, 'Expected the issue to stay Open while every API is disabled');
		Assert.areEqual(callCountBefore, new SEL_ApiCall().findByServiceName(serviceName).size(), 'Expected no call while every API is disabled');
	}

	/**
	 * @description A user without the Retry API Issue permission is refused by Retry: the answer carries the labelled
	 * refusal, the issue stays Open and no call is sent for the service.
	 */
	@IsTest
	private static void shouldRefuseRetryToAUserWithoutTheRetryPermission()
	{
		String serviceName = API_PostExample.class.getName();
		ApiCall__c apiCall = TST_Factory.newOutboundApiCall(serviceName, UserInfo.getUserId(), UTIL_Random.randomName(), UTIL_Random.randomName());
		ApiIssue__c apiIssue = TST_Factory.insertApiIssue(apiCall, UTIL_Crypto.generateMD5Hash(apiCall.RequestParameters__c));
		Integer callCountBefore = new SEL_ApiCall().findByServiceName(serviceName).size();
		CTRL_RetryApiIssue.DTO_Response dtoResponse;

		System.runAs(getUserWithoutRetryPermission())
		{
			Test.startTest();
			dtoResponse = CTRL_RetryApiIssue.retry(apiIssue.Id);
			Test.stopTest();
		}

		Assert.isFalse(dtoResponse.callSuccessful, 'Expected the retry to be refused');
		Assert.areEqual(System.Label.RetryApiIssue_PermissionRequired, dtoResponse.errorMessage, 'Expected the refusal to come from the label');
		ApiIssue__c unchangedIssue = (ApiIssue__c)new SEL_ApiIssue().findById(apiIssue.Id);
		Assert.areEqual(SEL_ApiIssue.STATUS_OPEN, unchangedIssue.Status__c, 'Expected the issue to stay Open');
		Assert.areEqual(callCountBefore, new SEL_ApiCall().findByServiceName(serviceName).size(), 'Expected no call to be sent');
	}

	/**
	 * @description A user without the Retry API Issue permission is refused by the resolve action too, before an inbound
	 * request is replayed: the issue stays Open with no resolved date.
	 */
	@IsTest
	private static void shouldRefuseResolveFailureToAUserWithoutTheRetryPermission()
	{
		registerInboundSetting(INBOUND_SERVICE_NAME, new Map<SObjectField, Object>());
		ApiIssue__c apiIssue = createInboundIssue();
		CTRL_RetryApiIssue.DTO_Response dtoResponse;

		System.runAs(getUserWithoutRetryPermission())
		{
			Test.startTest();
			dtoResponse = CTRL_RetryApiIssue.resolveFailure(apiIssue.Id);
			Test.stopTest();
		}

		Assert.isFalse(dtoResponse.callSuccessful, 'Expected the replay to be refused');
		Assert.areEqual(System.Label.RetryApiIssue_PermissionRequired, dtoResponse.errorMessage, 'Expected the refusal to come from the label');
		ApiIssue__c unchangedIssue = (ApiIssue__c)new SEL_ApiIssue().findById(apiIssue.Id);
		Assert.areEqual(SEL_ApiIssue.STATUS_OPEN, unchangedIssue.Status__c, 'Expected the issue to stay Open');
		Assert.isNull(unchangedIssue.ResolvedDate__c, 'Expected nothing to be replayed');
	}

	/**
	 * @description The Kern Administrator permission set grants the Retry API Issue permission, so a Standard User holding
	 * that set alone can retry: an administrator keeps Retry after the upgrade.
	 */
	@IsTest
	private static void shouldLetAnAdministratorRetry()
	{
		System.runAs(getUserWithAdministratorPermissionSet())
		{
			ApiCall__c apiCall = TST_Factory.newOutboundApiCall(API_PostExample.class.getName(), UserInfo.getUserId(), UTIL_Random.randomName(), UTIL_Random.randomName());
			ApiIssue__c apiIssue = TST_Factory.insertApiIssue(apiCall, UTIL_Crypto.generateMD5Hash(apiCall.RequestParameters__c));

			Test.startTest();
			CTRL_RetryApiIssue.DTO_Response dtoResponse = CTRL_RetryApiIssue.retry(apiIssue.Id);
			Test.stopTest();

			Assert.isTrue(dtoResponse.callSuccessful, 'Expected the administrator set to grant Retry');
			ApiIssue__c retriedIssue = (ApiIssue__c)new SEL_ApiIssue().findById(apiIssue.Id);
			Assert.areEqual(SEL_ApiIssue.STATUS_RESOLVED, retriedIssue.Status__c, 'Expected the issue to resolve');
		}
	}

	/**
	 * @description A resolver retries, from the issue's record page, an issue another user owns. The Kern API Issue Resolver
	 * permission set lets the resolver see every issue but not edit one, so the call is sent and the issue is marked
	 * Resolved by the action itself. The call goes through a caller that applies record sharing, as the record page does,
	 * so the test holds whatever the org's sharing default for API issues is.
	 */
	@IsTest
	private static void shouldRetryAnIssueAnotherUserOwnsFromTheRecordPage()
	{
		ApiCall__c apiCall = TST_Factory.newOutboundApiCall(API_PostExample.class.getName(), UserInfo.getUserId(), UTIL_Random.randomName(), UTIL_Random.randomName());
		ApiIssue__c apiIssue = TST_Factory.insertApiIssue(apiCall, UTIL_Crypto.generateMD5Hash(apiCall.RequestParameters__c));
		CTRL_RetryApiIssue.DTO_Response dtoResponse;

		System.runAs(getUserWithApiIssueResolverPermissionSet())
		{
			Test.startTest();
			dtoResponse = new SharingEnforcedCaller().retry(apiIssue.Id);
			Test.stopTest();
		}

		Assert.isTrue(dtoResponse.callSuccessful, 'Expected the resolver to retry an issue another user owns, got ' + dtoResponse.errorMessage);
		ApiIssue__c retriedIssue = (ApiIssue__c)new SEL_ApiIssue().findById(apiIssue.Id);
		Assert.areEqual(SEL_ApiIssue.STATUS_RESOLVED, retriedIssue.Status__c, 'Expected the issue another user owns to be marked Resolved');
	}

	/**
	 * @description A resolver replays, from the issue's record page, an inbound issue another user owns. The replay works
	 * and the issue is marked Resolved with a resolved date, though the resolver may not edit the issue. Record sharing is
	 * applied to the call, as the record page does.
	 */
	@IsTest
	private static void shouldReplayAnInboundIssueAnotherUserOwnsFromTheRecordPage()
	{
		registerInboundSetting(INBOUND_SERVICE_NAME, new Map<SObjectField, Object>());
		ApiIssue__c apiIssue = createInboundIssue();
		CTRL_RetryApiIssue.DTO_Response dtoResponse;

		System.runAs(getUserWithApiIssueResolverPermissionSet())
		{
			Test.startTest();
			dtoResponse = new SharingEnforcedCaller().resolveFailure(apiIssue.Id);
			Test.stopTest();
		}

		Assert.isTrue(dtoResponse.callSuccessful, 'Expected the resolver to replay an issue another user owns, got ' + dtoResponse.errorMessage);
		ApiIssue__c replayedIssue = (ApiIssue__c)new SEL_ApiIssue().findById(apiIssue.Id);
		Assert.areEqual(SEL_ApiIssue.STATUS_RESOLVED, replayedIssue.Status__c, 'Expected the inbound issue another user owns to be marked Resolved');
		Assert.isNotNull(replayedIssue.ResolvedDate__c, 'Expected the resolved date to be set');
	}

	/**
	 * @description A resolver chooses Retry Selected on an issue another user owns. The resolver sees every issue, so the
	 * issue counts as selected and is handed to a background job. Record sharing is applied to the call, as the Retry
	 * Selected flow does.
	 */
	@IsTest
	private static void shouldScheduleARetryOfAnIssueAnotherUserOwns()
	{
		ApiCall__c apiCall = TST_Factory.newOutboundApiCall(API_PostExample.class.getName(), UserInfo.getUserId(), UTIL_Random.randomName(), UTIL_Random.randomName());
		ApiIssue__c apiIssue = TST_Factory.insertApiIssue(apiCall, UTIL_Crypto.generateMD5Hash(apiCall.RequestParameters__c));
		CTRL_RetryApiIssue.DTO_ScheduledBulkRetry scheduledRetry;

		System.runAs(getUserWithApiIssueResolverPermissionSet())
		{
			Test.startTest();
			scheduledRetry = new SharingEnforcedCaller().scheduleBulkRetryOfIssues(new Set<Id> {apiIssue.Id});
			Test.stopTest();
		}

		Assert.areEqual(1, scheduledRetry.selectedCount, 'Expected the issue another user owns to count as selected');
		Assert.areEqual(1, scheduledRetry.queuedCount, 'Expected the issue another user owns to be handed to the job');
		Assert.isNotNull(scheduledRetry.jobId, 'Expected a job for the issue another user owns');
	}

	/**
	 * @description The bulk retry job, run as a resolver with record sharing applied, sends an issue another user owns and
	 * marks it Resolved, though the resolver may not edit the issue.
	 */
	@IsTest
	private static void shouldResolveAnIssueAnotherUserOwnsInTheBulkRetryJob()
	{
		ApiCall__c apiCall = TST_Factory.newOutboundApiCall(API_PostExample.class.getName(), UserInfo.getUserId(), UTIL_Random.randomName(), UTIL_Random.randomName());
		ApiIssue__c apiIssue = TST_Factory.insertApiIssue(apiCall, UTIL_Crypto.generateMD5Hash(apiCall.RequestParameters__c));

		System.runAs(getUserWithApiIssueResolverPermissionSet())
		{
			Test.startTest();
			new SharingEnforcedCaller().runBulkRetryJob(toRequestGroups(new List<Object> {apiIssue}));
			Test.stopTest();
		}

		ApiIssue__c retriedIssue = (ApiIssue__c)new SEL_ApiIssue().findById(apiIssue.Id);
		Assert.areEqual(SEL_ApiIssue.STATUS_RESOLVED, retriedIssue.Status__c, 'Expected the job to mark the issue another user owns Resolved');
		Assert.isNotNull(retriedIssue.ResolvedDate__c, 'Expected the bulk retry job to set the resolved date');
	}

	/**
	 * @description A user holds the Retry API Issue permission through their own permission set, without View All Records on
	 * API issues, and presses Retry on an issue they cannot read. The test asks about a made-up issue id that was never
	 * saved, so no read can return it whatever the org's sharing default is: the same answer the user gets for another
	 * user's issue under a Private default. Retry answers with the labelled message that says so and sends no call.
	 */
	@IsTest
	private static void shouldRefuseRetryOfAnIssueTheUserCannotSee()
	{
		String serviceName = API_PostExample.class.getName();
		Integer callCountBefore = new SEL_ApiCall().findByServiceName(serviceName).size();
		CTRL_RetryApiIssue.DTO_Response dtoResponse;

		System.runAs(getUserWithRetryPermissionWithoutViewAll())
		{
			Test.startTest();
			dtoResponse = new SharingEnforcedCaller().retry(UTIL_Random.randomId(ApiIssue__c.SObjectType));
			Test.stopTest();
		}

		Assert.isFalse(dtoResponse.callSuccessful, 'Expected Retry to be refused');
		Assert.areEqual(System.Label.RetryApiIssue_IssueNotVisible, dtoResponse.errorMessage, 'Expected the refusal to come from the label');
		Assert.areEqual(callCountBefore, new SEL_ApiCall().findByServiceName(serviceName).size(), 'Expected no call to be sent');
	}

	/**
	 * @description The same user presses the resolve action on an issue they cannot read. As in the Retry test, the id was
	 * never saved, so no read can return it under any sharing default. The action answers with the labelled message and
	 * replays nothing.
	 */
	@IsTest
	private static void shouldRefuseResolveFailureOfAnIssueTheUserCannotSee()
	{
		CTRL_RetryApiIssue.DTO_Response dtoResponse;

		System.runAs(getUserWithRetryPermissionWithoutViewAll())
		{
			Test.startTest();
			dtoResponse = new SharingEnforcedCaller().resolveFailure(UTIL_Random.randomId(ApiIssue__c.SObjectType));
			Test.stopTest();
		}

		Assert.isFalse(dtoResponse.callSuccessful, 'Expected the resolve action to be refused');
		Assert.areEqual(System.Label.RetryApiIssue_IssueNotVisible, dtoResponse.errorMessage, 'Expected the refusal to come from the label');
	}

	/**
	 * @description A bulk retry run by a user without the Retry API Issue permission sends and replays nothing:
	 * scheduleBulkRetry answers null with one warn naming the permission, and the processor, run directly by the same user
	 * on an outbound and an inbound issue, sends no call, leaves both issues Open and logs how many items it refused. The
	 * mocked settings answer every settings query, so the outbound service's own setting is registered first, where a
	 * lookup by class name finds it and the outbound issue would be sent without the gate.
	 */
	@IsTest
	private static void shouldRefuseABulkRetryToAUserWithoutTheRetryPermission()
	{
		LOG_Builder.ignoreTestMode = true;
		TST_Mock.register(ApiSetting__mdt.SObjectType, new SEL_ApiSetting().findByClassName(API_PostExample.class.getName()));
		String serviceName = API_PostExample.class.getName();
		registerInboundSetting(INBOUND_SERVICE_NAME, new Map<SObjectField, Object>());
		ApiIssue__c inboundIssue = createInboundIssue();
		ApiCall__c apiCall = TST_Factory.newOutboundApiCall(serviceName, UserInfo.getUserId(), UTIL_Random.randomName(), UTIL_Random.randomName());
		ApiIssue__c outboundIssue = TST_Factory.insertApiIssue(apiCall, UTIL_Crypto.generateMD5Hash(apiCall.RequestParameters__c));
		Integer callCountBefore = new SEL_ApiCall().findByServiceName(serviceName).size();
		List<Object> items = new List<Object> {outboundIssue, inboundIssue};
		Id jobId;

		System.runAs(getUserWithoutRetryPermission())
		{
			Test.startTest();
			jobId = CTRL_RetryApiIssue.scheduleBulkRetry(serviceName, 0);
			new CTRL_RetryApiIssue.FailureReplayProcessor().execute(toRequestGroups(items));
			Test.stopTest();
		}

		Assert.isNull(jobId, 'Expected no job to be enqueued for a user without the permission');
		Assert.areEqual(callCountBefore, new SEL_ApiCall().findByServiceName(serviceName).size(), 'Expected no call to be sent');
		ApiIssue__c unsentIssue = (ApiIssue__c)new SEL_ApiIssue().findById(outboundIssue.Id);
		Assert.areEqual(SEL_ApiIssue.STATUS_OPEN, unsentIssue.Status__c, 'Expected the outbound issue to stay Open');
		ApiIssue__c inboundIssueStillOpen = (ApiIssue__c)new SEL_ApiIssue().findById(inboundIssue.Id);
		Assert.areEqual(SEL_ApiIssue.STATUS_OPEN, inboundIssueStillOpen.Status__c, 'Expected the inbound issue to stay Open');
		Assert.isNull(inboundIssueStillOpen.ResolvedDate__c, 'Expected the inbound request not to be replayed');
		LogEntry__c entryLog = new SEL_LogEntry().findByMethod(CTRL_RetryApiIssue.class.getName() + '/scheduleBulkRetry');
		Assert.isNotNull(entryLog, 'Expected the refusal at entry to be logged');
		Assert.isTrue(entryLog.ShortMessage__c.contains(CTRL_RetryApiIssue.RETRY_API_ISSUE_CUSTOM_PERMISSION_NAME), 'Expected the warning to name the permission');
		LogEntry__c processorLog = new SEL_LogEntry().findByMethod(CTRL_RetryApiIssue.class.getName() + '/FailureReplayProcessor');
		Assert.isNotNull(processorLog, 'Expected the processor to log the items it refused');
		Assert.isTrue
				(
						processorLog.ShortMessage__c.startsWith(items.size() + ' failure replay(s) refused'),
						'Expected the warning to count the refused items, got ' + processorLog.ShortMessage__c
				);
	}

	/**
	 * @description A replay sends the request the call kept, not the issue's own fields: the handler receives the path,
	 * the method, the body, the query parameter and the Idempotency-Key the first request carried. The issue holds no copy
	 * of the request, so a replay that read the issue would send nothing.
	 */
	@IsTest
	private static void shouldReplayTheRequestTheCallKept()
	{
		registerInboundSetting(RECORDING_SERVICE_NAME, new Map<SObjectField, Object>());
		String body = JSON.serialize(new Map<String, Object> {PARAMETER_NAME => UTIL_Random.randomName()});
		String idempotencyKey = UTIL_Random.randomUUID();
		ApiIssue__c apiIssue = failRecordedRequest(body, idempotencyKey, new UTIL_Exceptions.IllegalStateException(HANDLER_FAILURE_MESSAGE));
		CTRL_RetryApiIssue.DTO_Response dtoResponse;

		System.runAs(getUserWithApiIssueResolverPermissionSet())
		{
			Test.startTest();
			dtoResponse = CTRL_RetryApiIssue.retry(apiIssue.Id);
			Test.stopTest();
		}

		Assert.isTrue(dtoResponse.callSuccessful, 'Expected the replay to succeed, got ' + dtoResponse.errorMessage);
		Assert.isNotNull(receivedRequest, 'Expected the handler to receive the replayed request');
		Assert.areEqual(TEST_PATH, receivedRequest.requestURI, 'Expected the path the first request was sent to');
		Assert.areEqual(HTTP_POST, receivedRequest.httpMethod, 'Expected the method of the first request');
		Assert.areEqual(body, receivedRequest.requestBody?.toString(), 'Expected the body the first request carried');
		Assert.areEqual(PARAMETER_VALUE, receivedRequest.params.get(PARAMETER_NAME), 'Expected the query parameter the first request carried');
		Assert.areEqual(idempotencyKey, receivedRequest.headers.get(API_Base.HEADER_IDEMPOTENCY_KEY), 'Expected the key the first request carried');
		Assert.areEqual(SEL_ApiIssue.STATUS_RESOLVED, ((ApiIssue__c)new SEL_ApiIssue().findById(apiIssue.Id)).Status__c, 'Expected the issue to be resolved');
	}

	/**
	 * @description A body too long for the call's field is kept whole in the call's request body file, and the field
	 * keeps a cut copy. A replay reads the body from the file: the field here holds other text, and the handler still
	 * receives the body the first request carried, whose hash matches the one the call recorded. The resolver sends the
	 * first request too, so the call and its files are the resolver's own: only a user who can read the call's files
	 * gets the body from the file.
	 */
	@IsTest
	private static void shouldReplayAnOversizedBodyFromTheCallsFile()
	{
		registerInboundSetting(RECORDING_SERVICE_NAME, new Map<SObjectField, Object>());
		String body = JSON.serialize(new Map<String, Object> {PARAMETER_NAME => UTIL_Random.randomName()});
		CTRL_RetryApiIssue.DTO_Response dtoResponse;

		System.runAs(getUserWithApiIssueResolverPermissionSet())
		{
			API_Base.simulateStoreToFile = true;
			ApiIssue__c apiIssue = failRecordedRequest(body, null, new UTIL_Exceptions.IllegalStateException(HANDLER_FAILURE_MESSAGE));
			API_Base.simulateStoreToFile = false;
			updateField(apiIssue.ApiCall__c, ApiCall__c.Request__c, UTIL_Random.randomName());

			Test.startTest();
			dtoResponse = CTRL_RetryApiIssue.retry(apiIssue.Id);
			Test.stopTest();
		}

		Assert.isTrue(dtoResponse.callSuccessful, 'Expected the replay from the file to succeed, got ' + dtoResponse.errorMessage);
		Assert.areEqual(body, receivedRequest?.requestBody?.toString(), 'Expected the handler to receive the body kept in the file');
	}

	/**
	 * @description An issue made by hand links to no call but holds a request in its own fields. A replay sends that
	 * request to the service the issue names and resolves the issue. No exact copy check is possible, because there is no
	 * call that recorded the hash of the body.
	 */
	@IsTest
	private static void shouldReplayAHandMadeIssueWithNoCallFromItsOwnFields()
	{
		registerInboundSetting(INBOUND_SERVICE_NAME, new Map<SObjectField, Object>());
		ApiIssue__c apiIssue = createInboundIssue();
		CTRL_RetryApiIssue.DTO_Response dtoResponse;

		System.runAs(getUserWithApiIssueResolverPermissionSet())
		{
			Test.startTest();
			dtoResponse = CTRL_RetryApiIssue.retry(apiIssue.Id);
			Test.stopTest();
		}

		Assert.isTrue(dtoResponse.callSuccessful, 'Expected the replay from the issue\'s own fields to succeed, got ' + dtoResponse.errorMessage);
		ApiCall__c replayCall = new SEL_ApiCall().findByServiceName(INBOUND_SERVICE_NAME).get(0);
		Assert.areEqual(TEST_BODY, replayCall.Request__c, 'Expected the replay to send the body the issue holds');
		Assert.isNull(replayCall.PreviousAttempt__c, 'Expected no link, because the request came from no call');
		Assert.areEqual(SEL_ApiIssue.STATUS_RESOLVED, ((ApiIssue__c)new SEL_ApiIssue().findById(apiIssue.Id)).Status__c, 'Expected the issue to be resolved');
	}

	/**
	 * @description An issue whose call was deleted, and which holds no copy of the request, has nothing to run again. The
	 * call is deleted while the issue is resolved, and the issue is then opened again. The replay is refused with the
	 * labelled message that says so, nothing runs, and the issue stays open.
	 */
	@SuppressWarnings('PMD.KernSecurityBypassCallSite')
	@IsTest
	private static void shouldRefuseToReplayAnIssueWhoseCallIsGone()
	{
		registerInboundSetting(INBOUND_SERVICE_NAME, new Map<SObjectField, Object>());
		TST_Factory.newFeatureFlag(API_Base.FLAG_BYPASS_API_RECORD_DELETE_GUARD);
		ApiIssue__c apiIssue = failEchoRequest(TEST_BODY, null);
		updateField(apiIssue.Id, ApiIssue__c.Status__c, SEL_ApiIssue.STATUS_RESOLVED);
		DML_Builder.newTransaction().withSystemMode().doDelete(ApiCall__c.SObjectType.newSObject(apiIssue.ApiCall__c)).execute();
		updateField(apiIssue.Id, ApiIssue__c.Status__c, SEL_ApiIssue.STATUS_OPEN);
		CTRL_RetryApiIssue.DTO_Response dtoResponse;

		System.runAs(getUserWithApiIssueResolverPermissionSet())
		{
			Test.startTest();
			dtoResponse = CTRL_RetryApiIssue.retry(apiIssue.Id);
			Test.stopTest();
		}

		Assert.isFalse(dtoResponse.callSuccessful, 'Expected the replay to be refused');
		Assert.areEqual(System.Label.RetryApiIssue_OriginalCallMissing, dtoResponse.errorMessage, 'Expected the refusal to come from the label');
		Assert.isTrue(new SEL_ApiCall().findByServiceName(INBOUND_SERVICE_NAME).isEmpty(), 'Expected nothing to run');
		Assert.areEqual(SEL_ApiIssue.STATUS_OPEN, ((ApiIssue__c)new SEL_ApiIssue().findById(apiIssue.Id)).Status__c, 'Expected the issue to stay open');
	}

	/**
	 * @description An inbound issue of a service with Retry Issues off is not replayed: the callers of such a service
	 * resend failed requests themselves. The refusal speaks of a request received, nothing runs, and the issue stays open.
	 */
	@IsTest
	private static void shouldRefuseToReplayWhenRetryIssuesIsOff()
	{
		registerInboundSetting(INBOUND_SERVICE_NAME, new Map<SObjectField, Object> {ApiSetting__mdt.RetryIssues__c => false});
		ApiIssue__c apiIssue = failEchoRequest(TEST_BODY, null);

		Assert.areEqual(System.Label.RetryApiIssue_ReplayNotEnabled, replayAndReadRefusal(apiIssue), 'Expected the refusal to come from the label');
	}

	/**
	 * @description While every inbound API is switched off, an inbound issue is not replayed, so a replay does not fail
	 * only to be refused by the same switch. The refusal says the service is paused, nothing runs, and the issue stays open.
	 */
	@IsTest
	private static void shouldRefuseToReplayWhenInboundApisAreSwitchedOff()
	{
		registerInboundSetting(INBOUND_SERVICE_NAME, new Map<SObjectField, Object>());
		ApiIssue__c apiIssue = failEchoRequest(TEST_BODY, null);
		TST_Factory.newFeatureFlag(API_Inbound.FLAG_DISABLE_ALL_INBOUND_APIS);

		Assert.areEqual(System.Label.RetryApiIssue_ReplayServiceNotAccepting, replayAndReadRefusal(apiIssue), 'Expected the refusal to come from the label');
	}

	/**
	 * @description A request whose handler said it can never succeed (a UTIL_Exceptions.PermanentFailureException) marks
	 * its call as a permanent failure. Its issue is not replayed: the refusal says why, nothing runs, and the issue stays
	 * open.
	 */
	@IsTest
	private static void shouldRefuseToReplayAPermanentCall()
	{
		registerInboundSetting(RECORDING_SERVICE_NAME, new Map<SObjectField, Object>());
		ApiIssue__c apiIssue = failRecordedRequest(TEST_BODY, null, new UTIL_Exceptions.PermanentFailureException(HANDLER_FAILURE_MESSAGE));

		Assert.areEqual(System.Label.RetryApiIssue_PermanentFailure, replayAndReadRefusal(apiIssue), 'Expected the refusal to come from the label');
		Assert.isNull(receivedRequest, 'Expected the handler not to run again');
	}

	/**
	 * @description A request whose handler refused it (a UTIL_Exceptions.RequestRefusedException) does not mark its call
	 * as a permanent failure, so its issue can be run again once the cause is fixed: Retry runs the request, and the issue
	 * is resolved.
	 */
	@IsTest
	private static void shouldReplayARequestTheHandlerRefused()
	{
		registerInboundSetting(RECORDING_SERVICE_NAME, new Map<SObjectField, Object>());
		ApiIssue__c apiIssue = failRecordedRequest(TEST_BODY, null, new UTIL_Exceptions.RequestRefusedException(HANDLER_FAILURE_MESSAGE));
		CTRL_RetryApiIssue.DTO_Response dtoResponse;

		System.runAs(getUserWithApiIssueResolverPermissionSet())
		{
			Test.startTest();
			dtoResponse = CTRL_RetryApiIssue.retry(apiIssue.Id);
			Test.stopTest();
		}

		Assert.isTrue(dtoResponse.callSuccessful, 'Expected the replay to run, got ' + dtoResponse.errorMessage);
		Assert.isNotNull(receivedRequest, 'Expected the handler to receive the replayed request');
		Assert.areEqual(SEL_ApiIssue.STATUS_RESOLVED, ((ApiIssue__c)new SEL_ApiIssue().findById(apiIssue.Id)).Status__c, 'Expected the issue to be resolved');
	}

	/**
	 * @description A body the call no longer holds as it was received (masking changed it after the hash of the body was
	 * recorded) is not replayed: the stored body's hash differs from the recorded one. The refusal says so, nothing runs,
	 * and the issue stays open.
	 */
	@IsTest
	private static void shouldRefuseToReplayAMaskedBody()
	{
		registerInboundSetting(INBOUND_SERVICE_NAME, new Map<SObjectField, Object>());
		ApiIssue__c apiIssue = failEchoRequest(TEST_BODY, null);
		updateField(apiIssue.ApiCall__c, ApiCall__c.Request__c, TEST_BODY.replace('world', '*****'));

		Assert.areEqual(System.Label.RetryApiIssue_StoredRequestDiffers, replayAndReadRefusal(apiIssue), 'Expected the refusal to come from the label');
	}

	/**
	 * @description An address that fills the call's URL__c field to its full length may have been cut when it was saved,
	 * so the request is not replayed. The refusal says the stored request is not the one received, nothing runs, and the
	 * issue stays open.
	 */
	@IsTest
	private static void shouldRefuseToReplayACutUrl()
	{
		registerInboundSetting(INBOUND_SERVICE_NAME, new Map<SObjectField, Object>());
		ApiIssue__c apiIssue = failEchoRequest(TEST_BODY, null);
		String fullLengthUrl = (TEST_PATH + '?' + PARAMETER_NAME + '=').rightPad(SEL_ApiCall.URL_LENGTH, 'x');
		updateField(apiIssue.ApiCall__c, ApiCall__c.URL__c, fullLengthUrl);

		Assert.areEqual(System.Label.RetryApiIssue_StoredRequestDiffers, replayAndReadRefusal(apiIssue), 'Expected the refusal to come from the label');
	}

	/**
	 * @description Retry Selected checks the selected inbound issues before it schedules the job without reading the body
	 * each call kept, so a large selection does not fill the memory the action may use. The test answers every read of API
	 * calls, while the action runs, with the issue's call read without its body: reading the body from that answer throws.
	 * The issue is still handed to the job, and the job, which reads the whole request just before it runs it, replays it
	 * and marks the issue Resolved.
	 */
	@IsTest
	private static void shouldNotReadTheBodyWhenRetrySelectedSchedulesAnInboundIssue()
	{
		registerInboundSetting(INBOUND_SERVICE_NAME, new Map<SObjectField, Object>());
		ApiIssue__c apiIssue = failEchoRequest(TEST_BODY, null);
		TST_Mock.register(ApiCall__c.SObjectType, readCallWithoutItsBody(apiIssue.ApiCall__c));
		CTRL_RetryApiIssue.DTO_ScheduledBulkRetry scheduledRetry;

		System.runAs(getUserWithApiIssueResolverPermissionSet())
		{
			Test.startTest();
			scheduledRetry = CTRL_RetryApiIssue.scheduleBulkRetryOfIssues(new Set<Id> {apiIssue.Id});
			TST_Mock.clear(ApiCall__c.SObjectType);
			Test.stopTest();
		}

		Assert.areEqual(1, scheduledRetry.queuedCount, 'Expected the issue to be handed to the job, got ' + scheduledRetry.queuedCount);
		Assert.isNotNull(scheduledRetry.jobId, 'Expected a job for the issue');
		ApiIssue__c replayedIssue = (ApiIssue__c)new SEL_ApiIssue().findById(apiIssue.Id);
		Assert.areEqual(SEL_ApiIssue.STATUS_RESOLVED, replayedIssue.Status__c, 'Expected the job to replay the request and resolve the issue');
	}

	/**
	 * @description The bulk retry of a service checks its open inbound issues before it schedules the job without reading
	 * the body each call kept, as Retry Selected does. The test answers every read of API calls, while the bulk retry is
	 * scheduled, with the issue's call read without its body: reading the body from that answer throws. A job is still
	 * scheduled.
	 */
	@IsTest
	private static void shouldNotReadTheBodyWhenTheBulkRetryOfAServiceSchedulesItsInboundIssues()
	{
		registerInboundSetting(INBOUND_SERVICE_NAME, new Map<SObjectField, Object>());
		ApiIssue__c apiIssue = failEchoRequest(TEST_BODY, null);
		TST_Mock.register(ApiCall__c.SObjectType, readCallWithoutItsBody(apiIssue.ApiCall__c));
		Id jobId;

		System.runAs(getUserWithApiIssueResolverPermissionSet())
		{
			Test.startTest();
			jobId = CTRL_RetryApiIssue.scheduleBulkRetry(INBOUND_SERVICE_NAME, 0);
			TST_Mock.clear(ApiCall__c.SObjectType);
			Test.stopTest();
		}

		Assert.isNotNull(jobId, 'Expected a job for the open inbound issue of the service');
	}

	/**
	 * @description A call whose body was changed after it was saved can be found only from the body. Retry Selected does
	 * not read the body, so it hands the issue to the job. The job reads the request whole, refuses it, runs nothing and
	 * logs at warn how many issues it did not run. The issue stays open.
	 */
	@IsTest
	private static void shouldLeaveAChangedBodyForTheJobToRefuse()
	{
		LOG_Builder.ignoreTestMode = true;
		registerInboundSetting(INBOUND_SERVICE_NAME, new Map<SObjectField, Object>());
		ApiIssue__c apiIssue = failEchoRequest(TEST_BODY, null);
		updateField(apiIssue.ApiCall__c, ApiCall__c.Request__c, TEST_BODY.replace('world', '*****'));
		CTRL_RetryApiIssue.DTO_ScheduledBulkRetry scheduledRetry;

		System.runAs(getUserWithApiIssueResolverPermissionSet())
		{
			Test.startTest();
			scheduledRetry = CTRL_RetryApiIssue.scheduleBulkRetryOfIssues(new Set<Id> {apiIssue.Id});
			Test.stopTest();
		}

		Assert.areEqual(1, scheduledRetry.queuedCount, 'Expected the issue to be handed to the job, got ' + scheduledRetry.queuedCount);
		Assert.isTrue(findLaterCalls(INBOUND_SERVICE_NAME, apiIssue.ApiCall__c).isEmpty(), 'Expected the job to run nothing');
		Assert.areEqual(SEL_ApiIssue.STATUS_OPEN, ((ApiIssue__c)new SEL_ApiIssue().findById(apiIssue.Id)).Status__c, 'Expected the issue to stay open');
		LogEntry__c warningLog = new SEL_LogEntry().findByMethod(CTRL_RetryApiIssue.class.getName() + '/FailureReplayProcessor');
		Assert.isNotNull(warningLog, 'Expected the job to log the issue it did not run');
		Assert.isTrue(warningLog.ShortMessage__c.startsWith('1 failure replay(s) skipped: Retry Issues is off'), 'Expected the refused count, got ' + warningLog.ShortMessage__c);
	}

	/**
	 * @description Retry Selected still refuses, before it schedules the job, every inbound issue it can refuse without the
	 * body. Of five selected issues, one has no call and no request of its own, one has a call whose address fills its
	 * field, so it may have been cut, and one has a call with no key and no hash, as version 1.8 saved it, whose address
	 * fills its field while the issue holds no request: none is handed to the job. An issue made by hand that holds its
	 * request is handed to the job. So is an issue on a call with no key, no hash and a full-length address that holds its
	 * own request: that request may be run instead, and only the job can tell.
	 */
	@IsTest
	private static void shouldStillRefuseWhatCanBeRefusedWithoutTheBodyWhenRetrySelectedSchedules()
	{
		registerInboundSetting(INBOUND_SERVICE_NAME, new Map<SObjectField, Object>());
		String fullLengthUrl = (TEST_PATH + '?' + PARAMETER_NAME + '=').rightPad(SEL_ApiCall.URL_LENGTH, 'x');
		ApiIssue__c cutAddressIssue = failEchoRequest(TEST_BODY, null);
		updateField(cutAddressIssue.ApiCall__c, ApiCall__c.URL__c, fullLengthUrl);
		ApiIssue__c handMadeIssue = createInboundIssue();
		ApiIssue__c noRequestIssue = (ApiIssue__c)TST_Builder.of(ApiIssue__c.SObjectType)
				.withOverride(ApiIssue__c.Direction__c, SEL_ApiIssue.DIRECTION_INBOUND)
				.withOverride(ApiIssue__c.ServiceName__c, INBOUND_SERVICE_NAME)
				.withOverride(ApiIssue__c.Status__c, SEL_ApiIssue.STATUS_OPEN)
				.build();
		ApiIssue__c noHashIssueWithNoRequest = insertIssueOfCallWithoutAHash(fullLengthUrl, false);
		ApiIssue__c noHashIssueWithItsRequest = insertIssueOfCallWithoutAHash(fullLengthUrl, true);
		CTRL_RetryApiIssue.DTO_ScheduledBulkRetry scheduledRetry;

		System.runAs(getUserWithApiIssueResolverPermissionSet())
		{
			Test.startTest();
			scheduledRetry = CTRL_RetryApiIssue.scheduleBulkRetryOfIssues(new Set<Id>
			{
					cutAddressIssue.Id, handMadeIssue.Id, noRequestIssue.Id, noHashIssueWithNoRequest.Id, noHashIssueWithItsRequest.Id
			});
			Test.stopTest();
		}

		Assert.areEqual(5, scheduledRetry.selectedCount, 'Expected five issues to count as selected, got ' + scheduledRetry.selectedCount);
		Assert.areEqual(2, scheduledRetry.queuedCount,
				'Expected only the hand-made issue and the issue on the call with no hash that holds its own request to be queued, got ' + scheduledRetry.queuedCount);
		Assert.areEqual(SEL_ApiIssue.STATUS_OPEN, ((ApiIssue__c)new SEL_ApiIssue().findById(noHashIssueWithNoRequest.Id)).Status__c,
				'Expected the issue on the call with no hash and no request of its own to be refused before the job and stay open');
		Assert.areEqual(SEL_ApiIssue.STATUS_RESOLVED, ((ApiIssue__c)new SEL_ApiIssue().findById(noHashIssueWithItsRequest.Id)).Status__c,
				'Expected the job to run the request the issue holds and resolve the issue on the call with no hash');
	}

	/**
	 * @description Reads a saved call with its small fields only, and not its body or its parameters: reading the body from
	 * the record returned throws, because the read did not ask for it. A test registers it as the answer to every read of
	 * API calls, so code that reads the body of a call from that answer fails the test.
	 *
	 * @param callId The id of the call
	 *
	 * @return The call, read without its body
	 */
	private static List<ApiCall__c> readCallWithoutItsBody(Id callId)
	{
		return QRY_Builder.selectFrom(ApiCall__c.SObjectType)
				.fields(new List<SObjectField>
				{
						ApiCall__c.CreatedById,
						ApiCall__c.HttpMethod__c,
						ApiCall__c.IdempotencyKeyBodyHash__c,
						ApiCall__c.IdempotencyKey__c,
						ApiCall__c.IsPermanentFailure__c,
						ApiCall__c.URL__c
				})
				.condition(ApiCall__c.Id).equals(callId)
				.withSystemMode()
				.toList();
	}

	/**
	 * @description Saves a failed inbound call of the echo service with no key and no hash of its body, as version 1.8 saved
	 * a request with no key, and an open inbound issue that links to it and, when asked, its own request.
	 *
	 * @param url The address the call kept
	 * @param holdsItsRequest True to give the issue its own request path, method and body, as a person may type them; false to leave the issue with no request
	 *
	 * @return The saved issue
	 */
	@SuppressWarnings('PMD.KernSecurityBypassCallSite')
	private static ApiIssue__c insertIssueOfCallWithoutAHash(String url, Boolean holdsItsRequest)
	{
		ApiCall__c originalCall = TST_Factory.newInboundApiCall(INBOUND_SERVICE_NAME);
		originalCall.Status__c = SEL_ApiCall.STATUS_FAILED;
		originalCall.URL__c = url;
		originalCall.HttpMethod__c = HTTP_POST;
		originalCall.Request__c = TEST_BODY;
		DML_Builder.newTransaction().withSystemMode().doInsert(originalCall).execute();
		TST_Builder.Builder issueBuilder = TST_Builder.of(ApiIssue__c.SObjectType)
				.withOverride(ApiIssue__c.Direction__c, SEL_ApiIssue.DIRECTION_INBOUND)
				.withOverride(ApiIssue__c.ServiceName__c, INBOUND_SERVICE_NAME)
				.withOverride(ApiIssue__c.Status__c, SEL_ApiIssue.STATUS_OPEN)
				.withOverride(ApiIssue__c.ApiCall__c, originalCall.Id);
		if(holdsItsRequest)
		{
			issueBuilder.withOverride(ApiIssue__c.RequestPath__c, TEST_PATH)
					.withOverride(ApiIssue__c.RequestMethod__c, HTTP_POST)
					.withOverride(ApiIssue__c.RequestBody__c, TEST_BODY);
		}
		return (ApiIssue__c)issueBuilder.build();
	}

	/**
	 * @description The bulk retry job checks the setting of every issue itself before it runs it, because the setting may
	 * have changed since the job was scheduled. The test gives the job an inbound issue whose setting has Retry Issues
	 * off. The job runs nothing for the issue, the issue stays open, and the job logs at warn how many issues it did not
	 * run.
	 */
	@IsTest
	private static void shouldRunNothingInTheJobWhenRetryIssuesIsOff()
	{
		LOG_Builder.ignoreTestMode = true;
		registerInboundSetting(INBOUND_SERVICE_NAME, new Map<SObjectField, Object> {ApiSetting__mdt.RetryIssues__c => false});
		ApiIssue__c apiIssue = failEchoRequest(TEST_BODY, null);

		runJobAsUserWithApiIssueResolverPermissionSet(toRequestGroups(new List<Object> {apiIssue}));

		Assert.areEqual(1, new SEL_ApiCall().findByServiceName(INBOUND_SERVICE_NAME).size(), 'Expected the job to run nothing');
		Assert.areEqual(SEL_ApiIssue.STATUS_OPEN, ((ApiIssue__c)new SEL_ApiIssue().findById(apiIssue.Id)).Status__c, 'Expected the issue to stay open');
		LogEntry__c warningLog = new SEL_LogEntry().findByMethod(CTRL_RetryApiIssue.class.getName() + '/FailureReplayProcessor');
		Assert.isNotNull(warningLog, 'Expected the job to log the issue it did not run');
		Assert.isTrue(warningLog.ShortMessage__c.startsWith('1 failure replay(s) skipped: Retry Issues is off'), 'Expected the refused count, got ' + warningLog.ShortMessage__c);
	}

	/**
	 * @description A replay goes to the service the issue names, even when the path now leads to another service: a
	 * setting for the echo service matches the exact path, so routing by the path would send the request there. The
	 * handler of the issue's service receives the request, and the new call names that service.
	 */
	@IsTest
	private static void shouldReplayByTheIssuesServiceWhenTheRouteNowPointsElsewhere()
	{
		registerInboundSetting(RECORDING_SERVICE_NAME, new Map<SObjectField, Object>());
		TST_Factory.newInboundApiSetting
				(
						INBOUND_SERVICE_NAME,
						TEST_PATH,
						ROUTE_PRIORITY,
						new Map<SObjectField, Object> {ApiSetting__mdt.RetryIssues__c => true, ApiSetting__mdt.LogIssues__c => true}
				);
		ApiIssue__c apiIssue = failRecordedRequest(TEST_BODY, null, new UTIL_Exceptions.IllegalStateException(HANDLER_FAILURE_MESSAGE));

		System.runAs(getUserWithApiIssueResolverPermissionSet())
		{
			Test.startTest();
			CTRL_RetryApiIssue.resolveFailure(apiIssue.Id);
			Test.stopTest();
		}

		Assert.isNotNull(receivedRequest, 'Expected the handler of the issue\'s service to receive the replay');
		Assert.areEqual(TEST_PATH, receivedRequest.requestURI, 'Expected the handler to receive the replayed request');
		Assert.areEqual(1, findLaterCalls(RECORDING_SERVICE_NAME, apiIssue.ApiCall__c).size(), 'Expected the new call to name the issue\'s service');
		Assert.isTrue(new SEL_ApiCall().findByServiceName(INBOUND_SERVICE_NAME).isEmpty(), 'Expected nothing sent to the service the path now leads to');
	}

	/**
	 * @description The call a replay makes links to the call the request was read from (PreviousAttempt__c), so the
	 * attempts of one request can be followed from the first to the last.
	 */
	@IsTest
	private static void shouldLinkTheReplayToTheOriginalCall()
	{
		registerInboundSetting(INBOUND_SERVICE_NAME, new Map<SObjectField, Object>());
		ApiIssue__c apiIssue = failEchoRequest(TEST_BODY, null);

		System.runAs(getUserWithApiIssueResolverPermissionSet())
		{
			Test.startTest();
			CTRL_RetryApiIssue.retry(apiIssue.Id);
			Test.stopTest();
		}

		List<ApiCall__c> replayCalls = findLaterCalls(INBOUND_SERVICE_NAME, apiIssue.ApiCall__c);
		Assert.areEqual(1, replayCalls.size(), 'Expected one call for the replay');
		Assert.areEqual(SEL_ApiCall.STATUS_COMPLETED, replayCalls.get(0).Status__c, 'Expected the replay to complete');
		Assert.areEqual(apiIssue.ApiCall__c, replayCalls.get(0).PreviousAttempt__c, 'Expected the replay\'s call to link to the original call');
	}

	/**
	 * @description With idempotency on, a replay of a keyed request the caller has since completed is answered from the
	 * completed call's stored response, and the handler does not run again. The issue is resolved.
	 */
	@SuppressWarnings('PMD.KernSecurityBypassCallSite')
	@IsTest
	private static void shouldAnswerAReplayOfACompletedKeyedRequestFromTheStoredResponse()
	{
		registerInboundSetting(RECORDING_SERVICE_NAME, new Map<SObjectField, Object> {ApiSetting__mdt.IdempotencyEnabled__c => true});
		String idempotencyKey = UTIL_Random.randomUUID();
		ApiIssue__c apiIssue = failRecordedRequest(TEST_BODY, idempotencyKey, new UTIL_Exceptions.IllegalStateException(HANDLER_FAILURE_MESSAGE));
		String storedResponse = JSON.serialize(new Map<String, Object> {PARAMETER_NAME => UTIL_Random.randomName()});
		ApiCall__c completedCall = TST_Factory.newInboundApiCall(RECORDING_SERVICE_NAME);
		completedCall.IdempotencyKey__c = idempotencyKey;
		completedCall.IdempotencyKeyBodyHash__c = API_Inbound.computeBodyHash(TEST_BODY);
		completedCall.Response__c = storedResponse;
		DML_Builder.newTransaction().withSystemMode().doInsert(completedCall).execute();
		CTRL_RetryApiIssue.DTO_Response dtoResponse;

		System.runAs(getUserWithApiIssueResolverPermissionSet())
		{
			Test.startTest();
			dtoResponse = CTRL_RetryApiIssue.retry(apiIssue.Id);
			Test.stopTest();
		}

		Assert.isTrue(dtoResponse.callSuccessful, 'Expected the replay to be answered, got ' + dtoResponse.errorMessage);
		Assert.isNull(receivedRequest, 'Expected the handler not to run again');
		Assert.areEqual(SEL_ApiIssue.STATUS_RESOLVED, ((ApiIssue__c)new SEL_ApiIssue().findById(apiIssue.Id)).Status__c, 'Expected the issue to be resolved');
		Boolean hasAnsweredCall = false;
		for(ApiCall__c laterCall : findLaterCalls(RECORDING_SERVICE_NAME, apiIssue.ApiCall__c))
		{
			hasAnsweredCall = hasAnsweredCall || (laterCall.IsIdempotencyHit__c && laterCall.Response__c == storedResponse);
		}
		Assert.isTrue(hasAnsweredCall, 'Expected a call answered from the stored response');
	}

	/**
	 * @description The Retry action follows the issue's direction: on an inbound issue it replays the request the call
	 * kept, instead of sending an outbound call to the inbound service. The replay completes and the issue is resolved.
	 */
	@IsTest
	private static void shouldRouteRetryOfAnInboundIssueToTheReplay()
	{
		registerInboundSetting(INBOUND_SERVICE_NAME, new Map<SObjectField, Object>());
		ApiIssue__c apiIssue = failEchoRequest(TEST_BODY, null);
		CTRL_RetryApiIssue.DTO_Response dtoResponse;

		System.runAs(getUserWithApiIssueResolverPermissionSet())
		{
			Test.startTest();
			dtoResponse = CTRL_RetryApiIssue.retry(apiIssue.Id);
			Test.stopTest();
		}

		Assert.isTrue(dtoResponse.callSuccessful, 'Expected Retry to replay the inbound request, got ' + dtoResponse.errorMessage);
		List<ApiCall__c> replayCalls = findLaterCalls(INBOUND_SERVICE_NAME, apiIssue.ApiCall__c);
		Assert.areEqual(1, replayCalls.size(), 'Expected one new call');
		Assert.areEqual(SEL_ApiCall.TYPE_INBOUND, replayCalls.get(0).Direction__c, 'Expected the new call to be an inbound replay');
		Assert.areEqual(SEL_ApiIssue.STATUS_RESOLVED, ((ApiIssue__c)new SEL_ApiIssue().findById(apiIssue.Id)).Status__c, 'Expected the issue to be resolved');
	}

	/**
	 * @description A replay that fails writes no new issue: the issue it was run for stays the one open issue of the
	 * request, so running Retry Selected again and again never adds issues. The failed replay's call still links to the
	 * original call.
	 */
	@IsTest
	private static void shouldWriteNoNewIssueWhenTheReplayFails()
	{
		registerInboundSetting(INBOUND_SERVICE_NAME, new Map<SObjectField, Object>());
		ApiIssue__c apiIssue = failEchoRequest(TEST_BODY, null);
		API_Inbound.returnErrorResponse = true;
		CTRL_RetryApiIssue.DTO_Response dtoResponse;

		System.runAs(getUserWithApiIssueResolverPermissionSet())
		{
			Test.startTest();
			dtoResponse = CTRL_RetryApiIssue.retry(apiIssue.Id);
			Test.stopTest();
		}

		Assert.isFalse(dtoResponse.callSuccessful, 'Expected the replay to fail');
		Assert.areEqual(apiIssue.Id, findOnlyOpenIssue(INBOUND_SERVICE_NAME).Id, 'Expected the original issue to stay the one open issue');
		List<ApiCall__c> replayCalls = findLaterCalls(INBOUND_SERVICE_NAME, apiIssue.ApiCall__c);
		Assert.areEqual(1, replayCalls.size(), 'Expected one call for the failed replay');
		Assert.areEqual(SEL_ApiCall.STATUS_FAILED, replayCalls.get(0).Status__c, 'Expected the replay\'s call to fail');
		Assert.areEqual(apiIssue.ApiCall__c, replayCalls.get(0).PreviousAttempt__c, 'Expected the failed replay\'s call to link to the original call');
	}

	/**
	 * @description An outbound call marked as a permanent failure is not sent again: Retry answers with the labelled
	 * message, sends nothing, and the issue stays open.
	 */
	@IsTest
	private static void shouldRefuseToResendAnOutboundCallMarkedPermanent()
	{
		ApiCall__c originalCall = insertFailedOutboundCall(true);
		ApiIssue__c apiIssue = TST_Factory.insertApiIssue(originalCall, UTIL_Crypto.generateMD5Hash(originalCall.RequestParameters__c));
		CTRL_RetryApiIssue.DTO_Response dtoResponse;

		System.runAs(getUserWithApiIssueResolverPermissionSet())
		{
			Test.startTest();
			dtoResponse = CTRL_RetryApiIssue.retry(apiIssue.Id);
			Test.stopTest();
		}

		Assert.isFalse(dtoResponse.callSuccessful, 'Expected Retry to be refused');
		Assert.areEqual(System.Label.RetryApiIssue_PermanentFailure, dtoResponse.errorMessage, 'Expected the refusal to come from the label');
		Assert.isTrue(findLaterCalls(API_PostExample.class.getName(), originalCall.Id).isEmpty(), 'Expected no call to be sent');
		Assert.areEqual(SEL_ApiIssue.STATUS_OPEN, ((ApiIssue__c)new SEL_ApiIssue().findById(apiIssue.Id)).Status__c, 'Expected the issue to stay open');
	}

	/**
	 * @description The call the Retry action sends links to the issue's call (PreviousAttempt__c), so the attempts of one
	 * request can be followed from the first to the last.
	 */
	@IsTest
	private static void shouldLinkTheOutboundRetryCallToTheOriginal()
	{
		ApiCall__c originalCall = insertFailedOutboundCall(false);
		ApiIssue__c apiIssue = TST_Factory.insertApiIssue(originalCall, UTIL_Crypto.generateMD5Hash(originalCall.RequestParameters__c));
		CTRL_RetryApiIssue.DTO_Response dtoResponse;

		System.runAs(getUserWithApiIssueResolverPermissionSet())
		{
			Test.startTest();
			dtoResponse = CTRL_RetryApiIssue.retry(apiIssue.Id);
			Test.stopTest();
		}

		Assert.isTrue(dtoResponse.callSuccessful, 'Expected Retry to succeed, got ' + dtoResponse.errorMessage);
		List<ApiCall__c> retryCalls = findLaterCalls(API_PostExample.class.getName(), originalCall.Id);
		Assert.areEqual(1, retryCalls.size(), 'Expected one call for the retry');
		Assert.areEqual(originalCall.Id, retryCalls.get(0).PreviousAttempt__c, 'Expected the retry\'s call to link to the original call');
	}

	/**
	 * @description A user who holds the Retry API Issue permission dismisses an issue whose call failed permanently: the
	 * issue is marked Resolved with a resolved date, though the user may not edit issues, and nothing is sent again.
	 */
	@IsTest
	private static void shouldDismissAnIssueForAUserWithTheRetryPermission()
	{
		ApiCall__c originalCall = insertFailedOutboundCall(true);
		ApiIssue__c apiIssue = TST_Factory.insertApiIssue(originalCall, UTIL_Crypto.generateMD5Hash(originalCall.RequestParameters__c));
		CTRL_RetryApiIssue.DTO_Response dtoResponse;

		System.runAs(getUserWithApiIssueResolverPermissionSet())
		{
			Test.startTest();
			dtoResponse = new SharingEnforcedCaller().dismiss(apiIssue.Id);
			Test.stopTest();
		}

		Assert.isTrue(dtoResponse.callSuccessful, 'Expected the issue to be dismissed, got ' + dtoResponse.errorMessage);
		ApiIssue__c dismissedIssue = (ApiIssue__c)new SEL_ApiIssue().findById(apiIssue.Id);
		Assert.areEqual(SEL_ApiIssue.STATUS_RESOLVED, dismissedIssue.Status__c, 'Expected the dismissed issue to be Resolved');
		Assert.isNotNull(dismissedIssue.ResolvedDate__c, 'Expected the dismiss to set the resolved date');
		Assert.isTrue(findLaterCalls(API_PostExample.class.getName(), originalCall.Id).isEmpty(), 'Expected nothing to be sent');
	}

	/**
	 * @description A user without the Retry API Issue permission cannot dismiss an issue: the answer carries the labelled
	 * refusal and the issue stays open.
	 */
	@IsTest
	private static void shouldRefuseToDismissWithoutThePermission()
	{
		ApiCall__c originalCall = insertFailedOutboundCall(true);
		ApiIssue__c apiIssue = TST_Factory.insertApiIssue(originalCall, UTIL_Crypto.generateMD5Hash(originalCall.RequestParameters__c));
		CTRL_RetryApiIssue.DTO_Response dtoResponse;

		System.runAs(getUserWithoutRetryPermission())
		{
			Test.startTest();
			dtoResponse = CTRL_RetryApiIssue.dismiss(apiIssue.Id);
			Test.stopTest();
		}

		Assert.isFalse(dtoResponse.callSuccessful, 'Expected the dismiss to be refused');
		Assert.areEqual(System.Label.RetryApiIssue_DismissPermissionRequired, dtoResponse.errorMessage, 'Expected the dismiss refusal to come from its own label');
		Assert.areEqual(SEL_ApiIssue.STATUS_OPEN, ((ApiIssue__c)new SEL_ApiIssue().findById(apiIssue.Id)).Status__c, 'Expected the issue to stay open');
	}

	/**
	 * @description A user who holds the permission but cannot read the issue is told so and dismisses nothing. The id was
	 * never saved, so no read can return it under any sharing default.
	 */
	@IsTest
	private static void shouldRefuseToDismissAnIssueTheUserCannotSee()
	{
		CTRL_RetryApiIssue.DTO_Response dtoResponse;

		System.runAs(getUserWithRetryPermissionWithoutViewAll())
		{
			Test.startTest();
			dtoResponse = new SharingEnforcedCaller().dismiss(UTIL_Random.randomId(ApiIssue__c.SObjectType));
			Test.stopTest();
		}

		Assert.isFalse(dtoResponse.callSuccessful, 'Expected the dismiss to be refused');
		Assert.areEqual(System.Label.RetryApiIssue_IssueNotVisible, dtoResponse.errorMessage, 'Expected the refusal to come from the label');
	}

	/**
	 * @description Dismissing an issue that is already Resolved saves nothing: the answer is a success, the issue stays
	 * Resolved, and its resolved date is not moved to now.
	 */
	@IsTest
	private static void shouldKeepTheResolvedDateWhenDismissingAResolvedIssue()
	{
		ApiCall__c originalCall = insertFailedOutboundCall(true);
		ApiIssue__c apiIssue = TST_Factory.insertApiIssue(originalCall, UTIL_Crypto.generateMD5Hash(originalCall.RequestParameters__c));
		apiIssue.Status__c = SEL_ApiIssue.STATUS_RESOLVED;
		apiIssue.ResolvedDate__c = Datetime.now().addDays(-DAYS_SINCE_EARLIER_RESOLUTION);
		updateIssue(apiIssue);
		Datetime earlierResolvedDate = ((ApiIssue__c)new SEL_ApiIssue().findById(apiIssue.Id)).ResolvedDate__c;
		CTRL_RetryApiIssue.DTO_Response dtoResponse;

		System.runAs(getUserWithApiIssueResolverPermissionSet())
		{
			Test.startTest();
			dtoResponse = new SharingEnforcedCaller().dismiss(apiIssue.Id);
			Test.stopTest();
		}

		Assert.isTrue(dtoResponse.callSuccessful, 'Expected dismissing a closed issue to answer success, got ' + dtoResponse.errorMessage);
		ApiIssue__c dismissedIssue = (ApiIssue__c)new SEL_ApiIssue().findById(apiIssue.Id);
		Assert.areEqual(SEL_ApiIssue.STATUS_RESOLVED, dismissedIssue.Status__c, 'Expected the issue to stay Resolved');
		Assert.areEqual(earlierResolvedDate, dismissedIssue.ResolvedDate__c, 'Expected the resolved date to stay as it was');
	}

	/**
	 * @description Asks, as a resolver, for an inbound issue to be run again, asserts that the replay was refused, that
	 * nothing ran, and that the issue stays open, and returns the message the refusal carries for the test to check.
	 *
	 * @param apiIssue The inbound issue, written by a failed request
	 *
	 * @return The message the refusal carries
	 */
	private static String replayAndReadRefusal(ApiIssue__c apiIssue)
	{
		CTRL_RetryApiIssue.DTO_Response dtoResponse;
		System.runAs(getUserWithApiIssueResolverPermissionSet())
		{
			Test.startTest();
			dtoResponse = CTRL_RetryApiIssue.retry(apiIssue.Id);
			Test.stopTest();
		}

		Assert.isFalse(dtoResponse.callSuccessful, 'Expected the replay to be refused');
		Assert.isTrue(findLaterCalls(apiIssue.ServiceName__c, apiIssue.ApiCall__c).isEmpty(), 'Expected nothing to run');
		Assert.areEqual(SEL_ApiIssue.STATUS_OPEN, ((ApiIssue__c)new SEL_ApiIssue().findById(apiIssue.Id)).Status__c, 'Expected the issue to stay open');
		return dtoResponse.errorMessage;
	}

	/**
	 * @description An inbound handler that records the request it receives, and fails while a test sets a failure for it.
	 */
	public inherited sharing class ReplayRecordingInbound extends API_Inbound
	{
		/**
		 * @description Throws the failure the test set, or records the request it received.
		 */
		public override void processRequest()
		{
			if(handlerFailure != null)
			{
				throw handlerFailure;
			}
			receivedRequest = request;
		}
	}

	/**
	 * @description Calls the retry controller the way the record page and the Retry Selected flow do: with the running
	 * user's record sharing applied. This test class declares no sharing, so a call made straight from a test method does
	 * not apply record sharing the way the page and the flow do.
	 */
	private with sharing class SharingEnforcedCaller
	{
		/**
		 * @description Retries one issue, as the Retry button on the issue's record page does.
		 *
		 * @param issueId The id of the issue
		 *
		 * @return Whether the call succeeded, and the error when it did not
		 */
		public CTRL_RetryApiIssue.DTO_Response retry(Id issueId)
		{
			return CTRL_RetryApiIssue.retry(issueId);
		}

		/**
		 * @description Resolves one issue, as the resolve action on the issue's record page does.
		 *
		 * @param issueId The id of the issue
		 *
		 * @return Whether the call or replay succeeded, and the error when it did not
		 */
		public CTRL_RetryApiIssue.DTO_Response resolveFailure(Id issueId)
		{
			return CTRL_RetryApiIssue.resolveFailure(issueId);
		}

		/**
		 * @description Dismisses one issue, as the dismiss action on the issue's record page does.
		 *
		 * @param issueId The id of the issue
		 *
		 * @return Whether the issue was marked Resolved, and the reason when it was not
		 */
		public CTRL_RetryApiIssue.DTO_Response dismiss(Id issueId)
		{
			return CTRL_RetryApiIssue.dismiss(issueId);
		}

		/**
		 * @description Runs the bulk retry job on the given items.
		 *
		 * @param items The groups of issue ids the job holds
		 */
		public void runBulkRetryJob(List<Object> items)
		{
			new CTRL_RetryApiIssue.FailureReplayProcessor().execute(items);
		}

		/**
		 * @description Asks for a retry of the selected issues, as the Retry Selected flow does.
		 *
		 * @param issueIds The ids of the selected issues
		 *
		 * @return How many issues were selected and queued, and the job id
		 */
		public CTRL_RetryApiIssue.DTO_ScheduledBulkRetry scheduleBulkRetryOfIssues(Set<Id> issueIds)
		{
			return CTRL_RetryApiIssue.scheduleBulkRetryOfIssues(issueIds);
		}
	}

	/**
	 * @description An outbound service that sends the same request as API_PostExample, and records how much memory the
	 * run is using when the call is checked before it is sent.
	 */
	public inherited sharing class MemoryRecordingOutbound extends API_Outbound
	{
		/**
		 * @description Sets the request and response the call uses, and the answer the test callout gives.
		 */
		public override void configure()
		{
			super.configure();
			requestPayload = new API_PostExample.DTO_Request();
			responsePayload = new API_PostExample.DTO_Response();
			defaultMockBody = MOCK_RESPONSE_BODY;
		}

		/**
		 * @description Records the memory the run is using while the call is being sent, and finds no error.
		 *
		 * @return No errors
		 */
		public override List<String> getValidationErrors()
		{
			heapUsedWhileSending = UTIL_Limits.heapSize().used();
			return new List<String>();
		}
	}
}