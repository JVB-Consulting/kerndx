// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Unit tests for UTIL_AccountClassifier.
 *
 * @see UTIL_AccountClassifier
 *
 * @author your.name@company.com
 *
 * @group Utilities
 *
 * @date February 2026, October 2026
 */
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest(seeAllData=false isParallel=true)
private class UTIL_AccountClassifier_TEST
{
	/**
	 * @description How many child Contacts the parent Account is built with.
	 */
	private static final Integer CHILD_CONTACT_COUNT = 3;

	/**
	 * @description An Account with no Industry is Unclassified. Industry is checked first, so without it nothing else
	 * about the Account is looked at.
	 */
	@IsTest
	private static void shouldClassifyAsUnclassifiedWhenNoIndustry()
	{
		Account record = (Account)kern.TST_Builder.of(Account.SObjectType)
				.withoutInsertion()
				.build();
		String result = UTIL_AccountClassifier.classify(record);
		Assert.areEqual(UTIL_AccountClassifier.UNCLASSIFIED, result, 'Should be Unclassified when Industry is blank');
	}

	/**
	 * @description An Account with an Industry and an annual revenue above the Enterprise threshold (five million here,
	 * against a threshold of one million) is Enterprise.
	 */
	@IsTest
	private static void shouldClassifyAsEnterpriseWhenHighRevenue()
	{
		Account record = (Account)kern.TST_Builder.of(Account.SObjectType)
				.withOverride(Account.Industry, 'Technology')
				.withOverride(Account.AnnualRevenue, 5000000)
				.withoutInsertion()
				.build();
		String result = UTIL_AccountClassifier.classify(record);
		Assert.areEqual(UTIL_AccountClassifier.ENTERPRISE, result, 'Should be Enterprise for high revenue');
	}

	/**
	 * @description An Account with an Industry and an annual revenue below the Enterprise threshold (500,000 here) is
	 * Standard.
	 */
	@IsTest
	private static void shouldClassifyAsStandard()
	{
		Account record = (Account)kern.TST_Builder.of(Account.SObjectType)
				.withOverride(Account.Industry, 'Finance')
				.withOverride(Account.AnnualRevenue, 500000)
				.withoutInsertion()
				.build();
		String result = UTIL_AccountClassifier.classify(record);
		Assert.areEqual(UTIL_AccountClassifier.STANDARD, result, 'Should be Standard for normal revenue');
	}

	/**
	 * @description Six Accounts whose Industry cycles through three values, and which have no revenue, are all Standard:
	 * any Industry is enough, and an Account with no revenue is never Enterprise. Also shows withCycle and withCount on
	 * kern.TST_Builder, which build several varied records in one call.
	 */
	@IsTest
	private static void shouldClassifyMultipleAccountsWithCycling()
	{
		List<SObject> records = kern.TST_Builder.of(Account.SObjectType)
				.withCycle(Account.Industry, new List<Object> {'Technology', 'Finance', 'Healthcare'})
				.withCount(6)
				.withoutInsertion()
				.buildList();
		for(SObject record : records)
		{
			String result = UTIL_AccountClassifier.classify((Account)record);
			Assert.areEqual(UTIL_AccountClassifier.STANDARD, result, 'All should be Standard (no revenue set)');
		}
	}

	/**
	 * @description A parent Account with an Industry and no revenue, built in memory with three child Contacts, classifies
	 * as Standard: the children make no difference to the classification. Shows withChildren on kern.TST_Builder with
	 * made-up Ids, which puts the Contacts in the parent's Contacts list without saving anything, so no validation rule in
	 * the org can stop the test.
	 */
	@IsTest
	private static void shouldClassifyAnAccountBuiltWithChildContacts()
	{
		Account parent = (Account)kern.TST_Builder.of(Account.SObjectType)
				.withOverride(Account.Industry, 'Technology')
				.withChildren(Contact.SObjectType, CHILD_CONTACT_COUNT)
				.withoutInsertion(true)
				.build();

		Assert.areEqual(CHILD_CONTACT_COUNT, parent.Contacts.size(), 'Expected ' + CHILD_CONTACT_COUNT + ' child Contacts, got ' + parent.Contacts.size());

		String result = UTIL_AccountClassifier.classify(parent);

		Assert.areEqual(UTIL_AccountClassifier.STANDARD, result, 'Expected Standard for an Account with an Industry and no revenue, got ' + result);
	}
}
