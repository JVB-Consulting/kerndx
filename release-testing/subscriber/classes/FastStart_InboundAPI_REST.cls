// SPDX-License-Identifier: BUSL-1.1
/**
 * @description REST endpoint for the Fast Start inbound API demonstration.
 *              Receives POST requests and delegates to FastStart_InboundAPI_DEMO for processing.
 *
 * @see FastStart_InboundAPI_DEMO
 *
 * @author your.name@company.com
 *
 * @group Fast Start Demos
 *
 * @date May 2026
 */
@RestResource(UrlMapping='/v1/contacts/*')
global with sharing class FastStart_InboundAPI_REST
{
	/**
	 * @description Handles POST requests. The @HttpPost annotation determines the verb —
	 *              kern__Method__c on ApiSetting__mdt is not consulted for the REST_* annotation pattern.
	 */
	@HttpPost
	global static void create()
	{
		kern.API_Dispatcher.processInboundService(FastStart_InboundAPI_DEMO.class.getName());
	}
}
