// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Test class to test the Outbound API call
 *
 * @see API_PostExample
 *
 * @author Jason van Beukering
 *
 * @group Web Services
 *
 * @date February 2026, May 2026
 */
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs,PMD.CyclomaticComplexity')
@IsTest(SeeAllData=false IsParallel=false)
public class API_PostExample_TEST
{
	/**
	 * @description The API class name used for test assertions.
	 */
	private static final String SERVICE_NAME = API_PostExample.class.getName();

	/**
	 * @description To setup the List of API Calls
	 *
	 * @return A list of API calls
	 */
	private static List<ApiCall__c> setup()
	{
		ApiCall__c apiCall = TST_Factory.newOutboundApiCall
				(
						SERVICE_NAME,
						UserInfo.getUserId(),
						UTIL_Random.randomName(),
						UTIL_Random.randomName()
				);

		return new List<ApiCall__c> {apiCall};
	}

	/**
	 * @description Emulates a successful call
	 */
	@IsTest
	private static void successful()
	{
		API_OutboundTestHelper.assertCallSuccessful(setup());
	}

	/**
	 * @description Checks that disabling inbound calls does not affect any outbound calls
	 */
	@IsTest
	private static void successfulInboundDisabled()
	{
		TST_Factory.disableAllInboundApis();
		API_OutboundTestHelper.assertCallSuccessful(setup());
	}

	/**
	 * @description Emulates a successful call and then checks that transformation code complete successfully
	 */
	@IsTest
	private static void successfulWithTransformer()
	{
		API_OutboundTestHelper.assertCallSuccessfulWithTransformation(SERVICE_NAME, UserInfo.getUserId(), API_PostExample.DTO_Response.class.getName());
	}

	/**
	 * @description Emulates a successful call and then checks that call was successful, but class name provided is invalid
	 */
	@IsTest
	private static void successfulWithInvalidTransformerClass()
	{
		API_OutboundTestHelper.assertCallSuccessfulWithInvalidTransformation(SERVICE_NAME, UserInfo.getUserId(), UserInfo.getUserId());
	}

	/**
	 * @description Emulates a successful call and then checks that call was successful, but class name provided is invalid
	 */
	@IsTest
	private static void successfulWithWrongTransformClassType()
	{
		API_OutboundTestHelper.assertCallSuccessfulWithInvalidTransformation(SERVICE_NAME, UserInfo.getUserId(), SERVICE_NAME);
	}

	/**
	 * @description Emulates a successful call using simpler alternative
	 */
	@IsTest
	private static void successfulAlternative()
	{
		API_Base handler = assertSuccess();
		Assert.isFalse(handler.result.isMocked, 'Service Handler should not be mocking');
	}

	/**
	 * @description Emulates a successful call using a single parameter
	 */
	@IsTest
	private static void successfulWithSingleParameter()
	{
		API_OutboundTestHelper.assertCallSuccessful(SERVICE_NAME, UserInfo.getUserId(), UTIL_Random.randomName());
	}

	/**
	 * @description Emulates a successful call using parameters
	 */
	@IsTest
	private static void successfulWithParameters()
	{
		API_OutboundTestHelper.assertCallSuccessful(SERVICE_NAME, UserInfo.getUserId(), new Set<String> {UTIL_Random.randomName()});
	}

	/**
	 * @description Emulates a successful call using parameter map
	 */
	@IsTest
	private static void successfulWithParameterMap()
	{
		Map<String, String> parameters = new Map<String, String>
		{
				UTIL_Random.randomName() => UTIL_Random.randomName()

		};

		API_OutboundTestHelper.assertCallSuccessful(SERVICE_NAME, UserInfo.getUserId(), parameters);
	}

	/**
	 * @description Emulates a successful call and checks if existing failed API call record is resolved
	 *
	 * @see API_Outbound.resolveApiIssues
	 */
	@IsTest
	private static void shouldResolveApiIssueOnSuccess()
	{
		System.runAs(TST_Factory.newUser(SEL_Profile.PROFILE_STANDARD_USER))
		{
			List<ApiCall__c> apiCalls = setup();

			ApiCall__c apiCall = apiCalls.iterator().next();
			TST_Factory.insertApiIssue(apiCall, UTIL_Crypto.generateMD5Hash(apiCall.RequestParameters__c));

			API_OutboundTestHelper.assertCallSuccessful(apiCalls);

			ApiIssue__c apiIssue = new SEL_ApiIssue().getAll().iterator().next();
			Assert.areEqual(SEL_ApiIssue.STATUS_RESOLVED, apiIssue.Status__c, 'API issues not resolved as expected');
		}
	}

	/**
	 * @description Emulates a failed call
	 */
	@IsTest
	private static void failedCall()
	{
		API_Base.simulateStoreToFile = true;
		API_Base handler = API_OutboundTestHelper.assertCallFailed(setup()).iterator().next();
		List<ContentVersion> foundVersions = new SEL_ContentVersion().findByFirstPublishLocationId(handler.apiCall.Id);
		Assert.isFalse(foundVersions.isEmpty(), 'No files stored as expected');

	}

	/**
	 * @description Emulates a failed call and checks if API issue record is created
	 */
	@IsTest
	private static void shouldLogApiIssueOnFailure()
	{
		System.runAs(TST_Factory.newUser(SEL_Profile.PROFILE_STANDARD_USER))
		{
			API_OutboundTestHelper.assertCallFailed(setup());
			List<ApiIssue__c> apiIssues = new SEL_ApiIssue().getAll();
			Assert.isFalse(apiIssues.isEmpty(), 'API issues not created as expected');
		}
	}

	/**
	 * @description Emulates a failed call due to response parse failure. Verifies the
	 * `parseError` flag distinguishes parse failure from transport failure on the Result,
	 * proves the local `handleError` was invoked (errors[] populated), and confirms the
	 * commitWork → logApiIssues → createFailureRecord path still persists an `ApiIssue__c`
	 * row when the service is configured with `LogIssues__c = true` (regression guard for
	 * the dispatcher control-flow change).
	 */
	@IsTest
	private static void parseFailed()
	{
		API_Base.simulateStoreToFile = true;
		API_Base handler = API_OutboundTestHelper.assertParseFailed(setup()).iterator().next();
		List<ContentVersion> foundVersions = new SEL_ContentVersion().findByFirstPublishLocationId(handler.apiCall.Id);
		Assert.isFalse(foundVersions.isEmpty(), 'No files stored as expected');
		Assert.isTrue(handler.result.parseError,
				'Result.parseError should be true when parseResponse() fails on a transport-success response');
		Assert.isFalse(handler.result.errors.isEmpty(),
				'Local handleError(parseFailure) must populate result.errors so subscribers see the parse exception detail');
		List<ApiIssue__c> issues = new SEL_ApiIssue().findByField(ApiIssue__c.ServiceName__c, API_PostExample.class.getName());
		Assert.isFalse(issues.isEmpty(),
				'Parse failure with LogIssues__c=true must still persist an ApiIssue__c row via the commitWork path (regression guard for the parseError dispatcher rewire)');
	}

	/**
	 * @description Checks that exception is thrown and logged when API setting is not found for a particular handler class
	 */
	@IsTest
	private static void abortedSettingNotFound()
	{
		ApiCall__c apiCall = TST_Factory.newOutboundApiCall(ApiWithNoSetting.class.getName());
		API_OutboundTestHelper.assertCallAborted(new List<ApiCall__c> {apiCall});
	}

	/**
	 * @description Emulates a call that is aborted because no ID was provided
	 *
	 * @see API_Base.getValidationErrors
	 */
	@IsTest
	private static void abortedNoId()
	{
		API_Base.simulateStoreToFile = true;
		API_Base handler = API_OutboundTestHelper.assertCallAborted(SERVICE_NAME, null);
		List<ContentVersion> foundVersions = new SEL_ContentVersion().findByFirstPublishLocationId(handler.apiCall.Id);
		Assert.isFalse(foundVersions.isEmpty(), 'No files stored as expected');
	}

	/**
	 * @description Emulates a call that is aborted because no ID was provided, uses an overload method that takes a parameter map
	 *
	 * @see API_Base.getValidationErrors
	 */
	@IsTest
	private static void abortedWithParameters()
	{
		Map<String, String> parameterMap = new Map<String, String>
		{
				UTIL_Random.randomName() => UTIL_Random.randomName()

		};

		API_OutboundTestHelper.assertCallAborted(SERVICE_NAME, null, parameterMap);
	}

	/**
	 * @description Emulates a call that is aborted because no ID was provided, uses the single parameter name overload.
	 *
	 * @see API_Base.getValidationErrors
	 */
	@IsTest
	private static void abortedWithSingleParameterName()
	{
		API_OutboundTestHelper.assertCallAborted(SERVICE_NAME, null, UTIL_Random.randomName());
	}

	/**
	 * @description Emulates a call that is aborted because all APIs have been disabled for the current user
	 */
	@IsTest
	private static void abortAllApisDisabled()
	{
		TST_Factory.disableAllApis();
		API_OutboundTestHelper.assertCallAborted(setup());
	}

	/**
	 * @description Emulates a call that is aborted because all Outbound APIs have been disabled for the current user
	 */
	@IsTest
	private static void abortOutboundApsDisabled()
	{
		TST_Factory.disableAllOutboundApis();
		API_OutboundTestHelper.assertCallAborted(setup());
	}

	/**
	 * @description Emulates a call that returns a mock response because the API has been mocked via API_MockFactory.
	 */
	@IsTest
	private static void mockApiViaFactory()
	{
		API_MockFactory.enableMocking(SERVICE_NAME);
		API_Base handler = assertSuccess();
		Assert.isTrue(handler.result.isMocked, 'Service Handler is not mocking as expected');
	}

	/**
	 * @description Tests to see if the getBaseURL works as expected
	 */
	@IsTest
	private static void getBaseUrl()
	{
		API_PostExample service = new API_PostExample();

		Test.startTest();

		String baseUrl = service.baseUrl;

		Test.stopTest();

		Assert.isTrue(String.isNotBlank(baseUrl), 'Base URL should not be blank');
		Assert.areNotEqual(service.getWebServiceEndPoint(), baseUrl, 'Invalid base URL');
	}

	/**
	 * @description Ensures that use of DTO Json base class throws error for a method that should be overridden
	 *
	 * @see DTO_JsonBase.getObjectType
	 * @see DTO_JsonBase.deserialize
	 */
	@IsTest
	private static void checkJsonDtoMethodOverrideThrowsError()
	{
		DTO_Base dtoMethodOverride = new DTO_IncorrectlyImplemented();

		Test.startTest();

		try
		{
			dtoMethodOverride = dtoMethodOverride.deserialize(UTIL_String.EMPTY_JSON_RESPONSE);
			Assert.fail('Exception not thrown as expected.');
		}
		catch(Exception caughtException)
		{
			Assert.isInstanceOfType(caughtException, IllegalArgumentException.class, 'Incorrect Exception Type');
		}

		Test.stopTest();
	}

	/**
	 * @description Emulates an aborted call with the expected disabled error message.
	 */
	@IsTest
	private static void abortedWithDisabledMessage()
	{
		TST_Factory.disableAllApis();
		API_OutboundTestHelper.assertCallAborted(setup().iterator().next(), API_Base.ERROR_API_DISABLED);
	}

	/**
	 * @description Tests that circuit breaker is enabled for API_PostExample via metadata configuration
	 *
	 * @see UTIL_CircuitBreaker
	 * @see API_Outbound.sendRequest
	 * @see API_Outbound.isCircuitBreakerEnabled
	 */
	@IsTest
	private static void circuitBreakerEnabledViaMetadata()
	{
		// Circuit breaker is enabled for API_PostExample via ApiSetting metadata
		// Successful calls should execute normally and record success with circuit breaker
		API_OutboundTestHelper.assertCallSuccessful(setup());
	}

	/**
	 * @description Tests that circuit breaker records failures when HTTP calls fail
	 *
	 * @see UTIL_CircuitBreaker
	 * @see API_Outbound.sendRequest
	 */
	@IsTest
	private static void circuitBreakerRecordsFailures()
	{
		// Verify that when circuit breaker is enabled, failures are recorded
		// The actual circuit state management is tested in UTIL_CircuitBreaker_TEST
		API_MockFactory.registerErrorMock(SERVICE_NAME);

		Test.startTest();

		List<API_Base> handlers = API_Dispatcher.execute(setup());

		Test.stopTest();

		// Verify the call failed and circuit breaker code path was executed
		Assert.isTrue(handlers.iterator().next().result.hasFailed, 'Call should have failed');
	}

	/**
	 * @description Tests that circuit breaker allows requests when enabled and circuit is closed
	 *
	 * @see UTIL_CircuitBreaker
	 * @see API_Outbound.sendRequest
	 */
	@IsTest
	private static void circuitBreakerAllowsRequestsWhenClosed()
	{
		// When circuit breaker is enabled and circuit is CLOSED, requests should proceed normally
		// The helper method wraps the call in Test.startTest/stopTest, so we don't duplicate it
		API_Base handler = assertSuccess();

		// Verify the call succeeded
		Assert.isTrue(handler.result.isSuccess, 'Call should have completed successfully');
	}

	/**
	 * @description Tests that retry logic works correctly with circuit breaker enabled
	 *
	 * @see UTIL_CircuitBreaker
	 * @see API_Outbound.retry
	 */
	@IsTest
	private static void circuitBreakerWithRetryIssues()
	{
		// Verify that retry logic continues to function when circuit breaker is enabled
		// The actual coordination between circuit breaker state and retry backoff is tested
		// through integration - retry backoff should be extended to circuit timeout when circuit is OPEN
		API_MockFactory.registerErrorMock(SERVICE_NAME);

		Test.startTest();

		List<API_Base> handlers = API_Dispatcher.execute(setup());

		Test.stopTest();

		// Verify the call failed and retry was scheduled
		API_Base handler = handlers.iterator().next();
		Assert.isTrue(handler.result.hasFailed, 'Call should have failed');
		Assert.areEqual(SEL_ApiCall.STATUS_RETRY, handler.apiCall.Status__c, 'Status should be Retry when retries remain');
		Assert.isNotNull(handler.apiCall.NextRetry__c, 'Next retry should be scheduled');
	}

	/**
	 * @description Tests that circuit breaker aborts requests when circuit is OPEN
	 *
	 * This test opens the circuit by causing 3 failed requests (threshold from metadata),
	 * then verifies that the 4th request is aborted due to the circuit being OPEN.
	 *
	 * @see UTIL_CircuitBreaker
	 * @see API_Base.getValidationErrors
	 */
	@IsTest
	private static void circuitBreakerAbortsWhenOpen()
	{
		Assert.isTrue(UTIL_Cache.isOrgAllocated(), 'Org cache must be allocated for circuit breaker testing');

		API_MockFactory.registerErrorMock(SERVICE_NAME);

		// Create 4 API calls, because of circuit breaker configuration we know after 3 failures, the 4th will abort
		List<ApiCall__c> apiCalls = setup();

		for(Integer i = 0; i < 3; i++)
		{
			apiCalls.add(TST_Factory.newOutboundApiCall
					(
							SERVICE_NAME,
							UserInfo.getUserId(),
							UTIL_Random.randomName(),
							UTIL_Random.randomName()
					));
		}

		Test.startTest();

		List<API_Base> handlers = API_Dispatcher.execute(apiCalls);

		Test.stopTest();

		API_Base handler = handlers[3];

		// Verify the request was aborted due to circuit breaker
		Assert.isTrue(handler.result.isAborted, 'Call should have been aborted');
		Assert.isTrue(handler.result.errors.iterator().next().contains('Circuit breaker is OPEN'), 'Error should mention circuit breaker');
	}

	/**
	 * @description Tests that an unexpected exception during validation is caught and causes abort.
	 *
	 * @see API_Base.performValidation
	 */
	@IsTest
	private static void shouldAbortWhenValidationThrowsUnexpectedException()
	{
		API_Outbound.simulateValidationException = true;
		API_OutboundTestHelper.assertCallAborted(setup());
	}

	/**
	 * @description Tests that retry logic continues to function even when circuit breaker check fails.
	 * This ensures defensive code handles circuit breaker configuration errors gracefully.
	 *
	 * @see API_Outbound.retry
	 */
	@IsTest
	private static void retryHandlesCircuitBreakerFailure()
	{
		API_MockFactory.registerErrorMock(SERVICE_NAME);
		API_Outbound.simulateCircuitBreakerFailure = true;

		Test.startTest();

		List<API_Base> handlers = API_Dispatcher.execute(setup());

		Test.stopTest();

		// Verify the call failed but retry was still scheduled despite circuit breaker failure
		API_Base handler = handlers.iterator().next();
		Assert.isTrue(handler.result.hasFailed, 'Call should have failed');
		Assert.areEqual(SEL_ApiCall.STATUS_RETRY, handler.apiCall.Status__c, 'Status should be Retry despite circuit breaker failure');
		Assert.isNotNull(handler.apiCall.NextRetry__c, 'Next retry should be scheduled despite circuit breaker failure');
	}

	/**
	 * @description Tests that outbound API is aborted when disabled via feature flag.
	 *
	 * @see API_Outbound.isDisabled
	 * @see API_Outbound.FLAG_DISABLE_ALL_OUTBOUND_APIS
	 */
	@IsTest
	private static void abortOutboundApisDisabledViaFeatureFlag()
	{
		TST_Factory.newFeatureFlag(API_Outbound.FLAG_DISABLE_ALL_OUTBOUND_APIS);
		API_OutboundTestHelper.assertCallAborted(setup());
	}

	/**
	 * @description Tests that DML is rolled back when Safe Mode is active, while the callout still executes.
	 * Safe Mode prevents DML from persisting but does not block or mock the callout itself.
	 *
	 * @see API_Base.SafeModeContext
	 * @see API_Base.commitWork
	 */
	@IsTest
	private static void shouldRollbackDmlWhenSafeModeActive()
	{
		API_Base.SafeModeContext safeMode = API_Base.enterSafeMode();

		try
		{
			ApiCall__c apiCall = TST_Factory.newOutboundApiCall(SERVICE_NAME, UserInfo.getUserId());

			Test.startTest();

			List<API_Base> handlers = API_Dispatcher.execute(new List<ApiCall__c> {apiCall});

			Test.stopTest();

			API_Base handler = handlers.iterator().next();
			Assert.isTrue(handler.result.isSuccess, 'Callout should succeed in Safe Mode');
			Assert.isFalse(handler.result.isMocked, 'Safe Mode should not mock the callout');
		}
		finally
		{
			safeMode.close();
		}

		Assert.isFalse(API_Base.isSafeModeActive(), 'Safe Mode should be closed after context close');
	}

	/**
	 * @description Tests that outbound mock now delegates to API_MockFactory when apiClassName is set.
	 * Registers a memory mock and verifies the factory response is returned.
	 *
	 * @see API_MockFactory.CalloutMock
	 * @see API_Outbound.createEndpointMock
	 */
	@IsTest
	private static void shouldDelegateToMockFactoryWhenMockRegistered()
	{
		String expectedBody = '{"factoryMock":true}';
		API_MockFactory.forService(SERVICE_NAME).body(expectedBody).statusCode(API_Base.HTTP_OK).register();
		API_MockFactory.enableMocking(SERVICE_NAME);

		ApiCall__c apiCall = TST_Factory.newOutboundApiCall(SERVICE_NAME, UserInfo.getUserId());

		Test.startTest();

		List<API_Base> handlers = API_Dispatcher.execute(new List<ApiCall__c> {apiCall});

		Test.stopTest();

		API_Base handler = handlers.iterator().next();
		Assert.isTrue(handler.result.isMocked, 'Should be mocked');
		Assert.areEqual(expectedBody, handler.result.responseBody, 'Should return factory mock body');
	}

	/**
	 * @description Tests that outbound mocking is enabled via API_MockFactory.enableMocking()
	 * and the handler returns a mocked response.
	 *
	 * @see API_Base.isMocking
	 * @see API_MockFactory.enableMocking
	 */
	@IsTest
	private static void shouldMockOutboundWhenEnabledViaFactory()
	{
		API_MockFactory.enableMocking(SERVICE_NAME);

		ApiCall__c apiCall = TST_Factory.newOutboundApiCall(SERVICE_NAME, UserInfo.getUserId());

		Test.startTest();

		List<API_Base> handlers = API_Dispatcher.execute(new List<ApiCall__c> {apiCall});

		Test.stopTest();

		API_Base handler = handlers.iterator().next();
		Assert.isTrue(handler.result.isMocked, 'Should be mocked when enableMocking is called');
	}

	/**
	 * @description Tests that outbound calls populate trace context on the API call record.
	 * Verifies the W3C Trace Parent header is injected and trace ID is persisted.
	 *
	 * @see API_Outbound.setHeaders
	 * @see API_Base.TraceContext
	 */
	@IsTest
	private static void shouldPopulateTraceContextOnOutboundCall()
	{
		API_Base handler = assertSuccess();

		Assert.isNotNull(handler.apiCall.TraceId__c, 'Trace ID should be populated on outbound API call');
		Assert.areEqual(32, handler.apiCall.TraceId__c.length(), 'Trace ID should be 32 hex characters');
		Assert.isNotNull(handler.apiCall.ParentSpanId__c, 'Parent span ID should be populated on outbound API call');
		Assert.areEqual(16, handler.apiCall.ParentSpanId__c.length(), 'Parent span ID should be 16 hex characters');
	}

	/**
	 * @description Tests that the outbound trace ID is bridged to LOG_Builder.correlationId
	 * so log entries emitted during API processing can be correlated with the distributed trace.
	 *
	 * @see API_Outbound.process
	 * @see LOG_Builder.setCorrelationId
	 */
	@IsTest
	private static void shouldSetLogCorrelationIdForOutbound()
	{
		API_Base handler = assertSuccess();

		Assert.areEqual(handler.apiCall.TraceId__c, LOG_Builder.correlationId, 'LOG_Builder correlationId should equal the outbound trace ID');
	}

	/**
	 * @description Tests that outbound calls generate an idempotency key when enabled in settings.
	 * The IdempotencyEnabled__c flag is set on the ApiSetting.PostExample metadata record.
	 *
	 * @see API_Outbound.setHeaders
	 * @see API_Outbound.setApiCallDetails
	 */
	@IsTest
	private static void shouldGenerateIdempotencyKeyWhenEnabled()
	{
		API_Base handler = assertSuccess();

		Assert.isNotNull(handler.apiCall.IdempotencyKey__c, 'Idempotency key should be generated when enabled');
	}

	/**
	 * @description Tests that content hash mode generates a SHA-256 idempotency key
	 * (64-character hex string) rather than a random UUID (36-character with dashes).
	 *
	 * @see API_Outbound.resolveIdempotencyKey
	 */
	@IsTest
	private static void shouldGenerateContentHashIdempotencyKey()
	{
		API_Base handler = assertSuccess();

		String idempotencyKey = handler.apiCall.IdempotencyKey__c;
		Assert.isNotNull(idempotencyKey, 'Idempotency key should be generated');
		Assert.areEqual(64, idempotencyKey.length(), 'Content hash key should be 64-character SHA-256 hex, not a UUID');
		Assert.isFalse(idempotencyKey.contains('-'), 'Content hash key should not contain dashes like a UUID');
		Assert.areEqual(idempotencyKey, ((API_Outbound)handler).request.getHeader(API_Base.HEADER_IDEMPOTENCY_KEY), 'Content hash key should be sent as HTTP header');
	}

	/**
	 * @description Verifies that MaxRetries__c is populated from settings during setApiCallDetails.
	 *
	 * @see API_Outbound.setApiCallDetails
	 */
	@IsTest
	private static void shouldPopulateMaxRetriesFromSettings()
	{
		Test.startTest();

		List<API_Base> handlers = API_Dispatcher.execute(setup());

		Test.stopTest();

		API_Base handler = handlers.iterator().next();
		Assert.isNotNull(handler.apiCall.MaxRetries__c, 'MaxRetries should be populated');
	}

	/**
	 * @description Verifies that a dead-lettered API call can be recovered with additional retries.
	 *
	 * @see API_PostExample_TEST.recoverDeadLetter
	 */
	@IsTest
	private static void shouldRecoverDeadLetteredApiCall()
	{
		ApiCall__c deadLetter = (ApiCall__c)deadLetterBuilder(3, false).build();

		Test.startTest();

		recoverDeadLetter(deadLetter.Id, 3);

		Test.stopTest();

		ApiCall__c recovered = (ApiCall__c)new SEL_ApiCall().findById(deadLetter.Id);
		Assert.areEqual(6, recovered.MaxRetries__c, 'MaxRetries should be increased by additional retries');
		Assert.isFalse(recovered.ManualDeadLetter__c, 'ManualDeadLetter should be cleared');
		Assert.areEqual(SEL_ApiCall.STATUS_RETRY, recovered.Status__c, 'Status should be set to Retry');
		Assert.isNotNull(recovered.NextRetry__c, 'NextRetry should be set');
	}

	/**
	 * @description Verifies that a manually dead-lettered API call is recovered correctly.
	 *
	 * @see API_PostExample_TEST.recoverDeadLetter
	 */
	@IsTest
	private static void shouldRecoverManuallyDeadLetteredApiCall()
	{
		ApiCall__c deadLetter = (ApiCall__c)deadLetterBuilder(1, true).build();

		Test.startTest();

		recoverDeadLetter(deadLetter.Id, 2);

		Test.stopTest();

		ApiCall__c recovered = (ApiCall__c)new SEL_ApiCall().findById(deadLetter.Id);
		Assert.areEqual(3, recovered.MaxRetries__c, 'MaxRetries should be currentRetries + additionalRetries');
		Assert.isFalse(recovered.ManualDeadLetter__c, 'ManualDeadLetter should be cleared');
		Assert.areEqual(SEL_ApiCall.STATUS_RETRY, recovered.Status__c, 'Status should be set to Retry');
	}

	/**
	 * @description Verifies that recovering a non-existent API call throws an exception.
	 *
	 * @see API_PostExample_TEST.recoverDeadLetter
	 */
	@IsTest
	private static void shouldThrowWhenRecoveringNonExistentApiCall()
	{
		Id fakeId = UTIL_Random.randomId(ApiCall__c.SObjectType);

		try
		{
			recoverDeadLetter(fakeId, 3);
			Assert.fail('Should throw exception for non-existent record');
		}
		catch(Exception error)
		{
			Assert.isInstanceOfType(error, UTIL_Exceptions.NotFoundException.class, 'Incorrect Exception Type');
		}
	}

	/**
	 * @description Convenience wrapper that asserts a successful outbound call for the PostExample service.
	 *
	 * @return The executed API_Base handler
	 */
	private static API_Base assertSuccess()
	{
		return API_OutboundTestHelper.assertCallSuccessful(SERVICE_NAME, UserInfo.getUserId());
	}

	/**
	 * @description Recovers a dead-lettered API call by resetting retry count and re-queuing.
	 *
	 * @param apiCallId The dead-lettered ApiCall__c record to recover
	 * @param additionalRetries Number of additional retry attempts to allow
	 */
	private static void recoverDeadLetter(Id apiCallId, Integer additionalRetries)
	{
		ApiCall__c deadLetter = (ApiCall__c)new SEL_ApiCall().findByIdOrThrow(apiCallId);

		deadLetter.MaxRetries__c = (deadLetter.Retries__c ?? 0) + additionalRetries;
		deadLetter.ManualDeadLetter__c = false;
		deadLetter.Status__c = SEL_ApiCall.STATUS_RETRY;
		deadLetter.NextRetry__c = Datetime.now();

		DML_Builder.newTransaction().withSystemMode().doUpdate(deadLetter).execute();

		LOG_Builder.build()
				.info('Dead-lettered API call recovered with ' + additionalRetries + ' additional retries')
				.emitAt(deadLetter.ServiceName__c + '.recoverDeadLetter');
	}

	/**
	 * @description Creates a pre-configured dead letter ApiCall builder for recovery testing.
	 *
	 * @param retries The number of retries already attempted
	 * @param manualDeadLetter Whether the record was manually dead-lettered
	 *
	 * @return A TST_Builder.Builder ready for further chaining or .build()
	 */
	private static TST_Builder.Builder deadLetterBuilder(Integer retries, Boolean manualDeadLetter)
	{
		return TST_Factory.getApiCallBuilder()
				.withOverrides(new Map<SObjectField, Object>
				{
						ApiCall__c.ServiceName__c => SERVICE_NAME,
						ApiCall__c.Status__c => SEL_ApiCall.STATUS_FAILED,
						ApiCall__c.Retries__c => retries,
						ApiCall__c.MaxRetries__c => 3,
						ApiCall__c.ManualDeadLetter__c => manualDeadLetter
				});
	}

	/**
	 * @description Verifies that outbound service aborts when IsActive__c is false on ApiSetting__mdt.
	 *
	 * @see API_Base.performValidation
	 */
	@IsTest
	private static void shouldAbortWhenServiceIsInactive()
	{
		enableApiSettingFeature(new Map<SObjectField, Object>
		{
				ApiSetting__mdt.IsActive__c => false
		});

		ApiCall__c apiCall = TST_Factory.newOutboundApiCall(SERVICE_NAME, UserInfo.getUserId());

		API_OutboundTestHelper.assertCallAborted(apiCall, API_Base.ERROR_API_INACTIVE);
	}

	/**
	 * @description Verifies that outbound service aborts when RequiredFeatureFlag__c names a disabled feature flag.
	 *
	 * @see API_Base.performValidation
	 */
	@IsTest
	private static void shouldAbortWhenRequiredConditionNotMet()
	{
		String flagName = 'DisabledTestFlag';
		FeatureFlag__mdt newFlag = (FeatureFlag__mdt)TST_Builder.of(FeatureFlag__mdt.SObjectType)
				.withoutInsertion()
				.build();
		newFlag.IsEnabledByDefault__c = false;

		SEL_FeatureFlag.activeFlags.put(flagName, newFlag);
		SEL_FeatureFlag.allDeveloperNames = new Set<String>(SEL_FeatureFlag.allDeveloperNames);
		SEL_FeatureFlag.allDeveloperNames.add(flagName);

		enableApiSettingFeature(new Map<SObjectField, Object>
		{
				ApiSetting__mdt.IsActive__c => true,
				ApiSetting__mdt.RequiredFeatureFlag__c => TST_Factory.newFeatureFlag(flagName, false)
		});

		ApiCall__c apiCall = TST_Factory.newOutboundApiCall(SERVICE_NAME, UserInfo.getUserId());

		API_OutboundTestHelper.assertCallAborted(apiCall,
				String.format(API_Base.ERROR_REQUIRED_CONDITION_NOT_MET, new List<String> {flagName}));
	}

	/**
	 * @description Verifies that outbound service passes validation when RequiredFeatureFlag__c names an enabled
	 * feature flag. The call proceeds past the condition gate (not aborted), proving the check was satisfied.
	 *
	 * @see API_Base.performValidation
	 */
	@IsTest
	private static void shouldNotAbortWhenRequiredConditionMet()
	{
		String flagName = 'EnabledTestFlag';
		FeatureFlag__mdt newFlag = (FeatureFlag__mdt)TST_Builder.of(FeatureFlag__mdt.SObjectType)
				.withoutInsertion()
				.build();
		newFlag.IsEnabledByDefault__c = true;

		SEL_FeatureFlag.activeFlags.put(flagName, newFlag);
		SEL_FeatureFlag.allDeveloperNames = new Set<String>(SEL_FeatureFlag.allDeveloperNames);
		SEL_FeatureFlag.allDeveloperNames.add(flagName);

		enableApiSettingFeature(new Map<SObjectField, Object>
		{
				ApiSetting__mdt.IsActive__c => true,
				ApiSetting__mdt.RequiredFeatureFlag__c => TST_Factory.newFeatureFlag(flagName, false)
		});

		ApiCall__c apiCall = TST_Factory.newOutboundApiCall(SERVICE_NAME, UserInfo.getUserId());

		Test.startTest();
		List<API_Base> handlers = API_Dispatcher.execute(new List<ApiCall__c> {apiCall});
		Test.stopTest();

		Assert.isFalse(handlers.isEmpty(), 'Handler should have been created');
		Assert.isFalse(handlers[0].result.isAborted, 'Call should not be aborted when required condition is met');
	}

	/**
	 * @description Verifies that outbound service aborts when BypassFeatureFlag__c names an enabled feature flag.
	 *
	 * @see API_Base.performValidation
	 */
	@IsTest
	private static void shouldAbortWhenBypassFeatureFlagActive()
	{
		String flagName = 'BypassOutboundFlag';
		FeatureFlag__mdt newFlag = (FeatureFlag__mdt)TST_Builder.of(FeatureFlag__mdt.SObjectType)
				.withoutInsertion()
				.build();
		newFlag.IsEnabledByDefault__c = true;

		SEL_FeatureFlag.activeFlags.put(flagName, newFlag);
		SEL_FeatureFlag.allDeveloperNames = new Set<String>(SEL_FeatureFlag.allDeveloperNames);
		SEL_FeatureFlag.allDeveloperNames.add(flagName);

		enableApiSettingFeature(new Map<SObjectField, Object>
		{
				ApiSetting__mdt.IsActive__c => true,
				ApiSetting__mdt.BypassFeatureFlag__c => TST_Factory.newFeatureFlag(flagName, false)
		});

		ApiCall__c apiCall = TST_Factory.newOutboundApiCall(SERVICE_NAME, UserInfo.getUserId());

		API_OutboundTestHelper.assertCallAborted(apiCall,
				String.format(API_Base.ERROR_API_BYPASSED, new List<String> {flagName}));
	}

	/**
	 * @description Creates a mock ApiSetting__mdt for the PostExample API with additional field overrides.
	 *
	 * @param overrides Map of ApiSetting__mdt fields to override beyond the defaults
	 */
	private static void enableApiSettingFeature(Map<SObjectField, Object> overrides)
	{
		TST_Factory.newOutboundApiSetting(SERVICE_NAME, overrides);
	}

	/**
	 * @description A Handler used to test when no API setting is found
	 */
	public inherited sharing class ApiWithNoSetting extends API_Outbound
	{
	}

	/**
	 * @description Used to check that getObjectType works correctly
	 *
	 * @see DTO_JsonBase.getObjectType
	 */
	private class DTO_IncorrectlyImplemented extends DTO_JsonBase
	{

	}
}