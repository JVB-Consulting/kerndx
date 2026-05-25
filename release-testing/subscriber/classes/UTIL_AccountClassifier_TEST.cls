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
 * @date February 2026, May 2026
 */
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest(IsParallel=true)
private class UTIL_AccountClassifier_TEST
{
	@IsTest
	private static void shouldClassifyAsUnclassifiedWhenNoIndustry()
	{
		Account record = (Account)kern.TST_Builder.of(Account.SObjectType)
				.withoutInsertion()
				.build();
		String result = UTIL_AccountClassifier.classify(record);
		Assert.areEqual(UTIL_AccountClassifier.UNCLASSIFIED, result, 'Should be Unclassified when Industry is blank');
	}

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

	@IsTest
	private static void shouldCreateAccountWithChildren()
	{
		kern.UTIL_ValidationRule.bypassObject('Account');
		Account parent = (Account)kern.TST_Builder.of(Account.SObjectType)
				.withOverride(Account.Name, 'Parent Corp')
				.withOverride(Account.Industry, 'Technology')
				.withChildren(Contact.SObjectType, 3)
				.build();

		Assert.isNotNull(parent.Id, 'Parent should be inserted');

		List<Contact> children = kern.QRY_Builder.selectFrom(Contact.SObjectType)
				.fields(new List<SObjectField> {Contact.LastName, Contact.AccountId})
				.condition(Contact.AccountId).equals(parent.Id)
				.toList();
		Assert.areEqual(3, children.size(), 'Should create 3 child Contacts');

		String result = UTIL_AccountClassifier.classify(parent);
		Assert.areEqual(UTIL_AccountClassifier.STANDARD, result, 'Parent should be classified');
	}
}
