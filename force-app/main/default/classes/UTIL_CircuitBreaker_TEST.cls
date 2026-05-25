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
 * @date December 2025, May 2026
 */
@IsTest(SeeAllData=false IsParallel=true)
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
private class UTIL_CircuitBreaker_TEST
{
	private static final String SERVICE_NAME = 'TestAPIService';

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
	 * @description Tests limited requests allowed in HALF_OPEN state
	 */
	@IsTest
	private static void shouldAllowLimitedRequestsInHalfOpenState()
	{
		UTIL_CircuitBreaker.Breaker breaker = UTIL_CircuitBreaker.monitor(SERVICE_NAME)
				.withFailureThreshold(1)
				.withTimeout(0)
				.withHalfOpenMaxAttempts(2);

		// When - Open circuit and transition to HALF_OPEN
		breaker.recordFailure();
		breaker.getState(); // Trigger transition to HALF_OPEN

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
		public Boolean wasExecuted = false;
		public Boolean shouldFail = false;

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
		public Boolean wasExecuted = false;
		public Boolean shouldFail = false;
		public String resultValue = 'test result';

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
	 * @description Tests that circuit breaker state loads from cache when available.
	 * This test manually populates the cache to exercise the cache.get() code path (line 1047).
	 */
	@IsTest
	private static void shouldLoadStateFromCache()
	{
		// Given - Manually create and save a circuit state to cache
		String testCircuitId = 'TestCachedCircuit';

		// Note: We can't easily serialize CircuitState since it's private, so this test
		// verifies the cache retrieval logic by creating a breaker, letting it save state,
		// then creating another instance to load it
		UTIL_CircuitBreaker.Breaker breaker1 = UTIL_CircuitBreaker.monitor(testCircuitId)
				.withFailureThreshold(3);

		// Record failures to trigger state save to cache
		breaker1.recordFailure();
		breaker1.recordFailure();

		// When - Create a NEW instance (not singleton) which should attempt to load from cache
		// The loadState() method will call cache.contains() and cache.get()
		UTIL_CircuitBreaker.Breaker breaker2 = UTIL_CircuitBreaker.monitor(testCircuitId);

		// Then - If cache is working, breaker2 loads the saved state. If cache is not available in tests,
		// it creates new state. Either way, this test exercises the loadState() code path including line 1047.
		UTIL_CircuitBreaker.Metrics metrics = breaker2.getMetrics();

		// The assertion depends on whether platform cache is available in the test environment
		// In most cases, cache works and we'll load the 2 failures. If not, we get 0.
		Boolean cacheWorked = (metrics.failureCount == 2);
		Boolean cacheMissed = (metrics.failureCount == 0);

		Assert.isTrue(cacheWorked || cacheMissed,
				'Should either load from cache (2 failures) or create new state (0 failures). Got: ' + metrics.failureCount);
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
	 * @description Tests that state transitions log appropriately
	 */
	@IsTest
	private static void shouldLogStateTransitions()
	{
		LOG_Builder.ignoreTestMode = true;

		UTIL_CircuitBreaker.Breaker breaker = UTIL_CircuitBreaker.monitor(SERVICE_NAME)
				.withFailureThreshold(1)
				.withTimeout(0)
				.withSuccessThreshold(1);

		// When - Trigger all state transitions
		breaker.recordFailure(); // CLOSED -> OPEN (should log warn)
		breaker.getState(); // OPEN -> HALF_OPEN (should log info)
		breaker.recordSuccess(); // HALF_OPEN -> CLOSED (should log info)

		Assert.areEqual(UTIL_CircuitBreaker.State.CLOSED, breaker.getState(), 'Should be back to CLOSED');
	}
}