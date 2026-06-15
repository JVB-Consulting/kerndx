// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Counts Account records by Industry. Used as a minimal real class so that
 * FastStart_TestData_DEMO_TEST has a production method to exercise with TST_Builder and TST_Mock.
 *
 * @see FastStart_TestData_DEMO_TEST
 *
 * @author your.name@company.com
 *
 * @group Fast Start Demos
 *
 * @date May 2026
 */
public with sharing class FastStart_TestData_DEMO
{
	/**
	 * @description Returns the number of Account records whose Industry field matches the given value.
	 *
	 * @param industry The Industry picklist value to filter on.
	 *
	 * @return The count of matching Account records.
	 */
	public static Integer countAccountsByIndustry(String industry)
	{
		return kern.QRY_Builder.selectFrom(Account.SObjectType)
				.condition(Account.Industry).equals(industry)
				.count();
	}
}
