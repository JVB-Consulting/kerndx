// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Scheduled job that runs daily to process login history data. Launches
 * PROC_LoginFrequencyAggregator via the adaptive async framework using Batch Apex. Batch is required
 * because finish() updates ScheduleSetting__c (a setup object), which must run in a separate
 * transaction from execute()'s LoginFrequency__c DML to avoid MIXED_DML_OPERATION.
 *
 * @see PROC_LoginFrequencyAggregator
 * @see SCHED_ProcessLoginHistory_TEST
 *
 * @author Jason van Beukering
 *
 * @group Schedulables
 *
 * @date February 2026, May 2026
 *
 * @since 1.0
 *
 * @example
 * ```apex
 * System.schedule('Daily Login History', '0 0 2 * * ?', new SCHED_ProcessLoginHistory());
 * ```
 */
@SuppressWarnings('PMD.AvoidGlobalModifier')
global inherited sharing class SCHED_ProcessLoginHistory implements Schedulable
{
	/**
	 * @description The batch chunk size for processing LoginHistory records.
	 */
	private static final Integer JOB_SIZE = SEL_AsynchronousJobSetting.getBatchSize(PROC_LoginFrequencyAggregator.SETTING_NAME);

	/**
	 * @description Executes the scheduled Apex job to process login history data. Reads the watermark
	 * from ScheduleSetting__c, builds the LoginHistory query, and dispatches processing via the
	 * adaptive async framework.
	 *
	 * @param context Contains the job id
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * System.schedule('Daily Login History Processing', '0 0 2 * * ?', new SCHED_ProcessLoginHistory());
	 * ```
	 */
	global void execute(SchedulableContext context)
	{
		Datetime targetTimestamp = Datetime.now();
		ScheduleSetting__c setting = SEL_ScheduleSetting.getScheduleSetting(PROC_LoginFrequencyAggregator.SETTING_NAME);

		UTIL_AsynchronousJobLauncher.DTO_AsynchronousJobRequest request =
				new UTIL_AsynchronousJobLauncher.DTO_AsynchronousJobRequest(new SEL_LoginHistory().findByLoginTime(setting?.LastSuccessfulRunTime__c))
						.withBatchSize(JOB_SIZE)
						.withExecutionStrategy(IF_Async.AsynchronousExecutionStrategy.BATCH);

		UTIL_AsynchronousJobLauncher.process(request, new PROC_LoginFrequencyAggregator(targetTimestamp));
	}
}