// SPDX-License-Identifier: Apache-2.0
/**
 * @description Test class for CTRL_ApiTestHarness. Verifies service discovery,
 * outbound invocation, and inbound invocation through the controller.
 *
 * @see CTRL_ApiTestHarness
 *
 * @author Jason van Beukering
 *
 * @group Controllers
 *
 * @date February 2026, October 2026
 */
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest(seeAllData=false isParallel=false)
private class CTRL_ApiTestHarness_TEST
{
	/**
	 * @description The outbound service class name.
	 */
	private static final String OUTBOUND_SERVICE = API_PostExample.class.getName();
	/**
	 * @description The inbound service class name.
	 */
	private static final String INBOUND_SERVICE = API_Echo.class.getName();
	/**
	 * @description The outbound service class name that declares a required input.
	 */
	private static final String DECLARING_SERVICE = API_GetPwndPasswords.class.getName();
	/**
	 * @description A class name that resolves to no Apex class.
	 */
	private static final String UNKNOWN_SERVICE = 'API_DoesNotExist' + UTIL_Random.randomAlphanumeric(6);
	/**
	 * @description The required input name that API_GetPwndPasswords declares.
	 */
	private static final String PASSWORD_INPUT = 'password';
	/**
	 * @description The outbound service that sends a bearer token on every request: the inner test subclass below.
	 */
	private static final String BEARER_SERVICE = CTRL_ApiTestHarness_TEST.BearerOutbound.class.getName();
	/**
	 * @description The credential the bearer service sends; random so no fixed value can pass by coincidence.
	 */
	private static final String BEARER_TOKEN = UTIL_Random.randomAlphanumeric(32);
	/**
	 * @description The session cookie the mocked endpoint sets on its response.
	 */
	private static final String RESPONSE_COOKIE = 'sid=' + UTIL_Random.randomAlphanumeric(16);
	/**
	 * @description The response header that carries a cookie.
	 */
	private static final String HEADER_SET_COOKIE = 'Set-Cookie';
	/**
	 * @description The JSON content type the mocked endpoint answers with.
	 */
	private static final String CONTENT_TYPE_JSON = 'application/json';
	/**
	 * @description The key DTO_NameValues serialises its map under.
	 */
	private static final String NAME_VALUE_MAP_KEY = 'nameValueMap';
	/**
	 * @description The shipped example named credential, so the bearer service resolves to a real endpoint host.
	 */
	private static final String EXAMPLE_CREDENTIAL = 'API_ExampleRestApi';
	/**
	 * @description The endpoint path the bearer service calls on that credential.
	 */
	private static final String EXAMPLE_PATH = '/posts';
	/**
	 * @description The body every mocked bearer-service response carries.
	 */
	private static final String MOCK_BODY = '{"id": 101}';

	/**
	 * @description Builds a JSON-serialized outbound request for the controller.
	 *
	 * @param serviceName The API handler class name
	 * @param recordId The triggering record Id
	 * @param parameters Optional parameter list
	 * @param enableSafeMode Safe Mode flag
	 * @param enableMocking Mocking flag
	 *
	 * @return JSON payload matching CTRL_ApiTestHarness.DTO_Request
	 */
	@SuppressWarnings('PMD.ExcessiveParameterList')
	private static String buildOutboundRequest(String serviceName, Id recordId, List<DTO_NameValue> parameters, Boolean enableSafeMode, Boolean enableMocking)
	{
		CTRL_ApiTestHarness.DTO_Request request = new CTRL_ApiTestHarness.DTO_Request();
		request.serviceName = serviceName;
		request.recordId = recordId;
		request.parameters = parameters;
		request.enableSafeMode = enableSafeMode;
		request.enableMocking = enableMocking;
		return JSON.serialize(request);
	}

	/**
	 * @description Builds a JSON-serialized inbound request for the controller.
	 *
	 * @param serviceName The API handler class name
	 * @param jsonBody The inbound request body
	 * @param enableSafeMode Safe Mode flag
	 * @param enableMocking Mocking flag
	 *
	 * @return JSON payload matching CTRL_ApiTestHarness.DTO_Request
	 */
	private static String buildInboundRequest(String serviceName, String jsonBody, Boolean enableSafeMode, Boolean enableMocking)
	{
		CTRL_ApiTestHarness.DTO_Request request = new CTRL_ApiTestHarness.DTO_Request();
		request.serviceName = serviceName;
		request.jsonBody = jsonBody;
		request.enableSafeMode = enableSafeMode;
		request.enableMocking = enableMocking;
		return JSON.serialize(request);
	}

	/**
	 * @description Tests that getServices returns active outbound services with class name as value.
	 */
	@IsTest
	private static void shouldReturnActiveOutboundServicesAsComboboxOptions()
	{
		TST_Factory.newOutboundApiSetting(OUTBOUND_SERVICE, new Map<SObjectField, Object>
		{
				ApiSetting__mdt.MasterLabel => 'Post Example'
		});

		List<CTRL_ApiTestHarness.DTO_ServiceOption> options =
				CTRL_ApiTestHarness.getServices(SEL_ApiSetting.DIRECTION_OUTBOUND);

		Assert.isFalse(options.isEmpty(), 'Should return outbound services');
		Assert.areEqual(OUTBOUND_SERVICE, options.iterator().next().value, 'Value should be class name');
	}

	/**
	 * @description Tests that getServices returns active inbound services with class name as value.
	 */
	@IsTest
	private static void shouldReturnActiveInboundServicesAsComboboxOptions()
	{
		TST_Mock.of(ApiSetting__mdt.SObjectType)
				.withOverride(ApiSetting__mdt.ClassName__c, INBOUND_SERVICE)
				.withOverride(ApiSetting__mdt.Direction__c, SEL_ApiSetting.DIRECTION_INBOUND)
				.withOverride(ApiSetting__mdt.IsActive__c, true)
				.withOverride(ApiSetting__mdt.MasterLabel, 'Echo')
				.build();

		List<CTRL_ApiTestHarness.DTO_ServiceOption> options =
				CTRL_ApiTestHarness.getServices(SEL_ApiSetting.DIRECTION_INBOUND);

		Assert.isFalse(options.isEmpty(), 'Should return inbound services');
		Assert.areEqual(INBOUND_SERVICE, options.iterator().next().value, 'Value should be class name');
	}

	/**
	 * @description Tests that outbound invocation returns success with Safe Mode enabled.
	 */
	@IsTest
	private static void shouldReturnSuccessForOutboundInvocationWithSafeMode()
	{
		String requestJson = buildOutboundRequest(OUTBOUND_SERVICE, UserInfo.getUserId(), null, true, false);

		Test.startTest();

		CTRL_ApiTestHarness.DTO_TestResult testResult = CTRL_ApiTestHarness.invokeOutbound(requestJson);

		Test.stopTest();

		Assert.isTrue(testResult.isSuccess, 'Outbound invocation should succeed');
		Assert.isTrue(testResult.safeModeEnabled, 'Safe Mode should be enabled');
	}

	/**
	 * @description Tests that outbound invocation returns a mocked response when mocking is enabled.
	 */
	@IsTest
	private static void shouldReturnMockedResponseForOutboundInvocation()
	{
		String requestJson = buildOutboundRequest(OUTBOUND_SERVICE, UserInfo.getUserId(), null, false, true);

		Test.startTest();

		CTRL_ApiTestHarness.DTO_TestResult testResult = CTRL_ApiTestHarness.invokeOutbound(requestJson);

		Test.stopTest();

		Assert.isTrue(testResult.isMockedResponse, 'Response should be mocked');
		Assert.isTrue(testResult.mockingEnabled, 'Mocking should be enabled');
	}

	/**
	 * @description Tests that inbound invocation returns success with Safe Mode enabled.
	 */
	@IsTest
	private static void shouldReturnSuccessForInboundInvocationWithSafeMode()
	{
		TST_Factory.newInboundApiSetting(INBOUND_SERVICE, '/echo/*');
		String requestJson = buildInboundRequest(INBOUND_SERVICE, '{"hello":"world"}', true, false);

		Test.startTest();

		CTRL_ApiTestHarness.DTO_TestResult testResult = CTRL_ApiTestHarness.invokeInbound(requestJson);

		Test.stopTest();

		Assert.isTrue(testResult.isSuccess, 'Inbound invocation should succeed');
		Assert.isTrue(testResult.safeModeEnabled, 'Safe Mode should be enabled');
	}

	/**
	 * @description Tests that inbound invocation returns a mocked response when mocking is enabled.
	 */
	@IsTest
	private static void shouldReturnMockedResponseForInboundInvocation()
	{
		TST_Factory.newInboundApiSetting(INBOUND_SERVICE, '/echo/*');
		String requestJson = buildInboundRequest(INBOUND_SERVICE, '{"hello":"world"}', false, true);

		Test.startTest();

		CTRL_ApiTestHarness.DTO_TestResult testResult = CTRL_ApiTestHarness.invokeInbound(requestJson);

		Test.stopTest();

		Assert.isTrue(testResult.isMockedResponse, 'Response should be mocked');
		Assert.isTrue(testResult.mockingEnabled, 'Mocking should be enabled');
	}

	/**
	 * @description Tests that timing duration fields are mapped from the invocation result to the test result DTO.
	 */
	@IsTest
	private static void shouldMapTimingDurationFieldsToTestResult()
	{
		String requestJson = buildOutboundRequest(OUTBOUND_SERVICE, UserInfo.getUserId(), null, false, false);

		Test.startTest();

		CTRL_ApiTestHarness.DTO_TestResult testResult = CTRL_ApiTestHarness.invokeOutbound(requestJson);

		Test.stopTest();

		Assert.isTrue(testResult.isSuccess, 'Outbound invocation should succeed');
		Assert.isNotNull(testResult.handlerDurationMs, 'Handler duration should be mapped');
		Assert.isNotNull(testResult.calloutDurationMs, 'Callout duration should be mapped');
		Assert.isNotNull(testResult.commitDurationMs, 'Commit duration should be mapped');
	}

	/**
	 * @description Tests that outbound headers are serialized to JSON strings in the test result DTO.
	 */
	@IsTest
	private static void shouldSerializeOutboundHeadersToTestResult()
	{
		String requestJson = buildOutboundRequest(OUTBOUND_SERVICE, UserInfo.getUserId(), null, false, false);

		Test.startTest();

		CTRL_ApiTestHarness.DTO_TestResult testResult = CTRL_ApiTestHarness.invokeOutbound(requestJson);

		Test.stopTest();

		Assert.isTrue(testResult.isSuccess, 'Outbound invocation should succeed');
		Assert.isNotNull(testResult.requestHeaders, 'Request headers should be mapped');
		Assert.isNotNull(testResult.responseHeaders, 'Response headers should be mapped');
	}

	/**
	 * @description Tests that the harness never hands the page the bearer token a service sends: the Authorization
	 * value in the serialised request headers is the redaction marker, the token appears nowhere in that payload, and
	 * a non-credential header is still reported as sent.
	 */
	@IsTest
	private static void shouldRedactTheAuthorizationHeaderInTheOutboundResult()
	{
		registerBearerService();
		String requestJson = buildOutboundRequest(BEARER_SERVICE, UserInfo.getUserId(), null, true, true);

		Test.startTest();
		CTRL_ApiTestHarness.DTO_TestResult testResult = CTRL_ApiTestHarness.invokeOutbound(requestJson);
		Test.stopTest();

		Map<String, Object> requestHeaders = headersOf(testResult.requestHeaders);
		Assert.areEqual(API_Base.REDACTED_HEADER_VALUE, requestHeaders.get(API_Base.HTTP_HEADER_AUTHORIZATION), 'The Authorization value must be the redaction marker');
		Assert.isFalse(testResult.requestHeaders.contains(BEARER_TOKEN), 'The bearer token must not appear anywhere in the serialised request headers');
		Assert.isNotNull(requestHeaders.get(API_Base.HTTP_CONTENT_TYPE), 'A non-credential header is still reported');
		Assert.areNotEqual(API_Base.REDACTED_HEADER_VALUE, requestHeaders.get(API_Base.HTTP_CONTENT_TYPE), 'A non-credential header is reported as sent, not redacted');
	}

	/**
	 * @description Tests that a cookie the endpoint sets is redacted in the serialised response headers while the
	 * response content type is reported as received.
	 */
	@IsTest
	private static void shouldRedactTheSetCookieHeaderInTheOutboundResponse()
	{
		registerBearerService();
		API_MockFactory.forService(BEARER_SERVICE)
				.body(MOCK_BODY).statusCode(API_Base.HTTP_OK).status('OK')
				.withHeader(HEADER_SET_COOKIE, RESPONSE_COOKIE)
				.withHeader(API_Base.HTTP_CONTENT_TYPE, CONTENT_TYPE_JSON)
				.register();
		String requestJson = buildOutboundRequest(BEARER_SERVICE, UserInfo.getUserId(), null, true, true);

		Test.startTest();
		CTRL_ApiTestHarness.DTO_TestResult testResult = CTRL_ApiTestHarness.invokeOutbound(requestJson);
		Test.stopTest();

		Assert.isNotNull(testResult.responseHeaders, 'Precondition: the mocked response headers reach the result');
		Map<String, Object> responseHeaders = headersOf(testResult.responseHeaders);
		Assert.areEqual(API_Base.REDACTED_HEADER_VALUE, responseHeaders.get(HEADER_SET_COOKIE), 'The Set-Cookie value must be the redaction marker');
		Assert.isFalse(testResult.responseHeaders.contains(RESPONSE_COOKIE), 'The cookie must not appear anywhere in the serialised response headers');
		Assert.areEqual(CONTENT_TYPE_JSON, responseHeaders.get(API_Base.HTTP_CONTENT_TYPE), 'A non-credential response header is reported as received');
	}

	/**
	 * @description Tests that the redaction is a disclosure control, not a masking policy: with the masking framework
	 * switched off, the Authorization value is still the redaction marker.
	 */
	@IsTest
	private static void shouldRedactHeadersWithTheMaskingFrameworkSwitchedOff()
	{
		SEL_FeatureFlag.activeFlags.remove(UTIL_FrameworkMasker.FLAG_MASKING_FRAMEWORK_ENABLED);
		registerBearerService();
		String requestJson = buildOutboundRequest(BEARER_SERVICE, UserInfo.getUserId(), null, true, true);

		Test.startTest();
		CTRL_ApiTestHarness.DTO_TestResult testResult = CTRL_ApiTestHarness.invokeOutbound(requestJson);
		Test.stopTest();

		Assert.isFalse(UTIL_FrameworkMasker.isMaskingEnabled, 'Precondition: the masking framework is off');
		Assert.areEqual(API_Base.REDACTED_HEADER_VALUE, headersOf(testResult.requestHeaders).get(API_Base.HTTP_HEADER_AUTHORIZATION),
				'The Authorization value must be redacted with masking off');
		Assert.isFalse(testResult.requestHeaders.contains(BEARER_TOKEN), 'The bearer token must not appear with masking off');
	}

	/**
	 * @description Tests that inbound request headers are surfaced as DTO_NameValues in the invocation result.
	 * Uses direct invoke path with custom headers since invokeByServiceName does not pass headers.
	 */
	@IsTest
	private static void shouldSurfaceInboundRequestHeadersInResult()
	{
		TST_Factory.newInboundApiSetting(INBOUND_SERVICE, '/echo/*');

		Map<String, String> headers = new Map<String, String> {'X-Test' => 'value'};

		Test.startTest();

		DTO_InvocationResult invocationResult =
				API_InboundInvoker.invoke('/echo/test', 'POST', '{"hello":"world"}', headers, false);

		Test.stopTest();

		Assert.isFalse(invocationResult.requestHeaders.isEmpty(), 'Request headers should be mapped');
		Assert.isTrue(invocationResult.requestHeaders.exists('X-Test'), 'Should contain custom header');
	}

	/**
	 * @description Tests that getServices returns an empty list when no active services exist for the direction.
	 */
	@IsTest
	private static void shouldReturnEmptyOptionsWhenNoActiveServicesExist()
	{
		QRY_Builder.setMock(ApiSetting__mdt.SObjectType, new List<ApiSetting__mdt>());

		List<CTRL_ApiTestHarness.DTO_ServiceOption> options =
				CTRL_ApiTestHarness.getServices(SEL_ApiSetting.DIRECTION_OUTBOUND);

		Assert.isTrue(options.isEmpty(), 'Should return empty list when no services match');
	}

	/**
	 * @description Tests that outbound invocation reports failure for a non-existent service class.
	 */
	@IsTest
	private static void shouldReportFailureForNonExistentOutboundService()
	{
		String requestJson = buildOutboundRequest('API_NonExistent', UserInfo.getUserId(), null, true, false);

		Test.startTest();

		CTRL_ApiTestHarness.DTO_TestResult testResult = CTRL_ApiTestHarness.invokeOutbound(requestJson);

		Test.stopTest();

		Assert.isFalse(testResult.isSuccess, 'Should not succeed with invalid service name');
	}

	/**
	 * @description Tests that inbound invocation reports failure with error details for a non-existent service class.
	 */
	@IsTest
	private static void shouldReportFailureForNonExistentInboundService()
	{
		String requestJson = buildInboundRequest('API_NonExistent', '{"hello":"world"}', true, false);

		CTRL_ApiTestHarness.DTO_TestResult testResult = CTRL_ApiTestHarness.invokeInbound(requestJson);

		Assert.isFalse(testResult.isSuccess, 'Should not succeed with invalid service name');
		Assert.isNotNull(testResult.errorMessages, 'Should contain error details');
	}

	/**
	 * @description Tests that parameter values containing commas and equals signs are preserved intact.
	 * This is the key benefit of passing parameters as a structured List&lt;DTO_NameValue&gt; inside
	 * the request DTO — the previous comma-delimited string signature corrupted values containing those characters.
	 */
	@IsTest
	private static void shouldPreserveValuesContainingCommasAndEqualsSigns()
	{
		List<DTO_NameValue> parameters = new List<DTO_NameValue>
		{
				new DTO_NameValue('csvField', 'apple, banana, cherry'),
				new DTO_NameValue('formula', 'x = (a + b) / c')
		};
		String requestJson = buildOutboundRequest(OUTBOUND_SERVICE, UserInfo.getUserId(), parameters, true, false);

		Test.startTest();

		CTRL_ApiTestHarness.DTO_TestResult testResult = CTRL_ApiTestHarness.invokeOutbound(requestJson);

		Test.stopTest();

		Assert.isNotNull(testResult, 'Should return a result when parameters contain commas and equals signs');
	}

	/**
	 * @description Tests that parameter entries with blank names are filtered out by the controller.
	 */
	@IsTest
	private static void shouldFilterEntriesWithBlankNames()
	{
		List<DTO_NameValue> parameters = new List<DTO_NameValue>
		{
				new DTO_NameValue('', 'orphan'),
				new DTO_NameValue('valid', 'kept')
		};
		String requestJson = buildOutboundRequest(OUTBOUND_SERVICE, UserInfo.getUserId(), parameters, true, false);

		Test.startTest();

		CTRL_ApiTestHarness.DTO_TestResult testResult = CTRL_ApiTestHarness.invokeOutbound(requestJson);

		Test.stopTest();

		Assert.isNotNull(testResult, 'Should return a result even when a parameter entry has a blank name');
	}

	/**
	 * @description Tests that a null requestJson argument returns an empty DTO_Request and still invokes cleanly.
	 */
	@IsTest
	private static void shouldTolerateNullRequestJson()
	{
		Test.startTest();

		CTRL_ApiTestHarness.DTO_TestResult testResult = CTRL_ApiTestHarness.invokeOutbound(null);

		Test.stopTest();

		Assert.isNotNull(testResult, 'Should return a result when requestJson is null');
	}

	/**
	 * @description Tests that describeService reports the required inputs and the record requirement a service declares.
	 */
	@IsTest
	private static void describeServiceReturnsTheDeclaredInputsAndRecordRequirement()
	{
		LOG_Engine.pushOperationContext(LOG_Engine.OperationType.LWC, new Map<String, String> {LOG_Engine.CONTEXT_SERVICE_NAME => DECLARING_SERVICE});

		try
		{
			CTRL_ApiTestHarness.DTO_ServiceDescription description = CTRL_ApiTestHarness.describeService(DECLARING_SERVICE);

			Assert.areEqual(1, LOG_Engine.getContextStackDepth(), 'Describing a service leaves the caller\'s context on the stack.');
			Assert.areEqual(1, description.inputs.size(), 'API_GetPwndPasswords declares exactly one input.');
			Assert.areEqual(PASSWORD_INPUT, description.inputs[0].name, 'API_GetPwndPasswords declares password.');
			Assert.isTrue(description.inputs[0].isRequired, 'A declared input is required.');
			Assert.isFalse(description.requiresTriggeringRecord, 'API_GetPwndPasswords sets requiresTriggeringRecord = false.');
			Assert.isTrue(LOG_Engine.webserviceContextsByCorrelation.isEmpty(), 'describeService clears the webservice context it registered.');
		}
		finally
		{
			LOG_Engine.popOperationContext();
		}
	}

	/**
	 * @description Tests that describeService falls back to the API_Outbound defaults when a service declares nothing.
	 */
	@IsTest
	private static void describeServiceReportsTheBaseDefaultsForAnUndeclaringService()
	{
		CTRL_ApiTestHarness.DTO_ServiceDescription description = CTRL_ApiTestHarness.describeService(OUTBOUND_SERVICE);

		Assert.isTrue(description.inputs.isEmpty(), 'API_PostExample declares no required inputs.');
		Assert.isTrue(description.requiresTriggeringRecord, 'The base default requires a triggering record.');
		Assert.areEqual(0, LOG_Engine.getContextStackDepth(), 'Describing a service leaves the context stack as it found it.');
		Assert.isTrue(LOG_Engine.webserviceContextsByCorrelation.isEmpty(), 'describeService clears the webservice context it registered.');
	}

	/**
	 * @description Tests that describeService answers a blank, unknown or non-outbound class name with an empty
	 * description instead of raising an error at the client.
	 */
	@IsTest
	private static void describeServiceReturnsAnEmptyDescriptionInsteadOfThrowing()
	{
		for(String className : new List<String> {null, '', UNKNOWN_SERVICE, INBOUND_SERVICE})
		{
			CTRL_ApiTestHarness.DTO_ServiceDescription description = CTRL_ApiTestHarness.describeService(className);

			Assert.isTrue(description.inputs.isEmpty(), 'Empty description expected for: ' + className);
			Assert.isFalse(description.requiresTriggeringRecord, 'No record requirement expected for: ' + className);
		}
	}

	/**
	 * @description Registers the bearer service as an active outbound setting on the shipped example credential.
	 */
	private static void registerBearerService()
	{
		TST_Factory.newOutboundApiSetting(BEARER_SERVICE, new Map<SObjectField, Object>
		{
				ApiSetting__mdt.ApiCredential__c => EXAMPLE_CREDENTIAL,
				ApiSetting__mdt.EndpointPath__c => EXAMPLE_PATH
		});
	}

	/**
	 * @description Reads the header map out of the harness's serialised header JSON ({"nameValueMap": {...}}).
	 *
	 * @param serialisedHeaders The DTO_TestResult header string
	 *
	 * @return The name-to-value map the page renders
	 */
	private static Map<String, Object> headersOf(String serialisedHeaders)
	{
		Map<String, Object> envelope = (Map<String, Object>)JSON.deserializeUntyped(serialisedHeaders);
		return (Map<String, Object>)envelope.get(NAME_VALUE_MAP_KEY);
	}

	/**
	 * @description An outbound service that sends a bearer token, so the harness has a real Authorization header to
	 * redact. Mirrors API_PostExample's configuration (that class is not virtual, so it cannot be extended).
	 */
	public inherited sharing class BearerOutbound extends API_Outbound
	{
		/**
		 * @description Mirrors API_PostExample's configuration: the example request and response payloads plus the harness mock body,
		 * so the service runs end to end without a live endpoint.
		 */
		public override void configure()
		{
			super.configure();
			requestPayload = new API_PostExample.DTO_Request();
			responsePayload = new API_PostExample.DTO_Response();
			defaultMockBody = MOCK_BODY;
		}

		/**
		 * @description Supplies the bearer token the harness must redact.
		 *
		 * @return The Bearer scheme followed by BEARER_TOKEN.
		 */
		public override String getAuthorisationToken()
		{
			return API_Base.HTTP_AUTH_TOKEN_BEARER + BEARER_TOKEN;
		}
	}
}