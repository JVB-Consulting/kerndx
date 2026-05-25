---
title: "LOG_Builder"
type: class
description: "Primary logging interface for application debugging, monitoring, and error tracking. Uses a fluent builder API for rich contextual logging.  ```apex // Full chain with context LOG_Builder.build()     "
author: "Jason Van Beukering"
group: "Logging"
date: "October 2024, May 2026"
since: "1.0"
category: apex
---

# LOG_Builder

**Class** · Group: `Logging`

```apex
global inherited sharing class LOG_Builder
```

Primary logging interface for application debugging, monitoring, and error tracking.
Uses a fluent builder API for rich contextual logging.

```apex
// Full chain with context
LOG_Builder.build()
    .error(caughtException)
    .at('PaymentService.charge')
    .forRecord(paymentId)
    .withContext('amount', payment.Amount__c)
    .emit();

// Quick one-liner using emitAt shorthand
LOG_Builder.build().error(caughtException).emitAt('PaymentService.charge');

```

**Key Features:**

    - Fluent builder for combining level, location, record, and context in a single chain

    - Support for single messages, batch messages, and exception logging

    - Record ID correlation for tracing log entries to specific data

    - DML operation result analysis and error extraction

    - Correlation IDs for multi-transaction tracing

    - Scoped logging for batched publish

    - Integration with platform events for asynchronous log processing

**Querying log entries — filter by `UserId__c`, NOT `CreatedById`:**
Log entries are persisted by `TRG_PersistLogEntry` running on the `LogEntryEvent__e` Platform
Event subscriber. Salesforce executes Platform Event triggers as the Automated Process user, so
EVERY persisted `LogEntry__c` row has `CreatedById` set to the Automated Process user — NOT
the user that called `LOG_Builder.emit()`. The framework captures the emitting user's Id at
publish time into `LogEntry__c.UserId__c`. To query logs by emitting user, use:

```apex
// RIGHT — returns logs from the running user
QRY_Builder.selectFrom(LogEntry__c.SObjectType)
    .condition(LogEntry__c.UserId__c).equals(UserInfo.getUserId())
    .toList();

// WRONG — silently returns ZERO rows (CreatedById is the Automated Process user)
QRY_Builder.selectFrom(LogEntry__c.SObjectType)
    .condition(LogEntry__c.CreatedById).equals(UserInfo.getUserId())
    .toList();

```

The same applies to subscriber reports, dashboards, cleanup scripts, and audit queries. See
the Logging Developer Guide → "Querying Log Entries" for worked subscriber examples.

**Since:** 1.0

**Example:**

```apex
LOG_Builder.build().error(caughtException).emitAt('MyClass.myMethod');
LOG_Builder.build().info('Processing complete').emitAt('MyClass.myMethod');
```

**See Also:** [LoggingLevel](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_enum_System_LoggingLevel.htm)

---

## Properties

| Property | Description |
|----------|-------------|
| global static [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [correlationId](#correlationid) | The current correlation ID for log grouping across related operations. |
| global static [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) [ignoreTestMode](#ignoretestmode) | Controls whether logging events are published during test execution. |

## Methods

| Method | Description |
|--------|-------------|
| global static [LOG_Builder.LogEntry](LOG_Builder.LogEntry.md) [build](#build)() | Creates a new fluent log entry builder for constructing rich contextual log entries. |
| global static void [clearAllGlobalContext](#clearallglobalcontext)() | Clears all global context values. |
| global static void [clearGlobalContext](#clearglobalcontext)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) key) | Clears a specific global context key. |
| global static [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) [errorDMLOperationResults](#errordmloperationresults)([List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[Object](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_System_Object.htm)> operationResults, [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) classMethod) | Analyzes DML operation results and logs any errors encountered during database operations. |
| global static void [flushBuffer](#flushbuffer)() | Manually flushes buffered logs without resuming. |
| global static void [hydrateContext](#hydratecontext)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) serializedContext) | Restores logging context in async jobs. |
| global static void [resumeSaving](#resumesaving)() | Resumes log publishing and flushes buffer. |
| global static [LOG_Builder.LogScope](LOG_Builder.LogScope.md) [scope](#scope)() | Creates a logging scope that suspends immediate log publishing. |
| global static [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [serializeContext](#serializecontext)() | Serializes logging context for async job transfer. |
| global static void [setCorrelationId](#setcorrelationid)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) correlationId) | Sets the correlation ID for child transactions. |
| global static void [setGlobalContext](#setglobalcontext)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) key, [Object](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_System_Object.htm) value) | Sets a global context value included in ALL logs this transaction. |
| global static void [setParentTransactionId](#setparenttransactionid)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) parentTransactionId) | Sets parent transaction ID for hierarchy tracking. |
| global static [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [startCorrelation](#startcorrelation)() | Starts a new correlation context for multi-transaction tracing. |
| global static void [suspendSaving](#suspendsaving)() | Suspends log publishing. |

## Inner Classes

| Class | Description |
|-------|-------------|
| [LogEntry](LOG_Builder.LogEntry.md) | Fluent builder for constructing rich log entries with context. |
| [LogScope](LOG_Builder.LogScope.md) | A logging scope that buffers log entries until closed. |

---

## Property Details

### correlationId

```apex
global static String correlationId
```

**Type:** [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)

The current correlation ID for log grouping across related operations.

Since:


Example:

### ignoreTestMode

```apex
global static Boolean ignoreTestMode
```

**Type:** [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm)

Controls whether logging events are published during test execution.
When set to true, enables logging in test mode for debugging test-specific issues.
Defaults to false to avoid unnecessary logging overhead during unit tests.

Since:


Example:

---

## Method Details

### build

```apex
global static LOG_Builder.LogEntry build()
```

Creates a new fluent log entry builder for constructing rich contextual log entries.

**Returns:** [LOG_Builder.LogEntry](LOG_Builder.LogEntry.md) - LogEntry A new builder instance

**Since:** 1.0

**Example:**

```apex
LOG_Builder.build()
    .error(caughtException)
    .at('PaymentService.charge')
    .forRecord(paymentId)
    .withContext('amount', payment.Amount__c)
    .emit();
```

### clearAllGlobalContext

```apex
global static void clearAllGlobalContext()
```

Clears all global context values.

**Since:** 1.0

**Example:**

```apex
LOG_Builder.clearAllGlobalContext();
```

### clearGlobalContext

```apex
global static void clearGlobalContext(String key)
```

Clears a specific global context key.

**Parameters:**

- `key` ([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)) - The key to remove

**Since:** 1.0

**Example:**

```apex
LOG_Builder.clearGlobalContext('value');
```

### errorDMLOperationResults

```apex
global static Boolean errorDMLOperationResults(List<Object> operationResults, String classMethod)
```

Analyzes DML operation results and logs any errors encountered during database operations.
Automatically extracts and logs error details from failed DML operations, supporting various result types
including SaveResult, DeleteResult, UpsertResult, and UndeleteResult.

**Parameters:**

- `operationResults` ([List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)) - Collection of DML operation results to analyze for errors
- `classMethod` ([Object](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_System_Object.htm)) - The originating class and method in format 'ClassName.methodName'

**Returns:** [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) - Boolean indicating whether any errors were found and logged

**Since:** 1.0

**Example:**

```apex
List<Database.SaveResult> results = Database.insert(accounts, false);
Boolean hasErrors = LOG_Builder.errorDMLOperationResults(results, 'AccountService.insertAccounts');
if(hasErrors)
{
	// Handle the fact that some records failed
	System.debug('Some account insertions failed - check logs for details');
}
```

### flushBuffer

```apex
global static void flushBuffer()
```

Manually flushes buffered logs without resuming.

**Since:** 1.0

**Example:**

```apex
LOG_Builder.flushBuffer();
```

### hydrateContext

```apex
global static void hydrateContext(String serializedContext)
```

Restores logging context in async jobs.

**Parameters:**

- `serializedContext` ([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)) - JSON from serializeContext()

**Since:** 1.0

**Example:**

```apex
public void execute(QueueableContext ctx)
{
    LOG_Builder.hydrateContext(this.logContext);
    LOG_Builder.build().info('Processing with correlation').at('MyQueueable.execute').emit();
}
```

### resumeSaving

```apex
global static void resumeSaving()
```

Resumes log publishing and flushes buffer.

**Since:** 1.0

**Example:**

```apex
LOG_Builder.resumeSaving();
```

### scope

```apex
global static LOG_Builder.LogScope scope()
```

Creates a logging scope that suspends immediate log publishing. Logs emitted within
the scope are buffered until the scope is closed, at which point the buffer is flushed and
publishing resumes. This replaces the manual suspendSaving/flushBuffer/resumeSaving try/finally
pattern with a single close() call.

**Returns:** [LOG_Builder.LogScope](LOG_Builder.LogScope.md) - LogScope A new scope instance that must be closed when logging is complete

**Since:** 1.0

**Example:**

```apex
LOG_Builder.LogScope scope = LOG_Builder.scope();
for(Account account : accounts)
{
    LOG_Builder.build().debug('Processing: ' + account.Name).at('BatchJob.execute').emit();
}
scope.close();
```

### serializeContext

```apex
global static String serializeContext()
```

Serializes logging context for async job transfer.

**Returns:** [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) - String JSON context to pass to Queueable/Batch/Future

**Since:** 1.0

**Example:**

```apex
String logContext = LOG_Builder.serializeContext();
System.enqueueJob(new MyQueueable(logContext));
```

### setCorrelationId

```apex
global static void setCorrelationId(String correlationId)
```

Sets the correlation ID for child transactions.

**Parameters:**

- `correlationId` ([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)) - The correlation ID from parent transaction

**Since:** 1.0

**Example:**

```apex
LOG_Builder.setCorrelationId('value');
```

### setGlobalContext

```apex
global static void setGlobalContext(String key, Object value)
```

Sets a global context value included in ALL logs this transaction.

**Parameters:**

- `key` ([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)) - Context key (e.g., 'orderId')
- `value` ([Object](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_System_Object.htm)) - Context value

**Since:** 1.0

**Example:**

```apex
LOG_Builder.setGlobalContext('orderId', order.Id);
LOG_Builder.build().info('Processing order').at('OrderService.process').emit(); // Includes orderId
```

### setParentTransactionId

```apex
global static void setParentTransactionId(String parentTransactionId)
```

Sets parent transaction ID for hierarchy tracking.

**Parameters:**

- `parentTransactionId` ([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)) - The parent transaction's Request ID

**Since:** 1.0

**Example:**

```apex
LOG_Builder.setParentTransactionId('value');
```

### startCorrelation

```apex
global static String startCorrelation()
```

Starts a new correlation context for multi-transaction tracing.

**Returns:** [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) - String The generated correlation ID to pass to child processes

**Since:** 1.0

**Example:**

```apex
String correlationId = LOG_Builder.startCorrelation();
System.enqueueJob(new MyQueueable(correlationId));
```

### suspendSaving

```apex
global static void suspendSaving()
```

Suspends log publishing. Use try/finally to ensure resumeSaving().
ERROR logs bypass buffer and trigger immediate flush.

**Since:** 1.0

**Example:**

```apex
LOG_Builder.suspendSaving();
try
{
    for(Account account : accounts)
    {
        LOG_Builder.build().debug('Processing: ' + account.Name).at('BatchJob.execute').emit();
    }
    LOG_Builder.flushBuffer();
}
finally
{
    LOG_Builder.resumeSaving();
}
```

