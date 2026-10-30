// SPDX-License-Identifier: Apache-2.0
/**
 * @description Tests for the Retry API Issues Flow action: the single request guard, the permission refusal, the message
 * for each outcome and the retry the job performs, including a call written with global members only, as a subscriber writes it.
 *
 * @see FLOW_RetryApiIssues
 *
 * @author Jason van Beukering
 *
 * @group Web Services
 *
 * @date October 2026
 */
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest(seeAllData=false isParallel=false)
private class FLOW_RetryApiIssues_TEST
{
	/**
	 * @description The outbound service whose calls succeed and whose setting allows retries.
	 */
	private static final String SERVICE_NAME = API_PostExample.class.getName();

	/**
	 * @description The name of the one parameter every seeded request carries, so two requests differ only by its value.
	 */
	private static final String PARAMETER_NAME = 'reference';

	/**
	 * @description A value that is not a record id.
	 */
	private static final String NOT_A_RECORD_ID = 'not-an-id';

	/**
	 * @description How many issues the queueing tests select.
	 */
	private static final Integer SELECTED_ISSUE_COUNT = 2;

	/**
	 * @description How many issues the large selection holds: enough that one query for each issue would be plain to see,
	 * and well inside the query limit if each issue cost one.
	 */
	private static final Integer LARGE_SELECTION_COUNT = 60;

	/**
	 * @description The direction of an issue logged for a call the framework made, written as a subscriber writes it.
	 */
	private static final String DIRECTION_OUTBOUND = 'Outbound';

	/**
	 * @description The direction of an issue logged for a request the org received, written as a subscriber writes it.
	 */
	private static final String DIRECTION_INBOUND = 'Inbound';

	/**
	 * @description The route pattern of the inbound setting the inbound test registers.
	 */
	private static final String INBOUND_ROUTE_PATH = '/echo/*';

	/**
	 * @description The routing priority of the inbound setting the inbound test registers.
	 */
	private static final Integer INBOUND_ROUTE_PRIORITY = 100;

	/**
	 * @description The path of the request the inbound issue holds.
	 */
	private static final String INBOUND_REQUEST_PATH = '/echo/test';

	/**
	 * @description The status an open issue has, written as a subscriber writes it.
	 */
	private static final String STATUS_OPEN = 'Open';

	/**
	 * @description The status a resolved issue has, written as a subscriber writes it.
	 */
	private static final String STATUS_RESOLVED = 'Resolved';

	/**
	 * @description Company name of the test user who holds the Kern API Issue Resolver permission set: a Standard User
	 * with no other Kern permission set.
	 */
	private static final String API_ISSUE_RESOLVER_USER_COMPANY = 'FLOW_RetryApiIssues_TEST-resolver';

	/**
	 * @description Company name of the user without the permission, a Standard User who holds no Kern permission set.
	 */
	private static final String USER_WITHOUT_RETRY_PERMISSION_COMPANY = 'FLOW_RetryApiIssues_TEST-no-permission';

	/**
	 * @description Creates two Standard Users: one who holds the Kern API Issue Resolver permission set, and one who
	 * holds no Kern permission set. They are created in setup so that System.runAs checks their permissions afresh in
	 * each test.
	 */
	@TestSetup
	private static void setupUsers()
	{
		TST_Factory.newUserWithPermissionSet(SEL_Profile.PROFILE_STANDARD_USER, API_ISSUE_RESOLVER_USER_COMPANY, CTRL_RetryApiIssue.API_ISSUE_RESOLVER_PERMISSION_SET_NAME);
		TST_Factory.insertUser(SEL_Profile.PROFILE_STANDARD_USER, USER_WITHOUT_RETRY_PERMISSION_COMPANY);
	}

	/**
	 * @description Finds the test user who holds the Kern API Issue Resolver permission set.
	 *
	 * @return The Standard User holding only the Kern API Issue Resolver permission set
	 */
	private static User getUserWithApiIssueResolverPermissionSet()
	{
		return new SEL_User().findByCompanyName(API_ISSUE_RESOLVER_USER_COMPANY);
	}

	/**
	 * @description Finds the test user who holds no Kern permission set, and asserts that this user does not hold the
	 * Retry API Issue permission. When the package is installed for all users, the install gives the permission to
	 * every profile, so every user holds it. A refusal test in such an org would not be testing a user without the
	 * permission, and the assertion says so.
	 *
	 * @return The user without the permission, guaranteed to lack the permission
	 */
	private static User getUserWithoutRetryPermission()
	{
		User user = new SEL_User().findByCompanyName(USER_WITHOUT_RETRY_PERMISSION_COMPANY);
		Assert.isFalse
				(
						SEL_CustomPermission.hasPackagePermission(user.Id, CTRL_RetryApiIssue.RETRY_API_ISSUE_CUSTOM_PERMISSION_NAME),
						'Expected the user without the permission to lack ' + CTRL_RetryApiIssue.RETRY_API_ISSUE_CUSTOM_PERMISSION_NAME + '; this org grants it to every user'
				);
		return user;
	}

	/**
	 * @description Saves an open issue of the service whose calls succeed, for a fresh request made for the running user.
	 *
	 * @return The saved issue
	 */
	private static ApiIssue__c insertOpenIssue()
	{
		ApiCall__c apiCall = TST_Factory.newOutboundApiCall(SERVICE_NAME, UserInfo.getUserId(), PARAMETER_NAME, UTIL_Random.randomName());
		return TST_Factory.insertApiIssue(apiCall, UTIL_Crypto.generateMD5Hash(apiCall.RequestParameters__c));
	}

	/**
	 * @description Saves the given number of open issues of the service whose calls succeed in one save, each for a fresh
	 * request made for the running user. One save keeps the work the issue trigger does within the test's limits.
	 *
	 * @param issueCount How many issues to save
	 *
	 * @return The ids of the saved issues
	 */
	@SuppressWarnings('PMD.KernSecurityBypassCallSite')
	private static List<String> insertOpenIssues(Integer issueCount)
	{
		List<ApiIssue__c> issues = new List<ApiIssue__c>();
		for(Integer index = 0; index < issueCount; index++)
		{
			ApiCall__c apiCall = TST_Factory.newOutboundApiCall(SERVICE_NAME, UserInfo.getUserId(), PARAMETER_NAME, UTIL_Random.randomName());
			issues.add(TST_Factory.newApiIssue(apiCall, UTIL_Crypto.generateMD5Hash(apiCall.RequestParameters__c)));
		}
		DML_Builder.newTransaction().withSystemMode().doInsert(issues).execute();
		List<String> issueIds = new List<String>();
		for(ApiIssue__c issue : issues)
		{
			issueIds.add(issue.Id);
		}
		return issueIds;
	}

	/**
	 * @description Calls the action once for the given issues and counts the database queries the call spent. The
	 * query cache is emptied first, so each call is measured as a user's own request would run: a read kept in memory
	 * by an earlier call in the same test does not make the later call look cheaper than it is.
	 *
	 * @param issueIds The ids of the selected issues
	 *
	 * @return How many queries the call spent
	 */
	private static Integer countQueriesOfOneRetry(List<String> issueIds)
	{
		QRY_Engine.clearQueryResultMemoryCache();
		Integer queriesBefore = UTIL_Limits.soqlQueries().used();
		FLOW_RetryApiIssues.retryApiIssues(newRequests(issueIds));
		return UTIL_Limits.soqlQueries().used() - queriesBefore;
	}

	/**
	 * @description Saves a change to an issue, the way the engine writes issues.
	 *
	 * @param issue The issue to save
	 */
	@SuppressWarnings('PMD.KernSecurityBypassCallSite')
	private static void updateIssue(ApiIssue__c issue)
	{
		DML_Builder.newTransaction().withSystemMode().doUpdate(issue).execute();
	}

	/**
	 * @description Builds the one request the action takes, naming the given issues.
	 *
	 * @param issueIds The ids of the issues to run again
	 *
	 * @return The request list the action expects
	 */
	private static List<FLOW_RetryApiIssues.DTO_Request> newRequests(List<String> issueIds)
	{
		FLOW_RetryApiIssues.DTO_Request request = new FLOW_RetryApiIssues.DTO_Request();
		request.apiIssueIds = issueIds;
		return new List<FLOW_RetryApiIssues.DTO_Request> {request};
	}

	/**
	 * @description Calls the action as the given user and lets the job run.
	 *
	 * @param runningUser The user who presses Retry Selected
	 * @param issueIds The ids of the selected issues
	 *
	 * @return The one response the action gave
	 */
	private static FLOW_RetryApiIssues.DTO_Response retryAs(User runningUser, List<String> issueIds)
	{
		FLOW_RetryApiIssues.DTO_Response response;
		System.runAs(runningUser)
		{
			Test.startTest();
			response = FLOW_RetryApiIssues.retryApiIssues(newRequests(issueIds)).get(0);
			Test.stopTest();
		}
		return response;
	}

	/**
	 * @description Asserts the status of one issue.
	 *
	 * @param issueId The issue to check
	 * @param expectedStatus The status it must have
	 */
	private static void assertStatus(Id issueId, String expectedStatus)
	{
		ApiIssue__c issue = (ApiIssue__c)new SEL_ApiIssue().findById(issueId);
		Assert.areEqual(expectedStatus, issue.Status__c, 'Expected issue ' + issueId + ' to be ' + expectedStatus);
	}

	/**
	 * @description The action refuses anything but exactly one request: no list, an empty list and two requests.
	 */
	@IsTest
	private static void shouldThrowWhenNoRequests()
	{
		List<List<FLOW_RetryApiIssues.DTO_Request>> invalidLists = new List<List<FLOW_RetryApiIssues.DTO_Request>>
		{
				null,
				new List<FLOW_RetryApiIssues.DTO_Request>(),
				new List<FLOW_RetryApiIssues.DTO_Request> {new FLOW_RetryApiIssues.DTO_Request(), new FLOW_RetryApiIssues.DTO_Request()}
		};
		for(List<FLOW_RetryApiIssues.DTO_Request> invalidList : invalidLists)
		{
			try
			{
				FLOW_RetryApiIssues.retryApiIssues(invalidList);
				Assert.fail('Expected an IllegalArgumentException for ' + (invalidList == null ? 'no list' : 'a list of ' + invalidList.size()));
			}
			catch(Exception error)
			{
				Assert.isInstanceOfType(error, IllegalArgumentException.class, 'Expected the single request guard to throw, got ' + error.getMessage());
			}
		}
	}

	/**
	 * @description Two open issues are queued for the user who holds the Kern API Issue Resolver permission set, the answer says two of two, and the job resolves both.
	 */
	@IsTest
	private static void shouldQueueTheOpenIssuesForTheResolver()
	{
		ApiIssue__c firstIssue = insertOpenIssue();
		ApiIssue__c secondIssue = insertOpenIssue();

		FLOW_RetryApiIssues.DTO_Response response = retryAs(getUserWithApiIssueResolverPermissionSet(), new List<String> {firstIssue.Id, secondIssue.Id});

		Assert.isNotNull(response.jobId, 'Expected a job id for the queued issues');
		Assert.isTrue(response.success, 'Expected success when issues were queued');
		Assert.areEqual(SELECTED_ISSUE_COUNT, response.queuedCount, 'Expected both open issues to be queued');
		Assert.areEqual
				(
						String.format(System.Label.RetryApiIssues_Queued, new List<Object> {SELECTED_ISSUE_COUNT, SELECTED_ISSUE_COUNT}),
						response.message,
						'Expected the message to come from the label'
				);
		assertStatus(firstIssue.Id, STATUS_RESOLVED);
		assertStatus(secondIssue.Id, STATUS_RESOLVED);
	}

	/**
	 * @description Of one flagged open issue and one plain open issue, one is queued and the answer says one of two: the
	 * flagged issue stays open and the plain one is resolved.
	 */
	@IsTest
	private static void shouldSayHowManyOfTheSelectionWereQueued()
	{
		ApiIssue__c flaggedIssue = insertOpenIssue();
		flaggedIssue.ExternalSystemMayHaveActed__c = true;
		updateIssue(flaggedIssue);
		ApiIssue__c plainIssue = insertOpenIssue();

		FLOW_RetryApiIssues.DTO_Response response = retryAs(getUserWithApiIssueResolverPermissionSet(), new List<String> {flaggedIssue.Id, plainIssue.Id});

		Assert.isTrue(response.success, 'Expected the request to be accepted, because one issue was queued');
		Assert.areEqual(1, response.queuedCount, 'Expected only the plain issue to be queued');
		Assert.areEqual
				(
						String.format(System.Label.RetryApiIssues_Queued, new List<Object> {1, SELECTED_ISSUE_COUNT}),
						response.message,
						'Expected the message to say one of two were queued'
				);
		assertStatus(flaggedIssue.Id, STATUS_OPEN);
		assertStatus(plainIssue.Id, STATUS_RESOLVED);
	}

	/**
	 * @description An issue of a request your org received is checked like any other: when its service has Retry Issues
	 * off, it is not queued, the answer says none of one was queued, and the issue stays open.
	 */
	@IsTest
	private static void shouldNotQueueAnInboundIssueWhoseServiceHasRetryIssuesOff()
	{
		String inboundServiceName = API_Echo.class.getName();
		TST_Factory.newInboundApiSetting
				(
						inboundServiceName,
						INBOUND_ROUTE_PATH,
						INBOUND_ROUTE_PRIORITY,
						new Map<SObjectField, Object> {ApiSetting__mdt.RetryIssues__c => false, ApiSetting__mdt.LogIssues__c => true}
				);
		ApiIssue__c inboundIssue = (ApiIssue__c)TST_Builder.of(ApiIssue__c.SObjectType)
				.withOverride(ApiIssue__c.Direction__c, DIRECTION_INBOUND)
				.withOverride(ApiIssue__c.ServiceName__c, inboundServiceName)
				.withOverride(ApiIssue__c.Status__c, STATUS_OPEN)
				.withOverride(ApiIssue__c.RequestPath__c, INBOUND_REQUEST_PATH)
				.build();

		FLOW_RetryApiIssues.DTO_Response response = retryAs(getUserWithApiIssueResolverPermissionSet(), new List<String> {inboundIssue.Id});

		Assert.isFalse(response.success, 'Expected nothing to be accepted');
		Assert.areEqual(0, response.queuedCount, 'Expected the inbound issue not to be queued');
		Assert.areEqual
				(
						String.format(System.Label.RetryApiIssues_Queued, new List<Object> {0, 1}),
						response.message,
						'Expected the message to say none of one was queued'
				);
		assertStatus(inboundIssue.Id, STATUS_OPEN);
	}

	/**
	 * @description A user without the Retry API Issue permission queues nothing, is told so by the label, and the issue stays open.
	 */
	@IsTest
	private static void shouldRefuseAUserWithoutThePermission()
	{
		ApiIssue__c issue = insertOpenIssue();
		Integer callCountBefore = new SEL_ApiCall().findByServiceName(SERVICE_NAME).size();

		FLOW_RetryApiIssues.DTO_Response response = retryAs(getUserWithoutRetryPermission(), new List<String> {issue.Id});

		Assert.isNull(response.jobId, 'Expected no job for a user without the permission');
		Assert.isFalse(response.success, 'Expected no success for a user without the permission');
		Assert.areEqual(0, response.queuedCount, 'Expected nothing queued for a user without the permission');
		Assert.areEqual(System.Label.RetryApiIssue_PermissionRequired, response.message, 'Expected the refusal to come from the label');
		assertStatus(issue.Id, STATUS_OPEN);
		Assert.areEqual(callCountBefore, new SEL_ApiCall().findByServiceName(SERVICE_NAME).size(), 'Expected no new call');
	}

	/**
	 * @description When no selected issue is open, nothing is queued and the answer says only open issues can be retried.
	 */
	@IsTest
	private static void shouldReportNothingToRetryWhenNoSelectedIssueIsOpen()
	{
		ApiIssue__c resolvedIssue = insertOpenIssue();
		resolvedIssue.Status__c = STATUS_RESOLVED;
		updateIssue(resolvedIssue);

		FLOW_RetryApiIssues.DTO_Response response = retryAs(getUserWithApiIssueResolverPermissionSet(), new List<String> {resolvedIssue.Id, NOT_A_RECORD_ID});

		Assert.isNull(response.jobId, 'Expected no job when nothing is open');
		Assert.isFalse(response.success, 'Expected no success when nothing is open');
		Assert.areEqual(0, response.queuedCount, 'Expected nothing queued when nothing is open');
		Assert.areEqual(System.Label.RetryApiIssues_NothingToRetry, response.message, 'Expected the message to come from the label');
	}

	/**
	 * @description Selecting many outbound issues of one service reads the database as often as selecting one: the
	 * service's answer to "does it accept retries" is worked out once, not once per issue. A list view lets a user
	 * select up to 200 rows, so a cost per issue would run out of queries.
	 */
	@IsTest
	private static void shouldSpendAsManyQueriesOnALargeSelectionAsOnOneIssue()
	{
		List<String> singleIssueIds = new List<String> {insertOpenIssue().Id};
		List<String> largeSelectionIds = insertOpenIssues(LARGE_SELECTION_COUNT);
		Integer queriesForOneIssue;
		Integer queriesForLargeSelection;

		System.runAs(getUserWithApiIssueResolverPermissionSet())
		{
			Test.startTest();
			queriesForOneIssue = countQueriesOfOneRetry(singleIssueIds);
			queriesForLargeSelection = countQueriesOfOneRetry(largeSelectionIds);
			Test.stopTest();
		}

		Assert.areEqual
				(
						queriesForOneIssue,
						queriesForLargeSelection,
						'Expected a selection of ' + LARGE_SELECTION_COUNT + ' outbound issues of one service to read the database as often as a selection of one'
				);
	}

	/**
	 * @description A call written with global members only queues and resolves an open issue, as a subscriber's Apex does.
	 */
	@IsTest
	private static void shouldQueueIssuesWhenCalledAsSubscriberApex()
	{
		String parameters = new DTO_NameValues(new Map<String, String> {PARAMETER_NAME => UTIL_Random.randomName()}).serialize();
		ApiIssue__c issue = (ApiIssue__c)TST_Builder.of(ApiIssue__c.SObjectType)
				.withOverride(ApiIssue__c.ServiceName__c, SERVICE_NAME)
				.withOverride(ApiIssue__c.Direction__c, DIRECTION_OUTBOUND)
				.withOverride(ApiIssue__c.Status__c, STATUS_OPEN)
				.withOverride(ApiIssue__c.TriggeringRecordId__c, UserInfo.getUserId())
				.withOverride(ApiIssue__c.RequestParameters__c, parameters)
				.build();

		FLOW_RetryApiIssues.DTO_Response response = retryAs(getUserWithApiIssueResolverPermissionSet(), new List<String> {issue.Id});

		Assert.isTrue(response.success, 'Expected the request to be accepted, because the open issue was queued');
		Assert.areEqual(1, response.queuedCount, 'Expected the open issue to be queued');
		Assert.isNotNull(response.jobId, 'Expected a job id for the queued issue');
		assertStatus(issue.Id, STATUS_RESOLVED);
	}
}
