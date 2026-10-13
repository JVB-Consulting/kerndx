// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Test class for UTIL_CircuitBreaker to verify circuit breaker pattern
 * implementation including state transitions, failure thresholds, and recovery logic.
 *
 * @see UTIL_CircuitBreaker
 *
 * @author Jason van Beukering
 *
 * @group Resilience
 *
 * @date December 2025, October 2026
 */
@IsTest(seeAllData=false isParallel=true)
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
private class UTIL_CircuitBreaker_TEST
{
	/**
	 * @description The name of the circuit the tests of this class watch.
	 */
	private static final String SERVICE_NAME = 'TestAPIService';

	/**
	 * @description A timeout of zero seconds. In a test the breaker treats a zero timeout as passed once the clock has
	 * moved on by one millisecond, so a test can let the timeout pass without waiting.
	 */
	private static final Integer IMMEDIATE_TIMEOUT_SECONDS = 0;

	/**
	 * @description A timeout no test waits out, in seconds, so a breaker that carries it never sees its timeout pass.
	 */
	private static final Integer LONG_TIMEOUT_SECONDS = 60;

	/**
	 * @description How many trial requests the half-open tests let through in one round.
	 */
	private static final Integer TRIAL_REQUESTS = 2;

	/**
	 * @description How many successful trial requests close the circuit in the test that spreads them over two rounds.
	 */
	private static final Integer SUCCESSES_TO_CLOSE = 2;

	/**
	 * @description The length of the random circuit name the cache-loading test uses, so no other test shares its state.
	 */
	private static final Integer CACHED_CIRCUIT_NAME_LENGTH = 16;

	/**
	 * @description The failure threshold of the circuit in the cache-loading test: above the failures it records, so the
	 * circuit stays closed and the test reads the failure count alone.
	 */
	private static final Integer CACHED_CIRCUIT_FAILURE_THRESHOLD = 3;

	/**
	 * @description The failures the cache-loading test records through its first breaker and expects the second to load.
	 */
	private static final Integer CACHED_CIRCUIT_FAILURES = 2;

	/**
	 * @description The name of the field of the cached circuit state that holds when the current round of trial requests
	 * began.
	 */
	private static final String FIELD_STATE_CHANGED_TIME = 'stateChangedTime';

	/**
	 * @description How long a test keeps the state it writes to the org cache, in seconds: the shortest time the platform
	 * accepts.
	 */
	private static final Integer CACHE_SECONDS = 300;

	/**
	 * @description The name of the breaker method that starts a new round of trial requests, as its log line carries it.
	 */
	private static final String METHOD_START_NEW_ROUND = 'startNewRoundOfTrials';

	/**
	 * @description Tests circuit starts in CLOSED state and allows requests
	 */
	@IsTest
	private static void shouldStartInClosedState()
	{
		UTIL_CircuitBreaker.Breaker breaker = UTIL_CircuitBreaker.monitor(SERVICE_NAME);

		UTIL_CircuitBreaker.State state = breaker.getState();
		Boolean allowed = breaker.allowRequest();

		Assert.areEqual(UTIL_CircuitBreaker.State.CLOSED, state, 'Circuit should start in CLOSED state');
		Assert.isTrue(allowed, 'Requests should be allowed in CLOSED state');
	}

	/**
	 * @description Tests circuit opens after failure threshold exceeded
	 */
	@IsTest
	private static void shouldOpenCircuitAfterFailureThreshold()
	{
		UTIL_CircuitBreaker.Breaker breaker = UTIL_CircuitBreaker.monitor(SERVICE_NAME)
				.withFailureThreshold(3);

		// When - Record failures up to threshold
		breaker.recordFailure(); // 1
		Assert.areEqual(UTIL_CircuitBreaker.State.CLOSED, breaker.getState(), 'Should stay CLOSED after 1 failure');

		breaker.recordFailure(); // 2
		Assert.areEqual(UTIL_CircuitBreaker.State.CLOSED, breaker.getState(), 'Should stay CLOSED after 2 failures');

		breaker.recordFailure(); // 3 - hits threshold
		UTIL_CircuitBreaker.State state = breaker.getState();
		Boolean allowed = breaker.allowRequest();

		Assert.areEqual(UTIL_CircuitBreaker.State.OPEN, state, 'Circuit should be OPEN after hitting failure threshold');
		Assert.isFalse(allowed, 'Requests should not be allowed in OPEN state');
	}

	/**
	 * @description Tests success in CLOSED state resets failure count
	 */
	@IsTest
	private static void shouldResetFailureCountOnSuccessInClosedState()
	{
		UTIL_CircuitBreaker.Breaker breaker = UTIL_CircuitBreaker.monitor(SERVICE_NAME)
				.withFailureThreshold(3);

		// When - Record failures and then success
		breaker.recordFailure();
		breaker.recordFailure();

		UTIL_CircuitBreaker.Metrics metricsBeforeSuccess = breaker.getMetrics();
		Assert.areEqual(2, metricsBeforeSuccess.failureCount, 'Should have 2 failures');

		breaker.recordSuccess();
		UTIL_CircuitBreaker.Metrics metricsAfterSuccess = breaker.getMetrics();

		Assert.areEqual(0, metricsAfterSuccess.failureCount, 'Failure count should reset to 0 after success');
		Assert.areEqual(UTIL_CircuitBreaker.State.CLOSED, breaker.getState(), 'Should remain CLOSED');
	}

	/**
	 * @description Tests circuit transitions from OPEN to HALF_OPEN after timeout
	 */
	@IsTest
	private static void shouldTransitionToHalfOpenAfterTimeout()
	{
		UTIL_CircuitBreaker.Breaker breaker = UTIL_CircuitBreaker.monitor(SERVICE_NAME)
				.withFailureThreshold(2)
				.withTimeout(0); // Immediate timeout for testing

		// When - Open the circuit
		breaker.recordFailure();
		breaker.recordFailure();
		Assert.areEqual(UTIL_CircuitBreaker.State.OPEN, breaker.getState(), 'Circuit should be OPEN');

		// Wait for timeout (0 seconds in this test)
		Test.startTest();
		UTIL_CircuitBreaker.State state = breaker.getState();
		Test.stopTest();

		Assert.areEqual(UTIL_CircuitBreaker.State.HALF_OPEN, state, 'Circuit should transition to HALF_OPEN after timeout');
	}

	/**
	 * @description Tests limited requests allowed in HALF_OPEN state. The timeout is raised once the circuit is
	 * HALF_OPEN, because a zero timeout would start a new round of trial requests as soon as the two were used.
	 */
	@IsTest
	private static void shouldAllowLimitedRequestsInHalfOpenState()
	{
		UTIL_CircuitBreaker.Breaker breaker = UTIL_CircuitBreaker.monitor(SERVICE_NAME)
				.withFailureThreshold(1)
				.withTimeout(IMMEDIATE_TIMEOUT_SECONDS)
				.withHalfOpenMaxAttempts(TRIAL_REQUESTS);

		// When - Open circuit and transition to HALF_OPEN
		breaker.recordFailure();
		breaker.getState(); // Trigger transition to HALF_OPEN
		UTIL_CircuitBreaker.State stateBeforeTheTrials = breaker.getState();
		Assert.areEqual(UTIL_CircuitBreaker.State.HALF_OPEN, stateBeforeTheTrials, 'Expected HALF_OPEN once the zero timeout passed, got ' + stateBeforeTheTrials);
		breaker.withTimeout(LONG_TIMEOUT_SECONDS);

		// Then - Should allow limited requests
		Assert.isTrue(breaker.allowRequest(), 'First request should be allowed in HALF_OPEN');
		Assert.isTrue(breaker.allowRequest(), 'Second request should be allowed in HALF_OPEN');
		Assert.isFalse(breaker.allowRequest(), 'Third request should not be allowed - exceeded halfOpenMaxAttempts');
	}

	/**
	 * @description Tests circuit closes after successful requests in HALF_OPEN state
	 */
	@IsTest
	private static void shouldCloseCircuitAfterSuccessesInHalfOpen()
	{
		UTIL_CircuitBreaker.Breaker breaker = UTIL_CircuitBreaker.monitor(SERVICE_NAME)
				.withFailureThreshold(1)
				.withTimeout(0)
				.withSuccessThreshold(2);

		// When - Open circuit and transition to HALF_OPEN
		breaker.recordFailure();
		breaker.getState(); // Trigger transition to HALF_OPEN
		Assert.areEqual(UTIL_CircuitBreaker.State.HALF_OPEN, breaker.getState(), 'Should be HALF_OPEN');

		// Record successes
		breaker.recordSuccess();
		Assert.areEqual(UTIL_CircuitBreaker.State.HALF_OPEN, breaker.getState(), 'Should stay HALF_OPEN after 1 success');

		breaker.recordSuccess();
		UTIL_CircuitBreaker.State state = breaker.getState();

		Assert.areEqual(UTIL_CircuitBreaker.State.CLOSED, state, 'Circuit should close after reaching success threshold');
		Assert.isTrue(breaker.allowRequest(), 'Should allow requests in CLOSED state');
	}

	/**
	 * @description Tests circuit reopens on failure in HALF_OPEN state
	 */
	@IsTest
	private static void shouldReopenCircuitOnFailureInHalfOpen()
	{
		UTIL_CircuitBreaker.Breaker breaker = UTIL_CircuitBreaker.monitor(SERVICE_NAME)
				.withFailureThreshold(1)
				.withTimeout(0);

		// When - Open circuit and transition to HALF_OPEN
		breaker.recordFailure();
		breaker.getState(); // Trigger transition to HALF_OPEN
		Assert.areEqual(UTIL_CircuitBreaker.State.HALF_OPEN, breaker.getState(), 'Should be HALF_OPEN');

		//Increase timeout so it doesn't immediately bounce back to HALF_OPEN after the next failure.
		breaker.withTimeout(60);

		// Record failure in HALF_OPEN
		breaker.recordFailure();
		UTIL_CircuitBreaker.State state = breaker.getState();

		Assert.areEqual(UTIL_CircuitBreaker.State.OPEN, state, 'Circuit should reopen on failure in HALF_OPEN');
		Assert.isFalse(breaker.allowRequest(), 'Should not allow requests in OPEN state');
	}

	/**
	 * @description A trial request that ends with no result recorded must not leave the circuit refusing every request.
	 * Every trial request of the round is let through and none records a success or a failure. Once the timeout has
	 * passed since the round began, the next request is allowed, the circuit is still HALF_OPEN and the metrics show the
	 * later time at which the new round began.
	 */
	@IsTest
	private static void shouldStartANewRoundOfTrialsWhenEveryTrialEndedWithoutAResult()
	{
		UTIL_CircuitBreaker.Breaker breaker = newHalfOpenBreaker();
		Long firstRoundStartedAt = breaker.getMetrics().stateChangedTime.getTime();
		assertTrialRequestsAreAllowed(breaker, TRIAL_REQUESTS);
		waitForTheClockToMove();

		Boolean isAllowed = breaker.allowRequest();
		UTIL_CircuitBreaker.Metrics metrics = breaker.getMetrics();

		Assert.isTrue(isAllowed, 'Expected a request to be allowed once the timeout passed since the trial requests began, got a refusal');
		Assert.areEqual(UTIL_CircuitBreaker.State.HALF_OPEN, metrics.state, 'Expected the circuit to stay HALF_OPEN in the new round, got ' + metrics.state);
		Long newRoundStartedAt = metrics.stateChangedTime.getTime();
		Assert.isTrue(newRoundStartedAt > firstRoundStartedAt, 'Expected the new round to begin after ' + firstRoundStartedAt + ', got ' + newRoundStartedAt);
	}

	/**
	 * @description A new round of trial requests waits for the timeout. With every trial request used and a timeout that
	 * has not passed since the round began, the next request is still refused, the circuit stays HALF_OPEN and the round
	 * keeps its start time.
	 */
	@IsTest
	private static void shouldKeepRefusingUntilTheTimeoutHasPassedSinceTheTrialsBegan()
	{
		UTIL_CircuitBreaker.Breaker breaker = newHalfOpenBreaker().withTimeout(LONG_TIMEOUT_SECONDS);
		Datetime roundStartedAt = breaker.getMetrics().stateChangedTime;
		assertTrialRequestsAreAllowed(breaker, TRIAL_REQUESTS);
		waitForTheClockToMove();

		Boolean isAllowed = breaker.allowRequest();
		UTIL_CircuitBreaker.Metrics metrics = breaker.getMetrics();

		Assert.isFalse(isAllowed, 'Expected a refusal while the timeout has not passed since the trial requests began, got an allowed request');
		Assert.areEqual(UTIL_CircuitBreaker.State.HALF_OPEN, metrics.state, 'Expected the circuit to stay HALF_OPEN while it refuses, got ' + metrics.state);
		Assert.areEqual(roundStartedAt, metrics.stateChangedTime, 'Expected the round to keep its start time ' + roundStartedAt + ', got ' + metrics.stateChangedTime);
	}

	/**
	 * @description A new round of trial requests keeps the successes already recorded. With two successes needed to close
	 * the circuit, one trial request succeeds and the others of the round end with no result. After the timeout a new
	 * round begins with that one success still counted, so one more success closes the circuit.
	 */
	@IsTest
	private static void shouldKeepRecordedSuccessesWhenANewRoundOfTrialsStarts()
	{
		UTIL_CircuitBreaker.Breaker breaker = newHalfOpenBreaker().withSuccessThreshold(SUCCESSES_TO_CLOSE);
		assertTrialRequestsAreAllowed(breaker, 1);
		breaker.recordSuccess();
		assertTrialRequestsAreAllowed(breaker, TRIAL_REQUESTS - 1);
		waitForTheClockToMove();

		Boolean isAllowed = breaker.allowRequest();
		Integer successesInTheNewRound = breaker.getMetrics().consecutiveSuccesses;
		breaker.recordSuccess();
		UTIL_CircuitBreaker.State stateAfterTheSecondSuccess = breaker.getState();

		Assert.isTrue(isAllowed, 'Expected a request to be allowed in the new round, got a refusal');
		Assert.areEqual(1, successesInTheNewRound, 'Expected the one recorded success to still count in the new round, got ' + successesInTheNewRound);
		Assert.areEqual(UTIL_CircuitBreaker.State.CLOSED, stateAfterTheSecondSuccess, 'Expected the second success to close the circuit, got ' + stateAfterTheSecondSuccess);
	}

	/**
	 * @description A failure recorded in a new round of trial requests reopens the circuit at once, as a failure in the
	 * first round does, and the reopened circuit refuses the next request.
	 */
	@IsTest
	private static void shouldReopenTheCircuitWhenATrialOfANewRoundFails()
	{
		UTIL_CircuitBreaker.Breaker breaker = newHalfOpenBreaker();
		assertTrialRequestsAreAllowed(breaker, TRIAL_REQUESTS);
		waitForTheClockToMove();
		Boolean isAllowed = breaker.allowRequest();
		breaker.withTimeout(LONG_TIMEOUT_SECONDS);

		breaker.recordFailure();
		UTIL_CircuitBreaker.State stateAfterTheFailure = breaker.getState();

		Assert.isTrue(isAllowed, 'Expected a request to be allowed in the new round, got a refusal');
		Assert.areEqual(UTIL_CircuitBreaker.State.OPEN, stateAfterTheFailure, 'Expected the failure to reopen the circuit, got ' + stateAfterTheFailure);
		Assert.isFalse(breaker.allowRequest(), 'Expected the reopened circuit to refuse the next request, got an allowed request');
	}

	/**
	 * @description A new round of trial requests is saved, so the next transaction sees it. One breaker starts the new
	 * round by reading its state, which uses no trial request. A second breaker for the same circuit, built afterwards
	 * with a timeout that has not passed, reads the state from the org cache and allows a request. Without the save the
	 * second breaker would read every trial request as used and refuse. In an org whose org cache has no space set aside,
	 * nothing is saved: the second breaker finds no state, starts CLOSED and allows the request.
	 */
	@IsTest
	private static void shouldSaveANewRoundOfTrialsForTheNextBreakerOfTheCircuit()
	{
		UTIL_CircuitBreaker.State expectedState = UTIL_Cache.isOrgAllocated() ? UTIL_CircuitBreaker.State.HALF_OPEN : UTIL_CircuitBreaker.State.CLOSED;
		UTIL_CircuitBreaker.Breaker firstBreaker = newHalfOpenBreaker();
		assertTrialRequestsAreAllowed(firstBreaker, TRIAL_REQUESTS);
		waitForTheClockToMove();
		firstBreaker.getState();

		UTIL_CircuitBreaker.Breaker secondBreaker = UTIL_CircuitBreaker.monitor(SERVICE_NAME).withTimeout(LONG_TIMEOUT_SECONDS).withHalfOpenMaxAttempts(TRIAL_REQUESTS);
		UTIL_CircuitBreaker.State stateReadFromTheCache = secondBreaker.getState();
		Boolean isAllowed = secondBreaker.allowRequest();

		Assert.areEqual(expectedState, stateReadFromTheCache, 'Expected the second breaker to read ' + expectedState + ', got ' + stateReadFromTheCache);
		Assert.isTrue(isAllowed, 'Expected the second breaker to allow a request, got a refusal');
	}

	/**
	 * @description A circuit state kept in the org cache with no start time for its round of trial requests still
	 * recovers. The test stores such a state with every trial request used, then asks a breaker whose timeout has not
	 * passed. The missing time reads as a timeout that has passed: the request is allowed, nothing throws and the new
	 * round gets a start time. In an org whose org cache has no space set aside, the breaker cannot save its state: the
	 * test checks that the org cache holds none and that a new breaker for the circuit starts CLOSED.
	 */
	@IsTest
	private static void shouldStartANewRoundOfTrialsWhenTheCachedStateHasNoStartTime()
	{
		Boolean hasOrgCacheSpace = UTIL_Cache.isOrgAllocated();
		assertTrialRequestsAreAllowed(newHalfOpenBreaker(), TRIAL_REQUESTS);
		UTIL_Cache.Store cache = UTIL_Cache.org().withPartition(UTIL_Cache.getPlatformCacheName());
		Object cachedState = cache.get(SERVICE_NAME);
		if(!hasOrgCacheSpace)
		{
			Assert.isNull(cachedState, 'Expected no circuit state in the org cache when it has no space, got ' + cachedState);
			UTIL_CircuitBreaker.State stateOfANewBreaker = UTIL_CircuitBreaker.monitor(SERVICE_NAME).getState();
			Assert.areEqual(UTIL_CircuitBreaker.State.CLOSED, stateOfANewBreaker, 'Expected a new breaker to start CLOSED with no saved state, got ' + stateOfANewBreaker);
			return;
		}
		Assert.isNotNull(cachedState, 'Expected the circuit state in the org cache, got none');
		Map<String, Object> stateByField = (Map<String, Object>)JSON.deserializeUntyped(JSON.serialize(cachedState));
		stateByField.remove(FIELD_STATE_CHANGED_TIME);
		cache.put(SERVICE_NAME, JSON.deserialize(JSON.serialize(stateByField), UTIL_CircuitBreaker.CircuitState.class), CACHE_SECONDS);
		UTIL_CircuitBreaker.Breaker breaker = UTIL_CircuitBreaker.monitor(SERVICE_NAME).withTimeout(LONG_TIMEOUT_SECONDS).withHalfOpenMaxAttempts(TRIAL_REQUESTS);

		Boolean isAllowed = breaker.allowRequest();
		UTIL_CircuitBreaker.Metrics metrics = breaker.getMetrics();

		Assert.isTrue(isAllowed, 'Expected a request to be allowed when the cached state has no start time for its round, got a refusal');
		Assert.areEqual(UTIL_CircuitBreaker.State.HALF_OPEN, metrics.state, 'Expected the HALF_OPEN state the test stored in the org cache, got ' + metrics.state);
		Assert.isNotNull(metrics.stateChangedTime, 'Expected the new round to get a start time, got none');
	}

	/**
	 * @description Tests manual reset of circuit breaker
	 */
	@IsTest
	private static void shouldResetCircuitManually()
	{
		UTIL_CircuitBreaker.Breaker breaker = UTIL_CircuitBreaker.monitor(SERVICE_NAME)
				.withFailureThreshold(2);

		// When - Open the circuit
		breaker.recordFailure();
		breaker.recordFailure();
		Assert.areEqual(UTIL_CircuitBreaker.State.OPEN, breaker.getState(), 'Circuit should be OPEN');

		// Reset manually
		breaker.reset();
		UTIL_CircuitBreaker.State state = breaker.getState();
		UTIL_CircuitBreaker.Metrics metrics = breaker.getMetrics();

		Assert.areEqual(UTIL_CircuitBreaker.State.CLOSED, state, 'Circuit should be CLOSED after manual reset');
		Assert.areEqual(0, metrics.failureCount, 'Failure count should be reset to 0');
		Assert.isTrue(breaker.allowRequest(), 'Should allow requests after reset');
	}

	/**
	 * @description Tests manual forcing circuit to OPEN
	 */
	@IsTest
	private static void shouldForceCircuitOpen()
	{
		UTIL_CircuitBreaker.Breaker breaker = UTIL_CircuitBreaker.monitor(SERVICE_NAME);
		Assert.areEqual(UTIL_CircuitBreaker.State.CLOSED, breaker.getState(), 'Should start CLOSED');

		// When - Force open
		breaker.forceOpen();
		UTIL_CircuitBreaker.State state = breaker.getState();

		Assert.areEqual(UTIL_CircuitBreaker.State.OPEN, state, 'Circuit should be OPEN after force open');
		Assert.isFalse(breaker.allowRequest(), 'Should not allow requests after forcing open');
	}

	/**
	 * @description Tests getMetrics returns accurate metrics
	 */
	@IsTest
	private static void shouldReturnAccurateMetrics()
	{
		UTIL_CircuitBreaker.Breaker breaker = UTIL_CircuitBreaker.monitor(SERVICE_NAME)
				.withFailureThreshold(5);

		// When - Record some failures
		breaker.recordFailure();
		breaker.recordFailure();
		breaker.recordFailure();

		UTIL_CircuitBreaker.Metrics metrics = breaker.getMetrics();

		Assert.areEqual(SERVICE_NAME, metrics.circuitId, 'Circuit ID should match service name');
		Assert.areEqual(UTIL_CircuitBreaker.State.CLOSED, metrics.state, 'State should be CLOSED');
		Assert.areEqual(3, metrics.failureCount, 'Failure count should be 3');
		Assert.isNotNull(metrics.stateChangedTime, 'State changed time should be set');
	}

	/**
	 * @description Tests creating circuit breaker from ApiSetting
	 */
	@IsTest
	private static void shouldCreateConfigFromApiSetting()
	{
		ApiSetting__mdt setting = new ApiSetting__mdt(
				RetryBackoffSeconds__c = 20,
				MaxRetryCount__c = 5
		);

		UTIL_CircuitBreaker.Breaker breaker = UTIL_CircuitBreaker.fromSetting('TestService', setting);
		UTIL_CircuitBreaker.Metrics metrics = breaker.getMetrics();

		// Then - Should have configured correctly
		Assert.isNotNull(breaker, 'Should create breaker from setting');
		Assert.areEqual('TestService', metrics.circuitId, 'Circuit ID should match service name');

		// When - Null setting
		UTIL_CircuitBreaker.Breaker defaultBreaker = UTIL_CircuitBreaker.fromSetting('DefaultService', null);

		Assert.isNotNull(defaultBreaker, 'Should create breaker with defaults for null setting');
	}

	/**
	 * @description Tests monitor with custom config
	 */
	@IsTest
	private static void shouldCreateInstanceWithCustomConfig()
	{
		// Given/When
		UTIL_CircuitBreaker.Breaker breaker = UTIL_CircuitBreaker.monitor('CustomService')
				.withFailureThreshold(10);

		Assert.isNotNull(breaker, 'Should create instance with custom config');
		Assert.areEqual(UTIL_CircuitBreaker.State.CLOSED, breaker.getState(), 'Should start in CLOSED state');
	}

	/**
	 * @description Tests circuit breaker with default config
	 */
	@IsTest
	private static void shouldUseDefaultConfiguration()
	{
		// Given/When
		UTIL_CircuitBreaker.Breaker breaker = UTIL_CircuitBreaker.monitor(SERVICE_NAME);

		Assert.areEqual(UTIL_CircuitBreaker.State.CLOSED, breaker.getState(), 'Should use default config');
		Assert.isTrue(breaker.allowRequest(), 'Should allow requests with default config');
	}

	/**
	 * @description Test helper class implementing ProtectedAction
	 */
	private class TestProtectedAction implements UTIL_CircuitBreaker.ProtectedAction
	{
		/**
		 * @description True once execute() has run, so a test can tell whether the breaker let the action through.
		 */
		public Boolean wasExecuted = false;

		/**
		 * @description Set to true to make execute() throw, standing in for a call to an external system that fails.
		 */
		public Boolean shouldFail = false;

		/**
		 * @description Notes that the action ran, then throws when the test asked for a failure.
		 */
		public void execute()
		{
			wasExecuted = true;
			if(shouldFail)
			{
				throw new TestException('Simulated failure');
			}
		}
	}

	/**
	 * @description Test helper class implementing Provider
	 */
	private class TestProvider implements UTIL_CircuitBreaker.Provider
	{
		/**
		 * @description True once execute() has run, so a test can tell whether the breaker let the provider through.
		 */
		public Boolean wasExecuted = false;

		/**
		 * @description Set to true to make execute() throw, standing in for a call to an external system that fails.
		 */
		public Boolean shouldFail = false;

		/**
		 * @description The value execute() returns when it does not throw.
		 */
		public String resultValue = 'test result';

		/**
		 * @description Notes that the provider ran, then throws when the test asked for a failure.
		 *
		 * @return The value held in resultValue.
		 */
		public Object execute()
		{
			wasExecuted = true;
			if(shouldFail)
			{
				throw new TestException('Simulated failure');
			}
			return resultValue;
		}
	}

	/**
	 * @description Test exception class
	 */
	private class TestException extends Exception
	{
	}

	/**
	 * @description Tests execute() helper with successful action
	 */
	@IsTest
	private static void shouldExecuteProtectedActionSuccessfully()
	{
		UTIL_CircuitBreaker.Breaker breaker = UTIL_CircuitBreaker.monitor(SERVICE_NAME);
		TestProtectedAction action = new TestProtectedAction();

		breaker.execute(action);

		Assert.isTrue(action.wasExecuted, 'Action should have been executed');
		Assert.areEqual(UTIL_CircuitBreaker.State.CLOSED, breaker.getState(), 'Circuit should remain CLOSED');
	}

	/**
	 * @description Tests execute() helper records failure
	 */
	@IsTest
	private static void shouldRecordFailureFromProtectedAction()
	{
		UTIL_CircuitBreaker.Breaker breaker = UTIL_CircuitBreaker.monitor(SERVICE_NAME)
				.withFailureThreshold(1);
		TestProtectedAction action = new TestProtectedAction();
		action.shouldFail = true;

		try
		{
			breaker.execute(action);
			Assert.fail('Should have thrown TestException');
		}
		catch(TestException e)
		{
			Assert.isTrue(action.wasExecuted, 'Action should have been executed');
			Assert.areEqual(UTIL_CircuitBreaker.State.OPEN, breaker.getState(), 'Circuit should be OPEN after failure');
		}
	}

	/**
	 * @description Tests execute() throws exception when circuit is OPEN
	 */
	@IsTest
	private static void shouldThrowExceptionWhenCircuitIsOpen()
	{
		UTIL_CircuitBreaker.Breaker breaker = UTIL_CircuitBreaker.monitor(SERVICE_NAME)
				.withFailureThreshold(1);
		TestProtectedAction action = new TestProtectedAction();

		// Open the circuit
		breaker.recordFailure();
		Assert.areEqual(UTIL_CircuitBreaker.State.OPEN, breaker.getState(), 'Circuit should be OPEN');

		try
		{
			breaker.execute(action);
			Assert.fail('Should have thrown OpenException');
		}
		catch(UTIL_CircuitBreaker.OpenException error)
		{
			// Expected
			Assert.isTrue(error.getMessage().contains('OPEN'), 'Exception message should mention OPEN state');
		}

		Assert.isFalse(action.wasExecuted, 'Action should not have been executed when circuit is OPEN');
	}

	/**
	 * @description Tests execute() with provider returns result
	 */
	@IsTest
	private static void shouldExecuteProviderAndReturnResult()
	{
		UTIL_CircuitBreaker.Breaker breaker = UTIL_CircuitBreaker.monitor(SERVICE_NAME);
		TestProvider provider = new TestProvider();
		provider.resultValue = 'expected result';

		Object result = breaker.execute(provider);

		Assert.isTrue(provider.wasExecuted, 'Provider should have been executed');
		Assert.areEqual('expected result', result, 'Should return provider result');
		Assert.areEqual(UTIL_CircuitBreaker.State.CLOSED, breaker.getState(), 'Circuit should remain CLOSED');
	}

	/**
	 * @description Tests execute() with provider records failure
	 */
	@IsTest
	private static void shouldRecordFailureFromProvider()
	{
		UTIL_CircuitBreaker.Breaker breaker = UTIL_CircuitBreaker.monitor(SERVICE_NAME)
				.withFailureThreshold(1);
		TestProvider provider = new TestProvider();
		provider.shouldFail = true;

		try
		{
			breaker.execute(provider);
			Assert.fail('Should have thrown TestException');
		}
		catch(TestException e)
		{
			Assert.isTrue(provider.wasExecuted, 'Provider should have been executed');
			Assert.areEqual(UTIL_CircuitBreaker.State.OPEN, breaker.getState(), 'Circuit should be OPEN after failure');
		}
	}

	/**
	 * @description Tests execute() with provider throws exception when circuit is OPEN
	 */
	@IsTest
	private static void shouldThrowExceptionForProviderWhenCircuitIsOpen()
	{
		UTIL_CircuitBreaker.Breaker breaker = UTIL_CircuitBreaker.monitor(SERVICE_NAME)
				.withFailureThreshold(1);
		TestProvider provider = new TestProvider();

		// Open the circuit
		breaker.recordFailure();
		Assert.areEqual(UTIL_CircuitBreaker.State.OPEN, breaker.getState(), 'Circuit should be OPEN');

		try
		{
			breaker.execute(provider);
			Assert.fail('Should have thrown OpenException');
		}
		catch(UTIL_CircuitBreaker.OpenException error)
		{
			// Expected
			Assert.isTrue(error.getMessage().contains('OPEN'), 'Exception message should mention OPEN state');
		}

		Assert.isFalse(provider.wasExecuted, 'Provider should not have been executed when circuit is OPEN');
	}

	/**
	 * @description Tests circuit breaker gracefully handles cache failures during load
	 */
	@IsTest
	private static void shouldHandleCacheLoadFailure()
	{
		LOG_Builder.ignoreTestMode = true;

		// Given - Simulate cache get exception using UTIL_Cache flag
		UTIL_Cache.simulateGetException = true;

		Test.startTest();

		// When - Create breaker (will fail to load from cache due to simulated exception)
		UTIL_CircuitBreaker.Breaker breaker = UTIL_CircuitBreaker.monitor(SERVICE_NAME);

		Test.stopTest();

		// Reset flag
		UTIL_Cache.simulateGetException = false;

		// Then - Should still work with in-memory state
		Assert.areEqual(UTIL_CircuitBreaker.State.CLOSED, breaker.getState(), 'Should start CLOSED despite cache failure');
		Assert.isTrue(breaker.allowRequest(), 'Should allow requests despite cache failure');
	}

	/**
	 * @description Tests circuit breaker gracefully handles cache failures during save
	 */
	@IsTest
	private static void shouldHandleCacheSaveFailure()
	{
		LOG_Builder.ignoreTestMode = true;

		// Given - Circuit breaker that will attempt to save state
		UTIL_CircuitBreaker.Breaker breaker = UTIL_CircuitBreaker.monitor(SERVICE_NAME)
				.withFailureThreshold(2);

		// Simulate cache put exception using UTIL_Cache flag
		UTIL_Cache.simulatePutException = true;

		Test.startTest();

		// When - Record failure which will trigger save (will fail due to simulated exception)
		breaker.recordFailure();

		Test.stopTest();

		// Reset flag
		UTIL_Cache.simulatePutException = false;

		// Then - Circuit should still function correctly despite cache save failure
		UTIL_CircuitBreaker.Metrics metrics = breaker.getMetrics();
		Assert.areEqual(1, metrics.failureCount, 'Should track failures despite cache save issues');
		Assert.areEqual(UTIL_CircuitBreaker.State.CLOSED, breaker.getState(), 'Should remain CLOSED');
	}

	/**
	 * @description A breaker loads the state an earlier breaker for the same circuit saved to Platform Cache: two failures
	 * recorded through one breaker are read back by a second breaker created for the same circuit. Each call to monitor()
	 * creates a new breaker, so the second one can only know the failures through the cache. The circuit name is random,
	 * so no other test shares its cached state. In an org whose org cache has no space set aside, nothing is saved, so
	 * the second breaker starts with no failures.
	 */
	@IsTest
	private static void shouldLoadStateFromCache()
	{
		Integer expectedFailures = UTIL_Cache.isOrgAllocated() ? CACHED_CIRCUIT_FAILURES : 0;
		String circuitId = UTIL_Random.randomAlphanumeric(CACHED_CIRCUIT_NAME_LENGTH);
		UTIL_CircuitBreaker.Breaker firstBreaker = UTIL_CircuitBreaker.monitor(circuitId).withFailureThreshold(CACHED_CIRCUIT_FAILURE_THRESHOLD);
		firstBreaker.recordFailure();
		firstBreaker.recordFailure();

		UTIL_CircuitBreaker.Metrics metrics = UTIL_CircuitBreaker.monitor(circuitId).getMetrics();

		Assert.areEqual(expectedFailures, metrics.failureCount, 'Expected the second breaker to read ' + expectedFailures + ' failures, got ' + metrics.failureCount);
	}

	/**
	 * @description Tests all configuration methods can be chained
	 */
	@IsTest
	private static void shouldSupportFullFluentConfiguration()
	{
		// Given/When - Chain all fluent methods
		UTIL_CircuitBreaker.Breaker breaker = UTIL_CircuitBreaker.monitor(SERVICE_NAME)
				.withFailureThreshold(10)
				.withTimeout(120)
				.withSuccessThreshold(3)
				.withHalfOpenMaxAttempts(5);

		// Then - Should be configured and working
		Assert.isNotNull(breaker, 'Should create breaker with all configurations');
		Assert.areEqual(UTIL_CircuitBreaker.State.CLOSED, breaker.getState(), 'Should start CLOSED');

		// Verify configuration is applied
		UTIL_CircuitBreaker.Metrics metrics = breaker.getMetrics();
		Assert.isNotNull(metrics, 'Should return metrics');
	}

	/**
	 * @description Tests that fromSetting handles null values correctly
	 */
	@IsTest
	private static void shouldHandleNullApiSettingFields()
	{
		// Given - Setting with null fields
		ApiSetting__mdt setting = new ApiSetting__mdt(
				RetryBackoffSeconds__c = null,
				MaxRetryCount__c = null
		);

		UTIL_CircuitBreaker.Breaker breaker = UTIL_CircuitBreaker.fromSetting('TestService', setting);

		// Then - Should use defaults
		Assert.isNotNull(breaker, 'Should create breaker with defaults for null fields');
		Assert.areEqual(UTIL_CircuitBreaker.State.CLOSED, breaker.getState(), 'Should start CLOSED');
	}

	/**
	 * @description Tests that state transitions log appropriately, and that each transition line is labelled with
	 * the class name the platform resolves, so an install under a namespace stamps the line as the framework's.
	 */
	@IsTest
	private static void shouldLogStateTransitions()
	{
		LOG_Builder.ignoreTestMode = true;
		TST_Factory.setupLoggerForTest();

		UTIL_CircuitBreaker.Breaker breaker = UTIL_CircuitBreaker.monitor(SERVICE_NAME)
				.withFailureThreshold(1)
				.withTimeout(0)
				.withSuccessThreshold(1);

		// When - Trigger all state transitions
		Test.startTest();
		breaker.recordFailure(); // CLOSED -> OPEN (should log warn)
		breaker.getState(); // OPEN -> HALF_OPEN (should log info)
		breaker.recordSuccess(); // HALF_OPEN -> CLOSED (should log info)
		Test.stopTest();

		Assert.areEqual(UTIL_CircuitBreaker.State.CLOSED, breaker.getState(), 'Should be back to CLOSED');

		String expectedClassMethod = UTIL_CircuitBreaker.class.getName() + UTIL_String.DOT + 'transitionToOpen';
		LogEntry__c openRow = new SEL_LogEntry().findByMethod(expectedClassMethod);
		Assert.isNotNull(openRow, 'The transition to OPEN was written under the class name the platform resolves, not a bare literal');
	}

	/**
	 * @description A new round of trial requests writes one log line under the breaker's class name, so an administrator
	 * reading the log can see why a circuit whose trial requests were all used is letting requests through again.
	 */
	@IsTest
	private static void shouldLogANewRoundOfTrials()
	{
		LOG_Builder.ignoreTestMode = true;
		TST_Factory.setupLoggerForTest();

		Test.startTest();
		UTIL_CircuitBreaker.Breaker breaker = newHalfOpenBreaker();
		assertTrialRequestsAreAllowed(breaker, TRIAL_REQUESTS);
		waitForTheClockToMove();
		breaker.getState();
		Test.stopTest();

		String expectedClassMethod = UTIL_CircuitBreaker.class.getName() + UTIL_String.DOT + METHOD_START_NEW_ROUND;
		LogEntry__c newRoundRow = new SEL_LogEntry().findByMethod(expectedClassMethod);
		Assert.isNotNull(newRoundRow, 'Expected one log line written at ' + expectedClassMethod + ' for the new round of trial requests, got none');
	}

	/**
	 * @description Builds a breaker for the test circuit and takes it to HALF_OPEN with a zero timeout: one failure opens
	 * the circuit, the timeout passes as soon as the clock moves, and reading the state moves the circuit on. The state is
	 * read twice because the breaker skips its timeout check on the first read after the circuit opens.
	 *
	 * @return The breaker, HALF_OPEN, with no trial request used.
	 */
	private static UTIL_CircuitBreaker.Breaker newHalfOpenBreaker()
	{
		UTIL_CircuitBreaker.Breaker breaker = UTIL_CircuitBreaker.monitor(SERVICE_NAME)
				.withFailureThreshold(1)
				.withTimeout(IMMEDIATE_TIMEOUT_SECONDS)
				.withHalfOpenMaxAttempts(TRIAL_REQUESTS);
		breaker.recordFailure();
		breaker.getState();
		waitForTheClockToMove();
		breaker.getState();
		return breaker;
	}

	/**
	 * @description Asks the breaker for a number of requests in a row and asserts each one is allowed. No result is
	 * recorded for any of them, so each one uses a trial request of a HALF_OPEN circuit and leaves it used.
	 *
	 * @param breaker The breaker to ask.
	 * @param requestCount How many requests to ask for.
	 */
	private static void assertTrialRequestsAreAllowed(UTIL_CircuitBreaker.Breaker breaker, Integer requestCount)
	{
		for(Integer request = 1; request <= requestCount; request++)
		{
			Assert.isTrue(breaker.allowRequest(), 'Expected trial request ' + request + ' of ' + requestCount + ' to be allowed, got a refusal');
		}
	}

	/**
	 * @description Returns once the clock has moved on by at least one millisecond. A breaker with a zero timeout reads
	 * its timeout as passed from then on, so a test that calls this never depends on how long its own statements took.
	 */
	private static void waitForTheClockToMove()
	{
		Long startedAt = Datetime.now().getTime();
		Long currentTime = startedAt;
		while(currentTime == startedAt)
		{
			currentTime = Datetime.now().getTime();
		}
	}
}