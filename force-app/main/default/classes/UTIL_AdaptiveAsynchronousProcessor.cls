// SPDX-License-Identifier: Apache-2.0
/**
 * @description Internal processor for asynchronous execution, automatically switching between Queueable and Batchable contexts.
 * This class is a self-contained engine that processes data based on logic provided via the Processable interface.
 *
 * This class should not be instantiated directly. Use UTIL_AsynchronousJobLauncher.process() as the
 * public entry point for all asynchronous processing needs. The launcher handles delayed execution,
 * request configuration, and proper processor instantiation.
 *
 * @see UTIL_AsynchronousJobLauncher
 * @see IF_Async
 * @see UTIL_AsynchronousJobLauncher_TEST
 *
 * @author Jason van Beukering
 *
 * @group Async Processing
 *
 * @date September 2025, October 2026
 */
@SuppressWarnings('PMD.CognitiveComplexity,PMD.CyclomaticComplexity')
public without sharing class UTIL_AdaptiveAsynchronousProcessor implements
				Database.AllowsCallouts,
				Database.Batchable<Object>,
				Database.RaisesPlatformEvents,
				INT_Process
{

	/**
	 * @description Set this value to true in an unit test to ensure we test that events are processed via batch
	 * to simulate scenarios where query governor limits will be breached
	 */
	@TestVisible
	private static Boolean simulateQueryLimits = false;

	/**
	 * @description Flag to simulate Queueable limits for testing purposes.
	 */
	@TestVisible
	private static Boolean simulateQueueableLimits = false;

	/**
	 * @description The scope sizes at which the platform's retrieve chunk changes: a scope up to the first value reads
	 * chunks of that size, up to the second reads chunks of the second, and anything above reads chunks of the last.
	 */
	private static final List<Integer> RETRIEVE_CHUNK_SIZES = new List<Integer> {100, 400, 2000};

	/**
	 * @description Every scope size that divides its retrieve chunk exactly, in ascending order: the divisors of 100 for
	 * a chunk of 100, then the sizes above 100 that divide a chunk of 400 or 2,000.
	 */
	private static final List<Integer> FITTING_SCOPE_SIZES = new List<Integer> {1, 2, 4, 5, 10, 20, 25, 50, 100, 200, 400, 500, 1000, 2000};

	/**
	 * @description Context key naming the retrieve chunk a batch reads at its scope size.
	 */
	private static final String CONTEXT_RETRIEVE_CHUNK = 'retrieveChunk';

	/**
	 * @description Context key naming the scope size a batch was launched with.
	 */
	private static final String CONTEXT_SCOPE_SIZE = 'scopeSize';

	/**
	 * @description Context key listing the scope sizes nearest to the launched one that fit their chunk.
	 */
	private static final String CONTEXT_FITTING_SCOPE_SIZES = 'fittingScopeSizes';

	/**
	 * @description Fingerprint prefix of the scope-size warning, so a job launched many times with the same size folds
	 * into one problem in the Log Console instead of one row per launch.
	 */
	private static final String FINGERPRINT_SCOPE_SIZE = 'batch-scope-size-does-not-fit:';

	/**
	 * @description Text of the scope-size warning: the size, the chunk of records the platform reads, the short run each
	 * chunk leaves, and the sizes that fit.
	 */
	private static final String MESSAGE_SCOPE_SIZE_FORMAT =
			'Batch size {0} does not divide the chunk of {1} records the platform reads: every chunk ends with a short run of {2} records, ' +
			'so the job makes more execute() calls than it needs. Sizes that fit: {3}.';

	/**
	 * @description Stores the user's processing logic
	 */
	private IF_Async.Processable processorLogic;

	/**
	 * @description The queryable defining the query criteria for retrieving records.
	 */
	private IF_Queryable queryable;

	/**
	 * @description The Queueable wrapper instance for handling Queueable execution.
	 * Initialized when Queueable processing is selected.
	 */
	@TestVisible
	private AsyncProcessorQueueable queueable;

	/**
	 * @description Configuration object holding performance settings for the processor.
	 * Defaults to a new `DTO_ProcessSettings` instance with platform limit defaults.
	 */
	@TestVisible
	private DTO_ProcessSettings processSettings = new DTO_ProcessSettings();

	/**
	 * @description List of objects to be processed, accessible by subclasses in `innerExecute`.
	 * Populated automatically based on the query or list provided to `initialise`.
	 */
	private List<Object> itemsToProcess
	{
		get
		{
			if(itemsToProcess == null)
			{
				itemsToProcess = new List<Object>();
			}
			return itemsToProcess;
		}
		set;
	}

	/**
	 * @description The ID of the first asynchronous job (Queueable or Batch) that was started.
	 * Used to monitor job progress via AsyncApexJob queries.
	 *
	 * @example
	 * Monitoring job progress:
	 * ```apex
	 * String jobId = processor.run();
	 * AsyncApexJob job = [SELECT Status, NumberOfErrors, JobItemsProcessed, TotalJobItems
	 * FROM AsyncApexJob WHERE Id = :jobId];
	 * // job.Status tells you how far the job has come, for example 'Processing' or 'Completed'
	 * ```
	 */
	private Id asyncJobId {get; set;}

	/**
	 * @description Constructor to provide the processing logic.
	 *
	 * @param processorLogic An implementation of Processable.
	 */
	public UTIL_AdaptiveAsynchronousProcessor(IF_Async.Processable processorLogic)
	{
		this();
		this.processorLogic = processorLogic;
		processSettings.processableClassName = resolveProcessableClassName();
	}

	/**
	 * @description Default constructor required for cloning in parallel queueables.
	 */
	public UTIL_AdaptiveAsynchronousProcessor()
	{
		itemsToProcess = new List<Object>();
	}

	/**
	 * @description Implements the processing logic by delegating to the provided interface.
	 *
	 * @param items The list of objects to process in this execution.
	 */
	private void innerExecute(List<Object> items)
	{
		if(processorLogic != null)
		{
			processorLogic.execute(items);
		}
	}

	/**
	 * @description Overrides the finish method to delegate to the Finishable interface, if implemented.
	 *
	 * @param context The BatchableContext provided by the platform.
	 */
	public void finish(Database.BatchableContext context)
	{
		if(processorLogic instanceof IF_Async.Finishable)
		{
			((IF_Async.Finishable)processorLogic).finish(context);
		}
	}

	/**
	 * @description Initializes the processor with an IF_Queryable to retrieve records.
	 * The query is executed when processing begins.
	 *
	 * @param queryable The IF_Queryable defining the query criteria.
	 *
	 * @return The INT_Process instance for method chaining.
	 */
	public INT_Process initialise(IF_Queryable queryable)
	{
		return initialise(queryable, null);
	}

	/**
	 * @description Initializes the processor with a list of objects.
	 * Use for in-memory items to avoid querying.
	 *
	 * @param items The list of objects to process.
	 *
	 * @return The INT_Process instance for method chaining.
	 */
	public INT_Process initialise(List<Object> items)
	{
		return initialise(null, items);
	}

	/**
	 * @description Initializes the processor, populates items, and determines the execution strategy.
	 *
	 * @param queryable The IF_Queryable defining the query criteria (optional).
	 * @param items The list of objects (optional).
	 *
	 * @return The configured INT_Process instance.
	 */
	private INT_Process initialise(IF_Queryable queryable, List<Object> items)
	{
		this.queryable = queryable;
		itemsToProcess = items;

		determineCorrectExecutionStrategy();

		if
		(
				processSettings.executionStrategy == IF_Async.AsynchronousExecutionStrategy.CHAINABLE ||
				processSettings.executionStrategy == IF_Async.AsynchronousExecutionStrategy.PARALLEL_QUEUEABLES
		)
		{
			if(queryable != null)
			{
				itemsToProcess = queryable.toList();
			}

			queueable = new AsyncProcessorQueueable(this);

			return queueable;
		}

		return this;
	}

	/**
	 * @description Determines which execution strategy to use based on configuration and context.
	 */
	private void determineCorrectExecutionStrategy()
	{
		if(processSettings.executionStrategy != IF_Async.AsynchronousExecutionStrategy.AUTO)
		{
			return;
		}

		//Default to batch unless additional parameters allow queueable
		processSettings.executionStrategy = IF_Async.AsynchronousExecutionStrategy.BATCH;

		//If we cannot execute queries because of limits, deflect automatically to default (which is batch)
		if(queryable != null && (simulateQueryLimits || !canExecuteQueries()))
		{
			return;
		}

		Integer availableQueueables = simulateQueueableLimits ? 1 : UTIL_Limits.queueableJobs().remaining();

		if(availableQueueables > 0)
		{
			//If running in an async context (e.g., another Queueable, Batch, or Future),
			//we can (potentially) enqueue one more job, so we must use the chainable strategy.
			if(System.isQueueable() || System.isFuture() || System.isBatch())
			{
				processSettings.executionStrategy = IF_Async.AsynchronousExecutionStrategy.CHAINABLE;
				return;
			}

			//If running in a synchronous context, decide between parallel, chainable (else the default batch will be used)
			Integer itemCount = queryable != null ? queryable.count() : itemsToProcess.size();

			//If the item count exceeds the configured batch threshold, always use Batch Apex.
			if(itemCount <= processSettings.limitAtWhichToBatch)
			{
				Integer numQueueablesNeeded = (Integer)Math.ceil((Decimal)itemCount / Math.max(1, getQueueableJobSize()));

				if(numQueueablesNeeded <= availableQueueables)
				{
					//We have enough slots for full parallelism - this is the fastest option.
					processSettings.executionStrategy = IF_Async.AsynchronousExecutionStrategy.PARALLEL_QUEUEABLES;
				}
				else
				{
					//We don't have enough slots for parallel, but we have at least one.
					//Start a chain of Queueables. This is more efficient than Batch for this scenario.
					processSettings.executionStrategy = IF_Async.AsynchronousExecutionStrategy.CHAINABLE;
				}
			}
		}
	}

	/**
	 * @description Will return whether a query can be run to return the expected number of rows looking at DML limits
	 *
	 * @return True if the queries can be executed
	 */
	private static Boolean canExecuteQueries()
	{
		return UTIL_Limits.soqlQueries().remaining() > 0 && UTIL_Limits.soqlQueryRows().remaining() >= 2;
	}

	/**
	 * @description Starts the asynchronous processing based on the strategy determined during initialization.
	 *
	 * @return The ID of the first started asynchronous job.
	 */
	public Id run()
	{
		try
		{
			switch on processSettings.executionStrategy
			{
				when PARALLEL_QUEUEABLES
				{
					return executeParallelQueueables();
				}
				when CHAINABLE
				{
					return executeChainableQueueable();
				}
				when else
				{
					warnWhenScopeSizeDoesNotFit(processSettings.batchJobSize);
					return Database.executeBatch(this, processSettings.batchJobSize);
				}
			}
		}
		catch(Exception error)
		{
			LOG_Builder.build().error(error).at(UTIL_System.getRuntimeTypeName(this) + '/run').emit();
			throw error;
		}
	}

	/**
	 * @description Works out the retrieve chunk the platform reads for a query-backed batch at the given scope size: 100
	 * up to a scope of 100, 400 up to 400, 2,000 above that.
	 *
	 * @param scopeSize The scope size the batch is launched with.
	 *
	 * @return The chunk size.
	 */
	public static Integer computeRetrieveChunk(Integer scopeSize)
	{
		for(Integer chunkSize : RETRIEVE_CHUNK_SIZES)
		{
			if(scopeSize <= chunkSize)
			{
				return chunkSize;
			}
		}
		return RETRIEVE_CHUNK_SIZES[RETRIEVE_CHUNK_SIZES.size() - 1];
	}

	/**
	 * @description Finds the scope sizes nearest to the given one that divide their retrieve chunk exactly: the largest
	 * fitting size below it and the smallest above it. At or below 100 a fitting size is a divisor of 100; above 100
	 * it is one of 200, 400, 500, 1,000 and 2,000.
	 *
	 * @param scopeSize The scope size the batch is launched with.
	 *
	 * @return One or two sizes in ascending order, never the given size itself.
	 */
	public static List<Integer> findFittingScopeSizesAround(Integer scopeSize)
	{
		Integer below = null;
		Integer above = null;
		for(Integer candidate : FITTING_SCOPE_SIZES)
		{
			if(candidate < scopeSize)
			{
				below = candidate;
			}
			else if(candidate > scopeSize)
			{
				above = candidate;
				break;
			}
		}

		List<Integer> nearest = new List<Integer>();
		if(below != null)
		{
			nearest.add(below);
		}
		if(above != null)
		{
			nearest.add(above);
		}
		return nearest;
	}

	/**
	 * @description Writes one WARN entry when a query-backed batch is launched with a scope size that does not
	 * divide its retrieve chunk, naming the size, the chunk, the short run each chunk leaves and the nearest sizes
	 * that fit. An in-memory batch is immune and gets no entry, and neither does a size above the platform's maximum,
	 * which the platform refuses with an error of its own. The entry is fingerprinted by processable and size, so
	 * repeated launches fold into one problem.
	 *
	 * @param scopeSize The scope size the batch is launched with.
	 */
	private void warnWhenScopeSizeDoesNotFit(Integer scopeSize)
	{
		if(queryable == null || scopeSize > UTIL_SObjectDescribe.MAXIMUM_BATCH_SIZE)
		{
			return;
		}
		Integer chunkSize = computeRetrieveChunk(scopeSize);
		Integer shortRun = Math.mod(chunkSize, scopeSize);
		if(shortRun == 0)
		{
			return;
		}
		String fittingSizesText = String.join(findFittingScopeSizesAround(scopeSize), UTIL_String.COMMA + UTIL_String.SPACE);

		LOG_Builder.build()
				.warn(String.format(MESSAGE_SCOPE_SIZE_FORMAT, new List<Object> {scopeSize, chunkSize, shortRun, fittingSizesText}))
				.withFingerprintInternal(FINGERPRINT_SCOPE_SIZE + processSettings.processableClassName + UTIL_String.COLON + scopeSize)
				.withContext(CONTEXT_SCOPE_SIZE, scopeSize)
				.withContext(CONTEXT_RETRIEVE_CHUNK, chunkSize)
				.withContext(CONTEXT_FITTING_SCOPE_SIZES, fittingSizesText)
				.emitAt(UTIL_System.getRuntimeTypeName(this) + '/run');
	}

	/**
	 * @description Applies performance configuration settings to the processor.
	 * Overrides default settings if provided.
	 *
	 * @param configuration The configuration object with performance settings.
	 *
	 * @return The INT_Process instance for method chaining.
	 */
	public INT_Process configure(DTO_ProcessSettings configuration)
	{
		processSettings = configuration;
		processSettings.processableClassName = resolveProcessableClassName();
		return this;
	}

	/**
	 * @description Resolves the class name of the processing logic this processor runs. That name is the key the
	 * settings use to find the `AsynchronousJobSetting__mdt` record configuring the batch size, so a subscriber
	 * names the record after the Processable class they wrote.
	 *
	 * @return The runtime class name of the processing logic, or null when no logic has been supplied yet.
	 */
	private String resolveProcessableClassName()
	{
		return processorLogic == null ? null : UTIL_System.getRuntimeTypeName(processorLogic);
	}

	/**
	 * @description Executes parallel queueable strategy - enqueues multiple queueables simultaneously.
	 *
	 * @return The ID of the first enqueued queueable.
	 */
	@SuppressWarnings('PMD.OperationWithLimitsInLoop')
	private Id executeParallelQueueables()
	{
		String firstJobId;

		for(List<Object> chunk : UTIL_List.partition(itemsToProcess, getQueueableJobSize()))
		{
			UTIL_AdaptiveAsynchronousProcessor clonedProcessor = (UTIL_AdaptiveAsynchronousProcessor)UTIL_System.getRuntimeType(this).newInstance();
			clonedProcessor.onClone(this);

			clonedProcessor.itemsToProcess = chunk;
			clonedProcessor.processSettings = processSettings;
			clonedProcessor.queueable = new AsyncProcessorQueueable(clonedProcessor);
			queueable.configure(processSettings);

			Id jobId = enqueueWithOptionalDelay(clonedProcessor.queueable);

			if(firstJobId == null)
			{
				firstJobId = jobId;
				asyncJobId = jobId;
			}
		}
		return firstJobId;
	}

	/**
	 * @description Executes chainable queueable strategy - enqueues single parent with chaining.
	 *
	 * @return The ID of the parent queueable.
	 */
	private Id executeChainableQueueable()
	{
		return enqueueWithOptionalDelay(queueable);
	}

	/**
	 * @description Enqueues a queueable job with optional asyncOptions.
	 *
	 * @param job The queueable job to enqueue.
	 *
	 * @return The job ID of the enqueued job.
	 */
	private Id enqueueWithOptionalDelay(Queueable job)
	{
		if(processSettings.asyncOptions != null)
		{
			return System.enqueueJob(job, processSettings.asyncOptions);
		}
		return System.enqueueJob(job);
	}

	/**
	 * @description Protected virtual method to allow subclasses to copy state to a cloned instance.
	 * Called after `Type.newInstance()` during parallel Queueable enqueuing.
	 *
	 * @param originalProcessor The original processor instance from which to copy state.
	 */
	private void onClone(UTIL_AdaptiveAsynchronousProcessor originalProcessor)
	{
		processorLogic = originalProcessor.processorLogic;
	}

	/**
	 * @description Batchable start method that provides the Iterable for batch processing.
	 *
	 * @param context The BatchableContext provided by the platform.
	 *
	 * @return The Iterable<Object> for the batch execution.
	 */
	public Iterable<Object> start(Database.BatchableContext context)
	{
		return queryable != null ? queryable.toQueryLocator() : (Iterable<Object>)itemsToProcess;
	}

	/**
	 * @description Batchable execute method that processes a chunk of items.
	 *
	 * @param context The BatchableContext provided by the platform.
	 * @param localItems The batch of objects to process.
	 */
	public void execute(Database.BatchableContext context, Iterable<Object> localItems)
	{
		try
		{
			innerExecute(cloneItems(localItems));
		}
		catch(Exception error)
		{
			LOG_Builder.build().error(error).at(UTIL_System.getRuntimeTypeName(this) + '/execute').emit();
			throw error;
		}
	}

	/**
	 * @description Returns the Queueable job size for processing.
	 *
	 * @return The number of items to process in each Queueable execution.
	 */
	private Integer getQueueableJobSize()
	{
		return processSettings.queueableJobSize = processSettings.queueableJobSize ?? (!itemsToProcess.isEmpty() ? itemsToProcess.size() : processSettings.batchJobSize);
	}

	/**
	 * @description Clones items to prevent modification of original objects during processing (if they are SObjects).
	 *
	 * @param sourceItems The list of items to clone.
	 *
	 * @return A new list with cloned items.
	 */
	private static List<Object> cloneItems(Iterable<Object> sourceItems)
	{
		List<Object> cloned = new List<Object>();

		for(Object item : sourceItems)
		{
			cloned.add(item instanceof SObject ? ((SObject)item).clone(true, true, false, false) : item);
		}

		return cloned;
	}

	/**
	 * @description Inner class that implements Queueable processing with chunking and error handling.
	 */
	private inherited sharing class AsyncProcessorQueueable implements Queueable, Finalizer, INT_Process, Database.AllowsCallouts, Database.RaisesPlatformEvents
	{
		/**
		 * @description The parent processor instance being wrapped for Queueable execution.
		 */
		private final UTIL_AdaptiveAsynchronousProcessor processor;

		/**
		 * @description Constructor for the Queueable wrapper.
		 *
		 * @param processor The parent processor instance to wrap.
		 */
		public AsyncProcessorQueueable(UTIL_AdaptiveAsynchronousProcessor processor)
		{
			this.processor = processor;
		}

		/**
		 * @description Applies configuration settings to the parent processor.
		 *
		 * @param configuration The configuration object with performance settings.
		 *
		 * @return The INT_Process instance for method chaining.
		 */
		public INT_Process configure(DTO_ProcessSettings configuration)
		{
			return processor.configure(configuration);
		}

		/**
		 * @description Starts the Queueable job by calling the parent processor's run method.
		 *
		 * @return The job ID of the started asynchronous process.
		 */
		public Id run()
		{
			return processor.run();
		}

		/**
		 * @description Executes the Queueable job, processing a chunk of items.
		 *
		 * @param context The QueueableContext provided by the platform.
		 */
		public void execute(QueueableContext context)
		{
			processor.asyncJobId = context.getJobId();

			System.attachFinalizer(this);

			// For chainable strategy, we chunk the items here.
			// Parallel strategy pre-chunks items before enqueuing.
			if(processor.processSettings.executionStrategy == IF_Async.AsynchronousExecutionStrategy.CHAINABLE)
			{
				List<Object> removedItems = removeExtraItemsToProcess();

				processor.innerExecute(cloneItems(processor.itemsToProcess));
				processor.itemsToProcess = removedItems;

				if(processor.itemsToProcess.isEmpty())
				{
					processor.finish(new QueueableToBatchableContext(context));
				}
			}
			else
			{
				processor.innerExecute(cloneItems(processor.itemsToProcess));
				processor.finish(new QueueableToBatchableContext(context));
			}
		}

		/**
		 * @description Finalizer method that handles errors and re-queues the job if necessary.
		 *
		 * @param context The FinalizerContext provided by the platform.
		 */
		public void execute(FinalizerContext context)
		{
			if(ParentJobResult.UNHANDLED_EXCEPTION.equals(context.getResult()))
			{
				logUnhandledException(context);
			}
			else if
			(
					!processor.itemsToProcess.isEmpty() &&
					processor.processSettings.executionStrategy == IF_Async.AsynchronousExecutionStrategy.CHAINABLE
			)
			{
				AsyncProcessorQueueable nextQueueable = new AsyncProcessorQueueable(processor);
				processor.enqueueWithOptionalDelay(nextQueueable);
			}
		}

		/**
		 * @description Splits items into chunks for Queueable processing, preserving original order.
		 *
		 * @return The list of items removed for subsequent processing.
		 */
		private List<Object> removeExtraItemsToProcess()
		{
			List<Object> splitItems = new List<Object>();

			//You need to have an entry in the list to add a new one at index zero!
			if(processor.itemsToProcess.size() > processor.getQueueableJobSize())
			{
				splitItems.add(processor.itemsToProcess.remove(processor.itemsToProcess.size() - 1));
			}

			while(processor.itemsToProcess.size() > processor.getQueueableJobSize())
			{
				// keep original order
				splitItems.add(0, processor.itemsToProcess.remove(processor.itemsToProcess.size() - 1));
			}

			return splitItems;
		}

		/**
		 * @description Logs an unhandled exception raised during Queueable execution, capturing the failed
		 * job's record scope as context. Queueable jobs have no platform auto-fired BatchApexErrorEvent
		 * (unlike Batch jobs, which implement Database.RaisesPlatformEvents), so the exception is surfaced
		 * through the framework log for subscribers to observe via LogEntryEvent__e / LogEntry__c.
		 *
		 * @param context The FinalizerContext containing the unhandled exception and job Id.
		 */
		private void logUnhandledException(FinalizerContext context)
		{
			List<String> itemsInScope = new List<String>();

			for(Object item : processor.itemsToProcess)
			{
				itemsInScope.add(item instanceof SObject ? String.valueOf(((SObject)item).Id) : String.valueOf(item));
			}

			LOG_Builder.build()
					.error(context.getException())
					.at(UTIL_System.getRuntimeTypeName(this) + '/logUnhandledException')
					.forRecord(context.getAsyncApexJobId())
					.withContext(LOG_Engine.CONTEXT_JOB_SCOPE, String.join(itemsInScope, UTIL_String.COMMA))
					.emit();
		}
	}

	/**
	 * @description Adapter class to convert QueueableContext to BatchableContext for finish method compatibility.
	 */
	private class QueueableToBatchableContext implements Database.BatchableContext
	{
		/**
		 * @description Copied from the Queueable context when the adapter is built, and never changed after that.
		 */
		private final Id jobId;

		/**
		 * @description Constructor that wraps a QueueableContext.
		 *
		 * @param context The QueueableContext to wrap.
		 */
		public QueueableToBatchableContext(QueueableContext context)
		{
			jobId = context.getJobId();
		}

		/**
		 * @description Gives the finish logic the Id of the running Queueable job, where a batch would give its own job Id.
		 *
		 * @return The job ID.
		 */
		public Id getJobId()
		{
			return jobId;
		}

		/**
		 * @description Returns null, as Queueable jobs do not have child jobs.
		 *
		 * @return Always null.
		 */
		public Id getChildJobId()
		{
			return null;
		}
	}

	/**
	 * @description Interface defining the fluent API for initiating and configuring asynchronous processing.
	 */
	public interface INT_Process
	{
		/**
		 * @description Starts the asynchronous processing job, selecting Queueable or Batch Apex based on item count.
		 *
		 * @return The job ID of the first started asynchronous process.
		 */
		Id run();

		/**
		 * @description Applies performance configuration settings to the processor.
		 *
		 * @param settings The settings object with performance configurations.
		 *
		 * @return The INT_Process instance for method chaining.
		 */
		INT_Process configure(DTO_ProcessSettings settings);
	}

	/**
	 * @description Enhanced settings class with execution strategy and AsyncOptions support.
	 * Allows fine-tuning of batch and queueable execution parameters.
	 */
	public inherited sharing class DTO_ProcessSettings
	{
		/**
		 * @description Maximum number of items to process using Queueable execution.
		 * If exceeded, Batch Apex is used. Default: `Limits.getLimitQueryRows()`.
		 * =
		 */
		public Integer limitAtWhichToBatch
		{
			get
			{
				if(limitAtWhichToBatch == null)
				{
					limitAtWhichToBatch = UTIL_Limits.soqlQueryRows().maximum();
				}

				return limitAtWhichToBatch;
			}
			set;
		}

		/**
		 * @description The class name of the processing logic this job runs, stamped by the processor.
		 * It is the name of the `AsynchronousJobSetting__mdt` record that configures `batchJobSize`, so a
		 * subscriber names that record after the Processable class they wrote.
		 */
		public String processableClassName {get; set;}

		/**
		 * @description Number of items to process in each Batch Apex execution.
		 * When no size is set in code, the first read resolves it from the `AsynchronousJobSetting__mdt` record
		 * named for `processableClassName`, and falls back to 200 when no such record exists.
		 */
		public Integer batchJobSize
		{
			get
			{
				if(batchJobSize == null)
				{
					batchJobSize = SEL_AsynchronousJobSetting.getBatchSize(processableClassName);
				}
				return Math.max(1, batchJobSize);
			}
			set;
		}

		/**
		 * @description Number of items to process in each Queueable execution.
		 * Default: Total item count or `batchJobSize` if not set.
		 */
		public Integer queueableJobSize {get; set;}

		/**
		 * @description The execution strategy for queueable processing.
		 * Default: AUTO (framework decides based on context and limits).
		 */
		public IF_Async.AsynchronousExecutionStrategy executionStrategy
		{
			get
			{
				if(executionStrategy == null)
				{
					executionStrategy = IF_Async.AsynchronousExecutionStrategy.AUTO;
				}
				return executionStrategy;
			}
			set;
		}

		/**
		 * @description AsyncOptions for configuring queueable behavior, especially useful for tests.
		 * When set, this will be passed to System.enqueueJob calls.
		 */
		public AsyncOptions asyncOptions {get; set;}

		/**
		 * @description Creates settings with nothing set. The batch threshold, the batch size and the execution strategy
		 * fill in their defaults the first time they are read; the other settings stay null until you set them.
		 */
		@SuppressWarnings('PMD.EmptyStatementBlock')
		public DTO_ProcessSettings()
		{
		}
	}
}