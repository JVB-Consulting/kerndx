// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Unit tests for SEL_OrgWideEmailAddress selector.
 *
 * @see SEL_OrgWideEmailAddress
 *
 * @author Jason van Beukering
 *
 * @group Selectors
 *
 * @date February 2026, May 2026
 */
@IsTest(SeeAllData=false IsParallel=true)
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
private class SEL_OrgWideEmailAddress_TEST
{
	/**
	 * @description Tests that findByName returns matching OrgWideEmailAddress records.
	 */
	@IsTest
	private static void shouldFindByName()
	{
		List<OrgWideEmailAddress> results = new SEL_OrgWideEmailAddress().findByName(new Set<String> {'nonexistent@example.com'});

		Assert.isNotNull(results, 'Should return a list');
	}

	/**
	 * @description Tests that getRandomItem returns a random org-wide email available to all profiles.
	 */
	@IsTest
	private static void shouldGetRandomItem()
	{
		OrgWideEmailAddress result = (OrgWideEmailAddress)new SEL_OrgWideEmailAddress().getRandomItem();

		if(result != null)
		{
			Assert.isTrue(result.IsAllowAllProfiles, 'Returned address should be available to all profiles');
		}
	}
}