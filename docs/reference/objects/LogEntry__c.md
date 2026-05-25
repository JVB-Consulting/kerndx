---
title: "LogEntry__c"
type: sobject
description: "Persistent log entries captured by the Kern logging framework. Each record represents a single logged event from Apex, Flows, or LWC, published asynchronously via LogEntryEvent__e."
category: objects
---

# LogEntry__c

**Sobject**

```apex
global class LogEntry__c extends SObject
```

**Extends:** [SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm)

Persistent log entries captured by the Kern logging framework. Each record represents a single logged event from Apex, Flows, or LWC, published asynchronously via LogEntryEvent__e.

---

## Fields

| Field | Description |
|-------|-------------|
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [ClassMethod__c](#classmethod__c) | Source class and method where the event occurred, formatted as Class.method. |
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [ContextData__c](#contextdata__c) | JSON map of key-value pairs providing structured context about the operation. |
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [CorrelationId__c](#correlationid__c) | Unique identifier linking related log entries across multiple transactions. |
| global [Decimal](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_decimal.htm) [DurationMs__c](#durationms__c) | Duration of the operation in milliseconds. |
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [ExceptionType__c](#exceptiontype__c) | Fully qualified Apex exception class name (e.g., System.DmlException). |
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [ExecutionEvent__c](#executionevent__c) | Salesforce execution context (Quiddity) that produced this log entry. |
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [Limits__c](#limits__c) | JSON snapshot of Salesforce governor limits at the time the event was logged. |
| global [Decimal](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_decimal.htm) [LineNumber__c](#linenumber__c) | Source code line number in the Apex class where the exception occurred. |
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [LogLevel__c](#loglevel__c) | Severity level of this log entry: DEBUG, INFO, WARN, or ERROR. |
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [Message__c](#message__c) | Full log message content. |
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [ParentTransactionId__c](#parenttransactionid__c) | Transaction ID of the parent process that spawned this execution context. |
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [RecordId__c](#recordid__c) | Salesforce record ID associated with this log entry, if applicable. |
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [RecordLink__c](#recordlink__c) | Formula-generated hyperlink to the record associated with this log entry. |
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [ShortMessage__c](#shortmessage__c) | Brief summary of the log message, safe for SOQL WHERE and GROUP BY clauses. |
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [StackTrace__c](#stacktrace__c) | Apex execution stack trace captured at the time the event was logged. |
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [TransactionId__c](#transactionid__c) | Salesforce Request ID for the transaction that produced this log entry. |
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [UserId__c](#userid__c) | Salesforce User ID of the user whose execution context emitted this log entry. |
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [UserLink__c](#userlink__c) | Formula-generated hyperlink to the user who produced this log entry. |

---

## Field Details

### ClassMethod__c

```apex
global String ClassMethod__c
```

Source class and method where the event occurred, formatted as Class.method.

**Field Attributes:**

| Attribute | Value |
|-----------|-------|
| Data Type | Text(100) |
| Required | false |
| Unique | false |
| External ID | false |

### ContextData__c

```apex
global String ContextData__c
```

JSON map of key-value pairs providing structured context about the operation.

**Field Attributes:**

| Attribute | Value |
|-----------|-------|
| Data Type | Long Text Area(32768) |

### CorrelationId__c

```apex
global String CorrelationId__c
```

Unique identifier linking related log entries across multiple transactions.

**Field Attributes:**

| Attribute | Value |
|-----------|-------|
| Data Type | Text(36) |
| Required | false |
| Unique | false |
| External ID | true |

### DurationMs__c

```apex
global Decimal DurationMs__c
```

Duration of the operation in milliseconds.

**Field Attributes:**

| Attribute | Value |
|-----------|-------|
| Data Type | Number(18,0) |
| Required | false |
| Unique | false |
| External ID | false |

### ExceptionType__c

```apex
global String ExceptionType__c
```

Fully qualified Apex exception class name (e.g., System.DmlException).

**Field Attributes:**

| Attribute | Value |
|-----------|-------|
| Data Type | Text(80) |
| Required | false |
| Unique | false |
| External ID | false |

### ExecutionEvent__c

```apex
global String ExecutionEvent__c
```

Salesforce execution context (Quiddity) that produced this log entry.

**Field Attributes:**

| Attribute | Value |
|-----------|-------|
| Data Type | Picklist |
| Required | false |

**Picklist Values:**

| API Name | Label | Active |
|----------|-------|--------|
| `ANONYMOUS` | ANONYMOUS | Yes |
| `AURA` | AURA | Yes |
| `BATCH_ACS` | BATCH_ACS | Yes |
| `BATCH_APEX` | BATCH_APEX | Yes |
| `BATCH_CHUNK_PARALLEL` | BATCH_CHUNK_PARALLEL | Yes |
| `BATCH_CHUNK_SERIAL` | BATCH_CHUNK_SERIAL | Yes |
| `BULK_API` | BULK_API | Yes |
| `COMMERCE_INTEGRATION` | COMMERCE_INTEGRATION | Yes |
| `DISCOVERABLE_LOGIN` | DISCOVERABLE_LOGIN | Yes |
| `FUNCTION_CALLBACK` | FUNCTION_CALLBACK | Yes |
| `FUTURE` | FUTURE | Yes |
| `INBOUND_EMAIL_SERVICE` | INBOUND_EMAIL_SERVICE | Yes |
| `INVOCABLE_ACTION` | INVOCABLE_ACTION | Yes |
| `IOT` | IOT | Yes |
| `QUEUEABLE` | QUEUEABLE | Yes |
| `QUICK_ACTION` | QUICK_ACTION | Yes |
| `REMOTE_ACTION` | REMOTE_ACTION | Yes |
| `REST` | REST | Yes |
| `RUNTEST_ASYNC` | RUNTEST_ASYNC | Yes |
| `RUNTEST_DEPLOY` | RUNTEST_DEPLOY | Yes |
| `RUNTEST_SYNC` | RUNTEST_SYNC | Yes |
| `SCHEDULED` | SCHEDULED | Yes |
| `SOAP` | SOAP | Yes |
| `SYNCHRONOUS` | SYNCHRONOUS | Yes |
| `TRANSACTION_FINALIZER_QUEUEABLE` | TRANSACTION_FINALIZER_QUEUEABLE | Yes |
| `VF` | VF | Yes |

### Limits__c

```apex
global String Limits__c
```

JSON snapshot of Salesforce governor limits at the time the event was logged.

**Field Attributes:**

| Attribute | Value |
|-----------|-------|
| Data Type | Long Text Area(1024) |

### LineNumber__c

```apex
global Decimal LineNumber__c
```

Source code line number in the Apex class where the exception occurred.

**Field Attributes:**

| Attribute | Value |
|-----------|-------|
| Data Type | Number(8,0) |
| Required | false |
| Unique | false |
| External ID | false |

### LogLevel__c

```apex
global String LogLevel__c
```

Severity level of this log entry: DEBUG, INFO, WARN, or ERROR.

**Field Attributes:**

| Attribute | Value |
|-----------|-------|
| Data Type | Picklist |
| Required | false |

**Picklist Values:**

| API Name | Label | Active |
|----------|-------|--------|
| `DEBUG` | DEBUG | Yes |
| `INFO` | INFO | Yes |
| `WARN` | WARN | Yes |
| `ERROR` | ERROR | Yes |

### Message__c

```apex
global String Message__c
```

Full log message content. May contain exception details, stack traces, or diagnostic text.

**Field Attributes:**

| Attribute | Value |
|-----------|-------|
| Data Type | Long Text Area(131072) |

### ParentTransactionId__c

```apex
global String ParentTransactionId__c
```

Transaction ID of the parent process that spawned this execution context.

**Field Attributes:**

| Attribute | Value |
|-----------|-------|
| Data Type | Text(36) |
| Required | false |
| Unique | false |
| External ID | false |

### RecordId__c

```apex
global String RecordId__c
```

Salesforce record ID associated with this log entry, if applicable.

**Field Attributes:**

| Attribute | Value |
|-----------|-------|
| Data Type | Text(18) |
| Required | false |
| Unique | false |
| External ID | false |

### RecordLink__c

```apex
global String RecordLink__c
```

Formula-generated hyperlink to the record associated with this log entry. Provides one-click navigation from the log to the source record.

**Field Attributes:**

| Attribute | Value |
|-----------|-------|
| Data Type | Text |
| Required | false |
| Unique | false |
| External ID | false |
| Formula | `HYPERLINK("/" + RecordId__c , "Open")` |

### ShortMessage__c

```apex
global String ShortMessage__c
```

Brief summary of the log message, safe for SOQL WHERE and GROUP BY clauses.

**Field Attributes:**

| Attribute | Value |
|-----------|-------|
| Data Type | Text(255) |
| Required | false |
| Unique | false |
| External ID | false |

### StackTrace__c

```apex
global String StackTrace__c
```

Apex execution stack trace captured at the time the event was logged.

**Field Attributes:**

| Attribute | Value |
|-----------|-------|
| Data Type | Long Text Area(4096) |

### TransactionId__c

```apex
global String TransactionId__c
```

Salesforce Request ID for the transaction that produced this log entry.

**Field Attributes:**

| Attribute | Value |
|-----------|-------|
| Data Type | Text(36) |
| Required | false |
| Unique | false |
| External ID | true |

### UserId__c

```apex
global String UserId__c
```

Salesforce User ID of the user whose execution context emitted this log entry. Filter reports and queries by this field — not CreatedById — to find logs from a specific user. CreatedById is always the Automated Process user because log entries are persisted by a Platform Event trigger subscriber.

**Field Attributes:**

| Attribute | Value |
|-----------|-------|
| Data Type | Text(18) |
| Required | false |
| Unique | false |
| External ID | false |

### UserLink__c

```apex
global String UserLink__c
```

Formula-generated hyperlink to the user who produced this log entry. Provides one-click navigation from the log to the user record.

**Field Attributes:**

| Attribute | Value |
|-----------|-------|
| Data Type | Text |
| Required | false |
| Unique | false |
| External ID | false |
| Formula | `HYPERLINK("/" + UserId__c , "Open")` |

