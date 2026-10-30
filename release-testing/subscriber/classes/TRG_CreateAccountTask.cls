// SPDX-License-Identifier: Apache-2.0
/**
 * @description Trigger action that creates a follow-up Task for every new Account, so that someone reviews it. Runs
 * after insert, when the Account has its Id and the Task can point at it.
 */
public inherited sharing class TRG_CreateAccountTask extends kern.TRG_Base implements kern.IF_Trigger.AfterInsert
{
	/**
	 * @description Builds one "Review New Account" Task for each inserted Account, linked to that Account, and inserts
	 * them all together in one kern.DML_Builder transaction.
	 *
	 * @param newRecords The Accounts that were inserted.
	 */
	public void afterInsert(List<SObject> newRecords)
	{
		List<Task> tasks = new List<Task>();

		for(SObject record : newRecords)
		{
			Account newAccount = (Account)record;
			tasks.add(new Task(
					WhatId = newAccount.Id,
					Subject = 'Review New Account: ' + newAccount.Name,
					Status = 'Not Started',
					Priority = 'Normal',
					Description = 'Auto-created by TRG_CreateAccountTask after insert'
			));
		}

		if(!tasks.isEmpty())
		{
			kern.DML_Builder.newTransaction().doInsert(tasks).execute();
		}
	}
}
