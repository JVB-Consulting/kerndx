// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Unit tests for SEL_FieldSetGroup selector.
 *
 * @see SEL_FieldSetGroup
 *
 * @author Jason van Beukering
 *
 * @group Selectors
 *
 * @date February 2026, May 2026
 */
@IsTest(SeeAllData=false IsParallel=true)
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
private class SEL_FieldSetGroup_TEST
{
	/**
	 * @description Tests that findByDeveloperName executes without error.
	 */
	@IsTest
	private static void shouldFindByDeveloperName()
	{
		FieldSetGroup__mdt result = new SEL_FieldSetGroup().findByDeveloperName('NonExistentName');

		Assert.isTrue(result == null, 'Should return null for non-existent name');
	}

	/**
	 * @description Tests that getAll executes without error.
	 */
	@IsTest
	private static void shouldGetAll()
	{
		List<FieldSetGroup__mdt> results = new SEL_FieldSetGroup().getAll();

		Assert.isNotNull(results, 'Should return a list');
	}
}