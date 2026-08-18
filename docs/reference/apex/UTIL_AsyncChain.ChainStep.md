---
title: "UTIL_AsyncChain.ChainStep"
type: class
pageClass: reference
description: "Abstract base class for individual steps in an async chain. Each step runs in its own Queueable transaction, providing governor limit isolation."
since: "1.0"
category: apex
---

# UTIL_AsyncChain.ChainStep

**Class**

<div class="apex-member apex-class">

```apex
global inherited sharing abstract class UTIL_AsyncChain.ChainStep implements IF_Chain.Step
```

**Implements:** [IF_Chain.Step](IF_Chain.Step.md)

**Known Derived Types:** [UTIL_AsyncChain.ApiStep](UTIL_AsyncChain.ApiStep.md), [IF_Chain.Step.work(UTIL_AsyncChain.ChainContext)](IF_Chain.Step.md#work)

Abstract base class for individual steps in an async chain. Each step runs in its own Queueable transaction, providing governor limit isolation.

**Example**

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

</div>

---

## Methods

| Method | Description |
|--------|-------------|
| global virtual [UTIL_Retry.Strategy](UTIL_Retry.Strategy.md) [createRetryStrategy](#createretrystrategy)() | Optional per-step retry strategy. |
| global virtual [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) [isIdempotent](#isidempotent)() | Declares whether this step is safe to execute more than once — override to return true only when a repeat run of work() cannot double the step's side effects, either because the work is naturally idempotent or because the step guards itself (e.g. |
| global abstract [UTIL_AsyncChain.StepResult](UTIL_AsyncChain.StepResult.md) [work](#work)([UTIL_AsyncChain.ChainContext](UTIL_AsyncChain.ChainContext.md) context) | Execute the step's business logic. |

### createRetryStrategy

<div class="apex-member">

```apex
global virtual UTIL_Retry.Strategy createRetryStrategy()
```

Optional per-step retry strategy. Return null (the default) for no retry — a
failure is final on the first attempt, exactly as before this member existed. Retry TRANSIENT
failures only (locks, timeouts, 5xx-shaped results): compose
UTIL_Retry.retryOnlyOnException(...) / dontRetryOnException(...) so deterministic failures are
never re-burned; a validation error retried N times across a storm of trigger-spawned chains
costs async budget with zero chance of success. Steps that retry MUST be idempotent — pair with
ChainContext.idempotencyKey(). Exception filters match the failure's exception wherever one
exists: a step that THROWS and a step that RETURNS failed(exception) are filtered identically.
Only a message-only failed(message) carries no exception, so nothing but the attempt budget
gates it; a step that recognises a deterministic message-only failure should return
failedPermanently(...) instead, which refuses retry outright whatever this strategy answers.

A chain retrying enough to exhaust queueable stack depth degrades to Stalled and is
recovered by the watchdog from a fresh root. Backoff has whole-minute granularity — the
platform's delayed enqueue is minute-based, so any computed backoff over 0 seconds rounds UP
to the next full minute (a 2-second backoff waits ~1 minute; only withBaseBackoff(0)
re-enqueues immediately); do not expect sub-minute retry precision.

The backoff delay applies only to the retried attempt's enqueue: it fires exactly once, on
the retry itself, and the steps after a recovered retry run without any added delay. A chain
that has retried also carries increased queueable stack-depth headroom for the remainder of
its run — each retry link genuinely deepens the chain, so the extra depth stays available to
the hops that follow.

**Returns** [UTIL_Retry.Strategy](UTIL_Retry.Strategy.md) — The retry strategy for this step, or null (the default) for no retry.

</div>

### isIdempotent

<div class="apex-member">

```apex
global virtual Boolean isIdempotent()
```

Declares whether this step is safe to execute more than once — override to
return true only when a repeat run of work() cannot double the step's side effects, either
because the work is naturally idempotent or because the step guards itself (e.g. via
ChainContext.idempotencyKey()). Read on the instance the chain was built with, persisted
into the run's step log, and consulted by the Chain Monitor's retry-from-failed-step gate;
the default false keeps retry hidden until the author opts in. The declaration never
changes how the chain runs. It is a method rather than a field so the declaration needs no
constructor: the framework recreates every step by class name in each hop, and a step
class that declares its own constructor cannot be recreated across the package boundary.

**Returns** [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) — True when a repeat run of this step is safe; false (the default) otherwise.

**Example**

```apex
public override Boolean isIdempotent()
{
    return true;
}
```

</div>

### work

<div class="apex-member">

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

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `context` | [UTIL_AsyncChain.ChainContext](UTIL_AsyncChain.ChainContext.md) | Shared chain context for reading/writing state between steps. |

**Returns** [UTIL_AsyncChain.StepResult](UTIL_AsyncChain.StepResult.md) — StepResult indicating success or failure.

**Example**

```apex
public override UTIL_AsyncChain.StepResult work(UTIL_AsyncChain.ChainContext context)
{
    String previousValue = (String)context.get('inputKey');
    context.put('outputKey', 'processed');
    return UTIL_AsyncChain.succeeded('Done');
}
```

</div>

## Fields

| Field | Description |
|-------|-------------|
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [stepName](#stepname) | Optional step name for identification in logs and status. |

### stepName

```apex
global String stepName
```

**Type:** [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)

Optional step name for identification in logs and status.

