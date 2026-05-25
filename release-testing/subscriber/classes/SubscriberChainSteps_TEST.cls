// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Tests for SubscriberChainSteps — exercises async chain orchestration
 * from subscriber context with real DML, API callouts, and context manipulation.
 *
 * @see SubscriberChainSteps
 *
 * @author your.name@company.com
 *
 * @group Async
 *
 * @date April 2026, May 2026
 */
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest(SeeAllData=false)
private class SubscriberChainSteps_TEST
{
	/** @description Chain name used across tests. */
	private static final String CHAIN_NAME = 'SubscriberTest';

	/**
	 * @description Verifies that a single-step chain creates a Foobar and completes.
	 */
	@IsTest
	private static void shouldCompleteSingleStepChain()
	{
		Test.startTest();
		String executionId = kern.UTIL_AsyncChain.newChain(CHAIN_NAME)
				.then(new SubscriberChainSteps.CreateFoobarStep())
				.execute();
		Test.stopTest();

		kern__AsyncChainExecution__c execution = queryExecution(executionId);
		Assert.areEqual('Completed', execution.kern__Status__c, 'Chain should complete');
		Assert.areEqual(1, execution.kern__CompletedSteps__c, 'Should complete 1 step');

		Map<String, Object> contextData = parseContext(execution);
		Assert.isNotNull(contextData.get(SubscriberChainSteps.KEY_FOOBAR_ID), 'Foobar ID should be in context');

		Id foobarId = (Id)contextData.get(SubscriberChainSteps.KEY_FOOBAR_ID);
		List<kern__Foobar__c> foobars = [SELECT Id FROM kern__Foobar__c WHERE Id = :foobarId];
		Assert.areEqual(1, foobars.size(), 'Foobar record should exist');
	}

	/**
	 * @description Verifies that a multi-step chain passes context between steps and updates the record.
	 */
	@IsTest
	private static void shouldPassContextAcrossSteps()
	{
		Test.startTest();
		String executionId = kern.UTIL_AsyncChain.newChain(CHAIN_NAME)
				.then(new SubscriberChainSteps.CreateFoobarStep())
				.then(new SubscriberChainSteps.UpdateFoobarStep())
				.execute();
		Test.stopTest();

		kern__AsyncChainExecution__c execution = queryExecution(executionId);
		Assert.areEqual('Completed', execution.kern__Status__c, 'Chain should complete');
		Assert.areEqual(2, execution.kern__CompletedSteps__c, 'Should complete 2 steps');

		Map<String, Object> contextData = parseContext(execution);
		Id foobarId = (Id)contextData.get(SubscriberChainSteps.KEY_FOOBAR_ID);
		kern__Foobar__c record = [SELECT Name FROM kern__Foobar__c WHERE Id = :foobarId];
		Assert.isTrue(record.Name.contains('Updated'), 'Foobar should be updated by second step');
	}

	/**
	 * @description Verifies that a chain with a failing step is marked as Failed with an error message.
	 */
	@IsTest
	private static void shouldFailChainOnStepFailure()
	{
		Test.startTest();
		String executionId = kern.UTIL_AsyncChain.newChain(CHAIN_NAME)
				.then(new SubscriberChainSteps.FailingStep())
				.execute();
		Test.stopTest();

		kern__AsyncChainExecution__c execution = queryExecution(executionId);
		Assert.areEqual('Failed', execution.kern__Status__c, 'Chain should be Failed');
		Assert.isTrue(execution.kern__ErrorMessage__c.contains('Deliberate subscriber failure'), 'Error message should match');
	}

	/**
	 * @description Verifies that the onError handler executes when a step fails.
	 */
	@IsTest
	private static void shouldInvokeErrorHandler()
	{
		Test.startTest();
		String executionId = kern.UTIL_AsyncChain.newChain(CHAIN_NAME)
				.then(new SubscriberChainSteps.FailingStep())
				.onError(new SubscriberChainSteps.ErrorHandlerStep())
				.execute();
		Test.stopTest();

		kern__AsyncChainExecution__c execution = queryExecution(executionId);
		Assert.areEqual('Failed', execution.kern__Status__c, 'Chain should still be Failed');
		Map<String, Object> contextData = parseContext(execution);
		Assert.isTrue((Boolean)contextData.get(SubscriberChainSteps.KEY_ERROR_HANDLED), 'Error handler should have executed');
	}

	/**
	 * @description Verifies that the onComplete handler executes after all steps succeed.
	 */
	@IsTest
	private static void shouldInvokeCompletionHandler()
	{
		Test.startTest();
		String executionId = kern.UTIL_AsyncChain.newChain(CHAIN_NAME)
				.then(new SubscriberChainSteps.CreateFoobarStep())
				.onComplete(new SubscriberChainSteps.CompletionHandlerStep())
				.execute();
		Test.stopTest();

		kern__AsyncChainExecution__c execution = queryExecution(executionId);
		Assert.areEqual('Completed', execution.kern__Status__c, 'Chain should complete');
		Map<String, Object> contextData = parseContext(execution);
		Assert.isTrue((Boolean)contextData.get(SubscriberChainSteps.KEY_COMPLETED), 'Completion handler should have executed');
	}

	/**
	 * @description Verifies that getStatus returns a map with all expected keys.
	 */
	@IsTest
	private static void shouldReturnStatusMap()
	{
		Test.startTest();
		String executionId = kern.UTIL_AsyncChain.newChain(CHAIN_NAME)
				.then(new SubscriberChainSteps.CreateFoobarStep())
				.execute();
		Test.stopTest();

		Map<String, Object> status = kern.UTIL_AsyncChain.getStatus(executionId);
		Assert.isNotNull(status, 'Status map should not be null');
		Assert.areEqual(executionId, status.get('executionId'), 'executionId should match');
		Assert.areEqual(CHAIN_NAME, status.get('chainName'), 'chainName should match');
		Assert.areEqual('Completed', status.get('status'), 'status should be Completed');
		Assert.isTrue(status.containsKey('totalSteps'), 'Should contain totalSteps');
		Assert.isTrue(status.containsKey('completedSteps'), 'Should contain completedSteps');
	}

	/**
	 * @description Verifies that then(step, true) allows the chain to continue past a failing step.
	 */
	@IsTest
	private static void shouldContinueOnErrorViaBuilderOverload()
	{
		Test.startTest();
		String executionId = kern.UTIL_AsyncChain.newChain(CHAIN_NAME)
				.then(new SubscriberChainSteps.OptionalFailingStep(), true)
				.then(new SubscriberChainSteps.CreateFoobarStep())
				.execute();
		Test.stopTest();

		kern__AsyncChainExecution__c execution = queryExecution(executionId);
		Assert.areEqual('Completed', execution.kern__Status__c, 'Chain should complete despite step failure');
		Assert.areEqual(1, execution.kern__CompletedSteps__c, 'Only the successful step should be counted');
		Assert.isTrue(execution.kern__ErrorMessage__c.contains('Non-fatal'), 'Should contain non-fatal failure summary');

		Map<String, Object> contextData = parseContext(execution);
		Assert.isNotNull(contextData.get(SubscriberChainSteps.KEY_FOOBAR_ID), 'Second step should have created Foobar');
	}

	/**
	 * @description Verifies that DurationMs is populated when a chain completes.
	 */
	@IsTest
	private static void shouldSetDurationOnCompletion()
	{
		Test.startTest();
		String executionId = kern.UTIL_AsyncChain.newChain(CHAIN_NAME)
				.then(new SubscriberChainSteps.CreateFoobarStep())
				.execute();
		Test.stopTest();

		kern__AsyncChainExecution__c execution = queryExecution(executionId);
		Assert.areEqual('Completed', execution.kern__Status__c, 'Chain should complete');
		Assert.isNotNull(execution.kern__DurationMs__c, 'DurationMs should be set');
		Assert.isTrue(execution.kern__DurationMs__c >= 0, 'DurationMs should be non-negative');
	}

	/**
	 * @description Verifies that multiple continueOnError failures accumulate in ErrorMessage.
	 */
	@IsTest
	private static void shouldAccumulateMultipleContinuedFailures()
	{
		Test.startTest();
		String executionId = kern.UTIL_AsyncChain.newChain(CHAIN_NAME)
				.then(new SubscriberChainSteps.OptionalFailingStep(), true)
				.then(new SubscriberChainSteps.PureInterfaceFailingStep(), true)
				.then(new SubscriberChainSteps.CreateFoobarStep())
				.execute();
		Test.stopTest();

		kern__AsyncChainExecution__c execution = queryExecution(executionId);
		Assert.areEqual('Completed', execution.kern__Status__c, 'Chain should complete');
		Assert.areEqual(1, execution.kern__CompletedSteps__c, 'Only the successful step should be counted');
		Assert.isTrue(execution.kern__ErrorMessage__c.contains('; '), 'Should concatenate multiple failures');
		Assert.isNotNull(execution.kern__DurationMs__c, 'DurationMs should be set');
	}

	/**
	 * @description Verifies that a pure IF_Chain.Step implementation works with the chain.
	 */
	@IsTest
	private static void shouldExecutePureInterfaceStep()
	{
		Test.startTest();
		String executionId = kern.UTIL_AsyncChain.newChain(CHAIN_NAME)
				.then(new SubscriberChainSteps.PureInterfaceStep())
				.execute();
		Test.stopTest();

		kern__AsyncChainExecution__c execution = queryExecution(executionId);
		Assert.areEqual('Completed', execution.kern__Status__c, 'Pure interface step should complete');
		Map<String, Object> contextData = parseContext(execution);
		Assert.isTrue((Boolean)contextData.get('pureInterfaceExecuted'), 'Pure interface step should have run');
	}

	/**
	 * @description Verifies that then(step, true) works with a pure IF_Chain.Step implementation.
	 */
	@IsTest
	private static void shouldContinueOnErrorWithPureInterfaceStep()
	{
		Test.startTest();
		String executionId = kern.UTIL_AsyncChain.newChain(CHAIN_NAME)
				.then(new SubscriberChainSteps.PureInterfaceFailingStep(), true)
				.then(new SubscriberChainSteps.PureInterfaceStep())
				.execute();
		Test.stopTest();

		kern__AsyncChainExecution__c execution = queryExecution(executionId);
		Assert.areEqual('Completed', execution.kern__Status__c, 'Chain should continue past pure interface failure');
		Assert.areEqual(1, execution.kern__CompletedSteps__c, 'Only succeeded step counts (continueOnError failure excluded)');
		Map<String, Object> contextData = parseContext(execution);
		Assert.isTrue((Boolean)contextData.get('pureInterfaceExecuted'), 'Second step should have run');
	}

	/**
	 * @description Verifies a full chain with DML + API callout + context flow across 3 steps.
	 */
	@IsTest
	private static void shouldExecuteFullChainWithApiCallout()
	{
		kern.API_MockFactory.forService('kern.API_PostExample')
				.body('{"body":"test","id":101,"title":"ChainTest","userId":9}')
				.statusCode(201)
				.register();

		Test.startTest();
		String executionId = kern.UTIL_AsyncChain.newChain(CHAIN_NAME)
				.then(new SubscriberChainSteps.CreateFoobarStep())
				.then(new SubscriberChainSteps.CallApiStep())
				.then(new SubscriberChainSteps.UpdateFoobarStep())
				.execute();
		Test.stopTest();

		kern__AsyncChainExecution__c execution = queryExecution(executionId);
		Assert.areEqual('Completed', execution.kern__Status__c, 'Full chain should complete');
		Assert.areEqual(3, execution.kern__CompletedSteps__c, 'All 3 steps should complete');

		Map<String, Object> contextData = parseContext(execution);
		Assert.areEqual('invoked', contextData.get(SubscriberChainSteps.KEY_API_RESPONSE), 'API step should set response flag');

		Id foobarId = (Id)contextData.get(SubscriberChainSteps.KEY_FOOBAR_ID);
		kern__Foobar__c record = [SELECT Name FROM kern__Foobar__c WHERE Id = :foobarId];
		Assert.isTrue(record.Name.contains('Updated'), 'Foobar should be updated by third step');
	}

	/**
	 * @description Verifies that a chain inherits the current LOG_Builder correlation
	 * and that log entries from the chain share the same correlation ID.
	 */
	@IsTest
	private static void shouldCorrelateLogsAcrossChainSteps()
	{
		kern.LOG_Builder.ignoreTestMode = true;

		String correlationId = kern.LOG_Builder.startCorrelation();

		Test.startTest();
		String executionId = kern.UTIL_AsyncChain.newChain('CorrelationTest')
				.then(new SubscriberChainSteps.OptionalFailingStep(), true)
				.then(new SubscriberChainSteps.CreateFoobarStep())
				.execute();
		Test.stopTest();

		kern__AsyncChainExecution__c execution = queryExecution(executionId);
		Assert.areEqual(correlationId, execution.kern__CorrelationId__c, 'Chain should inherit subscriber correlation ID');
		Assert.areEqual('Completed', execution.kern__Status__c, 'Chain should complete');

		List<kern__LogEntry__c> correlatedLogs = [SELECT kern__CorrelationId__c FROM kern__LogEntry__c WHERE kern__CorrelationId__c = :correlationId];
		Assert.isTrue(correlatedLogs.size() >= 1, 'At least 1 log entry should share the correlation ID (continueOnError warn)');
	}

	/**
	 * @description Verifies that performance logs are emitted with DurationMs when threshold is set low.
	 */
	@IsTest
	private static void shouldEmitPerformanceLogWithDuration()
	{
		kern.LOG_Builder.ignoreTestMode = true;
		insert new kern__LogSetting__c(
				SetupOwnerId = UserInfo.getUserId(),
				kern__EnablePerformanceLogging__c = true,
				kern__PerformanceThresholdMs__c = 1
		);

		Test.startTest();
		String executionId = kern.UTIL_AsyncChain.newChain(CHAIN_NAME)
				.then(new SubscriberChainSteps.CreateFoobarStep())
				.execute();
		Test.stopTest();

		kern__AsyncChainExecution__c execution = queryExecution(executionId);
		Assert.areEqual('Completed', execution.kern__Status__c, 'Chain should complete');
		Assert.isNotNull(execution.kern__DurationMs__c, 'DurationMs should be set on execution record');

		List<kern__LogEntry__c> perfLogs = [
				SELECT kern__DurationMs__c, kern__Message__c
				FROM kern__LogEntry__c
				WHERE kern__DurationMs__c != null
				ORDER BY CreatedDate DESC
		];
		Assert.isFalse(perfLogs.isEmpty(), 'At least one performance log should have DurationMs populated');
	}

	/**
	 * @description Verifies that a caller-supplied correlation ID is used instead of auto-generating one.
	 */
	@IsTest
	private static void shouldUseExplicitCorrelationId()
	{
		String customCorrelationId = 'subscriber-correlation-' + Datetime.now().getTime();

		Test.startTest();
		String executionId = kern.UTIL_AsyncChain.newChain('ExplicitCorrelation')
				.then(new SubscriberChainSteps.CreateFoobarStep())
				.execute(customCorrelationId);
		Test.stopTest();

		kern__AsyncChainExecution__c execution = queryExecution(executionId);
		Assert.areEqual(customCorrelationId, execution.kern__CorrelationId__c, 'Should use the explicit correlation ID');
		Assert.areEqual('Completed', execution.kern__Status__c, 'Chain should complete');
	}

	/**
	 * @description Verifies that the serialized logging context is persisted in the chain's context data.
	 */
	@IsTest
	private static void shouldPersistLoggingContextForHydration()
	{
		kern.LOG_Builder.startCorrelation();

		Test.startTest();
		String executionId = kern.UTIL_AsyncChain.newChain('LogContextTest')
				.then(new SubscriberChainSteps.CreateFoobarStep())
				.execute();
		Test.stopTest();

		kern__AsyncChainExecution__c execution = queryExecution(executionId);
		Map<String, Object> contextData = parseContext(execution);
		Assert.isNotNull(contextData.get('__logContext'), 'Serialized log context should be stored in chain context');
	}

	/**
	 * @description Verifies that kern.UTIL_AsyncChain.ApiStep wraps an API_Outbound handler
	 * and executes it as a chain step, storing the API result in context.
	 */
	@IsTest
	private static void shouldExecuteApiStepBridgeInChain()
	{
		kern.API_MockFactory.forService('kern.API_PostExample')
				.body('{"body":"test","id":101,"title":"ApiStepBridge","userId":9}')
				.statusCode(201)
				.register();

		kern__Foobar__c record = new kern__Foobar__c(Name = 'ApiStep Test');
		kern.DML_Builder.newTransaction().doInsert(record).execute();

		Test.startTest();
		String executionId = kern.UTIL_AsyncChain.newChain('ApiStepBridgeTest')
				.then(new kern.UTIL_AsyncChain.ApiStep(kern.UTIL_System.getTypeForClassName('API_PostExample'))
						.triggeringRecord(record.Id)
						.withParameter('foo', 'bridgeValue'))
				.execute();
		Test.stopTest();

		kern__AsyncChainExecution__c execution = queryExecution(executionId);
		Assert.areEqual('Completed', execution.kern__Status__c, 'ApiStep bridge chain should complete');
		Assert.areEqual(1, execution.kern__CompletedSteps__c, 'One step should complete');

		Map<String, Object> contextData = parseContext(execution);
		Map<String, Object> apiResult = (Map<String, Object>)contextData.get('__apiResult_0');
		Assert.isNotNull(apiResult, 'API result should be stored in context');
		Assert.areEqual(true, apiResult.get('success'), 'API call should succeed');
		Assert.isNotNull(apiResult.get('apiCallId'), 'ApiCall ID should be stored');
	}

	/**
	 * @description Verifies that ApiStep resolves parameters and triggering record from ChainContext
	 * using withParameterFrom() and triggeringRecordFrom().
	 */
	@IsTest
	private static void shouldResolveApiStepParametersFromContext()
	{
		kern.API_MockFactory.forService('kern.API_PostExample')
				.body('{"body":"test","id":101,"title":"ContextParam","userId":9}')
				.statusCode(201)
				.register();

		kern__Foobar__c record = new kern__Foobar__c(Name = 'ApiStep Context Test');
		kern.DML_Builder.newTransaction().doInsert(record).execute();

		Test.startTest();
		String executionId = kern.UTIL_AsyncChain.newChain('ApiStepContextTest')
				.withInitialContext('recordId', String.valueOf(record.Id))
				.withInitialContext('dynamicParam', 'fromContext')
				.then(new kern.UTIL_AsyncChain.ApiStep(kern.UTIL_System.getTypeForClassName('API_PostExample'))
						.triggeringRecordFrom('recordId')
						.withParameterFrom('foo', 'dynamicParam'))
				.execute();
		Test.stopTest();

		kern__AsyncChainExecution__c execution = queryExecution(executionId);
		Assert.areEqual('Completed', execution.kern__Status__c, 'ApiStep with context params should complete');
	}

	/**
	 * @description Verifies that two ApiStep instances in the same chain produce independent results
	 * stored under separate context keys (__apiResult_0 and __apiResult_1).
	 */
	@IsTest
	private static void shouldSupportMultipleApiStepsInChain()
	{
		kern.API_MockFactory.forService('kern.API_PostExample')
				.body('{"body":"test","id":101,"title":"Multi","userId":9}')
				.statusCode(201)
				.register();

		kern__Foobar__c record = new kern__Foobar__c(Name = 'Multi ApiStep Test');
		kern.DML_Builder.newTransaction().doInsert(record).execute();

		AsyncOptions options = new AsyncOptions();
		options.maximumQueueableStackDepth = 3;

		Test.startTest();
		String executionId = kern.UTIL_AsyncChain.newChain('MultiApiStepTest')
				.then(new kern.UTIL_AsyncChain.ApiStep(kern.UTIL_System.getTypeForClassName('API_PostExample'))
						.triggeringRecord(record.Id)
						.withParameter('foo', 'first'))
				.then(new kern.UTIL_AsyncChain.ApiStep(kern.UTIL_System.getTypeForClassName('API_PostExample'))
						.triggeringRecord(record.Id)
						.withParameter('foo', 'second'))
				.withAsyncOptions(options)
				.execute();
		Test.stopTest();

		kern__AsyncChainExecution__c execution = queryExecution(executionId);
		Assert.areEqual('Completed', execution.kern__Status__c, 'Multi-ApiStep chain should complete');
		Assert.areEqual(2, execution.kern__CompletedSteps__c, 'Both ApiSteps should complete');

		Map<String, Object> contextData = parseContext(execution);
		Assert.isNotNull(contextData.get('__apiResult_0'), 'First ApiStep result should be stored');
		Assert.isNotNull(contextData.get('__apiResult_1'), 'Second ApiStep result should be stored');
	}

	/**
	 * @description Verifies that WriteContextStep writes a 1KB payload to context under
	 * step_&lt;index&gt; and reads back the prior step's payload across step boundaries.
	 */
	@IsTest
	private static void shouldWriteAndReadPriorContextPayload()
	{
		AsyncOptions options = new AsyncOptions();
		options.maximumQueueableStackDepth = 4;

		Test.startTest();
		String executionId = kern.UTIL_AsyncChain.newChain('WriteContextChain')
				.then(new SubscriberChainSteps.WriteContextStep())
				.then(new SubscriberChainSteps.WriteContextStep())
				.then(new SubscriberChainSteps.WriteContextStep())
				.withAsyncOptions(options)
				.execute();
		Test.stopTest();

		kern__AsyncChainExecution__c execution = queryExecution(executionId);
		Assert.areEqual('Completed', execution.kern__Status__c, 'WriteContextStep chain should complete');
		Assert.areEqual(3, execution.kern__CompletedSteps__c, 'All 3 WriteContextStep instances should complete');

		Map<String, Object> contextData = parseContext(execution);
		for(Integer index = 0; index < 3; index++)
		{
			String key = SubscriberChainSteps.CONTEXT_KEY_PREFIX + index;
			Object payload = contextData.get(key);
			Assert.isNotNull(payload, 'Payload should be present at ' + key);
			Assert.areEqual(SubscriberChainSteps.WRITE_CONTEXT_PAYLOAD_SIZE, ((String)payload).length(),
					'Payload at ' + key + ' should be ' + SubscriberChainSteps.WRITE_CONTEXT_PAYLOAD_SIZE + ' chars');
		}
	}

	/**
	 * @description Verifies WriteContextStep fails fast when a prior payload is shorter than the
	 * expected size (covers the defensive size-mismatch branch). Uses a 2-step chain where the
	 * first step seeds an undersized payload via WriteUndersizedContextStep, then
	 * WriteContextStep at step 1 detects the mismatch.
	 */
	@IsTest
	private static void shouldFailWhenPriorPayloadIsUndersized()
	{
		AsyncOptions options = new AsyncOptions();
		options.maximumQueueableStackDepth = 3;

		Test.startTest();
		String executionId = kern.UTIL_AsyncChain.newChain('WriteContextSizeProbe')
				.then(new SubscriberChainSteps.WriteUndersizedContextStep())
				.then(new SubscriberChainSteps.WriteContextStep())
				.withAsyncOptions(options)
				.execute();
		Test.stopTest();

		kern__AsyncChainExecution__c execution = queryExecution(executionId);
		Assert.areEqual('Failed', execution.kern__Status__c, 'Chain should fail when prior payload is undersized');
		Assert.isTrue(execution.kern__ErrorMessage__c.contains('expected ' + SubscriberChainSteps.WRITE_CONTEXT_PAYLOAD_SIZE),
				'Error should mention the expected payload size; got: ' + execution.kern__ErrorMessage__c);
	}

	/**
	 * @description Verifies WriteContextStep fails fast when the prior context key is absent
	 * (covers the defensive missing-payload branch). Uses a 2-step chain where the first step
	 * does NOT write step_0, then WriteContextStep at step 1 detects the absence.
	 */
	@IsTest
	private static void shouldFailWhenPriorPayloadMissing()
	{
		AsyncOptions options = new AsyncOptions();
		options.maximumQueueableStackDepth = 3;

		Test.startTest();
		String executionId = kern.UTIL_AsyncChain.newChain('WriteContextMissingProbe')
				.then(new SubscriberChainSteps.NoWriteStep())
				.then(new SubscriberChainSteps.WriteContextStep())
				.withAsyncOptions(options)
				.execute();
		Test.stopTest();

		kern__AsyncChainExecution__c execution = queryExecution(executionId);
		Assert.areEqual('Failed', execution.kern__Status__c, 'Chain should fail when prior payload key absent');
		Assert.isTrue(execution.kern__ErrorMessage__c.contains('Prior payload missing'),
				'Error should mention missing prior payload; got: ' + execution.kern__ErrorMessage__c);
	}

	/**
	 * @description Queries an AsyncChainExecution__c record by ID.
	 *
	 * @param executionId The execution record ID.
	 *
	 * @return The queried execution record.
	 */
	private static kern__AsyncChainExecution__c queryExecution(String executionId)
	{
		return [
				SELECT kern__ChainName__c, kern__Status__c, kern__TotalSteps__c, kern__CompletedSteps__c,
						kern__ErrorMessage__c, kern__ContextData__c, kern__CorrelationId__c, kern__DurationMs__c
				FROM kern__AsyncChainExecution__c
				WHERE Id = :executionId
		];
	}

	/**
	 * @description Parses context data JSON from an execution record.
	 *
	 * @param execution The execution record.
	 *
	 * @return Deserialized context data map.
	 */
	private static Map<String, Object> parseContext(kern__AsyncChainExecution__c execution)
	{
		return String.isNotBlank(execution.kern__ContextData__c)
				? (Map<String, Object>)JSON.deserializeUntyped(execution.kern__ContextData__c)
				: new Map<String, Object>();
	}
}
