// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Trigger action that marks the Accounts it has handled by setting AccountSource to "Subscriber Trigger".
 * One class handles two events: every insert, and any update that changes the Account's name.
 */
public inherited sharing class TRG_StampAccountSource extends kern.TRG_Base implements kern.IF_Trigger.BeforeInsert, kern.IF_Trigger.BeforeUpdate
{
	/**
	 * @description Sets AccountSource on every new Account, replacing any value that was entered.
	 *
	 * @param newRecords The Accounts being inserted.
	 */
	public void beforeInsert(List<SObject> newRecords)
	{
		for(SObject record : newRecords)
		{
			Account newAccount = (Account)record;
			newAccount.AccountSource = 'Subscriber Trigger';
		}
	}

	/**
	 * @description Sets AccountSource only on the Accounts whose name changed in this update. The others keep the value
	 * they have.
	 *
	 * @param newRecords The Accounts as they are about to be saved.
	 * @param oldRecords The same Accounts as they were before the update; unused, the old values come from triggerOldMap.
	 */
	public void beforeUpdate(List<SObject> newRecords, List<SObject> oldRecords)
	{
		for(SObject record : newRecords)
		{
			Account newAccount = (Account)record;
			Account oldAccount = (Account)triggerOldMap.get(newAccount.Id);
			if(newAccount.Name != oldAccount.Name)
			{
				newAccount.AccountSource = 'Subscriber Trigger';
			}
		}
	}
}
