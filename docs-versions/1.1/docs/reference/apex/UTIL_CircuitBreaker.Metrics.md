---
title: "UTIL_CircuitBreaker.Metrics"
type: class
description: "Public class containing circuit breaker metrics"
since: "1.0"
category: apex
---

# UTIL_CircuitBreaker.Metrics

**Class**

```apex
global inherited sharing class UTIL_CircuitBreaker.Metrics
```

Public class containing circuit breaker metrics

**Since:** 1.0

---

## Fields

| Field | Description |
|-------|-------------|
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [circuitId](#circuitid) | The circuit identifier |
| global [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) [consecutiveSuccesses](#consecutivesuccesses) | Current consecutive success count |
| global [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) [failureCount](#failurecount) | Current failure count |
| global [Datetime](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_datetime.htm) [lastFailureTime](#lastfailuretime) | Time of last failure |
| global [UTIL_CircuitBreaker.State](UTIL_CircuitBreaker.State.md) [state](#state) | Current state of the circuit |
| global [Datetime](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_datetime.htm) [stateChangedTime](#statechangedtime) | Time when state last changed |

---

## Field Details

### circuitId

```apex
global String circuitId
```

**Type:** [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)

The circuit identifier

**Since:** 1.0

**Example:**

```apex
String value = instance.circuitId;
```

### consecutiveSuccesses

```apex
global Integer consecutiveSuccesses
```

**Type:** [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm)

Current consecutive success count

**Since:** 1.0

**Example:**

```apex
Integer value = instance.consecutiveSuccesses;
```

### failureCount

```apex
global Integer failureCount
```

**Type:** [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm)

Current failure count

**Since:** 1.0

**Example:**

```apex
Integer value = instance.failureCount;
```

### lastFailureTime

```apex
global Datetime lastFailureTime
```

**Type:** [Datetime](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_datetime.htm)

Time of last failure

**Since:** 1.0

**Example:**

```apex
Datetime value = instance.lastFailureTime;
```

### state

```apex
global UTIL_CircuitBreaker.State state
```

**Type:** [UTIL_CircuitBreaker.State](UTIL_CircuitBreaker.State.md)

Current state of the circuit

**Since:** 1.0

**Example:**

```apex
State value = instance.state;
```

### stateChangedTime

```apex
global Datetime stateChangedTime
```

**Type:** [Datetime](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_datetime.htm)

Time when state last changed

**Since:** 1.0

**Example:**

```apex
Datetime value = instance.stateChangedTime;
```

