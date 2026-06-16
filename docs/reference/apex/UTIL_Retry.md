---
title: "UTIL_Retry"
type: class
pageClass: reference
description: "Factory for retry strategies with nested interface definitions. Provides a clean API for creating and configuring retry strategies with exponential or linear backoff. This factory pattern reduces name"
author: "Jason Van Beukering"
group: "Resilience"
date: "December 2025, May 2026"
since: "1.0"
category: apex
---

# UTIL_Retry

**Class** · Group: `Resilience`

<div class="apex-member apex-class">

```apex
global inherited sharing class UTIL_Retry
```

Factory for retry strategies with nested interface definitions. Provides a clean API for creating and configuring retry strategies with exponential or linear backoff. This factory pattern reduces namespace pollution by nesting the interface inside the factory class. Features: Nested interfaces for clean type organization Fluent configuration API Standard implementations (exponential, linear) Custom strategy support via interface Jitter support to prevent thundering herd

**Example**

Example 1: Simple exponential backoff

```apex
UTIL_Retry.Strategy strategy = UTIL_Retry.exponential();
UTIL_Retry.Context context = UTIL_Retry.newContext(1);
if(strategy.shouldRetry(context))
{
    Integer backoffSeconds = strategy.calculateBackoff(context);
    Datetime nextRetry = Datetime.now().addSeconds(backoffSeconds);
}
```

Example 2: Custom configuration

```apex
UTIL_Retry.Strategy strategy = UTIL_Retry.exponential()
    .withMaxRetries(5)
    .withBaseBackoff(10)
    .withJitter(true);
```

Example 3: Custom strategy implementation

```apex
public class RateLimitStrategy implements UTIL_Retry.Strategy
{
    public Boolean shouldRetry(UTIL_Retry.Context ctx)
    {
        return context.getRetryCount() < 3;
    }
    public Integer calculateBackoff(UTIL_Retry.Context ctx)
    {
        // Custom logic based on rate limit headers
        return 60; // Wait 1 minute for rate limit
    }
    // Implement fluent setters...
}
```

</div>

---

## Properties

| Property | Description |
|----------|-------------|
| global interface [Context](UTIL_Retry.Context.md) | Interface defining the retry context. |
| global interface [Strategy](UTIL_Retry.Strategy.md) | Interface defining the retry strategy logic. |

## Methods

| Method | Description |
|--------|-------------|
| global static [UTIL_Retry.Strategy](UTIL_Retry.Strategy.md) [dontRetryOnException](#dontretryonexception)([UTIL_Retry.Strategy](UTIL_Retry.Strategy.md) base, [Set](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_set.htm)<[Type](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_type.htm)> exceptionTypes) | Wraps an existing strategy with an exception-type denylist. |
| global static [UTIL_Retry.Strategy](UTIL_Retry.Strategy.md) [exponential](#exponential)() | Returns a standard exponential backoff strategy. |
| global static [UTIL_Retry.Strategy](UTIL_Retry.Strategy.md) [linear](#linear)() | Returns a standard linear backoff strategy. |
| global static [UTIL_Retry.Context](UTIL_Retry.Context.md) [newContext](#newcontext)([Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) retryCount) | Creates a new retry context with the specified retry count. |
| global static [UTIL_Retry.Strategy](UTIL_Retry.Strategy.md) [retryOnlyOnException](#retryonlyonexception)([UTIL_Retry.Strategy](UTIL_Retry.Strategy.md) base, [Set](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_set.htm)<[Type](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_type.htm)> exceptionTypes) | Wraps an existing strategy with an exception-type allowlist. |

---

## Method Details

### dontRetryOnException

<div class="apex-member">

```apex
global static UTIL_Retry.Strategy dontRetryOnException(UTIL_Retry.Strategy base, Set<Type> exceptionTypes)
```

Wraps an existing strategy with an exception-type denylist. The wrapped
strategy delegates `calculateBackoff` and the fluent setters (`withMaxRetries`, etc.)
to the base strategy, but `shouldRetry` returns `false` whenever the caught exception
(passed via `Context.withCustomData(Exception)`) matches any type in the denylist by
**exact type name** (e.g. `System.IllegalArgumentException`). Subclass relationships
are NOT considered — denylisting `Exception.class` does not catch concrete subclasses;
list each concrete type explicitly. Use for "never retry on these errors" cases — e.g.
authentication failures that won't recover via retry.

Wrapping (rather than adding setters to the `Strategy` interface) keeps the contract
for subscriber Strategy implementations unchanged.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `base` | [UTIL_Retry.Strategy](UTIL_Retry.Strategy.md) | The base retry strategy to wrap. |
| `exceptionTypes` | [Set](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_set.htm) | Set of exception types that should NEVER be retried. |

**Returns** [UTIL_Retry.Strategy](UTIL_Retry.Strategy.md) — A wrapped Strategy that suppresses retries when the caught exception matches any type in the denylist.

**Example**

```apex
UTIL_Retry.Strategy strategy = UTIL_Retry.dontRetryOnException(
        UTIL_Retry.exponential().withMaxRetries(5),
        new Set<Type>{System.IllegalArgumentException.class}
);
UTIL_Retry.Context context = UTIL_Retry.newContext(0).withCustomData(caughtException);
Boolean shouldRetry = strategy.shouldRetry(context);
```

</div>

### exponential

<div class="apex-member">

```apex
global static UTIL_Retry.Strategy exponential()
```

Returns a standard exponential backoff strategy.
Defaults: max retries = 3, base backoff = 10s, jitter = false

**Returns** [UTIL_Retry.Strategy](UTIL_Retry.Strategy.md) — Configured exponential backoff strategy

**Example**

```apex
UTIL_Retry.Strategy strategy = UTIL_Retry.exponential()
    .withMaxRetries(5)
    .withJitter(true);
```

</div>

### linear

<div class="apex-member">

```apex
global static UTIL_Retry.Strategy linear()
```

Returns a standard linear backoff strategy.
Defaults: max retries = 3, base backoff = 10s

**Returns** [UTIL_Retry.Strategy](UTIL_Retry.Strategy.md) — Configured linear backoff strategy

**Example**

```apex
UTIL_Retry.Strategy strategy = UTIL_Retry.linear()
    .withMaxRetries(5)
    .withBaseBackoff(15);
```

</div>

### newContext

<div class="apex-member">

```apex
global static UTIL_Retry.Context newContext(Integer retryCount)
```

Creates a new retry context with the specified retry count.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `retryCount` | [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) | The current retry attempt number (0 = first attempt, 1 = first retry, etc.) |

**Returns** [UTIL_Retry.Context](UTIL_Retry.Context.md) — New context instance

**Example**

```apex
UTIL_Retry.Context context = UTIL_Retry.newContext(1)
    .withLastAttemptTime(Datetime.now())
    .withCustomData(apiCall);
```

</div>

### retryOnlyOnException

<div class="apex-member">

```apex
global static UTIL_Retry.Strategy retryOnlyOnException(UTIL_Retry.Strategy base, Set<Type> exceptionTypes)
```

Wraps an existing strategy with an exception-type allowlist. The wrapped
strategy delegates everything to the base, but `shouldRetry` returns `false` UNLESS
the caught exception (passed via `Context.withCustomData(Exception)`) matches one of
the allowed types by **exact type name**. Subclass relationships are NOT considered.
Use for "only retry on these errors" cases — e.g. a narrow set of transient errors a
remote service might throw.

Calls without a caught Exception in `Context.getCustomData()` always retry per the
base strategy (the allowlist only applies when an exception is present).

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `base` | [UTIL_Retry.Strategy](UTIL_Retry.Strategy.md) | The base retry strategy to wrap. |
| `exceptionTypes` | [Set](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_set.htm) | Set of exception types that ARE allowed to be retried. Empty or null disables the filter (delegates fully to base). |

**Returns** [UTIL_Retry.Strategy](UTIL_Retry.Strategy.md) — A wrapped Strategy that only retries when the caught exception matches an allowed type.

**Example**

```apex
UTIL_Retry.Strategy strategy = UTIL_Retry.retryOnlyOnException(
        UTIL_Retry.exponential().withMaxRetries(5),
        new Set<Type>{System.CalloutException.class}
);
```

</div>

