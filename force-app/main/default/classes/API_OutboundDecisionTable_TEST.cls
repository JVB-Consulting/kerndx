// SPDX-License-Identifier: Apache-2.0
/**
 * @description Tests how the outbound engine decides whether to send a failed call again. Each test sends a request
 * through one of the real ways a call is made: a chain's API step, a call made through UTIL_HttpClient.useHandler(...),
 * the flow action, the bulk retry, the Retry button or the dispatcher. The mocked external system answers with an
 * error, with no response, or with a success that the handler then fails to process. Each test then checks what is
 * left on the call record and the issue: the call's status and its next retry time, the attempts spent, how many issues
 * there are, and whether each issue says the external system may have acted on the request. Every mocked setting leaves
 * retry budget. So when a call is not sent again, the reason is the engine's rule and never a spent budget. The tests
 * run one at a time because the setup creates the users the chain tests and the retry tests run as. The same cases are
 * listed in release-testing/decision-tables/outbound-retry-decision-table.json.
 *
 * @see API_Outbound
 * @see API_Outbound_TEST
 * @see UTIL_AsyncChain
 * @see CTRL_RetryApiIssue
 * @see FLOW_CallApi
 *
 * @author Jason van Beukering
 *
 * @group Web Services
 *
 * @date October 2026
 */
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest(seeAllData=false isParallel=false)
private class API_OutboundDecisionTable_TEST
{
	/**
	 * @description The retry budget every mocked setting carries: enough attempts that a call the engine does not retry
	 * is refused by the engine, never by an exhausted budget.
	 */
	private static final Integer RETRY_BUDGET = 3;

	/**
	 * @description The retry wait every mocked setting carries, in seconds.
	 */
	private static final Integer RETRY_BACKOFF_SECONDS = 30;

	/**
	 * @description The circuit breaker cool-off the circuit tests' setting carries, in seconds: longer than the retry wait
	 * and never waited out during a test, so a circuit the test opens stays open.
	 */
	private static final Integer CIRCUIT_TIMEOUT_SECONDS = 120;

	/**
	 * @description A circuit breaker cool-off of zero seconds. The breaker reads it as passed once the clock has moved on by
	 * one millisecond, which is how a test moves an open circuit to half-open without waiting.
	 */
	private static final Integer IMMEDIATE_CIRCUIT_TIMEOUT_SECONDS = 0;

	/**
	 * @description How many trial requests a half-open circuit lets through in one round. An API setting has no field for
	 * it, so a dispatched call always gets the breaker's default round of three.
	 */
	private static final Integer HALF_OPEN_TRIAL_REQUESTS = 3;

	/**
	 * @description How many attempts the chain's API step may make: budget left after the first attempt.
	 */
	private static final Integer CHAIN_RETRY_ATTEMPTS = 3;

	/**
	 * @description The chain's wait between attempts, in seconds: none, so a re-run happens within the test.
	 */
	private static final Integer CHAIN_RETRY_BACKOFF_SECONDS = 0;

	/**
	 * @description How many queueable hops the chain may make in the test: enough for the attempts the chain may run.
	 */
	private static final Integer CHAIN_STACK_DEPTH = 4;

	/**
	 * @description The attempt number of a step that succeeded the second time it ran.
	 */
	private static final Integer SECOND_ATTEMPT = 2;

	/**
	 * @description The name of the one-step chains the API step tests run.
	 */
	private static final String CHAIN_NAME = 'DecisionTableChain';

	/**
	 * @description Company name of the administrator the chain tests run as, unique to this class so the user can be read
	 * back by it.
	 */
	private static final String ADMINISTRATOR_COMPANY = 'API_OutboundDecisionTable_TEST-administrator';

	/**
	 * @description Company name of the resolver the retry tests run as: a Standard User holding the Kern API Issue Resolver
	 * permission set, the access an operator who retries issues has.
	 */
	private static final String API_ISSUE_RESOLVER_USER_COMPANY = 'API_OutboundDecisionTable_TEST-resolver';

	/**
	 * @description The body the mocked external system sends with a server error.
	 */
	private static final String SERVER_ERROR_BODY = '{"error":"bad gateway"}';

	/**
	 * @description The message of the refusal the strategy-refusing handlers throw from createRetryStrategy().
	 */
	private static final String MESSAGE_STRATEGY_REFUSED = 'the handler refused the retry while building its strategy';

	/**
	 * @description The message of the failure the strategy-refusing handlers throw from their own code.
	 */
	private static final String MESSAGE_HANDLER_FAILED = 'the handler failed on purpose';

	/**
	 * @description The phrase the platform's own message carries when it refuses a callout because the transaction has
	 * unsaved work pending.
	 */
	private static final String MESSAGE_UNCOMMITTED_WORK = 'uncommitted work pending';

	/**
	 * @description The phrase that opens the message of the transport failure a mock registered with
	 * withTransportFailure() throws at the send.
	 */
	private static final String MESSAGE_MOCKED_TRANSPORT_FAILURE = 'Simulated transport failure';

	/**
	 * @description An email value the platform refuses, so saving a record that carries it fails with a row error.
	 */
	private static final String INVALID_EMAIL = 'not-an-email';

	/**
	 * @description The service of the POST without an Idempotency-Key the flow, delegation, bulk retry and Retry button tests send.
	 */
	private static final String UNKEYED_POST_SERVICE_NAME = API_Outbound_TEST.PostTransportOutbound.class.getName();

	/**
	 * @description The service of the POST whose first call gets the server error the test registers and whose later calls
	 * succeed.
	 */
	private static final String FLAKY_POST_SERVICE_NAME = FlakyPostOutbound.class.getName();

	/**
	 * @description Creates the two users the tests run as: the administrator the chain tests run as, and the resolver the
	 * bulk retry and Retry button tests run as.
	 */
	@TestSetup
	private static void insertTheUsersTheTestsRunAs()
	{
		TST_Factory.newUserWithPermissionSet(SEL_Profile.PROFILE_SYSTEM_ADMIN, ADMINISTRATOR_COMPANY, SEL_PermissionSet.ADMIN_PERMISSION_SET_API_NAME);
		TST_Factory.newUserWithPermissionSet(SEL_Profile.PROFILE_STANDARD_USER, API_ISSUE_RESOLVER_USER_COMPANY, CTRL_RetryApiIssue.API_ISSUE_RESOLVER_PERMISSION_SET_NAME);
	}

	/**
	 * @description A chain's API step sends a POST with no Idempotency-Key, and the external system answers 502. The
	 * handler adds 502 to its own list of retryable statuses (getRetryableStatusCodes()). That is not a choice to send the
	 * request again: 502 is already in the default list, and a request that is not safe to repeat is never sent again
	 * after a 502. So the step stops after one callout, although the chain has retry budget left. The test checks that the
	 * chain is Failed with a step error, and that the error carries the line saying why the request was not sent again.
	 * It checks that the step failed for good on its first attempt. It checks that the one call record is Failed, with
	 * no next retry time and no attempt spent, and that its one issue says the external system may have acted.
	 */
	@IsTest
	private static void shouldStopAnApiStepOnAServerErrorItsHandlerAddsToItsRetryableSet()
	{
		System.runAs(getAdministrator())
		{
			enableAsyncChains();
			String serviceName = ServerErrorListingPostOutbound.class.getName();
			registerRetryingSetting(serviceName);
			API_MockFactory.forService(serviceName).body(SERVER_ERROR_BODY).statusCode(API_Base.HTTP_BAD_GATEWAY).register();

			Test.startTest();
			String executionId = executeOneStepChain(new UTIL_AsyncChain.ApiStep(ServerErrorListingPostOutbound.class));
			Test.stopTest();

			String notRepeatedLine = String.format(System.Label.OutboundCall_ServerErrorNotRepeated, new List<Object> {serviceName, API_Base.HTTP_BAD_GATEWAY});
			AsyncChainExecution__c execution = (AsyncChainExecution__c)new SEL_AsyncChainExecution().findById(executionId);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_FAILED, execution.Status__c, 'Expected the chain to fail, got ' + execution.Status__c);
			Assert.areEqual(SEL_AsyncChainExecution.FAILURE_CATEGORY_STEP_EXCEPTION, execution.FailureCategory__c,
					'Expected a step error, not an exhausted budget, got ' + execution.FailureCategory__c);
			Assert.isTrue(execution.ErrorMessage__c.contains(notRepeatedLine), 'Expected the chain error to carry the not-repeated line, got ' + execution.ErrorMessage__c);
			UTIL_AsyncChain.DTO_StepDefinition step = parseFirstStep(execution);
			Assert.isNull(step.attempt, 'Expected the step to run once, with no second attempt recorded, got attempt ' + step.attempt);
			Assert.areEqual(true, step.permanentFailure, 'Expected the step to fail for good, got ' + step.permanentFailure);
			Integer callouts = API_MockFactory.getInvocationCount(serviceName);
			Assert.areEqual(1, callouts, 'Expected one callout, got ' + callouts);
			assertFailedAsServerErrorNotRepeated(serviceName, API_Base.HTTP_BAD_GATEWAY);
		}
	}

	/**
	 * @description A chain's API step sends a POST with no Idempotency-Key, and names 502 in its retryOn(...). The
	 * external system answers 502 the first time and 200 after that. The step's author chose to retry on 502, so the chain
	 * runs the step again, and the step completes on its second attempt. The test checks that the first attempt's call
	 * record is Failed, with no next retry time and no attempt spent. Its errors start with the line saying the request was
	 * not sent again, because it is not safe to repeat. The test also checks that the one issue, from
	 * the first attempt, says the external system may have acted, and that the second attempt's call record is Completed.
	 */
	@IsTest
	private static void shouldRerunAnApiStepOnAServerErrorItNamesInRetryOn()
	{
		System.runAs(getAdministrator())
		{
			enableAsyncChains();
			registerRetryingSetting(FLAKY_POST_SERVICE_NAME);
			API_MockFactory.forService(FLAKY_POST_SERVICE_NAME).body(SERVER_ERROR_BODY).statusCode(API_Base.HTTP_BAD_GATEWAY).register();

			Test.startTest();
			String executionId = executeOneStepChain(new UTIL_AsyncChain.ApiStep(FlakyPostOutbound.class).retryOn(new Set<Integer> {API_Base.HTTP_BAD_GATEWAY}));
			Test.stopTest();

			AsyncChainExecution__c execution = (AsyncChainExecution__c)new SEL_AsyncChainExecution().findById(executionId);
			Assert.areEqual(SEL_AsyncChainExecution.STATUS_COMPLETED, execution.Status__c, 'Expected the chain to complete, got ' + execution.Status__c);
			UTIL_AsyncChain.DTO_StepDefinition step = parseFirstStep(execution);
			Assert.areEqual(SECOND_ATTEMPT, step.attempt, 'Expected the step to succeed on its second attempt, got attempt ' + step.attempt);
			Integer callouts = API_MockFactory.getInvocationCount(FLAKY_POST_SERVICE_NAME);
			Assert.areEqual(SECOND_ATTEMPT, callouts, 'Expected one callout per attempt, got ' + callouts);
			ApiCall__c firstAttempt = findTheOneCallWithStatus(FLAKY_POST_SERVICE_NAME, SEL_ApiCall.STATUS_FAILED);
			String notRepeatedLine = String.format(System.Label.OutboundCall_ServerErrorNotRepeated, new List<Object> {FLAKY_POST_SERVICE_NAME, API_Base.HTTP_BAD_GATEWAY});
			String firstAttemptErrors = firstAttempt.ErrorMessages__c;
			Assert.isTrue(firstAttemptErrors.startsWith(notRepeatedLine), 'Expected the first attempt\'s errors to open with the not-repeated line, got ' + firstAttemptErrors);
			Assert.isNull(firstAttempt.NextRetry__c, 'Expected no next retry time on a call the chain owns, got ' + firstAttempt.NextRetry__c);
			Assert.areEqual(0, countRetriesOf(firstAttempt), 'Expected no attempt spent on the first call, got ' + firstAttempt.Retries__c);
			findTheOneCallWithStatus(FLAKY_POST_SERVICE_NAME, SEL_ApiCall.STATUS_COMPLETED);
			List<ApiIssue__c> issues = new SEL_ApiIssue().findUnresolvedByService(FLAKY_POST_SERVICE_NAME);
			Assert.areEqual(1, issues.size(), 'Expected one issue, from the first attempt, got ' + issues.size());
			Assert.isTrue(issues[0].ExternalSystemMayHaveActed__c, 'Expected the first attempt\'s issue to say the external system may have acted, got false');
		}
	}

	/**
	 * @description A POST with no Idempotency-Key is sent through UTIL_HttpClient.useHandler(...).send(), and the external
	 * system answers 502, a status in the default retryable list. On this path the handler decides its own retry. The
	 * external system may have acted on the request, so it is not sent again. The test checks that send() returns the 502
	 * and that one callout was made. It checks that the call record is Failed, with no next retry time, no attempt spent
	 * and the line saying why the request was not sent again, and that its one issue says the external system may have
	 * acted.
	 */
	@IsTest
	private static void shouldNotResendAnUnkeyedPostOnAServerErrorThroughDelegation()
	{
		registerRetryingSetting(UNKEYED_POST_SERVICE_NAME);
		API_MockFactory.forService(UNKEYED_POST_SERVICE_NAME).body(SERVER_ERROR_BODY).statusCode(API_Base.HTTP_BAD_GATEWAY).register();

		Test.startTest();
		HttpResponse response = UTIL_HttpClient.useHandler(API_Outbound_TEST.PostTransportOutbound.class).send();
		Test.stopTest();

		Assert.areEqual(API_Base.HTTP_BAD_GATEWAY, response.getStatusCode(), 'Expected send() to answer with the 502, got ' + response.getStatusCode());
		Integer callouts = API_MockFactory.getInvocationCount(UNKEYED_POST_SERVICE_NAME);
		Assert.areEqual(1, callouts, 'Expected one callout, got ' + callouts);
		assertFailedAsServerErrorNotRepeated(UNKEYED_POST_SERVICE_NAME, API_Base.HTTP_BAD_GATEWAY);
	}

	/**
	 * @description The synchronous flow action sends a POST with no Idempotency-Key, and the request gets no response (a
	 * transport failure, which the handler does not list as retryable). The request may have reached the external system,
	 * so it is not sent again. The test checks that the flow action reports the failure. It checks that the call record is
	 * Failed, with no next retry time, no attempt spent and the line saying why the request was not sent again, and that
	 * the one issue says the external system may have acted.
	 */
	@IsTest
	private static void shouldFailAtOnceWhenAnUnkeyedPostThroughTheFlowGetsNoResponse()
	{
		registerRetryingSetting(UNKEYED_POST_SERVICE_NAME);
		API_MockFactory.forService(UNKEYED_POST_SERVICE_NAME).withTransportFailure().register();
		FLOW_CallApi.DTO_Request request = new FLOW_CallApi.DTO_Request();
		request.apiName = UNKEYED_POST_SERVICE_NAME;
		request.recordId = UserInfo.getUserId();

		Test.startTest();
		List<FLOW_CallApi.DTO_Response> responses = FLOW_CallApi.invokeApiCallSynchronously(new List<FLOW_CallApi.DTO_Request> {request});
		Test.stopTest();

		Assert.isFalse(responses[0].success, 'Expected the flow action to report the failure');
		assertFailedAsNotRepeatedAfterNoResponse(null);
	}

	/**
	 * @description A user with the API Issue Resolver permission set schedules a bulk retry of an open issue for a POST
	 * with no Idempotency-Key. The retried request gets no response (a transport failure, which the handler does not list
	 * as retryable). The test checks that a job was scheduled. It checks that the new call record is Failed, with no next
	 * retry time, no attempt spent and the line saying why the request was not sent again. It checks that the retried
	 * issue stays open, and that one new issue says the external system may have acted.
	 */
	@IsTest
	private static void shouldFailAtOnceWhenAnUnkeyedPostFromABulkRetryGetsNoResponse()
	{
		registerRetryingSetting(UNKEYED_POST_SERVICE_NAME);
		API_MockFactory.forService(UNKEYED_POST_SERVICE_NAME).withTransportFailure().register();
		ApiIssue__c retriedIssue;
		Id jobId;

		System.runAs(getUserWithApiIssueResolverPermissionSet())
		{
			retriedIssue = insertOpenIssue(UNKEYED_POST_SERVICE_NAME);
			Test.startTest();
			jobId = CTRL_RetryApiIssue.scheduleBulkRetry(UNKEYED_POST_SERVICE_NAME, 0);
			Test.stopTest();
		}

		Assert.isNotNull(jobId, 'Expected the bulk retry to schedule a job for the open issue');
		assertFailedAsNotRepeatedAfterNoResponse(retriedIssue.Id);
	}

	/**
	 * @description A user with the API Issue Resolver permission set presses Retry on an open issue for a POST with no
	 * Idempotency-Key. The retried request gets no response (a transport failure, which the handler does not list as
	 * retryable). The test checks that Retry reports the failure. It checks that the new call record is Failed, with no
	 * next retry time, no attempt spent and the line saying why the request was not sent again. It checks that the
	 * retried issue stays open, and that one new issue says the external system may have acted.
	 */
	@IsTest
	private static void shouldFailAtOnceWhenAnUnkeyedPostFromTheRetryButtonGetsNoResponse()
	{
		registerRetryingSetting(UNKEYED_POST_SERVICE_NAME);
		API_MockFactory.forService(UNKEYED_POST_SERVICE_NAME).withTransportFailure().register();
		ApiIssue__c retriedIssue;
		CTRL_RetryApiIssue.DTO_Response retryResponse;

		System.runAs(getUserWithApiIssueResolverPermissionSet())
		{
			retriedIssue = insertOpenIssue(UNKEYED_POST_SERVICE_NAME);
			Test.startTest();
			retryResponse = CTRL_RetryApiIssue.retry(retriedIssue.Id);
			Test.stopTest();
		}

		Assert.isFalse(retryResponse.callSuccessful, 'Expected Retry to report the failure');
		assertFailedAsNotRepeatedAfterNoResponse(retriedIssue.Id);
	}

	/**
	 * @description The test saves a record and then the dispatcher sends a GET, so the platform refuses the callout
	 * before it leaves the org. A callout that never left the org may be retried whatever its method, so the engine asks
	 * the handler for its retry strategy. The handler's createRetryStrategy() throws a
	 * UTIL_Exceptions.PermanentFailureException, and that ends the call. The test checks that the call record is Failed,
	 * with no next retry time and no attempt spent, and that its errors give the platform's own message before the
	 * refusal. It checks that the one issue does not say the external system may have acted, because nothing was sent.
	 */
	@IsTest
	private static void shouldFailAtOnceWhenBuildingTheStrategyRefusesACalloutThePlatformRefused()
	{
		String serviceName = StrategyRefusingGetOutbound.class.getName();
		registerRetryingSetting(serviceName);
		API_MockFactory.forService(serviceName).body(UTIL_String.EMPTY_JSON_RESPONSE).statusCode(API_Base.HTTP_OK).register();

		Test.startTest();
		TST_Builder.of(Foobar__c.SObjectType).build();
		API_Dispatcher.execute(TST_Factory.newOutboundApiCall(serviceName, UserInfo.getUserId()));
		Test.stopTest();

		assertFailedByTheStrategyRefusal(serviceName, MESSAGE_UNCOMMITTED_WORK, false);
	}

	/**
	 * @description The dispatcher sends a GET whose prepareRequest() throws before the send. The handler lists that
	 * exception type as retryable (getRetryableExceptionTypes()), so the engine asks the handler for its retry strategy.
	 * The handler's createRetryStrategy() throws a UTIL_Exceptions.PermanentFailureException, and that ends the call. The
	 * test checks that the call record is Failed, with no next retry time and no attempt spent, and that its errors give
	 * the handler's own message before the refusal. It checks that the one issue does not say the external system may
	 * have acted, because nothing was sent.
	 */
	@IsTest
	private static void shouldFailAtOnceWhenBuildingTheStrategyRefusesAFailureBeforeTheSend()
	{
		String serviceName = StrategyRefusingPrepareOutbound.class.getName();
		registerRetryingSetting(serviceName);

		Test.startTest();
		API_Dispatcher.execute(TST_Factory.newOutboundApiCall(serviceName, UserInfo.getUserId()));
		Test.stopTest();

		assertFailedByTheStrategyRefusal(serviceName, MESSAGE_HANDLER_FAILED, false);
	}

	/**
	 * @description The dispatcher sends a GET that gets no response (a transport failure, which the handler does not list
	 * as retryable). A GET is safe to repeat, so the engine asks the handler for its retry strategy. The handler's
	 * createRetryStrategy() throws a UTIL_Exceptions.PermanentFailureException, and that ends the call. The test checks
	 * that the call record is Failed, with no next retry time and no attempt spent, and that its errors give the transport
	 * failure's message before the refusal. It checks that the one issue does not say the external system may have
	 * acted, because repeating a GET is safe.
	 */
	@IsTest
	private static void shouldFailAtOnceWhenBuildingTheStrategyRefusesACallThatGotNoResponse()
	{
		String serviceName = StrategyRefusingGetOutbound.class.getName();
		registerRetryingSetting(serviceName);
		API_MockFactory.forService(serviceName).withTransportFailure().register();

		Test.startTest();
		API_Dispatcher.execute(TST_Factory.newOutboundApiCall(serviceName, UserInfo.getUserId()));
		Test.stopTest();

		assertFailedByTheStrategyRefusal(serviceName, MESSAGE_MOCKED_TRANSPORT_FAILURE, false);
	}

	/**
	 * @description The dispatcher sends a GET and the external system answers 200. The handler's parseResponse() then
	 * throws an exception type the handler lists as retryable. A GET is safe to repeat, so the engine asks the handler for
	 * its retry strategy. The handler's createRetryStrategy() throws a UTIL_Exceptions.PermanentFailureException, and that
	 * ends the call. The test checks that the call record is Failed, with no next retry time and no attempt spent, and
	 * that its errors give the handler's own message before the refusal. It checks that the one issue says the external
	 * system may have acted, because it accepted the request.
	 */
	@IsTest
	private static void shouldFailAtOnceWhenBuildingTheStrategyRefusesAFailureAfterASuccess()
	{
		String serviceName = StrategyRefusingParseOutbound.class.getName();
		registerRetryingSetting(serviceName);
		API_MockFactory.forService(serviceName).body(UTIL_String.EMPTY_JSON_RESPONSE).statusCode(API_Base.HTTP_OK).register();

		Test.startTest();
		API_Dispatcher.execute(TST_Factory.newOutboundApiCall(serviceName, UserInfo.getUserId()));
		Test.stopTest();

		assertFailedByTheStrategyRefusal(serviceName, MESSAGE_HANDLER_FAILED, true);
	}

	/**
	 * @description The test opens the service's circuit breaker (after repeated failures, a circuit breaker stops calls to
	 * a service for a cool-off time). The setting still leaves retry budget. The dispatcher sends a GET, and the open
	 * circuit refuses it. Such a call could wait for the cool-off, so the engine asks the handler for its retry strategy.
	 * The handler's createRetryStrategy() throws a UTIL_Exceptions.PermanentFailureException, and that ends the call
	 * instead of the wait. The test checks that the call record is Failed, with no next retry time and no attempt spent,
	 * and that its errors give the open-circuit line before the refusal. It checks that the one issue does not say the
	 * external system may have acted, because nothing was sent. In an org whose org cache has no space set aside, the
	 * open state cannot be saved, so the test checks that a new breaker for the service starts CLOSED instead.
	 */
	@IsTest
	private static void shouldFailAtOnceWhenBuildingTheStrategyRefusesACallTheOpenCircuitRefused()
	{
		String serviceName = StrategyRefusingGetOutbound.class.getName();
		registerCircuitBreakingSetting(serviceName);
		String circuitOpenLine = String.format(System.Label.OutboundCall_CircuitOpen, new List<Object> {serviceName});

		try
		{
			UTIL_CircuitBreaker.monitor(serviceName).forceOpen();
			if(!UTIL_Cache.isOrgAllocated())
			{
				assertTheNextBreakerStartsClosed(serviceName);
				return;
			}

			Test.startTest();
			API_Dispatcher.execute(TST_Factory.newOutboundApiCall(serviceName, UserInfo.getUserId()));
			Test.stopTest();
		}
		finally
		{
			UTIL_CircuitBreaker.monitor(serviceName).reset();
		}

		assertFailedByTheStrategyRefusal(serviceName, circuitOpenLine, false);
	}

	/**
	 * @description The test moves the service's circuit breaker to half-open, the state in which the circuit lets a few
	 * trial requests through. The setting still leaves retry budget. After a save, the dispatcher sends three GET calls.
	 * They use the round's three trial requests, and the platform refuses each one before it leaves the org. The fourth
	 * call finds no trial request left, and the circuit refuses it. The engine asks the handler for its retry strategy.
	 * The handler's createRetryStrategy() throws a UTIL_Exceptions.PermanentFailureException, and that ends the fourth
	 * call. The test checks that the fourth call record is Failed, with no next retry time and no attempt spent, and that
	 * its errors give the open-circuit line before the refusal. It checks that each of the four calls left one issue, and
	 * that no issue says the external system may have acted, because nothing was sent. In an org whose org cache has no
	 * space set aside, the half-open state cannot be saved, so the test checks that a new breaker for the service starts
	 * CLOSED instead.
	 */
	@IsTest
	private static void shouldFailAtOnceWhenBuildingTheStrategyRefusesACallTheHalfOpenCircuitRefused()
	{
		String serviceName = StrategyRefusingGetOutbound.class.getName();
		registerCircuitBreakingSetting(serviceName);
		API_MockFactory.forService(serviceName).body(UTIL_String.EMPTY_JSON_RESPONSE).statusCode(API_Base.HTTP_OK).register();
		String circuitOpenLine = String.format(System.Label.OutboundCall_CircuitOpen, new List<Object> {serviceName});
		ApiCall__c refused;

		try
		{
			UTIL_CircuitBreaker.State stateBeforeTheCalls = moveTheCircuitToHalfOpen(serviceName);
			if(!UTIL_Cache.isOrgAllocated())
			{
				assertTheNextBreakerStartsClosed(serviceName);
				return;
			}
			Assert.areEqual(UTIL_CircuitBreaker.State.HALF_OPEN, stateBeforeTheCalls, 'Expected the circuit to be half-open before the calls, got ' + stateBeforeTheCalls);

			Test.startTest();
			TST_Builder.of(Foobar__c.SObjectType).build();
			for(Integer trial = 0; trial < HALF_OPEN_TRIAL_REQUESTS; trial++)
			{
				API_Dispatcher.execute(TST_Factory.newOutboundApiCall(serviceName, UserInfo.getUserId()));
			}
			API_Base handler = API_Dispatcher.execute(TST_Factory.newOutboundApiCall(serviceName, UserInfo.getUserId()));
			Test.stopTest();
			refused = (ApiCall__c)new SEL_ApiCall().findById(handler.apiCall.Id);
		}
		finally
		{
			UTIL_CircuitBreaker.monitor(serviceName).reset();
		}

		Assert.areEqual(SEL_ApiCall.STATUS_FAILED, refused.Status__c, 'Expected the refused call to end Failed, got ' + refused.Status__c);
		String errorText = refused.ErrorMessages__c;
		Integer circuitLinePosition = errorText.indexOf(circuitOpenLine);
		Assert.isTrue(circuitLinePosition >= 0, 'Expected the open-circuit line on the refused call, got ' + errorText);
		Assert.isTrue(circuitLinePosition < errorText.indexOf(MESSAGE_STRATEGY_REFUSED), 'Expected the open-circuit line ahead of the refusal, got ' + errorText);
		Assert.isNull(refused.NextRetry__c, 'Expected no next retry time after the refusal, got ' + refused.NextRetry__c);
		Assert.areEqual(0, countRetriesOf(refused), 'Expected no attempt spent after the refusal, got ' + refused.Retries__c);
		List<ApiIssue__c> issues = new SEL_ApiIssue().findUnresolvedByService(serviceName);
		Assert.areEqual(HALF_OPEN_TRIAL_REQUESTS + 1, issues.size(), 'Expected one issue per call, got ' + issues.size());
		for(ApiIssue__c issue : issues)
		{
			Assert.isFalse(issue.ExternalSystemMayHaveActed__c, 'Expected no issue to say the external system may have acted, got true on ' + issue.Id);
		}
	}

	/**
	 * @description The dispatcher sends a GET and the external system answers 200. The handler then registers a record
	 * whose email value the platform refuses, so saving the handler's records fails after the external system accepted the
	 * request. The handler does not list that failure's type as retryable, so the call fails at once. The test checks that
	 * the call record is Failed, with no next retry time and no attempt spent, and that it carries the refused record's
	 * own error. It checks that the one issue says the external system may have acted.
	 */
	@IsTest
	private static void shouldFailAtOnceWhenTheCommitIsRefusedByValidation()
	{
		String serviceName = ValidationRefusedOutbound.class.getName();
		registerRetryingSetting(serviceName);
		API_MockFactory.forService(serviceName).body(UTIL_String.EMPTY_JSON_RESPONSE).statusCode(API_Base.HTTP_OK).register();

		Test.startTest();
		API_Dispatcher.execute(TST_Factory.newOutboundApiCall(serviceName, UserInfo.getUserId()));
		Test.stopTest();

		ApiCall__c failed = SEL_ApiCall.assertServiceFailed(serviceName, INVALID_EMAIL)[0];
		Assert.isNull(failed.NextRetry__c, 'Expected no next retry time after a refused commit, got ' + failed.NextRetry__c);
		Assert.areEqual(0, countRetriesOf(failed), 'Expected no attempt spent after a refused commit, got ' + failed.Retries__c);
		List<ApiIssue__c> issues = new SEL_ApiIssue().findUnresolvedByService(serviceName);
		Assert.areEqual(1, issues.size(), 'Expected one issue after a refused commit, got ' + issues.size());
		Assert.isTrue(issues[0].ExternalSystemMayHaveActed__c, 'Expected the issue to say the external system acted before the commit failed, got false');
	}

	/**
	 * @description Asserts that a call whose request was not safe to repeat ended Failed after a server error: one call row
	 * with no next retry time, no attempt spent and the labelled not-repeated line, and one issue that says the external
	 * system may have acted.
	 *
	 * @param serviceName The handler whose row and issue are read back.
	 * @param statusCode The status the external system responded with.
	 */
	private static void assertFailedAsServerErrorNotRepeated(String serviceName, Integer statusCode)
	{
		String notRepeatedLine = String.format(System.Label.OutboundCall_ServerErrorNotRepeated, new List<Object> {serviceName, statusCode});
		List<ApiCall__c> failed = SEL_ApiCall.assertServiceFailed(serviceName, notRepeatedLine);
		Assert.areEqual(1, failed.size(), 'Expected one call row after status ' + statusCode + ', got ' + failed.size());
		Assert.isNull(failed[0].NextRetry__c, 'Expected no next retry time after status ' + statusCode + ', got ' + failed[0].NextRetry__c);
		Assert.areEqual(0, countRetriesOf(failed[0]), 'Expected no attempt spent after status ' + statusCode + ', got ' + failed[0].Retries__c);
		List<ApiIssue__c> issues = new SEL_ApiIssue().findUnresolvedByService(serviceName);
		Assert.areEqual(1, issues.size(), 'Expected one issue after status ' + statusCode + ', got ' + issues.size());
		Assert.isTrue(issues[0].ExternalSystemMayHaveActed__c, 'Expected the issue after status ' + statusCode + ' to say the external system may have acted, got false');
	}

	/**
	 * @description Asserts that the POST without an Idempotency-Key that got no response ended Failed and was not
	 * repeated: its call row has no next retry time, no attempt spent and the labelled not-repeated line, and of the
	 * service's open issues, the one opened for that call says the external system may have acted. When an issue was
	 * retried, it stays open and is left out of the count.
	 *
	 * @param retriedIssueId The open issue the call retried, or null when the call retried none.
	 */
	private static void assertFailedAsNotRepeatedAfterNoResponse(Id retriedIssueId)
	{
		String notRepeatedLine = String.format(System.Label.OutboundCall_NoResponseNotRepeated, new List<Object> {UNKEYED_POST_SERVICE_NAME});
		List<ApiCall__c> failed = SEL_ApiCall.assertServiceFailed(UNKEYED_POST_SERVICE_NAME, notRepeatedLine);
		Assert.areEqual(1, failed.size(), 'Expected one call row, got ' + failed.size());
		Assert.isNull(failed[0].NextRetry__c, 'Expected no next retry time, got ' + failed[0].NextRetry__c);
		Assert.areEqual(0, countRetriesOf(failed[0]), 'Expected no attempt spent, got ' + failed[0].Retries__c);
		List<ApiIssue__c> newIssues = new List<ApiIssue__c>();
		Boolean isRetriedIssueOpen = false;
		for(ApiIssue__c issue : new SEL_ApiIssue().findUnresolvedByService(UNKEYED_POST_SERVICE_NAME))
		{
			if(issue.Id == retriedIssueId)
			{
				isRetriedIssueOpen = true;
			}
			else
			{
				newIssues.add(issue);
			}
		}
		Assert.areEqual(retriedIssueId != null, isRetriedIssueOpen, 'Expected a retried issue to stay open after the failed retry');
		Assert.areEqual(1, newIssues.size(), 'Expected one issue for the call, got ' + newIssues.size());
		Assert.isTrue(newIssues[0].ExternalSystemMayHaveActed__c, 'Expected the issue to say the external system may have acted, got false');
	}

	/**
	 * @description Asserts that a call the strategy refused ended Failed: one call row with no next retry time and no
	 * attempt spent, whose errors carry the failure's own message ahead of the refusal, and one issue whose flag says
	 * whether the external system may have acted.
	 *
	 * @param serviceName The handler whose row and issue are read back.
	 * @param failurePhrase A phrase of the failure's own message, which comes first.
	 * @param isExternalSystemExpectedToHaveActed The flag the issue must carry.
	 */
	private static void assertFailedByTheStrategyRefusal(String serviceName, String failurePhrase, Boolean isExternalSystemExpectedToHaveActed)
	{
		List<ApiCall__c> failed = SEL_ApiCall.assertServiceFailed(serviceName, MESSAGE_STRATEGY_REFUSED);
		Assert.areEqual(1, failed.size(), 'Expected one call row, got ' + failed.size());
		String errorText = failed[0].ErrorMessages__c;
		Integer failurePosition = errorText.indexOf(failurePhrase);
		Assert.isTrue(failurePosition >= 0, 'Expected the failure\'s own message "' + failurePhrase + '" on the call, got ' + errorText);
		Assert.isTrue(failurePosition < errorText.indexOf(MESSAGE_STRATEGY_REFUSED), 'Expected the failure\'s own message ahead of the refusal, got ' + errorText);
		Assert.isNull(failed[0].NextRetry__c, 'Expected no next retry time after the refusal, got ' + failed[0].NextRetry__c);
		Assert.areEqual(0, countRetriesOf(failed[0]), 'Expected no attempt spent after the refusal, got ' + failed[0].Retries__c);
		List<ApiIssue__c> issues = new SEL_ApiIssue().findUnresolvedByService(serviceName);
		Assert.areEqual(1, issues.size(), 'Expected one issue, got ' + issues.size());
		Assert.areEqual(isExternalSystemExpectedToHaveActed, issues[0].ExternalSystemMayHaveActed__c,
				'Expected the issue flag ' + isExternalSystemExpectedToHaveActed + ', got ' + issues[0].ExternalSystemMayHaveActed__c);
	}

	/**
	 * @description Reads the one call row of a service with the given status, asserting there is exactly one.
	 *
	 * @param serviceName The service whose rows are read.
	 * @param status The status the row must have.
	 *
	 * @return The row.
	 */
	private static ApiCall__c findTheOneCallWithStatus(String serviceName, String status)
	{
		List<ApiCall__c> matching = new List<ApiCall__c>();
		for(ApiCall__c apiCall : new SEL_ApiCall().findByServiceName(serviceName))
		{
			if(apiCall.Status__c == status)
			{
				matching.add(apiCall);
			}
		}
		Assert.areEqual(1, matching.size(), 'Expected one ' + status + ' call row for ' + serviceName + ', got ' + matching.size());
		return matching[0];
	}

	/**
	 * @description Registers the mocked setting the handler reads: retry budget and a wait, issues logged, and retries of
	 * its issues allowed, so the bulk retry and the Retry button may send it again.
	 *
	 * @param serviceName The handler class the setting names.
	 */
	private static void registerRetryingSetting(String serviceName)
	{
		TST_Factory.newOutboundApiSetting(serviceName, new Map<SObjectField, Object>
		{
				ApiSetting__mdt.MaxRetryCount__c => RETRY_BUDGET,
				ApiSetting__mdt.RetryBackoffSeconds__c => RETRY_BACKOFF_SECONDS,
				ApiSetting__mdt.LogIssues__c => true,
				ApiSetting__mdt.RetryIssues__c => true
		});
	}

	/**
	 * @description Registers the mocked setting the circuit tests' handler reads: retry budget and a wait, issues logged,
	 * and the circuit breaker on with a cool-off no test waits out.
	 *
	 * @param serviceName The handler class the setting names.
	 */
	private static void registerCircuitBreakingSetting(String serviceName)
	{
		TST_Factory.newOutboundApiSetting(serviceName, new Map<SObjectField, Object>
		{
				ApiSetting__mdt.MaxRetryCount__c => RETRY_BUDGET,
				ApiSetting__mdt.RetryBackoffSeconds__c => RETRY_BACKOFF_SECONDS,
				ApiSetting__mdt.LogIssues__c => true,
				ApiSetting__mdt.CircuitBreakerEnabled__c => true,
				ApiSetting__mdt.CircuitBreakerTimeout__c => CIRCUIT_TIMEOUT_SECONDS
		});
	}

	/**
	 * @description Takes a service's circuit to half-open with no trial request used. One breaker opens the circuit; a
	 * second breaker for the same circuit, with a zero cool-off and built once the clock has moved on by a millisecond,
	 * reads the cool-off as passed and moves the circuit to half-open. That state is saved, so the breaker the handler
	 * builds from its setting finds the circuit half-open.
	 *
	 * @param serviceName The service whose circuit is taken to half-open.
	 *
	 * @return The state the circuit was left in, for the test to check.
	 */
	private static UTIL_CircuitBreaker.State moveTheCircuitToHalfOpen(String serviceName)
	{
		UTIL_CircuitBreaker.monitor(serviceName).forceOpen();
		Long openedAt = Datetime.now().getTime();
		Long currentTime = openedAt;
		while(currentTime == openedAt)
		{
			currentTime = Datetime.now().getTime();
		}
		return UTIL_CircuitBreaker.monitor(serviceName).withTimeout(IMMEDIATE_CIRCUIT_TIMEOUT_SECONDS).getState();
	}

	/**
	 * @description Checks what a circuit breaker does in an org whose org cache has no space set aside. A breaker keeps
	 * its state in the org cache only, so the state an earlier breaker set cannot be saved, and a new breaker for the
	 * service, like the one the handler builds from its setting, finds no state and starts CLOSED.
	 *
	 * @param serviceName The service whose circuit the test opened.
	 */
	private static void assertTheNextBreakerStartsClosed(String serviceName)
	{
		UTIL_CircuitBreaker.State stateOfTheNextBreaker = UTIL_CircuitBreaker.monitor(serviceName).getState();
		Assert.areEqual(UTIL_CircuitBreaker.State.CLOSED, stateOfTheNextBreaker, 'Expected a new breaker to start CLOSED with no org cache space, got ' + stateOfTheNextBreaker);
	}

	/**
	 * @description Saves an open issue of a service, the kind the bulk retry and the Retry button send again.
	 *
	 * @param serviceName The service the issue names.
	 *
	 * @return The saved issue.
	 */
	private static ApiIssue__c insertOpenIssue(String serviceName)
	{
		ApiCall__c apiCall = TST_Factory.newOutboundApiCall(serviceName, UserInfo.getUserId(), UTIL_Random.randomName(), UTIL_Random.randomName());
		return TST_Factory.insertApiIssue(apiCall, UTIL_Crypto.generateMD5Hash(apiCall.RequestParameters__c));
	}

	/**
	 * @description Runs a one-step chain whose API step has chain retry on with budget left and no wait.
	 *
	 * @param step The API step, without its retry setting.
	 *
	 * @return The execution record ID.
	 */
	private static String executeOneStepChain(UTIL_AsyncChain.ApiStep step)
	{
		AsyncOptions options = new AsyncOptions();
		options.maximumQueueableStackDepth = CHAIN_STACK_DEPTH;
		return UTIL_AsyncChain.newChain(CHAIN_NAME).then(step.withRetry(CHAIN_RETRY_ATTEMPTS, CHAIN_RETRY_BACKOFF_SECONDS)).withAsyncOptions(options).execute();
	}

	/**
	 * @description Reads the first step of a chain's step log.
	 *
	 * @param execution The execution record whose StepLog__c is read.
	 *
	 * @return The first step's entry.
	 */
	private static UTIL_AsyncChain.DTO_StepDefinition parseFirstStep(AsyncChainExecution__c execution)
	{
		return ((List<UTIL_AsyncChain.DTO_StepDefinition>)JSON.deserialize(execution.StepLog__c, List<UTIL_AsyncChain.DTO_StepDefinition>.class))[0];
	}

	/**
	 * @description Switches the async chain feature on for the test, through the feature flag indexes the flag selector
	 * reads.
	 */
	private static void enableAsyncChains()
	{
		FeatureFlag__mdt flag = (FeatureFlag__mdt)TST_Builder.of(FeatureFlag__mdt.SObjectType)
				.withOverride(FeatureFlag__mdt.DeveloperName, UTIL_AsyncChain.FEATURE_FLAG_NAME)
				.withOverride(FeatureFlag__mdt.IsActive__c, true)
				.withOverride(FeatureFlag__mdt.IsEnabledByDefault__c, true)
				.withOverride(FeatureFlag__mdt.ResultOnNoMatch__c, true)
				.withoutInsertion()
				.build();
		SEL_FeatureFlag.allDeveloperNames = new Set<String> {UTIL_AsyncChain.FEATURE_FLAG_NAME};
		SEL_FeatureFlag.activeFlags = new Map<String, FeatureFlag__mdt> {UTIL_AsyncChain.FEATURE_FLAG_NAME => flag};
	}

	/**
	 * @description Reads a row's retry count as an integer, null counting as zero.
	 *
	 * @param item The row.
	 *
	 * @return The retry count.
	 */
	private static Integer countRetriesOf(ApiCall__c item)
	{
		return (item.Retries__c ?? 0).intValue();
	}

	/**
	 * @description Reads back the administrator the chain tests run as.
	 *
	 * @return The System Administrator holding the Kern Administrator permission set.
	 */
	private static User getAdministrator()
	{
		return new SEL_User().findByCompanyName(ADMINISTRATOR_COMPANY);
	}

	/**
	 * @description Reads back the user the retry tests run as.
	 *
	 * @return The Standard User holding the Kern API Issue Resolver permission set.
	 */
	private static User getUserWithApiIssueResolverPermissionSet()
	{
		return new SEL_User().findByCompanyName(API_ISSUE_RESOLVER_USER_COMPANY);
	}

	/**
	 * @description The failure the strategy-refusing handlers throw from their own code. They list this type as
	 * retryable, so the engine goes on to ask them for their retry strategy.
	 */
	public class HandlerFailureException extends Exception
	{
	}

	/**
	 * @description A POST without an Idempotency-Key whose getRetryableStatusCodes() override adds 502 to the default
	 * set.
	 */
	public class ServerErrorListingPostOutbound extends API_Outbound_TEST.PostTransportOutbound
	{
		/**
		 * @description Adds the bad gateway status to the default set.
		 *
		 * @return The default statuses plus 502.
		 */
		public override Set<Integer> getRetryableStatusCodes()
		{
			Set<Integer> codes = super.getRetryableStatusCodes();
			codes.add(API_Base.HTTP_BAD_GATEWAY);
			return codes;
		}
	}

	/**
	 * @description A POST without an Idempotency-Key whose first call gets the error the test registers and whose later
	 * calls succeed: configure() registers a successful response once a callout has been made.
	 */
	public class FlakyPostOutbound extends API_Outbound_TEST.PostTransportOutbound
	{
		/**
		 * @description Sets the handler up, and registers a successful response once a callout has been made.
		 */
		public override void configure()
		{
			super.configure();
			if(API_MockFactory.getInvocationCount(FLAKY_POST_SERVICE_NAME) >= 1)
			{
				API_MockFactory.forService(FLAKY_POST_SERVICE_NAME).body(UTIL_String.EMPTY_JSON_RESPONSE).statusCode(API_Base.HTTP_OK).register();
			}
		}
	}

	/**
	 * @description A GET whose createRetryStrategy() refuses the retry by throwing a UTIL_Exceptions.PermanentFailureException.
	 * It lists its own failure type as retryable, so the engine also asks for the strategy after a failure of its own code.
	 */
	public virtual class StrategyRefusingGetOutbound extends API_Outbound_TEST.RetryProbeOutbound
	{
		/**
		 * @description Refuses the retry instead of building a strategy.
		 *
		 * @return Never returns.
		 */
		public override UTIL_Retry.Strategy createRetryStrategy()
		{
			throw new UTIL_Exceptions.PermanentFailureException(MESSAGE_STRATEGY_REFUSED);
		}

		/**
		 * @description Lists the handler's own failure type as retryable.
		 *
		 * @return The handler failure type.
		 */
		public override Set<Type> getRetryableExceptionTypes()
		{
			return new Set<Type> {HandlerFailureException.class};
		}
	}

	/**
	 * @description The strategy-refusing GET whose prepareRequest() fails before the send.
	 */
	public class StrategyRefusingPrepareOutbound extends StrategyRefusingGetOutbound
	{
		/**
		 * @description Fails before the request is built.
		 */
		public override void prepareRequest()
		{
			throw new HandlerFailureException(MESSAGE_HANDLER_FAILED);
		}
	}

	/**
	 * @description The strategy-refusing GET whose parseResponse() fails after a successful response.
	 */
	public class StrategyRefusingParseOutbound extends StrategyRefusingGetOutbound
	{
		/**
		 * @description Fails while reading the response.
		 */
		public override void parseResponse()
		{
			throw new HandlerFailureException(MESSAGE_HANDLER_FAILED);
		}
	}

	/**
	 * @description A GET that registers a record the platform refuses, so saving the handler's records fails after a
	 * successful response.
	 */
	public class ValidationRefusedOutbound extends API_Outbound_TEST.RetryProbeOutbound
	{
		/**
		 * @description Registers a record whose email value the platform refuses.
		 */
		public override void onSuccess()
		{
			registerFoobar(Foobar__c.Email__c, INVALID_EMAIL);
		}
	}
}
