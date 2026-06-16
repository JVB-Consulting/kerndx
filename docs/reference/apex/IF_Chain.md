---
title: "IF_Chain"
type: class
pageClass: reference
description: "A container for shared global interfaces used by the async chain orchestration framework. Subscribers implement these interfaces to define chain step logic and conditional branching."
author: "Jason Van Beukering"
group: "Async"
date: "April 2026, May 2026"
since: "1.0"
category: apex
---

# IF_Chain

**Class** · Group: `Async`

<div class="apex-member apex-class">

```apex
global inherited sharing class IF_Chain
```

A container for shared global interfaces used by the async chain orchestration framework. Subscribers implement these interfaces to define chain step logic and conditional branching.

**Example**

```apex
public class MyStep implements IF_Chain.Step
{
    public UTIL_AsyncChain.StepResult work(UTIL_AsyncChain.ChainContext context)
    {
        context.put('result', 'done');
        return UTIL_AsyncChain.succeeded('Step completed');
    }
}
```

**See Also:** [UTIL_AsyncChain](UTIL_AsyncChain.md)

</div>

---

## Properties

| Property | Description |
|----------|-------------|
| global interface [Step](IF_Chain.Step.md) | Interface for defining the business logic of a single chain step. |

