---
title: "UTIL_CircuitBreaker.Breaker"
type: class
description: "Interface for circuit breaker operations. This interface defines the contract for circuit breaker behavior, including: Request gating (allowRequest) Success/failure recording State inspection and metr"
since: "1.0"
category: apex
---

# UTIL_CircuitBreaker.Breaker

**Class**

```apex
global interface UTIL_CircuitBreaker.Breaker
```

Interface for circuit breaker operations. This interface defines the contract for circuit breaker behavior, including: Request gating (allowRequest) Success/failure recording State inspection and metrics Configuration via fluent API Convenient execute() helpers for protected actions

**Since:** 1.0

---

## Methods

| Method | Description |
|--------|-------------|
| global abstract [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) [allowRequest](#allowrequest)() | Determines if a request is allowed through the circuit breaker |
| global abstract void [execute](#execute)([UTIL_CircuitBreaker.ProtectedAction](UTIL_CircuitBreaker.ProtectedAction.md) action) | Executes an action within the circuit breaker context This is a convenience method that abstracts the boilerplate pattern: Checks if request is allowed (throws exception if circuit is OPEN) Executes the action Records success/failure automatically |
| global abstract [Object](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_System_Object.htm) [execute](#execute)([UTIL_CircuitBreaker.Provider](UTIL_CircuitBreaker.Provider.md) action) | Executes an action within the circuit breaker context (with return value) This overload allows actions to return data, eliminating the need for member variables to capture API responses. |
| global abstract void [forceOpen](#forceopen)() | Manually forces the circuit breaker to OPEN state (use with caution) |
| global abstract [UTIL_CircuitBreaker.Metrics](UTIL_CircuitBreaker.Metrics.md) [getMetrics](#getmetrics)() | Gets detailed metrics about the circuit breaker |
| global abstract [UTIL_CircuitBreaker.State](UTIL_CircuitBreaker.State.md) [getState](#getstate)() | Gets the current state of the circuit breaker |
| global abstract void [recordFailure](#recordfailure)() | Records a failed request |
| global abstract void [recordSuccess](#recordsuccess)() | Records a successful request |
| global abstract void [reset](#reset)() | Manually resets the circuit breaker to CLOSED state (use with caution) |
| global abstract [UTIL_CircuitBreaker.Breaker](UTIL_CircuitBreaker.Breaker.md) [withFailureThreshold](#withfailurethreshold)([Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) threshold) | Sets the failure threshold (fluent API) |
| global abstract [UTIL_CircuitBreaker.Breaker](UTIL_CircuitBreaker.Breaker.md) [withHalfOpenMaxAttempts](#withhalfopenmaxattempts)([Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) maxAttempts) | Sets the maximum attempts allowed in HALF_OPEN state (fluent API) |
| global abstract [UTIL_CircuitBreaker.Breaker](UTIL_CircuitBreaker.Breaker.md) [withSuccessThreshold](#withsuccessthreshold)([Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) threshold) | Sets the success threshold for HALF_OPEN state (fluent API) |
| global abstract [UTIL_CircuitBreaker.Breaker](UTIL_CircuitBreaker.Breaker.md) [withTimeout](#withtimeout)([Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) seconds) | Sets the timeout period in seconds (fluent API) |

---

## Method Details

### allowRequest

```apex
global abstract Boolean allowRequest()
```

Determines if a request is allowed through the circuit breaker

**Returns:** [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) - True if the request should proceed, false if it should fail fast

### execute

```apex
global abstract void execute(UTIL_CircuitBreaker.ProtectedAction action)
```

Executes an action within the circuit breaker context

This is a convenience method that abstracts the boilerplate pattern:

- Checks if request is allowed (throws exception if circuit is OPEN)

- Executes the action

- Records success/failure automatically

**Parameters:**

- `action` ([UTIL_CircuitBreaker.ProtectedAction](UTIL_CircuitBreaker.ProtectedAction.md)) - The action to execute with circuit breaker protection

**Throws:**

- Exception - if the circuit is OPEN and request is blocked

**Example:**

```apex
UTIL_CircuitBreaker.Breaker breaker = UTIL_CircuitBreaker.monitor('API_SendGridEmail');
try
{
    breaker.execute(new SendEmailAction('user@example.com'));
}
catch(UTIL_CircuitBreaker.OpenException e)
{
    LOG_Builder.build().error(e).at('MyClass.sendEmail').emit();
    // Handle circuit open scenario
}
```

```apex
global abstract Object execute(UTIL_CircuitBreaker.Provider action)
```

Executes an action within the circuit breaker context (with return value)

This overload allows actions to return data, eliminating the need for member variables
to capture API responses.

**Parameters:**

- `action` ([UTIL_CircuitBreaker.Provider](UTIL_CircuitBreaker.Provider.md)) - The action to execute with circuit breaker protection

**Returns:** [Object](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_System_Object.htm) - The result from action.execute() (caller must cast to appropriate type)

**Throws:**

- Exception - if the circuit is OPEN and request is blocked

**Example:**

```apex
UTIL_CircuitBreaker.Breaker breaker = UTIL_CircuitBreaker.monitor('API_GetCustomerData');
try
{
    DTO_CustomerResponse response = (DTO_CustomerResponse)breaker.execute(
        new GetCustomerDataProvider(customerId)
    );
    System.debug('Customer Name: ' + response.name);
}
catch(UTIL_CircuitBreaker.OpenException e)
{
    LOG_Builder.build().error(e).at('MyClass.getCustomerData').emit();
    // Handle circuit open scenario
}
```

### forceOpen

```apex
global abstract void forceOpen()
```

Manually forces the circuit breaker to OPEN state (use with caution)

### getMetrics

```apex
global abstract UTIL_CircuitBreaker.Metrics getMetrics()
```

Gets detailed metrics about the circuit breaker

**Returns:** [UTIL_CircuitBreaker.Metrics](UTIL_CircuitBreaker.Metrics.md) - Circuit metrics including failure count, state, etc.

### getState

```apex
global abstract UTIL_CircuitBreaker.State getState()
```

Gets the current state of the circuit breaker

**Returns:** [UTIL_CircuitBreaker.State](UTIL_CircuitBreaker.State.md) - The current circuit state

### recordFailure

```apex
global abstract void recordFailure()
```

Records a failed request

### recordSuccess

```apex
global abstract void recordSuccess()
```

Records a successful request

### reset

```apex
global abstract void reset()
```

Manually resets the circuit breaker to CLOSED state (use with caution)

### withFailureThreshold

```apex
global abstract UTIL_CircuitBreaker.Breaker withFailureThreshold(Integer threshold)
```

Sets the failure threshold (fluent API)

**Parameters:**

- `threshold` ([Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm)) - Number of failures before opening the circuit

**Returns:** [UTIL_CircuitBreaker.Breaker](UTIL_CircuitBreaker.Breaker.md) - This instance for method chaining

### withHalfOpenMaxAttempts

```apex
global abstract UTIL_CircuitBreaker.Breaker withHalfOpenMaxAttempts(Integer maxAttempts)
```

Sets the maximum attempts allowed in HALF_OPEN state (fluent API)

**Parameters:**

- `maxAttempts` ([Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm)) - Maximum number of requests allowed in HALF_OPEN state

**Returns:** [UTIL_CircuitBreaker.Breaker](UTIL_CircuitBreaker.Breaker.md) - This instance for method chaining

### withSuccessThreshold

```apex
global abstract UTIL_CircuitBreaker.Breaker withSuccessThreshold(Integer threshold)
```

Sets the success threshold for HALF_OPEN state (fluent API)

**Parameters:**

- `threshold` ([Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm)) - Number of consecutive successes needed to close circuit

**Returns:** [UTIL_CircuitBreaker.Breaker](UTIL_CircuitBreaker.Breaker.md) - This instance for method chaining

### withTimeout

```apex
global abstract UTIL_CircuitBreaker.Breaker withTimeout(Integer seconds)
```

Sets the timeout period in seconds (fluent API)

**Parameters:**

- `seconds` ([Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm)) - Timeout in seconds before transitioning from OPEN to HALF_OPEN

**Returns:** [UTIL_CircuitBreaker.Breaker](UTIL_CircuitBreaker.Breaker.md) - This instance for method chaining

