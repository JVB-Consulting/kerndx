---
title: "UTIL_AsyncChain.ChainStatus"
type: class
pageClass: reference
description: "Typed, read-only snapshot of a chain execution returned by getChainStatus. A structured alternative to the getStatus(Id) map: each tracked field is a named property and the lifecycle is queryable thro"
since: "1.2"
category: apex
---

# UTIL_AsyncChain.ChainStatus

**Class**

<div class="apex-member apex-class">

```apex
global inherited sharing class UTIL_AsyncChain.ChainStatus
```

Typed, read-only snapshot of a chain execution returned by getChainStatus. A structured alternative to the getStatus(Id) map: each tracked field is a named property and the lifecycle is queryable through isRunning(), isTerminal() and isFailed(). Holds no step list and performs no queries — it is a plain value object built from a single AsyncChainExecution__c row.

**Example**

```apex
UTIL_AsyncChain.ChainStatus status = UTIL_AsyncChain.getChainStatus(executionId);
Boolean stillRunning = status.isRunning();
Integer done = status.completedSteps;
```

</div>

---

## Methods

| Method | Description |
|--------|-------------|
| global [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) [isFailed](#isfailed)() | Whether the chain failed. |
| global [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) [isRunning](#isrunning)() | Whether the chain is currently running. |
| global [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) [isTerminal](#isterminal)() | Whether the chain has reached a terminal state from which it will not advance — Completed, Failed or Aborted. |

### isFailed

<div class="apex-member">

```apex
global Boolean isFailed()
```

Whether the chain failed.

**Returns** [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) — true when the status is Failed.

**Example**

```apex
if(status.isFailed()) { escalate(status.errorMessage); }
```

</div>

### isRunning

<div class="apex-member">

```apex
global Boolean isRunning()
```

Whether the chain is currently running. Delayed and Stalled are reported as
neither running nor terminal.

**Returns** [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) — true when the status is Running.

**Example**

```apex
if(status.isRunning()) { return; }
```

</div>

### isTerminal

<div class="apex-member">

```apex
global Boolean isTerminal()
```

Whether the chain has reached a terminal state from which it will not advance —
Completed, Failed or Aborted.

**Returns** [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) — true when the status is Completed, Failed or Aborted.

**Example**

```apex
if(status.isTerminal()) { notifyDone(status); }
```

</div>

## Fields

| Field | Description |
|-------|-------------|
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [chainName](#chainname) | The descriptive chain name supplied to newChain(...). |
| global [Datetime](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_datetime.htm) [completedAt](#completedat) | When the chain reached a terminal state; null while still in flight. |
| global [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) [completedSteps](#completedsteps) | The number of steps completed so far. |
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [correlationId](#correlationid) | The correlation ID that ties this chain's log entries together. |
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [currentStepName](#currentstepname) | The name of the step currently executing (or last executed), if recorded. |
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [durationLabel](#durationlabel) | A compact, human-readable form of durationMs (for example "1m 30s"); null when no duration is available. |
| global [Long](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_long.htm) [durationMs](#durationms) | Elapsed run time in milliseconds. |
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [errorMessage](#errormessage) | The failure message, when the chain has failed; otherwise null. |
| global [Id](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_id.htm) [executionId](#executionid) | The AsyncChainExecution__c record ID. |
| global [Datetime](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_datetime.htm) [startedAt](#startedat) | When the chain started executing. |
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [status](#status) | The lifecycle status: one of Running, Completed, Failed, Aborted, Delayed or Stalled. |
| global [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) [totalSteps](#totalsteps) | The total number of steps in the chain. |

### chainName

```apex
global String chainName
```

**Type:** [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)

The descriptive chain name supplied to newChain(...).

### completedAt

```apex
global Datetime completedAt
```

**Type:** [Datetime](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_datetime.htm)

When the chain reached a terminal state; null while still in flight.

### completedSteps

```apex
global Integer completedSteps
```

**Type:** [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm)

The number of steps completed so far.

### correlationId

```apex
global String correlationId
```

**Type:** [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)

The correlation ID that ties this chain's log entries together.

### currentStepName

```apex
global String currentStepName
```

**Type:** [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)

The name of the step currently executing (or last executed), if recorded.

### durationLabel

```apex
global String durationLabel
```

**Type:** [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)

A compact, human-readable form of durationMs (for example "1m 30s"); null when
no duration is available.

### durationMs

```apex
global Long durationMs
```

**Type:** [Long](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_long.htm)

Elapsed run time in milliseconds. For a still-Running chain with no persisted
duration, this is computed live from startedAt, matching the Chain Monitor console.

### errorMessage

```apex
global String errorMessage
```

**Type:** [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)

The failure message, when the chain has failed; otherwise null.

### executionId

```apex
global Id executionId
```

**Type:** [Id](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_id.htm)

The AsyncChainExecution__c record ID.

### startedAt

```apex
global Datetime startedAt
```

**Type:** [Datetime](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_datetime.htm)

When the chain started executing.

### status

```apex
global String status
```

**Type:** [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)

The lifecycle status: one of Running, Completed, Failed, Aborted, Delayed or
Stalled. Prefer the isRunning()/isTerminal()/isFailed() predicates over comparing this String.

### totalSteps

```apex
global Integer totalSteps
```

**Type:** [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm)

The total number of steps in the chain.

