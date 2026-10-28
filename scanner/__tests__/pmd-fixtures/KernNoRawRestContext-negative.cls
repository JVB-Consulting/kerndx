// SPDX-License-Identifier: BUSL-1.1
@RestResource(UrlMapping='/routed/*')
global with sharing class REST_KernNoRawRestContextNegative
{
	@HttpPost
	global static void handle()
	{
		API_Dispatcher.processInboundService('ExampleService');
	}

	private static void readOwnProperties(Holder holder)
	{
		Object request = holder.request;
		Object response = holder.response;
	}

	private class Holder
	{
		private Object request;
		private Object response;
	}
}
