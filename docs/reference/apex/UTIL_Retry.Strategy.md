---
title: "UTIL_Retry.Strategy"
type: class
pageClass: reference
description: "Interface defining the retry strategy logic. Implement this interface to create custom retry strategies."
since: "1.0"
category: apex
---

# UTIL_Retry.Strategy

**Class**

```apex
global interface UTIL_Retry.Strategy
```

Interface defining the retry strategy logic. Implement this interface to create custom retry strategies.

**Since:** 1.0

---

## Methods

| Method | Description |
|--------|-------------|
| global abstract [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) [calculateBackoff](#calculatebackoff)([UTIL_Retry.Context](UTIL_Retry.Context.md) context) | Calculates the backoff period in seconds for the next retry |
| global abstract [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) [shouldRetry](#shouldretry)([UTIL_Retry.Context](UTIL_Retry.Context.md) context) | Determines if a retry should be attempted |
| global abstract [UTIL_Retry.Strategy](UTIL_Retry.Strategy.md) [withBaseBackoff](#withbasebackoff)([Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) seconds) | Sets the base backoff period in seconds (fluent API) |
| global abstract [UTIL_Retry.Strategy](UTIL_Retry.Strategy.md) [withExponentialMultiplier](#withexponentialmultiplier)([Decimal](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_decimal.htm) multiplier) | Sets the exponential multiplier for exponential backoff (fluent API) |
| global abstract [UTIL_Retry.Strategy](UTIL_Retry.Strategy.md) [withJitter](#withjitter)([Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) enabled) | Enables or disables random jitter (fluent API) |
| global abstract [UTIL_Retry.Strategy](UTIL_Retry.Strategy.md) [withMaximumBackoff](#withmaximumbackoff)([Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) seconds) | Sets the maximum backoff cap in seconds (fluent API) |
| global abstract [UTIL_Retry.Strategy](UTIL_Retry.Strategy.md) [withMaxRetries](#withmaxretries)([Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) max) | Sets the maximum retry attempts (fluent API) |

---

## Method Details

### calculateBackoff

<div class="apex-member">

```apex
global abstract Integer calculateBackoff(UTIL_Retry.Context context)
```

Calculates the backoff period in seconds for the next retry

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `context` | [UTIL_Retry.Context](UTIL_Retry.Context.md) | The retry context containing retry count and configuration |

**Returns** [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) — The backoff period in seconds

**Example**

```apex
UTIL_Retry.Strategy strategy = UTIL_Retry.exponential();
UTIL_Retry.Context ctx = UTIL_Retry.newContext(1);
Integer backoffSeconds = strategy.calculateBackoff(ctx);
Datetime nextRetry = Datetime.now().addSeconds(backoffSeconds);
```

</div>

### shouldRetry

<div class="apex-member">

```apex
global abstract Boolean shouldRetry(UTIL_Retry.Context context)
```

Determines if a retry should be attempted

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `context` | [UTIL_Retry.Context](UTIL_Retry.Context.md) | The retry context containing retry count and configuration |

**Returns** [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) — True if a retry should be attempted, false otherwise

**Example**

```apex
UTIL_Retry.Strategy strategy = UTIL_Retry.exponential();
UTIL_Retry.Context ctx = UTIL_Retry.newContext(2);
if(strategy.shouldRetry(ctx))
{
    // Perform retry logic
}
```

</div>

### withBaseBackoff

<div class="apex-member">

```apex
global abstract UTIL_Retry.Strategy withBaseBackoff(Integer seconds)
```

Sets the base backoff period in seconds (fluent API)

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `seconds` | [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) | The base backoff period |

**Returns** [UTIL_Retry.Strategy](UTIL_Retry.Strategy.md) — This strategy for method chaining

**Example**

```apex
UTIL_Retry.Strategy strategy = UTIL_Retry.linear()
    .withBaseBackoff(15);
```

</div>

### withExponentialMultiplier

<div class="apex-member">

```apex
global abstract UTIL_Retry.Strategy withExponentialMultiplier(Decimal multiplier)
```

Sets the exponential multiplier for exponential backoff (fluent API)

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `multiplier` | [Decimal](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_decimal.htm) | The exponential multiplier (must be >= 1.0, default: 2.0) |

**Returns** [UTIL_Retry.Strategy](UTIL_Retry.Strategy.md) — This strategy for method chaining

**Example**

```apex
UTIL_Retry.Strategy strategy = UTIL_Retry.exponential()
    .withExponentialMultiplier(3.0); // Faster backoff growth
```

</div>

### withJitter

<div class="apex-member">

```apex
global abstract UTIL_Retry.Strategy withJitter(Boolean enabled)
```

Enables or disables random jitter (fluent API)

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `enabled` | [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) | Whether to enable jitter (adds up to 25% randomness) |

**Returns** [UTIL_Retry.Strategy](UTIL_Retry.Strategy.md) — This strategy for method chaining

**Example**

```apex
UTIL_Retry.Strategy strategy = UTIL_Retry.exponential()
    .withJitter(true);
```

</div>

### withMaximumBackoff

<div class="apex-member">

```apex
global abstract UTIL_Retry.Strategy withMaximumBackoff(Integer seconds)
```

Sets the maximum backoff cap in seconds (fluent API)

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `seconds` | [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) | Maximum backoff cap in seconds |

**Returns** [UTIL_Retry.Strategy](UTIL_Retry.Strategy.md) — This strategy for method chaining

**Example**

```apex
UTIL_Retry.Strategy strategy = UTIL_Retry.exponential()
    .withMaximumBackoff(600); // Cap at 10 minutes
```

</div>

### withMaxRetries

<div class="apex-member">

```apex
global abstract UTIL_Retry.Strategy withMaxRetries(Integer max)
```

Sets the maximum retry attempts (fluent API)

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `max` | [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) | The maximum retry attempts |

**Returns** [UTIL_Retry.Strategy](UTIL_Retry.Strategy.md) — This strategy for method chaining

**Example**

```apex
UTIL_Retry.Strategy strategy = UTIL_Retry.exponential()
    .withMaxRetries(5);
```

</div>

