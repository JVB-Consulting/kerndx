// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Selector for the AsyncApexJob system table. Provides the async liveness reads —
 * a deliberately minimal projection (getFields() declares only Status, and the query builder
 * projects Id automatically) behind UTIL_AsyncChain.isExecutorLive, which decides whether a
 * chain's stamped executor job still holds a live platform status, and behind the Health Check's
 * chain-watchdog probe, which decides whether a schedulable class holds a live scheduled job.
 *
 * @see SEL_Base
 * @see SEL_AsyncApexJob_TEST
 *
 * @author Jason van Beukering
 *
 * @group Async
 *
 * @date July 2026
 */
public inherited sharing class SEL_AsyncApexJob extends SEL_Base
{
	/**
	 * @description AsyncApexJob status values that count as live on the platform: waiting for a fire
	 * or in some phase of executing. Completed, Aborted and Failed rows are dead and never match, so
	 * leftovers from an aborted schedule cannot read as an active one.
	 */
	private static final Set<Object> LIVE_STATUSES = new Set<Object> {'Queued', 'Processing', 'Preparing', 'Holding'};

	/**
	 * @description The AsyncApexJob job type a System.schedule registration creates. Both a declarative
	 * ScheduledJob__c activation (TRG_ScheduleJob schedules synchronously) and a direct System.schedule
	 * call produce one of these rows, so a probe on this type sees both scheduling paths.
	 */
	private static final String JOB_TYPE_SCHEDULED_APEX = 'ScheduledApex';

	/**
	 * @description Constructs an AsyncApexJob selector.
	 */
	public SEL_AsyncApexJob()
	{
		super(AsyncApexJob.SObjectType);
	}

	/**
	 * @description Returns the core fields for AsyncApexJob queries — deliberately minimal, because
	 * the liveness check reads only the job's status.
	 *
	 * @return List of AsyncApexJob SObjectField tokens
	 */
	public override List<SObjectField> getFields()
	{
		return new List<SObjectField> {AsyncApexJob.Status};
	}

	/**
	 * @description Framework-internal system-table selector — always runs in `AccessLevel.SYSTEM_MODE`
	 * regardless of the `UserModeQueries_Enabled` feature flag. Running users typically lack the setup
	 * visibility AsyncApexJob reads require, so USER_MODE reads would return empty and the watchdog
	 * would mistake a live executor for a dead one — exactly the misread the liveness check exists
	 * to prevent.
	 *
	 * @return `true` — this selector requires SYSTEM_MODE.
	 */
	public override Boolean systemModeRequired()
	{
		return true;
	}

	/**
	 * @description Finds the live scheduled-Apex jobs for an Apex class — the platform-truth probe
	 * behind "is this schedulable actually scheduled". Covers declarative ScheduledJob__c jobs and
	 * hand-run System.schedule registrations alike, because both produce the same scheduled-Apex row.
	 *
	 * @param apexClassId The Id of the ApexClass whose scheduled jobs to find
	 *
	 * @return Live (waiting or executing) scheduled-Apex AsyncApexJob rows for the class
	 *
	 * @example
	 * ```apex
	 * List<AsyncApexJob> liveJobs = new SEL_AsyncApexJob().findLiveScheduledApexByApexClassId(watchdogClassId);
	 * ```
	 */
	public List<AsyncApexJob> findLiveScheduledApexByApexClassId(Id apexClassId)
	{
		return query
				.condition(AsyncApexJob.JobType).equals(JOB_TYPE_SCHEDULED_APEX)
				.condition(AsyncApexJob.ApexClassId).equals(apexClassId)
				.condition(AsyncApexJob.Status).isIn(LIVE_STATUSES)
				.toList();
	}
}