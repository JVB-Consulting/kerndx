// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Unit tests for REST_ContactForm endpoint.
 *
 * @see REST_ContactForm
 *
 * @author your.name@company.com
 *
 * @group Web Services
 *
 * @date March 2026, May 2026
 */
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest(SeeAllData=false IsParallel=true)
private class REST_ContactForm_TEST
{
	/**
	 * @description Tests that the REST endpoint delegates to the API handler.
	 */
	@IsTest
	private static void shouldDelegateToApiHandler()
	{
		API_ContactFormSubmit.DTO_Request request = new API_ContactFormSubmit.DTO_Request();
		Request.firstName = 'Jane';
		Request.lastName = 'Doe';
		Request.email = 'jane.doe@example.com';
		Request.message = 'Test via REST';

		kern.API_InboundTestHelper.setupRestContext(Request);

		Test.startTest();
		REST_ContactForm.submitForm();
		Test.stopTest();

		kern.SEL_ApiCall.assertServiceCompleted(API_ContactFormSubmit.class.getName());
	}
}
