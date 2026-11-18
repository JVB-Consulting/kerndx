---
title: "LOG_Builder.LogEntry"
type: class
pageClass: reference
description: "Fluent builder for constructing rich log entries with context. Provides a chainable API for setting log level, location, record association, and contextual metadata before emitting the log."
since: "1.0"
category: apex
---

# LOG_Builder.LogEntry

**Class**

<div class="apex-member apex-class">

```apex
global inherited sharing class LOG_Builder.LogEntry
```

Fluent builder for constructing rich log entries with context. Provides a chainable API for setting log level, location, record association, and contextual metadata before emitting the log.

**Example**

```apex
LOG_Builder.build()
    .error(caughtException)
    .at('PaymentService.charge')
    .forRecord(paymentId)
    .withContext('amount', payment.Amount__c)
    .emit();
```

</div>

---

## Methods

| Method | Description |
|--------|-------------|
| global [LOG_Builder.LogEntry](LOG_Builder.LogEntry.md) [at](#at)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) classMethod) | Sets the originating class and method for the log entry. |
| global [LOG_Builder.LogEntry](LOG_Builder.LogEntry.md) [debug](#debug)([List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)> messages) | Sets the log level to DEBUG with the given batch of messages. |
| global [LOG_Builder.LogEntry](LOG_Builder.LogEntry.md) [debug](#debug)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) message) | Sets the log level to DEBUG with the given message. |
| global void [emit](#emit)() | Emits the log entry with all configured properties. |
| global void [emitAt](#emitat)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) classMethod) | A shortcut that sets the class and method and emits the entry in one call. |
| global [LOG_Builder.LogEntry](LOG_Builder.LogEntry.md) [error](#error)([Exception](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_classes_exception_methods.htm) error) | Sets the log level to ERROR with the given exception. |
| global [LOG_Builder.LogEntry](LOG_Builder.LogEntry.md) [error](#error)([List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)> messages) | Sets the log level to ERROR with the given batch of messages. |
| global [LOG_Builder.LogEntry](LOG_Builder.LogEntry.md) [error](#error)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) message) | Sets the log level to ERROR with the given message. |
| global [LOG_Builder.LogEntry](LOG_Builder.LogEntry.md) [forRecord](#forrecord)([Id](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_id.htm) recordId) | Associates a record ID with the log entry. |
| global [LOG_Builder.LogEntry](LOG_Builder.LogEntry.md) [forRecord](#forrecord)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) recordId) | Associates a record ID (as String) with the log entry. |
| global [LOG_Builder.LogEntry](LOG_Builder.LogEntry.md) [info](#info)([List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)> messages) | Sets the log level to INFO with the given batch of messages. |
| global [LOG_Builder.LogEntry](LOG_Builder.LogEntry.md) [info](#info)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) message) | Sets the log level to INFO with the given message. |
| global [LOG_Builder.LogEntry](LOG_Builder.LogEntry.md) [warn](#warn)([List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)> messages) | Sets the log level to WARN with the given batch of messages. |
| global [LOG_Builder.LogEntry](LOG_Builder.LogEntry.md) [warn](#warn)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) message) | Sets the log level to WARN with the given message. |
| global [LOG_Builder.LogEntry](LOG_Builder.LogEntry.md) [withContext](#withcontext)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) key, [Object](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_System_Object.htm) value) | Adds a context key-value pair to this log entry. |
| global [LOG_Builder.LogEntry](LOG_Builder.LogEntry.md) [withFingerprint](#withfingerprint)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) key) | Sets a grouping fingerprint for this entry, which turns on flood control. |
| global [LOG_Builder.LogEntry](LOG_Builder.LogEntry.md) [withSummary](#withsummary)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) shortMessage) | Sets a brief summary message for the log entry. |

### at

<div class="apex-member">

```apex
global LOG_Builder.LogEntry at(String classMethod)
```

Sets the originating class and method for the log entry.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `classMethod` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The class and method in format 'ClassName.methodName' |

**Returns** [LOG_Builder.LogEntry](LOG_Builder.LogEntry.md) — This LogEntry for chaining

</div>

### debug

<div class="apex-member">

```apex
global LOG_Builder.LogEntry debug(List<String> messages)
```

Sets the log level to DEBUG with the given batch of messages.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `messages` | [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm) | The debug messages to log |

**Returns** [LOG_Builder.LogEntry](LOG_Builder.LogEntry.md) — This LogEntry for chaining

</div>

<div class="apex-member">

```apex
global LOG_Builder.LogEntry debug(String message)
```

Sets the log level to DEBUG with the given message.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `message` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The debug message |

**Returns** [LOG_Builder.LogEntry](LOG_Builder.LogEntry.md) — This LogEntry for chaining

</div>

### emit

<div class="apex-member">

```apex
global void emit()
```

Emits the log entry with all configured properties.
Any per-entry context is temporarily set as global context for the duration of the log call,
then cleaned up to prevent leaking into subsequent logs.

</div>

### emitAt

<div class="apex-member">

```apex
global void emitAt(String classMethod)
```

A shortcut that sets the class and method and emits the entry in one call.
Equivalent to `.at(classMethod).emit()`.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `classMethod` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The class and method in format 'ClassName.methodName' |

**Example**

```apex
LOG_Builder.build().error(caughtException).emitAt('PaymentService.charge');
```

</div>

### error

<div class="apex-member">

```apex
global LOG_Builder.LogEntry error(Exception error)
```

Sets the log level to ERROR with the given exception.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `error` | [Exception](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_classes_exception_methods.htm) | The exception to log |

**Returns** [LOG_Builder.LogEntry](LOG_Builder.LogEntry.md) — This LogEntry for chaining

</div>

<div class="apex-member">

```apex
global LOG_Builder.LogEntry error(List<String> messages)
```

Sets the log level to ERROR with the given batch of messages.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `messages` | [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm) | The error messages to log |

**Returns** [LOG_Builder.LogEntry](LOG_Builder.LogEntry.md) — This LogEntry for chaining

</div>

<div class="apex-member">

```apex
global LOG_Builder.LogEntry error(String message)
```

Sets the log level to ERROR with the given message.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `message` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The error message |

**Returns** [LOG_Builder.LogEntry](LOG_Builder.LogEntry.md) — This LogEntry for chaining

</div>

### forRecord

<div class="apex-member">

```apex
global LOG_Builder.LogEntry forRecord(Id recordId)
```

Associates a record ID with the log entry.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `recordId` | [Id](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_id.htm) | The related record ID |

**Returns** [LOG_Builder.LogEntry](LOG_Builder.LogEntry.md) — This LogEntry for chaining

</div>

<div class="apex-member">

```apex
global LOG_Builder.LogEntry forRecord(String recordId)
```

Associates a record ID (as String) with the log entry.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `recordId` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | String representation of the related record ID |

**Returns** [LOG_Builder.LogEntry](LOG_Builder.LogEntry.md) — This LogEntry for chaining

</div>

### info

<div class="apex-member">

```apex
global LOG_Builder.LogEntry info(List<String> messages)
```

Sets the log level to INFO with the given batch of messages.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `messages` | [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm) | The informational messages to log |

**Returns** [LOG_Builder.LogEntry](LOG_Builder.LogEntry.md) — This LogEntry for chaining

</div>

<div class="apex-member">

```apex
global LOG_Builder.LogEntry info(String message)
```

Sets the log level to INFO with the given message.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `message` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The informational message |

**Returns** [LOG_Builder.LogEntry](LOG_Builder.LogEntry.md) — This LogEntry for chaining

</div>

### warn

<div class="apex-member">

```apex
global LOG_Builder.LogEntry warn(List<String> messages)
```

Sets the log level to WARN with the given batch of messages.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `messages` | [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm) | The warning messages to log |

**Returns** [LOG_Builder.LogEntry](LOG_Builder.LogEntry.md) — This LogEntry for chaining

</div>

<div class="apex-member">

```apex
global LOG_Builder.LogEntry warn(String message)
```

Sets the log level to WARN with the given message.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `message` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The warning message |

**Returns** [LOG_Builder.LogEntry](LOG_Builder.LogEntry.md) — This LogEntry for chaining

</div>

### withContext

<div class="apex-member">

```apex
global LOG_Builder.LogEntry withContext(String key, Object value)
```

Adds a context key-value pair to this log entry.
Context is scoped to this entry only and does not affect other logs.

Complex types (Maps, Lists, SObjects) are turned into JSON automatically inside
`LOG_Engine.setGlobalContext`. Callers MUST NOT turn them into JSON first with `JSON.serialize(value)`,
or the value is encoded twice. Pass the value object directly and let the engine decide how to store it.
Use the `LOG_Engine.CONTEXT_*` constants for `key` instead of your own text, so that log entries from every
part of the framework use the same key names and can be searched together.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `key` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The context key (use a LOG_Engine.CONTEXT_* constant where one exists). |
| `value` | [Object](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_System_Object.htm) | The context value (any type; auto-serialised when complex). |

**Returns** [LOG_Builder.LogEntry](LOG_Builder.LogEntry.md) — This LogEntry for chaining

</div>

### withFingerprint

<div class="apex-member">

```apex
global LOG_Builder.LogEntry withFingerprint(String key)
```

Sets a grouping fingerprint for this entry, which turns on flood control. Flood control stops
the same event from filling the log: the first time the event happens it is saved as a full detail row,
and repeats are added up in one counter row per day. Use a key that names the kind of event and never
changes (e.g. 'payment-retry-loop'). Never use data that changes each time, such as record ids or
timestamps: that would make every entry unique and produce MORE rows than plain logging. Keys are trimmed.
Keys longer than 200 characters, or starting with the reserved 'bypass:' prefix, are replaced by their
SHA-256 hash. When a key is hashed, the original key is saved in this entry's context
(`LOG_Engine.CONTEXT_FINGERPRINT_SOURCE`), so you can still match the stored hash to the key you supplied.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `key` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The stable grouping key. |

**Returns** [LOG_Builder.LogEntry](LOG_Builder.LogEntry.md) — This LogEntry for chaining

**Example**

```apex
LOG_Builder.build().warn('Retry failed').withFingerprint('order-sync-retry').emitAt('OrderSync.run');
```

</div>

### withSummary

<div class="apex-member">

```apex
global LOG_Builder.LogEntry withSummary(String shortMessage)
```

Sets a brief summary message for the log entry. On an entry that carries an
exception, the summary becomes the short message and the exception's text stays the message.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `shortMessage` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The summary message |

**Returns** [LOG_Builder.LogEntry](LOG_Builder.LogEntry.md) — This LogEntry for chaining

</div>

