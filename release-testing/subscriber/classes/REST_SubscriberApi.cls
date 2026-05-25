// SPDX-License-Identifier: BUSL-1.1
@RestResource(UrlMapping='/subscriber/accounts/*')
global inherited sharing class REST_SubscriberApi
{
	@HttpPost
	global static void createAccount()
	{
		kern.API_Dispatcher.processInboundService(API_SubscriberCreateAccount.class.getName());
	}
}
