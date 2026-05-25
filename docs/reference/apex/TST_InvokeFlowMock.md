---
title: "TST_InvokeFlowMock"
type: class
description: "Test mock harness for TRG_InvokeFlow-dispatched flows. Lets test authors register canned flow responses that TRG_InvokeFlow.invokeSingle short-circuits against, bypassing the platform Flow.Interview A"
author: "Jason Van Beukering"
group: "Trigger Framework"
date: "April 2026, May 2026"
since: "1.0"
category: apex
---

# TST_InvokeFlowMock

**Class** · Group: `Trigger Framework`

```apex
global inherited sharing class TST_InvokeFlowMock
```

Test mock harness for TRG_InvokeFlow-dispatched flows. Lets test authors register canned flow responses that TRG_InvokeFlow.invokeSingle short-circuits against, bypassing the platform Flow.Interview API entirely. Mirrors the fluent shape of API_MockFactory so the patterns transfer one-to-one. Subscriber-facing global surface (locked at v1.0): forFlow(String) — entry point returning a MockBuilder MockBuilder.succeed() / .fail(String) / .withOutputRecord(SObject) / .withOutputRecords(List<SObject>) / .throwOnStart(Exception) / .register() clear(), assertInvoked(name, count), assertNotInvoked(name), wasInvoked(name) getLastInputRecord(name), getLastInputPriorRecord(name) — verify the flow saw upstream Apex mutations Framework-internal surface (used by TRG_InvokeFlow): isMocked(name), getMockResult(name), recordInvocation(name, record, priorRecord)

**Since:** 1.0

**Example:**

```apex
TST_InvokeFlowMock.forFlow('Foobar_SetDefaults')
    .succeed()
    .withOutputRecord((Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
        .withOverride(Foobar__c.TextArea__c, 'Mock-set').withoutInsertion().build())
    .register();
Assert.isTrue(TST_InvokeFlowMock.wasInvoked('Foobar_SetDefaults'), 'Flow should be invoked');
```

---

## Methods

| Method | Description |
|--------|-------------|
| global static void [assertInvoked](#assertinvoked)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) flowName, [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) expectedCount) | Asserts that a mocked flow was invoked an exact number of times. |
| global static void [assertNotInvoked](#assertnotinvoked)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) flowName) | Asserts that a mocked flow was never invoked. |
| global static void [clear](#clear)() | Clears all registered mocks and invocation counts. |
| global static [TST_InvokeFlowMock.MockBuilder](TST_InvokeFlowMock.MockBuilder.md) [forFlow](#forflow)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) flowName) | Creates a fluent builder for registering a mock flow response. |
| global static [SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm) [getLastInputPriorRecord](#getlastinputpriorrecord)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) flowName) | Returns the recordPrior SObject the mocked flow received on its most recent invocation. |
| global static [SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm) [getLastInputRecord](#getlastinputrecord)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) flowName) | Returns the record SObject the mocked flow received on its most recent invocation, or null when the flow has not been invoked. |
| global static [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) [wasInvoked](#wasinvoked)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) flowName) | Returns whether a mocked flow was invoked at least once. |

## Inner Classes

| Class | Description |
|-------|-------------|
| [MockBuilder](TST_InvokeFlowMock.MockBuilder.md) | Fluent builder for registering a mock flow response. |

---

## Method Details

### assertInvoked

```apex
global static void assertInvoked(String flowName, Integer expectedCount)
```

Asserts that a mocked flow was invoked an exact number of times.

**Parameters:**

- `flowName` ([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)) - The flow API name to verify
- `expectedCount` ([Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm)) - The expected number of invocations

**Since:** 1.0

**Example:**

```apex
TST_InvokeFlowMock.assertInvoked('Foobar_SetDefaults', 1);
```

### assertNotInvoked

```apex
global static void assertNotInvoked(String flowName)
```

Asserts that a mocked flow was never invoked.

**Parameters:**

- `flowName` ([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)) - The flow API name to verify

**Since:** 1.0

**Example:**

```apex
TST_InvokeFlowMock.assertNotInvoked('Foobar_SetDefaults');
```

### clear

```apex
global static void clear()
```

Clears all registered mocks and invocation counts.

Salesforce resets static state between tests, but `clear()` is exposed for
scenarios where multiple register/invoke cycles run inside a single test method.

**Since:** 1.0

### forFlow

```apex
global static TST_InvokeFlowMock.MockBuilder forFlow(String flowName)
```

Creates a fluent builder for registering a mock flow response.

**Parameters:**

- `flowName` ([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)) - The flow API name (matches TriggerAction__mdt.FlowName__c)

**Returns:** [TST_InvokeFlowMock.MockBuilder](TST_InvokeFlowMock.MockBuilder.md) - A new MockBuilder for chaining

**Throws:**

- [UTIL_Exceptions.ConfigurationException](UTIL_Exceptions.ConfigurationException.md) - When flowName is blank

**Since:** 1.0

**Example:**

```apex
TST_InvokeFlowMock.forFlow('Foobar_SetDefaults').succeed().register();
```

### getLastInputPriorRecord

```apex
global static SObject getLastInputPriorRecord(String flowName)
```

Returns the `recordPrior` SObject the mocked flow received on its most
recent invocation. Null when the flow has not been invoked or when the context did
not supply a prior record (insert / before-delete / after-undelete).

Pairs with `getLastInputRecord` for update-context tests asserting the flow received
both the new and prior record state.

**Parameters:**

- `flowName` ([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)) - The flow API name to check

**Returns:** [SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm) - The `recordPrior` SObject from the last invocation, or null when no prior record

**Since:** 1.0

**Example:**

```apex
Foobar__c oldValues = (Foobar__c)TST_InvokeFlowMock.getLastInputPriorRecord('Foobar_OnUpdate');
Assert.areEqual('Old TextArea', oldValues.TextArea__c, 'Flow should see prior TextArea');
```

### getLastInputRecord

```apex
global static SObject getLastInputRecord(String flowName)
```

Returns the `record` SObject the mocked flow received on its most recent
invocation, or null when the flow has not been invoked.

Mirrors `API_MockFactory.lastRequestContains` — lets subscribers verify the flow saw
the input they expected (typically: an upstream Apex action's mutation) without
inspecting the trigger record's final state. The returned SObject is the in-memory
reference passed into the flow input map; mutating it after retrieval is undefined.

**Parameters:**

- `flowName` ([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)) - The flow API name to check

**Returns:** [SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm) - The `record` SObject from the last invocation, or null if never invoked

**Since:** 1.0

**Example:**

```apex
Foobar__c observed = (Foobar__c)TST_InvokeFlowMock.getLastInputRecord('Foobar_SetDefaults');
Assert.areEqual('upstream-set', observed.TextArea__c, 'Flow should see upstream Apex mutation');
```

### wasInvoked

```apex
global static Boolean wasInvoked(String flowName)
```

Returns whether a mocked flow was invoked at least once. Use this for
conditional test branching where the assertion shape varies on whether the flow ran
(e.g. "only validate flow output write-back if the flow was reached"). For pass/fail
count checks, prefer `assertInvoked(name, count)` or `assertNotInvoked(name)`.

**Parameters:**

- `flowName` ([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)) - The flow API name to check

**Returns:** [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) - True if the flow was invoked at least once

**Since:** 1.0

**Example:**

```apex
if(TST_InvokeFlowMock.wasInvoked('Foobar_SetDefaults'))
{
    Foobar__c result = (Foobar__c)new SEL_Foobar().findById(record.Id);
    Assert.areEqual('From flow', result.TextArea__c, 'Flow output should land');
}
```

