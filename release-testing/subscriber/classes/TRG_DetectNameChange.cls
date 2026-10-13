// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Trigger action that leaves a record of every Account rename: a completed Task whose subject shows the
 * old name and the new one. Runs after update.
 */
public inherited sharing class TRG_DetectNameChange extends kern.TRG_Base implements kern.IF_Trigger.AfterUpdate
{
	/**
	 * @description Compares each Account's name with its value before the update, read from triggerOldMap, and creates a
	 * completed Task for each Account whose name changed. An Account whose name did not change gets no Task. The Tasks
	 * are inserted together in one kern.DML_Builder transaction.
	 *
	 * @param newRecords The Accounts as they are after the update.
	 * @param oldRecords The same Accounts as they were before the update; unused, the old values come from triggerOldMap.
	 */
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
			kern.DML_Builder.newTransaction().doInsert(tasks).execute();
		}
	}
}
