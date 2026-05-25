---
title: "IF_Async.Finishable"
type: class
description: "Optional interface for defining finalizer logic that runs after all data is processed. Implement this for cleanup or notification actions."
since: "1.0"
category: apex
---

# IF_Async.Finishable

**Class**

```apex
global interface IF_Async.Finishable
```

Optional interface for defining finalizer logic that runs after all data is processed. Implement this for cleanup or notification actions.

**Since:** 1.0

---

## Methods

| Method | Description |
|--------|-------------|
| global abstract void [finish](#finish)([Database.BatchableContext](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_interface_database_batchablecontext.htm) context) | Called once after all chunks are processed, for cleanup or notifications. |

---

## Method Details

### finish

```apex
global abstract void finish(Database.BatchableContext context)
```

Called once after all chunks are processed, for cleanup or notifications.

**Parameters:**

- `context` ([Database.BatchableContext](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_interface_database_batchablecontext.htm)) - The BatchableContext providing job details, such as the job ID.

**Since:** 1.0

