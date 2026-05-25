// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Test class to check behavior of FLOW_CallApiAsync
 *
 * @see FLOW_CallApiAsync
 *
 * @author Jason van Beukering
 *
 * @group Web Services
 *
 * @date February 2026, May 2026
 */
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest(SeeAllData=false IsParallel=true)
private class FLOW_CallApiAsync_TEST
{
	/**
	 * @description Verifies the default job size stays within the callout governor limit.
	 */
	@IsTest
	private static void shouldDefaultJobSizeWithinCalloutLimit()
	{
		Assert.isTrue(
				FLOW_CallApiAsync.DEFAULT_JOB_SIZE <= FLOW_CallApiAsync.MAXIMUM_CALLOUT_JOB_SIZE,
				'Default job size must not exceed MAXIMUM_CALLOUT_JOB_SIZE'
		);
	}

	/**
	 * @description Verifies MAXIMUM_CALLOUT_JOB_SIZE equals the Salesforce governor limit for callouts per transaction.
	 */
	@IsTest
	private static void shouldMaximumCalloutJobSizeMatchGovernorLimit()
	{
		Assert.areEqual(
				UTIL_Limits.callouts().maximum(),
				FLOW_CallApiAsync.MAXIMUM_CALLOUT_JOB_SIZE,
				'MAXIMUM_CALLOUT_JOB_SIZE should equal the governor callout limit'
		);
	}

	/**
	 * @description Verifies a metadata override above 100 is capped at MAXIMUM_CALLOUT_JOB_SIZE.
	 */
	@IsTest
	private static void shouldCapMetadataOverrideAtCalloutLimit()
	{
		SEL_AsynchronousJobSetting.mockedSetting = new AsynchronousJobSetting__mdt(BatchSize__c = 150);

		Integer jobSize = Math.min(
				SEL_AsynchronousJobSetting.getBatchSize(FLOW_CallApiAsync.class.getName(), FLOW_CallApiAsync.DEFAULT_JOB_SIZE),
				FLOW_CallApiAsync.MAXIMUM_CALLOUT_JOB_SIZE
		);

		Assert.areEqual(FLOW_CallApiAsync.MAXIMUM_CALLOUT_JOB_SIZE, jobSize, 'Job size of 150 should be capped at callout limit');
	}

	/**
	 * @description Verifies a metadata override below the callout limit is used as-is.
	 */
	@IsTest
	private static void shouldAllowMetadataOverrideBelowCalloutLimit()
	{
		SEL_AsynchronousJobSetting.mockedSetting = new AsynchronousJobSetting__mdt(BatchSize__c = 50);

		Integer jobSize = Math.min(
				SEL_AsynchronousJobSetting.getBatchSize(FLOW_CallApiAsync.class.getName(), FLOW_CallApiAsync.DEFAULT_JOB_SIZE),
				FLOW_CallApiAsync.MAXIMUM_CALLOUT_JOB_SIZE
		);

		Assert.areEqual(50, jobSize, 'Job size of 50 should be used as-is');
	}

	/**
	 * @description Verifies a metadata override at exactly 100 is accepted without capping.
	 */
	@IsTest
	private static void shouldAcceptJobSizeAtExactCalloutLimit()
	{
		SEL_AsynchronousJobSetting.mockedSetting = new AsynchronousJobSetting__mdt(BatchSize__c = 100);

		Integer jobSize = Math.min(
				SEL_AsynchronousJobSetting.getBatchSize(FLOW_CallApiAsync.class.getName(), FLOW_CallApiAsync.DEFAULT_JOB_SIZE),
				FLOW_CallApiAsync.MAXIMUM_CALLOUT_JOB_SIZE
		);

		Assert.areEqual(100, jobSize, 'Job size at exactly the callout limit should be accepted');
	}

	/**
	 * @description Verifies the job size can be overridden via AsynchronousJobSetting__mdt.
	 */
	@IsTest
	private static void shouldReadJobSizeFromMetadata()
	{
		SEL_AsynchronousJobSetting.mockedSetting = new AsynchronousJobSetting__mdt(BatchSize__c = 15);

		Integer jobSize = SEL_AsynchronousJobSetting.getBatchSize(FLOW_CallApiAsync.class.getName(), FLOW_CallApiAsync.DEFAULT_JOB_SIZE);

		Assert.areEqual(15, jobSize, 'Should read job size from AsynchronousJobSetting__mdt');
	}

	/**
	 * @description Verifies that items are chunked across multiple Queueable jobs when the job size
	 * is smaller than the total item count. Five items with a job size of 2 should produce 3 Queueables.
	 */
	@IsTest
	private static void shouldChunkItemsAcrossMultipleQueueables()
	{
		SEL_AsynchronousJobSetting.mockedSetting = new AsynchronousJobSetting__mdt(BatchSize__c = 2);

		TST_Builder.of(ApiCall__c.SObjectType)
				.withOverrides(new Map<SObjectField, Object>
				{
						ApiCall__c.ServiceName__c => API_PostExample.class.getName(),
						ApiCall__c.TriggeringRecordId__c => UserInfo.getUserId(),
						ApiCall__c.Direction__c => SEL_ApiCall.TYPE_OUTBOUND,
						ApiCall__c.Status__c => SEL_ApiCall.STATUS_BATCHED
				}).withCount(3).buildList();

		Test.startTest();

		FLOW_CallApiAsync.invokeApiCallAsynchronously(new SEL_ApiCall().findByBatchedOutbound());

		Assert.areEqual(2, UTIL_Limits.queueableJobs().used(), 'Three items with job size 2 should produce 2 Queueable jobs');

		Test.stopTest();
	}

	/**
	 * @description Will check that any batched APIs are run via a Queueable job
	 *
	 * @see FLOW_CallApiAsync.invokeApiCallAsynchronously
	 */
	@IsTest
	private static void runQueueable()
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

		FLOW_CallApiAsync.invokeApiCallAsynchronously(new SEL_ApiCall().findByBatchedOutbound());

		Assert.areEqual(1, UTIL_Limits.queueableJobs().used(), 'Expected a Queueable job to have run');

		Test.stopTest();

		SEL_ApiCall.assertServiceCompleted(API_PostExample.class.getName());
	}
}