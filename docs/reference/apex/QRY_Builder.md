---
title: "QRY_Builder"
type: class
description: "Modern fluent query builder - the primary entry point for constructing and executing SOQL queries. Provides a clean, type-safe API for building queries with support for conditions, ordering, paginatio"
author: "Jason Van Beukering"
group: "Query Infrastructure"
date: "February 2026, June 2026"
since: "1.0"
category: apex
---

# QRY_Builder

**Class** · Group: `Query Infrastructure`

```apex
global inherited sharing class QRY_Builder
```

Modern fluent query builder - the primary entry point for constructing and executing SOQL queries. Provides a clean, type-safe API for building queries with support for conditions, ordering, pagination, caching, and security enforcement. Design Principle: QRY_Builder is an adapter that delegates to the existing query infrastructure. This ensures backwards compatibility while providing a cleaner API surface for new development. 95% Use Case: Inline queries via QRY_Builder.selectFrom(...) 5% Use Case: Extend Builder for reusable custom selectors

**Since:** 1.0

**Example:**

```apex
// Basic query
List<Account> accounts = QRY_Builder.selectFrom(Account.SObjectType)
    .fields(new List<String>{'Name', 'Industry'})
    .condition(Account.Industry).equals('Technology')
    .toList();
```

```apex
// With caching
Account account = (Account)QRY_Builder.selectFrom(Account.SObjectType)
    .condition(Account.Id).equals(accountId)
    .withCache(300)
    .getFirst();
```

```apex
// Pagination
QRY_Builder.QueryPage result = QRY_Builder.selectFrom(Account.SObjectType)
    .condition(Account.Type).equals('Customer')
    .getPage(2, 25);
```

**See Also:** [IF_Queryable](IF_Queryable.md), [QRY_Condition.DateLiteral](QRY_Condition.DateLiteral.md), [QRY_Function](QRY_Function.md)

---

## Properties

| Property | Description |
|----------|-------------|
| global enum [Scope](QRY_Builder.Scope.md) | Enumeration of valid SOQL scope values for use with the USING SCOPE clause. |

## Methods

| Method | Description |
|--------|-------------|
| global static void [clearMocks](#clearmocks)() | Clears all registered mocks and mock context classes for all SObjectTypes. |
| global static void [registerMockContextClass](#registermockcontextclass)([SObjectType](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectType.htm) sObjectType, [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) contextClassName) | Registers a FormulaEval context class for an SObjectType, enabling smart mock filtering. |
| global static [QRY_Builder.Builder](QRY_Builder.Builder.md) [selectFrom](#selectfrom)([SObjectType](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectType.htm) sObjectType) | Entry point for inline queries. |
| global static void [setMock](#setmock)([SObjectType](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectType.htm) sObjectType, [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm)> mocks) | Registers mock records for a specific SObjectType during test execution. |
| global static void [setMockException](#setmockexception)([SObjectType](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectType.htm) sObjectType, [Exception](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_classes_exception_methods.htm) exceptionToThrow) | Registers an exception to be thrown when QRY_Builder is invoked for the specified SObjectType. |

## Inner Classes

| Class | Description |
|-------|-------------|
| [AggregateRow](QRY_Builder.AggregateRow.md) | Typed wrapper around AggregateResult for convenient value access. |
| [Builder](QRY_Builder.Builder.md) | Extensible query builder class. |
| [ConditionBuilder](QRY_Builder.ConditionBuilder.md) | Fluent builder for field-level conditions (WHERE and HAVING). |
| [DataCategoryBuilder](QRY_Builder.DataCategoryBuilder.md) | Fluent builder for WITH DATA CATEGORY filters. |
| [QueryPage](QRY_Builder.QueryPage.md) | Result container for paged queries, providing records and pagination metadata. |

---

## Method Details

### clearMocks

```apex
global static void clearMocks()
```

Clears all registered mocks and mock context classes for all SObjectTypes.

**Since:** 1.0

**Example:**

```apex
QRY_Builder.clearMocks();
```

### registerMockContextClass

```apex
global static void registerMockContextClass(SObjectType sObjectType, String contextClassName)
```

Registers a FormulaEval context class for an SObjectType, enabling smart mock filtering.
When registered, mock queries against this SObjectType will evaluate WHERE conditions in memory
using the specified context class, returning only matching mock records.

Standard objects (Account, Contact, etc.) and Foobar__c are auto-detected and do not require
explicit registration. Use this method for custom objects that need mock filtering.

**Parameters:**

- `sObjectType` ([SObjectType](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectType.htm)) - The SObjectType to register the context for
- `contextClassName` ([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)) - The fully qualified class name of the FormulaEval context

**Since:** 1.0

**Example:**

```apex
QRY_Builder.registerMockContextClass(Invoice__c.SObjectType, 'InvoiceFormulaContext');
QRY_Builder.setMock(Invoice__c.SObjectType, mockInvoices);
// Queries against Invoice__c now filter mocks using InvoiceFormulaContext
```

### selectFrom

```apex
global static QRY_Builder.Builder selectFrom(SObjectType sObjectType)
```

Entry point for inline queries. Creates a new Builder instance for the specified SObject type.

**Parameters:**

- `sObjectType` ([SObjectType](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectType.htm)) - The SObject type to query

**Returns:** [QRY_Builder.Builder](QRY_Builder.Builder.md) - Builder for fluent chaining

**Since:** 1.0

**Example:**

```apex
List<Account> accounts = QRY_Builder.selectFrom(Account.SObjectType)
    .fields(new List<String>{'Name', 'Industry'})
    .condition(Account.Industry).equals('Technology')
    .toList();
```

### setMock

```apex
global static void setMock(SObjectType sObjectType, List<SObject> mocks)
```

Registers mock records for a specific SObjectType during test execution.
When mocks are registered, queries will return these records instead of executing actual SOQL.

**Smart Mock Filtering:** WHERE conditions are evaluated in memory against mock records
using FormulaEval when a context class is available for the SObjectType. Standard objects
(Account, Contact, etc.) and Foobar__c are auto-detected. For custom objects, register
a context class via registerMockContextClass() to enable filtering.

When filtering is not possible (no context class, unsupported condition operators, or
relationship field traversals), all mocks are returned with only LIMIT and pagination applied.

**Parameters:**

- `sObjectType` ([SObjectType](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectType.htm)) - The SObjectType to mock
- `mocks` ([List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)) - List of mock records to return for queries

**Throws:**

- [IllegalArgumentException](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_classes_exception_methods.htm) - if mocks contain records of a different type than sObjectType

**Since:** 1.0

**Example:**

```apex
List<Account> mockAccounts = (List<Account>)TST_Builder.of(Account.SObjectType)
    .withOverride(Account.Name, 'Test Account')
    .withCount(5)
    .withoutInsertion(true)
    .buildList();
QRY_Builder.setMock(Account.SObjectType, mockAccounts);
```

### setMockException

```apex
global static void setMockException(SObjectType sObjectType, Exception exceptionToThrow)
```

Registers an exception to be thrown when QRY_Builder is invoked
for the specified SObjectType. Used for negative-path test coverage when a caller
needs to exercise a catch block around a SOQL call. Cleared by TST_Mock.clear()
and TST_Mock.clear(SObjectType).

**Parameters:**

- `sObjectType` ([SObjectType](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectType.htm)) - The SObjectType for which queries should throw.
- `exceptionToThrow` ([Exception](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_classes_exception_methods.htm)) - The exception instance to throw.

**Since:** 1.0

**Example:**

```apex
QRY_Builder.setMockException(Account.SObjectType, new QueryException('Simulated SOQL failure'));
```

