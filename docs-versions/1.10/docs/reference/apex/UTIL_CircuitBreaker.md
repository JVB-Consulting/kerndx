---
title: "UTIL_CircuitBreaker"
type: class
pageClass: reference
description: "Factory for creating circuit breaker instances to prevent cascading failures and provide fast failure when external services are unavailable. The circuit breaker has three states: CLOSED (normal opera"
author: "Jason Van Beukering"
group: "Resilience"
date: "December 2025, October 2026"
since: "1.0"
category: apex
---

# UTIL_CircuitBreaker

**Class** · Group: `Resilience`

<div class="apex-member apex-class">

```apex
global inherited sharing class UTIL_CircuitBreaker
```

Factory for creating circuit breaker instances to prevent cascading failures and provide fast failure when external services are unavailable. The circuit breaker has three states: CLOSED (normal operation), OPEN (failing fast), and HALF_OPEN (testing recovery). Features: Three-state circuit breaker pattern (CLOSED, OPEN, HALF_OPEN) Configurable failure threshold and timeout periods Automatic state transitions based on success/failure rates Integration with Platform Cache for distributed state management Per-service circuit breaker instances with shared state across transactions Detailed state tracking and metrics Convenient execute() helpers for protected actions Circuit States: CLOSED: Normal operation, requests pass through OPEN: Circuit is open, requests fail immediately without attempting the call HALF_OPEN: Testing if service has recovered, limited requests allowed through State Transitions: CLOSED → OPEN: When failure count reaches the threshold OPEN → HALF_OPEN: After timeout period expires HALF_OPEN → CLOSED: When success count indicates recovery HALF_OPEN → OPEN: When failures continue HALF_OPEN stays HALF_OPEN with a new round of trial requests: when every trial request of the round was used, none of them closed or reopened the circuit, and the timeout period has passed since the round began

**Example**

Example 1: Simple usage with execute() helper (RECOMMENDED)

```apex
UTIL_CircuitBreaker.Breaker breaker = UTIL_CircuitBreaker.monitor('API_SendGridEmail');
try
{
    breaker.execute(new SendEmailAction(emailData));
}
catch(UTIL_CircuitBreaker.OpenException e)
{
    // Circuit is open - handle gracefully
}
```

Example 2: Manual control with allowRequest()

```apex
UTIL_CircuitBreaker.Breaker breaker = UTIL_CircuitBreaker.monitor('API_SendGridEmail')
    .withFailureThreshold(5)
    .withTimeout(60);
if(breaker.allowRequest())
{
    try
    {
        // Make webservice call
        breaker.recordSuccess();
    }
    catch(Exception e)
    {
        breaker.recordFailure();
    }
}
```

Example 3: An API_Outbound handler needs no breaker code. Check Circuit Breaker Enabled on the service's API setting (it is off by default) and the framework checks a breaker named after the service before each send. While that breaker is open, the call is not sent, and its errors hold the line "The circuit breaker for (the service name) is open after repeated failures, so the request was not sent." A call whose setting allows retries is tried again after the cool-off while retries remain; a call whose setting allows no retries ends Aborted. To spot that outcome in your own code:

```apex
API_Outbound handler = UTIL_HttpClient.useHandler(API_SendGridEmail.class).invoke();
Boolean isCircuitOpen = handler != null && String.join(handler.result.errors, '\n').contains('is open after repeated failures');
```

**See Also:** [API_Outbound](API_Outbound.md), [UTIL_Cache](UTIL_Cache.md), [UTIL_Retry](UTIL_Retry.md)

</div>

---

## Methods

| Method | Description |
|--------|-------------|
| global static [UTIL_CircuitBreaker.Breaker](UTIL_CircuitBreaker.Breaker.md) [monitor](#monitor)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) circuitId) | Creates a new circuit breaker instance with default configuration Default configuration: Failure threshold: 5 failures Timeout: 60 seconds Success threshold: 2 successes Half-open max attempts: 3 |

### monitor

<div class="apex-member">

```apex
global static UTIL_CircuitBreaker.Breaker monitor(String circuitId)
```

Creates a new circuit breaker instance with default configuration

Default configuration:

- Failure threshold: 5 failures

- Timeout: 60 seconds

- Success threshold: 2 successes

- Half-open max attempts: 3

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `circuitId` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | Unique identifier for this circuit (typically service class name) |

**Returns** [UTIL_CircuitBreaker.Breaker](UTIL_CircuitBreaker.Breaker.md) — A new circuit breaker instance with defaults

**Example**

```apex
// Use defaults
UTIL_CircuitBreaker.Breaker breaker = UTIL_CircuitBreaker.monitor('API_SendGridEmail');
// Customize with fluent API
UTIL_CircuitBreaker.Breaker breaker = UTIL_CircuitBreaker.monitor('API_SendGridEmail')
    .withFailureThreshold(10)
    .withTimeout(120);
```

</div>

## Inner Classes

| Class | Description |
|-------|-------------|
| [Breaker](UTIL_CircuitBreaker.Breaker.md) | Interface for circuit breaker operations. |
| [Metrics](UTIL_CircuitBreaker.Metrics.md) | Public class containing circuit breaker metrics |
| [OpenException](UTIL_CircuitBreaker.OpenException.md) | Exception thrown when circuit breaker is OPEN and blocks a request |
| [ProtectedAction](UTIL_CircuitBreaker.ProtectedAction.md) | Interface for code that needs circuit breaker protection (no return value) Implement this interface to use the simplified execute() method which handles allowRequest(), recordSuccess(), and recordFailure() automatically. |
| [Provider](UTIL_CircuitBreaker.Provider.md) | Interface for code that needs circuit breaker protection (with return value) Implement this interface when your action needs to return data. |
| [State](UTIL_CircuitBreaker.State.md) | Enum representing the circuit breaker state |

---

