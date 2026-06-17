---
title: "UTIL_AsyncChain.ChainContext"
type: class
pageClass: reference
description: "Shared state container passed between chain steps. Provides key-value storage for inter-step communication and access to chain metadata such as execution ID and correlation ID."
since: "1.0"
category: apex
---

# UTIL_AsyncChain.ChainContext

**Class**

<div class="apex-member apex-class">

```apex
global inherited sharing class UTIL_AsyncChain.ChainContext
```

Shared state container passed between chain steps. Provides key-value storage for inter-step communication and access to chain metadata such as execution ID and correlation ID.

**Example**

```apex
context.put('accountId', account.Id);
Id accountId = (Id)context.get('accountId');
Boolean hasKey = context.has('accountId');
```

</div>

---

## Methods

| Method | Description |
|--------|-------------|
| global [Object](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_System_Object.htm) [get](#get)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) key) | Retrieves a value from the context by key. |
| global [Object](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_System_Object.htm) [getAs](#getas)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) key, [Type](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_type.htm) targetType) | Retrieves a value from the context and deserializes it to the specified type. |
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [getChainExecutionId](#getchainexecutionid)() | Returns the ID of the AsyncChainExecution__c record tracking this chain. |
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [getCorrelationId](#getcorrelationid)() | Returns the correlation ID for this chain, used for log correlation across transactions. |
| global [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) [getCurrentStepIndex](#getcurrentstepindex)() | Returns the zero-based index of the currently executing step. |
| global [UTIL_AsyncChain.StepResult](UTIL_AsyncChain.StepResult.md) [getPreviousStepResult](#getpreviousstepresult)() | Returns the result of the most recently completed step. |
| global [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) [has](#has)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) key) | Checks whether the context contains a value for the given key. |
| global void [put](#put)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) key, [Object](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_System_Object.htm) value) | Stores a value in the context under the given key. |

### get

<div class="apex-member">

```apex
global Object get(String key)
```

Retrieves a value from the context by key.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `key` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The key to look up. |

**Returns** [Object](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_System_Object.htm) — The stored value, or null if not found.

**Example**

```apex
Object value = context.get('recordCount');
```

</div>

### getAs

<div class="apex-member">

```apex
global Object getAs(String key, Type targetType)
```

Retrieves a value from the context and deserializes it to the specified type.
Useful for retrieving complex objects that were stored via put() and serialized between transactions.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `key` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The key to look up. |
| `targetType` | [Type](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_type.htm) | The Apex Type to deserialize the value into. |

**Returns** [Object](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_System_Object.htm) — The deserialized value, or null if the key is not found.

**Example**

```apex
List<String> names = (List<String>)context.getAs('nameList', List<String>.class);
```

</div>

### getChainExecutionId

<div class="apex-member">

```apex
global String getChainExecutionId()
```

Returns the ID of the AsyncChainExecution__c record tracking this chain.

**Returns** [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) — The chain execution record ID.

**Example**

```apex
String executionId = context.getChainExecutionId();
```

</div>

### getCorrelationId

<div class="apex-member">

```apex
global String getCorrelationId()
```

Returns the correlation ID for this chain, used for log correlation across transactions.

**Returns** [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) — The correlation ID string.

**Example**

```apex
String correlationId = context.getCorrelationId();
```

</div>

### getCurrentStepIndex

<div class="apex-member">

```apex
global Integer getCurrentStepIndex()
```

Returns the zero-based index of the currently executing step.
Useful for building idempotency keys (e.g., executionId + stepIndex).

**Returns** [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) — The current step index, or null for contexts not yet assigned to a step.

**Example**

```apex
String idempotencyKey = context.getChainExecutionId() + '-' + context.getCurrentStepIndex();
```

</div>

### getPreviousStepResult

<div class="apex-member">

```apex
global UTIL_AsyncChain.StepResult getPreviousStepResult()
```

Returns the result of the most recently completed step. Returns null for the first step.

**Returns** [UTIL_AsyncChain.StepResult](UTIL_AsyncChain.StepResult.md) — The previous step's StepResult, or null if this is the first step.

**Example**

```apex
UTIL_AsyncChain.StepResult previous = context.getPreviousStepResult();
if(previous != null && previous.success)
{
    String message = previous.message;
}
```

</div>

### has

<div class="apex-member">

```apex
global Boolean has(String key)
```

Checks whether the context contains a value for the given key.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `key` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The key to check. |

**Returns** [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) — True if the key exists in the context, false otherwise.

**Example**

```apex
if(context.has('accountId'))
{
    Id accountId = (Id)context.get('accountId');
}
```

</div>

### put

<div class="apex-member">

```apex
global void put(String key, Object value)
```

Stores a value in the context under the given key.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `key` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The key to store the value under. |
| `value` | [Object](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_System_Object.htm) | The value to store. |

**Example**

```apex
context.put('batchSize', 200);
```

</div>

