// SPDX-License-Identifier: Apache-2.0

/**
 * @description The job runner: the values a ScheduledJob__c record uses to opt in, and the helpers that read them.
 * The runner is a scheduling mechanism, not a second orchestration framework: once a run is started, execution
 * belongs to the Schedulable contract.
 *
 * @see SCHED_JobRunner
 * @see SEL_ScheduledJob
 * @see TRG_ScheduleJob
 * @see UTIL_CronExpression
 * @see UTIL_ScheduledJobRunner_TEST
 *
 * @author Jason van Beukering
 *
 * @group Schedulables
 *
 * @date September 2026, October 2026
 */
@SuppressWarnings('PMD.CognitiveComplexity,PMD.CyclomaticComplexity')
public inherited sharing class UTIL_ScheduledJobRunner
{
	/**
	 * @description ExecutionMode__c value for a record that owns one platform scheduled job, the default and the meaning of blank.
	 */
	public static final String EXECUTION_MODE_OWN_SCHEDULED_JOB = 'OwnScheduledJob';

	/**
	 * @description ExecutionMode__c value for a record the job runner runs.
	 */
	public static final String EXECUTION_MODE_JOB_RUNNER = 'JobRunner';

	/**
	 * @description LastRunOutcome__c value written by the Finalizer when a run finishes without an exception.
	 */
	public static final String OUTCOME_SUCCEEDED = 'Succeeded';

	/**
	 * @description LastRunOutcome__c value written by the Finalizer when a run ends in an exception or a limit.
	 */
	public static final String OUTCOME_FAILED = 'Failed';

	/**
	 * @description LastRunOutcome__c value written when a due occurrence was consumed without a run.
	 */
	public static final String OUTCOME_SKIPPED = 'Skipped';

	/**
	 * @description LastRunOutcome__c value written when a check could not load the class or place the expression. Such a
	 * row is parked: the runner records a fixed reason on it and sets its next due time one day later (see park).
	 */
	public static final String OUTCOME_PARKED = 'Parked';

	/**
	 * @description LastRunReason__c value: a due run was skipped because the job's previous run was still running.
	 */
	public static final String REASON_PREVIOUS_RUN_STILL_RUNNING = 'PreviousRunStillRunning';

	/**
	 * @description LastRunReason__c value: when the run started, the job was inactive or no longer set to run on the job runner.
	 */
	public static final String REASON_RECORD_NO_LONGER_ON_RUNNER = 'RecordNoLongerOnRunner';

	/**
	 * @description LastRunReason__c value: the job was parked because its class could not be loaded.
	 */
	public static final String REASON_CLASS_NOT_FOUND = 'ClassNotFound';

	/**
	 * @description LastRunReason__c value: the job was parked because its cron expression could not be read.
	 */
	public static final String REASON_EXPRESSION_CANNOT_BE_PLACED = 'ExpressionCannotBePlaced';

	/**
	 * @description LastRunReason__c value: the job was parked because its expression never fires within the next four years.
	 */
	public static final String REASON_EXPRESSION_CANNOT_FIRE_WITHIN_HORIZON = 'ExpressionCannotFireWithinHorizon';

	/**
	 * @description OverlapPolicy__c value: a due occurrence is skipped while the previous run is still live. The default.
	 */
	public static final String OVERLAP_POLICY_SKIP = 'Skip';

	/**
	 * @description OverlapPolicy__c value: a due occurrence is started regardless of the previous run.
	 */
	public static final String OVERLAP_POLICY_ALLOW = 'Allow';

	/**
	 * @description The FeatureFlag__mdt record that turns the job runner off without anything being unscheduled.
	 */
	public static final String FEATURE_FLAG_NAME = 'ScheduledJobRunner';

	/**
	 * @description The ScheduleSetting__c row whose LastSuccessfulRunTime__c holds the time of the last completed check.
	 */
	public static final String LAST_CHECK_SETTING_NAME = 'JobRunner';

	/**
	 * @description The AsynchronousJobSetting__mdt record whose BatchSize__c is how many jobs one check may start.
	 */
	public static final String CHECK_LIMIT_SETTING_NAME = 'JobRunnerCheckLimit';

	/**
	 * @description How many jobs one check may start when the setting is absent.
	 */
	public static final Integer DEFAULT_CHECK_LIMIT = 25;

	/**
	 * @description The check intervals Health Check offers, in minutes: each divides the hour, so a runner at that
	 * interval has one scheduled job per minute mark.
	 */
	public static final List<Integer> CHECK_INTERVAL_MINUTES = new List<Integer> {60, 30, 15, 10, 5};

	/**
	 * @description How far a parked row's cursor is pushed, in days. The cursor is NextRunAt__c, the time the row is next
	 * due. Pushing it stops the parked row from holding the front of the queue at every check.
	 */
	public static final Integer PARKED_CURSOR_PUSH_DAYS = 1;

	/**
	 * @description The API name of the Manage Job Runner custom permission. Every action that puts a job on the runner,
	 * changes such a job's class or parameters, runs it now, or activates, repairs or deactivates the runner checks it
	 * for the running user.
	 */
	public static final String MANAGE_JOB_RUNNER_CUSTOM_PERMISSION_NAME = 'ManageJobRunner';

	/**
	 * @description The API name of the Kern Job Runner Management permission set, which grants the Manage Job Runner custom
	 * permission. The package ships it assigned to nobody.
	 */
	public static final String JOB_RUNNER_MANAGEMENT_PERMISSION_SET_NAME = 'JobRunnerManagement';

	/**
	 * @description The qualified name of the runner's schedulable, the class name of every runner record.
	 */
	public static final String RUNNER_CLASS_NAME = SCHED_JobRunner.class.getName();

	/**
	 * @description The class name used as the log method prefix.
	 */
	private static final String CLASS_NAME = UTIL_ScheduledJobRunner.class.getName();

	/**
	 * @description The log method of a check for due jobs.
	 */
	private static final String CHECK_METHOD = CLASS_NAME + '.checkForDueJobs';

	/**
	 * @description The log method of a run.
	 */
	private static final String RUN_METHOD = CLASS_NAME + '.Execution.execute';

	/**
	 * @description Milliseconds in a minute, for snapping the check clock.
	 */
	private static final Long MILLISECONDS_PER_MINUTE = 60000L;

	/**
	 * @description Set only by a test: the next framework row write throws, so a test can prove the run just enqueued is
	 * aborted and the row stays due. The async chain framework simulates a crash the same way. Never set outside a test.
	 */
	@TestVisible
	private static Boolean simulateRowWriteFailure = false;

	/**
	 * @description Whether a record is on the job runner. Blank reads as own mode, so no existing record changes behaviour.
	 *
	 * @param record The scheduled job record.
	 *
	 * @return True when ExecutionMode__c is JobRunner.
	 */
	public static Boolean isJobRunnerMode(ScheduledJob__c record)
	{
		return record != null && record.ExecutionMode__c == EXECUTION_MODE_JOB_RUNNER;
	}

	/**
	 * @description Whether a record names the runner's own schedulable, written either the way RUNNER_CLASS_NAME is
	 * written or as its bare name without the package namespace, in any letter case. Nothing else is a runner record,
	 * not even the same bare name under another namespace, so this answers exactly what SEL_ScheduledJob.findRunnerRecords
	 * reads back.
	 *
	 * @param record The scheduled job record.
	 *
	 * @return True when ClassName__c names the runner's schedulable.
	 */
	public static Boolean isRunnerRecord(ScheduledJob__c record)
	{
		if(record == null || String.isBlank(record.ClassName__c))
		{
			return false;
		}
		String bareRunnerClassName = RUNNER_CLASS_NAME.substringAfterLast(UTIL_String.DOT);
		return record.ClassName__c.equalsIgnoreCase(RUNNER_CLASS_NAME) || record.ClassName__c.equalsIgnoreCase(bareRunnerClassName);
	}

	/**
	 * @description Whether the running user holds the Manage Job Runner permission.
	 *
	 * @return True when the running user holds it, false when not.
	 */
	public static Boolean hasManagePermission()
	{
		return SEL_CustomPermission.hasPackagePermission(UserInfo.getUserId(), MANAGE_JOB_RUNNER_CUSTOM_PERMISSION_NAME);
	}

	/**
	 * @description Snaps an instant to the start of its minute, so a check that starts at 07:35:12 treats itself as 07:35:00.
	 *
	 * @param instant The instant.
	 *
	 * @return The same minute with seconds and milliseconds cleared.
	 */
	public static Datetime snapToMinute(Datetime instant)
	{
		Long milliseconds = instant.getTime();
		return Datetime.newInstance(milliseconds - Math.mod(milliseconds, MILLISECONDS_PER_MINUTE));
	}

	/**
	 * @description One check for due jobs. Guards its entry (the feature flag, then the permission), snaps the clock,
	 * works out how many jobs it may start, claims the due rows under a lock, checks which previous runs are still live,
	 * then handles each row on its own: skip, park or start. Records the time of the check on every clean exit and logs
	 * only when something happened.
	 *
	 * @param now The clock. Tests pass an explicit instant; the schedulable passes Datetime.now().
	 *
	 * @return What the check did, for tests and for the schedulable's log.
	 */
	public static CheckResult checkForDueJobs(Datetime now)
	{
		CheckResult result = new CheckResult();
		Datetime clock = now ?? Datetime.now();
		FrameworkWriter writer = new FrameworkWriter();
		if(!UTIL_FeatureFlag.isEnabled(FEATURE_FLAG_NAME))
		{
			result.stoppedByFeatureFlag = true;
			writer.recordLastCheck(clock);
			return result;
		}
		if(!hasManagePermission())
		{
			result.refusedWithoutPermission = true;
			String refusal = 'The job runner checked for due jobs as ' + UserInfo.getUserName() + ', who does not hold the Manage Job Runner permission.';
			refusal += ' No job was started. Repair the runner in Health Check as a user who holds it.';
			LOG_Builder.build().warn(refusal).emitAt(CHECK_METHOD);
			return result;
		}
		result.checkTime = snapToMinute(clock);
		result.checkLimit = effectiveCheckLimit();
		List<ScheduledJob__c> claimed;
		try
		{
			claimed = new SEL_ScheduledJob().findDueJobRunnerRecordsForUpdate(result.checkTime, result.checkLimit);
		}
		catch(QueryException lockError)
		{
			result.lockedOut = true;
			String lockout = 'Another writer holds the due rows; this check exits without starting anything. ' + lockError.getMessage();
			LOG_Builder.build().warn(lockout).emitAt(CHECK_METHOD);
			writer.recordLastCheck(clock);
			return result;
		}
		Set<Id> liveRunIds = findLiveRunIds(claimed);
		for(ScheduledJob__c row : claimed)
		{
			if(UTIL_Limits.queueableJobs().remaining() <= 0)
			{
				// kern-coverage-exempt: the allowance is clamped before the loop, so only a trigger or log handler starting a job mid-loop could use it up, and none of ours do
				result.allowanceExhausted = true;
				// kern-coverage-exempt: the exit from a loop whose allowance ran out mid-way, unreachable for the same reason as the line above it
				break;
			}
			try
			{
				handleRow(row, liveRunIds, writer, result);
			}
			catch(DmlException writeError)
			{
				recordRowWriteFailure(row, writeError, result);
			}
		}
		reportRowsLeftWaiting(claimed, result);
		writer.recordLastCheck(clock);
		return result;
	}

	/**
	 * @description Runs one job on the runner now, as the user who asks. Takes the same row lock a check takes, applies
	 * the overlap policy the same way (Skip refuses while the previous run is live; Allow proceeds), enqueues the same
	 * run and stamps the run id in the same transaction. Never moves the cursor: a run now is not one of the schedule's
	 * occurrences. The switch that turns the whole job runner off covers this too: with the runner off, nothing starts.
	 *
	 * @param scheduledJobId The record to run.
	 *
	 * @return The run's platform job id.
	 *
	 * @throws IllegalArgumentException With the label text when the job runner is switched off, the caller lacks the
	 * permission, the record is not an active job on the runner, or the overlap policy refuses. If the stamp itself cannot
	 * be written, the run just started is called off first and that write failure is then thrown on to the caller, so no
	 * run outlives a stamp that could not be written.
	 */
	public static Id runNow(Id scheduledJobId)
	{
		ScheduledJob__c row = claimRowForRunNow(scheduledJobId);
		Id runJobId = System.enqueueJob(new Execution(row.Id));
		try
		{
			new FrameworkWriter().updateRecord(new ScheduledJob__c(Id = row.Id, LastRunJobId__c = runJobId));
		}
		catch(Exception writeError)
		{
			abortOrThrow(row.Id, runJobId, writeError);
			throw writeError;
		}
		return runJobId;
	}

	/**
	 * @description Claims one record for a Run now, or refuses. Turns the request down straight away while the job runner
	 * is switched off, before anything is locked, so the switch that stops the checks stops Run now with them. Then checks
	 * that the running user holds the Manage Job Runner permission, reads the record under the same lock a check takes,
	 * and turns down anything that is not an active job on the runner or whose previous run is still going while the
	 * record says to skip such a run. Every refusal carries the words the subscriber sees.
	 *
	 * @param scheduledJobId The record to run.
	 *
	 * @return The record, locked and ready to run.
	 *
	 * @throws IllegalArgumentException With the label text for whichever refusal applies.
	 */
	private static ScheduledJob__c claimRowForRunNow(Id scheduledJobId)
	{
		if(!UTIL_FeatureFlag.isEnabled(FEATURE_FLAG_NAME))
		{
			throw new IllegalArgumentException(System.Label.ScheduledJob_RunNowRefusedRunnerOff);
		}
		if(!hasManagePermission())
		{
			throw new IllegalArgumentException(System.Label.ScheduledJob_RunNowPermissionRequired);
		}
		ScheduledJob__c row = new SEL_ScheduledJob().findByIdForUpdate(scheduledJobId);
		if(row == null || !row.IsActive__c || !isJobRunnerMode(row))
		{
			throw new IllegalArgumentException(System.Label.ScheduledJob_RunNowOnlyForJobRunnerRecords);
		}
		Boolean previousRunLive = !findLiveRunIds(new List<ScheduledJob__c> {row}).isEmpty();
		if(row.OverlapPolicy__c != OVERLAP_POLICY_ALLOW && previousRunLive)
		{
			throw new IllegalArgumentException(System.Label.ScheduledJob_RunNowRefusedPreviousRunLive);
		}
		return row;
	}

	/**
	 * @description Records a row the check could not write. The row keeps everything it had, so it is due again at the
	 * next check, and the log entry is the account of what happened to it. One refused row never stops the rows after it.
	 *
	 * @param row The claimed row.
	 * @param writeError The write failure.
	 * @param result The result to update.
	 */
	private static void recordRowWriteFailure(ScheduledJob__c row, DmlException writeError, CheckResult result)
	{
		String summary = row.SchedulerName__c + ': the row could not be written, so it stays due.';
		LOG_Builder.build().error(writeError).withSummary(summary).forRecord(row.Id).emitAt(CHECK_METHOD);
		result.writeFailures++;
	}

	/**
	 * @description Counts the rows that are still due once the check has done what it could, and warns once when the check
	 * ran out of room for them. A row whose write failed is still due but was not left waiting by the check limit; its own
	 * ERROR entry names it, so it is taken out of the count.
	 *
	 * @param claimed The rows the check claimed.
	 * @param result The result to update.
	 */
	private static void reportRowsLeftWaiting(List<ScheduledJob__c> claimed, CheckResult result)
	{
		Integer leftWaitingByTheLimit = new SEL_ScheduledJob().countDueJobRunnerRecords(result.checkTime) - result.writeFailures;
		if(leftWaitingByTheLimit <= 0 || (claimed.size() < result.checkLimit && !result.allowanceExhausted))
		{
			return;
		}
		result.leftWaiting = leftWaitingByTheLimit;
		String atTheLimit = leftWaitingByTheLimit + ' due job(s) were left for the next check because this check may start at most ';
		atTheLimit += result.checkLimit + ' jobs. Raise the Job Runner Check Limit, check less often, or run fewer jobs.';
		LOG_Builder.build().warn(atTheLimit).emitAt(CHECK_METHOD);
	}

	/**
	 * @description The smaller of the configured check limit and the Queueable allowance the transaction has left, so no
	 * configured value can make a check hit an uncatchable limit.
	 *
	 * @return The number of runs this check may start.
	 */
	private static Integer effectiveCheckLimit()
	{
		Integer configured = SEL_AsynchronousJobSetting.getBatchSize(CHECK_LIMIT_SETTING_NAME, DEFAULT_CHECK_LIMIT);
		return Math.max(0, Math.min(configured, UTIL_Limits.queueableJobs().remaining()));
	}

	/**
	 * @description One bulk read of the platform's job table answering which claimed rows' previous runs are still live.
	 * Ids are compared as ids throughout, never as text: the same job is written as fifteen characters in one place and
	 * eighteen in another, and only an Id comparison sees those two spellings as the same job.
	 *
	 * @param claimed The claimed rows.
	 *
	 * @return The live run ids among their LastRunJobId__c values.
	 */
	private static Set<Id> findLiveRunIds(List<ScheduledJob__c> claimed)
	{
		List<Id> previousRunIds = new List<Id>();
		for(ScheduledJob__c row : claimed)
		{
			Id previousRunId = toRunId(row.LastRunJobId__c);
			if(previousRunId != null)
			{
				previousRunIds.add(previousRunId);
			}
		}
		Set<Id> liveRunIds = new Set<Id>();
		for(AsyncApexJob liveJob : new SEL_AsyncApexJob().findLiveByIds(previousRunIds))
		{
			liveRunIds.add(liveJob.Id);
		}
		return liveRunIds;
	}

	/**
	 * @description Reads the run id a record carries. The field is text, so it can hold anything; a blank or unreadable
	 * value simply means there is no previous run to look up.
	 *
	 * @param storedRunId The LastRunJobId__c value.
	 *
	 * @return The id, or null when the field holds nothing usable.
	 */
	private static Id toRunId(String storedRunId)
	{
		if(String.isBlank(storedRunId) || !(storedRunId instanceof Id))
		{
			return null;
		}
		return Id.valueOf(storedRunId);
	}

	/**
	 * @description Handles one claimed row in its own try block: parks it when its class or expression cannot be used,
	 * skips it under Skip while its previous run is live, otherwise enqueues its run and writes the new cursor and the
	 * run id in the same transaction, aborting the run if that write fails.
	 *
	 * @param row The claimed row.
	 * @param liveRunIds The previous runs that are still live.
	 * @param writer The framework writer.
	 * @param result The result to update.
	 */
	private static void handleRow(ScheduledJob__c row, Set<Id> liveRunIds, FrameworkWriter writer, CheckResult result)
	{
		Datetime nextCursor;
		try
		{
			TRG_ScheduleJob.resolveJobInstance(row.ClassName__c);
		}
		catch(Exception unresolved)
		{
			String classDetail = String.format(System.Label.ScheduledJob_ParkedClassNotFound, new List<Object> {unresolved.getMessage()});
			LOG_Builder.LogEntry classEntry = LOG_Builder.build().error(unresolved).withSummary(row.SchedulerName__c + ': ' + classDetail);
			park(row, REASON_CLASS_NOT_FOUND, classEntry, writer, result);
			return;
		}
		try
		{
			nextCursor = UTIL_CronExpression.nextFireTime(row.CronExpression__c, result.checkTime, row.Timezone__c);
		}
		catch(Exception unreadable)
		{
			String placementDetail = row.SchedulerName__c + ': ' + System.Label.ScheduledJob_ParkedExpressionCannotBePlaced;
			LOG_Builder.LogEntry placementEntry = LOG_Builder.build().error(unreadable).withSummary(placementDetail);
			park(row, REASON_EXPRESSION_CANNOT_BE_PLACED, placementEntry, writer, result);
			return;
		}
		if(nextCursor == null)
		{
			String horizonDetail = row.SchedulerName__c + ': ' + System.Label.ScheduledJob_ExpressionCannotFireWithinHorizon;
			park(row, REASON_EXPRESSION_CANNOT_FIRE_WITHIN_HORIZON, LOG_Builder.build().error(horizonDetail), writer, result);
			return;
		}
		Id previousRunId = toRunId(row.LastRunJobId__c);
		Boolean previousRunLive = previousRunId != null && liveRunIds.contains(previousRunId);
		if(row.OverlapPolicy__c != OVERLAP_POLICY_ALLOW && previousRunLive)
		{
			skip(row, nextCursor, writer, result);
			return;
		}
		startRun(row, nextCursor, writer, result);
	}

	/**
	 * @description Gives up one run time on a row whose previous run is still going: moves the cursor on, records why,
	 * and says so in the log under the job's name.
	 *
	 * @param row The claimed row.
	 * @param nextCursor The row's next run time.
	 * @param writer The framework writer.
	 * @param result The result to update.
	 */
	private static void skip(ScheduledJob__c row, Datetime nextCursor, FrameworkWriter writer, CheckResult result)
	{
		ScheduledJob__c skippedRow = new ScheduledJob__c(Id = row.Id, NextRunAt__c = nextCursor);
		skippedRow.LastRunOutcome__c = OUTCOME_SKIPPED;
		skippedRow.LastRunReason__c = REASON_PREVIOUS_RUN_STILL_RUNNING;
		writer.updateRecord(skippedRow);
		String skipSummary = row.SchedulerName__c + ': ' + System.Label.ScheduledJob_SkippedPreviousRunStillRunning;
		LOG_Builder.build().info(skipSummary).forRecord(row.Id).emitAt(CHECK_METHOD);
		result.skipped++;
	}

	/**
	 * @description Starts one row's run and writes its new cursor and run id in the same transaction. If that write
	 * fails, the run just queued is called off and the row is left exactly as it was, so the run time is not lost, and
	 * the failure is logged against the row. When the run cannot be called off, the abort's own entry names the row
	 * instead and the check rolls back, so the row is named in exactly one entry either way. The run id is written as an
	 * id, not as text, so it reads back in the same eighteen-character spelling the platform's job table uses and the
	 * next check can tell that this run is still going.
	 *
	 * @param row The claimed row.
	 * @param nextCursor The row's next run time.
	 * @param writer The framework writer.
	 * @param result The result to update.
	 */
	private static void startRun(ScheduledJob__c row, Datetime nextCursor, FrameworkWriter writer, CheckResult result)
	{
		Id runJobId = System.enqueueJob(new Execution(row.Id));
		try
		{
			writer.updateRecord(new ScheduledJob__c(Id = row.Id, NextRunAt__c = nextCursor, LastRunJobId__c = runJobId));
		}
		catch(Exception writeError)
		{
			abortOrThrow(row.Id, runJobId, writeError);
			String writeSummary = row.SchedulerName__c + ': the run was queued, then its row could not be written; the run was called off and the row stays due.';
			LOG_Builder.build().error(writeError).withSummary(writeSummary).forRecord(row.Id).emitAt(CHECK_METHOD);
			result.writeFailures++;
			return;
		}
		result.started++;
	}

	/**
	 * @description Parks a row: records why as a fixed reason, pushes its cursor a day out so it cannot hold the front of
	 * the queue at every check, and emits the given ERROR entry against the record. An edit of the expression, time zone,
	 * mode or active flag resets the cursor, which is how a parked row is un-parked.
	 *
	 * @param row The claimed row.
	 * @param reason The LastRunReason__c value.
	 * @param entry The log entry, already built with its level, message and summary; parked here against the record.
	 * @param writer The framework writer.
	 * @param result The result to update.
	 */
	private static void park(ScheduledJob__c row, String reason, LOG_Builder.LogEntry entry, FrameworkWriter writer, CheckResult result)
	{
		ScheduledJob__c parkedRow = new ScheduledJob__c(Id = row.Id, NextRunAt__c = result.checkTime.addDays(PARKED_CURSOR_PUSH_DAYS));
		parkedRow.LastRunOutcome__c = OUTCOME_PARKED;
		parkedRow.LastRunReason__c = reason;
		writer.updateRecord(parkedRow);
		entry.forRecord(row.Id).emitAt(CHECK_METHOD);
		result.parked++;
	}

	/**
	 * @description Aborts a run whose row write failed. If the abort itself fails, says so in one ERROR entry against
	 * the row first, so the account of both failures survives the rollback, then throws so the whole check rolls back
	 * and every enqueue is discarded with it: either way no run exists without its consumed occurrence, and a check
	 * that calls this names the row in exactly one entry either way.
	 *
	 * @param rowId The row whose write failed.
	 * @param runJobId The run to abort.
	 * @param writeError The write failure being handled.
	 */
	private static void abortOrThrow(Id rowId, Id runJobId, Exception writeError)
	{
		try
		{
			System.abortJob(runJobId);
		}
		catch(Exception abortError)
		{
			String detail = 'The run ' + runJobId + ' was queued, its row could not be written (' + writeError.getMessage() + ')';
			detail += ' and the run could not be aborted (' + abortError.getMessage() + '); the check rolls back.';
			LOG_Builder.build().error(abortError).withSummary(detail).forRecord(rowId).emitAt(CHECK_METHOD);
			throw new UTIL_Exceptions.IllegalStateException(detail);
		}
	}

	/**
	 * @description What one check did. Tests read it; the schedulable ignores it.
	 */
	public class CheckResult
	{
		/**
		 * @description The check time, snapped to the minute; null when the check exited at a guard.
		 */
		public Datetime checkTime;

		/**
		 * @description How many jobs this check was allowed to start.
		 */
		public Integer checkLimit = 0;

		/**
		 * @description Rows whose run was enqueued and whose row write landed.
		 */
		public Integer started = 0;

		/**
		 * @description Rows skipped under the Skip policy.
		 */
		public Integer skipped = 0;

		/**
		 * @description Rows parked.
		 */
		public Integer parked = 0;

		/**
		 * @description Rows whose framework write failed: a skip, a park, or the stamp after an enqueue, in which case the
		 * run was aborted.
		 */
		public Integer writeFailures = 0;

		/**
		 * @description Rows still due after the check because it had already started as many jobs as it may.
		 */
		public Integer leftWaiting = 0;

		/**
		 * @description True when another writer held the rows.
		 */
		public Boolean lockedOut = false;

		/**
		 * @description True when the feature flag stopped the check.
		 */
		public Boolean stoppedByFeatureFlag = false;

		/**
		 * @description True when the running user lacked the permission.
		 */
		public Boolean refusedWithoutPermission = false;

		/**
		 * @description True when the Queueable allowance ran out part way through the check.
		 */
		public Boolean allowanceExhausted = false;
	}

	/**
	 * @description Writes the state the framework owns on ScheduledJob__c (the cursor, the run id, the outcome, the reason
	 * and the last-run time) and the row that records when the runner last checked. ScheduledJob__c is public read-only, so
	 * the running user (the activator, or whoever pressed Run now) may not update records other administrators own: this
	 * class is without sharing and its DML runs in system mode so those writes land. It writes nothing an administrator
	 * edits, with one exception: Deactivate moves a watchdog that rode the runner back to its own scheduled job by writing
	 * ExecutionMode__c through it, so the trigger schedules that job as the deactivator. For Health Check it also inserts
	 * and deletes the runner's own records.
	 */
	public without sharing class FrameworkWriter
	{
		/**
		 * @description Updates one record's framework-owned fields.
		 *
		 * @param record A sparse record: the id and the fields to write.
		 */
		public void updateRecord(ScheduledJob__c record)
		{
			if(simulateRowWriteFailure)
			{
				simulateRowWriteFailure = false;
				throw new DmlException('Simulated row write failure');
			}
			DML_Builder.newTransaction().systemModeInternal().doUpdate(record).execute();
		}

		/**
		 * @description Inserts the runner's own records for Health Check's Activate and Repair.
		 *
		 * @param records The records.
		 *
		 * @return The inserted ids.
		 */
		public List<Id> insertRecords(List<ScheduledJob__c> records)
		{
			return DML_Builder.newTransaction().systemModeInternal().doInsert(records).execute().getInsertedIds();
		}

		/**
		 * @description Deletes the runner's own records for Health Check's Repair and Deactivate, whoever created them.
		 *
		 * @param records The records.
		 */
		public void deleteRecords(List<ScheduledJob__c> records)
		{
			if(records == null || records.isEmpty())
			{
				return;
			}

			DML_Builder.newTransaction().systemModeInternal().doDelete(records).execute();
		}

		/**
		 * @description Records the time of the check that just completed on the JobRunner setting row, creating that row at
		 * the first check.
		 *
		 * @param checkedAt The check clock.
		 */
		public void recordLastCheck(Datetime checkedAt)
		{
			ScheduleSetting__c setting = SEL_ScheduleSetting.getScheduleSetting(LAST_CHECK_SETTING_NAME) ?? new ScheduleSetting__c(Name = LAST_CHECK_SETTING_NAME);
			setting.LastSuccessfulRunTime__c = checkedAt;
			DML_Builder.newTransaction().systemModeInternal().doUpsert(setting).execute();
		}

		/**
		 * @description Takes the runner-management lock: creates the JobRunner setting row if it does not exist yet, then
		 * reads it FOR UPDATE. Activate, Repair and Deactivate call this before they delete or insert runner records, so two
		 * administrators pressing at the same moment serialize instead of both deleting the old set and both inserting a new
		 * one, which would double the clock. The lock is held to the end of the transaction.
		 */
		public void lockRunnerManagement()
		{
			if(SEL_ScheduleSetting.getScheduleSetting(LAST_CHECK_SETTING_NAME) == null)
			{
				DML_Builder.newTransaction().systemModeInternal().doInsert(new ScheduleSetting__c(Name = LAST_CHECK_SETTING_NAME)).execute();
			}
			buildRunnerManagementLock().toList();
		}

		/**
		 * @description The locking read behind lockRunnerManagement. Public so a test can read its SOQL; the lock executes exactly this builder.
		 *
		 * @return The builder, ready to execute.
		 */
		public QRY_Builder.Builder buildRunnerManagementLock()
		{
			return QRY_Builder.selectFrom(ScheduleSetting__c.SObjectType)
					.systemModeInternal()
					.condition(ScheduleSetting__c.Name).equals(LAST_CHECK_SETTING_NAME)
					.forUpdate();
		}
	}

	/**
	 * @description The scheduling context a job on the runner receives. The platform builds its own context only for its
	 * scheduler, so Kern passes this one; getTriggerId returns the run's platform job id, which names the run, not a
	 * scheduled job, so a job must not hand it to System.abortJob.
	 */
	public inherited sharing class RunContext implements SchedulableContext
	{
		/**
		 * @description The run's AsyncApexJob id.
		 */
		private final Id runJobId;

		/**
		 * @description Builds the context for one run.
		 *
		 * @param runJobId The run's AsyncApexJob id.
		 */
		public RunContext(Id runJobId)
		{
			this.runJobId = runJobId;
		}

		/**
		 * @description Returns the job id of the queued run that is executing the job, not the id of a scheduled job. So a
		 * job must not pass it to System.abortJob to stop its schedule.
		 *
		 * @return The run's AsyncApexJob id.
		 */
		public Id getTriggerId()
		{
			return runJobId;
		}
	}

	/**
	 * @description One run of one job on the runner. Re-reads the record as it is when the run starts, resolves the class
	 * by name, injects the parameters exactly as the trigger does, and calls execute with a Kern run context. Allows
	 * callouts, so a job on the runner may call out directly. Its Finalizer records the outcome after the run's own
	 * transaction has ended, so a run that dies of a governor limit still lands as Failed. The run does not catch its
	 * job's exception: a failing job rolls back exactly as it would under the platform scheduler.
	 */
	public inherited sharing class Execution implements Queueable, Database.AllowsCallouts, Finalizer
	{
		/**
		 * @description The record to run.
		 */
		private final Id scheduledJobId;

		/**
		 * @description True when execute already wrote a terminal outcome (or found no record), so the Finalizer writes nothing.
		 */
		private Boolean outcomeAlreadyRecorded = false;

		/**
		 * @description The job's display name, for the Finalizer's log entry.
		 */
		private String jobName;

		/**
		 * @description Builds a run.
		 *
		 * @param scheduledJobId The record to run.
		 */
		public Execution(Id scheduledJobId)
		{
			this.scheduledJobId = scheduledJobId;
		}

		/**
		 * @description Runs the job the record names now, or records why it did not.
		 *
		 * @param context The platform's Queueable context; its job id becomes the run context's trigger id.
		 */
		public void execute(QueueableContext context)
		{
			System.attachFinalizer(this);
			ScheduledJob__c record = new SEL_ScheduledJob().findByIdBypassingSharing(scheduledJobId);
			if(record == null)
			{
				outcomeAlreadyRecorded = true;
				String deleted = 'The scheduled job ' + scheduledJobId + ' was deleted before its run started; nothing ran.';
				LOG_Builder.build().info(deleted).forRecord(scheduledJobId).emitAt(RUN_METHOD);
				return;
			}
			jobName = record.SchedulerName__c;
			if(!record.IsActive__c || !isJobRunnerMode(record))
			{
				ScheduledJob__c offRunner = new ScheduledJob__c(Id = record.Id, LastRunAt__c = Datetime.now());
				offRunner.LastRunOutcome__c = OUTCOME_SKIPPED;
				offRunner.LastRunReason__c = REASON_RECORD_NO_LONGER_ON_RUNNER;
				new FrameworkWriter().updateRecord(offRunner);
				outcomeAlreadyRecorded = true;
				String offRunnerSummary = jobName + ': ' + System.Label.ScheduledJob_SkippedRecordNoLongerOnRunner;
				LOG_Builder.build().info(offRunnerSummary).forRecord(record.Id).emitAt(RUN_METHOD);
				return;
			}
			Schedulable job = TRG_ScheduleJob.resolveJobInstance(record.ClassName__c);
			TRG_ScheduleJob.injectParameters(job, TRG_ScheduleJob.deserializeAttributes(record.Parameters__c));
			job.execute(new RunContext(context.getJobId()));
		}

		/**
		 * @description Records the outcome after the run's transaction ended: Succeeded, or Failed with an ERROR log entry
		 * under the job's name that carries the failure. Writes nothing when the run already recorded its own outcome. If
		 * its own write fails, says so in an entry that names the job and the outcome that could not be written and
		 * stands on its own, because the Log Console is authoritative when a record and its log disagree.
		 *
		 * @param context The Finalizer context: the run's result and, on failure, its exception.
		 */
		public void execute(FinalizerContext context)
		{
			if(outcomeAlreadyRecorded)
			{
				return;
			}
			Boolean runSucceeded = context.getResult() == ParentJobResult.SUCCESS;
			String outcome = runSucceeded ? OUTCOME_SUCCEEDED : OUTCOME_FAILED;
			try
			{
				if(!runSucceeded)
				{
					Exception failure = context.getException();
					String message = failure?.getMessage() ?? System.Label.ScheduledJob_RunFailedWithoutMessage;
					LOG_Builder.LogEntry entry = failure != null ? LOG_Builder.build().error(failure) : LOG_Builder.build().error(message);
					entry.withSummary(describedJob() + ': ' + message).forRecord(scheduledJobId).emitAt(RUN_METHOD);
				}
				recordOutcome(outcome);
			}
			catch(Exception writeError)
			{
				String summary = describedJob() + ': the run ' + outcome;
				summary += ' but that could not be written to the record; this entry is the record of it.';
				LOG_Builder.build().error(writeError).withSummary(summary).forRecord(scheduledJobId).emitAt(RUN_METHOD);
			}
		}

		/**
		 * @description What to call this job in a log entry: its name, or its record id when the run died before it could
		 * read the name.
		 *
		 * @return The job's name, or the record id.
		 */
		private String describedJob()
		{
			return jobName ?? String.valueOf(scheduledJobId);
		}

		/**
		 * @description Writes how the run ended and when, and clears any reason an earlier skip or park left behind: a
		 * failure's detail lives in the log entry, never on the record.
		 *
		 * @param outcome The LastRunOutcome__c value.
		 */
		private void recordOutcome(String outcome)
		{
			ScheduledJob__c finished = new ScheduledJob__c(Id = scheduledJobId, LastRunAt__c = Datetime.now());
			finished.LastRunOutcome__c = outcome;
			finished.LastRunReason__c = null;
			new FrameworkWriter().updateRecord(finished);
		}
	}
}
