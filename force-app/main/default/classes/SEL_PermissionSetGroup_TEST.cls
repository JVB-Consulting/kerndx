// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Unit tests for SEL_PermissionSetGroup selector.
 *
 * @see SEL_PermissionSetGroup
 *
 * @author Jason van Beukering
 *
 * @group Selectors
 *
 * @date February 2026, May 2026
 */
@IsTest(SeeAllData=false IsParallel=true)
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
private class SEL_PermissionSetGroup_TEST
{
	/**
	 * @description Tests that findByName with an empty set returns a non-null empty list.
	 */
	@IsTest
	private static void shouldFindByNameWithEmptySet()
	{
		List<PermissionSetGroup> results = new SEL_PermissionSetGroup().findByName(new Set<String>());

		Assert.isNotNull(results, 'Should return an empty list');
	}
}