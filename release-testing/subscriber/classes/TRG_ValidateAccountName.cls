// SPDX-License-Identifier: BUSL-1.1
public inherited sharing class TRG_ValidateAccountName extends kern.TRG_Base implements kern.IF_Trigger.BeforeInsert
{
	public void beforeInsert(List<SObject> newRecords)
	{
		for(SObject record : newRecords)
		{
			Account account = (Account)record;
			if(Account.Name != null && Account.Name.contains('BLOCKED'))
			{
				Account.addError('Account Name cannot contain BLOCKED');
			}
		}
	}
}
