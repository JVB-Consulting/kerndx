// SPDX-License-Identifier: BUSL-1.1
public inherited sharing class TRG_SetAccountDefaults extends kern.TRG_Base implements kern.IF_Trigger.BeforeInsert
{
	public void beforeInsert(List<SObject> newRecords)
	{
		for(SObject record : newRecords)
		{
			Account account = (Account)record;
			if(String.isBlank(Account.Description))
			{
				Account.Description = 'Default';
			}
		}
	}
}
