// SPDX-License-Identifier: Apache-2.0
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
