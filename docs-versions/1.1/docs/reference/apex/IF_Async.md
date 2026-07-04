---
title: "IF_Async"
type: class
description: "A container for shared global interfaces used by the asynchronous framework."
author: "Jason Van Beukering"
group: "Async Processing"
date: "September 2025, May 2026"
since: "1.0"
category: apex
---

# IF_Async

**Class** · Group: `Async Processing`

```apex
global inherited sharing class IF_Async
```

A container for shared global interfaces used by the asynchronous framework.

**Since:** 1.0

**Example:**

```apex
public class MyProcessor implements IF_Async.Processable
{
    public void execute(List<Object> items)
    {
        // process items
    }
}
```

---

## Properties

| Property | Description |
|----------|-------------|
| global enum [AsynchronousExecutionStrategy](IF_Async.AsynchronousExecutionStrategy.md) | Enum defining different asynchronous execution strategies. |
| global interface [Finishable](IF_Async.Finishable.md) | Optional interface for defining finalizer logic that runs after all data is processed. |
| global interface [Processable](IF_Async.Processable.md) | Interface for defining the core processing logic to be executed by an asynchronous job. |

