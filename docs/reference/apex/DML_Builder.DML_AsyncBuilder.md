---
title: "DML_Builder.DML_AsyncBuilder"
type: class
pageClass: reference
description: "Runs DML in an async job. It groups the registered operations by type and hands them to PROC_ExecuteDML through UTIL_AsynchronousJobLauncher, which picks a Queueable or Batch job to suit the volume. I"
since: "1.0"
category: apex
---

# DML_Builder.DML_AsyncBuilder

**Class**

<div class="apex-member apex-class">

```apex
global class DML_Builder.DML_AsyncBuilder
```

Runs DML in an async job. It groups the registered operations by type and hands them to PROC_ExecuteDML through UTIL_AsynchronousJobLauncher, which picks a Queueable or Batch job to suit the volume. It carries these settings of the parent builder into the job: access mode, partial success, ignoring sharing, expected refusals and the row-lock retry count. The job enforces record sharing unless .bypassSharing() was called. The job itself runs without sharing, so inherited sharing cannot be used.

</div>

---

## Methods

| Method | Description |
|--------|-------------|
| global void [execute](#execute)() | Enqueues the registered DML operations for asynchronous execution. |
| global [DML_Builder.DML_AsyncBuilder](DML_Builder.DML_AsyncBuilder.md) [withBatchSize](#withbatchsize)([Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) batchSize) | Sets the batch size for async processing. |

### execute

<div class="apex-member">

```apex
global void execute()
```

Enqueues the registered DML operations for asynchronous execution.
Groups records by operation type and launches one async job per type.

**Example**

```apex
DML_Builder.newTransaction()
    .doUpdate(records)
    .allowPartial()
    .async()
    .execute();
```

</div>

### withBatchSize

<div class="apex-member">

```apex
global DML_Builder.DML_AsyncBuilder withBatchSize(Integer batchSize)
```

Sets the batch size for async processing.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `batchSize` | [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) | The number of records to process per batch/queueable execution. |

**Returns** [DML_Builder.DML_AsyncBuilder](DML_Builder.DML_AsyncBuilder.md) — This DML_AsyncBuilder instance for fluent chaining.

**Example**

```apex
DML_Builder.newTransaction()
    .doDelete(records)
    .async()
    .withBatchSize(200)
    .execute();
```

</div>

