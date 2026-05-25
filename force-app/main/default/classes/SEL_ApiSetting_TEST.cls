// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Unit tests for SEL_ApiSetting selector.
 *
 * @see SEL_ApiSetting
 *
 * @author Jason van Beukering
 *
 * @group Web Services
 *
 * @date February 2026, May 2026
 */
@IsTest(SeeAllData=false IsParallel=true)
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
private class SEL_ApiSetting_TEST
{
	/**
	 * @description Tests that findByClassName returns null for non-existent class.
	 */
	@IsTest
	private static void shouldReturnNullForNonExistentClassName()
	{
		ApiSetting__mdt result = new SEL_ApiSetting().findByClassName('NonExistentClass');

		Assert.isNull(result, 'Should return null for non-existent class');
	}

	/**
	 * @description Tests that findActiveInboundRoutes returns a list without errors.
	 */
	@IsTest
	private static void shouldReturnActiveInboundRoutes()
	{
		List<ApiSetting__mdt> results = new SEL_ApiSetting().findActiveInboundRoutes();

		Assert.isNotNull(results, 'Should return a non-null list');
	}

	/**
	 * @description Tests that findActiveByDirection returns a list without errors.
	 */
	@IsTest
	private static void shouldReturnActiveByDirection()
	{
		List<ApiSetting__mdt> results = new SEL_ApiSetting().findActiveByDirection(SEL_ApiSetting.DIRECTION_OUTBOUND);

		Assert.isNotNull(results, 'Should return a non-null list');
	}
}