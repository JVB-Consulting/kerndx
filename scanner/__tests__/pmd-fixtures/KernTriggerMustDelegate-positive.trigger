// SPDX-License-Identifier: Apache-2.0
trigger KernTriggerMustDelegatePositive on Account (before insert)
{
	List<Account> existing = [SELECT Id FROM Account LIMIT 1];
	if(existing.isEmpty())
	{
		new TRG_Dispatcher().run();
	}
	existing.clear();
}
