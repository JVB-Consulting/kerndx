// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Unit tests for SCHED_SubscriberJob.
 *
 * @see SCHED_SubscriberJob
 *
 * @author your.name@company.com
 *
 * @group Scheduler
 *
 * @date March 2026, May 2026
 */
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest(SeeAllData=false IsParallel=true)
private class SCHED_SubscriberJob_TEST
{
	/**
	 * @description Tests that parameter definitions are returned.
	 */
	@IsTest
	private static void shouldReturnParameterDefinitions()
	{
		SCHED_SubscriberJob job = new SCHED_SubscriberJob();

		List<kern.DTO_ScheduledParameterDefinition> definitions = job.getParameterDefinitions();

		Assert.areEqual(3, definitions.size(), 'Should return 3 parameter definitions');
	}

	/**
	 * @description Tests execution with parameters.
	 */
	@IsTest
	private static void shouldExecuteWithParameters()
	{
		SCHED_SubscriberJob job = new SCHED_SubscriberJob();
		kern.DTO_NameValues parameters = new kern.DTO_NameValues();
		parameters.add('objectName', 'Account');
		parameters.add('batchSize', '500');
		parameters.add('dryRun', 'true');
		job.setParameterValues(parameters);

		Test.startTest();
		job.execute(null);
		Test.stopTest();

		Assert.isTrue(SCHED_SubscriberJob.executed, 'Job should have executed');
		Assert.areEqual('Account', SCHED_SubscriberJob.resolvedObjectName, 'Object name should be resolved');
		Assert.areEqual(500, SCHED_SubscriberJob.resolvedBatchSize, 'Batch size should be resolved');
		Assert.isTrue(SCHED_SubscriberJob.resolvedDryRun, 'Dry run should be resolved');
	}

	/**
	 * @description Tests execution without parameters.
	 */
	@IsTest
	private static void shouldExecuteWithoutParameters()
	{
		SCHED_SubscriberJob job = new SCHED_SubscriberJob();

		Test.startTest();
		job.execute(null);
		Test.stopTest();

		Assert.isTrue(SCHED_SubscriberJob.executed, 'Job should have executed');
		Assert.isNull(SCHED_SubscriberJob.resolvedObjectName, 'Object name should be null without parameters');
	}

	/**
	 * @description Tests execution with blank parameter values.
	 */
	@IsTest
	private static void shouldHandleBlankParameterValues()
	{
		SCHED_SubscriberJob job = new SCHED_SubscriberJob();
		kern.DTO_NameValues parameters = new kern.DTO_NameValues();
		parameters.add('objectName', 'Contact');
		parameters.add('batchSize', '');
		parameters.add('dryRun', '');
		job.setParameterValues(parameters);

		Test.startTest();
		job.execute(null);
		Test.stopTest();

		Assert.isTrue(SCHED_SubscriberJob.executed, 'Job should have executed');
		Assert.areEqual('Contact', SCHED_SubscriberJob.resolvedObjectName, 'Object name should be resolved');
		Assert.isNull(SCHED_SubscriberJob.resolvedBatchSize, 'Batch size should be null for blank value');
		Assert.isFalse(SCHED_SubscriberJob.resolvedDryRun, 'Dry run should default to false for blank value');
	}
}
