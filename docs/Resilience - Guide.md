---
navOrder: 62
---

# Resilience - Guide

**Framework:** KernDX
**Package Type:** Managed Package

**Target Audience:**

- **Developers** - Adding retry-with-backoff and circuit-breaker protection around callouts and other failure-prone operations
- **Architects** - Designing fault-tolerant integration patterns that degrade gracefully when external services slow down or go offline
- **Business Analysts** - Understanding how the framework absorbs transient failures and protects org resources during outages

---

## In one paragraph

Calls to outside systems fail in ways you don't control. A payment gateway times out, a rate limit kicks in, a CRM goes down for maintenance. When that happens, naive code either gives up too soon or keeps hammering a service that is already down, wasting your org's limited callout time and CPU. This framework gives you two ready-made tools for handling those failures gracefully, so you don't have to write your own timing math and failure-tracking logic. Developers use it to make individual callouts more reliable; architects use it to design integrations that stay healthy when a dependency slows or fails. Reach for it whenever your code calls a system you don't run yourself.

---

## Table of Contents

<details>
<summary>Expand</summary>

1. [Quick Navigation](#quick-navigation)
2. [Overview](#overview)
3. [Quick Start](#quick-start)
4. [How to opt out](#how-to-opt-out)
5. [Architecture](#architecture)
    - [Two Patterns, One Goal](#two-patterns-one-goal)
    - [How They Fit Together](#how-they-fit-together)
6. [Retry with Backoff (UTIL_Retry)](#retry-with-backoff-util_retry)
    - [Built-in Strategies](#built-in-strategies)
    - [Backoff Calculation](#backoff-calculation)
    - [Jitter](#jitter)
    - [Configuring a Strategy](#configuring-a-strategy)
    - [The Retry Context](#the-retry-context)
    - [Exception Allowlists and Denylists](#exception-allowlists-and-denylists)
    - [Custom Strategies](#custom-strategies)
    - [What UTIL_Retry Does Not Do](#what-util_retry-does-not-do)
7. [Circuit Breaker (UTIL_CircuitBreaker)](#circuit-breaker-util_circuitbreaker)
    - [The Three States](#the-three-states)
    - [State Transitions](#state-transitions)
    - [The execute() Helpers](#the-execute-helpers)
    - [Manual Gating](#manual-gating)
    - [Configuring a Breaker](#configuring-a-breaker)
    - [Inspecting State and Metrics](#inspecting-state-and-metrics)
    - [Platform Cache and Cross-Transaction State](#platform-cache-and-cross-transaction-state)
8. [Combining Retry and Circuit Breaker](#combining-retry-and-circuit-breaker)
9. [Use with the Web Services Framework](#use-with-the-web-services-framework)
    - [Configuration via ApiSetting](#configuration-via-apisetting)
    - [Overriding the Retry Strategy](#overriding-the-retry-strategy)
    - [Per-Call Overrides with UTIL_HttpClient](#per-call-overrides-with-util_httpclient)
10. [Capability Matrix (for Analysts)](#capability-matrix-for-analysts)
11. [Testing](#testing)
    - [Testing Retry Strategies](#testing-retry-strategies)
    - [Testing Circuit Breakers](#testing-circuit-breakers)
12. [Anti-Patterns](#anti-patterns)
13. [Best Practices](#best-practices)
14. [Related Documentation](#related-documentation)

</details>

---

## Quick Navigation

| I am a...     | I need to...                             | Go to...                                                                    |
|---------------|------------------------------------------|-----------------------------------------------------------------------------|
| **Architect** | Understand how the two patterns differ   | [Architecture](#architecture)                                               |
| **Architect** | Protect callouts from cascading failures | [Circuit Breaker](#circuit-breaker-util_circuitbreaker)                     |
| **Developer** | Add retry-with-backoff to an operation   | [Retry with Backoff](#retry-with-backoff-util_retry)                        |
| **Developer** | Wrap a callout in a circuit breaker      | [The execute() Helpers](#the-execute-helpers)                               |
| **Developer** | Wire resilience into the API framework   | [Use with the Web Services Framework](#use-with-the-web-services-framework) |
| **Analyst**   | Know what resilience is built in         | [Capability Matrix](#capability-matrix-for-analysts)                        |

---

## Overview

The two tools answer different questions:

1. **[`UTIL_Retry`](reference/apex/UTIL_Retry.md)** decides **when** to try again and **how long** to wait between attempts. It works out an exponential or linear backoff period (the growing pause between tries), optionally with a small random jitter, and tells you when to stop.
2. **[`UTIL_CircuitBreaker`](reference/apex/UTIL_CircuitBreaker.md)** decides **whether** to even attempt the call. After repeated failures it "opens" the circuit and rejects calls immediately, sparing your org the cost of waiting on a service that is already down. It tests for recovery again after a cool-off period.

**How it works under the hood:** both classes are part of the public API your org can call, and they live in the `Resilience` group. You start each one from a static factory method, configure it with short chained calls, and your code talks only to the published interface, never the internal implementation.

> **Managed Package Context:** These are `global` classes in a managed package. When calling them from your own org, use the `kern.` namespace prefix (for example,
`kern.UTIL_Retry.exponential()`). The examples below show the prefix where you would type it.

> **What these utilities do and don't do:** They decide timing and gating only. They do not perform the callout, query data, or hold business logic. You supply the operation, and they wrap it. In particular, `UTIL_Retry` does not sleep, schedule, or re-invoke anything by itself. It hands back a backoff period and a retry-or-stop decision, and your code acts on that.

> **When NOT to use these patterns:**
> - Operations that rarely fail (in-memory transforms, simple saves against your own objects)
> - One-off scripts where a single failure is acceptable and a manual re-run is fine
> - Callouts already routed through the [Web Services framework](Web%20Services%20-%20Guide.md), which applies both patterns automatically. Reach for these classes directly only when you are outside that pipeline, or when you want to customize its behavior.

**Key Benefits:**

- **Less code to write:** the backoff math, overflow protection, and the three-state circuit machine are handled for you.
- **Fail fast under outage:** an open circuit rejects calls immediately instead of burning callout time and CPU on a service that is down.
- **Memory that survives a transaction:** circuit state is kept in Platform Cache, so failures in one transaction protect the next.
- **Protection against a "thundering herd":** optional jitter spreads retries out, so many clients don't all retry at the same instant.
- **Stacks cleanly:** retry and circuit breaker work together, and both drop straight into the Web Services framework.
- **Easy to test:** the timing calculations and state transitions are predictable, so you can assert on them directly.

---

## Quick Start

You want to protect a callout (or any operation that might fail) so that, when the target service is down, your code stops trying instead of waiting on it. Wrap the operation in a circuit breaker and run it through `execute()`. That single call checks whether the request is allowed, runs your action, and records success or failure for you.

> **Step-by-step walkthrough:** [Fast Start - Resilience](Fast%20Start%20-%20Resilience.md) covers implementation, testing, and common pitfalls.

```apex
public with sharing class ChargeCardAction implements kern.UTIL_CircuitBreaker.ProtectedAction
{
	private Id orderId;

	public ChargeCardAction(Id orderId)
	{
		this.orderId = orderId;
	}

	public void execute()
	{
		// Failure-prone work — a callout, for example. Throw on failure.
	}
}

// Usage
kern.UTIL_CircuitBreaker.Breaker breaker = kern.UTIL_CircuitBreaker.monitor('PaymentGateway');
try
{
	breaker.execute(new ChargeCardAction(orderId));
}
catch(kern.UTIL_CircuitBreaker.OpenException openError)
{
	// Circuit is OPEN — the service is failing. Degrade gracefully.
	kern.LOG_Builder.build().warn(System.Label.Resilience_Service_Unavailable)
		.at('OrderService.charge')
		.emit();
}
```

> **`System.Label.Resilience_Service_Unavailable` is illustrative.** The framework does not ship this
> Custom Label. Create your own label (any name) in your org and reference it the same way so the example
> compiles. Pulling the message from a Custom Label keeps it translatable and overridable.

For deeper coverage, continue reading the sections below.

---

## How to opt out

You are never required to use these classes. The Resilience framework is opt-in: it pays off where calls are unreliable, and plain Apex is simpler everywhere else. The table below shows what to reach for in each situation, including when to skip the framework entirely.

| You need                                                  | Use                                                                                                                     | See                                                                                 |
|-----------------------------------------------------------|-------------------------------------------------------------------------------------------------------------------------|-------------------------------------------------------------------------------------|
| **A single callout with no failure handling**             | A plain `Http().send(request)`. No wrapper required.                                                                    | —                                                                                   |
| **Retry timing without a circuit breaker**                | `kern.UTIL_Retry` alone. It only computes backoff and the retry/stop decision.                                          | [Retry with Backoff](#retry-with-backoff-util_retry)                                |
| **Fail-fast gating without backoff math**                 | `kern.UTIL_CircuitBreaker` alone. It gates requests and tracks state.                                                   | [Circuit Breaker](#circuit-breaker-util_circuitbreaker)                             |
| **Resilience built into your callouts automatically**     | The [Web Services framework](Web%20Services%20-%20Guide.md): `API_Outbound` applies retry and circuit breaker for you.  | [Use with the Web Services Framework](#use-with-the-web-services-framework)         |
| **Per-call retry/circuit settings from a fluent callout** | `kern.UTIL_HttpClient` builder methods `.withRetry()` / `.withCircuitBreaker()`.                                        | [Per-Call Overrides with UTIL_HttpClient](#per-call-overrides-with-util_httpclient) |
| **Completely custom retry logic**                         | Implement `kern.UTIL_Retry.Strategy` yourself; the framework will use it anywhere a strategy is accepted.               | [Custom Strategies](#custom-strategies)                                             |

These are utilities, not a wall. Use them where the unreliability is real, and skip them where it isn't.

---

## Architecture

### Two Patterns, One Goal

Both tools help your code survive a failing dependency, but they answer different questions:

| Question                                              | Pattern               | What it controls                                                        |
|-------------------------------------------------------|-----------------------|-------------------------------------------------------------------------|
| **Should I wait, and how long, before trying again?** | `UTIL_Retry`          | Backoff period per attempt, maximum attempts, when to give up           |
| **Should I even try right now?**                      | `UTIL_CircuitBreaker` | Fast-fail when a service is known-bad, recovery testing after a timeout |

`UTIL_Retry` has **no memory of past calls**: give it a retry count and it hands back a backoff in seconds plus a keep-going or stop decision, nothing more. `UTIL_CircuitBreaker` **remembers recent activity and adapts**: it tracks recent failures across transactions in Platform Cache and changes its behavior based on that history.

### How They Fit Together

```text
+--------------------------------------------------------------------------------+
|                          RESILIENCE AROUND A CALLOUT                            |
+--------------------------------------------------------------------------------+
|                                                                                |
|   Caller wants to invoke an unreliable service                                 |
|            |                                                                   |
|            v                                                                   |
|   +-------------------------+    allowRequest() == false                       |
|   |  Circuit Breaker        |-----------------------------> FAIL FAST           |
|   |  (UTIL_CircuitBreaker)  |    (circuit is OPEN)          (OpenException)     |
|   +-----------+-------------+                                                   |
|               | allowRequest() == true                                         |
|               v                                                                |
|   +-------------------------+    success -> recordSuccess()                     |
|   |  Attempt the operation  |                                                   |
|   +-----------+-------------+    failure -> recordFailure()                     |
|               | failure                                                        |
|               v                                                                |
|   +-------------------------+    shouldRetry() == true                          |
|   |  Retry decision         |-----------------------------> wait calculateBackoff()|
|   |  (UTIL_Retry)           |                               seconds, try again  |
|   +-----------+-------------+    shouldRetry() == false                         |
|               |                  -----------------------> GIVE UP              |
|               v                                                                |
|        Repeated failures eventually open the circuit                           |
|                                                                                |
+--------------------------------------------------------------------------------+
```

Read it as two layers. The circuit breaker is the outer guard: don't bother calling at all if the service is known to be down. Retry is the inner loop: the call failed, but the failure looks temporary, so wait and try once more. The Web Services framework wires both of these together for you. The rest of this guide shows how to use them directly when you need to.

---

## Retry with Backoff (UTIL_Retry)

You want a flaky operation to try again after it fails, but in a way that gives a struggling service room to recover instead of pounding it. That is the retry pattern, and [`UTIL_Retry`](reference/apex/UTIL_Retry.md) handles it: when an operation fails with a temporary error, wait a calculated period and try again, growing the wait after each failure.

To use it, you work with two interfaces and a small set of factory methods:

- **`UTIL_Retry.Strategy`** decides whether to retry (`shouldRetry`) and how long to wait (`calculateBackoff`).
- **`UTIL_Retry.Context`** carries the current attempt number, an optional last-attempt time, and optional custom data into those decisions.

### Built-in Strategies

Two factory methods cover the common cases. Both default to **3 maximum retries** and a **10-second base
backoff**.

**Exponential backoff** (recommended for most integrations) doubles the wait after each attempt, giving a failing service progressively more room to recover:

```apex
kern.UTIL_Retry.Strategy strategy = kern.UTIL_Retry.exponential();
```

**Linear backoff** grows the wait by a fixed increment. It is gentler than exponential when doubling would otherwise climb too fast:

```apex
kern.UTIL_Retry.Strategy strategy = kern.UTIL_Retry.linear();
```

### Backoff Calculation

You run a strategy by handing it a `Context` that carries the current retry count. The strategy hands back the number of seconds to wait before the next attempt.

```apex
kern.UTIL_Retry.Strategy strategy = kern.UTIL_Retry.exponential();
kern.UTIL_Retry.Context context = kern.UTIL_Retry.newContext(1); // second attempt

if(strategy.shouldRetry(context))
{
	Integer backoffSeconds = strategy.calculateBackoff(context);
	// Schedule the next attempt backoffSeconds from now.
}
```

The retry count is **zero-based**: `0` is the first attempt, `1` is the first retry, and so on.

**Exponential** computes `baseBackoff * (multiplier ^ retryCount)`, capped at the maximum backoff. With the
defaults (base 10 seconds, multiplier 2.0, maximum 300 seconds):

| Retry count | Backoff (seconds) |
|-------------|-------------------|
| 0           | 10                |
| 1           | 20                |
| 2           | 40                |
| 3           | 80                |
| 4           | 160               |
| 5           | 300 (capped)      |

**Linear** computes `baseBackoff * retryCount`, except that retry counts `0` and `1` both use the base period.
With a base of 10 seconds:

| Retry count | Backoff (seconds) |
|-------------|-------------------|
| 0           | 10                |
| 1           | 10                |
| 2           | 20                |
| 3           | 30                |
| 4           | 40                |

The maximum backoff defaults to **300 seconds (5 minutes)** and acts as a ceiling on both strategies. For very high retry counts (31 or more), the exponential strategy returns the maximum directly, which avoids an arithmetic overflow.

### Jitter

Picture every user in your org hitting the same downed API at the same moment. Without jitter, they all retry on exactly the same schedule and swamp the service the instant it recovers. This is the "thundering herd" problem. Turning on jitter adds up to 25% random variation to each backoff, so the attempts spread out instead of arriving all at once:

```apex
kern.UTIL_Retry.Strategy strategy = kern.UTIL_Retry.exponential()
		.withJitter(true);
```

With jitter, a calculated backoff of 40 seconds becomes a random value between 40 and 50 seconds. The maximum
backoff cap is still respected after jitter is applied.

### Configuring a Strategy

You set every option with short chained calls. Because the setters live on the `Strategy` interface, they work on both built-in strategies and on any custom strategy you write:

```apex
kern.UTIL_Retry.Strategy strategy = kern.UTIL_Retry.exponential()
		.withMaxRetries(5) // give up after 5 retries
		.withBaseBackoff(10) // start at 10 seconds
		.withMaximumBackoff(300) // never wait more than 5 minutes
		.withExponentialMultiplier(2.0) // double each time (the default)
		.withJitter(true); // spread retries out
```

| Method                               | Purpose                                                          | Default |
|--------------------------------------|------------------------------------------------------------------|---------|
| `withMaxRetries(Integer)`            | Maximum number of retries before `shouldRetry()` returns `false` | 3       |
| `withBaseBackoff(Integer)`           | Base wait in seconds                                             | 10      |
| `withMaximumBackoff(Integer)`        | Ceiling on the calculated backoff in seconds                     | 300     |
| `withExponentialMultiplier(Decimal)` | Growth factor for exponential backoff (clamped to at least 1.0)  | 2.0     |
| `withJitter(Boolean)`                | Add up to 25% random variation to each backoff                   | false   |

Negative or null values are corrected to safe defaults, so a bad input can't break the math: a negative base backoff becomes `0`, a multiplier below `1.0` becomes `1.0`, and a null retry count becomes `0`.

### The Retry Context

`UTIL_Retry.newContext(retryCount)` builds a `Context`. Beyond the retry count, the context can carry the time of the last attempt and an arbitrary custom-data payload. That payload is useful for custom strategies that base their decision on the caught exception or on response headers:

```apex
kern.UTIL_Retry.Context context = kern.UTIL_Retry.newContext(1)
		.withLastAttemptTime(Datetime.now())
		.withCustomData(caughtException);
```

| Method                          | Returns    | Description                                                                  |
|---------------------------------|------------|------------------------------------------------------------------------------|
| `getRetryCount()`               | `Integer`  | Current attempt number (0-based)                                             |
| `getLastAttemptTime()`          | `Datetime` | Time of the last attempt, or null if not set                                 |
| `getCustomData()`               | `Object`   | Caller-supplied payload (exception, map, SObject, etc.), or null             |
| `withLastAttemptTime(Datetime)` | `Context`  | Sets the last-attempt time (fluent)                                          |
| `withCustomData(Object)`        | `Context`  | Sets the custom payload (fluent)                                             |
| `getBaseBackoff()`              | `Integer`  | Base backoff the strategy used (populated when `calculateBackoff()` runs)    |
| `getMaxBackoff()`               | `Integer`  | Maximum backoff the strategy used (populated when `calculateBackoff()` runs) |

### Exception Allowlists and Denylists

Some failures should never be retried. An authentication or bad-input error won't fix itself by waiting, so retrying it just wastes attempts. Two factory methods wrap an existing strategy and skip the retry based on the **caught exception**, which you pass in through `Context.withCustomData(exception)`:

**Denylist (never retry these error types):**

```apex
kern.UTIL_Retry.Strategy strategy = kern.UTIL_Retry.dontRetryOnException(
	kern.UTIL_Retry.exponential().withMaxRetries(5),
	new Set<Type>{ System.IllegalArgumentException.class }
);

kern.UTIL_Retry.Context context = kern.UTIL_Retry.newContext(0).withCustomData(caughtException);
Boolean shouldRetry = strategy.shouldRetry(context); // false if caughtException is an IllegalArgumentException
```

**Allowlist (retry only these error types):**

```apex
kern.UTIL_Retry.Strategy strategy = kern.UTIL_Retry.retryOnlyOnException(
	kern.UTIL_Retry.exponential().withMaxRetries(5),
	new Set<Type>{ System.CalloutException.class }
);
```

A few matching rules, straight from the implementation, are worth knowing so the filter behaves the way you expect:

- Matching is by **exact type name**. Subclass relationships are **not** considered, so denylisting `Exception.class` does not catch its concrete subclasses. List each concrete type explicitly.
- Inner-class exceptions from the framework match too, by their fully qualified name (for example `kern.UTIL_Exceptions.IllegalStateException`).
- When no exception is present in the context, both wrappers fall back to the base strategy. An empty or null type set also falls back fully, so the filter behaves as if it weren't there.

The wrappers pass `calculateBackoff()` and every chained setter through to the base strategy, so they slot into a chain without changing how it behaves.

### Custom Strategies

Sometimes the built-ins don't fit. Say you need to read a `Retry-After` header to honor a rate limit exactly. For cases like that, write your own class that implements the `Strategy` interface. Implement every method on the interface; for setters you don't need, just return `this`.

```apex
public with sharing class RateLimitStrategy implements kern.UTIL_Retry.Strategy
{
	private Integer maxRetries = 3;
	private Integer baseBackoff = 60;

	public Boolean shouldRetry(kern.UTIL_Retry.Context context)
	{
		return context.getRetryCount() < maxRetries;
	}

	public Integer calculateBackoff(kern.UTIL_Retry.Context context)
	{
		Object data = context.getCustomData();
		// Inspect data (e.g. a rate-limit reset header) to compute the wait, then:
		return baseBackoff;
	}

	public kern.UTIL_Retry.Strategy withMaxRetries(Integer max)
	{
		this.maxRetries = max;
		return this;
	}

	public kern.UTIL_Retry.Strategy withBaseBackoff(Integer seconds)
	{
		this.baseBackoff = seconds;
		return this;
	}

	public kern.UTIL_Retry.Strategy withJitter(Boolean enabled)
	{
		return this; // not used by this strategy
	}

	public kern.UTIL_Retry.Strategy withMaximumBackoff(Integer seconds)
	{
		return this; // not used by this strategy
	}

	public kern.UTIL_Retry.Strategy withExponentialMultiplier(Decimal multiplier)
	{
		return this; // not used by this strategy
	}
}
```

### What UTIL_Retry Does Not Do

So you know where the boundaries are:

- It **does not sleep.** Apex has no production-safe way to pause and wait. `calculateBackoff()` returns a number of seconds, and your code is responsible for scheduling the next attempt: a scheduled job, a platform event, or (inside the Web Services framework) the built-in retry flow.
- It **does not decide which errors are temporary.** It handles timing and the retry-or-stop count only. Deciding whether a given failure is worth retrying is your job, helped by the allowlist and denylist wrappers above.
- It **does not perform the operation.** You make the call; the strategy only advises on whether to retry it.

---

## Circuit Breaker (UTIL_CircuitBreaker)

You want to stop your code from repeatedly calling a service that is clearly down, and to start calling it again once it recovers. That is the job of a circuit breaker: after repeated failures, the framework stops calling the failing system for a cool-off, then resumes. [`UTIL_CircuitBreaker`](reference/apex/UTIL_CircuitBreaker.md) is a "smart fuse" for external calls. It watches failures and, once they cross a threshold, blocks further calls for a cool-down period instead of letting every request wait on a service that is already down. After the cool-down it lets a few test requests through to check whether the service has recovered.

Create one with the `monitor()` factory, passing a stable identifier (typically the service or API class name). That identifier keys the shared state, so every breaker created with the same id sees the same circuit:

```apex
kern.UTIL_CircuitBreaker.Breaker breaker = kern.UTIL_CircuitBreaker.monitor('PaymentGateway');
```

### The Three States

The `UTIL_CircuitBreaker.State` enum has three values:

| State         | Behavior                                                          | Meaning                            |
|---------------|-------------------------------------------------------------------|------------------------------------|
| **CLOSED**    | All requests pass through; failures are counted                   | Normal operation                   |
| **OPEN**      | All requests are rejected immediately without calling the service | The service is failing, so fail fast |
| **HALF_OPEN** | A limited number of test requests are allowed through             | Probing for recovery               |

### State Transitions

```text
        failures >= failureThreshold
   +-----------------------------------------+
   |                                         v
+--------+                              +--------+
| CLOSED |                              |  OPEN  |
+--------+                              +--------+
   ^                                         |
   | successes >= successThreshold           | timeout elapsed
   |                                         v
   |        any failure              +-----------+
   +<-------------------------------+| HALF_OPEN |
   |                                 +-----------+
   |  successes >= successThreshold        |
   +---------------------------------------+
```

- **CLOSED → OPEN** when the failure count reaches the failure threshold (default **5**). A success while CLOSED resets the failure count to zero.
- **OPEN → HALF_OPEN** automatically once the timeout has elapsed since the last failure (default **60 seconds**).
- **HALF_OPEN → CLOSED** when consecutive successes reach the success threshold (default **2**), at which point the service is considered recovered.
- **HALF_OPEN → OPEN** on **any** failure. The breaker is deliberately conservative: a single failure during recovery testing sends it straight back to OPEN to wait out another full timeout.

While HALF_OPEN, the breaker also limits how many test requests it lets through (default **3**), so a fragile, recovering service is not flooded.

### The execute() Helpers

The simplest and recommended way to use a breaker is `execute()`. It checks whether the request is allowed, runs your action, records success or failure, and re-throws the original error so the caller still sees it. There are two versions: one for work that returns nothing, and one for work that returns a value.

**Void action** (work that returns nothing): implement `ProtectedAction`:

```apex
public with sharing class SendEmailAction implements kern.UTIL_CircuitBreaker.ProtectedAction
{
	private String emailAddress;

	public SendEmailAction(String emailAddress)
	{
		this.emailAddress = emailAddress;
	}

	public void execute()
	{
		// Work that may fail — a callout, for example. Throw on failure.
	}
}

// Usage
kern.UTIL_CircuitBreaker.Breaker breaker = kern.UTIL_CircuitBreaker.monitor('EmailService');
try
{
	breaker.execute(new SendEmailAction('user@example.com'));
}
catch(kern.UTIL_CircuitBreaker.OpenException openError)
{
	kern.LOG_Builder.build().warn(System.Label.Resilience_Service_Unavailable)
		.at('NotificationService.send')
		.emit();
}
```

> As in the Quick Start, `System.Label.Resilience_Service_Unavailable` is illustrative. Create the Custom
> Label in your own org; the framework does not ship it.

**Value-returning action** (work that hands back a result): implement `Provider` and cast the result:

```apex
public with sharing class GetCustomerProvider implements kern.UTIL_CircuitBreaker.Provider
{
	private Id customerId;

	public GetCustomerProvider(Id customerId)
	{
		this.customerId = customerId;
	}

	public Object execute()
	{
		// Make the call and return the parsed response.
		return null;
	}
}

// Usage
kern.UTIL_CircuitBreaker.Breaker breaker = kern.UTIL_CircuitBreaker.monitor('CustomerService');
try
{
	Object response = breaker.execute(new GetCustomerProvider(customerId));
}
catch(kern.UTIL_CircuitBreaker.OpenException openError)
{
	// Circuit is OPEN — return cached data or a default.
}
```

When the circuit is OPEN, `execute()` throws `UTIL_CircuitBreaker.OpenException` **before** running your action,
so no callout is attempted. When your action throws while the circuit is CLOSED or HALF_OPEN, the breaker records
the failure and re-throws the original exception.

### Manual Gating

If you need finer control than `execute()` gives you, run the breaker by hand. The pattern is: ask whether the request is allowed, make the call, then report the outcome back to the breaker.

```apex
kern.UTIL_CircuitBreaker.Breaker breaker = kern.UTIL_CircuitBreaker.monitor('PaymentGateway')
	.withFailureThreshold(5)
	.withTimeout(60);

if(breaker.allowRequest())
{
	try
	{
		// Make the call.
		breaker.recordSuccess();
	}
	catch(Exception callError)
	{
		breaker.recordFailure();
		throw callError;
	}
}
else
{
	// Circuit is OPEN — skip the call and degrade gracefully.
}
```

### Configuring a Breaker

You set all four thresholds with short chained calls:

```apex
kern.UTIL_CircuitBreaker.Breaker breaker = kern.UTIL_CircuitBreaker.monitor('PaymentGateway')
		.withFailureThreshold(5) // open after 5 failures
		.withTimeout(120) // stay open for 2 minutes
		.withSuccessThreshold(3) // need 3 successes in HALF_OPEN to close
		.withHalfOpenMaxAttempts(2); // allow 2 test requests while HALF_OPEN
```

| Method                             | Purpose                                                        | Default |
|------------------------------------|----------------------------------------------------------------|---------|
| `withFailureThreshold(Integer)`    | Failures in CLOSED state before the circuit opens              | 5       |
| `withTimeout(Integer)`             | Seconds the circuit stays OPEN before testing recovery         | 60      |
| `withSuccessThreshold(Integer)`    | Consecutive successes in HALF_OPEN needed to close the circuit | 2       |
| `withHalfOpenMaxAttempts(Integer)` | Test requests allowed while HALF_OPEN                          | 3       |

Two manual overrides are available for operational control. Use them sparingly:

- `reset()` forces the circuit back to CLOSED and clears the counters.
- `forceOpen()` forces the circuit OPEN immediately (for example, to take a known-bad service out of rotation).

### Inspecting State and Metrics

To see what a breaker is doing, call `getState()` for the current `State`, or `getMetrics()` for a `UTIL_CircuitBreaker.Metrics` snapshot with the underlying counts and timestamps:

```apex
kern.UTIL_CircuitBreaker.Metrics metrics = breaker.getMetrics();
// metrics.circuitId, metrics.state, metrics.failureCount,
// metrics.consecutiveSuccesses, metrics.lastFailureTime, metrics.stateChangedTime
```

| Field                  | Type       | Description                          |
|------------------------|------------|--------------------------------------|
| `circuitId`            | `String`   | The identifier passed to `monitor()` |
| `state`                | `State`    | Current circuit state                |
| `failureCount`         | `Integer`  | Current failure count                |
| `consecutiveSuccesses` | `Integer`  | Current consecutive success count    |
| `lastFailureTime`      | `Datetime` | Time of the most recent failure      |
| `stateChangedTime`     | `Datetime` | Time the state last changed          |

### Platform Cache and Cross-Transaction State

Circuit state is stored in **Platform Cache**, in the framework's standard `Library` partition. This is what makes the breaker genuinely useful: a transaction that pushes the circuit OPEN protects every later transaction and user, not just its own request. The cache key is the circuit identifier you pass to `monitor()`, so reuse the same identifier everywhere you protect the same service.

The framework keeps the cache entry alive for the timeout period plus a buffer. That way the state survives long enough for the OPEN-to-HALF_OPEN transition to happen correctly when the timeout expires.

> **Graceful degradation:** If the `Library` cache partition is not available, the breaker still works, but its state lives only in memory for the current transaction and resets between transactions. That is fine for testing, but it means the cross-transaction protection is lost. Configure the cache partition for production use. See the [Utilities - Guide](Utilities%20-%20Guide.md) for cache partition setup.

---

## Combining Retry and Circuit Breaker

The two patterns are designed to work together. Retry absorbs the occasional temporary blip. The circuit breaker steps in when failures are no longer occasional and stops your code from piling on:

```apex
// Circuit breaker prevents cascade failures when the service is genuinely down.
// Retry handles the transient blip when the service is merely flaky.
kern.UTIL_CircuitBreaker.Breaker breaker = kern.UTIL_CircuitBreaker.monitor('ExternalAPI');

try
{
	breaker.execute(new MyRetryableCalloutAction());
}
catch(kern.UTIL_CircuitBreaker.OpenException openError)
{
	// Service is down — don't even attempt; degrade gracefully.
}
```

A useful mental model: **retry is short-term patience, the circuit breaker is long-term memory.** Retry gives a single call a few more chances over a handful of seconds. The circuit breaker remembers a pattern of failure across many calls and transactions, and refuses to keep trying once a service is clearly broken.

---

## Use with the Web Services Framework

If your callouts go through the [Web Services framework](Web%20Services%20-%20Guide.md) (`API_Outbound` and `UTIL_HttpClient`), both resilience patterns are applied **for you**, so you rarely call `UTIL_Retry` or `UTIL_CircuitBreaker` directly in that path. This section shows how the framework drives them, in case you want to tune or override the defaults.

### Configuration via ApiSetting

Each outbound API has an [`ApiSetting__mdt`](reference/metadata/ApiSetting__mdt.md) configuration record. The fields below let an admin tune resilience without touching code:

| Field                               | Controls                                                        |
|-------------------------------------|-----------------------------------------------------------------|
| `MaxRetryCount__c`                  | Maximum retry attempts                                          |
| `RetryBackoffSeconds__c`            | Base backoff in seconds for the default (linear) retry strategy |
| `CircuitBreakerEnabled__c`          | Whether circuit breaker protection is applied to the callout    |
| `CircuitBreakerFailureThreshold__c` | Failures before the circuit opens                               |
| `CircuitBreakerTimeout__c`          | Seconds the circuit stays open before testing recovery          |
| `CircuitBreakerSuccessThreshold__c` | Consecutive successes in HALF_OPEN needed to close the circuit  |

Out of the box, the framework builds a **linear** retry strategy from `RetryBackoffSeconds__c` and
`MaxRetryCount__c`, and a circuit breaker from the three `CircuitBreaker*` threshold fields. (The HALF_OPEN
test-request limit is not an `ApiSetting` field; it uses the breaker default and can be tuned in code via
`withHalfOpenMaxAttempts()` when you build a breaker directly.)

### Overriding the Retry Strategy

`API_Outbound` exposes a `createRetryStrategy()` hook. By default it returns a linear strategy built from the `ApiSetting__mdt` values. Override it to use any strategy you like, including a custom one:

```apex
global with sharing class API_PaymentGateway extends API_Outbound
{
	global override UTIL_Retry.Strategy createRetryStrategy()
	{
		// Exponential backoff with jitter for a rate-limited gateway.
		return UTIL_Retry.exponential()
			.withMaxRetries(5)
			.withBaseBackoff(10)
			.withJitter(true);
	}
}
```

> Inside your own `API_Outbound` subclass, you write return types and framework symbols without the `kern.` prefix, because the subclass is compiled in your namespace against the managed parent. Use the `kern.` prefix when you call these utilities from ordinary, unrelated Apex.

When a call fails with a temporary error, the framework builds a `UTIL_Retry.Context` from the call's current retry count, asks the strategy whether to retry, and if so uses `calculateBackoff()` to schedule the next attempt through its built-in retry processing. You do not schedule anything yourself.

### Per-Call Overrides with UTIL_HttpClient

For a one-off callout written with chained calls, `UTIL_HttpClient` lets you override the metadata defaults for a single request:

```apex
HttpResponse response = kern.UTIL_HttpClient.post('PaymentGateway', '/charges')
		.body(chargeRequest)
		.withRetry(3)
		.withCircuitBreaker()
		.send();
```

| Builder method           | Overrides                                     |
|--------------------------|-----------------------------------------------|
| `.withRetry(n)`          | `MaxRetryCount__c`                            |
| `.withRetry(n, backoff)` | `MaxRetryCount__c` + `RetryBackoffSeconds__c` |
| `.withCircuitBreaker()`  | `CircuitBreakerEnabled__c`                    |

See the [Web Services - Guide](Web%20Services%20-%20Guide.md) for the full callout builder and lifecycle.

---

## Capability Matrix (for Analysts)

If you don't write Apex, this table is your summary: it lists what resilience the framework gives you, whether it is on by default or opt-in, and which part provides it.

| Capability                                   | Built in?                 | Where it comes from                               |
|----------------------------------------------|---------------------------|---------------------------------------------------|
| Retry transient failures with backoff        | Yes                       | `UTIL_Retry` (exponential or linear)              |
| Spread retries to avoid thundering herd      | Yes (opt-in)              | `UTIL_Retry.withJitter(true)`                     |
| Never retry specific error types             | Yes                       | `UTIL_Retry.dontRetryOnException(...)`            |
| Retry only specific error types              | Yes                       | `UTIL_Retry.retryOnlyOnException(...)`            |
| Fail fast when a service is down             | Yes                       | `UTIL_CircuitBreaker` (OPEN state)                |
| Automatic recovery testing after an outage   | Yes                       | `UTIL_CircuitBreaker` (HALF_OPEN state)           |
| State shared across transactions and users   | Yes (with Platform Cache) | `UTIL_CircuitBreaker` + `Library` cache partition |
| Resilience applied automatically to callouts | Yes                       | Web Services framework (`API_Outbound`)           |
| Configure thresholds without code            | Yes                       | `ApiSetting__mdt` fields                          |
| Blocking sleep between retries               | No                        | Not available on the platform; schedule the retry |

---

## Testing

### Testing Retry Strategies

Retry strategies are pure timing calculations, so the tests are straightforward asserts on `shouldRetry()` and `calculateBackoff()`. You need no callouts and no asynchronous setup.

```apex
@IsTest
private static void shouldCalculateExponentialBackoff()
{
	kern.UTIL_Retry.Strategy strategy = kern.UTIL_Retry.exponential()
		.withMaxRetries(5)
		.withBaseBackoff(10);

	kern.UTIL_Retry.Context firstAttempt = kern.UTIL_Retry.newContext(0);
	kern.UTIL_Retry.Context secondAttempt = kern.UTIL_Retry.newContext(1);
	kern.UTIL_Retry.Context pastMax = kern.UTIL_Retry.newContext(5);

	Assert.isTrue(strategy.shouldRetry(firstAttempt), 'Should retry on the first attempt');
	Assert.areEqual(10, strategy.calculateBackoff(firstAttempt), 'First backoff should be 10s');
	Assert.areEqual(20, strategy.calculateBackoff(secondAttempt), 'Second backoff should be 20s');
	Assert.isFalse(strategy.shouldRetry(pastMax), 'Should not retry beyond the maximum');
}
```

### Testing Circuit Breakers

Move a breaker through its states by recording failures and successes. Set `withTimeout(0)` so the OPEN-to-HALF_OPEN transition happens immediately in the test, then read `getState()` to advance the breaker and assert on where it landed.

```apex
@IsTest
private static void shouldOpenAfterFailureThreshold()
{
	kern.UTIL_CircuitBreaker.Breaker breaker = kern.UTIL_CircuitBreaker.monitor('TestService')
		.withFailureThreshold(3);

	breaker.recordFailure();
	breaker.recordFailure();
	Assert.areEqual(kern.UTIL_CircuitBreaker.State.CLOSED, breaker.getState(), 'Stays CLOSED below threshold');

	breaker.recordFailure(); // hits the threshold
	Assert.areEqual(kern.UTIL_CircuitBreaker.State.OPEN, breaker.getState(), 'Opens at the threshold');
	Assert.isFalse(breaker.allowRequest(), 'Blocks requests while OPEN');
}
```

```apex
@IsTest
private static void shouldRecoverThroughHalfOpen()
{
	kern.UTIL_CircuitBreaker.Breaker breaker = kern.UTIL_CircuitBreaker.monitor('TestService')
		.withFailureThreshold(1)
		.withTimeout(0)          // immediate timeout for the test
		.withSuccessThreshold(2);

	breaker.recordFailure();     // CLOSED -> OPEN
	breaker.getState();          // OPEN -> HALF_OPEN (timeout elapsed)

	breaker.recordSuccess();
	breaker.recordSuccess();     // reaches success threshold -> CLOSED
	Assert.areEqual(kern.UTIL_CircuitBreaker.State.CLOSED, breaker.getState(), 'Closes after recovery');
}
```

---

## Anti-Patterns

These are common mistakes (anti-patterns) that quietly defeat the framework's protection. Each row pairs the mistake with what to do instead.

| Anti-Pattern                                            | Why it's wrong                                                           | Instead                                                                   |
|---------------------------------------------------------|--------------------------------------------------------------------------|---------------------------------------------------------------------------|
| Retrying non-transient errors (bad input, auth failure) | Wastes attempts on a failure that will never succeed                     | Use `dontRetryOnException(...)` to skip those types                       |
| Very high retry counts with exponential backoff         | Total wait can balloon into minutes or hours and exhaust patience/limits | Keep `withMaxRetries()` conservative (around 3–5)                         |
| No jitter when many clients fail together               | All clients retry in lockstep and re-overwhelm the recovering service    | Enable `withJitter(true)` for shared/high-volume integrations             |
| A fresh circuit identifier per transaction              | State is never shared, so the breaker never actually protects anything   | Use a stable identifier (the service or API class name) everywhere        |
| Swallowing `OpenException` silently                     | Hides outages from monitoring and users                                  | Log it and degrade gracefully (cached data, a clear message)              |
| Trying to block-sleep between retries                   | Apex has no production-safe sleep; it burns CPU or isn't allowed         | Schedule the next attempt (scheduled job, platform event, API retry flow) |

---

## Best Practices

1. **Default to exponential backoff with jitter** for external integrations. It is the most forgiving to a struggling service and avoids the thundering herd.
2. **Keep maximum retries low.** Three to five retries cover almost all temporary failures; more just delays the failure handling you'll need anyway.
3. **Use the denylist** to keep authentication and validation errors out of the retry loop, since they won't recover by waiting.
4. **Give each protected service one stable circuit identifier** and reuse it everywhere, so the breaker's cross-transaction memory actually builds up.
5. **Always handle `OpenException`.** Return cached data, a default, or a clear user message, and log it so outages are visible.
6. **Configure the `Library` Platform Cache partition in production** so circuit state survives across transactions; without it, the breaker only protects a single transaction.
7. **Let the Web Services framework do the wiring** when your calls are callouts. Configure `ApiSetting__mdt` (and override `createRetryStrategy()` when needed) rather than re-implementing the loop by hand.
8. **Surface user-facing copy through Custom Labels** (`System.Label.X` in Apex), never hardcoded literals, so degradation messages can be translated and overridden.

---

## Related Documentation

- [Fast Start - Resilience](Fast%20Start%20-%20Resilience.md) - Step-by-step walkthrough of retry and circuit breaker with tests and pitfalls
- [Web Services - Guide](Web%20Services%20-%20Guide.md) - `API_Outbound` and `UTIL_HttpClient`, where retry and circuit breaker are applied to callouts automatically
- [Async Processing - Guide](Async%20Processing%20-%20Guide.md) - Resilience patterns around asynchronous and batched callout processing
- [Utilities - Guide](Utilities%20-%20Guide.md) - `UTIL_Cache` and the `Library` Platform Cache partition that backs circuit state
- [Logging - Guide](Logging%20-%20Guide.md) - `LOG_Builder` for recording retry attempts and circuit transitions
