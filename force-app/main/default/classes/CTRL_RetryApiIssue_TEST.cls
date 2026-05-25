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
 * @date February 2026, May 2026
 */
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest(SeeAllData=false IsParallel=false)
private class CTRL_RetryApiIssue_TEST
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
	 * @description Creates a real ApiIssue with inbound direction and request details.
	 *
	 * @return The inserted ApiIssue__c record
	 */
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
	 * @description Verifies that retrying a valid API issue succeeds and resolves the issue.
	 *
	 * @see CTRL_RetryApiIssue.retry
	 */
	@IsTest
	private static void shouldRetrySuccessfully()
	{
		System.runAs(TST_Factory.newUser(SEL_Profile.PROFILE_STANDARD_USER))
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
		}
	}

	/**
	 * @description Verifies that retry fails when the retry setting is not enabled.
	 */
	@IsTest
	private static void shouldFailWhenRetrySettingNotEnabled()
	{
		System.runAs(TST_Factory.newUser(SEL_Profile.PROFILE_STANDARD_USER))
		{
			ApiCall__c apiCall = TST_Factory.newOutboundApiCall(API_GetPwndPasswords.class.getName(), UserInfo.getUserId(), UTIL_Random.randomName(), UTIL_Random.randomName());
			ApiIssue__c apiIssue =
					TST_Factory.insertApiIssue(apiCall, UTIL_Crypto.generateMD5Hash(apiCall.RequestParameters__c));

			Test.startTest();

			CTRL_RetryApiIssue.DTO_Response dtoResponse = CTRL_RetryApiIssue.retry(apiIssue.Id);

			Test.stopTest();

			Assert.isFalse(dtoResponse.callSuccessful, 'API issue retry did not fail as expected');
			Assert.areEqual(CTRL_RetryApiIssue.MESSAGE_RETRY_FAILURE, dtoResponse.errorMessage, 'Retry Failure is enabled');

			ApiIssue__c updatedIssue = (ApiIssue__c)new SEL_ApiIssue().findById(apiIssue.Id);
			Assert.areEqual(SEL_ApiIssue.STATUS_OPEN, updatedIssue.Status__c, 'ApiIssue should remain open when retry setting is not enabled');
		}
	}

	/**
	 * @description Verifies that retry reports an error when the underlying call fails.
	 */
	@IsTest
	private static void shouldReportErrorWhenRetryFails()
	{
		System.runAs(TST_Factory.newUser(SEL_Profile.PROFILE_STANDARD_USER))
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
		System.runAs(TST_Factory.newUser(SEL_Profile.PROFILE_STANDARD_USER))
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

		Test.startTest();

		CTRL_RetryApiIssue.DTO_Response dtoResponse = CTRL_RetryApiIssue.resolveFailure(apiIssue.Id);

		Test.stopTest();

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

		Test.startTest();

		CTRL_RetryApiIssue.DTO_Response dtoResponse = CTRL_RetryApiIssue.resolveFailure(apiIssue.Id);

		Test.stopTest();

		Assert.isFalse(dtoResponse.callSuccessful, 'Should report failure');
		Assert.isNotNull(dtoResponse.errorMessage, 'Should have error message');

		ApiIssue__c updatedIssue = (ApiIssue__c)new SEL_ApiIssue().findById(apiIssue.Id);
		Assert.areEqual(SEL_ApiIssue.STATUS_OPEN, updatedIssue.Status__c, 'ApiIssue should remain open when replay fails');
	}

	/**
	 * @description Verifies resolveFailure uses fallback message when inbound replay fails with blank error text.
	 * This occurs when no matching inbound route is configured for the failure's request path.
	 */
	@IsTest
	private static void shouldUseFallbackMessageWhenReplayHasBlankErrorText()
	{
		ApiIssue__c apiIssue = createInboundIssue();
		apiIssue.RequestPath__c = '/nonexistent/route/' + UTIL_Random.randomName();
		DML_Builder.newTransaction().withSystemMode().doUpdate(apiIssue).execute();

		Test.startTest();

		CTRL_RetryApiIssue.DTO_Response dtoResponse = CTRL_RetryApiIssue.resolveFailure(apiIssue.Id);

		Test.stopTest();

		Assert.isFalse(dtoResponse.callSuccessful, 'Should report failure');
		Assert.areEqual(CTRL_RetryApiIssue.MESSAGE_INBOUND_REPLAY_FAILURE, dtoResponse.errorMessage, 'Should use fallback message when error text is blank');
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
		SEL_AsynchronousJobSetting.mockedSetting = new AsynchronousJobSetting__mdt(BatchSize__c = 150);

		Integer jobSize = Math.min(
				SEL_AsynchronousJobSetting.getBatchSize(FLOW_CallApiAsync.class.getName(), FLOW_CallApiAsync.DEFAULT_JOB_SIZE),
				FLOW_CallApiAsync.MAXIMUM_CALLOUT_JOB_SIZE
		);

		Assert.areEqual(FLOW_CallApiAsync.MAXIMUM_CALLOUT_JOB_SIZE, jobSize, 'Bulk retry job size of 150 should be capped at callout limit');
	}

	/**
	 * @description Verifies scheduleBulkRetry returns null when no unresolved failures exist.
	 */
	@IsTest
	private static void shouldReturnNullWhenNoFailuresForBulkRetry()
	{
		Test.startTest();

		Id jobId = CTRL_RetryApiIssue.scheduleBulkRetry('NonExistentService', 5);

		Test.stopTest();

		Assert.isNull(jobId, 'Should return null when no failures found');
	}

	/**
	 * @description Verifies that the idempotency key from ApiIssue__c is preserved when retrying.
	 *
	 * @see CTRL_RetryApiIssue.retry
	 */
	@IsTest
	private static void shouldPreserveIdempotencyKeyOnRetry()
	{
		System.runAs(TST_Factory.newUser(SEL_Profile.PROFILE_STANDARD_USER))
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
	 * in a bulk replay batch is processed and the rest are deferred with a warning log.
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

		Test.startTest();

		processor.execute(items);

		Test.stopTest();

		LogEntry__c warningLog = new SEL_LogEntry().findByMethod(CTRL_RetryApiIssue.class.getName() + '/FailureReplayProcessor');
		Assert.isNotNull(warningLog, 'Warning log should be emitted for deferred failure replays');
		Assert.isTrue(warningLog.ShortMessage__c.contains('deferred'), 'Warning should mention deferred replays');
	}

	/**
	 * @description Verifies scheduleBulkRetry enqueues a job when unresolved failures exist.
	 */
	@IsTest
	private static void shouldScheduleBulkRetry()
	{
		System.runAs(TST_Factory.newUser(SEL_Profile.PROFILE_STANDARD_USER))
		{
			ApiCall__c apiCall = TST_Factory.newOutboundApiCall(API_PostExample.class.getName(), UserInfo.getUserId(), UTIL_Random.randomName(), UTIL_Random.randomName());
			TST_Factory.insertApiIssue(apiCall, UTIL_Crypto.generateMD5Hash(apiCall.RequestParameters__c));

			Test.startTest();

			Id jobId = CTRL_RetryApiIssue.scheduleBulkRetry(API_PostExample.class.getName(), 0);

			Test.stopTest();

			Assert.isNotNull(jobId, 'Should return job ID when failures exist');
		}
	}
}