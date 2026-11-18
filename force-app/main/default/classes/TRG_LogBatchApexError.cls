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
 * @see UTIL_StatefulAsynchronousBatch
 * @see UTIL_AdaptiveAsynchronousProcessor
 *
 * @author Jason van Beukering
 *
 * @group Triggers
 *
 * @date September 2026, November 2026
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
	 * @description The step name the platform gives a failure in a batch job's start method, which is also how a job
	 * that failed before its first chunk is reported.
	 */
	private static final String PHASE_START = 'START';

	/**
	 * @description The full name, namespace included, of the batch that runs processor logic with a finish step. Its job
	 * row names it, but the processor it runs logs under its own name.
	 */
	private static final String STATEFUL_BATCH_CLASS_NAME = UTIL_StatefulAsynchronousBatch.class.getName();

	/**
	 * @description The full name, namespace included, of the processor. A failure of the batch named by
	 * STATEFUL_BATCH_CLASS_NAME is filed under this name instead.
	 */
	private static final String PROCESSOR_CLASS_NAME = UTIL_AdaptiveAsynchronousProcessor.class.getName();

	/**
	 * @description Writes one ERROR log entry per reported batch failure, carrying the failure's message, exception type
	 * and stack trace, linked to the failed job, and filed under the failed job's class and the step it failed in. Every
	 * entry also carries the platform's reason text for the job. A failure in the start step is a batch that failed
	 * before its first chunk ran, so its message is the reason text put into a label and not the event's message. When the
	 * job gives no reason text, or its row cannot be found, the message is the event's own message.
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
			AsyncApexJob job = jobsById.get(event.AsyncApexJobId);
			String message = event.Phase == PHASE_START && String.isNotBlank(job?.ExtendedStatus)
					? String.format(System.Label.BatchJob_FailedBeforeFirstChunk, new List<Object> {job.ExtendedStatus})
					: event.Message;
			LOG_Builder.build()
					.error(message)
					.withExceptionTypeInternal(event.ExceptionType)
					.withStackTraceInternal(event.StackTrace)
					.forRecord(event.AsyncApexJobId)
					.withContext(LOG_Engine.CONTEXT_BATCH_PHASE, event.Phase)
					.withContext(LOG_Engine.CONTEXT_EXTENDED_STATUS, job?.ExtendedStatus)
					.withContext(LOG_Engine.CONTEXT_REQUEST_ID, event.RequestId)
					.withContext(LOG_Engine.CONTEXT_JOB_SCOPE, event.JobScope)
					.withContext(LOG_Engine.CONTEXT_JOB_SCOPE_TRUNCATED, event.DoesExceedJobScopeMaxLength)
					.emitAt(resolveLocation(event, job));
		}
	}

	/**
	 * @description Works out the location an entry is filed under: the failed job's class, with its namespace when it
	 * has one, and the step it failed in, in lower case (for example `MyBatch/execute`, or `acme.MyBatch/execute` for a
	 * packaged class). That is the same name the class gives itself when it logs, so both entries for one failure are
	 * filed together. A job of UTIL_StatefulAsynchronousBatch is filed under UTIL_AdaptiveAsynchronousProcessor: that
	 * batch only runs the processor, and the processor logs the same failure under its own name. When the job's row was
	 * not found or the event names no step, the entry is filed under this handler's own location instead.
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
		if(qualifiedClassName == STATEFUL_BATCH_CLASS_NAME)
		{
			qualifiedClassName = PROCESSOR_CLASS_NAME;
		}
		return qualifiedClassName + LOCATION_SEPARATOR + event.Phase.toLowerCase();
	}
}
