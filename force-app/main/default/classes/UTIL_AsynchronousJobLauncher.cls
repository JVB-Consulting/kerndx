// SPDX-License-Identifier: Apache-2.0
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
 * @date September 2025, November 2026
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
	 * @description The words the delayed-dispatch error entry uses in place of an item count when the job was built from
	 * a query, which has no list of items yet.
	 */
	private static final String ITEMS_FROM_A_QUERY = 'a query';

	/**
	 * @description Starts an adaptive asynchronous job with automatic execution strategy selection.
	 * The framework chooses between Queueable and Batch Apex for you. If the code already runs inside an
	 * asynchronous job (a Queueable, Batch or future method), it starts a chain of Queueables, whatever the
	 * number of items. Otherwise, more items than the batch threshold run as Batch Apex, and a number of items
	 * equal to or below the threshold runs as Queueables. When no Queueable job can be added in this
	 * transaction, it uses Batch Apex.
	 *
	 * @param items The Items to process
	 * @param processor An instance of a class that implements Processable.
	 *
	 * @return The ID of the started asynchronous job.
	 *
	 * @throws Exception Salesforce refused to start a job. Catch it as Exception. For a queueable job, getCause() returns
	 * the error Salesforce raised.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * // Process a list of accounts using a custom processor
	 * List<Account> accounts = [SELECT Id, Name FROM Account LIMIT 100];
	 * IF_Async.Processable processor = new MyAccountProcessor();
	 * Id jobId = UTIL_AsynchronousJobLauncher.process(accounts, processor);
	 * // jobId is the Id of the job that was started
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
	 * @throws Exception Salesforce refused to start a job. Catch it as Exception. For a queueable job, getCause() returns
	 * the error Salesforce raised.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * // Process contacts with a custom batch size of 50
	 * List<Contact> contacts = [SELECT Id, Email FROM Contact WHERE Email != null LIMIT 500];
	 * IF_Async.Processable processor = new EmailValidationProcessor();
	 * Id jobId = UTIL_AsynchronousJobLauncher.process(contacts, processor, 50);
	 * // Up to 500 contacts are processed 50 at a time; jobId is the Id of the job that was started
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
	 * A processor that implements IF_Async.Finishable cannot be forced to run as PARALLEL_QUEUEABLES: its finish step
	 * would run once for every job. That request is refused before any job is started.
	 *
	 * @param request The AsynchronousJobRequest containing the data and configuration.
	 * @param processor An instance of a class that implements Processable.
	 *
	 * @return The ID of the started asynchronous job.
	 *
	 * @throws Exception Salesforce refused to start a job. Catch it as Exception. For a queueable job, getCause() returns
	 * the error Salesforce raised.
	 * @throws IllegalArgumentException The request forces PARALLEL_QUEUEABLES and the processor implements IF_Async.Finishable.
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
	 * // jobId is the Id of the job that was started
	 * ```
	 */
	global static Id process(DTO_AsynchronousJobRequest request, IF_Async.Processable processor)
	{
		if(request.executionStrategy == IF_Async.AsynchronousExecutionStrategy.PARALLEL_QUEUEABLES && processor instanceof IF_Async.Finishable)
		{
			throw new IllegalArgumentException(System.Label.AsyncProcessor_ParallelRefusedForFinishable);
		}

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
	 *
	 * @throws UTIL_Exceptions.LaunchRefusedException Salesforce refused to queue the delayed handler. The exception has
	 * the error Salesforce raised as its cause and names every item of the request (none for a request built from a
	 * query). One error entry is written before it is thrown, unless the request says the caller handles a refused start.
	 */
	private static Id enqueueWithDelay(DTO_AsynchronousJobRequest request, IF_Async.Processable processor, Integer totalDelayMinutes)
	{
		Integer initialDelay = Math.min(totalDelayMinutes, MAX_DELAY_MINUTES);
		Integer remainingMinutes = totalDelayMinutes - initialDelay;

		try
		{
			return System.enqueueJob(new DelayedDispatchHandler(request, processor, remainingMinutes), initialDelay);
		}
		catch(Exception error)
		{
			List<Object> unsentItems = request.itemsToProcess != null ? new List<Object>(request.itemsToProcess) : new List<Object>();
			UTIL_Exceptions.LaunchRefusedException refused = new UTIL_Exceptions.LaunchRefusedException(error, unsentItems);
			if(!request.isLaunchRefusalHandledByCaller)
			{
				LOG_Builder.build().error(refused).at(UTIL_AsynchronousJobLauncher.class.getName() + '/enqueueWithDelay').emit();
			}
			throw refused;
		}
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
		settings.isLaunchRefusalHandledByCaller = request.isLaunchRefusalHandledByCaller;

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
		 * @description The batch threshold. When the framework chooses the job type, more items than this number run as
		 * Batch Apex; a number of items equal to or below it runs as Queueables. Inside a running asynchronous job the
		 * framework starts a chain of Queueables whatever the number of items. When no Queueable job can be added, it
		 * uses Batch Apex.
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
		 * @description True when the code that starts the job catches a refused start itself and keeps its own record of
		 * it. Salesforce can refuse to start a job, for example when the org has used its daily allowance of background
		 * jobs.
		 *
		 * When this is true, the framework writes no error log entry for a refused start, and still throws the refusal to
		 * that code. Any other failure still writes its error entry. False until withLaunchRefusalHandledByCaller is called.
		 */
		public Boolean isLaunchRefusalHandledByCaller
		{
			get
			{
				return isLaunchRefusalHandledByCaller ?? false;
			}
			private set;
		}

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
		 * @description Sets the batch threshold used when the framework chooses the job type. More items than this
		 * number run as Batch Apex; a number of items equal to it or below it still runs as Queueables. Inside a running
		 * asynchronous job the framework starts a chain of Queueables whatever the number of items, and when no
		 * Queueable job can be added it uses Batch Apex.
		 *
		 * @param threshold The highest number of items that still runs as Queueables.
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

		/**
		 * @description Says that the code starting the job catches a refused start itself and keeps its own record of it.
		 * The framework then writes no error log entry for a refused start. The refusal is still thrown to that code, and
		 * any other failure still writes its error entry.
		 *
		 * When the code cannot keep the work for a later try, its own record must be an error entry, so lost work is never
		 * logged below the error level.
		 *
		 * @return The AsynchronousJobRequest instance for method chaining.
		 */
		public DTO_AsynchronousJobRequest withLaunchRefusalHandledByCaller()
		{
			isLaunchRefusalHandledByCaller = true;
			return this;
		}
	}

	/**
	 * @description Internal queueable that manages delayed dispatch with automatic chaining.
	 * Chains itself for delays greater than 10 minutes until the delay expires, then dispatches processing.
	 * It is also its own Finalizer (code the platform runs after a Queueable ends, even when it crashes),
	 * so a crash in this handler always leaves an error log entry, as it does for the framework's other Queueables.
	 */
	public inherited sharing class DelayedDispatchHandler implements Queueable, Finalizer
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
		 * @description Holds the work for one step of the wait. A null remainingMinutes counts as 0, so the handler starts
		 * the processing the first time it runs.
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
		 * @description Executes the queueable job. It first attaches itself as the job's Finalizer.
		 * If remaining minutes greater than 0, chains with delay. Otherwise dispatches processing.
		 *
		 * @param context The QueueableContext provided by the platform.
		 */
		public void execute(QueueableContext context)
		{
			System.attachFinalizer(this);

			if(remainingMinutes > 0)
			{
				chainWithDelay();
			}
			else
			{
				dispatchProcessing(context.getJobId());
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
		 * @description Starts the real job now that the delay has ended. When Salesforce refuses to start it, the work is
		 * not done, and nothing starts it again. The handler then writes one error entry (see logRefusedLaunch) and ends
		 * normally.
		 *
		 * The handler says that it handles a refused start, so the processor writes no error entry of its own. The
		 * Finalizer has nothing to log, because the handler did not crash. Any other failure still writes its error entry.
		 *
		 * @param jobId The id of this handler's own job, which the error entry is linked to.
		 */
		private void dispatchProcessing(Id jobId)
		{
			try
			{
				processImmediately(request.withLaunchRefusalHandledByCaller(), processor);
			}
			catch(UTIL_Exceptions.LaunchRefusedException refused)
			{
				logRefusedLaunch(jobId, refused);
			}
		}

		/**
		 * @description Writes the error entry for a job Salesforce refused to start after the delay. The work is lost, so
		 * the entry is an error, not a warning: it shows at any log level setting.
		 *
		 * The entry names the processor's class, the number of items (or "a query" for a job built from a query), the
		 * delay that was asked for and the error Salesforce gave. It is linked to this handler's job and lists the items
		 * (the job scope).
		 *
		 * @param jobId The id of this handler's own job.
		 * @param refused The exception that says Salesforce refused to start the job.
		 */
		private void logRefusedLaunch(Id jobId, UTIL_Exceptions.LaunchRefusedException refused)
		{
			String itemCount = request.itemsToProcess != null ? String.valueOf(request.itemsToProcess.size()) : ITEMS_FROM_A_QUERY;

			String message = String.format
					(
							System.Label.AsyncLauncher_DelayedDispatchRefused,
							new List<Object>
							{
									UTIL_System.getRuntimeTypeName(processor),
									itemCount,
									String.valueOf(request.delayMinutes),
									refused.getCause().getMessage()
							}
					);

			LOG_Builder.LogEntry entry = LOG_Builder.build()
					.error(message)
					.at(UTIL_System.getRuntimeTypeName(this) + '/dispatchProcessing')
					.forRecord(jobId);

			addJobScope(entry);
			entry.emit();
		}

		/**
		 * @description Finalizer method. The platform runs it after the job ends. When the job crashed, it logs the error.
		 *
		 * @param context The FinalizerContext provided by the platform.
		 */
		public void execute(FinalizerContext context)
		{
			if(ParentJobResult.UNHANDLED_EXCEPTION.equals(context.getResult()))
			{
				logUnhandledException(context);
			}
		}

		/**
		 * @description Logs the exception that crashed this job, with the job's id as the record, so the crash
		 * leaves a lasting error log entry. When the request was given a list of items, the entry also lists them
		 * (the job scope): a record by its Id, any other item as its text. A request built from a query has no list
		 * yet, so its entry has no job scope.
		 *
		 * @param context The FinalizerContext containing the exception and the job's id.
		 */
		private void logUnhandledException(FinalizerContext context)
		{
			LOG_Builder.LogEntry entry = LOG_Builder.build()
					.error(context.getException())
					.at(UTIL_System.getRuntimeTypeName(this) + '/logUnhandledException')
					.forRecord(context.getAsyncApexJobId());

			addJobScope(entry);
			entry.emit();
		}

		/**
		 * @description Adds the job scope to a log entry when the request was given a list of items. A request built
		 * from a query has no list yet, so its entry gets no job scope.
		 *
		 * @param entry The log entry to add the job scope to.
		 */
		private void addJobScope(LOG_Builder.LogEntry entry)
		{
			if(request.itemsToProcess != null)
			{
				entry.withContext(LOG_Engine.CONTEXT_JOB_SCOPE, buildJobScope(request.itemsToProcess));
			}
		}

		/**
		 * @description Builds the job scope text of a crash log entry: the items joined with commas, a record by its
		 * Id and any other item as its text.
		 *
		 * @param items The items the request was given.
		 *
		 * @return The items as one line of text.
		 */
		private String buildJobScope(List<Object> items)
		{
			List<String> itemsInScope = new List<String>();

			for(Object item : items)
			{
				itemsInScope.add(item instanceof SObject ? String.valueOf(((SObject)item).Id) : String.valueOf(item));
			}

			return String.join(itemsInScope, UTIL_String.COMMA);
		}
	}
}