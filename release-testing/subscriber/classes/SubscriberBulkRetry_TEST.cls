// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Subscriber-side proof of Retry Selected through the global surface: the Retry API Issues flow action, called
 * by a Standard User who holds only the Kern API Issue Resolver permission set, queues the open issues it is given and
 * the job resolves them once their calls succeed, with the date they were resolved; and a handler that refuses the
 * answer from parseResponse() with RequestRefusedException leaves an issue that does not say the external system may
 * have acted, so Retry Selected can send it again.
 *
 * Three more checks: a user without the Retry API Issue permission is refused with the labelled message and nothing is
 * queued; an issue of a service that does not accept retries is not queued and stays open; and an inbound issue is
 * replayed by the job, which saves the handler's record and resolves the issue.
 *
 * The refusal test assumes the package was installed for administrators only: if the Standard User profile holds the
 * Retry API Issue permission, no user exists that the action refuses.
 *
 * @see kern.FLOW_RetryApiIssues
 * @see kern.UTIL_Exceptions
 * @see kern.API_Outbound
 * @see kern.API_Dispatcher
 *
 * @author your.name@company.com
 *
 * @group Web Services
 *
 * @date October 2026
 */
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest(seeAllData=false isParallel=false)
private class SubscriberBulkRetry_TEST
{
	/**
	 * @description How many issues the flow action is given.
	 */
	private static final Integer SELECTED_ISSUE_COUNT = 2;

	/**
	 * @description HTTP status code for a successful answer (200); the framework's own constant is not visible across the
	 * namespace, so the test spells it.
	 */
	private static final Integer HTTP_OK = 200;

	/**
	 * @description The body every mock answers with.
	 */
	private static final String EMPTY_BODY = '{}';

	/**
	 * @description The message the refusing handler fails with.
	 */
	private static final String MESSAGE_REQUEST_REFUSED = 'the external system refused the request on purpose';

	/**
	 * @description The status of an issue that still needs attention.
	 */
	private static final String STATUS_OPEN = 'Open';

	/**
	 * @description The status of an issue whose call has since succeeded.
	 */
	private static final String STATUS_RESOLVED = 'Resolved';

	/**
	 * @description The direction of an outbound issue.
	 */
	private static final String DIRECTION_OUTBOUND = 'Outbound';

	/**
	 * @description The direction of an inbound issue.
	 */
	private static final String DIRECTION_INBOUND = 'Inbound';

	/**
	 * @description The path the inbound issue's request was sent to, which the replay routes by.
	 */
	private static final String INBOUND_PATH = '/bulk-retry-inbound';

	/**
	 * @description The method of the inbound issue's request.
	 */
	private static final String HTTP_METHOD_POST = 'POST';

	/**
	 * @description The profile the resolver is created with.
	 */
	private static final String PROFILE_STANDARD_USER = 'Standard User';

	/**
	 * @description The permission set the resolver holds, and the only one from the package.
	 */
	private static final String API_ISSUE_RESOLVER_PERMISSION_SET = 'ApiIssueResolver';

	/**
	 * @description Company name of the resolver, by which the tests find the user setup created.
	 */
	private static final String API_ISSUE_RESOLVER_USER_COMPANY = 'SubscriberBulkRetry_TEST-resolver';

	/**
	 * @description Company name of the user with no permission set, by which the tests find the user setup created.
	 */
	private static final String NO_PERMISSION_USER_COMPANY = 'SubscriberBulkRetry_TEST-nobody';

	/**
	 * @description The resolver, and a Standard User with no permission set, created in setup so System.runAs starts a
	 * fresh permission evaluation for each test.
	 */
	@TestSetup
	private static void setupUsers()
	{
		kern.TST_Factory.newUserWithPermissionSet(PROFILE_STANDARD_USER, API_ISSUE_RESOLVER_USER_COMPANY, API_ISSUE_RESOLVER_PERMISSION_SET);
		kern.TST_Factory.insertUser(PROFILE_STANDARD_USER, NO_PERMISSION_USER_COMPANY);
	}

	/**
	 * @description The resolver runs the flow action on two open issues of a service whose calls succeed: the answer
	 * reports success and carries a job, a count of two and the queued message, and once the job has run both issues
	 * read Resolved and carry the date they were resolved.
	 */
	@IsTest
	private static void shouldQueueAndResolveTheSelectedIssuesThroughTheFlowAction()
	{
		String serviceName = BulkRetryGet.class.getName();
		kern.TST_Factory.newOutboundApiSetting(serviceName, new Map<SObjectField, Object>
		{
				kern__ApiSetting__mdt.kern__RetryIssues__c => true,
				kern__ApiSetting__mdt.kern__ResolveIssues__c => false
		});
		kern.API_MockFactory.forService(serviceName).body(EMPTY_BODY).statusCode(HTTP_OK).register();
		List<kern__ApiIssue__c> issues = (List<kern__ApiIssue__c>)kern.TST_Builder.of(kern__ApiIssue__c.SObjectType)
				.withCount(SELECTED_ISSUE_COUNT)
				.withOverrides(new Map<SObjectField, Object>
				{
						kern__ApiIssue__c.kern__ServiceName__c => serviceName,
						kern__ApiIssue__c.kern__Status__c => STATUS_OPEN,
						kern__ApiIssue__c.kern__Direction__c => DIRECTION_OUTBOUND
				})
				.withCycle(kern__ApiIssue__c.kern__RequestParametersHash__c, new List<Object> {kern.UTIL_Random.randomName(), kern.UTIL_Random.randomName()})
				.buildList();
		kern.FLOW_RetryApiIssues.DTO_Request request = new kern.FLOW_RetryApiIssues.DTO_Request();
		request.apiIssueIds = new List<String> {issues[0].Id, issues[1].Id};

		kern.FLOW_RetryApiIssues.DTO_Response response;
		System.runAs(new kern.SEL_User().findByCompanyName(API_ISSUE_RESOLVER_USER_COMPANY))
		{
			Test.startTest();
			response = kern.FLOW_RetryApiIssues.retryApiIssues(new List<kern.FLOW_RetryApiIssues.DTO_Request> {request})[0];
			Test.stopTest();
		}

		String expectedMessage = String.format(System.Label.kern.RetryApiIssues_Queued, new List<Object> {SELECTED_ISSUE_COUNT, SELECTED_ISSUE_COUNT});
		Assert.isTrue(response.success, 'Expected the action to report success when it queued the issues');
		Assert.isNotNull(response.jobId, 'Expected the action to answer with the job it queued');
		Assert.areEqual(SELECTED_ISSUE_COUNT, response.queuedCount, 'Expected both open issues to be queued');
		Assert.areEqual(expectedMessage, response.message, 'Expected the queued message with both counts');
		List<kern__ApiIssue__c> found = (List<kern__ApiIssue__c>)new kern.SEL_ApiIssue().findByField(kern__ApiIssue__c.kern__ServiceName__c, serviceName);
		Assert.areEqual(SELECTED_ISSUE_COUNT, found.size(), 'Expected only the two selected issues for ' + serviceName + ', got ' + found.size());
		for(kern__ApiIssue__c issue : found)
		{
			Assert.areEqual(STATUS_RESOLVED, issue.kern__Status__c, 'Expected issue ' + issue.Id + ' to be resolved once its call succeeded');
			Assert.isNotNull(issue.kern__ResolvedDate__c, 'Expected issue ' + issue.Id + ' to carry the date it was resolved');
		}
	}

	/**
	 * @description A Standard User with no permission set runs the flow action on an open issue: the answer is not a
	 * success, carries no job, a count of none and the labelled message that names the missing permission, and the
	 * issue stays open.
	 */
	@IsTest
	private static void shouldRefuseTheFlowActionToAUserWithoutThePermission()
	{
		String serviceName = BulkRetryGet.class.getName();
		kern.TST_Factory.newOutboundApiSetting(serviceName, new Map<SObjectField, Object> {kern__ApiSetting__mdt.kern__RetryIssues__c => true});
		kern__ApiIssue__c issue = insertOpenIssue(serviceName, DIRECTION_OUTBOUND);

		kern.FLOW_RetryApiIssues.DTO_Response response;
		System.runAs(new kern.SEL_User().findByCompanyName(NO_PERMISSION_USER_COMPANY))
		{
			Test.startTest();
			response = retryThroughTheFlowAction(issue.Id);
			Test.stopTest();
		}

		Assert.isFalse(response.success, 'Expected the action to refuse a user without the Retry API Issue permission');
		Assert.isNull(response.jobId, 'Expected no job for a refused request, got ' + response.jobId);
		Assert.areEqual(0, response.queuedCount, 'Expected no issue queued for a refused request');
		Assert.areEqual(System.Label.kern.RetryApiIssue_PermissionRequired, response.message, 'Expected the message naming the missing permission');
		Assert.areEqual(STATUS_OPEN, findIssue(issue.Id).kern__Status__c, 'Expected the issue to stay open after a refused request');
	}

	/**
	 * @description The resolver runs the flow action on an open issue of a service whose setting has Retry Issues off: the
	 * issue is counted as selected but not queued, no job starts, and the issue stays open.
	 */
	@IsTest
	private static void shouldLeaveAnIssueOpenWhenItsServiceDoesNotAcceptRetries()
	{
		String serviceName = BulkRetryGet.class.getName();
		kern.TST_Factory.newOutboundApiSetting(serviceName, new Map<SObjectField, Object> {kern__ApiSetting__mdt.kern__RetryIssues__c => false});
		kern__ApiIssue__c issue = insertOpenIssue(serviceName, DIRECTION_OUTBOUND);

		kern.FLOW_RetryApiIssues.DTO_Response response;
		System.runAs(new kern.SEL_User().findByCompanyName(API_ISSUE_RESOLVER_USER_COMPANY))
		{
			Test.startTest();
			response = retryThroughTheFlowAction(issue.Id);
			Test.stopTest();
		}

		String expectedMessage = String.format(System.Label.kern.RetryApiIssues_Queued, new List<Object> {0, 1});
		Assert.isFalse(response.success, 'Expected no success when no issue could be queued');
		Assert.isNull(response.jobId, 'Expected no job when no issue was queued, got ' + response.jobId);
		Assert.areEqual(0, response.queuedCount, 'Expected the issue of a service that does not accept retries to be left out');
		Assert.areEqual(expectedMessage, response.message, 'Expected the queued message to say none of one selected issue was queued');
		Assert.areEqual(STATUS_OPEN, findIssue(issue.Id).kern__Status__c, 'Expected the issue to stay open');
	}

	/**
	 * @description The resolver runs the flow action on one open inbound issue: the job replays the stored request through
	 * the inbound handler, the handler's record is saved, and the issue reads Resolved with the date it was resolved.
	 */
	@IsTest
	private static void shouldReplayAnInboundIssueAndResolveItThroughTheFlowAction()
	{
		String serviceName = BulkRetryInbound.class.getName();
		kern.TST_Factory.newInboundApiSetting(serviceName, INBOUND_PATH);
		BulkRetryInboundRequest storedRequest = new BulkRetryInboundRequest();
		storedRequest.recordName = kern.UTIL_Random.randomName();
		kern__ApiIssue__c issue = (kern__ApiIssue__c)kern.TST_Builder.of(kern__ApiIssue__c.SObjectType)
				.withOverrides(new Map<SObjectField, Object>
				{
						kern__ApiIssue__c.kern__ServiceName__c => serviceName,
						kern__ApiIssue__c.kern__Status__c => STATUS_OPEN,
						kern__ApiIssue__c.kern__Direction__c => DIRECTION_INBOUND,
						kern__ApiIssue__c.kern__RequestPath__c => INBOUND_PATH,
						kern__ApiIssue__c.kern__RequestMethod__c => HTTP_METHOD_POST,
						kern__ApiIssue__c.kern__RequestBody__c => JSON.serialize(storedRequest)
				})
				.build();

		kern.FLOW_RetryApiIssues.DTO_Response response;
		System.runAs(new kern.SEL_User().findByCompanyName(API_ISSUE_RESOLVER_USER_COMPANY))
		{
			Test.startTest();
			response = retryThroughTheFlowAction(issue.Id);
			Test.stopTest();
		}

		Assert.areEqual(1, response.queuedCount, 'Expected the inbound issue to be queued');
		kern__ApiIssue__c replayedIssue = findIssue(issue.Id);
		Assert.areEqual(STATUS_RESOLVED, replayedIssue.kern__Status__c, 'Expected the inbound issue to be resolved once its replay succeeded');
		Assert.isNotNull(replayedIssue.kern__ResolvedDate__c, 'Expected the inbound issue to carry the date it was resolved');
		Integer savedCount = kern.QRY_Builder.selectFrom(kern__Foobar__c.SObjectType).condition(kern__Foobar__c.Name).equals(storedRequest.recordName).count();
		Assert.areEqual(1, savedCount, 'Expected the replayed handler to save its record once, got ' + savedCount);
	}

	/**
	 * @description A handler that refuses the answer from parseResponse() with RequestRefusedException, after a successful
	 * status, fails the call at once and leaves one issue that does not say the external system may have acted.
	 */
	@IsTest
	private static void shouldLeaveTheIssueUnflaggedWhenParseResponseRefusesTheRequest()
	{
		String serviceName = BulkRetryRefusing.class.getName();
		kern.TST_Factory.newOutboundApiSetting(serviceName, new Map<SObjectField, Object> {kern__ApiSetting__mdt.kern__LogIssues__c => true});
		kern.API_MockFactory.forService(serviceName).body(EMPTY_BODY).statusCode(HTTP_OK).register();

		Test.startTest();
		kern.API_Dispatcher.execute(new List<kern__ApiCall__c> {kern.TST_Factory.newOutboundApiCall(serviceName, UserInfo.getUserId())});
		Test.stopTest();

		kern.SEL_ApiCall.assertServiceFailed(serviceName, MESSAGE_REQUEST_REFUSED);
		List<kern__ApiIssue__c> issues = (List<kern__ApiIssue__c>)new kern.SEL_ApiIssue().findByField(kern__ApiIssue__c.kern__ServiceName__c, serviceName);
		Assert.areEqual(1, issues.size(), 'Expected one issue for ' + serviceName + ', got ' + issues.size());
		Assert.isFalse(issues[0].kern__ExternalSystemMayHaveActed__c, 'Expected a request the external system refused to leave the issue unflagged');
	}

	/**
	 * @description Inserts one open issue of the given service and direction.
	 *
	 * @param serviceName The service the issue belongs to.
	 * @param direction Outbound or Inbound.
	 *
	 * @return The saved issue.
	 */
	private static kern__ApiIssue__c insertOpenIssue(String serviceName, String direction)
	{
		return (kern__ApiIssue__c)kern.TST_Builder.of(kern__ApiIssue__c.SObjectType)
				.withOverrides(new Map<SObjectField, Object>
				{
						kern__ApiIssue__c.kern__ServiceName__c => serviceName,
						kern__ApiIssue__c.kern__Status__c => STATUS_OPEN,
						kern__ApiIssue__c.kern__Direction__c => direction
				})
				.build();
	}

	/**
	 * @description Runs the Retry API Issues flow action on one issue, as the running user.
	 *
	 * @param issueId The issue to retry.
	 *
	 * @return The action's answer.
	 */
	private static kern.FLOW_RetryApiIssues.DTO_Response retryThroughTheFlowAction(Id issueId)
	{
		kern.FLOW_RetryApiIssues.DTO_Request request = new kern.FLOW_RetryApiIssues.DTO_Request();
		request.apiIssueIds = new List<String> {issueId};
		return kern.FLOW_RetryApiIssues.retryApiIssues(new List<kern.FLOW_RetryApiIssues.DTO_Request> {request})[0];
	}

	/**
	 * @description Reads one issue as it is now.
	 *
	 * @param issueId The issue to read.
	 *
	 * @return The issue.
	 */
	private static kern__ApiIssue__c findIssue(Id issueId)
	{
		return (kern__ApiIssue__c)new kern.SEL_ApiIssue().findById(issueId);
	}

	/**
	 * @description The payload both directions use; any JSON-capable DTO satisfies the handler.
	 */
	@JsonAccess(serializable='always' deserializable='always')
	public class BulkRetryPayload extends kern.DTO_JsonBase
	{
	}

	/**
	 * @description A GET handler with in-memory payloads and no triggering record, the base of this class's handlers.
	 */
	public virtual class BulkRetryGet extends kern.API_Outbound
	{
		/**
		 * @description Sets the payloads and clears the triggering-record requirement.
		 */
		public override void configure()
		{
			super.configure();
			requestPayload = new BulkRetryPayload();
			responsePayload = new BulkRetryPayload();
			requiresTriggeringRecord = false;
		}

		/**
		 * @description A GET, so a repeat is safe.
		 *
		 * @return GET.
		 */
		public override virtual kern.API_Base.HttpMethod getHttpMethod()
		{
			return kern.API_Base.HttpMethod.GET;
		}
	}

	/**
	 * @description A POST handler with no idempotency key that refuses the request from parseResponse(): without the
	 * refusal, a POST sent without an Idempotency-Key header that got an answer would leave an issue saying the external
	 * system may have acted.
	 */
	public class BulkRetryRefusing extends BulkRetryGet
	{
		/**
		 * @description A POST, which is not safe to repeat without a key.
		 *
		 * @return POST.
		 */
		public override kern.API_Base.HttpMethod getHttpMethod()
		{
			return kern.API_Base.HttpMethod.POST;
		}

		/**
		 * @description Refuses the request after a successful answer, as a handler does when the body says the external
		 * system turned it down.
		 */
		public override void parseResponse()
		{
			throw new kern.UTIL_Exceptions.RequestRefusedException(MESSAGE_REQUEST_REFUSED);
		}
	}

	/**
	 * @description The request the inbound handler receives: the name of the record it saves, so the test can find it.
	 */
	@JsonAccess(serializable='always' deserializable='always')
	public class BulkRetryInboundRequest extends kern.DTO_JsonBase
	{
		/**
		 * @description The name the saved record gets.
		 */
		public String recordName;
	}

	/**
	 * @description An inbound handler that saves one record, named by the request, when the request succeeds.
	 */
	public inherited sharing class BulkRetryInbound extends kern.API_Inbound
	{
		/**
		 * @description Sets the payloads.
		 */
		public override void configure()
		{
			super.configure();
			requestPayload = new BulkRetryInboundRequest();
			responsePayload = new BulkRetryPayload();
		}

		/**
		 * @description Registers the record with the handler's own save.
		 */
		public override void onSuccess()
		{
			super.onSuccess();
			doInsert(kern.TST_Builder.of(kern__Foobar__c.SObjectType)
					.withOverride(kern__Foobar__c.Name, ((BulkRetryInboundRequest)requestPayload).recordName)
					.withoutInsertion()
					.build());
		}
	}
}
