// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Unit tests for SEL_ScheduledJob selector.
 *
 * @see SEL_ScheduledJob
 *
 * @author Jason van Beukering
 *
 * @group Schedulables
 *
 * @date February 2026, May 2026
 */
@IsTest(SeeAllData=false IsParallel=true)
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs,PMD.EagerlyLoadedDescribeSObjectResult')
private class SEL_ScheduledJob_TEST
{
	/**
	 * @description Tests that the selector constructs and exposes fields correctly.
	 */
	@IsTest
	private static void shouldQueryScheduledJobs()
	{
		List<SObject> results = new SEL_ScheduledJob().toList();

		Assert.isNotNull(results, 'Should execute query successfully');
	}

	/**
	 * @description Tests that findActiveByClassName returns only matching active records.
	 */
	@IsTest
	private static void shouldFindActiveByClassName()
	{
		String targetClassName = SCHED_PurgeRecords.class.getName();

		String paramKey = SCHED_PurgeRecords.REQUIRED_PARAMETER_OBJECT_NAME;

		TST_Mock.register(ScheduledJob__c.SObjectType, new List<ScheduledJob__c>
		{
				TST_Factory.newScheduledJob(targetClassName, new DTO_NameValues(new Map<String, String> {paramKey => LogEntry__c.SObjectType.getDescribe().name})),
				TST_Factory.newScheduledJob('SCHED_ProcessLoginHistory', new DTO_NameValues(new Map<String, String> {paramKey => Foobar__c.SObjectType.getDescribe().name}))
		});

		List<ScheduledJob__c> results = new SEL_ScheduledJob().findActiveByClassName(targetClassName);

		Assert.isFalse(results.isEmpty(), 'Should return results for matching class name');
	}
}