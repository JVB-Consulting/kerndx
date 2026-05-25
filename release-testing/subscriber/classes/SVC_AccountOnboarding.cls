// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Account onboarding service. Creates an Account with related Contacts
 * and an Opportunity in a single transaction.
 *
 * @see SVC_AccountOnboarding_TEST
 *
 * @author your.name@company.com
 *
 * @group Services
 *
 * @date February 2026, May 2026
 */
public with sharing class SVC_AccountOnboarding
{
	/**
	 * @description Creates an Account with related Contacts and an Opportunity.
	 *
	 * @param accountName The name for the new Account.
	 * @param contactLastNames Last names for the Contacts to create.
	 * @param opportunityName The name for the Opportunity.
	 *
	 * @return The result of the transaction.
	 */
	public kern.DML_Builder.TransactionResult createAccount
			(
					String accountName,
					List<String> contactLastNames,
					String opportunityName
			)
	{
		Account newAccount = new Account(Name = accountName, Industry = 'Technology');

		Opportunity newOpportunity = new Opportunity
				(
						Name = opportunityName,
						StageName = 'Prospecting',
						CloseDate = Date.today().addDays(30)
				);

		kern.DML_Builder dmlTransaction = kern.DML_Builder.newTransaction()
				.doInsert(newAccount)
				.doInsert(newOpportunity, Opportunity.AccountId, newAccount);

		for(String lastName : contactLastNames)
		{
			Contact newContact = new Contact(LastName = lastName);
			dmlTransaction.doInsert(newContact, Contact.AccountId, newAccount);
		}

		return dmlTransaction.execute();
	}
}
