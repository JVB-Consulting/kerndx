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
 * @date February 2026, August 2026
 */
@IsTest(seeAllData=false isParallel=false)
private class SCHED_ProcessLoginHistory_TEST
{
	/**
	 * @description Test method to test the Schedule job
	 */
	@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
	@IsTest
	private static void runSchedule()
	{
		// The watermark is "now", not a random past instant: the batch reads the org's REAL LoginHistory
		// (platform data a test can neither seed nor purge), so a past watermark makes the batch's row
		// count grow with org age until it spans two chunks and stopTest throws the one-executeBatch rule.
		TST_Builder.of(ScheduleSetting__c.SObjectType)
				.withOverride(ScheduleSetting__c.Name, PROC_LoginFrequencyAggregator.SETTING_NAME)
				.withOverride(ScheduleSetting__c.LastSuccessfulRunTime__c, Datetime.now())
				.build();

		Test.startTest();

		ScheduledJob__c scheduler = TST_Factory.insertScheduledJob(SCHED_ProcessLoginHistory.class.getName());

		scheduler = (ScheduledJob__c)new SEL_ScheduledJob().findById(scheduler.Id);

		Test.stopTest();

		// Driven directly, after the flush: the schedulable's own body must run for the test to mean
		// anything, and a job enqueued here is never executed, so the empty watermark window keeps this
		// deterministic at any org size instead of racing the org's LoginHistory row count. A failure
		// anywhere in the setting read, the login-history query or the launch fails this call.
		new SCHED_ProcessLoginHistory().execute(null);

		Assert.isNotNull(scheduler.ScheduledJobId__c, 'SCHED_ProcessLoginHistory was not started');
	}
}