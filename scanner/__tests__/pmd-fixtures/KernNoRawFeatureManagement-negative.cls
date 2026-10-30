// SPDX-License-Identifier: Apache-2.0
public with sharing class KernNoRawFeatureManagement_Negative
{
	public static void checkThroughUtility()
	{
		Boolean enabled = UTIL_FeatureFlag.isEnabled('MyFlag');
		Boolean namespaced = kern.UTIL_FeatureFlag.isEnabled('MyFlag');
	}
}
