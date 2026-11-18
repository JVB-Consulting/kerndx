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
| global virtual [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) [isIdempotent](#isidempotent)() | Declares whether this step is safe to execute more than once. |
| global abstract [UTIL_AsyncChain.StepResult](UTIL_AsyncChain.StepResult.md) [work](#work)([UTIL_AsyncChain.ChainContext](UTIL_AsyncChain.ChainContext.md) context) | Execute the step's business logic. |

### createRetryStrategy

<div class="apex-member">

```apex
global virtual UTIL_Retry.Strategy createRetryStrategy()
```

Optional per-step retry strategy. Return null (the default) for no retry: a
failure is final on the first attempt. Retry only TRANSIENT failures, the kind that may pass on
a second try (locks, timeouts, 5xx-style results). Combine
UTIL_Retry.retryOnlyOnException(...) / dontRetryOnException(...) so a failure that will always
happen again is never retried. A validation error retried N times, across many chains started
by a trigger at once, uses up async budget with no chance of success. Steps that retry MUST be
idempotent (safe to run more than once): use ChainContext.idempotencyKey(). Exception filters
match the failure's exception wherever there is one: a step that THROWS and a step that RETURNS
failed(exception) are filtered the same way. Only a failed(message) with no exception has
nothing to filter, so only the attempt budget limits it. A step that knows a message-only
failure will always happen again should return failedPermanently(...) instead. That refuses
any retry, whatever this strategy answers.

A chain that retries so often that it uses up the queueable stack depth becomes Stalled, and
the watchdog recovers it from a new first job. Backoff works in whole minutes. The platform's
delayed enqueue counts in minutes, so any backoff over 0 seconds is rounded UP to the next full
minute (a 2-second backoff waits about 1 minute; only withBaseBackoff(0) queues the step again
at once). Do not expect retry timing finer than a minute.

The backoff delay applies only when the retried attempt is queued. It happens exactly once, on
the retry itself, and the steps after a successful retry run with no added delay. A chain that
has retried also has more room in the queueable stack depth for the rest of its run. Each retry
really adds one more job to the jobs queued one from another, so the extra depth stays available to the hops that
follow.

**Returns** [UTIL_Retry.Strategy](UTIL_Retry.Strategy.md) — The retry strategy for this step, or null (the default) for no retry.

</div>

### isIdempotent

<div class="apex-member">

```apex
global virtual Boolean isIdempotent()
```

Declares whether this step is safe to execute more than once. Override it to
return true only when a repeat run of work() cannot double the step's side effects, either
because the work is naturally idempotent or because the step guards itself (e.g. via
ChainContext.idempotencyKey()). The answer is read on the instance the chain was built with
and saved in the run's step log. Two readers use it. The Chain Monitor shows retry from the
failed step only for a step that declares itself idempotent. The watchdog uses it when a
chain stalls on a step that had started and left no saved result: it runs the step again
only if the step declares itself idempotent. Otherwise it ends the chain as Failed with a
reason that names the step, because the step may already have done its work. The default
false keeps retry hidden, and that second run off, until the author chooses otherwise. An
ApiStep does not use this default: it answers for itself from its handler's request (see
ApiStep). The declaration never changes how a healthy chain runs. It is a method rather than
a field, so the declaration needs no constructor. The framework creates every step again by
class name in each hop, and the package cannot create a step class that declares its own
constructor.

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

**A step may start another chain** by calling `UTIL_AsyncChain.newChain(...).execute()` inside
this method. The new chain is a run of its own, with its own `AsyncChainExecution__c` record and
its own tracking id. It records the parent run's correlation ID as the ID it was launched under,
and keeps the parent's root correlation ID, so its log entries can be followed from the parent.
What to expect:

- The new chain runs later, in jobs of its own. The step does not wait for it, and its result
does not change this step's result.

- It has its own ChainContext. Values it writes never reach this chain's context, and this
chain's context is not passed to it; use withInitialContext(...) to hand it values.

- A step may start one chain. A second launch from the same step in the same transaction is
refused with an IllegalStateException. When this step runs again (a retry or a re-drive) and
the launch sets no deduplication key of its own, the same launch returns the chain the step
started before instead of starting a second one. If the run again launches a chain with a
different name, the launch is refused with an IllegalStateException, because one step
starts one chain.

- Chains may nest at most five levels deep. A launch that would nest deeper, that finds no free
queueable stack level, or that comes after the step already added a queueable job of its own,
is refused with an IllegalStateException before anything is written.

- The new chain's first step runs under this chain's maximum queueable stack depth. The
framework's default leaves room for that. If you pass your own AsyncOptions to the new chain,
its maximum must include the depth the launching job already runs at.

If the new chain's steps belong to this work, add them to this chain with `.then(...)` instead.

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

