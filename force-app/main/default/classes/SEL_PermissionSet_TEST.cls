// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Unit tests for SEL_PermissionSet selector.
 *
 * @see SEL_PermissionSet
 *
 * @author Jason van Beukering
 *
 * @group Selectors
 *
 * @date February 2026, May 2026
 */
@IsTest(SeeAllData=false IsParallel=true)
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
private class SEL_PermissionSet_TEST
{
	/**
	 * @description Tests that findByName returns null for a non-existent permission set name.
	 */
	@IsTest
	private static void shouldFindByNameWithNonExistentPermissionSet()
	{
		PermissionSet result = new SEL_PermissionSet().findByName('NonExistent_Permission_Set_12345');

		Assert.isNull(result, 'Should return null for non-existent permission set');
	}
}