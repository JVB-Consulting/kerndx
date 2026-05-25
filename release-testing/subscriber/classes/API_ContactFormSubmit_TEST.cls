// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Unit tests for API_ContactFormSubmit.
 *
 * @see API_ContactFormSubmit
 *
 * @author your.name@company.com
 *
 * @group Web Services
 *
 * @date February 2026, May 2026
 */
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest(SeeAllData=false IsParallel=true)
private class API_ContactFormSubmit_TEST
{
	/**
	 * @description The API service class name.
	 */
	private static final String SERVICE_NAME = API_ContactFormSubmit.class.getName();

	/**
	 * @description Tests a successful form submission that creates a Lead.
	 */
	@IsTest
	private static void shouldCreateLeadFromValidSubmission()
	{
		API_ContactFormSubmit.DTO_Request request = new API_ContactFormSubmit.DTO_Request();
		Request.firstName = 'Jane';
		Request.lastName = 'Doe';
		Request.email = 'jane.doe@example.com';
		Request.message = 'I want to learn more';

		kern.API_InboundTestHelper.assertCallSuccessful(SERVICE_NAME, Request);
	}

	/**
	 * @description Tests that the call is aborted when last name is missing.
	 */
	@IsTest
	private static void shouldAbortWhenLastNameMissing()
	{
		API_ContactFormSubmit.DTO_Request request = new API_ContactFormSubmit.DTO_Request();
		Request.email = 'jane@example.com';

		kern.API_InboundTestHelper.assertCallAborted(SERVICE_NAME, Request, 'Last name is required');
	}

	/**
	 * @description Tests that the call is aborted when email is missing.
	 */
	@IsTest
	private static void shouldAbortWhenEmailMissing()
	{
		API_ContactFormSubmit.DTO_Request request = new API_ContactFormSubmit.DTO_Request();
		Request.lastName = 'Doe';

		kern.API_InboundTestHelper.assertCallAborted(SERVICE_NAME, Request, 'Email is required');
	}
}
