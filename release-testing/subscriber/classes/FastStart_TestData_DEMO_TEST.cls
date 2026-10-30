// SPDX-License-Identifier: Apache-2.0
/**
 * @description Unit tests for FastStart_TestData_DEMO. They show TST_Builder saving real records, and TST_Mock answering a
 * query with records that are never saved to the database.
 *
 * @see FastStart_TestData_DEMO
 *
 * @author your.name@company.com
 *
 * @group Fast Start Demos
 *
 * @date May 2026, October 2026
 */
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest(seeAllData=false isParallel=true)
private class FastStart_TestData_DEMO_TEST
{
	/**
	 * @description Industry value used across insert-based tests.
	 */
	private static final String INDUSTRY_TECH = 'Technology';

	/**
	 * @description Industry value used for the mock-based count test.
	 */
	private static final String INDUSTRY_FINANCE = 'Finance';

	/**
	 * @description Verifies that TST_Builder inserts records that are visible to a real SOQL count.
	 * Demonstrates: .withOverride() + .withCount() + .buildList() with a real DML insert.
	 */
	@IsTest
	private static void shouldCountRealInsertedAccounts()
	{
		kern.UTIL_ValidationRule.bypassObject('Account');
		kern.TST_Builder.of(Account.SObjectType)
				.withOverride(Account.Industry, INDUSTRY_TECH)
				.withCount(5)
				.buildList();

		Integer result = FastStart_TestData_DEMO.countAccountsByIndustry(INDUSTRY_TECH);

		Assert.areEqual(5, result, 'Count should match the 5 inserted Technology accounts');
	}

	/**
	 * @description Verifies that TST_Builder bulk-inserts records with cycling values and that
	 * each build() call produces a persisted record with a real Id.
	 * Demonstrates: .withCycle() + .withCount() + .buildList() return values.
	 */
	@IsTest
	private static void shouldBuildListWithCyclingIndustryValues()
	{
		kern.UTIL_ValidationRule.bypassObject('Account');
		List<SObject> records = kern.TST_Builder.of(Account.SObjectType)
				.withCycle(Account.Industry, new List<Object> {INDUSTRY_TECH, INDUSTRY_FINANCE})
				.withCount(4)
				.buildList();

		Assert.areEqual(4, records.size(), 'buildList should return 4 records');

		for(SObject record : records)
		{
			Assert.isNotNull(record.Id, 'Each record should have a real database Id after buildList()');
		}

		Assert.areEqual(2, FastStart_TestData_DEMO.countAccountsByIndustry(INDUSTRY_TECH), 'Should have 2 Technology accounts');
		Assert.areEqual(2, FastStart_TestData_DEMO.countAccountsByIndustry(INDUSTRY_FINANCE), 'Should have 2 Finance accounts');
	}

	/**
	 * @description Verifies that TST_Mock registers a Finance account without DML so that the
	 * QRY_Builder-backed count returns 1 without touching the database.
	 * Shows that TST_Mock.of().withOverride().build() registers the mock record by itself, with no extra call.
	 */
	@IsTest
	private static void shouldCountMockedAccountWithoutDml()
	{
		kern.TST_Mock.of(Account.SObjectType)
				.withOverride(Account.Industry, INDUSTRY_FINANCE)
				.build();

		Integer result = FastStart_TestData_DEMO.countAccountsByIndustry(INDUSTRY_FINANCE);

		Assert.areEqual(1, result, 'Mock-registered Finance account should be returned by QRY_Builder count');
	}

	/** @description Verifies an in-memory record does not affect the database count. */
	@IsTest
	private static void shouldReturnZeroWhenNoMatchingAccounts()
	{
		kern.TST_Builder.of(Account.SObjectType)
				.withOverride(Account.Industry, INDUSTRY_TECH)
				.withoutInsertion()
				.build();

		Integer result = FastStart_TestData_DEMO.countAccountsByIndustry(INDUSTRY_TECH);

		Assert.areEqual(0, result, 'An in-memory record is not saved, so the database count should be 0');
	}
}
