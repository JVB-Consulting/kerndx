// SPDX-License-Identifier: Apache-2.0
public with sharing class KernNoRawEventPublish_Negative
{
	public static void publishThroughFramework()
	{
		LOG_Builder.build().info('message').emitAt('KernNoRawEventPublish_Negative.publishThroughFramework');
		String identifier = EventBus.getOperationId(null);
	}
}
