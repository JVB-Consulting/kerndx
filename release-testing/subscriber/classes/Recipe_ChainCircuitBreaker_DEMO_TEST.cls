// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Proof tests for the circuit-breaker composition pattern: a closed breaker lets
 * the chain run, handler-recorded outcomes are observable on the shared circuit, and an open
 * breaker stops the launch before any run row exists.
 *
 * @see Recipe_ChainCircuitBreaker_DEMO
 *
 * @author your.name@company.com
 *
 * @group Async
 *
 * @date August 2026
 */
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest(seeAllData=false)
private class Recipe_ChainCircuitBreaker_DEMO_TEST
{
	/**
	 * @description Chain name the DEMO launch point uses; queried to prove presence/absence of runs.
	 */
	private static final String CHAIN_NAME = 'Order Export';

	/**
	 * @description Verifies a closed breaker lets the chain start and complete, and that the
	 * completion handler's recordSuccess() is observable from the test context afterwards.
	 * Witness: recordSuccess() on a closed breaker resets the accumulated failure count
	 * (UTIL_CircuitBreaker closed-state semantics), so a failure seeded before the run must be
	 * gone after it — proving the handler's recording crossed the drained queueable
	 * transaction boundary via Platform Cache.
	 */
	@IsTest
	private static void shouldCompleteChainAndRecordSuccessWhenCircuitClosed()
	{
		kern.UTIL_CircuitBreaker.Breaker breaker = Recipe_ChainCircuitBreaker_DEMO.monitorCircuit();
		breaker.reset();
		breaker.recordFailure();
		Assert.areEqual(1, breaker.getMetrics().failureCount, 'The seeded failure should be counted before the run');

		Test.startTest();
		String executionId = Recipe_ChainCircuitBreaker_DEMO.launch();
		Test.stopTest();

		Assert.isNotNull(executionId, 'A closed breaker should let the chain start');

		kern__AsyncChainExecution__c execution = queryExecution(executionId);
		Assert.areEqual('Completed', execution.kern__Status__c, 'Chain should complete');
		Assert.areEqual(1, execution.kern__CompletedSteps__c, 'The export step should complete');

		kern.UTIL_CircuitBreaker.Metrics metrics = Recipe_ChainCircuitBreaker_DEMO.monitorCircuit().getMetrics();
		Assert.areEqual(kern.UTIL_CircuitBreaker.State.CLOSED, metrics.state, 'Breaker should stay closed after a success');
		Assert.areEqual(0, metrics.failureCount,
				'recordSuccess() from the completion handler should have reset the seeded failure count; got: ' + metrics.failureCount);
	}

	/**
	 * @description Verifies the configured threshold is honoured at every touch point: three
	 * failed chains open the circuit, and the next launch is gated. This is the witness for the
	 * pattern's central claim; it only holds because the handlers use the same configured
	 * monitor as the launch gate.
	 */
	@IsTest
	private static void shouldOpenCircuitAfterThreeFailedChains()
	{
		Recipe_ChainCircuitBreaker_DEMO.monitorCircuit().reset();

		Test.startTest();
		for(Integer index = 0; index < 3; index++)
		{
			kern.UTIL_AsyncChain.newChain(CHAIN_NAME)
					.then(new FailingExportStep())
					.onError(new Recipe_ChainCircuitBreaker_DEMO.RecordExportFailure())
					.execute();
		}
		Test.stopTest();

		kern.UTIL_CircuitBreaker.Metrics metrics = Recipe_ChainCircuitBreaker_DEMO.monitorCircuit().getMetrics();
		Assert.areEqual(kern.UTIL_CircuitBreaker.State.OPEN, metrics.state,
				'Three failed chains should open the circuit at the configured threshold');
		Assert.isNull(Recipe_ChainCircuitBreaker_DEMO.launch(), 'An open circuit should gate the next launch');

		Recipe_ChainCircuitBreaker_DEMO.monitorCircuit().reset();
	}

	/**
	 * @description Verifies the failure side of the composition: a failing chain routes through
	 * the pattern's onError handler, whose recordFailure() is observable on the shared circuit.
	 */
	@IsTest
	private static void shouldRecordFailureThroughErrorHandler()
	{
		Recipe_ChainCircuitBreaker_DEMO.monitorCircuit().reset();

		Test.startTest();
		String executionId = kern.UTIL_AsyncChain.newChain(CHAIN_NAME)
				.then(new FailingExportStep())
				.onError(new Recipe_ChainCircuitBreaker_DEMO.RecordExportFailure())
				.execute();
		Test.stopTest();

		kern__AsyncChainExecution__c execution = queryExecution(executionId);
		Assert.areEqual('Failed', execution.kern__Status__c, 'The chain should fail');

		kern.UTIL_CircuitBreaker.Metrics metrics = Recipe_ChainCircuitBreaker_DEMO.monitorCircuit().getMetrics();
		Assert.isTrue(metrics.failureCount >= 1,
				'recordFailure() from the error handler should be visible on the shared circuit; got: ' + metrics.failureCount);
	}

	/**
	 * @description Verifies the launch gate: with the circuit forced open, launch() returns null
	 * and no chain run row is created.
	 */
	@IsTest
	private static void shouldSkipLaunchWhenCircuitOpen()
	{
		kern.UTIL_CircuitBreaker.Breaker breaker = Recipe_ChainCircuitBreaker_DEMO.monitorCircuit();
		breaker.reset();
		breaker.forceOpen();

		Test.startTest();
		String executionId = Recipe_ChainCircuitBreaker_DEMO.launch();
		Test.stopTest();

		Assert.isNull(executionId, 'An open breaker should stop the launch');

		List<kern__AsyncChainExecution__c> runs =
		[
				SELECT Id
				FROM kern__AsyncChainExecution__c
				WHERE kern__ChainName__c = :CHAIN_NAME
		];
		Assert.areEqual(0, runs.size(), 'No run row should exist for a gated launch');

		breaker.reset();
	}

	/**
	 * @description Failing stand-in for the export work, used to drive the onError handler.
	 */
	private with sharing class FailingExportStep extends kern.UTIL_AsyncChain.ChainStep
	{
		/**
		 * @description Fails deliberately.
		 *
		 * @param context The shared chain context.
		 *
		 * @return A failed result.
		 */
		public override kern.UTIL_AsyncChain.StepResult work(kern.UTIL_AsyncChain.ChainContext context)
		{
			return kern.UTIL_AsyncChain.failed('Deliberate export failure for the breaker proof');
		}
	}

	/**
	 * @description Queries an AsyncChainExecution__c record by Id.
	 *
	 * @param executionId The execution record Id.
	 *
	 * @return The queried execution record.
	 */
	private static kern__AsyncChainExecution__c queryExecution(String executionId)
	{
		return
		[
				SELECT kern__Status__c,
						kern__CompletedSteps__c,
						kern__ErrorMessage__c
				FROM kern__AsyncChainExecution__c
				WHERE Id = :executionId
		];
	}
}
