---
title: "UTIL_AsyncChain.ApiStep"
type: class
pageClass: reference
description: "Chain step adapter that executes any API_Outbound handler as part of an async chain. Wraps the full web service lifecycle (validation, callout, response parsing, DML, ApiCall__c persistence) via UTIL_"
since: "1.0"
category: apex
---

# UTIL_AsyncChain.ApiStep

**Class**

<div class="apex-member apex-class">

```apex
global inherited sharing class UTIL_AsyncChain.ApiStep extends UTIL_AsyncChain.ChainStep
```

**Extends:** [UTIL_AsyncChain.ChainStep](UTIL_AsyncChain.ChainStep.md)

**Known Derived Types:** [IF_Chain.Step.work(UTIL_AsyncChain.ChainContext)](IF_Chain.Step.md#work)

Chain step adapter that executes any API_Outbound handler as part of an async chain. Wraps the full web service lifecycle (validation, callout, response parsing, DML, ApiCall__c persistence) via UTIL_HttpClient delegation mode, allowing existing outbound services to run inside chains with zero changes to the service class. Configuration is stored in the ChainContext (not on the step instance) because steps are serialized as class names and instantiated via reflection. At build-time, the ChainBuilder calls writeConfig() to persist the step's configuration into the initial context. At execution-time, work() reads the configuration back from the context using the current step index. A chain can stall in the middle of this step: for example, Salesforce ends the step's job after the request went out and before the result was saved. The chain's watchdog, the scheduled job that finds stuck chains, then runs the step again only when its request is safe to send twice: the handler's getHttpMethod() is GET, PUT or DELETE, or the handler's API setting has Idempotency Enabled, so every attempt carries an Idempotency-Key. Any other API step ends the chain as Failed, with a reason that names the step, because the external system may already have acted on the request. An API step whose request is safe to send twice can also be retried from the Chain Monitor after it fails. The step decides this when the chain is built, so it cannot see a createRequest() override that removes the Idempotency-Key header: for such a handler, do not rely on Idempotency Enabled.

**Example**

```apex
UTIL_AsyncChain.newChain('OrderProcessing')
    .withInitialContext('orderId', order.Id)
    .then(new UTIL_AsyncChain.ApiStep(API_ChargePayment.class)
        .triggeringRecordFrom('orderId')
        .withParameter(API_ChargePayment.PARAM_AMOUNT, '99.99'))
    .then(new UTIL_AsyncChain.ApiStep(API_SendConfirmation.class)
        .triggeringRecordFrom('orderId')
        .withParameterFrom('recipient', 'customerEmail'))
    .onError(new NotifyAdminStep())
    .execute();
```

</div>

---

## Methods

| Method | Description |
|--------|-------------|
| global [UTIL_AsyncChain.ApiStep](UTIL_AsyncChain.ApiStep.md) [credential](#credential)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) namedCredential) | Overrides the Named Credential used for this API call. |
| global [UTIL_AsyncChain.ApiStep](UTIL_AsyncChain.ApiStep.md) [retryOn](#retryon)([Set](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_set.htm)<[Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm)> statusCodes) | Restricts chain-level retry to the given HTTP status codes. |
| global [UTIL_AsyncChain.ApiStep](UTIL_AsyncChain.ApiStep.md) [triggeringRecord](#triggeringrecord)([Id](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_id.htm) recordId) | Sets a static triggering record ID for this API call. |
| global [UTIL_AsyncChain.ApiStep](UTIL_AsyncChain.ApiStep.md) [triggeringRecordFrom](#triggeringrecordfrom)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) contextKey) | Sets the triggering record ID from a ChainContext key, resolved at execution-time. |
| global [UTIL_AsyncChain.ApiStep](UTIL_AsyncChain.ApiStep.md) [withParameter](#withparameter)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) name, [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) value) | Adds a static parameter value to pass to the handler. |
| global [UTIL_AsyncChain.ApiStep](UTIL_AsyncChain.ApiStep.md) [withParameterFrom](#withparameterfrom)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) parameterName, [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) contextKey) | Maps a handler parameter to a ChainContext key, resolved at execution-time. |
| global [UTIL_AsyncChain.ApiStep](UTIL_AsyncChain.ApiStep.md) [withRetry](#withretry)([Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) maxAttempts, [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) baseBackoffSeconds) | Opt-in chain-level retry for this API step. |
| global override [UTIL_AsyncChain.StepResult](UTIL_AsyncChain.StepResult.md) [work](#work)([UTIL_AsyncChain.ChainContext](UTIL_AsyncChain.ChainContext.md) context) | Executes the API_Outbound handler via UTIL_HttpClient delegation mode. |

### credential

<div class="apex-member">

```apex
global UTIL_AsyncChain.ApiStep credential(String namedCredential)
```

Overrides the Named Credential used for this API call.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `namedCredential` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The Named Credential developer name. |

**Returns** [UTIL_AsyncChain.ApiStep](UTIL_AsyncChain.ApiStep.md) — This ApiStep for method chaining.

**Example**

```apex
new UTIL_AsyncChain.ApiStep(API_SendEmail.class)
    .credential('AlternateGateway')
```

</div>

### retryOn

<div class="apex-member">

```apex
global UTIL_AsyncChain.ApiStep retryOn(Set<Integer> statusCodes)
```

Restricts chain-level retry to the given HTTP status codes. It is the ApiStep
version of UTIL_HttpClient's retryOn. A failed call whose status is outside the set is
declared permanently failed: the chain fails on that attempt without spending the
remaining retry budget, because the status shows the failure will happen again on every try (a 400
returns 400 however often it is re-sent). Without this call every failed status
retries, except a 500, 502 or 504 to a request that is not safe to repeat (see
withRetry). A status named here is re-run whatever the method, a 500, 502 or 504 to a
POST with no Idempotency-Key included: naming it accepts that the external system may
act on the request twice. The one exception is a UTIL_Exceptions.PermanentFailureException
thrown by the handler: it says the call must never be retried, so the step fails for good
whatever this set holds. A failure with no status code at all (the transport threw
before any response arrived) is re-run for a GET, PUT or DELETE, for a request sent
with an Idempotency-Key and for a callout the platform refused before it left the org;
for a POST or PATCH with no Idempotency-Key it fails at once whatever this set holds,
as does a failure after the external system accepted such a request. So passing an
empty set on purpose stops every failure that has a status code from retrying. Has no
effect unless withRetry(...) enabled chain-level retry, matching the UTIL_HttpClient family.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `statusCodes` | [Set](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_set.htm) | The status codes eligible for retry. |

**Returns** [UTIL_AsyncChain.ApiStep](UTIL_AsyncChain.ApiStep.md) — This ApiStep for method chaining.

**Example**

```apex
new UTIL_AsyncChain.ApiStep(API_ChargePayment.class)
    .withRetry(3, 30)
    .retryOn(new Set<Integer> {500, 503})
```

</div>

### triggeringRecord

<div class="apex-member">

```apex
global UTIL_AsyncChain.ApiStep triggeringRecord(Id recordId)
```

Sets a static triggering record ID for this API call.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `recordId` | [Id](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_id.htm) | The Salesforce record ID. |

**Returns** [UTIL_AsyncChain.ApiStep](UTIL_AsyncChain.ApiStep.md) — This ApiStep for method chaining.

**Example**

```apex
new UTIL_AsyncChain.ApiStep(API_SendEmail.class)
    .triggeringRecord(account.Id)
```

</div>

### triggeringRecordFrom

<div class="apex-member">

```apex
global UTIL_AsyncChain.ApiStep triggeringRecordFrom(String contextKey)
```

Sets the triggering record ID from a ChainContext key, resolved at execution-time.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `contextKey` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The ChainContext key containing the record ID. |

**Returns** [UTIL_AsyncChain.ApiStep](UTIL_AsyncChain.ApiStep.md) — This ApiStep for method chaining.

**Example**

```apex
new UTIL_AsyncChain.ApiStep(API_ChargePayment.class)
    .triggeringRecordFrom('orderId')
```

</div>

### withParameter

<div class="apex-member">

```apex
global UTIL_AsyncChain.ApiStep withParameter(String name, String value)
```

Adds a static parameter value to pass to the handler.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `name` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The parameter name (use the handler's PARAM_* constants). |
| `value` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The parameter value. |

**Returns** [UTIL_AsyncChain.ApiStep](UTIL_AsyncChain.ApiStep.md) — This ApiStep for method chaining.

**Example**

```apex
new UTIL_AsyncChain.ApiStep(API_ChargePayment.class)
    .withParameter(API_ChargePayment.PARAM_AMOUNT, '99.99')
    .withParameter(API_ChargePayment.PARAM_CURRENCY, 'USD')
```

</div>

### withParameterFrom

<div class="apex-member">

```apex
global UTIL_AsyncChain.ApiStep withParameterFrom(String parameterName, String contextKey)
```

Maps a handler parameter to a ChainContext key, resolved at execution-time.
Use this when the parameter value is produced by a prior step in the chain.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `parameterName` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The handler parameter name. |
| `contextKey` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The ChainContext key to read the value from. |

**Returns** [UTIL_AsyncChain.ApiStep](UTIL_AsyncChain.ApiStep.md) — This ApiStep for method chaining.

**Example**

```apex
new UTIL_AsyncChain.ApiStep(API_SendConfirmation.class)
    .withParameterFrom('recipient', 'customerEmail')
```

</div>

### withRetry

<div class="apex-member">

```apex
global UTIL_AsyncChain.ApiStep withRetry(Integer maxAttempts, Integer baseBackoffSeconds)
```

Opt-in chain-level retry for this API step. When configured, the chain re-runs
the whole step (a fresh callout) with exponential backoff, and the outbound engine's own
NextRetry__c rescheduling is turned off for calls made by this step, so only one part of the
framework decides retries, never two. The chain does not re-run the step when the external system may
already have acted on a request that is not safe to repeat, which is a POST or PATCH sent
with no Idempotency-Key: when the call got no response, when the external system responded
with 500, 502 or 504, or when the external system accepted the request and the call then
failed in your org. The step then fails at once, whatever retry budget is left, and its
message starts with the reason. A handler that throws
UTIL_Exceptions.PermanentFailureException fails the step at once too, whatever the
method or key. A GET, PUT or DELETE, a request sent with an Idempotency-Key and a
callout the platform refused before it left the org are re-run as usual. A status named in
retryOn(...) is re-run whatever the method. Without this call the outbound engine alone
decides retries. These rules cover a call that failed. A chain that stalled in the middle
of this step follows the rule in the ApiStep class description, with or without this call.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `maxAttempts` | [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) | Total attempts including the first (2 = one retry). Null or <= 1 disables. |
| `baseBackoffSeconds` | [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) | Base delay fed to UTIL_Retry.exponential(); null = 0. |

**Returns** [UTIL_AsyncChain.ApiStep](UTIL_AsyncChain.ApiStep.md) — This ApiStep for method chaining.

**Example**

```apex
new UTIL_AsyncChain.ApiStep(API_ChargePayment.class)
    .triggeringRecordFrom('orderId')
    .withRetry(3, 30)
```

</div>

### work

<div class="apex-member">

```apex
global override UTIL_AsyncChain.StepResult work(UTIL_AsyncChain.ChainContext context)
```

Executes the API_Outbound handler via UTIL_HttpClient delegation mode.
Reads configuration from the ChainContext, builds the request, invokes the handler,
and writes results back to the context for downstream steps. A failure the chain must
not re-run (a status outside retryOn(...), a UTIL_Exceptions.PermanentFailureException
from the handler, or a request that is not safe to repeat after the external system may
have acted on it, as withRetry(...) describes) fails the step for good; the step's
message then carries the handler's errors, which say why.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `context` | [UTIL_AsyncChain.ChainContext](UTIL_AsyncChain.ChainContext.md) | Shared chain context for reading configuration and writing results. |

**Returns** [UTIL_AsyncChain.StepResult](UTIL_AsyncChain.StepResult.md) — StepResult indicating success or failure of the API call.

</div>

## Constructors

| Constructor | Description |
|-------------|-------------|
| global [ApiStep](#constructors)([Type](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_type.htm) handlerType) | Creates an ApiStep that wraps the specified API_Outbound handler. |

### ApiStep(Type handlerType)

<div class="apex-member">

```apex
global ApiStep(Type handlerType)
```

Creates an ApiStep that wraps the specified API_Outbound handler.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `handlerType` | [Type](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_type.htm) | The API_Outbound subclass to execute (e.g., API_SendEmail.class). |

**Example**

```apex
new UTIL_AsyncChain.ApiStep(API_SendEmail.class)
    .withParameter(API_SendEmail.PARAM_RECIPIENT, 'test@example.com')
    .triggeringRecordFrom('recordId')
```

</div>

