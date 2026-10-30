// SPDX-License-Identifier: Apache-2.0
/**
 * @description Circuit-breaker composition pattern: a launch point gates chain starts on
 * kern.UTIL_CircuitBreaker state, and the chain's completion and failure handlers record
 * outcomes so failures observed in one transaction protect the next. Proof artifact for the
 * Async Processing guide's "Protecting a struggling integration with a circuit breaker"
 * pattern — the guide fence mirrors this class.
 *
 * @see Recipe_ChainCircuitBreaker_DEMO_TEST
 *
 * @author your.name@company.com
 *
 * @group Async
 *
 * @date August 2026
 */
public with sharing class Recipe_ChainCircuitBreaker_DEMO
{
	/**
	 * @description Breaker circuit id shared by the launch gate and both outcome handlers.
	 */
	public static final String CIRCUIT_NAME = 'OrderExport';

	/**
	 * @description Builds the identically configured monitor every touch point uses. Breaker
	 * thresholds live on each monitor() instance (only the counts and state are shared), so the
	 * launch gate and both handlers must apply the same configuration for it to mean anything.
	 *
	 * @return The configured breaker for the shared circuit.
	 */
	public static kern.UTIL_CircuitBreaker.Breaker monitorCircuit()
	{
		return kern.UTIL_CircuitBreaker.monitor(CIRCUIT_NAME)
				.withFailureThreshold(3)
				.withTimeout(120);
	}

	/**
	 * @description Starts the export chain when the breaker allows it; the else-branch is the
	 * caller's own policy decision.
	 *
	 * @return The chain run record Id, or null when the circuit is open.
	 */
	public static String launch()
	{
		if(!monitorCircuit().allowRequest())
		{
			return null; // you own this branch: skip, park the work, or surface it to the user
		}
		return kern.UTIL_AsyncChain.newChain('Order Export')
				.then(new ExportStep())
				.onError(new RecordExportFailure())
				.onComplete(new RecordExportSuccess())
				.execute();
	}

	/**
	 * @description The work being protected; stands in for your real export step.
	 */
	public with sharing class ExportStep extends kern.UTIL_AsyncChain.ChainStep
	{
		/**
		 * @description Performs the export work.
		 *
		 * @param context The shared chain context.
		 *
		 * @return A succeeded result.
		 */
		public override kern.UTIL_AsyncChain.StepResult work(kern.UTIL_AsyncChain.ChainContext context)
		{
			return kern.UTIL_AsyncChain.succeeded();
		}
	}

	/**
	 * @description Chain failure handler: counts the failure against the circuit.
	 */
	public with sharing class RecordExportFailure extends kern.UTIL_AsyncChain.ChainStep
	{
		/**
		 * @description Records a failure outcome on the shared circuit.
		 *
		 * @param context The shared chain context.
		 *
		 * @return A succeeded result (the handler itself must not fail the chain again).
		 */
		public override kern.UTIL_AsyncChain.StepResult work(kern.UTIL_AsyncChain.ChainContext context)
		{
			monitorCircuit().recordFailure();
			return kern.UTIL_AsyncChain.succeeded();
		}
	}

	/**
	 * @description Chain completion handler: counts the success against the circuit.
	 */
	public with sharing class RecordExportSuccess extends kern.UTIL_AsyncChain.ChainStep
	{
		/**
		 * @description Records a success outcome on the shared circuit.
		 *
		 * @param context The shared chain context.
		 *
		 * @return A succeeded result.
		 */
		public override kern.UTIL_AsyncChain.StepResult work(kern.UTIL_AsyncChain.ChainContext context)
		{
			monitorCircuit().recordSuccess();
			return kern.UTIL_AsyncChain.succeeded();
		}
	}
}
