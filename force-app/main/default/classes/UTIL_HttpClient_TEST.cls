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
 * @date February 2026, October 2026
 */
@IsTest(seeAllData=false isParallel=false)
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
	 * @description A second credential, for calls that must not share the first credential's own circuit breaker.
	 */
	private static final String OTHER_CREDENTIAL = 'OtherTestCredential';

	/**
	 * @description The length of a random circuit breaker name, so no breaker state left by another test is shared.
	 */
	private static final Integer RANDOM_BREAKER_NAME_LENGTH = 16;

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
	 * @description Tests that the correlation id given to a call is stored as a logger context the logger reads back:
	 * hydrating the stored document restores that correlation.
	 */
	@IsTest
	private static void shouldStoreTheCorrelationInAReadableLoggerContext()
	{
		registerSuccessMock();
		String correlationId = UTIL_Random.randomUUID();

		UTIL_HttpClient.RequestBuilder builder = UTIL_HttpClient.get(TEST_CREDENTIAL, TEST_PATH).withCorrelationId(correlationId);
		assertSend(builder);

		LOG_Builder.setCorrelationId(null);
		LOG_Builder.hydrateContext(builder.handlerInstance.apiCall.LoggerContext__c);
		Assert.areEqual(correlationId, LOG_Builder.correlationId, 'The stored logger context must hydrate to the correlation the call was built with');
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
	 * @description Two calls on one credential that name different circuit breakers keep separate breakers: the call whose
	 * breaker is open is refused without being sent, and its error line names that breaker, while the other call is sent.
	 */
	@IsTest
	private static void shouldKeepSeparateBreakersForDifferentNamesOnOneCredential()
	{
		if(!UTIL_Cache.isOrgAllocated())
		{
			return;
		}

		registerSuccessMock();
		String openBreakerName = UTIL_Random.randomAlphanumeric(RANDOM_BREAKER_NAME_LENGTH);
		String closedBreakerName = UTIL_Random.randomAlphanumeric(RANDOM_BREAKER_NAME_LENGTH);
		UTIL_CircuitBreaker.monitor(openBreakerName).forceOpen();

		UTIL_HttpClient.RequestBuilder sentCall = UTIL_HttpClient.get(TEST_CREDENTIAL, TEST_PATH).withCircuitBreaker(closedBreakerName);
		UTIL_HttpClient.RequestBuilder refusedCall = UTIL_HttpClient.get(TEST_CREDENTIAL, TEST_PATH).withCircuitBreaker(openBreakerName);

		Test.startTest();
		HttpResponse response = sentCall.send();
		refusedCall.send();
		Test.stopTest();

		assertNotAborted(sentCall);
		Assert.areEqual(API_Base.HTTP_OK, response.getStatusCode(), 'Expected the call on the closed breaker to be sent, got ' + response.getStatusCode());
		List<String> errors = refusedCall.handlerInstance.result.errors;
		Assert.isTrue(errors.contains(buildOpenBreakerLine(openBreakerName)), 'Expected the call to be refused by breaker ' + openBreakerName + ', got ' + errors);
	}

	/**
	 * @description Two calls on different credentials that name the same circuit breaker share it: once that breaker is
	 * open, both are refused without being sent, though neither credential's own breaker is open.
	 */
	@IsTest
	private static void shouldShareOneNamedBreakerAcrossCredentials()
	{
		if(!UTIL_Cache.isOrgAllocated())
		{
			return;
		}

		registerSuccessMock();
		String sharedBreakerName = UTIL_Random.randomAlphanumeric(RANDOM_BREAKER_NAME_LENGTH);
		UTIL_CircuitBreaker.monitor(sharedBreakerName).forceOpen();

		UTIL_HttpClient.RequestBuilder firstCall = UTIL_HttpClient.get(TEST_CREDENTIAL, TEST_PATH).withCircuitBreaker(sharedBreakerName);
		UTIL_HttpClient.RequestBuilder secondCall = UTIL_HttpClient.get(OTHER_CREDENTIAL, TEST_PATH).withCircuitBreaker(sharedBreakerName);

		Test.startTest();
		firstCall.send();
		secondCall.send();
		Test.stopTest();

		String expectedLine = buildOpenBreakerLine(sharedBreakerName);
		List<String> firstErrors = firstCall.handlerInstance.result.errors;
		List<String> secondErrors = secondCall.handlerInstance.result.errors;
		Assert.isTrue(firstErrors.contains(expectedLine), 'Expected the first credential\'s call to be refused, got ' + firstErrors);
		Assert.isTrue(secondErrors.contains(expectedLine), 'Expected the second credential\'s call to be refused, got ' + secondErrors);
	}

	/**
	 * @description A call that enables the circuit breaker without a name uses the credential's own breaker,
	 * and its error line names the credential; enabling it without a name after giving one drops the name given.
	 */
	@IsTest
	private static void shouldUseTheCredentialsBreakerWithoutAName()
	{
		if(!UTIL_Cache.isOrgAllocated())
		{
			return;
		}

		registerSuccessMock();
		UTIL_CircuitBreaker.monitor(TEST_CREDENTIAL).forceOpen();
		String droppedBreakerName = UTIL_Random.randomAlphanumeric(RANDOM_BREAKER_NAME_LENGTH);

		UTIL_HttpClient.RequestBuilder unnamedCall = UTIL_HttpClient.get(TEST_CREDENTIAL, TEST_PATH).withCircuitBreaker();
		UTIL_HttpClient.RequestBuilder renamedCall = UTIL_HttpClient.get(TEST_CREDENTIAL, TEST_PATH).withCircuitBreaker(droppedBreakerName).withCircuitBreaker();

		Test.startTest();
		unnamedCall.send();
		renamedCall.send();
		Test.stopTest();

		String expectedLine = buildOpenBreakerLine(TEST_CREDENTIAL);
		List<String> unnamedErrors = unnamedCall.handlerInstance.result.errors;
		List<String> renamedErrors = renamedCall.handlerInstance.result.errors;
		Assert.isTrue(unnamedErrors.contains(expectedLine), 'Expected the unnamed call to be refused by the credential\'s breaker, got ' + unnamedErrors);
		Assert.isTrue(renamedErrors.contains(expectedLine), 'Expected the name given first to be dropped, got ' + renamedErrors);
	}

	/**
	 * @description A call made through useHandler(...) that names a circuit breaker uses that breaker instead of the
	 * handler's own: once the named breaker is open, the handler's call is refused without being sent.
	 */
	@IsTest
	private static void shouldUseTheNamedBreakerForADelegatedCall()
	{
		if(!UTIL_Cache.isOrgAllocated())
		{
			return;
		}

		String breakerName = UTIL_Random.randomAlphanumeric(RANDOM_BREAKER_NAME_LENGTH);
		UTIL_CircuitBreaker.monitor(breakerName).forceOpen();

		UTIL_HttpClient.RequestBuilder delegatedCall = UTIL_HttpClient.useHandler(TestMockedHandler.class).withCircuitBreaker(breakerName);

		Test.startTest();
		delegatedCall.send();
		Test.stopTest();

		List<String> errors = delegatedCall.handlerInstance.result.errors;
		Assert.isTrue(errors.contains(buildOpenBreakerLine(breakerName)), 'Expected the delegated call to be refused by breaker ' + breakerName + ', got ' + errors);
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
	 * @description Tests that an empty deserialized query parameter map returns null.
	 */
	@IsTest
	private static void shouldReturnNullForEmptyQueryParameterMap()
	{
		registerSuccessMock();
		assertSend(UTIL_HttpClient.get(TEST_CREDENTIAL, TEST_PATH).withParameter(UTIL_HttpClient.KEY_QUERY_PARAMETERS, '{}'), API_Base.HTTP_OK);
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
	 * @description The error line a call refused by an open circuit breaker carries.
	 *
	 * @param breakerName The circuit breaker the line names
	 *
	 * @return The labelled line naming that breaker.
	 */
	private static String buildOpenBreakerLine(String breakerName)
	{
		return String.format(System.Label.OutboundCall_CircuitOpen, new List<Object> {breakerName});
	}

	/**
	 * @description Delegate handler that runs the standard outbound flow against its default mock body, so a call made
	 * through it reaches the circuit breaker check like any real handler's call.
	 */
	public class TestMockedHandler extends API_Outbound
	{
		/**
		 * @description Configure handler with no triggering record requirement and a default mock body.
		 */
		public override void configure()
		{
			super.configure();
			requiresTriggeringRecord = false;
			defaultMockBody = RESPONSE_BODY;
		}
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
}