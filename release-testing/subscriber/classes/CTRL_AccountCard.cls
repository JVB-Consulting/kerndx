// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Controller for the accountCard LWC. Loads a single Account for display.
 *
 * @see CTRL_AccountCard_TEST
 *
 * @author your.name@company.com
 *
 * @group Account Management
 *
 * @date February 2026
 */
public with sharing class CTRL_AccountCard
{
	/**
	 * @description Loads one Account by ID for the accountCard component.
	 *
	 * @param accountId The Id of the Account to load.
	 *
	 * @return The Account with Name and Industry populated.
	 */
	@AuraEnabled(cacheable=true)
	public static Account getAccount(Id accountId)
	{
		return (Account)kern.QRY_Builder.selectFrom(Account.SObjectType)
				.fields(new List<SObjectField> {Account.Name, Account.Industry})
				.condition(Account.Id).equals(accountId)
				.getFirst();
	}
}
