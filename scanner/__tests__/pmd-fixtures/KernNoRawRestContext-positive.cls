// SPDX-License-Identifier: BUSL-1.1
@RestResource(UrlMapping='/raw/*')
global with sharing class REST_KernNoRawRestContextPositive
{
	@HttpPost
	global static void handle()
	{
		RestRequest request = RestContext.request;
		RestResponse response = RestContext.response;
		response.statusCode = 200;
	}
}
