// SPDX-License-Identifier: Apache-2.0
public with sharing class KernNoRawCache_Positive
{
	public static void cacheRaw()
	{
		Cache.Org.put('local.Default.key', 'value');
		Object cached = Cache.Org.get('local.Default.key');
		Cache.Session.put('local.Default.key', 'value');
	}
}
