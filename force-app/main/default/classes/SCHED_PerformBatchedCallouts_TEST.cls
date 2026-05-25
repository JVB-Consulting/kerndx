// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Test class to check behavior of SCHED_PerformBatchedCallouts
 *
 * @see SCHED_PerformBatchedCallouts
 *
 * @author Jason van Beukering
 *
 * @group Web Services
 *
 * @date February 2026, May 2026
 */
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest(SeeAllData=false IsParallel=false)
private class SCHED_PerformBatchedCallouts_TEST
{
	/**
	 * @description Test method to test the Schedule job
	 */
	@IsTest
	private static void runSchedule()
	{
		TST_Builder.of(ApiCall__c.SObjectType)
				.withOverrides(new Map<SObjectField, Object>
				{
						ApiCall__c.ServiceName__c => API_PostExample.class.getName(),
						ApiCall__c.TriggeringRecordId__c => UserInfo.getUserId(),
						ApiCall__c.Direction__c => SEL_ApiCall.TYPE_OUTBOUND,
						ApiCall__c.Status__c => SEL_ApiCall.STATUS_BATCHED
				}).build();

		Test.startTest();

		ScheduledJob__c scheduler = TST_Factory.insertScheduledJob(SCHED_PerformBatchedCallouts.class.getName());

		scheduler = (ScheduledJob__c)new SEL_ScheduledJob().findById(scheduler.Id);

		Test.stopTest();

		Assert.isNotNull(scheduler.ScheduledJobId__c, SCHED_PerformBatchedCallouts.class.getName() + ' was not started');
	}
}