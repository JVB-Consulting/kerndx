---
title: "IF_Async.AsynchronousExecutionStrategy"
type: class
pageClass: reference
description: "Enum defining different asynchronous execution strategies."
since: "1.0"
category: apex
---

# IF_Async.AsynchronousExecutionStrategy

**Class**

<div class="apex-member apex-class">

```apex
global enum IF_Async.AsynchronousExecutionStrategy
```

Enum defining different asynchronous execution strategies.

</div>

---

## Values

| Value | Description |
|----------|-------------|
| global  [AUTO](#auto) | Automatically decide between parallel, chainable, or batch based on data size and limits. |
| global  [BATCH](#batch) | Force batch execution regardless of data size. |
| global  [CHAINABLE](#chainable) | Force chainable queueable execution (single parent with chained children). |
| global  [PARALLEL_QUEUEABLES](#parallel_queueables) | Force parallel queueable execution (multiple queueables enqueued simultaneously). |

---

## Value Details

### AUTO

```apex
global AUTO
```

Automatically decide between parallel, chainable, or batch based on data size and limits.

### BATCH

```apex
global BATCH
```

Force batch execution regardless of data size.

### CHAINABLE

```apex
global CHAINABLE
```

Force chainable queueable execution (single parent with chained children).

### PARALLEL_QUEUEABLES

```apex
global PARALLEL_QUEUEABLES
```

Force parallel queueable execution (multiple queueables enqueued simultaneously).

