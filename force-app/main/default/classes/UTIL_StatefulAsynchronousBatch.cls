// SPDX-License-Identifier: Apache-2.0
/**
 * @description The batch that runs processor logic with a finish step (logic that implements IF_Async.Finishable).
 * UTIL_AdaptiveAsynchronousProcessor starts it in place of itself under BATCH, only for such logic.
 *
 * It keeps its values from one chunk to the next (`Database.Stateful`). A chunk is one group of items the batch handles
 * at a time. Because the values are kept, finish sees the values execute built. It calls finish once, after the last
 * chunk, and only when no chunk failed. When a chunk failed it writes one warning instead. As the batch's entry point
 * it runs with sharing, which covers only its read of its own job row; the processor it holds runs your logic without
 * sharing, as it does for every other batch.
 *
 * Keeping values means the platform saves this batch, and the processor it holds, after every chunk. To keep that
 * small, start clears the processor's list of items once it has handed the items to the platform. Logic without a
 * finish step runs as the processor itself, which does not keep its values, so it does not pay this cost.
 *
 * The platform names this class on the batch's job row. TRG_LogBatchApexError files a failure of this batch under
 * UTIL_AdaptiveAsynchronousProcessor, so it sits beside the entry the processor writes for the same failure.
 *
 * @see UTIL_AdaptiveAsynchronousProcessor
 * @see TRG_LogBatchApexError
 * @see SEL_AsyncApexJob
 * @see UTIL_AsynchronousJobLauncher_TEST
 *
 * @author Jason van Beukering
 *
 * @group Async Processing
 *
 * @date November 2026
 */
public inherited sharing class UTIL_StatefulAsynchronousBatch implements
				Database.AllowsCallouts,
				Database.Batchable<Object>,
				Database.RaisesPlatformEvents,
				Database.Stateful
{
	/**
	 * @description The step name added to the processor's class name for the warning written when finish is skipped.
	 */
	private static final String FINISH_LOCATION_SUFFIX = '/finish';

	/**
	 * @description The processor whose logic this batch runs, kept from one chunk to the next.
	 */
	private final UTIL_AdaptiveAsynchronousProcessor processor;

	/**
	 * @description Holds the processor whose logic this batch runs.
	 *
	 * @param processor The processor to run. Its logic implements IF_Async.Finishable.
	 */
	public UTIL_StatefulAsynchronousBatch(UTIL_AdaptiveAsynchronousProcessor processor)
	{
		this.processor = processor;
	}

	/**
	 * @description Hands the platform the items to process, then clears the processor's own list of items, so the items
	 * are not saved again after every chunk. The list handed to the platform is not changed.
	 *
	 * @param context The BatchableContext provided by the platform.
	 *
	 * @return The items for the batch: the query's records, or the list the processor was given.
	 */
	public Iterable<Object> start(Database.BatchableContext context)
	{
		Iterable<Object> items = processor.start(context);
		processor.clearItemsToProcess();
		return items;
	}

	/**
	 * @description Processes one chunk of items through the processor.
	 *
	 * @param context The BatchableContext provided by the platform.
	 * @param items The chunk of items to process.
	 */
	public void execute(Database.BatchableContext context, Iterable<Object> items)
	{
		processor.execute(context, items);
	}

	/**
	 * @description Reads the batch's job row. When any chunk failed, it writes one warning saying how many chunks failed
	 * out of how many, linked to the job, and does not call finish. Otherwise it calls the logic's finish.
	 *
	 * @param context The BatchableContext provided by the platform.
	 */
	public void finish(Database.BatchableContext context)
	{
		AsyncApexJob job = new SEL_AsyncApexJob().findByIds(new List<Id> {context.getJobId()})[0];
		Integer failedChunkCount = job.NumberOfErrors ?? 0;

		if(failedChunkCount > 0)
		{
			LOG_Builder.build()
					.warn(String.format(System.Label.AsyncProcessor_FinishSkipped, new List<Object> {String.valueOf(failedChunkCount), String.valueOf(job.TotalJobItems)}))
					.forRecord(context.getJobId())
					.emitAt(UTIL_System.getRuntimeTypeName(processor) + FINISH_LOCATION_SUFFIX);
			return;
		}

		processor.finish(context);
	}
}
