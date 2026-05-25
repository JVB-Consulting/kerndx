// SPDX-License-Identifier: BUSL-1.1
public inherited sharing class TRG_StampAccountSource extends kern.TRG_Base implements kern.IF_Trigger.BeforeInsert, kern.IF_Trigger.BeforeUpdate
{
	public void beforeInsert(List<SObject> newRecords)
	{
		for(SObject record : newRecords)
		{
			Account account = (Account)record;
			Account.AccountSource = 'Subscriber Trigger';
		}
	}

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
