// SPDX-License-Identifier: Apache-2.0
/**
 * @description Tests what an inbound request does with the earlier calls of the same request. Two calls are of the same
 * request when the same user sent them to the same service with the same Idempotency-Key. When another person runs an
 * issue's request again, the call of that run still counts as a call of the user who sent the request. A call is a
 * retry of an earlier one when it also received the same body. When the service has Idempotency Enabled, a retry links
 * to the newest earlier call that its sender created and that did not complete (PreviousAttempt__c). When the service
 * also has Resolve Issues on, a request that succeeds with a status from 200 to 299 marks Resolved the open issues of
 * every earlier call of the same request, whatever body that call received. A failed request writes no issue when an
 * earlier call of the same request already holds an open one.
 *
 * @see API_Inbound
 * @see SEL_ApiCall
 *
 * @author Jason van Beukering
 *
 * @group Web Services
 *
 * @date October 2026
 */
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest(seeAllData=false isParallel=true)
private class API_InboundRetryLink_TEST
{
	/**
	 * @description The service the echo endpoint sends its requests to.
	 */
	private static final String SERVICE_NAME = API_Echo.class.getName();

	/**
	 * @description The service of the test handler that can answer with a status a test chooses.
	 */
	private static final String STATUS_ANSWERING_SERVICE_NAME = StatusAnsweringInbound.class.getName();

	/**
	 * @description The service of the test handler whose own error handling throws.
	 */
	private static final String THROWING_ERROR_HANDLING_SERVICE_NAME = ThrowingErrorHandlingInbound.class.getName();

	/**
	 * @description The message the throwing test handler's own error handling throws with.
	 */
	private static final String MESSAGE_ERROR_HANDLING_THREW = 'The error handling threw on purpose';

	/**
	 * @description The path each test request is sent to. It matches the route of the settings the tests register.
	 */
	private static final String REQUEST_PATH = '/echo/test';

	/**
	 * @description The route pattern of the settings the tests register, so a request to the request path finds them.
	 */
	private static final String ROUTE_PATH = '/echo/*';

	/**
	 * @description The routing priority of the settings the tests register. Any value works, because each test registers
	 * one setting.
	 */
	private static final Integer ROUTE_PRIORITY = 100;

	/**
	 * @description The one field of the JSON body each test sends.
	 */
	private static final String BODY_FIELD = 'helloWorld';

	/**
	 * @description The HTTP method each test request uses.
	 */
	private static final String HTTP_METHOD_POST = API_Base.toHttpString(API_Base.HttpMethod.POST);

	/**
	 * @description How many queries a successful request that carries an Idempotency-Key makes, once the settings a
	 * transaction keeps are read: the read of the switch that can turn off every API, and the one read of the earlier
	 * calls with the same key. It is the same number for a request whose key has no earlier call.
	 */
	private static final Integer QUERIES_OF_A_KEYED_REQUEST = 2;

	/**
	 * @description A stored time keeps whole seconds, so a time read back is compared with a bound one second earlier
	 * than the time the test took before the request.
	 */
	private static final Integer ONE_SECOND_TOLERANCE = 1;

	/**
	 * @description How many failed calls of one request a test saves: one more than the read of a key returns, so that
	 * read leaves out one of them.
	 */
	private static final Integer MORE_CALLS_THAN_THE_KEY_READ_RETURNS = SEL_ApiCall.MAXIMUM_CALLS_PER_IDEMPOTENCY_KEY + 1;

	/**
	 * @description The status code the test handler answers with on purpose, or null to let the framework answer 200.
	 */
	private static Integer answeredStatusCode;

	/**
	 * @description A caller sends a request with a key, the request fails, and the caller sends the same body with the same
	 * key again. The retry succeeds, links to the failed call, and marks the issue of the failed call Resolved with the
	 * time it was resolved.
	 */
	@IsTest
	private static void shouldLinkAndResolveWhenTheCallerRetriesWithTheSameKey()
	{
		registerSetting(SERVICE_NAME, null);
		String body = buildBody();
		String idempotencyKey = UTIL_Random.randomUUID();
		ApiCall__c failedCall = runFailingRequest(SERVICE_NAME, body, idempotencyKey);
		ApiIssue__c openIssue = findOneIssue();
		Datetime resolvedAfter = Datetime.now().addSeconds(-ONE_SECOND_TOLERANCE);

		Test.startTest();
		ApiCall__c retryCall = runRequest(SERVICE_NAME, body, idempotencyKey);
		Test.stopTest();

		Assert.areEqual(SEL_ApiCall.STATUS_COMPLETED, retryCall.Status__c, 'Expected the retry to complete, got ' + retryCall.Status__c);
		Assert.areEqual(failedCall.Id, retryCall.PreviousAttempt__c, 'Expected the retry to link to the failed call');
		ApiIssue__c resolvedIssue = (ApiIssue__c)new SEL_ApiIssue().findById(openIssue.Id);
		Assert.areEqual(SEL_ApiIssue.STATUS_RESOLVED, resolvedIssue.Status__c, 'Expected the issue of the failed call to be resolved');
		Assert.isTrue(resolvedIssue.ResolvedDate__c >= resolvedAfter, 'Expected the issue to record when it was resolved, got ' + resolvedIssue.ResolvedDate__c);
	}

	/**
	 * @description With Resolve Issues off, a retry with the same key and body still links to the failed call, but the
	 * issue of the failed call stays Open.
	 */
	@IsTest
	private static void shouldLinkButNotResolveWhenResolveIssuesIsOff()
	{
		registerSetting(SERVICE_NAME, new Map<SObjectField, Object> {ApiSetting__mdt.ResolveIssues__c => false});
		String body = buildBody();
		String idempotencyKey = UTIL_Random.randomUUID();
		ApiCall__c failedCall = runFailingRequest(SERVICE_NAME, body, idempotencyKey);
		ApiIssue__c openIssue = findOneIssue();

		Test.startTest();
		ApiCall__c retryCall = runRequest(SERVICE_NAME, body, idempotencyKey);
		Test.stopTest();

		Assert.areEqual(failedCall.Id, retryCall.PreviousAttempt__c, 'Expected the retry to link to the failed call');
		assertIssueOpen(openIssue.Id);
	}

	/**
	 * @description A caller whose request failed corrects the body and sends it with the same key. The corrected request is
	 * not a retry, because its body differs, so it does not link to the failed call. Its success still marks the issue of
	 * the failed call Resolved, because the key names one operation and that operation is now done. A later request that
	 * sends the first body with the same key is refused with status 409.
	 */
	@IsTest
	private static void shouldResolveButNotLinkACorrectedRequest()
	{
		registerSetting(SERVICE_NAME, null);
		String firstBody = buildBody();
		String idempotencyKey = UTIL_Random.randomUUID();
		runFailingRequest(SERVICE_NAME, firstBody, idempotencyKey);
		ApiIssue__c openIssue = findOneIssue();

		Test.startTest();
		ApiCall__c correctedCall = runRequest(SERVICE_NAME, buildBody(), idempotencyKey);
		runRequest(SERVICE_NAME, firstBody, idempotencyKey);
		Test.stopTest();

		Assert.areEqual(SEL_ApiCall.STATUS_COMPLETED, correctedCall.Status__c, 'Expected the corrected request to complete, got ' + correctedCall.Status__c);
		Assert.isNull(correctedCall.PreviousAttempt__c, 'Expected a request with another body not to link to the failed call');
		Assert.areEqual(SEL_ApiIssue.STATUS_RESOLVED, ((ApiIssue__c)new SEL_ApiIssue().findById(openIssue.Id)).Status__c, 'Expected the issue to be resolved');
		Assert.areEqual(API_Base.HTTP_CONFLICT, RestContext.response.statusCode, 'Expected the first body sent again with the key to be refused with 409');
	}

	/**
	 * @description A request fails twice with the same key and body, then succeeds. Each call links to the one before it.
	 * The second failure writes no issue of its own, so a second open issue is saved for it here, as a call saved before
	 * this rule existed may hold one. The success marks every open issue of the earlier calls Resolved, with one time.
	 */
	@IsTest
	private static void shouldResolveEveryEarlierAttemptOfTheRequest()
	{
		registerSetting(SERVICE_NAME, null);
		String body = buildBody();
		String idempotencyKey = UTIL_Random.randomUUID();
		ApiCall__c firstFailure = runFailingRequest(SERVICE_NAME, body, idempotencyKey);
		ApiCall__c secondFailure = runFailingRequest(SERVICE_NAME, body, idempotencyKey);
		ApiIssue__c firstIssue = findOneIssue();
		ApiIssue__c secondIssue = insertOpenIssue(secondFailure);

		Test.startTest();
		ApiCall__c success = runRequest(SERVICE_NAME, body, idempotencyKey);
		Test.stopTest();

		Assert.areEqual(firstFailure.Id, secondFailure.PreviousAttempt__c, 'Expected the second failure to link to the first');
		Assert.areEqual(secondFailure.Id, success.PreviousAttempt__c, 'Expected the success to link to the newest failure');
		List<ApiIssue__c> resolvedIssues = new SEL_ApiIssue().findById(new Set<Id> {firstIssue.Id, secondIssue.Id});
		Assert.areEqual(2, resolvedIssues.size(), 'Expected both issues to be read back, got ' + resolvedIssues.size());
		for(ApiIssue__c resolvedIssue : resolvedIssues)
		{
			Assert.areEqual(SEL_ApiIssue.STATUS_RESOLVED, resolvedIssue.Status__c, 'Expected every earlier issue to be resolved');
			Assert.areEqual(resolvedIssues[0].ResolvedDate__c, resolvedIssue.ResolvedDate__c, 'Expected one resolved time for every issue');
		}
	}

	/**
	 * @description A caller sends a failing request with a key more times than the read of the key returns calls. Only the
	 * first failed call of a request holds the open issue, and here it is the call that read leaves out. The next failure
	 * still finds that issue, so it writes no second one.
	 */
	@IsTest
	private static void shouldWriteNoSecondIssueWhenTheCallWithTheIssueIsLeftOutOfTheKeyRead()
	{
		registerSetting(SERVICE_NAME, null);
		String body = buildBody();
		String idempotencyKey = UTIL_Random.randomUUID();
		ApiIssue__c openIssue = insertOpenIssue(insertFailedCallsAndFindTheOneLeftOut(body, idempotencyKey));

		Test.startTest();
		ApiCall__c failedCall = runFailingRequest(SERVICE_NAME, body, idempotencyKey);
		Test.stopTest();

		Assert.areEqual(SEL_ApiCall.STATUS_FAILED, failedCall.Status__c, 'Expected the request to fail, got ' + failedCall.Status__c);
		List<ApiIssue__c> issues = new SEL_ApiIssue().getAll();
		Assert.areEqual(1, issues.size(), 'Expected only the issue of the first failed call, got ' + issues.size());
		Assert.areEqual(openIssue.Id, issues.iterator().next().Id, 'Expected the one issue to be the issue of the first failed call');
	}

	/**
	 * @description A caller sends a failing request with a key more times than the read of the key returns calls, and then
	 * the request succeeds. The open issue belongs to the call that read leaves out. The success still marks it Resolved.
	 */
	@IsTest
	private static void shouldResolveTheIssueOfACallLeftOutOfTheKeyRead()
	{
		registerSetting(SERVICE_NAME, null);
		String body = buildBody();
		String idempotencyKey = UTIL_Random.randomUUID();
		ApiIssue__c openIssue = insertOpenIssue(insertFailedCallsAndFindTheOneLeftOut(body, idempotencyKey));

		Test.startTest();
		ApiCall__c success = runRequest(SERVICE_NAME, body, idempotencyKey);
		Test.stopTest();

		Assert.areEqual(SEL_ApiCall.STATUS_COMPLETED, success.Status__c, 'Expected the request to complete, got ' + success.Status__c);
		ApiIssue__c resolvedIssue = (ApiIssue__c)new SEL_ApiIssue().findById(openIssue.Id);
		Assert.areEqual(SEL_ApiIssue.STATUS_RESOLVED, resolvedIssue.Status__c, 'Expected the issue of the first failed call to be resolved, got ' + resolvedIssue.Status__c);
	}

	/**
	 * @description A successful request with a key, whose key has no earlier call, makes no more queries than such a
	 * request made before calls were linked: the read of the switch for every API and the one read of the calls with the
	 * key. It links to nothing.
	 */
	@IsTest
	private static void shouldAddNoQueryForAKeyedSuccessWithNoEarlierFailure()
	{
		registerSetting(SERVICE_NAME, null);
		runRequest(SERVICE_NAME, buildBody(), null);
		setupRequest(buildBody(), UTIL_Random.randomUUID());

		Test.startTest();
		Integer queriesBefore = UTIL_Limits.soqlQueries().used();
		API_Base handler = API_Dispatcher.processInboundService(SERVICE_NAME);
		Integer queriesUsed = UTIL_Limits.soqlQueries().used() - queriesBefore;
		Test.stopTest();

		ApiCall__c completedCall = (ApiCall__c)new SEL_ApiCall().findById(handler.apiCall.Id);
		Assert.areEqual(SEL_ApiCall.STATUS_COMPLETED, completedCall.Status__c, 'Expected the request to complete, got ' + completedCall.Status__c);
		Assert.isNull(completedCall.PreviousAttempt__c, 'Expected no link for a key with no earlier call');
		Assert.areEqual(QUERIES_OF_A_KEYED_REQUEST, queriesUsed, 'Expected only the switch read and the read of the key, got ' + queriesUsed + ' queries');
	}

	/**
	 * @description Without an Idempotency-Key, a request that sends the body of a failed request again is a new request:
	 * it does not link to the failed call, and the issue of the failed call stays Open.
	 */
	@IsTest
	private static void shouldNotLinkWithoutAKey()
	{
		registerSetting(SERVICE_NAME, null);
		String body = buildBody();
		runFailingRequest(SERVICE_NAME, body, null);
		ApiIssue__c openIssue = findOneIssue();

		Test.startTest();
		ApiCall__c laterCall = runRequest(SERVICE_NAME, body, null);
		Test.stopTest();

		Assert.isNull(laterCall.PreviousAttempt__c, 'Expected no link for a request without a key');
		assertIssueOpen(openIssue.Id);
	}

	/**
	 * @description When the service does not have Idempotency Enabled, the key is not used to find earlier calls: a retry
	 * with the same key and body does not link to the failed call, and the issue of the failed call stays Open.
	 */
	@IsTest
	private static void shouldNotLinkWhenIdempotencyIsOff()
	{
		registerSetting(SERVICE_NAME, new Map<SObjectField, Object> {ApiSetting__mdt.IdempotencyEnabled__c => false});
		String body = buildBody();
		String idempotencyKey = UTIL_Random.randomUUID();
		runFailingRequest(SERVICE_NAME, body, idempotencyKey);
		ApiIssue__c openIssue = findOneIssue();

		Test.startTest();
		ApiCall__c laterCall = runRequest(SERVICE_NAME, body, idempotencyKey);
		Test.stopTest();

		Assert.isNull(laterCall.PreviousAttempt__c, 'Expected no link when the service does not have Idempotency Enabled');
		assertIssueOpen(openIssue.Id);
	}

	/**
	 * @description A key that another service already completed with the same body is a different request for this service.
	 * The request runs and answers with its own response, not the answer the other service stored.
	 */
	@IsTest
	private static void shouldNotShareAStoredAnswerAcrossServices()
	{
		registerSetting(SERVICE_NAME, null);
		String body = buildBody();
		String idempotencyKey = UTIL_Random.randomUUID();
		String otherServiceAnswer = buildBody();
		insertCompletedCall(body, idempotencyKey, otherServiceAnswer);

		Test.startTest();
		ApiCall__c completedCall = runRequest(SERVICE_NAME, body, idempotencyKey);
		Test.stopTest();

		Assert.isFalse(completedCall.IsIdempotencyHit__c, 'Expected the request not to be answered from the other service');
		Assert.areEqual(body, RestContext.response.responseBody.toString(), 'Expected the echo of the body, not the answer of the other service');
	}

	/**
	 * @description Three requests complete with a key whose earlier call holds an open issue, and none of them resolves it.
	 * A request answered with a status of 400 on purpose completes, but the operation did not succeed. A request answered
	 * with the stored answer of a completed call ran nothing. A request answered by a mock ran nothing either.
	 */
	@IsTest
	private static void shouldResolveNothingForAStoredAnswerAMockOrANon2xxSuccess()
	{
		registerSetting(STATUS_ANSWERING_SERVICE_NAME, null);
		String body = buildBody();
		String refusedKey = UTIL_Random.randomUUID();
		String storedAnswerKey = UTIL_Random.randomUUID();
		String mockedKey = UTIL_Random.randomUUID();
		ApiIssue__c refusedIssue = insertOpenIssue(insertFailedCall(STATUS_ANSWERING_SERVICE_NAME, body, refusedKey));
		ApiIssue__c storedAnswerIssue = insertOpenIssue(insertFailedCall(STATUS_ANSWERING_SERVICE_NAME, body, storedAnswerKey));
		ApiIssue__c mockedIssue = insertOpenIssue(insertFailedCall(STATUS_ANSWERING_SERVICE_NAME, body, mockedKey));
		insertCompletedCall(body, storedAnswerKey, buildBody());

		Test.startTest();
		answeredStatusCode = API_Base.HTTP_BAD_REQUEST;
		ApiCall__c refusedCall = runRequest(STATUS_ANSWERING_SERVICE_NAME, body, refusedKey);
		answeredStatusCode = null;
		ApiCall__c storedAnswerCall = runRequest(STATUS_ANSWERING_SERVICE_NAME, body, storedAnswerKey);
		API_MockFactory.enableMocking(STATUS_ANSWERING_SERVICE_NAME);
		ApiCall__c mockedCall = runRequest(STATUS_ANSWERING_SERVICE_NAME, body, mockedKey);
		Test.stopTest();

		Assert.areEqual(SEL_ApiCall.STATUS_COMPLETED, refusedCall.Status__c, 'Expected the request answered with 400 to complete, got ' + refusedCall.Status__c);
		Assert.areEqual(String.valueOf(API_Base.HTTP_BAD_REQUEST), refusedCall.StatusCode__c, 'Expected the call to keep the status 400');
		Assert.isTrue(storedAnswerCall.IsIdempotencyHit__c, 'Expected the second request to get the stored answer');
		Assert.areEqual(SEL_ApiCall.STATUS_COMPLETED, mockedCall.Status__c, 'Expected the mocked request to complete, got ' + mockedCall.Status__c);
		assertIssueOpen(refusedIssue.Id);
		assertIssueOpen(storedAnswerIssue.Id);
		assertIssueOpen(mockedIssue.Id);
	}

	/**
	 * @description A request with a key fails while it is handled and writes an issue. The same key then fails again, this
	 * time refused by the checks of the request, which is the other way a failure writes an issue. The second failure writes
	 * no issue, because the earlier call of the same request already holds an open one.
	 */
	@IsTest
	private static void shouldWriteNoSecondIssueForAKeyedRequestThatAlreadyHasOne()
	{
		registerSetting(SERVICE_NAME, null);
		String idempotencyKey = UTIL_Random.randomUUID();
		runFailingRequest(SERVICE_NAME, buildBody(), idempotencyKey);

		Test.startTest();
		ApiCall__c refusedCall = runRequest(SERVICE_NAME, UTIL_String.EMPTY, idempotencyKey);
		Test.stopTest();

		Assert.areEqual(SEL_ApiCall.STATUS_ABORTED, refusedCall.Status__c, 'Expected the empty body to be refused, got ' + refusedCall.Status__c);
		List<ApiIssue__c> issues = new SEL_ApiIssue().getAll();
		Assert.areEqual(1, issues.size(), 'Expected only the issue of the first failure, got ' + issues.size());
	}

	/**
	 * @description A request with a key fails while it is handled, and the service's own error handling then throws. The
	 * framework then writes the issue without the service's code. An earlier call of the same request already holds an
	 * open issue, so this failure writes no second one there either.
	 */
	@IsTest
	private static void shouldWriteNoSecondIssueWhenTheErrorHandlingThrowsForAKeyedRequestThatAlreadyHasOne()
	{
		registerSetting(THROWING_ERROR_HANDLING_SERVICE_NAME, null);
		String body = buildBody();
		String idempotencyKey = UTIL_Random.randomUUID();
		ApiIssue__c openIssue = insertOpenIssue(insertFailedCall(THROWING_ERROR_HANDLING_SERVICE_NAME, body, idempotencyKey));

		Test.startTest();
		ApiCall__c failedCall = runFailingRequest(THROWING_ERROR_HANDLING_SERVICE_NAME, body, idempotencyKey);
		Test.stopTest();

		Assert.areEqual(SEL_ApiCall.STATUS_FAILED, failedCall.Status__c, 'Expected the request to fail, got ' + failedCall.Status__c);
		Assert.isTrue(failedCall.ErrorMessages__c.contains(MESSAGE_ERROR_HANDLING_THREW), 'Expected the error handling to throw, got ' + failedCall.ErrorMessages__c);
		Assert.areEqual(API_Base.HTTP_INTERNAL_SERVER_ERROR, RestContext.response.statusCode, 'Expected status 500 when the error handling throws');
		List<ApiIssue__c> issues = new SEL_ApiIssue().getAll();
		Assert.areEqual(1, issues.size(), 'Expected only the issue of the earlier call, got ' + issues.size());
		Assert.areEqual(openIssue.Id, issues.iterator().next().Id, 'Expected the one issue to be the issue of the earlier call');
	}

	/**
	 * @description A key belongs to the user who sent it. One user's request with a key fails. Another user then sends the
	 * same body to the same service with the same key. That request is a new one: it runs and is not answered from the
	 * first user's call, it does not link to that call, and the issue of that call stays Open.
	 */
	@IsTest
	private static void shouldTreatAnotherUsersRequestWithTheSameKeyAsNew()
	{
		registerSetting(SERVICE_NAME, null);
		String body = buildBody();
		String idempotencyKey = UTIL_Random.randomUUID();
		runFailingRequest(SERVICE_NAME, body, idempotencyKey);
		ApiIssue__c openIssue = findOneIssue();
		User anotherUser = TST_Factory.insertUser(SEL_Profile.PROFILE_SYSTEM_ADMIN);
		ApiCall__c laterCall;

		Test.startTest();
		System.runAs(anotherUser)
		{
			laterCall = runRequest(SERVICE_NAME, body, idempotencyKey);
		}
		Test.stopTest();

		Assert.areEqual(anotherUser.Id, laterCall.CreatedById, 'Expected the other user to have sent the later request');
		Assert.areEqual(SEL_ApiCall.STATUS_COMPLETED, laterCall.Status__c, 'Expected the later request to run and complete, got ' + laterCall.Status__c);
		Assert.isFalse(laterCall.IsIdempotencyHit__c, 'Expected the later request not to be answered from the call of another user');
		Assert.isNull(laterCall.PreviousAttempt__c, 'Expected no link to the call of another user');
		assertIssueOpen(openIssue.Id);
	}

	/**
	 * @description A key belongs to the user who sent it, also when the call of another user completed. Another user
	 * completed calls with two keys. This user then sends the same body with the first key, which would get the stored
	 * answer if that call were this user's. This user also sends another body with the second key, which would be refused
	 * with status 409 if that call were this user's. Both requests run as new ones and complete with status 200.
	 */
	@IsTest
	private static void shouldRunAsNewARequestWhoseKeyAnotherUserCompleted()
	{
		registerSetting(STATUS_ANSWERING_SERVICE_NAME, null);
		String body = buildBody();
		String sameBodyKey = UTIL_Random.randomUUID();
		String otherBodyKey = UTIL_Random.randomUUID();
		String storedAnswer = buildBody();
		System.runAs(TST_Factory.insertUser(SEL_Profile.PROFILE_SYSTEM_ADMIN))
		{
			insertCompletedCall(body, sameBodyKey, storedAnswer);
			insertCompletedCall(body, otherBodyKey, storedAnswer);
		}

		Test.startTest();
		ApiCall__c sameBodyCall = runRequest(STATUS_ANSWERING_SERVICE_NAME, body, sameBodyKey);
		Integer sameBodyStatus = RestContext.response.statusCode;
		ApiCall__c otherBodyCall = runRequest(STATUS_ANSWERING_SERVICE_NAME, buildBody(), otherBodyKey);
		Integer otherBodyStatus = RestContext.response.statusCode;
		Test.stopTest();

		Assert.areEqual(SEL_ApiCall.STATUS_COMPLETED, sameBodyCall.Status__c, 'Expected the request with the same body to run and complete, got ' + sameBodyCall.Status__c);
		Assert.isFalse(sameBodyCall.IsIdempotencyHit__c, 'Expected the request with the same body not to be answered from the call of another user');
		Assert.areNotEqual(storedAnswer, sameBodyCall.Response__c, 'Expected the request with the same body to answer with its own response');
		Assert.areEqual(API_Base.HTTP_OK, sameBodyStatus, 'Expected status 200 for the request with the same body, got ' + sameBodyStatus);
		Assert.areEqual(SEL_ApiCall.STATUS_COMPLETED, otherBodyCall.Status__c, 'Expected the request with another body to run and complete, got ' + otherBodyCall.Status__c);
		Assert.isFalse(otherBodyCall.IsIdempotencyHit__c, 'Expected the request with another body not to be refused because of the call of another user');
		Assert.areEqual(API_Base.HTTP_OK, otherBodyStatus, 'Expected status 200, not 409, for the request with another body, got ' + otherBodyStatus);
	}

	/**
	 * @description A request belongs to the user who sent it, also after another person runs it again. A user's request
	 * with a key fails. Another user runs the issue's request again, and that run completes. The first user then sends the
	 * same body with the same key. The request is answered with the response the completed run stored, so the handler
	 * does not run a second time, and no new issue is written.
	 */
	@IsTest
	private static void shouldAnswerTheSendersRetryFromAReplayThatCompleted()
	{
		registerSetting(SERVICE_NAME, null);
		String body = buildBody();
		String idempotencyKey = UTIL_Random.randomUUID();
		ApiCall__c failedCall = runFailingRequest(SERVICE_NAME, body, idempotencyKey);
		ApiIssue__c openIssue = findOneIssue();
		User replayingUser = TST_Factory.insertUser(SEL_Profile.PROFILE_SYSTEM_ADMIN);

		Test.startTest();
		System.runAs(replayingUser)
		{
			API_InboundInvoker.replay(openIssue.Id, false);
		}
		ApiCall__c retryCall = runRequest(SERVICE_NAME, body, idempotencyKey);
		Test.stopTest();

		ApiCall__c replayCall = (ApiCall__c)new SEL_ApiCall().findFirstByField(ApiCall__c.CreatedById, replayingUser.Id);
		Assert.isNotNull(replayCall, 'Expected the run of the issue\'s request to save a call created by the user who ran it');
		Assert.areEqual(SEL_ApiCall.STATUS_COMPLETED, replayCall.Status__c, 'Expected the run of the issue\'s request to complete, got ' + replayCall.Status__c);
		Assert.areEqual(failedCall.Id, replayCall.PreviousAttempt__c, 'Expected the run of the issue\'s request to link to the failed call');
		Assert.isTrue(retryCall.IsIdempotencyHit__c, 'Expected the retry to be answered from the call of the completed run');
		Assert.areEqual(replayCall.Response__c, RestContext.response.responseBody.toString(), 'Expected the retry to get the response the completed run stored');
		Assert.areEqual(openIssue.Id, findOneIssue().Id, 'Expected no new issue, only the issue of the failed call');
	}

	/**
	 * @description A retry links only to a call that its own sender created. A user's request with a key fails. Another
	 * user runs the issue's request again, and that run fails too, so its call is created by the other user. The first
	 * user then sends the same body with the same key. The retry links to the first user's failed call, not to the call
	 * of the run that failed. The retry succeeds and still marks the issue of the failed call Resolved.
	 */
	@IsTest
	private static void shouldNotLinkTheSendersRetryToAReplayThatFailed()
	{
		registerSetting(SERVICE_NAME, null);
		String body = buildBody();
		String idempotencyKey = UTIL_Random.randomUUID();
		ApiCall__c failedCall = runFailingRequest(SERVICE_NAME, body, idempotencyKey);
		ApiIssue__c openIssue = findOneIssue();
		User replayingUser = TST_Factory.insertUser(SEL_Profile.PROFILE_SYSTEM_ADMIN);

		Test.startTest();
		API_Inbound.returnErrorResponse = true;
		System.runAs(replayingUser)
		{
			API_InboundInvoker.replay(openIssue.Id, false);
		}
		API_Inbound.returnErrorResponse = false;
		ApiCall__c retryCall = runRequest(SERVICE_NAME, body, idempotencyKey);
		Test.stopTest();

		ApiCall__c replayCall = (ApiCall__c)new SEL_ApiCall().findFirstByField(ApiCall__c.CreatedById, replayingUser.Id);
		Assert.isNotNull(replayCall, 'Expected the run of the issue\'s request to save a call created by the user who ran it');
		Assert.areEqual(SEL_ApiCall.STATUS_FAILED, replayCall.Status__c, 'Expected the run of the issue\'s request to fail, got ' + replayCall.Status__c);
		Assert.areEqual(failedCall.Id, replayCall.PreviousAttempt__c, 'Expected the run of the issue\'s request to link to the failed call');
		Assert.areEqual(SEL_ApiCall.STATUS_COMPLETED, retryCall.Status__c, 'Expected the retry to complete, got ' + retryCall.Status__c);
		Assert.areEqual(failedCall.Id, retryCall.PreviousAttempt__c, 'Expected the retry to link to the failed call of its sender, not to the call of the run');
		Assert.areEqual(SEL_ApiIssue.STATUS_RESOLVED, ((ApiIssue__c)new SEL_ApiIssue().findById(openIssue.Id)).Status__c, 'Expected the issue to be resolved');
	}

	/**
	 * @description A request of one user is never answered from the retry of another user. A user's request with a key
	 * fails. Another user, who looks after the issues, runs the issue's request again, and that run fails. The first user
	 * then retries with success. The other user then sends the same body to the same service with the same key. That
	 * request is a new one: it runs, it is not answered from the first user's retry, and it is not refused with status 409.
	 */
	@IsTest
	private static void shouldNotAnswerTheOperatorFromTheSendersRetry()
	{
		registerSetting(SERVICE_NAME, null);
		String body = buildBody();
		String idempotencyKey = UTIL_Random.randomUUID();
		runFailingRequest(SERVICE_NAME, body, idempotencyKey);
		ApiIssue__c openIssue = findOneIssue();
		User replayingUser = TST_Factory.insertUser(SEL_Profile.PROFILE_SYSTEM_ADMIN);
		ApiCall__c operatorCall;
		Integer operatorStatus;

		Test.startTest();
		API_Inbound.returnErrorResponse = true;
		System.runAs(replayingUser)
		{
			API_InboundInvoker.replay(openIssue.Id, false);
		}
		API_Inbound.returnErrorResponse = false;
		ApiCall__c senderRetry = runRequest(SERVICE_NAME, body, idempotencyKey);
		System.runAs(replayingUser)
		{
			operatorCall = runRequest(SERVICE_NAME, body, idempotencyKey);
			operatorStatus = RestContext.response.statusCode;
		}
		Test.stopTest();

		Assert.areEqual(SEL_ApiCall.STATUS_COMPLETED, senderRetry.Status__c, 'Expected the retry of the first user to complete, got ' + senderRetry.Status__c);
		Assert.areEqual(replayingUser.Id, operatorCall.CreatedById, 'Expected the other user to have sent the later request');
		Assert.areEqual(SEL_ApiCall.STATUS_COMPLETED, operatorCall.Status__c, 'Expected the later request to run and complete, got ' + operatorCall.Status__c);
		Assert.isFalse(operatorCall.IsIdempotencyHit__c, 'Expected the later request not to be answered from the retry of the first user');
		Assert.areEqual(API_Base.HTTP_OK, operatorStatus, 'Expected status 200, not 409, for the later request, got ' + operatorStatus);
	}

	/**
	 * @description An issue's request is run again, and it carries a key whose newest failed call also received the same
	 * body. The new call links to the call the request was read from, not to the call the key would link to.
	 */
	@IsTest
	private static void shouldPreferTheReplayOriginalOverTheKeyLink()
	{
		registerSetting(SERVICE_NAME, null);
		String body = buildBody();
		String idempotencyKey = UTIL_Random.randomUUID();
		ApiCall__c originalCall = insertFailedCall(SERVICE_NAME, body, null);
		insertFailedCall(SERVICE_NAME, body, idempotencyKey);
		API_InboundInvoker.InboundRequest request = new API_InboundInvoker.InboundRequest();
		request.path = REQUEST_PATH;
		request.method = HTTP_METHOD_POST;
		request.body = body;
		request.headers.put(API_Base.HEADER_IDEMPOTENCY_KEY, idempotencyKey);
		request.serviceName = SERVICE_NAME;
		request.originalCallId = originalCall.Id;

		Test.startTest();
		API_InboundInvoker.replay(request, false);
		Test.stopTest();

		List<ApiCall__c> completedCalls = new List<ApiCall__c>();
		for(ApiCall__c apiCall : new SEL_ApiCall().findByServiceName(SERVICE_NAME))
		{
			if(apiCall.Status__c == SEL_ApiCall.STATUS_COMPLETED)
			{
				completedCalls.add(apiCall);
			}
		}
		Assert.areEqual(1, completedCalls.size(), 'Expected the replay to save one completed call, got ' + completedCalls.size());
		ApiCall__c replayCall = completedCalls.iterator().next();
		Assert.areEqual(originalCall.Id, replayCall.PreviousAttempt__c, 'Expected the replay to link to the call its request was read from');
	}

	/**
	 * @description When no query is left after the request has run, the success does not look for the issues of the earlier
	 * call. The caller still gets the answer of the success, and the issue stays Open.
	 */
	@IsTest
	private static void shouldLeaveTheIssueOpenWhenNoQueryIsLeftToResolveIt()
	{
		registerSetting(SERVICE_NAME, null);
		String body = buildBody();
		String idempotencyKey = UTIL_Random.randomUUID();
		runRequest(SERVICE_NAME, buildBody(), null);
		ApiIssue__c openIssue = insertOpenIssue(insertFailedCall(SERVICE_NAME, body, idempotencyKey));
		setupRequest(body, idempotencyKey);

		Test.startTest();
		useQueriesUntilOnlyThisManyAreLeft(QUERIES_OF_A_KEYED_REQUEST);
		API_Base handler = API_Dispatcher.processInboundService(SERVICE_NAME);
		Test.stopTest();

		Assert.areEqual(String.valueOf(API_Base.HTTP_OK), handler.result.statusCode, 'Expected the caller to get the answer of the success');
		assertIssueOpen(openIssue.Id);
	}

	/**
	 * @description When the issues of the earlier calls cannot be read, the success still answers the caller, and the issue
	 * stays Open. The error is logged and not passed to the caller.
	 */
	@IsTest
	private static void shouldKeepTheAnswerWhenTheEarlierIssuesCannotBeRead()
	{
		registerSetting(SERVICE_NAME, null);
		String body = buildBody();
		String idempotencyKey = UTIL_Random.randomUUID();
		ApiIssue__c openIssue = insertOpenIssue(insertFailedCall(SERVICE_NAME, body, idempotencyKey));
		TST_Mock.throwsException(ApiIssue__c.SObjectType);

		Test.startTest();
		ApiCall__c completedCall = runRequest(SERVICE_NAME, body, idempotencyKey);
		Test.stopTest();

		TST_Mock.clear(ApiIssue__c.SObjectType);
		Assert.areEqual(SEL_ApiCall.STATUS_COMPLETED, completedCall.Status__c, 'Expected the request to complete, got ' + completedCall.Status__c);
		Assert.areEqual(API_Base.HTTP_OK, RestContext.response.statusCode, 'Expected the caller to get status 200');
		assertIssueOpen(openIssue.Id);
	}

	/**
	 * @description When no query is left to look for an open issue of an earlier call, a failed request writes its own
	 * issue. A second open issue for the same request is better than a failure with no issue at all.
	 */
	@IsTest
	private static void shouldWriteTheIssueWhenNoQueryIsLeftToLookForAnEarlierOne()
	{
		registerSetting(SERVICE_NAME, null);
		String body = buildBody();
		String idempotencyKey = UTIL_Random.randomUUID();
		runRequest(SERVICE_NAME, buildBody(), null);
		insertOpenIssue(insertFailedCall(SERVICE_NAME, body, idempotencyKey));
		setupRequest(body, idempotencyKey);
		API_Inbound.returnErrorResponse = true;

		Test.startTest();
		useQueriesUntilOnlyThisManyAreLeft(QUERIES_OF_A_KEYED_REQUEST);
		API_Dispatcher.processInboundService(SERVICE_NAME);
		Test.stopTest();

		List<ApiIssue__c> issues = new SEL_ApiIssue().getAll();
		Assert.areEqual(2, issues.size(), 'Expected the failed request to write its own issue, got ' + issues.size());
	}

	/**
	 * @description When the issues of the earlier calls cannot be read, a failed request writes its own issue, so the
	 * failure is not lost.
	 */
	@IsTest
	private static void shouldWriteTheIssueWhenTheEarlierIssuesCannotBeRead()
	{
		registerSetting(SERVICE_NAME, null);
		String body = buildBody();
		String idempotencyKey = UTIL_Random.randomUUID();
		insertOpenIssue(insertFailedCall(SERVICE_NAME, body, idempotencyKey));
		TST_Mock.throwsException(ApiIssue__c.SObjectType);

		Test.startTest();
		runFailingRequest(SERVICE_NAME, body, idempotencyKey);
		Test.stopTest();

		TST_Mock.clear(ApiIssue__c.SObjectType);
		List<ApiIssue__c> issues = new SEL_ApiIssue().getAll();
		Assert.areEqual(2, issues.size(), 'Expected the failed request to write its own issue, got ' + issues.size());
	}

	/**
	 * @description Registers the inbound setting of a service through the test mock, routed to the request path, with
	 * Idempotency Enabled, Log Issues and Resolve Issues on unless the overrides say otherwise.
	 *
	 * @param serviceName The handler class the setting names.
	 * @param overrides The field values that replace the defaults, or null to keep them.
	 */
	private static void registerSetting(String serviceName, Map<SObjectField, Object> overrides)
	{
		Map<SObjectField, Object> fieldValues = new Map<SObjectField, Object>
		{
				ApiSetting__mdt.IdempotencyEnabled__c => true,
				ApiSetting__mdt.LogIssues__c => true,
				ApiSetting__mdt.ResolveIssues__c => true
		};
		if(overrides != null)
		{
			fieldValues.putAll(overrides);
		}
		TST_Factory.newInboundApiSetting(serviceName, ROUTE_PATH, ROUTE_PRIORITY, fieldValues);
	}

	/**
	 * @description Sets up a POST request with the given body and, when given, an Idempotency-Key header. The tests send
	 * each request to a service by its name, so the path of the request is not used.
	 *
	 * @param body The body to send.
	 * @param idempotencyKey The key to send, or null to send none.
	 */
	private static void setupRequest(String body, String idempotencyKey)
	{
		API_InboundTestHelper.setupRestContext();
		RestContext.request.requestBody = Blob.valueOf(body);
		if(idempotencyKey != null)
		{
			RestContext.request.addHeader(API_Base.HEADER_IDEMPOTENCY_KEY, idempotencyKey);
		}
	}

	/**
	 * @description Sends a request to a service and reads back the call it saved.
	 *
	 * @param serviceName The service to send the request to.
	 * @param body The body to send.
	 * @param idempotencyKey The key to send, or null to send none.
	 *
	 * @return The saved call of the request.
	 */
	private static ApiCall__c runRequest(String serviceName, String body, String idempotencyKey)
	{
		setupRequest(body, idempotencyKey);
		API_Base handler = API_Dispatcher.processInboundService(serviceName);
		return (ApiCall__c)new SEL_ApiCall().findById(handler.apiCall.Id);
	}

	/**
	 * @description Sends a request whose handling throws, so it ends Failed, and reads back the call it saved.
	 *
	 * @param serviceName The service to send the request to.
	 * @param body The body to send.
	 * @param idempotencyKey The key to send, or null to send none.
	 *
	 * @return The saved call of the failed request.
	 */
	private static ApiCall__c runFailingRequest(String serviceName, String body, String idempotencyKey)
	{
		API_Inbound.returnErrorResponse = true;
		ApiCall__c failedCall = runRequest(serviceName, body, idempotencyKey);
		API_Inbound.returnErrorResponse = false;
		return failedCall;
	}

	/**
	 * @description Saves a failed inbound call of a service, with the hash of the body it received and, when given, a key.
	 *
	 * @param serviceName The service of the call.
	 * @param body The body the call received.
	 * @param idempotencyKey The key the call carried, or null for none.
	 *
	 * @return The saved call.
	 */
	private static ApiCall__c insertFailedCall(String serviceName, String body, String idempotencyKey)
	{
		return (ApiCall__c)buildCall(serviceName, body, idempotencyKey).withOverride(ApiCall__c.Status__c, SEL_ApiCall.STATUS_FAILED).build();
	}

	/**
	 * @description Saves, as sent by the running user, more failed calls of the echo service with one body and one key than
	 * the read of a key returns, and finds the one call that read leaves out. It checks that the read leaves out exactly
	 * one of them, so a test that uses it really looks past that read.
	 *
	 * @param body The body every call received.
	 * @param idempotencyKey The key every call carried.
	 *
	 * @return The saved call that the read of the key leaves out.
	 */
	private static ApiCall__c insertFailedCallsAndFindTheOneLeftOut(String body, String idempotencyKey)
	{
		List<ApiCall__c> failedCalls = buildCall(SERVICE_NAME, body, idempotencyKey)
				.withCount(MORE_CALLS_THAN_THE_KEY_READ_RETURNS)
				.withOverride(ApiCall__c.Status__c, SEL_ApiCall.STATUS_FAILED)
				.buildList();
		Set<Id> readCallIds = UTIL_SObject.extractIds(new SEL_ApiCall().findByServiceAndIdempotencyKey(SERVICE_NAME, idempotencyKey, UserInfo.getUserId()));
		List<ApiCall__c> leftOutCalls = new List<ApiCall__c>();
		for(ApiCall__c failedCall : failedCalls)
		{
			if(!readCallIds.contains(failedCall.Id))
			{
				leftOutCalls.add(failedCall);
			}
		}
		Assert.areEqual(1, leftOutCalls.size(), 'Expected the read of the key to leave out one call, got ' + leftOutCalls.size());
		return leftOutCalls.iterator().next();
	}

	/**
	 * @description Saves a completed inbound call of the test handler's service, with the key it carried, the hash of the
	 * body it received and the response it answered with.
	 *
	 * @param body The body the call received.
	 * @param idempotencyKey The key the call carried.
	 * @param response The response the call answered with.
	 *
	 * @return The saved call.
	 */
	private static ApiCall__c insertCompletedCall(String body, String idempotencyKey, String response)
	{
		return (ApiCall__c)buildCall(STATUS_ANSWERING_SERVICE_NAME, body, idempotencyKey)
				.withOverride(ApiCall__c.Status__c, SEL_ApiCall.STATUS_COMPLETED)
				.withOverride(ApiCall__c.Response__c, response)
				.build();
	}

	/**
	 * @description Prepares an inbound call of a service, with the hash of the body it received and, when given, a key.
	 *
	 * @param serviceName The service of the call.
	 * @param body The body the call received.
	 * @param idempotencyKey The key the call carried, or null for none.
	 *
	 * @return A builder for the call, ready to be given its status and saved.
	 */
	private static TST_Builder.Builder buildCall(String serviceName, String body, String idempotencyKey)
	{
		return TST_Factory.getApiCallBuilder()
				.withOverrides(new Map<SObjectField, Object>
				{
						ApiCall__c.Direction__c => SEL_ApiCall.TYPE_INBOUND,
						ApiCall__c.IdempotencyKeyBodyHash__c => API_Inbound.computeBodyHash(body),
						ApiCall__c.IdempotencyKey__c => idempotencyKey,
						ApiCall__c.Request__c => body,
						ApiCall__c.ServiceName__c => serviceName
				});
	}

	/**
	 * @description Saves an open inbound issue for a call, built the way the framework builds one.
	 *
	 * @param apiCall The saved call the issue belongs to.
	 *
	 * @return The saved issue.
	 */
	private static ApiIssue__c insertOpenIssue(ApiCall__c apiCall)
	{
		return (ApiIssue__c)TST_Builder.of(ApiIssue__c.SObjectType)
				.withOverrides(API_Base.buildFailureRecord(apiCall).getPopulatedFieldsAsMap())
				.withOverride(ApiIssue__c.Direction__c, SEL_ApiIssue.DIRECTION_INBOUND)
				.build();
	}

	/**
	 * @description Reads the one issue the test has so far.
	 *
	 * @return The issue.
	 */
	private static ApiIssue__c findOneIssue()
	{
		List<ApiIssue__c> issues = new SEL_ApiIssue().getAll();
		Assert.areEqual(1, issues.size(), 'Expected one issue for the failed request, got ' + issues.size());
		return issues.iterator().next();
	}

	/**
	 * @description Reads an issue back and checks that it is still Open.
	 *
	 * @param issueId The issue to check.
	 */
	private static void assertIssueOpen(Id issueId)
	{
		ApiIssue__c issue = (ApiIssue__c)new SEL_ApiIssue().findById(issueId);
		Assert.areEqual(SEL_ApiIssue.STATUS_OPEN, issue.Status__c, 'Expected the issue to stay open, got ' + issue.Status__c);
	}

	/**
	 * @description Runs small queries until the transaction has only the given number of queries left.
	 *
	 * @param queriesLeft The number of queries to leave.
	 */
	private static void useQueriesUntilOnlyThisManyAreLeft(Integer queriesLeft)
	{
		while(UTIL_Limits.soqlQueries().remaining() > queriesLeft)
		{
			new SEL_ApiCall().findById(UTIL_Random.randomId(ApiCall__c.SObjectType));
		}
	}

	/**
	 * @description Builds a JSON body the echo service accepts, with a random value so each body is its own.
	 *
	 * @return The body.
	 */
	private static String buildBody()
	{
		return JSON.serialize(new Map<String, Object> {BODY_FIELD => UTIL_Random.randomName()});
	}

	/**
	 * @description An inbound handler that answers with the status a test sets in answeredStatusCode, and with the status
	 * the framework gives a success when the test sets none.
	 */
	public class StatusAnsweringInbound extends API_Inbound
	{
		/**
		 * @description Sets the status of the answer when the test chose one.
		 */
		public override void processRequest()
		{
			if(answeredStatusCode != null)
			{
				result.statusCode = String.valueOf(answeredStatusCode);
			}
		}
	}

	/**
	 * @description An inbound handler whose own error handling throws. A test makes the request fail the way
	 * runFailingRequest does, and the failure then reaches this error handling.
	 */
	public class ThrowingErrorHandlingInbound extends API_Inbound
	{
		/**
		 * @description Throws while it handles the failure, before the base method writes the answer.
		 *
		 * @param error The failure being handled.
		 */
		public override void handleError(Exception error)
		{
			throw new UTIL_Exceptions.IllegalStateException(MESSAGE_ERROR_HANDLING_THREW);
		}
	}
}
