// SPDX-License-Identifier: BUSL-1.1
/**
 * @description A container for shared global interfaces used by the async chain orchestration framework.
 * Subscribers implement these interfaces to define chain step logic and conditional branching.
 *
 * @see UTIL_AsyncChain
 *
 * @author Jason van Beukering
 *
 * @group Async
 *
 * @date April 2026, May 2026
 *
 * @since 1.0
 *
 * @example
 * ```apex
 * public class MyStep implements IF_Chain.Step
 * {
 *     public UTIL_AsyncChain.StepResult work(UTIL_AsyncChain.ChainContext context)
 *     {
 *         context.put('result', 'done');
 *         return UTIL_AsyncChain.succeeded('Step completed');
 *     }
 * }
 * ```
 */
@SuppressWarnings('PMD.AvoidGlobalModifier')
global inherited sharing class IF_Chain
{
	/**
	 * @description Interface for defining the business logic of a single chain step.
	 * Each step receives a shared context and returns a result indicating success or failure.
	 *
	 * @since 1.0
	 */
	global interface Step
	{
		/**
		 * @description Executes the step's business logic within the chain.
		 *
		 * @param context Shared chain context for reading/writing state between steps.
		 *
		 * @return StepResult indicating success or failure of the step.
		 *
		 * @since 1.0
		 */
		UTIL_AsyncChain.StepResult work(UTIL_AsyncChain.ChainContext context);
	}
}