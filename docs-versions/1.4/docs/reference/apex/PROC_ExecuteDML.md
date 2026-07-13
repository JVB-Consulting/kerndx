---
title: "PROC_ExecuteDML"
type: class
pageClass: reference
description: "Processor for generic DML operations using the adaptive async framework. Implements IF_Async.Processable to enable automatic selection between Queueable and Batch execution. Supports INSERT, UPDATE, D"
author: "Jason Van Beukering"
group: "Bulk DML"
date: "February 2026, May 2026"
since: "1.0"
category: apex
---

# PROC_ExecuteDML

**Class** · Group: `Bulk DML`

<div class="apex-member apex-class">

```apex
global inherited sharing class PROC_ExecuteDML implements IF_Async.Processable
```

**Implements:** [IF_Async.Processable](IF_Async.Processable.md)

**Known Derived Types:** [IF_Async.Processable.execute(List<Object>)](IF_Async.Processable.md#execute)

Processor for generic DML operations using the adaptive async framework. Implements IF_Async.Processable to enable automatic selection between Queueable and Batch execution. Supports INSERT, UPDATE, DELETE, UPSERT, and UNDELETE operations.

**Example**

```apex
PROC_ExecuteDML processor = new PROC_ExecuteDML(DML_Builder.DatabaseOperation.DML_UPDATE, false);
UTIL_AsynchronousJobLauncher.process(
    new UTIL_AsynchronousJobLauncher.DTO_AsynchronousJobRequest(queryable), processor
);
```

**See Also:** [IF_Async.Processable](IF_Async.Processable.md), [UTIL_AsynchronousJobLauncher](UTIL_AsynchronousJobLauncher.md)

</div>

---

## Methods

| Method | Description |
|--------|-------------|
| global void [execute](#execute)([List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[Object](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_System_Object.htm)> items) | Executes the configured DML operation on the provided list of records. |

### execute

<div class="apex-member">

```apex
global void execute(List<Object> items)
```

Executes the configured DML operation on the provided list of records.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `items` | [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm) | The list of SObject records to process. |

**Example**

```apex
List<Account> accounts = new List<Account>();
accounts.add(new Account(Name = 'Test'));
new PROC_ExecuteDML(DML_Builder.DatabaseOperation.DML_INSERT).execute(accounts);
```

</div>

## Constructors

| Constructor | Description |
|-------------|-------------|
| global [PROC_ExecuteDML](#constructors)([DML_Builder.DatabaseOperation](DML_Builder.DatabaseOperation.md) operation) | Constructs a DML processor with the specified operation and default all-or-nothing behavior. |
| global [PROC_ExecuteDML](#constructors)([DML_Builder.DatabaseOperation](DML_Builder.DatabaseOperation.md) operation, [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) allOrNothing) | Constructs a DML processor with the specified operation and transaction behavior. |
| global [PROC_ExecuteDML](#constructors)([DML_Builder.DatabaseOperation](DML_Builder.DatabaseOperation.md) operation, [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) allOrNothing, [AccessLevel](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexcode/apex_bulk_sharing_creating_with_apex.htm) accessLevel) | Constructs a DML processor with an explicit AccessLevel. |

### PROC_ExecuteDML(DML_Builder.DatabaseOperation operation)

<div class="apex-member">

```apex
global PROC_ExecuteDML(DML_Builder.DatabaseOperation operation)
```

Constructs a DML processor with the specified operation and default all-or-nothing behavior.
Access mode inherits the flag-driven default.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `operation` | [DML_Builder.DatabaseOperation](DML_Builder.DatabaseOperation.md) | The DML operation to perform (DML_INSERT, DML_UPDATE, DML_DELETE, DML_UPSERT, DML_UNDELETE). |

**Example**

```apex
PROC_ExecuteDML processor = new PROC_ExecuteDML(DML_Builder.DatabaseOperation.DML_INSERT);
```

</div>

### PROC_ExecuteDML(DML_Builder.DatabaseOperation operation, Boolean allOrNothing)

<div class="apex-member">

```apex
global PROC_ExecuteDML(DML_Builder.DatabaseOperation operation, Boolean allOrNothing)
```

Constructs a DML processor with the specified operation and transaction behavior.
Access mode inherits the flag-driven default.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `operation` | [DML_Builder.DatabaseOperation](DML_Builder.DatabaseOperation.md) | The DML operation to perform (DML_INSERT, DML_UPDATE, DML_DELETE, DML_UPSERT, DML_UNDELETE). |
| `allOrNothing` | [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) | If true, the entire transaction rolls back on any failure; if false, allows partial success. |

**Example**

```apex
PROC_ExecuteDML processor = new PROC_ExecuteDML(DML_Builder.DatabaseOperation.DML_UPDATE, false);
```

</div>

### PROC_ExecuteDML(DML_Builder.DatabaseOperation operation, Boolean allOrNothing, AccessLevel accessLevel)

<div class="apex-member">

```apex
global PROC_ExecuteDML(DML_Builder.DatabaseOperation operation, Boolean allOrNothing, AccessLevel accessLevel)
```

Constructs a DML processor with an explicit `AccessLevel`. Use this overload when
the async commit must pin a specific access mode regardless of the `UserModeDml_Enabled` flag —
framework utilities that own their lifecycle pass `AccessLevel.SYSTEM_MODE`, and the
`DML_Builder.async()` path passes the caller's chosen `AccessLevel` so subscriber `.withUserMode()`
opt-ins survive the sync-to-async boundary.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `operation` | [DML_Builder.DatabaseOperation](DML_Builder.DatabaseOperation.md) | The DML operation to perform (DML_INSERT, DML_UPDATE, DML_DELETE, DML_UPSERT, DML_UNDELETE). |
| `allOrNothing` | [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) | If true, the entire transaction rolls back on any failure; if false, allows partial success. |
| `accessLevel` | [AccessLevel](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexcode/apex_bulk_sharing_creating_with_apex.htm) | Explicit AccessLevel for the DML commit, or null to inherit the flag-driven default. |

**Example**

```apex
PROC_ExecuteDML processor = new PROC_ExecuteDML(DML_Builder.DatabaseOperation.DML_DELETE, true, AccessLevel.SYSTEM_MODE);
```

</div>

