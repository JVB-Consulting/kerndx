// SPDX-License-Identifier: Apache-2.0
/**
 * @description Controller for the accountCard LWC. Loads a single Account for display.
 *
 * @see CTRL_AccountCard_TEST
 *
 * @author your.name@company.com
 *
 * @group Account Management
 *
 * @date February 2026, November 2026
 */
public with sharing class CTRL_AccountCard
{
	/**
	 * @description Loads one Account by ID for the accountCard component.
	 *
	 * @param accountId The Id of the Account to load.
	 *
	 * @return The Account with Name and Industry populated, or null when no Account has that Id.
	 */
	@AuraEnabled(cacheable=true)
	public static Account getAccount(Id accountId)
	{
		return (Account)new SEL_Accounts().findById(accountId);
	}

	/**
	 * @description Reads Accounts with the fields the accountCard component shows.
	 */
	private with sharing class SEL_Accounts extends kern.SEL_Base
	{
		/**
		 * @description Creates the selector for Accounts.
		 */
		public SEL_Accounts()
		{
			super(Account.SObjectType);
		}

		/**
		 * @description The fields every read returns.
		 *
		 * @return Name and industry.
		 */
		public override List<SObjectField> getFields()
		{
			return new List<SObjectField> {Account.Name, Account.Industry};
		}
	}
}
