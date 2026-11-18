---
title: "DML_Builder.TransactionResult"
type: class
pageClass: reference
description: "Result object returned by execute() containing the outcome of all DML operations in the transaction. Provides methods to inspect success/failure status, retrieve generated IDs, and access errors."
group: "DML"
since: "1.0"
category: apex
---

# DML_Builder.TransactionResult

**Class** · Group: `DML`

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
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [getFailureMessage](#getfailuremessage)() | Returns why a save failed when no exception reached your code. |
| global [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[Id](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_id.htm)> [getInsertedIds](#getinsertedids)() | Returns the IDs of all successfully inserted records. |
| global [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) [getSuccessCount](#getsuccesscount)() | Returns the count of successful DML operations across all operation types. |
| global [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) [isSuccess](#issuccess)() | Returns true if all DML operations completed successfully. |

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

Returns the count of failed DML operations across all operation types. For a save that
`suppressExceptions()` turned into a failed result, every record counts as failed when the exception holds no row details.
For a partial save stopped by an exception, the count is an estimate, and it is at least 1. It adds the failed rows to
the records with no result. It can be too low when a child has the same object type as its parent, because the save
then updates that child a second time, and the extra result hides a record that has none.

**Returns** [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) — Number of failed operations.

**Example**

```apex
Integer failureCount = result.getFailureCount();
```

</div>

### getFailureMessage

<div class="apex-member">

```apex
global String getFailureMessage()
```

Returns why a save failed when no exception reached your code. There are two such cases: a failure that
`suppressExceptions()` caught, and an exception that stopped a partial save. Neither one gives row results, so
`getErrors()` does not show it. When a partial save only refuses some rows, this returns null: read each row's reason
from `getErrors()`. When Salesforce refused the save, this returns the message for the first failed row, without the
status code.

**Returns** [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) — The reason, or null when the save has no such failure.

**Example**

```apex
DML_Builder.TransactionResult result = DML_Builder.newTransaction()
    .doInsert(record)
    .suppressExceptions()
    .execute();
String reason = result.getFailureMessage();
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

