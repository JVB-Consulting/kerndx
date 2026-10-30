// SPDX-License-Identifier: Apache-2.0
/**
 * @description Trigger action that refuses a new Account whose name contains the word BLOCKED. It shows how a trigger
 * action rejects a record: an error added before insert stops that record from being saved.
 */
public inherited sharing class TRG_ValidateAccountName extends kern.TRG_Base implements kern.IF_Trigger.BeforeInsert
{
	/**
	 * @description Adds an error to each new Account whose name contains "BLOCKED" in capitals; the check is
	 * case-sensitive. An Account with no name is skipped. The error text comes from the AccountName_ContainsBlocked
	 * Custom Label, so it can be translated.
	 *
	 * @param newRecords The Accounts being inserted.
	 */
	public void beforeInsert(List<SObject> newRecords)
	{
		for(SObject record : newRecords)
		{
			Account newAccount = (Account)record;
			if(newAccount.Name != null && newAccount.Name.contains('BLOCKED'))
			{
				newAccount.addError(System.Label.AccountName_ContainsBlocked);
			}
		}
	}
}
