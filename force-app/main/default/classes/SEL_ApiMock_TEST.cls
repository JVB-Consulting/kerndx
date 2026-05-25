// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Unit tests for SEL_ApiMock selector.
 *
 * @see SEL_ApiMock
 *
 * @author Jason van Beukering
 *
 * @group Web Services
 *
 * @date February 2026, May 2026
 */
@IsTest(SeeAllData=false IsParallel=true)
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
private class SEL_ApiMock_TEST
{
	/**
	 * @description Tests that findByApiSetting returns empty list when no matching records exist.
	 */
	@IsTest
	private static void shouldReturnEmptyForNonExistentApiSetting()
	{
		List<ApiMock__mdt> results = new SEL_ApiMock().findByApiSetting('NonExistent_Setting');

		Assert.isTrue(results.isEmpty(), 'Should return empty list for non-existent API setting');
	}
}