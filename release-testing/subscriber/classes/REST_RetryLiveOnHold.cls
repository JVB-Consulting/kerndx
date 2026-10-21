// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Release-testing REST endpoint for API_RetryLiveOnHold, the inbound handler that fails every request while
 * it is on hold.
 *
 * @see API_RetryLiveOnHold
 *
 * @author your.name@company.com
 *
 * @group Web Services
 *
 * @date October 2026
 */
@RestResource(urlMapping='/v1/retry-live-on-hold/*')
global inherited sharing class REST_RetryLiveOnHold
{
	/**
	 * @description Handles a POST by handing it to the framework, which answers it.
	 */
	@HttpPost
	global static void receive()
	{
		kern.API_Dispatcher.processInboundService(API_RetryLiveOnHold.class.getName());
	}
}
