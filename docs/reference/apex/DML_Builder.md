---
title: "DML_Builder"
type: class
pageClass: reference
description: "Fluent DML API for building and executing database operations. Uses a static factory entry point to create a transaction context, fluent methods to register operations and configure behaviour, and a t"
author: "Jason Van Beukering"
group: "DML"
date: "February 2026, June 2026"
since: "1.0"
category: apex
---

# DML_Builder

**Class** · Group: `DML`

<div class="apex-member apex-class">

```apex
global inherited sharing class DML_Builder
```

Fluent DML API for building and executing database operations. Uses a static factory entry point to create a transaction context, fluent methods to register operations and configure behaviour, and a terminal method to commit all operations via DML_Transaction.

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

## Properties

| Property | Description |
|----------|-------------|
| global enum [DatabaseOperation](DML_Builder.DatabaseOperation.md) | Enum to specify the type of DML operation for external use. |

## Methods

| Method | Description |
|--------|-------------|
| global [DML_Builder](DML_Builder.md) [allowPartial](#allowpartial)() | Enables partial success mode. |
| global [DML_Builder.DML_AsyncBuilder](DML_Builder.DML_AsyncBuilder.md) [async](#async)() | Switches to asynchronous execution mode. |
| global [DML_Builder](DML_Builder.md) [bypassSharing](#bypasssharing)() | Bypasses sharing rules for DML operations. |
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
| global static [DML_Builder](DML_Builder.md) [newTransaction](#newtransaction)() | Creates a new DML_Builder instance representing a DML transaction. |
| global [DML_Builder](DML_Builder.md) [suppressExceptions](#suppressexceptions)() | Suppresses DmlException re-throw in all-or-nothing mode. |
| global [DML_Builder](DML_Builder.md) [suppressLogging](#suppresslogging)() | Suppresses LOG_Builder error logging for DML failures. |
| global [DML_Builder](DML_Builder.md) [withSystemMode](#withsystemmode)() | Forces AccessLevel.SYSTEM_MODE on every DML operation in this transaction. |
| global [DML_Builder](DML_Builder.md) [withUserMode](#withusermode)() | Forces AccessLevel.USER_MODE on every DML operation in this transaction, regardless of the UserModeDml_Enabled feature flag. |

## Inner Classes

| Class | Description |
|-------|-------------|
| [DML_AsyncBuilder](DML_Builder.DML_AsyncBuilder.md) | Async DML execution wrapper. |
| [TransactionResult](DML_Builder.TransactionResult.md) | Result object returned by execute() containing the outcome of all DML operations in the transaction. |

---

## Method Details

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

Switches to asynchronous execution mode. Returns a DML_AsyncBuilder that delegates to
PROC_ExecuteDML and UTIL_AsynchronousJobLauncher for adaptive async processing.

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

Bypasses sharing rules for DML operations.

**Returns** [DML_Builder](DML_Builder.md) — This builder instance for fluent chaining.

**Example**

```apex
DML_Builder.newTransaction()
    .doUpdate(records)
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

Suppresses DmlException re-throw in all-or-nothing mode. Errors are logged
via LOG_Builder instead of propagating to the caller.

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

Suppresses LOG_Builder error logging for DML failures.

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

### withSystemMode

<div class="apex-member">

```apex
global DML_Builder withSystemMode()
```

Forces `AccessLevel.SYSTEM_MODE` on every DML operation in this transaction.
Use when the framework writes objects the running user has no FLS/CRUD on by design
(logs, orchestration records, framework-owned sObjects).

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
regardless of the `UserModeDml_Enabled` feature flag. Use when a subscriber-facing flow
must enforce CRUD/FLS even in orgs where the flag has been disabled as a kill-switch.

**Returns** [DML_Builder](DML_Builder.md) — This builder instance for fluent chaining.

**Example**

```apex
DML_Builder.newTransaction()
    .doInsert(accountFromSubscriberUI)
    .withUserMode()
    .execute();
```

</div>

