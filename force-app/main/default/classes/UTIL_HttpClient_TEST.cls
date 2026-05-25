// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Unit tests for UTIL_HttpClient fluent HTTP client facade routed through API_Dispatcher.
 *
 * @see UTIL_HttpClient
 *
 * @author Jason van Beukering
 *
 * @group Web Services
 *
 * @date February 2026, May 2026
 */
@IsTest(SeeAllData=false IsParallel=false)
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs,PMD.ApexUnitTestClassShouldHaveAsserts,PMD.CyclomaticComplexity')
private class UTIL_HttpClient_TEST
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
	 * @description Error JSON response body for failure mocks.
	 */
	private static final String ERROR_BODY = '{"error":"Internal Server Error"}';

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
	 * @description Registers a server error mock for the DefaultOutboundHandler.
	 */
	private static void registerServerErrorMock()
	{
		registerMock(ERROR_BODY, API_Base.HTTP_INTERNAL_SERVER_ERROR, 'Internal Server Error');
	}

	/**
	 * @description Registers a bad request mock for the DefaultOutboundHandler.
	 */
	private static void registerBadRequestMock()
	{
		registerMock(ERROR_BODY, API_Base.HTTP_BAD_REQUEST, 'Bad Request');
	}

	/**
	 * @description Registers a too many requests mock for the DefaultOutboundHandler.
	 */
	private static void registerTooManyRequestsMock()
	{
		registerMock(ERROR_BODY, API_Base.HTTP_TOO_MANY_REQUESTS, 'Too Many Requests');
	}

	/**
	 * @description Tests that a GET request executes successfully.
	 */
	@IsTest
	private static void shouldExecuteGetRequest()
	{
		registerSuccessMock();

		HttpResponse response = assertSend(UTIL_HttpClient.get(TEST_CREDENTIAL, TEST_PATH), API_Base.HTTP_OK);

		Assert.areEqual(RESPONSE_BODY, response.getBody(), 'Body should match');
	}

	/**
	 * @description Tests that a POST request serializes an Object body as JSON.
	 */
	@IsTest
	private static void shouldExecutePostWithObjectBody()
	{
		registerSuccessMock();

		Map<String, Object> payload = new Map<String, Object> {'name' => 'Acme'};
		UTIL_HttpClient.RequestBuilder builder = UTIL_HttpClient.post(TEST_CREDENTIAL, TEST_PATH).body(payload);
		assertSend(builder, API_Base.HTTP_OK);
		Assert.isNotNull(builder.handlerInstance.result.requestBody, 'Request body should be captured');
		Assert.isTrue(builder.handlerInstance.result.requestBody.contains('Acme'), 'Request body should contain serialized payload');
	}

	/**
	 * @description Tests that a POST request sends a raw string body.
	 */
	@IsTest
	private static void shouldExecutePostWithStringBody()
	{
		registerSuccessMock();
		assertSend(UTIL_HttpClient.post(TEST_CREDENTIAL, TEST_PATH).body('{"raw":"data"}'), API_Base.HTTP_OK);
	}

	/**
	 * @description Tests that a PUT request executes successfully.
	 */
	@IsTest
	private static void shouldExecutePutRequest()
	{
		registerSuccessMock();
		assertSend(UTIL_HttpClient.put(TEST_CREDENTIAL, TEST_PATH).body('{"update":"data"}'), API_Base.HTTP_OK);
	}

	/**
	 * @description Tests that a DELETE request executes successfully.
	 */
	@IsTest
	private static void shouldExecuteDeleteRequest()
	{
		registerSuccessMock();
		assertSend(UTIL_HttpClient.del(TEST_CREDENTIAL, TEST_PATH), API_Base.HTTP_OK);
	}

	/**
	 * @description Tests that a PATCH request executes successfully.
	 */
	@IsTest
	private static void shouldExecutePatchRequest()
	{
		registerSuccessMock();
		assertSend(UTIL_HttpClient.patch(TEST_CREDENTIAL, TEST_PATH).body('{"patch":"data"}'), API_Base.HTTP_OK);
	}

	/**
	 * @description Tests that a custom header is applied to the request.
	 */
	@IsTest
	private static void shouldApplyCustomHeader()
	{
		registerSuccessMock();
		assertSend(UTIL_HttpClient.get(TEST_CREDENTIAL, TEST_PATH).header('X-Custom-Header', 'custom-value'), API_Base.HTTP_OK);
	}

	/**
	 * @description Tests that multiple headers are applied to the request.
	 */
	@IsTest
	private static void shouldApplyMultipleHeaders()
	{
		registerSuccessMock();

		Map<String, String> customHeaders = new Map<String, String>
		{
				'X-Header-One' => 'value1',
				'X-Header-Two' => 'value2'
		};

		assertSend(UTIL_HttpClient.get(TEST_CREDENTIAL, TEST_PATH).headers(customHeaders), API_Base.HTTP_OK);
	}

	/**
	 * @description Tests that query parameters are appended to the URL.
	 */
	@IsTest
	private static void shouldAppendQueryParameters()
	{
		registerSuccessMock();
		assertSend(UTIL_HttpClient.get(TEST_CREDENTIAL, TEST_PATH).queryParam('q', 'search term').queryParam('limit', '10'), API_Base.HTTP_OK);
	}

	/**
	 * @description Tests that path parameters substitute placeholders in the URL.
	 */
	@IsTest
	private static void shouldSubstitutePathParameters()
	{
		registerSuccessMock();
		assertSend(UTIL_HttpClient.get(TEST_CREDENTIAL, '/accounts/{accountId}').pathParam('accountId', 'ABC123'), API_Base.HTTP_OK);
	}

	/**
	 * @description Tests that the request timeout is applied.
	 */
	@IsTest
	private static void shouldApplyTimeout()
	{
		registerSuccessMock();
		assertSend(UTIL_HttpClient.get(TEST_CREDENTIAL, TEST_PATH).timeout(60000), API_Base.HTTP_OK);
	}

	/**
	 * @description Tests the asString() terminal method.
	 */
	@IsTest
	private static void shouldReturnBodyAsString()
	{
		registerSuccessMock();

		UTIL_HttpClient.RequestBuilder builder = UTIL_HttpClient.get(TEST_CREDENTIAL, TEST_PATH);

		Test.startTest();
		String responseBody = builder.asString();
		Test.stopTest();

		assertNotAborted(builder);
		Assert.areEqual(RESPONSE_BODY, responseBody, 'Body string should match response');
	}

	/**
	 * @description Tests the asMap() terminal method.
	 */
	@IsTest
	private static void shouldDeserializeAsMap()
	{
		registerSuccessMock();

		UTIL_HttpClient.RequestBuilder builder = UTIL_HttpClient.get(TEST_CREDENTIAL, TEST_PATH);

		Test.startTest();
		Map<String, Object> result = builder.asMap();
		Test.stopTest();

		assertNotAborted(builder);
		Assert.areEqual('ok', result.get('status'), 'Status field should be ok');
		Assert.areEqual('12345', result.get('id'), 'Id field should match');
	}

	/**
	 * @description Tests the deserialize(Type) terminal method.
	 */
	@IsTest
	private static void shouldDeserializeAsType()
	{
		registerSuccessMock();

		UTIL_HttpClient.RequestBuilder builder = UTIL_HttpClient.get(TEST_CREDENTIAL, TEST_PATH);

		Test.startTest();
		ResponseDTO result = (ResponseDTO)builder.deserialize(ResponseDTO.class);
		Test.stopTest();

		assertNotAborted(builder);
		Assert.areEqual('ok', result.status, 'Status field should be ok');
		Assert.areEqual('12345', result.id, 'Id field should match');
	}

	/**
	 * @description Tests that a ApiCall__c record is created after execution.
	 */
	@IsTest
	private static void shouldLogToApiCall()
	{
		registerSuccessMock();

		UTIL_HttpClient.RequestBuilder builder = UTIL_HttpClient.get(TEST_CREDENTIAL, TEST_PATH);
		assertSend(builder);

		ApiCall__c apiCall = builder.handlerInstance.apiCall;
		Assert.isNotNull(apiCall.Id, 'API call record should be inserted');
		Assert.areEqual(UTIL_HttpClient.DefaultOutboundHandler.class.getName(), apiCall.ServiceName__c, 'Service should be UTIL_HttpClient.Handler');
		Assert.areEqual(SEL_ApiCall.TYPE_OUTBOUND, apiCall.Direction__c, 'Type should be Outbound');
	}

	/**
	 * @description Tests that logging is skipped when skipLogging() is configured.
	 */
	@IsTest
	private static void shouldSkipLoggingWhenConfigured()
	{
		registerSuccessMock();

		UTIL_HttpClient.RequestBuilder builder = UTIL_HttpClient.get(TEST_CREDENTIAL, TEST_PATH).skipLogging();
		assertSend(builder);

		Assert.isNull(builder.handlerInstance.apiCall.Id, 'API call record should not be persisted');
	}

	/**
	 * @description Tests that the correlation ID is set on the API call record.
	 */
	@IsTest
	private static void shouldSetCorrelationId()
	{
		registerSuccessMock();

		UTIL_HttpClient.RequestBuilder builder = UTIL_HttpClient.get(TEST_CREDENTIAL, TEST_PATH).withCorrelationId('corr-123');
		assertSend(builder);

		Assert.areEqual('corr-123', builder.handlerInstance.apiCall.LoggerContext__c, 'Correlation ID should be set');
	}

	/**
	 * @description Tests that the triggering record ID is set on the API call record.
	 */
	@IsTest
	private static void shouldSetTriggeringRecordId()
	{
		registerSuccessMock();

		Foobar__c record = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType).build();

		UTIL_HttpClient.RequestBuilder builder = UTIL_HttpClient.get(TEST_CREDENTIAL, TEST_PATH).withTriggeringRecord(record.Id);
		assertSend(builder);

		Assert.areEqual
				(
						String.valueOf(record.Id),
						builder.handlerInstance.apiCall.TriggeringRecordId__c,
						'Triggering record ID should be set'
				);
	}

	/**
	 * @description Tests credential() overrides the initial credential.
	 */
	@IsTest
	private static void shouldOverrideCredential()
	{
		registerSuccessMock();
		assertSend(UTIL_HttpClient.get(TEST_CREDENTIAL, TEST_PATH).credential('OverrideCredential'), API_Base.HTTP_OK);
	}

	/**
	 * @description Tests that retries are exhausted and the final failed response is returned.
	 */
	@IsTest
	private static void shouldExhaustRetriesAndReturnFinalResponse()
	{
		registerServerErrorMock();

		UTIL_HttpClient.RequestBuilder builder = UTIL_HttpClient.get(TEST_CREDENTIAL, TEST_PATH).withRetry(2);
		assertSend(builder, API_Base.HTTP_INTERNAL_SERVER_ERROR);

		Assert.areEqual(2, (Integer)builder.handlerInstance.apiCall.Retries__c, 'Should record all retries');
	}

	/**
	 * @description Tests that retry only occurs on configured status codes.
	 */
	@IsTest
	private static void shouldRetryOnlyOnConfiguredStatusCodes()
	{
		registerTooManyRequestsMock();

		UTIL_HttpClient.RequestBuilder builder = UTIL_HttpClient.get(TEST_CREDENTIAL, TEST_PATH)
				.withRetry(2)
				.retryOn(new Set<Integer> {429});
		assertSend(builder, API_Base.HTTP_TOO_MANY_REQUESTS);

		Assert.areEqual(2, (Integer)builder.handlerInstance.apiCall.Retries__c, 'Should retry on 429');
	}

	/**
	 * @description Tests that a 400 client error is not retried by default.
	 */
	@IsTest
	private static void shouldNotRetryOnClientError()
	{
		registerBadRequestMock();

		UTIL_HttpClient.RequestBuilder builder = UTIL_HttpClient.get(TEST_CREDENTIAL, TEST_PATH).withRetry(2);
		assertSend(builder, API_Base.HTTP_BAD_REQUEST);

		Assert.isNull(builder.handlerInstance.apiCall.Retries__c, 'Should not retry on 400');
	}

	/**
	 * @description Tests that a call is aborted when circuit breaker is OPEN.
	 * Requires Platform Cache to persist circuit breaker state between instances.
	 */
	@IsTest
	private static void shouldAbortWhenCircuitBreakerOpen()
	{
		if(!UTIL_Cache.isOrgAllocated())
		{
			return;
		}

		registerSuccessMock();

		UTIL_CircuitBreaker.Breaker breaker = UTIL_CircuitBreaker.monitor(TEST_CREDENTIAL);
		breaker.forceOpen();

		UTIL_HttpClient.RequestBuilder builder = UTIL_HttpClient.get(TEST_CREDENTIAL, TEST_PATH).withCircuitBreaker();

		Test.startTest();
		builder.send();
		Test.stopTest();

		Assert.isTrue(builder.handlerInstance.result.isAborted, 'Should abort when circuit breaker is open');
	}

	/**
	 * @description Tests that circuit breaker success is recorded after a successful call.
	 */
	@IsTest
	private static void shouldRecordCircuitBreakerSuccess()
	{
		registerSuccessMock();

		UTIL_CircuitBreaker.Breaker breaker = UTIL_CircuitBreaker.monitor(TEST_CREDENTIAL);

		UTIL_HttpClient.RequestBuilder builder = UTIL_HttpClient.get(TEST_CREDENTIAL, TEST_PATH).withCircuitBreaker();
		assertSend(builder);

		Assert.areEqual(UTIL_CircuitBreaker.State.CLOSED, breaker.getState(), 'Circuit should be closed');
	}

	/**
	 * @description Tests that a ApiIssue__c record is created with LOG_FAILURE action.
	 */
	@IsTest
	private static void shouldCreateFailureRecordOnLogFailure()
	{
		registerServerErrorMock();

		Foobar__c record = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType).build();

		UTIL_HttpClient.RequestBuilder builder = UTIL_HttpClient.get(TEST_CREDENTIAL, TEST_PATH)
				.onFailure(UTIL_HttpClient.FailureAction.LOG_FAILURE)
				.withTriggeringRecord(record.Id);
		assertSend(builder);

		String serviceName = builder.handlerInstance.apiCall.ServiceName__c;
		List<ApiIssue__c> failures =
		[
				SELECT ServiceName__c
				FROM ApiIssue__c
				WHERE ServiceName__c = :serviceName
		];

		Assert.areEqual(1, failures.size(), 'Should create one failure record');
	}

	/**
	 * @description Tests that LOG_FAILURE skips retry and logs immediately.
	 */
	@IsTest
	private static void shouldSkipRetryWithLogFailureAction()
	{
		registerServerErrorMock();

		UTIL_HttpClient.RequestBuilder builder = UTIL_HttpClient.get(TEST_CREDENTIAL, TEST_PATH)
				.onFailure(UTIL_HttpClient.FailureAction.LOG_FAILURE)
				.withRetry(3);
		assertSend(builder);

		Assert.isNull(builder.handlerInstance.apiCall.Retries__c, 'Should not retry with LOG_FAILURE');
	}

	/**
	 * @description Tests that send() returns a cached response on subsequent calls.
	 */
	@IsTest
	private static void shouldReturnCachedResponse()
	{
		registerSuccessMock();

		UTIL_HttpClient.RequestBuilder builder = UTIL_HttpClient.get(TEST_CREDENTIAL, TEST_PATH);

		Test.startTest();
		HttpResponse first = builder.send();
		HttpResponse second = builder.send();
		Test.stopTest();

		assertNotAborted(builder);
		Assert.isTrue(first === second, 'Should return same cached response instance');
	}

	/**
	 * @description Tests the failed API call record has error details populated.
	 */
	@IsTest
	private static void shouldLogFailedApiCallRecordWithErrors()
	{
		registerServerErrorMock();

		UTIL_HttpClient.RequestBuilder builder = UTIL_HttpClient.get(TEST_CREDENTIAL, TEST_PATH);
		assertSend(builder);

		Assert.isTrue(builder.handlerInstance.result.hasFailed, 'Result should be failed');
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
	 * @description Tests that a custom circuit breaker name is used when specified.
	 */
	@IsTest
	private static void shouldUseCustomCircuitBreakerName()
	{
		registerSuccessMock();

		UTIL_CircuitBreaker.Breaker breaker = UTIL_CircuitBreaker.monitor('shared-circuit');

		UTIL_HttpClient.RequestBuilder builder = UTIL_HttpClient.get(TEST_CREDENTIAL, TEST_PATH).withCircuitBreaker('shared-circuit');
		assertSend(builder);

		Assert.areEqual(UTIL_CircuitBreaker.State.CLOSED, breaker.getState(), 'Named circuit should be closed');
	}

	/**
	 * @description Tests that linear backoff configuration is applied.
	 */
	@IsTest
	private static void shouldApplyLinearBackoffConfig()
	{
		registerSuccessMock();

		UTIL_HttpClient.RequestBuilder builder = UTIL_HttpClient.get(TEST_CREDENTIAL, TEST_PATH).withRetry(3, 30);
		assertSend(builder);

		Assert.isNotNull(builder.handlerInstance, 'Handler should be present');
		Assert.areEqual(3, builder.handlerInstance.apiCall.MaxRetries__c, 'Max retries should match configured value');
	}

	/**
	 * @description Tests that exponential backoff configuration is applied.
	 */
	@IsTest
	private static void shouldApplyExponentialBackoffConfig()
	{
		registerSuccessMock();

		UTIL_HttpClient.RequestBuilder builder = UTIL_HttpClient.get(TEST_CREDENTIAL, TEST_PATH).withExponentialBackoff(3, 10);
		assertSend(builder);

		Assert.isNotNull(builder.handlerInstance, 'Handler should be present');
		Assert.areEqual(3, builder.handlerInstance.apiCall.MaxRetries__c, 'Max retries should match configured value');
	}

	/**
	 * @description Tests that withParameter and withParameters set request parameters.
	 */
	@IsTest
	private static void shouldSetRequestParameters()
	{
		registerSuccessMock();

		UTIL_HttpClient.RequestBuilder builder = UTIL_HttpClient.get(TEST_CREDENTIAL, TEST_PATH)
				.withParameter('key1', 'value1')
				.withParameters(new Map<String, String> {'key2' => 'value2'});
		assertSend(builder);

		String parameters = builder.handlerInstance.apiCall.RequestParameters__c;
		Assert.isTrue(String.isNotBlank(parameters), 'Request parameters should be set');
		Assert.isTrue(parameters.contains('key1'), 'Should contain key1 parameter');
		Assert.isTrue(parameters.contains('value1'), 'Should contain value1');
		Assert.isTrue(parameters.contains('key2'), 'Should contain key2 parameter');
		Assert.isTrue(parameters.contains('value2'), 'Should contain value2');
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
	 * @description Tests that a single request replacement token transforms the request body.
	 */
	@IsTest
	private static void shouldApplyRequestReplacementToken()
	{
		registerSuccessMock();

		UTIL_HttpClient.RequestBuilder builder = UTIL_HttpClient.post(TEST_CREDENTIAL, TEST_PATH)
				.body('{"currencyIsoCode":"USD"}')
				.replaceRequestToken('currencyIsoCode', 'currency');
		assertSend(builder);

		Assert.isTrue(builder.handlerInstance.result.requestBody.contains('"currency"'), 'Request body should contain replaced token');
		Assert.isFalse(builder.handlerInstance.result.requestBody.contains('currencyIsoCode'), 'Request body should not contain original token');
	}

	/**
	 * @description Tests that multiple request replacement tokens transform the request body.
	 */
	@IsTest
	private static void shouldApplyMultipleRequestReplacementTokens()
	{
		registerSuccessMock();

		Map<String, String> tokens = new Map<String, String>
		{
				'currencyIsoCode' => 'currency',
				'groupName' => 'group'
		};

		UTIL_HttpClient.RequestBuilder builder = UTIL_HttpClient.post(TEST_CREDENTIAL, TEST_PATH)
				.body('{"currencyIsoCode":"USD","groupName":"A"}')
				.replaceRequestTokens(tokens);
		assertSend(builder);

		Assert.isTrue(builder.handlerInstance.result.requestBody.contains('"currency"'), 'Should replace currencyIsoCode');
		Assert.isTrue(builder.handlerInstance.result.requestBody.contains('"group"'), 'Should replace groupName');
	}

	/**
	 * @description Tests that a single response replacement token transforms the response body.
	 */
	@IsTest
	private static void shouldApplyResponseReplacementToken()
	{
		API_MockFactory.MockResponse mock = new API_MockFactory.MockResponse();
		mock.statusCode = API_Base.HTTP_OK;
		mock.status = 'OK';
		mock.body = '{"currency":"USD"}';

		UTIL_HttpClient.RequestBuilder builder = UTIL_HttpClient.post(TEST_CREDENTIAL, TEST_PATH)
				.body('{}')
				.replaceResponseToken('currency', 'currencyIsoCode')
				.withMockResponse(mock);

		Test.startTest();
		String responseBody = builder.asString();
		Test.stopTest();

		assertNotAborted(builder);
		Assert.isTrue(responseBody.contains('currencyIsoCode'), 'Response body should contain replaced token');
		Assert.isFalse(responseBody.contains('"currency"'), 'Response body should not contain original token');
	}

	/**
	 * @description Tests that multiple response replacement tokens transform the response body.
	 */
	@IsTest
	private static void shouldApplyMultipleResponseReplacementTokens()
	{
		API_MockFactory.MockResponse mock = new API_MockFactory.MockResponse();
		mock.statusCode = API_Base.HTTP_OK;
		mock.status = 'OK';
		mock.body = '{"currency":"USD","group":"A"}';

		Map<String, String> tokens = new Map<String, String>
		{
				'currency' => 'currencyIsoCode',
				'group' => 'groupName'
		};

		UTIL_HttpClient.RequestBuilder builder = UTIL_HttpClient.post(TEST_CREDENTIAL, TEST_PATH)
				.body('{}')
				.replaceResponseTokens(tokens)
				.withMockResponse(mock);

		Test.startTest();
		String responseBody = builder.asString();
		Test.stopTest();

		assertNotAborted(builder);
		Assert.isTrue(responseBody.contains('currencyIsoCode'), 'Should replace currency');
		Assert.isTrue(responseBody.contains('groupName'), 'Should replace group');
	}

	/**
	 * @description Tests that request tokens gracefully handle an empty body.
	 */
	@IsTest
	private static void shouldHandleRequestTokensWithNoBody()
	{
		registerSuccessMock();
		assertSend(UTIL_HttpClient.get(TEST_CREDENTIAL, TEST_PATH).replaceRequestToken('currencyIsoCode', 'currency'), API_Base.HTTP_OK);
	}

	/**
	 * @description Tests that response tokens are not applied on a failed response (500).
	 */
	@IsTest
	private static void shouldNotApplyResponseTokensOnFailure()
	{
		API_MockFactory.MockResponse mock = new API_MockFactory.MockResponse();
		mock.statusCode = API_Base.HTTP_INTERNAL_SERVER_ERROR;
		mock.status = 'Internal Server Error';
		mock.body = '{"currency":"USD"}';

		HttpResponse response = assertSend
				(
						UTIL_HttpClient.post(TEST_CREDENTIAL, TEST_PATH)
								.body('{}')
								.replaceResponseToken('currency', 'currencyIsoCode')
								.withMockResponse(mock),
						API_Base.HTTP_INTERNAL_SERVER_ERROR
				);

		Assert.isTrue(response.getBody().contains('"currency"'), 'Response tokens should not be applied on failure');
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
	 * @description Tests that an empty deserialized query parameter map returns null.
	 */
	@IsTest
	private static void shouldReturnNullForEmptyQueryParameterMap()
	{
		registerSuccessMock();
		assertSend(UTIL_HttpClient.get(TEST_CREDENTIAL, TEST_PATH).withParameter(UTIL_HttpClient.KEY_QUERY_PARAMETERS, '{}'), API_Base.HTTP_OK);
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
	 * @description Tests that withIdempotencyKey() passes the explicit key through to the API call.
	 */
	@IsTest
	private static void shouldPassExplicitIdempotencyKeyToApiCall()
	{
		registerSuccessMock();
		String expectedKey = 'order-12345';

		UTIL_HttpClient.RequestBuilder builder = UTIL_HttpClient.post(TEST_CREDENTIAL, TEST_PATH)
				.body('{"amount":100}')
				.withIdempotencyKey(expectedKey);
		assertSend(builder);

		Assert.areEqual(expectedKey, builder.handlerInstance.apiCall.IdempotencyKey__c, 'Explicit idempotency key should be set on ApiCall');
		Assert.areEqual(expectedKey, builder.handlerInstance.request.getHeader(API_Base.HEADER_IDEMPOTENCY_KEY), 'Explicit idempotency key should be sent as HTTP header');
	}

	/**
	 * @description Tests that retries are skipped when the callout budget is exhausted.
	 * The initial attempt proceeds but no retries are performed.
	 */
	@IsTest
	private static void shouldSkipRetriesWhenCalloutBudgetExhausted()
	{
		registerServerErrorMock();
		API_Dispatcher.simulateCalloutBudgetExhausted = true;

		UTIL_HttpClient.RequestBuilder builder = UTIL_HttpClient.get(TEST_CREDENTIAL, TEST_PATH).withRetry(2);

		Test.startTest();
		builder.send();
		Test.stopTest();

		Assert.isNull(builder.handlerInstance.apiCall.Retries__c, 'Should not retry when callout budget is exhausted');
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
	 * @description DTO used for typed deserialization tests.
	 */
	private class ResponseDTO
	{
		/**
		 * @description The status field.
		 */
		public String status;

		/**
		 * @description The id field.
		 */
		public String id;
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