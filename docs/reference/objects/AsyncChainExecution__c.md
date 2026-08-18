---
title: "AsyncChainExecution__c"
type: sobject
pageClass: reference
description: "Tracks async chain executions including state, step definitions, shared context, and progress. Each record represents one chain execution lifecycle."
category: objects
---

# AsyncChainExecution__c

**Sobject**

<div class="apex-member apex-class">

```apex
global class AsyncChainExecution__c extends SObject
```

**Extends:** [SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm)

Tracks async chain executions including state, step definitions, shared context, and progress. Each record represents one chain execution lifecycle.

</div>

---

## Fields

| Field | Description |
|-------|-------------|
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [ActiveDeduplicationKey__c](#activededuplicationkey__c) | Active-run deduplication key. |
| global [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) [AllowRestart__c](#allowrestart__c) | Whether this chain was built with allowRestart() and may be restarted from step 1 from the Chain Monitor. |
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [ChainName__c](#chainname__c) | The name assigned to this chain via newChain(). |
| global [Datetime](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_datetime.htm) [CompletedAt__c](#completedat__c) | When chain execution finished (completed, failed, or aborted). |
| global [Decimal](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_decimal.htm) [CompletedSteps__c](#completedsteps__c) | Number of steps that completed successfully. |
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [ContextData__c](#contextdata__c) | Serialized JSON of the shared chain context (Map of String to Object). |
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [CorrelationId__c](#correlationid__c) | UUID linking this chain execution to all related log entries across async boundaries. |
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [CurrentJobId__c](#currentjobid__c) | Identifier of the queueable job currently executing this chain run. |
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [CurrentStepName__c](#currentstepname__c) | Name of the currently executing or last executed step. |
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [DeclaredDeduplicationKey__c](#declareddeduplicationkey__c) | The deduplication key this chain was built with, kept after the run ends so a re-drive can re-claim it. |
| global [Decimal](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_decimal.htm) [DurationMs__c](#durationms__c) | Wall-clock duration in milliseconds from chain start to terminal state. |
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [ErrorMessage__c](#errormessage__c) | Error details if chain failed. |
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [FailureCategory__c](#failurecategory__c) | Why the chain left the happy path. |
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [InitialContextData__c](#initialcontextdata__c) | The chain's initial context as built, captured only for chains that declare allowRestart(). |
| global [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[AsyncChainExecution__c](../objects/AsyncChainExecution__c.md)> [RestartedExecutions__r](#restartedexecutions__r) | Reciprocal relationship for AsyncChainExecution__c.SourceExecution__c. |
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [RunKey__c](#runkey__c) | Internal run-key fence token. |
| global [Id](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_id.htm) [SourceExecution__c](#sourceexecution__c) | The run this chain was restarted from. |
| global [AsyncChainExecution__c](../objects/AsyncChainExecution__c.md) [SourceExecution__r](#sourceexecution__r) | The run this chain was restarted from. |
| global [Datetime](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_datetime.htm) [StartedAt__c](#startedat__c) | When chain execution began. |
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [Status__c](#status__c) | Current chain execution state. |
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [StepLog__c](#steplog__c) | Serialized JSON array logging each step's class name, configuration, execution result, and duration. |
| global [Decimal](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_decimal.htm) [TotalSteps__c](#totalsteps__c) | Total number of steps defined in the chain. |

### ActiveDeduplicationKey__c

```apex
global String ActiveDeduplicationKey__c
```

Active-run deduplication key. Held while the chain is running or stalled; cleared in the same update that writes any terminal status, so a finished chain frees its key for the next run. The unique index makes a second concurrent start with the same key land on the active run instead of creating a duplicate.

**Field Attributes:**

| Attribute | Value |
|-----------|-------|
| Data Type | Text(255), case-insensitive |
| Required | false |
| Unique | true |
| External ID | true |

### AllowRestart__c

```apex
global Boolean AllowRestart__c
```

Whether this chain was built with allowRestart() and may be restarted from step 1 from the Chain Monitor. Declared by the chain author at build time; never edited by hand.

**Field Attributes:**

| Attribute | Value |
|-----------|-------|
| Data Type | Checkbox |
| Default Value | false |

### ChainName__c

```apex
global String ChainName__c
```

The name assigned to this chain via newChain(). Used for identification in logs, monitoring, and per-chain kill switches.

**Field Attributes:**

| Attribute | Value |
|-----------|-------|
| Data Type | Text(255) |
| Required | true |
| Unique | false |
| External ID | false |

### CompletedAt__c

```apex
global Datetime CompletedAt__c
```

When chain execution finished (completed, failed, or aborted).

**Field Attributes:**

| Attribute | Value |
|-----------|-------|
| Data Type | Date Time |
| Required | false |

### CompletedSteps__c

```apex
global Decimal CompletedSteps__c
```

Number of steps that completed successfully.

**Field Attributes:**

| Attribute | Value |
|-----------|-------|
| Data Type | Number(5,0) |
| Required | false |
| Unique | false |
| External ID | false |

### ContextData__c

```apex
global String ContextData__c
```

Serialized JSON of the shared chain context (Map of String to Object). Framework enforces 32K default limit with configurable override.

**Field Attributes:**

| Attribute | Value |
|-----------|-------|
| Data Type | Long Text Area(131072) |

### CorrelationId__c

```apex
global String CorrelationId__c
```

UUID linking this chain execution to all related log entries across async boundaries.

**Field Attributes:**

| Attribute | Value |
|-----------|-------|
| Data Type | Text(36), case-insensitive |
| Required | false |
| Unique | true |
| External ID | true |

### CurrentJobId__c

```apex
global String CurrentJobId__c
```

Identifier of the queueable job currently executing this chain run. Stamped at each step's progress write; the watchdog uses it to check whether a live executor still exists before recovering the chain. Shown read-only on the record page for diagnostics.

**Field Attributes:**

| Attribute | Value |
|-----------|-------|
| Data Type | Text(18) |
| Required | false |
| Unique | false |
| External ID | false |

### CurrentStepName__c

```apex
global String CurrentStepName__c
```

Name of the currently executing or last executed step.

**Field Attributes:**

| Attribute | Value |
|-----------|-------|
| Data Type | Text(255) |
| Required | false |
| Unique | false |
| External ID | false |

### DeclaredDeduplicationKey__c

```apex
global String DeclaredDeduplicationKey__c
```

The deduplication key this chain was built with, kept after the run ends so a re-drive can re-claim it.

**Field Attributes:**

| Attribute | Value |
|-----------|-------|
| Data Type | Text(255) |
| Required | false |
| Unique | false |
| External ID | false |

### DurationMs__c

```apex
global Decimal DurationMs__c
```

Wall-clock duration in milliseconds from chain start to terminal state. Includes async gaps between Queueable transactions (platform scheduling overhead). Individual step durations in the Step Log field reflect CPU time within each transaction.

**Field Attributes:**

| Attribute | Value |
|-----------|-------|
| Data Type | Number(10,0) |
| Required | false |
| Unique | false |
| External ID | false |

### ErrorMessage__c

```apex
global String ErrorMessage__c
```

Error details if chain failed. Includes step name and exception information.

**Field Attributes:**

| Attribute | Value |
|-----------|-------|
| Data Type | Long Text Area(32768) |

### FailureCategory__c

```apex
global String FailureCategory__c
```

Why the chain left the happy path. Set by the framework at each terminal or stall transition. Empty on healthy chains and on records created before this field existed.

**Field Attributes:**

| Attribute | Value |
|-----------|-------|
| Data Type | Picklist |
| Required | false |

**Picklist Values:**

| API Name | Label | Active |
|----------|-------|--------|
| `StepException` | Step Exception | Yes |
| `RetriesExhausted` | Retries Exhausted | Yes |
| `KillSwitch` | Kill Switch | Yes |
| `Stalled` | Stalled | Yes |
| `OperatorAbort` | Operator Abort | Yes |

### InitialContextData__c

```apex
global String InitialContextData__c
```

The chain's initial context as built, captured only for chains that declare allowRestart(). A restart runs from this snapshot, never from the evolved context.

**Field Attributes:**

| Attribute | Value |
|-----------|-------|
| Data Type | Long Text Area(131072) |

### RestartedExecutions__r

```apex
global List<AsyncChainExecution__c> RestartedExecutions__r
```

Reciprocal relationship for **`AsyncChainExecution__c.SourceExecution__c`** .

### RunKey__c

```apex
global String RunKey__c
```

Internal run-key fence token. Rotated on initial start and on every watchdog re-drive; the executor re-checks it before each persist so a stale-key zombie cannot corrupt a resumed run. Shown read-only on the record page for diagnostics.

**Field Attributes:**

| Attribute | Value |
|-----------|-------|
| Data Type | Text(36) |
| Required | false |
| Unique | false |
| External ID | false |

### SourceExecution__c

```apex
global Id SourceExecution__c
```

The run this chain was restarted from. Set only on records created by the Chain Monitor's restart action.

**Field Attributes:**

| Attribute | Value |
|-----------|-------|
| Data Type | AsyncChainExecution__c |
| Required | false |

### SourceExecution__r

```apex
global AsyncChainExecution__c SourceExecution__r
```

The run this chain was restarted from. Set only on records created by the Chain Monitor's restart action.

**Field Attributes:**

| Attribute | Value |
|-----------|-------|
| Data Type | AsyncChainExecution__c |
| Required | false |

### StartedAt__c

```apex
global Datetime StartedAt__c
```

When chain execution began.

**Field Attributes:**

| Attribute | Value |
|-----------|-------|
| Data Type | Date Time |
| Required | false |

### Status__c

```apex
global String Status__c
```

Current chain execution state.

**Field Attributes:**

| Attribute | Value |
|-----------|-------|
| Data Type | Picklist |
| Required | false |

**Picklist Values:**

| API Name | Label | Active |
|----------|-------|--------|
| `Aborted` | Aborted | No |
| `Completed` | Completed | No |
| `Delayed` | Delayed | No |
| `Failed` | Failed | No |
| `Running` | Running | Yes |
| `Stalled` | Stalled | No |

### StepLog__c

```apex
global String StepLog__c
```

Serialized JSON array logging each step's class name, configuration, execution result, and duration. Populated at chain creation with step definitions, then enriched with runtime outcomes as each step completes.

**Field Attributes:**

| Attribute | Value |
|-----------|-------|
| Data Type | Long Text Area(131072) |

### TotalSteps__c

```apex
global Decimal TotalSteps__c
```

Total number of steps defined in the chain.

**Field Attributes:**

| Attribute | Value |
|-----------|-------|
| Data Type | Number(5,0) |
| Required | false |
| Unique | false |
| External ID | false |

