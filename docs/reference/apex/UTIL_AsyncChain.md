---
title: "UTIL_AsyncChain"
type: class
pageClass: reference
description: "Lightweight async chain runner for sequencing jobs with shared state, error handling, and progress tracking. Delegates to existing async and logging infrastructure."
author: "Jason Van Beukering"
group: "Async"
date: "April 2026, June 2026"
since: "1.0"
category: apex
---

# UTIL_AsyncChain

**Class** · Group: `Async`

```apex
global inherited sharing class UTIL_AsyncChain
```

Lightweight async chain runner for sequencing jobs with shared state, error handling, and progress tracking. Delegates to existing async and logging infrastructure.

**Since:** 1.0

**Example:**

```apex
UTIL_AsyncChain.newChain('DataMigration')
    .then(new LoadDataStep())
    .then(new TransformDataStep())
    .onError(new NotifyAdminStep())
    .execute();
```

---

## Methods

| Method | Description |
|--------|-------------|
| global static [UTIL_AsyncChain.StepResult](UTIL_AsyncChain.StepResult.md) [failed](#failed)([Exception](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_classes_exception_methods.htm) error) | Creates a failed step result from an exception, using the exception message. |
| global static [UTIL_AsyncChain.StepResult](UTIL_AsyncChain.StepResult.md) [failed](#failed)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) message) | Creates a failed step result with a descriptive message. |
| global static [Map](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_map.htm)<[String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm), [Object](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_System_Object.htm)> [getStatus](#getstatus)([Id](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_id.htm) chainExecutionId) | Retrieves the current status of a chain execution as a map of key-value pairs. |
| global static [UTIL_AsyncChain.ChainBuilder](UTIL_AsyncChain.ChainBuilder.md) [newChain](#newchain)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) chainName) | Creates a new chain builder for composing a sequence of async steps. |
| global static [UTIL_AsyncChain.StepResult](UTIL_AsyncChain.StepResult.md) [succeeded](#succeeded)() | Creates a successful step result with no message. |
| global static [UTIL_AsyncChain.StepResult](UTIL_AsyncChain.StepResult.md) [succeeded](#succeeded)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) message) | Creates a successful step result with a descriptive message. |
| global static [UTIL_AsyncChain.StepResult](UTIL_AsyncChain.StepResult.md) [succeeded](#succeeded)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) message, [Object](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_System_Object.htm) data) | Creates a successful step result with a message and data payload. |

## Inner Classes

| Class | Description |
|-------|-------------|
| [ApiStep](UTIL_AsyncChain.ApiStep.md) | Chain step adapter that executes any API_Outbound handler as part of an async chain. |
| [ChainBuilder](UTIL_AsyncChain.ChainBuilder.md) | Fluent builder for configuring and executing an async chain. |
| [ChainContext](UTIL_AsyncChain.ChainContext.md) | Shared state container passed between chain steps. |
| [ChainStep](UTIL_AsyncChain.ChainStep.md) | Abstract base class for individual steps in an async chain. |
| [StepResult](UTIL_AsyncChain.StepResult.md) | Immutable result object returned by each ChainStep to indicate success or failure. |

---

## Method Details

### failed

<div class="apex-member">

```apex
global static UTIL_AsyncChain.StepResult failed(Exception error)
```

Creates a failed step result from an exception, using the exception message.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `error` | [Exception](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_classes_exception_methods.htm) | The exception that caused the failure. |

**Returns** [UTIL_AsyncChain.StepResult](UTIL_AsyncChain.StepResult.md) — A StepResult with success set to false, the exception message, and the exception reference.

**Example**

```apex
try { riskyOperation(); }
catch(Exception error) { return UTIL_AsyncChain.failed(error); }
```

</div>

<div class="apex-member">

```apex
global static UTIL_AsyncChain.StepResult failed(String message)
```

Creates a failed step result with a descriptive message.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `message` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | A human-readable description of the failure. |

**Returns** [UTIL_AsyncChain.StepResult](UTIL_AsyncChain.StepResult.md) — A StepResult with success set to false and the provided message.

**Example**

```apex
return UTIL_AsyncChain.failed('Required field is blank');
```

</div>

### getStatus

<div class="apex-member">

```apex
global static Map<String, Object> getStatus(Id chainExecutionId)
```

Retrieves the current status of a chain execution as a map of key-value pairs.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `chainExecutionId` | [Id](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_id.htm) | The ID of the AsyncChainExecution__c record to query. |

**Returns** [Object](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_System_Object.htm) — A map containing executionId, chainName, status, totalSteps, completedSteps, and errorMessage. Returns null if the record is not found.

**Example**

```apex
Map<String, Object> status = UTIL_AsyncChain.getStatus(executionId);
String currentStatus = (String)status.get('status');
```

</div>

### newChain

<div class="apex-member">

```apex
global static UTIL_AsyncChain.ChainBuilder newChain(String chainName)
```

Creates a new chain builder for composing a sequence of async steps.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `chainName` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | A descriptive name for the chain, used in logs and status tracking. |

**Returns** [UTIL_AsyncChain.ChainBuilder](UTIL_AsyncChain.ChainBuilder.md) — A new ChainBuilder instance for fluent configuration.

**Example**

```apex
UTIL_AsyncChain.ChainBuilder builder = UTIL_AsyncChain.newChain('DataMigration');
```

</div>

### succeeded

<div class="apex-member">

```apex
global static UTIL_AsyncChain.StepResult succeeded()
```

Creates a successful step result with no message.

**Returns** [UTIL_AsyncChain.StepResult](UTIL_AsyncChain.StepResult.md) — A StepResult with success set to true.

**Example**

```apex
return UTIL_AsyncChain.succeeded();
```

</div>

<div class="apex-member">

```apex
global static UTIL_AsyncChain.StepResult succeeded(String message)
```

Creates a successful step result with a descriptive message.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `message` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | A human-readable description of the successful outcome. |

**Returns** [UTIL_AsyncChain.StepResult](UTIL_AsyncChain.StepResult.md) — A StepResult with success set to true and the provided message.

**Example**

```apex
return UTIL_AsyncChain.succeeded('Processed 42 records');
```

</div>

<div class="apex-member">

```apex
global static UTIL_AsyncChain.StepResult succeeded(String message, Object data)
```

Creates a successful step result with a message and data payload.
The data is serialized into the chain context between transactions, so keep it small —
use record IDs or primitive values, not full SObject graphs or large collections.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `message` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | A human-readable description of the successful outcome. |
| `data` | [Object](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_System_Object.htm) | Arbitrary data to pass to subsequent steps via the context. Prefer IDs and primitives. |

**Returns** [UTIL_AsyncChain.StepResult](UTIL_AsyncChain.StepResult.md) — A StepResult with success set to true, the provided message, and data.

**Example**

```apex
List<Id> processedIds = new List<Id>{ record.Id };
return UTIL_AsyncChain.succeeded('Processed records', processedIds);
```

</div>

