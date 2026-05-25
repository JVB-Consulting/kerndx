/**
 * Section 64: UTIL_AsynchronousJobLauncher — Edge Cases (Launch + Verify)
 *
 * First-time section script for UTIL_AsynchronousJobLauncher. No prior section coverage existed.
 * Covers 6 scenarios from the extended-load spec §6.13 with the following framework findings and deviations.
 *
 * Scenarios:
 *   64a. Queueable below threshold — withLimitAtWhichToBatch(50) + 49 items → AUTO selects
 *        PARALLEL_QUEUEABLES (< threshold, queueable slots available). Returns job ID.
 *        AsyncApexJob is verified immediately via SOQL (job is Queued/Processing/Completed).
 *        SPEC NOTE: spec says "JobType = Queueable" but platform AsyncApexJob.JobType for
 *        enqueueJob jobs is "Queueable" (confirmed). PARALLEL_QUEUEABLES enqueues one job per
 *        chunk; single-chunk (49 items, no withQueueableJobSize) → 1 job.
 *
 *   64b. Batch above threshold — withLimitAtWhichToBatch(50) + 51 items → AUTO selects BATCH.
 *        Returns job ID. AsyncApexJob.JobType = 'BatchApex' verified immediately.
 *        SPEC ALIGNMENT: threshold check is `itemCount <= limitAtWhichToBatch` so 51 > 50 → BATCH.
 *
 *   64c. withQueueableJobSize chunking — PARALLEL_QUEUEABLES with queueableJobSize=5 and 11
 *        items → ceil(11/5)=3 parallel jobs. Verified via UTIL_Limits.queueableJobs().used().
 *        This is a synchronous assertion immediately after process(); no async wait needed.
 *        AccountArchiveProcessor subscriber fixture used as the Processable implementation.
 *
 *   64d. withDelayMinutes(2) — SPEC DEVIATION: withDelayMinutes uses System.enqueueJob(handler, minutes)
 *        (delayed Queueable), NOT CronTrigger. CronTrigger is a platform-scheduled job (cron expressions).
 *        Spec said "verify scheduled future via CronTrigger" but that is wrong for this framework API.
 *        OBSERVABLE: process() returns a non-null job ID and AsyncApexJob row exists with the
 *        DelayedDispatchHandler class name in the ApexClass.Name field.
 *        FRAMEWORK FOLLOW-UP: update spec §6.13 #4 to say "delayed Queueable via System.enqueueJob
 *        with delayMinutes" and remove CronTrigger references.
 *
 *   64e. withExecutionStrategy — SPEC DEVIATION: AsynchronousExecutionStrategy enum has no
 *        'SyncOrAsync' value. Actual enum values: AUTO, BATCH, CHAINABLE, PARALLEL_QUEUEABLES.
 *        Spec's "SyncOrAsync — sync below threshold, async above" does not correspond to any
 *        framework enum. OBSERVABLE: explicit BATCH strategy processes items as batch regardless
 *        of count; explicit PARALLEL_QUEUEABLES processes as queueable regardless of count.
 *        FRAMEWORK FOLLOW-UP: update spec §6.13 #5 to reflect actual enum values.
 *
 *   64f. Mid-stream escalation — SPEC DEVIATION: this is not a real framework capability.
 *        UTIL_AdaptiveAsynchronousProcessor.determineCorrectExecutionStrategy() is called once
 *        at initialise() time, before run(). Once CHAINABLE/PARALLEL_QUEUEABLES is chosen, the
 *        queueable path does not escalate to batch mid-execution. The only "escalation" is the
 *        AUTO strategy at init: if queueableJobs().remaining()=0 at initialise() time, it falls
 *        back to BATCH. There is no mid-execution payload growth check.
 *        OBSERVABLE: demonstrate AUTO fallback at init when simulateQueueableLimits=true (this
 *        flag is @TestVisible private, inaccessible from anon Apex in subscriber org).
 *        FRAMEWORK FOLLOW-UP: update spec §6.13 #6 — mid-stream escalation is a speculative
 *        future capability, not implemented. Document as deferred.
 *
 * Deferrals to managed @IsTest harness:
 *   - §6.13 #6 mid-stream escalation: structurally not implemented in the framework. The
 *     UTIL_AdaptiveAsynchronousProcessor.simulateQueueableLimits flag is @TestVisible private
 *     and inaccessible from anon Apex in the subscriber org. Any test requiring that flag must
 *     live in a managed @IsTest class (Subscriber_AsyncJobEdges_TEST) that can reference the
 *     public-managed API without needing @TestVisible access.
 *   - AsyncApexJob terminal-status polling for Queueable (64a) and Batch (64b): polling for
 *     Completed status requires 1-60s of wall-clock. This script verifies job was ENQUEUED
 *     (Queued/Processing/Completed is all acceptable); terminal-status verification would
 *     require a launch+verify split like section-56/56b. Omitted here since JobType is
 *     verifiable at enqueue time and the framework's execution correctness is covered by
 *     the unit test suite.
 *
 * Run-isolation: Creates Account records for 64c processor fixture. All are deleted in cleanup.
 *   Does not depend on prior section state.
 *
 * Prerequisites:
 *   - ${SF_SUBSCRIBER_ORG_ALIAS} org, kern managed package installed.
 *   - AccountArchiveProcessor deployed (release-testing/subscriber/classes/).
 *   - kern__AsynchronousJobSetting__mdt records not required (defaults apply).
 *
 * Run:
 *   sf apex run --file release-testing/scripts/section-64-edge-asyncjob-launcher.apex -o $SF_SUBSCRIBER_ORG_ALIAS
 *
 * Expected wall-clock: 3-8 seconds (no blocking spin-wait; scenarios are synchronous assertions).
 */

System.debug(LoggingLevel.INFO, '');
System.debug(LoggingLevel.INFO, '=== Section 64: UTIL_AsynchronousJobLauncher — Edge Cases ===');

kern.TRG_Base.clearAllBypasses();
kern.UTIL_ValidationRule.clearAllBypasses();

Integer pass = 0;
Integer fail = 0;
List<String> failures = new List<String>();

final String RUN_STAMP_64 = String.valueOf(System.currentTimeMillis());
final Integer THRESHOLD = 50;

// Scenario 64a — Queueable below threshold.
// withLimitAtWhichToBatch(THRESHOLD) + 49 items → AUTO selects PARALLEL_QUEUEABLES (below threshold,
// queueable slots available in the synchronous anon-Apex context). Returns a non-null job ID.
// AsyncApexJob.JobType is verified immediately (the job row exists as soon as enqueueJob returns).
// PARALLEL_QUEUEABLES with no withQueueableJobSize → all 49 items in a single chunk → 1 job.
try
{
	List<Object> items64a = new List<Object>();
	for(Integer i = 0; i < 49; i++)
	{
		items64a.add('item-64a-' + i);
	}

	kern.UTIL_AsynchronousJobLauncher.DTO_AsynchronousJobRequest request64a =
		new kern.UTIL_AsynchronousJobLauncher.DTO_AsynchronousJobRequest(items64a)
			.withLimitAtWhichToBatch(THRESHOLD);

	Id jobId64a = kern.UTIL_AsynchronousJobLauncher.process(request64a, new AccountArchiveProcessor());

	Assert.isNotNull(jobId64a, '64a: process() must return a non-null job ID (49 items, threshold=50 → Queueable)');

	List<AsyncApexJob> jobs64a =
	[
		SELECT Id, JobType, Status
		FROM AsyncApexJob
		WHERE Id = :jobId64a
		LIMIT 1
	];

	Assert.areEqual(1, jobs64a.size(),
		'64a: AsyncApexJob row must exist for the returned job ID. Got: ' + jobs64a.size()
	);

	Assert.areEqual('Queueable', jobs64a[0].JobType,
		'64a: JobType must be "Queueable" for PARALLEL_QUEUEABLES execution (49 < threshold=50). '
		+ 'Got: ' + jobs64a[0].JobType
	);

	Assert.isTrue(
		jobs64a[0].Status == 'Queued'
		|| jobs64a[0].Status == 'Processing'
		|| jobs64a[0].Status == 'Completed',
		'64a: Status must be Queued/Processing/Completed immediately after enqueue. Got: ' + jobs64a[0].Status
	);

	System.debug(LoggingLevel.INFO,
		'64a PASS: 49 items, threshold=50 → JobType=' + jobs64a[0].JobType
		+ ', Status=' + jobs64a[0].Status + ', JobId=' + jobId64a
	);
	pass++;
}
catch(Exception scenarioError)
{
	System.debug(LoggingLevel.ERROR,
		'64a FAIL: ' + scenarioError.getMessage() + '\n' + scenarioError.getStackTraceString()
	);
	failures.add('64a: ' + scenarioError.getMessage());
	fail++;
}

// Scenario 64b — Batch above threshold.
// withLimitAtWhichToBatch(THRESHOLD) + 51 items → AUTO selects BATCH (51 > 50).
// Returns a non-null job ID. AsyncApexJob.JobType = 'BatchApex' verified immediately.
// SPEC ALIGNMENT: determineCorrectExecutionStrategy() checks itemCount <= limitAtWhichToBatch;
// 51 > 50 so the BATCH branch is taken.
try
{
	List<Object> items64b = new List<Object>();
	for(Integer i = 0; i < 51; i++)
	{
		items64b.add('item-64b-' + i);
	}

	kern.UTIL_AsynchronousJobLauncher.DTO_AsynchronousJobRequest request64b =
		new kern.UTIL_AsynchronousJobLauncher.DTO_AsynchronousJobRequest(items64b)
			.withLimitAtWhichToBatch(THRESHOLD);

	Id jobId64b = kern.UTIL_AsynchronousJobLauncher.process(request64b, new AccountArchiveProcessor());

	Assert.isNotNull(jobId64b, '64b: process() must return a non-null job ID (51 items, threshold=50 → Batch)');

	List<AsyncApexJob> jobs64b =
	[
		SELECT Id, JobType, Status
		FROM AsyncApexJob
		WHERE Id = :jobId64b
		LIMIT 1
	];

	Assert.areEqual(1, jobs64b.size(),
		'64b: AsyncApexJob row must exist for the batch job ID. Got: ' + jobs64b.size()
	);

	Assert.areEqual('BatchApex', jobs64b[0].JobType,
		'64b: JobType must be "BatchApex" for BATCH execution (51 > threshold=50). '
		+ 'Got: ' + jobs64b[0].JobType
	);

	Assert.isTrue(
		jobs64b[0].Status == 'Queued'
		|| jobs64b[0].Status == 'Processing'
		|| jobs64b[0].Status == 'Completed'
		|| jobs64b[0].Status == 'Holding',
		'64b: Status must be Queued/Processing/Completed/Holding immediately after submitBatch. Got: ' + jobs64b[0].Status
	);

	System.debug(LoggingLevel.INFO,
		'64b PASS: 51 items, threshold=50 → JobType=' + jobs64b[0].JobType
		+ ', Status=' + jobs64b[0].Status + ', JobId=' + jobId64b
	);
	pass++;
}
catch(Exception scenarioError)
{
	System.debug(LoggingLevel.ERROR,
		'64b FAIL: ' + scenarioError.getMessage() + '\n' + scenarioError.getStackTraceString()
	);
	failures.add('64b: ' + scenarioError.getMessage());
	fail++;
}

// Scenario 64c — withQueueableJobSize chunking.
// PARALLEL_QUEUEABLES with withQueueableJobSize=5 and 11 items → ceil(11/5)=3 parallel Queueables.
// Verified synchronously via UTIL_Limits.queueableJobs().used() count before and after process().
// AccountArchiveProcessor is the Processable; we pass Account objects so the processor can cast them.
// kern.UTIL_ValidationRule.bypassObject('Account') prevents validation rule DML failures.
try
{
	kern.UTIL_ValidationRule.bypassObject('Account');

	final Integer ITEM_COUNT_64C = 11;
	final Integer JOB_SIZE_64C = 5;
	final Integer EXPECTED_JOBS_64C = 3;

	List<Account> accounts64c = new List<Account>();
	for(Integer i = 0; i < ITEM_COUNT_64C; i++)
	{
		accounts64c.add(new Account(Name = 'Section64c_Account_' + i + '_' + RUN_STAMP_64));
	}
	insert accounts64c;

	List<Object> items64c = new List<Object>();
	for(Account a : accounts64c)
	{
		items64c.add(a);
	}

	Integer usedBefore64c = kern.UTIL_Limits.queueableJobs().used();

	kern.UTIL_AsynchronousJobLauncher.DTO_AsynchronousJobRequest request64c =
		new kern.UTIL_AsynchronousJobLauncher.DTO_AsynchronousJobRequest(items64c)
			.withQueueableJobSize(JOB_SIZE_64C)
			.withLimitAtWhichToBatch(ITEM_COUNT_64C + 100)
			.withExecutionStrategy(kern.IF_Async.AsynchronousExecutionStrategy.PARALLEL_QUEUEABLES);

	Id jobId64c = kern.UTIL_AsynchronousJobLauncher.process(request64c, new AccountArchiveProcessor());

	Integer usedAfter64c = kern.UTIL_Limits.queueableJobs().used();
	Integer enqueuedCount64c = usedAfter64c - usedBefore64c;

	Assert.isNotNull(jobId64c, '64c: process() must return a non-null job ID for PARALLEL_QUEUEABLES');

	Assert.areEqual(EXPECTED_JOBS_64C, enqueuedCount64c,
		'64c: PARALLEL_QUEUEABLES with 11 items / jobSize=5 must enqueue ceil(11/5)=3 jobs. '
		+ 'Enqueued: ' + enqueuedCount64c
	);

	System.debug(LoggingLevel.INFO,
		'64c PASS: 11 items, jobSize=5 → ' + enqueuedCount64c + ' parallel Queueables enqueued '
		+ '(expected ' + EXPECTED_JOBS_64C + '). JobId=' + jobId64c
	);
	pass++;
}
catch(Exception scenarioError)
{
	System.debug(LoggingLevel.ERROR,
		'64c FAIL: ' + scenarioError.getMessage() + '\n' + scenarioError.getStackTraceString()
	);
	failures.add('64c: ' + scenarioError.getMessage());
	fail++;
}

// Scenario 64d — withDelayMinutes(2).
// SPEC DEVIATION: withDelayMinutes uses System.enqueueJob(handler, delayMinutes) — a DELAYED QUEUEABLE
// — not CronTrigger. process() returns the enqueued job ID. The AsyncApexJob row can be verified
// immediately; the job sits in Queued/Holding status until the delay elapses.
// The implementing class is UTIL_AsynchronousJobLauncher.DelayedDispatchHandler.
// OBSERVABLE: non-null job ID + AsyncApexJob row for the DelayedDispatchHandler exists.
// CronTrigger is NOT involved — do not query CronTrigger.
try
{
	List<Object> items64d = new List<Object> {'delayed-item-64d-' + RUN_STAMP_64};

	kern.UTIL_AsynchronousJobLauncher.DTO_AsynchronousJobRequest request64d =
		new kern.UTIL_AsynchronousJobLauncher.DTO_AsynchronousJobRequest(items64d)
			.withDelayMinutes(2);

	Id jobId64d = kern.UTIL_AsynchronousJobLauncher.process(request64d, new AccountArchiveProcessor());

	Assert.isNotNull(jobId64d,
		'64d: process() with withDelayMinutes(2) must return a non-null job ID for the DelayedDispatchHandler Queueable'
	);

	List<AsyncApexJob> jobs64d =
	[
		SELECT Id, JobType, Status
		FROM AsyncApexJob
		WHERE Id = :jobId64d
		LIMIT 1
	];

	Assert.areEqual(1, jobs64d.size(),
		'64d: AsyncApexJob row must exist for the DelayedDispatchHandler Queueable. '
		+ 'withDelayMinutes uses System.enqueueJob(handler, minutes) — NOT CronTrigger. '
		+ 'Got: ' + jobs64d.size()
	);

	Assert.areEqual('Queueable', jobs64d[0].JobType,
		'64d: JobType must be "Queueable" — DelayedDispatchHandler is a Queueable, not a scheduled job. '
		+ 'Got: ' + jobs64d[0].JobType
	);

	Assert.isTrue(
		jobs64d[0].Status == 'Queued'
		|| jobs64d[0].Status == 'Processing'
		|| jobs64d[0].Status == 'Holding',
		'64d: Status must be Queued/Processing/Holding for delayed Queueable. Got: ' + jobs64d[0].Status
		+ '. SPEC DEVIATION: spec said CronTrigger; actual is delayed Queueable via System.enqueueJob(handler, 2).'
	);

	System.debug(LoggingLevel.INFO,
		'64d PASS (SPEC DEVIATION — delayed Queueable, not CronTrigger): '
		+ 'withDelayMinutes(2) → JobType=' + jobs64d[0].JobType + ', Status=' + jobs64d[0].Status + ', JobId=' + jobId64d
		+ '. SPEC DEVIATION: §6.13 #4 assumed CronTrigger; actual mechanism is System.enqueueJob(handler, 2). '
		+ 'FRAMEWORK FOLLOW-UP: update spec to reflect delayed-Queueable semantics.'
	);
	pass++;
}
catch(Exception scenarioError)
{
	System.debug(LoggingLevel.ERROR,
		'64d FAIL: ' + scenarioError.getMessage() + '\n' + scenarioError.getStackTraceString()
	);
	failures.add('64d: ' + scenarioError.getMessage());
	fail++;
}

// Scenario 64e — withExecutionStrategy — SPEC DEVIATION.
// AsynchronousExecutionStrategy enum values: AUTO, BATCH, CHAINABLE, PARALLEL_QUEUEABLES.
// Spec §6.13 #5 says "SyncOrAsync — sync below threshold, async above" — this enum value does NOT
// exist. No framework method dispatches synchronously based on record count.
//
// OBSERVABLE: explicit BATCH strategy (11 items) → BatchApex.
//             explicit PARALLEL_QUEUEABLES strategy (3 items) → Queueable.
//             This demonstrates the strategy enum controls the execution mode explicitly.
try
{
	List<Object> batchItems64e = new List<Object>();
	for(Integer i = 0; i < 11; i++)
	{
		batchItems64e.add('batch-item-64e-' + i);
	}

	kern.UTIL_AsynchronousJobLauncher.DTO_AsynchronousJobRequest batchRequest64e =
		new kern.UTIL_AsynchronousJobLauncher.DTO_AsynchronousJobRequest(batchItems64e)
			.withExecutionStrategy(kern.IF_Async.AsynchronousExecutionStrategy.BATCH);

	Id batchJobId64e = kern.UTIL_AsynchronousJobLauncher.process(batchRequest64e, new AccountArchiveProcessor());

	Assert.isNotNull(batchJobId64e, '64e: explicit BATCH strategy must return a job ID');

	List<AsyncApexJob> batchJobs64e =
	[
		SELECT Id, JobType
		FROM AsyncApexJob
		WHERE Id = :batchJobId64e
		LIMIT 1
	];

	Assert.areEqual(1, batchJobs64e.size(), '64e: AsyncApexJob row must exist for BATCH job');
	Assert.areEqual('BatchApex', batchJobs64e[0].JobType,
		'64e: explicit BATCH strategy → JobType=BatchApex. Got: ' + batchJobs64e[0].JobType
	);

	List<Object> queueableItems64e = new List<Object> {'item1', 'item2', 'item3'};

	kern.UTIL_AsynchronousJobLauncher.DTO_AsynchronousJobRequest queueableRequest64e =
		new kern.UTIL_AsynchronousJobLauncher.DTO_AsynchronousJobRequest(queueableItems64e)
			.withExecutionStrategy(kern.IF_Async.AsynchronousExecutionStrategy.PARALLEL_QUEUEABLES);

	Id queueableJobId64e = kern.UTIL_AsynchronousJobLauncher.process(queueableRequest64e, new AccountArchiveProcessor());

	Assert.isNotNull(queueableJobId64e, '64e: explicit PARALLEL_QUEUEABLES strategy must return a job ID');

	List<AsyncApexJob> queueableJobs64e =
	[
		SELECT Id, JobType
		FROM AsyncApexJob
		WHERE Id = :queueableJobId64e
		LIMIT 1
	];

	Assert.areEqual(1, queueableJobs64e.size(), '64e: AsyncApexJob row must exist for PARALLEL_QUEUEABLES job');
	Assert.areEqual('Queueable', queueableJobs64e[0].JobType,
		'64e: explicit PARALLEL_QUEUEABLES strategy → JobType=Queueable. Got: ' + queueableJobs64e[0].JobType
	);

	System.debug(LoggingLevel.INFO,
		'64e PASS (SPEC DEVIATION — no SyncOrAsync enum): '
		+ 'BATCH(11 items)→BatchApex; '
		+ 'PARALLEL_QUEUEABLES(3 items)→' + queueableJobs64e[0].JobType + '. '
		+ 'SPEC DEVIATION: §6.13 #5 "SyncOrAsync" does not exist. Actual enum values: '
		+ 'AUTO, BATCH, CHAINABLE, PARALLEL_QUEUEABLES. '
		+ 'FRAMEWORK FOLLOW-UP: update spec §6.13 #5 to reflect actual enum.'
	);
	pass++;
}
catch(Exception scenarioError)
{
	System.debug(LoggingLevel.ERROR,
		'64e FAIL: ' + scenarioError.getMessage() + '\n' + scenarioError.getStackTraceString()
	);
	failures.add('64e: ' + scenarioError.getMessage());
	fail++;
}

// Scenario 64f — Mid-stream escalation — SPEC DEVIATION.
// Mid-stream Queueable→Batch escalation is NOT a real framework capability. The execution strategy
// is determined ONCE at initialise() time in determineCorrectExecutionStrategy(). There is no
// mid-execution payload growth detection or strategy switch.
//
// OBSERVABLE: AUTO strategy picks BATCH vs PARALLEL_QUEUEABLES at init based on:
//   (a) limitAtWhichToBatch threshold, (b) queueable slots remaining, (c) current async context.
// Once BATCH is chosen, all items go to Database.executeBatch(). Once PARALLEL_QUEUEABLES is
// chosen, all items are chunked up front. No mid-execution escalation occurs.
//
// This scenario demonstrates the AUTO threshold behavior (observable boundary: itemCount == threshold)
// and documents the spec deviation explicitly.
try
{
	List<Object> atThresholdItems64f = new List<Object>();
	for(Integer i = 0; i < THRESHOLD; i++)
	{
		atThresholdItems64f.add('item-64f-' + i);
	}

	kern.UTIL_AsynchronousJobLauncher.DTO_AsynchronousJobRequest atThresholdRequest64f =
		new kern.UTIL_AsynchronousJobLauncher.DTO_AsynchronousJobRequest(atThresholdItems64f)
			.withLimitAtWhichToBatch(THRESHOLD);

	Id atThresholdJobId64f = kern.UTIL_AsynchronousJobLauncher.process(atThresholdRequest64f, new AccountArchiveProcessor());

	Assert.isNotNull(atThresholdJobId64f, '64f: process() must return a non-null job ID (itemCount=threshold boundary)');

	List<AsyncApexJob> atThresholdJobs64f =
	[
		SELECT Id, JobType
		FROM AsyncApexJob
		WHERE Id = :atThresholdJobId64f
		LIMIT 1
	];

	Assert.areEqual(1, atThresholdJobs64f.size(), '64f: AsyncApexJob row must exist for threshold-boundary job');

	Assert.areEqual('Queueable', atThresholdJobs64f[0].JobType,
		'64f: itemCount=50 == threshold=50 → condition is (50 <= 50)=true → Queueable (not Batch). '
		+ 'Got: ' + atThresholdJobs64f[0].JobType
		+ '. This confirms AUTO strategy boundary: <= threshold → Queueable, > threshold → Batch.'
	);

	List<Object> aboveThresholdItems64f = new List<Object>();
	for(Integer i = 0; i < THRESHOLD + 1; i++)
	{
		aboveThresholdItems64f.add('item-64f-above-' + i);
	}

	kern.UTIL_AsynchronousJobLauncher.DTO_AsynchronousJobRequest aboveThresholdRequest64f =
		new kern.UTIL_AsynchronousJobLauncher.DTO_AsynchronousJobRequest(aboveThresholdItems64f)
			.withLimitAtWhichToBatch(THRESHOLD);

	Id aboveThresholdJobId64f = kern.UTIL_AsynchronousJobLauncher.process(aboveThresholdRequest64f, new AccountArchiveProcessor());

	Assert.isNotNull(aboveThresholdJobId64f, '64f: process() must return a non-null job ID (itemCount>threshold boundary)');

	List<AsyncApexJob> aboveThresholdJobs64f =
	[
		SELECT Id, JobType
		FROM AsyncApexJob
		WHERE Id = :aboveThresholdJobId64f
		LIMIT 1
	];

	Assert.areEqual(1, aboveThresholdJobs64f.size(), '64f: AsyncApexJob row must exist for above-threshold job');

	Assert.areEqual('BatchApex', aboveThresholdJobs64f[0].JobType,
		'64f: itemCount=51 > threshold=50 → Batch at init time. Got: ' + aboveThresholdJobs64f[0].JobType
		+ '. SPEC DEVIATION: §6.13 #6 "mid-stream escalation" is not a framework capability. '
		+ 'Strategy is chosen ONCE at initialise() time. No mid-execution growth detection.'
	);

	System.debug(LoggingLevel.INFO,
		'64f PASS (SPEC DEVIATION — no mid-stream escalation): '
		+ 'itemCount=50 (== threshold) → Queueable; '
		+ 'itemCount=51 (> threshold) → BatchApex. '
		+ 'AUTO threshold boundary: itemCount <= limitAtWhichToBatch → Queueable; > → Batch. '
		+ 'SPEC DEVIATION: §6.13 #6 mid-stream escalation is not implemented. '
		+ 'Strategy is fixed at initialise() time. '
		+ 'FRAMEWORK FOLLOW-UP: update spec §6.13 #6 — defer mid-stream escalation to a future PLAN.'
	);
	pass++;
}
catch(Exception scenarioError)
{
	System.debug(LoggingLevel.ERROR,
		'64f FAIL: ' + scenarioError.getMessage() + '\n' + scenarioError.getStackTraceString()
	);
	failures.add('64f: ' + scenarioError.getMessage());
	fail++;
}

// Cleanup — delete any Account rows created by the 64c processor fixture.
delete
[
	SELECT Id
	FROM Account
	WHERE Name LIKE 'Section64c_Account_%'
	  AND CreatedDate = TODAY
	  AND CreatedById = :UserInfo.getUserId()
	LIMIT 500
];

kern.TRG_Base.clearAllBypasses();
kern.UTIL_ValidationRule.clearAllBypasses();

System.debug(LoggingLevel.INFO, '');
System.debug(LoggingLevel.INFO, 'Section 64: ' + pass + ' passed, ' + fail + ' failed');
if(fail > 0)
{
	System.debug(LoggingLevel.ERROR, '=== Section 64 FAILED ===');
	for(String message : failures)
	{
		System.debug(LoggingLevel.ERROR, '  - ' + message);
	}
	throw new System.AssertException('Section 64 failed: ' + fail + ' scenarios');
}
else
{
	System.debug(LoggingLevel.INFO, '=== Section 64 COMPLETE: All scenarios passed ===');
}
