---
title: "UTIL_Retry.Context"
type: class
description: "Interface defining the retry context. Contains information about the current retry attempt including count, timing, and custom data."
since: "1.0"
category: apex
---

# UTIL_Retry.Context

**Class**

```apex
global interface UTIL_Retry.Context
```

Interface defining the retry context. Contains information about the current retry attempt including count, timing, and custom data.

**Since:** 1.0

---

## Methods

| Method | Description |
|--------|-------------|
| global abstract [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) [getBaseBackoff](#getbasebackoff)() | Gets the configured base backoff in seconds |
| global abstract [Object](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_System_Object.htm) [getCustomData](#getcustomdata)() | Gets custom data for use with custom retry strategies |
| global abstract [Datetime](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_datetime.htm) [getLastAttemptTime](#getlastattempttime)() | Gets the datetime of the last retry attempt |
| global abstract [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) [getMaxBackoff](#getmaxbackoff)() | Gets the configured maximum backoff in seconds |
| global abstract [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) [getRetryCount](#getretrycount)() | Gets the current retry attempt number (0 = first attempt, 1 = first retry, etc.) |
| global abstract [UTIL_Retry.Context](UTIL_Retry.Context.md) [withCustomData](#withcustomdata)([Object](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_System_Object.htm) data) | Sets custom data for use with custom retry strategies (fluent API) |
| global abstract [UTIL_Retry.Context](UTIL_Retry.Context.md) [withLastAttemptTime](#withlastattempttime)([Datetime](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_datetime.htm) dt) | Sets the last attempt time (fluent API) |

---

## Method Details

### getBaseBackoff

```apex
global abstract Integer getBaseBackoff()
```

Gets the configured base backoff in seconds

**Returns:** [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) - The base backoff period

**Example:**

```apex
UTIL_Retry.Context ctx = UTIL_Retry.newContext(1);
UTIL_Retry.Strategy strategy = UTIL_Retry.linear();
strategy.calculateBackoff(ctx);
Integer baseBackoff = ctx.getBaseBackoff(); // Returns 10 (default)
```

### getCustomData

```apex
global abstract Object getCustomData()
```

Gets custom data for use with custom retry strategies

**Returns:** [Object](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_System_Object.htm) - The custom data object, or null if not set

**Example:**

```apex
Map<String, Object> data = new Map<String, Object>{'error' => '429'};
UTIL_Retry.Context ctx = UTIL_Retry.newContext(1)
    .withCustomData(data);
Object customData = ctx.getCustomData();
```

### getLastAttemptTime

```apex
global abstract Datetime getLastAttemptTime()
```

Gets the datetime of the last retry attempt

**Returns:** [Datetime](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_datetime.htm) - The last attempt time, or null if not set

**Example:**

```apex
UTIL_Retry.Context ctx = UTIL_Retry.newContext(1)
    .withLastAttemptTime(Datetime.now());
Datetime lastAttempt = ctx.getLastAttemptTime();
```

### getMaxBackoff

```apex
global abstract Integer getMaxBackoff()
```

Gets the configured maximum backoff in seconds

**Returns:** [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) - The maximum backoff period

**Example:**

```apex
UTIL_Retry.Context ctx = UTIL_Retry.newContext(1);
UTIL_Retry.Strategy strategy = UTIL_Retry.exponential();
strategy.calculateBackoff(ctx);
Integer maxBackoff = ctx.getMaxBackoff(); // Returns 300 (default)
```

### getRetryCount

```apex
global abstract Integer getRetryCount()
```

Gets the current retry attempt number (0 = first attempt, 1 = first retry, etc.)

**Returns:** [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) - The retry count

**Example:**

```apex
UTIL_Retry.Context ctx = UTIL_Retry.newContext(2);
Integer count = context.getRetryCount(); // Returns 2
```

### withCustomData

```apex
global abstract UTIL_Retry.Context withCustomData(Object data)
```

Sets custom data for use with custom retry strategies (fluent API)

**Parameters:**

- `data` ([Object](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_System_Object.htm)) - The custom data (SObject, Map, List, custom class, etc.)

**Returns:** [UTIL_Retry.Context](UTIL_Retry.Context.md) - This context for method chaining

**Example:**

```apex
ApiCall__c apiCall = [SELECT Id, StatusCode__c FROM ApiCall__c LIMIT 1];
UTIL_Retry.Context ctx = UTIL_Retry.newContext(1)
    .withCustomData(apiCall);
```

### withLastAttemptTime

```apex
global abstract UTIL_Retry.Context withLastAttemptTime(Datetime dt)
```

Sets the last attempt time (fluent API)

**Parameters:**

- `dt` ([Datetime](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_datetime.htm)) - The datetime of the last attempt

**Returns:** [UTIL_Retry.Context](UTIL_Retry.Context.md) - This context for method chaining

**Example:**

```apex
UTIL_Retry.Context ctx = UTIL_Retry.newContext(1)
    .withLastAttemptTime(Datetime.now());
```

