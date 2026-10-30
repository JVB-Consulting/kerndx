// SPDX-License-Identifier: Apache-2.0
public with sharing class KernNoSystemDebug_Positive
{
	public static void logRaw()
	{
		System.debug('first');
		System.debug(LoggingLevel.ERROR, 'second');
		system.DEBUG('third');
	}
}
