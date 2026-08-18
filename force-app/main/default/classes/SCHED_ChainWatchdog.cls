// SPDX-License-Identifier: BUSL-1.1
/**
 * @description A scheduled job that finds async chains stuck with no recent activity and marks them
 * Stalled, firing each chain's persisted onError notification once per stall. A chain goes silently
 * stuck when the platform stops its next piece of work without ever calling back — this job is the
 * safety net that surfaces such chains for recovery instead of leaving them Running forever.
 * Configurable via attributes: how long a chain may sit idle before it counts as stale, and how
 * many chains one sweep inspects.
 *
 * @see SCHED_Base
 * @see SCHED_ChainWatchdog_TEST
 * @see UTIL_AsyncChain
 *
 * @author Jason van Beukering
 *
 * @group Async
 *
 * @date July 2026
 *
 * @since 1.6
 *
 * @example
 * ```apex
 * SCHED_ChainWatchdog job = new SCHED_ChainWatchdog();
 * DTO_NameValues attributes = new DTO_NameValues();
 * attributes.add('StaleThresholdMinutes', '30');
 * attributes.add('BatchSize', '50');
 * job.setParameterValues(attributes);
 * System.schedule('Chain Watchdog', '0 0 * * * ?', job);
 * ```
 */
@SuppressWarnings('PMD.AvoidGlobalModifier')
global inherited sharing class SCHED_ChainWatchdog extends SCHED_Base
{
	/**
	 * @description Optional parameter for the maximum number of chains inspected per sweep. Defaults to 50.
	 * Public (not global) so framework callers building a watchdog job — the Health Check one-click
	 * schedule — reference the parameter name symbolically, mirroring SCHED_PurgeRecords.
	 */
	public static final String PARAMETER_BATCH_SIZE = 'BatchSize';

	/**
	 * @description Optional parameter for the number of minutes since the last activity before a
	 * Running chain is treated as stale. Defaults to 30. Public (not global) for the same
	 * symbolic-reference reason as PARAMETER_BATCH_SIZE.
	 */
	public static final String PARAMETER_STALE_THRESHOLD_MINUTES = 'StaleThresholdMinutes';

	/**
	 * @description Executes the scheduled job, delegating to the watchdog sweep on UTIL_AsyncChain
	 * with the configured stale threshold and batch size.
	 *
	 * @param context The SchedulableContext for the scheduled job execution.
	 *
	 * @example
	 * ```apex
	 * SCHED_ChainWatchdog job = new SCHED_ChainWatchdog();
	 * DTO_NameValues attributes = new DTO_NameValues();
	 * attributes.add(SCHED_ChainWatchdog.PARAMETER_STALE_THRESHOLD_MINUTES, '30');
	 * job.setParameterValues(attributes);
	 * System.schedule('Chain Watchdog', '0 0 * * * ?', job);
	 * ```
	 */
	public void execute(SchedulableContext context)
	{
		UTIL_AsyncChain.runWatchdogSweep
				(
						getNumericParameter(PARAMETER_STALE_THRESHOLD_MINUTES),
						getNumericParameter(PARAMETER_BATCH_SIZE)
				);
	}

	/**
	 * @description Returns the parameter definitions supported by this scheduled job.
	 *
	 * @return List of parameter definitions for the stale threshold in minutes and the sweep batch size.
	 *
	 * @example
	 * ```apex
	 * List<DTO_ScheduledParameterDefinition> parameters = new SCHED_ChainWatchdog().getParameterDefinitions();
	 * ```
	 */
	public override List<DTO_ScheduledParameterDefinition> getParameterDefinitions()
	{
		return new List<DTO_ScheduledParameterDefinition>
		{
				DTO_ScheduledParameterDefinition.of(PARAMETER_STALE_THRESHOLD_MINUTES)
						.asNumeric()
						.withDefault('30')
						.withDescription('Minutes since last activity before a Running chain is treated as stale.'),
				DTO_ScheduledParameterDefinition.of(PARAMETER_BATCH_SIZE)
						.asNumeric()
						.withDefault('50')
						.withDescription('Maximum chains inspected per sweep. Values above 50 are capped at 50, so one sweep never runs out of platform resources partway through.')
		};
	}
}