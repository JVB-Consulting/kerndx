// SPDX-License-Identifier: BUSL-1.1
/**
 * @description The job runner's scheduled job. Health Check schedules this class once per chosen minute mark (one
 * to twelve times an hour); each time the platform fires it, it runs one check, which starts every job whose record is
 * set to run on the job runner and is due. The class holds no state and takes no parameters, so a package upgrade never
 * invalidates it, and it is the only Kern class a platform scheduled job references for job-runner work. A check refuses
 * to run for a user who does not hold the Manage Job Runner permission, because the jobs it starts run as that user.
 *
 * @see SCHED_Base
 * @see SCHED_JobRunner_TEST
 * @see UTIL_ScheduledJobRunner
 *
 * @author Jason van Beukering
 *
 * @group Schedulables
 *
 * @date September 2026
 *
 * @since 1.8
 *
 * @example
 * ```apex
 * // Health Check activates the runner for you. To run one check by hand, schedule the class once at the next minute:
 * Datetime fireAt = Datetime.now().addSeconds(75);
 * String cron = '0 ' + fireAt.minute() + ' ' + fireAt.hour() + ' ' + fireAt.day() + ' ' + fireAt.month() + ' ? ' + fireAt.year();
 * System.schedule('One job runner check', cron, new SCHED_JobRunner());
 * ```
 */
@SuppressWarnings('PMD.AvoidGlobalModifier')
global inherited sharing class SCHED_JobRunner extends SCHED_Base
{
	/**
	 * @description Runs one check for due jobs: starts every due job that is set to run on the runner, as the user who
	 * owns this scheduled job.
	 *
	 * @param context The platform's scheduling context; not read.
	 *
	 * @since 1.8
	 */
	public void execute(SchedulableContext context)
	{
		UTIL_ScheduledJobRunner.checkForDueJobs(Datetime.now());
	}
}
