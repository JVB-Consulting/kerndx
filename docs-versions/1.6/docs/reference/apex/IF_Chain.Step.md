---
title: "IF_Chain.Step"
type: class
pageClass: reference
description: "Interface for defining the business logic of a single chain step. Each step receives a shared context and returns a result indicating success or failure."
since: "1.0"
category: apex
---

# IF_Chain.Step

**Class**

<div class="apex-member apex-class">

```apex
global interface IF_Chain.Step
```

**Known Derived Types:** [UTIL_AsyncChain.ApiStep](UTIL_AsyncChain.ApiStep.md), [UTIL_AsyncChain.ChainStep](UTIL_AsyncChain.ChainStep.md), [UTIL_AsyncChain.ApiStep.work(UTIL_AsyncChain.ChainContext)](UTIL_AsyncChain.ApiStep.md#work), [UTIL_AsyncChain.ChainStep.work(UTIL_AsyncChain.ChainContext)](UTIL_AsyncChain.ChainStep.md#work)

Interface for defining the business logic of a single chain step. Each step receives a shared context and returns a result indicating success or failure.

</div>

---

## Methods

| Method | Description |
|--------|-------------|
| global abstract [UTIL_AsyncChain.StepResult](UTIL_AsyncChain.StepResult.md) [work](#work)([UTIL_AsyncChain.ChainContext](UTIL_AsyncChain.ChainContext.md) context) | Executes the step's business logic within the chain. |

### work

<div class="apex-member">

```apex
global abstract UTIL_AsyncChain.StepResult work(UTIL_AsyncChain.ChainContext context)
```

Executes the step's business logic within the chain.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `context` | [UTIL_AsyncChain.ChainContext](UTIL_AsyncChain.ChainContext.md) | Shared chain context for reading/writing state between steps. |

**Returns** [UTIL_AsyncChain.StepResult](UTIL_AsyncChain.StepResult.md) — StepResult indicating success or failure of the step.

</div>

