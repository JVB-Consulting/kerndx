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
 * @date April 2026, July 2026
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
	 * @description Sample step log for a running chain (partial execution).
	 *
	 * @return Serialized step log JSON.
	 */
	private static String stepLogRunning()
	{
		UTIL_AsyncChain.DTO_StepDefinition completedStep = buildStep('Step1', 'First Step', true, 400);
		UTIL_AsyncChain.DTO_StepDefinition pendingStep = buildStep('Step2', 'Second Step', null, null);

		UTIL_AsyncChain.DTO_StepDefinition handlerStep = new UTIL_AsyncChain.DTO_StepDefinition();
		handlerStep.className = 'CompletionHandler';
		handlerStep.isCompletionHandler = true;

		return buildStepLog(new List<UTIL_AsyncChain.DTO_StepDefinition> {completedStep, pendingStep, handlerStep});
	}

	@IsTest
	private static void shouldReturnFilteredExecutionsByStatus()
	{
		TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_RUNNING, TEST_CHAIN);
		TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_COMPLETED, 'OtherChain');
		TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_FAILED, TEST_CHAIN);

		CTRL_ChainMonitor.DTO_Request request = new CTRL_ChainMonitor.DTO_Request();
		request.statusFilters = new List<String> {SEL_AsyncChainExecution.STATUS_RUNNING, SEL_AsyncChainExecution.STATUS_FAILED};
		CTRL_ChainMonitor.DTO_ChainPage result = CTRL_ChainMonitor.getChainExecutions(JSON.serialize(request));

		Assert.areEqual(2, result.records.size(), 'Should return only Running and Failed chains');
		Assert.areEqual(2, result.totalCount, 'Total count should match filtered results');
	}

	@IsTest
	private static void shouldReturnFilteredExecutionsByName()
	{
		TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_COMPLETED, 'AccountOnboarding');
		TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_COMPLETED, 'DataSync');
		TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_COMPLETED, 'AccountCleanup');

		CTRL_ChainMonitor.DTO_Request request = new CTRL_ChainMonitor.DTO_Request();
		request.nameFilter = 'Account';
		CTRL_ChainMonitor.DTO_ChainPage result = CTRL_ChainMonitor.getChainExecutions(JSON.serialize(request));

		Assert.areEqual(2, result.records.size(), 'Should return chains matching name filter');
	}

	@IsTest
	private static void shouldReturnPaginatedResults()
	{
		for(Integer index = 0; index < 5; index++)
		{
			TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_COMPLETED, 'Chain' + index);
		}

		CTRL_ChainMonitor.DTO_Request request = new CTRL_ChainMonitor.DTO_Request();
		request.pageSize = 2;
		request.pageNumber = 1;
		CTRL_ChainMonitor.DTO_ChainPage result = CTRL_ChainMonitor.getChainExecutions(JSON.serialize(request));

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

		CTRL_ChainMonitor.DTO_Request request = new CTRL_ChainMonitor.DTO_Request();
		request.sortField = 'ChainName';
		request.sortAscending = true;
		CTRL_ChainMonitor.DTO_ChainPage result = CTRL_ChainMonitor.getChainExecutions(JSON.serialize(request));

		List<CTRL_ChainMonitor.DTO_ChainSummary> records = result.records;
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

		CTRL_ChainMonitor.DTO_ChainDetail detail = CTRL_ChainMonitor.getChainDetail(execution.Id);

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

		CTRL_ChainMonitor.DTO_ChainDetail detail = CTRL_ChainMonitor.getChainDetail(execution.Id);

		Assert.areEqual(3, detail.steps.size(), 'Should have 3 parsed steps');

		CTRL_ChainMonitor.DTO_StepDetail successStep = detail.steps[0];
		Assert.areEqual(CTRL_ChainMonitor.STEP_STATUS_SUCCESS, successStep.stepStatus, 'First step should be success');

		CTRL_ChainMonitor.DTO_StepDetail warnStep = detail.steps[1];
		Assert.areEqual(CTRL_ChainMonitor.STEP_STATUS_WARNING, warnStep.stepStatus, 'ContinueOnError step should be warning');
		Assert.areEqual('Non-fatal: skipped', warnStep.errorMessage, 'Should have error message');

		CTRL_ChainMonitor.DTO_StepDetail failedStep = detail.steps[2];
		Assert.areEqual(CTRL_ChainMonitor.STEP_STATUS_FAILED, failedStep.stepStatus, 'Failed step should be error');
		Assert.areEqual('Required field missing', failedStep.errorMessage, 'Should have error message');
	}

	@IsTest
	private static void shouldIdentifyRunningStepInTimeline()
	{
		AsyncChainExecution__c execution = TST_Factory.newChainExecution(
				SEL_AsyncChainExecution.STATUS_RUNNING, TEST_CHAIN, stepLogRunning(), 3, 1
		);

		List<CTRL_ChainMonitor.DTO_StepDetail> steps = CTRL_ChainMonitor.getStepTimeline(execution.Id);

		Assert.areEqual(3, steps.size(), 'Should have 3 steps');
		Assert.areEqual(CTRL_ChainMonitor.STEP_STATUS_SUCCESS, steps[0].stepStatus, 'Completed step should be success');
		Assert.areEqual(CTRL_ChainMonitor.STEP_STATUS_PENDING, steps[1].stepStatus, 'Unexecuted step should be pending');
		Assert.areEqual(CTRL_ChainMonitor.STEP_STATUS_PENDING, steps[2].stepStatus, 'Unexecuted step should be pending');
	}

	@IsTest
	private static void shouldReturnStepTimelineForRecordPage()
	{
		AsyncChainExecution__c execution = TST_Factory.newChainExecution(
				SEL_AsyncChainExecution.STATUS_COMPLETED, TEST_CHAIN, stepLogCompleted(), 3, 3
		);

		List<CTRL_ChainMonitor.DTO_StepDetail> steps = CTRL_ChainMonitor.getStepTimeline(execution.Id);

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

		List<CTRL_ChainMonitor.DTO_StepDetail> steps = CTRL_ChainMonitor.getStepTimeline(execution.Id);

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

		List<CTRL_ChainMonitor.DTO_StepDetail> steps = CTRL_ChainMonitor.getStepTimeline(execution.Id);

		Assert.areEqual(CTRL_ChainMonitor.STEP_STATUS_SUCCESS, steps[0].stepStatus, 'Completed step should be success');
		Assert.areEqual(CTRL_ChainMonitor.STEP_STATUS_PENDING, steps[1].stepStatus, 'Unexecuted step should be pending');
		Assert.areEqual(CTRL_ChainMonitor.STEP_STATUS_PENDING, steps[2].stepStatus, 'Future step should be pending');
		Assert.areEqual(CTRL_ChainMonitor.STEP_STATUS_PENDING, steps[2].stepStatus, 'Pending step should have pending status');
	}

	@IsTest
	private static void shouldReturnEmptyForNonexistentExecution()
	{
		CTRL_ChainMonitor.DTO_ChainDetail detail = CTRL_ChainMonitor.getChainDetail(null);
		Assert.isNull(detail, 'Should return null for null ID');

		List<CTRL_ChainMonitor.DTO_StepDetail> steps = CTRL_ChainMonitor.getStepTimeline(null);
		Assert.isTrue(steps.isEmpty(), 'Should return empty list for null ID');
	}

	@IsTest
	private static void shouldReturnEmptyForNoMatchingFilters()
	{
		TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_COMPLETED, TEST_CHAIN);

		CTRL_ChainMonitor.DTO_Request request = new CTRL_ChainMonitor.DTO_Request();
		request.statusFilters = new List<String> {SEL_AsyncChainExecution.STATUS_RUNNING};
		CTRL_ChainMonitor.DTO_ChainPage result = CTRL_ChainMonitor.getChainExecutions(JSON.serialize(request));

		Assert.isTrue(result.records.isEmpty(), 'Should return empty list when no chains match');
	}

	@IsTest
	private static void shouldHandleNullFilters()
	{
		TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_COMPLETED, TEST_CHAIN);

		CTRL_ChainMonitor.DTO_ChainPage result = CTRL_ChainMonitor.getChainExecutions(null);

		Assert.areEqual(1, result.records.size(), 'Should return all records when no filters applied');
	}

	@IsTest
	private static void shouldHandleBlankStepLog()
	{
		AsyncChainExecution__c execution = TST_Factory.newChainExecution(
				SEL_AsyncChainExecution.STATUS_COMPLETED, TEST_CHAIN, null, 0, 0
		);

		CTRL_ChainMonitor.DTO_ChainDetail detail = CTRL_ChainMonitor.getChainDetail(execution.Id);
		Assert.isTrue(detail.steps.isEmpty(), 'Steps should be empty when StepLog is blank');
	}

	@IsTest
	private static void shouldComputeDurationForRunningChain()
	{
		AsyncChainExecution__c execution = TST_Factory.newChainExecution(
				SEL_AsyncChainExecution.STATUS_RUNNING, TEST_CHAIN, null, 2, 0
		);

		CTRL_ChainMonitor.DTO_ChainDetail detail = CTRL_ChainMonitor.getChainDetail(execution.Id);

		Assert.isNotNull(detail.durationMs, 'Duration should be computed for running chain');
		Assert.isTrue(detail.durationMs > 0, 'Duration should be positive for running chain');
		Assert.isNotNull(detail.durationLabel, 'Duration label should be set');
	}

	@IsTest
	private static void shouldPopulateSummaryDtoFields()
	{
		AsyncChainExecution__c execution = TST_Factory.newChainExecution(SEL_AsyncChainExecution.STATUS_COMPLETED, TEST_CHAIN);
		execution.DurationMs__c = 45000;
		DML_Builder.newTransaction().withSystemMode().doUpdate(execution).execute();

		CTRL_ChainMonitor.DTO_ChainPage result = CTRL_ChainMonitor.getChainExecutions(null);

		CTRL_ChainMonitor.DTO_ChainSummary summary = result.records[0];
		Assert.isNotNull(summary.executionId, 'Execution ID should be set');
		Assert.areEqual(TEST_CHAIN, summary.chainName, 'Chain name should match');
		Assert.areEqual(SEL_AsyncChainExecution.STATUS_COMPLETED, summary.status, 'Status should match');
		Assert.areEqual(45000, summary.durationMs, 'Duration should match');
		Assert.areEqual('45s', summary.durationLabel, 'Duration label should be formatted');
	}

	@IsTest
	private static void shouldFindChainExecutionIdByCorrelation()
	{
		String correlationId = UTIL_Random.randomUUID();
		AsyncChainExecution__c execution = (AsyncChainExecution__c)TST_Builder.of(AsyncChainExecution__c.SObjectType)
				.withOverride(AsyncChainExecution__c.ChainName__c, TEST_CHAIN)
				.withOverride(AsyncChainExecution__c.Status__c, SEL_AsyncChainExecution.STATUS_RUNNING)
				.withOverride(AsyncChainExecution__c.CorrelationId__c, correlationId)
				.build();
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

}