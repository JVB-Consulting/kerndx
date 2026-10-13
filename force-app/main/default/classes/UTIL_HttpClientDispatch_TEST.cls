// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Tests for the outbound client's delegation mode, handler resolution and mock routing.
 *
 * @see UTIL_HttpClient
 *
 * @author Jason van Beukering
 *
 * @group Web Services
 *
 * @date August 2026, October 2026
 */
@IsTest(seeAllData=false isParallel=false)
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs,PMD.ApexUnitTestClassShouldHaveAsserts')
private class UTIL_HttpClientDispatch_TEST
{
	/**
	 * @description Test credential name.
	 */
	private static final String TEST_CREDENTIAL = 'TestCredential';

	/**
	 * @description Test URL path for callouts.
	 */
	private static final String TEST_PATH = '/api/v1/resource';

	/**
	 * @description The service name for DefaultOutboundHandler mock registration.
	 * DefaultOutboundHandler.getServiceName() returns the credential name.
	 */
	private static final String HANDLER_SERVICE = TEST_CREDENTIAL;

	/**
	 * @description Valid JSON response body for success mocks.
	 */
	private static final String RESPONSE_BODY = '{"status":"ok","id":"12345"}';

	/**
	 * @description The message of the failure a handler raises before it has taken the call record in hand.
	 */
	private static final String MESSAGE_THROWN_BEFORE_PROCESSING = 'The handler fails before it takes the call in hand';

	/**
	 * @description The retry budget the caller gives a delegated call.
	 */
	private static final Integer MAXIMUM_RETRIES = 3;

	/**
	 * @description The wait before a retry, long enough that a retry is scheduled rather than skipped.
	 */
	private static final Integer RETRY_BACKOFF_SECONDS = 10;
	/**
	 * @description An email value the platform refuses to save, so a handler's commit fails.
	 */
	private static final String INVALID_EMAIL = 'not-an-email';

	/**
	 * @description Registers a mock response for the DefaultOutboundHandler with the given parameters.
	 *
	 * @param body The JSON response body
	 * @param statusCode The HTTP status code
	 * @param status The HTTP status text
	 */
	private static void registerMock(String body, Integer statusCode, String status)
	{
		API_MockFactory.forService(HANDLER_SERVICE)
				.body(body).statusCode(statusCode).status(status).register();
	}

	/**
	 * @description Registers a success mock for the DefaultOutboundHandler.
	 */
	private static void registerSuccessMock()
	{
		registerMock(RESPONSE_BODY, API_Base.HTTP_OK, 'OK');
	}

	/**
	 * @description Tests that invoke() returns the handler instance.
	 */
	@IsTest
	private static void shouldReturnHandlerViaInvokeTerminal()
	{
		registerSuccessMock();

		UTIL_HttpClient.RequestBuilder builder = UTIL_HttpClient.get(TEST_CREDENTIAL, TEST_PATH);

		Test.startTest();
		API_Outbound handler = builder.invoke();
		Test.stopTest();

		assertNotAborted(builder);
		Assert.isNotNull(handler, 'Handler should be returned');
		Assert.isNotNull(handler.getHttpResponse(), 'Handler response should be set');
	}

	/**
	 * @description Tests that abort conditions propagate from delegate handler when required inputs are not satisfied.
	 */
	@IsTest
	private static void shouldAbortDelegateWhenValidationFails()
	{
		Test.startTest();
		API_Outbound handler = UTIL_HttpClient.useHandler(API_GetPwndPasswords.class)
				.withParameter('nonRequiredParam', 'someValue')
				.invoke();
		Test.stopTest();

		Assert.isTrue(handler.result.isAborted, 'Should abort when required input is missing');
	}

	/**
	 * @description Tests that withMockResponse() works in ad-hoc mode.
	 */
	@IsTest
	private static void shouldUseMockResponseOnAdHocRequest()
	{
		API_MockFactory.MockResponse mock = new API_MockFactory.MockResponse();
		mock.body = RESPONSE_BODY;

		HttpResponse response = assertSend(UTIL_HttpClient.get(TEST_CREDENTIAL, TEST_PATH).withMockResponse(mock));

		Assert.areEqual(RESPONSE_BODY, response.getBody(), 'Should use injected mock');
	}

	/**
	 * @description Tests that mock response headers are applied to the HttpResponse.
	 *
	 * @see API_MockFactory.CalloutMock
	 */
	@IsTest
	private static void shouldApplyMockResponseHeaders()
	{
		API_MockFactory.MockResponse mock = new API_MockFactory.MockResponse();
		mock.body = RESPONSE_BODY;
		mock.headers = new Map<String, String>
		{
				'X-Request-Id' => 'req-12345',
				'X-Correlation-Id' => 'corr-67890'
		};

		HttpResponse response = assertSend(UTIL_HttpClient.get(TEST_CREDENTIAL, TEST_PATH).withMockResponse(mock), API_Base.HTTP_OK);

		Assert.areEqual('req-12345', response.getHeader('X-Request-Id'), 'Custom header should be applied');
		Assert.areEqual('corr-67890', response.getHeader('X-Correlation-Id'), 'Custom header should be applied');
	}

	/**
	 * @description Tests that the default mock is used when no mock response is injected.
	 */
	@IsTest
	private static void shouldUseDefaultMockWhenNoMockInjected()
	{
		HttpResponse response = assertSend(UTIL_HttpClient.get(TEST_CREDENTIAL, TEST_PATH), API_Base.HTTP_OK);

		Assert.areEqual('{"success":true}', response.getBody(), 'Should use default mock body');
	}

	/**
	 * @description Tests that prepareRequest is a no-op override for ad-hoc mode.
	 */
	@IsTest
	private static void shouldSupportPrepareRequestOverride()
	{
		registerSuccessMock();

		UTIL_HttpClient.RequestBuilder builder = UTIL_HttpClient.get(TEST_CREDENTIAL, TEST_PATH);
		assertSend(builder);

		builder.handlerInstance.prepareRequest();
		Assert.isTrue(builder.handlerInstance.result.isSuccess, 'Handler should remain successful after prepareRequest no-op');
	}

	/**
	 * @description Tests delegation mode with no subscriber parameters.
	 */
	@IsTest
	private static void shouldDelegateWithNoSubscriberParameters()
	{
		Test.startTest();
		API_Outbound handler = UTIL_HttpClient.useHandler(API_GetPwndPasswords.class).invoke();
		Test.stopTest();

		Assert.isTrue(handler.result.isAborted, 'Should abort when required inputs are missing');
	}

	/**
	 * @description Tests that an ApiCall__c record is persisted when delegation mode aborts.
	 */
	@IsTest
	private static void shouldPersistApiCallWhenDelegateAborts()
	{
		Test.startTest();
		UTIL_HttpClient.useHandler(API_GetPwndPasswords.class).invoke();
		Test.stopTest();

		SEL_ApiCall.assertServiceAborted(API_GetPwndPasswords.class.getName());
	}

	/**
	 * @description Tests that an ApiCall__c record is persisted when delegation mode succeeds.
	 */
	@IsTest
	private static void shouldPersistApiCallWhenDelegateSucceeds()
	{
		Test.startTest();
		UTIL_HttpClient.useHandler(API_GetPwndPasswords.class)
				.withParameter(API_GetPwndPasswords.PARAMETER_PASSWORD, API_GetPwndPasswords.TEST_PASSWORD)
				.invoke();
		Test.stopTest();

		SEL_ApiCall.assertServiceCompleted(API_GetPwndPasswords.class.getName());
	}

	/**
	 * @description Tests that delegation mode auto-applies settings and enables mocking when the
	 * subscriber handler has no ApiSetting__mdt record but provides a defaultMockBody.
	 */
	@IsTest
	private static void shouldAutoApplySettingsWhenDelegateHandlerLacksCMDT()
	{
		Test.startTest();
		API_Outbound handler = UTIL_HttpClient.useHandler(TestDelegationHandler.class)
				.withParameter('input', 'test')
				.invoke();
		Test.stopTest();

		Assert.isTrue(handler.result.isSuccess, 'Handler should succeed via auto-mocking');
		Assert.isFalse(handler.result.isAborted, 'Handler should not be aborted');
		SEL_ApiCall.assertServiceCompleted(TestDelegationHandler.class.getName());
		Assert.areEqual(0, LOG_Engine.getContextStackDepth(), 'A delegation that succeeds leaves no context behind');
	}

	/**
	 * @description Tests that delegation mode catches unexpected exceptions from the subscriber
	 * handler and persists the ApiCall__c as failed.
	 */
	@IsTest
	private static void shouldCatchDelegateHandlerUnexpectedError()
	{
		Test.startTest();
		API_Outbound handler = UTIL_HttpClient.useHandler(TestThrowingHandler.class)
				.withParameter('input', 'test')
				.invoke();
		Test.stopTest();

		Assert.isFalse(handler.result.isSuccess, 'Handler should not report success');
		SEL_ApiCall.assertServiceFailed(TestThrowingHandler.class.getName());
	}

	/**
	 * @description Tests that delegating to a subscriber handler that fails leaves no logging context behind.
	 */
	@IsTest
	private static void shouldLeaveNoContextBehindWhenTheDelegatedHandlerThrows()
	{
		Test.startTest();
		UTIL_HttpClient.useHandler(TestThrowingHandler.class)
				.withParameter('input', 'test')
				.invoke();
		Test.stopTest();

		Assert.areEqual(0, LOG_Engine.getContextStackDepth(), 'Delegating to a handler that fails leaves no logging context behind.');
	}

	/**
	 * @description Tests that delegating to a subscriber handler that fails before it takes the call record in hand
	 * raises no second exception: the handler reports the original failure, the call record carries it, and no call
	 * context is left behind in the logging engine.
	 */
	@IsTest
	private static void shouldRecordTheFailureWhenTheDelegatedHandlerThrowsBeforeProcessing()
	{
		Test.startTest();
		API_Outbound handler = UTIL_HttpClient.useHandler(TestThrowingBeforeProcessingHandler.class)
				.withParameter('input', 'test')
				.invoke();
		Test.stopTest();

		Assert.isTrue(handler.result.hasFailed, 'A handler that fails before it processes reports the failure.');
		Assert.isTrue(handler.result.errors.contains(MESSAGE_THROWN_BEFORE_PROCESSING), 'The handler reports the original failure: ' + handler.result.errors);
		SEL_ApiCall.assertServiceFailed(TestThrowingBeforeProcessingHandler.class.getName(), MESSAGE_THROWN_BEFORE_PROCESSING);
		Assert.isTrue(LOG_Engine.webserviceContextsByCorrelation.isEmpty(), 'A delegation leaves no call context behind in the logging engine.');
	}

	/**
	 * @description Tests that a delegated call whose handler's records the platform refuses to save, after the external
	 * system responded with a success, ends Failed with the refusal on the row, is not scheduled again, and has one issue
	 * that says the external system may have acted.
	 */
	@IsTest
	private static void shouldRecordACommitFailureOfTheDelegatedHandler()
	{
		String serviceName = TestCommitRefusedHandler.class.getName();

		Test.startTest();
		API_Outbound handler = UTIL_HttpClient.useHandler(TestCommitRefusedHandler.class)
				.onFailure(UTIL_HttpClient.FailureAction.RETRY_THEN_LOG)
				.withRetry(MAXIMUM_RETRIES, RETRY_BACKOFF_SECONDS)
				.withParameter('input', 'test')
				.invoke();
		Test.stopTest();

		Assert.isTrue(handler.result.hasFailed, 'Expected a refused commit to report the failure, got ' + handler.result.errors);
		ApiCall__c failedCall = SEL_ApiCall.assertServiceFailed(serviceName, INVALID_EMAIL)[0];
		Assert.isNull(failedCall.NextRetry__c, 'Expected a failure after a success to schedule nothing, got ' + failedCall.NextRetry__c);
		List<ApiIssue__c> issues = new SEL_ApiIssue().findUnresolvedByService(serviceName);
		Assert.areEqual(1, issues.size(), 'Expected one issue, got ' + issues.size());
		Assert.isTrue(issues[0].ExternalSystemMayHaveActed__c, 'Expected the issue to say the external system may have acted, got false');
	}

	/**
	 * @description Tests that caller-provided credential overrides the subscriber handler default in delegation mode.
	 */
	@IsTest
	private static void shouldOverrideCredentialInDelegationMode()
	{
		String handlerName = TestDelegationHandler.class.getName();
		API_MockFactory.enableMocking(handlerName);

		Test.startTest();
		API_Outbound handler = UTIL_HttpClient.useHandler(TestDelegationHandler.class)
				.credential('OverrideCredential')
				.withParameter('input', 'test')
				.invoke();
		Test.stopTest();

		Assert.areEqual('OverrideCredential', handler.namedCredentialOverride, 'Credential should be overridden');
		Assert.isTrue(handler.result.isSuccess, 'Handler should succeed with mock enabled');
	}

	/**
	 * @description Tests that caller-provided path overrides the subscriber handler default in delegation mode.
	 */
	@IsTest
	private static void shouldOverridePathInDelegationMode()
	{
		Test.startTest();
		API_Outbound handler = UTIL_HttpClient.useHandler(TestDelegationHandler.class)
				.path('/v2/override')
				.withParameter('input', 'test')
				.invoke();
		Test.stopTest();

		Assert.areEqual('/v2/override', handler.setting.EndpointPath__c, 'Endpoint path should be overridden');
		Assert.isTrue(handler.result.isSuccess, 'Handler should succeed via auto-mocking');
	}

	/**
	 * @description Tests that caller-provided retry count overrides the subscriber handler default in delegation mode.
	 */
	@IsTest
	private static void shouldOverrideRetryInDelegationMode()
	{
		Test.startTest();
		API_Outbound handler = UTIL_HttpClient.useHandler(TestDelegationHandler.class)
				.withRetry(5)
				.withParameter('input', 'test')
				.invoke();
		Test.stopTest();

		Assert.areEqual(5, handler.setting.MaxRetryCount__c, 'Max retry count should be overridden');
		Assert.isTrue(handler.result.isSuccess, 'Handler should succeed via auto-mocking');
	}

	/**
	 * @description Tests that a key given with withIdempotencyKey is sent and recorded when the call is delegated to a
	 * handler whose setting does not have Idempotency Enabled.
	 */
	@IsTest
	private static void shouldSendTheCallersIdempotencyKeyInDelegationMode()
	{
		String idempotencyKey = UTIL_Random.randomUUID();

		Test.startTest();
		API_Outbound handler = UTIL_HttpClient.useHandler(TestDelegationHandler.class)
				.withIdempotencyKey(idempotencyKey)
				.withParameter('input', 'test')
				.invoke();
		Test.stopTest();

		Assert.isTrue(handler.result.isSuccess, 'Expected the delegated call to succeed: ' + handler.result.errors);
		Assert.areEqual(idempotencyKey, handler.result.requestHeaders.get(API_Base.HEADER_IDEMPOTENCY_KEY), 'Expected the request sent to carry the key.');
		ApiCall__c storedCall = SEL_ApiCall.assertServiceCompleted(TestDelegationHandler.class.getName())[0];
		Assert.areEqual(idempotencyKey, storedCall.IdempotencyKey__c, 'Expected the call to record the key that was sent.');
	}

	/**
	 * @description Tests that a delegated call sends no idempotency key when the caller gave none and the handler's
	 * setting does not have Idempotency Enabled.
	 */
	@IsTest
	private static void shouldSendNoIdempotencyKeyInDelegationModeWhenNoneIsGiven()
	{
		Test.startTest();
		API_Outbound handler = UTIL_HttpClient.useHandler(TestDelegationHandler.class)
				.withParameter('input', 'test')
				.invoke();
		Test.stopTest();

		Assert.isTrue(handler.result.isSuccess, 'Expected the delegated call to succeed: ' + handler.result.errors);
		Assert.isNull(handler.result.requestHeaders.get(API_Base.HEADER_IDEMPOTENCY_KEY), 'Expected the request sent to carry no key.');
		ApiCall__c storedCall = SEL_ApiCall.assertServiceCompleted(TestDelegationHandler.class.getName())[0];
		Assert.isNull(storedCall.IdempotencyKey__c, 'Expected the call to record no key.');
	}

	/**
	 * @description Tests that a delegated POST answered with a 500 is scheduled for another attempt when the caller gave
	 * it an idempotency key, because the key makes it safe to send again.
	 */
	@IsTest
	private static void shouldRetryAKeyedPostAfterServerErrorInDelegationMode()
	{
		registerServerErrorForTheDelegationHandler();

		Test.startTest();
		UTIL_HttpClient.useHandler(TestDelegationHandler.class)
				.withIdempotencyKey(UTIL_Random.randomUUID())
				.withRetry(MAXIMUM_RETRIES, RETRY_BACKOFF_SECONDS)
				.withParameter('input', 'test')
				.invoke();
		Test.stopTest();

		SEL_ApiCall.assertServiceRetrying(TestDelegationHandler.class.getName());
	}

	/**
	 * @description Tests that a delegated POST answered with a 500 is not sent again when it carries no idempotency key,
	 * because the external system may already have acted on it.
	 */
	@IsTest
	private static void shouldNotRetryAnUnkeyedPostAfterServerErrorInDelegationMode()
	{
		registerServerErrorForTheDelegationHandler();

		Test.startTest();
		UTIL_HttpClient.useHandler(TestDelegationHandler.class)
				.withRetry(MAXIMUM_RETRIES, RETRY_BACKOFF_SECONDS)
				.withParameter('input', 'test')
				.invoke();
		Test.stopTest();

		SEL_ApiCall.assertServiceFailed(TestDelegationHandler.class.getName());
	}

	/**
	 * @description Registers a 500 answer for the delegation test handler.
	 */
	private static void registerServerErrorForTheDelegationHandler()
	{
		API_MockFactory.forService(TestDelegationHandler.class.getName())
				.body(RESPONSE_BODY).statusCode(API_Base.HTTP_INTERNAL_SERVER_ERROR).status('Internal Server Error').register();
	}

	/**
	 * @description Tests that handler CMDT values are preserved when the caller provides no overrides.
	 */
	@IsTest
	private static void shouldFallBackToHandlerDefaultsWithoutOverrides()
	{
		String handlerName = TestDelegationHandlerWithCMDT.class.getName();
		API_MockFactory.enableMocking(handlerName);

		Test.startTest();
		API_Outbound handler = UTIL_HttpClient.useHandler(TestDelegationHandlerWithCMDT.class)
				.withParameter('input', 'test')
				.invoke();
		Test.stopTest();

		Assert.areEqual('OriginalCredential', handler.namedCredentialOverride, 'Credential should be preserved from handler CMDT');
		Assert.areEqual('/original/path', handler.setting.EndpointPath__c, 'Endpoint path should be preserved from handler CMDT');
		Assert.areEqual(2, handler.setting.MaxRetryCount__c, 'Max retry count should be preserved from handler CMDT');
	}

	/**
	 * @description Tests that partial caller overrides are merged with existing handler CMDT values,
	 * including backoff, circuit breaker, and failure logging overrides.
	 */
	@IsTest
	private static void shouldMergePartialOverridesWithHandlerCMDT()
	{
		String handlerName = TestDelegationHandlerWithCMDT.class.getName();
		API_MockFactory.enableMocking(handlerName);

		Test.startTest();
		API_Outbound handler = UTIL_HttpClient.useHandler(TestDelegationHandlerWithCMDT.class)
				.withRetry(7, 10)
				.withCircuitBreaker()
				.onFailure(UTIL_HttpClient.FailureAction.LOG_FAILURE)
				.withParameter('input', 'test')
				.invoke();
		Test.stopTest();

		Assert.areEqual('OriginalCredential', handler.namedCredentialOverride, 'Credential should be preserved from handler CMDT');
		Assert.areEqual('/original/path', handler.setting.EndpointPath__c, 'Endpoint path should be preserved from handler CMDT');
		Assert.areEqual(7, handler.setting.MaxRetryCount__c, 'Max retry count should be overridden by caller');
		Assert.areEqual(10, handler.setting.RetryBackoffSeconds__c, 'Backoff seconds should be overridden by caller');
		Assert.isTrue(handler.setting.CircuitBreakerEnabled__c, 'Circuit breaker should be overridden by caller');
		Assert.isTrue(handler.setting.LogIssues__c, 'Log issues should be overridden by caller');
	}

	/**
	 * @description Tests that auto-mocking is not enabled when a credential override is provided.
	 */
	@IsTest
	private static void shouldNotAutoMockWhenCredentialOverrideProvided()
	{
		Test.startTest();
		UTIL_HttpClient.useHandler(TestDelegationHandler.class)
				.credential('NonExistentCredential')
				.withParameter('input', 'test')
				.invoke();
		Test.stopTest();

		String handlerName = TestDelegationHandler.class.getName();
		Assert.isFalse(API_MockFactory.isMockingEnabled(handlerName), 'Auto-mocking should not be enabled when credential override is provided');
	}

	/**
	 * @description Executes the request within a Test.startTest/stopTest boundary and asserts
	 * the handler was not unexpectedly aborted during validation.
	 *
	 * @param builder The configured request builder
	 *
	 * @return The HTTP response from the callout
	 */
	private static HttpResponse assertSend(UTIL_HttpClient.RequestBuilder builder)
	{
		Test.startTest();
		HttpResponse response = builder.send();
		Test.stopTest();
		assertNotAborted(builder);
		return response;
	}

	/**
	 * @description Executes the request, asserts not aborted, and verifies the expected HTTP status code.
	 *
	 * @param builder The configured request builder
	 * @param expectedStatusCode The expected HTTP status code
	 *
	 * @return The HTTP response from the callout
	 */
	private static HttpResponse assertSend(UTIL_HttpClient.RequestBuilder builder, Integer expectedStatusCode)
	{
		HttpResponse response = assertSend(builder);
		Assert.areEqual(expectedStatusCode, response.getStatusCode(), 'Expected HTTP ' + expectedStatusCode);
		return response;
	}

	/**
	 * @description Asserts that the handler was not unexpectedly aborted during validation.
	 * Surfaces the actual abort reason instead of a cryptic NullPointerException on the response.
	 *
	 * @param builder The request builder after send() has been called
	 */
	private static void assertNotAborted(UTIL_HttpClient.RequestBuilder builder)
	{
		Assert.isFalse(builder.handlerInstance.result.isAborted, 'Call was unexpectedly aborted: ' + builder.handlerInstance.result.errors);
	}

	/**
	 * @description Minimal API_Outbound handler with no ApiSetting__mdt record.
	 * Used to test the applySubscriberSettings fallback path in delegation mode.
	 */
	public class TestDelegationHandler extends API_Outbound
	{
		/**
		 * @description Configure handler with mock body and no triggering record requirement.
		 */
		public override void configure()
		{
			super.configure();
			requiresTriggeringRecord = false;
			defaultMockBody = '{"delegation":"auto"}';
		}
	}

	/**
	 * @description Handler that throws during onSuccess() to test delegation error handling.
	 */
	public class TestThrowingHandler extends API_Outbound
	{
		/**
		 * @description Configure handler with mock body and no triggering record requirement.
		 */
		public override void configure()
		{
			super.configure();
			requiresTriggeringRecord = false;
			defaultMockBody = '{"will":"throw"}';
		}

		/**
		 * @description Forces an unexpected exception during processing.
		 */
		public override void onSuccess()
		{
			super.onSuccess();
			throw new UTIL_Exceptions.ConfigurationException('Test forced error');
		}
	}

	/**
	 * @description Handler whose records the platform refuses to save once the external system responded with a success.
	 */
	public class TestCommitRefusedHandler extends API_Outbound
	{
		/**
		 * @description Configure handler with mock body and no triggering record requirement.
		 */
		public override void configure()
		{
			super.configure();
			requiresTriggeringRecord = false;
			defaultMockBody = '{"commit":"refused"}';
		}

		/**
		 * @description Registers a record whose email value the platform refuses, so the handler's commit fails.
		 */
		public override void onSuccess()
		{
			super.onSuccess();
			doInsert(TST_Builder.of(Foobar__c.SObjectType).withoutInsertion().withOverride(Foobar__c.Email__c, INVALID_EMAIL).build());
		}
	}

	/**
	 * @description Handler that fails before it takes the call record in hand.
	 */
	public class TestThrowingBeforeProcessingHandler extends API_Outbound
	{
		/**
		 * @description Configure handler with mock body and no triggering record requirement.
		 */
		public override void configure()
		{
			super.configure();
			requiresTriggeringRecord = false;
			defaultMockBody = '{"will":"throw"}';
		}

		/**
		 * @description Fails before the base processing runs, so the handler never holds the call record.
		 *
		 * @param apiCall The API call being processed.
		 */
		public override void process(ApiCall__c apiCall)
		{
			throw new UTIL_Exceptions.ConfigurationException(MESSAGE_THROWN_BEFORE_PROCESSING);
		}
	}

	/**
	 * @description API_Outbound handler with pre-configured ApiSetting__mdt.
	 * Used to test caller overrides merging with existing handler CMDT values.
	 */
	public class TestDelegationHandlerWithCMDT extends API_Outbound
	{
		/**
		 * @description Configure handler with pre-applied settings simulating real CMDT.
		 */
		public override void configure()
		{
			super.configure();
			requiresTriggeringRecord = false;
			defaultMockBody = '{"delegation":"cmdt"}';

			ApiSetting__mdt preConfiguredSetting = (ApiSetting__mdt)TST_Builder.of(ApiSetting__mdt.SObjectType)
					.withOverride(ApiSetting__mdt.IsActive__c, true)
					.withOverride(ApiSetting__mdt.ClassName__c, TestDelegationHandlerWithCMDT.class.getName())
					.withOverride(ApiSetting__mdt.DeveloperName, TestDelegationHandlerWithCMDT.class.getName())
					.withOverride(ApiSetting__mdt.EndpointPath__c, '/original/path')
					.withOverride(ApiSetting__mdt.MaxRetryCount__c, 2)
					.withoutInsertion()
					.build();
			applySettings(preConfiguredSetting);
			namedCredentialOverride = 'OriginalCredential';
		}
	}
}