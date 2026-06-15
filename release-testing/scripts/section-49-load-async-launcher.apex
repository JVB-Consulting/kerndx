/**
 * Section 49 (extended-load Phase 3, Tier 2): Load Test — UTIL_AsynchronousJobLauncher Queueable/Batch
 *  threshold (Launch)
 *
 * Stresses kern.UTIL_AsynchronousJobLauncher.process()'s AUTO execution-strategy boundary:
 * `withLimitAtWhichToBatch(50)` + 49 items → Queueable; + 51 items → BatchApex. Captures the
 * synchronous dispatch wall time (the work the calling transaction does to enqueue + return)
 * for both runs, persists the two job IDs into a tagged kern__Foobar__c "handoff" row keyed
 * by run-stamp, asserts the JobType + immediate Status synchronously (which IS observable in
 * the same tx — see SPEC vs ACTUAL below), and exits. Section 49b reads the handoff row,
 * polls AsyncApexJob for terminal status, asserts no items dropped, and emits the per-job
 * PERF_ROW lines.
 *
 * SPEC vs ACTUAL — single-script vs launch+verify split (FRAMEWORK FINDING A36):
 *   The the extended-load spec §7.6 spec + Task 3.3 reference R1 called for a "single script — perf measured
 *   at dispatch time, async observation handled by AsyncApexJob query within the same script's
 *   polling phase". Empirical pre-flight survey demonstrated this is structurally impossible
 *   in Salesforce: Queueables only DEQUEUE after the enqueueing transaction COMMITS. A
 *   busy-wait probe within the launch script polled AsyncApexJob.Status for 3,000 ms after
 *   process() returned and the row stayed at Status='Queued' for the entire window because
 *   the enqueueing tx (the executeAnonymous) had not yet committed; the dequeue + Completed
 *   transition only fires AFTER `sf apex run` exits. The same constraint applies to BatchApex
 *   — Database.executeBatch creates the AsyncApexJob row immediately (Status='Holding') and
 *   does not run start()/execute() until the enqueuing tx commits. Polling for terminal status
 *   inside the same tx burns the 10 s sync CPU governor on no-op SOQL with no behaviour
 *   gained. Adopted: launch+verify split (mirrors section-34/34b, section-48/48b, and
 *   section-56/56b precedent). Launch script captures dispatchWallMs49/dispatchWallMs51 +
 *   IMMEDIATELY-observable JobType (Queueable vs BatchApex per Task 1.13 finding) +
 *   immediate Status (Queued/Holding); verify script (section-49b) polls for terminal
 *   Status='Completed' + NumberOfErrors=0, computes queueableWaitMs / batchExecutionMs from
 *   AsyncApexJob.CompletedDate - CreatedDate, and emits the three PERF_ROW lines for
 *   Phase 2.5's harvester. New finding A36 in plans/the extended-load spec-framework-followups.md captures
 *   the documentation gap (the spec assumed single-script polling worked).
 *
 * SPEC vs ACTUAL — JobType verification position:
 *   Task 1.13 (section-64, commit `e080f4c` + `f68a465`) confirmed AsyncApexJob.JobType is
 *   verifiable IMMEDIATELY after process() returns. The row exists pre-dequeue. So the
 *   JobType=Queueable / JobType=BatchApex assertion lives in THIS script, not the verify
 *   script. The verify script's assertions are: terminal Status, NumberOfErrors=0, and the
 *   batch-only TotalJobItems / JobItemsProcessed.
 *
 * SPEC vs ACTUAL — handoff persistence mechanism:
 *   The two job IDs (jobIdQueueable + jobIdBatch) need to survive the launch→verify gap. We
 *   store them on a single tagged kern__Foobar__c row by serializing JSON into the
 *   kern__TextAreaLong__c field (LongTextArea, 32K capacity — see force-app/main/default/
 *   objects/Foobar__c/fields/TextAreaLong__c.field-meta.xml; chosen because Foobar__c has no
 *   Description__c field). The row is keyed by Name='Section49Load_<runStamp>' so the verify
 *   script can ORDER BY CreatedDate DESC LIMIT 1 to find THIS run's handoff. Cleanup in
 *   section-49b deletes both the handoff row AND the processor's Account fixtures.
 *
 * SPEC vs ACTUAL — processor + side-effect:
 *   Reused AccountArchiveProcessor (release-testing/subscriber/classes/AccountArchiveProcessor.cls)
 *   — same fixture used by Task 1.13's section-64 scenarios. The processor calls DML_Builder
 *   .doUpdate(records) which fires the BeforeUpdate trigger which fires the test flow
 *   TST_SubscriberFlow_SetDefaults (overwrites Description='Default From Flow' + AccountSource
 *   ='Subscriber Flow'). The processor's intent (Description='Archived') is overwritten BUT
 *   the update DML succeeds — confirmed empirically. So the "no items dropped" assertion in
 *   section-49b uses AsyncApexJob.NumberOfErrors=0 (the processor's allowPartial() update
 *   would have surfaced any per-item failures via the AsyncApexJob extended status) instead
 *   of a per-Account field readback. For the BatchApex job, the additional check
 *   JobItemsProcessed = TotalJobItems = 1 (one chunk for 51 items at default batch size 200)
 *   verifies the batch's start→execute→finish sequence ran cleanly.
 *
 * SPEC vs ACTUAL — AsynchronousExecutionStrategy default vs AUTO:
 *   The DTO_AsynchronousJobRequest(items) constructor at UTIL_AsynchronousJobLauncher.cls:302
 *   defaults executionStrategy to AUTO. We rely on AUTO + withLimitAtWhichToBatch(50) for the
 *   threshold-driven branch selection. The script does NOT set .withExecutionStrategy(...)
 *   explicitly so the AUTO path in determineCorrectExecutionStrategy() at
 *   UTIL_AdaptiveAsynchronousProcessor.cls:221 picks up the threshold check
 *   (itemCount <= limitAtWhichToBatch ? Queueable : Batch).
 *
 * SPEC vs ACTUAL — initial baseline + threshold:
 *   First run captures the actual dispatchWallMs49 / dispatchWallMs51 (synchronous portion of
 *   process() — typically 30-100 ms each per probe) and queueableWaitMsAvg / batchExecutionMs
 *   (CompletedDate - CreatedDate; typically 1-5 s for Queueable, 1-30 s for BatchApex in
 *   scratch orgs). Threshold 50% (scheduler jitter is high in scratch orgs). Captured values
 *   land in the commit message and feed Phase 2.5's perf-history harvester via the PERF_ROW
 *   lines emitted by section-49b.
 *
 * BEHAVIOUR ASSERTIONS (HARD GATE — split across launch + verify):
 *   In section-49 (this launch script):
 *     - 49-record dispatch returns a non-null jobIdQueueable
 *     - jobIdQueueable's AsyncApexJob row exists with JobType='Queueable'
 *     - jobIdQueueable's immediate Status ∈ {'Queued','Processing','Completed'} (rules out
 *       a same-tx dequeue race where Status moves to Holding — Holding is a Batch-only state)
 *     - 51-record dispatch returns a non-null jobIdBatch
 *     - jobIdBatch's AsyncApexJob row exists with JobType='BatchApex'
 *     - jobIdBatch's immediate Status ∈ {'Queued','Holding','Processing','Completed'}
 *       (Holding is the typical immediate state for Database.executeBatch)
 *     - Handoff row persists with both job IDs in Description__c JSON
 *   In section-49b (verify script):
 *     - jobIdQueueable terminal Status='Completed' AND NumberOfErrors=0 (within 3 min budget)
 *     - jobIdBatch terminal Status='Completed' AND NumberOfErrors=0 AND
 *       JobItemsProcessed = TotalJobItems = 1 (one chunk processed, no batch errors)
 *     - Both terminal CompletedDate populated
 *
 * PERF METRICS (soft gate — emitted by section-49b after polling):
 *   dispatchWallMs           — average of dispatchWallMs49 + dispatchWallMs51 (this launch
 *                              script measures both and writes them into the handoff row;
 *                              section-49b reads + averages them)
 *   queueableWaitMsAvg       — Queueable CompletedDate - CreatedDate (in ms, single sample
 *                              for the 49-record run; "average" naming retained from spec
 *                              but this is a single-job observation — the metric is the
 *                              wait+execute round-trip)
 *   batchExecutionMs         — BatchApex CompletedDate - CreatedDate (in ms, single sample
 *                              for the 51-record run)
 *
 * Run-isolation: handoff row + Account fixtures are deleted by section-49b cleanup (filter:
 *   Name LIKE 'Section49QHF_%' and Name LIKE 'Section49BHF_%' for Accounts; Foobar Name LIKE
 *   'Section49Load_%' for handoff). Re-running section-49 before section-49b leaves orphan
 *   handoff rows; verify script's ORDER BY CreatedDate DESC LIMIT 1 always picks the latest.
 *
 * Prerequisites:
 *   - subscriber scratch org with kern managed package installed
 *   - AccountArchiveProcessor deployed (release-testing/subscriber/classes/)
 *   - kern__AsynchronousJobSetting__mdt records not required (defaults apply)
 *   - kern__Foobar__c trigger has no configured TriggerAction__mdt (verified — empty), so
 *     the handoff row's BeforeInsert/AfterInsert dispatcher fires but does no per-record work
 *
 * Run (in two stages — separated by ~30-90 s of wall-clock dequeue time):
 *   sf apex run --file release-testing/scripts/section-49-load-async-launcher.apex -o $SF_SUBSCRIBER_ORG_ALIAS
 *   (wait ~30-90 s for both jobs to dequeue and reach Status=Completed)
 *   sf apex run --file release-testing/scripts/section-49b-load-async-launcher-verify.apex -o $SF_SUBSCRIBER_ORG_ALIAS
 *
 * Expected wall-clock for the LAUNCH script: <2 seconds (insert 49+51 Accounts, two
 * process() calls, one Foobar handoff insert). Verify script wall-clock budget: up to 3 min.
 */

System.debug(LoggingLevel.INFO, '');
System.debug(LoggingLevel.INFO, '=== Section 49 (extended-load Phase 3): Load Test — UTIL_AsynchronousJobLauncher (Launch) ===');

kern.TRG_Base.clearAllBypasses();
kern.UTIL_ValidationRule.clearAllBypasses();
kern.UTIL_ValidationRule.bypassObject('Account');

Integer pass = 0;
Integer fail = 0;
List<String> failures = new List<String>();

final String RUN_STAMP_49 = String.valueOf(System.currentTimeMillis());
final String HANDOFF_NAME = 'Section49Load_' + RUN_STAMP_49;
final String ACCOUNT_QUEUEABLE_PREFIX = 'Section49QHF_' + RUN_STAMP_49 + '_';
final String ACCOUNT_BATCH_PREFIX = 'Section49BHF_' + RUN_STAMP_49 + '_';
final Integer THRESHOLD = 50;
final Integer ITEM_COUNT_QUEUEABLE = 49;
final Integer ITEM_COUNT_BATCH = 51;

try
{
	List<Account> accountsQueueable = new List<Account>();
	for(Integer index = 0; index < ITEM_COUNT_QUEUEABLE; index++)
	{
		accountsQueueable.add(new Account(Name = ACCOUNT_QUEUEABLE_PREFIX + index));
	}
	insert accountsQueueable;

	List<Object> itemsQueueable = new List<Object>();
	for(Account record : accountsQueueable)
	{
		itemsQueueable.add(record);
	}

	Long startWallMsQueueable = System.currentTimeMillis();
	kern.UTIL_AsynchronousJobLauncher.DTO_AsynchronousJobRequest requestQueueable =
			new kern.UTIL_AsynchronousJobLauncher.DTO_AsynchronousJobRequest(itemsQueueable)
					.withLimitAtWhichToBatch(THRESHOLD);

	Id jobIdQueueable = kern.UTIL_AsynchronousJobLauncher.process(requestQueueable, new AccountArchiveProcessor());
	Long dispatchWallMsQueueable = System.currentTimeMillis() - startWallMsQueueable;

	Assert.isNotNull(jobIdQueueable,
			'49-launch: 49-item dispatch must return a non-null job ID (49 <= threshold=50 → Queueable)');

	List<AsyncApexJob> jobsQueueable =
	[
			SELECT Id,
					JobType,
					Status
			FROM AsyncApexJob
			WHERE Id = :jobIdQueueable
			LIMIT 1
	];

	Assert.areEqual(1, jobsQueueable.size(),
			'49-launch: AsyncApexJob row must exist for the Queueable job ID. Got: ' + jobsQueueable.size());

	Assert.areEqual('Queueable', jobsQueueable[0].JobType,
			'49-launch: JobType must be "Queueable" for AUTO/49-item/threshold-50 dispatch. '
			+ 'Got: ' + jobsQueueable[0].JobType);

	Assert.isTrue(
			jobsQueueable[0].Status == 'Queued'
			|| jobsQueueable[0].Status == 'Processing'
			|| jobsQueueable[0].Status == 'Completed',
			'49-launch: Queueable Status must be Queued/Processing/Completed immediately after enqueue. '
			+ 'Got: ' + jobsQueueable[0].Status);

	System.debug(LoggingLevel.INFO,
			'49-launch (Queueable side) PASS: ' + ITEM_COUNT_QUEUEABLE + ' items, threshold=' + THRESHOLD
			+ ' → JobType=' + jobsQueueable[0].JobType + ', Status=' + jobsQueueable[0].Status
			+ ', JobId=' + jobIdQueueable + ', dispatchWallMs=' + dispatchWallMsQueueable + 'ms');

	List<Account> accountsBatch = new List<Account>();
	for(Integer index = 0; index < ITEM_COUNT_BATCH; index++)
	{
		accountsBatch.add(new Account(Name = ACCOUNT_BATCH_PREFIX + index));
	}
	insert accountsBatch;

	List<Object> itemsBatch = new List<Object>();
	for(Account record : accountsBatch)
	{
		itemsBatch.add(record);
	}

	Long startWallMsBatch = System.currentTimeMillis();
	kern.UTIL_AsynchronousJobLauncher.DTO_AsynchronousJobRequest requestBatch =
			new kern.UTIL_AsynchronousJobLauncher.DTO_AsynchronousJobRequest(itemsBatch)
					.withLimitAtWhichToBatch(THRESHOLD);

	Id jobIdBatch = kern.UTIL_AsynchronousJobLauncher.process(requestBatch, new AccountArchiveProcessor());
	Long dispatchWallMsBatch = System.currentTimeMillis() - startWallMsBatch;

	Assert.isNotNull(jobIdBatch,
			'49-launch: 51-item dispatch must return a non-null job ID (51 > threshold=50 → BatchApex)');

	List<AsyncApexJob> jobsBatch =
	[
			SELECT Id,
					JobType,
					Status
			FROM AsyncApexJob
			WHERE Id = :jobIdBatch
			LIMIT 1
	];

	Assert.areEqual(1, jobsBatch.size(),
			'49-launch: AsyncApexJob row must exist for the BatchApex job ID. Got: ' + jobsBatch.size());

	Assert.areEqual('BatchApex', jobsBatch[0].JobType,
			'49-launch: JobType must be "BatchApex" for AUTO/51-item/threshold-50 dispatch. '
			+ 'Per Task 1.13 finding, the framework reports "BatchApex" not "BatchApexWorker". '
			+ 'Got: ' + jobsBatch[0].JobType);

	Assert.isTrue(
			jobsBatch[0].Status == 'Queued'
			|| jobsBatch[0].Status == 'Holding'
			|| jobsBatch[0].Status == 'Processing'
			|| jobsBatch[0].Status == 'Completed',
			'49-launch: BatchApex Status must be Queued/Holding/Processing/Completed immediately after submitBatch. '
			+ 'Got: ' + jobsBatch[0].Status);

	System.debug(LoggingLevel.INFO,
			'49-launch (Batch side) PASS: ' + ITEM_COUNT_BATCH + ' items, threshold=' + THRESHOLD
			+ ' → JobType=' + jobsBatch[0].JobType + ', Status=' + jobsBatch[0].Status
			+ ', JobId=' + jobIdBatch + ', dispatchWallMs=' + dispatchWallMsBatch + 'ms');

	Map<String, Object> handoff = new Map<String, Object>
	{
			'jobIdQueueable' => (String)jobIdQueueable,
			'jobIdBatch' => (String)jobIdBatch,
			'dispatchWallMsQueueable' => dispatchWallMsQueueable,
			'dispatchWallMsBatch' => dispatchWallMsBatch,
			'itemCountQueueable' => ITEM_COUNT_QUEUEABLE,
			'itemCountBatch' => ITEM_COUNT_BATCH,
			'threshold' => THRESHOLD,
			'accountQueueablePrefix' => ACCOUNT_QUEUEABLE_PREFIX,
			'accountBatchPrefix' => ACCOUNT_BATCH_PREFIX,
			'runStamp' => RUN_STAMP_49
	};

	kern__Foobar__c handoffRow = new kern__Foobar__c
			(
					Name = HANDOFF_NAME,
					kern__TextAreaLong__c = JSON.serialize(handoff)
			);
	insert handoffRow;

	System.debug(LoggingLevel.INFO,
			'49-launch (handoff) PASS: persisted handoff row ' + handoffRow.Id + ' Name=' + HANDOFF_NAME
			+ ' with both job IDs + dispatch wall times. '
			+ 'Run section-49b after ~30-90 s for terminal-status verification + PERF_ROW emission.');

	pass++;
}
catch(Exception scenarioError)
{
	System.debug(LoggingLevel.ERROR,
			'49-launch FAIL: ' + scenarioError.getMessage() + '\n' + scenarioError.getStackTraceString());
	failures.add('49-launch: ' + scenarioError.getMessage());
	fail++;
}

System.debug(LoggingLevel.INFO, '');
System.debug(LoggingLevel.INFO, 'Section 49 (Launch): ' + pass + ' passed, ' + fail + ' failed');
if(fail > 0)
{
	System.debug(LoggingLevel.ERROR, '=== Section 49 (Launch) FAILED ===');
	for(String message : failures)
	{
		System.debug(LoggingLevel.ERROR, '  - ' + message);
	}
	throw new System.AssertException('Section 49 (Launch) failed: ' + fail + ' scenarios');
}
else
{
	System.debug(LoggingLevel.INFO, '=== Section 49 (Launch) COMPLETE: jobs dispatched. Run section-49b after dequeue (~30-90 s) to verify completion + emit PERF_ROW. ===');
}
