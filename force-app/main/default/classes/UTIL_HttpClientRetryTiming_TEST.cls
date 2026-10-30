// SPDX-License-Identifier: Apache-2.0
/**
 * @description Tests for how long a failed outbound call waits before its scheduled retry, and for how its retry count
 * (Retries__c) adds up across runs. A scheduled retry is a later attempt the framework plans by setting the call to
 * Retry with a next retry time. The tests cover calls built with withRetry and withExponentialBackoff, stored calls the
 * dispatcher runs again, and handlers called through useHandler. The base wait is 30 seconds, so every wait a test
 * expects differs from the wrong one by 15 seconds or more, and a slow org cannot pass a wrong value.
 *
 * @see UTIL_HttpClient
 * @see API_Outbound
 *
 * @author Jason van Beukering
 *
 * @group Web Services
 *
 * @date October 2026
 */
@IsTest(seeAllData=false isParallel=false)
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
private class UTIL_HttpClientRetryTiming_TEST
{
	/**
	 * @description Test credential name.
	 */
	private static final String TEST_CREDENTIAL = 'TestCredential';

	/**
	 * @description Test URL path for callouts.
	 */
	private static final String TEST_PATH = '/api/v1/resource';

	/**
	 * @description The service name for the mocks of the client's own handler, which takes the credential name as its
	 * service name.
	 */
	private static final String HANDLER_SERVICE = TEST_CREDENTIAL;

	/**
	 * @description The body of every mock answer. The tests read only its status.
	 */
	private static final String MOCK_BODY = UTIL_String.EMPTY_JSON_RESPONSE;

	/**
	 * @description The base wait, in seconds, of every test in this class.
	 */
	private static final Integer BASE_BACKOFF_SECONDS = 30;

	/**
	 * @description A retry budget larger than the three re-sends allowed in one transaction, so budget is left for a
	 * scheduled retry once those re-sends are used.
	 */
	private static final Integer RETRY_BUDGET_BEYOND_SYNCHRONOUS = 5;

	/**
	 * @description A retry budget large enough that a stored call with four retries counted still has room for three
	 * re-sends and a scheduled retry.
	 */
	private static final Integer LARGE_RETRY_BUDGET = 10;

	/**
	 * @description The retry budget of the stored calls answered with a 429: room for the retries numbered 0, 1 and 2.
	 */
	private static final Integer STORED_CALL_RETRY_BUDGET = 3;

	/**
	 * @description The retry count of a stored call that has one retry left of a budget of 5.
	 */
	private static final Integer RETRIES_WITH_ONE_LEFT = 4;

	/**
	 * @description The waits, in seconds, of the scheduled retries numbered 0, 1 and 2 under exponential backoff: the base
	 * of 30 seconds, then doubled once, then doubled twice.
	 */
	private static final List<Integer> EXPONENTIAL_WAITS = new List<Integer> {30, 60, 120};

	/**
	 * @description The waits, in seconds, of the scheduled retries numbered 0, 1 and 2 under the default backoff: the base
	 * of 30 seconds for the first two, then the base times 2.
	 */
	private static final List<Integer> LINEAR_WAITS = new List<Integer> {30, 30, 60};

	/**
	 * @description The wait, in seconds, of a retry scheduled after the three re-sends of the first run under exponential
	 * backoff: the base of 30 seconds doubled three times.
	 */
	private static final Integer EXPONENTIAL_WAIT_AFTER_SYNCHRONOUS_RETRIES = 240;

	/**
	 * @description The wait, in seconds, of a retry scheduled after the three re-sends of the first run under the default
	 * backoff: the base of 30 seconds times 3.
	 */
	private static final Integer LINEAR_WAIT_AFTER_SYNCHRONOUS_RETRIES = 90;

	/**
	 * @description The retry count after a first run with three re-sends and one scheduled retry.
	 */
	private static final Integer RETRIES_AFTER_FIRST_RUN = 4;

	/**
	 * @description The longest wait, in seconds, the default exponential strategy allows. The base of 30 seconds doubled
	 * seven times is far more, so a call with seven retries counted waits this long.
	 */
	private static final Integer MAXIMUM_WAIT_SECONDS = 300;

	/**
	 * @description The retry count after a stored call with four retries counted runs again with a budget of 10: four
	 * counted, three re-sends in the transaction, and one scheduled retry.
	 */
	private static final Integer RETRIES_AFTER_SECOND_RUN = 8;

	/**
	 * @description The circuit breaker's time-out, in seconds, when the service setting gives none. A call the open
	 * circuit refused waits at least this long.
	 */
	private static final Integer DEFAULT_CIRCUIT_TIMEOUT_SECONDS = 60;

	/**
	 * @description The base wait, in seconds, of the test handler that chooses its own retry strategy. It differs from
	 * the 30 seconds the caller asks for and from the 45 seconds of the handler's service setting, so the test can tell
	 * which one decided.
	 */
	private static final Integer OWN_STRATEGY_BACKOFF_SECONDS = 75;

	/**
	 * @description The base wait, in seconds, in the service setting of the test handler. It differs from the 30 seconds
	 * the caller asks for, so a test can tell whose base wait was used.
	 */
	private static final Integer HANDLER_SETTING_BACKOFF_SECONDS = 45;

	/**
	 * @description The maximum number of retries in the service setting of the test handler. It differs from the
	 * maximum the caller asks for, so a test can tell whose maximum was used.
	 */
	private static final Integer HANDLER_SETTING_RETRY_BUDGET = 5;

	/**
	 * @description The waits, in seconds, of the first and second scheduled retries of the test handler when the caller
	 * sets no retry values: the base of 45 seconds from its service setting, twice.
	 */
	private static final List<Integer> HANDLER_SETTING_WAITS = new List<Integer> {45, 45};

	/**
	 * @description The maximum number of retries the caller asks for on a call made through useHandler. It is lower than
	 * the 5 of the handler's service setting.
	 */
	private static final Integer CALLER_RETRY_BUDGET = 3;

	/**
	 * @description The maximum number of retries the caller asks for on a call to a handler that has no service setting.
	 */
	private static final Integer CALLER_RETRY_BUDGET_WITHOUT_SETTING = 2;

	/**
	 * @description The number of milliseconds in one second.
	 */
	private static final Long MILLISECONDS_PER_SECOND = 1000;

	/**
	 * @description How far, in milliseconds, a saved time may sit before the time the test took. A saved date and time
	 * keeps whole seconds only, so it can be up to 999 milliseconds earlier than the exact time.
	 */
	private static final Long SAVED_TIME_TOLERANCE_MILLISECONDS = 1000;

	/**
	 * @description A stored call made with withExponentialBackoff(3, 30) waits twice as long before each scheduled retry:
	 * 30, 60 and 120 seconds for the retries numbered 0, 1 and 2. The default backoff would wait 30, 30 and 60 seconds, so
	 * the retries numbered 1 and 2 tell the two apart. Each call gets a 429, which is never re-sent in the transaction, so
	 * the retry's number is the count the call was stored with.
	 */
	@IsTest
	private static void shouldDoubleTheWaitBeforeEachScheduledRetryOfAnExponentialBackoffCall()
	{
		assertStoredCallWaits(true, EXPONENTIAL_WAITS);
	}

	/**
	 * @description A stored call made with withRetry(3, 30) keeps the default waits: 30, 30 and 60 seconds for the
	 * scheduled retries numbered 0, 1 and 2.
	 */
	@IsTest
	private static void shouldKeepTheDefaultWaitsForAStoredCallWithoutExponentialBackoff()
	{
		assertStoredCallWaits(false, LINEAR_WAITS);
	}

	/**
	 * @description A first run of a request built with withExponentialBackoff gets a 500 and is re-sent three times in the
	 * transaction. The retry scheduled after that is the one numbered 3: it waits the base of 30 seconds doubled three
	 * times, 240 seconds, not the 90 seconds of the default backoff. The count is then 4: three re-sends and the
	 * scheduled retry.
	 */
	@IsTest
	private static void shouldScheduleTheRetryAfterTheSynchronousAttemptsWithAnExponentialWait()
	{
		assertFirstRunWait(UTIL_HttpClient.get(TEST_CREDENTIAL, TEST_PATH)
				.withExponentialBackoff(RETRY_BUDGET_BEYOND_SYNCHRONOUS, BASE_BACKOFF_SECONDS), EXPONENTIAL_WAIT_AFTER_SYNCHRONOUS_RETRIES);
	}

	/**
	 * @description A first run of a request built with withRetry gets a 500 and is re-sent three times in the transaction.
	 * The retry scheduled after that keeps the default wait: the base of 30 seconds times 3, which is 90 seconds. The
	 * count is then 4.
	 */
	@IsTest
	private static void shouldScheduleTheRetryAfterTheSynchronousAttemptsWithTheDefaultWait()
	{
		assertFirstRunWait(UTIL_HttpClient.get(TEST_CREDENTIAL, TEST_PATH)
				.withRetry(RETRY_BUDGET_BEYOND_SYNCHRONOUS, BASE_BACKOFF_SECONDS), LINEAR_WAIT_AFTER_SYNCHRONOUS_RETRIES);
	}

	/**
	 * @description A stored call has used 4 of its 5 retries and gets a 500 again. It may be re-sent once more in the
	 * transaction, and then its budget is used up: it ends Failed with no next retry time and a count of 5. Without the
	 * count adding up, the call would be re-sent three times and scheduled again, and would never stop.
	 */
	@IsTest
	private static void shouldEndFailedWhenAStoredCallUsesUpItsRetryBudget()
	{
		assertStoredCallEndsFailed(RETRIES_WITH_ONE_LEFT, RETRY_BUDGET_BEYOND_SYNCHRONOUS);
	}

	/**
	 * @description A stored call that has already used all 5 of its retries is sent once and not again in the transaction.
	 * It ends Failed with no next retry time, and its count stays at 5.
	 */
	@IsTest
	private static void shouldNotSendAgainWhenAStoredCallHasNoRetryLeft()
	{
		assertStoredCallEndsFailed(RETRY_BUDGET_BEYOND_SYNCHRONOUS, RETRY_BUDGET_BEYOND_SYNCHRONOUS);
	}

	/**
	 * @description A stored exponential call with 4 retries counted and a budget of 10 gets a 500. It is re-sent three
	 * times in the transaction, so its count reaches 7 before the scheduled retry. The base of 30 seconds doubled seven
	 * times is more than the longest wait, so it waits 300 seconds. The scheduled retry makes the count 8, saved on the
	 * row.
	 */
	@IsTest
	private static void shouldAddTheRetriesOfThisRunToTheStoredCount()
	{
		registerMock(HANDLER_SERVICE, API_Base.HTTP_INTERNAL_SERVER_ERROR);
		ApiCall__c storedCall = newStoredRetryCall(true, LARGE_RETRY_BUDGET, RETRIES_WITH_ONE_LEFT);

		Test.startTest();
		Datetime sentFrom = Datetime.now();
		ApiCall__c dispatchedCall = API_Dispatcher.execute(storedCall).apiCall;
		Datetime sentUntil = Datetime.now();
		Test.stopTest();

		Assert.areEqual(SEL_ApiCall.STATUS_RETRY, dispatchedCall.Status__c, 'Expected the call to be scheduled (Retry), got ' + dispatchedCall.Status__c);
		Assert.areEqual(RETRIES_AFTER_SECOND_RUN, dispatchedCall.Retries__c.intValue(), 'Expected a count of ' + RETRIES_AFTER_SECOND_RUN + ', got ' + dispatchedCall.Retries__c);
		assertWaitedSeconds(dispatchedCall, sentFrom, sentUntil, MAXIMUM_WAIT_SECONDS);
		assertOneSavedRowRetrying(dispatchedCall);
	}

	/**
	 * @description The open circuit still stretches the wait of a request built with withExponentialBackoff: the circuit
	 * refuses the call, and its scheduled retry waits the circuit's 60-second time-out, not the 30 seconds of the first
	 * exponential wait. The open state is kept in the org cache, so the test needs space set aside there.
	 */
	@IsTest
	private static void shouldStretchTheExponentialWaitToTheCircuitTimeoutWhenTheCircuitIsOpen()
	{
		if(!UTIL_Cache.isOrgAllocated())
		{
			return;
		}

		registerMock(HANDLER_SERVICE, API_Base.HTTP_OK);
		UTIL_CircuitBreaker.monitor(TEST_CREDENTIAL).forceOpen();
		UTIL_HttpClient.RequestBuilder builder = UTIL_HttpClient.get(TEST_CREDENTIAL, TEST_PATH)
				.withExponentialBackoff(RETRY_BUDGET_BEYOND_SYNCHRONOUS, BASE_BACKOFF_SECONDS)
				.withCircuitBreaker();

		Test.startTest();
		Datetime sentFrom = Datetime.now();
		builder.send();
		Datetime sentUntil = Datetime.now();
		Test.stopTest();

		ApiCall__c storedCall = builder.handlerInstance.apiCall;
		String circuitOpenLine = String.format(System.Label.OutboundCall_CircuitOpen, new List<Object> {HANDLER_SERVICE});
		Assert.isTrue(storedCall.ErrorMessages__c?.contains(circuitOpenLine) == true, 'Expected the open circuit to refuse the call, got ' + storedCall.ErrorMessages__c);
		Assert.areEqual(SEL_ApiCall.STATUS_RETRY, storedCall.Status__c, 'Expected the refused call to be scheduled (Retry), got ' + storedCall.Status__c);
		assertWaitedSeconds(storedCall, sentFrom, sentUntil, DEFAULT_CIRCUIT_TIMEOUT_SECONDS);
	}

	/**
	 * @description A handler with no retry strategy of its own, called through useHandler with
	 * withExponentialBackoff(3, 30), uses the caller's values on every run, not the base of 45 seconds and the maximum of
	 * 5 in its own service setting. The first run waits 30 seconds. When the dispatcher runs the saved call again, its
	 * retry waits 60 seconds (the base of 30 seconds doubled once), not 90 seconds (45 doubled once). Both runs save the
	 * caller's maximum of 3 on the call.
	 */
	@IsTest
	private static void shouldUseTheCallersExponentialWaitsOnEveryRunOfAHandlerCalledThroughUseHandler()
	{
		assertWaitsOfTwoRuns(UTIL_HttpClient.useHandler(TestTimedHandler.class)
				.withExponentialBackoff(CALLER_RETRY_BUDGET, BASE_BACKOFF_SECONDS), TestTimedHandler.class.getName(), EXPONENTIAL_WAITS, CALLER_RETRY_BUDGET);
	}

	/**
	 * @description A handler called through useHandler with withExponentialBackoff(3, 30) stops after 3 retries in
	 * total, the caller's maximum, not after the 5 of its own service setting. A saved call that has already used its 3
	 * retries ends Failed when the dispatcher runs it again.
	 */
	@IsTest
	private static void shouldStopAHandlerCallMadeWithExponentialBackoffAtTheCallersMaximum()
	{
		assertStopsAtTheCallersMaximum(UTIL_HttpClient.useHandler(TestTimedHandler.class).withExponentialBackoff(CALLER_RETRY_BUDGET, BASE_BACKOFF_SECONDS));
	}

	/**
	 * @description A handler with no retry strategy of its own, called through useHandler with withRetry(3, 30), uses the
	 * caller's values on every run: the default waits of 30 seconds on the first run and on the second, not the 45
	 * seconds of its own service setting. Both runs save the caller's maximum of 3 on the call.
	 */
	@IsTest
	private static void shouldUseTheCallersDefaultWaitsOnEveryRunOfAHandlerCalledThroughUseHandler()
	{
		assertWaitsOfTwoRuns(UTIL_HttpClient.useHandler(TestTimedHandler.class)
				.withRetry(CALLER_RETRY_BUDGET, BASE_BACKOFF_SECONDS), TestTimedHandler.class.getName(), LINEAR_WAITS, CALLER_RETRY_BUDGET);
	}

	/**
	 * @description A handler called through useHandler with withRetry(3, 30) stops after 3 retries in total, the caller's
	 * maximum, not after the 5 of its own service setting.
	 */
	@IsTest
	private static void shouldStopAHandlerCallMadeWithRetryAtTheCallersMaximum()
	{
		assertStopsAtTheCallersMaximum(UTIL_HttpClient.useHandler(TestTimedHandler.class).withRetry(CALLER_RETRY_BUDGET, BASE_BACKOFF_SECONDS));
	}

	/**
	 * @description A handler that has no service setting, called through useHandler with withRetry(2, 30), schedules its
	 * first retry with the caller's values: a wait of 30 seconds and a maximum of 2, both kept on the saved call. When the
	 * dispatcher runs the saved call again, the framework finds no service setting and ends it Aborted with no next retry
	 * time, before any retry decision. This is the documented limit of useHandler without an API Setting record.
	 */
	@IsTest
	private static void shouldAbortTheScheduledRetryOfAHandlerWithNoServiceSetting()
	{
		String serviceName = TestNoSettingHandler.class.getName();
		ApiCall__c firstRunCall = runFirstRunThroughUseHandler(UTIL_HttpClient.useHandler(TestNoSettingHandler.class)
				.withRetry(CALLER_RETRY_BUDGET_WITHOUT_SETTING, BASE_BACKOFF_SECONDS), serviceName, BASE_BACKOFF_SECONDS);

		Assert.areEqual(CALLER_RETRY_BUDGET_WITHOUT_SETTING, firstRunCall.MaxRetries__c.intValue(), 'Expected a maximum of 2, got ' + firstRunCall.MaxRetries__c);
		DTO_NameValues savedInputs = (DTO_NameValues)new DTO_NameValues().deserialize(firstRunCall.RequestParameters__c);
		Assert.areEqual(String.valueOf(CALLER_RETRY_BUDGET_WITHOUT_SETTING), savedInputs.get(UTIL_HttpClient.KEY_MAX_RETRIES),
				'Expected the saved call to keep the maximum of 2, got ' + firstRunCall.RequestParameters__c);
		Assert.areEqual(String.valueOf(BASE_BACKOFF_SECONDS), savedInputs.get(UTIL_HttpClient.KEY_BACKOFF_SECONDS),
				'Expected the saved call to keep the base wait of 30 seconds, got ' + firstRunCall.RequestParameters__c);

		Test.startTest();
		ApiCall__c dispatchedCall = API_Dispatcher.execute(firstRunCall).apiCall;
		Test.stopTest();

		Assert.areEqual(SEL_ApiCall.STATUS_ABORTED, dispatchedCall.Status__c, 'Expected the second run to end Aborted, got ' + dispatchedCall.Status__c);
		Assert.isNull(dispatchedCall.NextRetry__c, 'Expected no next retry time on the aborted call, got ' + dispatchedCall.NextRetry__c);
		List<ApiCall__c> abortedCalls = SEL_ApiCall.assertServiceAborted(serviceName,
				String.format(System.Label.OutboundCall_ApiSettingNotFound, new List<String> {serviceName}));
		Assert.areEqual(1, abortedCalls.size(), 'Expected one saved row at Aborted after the second run, got ' + abortedCalls.size());
	}

	/**
	 * @description A handler called through useHandler by a caller that sets no retry values keeps the values of its own
	 * service setting on every run: a wait of 45 seconds on the first run and on the second, and a maximum of 5.
	 */
	@IsTest
	private static void shouldKeepTheHandlersSettingWhenTheCallerSetsNoRetryValues()
	{
		assertWaitsOfTwoRuns(UTIL_HttpClient.useHandler(TestTimedHandler.class), TestTimedHandler.class.getName(), HANDLER_SETTING_WAITS,
				HANDLER_SETTING_RETRY_BUDGET);
	}

	/**
	 * @description A handler that overrides createRetryStrategy decides its own wait, even when the caller asks for
	 * withExponentialBackoff: it waits its own 75 seconds, not the 30 seconds the caller asked for, nor the 45 seconds of
	 * its service setting.
	 */
	@IsTest
	private static void shouldLetAHandlerWithItsOwnRetryStrategyDecideTheWait()
	{
		String serviceName = TestOwnStrategyHandler.class.getName();
		registerMock(serviceName, API_Base.HTTP_TOO_MANY_REQUESTS);

		Test.startTest();
		Datetime sentFrom = Datetime.now();
		UTIL_HttpClient.useHandler(TestOwnStrategyHandler.class)
				.withExponentialBackoff(RETRY_BUDGET_BEYOND_SYNCHRONOUS, BASE_BACKOFF_SECONDS)
				.invoke();
		Datetime sentUntil = Datetime.now();
		Test.stopTest();

		List<ApiCall__c> savedCalls = SEL_ApiCall.assertServiceRetrying(serviceName);
		Assert.areEqual(1, savedCalls.size(), 'Expected one saved row at Retry with a time, got ' + savedCalls.size());
		assertWaitedSeconds(savedCalls[0], sentFrom, sentUntil, OWN_STRATEGY_BACKOFF_SECONDS);
	}

	/**
	 * @description Registers a mock answer with the given status for a service.
	 *
	 * @param serviceName The service the mock answers for.
	 * @param statusCode The HTTP status code of the answer.
	 */
	private static void registerMock(String serviceName, Integer statusCode)
	{
		API_MockFactory.forService(serviceName).body(MOCK_BODY).statusCode(statusCode).register();
	}

	/**
	 * @description Sends a request built with a retry budget of 5 and a base wait of 30 seconds, answered with a 500, and
	 * checks the wait of the retry scheduled after the three re-sends, and the count saved on the row.
	 *
	 * @param builder The request, built with withRetry or withExponentialBackoff.
	 * @param expectedSeconds The expected wait, in seconds.
	 */
	private static void assertFirstRunWait(UTIL_HttpClient.RequestBuilder builder, Integer expectedSeconds)
	{
		registerMock(HANDLER_SERVICE, API_Base.HTTP_INTERNAL_SERVER_ERROR);

		Test.startTest();
		Datetime sentFrom = Datetime.now();
		builder.send();
		Datetime sentUntil = Datetime.now();
		Test.stopTest();

		ApiCall__c storedCall = builder.handlerInstance.apiCall;
		Assert.areEqual(SEL_ApiCall.STATUS_RETRY, storedCall.Status__c, 'Expected the leftover budget to be scheduled (Retry), got ' + storedCall.Status__c);
		Assert.areEqual(RETRIES_AFTER_FIRST_RUN, storedCall.Retries__c.intValue(), 'Expected a count of ' + RETRIES_AFTER_FIRST_RUN + ', got ' + storedCall.Retries__c);
		assertWaitedSeconds(storedCall, sentFrom, sentUntil, expectedSeconds);
		assertOneSavedRowRetrying(storedCall);
	}

	/**
	 * @description Runs a stored GET call answered with a 500 and checks that it ends Failed, with no next retry time and
	 * the whole budget counted, on the call and on its saved row.
	 *
	 * @param retriesAlreadyCounted The retry count the call is stored with.
	 * @param retryBudget The call's maximum number of retries.
	 */
	private static void assertStoredCallEndsFailed(Integer retriesAlreadyCounted, Integer retryBudget)
	{
		registerMock(HANDLER_SERVICE, API_Base.HTTP_INTERNAL_SERVER_ERROR);
		ApiCall__c storedCall = newStoredRetryCall(true, retryBudget, retriesAlreadyCounted);

		Test.startTest();
		ApiCall__c dispatchedCall = API_Dispatcher.execute(storedCall).apiCall;
		Test.stopTest();

		Assert.areEqual(SEL_ApiCall.STATUS_FAILED, dispatchedCall.Status__c, 'Expected the call to end Failed, got ' + dispatchedCall.Status__c);
		Assert.isNull(dispatchedCall.NextRetry__c, 'Expected no next retry time, got ' + dispatchedCall.NextRetry__c);
		Assert.areEqual(retryBudget, dispatchedCall.Retries__c.intValue(), 'Expected the whole budget of ' + retryBudget + ' counted, got ' + dispatchedCall.Retries__c);
		List<ApiCall__c> savedCalls = SEL_ApiCall.assertServiceFailed(dispatchedCall.ServiceName__c);
		Assert.areEqual(1, savedCalls.size(), 'Expected one saved Failed row, got ' + savedCalls.size());
		Assert.isNull(savedCalls[0].NextRetry__c, 'Expected no next retry time on the saved row, got ' + savedCalls[0].NextRetry__c);
		Assert.areEqual(retryBudget, savedCalls[0].Retries__c.intValue(), 'Expected the saved count ' + retryBudget + ', got ' + savedCalls[0].Retries__c);
	}

	/**
	 * @description Sends three stored calls with the retry numbers 0, 1 and 2 through the dispatcher, each answered with a
	 * 429, and checks that each scheduled retry waits the expected number of seconds, on the call and on its saved row.
	 *
	 * @param isExponential Whether the stored calls carry the input withExponentialBackoff writes.
	 * @param expectedWaits The expected wait, in seconds, for the retries numbered 0, 1 and 2.
	 */
	private static void assertStoredCallWaits(Boolean isExponential, List<Integer> expectedWaits)
	{
		registerMock(HANDLER_SERVICE, API_Base.HTTP_TOO_MANY_REQUESTS);
		List<ApiCall__c> storedCalls = new List<ApiCall__c>();
		for(Integer retryNumber = 0; retryNumber < expectedWaits.size(); retryNumber++)
		{
			storedCalls.add(newStoredRetryCall(isExponential, STORED_CALL_RETRY_BUDGET, retryNumber));
		}

		Test.startTest();
		Datetime sentFrom = Datetime.now();
		List<API_Base> handlers = API_Dispatcher.execute(storedCalls);
		Datetime sentUntil = Datetime.now();
		Test.stopTest();

		Assert.areEqual(expectedWaits.size(), handlers.size(), 'Expected one handler per stored call, got ' + handlers.size());
		Map<Id, ApiCall__c> savedCallsById = new Map<Id, ApiCall__c>(SEL_ApiCall.assertServiceRetrying(handlers[0].apiCall.ServiceName__c));
		Assert.areEqual(expectedWaits.size(), savedCallsById.size(), 'Expected one saved row at Retry per stored call, got ' + savedCallsById.size());
		for(Integer retryNumber = 0; retryNumber < expectedWaits.size(); retryNumber++)
		{
			ApiCall__c dispatchedCall = handlers[retryNumber].apiCall;
			Assert.areEqual(SEL_ApiCall.STATUS_RETRY, dispatchedCall.Status__c,
					'Expected the retry numbered ' + retryNumber + ' to be scheduled (Retry), got ' + dispatchedCall.Status__c);
			assertWaitedSeconds(dispatchedCall, sentFrom, sentUntil, expectedWaits[retryNumber]);
			ApiCall__c savedCall = savedCallsById.get(dispatchedCall.Id);
			Assert.isNotNull(savedCall, 'Expected the retry numbered ' + retryNumber + ' to be saved at Retry, got no row');
			Assert.areEqual(retryNumber + 1, savedCall.Retries__c.intValue(), 'Expected the saved count ' + (retryNumber + 1) + ', got ' + savedCall.Retries__c);
			assertWaitedSeconds(savedCall, sentFrom, sentUntil, expectedWaits[retryNumber]);
		}
	}

	/**
	 * @description Runs a request built through useHandler, answered with a 429, and then runs its saved call again
	 * through the dispatcher, as a scheduled retry does. It checks the wait of each run. The first run happens before
	 * Test.startTest, because a test may not make a callout after saving a record in the same part of the test.
	 *
	 * @param builder The request, built through useHandler.
	 * @param serviceName The class name of the handler.
	 * @param expectedWaits The expected wait, in seconds, of the first run and of the second.
	 * @param expectedMaximum The maximum number of retries each run must save on the call.
	 */
	private static void assertWaitsOfTwoRuns(UTIL_HttpClient.RequestBuilder builder, String serviceName, List<Integer> expectedWaits, Integer expectedMaximum)
	{
		ApiCall__c firstRunCall = runFirstRunThroughUseHandler(builder, serviceName, expectedWaits[0]);
		Assert.areEqual(expectedMaximum, firstRunCall.MaxRetries__c.intValue(), 'Expected a first-run maximum of ' + expectedMaximum + ', got ' + firstRunCall.MaxRetries__c);

		Test.startTest();
		Datetime secondSentFrom = Datetime.now();
		ApiCall__c dispatchedCall = API_Dispatcher.execute(firstRunCall).apiCall;
		Datetime secondSentUntil = Datetime.now();
		Test.stopTest();

		Assert.areEqual(SEL_ApiCall.STATUS_RETRY, dispatchedCall.Status__c, 'Expected the second run to be scheduled (Retry), got ' + dispatchedCall.Status__c);
		Assert.areEqual(2, dispatchedCall.Retries__c.intValue(), 'Expected a count of 2 after two scheduled retries, got ' + dispatchedCall.Retries__c);
		assertWaitedSeconds(dispatchedCall, secondSentFrom, secondSentUntil, expectedWaits[1]);
		List<ApiCall__c> savedCalls = SEL_ApiCall.assertServiceRetrying(serviceName);
		Assert.areEqual(1, savedCalls.size(), 'Expected one saved row at Retry after the second run, got ' + savedCalls.size());
		Assert.areEqual(expectedMaximum, savedCalls[0].MaxRetries__c.intValue(), 'Expected a second-run maximum of ' + expectedMaximum + ', got ' + savedCalls[0].MaxRetries__c);
	}

	/**
	 * @description Runs a request built through useHandler for the test handler, answered with a 429. It then marks the
	 * saved call as having used the caller's 3 retries, as three earlier runs would, and runs it again through the
	 * dispatcher. The call must end Failed with no next retry time: the caller's maximum of 3 applies, not the 5 of the
	 * handler's service setting.
	 *
	 * @param builder The request, built through useHandler with a maximum of 3 retries.
	 */
	private static void assertStopsAtTheCallersMaximum(UTIL_HttpClient.RequestBuilder builder)
	{
		String serviceName = TestTimedHandler.class.getName();
		ApiCall__c firstRunCall = runFirstRunThroughUseHandler(builder, serviceName, BASE_BACKOFF_SECONDS);
		firstRunCall.Retries__c = CALLER_RETRY_BUDGET;

		Test.startTest();
		ApiCall__c dispatchedCall = API_Dispatcher.execute(firstRunCall).apiCall;
		Test.stopTest();

		Assert.areEqual(SEL_ApiCall.STATUS_FAILED, dispatchedCall.Status__c, 'Expected the call to end Failed at the maximum of 3, got ' + dispatchedCall.Status__c);
		Assert.isNull(dispatchedCall.NextRetry__c, 'Expected no next retry time, got ' + dispatchedCall.NextRetry__c);
		List<ApiCall__c> savedCalls = SEL_ApiCall.assertServiceFailed(serviceName);
		Assert.areEqual(1, savedCalls.size(), 'Expected one saved Failed row, got ' + savedCalls.size());
		Assert.areEqual(CALLER_RETRY_BUDGET, savedCalls[0].MaxRetries__c.intValue(), 'Expected the saved maximum of 3, got ' + savedCalls[0].MaxRetries__c);
	}

	/**
	 * @description Runs a request built through useHandler, answered with a 429, before Test.startTest, and checks that
	 * one call is saved at Retry with the expected wait.
	 *
	 * @param builder The request, built through useHandler.
	 * @param serviceName The class name of the handler.
	 * @param expectedSeconds The expected wait, in seconds, of the first run.
	 *
	 * @return The saved call, as read back from the database.
	 */
	private static ApiCall__c runFirstRunThroughUseHandler(UTIL_HttpClient.RequestBuilder builder, String serviceName, Integer expectedSeconds)
	{
		registerMock(serviceName, API_Base.HTTP_TOO_MANY_REQUESTS);

		Datetime sentFrom = Datetime.now();
		builder.invoke();
		Datetime sentUntil = Datetime.now();
		List<ApiCall__c> savedCalls = SEL_ApiCall.assertServiceRetrying(serviceName);
		Assert.areEqual(1, savedCalls.size(), 'Expected one saved row at Retry after the first run, got ' + savedCalls.size());
		assertWaitedSeconds(savedCalls[0], sentFrom, sentUntil, expectedSeconds);
		return savedCalls[0];
	}

	/**
	 * @description Builds a stored GET call for the client's own handler, as a request built with withRetry or
	 * withExponentialBackoff with a base wait of 30 seconds stores it, with the retry count it has reached.
	 *
	 * @param isExponential Whether the call carries the input withExponentialBackoff writes.
	 * @param retryBudget The call's maximum number of retries.
	 * @param retriesAlreadyCounted The number of retries the call has already used.
	 *
	 * @return The stored call, not saved.
	 */
	private static ApiCall__c newStoredRetryCall(Boolean isExponential, Integer retryBudget, Integer retriesAlreadyCounted)
	{
		DTO_NameValues storedInputs = new DTO_NameValues();
		storedInputs.add(UTIL_HttpClient.KEY_CREDENTIAL, TEST_CREDENTIAL);
		storedInputs.add(UTIL_HttpClient.KEY_PATH, TEST_PATH);
		storedInputs.add(UTIL_HttpClient.KEY_HTTP_METHOD, API_Base.toHttpString(API_Base.HttpMethod.GET));
		storedInputs.add(UTIL_HttpClient.KEY_MAX_RETRIES, String.valueOf(retryBudget));
		storedInputs.add(UTIL_HttpClient.KEY_BACKOFF_SECONDS, String.valueOf(BASE_BACKOFF_SECONDS));
		if(isExponential)
		{
			storedInputs.add(API_Outbound.INPUT_EXPONENTIAL_BACKOFF, String.valueOf(true));
		}
		ApiCall__c storedCall = TST_Factory.newOutboundApiCall(UTIL_HttpClient.DefaultOutboundHandler.class.getName(), UserInfo.getUserId());
		storedCall.RequestParameters__c = storedInputs.serialize();
		storedCall.Retries__c = retriesAlreadyCounted;
		return storedCall;
	}

	/**
	 * @description Asserts that the call's next retry time is the expected number of seconds after the moment it was
	 * sent. The send happened somewhere between two times, so the next retry time must fall between those two times plus
	 * the wait. The lower end allows one second less, because a saved time keeps whole seconds only.
	 *
	 * @param storedCall The call that was sent.
	 * @param sentFrom The time just before the send.
	 * @param sentUntil The time just after the send.
	 * @param expectedSeconds The expected wait, in seconds.
	 */
	private static void assertWaitedSeconds(ApiCall__c storedCall, Datetime sentFrom, Datetime sentUntil, Integer expectedSeconds)
	{
		Assert.isNotNull(storedCall.NextRetry__c, 'Expected a scheduled retry to carry a time, got null');
		Long nextRetryTime = storedCall.NextRetry__c.getTime();
		Long earliest = sentFrom.getTime() + expectedSeconds * MILLISECONDS_PER_SECOND - SAVED_TIME_TOLERANCE_MILLISECONDS;
		Long latest = sentUntil.getTime() + expectedSeconds * MILLISECONDS_PER_SECOND;
		Assert.isTrue(nextRetryTime >= earliest && nextRetryTime <= latest,
				'Expected a wait of ' + expectedSeconds + ' seconds, got a next retry of ' + storedCall.NextRetry__c + ' for a send between ' + sentFrom + ' and ' + sentUntil);
	}

	/**
	 * @description Asserts that the call was saved, not only held in memory: one saved row for the service, at Retry with
	 * a time, with the count the handler's copy holds.
	 *
	 * @param storedCall The call that was sent, read from its handler.
	 */
	private static void assertOneSavedRowRetrying(ApiCall__c storedCall)
	{
		List<ApiCall__c> savedCalls = SEL_ApiCall.assertServiceRetrying(storedCall.ServiceName__c);
		Assert.areEqual(1, savedCalls.size(), 'Expected one saved row at Retry with a time, got ' + savedCalls.size());
		Assert.areEqual(storedCall.Retries__c, savedCalls[0].Retries__c, 'Expected the saved count ' + storedCall.Retries__c + ', got ' + savedCalls[0].Retries__c);
	}

	/**
	 * @description A handler with no retry strategy and no service setting of its own, as a handler in your org might
	 * be. It needs no triggering record and answers from a mock.
	 */
	public virtual class TestNoSettingHandler extends API_Outbound
	{
		/**
		 * @description Sets the mock answer.
		 */
		public virtual override void configure()
		{
			super.configure();
			requiresTriggeringRecord = false;
			defaultMockBody = MOCK_BODY;
		}
	}

	/**
	 * @description A handler with no retry strategy of its own that carries a service setting with a maximum of 5
	 * retries and a base wait of 45 seconds, so the dispatcher can run its saved call again. Both values differ from the
	 * ones the tests ask for as the caller.
	 */
	public virtual class TestTimedHandler extends TestNoSettingHandler
	{
		/**
		 * @description Sets the mock answer and the service setting.
		 */
		public override void configure()
		{
			super.configure();

			ApiSetting__mdt handlerSetting = (ApiSetting__mdt)TST_Builder.of(ApiSetting__mdt.SObjectType)
					.withOverride(ApiSetting__mdt.IsActive__c, true)
					.withOverride(ApiSetting__mdt.ClassName__c, getServiceName())
					.withOverride(ApiSetting__mdt.DeveloperName, getServiceName())
					.withOverride(ApiSetting__mdt.MaxRetryCount__c, HANDLER_SETTING_RETRY_BUDGET)
					.withOverride(ApiSetting__mdt.RetryBackoffSeconds__c, HANDLER_SETTING_BACKOFF_SECONDS)
					.withoutInsertion()
					.build();
			applySettings(handlerSetting);
		}
	}

	/**
	 * @description A handler that chooses its own retry strategy: the default backoff with a base wait of 75 seconds.
	 */
	public class TestOwnStrategyHandler extends TestTimedHandler
	{
		/**
		 * @description Returns this handler's own strategy, whatever the caller asked for.
		 *
		 * @return The default backoff with a base wait of 75 seconds and a budget of 5 retries.
		 */
		public override UTIL_Retry.Strategy createRetryStrategy()
		{
			return UTIL_Retry.linear().withBaseBackoff(OWN_STRATEGY_BACKOFF_SECONDS).withMaxRetries(RETRY_BUDGET_BEYOND_SYNCHRONOUS);
		}
	}
}
