// SPDX-License-Identifier: Apache-2.0
/**
 * @description Tests for the bulk retry of selected API issues: every test schedules through
 * CTRL_RetryApiIssue.scheduleBulkRetryOfIssues inside Test.startTest() and Test.stopTest(), so the job runs as the platform
 * runs it, and asserts what the job sent and what it left open.
 *
 * @see CTRL_RetryApiIssue
 * @see CTRL_RetryApiIssue_TEST
 *
 * @author Jason van Beukering
 *
 * @group Controllers
 *
 * @date October 2026
 */
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs, PMD.CyclomaticComplexity')
@IsTest(seeAllData=false isParallel=false)
private class CTRL_RetryApiIssueBulkRetry_TEST
{
	/**
	 * @description The outbound service whose calls succeed and whose setting allows retries.
	 */
	private static final String SERVICE_NAME = API_PostExample.class.getName();

	/**
	 * @description The outbound service whose setting does not allow retries.
	 */
	private static final String SERVICE_WITHOUT_RETRY_NAME = API_GetPwndPasswords.class.getName();

	/**
	 * @description The name of the one parameter every seeded request carries, so two requests differ only by its value.
	 */
	private static final String PARAMETER_NAME = 'reference';

	/**
	 * @description How many open issues the duplicate tests log for one request.
	 */
	private static final Integer DUPLICATE_ISSUE_COUNT = 3;

	/**
	 * @description A job size below the duplicate count, so issues of one request would fall into different batches if
	 * the job grouped them only within a batch.
	 */
	private static final Integer JOB_SIZE_BELOW_DUPLICATE_COUNT = 1;

	/**
	 * @description The start of a triggering record value that is not a record id, as a subscriber may write one.
	 */
	private static final String NON_ID_RECORD_PREFIX = 'ORDER-';
	/**
	 * @description How many digits follow the prefix of a triggering record value that is not a record id.
	 */
	private static final Integer NON_ID_RECORD_DIGITS = 8;

	/**
	 * @description Where the job logs its warnings.
	 */
	private static final String PROCESSOR_LOG_LOCATION = CTRL_RetryApiIssue.class.getName() + '/FailureReplayProcessor';

	/**
	 * @description Where scheduleBulkRetryOfIssues logs its refusal.
	 */
	private static final String ENTRY_LOG_LOCATION = CTRL_RetryApiIssue.class.getName() + '/scheduleBulkRetryOfIssues';

	/**
	 * @description The words the job's warning about an open call starts its reason with.
	 */
	private static final String OPEN_CALL_WARNING_PHRASE = 'still in progress';

	/**
	 * @description Company name of the test user who holds the Kern API Issue Resolver permission set: a Standard User
	 * with no other Kern permission set.
	 */
	private static final String API_ISSUE_RESOLVER_USER_COMPANY = 'CTRL_RetryApiIssueBulkRetry_TEST-resolver';

	/**
	 * @description Company name of the user without the permission, a Standard User who holds no Kern permission set.
	 */
	private static final String USER_WITHOUT_RETRY_PERMISSION_COMPANY = 'CTRL_RetryApiIssueBulkRetry_TEST-no-permission';

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
		return CTRL_RetryApiIssue_TEST.assertLacksRetryPermission(new SEL_User().findByCompanyName(USER_WITHOUT_RETRY_PERMISSION_COMPANY));
	}

	/**
	 * @description Builds an open outbound issue with no idempotency key, not yet saved, for one request: its parameters hash is the hash of the
	 * request parameters, as the engine logs it.
	 *
	 * @param serviceName The service the request was sent to
	 * @param recordId The record the request was made for, or null
	 * @param parameterValue The value of the request's one parameter
	 *
	 * @return The issue, not yet saved
	 */
	private static ApiIssue__c newOpenIssue(String serviceName, Id recordId, String parameterValue)
	{
		ApiCall__c apiCall = TST_Factory.newOutboundApiCall(serviceName, recordId, PARAMETER_NAME, parameterValue);
		return TST_Factory.newApiIssue(apiCall, UTIL_Crypto.generateMD5Hash(apiCall.RequestParameters__c));
	}

	/**
	 * @description Builds an open outbound issue of the service whose calls succeed, for a fresh request made for the running
	 * user, with no idempotency key. The service fails a request made for no record, so every issue it sends names one.
	 *
	 * @return The issue, not yet saved
	 */
	private static ApiIssue__c newOpenIssue()
	{
		return newOpenIssue(SERVICE_NAME, UserInfo.getUserId(), UTIL_Random.randomName());
	}

	/**
	 * @description Saves the issues.
	 *
	 * @param issues The issues to save
	 *
	 * @return The ids of the saved issues
	 */
	@SuppressWarnings('PMD.KernSecurityBypassCallSite')
	private static Set<Id> insertIssues(List<ApiIssue__c> issues)
	{
		DML_Builder.newTransaction().withSystemMode().doInsert(issues).execute();
		return UTIL_SObject.extractIds(issues);
	}

	/**
	 * @description Saves a call record.
	 *
	 * @param apiCall The call to save
	 */
	@SuppressWarnings('PMD.KernSecurityBypassCallSite')
	private static void insertCall(ApiCall__c apiCall)
	{
		DML_Builder.newTransaction().withSystemMode().doInsert(apiCall).execute();
	}
	/**
	 * @description Counts the calls of a service.
	 *
	 * @param serviceName The service whose calls are counted
	 *
	 * @return How many calls the service has
	 */
	private static Integer countCalls(String serviceName)
	{
		return new SEL_ApiCall().findByServiceName(serviceName).size();
	}

	/**
	 * @description Counts the open issues of a service.
	 *
	 * @param serviceName The service whose open issues are counted
	 *
	 * @return How many open issues the service has
	 */
	private static Integer countOpenIssues(String serviceName)
	{
		return new SEL_ApiIssue().findUnresolvedByService(serviceName).size();
	}

	/**
	 * @description Registers the service's own setting with Resolve Issues turned off, so the engine's own resolution of
	 * matching issues after a successful call cannot resolve the duplicates and hide whether the job did.
	 *
	 * @param serviceName The service whose setting is registered
	 */
	private static void registerSettingWithoutIssueResolution(String serviceName)
	{
		ApiSetting__mdt setting = new SEL_ApiSetting().findByClassName(serviceName);
		setting.ResolveIssues__c = false;
		TST_Mock.register(ApiSetting__mdt.SObjectType, setting);
	}

	/**
	 * @description Registers a setting for the service that allows retries, with the given changes on top.
	 *
	 * @param overrides The setting fields to change
	 */
	private static void registerSetting(Map<SObjectField, Object> overrides)
	{
		Map<SObjectField, Object> settingOverrides = new Map<SObjectField, Object> {ApiSetting__mdt.RetryIssues__c => true};
		settingOverrides.putAll(overrides);
		TST_Factory.newOutboundApiSetting(SERVICE_NAME, settingOverrides);
	}

	/**
	 * @description Schedules the bulk retry of the issues as the given user, and lets the job run.
	 *
	 * @param runningUser The user who presses Retry Selected
	 * @param issueIds The ids of the selected issues
	 *
	 * @return What the entry answered
	 */
	private static CTRL_RetryApiIssue.DTO_ScheduledBulkRetry scheduleAs(User runningUser, Set<Id> issueIds)
	{
		CTRL_RetryApiIssue.DTO_ScheduledBulkRetry scheduledRetry;
		System.runAs(runningUser)
		{
			Test.startTest();
			scheduledRetry = CTRL_RetryApiIssue.scheduleBulkRetryOfIssues(issueIds);
			Test.stopTest();
		}
		return scheduledRetry;
	}

	/**
	 * @description Asserts the status of every given issue.
	 *
	 * @param issueIds The issues to check
	 * @param expectedStatus The status each must have
	 */
	private static void assertStatus(Set<Id> issueIds, String expectedStatus)
	{
		for(ApiIssue__c issue : (List<ApiIssue__c>)new SEL_ApiIssue().findById(issueIds))
		{
			Assert.areEqual(expectedStatus, issue.Status__c, 'Expected issue ' + issue.Id + ' to be ' + expectedStatus);
		}
	}

	/**
	 * @description Asserts the status of one issue.
	 *
	 * @param issueId The issue to check
	 * @param expectedStatus The status it must have
	 */
	private static void assertStatus(Id issueId, String expectedStatus)
	{
		assertStatus(new Set<Id> {issueId}, expectedStatus);
	}

	/**
	 * @description Asserts that the job logged, at warn, that it skipped issues because a call is still in progress.
	 */
	private static void assertOpenCallWarning()
	{
		LogEntry__c warning = new SEL_LogEntry().findByMethod(PROCESSOR_LOG_LOCATION);
		Assert.isNotNull(warning, 'Expected the job to log the issues it skipped for an open call');
		Assert.isTrue(warning.ShortMessage__c.contains(OPEN_CALL_WARNING_PHRASE), 'Expected the warning to name the open call, got ' + warning.ShortMessage__c);
	}

	/**
	 * @description Three open issues logged for one keyed request (one service, record, parameters and key) are sent once,
	 * and the one success resolves all three. The setting has Resolve Issues off, so only the job can resolve the other two.
	 */
	@IsTest
	private static void shouldSendOneCallForKeyedDuplicateIssues()
	{
		registerSettingWithoutIssueResolution(SERVICE_NAME);
		Set<Id> issueIds = insertDuplicateIssues(UTIL_Random.randomUUID());
		Integer callCountBefore = countCalls(SERVICE_NAME);

		scheduleAs(getUserWithApiIssueResolverPermissionSet(), issueIds);

		Assert.areEqual(callCountBefore + 1, countCalls(SERVICE_NAME), 'Expected one call for the one request');
		assertStatus(issueIds, SEL_ApiIssue.STATUS_RESOLVED);
	}

	/**
	 * @description Three open issues logged for one request without a key, the shape an exhausted automatic retry leaves,
	 * are sent once, and the one success resolves all three.
	 */
	@IsTest
	private static void shouldSendOneCallForUnkeyedDuplicateIssuesOfOneRequest()
	{
		registerSettingWithoutIssueResolution(SERVICE_NAME);
		Set<Id> issueIds = insertDuplicateIssues(null);
		Integer callCountBefore = countCalls(SERVICE_NAME);

		scheduleAs(getUserWithApiIssueResolverPermissionSet(), issueIds);

		Assert.areEqual(callCountBefore + 1, countCalls(SERVICE_NAME), 'Expected one call for the one request');
		assertStatus(issueIds, SEL_ApiIssue.STATUS_RESOLVED);
	}

	/**
	 * @description Seeds open issues logged for one request, of the service whose calls succeed, made for the running user.
	 *
	 * @param idempotencyKey The request's idempotency key, or null
	 *
	 * @return The ids of the saved issues
	 */
	private static Set<Id> insertDuplicateIssues(String idempotencyKey)
	{
		String parameterValue = UTIL_Random.randomName();
		List<ApiIssue__c> issues = new List<ApiIssue__c>();
		for(Integer index = 0; index < DUPLICATE_ISSUE_COUNT; index++)
		{
			ApiIssue__c issue = newOpenIssue(SERVICE_NAME, UserInfo.getUserId(), parameterValue);
			issue.IdempotencyKey__c = idempotencyKey;
			issues.add(issue);
		}
		return insertIssues(issues);
	}

	/**
	 * @description Sets the bulk retry job size below the duplicate count.
	 */
	private static void useJobSizeBelowTheDuplicateCount()
	{
		SEL_AsynchronousJobSetting.mockedSetting = (AsynchronousJobSetting__mdt)TST_Builder.of(AsynchronousJobSetting__mdt.SObjectType)
				.withOverride(AsynchronousJobSetting__mdt.BatchSize__c, JOB_SIZE_BELOW_DUPLICATE_COUNT)
				.withoutInsertion(true)
				.build();
	}

	/**
	 * @description Keyed duplicates of one request are sent once and all resolved even when the job size is below their
	 * count: the job holds the request as one item, so its duplicates never fall into different batches.
	 */
	@IsTest
	private static void shouldSendOneCallForKeyedDuplicatesBeyondTheJobSize()
	{
		useJobSizeBelowTheDuplicateCount();
		registerSettingWithoutIssueResolution(SERVICE_NAME);
		Set<Id> issueIds = insertDuplicateIssues(UTIL_Random.randomUUID());
		Integer callCountBefore = countCalls(SERVICE_NAME);

		CTRL_RetryApiIssue.DTO_ScheduledBulkRetry scheduledRetry = scheduleAs(getUserWithApiIssueResolverPermissionSet(), issueIds);

		Assert.areEqual(DUPLICATE_ISSUE_COUNT, scheduledRetry.queuedCount, 'Expected every duplicate to be counted as queued');
		Assert.areEqual(callCountBefore + 1, countCalls(SERVICE_NAME), 'Expected one call for the one request');
		assertStatus(issueIds, SEL_ApiIssue.STATUS_RESOLVED);
	}

	/**
	 * @description Unkeyed duplicates of one request, the shape an exhausted automatic retry leaves, are sent once and all
	 * resolved even when the job size is below their count.
	 */
	@IsTest
	private static void shouldSendOneCallForUnkeyedDuplicatesBeyondTheJobSize()
	{
		useJobSizeBelowTheDuplicateCount();
		registerSettingWithoutIssueResolution(SERVICE_NAME);
		Set<Id> issueIds = insertDuplicateIssues(null);
		Integer callCountBefore = countCalls(SERVICE_NAME);

		scheduleAs(getUserWithApiIssueResolverPermissionSet(), issueIds);

		Assert.areEqual(callCountBefore + 1, countCalls(SERVICE_NAME), 'Expected one call for the one request');
		assertStatus(issueIds, SEL_ApiIssue.STATUS_RESOLVED);
	}

	/**
	 * @description A triggering record value that is not a record id does not stop the job: the rest of the batch is
	 * still sent and resolved.
	 */
	@IsTest
	private static void shouldSendTheBatchWhenATriggeringRecordIsNotAnId()
	{
		ApiIssue__c issueWithoutRecordId = newOpenIssue();
		issueWithoutRecordId.TriggeringRecordId__c = NON_ID_RECORD_PREFIX + UTIL_Random.randomNumeric(NON_ID_RECORD_DIGITS);
		ApiIssue__c plainIssue = newOpenIssue();
		Set<Id> issueIds = insertIssues(new List<ApiIssue__c> {issueWithoutRecordId, plainIssue});

		CTRL_RetryApiIssue.DTO_ScheduledBulkRetry scheduledRetry = scheduleAs(getUserWithApiIssueResolverPermissionSet(), issueIds);

		Assert.areEqual(issueIds.size(), scheduledRetry.queuedCount, 'Expected both issues to be queued');
		assertStatus(plainIssue.Id, SEL_ApiIssue.STATUS_RESOLVED);
	}

	/**
	 * @description Two open issues for one record but with different parameters are two requests, and both are sent.
	 */
	@IsTest
	private static void shouldSendSeparateCallsForDifferentRequests()
	{
		Set<Id> issueIds = insertIssues(new List<ApiIssue__c>
		{
				newOpenIssue(SERVICE_NAME, UserInfo.getUserId(), UTIL_Random.randomName()),
				newOpenIssue(SERVICE_NAME, UserInfo.getUserId(), UTIL_Random.randomName())
		});
		Integer callCountBefore = countCalls(SERVICE_NAME);

		scheduleAs(getUserWithApiIssueResolverPermissionSet(), issueIds);

		Assert.areEqual(callCountBefore + 2, countCalls(SERVICE_NAME), 'Expected one call per request');
		assertStatus(issueIds, SEL_ApiIssue.STATUS_RESOLVED);
	}

	/**
	 * @description Two open issues of one record with no parameters hash are never taken for one request: each is its own
	 * group, so both are sent.
	 */
	@IsTest
	private static void shouldSendSeparateCallsWhenTheHashIsMissing()
	{
		List<ApiIssue__c> issues = new List<ApiIssue__c> {newOpenIssue(), newOpenIssue()};
		for(ApiIssue__c issue : issues)
		{
			issue.RequestParametersHash__c = null;
		}
		Set<Id> issueIds = insertIssues(issues);
		Integer callCountBefore = countCalls(SERVICE_NAME);

		scheduleAs(getUserWithApiIssueResolverPermissionSet(), issueIds);

		Assert.areEqual(callCountBefore + 2, countCalls(SERVICE_NAME), 'Expected one call per issue without a hash');
		assertStatus(issueIds, SEL_ApiIssue.STATUS_RESOLVED);
	}

	/**
	 * @description Of three selected open issues, only the one the job will not certainly skip is handed over and counted:
	 * the flagged one and the one of a service without retries stay open and are not counted as queued.
	 */
	@IsTest
	private static void shouldQueueOnlyTheIssuesTheJobWouldNotCertainlySkip()
	{
		ApiIssue__c flaggedIssue = newOpenIssue();
		flaggedIssue.ExternalSystemMayHaveActed__c = true;
		ApiIssue__c plainIssue = newOpenIssue();
		ApiIssue__c issueWithoutRetry = newOpenIssue(SERVICE_WITHOUT_RETRY_NAME, null, UTIL_Random.randomName());
		Set<Id> issueIds = insertIssues(new List<ApiIssue__c> {flaggedIssue, plainIssue, issueWithoutRetry});
		Integer callCountBefore = countCalls(SERVICE_NAME);

		CTRL_RetryApiIssue.DTO_ScheduledBulkRetry scheduledRetry = scheduleAs(getUserWithApiIssueResolverPermissionSet(), issueIds);

		Assert.areEqual(issueIds.size(), scheduledRetry.selectedCount, 'Expected every selected open issue to be counted as selected');
		Assert.areEqual(1, scheduledRetry.queuedCount, 'Expected only the plain issue to be queued');
		Assert.areEqual(callCountBefore + 1, countCalls(SERVICE_NAME), 'Expected one call, for the plain issue');
		assertStatus(plainIssue.Id, SEL_ApiIssue.STATUS_RESOLVED);
		assertStatus(new Set<Id> {flaggedIssue.Id, issueWithoutRetry.Id}, SEL_ApiIssue.STATUS_OPEN);
	}

	/**
	 * @description An issue of an inactive service is not sent, stays open and no new issue is logged.
	 */
	@IsTest
	private static void shouldNotSendForAnInactiveService()
	{
		registerSetting(new Map<SObjectField, Object> {ApiSetting__mdt.IsActive__c => false});
		Set<Id> issueIds = insertIssues(new List<ApiIssue__c> {newOpenIssue()});
		Integer callCountBefore = countCalls(SERVICE_NAME);

		scheduleAs(getUserWithApiIssueResolverPermissionSet(), issueIds);

		Assert.areEqual(callCountBefore, countCalls(SERVICE_NAME), 'Expected no call to an inactive service');
		assertStatus(issueIds, SEL_ApiIssue.STATUS_OPEN);
		Assert.areEqual(issueIds.size(), countOpenIssues(SERVICE_NAME), 'Expected no new issue');
	}

	/**
	 * @description An issue of a service whose required feature flag is off is not sent, stays open and no new issue is
	 * logged.
	 */
	@IsTest
	private static void shouldNotSendWhenTheRequiredFeatureFlagIsOff()
	{
		registerSetting(new Map<SObjectField, Object> {ApiSetting__mdt.RequiredFeatureFlag__c => TST_Factory.newFeatureFlag(UTIL_Random.randomName(), false)});
		Set<Id> issueIds = insertIssues(new List<ApiIssue__c> {newOpenIssue()});
		Integer callCountBefore = countCalls(SERVICE_NAME);

		scheduleAs(getUserWithApiIssueResolverPermissionSet(), issueIds);

		Assert.areEqual(callCountBefore, countCalls(SERVICE_NAME), 'Expected no call while the required flag is off');
		assertStatus(issueIds, SEL_ApiIssue.STATUS_OPEN);
		Assert.areEqual(issueIds.size(), countOpenIssues(SERVICE_NAME), 'Expected no new issue');
	}

	/**
	 * @description An issue of a service whose bypass feature flag is on is not sent, stays open and no new issue is logged.
	 */
	@IsTest
	private static void shouldNotSendWhenTheBypassFeatureFlagIsOn()
	{
		registerSetting(new Map<SObjectField, Object> {ApiSetting__mdt.BypassFeatureFlag__c => TST_Factory.newFeatureFlag(UTIL_Random.randomName())});
		Set<Id> issueIds = insertIssues(new List<ApiIssue__c> {newOpenIssue()});
		Integer callCountBefore = countCalls(SERVICE_NAME);

		scheduleAs(getUserWithApiIssueResolverPermissionSet(), issueIds);

		Assert.areEqual(callCountBefore, countCalls(SERVICE_NAME), 'Expected no call while the bypass flag is on');
		assertStatus(issueIds, SEL_ApiIssue.STATUS_OPEN);
		Assert.areEqual(issueIds.size(), countOpenIssues(SERVICE_NAME), 'Expected no new issue');
	}

	/**
	 * @description While the switch that disables every API is on, open issues of a service that accepts retries are not
	 * queued, nothing is sent and the issues stay open.
	 */
	@IsTest
	private static void shouldNotQueueWhileEveryApiIsDisabled()
	{
		TST_Factory.newFeatureFlag(API_Base.FLAG_DISABLE_ALL_APIS);
		Set<Id> issueIds = insertIssues(new List<ApiIssue__c> {newOpenIssue(), newOpenIssue()});
		Integer callCountBefore = countCalls(SERVICE_NAME);

		CTRL_RetryApiIssue.DTO_ScheduledBulkRetry scheduledRetry = scheduleAs(getUserWithApiIssueResolverPermissionSet(), issueIds);

		Assert.areEqual(issueIds.size(), scheduledRetry.selectedCount, 'Expected both open issues to be counted as selected');
		Assert.areEqual(0, scheduledRetry.queuedCount, 'Expected nothing queued while every API is disabled');
		Assert.isNull(scheduledRetry.jobId, 'Expected no job while every API is disabled');
		Assert.areEqual(callCountBefore, countCalls(SERVICE_NAME), 'Expected no call while every API is disabled');
		assertStatus(issueIds, SEL_ApiIssue.STATUS_OPEN);
	}

	/**
	 * @description While only the switch that disables every outbound API is on, open outbound issues of a service that
	 * accepts retries are not queued, nothing is sent and the issues stay open.
	 */
	@IsTest
	private static void shouldNotQueueWhileEveryOutboundApiIsDisabled()
	{
		TST_Factory.newFeatureFlag(API_Outbound.FLAG_DISABLE_ALL_OUTBOUND_APIS);
		Set<Id> issueIds = insertIssues(new List<ApiIssue__c> {newOpenIssue(), newOpenIssue()});
		Integer callCountBefore = countCalls(SERVICE_NAME);

		CTRL_RetryApiIssue.DTO_ScheduledBulkRetry scheduledRetry = scheduleAs(getUserWithApiIssueResolverPermissionSet(), issueIds);

		Assert.areEqual(0, scheduledRetry.queuedCount, 'Expected nothing queued while every outbound API is disabled');
		Assert.isNull(scheduledRetry.jobId, 'Expected no job while every outbound API is disabled');
		Assert.areEqual(callCountBefore, countCalls(SERVICE_NAME), 'Expected no call while every outbound API is disabled');
		assertStatus(issueIds, SEL_ApiIssue.STATUS_OPEN);
	}

	/**
	 * @description An issue whose own call is waiting for its automatic retry is not sent again: it stays open and the
	 * skip is logged at warn.
	 */
	@IsTest
	private static void shouldSkipAnIssueWhoseOwnCallIsStillOpen()
	{
		LOG_Builder.ignoreTestMode = true;
		ApiCall__c ownCall = TST_Factory.newOutboundApiCall(SERVICE_NAME);
		ownCall.Status__c = SEL_ApiCall.STATUS_RETRY;
		ownCall.NextRetry__c = Datetime.now().addHours(1);
		insertCall(ownCall);
		ApiIssue__c issue = newOpenIssue(SERVICE_NAME, null, UTIL_Random.randomName());
		issue.ApiCall__c = ownCall.Id;
		Set<Id> issueIds = insertIssues(new List<ApiIssue__c> {issue});
		Integer callCountBefore = countCalls(SERVICE_NAME);

		scheduleAs(getUserWithApiIssueResolverPermissionSet(), issueIds);

		Assert.areEqual(callCountBefore, countCalls(SERVICE_NAME), 'Expected no call while the issue\'s own call is open');
		assertStatus(issueIds, SEL_ApiIssue.STATUS_OPEN);
		assertOpenCallWarning();
	}

	/**
	 * @description An issue whose record has a call another user started, still being sent, is not sent: it stays open and
	 * the skip is logged at warn. The call stays at Processing: a Queued outbound call saved in a test is sent by the
	 * outbound call flow's own job when the test stops, before the bulk retry job reads it.
	 */
	@IsTest
	private static void shouldSkipAnIssueWhoseRecordHasAnotherUsersOpenCall()
	{
		LOG_Builder.ignoreTestMode = true;
		Id recordId = UserInfo.getUserId();
		ApiCall__c otherUsersCall = TST_Factory.newOutboundApiCall(SERVICE_NAME, recordId);
		otherUsersCall.Status__c = SEL_ApiCall.STATUS_PROCESSING;
		insertCall(otherUsersCall);
		Set<Id> issueIds = insertIssues(new List<ApiIssue__c> {newOpenIssue(SERVICE_NAME, recordId, UTIL_Random.randomName())});
		Integer callCountBefore = countCalls(SERVICE_NAME);

		scheduleAs(getUserWithApiIssueResolverPermissionSet(), issueIds);

		Assert.areEqual(callCountBefore, countCalls(SERVICE_NAME), 'Expected no call while another call for the record is open');
		assertStatus(issueIds, SEL_ApiIssue.STATUS_OPEN);
		assertOpenCallWarning();
	}

	/**
	 * @description An issue with no call record, whose record has no open call, is sent and resolved: the open-call check
	 * does not hold back an issue it has nothing to check against.
	 */
	@IsTest
	private static void shouldSendAnIssueThatHasNoCallRecord()
	{
		Set<Id> issueIds = insertIssues(new List<ApiIssue__c> {newOpenIssue(SERVICE_NAME, UserInfo.getUserId(), UTIL_Random.randomName())});
		Integer callCountBefore = countCalls(SERVICE_NAME);

		scheduleAs(getUserWithApiIssueResolverPermissionSet(), issueIds);

		Assert.areEqual(callCountBefore + 1, countCalls(SERVICE_NAME), 'Expected the issue to be sent');
		assertStatus(issueIds, SEL_ApiIssue.STATUS_RESOLVED);
	}

	/**
	 * @description Of two open issues, the one the remote system may already have processed is not sent and stays open;
	 * the other is sent and resolved.
	 */
	@IsTest
	private static void shouldSkipAFlaggedIssue()
	{
		ApiIssue__c flaggedIssue = newOpenIssue();
		flaggedIssue.ExternalSystemMayHaveActed__c = true;
		ApiIssue__c plainIssue = newOpenIssue();
		Set<Id> issueIds = insertIssues(new List<ApiIssue__c> {flaggedIssue, plainIssue});
		Integer callCountBefore = countCalls(SERVICE_NAME);

		scheduleAs(getUserWithApiIssueResolverPermissionSet(), issueIds);

		Assert.areEqual(callCountBefore + 1, countCalls(SERVICE_NAME), 'Expected one call, for the issue not flagged');
		assertStatus(flaggedIssue.Id, SEL_ApiIssue.STATUS_OPEN);
		assertStatus(plainIssue.Id, SEL_ApiIssue.STATUS_RESOLVED);
	}

	/**
	 * @description A request one of whose duplicates the remote system may already have processed is not sent from the
	 * other: nothing is queued, no call is made and both issues stay open, so the warning on the marked one is not hidden.
	 */
	@IsTest
	private static void shouldNotSendARequestWithAFlaggedDuplicate()
	{
		String parameterValue = UTIL_Random.randomName();
		ApiIssue__c flaggedIssue = newOpenIssue(SERVICE_NAME, UserInfo.getUserId(), parameterValue);
		flaggedIssue.ExternalSystemMayHaveActed__c = true;
		ApiIssue__c plainIssue = newOpenIssue(SERVICE_NAME, UserInfo.getUserId(), parameterValue);
		Set<Id> issueIds = insertIssues(new List<ApiIssue__c> {flaggedIssue, plainIssue});
		Integer callCountBefore = countCalls(SERVICE_NAME);

		CTRL_RetryApiIssue.DTO_ScheduledBulkRetry scheduledRetry = scheduleAs(getUserWithApiIssueResolverPermissionSet(), issueIds);

		Assert.areEqual(0, scheduledRetry.queuedCount, 'Expected no issue of the request to be queued');
		Assert.areEqual(callCountBefore, countCalls(SERVICE_NAME), 'Expected no call for a request with a flagged duplicate');
		assertStatus(issueIds, SEL_ApiIssue.STATUS_OPEN);
	}

	/**
	 * @description Of a selection holding an open issue, a resolved issue and an id that names no issue, only the open
	 * issue is counted, queued and resolved.
	 */
	@IsTest
	private static void shouldQueueOnlyOpenIssuesAndReturnTheCount()
	{
		ApiIssue__c openIssue = newOpenIssue();
		ApiIssue__c resolvedIssue = newOpenIssue();
		resolvedIssue.Status__c = SEL_ApiIssue.STATUS_RESOLVED;
		Set<Id> issueIds = insertIssues(new List<ApiIssue__c> {openIssue, resolvedIssue});
		issueIds.add(UTIL_Random.randomId(ApiIssue__c.SObjectType));

		CTRL_RetryApiIssue.DTO_ScheduledBulkRetry scheduledRetry = scheduleAs(getUserWithApiIssueResolverPermissionSet(), issueIds);

		Assert.areEqual(1, scheduledRetry.selectedCount, 'Expected only the open issue to be counted as selected');
		Assert.areEqual(1, scheduledRetry.queuedCount, 'Expected only the open issue to be queued');
		Assert.isNotNull(scheduledRetry.jobId, 'Expected a job for the open issue');
		assertStatus(openIssue.Id, SEL_ApiIssue.STATUS_RESOLVED);
	}

	/**
	 * @description A selection with no open issue schedules no job, counts nothing and sends nothing.
	 */
	@IsTest
	private static void shouldReturnNoJobWhenNoSelectedIssueIsOpen()
	{
		ApiIssue__c resolvedIssue = newOpenIssue();
		resolvedIssue.Status__c = SEL_ApiIssue.STATUS_RESOLVED;
		Set<Id> issueIds = insertIssues(new List<ApiIssue__c> {resolvedIssue});
		Integer callCountBefore = countCalls(SERVICE_NAME);

		CTRL_RetryApiIssue.DTO_ScheduledBulkRetry scheduledRetry = scheduleAs(getUserWithApiIssueResolverPermissionSet(), issueIds);

		Assert.isNull(scheduledRetry.jobId, 'Expected no job when no selected issue is open');
		Assert.areEqual(0, scheduledRetry.selectedCount, 'Expected nothing counted as selected');
		Assert.areEqual(0, scheduledRetry.queuedCount, 'Expected nothing queued');
		Assert.areEqual(callCountBefore, countCalls(SERVICE_NAME), 'Expected no call');
	}

	/**
	 * @description An issue of a service whose setting does not allow retries is not sent and stays open.
	 */
	@IsTest
	private static void shouldNotSendForAServiceWithoutRetryIssues()
	{
		Set<Id> issueIds = insertIssues(new List<ApiIssue__c> {newOpenIssue(SERVICE_WITHOUT_RETRY_NAME, null, UTIL_Random.randomName())});
		Integer callCountBefore = countCalls(SERVICE_WITHOUT_RETRY_NAME);

		scheduleAs(getUserWithApiIssueResolverPermissionSet(), issueIds);

		Assert.areEqual(callCountBefore, countCalls(SERVICE_WITHOUT_RETRY_NAME), 'Expected no call to a service without retries');
		assertStatus(issueIds, SEL_ApiIssue.STATUS_OPEN);
	}

	/**
	 * @description In one selection that mixes two services, each service gets its own answer to "does it accept retries":
	 * the issues of the service that accepts retries are sent and resolved, and those of the service that does not are
	 * neither queued nor sent and stay open. The issues of the two services alternate, so an answer shared by every issue
	 * of the selection would queue all four or none.
	 */
	@IsTest
	private static void shouldDecideForEachServiceInAMixedSelection()
	{
		List<ApiIssue__c> acceptingIssues = new List<ApiIssue__c> {newOpenIssue(), newOpenIssue()};
		List<ApiIssue__c> issuesWithoutRetry = new List<ApiIssue__c>
		{
				newOpenIssue(SERVICE_WITHOUT_RETRY_NAME, null, UTIL_Random.randomName()),
				newOpenIssue(SERVICE_WITHOUT_RETRY_NAME, null, UTIL_Random.randomName())
		};
		Set<Id> issueIds = insertIssues(new List<ApiIssue__c> {issuesWithoutRetry.get(0), acceptingIssues.get(0), issuesWithoutRetry.get(1), acceptingIssues.get(1)});
		Integer acceptingCallCountBefore = countCalls(SERVICE_NAME);
		Integer withoutRetryCallCountBefore = countCalls(SERVICE_WITHOUT_RETRY_NAME);

		CTRL_RetryApiIssue.DTO_ScheduledBulkRetry scheduledRetry = scheduleAs(getUserWithApiIssueResolverPermissionSet(), issueIds);

		Assert.areEqual(issueIds.size(), scheduledRetry.selectedCount, 'Expected every selected open issue to be counted as selected');
		Assert.areEqual(acceptingIssues.size(), scheduledRetry.queuedCount, 'Expected only the issues of the service that accepts retries to be queued');
		Assert.areEqual(acceptingCallCountBefore + acceptingIssues.size(), countCalls(SERVICE_NAME), 'Expected one call for each issue of the service that accepts retries');
		Assert.areEqual(withoutRetryCallCountBefore, countCalls(SERVICE_WITHOUT_RETRY_NAME), 'Expected no call to the service without retries');
		assertStatus(UTIL_SObject.extractIds(acceptingIssues), SEL_ApiIssue.STATUS_RESOLVED);
		assertStatus(UTIL_SObject.extractIds(issuesWithoutRetry), SEL_ApiIssue.STATUS_OPEN);
	}

	/**
	 * @description The call the job sends links to the call of the issue it was sent for (PreviousAttempt__c), so the
	 * attempts of one request can be followed from the first to the last.
	 */
	@IsTest
	private static void shouldLinkTheOutboundRetryCallToTheOriginalInTheJob()
	{
		ApiCall__c originalCall = TST_Factory.newOutboundApiCall(SERVICE_NAME, UserInfo.getUserId(), PARAMETER_NAME, UTIL_Random.randomName());
		originalCall.Status__c = SEL_ApiCall.STATUS_FAILED;
		insertCall(originalCall);
		ApiIssue__c issue = TST_Factory.newApiIssue(originalCall, UTIL_Crypto.generateMD5Hash(originalCall.RequestParameters__c));
		Set<Id> issueIds = insertIssues(new List<ApiIssue__c> {issue});

		scheduleAs(getUserWithApiIssueResolverPermissionSet(), issueIds);

		assertStatus(issueIds, SEL_ApiIssue.STATUS_RESOLVED);
		List<ApiCall__c> retryCalls = new List<ApiCall__c>();
		for(ApiCall__c apiCall : new SEL_ApiCall().findByServiceName(SERVICE_NAME))
		{
			if(apiCall.Id != originalCall.Id)
			{
				retryCalls.add(apiCall);
			}
		}
		Assert.areEqual(1, retryCalls.size(), 'Expected one call sent by the job');
		Assert.areEqual(originalCall.Id, retryCalls.get(0).PreviousAttempt__c, 'Expected the job\'s call to link to the original call');
	}

	/**
	 * @description An issue whose call is marked as a permanent failure is not queued and not sent: running it again
	 * cannot help. It stays open.
	 */
	@IsTest
	private static void shouldNotQueueAnIssueWhoseCallIsMarkedPermanent()
	{
		ApiCall__c originalCall = TST_Factory.newOutboundApiCall(SERVICE_NAME, UserInfo.getUserId(), PARAMETER_NAME, UTIL_Random.randomName());
		originalCall.Status__c = SEL_ApiCall.STATUS_FAILED;
		originalCall.IsPermanentFailure__c = true;
		insertCall(originalCall);
		Set<Id> issueIds = insertIssues(new List<ApiIssue__c> {TST_Factory.newApiIssue(originalCall, UTIL_Crypto.generateMD5Hash(originalCall.RequestParameters__c))});
		Integer callCountBefore = countCalls(SERVICE_NAME);

		CTRL_RetryApiIssue.DTO_ScheduledBulkRetry scheduledRetry = scheduleAs(getUserWithApiIssueResolverPermissionSet(), issueIds);

		Assert.areEqual(1, scheduledRetry.selectedCount, 'Expected the open issue to be counted as selected');
		Assert.areEqual(0, scheduledRetry.queuedCount, 'Expected the issue of a permanent failure not to be queued');
		Assert.areEqual(callCountBefore, countCalls(SERVICE_NAME), 'Expected no call');
		assertStatus(issueIds, SEL_ApiIssue.STATUS_OPEN);
	}

	/**
	 * @description A user without the Retry API Issue permission schedules nothing: no job, both counts zero, no call, and
	 * one warn at the entry naming the permission.
	 */
	@IsTest
	private static void shouldRefuseTheIdEntryToAUserWithoutThePermission()
	{
		LOG_Builder.ignoreTestMode = true;
		Set<Id> issueIds = insertIssues(new List<ApiIssue__c> {newOpenIssue()});
		Integer callCountBefore = countCalls(SERVICE_NAME);

		CTRL_RetryApiIssue.DTO_ScheduledBulkRetry scheduledRetry = scheduleAs(getUserWithoutRetryPermission(), issueIds);

		Assert.isNull(scheduledRetry.jobId, 'Expected no job for a user without the permission');
		Assert.areEqual(0, scheduledRetry.selectedCount, 'Expected nothing counted as selected');
		Assert.areEqual(0, scheduledRetry.queuedCount, 'Expected nothing queued');
		Assert.areEqual(callCountBefore, countCalls(SERVICE_NAME), 'Expected no call');
		assertStatus(issueIds, SEL_ApiIssue.STATUS_OPEN);
		LogEntry__c refusal = new SEL_LogEntry().findByMethod(ENTRY_LOG_LOCATION);
		Assert.isNotNull(refusal, 'Expected the refusal to be logged at the entry');
		Assert.isTrue
				(
						refusal.ShortMessage__c.contains(CTRL_RetryApiIssue.RETRY_API_ISSUE_CUSTOM_PERMISSION_NAME),
						'Expected the warning to name the permission, got ' + refusal.ShortMessage__c
				);
	}
}
