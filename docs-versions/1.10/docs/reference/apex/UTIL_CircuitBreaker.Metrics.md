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
| global [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) [failureCount](#failurecount) | The failures recorded while the circuit was CLOSED. |
| global [Datetime](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_datetime.htm) [lastFailureTime](#lastfailuretime) | The time the circuit last opened: after too many failures, after a failed trial request, or through forceOpen. |
| global [UTIL_CircuitBreaker.State](UTIL_CircuitBreaker.State.md) [state](#state) | The state of the circuit when the metrics were read. |
| global [Datetime](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_datetime.htm) [stateChangedTime](#statechangedtime) | Time when the state last changed. |

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

The failures recorded while the circuit was CLOSED. A success while CLOSED sets it back to zero, and
so does closing the circuit. The circuit opens when this count reaches the failure threshold; opening it does
not reset the count.

**Example**

```apex
Integer value = instance.failureCount;
```

### lastFailureTime

```apex
global Datetime lastFailureTime
```

**Type:** [Datetime](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_datetime.htm)

The time the circuit last opened: after too many failures, after a failed trial request, or through
forceOpen. A failure that leaves the circuit CLOSED does not set it. Null when no opening is on record. The
timeout before an OPEN circuit lets trial requests through is counted from this time.

**Example**

```apex
Datetime value = instance.lastFailureTime;
```

### state

```apex
global UTIL_CircuitBreaker.State state
```

**Type:** [UTIL_CircuitBreaker.State](UTIL_CircuitBreaker.State.md)

The state of the circuit when the metrics were read. CLOSED lets every request through, OPEN refuses
them, and HALF_OPEN lets a few trial requests through. An OPEN circuit whose timeout has passed is shown as
HALF_OPEN, because reading the metrics moves it on first.

**Example**

```apex
State value = instance.state;
```

### stateChangedTime

```apex
global Datetime stateChangedTime
```

**Type:** [Datetime](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_datetime.htm)

Time when the state last changed. While the circuit is HALF_OPEN it is the time the current round of
trial requests began.

**Example**

```apex
Datetime value = instance.stateChangedTime;
```

