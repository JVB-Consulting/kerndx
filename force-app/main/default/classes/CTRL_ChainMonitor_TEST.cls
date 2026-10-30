// SPDX-License-Identifier: Apache-2.0
/**
 * @description Tests for CTRL_ChainMonitor.
 *
 * @see CTRL_ChainMonitor
 *
 * @author Jason van Beukering
 *
 * @group Controllers
 *
 * @date April 2026, October 2026
 */
@IsTest(seeAllData=false isParallel=true)
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs,PMD.CyclomaticComplexity')
private class CTRL_ChainMonitor_TEST
{
	/**
	 * @description Test chain name.
	 */
	private static final String TEST_CHAIN = 'TestChain';

	/**
	 * @description Error message on the refused step in the refused-step fixture.
	 */
	private static final String REFUSED_STEP_MESSAGE = 'Recovery stopped at a started step';

	/**
	 * @description Log level seeded on stream-seed log entries.
	 */
	private static final String TEST_LOG_LEVEL = 'ERROR';

	/**
	 * @description Short message seeded on stream-seed log entries.
	 */
	private static final String TEST_LOG_MESSAGE = 'Seeded chain log entry';

	/**
	 * @description More rows than the stream seed returns, to prove the cap.
	 */
	private static final Integer SEED_OVERFLOW_ROW_COUNT = 25;

	/**
	 * @description Message on the log entry that points at the run's record but carries no correlation id (the tracking id
	 * that follows one action across its work), so the test can tell that this entry is the one returned.
	 */
	private static final String RECORD_REFERENCED_MESSAGE = 'Record-referenced chain log entry';

	/**
	 * @description Message that marks the newest block of log entries in a trace too large to return whole, so the test can
	 * prove that only entries from that block are returned.
	 */
	private static final String NEWEST_WINDOW_MESSAGE = 'Newest window entry';

	/**
	 * @description How far in the past the elapsed-time tests place a run's start, so the computed
	 * value is unambiguously positive however long the test itself takes.
	 */
	private static final Integer ELAPSED_MINUTES = 90;

	/**
	 * @description How many of the stalled rows seeded by shouldCountStalledChainsWaitingForTheSweep
	 * are still waiting: the two without a completion instant.
	 */
	private static final Integer STALLED_AWAITING_SWEEP_COUNT = 2;

	/**
	 * @description The tracking id of the scheduled job's action: the job's own correlation is the root of everything under it.
	 */
	private static final String JOB_ROOT_ID = UTIL_Random.randomUUID();

	/**
	 * @description The tracking id of a click's action, which no run holds: a run launched under it was launched by the
	 * action itself.
	 */
	private static final String CLICK_ROOT_ID = UTIL_Random.randomUUID();

	/**
	 * @description What the controller puts between a run's chain name and its chain number when it labels the run.
	 */
	private static final String CHAIN_LABEL_SEPARATOR = ' · ';

	/**
	 * @description Stored duration of the short finished run in the elapsed-sort fixture: ten minutes.
	 */
	private static final Long SHORT_RUN_DURATION_MS = 600000L;

	/**
	 * @description Stored duration of the long finished run in the elapsed-sort fixture: three hours.
	 */
	private static final Long LONG_RUN_DURATION_MS = 10800000L;

	/**
	 * @description Minutes the stalled run of the elapsed-sort fixture has been going: between the two finished runs.
	 */
	private static final Integer STALLED_RUN_AGE_MINUTES = 92;

	/**
	 * @description Minutes between the start and the recorded end of the crashed run in the elapsed-sort fixture: one hour,
	 * which puts it between the short finished run and the stalled one.
	 */
	private static final Integer CRASHED_RUN_LENGTH_MINUTES = 60;

	/**
	 * @description Minutes between the start and the end of a run seeded to prove one ended status on its own.
	 */
	private static final Integer ENDED_RUN_LENGTH_MINUTES = 25;

	/**
	 * @description The wait the step-log fixture records on its manually retried step: thirty-seven minutes.
	 */
	private static final Long MANUAL_RETRY_WAIT_MS = 2220000L;

	/**
	 * @description What the engine writes on a retried step whose wait could not be measured.
	 */
	private static final Long WAIT_UNKNOWN_IN_STEP_LOG = -1L;

	/**
	 * @description The wait the step-log fixture records on a step retried in the same instant it failed: the zero boundary,
	 * which is a measured wait and not an unknown one.
	 */
	private static final Long MANUAL_RETRY_ZERO_WAIT_MS = 0L;

	/**
	 * @description Independent oracle for the formatted form of a zero wait, the text the timeline shows beside the manual
	 * retry marker (the note that an operator retried the step).
	 */
	private static final String MANUAL_RETRY_ZERO_WAIT_LABEL = '0ms';

	/**
	 * @description Milliseconds in a minute, for turning the stalled run's seeded age into the unit the list shows.
	 */
	private static final Long MILLISECONDS_PER_MINUTE = 60000L;

	/**
	 * @description Class name of the step in the display-table fixtures and in the old step log with no started records.
	 */
	private static final String TABLE_STEP_CLASS = 'TableStep';

	/**
	 * @description Display name of the step in the display-table fixtures and in the old step log with no started records.
	 */
	private static final String TABLE_STEP_NAME = 'Table Step';

	/**
	 * @description Duration recorded on a display-table step that has a result.
	 */
	private static final Long TABLE_STEP_DURATION_MS = 400L;

	/**
	 * @description A run status the picklist holds but the engine never writes. The selector keeps no constant for it.
	 */
	private static final String STATUS_DELAYED = 'Delayed';

	/**
	 * @description Failure message recorded on a display-table step that failed.
	 */
	private static final String TABLE_STEP_FAILURE_MESSAGE = 'Table step failed';

	/**
	 * @description How many step states the display table holds for each chain status.
	 */
	private static final Integer STEP_STATES_PER_CHAIN_STATUS = 6;

	/**
	 * @description Builds a step log JSON string from DTO_StepDefinition instances.
	 *
	 * @param definitions The step definitions to serialize.
	 *
	 * @return The serialized JSON string.
	 */
	private static String buildStepLog(List<UTIL_AsyncChain.DTO_StepDefinition> definitions)
	{
		return JSON.serialize(definitions);
	}

	/**
	 * @description Creates a step definition with the given properties.
	 *
	 * @param className The Apex class name.
	 * @param stepName The display name (nullable).
	 * @param success Whether the step succeeded (nullable for pending).
	 * @param durationMs Duration in milliseconds (nullable for pending).
	 *
	 * @return A populated DTO_StepDefinition.
	 */
	private static UTIL_AsyncChain.DTO_StepDefinition buildStep(String className, String stepName, Boolean success, Long durationMs)
	{
		UTIL_AsyncChain.DTO_StepDefinition step = new UTIL_AsyncChain.DTO_StepDefinition();
		step.className = className;
		step.stepName = stepName;
		step.success = success;
		step.durationMs = durationMs;
		return step;
	}

	/**
	 * @description Sample step log for a completed 3-step chain.
	 *
	 * @return Serialized step log JSON.
	 */
	private static String stepLogCompleted()
	{
		return buildStepLog(new List<UTIL_AsyncChain.DTO_StepDefinition>
		{
				buildStep('CreateAccountStep', 'Create Account', true, 800),
				buildStep('CallApiStep', null, true, 2100),
				buildStep('SendNotification', 'Notify Owner', true, 300)
		});
	}

	/**
	 * @description Sample step log for a failed chain with continueOnError.
	 *
	 * @return Serialized step log JSON.
	 */
	private static String stepLogFailed()
	{
		UTIL_AsyncChain.DTO_StepDefinition loadStep = buildStep('LoadDataStep', 'Load Data', true, 500);

		UTIL_AsyncChain.DTO_StepDefinition warnStep = buildStep('ValidateStep', 'Validate', false, 100);
		warnStep.continueOnError = true;
		warnStep.message = 'Non-fatal: skipped';

		UTIL_AsyncChain.DTO_StepDefinition failStep = buildStep('ProcessStep', null, false, 200);
		failStep.message = 'Required field missing';

		return buildStepLog(new List<UTIL_AsyncChain.DTO_StepDefinition> {loadStep, warnStep, failStep});
	}

	/**
	 * @description Sample step log for a chain the recovery stopped at a started step added with continueOnError: a
	 * completed step, then the refused step marked failed with the refusal as its message.
	 *
	 * @return Serialized step log JSON.
	 */
	private static String stepLogRefusedContinueOnError()
	{
		UTIL_AsyncChain.DTO_StepDefinition loadStep = buildStep('LoadDataStep', 'Load Data', true, 500);

		UTIL_AsyncChain.DTO_StepDefinition refusedStep = buildStep('ValidateStep', 'Validate', false, null);
		refusedStep.continueOnError = true;
		refusedStep.started = true;
		refusedStep.recoveryRefused = true;
		refusedStep.message = REFUSED_STEP_MESSAGE;

		return buildStepLog(new List<UTIL_AsyncChain.DTO_StepDefinition> {loadStep, refusedStep});
	}

	/**
	 * @description Sample step log for a running chain (partial execution), including the onError
	 * and onComplete handler entries the framework persists after the step entries. The timeline
	 * must exclude both.
	 *
	 * @return Serialized step log JSON.
	 */
	private static String stepLogRunning()
	{
		UTIL_AsyncChain.DTO_StepDefinition completedStep = buildStep('Step1', 'First Step', true, 400);
		UTIL_AsyncChain.DTO_StepDefinition pendingStep = buildStep('Step2', 'Second Step', null, null);

		UTIL_AsyncChain.DTO_StepDefinition errorHandlerStep = new UTIL_AsyncChain.DTO_StepDefinition();
		errorHandlerStep.className = 'ErrorHandler';
		errorHandlerStep.isErrorHandler = true;

		UTIL_AsyncChain.DTO_StepDefinition completionHandlerStep = new UTIL_AsyncChain.DTO_StepDefinition();
		completionHandlerStep.className = 'CompletionHandler';
		completionHandlerStep.isCompletionHandler = true;

		return buildStepLog(new List<UTIL_AsyncChain.DTO_StepDefinition> {completedStep, pendingStep, errorHandlerStep, completionHandlerStep});
	}

	/**
	 * @description With Running and Failed chosen as status filters, the list returns only the runs in those two statuses
	 * and the total count matches, so an operator who filters the monitor sees no run in another status. Each returned row
	 * is checked by id and status: the Running run comes back as Running, the Failed run as Failed, and the Completed run
	 * is left out.
	 */
	@IsTest
	private static void shouldReturnFilteredExecutionsByStatus()
	{
		AsyncChainExecution__c runningExecution = TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_RUNNING, TEST_CHAIN);
		TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_COMPLETED, 'OtherChain');
		AsyncChainExecution__c failedExecution = TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_FAILED, TEST_CHAIN);

		CTRL_ChainMonitorTypes.DTO_Request request = new CTRL_ChainMonitorTypes.DTO_Request();
		request.statusFilters = new List<String> {SEL_AsyncChainExecution.STATUS_RUNNING, SEL_AsyncChainExecution.STATUS_FAILED};
		CTRL_ChainMonitorTypes.DTO_ChainPage result = CTRL_ChainMonitor.getChainExecutions(JSON.serialize(request));

		Assert.areEqual(2, result.records.size(), 'Expected only the Running and the Failed run, got ' + result.records.size() + ' rows');
		Assert.areEqual(2, result.totalCount, 'Expected a total count of 2 matching the filtered rows, got ' + result.totalCount);

		Set<Id> returnedIds = new Set<Id>();
		for(CTRL_ChainMonitorTypes.DTO_ChainSummary summary : result.records)
		{
			returnedIds.add(summary.executionId);
		}
		Assert.areEqual(new Set<Id> {runningExecution.Id, failedExecution.Id}, returnedIds, 'Expected exactly the Running and the Failed run, got ' + returnedIds);
		for(CTRL_ChainMonitorTypes.DTO_ChainSummary summary : result.records)
		{
			String expectedStatus = summary.executionId == runningExecution.Id ? SEL_AsyncChainExecution.STATUS_RUNNING : SEL_AsyncChainExecution.STATUS_FAILED;
			Assert.areEqual(expectedStatus, summary.status, 'Expected run ' + summary.executionId + ' to show status ' + expectedStatus + ', got ' + summary.status);
		}
	}

	/**
	 * @description A name filter returns only the runs whose chain name contains the text: "Account" returns the two Account
	 * chains and leaves the third out, so an operator can narrow the list to the chains they are looking for.
	 */
	@IsTest
	private static void shouldReturnFilteredExecutionsByName()
	{
		TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_COMPLETED, 'AccountOnboarding');
		TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_COMPLETED, 'DataSync');
		TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_COMPLETED, 'AccountCleanup');

		CTRL_ChainMonitorTypes.DTO_Request request = new CTRL_ChainMonitorTypes.DTO_Request();
		request.nameFilter = 'Account';
		CTRL_ChainMonitorTypes.DTO_ChainPage result = CTRL_ChainMonitor.getChainExecutions(JSON.serialize(request));

		Assert.areEqual(2, result.records.size(), 'Should return chains matching name filter');
	}

	/**
	 * @description A page size larger than the server allows is cut to the server's limit of 100 rows, and the rows beyond it
	 * are left for the next page. A request from the browser therefore cannot make one read return thousands of rows.
	 */
	@IsTest
	private static void shouldCapClientSuppliedPageSize()
	{
		TST_Factory.newChainExecutions(101, SEL_AsyncChainExecution.STATUS_COMPLETED, TEST_CHAIN);

		CTRL_ChainMonitorTypes.DTO_Request request = new CTRL_ChainMonitorTypes.DTO_Request();
		request.pageSize = 5000;
		CTRL_ChainMonitorTypes.DTO_ChainPage result = CTRL_ChainMonitor.getChainExecutions(JSON.serialize(request));

		Assert.areEqual(100, result.records.size(), 'Client-supplied page size must clamp to the server cap');
		Assert.areEqual(101, result.totalCount, 'Total count should include all records');
		Assert.isTrue(result.hasMorePages, 'Records beyond the cap should land on the next page');
	}

	/**
	 * @description A page request returns only the rows of its own page, together with the figures a pager needs: the count
	 * of all matching runs, the number of pages and whether more pages follow.
	 */
	@IsTest
	private static void shouldReturnPaginatedResults()
	{
		for(Integer index = 0; index < 5; index++)
		{
			TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_COMPLETED, 'Chain' + index);
		}

		CTRL_ChainMonitorTypes.DTO_Request request = new CTRL_ChainMonitorTypes.DTO_Request();
		request.pageSize = 2;
		request.pageNumber = 1;
		CTRL_ChainMonitorTypes.DTO_ChainPage result = CTRL_ChainMonitor.getChainExecutions(JSON.serialize(request));

		Assert.areEqual(2, result.records.size(), 'Should return page size records');
		Assert.areEqual(5, result.totalCount, 'Total count should reflect all matching records');
		Assert.areEqual(1, result.pageNumber, 'Page number should be 1');
		Assert.areEqual(3, result.totalPages, 'Total pages should be 3 for 5 records with page size 2');
		Assert.isTrue(result.hasMorePages, 'Should have more pages');
	}

	/**
	 * @description Seeds one run of the elapsed-sort fixture: finished with a stored duration, or unfinished with none.
	 *
	 * @param status The run's status.
	 * @param chainName The chain name the assertions read the order by.
	 * @param startedAt When the run started; null for a run that has not.
	 * @param storedDurationMs The stored duration of a finished run; null for an unfinished one.
	 */
	private static void seedRunForElapsedSort(String status, String chainName, Datetime startedAt, Long storedDurationMs)
	{
		Map<SObjectField, Object> overrides = new Map<SObjectField, Object> {AsyncChainExecution__c.StartedAt__c => startedAt};
		if(storedDurationMs != null)
		{
			overrides.put(AsyncChainExecution__c.DurationMs__c, (Decimal)storedDurationMs);
			overrides.put(AsyncChainExecution__c.CompletedAt__c, Datetime.now());
		}
		TST_Factory.newChainExecution(status, chainName, overrides);
	}

	/**
	 * @description Seeds a run that ended without storing a duration: an end and never a duration, which is what a crashed
	 * background job and a run with no steps really leave. The formula is real in a test, so the row's elapsed time is the
	 * time between its start and its end. The end is counted from the start, never from a second reading of the clock, so
	 * the two differ by a whole number of minutes.
	 *
	 * @param status The ended status the row carries.
	 * @param chainName The chain name the row is seeded under.
	 * @param lengthMinutes Minutes between the row's start and its end.
	 */
	private static void seedEndedRunWithoutStoredDuration(String status, String chainName, Integer lengthMinutes)
	{
		Datetime startedAt = Datetime.now().addHours(-6);
		Map<SObjectField, Object> overrides = new Map<SObjectField, Object>
		{
				AsyncChainExecution__c.StartedAt__c => startedAt,
				AsyncChainExecution__c.CompletedAt__c => startedAt.addMinutes(lengthMinutes)
		};
		TST_Factory.newChainExecution(status, chainName, overrides);
	}

	/**
	 * @description Seeds the five runs every elapsed-sort test reads: two finished with a stored duration, one stalled and one
	 * that ended without storing a duration, both between them by value, and one with no elapsed time at all because it is
	 * still waiting to start. The run waiting to start is a Running row with no start time, a shape the engine writes.
	 */
	private static void seedElapsedSortFixture()
	{
		seedRunForElapsedSort(SEL_AsyncChainExecution.STATUS_COMPLETED, 'ShortRun', Datetime.now().addHours(-6), SHORT_RUN_DURATION_MS);
		seedRunForElapsedSort(SEL_AsyncChainExecution.STATUS_COMPLETED, 'LongRun', Datetime.now().addHours(-6), LONG_RUN_DURATION_MS);
		seedRunForElapsedSort(SEL_AsyncChainExecution.STATUS_STALLED, 'StalledRun', Datetime.now().addMinutes(-STALLED_RUN_AGE_MINUTES), null);
		seedRunForElapsedSort(SEL_AsyncChainExecution.STATUS_RUNNING, 'UnstartedRun', null, null);
		seedEndedRunWithoutStoredDuration(SEL_AsyncChainExecution.STATUS_FAILED, 'CrashedRun', CRASHED_RUN_LENGTH_MINUTES);
	}

	/**
	 * @description A descending Duration sort puts a run still going among the finished ones, by how long it has been going,
	 * and a run that ended without storing a duration by the time between its start and its end. Only the run still
	 * waiting to start has no elapsed time, and it sorts last.
	 */
	@IsTest
	private static void shouldSortAnUnfinishedRunBetweenFinishedRunsByElapsedTimeDescending()
	{
		seedElapsedSortFixture();
		CTRL_ChainMonitorTypes.DTO_Request request = new CTRL_ChainMonitorTypes.DTO_Request();
		request.sortField = 'DurationMs';
		request.sortAscending = false;

		List<CTRL_ChainMonitorTypes.DTO_ChainSummary> records = CTRL_ChainMonitor.getChainExecutions(JSON.serialize(request)).records;

		Assert.areEqual(5, records.size(), 'All five seeded runs are listed');
		Assert.areEqual('LongRun', records[0].chainName, 'The longest run leads a descending Duration sort');
		Assert.areEqual('StalledRun', records[1].chainName, 'A stalled run sorts by how long it has been going, between the finished runs');
		Assert.areEqual('CrashedRun', records[2].chainName, 'A run that ended without storing a duration sorts by the time between its start and its end');
		Assert.areEqual('ShortRun', records[3].chainName, 'The shortest finished run follows the crashed one');
		Assert.areEqual('UnstartedRun', records[4].chainName, 'The run still waiting to start sorts last when descending');
		Assert.isNull(records[4].durationMs, 'A run still waiting to start has no elapsed time');
		Assert.isTrue(records[1].durationMs >= STALLED_RUN_AGE_MINUTES * MILLISECONDS_PER_MINUTE && records[1].durationMs < LONG_RUN_DURATION_MS,
				'The list shows the value it sorted by: ' + records[1].durationMs);
		Assert.areEqual(CRASHED_RUN_LENGTH_MINUTES * MILLISECONDS_PER_MINUTE, records[2].durationMs, 'A crashed run shows the time between its start and its end');
		Assert.areEqual(LONG_RUN_DURATION_MS, records[0].durationMs, 'A finished run shows its stored duration');
	}

	/**
	 * @description An ascending Duration sort leads with the run that has no elapsed time and closes with the longest, the
	 * crashed run and the stalled run in between by value.
	 */
	@IsTest
	private static void shouldSortAnUnfinishedRunBetweenFinishedRunsByElapsedTimeAscending()
	{
		seedElapsedSortFixture();
		CTRL_ChainMonitorTypes.DTO_Request request = new CTRL_ChainMonitorTypes.DTO_Request();
		request.sortField = 'DurationMs';
		request.sortAscending = true;

		List<CTRL_ChainMonitorTypes.DTO_ChainSummary> records = CTRL_ChainMonitor.getChainExecutions(JSON.serialize(request)).records;

		Assert.areEqual(5, records.size(), 'All five seeded runs are listed');
		Assert.areEqual('UnstartedRun', records[0].chainName, 'The run still waiting to start sorts first when ascending');
		Assert.isNull(records[0].durationMs, 'A run still waiting to start has no elapsed time');
		Assert.areEqual('ShortRun', records[1].chainName, 'The shortest finished run leads the runs that have a duration');
		Assert.areEqual('CrashedRun', records[2].chainName, 'A run that ended without storing a duration sorts by the time between its start and its end');
		Assert.areEqual('StalledRun', records[3].chainName, 'A stalled run sorts by how long it has been going, between the finished runs');
		Assert.areEqual('LongRun', records[4].chainName, 'The longest run closes an ascending Duration sort');
	}

	/**
	 * @description A run with no steps is closed as Completed with an end and no stored duration. It shows the time between
	 * its start and its end, as a crashed run does.
	 */
	@IsTest
	private static void shouldShowTheTimeBetweenStartAndEndOnACompletedRunThatStoredNoDuration()
	{
		seedEndedRunWithoutStoredDuration(SEL_AsyncChainExecution.STATUS_COMPLETED, TEST_CHAIN, ENDED_RUN_LENGTH_MINUTES);

		CTRL_ChainMonitorTypes.DTO_ChainPage result = CTRL_ChainMonitor.getChainExecutions(null);

		Assert.areEqual(ENDED_RUN_LENGTH_MINUTES * MILLISECONDS_PER_MINUTE, result.records[0].durationMs, 'A completed run shows the time between its start and its end');
	}

	/**
	 * @description An aborted run that stored no duration shows the time between its start and its end too: it has ended,
	 * so the number is fixed and says how long the run lasted before it was stopped.
	 */
	@IsTest
	private static void shouldShowTheTimeBetweenStartAndEndOnAnAbortedRunThatStoredNoDuration()
	{
		seedEndedRunWithoutStoredDuration(SEL_AsyncChainExecution.STATUS_ABORTED, TEST_CHAIN, ENDED_RUN_LENGTH_MINUTES);

		CTRL_ChainMonitorTypes.DTO_ChainPage result = CTRL_ChainMonitor.getChainExecutions(null);

		Assert.areEqual(ENDED_RUN_LENGTH_MINUTES * MILLISECONDS_PER_MINUTE, result.records[0].durationMs, 'An aborted run shows the time between its start and its end');
	}

	/**
	 * @description The step detail carries the manual retry marker the engine wrote. The marker is the note on a step that
	 * an operator retried it, with how long the step waited for that retry. A step with a measured wait shows it
	 * formatted, a step retried in the instant it failed shows a wait of nothing, and a step whose wait could not be measured
	 * carries the marker with no number and no text.
	 */
	@IsTest
	private static void shouldCarryTheManualRetryMarkerOntoTheStepDetail()
	{
		UTIL_AsyncChain.DTO_StepDefinition retriedWithWait = buildStep('CallApiStep', 'Call API', true, 2100);
		retriedWithWait.manualRetryAfterMs = MANUAL_RETRY_WAIT_MS;
		UTIL_AsyncChain.DTO_StepDefinition retriedWithUnknownWait = buildStep('ReconcileStep', 'Reconcile', false, 500);
		retriedWithUnknownWait.manualRetryAfterMs = WAIT_UNKNOWN_IN_STEP_LOG;
		UTIL_AsyncChain.DTO_StepDefinition retriedWithoutWaiting = buildStep('SendReceiptStep', 'Send Receipt', true, 300);
		retriedWithoutWaiting.manualRetryAfterMs = MANUAL_RETRY_ZERO_WAIT_MS;
		String stepLog = buildStepLog(new List<UTIL_AsyncChain.DTO_StepDefinition>
		{buildStep('CreateAccountStep', 'Create Account', true, 800), retriedWithWait, retriedWithUnknownWait, retriedWithoutWaiting});
		AsyncChainExecution__c execution = TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_FAILED, TEST_CHAIN, stepLog, 4, 3);

		List<CTRL_ChainMonitorTypes.DTO_StepDetail> steps = CTRL_ChainMonitor.getChainDetail(execution.Id).steps;

		Assert.areEqual(false, steps[0].manuallyRetried, 'A step nobody retried carries no marker');
		Assert.isNull(steps[0].manualRetryAfterLabel, 'A step nobody retried carries no wait');
		Assert.areEqual(true, steps[1].manuallyRetried, 'A retried step carries the marker');
		Assert.areEqual(MANUAL_RETRY_WAIT_MS, steps[1].manualRetryAfterMs, 'The marker carries the wait in milliseconds');
		Assert.areEqual(UTIL_Date.formatDuration(MANUAL_RETRY_WAIT_MS), steps[1].manualRetryAfterLabel, 'The wait is formatted the way step durations are');
		Assert.areEqual(true, steps[2].manuallyRetried, 'A retried step whose wait is unknown still carries the marker');
		Assert.isNull(steps[2].manualRetryAfterMs, 'An unknown wait is never shown as a number');
		Assert.isNull(steps[2].manualRetryAfterLabel, 'An unknown wait is never shown as text');
		Assert.areEqual(true, steps[3].manuallyRetried, 'A step retried in the instant it failed still carries the marker');
		Assert.areEqual(MANUAL_RETRY_ZERO_WAIT_MS, steps[3].manualRetryAfterMs, 'A wait of nothing is a measured wait, not an unknown one');
		Assert.areEqual(MANUAL_RETRY_ZERO_WAIT_LABEL, steps[3].manualRetryAfterLabel, 'A wait of nothing is formatted like any other');
	}

	/**
	 * @description Sorting by chain name ascending returns the runs in alphabetical order, whatever order they were created
	 * in, so the list is ordered by the column the operator chose.
	 */
	@IsTest
	private static void shouldReturnSortedResultsAscending()
	{
		TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_COMPLETED, 'AlphaChain');
		TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_COMPLETED, 'ZetaChain');
		TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_COMPLETED, 'BetaChain');

		CTRL_ChainMonitorTypes.DTO_Request request = new CTRL_ChainMonitorTypes.DTO_Request();
		request.sortField = 'ChainName';
		request.sortAscending = true;
		CTRL_ChainMonitorTypes.DTO_ChainPage result = CTRL_ChainMonitor.getChainExecutions(JSON.serialize(request));

		List<CTRL_ChainMonitorTypes.DTO_ChainSummary> records = result.records;
		Assert.areEqual('AlphaChain', records[0].chainName, 'First record should be AlphaChain');
		Assert.areEqual('BetaChain', records[1].chainName, 'Second record should be BetaChain');
		Assert.areEqual('ZetaChain', records[2].chainName, 'Third record should be ZetaChain');
	}

	/**
	 * @description The detail of a completed run carries the run's own values and one entry for each step read from its
	 * stored step log. A step is labelled with its display name, or with its class name when it has no display name, so
	 * every step in the detail has a label.
	 */
	@IsTest
	private static void shouldReturnChainDetailWithParsedSteps()
	{
		AsyncChainExecution__c execution = TST_Factory.newChainExecution(
				SEL_AsyncChainExecution.STATUS_COMPLETED, TEST_CHAIN, stepLogCompleted(), 3, 3
		);
		execution.DurationMs__c = 3200;
		DML_Builder.newTransaction().withSystemMode().doUpdate(execution).execute();

		CTRL_ChainMonitorTypes.DTO_ChainDetail detail = CTRL_ChainMonitor.getChainDetail(execution.Id);

		Assert.isNotNull(detail, 'Detail should not be null');
		Assert.areEqual(TEST_CHAIN, detail.chainName, 'Chain name should match');
		Assert.areEqual(SEL_AsyncChainExecution.STATUS_COMPLETED, detail.status, 'Status should match');
		Assert.areEqual(3, detail.totalSteps, 'Total steps should be 3');
		Assert.areEqual(3, detail.completedSteps, 'Completed steps should be 3');
		Assert.areEqual(3200, detail.durationMs, 'Duration should match stored value');
		Assert.areEqual(3, detail.steps.size(), 'Should have 3 parsed steps');
		Assert.areEqual('Create Account', detail.steps[0].name, 'First step should use stepName');
		Assert.areEqual('CallApiStep', detail.steps[1].name, 'Second step should fall back to className');
		Assert.areEqual(CTRL_ChainMonitor.STEP_STATUS_SUCCESS, detail.steps[0].stepStatus, 'Successful step should have success status');
	}

	/**
	 * @description A failed step that was allowed to continue shows as a warning, and a failed step that was not shows as
	 * failed, each with its error message. The operator can therefore tell which failure ended the run.
	 */
	@IsTest
	private static void shouldParseFailedStepsWithContinueOnError()
	{
		AsyncChainExecution__c execution = TST_Factory.newChainExecution(
				SEL_AsyncChainExecution.STATUS_FAILED, TEST_CHAIN, stepLogFailed(), 3, 1
		);

		CTRL_ChainMonitorTypes.DTO_ChainDetail detail = CTRL_ChainMonitor.getChainDetail(execution.Id);

		Assert.areEqual(3, detail.steps.size(), 'Should have 3 parsed steps');

		CTRL_ChainMonitorTypes.DTO_StepDetail successStep = detail.steps[0];
		Assert.areEqual(CTRL_ChainMonitor.STEP_STATUS_SUCCESS, successStep.stepStatus, 'First step should be success');

		CTRL_ChainMonitorTypes.DTO_StepDetail warnStep = detail.steps[1];
		Assert.areEqual(CTRL_ChainMonitor.STEP_STATUS_WARNING, warnStep.stepStatus, 'ContinueOnError step should be warning');
		Assert.areEqual('Non-fatal: skipped', warnStep.errorMessage, 'Should have error message');

		CTRL_ChainMonitorTypes.DTO_StepDetail failedStep = detail.steps[2];
		Assert.areEqual(CTRL_ChainMonitor.STEP_STATUS_FAILED, failedStep.stepStatus, 'Failed step should be error');
		Assert.areEqual('Required field missing', failedStep.errorMessage, 'Should have error message');
	}

	/**
	 * @description A step the recovery refused to run again is the step the run stopped at, so it shows as failed even when
	 * it was added with continueOnError, with the refusal as its error message.
	 */
	@IsTest
	private static void shouldShowARefusedContinueOnErrorStepAsFailed()
	{
		AsyncChainExecution__c execution = TST_Factory.newChainExecution(
				SEL_AsyncChainExecution.STATUS_FAILED, TEST_CHAIN, stepLogRefusedContinueOnError(), 2, 1
		);

		CTRL_ChainMonitorTypes.DTO_ChainDetail detail = CTRL_ChainMonitor.getChainDetail(execution.Id);

		Assert.areEqual(2, detail.steps.size(), 'Expected 2 parsed steps, got ' + detail.steps.size());
		CTRL_ChainMonitorTypes.DTO_StepDetail refusedStep = detail.steps[1];
		Assert.areEqual(CTRL_ChainMonitor.STEP_STATUS_FAILED, refusedStep.stepStatus, 'Expected the refused step to show as failed, got ' + refusedStep.stepStatus);
		Assert.areEqual(REFUSED_STEP_MESSAGE, refusedStep.errorMessage, 'Expected the refusal as the error message, got ' + refusedStep.errorMessage);
	}

	/**
	 * @description The timeline of a running chain lists only the chain's steps: the finished step as a success and the step
	 * not yet run as pending. The error handler and completion handler entries stored after the steps are left out, so the
	 * timeline never shows a handler as a step.
	 */
	@IsTest
	private static void shouldListOnlyChainStepsInRunningChainTimeline()
	{
		AsyncChainExecution__c execution = TST_Factory.newChainExecution(
				SEL_AsyncChainExecution.STATUS_RUNNING, TEST_CHAIN, stepLogRunning(), 2, 1
		);

		List<CTRL_ChainMonitorTypes.DTO_StepDetail> steps = CTRL_ChainMonitor.getStepTimeline(execution.Id);

		Assert.areEqual(2, steps.size(), 'The timeline must show chain steps only: handler entries persisted after the steps are excluded');
		Assert.areEqual(CTRL_ChainMonitor.STEP_STATUS_SUCCESS, steps[0].stepStatus, 'Completed step should be success');
		Assert.areEqual(CTRL_ChainMonitor.STEP_STATUS_PENDING, steps[1].stepStatus, 'Unexecuted step should be pending');
		Assert.areEqual('First Step', steps[0].name, 'The first timeline entry must be the first chain step');
		Assert.areEqual('Second Step', steps[1].name, 'The last timeline entry must be the last chain step, not a handler');
	}

	/**
	 * @description The step timeline returns every step of a completed run with its duration as short readable text:
	 * milliseconds for a step under a second ("800ms") and seconds for a longer one ("2.1s").
	 */
	@IsTest
	private static void shouldReturnStepTimelineForRecordPage()
	{
		AsyncChainExecution__c execution = TST_Factory.newChainExecution(
				SEL_AsyncChainExecution.STATUS_COMPLETED, TEST_CHAIN, stepLogCompleted(), 3, 3
		);

		List<CTRL_ChainMonitorTypes.DTO_StepDetail> steps = CTRL_ChainMonitor.getStepTimeline(execution.Id);

		Assert.areEqual(3, steps.size(), 'Should return 3 steps');
		Assert.areEqual('800ms', steps[0].durationLabel, 'Duration should be formatted');
		Assert.areEqual('2.1s', steps[1].durationLabel, 'Duration should be formatted');
		Assert.areEqual('300ms', steps[2].durationLabel, 'Duration should be formatted');
	}

	/**
	 * @description When a running chain has finished no step and no step was ever marked started, every step in the timeline
	 * is pending, the first one included. The word comes from what each step's own entry records (its result, and whether
	 * it started), not from its position in the chain.
	 */
	@IsTest
	private static void shouldShowEveryStepAsPendingWhenNoStepsCompleted()
	{
		String stepLog = buildStepLog(new List<UTIL_AsyncChain.DTO_StepDefinition>
		{
				buildStep('Step1', 'First Step', null, null),
				buildStep('Step2', 'Second Step', null, null)
		});

		AsyncChainExecution__c execution = TST_Factory.newChainExecution(
				SEL_AsyncChainExecution.STATUS_RUNNING, TEST_CHAIN, stepLog, 2, 0
		);

		List<CTRL_ChainMonitorTypes.DTO_StepDetail> steps = CTRL_ChainMonitor.getStepTimeline(execution.Id);

		Assert.areEqual(CTRL_ChainMonitor.STEP_STATUS_PENDING, steps[0].stepStatus, 'First unexecuted step should be pending');
		Assert.areEqual(CTRL_ChainMonitor.STEP_STATUS_PENDING, steps[1].stepStatus, 'Second step should be pending');
	}

	/**
	 * @description In a running chain the finished step shows as a success and each step never marked started shows as
	 * pending, so a step still to come is never shown as having succeeded, failed or started running.
	 */
	@IsTest
	private static void shouldShowPendingStepsAsNeutral()
	{
		String stepLog = buildStepLog(new List<UTIL_AsyncChain.DTO_StepDefinition>
		{
				buildStep('Step1', 'First Step', true, 400),
				buildStep('Step2', 'Second Step', null, null),
				buildStep('Step3', 'Third Step', null, null)
		});

		AsyncChainExecution__c execution = TST_Factory.newChainExecution(
				SEL_AsyncChainExecution.STATUS_RUNNING, TEST_CHAIN, stepLog, 3, 1
		);

		List<CTRL_ChainMonitorTypes.DTO_StepDetail> steps = CTRL_ChainMonitor.getStepTimeline(execution.Id);

		Assert.areEqual(3, steps.size(), 'Expected all three chain steps in the timeline, got ' + steps.size());
		Assert.areEqual(CTRL_ChainMonitor.STEP_STATUS_SUCCESS, steps[0].stepStatus, 'Completed step should be success');
		Assert.areEqual(CTRL_ChainMonitor.STEP_STATUS_PENDING, steps[1].stepStatus, 'Unexecuted step should be pending');
		Assert.areEqual(CTRL_ChainMonitor.STEP_STATUS_PENDING, steps[2].stepStatus, 'Future step should be pending');
	}

	/**
	 * @description On a Running chain each step state shows as the display table says: a started step with no result is the
	 * step running now, and a step never started is still to come.
	 */
	@IsTest
	private static void shouldShowEveryStepStateOnARunningChainAsTheTableSays()
	{
		assertDisplayRowsForChainStatus(SEL_AsyncChainExecution.STATUS_RUNNING);
	}

	/**
	 * @description On a Stalled chain each step state shows as the display table says: nothing is running, so a started
	 * step with no result and a step never started both show as pending.
	 */
	@IsTest
	private static void shouldShowEveryStepStateOnAStalledChainAsTheTableSays()
	{
		assertDisplayRowsForChainStatus(SEL_AsyncChainExecution.STATUS_STALLED);
	}

	/**
	 * @description On a Completed chain each step state shows as the display table says: a started step with no result
	 * shows that no result was recorded, and a step never started shows that it did not run.
	 */
	@IsTest
	private static void shouldShowEveryStepStateOnACompletedChainAsTheTableSays()
	{
		assertDisplayRowsForChainStatus(SEL_AsyncChainExecution.STATUS_COMPLETED);
	}

	/**
	 * @description On a Failed chain each step state shows as the display table says: a started step with no result
	 * shows that no result was recorded, and a step never started shows that it did not run.
	 */
	@IsTest
	private static void shouldShowEveryStepStateOnAFailedChainAsTheTableSays()
	{
		assertDisplayRowsForChainStatus(SEL_AsyncChainExecution.STATUS_FAILED);
	}

	/**
	 * @description On an Aborted chain each step state shows as the display table says: a started step with no result
	 * shows that no result was recorded, and a step never started shows that it did not run.
	 */
	@IsTest
	private static void shouldShowEveryStepStateOnAnAbortedChainAsTheTableSays()
	{
		assertDisplayRowsForChainStatus(SEL_AsyncChainExecution.STATUS_ABORTED);
	}

	/**
	 * @description Older versions of the package did not record whether a step started. So a step log written by them has
	 * no started record on any step. Its finished step reads from its result. Its step with no result reads as pending
	 * while the chain is Running, and as not run once the chain has failed. The started record decides the word, never the
	 * step's position.
	 */
	@IsTest
	private static void shouldReadALogWithNoStartedRecordFromItsResults()
	{
		String stepLog = buildStepLog(new List<UTIL_AsyncChain.DTO_StepDefinition>
		{
				buildStep(TABLE_STEP_CLASS, TABLE_STEP_NAME, true, TABLE_STEP_DURATION_MS),
				buildStep(TABLE_STEP_CLASS, TABLE_STEP_NAME, null, null)
		});
		AsyncChainExecution__c runningExecution = TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_RUNNING, TEST_CHAIN, stepLog, 2, 1);
		AsyncChainExecution__c failedExecution = TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_FAILED, TEST_CHAIN, stepLog, 2, 1);

		List<CTRL_ChainMonitorTypes.DTO_StepDetail> runningSteps = CTRL_ChainMonitor.getChainDetail(runningExecution.Id).steps;
		List<CTRL_ChainMonitorTypes.DTO_StepDetail> failedSteps = CTRL_ChainMonitor.getChainDetail(failedExecution.Id).steps;

		Assert.areEqual(CTRL_ChainMonitor.STEP_STATUS_SUCCESS, runningSteps[0].stepStatus, 'Expected the finished step of the Running chain to read success, got '
				+ runningSteps[0].stepStatus);
		Assert.areEqual(CTRL_ChainMonitor.STEP_STATUS_PENDING, runningSteps[1].stepStatus, 'Expected the step with no started record in the Running chain to read pending, got '
				+ runningSteps[1].stepStatus);
		Assert.areEqual(CTRL_ChainMonitor.STEP_STATUS_SUCCESS, failedSteps[0].stepStatus, 'Expected the finished step of the Failed chain to read success, got '
				+ failedSteps[0].stepStatus);
		Assert.areEqual(CTRL_ChainMonitor.STEP_STATUS_DID_NOT_RUN, failedSteps[1].stepStatus, 'Expected the step with no started record in the Failed chain to read didNotRun, got '
				+ failedSteps[1].stepStatus);
	}

	/**
	 * @description A chain in a status the engine never writes (Delayed) has not ended. So a step that started and a step
	 * that never started both read pending, never noResultRecorded or didNotRun. The package refuses to save a Delayed
	 * run, so the test does not save one. It gives the timeline a stand-in record instead.
	 */
	@IsTest
	private static void shouldShowPendingStepsOnAChainInAStatusTheEngineNeverWrites()
	{
		String stepLog = buildStepLog(new List<UTIL_AsyncChain.DTO_StepDefinition> {buildStartedEntry(), buildNotStartedEntry()});
		AsyncChainExecution__c delayedExecution = (AsyncChainExecution__c)TST_Builder.of(AsyncChainExecution__c.SObjectType)
				.withOverride(AsyncChainExecution__c.ChainName__c, TEST_CHAIN)
				.withOverride(AsyncChainExecution__c.Status__c, STATUS_DELAYED)
				.withOverride(AsyncChainExecution__c.StepLog__c, stepLog)
				.withoutInsertion(true)
				.build();
		TST_Mock.register(AsyncChainExecution__c.SObjectType, delayedExecution);

		List<CTRL_ChainMonitorTypes.DTO_StepDetail> steps = CTRL_ChainMonitor.getStepTimeline(delayedExecution.Id);

		Assert.areEqual(2, steps.size(), 'Expected both steps of the Delayed chain on the timeline, got ' + steps.size());
		Assert.areEqual(CTRL_ChainMonitor.STEP_STATUS_PENDING, steps[0].stepStatus, 'Expected the started step of the Delayed chain to read pending, got '
				+ steps[0].stepStatus);
		Assert.areEqual(CTRL_ChainMonitor.STEP_STATUS_PENDING, steps[1].stepStatus, 'Expected the step that never started in the Delayed chain to read pending, got '
				+ steps[1].stepStatus);
	}

	/**
	 * @description Seeds one single-step run per row of the display table for the given chain status, reads each run
	 * through the controller's detail endpoint and asserts the step's display word against the row.
	 *
	 * @param chainStatus The chain status whose six rows to prove.
	 */
	private static void assertDisplayRowsForChainStatus(String chainStatus)
	{
		List<StepDisplayRow> rows = new List<StepDisplayRow>();
		List<AsyncChainExecution__c> executions = new List<AsyncChainExecution__c>();

		for(StepDisplayRow row : buildStepDisplayTable())
		{
			if(row.chainStatus == chainStatus)
			{
				Integer completedSteps = row.state == UTIL_AsyncChain.StepState.SUCCEEDED || row.state == UTIL_AsyncChain.StepState.FAILED_CONTINUED ? 1 : 0;
				String stepLog = buildStepLog(new List<UTIL_AsyncChain.DTO_StepDefinition> {buildEntryForState(row.state)});
				rows.add(row);
				executions.add(TST_Factory.newChainExecution(chainStatus, TEST_CHAIN, stepLog, 1, completedSteps));
			}
		}

		Assert.areEqual(STEP_STATES_PER_CHAIN_STATUS, rows.size(), 'Expected one table row per step state for status ' + chainStatus + ', got ' + rows.size());

		for(Integer index = 0; index < rows.size(); index++)
		{
			List<CTRL_ChainMonitorTypes.DTO_StepDetail> steps = CTRL_ChainMonitor.getChainDetail(executions[index].Id).steps;
			StepDisplayRow row = rows[index];

			Assert.areEqual(1, steps.size(), 'Expected one step in the detail of the ' + row.state.name() + ' run, got ' + steps.size());
			Assert.areEqual(row.expectedWord, steps[0].stepStatus, 'Expected ' + row.expectedWord + ' for a ' + row.state.name() + ' step on a chain in status '
					+ chainStatus + ', got ' + steps[0].stepStatus);
		}
	}

	/**
	 * @description The display table, written out by hand: every step state against every chain status, and the word the
	 * controller sends for that pair.
	 *
	 * @return The thirty rows of the table.
	 */
	private static List<StepDisplayRow> buildStepDisplayTable()
	{
		return new List<StepDisplayRow>
		{
				new StepDisplayRow(UTIL_AsyncChain.StepState.SUCCEEDED, SEL_AsyncChainExecution.STATUS_RUNNING, CTRL_ChainMonitor.STEP_STATUS_SUCCESS),
				new StepDisplayRow(UTIL_AsyncChain.StepState.SUCCEEDED, SEL_AsyncChainExecution.STATUS_STALLED, CTRL_ChainMonitor.STEP_STATUS_SUCCESS),
				new StepDisplayRow(UTIL_AsyncChain.StepState.SUCCEEDED, SEL_AsyncChainExecution.STATUS_COMPLETED, CTRL_ChainMonitor.STEP_STATUS_SUCCESS),
				new StepDisplayRow(UTIL_AsyncChain.StepState.SUCCEEDED, SEL_AsyncChainExecution.STATUS_FAILED, CTRL_ChainMonitor.STEP_STATUS_SUCCESS),
				new StepDisplayRow(UTIL_AsyncChain.StepState.SUCCEEDED, SEL_AsyncChainExecution.STATUS_ABORTED, CTRL_ChainMonitor.STEP_STATUS_SUCCESS),
				new StepDisplayRow(UTIL_AsyncChain.StepState.FAILED_CONTINUED, SEL_AsyncChainExecution.STATUS_RUNNING, CTRL_ChainMonitor.STEP_STATUS_WARNING),
				new StepDisplayRow(UTIL_AsyncChain.StepState.FAILED_CONTINUED, SEL_AsyncChainExecution.STATUS_STALLED, CTRL_ChainMonitor.STEP_STATUS_WARNING),
				new StepDisplayRow(UTIL_AsyncChain.StepState.FAILED_CONTINUED, SEL_AsyncChainExecution.STATUS_COMPLETED, CTRL_ChainMonitor.STEP_STATUS_WARNING),
				new StepDisplayRow(UTIL_AsyncChain.StepState.FAILED_CONTINUED, SEL_AsyncChainExecution.STATUS_FAILED, CTRL_ChainMonitor.STEP_STATUS_WARNING),
				new StepDisplayRow(UTIL_AsyncChain.StepState.FAILED_CONTINUED, SEL_AsyncChainExecution.STATUS_ABORTED, CTRL_ChainMonitor.STEP_STATUS_WARNING),
				new StepDisplayRow(UTIL_AsyncChain.StepState.FAILED_STOPPED, SEL_AsyncChainExecution.STATUS_RUNNING, CTRL_ChainMonitor.STEP_STATUS_FAILED),
				new StepDisplayRow(UTIL_AsyncChain.StepState.FAILED_STOPPED, SEL_AsyncChainExecution.STATUS_STALLED, CTRL_ChainMonitor.STEP_STATUS_FAILED),
				new StepDisplayRow(UTIL_AsyncChain.StepState.FAILED_STOPPED, SEL_AsyncChainExecution.STATUS_COMPLETED, CTRL_ChainMonitor.STEP_STATUS_FAILED),
				new StepDisplayRow(UTIL_AsyncChain.StepState.FAILED_STOPPED, SEL_AsyncChainExecution.STATUS_FAILED, CTRL_ChainMonitor.STEP_STATUS_FAILED),
				new StepDisplayRow(UTIL_AsyncChain.StepState.FAILED_STOPPED, SEL_AsyncChainExecution.STATUS_ABORTED, CTRL_ChainMonitor.STEP_STATUS_FAILED),
				new StepDisplayRow(UTIL_AsyncChain.StepState.RECOVERY_REFUSED, SEL_AsyncChainExecution.STATUS_RUNNING, CTRL_ChainMonitor.STEP_STATUS_FAILED),
				new StepDisplayRow(UTIL_AsyncChain.StepState.RECOVERY_REFUSED, SEL_AsyncChainExecution.STATUS_STALLED, CTRL_ChainMonitor.STEP_STATUS_FAILED),
				new StepDisplayRow(UTIL_AsyncChain.StepState.RECOVERY_REFUSED, SEL_AsyncChainExecution.STATUS_COMPLETED, CTRL_ChainMonitor.STEP_STATUS_FAILED),
				new StepDisplayRow(UTIL_AsyncChain.StepState.RECOVERY_REFUSED, SEL_AsyncChainExecution.STATUS_FAILED, CTRL_ChainMonitor.STEP_STATUS_FAILED),
				new StepDisplayRow(UTIL_AsyncChain.StepState.RECOVERY_REFUSED, SEL_AsyncChainExecution.STATUS_ABORTED, CTRL_ChainMonitor.STEP_STATUS_FAILED),
				new StepDisplayRow(UTIL_AsyncChain.StepState.STARTED, SEL_AsyncChainExecution.STATUS_RUNNING, CTRL_ChainMonitor.STEP_STATUS_RUNNING),
				new StepDisplayRow(UTIL_AsyncChain.StepState.STARTED, SEL_AsyncChainExecution.STATUS_STALLED, CTRL_ChainMonitor.STEP_STATUS_PENDING),
				new StepDisplayRow(UTIL_AsyncChain.StepState.STARTED, SEL_AsyncChainExecution.STATUS_COMPLETED, CTRL_ChainMonitor.STEP_STATUS_NO_RESULT_RECORDED),
				new StepDisplayRow(UTIL_AsyncChain.StepState.STARTED, SEL_AsyncChainExecution.STATUS_FAILED, CTRL_ChainMonitor.STEP_STATUS_NO_RESULT_RECORDED),
				new StepDisplayRow(UTIL_AsyncChain.StepState.STARTED, SEL_AsyncChainExecution.STATUS_ABORTED, CTRL_ChainMonitor.STEP_STATUS_NO_RESULT_RECORDED),
				new StepDisplayRow(UTIL_AsyncChain.StepState.NOT_STARTED, SEL_AsyncChainExecution.STATUS_RUNNING, CTRL_ChainMonitor.STEP_STATUS_PENDING),
				new StepDisplayRow(UTIL_AsyncChain.StepState.NOT_STARTED, SEL_AsyncChainExecution.STATUS_STALLED, CTRL_ChainMonitor.STEP_STATUS_PENDING),
				new StepDisplayRow(UTIL_AsyncChain.StepState.NOT_STARTED, SEL_AsyncChainExecution.STATUS_COMPLETED, CTRL_ChainMonitor.STEP_STATUS_DID_NOT_RUN),
				new StepDisplayRow(UTIL_AsyncChain.StepState.NOT_STARTED, SEL_AsyncChainExecution.STATUS_FAILED, CTRL_ChainMonitor.STEP_STATUS_DID_NOT_RUN),
				new StepDisplayRow(UTIL_AsyncChain.StepState.NOT_STARTED, SEL_AsyncChainExecution.STATUS_ABORTED, CTRL_ChainMonitor.STEP_STATUS_DID_NOT_RUN)
		};
	}

	/**
	 * @description Builds the step entry whose fields resolve to the given state.
	 *
	 * @param state The state the entry must resolve to.
	 *
	 * @return The step entry.
	 */
	private static UTIL_AsyncChain.DTO_StepDefinition buildEntryForState(UTIL_AsyncChain.StepState state)
	{
		switch on state
		{
			when SUCCEEDED
			{
				return buildSucceededEntry();
			}
			when FAILED_CONTINUED
			{
				return buildFailedContinuedEntry();
			}
			when FAILED_STOPPED
			{
				return buildFailedStoppedEntry();
			}
			when RECOVERY_REFUSED
			{
				return buildRecoveryRefusedEntry();
			}
			when STARTED
			{
				return buildStartedEntry();
			}
			when else
			{
				return buildNotStartedEntry();
			}
		}
	}

	/**
	 * @description A step that started and recorded a success.
	 *
	 * @return The step entry.
	 */
	private static UTIL_AsyncChain.DTO_StepDefinition buildSucceededEntry()
	{
		UTIL_AsyncChain.DTO_StepDefinition entry = buildStartedEntry();
		entry.success = true;
		entry.durationMs = TABLE_STEP_DURATION_MS;
		return entry;
	}

	/**
	 * @description A step added with continueOnError that started and recorded a failure the chain carried on from.
	 *
	 * @return The step entry.
	 */
	private static UTIL_AsyncChain.DTO_StepDefinition buildFailedContinuedEntry()
	{
		UTIL_AsyncChain.DTO_StepDefinition entry = buildFailedStoppedEntry();
		entry.continueOnError = true;
		return entry;
	}

	/**
	 * @description A step that started and recorded a failure the chain stopped at.
	 *
	 * @return The step entry.
	 */
	private static UTIL_AsyncChain.DTO_StepDefinition buildFailedStoppedEntry()
	{
		UTIL_AsyncChain.DTO_StepDefinition entry = buildStartedEntry();
		entry.success = false;
		entry.durationMs = TABLE_STEP_DURATION_MS;
		entry.message = TABLE_STEP_FAILURE_MESSAGE;
		return entry;
	}

	/**
	 * @description A step added with continueOnError that the watchdog refused to run again, so the chain stopped at it.
	 *
	 * @return The step entry.
	 */
	private static UTIL_AsyncChain.DTO_StepDefinition buildRecoveryRefusedEntry()
	{
		UTIL_AsyncChain.DTO_StepDefinition entry = buildStartedEntry();
		entry.success = false;
		entry.continueOnError = true;
		entry.recoveryRefused = true;
		entry.message = REFUSED_STEP_MESSAGE;
		return entry;
	}

	/**
	 * @description A step that has started but has no result yet.
	 *
	 * @return The step entry.
	 */
	private static UTIL_AsyncChain.DTO_StepDefinition buildStartedEntry()
	{
		UTIL_AsyncChain.DTO_StepDefinition entry = buildNotStartedEntry();
		entry.started = true;
		return entry;
	}

	/**
	 * @description A step that never started.
	 *
	 * @return The step entry.
	 */
	private static UTIL_AsyncChain.DTO_StepDefinition buildNotStartedEntry()
	{
		return buildStep(TABLE_STEP_CLASS, TABLE_STEP_NAME, null, null);
	}

	/**
	 * @description One row of the step display table: a step state, the status of the chain it sits in, and the word the
	 * controller must send for that pair.
	 */
	private inherited sharing class StepDisplayRow
	{
		/**
		 * @description The state the row's step entry resolves to.
		 */
		private final UTIL_AsyncChain.StepState state;

		/**
		 * @description The status of the chain the step sits in.
		 */
		private final String chainStatus;

		/**
		 * @description The display word the controller must send for the step.
		 */
		private final String expectedWord;

		/**
		 * @description Creates one row of the table.
		 *
		 * @param state The state the row's step entry resolves to.
		 * @param chainStatus The status of the chain the step sits in.
		 * @param expectedWord The display word the controller must send for the step.
		 */
		private StepDisplayRow(UTIL_AsyncChain.StepState state, String chainStatus, String expectedWord)
		{
			this.state = state;
			this.chainStatus = chainStatus;
			this.expectedWord = expectedWord;
		}
	}

	/**
	 * @description With no run id, or with the id of a run that does not exist, the detail read returns null and the
	 * timeline read returns an empty list. A caller that has no run to show gets nothing back and no error.
	 */
	@IsTest
	private static void shouldReturnEmptyForNonexistentExecution()
	{
		Id missingExecutionId = UTIL_Random.randomId(AsyncChainExecution__c.SObjectType);

		Assert.isNull(CTRL_ChainMonitor.getChainDetail(null), 'Expected no detail for a null id');
		Assert.isTrue(CTRL_ChainMonitor.getStepTimeline(null).isEmpty(), 'Expected an empty timeline for a null id');
		Assert.isNull(CTRL_ChainMonitor.getChainDetail(missingExecutionId), 'Expected no detail for the id of a run that does not exist');
		Assert.isTrue(CTRL_ChainMonitor.getStepTimeline(missingExecutionId).isEmpty(), 'Expected an empty timeline for the id of a run that does not exist');
	}

	/**
	 * @description A status filter that no run matches returns an empty list and no error: the only run is Completed and the
	 * filter asks for Running.
	 */
	@IsTest
	private static void shouldReturnEmptyForNoMatchingFilters()
	{
		TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_COMPLETED, TEST_CHAIN);

		CTRL_ChainMonitorTypes.DTO_Request request = new CTRL_ChainMonitorTypes.DTO_Request();
		request.statusFilters = new List<String> {SEL_AsyncChainExecution.STATUS_RUNNING};
		CTRL_ChainMonitorTypes.DTO_ChainPage result = CTRL_ChainMonitor.getChainExecutions(JSON.serialize(request));

		Assert.isTrue(result.records.isEmpty(), 'Should return empty list when no chains match');
	}

	/**
	 * @description A null request is read as "no filters" and returns every run, so a caller that sends nothing still gets
	 * the unfiltered list and no error.
	 */
	@IsTest
	private static void shouldHandleNullFilters()
	{
		TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_COMPLETED, TEST_CHAIN);

		CTRL_ChainMonitorTypes.DTO_ChainPage result = CTRL_ChainMonitor.getChainExecutions(null);

		Assert.areEqual(1, result.records.size(), 'Should return all records when no filters applied');
	}

	/**
	 * @description A run with no stored step log has a detail with an empty step list, so the detail of a run that recorded
	 * no steps can still be read.
	 */
	@IsTest
	private static void shouldHandleBlankStepLog()
	{
		AsyncChainExecution__c execution = TST_Factory.newChainExecution(
				SEL_AsyncChainExecution.STATUS_COMPLETED, TEST_CHAIN, null, 0, 0
		);

		CTRL_ChainMonitorTypes.DTO_ChainDetail detail = CTRL_ChainMonitor.getChainDetail(execution.Id);
		Assert.isTrue(detail.steps.isEmpty(), 'Steps should be empty when StepLog is blank');
	}

	/**
	 * @description A running chain has no stored duration yet, so its detail carries a duration worked out for it: a
	 * positive number with a formatted label. The operator sees how long the run has been going instead of a blank.
	 */
	@IsTest
	private static void shouldComputeDurationForRunningChain()
	{
		AsyncChainExecution__c execution = TST_Factory.newChainExecution(
				SEL_AsyncChainExecution.STATUS_RUNNING, TEST_CHAIN, null, 2, 0
		);

		CTRL_ChainMonitorTypes.DTO_ChainDetail detail = CTRL_ChainMonitor.getChainDetail(execution.Id);

		Assert.isNotNull(detail.durationMs, 'Duration should be computed for running chain');
		Assert.isTrue(detail.durationMs > 0, 'Duration should be positive for running chain');
		Assert.isNotNull(detail.durationLabel, 'Duration label should be set');
	}

	/**
	 * @description The active run time in a run's detail is the sum of the durations of its steps: 800, 2,100 and 300
	 * milliseconds give 3,200, shown as "3.2s" like every other duration.
	 */
	@IsTest
	private static void shouldSumStepRunsAsTheActiveRunTime()
	{
		AsyncChainExecution__c execution = TST_Factory.newChainExecution(
				SEL_AsyncChainExecution.STATUS_COMPLETED, TEST_CHAIN, stepLogCompleted(), 3, 3
		);

		CTRL_ChainMonitorTypes.DTO_ChainDetail detail = CTRL_ChainMonitor.getChainDetail(execution.Id);

		Assert.areEqual(3200L, detail.activeDurationMs, 'The active run time must be the sum of the three step runs');
		Assert.areEqual('3.2s', detail.activeDurationLabel, 'The active run time must be formatted the way every other duration is');
	}

	/**
	 * @description Only steps that have run count towards the active run time: a running chain with one finished step of 400
	 * milliseconds and one pending step reports 400 milliseconds.
	 */
	@IsTest
	private static void shouldLeaveUnrunStepsOutOfTheActiveRunTime()
	{
		AsyncChainExecution__c execution = TST_Factory.newChainExecution(
				SEL_AsyncChainExecution.STATUS_RUNNING, TEST_CHAIN, stepLogRunning(), 2, 1
		);

		CTRL_ChainMonitorTypes.DTO_ChainDetail detail = CTRL_ChainMonitor.getChainDetail(execution.Id);

		Assert.areEqual(400L, detail.activeDurationMs, 'Only the step that actually ran may count towards the active run time');
		Assert.areEqual('400ms', detail.activeDurationLabel, 'The active run time must be formatted the way every other duration is');
	}

	/**
	 * @description A chain whose steps have not run reports no active run time and no label for it: both are null, never a
	 * zero that would read as a measured time.
	 */
	@IsTest
	private static void shouldRecordNoActiveRunTimeWhenNoStepHasRunYet()
	{
		String stepLog = buildStepLog(new List<UTIL_AsyncChain.DTO_StepDefinition>
		{
				buildStep('Step1', 'First Step', null, null),
				buildStep('Step2', 'Second Step', null, null)
		});

		AsyncChainExecution__c execution = TST_Factory.newChainExecution(
				SEL_AsyncChainExecution.STATUS_RUNNING, TEST_CHAIN, stepLog, 2, 0
		);

		CTRL_ChainMonitorTypes.DTO_ChainDetail detail = CTRL_ChainMonitor.getChainDetail(execution.Id);

		Assert.isNull(detail.activeDurationMs, 'A chain whose steps have not run must report no active run time');
		Assert.isNull(detail.activeDurationLabel, 'A chain whose steps have not run must report no active run time label');
	}

	/**
	 * @description A list row carries the run's id, chain name, status and stored duration, with the duration also as
	 * readable text: 45,000 milliseconds reads "45s".
	 */
	@IsTest
	private static void shouldPopulateSummaryDtoFields()
	{
		AsyncChainExecution__c execution = TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_COMPLETED, TEST_CHAIN);
		execution.DurationMs__c = 45000;
		DML_Builder.newTransaction().withSystemMode().doUpdate(execution).execute();

		CTRL_ChainMonitorTypes.DTO_ChainPage result = CTRL_ChainMonitor.getChainExecutions(null);

		CTRL_ChainMonitorTypes.DTO_ChainSummary summary = result.records[0];
		Assert.isNotNull(summary.executionId, 'Execution ID should be set');
		Assert.areEqual(TEST_CHAIN, summary.chainName, 'Chain name should match');
		Assert.areEqual(SEL_AsyncChainExecution.STATUS_COMPLETED, summary.status, 'Status should match');
		Assert.areEqual(45000, summary.durationMs, 'Duration should match');
		Assert.areEqual('45s', summary.durationLabel, 'Duration label should be formatted');
	}

	/**
	 * @description A stalled run records no final duration, so a list row that reported only the
	 * recorded value was blank for exactly the rows a stuck-chain triage measures. The row now
	 * carries how long the run has been going, which is the number that answers "how long has this
	 * been hanging?".
	 */
	@IsTest
	private static void shouldReportElapsedTimeOnAStalledListRow()
	{
		TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_STALLED, TEST_CHAIN,
				new Map<SObjectField, Object> {AsyncChainExecution__c.StartedAt__c => Datetime.now().addMinutes(-ELAPSED_MINUTES)});

		CTRL_ChainMonitorTypes.DTO_ChainPage result = CTRL_ChainMonitor.getChainExecutions(null);

		CTRL_ChainMonitorTypes.DTO_ChainSummary summary = result.records[0];
		Assert.isNotNull(summary.durationMs, 'A stalled row must report the time its run has been going');
		Assert.isTrue(summary.durationMs > 0, 'The elapsed time of a run started in the past must be positive');
		Assert.isNotNull(summary.durationLabel, 'The elapsed time must reach the row as a formatted label');
	}

	/**
	 * @description The same rule reaches the detail pane, so opening a stalled row from the list
	 * shows the value the row just showed instead of an empty Timing entry.
	 */
	@IsTest
	private static void shouldReportElapsedTimeOnAStalledChainDetail()
	{
		AsyncChainExecution__c execution = TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_STALLED, TEST_CHAIN,
				new Map<SObjectField, Object> {AsyncChainExecution__c.StartedAt__c => Datetime.now().addMinutes(-ELAPSED_MINUTES)});

		CTRL_ChainMonitorTypes.DTO_ChainDetail detail = CTRL_ChainMonitor.getChainDetail(execution.Id);

		Assert.isNotNull(detail.durationMs, 'A stalled chain must report the time its run has been going');
		Assert.isTrue(detail.durationMs > 0, 'The elapsed time of a run started in the past must be positive');
	}

	/**
	 * @description A row that recorded a completion instant has ended, whatever its status says.
	 * Counting on from its start would grow without bound on a row nothing will ever touch again,
	 * so the ended row reports no duration rather than a running total. The package no longer lets anyone save a Stalled
	 * record with an end time. Older orgs still have such records. So the test does not save one. It gives the list a
	 * stand-in record and asks Salesforce to work out the record's elapsed-time formula first.
	 */
	@IsTest
	private static void shouldReportNoElapsedTimeOnAStalledRowThatAlreadyEnded()
	{
		AsyncChainExecution__c endedStall = (AsyncChainExecution__c)TST_Builder.of(AsyncChainExecution__c.SObjectType)
				.withOverride(AsyncChainExecution__c.ChainName__c, TEST_CHAIN)
				.withOverride(AsyncChainExecution__c.Status__c, SEL_AsyncChainExecution.STATUS_STALLED)
				.withOverride(AsyncChainExecution__c.StartedAt__c, Datetime.now().addMinutes(-ELAPSED_MINUTES))
				.withOverride(AsyncChainExecution__c.CompletedAt__c, Datetime.now())
				.withoutInsertion(true)
				.build();
		Formula.recalculateFormulas(new List<SObject> {endedStall});
		TST_Mock.register(AsyncChainExecution__c.SObjectType, endedStall);

		CTRL_ChainMonitorTypes.DTO_ChainPage result = CTRL_ChainMonitor.getChainExecutions(null);

		Assert.isNull(result.records[0].durationMs, 'A row carrying a completion instant must not report a still-running elapsed time');
		Assert.isNull(result.records[0].durationLabel, 'A row carrying a completion instant must not report an elapsed label');
	}

	/**
	 * @description A finished run that recorded no duration reports none: the elapsed fallback is
	 * scoped to runs that have not finished, so a completed row never gains an invented number. The package no longer lets
	 * anyone save a Completed record without an end time. Older orgs still have such records. So the test does not save
	 * one. It gives the list a stand-in record and asks Salesforce to work out the record's elapsed-time formula first.
	 */
	@IsTest
	private static void shouldReportNoElapsedTimeOnAFinishedListRow()
	{
		AsyncChainExecution__c finishedWithoutEnd = (AsyncChainExecution__c)TST_Builder.of(AsyncChainExecution__c.SObjectType)
				.withOverride(AsyncChainExecution__c.ChainName__c, TEST_CHAIN)
				.withOverride(AsyncChainExecution__c.Status__c, SEL_AsyncChainExecution.STATUS_COMPLETED)
				.withOverride(AsyncChainExecution__c.StartedAt__c, Datetime.now().addMinutes(-ELAPSED_MINUTES))
				.withoutInsertion(true)
				.build();
		Formula.recalculateFormulas(new List<SObject> {finishedWithoutEnd});
		TST_Mock.register(AsyncChainExecution__c.SObjectType, finishedWithoutEnd);

		CTRL_ChainMonitorTypes.DTO_ChainPage result = CTRL_ChainMonitor.getChainExecutions(null);

		Assert.isNull(result.records[0].durationMs, 'A completed row without a recorded duration must report none');
	}

	/**
	 * @description The clear-stalled dialog states how many chains are waiting before the operator
	 * commits, so the count travels with the operations state the header already loads. Only rows
	 * the sweep would take are counted: a stalled row carrying a completion instant is a finished
	 * run the sweep skips. The package now blocks saving a Stalled record that has an end time. Older orgs still have
	 * such records. So this test turns off that one check while it saves the record. The count is gathered only for a
	 * caller the sweep is open to, and the
	 * packaging org's validation user holds no packaged permission, so the gate's flag is
	 * activated through the factory rather than trusted to the org's own grants (User DML is
	 * barred in this parallel-annotated class).
	 */
	@IsTest
	private static void shouldCountStalledChainsWaitingForTheSweep()
	{
		TST_Factory.newFeatureFlag(UTIL_AsyncChain.REDRIVE_FEATURE_FLAG_NAME);
		TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_STALLED, TEST_CHAIN);
		TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_STALLED, TEST_CHAIN);
		String actionClassName = TST_Factory.getRunTransitionActionClassName();
		TRG_Base.bypassAction(actionClassName);
		try
		{
			TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_STALLED, TEST_CHAIN,
					new Map<SObjectField, Object> {AsyncChainExecution__c.CompletedAt__c => Datetime.now()});
		}
		finally
		{
			TRG_Base.clearActionBypass(actionClassName);
		}
		TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_RUNNING, TEST_CHAIN);

		CTRL_ChainMonitorTypes.DTO_OperationsState state = CTRL_ChainMonitor.getChainOperationsState();

		Assert.areEqual(STALLED_AWAITING_SWEEP_COUNT, state.stalledChainCount, 'Only stalled rows without a completion instant are waiting for the sweep');
	}

	/**
	 * @description Seeds a Running chain row carrying the given correlation id, for the deep-link
	 * and stream-seed tests that key on correlation.
	 *
	 * @param correlationId The correlation id to stamp on the row.
	 *
	 * @return The seeded AsyncChainExecution__c record.
	 */
	private static AsyncChainExecution__c seedCorrelatedChain(String correlationId)
	{
		return (AsyncChainExecution__c)TST_Builder.of(AsyncChainExecution__c.SObjectType)
				.withOverride(AsyncChainExecution__c.ChainName__c, TEST_CHAIN)
				.withOverride(AsyncChainExecution__c.Status__c, SEL_AsyncChainExecution.STATUS_RUNNING)
				.withOverride(AsyncChainExecution__c.CorrelationId__c, correlationId)
				.build();
	}

	/**
	 * @description Seeds persisted log entries carrying the given correlation id, for the
	 * stream-seed tests.
	 *
	 * @param correlationId The correlation id to stamp on the entries.
	 * @param rowCount How many entries to seed.
	 */
	private static void seedLogEntries(String correlationId, Integer rowCount)
	{
		seedLogEntries(correlationId, rowCount, TEST_LOG_MESSAGE);
	}

	/**
	 * @description Seeds persisted log entries carrying the given correlation id and short message,
	 * for the stream-seed tests that discriminate blocks of a trace by their message.
	 *
	 * @param correlationId The correlation id to stamp on the entries.
	 * @param rowCount How many entries to seed.
	 * @param shortMessage The short message to stamp on the entries.
	 */
	private static void seedLogEntries(String correlationId, Integer rowCount, String shortMessage)
	{
		TST_Builder.of(LogEntry__c.SObjectType)
				.withOverride(LogEntry__c.CorrelationId__c, correlationId)
				.withOverride(LogEntry__c.LogLevel__c, TEST_LOG_LEVEL)
				.withOverride(LogEntry__c.ShortMessage__c, shortMessage)
				.withCount(rowCount)
				.buildList();
	}

	/**
	 * @description Given a correlation id (the tracking id that follows one action across its work), the lookup returns the
	 * id of the run that carries it and not the id of another run, so a caller that knows only the tracking id can find
	 * the run.
	 */
	@IsTest
	private static void shouldFindChainExecutionIdByCorrelation()
	{
		String correlationId = UTIL_Random.randomUUID();
		AsyncChainExecution__c execution = seedCorrelatedChain(correlationId);
		TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_COMPLETED, 'OtherChain');

		Id resolvedId = CTRL_ChainMonitor.findChainExecutionIdByCorrelation(correlationId);

		Assert.areEqual(execution.Id, resolvedId, 'Should resolve the chain execution that carries the correlation id');
	}

	/**
	 * @description A correlation id that no run carries resolves to null, even when other runs exist: the lookup never
	 * returns a run that does not belong to the id.
	 */
	@IsTest
	private static void shouldReturnNullForUnknownCorrelation()
	{
		TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_RUNNING, TEST_CHAIN);

		Id resolvedId = CTRL_ChainMonitor.findChainExecutionIdByCorrelation(UTIL_Random.randomUUID());

		Assert.isNull(resolvedId, 'Should return null when no chain carries the correlation id');
	}

	/**
	 * @description A null or empty correlation id resolves to null and does not throw, so a caller with no tracking id gets
	 * a clear "no run" answer.
	 */
	@IsTest
	private static void shouldReturnNullForBlankCorrelation()
	{
		Assert.isNull(CTRL_ChainMonitor.findChainExecutionIdByCorrelation(null), 'Should return null for a null correlation id');
		Assert.isNull(CTRL_ChainMonitor.findChainExecutionIdByCorrelation(''), 'Should return null for an empty correlation id');
	}

	/**
	 * @description Tests that the run detail carries the id the run was launched under and the root correlation id, so
	 * the detail panel can show them beside the run's own correlation.
	 */
	@IsTest
	private static void shouldCarryTheLaunchAndRootIdsOnTheDetail()
	{
		String launchCorrelationId = UTIL_Random.randomUUID();
		String rootCorrelationId = UTIL_Random.randomUUID();
		AsyncChainExecution__c execution = TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_COMPLETED, TEST_CHAIN, new Map<SObjectField, Object>
		{
				AsyncChainExecution__c.LaunchCorrelationId__c => launchCorrelationId,
				AsyncChainExecution__c.RootCorrelationId__c => rootCorrelationId
		});

		Test.startTest();
		CTRL_ChainMonitorTypes.DTO_ChainDetail detail = CTRL_ChainMonitor.getChainDetail(execution.Id);
		Test.stopTest();

		Assert.areEqual(launchCorrelationId, detail.launchCorrelationId, 'The detail carries the id the run was launched under');
		Assert.areEqual(rootCorrelationId, detail.rootCorrelationId, 'The detail carries the root');
	}

	/**
	 * @description Scoped to an action, the list holds the runs launched under that action and no other.
	 */
	@IsTest
	private static void shouldListOnlyTheRunsOfAnAction()
	{
		AsyncChainExecution__c job = seedTrackedRun('NightlyJob', JOB_ROOT_ID, JOB_ROOT_ID, null, null, SEL_AsyncChainExecution.STATUS_COMPLETED);
		seedTrackedRun('Elsewhere', UTIL_Random.randomUUID(), UTIL_Random.randomUUID(), null, null, SEL_AsyncChainExecution.STATUS_COMPLETED);

		CTRL_ChainMonitorTypes.DTO_Request request = new CTRL_ChainMonitorTypes.DTO_Request();
		request.rootCorrelationId = JOB_ROOT_ID;
		CTRL_ChainMonitorTypes.DTO_ChainPage result = CTRL_ChainMonitor.getChainExecutions(JSON.serialize(request));

		Assert.areEqual(1, result.totalCount, 'Only the action\'s run is listed');
		Assert.areEqual(job.Id, result.records[0].executionId, 'The listed run is the job');
	}

	/**
	 * @description The Launched-under column reads the four cases in order: a run holding the launch id names that run as a
	 * link; a launch id no run holds is the action's own launch; no launch id with a source is a restart of the named source;
	 * neither is the run that started the action.
	 */
	@IsTest
	private static void shouldResolveTheFourLaunchedUnderCasesInOrder()
	{
		AsyncChainExecution__c job = seedTrackedRun('NightlyJob', JOB_ROOT_ID, JOB_ROOT_ID, null, null, SEL_AsyncChainExecution.STATUS_FAILED);
		AsyncChainExecution__c child = seedTrackedRun('NightlyChild', UTIL_Random.randomUUID(), JOB_ROOT_ID, JOB_ROOT_ID, null, SEL_AsyncChainExecution.STATUS_COMPLETED);
		AsyncChainExecution__c clone = seedTrackedRun('NightlyJob', UTIL_Random.randomUUID(), JOB_ROOT_ID, null, job.Id, SEL_AsyncChainExecution.STATUS_COMPLETED);
		AsyncChainExecution__c clicked = seedTrackedRun('CheckoutReserve', UTIL_Random.randomUUID(), CLICK_ROOT_ID, CLICK_ROOT_ID, null, SEL_AsyncChainExecution.STATUS_COMPLETED);

		CTRL_ChainMonitorTypes.DTO_Request jobRequest = new CTRL_ChainMonitorTypes.DTO_Request();
		jobRequest.rootCorrelationId = JOB_ROOT_ID;
		jobRequest.sortField = 'StartedAt';
		jobRequest.sortAscending = true;
		CTRL_ChainMonitorTypes.DTO_Request clickRequest = new CTRL_ChainMonitorTypes.DTO_Request();
		clickRequest.rootCorrelationId = CLICK_ROOT_ID;

		Test.startTest();
		Map<Id, CTRL_ChainMonitorTypes.DTO_ChainSummary> jobRows = summariesById(CTRL_ChainMonitor.getChainExecutions(JSON.serialize(jobRequest)));
		Map<Id, CTRL_ChainMonitorTypes.DTO_ChainSummary> clickRows = summariesById(CTRL_ChainMonitor.getChainExecutions(JSON.serialize(clickRequest)));
		Test.stopTest();

		String jobLabel = 'NightlyJob' + CHAIN_LABEL_SEPARATOR + job.Name;
		Assert.areEqual(CTRL_ChainMonitorTypes.LaunchKind.ORIGIN.name(), jobRows.get(job.Id).launchKind, 'The job started its own action');
		Assert.isNull(jobRows.get(job.Id).launchedUnderExecutionId, 'The origin links to nothing');
		Assert.areEqual(CTRL_ChainMonitorTypes.LaunchKind.CHAIN.name(), jobRows.get(child.Id).launchKind, 'A step of the job launched the child');
		Assert.areEqual(jobLabel, jobRows.get(child.Id).launchedUnderLabel, 'The launcher is named by chain name and number');
		Assert.areEqual(job.Id, jobRows.get(child.Id).launchedUnderExecutionId, 'The launcher link selects the job');
		Assert.areEqual(JOB_ROOT_ID, jobRows.get(child.Id).launchCorrelationId, 'The raw launch id still travels');
		Assert.areEqual(CTRL_ChainMonitorTypes.LaunchKind.RESTART.name(), jobRows.get(clone.Id).launchKind, 'The clone is a restart');
		Assert.areEqual(jobLabel, jobRows.get(clone.Id).launchedUnderLabel, 'The restart names its source');
		Assert.areEqual(job.Id, jobRows.get(clone.Id).launchedUnderExecutionId, 'The restart link selects the source');
		Assert.areEqual(CTRL_ChainMonitorTypes.LaunchKind.ACTION.name(), clickRows.get(clicked.Id).launchKind, 'A launch id no run holds is the action\'s own launch');
		Assert.isNull(clickRows.get(clicked.Id).launchedUnderLabel, 'The action\'s own launch names no run');
	}

	/**
	 * @description A launcher on another page is read in one query for the page, so the column is right whichever page the
	 * launcher sits on.
	 */
	@IsTest
	private static void shouldNameALauncherThatIsNotOnThePage()
	{
		AsyncChainExecution__c job = seedTrackedRun('NightlyJob', JOB_ROOT_ID, JOB_ROOT_ID, null, null, SEL_AsyncChainExecution.STATUS_COMPLETED);
		AsyncChainExecution__c child = seedTrackedRun('NightlyChild', UTIL_Random.randomUUID(), JOB_ROOT_ID, JOB_ROOT_ID, null, SEL_AsyncChainExecution.STATUS_COMPLETED);

		CTRL_ChainMonitorTypes.DTO_Request request = new CTRL_ChainMonitorTypes.DTO_Request();
		request.rootCorrelationId = JOB_ROOT_ID;
		request.nameFilter = 'NightlyChild';
		CTRL_ChainMonitorTypes.DTO_ChainPage result = CTRL_ChainMonitor.getChainExecutions(JSON.serialize(request));

		Assert.areEqual(1, result.records.size(), 'The name filter leaves the child alone on the page');
		Assert.areEqual(child.Id, result.records[0].executionId, 'The page holds the child');
		Assert.areEqual('NightlyJob' + CHAIN_LABEL_SEPARATOR + job.Name, result.records[0].launchedUnderLabel, 'The launcher outside the page is still named');
	}

	/**
	 * @description Naming what launched a page of runs costs at most one query on top of the page itself: a scoped page whose
	 * runs all started their own action costs what the unscoped page costs, and a page that has to read a launcher or a
	 * restart source from outside itself costs that same page plus one.
	 */
	@IsTest
	private static void shouldReadTheLaunchersOfAPageInAtMostOneQuery()
	{
		AsyncChainExecution__c job = seedTrackedRun('NightlyJob', JOB_ROOT_ID, JOB_ROOT_ID, null, null, SEL_AsyncChainExecution.STATUS_COMPLETED);
		seedTrackedRun('NightlyChild', UTIL_Random.randomUUID(), JOB_ROOT_ID, JOB_ROOT_ID, null, SEL_AsyncChainExecution.STATUS_COMPLETED);
		seedTrackedRun('NightlyClone', UTIL_Random.randomUUID(), JOB_ROOT_ID, null, job.Id, SEL_AsyncChainExecution.STATUS_COMPLETED);
		String scopedOriginJson = JSON.serialize(nameFilteredRequest(JOB_ROOT_ID, 'NightlyJob'));
		String unscopedOriginJson = JSON.serialize(nameFilteredRequest(null, 'NightlyJob'));
		String scopedLauncherJson = JSON.serialize(nameFilteredRequest(JOB_ROOT_ID, 'NightlyChild'));
		String scopedSourceJson = JSON.serialize(nameFilteredRequest(JOB_ROOT_ID, 'NightlyClone'));

		Test.startTest();
		Integer beforeScopedOrigin = UTIL_Limits.soqlQueries().used();
		CTRL_ChainMonitor.getChainExecutions(scopedOriginJson);
		Integer scopedOriginCost = UTIL_Limits.soqlQueries().used() - beforeScopedOrigin;

		Integer beforeUnscopedOrigin = UTIL_Limits.soqlQueries().used();
		CTRL_ChainMonitor.getChainExecutions(unscopedOriginJson);
		Integer unscopedOriginCost = UTIL_Limits.soqlQueries().used() - beforeUnscopedOrigin;

		Integer beforeLauncher = UTIL_Limits.soqlQueries().used();
		CTRL_ChainMonitor.getChainExecutions(scopedLauncherJson);
		Integer launcherCost = UTIL_Limits.soqlQueries().used() - beforeLauncher;

		Integer beforeSource = UTIL_Limits.soqlQueries().used();
		CTRL_ChainMonitorTypes.DTO_ChainPage clonePage = CTRL_ChainMonitor.getChainExecutions(scopedSourceJson);
		Integer sourceCost = UTIL_Limits.soqlQueries().used() - beforeSource;
		Test.stopTest();

		Assert.areEqual(unscopedOriginCost, scopedOriginCost, 'A scoped page with nothing to look up costs what the unscoped page costs');
		Assert.areEqual(scopedOriginCost + 1, launcherCost, 'Reading a launcher off the page costs one query');
		Assert.areEqual(scopedOriginCost + 1, sourceCost, 'Reading a restart source off the page costs one query');
		Assert.areEqual('NightlyJob' + CHAIN_LABEL_SEPARATOR + job.Name, clonePage.records[0].launchedUnderLabel, 'The restart source outside the page is still named');
	}

	/**
	 * @description Without an action scope the list carries no launched-under answer: the column is not shown, so the unscoped
	 * list keeps its one query. The name filter matches only the seeded run, so the page holds that run alone.
	 */
	@IsTest
	private static void shouldLeaveTheLaunchedUnderColumnUnresolvedWhenUnscoped()
	{
		seedTrackedRun('NightlyChild', UTIL_Random.randomUUID(), JOB_ROOT_ID, JOB_ROOT_ID, null, SEL_AsyncChainExecution.STATUS_COMPLETED);
		CTRL_ChainMonitorTypes.DTO_Request request = new CTRL_ChainMonitorTypes.DTO_Request();
		request.nameFilter = 'NightlyChild';

		Test.startTest();
		CTRL_ChainMonitorTypes.DTO_ChainPage result = CTRL_ChainMonitor.getChainExecutions(JSON.serialize(request));
		Test.stopTest();

		Assert.areEqual(1, result.records.size(), 'The name filter leaves the seeded run alone on the page');
		Assert.isNull(result.records[0].launchKind, 'No launch kind without a scope');
		Assert.areEqual(JOB_ROOT_ID, result.records[0].launchCorrelationId, 'The raw launch id travels regardless');
	}

	/**
	 * @description The detail's Timing row reads the same four cases: the launching run's name and id, the action's own launch,
	 * the restart's source, or the run that started the action.
	 */
	@IsTest
	private static void shouldNameWhatLaunchedTheRunOnTheDetail()
	{
		AsyncChainExecution__c job = seedTrackedRun('NightlyJob', JOB_ROOT_ID, JOB_ROOT_ID, null, null, SEL_AsyncChainExecution.STATUS_FAILED);
		AsyncChainExecution__c child = seedTrackedRun('NightlyChild', UTIL_Random.randomUUID(), JOB_ROOT_ID, JOB_ROOT_ID, null, SEL_AsyncChainExecution.STATUS_COMPLETED);
		AsyncChainExecution__c clone = seedTrackedRun('NightlyJob', UTIL_Random.randomUUID(), JOB_ROOT_ID, null, job.Id, SEL_AsyncChainExecution.STATUS_COMPLETED);
		AsyncChainExecution__c clicked = seedTrackedRun('CheckoutReserve', UTIL_Random.randomUUID(), CLICK_ROOT_ID, CLICK_ROOT_ID, null, SEL_AsyncChainExecution.STATUS_COMPLETED);

		Test.startTest();
		CTRL_ChainMonitorTypes.DTO_ChainDetail jobDetail = CTRL_ChainMonitor.getChainDetail(job.Id);
		CTRL_ChainMonitorTypes.DTO_ChainDetail childDetail = CTRL_ChainMonitor.getChainDetail(child.Id);
		CTRL_ChainMonitorTypes.DTO_ChainDetail cloneDetail = CTRL_ChainMonitor.getChainDetail(clone.Id);
		CTRL_ChainMonitorTypes.DTO_ChainDetail clickedDetail = CTRL_ChainMonitor.getChainDetail(clicked.Id);
		Test.stopTest();

		Assert.areEqual(CTRL_ChainMonitorTypes.LaunchKind.ORIGIN.name(), jobDetail.launchKind, 'The job started its own action');
		Assert.areEqual(CTRL_ChainMonitorTypes.LaunchKind.CHAIN.name(), childDetail.launchKind, 'A step of the job launched the child');
		Assert.areEqual('NightlyJob' + CHAIN_LABEL_SEPARATOR + job.Name, childDetail.launchedUnderName, 'The detail names the launcher');
		Assert.areEqual(job.Id, childDetail.launchedUnderExecutionId, 'The detail links to the launcher');
		Assert.areEqual(CTRL_ChainMonitorTypes.LaunchKind.RESTART.name(), cloneDetail.launchKind, 'The clone is a restart');
		Assert.areEqual(job.Id, cloneDetail.launchedUnderExecutionId, 'The restart links to its source');
		Assert.areEqual('NightlyJob' + CHAIN_LABEL_SEPARATOR + job.Name, cloneDetail.launchedUnderName, 'The detail names the restart source read from outside the page');
		Assert.areEqual(CTRL_ChainMonitorTypes.LaunchKind.ACTION.name(), clickedDetail.launchKind, 'The click launched it');
		Assert.isNull(clickedDetail.launchedUnderName, 'The action\'s own launch names no run');
	}

	/**
	 * @description The controller returns the same managed-package namespace prefix that UTIL_System reports. The monitor
	 * builds the name of its streaming channel and its payload key from that prefix, so the two must agree.
	 */
	@IsTest
	private static void shouldExposeManagedPackageNamespacePrefixForStreaming()
	{
		String namespacePrefix = CTRL_ChainMonitor.getNamespacePrefix();

		Assert.areEqual
				(
						UTIL_System.getManagedPackageNamespacePrefix(), namespacePrefix,
						'Wrapper should expose the managed-package namespace prefix the monitor builds its streaming channel and payload key from'
				);
	}

	/**
	 * @description A terminal Completed row resolves the not-retryable and not-restartable state
	 * codes on the detail DTO: the chain-state code wins before any capability or permission
	 * consideration, so the assertion is deterministic in every org.
	 */
	@IsTest
	private static void shouldResolveTerminalStateCodesOnDetail()
	{
		AsyncChainExecution__c execution = TST_Factory.newChainExecution(
				SEL_AsyncChainExecution.STATUS_COMPLETED, TEST_CHAIN, stepLogCompleted(), 3, 3
		);

		CTRL_ChainMonitorTypes.DTO_ChainDetail detail = CTRL_ChainMonitor.getChainDetail(execution.Id);

		Assert.areEqual(UTIL_AsyncChain.REDRIVE_CHAIN_NOT_RETRYABLE, detail.retryAvailability, 'A Completed chain is not retryable, permission or not');
		Assert.areEqual(UTIL_AsyncChain.RESTART_CHAIN_NOT_RESTARTABLE, detail.restartAvailability, 'A Completed chain is not restartable, permission or not');
	}

	/**
	 * @description A Failed row whose failed step never declared isIdempotent and whose chain never
	 * declared allowRestart resolves the specific engine refusals on the detail DTO: state codes
	 * that win before the capability layer, so the assertion is deterministic in every org.
	 */
	@IsTest
	private static void shouldResolveEngineRefusalCodesOnFailedDetail()
	{
		AsyncChainExecution__c execution = TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_FAILED, TEST_CHAIN, new Map<SObjectField, Object>
		{
				AsyncChainExecution__c.StepLog__c => stepLogFailed(),
				AsyncChainExecution__c.ContextData__c => JSON.serialize(new Map<String, Object> {'seeded' => true}),
				AsyncChainExecution__c.TotalSteps__c => 3,
				AsyncChainExecution__c.CompletedSteps__c => 1
		});

		CTRL_ChainMonitorTypes.DTO_ChainDetail detail = CTRL_ChainMonitor.getChainDetail(execution.Id);

		Assert.areEqual(UTIL_AsyncChain.REDRIVE_STEP_NOT_IDEMPOTENT, detail.retryAvailability, 'An undeclared failed step refuses retry with the specific engine code');
		Assert.areEqual(UTIL_AsyncChain.RESTART_NOT_DECLARED, detail.restartAvailability, 'An undeclared chain refuses restart with the specific engine code');
	}

	/**
	 * @description The detail DTO carries the restart lineage lookup, so the monitor can offer the
	 * source-chain affordance for restarted clones.
	 */
	@IsTest
	private static void shouldPopulateSourceExecutionIdOnDetail()
	{
		AsyncChainExecution__c source = TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_FAILED, TEST_CHAIN);
		AsyncChainExecution__c clone = TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_RUNNING, TEST_CHAIN, new Map<SObjectField, Object>
		{
				AsyncChainExecution__c.SourceExecution__c => source.Id
		});

		Assert.areEqual(source.Id, CTRL_ChainMonitor.getChainDetail(clone.Id).sourceExecutionId, 'The detail must carry the restart lineage lookup');
		Assert.isNull(CTRL_ChainMonitor.getChainDetail(source.Id).sourceExecutionId, 'A chain that is not a restart clone carries no lineage lookup');
	}

	/**
	 * @description With both operator feature flags out of the active set the operations state
	 * reports the org-wide off state for the kill switch and the sweep, while chain processing
	 * itself stays enabled: the runtime switch and the capability gates are separate dials.
	 * Removing the cache entries models an admin deactivating the flag records, and makes the
	 * availability assertion deterministic in every org. A caller refused the sweep is also not
	 * told how many chains are waiting for it: the count is read through a sharing bypass, so it is
	 * gathered only for a caller the sweep is actually open to.
	 */
	@IsTest
	private static void shouldReportOperationsStateWithCapabilityFlagsInactive()
	{
		SEL_FeatureFlag.activeFlags.remove(UTIL_AsyncChain.KILL_SWITCH_TOGGLE_FEATURE_FLAG_NAME);
		SEL_FeatureFlag.activeFlags.remove(UTIL_AsyncChain.REDRIVE_FEATURE_FLAG_NAME);
		TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_STALLED, TEST_CHAIN);

		CTRL_ChainMonitorTypes.DTO_OperationsState state = CTRL_ChainMonitor.getChainOperationsState();

		Assert.isTrue(state.chainProcessingEnabled, 'Chain processing stays enabled: the capability flags gate the controls, not the chains');
		Assert.areEqual(CTRL_ChainMonitor.OPERATOR_CAPABILITY_DISABLED, state.killSwitchAvailability, 'An inactive kill-switch flag reads as the org-wide off state');
		Assert.areEqual(CTRL_ChainMonitor.OPERATOR_CAPABILITY_DISABLED, state.clearStalledAvailability, 'An inactive redrive flag reads as the org-wide off state');
		Assert.areEqual(0, state.stalledChainCount, 'A caller refused the sweep is not told how many chains are waiting for it');
	}

	/**
	 * @description The stream seed returns the chain's persisted log entries mapped to display
	 * DTOs, filtered to the chain's own correlation id: an unrelated entry never appears.
	 */
	@IsTest
	private static void shouldSeedChainLogEntriesForSelectedChain()
	{
		String correlationId = UTIL_Random.randomUUID();
		AsyncChainExecution__c execution = seedCorrelatedChain(correlationId);
		seedLogEntries(correlationId, 1);
		seedLogEntries(UTIL_Random.randomUUID(), 1);

		List<CTRL_ChainMonitorTypes.DTO_LogStreamEntry> entries = CTRL_ChainMonitor.getChainLogEntries(execution.Id);

		Assert.areEqual(1, entries.size(), 'The seed must return only the selected chain\'s entries');
		Assert.areEqual(TEST_LOG_LEVEL, entries[0].logLevel, 'The entry carries its log level');
		Assert.areEqual(TEST_LOG_MESSAGE, entries[0].message, 'The entry carries its short message');
		Assert.isNotNull(entries[0].timestamp, 'The entry carries its persisted timestamp');
	}

	/**
	 * @description The stream seed is bounded: a chain with more persisted entries than the cap
	 * returns exactly the cap, never the whole trace. This test does not check WHICH end of the
	 * trace is kept. shouldSeedTheNewestRowsOfAnOversizedTrace checks that. It can, because the
	 * seed read sorts entries with the same timestamp by Id, so the newest entries can be told apart.
	 */
	@IsTest
	private static void shouldCapChainLogEntrySeed()
	{
		String correlationId = UTIL_Random.randomUUID();
		AsyncChainExecution__c execution = seedCorrelatedChain(correlationId);
		seedLogEntries(correlationId, SEED_OVERFLOW_ROW_COUNT);

		List<CTRL_ChainMonitorTypes.DTO_LogStreamEntry> entries = CTRL_ChainMonitor.getChainLogEntries(execution.Id);

		Assert.areEqual(CTRL_ChainMonitor.LOG_STREAM_HISTORY_ROW_CAP, entries.size(), 'Expected the first load to stop at the stream history row cap, got ' + entries.size());
	}

	/**
	 * @description The stream seed degrades to an empty list for a missing or null chain, never a
	 * throw: the stream is a best-effort supplement, and its first load follows the same rule.
	 */
	@IsTest
	private static void shouldReturnEmptyChainLogEntriesForMissingChain()
	{
		Assert.isTrue(CTRL_ChainMonitor.getChainLogEntries(UTIL_Random.randomId(AsyncChainExecution__c.SObjectType)).isEmpty(),
				'A missing chain seeds an empty list, never a throw');
		Assert.isTrue(CTRL_ChainMonitor.getChainLogEntries(null).isEmpty(), 'A null id seeds an empty list, never a throw');
	}

	/**
	 * @description The seed also returns entries that reference the chain RECORD without carrying
	 * its correlation id: a chain launched from a transaction with no active log correlation still
	 * logs with its record id stamped, and those entries must seed rather than leave the stream
	 * history empty for exactly the failed runs an operator most needs to inspect.
	 */
	@IsTest
	private static void shouldSeedEntriesReferencingTheChainRecordWithoutItsCorrelation()
	{
		AsyncChainExecution__c execution = seedCorrelatedChain(UTIL_Random.randomUUID());
		TST_Builder.of(LogEntry__c.SObjectType)
				.withOverride(LogEntry__c.RecordId__c, execution.Id)
				.withOverride(LogEntry__c.LogLevel__c, TEST_LOG_LEVEL)
				.withOverride(LogEntry__c.ShortMessage__c, RECORD_REFERENCED_MESSAGE)
				.build();

		List<CTRL_ChainMonitorTypes.DTO_LogStreamEntry> entries = CTRL_ChainMonitor.getChainLogEntries(execution.Id);

		Assert.areEqual(1, entries.size(), 'A record-referencing entry with no correlation must still seed');
		Assert.areEqual(RECORD_REFERENCED_MESSAGE, entries[0].message, 'The seeded entry is the record-referencing one');
	}

	/**
	 * @description An oversized trace seeds its NEWEST rows: with more entries than the trace
	 * read's own row cap and the newest block distinctly marked, only marked entries may return.
	 * Rows saved in one transaction share one timestamp. So the seed read sorts them by Id as well,
	 * and that Id order decides which rows are the newest.
	 */
	@IsTest
	private static void shouldSeedTheNewestRowsOfAnOversizedTrace()
	{
		String correlationId = UTIL_Random.randomUUID();
		AsyncChainExecution__c execution = seedCorrelatedChain(correlationId);
		seedLogEntries(correlationId, SEL_LogEntry.CORRELATION_TRACE_ROW_CAP + 2 - CTRL_ChainMonitor.LOG_STREAM_HISTORY_ROW_CAP, TEST_LOG_MESSAGE);
		seedLogEntries(correlationId, CTRL_ChainMonitor.LOG_STREAM_HISTORY_ROW_CAP, NEWEST_WINDOW_MESSAGE);

		List<CTRL_ChainMonitorTypes.DTO_LogStreamEntry> entries = CTRL_ChainMonitor.getChainLogEntries(execution.Id);

		Assert.areEqual(CTRL_ChainMonitor.LOG_STREAM_HISTORY_ROW_CAP, entries.size(), 'Expected the first load to stop at the stream history row cap, got ' + entries.size());
		for(CTRL_ChainMonitorTypes.DTO_LogStreamEntry entry : entries)
		{
			Assert.areEqual(NEWEST_WINDOW_MESSAGE, entry.message, 'Every seeded entry comes from the newest block of the oversized trace');
		}
	}

	/**
	 * @description Seeds one run with the tracking fields the launched-under cases are decided from.
	 *
	 * @param chainName The chain name.
	 * @param correlationId The run's own tracking id.
	 * @param rootCorrelationId The action's id.
	 * @param launchCorrelationId The id the run was launched under, or null.
	 * @param sourceExecutionId The run this one was restarted from, or null.
	 * @param status The run's status.
	 *
	 * @return The inserted run with its chain number populated.
	 */
	@SuppressWarnings('PMD.ExcessiveParameterList')
	private static AsyncChainExecution__c seedTrackedRun
			(
					String chainName,
					String correlationId,
					String rootCorrelationId,
					String launchCorrelationId,
					Id sourceExecutionId,
					String status
			)
	{
		AsyncChainExecution__c run = TST_Factory.newChainExecution(status, chainName, new Map<SObjectField, Object>
		{
				AsyncChainExecution__c.CorrelationId__c => correlationId,
				AsyncChainExecution__c.RootCorrelationId__c => rootCorrelationId,
				AsyncChainExecution__c.LaunchCorrelationId__c => launchCorrelationId,
				AsyncChainExecution__c.SourceExecution__c => sourceExecutionId,
				AsyncChainExecution__c.StartedAt__c => Datetime.now().addMinutes(-10)
		});
		return new SEL_AsyncChainExecution().findByIdsForSummary(new Set<Id> {run.Id})[0];
	}

	/**
	 * @description A list request limited to one action (or to none) and to one chain name. The tests that count queries use
	 * it to keep a page to a single known run.
	 *
	 * @param rootCorrelationId The action to keep the list to, or null for the unscoped list.
	 * @param nameFilter The chain name the page is limited to.
	 *
	 * @return The request.
	 */
	private static CTRL_ChainMonitorTypes.DTO_Request nameFilteredRequest(String rootCorrelationId, String nameFilter)
	{
		CTRL_ChainMonitorTypes.DTO_Request request = new CTRL_ChainMonitorTypes.DTO_Request();
		request.rootCorrelationId = rootCorrelationId;
		request.nameFilter = nameFilter;
		return request;
	}

	/**
	 * @description The summaries of a page keyed by run id, so a test asserts by run rather than by position.
	 *
	 * @param page The list page.
	 *
	 * @return The summaries by run id.
	 */
	private static Map<Id, CTRL_ChainMonitorTypes.DTO_ChainSummary> summariesById(CTRL_ChainMonitorTypes.DTO_ChainPage page)
	{
		Map<Id, CTRL_ChainMonitorTypes.DTO_ChainSummary> byId = new Map<Id, CTRL_ChainMonitorTypes.DTO_ChainSummary>();
		for(CTRL_ChainMonitorTypes.DTO_ChainSummary summary : page.records)
		{
			byId.put(summary.executionId, summary);
		}
		return byId;
	}
}