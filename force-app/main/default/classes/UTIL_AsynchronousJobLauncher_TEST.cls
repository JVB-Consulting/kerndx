// SPDX-License-Identifier: Apache-2.0
/**
 * @description Test class for the UTIL_AsynchronousJobLauncher framework.
 *
 * @see UTIL_AsynchronousJobLauncher
 * @see UTIL_StatefulAsynchronousBatch
 *
 * @author Jason van Beukering
 *
 * @group Async Processing
 *
 * @date September 2025, November 2026
 */
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs,PMD.CyclomaticComplexity,PMD.CognitiveComplexity,PMD.NcssTypeCount')
@IsTest(seeAllData=false isParallel=false)
private class UTIL_AsynchronousJobLauncher_TEST
{
	/**
	 * @description Company name given to the admin user created in test setup. It is unique to this class, so getTestAdmin
	 * can find that one user again by company name.
	 */
	private static final String TEST_ADMIN_COMPANY = 'UTIL_AsynchronousJobLauncher_TEST-admin';

	/**
	 * @description First of two plain-text items a job is given in place of records. The test expects the failure log to
	 * show this text, which proves the logger can report items that are not records.
	 */
	private static final String FIRST_TEXT_ITEM = 'first text item';

	/**
	 * @description Second of the two plain-text items, so the test can check that the failure log lists both items
	 * separated by a comma.
	 */
	private static final String SECOND_TEXT_ITEM = 'second text item';

	/**
	 * @description Batch size carried by the metadata record staged in the batch-size tests, chosen to differ from
	 * the platform default so a size resolved from that record cannot be confused with the fallback.
	 */
	private static final Integer CONFIGURED_BATCH_SIZE = 7;

	/**
	 * @description The end of the location the delayed-dispatch handler writes its crash log entry from. The test adds
	 * it to the handler's class name to find that entry.
	 */
	private static final String HANDLER_CRASH_LOG_METHOD = '/logUnhandledException';

	/**
	 * @description The end of the location the delayed-dispatch handler writes its warning from when Salesforce refuses
	 * to start the job after the delay. The test adds it to the handler's class name to find that entry.
	 */
	private static final String HANDLER_DISPATCH_LOG_METHOD = '/dispatchProcessing';

	/**
	 * @description The end of the location the launcher writes its error from when Salesforce refuses to queue the
	 * delayed start of a launch. The test adds it to the launcher's class name to find that entry.
	 */
	private static final String DELAYED_START_LOG_METHOD = '/enqueueWithDelay';

	/**
	 * @description The message Salesforce gives in a test when a Queueable tries to start another Queueable.
	 */
	private static final String STACK_DEPTH_REFUSAL_MESSAGE = 'Maximum stack depth has been reached.';

	/**
	 * @description The message of the error a query used in the tests throws when it is read.
	 */
	private static final String QUERY_FAILURE_MESSAGE = 'Simulating a query that cannot be read.';

	/**
	 * @description Flag to confirm the execute method of a mock processor was called.
	 */
	private static Boolean executeWasCalled = false;
	/**
	 * @description How many times the finish method of a mock processor was called in the test.
	 */
	private static Integer finishCallCount = 0;
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
	 * @description Number of items given to a job in the tests where Salesforce refuses to start one of its jobs.
	 */
	private static final Integer REFUSED_LAUNCH_ITEM_COUNT = 10;

	/**
	 * @description Job size of one item per job, so each item gets its own Queueable and the tests can tell which
	 * items were started and which were not.
	 */
	private static final Integer ONE_ITEM_PER_JOB = 1;

	/**
	 * @description Length of the random text used for each plain-text item.
	 */
	private static final Integer TEXT_ITEM_LENGTH = 12;

	/**
	 * @description The end of the location the processor writes its error log entry from when it cannot start a job.
	 * The test adds it to the processor's class name to find that entry.
	 */
	private static final String PROCESSOR_RUN_LOG_METHOD = '/run';

	/**
	 * @description Number of records the stateful batch tests give a job.
	 */
	private static final Integer STATEFUL_RECORD_COUNT = 5;

	/**
	 * @description How many times execute runs in a batch test. A test may run only one chunk of a batch, so each
	 * batch test sets its batch size to its number of records.
	 */
	private static final Integer ONE_CHUNK = 1;

	/**
	 * @description Number of records a job is given in the tests where every chunk or hop throws, or where a chain runs.
	 */
	private static final Integer SHORT_JOB_ITEM_COUNT = 3;

	/**
	 * @description Delay in minutes used to prove a refused launch is refused before the delayed start is queued.
	 */
	private static final Integer LAUNCH_DELAY_MINUTES = 5;

	/**
	 * @description The job type the platform writes on the job row of a batch.
	 */
	private static final String BATCH_JOB_TYPE = 'BatchApex';

	/**
	 * @description The end of the location the processor writes its skipped-finish warning from. The test adds it to
	 * the processor's class name to find that entry.
	 */
	private static final String PROCESSOR_FINISH_LOG_METHOD = '/finish';

	/**
	 * @description The end of the location the processor writes a failed chunk's error from, which is also where the
	 * batch error listener files the same failure.
	 */
	private static final String PROCESSOR_EXECUTE_LOG_METHOD = '/execute';

	/**
	 * @description The record Ids MockStatefulProcessor had collected when its finish method ran, or null if it never ran.
	 */
	private static List<Id> finishSeenIds;

	/**
	 * @description The totals MockStatefulProcessor had built when its finish method ran, or null if it never ran.
	 */
	private static MockTotals finishTotals;

	/**
	 * @description The job Id MockStatefulProcessor was given in its finish method, or null if it never ran.
	 */
	private static Id finishJobId;

	/**
	 * @description Every item MockProcessor was given, across all its jobs, in the order the jobs ran.
	 */
	private static final List<Object> ITEMS_PROCESSED_BY_MOCK_PROCESSOR = new List<Object>();

	/**
	 * @description The cause of the refused launch that the test Queueable caught, or null if it caught none.
	 */
	private static Exception refusedLaunchCause;

	/**
	 * @description How many items the refused launch caught by the test Queueable said were not started.
	 */
	private static Integer refusedLaunchUnsentItemCount;

	/**
	 * @description The items the refused launch caught by the test Queueable said were not started, or null if it
	 * caught none.
	 */
	private static List<Object> refusedLaunchUnsentItems;

	/**
	 * @description The failure that is not a refused start, kept by the future method that starts a batch where
	 * Salesforce does not allow one, or null if it caught none.
	 */
	private static Exception otherLaunchFailure;

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
							new MockProcessor(),
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
	 * @description Starts a job, waits for it to end, and checks that it ran. A processor with a finish step runs under
	 * BATCH or CHAINABLE, never as parallel jobs, so its finish step must have run exactly once. A processor without a
	 * finish step is not checked for one.
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
		finishCallCount = 0;

		request.withExecutionStrategy(strategy);

		Test.startTest();

		Id jobId = UTIL_AsynchronousJobLauncher.process(request, processorLogic);

		Test.stopTest();

		Assert.isNotNull(jobId, 'Expected the launcher to return a job Id.');
		Assert.isTrue(executeWasCalled, 'Expected the execute method to have been called.');
		Assert.areEqual(shouldRunQueueable, executionWasQueueable, 'Expected the job to run as ' + (shouldRunQueueable ? 'a Queueable' : 'a batch'));
		if(processorLogic instanceof IF_Async.Finishable)
		{
			Assert.areEqual(1, finishCallCount, 'Expected the finish method to have been called exactly once.');
			Assert.isNotNull(executeJobId, 'Expected the finish method to have been given a job Id.');
		}
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
	 * finalizer logs the unhandled exception, with the records the failed job was given, so you can see it in
	 * LogEntryEvent__e and LogEntry__c.
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
	 * @description Verifies that the queueable unhandled-exception log renders items that are not records as their
	 * text. The scope used to be rendered through a ternary whose branches Apex unified to Id, so a plain-text item
	 * turned every job-level failure into an "Invalid id" exception inside the log itself, burying the failure being
	 * reported.
	 */
	@IsTest
	private static void queueableExceptionWithTextItemsIsLogged()
	{
		System.runAs(getTestAdmin())
		{
			List<Object> items = new List<Object> {FIRST_TEXT_ITEM, SECOND_TEXT_ITEM};

			UTIL_AsynchronousJobLauncher.DTO_AsynchronousJobRequest request = new UTIL_AsynchronousJobLauncher.DTO_AsynchronousJobRequest(items)
					.withBatchSize(items.size())
					.withQueueableJobSize(items.size());

			assertExceptionFiresEvents(request, false, FIRST_TEXT_ITEM + UTIL_String.COMMA + SECOND_TEXT_ITEM);
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

		assertExceptionFiresEvents(request, runBatchJob, String.valueOf(foobars[0].Id));
	}

	/**
	 * @description Verifies that an exception in the processor logic is caught and surfaces error events, and that
	 * the queueable path's durable log names the failed job's scope.
	 *
	 * @param request The job request carrying the items to process
	 * @param runBatchJob Indicates if the Job should be run as batch else it will run as queueable
	 * @param expectedJobScope The scope text the unhandled-exception log should carry (queueable path only)
	 */
	private static void assertExceptionFiresEvents(UTIL_AsynchronousJobLauncher.DTO_AsynchronousJobRequest request, Boolean runBatchJob, String expectedJobScope)
	{
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
								expectedJobScope,
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

			UTIL_AsynchronousJobLauncher.process(request, new MockProcessor());
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
	 * @description Verifies that the process initializer's run() enqueues the Queueable jobs itself. Two records at a
	 * job size of one, under AUTO with a full queueable budget, resolve PARALLEL_QUEUEABLES: both jobs are enqueued at
	 * once and each record is processed by its own Queueable, so a stack depth of one is enough because nothing chains.
	 */
	@IsTest
	private static void queueableParallelIsTriggeredByRun()
	{
		System.runAs(getTestAdmin())
		{
			Integer numberOfRecords = 2;
			Integer expectedJobCount = 2;

			List<Foobar__c> foobars = TST_Factory.newFoobars(numberOfRecords);

			AsyncOptions options = new AsyncOptions();
			options.maximumQueueableStackDepth = 1;

			UTIL_AdaptiveAsynchronousProcessor processor = new UTIL_AdaptiveAsynchronousProcessor(new MockProcessor());

			UTIL_AdaptiveAsynchronousProcessor.DTO_ProcessSettings settings = new UTIL_AdaptiveAsynchronousProcessor.DTO_ProcessSettings();
			settings.executionStrategy = IF_Async.AsynchronousExecutionStrategy.AUTO;
			settings.queueableJobSize = 1;
			settings.asyncOptions = options;
			processor.configure(settings);

			UTIL_AdaptiveAsynchronousProcessor.INT_Process processInitializer = processor.initialise(foobars);

			Test.startTest();

			Id jobId = processInitializer.run();
			Assert.areEqual(expectedJobCount, UTIL_Limits.queueableJobs().used(), 'Expected ' + expectedJobCount + ' parallel Queueable jobs to be enqueued.');

			Test.stopTest();

			Assert.isNotNull(jobId, 'Job Id should not be null for the PARALLEL_QUEUEABLES strategy.');
			Assert.isTrue(executionWasQueueable, 'Execution should have been identified as Queueable.');
			Assert.areEqual(expectedJobCount, executeCallCounter, 'Execute should have been called once per record, one Queueable each.');
		}
	}

	/**
	 * @description Verifies that a list one item longer than the job size still reaches the Queueable jobs in full.
	 * With a job size of 200 and 201 records, two parallel jobs start and together they process every record.
	 */
	@IsTest
	private static void shouldProcessEveryRecordWhenParallelItemCountIsOneOverJobSize()
	{
		System.runAs(getTestAdmin())
		{
			Integer numberOfRecords = 201;
			Integer jobSize = 200;
			Integer expectedJobCount = 2;

			List<Foobar__c> foobars = TST_Factory.newFoobars(numberOfRecords);

			AsyncOptions options = new AsyncOptions();
			options.maximumQueueableStackDepth = 1;

			UTIL_AdaptiveAsynchronousProcessor processor = new UTIL_AdaptiveAsynchronousProcessor(new MockProcessor());

			UTIL_AdaptiveAsynchronousProcessor.DTO_ProcessSettings settings = new UTIL_AdaptiveAsynchronousProcessor.DTO_ProcessSettings();
			settings.executionStrategy = IF_Async.AsynchronousExecutionStrategy.PARALLEL_QUEUEABLES;
			settings.queueableJobSize = jobSize;
			settings.asyncOptions = options;
			processor.configure(settings);

			UTIL_AdaptiveAsynchronousProcessor.INT_Process processInitializer = processor.initialise(foobars);

			Test.startTest();
			processInitializer.run();
			Test.stopTest();

			Assert.isTrue(executionWasQueueable, 'Expected the work to run as a Queueable job.');
			Assert.areEqual(expectedJobCount, executeCallCounter, 'Expected two parallel jobs for 201 records at a job size of 200.');
			Assert.areEqual(numberOfRecords, ITEMS_PROCESSED_BY_MOCK_PROCESSOR.size(), 'Expected every record to reach a job.');
		}
	}

	/**
	 * @description Verifies the finalizer's chained hop enqueues and executes when the settings carry
	 * no AsyncOptions, so the re-enqueue and the first enqueue treat a null the same way. The queueable
	 * budget is simulated to one so the strategy resolves CHAINABLE and the chained path actually runs.
	 */
	@IsTest
	private static void chainsNextHopWhenNoAsyncOptionsConfigured()
	{
		System.runAs(getTestAdmin())
		{
			Integer numberOfRecords = 2;
			Integer expectedJobCount = 2;

			UTIL_AdaptiveAsynchronousProcessor.simulateQueueableLimits = true;

			List<Foobar__c> foobars = TST_Factory.newFoobars(numberOfRecords);

			UTIL_AdaptiveAsynchronousProcessor processor = new UTIL_AdaptiveAsynchronousProcessor(new MockProcessorWithFinish());

			UTIL_AdaptiveAsynchronousProcessor.DTO_ProcessSettings settings = new UTIL_AdaptiveAsynchronousProcessor.DTO_ProcessSettings();
			settings.executionStrategy = IF_Async.AsynchronousExecutionStrategy.AUTO;
			settings.queueableJobSize = 1;
			processor.configure(settings);

			UTIL_AdaptiveAsynchronousProcessor.INT_Process processInitializer = processor.initialise(foobars);

			Test.startTest();

			Id jobId = processInitializer.run();

			Test.stopTest();

			Assert.isNotNull(jobId, 'Job Id should not be null when no AsyncOptions are configured.');
			Assert.areEqual(expectedJobCount, executeCallCounter, 'The chained hop should have executed with no AsyncOptions configured.');
		}
	}

	/**
	 * @description Force an error to be thrown by setting invalid Async Option, tests the correct error handling when attempting to kick of a job.
	 * Salesforce refuses to start the job, so the caller gets the exception that names the items not started, with the
	 * platform's error as its cause.
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
				Assert.isInstanceOfType(error, UTIL_Exceptions.LaunchRefusedException.class, 'Expected the refused start to reach the caller, got ' + error);
				Assert.isInstanceOfType(error.getCause(), InvalidParameterValueException.class, 'Expected the invalid option to be the cause, got ' + error.getCause());

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
	 * @description Verifies that a crash inside the delayed-dispatch handler still leaves a log entry. The job is
	 * launched with a delay, so the launcher first queues the delayed-dispatch handler. When the delay ends, the
	 * handler starts the job. The job is built from a query that throws when it is read, so the handler crashes
	 * before any job is started. A Finalizer (code the platform runs after a Queueable ends, even when it crashes)
	 * must then write an error entry for the handler's job, and the processor must never run. A job built from a query
	 * has no list of items yet, so the entry has no job scope (the list of items a job was given).
	 */
	@IsTest
	private static void shouldLogACrashOfTheDelayedDispatchHandler()
	{
		System.runAs(getTestAdmin())
		{
			final Integer delayMinutes = 1;

			LOG_Builder.ignoreTestMode = true;
			executeWasCalled = false;

			UTIL_AsynchronousJobLauncher.DTO_AsynchronousJobRequest request =
					new UTIL_AsynchronousJobLauncher.DTO_AsynchronousJobRequest(new FailingQueryable())
							.withDelayMinutes(delayMinutes)
							.withExecutionStrategy(IF_Async.AsynchronousExecutionStrategy.CHAINABLE);

			Test.startTest();

			Id jobId = UTIL_AsynchronousJobLauncher.process(request, new MockProcessorWithFinish());

			try
			{
				Test.stopTest();
				Assert.fail('Expected the delayed-dispatch handler to crash when it reads a query that throws.');
			}
			catch(Exception error)
			{
				Assert.isInstanceOfType(error, TestException.class, 'Expected the failing query to make the handler crash, got ' + error);
				Assert.areEqual(QUERY_FAILURE_MESSAGE, error.getMessage(), 'Expected the crash to carry the message of the failing query.');
			}

			String handlerLogLocation = UTIL_System.getRuntimeTypeName(new UTIL_AsynchronousJobLauncher.DelayedDispatchHandler(request, null, 0))
					+ HANDLER_CRASH_LOG_METHOD;

			List<LogEntry__c> handlerCrashLogs = new SEL_LogEntry().findAllByMethod(handlerLogLocation);
			Assert.areEqual(1, handlerCrashLogs.size(), 'Expected the Finalizer to write one log entry for the crashed delayed-dispatch handler job.');

			LogEntry__c handlerCrashLog = handlerCrashLogs[0];
			Assert.areEqual(LoggingLevel.ERROR.name(), handlerCrashLog.LogLevel__c, 'Expected the crash to be logged as an error.');
			Assert.areEqual(TestException.class.getName(), handlerCrashLog.ExceptionType__c, 'Expected the log entry to name the exception that crashed the handler.');
			// The job id the platform returns can be the 15-character form, so the ids are compared as ids, not as text.
			Assert.areEqual(jobId, Id.valueOf(handlerCrashLog.RecordId__c), 'Expected the log entry to name the crashed handler job.');
			Assert.isFalse(executeWasCalled, 'Expected the processor never to run, because the handler crashed before the job started.');

			Map<String, Object> logContext = SEL_LogEntry.parseContextDataForTest(handlerCrashLog);
			Assert.isNull(logContext?.get(LOG_Engine.CONTEXT_JOB_SCOPE), 'Expected no job scope on the crash log entry of a job built from a query.');
		}
	}

	/**
	 * @description Proves that when Salesforce refuses to start the job after the delay, the delayed-dispatch handler
	 * writes one error entry and then ends normally. The work is lost, so the entry is an error, not a warning.
	 *
	 * The entry names the processor's class, the number of items, the delay that was asked for and the error Salesforce
	 * gave. It is linked to the handler's job and lists the record the job was given.
	 *
	 * The handler says that it handles a refused start, so the processor writes no error entry: the handler's entry is
	 * the only error entry. The handler's Finalizer (code the platform runs after a Queueable ends) writes nothing,
	 * because the handler did not crash.
	 *
	 * In a test a Queueable cannot start another Queueable, so the start inside the handler is refused.
	 */
	@IsTest
	private static void shouldRecordARefusedLaunchAndEndNormally()
	{
		System.runAs(getTestAdmin())
		{
			final Integer delayMinutes = 1;

			LOG_Builder.ignoreTestMode = true;
			executeWasCalled = false;

			List<Foobar__c> foobars = TST_Factory.insertFoobars(1);
			MockProcessorWithFinish processorLogic = new MockProcessorWithFinish();

			UTIL_AsynchronousJobLauncher.DTO_AsynchronousJobRequest request =
					new UTIL_AsynchronousJobLauncher.DTO_AsynchronousJobRequest(foobars)
							.withDelayMinutes(delayMinutes)
							.withExecutionStrategy(IF_Async.AsynchronousExecutionStrategy.AUTO);

			Test.startTest();
			Id jobId = UTIL_AsynchronousJobLauncher.process(request, processorLogic);
			Test.stopTest();

			String handlerName = UTIL_System.getRuntimeTypeName(new UTIL_AsynchronousJobLauncher.DelayedDispatchHandler(request, null, 0));

			List<LogEntry__c> errorEntries = new SEL_LogEntry().findByLogLevel(LoggingLevel.ERROR.name());
			Assert.areEqual(1, errorEntries.size(), 'Expected exactly one error entry for the refused start: the handler\'s own.');

			LogEntry__c refusalEntry = errorEntries[0];
			Assert.areEqual
					(
							handlerName + HANDLER_DISPATCH_LOG_METHOD,
							refusalEntry.ClassMethod__c,
							'Expected the one error entry to be written by the handler at its dispatch method.'
					);
			Assert.areEqual
					(
							String.format
									(
											System.Label.AsyncLauncher_DelayedDispatchRefused,
											new List<Object>
											{
													UTIL_System.getRuntimeTypeName(processorLogic),
													String.valueOf(foobars.size()),
													String.valueOf(delayMinutes),
													STACK_DEPTH_REFUSAL_MESSAGE
											}
									),
							refusalEntry.Message__c,
							'Expected the error entry to name the class, the number of items, the delay and the error Salesforce gave.'
					);
			// The job id the platform returns can be the 15-character form, so the ids are compared as ids, not as text.
			Assert.areEqual(jobId, Id.valueOf(refusalEntry.RecordId__c), 'Expected the error entry to be linked to the handler job.');
			Assert.areEqual
					(
							String.valueOf(foobars[0].Id),
							String.valueOf(SEL_LogEntry.parseContextDataForTest(refusalEntry)?.get(LOG_Engine.CONTEXT_JOB_SCOPE)),
							'Expected the error entry to list the record the delayed job was given.'
					);

			Assert.isTrue
					(
							new SEL_LogEntry().findAllByMethod(handlerName + HANDLER_CRASH_LOG_METHOD).isEmpty(),
							'Expected the Finalizer to write nothing, because the handler ended normally.'
					);
			Assert.isTrue(findRunErrors().isEmpty(), 'Expected no error entry from the processor, because the handler handles the refused start.');
			Assert.isFalse(executeWasCalled, 'Expected the processor never to run, because its job was not started.');
		}
	}

	/**
	 * @description Finds the error entries the processor wrote when it could not start a job.
	 *
	 * @return The error entries written at the processor's run method.
	 */
	private static List<LogEntry__c> findRunErrors()
	{
		String runLogLocation = UTIL_System.getRuntimeTypeName(new UTIL_AdaptiveAsynchronousProcessor()) + PROCESSOR_RUN_LOG_METHOD;
		List<LogEntry__c> runErrors = new List<LogEntry__c>();
		for(LogEntry__c runLog : new SEL_LogEntry().findAllByMethod(runLogLocation))
		{
			if(LoggingLevel.ERROR.name().equals(runLog.LogLevel__c))
			{
				runErrors.add(runLog);
			}
		}
		return runErrors;
	}

	/**
	 * @description Checks that the processor wrote exactly one error entry when it could not start a job, and that the
	 * entry names the type of the exception.
	 *
	 * @param expectedExceptionType The type name of the exception the entry should name.
	 */
	private static void assertOneRunError(String expectedExceptionType)
	{
		List<LogEntry__c> runErrors = findRunErrors();
		Assert.areEqual(1, runErrors.size(), 'Expected the processor to write one error entry when it could not start the job.');
		Assert.areEqual(expectedExceptionType, runErrors[0].ExceptionType__c, 'Expected the error entry to name the exception that stopped the start.');
	}

	/**
	 * @description Proves that when Salesforce refuses to queue the delayed start of a launch, the caller gets the
	 * exception that names every item of the request, with the error Salesforce raised as its cause, and that the
	 * launcher writes exactly one error entry for it. In a test a Queueable cannot start another Queueable, so a launch
	 * with a delay made from inside a test Queueable is refused when the launcher queues its delayed start. The
	 * processor is never reached, so it writes no error of its own.
	 */
	@IsTest
	private static void shouldThrowAndLogOnceWhenTheDelayedStartIsRefused()
	{
		System.runAs(getTestAdmin())
		{
			LOG_Builder.ignoreTestMode = true;

			List<Foobar__c> foobars = TST_Factory.newFoobars(SHORT_JOB_ITEM_COUNT);

			UTIL_AsynchronousJobLauncher.DTO_AsynchronousJobRequest request =
					new UTIL_AsynchronousJobLauncher.DTO_AsynchronousJobRequest(foobars)
							.withDelayMinutes(LAUNCH_DELAY_MINUTES);

			Test.startTest();
			System.enqueueJob(new RefusedDelayedLauncher(request));
			Test.stopTest();

			Assert.isInstanceOfType(refusedLaunchCause, AsyncException.class, 'Expected the refused delayed start to be the cause, got ' + refusedLaunchCause);
			Assert.areEqual(STACK_DEPTH_REFUSAL_MESSAGE, refusedLaunchCause.getMessage(), 'Expected the cause to carry the error Salesforce gave.');
			List<Object> expectedItems = new List<Object>();
			expectedItems.addAll(foobars);
			Assert.areEqual(expectedItems, refusedLaunchUnsentItems, 'Expected every item of the request to be named as not started, in order.');

			List<LogEntry__c> startErrors = new SEL_LogEntry().findAllByMethod(UTIL_AsynchronousJobLauncher.class.getName() + DELAYED_START_LOG_METHOD);
			Assert.areEqual(1, startErrors.size(), 'Expected the launcher to write one entry for the refused delayed start.');
			Assert.areEqual(LoggingLevel.ERROR.name(), startErrors[0].LogLevel__c, 'Expected the refused delayed start to be logged as an error.');
			Assert.areEqual
					(
							UTIL_Exceptions.LaunchRefusedException.class.getName(),
							startErrors[0].ExceptionType__c,
							'Expected the error entry to name the exception that says which items were not started.'
					);

			String runLogLocation = UTIL_System.getRuntimeTypeName(new UTIL_AdaptiveAsynchronousProcessor()) + PROCESSOR_RUN_LOG_METHOD;
			Assert.isTrue(new SEL_LogEntry().findAllByMethod(runLogLocation).isEmpty(), 'Expected no entry from the processor, which was never reached.');
			Assert.areEqual(0, executeCallCounter, 'Expected the processor never to run.');
		}
	}

	/**
	 * @description Proves the batch size a job runs at is read from the `AsynchronousJobSetting__mdt` record named
	 * for the Processable class doing the work, which is the class a subscriber names their record after. The
	 * launcher writes the resolved size back onto the request, so the request is where the resolved value is read.
	 */
	@IsTest
	private static void batchSizeComesFromRecordNamedForProcessableClass()
	{
		System.runAs(getTestAdmin())
		{
			final Integer numberOfRecords = 1;

			IF_Async.Processable processorLogic = new MockProcessorWithFinish();

			SEL_AsynchronousJobSetting.mockedSetting = (AsynchronousJobSetting__mdt)TST_Builder.of(AsynchronousJobSetting__mdt.SObjectType)
					.withOverride(AsynchronousJobSetting__mdt.DeveloperName, toSettingName(UTIL_System.getRuntimeTypeName(processorLogic)))
					.withOverride(AsynchronousJobSetting__mdt.BatchSize__c, CONFIGURED_BATCH_SIZE)
					.withoutInsertion()
					.build();

			UTIL_AsynchronousJobLauncher.DTO_AsynchronousJobRequest request =
					new UTIL_AsynchronousJobLauncher.DTO_AsynchronousJobRequest(TST_Factory.newFoobars(numberOfRecords));

			assertJobRan(request, processorLogic, IF_Async.AsynchronousExecutionStrategy.BATCH, false);

			Assert.areEqual(CONFIGURED_BATCH_SIZE, request.batchJobSize, 'Batch size should come from the record named for the Processable class');
		}
	}

	/**
	 * @description Proves a job with no matching metadata record and no size supplied in code still runs at the
	 * platform default, pinning the behaviour of every job that has no record of its own.
	 */
	@IsTest
	private static void batchSizeFallsBackToDefaultWhenNoRecordIsNamedForTheProcessableClass()
	{
		System.runAs(getTestAdmin())
		{
			final Integer numberOfRecords = 1;

			UTIL_AsynchronousJobLauncher.DTO_AsynchronousJobRequest request =
					new UTIL_AsynchronousJobLauncher.DTO_AsynchronousJobRequest(TST_Factory.newFoobars(numberOfRecords));

			assertJobRan(request, new MockProcessorWithFinish(), IF_Async.AsynchronousExecutionStrategy.BATCH, false);

			Assert.areEqual(UTIL_SObjectDescribe.DEFAULT_BATCH_SIZE, request.batchJobSize, 'Batch size should fall back to the platform default');
		}
	}

	/**
	 * @description Renders an Apex class name the way a metadata record is named for it, putting an underscore where
	 * an inner class carries a dot, which a metadata DeveloperName cannot contain.
	 *
	 * @param className The Apex class name to render.
	 *
	 * @return The DeveloperName form of the supplied class name.
	 */
	private static String toSettingName(String className)
	{
		return UTIL_String.replace(className, UTIL_String.DOT, UTIL_String.UNDERSCORE);
	}

	/**
	 * @description Proves that when Salesforce refuses to start a job part way through a list, the exception names the
	 * items of that job and of every job after it, in list order. The job options carry a duplicate signature, so
	 * Salesforce starts the first job and refuses the second one, which has the same signature. It also proves that the
	 * processor writes exactly one error log entry for the refused start.
	 */
	@IsTest
	private static void shouldCarryTheChunksAfterTheOneADuplicateSignatureRefused()
	{
		System.runAs(getTestAdmin())
		{
			LOG_Builder.ignoreTestMode = true;

			List<Foobar__c> foobars = TST_Factory.newFoobars(REFUSED_LAUNCH_ITEM_COUNT);

			AsyncOptions options = new AsyncOptions();
			options.duplicateSignature = QueueableDuplicateSignature.builder().addId(UserInfo.getUserId()).build();

			UTIL_AsynchronousJobLauncher.DTO_AsynchronousJobRequest request = new UTIL_AsynchronousJobLauncher.DTO_AsynchronousJobRequest(foobars)
					.withExecutionStrategy(IF_Async.AsynchronousExecutionStrategy.PARALLEL_QUEUEABLES)
					.withQueueableJobSize(ONE_ITEM_PER_JOB)
					.withAsyncOptions(options);

			Test.startTest();
			try
			{
				UTIL_AsynchronousJobLauncher.process(request, new MockProcessor());
				Assert.fail('Expected Salesforce to refuse the second job, which has the same duplicate signature as the first.');
			}
			catch(UTIL_Exceptions.LaunchRefusedException refused)
			{
				Assert.isInstanceOfType(refused.getCause(), DuplicateMessageException.class, 'Expected the duplicate signature to be the cause, got ' + refused.getCause());
				Assert.areEqual(REFUSED_LAUNCH_ITEM_COUNT - 1, refused.unsentItems.size(), 'Expected every record except the first to be named as not started.');
				for(Integer index = 0; index < refused.unsentItems.size(); index++)
				{
					Assert.areEqual(foobars[index + 1], refused.unsentItems[index], 'Expected the records not started to keep their list order, at position ' + index);
				}
			}
			Test.stopTest();

			Assert.areEqual(1, executeCallCounter, 'Expected only the first job to run.');
			Assert.areEqual(new List<Object> {foobars[0]}, ITEMS_PROCESSED_BY_MOCK_PROCESSOR, 'Expected the first record to be the one processed.');

			String runLogLocation = UTIL_System.getRuntimeTypeName(new UTIL_AdaptiveAsynchronousProcessor()) + PROCESSOR_RUN_LOG_METHOD;
			List<LogEntry__c> runLogs = new SEL_LogEntry().findAllByMethod(runLogLocation);
			Assert.areEqual(1, runLogs.size(), 'Expected one log entry for the refused start.');
			Assert.areEqual(LoggingLevel.ERROR.name(), runLogs[0].LogLevel__c, 'Expected the refused start to be logged as an error.');
			Assert.areEqual
					(
							UTIL_Exceptions.LaunchRefusedException.class.getName(),
							runLogs[0].ExceptionType__c,
							'Expected the log entry to name the exception that says which items were not started.'
					);
		}
	}

	/**
	 * @description Proves that when Salesforce refuses the very first job of a list, the exception names every record,
	 * in list order, and no job of the launch runs. Before the launch, the test starts one job that does nothing and carries a duplicate
	 * signature. The launch uses the same signature, so Salesforce refuses its first job.
	 */
	@IsTest
	private static void shouldCarryEveryItemWhenTheFirstParallelEnqueueIsRefused()
	{
		System.runAs(getTestAdmin())
		{
			final Integer numberOfItems = 2;

			List<Foobar__c> foobars = TST_Factory.newFoobars(numberOfItems);

			AsyncOptions options = new AsyncOptions();
			options.duplicateSignature = QueueableDuplicateSignature.builder().addId(UserInfo.getUserId()).build();

			UTIL_AsynchronousJobLauncher.DTO_AsynchronousJobRequest request = new UTIL_AsynchronousJobLauncher.DTO_AsynchronousJobRequest(foobars)
					.withExecutionStrategy(IF_Async.AsynchronousExecutionStrategy.PARALLEL_QUEUEABLES)
					.withQueueableJobSize(ONE_ITEM_PER_JOB)
					.withAsyncOptions(options);

			Test.startTest();
			System.enqueueJob(new DoNothingQueueable(), options);
			try
			{
				UTIL_AsynchronousJobLauncher.process(request, new MockProcessor());
				Assert.fail('Expected Salesforce to refuse the first job, which has the same duplicate signature as the job already started.');
			}
			catch(UTIL_Exceptions.LaunchRefusedException refused)
			{
				Assert.isInstanceOfType(refused.getCause(), DuplicateMessageException.class, 'Expected the duplicate signature to be the cause, got ' + refused.getCause());
				Assert.areEqual(new List<Object> {foobars[0], foobars[1]}, refused.unsentItems, 'Expected every record to be named as not started, in list order.');
			}
			Test.stopTest();

			Assert.areEqual(0, executeCallCounter, 'Expected no job of the launch to run.');
		}
	}

	/**
	 * @description Proves that when the processor runs inside a Queueable it starts one chained job, and when Salesforce
	 * refuses that job the exception names every item. In a test, a Queueable cannot start another Queueable, so the
	 * start is refused.
	 */
	@IsTest
	private static void shouldCarryEveryItemWhenAChainableEnqueueIsRefused()
	{
		System.runAs(getTestAdmin())
		{
			final Integer numberOfItems = 3;

			Test.startTest();
			System.enqueueJob(new RefusedChainLauncher(newTextItems(numberOfItems)));
			Test.stopTest();

			Assert.isInstanceOfType(refusedLaunchCause, AsyncException.class, 'Expected the refused chained start to be the cause, got ' + refusedLaunchCause);
			Assert.areEqual(numberOfItems, refusedLaunchUnsentItemCount, 'Expected every item to be named as not started.');
		}
	}

	/**
	 * @description Proves that a refused start still writes its error entry when the code that started the job did not
	 * say it handles a refusal. Code that does not catch the refusal may leave no other record that the job did not
	 * start. The refusal still reaches that code.
	 *
	 * In a test, a Queueable cannot start another Queueable, so the start is refused.
	 */
	@IsTest
	@SuppressWarnings('PMD.KernNoRawEnqueueJob')
	private static void shouldStillWriteAnErrorEntryForARefusalNoCallerHandles()
	{
		System.runAs(getTestAdmin())
		{
			LOG_Builder.ignoreTestMode = true;

			Test.startTest();
			System.enqueueJob(new RefusedChainLauncher(newTextItems(SHORT_JOB_ITEM_COUNT)));
			Test.stopTest();

			Assert.isInstanceOfType(refusedLaunchCause, AsyncException.class, 'Expected the refusal to reach the code that started the job, got ' + refusedLaunchCause);
			assertOneRunError(UTIL_Exceptions.LaunchRefusedException.class.getName());
		}
	}

	/**
	 * @description Proves that a failure that is not a refused start still writes its error entry, even when the code
	 * that started the job said it handles a refusal. The error still reaches the code that started the job.
	 *
	 * The job is forced to run as Batch Apex from inside a future method, where Salesforce does not allow a batch to
	 * start, so the start fails with an error that is not a refusal.
	 */
	@IsTest
	private static void shouldStillWriteAnErrorEntryForAnyOtherFailure()
	{
		System.runAs(getTestAdmin())
		{
			LOG_Builder.ignoreTestMode = true;

			Test.startTest();
			runHandledBatchRequestWithFuture();
			Test.stopTest();

			Assert.isNotNull(otherLaunchFailure, 'Expected the failure to reach the code that started the job.');
			Assert.isNotInstanceOfType(otherLaunchFailure, UTIL_Exceptions.LaunchRefusedException.class, 'Expected a failure that is not a refused start.');
			assertOneRunError(otherLaunchFailure.getTypeName());
		}
	}

	/**
	 * @description Starts a job that is forced to run as Batch Apex and says it handles a refused start, from inside a
	 * future method. Salesforce does not allow a batch to start there, so the start fails. Keeps the failure.
	 */
	@Future
	@SuppressWarnings('PMD.AvoidFutureAnnotation')
	private static void runHandledBatchRequestWithFuture()
	{
		UTIL_AsynchronousJobLauncher.DTO_AsynchronousJobRequest request =
				new UTIL_AsynchronousJobLauncher.DTO_AsynchronousJobRequest(newTextItems(SHORT_JOB_ITEM_COUNT))
						.withExecutionStrategy(IF_Async.AsynchronousExecutionStrategy.BATCH)
						.withLaunchRefusalHandledByCaller();
		try
		{
			UTIL_AsynchronousJobLauncher.process(request, new MockProcessor());
			Assert.fail('Expected Salesforce not to allow a batch to start from inside a future method.');
		}
		catch(Exception error)
		{
			otherLaunchFailure = error;
		}
	}

	/**
	 * @description Proves that when Salesforce refuses to queue the delayed start of a launch whose code said it handles
	 * a refusal, the launcher writes no error entry and the refusal still reaches that code. In a test a Queueable
	 * cannot start another Queueable, so a launch with a delay made from inside a test Queueable is refused.
	 */
	@IsTest
	@SuppressWarnings('PMD.KernNoRawEnqueueJob')
	private static void shouldWriteNoErrorEntryWhenTheCallerHandlesARefusedDelayedStart()
	{
		System.runAs(getTestAdmin())
		{
			LOG_Builder.ignoreTestMode = true;

			UTIL_AsynchronousJobLauncher.DTO_AsynchronousJobRequest request =
					new UTIL_AsynchronousJobLauncher.DTO_AsynchronousJobRequest(TST_Factory.newFoobars(SHORT_JOB_ITEM_COUNT))
							.withDelayMinutes(LAUNCH_DELAY_MINUTES)
							.withLaunchRefusalHandledByCaller();

			Test.startTest();
			System.enqueueJob(new RefusedDelayedLauncher(request));
			Test.stopTest();

			Assert.isInstanceOfType(refusedLaunchCause, AsyncException.class, 'Expected the refusal to reach the code that started the job, got ' + refusedLaunchCause);
			Assert.isTrue
					(
							new SEL_LogEntry().findAllByMethod(UTIL_AsynchronousJobLauncher.class.getName() + DELAYED_START_LOG_METHOD).isEmpty(),
							'Expected no error entry for a refused delayed start that the caller handles.'
					);
		}
	}

	/**
	 * @description Proves that under BATCH the finish method runs once, after the last chunk, and sees the values that
	 * execute built: a list of record Ids and a small object holding a count and a map of counts by record name. A test
	 * may run only one chunk of a batch, so the five records run as one chunk. The test also proves the job is a batch
	 * job, and that its job row names UTIL_StatefulAsynchronousBatch, the class that runs logic with a finish step.
	 */
	@IsTest
	private static void shouldCallFinishOnceWithTheStateExecuteBuiltUnderBatch()
	{
		System.runAs(getTestAdmin())
		{
			List<Foobar__c> foobars = TST_Factory.insertFoobars(STATEFUL_RECORD_COUNT);

			UTIL_AsynchronousJobLauncher.DTO_AsynchronousJobRequest request = new UTIL_AsynchronousJobLauncher.DTO_AsynchronousJobRequest(foobars)
					.withBatchSize(STATEFUL_RECORD_COUNT)
					.withExecutionStrategy(IF_Async.AsynchronousExecutionStrategy.BATCH);

			Test.startTest();
			UTIL_AsynchronousJobLauncher.process(request, new MockStatefulProcessor());
			Test.stopTest();

			assertFinishSawEveryRecord(foobars, ONE_CHUNK);

			List<AsyncApexJob> jobs = new SEL_AsyncApexJob().findByIds(new List<Id> {finishJobId});
			Assert.areEqual(1, jobs.size(), 'Expected the job Id given to finish to name a job row.');
			Assert.areEqual(BATCH_JOB_TYPE, jobs[0].JobType, 'Expected the job given to finish to be a batch job.');

			ApexClass batchClass = new SEL_ApexClass().findByQualifiedName(UTIL_StatefulAsynchronousBatch.class.getName());
			Assert.areEqual(batchClass.Id, jobs[0].ApexClassId, 'Expected the batch job row to name the batch class that keeps its values.');
			Assert.areEqual(batchClass.Name, jobs[0].ApexClass.Name, 'Expected the batch job row to carry the name of the batch class that keeps its values.');
		}
	}

	/**
	 * @description Proves that a batch built from a query also runs finish once with the values execute built. The
	 * records come from the query when the batch starts, not from a list the job carries.
	 */
	@IsTest
	private static void shouldCallFinishWithTheStateExecuteBuiltForAQueryBackedBatch()
	{
		System.runAs(getTestAdmin())
		{
			List<Foobar__c> foobars = TST_Factory.insertFoobars(STATEFUL_RECORD_COUNT);

			IF_Queryable query = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.fields(new SEL_Foobar().fields);

			UTIL_AsynchronousJobLauncher.DTO_AsynchronousJobRequest request = new UTIL_AsynchronousJobLauncher.DTO_AsynchronousJobRequest(query)
					.withBatchSize(STATEFUL_RECORD_COUNT)
					.withExecutionStrategy(IF_Async.AsynchronousExecutionStrategy.BATCH);

			Test.startTest();
			UTIL_AsynchronousJobLauncher.process(request, new MockStatefulProcessor());
			Test.stopTest();

			assertFinishSawEveryRecord(foobars, ONE_CHUNK);
		}
	}

	/**
	 * @description Checks that MockStatefulProcessor's finish method ran once and saw every record: the same Ids, a
	 * count equal to the number of records, and a count by name for every record name.
	 *
	 * @param foobars The records the job was given.
	 * @param expectedExecuteCount How many times execute should have run.
	 */
	private static void assertFinishSawEveryRecord(List<Foobar__c> foobars, Integer expectedExecuteCount)
	{
		Map<String, Integer> expectedCountByName = new Map<String, Integer>();
		for(Foobar__c foobar : foobars)
		{
			expectedCountByName.put(foobar.Name, (expectedCountByName.get(foobar.Name) ?? 0) + 1);
		}

		Assert.areEqual(1, finishCallCount, 'Expected the finish method to have been called exactly once.');
		Assert.areEqual(expectedExecuteCount, executeCallCounter, 'Expected execute to have run once per chunk.');
		Assert.areEqual(foobars.size(), finishSeenIds.size(), 'Expected finish to see the Id of every record execute was given.');
		Assert.areEqual(new Map<Id, Foobar__c>(foobars).keySet(), new Set<Id>(finishSeenIds), 'Expected finish to see exactly the Ids of the records.');
		Assert.areEqual(foobars.size(), finishTotals.count, 'Expected finish to see the count execute built across every chunk.');
		Assert.areEqual(expectedCountByName, finishTotals.countByName, 'Expected finish to see the counts by name execute built across every chunk.');
	}

	/**
	 * @description Proves that under BATCH the finish method is not run when a chunk threw, and that the error entries
	 * for the failed chunk are still written. A test may run only one chunk of a batch, so the three records run as one
	 * chunk. In a test the platform does not run the batch's finish after a chunk threw, so the warning about the
	 * skipped finish is proved by the two tests that call the batch's finish directly.
	 */
	@IsTest
	private static void shouldNotCallFinishWhenAChunkFailedUnderBatch()
	{
		System.runAs(getTestAdmin())
		{
			LOG_Builder.ignoreTestMode = true;
			List<Foobar__c> foobars = TST_Factory.insertFoobars(SHORT_JOB_ITEM_COUNT);

			UTIL_AsynchronousJobLauncher.DTO_AsynchronousJobRequest request = new UTIL_AsynchronousJobLauncher.DTO_AsynchronousJobRequest(foobars)
					.withBatchSize(SHORT_JOB_ITEM_COUNT)
					.withExecutionStrategy(IF_Async.AsynchronousExecutionStrategy.BATCH);

			Test.startTest();
			UTIL_AsynchronousJobLauncher.process(request, new MockFailingProcessor());
			try
			{
				Test.stopTest();
				Assert.fail('Expected the failing chunks to surface their exception when the batch ends.');
			}
			catch(Exception error)
			{
				Assert.isInstanceOfType(error, TestException.class, 'Expected the processing error to be thrown, got ' + error);
			}

			Test.getEventBus().deliver();

			Assert.areEqual(0, finishCallCount, 'Expected no finish call after a chunk threw.');

			String processorName = UTIL_System.getRuntimeTypeName(new UTIL_AdaptiveAsynchronousProcessor());
			List<LogEntry__c> errorLogs = new SEL_LogEntry().findAllByMethod(processorName + PROCESSOR_EXECUTE_LOG_METHOD);
			Assert.isFalse(errorLogs.isEmpty(), 'Expected the failed chunks to leave error entries.');
			for(LogEntry__c errorLog : errorLogs)
			{
				Assert.areEqual(LoggingLevel.ERROR.name(), errorLog.LogLevel__c, 'Expected every failed chunk entry to be an error.');
			}
		}
	}

	/**
	 * @description Proves that the batch which runs logic with a finish step does not call finish when its job row says
	 * a chunk failed. It writes one warning instead, linked to the job and filed under the processor's finish step, and
	 * the warning says that 1 of 1 chunks failed. In a test the platform does not run a batch's finish after a chunk
	 * threw, so the test calls finish itself, with a job row from TST_Mock that reports one failed chunk.
	 */
	@IsTest
	private static void shouldWarnAndNotCallFinishWhenTheJobReportsAFailedChunk()
	{
		System.runAs(getTestAdmin())
		{
			LOG_Builder.ignoreTestMode = true;
			Id jobId = TST_Factory.mockBatchJob(ONE_CHUNK, ONE_CHUNK);

			Test.startTest();
			new UTIL_StatefulAsynchronousBatch(new UTIL_AdaptiveAsynchronousProcessor(new MockProcessorWithFinish())).finish(TST_Factory.newBatchableContext(jobId));
			Test.stopTest();
			Test.getEventBus().deliver();

			Assert.areEqual(0, finishCallCount, 'Expected no finish call when the job reports a failed chunk.');

			String processorName = UTIL_System.getRuntimeTypeName(new UTIL_AdaptiveAsynchronousProcessor());
			List<LogEntry__c> finishLogs = new SEL_LogEntry().findAllByMethod(processorName + PROCESSOR_FINISH_LOG_METHOD);
			Assert.areEqual(1, finishLogs.size(), 'Expected one warning for the skipped finish.');
			Assert.areEqual(LoggingLevel.WARN.name(), finishLogs[0].LogLevel__c, 'Expected the skipped finish to be logged as a warning.');
			Assert.areEqual(jobId, UTIL_SObject.validateId(finishLogs[0].RecordId__c), 'Expected the warning to be linked to the batch job.');
			Assert.areEqual
					(
							String.format(System.Label.AsyncProcessor_FinishSkipped, new List<Object> {String.valueOf(ONE_CHUNK), String.valueOf(ONE_CHUNK)}),
							finishLogs[0].Message__c,
							'Expected the warning to say that 1 of 1 chunks failed.'
					);
		}
	}

	/**
	 * @description Proves that the batch which runs logic with a finish step calls finish once, with the context it was
	 * given, and writes no warning when its job row says no chunk failed. This is the other half of the test that
	 * proves the warning, so that test cannot pass only because finish is never called.
	 */
	@IsTest
	private static void shouldCallFinishOnceWhenTheJobReportsNoFailedChunk()
	{
		System.runAs(getTestAdmin())
		{
			LOG_Builder.ignoreTestMode = true;
			final Integer noFailedChunks = 0;
			Id jobId = TST_Factory.mockBatchJob(noFailedChunks, ONE_CHUNK);

			Test.startTest();
			new UTIL_StatefulAsynchronousBatch(new UTIL_AdaptiveAsynchronousProcessor(new MockProcessorWithFinish())).finish(TST_Factory.newBatchableContext(jobId));
			Test.stopTest();
			Test.getEventBus().deliver();

			Assert.areEqual(1, finishCallCount, 'Expected the finish method to have been called exactly once.');
			Assert.areEqual(jobId, executeJobId, 'Expected finish to be given the context with the batch job Id.');

			String processorName = UTIL_System.getRuntimeTypeName(new UTIL_AdaptiveAsynchronousProcessor());
			Assert.isTrue(new SEL_LogEntry().findAllByMethod(processorName + PROCESSOR_FINISH_LOG_METHOD).isEmpty(), 'Expected no warning when no chunk failed.');
		}
	}

	/**
	 * @description Proves that under CHAINABLE the finish method runs once, in the last job of the chain, and sees the
	 * values that execute built in every job of the chain.
	 */
	@IsTest
	private static void shouldCallFinishOnceUnderChainable()
	{
		System.runAs(getTestAdmin())
		{
			List<Foobar__c> foobars = TST_Factory.insertFoobars(SHORT_JOB_ITEM_COUNT);

			AsyncOptions options = new AsyncOptions();
			options.maximumQueueableStackDepth = SHORT_JOB_ITEM_COUNT;

			UTIL_AsynchronousJobLauncher.DTO_AsynchronousJobRequest request = new UTIL_AsynchronousJobLauncher.DTO_AsynchronousJobRequest(foobars)
					.withQueueableJobSize(ONE_ITEM_PER_JOB)
					.withAsyncOptions(options)
					.withExecutionStrategy(IF_Async.AsynchronousExecutionStrategy.CHAINABLE);

			Test.startTest();
			UTIL_AsynchronousJobLauncher.process(request, new MockStatefulProcessor());
			Test.stopTest();

			assertFinishSawEveryRecord(foobars, SHORT_JOB_ITEM_COUNT);
		}
	}

	/**
	 * @description Proves that under CHAINABLE the finish method is not run when a job of the chain threw.
	 */
	@IsTest
	private static void shouldNotCallFinishWhenAHopFailedUnderChainable()
	{
		System.runAs(getTestAdmin())
		{
			AsyncOptions options = new AsyncOptions();
			options.maximumQueueableStackDepth = SHORT_JOB_ITEM_COUNT;

			UTIL_AsynchronousJobLauncher.DTO_AsynchronousJobRequest request =
					new UTIL_AsynchronousJobLauncher.DTO_AsynchronousJobRequest(newTextItems(SHORT_JOB_ITEM_COUNT))
							.withQueueableJobSize(ONE_ITEM_PER_JOB)
							.withAsyncOptions(options)
							.withExecutionStrategy(IF_Async.AsynchronousExecutionStrategy.CHAINABLE);

			Test.startTest();
			UTIL_AsynchronousJobLauncher.process(request, new MockFailingProcessor());
			try
			{
				Test.stopTest();
				Assert.fail('Expected the failing job to surface its exception when the chain ends.');
			}
			catch(Exception error)
			{
				Assert.isInstanceOfType(error, TestException.class, 'Expected the processing error to be thrown, got ' + error);
			}

			Assert.areEqual(1, executeCallCounter, 'Expected the chain to stop at the job that threw.');
			Assert.areEqual(0, finishCallCount, 'Expected no finish call after a job of the chain threw.');
		}
	}

	/**
	 * @description Proves that AUTO never runs a processor with a finish step as parallel jobs. Two items at one item
	 * per job, in a synchronous transaction with free job slots, would run as two parallel jobs for a processor without
	 * a finish step. Here one chained job is started instead, and finish runs once.
	 */
	@IsTest
	private static void shouldResolveChainableNotParallelForAFinishableProcessorUnderAuto()
	{
		System.runAs(getTestAdmin())
		{
			final Integer numberOfItems = 2;

			AsyncOptions options = new AsyncOptions();
			options.maximumQueueableStackDepth = numberOfItems;

			UTIL_AsynchronousJobLauncher.DTO_AsynchronousJobRequest request =
					new UTIL_AsynchronousJobLauncher.DTO_AsynchronousJobRequest(TST_Factory.newFoobars(numberOfItems))
							.withQueueableJobSize(ONE_ITEM_PER_JOB)
							.withAsyncOptions(options)
							.withExecutionStrategy(IF_Async.AsynchronousExecutionStrategy.AUTO);

			Test.startTest();
			UTIL_AsynchronousJobLauncher.process(request, new MockProcessorWithFinish());
			Assert.areEqual(1, UTIL_Limits.queueableJobs().used(), 'Expected one chained job to be started, not one parallel job per item.');
			Test.stopTest();

			Assert.areEqual(numberOfItems, executeCallCounter, 'Expected the chain to run one job per item.');
			Assert.areEqual(1, finishCallCount, 'Expected the finish method to have been called exactly once.');
		}
	}

	/**
	 * @description Proves that forcing PARALLEL_QUEUEABLES for a processor with a finish step is refused at launch, in
	 * the caller's transaction, with the labelled message, and that no job is created. A delayed launch is refused the
	 * same way, before its delayed start is queued.
	 */
	@IsTest
	private static void shouldRefuseForcedParallelForAFinishableProcessor()
	{
		System.runAs(getTestAdmin())
		{
			Integer jobCountBefore = new SEL_AsyncApexJob().count();

			UTIL_AsynchronousJobLauncher.DTO_AsynchronousJobRequest immediateRequest =
					new UTIL_AsynchronousJobLauncher.DTO_AsynchronousJobRequest(TST_Factory.newFoobars(SHORT_JOB_ITEM_COUNT))
							.withExecutionStrategy(IF_Async.AsynchronousExecutionStrategy.PARALLEL_QUEUEABLES);

			UTIL_AsynchronousJobLauncher.DTO_AsynchronousJobRequest delayedRequest =
					new UTIL_AsynchronousJobLauncher.DTO_AsynchronousJobRequest(TST_Factory.newFoobars(SHORT_JOB_ITEM_COUNT))
							.withDelayMinutes(LAUNCH_DELAY_MINUTES)
							.withExecutionStrategy(IF_Async.AsynchronousExecutionStrategy.PARALLEL_QUEUEABLES);

			Test.startTest();
			assertParallelLaunchIsRefused(immediateRequest);
			assertParallelLaunchIsRefused(delayedRequest);
			Assert.areEqual(0, UTIL_Limits.queueableJobs().used(), 'Expected no job to be queued for a refused launch.');
			Test.stopTest();

			Assert.areEqual(jobCountBefore, new SEL_AsyncApexJob().count(), 'Expected no job row to be created for a refused launch.');
			Assert.areEqual(0, executeCallCounter, 'Expected the processor never to run.');
			Assert.areEqual(0, finishCallCount, 'Expected the finish method never to run.');
		}
	}

	/**
	 * @description Launches a request with a processor that has a finish step, and checks that the launch is refused
	 * with the labelled message.
	 *
	 * @param request The request, which forces PARALLEL_QUEUEABLES.
	 */
	private static void assertParallelLaunchIsRefused(UTIL_AsynchronousJobLauncher.DTO_AsynchronousJobRequest request)
	{
		try
		{
			UTIL_AsynchronousJobLauncher.process(request, new MockProcessorWithFinish());
			Assert.fail('Expected the launch to be refused for a processor with a finish step.');
		}
		catch(Exception error)
		{
			Assert.isInstanceOfType(error, IllegalArgumentException.class, 'Expected the refusal to be an IllegalArgumentException, got ' + error);
			Assert.areEqual(System.Label.AsyncProcessor_ParallelRefusedForFinishable, error.getMessage(), 'Expected the refusal to carry the labelled message.');
		}
	}

	/**
	 * @description Proves that forcing PARALLEL_QUEUEABLES still runs parallel jobs for a processor without a finish step.
	 */
	@IsTest
	private static void shouldStillRunForcedParallelForAPlainProcessor()
	{
		System.runAs(getTestAdmin())
		{
			final Integer numberOfItems = 2;

			UTIL_AsynchronousJobLauncher.DTO_AsynchronousJobRequest request =
					new UTIL_AsynchronousJobLauncher.DTO_AsynchronousJobRequest(TST_Factory.newFoobars(numberOfItems))
							.withQueueableJobSize(ONE_ITEM_PER_JOB)
							.withExecutionStrategy(IF_Async.AsynchronousExecutionStrategy.PARALLEL_QUEUEABLES);

			Test.startTest();
			UTIL_AsynchronousJobLauncher.process(request, new MockProcessor());
			Assert.areEqual(numberOfItems, UTIL_Limits.queueableJobs().used(), 'Expected one parallel job per item.');
			Test.stopTest();

			Assert.isTrue(executionWasQueueable, 'Expected the items to be processed in Queueables.');
			Assert.areEqual(numberOfItems, executeCallCounter, 'Expected one run per parallel job.');
		}
	}

	/**
	 * @description Builds a list of random plain-text items.
	 *
	 * @param numberOfItems How many items to build.
	 *
	 * @return The new list of text items.
	 */
	private static List<Object> newTextItems(Integer numberOfItems)
	{
		List<Object> items = new List<Object>();
		for(Integer index = 0; index < numberOfItems; index++)
		{
			items.add(UTIL_Random.randomAlphanumeric(TEXT_ITEM_LENGTH));
		}
		return items;
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
			finishCallCount++;
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
	 * @description A processor with no finish step. It counts its runs and keeps every item it is given.
	 */
	private class MockProcessor implements IF_Async.Processable
	{
		/**
		 * @description Counts the run and keeps the items it was given.
		 *
		 * @param items The list of objects processed in the current transaction.
		 */
		public void execute(List<Object> items)
		{
			executeCallCounter++;
			executeWasCalled = true;
			executionWasQueueable = System.isQueueable();
			ITEMS_PROCESSED_BY_MOCK_PROCESSOR.addAll(items);
		}
	}

	/**
	 * @description A processor with a finish step that keeps what it saw in its own fields, so a test can prove that
	 * finish sees the values execute built across every chunk or job. It is given Foobar__c records.
	 */
	private class MockStatefulProcessor implements IF_Async.Processable, IF_Async.Finishable
	{
		/**
		 * @description The Id of every record execute was given, in the order it saw them.
		 */
		public List<Id> seenIds = new List<Id>();

		/**
		 * @description A count of the records execute was given, and a count for each record name.
		 */
		public MockTotals totals = new MockTotals();

		/**
		 * @description Counts the run and adds every record to the Ids and the totals.
		 *
		 * @param items The records processed in the current transaction.
		 */
		public void execute(List<Object> items)
		{
			executeCallCounter++;
			executionWasQueueable = System.isQueueable();
			for(Object item : items)
			{
				Foobar__c foobar = (Foobar__c)item;
				seenIds.add(foobar.Id);
				totals.add(foobar.Name);
			}
		}

		/**
		 * @description Counts the call and copies the Ids, the totals and the job Id into the test's static fields.
		 *
		 * @param context The context the job gives the finish step.
		 */
		public void finish(Database.BatchableContext context)
		{
			finishCallCount++;
			finishSeenIds = new List<Id>(seenIds);
			finishTotals = totals;
			finishJobId = context.getJobId();
		}
	}

	/**
	 * @description A small object holding a count and a count for each record name, so the tests prove that an object
	 * holding a map keeps its values from one chunk to the next.
	 */
	private class MockTotals
	{
		/**
		 * @description How many records were added.
		 */
		public Integer count = 0;

		/**
		 * @description How many records were added for each record name.
		 */
		public Map<String, Integer> countByName = new Map<String, Integer>();

		/**
		 * @description Adds one record with the given name.
		 *
		 * @param name The record's name.
		 */
		public void add(String name)
		{
			count++;
			countByName.put(name, (countByName.get(name) ?? 0) + 1);
		}
	}

	/**
	 * @description A Queueable that does nothing when it runs. A test starts it with a duplicate signature, so that
	 * Salesforce refuses the next job that carries the same signature.
	 */
	@SuppressWarnings('PMD.QueueableWithoutFinalizer')
	private class DoNothingQueueable implements Queueable
	{
		/**
		 * @description Does nothing; the job exists only to hold the duplicate signature.
		 *
		 * @param context The context Salesforce gives the running job.
		 */
		@SuppressWarnings('PMD.EmptyStatementBlock')
		public void execute(QueueableContext context)
		{
		}
	}

	/**
	 * @description A Queueable that hands its items to the launcher from inside a running job, so the launcher starts
	 * one chained job. It keeps the cause and the number of items not started from the refusal it catches.
	 */
	@SuppressWarnings('PMD.QueueableWithoutFinalizer')
	private class RefusedChainLauncher implements Queueable
	{
		/**
		 * @description The items handed to the launcher.
		 */
		private final List<Object> items;

		/**
		 * @description Keeps the items to hand to the launcher when the job runs.
		 *
		 * @param items The items to hand to the launcher.
		 */
		private RefusedChainLauncher(List<Object> items)
		{
			this.items = items;
		}

		/**
		 * @description Hands the items to the launcher and keeps what the refusal says.
		 *
		 * @param context The context Salesforce gives the running job.
		 */
		public void execute(QueueableContext context)
		{
			try
			{
				UTIL_AsynchronousJobLauncher.process(items, new MockProcessor());
				Assert.fail('Expected Salesforce to refuse the chained job started from inside a test Queueable.');
			}
			catch(UTIL_Exceptions.LaunchRefusedException refused)
			{
				refusedLaunchCause = refused.getCause();
				refusedLaunchUnsentItemCount = refused.unsentItems.size();
			}
		}
	}

	/**
	 * @description A Queueable that hands a request with a delay to the launcher from inside a running job, so the
	 * launcher tries to queue the delayed start. It keeps the cause and the items not started from the refusal it catches.
	 */
	@SuppressWarnings('PMD.QueueableWithoutFinalizer')
	private class RefusedDelayedLauncher implements Queueable
	{
		/**
		 * @description The request handed to the launcher.
		 */
		private final UTIL_AsynchronousJobLauncher.DTO_AsynchronousJobRequest request;

		/**
		 * @description Keeps the request to hand to the launcher when the job runs.
		 *
		 * @param request The request to hand to the launcher.
		 */
		private RefusedDelayedLauncher(UTIL_AsynchronousJobLauncher.DTO_AsynchronousJobRequest request)
		{
			this.request = request;
		}

		/**
		 * @description Hands the request to the launcher and keeps what the refusal says.
		 *
		 * @param context The context Salesforce gives the running job.
		 */
		public void execute(QueueableContext context)
		{
			try
			{
				UTIL_AsynchronousJobLauncher.process(request, new MockProcessor());
				Assert.fail('Expected Salesforce to refuse the delayed start queued from inside a test Queueable.');
			}
			catch(UTIL_Exceptions.LaunchRefusedException refused)
			{
				refusedLaunchCause = refused.getCause();
				refusedLaunchUnsentItems = refused.unsentItems;
			}
		}
	}

	/**
	 * @description A query that throws when it is read, so a job built from it fails before any job is started.
	 */
	private class FailingQueryable implements IF_Queryable
	{
		/**
		 * @description Throws, as a query that cannot be read does.
		 *
		 * @return Never returns.
		 */
		public List<SObject> toList()
		{
			throw new TestException(QUERY_FAILURE_MESSAGE);
		}

		/**
		 * @description Throws, as a query that cannot be read does.
		 *
		 * @return Never returns.
		 */
		public SObject getFirst()
		{
			throw new TestException(QUERY_FAILURE_MESSAGE);
		}

		/**
		 * @description Throws, as a query that cannot be read does.
		 *
		 * @return Never returns.
		 */
		public Database.QueryLocator toQueryLocator()
		{
			throw new TestException(QUERY_FAILURE_MESSAGE);
		}

		/**
		 * @description Throws, as a query that cannot be read does.
		 *
		 * @return Never returns.
		 */
		public Integer count()
		{
			throw new TestException(QUERY_FAILURE_MESSAGE);
		}

		/**
		 * @description Throws, as a query that cannot be read does.
		 *
		 * @return Never returns.
		 */
		public Boolean exists()
		{
			throw new TestException(QUERY_FAILURE_MESSAGE);
		}
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

	/**
	 * @description Verifies the platform's retrieve chunk for a query-backed batch: 100 up to a scope size of 100,
	 * 400 up to 400, and 2,000 above that.
	 */
	@IsTest
	private static void retrieveChunkFollowsTheScopeSize()
	{
		Assert.areEqual(100, UTIL_AdaptiveAsynchronousProcessor.computeRetrieveChunk(1), 'a scope size of 1 reads a chunk of 100');
		Assert.areEqual(100, UTIL_AdaptiveAsynchronousProcessor.computeRetrieveChunk(100), 'a scope size of 100 reads a chunk of 100');
		Assert.areEqual(400, UTIL_AdaptiveAsynchronousProcessor.computeRetrieveChunk(101), 'a scope size of 101 reads a chunk of 400');
		Assert.areEqual(400, UTIL_AdaptiveAsynchronousProcessor.computeRetrieveChunk(400), 'a scope size of 400 reads a chunk of 400');
		Assert.areEqual(2000, UTIL_AdaptiveAsynchronousProcessor.computeRetrieveChunk(401), 'a scope size of 401 reads a chunk of 2,000');
		Assert.areEqual(2000, UTIL_AdaptiveAsynchronousProcessor.computeRetrieveChunk(2000), 'a scope size of 2,000 reads a chunk of 2,000');
		Assert.areEqual(2000, UTIL_AdaptiveAsynchronousProcessor.computeRetrieveChunk(2001), 'a scope size above 2,000 still reads a chunk of 2,000');
	}

	/**
	 * @description Verifies the scope sizes nearest to a given one that divide their retrieve chunk exactly, in
	 * ascending order and never including the given size itself.
	 */
	@IsTest
	private static void fittingScopeSizesAreTheNearestDivisorsOfTheChunk()
	{
		Assert.areEqual(new List<Integer> {50, 100}, UTIL_AdaptiveAsynchronousProcessor.findFittingScopeSizesAround(75),
				'the nearest fitting sizes around 75 are 50 and 100');
		Assert.areEqual(new List<Integer> {100, 200}, UTIL_AdaptiveAsynchronousProcessor.findFittingScopeSizesAround(150),
				'the nearest fitting sizes around 150 are 100 and 200');
		Assert.areEqual(new List<Integer> {2, 4}, UTIL_AdaptiveAsynchronousProcessor.findFittingScopeSizesAround(3),
				'the nearest fitting sizes around 3 are 2 and 4');
		Assert.areEqual(new List<Integer> {50, 200}, UTIL_AdaptiveAsynchronousProcessor.findFittingScopeSizesAround(100),
				'the nearest fitting sizes around 100 exclude 100 itself');
		Assert.areEqual(new List<Integer> {1000}, UTIL_AdaptiveAsynchronousProcessor.findFittingScopeSizesAround(2000),
				'the only fitting size near 2,000 is 1,000 below it, since none fit above it');
		Assert.areEqual(new List<Integer> {2}, UTIL_AdaptiveAsynchronousProcessor.findFittingScopeSizesAround(1),
				'the only fitting size near 1 is 2 above it, since none fit below it');
	}

	/**
	 * @description Verifies a query-backed batch launched with a scope size that does not divide its retrieve chunk
	 * writes exactly one WARN entry naming the scope size, the chunk, the short run every chunk leaves and the
	 * nearest sizes that fit, fingerprinted with the processable's name and the scope size so repeated launches
	 * fold into one problem.
	 */
	@IsTest
	private static void aQueryBackedBatchWithAScopeThatDoesNotFitWarnsOnce()
	{
		final Integer scopeSizeThatDoesNotFit = 75;
		final Integer expectedRetrieveChunk = 100;
		final Integer expectedShortRun = 25;
		final String expectedFittingSizesText = '50, 100';
		MockProcessorWithFinish processorLogic = new MockProcessorWithFinish();
		String expectedProcessableName = UTIL_System.getRuntimeTypeName(processorLogic);

		System.runAs(getTestAdmin())
		{
			TST_Factory.insertFoobars(1);
			LOG_Builder.ignoreTestMode = true;

			IF_Queryable query = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.fields(new SEL_Foobar().fields);

			UTIL_AsynchronousJobLauncher.DTO_AsynchronousJobRequest request =
					new UTIL_AsynchronousJobLauncher.DTO_AsynchronousJobRequest(query)
							.withBatchSize(scopeSizeThatDoesNotFit)
							.withExecutionStrategy(IF_Async.AsynchronousExecutionStrategy.BATCH);

			Test.startTest();
			UTIL_AsynchronousJobLauncher.process(request, processorLogic);
			Test.stopTest();
		}

		Test.getEventBus().deliver();

		List<LogEntry__c> warnEntries = findRunWarnEntries();
		Assert.areEqual(1, warnEntries.size(), 'a scope size that does not divide its retrieve chunk must write exactly one WARN entry');

		LogEntry__c entry = warnEntries[0];
		Assert.isTrue(entry.Message__c.contains('Batch size ' + scopeSizeThatDoesNotFit + ' '), 'the message names the launched scope size');
		Assert.isTrue(entry.Message__c.contains('chunk of ' + expectedRetrieveChunk + ' records'), 'the message names the chunk the size falls into');
		Assert.isTrue(entry.Message__c.contains('short run of ' + expectedShortRun + ' records'), 'the message names the short run every chunk leaves');
		Assert.isTrue(entry.Message__c.contains('Sizes that fit: ' + expectedFittingSizesText), 'the message names the nearest scope sizes that fit');
		Assert.isTrue(entry.Fingerprint__c.contains(expectedProcessableName), 'the fingerprint carries the processable class name');
		Assert.isTrue(entry.Fingerprint__c.contains(String.valueOf(scopeSizeThatDoesNotFit)), 'the fingerprint carries the launched scope size');
	}

	/**
	 * @description Verifies a query-backed batch launched with a scope size that divides its retrieve chunk exactly
	 * writes no scope-size WARN entry.
	 */
	@IsTest
	private static void aQueryBackedBatchWithAFittingScopeWritesNoWarning()
	{
		final Integer fittingScopeSize = 50;

		System.runAs(getTestAdmin())
		{
			TST_Factory.insertFoobars(1);
			LOG_Builder.ignoreTestMode = true;

			IF_Queryable query = QRY_Builder.selectFrom(Foobar__c.SObjectType)
					.fields(new SEL_Foobar().fields);

			UTIL_AsynchronousJobLauncher.DTO_AsynchronousJobRequest request =
					new UTIL_AsynchronousJobLauncher.DTO_AsynchronousJobRequest(query)
							.withBatchSize(fittingScopeSize)
							.withExecutionStrategy(IF_Async.AsynchronousExecutionStrategy.BATCH);

			Test.startTest();
			UTIL_AsynchronousJobLauncher.process(request, new MockProcessorWithFinish());
			Test.stopTest();
		}

		Test.getEventBus().deliver();

		Assert.areEqual(0, findRunWarnEntries().size(), 'a scope size that divides its retrieve chunk exactly must write no WARN entry');
	}

	/**
	 * @description Verifies an in-memory (list-backed) batch launched with a scope size that would not divide a
	 * query-backed batch's retrieve chunk writes no scope-size WARN entry, since an in-memory batch never reads a
	 * retrieve chunk from the platform.
	 */
	@IsTest
	private static void anInMemoryBatchWithAScopeThatDoesNotFitWritesNoWarning()
	{
		final Integer scopeSizeThatDoesNotFit = 75;

		System.runAs(getTestAdmin())
		{
			LOG_Builder.ignoreTestMode = true;

			UTIL_AsynchronousJobLauncher.DTO_AsynchronousJobRequest request =
					new UTIL_AsynchronousJobLauncher.DTO_AsynchronousJobRequest(TST_Factory.newFoobars(1))
							.withBatchSize(scopeSizeThatDoesNotFit)
							.withExecutionStrategy(IF_Async.AsynchronousExecutionStrategy.BATCH);

			Test.startTest();
			UTIL_AsynchronousJobLauncher.process(request, new MockProcessorWithFinish());
			Test.stopTest();
		}

		Test.getEventBus().deliver();

		Assert.areEqual(0, findRunWarnEntries().size(), 'an in-memory batch must write no scope-size WARN entry');
	}

	/**
	 * @description Scans persisted log rows for the detail row of a WARN entry whose class-method ends in `/run`, the
	 * location the processor's scope-size warning emits from. A fingerprinted entry also persists a daily rollup row,
	 * which is not the entry itself, so only detail rows count.
	 *
	 * @return The matching LogEntry__c detail rows.
	 */
	private static List<LogEntry__c> findRunWarnEntries()
	{
		List<LogEntry__c> matches = new List<LogEntry__c>();
		for(LogEntry__c row : new SEL_LogEntry().getAll())
		{
			Boolean isDetailRow = row.Fingerprint__c != null && row.Fingerprint__c.startsWith(TRG_PersistLogEntry.PREFIX_DETAIL);
			if(isDetailRow && LoggingLevel.WARN.name().equals(row.LogLevel__c) && row.ClassMethod__c != null && row.ClassMethod__c.endsWith('/run'))
			{
				matches.add(row);
			}
		}
		return matches;
	}
}