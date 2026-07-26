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
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [idempotencyKey](#idempotencykey)() | Returns the step-level idempotency key for the currently executing step: the chain execution id joined to the step index. |
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [idempotencyKey](#idempotencykey)([Id](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_id.htm) recordId) | Returns the record-grain idempotency key for a step that fans out over many records: the step-level key joined to the given record id. |
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [idempotencyKey](#idempotencykey)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) grain) | Returns a custom-grain idempotency key for a step that fans out over a unit that is not a record id (for example a line number or an external key): the step-level key joined to the given grain. |
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
To build a replay-safe key for this step, call context.idempotencyKey() rather than composing
the execution id and step index by hand.

**Returns** [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) — The current step index, or null for contexts not yet assigned to a step.

**Example**

```apex
String key = context.idempotencyKey();
String rowKey = context.idempotencyKey(recordId);
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

### idempotencyKey

<div class="apex-member">

```apex
global String idempotencyKey()
```

Returns the step-level idempotency key for the currently executing step: the
chain execution id joined to the step index. The key stays identical when the same step
replays, so a step that does one logical unit of work can store this key on an external-id
field and upsert (a replay updates the same record instead of creating a duplicate), or stamp
it on a marker for a side effect that cannot be upserted (a callout, an email) and skip when
the marker is already present. Treat the result as an opaque token: compare it or store it
whole, and do not split it to read back the run or step (use getChainExecutionId() and
getCurrentStepIndex() for those). Call it from within a step's work(context), where the step
index is always assigned.

**Returns** [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) — The step-level key, the execution id + "-" + step index.

**Example**

```apex
String key = context.idempotencyKey();
```

</div>

<div class="apex-member">

```apex
global String idempotencyKey(Id recordId)
```

Returns the record-grain idempotency key for a step that fans out over many
records: the step-level key joined to the given record id. Use it so a replay after a
partial failure only reprocesses the rows that did not complete the first time, instead of
re-running or skipping the whole step. A null recordId falls back to the bare step-level key.
An 18-character Id keeps the whole key well under the 255-character external-id limit, so this
overload needs no length caveat. Treat the result as an opaque token. Pass a literal null as a
typed variable or a cast ((Id) null), because a bare idempotencyKey(null) is ambiguous between
this overload and the String overload.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `recordId` | [Id](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_id.htm) | The record being processed, used as the per-record grain. |

**Returns** [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) — The step-level key + "-" + recordId, or the bare step-level key when recordId is null.

**Example**

```apex
String rowKey = context.idempotencyKey(record.Id);
```

</div>

<div class="apex-member">

```apex
global String idempotencyKey(String grain)
```

Returns a custom-grain idempotency key for a step that fans out over a unit that
is not a record id (for example a line number or an external key): the step-level key joined
to the given grain. A null or blank grain falls back to the bare step-level key. The grain
passes through verbatim, so the helper never hashes or truncates it. The composed key is
typically stored on a Text external-id field capped at 255 characters; an over-long key fails
loudly at upsert with a STRING_TOO_LONG DmlException (not silent truncation), so it surfaces
in your own test. If you need a long composite grain, shorten it yourself (a one-line hash of
just the grain) before passing it. Treat the result as an opaque token. Pass a literal null as
a typed variable or a cast ((String) null), because a bare idempotencyKey(null) is ambiguous
between this overload and the Id overload.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `grain` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The stable fan-out token, kept short, that does not change between attempts. |

**Returns** [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) — The step-level key + "-" + grain, or the bare step-level key when grain is blank.

**Example**

```apex
String lineKey = context.idempotencyKey('orderLine-' + lineNumber);
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

