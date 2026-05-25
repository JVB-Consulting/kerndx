// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Test class for API_InboundInvoker. Verifies invocation of inbound API
 * requests with and without Safe Mode, replay from failure records, and error handling.
 *
 * @see API_InboundInvoker
 *
 * @author Jason van Beukering
 *
 * @group Web Services
 *
 * @date February 2026, May 2026
 */
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest(SeeAllData=false IsParallel=true)
private class API_InboundInvoker_TEST
{
	/**
	 * @description The service class name used for routing.
	 */
	private static final String SERVICE_NAME = API_Echo.class.getName();
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
	 * @description Tests that invocation populates status code, response body, request body, and execution time.
	 */
	@IsTest
	private static void shouldPopulateResultFieldsOnSuccessfulInvocation()
	{
		TST_Factory.newInboundApiSetting(SERVICE_NAME, '/echo/*');

		Test.startTest();

		DTO_InvocationResult invocationResult =
				API_InboundInvoker.invoke(TEST_PATH, HTTP_POST, TEST_BODY, false);

		Test.stopTest();

		Assert.isTrue(invocationResult.success, 'Invocation should succeed');
		Assert.areEqual(API_Base.HTTP_OK, invocationResult.statusCode, 'Should return 200');
		Assert.isFalse(invocationResult.safeModeEnabled, 'Safe mode should be off');
		Assert.isNotNull(invocationResult.responseBody, 'Response body should be set');
		Assert.areEqual(TEST_BODY, invocationResult.requestBody, 'Request body should be preserved');
		Assert.isNotNull(invocationResult.executionTimeMs, 'Execution time should be tracked');
	}

	/**
	 * @description Tests that Safe Mode invocation captures service name, status, and HTTP method from the handler.
	 */
	@IsTest
	private static void shouldCaptureHandlerMetadataWithSafeModeEnabled()
	{
		TST_Factory.newInboundApiSetting(SERVICE_NAME, '/echo/*');

		Test.startTest();

		DTO_InvocationResult invocationResult =
				API_InboundInvoker.invoke(TEST_PATH, HTTP_POST, TEST_BODY, true);

		Test.stopTest();

		Assert.isTrue(invocationResult.safeModeEnabled, 'Safe mode should be enabled');
		Assert.isNotNull(invocationResult.serviceName, 'Service name should be captured');
		Assert.isNotNull(invocationResult.status, 'Status should be captured');
		Assert.isNotNull(invocationResult.httpMethod, 'HTTP method should be captured');
	}

	/**
	 * @description Tests that the three-parameter overload enables Safe Mode by default.
	 */
	@IsTest
	private static void shouldDefaultToSafeModeForThreeParameterOverload()
	{
		TST_Factory.newInboundApiSetting(SERVICE_NAME, '/echo/*');

		Test.startTest();

		DTO_InvocationResult invocationResult =
				API_InboundInvoker.invoke(TEST_PATH, HTTP_POST, TEST_BODY);

		Test.stopTest();

		Assert.isTrue(invocationResult.safeModeEnabled, 'Should default to safe mode enabled');
	}

	/**
	 * @description Tests that an unmatched request path produces a 404 Not Found response.
	 */
	@IsTest
	private static void shouldReturnNotFoundForUnmatchedPath()
	{
		DTO_InvocationResult invocationResult =
				API_InboundInvoker.invoke('/nonexistent/path', 'GET', null, false);

		Assert.areEqual(API_Base.HTTP_NOT_FOUND, invocationResult.statusCode, 'Should return 404');
		Assert.isFalse(invocationResult.success, 'Should not be successful');
	}

	/**
	 * @description Creates a pre-configured inbound failure record for replay testing.
	 *
	 * @return The inserted ApiIssue__c record
	 */
	private static ApiIssue__c createInboundFailure()
	{
		return (ApiIssue__c)TST_Builder.of(ApiIssue__c.SObjectType)
				.withOverride(ApiIssue__c.RequestPath__c, TEST_PATH)
				.withOverride(ApiIssue__c.RequestMethod__c, HTTP_POST)
				.withOverride(ApiIssue__c.RequestBody__c, TEST_BODY)
				.withOverride(ApiIssue__c.Direction__c, SEL_ApiIssue.DIRECTION_INBOUND)
				.build();
	}

	/**
	 * @description Tests that replay re-executes the request from the stored failure record.
	 */
	@IsTest
	private static void shouldReplayRequestFromFailureRecord()
	{
		TST_Factory.newInboundApiSetting(SERVICE_NAME, '/echo/*');
		ApiIssue__c failure = createInboundFailure();

		Test.startTest();

		DTO_InvocationResult invocationResult =
				API_InboundInvoker.replay(failure.Id, false);

		Test.stopTest();

		Assert.isTrue(invocationResult.success, 'Replay should succeed');
		Assert.areEqual(TEST_BODY, invocationResult.requestBody, 'Should use body from failure record');
	}

	/**
	 * @description Tests that replay returns Not Found when the failure record does not exist.
	 */
	@IsTest
	private static void shouldReturnNotFoundWhenFailureRecordMissing()
	{
		Id fakeId = UTIL_Random.randomId(ApiIssue__c.SObjectType);

		DTO_InvocationResult invocationResult =
				API_InboundInvoker.replay(fakeId, false);

		Assert.areEqual(API_Base.HTTP_NOT_FOUND, invocationResult.statusCode, 'Should return 404');
		Assert.isFalse(invocationResult.errors.isEmpty(), 'Should contain error message');
	}

	/**
	 * @description Tests that the single-parameter replay overload enables Safe Mode by default.
	 */
	@IsTest
	private static void shouldDefaultToSafeModeForSingleParameterReplay()
	{
		TST_Factory.newInboundApiSetting(SERVICE_NAME, '/echo/*');
		ApiIssue__c failure = createInboundFailure();

		Test.startTest();

		DTO_InvocationResult invocationResult =
				API_InboundInvoker.replay(failure.Id);

		Test.stopTest();

		Assert.isTrue(invocationResult.safeModeEnabled, 'Should default to safe mode enabled');
	}

	/**
	 * @description Tests that platform-level exceptions produce a 500 status with error details.
	 */
	@IsTest
	private static void shouldReturnInternalServerErrorOnException()
	{
		API_InboundInvoker.forceException = true;

		DTO_InvocationResult invocationResult =
				API_InboundInvoker.invoke(TEST_PATH, HTTP_POST, TEST_BODY, false);

		Assert.areEqual(API_Base.HTTP_INTERNAL_SERVER_ERROR, invocationResult.statusCode, 'Should return 500');
		Assert.isFalse(invocationResult.errors.isEmpty(), 'Should contain error details');
		Assert.isFalse(invocationResult.success, 'Should not be successful');
	}

	/**
	 * @description Tests that Safe Mode context is released even when an exception occurs.
	 */
	@IsTest
	private static void shouldCloseSafeModeContextOnException()
	{
		API_InboundInvoker.forceException = true;

		DTO_InvocationResult invocationResult =
				API_InboundInvoker.invoke(TEST_PATH, HTTP_POST, TEST_BODY, true);

		Assert.areEqual(API_Base.HTTP_INTERNAL_SERVER_ERROR, invocationResult.statusCode, 'Should return 500');
		Assert.isTrue(invocationResult.safeModeEnabled, 'Safe mode should have been enabled');
		Assert.isFalse(API_Base.isSafeModeActive(), 'Safe mode should be closed after exception');
	}

	/**
	 * @description Tests that invokeByServiceName resolves the endpoint path from ApiSetting metadata.
	 */
	@IsTest
	private static void shouldResolveEndpointPathFromApiSettingMetadata()
	{
		TST_Factory.newInboundApiSetting(SERVICE_NAME, '/echo/*');

		Test.startTest();

		DTO_InvocationResult invocationResult =
				API_InboundInvoker.invokeByServiceName(SERVICE_NAME, TEST_BODY, false, false);

		Test.stopTest();

		Assert.isTrue(invocationResult.success, 'Should succeed when resolving by service name');
		Assert.areEqual(API_Base.HTTP_OK, invocationResult.statusCode, 'Should return 200');
		Assert.isFalse(invocationResult.mockingEnabled, 'Mocking should be disabled');
	}

	/**
	 * @description Tests that invokeByServiceName produces a mocked response when mocking is enabled.
	 */
	@IsTest
	private static void shouldReturnMockedResponseWhenMockingEnabledByServiceName()
	{
		TST_Factory.newInboundApiSetting(SERVICE_NAME, '/echo/*');

		Test.startTest();

		DTO_InvocationResult invocationResult =
				API_InboundInvoker.invokeByServiceName(SERVICE_NAME, TEST_BODY, false, true);

		Test.stopTest();

		Assert.isTrue(invocationResult.success, 'Should succeed');
		Assert.isTrue(invocationResult.mockingEnabled, 'Mocking should be enabled');
		Assert.isTrue(invocationResult.isMockedResponse, 'Response should be mocked');
	}

	/**
	 * @description Tests that invokeByServiceName returns Not Found when no ApiSetting metadata exists.
	 */
	@IsTest
	private static void shouldReturnNotFoundWhenApiSettingMissing()
	{
		DTO_InvocationResult invocationResult =
				API_InboundInvoker.invokeByServiceName('API_NonExistent', TEST_BODY, false, false);

		Assert.areEqual(API_Base.HTTP_NOT_FOUND, invocationResult.statusCode, 'Should return 404');
		Assert.isFalse(invocationResult.errors.isEmpty(), 'Should contain error message');
	}

	/**
	 * @description Tests that custom request headers are surfaced in the invocation result.
	 */
	@IsTest
	private static void shouldSurfaceCustomRequestHeaders()
	{
		TST_Factory.newInboundApiSetting(SERVICE_NAME, '/echo/*');

		Map<String, String> headers = new Map<String, String>
		{
				'X-Test-Header' => 'test-value'
		};

		Test.startTest();

		DTO_InvocationResult invocationResult =
				API_InboundInvoker.invoke(TEST_PATH, HTTP_POST, TEST_BODY, headers, false);

		Test.stopTest();

		Assert.isTrue(invocationResult.success, 'Invocation should succeed');
		Assert.isFalse(invocationResult.requestHeaders.isEmpty(), 'Request headers should be captured');
		Assert.isTrue(invocationResult.requestHeaders.exists('X-Test-Header'), 'Should contain custom header');
	}

	/**
	 * @description Tests that the Idempotency-Key header propagates to the ApiCall record.
	 */
	@IsTest
	private static void shouldPropagateIdempotencyKeyHeaderToApiCallRecord()
	{
		TST_Factory.newInboundApiSetting(SERVICE_NAME, '/echo/*');

		Map<String, String> headers = new Map<String, String>
		{
				'Idempotency-Key' => 'test-key-12345',
				'X-Custom-Header' => 'custom-value'
		};

		Test.startTest();

		DTO_InvocationResult invocationResult =
				API_InboundInvoker.invoke(TEST_PATH, HTTP_POST, TEST_BODY, headers, false);

		Test.stopTest();

		Assert.isTrue(invocationResult.success, 'Invocation should succeed');
		Assert.areEqual(TEST_BODY, invocationResult.requestBody, 'Request body should match');

		ApiCall__c apiCallRecord = new SEL_ApiCall().findByIdempotencyKey('test-key-12345');
		Assert.isNotNull(apiCallRecord, 'Idempotency-Key header should be captured on API call record');
		Assert.areEqual('test-key-12345', apiCallRecord.IdempotencyKey__c, 'Idempotency-Key header value should be applied to request');
	}

	/**
	 * @description Tests that toConcreteEndpointPath returns a default path when the endpoint pattern is blank.
	 */
	@IsTest
	private static void shouldReturnDefaultPathWhenEndpointPatternIsBlank()
	{
		Assert.areEqual('/test', API_InboundInvoker.toConcreteEndpointPath(null), 'Null pattern should produce default path');
		Assert.areEqual('/test', API_InboundInvoker.toConcreteEndpointPath(''), 'Empty pattern should produce default path');
	}
}