// SPDX-License-Identifier: Apache-2.0
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
 * @date March 2026, October 2026
 */
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest(seeAllData=false isParallel=true)
private class SubscriberResilience_TEST
{
	/**
	 * @description Test credential name used as the mock service key for ad-hoc calls.
	 */
	private static final String TEST_CREDENTIAL = 'ResilienceTestCredential';
	/**
	 * @description The status an external system answers with when it is too busy to take the request: it did not
	 * process it, so the framework may send it again whatever the HTTP method.
	 */
	private static final Integer SERVICE_UNAVAILABLE = 503;
	/**
	 * @description How many retries the retry test asks for.
	 */
	private static final Integer RETRY_ALLOWANCE = 2;
	/**
	 * @description How many seconds the retry test asks the framework to wait before the next attempt.
	 */
	private static final Integer BACKOFF_SECONDS = 5;
	/**
	 * @description A stored date and time keeps whole seconds only, so it can read up to a second earlier than the time
	 * the test took around the call.
	 */
	private static final Integer STORED_TIME_TOLERANCE_SECONDS = 1;
	/**
	 * @description The status of an ApiCall record that is waiting for its next attempt.
	 */
	private static final String STATUS_RETRY = 'Retry';
	/**
	 * @description How many random letters and digits make up the text the retry test sends.
	 */
	private static final Integer MESSAGE_LENGTH = 12;

	/**
	 * @description A circuit breaker that has recorded nothing yet is CLOSED, the state in which requests are allowed, so
	 * a service is never blocked before it has failed.
	 */
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

	/**
	 * @description Once the recorded failures reach the threshold (two here) the breaker is OPEN and allowRequest answers
	 * false, so callers stop sending requests to a service that keeps failing.
	 */
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

	/**
	 * @description With a timeout of zero the wait after opening is over at once, so the next allowRequest moves the
	 * breaker from OPEN to HALF_OPEN, the state that comes between a failing service and a trusted one.
	 */
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

	/**
	 * @description With a success threshold of one, a single recorded success in HALF_OPEN closes the breaker again, so a
	 * service that has recovered gets its requests back.
	 */
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

	/**
	 * @description Running an action through a breaker that was forced OPEN throws OpenException, so the caller is told
	 * the call was refused and can decide what to do instead.
	 */
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

	/**
	 * @description An exponential retry strategy with a base wait of 5 doubles the wait on each retry: 5, 10, 20, then
	 * 40. Whoever sets the base can work out every wait in advance.
	 */
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

	/**
	 * @description A linear retry strategy never waits longer than its maximum: with a base wait of 100 and a maximum of
	 * 250, the wait at retry 3 is 250.
	 */
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

	/**
	 * @description A call sent through the API_EchoSubscriber handler with two retries and a wait of five seconds, against
	 * an external system that keeps answering 503 (it did not process the request, so a repeat is safe for any method),
	 * is not given up: its one ApiCall record is left waiting for a retry, with one retry counted, the two that were asked
	 * for as its allowance, and the next attempt set the wait after the call.
	 */
	@IsTest
	private static void shouldScheduleARetryWhenTheDelegatedCallFails()
	{
		String echoService = API_EchoSubscriber.class.getName();
		kern.API_MockFactory.forService(echoService)
				.body('{"error":"service unavailable"}')
				.statusCode(SERVICE_UNAVAILABLE)
				.register();
		Datetime earliestRetry = Datetime.now().addSeconds(BACKOFF_SECONDS - STORED_TIME_TOLERANCE_SECONDS);

		Test.startTest();
		kern.UTIL_HttpClient.useHandler(API_EchoSubscriber.class)
				.withRetry(RETRY_ALLOWANCE, BACKOFF_SECONDS)
				.withParameter(API_EchoSubscriber.PARAM_MESSAGE, kern.UTIL_Random.randomAlphanumeric(MESSAGE_LENGTH))
				.invoke();
		Test.stopTest();
		Datetime latestRetry = Datetime.now().addSeconds(BACKOFF_SECONDS);

		List<kern__ApiCall__c> calls = kern.QRY_Builder.selectFrom(kern__ApiCall__c.SObjectType)
				.fields(new List<SObjectField>
				{
						kern__ApiCall__c.kern__Status__c, kern__ApiCall__c.kern__StatusCode__c, kern__ApiCall__c.kern__Retries__c,
						kern__ApiCall__c.kern__MaxRetries__c, kern__ApiCall__c.kern__NextRetry__c
				})
				.condition(kern__ApiCall__c.kern__ServiceName__c).equals(echoService)
				.toList();
		Assert.areEqual(1, calls.size(), 'Expected one ApiCall record for the call, got ' + calls.size());
		kern__ApiCall__c call = calls[0];
		Assert.areEqual(STATUS_RETRY, call.kern__Status__c, 'Expected the call to wait for a retry, got ' + call.kern__Status__c);
		Assert.areEqual(String.valueOf(SERVICE_UNAVAILABLE), call.kern__StatusCode__c, 'Expected the external system\'s status code');
		Assert.areEqual(1, call.kern__Retries__c, 'Expected one retry counted, got ' + call.kern__Retries__c);
		Assert.areEqual(RETRY_ALLOWANCE, call.kern__MaxRetries__c, 'Expected the retry allowance that was asked for, got ' + call.kern__MaxRetries__c);
		Assert.isTrue(call.kern__NextRetry__c >= earliestRetry && call.kern__NextRetry__c <= latestRetry,
				'Expected the next attempt between ' + earliestRetry + ' and ' + latestRetry + ', got ' + call.kern__NextRetry__c);
	}

	/**
	 * @description No-op action for circuit breaker execute() test.
	 */
	private class NoOpAction implements kern.UTIL_CircuitBreaker.ProtectedAction
	{
		/**
		 * @description Executes nothing; used to verify circuit breaker blocks when OPEN.
		 */
		public void execute()
		{
		}
	}
}
