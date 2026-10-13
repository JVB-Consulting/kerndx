// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Tests for the list of status moves the engine allows a chain run, in UTIL_AsyncChain. A run event is one
 * thing that can happen to a run: a step completes, the watchdog marks it Stalled, an operator aborts it, and so on. The
 * tests cover the 78 moves of the run event table (thirteen run events from each of six statuses), written out by hand
 * and checked against isAllowedRunTransition. The trigger backstop (TRG_AsyncChainRunTransition, the trigger action that
 * checks every saved run) uses that check, and it sees only the status before and the status after. Some refused moves
 * go between the same two statuses as a move another run event may make, so that check cannot refuse them; the real
 * writers (the Finalizer, the executor and the handler) prove those. The tests also cover: the Delayed rule; the failure
 * category and end time a finished chain keeps when its handler fails or crashes; the handler note a finished chain
 * keeps when its handler could not be queued, in every length case the message field allows; the stall category a
 * watchdog re-drive (a new start of a stuck run) clears; the completion a slow executor lands on a run the watchdog
 * marked Stalled; the degrade (ending a stuck run Failed) and re-drive the watchdog sweep refuses over a run another
 * actor ended; and the operator abort refused over a run already Aborted. Then the trigger backstop, through the real
 * trigger: every (from, to) pair of statuses written
 * straight to the database, where the pairs the engine makes land and every other pair is refused with the label's
 * text; a changed end time refused; the Stalled-with-an-end-time shape refused; a write that keeps the same status
 * let through; and the one case where the backstop refuses the engine's own write because the row moved between the
 * engine's read and its write, which the engine logs and answers with false.
 *
 * @see UTIL_AsyncChain
 * @see UTIL_AsyncChainRecovery_TEST
 *
 * @author Jason van Beukering
 *
 * @group Async
 *
 * @date October 2026
 */
@IsTest(seeAllData=false isParallel=false)
@SuppressWarnings('PMD.CyclomaticComplexity,PMD.ApexUnitTestClassShouldHaveRunAs,PMD.ExcessiveParameterList,PMD.ApexUnitTestClassShouldHaveAsserts,PMD.NcssTypeCount')
private class UTIL_AsyncChainTransition_TEST
{
	/**
	 * @description Company name given to the admin user created in test setup, so getTestAdmin can find that one user
	 * again by company name.
	 */
	private static final String TEST_ADMIN_COMPANY = 'UTIL_AsyncChainTransition_TEST-admin';

	/**
	 * @description Name used for the test chains.
	 */
	private static final String TEST_CHAIN_NAME = 'TransitionTestChain';

	/**
	 * @description Marks a move of the run event table that the status pair check (isAllowedRunTransition, which sees only
	 * the status before and the status after) decides on its own: an allowed move, or a refused move whose two statuses no
	 * other run event moves between.
	 */
	private static final String DRIVER_STATUS_PAIR_CHECK = 'STATUS_PAIR_CHECK';

	/**
	 * @description Marks a refused move of the run event table that goes between the same two statuses as a move another
	 * run event may make. The status pair check cannot refuse it, so only the real writer can prove the refusal; a test
	 * that runs that writer does.
	 */
	private static final String DRIVER_WRITER = 'WRITER';

	/**
	 * @description The reserved run status the engine never writes. The value is the picklist's own; the selector keeps
	 * no constant for it because no code path reads or writes it.
	 */
	private static final String STATUS_DELAYED = 'Delayed';

	/**
	 * @description How many moves of the hand-written run event table the status pair check decides: every allowed move
	 * and every refused move whose two statuses no other run event moves between.
	 */
	private static final Integer STATUS_PAIR_CHECK_MOVE_COUNT = 60;

	/**
	 * @description How many moves the hand-written run event table carries: thirteen run events times six statuses.
	 */
	private static final Integer RUN_EVENT_MOVE_COUNT = 78;

	/**
	 * @description How many refused moves only the real writer can prove.
	 */
	private static final Integer WRITER_PROVED_MOVE_COUNT = 18;

	/**
	 * @description Run event name: a step result that ends the chain well.
	 */
	private static final String RUN_EVENT_STEP_COMPLETED = 'STEP_COMPLETED';

	/**
	 * @description Run event name: a step result that ends the chain Failed.
	 */
	private static final String RUN_EVENT_STEP_FAILED = 'STEP_FAILED';

	/**
	 * @description Run event name: the Finalizer finds the executor's job crashed.
	 */
	private static final String RUN_EVENT_QUEUEABLE_CRASHED = 'QUEUEABLE_CRASHED';

	/**
	 * @description Run event name: the Finalizer could not queue the next step or the retry link.
	 */
	private static final String RUN_EVENT_ENQUEUE_FAILED = 'ENQUEUE_FAILED';

	/**
	 * @description Run event name: the Finalizer could not queue the completion or error handler.
	 */
	private static final String RUN_EVENT_HANDLER_NOT_QUEUED = 'HANDLER_NOT_QUEUED';

	/**
	 * @description Run event name: a handler ran and succeeded.
	 */
	private static final String RUN_EVENT_HANDLER_SUCCEEDED = 'HANDLER_SUCCEEDED';

	/**
	 * @description Run event name: a handler ran and failed.
	 */
	private static final String RUN_EVENT_HANDLER_FAILED = 'HANDLER_FAILED';

	/**
	 * @description Run event name: the watchdog marks a run Stalled.
	 */
	private static final String RUN_EVENT_WATCHDOG_STALLED = 'WATCHDOG_STALLED';

	/**
	 * @description Run event name: the watchdog drives a stalled run again.
	 */
	private static final String RUN_EVENT_WATCHDOG_REDRIVEN = 'WATCHDOG_REDRIVEN';

	/**
	 * @description Run event name: the watchdog ends a run it cannot recover.
	 */
	private static final String RUN_EVENT_RECOVERY_DEGRADED = 'RECOVERY_DEGRADED';

	/**
	 * @description Run event name: the kill switch aborts a run.
	 */
	private static final String RUN_EVENT_KILL_SWITCH_ABORTED = 'KILL_SWITCH_ABORTED';

	/**
	 * @description Run event name: an operator aborts a run.
	 */
	private static final String RUN_EVENT_OPERATOR_ABORTED = 'OPERATOR_ABORTED';

	/**
	 * @description Run event name: an operator retries a failed run from its failed step.
	 */
	private static final String RUN_EVENT_OPERATOR_RETRIED = 'OPERATOR_RETRIED';

	/**
	 * @description Start of the error log the transition function writes when it refuses a run event itself, for either of
	 * two reasons: the list of allowed moves does not permit the run event from the run's status, or the write would break
	 * a rule a row must meet in its status. The third kind of refusal, the trigger backstop's, starts with other words
	 * (BACKSTOP_REFUSAL_LOG_FRAGMENT), so this fragment never matches it.
	 */
	private static final String REFUSAL_LOG_FRAGMENT = 'Chain run transition refused:';

	/**
	 * @description LogLevel__c literal of an error entry.
	 */
	private static final String LOG_LEVEL_ERROR = LoggingLevel.ERROR.name();

	/**
	 * @description LogLevel__c literal of a warning entry.
	 */
	private static final String LOG_LEVEL_WARN = LoggingLevel.WARN.name();

	/**
	 * @description Fragment of the warning the transition function writes when the run's fresh key is not the one the
	 * caller captured.
	 */
	private static final String STALE_KEY_LOG_FRAGMENT = 'stale run key (fenced)';

	/**
	 * @description Independent oracle for the note a finished chain keeps when its handler could not be queued: {0} is
	 * the handler's position (onError or onComplete), {1} the handler's name.
	 */
	private static final String HANDLER_NOT_QUEUED_NOTE_FORMAT = System.Label.AsyncChain_HandlerNotQueued;

	/**
	 * @description Position name of an error handler, as the engine names it in the note.
	 */
	private static final String ERROR_HANDLER_POSITION = 'onError';

	/**
	 * @description Position name of a completion handler, as the engine names it in the note.
	 */
	private static final String COMPLETION_HANDLER_POSITION = 'onComplete';

	/**
	 * @description Separator the engine puts between a row's existing message and the handler note.
	 */
	private static final String NOTE_SEPARATOR = '; ';

	/**
	 * @description Separator the engine puts between the handler note and the platform's reason.
	 */
	private static final String REASON_SEPARATOR = ': ';

	/**
	 * @description Independent oracle for the reason the engine reports when a test asks it to simulate a handler enqueue
	 * failure.
	 */
	private static final String SIMULATED_HANDLER_ENQUEUE_FAILURE = 'Simulated handler enqueue failure';

	/**
	 * @description Independent oracle for the three characters an abbreviated text ends with.
	 */
	private static final String ELLIPSIS = '...';

	/**
	 * @description Character the long messages and the long handler name are made of.
	 */
	private static final String FILLER_CHARACTER = 'x';

	/**
	 * @description Independent oracle for the longest message ErrorMessage__c stores, read from the field itself.
	 */
	private static final Integer ERROR_MESSAGE_FIELD_LENGTH = AsyncChainExecution__c.ErrorMessage__c.getDescribe().getLength();

	/**
	 * @description Stall reason handed to the Finalizer's direct calls.
	 */
	private static final String TRANSIENT_ENQUEUE_FAILURE = 'Transient enqueue failure';

	/**
	 * @description Crash reason handed to the Finalizer's direct calls.
	 */
	private static final String SIMULATED_CRASH_REASON = 'Queueable crashed (unhandled exception): simulated';

	/**
	 * @description Name of the counting error handler as a chain step.
	 */
	private static final String COUNTING_ERROR_HANDLER_STEP_NAME = 'CountingErrorHandler';

	/**
	 * @description Name of the failing error handler as a chain step.
	 */
	private static final String FAILING_ERROR_HANDLER_STEP_NAME = 'FailingErrorHandler';

	/**
	 * @description How many minutes in the past a seeded completion stamp is put, so a write that re-stamps the end time
	 * with the present is told apart from one that keeps it: a stored stamp at least this old can only be the seeded one.
	 */
	private static final Integer STAMP_AGE_MINUTES = 5;

	/**
	 * @description Crash reason handed to the handler Finalizer's direct calls.
	 */
	private static final String HANDLER_CRASH_REASON = 'Handler crashed: simulated';

	/**
	 * @description The step failure an error handler built directly is told it runs for.
	 */
	private static final String ORIGINAL_FAILURE_REASON = 'Original step failure';

	/**
	 * @description Independent oracle for the reason the kill switch records on a run it aborts.
	 */
	private static final String KILL_SWITCH_ABORT_REASON = 'Kill switch active';

	/**
	 * @description Start of the message the retrying step fails with; the attempt number follows it.
	 */
	private static final String RETRY_STEP_FAILURE_PREFIX = 'Permanent failure, attempt ';

	/**
	 * @description The attempt on which the retrying step's single retry is used up.
	 */
	private static final Integer EXHAUSTED_ATTEMPT = 2;

	/**
	 * @description Independent oracle for the text the engine puts in front of a failed handler's own reason.
	 */
	private static final String HANDLER_FAILURE_PREFIX = 'Handler failed: ';

	/**
	 * @description Reason the failing error handler throws with.
	 */
	private static final String ERROR_HANDLER_FAILURE_REASON = 'Error handler failed';

	/**
	 * @description Reason the failing completion handler throws with.
	 */
	private static final String COMPLETION_HANDLER_FAILURE_REASON = 'Completion handler failed';

	/**
	 * @description Context key the counting error handler marks when it runs, so a refused write-back is told apart from
	 * a handler that never ran: the marker is in the handler's context but never reaches the row.
	 */
	private static final String HANDLER_RAN_CONTEXT_KEY = 'errorHandlerExecuted';

	/**
	 * @description The refusal reason the function writes when a write would leave a Failed or Aborted run without a
	 * failure category. The test checks that the error log carries it.
	 */
	private static final String MISSING_FAILURE_CATEGORY_REASON = 'a Failed or Aborted run must have a failure category';

	/**
	 * @description The refusal reason the function writes when a write would leave a Running run with an end time or a
	 * failure category. The test checks that the error log carries it.
	 */
	private static final String RUNNING_WITH_END_TIME_REASON = 'a Running run must have no end time and no failure category';

	/**
	 * @description The start of the error log the Finalizer writes when its handler note fails to save for a reason other
	 * than a refused transition, in place of throwing.
	 */
	private static final String HANDLER_NOTE_WRITE_FAILED_LOG_FRAGMENT = 'Finalizer handler note DML failed:';

	/**
	 * @description Staleness threshold that makes every run a watchdog candidate: a negative number of minutes puts the
	 * cutoff in the future.
	 */
	private static final Integer SWEEP_EVERYTHING_THRESHOLD_MINUTES = -1;

	/**
	 * @description The batch size handed to the watchdog sweep.
	 */
	private static final Integer WATCHDOG_BATCH_SIZE = 50;

	/**
	 * @description Platform status of a mocked executor job the watchdog's liveness probe reads as dead.
	 */
	private static final String DEAD_JOB_STATUS = 'Aborted';

	/**
	 * @description Reason handed to the operator abort.
	 */
	private static final String OPERATOR_ABORT_REASON = 'Aborted by an operator';

	/**
	 * @description Step count of a mid-chain re-drive candidate: one completed, one still to run.
	 */
	private static final Integer MID_CHAIN_TOTAL_STEPS = 2;

	/**
	 * @description Completed step count of a mid-chain re-drive candidate.
	 */
	private static final Integer MID_CHAIN_COMPLETED_STEPS = 1;

	/**
	 * @description Step count of a run with one step.
	 */
	private static final Integer SINGLE_STEP_TOTAL_STEPS = 1;

	/**
	 * @description Persisted context of a seeded run that carries no values.
	 */
	private static final String EMPTY_CONTEXT_JSON = JSON.serialize(new Map<String, Object>());

	/**
	 * @description Display name of the success step in a hand-built step log.
	 */
	private static final String SUCCESS_STEP_NAME = 'SuccessStep';

	/**
	 * @description The step cap a directly built executor runs under.
	 */
	private static final Integer EXECUTOR_MAX_STEPS = 50;

	/**
	 * @description The context size cap a directly built executor runs under.
	 */
	private static final Integer EXECUTOR_MAX_CONTEXT_SIZE = 32768;

	/**
	 * @description Start of the error log the transition function writes when the trigger backstop refuses the
	 * function's own write, because another writer moved the row between the function's fresh read and its write.
	 */
	private static final String BACKSTOP_REFUSAL_LOG_FRAGMENT = 'Chain run transition refused by the backstop:';

	/**
	 * @description Start of the error log the Finalizer writes when its write fails for a reason the transition function
	 * does not handle itself.
	 */
	private static final String FINALIZER_DML_FAILED_FRAGMENT = 'Finalizer DML failed';

	/**
	 * @description How many rows the hand-written (from, to) table carries: six statuses times six statuses.
	 */
	private static final Integer STATUS_PAIR_COUNT = 36;

	/**
	 * @description How many rows of the (from, to) table start from one status: one per target status.
	 */
	private static final Integer PAIRS_PER_STARTING_STATUS = 6;

	/**
	 * @description A message written on a Failed row together with its unchanged status, to prove the write lands.
	 */
	private static final String CHANGED_MESSAGE = 'A message the row did not carry before';

	/**
	 * @description How many minutes later than the stored end time a refused second end time sits.
	 */
	private static final Integer LATER_END_TIME_OFFSET_MINUTES = 5;

	/**
	 * @description The three statuses of a run that has finished. A row in one of them has an end time.
	 */
	private static final Set<String> FINISHED_STATUSES = new Set<String>
	{
			SEL_AsyncChainExecution.STATUS_COMPLETED,
			SEL_AsyncChainExecution.STATUS_FAILED,
			SEL_AsyncChainExecution.STATUS_ABORTED
	};

	/**
	 * @description The failure category a row carries in each status that needs one, so a write into that status
	 * differs from a fitting row only by the status itself. Running, Completed and Delayed carry none.
	 */
	private static final Map<String, String> FAILURE_CATEGORY_BY_STATUS = new Map<String, String>
	{
			SEL_AsyncChainExecution.STATUS_STALLED => SEL_AsyncChainExecution.FAILURE_CATEGORY_STALLED,
			SEL_AsyncChainExecution.STATUS_FAILED => SEL_AsyncChainExecution.FAILURE_CATEGORY_STEP_EXCEPTION,
			SEL_AsyncChainExecution.STATUS_ABORTED => SEL_AsyncChainExecution.FAILURE_CATEGORY_OPERATOR_ABORT
	};

	/**
	 * @description Message the configurable failing step fails with; each test sets it before launching its chain.
	 */
	private static String configuredFailureMessage;

	/**
	 * @description How many times the counting error handler ran; every test here expects zero.
	 */
	private static Integer errorHandlerRunCount = 0;

	/**
	 * @description How many times the counting completion handler ran; every test here expects zero.
	 */
	private static Integer completionHandlerRunCount = 0;

	/**
	 * @description Status the moving steps put their own run at before returning, as another actor committing mid-work
	 * would; each test sets it before launching its chain.
	 */
	private static String movedRunStatus;

	/**
	 * @description Failure category the moving steps write with movedRunStatus, or null.
	 */
	private static String movedRunFailureCategory;

	/**
	 * @description Creates a dedicated test admin user so System.runAs in each test starts a fresh permission-evaluation
	 * context.
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
	 * @description Every move of the run event table that the status pair check decides on its own answers as the
	 * hand-written table says. An allowed move is legal for its (from, target) pair. A refused move whose two statuses no
	 * other run event moves between is illegal. The eighteen refused moves that share their two statuses with an allowed
	 * move are proved by the tests that run the real writer.
	 */
	@IsTest
	private static void shouldDecideEveryStatusPairMoveAsTheHandWrittenTableSays()
	{
		Integer statusPairMoves = 0;
		for(ExpectedRunEventMove move : buildExpectedRunEventMoves())
		{
			if(move.driver != DRIVER_STATUS_PAIR_CHECK)
			{
				continue;
			}
			statusPairMoves++;
			String target = move.targetStatus ?? move.fromStatus;
			Assert.areEqual(move.allowed, UTIL_AsyncChain.isAllowedRunTransition(move.fromStatus, target),
					'Expected ' + move.runEvent + ' from ' + move.fromStatus + ' to ' + target + ' to be ' + (move.allowed ? 'legal' : 'refused'));
		}
		Assert.areEqual(STATUS_PAIR_CHECK_MOVE_COUNT, statusPairMoves,
				'Expected the hand-written table to carry ' + STATUS_PAIR_CHECK_MOVE_COUNT + ' moves the status pair check decides, got ' + statusPairMoves);
	}

	/**
	 * @description The hand-written table carries every move: thirteen run events times six statuses, eighteen of them
	 * proved by a real writer, so a row cannot be dropped quietly.
	 */
	@IsTest
	private static void shouldCarrySeventyEightMovesWithEighteenProvedByARealWriter()
	{
		Integer writerProvedMoves = 0;
		for(ExpectedRunEventMove move : buildExpectedRunEventMoves())
		{
			if(move.driver == DRIVER_WRITER)
			{
				writerProvedMoves++;
				Assert.isFalse(move.allowed, 'Expected every move a real writer proves to be a refused move, but ' + move.runEvent + ' from ' + move.fromStatus + ' is allowed');
			}
		}
		Assert.areEqual(RUN_EVENT_MOVE_COUNT, buildExpectedRunEventMoves().size(),
				'Expected the hand-written table to carry ' + RUN_EVENT_MOVE_COUNT + ' moves, got ' + buildExpectedRunEventMoves().size());
		Assert.areEqual(WRITER_PROVED_MOVE_COUNT, writerProvedMoves, 'Expected ' + WRITER_PROVED_MOVE_COUNT + ' moves a real writer proves, got ' + writerProvedMoves);
	}

	/**
	 * @description Delayed is never a from or a to: no written status may move to it, it may move to no status, and it
	 * may not even stay itself.
	 */
	@IsTest
	private static void shouldNeverAllowDelayedAsAFromOrATo()
	{
		for(String status : listAllStatuses())
		{
			Assert.isFalse(UTIL_AsyncChain.isAllowedRunTransition(status, STATUS_DELAYED), 'Expected ' + status + ' to ' + STATUS_DELAYED + ' to be refused');
			Assert.isFalse(UTIL_AsyncChain.isAllowedRunTransition(STATUS_DELAYED, status), 'Expected ' + STATUS_DELAYED + ' to ' + status + ' to be refused');
		}
	}

	/**
	 * @description A Finalizer that finds the row Failed when its job crashed found a logic error, not a chain to fail
	 * again: QUEUEABLE_CRASHED is refused from Failed, the row keeps its status, its completion stamp and its message,
	 * and one error log names the refusal.
	 */
	@IsTest
	private static void shouldRefuseAFinalizerCrashWriteOverAFailedRow()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();
			LOG_Builder.ignoreTestMode = true;

			String runKey = UTIL_Random.randomUUID();
			AsyncChainExecution__c execution = persistRunningExecutionWithKey(runKey);
			flipToFailed(execution.Id);
			AsyncChainExecution__c flipped = queryExecution(execution.Id);
			UTIL_AsyncChain.ChainExecutor executor = buildExecutorWithCountingErrorHandler(execution.Id, runKey);

			Test.startTest();
			executor.markChainFailedFromFinalizer(execution.Id, SIMULATED_CRASH_REASON);
			Test.stopTest();
			Test.getEventBus().deliver();

			assertRowUnchanged(flipped, SEL_AsyncChainExecution.STATUS_FAILED);
			Assert.isTrue(hasLogEntryAtLevelContaining(LOG_LEVEL_ERROR, REFUSAL_LOG_FRAGMENT), 'Expected an error log naming the refused transition');
		}
	}

	/**
	 * @description A Finalizer that finds the row Completed when its job crashed found a logic error: QUEUEABLE_CRASHED is
	 * refused from Completed, the row keeps its status, its completion stamp and its message, and one error log names the
	 * refusal.
	 */
	@IsTest
	private static void shouldRefuseAFinalizerCrashWriteOverACompletedRow()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();
			LOG_Builder.ignoreTestMode = true;

			String runKey = UTIL_Random.randomUUID();
			AsyncChainExecution__c execution = persistRunningExecutionWithKey(runKey);
			flipToCompleted(execution.Id);
			AsyncChainExecution__c flipped = queryExecution(execution.Id);
			UTIL_AsyncChain.ChainExecutor executor = buildExecutorWithCountingErrorHandler(execution.Id, runKey);

			Test.startTest();
			executor.markChainFailedFromFinalizer(execution.Id, SIMULATED_CRASH_REASON);
			Test.stopTest();
			Test.getEventBus().deliver();

			assertRowUnchanged(flipped, SEL_AsyncChainExecution.STATUS_COMPLETED);
			Assert.isTrue(hasLogEntryAtLevelContaining(LOG_LEVEL_ERROR, REFUSAL_LOG_FRAGMENT), 'Expected an error log naming the refused transition');
		}
	}

	/**
	 * @description The handler note belongs to a finished chain only. A real chain fails its step and its error handler
	 * cannot be queued, but the Finalizer's fresh read answers Running (the terminal write is simulated absent): the list
	 * of allowed moves refuses HANDLER_NOT_QUEUED from Running, the row keeps exactly what the terminal write left, no note
	 * is added, no handler runs, and one error log names the refusal.
	 */
	@IsTest
	private static void shouldRefuseAHandlerNoteOverARunningRow()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();
			LOG_Builder.ignoreTestMode = true;
			configuredFailureMessage = TRANSIENT_ENQUEUE_FAILURE;

			String executionId = launchFailingChainWhoseErrorHandlerCannotBeQueuedWhileTheFreshRowReads(SEL_AsyncChainExecution.STATUS_RUNNING, null, null);

			assertHandlerNoteRefused(executionId, SEL_AsyncChainExecution.STATUS_RUNNING);
		}
	}

	/**
	 * @description A Stalled chain has not finished. A real chain fails its step and its error handler cannot be queued,
	 * but the Finalizer's fresh read answers Stalled (the watchdog moved the run in between): the list of allowed moves refuses
	 * HANDLER_NOT_QUEUED from Stalled, the row keeps exactly what the terminal write left, no note is added, no handler
	 * runs, and one error log names the refusal.
	 */
	@IsTest
	private static void shouldRefuseAHandlerNoteOverAStalledRow()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();
			LOG_Builder.ignoreTestMode = true;
			configuredFailureMessage = TRANSIENT_ENQUEUE_FAILURE;

			String executionId = launchFailingChainWhoseErrorHandlerCannotBeQueuedWhileTheFreshRowReads(
					SEL_AsyncChainExecution.STATUS_STALLED, null, SEL_AsyncChainExecution.FAILURE_CATEGORY_STALLED);

			assertHandlerNoteRefused(executionId, SEL_AsyncChainExecution.STATUS_STALLED);
		}
	}

	/**
	 * @description An operator abort does not give the run a new run key, so the fence (the check that the row still
	 * carries the run key the caller captured) alone would let the Finalizer write its handler note over an Aborted row.
	 * A real chain fails its step and its error handler cannot be queued, but the Finalizer's fresh read answers Aborted
	 * (an operator moved the run in between): the list of allowed moves refuses HANDLER_NOT_QUEUED from Aborted, the row
	 * keeps exactly what the terminal write left, no note is added, no handler runs, and one error log names the refusal.
	 */
	@IsTest
	private static void shouldRefuseAHandlerNoteOverAnAbortedRow()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();
			LOG_Builder.ignoreTestMode = true;
			configuredFailureMessage = TRANSIENT_ENQUEUE_FAILURE;

			String executionId = launchFailingChainWhoseErrorHandlerCannotBeQueuedWhileTheFreshRowReads(
					SEL_AsyncChainExecution.STATUS_ABORTED, Datetime.now(), SEL_AsyncChainExecution.FAILURE_CATEGORY_OPERATOR_ABORT);

			assertHandlerNoteRefused(executionId, SEL_AsyncChainExecution.STATUS_ABORTED);
		}
	}

	/**
	 * @description A Stalled row carrying a completion stamp is the shape a 1.7 Finalizer could leave behind. The list of
	 * allowed moves permits ENQUEUE_FAILED from Stalled, but the write would keep a Stalled run with a completion stamp,
	 * and a Stalled run cannot have an end time, so the function refuses it: nothing is written and one error log names the
	 * refusal. The shape is what the function's fresh read answers, registered as a mock: a row the backstop forbids is
	 * never inserted.
	 */
	@IsTest
	private static void shouldRefuseAFinalizerStallOverAStalledRowCarryingACompletionStamp()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();
			LOG_Builder.ignoreTestMode = true;

			String runKey = UTIL_Random.randomUUID();
			AsyncChainExecution__c execution = persistRunningExecutionWithKey(runKey);
			AsyncChainExecution__c before = queryExecution(execution.Id);
			TST_Mock.registerNext(AsyncChainExecution__c.SObjectType,
					buildFreshReadMock(execution.Id, runKey, SEL_AsyncChainExecution.STATUS_STALLED, Datetime.now(), SEL_AsyncChainExecution.FAILURE_CATEGORY_STALLED, null));
			UTIL_AsyncChain.ChainExecutor executor = buildExecutorWithCountingErrorHandler(execution.Id, runKey);

			Test.startTest();
			executor.markChainStalledFromFinalizer(execution.Id, TRANSIENT_ENQUEUE_FAILURE, null);
			Test.stopTest();
			Test.getEventBus().deliver();

			assertRowUnchanged(before, SEL_AsyncChainExecution.STATUS_RUNNING);
			Assert.isTrue(hasLogEntryAtLevelContaining(LOG_LEVEL_ERROR, REFUSAL_LOG_FRAGMENT), 'Expected an error log naming the refused transition');
		}
	}

	/**
	 * @description A Failed row still holding its active deduplication key breaks the rule that a finished run holds no
	 * such key. A real chain fails its step and its error handler cannot be queued, and the Finalizer's fresh read answers
	 * that shape: the list of allowed moves permits HANDLER_NOT_QUEUED from Failed, but the function refuses to write over
	 * a row the write would leave inconsistent, so the row keeps exactly what the terminal write left and one error log
	 * names the refusal. The shape is mocked, never inserted: the backstop forbids it.
	 */
	@IsTest
	private static void shouldRefuseAHandlerNoteOverAFailedRowStillHoldingItsDeduplicationKey()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();
			LOG_Builder.ignoreTestMode = true;
			configuredFailureMessage = TRANSIENT_ENQUEUE_FAILURE;

			String executionId = launchFailingChainWhoseErrorHandlerCannotBeQueuedWhileTheFreshRowReads(
					SEL_AsyncChainExecution.STATUS_FAILED, Datetime.now(), SEL_AsyncChainExecution.FAILURE_CATEGORY_STEP_EXCEPTION, UTIL_Random.randomUUID());

			assertHandlerNoteRefused(executionId, SEL_AsyncChainExecution.STATUS_FAILED);
		}
	}

	/**
	 * @description A completed chain carries no message, so when its completion handler cannot be queued the note stands
	 * alone on the row: the label text with the handler's position and name, then the platform's reason.
	 */
	@IsTest
	private static void shouldWriteTheNoteAloneWhenTheChainHadNoMessage()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();
			LOG_Builder.ignoreTestMode = true;

			Test.startTest();
			String executionId = UTIL_AsyncChain.newChain(TEST_CHAIN_NAME)
					.then(new UTIL_AsyncChainTransition_TEST.SuccessStep())
					.onComplete(new UTIL_AsyncChainTransition_TEST.CompletionHandlerStep())
					.withAsyncOptions(createAsyncOptions(2))
					.execute();
			UTIL_AsyncChain.simulateEnqueueFailure = true;
			Test.stopTest();
			UTIL_AsyncChain.simulateEnqueueFailure = false;
			Test.getEventBus().deliver();

			AsyncChainExecution__c execution = queryExecution(executionId);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_COMPLETED, execution.Status__c, 'Expected the chain to stay Completed, got ' + execution.Status__c);
			Assert.areEqual(buildExpectedNote(COMPLETION_HANDLER_POSITION, CompletionHandlerStep.class.getName()), execution.ErrorMessage__c,
					'Expected the note alone on a chain that had no message');
		}
	}

	/**
	 * @description A step that fails with an empty message leaves no text on the row, so when the error handler cannot be
	 * queued the note stands alone: no separator and nothing in front of it.
	 */
	@IsTest
	private static void shouldWriteTheNoteAloneWhenTheMessageIsEmpty()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();
			LOG_Builder.ignoreTestMode = true;
			configuredFailureMessage = UTIL_String.EMPTY;

			String executionId = launchFailingChainWhoseErrorHandlerCannotBeQueued(new UTIL_AsyncChainTransition_TEST.CountingErrorHandlerStep());

			AsyncChainExecution__c execution = queryExecution(executionId);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_FAILED, execution.Status__c, 'Expected the chain to stay Failed, got ' + execution.Status__c);
			Assert.areEqual(buildExpectedNote(ERROR_HANDLER_POSITION, CountingErrorHandlerStep.class.getName()), execution.ErrorMessage__c,
					'Expected the note alone on a chain whose step failed with an empty message');
			Assert.areEqual(0, errorHandlerRunCount, 'Expected the error handler not to run once its enqueue failed, got ' + errorHandlerRunCount + ' run(s)');
		}
	}

	/**
	 * @description A step message that fills the whole field gives way to the note: the message keeps its first
	 * characters and ends abbreviated, the separator and the whole note follow, and the row stays within the field.
	 */
	@IsTest
	private static void shouldKeepTheNoteWholeWhenTheMessageFillsTheField()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();
			LOG_Builder.ignoreTestMode = true;
			configuredFailureMessage = FILLER_CHARACTER.repeat(ERROR_MESSAGE_FIELD_LENGTH);

			String executionId = launchFailingChainWhoseErrorHandlerCannotBeQueued(new UTIL_AsyncChainTransition_TEST.CountingErrorHandlerStep());

			AsyncChainExecution__c execution = queryExecution(executionId);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_FAILED, execution.Status__c, 'Expected the chain to stay Failed, got ' + execution.Status__c);
			assertMessageAbbreviatedAheadOfWholeNote(execution);
		}
	}

	/**
	 * @description A step message one longer than the field is already abbreviated to the field by the terminal write,
	 * so the note meets a message at the limit and the row reads exactly as when the message filled the field.
	 */
	@IsTest
	private static void shouldKeepTheNoteWholeWhenTheMessageExceedsTheField()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();
			LOG_Builder.ignoreTestMode = true;
			configuredFailureMessage = FILLER_CHARACTER.repeat(ERROR_MESSAGE_FIELD_LENGTH + 1);

			String executionId = launchFailingChainWhoseErrorHandlerCannotBeQueued(new UTIL_AsyncChainTransition_TEST.CountingErrorHandlerStep());

			AsyncChainExecution__c execution = queryExecution(executionId);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_FAILED, execution.Status__c, 'Expected the chain to stay Failed, got ' + execution.Status__c);
			assertMessageAbbreviatedAheadOfWholeNote(execution);
		}
	}

	/**
	 * @description When the note itself is longer than the field (a handler whose display name fills it), the row keeps
	 * the note's start and nothing else: the message is dropped, the note is abbreviated to the field and the platform's
	 * reason at its end is cut away, because the note is the signal a reader needs.
	 */
	@IsTest
	private static void shouldKeepTheNoteStartWhenTheReasonExceedsTheRoomLeft()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();
			LOG_Builder.ignoreTestMode = true;
			configuredFailureMessage = TRANSIENT_ENQUEUE_FAILURE;
			String fillingHandlerName = FILLER_CHARACTER.repeat(ERROR_MESSAGE_FIELD_LENGTH);
			UTIL_AsyncChainTransition_TEST.CountingErrorHandlerStep handler = new UTIL_AsyncChainTransition_TEST.CountingErrorHandlerStep();
			handler.stepName = fillingHandlerName;

			String executionId = launchFailingChainWhoseErrorHandlerCannotBeQueued(handler);

			AsyncChainExecution__c execution = queryExecution(executionId);
			String wholeNote = buildExpectedNote(ERROR_HANDLER_POSITION, fillingHandlerName);
			String expectedStart = wholeNote.substring(0, ERROR_MESSAGE_FIELD_LENGTH - ELLIPSIS.length());
			Assert.areEqual(ERROR_MESSAGE_FIELD_LENGTH, execution.ErrorMessage__c.length(), 'Expected the row to fill the field exactly');
			Assert.isTrue(execution.ErrorMessage__c.startsWith(expectedStart), 'Expected the note to keep its start when it is longer than the field');
			Assert.isTrue(execution.ErrorMessage__c.endsWith(ELLIPSIS), 'Expected the overlong note to end abbreviated');
			Assert.isFalse(execution.ErrorMessage__c.contains(SIMULATED_HANDLER_ENQUEUE_FAILURE), 'Expected the platform reason at the note\'s end to be cut away');
			Assert.isFalse(execution.ErrorMessage__c.startsWith(TRANSIENT_ENQUEUE_FAILURE), 'Expected the step message to be dropped in favour of the note');
		}
	}

	/**
	 * @description A completed chain whose completion handler fails in its own transaction ends Failed, and a Failed run
	 * must carry a failure category: HANDLER_FAILED from Completed stamps StepException, because the row had no category
	 * yet, and the message names the handler's failure.
	 */
	@IsTest
	private static void shouldStampStepExceptionWhenACompletionHandlerFailsInTransaction()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();

			Test.startTest();
			String executionId = UTIL_AsyncChain.newChain(TEST_CHAIN_NAME)
					.then(new UTIL_AsyncChainTransition_TEST.SuccessStep())
					.onComplete(new UTIL_AsyncChainTransition_TEST.FailingCompletionHandlerStep())
					.withAsyncOptions(createAsyncOptions(2))
					.execute();
			Test.stopTest();

			AsyncChainExecution__c execution = queryExecution(executionId);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_FAILED, execution.Status__c,
					'Expected the failed completion handler to end the chain Failed, got ' + execution.Status__c);
			Assert.areEqual(SEL_AsyncChainExecution.FAILURE_CATEGORY_STEP_EXCEPTION, execution.FailureCategory__c,
					'Expected a completion handler failure to stamp StepException on a run that had no category, got ' + execution.FailureCategory__c);
			Assert.areEqual(HANDLER_FAILURE_PREFIX + COMPLETION_HANDLER_FAILURE_REASON, execution.ErrorMessage__c, 'Expected the message to name the handler failure alone');
			Assert.isNotNull(execution.CompletedAt__c, 'Expected the completion stamp the terminal write set');
		}
	}

	/**
	 * @description A chain that used up its step's retry budget ends Failed as RetriesExhausted; when its error handler
	 * then fails, HANDLER_FAILED from Failed keeps that category (a Failed row keeps the category it has) and the message
	 * carries the step's reason, then the handler's.
	 */
	@IsTest
	private static void shouldKeepRetriesExhaustedWhenTheErrorHandlerFails()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();

			Test.startTest();
			String executionId = UTIL_AsyncChain.newChain(TEST_CHAIN_NAME)
					.then(new UTIL_AsyncChainTransition_TEST.AlwaysFailsWithRetryStep())
					.onError(new UTIL_AsyncChainTransition_TEST.FailingErrorHandlerStep())
					.withAsyncOptions(createAsyncOptions(3))
					.execute();
			Test.stopTest();

			AsyncChainExecution__c execution = queryExecution(executionId);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_FAILED, execution.Status__c, 'Expected the chain to stay Failed, got ' + execution.Status__c);
			Assert.areEqual(SEL_AsyncChainExecution.FAILURE_CATEGORY_RETRIES_EXHAUSTED, execution.FailureCategory__c,
					'Expected the error handler failure to keep RetriesExhausted, got ' + execution.FailureCategory__c);
			Assert.areEqual(RETRY_STEP_FAILURE_PREFIX + EXHAUSTED_ATTEMPT + NOTE_SEPARATOR + HANDLER_FAILURE_PREFIX + ERROR_HANDLER_FAILURE_REASON, execution.ErrorMessage__c,
					'Expected the step reason, then the handler failure');
		}
	}

	/**
	 * @description A completion handler that crashes moves a Completed run to Failed, but the run's end time is the
	 * completion's, not the crash's, because an end time never changes once it is set. HANDLER_FAILED through the handler
	 * Finalizer keeps CompletedAt__c and stamps StepException because the row had no category.
	 */
	@IsTest
	private static void shouldKeepTheEndTimeWhenACompletionHandlerCrashes()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();

			String runKey = UTIL_Random.randomUUID();
			AsyncChainExecution__c execution = persistRunningExecutionWithKey(runKey);
			flipStatus(execution.Id, SEL_AsyncChainExecution.STATUS_COMPLETED, Datetime.now().addMinutes(-STAMP_AGE_MINUTES), null);
			AsyncChainExecution__c completed = queryExecution(execution.Id);
			UTIL_AsyncChain.HandlerExecutor handlerExecutor = buildHandlerExecutor(execution.Id, null, SEL_AsyncChainExecution.STATUS_COMPLETED, null, runKey);

			Test.startTest();
			handlerExecutor.markHandlerFailed(execution.Id, HANDLER_CRASH_REASON);
			Test.stopTest();

			AsyncChainExecution__c failed = queryExecution(execution.Id);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_FAILED, failed.Status__c, 'Expected the handler crash to end the chain Failed, got ' + failed.Status__c);
			Assert.areEqual(SEL_AsyncChainExecution.FAILURE_CATEGORY_STEP_EXCEPTION, failed.FailureCategory__c,
					'Expected a completion handler crash to stamp StepException on a run that had no category, got ' + failed.FailureCategory__c);
			Assert.areEqual(completed.CompletedAt__c, failed.CompletedAt__c, 'Expected the end time of the completion to stay, not the crash\'s');
			Assert.areEqual(HANDLER_CRASH_REASON, failed.ErrorMessage__c, 'Expected the crash reason on the row');
		}
	}

	/**
	 * @description An error handler that crashes leaves a Failed run Failed, with the end time of the step failure, not
	 * the crash's (an end time never changes once it is set), and with the category the step failure stamped.
	 * HANDLER_FAILED through the handler Finalizer keeps CompletedAt__c and keeps RetriesExhausted.
	 */
	@IsTest
	private static void shouldKeepTheEndTimeWhenAnErrorHandlerCrashes()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();

			String runKey = UTIL_Random.randomUUID();
			AsyncChainExecution__c execution = persistRunningExecutionWithKey(runKey);
			flipStatus(execution.Id, SEL_AsyncChainExecution.STATUS_FAILED, Datetime.now().addMinutes(-STAMP_AGE_MINUTES),
					SEL_AsyncChainExecution.FAILURE_CATEGORY_RETRIES_EXHAUSTED);
			AsyncChainExecution__c failedByStep = queryExecution(execution.Id);
			UTIL_AsyncChain.HandlerExecutor handlerExecutor = buildHandlerExecutor(execution.Id, null, SEL_AsyncChainExecution.STATUS_FAILED, ORIGINAL_FAILURE_REASON, runKey);

			Test.startTest();
			handlerExecutor.markHandlerFailed(execution.Id, HANDLER_CRASH_REASON);
			Test.stopTest();

			AsyncChainExecution__c failedByHandler = queryExecution(execution.Id);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_FAILED, failedByHandler.Status__c, 'Expected the chain to stay Failed, got ' + failedByHandler.Status__c);
			Assert.areEqual(SEL_AsyncChainExecution.FAILURE_CATEGORY_RETRIES_EXHAUSTED, failedByHandler.FailureCategory__c,
					'Expected the error handler crash to keep RetriesExhausted, got ' + failedByHandler.FailureCategory__c);
			Assert.areEqual(failedByStep.CompletedAt__c, failedByHandler.CompletedAt__c, 'Expected the end time of the step failure to stay, not the crash\'s');
			Assert.areEqual(HANDLER_CRASH_REASON, failedByHandler.ErrorMessage__c, 'Expected the crash reason on the row');
		}
	}

	/**
	 * @description A handler crash cannot end a Stalled run, even when the handler was queued for a Failed run. The list
	 * of allowed moves permits HANDLER_FAILED from Completed and Failed only. Here the handler's own check of the status it
	 * was queued for does not apply, because that status is Failed. The run reads Stalled under the handler's run key, so
	 * the list of allowed moves alone refuses the write: the row keeps Stalled, its category and no end time, and one
	 * error log names the refusal.
	 */
	@IsTest
	private static void shouldRefuseAHandlerCrashOverAStalledRowThroughTheListOfAllowedMoves()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();
			LOG_Builder.ignoreTestMode = true;

			String runKey = UTIL_Random.randomUUID();
			AsyncChainExecution__c execution = persistRunningExecutionWithKey(runKey);
			flipStatus(execution.Id, SEL_AsyncChainExecution.STATUS_STALLED, null, SEL_AsyncChainExecution.FAILURE_CATEGORY_STALLED);
			AsyncChainExecution__c stalled = queryExecution(execution.Id);
			UTIL_AsyncChain.HandlerExecutor handlerExecutor = buildHandlerExecutor(execution.Id, null, SEL_AsyncChainExecution.STATUS_FAILED, ORIGINAL_FAILURE_REASON, runKey);

			Test.startTest();
			handlerExecutor.markHandlerFailed(execution.Id, HANDLER_CRASH_REASON);
			Test.stopTest();
			Test.getEventBus().deliver();

			AsyncChainExecution__c after = queryExecution(execution.Id);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_STALLED, after.Status__c, 'Expected the row to keep Stalled, got ' + after.Status__c);
			Assert.areEqual(SEL_AsyncChainExecution.FAILURE_CATEGORY_STALLED, after.FailureCategory__c, 'Expected the stall category to stay, got ' + after.FailureCategory__c);
			Assert.isNull(after.CompletedAt__c, 'Expected no end time on the Stalled row, got ' + after.CompletedAt__c);
			Assert.areEqual(stalled.ErrorMessage__c, after.ErrorMessage__c, 'Expected the message to read as before the refused handler crash');
			Assert.isTrue(hasLogEntryAtLevelContaining(LOG_LEVEL_ERROR, REFUSAL_LOG_FRAGMENT + ' ' + RUN_EVENT_HANDLER_FAILED + ' from ' + SEL_AsyncChainExecution.STATUS_STALLED),
					'Expected an error log naming the refused handler crash from Stalled');
			Assert.isFalse(hasLogEntryAtLevelContaining(LOG_LEVEL_ERROR, REFUSAL_LOG_FRAGMENT + ' ' + RUN_EVENT_HANDLER_FAILED + ' from '
					+ SEL_AsyncChainExecution.STATUS_STALLED + ': '), 'Expected the list of allowed moves, not a broken rule of the row, to refuse the handler crash');
		}
	}

	/**
	 * @description A handler's write-back belongs to a finished chain only. An error handler built for a Failed run finds
	 * the run back at Running, with its completion stamp and category cleared, as a retry committed between the terminal
	 * write and the handler's run would leave it. The handler fails, the list of allowed moves refuses HANDLER_FAILED from
	 * Running, the row keeps Running, its held deduplication key and no context, and one error log names the refusal.
	 */
	@IsTest
	private static void shouldRefuseAHandlerFailureOverARunningRow()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();
			LOG_Builder.ignoreTestMode = true;

			AsyncChainExecution__c running = runHandlerOverARunningRow(buildDtoStepDefinition(FailingErrorHandlerStep.class.getName(), FAILING_ERROR_HANDLER_STEP_NAME));

			assertHandlerWriteRefusedOverRunningRow(running, RUN_EVENT_HANDLER_FAILED);
		}
	}

	/**
	 * @description A handler that succeeds against a run back at Running is refused the same way: the list of allowed moves
	 * refuses HANDLER_SUCCEEDED from Running, so the handler's context never reaches the row, the held deduplication key
	 * stays, and one error log names the refusal. The handler itself ran: only its write-back is refused.
	 */
	@IsTest
	private static void shouldRefuseAHandlerSuccessOverARunningRow()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();
			LOG_Builder.ignoreTestMode = true;

			AsyncChainExecution__c running = runHandlerOverARunningRow(buildDtoStepDefinition(CountingErrorHandlerStep.class.getName(), COUNTING_ERROR_HANDLER_STEP_NAME));

			assertHandlerWriteRefusedOverRunningRow(running, RUN_EVENT_HANDLER_SUCCEEDED);
			Assert.areEqual(1, errorHandlerRunCount, 'Expected the error handler to run once, got ' + errorHandlerRunCount + ' run(s)');
		}
	}

	/**
	 * @description A Failed run must carry a failure category, and a handler's successful write-back must not leave a
	 * Failed run without one. A real chain fails its step and its error handler succeeds, but the function's fresh read
	 * answers a Failed row with its completion stamp, the matching run key and no category (a shape the backstop forbids,
	 * so it is mocked, never inserted). The list of allowed moves permits HANDLER_SUCCEEDED from Failed, but the check of
	 * the rules a row must meet in its status refuses the write. The handler's context never reaches the row, and one error
	 * log names the refusal and the broken rule.
	 */
	@IsTest
	private static void shouldRefuseAHandlerSuccessWhenTheFreshRowIsFailedWithoutACategory()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();
			LOG_Builder.ignoreTestMode = true;
			configuredFailureMessage = ORIGINAL_FAILURE_REASON;

			Test.startTest();
			String executionId = startFailingChainWithCountingErrorHandler();
			AsyncChainExecution__c launched = queryExecution(executionId);
			TST_Mock.registerNext(AsyncChainExecution__c.SObjectType, launched);
			TST_Mock.registerNext(AsyncChainExecution__c.SObjectType, launched);
			TST_Mock.registerNext(AsyncChainExecution__c.SObjectType, launched);
			TST_Mock.registerNext(AsyncChainExecution__c.SObjectType,
					buildFreshReadMock(executionId, launched.RunKey__c, SEL_AsyncChainExecution.STATUS_FAILED, Datetime.now(), null, null));
			Test.stopTest();
			Test.getEventBus().deliver();

			AsyncChainExecution__c execution = queryExecution(executionId);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_FAILED, execution.Status__c, 'Expected the terminal write to stand, got ' + execution.Status__c);
			Assert.areEqual(SEL_AsyncChainExecution.FAILURE_CATEGORY_STEP_EXCEPTION, execution.FailureCategory__c, 'Expected the category the terminal write set');
			Assert.areEqual(ORIGINAL_FAILURE_REASON, execution.ErrorMessage__c, 'Expected the step message the terminal write set');
			Map<String, Object> contextData = (Map<String, Object>)JSON.deserializeUntyped(execution.ContextData__c);
			Assert.isNull(contextData.get(HANDLER_RAN_CONTEXT_KEY), 'Expected the handler\'s context not to reach the row');
			Assert.areEqual(1, errorHandlerRunCount, 'Expected the error handler to run once, got ' + errorHandlerRunCount + ' run(s)');
			Assert.isTrue(hasLogEntryAtLevelContaining(LOG_LEVEL_ERROR, REFUSAL_LOG_FRAGMENT + ' ' + RUN_EVENT_HANDLER_SUCCEEDED + ' from '
					+ SEL_AsyncChainExecution.STATUS_FAILED), 'Expected an error log naming the refused handler write-back from Failed');
			Assert.isTrue(hasLogEntryAtLevelContaining(LOG_LEVEL_ERROR, MISSING_FAILURE_CATEGORY_REASON),
					'Expected the error log to name the rule that a Failed run needs a category');
		}
	}

	/**
	 * @description A completion write belongs to a run that is still going. A real chain's last step finds its run already
	 * Completed, with an end time in the past (another actor committed it mid-work), and succeeds: the list of allowed
	 * moves refuses STEP_COMPLETED from Completed, the row keeps Completed and the earlier end time, no completion handler
	 * is queued, and one error log names the refusal.
	 */
	@IsTest
	private static void shouldRefuseACompletionWriteOverACompletedRow()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();
			LOG_Builder.ignoreTestMode = true;
			movedRunStatus = SEL_AsyncChainExecution.STATUS_COMPLETED;
			movedRunFailureCategory = null;

			Test.startTest();
			String executionId = UTIL_AsyncChain.newChain(TEST_CHAIN_NAME)
					.then(new UTIL_AsyncChainTransition_TEST.MoveRunThenSucceedStep())
					.onComplete(new UTIL_AsyncChainTransition_TEST.CountingCompletionHandlerStep())
					.withAsyncOptions(createAsyncOptions(2))
					.execute();
			Test.stopTest();
			Test.getEventBus().deliver();

			AsyncChainExecution__c execution = queryExecution(executionId);
			assertMovedRunKept(execution, SEL_AsyncChainExecution.STATUS_COMPLETED, null);
			Assert.areEqual(0, completionHandlerRunCount, 'Expected no completion handler from a refused completion, got ' + completionHandlerRunCount + ' run(s)');
			Assert.isTrue(hasLogEntryAtLevelContaining(LOG_LEVEL_ERROR, REFUSAL_LOG_FRAGMENT + ' ' + RUN_EVENT_STEP_COMPLETED + ' from '
					+ SEL_AsyncChainExecution.STATUS_COMPLETED), 'Expected an error log naming the refused completion from Completed');
		}
	}

	/**
	 * @description A step failure write belongs to a run that is still going. A real chain's step finds its run already
	 * Failed as RetriesExhausted, with an end time in the past, and fails: the list of allowed moves refuses STEP_FAILED
	 * from Failed, the row keeps Failed, its category, the earlier end time and no message, no error handler is queued, and
	 * one error log names the refusal.
	 */
	@IsTest
	private static void shouldRefuseAStepFailureWriteOverAFailedRow()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();
			LOG_Builder.ignoreTestMode = true;
			configuredFailureMessage = TRANSIENT_ENQUEUE_FAILURE;
			movedRunStatus = SEL_AsyncChainExecution.STATUS_FAILED;
			movedRunFailureCategory = SEL_AsyncChainExecution.FAILURE_CATEGORY_RETRIES_EXHAUSTED;

			String executionId = launchChainWhoseStepMovesItsRunThenFails();

			AsyncChainExecution__c execution = queryExecution(executionId);
			assertMovedRunKept(execution, SEL_AsyncChainExecution.STATUS_FAILED, SEL_AsyncChainExecution.FAILURE_CATEGORY_RETRIES_EXHAUSTED);
			Assert.isTrue(hasLogEntryAtLevelContaining(LOG_LEVEL_ERROR, REFUSAL_LOG_FRAGMENT + ' ' + RUN_EVENT_STEP_FAILED + ' from ' + SEL_AsyncChainExecution.STATUS_FAILED),
					'Expected an error log naming the refused step failure from Failed');
		}
	}

	/**
	 * @description A real chain's step finds its run already Completed, with an end time in the past, and fails: the list
	 * of allowed moves refuses STEP_FAILED from Completed, the row keeps Completed, the earlier end time and no message, no
	 * error handler is queued, and one error log names the refusal.
	 */
	@IsTest
	private static void shouldRefuseAStepFailureWriteOverACompletedRow()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();
			LOG_Builder.ignoreTestMode = true;
			configuredFailureMessage = TRANSIENT_ENQUEUE_FAILURE;
			movedRunStatus = SEL_AsyncChainExecution.STATUS_COMPLETED;
			movedRunFailureCategory = null;

			String executionId = launchChainWhoseStepMovesItsRunThenFails();

			AsyncChainExecution__c execution = queryExecution(executionId);
			assertMovedRunKept(execution, SEL_AsyncChainExecution.STATUS_COMPLETED, null);
			Assert.isTrue(hasLogEntryAtLevelContaining(LOG_LEVEL_ERROR, REFUSAL_LOG_FRAGMENT + ' ' + RUN_EVENT_STEP_FAILED + ' from ' + SEL_AsyncChainExecution.STATUS_COMPLETED),
					'Expected an error log naming the refused step failure from Completed');
		}
	}

	/**
	 * @description The kill switch aborts a run that is still going, or re-stamps one already Aborted; a run that ended
	 * Failed is not its to abort. An executor with the matching run key finds the row Failed when it meets the kill switch:
	 * the list of allowed moves refuses KILL_SWITCH_ABORTED from Failed, the row keeps Failed, its category, its end time
	 * and its message, and one error log names the refusal.
	 */
	@IsTest
	private static void shouldRefuseAKillSwitchAbortOverAFailedRow()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();
			LOG_Builder.ignoreTestMode = true;

			String runKey = UTIL_Random.randomUUID();
			AsyncChainExecution__c execution = persistRunningExecutionWithKey(runKey);
			flipToFailed(execution.Id);
			AsyncChainExecution__c flipped = queryExecution(execution.Id);
			UTIL_AsyncChain.ChainExecutor executor = buildExecutorWithCountingErrorHandler(execution.Id, runKey);

			Test.startTest();
			executor.markAborted(queryExecution(execution.Id), KILL_SWITCH_ABORT_REASON);
			Test.stopTest();
			Test.getEventBus().deliver();

			assertRowUnchanged(flipped, SEL_AsyncChainExecution.STATUS_FAILED);
			Assert.areEqual(SEL_AsyncChainExecution.FAILURE_CATEGORY_STEP_EXCEPTION, queryExecution(execution.Id).FailureCategory__c,
					'Expected the category to read as before the refused call');
			Assert.isTrue(hasLogEntryAtLevelContaining(LOG_LEVEL_ERROR,
					REFUSAL_LOG_FRAGMENT + ' ' + RUN_EVENT_KILL_SWITCH_ABORTED + ' from ' + SEL_AsyncChainExecution.STATUS_FAILED),
					'Expected an error log naming the refused kill-switch abort from Failed');
		}
	}

	/**
	 * @description The kill switch re-stamping an operator abort is allowed, since the run is Aborted either way and
	 * the kill switch is the stronger signal: KILL_SWITCH_ABORTED from Aborted sets the category to KillSwitch and the
	 * abort reason, and keeps the end time and the duration the operator abort set (an end time never changes once it
	 * is set). Nothing is refused.
	 */
	@IsTest
	private static void shouldReStampAnOperatorAbortWithTheKillSwitch()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();
			LOG_Builder.ignoreTestMode = true;

			String runKey = UTIL_Random.randomUUID();
			AsyncChainExecution__c execution = persistRunningExecutionWithKey(runKey);
			flipStatus(execution.Id, SEL_AsyncChainExecution.STATUS_ABORTED, Datetime.now().addMinutes(-STAMP_AGE_MINUTES),
					SEL_AsyncChainExecution.FAILURE_CATEGORY_OPERATOR_ABORT);
			AsyncChainExecution__c abortedByOperator = queryExecution(execution.Id);
			UTIL_AsyncChain.ChainExecutor executor = buildExecutorWithCountingErrorHandler(execution.Id, runKey);

			Test.startTest();
			executor.markAborted(queryExecution(execution.Id), KILL_SWITCH_ABORT_REASON);
			Test.stopTest();
			Test.getEventBus().deliver();

			AsyncChainExecution__c abortedByKillSwitch = queryExecution(execution.Id);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_ABORTED, abortedByKillSwitch.Status__c, 'Expected the row to stay Aborted, got ' + abortedByKillSwitch.Status__c);
			Assert.areEqual(SEL_AsyncChainExecution.FAILURE_CATEGORY_KILL_SWITCH, abortedByKillSwitch.FailureCategory__c,
					'Expected the kill switch to re-stamp the category, got ' + abortedByKillSwitch.FailureCategory__c);
			Assert.areEqual(KILL_SWITCH_ABORT_REASON, abortedByKillSwitch.ErrorMessage__c, 'Expected the kill switch reason on the row');
			Assert.areEqual(abortedByOperator.CompletedAt__c, abortedByKillSwitch.CompletedAt__c, 'Expected the end time of the operator abort to stay');
			Assert.areEqual(abortedByOperator.DurationMs__c, abortedByKillSwitch.DurationMs__c, 'Expected the duration of the operator abort to stay');
			Assert.isFalse(hasLogEntryAtLevelContaining(LOG_LEVEL_ERROR, REFUSAL_LOG_FRAGMENT), 'Expected no refusal of a kill-switch re-stamp');
		}
	}

	/**
	 * @description A watchdog re-drive puts the run back to Running, and a Running run carries no failure category
	 * and no end time: WATCHDOG_REDRIVEN from a Stalled run carrying the Stalled category clears the category in the same
	 * write that gives the run a new run key and leaves the end time unset. The run is a dead stalled candidate as the sweep
	 * finds it, and the sweep's own re-drive leg is the writer.
	 */
	@IsTest
	private static void shouldClearTheStallCategoryWhenTheWatchdogRedrivesAStalledRow()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();

			String staleRunKey = UTIL_Random.randomUUID();
			AsyncChainExecution__c stalled = seedDeadRedriveCandidate(SEL_AsyncChainExecution.STATUS_STALLED, staleRunKey, buildMidChainStepLogWithErrorHandler());

			UTIL_AsyncChain.runWatchdogSweep(SWEEP_EVERYTHING_THRESHOLD_MINUTES, WATCHDOG_BATCH_SIZE);

			AsyncChainExecution__c redriven = queryExecution(stalled.Id);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_RUNNING, redriven.Status__c, 'Expected the sweep to re-drive the dead candidate, got ' + redriven.Status__c);
			Assert.isNull(redriven.FailureCategory__c, 'Expected the re-drive to clear the stall category, got ' + redriven.FailureCategory__c);
			Assert.areNotEqual(staleRunKey, redriven.RunKey__c, 'Expected the re-drive to rotate the run key');
			Assert.isNull(redriven.CompletedAt__c, 'Expected a re-driven run to carry no end time');
			Assert.areEqual(0, errorHandlerRunCount, 'Expected no notification from a re-drive, got ' + errorHandlerRunCount + ' run(s)');
		}
	}

	/**
	 * @description A run the watchdog marked Stalled is still owned by its executor when that executor is only slow: an
	 * unstamped Running run is marked Stalled by the sweep (no job id to probe, so the sweep cannot prove the executor
	 * dead), then the executor, holding the matching run key, finishes the last step and STEP_COMPLETED from Stalled
	 * ends the run Completed with the stall category cleared and the run key kept.
	 */
	@IsTest
	private static void shouldFinishStalledWhenASlowExecutorCompletes()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();

			String runKey = UTIL_Random.randomUUID();
			AsyncChainExecution__c execution = TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_RUNNING, TEST_CHAIN_NAME, new Map<SObjectField, Object>
			{
					AsyncChainExecution__c.TotalSteps__c => SINGLE_STEP_TOTAL_STEPS,
					AsyncChainExecution__c.CompletedSteps__c => 0,
					AsyncChainExecution__c.StartedAt__c => Datetime.now(),
					AsyncChainExecution__c.RunKey__c => runKey,
					AsyncChainExecution__c.StepLog__c => buildSingleStepLogWithErrorHandler(),
					AsyncChainExecution__c.ContextData__c => EMPTY_CONTEXT_JSON
			});
			UTIL_AsyncChain.runWatchdogSweep(SWEEP_EVERYTHING_THRESHOLD_MINUTES, WATCHDOG_BATCH_SIZE);
			AsyncChainExecution__c marked = queryExecution(execution.Id);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_STALLED, marked.Status__c,
					'Fixture guard: expected the sweep to mark the unstamped run Stalled, got ' + marked.Status__c);

			Test.startTest();
			System.enqueueJob(buildExecutorWithoutHandlers(execution.Id, runKey), createAsyncOptions(2));
			Test.stopTest();

			AsyncChainExecution__c completed = queryExecution(execution.Id);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_COMPLETED, completed.Status__c, 'Expected the slow executor to finish the stalled run, got ' + completed.Status__c);
			Assert.isNull(completed.FailureCategory__c, 'Expected the completion to clear the stall category, got ' + completed.FailureCategory__c);
			Assert.isNotNull(completed.CompletedAt__c, 'Expected the completion to stamp the end time');
			Assert.areEqual(runKey, completed.RunKey__c, 'Expected the executor\'s completion to keep the run key');
			Assert.areEqual(SINGLE_STEP_TOTAL_STEPS, completed.CompletedSteps__c, 'Expected the one step to be counted');
		}
	}

	/**
	 * @description A degrade belongs to a run that is still waiting for recovery. The sweep's re-drive leg reads a stalled
	 * candidate it cannot re-drive (every step already attempted), but between that read and the degrade write another
	 * actor ended the run Failed: the list of allowed moves refuses RECOVERY_DEGRADED from Failed, the row keeps the other
	 * actor's status, category and end time, its run key is not rotated, no notification is queued and one error log names
	 * the refusal.
	 */
	@IsTest
	private static void shouldRefuseADegradeOverAFailedRow()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();
			LOG_Builder.ignoreTestMode = true;

			assertDegradeRefusedOverARunMovedTo(SEL_AsyncChainExecution.STATUS_FAILED, SEL_AsyncChainExecution.FAILURE_CATEGORY_STEP_EXCEPTION);
		}
	}

	/**
	 * @description The same race as shouldRefuseADegradeOverAFailedRow with the run ended Completed in the window: the list
	 * of allowed moves refuses RECOVERY_DEGRADED from Completed, the row keeps Completed and its end time, no notification
	 * is queued and one error log names the refusal.
	 */
	@IsTest
	private static void shouldRefuseADegradeOverACompletedRow()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();
			LOG_Builder.ignoreTestMode = true;

			assertDegradeRefusedOverARunMovedTo(SEL_AsyncChainExecution.STATUS_COMPLETED, null);
		}
	}

	/**
	 * @description The degrade's notification is queued only after its terminal write has landed: a degrade whose write
	 * is refused, because an operator aborted the run between the sweep's read and the write, queues nothing at all, so
	 * no handler runs for a failure that never committed. The queueable count around the call and the handler's run
	 * count after the test's jobs ran both read zero.
	 */
	@IsTest
	private static void shouldQueueTheDegradeNotificationOnlyAfterTheWriteLands()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();
			LOG_Builder.ignoreTestMode = true;

			assertDegradeRefusedOverARunMovedTo(SEL_AsyncChainExecution.STATUS_ABORTED, SEL_AsyncChainExecution.FAILURE_CATEGORY_OPERATOR_ABORT);
		}
	}

	/**
	 * @description A re-drive enqueues its recovery executor only after its rotation write (the write that gives the run
	 * a new run key) has landed. The sweep's re-drive leg reads a running candidate with a step still to run, but between
	 * that read and the rotation write another actor ended the run Completed: the list of allowed moves refuses
	 * WATCHDOG_REDRIVEN from Completed, the row keeps Completed, its end time, its run key and its step log, no executor
	 * is queued and one error log names the refusal.
	 */
	@IsTest
	private static void shouldEnqueueNoRecoveryExecutorWhenTheRedriveWriteIsRefused()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();
			LOG_Builder.ignoreTestMode = true;

			AsyncChainExecution__c candidate = seedDeadRedriveCandidate(SEL_AsyncChainExecution.STATUS_RUNNING, UTIL_Random.randomUUID(), buildMidChainStepLogWithErrorHandler());
			AsyncChainExecution__c sweepView = queryExecution(candidate.Id);
			flipToCompleted(candidate.Id);
			AsyncChainExecution__c completed = queryExecution(candidate.Id);
			TST_Mock.registerNext(AsyncChainExecution__c.SObjectType, sweepView);

			Integer executorsQueued = countJobsQueuedByRedrive(sweepView);

			AsyncChainExecution__c after = queryExecution(candidate.Id);
			assertRowUnchanged(completed, SEL_AsyncChainExecution.STATUS_COMPLETED);
			Assert.areEqual(sweepView.RunKey__c, after.RunKey__c, 'Expected no rotation from a refused re-drive');
			Assert.areEqual(completed.StepLog__c, after.StepLog__c, 'Expected the step log to read as before the refused re-drive');
			Assert.areEqual(0, executorsQueued, 'Expected no recovery executor queued by a refused re-drive, got ' + executorsQueued);
			Assert.isTrue(
					hasLogEntryAtLevelContaining(LOG_LEVEL_ERROR, REFUSAL_LOG_FRAGMENT + ' ' + RUN_EVENT_WATCHDOG_REDRIVEN + ' from ' + SEL_AsyncChainExecution.STATUS_COMPLETED),
					'Expected an error log naming the refused re-drive from Completed');
		}
	}

	/**
	 * @description The Failed leg of the same race, through the sweep's own candidate decision: the sweep reads a dead
	 * running candidate with a step still to run and takes its re-drive leg (sweepCandidate, a stamped dead job), but
	 * between the leg's entry re-read and the rotation write another actor ended the run Failed. The entry read is scripted
	 * to answer the candidate as the sweep saw it, so qualifiesForRedrive passes and the move is decided by the list of
	 * allowed moves at the function's fresh read: WATCHDOG_REDRIVEN from Failed is refused, the row keeps Failed, its
	 * category, its end time, its run key and its step log, no executor is queued and one error log names the refusal. (A
	 * Failed row carries an end time, so the stale selector never returns it; the stale view is handed to sweepCandidate as
	 * the sweep would hold it.)
	 */
	@IsTest
	private static void shouldRefuseARedriveOverAFailedRow()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();
			LOG_Builder.ignoreTestMode = true;

			AsyncChainExecution__c candidate = seedDeadRedriveCandidate(SEL_AsyncChainExecution.STATUS_RUNNING, UTIL_Random.randomUUID(), buildMidChainStepLogWithErrorHandler());
			AsyncChainExecution__c sweepView = queryExecution(candidate.Id);
			flipToFailed(candidate.Id);
			AsyncChainExecution__c failed = queryExecution(candidate.Id);
			TST_Mock.registerNext(AsyncChainExecution__c.SObjectType, sweepView);

			Test.startTest();
			Integer queuedBefore = UTIL_Limits.queueableJobs().used();
			UTIL_AsyncChain.sweepCandidate(sweepView);
			Integer queuedAfter = UTIL_Limits.queueableJobs().used();
			Test.stopTest();
			Test.getEventBus().deliver();

			AsyncChainExecution__c after = queryExecution(candidate.Id);
			assertRowUnchanged(failed, SEL_AsyncChainExecution.STATUS_FAILED);
			Assert.areEqual(SEL_AsyncChainExecution.FAILURE_CATEGORY_STEP_EXCEPTION, after.FailureCategory__c, 'Expected the category the other actor set to stay');
			Assert.areEqual(sweepView.RunKey__c, after.RunKey__c, 'Expected no rotation from a refused re-drive');
			Assert.areEqual(failed.StepLog__c, after.StepLog__c, 'Expected the step log to read as before the refused re-drive');
			Assert.areEqual(queuedBefore, queuedAfter, 'Expected no recovery executor queued by a refused re-drive, got ' + (queuedAfter - queuedBefore));
			Assert.isTrue(
					hasLogEntryAtLevelContaining(LOG_LEVEL_ERROR, REFUSAL_LOG_FRAGMENT + ' ' + RUN_EVENT_WATCHDOG_REDRIVEN + ' from ' + SEL_AsyncChainExecution.STATUS_FAILED),
					'Expected an error log naming the refused re-drive from Failed');
		}
	}

	/**
	 * @description The re-drive's fence repeats the sweep's key check at write time. The sweep's re-drive leg reads a
	 * running candidate under the key it saw, but the function's fresh read answers the row under another key (another
	 * actor claimed the run between the entry re-read and the write): the fence refuses the write with its warning,
	 * the row keeps its key, its status and its step log, and no executor is queued.
	 */
	@IsTest
	private static void shouldRefuseARedriveWhenTheRunWasClaimedInsideTheWriteWindow()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();
			LOG_Builder.ignoreTestMode = true;

			String sweepRunKey = UTIL_Random.randomUUID();
			AsyncChainExecution__c candidate = seedDeadRedriveCandidate(SEL_AsyncChainExecution.STATUS_RUNNING, sweepRunKey, buildMidChainStepLogWithErrorHandler());
			AsyncChainExecution__c sweepView = queryExecution(candidate.Id);
			String persistedStepLog = sweepView.StepLog__c;
			TST_Mock.registerNext(AsyncChainExecution__c.SObjectType, sweepView);
			TST_Mock.registerNext(AsyncChainExecution__c.SObjectType,
					buildFreshReadMock(candidate.Id, UTIL_Random.randomUUID(), SEL_AsyncChainExecution.STATUS_RUNNING, null, null, null));

			Integer executorsQueued = countJobsQueuedByRedrive(sweepView);

			AsyncChainExecution__c after = queryExecution(candidate.Id);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_RUNNING, after.Status__c, 'Expected the row to keep Running, got ' + after.Status__c);
			Assert.areEqual(sweepRunKey, after.RunKey__c, 'Expected the fenced re-drive to leave the run key as it was');
			Assert.areEqual(persistedStepLog, after.StepLog__c, 'Expected the persisted step log to read as before the fenced re-drive');
			Assert.areEqual(0, executorsQueued, 'Expected no recovery executor queued by a fenced re-drive, got ' + executorsQueued);
			Assert.isTrue(hasLogEntryAtLevelContaining(LOG_LEVEL_WARN, STALE_KEY_LOG_FRAGMENT), 'Expected a warning naming the fenced write');
			Assert.isFalse(hasLogEntryAtLevelContaining(LOG_LEVEL_ERROR, REFUSAL_LOG_FRAGMENT), 'Expected the run key check, not the list of allowed moves, to refuse the write');
		}
	}

	/**
	 * @description A re-driven run is Running again, and a Running run cannot have an end time. The sweep's re-drive leg
	 * reads a running candidate under the key it saw, and the function's fresh read answers the same run under the same
	 * key but carrying an end time (a shape no engine write leaves, so it is mocked, never inserted). The re-drive clears
	 * the stall category but keeps the end time, so the function refuses it: the row keeps its status and its run key, no
	 * executor is queued and one error log names the rule the write would break.
	 */
	@IsTest
	private static void shouldRefuseARedriveOverARunningRowCarryingAnEndTime()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();
			LOG_Builder.ignoreTestMode = true;

			String sweepRunKey = UTIL_Random.randomUUID();
			AsyncChainExecution__c candidate = seedDeadRedriveCandidate(SEL_AsyncChainExecution.STATUS_RUNNING, sweepRunKey, buildMidChainStepLogWithErrorHandler());
			AsyncChainExecution__c sweepView = queryExecution(candidate.Id);
			TST_Mock.registerNext(AsyncChainExecution__c.SObjectType, sweepView);
			TST_Mock.registerNext(AsyncChainExecution__c.SObjectType,
					buildFreshReadMock(candidate.Id, sweepRunKey, SEL_AsyncChainExecution.STATUS_RUNNING, Datetime.now(), null, null));

			Integer executorsQueued = countJobsQueuedByRedrive(sweepView);

			AsyncChainExecution__c after = queryExecution(candidate.Id);
			Assert.areEqual(0, executorsQueued, 'Expected no recovery executor queued by a refused re-drive, got ' + executorsQueued);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_RUNNING, after.Status__c, 'Expected the row to keep Running, got ' + after.Status__c);
			Assert.areEqual(sweepRunKey, after.RunKey__c, 'Expected the refused re-drive to leave the run key as it was');
			Assert.isTrue(hasLogEntryAtLevelContaining(LOG_LEVEL_ERROR, REFUSAL_LOG_FRAGMENT + ' ' + RUN_EVENT_WATCHDOG_REDRIVEN + ' from '
					+ SEL_AsyncChainExecution.STATUS_RUNNING + ': ' + RUNNING_WITH_END_TIME_REASON), 'Expected an error log naming the rule the re-drive would break');
		}
	}

	/**
	 * @description The Finalizer must never throw. A chain fails its step and its error handler cannot be queued, so the
	 * Finalizer writes the handler note. Its fresh read answers a Failed row the list of allowed moves accepts, but under an
	 * Id no saved row has (mocked, never inserted), so the save fails for a reason that is not a refused transition. The
	 * Finalizer logs the failed save at ERROR and returns: the row keeps what the step failure wrote, with no note after
	 * the message, and the error handler never runs.
	 */
	@IsTest
	private static void shouldLogTheFailedSaveWhenTheHandlerNoteCannotBeWritten()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();
			LOG_Builder.ignoreTestMode = true;
			configuredFailureMessage = TRANSIENT_ENQUEUE_FAILURE;

			String executionId = launchFailingChainWhoseErrorHandlerCannotBeQueuedWhileTheFreshRowReads(SEL_AsyncChainExecution.STATUS_FAILED, Datetime.now(),
					SEL_AsyncChainExecution.FAILURE_CATEGORY_STEP_EXCEPTION, null, UTIL_Random.randomId(AsyncChainExecution__c.SObjectType));

			AsyncChainExecution__c execution = queryExecution(executionId);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_FAILED, execution.Status__c, 'Expected the step failure to stand, got ' + execution.Status__c);
			Assert.areEqual(TRANSIENT_ENQUEUE_FAILURE, execution.ErrorMessage__c, 'Expected the step message alone, with no handler note after it');
			Assert.areEqual(0, errorHandlerRunCount, 'Expected the error handler not to run, got ' + errorHandlerRunCount + ' run(s)');
			Assert.isTrue(hasLogEntryAtLevelContaining(LOG_LEVEL_ERROR, HANDLER_NOTE_WRITE_FAILED_LOG_FRAGMENT),
					'Expected an error log naming the failed save of the handler note');
		}
	}

	/**
	 * @description An operator retry re-enters a Failed run only. The retry's availability check reads the run Failed and
	 * retryable, but the function's fresh read answers Running (a second operator's retry landed in between): the list of
	 * allowed moves refuses OPERATOR_RETRIED from Running, the action answers ChainNotRetryable with no result, the row
	 * keeps what the availability check read, no executor is queued and one error log names the refusal.
	 */
	@IsTest
	private static void shouldRefuseAnOperatorRetryWhenTheRunLeftFailedBeforeTheWrite()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();
			LOG_Builder.ignoreTestMode = true;

			AsyncChainExecution__c failed = seedFailedRetryCandidate();
			AsyncChainExecution__c before = queryExecution(failed.Id);
			TST_Mock.registerNext(AsyncChainExecution__c.SObjectType, before);
			TST_Mock.registerNext(AsyncChainExecution__c.SObjectType,
					buildFreshReadMock(failed.Id, before.RunKey__c, SEL_AsyncChainExecution.STATUS_RUNNING, null, null, null));

			Test.startTest();
			Integer queuedBefore = UTIL_Limits.queueableJobs().used();
			UTIL_AsyncChain.OperatorActionOutcome outcome = UTIL_AsyncChain.retryChainFromFailedStep(failed.Id);
			Integer queuedAfter = UTIL_Limits.queueableJobs().used();
			Test.stopTest();
			Test.getEventBus().deliver();

			Assert.areEqual(UTIL_AsyncChain.REDRIVE_CHAIN_NOT_RETRYABLE, outcome.refusalCode, 'Expected the refused retry to answer ChainNotRetryable, got ' + outcome.refusalCode);
			Assert.isNull(outcome.resultId, 'Expected no result from a refused retry');
			assertRowUnchanged(before, SEL_AsyncChainExecution.STATUS_FAILED);
			AsyncChainExecution__c after = queryExecution(failed.Id);
			Assert.areEqual(before.RunKey__c, after.RunKey__c, 'Expected no rotation from a refused retry');
			Assert.isNull(after.LastManualRetryAt__c, 'Expected no retry stamp from a refused retry');
			Assert.areEqual(queuedBefore, queuedAfter, 'Expected no recovery executor queued by a refused retry, got ' + (queuedAfter - queuedBefore));
			Assert.isTrue(hasLogEntryAtLevelContaining(LOG_LEVEL_ERROR, REFUSAL_LOG_FRAGMENT + ' ' + RUN_EVENT_OPERATOR_RETRIED + ' from '
					+ SEL_AsyncChainExecution.STATUS_RUNNING), 'Expected an error log naming the refused retry from Running');
		}
	}

	/**
	 * @description An operator abort acts on a run that is still going; a run already Aborted is not its to abort again.
	 * The abort finds the row Aborted with the OperatorAbort category and an end time: the list of allowed moves refuses
	 * OPERATOR_ABORTED from Aborted, the abort answers false, the row keeps its status, category, end time and message, and
	 * one error log names the refusal.
	 */
	@IsTest
	private static void shouldRefuseAnOperatorAbortOverAnAbortedRow()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();
			LOG_Builder.ignoreTestMode = true;

			AsyncChainExecution__c execution = persistRunningExecutionWithKey(UTIL_Random.randomUUID());
			flipToAborted(execution.Id);
			AsyncChainExecution__c aborted = queryExecution(execution.Id);

			Test.startTest();
			Boolean abortedAgain = UTIL_AsyncChain.abortExecution(execution.Id, OPERATOR_ABORT_REASON);
			Test.stopTest();
			Test.getEventBus().deliver();

			Assert.isFalse(abortedAgain, 'Expected the abort of an Aborted run to be refused');
			assertRowUnchanged(aborted, SEL_AsyncChainExecution.STATUS_ABORTED);
			Assert.areEqual(SEL_AsyncChainExecution.FAILURE_CATEGORY_OPERATOR_ABORT, queryExecution(execution.Id).FailureCategory__c,
					'Expected the category to read as before the refused abort');
			Assert.isTrue(hasLogEntryAtLevelContaining(LOG_LEVEL_ERROR, REFUSAL_LOG_FRAGMENT + ' ' + RUN_EVENT_OPERATOR_ABORTED + ' from '
					+ SEL_AsyncChainExecution.STATUS_ABORTED), 'Expected an error log naming the refused operator abort from Aborted');
		}
	}

	/**
	 * @description Every status change written straight to the database, not through the engine, meets the trigger
	 * backstop. From a Running row, each of the six target statuses is tried with fields that fit the target: the five
	 * moves the engine makes land and the row fits its new status; the move to Delayed is refused with the label's text
	 * and the row keeps its fields.
	 */
	@IsTest
	private static void shouldLandEveryAllowedPairAndRefuseEveryOtherPairFromRunningThroughTheTrigger()
	{
		System.runAs(getTestAdmin())
		{
			assertEveryPairStartingFrom(SEL_AsyncChainExecution.STATUS_RUNNING);
		}
	}

	/**
	 * @description From a Stalled row, each of the six target statuses is tried straight against the database with fields
	 * that fit the target: the five moves the engine makes land and the row fits its new status; the move to Delayed is
	 * refused with the label's text and the row keeps its fields.
	 */
	@IsTest
	private static void shouldLandEveryAllowedPairAndRefuseEveryOtherPairFromStalledThroughTheTrigger()
	{
		System.runAs(getTestAdmin())
		{
			assertEveryPairStartingFrom(SEL_AsyncChainExecution.STATUS_STALLED);
		}
	}

	/**
	 * @description From a Failed row, each of the six target statuses is tried straight against the database with fields
	 * that fit the target: the operator retry to Running and a write that keeps Failed land; the moves to Stalled (the
	 * shape an older release could leave), Completed, Aborted and Delayed are refused with the label's text and the row
	 * keeps its fields.
	 */
	@IsTest
	private static void shouldLandEveryAllowedPairAndRefuseEveryOtherPairFromFailedThroughTheTrigger()
	{
		System.runAs(getTestAdmin())
		{
			assertEveryPairStartingFrom(SEL_AsyncChainExecution.STATUS_FAILED);
		}
	}

	/**
	 * @description From a Completed row, each of the six target statuses is tried straight against the database with
	 * fields that fit the target: a write that keeps Completed and the handler failure to Failed land; the moves to
	 * Running, Stalled (the shape an older release could leave), Aborted and Delayed are refused with the label's text
	 * and the row keeps its fields.
	 */
	@IsTest
	private static void shouldLandEveryAllowedPairAndRefuseEveryOtherPairFromCompletedThroughTheTrigger()
	{
		System.runAs(getTestAdmin())
		{
			assertEveryPairStartingFrom(SEL_AsyncChainExecution.STATUS_COMPLETED);
		}
	}

	/**
	 * @description From an Aborted row, each of the six target statuses is tried straight against the database with
	 * fields that fit the target: only a write that keeps Aborted lands; every other move is refused with the label's
	 * text and the row keeps its fields.
	 */
	@IsTest
	private static void shouldLandEveryAllowedPairAndRefuseEveryOtherPairFromAbortedThroughTheTrigger()
	{
		System.runAs(getTestAdmin())
		{
			assertEveryPairStartingFrom(SEL_AsyncChainExecution.STATUS_ABORTED);
		}
	}

	/**
	 * @description An end time never changes once it is set. A Failed row written again with a later end time, straight
	 * against the database, is refused by the trigger backstop with the label's text, and the row keeps the end time it
	 * had.
	 */
	@IsTest
	private static void shouldRefuseAChangedEndTimeThroughTheTrigger()
	{
		System.runAs(getTestAdmin())
		{
			AsyncChainExecution__c execution = TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_RUNNING, TEST_CHAIN_NAME);
			flipToFailed(execution.Id);
			AsyncChainExecution__c failed = queryExecution(execution.Id);
			AsyncChainExecution__c write = buildStatusWrite(execution.Id, SEL_AsyncChainExecution.STATUS_FAILED,
					failed.CompletedAt__c.addMinutes(LATER_END_TIME_OFFSET_MINUTES), SEL_AsyncChainExecution.FAILURE_CATEGORY_STEP_EXCEPTION);

			assertWriteRefusedByTheTrigger(write, failed, SEL_AsyncChainExecution.STATUS_FAILED, SEL_AsyncChainExecution.STATUS_FAILED);
		}
	}

	/**
	 * @description A Stalled run cannot have an end time. A Running row written Stalled with an end time, the shape an
	 * older release could leave, straight against the database, is refused by the trigger backstop even though Running
	 * to Stalled is a move the engine makes, and the row stays Running.
	 */
	@IsTest
	private static void shouldRefuseAStalledRowWithAnEndTimeThroughTheTrigger()
	{
		System.runAs(getTestAdmin())
		{
			AsyncChainExecution__c execution = TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_RUNNING, TEST_CHAIN_NAME);
			AsyncChainExecution__c running = queryExecution(execution.Id);
			AsyncChainExecution__c write = buildStatusWrite(execution.Id, SEL_AsyncChainExecution.STATUS_STALLED, Datetime.now(), SEL_AsyncChainExecution.FAILURE_CATEGORY_STALLED);

			assertWriteRefusedByTheTrigger(write, running, SEL_AsyncChainExecution.STATUS_RUNNING, SEL_AsyncChainExecution.STATUS_STALLED);
		}
	}

	/**
	 * @description A write that carries the status the row already has is not a status change. A Failed row written
	 * with Failed and a new message, as the engine writes a note about a handler, lands: the trigger backstop compares
	 * the old and the new status and leaves an equal pair alone.
	 */
	@IsTest
	private static void shouldNotReadAnUnchangedStatusAsAMove()
	{
		System.runAs(getTestAdmin())
		{
			AsyncChainExecution__c execution = TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_RUNNING, TEST_CHAIN_NAME);
			flipToFailed(execution.Id);
			AsyncChainExecution__c failed = queryExecution(execution.Id);
			AsyncChainExecution__c write = buildStatusWrite(execution.Id, SEL_AsyncChainExecution.STATUS_FAILED, failed.CompletedAt__c,
					SEL_AsyncChainExecution.FAILURE_CATEGORY_STEP_EXCEPTION);
			write.ErrorMessage__c = CHANGED_MESSAGE;

			DML_Builder.newTransaction().systemModeInternal().doUpdate(write).execute();

			AsyncChainExecution__c after = queryExecution(execution.Id);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_FAILED, after.Status__c, 'Expected the row to stay Failed, got ' + after.Status__c);
			Assert.areEqual(CHANGED_MESSAGE, after.ErrorMessage__c, 'Expected the write with an unchanged status to land');
			Assert.areEqual(failed.CompletedAt__c, after.CompletedAt__c, 'Expected the end time to read as before the write');
		}
	}

	/**
	 * @description The Finalizer's crash write loses a race. Its fresh read answers Running, but by the time it writes an
	 * operator has moved the run to Aborted, and Aborted to Failed is a move the engine never makes, so the trigger
	 * backstop refuses the write. The transition function catches that one refusal, writes an error log that starts
	 * with the backstop phrase and answers false. The row stays Aborted with its category, the Finalizer throws nothing
	 * (the test would end in error if it did), and the Finalizer's own catch, which is for every other write failure,
	 * never runs.
	 */
	@IsTest
	private static void shouldLogAndReturnFalseWhenTheBackstopRefusesTheFunctionsWrite()
	{
		System.runAs(getTestAdmin())
		{
			setupEnabledFeatureFlag();
			LOG_Builder.ignoreTestMode = true;

			String runKey = UTIL_Random.randomUUID();
			AsyncChainExecution__c execution = persistRunningExecutionWithKey(runKey);
			flipToAborted(execution.Id);
			AsyncChainExecution__c aborted = queryExecution(execution.Id);
			TST_Mock.registerNext(AsyncChainExecution__c.SObjectType,
					buildFreshReadMock(execution.Id, runKey, SEL_AsyncChainExecution.STATUS_RUNNING, null, null, null));
			UTIL_AsyncChain.ChainExecutor executor = buildExecutorWithCountingErrorHandler(execution.Id, runKey);

			Test.startTest();
			executor.markChainFailedFromFinalizer(execution.Id, SIMULATED_CRASH_REASON);
			Test.stopTest();
			Test.getEventBus().deliver();

			assertRowUnchanged(aborted, SEL_AsyncChainExecution.STATUS_ABORTED);
			Assert.areEqual(SEL_AsyncChainExecution.FAILURE_CATEGORY_OPERATOR_ABORT, queryExecution(execution.Id).FailureCategory__c,
					'Expected the category to read as before the refused write');
			Assert.isTrue(hasLogEntryAtLevelContaining(LOG_LEVEL_ERROR, BACKSTOP_REFUSAL_LOG_FRAGMENT), 'Expected an error log that starts with the backstop phrase');
			Assert.isFalse(hasLogEntryAtLevelContaining(LOG_LEVEL_ERROR, FINALIZER_DML_FAILED_FRAGMENT), 'Expected the function, not the Finalizer, to handle the refusal');
		}
	}

	/**
	 * @description Walks the six (from, to) pairs that start from one status, each on its own row born Running and moved
	 * to the starting status by one legal write. The write into the target carries fields that fit the target, so only
	 * the status decides. An allowed pair lands and the row fits its new status; a refused pair fails with the label's
	 * text and the row keeps its fields.
	 *
	 * @param fromStatus The status every row starts from.
	 */
	private static void assertEveryPairStartingFrom(String fromStatus)
	{
		Integer pairsFromStatus = 0;
		List<StatusPair> pairs = buildExpectedStatusPairs();
		Assert.areEqual(STATUS_PAIR_COUNT, pairs.size(), 'Expected the hand-written table to hold ' + STATUS_PAIR_COUNT + ' rows, got ' + pairs.size());
		for(StatusPair pair : pairs)
		{
			if(pair.fromStatus != fromStatus)
			{
				continue;
			}
			pairsFromStatus++;
			AsyncChainExecution__c execution = TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_RUNNING, TEST_CHAIN_NAME);
			moveToStartingStatus(execution.Id, fromStatus);
			AsyncChainExecution__c before = queryExecution(execution.Id);
			AsyncChainExecution__c write = buildConsistentWrite(before, pair.toStatus);
			if(pair.allowed)
			{
				DML_Builder.newTransaction().systemModeInternal().doUpdate(write).execute();
				AsyncChainExecution__c after = queryExecution(execution.Id);
				Assert.areEqual(pair.toStatus, after.Status__c, 'Expected the move from ' + fromStatus + ' to ' + pair.toStatus + ' to land');
				assertRowFitsItsStatus(after);
			}
			else
			{
				assertWriteRefusedByTheTrigger(write, before, fromStatus, pair.toStatus);
			}
		}
		Assert.areEqual(PAIRS_PER_STARTING_STATUS, pairsFromStatus, 'Expected ' + PAIRS_PER_STARTING_STATUS + ' pairs from ' + fromStatus + ', got ' + pairsFromStatus);
	}

	/**
	 * @description Moves a row born Running to the given starting status by one write the engine makes: Stalled with the
	 * Stalled category; Completed with an end time; Failed with an end time and the StepException category; Aborted with
	 * an end time and the OperatorAbort category. A Running row stays as born.
	 *
	 * @param executionId The row to move.
	 * @param fromStatus The status the row must read before the pair's write.
	 */
	private static void moveToStartingStatus(Id executionId, String fromStatus)
	{
		if(fromStatus == SEL_AsyncChainExecution.STATUS_RUNNING)
		{
			return;
		}
		Datetime completedAt = FINISHED_STATUSES.contains(fromStatus) ? Datetime.now() : null;
		flipStatus(executionId, fromStatus, completedAt, FAILURE_CATEGORY_BY_STATUS.get(fromStatus));
	}

	/**
	 * @description Builds the write into a target status with fields that fit the target, so only the status decides
	 * whether the trigger backstop lets it through. Into Running: no end time and no category. Into Stalled: no end
	 * time, the Stalled category. Into a finished status: the end time the row already has, or now when it has none
	 * (an end time, once set, must not change), and the category the status needs. Into Delayed: no end time and no
	 * category.
	 *
	 * @param before The row as it reads before the write.
	 * @param toStatus The status the write asks for.
	 *
	 * @return The sparse write, not yet executed.
	 */
	private static AsyncChainExecution__c buildConsistentWrite(AsyncChainExecution__c before, String toStatus)
	{
		Datetime completedAt = FINISHED_STATUSES.contains(toStatus) ? (before.CompletedAt__c ?? Datetime.now()) : null;
		return buildStatusWrite(before.Id, toStatus, completedAt, FAILURE_CATEGORY_BY_STATUS.get(toStatus));
	}

	/**
	 * @description Asserts a row read back from the database fits its status: a Running row has no end time and no
	 * failure category; a Stalled row has no end time and no duration; a finished row has an end time and no active
	 * deduplication key; a Failed or Aborted row has a failure category.
	 *
	 * @param row The row as read back after a landed write.
	 */
	private static void assertRowFitsItsStatus(AsyncChainExecution__c row)
	{
		String status = row.Status__c;
		if(status == SEL_AsyncChainExecution.STATUS_RUNNING)
		{
			Assert.isNull(row.CompletedAt__c, 'Expected a Running row to have no end time');
			Assert.isNull(row.FailureCategory__c, 'Expected a Running row to have no failure category');
		}
		if(status == SEL_AsyncChainExecution.STATUS_STALLED)
		{
			Assert.isNull(row.CompletedAt__c, 'Expected a Stalled row to have no end time');
			Assert.isNull(row.DurationMs__c, 'Expected a Stalled row to have no duration');
		}
		if(FINISHED_STATUSES.contains(status))
		{
			Assert.isNotNull(row.CompletedAt__c, 'Expected a ' + status + ' row to have an end time');
			Assert.isNull(row.ActiveDeduplicationKey__c, 'Expected a ' + status + ' row to hold no active deduplication key');
		}
		if(status == SEL_AsyncChainExecution.STATUS_FAILED || status == SEL_AsyncChainExecution.STATUS_ABORTED)
		{
			Assert.isNotNull(row.FailureCategory__c, 'Expected a ' + status + ' row to have a failure category');
		}
	}

	/**
	 * @description Executes the write and asserts the trigger backstop refused it: the write fails with a DmlException
	 * whose message carries the AsyncChain_TransitionRefused label for the two statuses, and the row, read again from
	 * the database, keeps its status, its end time and its failure category.
	 *
	 * @param write The sparse write to execute.
	 * @param before The row as it read before the write.
	 * @param fromStatus The status the row has.
	 * @param toStatus The status the write asks for.
	 */
	private static void assertWriteRefusedByTheTrigger(AsyncChainExecution__c write, AsyncChainExecution__c before, String fromStatus, String toStatus)
	{
		String move = 'the move from ' + fromStatus + ' to ' + toStatus;
		try
		{
			DML_Builder.newTransaction().systemModeInternal().doUpdate(write).execute();
			Assert.fail('Expected the trigger backstop to refuse ' + move);
		}
		catch(Exception error)
		{
			Assert.isInstanceOfType(error, DmlException.class,
					'Expected a DmlException for ' + move + ', got ' + error.getTypeName() + ': ' + error.getMessage());
			String expectedText = String.format(System.Label.AsyncChain_TransitionRefused, new List<String> {fromStatus, toStatus});
			Assert.isTrue(error.getMessage().contains(expectedText), 'Expected the refusal of ' + move + ' to carry the label text, got ' + error.getMessage());
		}
		QRY_Engine.clearQueryResultMemoryCache();
		AsyncChainExecution__c after = queryExecution(before.Id);
		Assert.areEqual(before.Status__c, after.Status__c, 'Expected the row to keep ' + before.Status__c + ' after the refused ' + move);
		Assert.areEqual(before.CompletedAt__c, after.CompletedAt__c, 'Expected the end time to read as before the refused ' + move);
		Assert.areEqual(before.FailureCategory__c, after.FailureCategory__c, 'Expected the failure category to read as before the refused ' + move);
	}

	/**
	 * @description Runs the sweep's degrade over a stalled candidate another actor ended in the window and checks the
	 * refusal: the candidate's step log has every step attempted, so the re-drive leg degrades; the row is moved to the
	 * given status, category and an end time STAMP_AGE_MINUTES in the past before the leg runs, while the leg's entry
	 * read is scripted to answer the stalled candidate as the sweep saw it, so the function's fresh read is what meets
	 * the moved row. Afterwards the row reads as moved, its run key is not rotated, no notification was queued, the
	 * counting handler never ran and one error log names the refused degrade from that status.
	 *
	 * @param movedStatus The status the other actor ended the run with.
	 * @param movedFailureCategory The category the other actor set, or null.
	 */
	private static void assertDegradeRefusedOverARunMovedTo(String movedStatus, String movedFailureCategory)
	{
		AsyncChainExecution__c candidate = seedDeadRedriveCandidate(SEL_AsyncChainExecution.STATUS_STALLED, UTIL_Random.randomUUID(), buildAllAttemptedStepLogWithErrorHandler());
		AsyncChainExecution__c sweepView = queryExecution(candidate.Id);
		flipStatus(candidate.Id, movedStatus, Datetime.now().addMinutes(-STAMP_AGE_MINUTES), movedFailureCategory);
		AsyncChainExecution__c moved = queryExecution(candidate.Id);
		TST_Mock.registerNext(AsyncChainExecution__c.SObjectType, sweepView);

		Integer notificationsQueued = countJobsQueuedByRedrive(sweepView);

		AsyncChainExecution__c after = queryExecution(candidate.Id);
		assertMovedRunKept(after, movedStatus, movedFailureCategory);
		Assert.areEqual(moved.CompletedAt__c, after.CompletedAt__c, 'Expected the end time the other actor set to stay');
		Assert.areEqual(sweepView.RunKey__c, after.RunKey__c, 'Expected no rotation from a refused degrade');
		Assert.areEqual(0, notificationsQueued, 'Expected no notification queued by a refused degrade, got ' + notificationsQueued);
		Assert.isTrue(hasLogEntryAtLevelContaining(LOG_LEVEL_ERROR, REFUSAL_LOG_FRAGMENT + ' ' + RUN_EVENT_RECOVERY_DEGRADED + ' from ' + movedStatus),
				'Expected an error log naming the refused degrade from ' + movedStatus);
	}

	/**
	 * @description Launches a one-step chain whose step moves its own run to movedRunStatus with movedRunFailureCategory
	 * and an end time STAMP_AGE_MINUTES in the past, then fails with configuredFailureMessage, with the counting error
	 * handler registered, so the executor's step failure write meets a run that has already ended.
	 *
	 * @return The execution record Id.
	 */
	private static String launchChainWhoseStepMovesItsRunThenFails()
	{
		Test.startTest();
		String executionId = UTIL_AsyncChain.newChain(TEST_CHAIN_NAME)
				.then(new UTIL_AsyncChainTransition_TEST.MoveRunThenFailStep())
				.onError(new UTIL_AsyncChainTransition_TEST.CountingErrorHandlerStep())
				.withAsyncOptions(createAsyncOptions(2))
				.execute();
		Test.stopTest();
		Test.getEventBus().deliver();
		return executionId;
	}

	/**
	 * @description Runs a handler built for a Failed run, with the matching run key, over a row that reads Running and
	 * holds a deduplication key, through the real handler queueable, so the handler's write-back meets a run that is
	 * going again.
	 *
	 * @param handler The handler step definition to run.
	 *
	 * @return The Running row as persisted, before the handler ran.
	 */
	private static AsyncChainExecution__c runHandlerOverARunningRow(UTIL_AsyncChain.DTO_StepDefinition handler)
	{
		String runKey = UTIL_Random.randomUUID();
		AsyncChainExecution__c running = persistRunningExecutionHoldingKey(runKey, UTIL_Random.randomUUID());
		UTIL_AsyncChain.HandlerExecutor handlerExecutor = buildHandlerExecutor(running.Id, handler, SEL_AsyncChainExecution.STATUS_FAILED, ORIGINAL_FAILURE_REASON, runKey);

		Test.startTest();
		System.enqueueJob(handlerExecutor);
		Test.stopTest();
		Test.getEventBus().deliver();
		return running;
	}

	/**
	 * @description Checks that a handler's write-back over a Running row was refused: the row keeps Running with no end
	 * time, no category, no message and no context, still holds its deduplication key, and one error log names the
	 * refused run event from Running.
	 *
	 * @param running The Running row as persisted before the handler ran.
	 * @param runEventName The handler run event the log must name.
	 */
	private static void assertHandlerWriteRefusedOverRunningRow(AsyncChainExecution__c running, String runEventName)
	{
		AsyncChainExecution__c after = queryExecution(running.Id);
		Assert.areEqual(SEL_AsyncChainExecution.STATUS_RUNNING, after.Status__c, 'Expected the row to keep Running, got ' + after.Status__c);
		Assert.isNull(after.CompletedAt__c, 'Expected no end time from a refused handler write-back');
		Assert.isNull(after.FailureCategory__c, 'Expected no category from a refused handler write-back');
		Assert.isNull(after.ErrorMessage__c, 'Expected no message from a refused handler write-back');
		Assert.isNull(after.ContextData__c, 'Expected the handler\'s context not to reach the row');
		Assert.areEqual(running.ActiveDeduplicationKey__c, after.ActiveDeduplicationKey__c, 'Expected the held deduplication key to stay');
		Assert.isTrue(hasLogEntryAtLevelContaining(LOG_LEVEL_ERROR, REFUSAL_LOG_FRAGMENT + ' ' + runEventName + ' from ' + SEL_AsyncChainExecution.STATUS_RUNNING),
				'Expected an error log naming the refused ' + runEventName + ' from Running');
	}

	/**
	 * @description Checks that an executor's terminal write over a run another actor had already ended was refused: the
	 * row keeps that status and category, its end time is the one set STAMP_AGE_MINUTES in the past (a stamp this old
	 * cannot be the executor's), no message landed, and the counting error handler never ran.
	 *
	 * @param execution The row read back.
	 * @param expectedStatus The status the other actor set.
	 * @param expectedFailureCategory The category the other actor set, or null.
	 */
	private static void assertMovedRunKept(AsyncChainExecution__c execution, String expectedStatus, String expectedFailureCategory)
	{
		Assert.areEqual(expectedStatus, execution.Status__c, 'Expected the row to keep ' + expectedStatus + ', got ' + execution.Status__c);
		Assert.areEqual(expectedFailureCategory, execution.FailureCategory__c, 'Expected the category to read as the other actor set it');
		Assert.isTrue(execution.CompletedAt__c <= Datetime.now().addMinutes(-STAMP_AGE_MINUTES), 'Expected the end time set in the past to stay, not a fresh one');
		Assert.isNull(execution.ErrorMessage__c, 'Expected no message from a refused terminal write');
		Assert.areEqual(0, errorHandlerRunCount, 'Expected no error handler from a refused terminal write, got ' + errorHandlerRunCount + ' run(s)');
	}

	/**
	 * @description Launches a one-step chain whose step fails with configuredFailureMessage, with the given error handler,
	 * and makes the Finalizer's handler enqueue fail, so the chain ends Failed with the handler note on its row.
	 *
	 * @param errorHandler The error handler step to register.
	 *
	 * @return The execution record Id.
	 */
	private static String launchFailingChainWhoseErrorHandlerCannotBeQueued(UTIL_AsyncChain.ChainStep errorHandler)
	{
		Test.startTest();
		String executionId = UTIL_AsyncChain.newChain(TEST_CHAIN_NAME)
				.then(new UTIL_AsyncChainTransition_TEST.FailingWithConfiguredMessageStep())
				.onError(errorHandler)
				.withAsyncOptions(createAsyncOptions(2))
				.execute();
		UTIL_AsyncChain.simulateEnqueueFailure = true;
		Test.stopTest();
		UTIL_AsyncChain.simulateEnqueueFailure = false;
		Test.getEventBus().deliver();
		return executionId;
	}

	/**
	 * @description Runs the sweep's re-drive leg for one candidate inside Test.startTest and Test.stopTest, then delivers
	 * the log events, and counts the queueable jobs the re-drive queued.
	 *
	 * @param sweepView The candidate as the sweep read it.
	 *
	 * @return The number of queueable jobs the re-drive queued.
	 */
	private static Integer countJobsQueuedByRedrive(AsyncChainExecution__c sweepView)
	{
		Test.startTest();
		Integer queuedBefore = UTIL_Limits.queueableJobs().used();
		UTIL_AsyncChain.redriveStalledChain(sweepView);
		Integer queuedAfter = UTIL_Limits.queueableJobs().used();
		Test.stopTest();
		Test.getEventBus().deliver();
		return queuedAfter - queuedBefore;
	}

	/**
	 * @description Launches a one-step chain whose step fails with configuredFailureMessage and whose counting error
	 * handler cannot be queued, exactly as launchFailingChainWhoseErrorHandlerCannotBeQueued does, but scripts the
	 * execution record's reads so the Finalizer's fresh read answers a row another actor moved after the terminal write:
	 * the executor's entry read and the terminal write's fence read answer the launched row as stored, the third read
	 * (the transition function's) answers the given shape, and every later read goes to the database. The moved shape is
	 * mocked, never inserted, because the backstop forbids some of these shapes.
	 *
	 * @param status The status the fresh read answers.
	 * @param completedAt The completion stamp the fresh read answers, or null.
	 * @param failureCategory The failure category the fresh read answers, or null.
	 *
	 * @return The execution record Id.
	 */
	private static String launchFailingChainWhoseErrorHandlerCannotBeQueuedWhileTheFreshRowReads(String status, Datetime completedAt, String failureCategory)
	{
		return launchFailingChainWhoseErrorHandlerCannotBeQueuedWhileTheFreshRowReads(status, completedAt, failureCategory, null);
	}

	/**
	 * @description The four-argument form of launchFailingChainWhoseErrorHandlerCannotBeQueuedWhileTheFreshRowReads, for a
	 * fresh read that also answers an active deduplication key.
	 *
	 * @param status The status the fresh read answers.
	 * @param completedAt The completion stamp the fresh read answers, or null.
	 * @param failureCategory The failure category the fresh read answers, or null.
	 * @param activeDeduplicationKey The active deduplication key the fresh read answers, or null.
	 *
	 * @return The execution record Id.
	 */
	private static String launchFailingChainWhoseErrorHandlerCannotBeQueuedWhileTheFreshRowReads
			(
					String status, Datetime completedAt, String failureCategory, String activeDeduplicationKey
			)
	{
		return launchFailingChainWhoseErrorHandlerCannotBeQueuedWhileTheFreshRowReads(status, completedAt, failureCategory, activeDeduplicationKey, null);
	}

	/**
	 * @description The five-argument form of launchFailingChainWhoseErrorHandlerCannotBeQueuedWhileTheFreshRowReads, for a
	 * fresh read that answers under another Id than the launched run's. A row under an Id no saved row has makes the
	 * Finalizer's save fail for a reason that is not a refused transition.
	 *
	 * @param status The status the fresh read answers.
	 * @param completedAt The end time the fresh read answers, or null.
	 * @param failureCategory The failure category the fresh read answers, or null.
	 * @param activeDeduplicationKey The active deduplication key the fresh read answers, or null.
	 * @param freshReadId The Id the fresh read answers, or null for the launched run's own Id.
	 *
	 * @return The execution record Id.
	 */
	private static String launchFailingChainWhoseErrorHandlerCannotBeQueuedWhileTheFreshRowReads
			(
					String status, Datetime completedAt, String failureCategory, String activeDeduplicationKey, Id freshReadId
			)
	{
		Test.startTest();
		String executionId = startFailingChainWithCountingErrorHandler();
		AsyncChainExecution__c launched = queryExecution(executionId);
		TST_Mock.registerNext(AsyncChainExecution__c.SObjectType, launched);
		TST_Mock.registerNext(AsyncChainExecution__c.SObjectType, launched);
		TST_Mock.registerNext(AsyncChainExecution__c.SObjectType,
				buildFreshReadMock(freshReadId ?? launched.Id, launched.RunKey__c, status, completedAt, failureCategory, activeDeduplicationKey));
		UTIL_AsyncChain.simulateEnqueueFailure = true;
		Test.stopTest();
		UTIL_AsyncChain.simulateEnqueueFailure = false;
		Test.getEventBus().deliver();
		return executionId;
	}

	/**
	 * @description Starts, inside the caller's Test.startTest, a one-step chain whose step fails with
	 * configuredFailureMessage and whose error handler is the counting one.
	 *
	 * @return The execution record Id.
	 */
	private static String startFailingChainWithCountingErrorHandler()
	{
		return UTIL_AsyncChain.newChain(TEST_CHAIN_NAME)
				.then(new UTIL_AsyncChainTransition_TEST.FailingWithConfiguredMessageStep())
				.onError(new UTIL_AsyncChainTransition_TEST.CountingErrorHandlerStep())
				.withAsyncOptions(createAsyncOptions(2))
				.execute();
	}

	/**
	 * @description Checks that a handler note was refused on a chain that failed its step: the row reads exactly what the
	 * terminal write left (Failed, the step's message and nothing after it, a completion stamp), the error handler never
	 * ran, and one error log names the refused run event and the status the fresh read answered.
	 *
	 * @param executionId The execution record Id.
	 * @param statusReadBack The status the Finalizer's fresh read answered.
	 */
	private static void assertHandlerNoteRefused(String executionId, String statusReadBack)
	{
		AsyncChainExecution__c execution = queryExecution(executionId);
		Assert.areEqual(SEL_AsyncChainExecution.STATUS_FAILED, execution.Status__c, 'Expected the terminal write to stand, got ' + execution.Status__c);
		Assert.areEqual(TRANSIENT_ENQUEUE_FAILURE, execution.ErrorMessage__c, 'Expected the step message alone, with no handler note after it');
		Assert.isNotNull(execution.CompletedAt__c, 'Expected the completion stamp the terminal write set');
		Assert.areEqual(0, errorHandlerRunCount, 'Expected the error handler not to run, got ' + errorHandlerRunCount + ' run(s)');
		Assert.isTrue(hasLogEntryAtLevelContaining(LOG_LEVEL_ERROR, REFUSAL_LOG_FRAGMENT + ' ' + RUN_EVENT_HANDLER_NOT_QUEUED + ' from ' + statusReadBack),
				'Expected an error log naming the refused handler note from ' + statusReadBack);
	}

	/**
	 * @description Checks a Failed row whose step message met the field's length ahead of the handler note: the row fills
	 * the field exactly, the whole note ends it after the separator, and the message in front keeps its first characters
	 * and ends abbreviated.
	 *
	 * @param execution The row read back.
	 */
	private static void assertMessageAbbreviatedAheadOfWholeNote(AsyncChainExecution__c execution)
	{
		String separatedNote = NOTE_SEPARATOR + buildExpectedNote(ERROR_HANDLER_POSITION, CountingErrorHandlerStep.class.getName());
		Integer keptMessageLength = ERROR_MESSAGE_FIELD_LENGTH - separatedNote.length() - ELLIPSIS.length();
		Assert.areEqual(ERROR_MESSAGE_FIELD_LENGTH, execution.ErrorMessage__c.length(), 'Expected the row to fill the field exactly');
		Assert.isTrue(execution.ErrorMessage__c.endsWith(separatedNote), 'Expected the whole note at the end of the row');
		Assert.isTrue(execution.ErrorMessage__c.startsWith(FILLER_CHARACTER.repeat(keptMessageLength) + ELLIPSIS),
				'Expected the message to keep its first characters and end abbreviated');
		Assert.areEqual(0, errorHandlerRunCount, 'Expected the error handler not to run once its enqueue failed, got ' + errorHandlerRunCount + ' run(s)');
	}

	/**
	 * @description Checks that a refused transition wrote nothing: status, completion stamp and message read as they
	 * did before the call, and the counting error handler never ran.
	 *
	 * @param before The row as it read before the refused call.
	 * @param expectedStatus The status the row must still carry.
	 */
	private static void assertRowUnchanged(AsyncChainExecution__c before, String expectedStatus)
	{
		AsyncChainExecution__c after = queryExecution(before.Id);
		Assert.areEqual(expectedStatus, after.Status__c, 'Expected the row to keep ' + expectedStatus + ', got ' + after.Status__c);
		Assert.areEqual(before.CompletedAt__c, after.CompletedAt__c, 'Expected the completion stamp to read as before the refused call');
		Assert.areEqual(before.ErrorMessage__c, after.ErrorMessage__c, 'Expected the message to read as before the refused call');
		Assert.areEqual(0, errorHandlerRunCount, 'Expected no notification from a refused transition, got ' + errorHandlerRunCount + ' run(s)');
	}

	/**
	 * @description Builds the note the engine writes for a handler it could not queue: the label with the position and
	 * the handler name, then the separator and the simulated enqueue failure's reason.
	 *
	 * @param position The handler position, onError or onComplete.
	 * @param handlerName The handler's display name.
	 *
	 * @return The expected note.
	 */
	private static String buildExpectedNote(String position, String handlerName)
	{
		return String.format(HANDLER_NOT_QUEUED_NOTE_FORMAT, new List<String> {position, handlerName}) + REASON_SEPARATOR + SIMULATED_HANDLER_ENQUEUE_FAILURE;
	}

	/**
	 * @description The five written statuses plus the reserved one, for the Delayed walk.
	 *
	 * @return The six status values.
	 */
	private static List<String> listAllStatuses()
	{
		return new List<String>
		{
				SEL_AsyncChainExecution.STATUS_RUNNING,
				SEL_AsyncChainExecution.STATUS_STALLED,
				SEL_AsyncChainExecution.STATUS_COMPLETED,
				SEL_AsyncChainExecution.STATUS_FAILED,
				SEL_AsyncChainExecution.STATUS_ABORTED,
				STATUS_DELAYED
		};
	}

	/**
	 * @description The hand-written run event table: thirteen run events times six statuses, every row written out. An
	 * allowed row names its target (null for a run event that keeps the status); a refused row names the run event's
	 * target so the status pair check can be asked about the same (from, target) pair. Never computed from the engine's
	 * maps.
	 *
	 * @return The 78 moves.
	 */
	@SuppressWarnings('PMD.NcssMethodCount,PMD.ExcessiveMethodLength')
	private static List<ExpectedRunEventMove> buildExpectedRunEventMoves()
	{
		String running = SEL_AsyncChainExecution.STATUS_RUNNING;
		String stalled = SEL_AsyncChainExecution.STATUS_STALLED;
		String completed = SEL_AsyncChainExecution.STATUS_COMPLETED;
		String failed = SEL_AsyncChainExecution.STATUS_FAILED;
		String aborted = SEL_AsyncChainExecution.STATUS_ABORTED;
		return new List<ExpectedRunEventMove>
		{
				new ExpectedRunEventMove(RUN_EVENT_STEP_COMPLETED, running, true, completed, DRIVER_STATUS_PAIR_CHECK),
				new ExpectedRunEventMove(RUN_EVENT_STEP_COMPLETED, stalled, true, completed, DRIVER_STATUS_PAIR_CHECK),
				new ExpectedRunEventMove(RUN_EVENT_STEP_COMPLETED, completed, false, completed, DRIVER_WRITER),
				new ExpectedRunEventMove(RUN_EVENT_STEP_COMPLETED, failed, false, completed, DRIVER_STATUS_PAIR_CHECK),
				new ExpectedRunEventMove(RUN_EVENT_STEP_COMPLETED, aborted, false, completed, DRIVER_STATUS_PAIR_CHECK),
				new ExpectedRunEventMove(RUN_EVENT_STEP_COMPLETED, STATUS_DELAYED, false, completed, DRIVER_STATUS_PAIR_CHECK),

				new ExpectedRunEventMove(RUN_EVENT_STEP_FAILED, running, true, failed, DRIVER_STATUS_PAIR_CHECK),
				new ExpectedRunEventMove(RUN_EVENT_STEP_FAILED, stalled, true, failed, DRIVER_STATUS_PAIR_CHECK),
				new ExpectedRunEventMove(RUN_EVENT_STEP_FAILED, completed, false, failed, DRIVER_WRITER),
				new ExpectedRunEventMove(RUN_EVENT_STEP_FAILED, failed, false, failed, DRIVER_WRITER),
				new ExpectedRunEventMove(RUN_EVENT_STEP_FAILED, aborted, false, failed, DRIVER_STATUS_PAIR_CHECK),
				new ExpectedRunEventMove(RUN_EVENT_STEP_FAILED, STATUS_DELAYED, false, failed, DRIVER_STATUS_PAIR_CHECK),

				new ExpectedRunEventMove(RUN_EVENT_QUEUEABLE_CRASHED, running, true, failed, DRIVER_STATUS_PAIR_CHECK),
				new ExpectedRunEventMove(RUN_EVENT_QUEUEABLE_CRASHED, stalled, true, failed, DRIVER_STATUS_PAIR_CHECK),
				new ExpectedRunEventMove(RUN_EVENT_QUEUEABLE_CRASHED, completed, false, failed, DRIVER_WRITER),
				new ExpectedRunEventMove(RUN_EVENT_QUEUEABLE_CRASHED, failed, false, failed, DRIVER_WRITER),
				new ExpectedRunEventMove(RUN_EVENT_QUEUEABLE_CRASHED, aborted, false, failed, DRIVER_STATUS_PAIR_CHECK),
				new ExpectedRunEventMove(RUN_EVENT_QUEUEABLE_CRASHED, STATUS_DELAYED, false, failed, DRIVER_STATUS_PAIR_CHECK),

				new ExpectedRunEventMove(RUN_EVENT_ENQUEUE_FAILED, running, true, stalled, DRIVER_STATUS_PAIR_CHECK),
				new ExpectedRunEventMove(RUN_EVENT_ENQUEUE_FAILED, stalled, true, stalled, DRIVER_STATUS_PAIR_CHECK),
				new ExpectedRunEventMove(RUN_EVENT_ENQUEUE_FAILED, completed, false, stalled, DRIVER_STATUS_PAIR_CHECK),
				new ExpectedRunEventMove(RUN_EVENT_ENQUEUE_FAILED, failed, false, stalled, DRIVER_STATUS_PAIR_CHECK),
				new ExpectedRunEventMove(RUN_EVENT_ENQUEUE_FAILED, aborted, false, stalled, DRIVER_STATUS_PAIR_CHECK),
				new ExpectedRunEventMove(RUN_EVENT_ENQUEUE_FAILED, STATUS_DELAYED, false, stalled, DRIVER_STATUS_PAIR_CHECK),

				new ExpectedRunEventMove(RUN_EVENT_HANDLER_NOT_QUEUED, running, false, null, DRIVER_WRITER),
				new ExpectedRunEventMove(RUN_EVENT_HANDLER_NOT_QUEUED, stalled, false, null, DRIVER_WRITER),
				new ExpectedRunEventMove(RUN_EVENT_HANDLER_NOT_QUEUED, completed, true, null, DRIVER_STATUS_PAIR_CHECK),
				new ExpectedRunEventMove(RUN_EVENT_HANDLER_NOT_QUEUED, failed, true, null, DRIVER_STATUS_PAIR_CHECK),
				new ExpectedRunEventMove(RUN_EVENT_HANDLER_NOT_QUEUED, aborted, false, null, DRIVER_WRITER),
				new ExpectedRunEventMove(RUN_EVENT_HANDLER_NOT_QUEUED, STATUS_DELAYED, false, null, DRIVER_STATUS_PAIR_CHECK),

				new ExpectedRunEventMove(RUN_EVENT_HANDLER_SUCCEEDED, running, false, null, DRIVER_WRITER),
				new ExpectedRunEventMove(RUN_EVENT_HANDLER_SUCCEEDED, stalled, true, null, DRIVER_STATUS_PAIR_CHECK),
				new ExpectedRunEventMove(RUN_EVENT_HANDLER_SUCCEEDED, completed, true, null, DRIVER_STATUS_PAIR_CHECK),
				new ExpectedRunEventMove(RUN_EVENT_HANDLER_SUCCEEDED, failed, true, null, DRIVER_STATUS_PAIR_CHECK),
				new ExpectedRunEventMove(RUN_EVENT_HANDLER_SUCCEEDED, aborted, false, null, DRIVER_WRITER),
				new ExpectedRunEventMove(RUN_EVENT_HANDLER_SUCCEEDED, STATUS_DELAYED, false, null, DRIVER_STATUS_PAIR_CHECK),

				new ExpectedRunEventMove(RUN_EVENT_HANDLER_FAILED, running, false, failed, DRIVER_WRITER),
				new ExpectedRunEventMove(RUN_EVENT_HANDLER_FAILED, stalled, false, failed, DRIVER_WRITER),
				new ExpectedRunEventMove(RUN_EVENT_HANDLER_FAILED, completed, true, failed, DRIVER_STATUS_PAIR_CHECK),
				new ExpectedRunEventMove(RUN_EVENT_HANDLER_FAILED, failed, true, failed, DRIVER_STATUS_PAIR_CHECK),
				new ExpectedRunEventMove(RUN_EVENT_HANDLER_FAILED, aborted, false, failed, DRIVER_STATUS_PAIR_CHECK),
				new ExpectedRunEventMove(RUN_EVENT_HANDLER_FAILED, STATUS_DELAYED, false, failed, DRIVER_STATUS_PAIR_CHECK),

				new ExpectedRunEventMove(RUN_EVENT_WATCHDOG_STALLED, running, true, stalled, DRIVER_STATUS_PAIR_CHECK),
				new ExpectedRunEventMove(RUN_EVENT_WATCHDOG_STALLED, stalled, true, stalled, DRIVER_STATUS_PAIR_CHECK),
				new ExpectedRunEventMove(RUN_EVENT_WATCHDOG_STALLED, completed, false, stalled, DRIVER_STATUS_PAIR_CHECK),
				new ExpectedRunEventMove(RUN_EVENT_WATCHDOG_STALLED, failed, false, stalled, DRIVER_STATUS_PAIR_CHECK),
				new ExpectedRunEventMove(RUN_EVENT_WATCHDOG_STALLED, aborted, false, stalled, DRIVER_STATUS_PAIR_CHECK),
				new ExpectedRunEventMove(RUN_EVENT_WATCHDOG_STALLED, STATUS_DELAYED, false, stalled, DRIVER_STATUS_PAIR_CHECK),

				new ExpectedRunEventMove(RUN_EVENT_WATCHDOG_REDRIVEN, running, true, running, DRIVER_STATUS_PAIR_CHECK),
				new ExpectedRunEventMove(RUN_EVENT_WATCHDOG_REDRIVEN, stalled, true, running, DRIVER_STATUS_PAIR_CHECK),
				new ExpectedRunEventMove(RUN_EVENT_WATCHDOG_REDRIVEN, completed, false, running, DRIVER_STATUS_PAIR_CHECK),
				new ExpectedRunEventMove(RUN_EVENT_WATCHDOG_REDRIVEN, failed, false, running, DRIVER_WRITER),
				new ExpectedRunEventMove(RUN_EVENT_WATCHDOG_REDRIVEN, aborted, false, running, DRIVER_STATUS_PAIR_CHECK),
				new ExpectedRunEventMove(RUN_EVENT_WATCHDOG_REDRIVEN, STATUS_DELAYED, false, running, DRIVER_STATUS_PAIR_CHECK),

				new ExpectedRunEventMove(RUN_EVENT_RECOVERY_DEGRADED, running, true, failed, DRIVER_STATUS_PAIR_CHECK),
				new ExpectedRunEventMove(RUN_EVENT_RECOVERY_DEGRADED, stalled, true, failed, DRIVER_STATUS_PAIR_CHECK),
				new ExpectedRunEventMove(RUN_EVENT_RECOVERY_DEGRADED, completed, false, failed, DRIVER_WRITER),
				new ExpectedRunEventMove(RUN_EVENT_RECOVERY_DEGRADED, failed, false, failed, DRIVER_WRITER),
				new ExpectedRunEventMove(RUN_EVENT_RECOVERY_DEGRADED, aborted, false, failed, DRIVER_STATUS_PAIR_CHECK),
				new ExpectedRunEventMove(RUN_EVENT_RECOVERY_DEGRADED, STATUS_DELAYED, false, failed, DRIVER_STATUS_PAIR_CHECK),

				new ExpectedRunEventMove(RUN_EVENT_KILL_SWITCH_ABORTED, running, true, aborted, DRIVER_STATUS_PAIR_CHECK),
				new ExpectedRunEventMove(RUN_EVENT_KILL_SWITCH_ABORTED, stalled, true, aborted, DRIVER_STATUS_PAIR_CHECK),
				new ExpectedRunEventMove(RUN_EVENT_KILL_SWITCH_ABORTED, completed, false, aborted, DRIVER_STATUS_PAIR_CHECK),
				new ExpectedRunEventMove(RUN_EVENT_KILL_SWITCH_ABORTED, failed, false, aborted, DRIVER_STATUS_PAIR_CHECK),
				new ExpectedRunEventMove(RUN_EVENT_KILL_SWITCH_ABORTED, aborted, true, aborted, DRIVER_STATUS_PAIR_CHECK),
				new ExpectedRunEventMove(RUN_EVENT_KILL_SWITCH_ABORTED, STATUS_DELAYED, false, aborted, DRIVER_STATUS_PAIR_CHECK),

				new ExpectedRunEventMove(RUN_EVENT_OPERATOR_ABORTED, running, true, aborted, DRIVER_STATUS_PAIR_CHECK),
				new ExpectedRunEventMove(RUN_EVENT_OPERATOR_ABORTED, stalled, true, aborted, DRIVER_STATUS_PAIR_CHECK),
				new ExpectedRunEventMove(RUN_EVENT_OPERATOR_ABORTED, completed, false, aborted, DRIVER_STATUS_PAIR_CHECK),
				new ExpectedRunEventMove(RUN_EVENT_OPERATOR_ABORTED, failed, false, aborted, DRIVER_STATUS_PAIR_CHECK),
				new ExpectedRunEventMove(RUN_EVENT_OPERATOR_ABORTED, aborted, false, aborted, DRIVER_WRITER),
				new ExpectedRunEventMove(RUN_EVENT_OPERATOR_ABORTED, STATUS_DELAYED, false, aborted, DRIVER_STATUS_PAIR_CHECK),

				new ExpectedRunEventMove(RUN_EVENT_OPERATOR_RETRIED, running, false, running, DRIVER_WRITER),
				new ExpectedRunEventMove(RUN_EVENT_OPERATOR_RETRIED, stalled, false, running, DRIVER_WRITER),
				new ExpectedRunEventMove(RUN_EVENT_OPERATOR_RETRIED, completed, false, running, DRIVER_STATUS_PAIR_CHECK),
				new ExpectedRunEventMove(RUN_EVENT_OPERATOR_RETRIED, failed, true, running, DRIVER_STATUS_PAIR_CHECK),
				new ExpectedRunEventMove(RUN_EVENT_OPERATOR_RETRIED, aborted, false, running, DRIVER_STATUS_PAIR_CHECK),
				new ExpectedRunEventMove(RUN_EVENT_OPERATOR_RETRIED, STATUS_DELAYED, false, running, DRIVER_STATUS_PAIR_CHECK)
		};
	}

	/**
	 * @description The hand-written (from, to) table the trigger backstop is held to: six statuses times six statuses,
	 * every pair written out by hand from the engine's table. A pair is allowed when at least one move the engine makes
	 * goes from the first status to the second. Delayed is never a from or a to. Never computed from the engine's maps.
	 *
	 * @return The 36 pairs.
	 */
	private static List<StatusPair> buildExpectedStatusPairs()
	{
		String running = SEL_AsyncChainExecution.STATUS_RUNNING;
		String stalled = SEL_AsyncChainExecution.STATUS_STALLED;
		String completed = SEL_AsyncChainExecution.STATUS_COMPLETED;
		String failed = SEL_AsyncChainExecution.STATUS_FAILED;
		String aborted = SEL_AsyncChainExecution.STATUS_ABORTED;
		return new List<StatusPair>
		{
				new StatusPair(running, running, true),
				new StatusPair(running, stalled, true),
				new StatusPair(running, completed, true),
				new StatusPair(running, failed, true),
				new StatusPair(running, aborted, true),
				new StatusPair(running, STATUS_DELAYED, false),

				new StatusPair(stalled, running, true),
				new StatusPair(stalled, stalled, true),
				new StatusPair(stalled, completed, true),
				new StatusPair(stalled, failed, true),
				new StatusPair(stalled, aborted, true),
				new StatusPair(stalled, STATUS_DELAYED, false),

				new StatusPair(failed, running, true),
				new StatusPair(failed, stalled, false),
				new StatusPair(failed, completed, false),
				new StatusPair(failed, failed, true),
				new StatusPair(failed, aborted, false),
				new StatusPair(failed, STATUS_DELAYED, false),

				new StatusPair(completed, running, false),
				new StatusPair(completed, stalled, false),
				new StatusPair(completed, completed, true),
				new StatusPair(completed, failed, true),
				new StatusPair(completed, aborted, false),
				new StatusPair(completed, STATUS_DELAYED, false),

				new StatusPair(aborted, running, false),
				new StatusPair(aborted, stalled, false),
				new StatusPair(aborted, completed, false),
				new StatusPair(aborted, failed, false),
				new StatusPair(aborted, aborted, true),
				new StatusPair(aborted, STATUS_DELAYED, false),

				new StatusPair(STATUS_DELAYED, running, false),
				new StatusPair(STATUS_DELAYED, stalled, false),
				new StatusPair(STATUS_DELAYED, completed, false),
				new StatusPair(STATUS_DELAYED, failed, false),
				new StatusPair(STATUS_DELAYED, aborted, false),
				new StatusPair(STATUS_DELAYED, STATUS_DELAYED, false)
		};
	}

	/**
	 * @description Queries an AsyncChainExecution__c record by Id.
	 *
	 * @param executionId The execution record Id.
	 *
	 * @return The queried execution record.
	 */
	private static AsyncChainExecution__c queryExecution(String executionId)
	{
		return (AsyncChainExecution__c)new SEL_AsyncChainExecution().findById(executionId);
	}

	/**
	 * @description Inserts a Running execution row carrying the given run key, for direct Finalizer calls that need full
	 * control over the persisted key.
	 *
	 * @param runKey The run key to stamp on the record.
	 *
	 * @return The persisted record with its Id populated.
	 */
	private static AsyncChainExecution__c persistRunningExecutionWithKey(String runKey)
	{
		return persistRunningExecutionHoldingKey(runKey, null);
	}

	/**
	 * @description Inserts a Running execution row carrying the given run key and holding the given deduplication key,
	 * for the handler tests that prove a refused write-back leaves the held key in place.
	 *
	 * @param runKey The run key to stamp on the record.
	 * @param deduplicationKey The active deduplication key the row holds, or null.
	 *
	 * @return The persisted record with its Id populated.
	 */
	private static AsyncChainExecution__c persistRunningExecutionHoldingKey(String runKey, String deduplicationKey)
	{
		return TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_RUNNING, TEST_CHAIN_NAME, new Map<SObjectField, Object>
		{
				AsyncChainExecution__c.StartedAt__c => Datetime.now(),
				AsyncChainExecution__c.RunKey__c => runKey,
				AsyncChainExecution__c.ActiveDeduplicationKey__c => deduplicationKey
		});
	}

	/**
	 * @description Builds a handler executor for the given run, as the executor's terminal write would queue it.
	 *
	 * @param executionId The execution record Id.
	 * @param handler The handler step definition, or null for a direct call of the handler Finalizer's recovery write.
	 * @param expectedStatus The status the run ended with when the handler was queued.
	 * @param originalErrorMessage The step failure the handler runs for, or null for a completion handler.
	 * @param runKey The run key the handler captured at enqueue time.
	 *
	 * @return The handler executor.
	 */
	private static UTIL_AsyncChain.HandlerExecutor buildHandlerExecutor
			(
					Id executionId, UTIL_AsyncChain.DTO_StepDefinition handler, String expectedStatus, String originalErrorMessage, String runKey
			)
	{
		UTIL_AsyncChain.ChainContext context = new UTIL_AsyncChain.ChainContext(executionId, UTIL_Random.randomUUID());
		return new UTIL_AsyncChain.HandlerExecutor(executionId, context, handler, expectedStatus, originalErrorMessage, runKey);
	}

	/**
	 * @description Moves the running step's own run to movedRunStatus with movedRunFailureCategory and an end time
	 * STAMP_AGE_MINUTES in the past, through the flip helper, as another actor committing while the step works would.
	 *
	 * @param context The shared chain context, read for the execution record Id.
	 */
	private static void moveRunAsAnotherActorWould(UTIL_AsyncChain.ChainContext context)
	{
		flipStatus((Id)context.getChainExecutionId(), movedRunStatus, Datetime.now().addMinutes(-STAMP_AGE_MINUTES), movedRunFailureCategory);
	}

	/**
	 * @description Flips the given execution record to Failed with its completion stamp set, through a sparse update, as
	 * a terminal failure committed while a Finalizer is in flight would. The run key is untouched, so the fence alone
	 * still authorizes the in-flight actor.
	 *
	 * @param executionId The execution record Id to flip.
	 */
	private static void flipToFailed(Id executionId)
	{
		flipStatus(executionId, SEL_AsyncChainExecution.STATUS_FAILED, Datetime.now(), SEL_AsyncChainExecution.FAILURE_CATEGORY_STEP_EXCEPTION);
	}

	/**
	 * @description Flips the given execution record to Completed with its completion stamp set, as a completion
	 * committed while a Finalizer is in flight would. The run key is untouched.
	 *
	 * @param executionId The execution record Id to flip.
	 */
	private static void flipToCompleted(Id executionId)
	{
		flipStatus(executionId, SEL_AsyncChainExecution.STATUS_COMPLETED, Datetime.now(), null);
	}

	/**
	 * @description Flips the given execution record to Aborted with the OperatorAbort category and its completion stamp
	 * set, as an operator abort committed while another actor is in flight would. The run key is untouched.
	 *
	 * @param executionId The execution record Id to flip.
	 */
	private static void flipToAborted(Id executionId)
	{
		flipStatus(executionId, SEL_AsyncChainExecution.STATUS_ABORTED, Datetime.now(), SEL_AsyncChainExecution.FAILURE_CATEGORY_OPERATOR_ABORT);
	}

	/**
	 * @description Seeds a stale mid-chain candidate (two steps, one completed) whose stamped executor job is a mocked
	 * dead AsyncApexJob, so the sweep's re-drive leg takes it: the given status with the Stalled category when the status
	 * is Stalled, the given run key, the given step log and an empty persisted context.
	 *
	 * @param status The status the candidate reads: Running or Stalled.
	 * @param runKey The run key the candidate carries.
	 * @param stepLogJson The persisted step log.
	 *
	 * @return The seeded record.
	 */
	private static AsyncChainExecution__c seedDeadRedriveCandidate(String status, String runKey, String stepLogJson)
	{
		AsyncApexJob deadJob = (AsyncApexJob)TST_Mock.of(AsyncApexJob.SObjectType)
				.withOverride(AsyncApexJob.Status, DEAD_JOB_STATUS)
				.build();
		Boolean stalled = status == SEL_AsyncChainExecution.STATUS_STALLED;
		return TST_Factory.newChainExecution(status, TEST_CHAIN_NAME, new Map<SObjectField, Object>
		{
				AsyncChainExecution__c.TotalSteps__c => MID_CHAIN_TOTAL_STEPS,
				AsyncChainExecution__c.CompletedSteps__c => MID_CHAIN_COMPLETED_STEPS,
				AsyncChainExecution__c.StartedAt__c => Datetime.now(),
				AsyncChainExecution__c.RunKey__c => runKey,
				AsyncChainExecution__c.CurrentJobId__c => String.valueOf(deadJob.Id),
				AsyncChainExecution__c.FailureCategory__c => stalled ? SEL_AsyncChainExecution.FAILURE_CATEGORY_STALLED : null,
				AsyncChainExecution__c.StepLog__c => stepLogJson,
				AsyncChainExecution__c.ContextData__c => EMPTY_CONTEXT_JSON
		});
	}

	/**
	 * @description Seeds a Failed run an operator may retry: its one step failed and declared itself idempotent, it
	 * carries its end time, the StepException category, a run key and an empty persisted context.
	 *
	 * @return The seeded record.
	 */
	private static AsyncChainExecution__c seedFailedRetryCandidate()
	{
		return TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_FAILED, TEST_CHAIN_NAME, new Map<SObjectField, Object>
		{
				AsyncChainExecution__c.TotalSteps__c => SINGLE_STEP_TOTAL_STEPS,
				AsyncChainExecution__c.CompletedSteps__c => 0,
				AsyncChainExecution__c.StartedAt__c => Datetime.now().addMinutes(-STAMP_AGE_MINUTES),
				AsyncChainExecution__c.CompletedAt__c => Datetime.now(),
				AsyncChainExecution__c.FailureCategory__c => SEL_AsyncChainExecution.FAILURE_CATEGORY_STEP_EXCEPTION,
				AsyncChainExecution__c.ErrorMessage__c => ORIGINAL_FAILURE_REASON,
				AsyncChainExecution__c.RunKey__c => UTIL_Random.randomUUID(),
				AsyncChainExecution__c.StepLog__c => buildFailedIdempotentStepLogWithErrorHandler(),
				AsyncChainExecution__c.ContextData__c => EMPTY_CONTEXT_JSON
		});
	}

	/**
	 * @description Builds a persisted step log whose one step failed the chain and declared itself idempotent, so an
	 * operator retry is available, plus the counting error handler entry.
	 *
	 * @return The serialized step log.
	 */
	private static String buildFailedIdempotentStepLogWithErrorHandler()
	{
		UTIL_AsyncChain.DTO_StepDefinition failedStep = buildDtoStepDefinition(SuccessStep.class.getName(), SUCCESS_STEP_NAME);
		failedStep.success = false;
		failedStep.isIdempotent = true;
		failedStep.message = ORIGINAL_FAILURE_REASON;
		return JSON.serialize(new List<UTIL_AsyncChain.DTO_StepDefinition> {failedStep, buildCountingErrorHandlerEntry()}, true);
	}

	/**
	 * @description Builds a persisted step log shaped like a mid-chain re-drive candidate: one completed success step,
	 * one success step still to run, then the counting error handler entry.
	 *
	 * @return The serialized step log.
	 */
	private static String buildMidChainStepLogWithErrorHandler()
	{
		UTIL_AsyncChain.DTO_StepDefinition completedStep = buildDtoStepDefinition(SuccessStep.class.getName(), SUCCESS_STEP_NAME);
		completedStep.success = true;
		return JSON.serialize(new List<UTIL_AsyncChain.DTO_StepDefinition>
		{
				completedStep,
				buildDtoStepDefinition(SuccessStep.class.getName(), SUCCESS_STEP_NAME),
				buildCountingErrorHandlerEntry()
		}, true);
	}

	/**
	 * @description Builds a persisted step log whose every step was attempted (one completed success step) plus the
	 * counting error handler entry, so a re-drive has no step to resume at and degrades.
	 *
	 * @return The serialized step log.
	 */
	private static String buildAllAttemptedStepLogWithErrorHandler()
	{
		UTIL_AsyncChain.DTO_StepDefinition attemptedStep = buildDtoStepDefinition(SuccessStep.class.getName(), SUCCESS_STEP_NAME);
		attemptedStep.success = true;
		return JSON.serialize(new List<UTIL_AsyncChain.DTO_StepDefinition> {attemptedStep, buildCountingErrorHandlerEntry()}, true);
	}

	/**
	 * @description Builds a persisted step log with one success step still to run plus the counting error handler entry.
	 *
	 * @return The serialized step log.
	 */
	private static String buildSingleStepLogWithErrorHandler()
	{
		return JSON.serialize(new List<UTIL_AsyncChain.DTO_StepDefinition>
		{
				buildDtoStepDefinition(SuccessStep.class.getName(), SUCCESS_STEP_NAME),
				buildCountingErrorHandlerEntry()
		}, true);
	}

	/**
	 * @description Builds the counting error handler's step log entry.
	 *
	 * @return The entry, marked as the error handler.
	 */
	private static UTIL_AsyncChain.DTO_StepDefinition buildCountingErrorHandlerEntry()
	{
		UTIL_AsyncChain.DTO_StepDefinition handlerEntry = buildDtoStepDefinition(CountingErrorHandlerStep.class.getName(), COUNTING_ERROR_HANDLER_STEP_NAME);
		handlerEntry.isErrorHandler = true;
		return handlerEntry;
	}

	/**
	 * @description Writes the given status, completion stamp and failure category to the record through a sparse
	 * system-mode update, leaving every other field as it is. A Completed, Failed or Aborted status also clears the
	 * active deduplication key, as every terminal write does.
	 *
	 * @param executionId The execution record Id to flip.
	 * @param status The status to write.
	 * @param completedAt The completion stamp to write, or null to leave none.
	 * @param failureCategory The failure category to write, or null to leave none.
	 */
	private static void flipStatus(Id executionId, String status, Datetime completedAt, String failureCategory)
	{
		DML_Builder.newTransaction().systemModeInternal().doUpdate(buildStatusWrite(executionId, status, completedAt, failureCategory)).execute();
	}

	/**
	 * @description Builds a sparse write of the given status, end time and failure category for the record, leaving
	 * every other field as it is. A Completed, Failed or Aborted status also clears the active deduplication key, as
	 * every write into a finished status does. The write is built, not executed.
	 *
	 * @param executionId The execution record Id to write.
	 * @param status The status to write.
	 * @param completedAt The end time to write, or null to write none.
	 * @param failureCategory The failure category to write, or null to write none.
	 *
	 * @return The sparse write.
	 */
	private static AsyncChainExecution__c buildStatusWrite(Id executionId, String status, Datetime completedAt, String failureCategory)
	{
		AsyncChainExecution__c row = (AsyncChainExecution__c)TST_Builder.of(AsyncChainExecution__c.SObjectType)
				.withOverride(AsyncChainExecution__c.Id, executionId)
				.withOverride(AsyncChainExecution__c.Status__c, status)
				.withOptionalField(AsyncChainExecution__c.ChainName__c)
				.withoutInsertion()
				.build();
		row.CompletedAt__c = completedAt;
		row.FailureCategory__c = failureCategory;
		if(status != SEL_AsyncChainExecution.STATUS_RUNNING && status != SEL_AsyncChainExecution.STATUS_STALLED)
		{
			row.ActiveDeduplicationKey__c = null;
		}
		return row;
	}

	/**
	 * @description Builds the row the transition function's fresh read is scripted to answer: a shape another actor
	 * could leave, or one the trigger backstop forbids and no insert may produce, carrying the run key the executor under
	 * test holds so the run key check passes and the list of allowed moves, or the check of the rules a row must meet in
	 * its status, is what refuses. Queued with
	 * TST_Mock.registerNext, so the reads after it go to the database.
	 *
	 * @param executionId The execution record Id the row answers for.
	 * @param runKey The run key the row reports.
	 * @param status The status the row reads.
	 * @param completedAt The completion stamp the row carries, or null.
	 * @param failureCategory The failure category the row carries, or null.
	 * @param activeDeduplicationKey The active deduplication key the row holds, or null.
	 *
	 * @return The row, never inserted.
	 */
	private static AsyncChainExecution__c buildFreshReadMock
			(
					Id executionId, String runKey, String status, Datetime completedAt, String failureCategory, String activeDeduplicationKey
			)
	{
		AsyncChainExecution__c mock = (AsyncChainExecution__c)TST_Builder.of(AsyncChainExecution__c.SObjectType)
				.withOverride(AsyncChainExecution__c.Id, executionId)
				.withOverride(AsyncChainExecution__c.RunKey__c, runKey)
				.withOverride(AsyncChainExecution__c.Status__c, status)
				.withOverride(AsyncChainExecution__c.ChainName__c, TEST_CHAIN_NAME)
				.withoutInsertion()
				.build();
		mock.CompletedAt__c = completedAt;
		mock.FailureCategory__c = failureCategory;
		mock.ActiveDeduplicationKey__c = activeDeduplicationKey;
		return mock;
	}

	/**
	 * @description Builds a direct-invocation ChainExecutor carrying the counting onError handler, for the refusal tests
	 * that assert the notification never fires.
	 *
	 * @param executionId The execution record Id.
	 * @param runKey The run key the executor captured at enqueue time.
	 *
	 * @return The configured executor.
	 */
	private static UTIL_AsyncChain.ChainExecutor buildExecutorWithCountingErrorHandler(Id executionId, String runKey)
	{
		return new UTIL_AsyncChain.ChainExecutor
				(
						executionId, 0, EXECUTOR_MAX_STEPS, EXECUTOR_MAX_CONTEXT_SIZE,
						buildDtoStepDefinition(CountingErrorHandlerStep.class.getName(), COUNTING_ERROR_HANDLER_STEP_NAME),
						null, createAsyncOptions(2), runKey
				);
	}

	/**
	 * @description Builds a ChainExecutor that resumes the given run at its first step under the given run key, with no
	 * handlers of its own, as a slow executor that still owns its run would wake.
	 *
	 * @param executionId The execution record Id.
	 * @param runKey The run key the executor captured at enqueue time.
	 *
	 * @return The configured executor.
	 */
	private static UTIL_AsyncChain.ChainExecutor buildExecutorWithoutHandlers(Id executionId, String runKey)
	{
		return new UTIL_AsyncChain.ChainExecutor(executionId, 0, EXECUTOR_MAX_STEPS, EXECUTOR_MAX_CONTEXT_SIZE, null, null, createAsyncOptions(2), runKey);
	}

	/**
	 * @description Builds a DTO_StepDefinition with the given class name and step name.
	 *
	 * @param className The step's class name.
	 * @param stepName The step's display name.
	 *
	 * @return The definition.
	 */
	private static UTIL_AsyncChain.DTO_StepDefinition buildDtoStepDefinition(String className, String stepName)
	{
		UTIL_AsyncChain.DTO_StepDefinition definition = new UTIL_AsyncChain.DTO_StepDefinition();
		definition.className = className;
		definition.stepName = stepName;
		return definition;
	}

	/**
	 * @description Creates an AsyncOptions instance with the given queueable stack depth.
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
	 * @description Sets up the feature flag cache to say the AsyncChain feature is enabled.
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
	 * @description Returns whether any persisted log entry at the given level carries a message containing the fragment.
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
	 * @description Retrieves the test admin user created in test setup, for System.runAs.
	 *
	 * @return The test admin User record.
	 */
	private static User getTestAdmin()
	{
		return new SEL_User().findByCompanyName(TEST_ADMIN_COMPANY);
	}

	/**
	 * @description One row of the hand-written run event table: one run event from one status.
	 */
	private class ExpectedRunEventMove
	{
		/**
		 * @description The run event's name, as the engine's enum spells it.
		 */
		private final String runEvent;

		/**
		 * @description The status the run reads before the run event.
		 */
		private final String fromStatus;

		/**
		 * @description Whether the list of allowed moves permits the run event from that status.
		 */
		private final Boolean allowed;

		/**
		 * @description The status the run event moves the run to, or null for a run event that keeps the status.
		 */
		private final String targetStatus;

		/**
		 * @description DRIVER_STATUS_PAIR_CHECK when the status pair check decides the move, DRIVER_WRITER when only the
		 * real writer can.
		 */
		private final String driver;

		/**
		 * @description Builds one row of the run event table.
		 *
		 * @param runEvent The run event's name.
		 * @param fromStatus The status before the run event.
		 * @param allowed Whether the run event is allowed from that status.
		 * @param targetStatus The run event's target, or null for unchanged.
		 * @param driver DRIVER_STATUS_PAIR_CHECK or DRIVER_WRITER.
		 */
		private ExpectedRunEventMove(String runEvent, String fromStatus, Boolean allowed, String targetStatus, String driver)
		{
			this.runEvent = runEvent;
			this.fromStatus = fromStatus;
			this.allowed = allowed;
			this.targetStatus = targetStatus;
			this.driver = driver;
		}
	}

	/**
	 * @description One row of the hand-written (from, to) table the trigger backstop is held to.
	 */
	private class StatusPair
	{
		/**
		 * @description The status the row has before the write.
		 */
		private final String fromStatus;

		/**
		 * @description The status the write asks for.
		 */
		private final String toStatus;

		/**
		 * @description Whether the backstop lets a write from the first status into the second through.
		 */
		private final Boolean allowed;

		/**
		 * @description Builds one row of the table.
		 *
		 * @param fromStatus The status before the write.
		 * @param toStatus The status the write asks for.
		 * @param allowed Whether the write is let through.
		 */
		private StatusPair(String fromStatus, String toStatus, Boolean allowed)
		{
			this.fromStatus = fromStatus;
			this.toStatus = toStatus;
			this.allowed = allowed;
		}
	}

	/**
	 * @description Step that succeeds.
	 */
	public class SuccessStep extends UTIL_AsyncChain.ChainStep
	{
		/**
		 * @description Succeeds.
		 *
		 * @param context The shared chain context; unused.
		 *
		 * @return A succeeded result.
		 */
		public override UTIL_AsyncChain.StepResult work(UTIL_AsyncChain.ChainContext context)
		{
			return UTIL_AsyncChain.succeeded('Step succeeded');
		}
	}

	/**
	 * @description Step that fails with whatever configuredFailureMessage holds when it runs.
	 */
	public class FailingWithConfiguredMessageStep extends UTIL_AsyncChain.ChainStep
	{
		/**
		 * @description Fails with configuredFailureMessage.
		 *
		 * @param context The shared chain context; unused.
		 *
		 * @return A failed result.
		 */
		public override UTIL_AsyncChain.StepResult work(UTIL_AsyncChain.ChainContext context)
		{
			return UTIL_AsyncChain.failed(configuredFailureMessage);
		}
	}

	/**
	 * @description Error handler step that counts its runs and marks the context, so a test can prove a refused or
	 * unqueued notification never ran it, or that a refused write-back kept its context off the row.
	 */
	public class CountingErrorHandlerStep extends UTIL_AsyncChain.ChainStep
	{
		/**
		 * @description Increments errorHandlerRunCount, marks the context under HANDLER_RAN_CONTEXT_KEY and succeeds.
		 *
		 * @param context The shared chain context, marked.
		 *
		 * @return A succeeded result.
		 */
		public override UTIL_AsyncChain.StepResult work(UTIL_AsyncChain.ChainContext context)
		{
			errorHandlerRunCount++;
			context.put(HANDLER_RAN_CONTEXT_KEY, true);
			return UTIL_AsyncChain.succeeded('Handled');
		}
	}

	/**
	 * @description Completion handler step that counts its runs, so a test can prove a refused completion never queued it.
	 */
	public class CountingCompletionHandlerStep extends UTIL_AsyncChain.ChainStep
	{
		/**
		 * @description Increments completionHandlerRunCount and succeeds.
		 *
		 * @param context The shared chain context; unused.
		 *
		 * @return A succeeded result.
		 */
		public override UTIL_AsyncChain.StepResult work(UTIL_AsyncChain.ChainContext context)
		{
			completionHandlerRunCount++;
			return UTIL_AsyncChain.succeeded('Completion handled');
		}
	}

	/**
	 * @description Error handler that itself throws.
	 */
	public class FailingErrorHandlerStep extends UTIL_AsyncChain.ChainStep
	{
		/**
		 * @description Throws so the chain's error handler itself fails.
		 *
		 * @param context The shared chain context; unused.
		 *
		 * @return Never; every call throws instead.
		 *
		 * @throws UTIL_Exceptions.IllegalStateException On every call.
		 */
		public override UTIL_AsyncChain.StepResult work(UTIL_AsyncChain.ChainContext context)
		{
			throw new UTIL_Exceptions.IllegalStateException(ERROR_HANDLER_FAILURE_REASON);
		}
	}

	/**
	 * @description Completion handler that itself throws.
	 */
	public class FailingCompletionHandlerStep extends UTIL_AsyncChain.ChainStep
	{
		/**
		 * @description Throws so the chain's completion handler itself fails.
		 *
		 * @param context The shared chain context; unused.
		 *
		 * @return Never; every call throws instead.
		 *
		 * @throws UTIL_Exceptions.IllegalStateException On every call.
		 */
		public override UTIL_AsyncChain.StepResult work(UTIL_AsyncChain.ChainContext context)
		{
			throw new UTIL_Exceptions.IllegalStateException(COMPLETION_HANDLER_FAILURE_REASON);
		}
	}

	/**
	 * @description Step that fails on every attempt, under a single-retry zero-backoff strategy, so the chain ends
	 * Failed as RetriesExhausted on its second attempt.
	 */
	public class AlwaysFailsWithRetryStep extends UTIL_AsyncChain.ChainStep
	{
		/**
		 * @description Fails on every attempt, naming the attempt in the message.
		 *
		 * @param context The shared chain context, read for the attempt number.
		 *
		 * @return A failed result.
		 */
		public override UTIL_AsyncChain.StepResult work(UTIL_AsyncChain.ChainContext context)
		{
			return UTIL_AsyncChain.failed(RETRY_STEP_FAILURE_PREFIX + context.getAttempt());
		}

		/**
		 * @description Allows a single retry with no backoff.
		 *
		 * @return An exponential strategy capped at one retry with a zero base backoff.
		 */
		public override UTIL_Retry.Strategy createRetryStrategy()
		{
			return UTIL_Retry.exponential().withMaxRetries(1).withBaseBackoff(0);
		}
	}

	/**
	 * @description Step that moves its own run to movedRunStatus, as another actor committing mid-work would, then
	 * succeeds, so the executor's completion write meets a run that has already ended.
	 */
	public class MoveRunThenSucceedStep extends UTIL_AsyncChain.ChainStep
	{
		/**
		 * @description Moves the run through moveRunAsAnotherActorWould and succeeds.
		 *
		 * @param context The shared chain context, read for the execution record Id.
		 *
		 * @return A succeeded result.
		 */
		public override UTIL_AsyncChain.StepResult work(UTIL_AsyncChain.ChainContext context)
		{
			moveRunAsAnotherActorWould(context);
			return UTIL_AsyncChain.succeeded('Step succeeded after the run was moved');
		}
	}

	/**
	 * @description Step that moves its own run to movedRunStatus, as another actor committing mid-work would, then fails
	 * with configuredFailureMessage, so the executor's step failure write meets a run that has already ended.
	 */
	public class MoveRunThenFailStep extends UTIL_AsyncChain.ChainStep
	{
		/**
		 * @description Moves the run through moveRunAsAnotherActorWould and fails with configuredFailureMessage.
		 *
		 * @param context The shared chain context, read for the execution record Id.
		 *
		 * @return A failed result.
		 */
		public override UTIL_AsyncChain.StepResult work(UTIL_AsyncChain.ChainContext context)
		{
			moveRunAsAnotherActorWould(context);
			return UTIL_AsyncChain.failed(configuredFailureMessage);
		}
	}

	/**
	 * @description Completion handler step that succeeds.
	 */
	public class CompletionHandlerStep extends UTIL_AsyncChain.ChainStep
	{
		/**
		 * @description Succeeds.
		 *
		 * @param context The shared chain context; unused.
		 *
		 * @return A succeeded result.
		 */
		public override UTIL_AsyncChain.StepResult work(UTIL_AsyncChain.ChainContext context)
		{
			return UTIL_AsyncChain.succeeded('Completion handled');
		}
	}
}
