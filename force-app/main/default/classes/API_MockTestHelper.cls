// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Test helper for API mock verification. Provides assertion methods
 * that delegate to API_MockFactory verification API with descriptive error messages.
 *
 * @see API_MockFactory
 * @see API_MockTestHelper_TEST
 *
 * @author Jason van Beukering
 *
 * @group Web Services
 *
 * @date February 2026, May 2026
 *
 * @since 1.0
 *
 * @example
 * ```apex
 * API_MockFactory.forService('API_SendEmail').body('{}').statusCode(200).register();
 * // ... execute callout logic ...
 * API_MockTestHelper.assertServiceCalled('API_SendEmail');
 * API_MockTestHelper.assertServiceCalledTimes('API_SendEmail', 1);
 * ```
 */
@SuppressWarnings('PMD.AvoidGlobalModifier')
global inherited sharing class API_MockTestHelper
{
	/**
	 * @description Asserts that a service was called at least once.
	 *
	 * @param serviceName The service class name to verify
	 *
	 * @since 1.0
	 */
	global static void assertServiceCalled(String serviceName)
	{
		Assert.isTrue
				(
						API_MockFactory.wasCalled(serviceName),
						'Expected ' + serviceName + ' to be called at least once, but it was never called'
				);
	}

	/**
	 * @description Asserts that a service was called exactly the specified number of times.
	 *
	 * @param serviceName The service class name to verify
	 * @param expectedCount The expected number of invocations
	 *
	 * @since 1.0
	 */
	global static void assertServiceCalledTimes(String serviceName, Integer expectedCount)
	{
		Integer actualCount = API_MockFactory.getInvocationCount(serviceName);
		Assert.areEqual
				(
						expectedCount,
						actualCount,
						'Expected ' + serviceName + ' to be called ' + expectedCount + ' time(s), but was called ' + actualCount + ' time(s)'
				);
	}

	/**
	 * @description Asserts that a service was never called.
	 *
	 * @param serviceName The service class name to verify
	 *
	 * @since 1.0
	 */
	global static void assertServiceNeverCalled(String serviceName)
	{
		Assert.isTrue
				(
						API_MockFactory.wasNeverCalled(serviceName),
						'Expected ' + serviceName + ' to never be called, but it was called ' + API_MockFactory.getInvocationCount(serviceName) + ' time(s)'
				);
	}

	/**
	 * @description Asserts that the last request body contains the expected text.
	 *
	 * @param serviceName The service class name to verify
	 * @param expectedContent Text expected in the last request body
	 *
	 * @since 1.0
	 */
	global static void assertLastRequestContains(String serviceName, String expectedContent)
	{
		Assert.isTrue
				(
						API_MockFactory.lastRequestContains(serviceName, expectedContent),
						'Expected last request to ' + serviceName + ' to contain "' + expectedContent + '"'
				);
	}
}