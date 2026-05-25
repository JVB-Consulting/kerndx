// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Unit tests for FastStart_DML_DEMO. Validates the parent-child auto-link pattern
 * and partial-success mode at 100% coverage.
 *
 * @see FastStart_DML_DEMO
 *
 * @author your.name@company.com
 *
 * @group Fast Start Demos
 *
 * @date May 2026
 */
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest(SeeAllData=false IsParallel=true)
private class FastStart_DML_DEMO_TEST
{
	/** @description Account name used across parent-child tests. */
	private static final String TEST_ACCOUNT_NAME = 'Demo Corp';

	/** @description Contact last name used for single-contact tests. */
	private static final String TEST_CONTACT_LAST_NAME = 'Smith';

	/**
	 * @description Verifies that each Contact's AccountId matches the inserted Account's Id after
	 * the framework resolves the parent-child relationship.
	 */
	@IsTest
	private static void shouldAutoLinkContactsToAccount()
	{
		kern.UTIL_ValidationRule.bypassObject('Account');
		List<String> lastNames = new List<String>{ TEST_CONTACT_LAST_NAME, 'Jones' };

		kern.DML_Builder.TransactionResult result =
			new FastStart_DML_DEMO().createAccountWithContacts(TEST_ACCOUNT_NAME, lastNames);

		Assert.isTrue(result.isSuccess(), 'Transaction should succeed');
		Assert.areEqual(3, result.getSuccessCount(), 'Should insert 1 Account + 2 Contacts');

		Id accountId = result.getInsertedIds()[0];

		List<Contact> contacts = kern.QRY_Builder.selectFrom(Contact.SObjectType)
			.fields(new List<SObjectField>{ Contact.LastName, Contact.AccountId })
			.condition(Contact.AccountId).equals(accountId)
			.toList();

		Assert.areEqual(2, contacts.size(), 'Both Contacts should reference the Account');

		for(Contact eachContact : contacts)
		{
			Assert.areEqual(accountId, eachContact.AccountId, 'Contact AccountId should match Account Id');
		}
	}

	/**
	 * @description Verifies that the transaction succeeds with an empty contact list,
	 * inserting only the Account.
	 */
	@IsTest
	private static void shouldCreateAccountWithNoContacts()
	{
		kern.UTIL_ValidationRule.bypassObject('Account');
		kern.DML_Builder.TransactionResult result =
			new FastStart_DML_DEMO().createAccountWithContacts(TEST_ACCOUNT_NAME, new List<String>());

		Assert.isTrue(result.isSuccess(), 'Transaction should succeed');
		Assert.areEqual(1, result.getSuccessCount(), 'Should insert only the Account');
		Assert.areEqual(1, result.getInsertedIds().size(), 'Should return exactly one inserted Id');
	}

	/**
	 * @description Verifies that partial-success mode saves valid Accounts and reports failures
	 * for invalid ones without rolling back the entire batch.
	 */
	@IsTest
	private static void shouldReportPartialFailuresWithoutRollback()
	{
		kern.UTIL_ValidationRule.bypassObject('Account');
		Account validAccount = (Account)kern.TST_Builder.of(Account.SObjectType)
			.withOverride(Account.Name, 'Valid Account')
			.withoutInsertion()
			.build();

		Account invalidAccount = (Account)kern.TST_Builder.of(Account.SObjectType)
			.withOverride(Account.Name, null)
			.withoutInsertion()
			.build();

		List<Account> mixedAccounts = new List<Account>{ validAccount, invalidAccount };

		kern.DML_Builder.TransactionResult result =
			new FastStart_DML_DEMO().tryBulkInsertAccounts(mixedAccounts);

		Assert.isFalse(result.isSuccess(), 'Overall result should reflect the failure');
		Assert.isTrue(result.getFailureCount() > 0, 'Should report at least one failure');
		Assert.isTrue(result.getSuccessCount() > 0, 'Valid record should have been saved');
		Assert.isFalse(result.getErrors().isEmpty(), 'Should expose Database.Error entries');
	}
}
