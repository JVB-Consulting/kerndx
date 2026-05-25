// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Unit tests for {@link FastStart_OutboundAPI_DEMO}. Validates the happy path,
 * the missing-parameter abort path, the non-numeric-parameter abort path, and the error-mock
 * failure path at 100% coverage.
 *
 * @see FastStart_OutboundAPI_DEMO
 *
 * @author your.name@company.com
 *
 * @group Fast Start Demos
 *
 * @date May 2026
 */
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest(SeeAllData=false IsParallel=true)
private class FastStart_OutboundAPI_DEMO_TEST
{
	/** @description Fully qualified service name used to identify the handler in the framework. */
	private static final String SERVICE_NAME = FastStart_OutboundAPI_DEMO.class.getName();

	/** @description Valid numeric post ID used in success-path tests. */
	private static final String TEST_POST_ID = '1';

	/**
	 * @description Verifies that a call with a valid numeric post ID is executed successfully.
	 * The framework intercepts the callout and returns {@code defaultMockBody} -- no real HTTP
	 * request is made.
	 */
	@IsTest
	private static void shouldFetchPostSuccessfully()
	{
		Map<String, String> parameters = new Map<String, String>
		{
			FastStart_OutboundAPI_DEMO.PARAM_POST_ID => TEST_POST_ID
		};

		kern.API_OutboundTestHelper.assertCallSuccessful(SERVICE_NAME, null, parameters);
	}

	/**
	 * @description Verifies that the call is aborted when the required {@code postId} parameter
	 * is absent. The framework short-circuits before making a network request.
	 */
	@IsTest
	private static void shouldAbortWhenPostIdMissing()
	{
		kern.API_OutboundTestHelper.assertCallAborted(SERVICE_NAME, null);
	}

	/**
	 * @description Verifies that the call is aborted when the post ID is non-numeric.
	 * {@code getValidationErrors()} detects the invalid value and returns an error message,
	 * causing the framework to abort without calling the external API.
	 */
	@IsTest
	private static void shouldAbortWhenPostIdNotNumeric()
	{
		Map<String, String> parameters = new Map<String, String>
		{
			FastStart_OutboundAPI_DEMO.PARAM_POST_ID => 'abc'
		};

		kern.API_OutboundTestHelper.assertCallAborted(SERVICE_NAME, null, parameters);
	}

	/**
	 * @description Verifies that the call is recorded as Failed when the external API returns a
	 * server error. Uses {@code kern.API_MockFactory.registerErrorMock()} to simulate a 500 response.
	 */
	@IsTest
	private static void shouldFailWhenApiReturnsError()
	{
		kern.API_MockFactory.registerErrorMock(SERVICE_NAME);

		Map<String, String> parameters = new Map<String, String>
		{
			FastStart_OutboundAPI_DEMO.PARAM_POST_ID => TEST_POST_ID
		};

		kern__ApiCall__c apiCall = kern.TST_Factory.newOutboundApiCall(SERVICE_NAME, null, parameters);
		kern.API_OutboundTestHelper.assertCallFailed(new List<kern__ApiCall__c>{ apiCall });
	}
}
