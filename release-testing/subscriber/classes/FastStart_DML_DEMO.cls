// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Drift-guard demo class for the Fast Start - DML guide. Demonstrates the core
 * DML_Builder patterns: parent-child auto-link and partial-success mode.
 *
 * @see FastStart_DML_DEMO_TEST
 *
 * @author your.name@company.com
 *
 * @group Fast Start Demos
 *
 * @date May 2026
 */
public with sharing class FastStart_DML_DEMO
{
	/**
	 * @description Creates an Account and one Contact per last name in a single atomic transaction.
	 * The Contact's AccountId is populated automatically by the framework after the Account inserts.
	 *
	 * @param accountName The name for the new Account.
	 * @param contactLastNames Last names for the Contacts to create.
	 *
	 * @return The result of the transaction.
	 */
	public kern.DML_Builder.TransactionResult createAccountWithContacts
			(
					String accountName,
					List<String> contactLastNames
			)
	{
		Account newAccount = new Account(Name = accountName, Phone = '555-0100');

		kern.DML_Builder dmlTransaction = kern.DML_Builder.newTransaction()
				.doInsert(newAccount);

		for(String lastName : contactLastNames)
		{
			Contact newContact = new Contact(LastName = lastName);
			dmlTransaction.doInsert(newContact, Contact.AccountId, newAccount);
		}

		return dmlTransaction.execute();
	}

	/**
	 * @description Inserts a list of Accounts in partial-success mode. Valid records are saved;
	 * invalid records are logged and reported in the result without rolling back the whole batch.
	 *
	 * @param accounts The Accounts to insert.
	 *
	 * @return The result of the transaction.
	 */
	public kern.DML_Builder.TransactionResult tryBulkInsertAccounts(List<Account> accounts)
	{
		return kern.DML_Builder.newTransaction()
				.doInsert(accounts)
				.allowPartial()
				.execute();
	}
}
