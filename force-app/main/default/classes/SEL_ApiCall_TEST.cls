// SPDX-License-Identifier: Apache-2.0
/**
 * @description Unit tests for SEL_ApiCall selector.
 *
 * @see SEL_ApiCall
 *
 * @author Jason van Beukering
 *
 * @group Web Services
 *
 * @date February 2026, November 2026
 */
@IsTest(seeAllData=false isParallel=false)
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs,PMD.CyclomaticComplexity')
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
	 * @description The number of records a test searches for when it checks that a long list of mocks is still filtered.
	 */
	private static final Integer MOCKED_RECORD_COUNT = 200;

	/**
	 * @description The access level of a share that lets a user read a record.
	 */
	private static final String SHARE_ACCESS_READ = 'Read';

	/**
	 * @description The start of a reference from another system, stored as the triggering value of a call.
	 */
	private static final String OTHER_SYSTEM_REFERENCE_PREFIX = 'ORD-';

	/**
	 * @description The number of random letters and digits after the start of a reference from another system.
	 */
	private static final Integer REFERENCE_RANDOM_LENGTH = 10;

	/**
	 * @description The name of the trigger action that fills Triggering Record Index, so a test can skip it and save a
	 * call with that field blank, as on a call saved before the field existed.
	 */
	private static final String INDEX_ACTION_NAME = TRG_SetTriggeringRecordIndex.class.getName();

	/**
	 * @description Saves a test administrator and a low-privilege user once, before the tests run, so a test can run as
	 * either of them. A user cannot be saved in the same transaction as the test's other records (Salesforce refuses that
	 * mix with a MIXED_DML_OPERATION error), so the users are saved here, in a transaction of their own.
	 *
	 * shouldFindByServiceNameForLowPrivilegeUser uses the test administrator and the low-privilege user. The tests that
	 * read another user's calls run as the Standard User. The two finders by triggering record check the running user's
	 * access, so their tests run as follows. The tests that expect calls back run the finders as the test administrator.
	 * The tests that refuse a bad set or row limit, and the tests that run no query, call the finders as the user who runs
	 * the tests, because the finders stop before they read anything. The access tests run as a reader that the test
	 * inserts, except shouldThrowForAUserWithoutObjectRead, which runs as the low-privilege user. The other SEL_ApiCall
	 * tests run as the user who runs the tests.
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
		TST_Factory.insertUser(SEL_Profile.PROFILE_STANDARD_USER, STANDARD_USER_COMPANY);
	}

	/**
	 * @description Seeds one call for every open status and one for every finished status, all for the same triggering
	 * record and owned by the running user.
	 *
	 * @param triggeringRecordValue The record Id, or other text, every seeded call was made for
	 *
	 * @return The seeded calls, open ones first
	 */
	private static List<ApiCall__c> seedOpenAndFinishedCalls(String triggeringRecordValue)
	{
		List<String> statuses = new List<String>(OPEN_STATUSES);
		statuses.addAll(FINISHED_STATUSES);
		List<ApiCall__c> calls = new List<ApiCall__c>();
		for(String status : statuses)
		{
			calls.add((ApiCall__c)apiCallBuilder(status).withOverride(ApiCall__c.TriggeringRecordId__c, triggeringRecordValue).build());
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
	 * @description The read by the text of the triggering record returns the open calls for a reference from another
	 * system, and leaves out the finished ones.
	 *
	 * It also leaves out an open call whose reference differs only in upper and lower case. The database ignores case when
	 * it compares text, so the finder must drop that call itself.
	 *
	 * @see SEL_ApiCall.findOpenByTriggeringRecordValues
	 */
	@IsTest
	private static void shouldFindOnlyOpenCallsWithTheSameTriggeringRecordText()
	{
		String reference = (OTHER_SYSTEM_REFERENCE_PREFIX + UTIL_Random.randomAlphanumeric(REFERENCE_RANDOM_LENGTH)).toUpperCase();
		List<ApiCall__c> seededCalls = seedOpenAndFinishedCalls(reference);
		apiCallBuilder(SEL_ApiCall.STATUS_PROCESSING).withOverride(ApiCall__c.TriggeringRecordId__c, reference.toLowerCase()).build();

		List<ApiCall__c> foundCalls = new SEL_ApiCall().findOpenByTriggeringRecordValues(new Set<String> {reference});

		Set<Id> openCallIds = collectOpenCallIds(seededCalls);
		Assert.areEqual(OPEN_STATUSES.size(), openCallIds.size(), 'Expected one seeded call per open status, got ' + openCallIds.size());
		Assert.areEqual(openCallIds, UTIL_SObject.extractIds(foundCalls), 'Expected exactly the open calls with the same case, got ' + foundCalls);
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
	 * @description The read of stale calls at Retry finds the outbound calls at Retry whose retry was due before the
	 * cutoff, oldest retry time first, each with its last save time. It leaves out a call due after the cutoff, a call at
	 * Retry with no retry time, an inbound call and a call at Retrying. The row limit stops the read at the oldest call.
	 *
	 * @see SEL_ApiCall.findOutboundRetryDueBefore
	 */
	@IsTest
	private static void shouldFindStaleOutboundRetryCallsOldestFirst()
	{
		assertFindsStaleCallsOldestFirst(SEL_ApiCall.STATUS_RETRY, SEL_ApiCall.STATUS_RETRYING);
	}

	/**
	 * @description The read of stale calls at Retrying finds the outbound calls at Retrying whose retry was due before the
	 * cutoff, oldest retry time first, each with its last save time. It leaves out a call due after the cutoff, a call at
	 * Retrying with no retry time, an inbound call and a call at Retry. The row limit stops the read at the oldest call.
	 *
	 * @see SEL_ApiCall.findOutboundRetryingDueBefore
	 */
	@IsTest
	private static void shouldFindStaleOutboundRetryingCallsOldestFirst()
	{
		assertFindsStaleCallsOldestFirst(SEL_ApiCall.STATUS_RETRYING, SEL_ApiCall.STATUS_RETRY);
	}

	/**
	 * @description The read of stale calls at Queued finds an outbound call at Queued last saved before the cutoff, with
	 * its last save time, and finds nothing when the cutoff is before that save. It leaves out an inbound call at Queued
	 * and an outbound call at another status.
	 *
	 * @see SEL_ApiCall.findOutboundQueuedUnchangedSince
	 */
	@IsTest
	private static void shouldFindOutboundQueuedCallsLastSavedBeforeTheCutoff()
	{
		ApiCall__c queuedCall = (ApiCall__c)apiCallBuilder(SEL_ApiCall.STATUS_QUEUED).build();
		apiCallBuilder(SEL_ApiCall.STATUS_QUEUED, SEL_ApiCall.TYPE_INBOUND).build();
		apiCallBuilder(SEL_ApiCall.STATUS_BATCHED).build();
		Datetime afterTheSave = Datetime.now().addMinutes(1);

		List<ApiCall__c> foundCalls = new SEL_ApiCall().findOutboundQueuedUnchangedSince(afterTheSave, ROW_LIMIT);

		Assert.areEqual(1, foundCalls.size(), 'Expected only the outbound call at Queued, got ' + foundCalls);
		Assert.areEqual(queuedCall.Id, foundCalls[0].Id, 'Expected the outbound call at Queued.');
		Assert.isNotNull(foundCalls[0].LastModifiedDate, 'Expected the last save time to be read.');
		Assert.isTrue
				(
						new SEL_ApiCall().findOutboundQueuedUnchangedSince(Datetime.now().addMinutes(-1), ROW_LIMIT).isEmpty(),
						'Expected no call when the cutoff is before the last save.'
				);
	}

	/**
	 * @description The read of stale calls at Retry leaves out the request and the response, which can each hold 131,072
	 * characters. The outbound retry watchdog reads up to 50 calls of each kind in one run, so the bodies would fill the
	 * memory of the run. The call is still found with the fields the watchdog uses.
	 *
	 * @see SEL_ApiCall.findOutboundRetryDueBefore
	 */
	@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveAsserts')
	@IsTest
	private static void shouldReadNoBodyTextForStaleRetryCalls()
	{
		ApiCall__c seededCall = insertCallWithFullLengthBodies(SEL_ApiCall.STATUS_RETRY);

		List<ApiCall__c> foundCalls = new SEL_ApiCall().findOutboundRetryDueBefore(Datetime.now(), ROW_LIMIT);

		assertFoundWithoutBodyText(foundCalls, seededCall);
	}

	/**
	 * @description The read of stale calls at Retrying leaves out the request and the response, which can each hold
	 * 131,072 characters. The call is still found with the fields the watchdog uses.
	 *
	 * @see SEL_ApiCall.findOutboundRetryingDueBefore
	 */
	@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveAsserts')
	@IsTest
	private static void shouldReadNoBodyTextForStaleRetryingCalls()
	{
		ApiCall__c seededCall = insertCallWithFullLengthBodies(SEL_ApiCall.STATUS_RETRYING);

		List<ApiCall__c> foundCalls = new SEL_ApiCall().findOutboundRetryingDueBefore(Datetime.now(), ROW_LIMIT);

		assertFoundWithoutBodyText(foundCalls, seededCall);
	}

	/**
	 * @description The read of stale calls at Queued reads only the fields the watchdog uses, so it leaves out the request
	 * and the response, which can each hold 131,072 characters. The package empties the request and the response of a
	 * call when it is put at Queued, so the saved call holds neither. The test therefore also checks that a field the
	 * watchdog does not use, the user who created the call, is not read.
	 *
	 * @see SEL_ApiCall.findOutboundQueuedUnchangedSince
	 */
	@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveAsserts')
	@IsTest
	private static void shouldReadNoBodyTextForStaleQueuedCalls()
	{
		ApiCall__c seededCall = insertCallWithFullLengthBodies(SEL_ApiCall.STATUS_QUEUED);

		List<ApiCall__c> foundCalls = new SEL_ApiCall().findOutboundQueuedUnchangedSince(Datetime.now().addMinutes(1), ROW_LIMIT);

		assertFoundWithoutBodyText(foundCalls, seededCall);
	}

	/**
	 * @description Saves an outbound call at the given status, with a retry time an hour ago, whose request and response
	 * are as long as the fields allow.
	 *
	 * @param status The status of the call
	 *
	 * @return The saved call
	 */
	private static ApiCall__c insertCallWithFullLengthBodies(String status)
	{
		final Integer oneHourAgo = -60;
		return (ApiCall__c)apiCallBuilder(status)
				.withOverrides(new Map<SObjectField, Object>
				{
						ApiCall__c.NextRetry__c => Datetime.now().addMinutes(oneHourAgo),
						ApiCall__c.Request__c => buildRandomText(SEL_ApiCall.REQUEST_LENGTH),
						ApiCall__c.Response__c => buildRandomText(SEL_ApiCall.RESPONSE_LENGTH)
				})
				.build();
	}

	/**
	 * @description Builds random text of the given length, by repeating a shorter random text.
	 *
	 * @param length The length of the text
	 *
	 * @return The text
	 */
	private static String buildRandomText(Integer length)
	{
		final Integer partLength = 1024;
		return UTIL_Random.randomAlphanumeric(partLength).repeat(length / partLength + 1).left(length);
	}

	/**
	 * @description Checks that a watchdog read found the one seeded call, with its name, its status and its last save
	 * time, and without its request, its response, or the user who created it (a field the watchdog does not use).
	 *
	 * @param foundCalls The calls the read returned
	 * @param seededCall The call the test saved
	 */
	private static void assertFoundWithoutBodyText(List<ApiCall__c> foundCalls, ApiCall__c seededCall)
	{
		Assert.areEqual(1, foundCalls.size(), 'Expected the one seeded call, got ' + foundCalls.size() + ' calls');
		Map<String, Object> populatedFields = foundCalls[0].getPopulatedFieldsAsMap();
		Assert.areEqual(seededCall.Id, foundCalls[0].Id, 'Expected the seeded call');
		Assert.isTrue(populatedFields.containsKey(UTIL_SObjectDescribe.getCachedFieldName(ApiCall__c.Status__c)), 'Expected the status to be read');
		Assert.isTrue(populatedFields.containsKey(UTIL_SObjectDescribe.getCachedFieldName(ApiCall__c.Name)), 'Expected the name to be read');
		Assert.isTrue(populatedFields.containsKey(UTIL_SObjectDescribe.getCachedFieldName(ApiCall__c.LastModifiedDate)), 'Expected the last save time to be read');
		Assert.isFalse(populatedFields.containsKey(UTIL_SObjectDescribe.getCachedFieldName(ApiCall__c.Request__c)), 'Expected the request not to be read');
		Assert.isFalse(populatedFields.containsKey(UTIL_SObjectDescribe.getCachedFieldName(ApiCall__c.Response__c)), 'Expected the response not to be read');
		Assert.isFalse(populatedFields.containsKey(UTIL_SObjectDescribe.getCachedFieldName(ApiCall__c.CreatedById)), 'Expected the creator not to be read');
	}

	/**
	 * @description Saves calls around a cutoff and checks that the read of stale calls at one status finds only the
	 * outbound calls at that status due before the cutoff, oldest first, with their last save time, and stops at the
	 * row limit.
	 *
	 * @param status The status the read looks for.
	 * @param otherStatus Another status whose stale call the read must leave out.
	 */
	private static void assertFindsStaleCallsOldestFirst(String status, String otherStatus)
	{
		final Integer staleMinutesAgo = -90;
		final Integer olderMinutesAgo = -120;
		final Integer recentMinutesAgo = -30;
		final Integer cutoffMinutesAgo = -60;
		Datetime cutoff = Datetime.now().addMinutes(cutoffMinutesAgo);
		ApiCall__c staleCall = (ApiCall__c)apiCallBuilder(status).withOverride(ApiCall__c.NextRetry__c, Datetime.now().addMinutes(staleMinutesAgo)).build();
		ApiCall__c olderCall = (ApiCall__c)apiCallBuilder(status).withOverride(ApiCall__c.NextRetry__c, Datetime.now().addMinutes(olderMinutesAgo)).build();
		apiCallBuilder(status).withOverride(ApiCall__c.NextRetry__c, Datetime.now().addMinutes(recentMinutesAgo)).build();
		apiCallBuilder(status).withOverride(ApiCall__c.NextRetry__c, null).build();
		apiCallBuilder(status, SEL_ApiCall.TYPE_INBOUND).withOverride(ApiCall__c.NextRetry__c, Datetime.now().addMinutes(staleMinutesAgo)).build();
		apiCallBuilder(otherStatus).withOverride(ApiCall__c.NextRetry__c, Datetime.now().addMinutes(staleMinutesAgo)).build();
		SEL_ApiCall selector = new SEL_ApiCall();

		List<ApiCall__c> foundCalls = status == SEL_ApiCall.STATUS_RETRY
				? selector.findOutboundRetryDueBefore(cutoff, ROW_LIMIT)
				: selector.findOutboundRetryingDueBefore(cutoff, ROW_LIMIT);
		List<ApiCall__c> limitedCalls = status == SEL_ApiCall.STATUS_RETRY
				? selector.findOutboundRetryDueBefore(cutoff, 1)
				: selector.findOutboundRetryingDueBefore(cutoff, 1);

		Assert.areEqual(new List<Id> {olderCall.Id, staleCall.Id}, extractIdsInOrder(foundCalls), 'Expected the two stale outbound calls, oldest first.');
		for(ApiCall__c foundCall : foundCalls)
		{
			Assert.isNotNull(foundCall.LastModifiedDate, 'Expected the last save time to be read, because the next wait is worked out from it.');
		}
		Assert.areEqual(new List<Id> {olderCall.Id}, extractIdsInOrder(limitedCalls), 'Expected the row limit to keep only the oldest call.');
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
	 * @description The read by record Ids that the bulk retry uses still finds an open call whose Triggering Record
	 * Index is blank, as on a call saved before the field existed. The new finder by record Ids does not find that call,
	 * which shows the field really is blank.
	 *
	 * @see SEL_ApiCall.findOpenByTriggeringRecordIds
	 */
	@SuppressWarnings('PMD.KernSecurityBypassCallSite')
	@IsTest
	private static void shouldFindAnOpenCallWhoseIndexFieldIsBlank()
	{
		Id triggeringRecordId = UTIL_Random.randomId(Foobar__c.SObjectType);
		TRG_Base.bypassAction(INDEX_ACTION_NAME);
		List<ApiCall__c> seededCalls = seedOpenAndFinishedCalls(triggeringRecordId);

		List<ApiCall__c> foundCalls = new SEL_ApiCall().findOpenByTriggeringRecordIds(new Set<Id> {triggeringRecordId});
		List<ApiCall__c> callsFoundByIds = findByIdsAsAdministrator(new Set<Id> {triggeringRecordId}, ROW_LIMIT);

		Assert.areEqual(collectOpenCallIds(seededCalls), UTIL_SObject.extractIds(foundCalls), 'Expected every open call, got ' + foundCalls);
		Assert.isTrue(callsFoundByIds.isEmpty(), 'Expected the finder by Ids to find no call, because Triggering Record Index was left blank, got '
				+ callsFoundByIds);
	}

	/**
	 * @description Both finders return the newest calls first. Two calls saved at the same moment come in the order of
	 * their own Id, highest first, and an older call comes after them even though its Id is the highest.
	 *
	 * @see SEL_ApiCall.findByTriggeringRecordIds
	 * @see SEL_ApiCall.findByTriggeringRecordValues
	 */
	@IsTest
	private static void shouldReturnRowsNewestFirstWithIdBreakingTies()
	{
		Id triggeringRecordId = UTIL_Random.randomId(Foobar__c.SObjectType);
		List<ApiCall__c> seededCalls = seedCallsFor(triggeringRecordId, 3);
		Datetime savedAt = Datetime.now().addHours(-1);
		Test.setCreatedDate(seededCalls[0].Id, savedAt);
		Test.setCreatedDate(seededCalls[1].Id, savedAt);
		Test.setCreatedDate(seededCalls[2].Id, savedAt.addDays(-1));
		List<Id> expectedOrder = new List<Id> {seededCalls[1].Id, seededCalls[0].Id, seededCalls[2].Id};

		List<ApiCall__c> callsFoundById = findByIdsAsAdministrator(new Set<Id> {triggeringRecordId}, ROW_LIMIT);
		List<ApiCall__c> callsFoundByValue = findByValuesAsAdministrator(new Set<String> {triggeringRecordId}, ROW_LIMIT);

		Assert.areEqual(expectedOrder, extractIdsInOrder(callsFoundById), 'Expected the newest calls first, the higher Id first on a tie');
		Assert.areEqual(expectedOrder, extractIdsInOrder(callsFoundByValue), 'Expected the newest calls first, the higher Id first on a tie');
	}

	/**
	 * @description Both finders return no more calls than the row limit.
	 *
	 * @see SEL_ApiCall.findByTriggeringRecordIds
	 * @see SEL_ApiCall.findByTriggeringRecordValues
	 */
	@IsTest
	private static void shouldStopAtTheRowLimit()
	{
		Id triggeringRecordId = UTIL_Random.randomId(Foobar__c.SObjectType);
		seedCallsFor(triggeringRecordId, 3);
		Integer rowLimit = 2;

		List<ApiCall__c> callsFoundById = findByIdsAsAdministrator(new Set<Id> {triggeringRecordId}, rowLimit);
		List<ApiCall__c> callsFoundByValue = findByValuesAsAdministrator(new Set<String> {triggeringRecordId}, rowLimit);

		Assert.areEqual(rowLimit, callsFoundById.size(), 'Expected the finder by Ids to stop at the row limit, got ' + callsFoundById);
		Assert.areEqual(rowLimit, callsFoundByValue.size(), 'Expected the finder by values to stop at the row limit, got ' + callsFoundByValue);
	}

	/**
	 * @description Both finders return an empty list for an empty set, and run no query.
	 *
	 * @see SEL_ApiCall.findByTriggeringRecordIds
	 * @see SEL_ApiCall.findByTriggeringRecordValues
	 */
	@IsTest
	private static void shouldReturnAnEmptyListAndIssueNoQueryForAnEmptySet()
	{
		Integer queriesBefore = UTIL_Limits.soqlQueries().used();

		List<ApiCall__c> callsFoundById = new SEL_ApiCall().findByTriggeringRecordIds(new Set<Id>(), ROW_LIMIT);
		List<ApiCall__c> callsFoundByValue = new SEL_ApiCall().findByTriggeringRecordValues(new Set<String>(), ROW_LIMIT);

		Assert.areEqual(queriesBefore, UTIL_Limits.soqlQueries().used(), 'Expected no query for an empty set');
		Assert.isTrue(callsFoundById.isEmpty(), 'Expected an empty list from the finder by Ids, got ' + callsFoundById);
		Assert.isTrue(callsFoundByValue.isEmpty(), 'Expected an empty list from the finder by values, got ' + callsFoundByValue);
	}

	/**
	 * @description Both finders return an empty list, and run no query, for a set that holds only null, or for the finder
	 * by values only null and blank values.
	 *
	 * @see SEL_ApiCall.findByTriggeringRecordIds
	 * @see SEL_ApiCall.findByTriggeringRecordValues
	 */
	@IsTest
	private static void shouldReturnAnEmptyListAndIssueNoQueryForASetHoldingOnlyNull()
	{
		Integer queriesBefore = UTIL_Limits.soqlQueries().used();

		List<ApiCall__c> callsFoundById = new SEL_ApiCall().findByTriggeringRecordIds(new Set<Id> {null}, ROW_LIMIT);
		List<ApiCall__c> callsFoundByValue = new SEL_ApiCall().findByTriggeringRecordValues(new Set<String> {null, UTIL_String.EMPTY, UTIL_String.SPACE}, ROW_LIMIT);

		Assert.areEqual(queriesBefore, UTIL_Limits.soqlQueries().used(), 'Expected no query for a set with nothing to look for');
		Assert.isTrue(callsFoundById.isEmpty(), 'Expected an empty list from the finder by Ids, got ' + callsFoundById);
		Assert.isTrue(callsFoundByValue.isEmpty(), 'Expected an empty list from the finder by values, got ' + callsFoundByValue);
	}

	/**
	 * @description Both finders leave the set they are given as it was, null and blank values included, and still find
	 * the call for the value in it.
	 *
	 * @see SEL_ApiCall.findByTriggeringRecordIds
	 * @see SEL_ApiCall.findByTriggeringRecordValues
	 */
	@IsTest
	private static void shouldNotChangeTheCallersSet()
	{
		Id triggeringRecordId = UTIL_Random.randomId(Foobar__c.SObjectType);
		ApiCall__c seededCall = seedCallsFor(triggeringRecordId, 1)[0];
		Set<Id> recordIds = new Set<Id> {triggeringRecordId, null};
		Set<String> values = new Set<String> {triggeringRecordId, null, UTIL_String.EMPTY};

		List<ApiCall__c> callsFoundById = findByIdsAsAdministrator(recordIds, ROW_LIMIT);
		List<ApiCall__c> callsFoundByValue = findByValuesAsAdministrator(values, ROW_LIMIT);

		Assert.areEqual(new Set<Id> {triggeringRecordId, null}, recordIds, 'Expected the set of Ids to be unchanged');
		Assert.areEqual(new Set<String> {triggeringRecordId, null, UTIL_String.EMPTY}, values, 'Expected the set of values to be unchanged');
		Assert.areEqual(new List<Id> {seededCall.Id}, extractIdsInOrder(callsFoundById), 'Expected the call by Id, got ' + callsFoundById);
		Assert.areEqual(new List<Id> {seededCall.Id}, extractIdsInOrder(callsFoundByValue), 'Expected the call by value, got ' + callsFoundByValue);
	}

	/**
	 * @description Both finders refuse a null set with an IllegalArgumentException.
	 *
	 * @see SEL_ApiCall.findByTriggeringRecordIds
	 * @see SEL_ApiCall.findByTriggeringRecordValues
	 */
	@IsTest
	private static void shouldRefuseANullSet()
	{
		try
		{
			new SEL_ApiCall().findByTriggeringRecordIds(null, ROW_LIMIT);
			Assert.fail('Expected the finder by Ids to refuse a null set');
		}
		catch(Exception error)
		{
			Assert.isInstanceOfType(error, IllegalArgumentException.class, 'Expected an IllegalArgumentException, got ' + error);
		}
		try
		{
			new SEL_ApiCall().findByTriggeringRecordValues(null, ROW_LIMIT);
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
	 * @see SEL_ApiCall.findByTriggeringRecordIds
	 * @see SEL_ApiCall.findByTriggeringRecordValues
	 */
	@IsTest
	private static void shouldRefuseARowLimitBelowOne()
	{
		for(Integer rowLimit : new List<Integer> {null, 0, -1})
		{
			try
			{
				new SEL_ApiCall().findByTriggeringRecordIds(new Set<Id>(), rowLimit);
				Assert.fail('Expected the finder by Ids to refuse the row limit ' + rowLimit);
			}
			catch(Exception error)
			{
				Assert.isInstanceOfType(error, IllegalArgumentException.class, 'Expected an IllegalArgumentException, got ' + error);
			}
			try
			{
				new SEL_ApiCall().findByTriggeringRecordValues(new Set<String>(), rowLimit);
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
	 * and Triggering Record Index. The request, the response and the parameters are not read, even when the call holds them.
	 *
	 * @see SEL_ApiCall.findByTriggeringRecordIds
	 * @see SEL_ApiCall.findByTriggeringRecordValues
	 */
	@IsTest
	private static void shouldReturnOnlySummaryFields()
	{
		Id triggeringRecordId = UTIL_Random.randomId(Foobar__c.SObjectType);
		apiCallBuilder(SEL_ApiCall.STATUS_FAILED)
				.withOverrides(new Map<SObjectField, Object>
				{
						ApiCall__c.TriggeringRecordId__c => triggeringRecordId,
						ApiCall__c.Request__c => UTIL_Random.randomName(),
						ApiCall__c.Response__c => UTIL_Random.randomName(),
						ApiCall__c.RequestParameters__c => UTIL_Random.randomName()
				})
				.build();

		List<ApiCall__c> foundCalls = findByIdsAsAdministrator(new Set<Id> {triggeringRecordId}, ROW_LIMIT);
		foundCalls.addAll(findByValuesAsAdministrator(new Set<String> {triggeringRecordId}, ROW_LIMIT));

		Assert.areEqual(2, foundCalls.size(), 'Expected the call once from each finder, got ' + foundCalls);
		List<SObjectField> summaryFields = new List<SObjectField>
		{
				ApiCall__c.Id, ApiCall__c.ServiceName__c, ApiCall__c.Status__c, ApiCall__c.CreatedDate, ApiCall__c.TriggeringRecordIndex__c
		};
		for(ApiCall__c foundCall : foundCalls)
		{
			Map<String, Object> populatedFields = foundCall.getPopulatedFieldsAsMap();
			Assert.areEqual(summaryFields.size(), populatedFields.size(), 'Expected only the summary fields, got ' + populatedFields.keySet());
			for(SObjectField summaryField : summaryFields)
			{
				Assert.isTrue(foundCall.isSet(summaryField), 'Expected the summary field to be read: ' + summaryField);
			}
			Assert.isFalse(foundCall.isSet(ApiCall__c.Request__c), 'Expected the request not to be read');
			Assert.isFalse(foundCall.isSet(ApiCall__c.Response__c), 'Expected the response not to be read');
			Assert.isFalse(foundCall.isSet(ApiCall__c.RequestParameters__c), 'Expected the parameters not to be read');
		}
	}

	/**
	 * @description A user who may read calls and their summary fields, but to whom record sharing gives no access to a
	 * call another user owns, gets no call from either finder.
	 *
	 * @see SEL_ApiCall.findByTriggeringRecordIds
	 * @see SEL_ApiCall.findByTriggeringRecordValues
	 */
	@IsTest
	private static void shouldHideARowFromAUserWithoutSharing()
	{
		Id triggeringRecordId = UTIL_Random.randomId(Foobar__c.SObjectType);
		seedCallsFor(triggeringRecordId, 1);
		User reader = insertReaderWithHiddenField(ApiCall__c.Response__c);

		List<ApiCall__c> callsFoundById = findByIdsAsUser(reader, new Set<Id> {triggeringRecordId}, ROW_LIMIT);
		List<ApiCall__c> callsFoundByValue = findByValuesAsUser(reader, new Set<String> {triggeringRecordId}, ROW_LIMIT);

		Assert.isTrue(callsFoundById.isEmpty(), 'Expected sharing to hide the call from the finder by Ids, got ' + callsFoundById);
		Assert.isTrue(callsFoundByValue.isEmpty(), 'Expected sharing to hide the call from the finder by values, got ' + callsFoundByValue);
	}

	/**
	 * @description A user who may read calls and their summary fields gets a call another user owns once that call is
	 * shared with them, from both finders.
	 *
	 * @see SEL_ApiCall.findByTriggeringRecordIds
	 * @see SEL_ApiCall.findByTriggeringRecordValues
	 */
	@IsTest
	private static void shouldReturnARowToAUserItIsSharedWith()
	{
		Id triggeringRecordId = UTIL_Random.randomId(Foobar__c.SObjectType);
		ApiCall__c seededCall = seedCallsFor(triggeringRecordId, 1)[0];
		User reader = insertReaderWithHiddenField(ApiCall__c.Response__c);
		DML_Builder.newTransaction().doInsert(TST_Factory.newSObjectShare(seededCall.Id, SHARE_ACCESS_READ, reader.Id)).execute();

		List<ApiCall__c> callsFoundById = findByIdsAsUser(reader, new Set<Id> {triggeringRecordId}, ROW_LIMIT);
		List<ApiCall__c> callsFoundByValue = findByValuesAsUser(reader, new Set<String> {triggeringRecordId}, ROW_LIMIT);

		Assert.areEqual(new List<Id> {seededCall.Id}, extractIdsInOrder(callsFoundById), 'Expected the shared call by Id, got ' + callsFoundById);
		Assert.areEqual(new List<Id> {seededCall.Id}, extractIdsInOrder(callsFoundByValue), 'Expected the shared call by value, got ' + callsFoundByValue);
	}

	/**
	 * @description Both finders fail with a QueryException for a user who may read calls but not their Triggering Record Index field. This
	 * proves the finders read with the user's field access (user mode): the selector's other reads skip that check.
	 *
	 * @see SEL_ApiCall.findByTriggeringRecordIds
	 * @see SEL_ApiCall.findByTriggeringRecordValues
	 */
	@IsTest
	private static void shouldThrowForAUserWithoutFieldRead()
	{
		Id triggeringRecordId = UTIL_Random.randomId(Foobar__c.SObjectType);
		User reader = insertReaderWithHiddenField(ApiCall__c.TriggeringRecordIndex__c);

		System.runAs(reader)
		{
			try
			{
				new SEL_ApiCall().findByTriggeringRecordIds(new Set<Id> {triggeringRecordId}, ROW_LIMIT);
				Assert.fail('Expected the finder by Ids to fail for a user who cannot read Triggering Record Index');
			}
			catch(Exception error)
			{
				Assert.isInstanceOfType(error, QueryException.class, 'Expected a QueryException, got ' + error);
			}
			try
			{
				new SEL_ApiCall().findByTriggeringRecordValues(new Set<String> {triggeringRecordId}, ROW_LIMIT);
				Assert.fail('Expected the finder by values to fail for a user who cannot read Triggering Record Index');
			}
			catch(Exception error)
			{
				Assert.isInstanceOfType(error, QueryException.class, 'Expected a QueryException, got ' + error);
			}
		}
	}

	/**
	 * @description Both finders fail with a QueryException for a user who may not read calls at all.
	 *
	 * @see SEL_ApiCall.findByTriggeringRecordIds
	 * @see SEL_ApiCall.findByTriggeringRecordValues
	 */
	@IsTest
	private static void shouldThrowForAUserWithoutObjectRead()
	{
		Id triggeringRecordId = UTIL_Random.randomId(Foobar__c.SObjectType);

		System.runAs(getLowPrivilegeUser())
		{
			try
			{
				new SEL_ApiCall().findByTriggeringRecordIds(new Set<Id> {triggeringRecordId}, ROW_LIMIT);
				Assert.fail('Expected the finder by Ids to fail for a user who cannot read calls');
			}
			catch(Exception error)
			{
				Assert.isInstanceOfType(error, QueryException.class, 'Expected a QueryException, got ' + error);
			}
			try
			{
				new SEL_ApiCall().findByTriggeringRecordValues(new Set<String> {triggeringRecordId}, ROW_LIMIT);
				Assert.fail('Expected the finder by values to fail for a user who cannot read calls');
			}
			catch(Exception error)
			{
				Assert.isInstanceOfType(error, QueryException.class, 'Expected a QueryException, got ' + error);
			}
		}
	}

	/**
	 * @description Both finders read a set of 2,000 values in one query and find the call among them.
	 *
	 * @see SEL_ApiCall.findByTriggeringRecordIds
	 * @see SEL_ApiCall.findByTriggeringRecordValues
	 */
	@IsTest
	private static void shouldAcceptTwoThousandIds()
	{
		Id triggeringRecordId = UTIL_Random.randomId(Foobar__c.SObjectType);
		ApiCall__c seededCall = seedCallsFor(triggeringRecordId, 1)[0];
		Set<Id> recordIds = new Set<Id> {triggeringRecordId};
		while(recordIds.size() < LARGE_SET_SIZE)
		{
			recordIds.add(UTIL_Random.randomId(Foobar__c.SObjectType));
		}
		Set<String> values = new Set<String>((List<String>)new List<Id>(recordIds));

		List<ApiCall__c> callsFoundById;
		List<ApiCall__c> callsFoundByValue;
		Integer queriesById;
		Integer queriesByValue;

		System.runAs(getTestAdmin())
		{
			Integer queriesBefore = UTIL_Limits.soqlQueries().used();
			callsFoundById = new SEL_ApiCall().findByTriggeringRecordIds(recordIds, ROW_LIMIT);
			queriesById = UTIL_Limits.soqlQueries().used() - queriesBefore;
			callsFoundByValue = new SEL_ApiCall().findByTriggeringRecordValues(values, ROW_LIMIT);
			queriesByValue = UTIL_Limits.soqlQueries().used() - queriesBefore - queriesById;
		}

		Assert.areEqual(1, queriesById, 'Expected the finder by Ids to run one query');
		Assert.areEqual(1, queriesByValue, 'Expected the finder by values to run one query');
		Assert.areEqual(new List<Id> {seededCall.Id}, extractIdsInOrder(callsFoundById), 'Expected the call by Id, got ' + callsFoundById);
		Assert.areEqual(new List<Id> {seededCall.Id}, extractIdsInOrder(callsFoundByValue), 'Expected the call by value, got ' + callsFoundByValue);
	}

	/**
	 * @description In a test, both finders filter the mocked calls the way the query does: only a mock whose Triggering
	 * Record Index holds a searched value comes back. A mock with a blank index, with another record's Id, or with the
	 * searched value in another case is left out.
	 *
	 * @see SEL_ApiCall.findByTriggeringRecordIds
	 * @see SEL_ApiCall.findByTriggeringRecordValues
	 */
	@IsTest
	private static void shouldReturnOnlyMockedRowsWithAMatchingIndex()
	{
		Id triggeringRecordId = UTIL_Random.randomId(Foobar__c.SObjectType);
		String searchedValue = String.valueOf(triggeringRecordId);
		String valueInAnotherCase = searchedValue.toLowerCase().equals(searchedValue) ? searchedValue.toUpperCase() : searchedValue.toLowerCase();
		Assert.areNotEqual(searchedValue, valueInAnotherCase, 'Expected the searched value to hold a letter, so it has another case');
		ApiCall__c matchingMock = (ApiCall__c)TST_Mock.of(ApiCall__c.SObjectType)
				.withOverride(ApiCall__c.TriggeringRecordIndex__c, String.valueOf(triggeringRecordId))
				.build();
		TST_Mock.of(ApiCall__c.SObjectType)
				.withOverride(ApiCall__c.TriggeringRecordIndex__c, String.valueOf(UTIL_Random.randomId(Foobar__c.SObjectType)))
				.build();
		TST_Mock.of(ApiCall__c.SObjectType).withOverride(ApiCall__c.TriggeringRecordIndex__c, null).build();
		TST_Mock.of(ApiCall__c.SObjectType)
				.withOverride(ApiCall__c.TriggeringRecordIndex__c, valueInAnotherCase)
				.build();
		Set<Id> expectedIds = new Set<Id> {matchingMock.Id};

		List<ApiCall__c> callsFoundById = findByIdsAsAdministrator(new Set<Id> {triggeringRecordId}, ROW_LIMIT);
		List<ApiCall__c> callsFoundByValue = findByValuesAsAdministrator(new Set<String> {triggeringRecordId}, ROW_LIMIT);

		Assert.areEqual(expectedIds, new Set<Id>(extractIdsInOrder(callsFoundById)), 'Expected only the matching mock by Id, got ' + callsFoundById);
		Assert.areEqual(expectedIds, new Set<Id>(extractIdsInOrder(callsFoundByValue)), 'Expected only the matching mock by value, got ' + callsFoundByValue);
	}

	/**
	 * @description In a test, the finder by Ids still filters the mocked calls when it searches for 200 records: the 200
	 * matching mocks come back, and a mock for another record is left out.
	 *
	 * @see SEL_ApiCall.findByTriggeringRecordIds
	 */
	@IsTest
	private static void shouldReturnOnlyMatchingMocksForTwoHundredRecords()
	{
		Set<Id> recordIds = new Set<Id>();
		while(recordIds.size() < MOCKED_RECORD_COUNT)
		{
			recordIds.add(UTIL_Random.randomId(Foobar__c.SObjectType));
		}
		Set<Id> expectedIds = new Set<Id>();
		for(Id recordId : recordIds)
		{
			ApiCall__c matchingMock = (ApiCall__c)TST_Mock.of(ApiCall__c.SObjectType)
					.withOverride(ApiCall__c.TriggeringRecordIndex__c, String.valueOf(recordId))
					.build();
			expectedIds.add(matchingMock.Id);
		}
		Id otherRecordId = UTIL_Random.randomId(Foobar__c.SObjectType);
		Assert.isFalse(recordIds.contains(otherRecordId), 'Expected the other record Id to be outside the searched Ids');
		ApiCall__c otherMock = (ApiCall__c)TST_Mock.of(ApiCall__c.SObjectType)
				.withOverride(ApiCall__c.TriggeringRecordIndex__c, String.valueOf(otherRecordId))
				.build();

		List<ApiCall__c> foundCalls = findByIdsAsAdministrator(recordIds, MOCKED_RECORD_COUNT + 1);

		Set<Id> foundIds = new Set<Id>(extractIdsInOrder(foundCalls));
		Assert.areEqual(MOCKED_RECORD_COUNT, foundCalls.size(), 'Expected one call for each searched record, got ' + foundCalls.size());
		Assert.areEqual(expectedIds, foundIds, 'Expected exactly the matching mocks');
		Assert.isFalse(foundIds.contains(otherMock.Id), 'Expected the mock for another record to be left out');
	}

	/**
	 * @description In a test, TST_Mock.registerNext scripts what each finder reads. The scripted calls are filtered by
	 * the finder's conditions too, so a scripted call that holds the searched record comes back. This is how a test of
	 * code that calls a finder chooses the calls it gets: give the scripted calls the values the finder searches for.
	 *
	 * @see SEL_ApiCall.findByTriggeringRecordIds
	 * @see SEL_ApiCall.findByTriggeringRecordValues
	 */
	@IsTest
	private static void shouldReturnTheAnswerScriptedWithRegisterNext()
	{
		Id triggeringRecordId = UTIL_Random.randomId(Foobar__c.SObjectType);
		ApiCall__c scriptedCall = (ApiCall__c)TST_Builder.of(ApiCall__c.SObjectType)
				.withOverride(ApiCall__c.TriggeringRecordIndex__c, String.valueOf(triggeringRecordId))
				.withoutInsertion(true)
				.build();
		List<Id> scriptedIds = new List<Id> {scriptedCall.Id};

		TST_Mock.registerNext(ApiCall__c.SObjectType, scriptedCall);
		List<ApiCall__c> callsFoundById = findByIdsAsAdministrator(new Set<Id> {triggeringRecordId}, ROW_LIMIT);
		TST_Mock.registerNext(ApiCall__c.SObjectType, scriptedCall);
		List<ApiCall__c> callsFoundByValue = findByValuesAsAdministrator(new Set<String> {triggeringRecordId}, ROW_LIMIT);

		Assert.areEqual(scriptedIds, extractIdsInOrder(callsFoundById), 'Expected the scripted call by Id, got ' + callsFoundById);
		Assert.areEqual(scriptedIds, extractIdsInOrder(callsFoundByValue), 'Expected the scripted call by value, got ' + callsFoundByValue);
	}

	/**
	 * @description The finder by Ids searches only the full form of 18 characters, so it does not find a call whose
	 * triggering record Id was written in the short form of 15 characters.
	 *
	 * @see SEL_ApiCall.findByTriggeringRecordIds
	 */
	@IsTest
	private static void shouldNotFindAValueStoredInTheFifteenCharacterForm()
	{
		Id triggeringRecordId = UTIL_Random.randomId(Foobar__c.SObjectType);
		seedCallsFor(String.valueOf(triggeringRecordId).left(SHORT_ID_LENGTH), 1);

		List<ApiCall__c> foundCalls = findByIdsAsAdministrator(new Set<Id> {triggeringRecordId}, ROW_LIMIT);

		Assert.isTrue(foundCalls.isEmpty(), 'Expected no call stored with the short form, got ' + foundCalls);
	}

	/**
	 * @description The finder by values matches any text, so it also finds a call whose triggering record Id was written
	 * in the short form of 15 characters when given that text. This only records how the finder behaves: it is not the
	 * way to search by record Id, because its match ignores case.
	 *
	 * @see SEL_ApiCall.findByTriggeringRecordValues
	 */
	@IsTest
	private static void shouldFindAFifteenCharacterValueThroughTheTextFinder()
	{
		String shortForm = String.valueOf(UTIL_Random.randomId(Foobar__c.SObjectType)).left(SHORT_ID_LENGTH);
		ApiCall__c seededCall = seedCallsFor(shortForm, 1)[0];

		List<ApiCall__c> foundCalls = findByValuesAsAdministrator(new Set<String> {shortForm}, ROW_LIMIT);

		Assert.areEqual(new List<Id> {seededCall.Id}, extractIdsInOrder(foundCalls), 'Expected the call stored with the short form, got ' + foundCalls);
	}

	/**
	 * @description The finder by Ids finds a call whose triggering record Id was written in the full form of 18
	 * characters, as the framework writes it.
	 *
	 * @see SEL_ApiCall.findByTriggeringRecordIds
	 */
	@IsTest
	private static void shouldFindARowStoredWithTheEighteenCharacterForm()
	{
		Id triggeringRecordId = UTIL_Random.randomId(Foobar__c.SObjectType);
		ApiCall__c seededCall = seedCallsFor(triggeringRecordId, 1)[0];

		List<ApiCall__c> foundCalls = findByIdsAsAdministrator(new Set<Id> {triggeringRecordId}, ROW_LIMIT);

		Assert.areEqual(new List<Id> {seededCall.Id}, extractIdsInOrder(foundCalls), 'Expected the call stored with the full form, got ' + foundCalls);
	}

	/**
	 * @description The finder by Ids finds a call whose triggering record Id was written in the full form of 18
	 * characters with the case of every letter changed. The search ignores case, and that is safe for the full form: its
	 * last three characters tell apart two Ids that differ only in case.
	 *
	 * @see SEL_ApiCall.findByTriggeringRecordIds
	 */
	@IsTest
	private static void shouldFindAValueStoredInTheEighteenCharacterFormInAnotherCase()
	{
		Id triggeringRecordId = UTIL_Random.randomId(Foobar__c.SObjectType);
		String otherCase = String.valueOf(triggeringRecordId).swapCase();
		Assert.isFalse(otherCase.equals(String.valueOf(triggeringRecordId)), 'Expected the stored value to differ in case from the Id');
		ApiCall__c seededCall = seedCallsFor(otherCase, 1)[0];

		List<ApiCall__c> foundCalls = findByIdsAsAdministrator(new Set<Id> {triggeringRecordId}, ROW_LIMIT);

		Assert.areEqual(new List<Id> {seededCall.Id}, extractIdsInOrder(foundCalls), 'Expected the call stored in another case, got ' + foundCalls);
	}

	/**
	 * @description The finder by values finds a call made for a reference from another system, which is not a record Id.
	 *
	 * @see SEL_ApiCall.findByTriggeringRecordValues
	 */
	@IsTest
	private static void shouldFindAValueThatIsNotARecordId()
	{
		String reference = OTHER_SYSTEM_REFERENCE_PREFIX + UTIL_Random.randomAlphanumeric(REFERENCE_RANDOM_LENGTH);
		ApiCall__c seededCall = seedCallsFor(reference, 1)[0];

		List<ApiCall__c> foundCalls = findByValuesAsAdministrator(new Set<String> {reference}, ROW_LIMIT);

		Assert.areEqual(new List<Id> {seededCall.Id}, extractIdsInOrder(foundCalls), 'Expected the call made for the reference, got ' + foundCalls);
	}

	/**
	 * @description The finder by values ignores blank values in the set and finds the call for the value beside them.
	 *
	 * @see SEL_ApiCall.findByTriggeringRecordValues
	 */
	@IsTest
	private static void shouldIgnoreABlankElement()
	{
		String reference = OTHER_SYSTEM_REFERENCE_PREFIX + UTIL_Random.randomAlphanumeric(REFERENCE_RANDOM_LENGTH);
		ApiCall__c seededCall = seedCallsFor(reference, 1)[0];

		List<ApiCall__c> foundCalls = findByValuesAsAdministrator(new Set<String> {reference, UTIL_String.EMPTY, UTIL_String.SPACE}, ROW_LIMIT);

		Assert.areEqual(new List<Id> {seededCall.Id}, extractIdsInOrder(foundCalls), 'Expected the call made for the reference, got ' + foundCalls);
	}

	/**
	 * @description The finder by values ignores upper and lower case: a value written in upper case finds a call whose
	 * Triggering Record Index is in lower case.
	 *
	 * @see SEL_ApiCall.findByTriggeringRecordValues
	 */
	@IsTest
	private static void shouldMatchAValueWrittenInAnotherCase()
	{
		String reference = (OTHER_SYSTEM_REFERENCE_PREFIX + UTIL_Random.randomAlphanumeric(REFERENCE_RANDOM_LENGTH)).toLowerCase();
		ApiCall__c seededCall = seedCallsFor(reference, 1)[0];

		List<ApiCall__c> foundCalls = findByValuesAsAdministrator(new Set<String> {reference.toUpperCase()}, ROW_LIMIT);

		Assert.areEqual(new List<Id> {seededCall.Id}, extractIdsInOrder(foundCalls), 'Expected the call whose Triggering Record Index is in another case, got ' + foundCalls);
	}

	/**
	 * @description Saves failed outbound calls for the test service, all made for the same triggering value.
	 *
	 * @param triggeringValue The value written as the triggering record Id of each call
	 * @param numberOfCalls How many calls to save
	 *
	 * @return The saved calls, in the order they were saved
	 */
	private static List<ApiCall__c> seedCallsFor(String triggeringValue, Integer numberOfCalls)
	{
		return apiCallBuilder(SEL_ApiCall.STATUS_FAILED)
				.withCount(numberOfCalls)
				.withOverride(ApiCall__c.TriggeringRecordId__c, triggeringValue)
				.buildList();
	}

	/**
	 * @description Runs the finder by Ids as the test administrator, who may read calls and every field of a call. The
	 * user who runs the tests may lack read access to the call fields, and the finder checks it.
	 *
	 * @param recordIds The record Ids to look for
	 * @param rowLimit The most calls to return
	 *
	 * @return The calls found
	 */
	private static List<ApiCall__c> findByIdsAsAdministrator(Set<Id> recordIds, Integer rowLimit)
	{
		return findByIdsAsUser(getTestAdmin(), recordIds, rowLimit);
	}

	/**
	 * @description Runs the finder by Ids as the given user, so the user's object, field and sharing access apply.
	 *
	 * @param reader The user who reads
	 * @param recordIds The record Ids to look for
	 * @param rowLimit The most calls to return
	 *
	 * @return The calls found
	 */
	private static List<ApiCall__c> findByIdsAsUser(User reader, Set<Id> recordIds, Integer rowLimit)
	{
		List<ApiCall__c> foundCalls;
		System.runAs(reader)
		{
			foundCalls = new SEL_ApiCall().findByTriggeringRecordIds(recordIds, rowLimit);
		}
		return foundCalls;
	}

	/**
	 * @description Runs the finder by values as the given user, so the user's object, field and sharing access apply.
	 *
	 * @param reader The user who reads
	 * @param values The values to look for
	 * @param rowLimit The most calls to return
	 *
	 * @return The calls found
	 */
	private static List<ApiCall__c> findByValuesAsUser(User reader, Set<String> values, Integer rowLimit)
	{
		List<ApiCall__c> foundCalls;
		System.runAs(reader)
		{
			foundCalls = new SEL_ApiCall().findByTriggeringRecordValues(values, rowLimit);
		}
		return foundCalls;
	}

	/**
	 * @description Runs the finder by values as the test administrator, who may read calls and every field of a call. The
	 * user who runs the tests may lack read access to the call fields, and the finder checks it.
	 *
	 * @param values The values to look for
	 * @param rowLimit The most calls to return
	 *
	 * @return The calls found
	 */
	private static List<ApiCall__c> findByValuesAsAdministrator(Set<String> values, Integer rowLimit)
	{
		return findByValuesAsUser(getTestAdmin(), values, rowLimit);
	}

	/**
	 * @description Saves a Minimum Access user with a permission set made for the test: read access to calls and to
	 * every field of a call except one.
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
						new List<SObjectType> {ApiCall__c.SObjectType},
						new List<SObjectField> {ObjectPermissions.PermissionsRead},
						hiddenField
				);
	}

	/**
	 * @description Collects the Ids of the calls in the order they were returned.
	 *
	 * @param calls The calls returned
	 *
	 * @return Their Ids, in order
	 */
	private static List<Id> extractIdsInOrder(List<ApiCall__c> calls)
	{
		List<Id> callIds = new List<Id>();
		for(ApiCall__c call : calls)
		{
			callIds.add(call.Id);
		}
		return callIds;
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