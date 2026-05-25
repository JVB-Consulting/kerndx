// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Unit tests for SEL_Profile selector.
 *
 * @see SEL_Profile
 *
 * @author Jason van Beukering
 *
 * @group Selectors
 *
 * @date February 2026, May 2026
 */
@IsTest(SeeAllData=false IsParallel=true)
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
private class SEL_Profile_TEST
{
	/**
	 * @description Tests that findByName returns the correct profile.
	 */
	@IsTest
	private static void shouldFindByName()
	{
		Profile result = new SEL_Profile().findByName(SEL_Profile.PROFILE_SYSTEM_ADMIN);

		Assert.isNotNull(result, 'System Administrator profile should exist');
		Assert.areEqual(SEL_Profile.PROFILE_SYSTEM_ADMIN, result.Name, 'Should return the correct profile');
	}

	/**
	 * @description Tests that findByName returns cached result on subsequent calls.
	 */
	@IsTest
	private static void shouldReturnCachedProfile()
	{
		SEL_Profile selector = new SEL_Profile();

		Profile firstCall = selector.findByName(SEL_Profile.PROFILE_SYSTEM_ADMIN);
		Profile secondCall = selector.findByName(SEL_Profile.PROFILE_SYSTEM_ADMIN);

		Assert.areEqual(firstCall.Id, secondCall.Id, 'Should return same profile from cache');
	}
}