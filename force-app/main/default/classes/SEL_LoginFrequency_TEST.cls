// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Unit tests for SEL_LoginFrequency selector.
 *
 * @see SEL_LoginFrequency
 *
 * @author Jason van Beukering
 *
 * @group Selectors
 *
 * @date February 2026, May 2026
 */
@IsTest(SeeAllData=false IsParallel=true)
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
private class SEL_LoginFrequency_TEST
{
	/**
	 * @description Tests that findByUserIdAndLoginMonth executes without error.
	 */
	@IsTest
	private static void shouldFindByUserIdAndLoginMonth()
	{
		List<LoginFrequency__c> results = new SEL_LoginFrequency().findByUserIdAndLoginMonth(new Set<String> {'test'});

		Assert.isNotNull(results, 'Should return a list');
	}

	/**
	 * @description Tests that findByUserIdAndLoginMonth handles empty set.
	 */
	@IsTest
	private static void shouldHandleEmptySet()
	{
		List<LoginFrequency__c> results = new SEL_LoginFrequency().findByUserIdAndLoginMonth(new Set<String>());

		Assert.isNotNull(results, 'Should return an empty list');
	}

	/**
	 * @description Tests that getAll executes without error.
	 */
	@IsTest
	private static void shouldGetAll()
	{
		List<LoginFrequency__c> results = new SEL_LoginFrequency().getAll();

		Assert.isNotNull(results, 'Should return a list');
	}
}