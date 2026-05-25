// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Unit tests for API_GetPost.
 *
 * @see API_GetPost
 *
 * @author your.name@company.com
 *
 * @group Web Services
 *
 * @date February 2026, May 2026
 */
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest(SeeAllData=false IsParallel=true)
private class API_GetPost_TEST
{
	/**
	 * @description The API service class name.
	 */
	private static final String SERVICE_NAME = API_GetPost.class.getName();

	/**
	 * @description Test value for post ID parameter.
	 */
	private static final String TEST_POST_ID = '1';

	/**
	 * @description Tests a successful API call with valid parameters.
	 */
	@IsTest
	private static void shouldFetchPostSuccessfully()
	{
		Map<String, String> parameters = new Map<String, String>
		{
				API_GetPost.PARAM_POST_ID => TEST_POST_ID
		};

		kern.API_OutboundTestHelper.assertCallSuccessful(SERVICE_NAME, null, parameters);
	}

	/**
	 * @description Tests that the call is aborted when the post ID parameter is missing.
	 */
	@IsTest
	private static void shouldAbortWhenPostIdMissing()
	{
		kern.API_OutboundTestHelper.assertCallAborted(SERVICE_NAME, null);
	}

	/**
	 * @description Tests that the call is aborted when post ID is not numeric.
	 */
	@IsTest
	private static void shouldAbortWhenPostIdNotNumeric()
	{
		Map<String, String> parameters = new Map<String, String>
		{
				API_GetPost.PARAM_POST_ID => 'abc'
		};

		kern.API_OutboundTestHelper.assertCallAborted(SERVICE_NAME, null, parameters);
	}

	/**
	 * @description Tests that the call fails when the API returns a server error.
	 */
	@IsTest
	private static void shouldFailWhenApiReturnsError()
	{
		kern.API_MockFactory.registerErrorMock(SERVICE_NAME);

		Map<String, String> parameters = new Map<String, String>
		{
				API_GetPost.PARAM_POST_ID => TEST_POST_ID
		};

		kern__ApiCall__c apiCall = kern.TST_Factory.newOutboundApiCall(SERVICE_NAME, null, parameters);
		kern.API_OutboundTestHelper.assertCallFailed(new List<kern__ApiCall__c> {apiCall});
	}
}
