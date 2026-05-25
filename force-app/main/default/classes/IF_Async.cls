// SPDX-License-Identifier: BUSL-1.1
/**
 * @description A container for shared global interfaces used by the asynchronous framework.
 *
 * @author Jason van Beukering
 *
 * @group Async Processing
 *
 * @date September 2025, May 2026
 *
 * @since 1.0
 *
 * @example
 * ```apex
 * public class MyProcessor implements IF_Async.Processable
 * {
 *     public void execute(List<Object> items)
 *     {
 *         // process items
 *     }
 * }
 * ```
 */
@SuppressWarnings('PMD.AvoidGlobalModifier')
global inherited sharing class IF_Async
{
	/**
	 * @description Enum defining different asynchronous execution strategies.
	 *
	 * @since 1.0
	 */
	global enum AsynchronousExecutionStrategy
	{
		/**
		 * @description Automatically decide between parallel, chainable, or batch based on data size and limits.
		 */
		AUTO,
		/**
		 * @description Force batch execution regardless of data size.
		 */
		BATCH,
		/**
		 * @description Force chainable queueable execution (single parent with chained children).
		 */
		CHAINABLE,
		/**
		 * @description Force parallel queueable execution (multiple queueables enqueued simultaneously).
		 */
		PARALLEL_QUEUEABLES
	}

	/**
	 * @description Interface for defining the core processing logic to be executed by an asynchronous job.
	 *
	 * @since 1.0
	 */
	global interface Processable
	{
		/**
		 * @description Executes the business logic on a list of items.
		 *
		 * @param items The list of objects to process in the current transaction.
		 *
		 * @since 1.0
		 */
		void execute(List<Object> items);
	}

	/**
	 * @description Optional interface for defining finalizer logic that runs after all data is processed.
	 * Implement this for cleanup or notification actions.
	 *
	 * @since 1.0
	 */
	global interface Finishable
	{
		/**
		 * @description Called once after all chunks are processed, for cleanup or notifications.
		 *
		 * @param context The BatchableContext providing job details, such as the job ID.
		 *
		 * @since 1.0
		 */
		void finish(Database.BatchableContext context);
	}
}