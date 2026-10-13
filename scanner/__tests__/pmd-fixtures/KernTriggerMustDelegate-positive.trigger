// SPDX-License-Identifier: BUSL-1.1
trigger KernTriggerMustDelegatePositive on Account (before insert)
{
	List<Account> existing = [SELECT Id FROM Account LIMIT 1];
	if(existing.isEmpty())
	{
		new TRG_Dispatcher().run();
	}
	existing.clear();
}
