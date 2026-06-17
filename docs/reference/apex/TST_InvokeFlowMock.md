---
title: "TST_InvokeFlowMock"
type: class
pageClass: reference
description: "Test mock harness for TRG_InvokeFlow-dispatched flows. Lets test authors register canned flow responses that TRG_InvokeFlow.invokeSingle short-circuits against, bypassing the platform Flow.Interview A"
author: "Jason Van Beukering"
group: "Triggers"
date: "April 2026, May 2026"
since: "1.0"
category: apex
---

# TST_InvokeFlowMock

**Class** · Group: `Triggers`

<div class="apex-member apex-class">

```apex
global inherited sharing class TST_InvokeFlowMock
```

Test mock harness for TRG_InvokeFlow-dispatched flows. Lets test authors register canned flow responses that TRG_InvokeFlow.invokeSingle short-circuits against, bypassing the platform Flow.Interview API entirely. Mirrors the fluent shape of API_MockFactory so the patterns transfer one-to-one. Subscriber-facing global surface (locked at v1.0): forFlow(String) — entry point returning a MockBuilder MockBuilder.succeed() / .fail(String) / .withOutputRecord(SObject) / .withOutputRecords(List<SObject>) / .throwOnStart(Exception) / .register() clear(), assertInvoked(name, count), assertNotInvoked(name), wasInvoked(name) getLastInputRecord(name), getLastInputPriorRecord(name) — verify the flow saw upstream Apex mutations Framework-internal surface (used by TRG_InvokeFlow): isMocked(name), getMockResult(name), recordInvocation(name, record, priorRecord)

**Example**

```apex
TST_InvokeFlowMock.forFlow('Foobar_SetDefaults')
    .succeed()
    .withOutputRecord((Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
        .withOverride(Foobar__c.TextArea__c, 'Mock-set').withoutInsertion().build())
    .register();
Assert.isTrue(TST_InvokeFlowMock.wasInvoked('Foobar_SetDefaults'), 'Flow should be invoked');
```

</div>

---

## Methods

| Method | Description |
|--------|-------------|
| global static void [assertInvoked](#assertinvoked)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) flowName, [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) expectedCount) | Asserts that a mocked flow was invoked an exact number of times. |
| global static void [assertNotInvoked](#assertnotinvoked)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) flowName) | Asserts that a mocked flow was never invoked. |
| global static void [clear](#clear)() | Clears all registered mocks and invocation counts. |
| global static [TST_InvokeFlowMock.MockBuilder](TST_InvokeFlowMock.MockBuilder.md) [forFlow](#forflow)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) flowName) | Creates a fluent builder for registering a mock flow response. |
| global static [Object](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_System_Object.htm) [getLastInputHeader](#getlastinputheader)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) flowName) | Returns the header Change Event input variable the mocked flow received on its most recent invocation. |
| global static [SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm) [getLastInputPriorRecord](#getlastinputpriorrecord)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) flowName) | Returns the recordPrior SObject the mocked flow received on its most recent invocation. |
| global static [SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm) [getLastInputRecord](#getlastinputrecord)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) flowName) | Returns the record SObject the mocked flow received on its most recent invocation, or null when the flow has not been invoked. |
| global static [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) [wasInvoked](#wasinvoked)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) flowName) | Returns whether a mocked flow was invoked at least once. |

### assertInvoked

<div class="apex-member">

```apex
global static void assertInvoked(String flowName, Integer expectedCount)
```

Asserts that a mocked flow was invoked an exact number of times.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `flowName` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The flow API name to verify |
| `expectedCount` | [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) | The expected number of invocations |

**Example**

```apex
TST_InvokeFlowMock.assertInvoked('Foobar_SetDefaults', 1);
```

</div>

### assertNotInvoked

<div class="apex-member">

```apex
global static void assertNotInvoked(String flowName)
```

Asserts that a mocked flow was never invoked.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `flowName` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The flow API name to verify |

**Example**

```apex
TST_InvokeFlowMock.assertNotInvoked('Foobar_SetDefaults');
```

</div>

### clear

<div class="apex-member">

```apex
global static void clear()
```

Clears all registered mocks and invocation counts.

Salesforce resets static state between tests, but `clear()` is exposed for
scenarios where multiple register/invoke cycles run inside a single test method.

</div>

### forFlow

<div class="apex-member">

```apex
global static TST_InvokeFlowMock.MockBuilder forFlow(String flowName)
```

Creates a fluent builder for registering a mock flow response.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `flowName` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The flow API name (matches TriggerAction__mdt.FlowName__c) |

**Returns** [TST_InvokeFlowMock.MockBuilder](TST_InvokeFlowMock.MockBuilder.md) — A new MockBuilder for chaining

**Throws**

| Exception | Description |
|-----------|-------------|
| [UTIL_Exceptions.ConfigurationException](UTIL_Exceptions.ConfigurationException.md) | When flowName is blank |

**Example**

```apex
TST_InvokeFlowMock.forFlow('Foobar_SetDefaults').succeed().register();
```

</div>

### getLastInputHeader

<div class="apex-member">

```apex
global static Object getLastInputHeader(String flowName)
```

Returns the `header` Change Event input variable the mocked flow
received on its most recent invocation. Null when the flow has not been invoked
or when the dispatch was not a Change Event context (standard / custom-object
triggers do not inject a header).

Returned as `Object` (rather than `DTO_ChangeEventHeader`) to keep this mock's
compile-time surface decoupled from the CDC header type — callers cast at the
call site:

`DTO_ChangeEventHeader header =
(DTO_ChangeEventHeader)TST_InvokeFlowMock.getLastInputHeader('Foobar_OnChange');
`

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `flowName` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The flow API name to check |

**Returns** [Object](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_System_Object.htm) — The `header` input variable from the last invocation, or null when the flow has not been invoked or the context did not carry a header

</div>

### getLastInputPriorRecord

<div class="apex-member">

```apex
global static SObject getLastInputPriorRecord(String flowName)
```

Returns the `recordPrior` SObject the mocked flow received on its most
recent invocation. Null when the flow has not been invoked or when the context did
not supply a prior record (insert / before-delete / after-undelete).

Pairs with `getLastInputRecord` for update-context tests asserting the flow received
both the new and prior record state.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `flowName` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The flow API name to check |

**Returns** [SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm) — The `recordPrior` SObject from the last invocation, or null when no prior record

**Example**

```apex
Foobar__c oldValues = (Foobar__c)TST_InvokeFlowMock.getLastInputPriorRecord('Foobar_OnUpdate');
Assert.areEqual('Old TextArea', oldValues.TextArea__c, 'Flow should see prior TextArea');
```

</div>

### getLastInputRecord

<div class="apex-member">

```apex
global static SObject getLastInputRecord(String flowName)
```

Returns the `record` SObject the mocked flow received on its most recent
invocation, or null when the flow has not been invoked.

Mirrors `API_MockFactory.lastRequestContains` — lets subscribers verify the flow saw
the input they expected (typically: an upstream Apex action's mutation) without
inspecting the trigger record's final state. The returned SObject is the in-memory
reference passed into the flow input map; mutating it after retrieval is undefined.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `flowName` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The flow API name to check |

**Returns** [SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm) — The `record` SObject from the last invocation, or null if never invoked

**Example**

```apex
Foobar__c observed = (Foobar__c)TST_InvokeFlowMock.getLastInputRecord('Foobar_SetDefaults');
Assert.areEqual('upstream-set', observed.TextArea__c, 'Flow should see upstream Apex mutation');
```

</div>

### wasInvoked

<div class="apex-member">

```apex
global static Boolean wasInvoked(String flowName)
```

Returns whether a mocked flow was invoked at least once. Use this for
conditional test branching where the assertion shape varies on whether the flow ran
(e.g. "only validate flow output write-back if the flow was reached"). For pass/fail
count checks, prefer `assertInvoked(name, count)` or `assertNotInvoked(name)`.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `flowName` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The flow API name to check |

**Returns** [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) — True if the flow was invoked at least once

**Example**

```apex
if(TST_InvokeFlowMock.wasInvoked('Foobar_SetDefaults'))
{
    Foobar__c result = (Foobar__c)new SEL_Foobar().findById(record.Id);
    Assert.areEqual('From flow', result.TextArea__c, 'Flow output should land');
}
```

</div>

## Inner Classes

| Class | Description |
|-------|-------------|
| [MockBuilder](TST_InvokeFlowMock.MockBuilder.md) | Fluent builder for registering a mock flow response. |

---

