// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Test Class for SCHED_ProcessLoginHistory
 *
 * @see SCHED_ProcessLoginHistory
 *
 * @author Jason van Beukering
 *
 * @group Schedulables
 *
 * @date February 2026, May 2026
 */
@IsTest(SeeAllData=false IsParallel=false)
private class SCHED_ProcessLoginHistory_TEST
{
	/**
	 * @description Test method to test the Schedule job
	 */
	@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
	@IsTest
	private static void runSchedule()
	{
		TST_Builder.of(ScheduleSetting__c.SObjectType)
				.withOverride(ScheduleSetting__c.Name, PROC_LoginFrequencyAggregator.SETTING_NAME)
				.withOverride(ScheduleSetting__c.LastSuccessfulRunTime__c, UTIL_Random.randomDateTime())
				.build();

		Test.startTest();

		ScheduledJob__c scheduler = TST_Factory.insertScheduledJob(SCHED_ProcessLoginHistory.class.getName());

		scheduler = (ScheduledJob__c)new SEL_ScheduledJob().findById(scheduler.Id);

		Test.stopTest();

		Assert.isNotNull(scheduler.ScheduledJobId__c, 'SCHED_ProcessLoginHistory was not started');
	}
}