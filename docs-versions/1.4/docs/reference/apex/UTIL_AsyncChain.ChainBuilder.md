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
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [execute](#execute)() | Executes the chain with an auto-generated correlation ID. |
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [execute](#execute)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) correlationId) | Executes the chain with a caller-supplied correlation ID for log tracing. |
| global [UTIL_AsyncChain.ChainBuilder](UTIL_AsyncChain.ChainBuilder.md) [onComplete](#oncomplete)([IF_Chain.Step](IF_Chain.Step.md) completionHandlerStep) | Registers a completion handler step that executes ONLY when every step in the chain completes successfully. |
| global [UTIL_AsyncChain.ChainBuilder](UTIL_AsyncChain.ChainBuilder.md) [onError](#onerror)([IF_Chain.Step](IF_Chain.Step.md) errorHandlerStep) | Registers an error handler step that executes when any step fails (unless the failing step has continueOnError set to true). |
| global [UTIL_AsyncChain.ChainBuilder](UTIL_AsyncChain.ChainBuilder.md) [then](#then)([IF_Chain.Step](IF_Chain.Step.md) step) | Appends a step to the end of the chain. |
| global [UTIL_AsyncChain.ChainBuilder](UTIL_AsyncChain.ChainBuilder.md) [then](#then)([IF_Chain.Step](IF_Chain.Step.md) step, [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) continueOnError) | Appends a step to the chain with explicit control over error continuation. |
| global [UTIL_AsyncChain.ChainBuilder](UTIL_AsyncChain.ChainBuilder.md) [withAsyncOptions](#withasyncoptions)([AsyncOptions](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_System_AsyncOptions.htm) options) | Sets the AsyncOptions controlling queueable stack depth. |
| global [UTIL_AsyncChain.ChainBuilder](UTIL_AsyncChain.ChainBuilder.md) [withDelayMinutes](#withdelayminutes)([Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) minutes) | Defers the chain's first step by the given number of minutes. |
| global [UTIL_AsyncChain.ChainBuilder](UTIL_AsyncChain.ChainBuilder.md) [withInitialContext](#withinitialcontext)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) key, [Object](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_System_Object.htm) value) | Seeds the chain context with an initial key-value pair before execution begins. |
| global [UTIL_AsyncChain.ChainBuilder](UTIL_AsyncChain.ChainBuilder.md) [withMaxContextSize](#withmaxcontextsize)([Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) maximumSize) | Sets the maximum serialized context size in characters. |
| global [UTIL_AsyncChain.ChainBuilder](UTIL_AsyncChain.ChainBuilder.md) [withMaxSteps](#withmaxsteps)([Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) maximumSteps) | Sets the maximum number of steps the chain is allowed to execute. |

### execute

<div class="apex-member">

```apex
global String execute()
```

Executes the chain with an auto-generated correlation ID.
Persists the chain configuration and enqueues the first step.

**Returns** [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) — The ID of the AsyncChainExecution__c record tracking this chain.

**Throws**

| Exception | Description |
|-----------|-------------|
| [UTIL_Exceptions.IllegalStateException](UTIL_Exceptions.IllegalStateException.md) | If the serialized step list exceeds the StepLog__c field capacity less the per-step runtime reserve — see the correlation-ID overload this method delegates to. |

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

Executes the chain with a caller-supplied correlation ID for log tracing.
Persists the chain configuration and enqueues the first step.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `correlationId` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The correlation ID to attach to all log entries for this chain. |

**Returns** [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) — The ID of the AsyncChainExecution__c record tracking this chain.

**Throws**

| Exception | Description |
|-----------|-------------|
| [UTIL_Exceptions.IllegalStateException](UTIL_Exceptions.IllegalStateException.md) | If the serialized step list exceeds the StepLog__c field capacity less the per-step runtime reserve — a chain that cannot persist its step list intact for its whole life must fail at definition time, never by silently truncating the persisted JSON. |

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

Sets the AsyncOptions controlling queueable stack depth. When provided,
these options override the framework default (maximumQueueableStackDepth = steps.size() + 1).
In tests, pass options with an explicit maximumQueueableStackDepth matching the expected
chain depth to enable chained Queueable execution within Test.startTest/stopTest.

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

### withDelayMinutes

<div class="apex-member">

```apex
global UTIL_AsyncChain.ChainBuilder withDelayMinutes(Integer minutes)
```

Defers the chain's first step by the given number of minutes. This is best-effort:
the platform enqueues the first step with a Queueable delay, so the chain shows as Running with
zero completed steps in the Chain Monitor until the delay elapses, and the delay degrades to
immediate if the org has disabled Queueable delay. The value is clamped to the platform range
of 0 to 10 minutes; a null or zero delay is a no-op. Only the first step is delayed; every later
step runs as soon as its predecessor finishes.

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
This is additive — each call adds one key-value pair to the initial context map.

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

