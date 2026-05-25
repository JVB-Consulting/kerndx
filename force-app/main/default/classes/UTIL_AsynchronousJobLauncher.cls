// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Provides a simplified, static entry point for running complex asynchronous jobs
 * using the UTIL_AdaptiveAsynchronousProcessor engine.
 *
 * @see IF_Async
 * @see UTIL_AsynchronousJobLauncher_TEST
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
 * List<Object> items = new List<Object>{ 'item1', 'item2', 'item3' };
 * IF_Async.Processable processor = new MyCustomProcessor();
 * Id jobId = UTIL_AsynchronousJobLauncher.process(items, processor, 50);
 * ```
 */
@SuppressWarnings('PMD.AvoidGlobalModifier')
global inherited sharing class UTIL_AsynchronousJobLauncher
{
	/**
	 * @description Maximum delay per queueable execution (Salesforce limit).
	 */
	@TestVisible
	private static final Integer MAX_DELAY_MINUTES = 10;

	/**
	 * @description Starts an adaptive asynchronous job with automatic execution strategy selection.
	 * The framework automatically chooses between Queueable and Batch Apex based on the number of items
	 * and available governor limits, optimizing for performance.
	 *
	 * @param items The Items to process
	 * @param processor An instance of a class that implements Processable.
	 *
	 * @return The ID of the started asynchronous job.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * // Process a list of accounts using a custom processor
	 * List<Account> accounts = [SELECT Id, Name FROM Account LIMIT 100];
	 * IF_Async.Processable processor = new MyAccountProcessor();
	 * Id jobId = UTIL_AsynchronousJobLauncher.process(accounts, processor);
	 * System.debug('Job started with ID: ' + jobId);
	 * ```
	 */
	global static Id process(List<Object> items, IF_Async.Processable processor)
	{
		return process(items, processor, null);
	}

	/**
	 * @description Starts an adaptive asynchronous job with a custom job size for batch or queueable processing.
	 * The job size controls how many records are processed in each batch execution or queueable transaction.
	 *
	 * @param items The Items to process
	 * @param processor An instance of a class that implements Processable.
	 * @param jobSize The size of each job to be executed
	 *
	 * @return The ID of the started asynchronous job.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * // Process contacts with a custom batch size of 50
	 * List<Contact> contacts = [SELECT Id, Email FROM Contact WHERE Email != null LIMIT 500];
	 * IF_Async.Processable processor = new EmailValidationProcessor();
	 * Id jobId = UTIL_AsynchronousJobLauncher.process(contacts, processor, 50);
	 * System.debug('Processing 500 contacts in batches of 50. Job ID: ' + jobId);
	 * ```
	 */
	global static Id process(List<Object> items, IF_Async.Processable processor, Integer jobSize)
	{
		DTO_AsynchronousJobRequest request =
				new DTO_AsynchronousJobRequest(items)
						.withBatchSize(jobSize)
						.withQueueableJobSize(jobSize)
						.withExecutionStrategy(IF_Async.AsynchronousExecutionStrategy.AUTO);

		return process(request, processor);
	}

	/**
	 * @description Starts an adaptive asynchronous job with full configuration control via a request object.
	 * This method provides maximum flexibility, allowing you to configure batch size, queueable job size,
	 * execution strategy, and other advanced settings through the DTO_AsynchronousJobRequest object.
	 *
	 * @param request The AsynchronousJobRequest containing the data and configuration.
	 * @param processor An instance of a class that implements Processable.
	 *
	 * @return The ID of the started asynchronous job.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * // Process opportunities with advanced configuration
	 * List<Opportunity> opportunities = [SELECT Id, Amount FROM Opportunity WHERE StageName = 'Closed Won' LIMIT 1000];
	 * DTO_AsynchronousJobRequest request = new DTO_AsynchronousJobRequest(opportunities)
	 *     .withBatchSize(100)
	 *     .withQueueableJobSize(50)
	 *     .withExecutionStrategy(IF_Async.AsynchronousExecutionStrategy.BATCH);
	 * IF_Async.Processable processor = new OpportunityProcessor();
	 * Id jobId = UTIL_AsynchronousJobLauncher.process(request, processor);
	 * System.debug('Advanced processing started with Job ID: ' + jobId);
	 * ```
	 */
	global static Id process(DTO_AsynchronousJobRequest request, IF_Async.Processable processor)
	{
		Integer totalDelay = request.delayMinutes != null ? request.delayMinutes : 0;

		// If delay > 0, use the delay handler (with chaining for delays > 10 min)
		if(totalDelay > 0)
		{
			return enqueueWithDelay(request, processor, totalDelay);
		}

		return processImmediately(request, processor);
	}

	/**
	 * @description Enqueues a delayed handler that will chain until the delay expires.
	 * For delays greater than 10 minutes, the handler chains itself automatically.
	 *
	 * @param request The request containing items and configuration.
	 * @param processor The processor to execute when delay expires.
	 * @param totalDelayMinutes The total delay before processing starts.
	 *
	 * @return The job ID of the enqueued delay handler.
	 */
	private static Id enqueueWithDelay(DTO_AsynchronousJobRequest request, IF_Async.Processable processor, Integer totalDelayMinutes)
	{
		Integer initialDelay = Math.min(totalDelayMinutes, MAX_DELAY_MINUTES);
		Integer remainingMinutes = totalDelayMinutes - initialDelay;

		return System.enqueueJob(
				new DelayedDispatchHandler(request, processor, remainingMinutes),
				initialDelay
		);
	}

	/**
	 * @description Processes the request immediately using the adaptive processor.
	 *
	 * @param request The request containing items and configuration.
	 * @param processor The processor to execute.
	 *
	 * @return The job ID of the started job.
	 */
	@TestVisible
	private static Id processImmediately(DTO_AsynchronousJobRequest request, IF_Async.Processable processor)
	{
		UTIL_AdaptiveAsynchronousProcessor adaptiveProcessor = new UTIL_AdaptiveAsynchronousProcessor(processor);

		UTIL_AdaptiveAsynchronousProcessor.DTO_ProcessSettings settings = new UTIL_AdaptiveAsynchronousProcessor.DTO_ProcessSettings();

		settings.asyncOptions = request.asyncOptions;
		settings.batchJobSize = request.batchJobSize;
		settings.executionStrategy = request.executionStrategy;
		settings.limitAtWhichToBatch = request.limitAtWhichToBatch;
		settings.queueableJobSize = request.queueableJobSize;

		adaptiveProcessor.configure(settings);

		// Update the request DTO with any default values that were set.
		request.batchJobSize = settings.batchJobSize;
		request.executionStrategy = settings.executionStrategy;
		request.limitAtWhichToBatch = settings.limitAtWhichToBatch;
		request.queueableJobSize = settings.queueableJobSize;

		UTIL_AdaptiveAsynchronousProcessor.INT_Process processInitializer = request.itemsToProcess != null ?
				adaptiveProcessor.initialise(request.itemsToProcess) : adaptiveProcessor.initialise(request.queryable);

		return processInitializer.run();
	}

	/**
	 * @description Request object for initiating an asynchronous process.
	 *
	 * @since 1.0
	 */
	global inherited sharing class DTO_AsynchronousJobRequest
	{
		/**
		 * @description The queryable used for query-based jobs. Null for list-based jobs.
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * IF_Queryable value = instance.queryable;
		 * ```
		 */
		global IF_Queryable queryable {get; private set;}

		/**
		 * @description The list of objects to process. Null for query-based jobs.
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * List<Object> value = instance.itemsToProcess;
		 * ```
		 */
		global List<Object> itemsToProcess {get; private set;}

		/**
		 * @description The record count threshold at which the framework switches from Queueable to Batch Apex.
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * Integer value = instance.limitAtWhichToBatch;
		 * ```
		 */
		global Integer limitAtWhichToBatch {get; private set;}

		/**
		 * @description The number of records to process in each Batch Apex transaction.
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * Integer value = instance.batchJobSize;
		 * ```
		 */
		global Integer batchJobSize {get; private set;}

		/**
		 * @description The number of records to process in each Queueable job transaction.
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * Integer value = instance.queueableJobSize;
		 * ```
		 */
		global Integer queueableJobSize {get; private set;}

		/**
		 * @description The execution strategy for queueable processing.
		 * Default: AUTO (framework decides based on context and limits).
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * IF_Async.AsynchronousExecutionStrategy value = instance.executionStrategy;
		 * ```
		 */
		global IF_Async.AsynchronousExecutionStrategy executionStrategy {get; private set;}

		/**
		 * @description AsyncOptions for configuring queueable behavior, especially useful for tests.
		 * When set, this will be passed to System.enqueueJob calls.
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * AsyncOptions value = instance.asyncOptions;
		 * ```
		 */
		global AsyncOptions asyncOptions {get; set;}

		/**
		 * @description The delay in minutes before processing starts.
		 * For delays greater than 10 minutes, the framework automatically chains queueables until the delay expires.
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * Integer value = instance.delayMinutes;
		 * ```
		 */
		global Integer delayMinutes {get; private set;}

		/**
		 * @description Constructor for processing a predefined list of objects.
		 *
		 * @param items The list of objects to process.
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * UTIL_AsynchronousJobLauncher.DTO_AsynchronousJobRequest instance = new UTIL_AsynchronousJobLauncher.DTO_AsynchronousJobRequest(new List<Object>{'a', 'b'});
		 * ```
		 */
		global DTO_AsynchronousJobRequest(List<Object> items)
		{
			itemsToProcess = items;
		}

		/**
		 * @description Constructor for processing records retrieved from an IF_Queryable.
		 * Supports QRY_Builder.Builder and SEL_Base instances directly.
		 *
		 * @param queryable The IF_Queryable defining the records to process.
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * IF_Queryable query = QRY_Builder.selectFrom(Account.SObjectType)
		 *     .fields(new List<String>{'Id', 'Name'})
		 *     .condition(Account.Industry).equals('Technology');
		 * DTO_AsynchronousJobRequest request = new DTO_AsynchronousJobRequest(query)
		 *     .withBatchSize(100);
		 * Id jobId = UTIL_AsynchronousJobLauncher.process(request, new MyProcessor());
		 * ```
		 */
		global DTO_AsynchronousJobRequest(IF_Queryable queryable)
		{
			this.queryable = queryable;
		}

		/**
		 * @description Sets the batch job size for Batch Apex execution.
		 *
		 * @param size The number of items per batch execution.
		 *
		 * @return The AsynchronousJobRequest instance for method chaining.
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * DTO_AsynchronousJobRequest result = instance.withBatchSize(10);
		 * ```
		 */
		global DTO_AsynchronousJobRequest withBatchSize(Integer size)
		{
			batchJobSize = size;
			return this;
		}

		/**
		 * @description Sets the chunk size for Queueable execution.
		 *
		 * @param size The number of items per Queueable execution.
		 *
		 * @return The AsynchronousJobRequest instance for method chaining.
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * DTO_AsynchronousJobRequest result = instance.withQueueableJobSize(10);
		 * ```
		 */
		global DTO_AsynchronousJobRequest withQueueableJobSize(Integer size)
		{
			queueableJobSize = size;
			return this;
		}

		/**
		 * @description Sets the threshold at which processing switches from Queueable to Batch Apex.
		 *
		 * @param threshold The number of items that will trigger Batch Apex execution.
		 *
		 * @return The AsynchronousJobRequest instance for method chaining.
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * DTO_AsynchronousJobRequest result = instance.withLimitAtWhichToBatch(10);
		 * ```
		 */
		global DTO_AsynchronousJobRequest withLimitAtWhichToBatch(Integer threshold)
		{
			limitAtWhichToBatch = threshold;
			return this;
		}

		/**
		 * @description Sets the execution strategy for determine what job type to use
		 *
		 * @param strategy The execution strategy to employ
		 *
		 * @return The AsynchronousJobRequest instance for method chaining.
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * DTO_AsynchronousJobRequest result = instance.withExecutionStrategy(new IF_Async.AsynchronousExecutionStrategy());
		 * ```
		 */
		global DTO_AsynchronousJobRequest withExecutionStrategy(IF_Async.AsynchronousExecutionStrategy strategy)
		{
			executionStrategy = strategy;
			return this;
		}

		/**
		 * @description Sets the maximum stack depth for chaining
		 *
		 * @param options The asynchronous options to use
		 *
		 * @return The AsynchronousJobRequest instance for method chaining.
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * DTO_AsynchronousJobRequest result = instance.withAsyncOptions(new AsyncOptions());
		 * ```
		 */
		global DTO_AsynchronousJobRequest withAsyncOptions(AsyncOptions options)
		{
			asyncOptions = options;
			return this;
		}

		/**
		 * @description Sets the delay in minutes before processing starts.
		 * For delays greater than 10 minutes, the framework automatically chains queueables
		 * until the delay expires, making this suitable for any duration.
		 *
		 * @param minutes The delay in minutes before processing begins (0 or greater).
		 *
		 * @return The AsynchronousJobRequest instance for method chaining.
		 *
		 * @throws IllegalArgumentException if minutes is less than 0.
		 *
		 * @since 1.0
		 *
		 * @example
		 * ```apex
		 * // Process immediately (default)
		 * DTO_AsynchronousJobRequest request = new DTO_AsynchronousJobRequest(items);
		 * // Process after 5 minutes
		 * DTO_AsynchronousJobRequest request = new DTO_AsynchronousJobRequest(items)
		 *     .withDelayMinutes(5);
		 * // Process after 45 minutes (automatically chains for delays > 10 min)
		 * DTO_AsynchronousJobRequest request = new DTO_AsynchronousJobRequest(items)
		 *     .withDelayMinutes(45);
		 * Id jobId = UTIL_AsynchronousJobLauncher.process(request, new MyProcessor());
		 * ```
		 */
		global DTO_AsynchronousJobRequest withDelayMinutes(Integer minutes)
		{
			if(minutes != null && minutes < 0)
			{
				throw new IllegalArgumentException(
						'Delay minutes cannot be negative.'
				);
			}
			delayMinutes = minutes;
			return this;
		}
	}

	/**
	 * @description Internal queueable that manages delayed dispatch with automatic chaining.
	 * Chains itself for delays greater than 10 minutes until the delay expires, then dispatches processing.
	 */
	@SuppressWarnings('PMD.QueueableWithoutFinalizer')
	public class DelayedDispatchHandler implements Queueable
	{
		/**
		 * @description The original request containing items and configuration.
		 */
		private final DTO_AsynchronousJobRequest request;

		/**
		 * @description The processor to execute when the delay expires.
		 */
		private final IF_Async.Processable processor;

		/**
		 * @description The remaining minutes before processing should start.
		 */
		private final Integer remainingMinutes;

		/**
		 * @description Constructs a delayed dispatch handler.
		 *
		 * @param request The request containing items and configuration.
		 * @param processor The processor to execute when delay expires.
		 * @param remainingMinutes The remaining minutes before processing.
		 */
		public DelayedDispatchHandler
				(
						DTO_AsynchronousJobRequest request,
						IF_Async.Processable processor,
						Integer remainingMinutes
				)
		{
			this.request = request;
			this.processor = processor;
			this.remainingMinutes = remainingMinutes != null ? remainingMinutes : 0;
		}

		/**
		 * @description Executes the queueable job.
		 * If remaining minutes greater than 0, chains with delay. Otherwise dispatches processing.
		 *
		 * @param context The QueueableContext provided by the platform.
		 */
		public void execute(QueueableContext context)
		{
			if(remainingMinutes > 0)
			{
				chainWithDelay();
			}
			else
			{
				dispatchProcessing();
			}
		}

		/**
		 * @description Chains the next delayed dispatch with reduced remaining time.
		 */
		private void chainWithDelay()
		{
			Integer delayMinutes = Math.min(remainingMinutes, MAX_DELAY_MINUTES);
			Integer newRemainingMinutes = remainingMinutes - delayMinutes;

			System.enqueueJob(
					new DelayedDispatchHandler(request, processor, newRemainingMinutes),
					delayMinutes
			);
		}

		/**
		 * @description Dispatches the actual processing now that delay has expired.
		 */
		private void dispatchProcessing()
		{
			// Clear the dispatch delay and process immediately
			processImmediately(request, processor);
		}
	}
}