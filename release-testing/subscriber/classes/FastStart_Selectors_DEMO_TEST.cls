// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Unit tests for FastStart_Selectors_DEMO.
 * Covers the inherited findById method and both custom query methods.
 * All SObject records are created via kern.TST_Builder -- never via bare constructor.
 *
 * @see FastStart_Selectors_DEMO
 *
 * @author your.name@company.com
 *
 * @group Fast Start Demos
 *
 * @date May 2026
 */
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest(SeeAllData=false IsParallel=true)
private class FastStart_Selectors_DEMO_TEST
{
	/** @description Industry value used across tests. */
	private static final String INDUSTRY_TECH = 'Technology';

	/** @description Industry value for negative/contrast tests. */
	private static final String INDUSTRY_FINANCE = 'Finance';

	/** @description Annual revenue used for the aggregate test account. */
	private static final Decimal TEST_REVENUE = 500000;

	/**
	 * @description Tests that the inherited findById returns the correct Account record,
	 * including default fields defined by getFields().
	 */
	@IsTest
	private static void shouldReturnAccountByIdWithDefaultFields()
	{
		kern.UTIL_ValidationRule.bypassObject('Account');
		Account inserted = (Account)kern.TST_Builder.of(Account.SObjectType)
			.withOverride(Account.Name, 'Acme Corp')
			.withOverride(Account.Industry, INDUSTRY_TECH)
			.withOverride(Account.AnnualRevenue, TEST_REVENUE)
			.build();

		Account result = (Account)new FastStart_Selectors_DEMO().findById(inserted.Id);

		Assert.isNotNull(result, 'findById should return a record');
		Assert.areEqual(inserted.Id, result.Id, 'Should return the correct account');
		Assert.areEqual(INDUSTRY_TECH, result.Industry, 'Industry should be in default fields');
		Assert.areEqual(TEST_REVENUE, result.AnnualRevenue, 'AnnualRevenue should be in default fields');
	}

	/**
	 * @description Tests that findByIndustry returns only accounts matching the given industry.
	 */
	@IsTest
	private static void shouldReturnMatchingAccountsByIndustry()
	{
		kern.UTIL_ValidationRule.bypassObject('Account');
		kern.TST_Builder.of(Account.SObjectType)
			.withOverride(Account.Name, 'Tech Co')
			.withOverride(Account.Industry, INDUSTRY_TECH)
			.build();
		kern.TST_Builder.of(Account.SObjectType)
			.withOverride(Account.Name, 'Bank Co')
			.withOverride(Account.Industry, INDUSTRY_FINANCE)
			.build();

		List<Account> results = new FastStart_Selectors_DEMO().findByIndustry(INDUSTRY_TECH);

		Assert.areEqual(1, results.size(), 'Should return only the Technology account');
		Assert.areEqual('Tech Co', results[0].Name, 'Should return the correct account');
	}

	/**
	 * @description Tests that findByIndustry returns an empty list when no accounts match.
	 */
	@IsTest
	private static void shouldReturnEmptyListWhenIndustryHasNoAccounts()
	{
		kern.UTIL_ValidationRule.bypassObject('Account');
		kern.TST_Builder.of(Account.SObjectType)
			.withOverride(Account.Name, 'Tech Co')
			.withOverride(Account.Industry, INDUSTRY_TECH)
			.build();

		List<Account> results = new FastStart_Selectors_DEMO().findByIndustry(INDUSTRY_FINANCE);

		Assert.isTrue(results.isEmpty(), 'Should return empty list when industry has no accounts');
	}

	/** @description Aggregate alias for SUM(AnnualRevenue) produced by QRY_Builder. */
	private static final String ALIAS_SUM_REVENUE = 'sum_AnnualRevenue';

	/** @description Aggregate field name for the grouped Industry column. */
	private static final String FIELD_INDUSTRY = 'Industry';

	/**
	 * @description Tests that revenueByIndustry returns aggregate rows with the correct Industry
	 * and summed AnnualRevenue.
	 */
	@IsTest
	private static void shouldReturnRevenueAggregateByIndustry()
	{
		kern.UTIL_ValidationRule.bypassObject('Account');
		kern.TST_Builder.of(Account.SObjectType)
			.withOverride(Account.Name, 'Tech A')
			.withOverride(Account.Industry, INDUSTRY_TECH)
			.withOverride(Account.AnnualRevenue, 200000)
			.build();
		kern.TST_Builder.of(Account.SObjectType)
			.withOverride(Account.Name, 'Tech B')
			.withOverride(Account.Industry, INDUSTRY_TECH)
			.withOverride(Account.AnnualRevenue, 300000)
			.build();

		List<kern.QRY_Builder.AggregateRow> rows = new FastStart_Selectors_DEMO().revenueByIndustry();

		Assert.areEqual(1, rows.size(), 'Should return exactly one aggregate row — only Technology was inserted');
		kern.QRY_Builder.AggregateRow row = rows[0];
		Assert.areEqual(INDUSTRY_TECH, row.getString(FIELD_INDUSTRY), 'Industry should be Technology');
		Assert.areEqual(500000, row.getDecimal(ALIAS_SUM_REVENUE), 'Summed revenue should be 500000 (200000 + 300000)');
	}
}
