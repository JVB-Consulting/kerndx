// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Tests for SubscriberChainSteps, which exercise async chain orchestration
 * from subscriber context with real DML, API callouts, and context manipulation.
 *
 * @see SubscriberChainSteps
 *
 * @author your.name@company.com
 *
 * @group Async
 *
 * @date April 2026, October 2026
 */
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest(seeAllData=false)
private class SubscriberChainSteps_TEST
{
	/**
	 * @description Chain name used across tests.
	 */
	private static final String CHAIN_NAME = 'SubscriberTest';

	/**
	 * @description The suffix the framework appends to a launching run's id to key a launch from its first step.
	 */
	private static final String FIRST_STEP_LAUNCH_KEY_SUFFIX = ':0';

	/**
	 * @description The maximum queueable stack depth the nested-launch test gives the parent: its one step and first
	 * hop, plus the child's two steps.
	 */
	private static final Integer NESTED_LAUNCH_STACK_DEPTH = 4;

	/**
	 * @description The CPU budget the fan-out tests give each busy step: every hop of a test chain runs in the one
	 * test transaction, so the default budget over ten busy steps would exhaust the transaction's CPU.
	 */
	private static final Integer TEST_BUSY_MILLISECONDS = 100;

	/**
	 * @description The context key under which the engine keeps the last step's result; a successful step's message
	 * lives there, since the step log records a message only for a failed step.
	 */
	private static final String PREVIOUS_STEP_RESULT_KEY = '__previousStepResult';

	/**
	 * @description The run token the volume tests key their ids by: eight letters of the id alphabet.
	 */
	private static final String TEST_RUN_TOKEN = 'abcdefab';

	/**
	 * @description The CPU budget the busy-step test asks for, in milliseconds.
	 */
	private static final Integer BUSY_TEST_MILLISECONDS = 300;

	/**
	 * @description A step may launch a chain of its own: the child completes both its steps, records the parent run as
	 * the id it was launched under and the action as its root, and is remembered under the parent run and the step.
	 */
	@IsTest
	private static void shouldLaunchAChildChainFromAStep()
	{
		String actionCorrelationId = kern.LOG_Builder.startCorrelation();
		AsyncOptions options = new AsyncOptions();
		options.maximumQueueableStackDepth = NESTED_LAUNCH_STACK_DEPTH;
		Test.startTest();
		String executionId = kern.UTIL_AsyncChain.newChain(CHAIN_NAME)
				.then(new SubscriberChainSteps.LaunchChildChainStep())
				.withAsyncOptions(options)
				.execute();
		Test.stopTest();

		kern__AsyncChainExecution__c parent = queryExecution(executionId);
		Assert.areEqual('Completed', parent.kern__Status__c, 'The parent completes: ' + parent.kern__ErrorMessage__c);
		String childExecutionId = (String)parseContext(parent).get(SubscriberChainSteps.KEY_CHILD_EXECUTION_ID);
		kern__AsyncChainExecution__c child = queryExecution(childExecutionId);
		Assert.areEqual('Completed', child.kern__Status__c, 'The child completes: ' + child.kern__ErrorMessage__c);
		Assert.areEqual(2, child.kern__CompletedSteps__c, 'The child ran both its steps');
		Assert.areEqual(parent.kern__CorrelationId__c, child.kern__LaunchCorrelationId__c, 'The child was launched under the parent run');
		Assert.areEqual(actionCorrelationId, child.kern__RootCorrelationId__c, 'The child keeps the action as its root');
		Assert.areEqual(executionId + FIRST_STEP_LAUNCH_KEY_SUFFIX, child.kern__DeclaredDeduplicationKey__c, 'The child is remembered under the parent run and the step');
	}

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
		List<kern__Foobar__c> foobars =
		[
				SELECT Id
				FROM kern__Foobar__c
				WHERE Id = :foobarId
		];
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
		kern__Foobar__c record =
		[
				SELECT Name
				FROM kern__Foobar__c
				WHERE Id = :foobarId
		];
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
	 * @description Verifies that RecoveringStep fails its first run for a chain while seeding exactly one
	 * recovery marker keyed to the execution, and that the step log records the idempotency declaration
	 * the operator retry gate reads.
	 */
	@IsTest
	private static void shouldSeedRecoveryMarkerAndFailFirstRun()
	{
		Test.startTest();
		String executionId = kern.UTIL_AsyncChain.newChain(CHAIN_NAME)
				.then(new SubscriberChainSteps.RecoveringStep())
				.execute();
		Test.stopTest();

		kern__AsyncChainExecution__c execution = queryExecution(executionId);
		Assert.areEqual('Failed', execution.kern__Status__c, 'First run should fail');
		Assert.isTrue(execution.kern__ErrorMessage__c.contains(SubscriberChainSteps.RECOVERY_FIRST_RUN_MESSAGE), 'Failure should report the seeded marker');
		Assert.isTrue(execution.kern__StepLog__c.contains('"isIdempotent":true'), 'Step log should carry the idempotency declaration');

		String markerName = SubscriberChainSteps.RECOVERY_MARKER_NAME_PREFIX + executionId;
		Assert.areEqual(1, [SELECT COUNT() FROM kern__Foobar__c WHERE Name = :markerName], 'Exactly one recovery marker should be seeded');
	}

	/**
	 * @description Verifies that RecoveringStep succeeds once its marker exists — the recovered run an
	 * operator retry produces — without seeding a second marker. The first step continues on error so the
	 * same execution reaches the step again.
	 */
	@IsTest
	private static void shouldRecoverOnceMarkerIsSeeded()
	{
		Test.startTest();
		String executionId = kern.UTIL_AsyncChain.newChain(CHAIN_NAME)
				.then(new SubscriberChainSteps.RecoveringStep(), true)
				.then(new SubscriberChainSteps.RecoveringStep())
				.execute();
		Test.stopTest();

		kern__AsyncChainExecution__c execution = queryExecution(executionId);
		Assert.areEqual('Completed', execution.kern__Status__c, 'Second run should recover the chain');
		Assert.areEqual(1, execution.kern__CompletedSteps__c, 'Only the recovered run should count as completed');
		Assert.isTrue(execution.kern__ErrorMessage__c.contains(SubscriberChainSteps.RECOVERY_FIRST_RUN_MESSAGE), 'Non-fatal summary should carry the first-run failure');

		String markerName = SubscriberChainSteps.RECOVERY_MARKER_NAME_PREFIX + executionId;
		Assert.areEqual(1, [SELECT COUNT() FROM kern__Foobar__c WHERE Name = :markerName], 'Recovered run should not seed a second marker');
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
		kern__Foobar__c record =
		[
				SELECT Name
				FROM kern__Foobar__c
				WHERE Id = :foobarId
		];
		Assert.isTrue(record.Name.contains('Updated'), 'Foobar should be updated by third step');
	}

	/**
	 * @description After a Foobar is created, the call is sent and the Foobar is updated, VerifyContextStep finds all
	 * three and writes true under KEY_VERIFIED, and the chain completes all four steps.
	 */
	@IsTest
	private static void shouldVerifyTheContextOnceEveryEarlierStepHasRun()
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
				.then(new SubscriberChainSteps.VerifyContextStep())
				.execute();
		Test.stopTest();

		kern__AsyncChainExecution__c execution = queryExecution(executionId);
		Assert.areEqual('Completed', execution.kern__Status__c, 'Expected the chain to complete, got ' + execution.kern__ErrorMessage__c);
		Assert.areEqual(4, execution.kern__CompletedSteps__c, 'Expected all four steps to complete');
		Assert.areEqual(true, parseContext(execution).get(SubscriberChainSteps.KEY_VERIFIED), 'Expected VerifyContextStep to write true');
	}

	/**
	 * @description VerifyContextStep given a Foobar Id that names no record fails with the message that names the Id,
	 * rather than with an error from reading a record that is not there.
	 */
	@IsTest
	private static void shouldFailVerificationWhenTheFoobarIdNamesNoRecord()
	{
		Id unknownFoobarId = kern.UTIL_Random.randomId(kern__Foobar__c.SObjectType);

		Test.startTest();
		String executionId = kern.UTIL_AsyncChain.newChain(CHAIN_NAME)
				.withInitialContext(SubscriberChainSteps.KEY_FOOBAR_ID, unknownFoobarId)
				.withInitialContext(SubscriberChainSteps.KEY_API_RESPONSE, kern.UTIL_Random.randomAlphanumeric(8))
				.then(new SubscriberChainSteps.VerifyContextStep())
				.execute();
		Test.stopTest();

		kern__AsyncChainExecution__c execution = queryExecution(executionId);
		String expectedMessage = SubscriberChainSteps.FOOBAR_NOT_FOUND_MESSAGE + unknownFoobarId;
		Assert.areEqual('Failed', execution.kern__Status__c, 'Expected the chain to fail');
		Assert.areEqual(0, execution.kern__CompletedSteps__c, 'Expected no step to complete');
		Assert.isTrue(execution.kern__ErrorMessage__c.contains(expectedMessage), 'Expected "' + expectedMessage + '", got ' + execution.kern__ErrorMessage__c);
		Assert.isNull(parseContext(execution).get(SubscriberChainSteps.KEY_VERIFIED), 'Expected nothing under KEY_VERIFIED');
	}

	/**
	 * @description VerifyContextStep run with no Foobar Id in the context fails with the message that says so.
	 */
	@IsTest
	private static void shouldFailVerificationWhenTheContextHoldsNoFoobarId()
	{
		Test.startTest();
		String executionId = kern.UTIL_AsyncChain.newChain(CHAIN_NAME)
				.then(new SubscriberChainSteps.VerifyContextStep())
				.execute();
		Test.stopTest();

		kern__AsyncChainExecution__c execution = queryExecution(executionId);
		String expectedMessage = SubscriberChainSteps.MISSING_FOOBAR_ID_MESSAGE;
		Assert.areEqual('Failed', execution.kern__Status__c, 'Expected the chain to fail, got ' + execution.kern__Status__c);
		Assert.areEqual(0, execution.kern__CompletedSteps__c, 'Expected no step to complete, got ' + execution.kern__CompletedSteps__c);
		Assert.isTrue(execution.kern__ErrorMessage__c.contains(expectedMessage), 'Expected "' + expectedMessage + '", got ' + execution.kern__ErrorMessage__c);
		Assert.isNull(parseContext(execution).get(SubscriberChainSteps.KEY_VERIFIED), 'Expected nothing under KEY_VERIFIED');
	}

	/**
	 * @description VerifyContextStep run with a Foobar Id but no API marker in the context fails with the message that
	 * names the missing marker.
	 */
	@IsTest
	private static void shouldFailVerificationWhenTheContextHoldsNoApiMarker()
	{
		Test.startTest();
		String executionId = kern.UTIL_AsyncChain.newChain(CHAIN_NAME)
				.withInitialContext(SubscriberChainSteps.KEY_FOOBAR_ID, kern.UTIL_Random.randomId(kern__Foobar__c.SObjectType))
				.then(new SubscriberChainSteps.VerifyContextStep())
				.execute();
		Test.stopTest();

		kern__AsyncChainExecution__c execution = queryExecution(executionId);
		String expectedMessage = SubscriberChainSteps.MISSING_API_MARKER_MESSAGE;
		Assert.areEqual('Failed', execution.kern__Status__c, 'Expected the chain to fail, got ' + execution.kern__Status__c);
		Assert.areEqual(0, execution.kern__CompletedSteps__c, 'Expected no step to complete, got ' + execution.kern__CompletedSteps__c);
		Assert.isTrue(execution.kern__ErrorMessage__c.contains(expectedMessage), 'Expected "' + expectedMessage + '", got ' + execution.kern__ErrorMessage__c);
		Assert.isNull(parseContext(execution).get(SubscriberChainSteps.KEY_VERIFIED), 'Expected nothing under KEY_VERIFIED');
	}

	/**
	 * @description VerifyContextStep run after a Foobar was created but never updated fails with the message that says
	 * the earlier step did not update it.
	 */
	@IsTest
	private static void shouldFailVerificationWhenTheFoobarWasNotUpdated()
	{
		Test.startTest();
		String executionId = kern.UTIL_AsyncChain.newChain(CHAIN_NAME)
				.withInitialContext(SubscriberChainSteps.KEY_API_RESPONSE, kern.UTIL_Random.randomAlphanumeric(8))
				.then(new SubscriberChainSteps.CreateFoobarStep())
				.then(new SubscriberChainSteps.VerifyContextStep())
				.execute();
		Test.stopTest();

		kern__AsyncChainExecution__c execution = queryExecution(executionId);
		Assert.areEqual('Failed', execution.kern__Status__c, 'Expected the chain to fail');
		Assert.areEqual(1, execution.kern__CompletedSteps__c, 'Expected only the create step to complete');
		Assert.isTrue(execution.kern__ErrorMessage__c.contains(SubscriberChainSteps.FOOBAR_NOT_UPDATED_MESSAGE),
				'Expected the not-updated failure, got ' + execution.kern__ErrorMessage__c);
	}

	/**
	 * @description UpdateFoobarStep run with no Foobar Id in the context fails with the message that says so, rather
	 * than with a null-pointer error, and no step completes.
	 */
	@IsTest
	private static void shouldFailTheUpdateWhenTheContextHoldsNoFoobarId()
	{
		Test.startTest();
		String executionId = kern.UTIL_AsyncChain.newChain(CHAIN_NAME)
				.then(new SubscriberChainSteps.UpdateFoobarStep())
				.execute();
		Test.stopTest();

		kern__AsyncChainExecution__c execution = queryExecution(executionId);
		String expectedMessage = SubscriberChainSteps.MISSING_FOOBAR_ID_MESSAGE;
		Assert.areEqual('Failed', execution.kern__Status__c, 'Expected the chain to fail');
		Assert.areEqual(0, execution.kern__CompletedSteps__c, 'Expected no step to complete');
		Assert.isTrue(execution.kern__ErrorMessage__c.contains(expectedMessage), 'Expected "' + expectedMessage + '", got ' + execution.kern__ErrorMessage__c);
	}

	/**
	 * @description UpdateFoobarStep given a Foobar Id that names no record fails with the message that names the Id,
	 * rather than with a null-pointer error, and no step completes.
	 */
	@IsTest
	private static void shouldFailTheUpdateWhenTheFoobarIdNamesNoRecord()
	{
		Id unknownFoobarId = kern.UTIL_Random.randomId(kern__Foobar__c.SObjectType);

		Test.startTest();
		String executionId = kern.UTIL_AsyncChain.newChain(CHAIN_NAME)
				.withInitialContext(SubscriberChainSteps.KEY_FOOBAR_ID, unknownFoobarId)
				.then(new SubscriberChainSteps.UpdateFoobarStep())
				.execute();
		Test.stopTest();

		kern__AsyncChainExecution__c execution = queryExecution(executionId);
		String expectedMessage = SubscriberChainSteps.FOOBAR_NOT_FOUND_MESSAGE + unknownFoobarId;
		Assert.areEqual('Failed', execution.kern__Status__c, 'Expected the chain to fail');
		Assert.areEqual(0, execution.kern__CompletedSteps__c, 'Expected no step to complete');
		Assert.isTrue(execution.kern__ErrorMessage__c.contains(expectedMessage), 'Expected "' + expectedMessage + '", got ' + execution.kern__ErrorMessage__c);
	}

	/**
	 * @description Verifies that a chain launched inside a traced action runs under a correlation id of its own,
	 * records the action's id as the id it was launched under and as its root, and writes its steps' log entries with
	 * the action's id as their root, so a query by the action's id finds the whole action.
	 */
	@IsTest
	private static void shouldCorrelateLogsAcrossChainSteps()
	{
		kern.LOG_Builder.ignoreTestMode = true;

		String actionCorrelationId = kern.LOG_Builder.startCorrelation();

		Test.startTest();
		String executionId = kern.UTIL_AsyncChain.newChain('CorrelationTest')
				.then(new SubscriberChainSteps.OptionalFailingStep(), true)
				.then(new SubscriberChainSteps.CreateFoobarStep())
				.execute();
		Test.stopTest();

		kern__AsyncChainExecution__c execution = queryExecution(executionId);
		Assert.areEqual('Completed', execution.kern__Status__c, 'Chain should complete');
		Assert.areNotEqual(actionCorrelationId, execution.kern__CorrelationId__c, 'The run gets a correlation id of its own');
		Assert.areEqual(actionCorrelationId, execution.kern__LaunchCorrelationId__c, 'The run records the action\'s id as the id it was launched under');
		Assert.areEqual(actionCorrelationId, execution.kern__RootCorrelationId__c, 'The run records the action\'s id as its root');

		String runCorrelationId = execution.kern__CorrelationId__c;
		List<kern__LogEntry__c> runLogs =
		[
				SELECT kern__CorrelationId__c
				FROM kern__LogEntry__c
				WHERE kern__RootCorrelationId__c = :actionCorrelationId
				AND kern__CorrelationId__c = :runCorrelationId
		];
		Assert.isTrue(runLogs.size() >= 1, 'At least 1 log entry of the run carries the action as its root (continueOnError warn)');
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

		List<kern__LogEntry__c> perfLogs =
		[
				SELECT kern__DurationMs__c,
						kern__Message__c
				FROM kern__LogEntry__c
				WHERE kern__DurationMs__c != NULL
				ORDER BY CreatedDate DESC
		];
		Assert.isFalse(perfLogs.isEmpty(), 'At least one performance log should have DurationMs populated');
	}

	/**
	 * @description Verifies that a caller-supplied correlation ID is used instead of auto-generating one.
	 * The suffix is alphanumeric, never an epoch timestamp: thirteen contiguous digits are card-shaped,
	 * and whenever the millisecond value happens to be Luhn-valid the framework's card masking redacts
	 * it, failing the round-trip comparison intermittently.
	 *
	 * @date July 2026
	 */
	@IsTest
	private static void shouldUseExplicitCorrelationId()
	{
		String customCorrelationId = 'subscriber-correlation-' + kern.UTIL_Random.randomAlphanumeric(12);

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
		for(Integer index = 0; Index < 3; Index++)
		{
			String key = SubscriberChainSteps.CONTEXT_KEY_PREFIX + Index;
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
	 * @description Verifies the 1.2 typed getChainStatus accessor returns a populated
	 * ChainStatus value object for a completed chain, with the terminal / running / failed
	 * predicates reading as plain code.
	 */
	@IsTest
	private static void shouldReturnTypedChainStatusForCompletedChain()
	{
		Test.startTest();
		String executionId = kern.UTIL_AsyncChain.newChain(CHAIN_NAME)
				.then(new SubscriberChainSteps.CreateFoobarStep())
				.execute();
		Test.stopTest();

		kern.UTIL_AsyncChain.ChainStatus status = kern.UTIL_AsyncChain.getChainStatus(executionId);

		Assert.isNotNull(status, 'getChainStatus should return a ChainStatus for a known execution Id');
		Assert.areEqual(executionId, String.valueOf(status.executionId), 'ChainStatus.executionId should match the launched chain');
		Assert.areEqual(CHAIN_NAME, status.chainName, 'ChainStatus.chainName should match newChain()');
		Assert.areEqual('Completed', status.status, 'ChainStatus.status should be Completed');
		Assert.areEqual(1, status.totalSteps, 'ChainStatus.totalSteps should be 1');
		Assert.areEqual(1, status.completedSteps, 'ChainStatus.completedSteps should be 1');
		Assert.isTrue(status.isTerminal(), 'A completed chain should be terminal');
		Assert.isFalse(status.isRunning(), 'A completed chain should not be running');
		Assert.isFalse(status.isFailed(), 'A completed chain should not be failed');
		Assert.isNotNull(status.startedAt, 'ChainStatus.startedAt should be set');
		Assert.isNotNull(status.completedAt, 'ChainStatus.completedAt should be set for a terminal chain');
	}

	/**
	 * @description Verifies the typed getChainStatus accessor reports a failed chain via
	 * isFailed() and carries the failing step's error message.
	 */
	@IsTest
	private static void shouldReturnFailedTypedChainStatus()
	{
		Test.startTest();
		String executionId = kern.UTIL_AsyncChain.newChain(CHAIN_NAME)
				.then(new SubscriberChainSteps.FailingStep())
				.execute();
		Test.stopTest();

		kern.UTIL_AsyncChain.ChainStatus status = kern.UTIL_AsyncChain.getChainStatus(executionId);

		Assert.isNotNull(status, 'getChainStatus should return a ChainStatus for a failed chain');
		Assert.areEqual('Failed', status.status, 'ChainStatus.status should be Failed');
		Assert.isTrue(status.isFailed(), 'isFailed() should be true for a failed chain');
		Assert.isTrue(status.isTerminal(), 'A failed chain should be terminal');
		Assert.isFalse(status.isRunning(), 'A failed chain should not be running');
		Assert.isTrue(status.errorMessage.contains('Deliberate subscriber failure'),
				'ChainStatus.errorMessage should carry the failing step message; got: ' + status.errorMessage);
	}

	/**
	 * @description Verifies getChainStatus returns null for an execution Id that does not
	 * resolve to a visible AsyncChainExecution record (the documented not-found contract).
	 */
	@IsTest
	private static void shouldReturnNullTypedStatusForUnknownId()
	{
		Id unknownId = fakeExecutionId();

		Test.startTest();
		kern.UTIL_AsyncChain.ChainStatus status = kern.UTIL_AsyncChain.getChainStatus(unknownId);
		Test.stopTest();

		Assert.isNull(status, 'getChainStatus should return null for an unknown execution Id');
	}

	/**
	 * @description Verifies the 1.2 first-step delay (withDelayMinutes) is reachable from a
	 * subscriber, accepts an over-range value without throwing, and does not stop the chain
	 * from completing. The Queueable delay is zeroed in Apex test context, so this proves
	 * reachability and completion only — the 0-10 minute clamp itself is not observable from a
	 * subscriber @IsTest and is covered by the package's own unit tests.
	 */
	@IsTest
	private static void shouldCompleteChainWithFirstStepDelay()
	{
		Test.startTest();
		String executionId = kern.UTIL_AsyncChain.newChain(CHAIN_NAME)
				.withDelayMinutes(15)
				.then(new SubscriberChainSteps.CreateFoobarStep())
				.execute();
		Test.stopTest();

		kern__AsyncChainExecution__c execution = queryExecution(executionId);
		Assert.areEqual('Completed', execution.kern__Status__c, 'A chain with a first-step delay should still complete');
		Assert.areEqual(1, execution.kern__CompletedSteps__c, 'The single step should complete after the delayed first enqueue');
	}

	/**
	 * @description Verifies withDelayMinutes(0) is an accepted no-op and the chain completes.
	 */
	@IsTest
	private static void shouldTreatZeroFirstStepDelayAsNoOp()
	{
		Test.startTest();
		String executionId = kern.UTIL_AsyncChain.newChain(CHAIN_NAME)
				.withDelayMinutes(0)
				.then(new SubscriberChainSteps.CreateFoobarStep())
				.execute();
		Test.stopTest();

		kern__AsyncChainExecution__c execution = queryExecution(executionId);
		Assert.areEqual('Completed', execution.kern__Status__c, 'A zero first-step delay should be a no-op and the chain should complete');
	}

	/**
	 * @description Verifies the 1.2 per-step idempotency-key overloads are reachable from
	 * inside a chain step and produce the documented composite shape: the bare key is
	 * executionId-stepIndex, and the Id / String grained overloads append the grain.
	 */
	@IsTest
	private static void shouldExposeIdempotencyKeyOverloadsToStep()
	{
		Test.startTest();
		String executionId = kern.UTIL_AsyncChain.newChain(CHAIN_NAME)
				.then(new SubscriberChainSteps.CaptureIdempotencyKeyStep())
				.execute();
		Test.stopTest();

		kern__AsyncChainExecution__c execution = queryExecution(executionId);
		Assert.areEqual('Completed', execution.kern__Status__c, 'Idempotency-capture chain should complete');

		Map<String, Object> contextData = parseContext(execution);
		String capturedExecutionId = (String)contextData.get(SubscriberChainSteps.KEY_IDEMPOTENCY_EXECUTION_ID);
		String capturedStepIndex = (String)contextData.get(SubscriberChainSteps.KEY_IDEMPOTENCY_STEP_INDEX);
		String capturedRecordId = (String)contextData.get(SubscriberChainSteps.KEY_IDEMPOTENCY_RECORD_ID);
		String baseKey = (String)contextData.get(SubscriberChainSteps.KEY_IDEMPOTENCY_BASE);
		String recordKey = (String)contextData.get(SubscriberChainSteps.KEY_IDEMPOTENCY_RECORD);
		String grainKey = (String)contextData.get(SubscriberChainSteps.KEY_IDEMPOTENCY_GRAIN);

		Assert.areEqual(executionId, capturedExecutionId, 'The step should observe the chain execution Id');
		Assert.areEqual(capturedExecutionId + '-' + capturedStepIndex, baseKey,
				'idempotencyKey() should be executionId-stepIndex; got: ' + baseKey);
		Assert.areEqual(baseKey + '-' + capturedRecordId, recordKey,
				'idempotencyKey(Id) should append the record Id; got: ' + recordKey);
		Assert.areEqual(baseKey + '-' + SubscriberChainSteps.IDEMPOTENCY_GRAIN, grainKey,
				'idempotencyKey(String) should append the grain; got: ' + grainKey);
	}

	/**
	 * @description Builds a syntactically valid but non-existent AsyncChainExecution Id for the
	 * not-found getChainStatus path. Raw describe is an acceptable independent oracle in a
	 * _TEST class.
	 *
	 * @return An Id of the AsyncChainExecution key prefix that resolves to no record.
	 */
	private static Id fakeExecutionId()
	{
		String keyPrefix = kern__AsyncChainExecution__c.SObjectType.getDescribe().getKeyPrefix();
		return Id.valueOf(keyPrefix + '000000000001');
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
		return
		[
				SELECT kern__ChainName__c,
						kern__Status__c,
						kern__TotalSteps__c,
						kern__CompletedSteps__c,
						kern__ErrorMessage__c,
						kern__ContextData__c,
						kern__CorrelationId__c,
						kern__LaunchCorrelationId__c,
						kern__RootCorrelationId__c,
						kern__DeclaredDeduplicationKey__c,
						kern__DurationMs__c,
						kern__StepLog__c
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

	/**
	 * @description Reads a run row by id with the fields the volume tests assert on.
	 *
	 * @param executionId The run's record id.
	 *
	 * @return The run row.
	 */
	private static kern__AsyncChainExecution__c readRun(Id executionId)
	{
		return (kern__AsyncChainExecution__c)kern.QRY_Builder.selectFrom(kern__AsyncChainExecution__c.SObjectType)
				.fields(new List<SObjectField>
				{
						kern__AsyncChainExecution__c.kern__Status__c, kern__AsyncChainExecution__c.kern__FailureCategory__c, kern__AsyncChainExecution__c.kern__StepLog__c,
						kern__AsyncChainExecution__c.kern__ErrorMessage__c, kern__AsyncChainExecution__c.kern__CorrelationId__c, kern__AsyncChainExecution__c.kern__DurationMs__c,
						kern__AsyncChainExecution__c.kern__ContextData__c
				})
				.condition(kern__AsyncChainExecution__c.Id).equals(executionId)
				.getFirst();
	}

	/**
	 * @description The message of the last step the engine ran, read from the run's persisted context.
	 *
	 * @param run The run row, with its context data.
	 *
	 * @return The message, or null when no step result is persisted.
	 */
	private static String lastStepMessage(kern__AsyncChainExecution__c run)
	{
		Map<String, Object> previous = (Map<String, Object>)parseContext(run).get(PREVIOUS_STEP_RESULT_KEY);
		return previous == null ? null : (String)previous.get('message');
	}

	/**
	 * @description Reads the one run launched under a correlation, or null.
	 *
	 * @param correlationId The launching run's correlation id.
	 *
	 * @return The launched run, or null when none was launched under it.
	 */
	private static kern__AsyncChainExecution__c readLaunchedUnder(String correlationId)
	{
		return (kern__AsyncChainExecution__c)kern.QRY_Builder.selectFrom(kern__AsyncChainExecution__c.SObjectType)
				.fields(new List<SObjectField>
				{
						kern__AsyncChainExecution__c.kern__ChainName__c, kern__AsyncChainExecution__c.kern__TotalSteps__c, kern__AsyncChainExecution__c.kern__StepLog__c,
						kern__AsyncChainExecution__c.kern__CorrelationId__c
				})
				.condition(kern__AsyncChainExecution__c.kern__LaunchCorrelationId__c).equals(correlationId)
				.getFirst();
	}

	/**
	 * @description Every eighth leaf fails, and the failing kinds cycle plain, permanent, after retries.
	 */
	@IsTest
	private static void shouldComputeTheLeafOutcomeFromTheOrdinal()
	{
		Assert.areEqual(SubscriberChainSteps.OUTCOME_SUCCEED, SubscriberChainSteps.leafOutcome(1), 'A leaf off the failing stride succeeds');
		Assert.areEqual(SubscriberChainSteps.OUTCOME_FAIL, SubscriberChainSteps.leafOutcome(0), 'The first failing leaf fails plainly');
		Assert.areEqual(SubscriberChainSteps.OUTCOME_FAIL_PERMANENTLY, SubscriberChainSteps.leafOutcome(8), 'The second fails permanently');
		Assert.areEqual(SubscriberChainSteps.OUTCOME_FAIL_AFTER_RETRIES, SubscriberChainSteps.leafOutcome(16), 'The third fails after retries');
		Assert.areEqual(SubscriberChainSteps.OUTCOME_FAIL, SubscriberChainSteps.leafOutcome(24), 'The kinds cycle');
	}

	/**
	 * @description A harness id is UUID-shaped from the letters a to f, so the console's search resolves it and no digit run forms.
	 */
	@IsTest
	private static void shouldSpellHarnessIdsInTheTrackingIdShapeWithLettersOnly()
	{
		Assert.areEqual('aaaa', SubscriberChainSteps.volumeLetters(0, 4), 'Zero is the first letter, padded');
		Assert.areEqual('aaba', SubscriberChainSteps.volumeLetters(6, 4), 'Six carries into the next letter');
		String id = SubscriberChainSteps.volumeRunId(TEST_RUN_TOKEN, SubscriberChainSteps.KIND_RECONCILIATION_RUN, 12, 3, 124);
		Assert.areEqual(36, id.length(), 'A harness id is 36 characters');
		Assert.isTrue(Pattern.matches('^[a-f]{8}-[a-f]{4}-[a-f]{4}-[a-f]{4}-[a-f]{12}$', id), 'A harness id is UUID-shaped from the letters a to f: ' + id);
	}

	/**
	 * @description When the next level is the target depth, the fan-out step launches a five-step leaf under its own run.
	 */
	@IsTest
	private static void shouldLaunchALeafChildWhenTheNextLevelIsTheTarget()
	{
		Test.startTest();
		Id rootId = kern.UTIL_AsyncChain.newChain(SubscriberChainSteps.VOLUME_CHAIN_NAMES[0])
				.withInitialContext(SubscriberChainSteps.KEY_VOLUME_DEPTH, 0)
				.withInitialContext(SubscriberChainSteps.KEY_VOLUME_TARGET_DEPTH, 1)
				.withInitialContext(SubscriberChainSteps.KEY_VOLUME_ORDINAL, 0)
				.withInitialContext(SubscriberChainSteps.KEY_VOLUME_ROOT_ORDINAL, 0)
				.withInitialContext(SubscriberChainSteps.KEY_VOLUME_RUN_IDENTIFIER, TEST_RUN_TOKEN)
				.withInitialContext(SubscriberChainSteps.KEY_BUSY_MILLISECONDS, TEST_BUSY_MILLISECONDS)
				.then(new SubscriberChainSteps.FanOutStep())
				.execute(SubscriberChainSteps.volumeRunId(TEST_RUN_TOKEN, SubscriberChainSteps.KIND_RECONCILIATION_RUN, 0, 0, 0));
		Test.stopTest();

		kern__AsyncChainExecution__c child = readLaunchedUnder(readRun(rootId).kern__CorrelationId__c);
		Assert.isNotNull(child, 'The fan-out step launched one child under the root');
		Assert.areEqual(SubscriberChainSteps.VOLUME_CHAIN_NAMES[1], child.kern__ChainName__c, 'The child carries the next level\'s name');
		String expectedChildId = SubscriberChainSteps.volumeRunId(TEST_RUN_TOKEN, SubscriberChainSteps.KIND_RECONCILIATION_RUN, 0, 1, 0);
		Assert.areEqual(expectedChildId, child.kern__CorrelationId__c, 'The child carries the token-keyed id the step minted');
		Assert.areEqual(5, child.kern__TotalSteps__c, 'A leaf has five steps');
		Assert.isTrue(child.kern__StepLog__c.contains('OutcomeStep') || child.kern__StepLog__c.contains('RetryingFailureStep'), 'A leaf ends in an outcome');
	}

	/**
	 * @description Below the target depth, the fan-out step launches a child of five fanning steps, not a leaf.
	 */
	@IsTest
	private static void shouldLaunchAFanningChildBelowTheTarget()
	{
		Test.startTest();
		Id rootId = kern.UTIL_AsyncChain.newChain(SubscriberChainSteps.VOLUME_CHAIN_NAMES[0])
				.withInitialContext(SubscriberChainSteps.KEY_VOLUME_DEPTH, 0)
				.withInitialContext(SubscriberChainSteps.KEY_VOLUME_TARGET_DEPTH, 2)
				.withInitialContext(SubscriberChainSteps.KEY_VOLUME_ORDINAL, 0)
				.withInitialContext(SubscriberChainSteps.KEY_VOLUME_ROOT_ORDINAL, 1)
				.withInitialContext(SubscriberChainSteps.KEY_VOLUME_RUN_IDENTIFIER, TEST_RUN_TOKEN)
				.withInitialContext(SubscriberChainSteps.KEY_BUSY_MILLISECONDS, TEST_BUSY_MILLISECONDS)
				.then(new SubscriberChainSteps.FanOutStep())
				.execute(SubscriberChainSteps.volumeRunId(TEST_RUN_TOKEN, SubscriberChainSteps.KIND_RECONCILIATION_RUN, 1, 0, 0));
		Test.stopTest();

		kern__AsyncChainExecution__c child = readLaunchedUnder(readRun(rootId).kern__CorrelationId__c);
		Assert.isNotNull(child, 'The fan-out step launched one child under the root');
		Assert.areEqual(5, child.kern__TotalSteps__c, 'A fanning child has five steps');
		Assert.isTrue(child.kern__StepLog__c.contains('FanOutStep'), 'A child below the target fans out again');
		Assert.isFalse(child.kern__StepLog__c.contains('OutcomeStep'), 'A child below the target is not a leaf');
	}

	/**
	 * @description The busy step spends at least the CPU budget its context names and reports the work.
	 */
	@IsTest
	private static void shouldWorkForTheRequestedBudget()
	{
		Test.startTest();
		Id executionId = kern.UTIL_AsyncChain.newChain('Volume_BusyTest')
				.withInitialContext(SubscriberChainSteps.KEY_BUSY_MILLISECONDS, BUSY_TEST_MILLISECONDS)
				.then(new SubscriberChainSteps.BusyStep())
				.execute();
		Test.stopTest();

		kern__AsyncChainExecution__c run = readRun(executionId);
		Assert.areEqual('Completed', run.kern__Status__c, 'The busy step completes');
		Assert.isTrue(String.valueOf(lastStepMessage(run)).startsWith('Worked'), 'The step reports its work: ' + lastStepMessage(run));
		Assert.isTrue(run.kern__DurationMs__c >= BUSY_TEST_MILLISECONDS, 'The step worked at least its budget, worked ' + run.kern__DurationMs__c);
	}

	/**
	 * @description A leaf ends the way its outcome says: a plain failure, a permanent one, or a narrated completion.
	 */
	@IsTest
	private static void shouldEndALeafTheWayItsOutcomeSays()
	{
		Test.startTest();
		Id failedId = kern.UTIL_AsyncChain.newChain('Volume_OutcomeTest')
				.withInitialContext(SubscriberChainSteps.KEY_VOLUME_OUTCOME, SubscriberChainSteps.OUTCOME_FAIL)
				.withInitialContext(SubscriberChainSteps.KEY_VOLUME_ORDINAL, 8)
				.then(new SubscriberChainSteps.OutcomeStep())
				.execute();
		Id permanentId = kern.UTIL_AsyncChain.newChain('Volume_OutcomeTest')
				.withInitialContext(SubscriberChainSteps.KEY_VOLUME_OUTCOME, SubscriberChainSteps.OUTCOME_FAIL_PERMANENTLY)
				.withInitialContext(SubscriberChainSteps.KEY_VOLUME_ORDINAL, 16)
				.then(new SubscriberChainSteps.OutcomeStep())
				.execute();
		Id narratedId = kern.UTIL_AsyncChain.newChain('Volume_OutcomeTest')
				.withInitialContext(SubscriberChainSteps.KEY_VOLUME_ORDINAL, 3)
				.then(new SubscriberChainSteps.NarratingStep())
				.execute();
		Test.stopTest();

		Assert.areEqual('Failed', readRun(failedId).kern__Status__c, 'A plain failure ends Failed');
		Assert.isTrue(readRun(failedId).kern__ErrorMessage__c.contains('did not balance'), 'The failure reads like a business message');
		Assert.isTrue(readRun(permanentId).kern__StepLog__c.contains('"permanentFailure":true'), 'A permanent failure is marked permanent');
		Assert.areEqual('Completed', readRun(narratedId).kern__Status__c, 'The narrating step completes');
		Assert.areEqual('Validated account batch 3 against the ledger', lastStepMessage(readRun(narratedId)), 'The narrating step names its batch');
	}

	/**
	 * @description The retrying failure step declares a strategy and keeps failing; every retry hop runs inside the
	 * test, so the run ends with its retries exhausted and the last attempt's message on the row.
	 */
	@IsTest
	private static void shouldDeclareARetryStrategyAndKeepFailing()
	{
		Assert.isNotNull(new SubscriberChainSteps.RetryingFailureStep().createRetryStrategy(), 'The step declares a retry strategy');

		Test.startTest();
		Id executionId = kern.UTIL_AsyncChain.newChain('Volume_RetryTest')
				.then(new SubscriberChainSteps.RetryingFailureStep())
				.execute();
		Test.stopTest();

		kern__AsyncChainExecution__c run = readRun(executionId);
		Assert.areEqual('Failed', run.kern__Status__c, 'The run ends failed once its retries are spent: ' + run.kern__ErrorMessage__c);
		Assert.areEqual('RetriesExhausted', run.kern__FailureCategory__c, 'The failure is categorised as exhausted retries: ' + run.kern__ErrorMessage__c);
		Assert.isFalse(run.kern__ErrorMessage__c.endsWith('attempt 1'), 'The last attempt was not the first: ' + run.kern__ErrorMessage__c);
	}
}
