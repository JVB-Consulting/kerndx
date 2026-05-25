// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Unit tests for API_MockFactory central mock registry.
 *
 * @see API_MockFactory
 *
 * @author Jason van Beukering
 *
 * @group Web Services
 *
 * @date February 2026, May 2026
 */
@IsTest(SeeAllData=false IsParallel=true)
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs,PMD.CyclomaticComplexity')
private class API_MockFactory_TEST
{
	/**
	 * @description Test service class name.
	 */
	private static final String TEST_SERVICE = 'API_TestService';

	/**
	 * @description Test response body.
	 */
	private static final String TEST_BODY = '{"success":true}';

	/**
	 * @description Tests basic mock registration and retrieval.
	 */
	@IsTest
	private static void shouldRegisterAndRetrieveMock()
	{
		API_MockFactory.forService(TEST_SERVICE).body(TEST_BODY).statusCode(API_Base.HTTP_OK).register();

		API_MockFactory.MockResponse mock = API_MockFactory.getOutboundMock(TEST_SERVICE, null);

		Assert.isNotNull(mock, 'Mock should be registered');
		Assert.areEqual(API_Base.HTTP_OK, mock.statusCode, 'Status code should match');
		Assert.areEqual(TEST_BODY, mock.body, 'Body should match');
	}

	/**
	 * @description Tests that getOutboundMock returns null when no mock registered.
	 */
	@IsTest
	private static void shouldReturnNullWhenNoMockRegistered()
	{
		API_MockFactory.MockResponse mock = API_MockFactory.getOutboundMock('API_NonExistent', null);

		Assert.isNull(mock, 'Should return null when no mock registered');
	}

	/**
	 * @description Tests mock registration with fault simulation.
	 */
	@IsTest
	private static void shouldRegisterMockWithFaultSimulation()
	{
		API_MockFactory.forService(TEST_SERVICE).body(TEST_BODY).statusCode(API_Base.HTTP_OK).register();

		API_MockFactory.MockResponse mock = API_MockFactory.getOutboundMock(TEST_SERVICE, null);

		Assert.isNotNull(mock, 'Mock should be registered');
		Assert.areEqual(API_Base.HTTP_OK, mock.statusCode, 'Status code should match');
	}

	/**
	 * @description Tests 100% failure rate returns simulated failure.
	 */
	@IsTest
	private static void shouldSimulateFailureAtFullRate()
	{
		API_MockFactory.forService(TEST_SERVICE).body(TEST_BODY).statusCode(API_Base.HTTP_OK).withFailureRate(100).register();

		API_MockFactory.MockResponse mock = API_MockFactory.getOutboundMock(TEST_SERVICE, null);

		Assert.areEqual(API_Base.HTTP_INTERNAL_SERVER_ERROR, mock.statusCode, 'Should return 500 for simulated failure');
		Assert.isTrue(mock.simulatedFailure, 'Should flag as simulated failure');
	}

	/**
	 * @description Tests mock registration from HttpResponse.
	 */
	@IsTest
	private static void shouldRegisterMockFromHttpResponse()
	{
		HttpResponse httpResponse = new HttpResponse();
		httpResponse.setStatusCode(API_Base.HTTP_CREATED);
		httpResponse.setBody('{"id":"123"}');

		API_MockFactory.forService(TEST_SERVICE).fromResponse(httpResponse).register();

		API_MockFactory.MockResponse mock = API_MockFactory.getOutboundMock(TEST_SERVICE, null);

		Assert.areEqual(API_Base.HTTP_CREATED, mock.statusCode, 'Status code should match HttpResponse');
		Assert.areEqual('{"id":"123"}', mock.body, 'Body should match HttpResponse');
	}

	/**
	 * @description Tests builder withHeader adds a single header.
	 */
	@IsTest
	private static void shouldRegisterMockWithSingleHeader()
	{
		API_MockFactory.forService(TEST_SERVICE)
				.body(TEST_BODY).statusCode(API_Base.HTTP_OK)
				.withHeader('X-Custom', 'value')
				.register();

		API_MockFactory.MockResponse mock = API_MockFactory.getOutboundMock(TEST_SERVICE, null);

		Assert.areEqual('value', mock.headers.get('X-Custom'), 'Should contain custom header');
	}

	/**
	 * @description Tests builder withHeaders adds multiple headers.
	 */
	@IsTest
	private static void shouldRegisterMockWithMultipleHeaders()
	{
		Map<String, String> headers = new Map<String, String>
		{
				'Content-Type' => 'application/json',
				'X-Request-Id' => 'abc-123'
		};

		API_MockFactory.forService(TEST_SERVICE)
				.body(TEST_BODY).statusCode(API_Base.HTTP_OK)
				.withHeaders(headers)
				.register();

		API_MockFactory.MockResponse mock = API_MockFactory.getOutboundMock(TEST_SERVICE, null);

		Assert.areEqual('application/json', mock.headers.get('Content-Type'), 'Should contain Content-Type header');
		Assert.areEqual('abc-123', mock.headers.get('X-Request-Id'), 'Should contain X-Request-Id header');
	}

	/**
	 * @description Tests response interpolation with request data.
	 */
	@IsTest
	private static void shouldInterpolateResponseBody()
	{
		String template = '{"echoId":"{{request.id}}","echoName":"{{request.name}}"}';
		API_MockFactory.forService(TEST_SERVICE).body(template).statusCode(API_Base.HTTP_OK).register();

		String requestBody = '{"id":"12345","name":"Test Account"}';
		API_MockFactory.MockResponse mock = API_MockFactory.getOutboundMock(TEST_SERVICE, null, requestBody);

		Assert.isTrue(mock.body.contains('12345'), 'Should interpolate id');
		Assert.isTrue(mock.body.contains('Test Account'), 'Should interpolate name');
	}

	/**
	 * @description Tests nested field interpolation.
	 */
	@IsTest
	private static void shouldInterpolateNestedFields()
	{
		String template = '{"result":"{{request.data.value}}"}';
		API_MockFactory.forService(TEST_SERVICE).body(template).statusCode(API_Base.HTTP_OK).register();

		String requestBody = '{"data":{"value":"nested_value"}}';
		API_MockFactory.MockResponse mock = API_MockFactory.getOutboundMock(TEST_SERVICE, null, requestBody);

		Assert.isTrue(mock.body.contains('nested_value'), 'Should interpolate nested value');
	}

	/**
	 * @description Tests interpolation returns template when request body is blank.
	 */
	@IsTest
	private static void shouldReturnTemplateWhenRequestBodyBlank()
	{
		String template = '{"id":"{{request.id}}"}';

		String result = API_MockFactory.interpolateResponse(template, '');

		Assert.areEqual(template, result, 'Should return original template');
	}

	/**
	 * @description Tests interpolation gracefully handles invalid JSON.
	 */
	@IsTest
	private static void shouldHandleInvalidJsonInInterpolation()
	{
		String template = '{"id":"{{request.id}}"}';

		String result = API_MockFactory.interpolateResponse(template, 'not-json');

		Assert.areEqual(template, result, 'Should return original template for invalid JSON');
	}

	/**
	 * @description Tests hasMock returns true for registered mock.
	 */
	@IsTest
	private static void shouldDetectRegisteredMock()
	{
		API_MockFactory.forService(TEST_SERVICE).body(TEST_BODY).statusCode(API_Base.HTTP_OK).register();

		Assert.isTrue(API_MockFactory.hasMock(TEST_SERVICE), 'Should detect registered mock');
	}

	/**
	 * @description Tests hasMock returns false for unregistered service.
	 */
	@IsTest
	private static void shouldReturnFalseForUnregisteredMock()
	{
		Assert.isFalse(API_MockFactory.hasMock('API_NonExistent'), 'Should return false for unregistered');
	}

	/**
	 * @description Tests unregistering a mock.
	 */
	@IsTest
	private static void shouldUnregisterMock()
	{
		API_MockFactory.forService(TEST_SERVICE).body(TEST_BODY).statusCode(API_Base.HTTP_OK).register();
		API_MockFactory.unregisterMock(TEST_SERVICE);

		Assert.isFalse(API_MockFactory.hasMock(TEST_SERVICE), 'Mock should be unregistered');
	}

	/**
	 * @description Tests clearMocks removes all registrations.
	 */
	@IsTest
	private static void shouldClearAllMocks()
	{
		API_MockFactory.forService(TEST_SERVICE).body(TEST_BODY).statusCode(API_Base.HTTP_OK).register();
		API_MockFactory.clearMocks();

		Assert.isFalse(API_MockFactory.hasMock(TEST_SERVICE), 'All mocks should be cleared');
	}

	/**
	 * @description Tests wasCalled returns true after mock is invoked.
	 */
	@IsTest
	private static void shouldTrackWasCalled()
	{
		API_MockFactory.forService(TEST_SERVICE).body(TEST_BODY).statusCode(API_Base.HTTP_OK).register();
		API_MockFactory.getOutboundMock(TEST_SERVICE, null);

		Assert.isTrue(API_MockFactory.wasCalled(TEST_SERVICE), 'Should detect invocation');
	}

	/**
	 * @description Tests wasCalledTimes with exact count.
	 */
	@IsTest
	private static void shouldTrackInvocationCount()
	{
		API_MockFactory.forService(TEST_SERVICE).body(TEST_BODY).statusCode(API_Base.HTTP_OK).register();
		API_MockFactory.getOutboundMock(TEST_SERVICE, null);
		API_MockFactory.getOutboundMock(TEST_SERVICE, null);

		Assert.isTrue(API_MockFactory.wasCalledTimes(TEST_SERVICE, 2), 'Should be called twice');
		Assert.isFalse(API_MockFactory.wasCalledTimes(TEST_SERVICE, 1), 'Should not be called once');
	}

	/**
	 * @description Tests wasNeverCalled for unregistered service.
	 */
	@IsTest
	private static void shouldDetectNeverCalled()
	{
		Assert.isTrue(API_MockFactory.wasNeverCalled('API_Uncalled'), 'Should detect never called');
	}

	/**
	 * @description Tests lastRequestContains with matching content.
	 */
	@IsTest
	private static void shouldVerifyLastRequestContent()
	{
		API_MockFactory.forService(TEST_SERVICE).body(TEST_BODY).statusCode(API_Base.HTTP_OK).register();
		API_MockFactory.getOutboundMock(TEST_SERVICE, null, '{"orderId":"ORD-123"}');

		Assert.isTrue(
				API_MockFactory.lastRequestContains(TEST_SERVICE, 'ORD-123'),
				'Should find content in last request'
		);
	}

	/**
	 * @description Tests lastRequestContains returns false when no invocations.
	 */
	@IsTest
	private static void shouldReturnFalseForLastRequestWhenNeverCalled()
	{
		Assert.isFalse(
				API_MockFactory.lastRequestContains('API_Uncalled', 'anything'),
				'Should return false when never called'
		);
	}

	/**
	 * @description Tests getInvocations returns invocation records.
	 */
	@IsTest
	private static void shouldReturnInvocationRecords()
	{
		API_MockFactory.forService(TEST_SERVICE).body(TEST_BODY).statusCode(API_Base.HTTP_OK).register();
		API_MockFactory.getOutboundMock(TEST_SERVICE, null, '{"id":"1"}');

		List<API_MockFactory.MockInvocation> invocations = API_MockFactory.getInvocations(TEST_SERVICE);

		Assert.areEqual(1, invocations.size(), 'Should have one invocation');
		Assert.areEqual('{"id":"1"}', invocations[0].requestBody, 'Should capture request body');
	}

	/**
	 * @description Tests getInvocations returns empty list for uncalled service.
	 */
	@IsTest
	private static void shouldReturnEmptyInvocationsForUncalledService()
	{
		List<API_MockFactory.MockInvocation> invocations = API_MockFactory.getInvocations('API_Uncalled');

		Assert.isTrue(invocations.isEmpty(), 'Should return empty list');
	}

	/**
	 * @description Tests clearInvocations clears history without clearing mocks.
	 */
	@IsTest
	private static void shouldClearInvocationsOnly()
	{
		API_MockFactory.forService(TEST_SERVICE).body(TEST_BODY).statusCode(API_Base.HTTP_OK).register();
		API_MockFactory.getOutboundMock(TEST_SERVICE, null);
		API_MockFactory.clearInvocations();

		Assert.isTrue(API_MockFactory.hasMock(TEST_SERVICE), 'Mock should still be registered');
		Assert.isTrue(API_MockFactory.wasNeverCalled(TEST_SERVICE), 'Invocations should be cleared');
	}

	/**
	 * @description Tests getInboundMock works the same as getOutboundMock for memory registry.
	 */
	@IsTest
	private static void shouldGetInboundMockFromMemory()
	{
		API_MockFactory.forService(TEST_SERVICE).body(TEST_BODY).statusCode(API_Base.HTTP_OK).register();

		API_MockFactory.MockResponse mock = API_MockFactory.getInboundMock(TEST_SERVICE, null, null);

		Assert.isNotNull(mock, 'Should retrieve inbound mock from memory');
		Assert.areEqual(API_Base.HTTP_OK, mock.statusCode, 'Status code should match');
	}

	/**
	 * @description Tests case-insensitive key normalization.
	 */
	@IsTest
	private static void shouldNormalizeKeyCaseInsensitive()
	{
		API_MockFactory.forService('API_MyService').body(TEST_BODY).statusCode(API_Base.HTTP_OK).register();

		Assert.isTrue(API_MockFactory.hasMock('api_myservice'), 'Should match lowercase');
		Assert.isTrue(API_MockFactory.hasMock('API_MYSERVICE'), 'Should match uppercase');
	}

	/**
	 * @description Tests MockResponse clone creates independent copy.
	 */
	@IsTest
	private static void shouldCopyMockResponse()
	{
		API_MockFactory.MockResponse original = new API_MockFactory.MockResponse();
		original.body = 'original';
		original.statusCode = API_Base.HTTP_OK;
		original.headers.put('X-Test', 'value');

		API_MockFactory.MockResponse cloned = original.copy();
		cloned.body = 'cloned';
		cloned.headers.put('X-New', 'new');

		Assert.areEqual('original', original.body, 'Original should be unchanged');
		Assert.isFalse(original.headers.containsKey('X-New'), 'Original headers should be unchanged');
	}

	/**
	 * @description Tests getInvocationCount returns zero for unknown service.
	 */
	@IsTest
	private static void shouldReturnZeroCountForUnknownService()
	{
		Assert.areEqual(0, API_MockFactory.getInvocationCount('API_Unknown'), 'Should return zero');
	}

	/**
	 * @description Tests getOutboundMock falls back to metadata when no memory mock and setting name provided.
	 */
	@IsTest
	private static void shouldFallBackToMetadataForOutboundMock()
	{
		API_MockFactory.MockResponse mock = API_MockFactory.getOutboundMock(TEST_SERVICE, 'NonExistent_Setting');

		Assert.isNull(mock, 'Should return null when no memory mock and no metadata match');
	}

	/**
	 * @description Tests getInboundMock falls back to metadata when no memory mock and setting name provided.
	 */
	@IsTest
	private static void shouldFallBackToMetadataForInboundMock()
	{
		API_MockFactory.MockResponse mock = API_MockFactory.getInboundMock(TEST_SERVICE, 'NonExistent_Setting', '{"data":"test"}');

		Assert.isNull(mock, 'Should return null when no memory mock and no metadata match');
	}

	/**
	 * @description Tests interpolation handles non-map nested value by preserving placeholder.
	 */
	@IsTest
	private static void shouldPreservePlaceholderForNonMapNestedPath()
	{
		String template = '{"result":"{{request.data.nested}}"}';

		String result = API_MockFactory.interpolateResponse(template, '{"data":"simple_string"}');

		Assert.isTrue(result.contains('{{request.data.nested}}'), 'Should preserve placeholder when nested path hits non-map value');
	}

	/**
	 * @description Tests buildMockResponse creates response from metadata record.
	 */
	@IsTest
	private static void shouldBuildMockResponseFromMetadataRecord()
	{
		ApiMock__mdt mock = new ApiMock__mdt(
				StatusCode__c = 201,
				ResponseBody__c = '{"created":true}',
				DelayMs__c = 50,
				FailureRate__c = 10
		);

		API_MockFactory.MockResponse response = API_MockFactory.buildMockResponse(mock);

		Assert.areEqual(API_Base.HTTP_CREATED, response.statusCode, 'Status code should match');
		Assert.areEqual('{"created":true}', response.body, 'Body should match');
		Assert.areEqual(API_MockFactory.MockSource.METADATA, response.source, 'Source should be METADATA');
		Assert.areEqual(50, response.delayMs, 'Delay should match');
		Assert.areEqual(10, response.failureRate, 'Failure rate should match');
	}

	/**
	 * @description Tests buildMockResponse parses response headers from JSON.
	 */
	@IsTest
	private static void shouldBuildMockResponseWithHeaders()
	{
		ApiMock__mdt mock = new ApiMock__mdt(
				StatusCode__c = 200,
				ResponseBody__c = '{}',
				ResponseHeaders__c = '{"Content-Type":"application/json","X-Custom":"value"}'
		);

		API_MockFactory.MockResponse response = API_MockFactory.buildMockResponse(mock);

		Assert.areEqual('application/json', response.headers.get('Content-Type'), 'Should parse Content-Type header');
		Assert.areEqual('value', response.headers.get('X-Custom'), 'Should parse custom header');
	}

	/**
	 * @description Tests buildMockResponse handles invalid headers JSON gracefully.
	 */
	@IsTest
	private static void shouldHandleInvalidHeadersJsonInBuildMockResponse()
	{
		ApiMock__mdt mock = new ApiMock__mdt(
				StatusCode__c = 200,
				ResponseBody__c = '{}',
				ResponseHeaders__c = 'not-valid-json'
		);

		API_MockFactory.MockResponse response = API_MockFactory.buildMockResponse(mock);

		Assert.isTrue(response.headers.isEmpty(), 'Should have empty headers for invalid JSON');
	}

	/**
	 * @description Tests buildMockResponse with null delay and failure rate uses defaults.
	 */
	@IsTest
	private static void shouldUseDefaultsWhenDelayAndFailureRateNull()
	{
		ApiMock__mdt mock = new ApiMock__mdt(
				StatusCode__c = 200,
				ResponseBody__c = '{}',
				DelayMs__c = null,
				FailureRate__c = null
		);

		API_MockFactory.MockResponse response = API_MockFactory.buildMockResponse(mock);

		Assert.areEqual(0, response.delayMs, 'Default delay should be 0');
		Assert.areEqual(0, response.failureRate, 'Default failure rate should be 0');
	}

	/**
	 * @description Tests getOutboundMock returns null when setting name is blank and no memory mock.
	 */
	@IsTest
	private static void shouldReturnNullWhenNoMockAndBlankSettingName()
	{
		API_MockFactory.MockResponse mock = API_MockFactory.getOutboundMock(TEST_SERVICE, '');

		Assert.isNull(mock, 'Should return null when no memory mock and blank setting name');
	}

	/**
	 * @description Tests getInboundMock returns null when setting name is blank and no memory mock.
	 */
	@IsTest
	private static void shouldReturnNullForInboundWhenBlankSettingName()
	{
		API_MockFactory.MockResponse mock = API_MockFactory.getInboundMock(TEST_SERVICE, '', '{"data":"test"}');

		Assert.isNull(mock, 'Should return null when no memory mock and blank setting name');
	}

	/**
	 * @description Tests metadata fallback path retrieves matching mock via TST_Mock.
	 */
	@IsTest
	private static void shouldRetrieveMatchingMockFromMetadata()
	{
		TST_Mock.register(ApiMock__mdt.SObjectType, new ApiMock__mdt(
				StatusCode__c = 201,
				ResponseBody__c = '{"mocked":true}',
				IsActive__c = true,
				Priority__c = 100
		));

		API_MockFactory.MockResponse mock = API_MockFactory.getOutboundMock(TEST_SERVICE, 'TestSetting', '{"id":"1"}');

		Assert.isNotNull(mock, 'Should retrieve mock from metadata');
		Assert.areEqual(API_Base.HTTP_CREATED, mock.statusCode, 'Status code should match metadata');
	}

	/**
	 * @description Tests registerMock from HttpResponse preserves headers.
	 */
	@IsTest
	private static void shouldRegisterMockFromHttpResponseWithHeaders()
	{
		HttpResponse httpResponse = new HttpResponse();
		httpResponse.setStatusCode(API_Base.HTTP_OK);
		httpResponse.setBody('{"ok":true}');
		httpResponse.setHeader('Content-Type', 'application/json');
		httpResponse.setHeader('X-Request-Id', 'abc-123');

		API_MockFactory.forService(TEST_SERVICE).fromResponse(httpResponse).register();

		API_MockFactory.MockResponse mock = API_MockFactory.getOutboundMock(TEST_SERVICE, null);

		Assert.areEqual('application/json', mock.headers.get('Content-Type'), 'Should preserve Content-Type');
		Assert.areEqual('abc-123', mock.headers.get('X-Request-Id'), 'Should preserve custom header');
	}

	/**
	 * @description Tests metadata returns null when all mocks have explicit patterns and none match.
	 */
	@IsTest
	private static void shouldReturnNullWhenMetadataPatternsDoNotMatch()
	{
		TST_Mock.register(ApiMock__mdt.SObjectType, new ApiMock__mdt(
				StatusCode__c = 202,
				ResponseBody__c = '{"fallback":true}',
				IsActive__c = true,
				Priority__c = 100,
				MatchRequestBodyPattern__c = 'WILL_NOT_MATCH',
				IsRegex__c = false
		));

		API_MockFactory.MockResponse mock = API_MockFactory.getOutboundMock(TEST_SERVICE, 'TestSetting', '{"id":"1"}');

		Assert.isNull(mock, 'Should return null when no metadata pattern matches');
	}

	/**
	 * @description Tests that CalloutMock returns a factory-registered mock response.
	 *
	 * @see API_MockFactory.CalloutMock
	 */
	@IsTest
	private static void calloutMockShouldReturnFactoryMock()
	{
		String expectedBody = '{"factory":true}';
		API_MockFactory.forService(TEST_SERVICE).body(expectedBody).statusCode(API_Base.HTTP_CREATED).register();

		API_MockFactory.CalloutMock calloutMock = new API_MockFactory.CalloutMock();
		calloutMock.apiClassName = TEST_SERVICE;

		Test.startTest();

		HttpResponse response = calloutMock.respond(new HttpRequest());

		Test.stopTest();

		Assert.areEqual(201, response.getStatusCode(), 'Status code should come from factory mock');
		Assert.areEqual(expectedBody, response.getBody(), 'Body should come from factory mock');
	}

	/**
	 * @description Tests that CalloutMock applies headers from a factory-registered mock.
	 *
	 * @see API_MockFactory.CalloutMock
	 */
	@IsTest
	private static void calloutMockShouldApplyFactoryHeaders()
	{
		API_MockFactory.forService(TEST_SERVICE)
				.body('{"ok":true}').statusCode(API_Base.HTTP_OK)
				.withHeader('X-Custom-Header', 'TestValue')
				.register();

		API_MockFactory.CalloutMock calloutMock = new API_MockFactory.CalloutMock();
		calloutMock.apiClassName = TEST_SERVICE;

		Test.startTest();

		HttpResponse response = calloutMock.respond(new HttpRequest());

		Test.stopTest();

		Assert.areEqual('TestValue', response.getHeader('X-Custom-Header'), 'Custom header should be applied');
	}

	/**
	 * @description Tests that CalloutMock falls back to defaultMockBody when no factory mock is registered.
	 *
	 * @see API_MockFactory.CalloutMock
	 */
	@IsTest
	private static void calloutMockShouldFallBackToDefaultMockBody()
	{
		String defaultBody = '{"default":true}';

		API_MockFactory.CalloutMock calloutMock = new API_MockFactory.CalloutMock();
		calloutMock.apiClassName = TEST_SERVICE;
		calloutMock.defaultMockBody = defaultBody;

		Test.startTest();

		HttpResponse response = calloutMock.respond(new HttpRequest());

		Test.stopTest();

		Assert.areEqual(API_Base.HTTP_OK, response.getStatusCode(), 'Should default to 200');
		Assert.areEqual(defaultBody, response.getBody(), 'Should use defaultMockBody');
	}

	/**
	 * @description Tests that CalloutMock throws ConfigurationException when no mock is available.
	 *
	 * @see API_MockFactory.CalloutMock
	 */
	@IsTest
	private static void calloutMockShouldThrowWhenNoMockConfigured()
	{
		API_MockFactory.CalloutMock calloutMock = new API_MockFactory.CalloutMock();
		calloutMock.apiClassName = TEST_SERVICE;

		try
		{
			Test.startTest();

			calloutMock.respond(new HttpRequest());

			Test.stopTest();

			Assert.fail('Should throw ConfigurationException');
		}
		catch(Exception error)
		{
			Assert.isInstanceOfType(error, UTIL_Exceptions.ConfigurationException.class, 'Incorrect Exception Type');
		}
	}

	/**
	 * @description Tests that CalloutMock passes settingDeveloperName for metadata lookup.
	 *
	 * @see API_MockFactory.CalloutMock
	 */
	@IsTest
	private static void calloutMockShouldPassSettingDeveloperName()
	{
		API_MockFactory.CalloutMock calloutMock = new API_MockFactory.CalloutMock();
		calloutMock.apiClassName = TEST_SERVICE;
		calloutMock.settingDeveloperName = 'NonExistent_Setting';
		calloutMock.defaultMockBody = '{"fallback":true}';

		Test.startTest();

		HttpResponse response = calloutMock.respond(new HttpRequest());

		Test.stopTest();

		Assert.areEqual(API_Base.HTTP_OK, response.getStatusCode(), 'Should fall back to defaultMockBody when no metadata mock found');
	}

	/**
	 * @description Tests that registerErrorMock registers a 500 error mock.
	 *
	 * @see API_MockFactory.registerErrorMock
	 */
	@IsTest
	private static void shouldRegisterErrorMock()
	{
		API_MockFactory.registerErrorMock(TEST_SERVICE);

		API_MockFactory.MockResponse mock = API_MockFactory.getOutboundMock(TEST_SERVICE, null);

		Assert.isNotNull(mock, 'Error mock should be registered');
		Assert.areEqual(API_Base.HTTP_INTERNAL_SERVER_ERROR, mock.statusCode, 'Status code should be 500');
		Assert.areEqual(API_Base.ERR_INTERNAL_SERVER, mock.body, 'Body should be error message');
		Assert.areEqual(API_Base.ERR_INTERNAL_SERVER, mock.status, 'Status should be error message');
	}

	/**
	 * @description Tests that registerParseFailMock registers a 200 OK mock with unparseable body.
	 *
	 * @see API_MockFactory.registerParseFailMock
	 */
	@IsTest
	private static void shouldRegisterParseFailMock()
	{
		API_MockFactory.registerParseFailMock(TEST_SERVICE);

		API_MockFactory.MockResponse mock = API_MockFactory.getOutboundMock(TEST_SERVICE, null);

		Assert.isNotNull(mock, 'Parse fail mock should be registered');
		Assert.areEqual(API_Base.HTTP_OK, mock.statusCode, 'Status code should be 200');
		Assert.areEqual(API_MockFactory.PARSE_FAIL_RESPONSE, mock.body, 'Body should be unparseable');
	}

	/**
	 * @description Tests that the status field is set via the builder and preserved in copy().
	 *
	 * @see API_MockFactory.MockBuilder.status
	 */
	@IsTest
	private static void shouldSetStatusViaBuilder()
	{
		API_MockFactory.forService(TEST_SERVICE)
				.body(TEST_BODY).statusCode(API_Base.HTTP_CREATED)
				.status('Created')
				.register();

		API_MockFactory.MockResponse mock = API_MockFactory.getOutboundMock(TEST_SERVICE, null);

		Assert.areEqual('Created', mock.status, 'Status text should match');
	}

	/**
	 * @description Tests that enableMocking enables mocking for a specific service.
	 */
	@IsTest
	private static void shouldEnableMockingForSpecificService()
	{
		API_MockFactory.enableMocking(TEST_SERVICE);

		Assert.isTrue(API_MockFactory.isMockingEnabled(TEST_SERVICE), 'Should be enabled for target service');
		Assert.isFalse(API_MockFactory.isMockingEnabled('API_OtherService'), 'Should not be enabled for other services');
	}

	/**
	 * @description Tests that wildcard enableMocking enables mocking for all services.
	 */
	@IsTest
	private static void shouldEnableMockingForAllViaWildcard()
	{
		API_MockFactory.enableMocking('*');

		Assert.isTrue(API_MockFactory.isMockingEnabled(TEST_SERVICE), 'Should be enabled for any service');
		Assert.isTrue(API_MockFactory.isMockingEnabled('API_AnotherService'), 'Should be enabled for another service');
	}

	/**
	 * @description Tests that clearMocks resets the mock enablement set.
	 */
	@IsTest
	private static void shouldClearMockEnabledOnClearMocks()
	{
		API_MockFactory.enableMocking(TEST_SERVICE);
		Assert.isTrue(API_MockFactory.isMockingEnabled(TEST_SERVICE), 'Should be enabled before clear');

		API_MockFactory.clearMocks();

		Assert.isFalse(API_MockFactory.isMockingEnabled(TEST_SERVICE), 'Should be disabled after clear');
	}

	/**
	 * @description Tests that isMockingEnabled returns false when nothing is enabled.
	 */
	@IsTest
	private static void shouldReturnFalseWhenNotEnabled()
	{
		Assert.isFalse(API_MockFactory.isMockingEnabled(TEST_SERVICE), 'Should be false by default');
	}

	/**
	 * @description Registers mock ApiMock__mdt records for selection tests.
	 */
	private static void registerMultipleMocks()
	{
		TST_Mock.clear(ApiMock__mdt.SObjectType);

		TST_Factory.newApiMock(new Map<SObjectField, Object>
		{
				ApiMock__mdt.Priority__c => 10,
				ApiMock__mdt.MatchRequestBodyPattern__c => 'urgent',
				ApiMock__mdt.StatusCode__c => 200,
				ApiMock__mdt.ResponseBody__c => '{"mock":"urgent","priority":10}'
		});

		TST_Factory.newApiMock(new Map<SObjectField, Object>
		{
				ApiMock__mdt.Priority__c => 50,
				ApiMock__mdt.MatchRequestBodyPattern__c => 'order-[0-9]+',
				ApiMock__mdt.IsRegex__c => true,
				ApiMock__mdt.StatusCode__c => 201,
				ApiMock__mdt.ResponseBody__c => '{"mock":"regex","priority":50}'
		});

		TST_Factory.newApiMock(new Map<SObjectField, Object>
		{
				ApiMock__mdt.Priority__c => 100,
				ApiMock__mdt.StatusCode__c => 202,
				ApiMock__mdt.ResponseBody__c => '{"mock":"default","priority":100}'
		});
	}

	/**
	 * @description Tests that the lowest-priority mock matching the request body is selected.
	 * Body contains "urgent" which matches Priority 10 — should beat the catch-all at 100.
	 */
	@IsTest
	private static void shouldSelectLowestPriorityMatchingMock()
	{
		registerMultipleMocks();

		API_MockFactory.MockResponse mock = API_MockFactory.getOutboundMock(TEST_SERVICE, 'TestSetting', '{"type":"urgent"}');

		Assert.isNotNull(mock, 'Should find matching mock');
		Assert.areEqual(200, mock.statusCode, 'Should select Priority 10 mock');
		Assert.isTrue(mock.body.contains('"urgent"'), 'Body should match Priority 10 mock');
	}

	/**
	 * @description Tests catch-all selection when no pattern matches the request body.
	 * Body "no-match" doesn't contain "urgent" or match "order-[0-9]+" — catch-all at 100 wins.
	 */
	@IsTest
	private static void shouldFallThroughToCatchAllMock()
	{
		registerMultipleMocks();

		API_MockFactory.MockResponse mock = API_MockFactory.getOutboundMock(TEST_SERVICE, 'TestSetting', '{"type":"no-match"}');

		Assert.isNotNull(mock, 'Should find catch-all mock');
		Assert.areEqual(202, mock.statusCode, 'Should select catch-all Priority 100 mock');
		Assert.isTrue(mock.body.contains('"default"'), 'Body should match catch-all mock');
	}

	/**
	 * @description Tests regex pattern matching in multi-mock selection.
	 * Body contains "order-12345" which matches "order-[0-9]+" at Priority 50.
	 */
	@IsTest
	private static void shouldSelectRegexMatchingMockByPriority()
	{
		registerMultipleMocks();

		API_MockFactory.MockResponse mock = API_MockFactory.getOutboundMock(TEST_SERVICE, 'TestSetting', '{"ref":"order-12345"}');

		Assert.isNotNull(mock, 'Should find regex mock');
		Assert.areEqual(201, mock.statusCode, 'Should select regex Priority 50 mock');
		Assert.isTrue(mock.body.contains('"regex"'), 'Body should match regex mock');
	}

	/**
	 * @description Tests that different request bodies route to different mocks from the same setting.
	 */
	@IsTest
	private static void shouldRouteDifferentBodiesToDifferentMocks()
	{
		registerMultipleMocks();

		API_MockFactory.MockResponse urgentMock = API_MockFactory.getOutboundMock(TEST_SERVICE, 'TestSetting', '{"type":"urgent"}');
		API_MockFactory.MockResponse regexMock = API_MockFactory.getOutboundMock(TEST_SERVICE, 'TestSetting', '{"ref":"order-99"}');
		API_MockFactory.MockResponse defaultMock = API_MockFactory.getOutboundMock(TEST_SERVICE, 'TestSetting', '{"type":"other"}');

		Assert.areEqual(200, urgentMock.statusCode, 'Urgent body should select Priority 10');
		Assert.areEqual(201, regexMock.statusCode, 'Order body should select Priority 50 regex');
		Assert.areEqual(202, defaultMock.statusCode, 'Unmatched body should select catch-all');
	}

	/**
	 * @description Tests that in-memory mock takes precedence over metadata mocks.
	 */
	@IsTest
	private static void shouldPreferMemoryMockOverMetadata()
	{
		registerMultipleMocks();

		API_MockFactory.forService(TEST_SERVICE).body('{"mock":"memory"}').statusCode(299).register();

		API_MockFactory.MockResponse mock = API_MockFactory.getOutboundMock(TEST_SERVICE, 'TestSetting', '{"type":"urgent"}');

		Assert.areEqual(299, mock.statusCode, 'In-memory mock should take precedence over metadata');
	}

}