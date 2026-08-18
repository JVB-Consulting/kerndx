// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Tests for CTRL_ChainMonitor.
 *
 * @see CTRL_ChainMonitor
 *
 * @author Jason van Beukering
 *
 * @group Controllers
 *
 * @date April 2026, August 2026
 */
@IsTest(SeeAllData=false IsParallel=true)
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
private class CTRL_ChainMonitor_TEST
{
	/**
	 * @description Test chain name.
	 */
	private static final String TEST_CHAIN = 'TestChain';

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
	private static final String RECORD_REFERENCED_MESSAGE = 'Record-referenced chain log entry';
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
	 * @description Sample step log for a running chain (partial execution), including the onError
	 * and onComplete handler entries the framework persists after the step entries — the timeline
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

	@IsTest
	private static void shouldReturnFilteredExecutionsByStatus()
	{
		TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_RUNNING, TEST_CHAIN);
		TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_COMPLETED, 'OtherChain');
		TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_FAILED, TEST_CHAIN);

		CTRL_ChainMonitorTypes.DTO_Request request = new CTRL_ChainMonitorTypes.DTO_Request();
		request.statusFilters = new List<String> {SEL_AsyncChainExecution.STATUS_RUNNING, SEL_AsyncChainExecution.STATUS_FAILED};
		CTRL_ChainMonitorTypes.DTO_ChainPage result = CTRL_ChainMonitor.getChainExecutions(JSON.serialize(request));

		Assert.areEqual(2, result.records.size(), 'Should return only Running and Failed chains');
		Assert.areEqual(2, result.totalCount, 'Total count should match filtered results');
	}

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

	@IsTest
	private static void shouldIdentifyRunningStepInTimeline()
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

	@IsTest
	private static void shouldShowFirstStepAsRunningWhenNoStepsCompleted()
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

		Assert.areEqual(CTRL_ChainMonitor.STEP_STATUS_SUCCESS, steps[0].stepStatus, 'Completed step should be success');
		Assert.areEqual(CTRL_ChainMonitor.STEP_STATUS_PENDING, steps[1].stepStatus, 'Unexecuted step should be pending');
		Assert.areEqual(CTRL_ChainMonitor.STEP_STATUS_PENDING, steps[2].stepStatus, 'Future step should be pending');
		Assert.areEqual(CTRL_ChainMonitor.STEP_STATUS_PENDING, steps[2].stepStatus, 'Pending step should have pending status');
	}

	@IsTest
	private static void shouldReturnEmptyForNonexistentExecution()
	{
		CTRL_ChainMonitorTypes.DTO_ChainDetail detail = CTRL_ChainMonitor.getChainDetail(null);
		Assert.isNull(detail, 'Should return null for null ID');

		List<CTRL_ChainMonitorTypes.DTO_StepDetail> steps = CTRL_ChainMonitor.getStepTimeline(null);
		Assert.isTrue(steps.isEmpty(), 'Should return empty list for null ID');
	}

	@IsTest
	private static void shouldReturnEmptyForNoMatchingFilters()
	{
		TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_COMPLETED, TEST_CHAIN);

		CTRL_ChainMonitorTypes.DTO_Request request = new CTRL_ChainMonitorTypes.DTO_Request();
		request.statusFilters = new List<String> {SEL_AsyncChainExecution.STATUS_RUNNING};
		CTRL_ChainMonitorTypes.DTO_ChainPage result = CTRL_ChainMonitor.getChainExecutions(JSON.serialize(request));

		Assert.isTrue(result.records.isEmpty(), 'Should return empty list when no chains match');
	}

	@IsTest
	private static void shouldHandleNullFilters()
	{
		TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_COMPLETED, TEST_CHAIN);

		CTRL_ChainMonitorTypes.DTO_ChainPage result = CTRL_ChainMonitor.getChainExecutions(null);

		Assert.areEqual(1, result.records.size(), 'Should return all records when no filters applied');
	}

	@IsTest
	private static void shouldHandleBlankStepLog()
	{
		AsyncChainExecution__c execution = TST_Factory.newChainExecution(
				SEL_AsyncChainExecution.STATUS_COMPLETED, TEST_CHAIN, null, 0, 0
		);

		CTRL_ChainMonitorTypes.DTO_ChainDetail detail = CTRL_ChainMonitor.getChainDetail(execution.Id);
		Assert.isTrue(detail.steps.isEmpty(), 'Steps should be empty when StepLog is blank');
	}

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
	 * so the ended row reports no duration rather than a running total.
	 */
	@IsTest
	private static void shouldReportNoElapsedTimeOnAStalledRowThatAlreadyEnded()
	{
		TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_STALLED, TEST_CHAIN,
				new Map<SObjectField, Object>
				{
						AsyncChainExecution__c.StartedAt__c => Datetime.now().addMinutes(-ELAPSED_MINUTES),
						AsyncChainExecution__c.CompletedAt__c => Datetime.now()
				});

		CTRL_ChainMonitorTypes.DTO_ChainPage result = CTRL_ChainMonitor.getChainExecutions(null);

		Assert.isNull(result.records[0].durationMs, 'A row carrying a completion instant must not report a still-running elapsed time');
		Assert.isNull(result.records[0].durationLabel, 'A row carrying a completion instant must not report an elapsed label');
	}

	/**
	 * @description A finished run that recorded no duration reports none: the elapsed fallback is
	 * scoped to runs that have not finished, so a completed row never gains an invented number.
	 */
	@IsTest
	private static void shouldReportNoElapsedTimeOnAFinishedListRow()
	{
		TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_COMPLETED, TEST_CHAIN,
				new Map<SObjectField, Object> {AsyncChainExecution__c.StartedAt__c => Datetime.now().addMinutes(-ELAPSED_MINUTES)});

		CTRL_ChainMonitorTypes.DTO_ChainPage result = CTRL_ChainMonitor.getChainExecutions(null);

		Assert.isNull(result.records[0].durationMs, 'A completed row without a recorded duration must report none');
	}

	/**
	 * @description The clear-stalled dialog states how many chains are waiting before the operator
	 * commits, so the count travels with the operations state the header already loads. Only rows
	 * the sweep would take are counted: a stalled row carrying a completion instant is a finished
	 * run the sweep skips. The count is gathered only for a caller the sweep is open to, and the
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
		TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_STALLED, TEST_CHAIN,
				new Map<SObjectField, Object> {AsyncChainExecution__c.CompletedAt__c => Datetime.now()});
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

	@IsTest
	private static void shouldFindChainExecutionIdByCorrelation()
	{
		String correlationId = UTIL_Random.randomUUID();
		AsyncChainExecution__c execution = seedCorrelatedChain(correlationId);
		TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_COMPLETED, 'OtherChain');

		Id resolvedId = CTRL_ChainMonitor.findChainExecutionIdByCorrelation(correlationId);

		Assert.areEqual(execution.Id, resolvedId, 'Should resolve the chain execution that carries the correlation id');
	}

	@IsTest
	private static void shouldReturnNullForUnknownCorrelation()
	{
		TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_RUNNING, TEST_CHAIN);

		Id resolvedId = CTRL_ChainMonitor.findChainExecutionIdByCorrelation(UTIL_Random.randomUUID());

		Assert.isNull(resolvedId, 'Should return null when no chain carries the correlation id');
	}

	@IsTest
	private static void shouldReturnNullForBlankCorrelation()
	{
		Assert.isNull(CTRL_ChainMonitor.findChainExecutionIdByCorrelation(null), 'Should return null for a null correlation id');
		Assert.isNull(CTRL_ChainMonitor.findChainExecutionIdByCorrelation(''), 'Should return null for an empty correlation id');
	}

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
	 * declared allowRestart resolves the specific engine refusals on the detail DTO — state codes
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
	 * returns exactly the cap, never the whole trace. WHICH end of the trace survives the slice is
	 * pinned by shouldSeedTheNewestRowsOfAnOversizedTrace: the seed read's Id tiebreak makes
	 * same-timestamp newest-ness witnessable, closing the gap this cap witness once disclosed.
	 */
	@IsTest
	private static void shouldCapChainLogEntrySeed()
	{
		String correlationId = UTIL_Random.randomUUID();
		AsyncChainExecution__c execution = seedCorrelatedChain(correlationId);
		seedLogEntries(correlationId, SEED_OVERFLOW_ROW_COUNT);

		List<CTRL_ChainMonitorTypes.DTO_LogStreamEntry> entries = CTRL_ChainMonitor.getChainLogEntries(execution.Id);

		Assert.areEqual(CTRL_ChainMonitor.LOG_STREAM_SEED_ROW_CAP, entries.size(), 'The seed must cap at the stream seed row cap');
	}

	/**
	 * @description The stream seed degrades to an empty list for a missing or null chain — never a
	 * throw: the stream is a best-effort supplement, and its seed follows the same posture.
	 */
	@IsTest
	private static void shouldReturnEmptyChainLogEntriesForMissingChain()
	{
		Assert.isTrue(CTRL_ChainMonitor.getChainLogEntries(UTIL_Random.randomId(AsyncChainExecution__c.SObjectType)).isEmpty(), 'A missing chain seeds an empty list, never a throw');
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
	 * Same-transaction rows share one timestamp, so newest-ness is pinned by the seed read's Id
	 * tiebreak — the witness the bounded-cap test above could not build before that tiebreak.
	 */
	@IsTest
	private static void shouldSeedTheNewestRowsOfAnOversizedTrace()
	{
		String correlationId = UTIL_Random.randomUUID();
		AsyncChainExecution__c execution = seedCorrelatedChain(correlationId);
		seedLogEntries(correlationId, SEL_LogEntry.CORRELATION_TRACE_ROW_CAP + 2 - CTRL_ChainMonitor.LOG_STREAM_SEED_ROW_CAP, TEST_LOG_MESSAGE);
		seedLogEntries(correlationId, CTRL_ChainMonitor.LOG_STREAM_SEED_ROW_CAP, NEWEST_WINDOW_MESSAGE);

		List<CTRL_ChainMonitorTypes.DTO_LogStreamEntry> entries = CTRL_ChainMonitor.getChainLogEntries(execution.Id);

		Assert.areEqual(CTRL_ChainMonitor.LOG_STREAM_SEED_ROW_CAP, entries.size(), 'The seed caps at the stream seed row cap');
		for(CTRL_ChainMonitorTypes.DTO_LogStreamEntry entry : entries)
		{
			Assert.areEqual(NEWEST_WINDOW_MESSAGE, entry.message, 'Every seeded entry comes from the newest block of the oversized trace');
		}
	}

}