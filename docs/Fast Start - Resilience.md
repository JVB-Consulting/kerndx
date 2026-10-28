---
navOrder: 62
---

# Fast Start - Resilience

**Framework:** KernDX | **Total time:** ~25 minutes

**What this is:** A way to keep an integration working when the system it calls has a bad moment. You get two tools: automatic retries (try a failed call again after a short, growing wait) and a circuit breaker (after repeated failures the framework stops calling a failing system for a cool-off, then resumes). **Why it matters:** A single timeout or a five-minute outage in someone else's service should not break your org or waste callouts. **Who should follow it:** developers wiring up callouts, plus tech leads who want consistent failure handling. **When to use it:** any time your code calls an external service that can be slow or temporarily down.

> **Namespaces in code samples:** `kern.` on a class and `kern__` on an object, field, or metadata type mark the managed package's namespace.
> On the managed package, framework references need those prefixes even where a sample omits them; repackaged under your own namespace, replace `kern`/`kern__`
> with your prefix; on an unmanaged deploy, drop them. See [How to read the code samples](Installation.md#how-to-read-the-code-samples).

**What you'll build:** A service whose one callout retries transient failures with exponential backoff and
guards the dependency with a circuit breaker. All of this is wired into the framework's HTTP client, with no
hand-rolled retry loop. You inspect the response it hands back, and the framework records the retry history for you.

**Success looks like:** A single resilient callout that retries a transient failure, opens a circuit breaker
on a sustained outage, and hands you back the response to inspect. The transient failure surfaces on the
response: it is never thrown at you. The retry history lands on the matching `ApiCall__c` record
(**App Launcher > Kern > API Calls**), and circuit-breaker state transitions show in
**App Launcher > Kern > Log Entries**. Your test class passes with 100% coverage.

**In one line:** `kern.UTIL_HttpClient.post('PaymentGateway', '/charges').body(request).withRetry(3).withCircuitBreaker().send();`
gives you retry, backoff, and a circuit breaker, with no boilerplate.

## Before you start

Open your terminal in your project's top folder, the one that holds `sfdx-project.json`; on Windows that terminal is
Command Prompt. Run the four-line check on [Set Up Your Computer](Set%20Up%20Your%20Computer.md#check-you-are-ready)
once: it proves your terminal, the CLI, your login and the KernDX package, and answers what goes wrong. Done that
today? Carry on. Work in a sandbox or a scratch org, never production. Every command below writes `YourOrgAlias`
where your org's alias goes: the name you gave it when you logged in.

---

## Table of Contents

<details>
<summary>Expand</summary>

1. [Before you start](#before-you-start)
2. [When to reach for each tool](#when-to-reach-for-each-tool)
3. [Tier 1: See It Work (~2 minutes)](#tier-1-see-it-work-2-minutes)
    - [Retry built into a callout](#retry-built-into-a-callout)
    - [A retry strategy you can inspect](#a-retry-strategy-you-can-inspect)
    - [A circuit breaker in three lines](#a-circuit-breaker-in-three-lines)
4. [Tier 2: Build Your Own (~15 minutes)](#tier-2-build-your-own-15-minutes)
    - [Step 1: Make a resilient callout](#step-1-make-a-resilient-callout)
    - [Step 2: Try the callout](#step-2-try-the-callout)
    - [Step 3: Write and run the test](#step-3-write-and-run-the-test)
        - [Key Patterns](#key-patterns)
5. [Tier 3: Production Patterns (~5-10 minutes)](#tier-3-production-patterns-5-10-minutes)
    - [Exponential vs linear backoff](#exponential-vs-linear-backoff)
    - [Jitter: avoid the thundering herd](#jitter-avoid-the-thundering-herd)
    - [Only retry the errors worth retrying](#only-retry-the-errors-worth-retrying)
    - [Circuit breaker states and recovery](#circuit-breaker-states-and-recovery)
    - [The execute() helper](#the-execute-helper)
    - [Reading circuit breaker metrics](#reading-circuit-breaker-metrics)
    - [Declarative resilience on a registered handler](#declarative-resilience-on-a-registered-handler)
    - [Clean up](#clean-up)
6. [Common Issues](#common-issues)
    - [Step 1: Make a resilient callout](#step-1-make-a-resilient-callout-1)
    - [Step 2: Try the callout](#step-2-try-the-callout-1)
    - [Step 3: Write and run the test](#step-3-write-and-run-the-test-1)
    - [Tier 3: Production Patterns (~5-10 minutes)](#tier-3-production-patterns-5-10-minutes-1)
7. [Honest limits](#honest-limits)
8. [What You Now Know](#what-you-now-know)
9. [Next Steps](#next-steps)

</details>

---

## When to reach for each tool

Retry and circuit breaker solve different problems. Most real integrations use both together. If your callout almost never fails and a rare error is fine to let through, a plain callout is simpler and you may not need either: add resilience once the dependency starts costing you timeouts or wasted callouts.

| Tool                   | Problem it solves                                                    | Use when                                                       |
|------------------------|----------------------------------------------------------------------|----------------------------------------------------------------|
| **Retry with backoff** | A single call fails *transiently* (timeout, 503, brief network blip) | The failure is likely to clear on its own within seconds       |
| **Circuit breaker**    | A dependency is *down*, so every call is wasted effort               | You want to stop calling a failing service and recover cleanly |

A retry says "try again, the blip will pass." A circuit breaker says "this service is clearly broken, so stop
calling it for a while and we won't waste callouts and pile up timeouts." Put simply: retry handles the bad second,
and the circuit breaker handles the bad five minutes.

---

## Tier 1: See It Work (~2 minutes)

Run these blocks in **Execute Anonymous** (Developer Console or VS Code) to see resilience in action. The
fastest path is the built-in HTTP client, which has retry and circuit breaker baked in.

### Retry built into a callout

[`UTIL_HttpClient`](reference/apex/UTIL_HttpClient.md) wires retry and circuit breaker straight into a
callout. The package ships **Example REST API** (`kern__API_ExampleRestApi`) pointing to
[JSONPlaceholder](https://jsonplaceholder.typicode.com), a free, public fake API that needs no keys.

**In Salesforce**, open the Developer Console (the gear icon, then Developer Console), then Debug, then Open Execute
Anonymous Window, and run:

```apex
HttpResponse response = kern.UTIL_HttpClient.post('kern__API_ExampleRestApi', '/posts')
		.body(new Map<String, Object> {'title' => 'Test', 'body' => 'Testing', 'userId' => 1})
		.withRetry(3)
		.withCircuitBreaker()
		.onFailure(kern.UTIL_HttpClient.FailureAction.RETRY_THEN_LOG)
		.send();

System.debug('Status: ' + response.getStatusCode());
```

You should see `Status: 201` in the log.

`.withRetry(3)` sends the request again, up to three times, when the answer says the other system did not
handle it (a 408 or 503), `.withCircuitBreaker()` opens the circuit after repeated failures, and
`.onFailure(...)` decides what happens once retries are exhausted. No custom classes. Because this is a POST
with no `Idempotency-Key`, a 500, 502 or 504, or no answer at all, is not sent again: the other system may
already have created the post, so the call ends `Failed` and its record says so. A GET, PUT or DELETE is also
sent again after a 500, 502 or 504. See
[Failures and retries](Web%20Services%20-%20Guide.md#failures-and-retries) in the Web Services Guide. For the full set of
builder options, see [Fast Start - Outbound APIs](Fast%20Start%20-%20Outbound%20APIs.md).

### A retry strategy you can inspect

Sometimes you're driving your own loop rather than a framework callout. For that, use
[`UTIL_Retry`](reference/apex/UTIL_Retry.md) directly. It separates the *strategy* (how long to wait, how
many times) from the *context* (which attempt you're on).

**In Salesforce**, in the same Execute Anonymous window, run:

```apex
kern.UTIL_Retry.Strategy strategy = kern.UTIL_Retry.exponential();

for(Integer attempt = 0; attempt < 4; attempt++)
{
	kern.UTIL_Retry.Context context = kern.UTIL_Retry.newContext(attempt);

	System.debug('Attempt ' + attempt
			+ ' — shouldRetry: ' + strategy.shouldRetry(context)
			+ ', backoff: ' + strategy.calculateBackoff(context) + 's');
}
```

You should see these lines in the log (exponential, defaults: max 3 retries, base 10s):

```text
Attempt 0 — shouldRetry: true, backoff: 10s
Attempt 1 — shouldRetry: true, backoff: 20s
Attempt 2 — shouldRetry: true, backoff: 40s
Attempt 3 — shouldRetry: false, backoff: 80s
```

`shouldRetry` returns `false` once the attempt count reaches the max (3 by default), so attempt 3 is where
you stop. The backoff doubles each attempt: 10 → 20 → 40.

### A circuit breaker in three lines

[`UTIL_CircuitBreaker`](reference/apex/UTIL_CircuitBreaker.md) tracks failures per named dependency and
fails fast once that dependency looks broken.

**In Salesforce**, in the same Execute Anonymous window, run:

```apex
kern.UTIL_CircuitBreaker.Breaker breaker = kern.UTIL_CircuitBreaker.monitor('PaymentGateway');

System.debug('State: ' + breaker.getState()); // CLOSED — calls allowed
System.debug('Allowed: ' + breaker.allowRequest()); // true
```

You should see `State: CLOSED` and `Allowed: true` in the log.

A new breaker starts **CLOSED** (calls flow through). Record enough failures and it flips to **OPEN**
(calls fail fast). After a timeout it moves to **HALF_OPEN** to test recovery. The state lives in Platform
Cache, so it is shared across transactions and users: one user's failures protect everyone.

> **When to move to Tier 2:** When you want to wrap your *own* callout in a retry loop and guard it with a
> circuit breaker inside a real service class, with test coverage.

---

## Tier 2: Build Your Own (~15 minutes)

> **No local project?** You can create classes directly in the Developer Console (Gear Icon > Developer
> Console > File > New > Apex Class) and run tests from there too (Test > New Run). Paste the code, save,
> and skip the terminal commands.

We'll build a service that makes one callout to a flaky dependency. Retry-with-backoff and a circuit
breaker are wired straight into the framework's HTTP client, so there's no hand-rolled loop. The framework
retries transient failures, guards the dependency, logs every attempt, and hands you back the response.

### Step 1: Make a resilient callout

The framework's [`UTIL_HttpClient`](reference/apex/UTIL_HttpClient.md) builds resilience into the call itself.
You chain the behaviours you want and call `send()`, and it returns an `HttpResponse` you interrogate. A transient
failure (a 5xx) surfaces on that response: it is **never thrown at you**. So there is no `try/catch` and no
retry loop to write. You create an empty class with one command, paste the code into it, then send it to your org.

**1. In the terminal**, from your project's top folder, create the empty class:

```shell
sf apex generate class --name SVC_ResilientSync --output-dir force-app/main/default/classes
```

You should see two files created in `force-app/main/default/classes`, both named `SVC_ResilientSync`: the class,
ending in `.cls`, and its companion, ending in `.cls-meta.xml`.

The second file tells Salesforce which API version the class uses. You never edit it, but a deploy fails without it.

**2. In your editor**, open this file, delete what is there, paste the code below in, and save:

```text
force-app/main/default/classes/SVC_ResilientSync.cls
```

```apex
/**
 * @description Calls a flaky dependency the resilient way: retry, backoff, and a circuit breaker
 * are wired straight into the framework's HTTP client. The framework retries transient failures,
 * logs every attempt, and hands you back the response to inspect — it never throws the transient
 * failure at you.
 *
 * @see SVC_ResilientSync_TEST
 *
 * @author your.name@company.com
 *
 * @group Resilience
 *
 * @date February 2026, October 2026
 */
public with sharing class SVC_ResilientSync
{
	/** @description Named Credential / API name the callout targets. */
	@TestVisible
	private static final String SERVICE_NAME = 'kern__API_ExampleRestApi';

	/** @description Endpoint path appended to the Named Credential. */
	@TestVisible
	private static final String ENDPOINT_PATH = '/posts/1';

	/**
	 * @description Calls the dependency with retry, exponential backoff, and a circuit breaker baked
	 * in. The framework retries a 408, 500, 502, 503 or 504, opens the circuit on a sustained outage, and
	 * records each attempt on the ApiCall__c log record.
	 *
	 * @return The HttpResponse — inspect getStatusCode() and getBody(); the retry history is on the
	 * matching ApiCall__c record.
	 */
	public HttpResponse fetchWithRetry()
	{
		return kern.UTIL_HttpClient.get(SERVICE_NAME, ENDPOINT_PATH)
				.withExponentialBackoff(3, 2)
				.withCircuitBreaker()
				.onFailure(kern.UTIL_HttpClient.FailureAction.RETRY_THEN_LOG)
				.send();
	}
}
```

**What this code does:**

- `kern.UTIL_HttpClient.get(SERVICE_NAME, ENDPOINT_PATH)` starts a GET against the named API. (`post`, `put`,
  `patch`, and `del` start the other verbs.)
- `.withExponentialBackoff(3, 2)` retries a transient failure up to 3 times, with the backoff growing
  exponentially from a 2-second base. The framework runs the retries for you, so you never write the loop.
  Because this is a GET, which is safe to send twice, an answer of 408, 500, 502, 503 or 504 is sent again
  straight away; a 425 or 429 (slow down) and a call that got no answer at all wait for the scheduled retry.
  (Apex can't pause a thread, so the synchronous retries fire back-to-back. The backoff seconds set the
  cadence for the framework's *scheduled* retries on a registered handler: see [Honest limits](#honest-limits)
  and [Declarative resilience](#declarative-resilience-on-a-registered-handler).)
- `.withCircuitBreaker()` guards the dependency with a circuit breaker keyed to the credential name, so a
  sustained outage trips the circuit and stops wasting callouts. Every call on the same credential shares
  that one circuit. To choose the circuit yourself, give it a name: `.withCircuitBreaker('PaymentGateway')`.
  Calls with the same name share one circuit whatever credential they use, and calls with different names
  keep separate circuits even on one credential. A call the open circuit refused names that circuit in its
  error line.
- `.onFailure(kern.UTIL_HttpClient.FailureAction.RETRY_THEN_LOG)` retries first, then logs a failure record
  once retries are exhausted. (`LOG_FAILURE` logs without retrying.)
- `.send()` returns an `HttpResponse`. On a transient failure the response carries the failing status code
  (e.g. 503), it is never thrown, and the framework records the call, including the retry count, on a
  matching `ApiCall__c` record you can read in **App Launcher > Kern > API Calls**.

**3. In the terminal**, send the class to your org:

```shell
sf project deploy start -o YourOrgAlias -m "ApexClass:SVC_ResilientSync"
```

You should see `Status: Succeeded`, with `SVC_ResilientSync` listed as created.

Something went wrong? See [Common Issues, Step 1](#step-1-make-a-resilient-callout-1).

### Step 2: Try the callout

Call the service once and read what it hands back.

**In Salesforce**, in the Developer Console's Execute Anonymous window, run:

```apex
HttpResponse response = new SVC_ResilientSync().fetchWithRetry();
System.debug('Status: ' + response.getStatusCode());
System.debug('Body: ' + response.getBody());
System.debug('Done — check App Launcher > Kern > API Calls for the logged call');
```

You should see `Status: 200` in the log, then the `Body:` line with the post the API returned, and the `Done` line.

Against the live Example REST API the call succeeds on the first attempt (status 200), so the matching
`ApiCall__c` record shows no retries. To watch the retry path (a transient failure surfacing on the response
with the retry count on the log), the test class in Step 3 forces a 503.

Something went wrong? See [Common Issues, Step 2](#step-2-try-the-callout-1).

### Step 3: Write and run the test

This test forces a transient 503 and proves the framework's promise: the failure surfaces on the response
(it is never thrown), and the retry count lands on the `ApiCall__c` log. A second test confirms a healthy
call hands back its body. Both use `kern.API_MockFactory` to stand in for the live dependency, so no real
callout fires.

> **Why this pattern, not a `try/catch`?** Because `send()` doesn't throw the transient failure: it returns
> it on the response. You assert on `getStatusCode()`, then read the logged `ApiCall__c` record to confirm
> the framework retried. This is exactly how the framework's own resilience tests work.

You create the empty class with one command, paste the code into it, send it to your org, then run it.

**1. In the terminal**, from your project's top folder, create the empty test class:

```shell
sf apex generate class --name SVC_ResilientSync_TEST --output-dir force-app/main/default/classes
```

You should see two files created in `force-app/main/default/classes`, both named `SVC_ResilientSync_TEST`: the
class, ending in `.cls`, and its companion, ending in `.cls-meta.xml`.

**2. In your editor**, open this file, delete what is there, paste the code below in, and save:

```text
force-app/main/default/classes/SVC_ResilientSync_TEST.cls
```

```apex
/**
 * @description Unit tests for SVC_ResilientSync.
 *
 * @see SVC_ResilientSync
 *
 * @author your.name@company.com
 *
 * @group Resilience
 *
 * @date February 2026, October 2026
 */
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest(seeAllData=false isParallel=true)
private class SVC_ResilientSync_TEST
{
	/** @description A transient (503) failure is retried, then surfaces on the response + ApiCall log. */
	@IsTest
	private static void shouldRetryThenSurfaceTransientFailure()
	{
		kern.LOG_Builder.ignoreTestMode = true;
		kern.UTIL_CircuitBreaker.monitor(SVC_ResilientSync.SERVICE_NAME).reset();
		kern.API_MockFactory.forService(SVC_ResilientSync.SERVICE_NAME)
				.body('{"error":"service unavailable"}')
				.statusCode(503)
				.register();

		Test.startTest();
		HttpResponse response = new SVC_ResilientSync().fetchWithRetry();
		Test.stopTest();

		Assert.areEqual(503, response.getStatusCode(),
				'The transient failure surfaces on the response — it is never thrown at you');

		List<kern__ApiCall__c> calls =
		[
				SELECT kern__StatusCode__c, kern__Retries__c, kern__MaxRetries__c
				FROM kern__ApiCall__c
				ORDER BY CreatedDate DESC
				LIMIT 1
		];
		Assert.isFalse(calls.isEmpty(), 'The framework logs every callout as an ApiCall record');
		Assert.areEqual('503', calls[0].kern__StatusCode__c, 'The logged call records the failure status');
	}

	/** @description A healthy dependency hands back its body on the first attempt. */
	@IsTest
	private static void shouldReturnBodyOnSuccess()
	{
		kern.UTIL_CircuitBreaker.monitor(SVC_ResilientSync.SERVICE_NAME).reset();
		kern.API_MockFactory.forService(SVC_ResilientSync.SERVICE_NAME)
				.body('{"id":1,"title":"ok"}')
				.statusCode(200)
				.register();

		Test.startTest();
		HttpResponse response = new SVC_ResilientSync().fetchWithRetry();
		Test.stopTest();

		Assert.areEqual(200, response.getStatusCode(), 'A healthy call returns 200');
		Assert.isTrue(response.getBody().contains('"title":"ok"'), 'The body comes back for inspection');
	}
}
```

> **About the annotations:** `@IsTest(seeAllData=false isParallel=true)` keeps the tests isolated and lets
> them run in parallel. `@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')` quiets a code-analysis
> rule. In production tests, consider wrapping logic in `System.runAs(testUser)` to verify profile and
> permission-set access.

> **What the test pattern shows:**
> - `kern.API_MockFactory.forService(...).statusCode(503).register()` makes the framework return a 503
>   instead of calling the live API. This is the standard way to force a failure for a callout test.
> - `kern.UTIL_CircuitBreaker.monitor(...).reset()` clears any circuit state an earlier test left in Platform
>   Cache, so each method starts from a known-CLOSED breaker.
> - `kern.LOG_Builder.ignoreTestMode = true` lets logging run in test context so the call is fully exercised.
>   See [Fast Start - Logging](Fast%20Start%20-%20Logging.md).

**3. In the terminal**, send the test class to your org:

```shell
sf project deploy start -o YourOrgAlias -m "ApexClass:SVC_ResilientSync_TEST"
```

You should see `Status: Succeeded`, with `SVC_ResilientSync_TEST` listed as created.

**4. In the terminal**, run the test:

```shell
sf apex run test -o YourOrgAlias -t SVC_ResilientSync_TEST --code-coverage --synchronous --result-format human
```

You should see 2 tests passing and full coverage on `SVC_ResilientSync`: both tests show `Pass`, the summary line
`Outcome` reads `Passed`, and the coverage table shows `SVC_ResilientSync` at `100%`.

Something went wrong? See [Common Issues, Step 3](#step-3-write-and-run-the-test-1).

#### Key Patterns

| Pattern                  | Example                                  | Why                                                    |
|--------------------------|------------------------------------------|--------------------------------------------------------|
| Let the client retry     | `.withExponentialBackoff(3, 2)`          | The framework retries transient failures, with no loop |
| Guard the dependency     | `.withCircuitBreaker()`                  | A sustained outage trips the circuit, sparing callouts |
| Pick the failure action  | `.onFailure(...RETRY_THEN_LOG)`          | Retry, then log a failure record once retries run out  |
| Interrogate the response | `response.getStatusCode()`               | The failure surfaces here; it is never thrown          |
| Read the retry history   | `ApiCall__c.Retries__c`                  | The framework logs every call and its retries          |
| Force failures in tests  | `kern.API_MockFactory...statusCode(503)` | Prove the retry path without the live dependency       |

---

## Tier 3: Production Patterns (~5-10 minutes)

### Exponential vs linear backoff

`UTIL_Retry` ships two backoff shapes. Both default to 3 max retries and a 10-second base, and both cap at
300 seconds.

| Factory                    | Wait at attempt 0, 1, 2 (base 10s)  | Use when                                            |
|----------------------------|-------------------------------------|-----------------------------------------------------|
| `UTIL_Retry.exponential()` | 10s, 20s, 40s (doubles)             | Default choice: backs off hard as failures persist  |
| `UTIL_Retry.linear()`      | 10s, 10s, 20s (multiplies by count) | A steady, predictable cadence                       |

**In your editor**, in your own class:

```apex
// Exponential: 10 → 20 → 40 → 80 ...
kern.UTIL_Retry.Strategy fast = kern.UTIL_Retry.exponential();

// Linear: base * attempt count
kern.UTIL_Retry.Strategy steady = kern.UTIL_Retry.linear();
```

Tune any strategy with short chained calls: `.withMaxRetries(n)`, `.withBaseBackoff(seconds)`,
`.withMaximumBackoff(seconds)` (the cap), and, for exponential, `.withExponentialMultiplier(decimal)` to
grow faster or slower than doubling.

**In your editor**, in your own class:

```apex
kern.UTIL_Retry.Strategy strategy = kern.UTIL_Retry.exponential()
		.withMaxRetries(5)
		.withBaseBackoff(5)
		.withMaximumBackoff(120)
		.withExponentialMultiplier(3.0);
```

### Jitter: avoid the thundering herd

When many transactions fail at the same moment (a dependency hiccup), they'd all retry at the same instant
without jitter, slamming the recovering service in lockstep. `.withJitter(true)` adds up to 25% randomness
to each backoff so retries spread out.

**In your editor**, in your own class:

```apex
kern.UTIL_Retry.Strategy strategy = kern.UTIL_Retry.exponential()
		.withBaseBackoff(10)
		.withJitter(true);
// Backoff at attempt 1 lands somewhere in 20..25 (20 base + up to 25%)
```

### Only retry the errors worth retrying

Some failures will never clear by retrying: a bad request, an authentication error, an invalid argument.
Retrying those just wastes attempts. Wrap a strategy to filter by exception type.

**In your editor**, in your own class:

```apex
// NEVER retry these — they won't recover via retry (denylist)
kern.UTIL_Retry.Strategy denylisted = kern.UTIL_Retry.dontRetryOnException(
		kern.UTIL_Retry.exponential().withMaxRetries(5),
		new Set<Type> {System.IllegalArgumentException.class}
);

// ONLY retry these transient errors (allowlist)
kern.UTIL_Retry.Strategy allowlisted = kern.UTIL_Retry.retryOnlyOnException(
		kern.UTIL_Retry.exponential().withMaxRetries(5),
		new Set<Type> {System.CalloutException.class}
);
```

Pass the caught exception through the context so the filter can see it.

**In your editor**, in the catch block that caught the exception:

```apex
kern.UTIL_Retry.Context context = kern.UTIL_Retry.newContext(0).withCustomData(caughtException);
Boolean retry = denylisted.shouldRetry(context);
```

> **Exact-type matching, not subclasses.** The filter matches by **exact exception type name**, so
> denylisting `Exception.class` does *not* catch its concrete subclasses. List each concrete type you care
> about explicitly. A context with no exception in its custom data falls through to the base strategy and
> retries normally.

Inside an `API_Outbound` handler you do not build the context yourself: the framework passes the caught
exception for you. So a `createRetryStrategy()` override that returns `dontRetryOnException(...)` or
`retryOnlyOnException(...)` filters exception failures. A failure the external system answered with a status
carries no exception, so the filter never sees it; which statuses retry is decided by the handler's
`getRetryableStatusCodes()`.

### Circuit breaker states and recovery

A breaker moves through three states automatically:

| State         | Behaviour                                          | Transitions out                                           |
|---------------|----------------------------------------------------|-----------------------------------------------------------|
| **CLOSED**    | Normal: calls pass through                         | → OPEN when failures reach the failure threshold          |
| **OPEN**      | Fails fast: `allowRequest()` returns `false`       | → HALF_OPEN after the timeout elapses                     |
| **HALF_OPEN** | Tests recovery: a limited number of calls allowed  | → CLOSED after enough successes, or → OPEN on any failure |

The defaults: failure threshold 5, timeout 60 seconds, success threshold 2 (consecutive successes to close
from HALF_OPEN), and up to 3 trial calls in HALF_OPEN. Tune them with short chained calls.

**In your editor**, in your own class:

```apex
kern.UTIL_CircuitBreaker.Breaker breaker = kern.UTIL_CircuitBreaker.monitor('PaymentGateway')
		.withFailureThreshold(10)
		.withTimeout(120)
		.withSuccessThreshold(3)
		.withHalfOpenMaxAttempts(5);
```

Every state transition writes a log entry, so you can watch a circuit open and recover in
**App Launcher > Kern > Log Entries**. `reset()` forces it back to CLOSED and `forceOpen()` forces it OPEN.
Both are manual overrides, so use them sparingly: for example, an admin "kill switch" (a master off-switch
you can flip in an incident without a deployment) or a recovery script.

### The execute() helper

Instead of hand-writing the `allowRequest()` / try / `recordSuccess()` / catch / `recordFailure()` dance,
implement `ProtectedAction` (no return value) or `Provider` (returns a value) and let `execute()` do it.

**In your editor**, in a new class:

```apex
public class ChargeAction implements kern.UTIL_CircuitBreaker.Provider
{
	private final Map<String, Object> request;

	public ChargeAction(Map<String, Object> request)
	{
		this.request = request;
	}

	public Object execute()
	{
		return kern.UTIL_HttpClient.post('PaymentGateway', '/charges').body(request).send();
	}
}
```

**In your editor**, in the code that makes the charge:

```apex
kern.UTIL_CircuitBreaker.Breaker breaker = kern.UTIL_CircuitBreaker.monitor('PaymentGateway');

try
{
	HttpResponse response = (HttpResponse)breaker.execute(new ChargeAction(request));
	System.debug('Charged: ' + response.getStatusCode());
}
catch(kern.UTIL_CircuitBreaker.OpenException openError)
{
	// Circuit is OPEN — handle gracefully (queue for later, surface a friendly message, etc.)
	kern.LOG_Builder.build().error(openError).emitAt('MyClass.charge');
}
```

`execute()` checks `allowRequest()` first and throws `OpenException` if the circuit is open; otherwise it
runs your action, records success, and on any thrown exception records the failure and re-throws so the
caller still knows the call failed.

> **Surfacing the open-circuit message to a user.** If a circuit-open outcome reaches the UI (a toast, an
> inline error, an LWC message), pull that text from a Custom Label, never a hardcoded string. In Apex,
> `throw new AuraHandledException(System.Label.Service_Temporarily_Unavailable);`. In an LWC, import it with
> `import message from '@salesforce/label/c.Service_Temporarily_Unavailable';`. That keeps the copy
> translatable and overridable. See [Fast Start - Logging](Fast%20Start%20-%20Logging.md) for the LWC logging side.
>
> **`Service_Temporarily_Unavailable` is illustrative.** The framework does not ship this Custom Label.
> Create your own label (any name) in your org and reference it the same way so the examples compile.

### Reading circuit breaker metrics

`getMetrics()` returns a snapshot for dashboards, health checks, or alerting.

**In your editor**, in your own class:

```apex
kern.UTIL_CircuitBreaker.Metrics metrics = kern.UTIL_CircuitBreaker.monitor('PaymentGateway').getMetrics();

System.debug('Circuit: ' + metrics.circuitId);
System.debug('State: ' + metrics.state);
System.debug('Failures: ' + metrics.failureCount);
System.debug('Consecutive successes: ' + metrics.consecutiveSuccesses);
System.debug('Last failure: ' + metrics.lastFailureTime);
System.debug('State changed: ' + metrics.stateChangedTime);
```

### Declarative resilience on a registered handler

If you've built a registered `API_Outbound` handler (see [Fast Start - Outbound APIs](Fast%20Start%20-%20Outbound%20APIs.md)),
you don't write retry or breaker code at all: you configure it on the handler's `ApiSetting__mdt` record:

| ApiSetting field                    | What it controls                              |
|-------------------------------------|-----------------------------------------------|
| `MaxRetryCount__c`                  | Maximum retry attempts                        |
| `RetryBackoffSeconds__c`            | Backoff seconds between retries               |
| `CircuitBreakerEnabled__c`          | Turns the circuit breaker on for this service |
| `CircuitBreakerFailureThreshold__c` | Failures before the circuit opens             |
| `CircuitBreakerTimeout__c`          | Seconds OPEN before testing recovery          |
| `CircuitBreakerSuccessThreshold__c` | Consecutive successes needed to close         |

The framework ships a record-triggered flow that processes scheduled retries automatically, with no custom
scheduled jobs or platform events needed. It schedules a retry only for a failure that sending the request again
could fix: see [Failures and retries](Web%20Services%20-%20Guide.md#failures-and-retries). The builder methods on `UTIL_HttpClient`
(`.withRetry(n)`, `.withRetry(n, backoff)`, `.withCircuitBreaker()`) override these per call. See the
[Resilience - Guide](Resilience%20-%20Guide.md) and [Web Services - Guide](Web%20Services%20-%20Guide.md)
for the full configuration reference.

### Clean up

If you built this example only to try the framework, run this command when you have finished the guide. The API Call
records the callouts wrote stay; delete them in the app, or leave them.

**In the terminal**, delete the two classes:

```shell
sf project delete source -o YourOrgAlias -m "ApexClass:SVC_ResilientSync_TEST" -m "ApexClass:SVC_ResilientSync" --no-prompt
```

You should see `Status: Succeeded`, then a `Deleted Source` table listing the two classes. The command deletes the
files from your project too.

Something went wrong? See [Common Issues](#common-issues).

---

## Common Issues

Trouble with your computer rather than this guide (`sf` is not recognised, scripts are disabled, you are not logged
in, the wrong folder)? Those are answered once, in
[Set Up Your Computer](Set%20Up%20Your%20Computer.md#if-something-went-wrong).

### Step 1: Make a resilient callout

#### The deploy says there is nothing to deploy

The deploy stops with `No source-backed components present in the package.` The command ran inside another project's
folder, so the CLI looked for the class there and found nothing. Open the terminal in your own project's top folder,
the one that holds `sfdx-project.json`, and run the command again.

### Step 2: Try the callout

#### `send()` returns a 5xx status and nothing is thrown

This is by design: a transient failure surfaces on the response. Inspect `response.getStatusCode()`; the retry count is
on the matching `ApiCall__c` record.

### Step 3: Write and run the test

#### Log entries don't appear in your own tests

Logging is suppressed in test context. Set `kern.LOG_Builder.ignoreTestMode = true` before the call, as the first test
method in this step does.

### Tier 3: Production Patterns (~5-10 minutes)

#### Retry fires on errors that can't recover

The strategy has no exception filter. Wrap it with `dontRetryOnException(...)` / `retryOnlyOnException(...)` and pass
the exception in `withCustomData(...)`. Inside an `API_Outbound` handler the framework passes the exception for you,
so the wrapped strategy filters exception failures on its own. A failure the external system answered with a status
(a 400, say) carries no exception: the filter cannot stop it, and the handler's `getRetryableStatusCodes()` decides
whether it retries.

#### The exception filter doesn't match

It was matched against a parent type. The filter matches by **exact type name**, so list the concrete exception class.

#### The circuit never opens

The failures are not recorded. Call `recordFailure()` in the catch block (or use `execute()`).

#### The circuit resets every transaction

The Platform Cache partition is not provisioned. Provision the Library cache partition so breaker state persists
across transactions.

#### `OpenException` is thrown unexpectedly

The circuit is OPEN from earlier failures. This is expected: handle it (queue or retry later); the circuit moves to
HALF_OPEN after the timeout.

Still stuck? [Tell us](https://github.com/JVB-Consulting/kerndx/issues/new?template=bug_report.md&title=%5Bdocs%5D%20Resilience) which step and what you saw.

## Honest limits

Resilience tools manage *failure*, they don't erase it. Know these boundaries before you rely on them.

- **Retry decisions are synchronous; the wait is not "free" sleep.** `UTIL_Retry` tells you whether to
  retry and how long to wait, but it does not block the thread for you. For real backoff between callouts, the
  wait belongs in an asynchronous path. The framework's registered-handler retry schedules attempts for
  you; a hand-rolled synchronous loop should not busy-wait across the backoff.
- **Circuit breaker state lives in Platform Cache.** If a cache partition isn't provisioned, the breaker
  gracefully degrades to in-memory state that resets every transaction. That is fine for tests, but not for
  protecting a shared dependency in production. Provision the cache partition so state persists across
  transactions and users.
- **Exception filtering is exact-type, not polymorphic.** `dontRetryOnException` / `retryOnlyOnException`
  match by exact type name. They will not catch subclasses of a listed type. List concrete types.
- **A circuit breaker doesn't retry, and retry doesn't fail fast.** They are complementary, not
  interchangeable. Use retry for transient blips and a breaker for sustained outages; most production
  integrations layer both.
- **Backoff and thresholds are guesses until you measure.** The defaults are sensible starting points, not
  tuned values. Watch the state transitions in **Log Entries** and adjust thresholds and timeouts to your
  dependency's real behaviour.

---

## What You Now Know

| Concept                                                    | What it does                                                 |
|------------------------------------------------------------|--------------------------------------------------------------|
| `kern.UTIL_Retry.exponential()` / `.linear()`              | Builds a backoff strategy (doubling vs by-count)             |
| `kern.UTIL_Retry.newContext(attempt)`                      | Describes the current attempt for the strategy to evaluate   |
| `strategy.shouldRetry(context)`                            | Returns whether to retry; `false` once attempts hit the max  |
| `strategy.calculateBackoff(context)`                       | Returns the seconds to wait before the next attempt          |
| `.withMaxRetries / .withBaseBackoff / .withMaximumBackoff` | Tune attempt count and backoff floor/cap                     |
| `.withJitter(true)`                                        | Spreads retries out to avoid a thundering herd               |
| `dontRetryOnException / retryOnlyOnException`              | Filter which exception types are worth retrying (exact type) |
| `kern.UTIL_CircuitBreaker.monitor(id)`                     | Returns a per-dependency breaker backed by Platform Cache    |
| `breaker.allowRequest()`                                   | Gate the call; `false` means the circuit is OPEN (fail fast) |
| `breaker.recordSuccess() / recordFailure()`                | Feed outcomes so the breaker opens and recovers              |
| `breaker.execute(action)`                                  | One-call helper that gates, runs, and records automatically  |
| `breaker.getState() / getMetrics()`                        | Inspect the circuit state and failure/success counters       |
| `UTIL_CircuitBreaker.OpenException`                        | Thrown by `execute()` when the circuit is OPEN               |

**Key patterns:**

- Use retry for transient failures, a circuit breaker for sustained outages, and layer both
- Bound retries (`withMaxRetries`) and back off between them (`calculateBackoff`)
- Add jitter when many transactions may fail and retry at once
- Filter retries to exceptions that can actually recover
- Record every outcome into the breaker so it can open and recover on its own
- Wrap the whole sequence in `LOG_Builder.scope()` so it reads as one trace
- For registered `API_Outbound` handlers, configure resilience on `ApiSetting__mdt` instead of in code

---

## Next Steps

- [Resilience Developer Guide](Resilience%20-%20Guide.md)
- [Outbound API calls (retry built in)](Fast%20Start%20-%20Outbound%20APIs.md)
- [Correlated logging for traces](Fast%20Start%20-%20Logging.md)
- [Complete Web Services Guide](Web%20Services%20-%20Guide.md)
- [UTIL_Retry API Reference](reference/apex/UTIL_Retry.md)
- [UTIL_CircuitBreaker API Reference](reference/apex/UTIL_CircuitBreaker.md)
- [UTIL_HttpClient API Reference](reference/apex/UTIL_HttpClient.md)
