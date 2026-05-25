// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Unit tests for SEL_LoginHistory selector.
 *
 * @see SEL_LoginHistory
 *
 * @author Jason van Beukering
 *
 * @group Selectors
 *
 * @date February 2026, May 2026
 */
@IsTest(SeeAllData=false IsParallel=true)
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
private class SEL_LoginHistory_TEST
{
	/**
	 * @description Tests that findByLoginTime returns an IF_Queryable.
	 */
	@IsTest
	private static void shouldFindByLoginTime()
	{
		IF_Queryable result = new SEL_LoginHistory().findByLoginTime(Datetime.now().addDays(-1));

		Assert.isNotNull(result, 'Should return an IF_Queryable');
	}

	/**
	 * @description Tests that findByLoginTime handles null fromLoginTime.
	 */
	@IsTest
	private static void shouldHandleNullFromLoginTime()
	{
		IF_Queryable result = new SEL_LoginHistory().findByLoginTime(null);

		Assert.isNotNull(result, 'Should return an IF_Queryable with null input');
	}
}