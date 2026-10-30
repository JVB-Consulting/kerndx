// SPDX-License-Identifier: Apache-2.0
/**
 * @description Test class to check behavior of SCHED_ChainWatchdog
 *
 * @see SCHED_ChainWatchdog
 *
 * @author Jason van Beukering
 *
 * @group Async
 *
 * @date July 2026, October 2026
 */
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest(seeAllData=false isParallel=false)
private class SCHED_ChainWatchdog_TEST
{
	/**
	 * @description Batch size value passed to the scheduled watchdog in the activation test.
	 */
	private static final String BATCH_SIZE_VALUE = '10';

	/**
	 * @description Stale threshold value passed to the scheduled watchdog in the activation test.
	 */
	private static final String STALE_THRESHOLD_MINUTES_VALUE = '45';

	/**
	 * @description Tests that getParameterDefinitions declares the two typed watchdog parameters
	 * with their expected names, numeric data type, and defaults.
	 *
	 * @see SCHED_ChainWatchdog.getParameterDefinitions
	 */
	@IsTest
	private static void shouldDeclareTypedParameters()
	{
		List<DTO_ScheduledParameterDefinition> parameters = new SCHED_ChainWatchdog().getParameterDefinitions();

		Assert.areEqual(2, parameters.size(), 'Should return 2 parameter definitions');
		Assert.areEqual(SCHED_ChainWatchdog.PARAMETER_STALE_THRESHOLD_MINUTES, parameters[0].name, 'First parameter should be StaleThresholdMinutes');
		Assert.areEqual(DTO_ScheduledParameterDefinition.DataType.NUMERIC.name(), parameters[0].dataType, 'StaleThresholdMinutes should be numeric');
		Assert.areEqual('30', parameters[0].defaultValue, 'StaleThresholdMinutes should default to 30');
		Assert.isFalse(parameters[0].isRequired, 'StaleThresholdMinutes should be optional');
		Assert.areEqual(SCHED_ChainWatchdog.PARAMETER_BATCH_SIZE, parameters[1].name, 'Second parameter should be BatchSize');
		Assert.areEqual(DTO_ScheduledParameterDefinition.DataType.NUMERIC.name(), parameters[1].dataType, 'BatchSize should be numeric');
		Assert.areEqual('50', parameters[1].defaultValue, 'BatchSize should default to 50');
		Assert.isFalse(parameters[1].isRequired, 'BatchSize should be optional');
	}

	/**
	 * @description Tests that the watchdog schedules and runs through the ScheduledJob__c activation
	 * path: inserting the record starts the scheduled job, and the job executes its sweep at
	 * Test.stopTest() without error.
	 *
	 * @see SCHED_ChainWatchdog.execute
	 */
	@IsTest
	private static void shouldScheduleViaScheduledJob()
	{
		Test.startTest();

		ScheduledJob__c scheduler = TST_Factory.insertScheduledJob(SCHED_ChainWatchdog.class.getName(), new Map<String, String>
		{
				SCHED_ChainWatchdog.PARAMETER_STALE_THRESHOLD_MINUTES => STALE_THRESHOLD_MINUTES_VALUE,
				SCHED_ChainWatchdog.PARAMETER_BATCH_SIZE => BATCH_SIZE_VALUE
		});
		scheduler = (ScheduledJob__c)new SEL_ScheduledJob().findById(scheduler.Id);

		Test.stopTest();

		Assert.isNotNull(scheduler.ScheduledJobId__c, SCHED_ChainWatchdog.class.getName() + ' was not started');
	}
}