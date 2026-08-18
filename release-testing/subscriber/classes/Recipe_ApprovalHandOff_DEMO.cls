// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Pause-for-approval composition pattern, first leg: the chain ends at the human
 * gate, and the waiting record is the durable state AND the join between the legs. Each leg
 * keeps its own correlation identifier (a chain run owns its correlation exclusively); the
 * record carries the story across the gap. Proof artifact for the Async Processing guide's
 * "Pausing for an approval: two chains and a hand-off" pattern.
 *
 * @see Recipe_ApprovalContinuation_DEMO
 * @see Recipe_ApprovalHandOff_DEMO_TEST
 *
 * @author your.name@company.com
 *
 * @group Async
 *
 * @date August 2026
 */
public with sharing class Recipe_ApprovalHandOff_DEMO
{
	/**
	 * @description Starts the preparation leg; the chain finishes at the approval gate. Store
	 * the returned run Id on the waiting record if you want to navigate back to this leg later.
	 *
	 * @param recordId The record awaiting approval.
	 *
	 * @return The chain run record Id.
	 */
	public static String startFirstLeg(Id recordId)
	{
		return kern.UTIL_AsyncChain.newChain('Order Approval - Preparation')
				.withInitialContext('recordId', recordId)
				.then(new PrepareStep())
				.execute();
	}

	/**
	 * @description The work done before the human decision; stands in for your real preparation.
	 */
	public with sharing class PrepareStep extends kern.UTIL_AsyncChain.ChainStep
	{
		/**
		 * @description Performs the preparation work and ends the leg at the gate.
		 *
		 * @param context The shared chain context.
		 *
		 * @return A succeeded result noting the wait.
		 */
		public override kern.UTIL_AsyncChain.StepResult work(kern.UTIL_AsyncChain.ChainContext context)
		{
			return kern.UTIL_AsyncChain.succeeded('Prepared; waiting on approval');
		}
	}

	/**
	 * @description The work done after the human decision; stands in for your real continuation.
	 */
	public with sharing class ContinueStep extends kern.UTIL_AsyncChain.ChainStep
	{
		/**
		 * @description Performs the continuation work.
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
}
