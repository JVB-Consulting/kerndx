// SPDX-License-Identifier: Apache-2.0
public with sharing class KernNoRawEventPublish_Positive
{
	public static void publishRaw(List<SObject> events)
	{
		EventBus.publish(events);
		Database.SaveResult result = EventBus.publish(events[0]);
	}
}
