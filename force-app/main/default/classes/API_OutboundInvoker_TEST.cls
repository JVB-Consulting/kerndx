// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Test class for API_OutboundInvoker. Verifies invocation of outbound API
 * requests with Safe Mode and mocking control, including error handling.
 *
 * @see API_OutboundInvoker
 *
 * @author Jason van Beukering
 *
 * @group Web Services
 *
 * @date February 2026, May 2026
 */
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest(SeeAllData=false IsParallel=false)
private class API_OutboundInvoker_TEST
{
	/**
	 * @description The service class name used for outbound invocation.
	 */
	private static final String SERVICE_NAME = API_PostExample.class.getName();

	/**
	 * @description Tests that invocation populates response body, execution time, and service name.
	 */
	@IsTest
	private static void shouldPopulateResultFieldsOnSuccessfulInvocation()
	{
		Test.startTest();

		DTO_InvocationResult invocationResult =
				API_OutboundInvoker.invoke(SERVICE_NAME, UserInfo.getUserId(), new Map<String, String>(), false, false);

		Test.stopTest();

		Assert.isTrue(invocationResult.success, 'Invocation should succeed');
		Assert.isNotNull(invocationResult.responseBody, 'Response body should be populated');
		Assert.isNotNull(invocationResult.executionTimeMs, 'Execution time should be tracked');
		Assert.areEqual(SERVICE_NAME, invocationResult.serviceName, 'Service name should match');
	}

	/**
	 * @description Tests that Safe Mode is activated and closed after invocation.
	 */
	@IsTest
	private static void shouldActivateAndCloseSafeMode()
	{
		Test.startTest();

		DTO_InvocationResult invocationResult =
				API_OutboundInvoker.invoke(SERVICE_NAME, UserInfo.getUserId(), new Map<String, String>(), true, false);

		Test.stopTest();

		Assert.isTrue(invocationResult.safeModeEnabled, 'Safe Mode should be enabled');
		Assert.isFalse(API_Base.isSafeModeActive(), 'Safe Mode should be closed after invocation');
	}

	/**
	 * @description Tests that mocking produces a mocked response.
	 */
	@IsTest
	private static void shouldReturnMockedResponseWhenMockingEnabled()
	{
		Test.startTest();

		DTO_InvocationResult invocationResult =
				API_OutboundInvoker.invoke(SERVICE_NAME, UserInfo.getUserId(), new Map<String, String>(), false, true);

		Test.stopTest();

		Assert.isTrue(invocationResult.mockingEnabled, 'Mocking should be enabled');
		Assert.isTrue(invocationResult.isMockedResponse, 'Response should be mocked');
	}

	/**
	 * @description Tests that Safe Mode and mocking work together without conflict.
	 */
	@IsTest
	private static void shouldSupportSafeModeAndMockingCombined()
	{
		Test.startTest();

		DTO_InvocationResult invocationResult =
				API_OutboundInvoker.invoke(SERVICE_NAME, UserInfo.getUserId(), new Map<String, String>(), true, true);

		Test.stopTest();

		Assert.isTrue(invocationResult.safeModeEnabled, 'Safe Mode should be enabled');
		Assert.isTrue(invocationResult.mockingEnabled, 'Mocking should be enabled');
		Assert.isTrue(invocationResult.isMockedResponse, 'Response should be mocked');
		Assert.isFalse(API_Base.isSafeModeActive(), 'Safe Mode should be closed after invocation');
	}

	/**
	 * @description Tests that the three-parameter overload enables Safe Mode and disables mocking by default.
	 */
	@IsTest
	private static void shouldDefaultToSafeModeForThreeParameterOverload()
	{
		Test.startTest();

		DTO_InvocationResult invocationResult =
				API_OutboundInvoker.invoke(SERVICE_NAME, UserInfo.getUserId(), new Map<String, String>());

		Test.stopTest();

		Assert.isTrue(invocationResult.safeModeEnabled, 'Should default to Safe Mode enabled');
		Assert.isFalse(invocationResult.mockingEnabled, 'Should default to mocking disabled');
	}

	/**
	 * @description Tests that the two-parameter overload enables Safe Mode and disables mocking by default.
	 */
	@IsTest
	private static void shouldDefaultToSafeModeForTwoParameterOverload()
	{
		Test.startTest();

		DTO_InvocationResult invocationResult =
				API_OutboundInvoker.invoke(SERVICE_NAME, UserInfo.getUserId());

		Test.stopTest();

		Assert.isTrue(invocationResult.safeModeEnabled, 'Should default to Safe Mode enabled');
		Assert.isFalse(invocationResult.mockingEnabled, 'Should default to mocking disabled');
	}

	/**
	 * @description Tests that platform-level exceptions populate errors list and error text.
	 */
	@IsTest
	private static void shouldPopulateErrorsWhenExceptionOccurs()
	{
		API_OutboundInvoker.forceException = true;

		DTO_InvocationResult invocationResult =
				API_OutboundInvoker.invoke(SERVICE_NAME, UserInfo.getUserId(), new Map<String, String>(), false, false);

		Assert.isFalse(invocationResult.success, 'Should not be successful');
		Assert.isFalse(invocationResult.errors.isEmpty(), 'Should contain error details');
		Assert.isNotNull(invocationResult.errorText, 'Error text should be populated');
	}

	/**
	 * @description Tests that Safe Mode context is released even when an exception occurs.
	 */
	@IsTest
	private static void shouldCloseSafeModeContextOnException()
	{
		API_OutboundInvoker.forceException = true;

		DTO_InvocationResult invocationResult =
				API_OutboundInvoker.invoke(SERVICE_NAME, UserInfo.getUserId(), new Map<String, String>(), true, false);

		Assert.isFalse(invocationResult.success, 'Should not be successful');
		Assert.isTrue(invocationResult.safeModeEnabled, 'Safe Mode should have been enabled');
		Assert.isFalse(API_Base.isSafeModeActive(), 'Safe Mode should be closed after exception');
	}

	/**
	 * @description Tests that request and response headers from the handler are surfaced in the result.
	 */
	@IsTest
	private static void shouldSurfaceRequestAndResponseHeaders()
	{
		Test.startTest();

		DTO_InvocationResult invocationResult =
				API_OutboundInvoker.invoke(SERVICE_NAME, UserInfo.getUserId(), new Map<String, String>(), false, false);

		Test.stopTest();

		Assert.isTrue(invocationResult.success, 'Invocation should succeed');
		Assert.isFalse(invocationResult.requestHeaders.isEmpty(), 'Request headers should be captured');
		Assert.isFalse(invocationResult.responseHeaders.isEmpty(), 'Response headers should be captured');
	}

	/**
	 * @description Tests that timing duration fields are populated from handler stopwatches.
	 */
	@IsTest
	private static void shouldPopulateTimingDurationFieldsOnSuccessfulInvocation()
	{
		Test.startTest();

		DTO_InvocationResult invocationResult =
				API_OutboundInvoker.invoke(SERVICE_NAME, UserInfo.getUserId(), new Map<String, String>(), false, false);

		Test.stopTest();

		Assert.isTrue(invocationResult.success, 'Invocation should succeed');
		Assert.isNotNull(invocationResult.handlerDurationMs, 'Handler duration should be populated');
		Assert.isNotNull(invocationResult.calloutDurationMs, 'Callout duration should be populated');
		Assert.isNotNull(invocationResult.commitDurationMs, 'Commit duration should be populated');
	}

	/**
	 * @description Tests that request parameters are forwarded to the handler via the queue item.
	 */
	@IsTest
	private static void shouldForwardParametersToHandler()
	{
		Map<String, String> parameters = new Map<String, String>
		{
				API_PostExample.PARAMETER_NAME => 'test-value'
		};

		Test.startTest();

		DTO_InvocationResult invocationResult =
				API_OutboundInvoker.invoke(SERVICE_NAME, UserInfo.getUserId(), parameters, false, false);

		Test.stopTest();

		Assert.isTrue(invocationResult.success, 'Invocation should succeed with parameters');
	}
}