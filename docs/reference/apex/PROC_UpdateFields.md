---
title: "PROC_UpdateFields"
type: class
pageClass: reference
description: "Processor for bulk field updates using the adaptive async framework. Implements IF_Async.Processable to enable automatic selection between Queueable and Batch execution. Supports REPLACE, PREFIX, and "
author: "Jason Van Beukering"
group: "Bulk DML"
date: "February 2026, May 2026"
since: "1.0"
category: apex
---

# PROC_UpdateFields

**Class** · Group: `Bulk DML`

```apex
global inherited sharing class PROC_UpdateFields implements IF_Async.Processable
```

**Implements:** [IF_Async.Processable](IF_Async.Processable.md)

**Known Derived Types:** [IF_Async.Processable.execute(List<Object>)](IF_Async.Processable.md#execute)

Processor for bulk field updates using the adaptive async framework. Implements IF_Async.Processable to enable automatic selection between Queueable and Batch execution. Supports REPLACE, PREFIX, and SUFFIX update methods for flexible field value manipulation.

**Since:** 1.0

**Example:**

```apex
PROC_UpdateFields.DTO_Parameters params = new PROC_UpdateFields.DTO_Parameters();
params.objectName = 'Account';
PROC_UpdateFields.DTO_Field field = new PROC_UpdateFields.DTO_Field();
field.name = 'Description';
field.value = 'Updated via bulk processor';
params.updateFields.add(field);
PROC_UpdateFields processor = new PROC_UpdateFields(params);
```

**See Also:** [IF_Async.Processable](IF_Async.Processable.md), [UTIL_AsynchronousJobLauncher](UTIL_AsynchronousJobLauncher.md)

---

## Properties

| Property | Description |
|----------|-------------|
| global enum [FieldUpdateMethod](PROC_UpdateFields.FieldUpdateMethod.md) | Enum defining methods for updating SObject fields. |

## Methods

| Method | Description |
|--------|-------------|
| global [IF_Queryable](IF_Queryable.md) [buildQueryable](#buildqueryable)() | Builds a queryable for the configured object and fields. |
| global void [execute](#execute)([List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[Object](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_System_Object.htm)> items) | Executes the field update operation on the provided list of records. |
| global  [PROC_UpdateFields](#proc_updatefields)([PROC_UpdateFields.DTO_Parameters](PROC_UpdateFields.DTO_Parameters.md) parameters) | Constructs a field update processor with the specified parameters. |

## Inner Classes

| Class | Description |
|-------|-------------|
| [DTO_Field](PROC_UpdateFields.DTO_Field.md) | DTO representing a field to update on an SObject. |
| [DTO_Parameters](PROC_UpdateFields.DTO_Parameters.md) | DTO for parameters to query and update records. |

---

## Method Details

### PROC_UpdateFields

<div class="apex-member">

```apex
global PROC_UpdateFields(PROC_UpdateFields.DTO_Parameters parameters)
```

Constructs a field update processor with the specified parameters.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `parameters` | [PROC_UpdateFields.DTO_Parameters](PROC_UpdateFields.DTO_Parameters.md) | The parameters defining which fields to update and how. |

**Example**

```apex
PROC_UpdateFields.DTO_Parameters params = new PROC_UpdateFields.DTO_Parameters();
params.objectName = 'Account';
PROC_UpdateFields processor = new PROC_UpdateFields(params);
```

</div>

### buildQueryable

<div class="apex-member">

```apex
global IF_Queryable buildQueryable()
```

Builds a queryable for the configured object and fields.

**Returns** [IF_Queryable](IF_Queryable.md) — An IF_Queryable instance for retrieving records to update.

**Example**

```apex
PROC_UpdateFields.DTO_Parameters params = new PROC_UpdateFields.DTO_Parameters();
params.objectName = 'Account';
PROC_UpdateFields.DTO_Field field = new PROC_UpdateFields.DTO_Field();
field.name = 'Name';
params.updateFields.add(field);
IF_Queryable query = new PROC_UpdateFields(params).buildQueryable();
```

</div>

### execute

<div class="apex-member">

```apex
global void execute(List<Object> items)
```

Executes the field update operation on the provided list of records.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `items` | [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm) | The list of SObject records to update. |

**Example**

```apex
PROC_UpdateFields.DTO_Parameters params = new PROC_UpdateFields.DTO_Parameters();
PROC_UpdateFields.DTO_Field field = new PROC_UpdateFields.DTO_Field();
field.name = 'Name';
field.value = 'Updated';
params.updateFields.add(field);
List<Account> accounts = [SELECT Id, Name FROM Account LIMIT 100];
new PROC_UpdateFields(params).execute(accounts);
```

</div>

