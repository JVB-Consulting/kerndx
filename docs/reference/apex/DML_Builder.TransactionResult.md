---
title: "DML_Builder.TransactionResult"
type: class
pageClass: reference
description: "Result object returned by execute() containing the outcome of all DML operations in the transaction. Provides methods to inspect success/failure status, retrieve generated IDs, and access errors."
since: "1.0"
category: apex
---

# DML_Builder.TransactionResult

**Class**

<div class="apex-member apex-class">

```apex
global class DML_Builder.TransactionResult
```

Result object returned by execute() containing the outcome of all DML operations in the transaction. Provides methods to inspect success/failure status, retrieve generated IDs, and access errors.

</div>

---

## Methods

| Method | Description |
|--------|-------------|
| global [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[Database.Error](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_database_error.htm)> [getErrors](#geterrors)() | Returns all errors from failed DML operations across all operation types. |
| global [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) [getFailureCount](#getfailurecount)() | Returns the count of failed DML operations across all operation types. |
| global [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[Id](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_id.htm)> [getInsertedIds](#getinsertedids)() | Returns the IDs of all successfully inserted records. |
| global [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) [getSuccessCount](#getsuccesscount)() | Returns the count of successful DML operations across all operation types. |
| global [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) [isSuccess](#issuccess)() | Returns true if all DML operations completed successfully. |

---

## Method Details

### getErrors

<div class="apex-member">

```apex
global List<Database.Error> getErrors()
```

Returns all errors from failed DML operations across all operation types.

**Returns** [Database.Error](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_database_error.htm) — List of Database.Error objects from all failed operations.

**Example**

```apex
List<Database.Error> errors = result.getErrors();
```

</div>

### getFailureCount

<div class="apex-member">

```apex
global Integer getFailureCount()
```

Returns the count of failed DML operations across all operation types.

**Returns** [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) — Number of failed operations.

**Example**

```apex
Integer failureCount = result.getFailureCount();
```

</div>

### getInsertedIds

<div class="apex-member">

```apex
global List<Id> getInsertedIds()
```

Returns the IDs of all successfully inserted records.

**Returns** [Id](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_id.htm) — List of inserted record IDs.

**Example**

```apex
List<Id> newIds = result.getInsertedIds();
```

</div>

### getSuccessCount

<div class="apex-member">

```apex
global Integer getSuccessCount()
```

Returns the count of successful DML operations across all operation types.

**Returns** [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) — Number of successful operations.

**Example**

```apex
Integer successCount = result.getSuccessCount();
```

</div>

### isSuccess

<div class="apex-member">

```apex
global Boolean isSuccess()
```

Returns true if all DML operations completed successfully.

**Returns** [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) — True if no failures occurred.

**Example**

```apex
DML_Builder.TransactionResult result = DML_Builder.newTransaction()
    .doInsert(record)
    .execute();
Assert.isTrue(result.isSuccess(), 'Should succeed');
```

</div>

