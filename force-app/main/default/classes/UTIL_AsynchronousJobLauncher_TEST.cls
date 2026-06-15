// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Test class for the UTIL_AsynchronousJobLauncher framework.
 *
 * @see UTIL_AsynchronousJobLauncher
 *
 * @author Jason van Beukering
 *
 * @group Async Processing
 *
 * @date September 2025, May 2026
 */
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest(SeeAllData=false IsParallel=false)
private class UTIL_AsynchronousJobLauncher_TEST
{
	private static final String TEST_ADMIN_COMPANY = 'UTIL_AsynchronousJobLauncher_TEST-admin';

	/**
	 * @description Flag to confirm the execute method of a mock processor was called.
	 */
	private static Boolean executeWasCalled = false;
	/**
	 * @description Flag to confirm the finish method of a mock processor was called.
	 */
	private static Boolean finishWasCalled = false;
	/**
	 * @description Flag to confirm if job was executed as Queueable or Batch
	 */
	private static Boolean executionWasQueueable = false;
	/**
	 * @description Counter for the number of times execute is called during testing.
	 */
	private static Integer executeCallCounter = 0;
	/**
	 * @description The Job Id of either the queueable or batch job
	 */
	private static Id executeJobId;
	/**
	 * @description The Child Job Id of either the queueable or batch job
	 */
	private static Id executeChildJobId;

	/**
	 * @description Creates a dedicated test admin user so System.runAs in each test starts a fresh
	 * permission-evaluation context, bypassing the synthetic-org permission-cache staleness issue
	 * that affected mutating the running user's permissionSet mid-transaction.
	 */
	@TestSetup
	private static void setupTestAdmin()
	{
		TST_Factory.newUserWithPermissionSet
				(
						SEL_Profile.PROFILE_SYSTEM_ADMIN,
						TEST_ADMIN_COMPANY,
						SEL_PermissionSet.ADMIN_PERMISSION_SET_API_NAME
				);
	}

	/**
	 * @description Verifies that a job launched with a List of objects correctly sets default parameters.
	 */
	@IsTest
	private static void queueableProcessesListOfObjects()
	{
		System.runAs(getTestAdmin())
		{
			final Integer numberOfRecords = 1;

			assertJobRan
					(
							new UTIL_AsynchronousJobLauncher.DTO_AsynchronousJobRequest(TST_Factory.newFoobars(numberOfRecords)),
							new MockProcessorWithFinish(),
							IF_Async.AsynchronousExecutionStrategy.PARALLEL_QUEUEABLES,
							true
					);
		}
	}

	/**
	 * @description Verifies that a job launched with a List of objects correctly sets default parameters.
	 */
	@IsTest
	private static void batchProcessesListOfObjects()
	{
		System.runAs(getTestAdmin())
		{
			final Integer numberOfRecords = 1;

			assertJobRan
					(
							new UTIL_AsynchronousJobLauncher.DTO_AsynchronousJobRequest(TST_Factory.newFoobars(numberOfRecords)),
							new MockProcessorWithFinish(),
							IF_Async.AsynchronousExecutionStrategy.BATCH,
							false
					);
		}
	}

	/**
	 * @description Utility method what will trigger asynchronous processing and perform default checks
	 *
	 * @param request The launcher which will manage processing async request
	 * @param processorLogic The process to implement processing
	 * @param strategy The execution strategy to use
	 * @param shouldRunQueueable Indicates if we expect a queueable to be run
	 */
	private static void assertJobRan
			(
					UTIL_AsynchronousJobLauncher.DTO_AsynchronousJobRequest request,
					IF_Async.Processable processorLogic,
					IF_Async.AsynchronousExecutionStrategy strategy,
					Boolean shouldRunQueueable
			)
	{
		LOG_Builder.ignoreTestMode = true;
		executeWasCalled = false;
		finishWasCalled = false;

		request.withExecutionStrategy(strategy);

		Test.startTest();

		Id jobId = UTIL_AsynchronousJobLauncher.process(request, processorLogic);

		Test.stopTest();

		Assert.isNotNull(jobId, 'Job Id should not be null');
		Assert.isTrue(executeWasCalled, 'Execute method should have been called.');
		Assert.isTrue(finishWasCalled, 'Finish method should have been called upon completion.');
		Assert.isNotNull(executeJobId, 'Job Id should not be null');
		Assert.areEqual(shouldRunQueueable, executionWasQueueable, 'Job was not run use correct pattern');
	}

	/**
	 * @description Verifies a job can be successfully launched using IF_Queryable as queueable.
	 */
	@IsTest
	private static void queueableWithQueryExecutor()
	{
		System.runAs(getTestAdmin())
		{
			final Integer numberOfRecords = 5;
			TST_Factory.insertFoobars(numberOfRecords);

			IF_Queryable query = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.fields(new SEL_Foobar().fields);

			assertJobRan
					(
							new UTIL_AsynchronousJobLauncher.DTO_AsynchronousJobRequest(query),
							new MockProcessorWithFinish(),
							IF_Async.AsynchronousExecutionStrategy.AUTO,
							true
					);
		}
	}
	/**
	 * @description Verifies a job can be successfully launched using IF_Queryable as batch.
	 */
	@IsTest
	private static void batchWithQueryExecutor()
	{
		System.runAs(getTestAdmin())
		{
			final Integer numberOfRecords = 5;
			TST_Factory.insertFoobars(numberOfRecords);

			IF_Queryable query = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.fields(new SEL_Foobar().fields);

			UTIL_AsynchronousJobLauncher.DTO_AsynchronousJobRequest request =
					new UTIL_AsynchronousJobLauncher.DTO_AsynchronousJobRequest(query)
							.withBatchSize(numberOfRecords)
							.withLimitAtWhichToBatch(numberOfRecords);

			assertJobRan
					(
							request,
							new MockProcessorWithFinish(),
							IF_Async.AsynchronousExecutionStrategy.BATCH,
							false
					);
		}
	}

	/**
	 * @description Verifies a job is executed as a batch due to query limits being reached (i.e. Count can't be performed)
	 */
	@IsTest
	private static void batchDueToQueryLimits()
	{
		System.runAs(getTestAdmin())
		{
			final Integer numberOfRecords = 1;
			TST_Factory.insertFoobars(numberOfRecords);
			UTIL_AdaptiveAsynchronousProcessor.simulateQueryLimits = true;

			IF_Queryable query = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.fields(new SEL_Foobar().fields);

			assertJobRan
					(
							new UTIL_AsynchronousJobLauncher.DTO_AsynchronousJobRequest(query),
							new MockProcessorWithFinish(),
							IF_Async.AsynchronousExecutionStrategy.AUTO,
							false
					);
		}
	}

	/**
	 * @description Verifies that an unhandled exception in a Queueable job is caught and surfaces a durable
	 * error log. Queueable jobs have no platform auto-fired BatchApexErrorEvent (unlike Batch jobs), so the
	 * finalizer logs the unhandled exception — including the failed job's record scope — for subscribers to
	 * observe via LogEntryEvent__e / LogEntry__c.
	 */
	@IsTest
	private static void queueableExceptionIsLogged()
	{
		System.runAs(getTestAdmin())
		{
			assertExceptionFiresEvents(false);
		}
	}

	/**
	 * @description Verifies that an exception in the processor logic is caught and surfaces error events.
	 *
	 * @param runBatchJob Indicates if the Job should be run as batch else it will run as queueable
	 */
	private static void assertExceptionFiresEvents(Boolean runBatchJob)
	{
		final Integer numberOfRecords = 1;

		List<Foobar__c> foobars = TST_Factory.insertFoobars(numberOfRecords);

		UTIL_AsynchronousJobLauncher.DTO_AsynchronousJobRequest request = new UTIL_AsynchronousJobLauncher.DTO_AsynchronousJobRequest(foobars)
				.withBatchSize(numberOfRecords)
				.withQueueableJobSize(numberOfRecords);

		IF_Async.AsynchronousExecutionStrategy strategy =
				runBatchJob ? IF_Async.AsynchronousExecutionStrategy.BATCH : IF_Async.AsynchronousExecutionStrategy.AUTO;

		try
		{
			assertJobRan(request, new MockFailingProcessor(), strategy, !runBatchJob);
			Assert.fail('An exception from the processor logic should have been thrown.');
		}
		catch(Exception error)
		{
			Assert.isInstanceOfType(error, TestException.class, 'The correct exception type should be caught.');

			List<LogEntry__c> logs = new SEL_LogEntry().getAll();
			Assert.isFalse(logs.isEmpty(), 'LOG_Builder should have logged the error');

			//Queueable failures are surfaced via the framework log; Batch failures auto-fire a platform
			//BatchApexErrorEvent, so the durable-log scope assertion only applies to the queueable path.
			if(!runBatchJob)
			{
				LogEntry__c unhandledExceptionLog = null;

				for(LogEntry__c log : logs)
				{
					if(TestException.class.getName().equals(log.ExceptionType__c))
					{
						unhandledExceptionLog = log;
						break;
					}
				}

				Assert.isNotNull(unhandledExceptionLog, 'The queueable unhandled exception should be logged with its exception type.');

				Map<String, Object> logContext = SEL_LogEntry.parseContextDataForTest(unhandledExceptionLog);
				Assert.isNotNull(logContext, 'The unhandled-exception log should carry context data.');
				Assert.areEqual
						(
								String.valueOf(foobars[0].Id),
								String.valueOf(logContext.get(LOG_Engine.CONTEXT_JOB_SCOPE)),
								'The unhandled-exception log should capture the failed job scope.'
						);
			}
		}
	}

	/**
	 * @description Verifies that an exception processed by Batch Job is caught and surfaces error events.
	 */
	@IsTest
	private static void batchExceptionFiresErrorEvent()
	{
		System.runAs(getTestAdmin())
		{
			assertExceptionFiresEvents(true);
		}
	}

	/**
	 * @description Verifies that multiple Queueable jobs are enqueued in parallel when the record list is larger than the queueable job size.
	 */
	@IsTest
	private static void queueableParallelIsTriggeredByJobSize()
	{
		System.runAs(getTestAdmin())
		{
			final Integer numberOfRecords = 5;
			final Integer queueableJobSize = 2;
			final Integer expectedJobCount = 3; // 5 records / 2 per job = 3 jobs

			List<Foobar__c> foobars = TST_Factory.newFoobars(numberOfRecords);

			UTIL_AsynchronousJobLauncher.DTO_AsynchronousJobRequest request = new UTIL_AsynchronousJobLauncher.DTO_AsynchronousJobRequest(foobars)
					.withQueueableJobSize(queueableJobSize);

			Test.startTest();

			UTIL_AsynchronousJobLauncher.process(request, new MockProcessorWithFinish());
			Assert.areEqual(expectedJobCount, UTIL_Limits.queueableJobs().used(), 'Expected ' + expectedJobCount + ' parallel Queueable jobs to be enqueued.');

			Test.stopTest();

			Assert.areEqual(expectedJobCount, executeCallCounter, 'Execute should have been called ' + expectedJobCount + ' times, once for each chunk.');
		}
	}

	/**
	 * @description Verifies that Queueable jobs are chained (run serially) when queueable limits does not allow parallel runs
	 */
	@IsTest
	private static void queueableChainIsTriggeredByLimits()
	{
		System.runAs(getTestAdmin())
		{
			final Integer numberOfRecords = 5;
			final Integer queueableJobSize = 2;
			final Integer expectedJobCount = 3; // 5 records / 2 per job = 3 jobs

			//Ensure that system behaves if only 1 queueable is available to enqueue
			UTIL_AdaptiveAsynchronousProcessor.simulateQueueableLimits = true;

			List<Foobar__c> foobars = TST_Factory.newFoobars(numberOfRecords);

			// Configure AsyncOptions for test context
			AsyncOptions options = new AsyncOptions();
			options.maximumQueueableStackDepth = expectedJobCount;

			UTIL_AsynchronousJobLauncher.DTO_AsynchronousJobRequest request = new UTIL_AsynchronousJobLauncher.DTO_AsynchronousJobRequest(foobars)
					.withQueueableJobSize(queueableJobSize)
					.withAsyncOptions(options);

			assertJobRan
					(
							request,
							new MockProcessorWithFinish(),
							IF_Async.AsynchronousExecutionStrategy.AUTO,
							true
					);

			Assert.areEqual(expectedJobCount, executeCallCounter, 'Execute should have been called ' + expectedJobCount + ' times for each chained job.');
		}
	}

	/**
	 * @description Verifies that Queueable jobs are chained (run serially) when the code trying to run an async job is already async
	 * for example its a batch or another queueable
	 */
	@IsTest
	private static void queueableChainIsTriggeredByAsyncContext()
	{
		System.runAs(getTestAdmin())
		{
			final Integer numberOfRecords = 4;
			final Integer expectedJobCount = 2; // 4 records / 2 per job = 2 jobs

			TST_Factory.insertFoobars(numberOfRecords);

			Test.startTest();

			runRequestWithFuture();

			Test.stopTest();

			Assert.areEqual(expectedJobCount, executeCallCounter, 'Execute should have been called ' + expectedJobCount + ' times for each chained job.');
		}
	}

	/**
	 * @description Execute the Job Launcher in an Async Context
	 */
	@Future
	@SuppressWarnings('PMD.AvoidFutureAnnotation')
	private static void runRequestWithFuture()
	{
		final Integer queueableJobSize = 2;

		// Configure AsyncOptions for test context
		AsyncOptions options = new AsyncOptions();
		options.maximumQueueableStackDepth = 2;

		IF_Queryable query = QRY_Builder.selectFrom(Foobar__c.SObjectType)
				.fields(new SEL_Foobar().fields);

		UTIL_AsynchronousJobLauncher.DTO_AsynchronousJobRequest request =
				new UTIL_AsynchronousJobLauncher.DTO_AsynchronousJobRequest(query)
						.withQueueableJobSize(queueableJobSize)
						.withAsyncOptions(options);

		UTIL_AsynchronousJobLauncher.process(request, new MockProcessorWithFinish());
	}

	/**
	 * @description Verifies that Queueable jobs are explicitly enqueued using the CHAINABLE_SINGLE_PARENT strategy.
	 */
	@IsTest
	private static void queueableSingleParentIsTriggeredByRun()
	{
		System.runAs(getTestAdmin())
		{
			Integer numberOfRecords = 2;

			List<Foobar__c> foobars = TST_Factory.newFoobars(numberOfRecords);

			AsyncOptions options = new AsyncOptions();
			options.maximumQueueableStackDepth = 1;

			UTIL_AdaptiveAsynchronousProcessor processor = new UTIL_AdaptiveAsynchronousProcessor(new MockProcessorWithFinish());

			UTIL_AdaptiveAsynchronousProcessor.DTO_ProcessSettings settings = new UTIL_AdaptiveAsynchronousProcessor.DTO_ProcessSettings();
			settings.executionStrategy = IF_Async.AsynchronousExecutionStrategy.AUTO;
			settings.queueableJobSize = 1;
			settings.asyncOptions = options;
			processor.configure(settings);

			UTIL_AdaptiveAsynchronousProcessor.INT_Process processInitializer = processor.initialise(foobars);

			Test.startTest();

			Id jobId = processInitializer.run();

			Test.stopTest();

			Assert.isNotNull(jobId, 'Job Id should not be null for forced CHAINABLE_SINGLE_PARENT strategy.');
			Assert.isTrue(executeWasCalled, 'Execute should have been called inside queueable.');
			Assert.isTrue(executionWasQueueable, 'Execution should have been identified as Queueable.');
		}
	}

	/**
	 * @description Force an error to be thrown by setting invalid Async Option, tests the correct error handling when attempting to kick of a job
	 */
	@IsTest
	private static void unexpectedErrorThrown()
	{
		System.runAs(getTestAdmin())
		{
			final Integer numberOfRecords = 1;
			List<Foobar__c> foobars = TST_Factory.newFoobars(numberOfRecords);

			LOG_Builder.ignoreTestMode = true;

			AsyncOptions invalidOptions = new AsyncOptions();
			invalidOptions.maximumQueueableStackDepth = -1;

			UTIL_AsynchronousJobLauncher.DTO_AsynchronousJobRequest request =
					new UTIL_AsynchronousJobLauncher.DTO_AsynchronousJobRequest(foobars)
							.withAsyncOptions(invalidOptions)
							.withExecutionStrategy(IF_Async.AsynchronousExecutionStrategy.CHAINABLE);

			try
			{
				Test.startTest();

				UTIL_AsynchronousJobLauncher.process(request, new MockProcessorWithFinish());

				Test.stopTest();

				Assert.fail('Should have thrown exception for invalid AsyncOptions');
			}
			catch(Exception error)
			{
				Assert.isInstanceOfType(error, InvalidParameterValueException.class, 'The correct exception type should be caught.');

				List<LogEntry__c> logs = new SEL_LogEntry().getAll();
				Assert.isFalse(logs.isEmpty(), 'LOG_Builder should have logged the error');
			}
		}
	}

	/**
	 * @description Verifies that withDelayMinutes sets the delay property correctly.
	 */
	@IsTest
	private static void withDelayMinutesSetsDelayProperty()
	{
		System.runAs(getTestAdmin())
		{
			UTIL_AsynchronousJobLauncher.DTO_AsynchronousJobRequest request =
					new UTIL_AsynchronousJobLauncher.DTO_AsynchronousJobRequest(new List<Object> {'test'})
							.withDelayMinutes(5);

			Assert.areEqual(5, request.delayMinutes, 'Delay minutes should be set to 5');
		}
	}

	/**
	 * @description Verifies that withDelayMinutes accepts zero delay.
	 */
	@IsTest
	private static void withDelayMinutesAcceptsZero()
	{
		System.runAs(getTestAdmin())
		{
			UTIL_AsynchronousJobLauncher.DTO_AsynchronousJobRequest request =
					new UTIL_AsynchronousJobLauncher.DTO_AsynchronousJobRequest(new List<Object> {'test'})
							.withDelayMinutes(0);

			Assert.areEqual(0, request.delayMinutes, 'Delay minutes should be set to 0');
		}
	}

	/**
	 * @description Verifies that withDelayMinutes accepts null delay.
	 */
	@IsTest
	private static void withDelayMinutesAcceptsNull()
	{
		System.runAs(getTestAdmin())
		{
			UTIL_AsynchronousJobLauncher.DTO_AsynchronousJobRequest request =
					new UTIL_AsynchronousJobLauncher.DTO_AsynchronousJobRequest(new List<Object> {'test'})
							.withDelayMinutes(null);

			Assert.isNull(request.delayMinutes, 'Delay minutes should be null');
		}
	}

	/**
	 * @description Verifies that withDelayMinutes accepts delays greater than 10 (with automatic chaining).
	 */
	@IsTest
	private static void withDelayMinutesAcceptsGreaterThanTen()
	{
		System.runAs(getTestAdmin())
		{
			UTIL_AsynchronousJobLauncher.DTO_AsynchronousJobRequest request =
					new UTIL_AsynchronousJobLauncher.DTO_AsynchronousJobRequest(new List<Object> {'test'})
							.withDelayMinutes(45);

			Assert.areEqual(45, request.delayMinutes, 'Delay minutes should accept values > 10');
		}
	}

	/**
	 * @description Verifies that withDelayMinutes throws exception for negative delay.
	 */
	@IsTest
	private static void withDelayMinutesRejectsNegative()
	{
		System.runAs(getTestAdmin())
		{
			try
			{
				new UTIL_AsynchronousJobLauncher.DTO_AsynchronousJobRequest(new List<Object> {'test'})
						.withDelayMinutes(-1);
				Assert.fail('Should throw IllegalArgumentException for negative delay');
			}
			catch(Exception error)
			{
				Assert.isInstanceOfType(error, IllegalArgumentException.class, 'Incorrect Exception Type');
			}
		}
	}

	/**
	 * @description Verifies that delay with short value (less than 10) processes after delay.
	 */
	@IsTest
	private static void delayEnqueuesHandlerWithShortDelay()
	{
		System.runAs(getTestAdmin())
		{
			executeWasCalled = false;
			List<Object> items = new List<Object> {'item1', 'item2'};

			AsyncOptions options = new AsyncOptions();
			options.maximumQueueableStackDepth = 3;

			UTIL_AsynchronousJobLauncher.DTO_AsynchronousJobRequest request =
					new UTIL_AsynchronousJobLauncher.DTO_AsynchronousJobRequest(items)
							.withDelayMinutes(5)
							.withAsyncOptions(options)
							.withExecutionStrategy(IF_Async.AsynchronousExecutionStrategy.CHAINABLE);

			Test.startTest();

			Id jobId = UTIL_AsynchronousJobLauncher.process(request, new MockProcessorWithFinish());

			Test.stopTest();

			Assert.isNotNull(jobId, 'Job ID should be returned');
			Assert.isTrue(executeWasCalled, 'Processor should execute after short delay');
		}
	}

	/**
	 * @description Verifies that the DelayedDispatchHandler can be instantiated correctly.
	 */
	@IsTest
	private static void delayedDispatchHandlerInstantiatesCorrectly()
	{
		System.runAs(getTestAdmin())
		{
			List<Object> items = new List<Object> {'item1'};

			UTIL_AsynchronousJobLauncher.DTO_AsynchronousJobRequest request =
					new UTIL_AsynchronousJobLauncher.DTO_AsynchronousJobRequest(items);

			UTIL_AsynchronousJobLauncher.DelayedDispatchHandler handler =
					new UTIL_AsynchronousJobLauncher.DelayedDispatchHandler(request, new MockProcessorWithFinish(), 5);

			Assert.isNotNull(handler, 'Handler should be instantiated');
		}
	}

	/**
	 * @description Verifies that the DelayedDispatchHandler dispatches processing when remaining time is zero.
	 */
	@IsTest
	private static void delayedDispatchHandlerDispatchesWhenRemainingMinutesIsZero()
	{
		System.runAs(getTestAdmin())
		{
			executeWasCalled = false;
			List<Object> items = new List<Object> {'item1', 'item2'};

			AsyncOptions options = new AsyncOptions();
			options.maximumQueueableStackDepth = 3;

			UTIL_AsynchronousJobLauncher.DTO_AsynchronousJobRequest request =
					new UTIL_AsynchronousJobLauncher.DTO_AsynchronousJobRequest(items)
							.withAsyncOptions(options)
							.withExecutionStrategy(IF_Async.AsynchronousExecutionStrategy.CHAINABLE);

			UTIL_AsynchronousJobLauncher.DelayedDispatchHandler handler =
					new UTIL_AsynchronousJobLauncher.DelayedDispatchHandler(request, new MockProcessorWithFinish(), 0);

			Test.startTest();

			System.enqueueJob(handler);

			Test.stopTest();

			Assert.isTrue(executeWasCalled, 'Processor should execute when remaining minutes is 0');
		}
	}

	/**
	 * @description Verifies that the MAX_DELAY_MINUTES constant is set correctly.
	 */
	@IsTest
	private static void maxDelayMinutesConstantIsCorrect()
	{
		System.runAs(getTestAdmin())
		{
			Assert.areEqual(10, UTIL_AsynchronousJobLauncher.MAX_DELAY_MINUTES, 'Max delay should be 10 minutes');
		}
	}

	/**
	 * @description Verifies the two-arg process(items, processor) convenience overload delegates correctly.
	 */
	@IsTest
	private static void processTwoArgOverloadDispatchesJob()
	{
		System.runAs(getTestAdmin())
		{
			executeWasCalled = false;
			finishWasCalled = false;
			List<Foobar__c> foobars = TST_Factory.newFoobars(1);

			Test.startTest();

			Id jobId = UTIL_AsynchronousJobLauncher.process(foobars, new MockProcessorWithFinish());

			Test.stopTest();

			Assert.isNotNull(jobId, 'Two-arg overload should return a job ID');
			Assert.isTrue(executeWasCalled, 'Execute should have been called by the two-arg overload');
		}
	}

	/**
	 * @description Verifies the three-arg process(items, processor, jobSize) overload applies the supplied job size.
	 */
	@IsTest
	private static void processThreeArgOverloadDispatchesJob()
	{
		System.runAs(getTestAdmin())
		{
			executeWasCalled = false;
			finishWasCalled = false;
			final Integer numberOfRecords = 4;
			final Integer jobSize = 2;
			List<Foobar__c> foobars = TST_Factory.newFoobars(numberOfRecords);

			Test.startTest();

			Id jobId = UTIL_AsynchronousJobLauncher.process(foobars, new MockProcessorWithFinish(), jobSize);

			Test.stopTest();

			Assert.isNotNull(jobId, 'Three-arg overload should return a job ID');
			Assert.isTrue(executeWasCalled, 'Execute should have been called by the three-arg overload');
		}
	}

	/**
	 * @description Verifies that DelayedDispatchHandler.execute chains itself when remainingMinutes is greater than zero.
	 * Test.stopTest runs the enqueued handler synchronously, which triggers its chaining enqueue and
	 * surfaces the expected stack-depth limit in the test harness. The coverage for the chainWithDelay
	 * path is produced by the enqueued handler before the stack-depth exception is raised.
	 */
	@IsTest
	private static void delayedDispatchHandlerChainsWhenRemainingMinutesGreaterThanZero()
	{
		System.runAs(getTestAdmin())
		{
			executeWasCalled = false;
			List<Object> items = new List<Object> {'item1'};

			AsyncOptions options = new AsyncOptions();
			options.maximumQueueableStackDepth = 2;

			UTIL_AsynchronousJobLauncher.DTO_AsynchronousJobRequest request =
					new UTIL_AsynchronousJobLauncher.DTO_AsynchronousJobRequest(items)
							.withAsyncOptions(options)
							.withExecutionStrategy(IF_Async.AsynchronousExecutionStrategy.CHAINABLE);

			UTIL_AsynchronousJobLauncher.DelayedDispatchHandler handler =
					new UTIL_AsynchronousJobLauncher.DelayedDispatchHandler(request, new MockProcessorWithFinish(), 5);

			Test.startTest();

			Id jobId = System.enqueueJob(handler);

			try
			{
				Test.stopTest();
			}
			catch(System.AsyncException asyncException)
			{
				Assert.isNotNull(asyncException.getMessage(), 'Stack-depth exception should carry a message');
			}

			Assert.isNotNull(jobId, 'Chained handler should be enqueued when remainingMinutes greater than zero');
			Assert.isFalse(executeWasCalled, 'Processor should not execute while the handler is still chaining for the delay');
		}
	}

	/**
	 * @description Mock implementation of both interfaces to test the full lifecycle, including the finish step.
	 */
	private virtual class MockProcessorWithFinish implements IF_Async.Processable, IF_Async.Finishable
	{
		/**
		 * @description Stores the lists of items passed to the execute method in each transaction.
		 */
		public List<List<Object>> processedItems = new List<List<Object>>();
		/**
		 * @description Stores the context from the finish method for assertion.
		 */
		public Database.BatchableContext finishContext;

		/**
		 * @description Sets a flag to confirm execution and captures the items.
		 *
		 * @param items The list of objects processed in the current transaction.
		 */
		public virtual void execute(List<Object> items)
		{
			executeCallCounter++;
			executeWasCalled = true;
			executionWasQueueable = System.isQueueable();
			processedItems.add(items);
		}

		/**
		 * @description Sets a flag to confirm completion and captures the final context.
		 *
		 * @param context The context provided by the platform upon job completion.
		 */
		public void finish(Database.BatchableContext context)
		{
			finishWasCalled = true;
			finishContext = context;
			executeJobId = context.getJobId();
			executeChildJobId = context.getChildJobId();
		}
	}

	/**
	 * @description Mock implementation that always throws an exception to test error handling.
	 */
	private class MockFailingProcessor extends MockProcessorWithFinish
	{
		/**
		 * @description Throws a TestException to simulate a failure during processing.
		 *
		 * @param items The list of objects that would have been processed.
		 */
		public override void execute(List<Object> items)
		{
			super.execute(items);
			throw new TestException('Simulating a processing error.');
		}
	}

	/**
	 * @description A custom exception for testing error handling.
	 */
	private class TestException extends Exception
	{
	}

	/**
	 * @description Retrieves the committed test admin user set up in @TestSetup for use with
	 * System.runAs, so each test body runs with a fresh permission-evaluation context.
	 *
	 * @return The test admin User record.
	 */
	private static User getTestAdmin()
	{
		return new SEL_User().findByCompanyName(TEST_ADMIN_COMPANY);
	}
}