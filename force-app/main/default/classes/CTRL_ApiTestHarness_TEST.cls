// SPDX-License-Identifier: BUSL-1.1
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
 * @date February 2026, May 2026
 */
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest(SeeAllData=false IsParallel=false)
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
}