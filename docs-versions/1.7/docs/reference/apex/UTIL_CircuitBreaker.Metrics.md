---
title: "UTIL_CircuitBreaker.Metrics"
type: class
pageClass: reference
description: "Public class containing circuit breaker metrics"
since: "1.0"
category: apex
---

# UTIL_CircuitBreaker.Metrics

**Class**

<div class="apex-member apex-class">

```apex
global inherited sharing class UTIL_CircuitBreaker.Metrics
```

Public class containing circuit breaker metrics

</div>

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

### circuitId

```apex
global String circuitId
```

**Type:** [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)

The circuit identifier

**Example**

```apex
String value = instance.circuitId;
```

### consecutiveSuccesses

```apex
global Integer consecutiveSuccesses
```

**Type:** [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm)

Current consecutive success count

**Example**

```apex
Integer value = instance.consecutiveSuccesses;
```

### failureCount

```apex
global Integer failureCount
```

**Type:** [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm)

Current failure count

**Example**

```apex
Integer value = instance.failureCount;
```

### lastFailureTime

```apex
global Datetime lastFailureTime
```

**Type:** [Datetime](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_datetime.htm)

Time of last failure

**Example**

```apex
Datetime value = instance.lastFailureTime;
```

### state

```apex
global UTIL_CircuitBreaker.State state
```

**Type:** [UTIL_CircuitBreaker.State](UTIL_CircuitBreaker.State.md)

Current state of the circuit

**Example**

```apex
State value = instance.state;
```

### stateChangedTime

```apex
global Datetime stateChangedTime
```

**Type:** [Datetime](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_datetime.htm)

Time when state last changed

**Example**

```apex
Datetime value = instance.stateChangedTime;
```

