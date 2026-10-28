---
title: "TST_Mock"
type: class
pageClass: reference
description: "Central registry and fluent builder for mock SObjects. Wraps QRY_Builder.setMock() with lifecycle management, providing a single point of control for registering, retrieving, and clearing mock records"
author: "Jason Van Beukering"
group: "Testing"
date: "February 2026, September 2026"
since: "1.0"
category: apex
---

# TST_Mock

**Class** · Group: `Testing`

<div class="apex-member apex-class">

```apex
global inherited sharing class TST_Mock
```

Central registry and fluent builder for mock SObjects. Wraps QRY_Builder.setMock() with lifecycle management, providing a single point of control for registering, retrieving, and clearing mock records used in DML-free unit tests, and for setting a different answer for each query with registerNext. The nested MockBuilder creates records with mock IDs and auto-registers them for query interception.

**Example**

```apex
Foobar__c mock = (Foobar__c)TST_Mock.of(Foobar__c.SObjectType)
    .withOverride(Foobar__c.Name, 'Test').build();
Foobar__c result = (Foobar__c)new SEL_Foobar().findById(mock.Id);
```

**See Also:** [TST_Builder](TST_Builder.md), [QRY_Builder](QRY_Builder.md)

</div>

---

## Methods

| Method | Description |
|--------|-------------|
| global static void [clear](#clear)() | Removes every mock record, queued answer and exception registered for every SObject type, and takes every type out of the QRY_Builder mock layer, so queries read the database again. |
| global static void [clear](#clear)([SObjectType](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectType.htm) objectType) | Removes the mock records, queued answers and exception registered for one SObject type, and takes that type out of the QRY_Builder mock layer, so its queries read the database again. |
| global static [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm)> [get](#get)([SObjectType](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectType.htm) objectType) | Retrieves all mock records registered for the specified SObject type. |
| global static [TST_Mock.MockBuilder](TST_Mock.MockBuilder.md) [of](#of)([SObjectType](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectType.htm) objectType) | Creates a new MockBuilder for the specified SObject type. |
| global static void [register](#register)([SObjectType](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectType.htm) objectType, [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm)> records) | Registers a list of mock records for the specified SObject type. |
| global static void [register](#register)([SObjectType](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectType.htm) objectType, [SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm) record) | Registers a single mock record for the specified SObject type. |
| global static void [registerNext](#registernext)([SObjectType](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectType.htm) objectType, [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm)> records) | Sets the answer to the NEXT query the framework runs against the given SObject type: that one query, or count, returns exactly these records, and the answer is then used up. |
| global static void [registerNext](#registernext)([SObjectType](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectType.htm) objectType, [SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm) record) | Sets one record as the answer to the NEXT query the framework runs against the given SObject type. |
| global static void [throwsException](#throwsexception)([SObjectType](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectType.htm) objectType) | Convenience overload that throws a generic QueryException for the given SObjectType. |
| global static void [throwsException](#throwsexception)([SObjectType](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectType.htm) objectType, [Exception](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_classes_exception_methods.htm) exceptionToThrow) | Registers an Exception to be thrown on every query the framework runs against the specified SObjectType, until it is cleared. |
| global static void [throwsException](#throwsexception)([SObjectType](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectType.htm) objectType, [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) errorMessage) | Convenience overload that throws a QueryException with the given message. |

### clear

<div class="apex-member">

```apex
global static void clear()
```

Removes every mock record, queued answer and exception registered for every SObject type, and
takes every type out of the QRY_Builder mock layer, so queries read the database again.

**Example**

```apex
TST_Mock.clear();
```

</div>

<div class="apex-member">

```apex
global static void clear(SObjectType objectType)
```

Removes the mock records, queued answers and exception registered for one SObject type, and
takes that type out of the QRY_Builder mock layer, so its queries read the database again.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `objectType` | [SObjectType](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectType.htm) | The SObject type to clear mocks for. |

**Example**

```apex
TST_Mock.clear(Foobar__c.SObjectType);
```

</div>

### get

<div class="apex-member">

```apex
global static List<SObject> get(SObjectType objectType)
```

Retrieves all mock records registered for the specified SObject type.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `objectType` | [SObjectType](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectType.htm) | The SObject type to retrieve mocks for. |

**Returns** [SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm) — The list of registered mock records, or an empty list if none registered.

**Example**

```apex
List<SObject> mocks = TST_Mock.get(Foobar__c.SObjectType);
```

</div>

### of

<div class="apex-member">

```apex
global static TST_Mock.MockBuilder of(SObjectType objectType)
```

Creates a new MockBuilder for the specified SObject type. Records built via
the returned builder are automatically created with mock IDs (no DML) and registered
with TST_Mock for query interception.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `objectType` | [SObjectType](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectType.htm) | The SObject type to build mock records for. |

**Returns** [TST_Mock.MockBuilder](TST_Mock.MockBuilder.md) — A new MockBuilder instance configured for the specified type.

**Example**

```apex
Foobar__c mock = (Foobar__c)TST_Mock.of(Foobar__c.SObjectType)
    .withOverride(Foobar__c.Name, 'Test')
    .build();
```

</div>

### register

<div class="apex-member">

```apex
global static void register(SObjectType objectType, List<SObject> records)
```

Registers a list of mock records for the specified SObject type. Appends to any
previously registered records for the same type and updates the QRY_Builder mock layer.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `objectType` | [SObjectType](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectType.htm) | The SObject type to register mocks for. |
| `records` | [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm) | The mock records to register. |

**Example**

```apex
List<Foobar__c> mocks = new List<Foobar__c>
{
    (Foobar__c)TST_Builder.of(Foobar__c.SObjectType).withoutInsertion(true).build(),
    (Foobar__c)TST_Builder.of(Foobar__c.SObjectType).withoutInsertion(true).build()
};
TST_Mock.register(Foobar__c.SObjectType, mocks);
```

</div>

<div class="apex-member">

```apex
global static void register(SObjectType objectType, SObject record)
```

Registers a single mock record for the specified SObject type.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `objectType` | [SObjectType](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectType.htm) | The SObject type to register the mock for. |
| `record` | [SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm) | The mock record to register. |

**Example**

```apex
Foobar__c mock = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType).withoutInsertion(true).build();
TST_Mock.register(Foobar__c.SObjectType, mock);
```

</div>

### registerNext

<div class="apex-member">

```apex
global static void registerNext(SObjectType objectType, List<SObject> records)
```

Sets the answer to the NEXT query the framework runs against the given SObject type: that one
query, or count, returns exactly these records, and the answer is then used up. Call it once for each query
you want to answer; the answers are used in the order you added them. When all of them are used up, the type
goes back to the records registered with register, or to the database when none are registered. A test can
therefore make the first read find nothing and the second read find the row. That is what a caller sees
when another transaction saved the row in between. Nothing needs cleaning up afterwards.

An empty list means the next query finds nothing. A queued answer is filtered, sorted, limited and paged in
memory in the same way as a registered record. An exception registered with throwsException is thrown
first, on every query until it is cleared, and the queued answers stay waiting. get returns registered
records only, never queued answers. clear() and clear(SObjectType) remove queued answers.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `objectType` | [SObjectType](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectType.htm) | The SObject type to set the next answer for. |
| `records` | [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm) | The records the next query returns. May be empty; may not be null. |

**Throws**

| Exception | Description |
|-----------|-------------|
| [IllegalArgumentException](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_classes_exception_methods.htm) | When objectType or records is null, or a record is of another type. |

**Example**

```apex
Foobar__c stored = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType).build();
TST_Mock.registerNext(Foobar__c.SObjectType, new List<SObject>());
Assert.isNull(new SEL_Foobar().findById(stored.Id), 'The first read misses');
Assert.isNotNull(new SEL_Foobar().findById(stored.Id), 'The second read finds the stored row');
```

</div>

<div class="apex-member">

```apex
global static void registerNext(SObjectType objectType, SObject record)
```

Sets one record as the answer to the NEXT query the framework runs against the given SObject
type. See the list overload for how queued answers are used.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `objectType` | [SObjectType](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectType.htm) | The SObject type to set the next answer for. |
| `record` | [SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm) | The record the next query returns. May not be null. |

**Throws**

| Exception | Description |
|-----------|-------------|
| [IllegalArgumentException](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_classes_exception_methods.htm) | When objectType or record is null, or the record is of another type. |

**Example**

```apex
Foobar__c mock = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType).withoutInsertion(true).build();
TST_Mock.registerNext(Foobar__c.SObjectType, mock);
```

</div>

### throwsException

<div class="apex-member">

```apex
global static void throwsException(SObjectType objectType)
```

Convenience overload that throws a generic QueryException for the given
SObjectType. The synthesized message names the type so failures point to which mock
fired without manual message threading.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `objectType` | [SObjectType](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectType.htm) | The SObjectType for which queries should throw. |

**Example**

```apex
TST_Mock.throwsException(Account.SObjectType);
```

</div>

<div class="apex-member">

```apex
global static void throwsException(SObjectType objectType, Exception exceptionToThrow)
```

Registers an Exception to be thrown on every query the framework runs against
the specified SObjectType, until it is cleared. Use for negative-path test coverage when a
caller needs to exercise a catch block around a SOQL call.

Coexists with record mocks: if both an exception and records are registered for the
same SObjectType, the exception is thrown first (records are unreachable).

Cleared by TST_Mock.clear() and TST_Mock.clear(SObjectType).

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `objectType` | [SObjectType](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectType.htm) | The SObjectType for which queries should throw. |
| `exceptionToThrow` | [Exception](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_classes_exception_methods.htm) | The exception instance to throw. |

**Example**

```apex
TST_Mock.throwsException(Account.SObjectType, new QueryException('Simulated SOQL failure'));
try
{
    new SEL_Accounts().findById(someAccountId);
    Assert.fail('Expected QueryException');
}
catch(QueryException error)
{
    Assert.areEqual('Simulated SOQL failure', error.getMessage(), 'Caught the simulated failure');
}
```

</div>

<div class="apex-member">

```apex
global static void throwsException(SObjectType objectType, String errorMessage)
```

Convenience overload that throws a QueryException with the given message.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `objectType` | [SObjectType](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectType.htm) | The SObjectType for which queries should throw. |
| `errorMessage` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The message attached to the synthesized QueryException. |

**Example**

```apex
TST_Mock.throwsException(Account.SObjectType, 'Simulated SOQL failure');
```

</div>

## Inner Classes

| Class | Description |
|-------|-------------|
| [MockBuilder](TST_Mock.MockBuilder.md) | Fluent builder wrapper that delegates to TST_Builder.Builder for record construction and auto-registers built records with TST_Mock. |

---

