// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Subscriber-side stress tests for framework resilience patterns: circuit breaker
 * state transitions, retry backoff calculations, and ad-hoc retry with mocked failures.
 * Exercises timeout=0 instant OPEN→HALF_OPEN transitions (test-context only) and
 * UTIL_HttpClient retry persistence.
 *
 * @see kern.UTIL_CircuitBreaker
 * @see kern.UTIL_Retry
 * @see kern.UTIL_HttpClient
 *
 * @author your.name@company.com
 *
 * @group Resilience
 *
 * @date March 2026, May 2026
 */
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest(SeeAllData=false IsParallel=true)
private class SubscriberResilience_TEST
{
	/**
	 * @description Test credential name used as the mock service key for ad-hoc calls.
	 */
	private static final String TEST_CREDENTIAL = 'ResilienceTestCredential';

	@IsTest
	private static void shouldStartInClosedState()
	{
		String circuitId = 'resilience_closed_' + System.currentTimeMillis();

		Test.startTest();
		kern.UTIL_CircuitBreaker.Breaker breaker = kern.UTIL_CircuitBreaker.monitor(circuitId)
				.withFailureThreshold(2).withTimeout(0);
		Test.stopTest();

		Assert.areEqual(
				kern.UTIL_CircuitBreaker.State.CLOSED, breaker.getState(),
				'Initial state should be CLOSED'
		);
		breaker.reset();
	}

	@IsTest
	private static void shouldTransitionToOpenAfterFailures()
	{
		String circuitId = 'resilience_open_' + System.currentTimeMillis();
		kern.UTIL_CircuitBreaker.Breaker breaker = kern.UTIL_CircuitBreaker.monitor(circuitId)
				.withFailureThreshold(2).withTimeout(60);

		Test.startTest();
		breaker.recordFailure();
		breaker.recordFailure();
		Test.stopTest();

		Assert.areEqual(
				kern.UTIL_CircuitBreaker.State.OPEN, breaker.getState(),
				'State should be OPEN after 2 failures'
		);
		Assert.isFalse(breaker.allowRequest(), 'allowRequest should be false when OPEN');
		breaker.reset();
	}

	@IsTest
	private static void shouldTransitionToHalfOpenAfterTimeout()
	{
		String circuitId = 'resilience_halfopen_' + System.currentTimeMillis();
		kern.UTIL_CircuitBreaker.Breaker breaker = kern.UTIL_CircuitBreaker.monitor(circuitId)
				.withFailureThreshold(2).withTimeout(0);
		breaker.recordFailure();
		breaker.recordFailure();

		Test.startTest();
		breaker.allowRequest();
		Test.stopTest();

		Assert.areEqual(
				kern.UTIL_CircuitBreaker.State.HALF_OPEN, breaker.getState(),
				'State should be HALF_OPEN after timeout elapsed'
		);
		breaker.reset();
	}

	@IsTest
	private static void shouldCloseAfterSuccessInHalfOpen()
	{
		String circuitId = 'resilience_close_' + System.currentTimeMillis();
		kern.UTIL_CircuitBreaker.Breaker breaker = kern.UTIL_CircuitBreaker.monitor(circuitId)
				.withFailureThreshold(2).withTimeout(0).withSuccessThreshold(1);
		breaker.recordFailure();
		breaker.recordFailure();
		breaker.allowRequest();

		Test.startTest();
		breaker.recordSuccess();
		Test.stopTest();

		Assert.areEqual(
				kern.UTIL_CircuitBreaker.State.CLOSED, breaker.getState(),
				'State should be CLOSED after success in HALF_OPEN'
		);
		breaker.reset();
	}

	@IsTest
	private static void shouldThrowOpenExceptionOnExecute()
	{
		String circuitId = 'resilience_exception_' + System.currentTimeMillis();
		kern.UTIL_CircuitBreaker.Breaker breaker = kern.UTIL_CircuitBreaker.monitor(circuitId)
				.withFailureThreshold(2).withTimeout(0);
		breaker.forceOpen();

		Test.startTest();
		try
		{
			breaker.execute(new NoOpAction());
			Assert.fail('Should throw OpenException');
		}
		catch(Exception error)
		{
			Assert.isInstanceOfType(error, kern.UTIL_CircuitBreaker.OpenException.class, 'Incorrect Exception Type');
		}
		Test.stopTest();

		breaker.reset();
	}

	@IsTest
	private static void shouldCalculateExponentialBackoff()
	{
		kern.UTIL_Retry.Strategy strategy = kern.UTIL_Retry.exponential().withBaseBackoff(5);

		Test.startTest();
		Integer backoff0 = strategy.calculateBackoff(kern.UTIL_Retry.newContext(0));
		Integer backoff1 = strategy.calculateBackoff(kern.UTIL_Retry.newContext(1));
		Integer backoff2 = strategy.calculateBackoff(kern.UTIL_Retry.newContext(2));
		Integer backoff3 = strategy.calculateBackoff(kern.UTIL_Retry.newContext(3));
		Test.stopTest();

		Assert.areEqual(5, backoff0, 'Backoff at retry 0 should be 5');
		Assert.areEqual(10, backoff1, 'Backoff at retry 1 should be 10');
		Assert.areEqual(20, backoff2, 'Backoff at retry 2 should be 20');
		Assert.areEqual(40, backoff3, 'Backoff at retry 3 should be 40');
	}

	@IsTest
	private static void shouldCalculateLinearBackoffWithCap()
	{
		kern.UTIL_Retry.Strategy strategy = kern.UTIL_Retry.linear()
				.withBaseBackoff(100).withMaximumBackoff(250);

		Test.startTest();
		Integer backoff3 = strategy.calculateBackoff(kern.UTIL_Retry.newContext(3));
		Test.stopTest();

		Assert.areEqual(250, backoff3, 'Backoff at retry 3 should be capped at 250');
	}

	@IsTest
	private static void shouldRetryDelegationCallOnFailure()
	{
		String echoService = API_EchoSubscriber.class.getName();
		kern.API_MockFactory.forService(echoService)
				.body('{"error":"service unavailable"}')
				.statusCode(500)
				.register();

		Test.startTest();
		kern.UTIL_HttpClient.useHandler(API_EchoSubscriber.class)
				.withRetry(2)
				.withParameter('message', 'retry test')
				.invoke();
		Test.stopTest();

		List<kern__ApiCall__c> calls =
		[
				SELECT kern__StatusCode__c,
						kern__MaxRetries__c
				FROM kern__ApiCall__c
				LIMIT 1
		];
		Assert.isFalse(calls.isEmpty(), 'ApiCall should be created for delegation retry call');
		Assert.areEqual('500', calls[0].kern__StatusCode__c, 'StatusCode should be 500 after retries exhausted');
		Assert.isTrue(calls[0].kern__MaxRetries__c >= 1, 'MaxRetries should be >= 1, got ' + calls[0].kern__MaxRetries__c);
	}

	/**
	 * @description No-op action for circuit breaker execute() test.
	 */
	private class NoOpAction implements kern.UTIL_CircuitBreaker.ProtectedAction
	{
		/**
		 * @description Executes nothing — used to verify circuit breaker blocks when OPEN.
		 */
		public void execute()
		{
		}
	}
}
