// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Unit tests for SEL_ApiCall selector.
 *
 * @see SEL_ApiCall
 *
 * @author Jason van Beukering
 *
 * @group Web Services
 *
 * @date February 2026, October 2026
 */
@IsTest(seeAllData=false isParallel=false)
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
private class SEL_ApiCall_TEST
{
	/**
	 * @description Test service name for API call creation.
	 */
	private static final String TEST_SERVICE_NAME = 'TestService';

	/**
	 * @description The address an inbound call kept for its request, with its query string.
	 */
	private static final String TEST_URL = '/services/apexrest/echo/test?reference=1';

	/**
	 * @description The retry wait a scheduled row is given, in seconds.
	 */
	private static final Integer SECONDS_UNTIL_RETRY = 30;

	/**
	 * @description Company name discriminator for the committed test admin user set up in
	 * @TestSetup and retrieved via SEL_User.findByCompanyName.
	 */
	private static final String TEST_ADMIN_COMPANY = 'SEL_ApiCall_TEST-admin';

	/**
	 * @description Company name discriminator for the committed low-privilege user (Minimum Access
	 * - Salesforce profile) set up in @TestSetup and used by the tier-A regression test.
	 */
	private static final String LOW_PRIVILEGE_COMPANY = 'SEL_ApiCall_TEST-low-privilege';

	/**
	 * @description Company name of the Standard User who owns none of the seeded calls, so a read that finds them as this
	 * user proves the read sees past the Private sharing model.
	 */
	private static final String STANDARD_USER_COMPANY = 'SEL_ApiCall_TEST-standard-user';

	/**
	 * @description The statuses that mean a call is in progress or will be sent; the open-call reads must find exactly these.
	 */
	private static final List<String> OPEN_STATUSES = new List<String>
	{
			SEL_ApiCall.STATUS_BATCHED,
			SEL_ApiCall.STATUS_PROCESSING,
			SEL_ApiCall.STATUS_QUEUED,
			SEL_ApiCall.STATUS_RETRY,
			SEL_ApiCall.STATUS_RETRYING
	};

	/**
	 * @description The statuses of calls that have finished; the open-call reads must leave these out.
	 */
	private static final List<String> FINISHED_STATUSES = new List<String> {SEL_ApiCall.STATUS_COMPLETED, SEL_ApiCall.STATUS_FAILED};

	/**
	 * @description Commits both a test-admin and a low-privilege user in @TestSetup's separate
	 * transaction so the tier-A test (shouldFindByServiceNameForLowPrivilegeUser) can use
	 * System.runAs against either without triggering MIXED_DML_OPERATION. User is a Setup object,
	 * so User DML cannot mix with standard/custom-object DML in the same transaction;
	 * pre-provisioning here satisfies that boundary.
	 *
	 * Only the tier-A test uses these users — existing SEL_ApiCall tests continue to run as the
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
		DML_Builder.newTransaction().doInsert(lowPrivilegeUser).execute();

		TST_Factory.insertUser(SEL_Profile.PROFILE_STANDARD_USER, STANDARD_USER_COMPANY);
	}

	/**
	 * @description Seeds one call for every open status and one for every finished status, all for the same triggering
	 * record and owned by the running user.
	 *
	 * @param triggeringRecordId The record every seeded call was made for
	 *
	 * @return The seeded calls, open ones first
	 */
	private static List<ApiCall__c> seedOpenAndFinishedCalls(Id triggeringRecordId)
	{
		List<String> statuses = new List<String>(OPEN_STATUSES);
		statuses.addAll(FINISHED_STATUSES);
		List<ApiCall__c> calls = new List<ApiCall__c>();
		for(String status : statuses)
		{
			calls.add((ApiCall__c)apiCallBuilder(status).withOverride(ApiCall__c.TriggeringRecordId__c, triggeringRecordId).build());
		}
		return calls;
	}

	/**
	 * @description Collects the ids of the seeded calls at an open status.
	 *
	 * @param seededCalls The calls seeded, open and finished
	 *
	 * @return The ids of the open ones
	 */
	private static Set<Id> collectOpenCallIds(List<ApiCall__c> seededCalls)
	{
		return UTIL_SObject.extractIds(UTIL_SObject.findWhereIn(seededCalls, UTIL_SObjectDescribe.getCachedFieldName(ApiCall__c.Status__c), OPEN_STATUSES));
	}

	/**
	 * @description The read by call id returns the calls that are Queued, Processing, Retry, Retrying or Batched, and leaves
	 * out the Completed and the Failed one.
	 *
	 * @see SEL_ApiCall.findOpenById
	 */
	@IsTest
	private static void shouldFindOnlyOpenCallsById()
	{
		List<ApiCall__c> seededCalls = seedOpenAndFinishedCalls(UTIL_Random.randomId(Foobar__c.SObjectType));

		List<ApiCall__c> foundCalls = new SEL_ApiCall().findOpenById(UTIL_SObject.extractIds(seededCalls));

		Set<Id> openCallIds = collectOpenCallIds(seededCalls);
		Assert.areEqual(OPEN_STATUSES.size(), openCallIds.size(), 'Expected one seeded call per open status, got ' + openCallIds.size());
		Assert.areEqual(openCallIds, UTIL_SObject.extractIds(foundCalls), 'Expected exactly the calls at an open status, got ' + foundCalls);
	}

	/**
	 * @description The read by triggering record returns the open calls made for that record, and leaves out the finished
	 * ones.
	 *
	 * @see SEL_ApiCall.findOpenByTriggeringRecordIds
	 */
	@IsTest
	private static void shouldFindOnlyOpenCallsByTriggeringRecord()
	{
		Id triggeringRecordId = UTIL_Random.randomId(Foobar__c.SObjectType);
		List<ApiCall__c> seededCalls = seedOpenAndFinishedCalls(triggeringRecordId);

		List<ApiCall__c> foundCalls = new SEL_ApiCall().findOpenByTriggeringRecordIds(new Set<Id> {triggeringRecordId});

		Set<Id> openCallIds = collectOpenCallIds(seededCalls);
		Assert.areEqual(OPEN_STATUSES.size(), openCallIds.size(), 'Expected one seeded call per open status, got ' + openCallIds.size());
		Assert.areEqual(openCallIds, UTIL_SObject.extractIds(foundCalls), 'Expected exactly the calls at an open status, got ' + foundCalls);
	}

	/**
	 * @description A Standard User who owns none of the calls still finds every open one among their ids: ApiCall__c is
	 * Private, and the bulk retry must see an issue's own call even when another user started it.
	 *
	 * @see SEL_ApiCall.findOpenById
	 */
	@IsTest
	private static void shouldFindAnotherUsersOpenCallsById()
	{
		List<ApiCall__c> seededCalls = seedOpenAndFinishedCalls(UTIL_Random.randomId(Foobar__c.SObjectType));
		List<ApiCall__c> foundCalls;

		System.runAs(new SEL_User().findByCompanyName(STANDARD_USER_COMPANY))
		{
			foundCalls = new SEL_ApiCall().findOpenById(UTIL_SObject.extractIds(seededCalls));
		}

		Set<Id> openCallIds = collectOpenCallIds(seededCalls);
		Assert.areEqual(OPEN_STATUSES.size(), openCallIds.size(), 'Expected one seeded call per open status, got ' + openCallIds.size());
		Assert.areEqual(openCallIds, UTIL_SObject.extractIds(foundCalls), 'Expected exactly the calls at an open status, got ' + foundCalls);
	}

	/**
	 * @description A Standard User who owns none of the calls still finds every open call made for the record: ApiCall__c is
	 * Private, and the bulk retry must see a call another user started before it sends the same request again.
	 *
	 * @see SEL_ApiCall.findOpenByTriggeringRecordIds
	 */
	@IsTest
	private static void shouldFindAnotherUsersOpenCallsByTriggeringRecord()
	{
		Id triggeringRecordId = UTIL_Random.randomId(Foobar__c.SObjectType);
		List<ApiCall__c> seededCalls = seedOpenAndFinishedCalls(triggeringRecordId);
		List<ApiCall__c> foundCalls;

		System.runAs(new SEL_User().findByCompanyName(STANDARD_USER_COMPANY))
		{
			foundCalls = new SEL_ApiCall().findOpenByTriggeringRecordIds(new Set<Id> {triggeringRecordId});
		}

		Set<Id> openCallIds = collectOpenCallIds(seededCalls);
		Assert.areEqual(OPEN_STATUSES.size(), openCallIds.size(), 'Expected one seeded call per open status, got ' + openCallIds.size());
		Assert.areEqual(openCallIds, UTIL_SObject.extractIds(foundCalls), 'Expected exactly the calls at an open status, got ' + foundCalls);
	}

	/**
	 * @description The read of a call's request returns what a replay needs (the body, the address, the hash of the
	 * body), and leaves out the response, which can be as long as the request, so a check of many issues does not hold
	 * every response in memory.
	 *
	 * @see SEL_ApiCall.findRequestById
	 */
	@IsTest
	private static void shouldReadTheRequestOfACallWithoutItsResponse()
	{
		String body = UTIL_Random.randomName();
		ApiCall__c seededCall = (ApiCall__c)apiCallBuilder(SEL_ApiCall.STATUS_FAILED, SEL_ApiCall.TYPE_INBOUND)
				.withOverrides(new Map<SObjectField, Object>
				{
						ApiCall__c.Request__c => body,
						ApiCall__c.Response__c => UTIL_Random.randomName(),
						ApiCall__c.URL__c => TEST_URL,
						ApiCall__c.IdempotencyKeyBodyHash__c => API_Inbound.computeBodyHash(body)
				})
				.build();

		List<ApiCall__c> foundCalls = new SEL_ApiCall().findRequestById(new Set<Id> {seededCall.Id});

		Assert.areEqual(1, foundCalls.size(), 'Expected the one call, got ' + foundCalls);
		ApiCall__c foundCall = foundCalls.get(0);
		Assert.areEqual(body, foundCall.Request__c, 'Expected the body the call kept');
		Assert.areEqual(TEST_URL, foundCall.URL__c, 'Expected the address the call kept');
		Assert.areEqual(API_Inbound.computeBodyHash(body), foundCall.IdempotencyKeyBodyHash__c, 'Expected the hash of the body the call kept');
		Assert.isFalse(foundCall.isSet(ApiCall__c.Response__c), 'Expected the response not to be read');
	}

	/**
	 * @description A Standard User who owns none of the calls reads the small fields of the request a call kept (the
	 * address, the key, the hash of the body and the permanent failure marker), and the read holds nothing large: no
	 * body, no parameters and no response. Retry Selected reads the calls of every selected inbound issue this way, so a
	 * large selection does not fill the memory the action may use.
	 *
	 * @see SEL_ApiCall.findRequestWithoutBodyById
	 */
	@IsTest
	private static void shouldReadTheRequestOfAnotherUsersCallWithoutItsBody()
	{
		String body = UTIL_Random.randomName();
		String idempotencyKey = UTIL_Random.randomUUID();
		ApiCall__c seededCall = (ApiCall__c)apiCallBuilder(SEL_ApiCall.STATUS_FAILED, SEL_ApiCall.TYPE_INBOUND)
				.withOverrides(new Map<SObjectField, Object>
				{
						ApiCall__c.Request__c => body,
						ApiCall__c.RequestParameters__c => UTIL_Random.randomName(),
						ApiCall__c.Response__c => UTIL_Random.randomName(),
						ApiCall__c.URL__c => TEST_URL,
						ApiCall__c.IdempotencyKey__c => idempotencyKey,
						ApiCall__c.IdempotencyKeyBodyHash__c => API_Inbound.computeBodyHash(body),
						ApiCall__c.IsPermanentFailure__c => true
				})
				.build();
		List<ApiCall__c> foundCalls;

		System.runAs(new SEL_User().findByCompanyName(STANDARD_USER_COMPANY))
		{
			foundCalls = new SEL_ApiCall().findRequestWithoutBodyById(new Set<Id> {seededCall.Id});
		}

		Assert.areEqual(1, foundCalls.size(), 'Expected the call another user wrote, got ' + foundCalls);
		ApiCall__c foundCall = foundCalls.get(0);
		Assert.areEqual(TEST_URL, foundCall.URL__c, 'Expected the address the call kept');
		Assert.areEqual(idempotencyKey, foundCall.IdempotencyKey__c, 'Expected the key the call kept');
		Assert.areEqual(API_Inbound.computeBodyHash(body), foundCall.IdempotencyKeyBodyHash__c, 'Expected the hash of the body the call kept');
		Assert.isTrue(foundCall.IsPermanentFailure__c, 'Expected the call to be marked as failed permanently');
		Assert.isFalse(foundCall.isSet(ApiCall__c.Request__c), 'Expected the body not to be read');
		Assert.isFalse(foundCall.isSet(ApiCall__c.RequestParameters__c), 'Expected the parameters not to be read');
		Assert.isFalse(foundCall.isSet(ApiCall__c.Response__c), 'Expected the response not to be read');
	}

	/**
	 * @description A Standard User who owns none of the calls still finds that a call failed permanently, and the read
	 * holds nothing else of the call: no request and no response. ApiCall__c is Private, and an outbound issue whose call
	 * failed permanently must not be sent again because the user cannot see the call.
	 *
	 * @see SEL_ApiCall.findPermanentFailureById
	 */
	@IsTest
	private static void shouldFindThatAnotherUsersCallFailedPermanentlyWithoutItsPayloads()
	{
		ApiCall__c seededCall = (ApiCall__c)apiCallBuilder(SEL_ApiCall.STATUS_FAILED)
				.withOverrides(new Map<SObjectField, Object>
				{
						ApiCall__c.IsPermanentFailure__c => true,
						ApiCall__c.Request__c => UTIL_Random.randomName(),
						ApiCall__c.Response__c => UTIL_Random.randomName()
				})
				.build();
		List<ApiCall__c> foundCalls;

		System.runAs(new SEL_User().findByCompanyName(STANDARD_USER_COMPANY))
		{
			foundCalls = new SEL_ApiCall().findPermanentFailureById(new Set<Id> {seededCall.Id});
		}

		Assert.areEqual(1, foundCalls.size(), 'Expected the call another user wrote, got ' + foundCalls);
		Assert.isTrue(foundCalls.get(0).IsPermanentFailure__c, 'Expected the call to be marked as failed permanently');
		Assert.isFalse(foundCalls.get(0).isSet(ApiCall__c.Request__c), 'Expected the request not to be read');
		Assert.isFalse(foundCalls.get(0).isSet(ApiCall__c.Response__c), 'Expected the response not to be read');
	}

	/**
	 * @description Creates a pre-configured ApiCall builder with common test fields.
	 *
	 * @param status The status value for the API call
	 * @param direction The direction (inbound/outbound) for the API call
	 *
	 * @return A TST_Builder.Builder ready for further chaining or .build()
	 */
	private static TST_Builder.Builder apiCallBuilder(String status, String direction)
	{
		return TST_Factory.getApiCallBuilder()
				.withOverrides(new Map<SObjectField, Object>
				{
						ApiCall__c.ServiceName__c => TEST_SERVICE_NAME,
						ApiCall__c.Status__c => status,
						ApiCall__c.Direction__c => direction
				});
	}

	/**
	 * @description Creates a pre-configured outbound ApiCall builder with common test fields.
	 *
	 * @param status The status value for the API call
	 *
	 * @return A TST_Builder.Builder ready for further chaining or .build()
	 */
	private static TST_Builder.Builder apiCallBuilder(String status)
	{
		return apiCallBuilder(status, SEL_ApiCall.TYPE_OUTBOUND);
	}

	/**
	 * @description Creates a pre-configured inbound ApiCall builder for the test service, with an Idempotency-Key.
	 *
	 * @param status The status value for the API call
	 * @param idempotencyKey The key the call carried
	 *
	 * @return A TST_Builder.Builder ready for further chaining or .build()
	 */
	private static TST_Builder.Builder inboundCallBuilder(String status, String idempotencyKey)
	{
		return apiCallBuilder(status, SEL_ApiCall.TYPE_INBOUND).withOverride(ApiCall__c.IdempotencyKey__c, idempotencyKey);
	}

	/**
	 * @description Tests that findByServiceName returns matching API calls.
	 */
	@IsTest
	private static void shouldFindByServiceName()
	{
		apiCallBuilder(SEL_ApiCall.STATUS_QUEUED).build();

		List<ApiCall__c> results = new SEL_ApiCall().findByServiceName(TEST_SERVICE_NAME);

		Assert.areEqual(1, results.size(), 'Should find one API call');
		Assert.areEqual(TEST_SERVICE_NAME, results[0].ServiceName__c, 'Service name should match');
	}

	/**
	 * @description Tests that findByBatchedOutbound returns only batched outbound items.
	 */
	@IsTest
	private static void shouldFindByBatchedOutbound()
	{
		apiCallBuilder(SEL_ApiCall.STATUS_BATCHED).build();

		List<ApiCall__c> results = new SEL_ApiCall().findByBatchedOutbound();

		Assert.areEqual(1, results.size(), 'Should find one batched outbound item');
	}

	/**
	 * @description Tests that the batched-outbound sweep — which bypasses sharing so a scheduled
	 * sweep sees every user's batched calls — emits no sharing BYPASS audit entry. The bypass is
	 * a framework-internal design choice, not a subscriber-facing opt-out.
	 *
	 * @see SEL_ApiCall.findByBatchedOutbound
	 * @see QRY_Builder.Builder.bypassSharingInternal
	 */
	@IsTest
	private static void shouldNotEmitBypassAuditOnBatchedOutboundSweep()
	{
		LOG_Builder.ignoreTestMode = true;
		TST_Factory.setupLoggerForTest();

		Test.startTest();
		new SEL_ApiCall().findByBatchedOutbound();
		Test.stopTest();

		for(LogEntry__c entry : new SEL_LogEntry().findAllOrderedByCreatedDateDesc())
		{
			Map<String, Object> context = SEL_LogEntry.parseContextDataForTest(entry);
			String target = (String)(context?.get(UTIL_BypassAudit.CONTEXT_TARGET));
			Assert.isFalse
					(
							target != null && target.startsWith('sharing'),
							'The batched-outbound sweep must not emit a sharing BYPASS audit entry'
					);
		}
	}

	/**
	 * @description Tests that assertServiceCompleted passes for completed API calls.
	 */
	@IsTest
	private static void shouldAssertServiceCompleted()
	{
		apiCallBuilder(SEL_ApiCall.STATUS_COMPLETED).build();

		List<ApiCall__c> results = SEL_ApiCall.assertServiceCompleted(TEST_SERVICE_NAME);

		Assert.areEqual(1, results.size(), 'Should find one completed item');
	}

	/**
	 * @description Tests that assertServiceAborted passes for aborted API calls with an error phrase.
	 */
	@IsTest
	private static void shouldAssertServiceAbortedWithErrorPhrase()
	{
		apiCallBuilder(SEL_ApiCall.STATUS_ABORTED)
				.withOverride(ApiCall__c.ErrorMessages__c, 'Connection timeout occurred')
				.build();

		List<ApiCall__c> results = SEL_ApiCall.assertServiceAborted(TEST_SERVICE_NAME, 'Connection timeout');

		Assert.areEqual(1, results.size(), 'Should find one aborted item');
	}

	/**
	 * @description Tests that assertServiceAborted, without an error phrase, passes for an aborted API call.
	 */
	@IsTest
	private static void shouldAssertServiceAborted()
	{
		apiCallBuilder(SEL_ApiCall.STATUS_ABORTED).build();

		List<ApiCall__c> results = SEL_ApiCall.assertServiceAborted(TEST_SERVICE_NAME);

		Assert.areEqual(1, results.size(), 'Expected one aborted call, got ' + results.size());
	}

	/**
	 * @description Tests that assertServiceFailed passes for a failed API call, with and without an error phrase.
	 */
	@IsTest
	private static void shouldAssertServiceFailed()
	{
		String errorPhrase = UTIL_Random.randomName();
		apiCallBuilder(SEL_ApiCall.STATUS_FAILED).withOverride(ApiCall__c.ErrorMessages__c, 'Failed: ' + errorPhrase).build();

		List<ApiCall__c> results = SEL_ApiCall.assertServiceFailed(TEST_SERVICE_NAME);
		List<ApiCall__c> resultsWithPhrase = SEL_ApiCall.assertServiceFailed(TEST_SERVICE_NAME, errorPhrase);

		Assert.areEqual(1, results.size(), 'Expected one failed call, got ' + results.size());
		Assert.areEqual(1, resultsWithPhrase.size(), 'Expected one failed call carrying the phrase, got ' + resultsWithPhrase.size());
	}

	/**
	 * @description Proves the assertion the retry tests share reads the pair the RetryOutboundApiCall flow filters on: a
	 * row at Retry with a next retry time passes and is returned. A Retry row with no time cannot be shown to be rejected
	 * inside a test, because an assertion failure cannot be caught; the retry engine's own tests fail through this
	 * assertion when a schedule is lost.
	 */
	@IsTest
	private static void shouldAcceptARowAtRetryWithANextRetryTime()
	{
		apiCallBuilder(SEL_ApiCall.STATUS_RETRY, SEL_ApiCall.TYPE_OUTBOUND)
				.withOverride(ApiCall__c.NextRetry__c, Datetime.now().addSeconds(SECONDS_UNTIL_RETRY))
				.build();

		List<ApiCall__c> retrying = SEL_ApiCall.assertServiceRetrying(TEST_SERVICE_NAME);

		Assert.areEqual(1, retrying.size(), 'Expected the one scheduled row to be returned, got ' + retrying.size());
		Assert.isNotNull(retrying[0].NextRetry__c, 'Expected the returned row to carry its next retry time, got none');
	}

	/**
	 * @description Tests that findByIdempotencyKey returns matching API call.
	 */
	@IsTest
	private static void shouldFindByIdempotencyKey()
	{
		String idempotencyKey = UTIL_Random.randomUUID();

		apiCallBuilder(SEL_ApiCall.STATUS_COMPLETED)
				.withOverride(ApiCall__c.IdempotencyKey__c, idempotencyKey)
				.build();

		ApiCall__c result = new SEL_ApiCall().findByIdempotencyKey(idempotencyKey);

		Assert.isNotNull(result, 'Should find API call by idempotency key');
		Assert.areEqual(idempotencyKey, result.IdempotencyKey__c, 'Idempotency key should match');
	}

	/**
	 * @description A Standard User who owns none of the calls finds every call the user who runs the test sent to the
	 * service with the key, whatever its status, newest first, even though record sharing hides those calls from the Standard User. The
	 * read leaves out a call of another service with the same key, a call of the service with another key, and a call
	 * that was answered from an earlier call. The same read for the Standard User finds none of these calls, because a
	 * key belongs to the user who sent it: another user's call with the same service and key is never returned.
	 *
	 * @see SEL_ApiCall.findByServiceAndIdempotencyKey
	 */
	@IsTest
	private static void shouldFindOnlyTheCallsTheUserSentToTheServiceWithTheKey()
	{
		String idempotencyKey = UTIL_Random.randomUUID();
		Id senderId = UserInfo.getUserId();
		ApiCall__c completedCall = (ApiCall__c)inboundCallBuilder(SEL_ApiCall.STATUS_COMPLETED, idempotencyKey).build();
		ApiCall__c failedCall = (ApiCall__c)inboundCallBuilder(SEL_ApiCall.STATUS_FAILED, idempotencyKey).build();
		inboundCallBuilder(SEL_ApiCall.STATUS_FAILED, idempotencyKey).withOverride(ApiCall__c.ServiceName__c, UTIL_Random.randomName()).build();
		inboundCallBuilder(SEL_ApiCall.STATUS_FAILED, UTIL_Random.randomUUID()).build();
		inboundCallBuilder(SEL_ApiCall.STATUS_COMPLETED, idempotencyKey).withOverride(ApiCall__c.IsIdempotencyHit__c, true).build();
		List<ApiCall__c> foundCalls;
		List<ApiCall__c> callsOfAnotherSender;

		System.runAs(new SEL_User().findByCompanyName(STANDARD_USER_COMPANY))
		{
			foundCalls = new SEL_ApiCall().findByServiceAndIdempotencyKey(TEST_SERVICE_NAME, idempotencyKey, senderId);
			callsOfAnotherSender = new SEL_ApiCall().findByServiceAndIdempotencyKey(TEST_SERVICE_NAME, idempotencyKey, UserInfo.getUserId());
		}

		Assert.isTrue(callsOfAnotherSender.isEmpty(), 'Expected no call of another user with the same service and key, got ' + callsOfAnotherSender);
		Assert.areEqual(2, foundCalls.size(), 'Expected only the two calls of the service with the key, got ' + foundCalls);
		Assert.areEqual(failedCall.Id, foundCalls[0].Id, 'Expected the newest call first');
		Assert.areEqual(completedCall.Id, foundCalls[1].Id, 'Expected the older call second');
		Assert.areEqual(SEL_ApiCall.STATUS_FAILED, foundCalls[0].Status__c, 'Expected the read to hold the status of the call');
	}

	/**
	 * @description Tests that findByIdempotencyKey returns null when no match exists.
	 */
	@IsTest
	private static void shouldReturnNullForNonExistentIdempotencyKey()
	{
		ApiCall__c result = new SEL_ApiCall().findByIdempotencyKey('non-existent-key');

		Assert.isNull(result, 'Should return null for non-existent idempotency key');
	}

	/**
	 * @description Tests that updateNextRetryInfo correctly sets retry fields.
	 */
	@IsTest
	private static void shouldUpdateNextRetryInfo()
	{
		ApiCall__c item = (ApiCall__c)apiCallBuilder(SEL_ApiCall.STATUS_QUEUED)
				.withOverride(ApiCall__c.Retries__c, 0)
				.withoutInsertion()
				.build();

		Datetime nextRetry = Datetime.now().addMinutes(5);

		SEL_ApiCall.updateNextRetryInfo(item, nextRetry);

		Assert.areEqual(nextRetry, item.NextRetry__c, 'NextRetry__c should be set');
		Assert.areEqual(1, item.Retries__c, 'Retries__c should be incremented');
		Assert.areEqual(SEL_ApiCall.STATUS_RETRY, item.Status__c, 'Status__c should be Retry');
	}

	/**
	 * @description Tier-A — proves SEL_ApiCall.findByServiceName returns rows
	 * when invoked by a subscriber user on the Minimum Access - Salesforce profile who has no FLS
	 * on kern__ApiCall__c. The framework-owned selector declares `systemModeRequired() = true`, so
	 * its internal QRY_Builder must elevate to SYSTEM_MODE and the query must return the seeded
	 * rows regardless of the running user's FLS.
	 *
	 * Catches: a future refactor that demotes SEL_ApiCall.systemModeRequired() to false, or deletes
	 * the override entirely, would cause the low-privilege user's query to fail with "No such
	 * column: kern__Status__c" — this test fails at 2GP validated-build time rather than at
	 * subscriber scratch-org time.
	 *
	 * @see SEL_ApiCall.findByServiceName
	 * @see SEL_ApiCall.systemModeRequired
	 */
	@IsTest
	private static void shouldFindByServiceNameForLowPrivilegeUser()
	{
		User lowPrivilegeUser = getLowPrivilegeUser();
		ApiCall__c seededCall;

		System.runAs(getTestAdmin())
		{
			seededCall = (ApiCall__c)apiCallBuilder(SEL_ApiCall.STATUS_QUEUED)
					.withOverride(ApiCall__c.OwnerId, lowPrivilegeUser.Id)
					.build();
		}

		Assert.isNotNull(seededCall?.Id, 'Seeded ApiCall__c should have an Id');

		System.runAs(lowPrivilegeUser)
		{
			List<ApiCall__c> results = new SEL_ApiCall().findByServiceName(TEST_SERVICE_NAME);

			Assert.areEqual(1, results.size(), 'Should find the seeded API call for low-privilege caller');
			Assert.areEqual(TEST_SERVICE_NAME, results[0].ServiceName__c, 'ServiceName should match the seeded value');
		}
	}

	/**
	 * @description Retrieves the committed test admin user set up in @TestSetup. Used by the
	 * tier-A test to seed the ApiCall__c row before the low-privilege user queries it.
	 *
	 * @return The test admin User record.
	 */
	private static User getTestAdmin()
	{
		return new SEL_User().findByCompanyName(TEST_ADMIN_COMPANY);
	}

	/**
	 * @description Retrieves the committed low-privilege user (Minimum Access - Salesforce profile)
	 * set up in @TestSetup. Used by the tier-A test to exercise SEL_ApiCall.findByServiceName and
	 * prove the framework-owned selector elevates internally via systemModeRequired().
	 *
	 * @return The low-privilege User record.
	 */
	private static User getLowPrivilegeUser()
	{
		return new SEL_User().findByCompanyName(LOW_PRIVILEGE_COMPANY);
	}
}