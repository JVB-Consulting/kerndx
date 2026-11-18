// SPDX-License-Identifier: Apache-2.0
/**
 * @description Unit tests for SEL_ApiIssue selector.
 *
 * @see SEL_ApiIssue
 *
 * @author Jason van Beukering
 *
 * @group Web Services
 *
 * @date February 2026, November 2026
 */
@IsTest(seeAllData=false isParallel=false)
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs,PMD.CognitiveComplexity,PMD.CyclomaticComplexity')
private class SEL_ApiIssue_TEST
{
	/**
	 * @description Company name discriminator for the committed test admin user set up in
	 * @TestSetup and retrieved via SEL_User.findByCompanyName.
	 */
	private static final String TEST_ADMIN_COMPANY = 'SEL_ApiIssue_TEST-admin';

	/**
	 * @description Company name discriminator for the committed low-privilege user (Minimum Access
	 * - Salesforce profile) set up in @TestSetup and used by the tier-A regression test.
	 */
	private static final String LOW_PRIVILEGE_COMPANY = 'SEL_ApiIssue_TEST-low-privilege';

	/**
	 * @description The row limit the finders by triggering record are given when the test is not about the limit.
	 */
	private static final Integer ROW_LIMIT = 10;

	/**
	 * @description The length of a record Id in its short form, which tells upper and lower case apart.
	 */
	private static final Integer SHORT_ID_LENGTH = 15;

	/**
	 * @description The number of record Ids in the large set that must still be read in one query.
	 */
	private static final Integer LARGE_SET_SIZE = 2000;

	/**
	 * @description The access level of a share that lets a user read a record.
	 */
	private static final String SHARE_ACCESS_READ = 'Read';

	/**
	 * @description The start of a reference from another system, stored as the triggering value of an issue.
	 */
	private static final String OTHER_SYSTEM_REFERENCE_PREFIX = 'ORD-';

	/**
	 * @description The number of random letters and digits after the start of a reference from another system.
	 */
	private static final Integer REFERENCE_RANDOM_LENGTH = 10;

	/**
	 * @description The number of random letters and digits after the start of a long reference from another system. The
	 * whole reference is then longer than the 18 characters of a record Id, and shorter than the 80 characters the
	 * Triggering Record Id field of an issue holds.
	 */
	private static final Integer LONG_REFERENCE_RANDOM_LENGTH = 30;

	/**
	 * @description The name of the trigger action that fills Triggering Record Index, so a test can skip it and save an
	 * issue with that field blank, as on an issue saved before the field existed.
	 */
	private static final String INDEX_ACTION_NAME = TRG_SetTriggeringRecordIndex.class.getName();

	/**
	 * @description Saves a test administrator and a low-privilege user once, before the tests run, so a test can run as
	 * either of them. A user cannot be saved in the same transaction as the test's other records (Salesforce refuses that
	 * mix with a MIXED_DML_OPERATION error), so the users are saved here, in a transaction of their own.
	 *
	 * shouldFindUnresolvedByServiceForLowPrivilegeUser and the tests that find another user's open issues
	 * (shouldFindAnotherUsersOpenIssueForTheSameRequest, shouldFindAnotherUsersOpenIssuesByApiCall,
	 * shouldFindAnotherUsersOpenOutboundIssuesByRequestParametersHash, shouldNotFindAnOpenIssueWithTheSameHashForAnotherRecord
	 * and shouldFindAnotherUsersOpenIssuesOfOneRequest) use the test administrator and the low-privilege user. The two
	 * finders by triggering record check the running user's access, so their tests run as follows. The tests that expect
	 * issues back run the finders as the test administrator. The tests that refuse a bad set or row limit, and the tests
	 * that run no query, call the finders as the user who runs the tests, because the finders stop before they read
	 * anything. The access tests run as a reader that the test inserts, except shouldThrowForAUserWithoutObjectRead, which
	 * runs as the low-privilege user. The other SEL_ApiIssue tests run as the user who runs the tests.
	 */
	@TestSetup
	private static void setupTestUsers()
	{
		TST_Factory.newUserWithPermissionSet
				(
						SEL_Profile.PROFILE_SYSTEM_ADMIN,
						TEST_ADMIN_COMPANY,
						SEL_PermissionSet.ADMIN_PERMISSION_SET_API_NAME
				);

		TST_Factory.insertUser(SEL_Profile.PROFILE_MINIMUM_ACCESS, LOW_PRIVILEGE_COMPANY);
	}

	/**
	 * @description Tests that findByFailedApiCall returns matching failed records.
	 */
	@IsTest
	private static void shouldFindByFailedApiCall()
	{
		Foobar__c record = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType).build();

		String serviceName = UTIL_Random.randomName();
		String hashParameter = UTIL_Crypto.generateMD5Hash(serviceName);

		TST_Builder.of(ApiIssue__c.SObjectType)
				.withOverride(ApiIssue__c.TriggeringRecordId__c, record.Id)
				.withOverride(ApiIssue__c.ServiceName__c, serviceName)
				.withOverride(ApiIssue__c.RequestParametersHash__c, hashParameter)
				.withOverride(ApiIssue__c.Status__c, SEL_ApiIssue.STATUS_OPEN)
				.build();

		List<ApiIssue__c> results = new SEL_ApiIssue().findByFailedApiCall(record.Id, serviceName, hashParameter);

		Assert.areEqual(1, results.size(), 'Should return the matching failure record');
	}

	/**
	 * @description Tests that getAll returns records within a test context.
	 */
	@IsTest
	private static void shouldGetAllInTestContext()
	{
		TST_Builder.of(ApiIssue__c.SObjectType)
				.withOverride(ApiIssue__c.Status__c, SEL_ApiIssue.STATUS_OPEN)
				.build();

		List<ApiIssue__c> results = new SEL_ApiIssue().getAll();

		Assert.isFalse(results.isEmpty(), 'Should return records in test context');
	}

	/**
	 * @description Tests that findUnresolvedByService returns matching open records.
	 */
	@IsTest
	private static void shouldFindUnresolvedByService()
	{
		String serviceName = UTIL_Random.randomName();

		TST_Builder.of(ApiIssue__c.SObjectType)
				.withOverride(ApiIssue__c.ServiceName__c, serviceName)
				.withOverride(ApiIssue__c.Status__c, SEL_ApiIssue.STATUS_OPEN)
				.build();

		List<ApiIssue__c> results = new SEL_ApiIssue().findUnresolvedByService(serviceName);

		Assert.areEqual(1, results.size(), 'Should return the matching unresolved record');
	}

	/**
	 * @description Tests that findUnresolvedByService returns empty for resolved records.
	 */
	@IsTest
	private static void shouldReturnEmptyWhenAllResolved()
	{
		String serviceName = UTIL_Random.randomName();

		TST_Builder.of(ApiIssue__c.SObjectType)
				.withOverride(ApiIssue__c.ServiceName__c, serviceName)
				.withOverride(ApiIssue__c.Status__c, SEL_ApiIssue.STATUS_RESOLVED)
				.build();

		List<ApiIssue__c> results = new SEL_ApiIssue().findUnresolvedByService(serviceName);

		Assert.isTrue(results.isEmpty(), 'Should return empty list when all records are resolved');
	}

	/**
	 * @description Tests that findUnresolvedInbound returns inbound failures.
	 */
	@IsTest
	private static void shouldFindUnresolvedInbound()
	{
		TST_Builder.of(ApiIssue__c.SObjectType)
				.withOverride(ApiIssue__c.Direction__c, SEL_ApiIssue.DIRECTION_INBOUND)
				.withOverride(ApiIssue__c.Status__c, SEL_ApiIssue.STATUS_OPEN)
				.build();

		List<ApiIssue__c> results = new SEL_ApiIssue().findUnresolvedInbound();

		Assert.areEqual(1, results.size(), 'Should return the inbound failure record');
	}

	/**
	 * @description Tests that findUnresolvedInbound excludes outbound failures.
	 */
	@IsTest
	private static void shouldExcludeOutboundFromInboundQuery()
	{
		TST_Builder.of(ApiIssue__c.SObjectType)
				.withOverride(ApiIssue__c.Direction__c, SEL_ApiIssue.DIRECTION_OUTBOUND)
				.withOverride(ApiIssue__c.Status__c, SEL_ApiIssue.STATUS_OPEN)
				.build();

		List<ApiIssue__c> results = new SEL_ApiIssue().findUnresolvedInbound();

		Assert.isTrue(results.isEmpty(), 'Should not return outbound failures');
	}

	/**
	 * @description Tier-A — proves SEL_ApiIssue.findUnresolvedByService
	 * returns rows when invoked by a subscriber user on the Minimum Access - Salesforce profile
	 * who has no FLS on kern__ApiIssue__c. The framework-owned selector declares
	 * `systemModeRequired() = true`, so its internal QRY_Builder must elevate to SYSTEM_MODE and
	 * the query must return the seeded rows regardless of the running user's FLS.
	 *
	 * The low-privilege user saves the issue, so they own it. API issues are private records, and this test is about field
	 * access, not about who may see another user's issue.
	 *
	 * Catches: a future refactor that demotes SEL_ApiIssue.systemModeRequired() to false, or
	 * deletes the override entirely, would cause the low-privilege user's query to fail with "No
	 * such column" under USER_MODE — this test fails at 2GP validated-build time rather than at
	 * subscriber scratch-org time.
	 *
	 * Note on method selection — T10's plan entry cites `findByItemHash(...)`; the selector does
	 * not expose that method. `findUnresolvedByService` covers the same elevation-via-
	 * systemModeRequired regression surface since both go through the shared SEL_Base.query
	 * property.
	 *
	 * @see SEL_ApiIssue.findUnresolvedByService
	 * @see SEL_ApiIssue.systemModeRequired
	 */
	@IsTest
	private static void shouldFindUnresolvedByServiceForLowPrivilegeUser()
	{
		final String serviceName = UTIL_Random.randomName();

		System.runAs(getLowPrivilegeUser())
		{
			TST_Builder.of(ApiIssue__c.SObjectType)
					.withOverride(ApiIssue__c.ServiceName__c, serviceName)
					.withOverride(ApiIssue__c.Status__c, SEL_ApiIssue.STATUS_OPEN)
					.build();

			List<ApiIssue__c> results = new SEL_ApiIssue().findUnresolvedByService(serviceName);

			Assert.areEqual(1, results.size(), 'Should find the seeded ApiIssue__c for low-privilege caller');
			Assert.areEqual(serviceName, results[0].ServiceName__c, 'ServiceName should match the seeded value');
		}
	}

	/**
	 * @description findByFailedApiCall returns an open issue for the request even when another user owns it and the
	 * reader cannot see it: whoever holds the record Id, the service name and the request parameters hash is asking about a
	 * request they know. The test administrator owns the issue, and a Minimum Access user reads it from a class declared
	 * with sharing, as the framework does when a later call for the same request succeeds. An issue for another request
	 * is not returned.
	 */
	@IsTest
	private static void shouldFindAnotherUsersOpenIssueForTheSameRequest()
	{
		Foobar__c record = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType).build();
		String serviceName = UTIL_Random.randomName();
		String hashParameter = UTIL_Crypto.generateMD5Hash(serviceName);
		ApiIssue__c seededIssue;
		System.runAs(getTestAdmin())
		{
			List<ApiIssue__c> issues = TST_Builder.of(ApiIssue__c.SObjectType)
					.withCount(2)
					.withOverrides(new Map<SObjectField, Object>
					{
							ApiIssue__c.TriggeringRecordId__c => record.Id,
							ApiIssue__c.ServiceName__c => serviceName,
							ApiIssue__c.Status__c => SEL_ApiIssue.STATUS_OPEN
					})
					.withCycle(ApiIssue__c.RequestParametersHash__c, new List<Object> {hashParameter, UTIL_Random.randomName()})
					.buildList();
			seededIssue = issues[0];
		}
		List<ApiIssue__c> results;

		System.runAs(getLowPrivilegeUser())
		{
			results = new SharingEnforcedReader().findByFailedApiCall(record.Id, serviceName, hashParameter);
		}

		Assert.areEqual(1, results.size(), 'Expected only the open issue for the same request');
		Assert.areEqual(seededIssue.Id, results[0].Id, 'Expected the issue another user owns');
	}

	/**
	 * @description findOpenByTriggeringRecordValue finds an open issue by the text of its Triggering Record Id field. Here
	 * the text is a long reference from another system.
	 *
	 * It finds the issue even when another user owns it and the reader cannot see it. The test administrator owns three
	 * issues of one service and request: an open one for the reference, an open one for another reference, and a resolved
	 * one for the same reference.
	 *
	 * A Minimum Access user reads from a class declared with sharing and gets only the first issue.
	 */
	@IsTest
	private static void shouldFindAnotherUsersOpenIssueByTheTextOfItsTriggeringRecord()
	{
		String reference = OTHER_SYSTEM_REFERENCE_PREFIX + UTIL_Random.randomAlphanumeric(LONG_REFERENCE_RANDOM_LENGTH);
		String otherReference = OTHER_SYSTEM_REFERENCE_PREFIX + UTIL_Random.randomAlphanumeric(LONG_REFERENCE_RANDOM_LENGTH);
		String serviceName = UTIL_Random.randomName();
		String hashParameter = UTIL_Crypto.generateMD5Hash(serviceName);
		List<ApiIssue__c> issues;
		System.runAs(getTestAdmin())
		{
			issues = TST_Builder.of(ApiIssue__c.SObjectType)
					.withCount(3)
					.withOverrides(new Map<SObjectField, Object>
					{
							ApiIssue__c.ServiceName__c => serviceName,
							ApiIssue__c.RequestParametersHash__c => hashParameter
					})
					.withCycle(ApiIssue__c.TriggeringRecordId__c, new List<Object> {reference, otherReference, reference})
					.withCycle(ApiIssue__c.Status__c, new List<Object> {SEL_ApiIssue.STATUS_OPEN, SEL_ApiIssue.STATUS_OPEN, SEL_ApiIssue.STATUS_RESOLVED})
					.buildList();
		}
		List<ApiIssue__c> results;

		System.runAs(getLowPrivilegeUser())
		{
			results = new SharingEnforcedReader().findOpenByTriggeringRecordValue(reference, serviceName, hashParameter);
		}

		Assert.areEqual(new List<Id> {issues[0].Id}, extractIdsInOrder(results), 'Expected only the open issue for the reference, got ' + results);
	}

	/**
	 * @description findOpenByTriggeringRecordValue matches upper and lower case exactly. The database ignores case when it
	 * compares text, so the finder must drop the other row itself.
	 *
	 * Two open issues of one service and request hold the same reference, one in upper case and one in lower case. The
	 * finder, given the upper-case reference, returns only the upper-case issue.
	 */
	@IsTest
	private static void shouldNotFindAnOpenIssueWhoseTriggeringRecordTextDiffersOnlyInCase()
	{
		String reference = (OTHER_SYSTEM_REFERENCE_PREFIX + UTIL_Random.randomAlphanumeric(LONG_REFERENCE_RANDOM_LENGTH)).toUpperCase();
		String lowerCaseReference = reference.toLowerCase();
		String serviceName = UTIL_Random.randomName();
		String hashParameter = UTIL_Crypto.generateMD5Hash(serviceName);
		List<ApiIssue__c> issues = insertTwoOpenIssues(serviceName, hashParameter, new List<Object> {reference, lowerCaseReference});

		List<ApiIssue__c> results = new SEL_ApiIssue().findOpenByTriggeringRecordValue(reference, serviceName, hashParameter);

		Assert.areEqual(new List<Id> {issues[0].Id}, extractIdsInOrder(results), 'Expected only the issue whose reference has the same case, got ' + results);
	}

	/**
	 * @description findOpenByTriggeringRecordValue, given no value, finds the open issue whose Triggering Record Id field
	 * is blank. A call with no Triggering Record ID resolves its issues this way.
	 *
	 * Two open issues of one service and request: one with the field blank and one that holds a reference. The finder
	 * returns only the blank one.
	 */
	@IsTest
	private static void shouldFindTheOpenIssueWithABlankTriggeringRecordWhenGivenNoValue()
	{
		String reference = OTHER_SYSTEM_REFERENCE_PREFIX + UTIL_Random.randomAlphanumeric(REFERENCE_RANDOM_LENGTH);
		String serviceName = UTIL_Random.randomName();
		String hashParameter = UTIL_Crypto.generateMD5Hash(serviceName);
		List<ApiIssue__c> issues = insertTwoOpenIssues(serviceName, hashParameter, new List<Object> {null, reference});

		List<ApiIssue__c> results = new SEL_ApiIssue().findOpenByTriggeringRecordValue(null, serviceName, hashParameter);

		Assert.areEqual(new List<Id> {issues[0].Id}, extractIdsInOrder(results), 'Expected only the issue with a blank Triggering Record Id, got ' + results);
	}

	/**
	 * @description findOpenByApiCalls returns the open issues of the given API calls, even when another user owns them
	 * and the reader cannot see them: the delete guard on API calls must see every open issue. The test administrator
	 * owns three calls: one with an open issue, one with only a resolved issue, and one with an open issue that is not
	 * asked about. A Minimum Access user reads from a class declared with sharing and gets only the open issue of the
	 * first call.
	 */
	@IsTest
	private static void shouldFindAnotherUsersOpenIssuesByApiCall()
	{
		List<ApiCall__c> apiCalls;
		List<ApiIssue__c> issues;
		System.runAs(getTestAdmin())
		{
			apiCalls = TST_Factory.getApiCallBuilder().withCount(3).buildList();
			issues = TST_Builder.of(ApiIssue__c.SObjectType)
					.withCount(3)
					.withCycle(ApiIssue__c.ApiCall__c, new List<Object> {apiCalls[0].Id, apiCalls[1].Id, apiCalls[2].Id})
					.withCycle(ApiIssue__c.Status__c, new List<Object> {SEL_ApiIssue.STATUS_OPEN, SEL_ApiIssue.STATUS_RESOLVED, SEL_ApiIssue.STATUS_OPEN})
					.buildList();
		}
		List<ApiIssue__c> results;

		System.runAs(getLowPrivilegeUser())
		{
			results = new SharingEnforcedReader().findOpenByApiCalls(new Set<Id> {apiCalls[0].Id, apiCalls[1].Id});
		}

		Assert.areEqual(1, results.size(), 'Expected only the open issue of the calls asked about');
		Assert.areEqual(issues[0].Id, results[0].Id, 'Expected the open issue another user owns');
	}

	/**
	 * @description findOpenOutboundByRequestParametersHashes returns the open outbound issues of the given services and
	 * request parameters hashes, even when another user owns them and the reader cannot see them: Retry Selected must see
	 * every open issue of a request before it sends it.
	 *
	 * The test administrator owns five issues of one service: an open outbound one with the hash, an open one with no
	 * direction and the hash, a resolved one with the hash, an open inbound one with the hash, and an open outbound one
	 * with another hash. A Minimum Access user reads from a class declared with sharing and gets only the first two.
	 */
	@IsTest
	private static void shouldFindAnotherUsersOpenOutboundIssuesByRequestParametersHash()
	{
		String serviceName = UTIL_Random.randomName();
		String hashParameter = UTIL_Crypto.generateMD5Hash(serviceName);
		List<ApiIssue__c> issues;
		System.runAs(getTestAdmin())
		{
			issues = TST_Builder.of(ApiIssue__c.SObjectType)
					.withCount(5)
					.withOverride(ApiIssue__c.ServiceName__c, serviceName)
					.withCycle(ApiIssue__c.Direction__c, new List<Object>
					{
							SEL_ApiIssue.DIRECTION_OUTBOUND, null, SEL_ApiIssue.DIRECTION_OUTBOUND, SEL_ApiIssue.DIRECTION_INBOUND, SEL_ApiIssue.DIRECTION_OUTBOUND
					})
					.withCycle(ApiIssue__c.Status__c, new List<Object>
					{
							SEL_ApiIssue.STATUS_OPEN, SEL_ApiIssue.STATUS_OPEN, SEL_ApiIssue.STATUS_RESOLVED, SEL_ApiIssue.STATUS_OPEN, SEL_ApiIssue.STATUS_OPEN
					})
					.withCycle(ApiIssue__c.RequestParametersHash__c, new List<Object>
					{
							hashParameter, hashParameter, hashParameter, hashParameter, UTIL_Crypto.generateMD5Hash(UTIL_Random.randomName())
					})
					.buildList();
		}
		Set<String> triggeringRecordValues = new Set<String>();
		for(ApiIssue__c issue : issues)
		{
			triggeringRecordValues.add(issue.TriggeringRecordId__c);
		}
		List<ApiIssue__c> results;

		System.runAs(getLowPrivilegeUser())
		{
			results = new SharingEnforcedReader().findOpenOutboundByRequestParametersHashes(new Set<String> {serviceName}, new Set<String> {hashParameter}, triggeringRecordValues);
		}

		Set<Id> expectedIds = new Set<Id> {issues[0].Id, issues[1].Id};
		Assert.areEqual(expectedIds, UTIL_SObject.extractIds(results), 'Expected only the two open outbound issues with the hash, got ' + results);
	}

	/**
	 * @description findOpenOutboundByRequestParametersHashes, given triggering record IDs, returns only the open issues of
	 * those records. Two records can be sent to one service with the same parameters, so their issues share a hash, but
	 * they are different requests.
	 *
	 * The test administrator owns three open outbound issues of one service, all with the same hash: one for the first
	 * record, one for a second record, and one with no record.
	 *
	 * A Minimum Access user reads for the first record only, from a class declared with sharing, and gets only the first
	 * issue. An issue with no record does not match a list of records.
	 */
	@IsTest
	private static void shouldNotFindAnOpenIssueWithTheSameHashForAnotherRecord()
	{
		String serviceName = UTIL_Random.randomName();
		String hashParameter = UTIL_Crypto.generateMD5Hash(serviceName);
		String firstRecordValue = UTIL_Random.randomName();
		List<ApiIssue__c> issues;
		System.runAs(getTestAdmin())
		{
			issues = TST_Builder.of(ApiIssue__c.SObjectType)
					.withCount(3)
					.withOverride(ApiIssue__c.ServiceName__c, serviceName)
					.withOverride(ApiIssue__c.Direction__c, SEL_ApiIssue.DIRECTION_OUTBOUND)
					.withOverride(ApiIssue__c.Status__c, SEL_ApiIssue.STATUS_OPEN)
					.withOverride(ApiIssue__c.RequestParametersHash__c, hashParameter)
					.withCycle(ApiIssue__c.TriggeringRecordId__c, new List<Object> {firstRecordValue, UTIL_Random.randomName(), null})
					.buildList();
		}
		List<ApiIssue__c> results;

		System.runAs(getLowPrivilegeUser())
		{
			results = new SharingEnforcedReader().findOpenOutboundByRequestParametersHashes(
					new Set<String> {serviceName}, new Set<String> {hashParameter}, new Set<String> {firstRecordValue}
			);
		}

		Assert.areEqual(new Set<Id> {issues[0].Id}, UTIL_SObject.extractIds(results), 'Expected only the open issue of the first record, got ' + results);
	}

	/**
	 * @description findOpenByIdempotencyKey returns the open issues of one request, whoever owns them: the issues whose call
	 * the sender sent to the service with the key and that did not complete, and the issue of a call another user made
	 * when running the sender's request again (it links to the sender's call). The test administrator sends the calls,
	 * and a Minimum Access user reads from a class declared with sharing. Left out: a resolved issue, and the issues of a
	 * call with another key, of a call that completed, and of a call another user sent with the same key.
	 */
	@IsTest
	private static void shouldFindAnotherUsersOpenIssuesOfOneRequest()
	{
		String serviceName = UTIL_Random.randomName();
		String idempotencyKey = UTIL_Random.randomUUID();
		User sender = getTestAdmin();
		List<ApiCall__c> senderCalls;
		System.runAs(sender)
		{
			senderCalls = TST_Factory.getApiCallBuilder()
					.withCount(4)
					.withOverride(ApiCall__c.ServiceName__c, serviceName)
					.withCycle(ApiCall__c.IdempotencyKey__c, new List<Object> {idempotencyKey, idempotencyKey, UTIL_Random.randomUUID(), idempotencyKey})
					.withCycle(ApiCall__c.Status__c, new List<Object>
					{
							SEL_ApiCall.STATUS_FAILED, SEL_ApiCall.STATUS_FAILED, SEL_ApiCall.STATUS_FAILED, SEL_ApiCall.STATUS_COMPLETED
					})
					.buildList();
		}
		Map<SObjectField, Object> sameRequestFields = new Map<SObjectField, Object>
		{
				ApiCall__c.ServiceName__c => serviceName,
				ApiCall__c.IdempotencyKey__c => idempotencyKey,
				ApiCall__c.Status__c => SEL_ApiCall.STATUS_FAILED
		};
		ApiCall__c rerunCall = (ApiCall__c)TST_Factory.getApiCallBuilder()
				.withOverrides(sameRequestFields)
				.withOverride(ApiCall__c.PreviousAttempt__c, senderCalls[0].Id)
				.build();
		ApiCall__c otherSenderCall = (ApiCall__c)TST_Factory.getApiCallBuilder().withOverrides(sameRequestFields).build();
		List<ApiIssue__c> issues = TST_Builder.of(ApiIssue__c.SObjectType)
				.withCount(6)
				.withCycle(ApiIssue__c.ApiCall__c, new List<Object>
				{
						senderCalls[0].Id, senderCalls[1].Id, senderCalls[2].Id, senderCalls[3].Id, rerunCall.Id, otherSenderCall.Id
				})
				.withCycle(ApiIssue__c.Status__c, new List<Object>
				{
						SEL_ApiIssue.STATUS_OPEN, SEL_ApiIssue.STATUS_RESOLVED, SEL_ApiIssue.STATUS_OPEN,
						SEL_ApiIssue.STATUS_OPEN, SEL_ApiIssue.STATUS_OPEN, SEL_ApiIssue.STATUS_OPEN
				})
				.buildList();
		List<ApiIssue__c> results;

		System.runAs(getLowPrivilegeUser())
		{
			results = new SharingEnforcedReader().findOpenByIdempotencyKey(serviceName, idempotencyKey, sender.Id);
		}

		Set<Id> expectedIds = new Set<Id> {issues[0].Id, issues[4].Id};
		Assert.areEqual(expectedIds, UTIL_SObject.extractIds(results), 'Expected the open issues of the sender\'s call and of the run by another user');
	}

	/**
	 * @description The read the framework uses when a later call for the same request succeeds still finds an open issue
	 * whose Triggering Record Index is blank, as on an issue saved before the field existed. The new finder by record Ids
	 * does not find that issue, which shows the field really is blank.
	 *
	 * @see SEL_ApiIssue.findByFailedApiCall
	 */
	@SuppressWarnings('PMD.KernSecurityBypassCallSite')
	@IsTest
	private static void shouldFindAnOpenIssueWhoseIndexFieldIsBlank()
	{
		Id triggeringRecordId = UTIL_Random.randomId(Foobar__c.SObjectType);
		String serviceName = UTIL_Random.randomName();
		String hashParameter = UTIL_Crypto.generateMD5Hash(serviceName);
		TRG_Base.bypassAction(INDEX_ACTION_NAME);
		ApiIssue__c seededIssue = (ApiIssue__c)TST_Builder.of(ApiIssue__c.SObjectType)
				.withOverrides(new Map<SObjectField, Object>
				{
						ApiIssue__c.TriggeringRecordId__c => triggeringRecordId,
						ApiIssue__c.ServiceName__c => serviceName,
						ApiIssue__c.RequestParametersHash__c => hashParameter,
						ApiIssue__c.Status__c => SEL_ApiIssue.STATUS_OPEN
				})
				.build();

		List<ApiIssue__c> foundIssues = new SEL_ApiIssue().findByFailedApiCall(triggeringRecordId, serviceName, hashParameter);
		List<ApiIssue__c> issuesFoundByIds = findByIdsAsAdministrator(new Set<Id> {triggeringRecordId}, ROW_LIMIT);

		Assert.areEqual(new List<Id> {seededIssue.Id}, extractIdsInOrder(foundIssues), 'Expected the open issue, got ' + foundIssues);
		Assert.isTrue(issuesFoundByIds.isEmpty(), 'Expected the finder by Ids to find no issue, because Triggering Record Index was left blank, got '
				+ issuesFoundByIds);
	}

	/**
	 * @description Both finders return the newest issues first. Two issues saved at the same moment come in the order of
	 * their own Id, highest first, and an older issue comes after them even though its Id is the highest.
	 *
	 * @see SEL_ApiIssue.findByTriggeringRecordIds
	 * @see SEL_ApiIssue.findByTriggeringRecordValues
	 */
	@IsTest
	private static void shouldReturnRowsNewestFirstWithIdBreakingTies()
	{
		Id triggeringRecordId = UTIL_Random.randomId(Foobar__c.SObjectType);
		List<ApiIssue__c> seededIssues = seedIssuesFor(triggeringRecordId, 3);
		Datetime savedAt = Datetime.now().addHours(-1);
		Test.setCreatedDate(seededIssues[0].Id, savedAt);
		Test.setCreatedDate(seededIssues[1].Id, savedAt);
		Test.setCreatedDate(seededIssues[2].Id, savedAt.addDays(-1));
		List<Id> expectedOrder = new List<Id> {seededIssues[1].Id, seededIssues[0].Id, seededIssues[2].Id};

		List<ApiIssue__c> issuesFoundById = findByIdsAsAdministrator(new Set<Id> {triggeringRecordId}, ROW_LIMIT);
		List<ApiIssue__c> issuesFoundByValue = findByValuesAsAdministrator(new Set<String> {triggeringRecordId}, ROW_LIMIT);

		Assert.areEqual(expectedOrder, extractIdsInOrder(issuesFoundById), 'Expected the newest issues first, the higher Id first on a tie');
		Assert.areEqual(expectedOrder, extractIdsInOrder(issuesFoundByValue), 'Expected the newest issues first, the higher Id first on a tie');
	}

	/**
	 * @description Both finders return no more issues than the row limit.
	 *
	 * @see SEL_ApiIssue.findByTriggeringRecordIds
	 * @see SEL_ApiIssue.findByTriggeringRecordValues
	 */
	@IsTest
	private static void shouldStopAtTheRowLimit()
	{
		Id triggeringRecordId = UTIL_Random.randomId(Foobar__c.SObjectType);
		seedIssuesFor(triggeringRecordId, 3);
		Integer rowLimit = 2;

		List<ApiIssue__c> issuesFoundById = findByIdsAsAdministrator(new Set<Id> {triggeringRecordId}, rowLimit);
		List<ApiIssue__c> issuesFoundByValue = findByValuesAsAdministrator(new Set<String> {triggeringRecordId}, rowLimit);

		Assert.areEqual(rowLimit, issuesFoundById.size(), 'Expected the finder by Ids to stop at the row limit, got ' + issuesFoundById);
		Assert.areEqual(rowLimit, issuesFoundByValue.size(), 'Expected the finder by values to stop at the row limit, got ' + issuesFoundByValue);
	}

	/**
	 * @description Both finders return an empty list for an empty set, and run no query.
	 *
	 * @see SEL_ApiIssue.findByTriggeringRecordIds
	 * @see SEL_ApiIssue.findByTriggeringRecordValues
	 */
	@IsTest
	private static void shouldReturnAnEmptyListAndIssueNoQueryForAnEmptySet()
	{
		Integer queriesBefore = UTIL_Limits.soqlQueries().used();

		List<ApiIssue__c> issuesFoundById = new SEL_ApiIssue().findByTriggeringRecordIds(new Set<Id>(), ROW_LIMIT);
		List<ApiIssue__c> issuesFoundByValue = new SEL_ApiIssue().findByTriggeringRecordValues(new Set<String>(), ROW_LIMIT);

		Assert.areEqual(queriesBefore, UTIL_Limits.soqlQueries().used(), 'Expected no query for an empty set');
		Assert.isTrue(issuesFoundById.isEmpty(), 'Expected an empty list from the finder by Ids, got ' + issuesFoundById);
		Assert.isTrue(issuesFoundByValue.isEmpty(), 'Expected an empty list from the finder by values, got ' + issuesFoundByValue);
	}

	/**
	 * @description Both finders return an empty list, and run no query, for a set that holds only null, or for the finder
	 * by values only null and blank values.
	 *
	 * @see SEL_ApiIssue.findByTriggeringRecordIds
	 * @see SEL_ApiIssue.findByTriggeringRecordValues
	 */
	@IsTest
	private static void shouldReturnAnEmptyListAndIssueNoQueryForASetHoldingOnlyNull()
	{
		Integer queriesBefore = UTIL_Limits.soqlQueries().used();

		List<ApiIssue__c> issuesFoundById = new SEL_ApiIssue().findByTriggeringRecordIds(new Set<Id> {null}, ROW_LIMIT);
		List<ApiIssue__c> issuesFoundByValue = new SEL_ApiIssue().findByTriggeringRecordValues(new Set<String> {null, UTIL_String.EMPTY, UTIL_String.SPACE}, ROW_LIMIT);

		Assert.areEqual(queriesBefore, UTIL_Limits.soqlQueries().used(), 'Expected no query for a set with nothing to look for');
		Assert.isTrue(issuesFoundById.isEmpty(), 'Expected an empty list from the finder by Ids, got ' + issuesFoundById);
		Assert.isTrue(issuesFoundByValue.isEmpty(), 'Expected an empty list from the finder by values, got ' + issuesFoundByValue);
	}

	/**
	 * @description Both finders leave the set they are given as it was, null and blank values included, and still find
	 * the issue for the value in it.
	 *
	 * @see SEL_ApiIssue.findByTriggeringRecordIds
	 * @see SEL_ApiIssue.findByTriggeringRecordValues
	 */
	@IsTest
	private static void shouldNotChangeTheCallersSet()
	{
		Id triggeringRecordId = UTIL_Random.randomId(Foobar__c.SObjectType);
		ApiIssue__c seededIssue = seedIssuesFor(triggeringRecordId, 1)[0];
		Set<Id> recordIds = new Set<Id> {triggeringRecordId, null};
		Set<String> values = new Set<String> {triggeringRecordId, null, UTIL_String.EMPTY};

		List<ApiIssue__c> issuesFoundById = findByIdsAsAdministrator(recordIds, ROW_LIMIT);
		List<ApiIssue__c> issuesFoundByValue = findByValuesAsAdministrator(values, ROW_LIMIT);

		Assert.areEqual(new Set<Id> {triggeringRecordId, null}, recordIds, 'Expected the set of Ids to be unchanged');
		Assert.areEqual(new Set<String> {triggeringRecordId, null, UTIL_String.EMPTY}, values, 'Expected the set of values to be unchanged');
		Assert.areEqual(new List<Id> {seededIssue.Id}, extractIdsInOrder(issuesFoundById), 'Expected the issue by Id, got ' + issuesFoundById);
		Assert.areEqual(new List<Id> {seededIssue.Id}, extractIdsInOrder(issuesFoundByValue), 'Expected the issue by value, got ' + issuesFoundByValue);
	}

	/**
	 * @description Both finders refuse a null set with an IllegalArgumentException.
	 *
	 * @see SEL_ApiIssue.findByTriggeringRecordIds
	 * @see SEL_ApiIssue.findByTriggeringRecordValues
	 */
	@IsTest
	private static void shouldRefuseANullSet()
	{
		try
		{
			new SEL_ApiIssue().findByTriggeringRecordIds(null, ROW_LIMIT);
			Assert.fail('Expected the finder by Ids to refuse a null set');
		}
		catch(Exception error)
		{
			Assert.isInstanceOfType(error, IllegalArgumentException.class, 'Expected an IllegalArgumentException, got ' + error);
		}
		try
		{
			new SEL_ApiIssue().findByTriggeringRecordValues(null, ROW_LIMIT);
			Assert.fail('Expected the finder by values to refuse a null set');
		}
		catch(Exception error)
		{
			Assert.isInstanceOfType(error, IllegalArgumentException.class, 'Expected an IllegalArgumentException, got ' + error);
		}
	}

	/**
	 * @description Both finders refuse a row limit that is null, 0 or negative with an IllegalArgumentException, even
	 * when the set holds nothing to look for.
	 *
	 * @see SEL_ApiIssue.findByTriggeringRecordIds
	 * @see SEL_ApiIssue.findByTriggeringRecordValues
	 */
	@IsTest
	private static void shouldRefuseARowLimitBelowOne()
	{
		for(Integer rowLimit : new List<Integer> {null, 0, -1})
		{
			try
			{
				new SEL_ApiIssue().findByTriggeringRecordIds(new Set<Id>(), rowLimit);
				Assert.fail('Expected the finder by Ids to refuse the row limit ' + rowLimit);
			}
			catch(Exception error)
			{
				Assert.isInstanceOfType(error, IllegalArgumentException.class, 'Expected an IllegalArgumentException, got ' + error);
			}
			try
			{
				new SEL_ApiIssue().findByTriggeringRecordValues(new Set<String>(), rowLimit);
				Assert.fail('Expected the finder by values to refuse the row limit ' + rowLimit);
			}
			catch(Exception error)
			{
				Assert.isInstanceOfType(error, IllegalArgumentException.class, 'Expected an IllegalArgumentException, got ' + error);
			}
		}
	}

	/**
	 * @description Both finders return only the summary fields: the Id, the service name, the status, the created date
	 * and Triggering Record Index. The request body and the request parameters are not read, even when the issue holds them.
	 *
	 * @see SEL_ApiIssue.findByTriggeringRecordIds
	 * @see SEL_ApiIssue.findByTriggeringRecordValues
	 */
	@IsTest
	private static void shouldReturnOnlySummaryFields()
	{
		Id triggeringRecordId = UTIL_Random.randomId(Foobar__c.SObjectType);
		TST_Builder.of(ApiIssue__c.SObjectType)
				.withOverrides(new Map<SObjectField, Object>
				{
						ApiIssue__c.TriggeringRecordId__c => triggeringRecordId,
						ApiIssue__c.ServiceName__c => UTIL_Random.randomName(),
						ApiIssue__c.Status__c => SEL_ApiIssue.STATUS_OPEN,
						ApiIssue__c.RequestBody__c => UTIL_Random.randomName(),
						ApiIssue__c.RequestParameters__c => UTIL_Random.randomName()
				})
				.build();

		List<ApiIssue__c> foundIssues = findByIdsAsAdministrator(new Set<Id> {triggeringRecordId}, ROW_LIMIT);
		foundIssues.addAll(findByValuesAsAdministrator(new Set<String> {triggeringRecordId}, ROW_LIMIT));

		Assert.areEqual(2, foundIssues.size(), 'Expected the issue once from each finder, got ' + foundIssues);
		List<SObjectField> summaryFields = new List<SObjectField>
		{
				ApiIssue__c.Id, ApiIssue__c.ServiceName__c, ApiIssue__c.Status__c, ApiIssue__c.CreatedDate, ApiIssue__c.TriggeringRecordIndex__c
		};
		for(ApiIssue__c foundIssue : foundIssues)
		{
			Map<String, Object> populatedFields = foundIssue.getPopulatedFieldsAsMap();
			Assert.areEqual(summaryFields.size(), populatedFields.size(), 'Expected only the summary fields, got ' + populatedFields.keySet());
			for(SObjectField summaryField : summaryFields)
			{
				Assert.isTrue(foundIssue.isSet(summaryField), 'Expected the summary field to be read: ' + summaryField);
			}
			Assert.isFalse(foundIssue.isSet(ApiIssue__c.RequestBody__c), 'Expected the request body not to be read');
			Assert.isFalse(foundIssue.isSet(ApiIssue__c.RequestParameters__c), 'Expected the request parameters not to be read');
		}
	}

	/**
	 * @description A user who may read issues and their summary fields, but to whom record sharing gives no access to an
	 * issue another user owns, gets no issue from either finder.
	 *
	 * @see SEL_ApiIssue.findByTriggeringRecordIds
	 * @see SEL_ApiIssue.findByTriggeringRecordValues
	 */
	@IsTest
	private static void shouldHideARowFromAUserWithoutSharing()
	{
		Id triggeringRecordId = UTIL_Random.randomId(Foobar__c.SObjectType);
		seedIssuesFor(triggeringRecordId, 1);
		User reader = insertReaderWithHiddenField(ApiIssue__c.RequestBody__c);

		List<ApiIssue__c> issuesFoundById = findByIdsAsUser(reader, new Set<Id> {triggeringRecordId}, ROW_LIMIT);
		List<ApiIssue__c> issuesFoundByValue = findByValuesAsUser(reader, new Set<String> {triggeringRecordId}, ROW_LIMIT);

		Assert.isTrue(issuesFoundById.isEmpty(), 'Expected sharing to hide the issue from the finder by Ids, got ' + issuesFoundById);
		Assert.isTrue(issuesFoundByValue.isEmpty(), 'Expected sharing to hide the issue from the finder by values, got ' + issuesFoundByValue);
	}

	/**
	 * @description A user who may read issues and their summary fields gets an issue another user owns once that issue is
	 * shared with them, from both finders.
	 *
	 * @see SEL_ApiIssue.findByTriggeringRecordIds
	 * @see SEL_ApiIssue.findByTriggeringRecordValues
	 */
	@IsTest
	private static void shouldReturnARowToAUserItIsSharedWith()
	{
		Id triggeringRecordId = UTIL_Random.randomId(Foobar__c.SObjectType);
		ApiIssue__c seededIssue = seedIssuesFor(triggeringRecordId, 1)[0];
		User reader = insertReaderWithHiddenField(ApiIssue__c.RequestBody__c);
		DML_Builder.newTransaction().doInsert(TST_Factory.newSObjectShare(seededIssue.Id, SHARE_ACCESS_READ, reader.Id)).execute();

		List<ApiIssue__c> issuesFoundById = findByIdsAsUser(reader, new Set<Id> {triggeringRecordId}, ROW_LIMIT);
		List<ApiIssue__c> issuesFoundByValue = findByValuesAsUser(reader, new Set<String> {triggeringRecordId}, ROW_LIMIT);

		Assert.areEqual(new List<Id> {seededIssue.Id}, extractIdsInOrder(issuesFoundById), 'Expected the shared issue by Id, got ' + issuesFoundById);
		Assert.areEqual(new List<Id> {seededIssue.Id}, extractIdsInOrder(issuesFoundByValue), 'Expected the shared issue by value, got ' + issuesFoundByValue);
	}

	/**
	 * @description Both finders fail with a QueryException for a user who may read issues but not their Triggering Record Index field. This
	 * proves the finders read with the user's field access (user mode): the selector's other reads skip that check.
	 *
	 * @see SEL_ApiIssue.findByTriggeringRecordIds
	 * @see SEL_ApiIssue.findByTriggeringRecordValues
	 */
	@IsTest
	private static void shouldThrowForAUserWithoutFieldRead()
	{
		Id triggeringRecordId = UTIL_Random.randomId(Foobar__c.SObjectType);
		User reader = insertReaderWithHiddenField(ApiIssue__c.TriggeringRecordIndex__c);

		System.runAs(reader)
		{
			try
			{
				new SEL_ApiIssue().findByTriggeringRecordIds(new Set<Id> {triggeringRecordId}, ROW_LIMIT);
				Assert.fail('Expected the finder by Ids to fail for a user who cannot read Triggering Record Index');
			}
			catch(Exception error)
			{
				Assert.isInstanceOfType(error, QueryException.class, 'Expected a QueryException, got ' + error);
			}
			try
			{
				new SEL_ApiIssue().findByTriggeringRecordValues(new Set<String> {triggeringRecordId}, ROW_LIMIT);
				Assert.fail('Expected the finder by values to fail for a user who cannot read Triggering Record Index');
			}
			catch(Exception error)
			{
				Assert.isInstanceOfType(error, QueryException.class, 'Expected a QueryException, got ' + error);
			}
		}
	}

	/**
	 * @description Both finders fail with a QueryException for a user who may not read issues at all.
	 *
	 * @see SEL_ApiIssue.findByTriggeringRecordIds
	 * @see SEL_ApiIssue.findByTriggeringRecordValues
	 */
	@IsTest
	private static void shouldThrowForAUserWithoutObjectRead()
	{
		Id triggeringRecordId = UTIL_Random.randomId(Foobar__c.SObjectType);

		System.runAs(getLowPrivilegeUser())
		{
			try
			{
				new SEL_ApiIssue().findByTriggeringRecordIds(new Set<Id> {triggeringRecordId}, ROW_LIMIT);
				Assert.fail('Expected the finder by Ids to fail for a user who cannot read issues');
			}
			catch(Exception error)
			{
				Assert.isInstanceOfType(error, QueryException.class, 'Expected a QueryException, got ' + error);
			}
			try
			{
				new SEL_ApiIssue().findByTriggeringRecordValues(new Set<String> {triggeringRecordId}, ROW_LIMIT);
				Assert.fail('Expected the finder by values to fail for a user who cannot read issues');
			}
			catch(Exception error)
			{
				Assert.isInstanceOfType(error, QueryException.class, 'Expected a QueryException, got ' + error);
			}
		}
	}

	/**
	 * @description Both finders read a set of 2,000 values in one query and find the issue among them.
	 *
	 * @see SEL_ApiIssue.findByTriggeringRecordIds
	 * @see SEL_ApiIssue.findByTriggeringRecordValues
	 */
	@IsTest
	private static void shouldAcceptTwoThousandIds()
	{
		Id triggeringRecordId = UTIL_Random.randomId(Foobar__c.SObjectType);
		ApiIssue__c seededIssue = seedIssuesFor(triggeringRecordId, 1)[0];
		Set<Id> recordIds = new Set<Id> {triggeringRecordId};
		while(recordIds.size() < LARGE_SET_SIZE)
		{
			recordIds.add(UTIL_Random.randomId(Foobar__c.SObjectType));
		}
		Set<String> values = new Set<String>((List<String>)new List<Id>(recordIds));
		List<ApiIssue__c> issuesFoundById;
		List<ApiIssue__c> issuesFoundByValue;
		Integer queriesById;
		Integer queriesByValue;

		System.runAs(getTestAdmin())
		{
			Integer queriesBefore = UTIL_Limits.soqlQueries().used();
			issuesFoundById = new SEL_ApiIssue().findByTriggeringRecordIds(recordIds, ROW_LIMIT);
			queriesById = UTIL_Limits.soqlQueries().used() - queriesBefore;
			issuesFoundByValue = new SEL_ApiIssue().findByTriggeringRecordValues(values, ROW_LIMIT);
			queriesByValue = UTIL_Limits.soqlQueries().used() - queriesBefore - queriesById;
		}

		Assert.areEqual(1, queriesById, 'Expected the finder by Ids to run one query');
		Assert.areEqual(1, queriesByValue, 'Expected the finder by values to run one query');
		Assert.areEqual(new List<Id> {seededIssue.Id}, extractIdsInOrder(issuesFoundById), 'Expected the issue by Id, got ' + issuesFoundById);
		Assert.areEqual(new List<Id> {seededIssue.Id}, extractIdsInOrder(issuesFoundByValue), 'Expected the issue by value, got ' + issuesFoundByValue);
	}

	/**
	 * @description In a test, both finders filter the mocked issues the way the query does: only a mock whose Triggering
	 * Record Index holds a searched value comes back. A mock with a blank index, with another record's Id, or with the
	 * searched value in another case is left out.
	 *
	 * @see SEL_ApiIssue.findByTriggeringRecordIds
	 * @see SEL_ApiIssue.findByTriggeringRecordValues
	 */
	@IsTest
	private static void shouldReturnOnlyMockedRowsWithAMatchingIndex()
	{
		Id triggeringRecordId = UTIL_Random.randomId(Foobar__c.SObjectType);
		String searchedValue = String.valueOf(triggeringRecordId);
		String valueInAnotherCase = searchedValue.toLowerCase().equals(searchedValue) ? searchedValue.toUpperCase() : searchedValue.toLowerCase();
		Assert.areNotEqual(searchedValue, valueInAnotherCase, 'Expected the searched value to hold a letter, so it has another case');
		ApiIssue__c matchingMock = (ApiIssue__c)TST_Mock.of(ApiIssue__c.SObjectType)
				.withOverride(ApiIssue__c.TriggeringRecordIndex__c, String.valueOf(triggeringRecordId))
				.build();
		TST_Mock.of(ApiIssue__c.SObjectType)
				.withOverride(ApiIssue__c.TriggeringRecordIndex__c, String.valueOf(UTIL_Random.randomId(Foobar__c.SObjectType)))
				.build();
		TST_Mock.of(ApiIssue__c.SObjectType).withOverride(ApiIssue__c.TriggeringRecordIndex__c, null).build();
		TST_Mock.of(ApiIssue__c.SObjectType)
				.withOverride(ApiIssue__c.TriggeringRecordIndex__c, valueInAnotherCase)
				.build();
		Set<Id> expectedIds = new Set<Id> {matchingMock.Id};

		List<ApiIssue__c> issuesFoundById = findByIdsAsAdministrator(new Set<Id> {triggeringRecordId}, ROW_LIMIT);
		List<ApiIssue__c> issuesFoundByValue = findByValuesAsAdministrator(new Set<String> {triggeringRecordId}, ROW_LIMIT);

		Assert.areEqual(expectedIds, new Set<Id>(extractIdsInOrder(issuesFoundById)), 'Expected only the matching mock by Id, got ' + issuesFoundById);
		Assert.areEqual(expectedIds, new Set<Id>(extractIdsInOrder(issuesFoundByValue)), 'Expected only the matching mock by value, got ' + issuesFoundByValue);
	}

	/**
	 * @description In a test, the finder of the issues of a failed call checks the status of the mocked issues the way the
	 * query does, though Status is a picklist field: of three mocked issues of one call, it returns only the open one, not
	 * the two that are resolved.
	 *
	 * @see SEL_ApiIssue.findByFailedApiCall
	 */
	@IsTest
	private static void shouldReturnOnlyTheOpenMockedIssuesOfAFailedCall()
	{
		Id triggeringRecordId = UTIL_Random.randomId(Foobar__c.SObjectType);
		String serviceName = UTIL_Random.randomName();
		String hashParameter = UTIL_Crypto.generateMD5Hash(serviceName);
		List<String> statuses = new List<String> {SEL_ApiIssue.STATUS_RESOLVED, SEL_ApiIssue.STATUS_OPEN, SEL_ApiIssue.STATUS_RESOLVED};
		List<ApiIssue__c> mockedIssues = new List<ApiIssue__c>();
		for(String status : statuses)
		{
			mockedIssues.add((ApiIssue__c)TST_Mock.of(ApiIssue__c.SObjectType)
					.withOverride(ApiIssue__c.TriggeringRecordId__c, String.valueOf(triggeringRecordId))
					.withOverride(ApiIssue__c.ServiceName__c, serviceName)
					.withOverride(ApiIssue__c.RequestParametersHash__c, hashParameter)
					.withOverride(ApiIssue__c.Status__c, status)
					.build());
		}

		List<ApiIssue__c> foundIssues = new SEL_ApiIssue().findByFailedApiCall(triggeringRecordId, serviceName, hashParameter);

		Assert.areEqual(new List<Id> {mockedIssues[1].Id}, extractIdsInOrder(foundIssues), 'Expected only the open mocked issue, got ' + foundIssues);
	}

	/**
	 * @description In a test, TST_Mock.registerNext decides what each finder returns: the finder returns exactly the
	 * scripted issues. This is how a test of code that calls a finder chooses the issues it gets.
	 *
	 * @see SEL_ApiIssue.findByTriggeringRecordIds
	 * @see SEL_ApiIssue.findByTriggeringRecordValues
	 */
	@IsTest
	private static void shouldReturnTheAnswerScriptedWithRegisterNext()
	{
		Id triggeringRecordId = UTIL_Random.randomId(Foobar__c.SObjectType);
		ApiIssue__c scriptedIssue = (ApiIssue__c)TST_Builder.of(ApiIssue__c.SObjectType)
				.withOverride(ApiIssue__c.TriggeringRecordIndex__c, String.valueOf(triggeringRecordId))
				.withoutInsertion(true)
				.build();
		List<Id> scriptedIds = new List<Id> {scriptedIssue.Id};

		TST_Mock.registerNext(ApiIssue__c.SObjectType, scriptedIssue);
		List<ApiIssue__c> issuesFoundById = findByIdsAsAdministrator(new Set<Id> {triggeringRecordId}, ROW_LIMIT);
		TST_Mock.registerNext(ApiIssue__c.SObjectType, scriptedIssue);
		List<ApiIssue__c> issuesFoundByValue = findByValuesAsAdministrator(new Set<String> {triggeringRecordId}, ROW_LIMIT);

		Assert.areEqual(scriptedIds, extractIdsInOrder(issuesFoundById), 'Expected the scripted issue by Id, got ' + issuesFoundById);
		Assert.areEqual(scriptedIds, extractIdsInOrder(issuesFoundByValue), 'Expected the scripted issue by value, got ' + issuesFoundByValue);
	}

	/**
	 * @description The finder by Ids searches only the full form of 18 characters, so it does not find an issue whose
	 * triggering record Id was written in the short form of 15 characters.
	 *
	 * @see SEL_ApiIssue.findByTriggeringRecordIds
	 */
	@IsTest
	private static void shouldNotFindAValueStoredInTheFifteenCharacterForm()
	{
		Id triggeringRecordId = UTIL_Random.randomId(Foobar__c.SObjectType);
		seedIssuesFor(String.valueOf(triggeringRecordId).left(SHORT_ID_LENGTH), 1);

		List<ApiIssue__c> foundIssues = findByIdsAsAdministrator(new Set<Id> {triggeringRecordId}, ROW_LIMIT);

		Assert.isTrue(foundIssues.isEmpty(), 'Expected no issue stored with the short form, got ' + foundIssues);
	}

	/**
	 * @description The finder by values matches any text, so it also finds an issue whose triggering record Id was written
	 * in the short form of 15 characters when given that text. This only records how the finder behaves: it is not the
	 * way to search by record Id, because its match ignores case.
	 *
	 * @see SEL_ApiIssue.findByTriggeringRecordValues
	 */
	@IsTest
	private static void shouldFindAFifteenCharacterValueThroughTheTextFinder()
	{
		String shortForm = String.valueOf(UTIL_Random.randomId(Foobar__c.SObjectType)).left(SHORT_ID_LENGTH);
		ApiIssue__c seededIssue = seedIssuesFor(shortForm, 1)[0];

		List<ApiIssue__c> foundIssues = findByValuesAsAdministrator(new Set<String> {shortForm}, ROW_LIMIT);

		Assert.areEqual(new List<Id> {seededIssue.Id}, extractIdsInOrder(foundIssues), 'Expected the issue stored with the short form, got ' + foundIssues);
	}

	/**
	 * @description The finder by Ids finds an issue whose triggering record Id was written in the full form of 18
	 * characters, as the framework writes it.
	 *
	 * @see SEL_ApiIssue.findByTriggeringRecordIds
	 */
	@IsTest
	private static void shouldFindARowStoredWithTheEighteenCharacterForm()
	{
		Id triggeringRecordId = UTIL_Random.randomId(Foobar__c.SObjectType);
		ApiIssue__c seededIssue = seedIssuesFor(triggeringRecordId, 1)[0];

		List<ApiIssue__c> foundIssues = findByIdsAsAdministrator(new Set<Id> {triggeringRecordId}, ROW_LIMIT);

		Assert.areEqual(new List<Id> {seededIssue.Id}, extractIdsInOrder(foundIssues), 'Expected the issue stored with the full form, got ' + foundIssues);
	}

	/**
	 * @description The finder by Ids finds an issue whose triggering record Id was written in the full form of 18
	 * characters with the case of every letter changed. The search ignores case, and that is safe for the full form: its
	 * last three characters tell apart two Ids that differ only in case.
	 *
	 * @see SEL_ApiIssue.findByTriggeringRecordIds
	 */
	@IsTest
	private static void shouldFindAValueStoredInTheEighteenCharacterFormInAnotherCase()
	{
		Id triggeringRecordId = UTIL_Random.randomId(Foobar__c.SObjectType);
		String otherCase = String.valueOf(triggeringRecordId).swapCase();
		Assert.isFalse(otherCase.equals(String.valueOf(triggeringRecordId)), 'Expected the stored value to differ in case from the Id');
		ApiIssue__c seededIssue = seedIssuesFor(otherCase, 1)[0];

		List<ApiIssue__c> foundIssues = findByIdsAsAdministrator(new Set<Id> {triggeringRecordId}, ROW_LIMIT);

		Assert.areEqual(new List<Id> {seededIssue.Id}, extractIdsInOrder(foundIssues), 'Expected the issue stored in another case, got ' + foundIssues);
	}

	/**
	 * @description The finder by values finds an issue raised for a reference from another system, which is not a record Id.
	 *
	 * @see SEL_ApiIssue.findByTriggeringRecordValues
	 */
	@IsTest
	private static void shouldFindAValueThatIsNotARecordId()
	{
		String reference = OTHER_SYSTEM_REFERENCE_PREFIX + UTIL_Random.randomAlphanumeric(REFERENCE_RANDOM_LENGTH);
		ApiIssue__c seededIssue = seedIssuesFor(reference, 1)[0];

		List<ApiIssue__c> foundIssues = findByValuesAsAdministrator(new Set<String> {reference}, ROW_LIMIT);

		Assert.areEqual(new List<Id> {seededIssue.Id}, extractIdsInOrder(foundIssues), 'Expected the issue raised for the reference, got ' + foundIssues);
	}

	/**
	 * @description The finder by values ignores blank values in the set and finds the issue for the value beside them.
	 *
	 * @see SEL_ApiIssue.findByTriggeringRecordValues
	 */
	@IsTest
	private static void shouldIgnoreABlankElement()
	{
		String reference = OTHER_SYSTEM_REFERENCE_PREFIX + UTIL_Random.randomAlphanumeric(REFERENCE_RANDOM_LENGTH);
		ApiIssue__c seededIssue = seedIssuesFor(reference, 1)[0];

		List<ApiIssue__c> foundIssues = findByValuesAsAdministrator(new Set<String> {reference, UTIL_String.EMPTY, UTIL_String.SPACE}, ROW_LIMIT);

		Assert.areEqual(new List<Id> {seededIssue.Id}, extractIdsInOrder(foundIssues), 'Expected the issue raised for the reference, got ' + foundIssues);
	}

	/**
	 * @description The finder by values ignores upper and lower case: a value written in upper case finds an issue whose
	 * Triggering Record Index is in lower case.
	 *
	 * @see SEL_ApiIssue.findByTriggeringRecordValues
	 */
	@IsTest
	private static void shouldMatchAValueWrittenInAnotherCase()
	{
		String reference = (OTHER_SYSTEM_REFERENCE_PREFIX + UTIL_Random.randomAlphanumeric(REFERENCE_RANDOM_LENGTH)).toLowerCase();
		ApiIssue__c seededIssue = seedIssuesFor(reference, 1)[0];

		List<ApiIssue__c> foundIssues = findByValuesAsAdministrator(new Set<String> {reference.toUpperCase()}, ROW_LIMIT);

		Assert.areEqual(new List<Id> {seededIssue.Id}, extractIdsInOrder(foundIssues), 'Expected the issue whose Triggering Record Index is in another case, got ' + foundIssues);
	}

	/**
	 * @description The read of calls that have an open issue, used inside another query, selects the API Call field of
	 * the issues whose status is Open. A read of API calls that leaves those calls out gives the same SOQL as the same
	 * read built by hand.
	 *
	 * @see SEL_ApiIssue.buildApiCallsWithOpenIssueSubquery
	 */
	@IsTest
	private static void shouldBuildTheOpenIssueSubqueryOnTheApiCallField()
	{
		QRY_Builder.Builder expectedSubquery = QRY_Builder.selectFrom(ApiIssue__c.SObjectType)
				.fields(new List<SObjectField> {ApiIssue__c.ApiCall__c})
				.condition(ApiIssue__c.Status__c).equals(SEL_ApiIssue.STATUS_OPEN);
		String expectedSoql = QRY_Builder.selectFrom(ApiCall__c.SObjectType)
				.condition(ApiCall__c.Id).notIn(expectedSubquery)
				.toSoql();

		Test.startTest();

		String soql = QRY_Builder.selectFrom(ApiCall__c.SObjectType)
				.condition(ApiCall__c.Id).notIn(SEL_ApiIssue.buildApiCallsWithOpenIssueSubquery())
				.toSoql();

		Test.stopTest();

		Assert.areEqual(expectedSoql, soql, 'Expected the same SOQL as the read of calls with an open issue built by hand');
	}

	/**
	 * @description Saves open issues for one service, all raised for the same triggering value.
	 *
	 * @param triggeringValue The value written as the triggering record Id of each issue
	 * @param numberOfIssues How many issues to save
	 *
	 * @return The saved issues, in the order they were saved
	 */
	private static List<ApiIssue__c> seedIssuesFor(String triggeringValue, Integer numberOfIssues)
	{
		return TST_Builder.of(ApiIssue__c.SObjectType)
				.withCount(numberOfIssues)
				.withOverrides(new Map<SObjectField, Object>
				{
						ApiIssue__c.TriggeringRecordId__c => triggeringValue,
						ApiIssue__c.ServiceName__c => UTIL_Random.randomName(),
						ApiIssue__c.Status__c => SEL_ApiIssue.STATUS_OPEN
				})
				.buildList();
	}

	/**
	 * @description Runs the finder by Ids as the test administrator, who may read issues and every field of an issue. The
	 * user who runs the tests may lack read access to the issue fields, and the finder checks it.
	 *
	 * @param recordIds The record Ids to look for
	 * @param rowLimit The most issues to return
	 *
	 * @return The issues found
	 */
	private static List<ApiIssue__c> findByIdsAsAdministrator(Set<Id> recordIds, Integer rowLimit)
	{
		return findByIdsAsUser(getTestAdmin(), recordIds, rowLimit);
	}

	/**
	 * @description Runs the finder by Ids as the given user, so the user's object, field and sharing access apply.
	 *
	 * @param reader The user who reads
	 * @param recordIds The record Ids to look for
	 * @param rowLimit The most issues to return
	 *
	 * @return The issues found
	 */
	private static List<ApiIssue__c> findByIdsAsUser(User reader, Set<Id> recordIds, Integer rowLimit)
	{
		List<ApiIssue__c> foundIssues;
		System.runAs(reader)
		{
			foundIssues = new SEL_ApiIssue().findByTriggeringRecordIds(recordIds, rowLimit);
		}
		return foundIssues;
	}

	/**
	 * @description Runs the finder by values as the given user, so the user's object, field and sharing access apply.
	 *
	 * @param reader The user who reads
	 * @param values The values to look for
	 * @param rowLimit The most issues to return
	 *
	 * @return The issues found
	 */
	private static List<ApiIssue__c> findByValuesAsUser(User reader, Set<String> values, Integer rowLimit)
	{
		List<ApiIssue__c> foundIssues;
		System.runAs(reader)
		{
			foundIssues = new SEL_ApiIssue().findByTriggeringRecordValues(values, rowLimit);
		}
		return foundIssues;
	}

	/**
	 * @description Runs the finder by values as the test administrator, who may read issues and every field of an issue.
	 * The user who runs the tests may lack read access to the issue fields, and the finder checks it.
	 *
	 * @param values The values to look for
	 * @param rowLimit The most issues to return
	 *
	 * @return The issues found
	 */
	private static List<ApiIssue__c> findByValuesAsAdministrator(Set<String> values, Integer rowLimit)
	{
		return findByValuesAsUser(getTestAdmin(), values, rowLimit);
	}

	/**
	 * @description Saves a Minimum Access user with a permission set made for the test: read access to issues and to
	 * every field of an issue except one.
	 *
	 * @param hiddenField The one field the user may not read
	 *
	 * @return The saved user
	 */
	private static User insertReaderWithHiddenField(SObjectField hiddenField)
	{
		return TST_Factory.insertUserWithOneHiddenField
				(
						SEL_Profile.PROFILE_MINIMUM_ACCESS,
						new List<SObjectType> {ApiIssue__c.SObjectType},
						new List<SObjectField> {ObjectPermissions.PermissionsRead},
						hiddenField
				);
	}

	/**
	 * @description Saves two open issues of one service and request as the test administrator. The first issue gets the
	 * first triggering value, and the second gets the second.
	 *
	 * @param serviceName The service both issues belong to
	 * @param hashParameter The request parameters hash both issues share
	 * @param triggeringValues The two Triggering Record Id values, in order
	 *
	 * @return The two saved issues, in the order of their values
	 */
	private static List<ApiIssue__c> insertTwoOpenIssues(String serviceName, String hashParameter, List<Object> triggeringValues)
	{
		List<ApiIssue__c> issues;
		System.runAs(getTestAdmin())
		{
			issues = TST_Builder.of(ApiIssue__c.SObjectType)
					.withCount(2)
					.withOverrides(new Map<SObjectField, Object>
					{
							ApiIssue__c.ServiceName__c => serviceName,
							ApiIssue__c.RequestParametersHash__c => hashParameter,
							ApiIssue__c.Status__c => SEL_ApiIssue.STATUS_OPEN
					})
					.withCycle(ApiIssue__c.TriggeringRecordId__c, triggeringValues)
					.buildList();
		}
		return issues;
	}

	/**
	 * @description Collects the Ids of the issues in the order they were returned.
	 *
	 * @param issues The issues returned
	 *
	 * @return Their Ids, in order
	 */
	private static List<Id> extractIdsInOrder(List<ApiIssue__c> issues)
	{
		List<Id> issueIds = new List<Id>();
		for(ApiIssue__c issue : issues)
		{
			issueIds.add(issue.Id);
		}
		return issueIds;
	}

	/**
	 * @description Retrieves the committed test admin user set up in @TestSetup. Used by the
	 * tier-A test to seed the ApiIssue__c row before the low-privilege user queries it.
	 *
	 * @return The test admin User record.
	 */
	private static User getTestAdmin()
	{
		return new SEL_User().findByCompanyName(TEST_ADMIN_COMPANY);
	}

	/**
	 * @description Retrieves the committed low-privilege user (Minimum Access - Salesforce profile)
	 * set up in @TestSetup. Used by the tier-A test to exercise SEL_ApiIssue.findUnresolvedByService
	 * and prove the framework-owned selector elevates internally via systemModeRequired().
	 *
	 * @return The low-privilege User record.
	 */
	private static User getLowPrivilegeUser()
	{
		return new SEL_User().findByCompanyName(LOW_PRIVILEGE_COMPANY);
	}

	/**
	 * @description Reads issues from a class declared with sharing, so the running user's record sharing applies the way
	 * it does when a Lightning action makes the call. This test class declares no sharing, so a read made straight from a
	 * test method does not apply record sharing.
	 */
	private with sharing class SharingEnforcedReader
	{
		/**
		 * @description Finds every user's open issues for one request through SEL_ApiIssue.findByFailedApiCall.
		 *
		 * @param recordId The Id of the triggering record
		 * @param serviceName The name of the web service
		 * @param hashParameter The request parameters hash to match
		 *
		 * @return The open issues for the request
		 */
		public List<ApiIssue__c> findByFailedApiCall(Id recordId, String serviceName, String hashParameter)
		{
			return new SEL_ApiIssue().findByFailedApiCall(recordId, serviceName, hashParameter);
		}

		/**
		 * @description Finds every user's open issues for one request through SEL_ApiIssue.findOpenByTriggeringRecordValue.
		 *
		 * @param triggeringRecordValue The text of the Triggering Record Id field of the request
		 * @param serviceName The name of the web service
		 * @param hashParameter The request parameters hash to match
		 *
		 * @return The open issues for the request
		 */
		public List<ApiIssue__c> findOpenByTriggeringRecordValue(String triggeringRecordValue, String serviceName, String hashParameter)
		{
			return new SEL_ApiIssue().findOpenByTriggeringRecordValue(triggeringRecordValue, serviceName, hashParameter);
		}

		/**
		 * @description Finds every user's open issues of the given API calls through SEL_ApiIssue.findOpenByApiCalls.
		 *
		 * @param apiCallIds The Ids of the API calls to check
		 *
		 * @return The open issues of those calls
		 */
		public List<ApiIssue__c> findOpenByApiCalls(Set<Id> apiCallIds)
		{
			return new SEL_ApiIssue().findOpenByApiCalls(apiCallIds);
		}

		/**
		 * @description Finds every user's open outbound issues with the given hashes through
		 * SEL_ApiIssue.findOpenOutboundByRequestParametersHashes.
		 *
		 * @param serviceNames The services the requests were sent to
		 * @param requestParametersHashes The request parameters hashes of the requests
		 * @param triggeringRecordValues The triggering record IDs of the requests; a blank value matches an issue with no record
		 *
		 * @return The open outbound issues found
		 */
		public List<ApiIssue__c> findOpenOutboundByRequestParametersHashes(Set<String> serviceNames, Set<String> requestParametersHashes, Set<String> triggeringRecordValues)
		{
			return new SEL_ApiIssue().findOpenOutboundByRequestParametersHashes(serviceNames, requestParametersHashes, triggeringRecordValues);
		}

		/**
		 * @description Finds every user's open issues of one request through SEL_ApiIssue.findOpenByIdempotencyKey.
		 *
		 * @param serviceName The service the request was sent to
		 * @param idempotencyKey The Idempotency-Key the request carried
		 * @param senderId The user who sent the request
		 *
		 * @return The open issues of the request
		 */
		public List<ApiIssue__c> findOpenByIdempotencyKey(String serviceName, String idempotencyKey, Id senderId)
		{
			return new SEL_ApiIssue().findOpenByIdempotencyKey(serviceName, idempotencyKey, senderId);
		}
	}
}