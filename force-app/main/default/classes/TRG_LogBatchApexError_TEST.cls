// SPDX-License-Identifier: Apache-2.0
/**
 * @description Test class for the TRG_LogBatchApexError trigger action. Runs serially because it waits for the platform
 * to deliver the failure event a real batch job raises.
 *
 * @see TRG_LogBatchApexError
 *
 * @author Jason van Beukering
 *
 * @group Triggers
 *
 * @date September 2026, October 2026
 */
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest(seeAllData=false isParallel=false)
private class TRG_LogBatchApexError_TEST
{
	/**
	 * @description The message the failing batch job throws.
	 */
	private static final String FAILURE_MESSAGE = 'Simulating a batch processing failure';

	/**
	 * @description One record in a batch of one, so the failing job runs its execute step exactly once.
	 */
	private static final Integer RECORD_COUNT = 1;

	/**
	 * @description The step name the platform gives a failure inside a batch job's execute method.
	 */
	private static final String PHASE_EXECUTE = 'EXECUTE';

	/**
	 * @description The step name the platform gives a failure inside a batch job's start method.
	 */
	private static final String PHASE_START = 'START';

	/**
	 * @description The step the framework's batch processor was in when the failing work threw, as it appears in the
	 * location an entry is filed under.
	 */
	private static final String EXECUTE_LOCATION_SUFFIX = '/execute';

	/**
	 * @description The location the handler files an entry under when the failed job's row cannot be found or the event
	 * names no step.
	 */
	private static final String HANDLER_LOCATION = TRG_LogBatchApexError.class.getName() + '/afterInsert';

	/**
	 * @description The level every entry the handler writes carries.
	 */
	private static final String LEVEL_ERROR = LoggingLevel.ERROR.name();

	/**
	 * @description A batch job that fails in its execute step makes the platform report the failure, and the handler
	 * turns that report into exactly one ERROR entry linked to the job, filed under the failed job's class and step,
	 * naming the exception the job threw and the step it failed in. The expected class is the processor's own name as
	 * Apex reports it, so it carries the namespace in a packaged build and none here. The processor's own catch entry
	 * carries no record link, so the listener's entry is the only one linked to the job.
	 */
	@IsTest
	private static void aBatchFailureTheEventReportsBecomesOneLogEntryNamingTheJob()
	{
		LOG_Builder.ignoreTestMode = true;
		List<Foobar__c> foobars = TST_Factory.insertFoobars(RECORD_COUNT);
		UTIL_AsynchronousJobLauncher.DTO_AsynchronousJobRequest request = new UTIL_AsynchronousJobLauncher.DTO_AsynchronousJobRequest(foobars)
				.withBatchSize(RECORD_COUNT)
				.withExecutionStrategy(IF_Async.AsynchronousExecutionStrategy.BATCH);
		Id jobId;

		Test.startTest();
		try
		{
			jobId = UTIL_AsynchronousJobLauncher.process(request, new FailingProcessable());
			Test.stopTest();
			Assert.fail('The failing batch job must rethrow its exception when the test stops');
		}
		catch(Exception error)
		{
			Assert.isInstanceOfType(error, BatchFailureException.class, 'The batch job must fail with the exception its work threw');
		}
		Test.getEventBus().deliver();

		List<LogEntry__c> jobEntries = findEntriesForRecord(jobId);
		Assert.areEqual(1, jobEntries.size(), 'Exactly one log entry must be linked to the failed batch job');
		LogEntry__c jobEntry = jobEntries[0];
		Assert.areEqual(LEVEL_ERROR, jobEntry.LogLevel__c, 'A batch job failure must be logged at ERROR');
		Assert.areEqual(UTIL_AdaptiveAsynchronousProcessor.class.getName() + EXECUTE_LOCATION_SUFFIX, jobEntry.ClassMethod__c,
				'The entry must be filed under the failed job class, namespace included, and step, as the processor names itself');
		Assert.areEqual(BatchFailureException.class.getName(), jobEntry.ExceptionType__c, 'The entry must name the exception the job threw');
		Map<String, Object> context = SEL_LogEntry.parseContextDataForTest(jobEntry);
		Assert.areEqual(PHASE_EXECUTE, String.valueOf(context.get(LOG_Engine.CONTEXT_BATCH_PHASE)), 'The entry must record the step the job failed in');
	}

	/**
	 * @description A reported failure whose job row cannot be found is still logged, filed under the handler's own
	 * location because the failed class is unknown. The platform alone publishes this event, so the handler is called
	 * directly here; the first test proves the path through the trigger.
	 */
	@IsTest
	private static void anEventWhoseJobIsGoneIsLoggedUnderTheHandler()
	{
		LOG_Builder.ignoreTestMode = true;
		Id missingJobId = UTIL_Random.randomId(AsyncApexJob.SObjectType);
		BatchApexErrorEvent event = new BatchApexErrorEvent(AsyncApexJobId = missingJobId, Message = FAILURE_MESSAGE, Phase = PHASE_START);

		Test.startTest();
		new TRG_LogBatchApexError().afterInsert(new List<SObject> {event});
		Test.stopTest();
		Test.getEventBus().deliver();

		List<LogEntry__c> jobEntries = findEntriesForRecord(missingJobId);
		Assert.areEqual(1, jobEntries.size(), 'The failure must still be logged when its job row is missing');
		Assert.areEqual(HANDLER_LOCATION, jobEntries[0].ClassMethod__c, 'An entry whose job row is missing must be filed under the handler');
		Assert.areEqual(LEVEL_ERROR, jobEntries[0].LogLevel__c, 'A batch job failure must be logged at ERROR');
	}

	/**
	 * @description Reads the persisted log entries linked to the given record.
	 *
	 * @param recordId The record the entries must be linked to.
	 *
	 * @return The entries whose record link is that record.
	 */
	private static List<LogEntry__c> findEntriesForRecord(Id recordId)
	{
		List<LogEntry__c> entries = new List<LogEntry__c>();
		for(LogEntry__c entry : new SEL_LogEntry().getAll())
		{
			if(String.isNotBlank(entry.RecordId__c) && UTIL_SObject.validateId(entry.RecordId__c) == recordId)
			{
				entries.add(entry);
			}
		}
		return entries;
	}

	/**
	 * @description Work that always fails, so the batch job running it fails in its execute step.
	 */
	private class FailingProcessable implements IF_Async.Processable
	{
		/**
		 * @description Throws, simulating work that fails.
		 *
		 * @param items The items the batch job hands over.
		 */
		public void execute(List<Object> items)
		{
			throw new BatchFailureException(FAILURE_MESSAGE);
		}
	}

	/**
	 * @description The exception the failing work throws, so the test can recognise it in the log.
	 */
	private class BatchFailureException extends Exception
	{
	}
}
