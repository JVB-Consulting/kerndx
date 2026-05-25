// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Unit tests for SEL_StreamingChannel selector.
 *
 * @see SEL_StreamingChannel
 *
 * @author Jason van Beukering
 *
 * @group Selectors
 *
 * @date February 2026, May 2026
 */
@IsTest(SeeAllData=false IsParallel=true)
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
private class SEL_StreamingChannel_TEST
{
	/**
	 * @description Tests that getAllOrderByName executes without error.
	 */
	@IsTest
	private static void shouldGetAllOrderByName()
	{
		List<StreamingChannel> results = new SEL_StreamingChannel().getAllOrderByName();

		Assert.isNotNull(results, 'Should return a list');
	}

	/**
	 * @description Tests that findByName executes without error.
	 */
	@IsTest
	private static void shouldFindByName()
	{
		StreamingChannel result = new SEL_StreamingChannel().findByName('NonExistentChannel');

		Assert.isNull(result, 'Should return null for non-existent channel');
	}
}