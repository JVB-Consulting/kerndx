// SPDX-License-Identifier: BUSL-1.1
public inherited sharing class TRG_CreateAccountTask extends kern.TRG_Base implements kern.IF_Trigger.AfterInsert
{
	public void afterInsert(List<SObject> newRecords)
	{
		List<Task> tasks = new List<Task>();

		for(SObject record : newRecords)
		{
			Account account = (Account)record;
			tasks.add(new Task(
					WhatId = Account.Id,
					Subject = 'Review New Account: ' + Account.Name,
					Status = 'Not Started',
					Priority = 'Normal',
					Description = 'Auto-created by TRG_CreateAccountTask after insert'
			));
		}

		if(!tasks.isEmpty())
		{
			insert tasks;
		}
	}
}
