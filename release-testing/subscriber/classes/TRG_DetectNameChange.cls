// SPDX-License-Identifier: BUSL-1.1
public inherited sharing class TRG_DetectNameChange extends kern.TRG_Base implements kern.IF_Trigger.AfterUpdate
{
	public void afterUpdate(List<SObject> newRecords, List<SObject> oldRecords)
	{
		List<Task> tasks = new List<Task>();

		for(SObject record : newRecords)
		{
			Account newAccount = (Account)record;
			Account oldAccount = (Account)triggerOldMap.get(newAccount.Id);

			if(newAccount.Name != oldAccount.Name)
			{
				tasks.add(new Task(
						WhatId = newAccount.Id,
						Subject = 'Name Changed: ' + oldAccount.Name + ' -> ' + newAccount.Name,
						Status = 'Completed',
						Priority = 'Low',
						Description = 'Auto-created by TRG_DetectNameChange after update'
				));
			}
		}

		if(!tasks.isEmpty())
		{
			insert tasks;
		}
	}
}
