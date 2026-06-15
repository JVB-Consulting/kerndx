// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Unit tests for FastStart_InboundAPI_DEMO.
 *              Covers the success path (valid email) and the abort path (blank email).
 *
 * @see FastStart_InboundAPI_DEMO
 *
 * @author your.name@company.com
 *
 * @group Fast Start Demos
 *
 * @date May 2026
 */
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest(SeeAllData=false IsParallel=true)
private class FastStart_InboundAPI_DEMO_TEST
{
	/**
	 * @description The API service class name used to identify the handler in assertions.
	 */
	private static final String SERVICE_NAME = FastStart_InboundAPI_DEMO.class.getName();

	/**
	 * @description Tests a successful request that creates an Account record.
	 */
	@IsTest
	private static void shouldCreateAccountFromValidRequest()
	{
		kern.UTIL_ValidationRule.bypassObject('Account');

		FastStart_InboundAPI_DEMO.DTO_Request request = new FastStart_InboundAPI_DEMO.DTO_Request();
		Request.name = 'Acme Corp';
		Request.email = 'info@acme.example.com';
		Request.phone = '415-555-0100';

		kern.API_InboundTestHelper.assertCallSuccessful(SERVICE_NAME, Request);
	}

	/**
	 * @description Tests that the call is aborted when the email field is blank.
	 */
	@IsTest
	private static void shouldAbortWhenEmailIsBlank()
	{
		kern.UTIL_ValidationRule.bypassObject('Account');

		FastStart_InboundAPI_DEMO.DTO_Request request = new FastStart_InboundAPI_DEMO.DTO_Request();
		Request.name = 'Acme Corp';

		kern.API_InboundTestHelper.assertCallAborted(SERVICE_NAME, Request, 'Email is required');
	}
}
