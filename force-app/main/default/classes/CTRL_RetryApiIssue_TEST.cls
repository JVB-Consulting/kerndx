// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Test Class for CTRL_RetryApiIssue
 *
 * @see CTRL_RetryApiIssue
 *
 * @author Jason van Beukering
 *
 * @group Controllers
 *
 * @date February 2026, October 2026
 */
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs,PMD.CyclomaticComplexity')
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
	 * @description How many open issues the bulk retry test sends together.
	 */
	private static final Integer BULK_ISSUE_COUNT = 3;

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
	 * @description Creates a real ApiIssue with inbound direction and request details.
	 *
	 * @return The inserted ApiIssue__c record
	 */
	@SuppressWarnings('PMD.KernSecurityBypassCallSite')
	private static ApiIssue__c createInboundIssue()
	{
		ApiCall__c apiCall = TST_Factory.newOutboundApiCall(INBOUND_SERVICE_NAME, UserInfo.getUserId(), UTIL_Random.randomName(), UTIL_Random.randomName());
		ApiIssue__c apiIssue = TST_Factory.insertApiIssue(apiCall, UTIL_Crypto.generateMD5Hash(apiCall.RequestParameters__c));

		apiIssue.Direction__c = SEL_ApiIssue.DIRECTION_INBOUND;
		apiIssue.RequestPath__c = TEST_PATH;
		apiIssue.RequestMethod__c = HTTP_POST;
		apiIssue.RequestBody__c = TEST_BODY;
		DML_Builder.newTransaction().withSystemMode().doUpdate(apiIssue).execute();

		return apiIssue;
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
		TST_Factory.newInboundApiSetting(INBOUND_SERVICE_NAME, '/echo/*');
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
	 * This occurs when no matching inbound route is configured for the failure's request path.
	 */
	@SuppressWarnings('PMD.KernSecurityBypassCallSite')
	@IsTest
	private static void shouldUseFallbackMessageWhenReplayHasBlankErrorText()
	{
		ApiIssue__c apiIssue = createInboundIssue();
		apiIssue.RequestPath__c = '/nonexistent/route/' + UTIL_Random.randomName();
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
		TST_Factory.newInboundApiSetting(INBOUND_SERVICE_NAME, '/echo/*');
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
		TST_Factory.newInboundApiSetting(INBOUND_SERVICE_NAME, '/echo/*');
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
		TST_Factory.newInboundApiSetting(INBOUND_SERVICE_NAME, '/echo/*');
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
		TST_Factory.newInboundApiSetting(INBOUND_SERVICE_NAME, '/echo/*');
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
		TST_Factory.newInboundApiSetting(INBOUND_SERVICE_NAME, '/echo/*');
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
		TST_Factory.newInboundApiSetting(INBOUND_SERVICE_NAME, '/echo/*');
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
		ApiIssue__c unreplayedIssue = (ApiIssue__c)new SEL_ApiIssue().findById(inboundIssue.Id);
		Assert.areEqual(SEL_ApiIssue.STATUS_OPEN, unreplayedIssue.Status__c, 'Expected the inbound issue to stay Open');
		Assert.isNull(unreplayedIssue.ResolvedDate__c, 'Expected the inbound request not to be replayed');
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
}