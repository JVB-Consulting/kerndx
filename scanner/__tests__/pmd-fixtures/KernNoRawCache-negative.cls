// SPDX-License-Identifier: BUSL-1.1
public with sharing class KernNoRawCache_Negative
{
	public static void cacheThroughUtility()
	{
		UTIL_Cache.org().put('key', 'value');
		Object cached = kern.UTIL_Cache.org().get('key');
	}
}
