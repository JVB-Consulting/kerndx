// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Tests for how UTIL_AsyncChain recovers chains that went wrong. They cover:
 * the run key (a value each job of a run carries, so a job from an older attempt cannot write to the run);
 * stalled chains; the watchdog sweep (the scheduled job that looks for chains that stopped moving);
 * re-drive (starting a stalled or failed chain again); checking whether a chain's job is still alive;
 * and the markers a step leaves so a resumed chain knows where it was.
 * They are kept apart from UTIL_AsyncChain_TEST because one class with all the tests was at the code
 * inspection's complexity limit, and the recovery code can be reviewed on its own.
 *
 * @see UTIL_AsyncChain
 * @see UTIL_AsyncChain_TEST
 *
 * @author Jason van Beukering
 *
 * @group Async
 *
 * @date July 2026, October 2026
 */
@IsTest(seeAllData=false isParallel=false)
@SuppressWarnings('PMD.CyclomaticComplexity,PMD.NcssTypeCount')
private class UTIL_AsyncChainRecovery_TEST
{
	/**
	 * @description Company name given to the admin user created in test setup. It is unique to this class, so getTestAdmin
	 * can find that one user again by company name.
	 */
	private static final String TEST_ADMIN_COMPANY = 'UTIL_AsyncChainRecovery_TEST-admin';

	/**
	 * @description Name used for test chains.
	 */
	private static final String TEST_CHAIN_NAME = 'TestChain';

	/**
	 * @description The test's own copy of the note a finished chain keeps when its handler could not be queued: {0} is
	 * the handler's position (onError or onComplete), {1} the handler's name.
	 */
	private static final String HANDLER_NOT_QUEUED_NOTE_FORMAT = System.Label.AsyncChain_HandlerNotQueued;

	/**
	 * @description The test's own copy of the error log naming the chain and its end status ahead of that note: {0} is
	 * the chain name, {1} the status the chain ended with, {2} the note.
	 */
	private static final String HANDLER_NOT_QUEUED_LOG_FORMAT = 'Chain {0} ended {1}: {2}';

	/**
	 * @description Position name of an error handler, as the engine names it in a note about a handler that did not run.
	 */
	private static final String ERROR_HANDLER_POSITION = 'onError';

	/**
	 * @description Position name of a completion handler, as the engine names it in a note about a handler that did not run.
	 */
	private static final String COMPLETION_HANDLER_POSITION = 'onComplete';

	/**
	 * @description Failure message returned by IdempotentFailingStep.
	 */
	private static final String IDEMPOTENT_FAILURE_MESSAGE = 'Deliberate failure of a step declared safe to re-run';

	/**
	 * @description The test's own copy of the longest message a step entry keeps in the saved step log: the engine
	 * shortens a longer one to this many characters.
	 */
	private static final Integer STEP_MESSAGE_CAPACITY = 255;

	/**
	 * @description Context key prefix under which StartObservingStep records the started marker it read on its own step
	 * entry while its work ran: key = prefix + step index, value = the marker (true, or null when the entry carried none).
	 */
	private static final String START_SEEN_KEY_PREFIX = 'startSeenAtStep';

	/**
	 * @description Context key SuccessStep counts its runs under: each run adds one, so the value after a recovery says
	 * how many times the step ran across the original run and the re-drive (the run started again).
	 */
	private static final String STEP_COUNT_KEY = 'stepCount';

	/**
	 * @description Marker a HandlerSideEffectStep writes onto its execution record through its own DML. The test of the
	 * run key check when a handler starts looks for this marker. The marker is saved with the handler's work, apart
	 * from the framework's status save. So if the marker is missing, the work never ran; it is not only that a later
	 * status save was blocked.
	 */
	private static final String HANDLER_SIDE_EFFECT_MARKER = 'HandlerSideEffectCommitted';

	/**
	 * @description Number of times a CountingErrorHandlerStep has run in this test transaction.
	 * The stall-notification tests assert on it to prove the onError handler fires exactly once
	 * each time the chain moves into Stalled. It is a test-only counter, set the same way as the production simulateCrash
	 * flag.
	 */
	private static Integer errorHandlerRunCount = 0;

	/**
	 * @description Number of times a CountingFailingStep has run in this test transaction. The
	 * upgrade test (a record saved by a package version from before the upgrade, then run by the
	 * current version) asserts on it to prove a pre-upgrade step log yields exactly one attempt,
	 * with no retry consulted.
	 */
	private static Integer failingStepRunCount = 0;

	/**
	 * @description Number of times RotateAndFailWithRetryStep's retry strategy has been asked in this test transaction.
	 * The test of a blocked retry checks it to prove the failure handling took the retry path. The unchanged record
	 * then proves the run key check in scheduleRetry blocked the save, not the check on the final save. Both blocked
	 * saves leave the same record.
	 */
	private static Integer retryStrategyConsultCount = 0;

	/**
	 * @description Number of times an IdempotentRecoveringStep has run in this test transaction.
	 * The operator retry tests check it to prove that exactly the failed step runs again, never a
	 * step whose success marker stays after the reset.
	 */
	private static Integer retriedStepRunCount = 0;

	/**
	 * @description Number of times a CountingRotateRunKeyStep has run in this test transaction. The started-step tests
	 * assert on it to prove the watchdog never ran the step again after the step ran once and left no saved result.
	 */
	private static Integer rotatingStepRunCount = 0;

	/**
	 * @description Stale threshold that treats a chain created just now as fresh, for the watchdog tests where the
	 * sweep must leave the row alone. With SWEEP_EVERYTHING_THRESHOLD_MINUTES it lets one test check both cases (left
	 * alone, and marked) on rows created just now, without setting any audit field to an earlier date.
	 */
	private static final Integer FRESH_THRESHOLD_MINUTES = 30;

	/**
	 * @description Negative stale threshold that places the cutoff in the future, so every seeded
	 * chain counts as stale (the other case of the pair described on the constant above).
	 */
	private static final Integer SWEEP_EVERYTHING_THRESHOLD_MINUTES = -1;

	/**
	 * @description Batch size used by the watchdog sweep tests. Equals the sweep's batch ceiling, so
	 * the clamp test can assert the marked count against it directly.
	 */
	private static final Integer WATCHDOG_BATCH_SIZE = 50;

	/**
	 * @description Seed count deliberately above the sweep's 50-chain batch ceiling, proving the
	 * clamp: a sweep asked for this many chains must still mark only WATCHDOG_BATCH_SIZE of them.
	 */
	private static final Integer OVERSIZED_SWEEP_SEED_COUNT = 60;

	/**
	 * @description The test's own copy of the reason the sweep records when it sets a candidate aside (marks it
	 * Stalled for a later sweep) instead of handling it, because the transaction can add no more Queueable jobs.
	 */
	private static final String PARKED_NO_BUDGET_REASON = 'Parked: no async budget';

	/**
	 * @description The test's own copy of the reason the sweep records when it sets the remaining candidates aside,
	 * because the transaction has almost no database queries left.
	 */
	private static final String PARKED_NO_QUERY_BUDGET_REASON = 'Parked: no query budget';

	/**
	 * @description Number of queries the sweep is left to start with, so that exactly one candidate can be handled:
	 * 1. The selector's own read uses one. That leaves the three queries kept free for each candidate, so the
	 *    first candidate's decision steps run, and reading it again to mark it uses another.
	 * 2. With two left, the check refuses the second candidate.
	 * 3. The remaining candidates are set aside one per query left, until none are left.
	 */
	private static final Integer QUERY_BUDGET_FOR_ONE_SWEPT_CANDIDATE = 4;

	/**
	 * @description Seed count for the test that sets candidates aside when queries run low: one candidate handled
	 * normally, two set aside (one per query left), and one left untouched when no queries are left.
	 */
	private static final Integer QUERY_PARK_SEED_COUNT = 4;

	/**
	 * @description Seed count for the tests of the operator's Clear Stalled sweep when limits run low: every seeded
	 * candidate must be left untouched when a limit check refuses to run the first candidate's decision steps.
	 */
	private static final Integer CLEAR_STALLED_TAIL_SEED_COUNT = 2;

	/**
	 * @description Number of queries the operator's Clear Stalled sweep is left to start with, so its limit check
	 * refuses every candidate. The candidate selector's own read uses one and leaves two. That is below the four
	 * queries the operator sweep keeps free for each candidate. So the check stops before the first candidate, while
	 * the one read that counts the results can still run.
	 */
	private static final Integer QUERY_BUDGET_FOR_NO_SWEPT_OPERATOR_CANDIDATES = 3;

	/**
	 * @description Number of DML statements the operator's Clear Stalled sweep is left to start with, so its limit
	 * check refuses every candidate. Two statements left is below the three the operator sweep keeps free for each
	 * candidate. The sweep's read-only steps (the candidate read and the read that counts the results) use none.
	 */
	private static final Integer DML_BUDGET_FOR_NO_SWEPT_OPERATOR_CANDIDATES = 2;

	/**
	 * @description Number of queries below the two the operator sweep needs to start, so the check at the start refuses
	 * before the candidate read runs. The check inside the loop can never see this case.
	 */
	private static final Integer QUERY_BUDGET_BELOW_OPERATOR_ENTRY_MINIMUM = 1;

	/**
	 * @description Stall reason seeded on a candidate BEFORE an operator sweep runs, distinct from
	 * every reason the sweep can write, so a test can prove whether the sweep touched the row.
	 */
	private static final String PRE_SWEEP_SEEDED_REASON = 'Seeded reason before operator sweep';

	/**
	 * @description A context value that parses as valid JSON but is a LIST, not an object. The job that runs a step
	 * casts the context straight to an object when it loads it. The retry check must refuse it: a check that only
	 * parsed it would accept it, queue the job, and the job would fail as it starts.
	 */
	private static final String NON_OBJECT_CONTEXT_JSON = '["valid json","but a list","never an object"]';

	/**
	 * @description Minutes by which the newer-activity test sets its hand-built copy of the sweep's row to an earlier
	 * time. So the real row's LastModifiedDate is surely newer than the copy that the re-drive receives.
	 */
	private static final Integer BACKDATED_SWEEP_VIEW_AGE_MINUTES = 5;

	/**
	 * @description The test's own copy of part of the reason the re-drive records when it cannot rebuild a runnable
	 * chain from a candidate's saved step log. The reason tells the reader what to do.
	 */
	private static final String REDRIVE_UNRECOVERABLE_FRAGMENT = 'step log is missing, unreadable, or inconsistent';

	/**
	 * @description The attempt number a retry-pending step-log entry carries after its first failed
	 * attempt scheduled a retry: scheduleRetry bumps the 1-based attempt to 2 and clears the
	 * entry's success marker.
	 */
	private static final Integer RETRY_PENDING_ATTEMPT = 2;

	/**
	 * @description Percentage of a valid pre-upgrade step-log document the truncation fixture
	 * keeps. Cutting at this point lands in the middle of the array, inside the second entry. So the document is JSON
	 * that started well and stopped suddenly, which is what a row that was only partly written leaves behind.
	 */
	private static final Integer TRUNCATED_STEP_LOG_PERCENT = 60;

	/**
	 * @description The value LOG_Engine saves to LogLevel__c for an ERROR entry: LOG_Engine
	 * writes LoggingLevel.name(), so taking this constant from the same enum keeps the checked
	 * value the same as what is recorded.
	 */
	private static final String LOG_LEVEL_ERROR = LoggingLevel.ERROR.name();

	/**
	 * @description The value LOG_Engine saves to LogLevel__c for a WARN entry: LOG_Engine
	 * writes LoggingLevel.name(), so taking this constant from the same enum keeps the checked
	 * value the same as what is recorded.
	 */
	private static final String LOG_LEVEL_WARN = LoggingLevel.WARN.name();

	/**
	 * @description Payload length guaranteed to push the serialized chain context past the
	 * ContextData__c field capacity (131,072 characters). The save after a failure keeps the context whole or not
	 * at all, so it must drop the context instead of cutting it short.
	 */
	private static final Integer OVERSIZED_CONTEXT_PAYLOAD_LENGTH = 140000;

	/**
	 * @description Context key the context-bloating fixture steps write their oversized payload under.
	 */
	private static final String OVERSIZED_CONTEXT_PAYLOAD_KEY = 'oversizedPayload';

	/**
	 * @description Context size limit, set when the chain is built, above the ContextData__c field capacity. So the
	 * test steps that grow the context always reach the field-length check in the save after a failure, not the
	 * size check that runs while the chain runs, even if the test steps change later.
	 */
	private static final Integer MAX_CONTEXT_SIZE_ABOVE_FIELD_CAPACITY = 262144;

	/**
	 * @description Failure message that the test step which grows the context returns. It is the test's own copy of
	 * the message that the context-not-kept marker is added to.
	 */
	private static final String OVERSIZED_CONTEXT_FAILURE_MESSAGE = 'Deliberate failure with oversized context';

	/**
	 * @description The test's own copy of the ErrorMessage__c field capacity in characters. The test that checks the
	 * marker survives fails with a message of exactly this length. That leaves no room to add the marker, unless the
	 * save after a failure keeps room for it first.
	 */
	private static final Integer ERROR_MESSAGE_FIELD_CAPACITY = 32768;

	/**
	 * @description Name used for the operator retry-from-failed-step test chains, keeping their
	 * records and log entries distinguishable from the watchdog fixtures'.
	 */
	private static final String RETRY_TEST_CHAIN_NAME = 'RetryTestChain';

	/**
	 * @description Step count of the retry fixtures' hand-built step log: one completed step and
	 * one failed step.
	 */
	private static final Integer RETRY_TOTAL_STEPS = 2;

	/**
	 * @description Completed-step count of the retry fixtures' hand-built step log: only the first
	 * step succeeded before the terminal failure.
	 */
	private static final Integer RETRY_COMPLETED_STEPS = 1;

	/**
	 * @description Context document that the retry tests save and that parses. It has exactly the shape a ChainContext
	 * has when saved in the middle of a chain, so the job that runs the chain again can load it.
	 */
	private static final String RETRY_CONTEXT_JSON = JSON.serialize(new Map<String, Object> {'stepCount' => 1});

	/**
	 * @description A step-log value that is not JSON at all, for the case where the retry is refused because the step
	 * log cannot be parsed.
	 */
	private static final String MALFORMED_STEP_LOG_JSON = 'not step-log json';

	/**
	 * @description A context value that is not JSON at all, for the case where the retry is refused because the context
	 * cannot be parsed. Only the check that parses the context can catch this case.
	 */
	private static final String MALFORMED_CONTEXT_JSON = 'not context json';

	/**
	 * @description The used-up attempt count the retry tests set on the failed entry. It proves the operator retry
	 * starts the attempt count again instead of going on from one that is used up.
	 */
	private static final Integer RETRY_PRIOR_ATTEMPT_COUNT = 3;

	/**
	 * @description Duration the retry tests set on the seeded finished row. It proves the operator retry clears the
	 * old details in its one update, which writes only the fields that change.
	 */
	private static final Integer RETRY_SEEDED_DURATION_MS = 1000;

	/**
	 * @description Minutes between the start and the end of a failed run seeded with a chosen end time, so the start
	 * always comes before the end.
	 */
	private static final Integer RETRY_SEEDED_RUN_MINUTES = 5;

	/**
	 * @description How many minutes in the past flipToAborted sets the abort's end time. Because that time is old, a test
	 * can tell it apart from an end time the running chain would write now.
	 */
	private static final Integer EXTERNAL_ABORT_AGE_MINUTES = 60;

	/**
	 * @description The words the handler Finalizer logs when the onError notification of a stalled run crashes. They say
	 * only that the record was not changed, which holds whether or not another executor has taken the run over since.
	 */
	private static final String STALLED_NOTIFICATION_CRASH_LOG_FRAGMENT = 'Stalled-run notification failed; the run record was not changed';

	/**
	 * @description Days since the seeded run started: past the 115.7 days DurationMs__c can hold in milliseconds.
	 */
	private static final Integer OVERLONG_RUN_AGE_DAYS = 120;

	/**
	 * @description The test's own copy of the largest duration DurationMs__c can store: all nines, to the field's own
	 * precision.
	 */
	private static final Long EXPECTED_STORED_DURATION_MAX = Long.valueOf('9'.repeat(AsyncChainExecution__c.DurationMs__c.getDescribe().getPrecision()));

	/**
	 * @description The reason the overlong-run abort test records.
	 */
	private static final String OVERLONG_ABORT_REASON = 'Aborted by the duration cap test';

	/**
	 * @description How long the seeded run sat failed before the operator's retry, in minutes: the wait the marker must report.
	 */
	private static final Integer MANUAL_RETRY_SEEDED_WAIT_MINUTES = 37;

	/**
	 * @description The shorter wait seeded before a second retry of the same step, so an overwritten marker is told from a kept one.
	 */
	private static final Integer MANUAL_RETRY_SECOND_WAIT_MINUTES = 5;

	/**
	 * @description Milliseconds in a minute, for turning the seeded waits into the unit the marker stores.
	 */
	private static final Long MILLISECONDS_PER_MINUTE = 60000L;

	/**
	 * @description The test's own copy of the engine's "retried manually, wait unknown" value.
	 */
	private static final Long EXPECTED_MANUAL_RETRY_WAIT_UNKNOWN = -1L;

	/**
	 * @description Seconds of slack needed to compare a saved Datetime with one held in memory. A DateTime field keeps whole
	 * seconds only: the platform drops the milliseconds of the value written to it, so a stamp read back is up to one second
	 * earlier than the in-memory instant the engine stamped. Measured on the development org: 1789914071055 in, 1789914071000
	 * back. Comparing two saved stamps needs no slack, so only the in-memory comparison carries this.
	 */
	private static final Integer PERSISTED_DATETIME_TOLERANCE_SECONDS = 1;

	/**
	 * @description Characters the near-capacity fixture leaves free in StepLog__c once the failed entry is cleared. The marker's
	 * own length varies with the wait it carries. These fixtures seed a completion an instant before the retry, so the value is
	 * one to four digits and the member is 23 to 26 characters. The value must be between 71 and 122. At 122 and below, the
	 * marker plus the per-step runtime reserve does not fit even at the marker's shortest (23 + 100), so the retry leaves the
	 * marker off. From 71 up, the marker at its longest (26) and the retried step's own result (about 42) both still fit. So a
	 * run that wrongly kept the marker completes, and fails this test on the marker, not on an overflow. A new runtime member on
	 * the step entry changes this arithmetic. The fixtures' failed entries already carry the started marker the retry writes,
	 * so the retry adds none.
	 */
	private static final Integer NEAR_CAPACITY_HEADROOM = 85;

	/**
	 * @description Characters the barely-fitting fixture leaves free once the failed entry is cleared. The window is 16 to 22: at
	 * least 16, so the seeded document (the cleared form plus the failed entry's 16-character failed marker) still fits the field;
	 * under 23, so the cleared form plus the shortest manual retry marker does not.
	 */
	private static final Integer BARELY_FITTING_HEADROOM = 18;

	/**
	 * @description Characters the two-steps-to-go fixture leaves free once the failed entry is cleared. The window is 126 to 222:
	 * at least one per-step runtime reserve plus the marker at its longest (100 + 26), so a rule that reserved for one step would
	 * keep the marker; at most two reserves plus the marker at its shortest, less one (200 + 23 - 1), so the real rule, with two
	 * steps yet to record, leaves it off whatever wait the marker carries.
	 */
	private static final Integer TWO_STEPS_TO_GO_HEADROOM = 130;

	/**
	 * @description Failure message the retry fixtures stamp on the failed entry and the seeded row.
	 */
	private static final String RETRY_FAILURE_MESSAGE = 'Deliberate retryable failure at step two';

	/**
	 * @description Deduplication key that the tests of a retry taking the key back declare when they seed the run.
	 */
	private static final String RETRY_DECLARED_DEDUPLICATION_KEY = 'retry-declared-deduplication-key';

	/**
	 * @description Name used for the operator restart-from-start test chains.
	 */
	private static final String RESTART_TEST_CHAIN_NAME = 'RestartTestChain';

	/**
	 * @description The framework's reserved context key for the serialized logging context. It is
	 * copied here because the production constant is private. If either copy changes, the restart
	 * correlation tests fail.
	 */
	private static final String CONTEXT_LOG_KEY = '__logContext';

	/**
	 * @description The logging-context document's correlation field name, as LOG_Engine's context
	 * DTO serializes it.
	 */
	private static final String LOG_CONTEXT_CORRELATION_FIELD = 'correlationId';

	/**
	 * @description Correlation id written into the logging entry of the seeded copy of the starting data. It stands for
	 * the source run's active correlation when the chain was built. The new run a restart makes must NEVER keep this
	 * value.
	 */
	private static final String SOURCE_LOG_CORRELATION_ID = 'source-log-correlation';

	/**
	 * @description Context key that the restart tests seed into the copy of the starting data, beside the logging
	 * context. It proves the new run starts again from the values as the chain was built.
	 */
	private static final String RESTART_SNAPSHOT_KEY = 'restartSeed';

	/**
	 * @description Value the restart fixtures seed under RESTART_SNAPSHOT_KEY.
	 */
	private static final String RESTART_SNAPSHOT_VALUE = 'restart-seed-value';

	/**
	 * @description The chain suite's step that launches a child chain whose own step launches a grandchild, named the
	 * way a saved step log names it, so a seeded run can be restarted into three levels of launches.
	 */
	private static final String NESTED_LAUNCH_STEP_CLASS_NAME = 'UTIL_AsyncChain_TEST.NestedLaunchingStep';

	/**
	 * @description The chain suite's step that launches a one-step child chain, named the way a seeded step log names
	 * it (UTIL_AsyncChain_TEST.LaunchingStep; a rename there must follow here).
	 */
	private static final String LAUNCHING_STEP_CLASS_NAME = 'UTIL_AsyncChain_TEST.LaunchingStep';

	/**
	 * @description The chain name that step launches (UTIL_AsyncChain_TEST.CHILD_CHAIN_NAME).
	 */
	private static final String LAUNCHING_STEP_CHILD_CHAIN_NAME = 'ChildChain';

	/**
	 * @description The chain name of a child seeded as launched by an earlier run of a retried step.
	 */
	private static final String EARLIER_CHILD_CHAIN_NAME = 'EarlierChildChain';

	/**
	 * @description The suffix the framework appends to a run's id to key a launch from its second step, the failed
	 * step of the retry fixtures.
	 */
	private static final String RETRIED_STEP_LAUNCH_KEY_SUFFIX = ':1';

	/**
	 * @description The display name of the nested launching step in the seeded step log.
	 */
	private static final String NESTED_LAUNCH_STEP_NAME = 'NestedLaunchingStep';

	/**
	 * @description The step count of the seeded nested-launch chain: one step, which launches the rest.
	 */
	private static final Integer NESTED_LAUNCH_TOTAL_STEPS = 1;

	/**
	 * @description The context key under which the chain suite's launching steps store the child's execution id.
	 */
	private static final String CHILD_EXECUTION_KEY = 'childExecutionId';

	/**
	 * @description The logging-context document's root correlation field name, as LOG_Engine's context DTO
	 * serializes it.
	 */
	private static final String LOG_CONTEXT_ROOT_FIELD = 'rootCorrelationId';

	/**
	 * @description The logging-context document's context values field name.
	 */
	private static final String LOG_CONTEXT_DATA_FIELD = 'contextData';

	/**
	 * @description Root correlation id seeded on a source run launched inside a traced action: the action's id,
	 * which the new run a restart makes must keep.
	 */
	private static final String SOURCE_ROOT_CORRELATION_ID = 'source-root-correlation';

	/**
	 * @description Context key seeded into the source run's logging document at launch. It proves the new run keeps
	 * the launch's context values.
	 */
	private static final String SOURCE_CONTEXT_KEY = 'seededAtLaunch';

	/**
	 * @description Value seeded under SOURCE_CONTEXT_KEY.
	 */
	private static final String SOURCE_CONTEXT_VALUE = 'launch-value';

	/**
	 * @description A full logging document as a run launched inside a traced action stores it: the source correlation,
	 * the action's root and one context value.
	 */
	private static final String ROOTED_LOG_CONTEXT_VALUE = JSON.serialize(new Map<String, Object>
	{
			LOG_CONTEXT_CORRELATION_FIELD => SOURCE_LOG_CORRELATION_ID,
			LOG_CONTEXT_ROOT_FIELD => SOURCE_ROOT_CORRELATION_ID,
			LOG_CONTEXT_DATA_FIELD => new Map<String, String> {SOURCE_CONTEXT_KEY => SOURCE_CONTEXT_VALUE}
	});

	/**
	 * @description Capacity in characters of the ContextData__c and InitialContextData__c long text
	 * areas. The overflow test seeds a copy of the starting data that fills the field exactly. So when the restart
	 * rebuilds the logging entry, which is larger, the new run's context can only grow past the field.
	 */
	private static final Integer CONTEXT_DATA_FIELD_CAPACITY = 131072;

	/**
	 * @description A logging-context value kept very small on purpose, for the overflow test. The restart replaces it
	 * with a full correlation document, so the rebuilt context is always larger than the copy it came from.
	 */
	private static final String TINY_LOG_CONTEXT_VALUE = 'x';

	/**
	 * @description Context key the overflow test pads with filler to reach the field capacity.
	 */
	private static final String SNAPSHOT_PADDING_KEY = 'padding';

	/**
	 * @description Creates a test admin user of its own, so System.runAs in each test starts with fresh permission
	 * checks. This avoids a problem where the test org kept stale permissions after the running user's permission set
	 * changed in the middle of a transaction. Every test in this
	 * class runs as that admin; the low-privilege chain test lives in UTIL_AsyncChain_TEST, which
	 * provisions its own minimum-access user.
	 */
	@TestSetup
	private static void setupTestUsers()
	{
		TST_Factory.newUserWithPermissionSet
				(
						SEL_Profile.PROFILE_SYSTEM_ADMIN,
						TEST_ADMIN_COMPANY,
						SEL_PermissionSet.ADMIN_PERMISSION_SET_API_NAME
				);
	}

	/**
	 * @description Verifies the Finalizer routes a transient next-step enqueue failure to Stalled:
	 * the chain awaits recovery instead of terminally failing, so CompletedAt stays unset.
	 */
	@IsTest
	private static void shouldRouteFinalizerEnqueueFailureToStalled()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();

			Test.startTest();
			String executionId = UTIL_AsyncChain.newChain(TEST_CHAIN_NAME)
					.then(new UTIL_AsyncChainRecovery_TEST.SuccessStep())
					.then(new UTIL_AsyncChainRecovery_TEST.SuccessStep())
					.withAsyncOptions(createAsyncOptions(3))
					.execute();

			UTIL_AsyncChain.simulateEnqueueFailure = true;
			Test.stopTest();
			UTIL_AsyncChain.simulateEnqueueFailure = false;

			AsyncChainExecution__c execution = queryExecution(executionId);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_STALLED, execution.Status__c, 'A transient enqueue failure must route the chain to Stalled, not Failed');
			Assert.isTrue(execution.ErrorMessage__c.contains('Finalizer failed to enqueue next step'), 'The stall reason must name the failed enqueue');
			Assert.isNull(execution.CompletedAt__c, 'Stalled is non-terminal: CompletedAt must stay unset');
		}
	}

	/**
	 * @description Verifies a completed chain whose completion handler could not be queued stays Completed: the
	 * Finalizer keeps the finished status and its end time, notes on the row which handler did not run, and logs
	 * an error naming the chain, instead of rewriting the row to Stalled, which nothing would ever move again.
	 */
	@IsTest
	private static void shouldKeepCompletedStatusWhenCompletionHandlerCannotBeQueued()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();
			LOG_Builder.ignoreTestMode = true;

			Test.startTest();
			String executionId = executeWithCompletionHandler();

			UTIL_AsyncChain.simulateEnqueueFailure = true;
			Test.stopTest();
			UTIL_AsyncChain.simulateEnqueueFailure = false;
			Test.getEventBus().deliver();

			AsyncChainExecution__c execution = queryExecution(executionId);
			String expectedNote = String.format(HANDLER_NOT_QUEUED_NOTE_FORMAT, new List<String> {COMPLETION_HANDLER_POSITION, CompletionHandlerStep.class.getName()});
			String expectedLog = String.format(HANDLER_NOT_QUEUED_LOG_FORMAT, new List<String> {TEST_CHAIN_NAME, SEL_AsyncChainExecution.STATUS_COMPLETED, expectedNote});
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_COMPLETED, execution.Status__c,
					'Expected the chain to stay Completed when its completion handler could not be queued, got ' + execution.Status__c);
			Assert.isNull(execution.FailureCategory__c, 'Expected a completed chain to keep no failure category, got ' + execution.FailureCategory__c);
			Assert.isNotNull(execution.CompletedAt__c, 'Expected the completion stamp to stay on the finished chain');
			Assert.isTrue(execution.ErrorMessage__c?.startsWith(expectedNote) == true,
					'Expected the row to note the completion handler that did not run, got ' + execution.ErrorMessage__c);
			Assert.isTrue(hasLogEntryAtLevelContaining(LOG_LEVEL_ERROR, expectedLog), 'Expected an error log naming the chain and the completion handler that did not run');
		}
	}

	/**
	 * @description Verifies a failed chain whose onError handler could not be queued stays Failed: the Finalizer keeps
	 * the failed status, its category and its end time, adds a note naming the handler that did not run after
	 * the step's own failure message, and logs an error naming the chain. The row stays what any Failed row is: the
	 * Chain Monitor offers Retry from the failed step, which declared itself safe to re-run.
	 */
	@IsTest
	private static void shouldKeepFailedStatusWhenErrorHandlerCannotBeQueued()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();
			LOG_Builder.ignoreTestMode = true;

			Test.startTest();
			String executionId = UTIL_AsyncChain.newChain(TEST_CHAIN_NAME)
					.then(new UTIL_AsyncChainRecovery_TEST.IdempotentFailingStep())
					.onError(new UTIL_AsyncChainRecovery_TEST.CountingErrorHandlerStep())
					.withAsyncOptions(createAsyncOptions(2))
					.execute();

			UTIL_AsyncChain.simulateEnqueueFailure = true;
			Test.stopTest();
			UTIL_AsyncChain.simulateEnqueueFailure = false;
			Test.getEventBus().deliver();

			AsyncChainExecution__c execution = queryExecution(executionId);
			String expectedNote = String.format(HANDLER_NOT_QUEUED_NOTE_FORMAT, new List<String> {ERROR_HANDLER_POSITION, CountingErrorHandlerStep.class.getName()});
			String expectedLog = String.format(HANDLER_NOT_QUEUED_LOG_FORMAT, new List<String> {TEST_CHAIN_NAME, SEL_AsyncChainExecution.STATUS_FAILED, expectedNote});
			String availability = UTIL_AsyncChain.resolveRetryAvailability(new SEL_AsyncChainExecution().findByIdForMonitoring(executionId));
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_FAILED, execution.Status__c,
					'Expected the chain to stay Failed when its onError handler could not be queued, got ' + execution.Status__c);
			Assert.areEqual(SEL_AsyncChainExecution.FAILURE_CATEGORY_STEP_EXCEPTION, execution.FailureCategory__c,
					'Expected the step failure category to stay, got ' + execution.FailureCategory__c);
			Assert.isNotNull(execution.CompletedAt__c, 'Expected the completion stamp to stay on the failed chain');
			Assert.isTrue(execution.ErrorMessage__c?.startsWith(IDEMPOTENT_FAILURE_MESSAGE + '; ' + expectedNote) == true,
					'Expected the step failure first, then the note naming the onError handler that did not run, got ' + execution.ErrorMessage__c);
			Assert.areEqual(0, errorHandlerRunCount, 'Expected the onError handler not to run once its enqueue failed, got ' + errorHandlerRunCount + ' run(s)');
			Assert.isTrue(hasLogEntryAtLevelContaining(LOG_LEVEL_ERROR, expectedLog), 'Expected an error log naming the chain and the onError handler that did not run');
			Assert.areEqual(UTIL_AsyncChain.REDRIVE_AVAILABLE, availability,
					'Expected Retry to be offered as for any Failed chain whose failed step is safe to re-run, got ' + availability);
		}
	}

	/**
	 * @description Verifies that a transition into Stalled fires the chain's onError handler exactly
	 * once through the real Finalizer path: the notification runs through the same HandlerExecutor as
	 * terminal failures and carries the stall reason through to the record.
	 */
	@IsTest
	private static void shouldFireOnErrorOnceWhenChainStalls()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();

			Test.startTest();
			String executionId = UTIL_AsyncChain.newChain(TEST_CHAIN_NAME)
					.then(new UTIL_AsyncChainRecovery_TEST.SuccessStep())
					.then(new UTIL_AsyncChainRecovery_TEST.SuccessStep())
					.onError(new UTIL_AsyncChainRecovery_TEST.CountingErrorHandlerStep())
					.withAsyncOptions(createAsyncOptions(3))
					.execute();

			UTIL_AsyncChain.simulateEnqueueFailure = true;
			Test.stopTest();
			UTIL_AsyncChain.simulateEnqueueFailure = false;

			Assert.areEqual(1, errorHandlerRunCount, 'The stall transition must fire the onError handler exactly once');
			AsyncChainExecution__c execution = queryExecution(executionId);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_STALLED, execution.Status__c, 'The chain must land Stalled after the transient enqueue failure');
			Assert.isTrue(execution.ErrorMessage__c.contains('Finalizer failed to enqueue next step'), 'The notification must carry the stall reason through to the record');
			Assert.isNull(execution.CompletedAt__c, 'Stalled is non-terminal: CompletedAt must stay unset');
		}
	}

	/**
	 * @description Verifies the single-fire guard: marking a chain Stalled twice enqueues the
	 * onError notification only for the first mark, because the second mark reads a prior status
	 * that is already Stalled and skips the fire. The repeat mark refreshes the stall reason on
	 * the record. The one notification then records again the first reason it carried, when its result is
	 * saved back at stopTest.
	 */
	@IsTest
	private static void shouldFireOnErrorOnceWhenMarkedStalledTwice()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();

			String runKey = UTIL_Random.randomUUID();
			AsyncChainExecution__c execution = persistRunningExecutionWithKey(runKey);
			UTIL_AsyncChain.ChainExecutor executor = buildExecutorWithStallHandler(execution.Id, runKey);

			Test.startTest();
			executor.markChainStalledFromFinalizer(execution.Id, 'First stall mark', null);
			executor.markChainStalledFromFinalizer(execution.Id, 'Second stall mark', null);

			AsyncChainExecution__c beforeNotification = queryExecution(execution.Id);
			Assert.isTrue(beforeNotification.ErrorMessage__c.contains('Second stall mark'), 'The repeat mark must refresh the stall reason on the record');
			Test.stopTest();

			Assert.areEqual(1, errorHandlerRunCount, 'The onError notification must fire exactly once per transition into Stalled');
			AsyncChainExecution__c result = queryExecution(execution.Id);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_STALLED, result.Status__c, 'The chain must remain Stalled after the repeat mark');
			Assert.isTrue(result.ErrorMessage__c.contains('First stall mark'), 'Saving the notification\'s result must record again the first stall reason it carried');
			Assert.isNull(result.CompletedAt__c, 'Stalled is non-terminal: CompletedAt must stay unset');
		}
	}

	/**
	 * @description Verifies the fallback path: when queuing the onError handler itself fails in the same
	 * resource-exhausted transaction that caused the stall, the stall write still lands, the
	 * failure is logged, and nothing throws.
	 */
	@IsTest
	private static void shouldStillSaveTheStallAndLogTheFailureWhenQueuingTheErrorHandlerFails()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();
			LOG_Builder.ignoreTestMode = true;

			String runKey = UTIL_Random.randomUUID();
			AsyncChainExecution__c execution = persistRunningExecutionWithKey(runKey);
			UTIL_AsyncChain.ChainExecutor executor = buildExecutorWithStallHandler(execution.Id, runKey);

			Test.startTest();
			UTIL_AsyncChain.simulateEnqueueFailure = true;
			executor.markChainStalledFromFinalizer(execution.Id, 'Stall with exhausted async budget', null);
			Test.stopTest();
			UTIL_AsyncChain.simulateEnqueueFailure = false;
			Test.getEventBus().deliver();

			AsyncChainExecution__c result = queryExecution(execution.Id);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_STALLED, result.Status__c, 'The stall write must land even when the onError enqueue fails');
			Assert.areEqual(0, errorHandlerRunCount, 'The onError handler that could not be queued must not run');
			Assert.isTrue(anyLogMessageContains('Stalled onError enqueue failed'), 'The degraded enqueue must log its failure with the stall reason');
		}
	}

	/**
	 * @description Verifies a broken onError handler cannot escalate a Stalled chain to Failed:
	 * when the stalled notification's handler fails, the framework logs the failure and leaves
	 * the record untouched, so the chain stays Stalled and visible to recovery.
	 */
	@IsTest
	private static void shouldKeepChainStalledWhenStalledOnErrorHandlerFails()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();
			LOG_Builder.ignoreTestMode = true;

			Test.startTest();
			String executionId = UTIL_AsyncChain.newChain(TEST_CHAIN_NAME)
					.then(new UTIL_AsyncChainRecovery_TEST.SuccessStep())
					.then(new UTIL_AsyncChainRecovery_TEST.SuccessStep())
					.onError(new UTIL_AsyncChainRecovery_TEST.FailingErrorHandlerStep())
					.withAsyncOptions(createAsyncOptions(3))
					.execute();

			UTIL_AsyncChain.simulateEnqueueFailure = true;
			Test.stopTest();
			UTIL_AsyncChain.simulateEnqueueFailure = false;
			Test.getEventBus().deliver();

			AsyncChainExecution__c execution = queryExecution(executionId);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_STALLED, execution.Status__c, 'A failing stalled notification handler must not escalate the chain to Failed');
			Assert.isTrue(execution.ErrorMessage__c.contains('Finalizer failed to enqueue next step'), 'The stall reason must survive the failed notification untouched');
			Assert.isNull(execution.CompletedAt__c, 'Stalled is non-terminal: CompletedAt must stay unset');
			Assert.isTrue(anyLogMessageContains('Stalled onError handler failed'), 'The handler failure must be logged, not written to the record');
		}
	}

	/**
	 * @description Verifies ChainBuilder.execute stamps the enqueued job's AsyncApexJob id
	 * into AsyncChainExecution__c.CurrentJobId__c before the first job runs. That job id, saved when the job is queued,
	 * is what lets the watchdog prove the job is still alive for chains on their first job and one-step chains, which
	 * never reach a progress save. It also verifies the final completion save leaves the job id in place.
	 */
	@IsTest
	private static void shouldStampExecutorJobIdAtEnqueue()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();

			Test.startTest();
			String executionId = UTIL_AsyncChain.newChain(TEST_CHAIN_NAME)
					.then(new SuccessStep())
					.execute();

			AsyncChainExecution__c beforeFirstHop = queryExecution(executionId);
			Assert.isNotNull(beforeFirstHop.CurrentJobId__c, 'The job id saved at queue time must be there before the first job runs');
			Test.stopTest();

			AsyncChainExecution__c completed = queryExecution(executionId);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_COMPLETED, completed.Status__c, 'The single-step chain completes normally');
			Assert.isNotNull(completed.CurrentJobId__c, 'The final save leaves the job id in place for the watchdog');
		}
	}

	/**
	 * @description Verifies a crashing onError handler cannot escalate a Stalled chain to Failed:
	 * the HandlerExecutor Finalizer logs the crash instead of stamping Failed plus a completion
	 * time, so the chain stays Stalled and visible to recovery.
	 */
	@IsTest
	private static void shouldKeepChainStalledWhenStalledOnErrorHandlerCrashes()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();
			LOG_Builder.ignoreTestMode = true;

			Test.startTest();
			String executionId = UTIL_AsyncChain.newChain(TEST_CHAIN_NAME)
					.then(new UTIL_AsyncChainRecovery_TEST.SuccessStep())
					.then(new UTIL_AsyncChainRecovery_TEST.SuccessStep())
					.onError(new UTIL_AsyncChainRecovery_TEST.CountingErrorHandlerStep())
					.withAsyncOptions(createAsyncOptions(3))
					.execute();

			UTIL_AsyncChain.simulateEnqueueFailure = true;
			UTIL_AsyncChain.simulateHandlerCrash = true;
			try
			{
				Test.stopTest();
			}
			catch(Exception surfacedCrash)
			{
				Assert.isNotNull(surfacedCrash, 'Simulated handler crash should surface an exception');
			}
			UTIL_AsyncChain.simulateEnqueueFailure = false;
			UTIL_AsyncChain.simulateHandlerCrash = false;
			Test.getEventBus().deliver();

			AsyncChainExecution__c execution = queryExecution(executionId);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_STALLED, execution.Status__c, 'A crashing stalled notification handler must not escalate the chain to Failed');
			Assert.isTrue(execution.ErrorMessage__c.contains('Finalizer failed to enqueue next step'), 'The stall reason must survive the handler crash untouched');
			Assert.isNull(execution.CompletedAt__c, 'Stalled is non-terminal: no completion stamp may land on a chain whose work never completed');
			Assert.isTrue(anyLogMessageContains(STALLED_NOTIFICATION_CRASH_LOG_FRAGMENT), 'Expected the handler crash to be logged, not written to the record');
		}
	}

	/**
	 * @description Verifies the watchdog sweep marks a stale Running chain Stalled with the sweep
	 * reason, and leaves a chain younger than the threshold untouched. A 30-minute threshold treats the chain created
	 * just now as fresh. Then a negative threshold puts the cutoff in the future, so the same row counts as stale. So
	 * the test checks both cases without setting any audit field to an earlier date.
	 */
	@IsTest
	private static void shouldMarkStuckRunningChainStalled()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();

			AsyncChainExecution__c execution = TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_RUNNING, TEST_CHAIN_NAME, new Map<SObjectField, Object>
			{
					AsyncChainExecution__c.StepLog__c => buildStepLogJson()
			});

			Test.startTest();
			UTIL_AsyncChain.runWatchdogSweep(FRESH_THRESHOLD_MINUTES, WATCHDOG_BATCH_SIZE);

			AsyncChainExecution__c fresh = queryExecution(execution.Id);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_RUNNING, fresh.Status__c, 'A chain younger than the stale threshold must stay Running');
			Assert.isNull(fresh.ErrorMessage__c, 'A fresh chain must carry no stall reason');

			UTIL_AsyncChain.runWatchdogSweep(SWEEP_EVERYTHING_THRESHOLD_MINUTES, WATCHDOG_BATCH_SIZE);
			Test.stopTest();

			AsyncChainExecution__c result = queryExecution(execution.Id);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_STALLED, result.Status__c, 'The sweep must mark a stale Running chain Stalled');
			Assert.isTrue(result.ErrorMessage__c.contains('No live executor detected by watchdog sweep'), 'The stall reason must name the watchdog sweep');
			Assert.isNull(result.CompletedAt__c, 'Stalled is non-terminal: CompletedAt must stay unset');
			Assert.areEqual(0, errorHandlerRunCount, 'A step log without an error-handler entry must not produce a notification');
		}
	}

	/**
	 * @description Verifies an unhandled stall is recorded at ERROR level: when the watchdog
	 * sweep moves a chain into Stalled and no onError handler is found, the one 'Chain stalled' log
	 * entry, which would otherwise be WARN, is raised to ERROR. It is the same entry with the same message start,
	 * never a second entry. That level shows stalls nobody handles in the Log Console, without anyone watching the
	 * Chain Monitor. A candidate set aside because limits ran low is never raised, even with no handler at all (see
	 * shouldNotRaiseTheStallLogToErrorForAChainSetAsideForLowLimits).
	 */
	@IsTest
	private static void shouldElevateUnhandledStallLogToError()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();
			LOG_Builder.ignoreTestMode = true;

			AsyncChainExecution__c execution = TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_RUNNING, TEST_CHAIN_NAME, new Map<SObjectField, Object>
			{
					AsyncChainExecution__c.StepLog__c => buildStepLogJson()
			});

			Test.startTest();
			UTIL_AsyncChain.runWatchdogSweep(SWEEP_EVERYTHING_THRESHOLD_MINUTES, WATCHDOG_BATCH_SIZE);
			Test.stopTest();
			Test.getEventBus().deliver();

			AsyncChainExecution__c result = queryExecution(execution.Id);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_STALLED, result.Status__c, 'The sweep must mark the stale chain Stalled');
			Assert.isTrue(hasLogEntryAtLevelContaining(LOG_LEVEL_ERROR, 'no onError handler registered'),
					'A genuine stall transition with no resolvable onError handler must be recorded at ERROR level');
			Assert.isFalse(hasLogEntryAtLevelContaining(LOG_LEVEL_WARN, 'Chain stalled'),
					'The ERROR entry replaces the WARN entry for this move into Stalled, and never adds a second entry');
			Assert.areEqual(1, countLogEntriesContaining('Chain stalled'),
					'Exactly one stall entry for one transition');
		}
	}

	/**
	 * @description Verifies the ERROR level for a stall nobody handles is used only when the chain really moves into
	 * Stalled, never when a later sweep sees the same row again. Two sweeps with plenty of limits run over one Running
	 * chain that has no handler and no CurrentJobId__c, so both take the stall path. The first sweep is the real move
	 * into Stalled and records the one ERROR entry. The second marks the row that is already Stalled again, sees no
	 * move, and must log its stall entry at WARN. If the stallTransition condition were removed from
	 * unhandledStallTransition in UTIL_AsyncChain.markStalledAndNotify, every later sweep would log a wrong second
	 * ERROR. The count check below is what catches that.
	 */
	@IsTest
	private static void shouldNotRepeatUnhandledStallErrorOnRepeatSweep()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();
			LOG_Builder.ignoreTestMode = true;

			AsyncChainExecution__c execution = TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_RUNNING, TEST_CHAIN_NAME, new Map<SObjectField, Object>
			{
					AsyncChainExecution__c.StepLog__c => buildStepLogJson()
			});

			Test.startTest();
			UTIL_AsyncChain.runWatchdogSweep(SWEEP_EVERYTHING_THRESHOLD_MINUTES, WATCHDOG_BATCH_SIZE);
			UTIL_AsyncChain.runWatchdogSweep(SWEEP_EVERYTHING_THRESHOLD_MINUTES, WATCHDOG_BATCH_SIZE);
			Test.stopTest();
			Test.getEventBus().deliver();

			AsyncChainExecution__c result = queryExecution(execution.Id);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_STALLED, result.Status__c, 'The repeat sweep must leave the chain Stalled');
			Assert.areEqual(1, countLogEntriesContaining('no onError handler registered'),
					'The ERROR for a stall nobody handles is logged once, only on the move into Stalled: a second entry means a repeat mark raised it again');
			Assert.isTrue(hasLogEntryAtLevelContaining(LOG_LEVEL_WARN, 'Chain stalled'),
					'Marking the already-Stalled row again logs its stall entry at WARN, proving the second sweep reached the stall path');
		}
	}

	/**
	 * @description Verifies that the watchdog stall mark stamps the Stalled failure category
	 * alongside the Stalled status.
	 */
	@IsTest
	private static void shouldCategoriseStallAsStalled()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();

			AsyncChainExecution__c execution = TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_RUNNING, TEST_CHAIN_NAME, new Map<SObjectField, Object>
			{
					AsyncChainExecution__c.StepLog__c => buildStepLogJson()
			});

			Test.startTest();
			UTIL_AsyncChain.runWatchdogSweep(SWEEP_EVERYTHING_THRESHOLD_MINUTES, WATCHDOG_BATCH_SIZE);
			Test.stopTest();

			AsyncChainExecution__c result = queryExecution(execution.Id);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_STALLED, result.Status__c, 'The sweep must mark a stale Running chain Stalled');
			Assert.areEqual(SEL_AsyncChainExecution.FAILURE_CATEGORY_STALLED, result.FailureCategory__c, 'A watchdog stall must be categorised Stalled');
		}
	}

	/**
	 * @description Verifies the sweep fires the onError notification exactly once for a chain whose
	 * saved step log carries an error-handler definition: the first sweep marks the chain
	 * Stalled and enqueues the notification, and a repeat sweep of the now-already-Stalled chain
	 * must not queue a second one (the shared code sends the notification only once per move into Stalled).
	 */
	@IsTest
	private static void shouldNotifyPersistedOnErrorHandlerOnceAcrossRepeatSweeps()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();

			AsyncChainExecution__c execution = TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_RUNNING, TEST_CHAIN_NAME, new Map<SObjectField, Object>
			{
					AsyncChainExecution__c.StepLog__c => buildStepLogJsonWithErrorHandler()
			});

			Test.startTest();
			UTIL_AsyncChain.runWatchdogSweep(SWEEP_EVERYTHING_THRESHOLD_MINUTES, WATCHDOG_BATCH_SIZE);
			UTIL_AsyncChain.runWatchdogSweep(SWEEP_EVERYTHING_THRESHOLD_MINUTES, WATCHDOG_BATCH_SIZE);

			AsyncChainExecution__c betweenSweeps = queryExecution(execution.Id);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_STALLED, betweenSweeps.Status__c, 'The repeat sweep must keep the already-Stalled chain Stalled');
			Test.stopTest();

			Assert.areEqual(1, errorHandlerRunCount, 'The sweep must fire the onError notification exactly once across repeat sweeps');
			AsyncChainExecution__c result = queryExecution(execution.Id);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_STALLED, result.Status__c, 'The chain must remain Stalled after the notification lands');
			Assert.isTrue(result.ErrorMessage__c.contains('No live executor detected by watchdog sweep'), 'Saving the notification\'s result must keep the sweep reason');
			Assert.isNull(result.CompletedAt__c, 'Stalled is non-terminal: CompletedAt must stay unset');
		}
	}

	/**
	 * @description Verifies a malformed step log cannot break recovery: the sweep still marks the
	 * chain Stalled and simply skips the notification it cannot resolve a handler from.
	 */
	@IsTest
	private static void shouldSweepChainWithMalformedStepLog()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();

			AsyncChainExecution__c execution = TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_RUNNING, TEST_CHAIN_NAME, new Map<SObjectField, Object>
			{
					AsyncChainExecution__c.StepLog__c => 'not step-log json'
			});

			Test.startTest();
			UTIL_AsyncChain.runWatchdogSweep(SWEEP_EVERYTHING_THRESHOLD_MINUTES, WATCHDOG_BATCH_SIZE);
			Test.stopTest();

			AsyncChainExecution__c result = queryExecution(execution.Id);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_STALLED, result.Status__c, 'A malformed step log must not stop the sweep from marking the chain Stalled');
			Assert.areEqual(0, errorHandlerRunCount, 'No notification can fire when the step log cannot be parsed');
		}
	}

	/**
	 * @description A rare race between an abort and another save can leave a Stalled row with an end time. That row is a
	 * finished run whose status was overwritten, and it must never come back to life. So the whole sweep must not see
	 * it: it is neither marked again nor started again. The row stays stopped instead of running again with a key that
	 * was already released. The package blocks saving a Stalled record that has an end time. Older orgs still have such
	 * records. So this test turns off that one check while it saves the record.
	 */
	@IsTest
	private static void shouldNotResurrectAbortedRowOverwrittenToStalled()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();

			AsyncChainExecution__c execution;
			String actionClassName = TST_Factory.getRunTransitionActionClassName();
			TRG_Base.bypassAction(actionClassName);
			try
			{
				execution = TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_STALLED, TEST_CHAIN_NAME, new Map<SObjectField, Object>
				{
						AsyncChainExecution__c.CompletedAt__c => Datetime.now(),
						AsyncChainExecution__c.FailureCategory__c => SEL_AsyncChainExecution.FAILURE_CATEGORY_STALLED,
						AsyncChainExecution__c.StepLog__c => buildStepLogJson()
				});
			}
			finally
			{
				TRG_Base.clearActionBypass(actionClassName);
			}

			Test.startTest();
			UTIL_AsyncChain.runWatchdogSweep(SWEEP_EVERYTHING_THRESHOLD_MINUTES, WATCHDOG_BATCH_SIZE);
			Test.stopTest();

			AsyncChainExecution__c result = queryExecution(execution.Id);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_STALLED, result.Status__c, 'The contradictory row must be left exactly as found');
			Assert.isNull(result.ErrorMessage__c, 'The contradictory row must carry no watchdog mark: an excluded candidate is never re-marked');
			Assert.areEqual(0, errorHandlerRunCount, 'No notification may fire for an excluded candidate');
		}
	}

	/**
	 * @description Verifies that one chain's failure stays with that chain in the sweep: when the stall save fails, the
	 * failure is logged with the sweep reason, no notification fires, and nothing throws. The test registers a mocked
	 * row, so the sweep and its fresh read both see a row whose real record is gone. That makes the stall DML fail.
	 */
	@IsTest
	private static void shouldLogAndContinueWhenWatchdogStallWriteFails()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();
			LOG_Builder.ignoreTestMode = true;

			AsyncChainExecution__c execution = TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_RUNNING, TEST_CHAIN_NAME);
			Id executionId = execution.Id;
			DML_Builder.newTransaction().doDelete(execution).execute();
			registerAuthorizedExecutionMock(executionId, null);

			Test.startTest();
			UTIL_AsyncChain.runWatchdogSweep(SWEEP_EVERYTHING_THRESHOLD_MINUTES, WATCHDOG_BATCH_SIZE);
			Test.stopTest();
			Test.getEventBus().deliver();

			Assert.isTrue(anyLogMessageContains('Watchdog stall DML failed'), 'A failed stall write must log the DML failure with the sweep reason');
			Assert.areEqual(0, errorHandlerRunCount, 'A failed stall write must not fire the onError notification');
		}
	}

	/**
	 * @description Verifies the sweep clamps an oversized batch size to its 50-chain ceiling: each
	 * stale row costs the sweep a query and an update. Without the limit, a large batch would hit a governor limit in
	 * the middle of the sweep and roll back the whole run. When many chains stall at once, every scheduled sweep would
	 * then crash the same way. The test seeds 60 stale Running chains, asks for all 60 in one sweep, and expects exactly 50
	 * marked Stalled with the remaining 10 left Running for the next sweep.
	 */
	@IsTest
	private static void shouldClampWatchdogSweepBatchToCeiling()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();

			TST_Factory.newChainExecutions(OVERSIZED_SWEEP_SEED_COUNT, SEL_AsyncChainExecution.STATUS_RUNNING, TEST_CHAIN_NAME);

			Test.startTest();
			UTIL_AsyncChain.runWatchdogSweep(SWEEP_EVERYTHING_THRESHOLD_MINUTES, OVERSIZED_SWEEP_SEED_COUNT);
			Test.stopTest();

			Integer stalledCount = new SEL_AsyncChainExecution().findByStatus(SEL_AsyncChainExecution.STATUS_STALLED).size();
			Integer runningCount = new SEL_AsyncChainExecution().findByStatus(SEL_AsyncChainExecution.STATUS_RUNNING).size();

			Assert.areEqual(WATCHDOG_BATCH_SIZE, stalledCount, 'The sweep must mark exactly the batch ceiling of chains Stalled');
			Assert.areEqual(OVERSIZED_SWEEP_SEED_COUNT - WATCHDOG_BATCH_SIZE, runningCount, 'Chains beyond the ceiling must stay Running for the next sweep');
		}
	}

	/**
	 * @description Verifies the sweep's check on the Queueable limit. When the transaction can add no more Queueable
	 * jobs, a stale Running chain is set aside: it is marked Stalled with its own reason for this case. Its saved onError
	 * notification is NOT queued, even though the step log has a handler. The test needs no extra check that nothing was
	 * queued: with no jobs left, any attempt to queue would throw a LimitException that cannot be caught, and fail the
	 * test at once. The test does not call Test.startTest, on purpose. startTest starts fresh governor limits, which
	 * would give the sweep a full Queueable limit again.
	 */
	@IsTest
	private static void shouldSetAsideAStaleChainWhenNoQueueableJobsAreLeft()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();

			AsyncChainExecution__c execution = TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_RUNNING, TEST_CHAIN_NAME, new Map<SObjectField, Object>
			{
					AsyncChainExecution__c.StepLog__c => buildStepLogJsonWithErrorHandler()
			});

			consumeAllQueueableBudget();
			Integer enqueuedJobsBeforeSweep = UTIL_Limits.queueableJobs().used();

			UTIL_AsyncChain.runWatchdogSweep(SWEEP_EVERYTHING_THRESHOLD_MINUTES, WATCHDOG_BATCH_SIZE);

			AsyncChainExecution__c result = queryExecution(execution.Id);
			Assert.areEqual
					(SEL_AsyncChainExecution.STATUS_STALLED, result.Status__c, 'With no Queueable jobs left, the sweep must set the stale chain aside as Stalled');
			Assert.areEqual(PARKED_NO_BUDGET_REASON, result.ErrorMessage__c, 'A chain set aside must carry its own no-jobs-left reason, not the general stall reason');
			Assert.areEqual
					(enqueuedJobsBeforeSweep, UTIL_Limits.queueableJobs().used(), 'Setting the chain aside must not queue the onError notification: no job is left for it');
			Assert.isNull(result.CompletedAt__c, 'Stalled is not a final status: a chain set aside waits for recovery, so CompletedAt must stay unset');
		}
	}

	/**
	 * @description Verifies that setting a chain aside because limits ran low never raises the stall log to ERROR (the
	 * raise that shouldElevateUnhandledStallLogToError proves). Setting aside means the sweep marks a stale chain
	 * Stalled because no Queueable jobs are left to handle it. The onError notification is held back because of that
	 * limit, not because no handler exists. So the stall entry must stay at WARN, never ERROR, even when the chain has
	 * no handler at all.
	 */
	@IsTest
	private static void shouldNotRaiseTheStallLogToErrorForAChainSetAsideForLowLimits()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();
			LOG_Builder.ignoreTestMode = true;

			AsyncChainExecution__c execution = TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_RUNNING, TEST_CHAIN_NAME, new Map<SObjectField, Object>
			{
					AsyncChainExecution__c.StepLog__c => buildStepLogJson()
			});

			consumeAllQueueableBudget();
			UTIL_AsyncChain.runWatchdogSweep(SWEEP_EVERYTHING_THRESHOLD_MINUTES, WATCHDOG_BATCH_SIZE);
			Test.getEventBus().deliver();

			AsyncChainExecution__c result = queryExecution(execution.Id);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_STALLED, result.Status__c, 'The limit check sets the stale chain aside');
			Assert.isTrue(hasLogEntryAtLevelContaining(LOG_LEVEL_WARN, 'Chain stalled'),
					'Setting the chain aside still logs its WARN stall entry (this proves log entries arrive in this test, so the ERROR check below cannot pass for nothing)');
			Assert.isFalse(hasLogEntryAtLevelContaining(LOG_LEVEL_ERROR, 'Chain stalled'),
					'Setting a chain aside must never log the ERROR for a stall nobody handles');
		}
	}

	/**
	 * @description Verifies a chain set aside can be handled again later. Setting aside a chain that is already Stalled
	 * keeps it Stalled, replaces its stall reason with the set-aside reason, and fires nothing. The shared code sends
	 * the notification only when a chain moves into Stalled, and this chain did not move. So no notification is tried,
	 * even on a later sweep of the same row with plenty of limits. The test does not call Test.startTest, for the same
	 * reason as the test with no Queueable jobs left: startTest would start fresh limits.
	 */
	@IsTest
	private static void shouldReparkAlreadyStalledChainWithoutNotifying()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();

			AsyncChainExecution__c execution = TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_STALLED, TEST_CHAIN_NAME, new Map<SObjectField, Object>
			{
					AsyncChainExecution__c.StepLog__c => buildStepLogJsonWithErrorHandler(),
					AsyncChainExecution__c.ErrorMessage__c => 'No live executor detected by watchdog sweep'
			});

			consumeAllQueueableBudget();
			Integer enqueuedJobsBeforeSweep = UTIL_Limits.queueableJobs().used();

			UTIL_AsyncChain.runWatchdogSweep(SWEEP_EVERYTHING_THRESHOLD_MINUTES, WATCHDOG_BATCH_SIZE);

			AsyncChainExecution__c result = queryExecution(execution.Id);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_STALLED, result.Status__c, 'A Stalled chain set aside again must stay Stalled, so the next sweep can handle it');
			Assert.areEqual(PARKED_NO_BUDGET_REASON, result.ErrorMessage__c, 'Setting it aside again must update the stall reason, so the record shows why');
			Assert.areEqual(enqueuedJobsBeforeSweep, UTIL_Limits.queueableJobs().used(), 'Setting it aside again must fire nothing: the chain did not move into Stalled');
		}
	}

	/**
	 * @description Verifies, from start to end, the sweep's check on the query limit when almost no queries are left:
	 * 1. The first candidate is still handled normally, because the queries kept free for it are there.
	 * 2. The check then refuses the next candidate.
	 * 3. The remaining candidates are set aside, with their own no-queries-left reason, while queries last.
	 * 4. The candidate after that is left completely untouched.
	 * Nothing throws, even with no queries left. The sweep runs outside Test.startTest, on purpose: startTest starts
	 * fresh governor limits, which would give the sweep a full query limit again. The checks run inside startTest
	 * instead, because the sweep ends, on purpose, with no queries left to read with.
	 */
	@IsTest
	private static void shouldSetAsideTheRestOfTheSweepWhenQueriesRunShort()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();

			TST_Factory.newChainExecutions(QUERY_PARK_SEED_COUNT, SEL_AsyncChainExecution.STATUS_RUNNING, TEST_CHAIN_NAME);
			consumeSoqlBudgetDownTo(QUERY_BUDGET_FOR_ONE_SWEPT_CANDIDATE);

			UTIL_AsyncChain.runWatchdogSweep(SWEEP_EVERYTHING_THRESHOLD_MINUTES, WATCHDOG_BATCH_SIZE);

			Test.startTest();
			List<String> stalledReasons = new List<String>();
			for(AsyncChainExecution__c chain : new SEL_AsyncChainExecution().findByStatus(SEL_AsyncChainExecution.STATUS_STALLED))
			{
				stalledReasons.add(chain.ErrorMessage__c);
			}
			stalledReasons.sort();

			List<String> expectedReasons = new List<String> {'No live executor detected by watchdog sweep', PARKED_NO_QUERY_BUDGET_REASON, PARKED_NO_QUERY_BUDGET_REASON};
			Assert.areEqual(expectedReasons, stalledReasons, 'One candidate must be handled normally, and two set aside with the no-queries-left reason, in any order');
			Integer untouchedCount = new SEL_AsyncChainExecution().findByStatus(SEL_AsyncChainExecution.STATUS_RUNNING).size();
			Assert.areEqual(1, untouchedCount, 'The candidate after the last one there were queries for must stay Running, untouched, for a later sweep');
			Assert.areEqual(0, errorHandlerRunCount, 'Setting chains aside must fire no notification');
			Test.stopTest();
		}
	}

	/**
	 * @description Verifies that a failure when the re-drive saves a new run key stays with that one chain. The
	 * candidate's job is proven dead, but its record was deleted between the sweep's read and the save. A registered
	 * mock keeps the fresh read valid while the real row is gone, so the DML fails on the deleted row. The failure is
	 * logged with the re-drive's own message and not thrown: sweepCandidate returns instead of letting the exception
	 * stop the whole sweep.
	 */
	@IsTest
	private static void shouldLogAndContinueWhenRedriveRotationWriteFails()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();
			LOG_Builder.ignoreTestMode = true;

			AsyncApexJob deadJob = (AsyncApexJob)TST_Mock.of(AsyncApexJob.SObjectType)
					.withOverride(AsyncApexJob.Status, 'Aborted')
					.build();
			String runKey = UTIL_Random.randomUUID();
			AsyncChainExecution__c execution = TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_RUNNING, TEST_CHAIN_NAME, new Map<SObjectField, Object>
			{
					AsyncChainExecution__c.RunKey__c => runKey,
					AsyncChainExecution__c.CurrentJobId__c => String.valueOf(deadJob.Id),
					AsyncChainExecution__c.StepLog__c => buildStepLogJson()
			});
			AsyncChainExecution__c sweepView = queryExecution(execution.Id);
			DML_Builder.newTransaction().doDelete(execution).execute();
			TST_Mock.register(AsyncChainExecution__c.SObjectType, TST_Builder.of(AsyncChainExecution__c.SObjectType)
					.withOverride(AsyncChainExecution__c.Id, sweepView.Id)
					.withOverride(AsyncChainExecution__c.RunKey__c, runKey)
					.withOverride(AsyncChainExecution__c.Status__c, SEL_AsyncChainExecution.STATUS_RUNNING)
					.withOverride(AsyncChainExecution__c.StepLog__c, buildStepLogJson())
					.withoutInsertion()
					.build());

			Test.startTest();
			UTIL_AsyncChain.sweepCandidate(sweepView);
			Test.stopTest();
			Test.getEventBus().deliver();

			Assert.isTrue
					(
							anyLogMessageContains('Watchdog re-drive failed'),
							'A failed rotation write must be logged with the re-drive leg\'s own message instead of aborting the sweep'
					);
			Assert.areEqual(0, errorHandlerRunCount, 'A failed re-drive must not fire the onError notification');
		}
	}

	/**
	 * @description Verifies, from start to end through runWatchdogSweep, that the sweep goes on after the re-drive of
	 * one candidate fails. One candidate has a job id, and the check whether its job is alive throws a real QueryException
	 * that can be caught. That candidate is logged and left untouched: no mark, no new run key. The other candidate is
	 * still marked Stalled, with the ordinary sweep reason.
	 * Whichever order the selector returns them in, an escaping exception would fail this test at
	 * the sweep call, and an aborted sweep would leave the healthy candidate Running.
	 */
	@IsTest
	private static void shouldContinueTheSweepAfterOneRedriveAttemptFails()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();
			LOG_Builder.ignoreTestMode = true;

			AsyncApexJob probedJob = (AsyncApexJob)TST_Mock.of(AsyncApexJob.SObjectType)
					.withOverride(AsyncApexJob.Status, 'Processing')
					.build();
			TST_Mock.throwsException(AsyncApexJob.SObjectType, new QueryException('Simulated liveness probe failure'));
			String probedRunKey = UTIL_Random.randomUUID();
			AsyncChainExecution__c brokenCandidate = TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_RUNNING, TEST_CHAIN_NAME, new Map<SObjectField, Object>
			{
					AsyncChainExecution__c.RunKey__c => probedRunKey,
					AsyncChainExecution__c.CurrentJobId__c => String.valueOf(probedJob.Id),
					AsyncChainExecution__c.StepLog__c => buildStepLogJson()
			});
			AsyncChainExecution__c healthyCandidate = TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_RUNNING, TEST_CHAIN_NAME);

			Test.startTest();
			UTIL_AsyncChain.runWatchdogSweep(SWEEP_EVERYTHING_THRESHOLD_MINUTES, WATCHDOG_BATCH_SIZE);
			Test.stopTest();
			Test.getEventBus().deliver();

			AsyncChainExecution__c broken = queryExecution(brokenCandidate.Id);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_RUNNING, broken.Status__c, 'A candidate whose re-drive failed stays in place, still stale, for a later sweep');
			Assert.areEqual(probedRunKey, broken.RunKey__c, 'No new run key may be saved when the re-drive fails before it decides');
			AsyncChainExecution__c healthy = queryExecution(healthyCandidate.Id);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_STALLED, healthy.Status__c, 'The sweep must keep handling candidates after one re-drive fails');
			Assert.isTrue(healthy.ErrorMessage__c.contains('No live executor detected by watchdog sweep'), 'The surviving candidate must carry the ordinary sweep stall reason');
			Assert.isTrue(anyLogMessageContains('Watchdog re-drive failed'), 'The failed re-drive must be logged with its own message');
		}
	}

	/**
	 * @description Verifies that the re-drive refuses a candidate with newer activity, and accepts one without it.
	 * If a fresh read shows a LastModifiedDate newer than the sweep's copy of the row, something saved the record after
	 * the sweep saw it, and a live job may be running it. So the re-drive skips the candidate (no new run key, nothing
	 * queued) and logs the skip. If the sweep's copy is not older than the fresh read, the re-drive still runs the same
	 * chain to completion.
	 */
	@IsTest
	private static void shouldSkipRedriveWhenFreshReadShowsNewerActivity()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();
			LOG_Builder.ignoreTestMode = true;

			String runKey = UTIL_Random.randomUUID();
			AsyncChainExecution__c execution = TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_STALLED, TEST_CHAIN_NAME, new Map<SObjectField, Object>
			{
					AsyncChainExecution__c.StartedAt__c => Datetime.now(),
					AsyncChainExecution__c.RunKey__c => runKey,
					AsyncChainExecution__c.StepLog__c => buildStepLogJson()
			});
			AsyncChainExecution__c backdatedSweepView = (AsyncChainExecution__c)TST_Builder.of(AsyncChainExecution__c.SObjectType)
					.withOverride(AsyncChainExecution__c.Id, execution.Id)
					.withOverride(AsyncChainExecution__c.RunKey__c, runKey)
					.withOverride(AsyncChainExecution__c.LastModifiedDate, Datetime.now().addMinutes(-BACKDATED_SWEEP_VIEW_AGE_MINUTES))
					.withoutInsertion()
					.build();

			Integer enqueuedJobsBeforeRedrive = UTIL_Limits.queueableJobs().used();
			UTIL_AsyncChain.redriveStalledChain(backdatedSweepView);
			Test.getEventBus().deliver();

			AsyncChainExecution__c skipped = queryExecution(execution.Id);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_STALLED, skipped.Status__c, 'A candidate with activity newer than the sweep view must stay untouched');
			Assert.areEqual(runKey, skipped.RunKey__c, 'No new run key may be saved when the fresh read shows newer activity: a live job may be running the chain');
			Assert.areEqual(enqueuedJobsBeforeRedrive, UTIL_Limits.queueableJobs().used(), 'Skipping for newer activity must queue no job');
			Assert.isTrue(anyLogMessageContains('Watchdog re-drive skipped'), 'The newer-activity skip must be logged');

			Test.startTest();
			UTIL_AsyncChain.redriveStalledChain(queryExecution(execution.Id));
			Test.stopTest();

			AsyncChainExecution__c recovered = queryExecution(execution.Id);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_COMPLETED, recovered.Status__c, 'A sweep view no newer than the fresh read must still re-drive the chain to completion');
			Assert.areNotEqual(runKey, recovered.RunKey__c, 'With equal times, the re-drive must set a new run key and recover the chain');
		}
	}

	/**
	 * @description Verifies handler saving: executing a chain built with onError and onComplete
	 * appends both handler definitions to the saved StepLog__c after the step entries, flagged
	 * with isErrorHandler or isCompletionHandler, while the job's step counting ignores them. The chain completes
	 * with the true step total, and the handler entries get no fields that a step adds while it runs.
	 */
	@IsTest
	private static void shouldPersistHandlerEntriesAfterStepsInStepLog()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();

			Test.startTest();
			String executionId = UTIL_AsyncChain.newChain(TEST_CHAIN_NAME)
					.then(new UTIL_AsyncChainRecovery_TEST.SuccessStep())
					.onError(new UTIL_AsyncChainRecovery_TEST.ErrorHandlerStep())
					.onComplete(new UTIL_AsyncChainRecovery_TEST.CompletionHandlerStep())
					.withAsyncOptions(createAsyncOptions(2))
					.execute();
			Test.stopTest();

			AsyncChainExecution__c execution = queryExecution(executionId);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_COMPLETED, execution.Status__c, 'The job must not run handler entries as steps: one real step completes the chain');
			Assert.areEqual(1, execution.TotalSteps__c, 'Handler entries are not steps: the persisted step total must not count them');
			Assert.areEqual(1, execution.CompletedSteps__c, 'Only the real step may count as completed');
			Assert.areEqual(true, parseContextData(execution).get('completionHandlerExecuted'), 'The completion handler must still fire through its own job');

			List<UTIL_AsyncChain.DTO_StepDefinition> persisted = (List<UTIL_AsyncChain.DTO_StepDefinition>)
					JSON.deserialize(execution.StepLog__c, List<UTIL_AsyncChain.DTO_StepDefinition>.class);
			Assert.areEqual(3, persisted.size(), 'The persisted step log must carry the step plus both handler definitions');
			Assert.areEqual(true, persisted[0].success, 'The first entry is the executed step, carrying its runtime result');
			Assert.isNull(persisted[0].isErrorHandler, 'Step entries carry no handler flag');
			Assert.areEqual(true, persisted[1].isErrorHandler, 'The onError definition must follow the step entries with its flag set');
			Assert.isNull(persisted[1].success, 'Handler entries never gain runtime step fields');
			Assert.areEqual(true, persisted[2].isCompletionHandler, 'The onComplete definition must follow the step entries with its flag set');
		}
	}

	/**
	 * @description Verifies end-to-end that a stalled chain's onError notification can come from
	 * the watchdog sweep alone: for a chain saved by ChainBuilder with an onError
	 * registration, the sweep resolves the handler purely from the saved step log and runs
	 * the notification. The builder runs outside startTest, and its queued job is aborted through the job id the builder
	 * saved. So the row stays Running, exactly like a real chain whose job died, and no job runs at stopTest to finish
	 * the chain. clearEnqueueTimeStamp then blanks the CurrentJobId__c that ChainBuilder.execute saves when it queues
	 * the job. This stands for a row saved by a package version that did not save the job id. Only a row with no job id
	 * reaches the sweep's path for chains it cannot check, which marks and notifies (see sweepCandidate in
	 * UTIL_AsyncChain). A row with a job id goes to the check whether the job is alive instead.
	 */
	@IsTest
	private static void shouldNotifyBuilderPersistedOnErrorHandlerViaSweep()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();

			String executionId = UTIL_AsyncChain.newChain(TEST_CHAIN_NAME)
					.then(new UTIL_AsyncChainRecovery_TEST.SuccessStep())
					.onError(new UTIL_AsyncChainRecovery_TEST.CountingErrorHandlerStep())
					.withAsyncOptions(createAsyncOptions(2))
					.execute();
			System.abortJob(queryExecution(executionId).CurrentJobId__c);
			clearEnqueueTimeStamp(executionId);

			Test.startTest();
			UTIL_AsyncChain.runWatchdogSweep(SWEEP_EVERYTHING_THRESHOLD_MINUTES, WATCHDOG_BATCH_SIZE);
			Test.stopTest();

			Assert.areEqual(1, errorHandlerRunCount, 'The sweep must resolve the builder-persisted onError handler and notify exactly once');
			AsyncChainExecution__c result = queryExecution(executionId);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_STALLED, result.Status__c, 'The sweep marks the stale chain Stalled');
			Assert.isTrue(result.ErrorMessage__c.contains('No live executor detected by watchdog sweep'), 'Saving the notification\'s result must keep the sweep reason');
		}
	}

	/**
	 * @description Verifies the watchdog re-drive from start to end. The row is a stale Running chain in the middle of
	 * its steps, and its saved job is dead. Then:
	 * 1. The run gets a new run key, so the old job can no longer save to it.
	 * 2. A new job, rebuilt from the saved data, is queued at the saved completed-step count. It finishes the
	 *    remaining step with the saved context.
	 * 3. The completion handler, rebuilt from the saved step log, fires.
	 * 4. A job that still carries the old run key is blocked, so the chain is not finished twice.
	 * The test calls redriveStalledChain directly (it is @TestVisible so a test can call it).
	 * shouldRedriveDeadCandidateThroughSweepPath checks the same through the sweep itself.
	 */
	@IsTest
	private static void shouldRedriveStaleChainAndBlockTheOldExecutor()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();

			String staleRunKey = UTIL_Random.randomUUID();
			AsyncChainExecution__c execution = seedMidChainDeadRedriveCandidate(staleRunKey);

			AsyncOptions oldJobOptions = createAsyncOptions(2);

			Test.startTest();
			UTIL_AsyncChain.redriveStalledChain(queryExecution(execution.Id));
			String rotatedRunKey = queryExecution(execution.Id).RunKey__c;
			System.enqueueJob(new UTIL_AsyncChain.ChainExecutor(execution.Id, 1, 50, 32768, null, null, oldJobOptions, staleRunKey), oldJobOptions);
			Test.stopTest();

			Assert.isNotNull(rotatedRunKey, 'The re-drive must stamp a run key');
			Assert.areNotEqual(staleRunKey, rotatedRunKey, 'The re-drive must set a new run key, so any old job is blocked');
			AsyncChainExecution__c result = queryExecution(execution.Id);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_COMPLETED, result.Status__c, 'The rebuilt job must complete the remaining steps');
			Assert.areEqual(2, result.CompletedSteps__c, 'Exactly the one remaining step may run: the old job is blocked and handler entries are not steps');
			Assert.areEqual(2, result.TotalSteps__c, 'Handler entries persisted in the step log must not change the step total');
			Assert.areEqual(rotatedRunKey, result.RunKey__c, 'The chain must finish under the new key: the blocked old job may not take it back');
			Assert.isNotNull(result.CompletedAt__c, 'The rebuilt job finishes the chain');
			Assert.areEqual(2, parseContextData(result).get('stepCount'), 'The remaining step must run with the restored context, not a fresh one');
			Assert.areEqual(true, parseContextData(result).get('completionHandlerExecuted'), 'The completion handler rebuilt from the saved step log must fire');
			Assert.areEqual(0, errorHandlerRunCount, 'The rebuilt error handler must not fire on a successful recovery');
			Assert.isNull(result.LastManualRetryAt__c, 'The watchdog is not a person: its re-drive never stamps a manual retry');
			for(UTIL_AsyncChain.DTO_StepDefinition redrivenEntry : (List<UTIL_AsyncChain.DTO_StepDefinition>)
					JSON.deserialize(result.StepLog__c, List<UTIL_AsyncChain.DTO_StepDefinition>.class))
			{
				Assert.isNull(redrivenEntry.manualRetryAfterMs, 'The watchdog never marks a step as manually retried');
			}
		}
	}

	/**
	 * @description Verifies the job id the re-drive saves when it queues. As soon as redriveStalledChain queues the
	 * rebuilt job, CurrentJobId__c must hold that new job's id, not the dead job's. So the check whether the job is
	 * alive follows the new job before its first progress save. The test calls redriveStalledChain directly (it is
	 * @TestVisible so a test can call it), outside startTest and stopTest, so the queued job never runs. The job id read
	 * back is therefore the one the re-drive saved, not a later progress save.
	 */
	@IsTest
	private static void shouldStampExecutorJobIdOnWatchdogRedrive()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();

			AsyncChainExecution__c execution = seedMidChainDeadRedriveCandidate(UTIL_Random.randomUUID());
			AsyncChainExecution__c beforeRedrive = queryExecution(execution.Id);
			String staleJobIdBeforeRedrive = beforeRedrive.CurrentJobId__c;
			Assert.isNotNull(staleJobIdBeforeRedrive, 'Set-up check: the candidate must carry the old job id, or the check that it was replaced proves nothing');

			UTIL_AsyncChain.redriveStalledChain(beforeRedrive);

			AsyncChainExecution__c redriven = queryExecution(execution.Id);
			Assert.isNotNull(redriven.CurrentJobId__c, 'The re-drive must save the new job\'s id');
			Assert.areNotEqual(staleJobIdBeforeRedrive, redriven.CurrentJobId__c, 'The old job id must be replaced when the new job is queued');
		}
	}

	/**
	 * @description Verifies the upgrade path. A re-drive of an old row, saved before run keys existed (RunKey__c is
	 * null), sets a real key. The null key equals the null the sweep read, so the candidate qualifies, and the new key
	 * lets the recovered run block old jobs. The test uses a Stalled candidate, the other status that qualifies, beside
	 * the main test's Running row.
	 */
	@IsTest
	private static void shouldStampRealRunKeyWhenRedrivingLegacyChain()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();

			AsyncChainExecution__c execution = TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_STALLED, TEST_CHAIN_NAME, new Map<SObjectField, Object>
			{
					AsyncChainExecution__c.StartedAt__c => Datetime.now(),
					AsyncChainExecution__c.RunKey__c => null,
					AsyncChainExecution__c.StepLog__c => buildStepLogJson()
			});

			Test.startTest();
			UTIL_AsyncChain.redriveStalledChain(queryExecution(execution.Id));
			Test.stopTest();

			AsyncChainExecution__c result = queryExecution(execution.Id);
			Assert.isNotNull(result.RunKey__c, 'A re-drive of an old row with no run key must set a real run key');
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_COMPLETED, result.Status__c, 'The old chain, started again, must complete under the current job');
			Assert.areEqual(1, result.CompletedSteps__c, 'The one rebuilt step must run');
		}
	}

	/**
	 * @description Verifies a chain that reached a final status between the sweep's read and the re-drive is left
	 * untouched. The fresh read, made to be safe, sees Completed. So no new run key, no status change and no queued
	 * job may happen: a finished chain must never run again.
	 */
	@IsTest
	private static void shouldNotRedriveChainCompletedSinceSweepRead()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();

			String runKey = UTIL_Random.randomUUID();
			AsyncChainExecution__c sweepView = TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_COMPLETED, TEST_CHAIN_NAME, new Map<SObjectField, Object>
			{
					AsyncChainExecution__c.RunKey__c => runKey,
					AsyncChainExecution__c.StepLog__c => buildStepLogJson(),
					AsyncChainExecution__c.CompletedAt__c => Datetime.now()
			});
			sweepView.Status__c = SEL_AsyncChainExecution.STATUS_RUNNING;

			Integer enqueuedJobsBeforeRedrive = UTIL_Limits.queueableJobs().used();
			UTIL_AsyncChain.redriveStalledChain(sweepView);

			AsyncChainExecution__c result = queryExecution(sweepView.Id);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_COMPLETED, result.Status__c, 'A chain that completed in the meantime must stay Completed');
			Assert.areEqual(runKey, result.RunKey__c, 'No new run key may be saved on a chain that completed in the meantime');
			Assert.areEqual(enqueuedJobsBeforeRedrive, UTIL_Limits.queueableJobs().used(), 'No job may be queued for a chain that completed in the meantime');
		}
	}

	/**
	 * @description Verifies a chain that something else took over between the sweep's read and the re-drive is left
	 * untouched. The fresh read sees a different run key, so the candidate is not this sweep's to handle. A record
	 * deleted since the sweep's read is handled the same way: no save, nothing queued, nothing thrown.
	 */
	@IsTest
	private static void shouldNotRedriveChainClaimedSinceSweepRead()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();

			String currentRunKey = UTIL_Random.randomUUID();
			AsyncChainExecution__c execution = TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_RUNNING, TEST_CHAIN_NAME, new Map<SObjectField, Object>
			{
					AsyncChainExecution__c.RunKey__c => currentRunKey,
					AsyncChainExecution__c.StepLog__c => buildStepLogJson()
			});
			AsyncChainExecution__c sweepView = queryExecution(execution.Id);
			sweepView.RunKey__c = UTIL_Random.randomUUID();

			Integer enqueuedJobsBeforeRedrive = UTIL_Limits.queueableJobs().used();
			UTIL_AsyncChain.redriveStalledChain(sweepView);

			AsyncChainExecution__c claimedResult = queryExecution(execution.Id);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_RUNNING, claimedResult.Status__c, 'A claimed chain must keep its current status');
			Assert.areEqual(currentRunKey, claimedResult.RunKey__c, 'A chain taken over must keep the new owner\'s key: the sweep may not replace it');

			AsyncChainExecution__c deletedView = queryExecution(execution.Id);
			DML_Builder.newTransaction().doDelete(execution).execute();
			UTIL_AsyncChain.redriveStalledChain(deletedView);

			Assert.areEqual(enqueuedJobsBeforeRedrive, UTIL_Limits.queueableJobs().used(), 'Neither a candidate taken over nor a deleted one may queue a job');
		}
	}

	/**
	 * @description Verifies the fallback for a chain that cannot be recovered. A re-drive candidate whose saved step log
	 * cannot be read, is blank, or does not match the recorded progress is marked Failed for good, with a reason that
	 * says what to do, instead of Stalled. A step log that cannot be read never repairs itself. Leaving the row Stalled
	 * would only set it aside again, with no warning, on every sweep forever.
	 */
	@IsTest
	private static void shouldFailRedriveCandidateWithUnrecoverableStepLog()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();

			AsyncChainExecution__c corruptLog = TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_STALLED, TEST_CHAIN_NAME, new Map<SObjectField, Object>
			{
					AsyncChainExecution__c.StartedAt__c => Datetime.now(),
					AsyncChainExecution__c.RunKey__c => UTIL_Random.randomUUID(),
					AsyncChainExecution__c.StepLog__c => 'not step-log json'
			});
			AsyncChainExecution__c blankLog = TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_STALLED, TEST_CHAIN_NAME);
			AsyncChainExecution__c inconsistentProgress = TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_STALLED, TEST_CHAIN_NAME, new Map<SObjectField, Object>
			{
					AsyncChainExecution__c.CompletedSteps__c => 5,
					AsyncChainExecution__c.StepLog__c => buildStepLogJson()
			});

			UTIL_AsyncChain.redriveStalledChain(queryExecution(corruptLog.Id));
			UTIL_AsyncChain.redriveStalledChain(queryExecution(blankLog.Id));
			UTIL_AsyncChain.redriveStalledChain(queryExecution(inconsistentProgress.Id));

			AsyncChainExecution__c corruptResult = queryExecution(corruptLog.Id);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_FAILED, corruptResult.Status__c, 'An unparseable step log must fail the candidate terminally');
			Assert.areEqual(corruptLog.StepLog__c, corruptResult.StepLog__c, 'Expected the fallback to leave the step log as it was, got ' + corruptResult.StepLog__c);
			Assert.areEqual(buildStepLogJson(), queryExecution(inconsistentProgress.Id).StepLog__c, 'Expected the fallback to leave a step log that parses as it was');
			Assert.isTrue(corruptResult.ErrorMessage__c.contains(REDRIVE_UNRECOVERABLE_FRAGMENT), 'The failure must carry the re-drive reason that says what to do');
			Assert.isNotNull(corruptResult.CompletedAt__c, 'Failed is a final status: the fallback must set CompletedAt');
			Assert.isNotNull(corruptResult.DurationMs__c, 'A candidate with a start time must receive its duration at terminal failure');
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_FAILED, queryExecution(blankLog.Id).Status__c, 'A blank step log must fail the candidate terminally');
			Assert.areEqual
					(SEL_AsyncChainExecution.STATUS_FAILED, queryExecution(inconsistentProgress.Id).Status__c, 'Progress past the persisted step count must fail the candidate');
		}
	}

	/**
	 * @description A run retried months after it started still finishes: the job's completion write stores the most the
	 * duration field can hold instead of a value the field refuses.
	 */
	@IsTest
	private static void shouldFinishARunOlderThanTheDurationFieldCanHold()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();
			AsyncChainExecution__c execution = seedFailedRetryChain(buildRetryEligibleStepLog());
			execution.StartedAt__c = Datetime.now().addDays(-OVERLONG_RUN_AGE_DAYS);
			DML_Builder.newTransaction().withSystemMode().doUpdate(execution).execute();

			Test.startTest();
			UTIL_AsyncChain.retryChainFromFailedStep(execution.Id);
			Test.stopTest();

			AsyncChainExecution__c result = queryExecution(execution.Id);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_COMPLETED, result.Status__c, 'The run must be able to record its end: ' + result.ErrorMessage__c);
			Assert.areEqual(EXPECTED_STORED_DURATION_MAX, result.DurationMs__c.longValue(), 'The stored duration is capped at what the field can hold');
		}
	}

	/**
	 * @description An operator can abort a run that has been stalled for months: the abort's own duration write is capped too.
	 */
	@IsTest
	private static void shouldAbortARunOlderThanTheDurationFieldCanHold()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();
			AsyncChainExecution__c execution = TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_STALLED, TEST_CHAIN_NAME, new Map<SObjectField, Object>
			{
					AsyncChainExecution__c.StartedAt__c => Datetime.now().addDays(-OVERLONG_RUN_AGE_DAYS)
			});

			Boolean aborted = UTIL_AsyncChain.abortExecution(execution.Id, OVERLONG_ABORT_REASON);

			AsyncChainExecution__c result = queryExecution(execution.Id);
			Assert.isTrue(aborted, 'The abort must commit');
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_ABORTED, result.Status__c, 'The run must be able to record its end');
			Assert.areEqual(EXPECTED_STORED_DURATION_MAX, result.DurationMs__c.longValue(), 'The stored duration is capped at what the field can hold');
			Assert.isNull(result.LastManualRetryAt__c, 'An abort is not a manual retry, so it never stamps the retry date');
		}
	}

	/**
	 * @description The watchdog can give up on a months-old run whose step log is unreadable: its terminal write is capped too.
	 */
	@IsTest
	private static void shouldFailAnUnrecoverableRunOlderThanTheDurationFieldCanHold()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();
			AsyncChainExecution__c execution = TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_STALLED, TEST_CHAIN_NAME, new Map<SObjectField, Object>
			{
					AsyncChainExecution__c.StartedAt__c => Datetime.now().addDays(-OVERLONG_RUN_AGE_DAYS),
					AsyncChainExecution__c.RunKey__c => UTIL_Random.randomUUID(),
					AsyncChainExecution__c.StepLog__c => MALFORMED_STEP_LOG_JSON
			});

			UTIL_AsyncChain.redriveStalledChain(queryExecution(execution.Id));

			AsyncChainExecution__c result = queryExecution(execution.Id);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_FAILED, result.Status__c, 'The run must be able to record its end');
			Assert.areEqual(EXPECTED_STORED_DURATION_MAX, result.DurationMs__c.longValue(), 'The stored duration is capped at what the field can hold');
		}
	}

	/**
	 * @description Verifies that the fallback for a re-drive that cannot recover sets the Stalled failure category (the
	 * failure started as a stall), beside the final Failed status.
	 */
	@IsTest
	private static void shouldCategoriseUnrecoverableRedriveAsStalled()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();

			AsyncChainExecution__c corruptLog = TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_STALLED, TEST_CHAIN_NAME, new Map<SObjectField, Object>
			{
					AsyncChainExecution__c.StartedAt__c => Datetime.now(),
					AsyncChainExecution__c.RunKey__c => UTIL_Random.randomUUID(),
					AsyncChainExecution__c.StepLog__c => 'not step-log json'
			});

			UTIL_AsyncChain.redriveStalledChain(queryExecution(corruptLog.Id));

			AsyncChainExecution__c result = queryExecution(corruptLog.Id);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_FAILED, result.Status__c, 'An unparseable step log must fail the candidate terminally');
			Assert.areEqual(SEL_AsyncChainExecution.FAILURE_CATEGORY_STALLED, result.FailureCategory__c, 'An unrecoverable re-drive must be categorised Stalled');
		}
	}

	/**
	 * @description Verifies the fallback for a re-drive candidate whose job is dead and whose saved step log is a
	 * document in the format of versions before 1.4, cut off in the middle of the array. Reading the JSON throws, but
	 * no exception leaves the sweep. Instead:
	 * 1. The candidate ends Failed for good, with the Stalled category and the same reason as every other step log
	 *    that cannot be recovered.
	 * 2. The fallback sets a new run key, so no old job can overwrite the Failed result.
	 * 3. The cut-off document stays in place, so someone can look at it.
	 * 4. The notification is skipped and nothing is queued, because no handler can be found in a document that
	 *    cannot be read.
	 */
	@IsTest
	private static void shouldFailTruncatedPre14StepLogActionablyOnRedrive()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();

			AsyncApexJob deadJob = (AsyncApexJob)TST_Mock.of(AsyncApexJob.SObjectType)
					.withOverride(AsyncApexJob.Status, 'Aborted')
					.build();
			String staleRunKey = UTIL_Random.randomUUID();
			String truncatedStepLog = buildTruncatedLegacyStepLog();
			AsyncChainExecution__c execution = TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_RUNNING, TEST_CHAIN_NAME, new Map<SObjectField, Object>
			{
					AsyncChainExecution__c.TotalSteps__c => 2,
					AsyncChainExecution__c.CompletedSteps__c => 1,
					AsyncChainExecution__c.StartedAt__c => Datetime.now(),
					AsyncChainExecution__c.RunKey__c => staleRunKey,
					AsyncChainExecution__c.CurrentJobId__c => String.valueOf(deadJob.Id),
					AsyncChainExecution__c.StepLog__c => truncatedStepLog
			});

			Test.startTest();
			Integer enqueuedJobsBeforeSweep = UTIL_Limits.queueableJobs().used();
			UTIL_AsyncChain.runWatchdogSweep(SWEEP_EVERYTHING_THRESHOLD_MINUTES, WATCHDOG_BATCH_SIZE);
			Assert.areEqual(enqueuedJobsBeforeSweep, UTIL_Limits.queueableJobs().used(), 'The fallback must queue neither a job nor a notification');
			Test.stopTest();

			AsyncChainExecution__c result = queryExecution(execution.Id);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_FAILED, result.Status__c, 'A truncated step log must fail the candidate terminally');
			Assert.areEqual(SEL_AsyncChainExecution.FAILURE_CATEGORY_STALLED, result.FailureCategory__c, 'A failure that started as a stall must be categorised Stalled');
			Assert.isTrue(result.ErrorMessage__c.contains(REDRIVE_UNRECOVERABLE_FRAGMENT), 'The failure must carry the re-drive reason that says what to do');
			Assert.isNotNull(result.CompletedAt__c, 'Failed is a final status: the fallback must set CompletedAt');
			Assert.isNotNull(result.DurationMs__c, 'A candidate with a start time must receive its duration at terminal failure');
			Assert.areNotEqual(staleRunKey, result.RunKey__c, 'The fallback must set a new run key, so any old job is blocked');
			Assert.areEqual(truncatedStepLog, result.StepLog__c, 'The fallback must leave the cut-off document in place, so someone can look at it');
			Assert.areEqual(0, errorHandlerRunCount, 'No notification can fire when the step log cannot be parsed');
		}
	}

	/**
	 * @description Verifies the sweep's check for a final status. A candidate that reached a final status between the
	 * selector's read and the decision about that candidate is skipped completely: no stall mark, no notification, no
	 * new reason. The shared marking code reads the row fresh and refuses a finished row on the watchdog's path, which
	 * has no run key check. The test calls sweepCandidate directly with an old copy of the row held in memory, as other
	 * tests here do, because the real selector can never return the finished row that this race produces.
	 */
	@IsTest
	private static void shouldSkipCandidateThatReachedTerminalStatusSinceSweepRead()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();

			AsyncChainExecution__c execution = TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_COMPLETED, TEST_CHAIN_NAME, new Map<SObjectField, Object>
			{
					AsyncChainExecution__c.StepLog__c => buildStepLogJsonWithErrorHandler(),
					AsyncChainExecution__c.CompletedAt__c => Datetime.now()
			});
			AsyncChainExecution__c sweepView = queryExecution(execution.Id);
			sweepView.Status__c = SEL_AsyncChainExecution.STATUS_RUNNING;

			Integer enqueuedJobsBeforeSweep = UTIL_Limits.queueableJobs().used();
			UTIL_AsyncChain.sweepCandidate(sweepView);

			AsyncChainExecution__c result = queryExecution(execution.Id);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_COMPLETED, result.Status__c, 'A concurrently-completed candidate must keep its terminal status');
			Assert.isNull(result.ErrorMessage__c, 'The sweep must not write a stall reason onto a terminal row');
			Assert.isNotNull(result.CompletedAt__c, 'The completion stamp must survive the sweep untouched');
			Assert.areEqual(0, errorHandlerRunCount, 'No notification may fire for a terminal row');
			Assert.areEqual(enqueuedJobsBeforeSweep, UTIL_Limits.queueableJobs().used(), 'A skipped terminal row must cost no enqueue');
		}
	}

	/**
	 * @description Verifies the path for a chain that is slow but alive. A stale candidate whose saved job still has a
	 * live platform status is left completely untouched: no stall mark, no notification, no new run key, no re-drive.
	 * Running a live chain twice is a worse fault than the stall the re-drive would fix. The test runs through the real
	 * sweep path, and a registered live AsyncApexJob answers the check whether the job is alive.
	 */
	@IsTest
	private static void shouldSkipSlowButAliveCandidateEntirely()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();

			AsyncApexJob liveJob = (AsyncApexJob)TST_Mock.of(AsyncApexJob.SObjectType)
					.withOverride(AsyncApexJob.Status, 'Processing')
					.build();
			String runKey = UTIL_Random.randomUUID();
			AsyncChainExecution__c execution = TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_RUNNING, TEST_CHAIN_NAME, new Map<SObjectField, Object>
			{
					AsyncChainExecution__c.RunKey__c => runKey,
					AsyncChainExecution__c.CurrentJobId__c => String.valueOf(liveJob.Id),
					AsyncChainExecution__c.StepLog__c => buildStepLogJsonWithErrorHandler()
			});

			Integer enqueuedJobsBeforeSweep = UTIL_Limits.queueableJobs().used();
			UTIL_AsyncChain.runWatchdogSweep(SWEEP_EVERYTHING_THRESHOLD_MINUTES, WATCHDOG_BATCH_SIZE);

			AsyncChainExecution__c result = queryExecution(execution.Id);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_RUNNING, result.Status__c, 'A slow-but-alive chain must stay Running: the sweep may not mark it');
			Assert.isNull(result.ErrorMessage__c, 'The sweep must not write a stall reason while a live job runs the chain');
			Assert.areEqual(runKey, result.RunKey__c, 'The sweep must not set a new run key on a live chain: that would block its live job');
			Assert.areEqual(0, errorHandlerRunCount, 'No notification may fire for a live chain');
			Assert.areEqual(enqueuedJobsBeforeSweep, UTIL_Limits.queueableJobs().used(), 'A live candidate must cost no enqueue');
		}
	}

	/**
	 * @description Proves from start to end, through the real sweep path, that an old job is blocked. The row is a
	 * stale Running chain in the middle of its steps, and its saved job is proven dead. runWatchdogSweep itself starts
	 * it again: it sets a new run key, queues a rebuilt job at the saved resume point, and the chain finishes under the
	 * new key with the saved completion handler. A job that still carries the old key is blocked, so the chain is not
	 * finished twice. This is the sweep-path partner of shouldRedriveStaleChainAndBlockTheOldExecutor, which calls the
	 * re-drive directly.
	 */
	@IsTest
	private static void shouldRedriveDeadCandidateThroughSweepPath()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();

			String staleRunKey = UTIL_Random.randomUUID();
			AsyncChainExecution__c execution = seedMidChainDeadRedriveCandidate(staleRunKey);

			AsyncOptions oldJobOptions = createAsyncOptions(2);

			Test.startTest();
			UTIL_AsyncChain.runWatchdogSweep(SWEEP_EVERYTHING_THRESHOLD_MINUTES, WATCHDOG_BATCH_SIZE);
			String rotatedRunKey = queryExecution(execution.Id).RunKey__c;
			System.enqueueJob(new UTIL_AsyncChain.ChainExecutor(execution.Id, 1, 50, 32768, null, null, oldJobOptions, staleRunKey), oldJobOptions);
			Test.stopTest();

			Assert.areNotEqual(staleRunKey, rotatedRunKey, 'The sweep itself must set a new run key when it starts a dead candidate again');
			AsyncChainExecution__c result = queryExecution(execution.Id);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_COMPLETED, result.Status__c, 'The job the sweep queued must complete the remaining step');
			Assert.areEqual(2, result.CompletedSteps__c, 'Exactly the one remaining step may run: the old job is blocked');
			Assert.areEqual(rotatedRunKey, result.RunKey__c, 'The chain must finish under the new key the sweep set');
			Assert.areEqual(2, parseContextData(result).get('stepCount'), 'The remaining step must run with the restored context');
			Assert.areEqual(true, parseContextData(result).get('completionHandlerExecuted'), 'The persisted completion handler must fire on the sweep-driven recovery');
			Assert.areEqual(0, errorHandlerRunCount, 'The persisted error handler must not fire on a successful sweep-driven recovery');
		}
	}

	/**
	 * @description Verifies the path for a chain the sweep cannot check also handles a broken job id. A candidate whose
	 * CurrentJobId__c holds text that is not a valid AsyncApexJob id gives the sweep no job to check. So the sweep falls
	 * back to marking the chain and notifying, exactly as for an empty job id. It does not throw out of the whole sweep,
	 * and it does not start again a chain it cannot prove dead.
	 */
	@IsTest
	private static void shouldFallBackToMarkAndNotifyWhenJobIdMalformed()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();

			String runKey = UTIL_Random.randomUUID();
			AsyncChainExecution__c execution = TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_RUNNING, TEST_CHAIN_NAME, new Map<SObjectField, Object>
			{
					AsyncChainExecution__c.RunKey__c => runKey,
					AsyncChainExecution__c.CurrentJobId__c => 'not-a-valid-job-id',
					AsyncChainExecution__c.StepLog__c => buildStepLogJsonWithErrorHandler()
			});

			Test.startTest();
			UTIL_AsyncChain.runWatchdogSweep(SWEEP_EVERYTHING_THRESHOLD_MINUTES, WATCHDOG_BATCH_SIZE);
			Test.stopTest();

			AsyncChainExecution__c result = queryExecution(execution.Id);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_STALLED, result.Status__c, 'A job id that cannot be used must make the sweep fall back to the stall mark');
			Assert.areEqual(runKey, result.RunKey__c, 'A candidate the sweep cannot check must never be started again: the run key must not change');
			Assert.areEqual(1, errorHandlerRunCount, 'The fallback must still notify the saved onError handler once');
		}
	}

	/**
	 * @description Verifies the fallback for a chain that cannot be recovered notifies before it fails. The re-drive
	 * candidate's saved log has an onError handler but no step left to resume (every entry already has a success
	 * marker). It is marked Failed for good, with the reason that says what to do, AND its saved onError handler is
	 * notified exactly once, through the shared notification code. The test also checks that the fallback sets a new
	 * run key with the final save.
	 */
	@IsTest
	private static void shouldNotifyPersistedHandlerWhenTheChainCannotBeRecovered()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();

			String preDegradeRunKey = UTIL_Random.randomUUID();
			AsyncChainExecution__c execution = TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_STALLED, TEST_CHAIN_NAME, new Map<SObjectField, Object>
			{
					AsyncChainExecution__c.StartedAt__c => Datetime.now(),
					AsyncChainExecution__c.RunKey__c => preDegradeRunKey,
					AsyncChainExecution__c.CompletedSteps__c => 1,
					AsyncChainExecution__c.StepLog__c => buildAllAttemptedStepLogWithErrorHandler()
			});

			Test.startTest();
			UTIL_AsyncChain.redriveStalledChain(queryExecution(execution.Id));
			Test.stopTest();

			AsyncChainExecution__c result = queryExecution(execution.Id);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_FAILED, result.Status__c, 'A candidate with no unattempted step to resume must fail terminally');
			Assert.isTrue(result.ErrorMessage__c.contains(REDRIVE_UNRECOVERABLE_FRAGMENT), 'The failure must carry the re-drive reason that says what to do');
			Assert.areEqual(1, errorHandlerRunCount, 'The fallback must notify the saved onError handler exactly once before failing');
			Assert.areNotEqual(preDegradeRunKey, result.RunKey__c, 'The fallback must set a new run key, so no old job can overwrite its Failed result');
			Assert.isNotNull(result.CompletedAt__c, 'Failed is a final status: the fallback must set CompletedAt');
		}
	}

	/**
	 * @description Verifies that no old job can overwrite the fallback's Failed result. After the fallback sets a new
	 * run key and fails the chain, an old job that still carries the earlier key cannot overwrite the Failed result. Its
	 * Finalizer's recovery save is blocked by the new key, and the record keeps the reason that says what to do.
	 */
	@IsTest
	private static void shouldBlockOldJobAfterTheFallbackFailsTheChain()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();

			String oldJobRunKey = UTIL_Random.randomUUID();
			AsyncChainExecution__c execution = TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_STALLED, TEST_CHAIN_NAME, new Map<SObjectField, Object>
			{
					AsyncChainExecution__c.RunKey__c => oldJobRunKey,
					AsyncChainExecution__c.StepLog__c => 'not step-log json'
			});
			UTIL_AsyncChain.redriveStalledChain(queryExecution(execution.Id));

			UTIL_AsyncChain.ChainExecutor oldJob = new UTIL_AsyncChain.ChainExecutor(execution.Id, 0, 50, 32768, null, null, createAsyncOptions(2), oldJobRunKey);
			oldJob.markChainFailedFromFinalizer(execution.Id, 'Old job crash after the fallback');

			AsyncChainExecution__c result = queryExecution(execution.Id);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_FAILED, result.Status__c, 'The chain the fallback failed must stay Failed');
			Assert.isTrue(result.ErrorMessage__c.contains(REDRIVE_UNRECOVERABLE_FRAGMENT), 'The old job\'s save must be blocked: the fallback reason must stay');
			Assert.isFalse(result.ErrorMessage__c.contains('Old job crash after the fallback'), 'The old job with the earlier key may not overwrite the Failed result');
		}
	}

	/**
	 * @description Verifies how the resume point is found. A chain started again resumes at the first step that was
	 * NOT tried yet (success marker null), not at the CompletedSteps__c position. CompletedSteps__c counts only
	 * successes. So after a continueOnError failure, the count is behind the true position, and using it would run
	 * again the step that already failed and was passed. The test checks both parts: the chain completes cleanly (running
	 * that step again would add a non-fatal failure to ErrorMessage__c), and only the one step not tried yet runs.
	 */
	@IsTest
	private static void shouldResumeAtFirstUnattemptedStepAfterContinueOnErrorHistory()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();

			AsyncChainExecution__c execution = TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_STALLED, TEST_CHAIN_NAME, new Map<SObjectField, Object>
			{
					AsyncChainExecution__c.TotalSteps__c => 3,
					AsyncChainExecution__c.CompletedSteps__c => 1,
					AsyncChainExecution__c.StartedAt__c => Datetime.now(),
					AsyncChainExecution__c.RunKey__c => UTIL_Random.randomUUID(),
					AsyncChainExecution__c.StepLog__c => buildContinueOnErrorHistoryStepLog(),
					AsyncChainExecution__c.ContextData__c => JSON.serialize(new Map<String, Object> {'stepCount' => 1})
			});

			Test.startTest();
			UTIL_AsyncChain.redriveStalledChain(queryExecution(execution.Id));
			Test.stopTest();

			AsyncChainExecution__c result = queryExecution(execution.Id);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_COMPLETED, result.Status__c, 'The chain started again must complete from the first step not tried yet');
			Assert.areEqual(2, parseContextData(result).get('stepCount'), 'Exactly one step may run on resume: the third step, not tried yet');
			Assert.areEqual(2, result.CompletedSteps__c, 'The resumed success joins the one persisted success');
			Assert.isNull(result.ErrorMessage__c, 'No step may run twice: running again the step that failed and was passed would add a non-fatal failure');
		}
	}

	/**
	 * @description Verifies the fallback for old rows. A saved step log with no run-time markers on any step entry (the
	 * shape saved before those markers existed) has nothing for the resume point to be found from. So the re-drive
	 * falls back to CompletedSteps__c and resumes past the
	 * recorded successes. The null run key also covers the upgrade case: a record saved by a
	 * package version from before the upgrade qualifies and recovers.
	 */
	@IsTest
	private static void shouldFallBackToCompletedStepsForLegacyLogWithoutMarkers()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();

			AsyncChainExecution__c execution = TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_STALLED, TEST_CHAIN_NAME, new Map<SObjectField, Object>
			{
					AsyncChainExecution__c.TotalSteps__c => 2,
					AsyncChainExecution__c.CompletedSteps__c => 1,
					AsyncChainExecution__c.StartedAt__c => Datetime.now(),
					AsyncChainExecution__c.StepLog__c => buildLegacyMarkerlessStepLog(),
					AsyncChainExecution__c.ContextData__c => JSON.serialize(new Map<String, Object> {'stepCount' => 1})
			});

			Test.startTest();
			UTIL_AsyncChain.redriveStalledChain(queryExecution(execution.Id));
			Test.stopTest();

			AsyncChainExecution__c result = queryExecution(execution.Id);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_COMPLETED, result.Status__c, 'The old chain must complete from the CompletedSteps position');
			Assert.areEqual(2, parseContextData(result).get('stepCount'), 'Only the one step past the recorded successes may run');
			Assert.areEqual(2, result.CompletedSteps__c, 'The resumed success joins the recorded one');
		}
	}

	/**
	 * @description Verifies that the retry save checks the run key like every other save. When the failing step itself
	 * changed the run key, scheduleRetry's save for the next attempt is skipped, and no retry job is queued. The saved
	 * step log keeps its first shape with no attempt marker, no failure is saved, and no retry job ever starts. (A job
	 * that started would log that its run key check at start blocked it.)
	 */
	@IsTest
	private static void shouldRefuseTheRetrySaveWhenTheRunKeyIsStale()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();
			LOG_Builder.ignoreTestMode = true;

			Test.startTest();
			String executionId = UTIL_AsyncChain.newChain(TEST_CHAIN_NAME)
					.then(new UTIL_AsyncChainRecovery_TEST.RotateAndFailWithRetryStep())
					.withAsyncOptions(createAsyncOptions(2))
					.execute();
			Test.stopTest();
			Test.getEventBus().deliver();

			AsyncChainExecution__c execution = queryExecution(executionId);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_RUNNING, execution.Status__c, 'A blocked retry must leave the record on its current run: not Failed, not Stalled');
			Assert.isFalse(execution.StepLog__c.contains('"attempt"'), 'The blocked retry save must not save its attempt marker');
			Assert.isFalse(execution.StepLog__c.contains('"success"'), 'The blocked retry save must not rewrite the step log at all');
			Assert.isNull(execution.ErrorMessage__c, 'A blocked job must not record the failure message');
			Assert.isNull(execution.FailureCategory__c, 'A blocked job must not categorise anything');
			Assert.areEqual(0, execution.CompletedSteps__c, 'No progress may be saved by a blocked job');
			Assert.isTrue(retryStrategyConsultCount > 0, 'The failing step\'s strategy must have been asked: the untouched record then proves the retry save was blocked');
			Assert.isFalse(anyLogMessageContains('Chain step retry scheduled'), 'A blocked retry must never report itself as scheduled');
			Assert.isFalse(anyLogMessageContains('stale run key'), 'No retry job may start at all: the check stops the queuing, not only a retry job that started');
		}
	}

	/**
	 * @description Verifies the run key check at job start catches a delayed retry job that is still waiting after a
	 * watchdog re-drive. By the time the delayed job starts at the retrying step, the record has a new run key. So the
	 * check stops the job before any work: nothing is saved, the attempt marker of the pending retry stays exactly the
	 * same, and the check logs a warning. It is the same test as shouldStopExecutorAtStartWhenTheRunKeyIsStale, with a pending
	 * retry seeded.
	 */
	@IsTest
	private static void shouldStopDelayedRetryExecutorAfterRedrive()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();
			LOG_Builder.ignoreTestMode = true;

			String staleRunKey = UTIL_Random.randomUUID();
			AsyncChainExecution__c execution = TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_RUNNING, TEST_CHAIN_NAME, new Map<SObjectField, Object>
			{
					AsyncChainExecution__c.TotalSteps__c => 2,
					AsyncChainExecution__c.CompletedSteps__c => 1,
					AsyncChainExecution__c.StartedAt__c => Datetime.now(),
					AsyncChainExecution__c.RunKey__c => UTIL_Random.randomUUID(),
					AsyncChainExecution__c.StepLog__c => buildRetryPendingStepLog(),
					AsyncChainExecution__c.ContextData__c => JSON.serialize(new Map<String, Object> {'stepCount' => 1})
			});
			AsyncChainExecution__c beforeFence = queryExecution(execution.Id);
			AsyncOptions options = createAsyncOptions(2);

			Test.startTest();
			System.enqueueJob(new UTIL_AsyncChain.ChainExecutor(execution.Id, 1, 50, 32768, null, null, options, staleRunKey), options);
			Test.stopTest();
			Test.getEventBus().deliver();

			AsyncChainExecution__c result = queryExecution(execution.Id);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_RUNNING, result.Status__c, 'The check at job start must stop the delayed retry job without touching the record');
			Assert.areEqual(1, result.CompletedSteps__c, 'No step may run once the check at job start has stopped the job');
			Assert.areEqual(beforeFence.RunKey__c, result.RunKey__c, 'The run started again must keep its new key');
			Assert.areEqual(beforeFence.StepLog__c, result.StepLog__c, 'The step log with the pending retry must stay exactly the same: the blocked job saves nothing');
			Assert.areEqual(beforeFence.ContextData__c, result.ContextData__c, 'The saved context must stay untouched when the check at job start stops the job');
			Assert.isTrue(anyLogMessageContains('stale run key'), 'The check at job start must log its warning for the blocked delayed retry');
		}
	}

	/**
	 * @description Verifies the Finalizer routes a transient retry enqueue failure to Stalled,
	 * exactly like a failure to queue the next step. The chain waits for recovery instead of failing for good. The
	 * markers of the pending retry that scheduleRetry saved stay after the stall save, which writes only the fields that
	 * change. So a later re-drive resumes AT the retrying step.
	 */
	@IsTest
	private static void shouldRouteRetryEnqueueFailureToStalled()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();

			Test.startTest();
			String executionId = UTIL_AsyncChain.newChain(TEST_CHAIN_NAME)
					.then(new UTIL_AsyncChainRecovery_TEST.FailingWithRetryStep())
					.withAsyncOptions(createAsyncOptions(2))
					.execute();

			UTIL_AsyncChain.simulateEnqueueFailure = true;
			Test.stopTest();
			UTIL_AsyncChain.simulateEnqueueFailure = false;

			AsyncChainExecution__c execution = queryExecution(executionId);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_STALLED, execution.Status__c, 'A transient retry enqueue failure must route the chain to Stalled, not Failed');
			Assert.areEqual(SEL_AsyncChainExecution.FAILURE_CATEGORY_STALLED, execution.FailureCategory__c, 'A retry enqueue failure is a stall, categorised Stalled');
			Assert.isTrue(execution.ErrorMessage__c.contains('Finalizer failed to enqueue next step'), 'The stall reason must name the failed enqueue');
			Assert.isNull(execution.CompletedAt__c, 'Stalled is non-terminal: CompletedAt must stay unset');
			List<UTIL_AsyncChain.DTO_StepDefinition> persisted = parseStepLog(execution);
			Assert.areEqual(RETRY_PENDING_ATTEMPT, persisted[0].attempt, 'The attempt marker of the pending retry must stay after the stall save');
			Assert.isNull(persisted[0].success, 'The cleared success marker must survive the stall, so a later re-drive resumes AT the retrying step');
		}
	}

	/**
	 * @description Verifies retry state cannot corrupt recovery on a row written before starts were
	 * recorded. The chain died during a retry. Its step log carries the attempt marker of the pending retry,
	 * with the success marker cleared and no started marker. The watchdog sweep re-drives it AT
	 * the retrying step's index, because a cleared success marker reads as unattempted and no start
	 * says the step may have run. The attempt marker survives the recovery, and the resumed attempt
	 * completes the chain without replaying the earlier success. The same chain on the current
	 * version carries a start until the stall write takes it back;
	 * shouldTakeBackTheRetryingStepsStartWhenItsRetryEnqueueFails checks that.
	 */
	@IsTest
	private static void shouldResumeRetryingStepOnWatchdogRedriveWhenNoStartWasRecorded()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();

			AsyncApexJob deadJob = (AsyncApexJob)TST_Mock.of(AsyncApexJob.SObjectType)
					.withOverride(AsyncApexJob.Status, 'Aborted')
					.build();
			String staleRunKey = UTIL_Random.randomUUID();
			AsyncChainExecution__c execution = TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_RUNNING, TEST_CHAIN_NAME, new Map<SObjectField, Object>
			{
					AsyncChainExecution__c.TotalSteps__c => 2,
					AsyncChainExecution__c.CompletedSteps__c => 1,
					AsyncChainExecution__c.StartedAt__c => Datetime.now(),
					AsyncChainExecution__c.RunKey__c => staleRunKey,
					AsyncChainExecution__c.CurrentJobId__c => String.valueOf(deadJob.Id),
					AsyncChainExecution__c.StepLog__c => buildRetryPendingStepLog(),
					AsyncChainExecution__c.ContextData__c => JSON.serialize(new Map<String, Object> {'stepCount' => 1})
			});

			Test.startTest();
			UTIL_AsyncChain.runWatchdogSweep(SWEEP_EVERYTHING_THRESHOLD_MINUTES, WATCHDOG_BATCH_SIZE);
			Test.stopTest();

			AsyncChainExecution__c result = queryExecution(execution.Id);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_COMPLETED, result.Status__c, 'The retrying chain, started again, must complete from the step with the pending retry');
			Assert.areEqual(2, result.CompletedSteps__c, 'The resumed attempt joins the one persisted success');
			Assert.areEqual(2, parseContextData(result).get('stepCount'), 'Exactly one step may run on resume: the retrying step, never the completed one again');
			Assert.areNotEqual(staleRunKey, result.RunKey__c, 'The sweep must set a new run key when it starts the dead retrying candidate again');
			List<UTIL_AsyncChain.DTO_StepDefinition> persisted = parseStepLog(result);
			Assert.areEqual(RETRY_PENDING_ATTEMPT, persisted[1].attempt, 'The attempt marker must stay after the re-drive: the record shows which attempt completed');
			Assert.areEqual(true, persisted[1].success, 'The resumed attempt must record its success on the retrying entry');
			Assert.areEqual(true, persisted[0].success, 'The earlier success marker must survive the recovery untouched');
		}
	}

	/**
	 * @description The engine itself produces the row this test sweeps. The chain has two steps. The second step runs and
	 * changes the run key while it runs, so its progress save is lost. A job (one Queueable run of the chain) leaves this
	 * same shape when the platform ends it between the step's work and the save. So the record shows the first step done,
	 * the second step started with no saved result, and the first job's id, which is dead once the test's work has run.
	 * The sweep must not run that
	 * step again: the step never declared itself idempotent and its work may already have happened. The test checks that:
	 * the chain ends Failed with the labelled reason; the started entry is marked as the failed step with that reason; the
	 * run key changes, so an old job still running cannot overwrite the result; the end-of-run fields are saved; and the
	 * step's run count stays at one.
	 */
	@IsTest
	private static void shouldNotRerunAStepThatStartedAndLeftNoResult()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();
			LOG_Builder.ignoreTestMode = true;

			Test.startTest();
			String executionId = UTIL_AsyncChain.newChain(TEST_CHAIN_NAME)
					.then(new UTIL_AsyncChainRecovery_TEST.SuccessStep())
					.then(new UTIL_AsyncChainRecovery_TEST.CountingRotateRunKeyStep())
					.withAsyncOptions(createAsyncOptions(3))
					.execute();
			Test.stopTest();

			AsyncChainExecution__c stranded = queryExecution(executionId);
			List<UTIL_AsyncChain.DTO_StepDefinition> strandedEntries = parseStepLog(stranded);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_RUNNING, stranded.Status__c,
					'Set-up check: expected the blocked job to leave the chain Running, got ' + stranded.Status__c);
			Assert.areEqual(1, rotatingStepRunCount, 'Set-up check: expected the rotating step to have run once, got ' + rotatingStepRunCount);
			Assert.areEqual(true, strandedEntries[1].started, 'Set-up check: expected the first job to record the second step\'s start, got ' + strandedEntries[1].started);
			Assert.isNull(strandedEntries[1].success, 'Set-up check: expected the blocked job to leave no result on the second step, got ' + strandedEntries[1].success);

			UTIL_AsyncChain.runWatchdogSweep(SWEEP_EVERYTHING_THRESHOLD_MINUTES, WATCHDOG_BATCH_SIZE);
			Test.getEventBus().deliver();

			String expectedReason = expectedStartedStepRefusal(CountingRotateRunKeyStep.class.getName());
			AsyncChainExecution__c result = queryExecution(executionId);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_FAILED, result.Status__c,
					'Expected the sweep to end the chain Failed instead of re-running the started step, got ' + result.Status__c);
			Assert.areEqual(SEL_AsyncChainExecution.FAILURE_CATEGORY_STALLED, result.FailureCategory__c, 'Expected the Stalled category, got ' + result.FailureCategory__c);
			Assert.areEqual(expectedReason, result.ErrorMessage__c, 'Expected the labelled reason naming the step, got ' + result.ErrorMessage__c);
			Assert.isNotNull(result.CompletedAt__c, 'Expected Failed to stamp CompletedAt, got null');
			Assert.isNotNull(result.DurationMs__c, 'Expected Failed to stamp the duration, got null');
			Assert.isNull(result.ActiveDeduplicationKey__c, 'Expected the final save to release the deduplication key, got ' + result.ActiveDeduplicationKey__c);
			Assert.areNotEqual(stranded.RunKey__c, result.RunKey__c, 'Expected the refusal to set a new run key so an old job is blocked, got the same key');
			Assert.areEqual(1, result.CompletedSteps__c, 'Expected the completed-step count to stay at the first step, got ' + result.CompletedSteps__c);
			Assert.areEqual(1, rotatingStepRunCount, 'Expected the started step not to run again, got ' + rotatingStepRunCount + ' runs');
			List<UTIL_AsyncChain.DTO_StepDefinition> entries = parseStepLog(result);
			Assert.areEqual(true, entries[0].success, 'Expected the first step\'s success marker untouched, got ' + entries[0].success);
			Assert.areEqual(false, entries[1].success, 'Expected the started entry marked as the failed step, got ' + entries[1].success);
			Assert.areEqual(UTIL_String.abbreviate(expectedReason, STEP_MESSAGE_CAPACITY), entries[1].message, 'Expected the entry to carry the reason, got ' + entries[1].message);
			Assert.areEqual(true, entries[1].started, 'Expected the start to stay on the refused entry, got ' + entries[1].started);
			Assert.isTrue(hasLogEntryAtLevelContaining(LOG_LEVEL_ERROR, expectedReason), 'Expected an ERROR log for the chain\'s end carrying the reason, found none');
		}
	}

	/**
	 * @description A started step the sweep refuses to run again is the step the chain stopped at, even when it was added
	 * with continueOnError: the chain never went on past it. The row ends Failed with the labelled reason, and the retry
	 * gate on the re-read row answers that the step never declared itself safe to run again, not that the chain has no
	 * failed step to resume from.
	 */
	@IsTest
	private static void shouldAnswerStepNotIdempotentForARefusedStepAddedWithContinueOnError()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();

			Test.startTest();
			String executionId = UTIL_AsyncChain.newChain(TEST_CHAIN_NAME)
					.then(new UTIL_AsyncChainRecovery_TEST.SuccessStep())
					.then(new UTIL_AsyncChainRecovery_TEST.CountingRotateRunKeyStep(), true)
					.then(new UTIL_AsyncChainRecovery_TEST.SuccessStep())
					.withAsyncOptions(createAsyncOptions(3))
					.execute();
			Test.stopTest();

			List<UTIL_AsyncChain.DTO_StepDefinition> strandedEntries = parseStepLog(queryExecution(executionId));
			Assert.areEqual(true, strandedEntries[1].started, 'Set-up check: expected the second step\'s start recorded, got ' + strandedEntries[1].started);
			Assert.isNull(strandedEntries[1].success, 'Set-up check: expected the blocked job to leave no result on the second step, got ' + strandedEntries[1].success);
			Assert.areEqual(true, strandedEntries[1].continueOnError, 'Set-up check: expected the second step to continue on error, got ' + strandedEntries[1].continueOnError);

			UTIL_AsyncChain.runWatchdogSweep(SWEEP_EVERYTHING_THRESHOLD_MINUTES, WATCHDOG_BATCH_SIZE);

			AsyncChainExecution__c result = new SEL_AsyncChainExecution().findByIdForMonitoring(executionId);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_FAILED, result.Status__c, 'Expected the sweep to end the chain Failed, got ' + result.Status__c);
			Assert.areEqual(expectedStartedStepRefusal(CountingRotateRunKeyStep.class.getName()), result.ErrorMessage__c,
					'Expected the labelled reason naming the step, got ' + result.ErrorMessage__c);
			Assert.areEqual(false, parseStepLog(result)[1].success, 'Expected the refused entry marked as the failed step, got ' + parseStepLog(result)[1].success);
			String availability = UTIL_AsyncChain.resolveRetryAvailability(result);
			Assert.areEqual(UTIL_AsyncChain.REDRIVE_STEP_NOT_IDEMPOTENT, availability, 'Expected the retry gate to name the undeclared refused step, got ' + availability);
		}
	}

	/**
	 * @description A last step that failed and let the chain go on did not stop the chain when the chain then fails in its
	 * completion handler: the completion write recorded the step's failure, and the handler's failure ends the row Failed
	 * without touching the step log. The retry gate on that row still finds no failed step to resume from.
	 */
	@IsTest
	private static void shouldNotTreatAContinuedLastStepAsTheStepTheChainStoppedAtWhenTheCompletionHandlerFails()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();

			Test.startTest();
			String executionId = UTIL_AsyncChain.newChain(TEST_CHAIN_NAME)
					.then(new UTIL_AsyncChainRecovery_TEST.SuccessStep())
					.then(new UTIL_AsyncChainRecovery_TEST.FailingStep(), true)
					.onComplete(new UTIL_AsyncChainRecovery_TEST.FailingErrorHandlerStep())
					.withAsyncOptions(createAsyncOptions(3))
					.execute();
			Test.stopTest();

			AsyncChainExecution__c result = new SEL_AsyncChainExecution().findByIdForMonitoring(executionId);
			List<UTIL_AsyncChain.DTO_StepDefinition> entries = parseStepLog(result);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_FAILED, result.Status__c, 'Set-up check: expected the failing handler to end the run Failed, got ' + result.Status__c);
			Assert.areEqual(false, entries[1].success, 'Set-up check: expected the continued step\'s failure recorded, got ' + entries[1].success);
			Assert.areEqual(true, entries[1].started, 'Set-up check: expected the continued step\'s start recorded, got ' + entries[1].started);
			String availability = UTIL_AsyncChain.resolveRetryAvailability(result);
			Assert.areEqual(UTIL_AsyncChain.REDRIVE_CONTEXT_UNAVAILABLE, availability, 'Expected no failed step to resume from, got ' + availability);
		}
	}

	/**
	 * @description A step that failed and let the chain go on is never the step the chain stopped at: the job that
	 * recorded its failure recorded the next step's start in the same write. A Failed row whose only failure is such a
	 * continued step, followed by a step that started and recorded no result, still has no failed step to resume from.
	 */
	@IsTest
	private static void shouldNotTreatAContinuedFailureAsTheStepTheChainStoppedAt()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();
			AsyncChainExecution__c execution = seedFailedRetryChain(buildContinuedFailureThenStartedStepLog());

			String availability = UTIL_AsyncChain.resolveRetryAvailability(new SEL_AsyncChainExecution().findByIdForMonitoring(execution.Id));

			Assert.areEqual(UTIL_AsyncChain.REDRIVE_CONTEXT_UNAVAILABLE, availability, 'Expected no failed step to resume from, got ' + availability);
		}
	}

	/**
	 * @description Proves the start is saved BEFORE a step's work runs, by both code paths that save it. The launch's insert
	 * records the first step's start, and the first job's progress save records the second step's. Each step reads its own
	 * entry from the database while its work runs, and keeps what it saw in the context. So a start recorded after the work
	 * (in the step's own progress save) would be read as missing here.
	 */
	@IsTest
	private static void shouldRecordAStepsStartBeforeItRuns()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();

			Test.startTest();
			String executionId = UTIL_AsyncChain.newChain(TEST_CHAIN_NAME)
					.then(new UTIL_AsyncChainRecovery_TEST.StartObservingStep())
					.then(new UTIL_AsyncChainRecovery_TEST.StartObservingStep())
					.withAsyncOptions(createAsyncOptions(3))
					.execute();
			Test.stopTest();

			AsyncChainExecution__c result = queryExecution(executionId);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_COMPLETED, result.Status__c, 'Expected the chain to complete, got ' + result.Status__c + ': ' + result.ErrorMessage__c);
			Map<String, Object> contextData = parseContextData(result);
			Assert.areEqual(true, contextData.get(START_SEEN_KEY_PREFIX + 0),
					'Expected the first step to see its start recorded by the launch while it ran, got ' + contextData.get(START_SEEN_KEY_PREFIX + 0));
			Assert.areEqual(true, contextData.get(START_SEEN_KEY_PREFIX + 1),
					'Expected the second step to see its start recorded by the first hop while it ran, got ' + contextData.get(START_SEEN_KEY_PREFIX + 1));
			List<UTIL_AsyncChain.DTO_StepDefinition> entries = parseStepLog(result);
			Assert.areEqual(true, entries[0].started, 'Expected the first step\'s start to survive the run, got ' + entries[0].started);
			Assert.areEqual(true, entries[1].started, 'Expected the second step\'s start to survive the run, got ' + entries[1].started);
		}
	}

	/**
	 * @description A step to resume with no started marker never ran, because no job for it was ever saved. So the sweep
	 * starts it again as usual: the dead candidate, stopped in the middle of its steps, completes, and the one step not
	 * tried yet runs exactly once.
	 */
	@IsTest
	private static void shouldRedriveAStepWhoseStartWasNeverRecorded()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();

			AsyncChainExecution__c execution = seedMidChainDeadRedriveCandidate(UTIL_Random.randomUUID());
			Assert.isNull(parseStepLog(execution)[1].started, 'Set-up check: expected the pending step to carry no start, got ' + parseStepLog(execution)[1].started);

			Test.startTest();
			UTIL_AsyncChain.runWatchdogSweep(SWEEP_EVERYTHING_THRESHOLD_MINUTES, WATCHDOG_BATCH_SIZE);
			Test.stopTest();

			AsyncChainExecution__c result = queryExecution(execution.Id);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_COMPLETED, result.Status__c,
					'Expected the never-started step to be re-driven to completion, got ' + result.Status__c + ': ' + result.ErrorMessage__c);
			Assert.areEqual(2, parseContextData(result).get(STEP_COUNT_KEY),
					'Expected exactly one run of the pending step on top of the seeded one, got ' + parseContextData(result).get(STEP_COUNT_KEY));
			Assert.areEqual(2, result.CompletedSteps__c, 'Expected the resumed success to join the persisted one, got ' + result.CompletedSteps__c);
			Assert.areEqual(true, parseStepLog(result)[1].started, 'Expected the re-drive to record the resumed step\'s start, got ' + parseStepLog(result)[1].started);
		}
	}

	/**
	 * @description A started step that declares itself idempotent is still started again: its author said running it twice
	 * is safe. So the sweep runs it again, and the chain completes with the step run exactly once in this recovery.
	 */
	@IsTest
	private static void shouldRedriveAStartedStepThatDeclaresItselfIdempotent()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();

			AsyncChainExecution__c execution = seedDeadMidChainCandidate(buildStartedIdempotentStepLog());

			Test.startTest();
			UTIL_AsyncChain.runWatchdogSweep(SWEEP_EVERYTHING_THRESHOLD_MINUTES, WATCHDOG_BATCH_SIZE);
			Test.stopTest();

			AsyncChainExecution__c result = queryExecution(execution.Id);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_COMPLETED, result.Status__c,
					'Expected the idempotent started step to be re-driven to completion, got ' + result.Status__c + ': ' + result.ErrorMessage__c);
			Assert.areEqual(1, retriedStepRunCount, 'Expected the idempotent step to run once in the recovery, got ' + retriedStepRunCount);
			Assert.areEqual(2, result.CompletedSteps__c, 'Expected the resumed success to join the persisted one, got ' + result.CompletedSteps__c);
			Assert.areEqual(true, parseStepLog(result)[1].success, 'Expected the resumed step to record its success, got ' + parseStepLog(result)[1].success);
		}
	}

	/**
	 * @description When the Finalizer cannot enqueue the next step, that step never ran, so the stall write takes its start
	 * back. The step log shows the completed first step with its start, and the second step with neither start nor result.
	 * A later sweep then starts the chain again instead of stopping it as a started step: the row goes back to Running
	 * under a new run key, with the start recorded again.
	 */
	@IsTest
	private static void shouldTakeBackTheNextStepsStartWhenItsEnqueueFails()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();

			Test.startTest();
			String executionId = UTIL_AsyncChain.newChain(TEST_CHAIN_NAME)
					.then(new UTIL_AsyncChainRecovery_TEST.SuccessStep())
					.then(new UTIL_AsyncChainRecovery_TEST.SuccessStep())
					.withAsyncOptions(createAsyncOptions(3))
					.execute();

			UTIL_AsyncChain.simulateEnqueueFailure = true;
			Test.stopTest();
			UTIL_AsyncChain.simulateEnqueueFailure = false;

			AsyncChainExecution__c stalled = queryExecution(executionId);
			List<UTIL_AsyncChain.DTO_StepDefinition> stalledEntries = parseStepLog(stalled);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_STALLED, stalled.Status__c, 'Set-up check: expected the failed enqueue to stall the chain, got ' + stalled.Status__c);
			Assert.areEqual(true, stalledEntries[0].started, 'Expected the completed step to keep its start, got ' + stalledEntries[0].started);
			Assert.areEqual(true, stalledEntries[0].success, 'Expected the completed step to keep its success marker, got ' + stalledEntries[0].success);
			Assert.isNull(stalledEntries[1].started, 'Expected the stall write to take back the start of the step it could not enqueue, got ' + stalledEntries[1].started);
			Assert.isNull(stalledEntries[1].success, 'Expected no result on the step that never ran, got ' + stalledEntries[1].success);

			UTIL_AsyncChain.runWatchdogSweep(SWEEP_EVERYTHING_THRESHOLD_MINUTES, WATCHDOG_BATCH_SIZE);

			AsyncChainExecution__c redriven = queryExecution(executionId);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_RUNNING, redriven.Status__c,
					'Expected the sweep to re-drive the never-started step, got ' + redriven.Status__c + ': ' + redriven.ErrorMessage__c);
			Assert.areNotEqual(stalled.RunKey__c, redriven.RunKey__c, 'Expected the re-drive to set a new run key, got the same key');
			Assert.areEqual(true, parseStepLog(redriven)[1].started,
					'Expected the re-drive to record the resumed step\'s start before its enqueue, got ' + parseStepLog(redriven)[1].started);
		}
	}

	/**
	 * @description A step's first attempt ran and returned a failure that the step's own retry strategy accepts for a
	 * repeat. The retry job then cannot be queued, so the second attempt never starts. The stall save takes the step's
	 * start back, exactly as it does for a next step it could not queue. So a later sweep starts the chain again instead
	 * of stopping it as a step that may have run: the row goes back to Running under a new run key, with the start
	 * recorded again. The attempt marker of the pending retry stays through both saves.
	 */
	@IsTest
	private static void shouldTakeBackTheRetryingStepsStartWhenItsRetryEnqueueFails()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();

			Test.startTest();
			String executionId = UTIL_AsyncChain.newChain(TEST_CHAIN_NAME)
					.then(new UTIL_AsyncChainRecovery_TEST.FailingWithRetryStep())
					.withAsyncOptions(createAsyncOptions(2))
					.execute();

			UTIL_AsyncChain.simulateEnqueueFailure = true;
			Test.stopTest();
			UTIL_AsyncChain.simulateEnqueueFailure = false;

			AsyncChainExecution__c stalled = queryExecution(executionId);
			List<UTIL_AsyncChain.DTO_StepDefinition> stalledEntries = parseStepLog(stalled);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_STALLED, stalled.Status__c,
					'Set-up check: expected the failure to queue the retry to stall the chain, got ' + stalled.Status__c);
			Assert.isNull(stalledEntries[0].started, 'Expected the stall write to take back the start of the retry it could not enqueue, got ' + stalledEntries[0].started);
			Assert.areEqual(RETRY_PENDING_ATTEMPT, stalledEntries[0].attempt, 'Expected the pending retry\'s attempt marker to stay, got ' + stalledEntries[0].attempt);
			Assert.isNull(stalledEntries[0].success, 'Expected the cleared success marker to survive the stall, got ' + stalledEntries[0].success);

			UTIL_AsyncChain.runWatchdogSweep(SWEEP_EVERYTHING_THRESHOLD_MINUTES, WATCHDOG_BATCH_SIZE);

			AsyncChainExecution__c redriven = queryExecution(executionId);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_RUNNING, redriven.Status__c,
					'Expected the sweep to re-drive the never-enqueued retry, got ' + redriven.Status__c + ': ' + redriven.ErrorMessage__c);
			Assert.areNotEqual(stalled.RunKey__c, redriven.RunKey__c, 'Expected the re-drive to set a new run key, got the same key');
			List<UTIL_AsyncChain.DTO_StepDefinition> redrivenEntries = parseStepLog(redriven);
			Assert.areEqual(true, redrivenEntries[0].started, 'Expected the re-drive to record the retrying step\'s start before its enqueue, got ' + redrivenEntries[0].started);
			Assert.areEqual(RETRY_PENDING_ATTEMPT, redrivenEntries[0].attempt, 'Expected the attempt marker to survive the re-drive, got ' + redrivenEntries[0].attempt);
			Assert.isNull(redrivenEntries[0].success, 'Expected the cleared success marker to survive the re-drive, got ' + redrivenEntries[0].success);
		}
	}

	/**
	 * @description Verifies the upgrade case: a Running row saved by a package version from before
	 * retries existed is then run by the current version. Its step log carries only the pre-upgrade
	 * keys, with no attempt or retry-limit fields. It is started again on the current job and takes
	 * the path without retries, unchanged, when its step fails:
	 * exactly one attempt runs, the chain fails terminally with the StepException category, and
	 * no attempt key ever reaches the saved step log.
	 */
	@IsTest
	private static void shouldTakeNoRetryPathForPreUpgradeStepLog()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();

			AsyncApexJob deadJob = (AsyncApexJob)TST_Mock.of(AsyncApexJob.SObjectType)
					.withOverride(AsyncApexJob.Status, 'Aborted')
					.build();
			AsyncChainExecution__c execution = TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_RUNNING, TEST_CHAIN_NAME, new Map<SObjectField, Object>
			{
					AsyncChainExecution__c.TotalSteps__c => 1,
					AsyncChainExecution__c.CompletedSteps__c => 0,
					AsyncChainExecution__c.StartedAt__c => Datetime.now(),
					AsyncChainExecution__c.RunKey__c => UTIL_Random.randomUUID(),
					AsyncChainExecution__c.CurrentJobId__c => String.valueOf(deadJob.Id),
					AsyncChainExecution__c.StepLog__c => buildLegacyFailingStepLog()
			});

			Test.startTest();
			UTIL_AsyncChain.runWatchdogSweep(SWEEP_EVERYTHING_THRESHOLD_MINUTES, WATCHDOG_BATCH_SIZE);
			Test.stopTest();

			Assert.areEqual(1, failingStepRunCount, 'A step log from before the upgrade must give exactly one attempt: with null attempt and limit fields, no retry is asked');
			AsyncChainExecution__c result = queryExecution(execution.Id);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_FAILED, result.Status__c, 'The pre-upgrade chain must fail terminally on its single attempt');
			Assert.areEqual(SEL_AsyncChainExecution.FAILURE_CATEGORY_STEP_EXCEPTION, result.FailureCategory__c, 'A no-retry first-attempt failure stays categorised StepException');
			Assert.isFalse(result.StepLog__c.contains('"attempt"'), 'The no-retry path must never stamp an attempt key onto a pre-upgrade step log');
			Assert.isTrue(result.ErrorMessage__c.contains('Deliberate pre-upgrade failure'), 'The single attempt\'s failure message must land on the record');
			Assert.isNotNull(result.CompletedAt__c, 'Failed is terminal: the single-attempt failure must stamp CompletedAt');
			Assert.areEqual(0, result.CompletedSteps__c, 'The failed step may not count as completed');
		}
	}

	/**
	 * @description Verifies markAborted checks the run key like every other save. A job whose run key does not match the
	 * record (the earlier job of a chain that was started again) must not save its kill-switch abort. The record keeps
	 * its current status, and no end time appears. The kill switch for the job that holds the current key works as usual,
	 * and is covered by
	 * shouldAbortChainWhenKillSwitchActive.
	 */
	@IsTest
	private static void shouldRefuseKillSwitchAbortWhenTheRunKeyIsStale()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();

			AsyncChainExecution__c execution = persistRunningExecutionWithKey(UTIL_Random.randomUUID());
			UTIL_AsyncChain.ChainExecutor oldJob = new UTIL_AsyncChain.ChainExecutor(execution.Id, 0, 50, 32768, null, null, createAsyncOptions(2), UTIL_Random.randomUUID());
			oldJob.markAborted(queryExecution(execution.Id), 'Kill switch active');

			AsyncChainExecution__c result = queryExecution(execution.Id);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_RUNNING, result.Status__c, 'A job with an old run key must not abort the current run');
			Assert.isNull(result.CompletedAt__c, 'A blocked abort may not save an end time');
			Assert.isNull(result.ErrorMessage__c, 'A blocked abort may not save an abort reason');
		}
	}

	/**
	 * @description Verifies a recovered chain does not always overflow on its own context. A candidate's saved context
	 * is already larger than the framework's default limit (it was built with a larger limit that is not saved). The
	 * re-drive uses a limit at least as large as the context. So the resumed step completes instead of always
	 * overflowing. Here that step makes the context smaller, by replacing a large saved result of the previous step.
	 */
	@IsTest
	private static void shouldRedriveOversizedContextCandidateWithinExpandedCap()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();

			Map<String, Object> bulkyPreviousResult = new Map<String, Object>
			{
					'success' => true,
					'message' => 'm'.repeat(2000),
					'data' => null
			};
			Map<String, Object> oversizedContext = new Map<String, Object>
			{
					'pad' => 'x'.repeat(33000),
					'stepCount' => 0,
					'__previousStepResult' => bulkyPreviousResult
			};
			AsyncChainExecution__c execution = TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_STALLED, TEST_CHAIN_NAME, new Map<SObjectField, Object>
			{
					AsyncChainExecution__c.StartedAt__c => Datetime.now(),
					AsyncChainExecution__c.RunKey__c => UTIL_Random.randomUUID(),
					AsyncChainExecution__c.StepLog__c => buildStepLogJson(),
					AsyncChainExecution__c.ContextData__c => JSON.serialize(oversizedContext)
			});

			Test.startTest();
			UTIL_AsyncChain.redriveStalledChain(queryExecution(execution.Id));
			Test.stopTest();

			AsyncChainExecution__c result = queryExecution(execution.Id);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_COMPLETED, result.Status__c, 'The candidate with the oversized context must complete under the larger limit');
			Assert.areEqual(1, result.CompletedSteps__c, 'The one rebuilt step must run');
		}
	}

	/**
	 * @description Verifies that HandlerExecutor.markHandlerFailed handles DML failure gracefully.
	 */
	@IsTest
	private static void shouldHandleDmlFailureInHandlerRecovery()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();
			LOG_Builder.ignoreTestMode = true;

			AsyncChainExecution__c execution = TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_RUNNING, TEST_CHAIN_NAME);
			Id executionId = execution.Id;
			DML_Builder.newTransaction().doDelete(execution).execute();
			registerFinishedExecutionMock(executionId, null, SEL_AsyncChainExecution.STATUS_FAILED, SEL_AsyncChainExecution.FAILURE_CATEGORY_STEP_EXCEPTION);

			UTIL_AsyncChain.HandlerExecutor handlerExecutor = new UTIL_AsyncChain.HandlerExecutor
					(
							executionId, new UTIL_AsyncChain.ChainContext('test', 'test'), null, 'Failed', null, null
					);

			handlerExecutor.markHandlerFailed(executionId, 'Test handler DML failure');
			Test.getEventBus().deliver();

			List<LogEntry__c> errorLogs = new SEL_LogEntry().getAll();
			Boolean foundDmlFailureLog = false;
			for(LogEntry__c log : errorLogs)
			{
				if(log.Message__c != null && log.Message__c.contains('Handler Finalizer DML failed'))
				{
					foundDmlFailureLog = true;
				}
			}
			Assert.isTrue(foundDmlFailureLog, 'Should emit handler DML failure error log');
		}
	}

	/**
	 * @description Verifies that ChainExecutor.markChainFailedFromFinalizer handles DML failure gracefully.
	 */
	@IsTest
	private static void shouldHandleDmlFailureInFinalizerRecovery()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();
			LOG_Builder.ignoreTestMode = true;

			AsyncChainExecution__c execution = TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_RUNNING, TEST_CHAIN_NAME);
			Id executionId = execution.Id;
			DML_Builder.newTransaction().doDelete(execution).execute();
			registerAuthorizedExecutionMock(executionId, null);

			AsyncOptions options = createAsyncOptions(2);
			UTIL_AsyncChain.ChainExecutor executor = new UTIL_AsyncChain.ChainExecutor
					(
							executionId, 0, 50, 32768, null, null, options, null
					);

			executor.markChainFailedFromFinalizer(executionId, 'Test DML failure');
			Test.getEventBus().deliver();

			List<LogEntry__c> errorLogs = new SEL_LogEntry().getAll();
			Boolean foundDmlFailureLog = false;
			for(LogEntry__c log : errorLogs)
			{
				if(log.Message__c != null && log.Message__c.contains('Finalizer DML failed'))
				{
					foundDmlFailureLog = true;
				}
			}
			Assert.isTrue(foundDmlFailureLog, 'Should emit DML failure error log with original error context');
		}
	}

	/**
	 * @description Verifies that an old execution row saved without a run key (data from before the upgrade) still
	 * completes when run by a job whose run key is null. That is what happens when a job queued before the upgrade
	 * resumes a running chain after it.
	 */
	@IsTest
	private static void shouldFinaliseLegacyChainWithNullRunKey()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();

			AsyncChainExecution__c execution = TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_RUNNING, TEST_CHAIN_NAME, new Map<SObjectField, Object>
			{
					AsyncChainExecution__c.StartedAt__c => Datetime.now(),
					AsyncChainExecution__c.RunKey__c => null,
					AsyncChainExecution__c.StepLog__c => JSON.serialize(new List<UTIL_AsyncChain.DTO_StepDefinition>
					{
							buildDtoStepDefinition('UTIL_AsyncChainRecovery_TEST.SuccessStep', 'SuccessStep')
					})
			});

			AsyncOptions options = createAsyncOptions(2);

			Test.startTest();
			System.enqueueJob(new UTIL_AsyncChain.ChainExecutor(execution.Id, 0, 50, 32768, null, null, options, null), options);
			Test.stopTest();

			AsyncChainExecution__c result = queryExecution(execution.Id);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_COMPLETED, result.Status__c, 'A legacy chain with a null run key should still complete');
			Assert.isNull(result.RunKey__c, 'Running an old chain must not set a run key on its execution record');
		}
	}

	/**
	 * @description Verifies the full upgrade case (a record saved by a package version from before the
	 * upgrade, then run by the current version). A chain of several steps started before run keys existed. It is seeded
	 * as a running row with a null RunKey__c: one step already completed, its step-log entry has only the keys from
	 * before the upgrade, and the saved context holds the old log context and the previous step's result. It finishes
	 * cleanly when the current job runs the remaining steps with a null run key. Both the progress save in the middle
	 * and the final completion save must pass the run key check (null equals null). The job must never add a run key
	 * to the old row afterwards.
	 */
	@IsTest
	private static void shouldFinaliseChainStartedBeforeUpgrade()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();

			UTIL_AsyncChain.DTO_StepDefinition completedLegacyStep = buildDtoStepDefinition('UTIL_AsyncChainRecovery_TEST.SuccessStep', 'SuccessStep');
			completedLegacyStep.success = true;
			completedLegacyStep.durationMs = 5;

			AsyncChainExecution__c execution = TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_RUNNING, TEST_CHAIN_NAME, new Map<SObjectField, Object>
			{
					AsyncChainExecution__c.TotalSteps__c => 3,
					AsyncChainExecution__c.CompletedSteps__c => 1,
					AsyncChainExecution__c.StartedAt__c => Datetime.now(),
					AsyncChainExecution__c.RunKey__c => null,
					AsyncChainExecution__c.StepLog__c => JSON.serialize(new List<UTIL_AsyncChain.DTO_StepDefinition>
					{
							completedLegacyStep,
							buildDtoStepDefinition('UTIL_AsyncChainRecovery_TEST.SuccessStep', 'SuccessStep'),
							buildDtoStepDefinition('UTIL_AsyncChainRecovery_TEST.SuccessStep', 'SuccessStep')
					}, true),
					AsyncChainExecution__c.ContextData__c => JSON.serialize(new Map<String, Object>
					{
							'__logContext' => LOG_Builder.serializeContext(),
							'stepCount' => 1,
							'__previousStepResult' => new Map<String, Object>
							{
									'success' => true,
									'message' => 'Step completed',
									'data' => null
							}
					})
			});

			AsyncOptions options = createAsyncOptions(3);

			Test.startTest();
			System.enqueueJob(new UTIL_AsyncChain.ChainExecutor(execution.Id, 1, 50, 32768, null, null, options, null), options);
			Test.stopTest();

			AsyncChainExecution__c result = queryExecution(execution.Id);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_COMPLETED, result.Status__c, 'A chain started before the upgrade should finish cleanly under the current job');
			Assert.areEqual(3, result.CompletedSteps__c, 'The progress save in the middle must pass the run key check (null equals null) so the final step can run');
			Assert.isNotNull(result.CompletedAt__c, 'The final completion save must pass the run key check (null equals null)');
			Assert.isNull(result.RunKey__c, 'Finishing a chain from before the upgrade must not add a run key to its execution record afterwards');
			Assert.areEqual(3, parseContextData(result).get('stepCount'), 'Both remaining steps should have run and incremented the shared context');

			List<UTIL_AsyncChain.DTO_StepDefinition> finalSteps = (List<UTIL_AsyncChain.DTO_StepDefinition>)
					JSON.deserialize(result.StepLog__c, List<UTIL_AsyncChain.DTO_StepDefinition>.class);
			Assert.areEqual(true, finalSteps[1].success, 'The first post-upgrade step should record its success in the step log');
			Assert.areEqual(true, finalSteps[2].success, 'The final post-upgrade step should record its success in the step log');
		}
	}

	/**
	 * @description Verifies the run key check stops an old job after the run key changes in the middle of a chain. Once
	 * something else takes over the execution record by changing RunKey__c, the running job still carries the old key.
	 * So its next save is skipped, no further step is queued, and the old job never finishes the chain.
	 */
	@IsTest
	private static void shouldBlockOldJobAfterTheRunKeyChanges()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();

			Test.startTest();
			String executionId = UTIL_AsyncChain.newChain(TEST_CHAIN_NAME)
					.then(new UTIL_AsyncChainRecovery_TEST.SuccessStep())
					.then(new UTIL_AsyncChainRecovery_TEST.RotateRunKeyStep())
					.then(new UTIL_AsyncChainRecovery_TEST.SuccessStep())
					.withAsyncOptions(createAsyncOptions(4))
					.execute();
			Test.stopTest();

			AsyncChainExecution__c execution = queryExecution(executionId);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_RUNNING, execution.Status__c, 'An old run key must block the job: the old job may not finish the chain');
			Assert.areEqual(1, execution.CompletedSteps__c, 'The blocked step must not save its progress');
		}
	}

	/**
	 * @description Verifies the run key check blocks the completion save when the run key changes during the final
	 * step: the old job may not mark the chain Completed.
	 */
	@IsTest
	private static void shouldRefuseCompletionSaveAfterTheRunKeyChanges()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();

			Test.startTest();
			String executionId = UTIL_AsyncChain.newChain(TEST_CHAIN_NAME)
					.then(new UTIL_AsyncChainRecovery_TEST.RotateRunKeyStep())
					.withAsyncOptions(createAsyncOptions(2))
					.execute();
			Test.stopTest();

			AsyncChainExecution__c execution = queryExecution(executionId);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_RUNNING, execution.Status__c, 'The completion save must be blocked after the run key changed during the run');
			Assert.isNull(execution.CompletedAt__c, 'A blocked job must not set CompletedAt');
		}
	}

	/**
	 * @description Verifies the run key check blocks the step-failure save when the failing step itself changed the run
	 * key: the old job may not mark the chain Failed or record its error message.
	 */
	@IsTest
	private static void shouldRefuseStepFailureSaveAfterTheRunKeyChanges()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();

			Test.startTest();
			String executionId = UTIL_AsyncChain.newChain(TEST_CHAIN_NAME)
					.then(new UTIL_AsyncChainRecovery_TEST.RotateAndFailStep())
					.withAsyncOptions(createAsyncOptions(2))
					.execute();
			Test.stopTest();

			AsyncChainExecution__c execution = queryExecution(executionId);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_RUNNING, execution.Status__c, 'The step-failure save must be blocked after the run key changed during the run');
			Assert.isNull(execution.ErrorMessage__c, 'A blocked job must not record the failure message');
		}
	}

	/**
	 * @description Verifies the run key check blocks the context-overflow failure save when the overflowing step changed
	 * the run key: the old job may not mark the chain Failed over the run that was started again.
	 */
	@IsTest
	private static void shouldRefuseOverflowFailureSaveAfterTheRunKeyChanges()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();

			Test.startTest();
			String executionId = UTIL_AsyncChain.newChain(TEST_CHAIN_NAME)
					.withMaxContextSize(1)
					.then(new UTIL_AsyncChainRecovery_TEST.RotateRunKeyStep())
					.withAsyncOptions(createAsyncOptions(2))
					.execute();
			Test.stopTest();

			AsyncChainExecution__c execution = queryExecution(executionId);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_RUNNING, execution.Status__c, 'The overflow failure save must be blocked after the run key changed during the run');
			Assert.isNull(execution.ErrorMessage__c, 'A blocked job must not record the overflow message');
		}
	}

	/**
	 * @description Verifies an abort saved from outside while a step runs survives the end of that step. The progress
	 * save after the step writes only the progress fields. So it must not write the Running status it loaded back over
	 * the Aborted status saved from outside. The next job's check when it starts must stop the chain without running
	 * more steps.
	 */
	@IsTest
	private static void shouldPreserveExternalAbortDuringStep()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();

			Datetime launchedAt = Datetime.now();
			Test.startTest();
			String executionId = UTIL_AsyncChain.newChain(TEST_CHAIN_NAME)
					.then(new UTIL_AsyncChainRecovery_TEST.ExternalAbortStep())
					.then(new UTIL_AsyncChainRecovery_TEST.TrackingStep())
					.withAsyncOptions(createAsyncOptions(3))
					.execute();
			Test.stopTest();

			AsyncChainExecution__c execution = queryExecution(executionId);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_ABORTED, execution.Status__c, 'Expected the abort saved from outside during a step to survive the progress save');
			Assert.areEqual(1, execution.CompletedSteps__c, 'Expected the step that ran to completion to save its progress');
			assertEndTimeIsTheAbortsOwn(execution, launchedAt, 'the progress save');
			Assert.isNull(parseContextData(execution).get('trackingStepExecuted'), 'No further step may run once the external abort is on the record');
		}
	}

	/**
	 * @description An abort saved from outside during the FINAL step must survive the job's completion save. The
	 * refusal reads the row fresh, sees Aborted, and skips the save, the end-of-chain log entry, and the completion
	 * fields.
	 */
	@IsTest
	private static void shouldRefuseCompletionOverExternalAbort()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();
			LOG_Builder.ignoreTestMode = true;

			Datetime launchedAt = Datetime.now();
			Test.startTest();
			String executionId = UTIL_AsyncChain.newChain(TEST_CHAIN_NAME)
					.then(new UTIL_AsyncChainRecovery_TEST.ExternalAbortStep())
					.withAsyncOptions(createAsyncOptions(2))
					.execute();
			Test.stopTest();
			Test.getEventBus().deliver();

			AsyncChainExecution__c execution = queryExecution(executionId);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_ABORTED, execution.Status__c, 'Expected the saved abort to survive the completion save, got ' + execution.Status__c);
			assertEndTimeIsTheAbortsOwn(execution, launchedAt, 'the refused completion');
			Assert.areEqual(0, countLogsAtSite(executionId, 'handleChainCompletion'), 'Expected a refused completion to log no end-of-chain entry');
		}
	}

	/**
	 * @description An abort saved from outside before a failing step's final save must survive that save.
	 * handleStepFailure's refusal reads the row fresh and skips both the save and the log entry.
	 */
	@IsTest
	private static void shouldRefuseFailureOverExternalAbort()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();
			LOG_Builder.ignoreTestMode = true;

			Datetime launchedAt = Datetime.now();
			Test.startTest();
			String executionId = UTIL_AsyncChain.newChain(TEST_CHAIN_NAME)
					.then(new UTIL_AsyncChainRecovery_TEST.AbortThenThrowStep())
					.withAsyncOptions(createAsyncOptions(2))
					.execute();
			Test.stopTest();
			Test.getEventBus().deliver();

			AsyncChainExecution__c execution = queryExecution(executionId);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_ABORTED, execution.Status__c, 'Expected the saved abort to survive the failure save, got ' + execution.Status__c);
			assertEndTimeIsTheAbortsOwn(execution, launchedAt, 'the refused failure save');
			Assert.areEqual(0, countLogsAtSite(executionId, 'handleStepFailure'), 'Expected a refused failure save to log no end-of-chain entry');
		}
	}

	/**
	 * @description A step succeeds but its result makes the context too large. While it ran, an abort was saved from
	 * outside. The abort must survive the overflow failure save: markFailed's refusal reads the row fresh, sees Aborted,
	 * and skips both the Failed save and its log entry. The abort is saved during the step (the step passes the job's
	 * check at start as Running). So this test covers the refusal because the row is ABORTED, which is a different case
	 * from the refusal because the run key is old.
	 */
	@IsTest
	private static void shouldRefuseOverflowFailureOverExternalAbort()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();
			LOG_Builder.ignoreTestMode = true;

			Datetime launchedAt = Datetime.now();
			Test.startTest();
			String executionId = UTIL_AsyncChain.newChain(TEST_CHAIN_NAME)
					.withMaxContextSize(1)
					.then(new UTIL_AsyncChainRecovery_TEST.ExternalAbortStep())
					.withAsyncOptions(createAsyncOptions(2))
					.execute();
			Test.stopTest();
			Test.getEventBus().deliver();

			AsyncChainExecution__c execution = queryExecution(executionId);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_ABORTED, execution.Status__c, 'Expected the saved abort to survive the overflow failure save, got '
					+ execution.Status__c);
			assertEndTimeIsTheAbortsOwn(execution, launchedAt, 'the refused overflow failure');
			Assert.areEqual(0, countLogsAtSite(executionId, 'markFailed'), 'Expected a refused overflow failure to log no end-of-chain entry at markFailed');
		}
	}

	/**
	 * @description A failed chain whose context still fits the ContextData__c field must save the whole context. The
	 * save after a failure keeps the context whole or not at all, so whatever is saved on the record must parse.
	 */
	@IsTest
	private static void shouldPersistFullContextOnFailureWhenWithinFieldLimit()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();

			Test.startTest();
			String executionId = UTIL_AsyncChain.newChain(TEST_CHAIN_NAME)
					.then(new UTIL_AsyncChainRecovery_TEST.TrackingStep())
					.then(new UTIL_AsyncChainRecovery_TEST.FailingStep())
					.withAsyncOptions(createAsyncOptions(3))
					.execute();
			Test.stopTest();

			AsyncChainExecution__c failed = new SEL_AsyncChainExecution().findByIdForMonitoring(executionId);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_FAILED, failed.Status__c, 'Fixture must fail the chain');
			Object parsed = JSON.deserializeUntyped(failed.ContextData__c);
			Assert.isNotNull(parsed, 'The saved failure context must be complete JSON that parses');
			Assert.areEqual(true, ((Map<String, Object>)parsed).get('trackingStepExecuted'), 'The saved context must give back, unchanged, the step data from before the failure');
		}
	}

	/**
	 * @description When the failing chain's context no longer fits the ContextData__c field, the
	 * save after a failure must store no context at all, never a document cut short. It must show the loss by adding
	 * the context-not-kept marker to the end of ErrorMessage__c. The test also calls the helper directly: an oversized
	 * context must serialize to null for the save after a failure.
	 */
	@IsTest
	private static void shouldPersistNoContextAndMarkerWhenContextExceedsFieldOnFailure()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();

			UTIL_AsyncChain.ChainContext oversizedContext = new UTIL_AsyncChain.ChainContext('test', 'test');
			oversizedContext.put(OVERSIZED_CONTEXT_PAYLOAD_KEY, 'x'.repeat(OVERSIZED_CONTEXT_PAYLOAD_LENGTH));
			Assert.isNull(UTIL_AsyncChain.serializeContextForFailurePersist(oversizedContext), 'An oversized context must not be saved cut short');

			Test.startTest();
			String executionId = UTIL_AsyncChain.newChain(TEST_CHAIN_NAME)
					.withMaxContextSize(MAX_CONTEXT_SIZE_ABOVE_FIELD_CAPACITY)
					.then(new UTIL_AsyncChainRecovery_TEST.ContextBloatingFailingStep())
					.withAsyncOptions(createAsyncOptions(2))
					.execute();
			Test.stopTest();

			AsyncChainExecution__c failed = new SEL_AsyncChainExecution().findByIdForMonitoring(executionId);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_FAILED, failed.Status__c, 'The test step that grows the context must fail the chain');
			Assert.isNull(failed.ContextData__c, 'An oversized failure context must be dropped entirely, never truncated');
			Assert.isTrue(failed.ErrorMessage__c.contains(UTIL_AsyncChain.CONTEXT_NOT_PRESERVED_MARKER), 'The dropped context must be flagged with the marker in ErrorMessage__c');
			Assert.isTrue(failed.ErrorMessage__c.startsWith(OVERSIZED_CONTEXT_FAILURE_MESSAGE), 'The original failure message must stay first, ahead of the marker suffix');
		}
	}

	/**
	 * @description The context-not-preserved marker must survive even when the failure message
	 * already fills ErrorMessage__c to its field capacity. The save after a failure makes room by shortening the
	 * message first, so the marker can never be cut off the end.
	 */
	@IsTest
	private static void shouldKeepMarkerWhenFailureMessageAlreadyAtFieldCapacity()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();

			Test.startTest();
			String executionId = UTIL_AsyncChain.newChain(TEST_CHAIN_NAME)
					.withMaxContextSize(MAX_CONTEXT_SIZE_ABOVE_FIELD_CAPACITY)
					.then(new UTIL_AsyncChainRecovery_TEST.ContextBloatingCapacityMessageStep())
					.withAsyncOptions(createAsyncOptions(2))
					.execute();
			Test.stopTest();

			AsyncChainExecution__c failed = new SEL_AsyncChainExecution().findByIdForMonitoring(executionId);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_FAILED, failed.Status__c, 'The capacity-length-message fixture must fail the chain');
			Assert.isNull(failed.ContextData__c, 'The oversized failure context must still be dropped entirely');
			Assert.isTrue(failed.ErrorMessage__c.endsWith(UTIL_AsyncChain.CONTEXT_NOT_PRESERVED_MARKER), 'The marker must survive at the end of a capacity-length failure message');
			Assert.isTrue(failed.ErrorMessage__c.length() <= ERROR_MESSAGE_FIELD_CAPACITY, 'The marked message must still fit within the ErrorMessage__c capacity');
		}
	}

	/**
	 * @description When the failing step supplies no message at all, the context-not-preserved
	 * marker must stand alone on the record: with no base text to prefix, there is no separator to
	 * add, so ErrorMessage__c reads as exactly the marker.
	 *
	 * This test records current behaviour. It cannot catch a stray separator on its own: the save
	 * builds the message without one, and the platform also trims leading whitespace when it
	 * saves a long text area, so the saved value is identical either way (measured: a
	 * 68-character leading-space value stores as 67). What it checks is what a reader sees:
	 * the marker is the whole message, and it is first. That would break if the code
	 * ever put the marker behind the base text or the field stopped trimming.
	 */
	@IsTest
	private static void shouldRecordMarkerAloneWhenFailureMessageIsBlank()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();

			Test.startTest();
			String executionId = UTIL_AsyncChain.newChain(TEST_CHAIN_NAME)
					.withMaxContextSize(MAX_CONTEXT_SIZE_ABOVE_FIELD_CAPACITY)
					.then(new UTIL_AsyncChainRecovery_TEST.ContextBloatingBlankMessageStep())
					.withAsyncOptions(createAsyncOptions(2))
					.execute();
			Test.stopTest();

			AsyncChainExecution__c failed = new SEL_AsyncChainExecution().findByIdForMonitoring(executionId);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_FAILED, failed.Status__c, 'The blank-message fixture must fail the chain');
			Assert.isNull(failed.ContextData__c, 'The oversized failure context must still be dropped entirely');
			Assert.areEqual
					(
							UTIL_AsyncChain.CONTEXT_NOT_PRESERVED_MARKER,
							failed.ErrorMessage__c,
							'A blank failure message must leave the marker standing alone, with no leading separator'
					);
		}
	}

	/**
	 * @description Checks that countLogsAtSite really counts. A healthy one-step chain logs exactly one completion entry.
	 * The counter must find it at the completion method, and must return zero for a method that logs nothing and for an
	 * unrelated execution record, over the same log entries. Without this test, the refusal tests' checks that
	 * countLogsAtSite(...) == 0 could pass for nothing, if the counter were broken and never matched.
	 */
	@IsTest
	private static void shouldCountTerminalSignalAtEmittingSite()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();
			LOG_Builder.ignoreTestMode = true;

			AsyncChainExecution__c unrelated = persistRunningExecutionWithKey(UTIL_Random.randomUUID());

			Test.startTest();
			String executionId = UTIL_AsyncChain.newChain(TEST_CHAIN_NAME)
					.then(new UTIL_AsyncChainRecovery_TEST.SuccessStep())
					.withAsyncOptions(createAsyncOptions(2))
					.execute();
			Test.stopTest();
			Test.getEventBus().deliver();

			AsyncChainExecution__c execution = queryExecution(executionId);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_COMPLETED, execution.Status__c, 'A healthy single-step chain must complete and signal its completion');
			Assert.areEqual(1, countLogsAtSite(executionId, 'handleChainCompletion'), 'The completion method must log exactly one end-of-chain entry that the counter can see');
			Assert.areEqual(0, countLogsAtSite(executionId, 'handleStepFailure'), 'A method that logs nothing must count zero over the same log entries');
			Assert.areEqual(0, countLogsAtSite(unrelated.Id, 'handleChainCompletion'), 'An unrelated execution record has no completion entry');
		}
	}

	/**
	 * @description Verifies a healthy chain keeps the run key set when it was queued all the way to completion, and the
	 * final save still writes every completion field. The saves that write only the changed fields leave the run key
	 * out of the fields they write, but never remove it from the record.
	 */
	@IsTest
	private static void shouldPreserveRunKeyThroughHealthyCompletion()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();

			Test.startTest();
			String executionId = UTIL_AsyncChain.newChain(TEST_CHAIN_NAME)
					.then(new UTIL_AsyncChainRecovery_TEST.SuccessStep())
					.then(new UTIL_AsyncChainRecovery_TEST.SuccessStep())
					.withAsyncOptions(createAsyncOptions(3))
					.execute();
			String stampedRunKey = queryExecution(executionId).RunKey__c;
			Test.stopTest();

			AsyncChainExecution__c execution = queryExecution(executionId);
			Assert.isNotNull(stampedRunKey, 'Starting a chain must set a run key on the execution record');
			Assert.areEqual(stampedRunKey, execution.RunKey__c, 'A healthy run must finish with the run key set when it was queued');
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_COMPLETED, execution.Status__c, 'The chain should complete');
			Assert.areEqual(2, execution.CompletedSteps__c, 'Both steps should save their progress');
			Assert.isNotNull(execution.CompletedAt__c, 'The final save must set CompletedAt');
			Assert.isNotNull(execution.DurationMs__c, 'The final save must record the chain duration');
			Assert.areEqual(2, parseContextData(execution).get('stepCount'), 'The completion save must carry the final context');
		}
	}

	/**
	 * @description Verifies the progress save really writes CurrentJobId__c. On a three-step chain, the second job's
	 * progress save writes the SECOND job's id over the one saved when the chain was queued. So the completed record
	 * must carry a job id that DIFFERS from the one saved at queue time. Leaving the field out of the progress save
	 * would keep the first job id and break the inequality below. The final save then leaves that last job id in place,
	 * for the watchdog's check whether the job is alive.
	 */
	@IsTest
	private static void shouldStampCurrentJobIdAtProgressWrite()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();

			Test.startTest();
			String executionId = UTIL_AsyncChain.newChain(TEST_CHAIN_NAME)
					.then(new UTIL_AsyncChainRecovery_TEST.SuccessStep())
					.then(new UTIL_AsyncChainRecovery_TEST.SuccessStep())
					.then(new UTIL_AsyncChainRecovery_TEST.SuccessStep())
					.withAsyncOptions(createAsyncOptions(4))
					.execute();
			String enqueueTimeStamp = queryExecution(executionId).CurrentJobId__c;
			Test.stopTest();

			AsyncChainExecution__c execution = queryExecution(executionId);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_COMPLETED, execution.Status__c, 'The chain should complete');
			Assert.isNotNull(execution.CurrentJobId__c, 'The progress save must write the running job\'s id, and no final save may clear it');
			Assert.areNotEqual
					(
							enqueueTimeStamp,
							execution.CurrentJobId__c,
							'The second job\'s progress save must write a later job\'s id: an unchanged value means the progress save left out CurrentJobId__c'
					);
			Assert.areEqual
					(
							AsyncApexJob.SObjectType,
							Id.valueOf(execution.CurrentJobId__c).getSobjectType(),
							'The stamped value must be the executor AsyncApexJob id the watchdog probes for liveness'
					);
		}
	}

	/**
	 * @description Verifies the completion save does not write CurrentJobId__c. On a two-step chain, the expected final
	 * value is the FIRST job's id: the one saved at queue time, and saved again by the first job's progress save. The
	 * last job holds its own DIFFERENT job id in memory at the final save. So a completion save that wrote the field
	 * would save the last job's id and break the equality below. This proves the completion save leaves the job id out
	 * on purpose. The other final saves choose their fields the same way, through buildSparseUpdate, but are not
	 * tested here.
	 */
	@IsTest
	private static void shouldNotStampCurrentJobIdViaTerminalWrite()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();

			Test.startTest();
			String executionId = UTIL_AsyncChain.newChain(TEST_CHAIN_NAME)
					.then(new UTIL_AsyncChainRecovery_TEST.SuccessStep())
					.then(new UTIL_AsyncChainRecovery_TEST.SuccessStep())
					.withAsyncOptions(createAsyncOptions(3))
					.execute();
			String enqueueTimeStamp = queryExecution(executionId).CurrentJobId__c;
			Test.stopTest();

			AsyncChainExecution__c execution = queryExecution(executionId);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_COMPLETED, execution.Status__c, 'The chain should complete');
			Assert.areEqual(enqueueTimeStamp, execution.CurrentJobId__c,
					'The final save must leave the first job\'s id in place: a different value means the completion save wrote CurrentJobId__c');
		}
	}

	/**
	 * @description Verifies isExecutorLive answers that the job is alive for each platform job status before or during
	 * its run. TST_Mock returns the registered rows regardless of the
	 * WHERE Id, so each iteration clears the registry and registers exactly the one job whose
	 * status it asserts.
	 */
	@IsTest
	private static void shouldReportExecutorLiveForEachLiveJobStatus()
	{
		System.runAs(getTestAdmin())
		{
			for(String liveStatus : new List<String> {'Queued', 'Processing', 'Preparing', 'Holding'})
			{
				TST_Mock.clear(AsyncApexJob.SObjectType);
				AsyncApexJob liveJob = (AsyncApexJob)TST_Mock.of(AsyncApexJob.SObjectType)
						.withOverride(AsyncApexJob.Status, liveStatus)
						.build();

				Assert.isTrue(UTIL_AsyncChain.isExecutorLive(liveJob.Id), 'A job in status ' + liveStatus + ' must prove a live job');
			}
		}
	}

	/**
	 * @description Verifies a final job status does not prove the job is alive. The saved job finished or was stopped,
	 * so the watchdog may treat this job id as having no live job behind it.
	 */
	@IsTest
	private static void shouldReportExecutorNotLiveForDeadJobStatus()
	{
		System.runAs(getTestAdmin())
		{
			AsyncApexJob deadJob = (AsyncApexJob)TST_Mock.of(AsyncApexJob.SObjectType)
					.withOverride(AsyncApexJob.Status, 'Aborted')
					.build();

			Assert.isFalse(UTIL_AsyncChain.isExecutorLive(deadJob.Id), 'A job in a final status must not prove the job is alive');
		}
	}

	/**
	 * @description Verifies a missing AsyncApexJob row does not prove a job is alive: with nothing
	 * registered in the mock layer the selector's query path runs for real and finds no row for
	 * the fabricated id.
	 */
	@IsTest
	private static void shouldReportExecutorNotLiveWhenJobRowAbsent()
	{
		System.runAs(getTestAdmin())
		{
			Id absentJobId = UTIL_Random.randomId(AsyncApexJob.SObjectType);

			Assert.isFalse(UTIL_AsyncChain.isExecutorLive(absentJobId), 'An id with no matching AsyncApexJob row must not prove a job is alive');
		}
	}

	/**
	 * @description Verifies a null job id returns false at once, before any query. A chain whose record has no saved
	 * job id gives nothing to check, and with nothing to check, the job can never be proven alive.
	 */
	@IsTest
	private static void shouldReportExecutorNotLiveForNullJobId()
	{
		System.runAs(getTestAdmin())
		{
			Integer queriesBeforeProbe = UTIL_Limits.soqlQueries().used();

			Assert.isFalse(UTIL_AsyncChain.isExecutorLive(null), 'A null job id means there is nothing to check, so the job cannot be proven alive');
			Assert.areEqual(queriesBeforeProbe, UTIL_Limits.soqlQueries().used(), 'The null-id branch must return before the selector issues its query');
		}
	}

	/**
	 * @description Verifies the run key check when a job starts, made on the values in memory. A job that starts with an
	 * old run key stops before running its step, leaves the record untouched, and logs a warning.
	 */
	@IsTest
	private static void shouldStopExecutorAtStartWhenTheRunKeyIsStale()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();
			LOG_Builder.ignoreTestMode = true;

			AsyncChainExecution__c execution = persistRunningExecutionWithKey(UTIL_Random.randomUUID());
			AsyncOptions options = createAsyncOptions(2);

			Test.startTest();
			System.enqueueJob(new UTIL_AsyncChain.ChainExecutor(execution.Id, 0, 50, 32768, null, null, options, UTIL_Random.randomUUID()), options);
			Test.stopTest();
			Test.getEventBus().deliver();

			AsyncChainExecution__c result = queryExecution(execution.Id);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_RUNNING, result.Status__c, 'A job with an old run key must stop when it starts, without touching the record');
			Assert.areEqual(0, result.CompletedSteps__c, 'No step may run once the check at job start has stopped the job');

			Boolean foundFenceWarning = anyLogMessageContains('stale run key');
			Assert.isTrue(foundFenceWarning, 'The run key check at job start should log a warning');
		}
	}

	/**
	 * @description Verifies that an old run key blocks the Finalizer's failure save: the record keeps its current run
	 * untouched instead of being failed by the old job.
	 */
	@IsTest
	private static void shouldRefuseFinalizerFailureSaveWhenTheRunKeyIsStale()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();

			AsyncChainExecution__c execution = persistRunningExecutionWithKey(UTIL_Random.randomUUID());

			UTIL_AsyncChain.ChainExecutor executor = new UTIL_AsyncChain.ChainExecutor
					(
							execution.Id, 0, 50, 32768, null, null, createAsyncOptions(2), UTIL_Random.randomUUID()
					);

			executor.markChainFailedFromFinalizer(execution.Id, 'Old job failure write');

			AsyncChainExecution__c result = queryExecution(execution.Id);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_RUNNING, result.Status__c, 'An old run key must block the Finalizer\'s failure save');
			Assert.isNull(result.ErrorMessage__c, 'The blocked Finalizer save must not record an error message');
		}
	}

	/**
	 * @description Verifies that a matching real (non-null) run key still allows the Finalizer
	 * failure save: the run key check does not block normal recovery.
	 */
	@IsTest
	private static void shouldAllowFinalizerFailureWriteWithMatchingKey()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();

			String runKey = UTIL_Random.randomUUID();
			AsyncChainExecution__c execution = persistRunningExecutionWithKey(runKey);

			UTIL_AsyncChain.ChainExecutor executor = new UTIL_AsyncChain.ChainExecutor
					(
							execution.Id, 0, 50, 32768, null, null, createAsyncOptions(2), runKey
					);

			executor.markChainFailedFromFinalizer(execution.Id, 'Authorized Finalizer failure write');

			AsyncChainExecution__c result = queryExecution(execution.Id);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_FAILED, result.Status__c, 'A matching run key must allow the Finalizer\'s failure save');
			Assert.isTrue(result.ErrorMessage__c.contains('Authorized Finalizer failure write'), 'The allowed save should record the failure message');
			Assert.isNotNull(result.CompletedAt__c, 'The allowed save should set CompletedAt');
		}
	}

	/**
	 * @description Verifies that a hard-deleted execution row stops the Finalizer's failure save completely: no DML is
	 * tried, no recovery log entry is written, and nothing throws.
	 */
	@IsTest
	private static void shouldSilenceFinalizerFailureWriteWhenRecordMissing()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();
			LOG_Builder.ignoreTestMode = true;

			AsyncChainExecution__c execution = TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_RUNNING, TEST_CHAIN_NAME);
			Id executionId = execution.Id;
			DML_Builder.newTransaction().doDelete(execution).execute();

			UTIL_AsyncChain.ChainExecutor executor = new UTIL_AsyncChain.ChainExecutor
					(
							executionId, 0, 50, 32768, null, null, createAsyncOptions(2), null
					);

			executor.markChainFailedFromFinalizer(executionId, 'Old job failure write after hard delete');
			Test.getEventBus().deliver();

			Boolean foundFinalizerLog = anyLogMessageContains('Finalizer DML failed') || anyLogMessageContains('Old job failure write after hard delete');
			Assert.isFalse(foundFinalizerLog, 'A missing execution row must stop the Finalizer\'s failure save completely');
		}
	}

	/**
	 * @description Verifies that an old run key blocks the Finalizer's stall save: the record keeps
	 * its current run untouched and no onError notification fires.
	 */
	@IsTest
	private static void shouldRefuseStallSaveWhenTheRunKeyIsStale()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();

			AsyncChainExecution__c execution = persistRunningExecutionWithKey(UTIL_Random.randomUUID());
			UTIL_AsyncChain.ChainExecutor executor = buildExecutorWithStallHandler(execution.Id, UTIL_Random.randomUUID());

			Test.startTest();
			executor.markChainStalledFromFinalizer(execution.Id, 'Old job stall write', null);
			Test.stopTest();

			AsyncChainExecution__c result = queryExecution(execution.Id);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_RUNNING, result.Status__c, 'An old run key must block the Finalizer\'s stall save');
			Assert.isNull(result.ErrorMessage__c, 'The blocked stall save must not record a stall reason');
			Assert.areEqual(0, errorHandlerRunCount, 'The blocked stall must not fire the onError notification');
		}
	}

	/**
	 * @description Verifies that a hard-deleted execution row stops the Finalizer's stall save completely: no DML is
	 * tried, no stall log entry is written, no notification fires, nothing throws.
	 */
	@IsTest
	private static void shouldSilenceStallWriteWhenRecordMissing()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();
			LOG_Builder.ignoreTestMode = true;

			AsyncChainExecution__c execution = TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_RUNNING, TEST_CHAIN_NAME);
			Id executionId = execution.Id;
			DML_Builder.newTransaction().doDelete(execution).execute();

			UTIL_AsyncChain.ChainExecutor executor = buildExecutorWithStallHandler(executionId, null);

			Test.startTest();
			executor.markChainStalledFromFinalizer(executionId, 'Old job stall write after hard delete', null);
			Test.stopTest();
			Test.getEventBus().deliver();

			Boolean foundStallLog = anyLogMessageContains('Chain stalled') || anyLogMessageContains('stall DML failed');
			Assert.isFalse(foundStallLog, 'A missing execution row must stop the Finalizer\'s stall save completely');
			Assert.areEqual(0, errorHandlerRunCount, 'A missing execution row must not fire the onError notification');
		}
	}

	/**
	 * @description Verifies that ChainExecutor.markChainStalledFromFinalizer handles DML failure
	 * gracefully: the failure is logged with the original stall reason, the onError notification
	 * is skipped, and nothing throws.
	 */
	@IsTest
	private static void shouldHandleDmlFailureInStallRecovery()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();
			LOG_Builder.ignoreTestMode = true;

			AsyncChainExecution__c execution = TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_RUNNING, TEST_CHAIN_NAME);
			Id executionId = execution.Id;
			DML_Builder.newTransaction().doDelete(execution).execute();
			registerAuthorizedExecutionMock(executionId, null);

			UTIL_AsyncChain.ChainExecutor executor = buildExecutorWithStallHandler(executionId, null);

			Test.startTest();
			executor.markChainStalledFromFinalizer(executionId, 'Stall write against a deleted row', null);
			Test.stopTest();
			Test.getEventBus().deliver();

			Assert.isTrue(anyLogMessageContains('Finalizer stall DML failed'), 'A failed stall write must log the DML failure');
			Assert.areEqual(0, errorHandlerRunCount, 'A failed stall write must not fire the onError notification');
		}
	}

	/**
	 * @description An operator abort does not change the run key, so the Finalizer's run key check alone would allow it
	 * to mark the aborted row Stalled. A separate refusal, made before the code splits on the run key check, must stop
	 * it on BOTH paths, without notifying.
	 */
	@IsTest
	private static void shouldRefuseStallOverAbortOnFinalizerPath()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();

			String runKey = UTIL_Random.randomUUID();
			AsyncChainExecution__c execution = persistRunningExecutionWithKey(runKey);
			flipToAborted(execution.Id);
			UTIL_AsyncChain.ChainExecutor executor = buildExecutorWithStallHandler(execution.Id, runKey);

			Test.startTest();
			executor.markChainStalledFromFinalizer(execution.Id, 'Transient enqueue failure', null);
			Test.stopTest();

			AsyncChainExecution__c result = queryExecution(execution.Id);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_ABORTED, result.Status__c, 'An aborted row must never be marked back to Stalled by the Finalizer');
			Assert.areEqual(0, errorHandlerRunCount, 'A refused stall mark must not notify');
		}
	}

	/**
	 * @description A chain that has already ended Failed is never marked Stalled by its Finalizer: the ENQUEUE_FAILED run event
	 * is not allowed from Failed, so the row keeps its status, its end time and its message, and no onError
	 * notification fires. A Stalled row carrying a end time is one nothing would ever move again.
	 */
	@IsTest
	private static void shouldRefuseFinalizerStallOverAFailedRow()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();

			String runKey = UTIL_Random.randomUUID();
			AsyncChainExecution__c execution = persistRunningExecutionWithKey(runKey);
			flipToFailed(execution.Id);
			AsyncChainExecution__c flipped = queryExecution(execution.Id);
			UTIL_AsyncChain.ChainExecutor executor = buildExecutorWithStallHandler(execution.Id, runKey);

			Test.startTest();
			executor.markChainStalledFromFinalizer(execution.Id, 'Transient enqueue failure', null);
			Test.stopTest();

			AsyncChainExecution__c result = queryExecution(execution.Id);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_FAILED, result.Status__c, 'Expected the Finalizer stall to be refused over a Failed row, got ' + result.Status__c);
			Assert.areEqual(flipped.CompletedAt__c, result.CompletedAt__c, 'Expected the end time to stay as the final save left it');
			Assert.areEqual(flipped.ErrorMessage__c, result.ErrorMessage__c, 'Expected the message to stay as the final save left it');
			Assert.areEqual(0, errorHandlerRunCount, 'Expected no notification from a refused stall, got ' + errorHandlerRunCount + ' run(s)');
		}
	}

	/**
	 * @description Verifies the run key check when a handler job starts. A handler job that starts with an old run key
	 * stops before running the subscriber's handler work. So none of the handler's own changes are saved, and it logs a
	 * warning. The handler writes its marker through its own DML. So a missing marker proves the work never ran, apart
	 * from the framework's status save, which the check also blocks.
	 */
	@IsTest
	private static void shouldStopHandlerWorkAtStartWhenTheRunKeyIsStale()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();
			LOG_Builder.ignoreTestMode = true;

			AsyncChainExecution__c execution = persistRunningExecutionWithKey(UTIL_Random.randomUUID());

			UTIL_AsyncChain.HandlerExecutor handlerExecutor = new UTIL_AsyncChain.HandlerExecutor
					(
							execution.Id,
							new UTIL_AsyncChain.ChainContext(execution.Id, 'test'),
							buildDtoStepDefinition(HandlerSideEffectStep.class.getName(), 'HandlerSideEffect'),
							SEL_AsyncChainExecution.STATUS_COMPLETED,
							null,
							UTIL_Random.randomUUID()
					);

			Test.startTest();
			System.enqueueJob(handlerExecutor);
			Test.stopTest();
			Test.getEventBus().deliver();

			AsyncChainExecution__c result = queryExecution(execution.Id);
			Assert.isNull(result.CurrentStepName__c, 'An old run key must stop the handler at start: its work never runs, so its own marker is not saved');
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_RUNNING, result.Status__c, 'The blocked handler must leave the record untouched');

			Boolean foundFenceWarning = anyLogMessageContains('Chain handler skipped');
			Assert.isTrue(foundFenceWarning, 'The run key check at handler start should log a warning');
		}
	}

	/**
	 * @description Verifies that an old run key keeps the handler job from changing the execution record at all:
	 * neither a status save nor a context save reaches the run that was started again.
	 */
	@IsTest
	private static void shouldRefuseHandlerStatusSaveWhenTheRunKeyIsStale()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();

			AsyncChainExecution__c execution = persistRunningExecutionWithKey(UTIL_Random.randomUUID());

			UTIL_AsyncChain.HandlerExecutor handlerExecutor = new UTIL_AsyncChain.HandlerExecutor
					(
							execution.Id,
							new UTIL_AsyncChain.ChainContext('test', 'test'),
							buildDtoStepDefinition('UTIL_AsyncChainRecovery_TEST.CompletionHandlerStep', 'CompletionHandler'),
							SEL_AsyncChainExecution.STATUS_COMPLETED,
							null,
							UTIL_Random.randomUUID()
					);

			Test.startTest();
			System.enqueueJob(handlerExecutor);
			Test.stopTest();

			AsyncChainExecution__c result = queryExecution(execution.Id);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_RUNNING, result.Status__c, 'An old run key must block the handler\'s status save');
			Assert.isNull(result.ContextData__c, 'The blocked handler must not save context data');
		}
	}

	/**
	 * @description Verifies the run key check on the handler's save, apart from the check when it starts. A handler that
	 * still has the right key when it starts, but whose run key changes while its work runs, may not save a final status
	 * over the run that took over the record during that work.
	 */
	@IsTest
	private static void shouldRefuseHandlerStatusSaveWhenTheRunKeyChangesDuringWork()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();

			String runKey = UTIL_Random.randomUUID();
			AsyncChainExecution__c execution = persistRunningExecutionWithKey(runKey);

			UTIL_AsyncChain.HandlerExecutor handlerExecutor = new UTIL_AsyncChain.HandlerExecutor
					(
							execution.Id,
							new UTIL_AsyncChain.ChainContext(execution.Id, 'test'),
							buildDtoStepDefinition('UTIL_AsyncChainRecovery_TEST.RotateRunKeyStep', 'RotateRunKey'),
							SEL_AsyncChainExecution.STATUS_COMPLETED,
							null,
							runKey
					);

			Test.startTest();
			System.enqueueJob(handlerExecutor);
			Test.stopTest();

			AsyncChainExecution__c result = queryExecution(execution.Id);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_RUNNING, result.Status__c, 'The handler\'s status save must be blocked after the run key changed during its work');
			Assert.isNull(result.ContextData__c, 'The blocked handler must not save context data over the run that took over');
		}
	}

	/**
	 * @description An abort committed while a completion handler ran must survive the handler's
	 * save of its result with expectedStatus: the refusal reads the row fresh and leaves Aborted in place.
	 */
	@IsTest
	private static void shouldRefuseHandlerWriteBackOverExternalAbort()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();

			String runKey = UTIL_Random.randomUUID();
			AsyncChainExecution__c execution = persistRunningExecutionWithKey(runKey);
			flipToAborted(execution.Id);

			UTIL_AsyncChain.HandlerExecutor handlerExecutor = new UTIL_AsyncChain.HandlerExecutor
					(
							execution.Id,
							new UTIL_AsyncChain.ChainContext(execution.Id, 'test'),
							buildDtoStepDefinition(CountingErrorHandlerStep.class.getName(), 'CountingErrorHandler'),
							SEL_AsyncChainExecution.STATUS_COMPLETED,
							null,
							runKey
					);

			Test.startTest();
			System.enqueueJob(handlerExecutor);
			Test.stopTest();

			AsyncChainExecution__c result = queryExecution(execution.Id);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_ABORTED, result.Status__c, 'Saving the handler\'s result must refuse an aborted row');
		}
	}

	/**
	 * @description An abort committed before a completion handler crashes must survive the handler's
	 * own crash-recovery Finalizer save: markHandlerFailed reads the row fresh, sees Aborted, and
	 * skips both the move to Failed and its log entry. The crash goes through the real
	 * HandlerExecutor dispatch and its attached Finalizer, through the production simulateHandlerCrash
	 * test switch, rather than by calling the recovery method directly. The handler's check when it starts checks
	 * only the run key, so the aborted row still reaches the crash.
	 */
	@IsTest
	private static void shouldRefuseHandlerCrashRecoveryOverExternalAbort()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();
			LOG_Builder.ignoreTestMode = true;

			String runKey = UTIL_Random.randomUUID();
			AsyncChainExecution__c execution = persistRunningExecutionWithKey(runKey);
			flipToAborted(execution.Id);

			UTIL_AsyncChain.HandlerExecutor handlerExecutor = new UTIL_AsyncChain.HandlerExecutor
					(
							execution.Id,
							new UTIL_AsyncChain.ChainContext(execution.Id, 'test'),
							buildDtoStepDefinition(CompletionHandlerStep.class.getName(), 'CompletionHandler'),
							SEL_AsyncChainExecution.STATUS_COMPLETED,
							null,
							runKey
					);

			UTIL_AsyncChain.simulateHandlerCrash = true;
			Test.startTest();
			System.enqueueJob(handlerExecutor);
			try
			{
				Test.stopTest();
			}
			catch(Exception surfacedCrash)
			{
				Assert.isNotNull(surfacedCrash, 'The simulated handler crash should surface an exception');
			}
			UTIL_AsyncChain.simulateHandlerCrash = false;
			Test.getEventBus().deliver();

			AsyncChainExecution__c result = queryExecution(execution.Id);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_ABORTED, result.Status__c, 'The Finalizer\'s recovery save after a handler crash must refuse an aborted row');
			Assert.areEqual(0, countLogsAtSite(execution.Id, 'HandlerExecutor.Finalizer'), 'A refused recovery save after a handler crash must log no end-of-chain entry');
		}
	}

	/**
	 * @description Verifies the upgrade path through the handler's check when it starts. A handler job queued before the
	 * upgrade, with a null run key, still runs its work on an old row with no run key that the final save left Completed.
	 * It saves its result back: null equals null passes, as in the run key check of the step job.
	 */
	@IsTest
	private static void shouldRunLegacyHandlerWithNullRunKey()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();

			AsyncChainExecution__c execution = persistRunningExecutionWithKey(null);
			flipToCompleted(execution.Id);

			UTIL_AsyncChain.HandlerExecutor handlerExecutor = new UTIL_AsyncChain.HandlerExecutor
					(
							execution.Id,
							new UTIL_AsyncChain.ChainContext(execution.Id, 'test'),
							buildDtoStepDefinition('UTIL_AsyncChainRecovery_TEST.CompletionHandlerStep', 'CompletionHandler'),
							SEL_AsyncChainExecution.STATUS_COMPLETED,
							null,
							null
					);

			Test.startTest();
			System.enqueueJob(handlerExecutor);
			Test.stopTest();

			AsyncChainExecution__c result = queryExecution(execution.Id);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_COMPLETED, result.Status__c, 'A handler from before the upgrade, with a null key, must still finish an old row');
			Assert.isTrue((Boolean)parseContextData(result).get('completionHandlerExecuted'), 'The old handler\'s work should have run');
			Assert.isNull(result.RunKey__c, 'Finishing an old row must not set a run key on it');
		}
	}

	/**
	 * @description Verifies that an old run key blocks the handler's recovery save: the old job's Finalizer may not
	 * mark the chain Failed over the run that was started again.
	 */
	@IsTest
	private static void shouldRefuseHandlerRecoverySaveWhenTheRunKeyIsStale()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();

			AsyncChainExecution__c execution = persistRunningExecutionWithKey(UTIL_Random.randomUUID());

			UTIL_AsyncChain.HandlerExecutor handlerExecutor = new UTIL_AsyncChain.HandlerExecutor
					(
							execution.Id, new UTIL_AsyncChain.ChainContext('test', 'test'), null, 'Failed', null, UTIL_Random.randomUUID()
					);

			handlerExecutor.markHandlerFailed(execution.Id, 'Old job handler recovery write');

			AsyncChainExecution__c result = queryExecution(execution.Id);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_RUNNING, result.Status__c, 'An old run key must block the handler\'s recovery save');
			Assert.isNull(result.ErrorMessage__c, 'The blocked handler recovery save must not record an error message');
		}
	}

	/**
	 * @description Verifies that a matching real (non-null) run key still allows the handler
	 * recovery save: the run key check does not block normal recovery after a handler crash.
	 */
	@IsTest
	private static void shouldAllowHandlerRecoveryWriteWithMatchingKey()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();

			String runKey = UTIL_Random.randomUUID();
			AsyncChainExecution__c execution = persistRunningExecutionWithKey(runKey);
			flipToFailed(execution.Id);

			UTIL_AsyncChain.HandlerExecutor handlerExecutor = new UTIL_AsyncChain.HandlerExecutor
					(
							execution.Id, new UTIL_AsyncChain.ChainContext('test', 'test'), null, 'Failed', null, runKey
					);

			handlerExecutor.markHandlerFailed(execution.Id, 'Authorized handler recovery write');

			AsyncChainExecution__c result = queryExecution(execution.Id);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_FAILED, result.Status__c, 'A matching run key must allow the handler\'s recovery save');
			Assert.isTrue(result.ErrorMessage__c.contains('Authorized handler recovery write'), 'The allowed save should record the failure message');
		}
	}

	/**
	 * @description Verifies that a hard-deleted execution row stops the handler's recovery save completely: no DML is
	 * tried, no recovery log entry is written, and nothing throws.
	 */
	@IsTest
	private static void shouldSilenceHandlerRecoveryWriteWhenRecordMissing()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();
			LOG_Builder.ignoreTestMode = true;

			AsyncChainExecution__c execution = TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_RUNNING, TEST_CHAIN_NAME);
			Id executionId = execution.Id;
			DML_Builder.newTransaction().doDelete(execution).execute();

			UTIL_AsyncChain.HandlerExecutor handlerExecutor = new UTIL_AsyncChain.HandlerExecutor
					(
							executionId, new UTIL_AsyncChain.ChainContext('test', 'test'), null, 'Failed', null, null
					);

			handlerExecutor.markHandlerFailed(executionId, 'Old job handler recovery write after hard delete');
			Test.getEventBus().deliver();

			Boolean foundHandlerLog = anyLogMessageContains('Handler Finalizer DML failed') || anyLogMessageContains('Old job handler recovery write after hard delete');
			Assert.isFalse(foundHandlerLog, 'A missing execution row must stop the handler\'s recovery save completely');
		}
	}

	/**
	 * @description A race where the run that holds the key cannot be found. The lookup for that run keeps disagreeing
	 * with the index: the key is held, but every lookup says it is free. That is what it looks like, from inside the
	 * start, when another run releases the key and takes it again around the lookup. The start tries once more, clashes
	 * again, looks once more, and still finds nobody. The launch used a correlation the FRAMEWORK created, and a new id
	 * cannot already belong to a run. So the correlation is ruled out as the index that clashed, and the platform's own
	 * duplicate-value error reaches the caller unchanged. A launch that
	 * reused a caller-supplied correlation is the opposite case and is refused by the correlation
	 * rule instead (UTIL_AsyncChain_TEST.shouldRefuseAKeyedLaunchWhoseCorrelationIsAlreadyAttached).
	 */
	@IsTest
	private static void shouldSurfaceThePlatformErrorWhenTheWinnerLookupKeepsComingUpEmpty()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();

			String deduplicationKey = UTIL_Random.randomUUID();
			TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_RUNNING, TEST_CHAIN_NAME, new Map<SObjectField, Object>
			{
					AsyncChainExecution__c.StartedAt__c => Datetime.now(),
					AsyncChainExecution__c.ActiveDeduplicationKey__c => deduplicationKey
			});
			TST_Mock.register(AsyncChainExecution__c.SObjectType, new List<AsyncChainExecution__c>());

			try
			{
				UTIL_AsyncChain.newChain(TEST_CHAIN_NAME)
						.then(new UTIL_AsyncChainRecovery_TEST.SuccessStep())
						.withDeduplicationKey(deduplicationKey)
						.execute();
				Assert.fail('A start that collides twice on a held key should surface the platform error');
			}
			catch(Exception error)
			{
				Assert.isInstanceOfType(error, DmlException.class,
						'A minted correlation cannot collide, so the deduplication failure must reach the caller as the platform reported it: ' + error.getMessage());
				Assert.areEqual(StatusCode.DUPLICATE_VALUE, ((DmlException)error).getDmlType(0),
						'The surfaced error should be the duplicate-value collision');
			}
		}
	}

	/**
	 * @description A race where another run releases the key and takes it again, solved on the second look. The key is
	 * held, the first lookup for the holder says it is free, the retry clashes again, and the second lookup finds the
	 * holder. So the start joins that run instead of showing the platform error. The reads the test sets up: the first
	 * lookup is the
	 * one queued empty answer (the loser's view before the holder's row is visible), the second lookup reads the
	 * database. The count of DML statements tells the shapes apart: a start that joins at its first look makes
	 * one refused insert, a start that joins at its second look makes two, and each refused insert costs the
	 * same number of statements (the transaction's savepoint, the insert, the rollback and the savepoint release;
	 * the failure entry is not published under test mode, and when LOG_Builder.ignoreTestMode is on it adds one
	 * statement to every refused insert alike), so the second start's count is exactly twice the first's. That
	 * cost is measured on the first start in the same test, never assumed. If the queued empty answer were used up
	 * by some other read, the first look would find the holder, the start would join after one refused insert, and
	 * the count would fail; a query count could not tell the two apart, because a mocked lookup never reaches the
	 * database while one real lookup runs in both shapes.
	 */
	@IsTest
	private static void shouldJoinTheHolderWhenTheSecondWinnerLookupFindsIt()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();
			String unracedKey = UTIL_Random.randomUUID();
			String racedKey = UTIL_Random.randomUUID();
			AsyncChainExecution__c unracedHolder = storeRunHoldingKey(unracedKey);
			AsyncChainExecution__c racedHolder = storeRunHoldingKey(racedKey);

			Integer statementsBefore = UTIL_Limits.dmlStatements().used();
			String unracedRunId = startSameKeyChain(unracedKey);
			Integer unracedStatements = UTIL_Limits.dmlStatements().used() - statementsBefore;

			TST_Mock.registerNext(AsyncChainExecution__c.SObjectType, new List<SObject>());
			statementsBefore = UTIL_Limits.dmlStatements().used();
			String racedRunId = startSameKeyChain(racedKey);
			Integer racedStatements = UTIL_Limits.dmlStatements().used() - statementsBefore;

			Assert.areEqual(unracedHolder.Id, unracedRunId, 'A start whose first lookup finds the holder joins it: the shape the second start is measured against');
			Assert.areEqual(racedHolder.Id, racedRunId, 'A start whose second lookup finds the holder joins that run');
			Assert.areEqual(unracedStatements, racedStatements - unracedStatements,
					'The start that joins at its second look makes exactly one more refused insert than the start that joins at its first look');
			Assert.areEqual(2, new SEL_AsyncChainExecution().findByChainName(TEST_CHAIN_NAME).size(), 'No run beyond the two holders is opened');
		}
	}

	/**
	 * @description Stalled is not a final status. The stall mark, and the save of a successful onError notification's
	 * result, both leave the deduplication key in place. A start with the same key lands on the stalled run instead of
	 * opening a duplicate.
	 */
	@IsTest
	private static void shouldHoldDeduplicationKeyWhileStalled()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();

			String deduplicationKey = UTIL_Random.randomUUID();
			AsyncChainExecution__c execution = TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_RUNNING, TEST_CHAIN_NAME, new Map<SObjectField, Object>
			{
					AsyncChainExecution__c.StepLog__c => buildStepLogJsonWithErrorHandler(),
					AsyncChainExecution__c.ActiveDeduplicationKey__c => deduplicationKey
			});

			Test.startTest();
			UTIL_AsyncChain.runWatchdogSweep(SWEEP_EVERYTHING_THRESHOLD_MINUTES, WATCHDOG_BATCH_SIZE);
			Test.stopTest();

			AsyncChainExecution__c stalledRun = queryExecution(execution.Id);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_STALLED, stalledRun.Status__c, 'The sweep must mark the stale chain Stalled');
			Assert.areEqual(1, errorHandlerRunCount, 'Expected the move into Stalled to fire the onError notification whose saved result this test checks');
			Assert.areEqual(deduplicationKey, stalledRun.ActiveDeduplicationKey__c,
					'A stalled chain must hold its deduplication key through the stall mark and the notification write-back');

			String landedRunId = UTIL_AsyncChain.newChain(TEST_CHAIN_NAME)
					.then(new UTIL_AsyncChainRecovery_TEST.SuccessStep())
					.withDeduplicationKey(deduplicationKey)
					.execute();
			Assert.areEqual(execution.Id, (Id)landedRunId, 'A start with the same key must land on the stalled run: a stalled run is still active');
		}
	}

	/**
	 * @description The fallback for a re-drive that cannot recover is final: the Failed save releases the deduplication
	 * key, and a later start with the same key opens a new run.
	 */
	@IsTest
	private static void shouldReleaseDeduplicationKeyWhenRedriveFallsBack()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();

			String deduplicationKey = UTIL_Random.randomUUID();
			AsyncChainExecution__c candidate = TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_STALLED, TEST_CHAIN_NAME, new Map<SObjectField, Object>
			{
					AsyncChainExecution__c.StartedAt__c => Datetime.now(),
					AsyncChainExecution__c.RunKey__c => UTIL_Random.randomUUID(),
					AsyncChainExecution__c.StepLog__c => 'not step-log json',
					AsyncChainExecution__c.ActiveDeduplicationKey__c => deduplicationKey
			});

			UTIL_AsyncChain.redriveStalledChain(queryExecution(candidate.Id));

			AsyncChainExecution__c degradedRun = queryExecution(candidate.Id);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_FAILED, degradedRun.Status__c, 'An unrecoverable re-drive candidate must fail terminally');
			Assert.isNull(degradedRun.ActiveDeduplicationKey__c,
					'The fallback\'s final save must release the deduplication key');

			String secondRunId = UTIL_AsyncChain.newChain(TEST_CHAIN_NAME)
					.then(new UTIL_AsyncChainRecovery_TEST.SuccessStep())
					.withDeduplicationKey(deduplicationKey)
					.execute();
			Assert.areNotEqual(candidate.Id, (Id)secondRunId,
					'A run the fallback failed must free its key for a later run');
		}
	}

	/**
	 * @description The run has already ended Failed. It was started with a deduplication key and no longer holds it. The
	 * test calls markHandlerFailed directly, which is the method the Finalizer calls after a handler crash. It checks
	 * that the run stays Failed and still holds no key, and that a new chain started with the same key opens a run of its
	 * own that holds the key.
	 */
	@IsTest
	private static void shouldKeepTheDeduplicationKeyReleasedWhenTheHandlerOfAFailedRunFails()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();

			String runKey = UTIL_Random.randomUUID();
			String deduplicationKey = UTIL_Random.randomUUID();
			AsyncChainExecution__c execution = TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_FAILED, TEST_CHAIN_NAME, new Map<SObjectField, Object>
			{
					AsyncChainExecution__c.StartedAt__c => Datetime.now(),
					AsyncChainExecution__c.CompletedAt__c => Datetime.now(),
					AsyncChainExecution__c.FailureCategory__c => SEL_AsyncChainExecution.FAILURE_CATEGORY_STEP_EXCEPTION,
					AsyncChainExecution__c.DeclaredDeduplicationKey__c => deduplicationKey,
					AsyncChainExecution__c.RunKey__c => runKey
			});

			UTIL_AsyncChain.HandlerExecutor handlerExecutor = new UTIL_AsyncChain.HandlerExecutor
					(
							execution.Id, new UTIL_AsyncChain.ChainContext('test', 'test'), null, SEL_AsyncChainExecution.STATUS_FAILED, null, runKey
					);

			handlerExecutor.markHandlerFailed(execution.Id, 'Authorized handler recovery write');

			AsyncChainExecution__c failedRun = queryExecution(execution.Id);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_FAILED, failedRun.Status__c, 'Expected the handler failure save to keep the chain Failed, got ' + failedRun.Status__c);
			Assert.isNull(failedRun.ActiveDeduplicationKey__c,
					'Expected the handler failure save to leave the deduplication key released, got ' + failedRun.ActiveDeduplicationKey__c);

			String secondRunId = UTIL_AsyncChain.newChain(TEST_CHAIN_NAME)
					.then(new UTIL_AsyncChainRecovery_TEST.SuccessStep())
					.withDeduplicationKey(deduplicationKey)
					.execute();
			AsyncChainExecution__c secondRun = queryExecution(secondRunId);
			Assert.areNotEqual(execution.Id, secondRun.Id, 'Expected the start with the same key to open a run of its own');
			Assert.areEqual(deduplicationKey, secondRun.ActiveDeduplicationKey__c,
					'Expected the new run to hold the key the failed run released, got ' + secondRun.ActiveDeduplicationKey__c);
		}
	}

	/**
	 * @description Only a save that passes the run key check releases the key. A blocked old job's final save may not
	 * clear the deduplication key that the current run still holds.
	 */
	@IsTest
	private static void shouldNotClearDeduplicationKeyFromBlockedOldJob()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();

			String deduplicationKey = UTIL_Random.randomUUID();
			AsyncChainExecution__c execution = TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_RUNNING, TEST_CHAIN_NAME, new Map<SObjectField, Object>
			{
					AsyncChainExecution__c.StartedAt__c => Datetime.now(),
					AsyncChainExecution__c.RunKey__c => UTIL_Random.randomUUID(),
					AsyncChainExecution__c.ActiveDeduplicationKey__c => deduplicationKey
			});

			UTIL_AsyncChain.ChainExecutor oldJob = new UTIL_AsyncChain.ChainExecutor
					(
							execution.Id, 0, 50, 32768, null, null, createAsyncOptions(2), UTIL_Random.randomUUID()
					);

			oldJob.markChainFailedFromFinalizer(execution.Id, 'Old job failure write');

			AsyncChainExecution__c survivingRun = queryExecution(execution.Id);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_RUNNING, survivingRun.Status__c, 'The old run key must block the old job\'s final save');
			Assert.areEqual(deduplicationKey, survivingRun.ActiveDeduplicationKey__c,
					'The deduplication key must survive a blocked final save: only a save that passes the run key check releases it');
		}
	}

	/**
	 * @description A candidate that qualifies must answer Available. It has the Failed status, a context and a step log
	 * that parse, and a failed entry declared idempotent and not permanent.
	 */
	@IsTest
	private static void shouldResolveRetryAvailableForIdempotentFailedStep()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();
			AsyncChainExecution__c execution = seedFailedRetryChain(buildRetryEligibleStepLog());

			String availability = UTIL_AsyncChain.resolveRetryAvailability(new SEL_AsyncChainExecution().findByIdForMonitoring(execution.Id));

			Assert.areEqual(UTIL_AsyncChain.REDRIVE_AVAILABLE, availability, 'An idempotent failed step on a Failed chain must offer retry');
		}
	}

	/**
	 * @description Every status other than Failed must refuse retry with ChainNotRetryable. The operator retry starts
	 * again only a chain that ended Failed. Live rows and rows with another final status are never candidates, whatever
	 * their step log declares.
	 */
	@IsTest
	private static void shouldRefuseRetryForNonFailedStatus()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();
			List<String> nonFailedStatuses = new List<String>
			{
					SEL_AsyncChainExecution.STATUS_RUNNING,
					SEL_AsyncChainExecution.STATUS_STALLED,
					SEL_AsyncChainExecution.STATUS_COMPLETED,
					SEL_AsyncChainExecution.STATUS_ABORTED
			};
			for(String status : nonFailedStatuses)
			{
				AsyncChainExecution__c execution = TST_Factory.newChainExecution(
						status, RETRY_TEST_CHAIN_NAME, buildRetryEligibleStepLog(), RETRY_TOTAL_STEPS, RETRY_COMPLETED_STEPS);
				execution.ContextData__c = RETRY_CONTEXT_JSON;
				DML_Builder.newTransaction().withSystemMode().doUpdate(execution).execute();

				String availability = UTIL_AsyncChain.resolveRetryAvailability(new SEL_AsyncChainExecution().findByIdForMonitoring(execution.Id));
				UTIL_AsyncChain.OperatorActionOutcome outcome = UTIL_AsyncChain.retryChainFromFailedStep(execution.Id);

				Assert.areEqual(UTIL_AsyncChain.REDRIVE_CHAIN_NOT_RETRYABLE, availability, 'A ' + status + ' chain must refuse retry');
				Assert.areEqual(UTIL_AsyncChain.REDRIVE_CHAIN_NOT_RETRYABLE, outcome.refusalCode, 'The action must refuse what the resolver refuses for ' + status);
				Assert.areEqual(status, queryExecution(execution.Id).Status__c, 'A refused retry must not mutate the ' + status + ' row');
			}
		}
	}

	/**
	 * @description A failed entry that never declared isIdempotent must refuse retry. Running such a step again could
	 * do its work twice, so retry stays hidden until the author declares the step safe.
	 */
	@IsTest
	private static void shouldRefuseRetryWhenFailedStepNotIdempotent()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();
			AsyncChainExecution__c execution = seedFailedRetryChain(buildFailedStepLogWithoutIdempotentMarker());

			Test.startTest();
			String availability = UTIL_AsyncChain.resolveRetryAvailability(new SEL_AsyncChainExecution().findByIdForMonitoring(execution.Id));
			UTIL_AsyncChain.OperatorActionOutcome outcome = UTIL_AsyncChain.retryChainFromFailedStep(execution.Id);
			Test.stopTest();

			Assert.areEqual(UTIL_AsyncChain.REDRIVE_STEP_NOT_IDEMPOTENT, availability, 'A step that declares nothing must refuse retry');
			Assert.areEqual(UTIL_AsyncChain.REDRIVE_STEP_NOT_IDEMPOTENT, outcome.refusalCode, 'The action must refuse what the resolver refuses');
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_FAILED, queryExecution(execution.Id).Status__c, 'A refused retry must not mutate the row');
			Assert.isNull(queryExecution(execution.Id).LastManualRetryAt__c, 'A refused retry must not stamp the record');
		}
	}

	/**
	 * @description A failed entry carrying the permanent-failure marker must refuse retry, even though it also declares
	 * isIdempotent. The step itself decided that running again would not help. The operator can overrule that only with
	 * a restart from the start or a code fix, never with this button.
	 */
	@IsTest
	private static void shouldRefuseRetryWhenFailureDeclaredPermanent()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();
			AsyncChainExecution__c execution = seedFailedRetryChain(buildFailedStepLogWithPermanentFailureMarker());

			Test.startTest();
			String availability = UTIL_AsyncChain.resolveRetryAvailability(new SEL_AsyncChainExecution().findByIdForMonitoring(execution.Id));
			UTIL_AsyncChain.OperatorActionOutcome outcome = UTIL_AsyncChain.retryChainFromFailedStep(execution.Id);
			Test.stopTest();

			Assert.areEqual(UTIL_AsyncChain.REDRIVE_FAILURE_PERMANENT, availability, 'A failure declared permanent must refuse retry despite the idempotency declaration');
			Assert.areEqual(UTIL_AsyncChain.REDRIVE_FAILURE_PERMANENT, outcome.refusalCode, 'The action must refuse what the resolver refuses');
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_FAILED, queryExecution(execution.Id).Status__c, 'A refused retry must not mutate the row');
		}
	}

	/**
	 * @description A Failed row whose context was not kept must refuse retry with ContextUnavailable: there is no state
	 * to resume from. (The save after a failure keeps the context whole or not at all, and here it stored null.)
	 */
	@IsTest
	private static void shouldRefuseRetryWhenContextNotPreserved()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();
			AsyncChainExecution__c execution = TST_Factory.newChainExecution(
					SEL_AsyncChainExecution.STATUS_FAILED, RETRY_TEST_CHAIN_NAME, buildRetryEligibleStepLog(), RETRY_TOTAL_STEPS, RETRY_COMPLETED_STEPS);

			Test.startTest();
			String availability = UTIL_AsyncChain.resolveRetryAvailability(new SEL_AsyncChainExecution().findByIdForMonitoring(execution.Id));
			UTIL_AsyncChain.OperatorActionOutcome outcome = UTIL_AsyncChain.retryChainFromFailedStep(execution.Id);
			Test.stopTest();

			Assert.areEqual(UTIL_AsyncChain.REDRIVE_CONTEXT_UNAVAILABLE, availability, 'An absent context must refuse retry cleanly');
			Assert.areEqual(UTIL_AsyncChain.REDRIVE_CONTEXT_UNAVAILABLE, outcome.refusalCode, 'The action must refuse what the resolver refuses');
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_FAILED, queryExecution(execution.Id).Status__c, 'A refused retry must not mutate the row');
		}
	}

	/**
	 * @description A Failed row whose step log does not parse must refuse retry with
	 * ContextUnavailable: with no readable step markers there is no failed step to resume at.
	 */
	@IsTest
	private static void shouldRefuseRetryWhenStepLogUnparseable()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();
			AsyncChainExecution__c execution = seedFailedRetryChain(MALFORMED_STEP_LOG_JSON);

			Test.startTest();
			String availability = UTIL_AsyncChain.resolveRetryAvailability(new SEL_AsyncChainExecution().findByIdForMonitoring(execution.Id));
			UTIL_AsyncChain.OperatorActionOutcome outcome = UTIL_AsyncChain.retryChainFromFailedStep(execution.Id);
			Test.stopTest();

			Assert.areEqual(UTIL_AsyncChain.REDRIVE_CONTEXT_UNAVAILABLE, availability, 'An unparseable step log must refuse retry cleanly');
			Assert.areEqual(UTIL_AsyncChain.REDRIVE_CONTEXT_UNAVAILABLE, outcome.refusalCode, 'The action must refuse what the resolver refuses');
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_FAILED, queryExecution(execution.Id).Status__c, 'A refused retry must not mutate the row');
		}
	}

	/**
	 * @description A Failed row whose step log parses but records no failed step that stopped the chain must refuse
	 * retry with ContextUnavailable: there is no failed step to resume at. Either every entry ran and succeeded, or every
	 * failure let the chain go on.
	 */
	@IsTest
	private static void shouldRefuseRetryWhenNoTerminalFailedStepRecorded()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();
			AsyncChainExecution__c execution = seedFailedRetryChain(buildAllAttemptedStepLogWithErrorHandler());

			Test.startTest();
			String availability = UTIL_AsyncChain.resolveRetryAvailability(new SEL_AsyncChainExecution().findByIdForMonitoring(execution.Id));
			UTIL_AsyncChain.OperatorActionOutcome outcome = UTIL_AsyncChain.retryChainFromFailedStep(execution.Id);
			Test.stopTest();

			Assert.areEqual(UTIL_AsyncChain.REDRIVE_CONTEXT_UNAVAILABLE, availability, 'A step log with no failed entry that stopped the chain must refuse retry cleanly');
			Assert.areEqual(UTIL_AsyncChain.REDRIVE_CONTEXT_UNAVAILABLE, outcome.refusalCode, 'The action must refuse what the resolver refuses');
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_FAILED, queryExecution(execution.Id).Status__c, 'A refused retry must not mutate the row');
		}
	}

	/**
	 * @description A Failed row whose step log is eligible but whose saved context does not
	 * parse must refuse retry with ContextUnavailable. The check that parses the context is the only check
	 * that can catch this shape, so this test fails if that probe is removed.
	 */
	@IsTest
	private static void shouldRefuseRetryWhenContextUnparseable()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();
			AsyncChainExecution__c execution = seedFailedRetryChain(buildRetryEligibleStepLog());
			execution.ContextData__c = MALFORMED_CONTEXT_JSON;
			DML_Builder.newTransaction().withSystemMode().doUpdate(execution).execute();

			Test.startTest();
			String availability = UTIL_AsyncChain.resolveRetryAvailability(new SEL_AsyncChainExecution().findByIdForMonitoring(execution.Id));
			UTIL_AsyncChain.OperatorActionOutcome outcome = UTIL_AsyncChain.retryChainFromFailedStep(execution.Id);
			Test.stopTest();

			Assert.areEqual(UTIL_AsyncChain.REDRIVE_CONTEXT_UNAVAILABLE, availability, 'An unparseable context must refuse retry cleanly');
			Assert.areEqual(UTIL_AsyncChain.REDRIVE_CONTEXT_UNAVAILABLE, outcome.refusalCode, 'The action must refuse what the resolver refuses');
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_FAILED, queryExecution(execution.Id).Status__c, 'A refused retry must not mutate the row');
		}
	}

	/**
	 * @description A context that parses as valid JSON but is not a JSON OBJECT must refuse retry with
	 * ContextUnavailable. The job casts the context straight to an object when it loads it. The restart check already
	 * refuses a copy of the starting data that is not an object, in the same way. Without this check, a row edited by
	 * hand would pass a check that only parses, get a new run key, move to Running, and queue a job that fails as it
	 * starts. That leaves a Running row with no live job.
	 */
	@IsTest
	private static void shouldRefuseRetryWhenContextIsNotAJsonObject()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();
			AsyncChainExecution__c execution = seedFailedRetryChain(buildRetryEligibleStepLog());
			execution.ContextData__c = NON_OBJECT_CONTEXT_JSON;
			DML_Builder.newTransaction().withSystemMode().doUpdate(execution).execute();

			Test.startTest();
			String availability = UTIL_AsyncChain.resolveRetryAvailability(new SEL_AsyncChainExecution().findByIdForMonitoring(execution.Id));
			UTIL_AsyncChain.OperatorActionOutcome outcome = UTIL_AsyncChain.retryChainFromFailedStep(execution.Id);
			Test.stopTest();

			Assert.areEqual(UTIL_AsyncChain.REDRIVE_CONTEXT_UNAVAILABLE, availability, 'A context that is not an object must refuse retry: the job can only load a JSON object');
			Assert.areEqual(UTIL_AsyncChain.REDRIVE_CONTEXT_UNAVAILABLE, outcome.refusalCode, 'The action must refuse what the resolver refuses');
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_FAILED, queryExecution(execution.Id).Status__c, 'A refused retry must not mutate the row');
		}
	}

	/**
	 * @description While chain processing is suspended, an otherwise-eligible retry must refuse
	 * with ChainProcessingSuspended. Starting a chain again while the kill switch is on only makes runs that the next
	 * job aborts as soon as it starts.
	 */
	@IsTest
	private static void shouldRefuseRetryWhileChainProcessingSuspended()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();
			AsyncChainExecution__c execution = seedFailedRetryChain(buildRetryEligibleStepLog());
			SEL_FeatureFlag.activeFlags.remove(UTIL_AsyncChain.FEATURE_FLAG_NAME);

			Test.startTest();
			String availability = UTIL_AsyncChain.resolveRetryAvailability(new SEL_AsyncChainExecution().findByIdForMonitoring(execution.Id));
			UTIL_AsyncChain.OperatorActionOutcome outcome = UTIL_AsyncChain.retryChainFromFailedStep(execution.Id);
			Test.stopTest();

			Assert.areEqual(UTIL_AsyncChain.REDRIVE_PROCESSING_SUSPENDED, availability, 'A suspended org must refuse retry');
			Assert.areEqual(UTIL_AsyncChain.REDRIVE_PROCESSING_SUSPENDED, outcome.refusalCode, 'The action must refuse what the resolver refuses');
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_FAILED, queryExecution(execution.Id).Status__c, 'A refused retry must not mutate the row');
		}
	}

	/**
	 * @description The operator retry from start to end. A Failed chain that qualifies goes back to Running. The SAME
	 * update clears its end-of-run details, sets a new run key and saves the new job's id. (Clearing them in the same
	 * update keeps the purge job and the watchdog from both missing the row.) The chain then completes by running again
	 * ONLY the failed step, with the framework's default settings. The failed entry is seeded without its start marker,
	 * as in a step log written before the marker existed, so the start the last assertion reads can only come from the
	 * retry's own save before it queues the job.
	 */
	@IsTest
	private static void shouldRetryFailedChainFromFailedStepAndComplete()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();
			List<UTIL_AsyncChain.DTO_StepDefinition> seededEntries = (List<UTIL_AsyncChain.DTO_StepDefinition>)JSON.deserialize(buildRetryEligibleStepLog(),
					List<UTIL_AsyncChain.DTO_StepDefinition>.class);
			seededEntries[1].started = null;
			AsyncChainExecution__c execution = seedFailedRetryChain(JSON.serialize(seededEntries, true));
			String failedRunKey = execution.RunKey__c;

			Test.startTest();
			UTIL_AsyncChain.OperatorActionOutcome outcome = UTIL_AsyncChain.retryChainFromFailedStep(execution.Id);
			AsyncChainExecution__c interim = queryExecution(execution.Id);
			Test.stopTest();

			Assert.isNull(outcome.refusalCode, 'An eligible retry must not refuse');
			Assert.areEqual(execution.Id, outcome.resultId, 'Retry uses the same record again and returns its id');
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_RUNNING, interim.Status__c, 'Retry moves the row back to Running');
			Assert.isNull(interim.CompletedAt__c, 'CompletedAt must clear in the SAME update: a Running row with it set could be purged, and the watchdog would not see it');
			Assert.isNull(interim.DurationMs__c, 'The old duration must clear with the end-of-run details');
			Assert.isNull(interim.FailureCategory__c, 'The old failure category must clear with the end-of-run details');
			Assert.isNull(interim.ErrorMessage__c, 'The old error message must clear with the end-of-run details');
			Assert.areNotEqual(failedRunKey, interim.RunKey__c, 'Retry must set a new run key so any old job stays blocked');
			Assert.isNotNull(interim.CurrentJobId__c, 'Retry must save the new job\'s id when it queues the job');

			AsyncChainExecution__c result = queryExecution(execution.Id);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_COMPLETED, result.Status__c, 'The job started again must complete the chain');
			Assert.areEqual(RETRY_TOTAL_STEPS, result.CompletedSteps__c, 'Both steps count completed after running again');
			Assert.areEqual(1, retriedStepRunCount, 'Exactly the failed step runs again');
			Assert.isNull(parseContextData(result).get('trackingStepExecuted'), 'The completed earlier step must not run again');
			Assert.areEqual(0, errorHandlerRunCount, 'The rebuilt error handler must not fire on a successful run');
			Assert.areEqual(true, parseStepLog(interim)[1].started,
					'Expected the retry to record the retried step\'s start before its enqueue, got ' + parseStepLog(interim)[1].started);
		}
	}

	/**
	 * @description A retried step that now launches a different chain from the one it launched before is refused,
	 * naming the child it launched before when the operator can see it: a retry runs in a transaction of its own, so
	 * the remembered child is the only record of the first launch, and answering the launch with a run of another
	 * chain would hide the change.
	 */
	@IsTest
	private static void shouldRefuseADifferentChainOnARetriedStep()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();
			UTIL_AsyncChain.DTO_StepDefinition completedStep = buildDtoStepDefinition('UTIL_AsyncChainRecovery_TEST.TrackingStep', 'TrackingStep');
			completedStep.success = true;
			UTIL_AsyncChain.DTO_StepDefinition launchingStep = buildDtoStepDefinition(LAUNCHING_STEP_CLASS_NAME, 'LaunchingStep');
			launchingStep.isIdempotent = true;
			launchingStep.success = false;
			launchingStep.message = RETRY_FAILURE_MESSAGE;
			AsyncChainExecution__c execution = seedFailedRetryChain(JSON.serialize(new List<UTIL_AsyncChain.DTO_StepDefinition> {completedStep, launchingStep}, true));
			AsyncChainExecution__c earlierChild = TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_COMPLETED, EARLIER_CHILD_CHAIN_NAME,
					new Map<SObjectField, Object> {AsyncChainExecution__c.DeclaredDeduplicationKey__c => execution.Id + RETRIED_STEP_LAUNCH_KEY_SUFFIX});

			Test.startTest();
			UTIL_AsyncChain.OperatorActionOutcome outcome = UTIL_AsyncChain.retryChainFromFailedStep(execution.Id);
			Test.stopTest();

			Assert.isNull(outcome.refusalCode, 'An eligible retry must not refuse');
			AsyncChainExecution__c result = queryExecution(execution.Id);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_FAILED, result.Status__c, 'The refused launch fails the retried step: ' + result.ErrorMessage__c);
			Assert.isTrue(result.ErrorMessage__c.contains(EARLIER_CHILD_CHAIN_NAME), 'The refusal names the chain the step launched before: ' + result.ErrorMessage__c);
			Assert.isTrue(result.ErrorMessage__c.contains(earlierChild.Id), 'The refusal names the run the operator can see: ' + result.ErrorMessage__c);
			Assert.isTrue(new SEL_AsyncChainExecution().findByChainName(LAUNCHING_STEP_CHILD_CHAIN_NAME).isEmpty(), 'The different chain was never written');
		}
	}

	/**
	 * @description The operator retry gives the failed entry its attempts back. All four run-time markers reset in the
	 * rewritten step log, while the completed earlier entry keeps its markers. The test runs outside startTest, so the
	 * queued job never runs. The parsed document is therefore the retry's own save.
	 */
	@IsTest
	private static void shouldGiveRetriedStepFreshAttemptBudget()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();
			AsyncChainExecution__c execution = seedFailedRetryChain(buildRetryEligibleStepLog());

			UTIL_AsyncChain.OperatorActionOutcome outcome = UTIL_AsyncChain.retryChainFromFailedStep(execution.Id);

			Assert.isNull(outcome.refusalCode, 'An eligible retry must not refuse');
			List<UTIL_AsyncChain.DTO_StepDefinition> entries = (List<UTIL_AsyncChain.DTO_StepDefinition>)
					JSON.deserialize(queryExecution(execution.Id).StepLog__c, List<UTIL_AsyncChain.DTO_StepDefinition>.class);
			Assert.isNull(entries[1].attempt, 'The retried step must start with its attempts back');
			Assert.isNull(entries[1].success, 'The old failure marker must reset, so the entry reads as not tried yet');
			Assert.isNull(entries[1].message, 'The old failure message must reset with the marker');
			Assert.isNull(entries[1].durationMs, 'The old duration must reset with the marker');
			Assert.areEqual(true, entries[0].success, 'The completed earlier entry keeps its markers: only the failed entry resets');
			Assert.areEqual(true, entries[1].isIdempotent, 'The declaration markers stay after the run-time markers reset');
			Assert.areEqual(true, entries[2].isErrorHandler, 'The trailing handler entry must survive the failed-entry reset untouched');
		}
	}

	/**
	 * @description The operator's retry sets the date on the record and marks the retried step with the wait since the
	 * failure. The marker stays when the recovered run rewrites the step log, because the job changes only the members it
	 * adds while it runs. Between the retry and the recovered run, the test moves the date earlier. A saved DateTime keeps
	 * whole seconds, and the two saves happen in the same second. Without moving it, a job that set the date again would
	 * still compare equal.
	 */
	@IsTest
	private static void shouldStampTheManualRetryAndKeepItsMarkerThroughTheRecoveredRun()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();
			AsyncChainExecution__c execution = seedFailedRetryChain(buildRetryEligibleStepLog(), Datetime.now().addMinutes(-MANUAL_RETRY_SEEDED_WAIT_MINUTES));
			Datetime beforeRetry = Datetime.now();

			Test.startTest();
			UTIL_AsyncChain.OperatorActionOutcome outcome = UTIL_AsyncChain.retryChainFromFailedStep(execution.Id);
			AsyncChainExecution__c interim = queryExecution(execution.Id);
			Datetime stampedByRetry = interim.LastManualRetryAt__c;
			interim.LastManualRetryAt__c = Datetime.now().addMinutes(-MANUAL_RETRY_SEEDED_WAIT_MINUTES);
			DML_Builder.newTransaction().withSystemMode().doUpdate(interim).execute();
			AsyncChainExecution__c afterBackDating = queryExecution(execution.Id);
			Test.stopTest();

			List<UTIL_AsyncChain.DTO_StepDefinition> interimEntries = (List<UTIL_AsyncChain.DTO_StepDefinition>)
					JSON.deserialize(interim.StepLog__c, List<UTIL_AsyncChain.DTO_StepDefinition>.class);
			AsyncChainExecution__c result = queryExecution(execution.Id);
			List<UTIL_AsyncChain.DTO_StepDefinition> entries = (List<UTIL_AsyncChain.DTO_StepDefinition>)
					JSON.deserialize(result.StepLog__c, List<UTIL_AsyncChain.DTO_StepDefinition>.class);
			Assert.isNull(outcome.refusalCode, 'An eligible retry must not refuse');
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_COMPLETED, result.Status__c, 'The recovered run must complete');
			Assert.isTrue(stampedByRetry >= beforeRetry.addSeconds(-PERSISTED_DATETIME_TOLERANCE_SECONDS),
					'The record must say when Retry was used: ' + stampedByRetry);
			Assert.areEqual(afterBackDating.LastManualRetryAt__c, result.LastManualRetryAt__c,
					'The recovered run must leave the retry date exactly as it found it: only a manual retry ever stamps it');
			Assert.areEqual(true, entries[1].success, 'The recovered run rewrote the retried entry with its own result');
			Assert.isTrue(interimEntries[1].manualRetryAfterMs >= MANUAL_RETRY_SEEDED_WAIT_MINUTES * MILLISECONDS_PER_MINUTE,
					'The retry must write the wait since the failure: ' + interimEntries[1].manualRetryAfterMs);
			Assert.isTrue(interimEntries[1].manualRetryAfterMs < (MANUAL_RETRY_SEEDED_WAIT_MINUTES + 1) * MILLISECONDS_PER_MINUTE,
					'The wait is measured from the instant the run failed, never from an earlier one: ' + interimEntries[1].manualRetryAfterMs);
			Assert.areEqual(interimEntries[1].manualRetryAfterMs, entries[1].manualRetryAfterMs,
					'The recovered run rewrites the entry and keeps the marker exactly as the retry wrote it');
			Assert.isNull(entries[0].manualRetryAfterMs, 'Only the retried step carries the marker');
		}
	}

	/**
	 * @description A failed run that recorded no end still sets the date on the record, and the marker says the wait is unknown rather
	 * than guessing one. The package does not let anyone save a Failed record without an end time. Older orgs still have
	 * such records. So the saved record is a normal failed run with an end time. The first time the retry reads it, the
	 * test hands back a copy without the end time.
	 */
	@IsTest
	private static void shouldLeaveTheWaitUnknownWhenTheFailedRunRecordedNoEnd()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();
			AsyncChainExecution__c execution = seedFailedRetryChain(buildRetryEligibleStepLog());
			AsyncChainExecution__c withoutEnd = execution.clone(true, true, true, true);
			withoutEnd.CompletedAt__c = null;
			TST_Mock.registerNext(AsyncChainExecution__c.SObjectType, withoutEnd);

			UTIL_AsyncChain.OperatorActionOutcome outcome = UTIL_AsyncChain.retryChainFromFailedStep(execution.Id);

			AsyncChainExecution__c result = queryExecution(execution.Id);
			List<UTIL_AsyncChain.DTO_StepDefinition> entries = (List<UTIL_AsyncChain.DTO_StepDefinition>)
					JSON.deserialize(result.StepLog__c, List<UTIL_AsyncChain.DTO_StepDefinition>.class);
			Assert.isNull(outcome.refusalCode, 'An eligible retry must not refuse');
			Assert.isNotNull(result.LastManualRetryAt__c, 'The date is set on the record whether or not the wait is known');
			Assert.areEqual(EXPECTED_MANUAL_RETRY_WAIT_UNKNOWN, entries[1].manualRetryAfterMs, 'No wait is recorded unless both instants were real');
		}
	}

	/**
	 * @description A failed run whose recorded end is later than the retry has no honest wait either: the marker says unknown,
	 * never a negative number.
	 */
	@IsTest
	private static void shouldLeaveTheWaitUnknownWhenTheRecordedEndIsLaterThanTheRetry()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();
			AsyncChainExecution__c execution = seedFailedRetryChain(buildRetryEligibleStepLog(), Datetime.now().addMinutes(MANUAL_RETRY_SEEDED_WAIT_MINUTES));

			UTIL_AsyncChain.OperatorActionOutcome outcome = UTIL_AsyncChain.retryChainFromFailedStep(execution.Id);

			List<UTIL_AsyncChain.DTO_StepDefinition> entries = (List<UTIL_AsyncChain.DTO_StepDefinition>)
					JSON.deserialize(queryExecution(execution.Id).StepLog__c, List<UTIL_AsyncChain.DTO_StepDefinition>.class);
			Assert.isNull(outcome.refusalCode, 'An eligible retry must not refuse');
			Assert.areEqual(EXPECTED_MANUAL_RETRY_WAIT_UNKNOWN, entries[1].manualRetryAfterMs, 'A wait is never negative: an end later than the retry reads as unknown');
		}
	}

	/**
	 * @description A second manual retry of the same step overwrites the first marker and the first date: "Last" means
	 * last. Both retries run outside startTest, so no job runs, and each parsed document is the retry's own save.
	 */
	@IsTest
	private static void shouldOverwriteTheMarkerAndTheStampOnASecondManualRetry()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();
			AsyncChainExecution__c execution = seedFailedRetryChain(buildRetryEligibleStepLog(), Datetime.now().addMinutes(-MANUAL_RETRY_SEEDED_WAIT_MINUTES));
			UTIL_AsyncChain.retryChainFromFailedStep(execution.Id);

			AsyncChainExecution__c afterFirst = queryExecution(execution.Id);
			List<UTIL_AsyncChain.DTO_StepDefinition> firstEntries = (List<UTIL_AsyncChain.DTO_StepDefinition>)
					JSON.deserialize(afterFirst.StepLog__c, List<UTIL_AsyncChain.DTO_StepDefinition>.class);
			Long firstWait = firstEntries[1].manualRetryAfterMs;
			firstEntries[1].success = false;
			afterFirst.StepLog__c = JSON.serialize(firstEntries, true);
			afterFirst.Status__c = SEL_AsyncChainExecution.STATUS_FAILED;
			afterFirst.CompletedAt__c = Datetime.now().addMinutes(-MANUAL_RETRY_SECOND_WAIT_MINUTES);
			afterFirst.FailureCategory__c = SEL_AsyncChainExecution.FAILURE_CATEGORY_STEP_EXCEPTION;
			afterFirst.LastManualRetryAt__c = Datetime.now().addMinutes(-MANUAL_RETRY_SEEDED_WAIT_MINUTES);
			DML_Builder.newTransaction().withSystemMode().doUpdate(afterFirst).execute();

			UTIL_AsyncChain.OperatorActionOutcome secondOutcome = UTIL_AsyncChain.retryChainFromFailedStep(execution.Id);

			AsyncChainExecution__c afterSecond = queryExecution(execution.Id);
			List<UTIL_AsyncChain.DTO_StepDefinition> secondEntries = (List<UTIL_AsyncChain.DTO_StepDefinition>)
					JSON.deserialize(afterSecond.StepLog__c, List<UTIL_AsyncChain.DTO_StepDefinition>.class);
			Assert.isNull(secondOutcome.refusalCode, 'The second retry is as eligible as the first');
			Assert.isTrue(firstWait >= MANUAL_RETRY_SEEDED_WAIT_MINUTES * MILLISECONDS_PER_MINUTE, 'The first marker carried the first wait: ' + firstWait);
			Assert.isTrue(secondEntries[1].manualRetryAfterMs < firstWait, 'The second retry must overwrite the marker with its own, shorter wait');
			Assert.isTrue(afterSecond.LastManualRetryAt__c > afterFirst.LastManualRetryAt__c, 'The second retry must move the date: "Last" means last');
		}
	}

	/**
	 * @description A step log with no room for the marker plus the room kept free while steps run is retried without the
	 * marker: the date is set on the record,
	 * the run recovers, and the marker is simply absent. A retry never fails because of the marker.
	 */
	@IsTest
	private static void shouldLeaveTheMarkerOffWhenTheStepLogHasNoRoomAndStillRetry()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();
			AsyncChainExecution__c execution = seedFailedRetryChain(buildNearCapacityRetryEligibleStepLog());

			Test.startTest();
			UTIL_AsyncChain.OperatorActionOutcome outcome = UTIL_AsyncChain.retryChainFromFailedStep(execution.Id);
			AsyncChainExecution__c interim = queryExecution(execution.Id);
			Test.stopTest();

			List<UTIL_AsyncChain.DTO_StepDefinition> interimEntries = (List<UTIL_AsyncChain.DTO_StepDefinition>)
					JSON.deserialize(interim.StepLog__c, List<UTIL_AsyncChain.DTO_StepDefinition>.class);
			Assert.isNull(outcome.refusalCode, 'A full step log must not refuse the retry');
			Assert.isNotNull(interim.LastManualRetryAt__c, 'The date is set on the record even when the marker has no room');
			Assert.isNull(interimEntries[1].manualRetryAfterMs, 'The marker is left off when the log cannot keep the reserve free');
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_COMPLETED, queryExecution(execution.Id).Status__c, 'The recovered run must still complete');
		}
	}

	/**
	 * @description A step log with no room for the marker keeps every other step's message: the marker is the first thing given
	 * up, and it never makes the safety valve (which drops step messages) act on a log that fits without it. The test runs
	 * outside startTest, so the parsed document is the retry's own save.
	 */
	@IsTest
	private static void shouldKeepOtherStepsMessagesWhenTheMarkerHasNoRoom()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();
			AsyncChainExecution__c execution = seedFailedRetryChain(buildBarelyFittingStepLogWithAContinuedFailure());

			UTIL_AsyncChain.OperatorActionOutcome outcome = UTIL_AsyncChain.retryChainFromFailedStep(execution.Id);

			List<UTIL_AsyncChain.DTO_StepDefinition> entries = (List<UTIL_AsyncChain.DTO_StepDefinition>)
					JSON.deserialize(queryExecution(execution.Id).StepLog__c, List<UTIL_AsyncChain.DTO_StepDefinition>.class);
			Assert.isNull(outcome.refusalCode, 'A full step log must not refuse the retry');
			Assert.isNull(entries[1].manualRetryAfterMs, 'The marker is left off when the log has no room for it');
			Assert.areEqual(RETRY_FAILURE_MESSAGE, entries[0].message, 'The marker must never cost another step its message');
		}
	}

	/**
	 * @description The room rule keeps room free for EVERY step that has yet to record a result, not just the retried one.
	 * With a second step still to run, a log that has room for one step's share and the marker, but not for two shares, is
	 * retried without the marker. The test runs outside startTest, so the parsed document is the retry's own save.
	 */
	@IsTest
	private static void shouldReserveRoomForEveryStepYetToRecordBeforeKeepingTheMarker()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();
			AsyncChainExecution__c execution = seedFailedRetryChain(buildNearCapacityStepLogWithAStepStillToRun());

			UTIL_AsyncChain.OperatorActionOutcome outcome = UTIL_AsyncChain.retryChainFromFailedStep(execution.Id);

			List<UTIL_AsyncChain.DTO_StepDefinition> entries = (List<UTIL_AsyncChain.DTO_StepDefinition>)
					JSON.deserialize(queryExecution(execution.Id).StepLog__c, List<UTIL_AsyncChain.DTO_StepDefinition>.class);
			Assert.isNull(outcome.refusalCode, 'A full step log must not refuse the retry');
			Assert.isNull(entries[1].manualRetryAfterMs, 'Two steps have yet to record, so the log needs room for two before it can keep the marker');
		}
	}

	/**
	 * @description A restart makes a new run that nobody has retried: it carries neither the date nor any marker, and the
	 * source run keeps both.
	 */
	@IsTest
	private static void shouldCarryNoManualRetryOntoARestartedRun()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();
			AsyncChainExecution__c source = seedRestartDeclaredChain(SEL_AsyncChainExecution.STATUS_FAILED);
			List<UTIL_AsyncChain.DTO_StepDefinition> sourceEntries = (List<UTIL_AsyncChain.DTO_StepDefinition>)
					JSON.deserialize(queryExecution(source.Id).StepLog__c, List<UTIL_AsyncChain.DTO_StepDefinition>.class);
			sourceEntries[0].manualRetryAfterMs = MANUAL_RETRY_SEEDED_WAIT_MINUTES * MILLISECONDS_PER_MINUTE;
			source.StepLog__c = JSON.serialize(sourceEntries, true);
			source.LastManualRetryAt__c = Datetime.now();
			DML_Builder.newTransaction().withSystemMode().doUpdate(source).execute();

			UTIL_AsyncChain.OperatorActionOutcome outcome = UTIL_AsyncChain.restartChainFromStart(source.Id);

			Assert.isNull(outcome.refusalCode, 'A declared restart must not refuse');
			AsyncChainExecution__c clone = queryExecution(outcome.resultId);
			Assert.isNull(clone.LastManualRetryAt__c, 'Nobody has retried the new run');
			List<UTIL_AsyncChain.DTO_StepDefinition> cloneEntries = (List<UTIL_AsyncChain.DTO_StepDefinition>)
					JSON.deserialize(clone.StepLog__c, List<UTIL_AsyncChain.DTO_StepDefinition>.class);
			Assert.areEqual(sourceEntries.size(), cloneEntries.size(), 'The clone keeps every step definition');
			for(UTIL_AsyncChain.DTO_StepDefinition cloneEntry : cloneEntries)
			{
				Assert.isNull(cloneEntry.manualRetryAfterMs, 'The new run starts without markers');
			}
			AsyncChainExecution__c keptSource = queryExecution(source.Id);
			List<UTIL_AsyncChain.DTO_StepDefinition> keptEntries = (List<UTIL_AsyncChain.DTO_StepDefinition>)
					JSON.deserialize(keptSource.StepLog__c, List<UTIL_AsyncChain.DTO_StepDefinition>.class);
			Assert.isNotNull(keptSource.LastManualRetryAt__c, 'The source run keeps its own date');
			Assert.areEqual(MANUAL_RETRY_SEEDED_WAIT_MINUTES * MILLISECONDS_PER_MINUTE, keptEntries[0].manualRetryAfterMs,
					'The source run keeps its own marker, so the clone loop is comparing against a marker that really persisted');
		}
	}

	/**
	 * @description A retry of a chain built with a deduplication key takes the declared key back into
	 * ActiveDeduplicationKey__c, in the same update. That brings back the lock against a second copy running at once,
	 * which the end of the run had released.
	 */
	@IsTest
	private static void shouldReclaimDeclaredDeduplicationKeyOnRetry()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();
			AsyncChainExecution__c execution = seedFailedRetryChain(buildRetryEligibleStepLog());
			execution.DeclaredDeduplicationKey__c = RETRY_DECLARED_DEDUPLICATION_KEY;
			DML_Builder.newTransaction().withSystemMode().doUpdate(execution).execute();

			UTIL_AsyncChain.OperatorActionOutcome outcome = UTIL_AsyncChain.retryChainFromFailedStep(execution.Id);

			AsyncChainExecution__c reclaimed = queryExecution(execution.Id);
			Assert.isNull(outcome.refusalCode, 'An eligible keyed retry must not refuse');
			Assert.areEqual(RETRY_DECLARED_DEDUPLICATION_KEY, reclaimed.ActiveDeduplicationKey__c, 'Retry must take the declared key back in its one update');
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_RUNNING, reclaimed.Status__c, 'The run that took its key back is live again');
		}
	}

	/**
	 * @description When another live run already holds the declared deduplication key, the retry
	 * must refuse with DuplicateRun and leave the row exactly as it was. The clash on the unique index rolls the whole
	 * update back, and the package's own check for that clash names the cause.
	 */
	@IsTest
	private static void shouldRefuseRetryWhenDeduplicationKeyHeldByLiveRun()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();
			AsyncChainExecution__c execution = seedFailedRetryChain(buildRetryEligibleStepLog());
			execution.DeclaredDeduplicationKey__c = RETRY_DECLARED_DEDUPLICATION_KEY;
			DML_Builder.newTransaction().withSystemMode().doUpdate(execution).execute();
			String failedRunKey = execution.RunKey__c;
			TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_RUNNING, RETRY_TEST_CHAIN_NAME, new Map<SObjectField, Object>
			{
					AsyncChainExecution__c.ActiveDeduplicationKey__c => RETRY_DECLARED_DEDUPLICATION_KEY
			});

			Test.startTest();
			UTIL_AsyncChain.OperatorActionOutcome outcome = UTIL_AsyncChain.retryChainFromFailedStep(execution.Id);
			Test.stopTest();

			AsyncChainExecution__c untouched = queryExecution(execution.Id);
			Assert.areEqual(UTIL_AsyncChain.REDRIVE_DUPLICATE_RUN, outcome.refusalCode, 'A live run holding the key must refuse the retry with DuplicateRun');
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_FAILED, untouched.Status__c, 'A refusal for a key clash must roll the whole update back');
			Assert.areEqual(failedRunKey, untouched.RunKey__c, 'No new run key may stay after a refusal for a key clash');
			Assert.isNotNull(untouched.CompletedAt__c, 'The end-of-run fields stay after a refused retry');
			Assert.isNull(untouched.LastManualRetryAt__c, 'A retry that clashed must not set the date on the record');
			Assert.areEqual(execution.StepLog__c, untouched.StepLog__c, 'A retry that clashed must leave the step log as it was');
		}
	}

	/**
	 * @description A Failed chain that declared allowRestart at build time must resolve Available
	 * for the restart action.
	 */
	@IsTest
	private static void shouldResolveRestartAvailableForDeclaredFailedChain()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();
			AsyncChainExecution__c execution = seedRestartDeclaredChain(SEL_AsyncChainExecution.STATUS_FAILED);

			String availability = UTIL_AsyncChain.resolveRestartAvailability(new SEL_AsyncChainExecution().findByIdForMonitoring(execution.Id));

			Assert.areEqual(UTIL_AsyncChain.RESTART_AVAILABLE, availability, 'A declared Failed chain must offer restart');
		}
	}

	/**
	 * @description An Aborted chain that declared allowRestart qualifies too. Restart is the one recovery an aborted run
	 * allows, because it can never be resumed.
	 */
	@IsTest
	private static void shouldResolveRestartAvailableForDeclaredAbortedChain()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();
			AsyncChainExecution__c execution = seedRestartDeclaredChain(SEL_AsyncChainExecution.STATUS_ABORTED);

			String availability = UTIL_AsyncChain.resolveRestartAvailability(new SEL_AsyncChainExecution().findByIdForMonitoring(execution.Id));

			Assert.areEqual(UTIL_AsyncChain.RESTART_AVAILABLE, availability, 'A declared Aborted chain must offer restart');
		}
	}

	/**
	 * @description Live and Completed chains must refuse restart with ChainNotRestartable. Only a run that ended badly,
	 * Failed or Aborted, may run again from the start.
	 */
	@IsTest
	private static void shouldRefuseRestartForNonTerminalOrCompletedStatus()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();
			List<String> ineligibleStatuses = new List<String>
			{
					SEL_AsyncChainExecution.STATUS_RUNNING,
					SEL_AsyncChainExecution.STATUS_STALLED,
					SEL_AsyncChainExecution.STATUS_COMPLETED
			};
			for(String status : ineligibleStatuses)
			{
				AsyncChainExecution__c execution = seedRestartDeclaredChain(status);

				String availability = UTIL_AsyncChain.resolveRestartAvailability(new SEL_AsyncChainExecution().findByIdForMonitoring(execution.Id));
				UTIL_AsyncChain.OperatorActionOutcome outcome = UTIL_AsyncChain.restartChainFromStart(execution.Id);

				Assert.areEqual(UTIL_AsyncChain.RESTART_CHAIN_NOT_RESTARTABLE, availability, 'A ' + status + ' chain must refuse restart');
				Assert.areEqual(UTIL_AsyncChain.RESTART_CHAIN_NOT_RESTARTABLE, outcome.refusalCode, 'The action must refuse what the resolver refuses for ' + status);
				Assert.areEqual(status, queryExecution(execution.Id).Status__c, 'A refused restart must not mutate the ' + status + ' row');
				Assert.isTrue(queryRestartClones(execution.Id).isEmpty(), 'A refused restart must insert no clone for ' + status);
			}
		}
	}

	/**
	 * @description A chain built without allowRestart() must refuse with RestartNotDeclared. Rows from before the
	 * upgrade and chains that declare nothing end here; a null value never counts as allowed.
	 */
	@IsTest
	private static void shouldRefuseRestartWithoutDeclaration()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();
			AsyncChainExecution__c execution = seedFailedRetryChain(buildRetryEligibleStepLog());

			Test.startTest();
			String availability = UTIL_AsyncChain.resolveRestartAvailability(new SEL_AsyncChainExecution().findByIdForMonitoring(execution.Id));
			UTIL_AsyncChain.OperatorActionOutcome outcome = UTIL_AsyncChain.restartChainFromStart(execution.Id);
			Test.stopTest();

			Assert.areEqual(UTIL_AsyncChain.RESTART_NOT_DECLARED, availability, 'An undeclared chain must refuse restart');
			Assert.areEqual(UTIL_AsyncChain.RESTART_NOT_DECLARED, outcome.refusalCode, 'The action must refuse what the resolver refuses');
			Assert.isTrue(queryRestartClones(execution.Id).isEmpty(), 'A refused restart must insert no clone');
		}
	}

	/**
	 * @description A chain that allows a restart, but whose copy of the starting data was never saved, is refused by the
	 * ACTION with ContextUnavailable, while the availability check still says Available. The check reads the monitoring
	 * field list, which leaves out the 131KB copy on purpose. The availability code is only a hint for the screen. The
	 * action's own restart read, which does include the copy, is where the rule is applied.
	 */
	@IsTest
	private static void shouldRefuseRestartWithoutInitialContextSnapshot()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();
			AsyncChainExecution__c execution = seedFailedRetryChain(buildRetryEligibleStepLog());
			execution.AllowRestart__c = true;
			DML_Builder.newTransaction().withSystemMode().doUpdate(execution).execute();

			Test.startTest();
			String availability = UTIL_AsyncChain.resolveRestartAvailability(new SEL_AsyncChainExecution().findByIdForMonitoring(execution.Id));
			UTIL_AsyncChain.OperatorActionOutcome outcome = UTIL_AsyncChain.restartChainFromStart(execution.Id);
			Test.stopTest();

			Assert.areEqual(UTIL_AsyncChain.RESTART_AVAILABLE, availability, 'The hint from the monitoring row cannot see the copy, and says Available on purpose');
			Assert.areEqual(UTIL_AsyncChain.RESTART_CONTEXT_UNAVAILABLE, outcome.refusalCode, 'The action must refuse when the copy of the starting data is missing');
			Assert.isTrue(queryRestartClones(execution.Id).isEmpty(), 'A refused restart must insert no clone');
		}
	}

	/**
	 * @description A chain that allows a restart, but whose copy of the starting data does not parse, must be refused by
	 * the action with ContextUnavailable. A new run cannot be built from a broken copy of the starting data.
	 */
	@IsTest
	private static void shouldRefuseRestartWhenSnapshotUnparseable()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();
			AsyncChainExecution__c execution = seedRestartDeclaredChain(SEL_AsyncChainExecution.STATUS_FAILED);
			execution.InitialContextData__c = MALFORMED_CONTEXT_JSON;
			DML_Builder.newTransaction().withSystemMode().doUpdate(execution).execute();

			Test.startTest();
			UTIL_AsyncChain.OperatorActionOutcome outcome = UTIL_AsyncChain.restartChainFromStart(execution.Id);
			Test.stopTest();

			Assert.areEqual(UTIL_AsyncChain.RESTART_CONTEXT_UNAVAILABLE, outcome.refusalCode, 'A copy of the starting data that does not parse must refuse restart cleanly');
			Assert.isTrue(queryRestartClones(execution.Id).isEmpty(), 'A refused restart must insert no clone');
		}
	}

	/**
	 * @description A chain that allows a restart, but whose step log does not parse or has no step entries, must be
	 * refused by the action with ContextUnavailable. A new run needs a list of step definitions to run.
	 */
	@IsTest
	private static void shouldRefuseRestartWhenStepLogUnparseableOrEmpty()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();
			AsyncChainExecution__c malformed = seedRestartDeclaredChain(SEL_AsyncChainExecution.STATUS_FAILED);
			malformed.StepLog__c = MALFORMED_STEP_LOG_JSON;
			DML_Builder.newTransaction().withSystemMode().doUpdate(malformed).execute();

			AsyncChainExecution__c entryless = seedRestartDeclaredChain(SEL_AsyncChainExecution.STATUS_FAILED);
			UTIL_AsyncChain.DTO_StepDefinition handlerOnly = buildDtoStepDefinition(CountingErrorHandlerStep.class.getName(), 'CountingErrorHandler');
			handlerOnly.isErrorHandler = true;
			entryless.StepLog__c = JSON.serialize(new List<UTIL_AsyncChain.DTO_StepDefinition> {handlerOnly}, true);
			DML_Builder.newTransaction().withSystemMode().doUpdate(entryless).execute();

			Test.startTest();
			UTIL_AsyncChain.OperatorActionOutcome malformedOutcome = UTIL_AsyncChain.restartChainFromStart(malformed.Id);
			UTIL_AsyncChain.OperatorActionOutcome entrylessOutcome = UTIL_AsyncChain.restartChainFromStart(entryless.Id);
			Test.stopTest();

			Assert.areEqual(UTIL_AsyncChain.RESTART_CONTEXT_UNAVAILABLE, malformedOutcome.refusalCode, 'An unparseable step log must refuse restart cleanly');
			Assert.areEqual(UTIL_AsyncChain.RESTART_CONTEXT_UNAVAILABLE, entrylessOutcome.refusalCode, 'A step log with no step entries must refuse restart cleanly');
			Assert.isTrue(queryRestartClones(malformed.Id).isEmpty(), 'A refused restart must insert no clone');
			Assert.isTrue(queryRestartClones(entryless.Id).isEmpty(), 'A refused restart must insert no clone');
		}
	}

	/**
	 * @description While chain processing is suspended, an otherwise-eligible restart must refuse
	 * with ChainProcessingSuspended. Restarting while the kill switch is on only makes a new run that the next job
	 * aborts as soon as it starts.
	 */
	@IsTest
	private static void shouldRefuseRestartWhileChainProcessingSuspended()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();
			AsyncChainExecution__c execution = seedRestartDeclaredChain(SEL_AsyncChainExecution.STATUS_FAILED);
			SEL_FeatureFlag.activeFlags.remove(UTIL_AsyncChain.FEATURE_FLAG_NAME);

			Test.startTest();
			String availability = UTIL_AsyncChain.resolveRestartAvailability(new SEL_AsyncChainExecution().findByIdForMonitoring(execution.Id));
			UTIL_AsyncChain.OperatorActionOutcome outcome = UTIL_AsyncChain.restartChainFromStart(execution.Id);
			Test.stopTest();

			Assert.areEqual(UTIL_AsyncChain.REDRIVE_PROCESSING_SUSPENDED, availability, 'A suspended org must refuse restart');
			Assert.areEqual(UTIL_AsyncChain.REDRIVE_PROCESSING_SUSPENDED, outcome.refusalCode, 'The action must refuse what the resolver refuses');
			Assert.isTrue(queryRestartClones(execution.Id).isEmpty(), 'A refused restart must insert no clone');
		}
	}

	/**
	 * @description The operator restart from start to end. A Failed chain that allows a restart is copied to a NEW record.
	 * The new record gets a new correlation id and run key, a step log with the definitions only, counters at zero, the
	 * copy of the starting data and AllowRestart__c, the SourceExecution__c lookup to the old run, and the new job's id.
	 * The new run then completes by running every step from the start, from the copy of the starting data.
	 */
	@IsTest
	private static void shouldRestartChainAsFreshCloneAndComplete()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();
			AsyncChainExecution__c source = seedRestartDeclaredChain(SEL_AsyncChainExecution.STATUS_FAILED);

			Test.startTest();
			UTIL_AsyncChain.OperatorActionOutcome outcome = UTIL_AsyncChain.restartChainFromStart(source.Id);
			AsyncChainExecution__c interimClone = new SEL_AsyncChainExecution().findByIdForRestart(outcome.resultId);
			Test.stopTest();

			Assert.isNull(outcome.refusalCode, 'An eligible restart must not refuse');
			Assert.isNotNull(outcome.resultId, 'Restart must return the clone id');
			Assert.areNotEqual(source.Id, outcome.resultId, 'Restart must clone to a NEW record, never mutate the source');

			Assert.areEqual(SEL_AsyncChainExecution.STATUS_RUNNING, interimClone.Status__c, 'The clone starts Running');
			Assert.areEqual(0, interimClone.CompletedSteps__c, 'The clone starts at step zero');
			Assert.areEqual(source.TotalSteps__c, interimClone.TotalSteps__c, 'The clone keeps the definition step total');
			Assert.areNotEqual(source.CorrelationId__c, interimClone.CorrelationId__c, 'The clone mints a fresh correlation id');
			Assert.areNotEqual(source.RunKey__c, interimClone.RunKey__c, 'The clone mints a fresh run key');
			Assert.areEqual(true, interimClone.AllowRestart__c, 'The clone is itself restartable');
			Assert.isTrue(String.isNotBlank(interimClone.InitialContextData__c), 'The new run keeps the copy of the starting data');
			Assert.areEqual(source.Id, interimClone.SourceExecution__c, 'The new run records the run it was restarted from');
			Assert.isNotNull(interimClone.CurrentJobId__c, 'Restart must save the new job\'s id when it queues the job');
			List<UTIL_AsyncChain.DTO_StepDefinition> cloneEntries = (List<UTIL_AsyncChain.DTO_StepDefinition>)
					JSON.deserialize(interimClone.StepLog__c, List<UTIL_AsyncChain.DTO_StepDefinition>.class);
			Assert.isNull(cloneEntries[0].success, 'The new run\'s step log has the definitions only: no run-time markers are copied');
			Assert.areEqual(true, cloneEntries[0].started, 'Expected the restart to record the first step\'s start before its enqueue, got ' + cloneEntries[0].started);
			Assert.isNull(cloneEntries[1].started, 'Expected the source\'s started marker not to be copied into the new run\'s second step, got ' + cloneEntries[1].started);
			Assert.isNull(cloneEntries[1].success, 'The failed marker must not be copied into the new run');
			Assert.isNull(cloneEntries[1].attempt, 'The used-up attempt count must not be copied into the new run');
			Assert.isNull(cloneEntries[1].message, 'The old failure message must not be copied into the new run');
			Assert.isNull(cloneEntries[1].durationMs, 'The old duration must not be copied into the new run');
			Assert.areEqual(true, cloneEntries[1].isIdempotent, 'The declaration markers stay in the copy of the definitions');
			Assert.areEqual(true, cloneEntries[2].isErrorHandler, 'The handler entries stay in the copy of the definitions');

			AsyncChainExecution__c completedClone = queryExecution(outcome.resultId);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_COMPLETED, completedClone.Status__c, 'The clone must complete from the start');
			Assert.areEqual(RETRY_TOTAL_STEPS, completedClone.CompletedSteps__c, 'Every step runs on the clone');
			Assert.areEqual(RESTART_SNAPSHOT_VALUE, parseContextData(completedClone).get(RESTART_SNAPSHOT_KEY), 'The new run starts again from the values as the chain was built');
			Assert.areEqual(true, parseContextData(completedClone).get('trackingStepExecuted'), 'The first step runs again on the new run');
			Assert.areEqual(1, retriedStepRunCount, 'The second step runs exactly once on the clone');
			Assert.areEqual(0, errorHandlerRunCount, 'The rebuilt error handler must not fire when the new run succeeds');
		}
	}

	/**
	 * @description A restart never changes the source row. Its final status, its error details and its ids stay exactly
	 * the same, while the new run runs beside it.
	 */
	@IsTest
	private static void shouldLeaveSourceRecordUntouchedByRestart()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();
			AsyncChainExecution__c source = seedRestartDeclaredChain(SEL_AsyncChainExecution.STATUS_FAILED);

			UTIL_AsyncChain.OperatorActionOutcome outcome = UTIL_AsyncChain.restartChainFromStart(source.Id);

			AsyncChainExecution__c untouched = queryExecution(source.Id);
			Assert.isNull(outcome.refusalCode, 'An eligible restart must not refuse');
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_FAILED, untouched.Status__c, 'The source keeps its final status');
			Assert.areEqual(SEL_AsyncChainExecution.FAILURE_CATEGORY_STEP_EXCEPTION, untouched.FailureCategory__c, 'The source keeps its failure category');
			Assert.areEqual(RETRY_FAILURE_MESSAGE, untouched.ErrorMessage__c, 'The source keeps its error message');
			Assert.isNotNull(untouched.CompletedAt__c, 'The source keeps its completion timestamp');
			Assert.areEqual(source.RunKey__c, untouched.RunKey__c, 'The source keeps its run key: a restart changes nothing on it');
		}
	}

	/**
	 * @description The new run's context loads the NEW run's correlation id, never the source's. The restart replaces
	 * the logging entry in the copy of the starting data, so the new run's steps log under the new run's ids. Every
	 * other value in the copy stays untouched. The test runs outside startTest, so the parsed document is the one built
	 * at insert, not a later save by a job.
	 */
	@IsTest
	private static void shouldLoadNewRunCorrelationIdIntoCloneContext()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();
			AsyncChainExecution__c source = seedRestartDeclaredChain(SEL_AsyncChainExecution.STATUS_FAILED);

			UTIL_AsyncChain.OperatorActionOutcome outcome = UTIL_AsyncChain.restartChainFromStart(source.Id);

			AsyncChainExecution__c clone = queryExecution(outcome.resultId);
			Map<String, Object> cloneContext = parseContextData(clone);
			Map<String, Object> logContext = (Map<String, Object>)JSON.deserializeUntyped((String)cloneContext.get(CONTEXT_LOG_KEY));
			Assert.areEqual(clone.CorrelationId__c, logContext.get(LOG_CONTEXT_CORRELATION_FIELD), 'The new run\'s context must load the NEW run\'s correlation id');
			Assert.areNotEqual(SOURCE_LOG_CORRELATION_ID, logContext.get(LOG_CONTEXT_CORRELATION_FIELD), 'The source correlation must never be copied into the new run');
			Assert.areEqual(RESTART_SNAPSHOT_VALUE, cloneContext.get(RESTART_SNAPSHOT_KEY), 'The rebuild replaces only the logging-context entry');
			Assert.areEqual(SOURCE_LOG_CORRELATION_ID, logContext.get(LOG_CONTEXT_ROOT_FIELD),
					'A source document without a root names its old correlation as the root, and the clone keeps it');
			Assert.areEqual(source.CorrelationId__c, clone.RootCorrelationId__c, 'A source from before root ids existed passes its own id to the new run as the root');
			Assert.isNull(clone.LaunchCorrelationId__c, 'A restart is launched by a click, under no active correlation');
		}
	}

	/**
	 * @description A restart of a run launched inside a traced action keeps the action's root and the launch's context
	 * values in the new run's document, while carrying the new run's own correlation.
	 */
	@IsTest
	private static void shouldKeepTheSourcesRootAndContextValuesOnRestart()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();
			AsyncChainExecution__c source = seedRestartDeclaredChainWithRootedContext(SEL_AsyncChainExecution.STATUS_FAILED);

			UTIL_AsyncChain.OperatorActionOutcome outcome = UTIL_AsyncChain.restartChainFromStart(source.Id);

			AsyncChainExecution__c clone = queryExecution(outcome.resultId);
			Map<String, Object> cloneContext = parseContextData(clone);
			Map<String, Object> logContext = (Map<String, Object>)JSON.deserializeUntyped((String)cloneContext.get(CONTEXT_LOG_KEY));
			Assert.areEqual(clone.CorrelationId__c, logContext.get(LOG_CONTEXT_CORRELATION_FIELD), 'The clone document carries the clone correlation');
			Assert.areEqual(SOURCE_ROOT_CORRELATION_ID, logContext.get(LOG_CONTEXT_ROOT_FIELD), 'The clone document keeps the action as the root');
			Map<String, Object> cloneContextValues = (Map<String, Object>)logContext.get(LOG_CONTEXT_DATA_FIELD);
			Assert.areEqual(SOURCE_CONTEXT_VALUE, cloneContextValues.get(SOURCE_CONTEXT_KEY), 'The clone document keeps the launch\'s context values');
			Assert.areEqual(SOURCE_ROOT_CORRELATION_ID, clone.RootCorrelationId__c, 'The clone record carries the source\'s root');
			Assert.isNull(clone.LaunchCorrelationId__c, 'A restart is launched under no active correlation');
		}
	}

	/**
	 * @description A run started again uses the framework's default stack depth, including the levels kept for nested
	 * chains: a restarted
	 * chain whose step launches a child whose own step launches a grandchild completes all three levels.
	 */
	@IsTest
	private static void shouldLaunchNestedChainsFromARestartedRun()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();
			AsyncChainExecution__c source = seedRestartDeclaredNestedLaunchChain();

			Test.startTest();
			UTIL_AsyncChain.OperatorActionOutcome outcome = UTIL_AsyncChain.restartChainFromStart(source.Id);
			Test.stopTest();

			Assert.isNull(outcome.refusalCode, 'An eligible restart must not refuse');
			AsyncChainExecution__c clone = queryExecution(outcome.resultId);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_COMPLETED, clone.Status__c, 'The restarted run completes: ' + clone.ErrorMessage__c);
			AsyncChainExecution__c child = queryExecution((String)parseContextData(clone).get(CHILD_EXECUTION_KEY));
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_COMPLETED, child.Status__c, 'The child the restarted run launched completes: ' + child.ErrorMessage__c);
			AsyncChainExecution__c grandchild = queryExecution((String)parseContextData(child).get(CHILD_EXECUTION_KEY));
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_COMPLETED, grandchild.Status__c, 'The grandchild completes under the recovery settings: ' + grandchild.ErrorMessage__c);
			Assert.areEqual(clone.CorrelationId__c, child.LaunchCorrelationId__c, 'The child was launched under the restarted run');
		}
	}

	/**
	 * @description A restart of a chain built with a deduplication key takes the declared key again on the new run at
	 * insert: both the declared and the active key fields carry it. The source's active key, already released, stays
	 * released.
	 */
	@IsTest
	private static void shouldReclaimDeclaredDeduplicationKeyOnRestartClone()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();
			AsyncChainExecution__c source = seedRestartDeclaredChain(SEL_AsyncChainExecution.STATUS_FAILED);
			source.DeclaredDeduplicationKey__c = RETRY_DECLARED_DEDUPLICATION_KEY;
			DML_Builder.newTransaction().withSystemMode().doUpdate(source).execute();

			UTIL_AsyncChain.OperatorActionOutcome outcome = UTIL_AsyncChain.restartChainFromStart(source.Id);

			AsyncChainExecution__c clone = queryExecution(outcome.resultId);
			Assert.areEqual(RETRY_DECLARED_DEDUPLICATION_KEY, clone.DeclaredDeduplicationKey__c, 'The new run keeps the declared key');
			Assert.areEqual(RETRY_DECLARED_DEDUPLICATION_KEY, clone.ActiveDeduplicationKey__c, 'The new run takes the key at insert');
			Assert.isNull(queryExecution(source.Id).ActiveDeduplicationKey__c, 'The source active key stays released');
		}
	}

	/**
	 * @description When another live run already holds the declared deduplication key, the restart
	 * must refuse with DuplicateRun and insert no new run. The clash on the unique index rolls the insert back, and the
	 * package's own check for that clash names the cause.
	 */
	@IsTest
	private static void shouldRefuseRestartWhenDeduplicationKeyHeldByLiveRun()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();
			AsyncChainExecution__c source = seedRestartDeclaredChain(SEL_AsyncChainExecution.STATUS_FAILED);
			source.DeclaredDeduplicationKey__c = RETRY_DECLARED_DEDUPLICATION_KEY;
			DML_Builder.newTransaction().withSystemMode().doUpdate(source).execute();
			TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_RUNNING, RESTART_TEST_CHAIN_NAME, new Map<SObjectField, Object>
			{
					AsyncChainExecution__c.ActiveDeduplicationKey__c => RETRY_DECLARED_DEDUPLICATION_KEY
			});

			Test.startTest();
			UTIL_AsyncChain.OperatorActionOutcome outcome = UTIL_AsyncChain.restartChainFromStart(source.Id);
			Test.stopTest();

			Assert.areEqual(UTIL_AsyncChain.REDRIVE_DUPLICATE_RUN, outcome.refusalCode, 'A live run holding the key must refuse the restart with DuplicateRun');
			Assert.isTrue(queryRestartClones(source.Id).isEmpty(), 'A refusal for a key clash must insert no new run');
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_FAILED, queryExecution(source.Id).Status__c, 'The source survives a refused restart untouched');
		}
	}

	/**
	 * @description A restart whose insert of the new run fails for any reason OTHER than the deduplication index must
	 * show that failure, not hide it as a refusal code. Only a clash on the key has a useful message for the operator.
	 * The test causes it with a copy of the starting data that fills the context field exactly. The restart's larger
	 * logging entry pushes the new run's context past the field, so the insert fails on length.
	 */
	@IsTest
	private static void shouldRethrowNonDuplicateFailureFromRestartInsert()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();
			AsyncChainExecution__c source = seedRestartDeclaredChain(SEL_AsyncChainExecution.STATUS_FAILED);
			source.InitialContextData__c = buildCapacityFillingSnapshotJson();
			DML_Builder.newTransaction().withSystemMode().doUpdate(source).execute();

			Test.startTest();
			try
			{
				UTIL_AsyncChain.restartChainFromStart(source.Id);
				Assert.fail('Should throw DmlException');
			}
			catch(Exception error)
			{
				Assert.isInstanceOfType(error, DmlException.class, 'Incorrect Exception Type');
			}
			Test.stopTest();

			Assert.isTrue(queryRestartClones(source.Id).isEmpty(), 'A failed insert of the new run must leave no new run behind');
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_FAILED, queryExecution(source.Id).Status__c, 'The source survives a failed restart untouched');
		}
	}

	/**
	 * @description A retry whose update fails for any reason OTHER than the deduplication index must show that failure
	 * instead of reporting a refusal. The test causes it with a registered mock: the availability check and the action
	 * both read a row whose real record has been deleted, so the update cannot be saved.
	 */
	@IsTest
	private static void shouldRethrowNonDuplicateFailureFromRetryUpdate()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();
			AsyncChainExecution__c execution = seedFailedRetryChain(buildRetryEligibleStepLog());
			Id executionId = execution.Id;
			DML_Builder.newTransaction().doDelete(execution).execute();
			TST_Mock.register(AsyncChainExecution__c.SObjectType, TST_Builder.of(AsyncChainExecution__c.SObjectType)
					.withOverride(AsyncChainExecution__c.Id, executionId)
					.withOverride(AsyncChainExecution__c.Status__c, SEL_AsyncChainExecution.STATUS_FAILED)
					.withOverride(AsyncChainExecution__c.ContextData__c, RETRY_CONTEXT_JSON)
					.withOverride(AsyncChainExecution__c.StepLog__c, buildRetryEligibleStepLog())
					.withoutInsertion()
					.build());

			Test.startTest();
			try
			{
				UTIL_AsyncChain.retryChainFromFailedStep(executionId);
				Assert.fail('Should throw DmlException');
			}
			catch(Exception error)
			{
				Assert.isInstanceOfType(error, DmlException.class, 'Incorrect Exception Type');
			}
			Test.stopTest();
		}
	}

	/**
	 * @description A restart against a row that no longer exists must refuse cleanly rather than
	 * dereferencing a null read.
	 */
	@IsTest
	private static void shouldRefuseRestartForMissingRow()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();

			Test.startTest();
			UTIL_AsyncChain.OperatorActionOutcome outcome = UTIL_AsyncChain.restartChainFromStart(UTIL_Random.randomId(AsyncChainExecution__c.SObjectType));
			Test.stopTest();

			Assert.areEqual(UTIL_AsyncChain.RESTART_CHAIN_NOT_RESTARTABLE, outcome.refusalCode, 'A missing row must refuse restart without dereferencing it');
		}
	}

	/**
	 * @description A snapshot that parses as JSON but is a LIST rather than an object must refuse
	 * restart with ContextUnavailable. With this shape, reading the copy throws when it is cast to an object, not when
	 * it is parsed.
	 */
	@IsTest
	private static void shouldRefuseRestartWhenSnapshotIsNotAnObject()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();
			AsyncChainExecution__c source = seedRestartDeclaredChain(SEL_AsyncChainExecution.STATUS_FAILED);
			source.InitialContextData__c = JSON.serialize(new List<String> {RESTART_SNAPSHOT_VALUE});
			DML_Builder.newTransaction().withSystemMode().doUpdate(source).execute();

			Test.startTest();
			UTIL_AsyncChain.OperatorActionOutcome outcome = UTIL_AsyncChain.restartChainFromStart(source.Id);
			Test.stopTest();

			Assert.areEqual(UTIL_AsyncChain.RESTART_CONTEXT_UNAVAILABLE, outcome.refusalCode, 'A copy of the starting data that is not an object must refuse restart cleanly');
			Assert.isTrue(queryRestartClones(source.Id).isEmpty(), 'A refused restart must insert no clone');
		}
	}

	/**
	 * @description Verifies the operator's Clear Stalled sweep starts again a stalled chain whose job is proven dead,
	 * through the watchdog's own decision path: a new run key, a newly queued job, and its saved job id. It counts the
	 * chain as started again. The read that counts the results sees the candidate Running before the transaction's
	 * Queueable jobs run, and the new job then completes the chain.
	 */
	@IsTest
	private static void shouldRedriveProvablyDeadStalledChainOnClearStalled()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();

			AsyncApexJob deadJob = (AsyncApexJob)TST_Mock.of(AsyncApexJob.SObjectType)
					.withOverride(AsyncApexJob.Status, 'Aborted')
					.build();
			AsyncChainExecution__c execution = TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_STALLED, TEST_CHAIN_NAME, new Map<SObjectField, Object>
			{
					AsyncChainExecution__c.StartedAt__c => Datetime.now(),
					AsyncChainExecution__c.RunKey__c => UTIL_Random.randomUUID(),
					AsyncChainExecution__c.CurrentJobId__c => String.valueOf(deadJob.Id),
					AsyncChainExecution__c.StepLog__c => buildStepLogJson()
			});

			Test.startTest();
			UTIL_AsyncChain.ClearStalledResult counts = UTIL_AsyncChain.clearStalledChains();
			Test.stopTest();

			Assert.areEqual(1, counts.candidates, 'The stalled chain must be inspected as a candidate');
			Assert.areEqual(1, counts.redriven, 'A candidate proven dead must count as started again');
			Assert.areEqual(0, counts.markedFailed, 'A clean re-drive must mark nothing Failed');
			Assert.areEqual(0, counts.remainingStalled, 'A candidate started again must not count as remaining');
			Assert.areEqual
					(
							SEL_AsyncChainExecution.STATUS_COMPLETED,
							queryExecution(execution.Id).Status__c,
							'The re-driven executor must complete the chain when the queueables drain'
					);
		}
	}

	/**
	 * @description Verifies the operator sweep cannot prove dead a candidate with no saved job id, because there is no
	 * job to check. So it marks the row through the watchdog's path for chains it cannot check, and counts it as
	 * remaining: still Stalled, its reason replaced by the sweep's stall reason, never started again.
	 */
	@IsTest
	private static void shouldCountStalledChainAsRemainingWhenLivenessCannotBeProven()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();

			AsyncChainExecution__c execution = TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_STALLED, TEST_CHAIN_NAME, new Map<SObjectField, Object>
			{
					AsyncChainExecution__c.ErrorMessage__c => PRE_SWEEP_SEEDED_REASON,
					AsyncChainExecution__c.StepLog__c => buildStepLogJson()
			});

			Test.startTest();
			UTIL_AsyncChain.ClearStalledResult counts = UTIL_AsyncChain.clearStalledChains();
			Test.stopTest();

			Assert.areEqual(1, counts.candidates, 'The stalled chain must be inspected as a candidate');
			Assert.areEqual(0, counts.redriven, 'A candidate that cannot be proven dead must never be started again');
			Assert.areEqual(0, counts.markedFailed, 'The path for chains the sweep cannot check marks Stalled, never Failed');
			Assert.areEqual(1, counts.remainingStalled, 'A candidate that was only marked must count as remaining');
			AsyncChainExecution__c result = queryExecution(execution.Id);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_STALLED, result.Status__c, 'A candidate that cannot be proven dead must stay Stalled');
			Assert.areEqual('No live executor detected by watchdog sweep', result.ErrorMessage__c,
					'The detect-mark leg must record the sweep stall reason, proving the candidate was processed rather than skipped');
		}
	}

	/**
	 * @description Verifies the operator sweep sends a candidate that cannot be recovered (its job is proven dead, but
	 * its saved step log cannot be read) through the watchdog's fallback that fails it for good. It counts the
	 * candidate as marked Failed, with the reason that says what to do and the Stalled failure category.
	 */
	@IsTest
	private static void shouldCountUnrecoverableCandidateAsMarkedFailedOnClearStalled()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();

			AsyncApexJob deadJob = (AsyncApexJob)TST_Mock.of(AsyncApexJob.SObjectType)
					.withOverride(AsyncApexJob.Status, 'Aborted')
					.build();
			AsyncChainExecution__c execution = TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_STALLED, TEST_CHAIN_NAME, new Map<SObjectField, Object>
			{
					AsyncChainExecution__c.StartedAt__c => Datetime.now(),
					AsyncChainExecution__c.RunKey__c => UTIL_Random.randomUUID(),
					AsyncChainExecution__c.CurrentJobId__c => String.valueOf(deadJob.Id),
					AsyncChainExecution__c.StepLog__c => MALFORMED_STEP_LOG_JSON
			});

			Test.startTest();
			UTIL_AsyncChain.ClearStalledResult counts = UTIL_AsyncChain.clearStalledChains();
			Test.stopTest();

			Assert.areEqual(1, counts.candidates, 'The stalled chain must be inspected as a candidate');
			Assert.areEqual(0, counts.redriven, 'A candidate that cannot be recovered must never count as started again');
			Assert.areEqual(1, counts.markedFailed, 'A candidate that cannot be recovered must count as marked Failed');
			Assert.areEqual(0, counts.remainingStalled, 'A candidate failed for good must not count as remaining');
			AsyncChainExecution__c result = queryExecution(execution.Id);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_FAILED, result.Status__c, 'A step log that cannot be read must fail the candidate for good');
			Assert.isTrue(result.ErrorMessage__c.contains(REDRIVE_UNRECOVERABLE_FRAGMENT), 'The failure must carry the re-drive reason that says what to do');
		}
	}

	/**
	 * @description Verifies Clear Stalled returns true zero counts when no stalled candidates
	 * exist, without throwing.
	 */
	@IsTest
	private static void shouldReportZeroCountsWhenNoStalledChainsExist()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();

			Test.startTest();
			UTIL_AsyncChain.ClearStalledResult counts = UTIL_AsyncChain.clearStalledChains();
			Test.stopTest();

			Assert.areEqual(0, counts.candidates, 'An org with no stalled chains has no candidates');
			Assert.areEqual(0, counts.redriven, 'Nothing can be started again when nothing is stalled');
			Assert.areEqual(0, counts.markedFailed, 'Nothing can be marked failed when nothing is stalled');
			Assert.areEqual(0, counts.remainingStalled, 'Nothing can remain when nothing is stalled');
		}
	}

	/**
	 * @description Verifies the check for a Stalled row with an end time. Such a row is a finished chain whose status was
	 * overwritten, and the operator sweep must not even count it as a candidate. Starting it again would bring back a
	 * completed chain whose deduplication key was already released. The package blocks saving a Stalled record that has
	 * an end time. Older orgs still have such records. So this test turns off that one check while it saves the record.
	 */
	@IsTest
	private static void shouldExcludeStalledRowsWithAnEndTimeFromClearStalled()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();

			AsyncChainExecution__c stalledWithEndTime;
			String actionClassName = TST_Factory.getRunTransitionActionClassName();
			TRG_Base.bypassAction(actionClassName);
			try
			{
				stalledWithEndTime = TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_STALLED, TEST_CHAIN_NAME, new Map<SObjectField, Object>
				{
						AsyncChainExecution__c.CompletedAt__c => Datetime.now(),
						AsyncChainExecution__c.ErrorMessage__c => PRE_SWEEP_SEEDED_REASON
				});
			}
			finally
			{
				TRG_Base.clearActionBypass(actionClassName);
			}

			Test.startTest();
			UTIL_AsyncChain.ClearStalledResult counts = UTIL_AsyncChain.clearStalledChains();
			Test.stopTest();

			Assert.areEqual(0, counts.candidates, 'Expected no candidate: a Stalled row with an end time is a finished row whose status was overwritten');
			AsyncChainExecution__c result = queryExecution(stalledWithEndTime.Id);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_STALLED, result.Status__c, 'Expected the sweep to leave the excluded row Stalled, got ' + result.Status__c);
			Assert.areEqual(PRE_SWEEP_SEEDED_REASON, result.ErrorMessage__c, 'Expected the excluded row to keep its seeded reason');
		}
	}

	/**
	 * @description Verifies the operator sweep's check on the query limit. When fewer queries are left than the operator
	 * sweep keeps free, no candidate's decision steps run. The rows stay exactly as seeded, with no set-aside save. The
	 * counts stay true, because the one extra query kept free still lets the read that counts the results run. The sweep
	 * runs outside Test.startTest, on purpose: startTest starts fresh governor limits, which would give the sweep a full
	 * query limit again. The checks run inside startTest instead.
	 */
	@IsTest
	private static void shouldLeaveTailUntouchedWhenQueryBudgetRunsShort()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();

			TST_Factory.newChainExecutions(CLEAR_STALLED_TAIL_SEED_COUNT, SEL_AsyncChainExecution.STATUS_STALLED, TEST_CHAIN_NAME);
			consumeSoqlBudgetDownTo(QUERY_BUDGET_FOR_NO_SWEPT_OPERATOR_CANDIDATES);

			UTIL_AsyncChain.ClearStalledResult counts = UTIL_AsyncChain.clearStalledChains();

			Test.startTest();
			Assert.areEqual(CLEAR_STALLED_TAIL_SEED_COUNT, counts.candidates, 'Both stalled rows must be counted as candidates');
			Assert.areEqual(0, counts.redriven, 'No decision steps may run when fewer queries are left than kept free');
			Assert.areEqual(0, counts.markedFailed, 'No decision steps may run when fewer queries are left than kept free');
			Assert.areEqual(CLEAR_STALLED_TAIL_SEED_COUNT, counts.remainingStalled, 'Refused candidates must count as remaining');
			List<AsyncChainExecution__c> untouched = new SEL_AsyncChainExecution().findByStatus(SEL_AsyncChainExecution.STATUS_STALLED);
			Assert.areEqual(CLEAR_STALLED_TAIL_SEED_COUNT, untouched.size(), 'Both rows must remain Stalled for a later sweep');
			for(AsyncChainExecution__c row : untouched)
			{
				Assert.isNull(row.ErrorMessage__c, 'A refused candidate must stay untouched: no stall mark, no set-aside save');
			}
			Test.stopTest();
		}
	}

	/**
	 * @description Verifies the operator sweep's check on the DML limit. The scheduled sweep does not need this check,
	 * because an @AuraEnabled transaction may already have used DML statements, and a scheduled one has not. When fewer
	 * DML statements are left than the operator sweep keeps free, no candidate's decision steps run, and the row keeps
	 * its seeded shape. A candidate that was handled would have been marked with the sweep's stall reason. The sweep
	 * runs outside Test.startTest, on purpose: fresh governor limits would give back the DML statements.
	 */
	@IsTest
	private static void shouldLeaveTailUntouchedWhenDmlBudgetRunsShort()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();

			AsyncChainExecution__c execution = TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_STALLED, TEST_CHAIN_NAME, new Map<SObjectField, Object>
			{
					AsyncChainExecution__c.ErrorMessage__c => PRE_SWEEP_SEEDED_REASON,
					AsyncChainExecution__c.StepLog__c => buildStepLogJson()
			});
			consumeDmlBudgetDownTo(DML_BUDGET_FOR_NO_SWEPT_OPERATOR_CANDIDATES);

			UTIL_AsyncChain.ClearStalledResult counts = UTIL_AsyncChain.clearStalledChains();

			Assert.areEqual(1, counts.candidates, 'The stalled row must be counted as a candidate');
			Assert.areEqual(0, counts.redriven, 'No decision steps may run when fewer DML statements are left than kept free');
			Assert.areEqual(0, counts.markedFailed, 'No decision steps may run when fewer DML statements are left than kept free');
			Assert.areEqual(1, counts.remainingStalled, 'The refused candidate must count as remaining');
			AsyncChainExecution__c result = queryExecution(execution.Id);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_STALLED, result.Status__c, 'The refused candidate must stay Stalled');
			Assert.areEqual(PRE_SWEEP_SEEDED_REASON, result.ErrorMessage__c,
					'The refused candidate must keep its seeded reason: a processed candidate would carry the sweep stall reason');
		}
	}

	/**
	 * @description Verifies the operator sweep leaves a slow-but-alive candidate completely
	 * untouched and counts it as remaining. The check finds the saved job still processing, so no mark, no new run key
	 * and nothing queued may happen. Running a live chain twice is the worse fault this check exists to prevent. This
	 * test checks the sweep's check whether the job is alive, on the operator path, apart from the path for rows with no
	 * job id.
	 */
	@IsTest
	private static void shouldCountLiveExecutorCandidateAsRemainingOnClearStalled()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();

			AsyncApexJob liveJob = (AsyncApexJob)TST_Mock.of(AsyncApexJob.SObjectType)
					.withOverride(AsyncApexJob.Status, 'Processing')
					.build();
			String runKey = UTIL_Random.randomUUID();
			AsyncChainExecution__c execution = TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_STALLED, TEST_CHAIN_NAME, new Map<SObjectField, Object>
			{
					AsyncChainExecution__c.RunKey__c => runKey,
					AsyncChainExecution__c.CurrentJobId__c => String.valueOf(liveJob.Id),
					AsyncChainExecution__c.StepLog__c => buildStepLogJson()
			});

			Integer enqueuedJobsBeforeSweep = UTIL_Limits.queueableJobs().used();
			UTIL_AsyncChain.ClearStalledResult counts = UTIL_AsyncChain.clearStalledChains();

			Assert.areEqual(1, counts.candidates, 'The stalled chain must be inspected as a candidate');
			Assert.areEqual(0, counts.redriven, 'A chain with a live job must never be started again: running it twice is the worse fault');
			Assert.areEqual(0, counts.markedFailed, 'A live candidate must not be marked failed');
			Assert.areEqual(1, counts.remainingStalled, 'A live candidate must count as remaining');
			AsyncChainExecution__c result = queryExecution(execution.Id);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_STALLED, result.Status__c, 'A live candidate must stay Stalled, untouched');
			Assert.areEqual(runKey, result.RunKey__c, 'No new run key may be saved while a live job runs: that would block the job while it runs');
			Assert.isNull(result.ErrorMessage__c, 'The live skip must write nothing to the row');
			Assert.areEqual(enqueuedJobsBeforeSweep, UTIL_Limits.queueableJobs().used(), 'A live candidate must queue no job');
		}
	}

	/**
	 * @description Verifies the engine passes its limit on candidates to the selector. With one more stalled row than the
	 * limit allows, the sweep looks at exactly the limit's number of candidates. The test leaves almost no DML
	 * statements, so the check refuses every candidate's decision steps. The limit can then be proven from the
	 * candidate count alone, with no cost for each candidate.
	 */
	@IsTest
	private static void shouldBoundOperatorSweepAtCandidateCeiling()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();

			TST_Factory.newChainExecutions(UTIL_AsyncChain.MAX_OPERATOR_SWEEP_CANDIDATES + 1, SEL_AsyncChainExecution.STATUS_STALLED, TEST_CHAIN_NAME);
			consumeDmlBudgetDownTo(DML_BUDGET_FOR_NO_SWEPT_OPERATOR_CANDIDATES);

			UTIL_AsyncChain.ClearStalledResult counts = UTIL_AsyncChain.clearStalledChains();

			Assert.areEqual(UTIL_AsyncChain.MAX_OPERATOR_SWEEP_CANDIDATES, counts.candidates,
					'One operator invocation must inspect at most the candidate ceiling; the row beyond it waits for the next invocation');
			Assert.areEqual(UTIL_AsyncChain.MAX_OPERATOR_SWEEP_CANDIDATES, counts.remainingStalled, 'Every refused candidate must count as remaining');
		}
	}

	/**
	 * @description Verifies the operator sweep's check when it starts. When the transaction does not have the queries
	 * for even the sweep's own two reads (the candidate read and the read that counts the results), it returns true zero
	 * counts. It does not run either read into a LimitException that cannot be caught, and it touches nothing. The sweep
	 * runs outside Test.startTest, on purpose: fresh governor limits would give back the queries. The checks run inside
	 * startTest instead.
	 */
	@IsTest
	private static void shouldReturnZeroCountsWhenQueryBudgetCannotAffordSweepReads()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();

			AsyncChainExecution__c execution = TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_STALLED, TEST_CHAIN_NAME, new Map<SObjectField, Object>
			{
					AsyncChainExecution__c.ErrorMessage__c => PRE_SWEEP_SEEDED_REASON
			});
			consumeSoqlBudgetDownTo(QUERY_BUDGET_BELOW_OPERATOR_ENTRY_MINIMUM);

			UTIL_AsyncChain.ClearStalledResult counts = UTIL_AsyncChain.clearStalledChains();

			Test.startTest();
			Assert.areEqual(0, counts.candidates, 'Zero candidates honestly means the sweep inspected nothing');
			Assert.areEqual(0, counts.redriven, 'Nothing may be started again when the sweep never ran');
			Assert.areEqual(0, counts.markedFailed, 'Nothing may be marked failed when the sweep never ran');
			Assert.areEqual(0, counts.remainingStalled, 'The check at start reports work NOT looked at, never a guessed count of what remains');
			AsyncChainExecution__c result = queryExecution(execution.Id);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_STALLED, result.Status__c, 'The stalled row must stay untouched for a later call with enough limits');
			Assert.areEqual(PRE_SWEEP_SEEDED_REASON, result.ErrorMessage__c, 'The check at start must write nothing');
			Test.stopTest();
		}
	}

	/**
	 * @description Queries an AsyncChainExecution__c record by ID.
	 *
	 * @param executionId The execution record ID.
	 *
	 * @return The queried execution record.
	 */
	private static AsyncChainExecution__c queryExecution(String executionId)
	{
		return (AsyncChainExecution__c)new SEL_AsyncChainExecution().findById(executionId);
	}

	/**
	 * @description Stores, for real, a running run that holds the given deduplication key, so a start with the same key
	 * clashes on the unique index.
	 *
	 * @param deduplicationKey The key the stored run holds.
	 *
	 * @return The stored run.
	 */
	private static AsyncChainExecution__c storeRunHoldingKey(String deduplicationKey)
	{
		return TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_RUNNING, TEST_CHAIN_NAME, new Map<SObjectField, Object>
		{
				AsyncChainExecution__c.StartedAt__c => Datetime.now(),
				AsyncChainExecution__c.ActiveDeduplicationKey__c => deduplicationKey
		});
	}

	/**
	 * @description Starts a one-step chain under the given deduplication key and returns the run it landed on:
	 * its own when the key was free, the holder's when it deduplicated.
	 *
	 * @param deduplicationKey The key the start declares.
	 *
	 * @return The Id of the run the start landed on.
	 */
	private static String startSameKeyChain(String deduplicationKey)
	{
		return UTIL_AsyncChain.newChain(TEST_CHAIN_NAME)
				.then(new UTIL_AsyncChainRecovery_TEST.SuccessStep())
				.withDeduplicationKey(deduplicationKey)
				.execute();
	}

	/**
	 * @description Blanks the CurrentJobId__c that ChainBuilder.execute saves when it queues the job. This gives the run
	 * record the shape of a row from before the upgrade: one saved by a package version that did not save the job id, or
	 * by a start that caught a failure to queue (see stampExecutorJobId in UTIL_AsyncChain). Such a row has no job id
	 * until its first progress save. The sweep tests need this, because a row with a job id goes to the check whether
	 * the job is alive. Only a row with no usable job id reaches the sweep's path for chains it cannot check, where
	 * age alone marks the chain and notifies (see sweepCandidate in UTIL_AsyncChain).
	 *
	 * @param executionId The execution record ID whose stamp to clear.
	 */
	private static void clearEnqueueTimeStamp(String executionId)
	{
		AsyncChainExecution__c row = (AsyncChainExecution__c)TST_Builder.of(AsyncChainExecution__c.SObjectType)
				.withOverride(AsyncChainExecution__c.Id, (Id)executionId)
				.withOptionalField(AsyncChainExecution__c.ChainName__c)
				.withoutInsertion()
				.build();
		row.CurrentJobId__c = null;
		DML_Builder.newTransaction().systemModeInternal().doUpdate(row).execute();
	}

	/**
	 * @description Inserts a Running execution row carrying the given run key, for the run key tests that call the
	 * engine directly and need full control over the saved key.
	 *
	 * @param runKey The run key to set on the record, or null for an old row.
	 *
	 * @return The saved record with its Id populated.
	 */
	private static AsyncChainExecution__c persistRunningExecutionWithKey(String runKey)
	{
		return TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_RUNNING, TEST_CHAIN_NAME, new Map<SObjectField, Object>
		{
				AsyncChainExecution__c.StartedAt__c => Datetime.now(),
				AsyncChainExecution__c.RunKey__c => runKey
		});
	}

	/**
	 * @description Asserts the aborted row still carries the end time flipToAborted wrote, not one a later save wrote.
	 * flipToAborted writes an end time EXTERNAL_ABORT_AGE_MINUTES before the moment it runs, which is some time between
	 * the launch and now. So the end time must sit in that window, moved back by the same minutes. The lower bound allows
	 * PERSISTED_DATETIME_TOLERANCE_SECONDS, because a saved time keeps whole seconds only.
	 *
	 * @param execution The aborted row as read back.
	 * @param launchedAt The time the test captured just before it launched the chain.
	 * @param saveDescription Words for the save that must not have changed the end time, used in the message.
	 */
	private static void assertEndTimeIsTheAbortsOwn(AsyncChainExecution__c execution, Datetime launchedAt, String saveDescription)
	{
		Datetime earliest = launchedAt.addMinutes(-EXTERNAL_ABORT_AGE_MINUTES).addSeconds(-PERSISTED_DATETIME_TOLERANCE_SECONDS);
		Datetime latest = Datetime.now().addMinutes(-EXTERNAL_ABORT_AGE_MINUTES);
		Assert.isTrue(execution.CompletedAt__c >= earliest && execution.CompletedAt__c <= latest, 'Expected the end time the abort wrote to stay after '
				+ saveDescription + ', between ' + earliest + ' and ' + latest + ', got ' + execution.CompletedAt__c);
	}

	/**
	 * @description Sets the given execution record to Aborted, with an update that writes only the changed fields. It
	 * acts like an abort saved from outside while a job or handler is running. The row gets what an operator
	 * abort leaves: an end time, the OperatorAbort category and no active deduplication key. The end time is
	 * EXTERNAL_ABORT_AGE_MINUTES in the past, so a test can tell it from one the in-flight actor would write. The run key
	 * is untouched, so the running code still passes the run key check: only the refusal keeps the abort in place.
	 *
	 * @param executionId The execution record ID to flip.
	 */
	private static void flipToAborted(Id executionId)
	{
		AsyncChainExecution__c row = (AsyncChainExecution__c)TST_Builder.of(AsyncChainExecution__c.SObjectType)
				.withOverride(AsyncChainExecution__c.Id, executionId)
				.withOverride(AsyncChainExecution__c.Status__c, SEL_AsyncChainExecution.STATUS_ABORTED)
				.withOverride(AsyncChainExecution__c.CompletedAt__c, Datetime.now().addMinutes(-EXTERNAL_ABORT_AGE_MINUTES))
				.withOverride(AsyncChainExecution__c.FailureCategory__c, SEL_AsyncChainExecution.FAILURE_CATEGORY_OPERATOR_ABORT)
				.withOptionalField(AsyncChainExecution__c.ChainName__c)
				.withoutInsertion()
				.build();
		row.ActiveDeduplicationKey__c = null;
		DML_Builder.newTransaction().systemModeInternal().doUpdate(row).execute();
	}

	/**
	 * @description Sets the given record to Failed, the way a failure saved by someone else while a Finalizer is still
	 * running would leave it. The record gets an end time, the StepException category and no active deduplication key.
	 * Only these fields are written. The run key does not change, so the running Finalizer is still allowed to act on
	 * the record.
	 *
	 * @param executionId The execution record ID to flip.
	 */
	private static void flipToFailed(Id executionId)
	{
		AsyncChainExecution__c row = (AsyncChainExecution__c)TST_Builder.of(AsyncChainExecution__c.SObjectType)
				.withOverride(AsyncChainExecution__c.Id, executionId)
				.withOverride(AsyncChainExecution__c.Status__c, SEL_AsyncChainExecution.STATUS_FAILED)
				.withOverride(AsyncChainExecution__c.CompletedAt__c, Datetime.now())
				.withOverride(AsyncChainExecution__c.FailureCategory__c, SEL_AsyncChainExecution.FAILURE_CATEGORY_STEP_EXCEPTION)
				.withOptionalField(AsyncChainExecution__c.ChainName__c)
				.withoutInsertion()
				.build();
		row.ActiveDeduplicationKey__c = null;
		DML_Builder.newTransaction().systemModeInternal().doUpdate(row).execute();
	}

	/**
	 * @description Sets the given execution record to Completed, with its end time set and no active deduplication key,
	 * as the final save of a chain that ended well leaves it. Like flipToFailed, it writes only
	 * these fields. The run key does not change, so the running code is still allowed to act on the record.
	 *
	 * @param executionId The execution record ID to flip.
	 */
	private static void flipToCompleted(Id executionId)
	{
		AsyncChainExecution__c row = (AsyncChainExecution__c)TST_Builder.of(AsyncChainExecution__c.SObjectType)
				.withOverride(AsyncChainExecution__c.Id, executionId)
				.withOverride(AsyncChainExecution__c.Status__c, SEL_AsyncChainExecution.STATUS_COMPLETED)
				.withOverride(AsyncChainExecution__c.CompletedAt__c, Datetime.now())
				.withOptionalField(AsyncChainExecution__c.ChainName__c)
				.withoutInsertion()
				.build();
		row.ActiveDeduplicationKey__c = null;
		DML_Builder.newTransaction().systemModeInternal().doUpdate(row).execute();
	}

	/**
	 * @description Registers a TST_Mock AsyncChainExecution__c row that reads Running and carries the given run key. So
	 * the fresh read before a save still passes the run key check, even though the real row is gone. This lets the tests
	 * of recovery after a DML failure reach the DML on a deleted row. Without it, the run key check would stop first, or
	 * the table of allowed status moves would refuse a row with no status.
	 *
	 * @param executionId The execution record ID the mock must answer for.
	 * @param runKey The run key the mock reports, matching the executor under test.
	 */
	private static void registerAuthorizedExecutionMock(Id executionId, String runKey)
	{
		TST_Mock.register(AsyncChainExecution__c.SObjectType, TST_Builder.of(AsyncChainExecution__c.SObjectType)
				.withOverride(AsyncChainExecution__c.Id, executionId)
				.withOverride(AsyncChainExecution__c.Status__c, SEL_AsyncChainExecution.STATUS_RUNNING)
				.withOverride(AsyncChainExecution__c.RunKey__c, runKey)
				.withoutInsertion()
				.build());
	}

	/**
	 * @description Registers a stand-in (mocked) chain-run record that has already finished. It has the given status, an
	 * end time, the given failure category and the given run key. The real record has been deleted. The stand-in lets the
	 * handler's recovery save pass the status check and go on to save.
	 *
	 * @param executionId The execution record ID the mock must answer for.
	 * @param runKey The run key the mock reports, matching the handler under test.
	 * @param status The finished status the mock reads.
	 * @param failureCategory The failure category the mock carries, or null for a run that ended well.
	 */
	private static void registerFinishedExecutionMock(Id executionId, String runKey, String status, String failureCategory)
	{
		AsyncChainExecution__c finished = (AsyncChainExecution__c)TST_Builder.of(AsyncChainExecution__c.SObjectType)
				.withOverride(AsyncChainExecution__c.Id, executionId)
				.withOverride(AsyncChainExecution__c.Status__c, status)
				.withOverride(AsyncChainExecution__c.RunKey__c, runKey)
				.withoutInsertion()
				.build();
		finished.CompletedAt__c = Datetime.now();
		finished.FailureCategory__c = failureCategory;
		TST_Mock.register(AsyncChainExecution__c.SObjectType, finished);
	}

	/**
	 * @description Returns whether any saved log entry carries a message containing the given
	 * fragment. The run key tests use it to check which log entries were written (or not written).
	 *
	 * @param fragment The message fragment to search for.
	 *
	 * @return True when at least one log entry message contains the fragment.
	 */
	private static Boolean anyLogMessageContains(String fragment)
	{
		for(LogEntry__c log : new SEL_LogEntry().getAll())
		{
			if(log.Message__c != null && log.Message__c.contains(fragment))
			{
				return true;
			}
		}
		return false;
	}

	/**
	 * @description Reports whether any saved log entry at the given level carries the fragment,
	 * so tests can prove not just that a stall was logged but at which severity.
	 *
	 * @param logLevel The LogLevel__c literal to match.
	 * @param fragment The message fragment to look for.
	 *
	 * @return True when a matching entry exists.
	 */
	private static Boolean hasLogEntryAtLevelContaining(String logLevel, String fragment)
	{
		for(LogEntry__c log : new SEL_LogEntry().getAll())
		{
			if(logLevel.equals(log.LogLevel__c) && log.Message__c != null && log.Message__c.contains(fragment))
			{
				return true;
			}
		}
		return false;
	}

	/**
	 * @description Counts saved log entries carrying the fragment, so a test can prove an entry was written exactly
	 * once, not only at least once.
	 *
	 * @param fragment The message fragment to count.
	 *
	 * @return The number of matching entries.
	 */
	private static Integer countLogEntriesContaining(String fragment)
	{
		Integer matches = 0;
		for(LogEntry__c log : new SEL_LogEntry().getAll())
		{
			if(log.Message__c != null && log.Message__c.contains(fragment))
			{
				matches++;
			}
		}
		return matches;
	}

	/**
	 * @description Counts saved LogEntry__c rows whose RecordId__c names the given execution and whose ClassMethod__c
	 * ends with the suffix of the given method. So the refusal tests can prove that a refused final save logged no entry
	 * from its method.
	 *
	 * @param executionId The chain execution record the log entry must name.
	 * @param siteMethodSuffix The suffix of the name of the method that logged the entry (for example
	 * 'handleChainCompletion').
	 *
	 * @return The number of matching log entries.
	 */
	private static Integer countLogsAtSite(Id executionId, String siteMethodSuffix)
	{
		Integer matches = 0;
		for(LogEntry__c logEntry : new SEL_LogEntry().getAll())
		{
			if(logEntry.RecordId__c == String.valueOf(executionId) && logEntry.ClassMethod__c != null && logEntry.ClassMethod__c.endsWith(siteMethodSuffix))
			{
				matches++;
			}
		}
		return matches;
	}

	/**
	 * @description Executes a single-step chain with a CompletionHandler.
	 *
	 * @return The execution record ID.
	 */
	private static String executeWithCompletionHandler()
	{
		return UTIL_AsyncChain.newChain(TEST_CHAIN_NAME)
				.then(new UTIL_AsyncChainRecovery_TEST.SuccessStep())
				.onComplete(new UTIL_AsyncChainRecovery_TEST.CompletionHandlerStep())
				.withAsyncOptions(createAsyncOptions(2))
				.execute();
	}

	/**
	 * @description Parses context data JSON from an execution record into a map, returning an empty map if blank.
	 *
	 * @param execution The execution record containing ContextData__c.
	 *
	 * @return Deserialized context data map.
	 */
	private static Map<String, Object> parseContextData(AsyncChainExecution__c execution)
	{
		return String.isNotBlank(execution.ContextData__c) ? (Map<String, Object>)JSON.deserializeUntyped(execution.ContextData__c) : new Map<String, Object>();
	}

	/**
	 * @description Creates an AsyncOptions instance with the specified queueable stack depth.
	 *
	 * @param stackDepth The maximum queueable stack depth.
	 *
	 * @return The configured AsyncOptions.
	 */
	private static AsyncOptions createAsyncOptions(Integer stackDepth)
	{
		AsyncOptions options = new AsyncOptions();
		options.maximumQueueableStackDepth = stackDepth;
		return options;
	}

	/**
	 * @description Sets up the feature flag cache to indicate the AsyncChain feature is enabled.
	 */
	private static void setupEnabledFeatureFlag()
	{
		FeatureFlag__mdt flag = (FeatureFlag__mdt)TST_Builder.of(FeatureFlag__mdt.SObjectType)
				.withOverride(FeatureFlag__mdt.DeveloperName, UTIL_AsyncChain.FEATURE_FLAG_NAME)
				.withOverride(FeatureFlag__mdt.IsActive__c, true)
				.withOverride(FeatureFlag__mdt.IsEnabledByDefault__c, true)
				.withOverride(FeatureFlag__mdt.ResultOnNoMatch__c, true)
				.withoutInsertion()
				.build();

		SEL_FeatureFlag.allDeveloperNames = new Set<String> {UTIL_AsyncChain.FEATURE_FLAG_NAME};
		SEL_FeatureFlag.activeFlags = new Map<String, FeatureFlag__mdt>
		{
				UTIL_AsyncChain.FEATURE_FLAG_NAME => flag
		};
	}

	/**
	 * @description Builds a DTO_StepDefinition with the given class name and step name.
	 *
	 * @param className The fully-qualified step class name.
	 * @param stepName The display name for the step.
	 *
	 * @return The configured DTO_StepDefinition.
	 */
	private static UTIL_AsyncChain.DTO_StepDefinition buildDtoStepDefinition(String className, String stepName)
	{
		UTIL_AsyncChain.DTO_StepDefinition definition = new UTIL_AsyncChain.DTO_StepDefinition();
		definition.className = className;
		definition.stepName = stepName;
		return definition;
	}

	/**
	 * @description Builds a saved step-log JSON body containing one regular step and no
	 * error-handler entry, for the watchdog tests that assert no notification resolves.
	 *
	 * @return The serialized step-log JSON.
	 */
	private static String buildStepLogJson()
	{
		return JSON.serialize(new List<UTIL_AsyncChain.DTO_StepDefinition> {buildDtoStepDefinition('UTIL_AsyncChainRecovery_TEST.SuccessStep', 'SuccessStep')}, true);
	}

	/**
	 * @description Builds a saved step-log JSON body containing one regular step plus a
	 * counting error-handler entry, for the watchdog tests that assert how often the saved
	 * onError notification fires.
	 *
	 * @return The serialized step-log JSON.
	 */
	private static String buildStepLogJsonWithErrorHandler()
	{
		UTIL_AsyncChain.DTO_StepDefinition handlerDefinition = buildDtoStepDefinition(CountingErrorHandlerStep.class.getName(), 'CountingErrorHandler');
		handlerDefinition.isErrorHandler = true;
		return JSON.serialize(new List<UTIL_AsyncChain.DTO_StepDefinition>
		{
				buildDtoStepDefinition('UTIL_AsyncChainRecovery_TEST.SuccessStep', 'SuccessStep'),
				handlerDefinition
		}, true);
	}

	/**
	 * @description Builds a saved step-log JSON document shaped like a re-drive candidate in the middle of its chain:
	 * one completed step, one pending step, then the error-handler and completion-handler entries. The handler entries
	 * come after the steps, which is the order the engine always saves them in.
	 *
	 * @return The serialized step-log JSON.
	 */
	private static String buildMidChainStepLogWithHandlers()
	{
		UTIL_AsyncChain.DTO_StepDefinition completedStep = buildDtoStepDefinition('UTIL_AsyncChainRecovery_TEST.SuccessStep', 'SuccessStep');
		completedStep.success = true;
		completedStep.durationMs = 5;

		UTIL_AsyncChain.DTO_StepDefinition errorHandlerEntry = buildDtoStepDefinition(CountingErrorHandlerStep.class.getName(), 'CountingErrorHandler');
		errorHandlerEntry.isErrorHandler = true;

		UTIL_AsyncChain.DTO_StepDefinition completionHandlerEntry = buildDtoStepDefinition(CompletionHandlerStep.class.getName(), 'CompletionHandler');
		completionHandlerEntry.isCompletionHandler = true;

		return JSON.serialize(new List<UTIL_AsyncChain.DTO_StepDefinition>
		{
				completedStep,
				buildDtoStepDefinition('UTIL_AsyncChainRecovery_TEST.SuccessStep', 'SuccessStep'),
				errorHandlerEntry,
				completionHandlerEntry
		}, true);
	}

	/**
	 * @description Seeds the shared re-drive candidate that the tests proving old jobs are blocked start from: a stale
	 * Running row in the middle of its chain (two steps, one completed) with the caller's old run key, a mocked Aborted
	 * AsyncApexJob as its current job, proven dead, the step log with handlers, and the saved context.
	 *
	 * @param staleRunKey The old run key to set. The caller keeps it, to prove an old job is blocked.
	 *
	 * @return The seeded AsyncChainExecution__c record.
	 */
	private static AsyncChainExecution__c seedMidChainDeadRedriveCandidate(String staleRunKey)
	{
		AsyncApexJob deadJob = (AsyncApexJob)TST_Mock.of(AsyncApexJob.SObjectType)
				.withOverride(AsyncApexJob.Status, 'Aborted')
				.build();

		return TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_RUNNING, TEST_CHAIN_NAME, new Map<SObjectField, Object>
		{
				AsyncChainExecution__c.TotalSteps__c => 2,
				AsyncChainExecution__c.CompletedSteps__c => 1,
				AsyncChainExecution__c.StartedAt__c => Datetime.now(),
				AsyncChainExecution__c.RunKey__c => staleRunKey,
				AsyncChainExecution__c.CurrentJobId__c => String.valueOf(deadJob.Id),
				AsyncChainExecution__c.StepLog__c => buildMidChainStepLogWithHandlers(),
				AsyncChainExecution__c.ContextData__c => JSON.serialize(new Map<String, Object> {'stepCount' => 1})
		});
	}

	/**
	 * @description Seeds a stale Running row in the middle of its chain (two steps, one completed) around the given
	 * hand-built step log, with a mocked Aborted AsyncApexJob as its current job, proven dead, and the saved context, for the
	 * sweep tests that decide a re-drive from the second entry's markers.
	 *
	 * @param stepLogJson The hand-built saved step log.
	 *
	 * @return The seeded AsyncChainExecution__c record.
	 */
	private static AsyncChainExecution__c seedDeadMidChainCandidate(String stepLogJson)
	{
		AsyncApexJob deadJob = (AsyncApexJob)TST_Mock.of(AsyncApexJob.SObjectType)
				.withOverride(AsyncApexJob.Status, 'Aborted')
				.build();

		return TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_RUNNING, TEST_CHAIN_NAME, new Map<SObjectField, Object>
		{
				AsyncChainExecution__c.TotalSteps__c => 2,
				AsyncChainExecution__c.CompletedSteps__c => 1,
				AsyncChainExecution__c.StartedAt__c => Datetime.now(),
				AsyncChainExecution__c.RunKey__c => UTIL_Random.randomUUID(),
				AsyncChainExecution__c.CurrentJobId__c => String.valueOf(deadJob.Id),
				AsyncChainExecution__c.StepLog__c => stepLogJson,
				AsyncChainExecution__c.ContextData__c => JSON.serialize(new Map<String, Object> {STEP_COUNT_KEY => 1})
		});
	}

	/**
	 * @description Builds the step log of an operator retry candidate that qualifies: a completed TrackingStep, a failed
	 * IdempotentRecoveringStep whose entry declares isIdempotent and carries the run-time markers of a real failure that
	 * ended the chain, and an error-handler entry at the end. So the retry tests also check that handler entries stay
	 * when the failed entry resets, and are rebuilt without firing when the run succeeds.
	 *
	 * @return The serialized step-log JSON.
	 */
	private static String buildRetryEligibleStepLog()
	{
		UTIL_AsyncChain.DTO_StepDefinition completedStep = buildDtoStepDefinition('UTIL_AsyncChainRecovery_TEST.TrackingStep', 'TrackingStep');
		completedStep.success = true;
		completedStep.durationMs = 5;

		UTIL_AsyncChain.DTO_StepDefinition failedStep = buildDtoStepDefinition(IdempotentRecoveringStep.class.getName(), 'IdempotentRecoveringStep');
		failedStep.isIdempotent = true;
		failedStep.started = true;
		failedStep.success = false;
		failedStep.message = RETRY_FAILURE_MESSAGE;
		failedStep.attempt = RETRY_PRIOR_ATTEMPT_COUNT;
		failedStep.durationMs = 3;

		UTIL_AsyncChain.DTO_StepDefinition handlerEntry = buildDtoStepDefinition(CountingErrorHandlerStep.class.getName(), 'CountingErrorHandler');
		handlerEntry.isErrorHandler = true;

		return JSON.serialize(new List<UTIL_AsyncChain.DTO_StepDefinition> {completedStep, failedStep, handlerEntry}, true);
	}

	/**
	 * @description Builds a retry-eligible step log padded to within NEAR_CAPACITY_HEADROOM characters of the StepLog__c
	 * capacity once the failed entry is cleared. The failed entry carries only its failed marker, so the seeded document
	 * still fits the field; the completed step's display name takes the padding, which no job reads.
	 *
	 * @return The serialized step-log JSON.
	 */
	private static String buildNearCapacityRetryEligibleStepLog()
	{
		UTIL_AsyncChain.DTO_StepDefinition completedStep = buildDtoStepDefinition('UTIL_AsyncChainRecovery_TEST.TrackingStep', 'TrackingStep');
		completedStep.success = true;
		completedStep.durationMs = 5;
		UTIL_AsyncChain.DTO_StepDefinition failedStep = buildDtoStepDefinition(IdempotentRecoveringStep.class.getName(), 'IdempotentRecoveringStep');
		failedStep.isIdempotent = true;
		failedStep.started = true;
		List<UTIL_AsyncChain.DTO_StepDefinition> entries = new List<UTIL_AsyncChain.DTO_StepDefinition> {completedStep, failedStep};

		Integer clearedLength = JSON.serialize(entries, true).length();
		Integer stepLogCapacity = AsyncChainExecution__c.StepLog__c.getDescribe().getLength();
		completedStep.stepName += 'N'.repeat(stepLogCapacity - clearedLength - NEAR_CAPACITY_HEADROOM);
		failedStep.success = false;
		return JSON.serialize(entries, true);
	}

	/**
	 * @description Builds a retry-eligible step log that fits StepLog__c with BARELY_FITTING_HEADROOM characters to spare once the
	 * failed entry is cleared, and whose first step is a continued failure carrying a message: the marker has no room, and the
	 * message must survive the retry's write.
	 *
	 * @return The serialized step-log JSON.
	 */
	private static String buildBarelyFittingStepLogWithAContinuedFailure()
	{
		UTIL_AsyncChain.DTO_StepDefinition continuedStep = buildDtoStepDefinition('UTIL_AsyncChainRecovery_TEST.TrackingStep', 'TrackingStep');
		continuedStep.continueOnError = true;
		continuedStep.success = false;
		continuedStep.message = RETRY_FAILURE_MESSAGE;
		continuedStep.durationMs = 5;
		UTIL_AsyncChain.DTO_StepDefinition failedStep = buildDtoStepDefinition(IdempotentRecoveringStep.class.getName(), 'IdempotentRecoveringStep');
		failedStep.isIdempotent = true;
		failedStep.started = true;
		List<UTIL_AsyncChain.DTO_StepDefinition> entries = new List<UTIL_AsyncChain.DTO_StepDefinition> {continuedStep, failedStep};

		Integer clearedLength = JSON.serialize(entries, true).length();
		Integer stepLogCapacity = AsyncChainExecution__c.StepLog__c.getDescribe().getLength();
		continuedStep.stepName += 'N'.repeat(stepLogCapacity - clearedLength - BARELY_FITTING_HEADROOM);
		failedStep.success = false;
		return JSON.serialize(entries, true);
	}

	/**
	 * @description Builds a near-capacity retry-eligible step log with a third step still to run after the failed one, padded to
	 * within TWO_STEPS_TO_GO_HEADROOM characters of the StepLog__c capacity once the failed entry is cleared: two steps have yet
	 * to record a result, so the room rule must keep room free for two steps before it can keep the marker.
	 *
	 * @return The serialized step-log JSON.
	 */
	private static String buildNearCapacityStepLogWithAStepStillToRun()
	{
		UTIL_AsyncChain.DTO_StepDefinition completedStep = buildDtoStepDefinition('UTIL_AsyncChainRecovery_TEST.TrackingStep', 'TrackingStep');
		completedStep.success = true;
		completedStep.durationMs = 5;
		UTIL_AsyncChain.DTO_StepDefinition failedStep = buildDtoStepDefinition(IdempotentRecoveringStep.class.getName(), 'IdempotentRecoveringStep');
		failedStep.isIdempotent = true;
		failedStep.started = true;
		UTIL_AsyncChain.DTO_StepDefinition pendingStep = buildDtoStepDefinition('UTIL_AsyncChainRecovery_TEST.TrackingStep', 'TrackingStep');
		List<UTIL_AsyncChain.DTO_StepDefinition> entries = new List<UTIL_AsyncChain.DTO_StepDefinition> {completedStep, failedStep, pendingStep};

		Integer clearedLength = JSON.serialize(entries, true).length();
		Integer stepLogCapacity = AsyncChainExecution__c.StepLog__c.getDescribe().getLength();
		completedStep.stepName += 'N'.repeat(stepLogCapacity - clearedLength - TWO_STEPS_TO_GO_HEADROOM);
		failedStep.success = false;
		return JSON.serialize(entries, true);
	}

	/**
	 * @description Builds an operator retry step log that does not qualify: its failed entry never declared
	 * isIdempotent. Rows from before the upgrade, and steps that declare nothing, have this shape, and the retry check
	 * must refuse it.
	 *
	 * @return The serialized step-log JSON.
	 */
	private static String buildFailedStepLogWithoutIdempotentMarker()
	{
		UTIL_AsyncChain.DTO_StepDefinition completedStep = buildDtoStepDefinition('UTIL_AsyncChainRecovery_TEST.TrackingStep', 'TrackingStep');
		completedStep.success = true;
		completedStep.durationMs = 5;

		UTIL_AsyncChain.DTO_StepDefinition failedStep = buildDtoStepDefinition('UTIL_AsyncChainRecovery_TEST.FailingStep', 'FailingStep');
		failedStep.started = true;
		failedStep.success = false;
		failedStep.message = RETRY_FAILURE_MESSAGE;
		failedStep.durationMs = 3;

		return JSON.serialize(new List<UTIL_AsyncChain.DTO_StepDefinition> {completedStep, failedStep}, true);
	}

	/**
	 * @description Builds an operator retry step log whose failure was declared permanent. The failed entry declares
	 * BOTH isIdempotent and permanentFailure, so a refusal proves the permanent failure wins over the idempotency
	 * declaration.
	 *
	 * @return The serialized step-log JSON.
	 */
	private static String buildFailedStepLogWithPermanentFailureMarker()
	{
		UTIL_AsyncChain.DTO_StepDefinition completedStep = buildDtoStepDefinition('UTIL_AsyncChainRecovery_TEST.TrackingStep', 'TrackingStep');
		completedStep.success = true;
		completedStep.durationMs = 5;

		UTIL_AsyncChain.DTO_StepDefinition failedStep = buildDtoStepDefinition(IdempotentRecoveringStep.class.getName(), 'IdempotentRecoveringStep');
		failedStep.isIdempotent = true;
		failedStep.started = true;
		failedStep.permanentFailure = true;
		failedStep.success = false;
		failedStep.message = RETRY_FAILURE_MESSAGE;
		failedStep.durationMs = 3;

		return JSON.serialize(new List<UTIL_AsyncChain.DTO_StepDefinition> {completedStep, failedStep}, true);
	}

	/**
	 * @description Seeds a Failed chain row from the given hand-built step log. It carries all the end-of-run fields of a
	 * real failure: a context that parses, a run key, an end time, a duration, a failure category and an error message.
	 * That is exactly the shape the operator retry check reads and its one update must clear.
	 *
	 * @param stepLogJson The hand-built saved step log.
	 *
	 * @return The seeded record, read again with the default field list.
	 */
	private static AsyncChainExecution__c seedFailedRetryChain(String stepLogJson)
	{
		AsyncChainExecution__c execution = TST_Factory.newChainExecution(
				SEL_AsyncChainExecution.STATUS_FAILED, RETRY_TEST_CHAIN_NAME, stepLogJson, RETRY_TOTAL_STEPS, RETRY_COMPLETED_STEPS);
		stampTerminalBookkeeping(execution);
		DML_Builder.newTransaction().withSystemMode().doUpdate(execution).execute();
		return queryExecution(execution.Id);
	}

	/**
	 * @description Seeds the same Failed chain row as seedFailedRetryChain, with the given completion timestamp written
	 * at birth. A finished run's end time never changes once written, so a test that needs a particular end time
	 * seeds it here instead of rewriting it afterwards.
	 *
	 * @param stepLogJson The hand-built saved step log.
	 * @param completedAt The end time the failed run recorded.
	 *
	 * @return The seeded record, read again with the default field list.
	 */
	private static AsyncChainExecution__c seedFailedRetryChain(String stepLogJson, Datetime completedAt)
	{
		AsyncChainExecution__c execution = TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_FAILED, RETRY_TEST_CHAIN_NAME,
				new Map<SObjectField, Object>
				{
						AsyncChainExecution__c.StepLog__c => stepLogJson,
						AsyncChainExecution__c.TotalSteps__c => RETRY_TOTAL_STEPS,
						AsyncChainExecution__c.CompletedSteps__c => RETRY_COMPLETED_STEPS,
						AsyncChainExecution__c.StartedAt__c => completedAt.addMinutes(-RETRY_SEEDED_RUN_MINUTES),
						AsyncChainExecution__c.CompletedAt__c => completedAt
				});
		stampTerminalBookkeeping(execution);
		DML_Builder.newTransaction().withSystemMode().doUpdate(execution).execute();
		return queryExecution(execution.Id);
	}

	/**
	 * @description Sets the end-of-run fields that a real failure leaves behind: a context that parses, a run key, an end
	 * time, a duration, a failure category and an error message. An end time the row was
	 * seeded with is kept, because a finished run's end time never changes once written. A Running or Stalled row (the
	 * ineligible statuses the refusal tests seed) gets the context, run key and message only: a run that has not
	 * finished never carries an end time, a duration or a failure category. The retry and restart set-up methods share
	 * it on purpose. Both checks read the same end-of-run shape. Two copies of this code could slowly drift into rows of
	 * different shapes, and the two sets of tests would no longer test the same thing.
	 *
	 * @param execution The seeded row to set the fields on, in memory. The caller does the DML.
	 */
	private static void stampTerminalBookkeeping(AsyncChainExecution__c execution)
	{
		execution.ContextData__c = RETRY_CONTEXT_JSON;
		execution.RunKey__c = UTIL_Random.randomUUID();
		execution.ErrorMessage__c = RETRY_FAILURE_MESSAGE;
		if(execution.Status__c == SEL_AsyncChainExecution.STATUS_RUNNING || execution.Status__c == SEL_AsyncChainExecution.STATUS_STALLED)
		{
			return;
		}
		execution.CompletedAt__c = execution.CompletedAt__c ?? Datetime.now();
		execution.DurationMs__c = RETRY_SEEDED_DURATION_MS;
		execution.FailureCategory__c = SEL_AsyncChainExecution.FAILURE_CATEGORY_STEP_EXCEPTION;
	}

	/**
	 * @description Builds the copy of the starting data that the restart tests seed: one business value plus a logging
	 * entry carrying the SOURCE correlation. That is exactly the shape ChainBuilder saves when the chain is built, so
	 * the restart has a real entry to replace.
	 *
	 * @return The serialized copy of the starting data, as JSON.
	 */
	private static String buildRestartSnapshotJson()
	{
		return JSON.serialize(new Map<String, Object>
		{
				RESTART_SNAPSHOT_KEY => RESTART_SNAPSHOT_VALUE,
				CONTEXT_LOG_KEY => JSON.serialize(new Map<String, String> {LOG_CONTEXT_CORRELATION_FIELD => SOURCE_LOG_CORRELATION_ID})
		});
	}

	/**
	 * @description Seeds a finished chain row that allows a restart: AllowRestart__c, the copy of the starting data, a
	 * step log that qualifies, and all the end-of-run fields. That is exactly the shape the restart action reads through
	 * its own read.
	 *
	 * @param status The final status to seed (Failed or Aborted).
	 *
	 * @return The seeded record, read again through the restart read (findByIdForRestart).
	 */
	private static AsyncChainExecution__c seedRestartDeclaredChain(String status)
	{
		AsyncChainExecution__c execution = TST_Factory.newChainExecution(
				status, RESTART_TEST_CHAIN_NAME, buildRetryEligibleStepLog(), RETRY_TOTAL_STEPS, RETRY_COMPLETED_STEPS);
		stampTerminalBookkeeping(execution);
		execution.AllowRestart__c = true;
		execution.InitialContextData__c = buildRestartSnapshotJson();
		DML_Builder.newTransaction().withSystemMode().doUpdate(execution).execute();
		return new SEL_AsyncChainExecution().findByIdForRestart(execution.Id);
	}

	/**
	 * @description Seeds a chain that allows a restart, whose copy of the starting data carries a full logging document:
	 * a source correlation, a root and a context value. That is what a run launched inside a traced action saves.
	 *
	 * @param status The final status to seed.
	 *
	 * @return The seeded execution, read through the restart read (findByIdForRestart).
	 */
	private static AsyncChainExecution__c seedRestartDeclaredChainWithRootedContext(String status)
	{
		AsyncChainExecution__c execution = TST_Factory.newChainExecution(
				status, RESTART_TEST_CHAIN_NAME, buildRetryEligibleStepLog(), RETRY_TOTAL_STEPS, RETRY_COMPLETED_STEPS);
		stampTerminalBookkeeping(execution);
		execution.AllowRestart__c = true;
		execution.RootCorrelationId__c = SOURCE_ROOT_CORRELATION_ID;
		execution.InitialContextData__c = JSON.serialize(new Map<String, Object>
		{
				CONTEXT_LOG_KEY => ROOTED_LOG_CONTEXT_VALUE,
				RESTART_SNAPSHOT_KEY => RESTART_SNAPSHOT_VALUE
		});
		DML_Builder.newTransaction().withSystemMode().doUpdate(execution).execute();
		return new SEL_AsyncChainExecution().findByIdForRestart(execution.Id);
	}

	/**
	 * @description Seeds a failed one-step chain that allows a restart. Its step launches a child chain, whose own step
	 * launches a grandchild (the nested launching step from UTIL_AsyncChain_TEST). So a test can prove that the steps of
	 * a run started again may launch chains under the settings recovery uses.
	 *
	 * @return The seeded execution, read through the restart read (findByIdForRestart).
	 */
	private static AsyncChainExecution__c seedRestartDeclaredNestedLaunchChain()
	{
		UTIL_AsyncChain.DTO_StepDefinition launchingStep = buildDtoStepDefinition(NESTED_LAUNCH_STEP_CLASS_NAME, NESTED_LAUNCH_STEP_NAME);
		launchingStep.success = false;
		launchingStep.message = RETRY_FAILURE_MESSAGE;
		String stepLog = JSON.serialize(new List<UTIL_AsyncChain.DTO_StepDefinition> {launchingStep}, true);
		AsyncChainExecution__c execution = TST_Factory.newChainExecution(
				SEL_AsyncChainExecution.STATUS_FAILED, RESTART_TEST_CHAIN_NAME, stepLog, NESTED_LAUNCH_TOTAL_STEPS, 0);
		stampTerminalBookkeeping(execution);
		execution.AllowRestart__c = true;
		execution.InitialContextData__c = buildRestartSnapshotJson();
		DML_Builder.newTransaction().withSystemMode().doUpdate(execution).execute();
		return new SEL_AsyncChainExecution().findByIdForRestart(execution.Id);
	}

	/**
	 * @description Builds a copy of the starting data that fills InitialContextData__c to its exact field capacity, with
	 * a logging entry kept very small on purpose. Restarting from it must overflow: the restart swaps that entry for a
	 * full correlation document, so the new run's ContextData__c cannot fit in the same size of field.
	 *
	 * @return The serialized copy that fills the field, as JSON.
	 */
	private static String buildCapacityFillingSnapshotJson()
	{
		Map<String, Object> snapshot = new Map<String, Object>
		{
				CONTEXT_LOG_KEY => TINY_LOG_CONTEXT_VALUE,
				SNAPSHOT_PADDING_KEY => UTIL_String.EMPTY
		};
		Integer fillerLength = CONTEXT_DATA_FIELD_CAPACITY - JSON.serialize(snapshot).length();
		snapshot.put(SNAPSHOT_PADDING_KEY, 'p'.repeat(fillerLength));
		return JSON.serialize(snapshot);
	}

	/**
	 * @description Queries the new runs a restart action inserted for the given source run. The list is empty when a
	 * refused restart rightly inserted nothing.
	 *
	 * @param sourceExecutionId The source run whose restarted runs to query.
	 *
	 * @return The new rows that point at the source.
	 */
	private static List<AsyncChainExecution__c> queryRestartClones(Id sourceExecutionId)
	{
		return QRY_Builder.selectFrom(AsyncChainExecution__c.SObjectType)
				.condition(AsyncChainExecution__c.SourceExecution__c).equals(sourceExecutionId)
				.toList();
	}

	/**
	 * @description Builds a saved step-log JSON document in which every step entry carries a success marker (a chain that
	 * tried all its work but never finished), plus a counting error-handler entry. Two kinds of test use it. The
	 * notification tests for the fallback that fails a chain for good: with no step left to resume, the resume point
	 * lands past the last entry, and the fallback must notify. And the test that the operator retry refuses a log with
	 * no failed entry that stopped the chain.
	 *
	 * @return The serialized step-log JSON.
	 */
	private static String buildAllAttemptedStepLogWithErrorHandler()
	{
		UTIL_AsyncChain.DTO_StepDefinition attemptedStep = buildDtoStepDefinition('UTIL_AsyncChainRecovery_TEST.SuccessStep', 'SuccessStep');
		attemptedStep.success = true;
		attemptedStep.durationMs = 5;

		UTIL_AsyncChain.DTO_StepDefinition handlerEntry = buildDtoStepDefinition(CountingErrorHandlerStep.class.getName(), 'CountingErrorHandler');
		handlerEntry.isErrorHandler = true;

		return JSON.serialize(new List<UTIL_AsyncChain.DTO_StepDefinition> {attemptedStep, handlerEntry}, true);
	}

	/**
	 * @description Builds a saved step-log JSON document with a continueOnError history: a step that ran and succeeded, a
	 * step that ran, failed and was passed, then a step not tried yet. The tests of the resume point check that only the
	 * third entry, the first with no success marker, is tried again on re-drive.
	 *
	 * @return The serialized step-log JSON.
	 */
	private static String buildContinueOnErrorHistoryStepLog()
	{
		UTIL_AsyncChain.DTO_StepDefinition attemptedSuccess = buildDtoStepDefinition('UTIL_AsyncChainRecovery_TEST.SuccessStep', 'SuccessStep');
		attemptedSuccess.success = true;
		attemptedSuccess.durationMs = 5;

		UTIL_AsyncChain.DTO_StepDefinition attemptedContinuedFailure = buildDtoStepDefinition('UTIL_AsyncChainRecovery_TEST.FailingStep', 'FailingStep');
		attemptedContinuedFailure.continueOnError = true;
		attemptedContinuedFailure.success = false;
		attemptedContinuedFailure.durationMs = 3;
		attemptedContinuedFailure.message = 'Deliberate failure';

		return JSON.serialize(new List<UTIL_AsyncChain.DTO_StepDefinition>
		{
				attemptedSuccess,
				attemptedContinuedFailure,
				buildDtoStepDefinition('UTIL_AsyncChainRecovery_TEST.SuccessStep', 'SuccessStep')
		}, true);
	}

	/**
	 * @description Builds the step log an job leaves when a step fails and the chain goes on, and the next step then
	 * ends the run without recording a result: a started continued failure, then a started step with no result.
	 *
	 * @return The serialized step-log JSON.
	 */
	private static String buildContinuedFailureThenStartedStepLog()
	{
		UTIL_AsyncChain.DTO_StepDefinition continuedFailure = buildDtoStepDefinition('UTIL_AsyncChainRecovery_TEST.FailingStep', 'FailingStep');
		continuedFailure.continueOnError = true;
		continuedFailure.started = true;
		continuedFailure.success = false;
		continuedFailure.durationMs = 3;
		continuedFailure.message = RETRY_FAILURE_MESSAGE;

		UTIL_AsyncChain.DTO_StepDefinition startedStep = buildDtoStepDefinition('UTIL_AsyncChainRecovery_TEST.SuccessStep', 'SuccessStep');
		startedStep.started = true;

		return JSON.serialize(new List<UTIL_AsyncChain.DTO_StepDefinition> {continuedFailure, startedStep}, true);
	}

	/**
	 * @description Builds a two-step saved step-log JSON document with no run-time markers on either entry. That is the
	 * old shape, whose resume point only CompletedSteps__c can give.
	 *
	 * @return The serialized step-log JSON.
	 */
	private static String buildLegacyMarkerlessStepLog()
	{
		return JSON.serialize(new List<UTIL_AsyncChain.DTO_StepDefinition>
		{
				buildDtoStepDefinition('UTIL_AsyncChainRecovery_TEST.SuccessStep', 'SuccessStep'),
				buildDtoStepDefinition('UTIL_AsyncChainRecovery_TEST.SuccessStep', 'SuccessStep')
		}, true);
	}

	/**
	 * @description Builds a step-log document in the format of versions before 1.4, cut off in the middle of the array.
	 * It is a valid two-entry list with no markers, cut at TRUNCATED_STEP_LOG_PERCENT of its length. The cut lands inside
	 * the second entry, so reading the JSON throws. An old row that was only partly written leaves this shape behind.
	 *
	 * @return The truncated step-log document.
	 */
	private static String buildTruncatedLegacyStepLog()
	{
		String legacyDocument = buildLegacyMarkerlessStepLog();
		return legacyDocument.substring(0, legacyDocument.length() * TRUNCATED_STEP_LOG_PERCENT / 100);
	}

	/**
	 * @description Builds a saved step-log JSON document shaped like a chain that died during a retry, on a package
	 * version that recorded no starts. It holds a completed first step, then a second entry with a pending retry. That
	 * entry carries the raised attempt marker, a cleared success marker and no started marker. This is the state
	 * scheduleRetry saved before the delayed job was queued again, as a row written before starts existed carries it.
	 *
	 * @return The serialised step-log JSON.
	 */
	private static String buildRetryPendingStepLog()
	{
		UTIL_AsyncChain.DTO_StepDefinition completedStep = buildDtoStepDefinition('UTIL_AsyncChainRecovery_TEST.SuccessStep', 'SuccessStep');
		completedStep.success = true;
		completedStep.durationMs = 5;

		UTIL_AsyncChain.DTO_StepDefinition retryPendingStep = buildDtoStepDefinition('UTIL_AsyncChainRecovery_TEST.SuccessStep', 'SuccessStep');
		retryPendingStep.attempt = RETRY_PENDING_ATTEMPT;

		return JSON.serialize(new List<UTIL_AsyncChain.DTO_StepDefinition> {completedStep, retryPendingStep}, true);
	}

	/**
	 * @description Builds a saved step-log JSON document shaped like a chain that died on a step declared idempotent:
	 * a completed first step, then an IdempotentRecoveringStep entry that started and recorded no result.
	 *
	 * @return The serialised step-log JSON.
	 */
	private static String buildStartedIdempotentStepLog()
	{
		UTIL_AsyncChain.DTO_StepDefinition completedStep = buildDtoStepDefinition('UTIL_AsyncChainRecovery_TEST.SuccessStep', 'SuccessStep');
		completedStep.started = true;
		completedStep.success = true;
		completedStep.durationMs = 5;

		UTIL_AsyncChain.DTO_StepDefinition startedStep = buildDtoStepDefinition(IdempotentRecoveringStep.class.getName(), 'IdempotentRecoveringStep');
		startedStep.isIdempotent = true;
		startedStep.started = true;

		return JSON.serialize(new List<UTIL_AsyncChain.DTO_StepDefinition> {completedStep, startedStep}, true);
	}

	/**
	 * @description Builds a one-entry step-log JSON document in the shape from before the upgrade (only the className and
	 * stepName keys, no attempt or retry-limit fields), whose step always fails, for the
	 * upgrade test (a record saved by a package version from before the upgrade, then run by the
	 * current version).
	 *
	 * @return The serialised step-log JSON.
	 */
	private static String buildLegacyFailingStepLog()
	{
		return JSON.serialize(new List<UTIL_AsyncChain.DTO_StepDefinition> {buildDtoStepDefinition(CountingFailingStep.class.getName(), 'CountingFailingStep')}, true);
	}

	/**
	 * @description Deserialises an execution record's saved step log into its step definitions: steps first and handler
	 * entries last, which is the order the engine always saves them in.
	 *
	 * @param execution The execution record carrying StepLog__c.
	 *
	 * @return The deserialised step definitions.
	 */
	private static List<UTIL_AsyncChain.DTO_StepDefinition> parseStepLog(AsyncChainExecution__c execution)
	{
		return (List<UTIL_AsyncChain.DTO_StepDefinition>)JSON.deserialize(execution.StepLog__c, List<UTIL_AsyncChain.DTO_StepDefinition>.class);
	}

	/**
	 * @description The reason the sweep records when it will not run a started step again: the subscriber-visible label
	 * with the step's display name, which for a step built without a name is its class name.
	 *
	 * @param stepDisplayName The refused step's display name.
	 *
	 * @return The expected ErrorMessage__c value.
	 */
	private static String expectedStartedStepRefusal(String stepDisplayName)
	{
		return String.format(System.Label.AsyncChain_RecoveryStoppedAtStartedStep, new List<String> {stepDisplayName});
	}

	/**
	 * @description Queues Queueable jobs that do nothing until the transaction can add no more, so the limit tests can
	 * run the watchdog sweep with UTIL_Limits.queueableJobs().remaining() at zero. It must run outside Test.startTest:
	 * startTest starts fresh governor limits, which would give the sweep a full limit again. The filler jobs never run:
	 * nothing starts them and the test transaction rolls back. Queuing inside a loop is done on purpose and stops by
	 * itself, because reaching the limit ends the loop. That is why the PMD rule is turned off for this method.
	 */
	@SuppressWarnings('PMD.OperationWithLimitsInLoop')
	private static void consumeAllQueueableBudget()
	{
		while(!UTIL_Limits.queueableJobs().isExhausted())
		{
			System.enqueueJob(new BudgetConsumingQueueable());
		}
	}

	/**
	 * @description Runs selector reads until the transaction has only the given number of synchronous queries left, so
	 * the query limit test can run the watchdog sweep with a known, small number of queries left. It must run outside
	 * Test.startTest: startTest starts fresh governor limits, which would give the sweep a full query limit again.
	 * Querying inside a loop is done on purpose and stops by itself, because reaching the target ends the loop. That is
	 * why the PMD rule is turned off for this method.
	 *
	 * @param targetRemaining The number of queries to leave for the code under test.
	 */
	@SuppressWarnings('PMD.OperationWithLimitsInLoop')
	private static void consumeSoqlBudgetDownTo(Integer targetRemaining)
	{
		while(UTIL_Limits.soqlQueries().remaining() > targetRemaining)
		{
			new SEL_AsyncChainExecution().findByStatus(SEL_AsyncChainExecution.STATUS_RUNNING);
		}
	}

	/**
	 * @description Runs one-row updates until the transaction has only the given number of DML statements left, so the
	 * test of the operator sweep's DML limit check can run with a known, small number of statements left. It must run
	 * outside Test.startTest: startTest starts fresh governor limits, which would give the sweep a full DML limit again.
	 * DML inside a loop is done on purpose and stops by itself, because reaching the target ends the loop. That is why
	 * the PMD rule is turned off for this method. The loop may end one statement below the target, when one builder
	 * transaction uses more than one statement. Every caller only needs "at or below the target", so ending lower does
	 * no harm.
	 *
	 * @param targetRemaining The number of DML statements to leave for the code under test.
	 */
	@SuppressWarnings('PMD.OperationWithLimitsInLoop')
	private static void consumeDmlBudgetDownTo(Integer targetRemaining)
	{
		AsyncChainExecution__c budgetConsumer = TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_COMPLETED, TEST_CHAIN_NAME);
		while(UTIL_Limits.dmlStatements().remaining() > targetRemaining)
		{
			DML_Builder.newTransaction().withSystemMode().doUpdate(budgetConsumer).execute();
		}
	}

	/**
	 * @description Builds a ChainExecutor for a test to call directly, carrying the counting onError handler, for the
	 * stall tests that check how often the notification fires.
	 *
	 * @param executionId The execution record ID.
	 * @param runKey The run key the job got when it was queued, or null for an old row.
	 *
	 * @return The configured executor.
	 */
	private static UTIL_AsyncChain.ChainExecutor buildExecutorWithStallHandler(Id executionId, String runKey)
	{
		return new UTIL_AsyncChain.ChainExecutor
				(
						executionId, 0, 50, 32768,
						buildDtoStepDefinition(CountingErrorHandlerStep.class.getName(), 'CountingErrorHandler'),
						null, createAsyncOptions(2), runKey
				);
	}

	/**
	 * @description Step that succeeds and increments a stepCount in context.
	 */
	public class SuccessStep extends UTIL_AsyncChain.ChainStep
	{
		/**
		 * @description Increments the stepCount context entry, starting from zero when absent, and succeeds.
		 *
		 * @param context The shared chain context.
		 *
		 * @return A succeeded result.
		 */
		public override UTIL_AsyncChain.StepResult work(UTIL_AsyncChain.ChainContext context)
		{
			Integer count = context.has('stepCount') ? (Integer)context.get('stepCount') : 0;
			context.put('stepCount', count + 1);
			return UTIL_AsyncChain.succeeded('Step completed');
		}
	}

	/**
	 * @description Step that always returns a failed result.
	 */
	public class FailingStep extends UTIL_AsyncChain.ChainStep
	{
		/**
		 * @description Fails on every call.
		 *
		 * @param context The shared chain context; unused.
		 *
		 * @return A failed result.
		 */
		public override UTIL_AsyncChain.StepResult work(UTIL_AsyncChain.ChainContext context)
		{
			return UTIL_AsyncChain.failed('Deliberate failure');
		}
	}

	/**
	 * @description Step that counts its attempts and always fails, with no retry strategy. The upgrade
	 * test uses it to prove a step log saved before the upgrade takes the path with a single attempt.
	 */
	public class CountingFailingStep extends UTIL_AsyncChain.ChainStep
	{
		/**
		 * @description Increments failingStepRunCount so the test can count attempts, then fails.
		 *
		 * @param context The shared chain context; unused.
		 *
		 * @return A failed result.
		 */
		public override UTIL_AsyncChain.StepResult work(UTIL_AsyncChain.ChainContext context)
		{
			failingStepRunCount++;
			return UTIL_AsyncChain.failed('Deliberate pre-upgrade failure');
		}
	}

	/**
	 * @description Step that writes a payload larger than the ContextData__c field capacity into
	 * the context and then fails. So handleStepFailure's final save runs with a context that can no
	 * longer be stored whole.
	 */
	public class ContextBloatingFailingStep extends UTIL_AsyncChain.ChainStep
	{
		/**
		 * @description Writes a payload OVERSIZED_CONTEXT_PAYLOAD_LENGTH characters long into the context, then fails with OVERSIZED_CONTEXT_FAILURE_MESSAGE.
		 *
		 * @param context The shared chain context.
		 *
		 * @return A failed result.
		 */
		public override UTIL_AsyncChain.StepResult work(UTIL_AsyncChain.ChainContext context)
		{
			context.put(OVERSIZED_CONTEXT_PAYLOAD_KEY, 'x'.repeat(OVERSIZED_CONTEXT_PAYLOAD_LENGTH));
			return UTIL_AsyncChain.failed(OVERSIZED_CONTEXT_FAILURE_MESSAGE);
		}
	}

	/**
	 * @description Step that writes a payload larger than the ContextData__c field capacity into
	 * the context and then fails with a message already at the ErrorMessage__c field capacity, so
	 * the context-not-kept marker survives only if the save after a failure keeps room for it.
	 */
	public class ContextBloatingCapacityMessageStep extends UTIL_AsyncChain.ChainStep
	{
		/**
		 * @description Writes a payload OVERSIZED_CONTEXT_PAYLOAD_LENGTH characters long into the context, then fails with a message
		 * exactly ERROR_MESSAGE_FIELD_CAPACITY characters long.
		 *
		 * @param context The shared chain context.
		 *
		 * @return A failed result.
		 */
		public override UTIL_AsyncChain.StepResult work(UTIL_AsyncChain.ChainContext context)
		{
			context.put(OVERSIZED_CONTEXT_PAYLOAD_KEY, 'x'.repeat(OVERSIZED_CONTEXT_PAYLOAD_LENGTH));
			return UTIL_AsyncChain.failed('m'.repeat(ERROR_MESSAGE_FIELD_CAPACITY));
		}
	}

	/**
	 * @description Step that writes a payload larger than the ContextData__c field capacity into
	 * the context and then fails with a BLANK message, so the save after a failure has no message to
	 * put before the context-not-kept marker.
	 */
	public class ContextBloatingBlankMessageStep extends UTIL_AsyncChain.ChainStep
	{
		/**
		 * @description Writes a payload OVERSIZED_CONTEXT_PAYLOAD_LENGTH characters long into the context, then fails with an empty message.
		 *
		 * @param context The shared chain context.
		 *
		 * @return A failed result.
		 */
		public override UTIL_AsyncChain.StepResult work(UTIL_AsyncChain.ChainContext context)
		{
			context.put(OVERSIZED_CONTEXT_PAYLOAD_KEY, 'x'.repeat(OVERSIZED_CONTEXT_PAYLOAD_LENGTH));
			return UTIL_AsyncChain.failed(UTIL_String.EMPTY);
		}
	}

	/**
	 * @description Step that sets a tracking flag in context.
	 */
	public class TrackingStep extends UTIL_AsyncChain.ChainStep
	{
		/**
		 * @description Writes the trackingStepExecuted flag into the context and succeeds.
		 *
		 * @param context The shared chain context.
		 *
		 * @return A succeeded result.
		 */
		public override UTIL_AsyncChain.StepResult work(UTIL_AsyncChain.ChainContext context)
		{
			context.put('trackingStepExecuted', true);
			return UTIL_AsyncChain.succeeded('Tracked');
		}
	}

	/**
	 * @description Error handler step that sets a tracking flag in context.
	 */
	public class ErrorHandlerStep extends UTIL_AsyncChain.ChainStep
	{
		/**
		 * @description Writes the errorHandlerExecuted flag into the context and succeeds.
		 *
		 * @param context The shared chain context.
		 *
		 * @return A succeeded result.
		 */
		public override UTIL_AsyncChain.StepResult work(UTIL_AsyncChain.ChainContext context)
		{
			context.put('errorHandlerExecuted', true);
			return UTIL_AsyncChain.succeeded('Error handled');
		}
	}

	/**
	 * @description Error handler step that counts its runs, proving the stall notification fires
	 * exactly once each time the chain moves into Stalled.
	 */
	public class CountingErrorHandlerStep extends UTIL_AsyncChain.ChainStep
	{
		/**
		 * @description Increments errorHandlerRunCount, writes the errorHandlerExecuted flag into the context and succeeds.
		 *
		 * @param context The shared chain context.
		 *
		 * @return A succeeded result.
		 */
		public override UTIL_AsyncChain.StepResult work(UTIL_AsyncChain.ChainContext context)
		{
			errorHandlerRunCount++;
			context.put('errorHandlerExecuted', true);
			return UTIL_AsyncChain.succeeded('Stall handled');
		}
	}

	/**
	 * @description Completion handler step that sets a tracking flag in context.
	 */
	public class CompletionHandlerStep extends UTIL_AsyncChain.ChainStep
	{
		/**
		 * @description Writes the completionHandlerExecuted flag into the context and succeeds.
		 *
		 * @param context The shared chain context.
		 *
		 * @return A succeeded result.
		 */
		public override UTIL_AsyncChain.StepResult work(UTIL_AsyncChain.ChainContext context)
		{
			context.put('completionHandlerExecuted', true);
			return UTIL_AsyncChain.succeeded('Completion handled');
		}
	}

	/**
	 * @description Error handler that itself throws.
	 */
	public class FailingErrorHandlerStep extends UTIL_AsyncChain.ChainStep
	{
		/**
		 * @description Throws an IllegalStateException so the chain's error handler itself fails.
		 *
		 * @param context The shared chain context; unused.
		 *
		 * @return Never; every call throws instead.
		 *
		 * @throws UTIL_Exceptions.IllegalStateException On every call.
		 */
		public override UTIL_AsyncChain.StepResult work(UTIL_AsyncChain.ChainContext context)
		{
			throw new UTIL_Exceptions.IllegalStateException('Error handler failed');
		}
	}

	/**
	 * @description Step that sets a new run key on the execution record during the chain and succeeds.
	 * It acts like something else (a watchdog re-drive) taking over the chain while this job is still
	 * running.
	 */
	public class RotateRunKeyStep extends UTIL_AsyncChain.ChainStep
	{
		/**
		 * @description Sets a new run key on the execution record through rotateRunKey, then succeeds.
		 *
		 * @param context The shared chain context.
		 *
		 * @return A succeeded result.
		 */
		public override UTIL_AsyncChain.StepResult work(UTIL_AsyncChain.ChainContext context)
		{
			rotateRunKey(context);
			return UTIL_AsyncChain.succeeded();
		}
	}

	/**
	 * @description Step that counts its runs, sets a new run key on the execution record and succeeds. Because the run
	 * key changed, the engine refuses its job's progress save. So the record keeps the step's start and never receives
	 * its result. A job leaves the same shape when the platform ends it between the step's work and the save. The
	 * started-step sweep tests count its runs to prove the watchdog never ran it again.
	 */
	public class CountingRotateRunKeyStep extends UTIL_AsyncChain.ChainStep
	{
		/**
		 * @description Increments rotatingStepRunCount, sets a new run key through rotateRunKey, then succeeds.
		 *
		 * @param context The shared chain context.
		 *
		 * @return A succeeded result.
		 */
		public override UTIL_AsyncChain.StepResult work(UTIL_AsyncChain.ChainContext context)
		{
			rotatingStepRunCount++;
			rotateRunKey(context);
			return UTIL_AsyncChain.succeeded();
		}
	}

	/**
	 * @description Step that reads its own entry in the saved step log while its work runs, and keeps the started
	 * marker it saw in the context under START_SEEN_KEY_PREFIX plus its index, so a test can prove the start was saved
	 * before the work ran.
	 */
	public class StartObservingStep extends UTIL_AsyncChain.ChainStep
	{
		/**
		 * @description Reads the execution record, records this step's saved started marker in the context, and succeeds.
		 *
		 * @param context The shared chain context.
		 *
		 * @return A succeeded result.
		 */
		public override UTIL_AsyncChain.StepResult work(UTIL_AsyncChain.ChainContext context)
		{
			AsyncChainExecution__c persisted = (AsyncChainExecution__c)new SEL_AsyncChainExecution().findById(context.getChainExecutionId());
			List<UTIL_AsyncChain.DTO_StepDefinition> entries = (List<UTIL_AsyncChain.DTO_StepDefinition>)
					JSON.deserialize(persisted.StepLog__c, List<UTIL_AsyncChain.DTO_StepDefinition>.class);
			context.put(START_SEEN_KEY_PREFIX + context.getCurrentStepIndex(), entries[context.getCurrentStepIndex()].started);
			return UTIL_AsyncChain.succeeded();
		}
	}

	/**
	 * @description Step that sets a new run key on the execution record and then fails. So the
	 * step-failure save runs while the job's run key is already old.
	 */
	public class RotateAndFailStep extends UTIL_AsyncChain.ChainStep
	{
		/**
		 * @description Sets a new run key on the execution record through rotateRunKey, then fails.
		 *
		 * @param context The shared chain context.
		 *
		 * @return A failed result.
		 */
		public override UTIL_AsyncChain.StepResult work(UTIL_AsyncChain.ChainContext context)
		{
			rotateRunKey(context);
			return UTIL_AsyncChain.failed('Deliberate failure after key rotation');
		}
	}

	/**
	 * @description Step that sets a new run key on the execution record and then fails, under a
	 * strategy of one retry with no wait. So the retry save runs while the job's run key is
	 * already old.
	 */
	public class RotateAndFailWithRetryStep extends UTIL_AsyncChain.ChainStep
	{
		/**
		 * @description Sets a new run key on the execution record through rotateRunKey, then fails, so the retry save runs with the old key.
		 *
		 * @param context The shared chain context.
		 *
		 * @return A failed result.
		 */
		public override UTIL_AsyncChain.StepResult work(UTIL_AsyncChain.ChainContext context)
		{
			rotateRunKey(context);
			return UTIL_AsyncChain.failed('Deliberate failure after key rotation');
		}

		/**
		 * @description Counts the call in retryStrategyConsultCount and allows a single retry with no wait.
		 *
		 * @return An exponential strategy capped at one retry with a zero base backoff.
		 */
		public override UTIL_Retry.Strategy createRetryStrategy()
		{
			retryStrategyConsultCount++;
			return UTIL_Retry.exponential().withMaxRetries(1).withBaseBackoff(0);
		}
	}

	/**
	 * @description Step that fails on every attempt, under a strategy of one retry with no wait, for
	 * the test of a stall when the retry cannot be queued. The first failure schedules a retry, and the
	 * simulated queue failure then stalls the chain with the pending retry's markers already saved.
	 */
	public class FailingWithRetryStep extends UTIL_AsyncChain.ChainStep
	{
		/**
		 * @description Fails on every attempt.
		 *
		 * @param context The shared chain context; unused.
		 *
		 * @return A failed result.
		 */
		public override UTIL_AsyncChain.StepResult work(UTIL_AsyncChain.ChainContext context)
		{
			return UTIL_AsyncChain.failed('Deliberate retryable failure');
		}

		/**
		 * @description Allows a single retry with no backoff, so the first failure schedules a retry straight away.
		 *
		 * @return An exponential strategy capped at one retry with a zero base backoff.
		 */
		public override UTIL_Retry.Strategy createRetryStrategy()
		{
			return UTIL_Retry.exponential().withMaxRetries(1).withBaseBackoff(0);
		}
	}

	/**
	 * @description Step that the successful operator retry runs again. It declares itself idempotent
	 * the way a subscriber writes it (an isIdempotent() override, no constructor), and succeeds while
	 * counting its runs, so the tests can prove exactly the failed step ran again.
	 */
	public class IdempotentRecoveringStep extends UTIL_AsyncChain.ChainStep
	{
		/**
		 * @description Declares the step safe to run again, the way a subscriber allows the Chain
		 * Monitor's retry action for a step. The job creates the step from its class name in the saved
		 * step log, which is exactly the run-time path under test.
		 *
		 * @return True.
		 */
		public override Boolean isIdempotent()
		{
			return true;
		}

		/**
		 * @description Increments retriedStepRunCount so the test can prove the step ran again, then succeeds.
		 *
		 * @param context The shared chain context; unused.
		 *
		 * @return A succeeded result.
		 */
		public override UTIL_AsyncChain.StepResult work(UTIL_AsyncChain.ChainContext context)
		{
			retriedStepRunCount++;
			return UTIL_AsyncChain.succeeded('Recovered');
		}
	}

	/**
	 * @description Step that declares itself safe to run again and fails on every call, so a chain ends Failed on a step the
	 * Chain Monitor may offer to retry.
	 */
	public class IdempotentFailingStep extends UTIL_AsyncChain.ChainStep
	{
		/**
		 * @description Declares the step safe to run again.
		 *
		 * @return True.
		 */
		public override Boolean isIdempotent()
		{
			return true;
		}

		/**
		 * @description Fails on every call with IDEMPOTENT_FAILURE_MESSAGE.
		 *
		 * @param context The shared chain context; unused.
		 *
		 * @return A failed result.
		 */
		public override UTIL_AsyncChain.StepResult work(UTIL_AsyncChain.ChainContext context)
		{
			return UTIL_AsyncChain.failed(IDEMPOTENT_FAILURE_MESSAGE);
		}
	}

	/**
	 * @description Sets a new run key on the execution record behind the given context. It acts like something else
	 * taking over the chain while the current job is still running.
	 *
	 * @param context The chain context carrying the execution record ID.
	 */
	private static void rotateRunKey(UTIL_AsyncChain.ChainContext context)
	{
		AsyncChainExecution__c row = (AsyncChainExecution__c)TST_Builder.of(AsyncChainExecution__c.SObjectType)
				.withOverride(AsyncChainExecution__c.Id, (Id)context.getChainExecutionId())
				.withOverride(AsyncChainExecution__c.RunKey__c, UTIL_Random.randomUUID())
				.withOptionalField(AsyncChainExecution__c.ChainName__c)
				.withoutInsertion()
				.build();
		DML_Builder.newTransaction().systemModeInternal().doUpdate(row).execute();
	}

	/**
	 * @description Step that sets its own execution record to Aborted with direct DML and succeeds.
	 * It acts like an abort saved from outside during the step, while the job is still running. The
	 * run key is untouched, so the job still passes the run key check. Only a save that writes just the
	 * changed fields keeps the abort in place when the step ends.
	 */
	public class ExternalAbortStep extends UTIL_AsyncChain.ChainStep
	{
		/**
		 * @description Sets the execution record to Aborted through flipToAborted (an end time, the OperatorAbort category
		 * and a system-mode update), then succeeds.
		 *
		 * @param context The shared chain context.
		 *
		 * @return A succeeded result.
		 */
		public override UTIL_AsyncChain.StepResult work(UTIL_AsyncChain.ChainContext context)
		{
			flipToAborted((Id)context.getChainExecutionId());
			return UTIL_AsyncChain.succeeded();
		}
	}

	/**
	 * @description Step that sets its own execution record to Aborted with direct DML and then
	 * throws. So the failure save runs while the saved abort is already on the row. The run key is
	 * untouched, so the job still passes the run key check. Only the refusal keeps the abort in place
	 * through the failure save.
	 */
	public class AbortThenThrowStep extends UTIL_AsyncChain.ChainStep
	{
		/**
		 * @description Sets the execution record to Aborted through flipToAborted (an end time, the OperatorAbort category
		 * and a system-mode update), then throws an IllegalArgumentException.
		 *
		 * @param context The shared chain context.
		 *
		 * @return Never; every call throws instead.
		 *
		 * @throws IllegalArgumentException On every call, once the abort is committed.
		 */
		public override UTIL_AsyncChain.StepResult work(UTIL_AsyncChain.ChainContext context)
		{
			flipToAborted((Id)context.getChainExecutionId());
			throw new IllegalArgumentException('Post-abort step failure');
		}
	}

	/**
	 * @description Handler step that writes a marker the test can see onto its execution record,
	 * through its own DML. The test of the run key check when a handler starts looks for this marker.
	 * It is saved with the handler's work, apart from the framework's status save. So a missing marker
	 * proves the work never ran, not only that a later status save was blocked.
	 */
	public class HandlerSideEffectStep extends UTIL_AsyncChain.ChainStep
	{
		/**
		 * @description Writes HANDLER_SIDE_EFFECT_MARKER into the execution record's CurrentStepName__c through a system-mode update, then succeeds.
		 *
		 * @param context The shared chain context.
		 *
		 * @return A succeeded result.
		 */
		public override UTIL_AsyncChain.StepResult work(UTIL_AsyncChain.ChainContext context)
		{
			AsyncChainExecution__c row = (AsyncChainExecution__c)TST_Builder.of(AsyncChainExecution__c.SObjectType)
					.withOverride(AsyncChainExecution__c.Id, (Id)context.getChainExecutionId())
					.withOverride(AsyncChainExecution__c.CurrentStepName__c, HANDLER_SIDE_EFFECT_MARKER)
					.withOptionalField(AsyncChainExecution__c.ChainName__c)
					.withoutInsertion()
					.build();
			DML_Builder.newTransaction().systemModeInternal().doUpdate(row).execute();
			return UTIL_AsyncChain.succeeded();
		}
	}

	/**
	 * @description Very small Queueable whose only purpose is to use up one Queueable job, so the
	 * limit tests can bring the transaction's Queueable jobs left down to zero through the real
	 * platform counters. A test class this small needs no Finalizer.
	 */
	@SuppressWarnings('PMD.EmptyStatementBlock,PMD.QueueableWithoutFinalizer')
	private class BudgetConsumingQueueable implements Queueable
	{
		/**
		 * @description Does no work: queuing the job is what uses up the Queueable job under test.
		 *
		 * @param context The queueable context supplied by the platform.
		 */
		public void execute(QueueableContext context)
		{
			// Queuing the job is all that is needed: the limit tests only need the job used up.
		}
	}

	/**
	 * @description Retrieves the committed test admin user set up in @TestSetup for use with
	 * System.runAs, so each test body runs with a fresh permission-evaluation context.
	 *
	 * @return The test admin User record.
	 */
	private static User getTestAdmin()
	{
		return new SEL_User().findByCompanyName(TEST_ADMIN_COMPANY);
	}
}