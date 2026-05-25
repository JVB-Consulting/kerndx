// SPDX-License-Identifier: BUSL-1.1
/**
 * @description REST endpoint for Contact Us form submissions.
 *
 * @see API_ContactFormSubmit
 *
 * @author your.name@company.com
 *
 * @group Web Services
 *
 * @date February 2026, May 2026
 */
@RestResource(UrlMapping='/v1/contact-form/*')
global inherited sharing class REST_ContactForm
{
	/**
	 * @description Handles POST requests for form submissions.
	 */
	@HttpPost
	global static void submitForm()
	{
		kern.API_Dispatcher.processInboundService(API_ContactFormSubmit.class.getName());
	}
}
