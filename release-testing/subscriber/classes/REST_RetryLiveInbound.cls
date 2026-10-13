// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Release-testing REST endpoint for API_RetryLiveInbound, the inbound handler whose error handling throws.
 *
 * @see API_RetryLiveInbound
 *
 * @author your.name@company.com
 *
 * @group Web Services
 *
 * @date October 2026
 */
@RestResource(urlMapping='/v1/retry-live-inbound/*')
global inherited sharing class REST_RetryLiveInbound
{
	/**
	 * @description Handles a POST by handing it to the framework, which answers it.
	 */
	@HttpPost
	global static void receive()
	{
		kern.API_Dispatcher.processInboundService(API_RetryLiveInbound.class.getName());
	}
}
