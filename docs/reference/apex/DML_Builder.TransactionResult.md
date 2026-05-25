---
title: "DML_Builder.TransactionResult"
type: class
description: "Result object returned by execute() containing the outcome of all DML operations in the transaction. Provides methods to inspect success/failure status, retrieve generated IDs, and access errors."
since: "1.0"
category: apex
---

# DML_Builder.TransactionResult

**Class**

```apex
global class DML_Builder.TransactionResult
```

Result object returned by execute() containing the outcome of all DML operations in the transaction. Provides methods to inspect success/failure status, retrieve generated IDs, and access errors.

**Since:** 1.0

---

## Methods

| Method | Description |
|--------|-------------|
| global [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm) [getErrors](#geterrors)() | Returns all errors from failed DML operations across all operation types. |
| global [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) [getFailureCount](#getfailurecount)() | Returns the count of failed DML operations across all operation types. |
| global [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm) [getInsertedIds](#getinsertedids)() | Returns the IDs of all successfully inserted records. |
| global [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) [getSuccessCount](#getsuccesscount)() | Returns the count of successful DML operations across all operation types. |
| global [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) [isSuccess](#issuccess)() | Returns true if all DML operations completed successfully. |

---

## Method Details

### getErrors

```apex
global List<Database.Error> getErrors()
```

Returns all errors from failed DML operations across all operation types.

**Returns:** [Database.Error](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_database_error.htm) - List of Database.Error objects from all failed operations.

**Since:** 1.0

**Example:**

```apex
List<Database.Error> errors = result.getErrors();
```

### getFailureCount

```apex
global Integer getFailureCount()
```

Returns the count of failed DML operations across all operation types.

**Returns:** [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) - Number of failed operations.

**Since:** 1.0

**Example:**

```apex
Integer failureCount = result.getFailureCount();
```

### getInsertedIds

```apex
global List<Id> getInsertedIds()
```

Returns the IDs of all successfully inserted records.

**Returns:** [Id](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_id.htm) - List of inserted record IDs.

**Since:** 1.0

**Example:**

```apex
List<Id> newIds = result.getInsertedIds();
```

### getSuccessCount

```apex
global Integer getSuccessCount()
```

Returns the count of successful DML operations across all operation types.

**Returns:** [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) - Number of successful operations.

**Since:** 1.0

**Example:**

```apex
Integer successCount = result.getSuccessCount();
```

### isSuccess

```apex
global Boolean isSuccess()
```

Returns true if all DML operations completed successfully.

**Returns:** [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) - True if no failures occurred.

**Since:** 1.0

**Example:**

```apex
DML_Builder.TransactionResult result = DML_Builder.newTransaction()
    .doInsert(record)
    .execute();
Assert.isTrue(result.isSuccess(), 'Should succeed');
```

