/**
 * Section 49b (extended-load Phase 3, Tier 2): Load Test — UTIL_AsynchronousJobLauncher Queueable/Batch
 *  threshold (Verify)
 *
 * Verification half of the section-49 launch + verify split. Section 49 launches a 49-item
 * Queueable + 51-item BatchApex run and persists both job IDs + per-job dispatchWallMs into a
 * tagged kern__Foobar__c handoff row (Name='Section49Load_<runStamp>'). This script reads the
 * handoff, asserts both AsyncApexJob rows reach Status='Completed' with NumberOfErrors=0
 * within a 3-min wall-clock budget, computes queueableWaitMs / batchExecutionMs from
 * AsyncApexJob.CompletedDate - CreatedDate, and emits the three PERF_ROW lines for Phase 2.5's
 * harvester. Then deletes the handoff row + the launch script's Account fixtures.
 *
 * Polling strategy: bounded retries on the AsyncApexJob status. Most queueables in scratch
 * orgs dequeue + complete within ~1-5 s; batches typically 5-30 s. Script wall-clock budget
 * up to 3 min total, capped at the sync 10 s CPU governor by spinning briefly between SOQL
 * polls (each SOQL poll consumes ~5-10 ms CPU; we cap at ~30 polls before re-evaluating).
 * If still not Completed after the wall budget, the script emits a clear diagnostic + throws
 * AssertException so the operator knows to wait longer + re-run section-49b only.
 *
 * SPEC vs ACTUAL — see section-49 launch script header for the launch+verify split rationale
 *   (FRAMEWORK FINDING A36) — the spec called for single-script polling for completion, which
 *   is structurally impossible because Queueables only dequeue after the enqueueing tx commits.
 *
 * SPEC vs ACTUAL — "no items dropped" via AsyncApexJob counters (not per-Account readback):
 *   The launch script's AccountArchiveProcessor calls DML_Builder.doUpdate(records) which
 *   fires the BeforeUpdate trigger which fires the test flow TST_SubscriberFlow_SetDefaults
 *   (overwrites Description='Default From Flow' + AccountSource='Subscriber Flow'). The
 *   processor's intent (Description='Archived') is overwritten BUT the update DML succeeds.
 *   So per-Account field-readback verification is impossible without reverting the flow,
 *   which would couple this load test to subscriber-fixture state. Instead this script uses:
 *     - AsyncApexJob.NumberOfErrors=0 (any per-item DML failure surfaces here via the
 *       processor's allowPartial() result.errors path)
 *     - For BatchApex: JobItemsProcessed = TotalJobItems = 1 (one chunk for 51 items at the
 *       default batchJobSize=200 — the start→execute→finish sequence ran once cleanly)
 *     - For Queueable: TotalJobItems is always 0 in scratch orgs (queueables don't track
 *       per-item counters) — relies on Status=Completed + NumberOfErrors=0 alone
 *   This is a meaningful signal: any record-level failure inside the processor's update DML
 *   bumps NumberOfErrors via UTIL_AdaptiveAsynchronousProcessor.execute()'s try/catch (line
 *   141-145 in UTIL_AsynchronousJobLauncher.cls). And the processor's per-item update DML is
 *   the ONLY DML the processor performs — there is no other failure path that could "drop"
 *   an item without surfacing as either NumberOfErrors > 0 or the processor's own emit().
 *
 * SPEC vs ACTUAL — "queueableWaitMsAvg" naming (single-sample, not multi):
 *   Spec metric name "queueableWaitMsAvg" implies multiple Queueable observations averaged.
 *   This load test runs ONE Queueable job (the 49-item dispatch). The metric is therefore a
 *   single-sample wait+execute round-trip (CompletedDate - CreatedDate in ms). Naming
 *   retained verbatim from spec for harvester-key continuity; semantics documented here.
 *
 * Cleanup happens at the end of THIS script (not section-49) because the verify queries depend
 * on the handoff row + the launch's Account fixtures still being intact. Cleanup deletes the
 * handoff Foobar__c row (Name LIKE 'Section49Load_%' from TODAY by current user) AND both
 * Account fixture sets (Name LIKE 'Section49QHF_%' / 'Section49BHF_%'). LIMIT 9000 each to
 * stay under DML row governor.
 *
 * Status constants are defined inline (matches section-48b/56b precedent — there is no global
 * SEL_AsyncApexJob constants surface in the framework).
 *
 * Prerequisites:
 *   - Section 49 launch executed in this org within the last few minutes
 *   - At least ~30-90 s of wall-clock time elapsed since launch (queueable typically <5 s,
 *     batch typically <30 s in scratch orgs, but scheduler backpressure can extend this)
 *
 * Run:
 *   sf apex run --file release-testing/scripts/section-49b-load-async-launcher-verify.apex -o $SF_SUBSCRIBER_ORG_ALIAS
 */

System.debug(LoggingLevel.INFO, '');
System.debug(LoggingLevel.INFO, '=== Section 49b (extended-load Phase 3): Load Test — UTIL_AsynchronousJobLauncher (Verify) ===');

kern.TRG_Base.clearAllBypasses();
kern.UTIL_ValidationRule.clearAllBypasses();
kern.UTIL_ValidationRule.bypassObject('Account');

Integer pass = 0;
Integer fail = 0;
List<String> failures = new List<String>();

final String STATUS_COMPLETED = 'Completed';
final String STATUS_FAILED = 'Failed';
final String STATUS_ABORTED = 'Aborted';
final Integer POLL_BUDGET_MS = 180000;
final Integer POLL_INTERVAL_MS = 2000;

String runStamp = '';
String handoffName = '';

try
{
	List<kern__Foobar__c> handoffRows =
	[
		SELECT Id, Name, kern__TextAreaLong__c
		FROM kern__Foobar__c
		WHERE Name LIKE 'Section49Load_%'
		ORDER BY CreatedDate DESC
		LIMIT 1
	];

	Assert.areEqual(1, handoffRows.size(),
		'49b-verify: expected exactly one Section49Load_% handoff row, got ' + handoffRows.size()
			+ ' (was section-49 launched first?)');

	kern__Foobar__c handoffRow = handoffRows[0];
	handoffName = handoffRow.Name;
	Map<String, Object> handoff = (Map<String, Object>)JSON.deserializeUntyped(handoffRow.kern__TextAreaLong__c);

	Id jobIdQueueable = (Id)((String)handoff.get('jobIdQueueable'));
	Id jobIdBatch = (Id)((String)handoff.get('jobIdBatch'));
	Long dispatchWallMsQueueable = (Long)handoff.get('dispatchWallMsQueueable');
	Long dispatchWallMsBatch = (Long)handoff.get('dispatchWallMsBatch');
	Integer itemCountQueueable = (Integer)handoff.get('itemCountQueueable');
	Integer itemCountBatch = (Integer)handoff.get('itemCountBatch');
	runStamp = (String)handoff.get('runStamp');

	System.debug(LoggingLevel.INFO,
		'49b-verify: read handoff ' + handoffName + ' jobIdQueueable=' + jobIdQueueable
			+ ' jobIdBatch=' + jobIdBatch + ' dispatchQ=' + dispatchWallMsQueueable
			+ 'ms dispatchB=' + dispatchWallMsBatch + 'ms');

	Set<Id> jobIds = new Set<Id> {jobIdQueueable, jobIdBatch};
	Long pollStartMs = System.currentTimeMillis();
	Long pollElapsedMs = 0;
	Boolean queueableTerminal = false;
	Boolean batchTerminal = false;
	String lastQueueableStatus = '';
	String lastBatchStatus = '';
	Map<Id, AsyncApexJob> latestRows = new Map<Id, AsyncApexJob>();

	while(pollElapsedMs < POLL_BUDGET_MS && !(queueableTerminal && batchTerminal))
	{
		List<AsyncApexJob> currentRows =
		[
			SELECT Id, JobType, Status, NumberOfErrors, JobItemsProcessed, TotalJobItems,
					CreatedDate, CompletedDate, ExtendedStatus
			FROM AsyncApexJob
			WHERE Id IN :jobIds
		];

		for(AsyncApexJob row : currentRows)
		{
			latestRows.put(row.Id, row);
			Boolean isTerminal = row.Status == STATUS_COMPLETED
				|| row.Status == STATUS_FAILED
				|| row.Status == STATUS_ABORTED;
			if(row.Id == jobIdQueueable)
			{
				if(row.Status != lastQueueableStatus)
				{
					System.debug(LoggingLevel.INFO,
						'49b-verify (Queueable poll @ ' + pollElapsedMs + 'ms): Status='
							+ row.Status + ' (was ' + lastQueueableStatus + ')');
					lastQueueableStatus = row.Status;
				}
				queueableTerminal = isTerminal;
			}
			else if(row.Id == jobIdBatch)
			{
				if(row.Status != lastBatchStatus)
				{
					System.debug(LoggingLevel.INFO,
						'49b-verify (Batch poll @ ' + pollElapsedMs + 'ms): Status='
							+ row.Status + ' (was ' + lastBatchStatus + ')');
					lastBatchStatus = row.Status;
				}
				batchTerminal = isTerminal;
			}
		}

		if(queueableTerminal && batchTerminal)
		{
			break;
		}

		Long spinUntilMs = System.currentTimeMillis() + POLL_INTERVAL_MS;
		while(System.currentTimeMillis() < spinUntilMs && Limits.getCpuTime() < 8000)
		{
			Math.sqrt(2.0);
		}
		pollElapsedMs = System.currentTimeMillis() - pollStartMs;

		if(Limits.getCpuTime() >= 8000)
		{
			System.debug(LoggingLevel.WARN,
				'49b-verify: approaching sync CPU governor (' + Limits.getCpuTime() + '/10000 ms) — '
					+ 'aborting poll loop. If both jobs still not terminal, re-run section-49b only '
					+ '(handoff row persists for re-poll).');
			break;
		}
	}

	AsyncApexJob queueableJob = latestRows.get(jobIdQueueable);
	AsyncApexJob batchJob = latestRows.get(jobIdBatch);

	Assert.isNotNull(queueableJob, '49b-verify: Queueable AsyncApexJob row must be readable');
	Assert.isNotNull(batchJob, '49b-verify: BatchApex AsyncApexJob row must be readable');

	Assert.areEqual(STATUS_COMPLETED, queueableJob.Status,
		'49b-verify: Queueable job (' + jobIdQueueable + ') must reach Status=Completed within '
			+ POLL_BUDGET_MS + ' ms; got Status=' + queueableJob.Status
			+ ', NumberOfErrors=' + queueableJob.NumberOfErrors
			+ ', ExtendedStatus=' + queueableJob.ExtendedStatus
			+ ', elapsed=' + pollElapsedMs + 'ms. If still Queued/Processing, scratch-org scheduler '
			+ 'backpressure is saturating — wait longer + re-run section-49b only.');

	Assert.areEqual(0, queueableJob.NumberOfErrors,
		'49b-verify: Queueable job (' + jobIdQueueable + ') must have NumberOfErrors=0 (no items dropped, '
			+ 'no per-item DML failure surfaced via processor allowPartial()); got '
			+ queueableJob.NumberOfErrors + '. ExtendedStatus=' + queueableJob.ExtendedStatus);

	Assert.areEqual(STATUS_COMPLETED, batchJob.Status,
		'49b-verify: BatchApex job (' + jobIdBatch + ') must reach Status=Completed within '
			+ POLL_BUDGET_MS + ' ms; got Status=' + batchJob.Status
			+ ', NumberOfErrors=' + batchJob.NumberOfErrors
			+ ', JobItemsProcessed=' + batchJob.JobItemsProcessed + '/' + batchJob.TotalJobItems
			+ ', ExtendedStatus=' + batchJob.ExtendedStatus
			+ ', elapsed=' + pollElapsedMs + 'ms. If still Holding/Processing, scratch-org batch '
			+ 'scheduler backpressure is saturating — wait longer + re-run section-49b only.');

	Assert.areEqual(0, batchJob.NumberOfErrors,
		'49b-verify: BatchApex job (' + jobIdBatch + ') must have NumberOfErrors=0 (no items dropped); '
			+ 'got ' + batchJob.NumberOfErrors + '. ExtendedStatus=' + batchJob.ExtendedStatus);

	Assert.areEqual(batchJob.TotalJobItems, batchJob.JobItemsProcessed,
		'49b-verify: BatchApex JobItemsProcessed (' + batchJob.JobItemsProcessed + ') must equal '
			+ 'TotalJobItems (' + batchJob.TotalJobItems + ') — every chunk completed cleanly.');

	Assert.isNotNull(queueableJob.CompletedDate,
		'49b-verify: Queueable CompletedDate must be populated on terminal Status=Completed');

	Assert.isNotNull(batchJob.CompletedDate,
		'49b-verify: BatchApex CompletedDate must be populated on terminal Status=Completed');

	Long queueableWaitMsAvg = queueableJob.CompletedDate.getTime() - queueableJob.CreatedDate.getTime();
	Long batchExecutionMs = batchJob.CompletedDate.getTime() - batchJob.CreatedDate.getTime();
	Long dispatchWallMsAvg = (dispatchWallMsQueueable + dispatchWallMsBatch) / 2;

	Assert.isTrue(queueableWaitMsAvg >= 0,
		'49b-verify: queueableWaitMsAvg must be >= 0; got ' + queueableWaitMsAvg);

	Assert.isTrue(batchExecutionMs >= 0,
		'49b-verify: batchExecutionMs must be >= 0; got ' + batchExecutionMs);

	Map<String, Object> dispatchRow = new Map<String, Object>
	{
		'section' => 49,
		'metric' => 'dispatchWallMs',
		'value' => dispatchWallMsAvg
	};
	Map<String, Object> queueableWaitRow = new Map<String, Object>
	{
		'section' => 49,
		'metric' => 'queueableWaitMsAvg',
		'value' => queueableWaitMsAvg
	};
	Map<String, Object> batchExecutionRow = new Map<String, Object>
	{
		'section' => 49,
		'metric' => 'batchExecutionMs',
		'value' => batchExecutionMs
	};
	System.debug(LoggingLevel.INFO, 'PERF_ROW: ' + JSON.serialize(dispatchRow));
	System.debug(LoggingLevel.INFO, 'PERF_ROW: ' + JSON.serialize(queueableWaitRow));
	System.debug(LoggingLevel.INFO, 'PERF_ROW: ' + JSON.serialize(batchExecutionRow));

	System.debug(LoggingLevel.INFO,
		'49b-verify PASS: Queueable ' + jobIdQueueable + ' Completed ('
			+ itemCountQueueable + ' items, NumberOfErrors=' + queueableJob.NumberOfErrors
			+ ', wait=' + queueableWaitMsAvg + 'ms). '
			+ 'BatchApex ' + jobIdBatch + ' Completed (' + itemCountBatch
			+ ' items, NumberOfErrors=' + batchJob.NumberOfErrors
			+ ', JobItemsProcessed=' + batchJob.JobItemsProcessed + '/' + batchJob.TotalJobItems
			+ ', exec=' + batchExecutionMs + 'ms). '
			+ 'dispatchWallMsAvg=' + dispatchWallMsAvg + 'ms (Queueable=' + dispatchWallMsQueueable
			+ 'ms, Batch=' + dispatchWallMsBatch + 'ms). '
			+ 'Total verify wall=' + pollElapsedMs + 'ms.');
	pass++;
}
catch(Exception scenarioError)
{
	System.debug(LoggingLevel.ERROR,
		'49b-verify FAIL: ' + scenarioError.getMessage() + '\n' + scenarioError.getStackTraceString());
	failures.add('49b-verify: ' + scenarioError.getMessage());
	fail++;
}

try
{
	List<kern__Foobar__c> residualHandoff =
	[
		SELECT Id
		FROM kern__Foobar__c
		WHERE Name LIKE 'Section49Load_%'
		  AND CreatedDate = TODAY
		  AND CreatedById = :UserInfo.getUserId()
		LIMIT 9000
	];
	if(!residualHandoff.isEmpty())
	{
		delete residualHandoff;
		System.debug(LoggingLevel.INFO,
			'Cleanup: deleted ' + residualHandoff.size() + ' Section49Load_% handoff Foobar__c row(s)');
	}

	List<Account> residualQueueableAccounts =
	[
		SELECT Id
		FROM Account
		WHERE Name LIKE 'Section49QHF_%'
		  AND CreatedDate = TODAY
		  AND CreatedById = :UserInfo.getUserId()
		LIMIT 9000
	];
	if(!residualQueueableAccounts.isEmpty())
	{
		delete residualQueueableAccounts;
		System.debug(LoggingLevel.INFO,
			'Cleanup: deleted ' + residualQueueableAccounts.size() + ' Section49QHF_% Account row(s)');
	}

	List<Account> residualBatchAccounts =
	[
		SELECT Id
		FROM Account
		WHERE Name LIKE 'Section49BHF_%'
		  AND CreatedDate = TODAY
		  AND CreatedById = :UserInfo.getUserId()
		LIMIT 9000
	];
	if(!residualBatchAccounts.isEmpty())
	{
		delete residualBatchAccounts;
		System.debug(LoggingLevel.INFO,
			'Cleanup: deleted ' + residualBatchAccounts.size() + ' Section49BHF_% Account row(s)');
	}
}
catch(Exception cleanupError)
{
	System.debug(LoggingLevel.WARN,
		'49b cleanup warning (handoff/Account delete failed): ' + cleanupError.getMessage());
}

System.debug(LoggingLevel.INFO, '');
System.debug(LoggingLevel.INFO, 'Section 49b (Verify): ' + pass + ' passed, ' + fail + ' failed');
if(fail > 0)
{
	System.debug(LoggingLevel.ERROR, '=== Section 49b (Verify) FAILED ===');
	for(String message : failures)
	{
		System.debug(LoggingLevel.ERROR, '  - ' + message);
	}
	throw new System.AssertException('Section 49b (Verify) failed: ' + fail + ' scenarios');
}
else
{
	System.debug(LoggingLevel.INFO, '=== Section 49b (Verify) COMPLETE: All scenarios verified + PERF_ROW emitted ===');
}
