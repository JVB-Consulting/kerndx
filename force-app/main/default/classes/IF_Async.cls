// SPDX-License-Identifier: Apache-2.0
/**
 * @description A container for shared global interfaces used by the asynchronous framework.
 *
 * @author Jason van Beukering
 *
 * @group Async Processing
 *
 * @date September 2025, November 2026
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
		 * @description Force parallel queueable execution (multiple queueables enqueued simultaneously). A processor that
		 * implements Finishable cannot use it, because its finish method would run once for every job: a launch that forces
		 * it for such a processor is refused, and AUTO never picks it for one.
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
	 * @description Optional interface for logic that runs once, after all items are processed. Implement it for cleanup,
	 * a summary or a notification.
	 *
	 * What finish promises:
	 * - It is called once, after the last chunk (a chunk is one group of items the job handles at a time).
	 * - It is called only when every chunk ran without throwing an exception. When a chunk failed, finish is not called,
	 * and the job's log has an error entry for the failed chunk. Under BATCH, the log also has one warning that finish
	 * was skipped. Under CHAINABLE, the chain stops at the job that threw, so finish is never reached. If you need to do
	 * work when a chunk fails, do it in execute.
	 * - A processor that catches its own errors in execute and goes on counts as having succeeded.
	 * - It sees the values your execute built, such as a count or a list of record Ids, as fields of your class.
	 *
	 * To keep those values from one chunk to the next, a batch saves your whole class after every chunk. Keep those
	 * fields small (a count or a list of Ids, not whole records) and mark any cache `transient` so it is not saved.
	 *
	 * Salesforce cannot save some values between chunks, such as a compiled `Pattern`, a `Matcher`, an `HttpRequest` or a
	 * describe result. If a field of your class that is not `static` holds one of them under BATCH, the batch can fail.
	 * Build such a value inside `execute`, or mark the field `transient`.
	 *
	 * Under BATCH, `context.getJobId()` in finish is the batch job. Under CHAINABLE it is the last job of the chain.
	 *
	 * A processor that implements this interface cannot run as PARALLEL_QUEUEABLES. AUTO never picks it for one, and a
	 * request that forces it is refused: `UTIL_AsynchronousJobLauncher.process` throws an IllegalArgumentException and
	 * no job is started.
	 *
	 * @since 1.0
	 */
	global interface Finishable
	{
		/**
		 * @description Called once, after the last chunk, and only when every chunk ran without throwing an exception.
		 * It sees the values your execute built.
		 *
		 * @param context The BatchableContext providing job details, such as the job ID.
		 *
		 * @since 1.0
		 */
		void finish(Database.BatchableContext context);
	}
}