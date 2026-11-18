---
title: "IF_Async.Finishable"
type: class
pageClass: reference
description: "Optional interface for logic that runs once, after all items are processed. Implement it for cleanup, a summary or a notification. What finish promises: It is called once, after the last chunk (a chun"
group: "Async Processing"
since: "1.0"
category: apex
---

# IF_Async.Finishable

**Class** · Group: `Async Processing`

<div class="apex-member apex-class">

```apex
global interface IF_Async.Finishable
```

Optional interface for logic that runs once, after all items are processed. Implement it for cleanup, a summary or a notification. What finish promises: It is called once, after the last chunk (a chunk is one group of items the job handles at a time). It is called only when every chunk ran without throwing an exception. When a chunk failed, finish is not called, and the job's log has an error entry for the failed chunk. Under BATCH, the log also has one warning that finish was skipped. Under CHAINABLE, the chain stops at the job that threw, so finish is never reached. If you need to do work when a chunk fails, do it in execute. A processor that catches its own errors in execute and goes on counts as having succeeded. It sees the values your execute built, such as a count or a list of record Ids, as fields of your class. To keep those values from one chunk to the next, a batch saves your whole class after every chunk. Keep those fields small (a count or a list of Ids, not whole records) and mark any cache transient so it is not saved. Salesforce cannot save some values between chunks, such as a compiled Pattern, a Matcher, an HttpRequest or a describe result. If a field of your class that is not static holds one of them under BATCH, the batch can fail. Build such a value inside execute, or mark the field transient. Under BATCH, context.getJobId() in finish is the batch job. Under CHAINABLE it is the last job of the chain. A processor that implements this interface cannot run as PARALLEL_QUEUEABLES. AUTO never picks it for one, and a request that forces it is refused: UTIL_AsynchronousJobLauncher.process throws an IllegalArgumentException and no job is started.

</div>

---

## Methods

| Method | Description |
|--------|-------------|
| global abstract void [finish](#finish)([Database.BatchableContext](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_interface_database_batchablecontext.htm) context) | Called once, after the last chunk, and only when every chunk ran without throwing an exception. |

### finish

<div class="apex-member">

```apex
global abstract void finish(Database.BatchableContext context)
```

Called once, after the last chunk, and only when every chunk ran without throwing an exception.
It sees the values your execute built.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `context` | [Database.BatchableContext](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_interface_database_batchablecontext.htm) | The BatchableContext providing job details, such as the job ID. |

</div>

