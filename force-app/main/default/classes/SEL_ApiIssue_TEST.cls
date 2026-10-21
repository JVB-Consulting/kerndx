// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Unit tests for SEL_ApiIssue selector.
 *
 * @see SEL_ApiIssue
 *
 * @author Jason van Beukering
 *
 * @group Web Services
 *
 * @date February 2026, October 2026
 */
@IsTest(seeAllData=false isParallel=false)
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
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
	 * @description Commits both a test-admin and a low-privilege user in @TestSetup's separate
	 * transaction so the tier-A test (shouldFindUnresolvedByServiceForLowPrivilegeUser) can use
	 * System.runAs against either without triggering MIXED_DML_OPERATION. User is a Setup object,
	 * so User DML cannot mix with standard/custom-object DML in the same transaction;
	 * pre-provisioning here satisfies that boundary.
	 *
	 * Only the tier-A test uses these users — existing SEL_ApiIssue tests continue to run as the
	 * @IsTest running user without runAs.
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

		User lowPrivilegeUser = TST_Factory.newMinimumAccessUser(LOW_PRIVILEGE_COMPANY);
		insert lowPrivilegeUser;
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