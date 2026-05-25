// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Unit tests for SEL_PushTopic selector.
 *
 * @see SEL_PushTopic
 *
 * @author Jason van Beukering
 *
 * @group Selectors
 *
 * @date February 2026, May 2026
 */
@IsTest(SeeAllData=false IsParallel=true)
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
private class SEL_PushTopic_TEST
{
	/**
	 * @description Tests that getAll executes without error.
	 */
	@IsTest
	private static void shouldGetAll()
	{
		List<PushTopic> results = new SEL_PushTopic().getAll();

		Assert.isNotNull(results, 'Should return a list');
	}
}