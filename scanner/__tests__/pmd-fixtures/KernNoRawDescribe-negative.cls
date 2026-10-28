// SPDX-License-Identifier: BUSL-1.1
public with sharing class KernNoRawDescribe_Negative
{
	public static void describeThroughUtility()
	{
		Object describe = UTIL_SObjectDescribe.getDescribe(Account.SObjectType);
		String fieldName = kern.UTIL_SObjectDescribe.getCachedFieldName(Account.Name);
	}
}
