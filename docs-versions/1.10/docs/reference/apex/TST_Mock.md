---
title: "TST_Mock"
type: class
pageClass: reference
description: "Central registry and fluent builder for mock SObjects. Wraps QRY_Builder.setMock() with lifecycle management, providing a single point of control for registering, retrieving, and clearing mock records"
author: "Jason Van Beukering"
group: "Testing"
date: "February 2026, October 2026"
since: "1.0"
category: apex
---

# TST_Mock

**Class** · Group: `Testing`

<div class="apex-member apex-class">

```apex
global inherited sharing class TST_Mock
```

Central registry and fluent builder for mock SObjects. Wraps QRY_Builder.setMock() with lifecycle management, providing a single point of control for registering, retrieving, and clearing mock records used in DML-free unit tests, and for setting a different answer for each query with registerNext. registerAggregateRows and registerNextAggregateRows answer aggregate queries. The nested MockBuilder creates records with mock IDs and auto-registers them for query interception.

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
| global static void [clear](#clear)() | Removes every mock record, queued answer, exception and aggregate rows registered for every SObject type, and takes every type out of the QRY_Builder mock layer, so queries read the database again. |
| global static void [clear](#clear)([SObjectType](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectType.htm) objectType) | Removes the mock records, queued answers, exception and aggregate rows registered for one SObject type, and takes that type out of the QRY_Builder mock layer, so its queries read the database again. |
| global static [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm)> [get](#get)([SObjectType](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectType.htm) objectType) | Retrieves all mock records registered for the specified SObject type. |
| global static [TST_Mock.MockBuilder](TST_Mock.MockBuilder.md) [of](#of)([SObjectType](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectType.htm) objectType) | Creates a new MockBuilder for the specified SObject type. |
| global static void [register](#register)([SObjectType](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectType.htm) objectType, [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm)> records) | Registers a list of mock records for the specified SObject type. |
| global static void [register](#register)([SObjectType](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectType.htm) objectType, [SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm) record) | Registers a single mock record for the specified SObject type. |
| global static void [registerAggregateRows](#registeraggregaterows)([SObjectType](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectType.htm) objectType, [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[Map](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_map.htm)<[String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm), [Object](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_System_Object.htm)>> rows) | Registers rows that every aggregate query on this object type returns until cleared. |
| global static void [registerAggregateRows](#registeraggregaterows)([SObjectType](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectType.htm) objectType, [Map](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_map.htm)<[String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm), [Object](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_System_Object.htm)> row) | Registers one row that every aggregate query on this object type returns until cleared. |
| global static void [registerNext](#registernext)([SObjectType](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectType.htm) objectType, [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm)> records) | Sets the answer to the NEXT query the framework runs against the given SObject type: that one query, or count, returns exactly these records, and the answer is then used up. |
| global static void [registerNext](#registernext)([SObjectType](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectType.htm) objectType, [SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm) record) | Sets one record as the answer to the NEXT query the framework runs against the given SObject type. |
| global static void [registerNextAggregateRows](#registernextaggregaterows)([SObjectType](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectType.htm) objectType, [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[Map](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_map.htm)<[String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm), [Object](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_System_Object.htm)>> rows) | Registers rows that answer the next aggregate query on this object type once; answers are used in the order you added them, before any registered rows. |
| global static void [registerNextAggregateRows](#registernextaggregaterows)([SObjectType](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectType.htm) objectType, [Map](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_map.htm)<[String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm), [Object](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_System_Object.htm)> row) | Registers one row that answers the next aggregate query on this object type once. |
| global static void [throwsException](#throwsexception)([SObjectType](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectType.htm) objectType) | Convenience overload that throws a generic QueryException for the given SObjectType. |
| global static void [throwsException](#throwsexception)([SObjectType](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectType.htm) objectType, [Exception](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_classes_exception_methods.htm) exceptionToThrow) | Registers an Exception to be thrown on every query the framework runs against the specified SObjectType, until it is cleared. |
| global static void [throwsException](#throwsexception)([SObjectType](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectType.htm) objectType, [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) errorMessage) | Convenience overload that throws a QueryException with the given message. |

### clear

<div class="apex-member">

```apex
global static void clear()
```

Removes every mock record, queued answer, exception and aggregate rows registered for every SObject
type, and takes every type out of the QRY_Builder mock layer, so queries read the database again.

**Example**

```apex
TST_Mock.clear();
```

</div>

<div class="apex-member">

```apex
global static void clear(SObjectType objectType)
```

Removes the mock records, queued answers, exception and aggregate rows registered for one SObject
type, and takes that type out of the QRY_Builder mock layer, so its queries read the database again.

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

### registerAggregateRows

<div class="apex-member">

```apex
global static void registerAggregateRows(SObjectType objectType, List<Map<String, Object>> rows)
```

Registers rows that every aggregate query on this object type returns until cleared. Each map is
one row; its keys are the aliases your code reads.

An aggregate query is one with count(field, alias), count(fieldName), countDistinct(), sum(), avg(), min(), max()
or groupBy(). The count() that ends a query and returns a number is not one: like toList(), it reads the records
registered with register. Read the rows with QRY_Builder.Builder.toAggregateList() or getFirstAggregate(). The
rows come back in the order you gave them; only the query's limit is applied to them, never its conditions or
its order. Aliases are matched without regard to case, and reading an alias the row does not hold throws, so a
spelling mistake shows at once. A number can be written as an Integer, a Long or a Decimal and read with any of
the number getters.

Rows registered here are added after the rows registered earlier for the type, the way register adds records,
so one aggregate query returns them all, the first registered first. QRY_Builder.setAggregateMock replaces the
rows instead. Record mocks registered with register never answer an aggregate query: such a query throws until
aggregate rows are registered too. Reading a mocked aggregate query with toList() or any other record read
throws. clear() and clear(SObjectType) remove the rows.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `objectType` | [SObjectType](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectType.htm) | The object type whose aggregate queries the rows answer. |
| `rows` | [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm) | The rows to add, in this order. May be empty; may not be null. An empty list adds no row, but when no rows are registered yet for the type, it makes every aggregate query on the type find nothing. To remove the rows, call clear(SObjectType). |

**Throws**

| Exception | Description |
|-----------|-------------|
| [IllegalArgumentException](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_classes_exception_methods.htm) | When objectType or rows is null. |

**Example**

```apex
TST_Mock.registerAggregateRows(Foobar__c.SObjectType, new List<Map<String, Object>>
{
    new Map<String, Object> {'total' => 3, 'Name' => 'A'},
    new Map<String, Object> {'total' => 2, 'Name' => 'B'}
});
List<QRY_Builder.AggregateRow> rows = QRY_Builder.selectFrom(Foobar__c.SObjectType)
    .count(Foobar__c.Id, 'total')
    .groupBy(Foobar__c.Name)
    .toAggregateList();
Assert.areEqual(3, rows[0].getInteger('total'), 'The first registered row comes first');
```

</div>

<div class="apex-member">

```apex
global static void registerAggregateRows(SObjectType objectType, Map<String, Object> row)
```

Registers one row that every aggregate query on this object type returns until cleared. Its keys
are the aliases your code reads. The row is added after the rows registered earlier for the type. Use it for a
query read with getFirstAggregate(). See the list overload for how the rows are used.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `objectType` | [SObjectType](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectType.htm) | The object type whose aggregate queries the row answers. |
| `row` | [Map](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_map.htm) | The row to return. May not be null. |

**Throws**

| Exception | Description |
|-----------|-------------|
| [IllegalArgumentException](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_classes_exception_methods.htm) | When objectType or row is null. |

**Example**

```apex
TST_Mock.registerAggregateRows(Foobar__c.SObjectType, new Map<String, Object> {'sum' => 10});
QRY_Builder.AggregateRow row = QRY_Builder.selectFrom(Foobar__c.SObjectType)
    .sum(Foobar__c.NumberInteger__c, 'sum')
    .getFirstAggregate();
Assert.areEqual(10, row.getDecimal('sum'), 'The registered row answers');
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

### registerNextAggregateRows

<div class="apex-member">

```apex
global static void registerNextAggregateRows(SObjectType objectType, List<Map<String, Object>> rows)
```

Registers rows that answer the next aggregate query on this object type once; answers are used in
the order you added them, before any registered rows.

Call it once for each aggregate query you want to answer. When all of these answers are used up, the type goes
back to the rows registered with registerAggregateRows, or to the database when none are registered. An empty
list means the next aggregate query finds nothing. clear() and clear(SObjectType) remove the answers that are
left.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `objectType` | [SObjectType](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectType.htm) | The object type to set the next aggregate answer for. |
| `rows` | [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm) | The rows the next aggregate query returns. May be empty; may not be null. |

**Throws**

| Exception | Description |
|-----------|-------------|
| [IllegalArgumentException](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_classes_exception_methods.htm) | When objectType or rows is null. |

**Example**

```apex
TST_Mock.registerNextAggregateRows(Foobar__c.SObjectType, new List<Map<String, Object>>());
List<QRY_Builder.AggregateRow> rows = QRY_Builder.selectFrom(Foobar__c.SObjectType)
    .count(Foobar__c.Id, 'total')
    .toAggregateList();
Assert.isTrue(rows.isEmpty(), 'The empty answer makes the first aggregate query find nothing');
```

</div>

<div class="apex-member">

```apex
global static void registerNextAggregateRows(SObjectType objectType, Map<String, Object> row)
```

Registers one row that answers the next aggregate query on this object type once. See the list
overload for how these answers are used.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `objectType` | [SObjectType](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectType.htm) | The object type to set the next aggregate answer for. |
| `row` | [Map](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_map.htm) | The row the next aggregate query returns. May not be null. |

**Throws**

| Exception | Description |
|-----------|-------------|
| [IllegalArgumentException](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_classes_exception_methods.htm) | When objectType or row is null. |

**Example**

```apex
TST_Mock.registerNextAggregateRows(Foobar__c.SObjectType, new Map<String, Object> {'total' => 1});
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

