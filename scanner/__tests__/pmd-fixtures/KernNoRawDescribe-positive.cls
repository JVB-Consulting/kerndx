// SPDX-License-Identifier: Apache-2.0
public with sharing class KernNoRawDescribe_Positive
{
	public static void describeRaw()
	{
		Map<String, Schema.SObjectType> globalDescribe = Schema.getGlobalDescribe();
		List<Schema.DescribeTabSetResult> tabs = Schema.describeTabs();
		List<Schema.DescribeSObjectResult> results = Schema.describeSObjects(new List<String> {'Account'});
	}
}
