// SPDX-License-Identifier: Apache-2.0
/**
 * @description Runs the failed calls of the API issues you select again, in one background job: from the Retry Selected
 * action on the API Issues list, from your own flow, or from Apex. The issues that are still open are handed to the job.
 * The job sends each distinct request once and marks resolved every issue whose call succeeds. It skips an issue whose
 * external system may already have acted, an issue whose call or record still has a call in progress, and an issue whose
 * service is paused or does not allow retries (Retry Issues is off in its API setting). It also skips an issue whose call
 * failed in a way a new run cannot fix, and an issue of a call your org received when the call no longer holds the
 * request exactly as it was received. A request your org received is run again from the call that received it. You need
 * the Retry API Issue permission; without it nothing is queued and the message says so.
 *
 * @see FLOW_RetryApiIssues_TEST
 *
 * @author Jason van Beukering
 *
 * @group Web Services
 *
 * @date October 2026
 *
 * @since 1.8
 *
 * @example
 * ```apex
 * FLOW_RetryApiIssues.DTO_Request request = new FLOW_RetryApiIssues.DTO_Request();
 * request.apiIssueIds = new List<String> {issueId};
 * FLOW_RetryApiIssues.DTO_Response response = FLOW_RetryApiIssues.retryApiIssues(new List<FLOW_RetryApiIssues.DTO_Request> {request}).get(0);
 * ```
 */
@SuppressWarnings('PMD.AvoidGlobalModifier')
global inherited sharing class FLOW_RetryApiIssues
{
	/**
	 * @description The end of the message thrown when the action is given anything but exactly one request.
	 */
	private static final String MESSAGE_SINGLE_REQUEST = ' expects a single request';

	/**
	 * @description Queues a retry of the open issues among the ids you pass and tells you how many were queued. Ids that are
	 * not record ids and ids of other objects are left out. An issue is not queued, and stays open, when it is not open, when
	 * the external system may already have acted on it, when its service is paused or does not allow retries, when its call
	 * failed in a way a new run cannot fix, or, for a call your org received, when the call no longer holds the request
	 * exactly as it was received; the message says how many of the open issues you named were queued and why the rest were not. The
	 * job may still skip a few, for example when a call for the same record is still running, and each issue shows its own
	 * result. The answer carries no count of the issues it left out.
	 *
	 * @param requests Exactly one request, holding the ids of the API issues to run again.
	 *
	 * @return One response: whether the request was accepted, the job id (null when nothing was queued), how many issues were queued, and a message.
	 *
	 * @throws IllegalArgumentException When the list does not hold exactly one request.
	 *
	 * @since 1.8
	 *
	 * @example
	 * ```apex
	 * FLOW_RetryApiIssues.DTO_Request request = new FLOW_RetryApiIssues.DTO_Request();
	 * request.apiIssueIds = new List<String> {firstIssueId, secondIssueId};
	 * FLOW_RetryApiIssues.DTO_Response response = FLOW_RetryApiIssues.retryApiIssues(new List<FLOW_RetryApiIssues.DTO_Request> {request}).get(0);
	 * Assert.areEqual(2, response.queuedCount);
	 * ```
	 */
	@InvocableMethod
	(
			category='Api Callouts'
			label='Retry API Issues'
			description='Runs the failed calls of the API issues you select again, in one background job. Needs the Retry API Issue permission.'
	)
	global static List<DTO_Response> retryApiIssues(List<DTO_Request> requests)
	{
		if(requests == null || requests.size() != 1)
		{
			throw new IllegalArgumentException(FLOW_RetryApiIssues.class.getName() + MESSAGE_SINGLE_REQUEST);
		}
		DTO_Response response = new DTO_Response();
		response.queuedCount = 0;
		response.success = false;
		if(!CTRL_RetryApiIssue.hasRetryPermission())
		{
			response.message = System.Label.RetryApiIssue_PermissionRequired;
			return new List<DTO_Response> {response};
		}
		Set<Id> selectedIssueIds = UTIL_Set.extractIds(new Set<Object>((List<Object>)(requests.get(0).apiIssueIds ?? new List<String>())));
		CTRL_RetryApiIssue.DTO_ScheduledBulkRetry scheduled = CTRL_RetryApiIssue.scheduleBulkRetryOfIssues(selectedIssueIds);
		response.jobId = scheduled.jobId;
		response.queuedCount = scheduled.queuedCount;
		response.success = scheduled.queuedCount > 0;
		response.message = scheduled.selectedCount == 0
				? System.Label.RetryApiIssues_NothingToRetry
				: String.format(System.Label.RetryApiIssues_Queued, new List<Object> {scheduled.queuedCount, scheduled.selectedCount});
		return new List<DTO_Response> {response};
	}

	/**
	 * @description What the action is asked: the API issues to run again.
	 *
	 * @since 1.8
	 */
	global inherited sharing class DTO_Request
	{
		/**
		 * @description The ids of the API issues to run again.
		 *
		 * @since 1.8
		 */
		@InvocableVariable(label='API Issue Ids' description='The ids of the API issues to run again.' required=true)
		global List<String> apiIssueIds;
	}

	/**
	 * @description What the action answers: the job, the count and a message for the person who asked.
	 *
	 * @since 1.8
	 */
	global inherited sharing class DTO_Response
	{
		/**
		 * @description The id of the background job, empty when nothing was queued.
		 *
		 * @since 1.8
		 */
		@InvocableVariable(label='Job Id' description='The id of the background job, empty when nothing was queued.')
		global String jobId;

		/**
		 * @description How many of the issues were open and were handed to the job.
		 *
		 * @since 1.8
		 */
		@InvocableVariable(label='Queued Count' description='How many of the issues were open and were handed to the job.')
		global Integer queuedCount;

		/**
		 * @description Whether the request was accepted: true when you hold the Retry API Issue permission and at least one
		 * issue was handed to the retry job, false otherwise.
		 *
		 * @since 1.8
		 */
		@InvocableVariable
		(
				label='Success'
				description='True when the request was accepted: you hold the Retry API Issue permission and at least one issue was handed to the retry job'
		)
		global Boolean success;

		/**
		 * @description What happened, in words you can show the person who asked.
		 *
		 * @since 1.8
		 */
		@InvocableVariable(label='Message' description='What happened, in words you can show the person who asked.')
		global String message;
	}
}
