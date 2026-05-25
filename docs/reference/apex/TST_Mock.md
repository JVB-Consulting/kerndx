---
title: "TST_Mock"
type: class
description: "Central registry and fluent builder for mock SObjects. Wraps QRY_Builder.setMock() with lifecycle management, providing a single point of control for registering, retrieving, and clearing mock records"
author: "Jason Van Beukering"
group: "Testing"
date: "February 2026, May 2026"
since: "1.0"
category: apex
---

# TST_Mock

**Class** · Group: `Testing`

```apex
global inherited sharing class TST_Mock
```

Central registry and fluent builder for mock SObjects. Wraps QRY_Builder.setMock() with lifecycle management, providing a single point of control for registering, retrieving, and clearing mock records used in DML-free unit tests. The nested MockBuilder creates records with mock IDs and auto-registers them for query interception.

**Since:** 1.0

**Example:**

```apex
Foobar__c mock = (Foobar__c)TST_Mock.of(Foobar__c.SObjectType)
    .withOverride(Foobar__c.Name, 'Test').build();
Foobar__c result = (Foobar__c)new SEL_Foobar().findById(mock.Id);
```

**See Also:** [TST_Builder](TST_Builder.md), [QRY_Builder](QRY_Builder.md)

---

## Methods

| Method | Description |
|--------|-------------|
| global static void [clear](#clear)() | Clears all registered mock records for all SObject types and resets the QRY_Builder mock layer. |
| global static void [clear](#clear)([SObjectType](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectType.htm) objectType) | Clears registered mock records for a specific SObject type and resets its QRY_Builder mock layer. |
| global static [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm) [get](#get)([SObjectType](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectType.htm) objectType) | Retrieves all mock records registered for the specified SObject type. |
| global static [TST_Mock.MockBuilder](TST_Mock.MockBuilder.md) [of](#of)([SObjectType](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectType.htm) objectType) | Creates a new MockBuilder for the specified SObject type. |
| global static void [register](#register)([SObjectType](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectType.htm) objectType, [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm)> records) | Registers a list of mock records for the specified SObject type. |
| global static void [register](#register)([SObjectType](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectType.htm) objectType, [SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm) record) | Registers a single mock record for the specified SObject type. |
| global static void [throwsException](#throwsexception)([SObjectType](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectType.htm) objectType) | Convenience overload that throws a generic QueryException for the given SObjectType. |
| global static void [throwsException](#throwsexception)([SObjectType](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectType.htm) objectType, [Exception](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_classes_exception_methods.htm) exceptionToThrow) | Registers an Exception to be thrown the next time the framework queries the specified SObjectType. |
| global static void [throwsException](#throwsexception)([SObjectType](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectType.htm) objectType, [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) errorMessage) | Convenience overload that throws a QueryException with the given message. |

## Inner Classes

| Class | Description |
|-------|-------------|
| [MockBuilder](TST_Mock.MockBuilder.md) | Fluent builder wrapper that delegates to TST_Builder.Builder for record construction and auto-registers built records with TST_Mock. |

---

## Method Details

### clear

```apex
global static void clear()
```

Clears all registered mock records for all SObject types and resets the
QRY_Builder mock layer.

**Since:** 1.0

**Example:**

```apex
TST_Mock.clear();
```

### clear

```apex
global static void clear(SObjectType objectType)
```

Clears registered mock records for a specific SObject type and resets its
QRY_Builder mock layer.

**Parameters:**

- `objectType` ([SObjectType](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectType.htm)) - The SObject type to clear mocks for.

**Since:** 1.0

**Example:**

```apex
TST_Mock.clear(Foobar__c.SObjectType);
```

### get

```apex
global static List<SObject> get(SObjectType objectType)
```

Retrieves all mock records registered for the specified SObject type.

**Parameters:**

- `objectType` ([SObjectType](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectType.htm)) - The SObject type to retrieve mocks for.

**Returns:** [SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm) - The list of registered mock records, or an empty list if none registered.

**Since:** 1.0

**Example:**

```apex
List<SObject> mocks = TST_Mock.get(Foobar__c.SObjectType);
```

### of

```apex
global static TST_Mock.MockBuilder of(SObjectType objectType)
```

Creates a new MockBuilder for the specified SObject type. Records built via
the returned builder are automatically created with mock IDs (no DML) and registered
with TST_Mock for query interception.

**Parameters:**

- `objectType` ([SObjectType](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectType.htm)) - The SObject type to build mock records for.

**Returns:** [TST_Mock.MockBuilder](TST_Mock.MockBuilder.md) - A new MockBuilder instance configured for the specified type.

**Since:** 1.0

**Example:**

```apex
Foobar__c mock = (Foobar__c)TST_Mock.of(Foobar__c.SObjectType)
    .withOverride(Foobar__c.Name, 'Test')
    .build();
```

### register

```apex
global static void register(SObjectType objectType, List<SObject> records)
```

Registers a list of mock records for the specified SObject type. Appends to any
previously registered records for the same type and updates the QRY_Builder mock layer.

**Parameters:**

- `objectType` ([SObjectType](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectType.htm)) - The SObject type to register mocks for.
- `records` ([List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)) - The mock records to register.

**Since:** 1.0

**Example:**

```apex
List<Foobar__c> mocks = new List<Foobar__c>
{
    (Foobar__c)TST_Builder.of(Foobar__c.SObjectType).withoutInsertion(true).build(),
    (Foobar__c)TST_Builder.of(Foobar__c.SObjectType).withoutInsertion(true).build()
};
TST_Mock.register(Foobar__c.SObjectType, mocks);
```

### register

```apex
global static void register(SObjectType objectType, SObject record)
```

Registers a single mock record for the specified SObject type.

**Parameters:**

- `objectType` ([SObjectType](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectType.htm)) - The SObject type to register the mock for.
- `record` ([SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm)) - The mock record to register.

**Since:** 1.0

**Example:**

```apex
Foobar__c mock = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType).withoutInsertion(true).build();
TST_Mock.register(Foobar__c.SObjectType, mock);
```

### throwsException

```apex
global static void throwsException(SObjectType objectType)
```

Convenience overload that throws a generic QueryException for the given
SObjectType. The synthesized message names the type so failures point to which mock
fired without manual message threading.

**Parameters:**

- `objectType` ([SObjectType](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectType.htm)) - The SObjectType for which queries should throw.

**Since:** 1.0

**Example:**

```apex
TST_Mock.throwsException(Account.SObjectType);
```

### throwsException

```apex
global static void throwsException(SObjectType objectType, Exception exceptionToThrow)
```

Registers an Exception to be thrown the next time the framework queries
the specified SObjectType. Use for negative-path test coverage when a caller needs to
exercise a catch block around a SOQL call.

Coexists with record mocks: if both an exception and records are registered for the
same SObjectType, the exception is thrown first (records are unreachable).

Cleared by TST_Mock.clear() and TST_Mock.clear(SObjectType).

**Parameters:**

- `objectType` ([SObjectType](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectType.htm)) - The SObjectType for which queries should throw.
- `exceptionToThrow` ([Exception](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_classes_exception_methods.htm)) - The exception instance to throw.

**Since:** 1.0

**Example:**

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

### throwsException

```apex
global static void throwsException(SObjectType objectType, String errorMessage)
```

Convenience overload that throws a QueryException with the given message.

**Parameters:**

- `objectType` ([SObjectType](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectType.htm)) - The SObjectType for which queries should throw.
- `errorMessage` ([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)) - The message attached to the synthesized QueryException.

**Since:** 1.0

**Example:**

```apex
TST_Mock.throwsException(Account.SObjectType, 'Simulated SOQL failure');
```

