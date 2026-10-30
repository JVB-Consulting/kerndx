// SPDX-License-Identifier: Apache-2.0
public with sharing class KernNoSystemDebug_Negative
{
	public static void logThroughBuilder()
	{
		LOG_Builder.build().info('message').emitAt('KernNoSystemDebug_Negative.logThroughBuilder');
		kern.LOG_Builder.build().error('message').emitAt('KernNoSystemDebug_Negative.logThroughBuilder');
	}
}
