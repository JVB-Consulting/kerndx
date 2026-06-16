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
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [ChainName__c](#chainname__c) | The name assigned to this chain via newChain(). |
| global [Datetime](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_datetime.htm) [CompletedAt__c](#completedat__c) | When chain execution finished (completed, failed, or aborted). |
| global [Decimal](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_decimal.htm) [CompletedSteps__c](#completedsteps__c) | Number of steps that completed successfully. |
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [ContextData__c](#contextdata__c) | Serialized JSON of the shared chain context (Map of String to Object). |
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [CorrelationId__c](#correlationid__c) | UUID linking this chain execution to all related log entries across async boundaries. |
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [CurrentStepName__c](#currentstepname__c) | Name of the currently executing or last executed step. |
| global [Decimal](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_decimal.htm) [DurationMs__c](#durationms__c) | Wall-clock duration in milliseconds from chain start to terminal state. |
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [ErrorMessage__c](#errormessage__c) | Error details if chain failed. |
| global [Datetime](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_datetime.htm) [StartedAt__c](#startedat__c) | When chain execution began. |
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [Status__c](#status__c) | Current chain execution state. |
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [StepLog__c](#steplog__c) | Serialized JSON array logging each step's class name, configuration, execution result, and duration. |
| global [Decimal](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_decimal.htm) [TotalSteps__c](#totalsteps__c) | Total number of steps defined in the chain. |

---

## Field Details

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

