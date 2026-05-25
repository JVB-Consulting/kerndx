// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Unit tests for API_MockTestHelper assertion methods.
 *
 * @see API_MockTestHelper
 *
 * @author Jason van Beukering
 *
 * @group Web Services
 *
 * @date February 2026, May 2026
 */
@IsTest(SeeAllData=false IsParallel=true)
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
private class API_MockTestHelper_TEST
{
	/**
	 * @description Test service class name.
	 */
	private static final String TEST_SERVICE = 'API_TestService';

	/**
	 * @description Tests assertServiceCalled passes when service was called.
	 */
	@IsTest
	private static void shouldPassWhenServiceCalled()
	{
		API_MockFactory.forService(TEST_SERVICE).body('{}').statusCode(API_Base.HTTP_OK).register();
		API_MockFactory.getOutboundMock(TEST_SERVICE, null);

		API_MockTestHelper.assertServiceCalled(TEST_SERVICE);
	}

	/**
	 * @description Tests that wasCalled returns false when service was never called.
	 */
	@IsTest
	private static void shouldDetectWhenServiceNeverCalled()
	{
		Assert.isFalse(API_MockFactory.wasCalled(TEST_SERVICE), 'Should detect uncalled service');
	}

	/**
	 * @description Tests assertServiceCalledTimes passes for correct count.
	 */
	@IsTest
	private static void shouldPassForCorrectCallCount()
	{
		API_MockFactory.forService(TEST_SERVICE).body('{}').statusCode(API_Base.HTTP_OK).register();
		API_MockFactory.getOutboundMock(TEST_SERVICE, null);
		API_MockFactory.getOutboundMock(TEST_SERVICE, null);

		API_MockTestHelper.assertServiceCalledTimes(TEST_SERVICE, 2);
	}

	/**
	 * @description Tests assertServiceNeverCalled passes when service not called.
	 */
	@IsTest
	private static void shouldPassWhenServiceNeverCalled()
	{
		API_MockTestHelper.assertServiceNeverCalled(TEST_SERVICE);
	}

	/**
	 * @description Tests assertLastRequestContains passes when content is present.
	 */
	@IsTest
	private static void shouldPassWhenLastRequestContainsContent()
	{
		API_MockFactory.forService(TEST_SERVICE).body('{}').statusCode(API_Base.HTTP_OK).register();
		API_MockFactory.getOutboundMock(TEST_SERVICE, null, '{"orderId":"ORD-123"}');

		API_MockTestHelper.assertLastRequestContains(TEST_SERVICE, 'ORD-123');
	}

	/**
	 * @description Tests that lastRequestContains returns false when content is absent.
	 */
	@IsTest
	private static void shouldDetectMissingContentInLastRequest()
	{
		API_MockFactory.forService(TEST_SERVICE).body('{}').statusCode(API_Base.HTTP_OK).register();
		API_MockFactory.getOutboundMock(TEST_SERVICE, null, '{"orderId":"ORD-123"}');

		Assert.isFalse(
				API_MockFactory.lastRequestContains(TEST_SERVICE, 'NOT_PRESENT'),
				'Should return false when content is not in request'
		);
	}
}