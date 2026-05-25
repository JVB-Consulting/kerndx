// SPDX-License-Identifier: BUSL-1.1
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
 * @date September 2025, May 2026
 */
@SuppressWarnings('PMD.CognitiveComplexity')
public without sharing class UTIL_AdaptiveAsynchronousProcessor implements
				Database.AllowsCallouts,
				Database.Batchable<Object>,
				Database.RaisesPlatformEvents,
				INT_Process
{

	/**
	 * @description The maximum length of the JobScope field on BatchApexErrorEvent.
	 */
	private static final Integer BATCH_ERROR_EVENT_JOB_SCOPE_LENGTH = 40000;

	/**
	 * @description The maximum length of text-based fields (Message, StackTrace) on BatchApexErrorEvent.
	 */
	private static final Integer BATCH_ERROR_EVENT_TEXT_LENGTH = 5000;

	/**
	 * @description Test-visible storage for the last fired BatchApexErrorEvent.
	 * Used for testing error handling behavior.
	 */
	@TestVisible
	private static BatchApexErrorEvent firedErrorEvent;

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
	 * System.debug('Job Status: ' + job.Status);
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
		if(this.processorLogic != null)
		{
			this.processorLogic.execute(items);
		}
	}

	/**
	 * @description Overrides the finish method to delegate to the Finishable interface, if implemented.
	 *
	 * @param context The BatchableContext provided by the platform.
	 */
	public void finish(Database.BatchableContext context)
	{
		if(this.processorLogic instanceof IF_Async.Finishable)
		{
			((IF_Async.Finishable)this.processorLogic).finish(context);
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
		return this.initialise(queryable, null);
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
	 * @description Applies performance configuration settings to the processor.
	 * Overrides default settings if provided.
	 *
	 * @param configuration The configuration object with performance settings.
	 *
	 * @return The INT_Process instance for method chaining.

	 */

	public INT_Process configure(DTO_ProcessSettings configuration)
	{
		this.processSettings = configuration;
		return this;
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
				this.asyncJobId = jobId;
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
				fireBatchApexErrorEvent(context);
			}
			else if
			(
					!processor.itemsToProcess.isEmpty() &&
					processor.processSettings.executionStrategy == IF_Async.AsynchronousExecutionStrategy.CHAINABLE
			)
			{
				AsyncProcessorQueueable nextQueueable = new AsyncProcessorQueueable(processor);
				System.enqueueJob(nextQueueable, processor.processSettings.asyncOptions);
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
		 * @description Publishes a BatchApexErrorEvent for unhandled exceptions with detailed context.
		 *
		 * @param context The FinalizerContext containing error information.
		 */
		private void fireBatchApexErrorEvent(FinalizerContext context)
		{
			List<String> itemsInScope = new List<String>();

			for(Object item : processor.itemsToProcess)
			{
				itemsInScope.add(item instanceof SObject ? ((SObject)item).Id : item.toString());
			}

			String fullLengthJobScope = String.join(itemsInScope, UTIL_String.COMMA);

			Exception error = context.getException();

			BatchApexErrorEvent errorEvent = new BatchApexErrorEvent();

			errorEvent.AsyncApexJobId = context.getAsyncApexJobId();
			errorEvent.DoesExceedJobScopeMaxLength = fullLengthJobScope.length() > BATCH_ERROR_EVENT_JOB_SCOPE_LENGTH;
			errorEvent.ExceptionType = error.getTypeName();
			errorEvent.JobScope = UTIL_String.abbreviate(fullLengthJobScope, BATCH_ERROR_EVENT_JOB_SCOPE_LENGTH);
			errorEvent.Message = UTIL_String.abbreviate(error.getMessage(), BATCH_ERROR_EVENT_TEXT_LENGTH);
			errorEvent.Phase = 'EXECUTE';
			errorEvent.StackTrace = UTIL_String.abbreviate(error.getStackTraceString(), BATCH_ERROR_EVENT_TEXT_LENGTH);
			Database.SaveResult saveResult = EventBus.publish(errorEvent);

			LOG_Builder.errorDMLOperationResults(new List<Object> {saveResult}, UTIL_System.getRuntimeTypeName(this) + '/fireBatchApexErrorEvent');

			if(Test.isRunningTest())
			{
				firedErrorEvent = saveResult.success ? errorEvent : firedErrorEvent;
			}

			LOG_Builder.build().error(error).at(UTIL_System.getRuntimeTypeName(this) + '/fireBatchApexErrorEvent').forRecord(errorEvent.AsyncApexJobId).emit();
		}
	}

	/**
	 * @description Adapter class to convert QueueableContext to BatchableContext for finish method compatibility.
	 */
	private class QueueableToBatchableContext implements Database.BatchableContext
	{
		/**
		 * @description The job ID of the Queueable job.
		 */
		private final Id jobId;

		/**
		 * @description Constructor that wraps a QueueableContext.
		 *
		 * @param context The QueueableContext to wrap.
		 */
		public QueueableToBatchableContext(QueueableContext context)
		{
			this.jobId = context.getJobId();
		}

		/**
		 * @description Returns the job ID of the Queueable job.
		 *
		 * @return The job ID.
		 */
		public Id getJobId()
		{
			return this.jobId;
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
		 * @description Number of items to process in each Batch Apex execution.
		 * Default: Determined by `SEL_AsynchronousJobSetting.getBatchSize`, or 200 if not set.
		 */
		public Integer batchJobSize
		{
			get
			{
				if(batchJobSize == null)
				{
					batchJobSize = SEL_AsynchronousJobSetting.getBatchSize(UTIL_System.getRuntimeTypeName(this));
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
		 * @description Default constructor for DTO_ProcessSettings.
		 */
		@SuppressWarnings('PMD.EmptyStatementBlock')
		public DTO_ProcessSettings()
		{
		}
	}
}