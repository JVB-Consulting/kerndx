// SPDX-License-Identifier: BUSL-1.1
public with sharing class KernNoRawHttp_Positive
{
	public static void sendRaw()
	{
		HttpRequest request = new HttpRequest();
		Http http = new Http();
		System.HttpRequest qualifiedRequest = new System.HttpRequest();
		System.Http qualifiedHttp = new System.Http();
		Object response = WebServiceCallout.invoke(null, null, null, null);
	}
}
