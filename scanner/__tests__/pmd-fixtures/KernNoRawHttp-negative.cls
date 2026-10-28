// SPDX-License-Identifier: BUSL-1.1
public with sharing class KernNoRawHttp_Negative
{
	public static void sendThroughClient()
	{
		UTIL_HttpClient.get('callout:Example/items').send();
		kern.UTIL_HttpClient.post('callout:Example/items').send();
		HttpResponse response = new HttpResponse();
		HttpRequestBuilder builder = new HttpRequestBuilder();
	}
}
