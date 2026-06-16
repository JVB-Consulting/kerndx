---
title: "UTIL_AsyncChain.ApiStep"
type: class
description: "Chain step adapter that executes any API_Outbound handler as part of an async chain. Wraps the full web service lifecycle (validation, callout, response parsing, DML, ApiCall__c persistence) via UTIL_"
since: "1.0"
category: apex
---

# UTIL_AsyncChain.ApiStep

**Class**

```apex
global inherited sharing class UTIL_AsyncChain.ApiStep extends UTIL_AsyncChain.ChainStep
```

**Extends:** [UTIL_AsyncChain.ChainStep](UTIL_AsyncChain.ChainStep.md)

**Known Derived Types:** [IF_Chain.Step.work(UTIL_AsyncChain.ChainContext)](IF_Chain.Step.md#work)

Chain step adapter that executes any API_Outbound handler as part of an async chain. Wraps the full web service lifecycle (validation, callout, response parsing, DML, ApiCall__c persistence) via UTIL_HttpClient delegation mode, allowing existing outbound services to run inside chains with zero changes to the service class. Configuration is stored in the ChainContext (not on the step instance) because steps are serialized as class names and instantiated via reflection. At build-time, the ChainBuilder calls writeConfig() to persist the step's configuration into the initial context. At execution-time, work() reads the configuration back from the context using the current step index.

**Since:** 1.0

**Example:**

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

---

## Methods

| Method | Description |
|--------|-------------|
| global  [ApiStep](#apistep)([Type](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_type.htm) handlerType) | Creates an ApiStep that wraps the specified API_Outbound handler. |
| global [UTIL_AsyncChain.ApiStep](UTIL_AsyncChain.ApiStep.md) [credential](#credential)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) namedCredential) | Overrides the Named Credential used for this API call. |
| global [UTIL_AsyncChain.ApiStep](UTIL_AsyncChain.ApiStep.md) [triggeringRecord](#triggeringrecord)([Id](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_id.htm) recordId) | Sets a static triggering record ID for this API call. |
| global [UTIL_AsyncChain.ApiStep](UTIL_AsyncChain.ApiStep.md) [triggeringRecordFrom](#triggeringrecordfrom)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) contextKey) | Sets the triggering record ID from a ChainContext key, resolved at execution-time. |
| global [UTIL_AsyncChain.ApiStep](UTIL_AsyncChain.ApiStep.md) [withParameter](#withparameter)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) name, [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) value) | Adds a static parameter value to pass to the handler. |
| global [UTIL_AsyncChain.ApiStep](UTIL_AsyncChain.ApiStep.md) [withParameterFrom](#withparameterfrom)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) parameterName, [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) contextKey) | Maps a handler parameter to a ChainContext key, resolved at execution-time. |
| global override [UTIL_AsyncChain.StepResult](UTIL_AsyncChain.StepResult.md) [work](#work)([UTIL_AsyncChain.ChainContext](UTIL_AsyncChain.ChainContext.md) context) | Executes the API_Outbound handler via UTIL_HttpClient delegation mode. |

---

## Method Details

### ApiStep

```apex
global ApiStep(Type handlerType)
```

Creates an ApiStep that wraps the specified API_Outbound handler.

**Parameters:**

- `handlerType` ([Type](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_type.htm)) - The API_Outbound subclass to execute (e.g., API_SendEmail.class).

**Since:** 1.0

**Example:**

```apex
new UTIL_AsyncChain.ApiStep(API_SendEmail.class)
    .withParameter(API_SendEmail.PARAM_RECIPIENT, 'test@example.com')
    .triggeringRecordFrom('recordId')
```

### credential

```apex
global UTIL_AsyncChain.ApiStep credential(String namedCredential)
```

Overrides the Named Credential used for this API call.

**Parameters:**

- `namedCredential` ([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)) - The Named Credential developer name.

**Returns:** [UTIL_AsyncChain.ApiStep](UTIL_AsyncChain.ApiStep.md) - This ApiStep for method chaining.

**Since:** 1.0

**Example:**

```apex
new UTIL_AsyncChain.ApiStep(API_SendEmail.class)
    .credential('AlternateGateway')
```

### triggeringRecord

```apex
global UTIL_AsyncChain.ApiStep triggeringRecord(Id recordId)
```

Sets a static triggering record ID for this API call.

**Parameters:**

- `recordId` ([Id](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_id.htm)) - The Salesforce record ID.

**Returns:** [UTIL_AsyncChain.ApiStep](UTIL_AsyncChain.ApiStep.md) - This ApiStep for method chaining.

**Since:** 1.0

**Example:**

```apex
new UTIL_AsyncChain.ApiStep(API_SendEmail.class)
    .triggeringRecord(account.Id)
```

### triggeringRecordFrom

```apex
global UTIL_AsyncChain.ApiStep triggeringRecordFrom(String contextKey)
```

Sets the triggering record ID from a ChainContext key, resolved at execution-time.

**Parameters:**

- `contextKey` ([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)) - The ChainContext key containing the record ID.

**Returns:** [UTIL_AsyncChain.ApiStep](UTIL_AsyncChain.ApiStep.md) - This ApiStep for method chaining.

**Since:** 1.0

**Example:**

```apex
new UTIL_AsyncChain.ApiStep(API_ChargePayment.class)
    .triggeringRecordFrom('orderId')
```

### withParameter

```apex
global UTIL_AsyncChain.ApiStep withParameter(String name, String value)
```

Adds a static parameter value to pass to the handler.

**Parameters:**

- `name` ([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)) - The parameter name (use the handler's PARAM_* constants).
- `value` ([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)) - The parameter value.

**Returns:** [UTIL_AsyncChain.ApiStep](UTIL_AsyncChain.ApiStep.md) - This ApiStep for method chaining.

**Since:** 1.0

**Example:**

```apex
new UTIL_AsyncChain.ApiStep(API_ChargePayment.class)
    .withParameter(API_ChargePayment.PARAM_AMOUNT, '99.99')
    .withParameter(API_ChargePayment.PARAM_CURRENCY, 'USD')
```

### withParameterFrom

```apex
global UTIL_AsyncChain.ApiStep withParameterFrom(String parameterName, String contextKey)
```

Maps a handler parameter to a ChainContext key, resolved at execution-time.
Use this when the parameter value is produced by a prior step in the chain.

**Parameters:**

- `parameterName` ([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)) - The handler parameter name.
- `contextKey` ([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)) - The ChainContext key to read the value from.

**Returns:** [UTIL_AsyncChain.ApiStep](UTIL_AsyncChain.ApiStep.md) - This ApiStep for method chaining.

**Since:** 1.0

**Example:**

```apex
new UTIL_AsyncChain.ApiStep(API_SendConfirmation.class)
    .withParameterFrom('recipient', 'customerEmail')
```

### work

```apex
global override UTIL_AsyncChain.StepResult work(UTIL_AsyncChain.ChainContext context)
```

Executes the API_Outbound handler via UTIL_HttpClient delegation mode.
Reads configuration from the ChainContext, builds the request, invokes the handler,
and writes results back to the context for downstream steps.

**Parameters:**

- `context` ([UTIL_AsyncChain.ChainContext](UTIL_AsyncChain.ChainContext.md)) - Shared chain context for reading configuration and writing results.

**Returns:** [UTIL_AsyncChain.StepResult](UTIL_AsyncChain.StepResult.md) - StepResult indicating success or failure of the API call.

**Since:** 1.0

