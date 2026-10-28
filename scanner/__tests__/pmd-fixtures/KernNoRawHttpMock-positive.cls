// SPDX-License-Identifier: BUSL-1.1
@IsTest
private class KernNoRawHttpMock_Positive_TEST
{
	private class HandRolledMock implements HttpCalloutMock
	{
		public HttpResponse respond(HttpRequest request)
		{
			return new HttpResponse();
		}
	}

	private class HandRolledSoapMock implements WebServiceMock
	{
		public void doInvoke(Object stub, Object request, Map<String, Object> response, String endpoint, String soapAction, String requestName, String responseNamespace, String responseName, String responseType)
		{
			response.put('response_x', null);
		}
	}
}
