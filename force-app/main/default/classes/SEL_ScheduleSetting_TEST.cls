// SPDX-License-Identifier: Apache-2.0
/**
 * @description Tests the behavior of the {@link SEL_ScheduleSetting} class.
 *
 * @see SEL_ScheduleSetting
 *
 * @author Jason van Beukering
 *
 * @group Schedulables
 *
 * @date February 2026, October 2026
 */
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest(seeAllData=false isParallel=true)
private class SEL_ScheduleSetting_TEST
{
	/**
	 * @description Tests that getScheduleSetting returns null for a non-existent schedule name.
	 *
	 * @see SEL_ScheduleSetting.getScheduleSetting
	 */
	@IsTest
	private static void shouldReturnNullForNonExistentSchedule()
	{
		Test.startTest();

		ScheduleSetting__c result = SEL_ScheduleSetting.getScheduleSetting(UTIL_Random.randomName());

		Test.stopTest();

		Assert.isNull(result, 'Should return null when no matching schedule setting exists');
	}
}