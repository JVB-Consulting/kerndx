// SPDX-License-Identifier: Apache-2.0
/**
 * @description Writes one ERROR log entry for each batch job failure the platform reports. A batch class that opts into
 * failure events (it implements `Database.RaisesPlatformEvents`, as the framework's own batch processor does) makes the
 * platform publish a `BatchApexErrorEvent` when the job fails, including failures the job's own code did not catch, such
 * as a governor limit, or an error in a phase the job left without a catch. Wired as the trigger action on that event
 * (`afterInsert`), this class turns
 * each event into a log entry linked to the failed job, filed under the failed job's class and the step it failed in,
 * so a failure nothing caught still leaves a record. It only logs: it sends no alert and changes no data.
 *
 * The entries are not written one by one. The trigger runs on a platform event, so the logging engine holds them and
 * writes them together when the trigger ends.
 *
 * @see TRG_LogBatchApexError_TEST
 * @see TRG_Base
 * @see IF_Trigger
 * @see LOG_Builder
 * @see SEL_AsyncApexJob
 * @see LOG_Engine
 * @see UTIL_String
 *
 * @author Jason van Beukering
 *
 * @group Triggers
 *
 * @date September 2026, October 2026
 */
public inherited sharing class TRG_LogBatchApexError extends TRG_Base implements IF_Trigger.AfterInsert
{
	/**
	 * @description Separates the class name from the step name in the location an entry is filed under.
	 */
	private static final String LOCATION_SEPARATOR = '/';

	/**
	 * @description The location an entry is filed under when the failed job's row cannot be found, so its class is
	 * unknown, or when the event names no step.
	 */
	private static final String HANDLER_LOCATION = TRG_LogBatchApexError.class.getName() + LOCATION_SEPARATOR + 'afterInsert';

	/**
	 * @description Writes one ERROR log entry per reported batch failure, carrying the failure's message, exception type
	 * and stack trace, linked to the failed job, and filed under the failed job's class and the step it failed in.
	 *
	 * @param newRecords The `BatchApexErrorEvent` records the platform delivered.
	 */
	public void afterInsert(List<SObject> newRecords)
	{
		List<BatchApexErrorEvent> events = new List<BatchApexErrorEvent>();
		List<Id> jobIds = new List<Id>();
		for(SObject record : newRecords)
		{
			BatchApexErrorEvent event = (BatchApexErrorEvent)record;
			events.add(event);
			jobIds.add(event.AsyncApexJobId);
		}

		Map<Id, AsyncApexJob> jobsById = new Map<Id, AsyncApexJob>(new SEL_AsyncApexJob().findByIds(jobIds));

		for(BatchApexErrorEvent event : events)
		{
			LOG_Builder.build()
					.error(event.Message)
					.withExceptionTypeInternal(event.ExceptionType)
					.withStackTraceInternal(event.StackTrace)
					.forRecord(event.AsyncApexJobId)
					.withContext(LOG_Engine.CONTEXT_BATCH_PHASE, event.Phase)
					.withContext(LOG_Engine.CONTEXT_REQUEST_ID, event.RequestId)
					.withContext(LOG_Engine.CONTEXT_JOB_SCOPE, event.JobScope)
					.withContext(LOG_Engine.CONTEXT_JOB_SCOPE_TRUNCATED, event.DoesExceedJobScopeMaxLength)
					.emitAt(resolveLocation(event, jobsById.get(event.AsyncApexJobId)));
		}
	}

	/**
	 * @description Works out the location an entry is filed under: the failed job's class, with its namespace when it
	 * has one, and the step it failed in, in lower case (for example `MyBatch/execute`, or `acme.MyBatch/execute` for a
	 * packaged class). That is the same name the class gives itself when it logs, so both entries for one failure are
	 * filed together. When the job's row was not found or the event names no step, the entry is filed under this
	 * handler's own location instead.
	 *
	 * @param event The reported failure.
	 * @param job The failed job's row, or null when it was not found.
	 *
	 * @return The location to file the entry under.
	 */
	private static String resolveLocation(BatchApexErrorEvent event, AsyncApexJob job)
	{
		String className = job?.ApexClass?.Name;
		if(String.isBlank(className) || String.isBlank(event.Phase))
		{
			return HANDLER_LOCATION;
		}
		String namespacePrefix = job.ApexClass.NamespacePrefix;
		String qualifiedClassName = String.isBlank(namespacePrefix) ? className : namespacePrefix + UTIL_String.DOT + className;
		return qualifiedClassName + LOCATION_SEPARATOR + event.Phase.toLowerCase();
	}
}
