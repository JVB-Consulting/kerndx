// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Unit tests for SVC_AccountOnboarding.
 *
 * @see SVC_AccountOnboarding
 *
 * @author your.name@company.com
 *
 * @group Services
 *
 * @date February 2026, May 2026
 */
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest(IsParallel=true)
private class SVC_AccountOnboarding_TEST
{
	/**
	 * @description Tests that an Account is created with Contacts and an Opportunity.
	 */
	@IsTest
	private static void shouldCreateAccountWithRelatedRecords()
	{
		kern.UTIL_ValidationRule.bypassObject('Account');
		List<String> contactLastNames = new List<String> {'Smith', 'Jones'};

		kern.DML_Builder.TransactionResult result =
				new SVC_AccountOnboarding().createAccount('Test Corp', contactLastNames, 'Test Deal');

		Assert.isTrue(result.isSuccess(), 'Transaction should succeed');
		Assert.areEqual(4, result.getSuccessCount(), 'Should insert 4 records (1 Account + 1 Opportunity + 2 Contacts)');

		// Verify parent-child relationships using QRY_Builder
		List<Contact> contacts = kern.QRY_Builder.selectFrom(Contact.SObjectType)
				.fields(new List<SObjectField> {Contact.LastName, Contact.AccountId})
				.condition(Contact.AccountId).equals(result.getInsertedIds()[0])
				.toList();
		Assert.areEqual(2, contacts.size(), 'Should create two Contacts');

		List<Opportunity> opportunities = kern.QRY_Builder.selectFrom(Opportunity.SObjectType)
				.fields(new List<SObjectField> {Opportunity.Name, Opportunity.AccountId})
				.condition(Opportunity.AccountId).equals(result.getInsertedIds()[0])
				.toList();
		Assert.areEqual(1, opportunities.size(), 'Should create one Opportunity');
		Assert.areEqual('Test Deal', opportunities[0].Name, 'Opportunity name should match');
	}

	/**
	 * @description Tests that the transaction result contains the inserted IDs.
	 */
	@IsTest
	private static void shouldReturnInsertedIds()
	{
		kern.UTIL_ValidationRule.bypassObject('Account');
		kern.DML_Builder.TransactionResult result =
				new SVC_AccountOnboarding().createAccount('ID Test Corp', new List<String> {'Doe'}, 'ID Deal');

		Assert.isTrue(result.isSuccess(), 'Transaction should succeed');
		List<Id> insertedIds = result.getInsertedIds();
		Assert.areEqual(3, insertedIds.size(), 'Should return 3 inserted IDs');
		Assert.isTrue(result.getErrors().isEmpty(), 'Should have no errors');
	}

	/**
	 * @description Tests that the service handles an empty contact list.
	 */
	@IsTest
	private static void shouldCreateAccountWithNoContacts()
	{
		kern.UTIL_ValidationRule.bypassObject('Account');
		kern.DML_Builder.TransactionResult result =
				new SVC_AccountOnboarding().createAccount('Solo Corp', new List<String>(), 'Solo Deal');

		Assert.isTrue(result.isSuccess(), 'Transaction should succeed');
		Assert.areEqual(2, result.getSuccessCount(), 'Should insert 2 records (1 Account + 1 Opportunity)');

		List<Contact> contacts = kern.QRY_Builder.selectFrom(Contact.SObjectType)
				.fields(new List<SObjectField> {Contact.LastName})
				.condition(Contact.AccountId).equals(result.getInsertedIds()[0])
				.toList();
		Assert.isTrue(contacts.isEmpty(), 'Should have no Contacts');
	}
}
