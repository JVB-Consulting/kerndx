// SPDX-License-Identifier: BUSL-1.1
trigger KernTriggerMustDelegatePositiveNoDelegation on Account (before insert)
{
	for(Account record : Trigger.new)
	{
		record.Description = 'set in the trigger';
	}
	Trigger.new[0].Name = 'set in the trigger';
}
