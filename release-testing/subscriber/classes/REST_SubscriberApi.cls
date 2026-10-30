// SPDX-License-Identifier: Apache-2.0
/**
 * @description REST endpoint for creating Accounts, mapped to /subscriber/accounts. It holds no logic of its own: it
 * hands each request to the framework, which runs API_SubscriberCreateAccount. The platform requires a REST resource
 * class to be global.
 */
@RestResource(urlMapping='/subscriber/accounts/*')
global inherited sharing class REST_SubscriberApi
{
	/**
	 * @description Handles an HTTP POST. Passes the name of the service class to kern.API_Dispatcher.processInboundService;
	 * the framework then reads the request, runs the service and writes the response.
	 */
	@HttpPost
	global static void createAccount()
	{
		kern.API_Dispatcher.processInboundService(API_SubscriberCreateAccount.class.getName());
	}
}
