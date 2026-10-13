// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Trigger action that gives a new Account a Description when none was entered. Runs before insert, so the
 * value is saved with the record and no second save is needed.
 */
public inherited sharing class TRG_SetAccountDefaults extends kern.TRG_Base implements kern.IF_Trigger.BeforeInsert
{
	/**
	 * @description Sets Description to "Default" on each new Account whose Description is blank. A Description that was
	 * entered is left as it is.
	 *
	 * @param newRecords The Accounts being inserted.
	 */
	public void beforeInsert(List<SObject> newRecords)
	{
		for(SObject record : newRecords)
		{
			Account newAccount = (Account)record;
			if(String.isBlank(newAccount.Description))
			{
				newAccount.Description = 'Default';
			}
		}
	}
}
