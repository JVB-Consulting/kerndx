// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Unit tests for FastStart_TestData_DEMO. Demonstrates TST_Builder (real DML),
 * TST_Mock (DML-free query interception), and TST_Factory.newUser() patterns in a subscriber org.
 *
 * @see FastStart_TestData_DEMO
 *
 * @author your.name@company.com
 *
 * @group Fast Start Demos
 *
 * @date May 2026
 */
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest(SeeAllData=false IsParallel=true)
private class FastStart_TestData_DEMO_TEST
{
	/** @description Industry value used across insert-based tests. */
	private static final String INDUSTRY_TECH = 'Technology';

	/** @description Industry value used for the mock-based count test. */
	private static final String INDUSTRY_FINANCE = 'Finance';

	/** @description Industry value that should return zero results. */
	private static final String INDUSTRY_OTHER = 'Education';

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
			.withCycle(Account.Industry, new List<Object>{ INDUSTRY_TECH, INDUSTRY_FINANCE })
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
	 * Demonstrates: TST_Mock.of().withOverride().build() auto-registration semantics.
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

	/**
	 * @description Verifies that a count for an industry with no records (real or mocked) returns zero.
	 * Demonstrates: TST_Builder.withoutInsertion() for in-memory records that do not affect counts.
	 */
	@IsTest
	private static void shouldReturnZeroWhenNoMatchingAccounts()
	{
		kern.TST_Builder.of(Account.SObjectType)
			.withOverride(Account.Industry, INDUSTRY_TECH)
			.withoutInsertion()
			.build();

		Integer result = FastStart_TestData_DEMO.countAccountsByIndustry(INDUSTRY_OTHER);

		Assert.areEqual(0, result, 'In-memory record should not affect the database count for a different industry');
	}
}
