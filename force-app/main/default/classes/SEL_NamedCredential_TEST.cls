// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Unit tests for SEL_NamedCredential selector.
 *
 * @see SEL_NamedCredential
 *
 * @author Jason van Beukering
 *
 * @group Selectors
 *
 * @date February 2026, May 2026
 */
@IsTest(SeeAllData=false IsParallel=true)
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
private class SEL_NamedCredential_TEST
{
	/**
	 * @description Tests that findByName executes without error for a simple name.
	 */
	@IsTest
	private static void shouldFindBySimpleName()
	{
		NamedCredential result = new SEL_NamedCredential().findByName('NonExistentCredential');

		Assert.isNull(result, 'Should return null for non-existent credential');
	}

	/**
	 * @description Tests that findByName executes without error for a namespaced name.
	 */
	@IsTest
	private static void shouldFindByNamespacedName()
	{
		NamedCredential result = new SEL_NamedCredential().findByName('kern__NonExistentCredential');

		Assert.isNull(result, 'Should return null for non-existent namespaced credential');
	}
}