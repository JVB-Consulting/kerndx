// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Selector for the ScheduledJob__c SObject. Provides default field configuration
 * and query methods for scheduled job records.
 *
 * @see SEL_Base
 * @see SEL_ScheduledJob_TEST
 *
 * @author Jason van Beukering
 *
 * @group Schedulables
 *
 * @date February 2026, October 2026
 */
public inherited sharing class SEL_ScheduledJob extends SEL_Base
{
	/**
	 * @description Set only by a test: the next claim throws the QueryException a blocked lock produces after the platform's
	 * ten-second wait, because Apex tests cannot produce two concurrent transactions. Never set outside a test.
	 */
	@TestVisible
	private static Boolean simulateLockTimeout = false;

	/**
	 * @description Constructs a ScheduledJob selector.
	 */
	public SEL_ScheduledJob()
	{
		super(ScheduledJob__c.SObjectType);
	}

	/**
	 * @description Returns the core fields for ScheduledJob__c queries.
	 *
	 * @return List of ScheduledJob__c SObjectField tokens
	 */
	public override List<SObjectField> getFields()
	{
		return new List<SObjectField>
		{
				ScheduledJob__c.Parameters__c,
				ScheduledJob__c.ClassName__c,
				ScheduledJob__c.CreatedDate,
				ScheduledJob__c.CronExpression__c,
				ScheduledJob__c.Description__c,
				ScheduledJob__c.IsActive__c,
				ScheduledJob__c.Name,
				ScheduledJob__c.ScheduledJobId__c,
				ScheduledJob__c.SchedulerName__c,
				ScheduledJob__c.Timezone__c,
				ScheduledJob__c.ExecutionMode__c,
				ScheduledJob__c.NextRunAt__c,
				ScheduledJob__c.LastRunAt__c,
				ScheduledJob__c.LastRunOutcome__c,
				ScheduledJob__c.LastRunReason__c,
				ScheduledJob__c.LastRunJobId__c,
				ScheduledJob__c.RunPriority__c,
				ScheduledJob__c.OverlapPolicy__c
		};
	}

	/**
	 * @description Framework-owned sObject selector. It always runs in `AccessLevel.SYSTEM_MODE`
	 * regardless of the `UserModeQueries_Enabled` feature flag. Running users typically have no
	 * CRUD on framework-owned scheduling records (the framework owns their lifecycle), so
	 * USER_MODE reads would return empty and schedulers would fail to resolve their jobs.
	 *
	 * @return `true`, because this selector requires SYSTEM_MODE.
	 */
	public override Boolean systemModeRequired()
	{
		return true;
	}

	/**
	 * @description Finds active scheduled jobs for a given Apex class name.
	 *
	 * @param className The fully qualified Apex class name
	 *
	 * @return List of active ScheduledJob__c records for the class
	 */
	public List<ScheduledJob__c> findActiveByClassName(String className)
	{
		return query
				.condition(ScheduledJob__c.IsActive__c).equals(true)
				.condition(ScheduledJob__c.ClassName__c).equals(className)
				.toList();
	}

	/**
	 * @description Claims the rows due when the job runner checks: active job-runner-mode rows whose cursor is at or before
	 * the check time, in the order the runner starts them (lowest RunPriority__c first, blanks last, then oldest cursor
	 * first), capped at the check limit. A locking query cannot carry ORDER BY, so this is two reads: an ordered read of the
	 * ids, then a FOR UPDATE read of those ids whose rows are returned in the first read's order. A row whose cursor moved
	 * past the check time between the two reads was consumed by another writer and is dropped. Both reads run in system
	 * mode and bypass sharing: the object is public read-only and the runner runs as the activator, who owns none of the
	 * rows other administrators created. A blocked lock waits the platform's ten seconds, then throws QueryException, which
	 * the caller treats as a clean exit. The record id is the last ordering key, so two rows with the same priority and
	 * the same cursor keep the same relative order at every check and cannot swap across the check limit's boundary.
	 *
	 * @param checkTime The check time, snapped to the minute.
	 * @param checkLimit The most rows to claim; zero or null claims nothing.
	 *
	 * @return The locked rows, in the order they are started.
	 */
	public List<ScheduledJob__c> findDueJobRunnerRecordsForUpdate(Datetime checkTime, Integer checkLimit)
	{
		if(checkTime == null || checkLimit == null || checkLimit <= 0)
		{
			return new List<ScheduledJob__c>();
		}
		List<ScheduledJob__c> ordered = dueJobRunnerRows(checkTime)
				.onlyFields(new List<SObjectField> {ScheduledJob__c.NextRunAt__c})
				.orderBy(ScheduledJob__c.RunPriority__c, false, true)
				.orderBy(ScheduledJob__c.NextRunAt__c).ascending()
				.orderBy(ScheduledJob__c.Id).ascending()
				.withLimit(checkLimit)
				.toList();
		if(ordered.isEmpty())
		{
			return ordered;
		}
		throwIfLockTimeoutSimulated();
		Map<Id, ScheduledJob__c> locked = new Map<Id, ScheduledJob__c>((List<ScheduledJob__c>)buildLockingRead(ordered).toList());
		List<ScheduledJob__c> claimed = new List<ScheduledJob__c>();
		for(ScheduledJob__c row : ordered)
		{
			ScheduledJob__c lockedRow = locked.get(row.Id);
			if(lockedRow != null && lockedRow.NextRunAt__c != null && lockedRow.NextRunAt__c <= checkTime)
			{
				claimed.add(lockedRow);
			}
		}
		return claimed;
	}

	/**
	 * @description Throws the QueryException a blocked lock produces, once, when a test has set simulateLockTimeout.
	 * Apex tests cannot produce two concurrent transactions, so this stands in for a real blocked lock.
	 */
	private static void throwIfLockTimeoutSimulated()
	{
		if(!simulateLockTimeout)
		{
			return;
		}
		simulateLockTimeout = false;
		throw new QueryException('Record currently unavailable: the record you are attempting to lock is held by another transaction');
	}

	/**
	 * @description The locking half of the claim: the default fields of the given rows, FOR UPDATE, with no ORDER BY.
	 * Public so a test can read the SOQL it would run; the claim executes exactly this builder. It reads and locks the
	 * scheduled job rows the ordered read chose, bypassing sharing because the object is public read-only and the runner
	 * runs as the activator, who owns none of the rows other administrators created. The bypass matters most if a
	 * subscriber tightens this object's sharing model to Private: the object ships public read-only, so a read reaches
	 * every row without it today, but under Private it would not and the runner would stop seeing the rows it is there
	 * to start.
	 *
	 * @param orderedRows The rows the ordered read returned.
	 *
	 * @return The builder, ready to execute.
	 */
	public QRY_Builder.Builder buildLockingRead(List<ScheduledJob__c> orderedRows)
	{
		return query.bypassSharingInternal()
				.condition(ScheduledJob__c.Id).isIn(orderedRows)
				.forUpdate();
	}

	/**
	 * @description Counts the rows due at a check, so the runner can report how many it left waiting. It counts the
	 * scheduled job rows of every team, bypassing sharing because the object is public read-only and the runner runs as the
	 * activator, who owns none of the rows other administrators created.
	 *
	 * @param checkTime The check time, snapped to the minute.
	 *
	 * @return The number of active job-runner-mode rows whose cursor is at or before the check time.
	 */
	public Integer countDueJobRunnerRecords(Datetime checkTime)
	{
		return dueJobRunnerRows(checkTime).count();
	}

	/**
	 * @description Reads one record FOR UPDATE, bypassing sharing, for Run now, which shares the claim's lock so it can never
	 * race a check on the same row.
	 *
	 * @param recordId The record id.
	 *
	 * @return The locked record, or null when it no longer exists.
	 */
	public ScheduledJob__c findByIdForUpdate(Id recordId)
	{
		List<ScheduledJob__c> rows = query.bypassSharingInternal()
				.condition(ScheduledJob__c.Id).equals(recordId)
				.forUpdate()
				.toList();
		return rows.isEmpty() ? null : rows[0];
	}

	/**
	 * @description Reads one record bypassing sharing, for the run Queueable's start-time re-read: the run executes as the
	 * activator, who need not own the record.
	 *
	 * @param recordId The record id.
	 *
	 * @return The record, or null when it has been deleted.
	 */
	public ScheduledJob__c findByIdBypassingSharing(Id recordId)
	{
		List<ScheduledJob__c> rows = query.bypassSharingInternal()
				.condition(ScheduledJob__c.Id).equals(recordId)
				.toList();
		return rows.isEmpty() ? null : rows[0];
	}

	/**
	 * @description The job runner's own records: every record, active or not, whose class is the runner's schedulable.
	 * Bypasses sharing because Health Check must see records another administrator activated.
	 *
	 * @return The runner records, oldest first.
	 */
	public List<ScheduledJob__c> findRunnerRecords()
	{
		Set<Object> runnerClassNames = new Set<Object>
		{
				UTIL_ScheduledJobRunner.RUNNER_CLASS_NAME,
				UTIL_ScheduledJobRunner.RUNNER_CLASS_NAME.substringAfterLast(UTIL_String.DOT)
		};
		runnerClassNames.remove(UTIL_String.EMPTY);
		return query.bypassSharingInternal()
				.condition(ScheduledJob__c.ClassName__c).isIn(runnerClassNames)
				.orderBy(ScheduledJob__c.CreatedDate).ascending()
				.toList();
	}

	/**
	 * @description The active rows that run on the job runner, for the orphan dimension. Bypasses sharing for the same
	 * reason as findRunnerRecords.
	 *
	 * @return The active job-runner-mode rows.
	 */
	public List<ScheduledJob__c> findActiveJobRunnerModeRecords()
	{
		return query.bypassSharingInternal()
				.condition(ScheduledJob__c.IsActive__c).equals(true)
				.andCondition(ScheduledJob__c.ExecutionMode__c).equals(UTIL_ScheduledJobRunner.EXECUTION_MODE_JOB_RUNNER)
				.toList();
	}

	/**
	 * @description The active rows that own a platform scheduled job, for the slot breakdown. A slot is one of the
	 * limited number of scheduled jobs the platform allows an org; the breakdown uses these rows to tell which slots
	 * belong to a Scheduled Job record of its own.
	 * Bypasses sharing for the same reason as findRunnerRecords.
	 *
	 * @return The active rows with a ScheduledJobId__c.
	 */
	public List<ScheduledJob__c> findActiveWithPlatformJob()
	{
		return query.bypassSharingInternal()
				.condition(ScheduledJob__c.IsActive__c).equals(true)
				.andCondition(ScheduledJob__c.ScheduledJobId__c).isNotNull()
				.toList();
	}

	/**
	 * @description The shared filter of the two due-row reads. It reads the scheduled job rows of every team, bypassing
	 * sharing because the object is public read-only and the runner runs as the activator, who owns none of the rows other
	 * administrators created.
	 *
	 * @param checkTime The check time.
	 *
	 * @return A builder filtered to active job-runner-mode rows due at or before the check time.
	 */
	private QRY_Builder.Builder dueJobRunnerRows(Datetime checkTime)
	{
		return query.bypassSharingInternal()
				.condition(ScheduledJob__c.IsActive__c).equals(true)
				.andCondition(ScheduledJob__c.ExecutionMode__c).equals(UTIL_ScheduledJobRunner.EXECUTION_MODE_JOB_RUNNER)
				.andCondition(ScheduledJob__c.NextRunAt__c).lessThanOrEquals(checkTime);
	}
}