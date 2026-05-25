---
title: "TST_InvokeFlowMock.MockBuilder"
type: class
description: "Fluent builder for registering a mock flow response."
since: "1.0"
category: apex
---

# TST_InvokeFlowMock.MockBuilder

**Class**

```apex
global class TST_InvokeFlowMock.MockBuilder
```

Fluent builder for registering a mock flow response.

**Since:** 1.0

**Example:**

```apex
TST_InvokeFlowMock.forFlow('Foobar_SetDefaults')
    .succeed()
    .withOutputRecord(record)
    .register();
```

---

## Methods

| Method | Description |
|--------|-------------|
| global [TST_InvokeFlowMock.MockBuilder](TST_InvokeFlowMock.MockBuilder.md) [fail](#fail)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) errorMessage) | Declares this mock simulates a flow failure. |
| global void [register](#register)() | Registers this mock in the static registry. |
| global [TST_InvokeFlowMock.MockBuilder](TST_InvokeFlowMock.MockBuilder.md) [succeed](#succeed)() | Declares this mock returns a successful flow result. |
| global [TST_InvokeFlowMock.MockBuilder](TST_InvokeFlowMock.MockBuilder.md) [throwOnStart](#throwonstart)([Exception](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_classes_exception_methods.htm) toThrow) | Configures this mock to raise the supplied exception at the point in the trigger framework where Flow.Interview.start() would have run for a real flow. |
| global [TST_InvokeFlowMock.MockBuilder](TST_InvokeFlowMock.MockBuilder.md) [withOutputRecord](#withoutputrecord)([SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm) outputRecord) | Supplies the SObject the mocked flow's record output returns. |
| global [TST_InvokeFlowMock.MockBuilder](TST_InvokeFlowMock.MockBuilder.md) [withOutputRecords](#withoutputrecords)([List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm)> outputRecords) | Supplies the list of SObjects the mocked flow returns when the registration needs to seed multiple output records (e.g. |

---

## Method Details

### fail

```apex
global TST_InvokeFlowMock.MockBuilder fail(String errorMessage)
```

Declares this mock simulates a flow failure.

**Parameters:**

- `errorMessage` ([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)) - The error message returned by the mock

**Returns:** [TST_InvokeFlowMock.MockBuilder](TST_InvokeFlowMock.MockBuilder.md) - This builder for chaining

**Since:** 1.0

### register

```apex
global void register()
```

Registers this mock in the static registry. Terminal.

Throws if a mock for the same flow is already registered. Tests that need
to reconfigure a mock mid-method must call `TST_InvokeFlowMock.clear()` first.

**Throws:**

- [UTIL_Exceptions.IllegalStateException](UTIL_Exceptions.IllegalStateException.md) - When a mock is already registered for this flow

**Since:** 1.0

### succeed

```apex
global TST_InvokeFlowMock.MockBuilder succeed()
```

Declares this mock returns a successful flow result.

Default state — call is optional but improves readability.

**Returns:** [TST_InvokeFlowMock.MockBuilder](TST_InvokeFlowMock.MockBuilder.md) - This builder for chaining

**Since:** 1.0

### throwOnStart

```apex
global TST_InvokeFlowMock.MockBuilder throwOnStart(Exception toThrow)
```

Configures this mock to raise the supplied exception at the point in
the trigger framework where `Flow.Interview.start()` would have run for a real
flow. Lets test authors drive the runtime-error catch path (the framework's
`catch (Exception runtimeError)` branch and the `LogAndContinue` / `BlockDml`
routing that depends on it) without deploying a deliberately-broken flow XML.

Marks this mock as a failure (`success = false`); the supplied exception's
`getMessage()` is what the trigger framework records and surfaces to subscribers.

**Parameters:**

- `toThrow` ([Exception](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_classes_exception_methods.htm)) - The exception the trigger framework will throw on the test author's behalf

**Returns:** [TST_InvokeFlowMock.MockBuilder](TST_InvokeFlowMock.MockBuilder.md) - This builder for chaining

**Since:** 1.0

**Example:**

```apex
TST_InvokeFlowMock.forFlow('Foobar_SetDefaults')
    .throwOnStart(new System.NullPointerException())
    .register();
```

### withOutputRecord

```apex
global TST_InvokeFlowMock.MockBuilder withOutputRecord(SObject outputRecord)
```

Supplies the SObject the mocked flow's `record` output returns.

**Parameters:**

- `outputRecord` ([SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm)) - The SObject the flow's record output variable yields

**Returns:** [TST_InvokeFlowMock.MockBuilder](TST_InvokeFlowMock.MockBuilder.md) - This builder for chaining

**Since:** 1.0

### withOutputRecords

```apex
global TST_InvokeFlowMock.MockBuilder withOutputRecords(List<SObject> outputRecords)
```

Supplies the list of SObjects the mocked flow returns when the
registration needs to seed multiple output records (e.g. a flow that populates
a `records` collection variable). For the default per-record dispatch path,
use `withOutputRecord(SObject)` instead.

**Parameters:**

- `outputRecords` ([List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)) - The list of SObjects the flow returns

**Returns:** [TST_InvokeFlowMock.MockBuilder](TST_InvokeFlowMock.MockBuilder.md) - This builder for chaining

**Since:** 1.0

