// SPDX-License-Identifier: Apache-2.0
/**
 * @description Asynchronously invokes web service calls, allowing large or delayed API callouts
 * to be processed outside of immediate flows or triggers. Leverages the adaptive asynchronous
 * processor to manage API requests efficiently.
 *
 * @see FLOW_CallApiAsync_TEST
 *
 * @author Jason van Beukering
 *
 * @group Web Services
 *
 * @date February 2026, November 2026
 *
 * @since 1.0
 *
 * @example
 * ```apex
 * List<ApiCall__c> apiCalls = new List<ApiCall__c>();
 * ApiCall__c apiCall = TST_Factory.newOutboundApiCall('API_GetCustomerInfo', recordId, new Map<String, String>{'customerId' => '5678'});
 * apiCalls.add(apiCall);
 * FLOW_CallApiAsync.invokeApiCallAsynchronously(apiCalls);
 * ```
 */
@SuppressWarnings('PMD.AvoidGlobalModifier')
global inherited sharing class FLOW_CallApiAsync
{
	/**
	 * @description Default job size for API callout processing. Keeps each async execution within
	 * the 100-callout governor limit while targeting ~60s wall-clock time at ~3s per callout.
	 * Subscribers can override via `AsynchronousJobSetting__mdt.FLOW_CallApiAsync`.
	 */
	public static final Integer DEFAULT_JOB_SIZE = 20;

	/**
	 * @description Hard ceiling for callout job size, equal to the Salesforce governor limit for
	 * callouts per transaction (`Limits.getLimitCallouts()`). Applied after reading
	 * `AsynchronousJobSetting__mdt` to prevent a misconfigured `BatchSize__c` from causing
	 * `System.LimitException: Too many callouts`.
	 *
	 * @since 1.0
	 */
	public static final Integer MAXIMUM_CALLOUT_JOB_SIZE = 100;

	/**
	 * @description The shortest wait, in minutes, before a call that Salesforce refused to start is tried again. A call
	 * that was not waiting at Retry before always waits this long.
	 */
	public static final Integer MINIMUM_WAIT_MINUTES = 15;

	/**
	 * @description The longest wait, in minutes, before a call that Salesforce refused to start is tried again. Each new
	 * refusal doubles the last wait, up to this value.
	 */
	public static final Integer MAXIMUM_WAIT_MINUTES = 240;

	/**
	 * @description The class and method the warnings of this class are filed under.
	 */
	@TestVisible
	private static final String LOG_LOCATION = FLOW_CallApiAsync.class.getName() + '/invokeApiCallAsynchronously';

	/**
	 * @description The context key for the number of calls that now wait at Retry.
	 */
	@TestVisible
	private static final String CONTEXT_WAITING_CALL_COUNT = 'waitingCallCount';

	/**
	 * @description The context key for the earliest time at which one of the waiting calls is tried again.
	 */
	@TestVisible
	private static final String CONTEXT_EARLIEST_NEXT_RETRY = 'earliestNextRetry';

	/**
	 * @description The context key for the number of calls whose background job Salesforce did start.
	 */
	@TestVisible
	private static final String CONTEXT_STARTED_CALL_COUNT = 'startedCallCount';

	/**
	 * @description The context key for the type name of the error Salesforce raised when it refused to start the job.
	 */
	@TestVisible
	private static final String CONTEXT_CAUSE_TYPE = 'causeType';

	/**
	 * @description The context key for the Id of the first call that now waits at Retry.
	 */
	@TestVisible
	private static final String CONTEXT_FIRST_WAITING_CALL_ID = 'firstWaitingCallId';

	/**
	 * @description The context key for the number of calls whose job Salesforce did not start, saved at Retry or not.
	 */
	@TestVisible
	private static final String CONTEXT_UNSENT_CALL_COUNT = 'unsentCallCount';

	/**
	 * @description The context key for the Ids of the calls that were not saved at Retry after a refused start, separated by
	 * commas.
	 */
	@TestVisible
	private static final String CONTEXT_NOT_SAVED_CALL_IDS = 'notSavedCallIds';

	/**
	 * @description The context key for the Ids of the calls left out of the send, separated by commas.
	 */
	@TestVisible
	private static final String CONTEXT_NOT_SENT_CALL_IDS = 'notSentCallIds';

	/**
	 * @description The warning written when some calls at Retry could not be saved at Retrying and were left out of the
	 * send. {0} is the number of those calls, {1} their Ids.
	 */
	private static final String MESSAGE_CALLS_NOT_SENT = '{0} calls at Retry could not be saved at Retrying, so they were not sent this time: {1}. '
			+ 'They stay at Retry. Where the outbound retry watchdog job (SCHED_OutboundRetryWatchdog) is scheduled, it gives them a new retry time.';

	/**
	 * @description The warning written when Salesforce refused to start the send and some calls now wait at Retry.
	 * {0} is the number of waiting calls, {1} the number of calls that were not sent, {2} the earliest time one of the
	 * waiting calls is tried again (ISO 8601, in UTC), {3} the number of calls whose job had already started.
	 */
	private static final String MESSAGE_CALLS_WAITING = 'Salesforce refused to start the background send. {0} of {1} calls that were not sent wait at Retry; '
			+ 'the first is tried again at {2}. {3} calls had already started.';

	/**
	 * @description The warning written when Salesforce refused to start the send but named no call as not started, so
	 * no call was changed. It is used only when the refusal names no call at all. {0} is the number of calls received.
	 */
	private static final String MESSAGE_NO_CALL_WAITING = 'Salesforce refused to start the background send, but named no call as not started, '
			+ 'so no call was changed. {0} calls were received.';

	/**
	 * @description The warning written when Salesforce refused to start the send and no call that was not started could
	 * be saved at Retry. The error log gives the reason each save was refused. {0} is the number of calls that were not
	 * started, {1} the number of calls whose job had already started.
	 */
	private static final String MESSAGE_NO_CALL_SAVED = 'Salesforce refused to start the background send. {0} calls were not sent, '
			+ 'and none of them could be saved at Retry; the error log gives the reason for each. {1} calls had already started.';

	/**
	 * @description The number of milliseconds in one minute.
	 */
	private static final Decimal MILLISECONDS_PER_MINUTE = 60000;

	/**
	 * @description Invokes web service calls asynchronously by enqueuing Queueable jobs for each set of API calls.
	 * Falls back to Batch job if Queueable limits are exceeded. The job size is read from
	 * `AsynchronousJobSetting__mdt.FLOW_CallApiAsync` (default: 20) to keep each execution within
	 * the 100-callout governor limit.
	 *
	 * Before the jobs start, every call whose Status__c is Retry is saved with the status Retrying, so the Retry
	 * Outbound Api Call flow does not pick it up a second time. Calls at any other status are not changed here.
	 *
	 * The saves this method makes ignore record sharing, so they work whoever the flow runs as. This means the method
	 * changes the calls it is given even when the running user cannot see or edit them.
	 *
	 * If the save of a call to Retrying is refused anyway, for example by a validation rule, that call is not sent this
	 * time. It stays at Retry, and one warning log entry lists the Ids of the calls that were not sent. Where the outbound
	 * retry watchdog job is scheduled, it gives those calls a new retry time.
	 *
	 * If the save to Retrying is refused for every call given, no job is started.
	 *
	 * Salesforce can refuse to start a background job, for example when the org has used its daily allowance of
	 * background jobs. This method then returns normally, and the save that called it does not fail:
	 * - Each call whose job did not start is saved at Status__c Retry, with a later NextRetry__c and the reason in
	 *   ErrorMessages__c. A call that was not saved yet is saved as a new call. The Retry Outbound Api Call flow sends
	 *   the call at that time.
	 * - Retries__c does not change and no API issue is raised, because the request was never sent.
	 * - The wait is twice the call's last wait, never less than 15 minutes and never more than 240. A call that is not
	 *   at Retry waits 15 minutes, and each new refusal of the same call doubles the wait.
	 * - Calls whose job did start are sent as usual and are not changed.
	 * - One warning log entry says how many calls wait and when the first one is tried again. No error entry is written
	 *   for the refused start. A call whose save at Retry is refused is not counted as waiting; it gets an error log entry.
	 *
	 * A job refused later, in a send split into a chain of jobs or in a send that runs as one batch job, is only logged
	 * as an ERROR. Its calls are not changed, and a call that was not saved yet is lost. Inside a batch, queueable or
	 * future job, save your calls before you pass them.
	 *
	 * The Web Services guide gives the full rules, under "What happens when Salesforce refuses to start a send?" and
	 * "Which refused sends are only logged?".
	 *
	 * @param apiCalls The list of API calls containing details for API callouts.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * List<ApiCall__c> apiCalls = new List<ApiCall__c>();
	 * ApiCall__c apiCall = TST_Factory.newOutboundApiCall('API_GetCustomerInfo', null, new Map<String, String>{'customerId' => '5678'});
	 * apiCalls.add(apiCall);
	 * FLOW_CallApiAsync.invokeApiCallAsynchronously(apiCalls);
	 * ```
	 */

	@InvocableMethod
	(
			category='Api Callouts'
			label='Invoke Callout Asynchronously'
			description='Queues an HTTP callout asynchronously. Use when a Flow sends data to an external service and does not need to wait for the response.'
	)
	global static void invokeApiCallAsynchronously(List<ApiCall__c> apiCalls)
	{
		List<ApiCall__c> callsToSend = markRetryCallsAsRetrying(apiCalls);
		// The calls to send are some of the calls given. When only the calls to send are empty, calls were given but none
		// is left to send, and a job for an empty list would only log a refusal.
		if(callsToSend.isEmpty() != apiCalls.isEmpty())
		{
			return;
		}
		Integer jobSize = Math.min(
				SEL_AsynchronousJobSetting.getBatchSize(FLOW_CallApiAsync.class.getName(), DEFAULT_JOB_SIZE),
				MAXIMUM_CALLOUT_JOB_SIZE
		);
		UTIL_AsynchronousJobLauncher.DTO_AsynchronousJobRequest request = new UTIL_AsynchronousJobLauncher.DTO_AsynchronousJobRequest(callsToSend)
				.withBatchSize(jobSize)
				.withQueueableJobSize(jobSize)
				.withExecutionStrategy(IF_Async.AsynchronousExecutionStrategy.AUTO)
				.withLaunchRefusalHandledByCaller();
		try
		{
			UTIL_AsynchronousJobLauncher.process(request, new ApiCallProcessor());
		}
		catch(UTIL_Exceptions.LaunchRefusedException refused)
		{
			scheduleRefusedCallsForRetry(callsToSend, refused);
		}
	}

	/**
	 * @description Works out how many minutes a call waits before it is tried again after Salesforce refused to start
	 * its job. The last wait of a call at Retry is the time from its last save (LastModifiedDate) to its NextRetry__c,
	 * rounded to whole minutes. The next wait is twice the last wait, never less than 15 and never more than 240
	 * minutes. A call at any other status, or a call at Retry whose last wait cannot be read (no NextRetry__c, no
	 * LastModifiedDate on the record given, or a NextRetry__c that is not after the last save), waits 15 minutes.
	 *
	 * Read the call before anything saves it again: a new save moves LastModifiedDate, and the last wait is lost.
	 *
	 * @param call The call as it was read, with Status__c, NextRetry__c and, for a call at Retry, LastModifiedDate.
	 *
	 * @return The number of minutes to wait, from 15 to 240.
	 */
	public static Integer computeNextWaitMinutes(ApiCall__c call)
	{
		Long doubledLastWaitMinutes = 2 * readLastWaitMinutes(call);
		return (Integer)Math.min(MAXIMUM_WAIT_MINUTES, Math.max(MINIMUM_WAIT_MINUTES, doubledLastWaitMinutes));
	}

	/**
	 * @description Reads how many minutes a call at Retry was last told to wait: the time from its last save to its
	 * NextRetry__c, rounded to whole minutes.
	 *
	 * @param call The call as it was read.
	 *
	 * @return The last wait in minutes, or 0 when the call is not at Retry or the wait cannot be read.
	 */
	private static Long readLastWaitMinutes(ApiCall__c call)
	{
		if(call.Status__c != SEL_ApiCall.STATUS_RETRY || call.NextRetry__c == null || !call.isSet(ApiCall__c.LastModifiedDate) || call.LastModifiedDate == null)
		{
			return 0;
		}
		Long lastWaitMilliseconds = call.NextRetry__c.getTime() - call.LastModifiedDate.getTime();
		return Math.max(0L, (lastWaitMilliseconds / MILLISECONDS_PER_MINUTE).round(System.RoundingMode.HALF_UP));
	}

	/**
	 * @description Saves every call at Retry with the status Retrying before its job starts, so the Retry Outbound Api
	 * Call flow does not pick it up again while it is being sent. The calls given are not changed: a copy holding only
	 * the Id and the new status is saved, so the last wait can still be read from the calls given if the start is
	 * refused.
	 *
	 * The save ignores record sharing, so it works whoever the flow runs as.
	 *
	 * A call whose save is refused anyway (for example by a validation rule or a locked record) is not sent: it still
	 * shows Retry, and sending it would let the flow send it a second time. It stays at Retry, and one warning log entry
	 * lists the Ids of the calls left out. The flow does not pick up a call again while it is not changed, so the
	 * outbound retry watchdog job, where it is scheduled, gives it a new retry time.
	 *
	 * A call given more than once is saved once.
	 *
	 * @param apiCalls The calls as they were received.
	 *
	 * @return The calls to send: every call given, except a call at Retry whose save to Retrying was refused.
	 */
	private static List<ApiCall__c> markRetryCallsAsRetrying(List<ApiCall__c> apiCalls)
	{
		Set<Id> retryCallIds = new Set<Id>();
		for(ApiCall__c apiCall : apiCalls)
		{
			if(apiCall.Status__c == SEL_ApiCall.STATUS_RETRY)
			{
				retryCallIds.add(apiCall.Id);
			}
		}
		// A call that is not saved yet has no Id, so there is nothing to mark.
		retryCallIds.remove(null);
		if(retryCallIds.isEmpty())
		{
			return apiCalls;
		}
		List<ApiCall__c> retryingCalls = new List<ApiCall__c>();
		for(Id retryCallId : retryCallIds)
		{
			retryingCalls.add(new ApiCall__c(Id = retryCallId, Status__c = SEL_ApiCall.STATUS_RETRYING));
		}
		Set<Id> refusedCallIds = retryCallIds.clone();
		refusedCallIds.removeAll(collectSavedIds(newSaveTransaction().doUpdate(retryingCalls).allowPartial().execute().getUpdateResults()));
		List<ApiCall__c> callsToSend = new List<ApiCall__c>();
		for(ApiCall__c apiCall : apiCalls)
		{
			if(!refusedCallIds.contains(apiCall.Id))
			{
				callsToSend.add(apiCall);
			}
		}
		logCallsNotSent(refusedCallIds);
		return callsToSend;
	}

	/**
	 * @description Writes one warning log entry that lists the calls left out of the send, because their save to
	 * Retrying was refused. Nothing is written when no call was left out.
	 *
	 * @param refusedCallIds The Ids of the calls left out of the send.
	 */
	private static void logCallsNotSent(Set<Id> refusedCallIds)
	{
		if(refusedCallIds.isEmpty())
		{
			return;
		}
		String callIds = String.join(new List<Id>(refusedCallIds), ', ');
		LOG_Builder.build()
				.warn(String.format(MESSAGE_CALLS_NOT_SENT, new List<Object> {refusedCallIds.size(), callIds}))
				.withContext(CONTEXT_NOT_SENT_CALL_IDS, callIds)
				.emitAt(LOG_LOCATION);
	}

	/**
	 * @description Collects the Ids of the records a save accepted.
	 *
	 * @param results The results of the save.
	 *
	 * @return The Ids of the accepted records. A refused record, and a record with no result, is not in it.
	 */
	private static Set<Id> collectSavedIds(List<Database.SaveResult> results)
	{
		Set<Id> savedIds = new Set<Id>();
		for(Database.SaveResult result : results)
		{
			// Salesforce gives the result of a refused record no Id, so only accepted records add an Id.
			savedIds.add(result.getId());
		}
		savedIds.remove(null);
		return savedIds;
	}

	/**
	 * @description Starts a save of the framework's own call records: it skips the running user's object and field
	 * permission checks and ignores record sharing, so the retry bookkeeping of a call does not depend on who the flow
	 * runs as. It writes no entry to the bypass audit (the log of who switched off a framework check), because the
	 * framework makes this save on its own. A refused record does not stop the others.
	 *
	 * @return A new save, ready for its records.
	 */
	private static DML_Builder newSaveTransaction()
	{
		return DML_Builder.newTransaction().systemModeInternal().bypassSharingInternal();
	}

	/**
	 * @description Saves each call that Salesforce did not start at Status__c Retry. NextRetry__c is set to now plus the
	 * call's wait (see computeNextWaitMinutes), and ErrorMessages__c says why the call was not sent. Retries__c is not
	 * changed, because the request was never sent.
	 *
	 * A call that was not saved yet (it has no Id) is saved as a new call: a copy of the fields it was given, with the
	 * same three fields set. New and changed calls go in one save, which ignores record sharing. Calls whose job did
	 * start are not touched.
	 *
	 * Writes one warning log entry with the number of waiting calls, the number of calls that were not sent, the earliest
	 * new time, the number of started calls, the type of the error, the Id of the first waiting call and the Ids of the
	 * calls already in the database whose save was refused.
	 *
	 * Only a call whose save succeeded counts as waiting. A call whose save was refused is not counted as waiting; the
	 * warning lists its Id when it has one. The save writes an error log entry for it.
	 *
	 * Visible to tests only, and used only by FLOW_CallApiAsync_TEST: the tests hand it refusals that the action's own
	 * launch cannot produce, a start that Salesforce refused part way through and the message Salesforce gives at the
	 * 24-hour limit.
	 *
	 * @param apiCalls Every call that was handed to the launcher, as it was received.
	 * @param refused The refusal, which names the calls that were not started.
	 */
	@TestVisible
	private static void scheduleRefusedCallsForRetry(List<ApiCall__c> apiCalls, UTIL_Exceptions.LaunchRefusedException refused)
	{
		Exception cause = refused.getCause() ?? refused;
		// The label puts its own full stop after the reason, so one full stop that ends the reason is dropped.
		String reason = cause.getMessage()?.removeEnd('.');
		Datetime now = UTIL_Date.truncateToSeconds(Datetime.now());
		List<ApiCall__c> callsToSave = new List<ApiCall__c>();
		List<ApiCall__c> newCalls = new List<ApiCall__c>();
		List<ApiCall__c> changedCalls = new List<ApiCall__c>();
		Set<Id> notSavedCallIds = new Set<Id>();

		for(Object unsentItem : refused.unsentItems)
		{
			ApiCall__c unsentCall = (ApiCall__c)unsentItem;
			Datetime nextRetry = now.addMinutes(computeNextWaitMinutes(unsentCall));
			ApiCall__c callToSave;
			if(unsentCall.Id == null)
			{
				callToSave = unsentCall.clone(false, true, false, false);
				newCalls.add(callToSave);
			}
			else
			{
				callToSave = new ApiCall__c(Id = unsentCall.Id);
				changedCalls.add(callToSave);
				notSavedCallIds.add(unsentCall.Id);
			}
			callToSave.Status__c = SEL_ApiCall.STATUS_RETRY;
			callToSave.NextRetry__c = nextRetry;
			callToSave.ErrorMessages__c = String.format(System.Label.OutboundCall_LaunchRefused, new List<Object> {reason, UTIL_Date.toIso8601(nextRetry)});
			callsToSave.add(callToSave);
		}

		List<ApiCall__c> waitingCalls = saveWaitingCalls(callsToSave, newCalls, changedCalls, notSavedCallIds);
		Datetime earliestNextRetry = findEarliestNextRetry(waitingCalls);
		Integer startedCallCount = apiCalls.size() - refused.unsentItems.size();
		String message;
		if(refused.unsentItems.isEmpty())
		{
			message = String.format(MESSAGE_NO_CALL_WAITING, new List<Object> {apiCalls.size()});
		}
		else if(waitingCalls.isEmpty())
		{
			message = String.format(MESSAGE_NO_CALL_SAVED, new List<Object> {refused.unsentItems.size(), startedCallCount});
		}
		else
		{
			message = String.format(
					MESSAGE_CALLS_WAITING,
					new List<Object> {waitingCalls.size(), refused.unsentItems.size(), UTIL_Date.toIso8601(earliestNextRetry), startedCallCount}
			);
		}

		LOG_Builder.build()
				.warn(message)
				.withContext(CONTEXT_WAITING_CALL_COUNT, waitingCalls.size())
				.withContext(CONTEXT_UNSENT_CALL_COUNT, refused.unsentItems.size())
				.withContext(CONTEXT_EARLIEST_NEXT_RETRY, earliestNextRetry)
				.withContext(CONTEXT_STARTED_CALL_COUNT, startedCallCount)
				.withContext(CONTEXT_CAUSE_TYPE, cause.getTypeName())
				.withContext(CONTEXT_FIRST_WAITING_CALL_ID, waitingCalls.isEmpty() ? null : waitingCalls[0].Id)
				.withContext(CONTEXT_NOT_SAVED_CALL_IDS, String.join(new List<Id>(notSavedCallIds), ', '))
				.emitAt(LOG_LOCATION);
	}

	/**
	 * @description Saves the calls that now wait at Retry, in one save that ignores record sharing. New calls are
	 * inserted and saved calls are updated. A refused call does not stop the others, and the save writes an error log
	 * entry for it.
	 *
	 * @param callsToSave Every call to save, in the order the refusal named them.
	 * @param newCalls The calls among them that have no Id yet.
	 * @param changedCalls The calls among them that are already saved.
	 * @param notSavedCallIds The Ids of the calls already in the database. The method removes the Id of each call the save
	 * accepted, so afterwards the set holds only the Ids of the calls whose save at Retry was refused.
	 *
	 * @return The calls the save accepted, in the order the refusal named them. A refused call is not in it.
	 */
	private static List<ApiCall__c> saveWaitingCalls(
			List<ApiCall__c> callsToSave,
			List<ApiCall__c> newCalls,
			List<ApiCall__c> changedCalls,
			Set<Id> notSavedCallIds
	)
	{
		List<ApiCall__c> waitingCalls = new List<ApiCall__c>();
		DML_Builder.TransactionResult result = newSaveTransaction().doInsert(newCalls).doUpdate(changedCalls).allowPartial().execute();
		Set<Id> savedCallIds = collectSavedIds(result.getUpdateResults());
		savedCallIds.addAll(result.getInsertedIds());
		notSavedCallIds.removeAll(savedCallIds);
		for(ApiCall__c callToSave : callsToSave)
		{
			if(savedCallIds.contains(callToSave.Id))
			{
				waitingCalls.add(callToSave);
			}
		}
		return waitingCalls;
	}

	/**
	 * @description Finds the earliest retry time among the calls that wait at Retry.
	 *
	 * @param waitingCalls The calls that were saved at Retry.
	 *
	 * @return The earliest NextRetry__c, or null when no call waits.
	 */
	private static Datetime findEarliestNextRetry(List<ApiCall__c> waitingCalls)
	{
		List<Datetime> nextRetries = new List<Datetime>();
		for(ApiCall__c waitingCall : waitingCalls)
		{
			nextRetries.add(waitingCall.NextRetry__c);
		}
		nextRetries.sort();
		return nextRetries.isEmpty() ? null : nextRetries[0];
	}

	/**
	 * @description Processor that executes API call records via the API dispatcher.
	 */
	private class ApiCallProcessor implements IF_Async.Processable
	{
		/**
		 * @description Executes the API callouts for the provided API calls.
		 *
		 * @param items The list of ApiCall__c records to process.
		 */
		public void execute(List<Object> items)
		{
			List<ApiCall__c> apiCalls = new List<ApiCall__c>();
			for(Object item : items)
			{
				apiCalls.add((ApiCall__c)item);
			}
			API_Dispatcher.execute(apiCalls);
		}
	}
}