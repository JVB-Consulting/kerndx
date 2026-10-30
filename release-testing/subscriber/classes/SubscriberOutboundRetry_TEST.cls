// SPDX-License-Identifier: Apache-2.0
/**
 * @description Subscriber-side proof of the outbound retry classification through the real call path: a callout that got
 * no answer retries on a GET and fails at once on an unkeyed POST, a handler's own exception fails at once unless its type
 * is listed, the denylist a handler puts in createRetryStrategy() reaches the decision, PermanentFailureException refuses a
 * retry, and an ad-hoc POST with an idempotency key is retried. It also proves a callout the org refused before it was sent
 * (unsaved work was pending) is retried without being marked as one the external system may have acted on, the codes a
 * caller names in retryOn(...) for both the immediate re-send and the scheduled retry, a server error on an unkeyed POST,
 * an async chain API step that stops retrying, the Idempotency-Key the request actually carried, and an inbound handler
 * whose own error handling throws. Every outbound test runs with retry budget left and asserts Status__c and NextRetry__c
 * together: a row at Retry carries a time, a row at Failed carries none.
 *
 * @see kern.API_Outbound
 * @see kern.API_Inbound
 * @see kern.UTIL_Retry
 * @see kern.UTIL_HttpClient
 * @see kern.UTIL_AsyncChain
 *
 * @author your.name@company.com
 *
 * @group Web Services
 *
 * @date October 2026
 */
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest(seeAllData=false isParallel=true)
private class SubscriberOutboundRetry_TEST
{
	/**
	 * @description Retry budget every test leaves, so a refusal comes from the framework, never from an exhausted budget.
	 */
	private static final Integer RETRY_BUDGET = 3;

	/**
	 * @description A retry budget of none, for the test that proves what a refused callout does once no retry is left.
	 */
	private static final Integer NO_RETRY_BUDGET = 0;

	/**
	 * @description The retry wait, in seconds.
	 */
	private static final Integer RETRY_BACKOFF_SECONDS = 30;

	/**
	 * @description A retry budget beyond the ad-hoc client's synchronous ceiling of three, so budget is left for the
	 * scheduled retry once the in-transaction attempts are spent.
	 */
	private static final Integer RETRY_BUDGET_BEYOND_SYNCHRONOUS = 5;

	/**
	 * @description The retry budget of the ad-hoc calls that prove retryOn(...): two re-sends at once spend all of it.
	 */
	private static final Integer RETRY_BUDGET_OF_TWO = 2;

	/**
	 * @description The message the throwing handlers fail with.
	 */
	private static final String MESSAGE_HANDLER_THREW = 'the handler threw on purpose';

	/**
	 * @description The message the inbound handler's own error handling fails with.
	 */
	private static final String MESSAGE_ERROR_HANDLING_THREW = 'the error handling threw on purpose';

	/**
	 * @description The credential name of the ad-hoc call, which is also its service name for the mock and the row.
	 */
	private static final String TEST_CREDENTIAL = 'RetryEdgeCredential';

	/**
	 * @description The ad-hoc call's path.
	 */
	private static final String TEST_PATH = '/retry';

	/**
	 * @description The inbound handler's endpoint path.
	 */
	private static final String INBOUND_PATH = '/retry-edge';

	/**
	 * @description The idempotency key the keyed ad-hoc call carries and is read back by.
	 */
	private static final String IDEMPOTENCY_KEY = 'retry-edge-key';

	/**
	 * @description The idempotency key a handler's createRequest() override puts on the request in place of the one the
	 * framework worked out.
	 */
	private static final String SENT_IDEMPOTENCY_KEY = 'retry-edge-sent-key';

	/**
	 * @description The request header that carries the idempotency key.
	 */
	private static final String HEADER_IDEMPOTENCY_KEY = 'Idempotency-Key';

	/**
	 * @description The name of the async chain the chain test runs.
	 */
	private static final String CHAIN_NAME = 'Retry Edge Chain';

	/**
	 * @description The number of attempts the chain test's API step may make, the first included.
	 */
	private static final Integer CHAIN_STEP_ATTEMPTS = 3;

	/**
	 * @description HTTP status code for a successful answer (200); the framework's own constant is not visible across the
	 * namespace, so the test spells it.
	 */
	private static final Integer HTTP_OK = 200;

	/**
	 * @description HTTP status code an external system answers with when it is asked to slow down (429).
	 */
	private static final Integer HTTP_TOO_MANY_REQUESTS = 429;

	/**
	 * @description HTTP status code for an error inside the external system, which may follow a request it processed (500).
	 */
	private static final Integer HTTP_INTERNAL_SERVER_ERROR = 500;

	/**
	 * @description HTTP status code an external system answers with when it did not process the request (503).
	 */
	private static final Integer HTTP_SERVICE_UNAVAILABLE = 503;

	/**
	 * @description The body every mock answers with.
	 */
	private static final String EMPTY_BODY = '{}';

	/**
	 * @description The status of an ApiCall record that waits for its next attempt.
	 */
	private static final String STATUS_RETRY = 'Retry';

	/**
	 * @description The status of an ApiCall record that ended in success.
	 */
	private static final String STATUS_COMPLETED = 'Completed';

	/**
	 * @description The status of an ApiCall record that ended in failure.
	 */
	private static final String STATUS_FAILED = 'Failed';

	/**
	 * @description The status of an async chain that ended in failure.
	 */
	private static final String STATUS_CHAIN_FAILED = 'Failed';

	/**
	 * @description How many times the commit-hooks handler's onDMLStarting() ran in this transaction; an inner class
	 * cannot hold a static of its own.
	 */
	private static Integer dmlStartingRuns = 0;

	/**
	 * @description How many times the commit-hooks handler's onCommitWorkStarting() ran in this transaction.
	 */
	private static Integer commitWorkStartingRuns = 0;

	/**
	 * @description How many times the inbound commit-hooks handler's onCommitWorkStarting() ran in this transaction.
	 */
	private static Integer inboundCommitWorkStartingRuns = 0;

	/**
	 * @description How many times the commit-hooks handler's onDMLFinished() ran in this transaction.
	 */
	private static Integer dmlFinishedRuns = 0;

	/**
	 * @description How many times the commit-hooks handler's onCommitWorkFinishing() ran in this transaction.
	 */
	private static Integer commitWorkFinishingRuns = 0;

	/**
	 * @description A callout that got no answer on a GET rests at Retry with a time: the request is safe to repeat.
	 */
	@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveAsserts')
	@IsTest
	private static void shouldRetryATransportFailureOnAGet()
	{
		String serviceName = RetryEdgeGet.class.getName();
		registerRetryingSetting(serviceName);
		kern.API_MockFactory.forService(serviceName).withTransportFailure().register();

		Test.startTest();
		kern.API_Dispatcher.execute(new List<kern__ApiCall__c> {kern.TST_Factory.newOutboundApiCall(serviceName, UserInfo.getUserId())});
		Test.stopTest();

		assertRetrying(serviceName);
	}

	/**
	 * @description A POST that got no answer and carried no Idempotency-Key fails at once with the labelled line, and its
	 * issue says the external system may have acted.
	 */
	@IsTest
	private static void shouldFailAnUnkeyedPostAtOnceWhenItGotNoAnswer()
	{
		String serviceName = RetryEdgePost.class.getName();
		registerRetryingSetting(serviceName);
		kern.API_MockFactory.forService(serviceName).withTransportFailure().register();

		Test.startTest();
		kern.API_Dispatcher.execute(new List<kern__ApiCall__c> {kern.TST_Factory.newOutboundApiCall(serviceName, UserInfo.getUserId())});
		Test.stopTest();

		String expectedLine = String.format(System.Label.kern.OutboundCall_NoResponseNotRepeated, new List<Object> {serviceName});
		List<kern__ApiCall__c> failed = kern.SEL_ApiCall.assertServiceFailed(serviceName, expectedLine);
		Assert.isNull(failed[0].kern__NextRetry__c, 'Expected nothing scheduled for a request that cannot be repeated');
		Assert.isTrue(findOnlyIssue(serviceName).kern__ExternalSystemMayHaveActed__c, 'Expected the issue to say the external system may have acted');
	}

	/**
	 * @description The denylist a handler puts in createRetryStrategy() reaches the decision: a transport failure whose
	 * type is denylisted ends Failed with no time (where shouldRetryATransportFailureOnAGet rests at Retry).
	 */
	@IsTest
	private static void shouldNotScheduleARetryForAFailureTheHandlerDenylists()
	{
		String serviceName = RetryEdgeDenylisting.class.getName();
		registerRetryingSetting(serviceName);
		kern.API_MockFactory.forService(serviceName).withTransportFailure().register();

		Test.startTest();
		kern.API_Dispatcher.execute(new List<kern__ApiCall__c> {kern.TST_Factory.newOutboundApiCall(serviceName, UserInfo.getUserId())});
		Test.stopTest();

		Assert.isNull(kern.SEL_ApiCall.assertServiceFailed(serviceName)[0].kern__NextRetry__c, 'Expected a denylisted failure to schedule nothing');
	}

	/**
	 * @description A throw in the handler's own code fails at once with no time.
	 */
	@IsTest
	private static void shouldFailAtOnceWhenTheHandlersOwnCodeThrows()
	{
		String serviceName = RetryEdgeThrowing.class.getName();
		registerRetryingSetting(serviceName);

		Test.startTest();
		kern.API_Dispatcher.execute(new List<kern__ApiCall__c> {kern.TST_Factory.newOutboundApiCall(serviceName, UserInfo.getUserId())});
		Test.stopTest();

		Assert.isNull(kern.SEL_ApiCall.assertServiceFailed(serviceName, MESSAGE_HANDLER_THREW)[0].kern__NextRetry__c, 'Expected a handler throw to schedule nothing');
	}

	/**
	 * @description The same throw retries when the handler lists its exact type in getRetryableExceptionTypes(): the row
	 * rests at Retry with a time. The type is the subscriber's own, matched by its exact name.
	 */
	@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveAsserts')
	@IsTest
	private static void shouldRetryAHandlerExceptionTheHandlerListed()
	{
		String serviceName = RetryEdgeOptedIn.class.getName();
		registerRetryingSetting(serviceName);

		Test.startTest();
		kern.API_Dispatcher.execute(new List<kern__ApiCall__c> {kern.TST_Factory.newOutboundApiCall(serviceName, UserInfo.getUserId())});
		Test.stopTest();

		assertRetrying(serviceName);
	}

	/**
	 * @description PermanentFailureException from parseResponse() after a successful answer ends the call Failed at once.
	 */
	@IsTest
	private static void shouldFailAtOnceWhenTheHandlerRefusesTheRetry()
	{
		String serviceName = RetryEdgeRefusing.class.getName();
		registerRetryingSetting(serviceName);
		kern.API_MockFactory.forService(serviceName).body(EMPTY_BODY).statusCode(HTTP_OK).register();

		Test.startTest();
		kern.API_Dispatcher.execute(new List<kern__ApiCall__c> {kern.TST_Factory.newOutboundApiCall(serviceName, UserInfo.getUserId())});
		Test.stopTest();

		Assert.isNull(kern.SEL_ApiCall.assertServiceFailed(serviceName, MESSAGE_HANDLER_THREW)[0].kern__NextRetry__c, 'Expected the refusal to schedule nothing');
	}

	/**
	 * @description An ad-hoc POST that carries an idempotency key is safe to repeat: a transport failure under a budget
	 * beyond the synchronous ceiling rests at Retry with a time; the row is read back by its key.
	 */
	@IsTest
	private static void shouldRetryAKeyedAdHocPostThatGotNoAnswer()
	{
		kern.API_MockFactory.forService(TEST_CREDENTIAL).withTransportFailure().register();

		Test.startTest();
		kern.UTIL_HttpClient.post(TEST_CREDENTIAL, TEST_PATH).withRetry(RETRY_BUDGET_BEYOND_SYNCHRONOUS, RETRY_BACKOFF_SECONDS).withIdempotencyKey(IDEMPOTENCY_KEY).send();
		Test.stopTest();

		List<kern__ApiCall__c> rows = (List<kern__ApiCall__c>)new kern.SEL_ApiCall().findByField(kern__ApiCall__c.kern__IdempotencyKey__c, IDEMPOTENCY_KEY);
		Assert.areEqual(1, rows.size(), 'Expected the keyed call to be stored');
		Assert.areEqual(STATUS_RETRY, rows[0].kern__Status__c, 'Expected a keyed POST that got no answer to be scheduled');
		Assert.isNotNull(rows[0].kern__NextRetry__c, 'Expected a scheduled retry to carry a time');
	}

	/**
	 * @description A callout the org refused before it was sent, because a save earlier in the same transaction left work
	 * pending, never reached the external system: an unkeyed POST then rests at Retry with a time, and its issue does not
	 * say the external system may have acted.
	 */
	@IsTest
	private static void shouldRetryACalloutTheOrgRefusedBeforeItWasSentWithoutMarkingIt()
	{
		String serviceName = RetryEdgePost.class.getName();
		registerRetryingSetting(serviceName);
		kern.API_MockFactory.forService(serviceName).body(EMPTY_BODY).statusCode(HTTP_OK).register();

		Test.startTest();
		kern.TST_Builder.of(kern__Foobar__c.SObjectType).build();
		kern.API_Dispatcher.execute(new List<kern__ApiCall__c> {kern.TST_Factory.newOutboundApiCall(serviceName, UserInfo.getUserId())});
		Test.stopTest();

		assertRetrying(serviceName);
		Assert.isFalse(findOnlyIssue(serviceName).kern__ExternalSystemMayHaveActed__c, 'Expected a callout that never left the org to be unmarked');
	}

	/**
	 * @description The same refused callout with no retry budget ends Failed with no time, and its issue still does not
	 * say the external system may have acted.
	 */
	@IsTest
	private static void shouldFailWithoutMarkingARefusedCalloutWhenNoRetryIsLeft()
	{
		String serviceName = RetryEdgePost.class.getName();
		registerSetting(serviceName, NO_RETRY_BUDGET);
		kern.API_MockFactory.forService(serviceName).body(EMPTY_BODY).statusCode(HTTP_OK).register();

		Test.startTest();
		kern.TST_Builder.of(kern__Foobar__c.SObjectType).build();
		kern.API_Dispatcher.execute(new List<kern__ApiCall__c> {kern.TST_Factory.newOutboundApiCall(serviceName, UserInfo.getUserId())});
		Test.stopTest();

		Assert.isNull(kern.SEL_ApiCall.assertServiceFailed(serviceName)[0].kern__NextRetry__c, 'Expected nothing scheduled once no retry is left');
		Assert.isFalse(findOnlyIssue(serviceName).kern__ExternalSystemMayHaveActed__c, 'Expected a callout that never left the org to be unmarked');
	}

	/**
	 * @description A status the caller names in retryOn(...) is sent again at once, 429 included: with two retries asked
	 * for, both are spent in the transaction and nothing is left to schedule.
	 */
	@IsTest
	private static void shouldResendAtOnceAStatusTheCallerNamed()
	{
		kern.API_MockFactory.forService(TEST_CREDENTIAL).body(EMPTY_BODY).statusCode(HTTP_TOO_MANY_REQUESTS).register();

		Test.startTest();
		kern.UTIL_HttpClient.get(TEST_CREDENTIAL, TEST_PATH).withRetry(RETRY_BUDGET_OF_TWO, RETRY_BACKOFF_SECONDS).retryOn(new Set<Integer> {HTTP_TOO_MANY_REQUESTS})
				.withIdempotencyKey(IDEMPOTENCY_KEY).send();
		Test.stopTest();

		kern__ApiCall__c row = findOnlyCallByKey(IDEMPOTENCY_KEY);
		Assert.areEqual(STATUS_FAILED, row.kern__Status__c, 'Expected the call to end Failed once the budget is spent');
		Assert.areEqual(RETRY_BUDGET_OF_TWO, row.kern__Retries__c, 'Expected both retries spent at once on the status the caller named');
		Assert.isNull(row.kern__NextRetry__c, 'Expected nothing scheduled once the budget is spent');
	}

	/**
	 * @description Without retryOn(...), a 429 is not sent again at once: it waits for the scheduled retry, which counts
	 * one retry and carries a time.
	 */
	@IsTest
	private static void shouldLeaveA429WithoutRetryOnToTheScheduledRetry()
	{
		kern.API_MockFactory.forService(TEST_CREDENTIAL).body(EMPTY_BODY).statusCode(HTTP_TOO_MANY_REQUESTS).register();

		Test.startTest();
		kern.UTIL_HttpClient.get(TEST_CREDENTIAL, TEST_PATH).withRetry(RETRY_BUDGET_OF_TWO, RETRY_BACKOFF_SECONDS).withIdempotencyKey(IDEMPOTENCY_KEY).send();
		Test.stopTest();

		kern__ApiCall__c row = findOnlyCallByKey(IDEMPOTENCY_KEY);
		Assert.areEqual(STATUS_RETRY, row.kern__Status__c, 'Expected the 429 to wait for the scheduled retry');
		Assert.isNotNull(row.kern__NextRetry__c, 'Expected a scheduled retry to carry a time');
		Assert.areEqual(1, row.kern__Retries__c, 'Expected the one retry the schedule counts, none sent at once');
	}

	/**
	 * @description A status retryOn(...) leaves out ends Failed even with a wait given: retryOn(...) limits the scheduled
	 * retry too, so a 503 the default would retry is not scheduled when the caller named only 429.
	 */
	@IsTest
	private static void shouldFailAStatusTheCallerLeftOutOfRetryOnEvenWithAWait()
	{
		kern.API_MockFactory.forService(TEST_CREDENTIAL).body(EMPTY_BODY).statusCode(HTTP_SERVICE_UNAVAILABLE).register();

		Test.startTest();
		kern.UTIL_HttpClient.get(TEST_CREDENTIAL, TEST_PATH).withRetry(RETRY_BUDGET_OF_TWO, RETRY_BACKOFF_SECONDS).retryOn(new Set<Integer> {HTTP_TOO_MANY_REQUESTS})
				.withIdempotencyKey(IDEMPOTENCY_KEY).send();
		Test.stopTest();

		kern__ApiCall__c row = findOnlyCallByKey(IDEMPOTENCY_KEY);
		Assert.areEqual(STATUS_FAILED, row.kern__Status__c, 'Expected a status outside retryOn to end Failed');
		Assert.isNull(row.kern__NextRetry__c, 'Expected a status outside retryOn to schedule nothing');
		Assert.areEqual(0, row.kern__Retries__c ?? 0, 'Expected no retry spent on a status outside retryOn');
	}

	/**
	 * @description An outbound handler's own onCommitWorkStarting(), onDMLStarting(), onDMLFinished() and
	 * onCommitWorkFinishing() overrides run once for each attempt of a commit that has work: once for a commit that
	 * succeeds at the first attempt. This class compiles only while an outbound handler can override all four. A second
	 * attempt needs a real row lock, which a unit test cannot produce; the package tests that hold the lock prove the
	 * retried commit (API_Outbound_TEST.shouldRetryTheCommitOnceOnARowLockWithoutResendingTheCallout and
	 * API_Base_TEST.shouldRetryAnInboundCommitOnceOnARowLockAndRespondOnce).
	 */
	@IsTest
	private static void shouldRunTheHandlersCommitHooksOncePerAttempt()
	{
		String serviceName = RetryEdgeCommitHooks.class.getName();
		registerRetryingSetting(serviceName);
		kern.API_MockFactory.forService(serviceName).body(EMPTY_BODY).statusCode(HTTP_OK).register();

		Test.startTest();
		kern.API_Dispatcher.execute(new List<kern__ApiCall__c> {kern.TST_Factory.newOutboundApiCall(serviceName, UserInfo.getUserId())});
		Test.stopTest();

		kern.SEL_ApiCall.assertServiceCompleted(serviceName);
		Assert.areEqual(1, commitWorkStartingRuns, 'Expected onCommitWorkStarting to run once for the one attempt');
		Assert.areEqual(1, dmlStartingRuns, 'Expected onDMLStarting to run once for the one attempt');
		Assert.areEqual(1, dmlFinishedRuns, 'Expected onDMLFinished to run once for the one attempt');
		Assert.areEqual(1, commitWorkFinishingRuns, 'Expected onCommitWorkFinishing to run once for the one attempt');
	}

	/**
	 * @description A DmlException the handler throws itself after a successful answer ends the call Failed with that
	 * message and one issue: on a request the handler did not opt in, a failure in its own code is not retried. The issue
	 * says the external system may have acted, because it answered with success before the handler failed.
	 */
	@IsTest
	private static void shouldFailWithTheHandlersOwnDmlExceptionAndOneIssue()
	{
		String serviceName = RetryEdgeDmlThrowing.class.getName();
		registerRetryingSetting(serviceName);
		kern.API_MockFactory.forService(serviceName).body(EMPTY_BODY).statusCode(HTTP_OK).register();

		Test.startTest();
		kern.API_Dispatcher.execute(new List<kern__ApiCall__c> {kern.TST_Factory.newOutboundApiCall(serviceName, UserInfo.getUserId())});
		Test.stopTest();

		Assert.isNull(kern.SEL_ApiCall.assertServiceFailed(serviceName, MESSAGE_HANDLER_THREW)[0].kern__NextRetry__c, 'Expected the handler\'s own failure to schedule nothing');
		Assert.isTrue(findOnlyIssue(serviceName).kern__ExternalSystemMayHaveActed__c,
				'Expected the issue to say the external system may have acted: it answered with success first');
	}

	/**
	 * @description An inbound handler whose own handleError() override throws still answers: status 500, with the
	 * message the call failed with and the message its error handling failed with.
	 */
	@IsTest
	private static void shouldAnswer500WithBothMessagesWhenTheInboundErrorHandlingThrows()
	{
		String serviceName = RetryEdgeInbound.class.getName();
		kern.TST_Factory.newInboundApiSetting(serviceName, INBOUND_PATH);
		kern.API_InboundTestHelper.setupRestContext();

		Test.startTest();
		kern.API_Dispatcher.processInboundService(serviceName);
		Test.stopTest();

		String responseBody = RestContext.response.responseBody.toString();
		Assert.areEqual(HTTP_INTERNAL_SERVER_ERROR, RestContext.response.statusCode, 'Expected the caller to be answered 500');
		Assert.isTrue(responseBody.contains(MESSAGE_HANDLER_THREW), 'Expected the call\'s own failure in the answer, got ' + responseBody);
		Assert.isTrue(responseBody.contains(MESSAGE_ERROR_HANDLING_THREW), 'Expected the error handling\'s failure in the answer, got ' + responseBody);
	}

	/**
	 * @description An inbound handler's own onCommitWorkStarting() override runs once for a call it accepts, and the
	 * caller is answered 200. This class compiles only while an inbound handler can override the hook, the same proof
	 * the outbound commit-hooks test gives for an outbound handler.
	 */
	@IsTest
	private static void shouldRunTheInboundHandlersCommitWorkStartingOverrideOnce()
	{
		String serviceName = RetryEdgeInboundCommitHooks.class.getName();
		kern.TST_Factory.newInboundApiSetting(serviceName, INBOUND_PATH);
		kern.API_InboundTestHelper.setupRestContext(new RetryEdgePayload());

		Test.startTest();
		kern.API_Dispatcher.processInboundService(serviceName);
		Test.stopTest();

		kern.SEL_ApiCall.assertServiceCompleted(serviceName);
		Assert.areEqual(HTTP_OK, RestContext.response.statusCode, 'Expected the caller to be answered 200, got ' + RestContext.response.statusCode);
		Assert.areEqual(1, inboundCommitWorkStartingRuns, 'Expected onCommitWorkStarting to run once for the one attempt, got ' + inboundCommitWorkStartingRuns);
	}

	/**
	 * @description A 500 to a POST that carried no Idempotency-Key is not sent again: the external system may have
	 * processed it, so the call ends Failed with the labelled line, no retry spent, and an issue that says so.
	 */
	@IsTest
	private static void shouldNotResendAnUnkeyedPostAfterAServerError()
	{
		String serviceName = RetryEdgePost.class.getName();
		registerRetryingSetting(serviceName);
		kern.API_MockFactory.forService(serviceName).body(EMPTY_BODY).statusCode(HTTP_INTERNAL_SERVER_ERROR).register();

		Test.startTest();
		kern.API_Dispatcher.execute(new List<kern__ApiCall__c> {kern.TST_Factory.newOutboundApiCall(serviceName, UserInfo.getUserId())});
		Test.stopTest();

		String expectedLine = String.format(System.Label.kern.OutboundCall_ServerErrorNotRepeated, new List<Object> {serviceName, HTTP_INTERNAL_SERVER_ERROR});
		kern__ApiCall__c row = kern.SEL_ApiCall.assertServiceFailed(serviceName, expectedLine)[0];
		Assert.isNull(row.kern__NextRetry__c, 'Expected nothing scheduled after a server error on an unkeyed POST');
		Assert.areEqual(0, row.kern__Retries__c ?? 0, 'Expected the request not to be sent again');
		Assert.isTrue(findOnlyIssue(serviceName).kern__ExternalSystemMayHaveActed__c, 'Expected the issue to say the external system may have acted');
	}

	/**
	 * @description An async chain API step whose unkeyed POST got no answer stops retrying although attempts are left:
	 * the external system may have acted, so the chain fails with the labelled line in its message.
	 */
	@IsTest
	private static void shouldStopAnApiStepRetryWhenTheExternalSystemMayHaveActed()
	{
		String serviceName = RetryEdgePost.class.getName();
		registerRetryingSetting(serviceName);
		kern.API_MockFactory.forService(serviceName).withTransportFailure().register();

		Test.startTest();
		String executionId = kern.UTIL_AsyncChain.newChain(CHAIN_NAME)
				.then(new kern.UTIL_AsyncChain.ApiStep(RetryEdgePost.class).withRetry(CHAIN_STEP_ATTEMPTS, RETRY_BACKOFF_SECONDS))
				.execute();
		Test.stopTest();

		kern__AsyncChainExecution__c execution = (kern__AsyncChainExecution__c)kern.QRY_Builder.selectFrom(kern__AsyncChainExecution__c.SObjectType)
				.fields(new List<SObjectField> {kern__AsyncChainExecution__c.kern__Status__c, kern__AsyncChainExecution__c.kern__ErrorMessage__c})
				.condition(kern__AsyncChainExecution__c.Id).equals(executionId)
				.toList()[0];
		String expectedLine = String.format(System.Label.kern.OutboundCall_NoResponseNotRepeated, new List<Object> {serviceName});
		Assert.areEqual(STATUS_CHAIN_FAILED, execution.kern__Status__c, 'Expected the chain to stop with attempts left, got ' + execution.kern__Status__c);
		Assert.isTrue(execution.kern__ErrorMessage__c?.contains(expectedLine), 'Expected the labelled line in the message, got ' + execution.kern__ErrorMessage__c);
	}

	/**
	 * @description The Idempotency-Key recorded on the call is the one the request actually carried: a handler whose
	 * createRequest() override puts its own key on the request is recorded with that key, not the one the framework
	 * worked out from Idempotency Enabled.
	 */
	@IsTest
	private static void shouldRecordTheIdempotencyKeyTheRequestCarried()
	{
		String serviceName = RetryEdgeOwnKey.class.getName();
		kern.TST_Factory.newOutboundApiSetting(serviceName, new Map<SObjectField, Object>
		{
				kern__ApiSetting__mdt.kern__MaxRetryCount__c => RETRY_BUDGET,
				kern__ApiSetting__mdt.kern__RetryBackoffSeconds__c => RETRY_BACKOFF_SECONDS,
				kern__ApiSetting__mdt.kern__LogIssues__c => true,
				kern__ApiSetting__mdt.kern__IdempotencyEnabled__c => true
		});
		kern.API_MockFactory.forService(serviceName).body(EMPTY_BODY).statusCode(HTTP_OK).register();

		Test.startTest();
		kern.API_Dispatcher.execute(new List<kern__ApiCall__c> {kern.TST_Factory.newOutboundApiCall(serviceName, UserInfo.getUserId())});
		Test.stopTest();

		kern__ApiCall__c row = kern.SEL_ApiCall.assertServiceCompleted(serviceName)[0];
		Assert.areEqual(SENT_IDEMPOTENCY_KEY, row.kern__IdempotencyKey__c, 'Expected the key the request carried to be recorded');
	}

	/**
	 * @description useHandler(...).withIdempotencyKey(k).invoke() sends k and records it, and the keyed POST is safe to
	 * repeat: answered 500, it rests at Retry with a time. The handler's setting logs issues, so the failed attempt has
	 * exactly one issue, written by the handler's own commit. The issue carries the key and does not say the external
	 * system may have acted, because a request that carries a key is safe to send again.
	 */
	@IsTest
	private static void shouldRecordTheCallersKeyAndRetryAKeyedPostAnsweredWithAServerError()
	{
		String serviceName = RetryEdgePost.class.getName();
		registerRetryingSetting(serviceName);
		kern.API_MockFactory.forService(serviceName).body(EMPTY_BODY).statusCode(HTTP_INTERNAL_SERVER_ERROR).register();

		Test.startTest();
		kern.UTIL_HttpClient.useHandler(RetryEdgePost.class).withIdempotencyKey(IDEMPOTENCY_KEY).withRetry(RETRY_BUDGET, RETRY_BACKOFF_SECONDS).invoke();
		Test.stopTest();

		List<kern__ApiCall__c> rows = assertRetrying(serviceName);
		Assert.areEqual(IDEMPOTENCY_KEY, rows[0].kern__IdempotencyKey__c, 'Expected the caller\'s key to be sent and recorded');
		kern__ApiIssue__c issue = findOnlyIssue(serviceName);
		Assert.areEqual(IDEMPOTENCY_KEY, issue.kern__IdempotencyKey__c, 'Expected the issue to carry the key the request was sent with');
		Assert.isFalse(issue.kern__ExternalSystemMayHaveActed__c, 'Expected a keyed request, which is safe to send again, to leave the issue unmarked');
	}

	/**
	 * @description Registers the mocked setting the handler reads: retries on, a wait, issues logged.
	 *
	 * @param serviceName The handler class.
	 */
	private static void registerRetryingSetting(String serviceName)
	{
		registerSetting(serviceName, RETRY_BUDGET);
	}

	/**
	 * @description Registers the mocked setting the handler reads, with the retry budget given, a wait and issues logged.
	 *
	 * @param serviceName The handler class.
	 * @param retryBudget The number of retries the setting allows.
	 */
	private static void registerSetting(String serviceName, Integer retryBudget)
	{
		kern.TST_Factory.newOutboundApiSetting(serviceName, new Map<SObjectField, Object>
		{
				kern__ApiSetting__mdt.kern__MaxRetryCount__c => retryBudget,
				kern__ApiSetting__mdt.kern__RetryBackoffSeconds__c => RETRY_BACKOFF_SECONDS,
				kern__ApiSetting__mdt.kern__LogIssues__c => true
		});
	}

	/**
	 * @description Asserts every row of the service rests at Retry with a next retry time, the pair the retry flow reads.
	 *
	 * @param serviceName The handler class, or the credential of an ad-hoc call.
	 *
	 * @return The rows of the service.
	 */
	private static List<kern__ApiCall__c> assertRetrying(String serviceName)
	{
		List<kern__ApiCall__c> rows = new kern.SEL_ApiCall().findByServiceName(serviceName);
		Assert.isFalse(rows.isEmpty(), 'Expected a row stored for ' + serviceName);
		for(kern__ApiCall__c row : rows)
		{
			Assert.areEqual(STATUS_RETRY, row.kern__Status__c, 'Expected the row to rest at Retry');
			Assert.isNotNull(row.kern__NextRetry__c, 'Expected a Retry row to carry a time');
		}
		return rows;
	}

	/**
	 * @description Finds the one call that carries the key. An ad-hoc call's row is stored under the framework's own
	 * handler name, not its credential, so the key is what tells the test's call apart.
	 *
	 * @param idempotencyKey The key the call was sent with.
	 *
	 * @return The one call.
	 */
	private static kern__ApiCall__c findOnlyCallByKey(String idempotencyKey)
	{
		List<kern__ApiCall__c> rows = (List<kern__ApiCall__c>)new kern.SEL_ApiCall().findByField(kern__ApiCall__c.kern__IdempotencyKey__c, idempotencyKey);
		Assert.areEqual(1, rows.size(), 'Expected one call with key ' + idempotencyKey + ', got ' + rows.size());
		return rows[0];
	}

	/**
	 * @description Asserts the service has exactly one issue and returns it.
	 *
	 * @param serviceName The handler class.
	 *
	 * @return The one issue.
	 */
	private static kern__ApiIssue__c findOnlyIssue(String serviceName)
	{
		List<kern__ApiIssue__c> issues = (List<kern__ApiIssue__c>)new kern.SEL_ApiIssue().findByField(kern__ApiIssue__c.kern__ServiceName__c, serviceName);
		Assert.areEqual(1, issues.size(), 'Expected one issue for ' + serviceName + ', got ' + issues.size());
		return issues[0];
	}

	/**
	 * @description The exception the throwing handlers raise; its exact name is what the opted-in handler lists.
	 */
	public class RetryEdgeException extends Exception
	{
	}

	/**
	 * @description The payload both directions use; any JSON-capable DTO satisfies the handler.
	 */
	@JsonAccess(serializable='always' deserializable='always')
	public class RetryEdgePayload extends kern.DTO_JsonBase
	{
	}

	/**
	 * @description A GET handler with in-memory payloads and no triggering record, the base of this class's handlers.
	 */
	public virtual class RetryEdgeGet extends kern.API_Outbound
	{
		/**
		 * @description Sets the payloads and clears the triggering-record requirement.
		 */
		public override void configure()
		{
			super.configure();
			requestPayload = new RetryEdgePayload();
			responsePayload = new RetryEdgePayload();
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
	 * @description A POST handler with no idempotency key.
	 */
	public virtual class RetryEdgePost extends RetryEdgeGet
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
	}

	/**
	 * @description A GET handler whose strategy denylists the callout exception.
	 */
	public class RetryEdgeDenylisting extends RetryEdgeGet
	{
		/**
		 * @description Wraps the default strategy in a denylist of System.CalloutException.
		 *
		 * @return The filtered strategy.
		 */
		public override kern.UTIL_Retry.Strategy createRetryStrategy()
		{
			return kern.UTIL_Retry.dontRetryOnException(super.createRetryStrategy(), new Set<Type> {System.CalloutException.class});
		}
	}

	/**
	 * @description A handler whose own code throws before the send.
	 */
	public virtual class RetryEdgeThrowing extends RetryEdgeGet
	{
		/**
		 * @description Throws before the request is built.
		 */
		public override void prepareRequest()
		{
			throw new RetryEdgeException(MESSAGE_HANDLER_THREW);
		}
	}

	/**
	 * @description The same throwing handler, listing its own exception type as retryable.
	 */
	public class RetryEdgeOptedIn extends RetryEdgeThrowing
	{
		/**
		 * @description Lists the one type the framework may retry.
		 *
		 * @return The subscriber's own exception type.
		 */
		public override Set<Type> getRetryableExceptionTypes()
		{
			return new Set<Type> {RetryEdgeException.class};
		}
	}

	/**
	 * @description A handler that refuses the retry from parseResponse().
	 */
	public class RetryEdgeRefusing extends RetryEdgeGet
	{
		/**
		 * @description Refuses after a successful answer.
		 */
		public override void parseResponse()
		{
			throw new kern.UTIL_Exceptions.PermanentFailureException(MESSAGE_HANDLER_THREW);
		}
	}

	/**
	 * @description A GET handler that saves a record after a successful answer and counts the attempts of its commit
	 * through the global commit hooks an outbound handler can override.
	 */
	public class RetryEdgeCommitHooks extends RetryEdgeGet
	{
		/**
		 * @description Registers one record, so the commit has work and its hooks run.
		 */
		public override void onSuccess()
		{
			super.onSuccess();
			doInsert(kern.TST_Builder.of(kern__Foobar__c.SObjectType).withoutInsertion().build());
		}

		/**
		 * @description Counts one attempt that started, after the framework's own work.
		 */
		public override void onCommitWorkStarting()
		{
			super.onCommitWorkStarting();
			commitWorkStartingRuns++;
		}

		/**
		 * @description Counts one attempt that reached its first statement, after the framework's own work.
		 */
		public override void onDMLStarting()
		{
			super.onDMLStarting();
			dmlStartingRuns++;
		}

		/**
		 * @description Counts one attempt that finished its statements, after the framework's own work.
		 */
		public override void onDMLFinished()
		{
			super.onDMLFinished();
			dmlFinishedRuns++;
		}

		/**
		 * @description Counts one attempt that reached its finishing step, after the framework's own work.
		 */
		public override void onCommitWorkFinishing()
		{
			super.onCommitWorkFinishing();
			commitWorkFinishingRuns++;
		}
	}

	/**
	 * @description A GET handler that throws a DmlException of its own after a successful answer.
	 */
	public class RetryEdgeDmlThrowing extends RetryEdgeGet
	{
		/**
		 * @description Throws as a failed save in the handler's own code would.
		 */
		public override void onSuccess()
		{
			throw new DmlException(MESSAGE_HANDLER_THREW);
		}
	}

	/**
	 * @description A POST handler whose createRequest() override puts its own Idempotency-Key on the request.
	 */
	public class RetryEdgeOwnKey extends RetryEdgePost
	{
		/**
		 * @description Builds the framework's request, then replaces the key on it.
		 *
		 * @param requestBody The serialised request body.
		 *
		 * @return The request with the handler's own key.
		 */
		public override HttpRequest createRequest(String requestBody)
		{
			HttpRequest builtRequest = super.createRequest(requestBody);
			builtRequest.setHeader(HEADER_IDEMPOTENCY_KEY, SENT_IDEMPOTENCY_KEY);
			return builtRequest;
		}
	}

	/**
	 * @description An inbound handler whose processing throws and whose own error handling throws too.
	 */
	public class RetryEdgeInbound extends kern.API_Inbound
	{
		/**
		 * @description Sets the payloads.
		 */
		public override void configure()
		{
			super.configure();
			requestPayload = new RetryEdgePayload();
			responsePayload = new RetryEdgePayload();
		}

		/**
		 * @description Throws while processing the request.
		 */
		public override void processRequest()
		{
			throw new RetryEdgeException(MESSAGE_HANDLER_THREW);
		}

		/**
		 * @description Throws while handling the failure.
		 *
		 * @param error The exception the call failed with.
		 */
		public override void handleError(Exception error)
		{
			throw new RetryEdgeException(MESSAGE_ERROR_HANDLING_THREW);
		}
	}

	/**
	 * @description An inbound handler that accepts the request and counts the attempts of its commit through the
	 * onCommitWorkStarting() hook an inbound handler can override.
	 */
	public class RetryEdgeInboundCommitHooks extends kern.API_Inbound
	{
		/**
		 * @description Sets the payloads.
		 */
		public override void configure()
		{
			super.configure();
			requestPayload = new RetryEdgePayload();
			responsePayload = new RetryEdgePayload();
		}

		/**
		 * @description Counts one attempt that started, after the framework's own work.
		 */
		public override void onCommitWorkStarting()
		{
			super.onCommitWorkStarting();
			inboundCommitWorkStartingRuns++;
		}
	}
}
