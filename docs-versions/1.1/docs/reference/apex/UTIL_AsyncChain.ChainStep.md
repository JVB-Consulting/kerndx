---
title: "UTIL_AsyncChain.ChainStep"
type: class
description: "Abstract base class for individual steps in an async chain. Each step runs in its own Queueable transaction, providing governor limit isolation."
since: "1.0"
category: apex
---

# UTIL_AsyncChain.ChainStep

**Class**

```apex
global inherited sharing abstract class UTIL_AsyncChain.ChainStep implements IF_Chain.Step
```

**Implements:** [IF_Chain.Step](IF_Chain.Step.md)

**Known Derived Types:** [UTIL_AsyncChain.ApiStep](UTIL_AsyncChain.ApiStep.md), [IF_Chain.Step.work(UTIL_AsyncChain.ChainContext)](IF_Chain.Step.md#work)

Abstract base class for individual steps in an async chain. Each step runs in its own Queueable transaction, providing governor limit isolation.

**Since:** 1.0

**Example:**

```apex
public class LoadDataStep extends UTIL_AsyncChain.ChainStep
{
    public override UTIL_AsyncChain.StepResult work(UTIL_AsyncChain.ChainContext context)
    {
        List<Account> accounts = new SEL_Account().toList();
        context.put('accountCount', accounts.size());
        return UTIL_AsyncChain.succeeded('Loaded ' + accounts.size() + ' accounts');
    }
}
```

---

## Fields

| Field | Description |
|-------|-------------|
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [stepName](#stepname) | Optional step name for identification in logs and status. |

## Methods

| Method | Description |
|--------|-------------|
| global abstract [UTIL_AsyncChain.StepResult](UTIL_AsyncChain.StepResult.md) [work](#work)([UTIL_AsyncChain.ChainContext](UTIL_AsyncChain.ChainContext.md) context) | Execute the step's business logic. |

---

## Method Details

### work

```apex
global abstract UTIL_AsyncChain.StepResult work(UTIL_AsyncChain.ChainContext context)
```

Execute the step's business logic.
Each step runs in its own Queueable transaction, so callouts and DML are both permitted.
However, standard Apex ordering rules still apply WITHIN a step: perform all callouts
before any DML. A step that does DML then a callout will throw CalloutException.

**Do not call `UTIL_AsyncChain.newChain(...).execute()` from inside this method.** Async
chains do not support nested execution. The inner chain consumes Queueable stack-depth
budget against the outer chain (capped by `AsyncOptions.maximumQueueableStackDepth`,
default 50), and ChainContext writes happen on the OUTER chain's `AsyncChainExecution__c`
row only — the inner chain has its own row, totally disconnected. Either add the inner
steps to the parent chain via `.then(...)` or enqueue a separate Queueable from outside
the chain (e.g. from `onComplete`'s handler step) that targets a fresh chain.

**Parameters:**

- `context` ([UTIL_AsyncChain.ChainContext](UTIL_AsyncChain.ChainContext.md)) - Shared chain context for reading/writing state between steps.

**Returns:** [UTIL_AsyncChain.StepResult](UTIL_AsyncChain.StepResult.md) - StepResult indicating success or failure.

**Since:** 1.0

**Example:**

```apex
public override UTIL_AsyncChain.StepResult work(UTIL_AsyncChain.ChainContext context)
{
    String previousValue = (String)context.get('inputKey');
    context.put('outputKey', 'processed');
    return UTIL_AsyncChain.succeeded('Done');
}
```

---

## Field Details

### stepName

```apex
global String stepName
```

**Type:** [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)

Optional step name for identification in logs and status.

**Since:** 1.0

