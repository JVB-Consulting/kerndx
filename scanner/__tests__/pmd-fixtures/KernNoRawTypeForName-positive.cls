// SPDX-License-Identifier: Apache-2.0
public with sharing class KernNoRawTypeForName_Positive
{
	public static void resolveRaw()
	{
		Type unqualified = Type.forName('MyClass');
		Type namespaced = Type.forName('kern', 'TRG_Dispatcher');
	}
}
