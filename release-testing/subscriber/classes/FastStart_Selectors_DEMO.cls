// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Demonstrates the KernDX selector pattern for the Account object.
 * Extends kern.SEL_Base to inherit findById, findByField, count, exists, and more.
 * Custom methods use the inherited query property -- never QRY_Builder.selectFrom() directly.
 *
 * @see FastStart_Selectors_DEMO_TEST
 *
 * @author your.name@company.com
 *
 * @group Fast Start Demos
 *
 * @date May 2026
 */
public inherited sharing class FastStart_Selectors_DEMO extends kern.SEL_Base
{
	/**
	 * @description Constructs the selector and tells the base class which object to query.
	 */
	public FastStart_Selectors_DEMO()
	{
		super(Account.SObjectType);
	}

	/**
	 * @description Returns the default fields included in every query from this selector.
	 * Uses SObjectField tokens for compile-time validation.
	 *
	 * @return List of Account SObjectField tokens.
	 */
	public override List<SObjectField> getFields()
	{
		return new List<SObjectField>
		{
				Account.Name,
				Account.Industry,
				Account.AnnualRevenue
		};
	}

	/**
	 * @description Finds Account records matching a given industry value.
	 * Uses the inherited query property which is pre-configured with the SObjectType and default fields.
	 *
	 * @param industry The industry picklist value to filter by.
	 *
	 * @return List of Account records in the given industry, ordered by Name ascending.
	 */
	public List<Account> findByIndustry(String industry)
	{
		return query
				.condition(Account.Industry).equals(industry)
				.orderBy(Account.Name).ascending()
				.toList();
	}

	/**
	 * @description Returns aggregate revenue totals grouped by industry.
	 * Uses the inherited query property with groupBy and sum aggregate functions.
	 *
	 * @return List of aggregate rows, each with Industry and the summed AnnualRevenue.
	 */
	public List<kern.QRY_Builder.AggregateRow> revenueByIndustry()
	{
		return query
				.groupBy(Account.Industry)
				.sum(Account.AnnualRevenue)
				.toAggregateList();
	}
}
