// =============================================================================
// Section 30: Resilience Strategies — Circuit Breaker & Retry Strategy
// =============================================================================
// Org: ${SF_SUBSCRIBER_ORG_ALIAS}
// Prerequisites:
//   - kern managed package installed
//   - Platform Cache partition allocated (kern__Library)
//
// Tests UTIL_CircuitBreaker state machine (CLOSED → OPEN → HALF_OPEN → CLOSED),
// manual transitions (forceOpen/reset), metrics, and UTIL_Retry backoff math
// (exponential, linear, cap, shouldRetry boundary).
//
// Run:
//   sf apex run -o $SF_SUBSCRIBER_ORG_ALIAS -f release-testing/scripts/section-30-resilience-strategies.apex
// =============================================================================

String circuitPrefix = 'S30_' + System.currentTimeMillis();
String mainId = circuitPrefix + '_main';
String manualId = circuitPrefix + '_manual';
String metricsId = circuitPrefix + '_metrics';

try
{
	// Test 30a: New breaker starts CLOSED and allows requests
	{
		kern.UTIL_CircuitBreaker.Breaker breaker = kern.UTIL_CircuitBreaker.monitor(mainId)
				.withFailureThreshold(3).withTimeout(1);
		System.assert(
				breaker.getState() == kern.UTIL_CircuitBreaker.State.CLOSED,
				'30a FAIL: Initial state should be CLOSED, got ' + breaker.getState()
		);
		System.assert(breaker.allowRequest(), '30a FAIL: allowRequest should be true when CLOSED');
		System.debug('30a PASS: New breaker starts CLOSED and allows requests');
	}

	// Test 30b: Three failures transition to OPEN, blocks requests
	{
		kern.UTIL_CircuitBreaker.Breaker breaker = kern.UTIL_CircuitBreaker.monitor(mainId)
				.withFailureThreshold(3).withTimeout(1);
		breaker.recordFailure();
		breaker.recordFailure();
		breaker.recordFailure();
		System.assert(
				breaker.getState() == kern.UTIL_CircuitBreaker.State.OPEN,
				'30b FAIL: State should be OPEN after 3 failures, got ' + breaker.getState()
		);
		System.assert(!breaker.allowRequest(), '30b FAIL: allowRequest should be false when OPEN');
		System.debug('30b PASS: Three failures transition to OPEN and block requests');
	}

	// Test 30c: Spin-wait past timeout, new instance reads HALF_OPEN from cache
	{
		Long waitStart = System.currentTimeMillis();
		while(System.currentTimeMillis() - waitStart < 2000)
		{
		}

		kern.UTIL_CircuitBreaker.Breaker halfOpen = kern.UTIL_CircuitBreaker.monitor(mainId)
				.withFailureThreshold(3).withTimeout(1);
		halfOpen.allowRequest();
		System.assert(
				halfOpen.getState() == kern.UTIL_CircuitBreaker.State.HALF_OPEN,
				'30c FAIL: State should be HALF_OPEN after timeout elapsed, got ' + halfOpen.getState()
		);
		System.debug('30c PASS: New instance transitions to HALF_OPEN after timeout via cache');
	}

	// Test 30d: Two successes in HALF_OPEN close the circuit
	{
		kern.UTIL_CircuitBreaker.Breaker halfOpen = kern.UTIL_CircuitBreaker.monitor(mainId)
				.withFailureThreshold(3).withTimeout(1);
		halfOpen.recordSuccess();
		halfOpen.recordSuccess();
		System.assert(
				halfOpen.getState() == kern.UTIL_CircuitBreaker.State.CLOSED,
				'30d FAIL: State should be CLOSED after 2 successes in HALF_OPEN, got ' + halfOpen.getState()
		);
		System.debug('30d PASS: Two successes in HALF_OPEN close the circuit');
	}

	// Test 30e: forceOpen sets OPEN, reset restores CLOSED
	{
		kern.UTIL_CircuitBreaker.Breaker manual = kern.UTIL_CircuitBreaker.monitor(manualId)
				.withFailureThreshold(3).withTimeout(1);
		manual.forceOpen();
		System.assert(
				manual.getState() == kern.UTIL_CircuitBreaker.State.OPEN,
				'30e FAIL: forceOpen should set OPEN, got ' + manual.getState()
		);
		manual.reset();
		System.assert(
				manual.getState() == kern.UTIL_CircuitBreaker.State.CLOSED,
				'30e FAIL: reset should restore CLOSED, got ' + manual.getState()
		);
		System.debug('30e PASS: forceOpen sets OPEN, reset restores CLOSED');
	}

	// Test 30f: Trip breaker and verify metrics
	{
		kern.UTIL_CircuitBreaker.Breaker metricsBreaker = kern.UTIL_CircuitBreaker.monitor(metricsId)
				.withFailureThreshold(3).withTimeout(1);
		metricsBreaker.recordFailure();
		metricsBreaker.recordFailure();
		metricsBreaker.recordFailure();
		kern.UTIL_CircuitBreaker.Metrics m = metricsBreaker.getMetrics();
		System.assert(m.failureCount == 3, '30f FAIL: failureCount should be 3, got ' + m.failureCount);
		System.assert(
				m.state == kern.UTIL_CircuitBreaker.State.OPEN,
				'30f FAIL: metrics state should be OPEN, got ' + m.state
		);
		System.assert(m.circuitId == metricsId, '30f FAIL: circuitId should be ' + metricsId + ', got ' + m.circuitId);
		System.debug('30f PASS: Metrics report failureCount=3, state=OPEN, correct circuitId');
	}

	// Test 30g: Exponential backoff — base=10, retries 0/1/2 → 10/20/40
	{
		kern.UTIL_Retry.Strategy exponential = kern.UTIL_Retry.exponential().withBaseBackoff(10);
		Integer b0 = exponential.calculateBackoff(kern.UTIL_Retry.newContext(0));
		Integer b1 = exponential.calculateBackoff(kern.UTIL_Retry.newContext(1));
		Integer b2 = exponential.calculateBackoff(kern.UTIL_Retry.newContext(2));
		System.assert(b0 == 10, '30g FAIL: Exponential retry 0 should be 10, got ' + b0);
		System.assert(b1 == 20, '30g FAIL: Exponential retry 1 should be 20, got ' + b1);
		System.assert(b2 == 40, '30g FAIL: Exponential retry 2 should be 40, got ' + b2);
		System.debug('30g PASS: Exponential backoff base=10 produces 10/20/40');
	}

	// Test 30h: Linear backoff — base=15, retries 1/2 → 15/30
	{
		kern.UTIL_Retry.Strategy linear = kern.UTIL_Retry.linear().withBaseBackoff(15);
		Integer b1 = linear.calculateBackoff(kern.UTIL_Retry.newContext(1));
		Integer b2 = linear.calculateBackoff(kern.UTIL_Retry.newContext(2));
		System.assert(b1 == 15, '30h FAIL: Linear retry 1 should be 15, got ' + b1);
		System.assert(b2 == 30, '30h FAIL: Linear retry 2 should be 30, got ' + b2);
		System.debug('30h PASS: Linear backoff base=15 produces 15/30');
	}

	// Test 30i: shouldRetry boundary — maxRetries=3, retry 2 → true, retry 3 → false
	{
		kern.UTIL_Retry.Strategy strategy = kern.UTIL_Retry.exponential().withMaxRetries(3);
		Boolean retry2 = strategy.shouldRetry(kern.UTIL_Retry.newContext(2));
		Boolean retry3 = strategy.shouldRetry(kern.UTIL_Retry.newContext(3));
		System.assert(retry2 == true, '30i FAIL: shouldRetry(2) should be true when maxRetries=3');
		System.assert(retry3 == false, '30i FAIL: shouldRetry(3) should be false when maxRetries=3');
		System.debug('30i PASS: shouldRetry boundary correct at maxRetries=3');
	}

	// Test 30j: Exponential with cap — base=10, max=50, retry 5 → 50 (capped from 320)
	{
		kern.UTIL_Retry.Strategy capped = kern.UTIL_Retry.exponential()
				.withBaseBackoff(10).withMaximumBackoff(50);
		Integer b5 = capped.calculateBackoff(kern.UTIL_Retry.newContext(5));
		System.assert(b5 == 50, '30j FAIL: Exponential retry 5 should be capped at 50, got ' + b5);
		System.debug('30j PASS: Exponential backoff capped at 50 (from 320)');
	}

	// Test 30k: Bulk-200 boundary — invoke circuit breaker 200 times, verify state machine behavior at volume
	// Scaled to 200 allowRequest() polls (read-only cache reads) — stays well within 10s CPU governor.
	// Breaker starts CLOSED, trips to OPEN after threshold=3, then all remaining 197 calls see OPEN (blocked).
	{
		String bulkId = circuitPrefix + '_bulk200';
		kern.UTIL_CircuitBreaker.Breaker bulkBreaker = kern.UTIL_CircuitBreaker.monitor(bulkId)
				.withFailureThreshold(3).withTimeout(300);

		System.assert(bulkBreaker.getState() == kern.UTIL_CircuitBreaker.State.CLOSED, '30k FAIL: Should start CLOSED');

		bulkBreaker.recordFailure();
		bulkBreaker.recordFailure();
		bulkBreaker.recordFailure();
		System.assert(bulkBreaker.getState() == kern.UTIL_CircuitBreaker.State.OPEN, '30k FAIL: Should be OPEN after threshold failures');

		Integer blockedCount = 0;
		for(Integer i = 0; i < 197; i++)
		{
			kern.UTIL_CircuitBreaker.Breaker probe = kern.UTIL_CircuitBreaker.monitor(bulkId)
					.withFailureThreshold(3).withTimeout(300);
			if(!probe.allowRequest()) blockedCount++;
		}
		System.assertEquals(197, blockedCount, '30k FAIL: All 197 remaining invocations should be blocked by OPEN breaker, only ' + blockedCount + ' blocked');
		System.debug('30k PASS: Circuit breaker state machine correct at bulk-200: CLOSED → OPEN after 3 failures, all 197 subsequent requests blocked');

		kern.UTIL_CircuitBreaker.monitor(bulkId).withFailureThreshold(3).withTimeout(300).reset();
	}

	System.debug('=== Section 30 COMPLETE: All resilience strategy tests passed ===');
}
catch(Exception error)
{
	System.debug('Section 30 ERROR: ' + error.getMessage());
	System.debug('Stack trace: ' + error.getStackTraceString());
}
finally
{
	kern.UTIL_CircuitBreaker.monitor(mainId).withFailureThreshold(3).withTimeout(1).reset();
	kern.UTIL_CircuitBreaker.monitor(manualId).withFailureThreshold(3).withTimeout(1).reset();
	kern.UTIL_CircuitBreaker.monitor(metricsId).withFailureThreshold(3).withTimeout(1).reset();
}
