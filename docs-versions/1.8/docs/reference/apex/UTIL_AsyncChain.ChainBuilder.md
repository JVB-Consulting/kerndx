---
title: "UTIL_AsyncChain.ChainBuilder"
type: class
pageClass: reference
description: "Fluent builder for configuring and executing an async chain. Provides methods for adding steps, setting context, configuring error/completion handlers, and executing the chain."
since: "1.0"
category: apex
---

# UTIL_AsyncChain.ChainBuilder

**Class**

<div class="apex-member apex-class">

```apex
global inherited sharing class UTIL_AsyncChain.ChainBuilder
```

Fluent builder for configuring and executing an async chain. Provides methods for adding steps, setting context, configuring error/completion handlers, and executing the chain.

**Example**

```apex
String executionId = UTIL_AsyncChain.newChain('OrderProcessing')
    .then(new ValidateOrderStep())
    .then(new ProcessPaymentStep())
    .withInitialContext('orderId', order.Id)
    .onError(new NotifyAdminStep())
    .onComplete(new SendConfirmationStep())
    .execute();
```

</div>

---

## Methods

| Method | Description |
|--------|-------------|
| global [UTIL_AsyncChain.ChainBuilder](UTIL_AsyncChain.ChainBuilder.md) [allowRestart](#allowrestart)() | Declares this chain safe to restart from its first step. |
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [execute](#execute)() | Executes the chain under a tracking id of its own, created by the framework. |
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [execute](#execute)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) correlationId) | Executes the chain under the supplied correlation id, which becomes the run's own tracking id. |
| global [UTIL_AsyncChain.ChainBuilder](UTIL_AsyncChain.ChainBuilder.md) [onComplete](#oncomplete)([IF_Chain.Step](IF_Chain.Step.md) completionHandlerStep) | Registers a completion handler step that executes ONLY when every step in the chain completes successfully. |
| global [UTIL_AsyncChain.ChainBuilder](UTIL_AsyncChain.ChainBuilder.md) [onError](#onerror)([IF_Chain.Step](IF_Chain.Step.md) errorHandlerStep) | Registers an error handler step that executes when any step fails (unless the failing step has continueOnError set to true). |
| global [UTIL_AsyncChain.ChainBuilder](UTIL_AsyncChain.ChainBuilder.md) [then](#then)([IF_Chain.Step](IF_Chain.Step.md) step) | Appends a step to the end of the chain. |
| global [UTIL_AsyncChain.ChainBuilder](UTIL_AsyncChain.ChainBuilder.md) [then](#then)([IF_Chain.Step](IF_Chain.Step.md) step, [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) continueOnError) | Appends a step to the chain with explicit control over error continuation. |
| global [UTIL_AsyncChain.ChainBuilder](UTIL_AsyncChain.ChainBuilder.md) [withAsyncOptions](#withasyncoptions)([AsyncOptions](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_System_AsyncOptions.htm) options) | Sets the AsyncOptions controlling queueable stack depth. |
| global [UTIL_AsyncChain.ChainBuilder](UTIL_AsyncChain.ChainBuilder.md) [withDeduplicationKey](#withdeduplicationkey)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) deduplicationKey) | Guards against two overlapping runs of the same logical chain. |
| global [UTIL_AsyncChain.ChainBuilder](UTIL_AsyncChain.ChainBuilder.md) [withDelayMinutes](#withdelayminutes)([Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) minutes) | Defers the chain's first step by the given number of minutes. |
| global [UTIL_AsyncChain.ChainBuilder](UTIL_AsyncChain.ChainBuilder.md) [withInitialContext](#withinitialcontext)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) key, [Object](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_System_Object.htm) value) | Seeds the chain context with an initial key-value pair before execution begins. |
| global [UTIL_AsyncChain.ChainBuilder](UTIL_AsyncChain.ChainBuilder.md) [withMaxContextSize](#withmaxcontextsize)([Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) maximumSize) | Sets the maximum serialized context size in characters. |
| global [UTIL_AsyncChain.ChainBuilder](UTIL_AsyncChain.ChainBuilder.md) [withMaxSteps](#withmaxsteps)([Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) maximumSteps) | Sets the maximum number of steps the chain is allowed to execute. |

### allowRestart

<div class="apex-member">

```apex
global UTIL_AsyncChain.ChainBuilder allowRestart()
```

Declares this chain safe to restart from its first step. A restart re-runs
EVERY step, so declare it only when the whole chain can run twice without doubling its
side effects. The declaration is written on the run record at start, together with a copy
of the initial context as the chain was built. The Chain Monitor offers its restart action
only for such runs. A restart uses that saved copy, never the changed context a partial run
left behind. It is off by default, so restart stays hidden until the author turns it on.
The declaration never changes how the chain runs.

**Returns** [UTIL_AsyncChain.ChainBuilder](UTIL_AsyncChain.ChainBuilder.md) — This builder, for chaining.

**Example**

```apex
String runId = UTIL_AsyncChain.newChain('NightlyAccountSync')
    .then(new SyncStep())
    .allowRestart()
    .execute();
```

</div>

### execute

<div class="apex-member">

```apex
global String execute()
```

Executes the chain under a tracking id of its own, created by the framework. The launching
transaction may already have an active correlation ID. If it does, the run records that ID as the one it was
launched under. It also keeps the transaction's root correlation ID (the ID of the action that started the
work), and writes one entry in the launcher's log that names the new run. If there is no active correlation
ID, the run starts its own action and is its own root. Saves the chain configuration and queues the first
step. A step or a handler of another chain may call this too; see the overload for what a launch from inside
a chain does.

**Returns** [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) — The ID of the AsyncChainExecution__c record tracking this chain.

**Throws**

| Exception | Description |
|-----------|-------------|
| [UTIL_Exceptions.IllegalStateException](UTIL_Exceptions.IllegalStateException.md) | If the serialized step list exceeds the StepLog__c field capacity less the per-step runtime reserve, or if a launch from inside a step or handler of another chain would nest too deep or find no room (see the correlation-ID overload this method delegates to). |

**Example**

```apex
String executionId = UTIL_AsyncChain.newChain('MyChain')
    .then(new MyStep())
    .execute();
```

</div>

<div class="apex-member">

```apex
global String execute(String correlationId)
```

Executes the chain under the supplied correlation id, which becomes the run's own tracking id.
The run records three things. First, the correlation ID active in this transaction, as the ID it was launched
under (null when none is active). Second, the transaction's root correlation ID (the ID of the action that
started the work) as its own root: the active correlation ID when no root exists yet, or the supplied ID when
neither exists. Third, the transaction's full logging context, stored under the supplied ID, so every step
logs with the run's ID and the action's root. A run launched while a correlation ID is active is announced
once in the launcher's log. Saves the chain configuration and queues the first step.

A run may be launched from inside a step, or from a completion or error handler, of another chain. Then it is
recorded with that run's id as the id it was launched under. It sits one level below that run (chains may nest
at most five levels deep). The launching run and step remember it, so a retry of that step gets the same run
back instead of a second one. A job started from inside a running job takes over that job's maximum queueable
stack depth and cannot set its own. So the first step of a chain launched this way runs under the launching
chain's maximum. The framework's default maximum leaves room for that. A launch that would find no room, or
would nest too deep, is refused before anything is written. One chain may be launched per step or handler.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `correlationId` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The correlation ID to attach to all log entries for this chain. |

**Returns** [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) — The ID of the AsyncChainExecution__c record tracking this chain.

**Throws**

| Exception | Description |
|-----------|-------------|
| [UTIL_Exceptions.IllegalStateException](UTIL_Exceptions.IllegalStateException.md) | If the serialized step list exceeds the StepLog__c field capacity less the per-step runtime reserve (a chain that cannot persist its step list intact for its whole life must fail at definition time, never by silently truncating the persisted JSON); or if the supplied correlation ID is already attached to another chain run, since a run owns its correlation exclusively; or if the launch runs inside a step or handler of another chain and would nest deeper than five levels, find no spare queueable stack level for its first step, follow another launch from the same step or handler in the same transaction, follow a queueable job that step or handler already added, or start a different chain from a step or handler that launched one before. |

**Example**

```apex
String executionId = UTIL_AsyncChain.newChain('MyChain')
    .then(new MyStep())
    .execute('my-correlation-id');
```

</div>

### onComplete

<div class="apex-member">

```apex
global UTIL_AsyncChain.ChainBuilder onComplete(IF_Chain.Step completionHandlerStep)
```

Registers a completion handler step that executes ONLY when every step in
the chain completes successfully. The completion handler does NOT run when the chain
terminates in failure (i.e. when a step returns a failed StepResult OR throws and the
step is not marked `continueOnError`).

**Failure-path handler is a separate registration.** To run a step on failure, register
an error handler via `.onError(...)`. The two handlers are mutually exclusive at runtime:
exactly one of them fires per chain (success → onComplete, failure → onError), and
neither fires if the chain is aborted by the framework kill switch. Subscribers needing
"always-runs" cleanup (e.g. release a row lock, close a session) should put the cleanup
inside the final step's `work()` body and use `continueOnError = true` on the step
before it, so the final step runs regardless of upstream failures.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `completionHandlerStep` | [IF_Chain.Step](IF_Chain.Step.md) | The IF_Chain.Step to execute on successful completion. |

**Returns** [UTIL_AsyncChain.ChainBuilder](UTIL_AsyncChain.ChainBuilder.md) — This ChainBuilder for method chaining.

**Example**

```apex
UTIL_AsyncChain.newChain('MyChain')
    .then(new ProcessStep())
    .onComplete(new SendConfirmationStep())   // success-only
    .onError(new NotifyAdminStep())           // failure-only
    .execute();
```

</div>

### onError

<div class="apex-member">

```apex
global UTIL_AsyncChain.ChainBuilder onError(IF_Chain.Step errorHandlerStep)
```

Registers an error handler step that executes when any step fails
(unless the failing step has continueOnError set to true).

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `errorHandlerStep` | [IF_Chain.Step](IF_Chain.Step.md) | The IF_Chain.Step to execute on failure. Receives the chain context with the failure details. |

**Returns** [UTIL_AsyncChain.ChainBuilder](UTIL_AsyncChain.ChainBuilder.md) — This ChainBuilder for method chaining.

**Example**

```apex
UTIL_AsyncChain.newChain('MyChain')
    .then(new RiskyStep())
    .onError(new NotifyAdminStep())
    .execute();
```

</div>

### then

<div class="apex-member">

```apex
global UTIL_AsyncChain.ChainBuilder then(IF_Chain.Step step)
```

Appends a step to the end of the chain.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `step` | [IF_Chain.Step](IF_Chain.Step.md) | The IF_Chain.Step implementation to add. |

**Returns** [UTIL_AsyncChain.ChainBuilder](UTIL_AsyncChain.ChainBuilder.md) — This ChainBuilder for method chaining.

**Example**

```apex
UTIL_AsyncChain.newChain('MyChain')
    .then(new FirstStep())
    .then(new SecondStep())
    .execute();
```

</div>

<div class="apex-member">

```apex
global UTIL_AsyncChain.ChainBuilder then(IF_Chain.Step step, Boolean continueOnError)
```

Appends a step to the chain with explicit control over error continuation.
Use this overload for IF_Chain.Step implementations that cannot extend ChainStep.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `step` | [IF_Chain.Step](IF_Chain.Step.md) | The IF_Chain.Step implementation to add. |
| `continueOnError` | [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) | When true, the chain continues past this step's failure. |

**Returns** [UTIL_AsyncChain.ChainBuilder](UTIL_AsyncChain.ChainBuilder.md) — This ChainBuilder for method chaining.

**Example**

```apex
UTIL_AsyncChain.newChain('MyChain')
    .then(new CriticalStep())
    .then(new OptionalStep(), true)
    .then(new FinalStep())
    .execute();
```

</div>

### withAsyncOptions

<div class="apex-member">

```apex
global UTIL_AsyncChain.ChainBuilder withAsyncOptions(AsyncOptions options)
```

Sets the AsyncOptions controlling queueable stack depth. When provided, these options override
the framework's default maximum. The default is one level per step, one for the first hop, and five more for
the chains those steps may launch. Inside a chain, it is counted from the launching job's depth.
In tests, pass options with an explicit maximumQueueableStackDepth that matches the expected chain depth, so
the queued jobs run one after another within Test.startTest/stopTest.
Inside a step or a handler of another chain, the options apply from the chain's second hop on. The first hop
uses the launching chain's maximum, because the platform does not let a running job change it. So a
duplicateSignature set here is not applied to that hop. The platform keeps counting depth from the launching
job's depth. So a maximum set here for a chain launched from a step must include that depth, as the
framework's default does. A maximum sized for a launch outside any chain runs out at a later hop and stalls
the run.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `options` | [AsyncOptions](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_System_AsyncOptions.htm) | The AsyncOptions to use for queueable enqueuing. |

**Returns** [UTIL_AsyncChain.ChainBuilder](UTIL_AsyncChain.ChainBuilder.md) — This ChainBuilder for method chaining.

**Example**

```apex
AsyncOptions options = new AsyncOptions();
options.maximumQueueableStackDepth = 4;
UTIL_AsyncChain.newChain('MyChain')
    .then(new Step1()).then(new Step2()).then(new Step3())
    .withAsyncOptions(options)
    .execute();
```

</div>

### withDeduplicationKey

<div class="apex-member">

```apex
global UTIL_AsyncChain.ChainBuilder withDeduplicationKey(String deduplicationKey)
```

Guards against two overlapping runs of the same logical chain. While a run holds
the key, a second execute() with the same key returns the active run's Id instead of starting
a duplicate. Any terminal status releases the key in the same update, so running the chain
again after it ends is allowed on purpose. A Stalled run still holds its key until it is
recovered or resolved. The key is stored exactly as given. The platform's unique text field
ignores case, so keys that differ only in case clash. Chains with no steps complete at once
and never hold a key. This is not the same as ChainContext.idempotencyKey(), which makes
replay-safe keys for your own step side effects. This method stops a second run from
starting at all.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `deduplicationKey` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | Non-blank key, at most 255 characters: for example a schedule name or a template like 'nightly-sync-' + recordId. |

**Returns** [UTIL_AsyncChain.ChainBuilder](UTIL_AsyncChain.ChainBuilder.md) — This builder, for chaining.

**Example**

```apex
String runId = UTIL_AsyncChain.newChain('NightlyAccountSync')
    .then(new SyncStep())
    .withDeduplicationKey('nightly-account-sync')
    .execute();
```

</div>

### withDelayMinutes

<div class="apex-member">

```apex
global UTIL_AsyncChain.ChainBuilder withDelayMinutes(Integer minutes)
```

Defers the chain's first step by the given number of minutes. This is best-effort:
the platform enqueues the first step with a Queueable delay, so the chain shows as Running with
zero completed steps in the Chain Monitor until the delay ends. If the org has turned off
Queueable delay, the first step runs at once instead. The value is kept within the platform range
of 0 to 10 minutes; a null or zero delay is a no-op. Only the first step is delayed; every later
step runs as soon as the step before it finishes.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `minutes` | [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) | The delay before the first step, in minutes (clamped to 0 to 10). Null is a no-op. |

**Returns** [UTIL_AsyncChain.ChainBuilder](UTIL_AsyncChain.ChainBuilder.md) — This ChainBuilder for method chaining.

**Example**

```apex
UTIL_AsyncChain.newChain('NightlyRollup')
    .then(new AggregateStep())
    .withDelayMinutes(5)
    .execute();
```

</div>

### withInitialContext

<div class="apex-member">

```apex
global UTIL_AsyncChain.ChainBuilder withInitialContext(String key, Object value)
```

Seeds the chain context with an initial key-value pair before execution begins.
Each call adds one more key-value pair to the initial context map.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `key` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The context key. |
| `value` | [Object](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_System_Object.htm) | The context value. |

**Returns** [UTIL_AsyncChain.ChainBuilder](UTIL_AsyncChain.ChainBuilder.md) — This ChainBuilder for method chaining.

**Example**

```apex
UTIL_AsyncChain.newChain('MyChain')
    .withInitialContext('recordId', record.Id)
    .withInitialContext('batchSize', 200)
    .then(new ProcessStep())
    .execute();
```

</div>

### withMaxContextSize

<div class="apex-member">

```apex
global UTIL_AsyncChain.ChainBuilder withMaxContextSize(Integer maximumSize)
```

Sets the maximum serialized context size in characters.
Prevents context overflow from storing large object graphs. Default: 32768.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `maximumSize` | [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) | The maximum context size in characters. |

**Returns** [UTIL_AsyncChain.ChainBuilder](UTIL_AsyncChain.ChainBuilder.md) — This ChainBuilder for method chaining.

**Example**

```apex
UTIL_AsyncChain.newChain('LargeContextChain')
    .withMaxContextSize(65536)
    .then(new DataHeavyStep())
    .execute();
```

</div>

### withMaxSteps

<div class="apex-member">

```apex
global UTIL_AsyncChain.ChainBuilder withMaxSteps(Integer maximumSteps)
```

Sets the maximum number of steps the chain is allowed to execute.
Prevents runaway chains from consuming unlimited resources. Default: 50.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `maximumSteps` | [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) | The maximum number of steps permitted. |

**Returns** [UTIL_AsyncChain.ChainBuilder](UTIL_AsyncChain.ChainBuilder.md) — This ChainBuilder for method chaining.

**Example**

```apex
UTIL_AsyncChain.newChain('ShortChain')
    .withMaxSteps(10)
    .then(new MyStep())
    .execute();
```

</div>

