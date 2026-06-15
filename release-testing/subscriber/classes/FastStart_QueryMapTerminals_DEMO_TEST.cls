// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Unit tests for FastStart_QueryMapTerminals_DEMO. Validates each of the four
 * subscriber demo methods against fixture data and confirms cross-namespace access to the
 * `kern.QRY_Builder.Builder` keyed-map terminals.
 *
 * @see FastStart_QueryMapTerminals_DEMO
 *
 * @author your.name@company.com
 *
 * @group Fast Start Demos
 *
 * @date May 2026
 */
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest(SeeAllData=false IsParallel=true)
private class FastStart_QueryMapTerminals_DEMO_TEST
{
	/**
	 * @description Account name used for the parent fixture in every test.
	 */
	private static final String PARENT_ACCOUNT_NAME = 'Demo Map Terminals Account';

	/**
	 * @description Account industry used to verify String-key grouping.
	 */
	private static final String FIXTURE_INDUSTRY = 'Biotechnology';

	/**
	 * @description Contact last names used to verify two-children-per-parent grouping.
	 */
	private static final List<String> CONTACT_LAST_NAMES = new List<String> {'Smith', 'Jones'};

	/**
	 * @description Verifies asMapById on a non-Id field (Contact.AccountId). The first Contact
	 * for each AccountId is returned; subsequent Contacts for the same AccountId are dropped
	 * (per the terminal's "keyed" semantic, distinct from the grouped variant).
	 */
	@IsTest
	private static void shouldReturnContactsKeyedByAccountId()
	{
		kern.UTIL_ValidationRule.bypassObject('Account');
		Account parent = createParentWithContacts();

		Map<Id, SObject> result = new FastStart_QueryMapTerminals_DEMO().contactsKeyedByAccountId();

		Assert.isTrue(result.containsKey(parent.Id), 'Result should contain the parent AccountId');
		Contact keyedContact = (Contact)result.get(parent.Id);
		Assert.areEqual(parent.Id, keyedContact.AccountId, 'Keyed Contact should belong to the parent Account');
	}

	/**
	 * @description Verifies asGroupedMapById on Contact.AccountId. Both Contacts for the same
	 * AccountId should be returned in the value list.
	 */
	@IsTest
	private static void shouldReturnContactsGroupedByAccountId()
	{
		kern.UTIL_ValidationRule.bypassObject('Account');
		Account parent = createParentWithContacts();

		Map<Id, List<Contact>> result = new FastStart_QueryMapTerminals_DEMO().contactsGroupedByAccountId();

		Assert.isTrue(result.containsKey(parent.Id), 'Result should contain the parent AccountId');
		Assert.areEqual(CONTACT_LAST_NAMES.size(), result.get(parent.Id).size(),
				'Both Contacts should be grouped under the parent AccountId');
	}

	/**
	 * @description Verifies asMapByString on Account.Name. The fixture Account should round-trip
	 * keyed by its Name.
	 */
	@IsTest
	private static void shouldReturnAccountsKeyedByName()
	{
		kern.UTIL_ValidationRule.bypassObject('Account');
		Account parent = createParentWithContacts();

		Map<String, SObject> result = new FastStart_QueryMapTerminals_DEMO().accountsKeyedByName();

		Assert.isTrue(result.containsKey(PARENT_ACCOUNT_NAME), 'Result should be keyed by Account.Name');
		Account keyedAccount = (Account)result.get(PARENT_ACCOUNT_NAME);
		Assert.areEqual(parent.Id, keyedAccount.Id, 'Keyed Account should be the fixture');
	}

	/**
	 * @description Verifies asGroupedMapByString on Account.Industry. The fixture Industry value
	 * should be present and contain the fixture Account.
	 */
	@IsTest
	private static void shouldReturnAccountsGroupedByIndustry()
	{
		kern.UTIL_ValidationRule.bypassObject('Account');
		Account parent = createParentWithContacts();

		Map<String, List<Account>> result = new FastStart_QueryMapTerminals_DEMO().accountsGroupedByIndustry();

		Assert.isTrue(result.containsKey(FIXTURE_INDUSTRY), 'Result should contain the fixture Industry');
		Boolean containsFixture = false;
		for(Account eachAccount : result.get(FIXTURE_INDUSTRY))
		{
			if(eachAccount.Id == parent.Id)
			{
				containsFixture = true;
				break;
			}
		}
		Assert.isTrue(containsFixture, 'Grouped Industry value should include the fixture Account');
	}

	/**
	 * @description Test fixture helper. Inserts one Account and two Contacts pointing at it.
	 *
	 * @return The inserted Account record (with Id populated).
	 */
	private static Account createParentWithContacts()
	{
		Account parent = new Account(Name = PARENT_ACCOUNT_NAME, Industry = FIXTURE_INDUSTRY, Phone = '555-0100');
		List<Contact> children = new List<Contact>();
		for(String lastName : CONTACT_LAST_NAMES)
		{
			children.add(new Contact(LastName = lastName));
		}

		kern.DML_Builder dmlTransaction = kern.DML_Builder.newTransaction().doInsert(parent);
		for(Contact eachChild : children)
		{
			dmlTransaction.doInsert(eachChild, Contact.AccountId, parent);
		}
		dmlTransaction.execute();
		return parent;
	}
}
