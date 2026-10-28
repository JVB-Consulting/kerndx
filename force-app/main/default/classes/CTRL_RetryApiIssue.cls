// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Controller Class used by the retry component(s). Supports both outbound
 * retry (re-executes the API call) and inbound replay (runs the request the call kept again), and the dismiss action,
 * which closes an issue without running anything. Before any request is run again, the same checks are made (see
 * RunAgainCheck.findRefusal): Retry Issues is on, the service accepts requests, the call did not fail permanently, and,
 * for an inbound request, the call still holds an exact copy of the request. The bulk retry of issues an operator
 * selects starts at scheduleBulkRetryOfIssues, which the Retry API Issues Flow action (FLOW_RetryApiIssues) calls.
 * A resolver sees every issue through the View All Records access of the Kern API Issue Resolver permission set, but
 * holds no edit access to issues. So the one save that marks issues Resolved (markIssuesResolved) ignores record sharing
 * and object access. It runs only after the entry point has checked the Retry API Issue custom permission, and only for
 * issues whose call or replay has just succeeded, or that the user dismissed.
 * The class length warning is turned off on purpose: every way of running an issue again, and the checks they share,
 * belong to this controller, so the code stays here instead of moving to a new class.
 *
 * @see CTRL_RetryApiIssueBulkRetry_TEST
 * @see CTRL_RetryApiIssue_TEST
 *
 * @author Jason van Beukering
 *
 * @group Controllers
 *
 * @date February 2026, October 2026
 */
@SuppressWarnings('PMD.CognitiveComplexity, PMD.CyclomaticComplexity, PMD.ExcessiveClassLength')
public inherited sharing class CTRL_RetryApiIssue
{
	/**
	 * @description The API name of the Retry API Issue custom permission. Every way of running a failed call again from an
	 * issue checks it for the running user: the Retry action, the resolve action and the bulk retry.
	 */
	public static final String RETRY_API_ISSUE_CUSTOM_PERMISSION_NAME = 'RetryApiIssue';

	/**
	 * @description The API name of the Kern API Issue Resolver permission set, which grants the Retry API Issue custom
	 * permission with read access to API issues and API calls. The package ships it assigned to nobody.
	 */
	public static final String API_ISSUE_RESOLVER_PERMISSION_SET_NAME = 'ApiIssueResolver';

	/**
	 * @description Why a bulk retry was refused, as both warnings in the log say it: the permission by its label and by its
	 * API name.
	 */
	private static final String MISSING_PERMISSION_REASON =
			'the running user does not hold the Retry API Issue custom permission (' + RETRY_API_ISSUE_CUSTOM_PERMISSION_NAME + ')';

	/**
	 * @description Checks whether the running user holds the Retry API Issue custom permission, through a permission set or
	 * a profile. The Retry action, the resolve action and the bulk retry all ask this one check.
	 *
	 * @return True when the running user holds it, false when not.
	 */
	public static Boolean hasRetryPermission()
	{
		return SEL_CustomPermission.hasPackagePermission(UserInfo.getUserId(), RETRY_API_ISSUE_CUSTOM_PERMISSION_NAME);
	}

	/**
	 * @description Builds the answer a user without the Retry API Issue permission gets when asking to run an issue again:
	 * not successful, with the labelled line naming the permission and the set that grants it. A dismiss has its own line.
	 *
	 * @return The refusal.
	 */
	private static DTO_Response refuseWithoutPermission()
	{
		return refuse(System.Label.RetryApiIssue_PermissionRequired);
	}

	/**
	 * @description Builds the answer a user gets when the issue they asked about cannot be read: they cannot see it (API
	 * issues are private, and they do not hold View All Records on them), or it no longer exists. Not successful, with the
	 * labelled line that says so and what to ask an administrator for.
	 *
	 * @return The refusal.
	 */
	private static DTO_Response refuseIssueNotVisible()
	{
		return refuse(System.Label.RetryApiIssue_IssueNotVisible);
	}

	/**
	 * @description Builds a refusal: not successful, with the given message.
	 *
	 * @param message The message the user sees
	 *
	 * @return The refusal.
	 */
	private static DTO_Response refuse(String message)
	{
		DTO_Response dtoResponse = new DTO_Response();
		dtoResponse.callSuccessful = false;
		dtoResponse.errorMessage = message;
		return dtoResponse;
	}

	/**
	 * @description Runs an issue's request again: sends an outbound issue's request again, or replays an inbound issue's
	 * request. The issue's direction decides which (see runIssueAgain).
	 *
	 * @param recordId The id of the record
	 *
	 * @return DTO_Response
	 */
	@AuraEnabled
	public static DTO_Response retry(Id recordId)
	{
		return runIssueAgain(recordId);
	}

	/**
	 * @description Runs an issue's request again, for the Retry action and the resolve action. In this order:
	 *
	 * 1. A user without the Retry API Issue custom permission is refused with the labelled line.
	 * 2. When the user cannot see the issue, or it no longer exists, the labelled line says so and nothing runs.
	 * 3. The checks made before every run (see RunAgainCheck.findRefusal) refuse with their labelled line and run nothing.
	 *    They are the same checks Retry Selected and the bulk retry job make, so a request the dispatcher would refuse is
	 *    not sent only to log a second open issue.
	 * 4. An inbound issue's request is replayed (see replayInboundCall); an outbound issue's request is sent again (see
	 *    retryIssue). On success the issue is marked Resolved with the date, even when another user owns it.
	 *
	 * @param issueId The id of the issue
	 *
	 * @return Whether the run succeeded, and the reason when it did not
	 */
	private static DTO_Response runIssueAgain(Id issueId)
	{
		if(!hasRetryPermission())
		{
			return refuseWithoutPermission();
		}

		ApiIssue__c apiIssue = (ApiIssue__c)new SEL_ApiIssue().findById(issueId);
		if(apiIssue == null)
		{
			return refuseIssueNotVisible();
		}

		RunAgainCheck check = new RunAgainCheck(new List<ApiIssue__c> {apiIssue});
		String refusal = check.findRefusal(apiIssue);
		if(refusal != null)
		{
			return refuse(refusal);
		}

		return apiIssue.Direction__c == SEL_ApiCall.TYPE_INBOUND ? replayInboundCall(apiIssue, check.getStoredRequest(apiIssue)) : retryIssue(apiIssue);
	}

	/**
	 * @description Marks an issue Resolved without running its request again: for a request that cannot be run again
	 * (it failed permanently, or its call is gone), or one the user has dealt with another way. Refuses, with the labelled
	 * line, a user without the Retry API Issue custom permission, and a user who cannot see the issue, or an issue that
	 * no longer exists. The issue is marked Resolved with the date (markIssuesResolved), even when another user owns it.
	 * An issue that is not Open is already closed: nothing is saved, so its resolved date stays as it was, and the
	 * answer is a success. Nothing is sent or replayed.
	 *
	 * @param issueId The id of the issue to dismiss
	 *
	 * @return Whether the issue was marked Resolved, and the reason when it was not
	 */
	@AuraEnabled
	public static DTO_Response dismiss(Id issueId)
	{
		if(!hasRetryPermission())
		{
			return refuse(System.Label.RetryApiIssue_DismissPermissionRequired);
		}

		ApiIssue__c apiIssue = (ApiIssue__c)new SEL_ApiIssue().findById(issueId);
		if(apiIssue == null)
		{
			return refuseIssueNotVisible();
		}

		if(apiIssue.Status__c == SEL_ApiIssue.STATUS_OPEN)
		{
			markIssuesResolved(new List<ApiIssue__c> {apiIssue});
		}
		DTO_Response dtoResponse = new DTO_Response();
		dtoResponse.callSuccessful = true;
		return dtoResponse;
	}

	/**
	 * @description Sends an outbound issue's request again, for a user whose permission the caller has checked, after
	 * the checks made before every run (see RunAgainCheck.findRefusal). The new call links to the issue's call through
	 * PreviousAttempt__c. When the call succeeds, the issue is marked Resolved with the date; when it fails, the answer
	 * carries the call's error.
	 *
	 * @param apiIssue The outbound issue, as the running user can read it
	 *
	 * @return Whether the call succeeded, and the reason when it did not
	 */
	private static DTO_Response retryIssue(ApiIssue__c apiIssue)
	{
		API_Base handler = API_Dispatcher.execute(newRetryCall(apiIssue));
		if(!handler.result.isSuccess)
		{
			return refuse(handler.errorText);
		}

		markIssuesResolved(new List<ApiIssue__c> {apiIssue});
		DTO_Response dtoResponse = new DTO_Response();
		dtoResponse.callSuccessful = true;
		return dtoResponse;
	}

	/**
	 * @description Marks the issues Resolved, with the same date and time on each, and saves them in one update. This is
	 * the only save in the class that marks an issue Resolved. The save ignores record sharing and object access
	 * (bypassSharingInternal() and systemModeInternal()): a resolver sees every issue through View All Records but may not
	 * edit one, and the issue may belong to another user. Every caller has checked the Retry API Issue custom permission
	 * first, and passes only issues whose call or replay has just succeeded, or the issue the user dismissed.
	 *
	 * @param issues The issues to mark Resolved
	 */
	private static void markIssuesResolved(List<ApiIssue__c> issues)
	{
		Datetime resolvedDate = Datetime.now();
		for(ApiIssue__c issue : issues)
		{
			issue.Status__c = SEL_ApiIssue.STATUS_RESOLVED;
			issue.ResolvedDate__c = resolvedDate;
		}
		DML_Builder.newTransaction().systemModeInternal().bypassSharingInternal().doUpdate(issues).execute();
	}

	/**
	 * @description Builds the outbound call record that sends an issue's request again, carrying the issue's request
	 * parameters and idempotency key so the remote system can recognise a repeat. The new call links to the issue's call
	 * through PreviousAttempt__c, so the calls of one request can be followed from one to the next.
	 *
	 * @param apiIssue The outbound issue to send again
	 *
	 * @return The new call record, not yet saved
	 */
	private static ApiCall__c newRetryCall(ApiIssue__c apiIssue)
	{
		ApiCall__c apiCall = TST_Factory.newOutboundApiCall(apiIssue.ServiceName__c);
		apiCall.TriggeringRecordId__c = apiIssue.TriggeringRecordId__c;
		apiCall.RequestParameters__c = apiIssue.RequestParameters__c;
		apiCall.IdempotencyKey__c = apiIssue.IdempotencyKey__c;
		apiCall.PreviousAttempt__c = apiIssue.ApiCall__c;
		return apiCall;
	}

	/**
	 * @description Unified resolve action: handles both Outbound and Inbound failures. It does what retry does (see
	 * runIssueAgain): the issue's direction decides whether its request is sent again or replayed.
	 *
	 * @param failureId The ApiIssue__c record ID to resolve
	 *
	 * @return DTO_Response
	 */
	@AuraEnabled
	public static DTO_Response resolveFailure(Id failureId)
	{
		return runIssueAgain(failureId);
	}

	/**
	 * @description Replays an inbound issue's request using the invoker, after the checks made before every run (see
	 * RunAgainCheck.findRefusal). Safe Mode is disabled so changes persist on success. On success the issue is marked
	 * Resolved with the date (markIssuesResolved), even when another user owns it. A failed replay writes no new issue,
	 * and the issue stays open. Every caller has checked the Retry API Issue custom permission first.
	 *
	 * @param apiIssue The inbound failure record to replay
	 * @param request The issue's request, read from its call or, for an issue made by hand, from its own fields
	 *
	 * @return DTO_Response with the result
	 */
	private static DTO_Response replayInboundCall(ApiIssue__c apiIssue, API_InboundInvoker.InboundRequest request)
	{
		DTO_Response dtoResponse = new DTO_Response();
		dtoResponse.callSuccessful = false;

		DTO_InvocationResult invocationResult = API_InboundInvoker.replay(request, false);

		if(invocationResult.success)
		{
			markIssuesResolved(new List<ApiIssue__c> {apiIssue});
			dtoResponse.callSuccessful = true;
		}
		else
		{
			dtoResponse.errorMessage = String.isNotBlank(invocationResult.errorText)
					? invocationResult.errorText
					: System.Label.RetryApiIssue_InboundReplayFailed;
		}

		return dtoResponse;
	}

	/**
	 * @description Schedules bulk retry of failures with staggered start using asynchronous processing. An issue the checks
	 * made before every run refuse (see RunAgainCheck.findRefusal) is not handed to the job and stays open, and neither is
	 * a request any of whose issues the remote system may already have processed (ExternalSystemMayHaveActed__c). The
	 * check of an inbound issue reads its call without the body (RequestRead.WITHOUT_BODY), because the service may have
	 * many open issues; the job reads each request whole and checks it again just before it runs it.
	 * Refuses, with a warn in the log and no job, a user without the Retry API Issue custom permission; the job checks the
	 * permission again when it runs, as the user who scheduled it.
	 *
	 * @param serviceName The service to retry failures for
	 * @param delayMinutes Minutes to delay before starting (spreads load)
	 *
	 * @return The async job ID, or null if no failures found or the user lacks the permission
	 */
	public static Id scheduleBulkRetry(String serviceName, Integer delayMinutes)
	{
		if(!hasRetryPermission())
		{
			warnBulkRetryRefused('scheduleBulkRetry');
			return null;
		}

		List<ApiIssue__c> failures = new SEL_ApiIssue().findUnresolvedByService(serviceName);

		return launchFailureReplay(selectUnflaggedRequests(new RunAgainCheck(failures, RequestRead.WITHOUT_BODY).selectAccepted(failures)), delayMinutes);
	}

	/**
	 * @description Schedules one background job that sends again the selected issues it can retry, at once. Of the issues
	 * the ids name, only those still open count as selected. Of those, an issue the checks made before every run refuse
	 * (see RunAgainCheck.findRefusal: Retry Issues off, the service paused or switched off, the call failed permanently,
	 * or an inbound issue with no request, or whose call has no hash of a keyed body or a cut address) is not handed to
	 * the job and stays open. So is any issue of a request one of whose selected issues the remote system may already
	 * have processed (ExternalSystemMayHaveActed__c). The check of an inbound issue reads its call without the body
	 * (RequestRead.WITHOUT_BODY), so a large selection does not fill the memory the action may use. So the queued count
	 * leaves out the issues the job would certainly skip, except an inbound issue whose call no longer holds the body or
	 * the parameters as they came in: the job reads each request whole just before it runs it, finds that, and skips the
	 * issue. The job may also skip a few for a call still in progress or a change made in between. Refuses, with a warn
	 * in the log and no job, a user without the Retry API Issue custom permission.
	 *
	 * @param issueIds The ids of the selected issues
	 *
	 * @return The job id (null when no issue was handed over), how many issues were queued and how many were selected
	 */
	public static DTO_ScheduledBulkRetry scheduleBulkRetryOfIssues(Set<Id> issueIds)
	{
		DTO_ScheduledBulkRetry scheduledRetry = new DTO_ScheduledBulkRetry();
		scheduledRetry.queuedCount = 0;
		scheduledRetry.selectedCount = 0;

		if(!hasRetryPermission())
		{
			warnBulkRetryRefused('scheduleBulkRetryOfIssues');
			return scheduledRetry;
		}

		List<ApiIssue__c> openIssues = new List<ApiIssue__c>();
		for(ApiIssue__c issue : (List<ApiIssue__c>)new SEL_ApiIssue().findById(issueIds))
		{
			if(issue.Status__c == SEL_ApiIssue.STATUS_OPEN)
			{
				openIssues.add(issue);
			}
		}
		scheduledRetry.selectedCount = openIssues.size();

		List<List<ApiIssue__c>> requestGroups = selectUnflaggedRequests(new RunAgainCheck(openIssues, RequestRead.WITHOUT_BODY).selectAccepted(openIssues));
		for(List<ApiIssue__c> requestIssues : requestGroups)
		{
			scheduledRetry.queuedCount += requestIssues.size();
		}
		scheduledRetry.jobId = launchFailureReplay(requestGroups, 0);
		return scheduledRetry;
	}

	/**
	 * @description Logs, at warn, that a bulk retry was refused because the running user does not hold the Retry API Issue
	 * custom permission.
	 *
	 * @param entryName The name of the entry that refused, logged as the location
	 */
	private static void warnBulkRetryRefused(String entryName)
	{
		LOG_Builder.build()
				.warn('Bulk retry refused: ' + MISSING_PERMISSION_REASON)
				.emitAt(CTRL_RetryApiIssue.class.getName() + '/' + entryName);
	}

	/**
	 * @description Checks whether the remote system may already have processed a request: any of the issues logged for it
	 * is marked so (ExternalSystemMayHaveActed__c). A bulk retry never sends such a request again, from any of its issues:
	 * a success would resolve the marked issue too and hide the warning. The Retry button remains the operator's
	 * deliberate re-send.
	 *
	 * @param requestIssues The issues logged for one request
	 *
	 * @return True when any of them is marked as possibly processed
	 */
	private static Boolean hasAFlaggedIssue(List<ApiIssue__c> requestIssues)
	{
		for(ApiIssue__c issue : requestIssues)
		{
			if(issue.ExternalSystemMayHaveActed__c == true)
			{
				return true;
			}
		}
		return false;
	}

	/**
	 * @description Groups the issues by the request each was logged for, and keeps the requests none of whose issues the
	 * remote system may already have processed.
	 *
	 * @param issues The issues to group
	 *
	 * @return The requests a bulk retry may send, one group of issues each
	 */
	private static List<List<ApiIssue__c>> selectUnflaggedRequests(List<ApiIssue__c> issues)
	{
		Map<String, List<ApiIssue__c>> issuesByRequestKey = new Map<String, List<ApiIssue__c>>();
		for(ApiIssue__c issue : issues)
		{
			String requestKey = buildRequestKey(issue);
			if(!issuesByRequestKey.containsKey(requestKey))
			{
				issuesByRequestKey.put(requestKey, new List<ApiIssue__c>());
			}
			issuesByRequestKey.get(requestKey).add(issue);
		}
		List<List<ApiIssue__c>> requestGroups = new List<List<ApiIssue__c>>();
		for(List<ApiIssue__c> requestIssues : issuesByRequestKey.values())
		{
			if(!hasAFlaggedIssue(requestIssues))
			{
				requestGroups.add(requestIssues);
			}
		}
		return requestGroups;
	}

	/**
	 * @description Checks whether a service's setting lets the Retry action, Retry Selected or the bulk retry job run its
	 * requests again: the switch that disables every API is off, the switch for the request's direction (every inbound
	 * API or every outbound API) is off, the setting is active, its required feature flag is absent or on, and its bypass
	 * feature flag is absent or off. These mirror API_Base.performValidation, API_Inbound.isDisabled and
	 * API_Outbound.isDisabled, so a request they would abort is never run only to log a new open issue; a condition added
	 * there that decides whether a service may be called is added here in the same change. A service class's own
	 * isDisabled() override and the validation errors it adds are not mirrored: they belong to a handler instance, which
	 * this check does not build, and the run's own validation still refuses the request. Retry Issues is checked before
	 * this, by RunAgainCheck.findRefusal.
	 *
	 * @param setting The service's setting
	 * @param direction The direction of the issue's call: Inbound or Outbound
	 *
	 * @return True when the service accepts requests run again
	 */
	private static Boolean isServiceAcceptingRetries(ApiSetting__mdt setting, String direction)
	{
		String directionSwitch = direction == SEL_ApiCall.TYPE_INBOUND ? API_Inbound.FLAG_DISABLE_ALL_INBOUND_APIS : API_Outbound.FLAG_DISABLE_ALL_OUTBOUND_APIS;
		return !UTIL_FeatureFlag.isEnabled(API_Base.FLAG_DISABLE_ALL_APIS)
				&& !UTIL_FeatureFlag.isEnabled(directionSwitch)
				&& setting.IsActive__c
				&& (setting.RequiredFeatureFlag__c == null || UTIL_FeatureFlag.isEnabled(setting.RequiredFeatureFlag__r?.DeveloperName))
				&& (setting.BypassFeatureFlag__c == null || !UTIL_FeatureFlag.isEnabled(setting.BypassFeatureFlag__r?.DeveloperName));
	}

	/**
	 * @description Finds a service's setting, reading it once per service into the map the caller holds.
	 *
	 * @param serviceName The service whose setting is wanted
	 * @param settingByService The settings already read, by service name; the setting read is added to it
	 *
	 * @return The service's setting, or null when it has none
	 */
	private static ApiSetting__mdt findSettingByService(String serviceName, Map<String, ApiSetting__mdt> settingByService)
	{
		if(!settingByService.containsKey(serviceName))
		{
			settingByService.put(serviceName, new SEL_ApiSetting().findByClassName(serviceName));
		}
		return settingByService.get(serviceName);
	}

	/**
	 * @description Hands the issues to one background job that sends each request again. Every way of scheduling a bulk
	 * retry goes through here, after checking the Retry API Issue custom permission. Each item the job holds is one
	 * request's group of issue ids, so a batch of the job counts requests and every duplicate of a request is sent, or
	 * skipped, together.
	 *
	 * @param requestGroups The issues to send again, one group per request
	 * @param delayMinutes Minutes to wait before the job starts
	 *
	 * @return The job id, or null when there is nothing to send
	 */
	private static Id launchFailureReplay(List<List<ApiIssue__c>> requestGroups, Integer delayMinutes)
	{
		if(requestGroups.isEmpty())
		{
			return null;
		}

		List<Object> items = new List<Object>();
		for(List<ApiIssue__c> requestIssues : requestGroups)
		{
			items.add(new List<Id>(UTIL_SObject.extractIds(requestIssues)));
		}

		Integer calloutSafeJobSize = Math.min(
				SEL_AsynchronousJobSetting.getBatchSize(FLOW_CallApiAsync.class.getName(), FLOW_CallApiAsync.DEFAULT_JOB_SIZE),
				FLOW_CallApiAsync.MAXIMUM_CALLOUT_JOB_SIZE
		);

		UTIL_AsynchronousJobLauncher.DTO_AsynchronousJobRequest request =
				new UTIL_AsynchronousJobLauncher.DTO_AsynchronousJobRequest(items)
						.withDelayMinutes(delayMinutes)
						.withBatchSize(calloutSafeJobSize)
						.withQueueableJobSize(calloutSafeJobSize);

		return UTIL_AsynchronousJobLauncher.process(request, new FailureReplayProcessor());
	}

	/**
	 * @description Builds the key that names one request: the service, the record, the parameters hash and the idempotency
	 * key. An outbound issue with no parameters hash, and every inbound issue, is its own request, keyed by its own id, so a
	 * missing hash never takes unrelated requests for one.
	 *
	 * @param issue The issue whose request is named
	 *
	 * @return The request key
	 */
	private static String buildRequestKey(ApiIssue__c issue)
	{
		if(issue.Direction__c == SEL_ApiCall.TYPE_INBOUND || String.isBlank(issue.RequestParametersHash__c))
		{
			return String.valueOf(issue.Id);
		}
		return issue.ServiceName__c + '|' + issue.TriggeringRecordId__c + '|' + issue.RequestParametersHash__c + '|' + issue.IdempotencyKey__c;
	}

	/**
	 * @description Inner class to define structure of response body
	 */
	public class DTO_Response extends DTO_JsonBase
	{
		/**
		 * @description Boolean flag to identify if call is successful or not
		 */
		@AuraEnabled
		public Boolean callSuccessful;
		/**
		 * @description The text the user reads when the retry is refused or fails: a Custom Label, or the error text of the call
		 * that failed. It is set only when callSuccessful is false.
		 */
		@AuraEnabled
		public String errorMessage;
	}

	/**
	 * @description What scheduling a bulk retry of selected issues answers: the job and how many of the selection it holds.
	 */
	public class DTO_ScheduledBulkRetry extends DTO_JsonBase
	{
		/**
		 * @description The id of the background job, or null when no issue was handed to a job.
		 */
		public Id jobId;
		/**
		 * @description How many selected issues were handed to the job: each was open, not marked as possibly processed by
		 * the remote system and, for an outbound issue, of a service that accepts retries, when the selection was read. The
		 * job checks them again when it runs and may still skip a few.
		 */
		public Integer queuedCount;
		/**
		 * @description How many of the selected ids named an issue that was open when the selection was read.
		 */
		public Integer selectedCount;
	}

	/**
	 * @description Processor for bulk failure retry with staggered execution.
	 * Implements IF_Async.Processable for use with UTIL_AsynchronousJobLauncher.
	 */
	public class FailureReplayProcessor implements IF_Async.Processable
	{
		/**
		 * @description Where this processor's warnings are logged.
		 */
		private final String logLocation = CTRL_RetryApiIssue.class.getName() + '/FailureReplayProcessor';

		/**
		 * @description The warning that follows the count of issues the job skipped because the remote system may already
		 * have processed their request.
		 */
		private final String skippedWarning = ' failure replay(s) skipped: the remote system may already have processed the request; '
				+ 'run them from the API Issue list if you choose to';

		/**
		 * @description The warning that follows the count of issues the job skipped because a call for the same request or
		 * record is still in progress.
		 */
		private final String openCallWarning = ' failure replay(s) skipped: a call for the same request or record is still in progress; '
				+ 'run them again when it has finished';

		/**
		 * @description The warning that follows the count of issues the job did not run because the checks made before
		 * every run refused them.
		 */
		private final String refusedWarning = ' failure replay(s) skipped: Retry Issues is off, the service is paused, the call failed permanently, '
				+ 'or the call no longer holds the request as it was received; open the issue and press Retry to see which';

		/**
		 * @description How many issues of the current run were no longer open when the job ran.
		 */
		private Integer noLongerOpenCount = 0;

		/**
		 * @description How many issues of the current run the checks made before every run refused.
		 */
		private Integer refusedCount = 0;

		/**
		 * @description How many issues of the current run the remote system may already have processed.
		 */
		private Integer skippedCount = 0;

		/**
		 * @description Sends again each request the batch holds, as one group of issues logged for that request. Each issue is
		 * read again when the job runs: one no longer open (resolved since the job was scheduled) is left out and counted at
		 * warn, and one whose request the remote system may already have processed (ExternalSystemMayHaveActed__c) is never
		 * re-sent by an unattended job, stays open and is counted at warn; the Retry button remains the operator's deliberate
		 * re-send. Each open issue is then checked again as the Retry action checks it (see RunAgainCheck.findRefusal),
		 * because the setting, the switches or the call may have changed since the job was scheduled: a request with an
		 * issue the checks refuse is not run, its issues stay open and are counted at warn. Outbound requests are sent
		 * together, so no call is refused for work an earlier one left unsaved, and calls past the callout budget are
		 * deferred. Inbound requests are replayed afterwards, because a replay saves data and a callout cannot follow
		 * unsaved work. The job runs as the user who scheduled it: when that user no longer holds the Retry API Issue custom
		 * permission, nothing is sent or replayed and the count of issues refused is logged at warn.
		 *
		 * @param items The groups of ApiIssue__c ids to process, one group per request
		 */
		public void execute(List<Object> items)
		{
			List<List<Id>> requestGroups = new List<List<Id>>();
			Set<Id> issueIds = new Set<Id>();
			for(Object item : items)
			{
				requestGroups.add((List<Id>)item);
				issueIds.addAll((List<Id>)item);
			}

			if(!hasRetryPermission())
			{
				LOG_Builder.build()
						.warn(issueIds.size() + ' failure replay(s) refused: ' + MISSING_PERMISSION_REASON)
						.emitAt(logLocation);
				return;
			}

			noLongerOpenCount = 0;
			skippedCount = 0;
			refusedCount = 0;
			Map<Id, ApiIssue__c> currentIssueById = new Map<Id, ApiIssue__c>((List<ApiIssue__c>)new SEL_ApiIssue().findById(issueIds));
			List<List<ApiIssue__c>> eligibleGroups = new List<List<ApiIssue__c>>();
			List<ApiIssue__c> eligibleIssues = new List<ApiIssue__c>();
			for(List<Id> requestGroup : requestGroups)
			{
				List<ApiIssue__c> requestIssues = readEligibleIssues(requestGroup, currentIssueById);
				if(!requestIssues.isEmpty())
				{
					eligibleGroups.add(requestIssues);
					eligibleIssues.addAll(requestIssues);
				}
			}

			RunAgainCheck check = new RunAgainCheck(eligibleIssues);
			List<List<ApiIssue__c>> outboundGroups = new List<List<ApiIssue__c>>();
			List<ApiIssue__c> inboundIssues = new List<ApiIssue__c>();
			for(List<ApiIssue__c> requestIssues : eligibleGroups)
			{
				if(check.selectAccepted(requestIssues).size() < requestIssues.size())
				{
					refusedCount += requestIssues.size();
				}
				else if(requestIssues.get(0).Direction__c == SEL_ApiCall.TYPE_INBOUND)
				{
					inboundIssues.addAll(requestIssues);
				}
				else
				{
					outboundGroups.add(requestIssues);
				}
			}
			retryOutboundIssues(outboundGroups);
			replayInboundIssues(inboundIssues, check, !outboundGroups.isEmpty());
			logSkippedIssueCounts();
		}

		/**
		 * @description Logs at warn, one entry per reason, how many issues of the current run were not run: the remote
		 * system may already have processed the request, the checks made before every run refused it, or the issue was no
		 * longer open. A reason with no issue logs nothing.
		 */
		private void logSkippedIssueCounts()
		{
			if(skippedCount > 0)
			{
				LOG_Builder.build().warn(skippedCount + skippedWarning).emitAt(logLocation);
			}
			if(refusedCount > 0)
			{
				LOG_Builder.build().warn(refusedCount + refusedWarning).emitAt(logLocation);
			}
			if(noLongerOpenCount > 0)
			{
				LOG_Builder.build().warn(noLongerOpenCount + ' failure replay(s) skipped: the issue was no longer open when the job ran').emitAt(logLocation);
			}
		}

		/**
		 * @description Reads one request's issues as they are now and keeps those still open. An issue deleted since the job
		 * was scheduled is left out, and one no longer open is counted for the warnings. When any open issue of the request
		 * is marked as possibly processed by the remote system, the request is not sent: none is kept, and all are counted
		 * for the warning.
		 *
		 * @param requestGroup The ids of the issues logged for one request
		 * @param currentIssueById The issues of the batch as they are now, by id
		 *
		 * @return The request's issues the job may send
		 */
		private List<ApiIssue__c> readEligibleIssues(List<Id> requestGroup, Map<Id, ApiIssue__c> currentIssueById)
		{
			List<ApiIssue__c> eligibleIssues = new List<ApiIssue__c>();
			for(Id issueId : requestGroup)
			{
				ApiIssue__c currentIssue = currentIssueById.get(issueId);
				if(currentIssue == null)
				{
					continue;
				}
				if(currentIssue.Status__c != SEL_ApiIssue.STATUS_OPEN)
				{
					noLongerOpenCount++;
				}
				else
				{
					eligibleIssues.add(currentIssue);
				}
			}
			if(hasAFlaggedIssue(eligibleIssues))
			{
				skippedCount += eligibleIssues.size();
				return new List<ApiIssue__c>();
			}
			return eligibleIssues;
		}

		/**
		 * @description Sends each outbound request again in one dispatch, one call per request from the first of its issues,
		 * then marks Resolved with the date (markIssuesResolved), in one update, every issue of each request whose call
		 * succeeded, whoever owns it; the job has checked the Retry API Issue custom permission and the checks made before
		 * every run before it gets here. Each new call links to the call of the request's first issue through
		 * PreviousAttempt__c. A request any of whose issues has its own call, or a call for its record, still in progress or
		 * waiting to be sent is not sent, its issues stay open and are counted at warn, so the job never sends a request
		 * that is already on its way.
		 *
		 * @param requestGroups The outbound issues to send again, one group per request
		 */
		private void retryOutboundIssues(List<List<ApiIssue__c>> requestGroups)
		{
			List<List<ApiIssue__c>> groupsToSend = selectRequestsToSend(requestGroups);
			if(groupsToSend.isEmpty())
			{
				return;
			}
			List<ApiCall__c> retryCalls = new List<ApiCall__c>();
			for(List<ApiIssue__c> requestIssues : groupsToSend)
			{
				retryCalls.add(newRetryCall(requestIssues.get(0)));
			}
			List<API_Base> handlers = API_Dispatcher.execute(retryCalls);
			List<ApiIssue__c> resolvedIssues = new List<ApiIssue__c>();
			for(Integer index = 0; index < retryCalls.size(); index++)
			{
				if(isSuccessfulCall(handlers, retryCalls.get(index)))
				{
					resolvedIssues.addAll(groupsToSend.get(index));
				}
			}
			if(!resolvedIssues.isEmpty())
			{
				markIssuesResolved(resolvedIssues);
			}
		}

		/**
		 * @description Keeps the requests the job may send: none of their issues has a call still in progress. The issues
		 * of requests left out for an open call are counted at warn.
		 *
		 * @param requestGroups The outbound issues the job holds, one group per request
		 *
		 * @return The requests to send, one group of issues each, in the order the job holds them
		 */
		private List<List<ApiIssue__c>> selectRequestsToSend(List<List<ApiIssue__c>> requestGroups)
		{
			List<ApiIssue__c> issues = new List<ApiIssue__c>();
			for(List<ApiIssue__c> requestIssues : requestGroups)
			{
				issues.addAll(requestIssues);
			}
			Set<Id> issueIdsWithAnOpenCall = collectIssueIdsWithAnOpenCall(issues);
			List<List<ApiIssue__c>> groupsToSend = new List<List<ApiIssue__c>>();
			Integer openCallCount = 0;
			for(List<ApiIssue__c> requestIssues : requestGroups)
			{
				Set<Id> requestIssueIds = UTIL_SObject.extractIds(requestIssues);
				requestIssueIds.retainAll(issueIdsWithAnOpenCall);
				if(!requestIssueIds.isEmpty())
				{
					openCallCount += requestIssues.size();
				}
				else
				{
					groupsToSend.add(requestIssues);
				}
			}
			if(openCallCount > 0)
			{
				LOG_Builder.build().warn(openCallCount + openCallWarning).emitAt(logLocation);
			}
			return groupsToSend;
		}

		/**
		 * @description Finds the issues that have a call still in progress or waiting to be sent: their own call, or any
		 * call made for their record, whoever started it. A triggering record id that is not a valid id names no record, so
		 * only the issue's own call is looked at for it. Each read runs only when there is something to look up. Call ids and
		 * record ids are held in one set, as no two records share an id.
		 *
		 * @param issues The outbound issues the job is about to send
		 *
		 * @return The ids of the issues with an open call
		 */
		private Set<Id> collectIssueIdsWithAnOpenCall(List<ApiIssue__c> issues)
		{
			Set<Id> callIds = UTIL_SObject.extractIds(issues, ApiIssue__c.ApiCall__c, true);
			Set<Id> recordIds = new Set<Id>();
			for(ApiIssue__c issue : issues)
			{
				recordIds.add(UTIL_SObject.validateId(issue.TriggeringRecordId__c));
			}
			recordIds.remove(null);
			Set<Id> idsWithAnOpenCall = new Set<Id>();
			if(!callIds.isEmpty())
			{
				idsWithAnOpenCall.addAll(UTIL_SObject.extractIds(new SEL_ApiCall().findOpenById(callIds)));
			}
			if(!recordIds.isEmpty())
			{
				idsWithAnOpenCall.addAll(UTIL_SObject.extractIds(new SEL_ApiCall().findOpenByTriggeringRecordIds(recordIds), ApiCall__c.TriggeringRecordId__c));
			}
			Set<Id> issueIdsWithAnOpenCall = new Set<Id>();
			for(ApiIssue__c issue : issues)
			{
				if(idsWithAnOpenCall.contains(issue.ApiCall__c) || idsWithAnOpenCall.contains(UTIL_SObject.validateId(issue.TriggeringRecordId__c)))
				{
					issueIdsWithAnOpenCall.add(issue.Id);
				}
			}
			return issueIdsWithAnOpenCall;
		}

		/**
		 * @description Checks whether the handler that holds a call record finished it successfully. The dispatcher returns
		 * no handler for a call it deferred past the callout budget or could not match to a service, so a handler is found
		 * by the record it holds, never by its position.
		 *
		 * @param handlers The handlers the dispatch returned
		 * @param retryCall The call record sent
		 *
		 * @return True when a handler holds the call record and its call succeeded
		 */
		private Boolean isSuccessfulCall(List<API_Base> handlers, ApiCall__c retryCall)
		{
			for(API_Base handler : handlers)
			{
				if(handler.apiCall === retryCall)
				{
					return handler.result?.isSuccess == true;
				}
			}
			return false;
		}

		/**
		 * @description Replays the inbound issues one at a time, deferring the rest when the callout budget is spent. Each
		 * request was read and checked when the batch started (see RunAgainCheck).
		 *
		 * @param issues The inbound issues to replay, each accepted by the checks made before every run
		 * @param check The checks made for this batch, which hold each issue's request
		 * @param hasOutboundWork Whether outbound calls were handled earlier in this run
		 */
		private void replayInboundIssues(List<ApiIssue__c> issues, RunAgainCheck check, Boolean hasOutboundWork)
		{
			for(Integer index = 0; index < issues.size(); index++)
			{
				if((hasOutboundWork || index > 0) && API_Dispatcher.isCalloutBudgetExhausted())
				{
					LOG_Builder.build()
							.warn((issues.size() - index) + ' failure replay(s) deferred: callout budget exhausted')
							.emitAt(logLocation);
					break;
				}
				replayInboundCall(issues.get(index), check.getStoredRequest(issues.get(index)));
			}
		}
	}

	/**
	 * @description How much of each inbound issue's request a RunAgainCheck reads.
	 */
	private enum RequestRead
	{
		/**
		 * @description The whole request, body and files included, so every check can be made. The Retry action, the
		 * resolve action and the bulk retry job read this much.
		 */
		WHOLE_REQUEST,
		/**
		 * @description The call without its body and its parameters, so many issues can be checked at once without
		 * filling the memory a request may use. Retry Selected and the bulk retry read this much when they schedule the job.
		 */
		WITHOUT_BODY
	}

	/**
	 * @description The checks made before an issue's request is run again, by the Retry action, the resolve action,
	 * Retry Selected, the bulk retry and, for every issue again, the bulk retry job. It reads, once for all the issues it
	 * is given, each service's setting, each issue's call (for an outbound issue only whether the call failed permanently)
	 * and, for inbound issues, each request as it would be run again (API_InboundInvoker.readStoredRequests). When Retry
	 * Selected and the bulk retry schedule the job, it reads an inbound issue's call without the body instead
	 * (RequestRead.WITHOUT_BODY), and the job makes the checks that need the body.
	 */
	private inherited sharing class RunAgainCheck
	{
		/**
		 * @description Whether each inbound issue's whole request was read. When false, only the call without its body
		 * was read, and the checks that need the body are left to the bulk retry job.
		 */
		private final Boolean isRequestReadWhole;

		/**
		 * @description The settings already read, by service name.
		 */
		private final Map<String, ApiSetting__mdt> settingByService = new Map<String, ApiSetting__mdt>();

		/**
		 * @description The issues' calls, by call id: an inbound issue's call with its request fields, an outbound issue's
		 * call with only its permanent failure field.
		 */
		private final Map<Id, ApiCall__c> callById = new Map<Id, ApiCall__c>();

		/**
		 * @description The request each inbound issue would run again, by issue id. An issue with no request is left out.
		 */
		private final Map<Id, API_InboundInvoker.InboundRequest> storedRequestByIssueId = new Map<Id, API_InboundInvoker.InboundRequest>();

		/**
		 * @description Reads what the checks need for the given issues, with each inbound issue's whole request (see
		 * RequestRead.WHOLE_REQUEST).
		 *
		 * @param issues The issues that may be run again
		 */
		private RunAgainCheck(List<ApiIssue__c> issues)
		{
			this(issues, RequestRead.WHOLE_REQUEST);
		}

		/**
		 * @description Reads what the checks need for the given issues. The calls of inbound issues are read with their
		 * request fields (SEL_ApiCall.findRequestById), and each inbound issue's request is built from its call; or, for
		 * RequestRead.WITHOUT_BODY, they are read without the body and the parameters
		 * (SEL_ApiCall.findRequestWithoutBodyById), and no request is built. The calls of outbound issues are read with only
		 * their permanent failure field (SEL_ApiCall.findPermanentFailureById): the bulk retry job keeps this check while it
		 * sends, and an outbound call's request and response could fill the memory a run may use. A read runs only when
		 * there is something to read.
		 *
		 * @param issues The issues that may be run again
		 * @param amountToRead How much of each inbound issue's request to read
		 */
		private RunAgainCheck(List<ApiIssue__c> issues, RequestRead amountToRead)
		{
			isRequestReadWhole = amountToRead == RequestRead.WHOLE_REQUEST;
			List<ApiIssue__c> inboundIssues = new List<ApiIssue__c>();
			List<ApiIssue__c> outboundIssues = new List<ApiIssue__c>();
			for(ApiIssue__c issue : issues)
			{
				if(issue.Direction__c == SEL_ApiCall.TYPE_INBOUND)
				{
					inboundIssues.add(issue);
				}
				else
				{
					outboundIssues.add(issue);
				}
			}
			readOutboundCalls(outboundIssues);
			if(isRequestReadWhole)
			{
				readInboundRequests(inboundIssues);
			}
			else
			{
				readInboundCallsWithoutBody(inboundIssues);
			}
		}

		/**
		 * @description Reads the calls of outbound issues with only their permanent failure field
		 * (SEL_ApiCall.findPermanentFailureById). Nothing is read when no issue has a call.
		 *
		 * @param outboundIssues The outbound issues that may be run again
		 */
		private void readOutboundCalls(List<ApiIssue__c> outboundIssues)
		{
			Set<Id> outboundCallIds = UTIL_SObject.extractIds(outboundIssues, ApiIssue__c.ApiCall__c, true);
			if(!outboundCallIds.isEmpty())
			{
				callById.putAll(new SEL_ApiCall().findPermanentFailureById(outboundCallIds));
			}
		}

		/**
		 * @description Reads the calls of inbound issues with their request fields (SEL_ApiCall.findRequestById), then builds
		 * each inbound issue's request from its call. Nothing is read when there is nothing to read.
		 *
		 * @param inboundIssues The inbound issues that may be run again
		 */
		private void readInboundRequests(List<ApiIssue__c> inboundIssues)
		{
			Set<Id> inboundCallIds = UTIL_SObject.extractIds(inboundIssues, ApiIssue__c.ApiCall__c, true);
			if(!inboundCallIds.isEmpty())
			{
				callById.putAll(new SEL_ApiCall().findRequestById(inboundCallIds));
			}
			if(!inboundIssues.isEmpty())
			{
				storedRequestByIssueId.putAll(API_InboundInvoker.readStoredRequests(inboundIssues, callById));
			}
		}

		/**
		 * @description Reads the calls of inbound issues without their body and their parameters
		 * (SEL_ApiCall.findRequestWithoutBodyById). Nothing is read when no issue has a call.
		 *
		 * @param inboundIssues The inbound issues that may be run again
		 */
		private void readInboundCallsWithoutBody(List<ApiIssue__c> inboundIssues)
		{
			Set<Id> inboundCallIds = UTIL_SObject.extractIds(inboundIssues, ApiIssue__c.ApiCall__c, true);
			if(!inboundCallIds.isEmpty())
			{
				callById.putAll(new SEL_ApiCall().findRequestWithoutBodyById(inboundCallIds));
			}
		}

		/**
		 * @description Finds why an issue's request must not be run again. The checks, in this order, each with its own
		 * labelled message:
		 *
		 * 1. The service has no API setting, or Retry Issues is off in it.
		 * 2. The service does not accept requests now (see isServiceAcceptingRetries): it is inactive, a feature flag holds
		 *    it back, or every API, or every API of the issue's direction, is switched off.
		 * 3. The issue's call failed permanently (IsPermanentFailure__c): running it again cannot help.
		 * 4. For an inbound issue only: the issue has no request to run (its call is gone and it holds no copy of the
		 *    request), or its call no longer holds an exact copy of the request that came in (see
		 *    API_InboundInvoker.findRequestRefusal). When only the call without its body was read, only what is known
		 *    without the body is checked (see API_InboundInvoker.findRefusalWithoutTheBody).
		 *
		 * An inbound issue gets the messages that speak of a request received; an outbound issue gets those that speak of a
		 * call sent.
		 *
		 * @param issue The issue, one of those the check was built for
		 *
		 * @return The message that says why, or null when the request may be run again
		 */
		private String findRefusal(ApiIssue__c issue)
		{
			Boolean isInbound = issue.Direction__c == SEL_ApiCall.TYPE_INBOUND;
			ApiSetting__mdt setting = findSettingByService(issue.ServiceName__c, settingByService);
			if(setting?.RetryIssues__c != true)
			{
				return isInbound ? System.Label.RetryApiIssue_ReplayNotEnabled : System.Label.RetryApiIssue_RetryNotEnabled;
			}
			if(!isServiceAcceptingRetries(setting, issue.Direction__c))
			{
				return isInbound ? System.Label.RetryApiIssue_ReplayServiceNotAccepting : System.Label.RetryApiIssue_ServiceNotAcceptingRetries;
			}
			if(callById.get(issue.ApiCall__c)?.IsPermanentFailure__c == true)
			{
				return System.Label.RetryApiIssue_PermanentFailure;
			}
			return isInbound ? findInboundRequestRefusal(issue) : null;
		}

		/**
		 * @description Finds why an inbound issue's request must not be run again, from the request when it was read
		 * whole (API_InboundInvoker.findRequestRefusal), or else from the call read without its body
		 * (API_InboundInvoker.findRefusalWithoutTheBody).
		 *
		 * @param issue The inbound issue, one of those the check was built for
		 *
		 * @return The message that says why, or null when nothing found stops the request from running
		 */
		private String findInboundRequestRefusal(ApiIssue__c issue)
		{
			return isRequestReadWhole
					? API_InboundInvoker.findRequestRefusal(getStoredRequest(issue))
					: API_InboundInvoker.findRefusalWithoutTheBody(issue, callById.get(issue.ApiCall__c));
		}

		/**
		 * @description Keeps the issues the checks accept (see findRefusal).
		 *
		 * @param issues The issues to check, each one of those the check was built for
		 *
		 * @return The issues that may be run again, in the order given
		 */
		private List<ApiIssue__c> selectAccepted(List<ApiIssue__c> issues)
		{
			List<ApiIssue__c> acceptedIssues = new List<ApiIssue__c>();
			for(ApiIssue__c issue : issues)
			{
				if(findRefusal(issue) == null)
				{
					acceptedIssues.add(issue);
				}
			}
			return acceptedIssues;
		}

		/**
		 * @description Returns the request an inbound issue would run again.
		 *
		 * @param issue The inbound issue
		 *
		 * @return The request, or null when the issue has none
		 */
		private API_InboundInvoker.InboundRequest getStoredRequest(ApiIssue__c issue)
		{
			return storedRequestByIssueId.get(issue.Id);
		}
	}
}