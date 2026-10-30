// SPDX-License-Identifier: Apache-2.0
public with sharing class KernNoRawTypeForName_Negative
{
	public static void resolveThroughUtility()
	{
		Type resolved = UTIL_System.getTypeForClassName('MyClass');
		Type namespaced = kern.UTIL_System.getTypeForClassName('MyClass');
		String className = KernNoRawTypeForName_Negative.class.getName();
	}
}
