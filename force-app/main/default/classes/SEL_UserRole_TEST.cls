// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Unit tests for SEL_UserRole selector.
 *
 * @see SEL_UserRole
 *
 * @author Jason van Beukering
 *
 * @group Selectors
 *
 * @date February 2026, May 2026
 */
@IsTest(SeeAllData=false IsParallel=true)
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
private class SEL_UserRole_TEST
{
	/**
	 * @description Tests that findAllChildRoles executes without error for empty input.
	 */
	@IsTest
	private static void shouldFindAllChildRolesWithEmptyInput()
	{
		List<UserRole> results = new SEL_UserRole().findAllChildRoles(new Set<Id>());

		Assert.isNotNull(results, 'Should return an empty list');
	}
}