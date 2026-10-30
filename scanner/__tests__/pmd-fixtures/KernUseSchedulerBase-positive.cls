// SPDX-License-Identifier: Apache-2.0
public with sharing class KernUseSchedulerBase_Positive implements Schedulable
{
	public void execute(SchedulableContext context)
	{
		new QueuedWork().run();
	}

	public with sharing class Nested implements System.Schedulable
	{
		public void execute(SchedulableContext context)
		{
			new QueuedWork().run();
		}
	}
}
