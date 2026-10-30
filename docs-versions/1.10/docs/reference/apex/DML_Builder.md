---
title: "DML_Builder"
type: class
pageClass: reference
description: "Fluent DML API for building and running database operations: you set it up by chaining method calls. A static method, newTransaction(), starts a transaction. Chained methods add operations and change "
author: "Jason Van Beukering"
group: "DML"
date: "February 2026, October 2026"
since: "1.0"
category: apex
---

# DML_Builder

**Class** · Group: `DML`

<div class="apex-member apex-class">

```apex
global inherited sharing class DML_Builder
```

Fluent DML API for building and running database operations: you set it up by chaining method calls. A static method, newTransaction(), starts a transaction. Chained methods add operations and change how they run. A final method, execute(), saves all operations through DML_Transaction.

**Example**

```apex
DML_Builder.TransactionResult result = DML_Builder.newTransaction()
    .doInsert(account)
    .doInsert(contact, Contact.AccountId, account)
    .doUpdate(existingRecord)
    .allowPartial()
    .execute();
```

**See Also:** [DML_Transaction](DML_Transaction.md)

</div>

---

## Methods

| Method | Description |
|--------|-------------|
| global [DML_Builder](DML_Builder.md) [allowPartial](#allowpartial)() | Enables partial success mode. |
| global [DML_Builder.DML_AsyncBuilder](DML_Builder.DML_AsyncBuilder.md) [async](#async)() | Switches to asynchronous mode. |
| global [DML_Builder](DML_Builder.md) [bypassSharing](#bypasssharing)() | Ignores record sharing for this save, so the running user can save records that other users own and that the user cannot see. |
| global [DML_Builder](DML_Builder.md) [doDelete](#dodelete)([List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm)> records) | Registers multiple records for deletion. |
| global [DML_Builder](DML_Builder.md) [doDelete](#dodelete)([SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm) record) | Registers a single record for deletion. |
| global [DML_Builder](DML_Builder.md) [doInsert](#doinsert)([List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm)> records) | Registers multiple records for insertion. |
| global [DML_Builder](DML_Builder.md) [doInsert](#doinsert)([SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm) record) | Registers a single record for insertion. |
| global [DML_Builder](DML_Builder.md) [doInsert](#doinsert)([SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm) child, [SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm) relationshipField, [SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm) parent) | Registers a child record for insertion with a relationship to a parent record. |
| global [DML_Builder](DML_Builder.md) [doUndelete](#doundelete)([List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm)> records) | Registers multiple records for undelete. |
| global [DML_Builder](DML_Builder.md) [doUndelete](#doundelete)([SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm) record) | Registers a single record for undelete. |
| global [DML_Builder](DML_Builder.md) [doUpdate](#doupdate)([List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm)> records) | Registers multiple records for update. |
| global [DML_Builder](DML_Builder.md) [doUpdate](#doupdate)([SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm) record) | Registers a single record for update. |
| global [DML_Builder](DML_Builder.md) [doUpsert](#doupsert)([List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm)> records) | Registers multiple records for upsert. |
| global [DML_Builder](DML_Builder.md) [doUpsert](#doupsert)([List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm)> records, [SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm) externalIdField) | Registers multiple records for upsert with a specific external ID field. |
| global [DML_Builder](DML_Builder.md) [doUpsert](#doupsert)([SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm) record) | Registers a single record for upsert. |
| global [DML_Builder](DML_Builder.md) [doUpsert](#doupsert)([SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm) record, [SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm) externalIdField) | Registers a single record for upsert with a specific external ID field. |
| global [DML_Builder.TransactionResult](DML_Builder.TransactionResult.md) [execute](#execute)() | Commits all registered DML operations via DML_Transaction and returns the result. |
| global [DML_Builder](DML_Builder.md) [expectRefusal](#expectrefusal)([System.StatusCode](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/langCon_apex_enums.htm) statusCode) | Declares a refusal you expect and handle, so a row refused for that reason is logged at WARN instead of ERROR when the transaction allows partial success. |
| global static [DML_Builder](DML_Builder.md) [newTransaction](#newtransaction)() | Creates a new DML_Builder instance representing a DML transaction. |
| global [DML_Builder](DML_Builder.md) [suppressExceptions](#suppressexceptions)() | Stops a DmlException from being thrown again in all-or-nothing mode. |
| global [DML_Builder](DML_Builder.md) [suppressLogging](#suppresslogging)() | Turns off LOG_Builder error logging for DML failures. |
| global [DML_Builder](DML_Builder.md) [withRetryOnLock](#withretryonlock)() | Tries the save again, once, when the platform refuses it because another transaction holds a record (UNABLE_TO_LOCK_ROW). |
| global [DML_Builder](DML_Builder.md) [withRetryOnLock](#withretryonlock)([Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) retries) | Tries the save again up to the given number of times when the platform refuses it because another transaction holds a record (UNABLE_TO_LOCK_ROW). |
| global [DML_Builder](DML_Builder.md) [withSystemMode](#withsystemmode)() | Forces AccessLevel.SYSTEM_MODE on every DML operation in this transaction. |
| global [DML_Builder](DML_Builder.md) [withUserMode](#withusermode)() | Forces AccessLevel.USER_MODE on every DML operation in this transaction, whatever the UserModeDml_Enabled feature flag says. |

### allowPartial

<div class="apex-member">

```apex
global DML_Builder allowPartial()
```

Enables partial success mode. Failed records do not cause the entire transaction to fail.

**Returns** [DML_Builder](DML_Builder.md) — This builder instance for fluent chaining.

**Example**

```apex
DML_Builder.newTransaction()
    .doUpdate(records)
    .allowPartial()
    .execute();
```

</div>

### async

<div class="apex-member">

```apex
global DML_Builder.DML_AsyncBuilder async()
```

Switches to asynchronous mode. Returns a DML_AsyncBuilder that hands the work to
PROC_ExecuteDML and UTIL_AsynchronousJobLauncher, which pick a Queueable or Batch job to suit the volume.

Five settings you made still apply in the job: the access mode (`.withUserMode()` or
`.withSystemMode()`), partial success (`.allowPartial()`), ignoring record sharing
(`.bypassSharing()`), the refusals you declared with `.expectRefusal()`, which the job logs
at WARN as a save in your own transaction would, and the row-lock retry count (`.withRetryOnLock()`),
which every batch applies within its own limits. The async job itself runs `without sharing`, so the job
sets record sharing explicitly: enforced by default, ignored only when `.bypassSharing()` was called. The
sharing of your own class does not carry into the job. `.suppressExceptions()` and `.suppressLogging()` are
dropped on purpose. They change the return value and error logging of a save in your own transaction, and an
async job has no caller to return a result to. The job's failures are always logged and reported through the
async framework's own error handling.

**Returns** [DML_Builder.DML_AsyncBuilder](DML_Builder.DML_AsyncBuilder.md) — A DML_AsyncBuilder for configuring and executing async DML.

**Example**

```apex
DML_Builder.newTransaction()
    .doUpdate(records)
    .allowPartial()
    .async()
    .execute();
```

</div>

### bypassSharing

<div class="apex-member">

```apex
global DML_Builder bypassSharing()
```

Ignores record sharing for this save, so the running user can save records that other users own
and that the user cannot see. What else is checked depends on the access mode:

- In user mode (the default while the `UserModeDml_Enabled` flag is on, or after `withUserMode()`), the running
user's object and field permissions still apply. A field the user cannot create or edit is left out of the
save, with no error, and the save logs one warning that names the object and the field. A save the user has
no object permission for, an upsert on an external Id field the user cannot read or edit, and a save that
would leave out the field that links a record to its parent are refused as user mode refuses them. A record
that names its parent only by an external Id the user cannot read is refused by Salesforce, with a message
that does not name the field.

- With `withSystemMode()`, in either order, the object and field permissions are not checked either.

- With the `UserModeDml_Enabled` flag off, a save with no access mode runs in system mode, so nothing is
checked, as for any save.

The choice is recorded in the bypass audit when the save runs.

**Returns** [DML_Builder](DML_Builder.md) — This builder instance for fluent chaining.

**Example**

```apex
// Ignores record sharing; the running user's object and field permissions still apply.
DML_Builder.newTransaction()
    .doUpdate(records)
    .bypassSharing()
    .execute();
// Ignores record sharing and the running user's object and field permissions.
DML_Builder.newTransaction()
    .doUpdate(records)
    .withSystemMode()
    .bypassSharing()
    .execute();
```

</div>

### doDelete

<div class="apex-member">

```apex
global DML_Builder doDelete(List<SObject> records)
```

Registers multiple records for deletion.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `records` | [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm) | The list of SObjects to delete. |

**Returns** [DML_Builder](DML_Builder.md) — This builder instance for fluent chaining.

**Example**

```apex
DML_Builder.newTransaction()
    .doDelete(records)
    .execute();
```

</div>

<div class="apex-member">

```apex
global DML_Builder doDelete(SObject record)
```

Registers a single record for deletion.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `record` | [SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm) | The SObject to delete. |

**Returns** [DML_Builder](DML_Builder.md) — This builder instance for fluent chaining.

**Example**

```apex
DML_Builder.newTransaction()
    .doDelete(record)
    .execute();
```

</div>

### doInsert

<div class="apex-member">

```apex
global DML_Builder doInsert(List<SObject> records)
```

Registers multiple records for insertion.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `records` | [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm) | The list of SObjects to insert. |

**Returns** [DML_Builder](DML_Builder.md) — This builder instance for fluent chaining.

**Example**

```apex
DML_Builder.newTransaction()
    .doInsert(accounts)
    .execute();
```

</div>

<div class="apex-member">

```apex
global DML_Builder doInsert(SObject record)
```

Registers a single record for insertion.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `record` | [SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm) | The SObject to insert. |

**Returns** [DML_Builder](DML_Builder.md) — This builder instance for fluent chaining.

**Example**

```apex
DML_Builder.newTransaction()
    .doInsert(new Account(Name = 'Test'))
    .execute();
```

</div>

<div class="apex-member">

```apex
global DML_Builder doInsert(SObject child, SObjectField relationshipField, SObject parent)
```

Registers a child record for insertion with a relationship to a parent record.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `child` | [SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm) | The child SObject to insert. |
| `relationshipField` | [SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm) | The field linking the child to the parent. |
| `parent` | [SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm) | The parent SObject. |

**Returns** [DML_Builder](DML_Builder.md) — This builder instance for fluent chaining.

**Example**

```apex
DML_Builder.newTransaction()
    .doInsert(account)
    .doInsert(contact, Contact.AccountId, account)
    .execute();
```

</div>

### doUndelete

<div class="apex-member">

```apex
global DML_Builder doUndelete(List<SObject> records)
```

Registers multiple records for undelete.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `records` | [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm) | The list of SObjects to undelete. |

**Returns** [DML_Builder](DML_Builder.md) — This builder instance for fluent chaining.

**Example**

```apex
DML_Builder.newTransaction()
    .doUndelete(records)
    .execute();
```

</div>

<div class="apex-member">

```apex
global DML_Builder doUndelete(SObject record)
```

Registers a single record for undelete.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `record` | [SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm) | The SObject to undelete. |

**Returns** [DML_Builder](DML_Builder.md) — This builder instance for fluent chaining.

**Example**

```apex
DML_Builder.newTransaction()
    .doUndelete(record)
    .execute();
```

</div>

### doUpdate

<div class="apex-member">

```apex
global DML_Builder doUpdate(List<SObject> records)
```

Registers multiple records for update.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `records` | [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm) | The list of SObjects to update. |

**Returns** [DML_Builder](DML_Builder.md) — This builder instance for fluent chaining.

**Example**

```apex
DML_Builder.newTransaction()
    .doUpdate(accounts)
    .execute();
```

</div>

<div class="apex-member">

```apex
global DML_Builder doUpdate(SObject record)
```

Registers a single record for update.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `record` | [SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm) | The SObject to update. |

**Returns** [DML_Builder](DML_Builder.md) — This builder instance for fluent chaining.

**Example**

```apex
DML_Builder.newTransaction()
    .doUpdate(account)
    .execute();
```

</div>

### doUpsert

<div class="apex-member">

```apex
global DML_Builder doUpsert(List<SObject> records)
```

Registers multiple records for upsert.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `records` | [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm) | The list of SObjects to upsert. |

**Returns** [DML_Builder](DML_Builder.md) — This builder instance for fluent chaining.

**Example**

```apex
DML_Builder.newTransaction()
    .doUpsert(accounts)
    .execute();
```

</div>

<div class="apex-member">

```apex
global DML_Builder doUpsert(List<SObject> records, SObjectField externalIdField)
```

Registers multiple records for upsert with a specific external ID field.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `records` | [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm) | The list of SObjects to upsert. |
| `externalIdField` | [SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm) | The external ID field for matching. |

**Returns** [DML_Builder](DML_Builder.md) — This builder instance for fluent chaining.

**Example**

```apex
DML_Builder.newTransaction()
    .doUpsert(accounts, Account.ExternalId__c)
    .execute();
```

</div>

<div class="apex-member">

```apex
global DML_Builder doUpsert(SObject record)
```

Registers a single record for upsert.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `record` | [SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm) | The SObject to upsert. |

**Returns** [DML_Builder](DML_Builder.md) — This builder instance for fluent chaining.

**Example**

```apex
DML_Builder.newTransaction()
    .doUpsert(account)
    .execute();
```

</div>

<div class="apex-member">

```apex
global DML_Builder doUpsert(SObject record, SObjectField externalIdField)
```

Registers a single record for upsert with a specific external ID field.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `record` | [SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm) | The SObject to upsert. |
| `externalIdField` | [SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm) | The external ID field for matching. |

**Returns** [DML_Builder](DML_Builder.md) — This builder instance for fluent chaining.

**Example**

```apex
DML_Builder.newTransaction()
    .doUpsert(account, Account.ExternalId__c)
    .execute();
```

</div>

### execute

<div class="apex-member">

```apex
global DML_Builder.TransactionResult execute()
```

Commits all registered DML operations via DML_Transaction and returns the result.

**Returns** [DML_Builder.TransactionResult](DML_Builder.TransactionResult.md) — A TransactionResult containing the outcome of all DML operations.

**Example**

```apex
DML_Builder.TransactionResult result = DML_Builder.newTransaction()
    .doInsert(account)
    .doInsert(contact, Contact.AccountId, account)
    .execute();
```

</div>

### expectRefusal

<div class="apex-member">

```apex
global DML_Builder expectRefusal(System.StatusCode statusCode)
```

Declares a refusal you expect and handle, so a row refused for that reason is logged at
WARN instead of ERROR when the transaction allows partial success. Every other failed row still
logs at ERROR, and the result is unchanged: the row still counts in `getFailureCount()` and
`getErrors()`, and `isSuccess()` is still false. Call it once per status code. It has no effect in
all-or-nothing mode, where any refusal fails the whole transaction. A row that also carries an error
you did not declare logs at ERROR. The setting also applies after `.async()`. In a background job the log is
the only place a refusal shows up, and the setting hides nothing there: the job logs the same refusal at WARN.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `statusCode` | [System.StatusCode](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/langCon_apex_enums.htm) | The status code of the refusal you expect, such as StatusCode.DUPLICATE_VALUE for a unique field that blocks a second copy when two processes save the same record at the same time, a clash that does no harm. |

**Returns** [DML_Builder](DML_Builder.md) — This builder instance for fluent chaining.

**Throws**

| Exception | Description |
|-----------|-------------|
| [IllegalArgumentException](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_classes_exception_methods.htm) | When statusCode is null. |

**Example**

```apex
DML_Builder.newTransaction()
    .doInsert(contacts)
    .allowPartial()
    .expectRefusal(StatusCode.DUPLICATE_VALUE)
    .execute();
```

</div>

### newTransaction

<div class="apex-member">

```apex
global static DML_Builder newTransaction()
```

Creates a new DML_Builder instance representing a DML transaction.

**Returns** [DML_Builder](DML_Builder.md) — A new DML_Builder instance.

**Example**

```apex
DML_Builder.newTransaction()
    .doInsert(account)
    .execute();
```

</div>

### suppressExceptions

<div class="apex-member">

```apex
global DML_Builder suppressExceptions()
```

Stops a DmlException from being thrown again in all-or-nothing mode. The failure shows on the
returned TransactionResult instead of reaching the caller as an exception. The save's single ERROR entry,
written in DML_Transaction.commitWork, still records it unless suppressLogging() is also set. In user mode, a
save refused because the running user lacks the object permission it needs also returns a failed result
instead of throwing.

**Returns** [DML_Builder](DML_Builder.md) — This builder instance for fluent chaining.

**Example**

```apex
DML_Builder.newTransaction()
    .doInsert(record)
    .suppressExceptions()
    .execute();
```

</div>

### suppressLogging

<div class="apex-member">

```apex
global DML_Builder suppressLogging()
```

Turns off LOG_Builder error logging for DML failures. This covers the entry for each failed row
of a partial save. It also covers the single ERROR entry the transaction writes when a save fails completely,
or when partial mode catches an exception thrown during the save. It also turns off the warning that
bypassSharing() logs in user mode when it leaves out fields the user cannot create or edit.

**Returns** [DML_Builder](DML_Builder.md) — This builder instance for fluent chaining.

**Example**

```apex
DML_Builder.newTransaction()
    .doUpdate(records)
    .allowPartial()
    .suppressLogging()
    .execute();
```

</div>

### withRetryOnLock

<div class="apex-member">

```apex
global DML_Builder withRetryOnLock()
```

Tries the save again, once, when the platform refuses it because another transaction holds a
record (UNABLE_TO_LOCK_ROW). This refusal is called a row lock. In all-or-nothing mode the whole save is rolled
back and runs again. In partial mode only the rows refused for a lock are saved again, before the save moves
on, and the rows that saved stay saved. Nothing else is retried: any other refusal is reported at once. There
is no pause between attempts. The platform already waits up to about ten seconds for the lock before it
refuses. So when another transaction holds the record, each attempt costs about ten seconds, and when none
does, the setting costs nothing extra. The retries stop early when the DML limits left cannot cover another
attempt. One WARN entry records a save that met a lock and then got through. A save still refused after its
last attempt carries the same details on its ERROR entry. suppressLogging() turns off both. The setting also
applies after .async(), where every batch applies it within its own limits. A retry cannot undo two things.
Platform events published immediately during a rolled-back attempt are published again. And static values a
failed attempt set, such as a trigger's own "already ran" flag, are not reset.

**Returns** [DML_Builder](DML_Builder.md) — This builder instance for fluent chaining.

**Example**

```apex
DML_Builder.newTransaction()
    .doUpdate(records)
    .withRetryOnLock()
    .execute();
```

</div>

<div class="apex-member">

```apex
global DML_Builder withRetryOnLock(Integer retries)
```

Tries the save again up to the given number of times when the platform refuses it because
another transaction holds a record (UNABLE_TO_LOCK_ROW). The count is the extra attempts after the first, from
1 to 5. Each attempt can wait about ten seconds when the record is held. A request that runs longer than five
seconds in the user's own transaction counts toward the org's limit on long-running requests at the same
time. So code that a user waits on should keep the default, and larger counts belong in asynchronous work.
Everything else is as withRetryOnLock() describes.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `retries` | [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) | Extra attempts after the first, 1 to 5. |

**Returns** [DML_Builder](DML_Builder.md) — This builder instance for fluent chaining.

**Throws**

| Exception | Description |
|-----------|-------------|
| [IllegalArgumentException](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_classes_exception_methods.htm) | When retries is null or outside 1 to 5. |

**Example**

```apex
DML_Builder.newTransaction()
    .doUpdate(records)
    .withRetryOnLock(3)
    .async()
    .execute();
```

</div>

### withSystemMode

<div class="apex-member">

```apex
global DML_Builder withSystemMode()
```

Forces `AccessLevel.SYSTEM_MODE` on every DML operation in this transaction.
Use it when code must write objects that the running user is not meant to have object or field access
(CRUD/FLS) to, such as logs, records that track background work, or other objects the framework owns.
The choice is recorded in the bypass audit when the save runs.

**Returns** [DML_Builder](DML_Builder.md) — This builder instance for fluent chaining.

**Example**

```apex
DML_Builder.newTransaction()
    .doInsert(logEntryEvent)
    .withSystemMode()
    .execute();
```

</div>

### withUserMode

<div class="apex-member">

```apex
global DML_Builder withUserMode()
```

Forces `AccessLevel.USER_MODE` on every DML operation in this transaction,
whatever the `UserModeDml_Enabled` feature flag says. Use it when a flow that serves your users must check
object and field access (CRUD/FLS), even in orgs where an admin has turned the flag off. With
`bypassSharing()`, the save ignores record sharing but still checks the object and field permissions.

**Returns** [DML_Builder](DML_Builder.md) — This builder instance for fluent chaining.

**Example**

```apex
DML_Builder.newTransaction()
    .doInsert(accountFromUserInput)
    .withUserMode()
    .execute();
```

</div>

## Inner Classes

| Class | Description |
|-------|-------------|
| [DatabaseOperation](DML_Builder.DatabaseOperation.md) | Enum to specify the type of DML operation for external use. |
| [DML_AsyncBuilder](DML_Builder.DML_AsyncBuilder.md) | Runs DML in an async job. |
| [TransactionResult](DML_Builder.TransactionResult.md) | Result object returned by execute() containing the outcome of all DML operations in the transaction. |

---

