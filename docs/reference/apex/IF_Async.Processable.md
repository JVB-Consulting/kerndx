---
title: "IF_Async.Processable"
type: class
description: "Interface for defining the core processing logic to be executed by an asynchronous job."
since: "1.0"
category: apex
---

# IF_Async.Processable

**Class**

```apex
global interface IF_Async.Processable
```

**Known Derived Types:** [PROC_ExecuteDML](PROC_ExecuteDML.md), [PROC_UpdateFields](PROC_UpdateFields.md), [PROC_ExecuteDML.execute(List<Object>)](PROC_ExecuteDML.md#execute), [PROC_UpdateFields.execute(List<Object>)](PROC_UpdateFields.md#execute)

Interface for defining the core processing logic to be executed by an asynchronous job.

**Since:** 1.0

---

## Methods

| Method | Description |
|--------|-------------|
| global abstract void [execute](#execute)([List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[Object](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_System_Object.htm)> items) | Executes the business logic on a list of items. |

---

## Method Details

### execute

```apex
global abstract void execute(List<Object> items)
```

Executes the business logic on a list of items.

**Parameters:**

- `items` ([List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)) - The list of objects to process in the current transaction.

**Since:** 1.0

