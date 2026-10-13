// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Controller Class used by the retry component(s). Supports both outbound
 * retry (re-executes the API call) and inbound replay (re-simulates the request). The bulk retry of issues an operator
 * selects starts at scheduleBulkRetryOfIssues, which the Retry API Issues Flow action (FLOW_RetryApiIssues) calls.
 * A resolver sees every issue through the View All Records access of the Kern API Issue Resolver permission set, but
 * holds no edit access to issues. So the one save that marks issues Resolved (markIssuesResolved) ignores record sharing
 * and object access. It runs only after the entry point has checked the Retry API Issue custom permission, and only for
 * issues whose call or replay has just succeeded.
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
@SuppressWarnings('PMD.CognitiveComplexity, PMD.CyclomaticComplexity')
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
	 * @description Builds the answer a user without the Retry API Issue permission gets: not successful, with the labelled
	 * line naming the permission and the set that grants it.
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
	 * @description Will retry the API call. Refuses, with the labelled line, a user without the Retry API Issue custom
	 * permission. When the user cannot see the issue, or it no longer exists, it refuses with the labelled line that says
	 * so and sends nothing. The rest is retryIssue: the service checks, the call, and on success the issue marked Resolved
	 * with the date, even when another user owns it.
	 *
	 * @param recordId The id of the record
	 *
	 * @return DTO_Response
	 */
	@AuraEnabled
	public static DTO_Response retry(Id recordId)
	{
		if(!hasRetryPermission())
		{
			return refuseWithoutPermission();
		}

		ApiIssue__c apiIssue = (ApiIssue__c)new SEL_ApiIssue().findById(recordId);
		if(apiIssue == null)
		{
			return refuseIssueNotVisible();
		}

		return retryIssue(apiIssue);
	}

	/**
	 * @description Sends an outbound issue's request again, for a user whose permission the caller has checked. Two checks
	 * come first, and each refuses with its labelled line and sends nothing. The first: the service has no API setting, or
	 * Retry Issues is off in it. The second: the service does not accept retries for another reason (it is inactive, its
	 * required feature flag is off, its bypass feature flag is on, or every API or every outbound API is disabled). This
	 * is the same check Retry Selected and the bulk retry job make, so a request the dispatcher would refuse is not sent
	 * only to log a second open issue. When the call succeeds, the issue is marked Resolved with the date; when it fails,
	 * the answer carries the call's error.
	 *
	 * @param apiIssue The outbound issue, as the running user can read it
	 *
	 * @return Whether the call succeeded, and the reason when it did not
	 */
	private static DTO_Response retryIssue(ApiIssue__c apiIssue)
	{
		ApiSetting__mdt settings = new SEL_ApiSetting().findByClassName(apiIssue.ServiceName__c);
		if(settings?.RetryIssues__c != true)
		{
			return refuse(System.Label.RetryApiIssue_RetryNotEnabled);
		}
		else if(!isServiceAcceptingRetries(settings))
		{
			return refuse(System.Label.RetryApiIssue_ServiceNotAcceptingRetries);
		}

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
	 * first, and passes only issues whose call or replay has just succeeded.
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
	 * parameters and idempotency key so the remote system can recognise a repeat.
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
		return apiCall;
	}

	/**
	 * @description Unified resolve action: handles both Outbound and Inbound failures.
	 * Routes to outbound retry (retryIssue) or inbound replay based on the failure's direction. Refuses, with the labelled
	 * line, a user without the Retry API Issue custom permission, and a user who cannot see the issue, or an issue that no
	 * longer exists. The permission is checked and the issue is read once, here.
	 *
	 * @param failureId The ApiIssue__c record ID to resolve
	 *
	 * @return DTO_Response
	 */
	@AuraEnabled
	public static DTO_Response resolveFailure(Id failureId)
	{
		if(!hasRetryPermission())
		{
			return refuseWithoutPermission();
		}

		ApiIssue__c apiIssue = (ApiIssue__c)new SEL_ApiIssue().findById(failureId);
		if(apiIssue == null)
		{
			return refuseIssueNotVisible();
		}

		if(apiIssue.Direction__c == SEL_ApiCall.TYPE_INBOUND)
		{
			return replayInboundCall(apiIssue);
		}

		return retryIssue(apiIssue);
	}

	/**
	 * @description Replays an inbound API call using the invoker. Safe Mode is disabled
	 * so changes persist on success. On success the issue is marked Resolved with the date (markIssuesResolved), even when
	 * another user owns it. Every caller has checked the Retry API Issue custom permission first.
	 *
	 * @param apiIssue The inbound failure record to replay
	 *
	 * @return DTO_Response with the result
	 */
	private static DTO_Response replayInboundCall(ApiIssue__c apiIssue)
	{
		DTO_Response dtoResponse = new DTO_Response();
		dtoResponse.callSuccessful = false;

		DTO_InvocationResult invocationResult = API_InboundInvoker.replay(apiIssue.Id, false);

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
	 * @description Schedules bulk retry of failures with staggered start using asynchronous processing. A request any of
	 * whose issues the remote system may already have processed (ExternalSystemMayHaveActed__c) is not handed to the job,
	 * and all its issues stay open for an operator.
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

		return launchFailureReplay(selectUnflaggedRequests(failures), delayMinutes);
	}

	/**
	 * @description Schedules one background job that sends again the selected issues it can retry, at once. Of the issues
	 * the ids name, only those still open count as selected; of those, an outbound issue of a service that does not accept
	 * retries (Retry Issues off, inactive, its required feature flag off, its bypass feature flag on, or every API or every
	 * outbound API disabled) is not handed to the job and stays open, and neither is any issue of a request one of whose
	 * selected issues the remote system may already have processed (ExternalSystemMayHaveActed__c). The checks are the ones
	 * the job makes again when it runs, so the queued count leaves out the issues the job would certainly skip; the job may
	 * still skip a few, for a call still in progress or a change made in between. Refuses, with a warn in the log and no
	 * job, a user without the Retry API Issue custom permission.
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

		Map<String, ApiSetting__mdt> settingByService = new Map<String, ApiSetting__mdt>();
		List<ApiIssue__c> issuesOfAcceptingServices = new List<ApiIssue__c>();
		for(ApiIssue__c issue : (List<ApiIssue__c>)new SEL_ApiIssue().findById(issueIds))
		{
			if(issue.Status__c != SEL_ApiIssue.STATUS_OPEN)
			{
				continue;
			}
			scheduledRetry.selectedCount++;
			if(issue.Direction__c == SEL_ApiCall.TYPE_INBOUND || isServiceAcceptingRetries(findSettingByService(issue.ServiceName__c, settingByService)))
			{
				issuesOfAcceptingServices.add(issue);
			}
		}

		List<List<ApiIssue__c>> requestGroups = selectUnflaggedRequests(issuesOfAcceptingServices);
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
	 * @description Checks whether a service's setting lets the Retry action, Retry Selected or the bulk retry job send its
	 * requests again: the switches that disable every API and every outbound API are off, Retry Issues is on, the setting
	 * is active, its required feature flag is absent or on, and its bypass feature flag is absent or off. All but Retry
	 * Issues mirror API_Base.performValidation
	 * and API_Outbound.isDisabled, so a request they would abort is never sent only to log a new open issue; a condition
	 * added there that decides whether a service may be called is added here in the same change. A service class's own
	 * isDisabled() override and the validation errors it adds are not mirrored: they belong to a handler instance, which
	 * this check does not build, and the re-send's validation still refuses the request.
	 *
	 * @param setting The service's setting, or null when it has none
	 *
	 * @return True when the service accepts retries
	 */
	private static Boolean isServiceAcceptingRetries(ApiSetting__mdt setting)
	{
		return !UTIL_FeatureFlag.isEnabled(API_Base.FLAG_DISABLE_ALL_APIS)
				&& !UTIL_FeatureFlag.isEnabled(API_Outbound.FLAG_DISABLE_ALL_OUTBOUND_APIS)
				&& setting?.RetryIssues__c == true
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
		 * @description error message
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
		 * @description How many issues of the current run were no longer open when the job ran.
		 */
		private Integer noLongerOpenCount = 0;

		/**
		 * @description How many issues of the current run the remote system may already have processed.
		 */
		private Integer skippedCount = 0;

		/**
		 * @description Sends again each request the batch holds, as one group of issues logged for that request. Each issue is
		 * read again when the job runs: one no longer open (resolved since the job was scheduled) is left out and counted at
		 * warn, and one whose request the remote system may already have processed (ExternalSystemMayHaveActed__c) is never
		 * re-sent by an unattended job, stays open and is counted at warn; the Retry button remains the operator's deliberate
		 * re-send. Outbound requests are sent together, so no call is refused for work an earlier one left unsaved, and calls
		 * past the callout budget are deferred. Inbound requests are replayed afterwards, because a replay saves data and a
		 * callout cannot follow unsaved work. The job runs as the user who scheduled it: when that user no longer holds the
		 * Retry API Issue custom permission, nothing is sent or replayed and the count of issues refused is logged at warn.
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
			Map<Id, ApiIssue__c> currentIssueById = new Map<Id, ApiIssue__c>((List<ApiIssue__c>)new SEL_ApiIssue().findById(issueIds));
			List<List<ApiIssue__c>> outboundGroups = new List<List<ApiIssue__c>>();
			List<ApiIssue__c> inboundIssues = new List<ApiIssue__c>();
			for(List<Id> requestGroup : requestGroups)
			{
				List<ApiIssue__c> eligibleIssues = readEligibleIssues(requestGroup, currentIssueById);
				if(eligibleIssues.isEmpty())
				{
					continue;
				}
				if(eligibleIssues.get(0).Direction__c == SEL_ApiCall.TYPE_INBOUND)
				{
					inboundIssues.addAll(eligibleIssues);
				}
				else
				{
					outboundGroups.add(eligibleIssues);
				}
			}
			retryOutboundIssues(outboundGroups);
			replayInboundIssues(inboundIssues, !outboundGroups.isEmpty());
			if(skippedCount > 0)
			{
				LOG_Builder.build().warn(skippedCount + skippedWarning).emitAt(logLocation);
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
		 * succeeded, whoever owns it; the job has checked the Retry API Issue custom permission before it gets here. Two checks come
		 * first. A request any of whose issues has its own call, or a call for its record, still in progress or waiting to be
		 * sent is not sent, its issues stay open and are counted at warn, so the job never sends a request that is already
		 * on its way. A request of a service that does not accept retries (Retry Issues off, inactive, its required feature flag
		 * off, its bypass feature flag on, or every API or every outbound API disabled) is not sent and its issues stay open.
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
		 * @description Keeps the requests the job may send: none of their issues has a call still in progress, and their
		 * service accepts retries. The issues of requests left out for an open call are counted at warn.
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
			Map<String, ApiSetting__mdt> settingByService = new Map<String, ApiSetting__mdt>();
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
				else if(isServiceAcceptingRetries(findSettingByService(requestIssues.get(0).ServiceName__c, settingByService)))
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
		 * @description Replays the inbound issues one at a time, deferring the rest when the callout budget is spent.
		 *
		 * @param issues The inbound issues to replay
		 * @param hasOutboundWork Whether outbound calls were handled earlier in this run
		 */
		private void replayInboundIssues(List<ApiIssue__c> issues, Boolean hasOutboundWork)
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
				replayInboundCall(issues.get(index));
			}
		}
	}
}