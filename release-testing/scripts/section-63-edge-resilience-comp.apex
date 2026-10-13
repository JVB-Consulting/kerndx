/**
 * Section 63: UTIL_CircuitBreaker + UTIL_Retry — Composition Edge Cases
 *
 * Closes coverage gaps beyond section-30 (happy-path) and SubscriberResilience_TEST.
 * Covers 6 anon-Apex edge scenarios from the extended-load spec §6.12.
 *
 * Scenarios:
 *   63a. HALF_OPEN regress: one failure in HALF_OPEN → immediate OPEN (no threshold re-trip).
 *        recordFailure() HALF_OPEN branch calls transitionToOpen() unconditionally.
 *        HALF_OPEN reached via forceOpen() + timeout=1 + 2s spin-wait (anon Apex; Test.isRunningTest()
 *        is false so timeout=0 millisecond shortcut does not apply).
 *
 *   63b. shouldRetry with a non-retryable exception type.
 *        The filter exists: kern.UTIL_Retry.dontRetryOnException(base, types) and
 *        retryOnlyOnException(base, types) wrap a strategy and read the exception passed through
 *        Context.withCustomData, matched by its exact type name.
 *        OBSERVABLE: a dontRetryOnException(exponential().withMaxRetries(2), {System.CalloutException})
 *        strategy answers false for a CalloutException, true for an IllegalArgumentException and
 *        true when no exception is passed. The through-the-handler proof (a handler whose
 *        createRetryStrategy() denylists the exception, on the real call path) is
 *        SubscriberOutboundRetry_TEST.shouldNotScheduleARetryForAFailureTheHandlerDenylists.
 *
 *   63c. Retry exhaustion + onFailure(BLOCK) — SPEC DEVIATION.
 *        FailureAction.BLOCK does not exist (only LOG_FAILURE and RETRY_THEN_LOG).
 *        Re-throw-after-exhaustion is the DEFAULT in ad-hoc mode (no onFailure call).
 *        OBSERVABLE: manual retry loop — shouldRetry returns false at exhaustion; last exception re-thrown.
 *        FRAMEWORK FOLLOW-UP: add FailureAction.BLOCK / RETHROW enum value.
 *
 *   63d. Retry exhaustion + onFailure(LOG_AND_CONTINUE) — SPEC DEVIATION.
 *        FailureAction.LOG_AND_CONTINUE does not exist. Nearest equivalent: LOG_FAILURE
 *        (sets logFailures=true + skipRetry=true in ad-hoc mode).
 *        OBSERVABLE: LOG_FAILURE + 500 mock → ApiIssue created, Status=Failed.
 *        FRAMEWORK FOLLOW-UP: add LOG_AND_CONTINUE alias for LOG_FAILURE.
 *
 *   63e. Circuit breaker + retry combination: retry does NOT bypass open breaker.
 *        UTIL_Retry has no awareness of UTIL_CircuitBreaker. Composition is caller-side.
 *        OBSERVABLE: allowRequest=false AND shouldRetry=true → composed gate=false; OpenException thrown.
 *        FRAMEWORK FOLLOW-UP: UTIL_ResilientClient or UTIL_Retry.withCircuitBreaker(Breaker).
 *
 *   63f. exponential().withJitter(false) — deterministic backoff for assertion.
 *        Exponential(base=10, mult=2.0): 0→10, 1→20, 2→40, 3→80.
 *        Linear(base=15): 1→15, 2→30. Custom multiplier(base=5, mult=3.0): 0→5, 1→15, 2→45.
 *        withJitter(true) produces values in expected [base, base+25%] range.
 *
 * Deferrals:
 *   §6.12 #2: closed. The exception filter is UTIL_Retry.dontRetryOnException / retryOnlyOnException (63b).
 *   §6.12 #3: FailureAction.BLOCK absent — SPEC DEVIATION. Follow-up: add BLOCK/RETHROW.
 *   §6.12 #4: FailureAction.LOG_AND_CONTINUE absent — SPEC DEVIATION. Follow-up: alias LOG_FAILURE.
 *   §6.12 #5: no native breaker+retry coupling — caller-side composition required.
 *
 * Run-isolation: circuit breaker state in Platform Cache (timestamp-prefixed IDs). Cleanup resets
 * all breakers. Scenario 63d creates ApiCall/ApiIssue rows; cleanup deletes them and proves by query
 * that none is left. The log entries this run writes land after it ends, so
 * section-63-edge-resilience-comp-cleanup.apex, run 30 seconds later, deletes them and proves it.
 *
 * Prerequisites:
 *   - ${SF_SUBSCRIBER_ORG_ALIAS} org, kern managed package installed.
 *   - API_EchoSubscriber deployed. kern__ApiSetting.EchoSubscriber (LogIssues=true).
 *   - The MockAllAPIs feature flag on (fixture cmdt-states/mock-all-apis-enabled; phase 2 deploys it around this
 *     section and restores mock-all-apis-disabled after): scenario 63d registers its answer through
 *     kern.API_MockFactory, which stands in for the callout outside a unit test only while MockAllAPIs is on.
 *   - Platform Cache partition allocated (kern__Library).
 *
 * Run:
 *   sf apex run --file release-testing/scripts/section-63-edge-resilience-comp.apex -o $SF_SUBSCRIBER_ORG_ALIAS
 *
 * Expected wall-clock: 3-5 seconds (2s spin-wait for 63a HALF_OPEN transition).
 */

System.debug(LoggingLevel.INFO, '');
System.debug(LoggingLevel.INFO, '=== Section 63: UTIL_CircuitBreaker + UTIL_Retry — Composition Edge Cases ===');

kern.TRG_Base.clearAllBypasses();
kern.API_MockFactory.clearMocks();

Integer pass = 0;
Integer fail = 0;
List<String> failures = new List<String>();

final String CIRCUIT_PREFIX = 'S63_' + System.currentTimeMillis();
final String CIRCUIT_HALF_OPEN = CIRCUIT_PREFIX + '_halfopen';
final String CIRCUIT_COMBO = CIRCUIT_PREFIX + '_combo';
final String CIRCUIT_EXEC = CIRCUIT_PREFIX + '_exec';
final String SERVICE_NAME = API_EchoSubscriber.class.getName();

// Scenario 63a — HALF_OPEN regress: one failure during HALF_OPEN → immediate OPEN.
// DefaultCircuitBreaker.recordFailure() HALF_OPEN branch calls transitionToOpen() unconditionally.
// Reaching HALF_OPEN in anon Apex: forceOpen() + timeout=1 + 2s spin-wait.
try
{
	kern.UTIL_CircuitBreaker.Breaker breaker63a = kern.UTIL_CircuitBreaker.monitor(CIRCUIT_HALF_OPEN)
			.withFailureThreshold(5)
			.withTimeout(1)
			.withSuccessThreshold(2)
			.withHalfOpenMaxAttempts(3);

	breaker63a.forceOpen();

	Assert.areEqual(
			kern.UTIL_CircuitBreaker.State.OPEN,
			breaker63a.getState(),
			'63a setup: breaker must be OPEN after forceOpen()'
	);

	Long spinStart63a = System.currentTimeMillis();
	while(System.currentTimeMillis() - spinStart63a < 2000)
	{
	}

	Boolean allowed63a = breaker63a.allowRequest();
	kern.UTIL_CircuitBreaker.State stateAfterAllow63a = breaker63a.getState();

	Assert.areEqual(
			kern.UTIL_CircuitBreaker.State.HALF_OPEN,
			stateAfterAllow63a,
			'63a: allowRequest() after timeout=1 elapsed (2s spin) must transition to HALF_OPEN. '
			+ 'Got: ' + stateAfterAllow63a
	);

	Assert.isTrue(allowed63a,
			'63a: first allowRequest() in HALF_OPEN must return true (halfOpenAttempts < max)'
	);

	breaker63a.recordFailure();

	kern.UTIL_CircuitBreaker.State stateAfterFailure63a = breaker63a.getState();

	Assert.areEqual(
			kern.UTIL_CircuitBreaker.State.OPEN,
			stateAfterFailure63a,
			'63a: recordFailure() in HALF_OPEN must immediately re-open (OPEN). Got: '
			+ stateAfterFailure63a
			+ '. FRAMEWORK: HALF_OPEN recordFailure() calls transitionToOpen() unconditionally.'
	);

	Assert.isFalse(
			breaker63a.allowRequest(),
			'63a: allowRequest() after HALF_OPEN regress must return false (circuit re-opened)'
	);

	Assert.areEqual(
			kern.UTIL_CircuitBreaker.State.OPEN,
			breaker63a.getMetrics().state,
			'63a: metrics.state must be OPEN after HALF_OPEN regress'
	);

	System.debug(LoggingLevel.INFO,
			'63a PASS: HALF_OPEN regress confirmed. forceOpen+2s spin→HALF_OPEN; '
			+ 'recordFailure→' + stateAfterFailure63a + ' (immediate, no threshold gate). '
			+ 'RATIONALE: HALF_OPEN is a trial state — any failure proves service still unhealthy.'
	);
	pass++;
}
catch(Exception scenarioError)
{
	System.debug(LoggingLevel.ERROR,
			'63a FAIL: ' + scenarioError.getMessage() + '\n' + scenarioError.getStackTraceString()
	);
	failures.add('63a: ' + scenarioError.getMessage());
	fail++;
}

// Scenario 63b — shouldRetry with a non-retryable exception type.
// UTIL_Retry.dontRetryOnException wraps a strategy with a denylist of exception types, read from the
// exception passed through Context.withCustomData and matched by exact type name. A denylisted
// exception is refused, any other exception is decided by the wrapped strategy, and a context with no
// exception reaches the wrapped strategy untouched. The through-the-handler proof, on the real call
// path, is SubscriberOutboundRetry_TEST.shouldNotScheduleARetryForAFailureTheHandlerDenylists.
try
{
	kern.UTIL_Retry.Strategy strategy63b = kern.UTIL_Retry.dontRetryOnException(
			kern.UTIL_Retry.exponential().withMaxRetries(2),
			new Set<Type> {System.CalloutException.class}
	);

	Assert.isFalse(
			strategy63b.shouldRetry(kern.UTIL_Retry.newContext(0).withCustomData(new System.CalloutException('63b'))),
			'63b: a denylisted CalloutException must not be retried, with budget left'
	);

	Assert.isTrue(
			strategy63b.shouldRetry(kern.UTIL_Retry.newContext(0).withCustomData(new IllegalArgumentException('63b'))),
			'63b: an IllegalArgumentException is not denylisted, so the wrapped strategy retries it'
	);

	Assert.isTrue(
			strategy63b.shouldRetry(kern.UTIL_Retry.newContext(0)),
			'63b: a context with no exception reaches the wrapped strategy, which retries it'
	);

	System.debug(LoggingLevel.INFO,
			'63b PASS: dontRetryOnException({CalloutException}) refused a CalloutException, '
			+ 'retried an IllegalArgumentException and retried a context with no exception.'
	);
	pass++;
}
catch(Exception scenarioError)
{
	System.debug(LoggingLevel.ERROR,
			'63b FAIL: ' + scenarioError.getMessage() + '\n' + scenarioError.getStackTraceString()
	);
	failures.add('63b: ' + scenarioError.getMessage());
	fail++;
}

// Scenario 63c — Retry exhaustion + onFailure(BLOCK) — SPEC DEVIATION.
// FailureAction.BLOCK does not exist. Re-throw is the DEFAULT (no onFailure) in ad-hoc mode.
// OBSERVABLE: manual retry loop; shouldRetry returns false at exhaustion; last exception re-thrown.
try
{
	kern.UTIL_Retry.Strategy strategy63c = kern.UTIL_Retry.linear()
			.withMaxRetries(2)
			.withBaseBackoff(5)
			.withJitter(false);

	Integer attemptCount63c = 0;
	Boolean exhaustionRethrown63c = false;
	String exhaustionMessage63c = null;

	try
	{
		while(true)
		{
			try
			{
				attemptCount63c++;
				throw new IllegalArgumentException('63c failure attempt ' + attemptCount63c);
			}
			catch(IllegalArgumentException attemptError)
			{
				if(!strategy63c.shouldRetry(kern.UTIL_Retry.newContext(attemptCount63c - 1)))
				{
					throw attemptError;
				}
			}
		}
	}
	catch(IllegalArgumentException exhaustionError)
	{
		exhaustionRethrown63c = true;
		exhaustionMessage63c = exhaustionError.getMessage();
	}

	Assert.areEqual(3, attemptCount63c,
			'63c: maxRetries=2 → 3 total attempts (1 initial + 2 retries). Got: ' + attemptCount63c
	);

	Assert.isTrue(exhaustionRethrown63c,
			'63c: last exception must be re-thrown after retry exhaustion (BLOCK semantic). '
			+ 'No rethrow detected.'
	);

	Assert.isTrue(
			exhaustionMessage63c != null && exhaustionMessage63c.contains('63c failure attempt 3'),
			'63c: re-thrown exception must be the last attempt (attempt 3). Got: ' + exhaustionMessage63c
	);

	Assert.isFalse(
			strategy63c.shouldRetry(kern.UTIL_Retry.newContext(3)),
			'63c: shouldRetry at count=3 (maxRetries=2) → false (exit gate confirmed)'
	);

	System.debug(LoggingLevel.INFO,
			'63c PASS (onFailure(BLOCK) absent — SPEC DEVIATION §6.12 #3): '
			+ '3 attempts, last exception re-thrown ("' + exhaustionMessage63c + '"). '
			+ 'shouldRetry(3)=false. '
			+ 'SPEC DEVIATION: FailureAction.BLOCK does not exist. '
			+ 'FRAMEWORK FOLLOW-UP: add FailureAction.BLOCK/RETHROW enum value.'
	);
	pass++;
}
catch(Exception scenarioError)
{
	System.debug(LoggingLevel.ERROR,
			'63c FAIL: ' + scenarioError.getMessage() + '\n' + scenarioError.getStackTraceString()
	);
	failures.add('63c: ' + scenarioError.getMessage());
	fail++;
}

// Scenario 63d — Retry exhaustion + onFailure(LOG_AND_CONTINUE) — SPEC DEVIATION.
// FailureAction.LOG_AND_CONTINUE absent. Nearest equivalent: LOG_FAILURE (logFailures=true + skipRetry).
// OBSERVABLE: LOG_FAILURE + 500 mock → ApiIssue created, Status=Failed.
try
{
	kern.API_MockFactory.forService(SERVICE_NAME)
			.body('{"error":"log-and-continue"}')
			.statusCode(500)
			.register();
	// A row's CreatedDate has whole seconds, so an earlier scenario's rows can share this second. The rows already there
	// are left out by id, so only the rows this scenario creates are read and counted.
	Datetime startedAt63d = Datetime.now().addSeconds(-1);
	Set<Id> earlierCallIds63d = new Map<Id, kern__ApiCall__c>(
			[SELECT Id FROM kern__ApiCall__c WHERE kern__ServiceName__c = :SERVICE_NAME AND CreatedDate >= :startedAt63d]).keySet();
	Set<Id> earlierIssueIds63d = new Map<Id, kern__ApiIssue__c>(
			[SELECT Id FROM kern__ApiIssue__c WHERE kern__ServiceName__c = :SERVICE_NAME AND CreatedDate >= :startedAt63d]).keySet();

	kern.UTIL_HttpClient.useHandler(API_EchoSubscriber.class)
			.onFailure(kern.UTIL_HttpClient.FailureAction.LOG_FAILURE)
			.withParameter('message', 'log-failure-63d-' + System.currentTimeMillis())
			.invoke();

	List<kern__ApiCall__c> apiCalls63d =
	[
			SELECT
					Id,
					kern__StatusCode__c,
					kern__Status__c,
					kern__MaxRetries__c
			FROM kern__ApiCall__c
			WHERE kern__ServiceName__c = :SERVICE_NAME
			AND CreatedDate >= :startedAt63d
			AND Id NOT IN :earlierCallIds63d
			ORDER BY CreatedDate DESC
			LIMIT 1
	];

	Assert.areEqual(1, apiCalls63d.size(),
			'63d: ApiCall row must be persisted for LOG_FAILURE + 500. '
			+ 'Confirm API_EchoSubscriber, kern__ApiSetting.EchoSubscriber and the MockAllAPIs feature flag (on).'
	);

	Assert.areEqual('500', apiCalls63d[0].kern__StatusCode__c,
			'63d: StatusCode__c must be 500. Got: ' + apiCalls63d[0].kern__StatusCode__c
	);

	Assert.areEqual('Failed', apiCalls63d[0].kern__Status__c,
			'63d: Status__c must be Failed (MaxRetries=0, no retry scheduled). '
			+ 'Got: ' + apiCalls63d[0].kern__Status__c
	);

	Integer apiIssueCount63d =
	[
			SELECT COUNT()
			FROM kern__ApiIssue__c
			WHERE kern__ServiceName__c = :SERVICE_NAME
			AND CreatedDate >= :startedAt63d
			AND Id NOT IN :earlierIssueIds63d
	];

	Assert.isTrue(apiIssueCount63d >= 1,
			'63d: at least 1 ApiIssue must be created — LOG_FAILURE sets logFailures=true. '
			+ 'Got: ' + apiIssueCount63d
	);

	System.debug(LoggingLevel.INFO,
			'63d PASS (onFailure(LOG_AND_CONTINUE) absent — SPEC DEVIATION §6.12 #4): '
			+ 'LOG_FAILURE + 500 → StatusCode=500, Status=Failed, '
			+ apiIssueCount63d + ' ApiIssue(s) created. '
			+ 'SPEC DEVIATION: FailureAction.LOG_AND_CONTINUE does not exist. '
			+ 'NEAREST: LOG_FAILURE (log + skip retry in ad-hoc mode). '
			+ 'FRAMEWORK FOLLOW-UP: add LOG_AND_CONTINUE alias for LOG_FAILURE.'
	);
	pass++;
}
catch(Exception scenarioError)
{
	System.debug(LoggingLevel.ERROR,
			'63d FAIL: ' + scenarioError.getMessage() + '\n' + scenarioError.getStackTraceString()
	);
	failures.add('63d: ' + scenarioError.getMessage());
	fail++;
}

// Scenario 63e — Breaker + retry combination: retry does NOT bypass open breaker.
// UTIL_Retry has no UTIL_CircuitBreaker awareness. Composition is caller-side.
// (a) shouldRetry=true does NOT prevent allowRequest()=false from blocking.
// (b) Composed gate: shouldRetry AND allowRequest → false when breaker is OPEN.
// (c) allowRequest()=false → caller raises OpenException to simulate execute() guard.
try
{
	kern.UTIL_Retry.Strategy strategy63e = kern.UTIL_Retry.exponential()
			.withMaxRetries(3)
			.withBaseBackoff(5)
			.withJitter(false);

	kern.UTIL_CircuitBreaker.Breaker breaker63e = kern.UTIL_CircuitBreaker.monitor(CIRCUIT_COMBO)
			.withFailureThreshold(5)
			.withTimeout(60)
			.withSuccessThreshold(2);

	breaker63e.reset();

	Assert.isTrue(
			strategy63e.shouldRetry(kern.UTIL_Retry.newContext(0)),
			'63e: shouldRetry at count=0 (maxRetries=3) must be true before breaker opens'
	);

	Assert.isTrue(
			breaker63e.allowRequest(),
			'63e: allowRequest on CLOSED breaker must be true (baseline)'
	);

	breaker63e.forceOpen();

	Assert.isFalse(
			breaker63e.allowRequest(),
			'63e: allowRequest on OPEN breaker must be false'
	);

	Assert.isTrue(
			strategy63e.shouldRetry(kern.UTIL_Retry.newContext(0)),
			'63e: shouldRetry does NOT check breaker — returns true regardless of breaker state. '
			+ 'Callers MUST combine shouldRetry AND allowRequest.'
	);

	Boolean composedGate63e = strategy63e.shouldRetry(kern.UTIL_Retry.newContext(0))
			&& breaker63e.allowRequest();

	Assert.isFalse(
			composedGate63e,
			'63e: composed gate (shouldRetry=true AND allowRequest=false) must be false. '
			+ 'Open breaker wins; retry does not bypass the breaker.'
	);

	Assert.isFalse(
			strategy63e.shouldRetry(kern.UTIL_Retry.newContext(3)),
			'63e: shouldRetry at count=3 (maxRetries=3) must be false — exhausted independently'
	);

	kern.UTIL_CircuitBreaker.Breaker breakerExec63e = kern.UTIL_CircuitBreaker.monitor(CIRCUIT_EXEC)
			.withFailureThreshold(5)
			.withTimeout(60);
	breakerExec63e.forceOpen();

	Boolean openExceptionThrown63e = false;
	String openExceptionTypeName63e = null;

	try
	{
		if(!breakerExec63e.allowRequest())
		{
			throw new kern.UTIL_CircuitBreaker.OpenException('Circuit OPEN — request blocked');
		}
	}
	catch(kern.UTIL_CircuitBreaker.OpenException openError)
	{
		openExceptionThrown63e = true;
		openExceptionTypeName63e = openError.getTypeName();
	}

	Assert.isTrue(openExceptionThrown63e,
			'63e: OPEN breaker allowRequest()=false must surface OpenException when caller enforces gate'
	);

	Assert.isTrue(
			openExceptionTypeName63e != null
			&& openExceptionTypeName63e.containsIgnoreCase('OpenException'),
			'63e: exception must be kern.UTIL_CircuitBreaker.OpenException. Got: ' + openExceptionTypeName63e
	);

	breakerExec63e.reset();

	System.debug(LoggingLevel.INFO,
			'63e PASS: Breaker+retry composition — no internal coupling. '
			+ 'shouldRetry(0)=true (breaker-agnostic). allowRequest on OPEN=false. '
			+ 'Composed gate=false. OpenException on allowRequest=false: '
			+ openExceptionTypeName63e + '. shouldRetry(3)=false (exhausted). '
			+ 'FRAMEWORK CONTRACT: UTIL_Retry and UTIL_CircuitBreaker are orthogonal. '
			+ 'FRAMEWORK FOLLOW-UP: UTIL_ResilientClient or withCircuitBreaker(Breaker).'
	);
	pass++;
}
catch(Exception scenarioError)
{
	System.debug(LoggingLevel.ERROR,
			'63e FAIL: ' + scenarioError.getMessage() + '\n' + scenarioError.getStackTraceString()
	);
	failures.add('63e: ' + scenarioError.getMessage());
	fail++;
}

// Scenario 63f — exponential().withJitter(false) — deterministic backoff.
// Exponential(base=10, mult=2.0): 0→10, 1→20, 2→40, 3→80.
// Linear(base=15): 1→15, 2→30.
// Custom multiplier exponential(base=5, mult=3.0): 0→5, 1→15, 2→45.
// withJitter(true) range: count=0 in [10,12], count=1 in [20,25] (max +25%).
try
{
	kern.UTIL_Retry.Strategy exp63f = kern.UTIL_Retry.exponential()
			.withBaseBackoff(10)
			.withJitter(false);

	Integer b63fExp0 = exp63f.calculateBackoff(kern.UTIL_Retry.newContext(0));
	Integer b63fExp1 = exp63f.calculateBackoff(kern.UTIL_Retry.newContext(1));
	Integer b63fExp2 = exp63f.calculateBackoff(kern.UTIL_Retry.newContext(2));
	Integer b63fExp3 = exp63f.calculateBackoff(kern.UTIL_Retry.newContext(3));

	Assert.areEqual(10, b63fExp0,
			'63f: exponential(base=10, mult=2, jitter=false) count=0 must be 10. Got: ' + b63fExp0
	);
	Assert.areEqual(20, b63fExp1,
			'63f: exponential count=1 must be 20 (10*2^1). Got: ' + b63fExp1
	);
	Assert.areEqual(40, b63fExp2,
			'63f: exponential count=2 must be 40 (10*2^2). Got: ' + b63fExp2
	);
	Assert.areEqual(80, b63fExp3,
			'63f: exponential count=3 must be 80 (10*2^3). Got: ' + b63fExp3
	);

	kern.UTIL_Retry.Strategy linear63f = kern.UTIL_Retry.linear()
			.withBaseBackoff(15)
			.withJitter(false);

	Integer b63fLin1 = linear63f.calculateBackoff(kern.UTIL_Retry.newContext(1));
	Integer b63fLin2 = linear63f.calculateBackoff(kern.UTIL_Retry.newContext(2));

	Assert.areEqual(15, b63fLin1,
			'63f: linear(base=15, jitter=false) count=1 must be 15 (15*1). Got: ' + b63fLin1
	);
	Assert.areEqual(30, b63fLin2,
			'63f: linear count=2 must be 30 (15*2). Got: ' + b63fLin2
	);

	kern.UTIL_Retry.Strategy customMult63f = kern.UTIL_Retry.exponential()
			.withBaseBackoff(5)
			.withExponentialMultiplier(3.0)
			.withJitter(false);

	Integer b63fCust0 = customMult63f.calculateBackoff(kern.UTIL_Retry.newContext(0));
	Integer b63fCust1 = customMult63f.calculateBackoff(kern.UTIL_Retry.newContext(1));
	Integer b63fCust2 = customMult63f.calculateBackoff(kern.UTIL_Retry.newContext(2));

	Assert.areEqual(5, b63fCust0,
			'63f: exponential(base=5, mult=3.0) count=0 must be 5 (5*3^0). Got: ' + b63fCust0
	);
	Assert.areEqual(15, b63fCust1,
			'63f: exponential(base=5, mult=3.0) count=1 must be 15 (5*3^1). Got: ' + b63fCust1
	);
	Assert.areEqual(45, b63fCust2,
			'63f: exponential(base=5, mult=3.0) count=2 must be 45 (5*3^2). Got: ' + b63fCust2
	);

	kern.UTIL_Retry.Strategy jitter63f = kern.UTIL_Retry.exponential()
			.withBaseBackoff(10)
			.withJitter(true);

	Integer b63fJit0 = jitter63f.calculateBackoff(kern.UTIL_Retry.newContext(0));
	Integer b63fJit1 = jitter63f.calculateBackoff(kern.UTIL_Retry.newContext(1));

	Assert.isTrue(b63fJit0 >= 10,
			'63f: jitter=true count=0 must be >= 10 (base). Got: ' + b63fJit0
	);
	Assert.isTrue(b63fJit0 <= 12,
			'63f: jitter=true count=0 must be <= 12 (+25% of 10 = +2.5 → max 12). Got: ' + b63fJit0
	);
	Assert.isTrue(b63fJit1 >= 20,
			'63f: jitter=true count=1 must be >= 20 (base 10*2^1). Got: ' + b63fJit1
	);
	Assert.isTrue(b63fJit1 <= 25,
			'63f: jitter=true count=1 must be <= 25 (+25% of 20 = +5 → max 25). Got: ' + b63fJit1
	);

	System.debug(LoggingLevel.INFO,
			'63f PASS: Deterministic backoff (jitter=false). '
			+ 'Exp(base=10,mult=2): 0→' + b63fExp0 + ', 1→' + b63fExp1
			+ ', 2→' + b63fExp2 + ', 3→' + b63fExp3 + '. '
			+ 'Linear(base=15): 1→' + b63fLin1 + ', 2→' + b63fLin2 + '. '
			+ 'Exp(base=5,mult=3): 0→' + b63fCust0 + ', 1→' + b63fCust1 + ', 2→' + b63fCust2 + '. '
			+ 'Jitter=true ranges: [' + b63fJit0 + '] in [10,12], [' + b63fJit1 + '] in [20,25].'
	);
	pass++;
}
catch(Exception scenarioError)
{
	System.debug(LoggingLevel.ERROR,
			'63f FAIL: ' + scenarioError.getMessage() + '\n' + scenarioError.getStackTraceString()
	);
	failures.add('63f: ' + scenarioError.getMessage());
	fail++;
}

// Cleanup
kern.UTIL_CircuitBreaker.monitor(CIRCUIT_HALF_OPEN).reset();
kern.UTIL_CircuitBreaker.monitor(CIRCUIT_COMBO).reset();
kern.UTIL_CircuitBreaker.monitor(CIRCUIT_EXEC).reset();

delete
[
		SELECT Id
		FROM kern__ApiIssue__c
		WHERE kern__ServiceName__c = :SERVICE_NAME
		AND CreatedDate = TODAY
		AND CreatedById = :UserInfo.getUserId()
		LIMIT 500
];
delete
[
		SELECT Id
		FROM kern__ApiCall__c
		WHERE kern__ServiceName__c = :SERVICE_NAME
		AND CreatedDate = TODAY
		AND CreatedById = :UserInfo.getUserId()
		LIMIT 500
];
// Log entries are written from a platform event after this transaction ends, so the ones this run
// emits are deleted by section-63-edge-resilience-comp-cleanup.apex, run 30 seconds later; the ones
// already written (an earlier run's) are deleted here: the handler's, and the breakers' (S63_ ids). The Automated Process
// user writes them, so they are not filtered by creator.
final String LOG_PATTERN = '%' + SERVICE_NAME + '%';
final String CIRCUIT_LOG_PATTERN = '%S63_%';
delete
[
		SELECT Id
		FROM kern__LogEntry__c
		WHERE (kern__ClassMethod__c LIKE :LOG_PATTERN OR kern__ShortMessage__c LIKE :CIRCUIT_LOG_PATTERN)
		AND CreatedDate = TODAY
		LIMIT 500
];
Integer callsLeft = [SELECT COUNT() FROM kern__ApiCall__c WHERE kern__ServiceName__c = :SERVICE_NAME AND CreatedDate = TODAY AND CreatedById = :UserInfo.getUserId()];
Integer issuesLeft = [SELECT COUNT() FROM kern__ApiIssue__c WHERE kern__ServiceName__c = :SERVICE_NAME AND CreatedDate = TODAY AND CreatedById = :UserInfo.getUserId()];
if(callsLeft + issuesLeft == 0)
{
	System.debug(LoggingLevel.INFO, '63-cleanup PASS: no API_EchoSubscriber call or issue of today is left; '
			+ 'run section-63-edge-resilience-comp-cleanup.apex in 30 seconds for the log entries');
}
else
{
	System.debug(LoggingLevel.ERROR, '63-cleanup FAIL: left behind: ' + callsLeft + ' calls, ' + issuesLeft + ' issues');
	failures.add('63-cleanup: left behind ' + callsLeft + ' calls, ' + issuesLeft + ' issues');
	fail++;
}

kern.API_MockFactory.clearMocks();
kern.TRG_Base.clearAllBypasses();

System.debug(LoggingLevel.INFO, '');
System.debug(LoggingLevel.INFO, 'Section 63: ' + pass + ' passed, ' + fail + ' failed');
if(fail > 0)
{
	System.debug(LoggingLevel.ERROR, '=== Section 63 FAILED ===');
	for(String message : failures)
	{
		System.debug(LoggingLevel.ERROR, '  - ' + message);
	}
	throw new System.AssertException('Section 63 failed: ' + fail + ' scenarios');
}
else
{
	System.debug(LoggingLevel.INFO, '=== Section 63 COMPLETE: All scenarios passed ===');
}
