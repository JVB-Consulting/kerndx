// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Unit tests for SEL_PlatformEventUsageMetric selector.
 *
 * @see SEL_PlatformEventUsageMetric
 *
 * @author Jason van Beukering
 *
 * @group Selectors
 *
 * @date February 2026, May 2026
 */
@IsTest(SeeAllData=false IsParallel=true)
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
private class SEL_PlatformEventUsageMetric_TEST
{
	/**
	 * @description Tests that getAllOrderByStartDate executes without error.
	 */
	@IsTest
	private static void shouldGetAllOrderByStartDate()
	{
		List<PlatformEventUsageMetric> results = new SEL_PlatformEventUsageMetric().getAllOrderByStartDate();

		Assert.isNotNull(results, 'Should return a list');
	}
}