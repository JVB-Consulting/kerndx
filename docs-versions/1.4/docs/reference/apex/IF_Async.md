---
title: "IF_Async"
type: class
pageClass: reference
description: "A container for shared global interfaces used by the asynchronous framework."
author: "Jason Van Beukering"
group: "Async Processing"
date: "September 2025, May 2026"
since: "1.0"
category: apex
---

# IF_Async

**Class** · Group: `Async Processing`

<div class="apex-member apex-class">

```apex
global inherited sharing class IF_Async
```

A container for shared global interfaces used by the asynchronous framework.

**Example**

```apex
public class MyProcessor implements IF_Async.Processable
{
    public void execute(List<Object> items)
    {
        // process items
    }
}
```

</div>

---

## Inner Classes

| Class | Description |
|-------|-------------|
| [AsynchronousExecutionStrategy](IF_Async.AsynchronousExecutionStrategy.md) | Enum defining different asynchronous execution strategies. |
| [Finishable](IF_Async.Finishable.md) | Optional interface for defining finalizer logic that runs after all data is processed. |
| [Processable](IF_Async.Processable.md) | Interface for defining the core processing logic to be executed by an asynchronous job. |

