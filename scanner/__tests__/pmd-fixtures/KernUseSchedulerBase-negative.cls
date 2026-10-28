// SPDX-License-Identifier: BUSL-1.1
public with sharing class KernUseSchedulerBase_Negative extends kern.SCHED_Base
{
	public override void execute()
	{
		new QueuedWork().run();
	}

	public with sharing class Unqualified extends SCHED_Base
	{
		public override void execute()
		{
			new QueuedWork().run();
		}
	}
}
