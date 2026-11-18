// SPDX-License-Identifier: Apache-2.0
/**
 * @description Selector for the AsyncApexJob system table. Provides the reads that tell whether an
 * async job is still live. They select as few fields as possible: getFields() declares only Status, and the query
 * builder adds Id on its own. They sit behind UTIL_AsyncChain.isExecutorLive, which decides whether a
 * chain's stamped executor job still holds a live platform status, and behind the Health Check's
 * chain-watchdog probe, which decides whether a schedulable class holds a live scheduled job. The job runner reads it to
 * decide whether a job's previous run is still live, and the batch-error listener reads it to name the class of each
 * batch job that failed. The outbound retry watchdog reads it to decide whether a job that may still send a call is live.
 *
 * @see SEL_Base
 * @see SEL_AsyncApexJob_TEST
 *
 * @author Jason van Beukering
 *
 * @group Async
 *
 * @date July 2026, November 2026
 */
public inherited sharing class SEL_AsyncApexJob extends SEL_Base
{
	/**
	 * @description The AsyncApexJob statuses this selector filters on. All of them are live statuses: the job is waiting or
	 * running. Each member name matches the status value the platform writes and SOQL expects, so name() is the value sent in
	 * the query; that is why the names keep their mixed case and the FieldNamingConventions rule is suppressed.
	 */
	@SuppressWarnings('PMD.FieldNamingConventions')
	public enum AsyncApexJobStatus
	{
		/**
		 * @description Enqueued and waiting for the platform to start it.
		 */
		Queued,
		/**
		 * @description Running right now.
		 */
		Processing,
		/**
		 * @description Being set up by the platform before its first chunk runs.
		 */
		Preparing,
		/**
		 * @description Held in the flex queue, waiting for capacity.
		 */
		Holding
	}

	/**
	 * @description AsyncApexJob status values that count as live on the platform: waiting for a fire
	 * or in some phase of executing. Completed, Aborted and Failed rows are dead and never match, so
	 * leftovers from an aborted schedule cannot read as an active one.
	 */
	private static final Set<AsyncApexJobStatus> LIVE_STATUSES = new Set<AsyncApexJobStatus>
	{
			AsyncApexJobStatus.Queued,
			AsyncApexJobStatus.Processing,
			AsyncApexJobStatus.Preparing,
			AsyncApexJobStatus.Holding
	};

	/**
	 * @description The AsyncApexJob job type a System.schedule registration creates. Both a declarative
	 * ScheduledJob__c activation (TRG_ScheduleJob schedules synchronously) and a direct System.schedule
	 * call produce one of these rows, so a probe on this type sees both scheduling paths.
	 */
	private static final String JOB_TYPE_SCHEDULED_APEX = 'ScheduledApex';

	/**
	 * @description The path to the name of the Apex class a job runs, read through the job's link to its class.
	 */
	private static final String FIELD_APEX_CLASS_NAME = 'ApexClass.Name';

	/**
	 * @description The path to the namespace of the Apex class a job runs, empty for a class outside any package.
	 */
	private static final String FIELD_APEX_CLASS_NAMESPACE_PREFIX = 'ApexClass.NamespacePrefix';

	/**
	 * @description Reads the platform's async job records (AsyncApexJob). Every query skips the running user's object and field permission checks (system mode). Creating the
	 * selector runs no query.
	 */
	public SEL_AsyncApexJob()
	{
		super(AsyncApexJob.SObjectType);
	}

	/**
	 * @description Returns the core fields for AsyncApexJob queries. The list is kept to one field on purpose, because
	 * the liveness check reads only the job's status.
	 *
	 * @return List of AsyncApexJob SObjectField tokens
	 */
	public override List<SObjectField> getFields()
	{
		return new List<SObjectField> {AsyncApexJob.Status};
	}

	/**
	 * @description Framework-internal system-table selector. It always runs in `AccessLevel.SYSTEM_MODE`
	 * regardless of the `UserModeQueries_Enabled` feature flag. Running users typically lack the setup
	 * visibility AsyncApexJob reads require, so USER_MODE reads would return empty and the watchdog
	 * would mistake a live executor for a dead one. That is exactly the mistake the liveness check exists
	 * to prevent.
	 *
	 * @return `true`, because this selector requires SYSTEM_MODE.
	 */
	public override Boolean systemModeRequired()
	{
		return true;
	}

	/**
	 * @description Finds the live scheduled-Apex jobs for an Apex class. This is the check against the
	 * platform itself behind "is this schedulable actually scheduled". Covers declarative ScheduledJob__c jobs and
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
				.condition(AsyncApexJob.Status).isIn(statusNames(LIVE_STATUSES))
				.toList();
	}

	/**
	 * @description Finds which of the given jobs are still live (Queued, Holding, Preparing or Processing). The job runner
	 * passes the LastRunJobId__c values of the rows it claimed, so one indexed read answers the overlap question for a
	 * whole check.
	 *
	 * @param jobIds The AsyncApexJob ids to check; empty reads nothing.
	 *
	 * @return The live rows among them.
	 */
	public List<AsyncApexJob> findLiveByIds(List<Id> jobIds)
	{
		if(jobIds == null || jobIds.isEmpty())
		{
			return new List<AsyncApexJob>();
		}
		return query
				.condition(AsyncApexJob.Id).isIn(jobIds)
				.condition(AsyncApexJob.Status).isIn(statusNames(LIVE_STATUSES))
				.toList();
	}

	/**
	 * @description Finds the jobs with the given ids, whatever their status, together with the name and namespace of
	 * the Apex class each one runs, the job's type, its detailed status message and its chunk counts. The batch-error
	 * listener passes the job ids its events name, so one read gives the full class name of every failed job. The
	 * processor reads its own batch job when the batch ends, to see whether any chunk failed before it calls finish.
	 *
	 * @param jobIds The AsyncApexJob ids to read; empty reads nothing.
	 *
	 * @return The matching rows, each carrying its ApexClassId, ApexClass.Name, ApexClass.NamespacePrefix, JobType,
	 * ExtendedStatus, NumberOfErrors (chunks that failed), TotalJobItems (chunks in all) and JobItemsProcessed (chunks
	 * that have run).
	 */
	public List<AsyncApexJob> findByIds(List<Id> jobIds)
	{
		if(jobIds == null || jobIds.isEmpty())
		{
			return new List<AsyncApexJob>();
		}
		return query
				.addField(AsyncApexJob.ApexClassId)
				.addField(FIELD_APEX_CLASS_NAME)
				.addField(FIELD_APEX_CLASS_NAMESPACE_PREFIX)
				.addField(AsyncApexJob.JobType)
				.addField(AsyncApexJob.ExtendedStatus)
				.addField(AsyncApexJob.NumberOfErrors)
				.addField(AsyncApexJob.TotalJobItems)
				.addField(AsyncApexJob.JobItemsProcessed)
				.condition(AsyncApexJob.Id).isIn(jobIds)
				.toList();
	}

	/**
	 * @description Finds the newest live job (Queued, Holding, Preparing or Processing) of an Apex class among the jobs
	 * created after the given time, of any job type. The read sorts the jobs newest first and returns only the first
	 * one, with its ApexClassId and CreatedDate. The outbound retry watchdog reads the jobs of the class that sends
	 * outbound calls this way: a live job created after a call's retry was due may still send that call, and only the
	 * newest job matters for that check. An org can have many live jobs of that class, so the read stops at one row.
	 *
	 * @param apexClassId The Id of the ApexClass whose jobs to find.
	 * @param after Only jobs created after this time are found.
	 *
	 * @return The newest live job, or null when there is none.
	 */
	public AsyncApexJob findNewestLiveByApexClassIdCreatedAfter(Id apexClassId, Datetime after)
	{
		return (AsyncApexJob)query
				.addField(AsyncApexJob.ApexClassId)
				.addField(AsyncApexJob.CreatedDate)
				.condition(AsyncApexJob.ApexClassId).equals(apexClassId)
				.condition(AsyncApexJob.Status).isIn(statusNames(LIVE_STATUSES))
				.condition(AsyncApexJob.CreatedDate).greaterThan(after)
				.orderBy(AsyncApexJob.CreatedDate).descending()
				.getFirst();
	}

	/**
	 * @description The wire values of the given statuses, the form both SOQL and AsyncApexJob.Status carry.
	 *
	 * @param statuses The statuses.
	 *
	 * @return Their names, ready for a query condition.
	 */
	private static Set<Object> statusNames(Set<AsyncApexJobStatus> statuses)
	{
		Set<Object> names = new Set<Object>();
		for(AsyncApexJobStatus status : statuses)
		{
			names.add(status.name());
		}
		return names;
	}
}