// SPDX-License-Identifier: Apache-2.0
/**
 * @description A scheduled job that finds outbound calls the Retry Outbound Api Call flow will never send again, and
 * deals with each one in a fixed way. It never sends a request itself. Schedule it through the job runner (a
 * ScheduledJob__c record with this class name), for example every hour.
 *
 * Each run reads three kinds of stale outbound call. A call is stale when the time it is judged by is older than the
 * stale limit (the StaleThresholdMinutes parameter, 60 minutes by default):
 *
 * - A call at Retry whose retry time (NextRetry__c) is stale gets a new retry time, so the flow sends it again. The
 *   new wait is twice the last wait, from 15 to 240 minutes. Its retry count does not change. One warning is logged.
 * - A call at Retrying whose retry time is stale is being sent again by a background job that has not finished. While
 *   a job of the class that sends outbound calls is waiting or running, and was created after the call's retry time,
 *   that job may still send it, so the call is left as it is and checked again on the next run. After one day, or
 *   when no such job is live, the call is marked Failed, with text that says the request may have been sent. When
 *   the service's API setting logs issues, an API issue is raised that says the other system may have acted on it.
 * - A call at Queued that has not changed for longer than the stale limit is only reported, in one warning.
 *
 * A call at Retry with no retry time is left as it is. Each run looks at no more than the batch size (the BatchSize
 * parameter, 50 by default and never more than 50) of each kind; the rest wait for the next run.
 *
 * The job reads and saves the calls without record sharing, so a run changes the calls of every user, whoever runs it.
 * A warning or an API issue is written only for a call whose change was saved: a call the save refused is not reported
 * as changed.
 *
 * @see SCHED_Base
 * @see SCHED_OutboundRetryWatchdog_TEST
 * @see SEL_ApiCall
 *
 * @author Jason van Beukering
 *
 * @group Web Services
 *
 * @date November 2026
 *
 * @since 1.12
 *
 * @example
 * ```apex
 * SCHED_OutboundRetryWatchdog job = new SCHED_OutboundRetryWatchdog();
 * DTO_NameValues attributes = new DTO_NameValues();
 * attributes.add('StaleThresholdMinutes', '60');
 * attributes.add('BatchSize', '50');
 * job.setParameterValues(attributes);
 * System.schedule('Outbound Retry Watchdog', '0 0 * * * ?', job);
 * ```
 */
@SuppressWarnings('PMD.AvoidGlobalModifier')
global inherited sharing class SCHED_OutboundRetryWatchdog extends SCHED_Base
{
	/**
	 * @description The name of the optional parameter for the most calls of each kind one run looks at.
	 */
	public static final String PARAMETER_BATCH_SIZE = 'BatchSize';

	/**
	 * @description The name of the optional parameter for the number of minutes after which a call counts as stale.
	 */
	public static final String PARAMETER_STALE_THRESHOLD_MINUTES = 'StaleThresholdMinutes';

	/**
	 * @description The class and method every log entry of the watchdog is filed under.
	 */
	public static final String LOG_LOCATION = SCHED_OutboundRetryWatchdog.class.getName() + '/execute';

	/**
	 * @description The text logged for a call at Retrying that is left as it is, because a job that may still send it is
	 * waiting or running.
	 */
	public static final String MESSAGE_LEFT_FOR_LIVE_JOB = 'This call is still at Retrying after its retry was due. A background job that may still '
			+ 'send it is waiting or running, so the call was not changed. It is checked again the next time the watchdog runs.';

	/**
	 * @description The warning logged for calls at Queued that have not changed for too long. {0} is the number of calls,
	 * {1} the stale limit in minutes, {2} the names of the calls.
	 */
	public static final String MESSAGE_STALE_QUEUED_CALLS = '{0} outbound call(s) have been at Queued without a change for more than {1} minutes, '
			+ 'so their send may never have started. They were not changed. Check them and send them again if needed: {2}';

	/**
	 * @description The stale limit, in minutes, when the job is given none.
	 */
	private static final Integer DEFAULT_STALE_THRESHOLD_MINUTES = 60;

	/**
	 * @description The batch size when the job is given none.
	 */
	private static final Integer DEFAULT_BATCH_SIZE = 50;

	/**
	 * @description The most calls of each kind one run looks at. A larger batch size is lowered to this value, so one
	 * run stays well inside the platform limits of one transaction. The reads leave out the request and the response of
	 * each call, which can each hold 131,072 characters, so most of the memory a run could use is never loaded. The
	 * request parameters are still read, because the API issue of a lost call copies them.
	 */
	private static final Integer MAXIMUM_BATCH_SIZE = 50;

	/**
	 * @description The longest time, in hours after its retry was due, that a call at Retrying is left waiting for a live
	 * job. Any job of the class that sends outbound calls keeps a call waiting, so the wait must end.
	 */
	private static final Integer MAXIMUM_WAIT_FOR_LIVE_JOB_HOURS = 24;

	/**
	 * @description The number of milliseconds in one hour.
	 */
	private static final Long MILLISECONDS_PER_HOUR = 3600000;

	/**
	 * @description The text that separates the names of the calls in the warning about calls at Queued.
	 */
	private static final String NAME_SEPARATOR = ', ';

	/**
	 * @description The context key for the retry time a stale call at Retry had before this run gave it a new one.
	 */
	@TestVisible
	private static final String CONTEXT_PREVIOUS_NEXT_RETRY = 'previousNextRetry';

	/**
	 * @description The context key for the new retry time this run gave a stale call at Retry.
	 */
	@TestVisible
	private static final String CONTEXT_NEXT_RETRY = 'nextRetry';

	/**
	 * @description The context key for the Id of the stale call at Retry that was given a new retry time.
	 */
	@TestVisible
	private static final String CONTEXT_API_CALL_ID = 'apiCallId';

	/**
	 * @description Runs one check of the stale outbound calls, with the stale limit and the batch size the job was given
	 * (see the class description for what happens to each kind of call). The run saves in two steps:
	 *
	 * - First it saves the changes to the calls. A call that cannot be saved does not stop the others.
	 * - Then it logs a warning for each call the save accepted, and saves the API issues of the lost calls the save
	 *   accepted.
	 *
	 * A call the save refused gets no warning and no API issue, so the log never reports a change that was not made.
	 * Both saves skip the running user's object and field permission checks (system mode) and ignore record sharing, as
	 * the reads do. So a run changes the calls of every user, whoever runs it.
	 *
	 * @param context The SchedulableContext for the scheduled job execution; it is not read.
	 *
	 * @example
	 * ```apex
	 * new SCHED_OutboundRetryWatchdog().execute(null);
	 * ```
	 */
	public void execute(SchedulableContext context)
	{
		Integer staleThresholdMinutes = readStaleThresholdMinutes();
		Integer batchSize = readBatchSize();
		Datetime now = Datetime.now();
		Datetime cutoff = now.addMinutes(-staleThresholdMinutes);
		SEL_ApiCall selector = new SEL_ApiCall();
		List<CallChange> changes = new List<CallChange>();

		scheduleStaleRetryCalls(selector.findOutboundRetryDueBefore(cutoff, batchSize), now, changes);
		failLostRetryingCalls(selector.findOutboundRetryingDueBefore(cutoff, batchSize), now, changes);
		reportStaleQueuedCalls(selector.findOutboundQueuedUnchangedSince(cutoff, batchSize), staleThresholdMinutes);

		saveAndReportChanges(changes);
	}

	/**
	 * @description Returns the parameter definitions supported by this scheduled job.
	 *
	 * @return The definitions of the stale limit in minutes and the batch size.
	 *
	 * @example
	 * ```apex
	 * List<DTO_ScheduledParameterDefinition> parameters = new SCHED_OutboundRetryWatchdog().getParameterDefinitions();
	 * ```
	 */
	public override List<DTO_ScheduledParameterDefinition> getParameterDefinitions()
	{
		return new List<DTO_ScheduledParameterDefinition>
		{
				DTO_ScheduledParameterDefinition.of(PARAMETER_STALE_THRESHOLD_MINUTES)
						.asNumeric()
						.withDefault(String.valueOf(DEFAULT_STALE_THRESHOLD_MINUTES))
						.withDescription('Minutes after its retry was due (or, for a Queued call, after its last change) before an outbound call is treated '
								+ 'as stale. A value below 1 uses 60.'),
				DTO_ScheduledParameterDefinition.of(PARAMETER_BATCH_SIZE)
						.asNumeric()
						.withDefault(String.valueOf(DEFAULT_BATCH_SIZE))
						.withDescription('Maximum calls of each kind (Retry, Retrying, Queued) looked at in one run. Values above 50 are lowered to 50, '
								+ 'so one run never runs out of platform resources partway through. The rest wait for the next run.')
		};
	}

	/**
	 * @description Reads the stale limit the job was given, or 60 minutes when it was given none or a value below 1.
	 *
	 * @return The stale limit in minutes.
	 */
	private Integer readStaleThresholdMinutes()
	{
		Integer configured = getNumericParameter(PARAMETER_STALE_THRESHOLD_MINUTES);
		return configured == null || configured < 1 ? DEFAULT_STALE_THRESHOLD_MINUTES : configured;
	}

	/**
	 * @description Reads the batch size the job was given, lowered to 50, or 50 when it was given none or a value below 1.
	 *
	 * @return The batch size.
	 */
	private Integer readBatchSize()
	{
		Integer configured = getNumericParameter(PARAMETER_BATCH_SIZE);
		return configured == null || configured < 1 ? DEFAULT_BATCH_SIZE : Math.min(configured, MAXIMUM_BATCH_SIZE);
	}

	/**
	 * @description Saves the changes to the calls, then reports only the changes the save accepted: one warning for each
	 * accepted call, and the API issue of each accepted lost call, saved in a second step. Every change is to a
	 * different API call, and the save holds no other object, so the result at each position of the update results
	 * belongs to the change at the same position. A change with no result (the save stopped before it) counts as refused.
	 *
	 * @param changes The changes this run made, in the order they were found.
	 */
	private static void saveAndReportChanges(List<CallChange> changes)
	{
		if(changes.isEmpty())
		{
			return;
		}
		List<ApiCall__c> changedCalls = new List<ApiCall__c>();
		for(CallChange change : changes)
		{
			changedCalls.add(change.changedCall);
		}
		List<Database.SaveResult> results = newSaveTransaction().doUpdate(changedCalls).allowPartial().execute().getUpdateResults();
		List<ApiIssue__c> issues = new List<ApiIssue__c>();
		for(Integer index = 0; index < changes.size() && index < results.size(); index++)
		{
			if(results[index].isSuccess())
			{
				CallChange change = changes[index];
				change.logWarning();
				if(change.issue != null)
				{
					issues.add(change.issue);
				}
			}
		}
		if(!issues.isEmpty())
		{
			newSaveTransaction().doInsert(issues).allowPartial().execute();
		}
	}

	/**
	 * @description Starts a save of the framework's own records: it skips the running user's object and field
	 * permission checks and ignores record sharing, as the reads of this job do. It writes no entry to the bypass audit
	 * (the log of who switched off a framework check), because the framework makes this save on its own.
	 *
	 * @return A new save, ready for its records.
	 */
	private static DML_Builder newSaveTransaction()
	{
		return DML_Builder.newTransaction().systemModeInternal().bypassSharingInternal();
	}

	/**
	 * @description Gives each stale call at Retry a new retry time: now plus twice its last wait, from 15 to 240 minutes
	 * (see FLOW_CallApiAsync.computeNextWaitMinutes). The status, the retry count and the error text do not change.
	 * Each call gets one warning, once the save accepts its change.
	 *
	 * @param calls The stale calls at Retry, as read, with LastModifiedDate.
	 * @param now The time of this run.
	 * @param changes The list the changes are added to.
	 */
	private static void scheduleStaleRetryCalls(List<ApiCall__c> calls, Datetime now, List<CallChange> changes)
	{
		for(ApiCall__c call : calls)
		{
			Datetime nextRetry = UTIL_Date.truncateToSeconds(now.addMinutes(FLOW_CallApiAsync.computeNextWaitMinutes(call)));
			changes.add(new CallChange(call, new ApiCall__c(Id = call.Id, NextRetry__c = nextRetry), null));
		}
	}

	/**
	 * @description Decides what happens to each stale call at Retrying. A call is left as it is, with one information
	 * entry, while a live job of the class that sends outbound calls was created after its retry time, but only for one
	 * day after that time. Every other call is marked Failed (see markCallLost).
	 *
	 * @param calls The stale calls at Retrying, as read.
	 * @param now The time of this run.
	 * @param changes The list the changes are added to.
	 */
	private static void failLostRetryingCalls(List<ApiCall__c> calls, Datetime now, List<CallChange> changes)
	{
		if(calls.isEmpty())
		{
			return;
		}
		Datetime newestLiveJobCreatedDate = findNewestLiveSenderJobCreatedDate(findEarliestRetryTime(calls));
		Map<String, Boolean> logsIssuesByServiceName = new Map<String, Boolean>();
		for(ApiCall__c call : calls)
		{
			Integer hoursWaited = ((now.getTime() - call.NextRetry__c.getTime()) / MILLISECONDS_PER_HOUR).intValue();
			Boolean mayStillBeSent = newestLiveJobCreatedDate != null && newestLiveJobCreatedDate > call.NextRetry__c;
			if(mayStillBeSent && hoursWaited < MAXIMUM_WAIT_FOR_LIVE_JOB_HOURS)
			{
				LOG_Builder.build().info(MESSAGE_LEFT_FOR_LIVE_JOB).forRecord(call.Id).emitAt(LOG_LOCATION);
				continue;
			}
			changes.add(markCallLost(call, hoursWaited, logsIssuesByServiceName));
		}
	}

	/**
	 * @description Builds the change that marks one call at Retrying Failed: no retry time, and error text that says no
	 * job finished it and the request may have been sent. The retry count does not change.
	 *
	 * When the service's API setting logs issues, also builds an outbound API issue for the call that says the other
	 * system may have acted on the request. The issue is saved, and one warning is logged, only once the save accepts the
	 * change to the call.
	 *
	 * The issue takes its text from the call's error text, which this method sets first, so the issue never needs the
	 * call's response, and the read does not load it.
	 *
	 * @param call The call, as read.
	 * @param hoursWaited The whole hours since the call's retry was due.
	 * @param logsIssuesByServiceName Whether each service logs issues, filled as services are read.
	 *
	 * @return The change to the call, with its API issue when the service logs issues.
	 */
	private static CallChange markCallLost(ApiCall__c call, Integer hoursWaited, Map<String, Boolean> logsIssuesByServiceName)
	{
		String lostText = String.format(System.Label.OutboundRetryWatchdog_LostJob, new List<Object> {hoursWaited});
		ApiCall__c changedCall = new ApiCall__c(Id = call.Id, Status__c = SEL_ApiCall.STATUS_FAILED, NextRetry__c = null, ErrorMessages__c = lostText);
		ApiIssue__c issue;
		if(isLoggingIssues(call.ServiceName__c, logsIssuesByServiceName))
		{
			call.ErrorMessages__c = lostText;
			issue = API_Outbound.buildOutboundFailureRecord(call, API_Outbound.buildRequestParametersHash(call.RequestParameters__c));
			issue.ExternalSystemMayHaveActed__c = true;
			issue.IdempotencyKey__c = call.IdempotencyKey__c;
		}
		return new CallChange(call, changedCall, issue);
	}

	/**
	 * @description Checks whether the API setting of a service logs issues (LogIssues__c). Each service is read once per
	 * run.
	 *
	 * @param serviceName The service name of the call.
	 * @param logsIssuesByServiceName The answers found so far, by service name.
	 *
	 * @return True when the service has a setting that logs issues.
	 */
	private static Boolean isLoggingIssues(String serviceName, Map<String, Boolean> logsIssuesByServiceName)
	{
		if(!logsIssuesByServiceName.containsKey(serviceName))
		{
			String className = SEL_ApiSetting.findClassNameByServiceName(serviceName);
			ApiSetting__mdt setting = String.isBlank(className) ? null : new SEL_ApiSetting().findByClassName(className);
			logsIssuesByServiceName.put(serviceName, setting?.LogIssues__c == true);
		}
		return logsIssuesByServiceName.get(serviceName);
	}

	/**
	 * @description Finds the earliest retry time among the calls.
	 *
	 * @param calls The calls, each with a retry time.
	 *
	 * @return The earliest retry time.
	 */
	private static Datetime findEarliestRetryTime(List<ApiCall__c> calls)
	{
		Datetime earliest = calls[0].NextRetry__c;
		for(ApiCall__c call : calls)
		{
			earliest = call.NextRetry__c < earliest ? call.NextRetry__c : earliest;
		}
		return earliest;
	}

	/**
	 * @description Finds when the newest live job of the class that sends outbound calls was created, among the jobs
	 * created after the given time. Those jobs run as UTIL_AdaptiveAsynchronousProcessor. A call does not record which
	 * job sends it, so any live job of that class counts.
	 *
	 * @param after Only jobs created after this time count.
	 *
	 * @return The creation time of the newest such job, or null when there is none.
	 */
	private static Datetime findNewestLiveSenderJobCreatedDate(Datetime after)
	{
		ApexClass senderClass = new SEL_ApexClass().findByQualifiedName(UTIL_AdaptiveAsynchronousProcessor.class.getName());
		AsyncApexJob newestJob = new SEL_AsyncApexJob().findNewestLiveByApexClassIdCreatedAfter(senderClass.Id, after);
		return newestJob?.CreatedDate;
	}

	/**
	 * @description Logs one warning that names the stale calls at Queued. Nothing is saved: the send of each call may
	 * never have started, but only an administrator can tell.
	 *
	 * @param calls The stale calls at Queued, as read.
	 * @param staleThresholdMinutes The stale limit in minutes.
	 */
	private static void reportStaleQueuedCalls(List<ApiCall__c> calls, Integer staleThresholdMinutes)
	{
		if(calls.isEmpty())
		{
			return;
		}
		List<String> callNames = new List<String>();
		for(ApiCall__c call : calls)
		{
			callNames.add(call.Name);
		}
		LOG_Builder.build()
				.warn(String.format(MESSAGE_STALE_QUEUED_CALLS, new List<Object> {calls.size(), staleThresholdMinutes, String.join(callNames, NAME_SEPARATOR)}))
				.emitAt(LOG_LOCATION);
	}

	/**
	 * @description One change this run makes to a call, with what to report once the save accepts it: a warning, and
	 * for a lost call whose service logs issues, an API issue.
	 */
	private inherited sharing class CallChange
	{
		/**
		 * @description The call as it was read, before this run changed it.
		 */
		private final ApiCall__c readCall;

		/**
		 * @description The record that is saved: the call's Id and the fields this run changes.
		 */
		private final ApiCall__c changedCall;

		/**
		 * @description The API issue to save once the change is saved, or null when there is none.
		 */
		private final ApiIssue__c issue;

		/**
		 * @description Holds one change to a call.
		 *
		 * @param readCall The call as it was read.
		 * @param changedCall The record that is saved.
		 * @param issue The API issue to save once the change is saved, or null when there is none.
		 */
		private CallChange(ApiCall__c readCall, ApiCall__c changedCall, ApiIssue__c issue)
		{
			this.readCall = readCall;
			this.changedCall = changedCall;
			this.issue = issue;
		}

		/**
		 * @description Logs the warning for this change. A call marked Failed gets its new error text as the warning. A
		 * call given a new retry time gets a warning with the old and the new time.
		 */
		private void logWarning()
		{
			if(changedCall.Status__c == SEL_ApiCall.STATUS_FAILED)
			{
				LOG_Builder.build().warn(changedCall.ErrorMessages__c).forRecord(changedCall.Id).emitAt(LOG_LOCATION);
				return;
			}
			LOG_Builder.build()
					.warn(String.format(System.Label.OutboundRetryWatchdog_RetryTimeMoved,
							new List<Object> {UTIL_Date.toIso8601(readCall.NextRetry__c), UTIL_Date.toIso8601(changedCall.NextRetry__c)}))
					.withContext(CONTEXT_PREVIOUS_NEXT_RETRY, readCall.NextRetry__c)
					.withContext(CONTEXT_NEXT_RETRY, changedCall.NextRetry__c)
					.withContext(CONTEXT_API_CALL_ID, changedCall.Id)
					.forRecord(changedCall.Id)
					.emitAt(LOG_LOCATION);
		}
	}
}
