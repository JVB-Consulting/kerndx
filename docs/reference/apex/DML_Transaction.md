---
title: "DML_Transaction"
type: class
pageClass: reference
description: "Transaction engine for managing complex DML operations across multiple SObjects. Handles dependency ordering via topological sort, parent-child relationship resolution, and lifecycle hooks for extensi"
author: "Jason Van Beukering"
group: "DML"
date: "February 2026, May 2026"
since: "1.0"
category: apex
---

# DML_Transaction

**Class** · Group: `DML`

<div class="apex-member apex-class">

```apex
global virtual inherited sharing class DML_Transaction
```

**Known Derived Types:** [API_Base](API_Base.md), [API_CallCurrentOrg](API_CallCurrentOrg.md), [API_Inbound](API_Inbound.md), [API_Outbound](API_Outbound.md)

Transaction engine for managing complex DML operations across multiple SObjects. Handles dependency ordering via topological sort, parent-child relationship resolution, and lifecycle hooks for extensibility.

**Example**

```apex
DML_Transaction aTransaction = new DML_Transaction();
aTransaction.registerInsert(account);
aTransaction.registerInsert(contact, Contact.AccountId, account);
aTransaction.commitWork();
```

**See Also:** [DML_Builder](DML_Builder.md)

</div>

---

## Methods

| Method | Description |
|--------|-------------|
| global virtual void [commitWork](#commitwork)() | Commits all registered DML operations using inherited sharing. |
| global virtual void [commitWork](#commitwork)([Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) enforceSharing) | Commits all registered DML operations with configurable sharing enforcement. |
| global void [doDelete](#dodelete)([List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm)> records) | Registers multiple records for deletion. |
| global void [doDelete](#dodelete)([SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm) record) | Registers a record for deletion. |
| global void [doInsert](#doinsert)([List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm)> records) | Registers multiple records for insertion. |
| global void [doInsert](#doinsert)([SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm) record) | Registers a record for insertion. |
| global void [doInsert](#doinsert)([SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm) child, [SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm) relationshipField, [SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm) parent) | Registers a child record for insertion with a relationship to a parent record. |
| global void [doSave](#dosave)([SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm) record) | Saves a record by inserting (if no Id) or updating (if Id exists). |
| global void [doUndelete](#doundelete)([List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm)> records) | Registers multiple records for undelete. |
| global void [doUndelete](#doundelete)([SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm) record) | Registers a record for undelete. |
| global void [doUpdate](#doupdate)([List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm)> records) | Registers multiple records for update. |
| global void [doUpdate](#doupdate)([SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm) record) | Registers a record for update. |
| global void [doUpdate](#doupdate)([SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm) record, [SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm) relationshipField, [SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm) parent) | Registers a record for update with a relationship to a parent record. |
| global void [doUpsert](#doupsert)([List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm)> records) | Registers multiple records for upsert without an external ID field. |
| global void [doUpsert](#doupsert)([List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm)> records, [SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm) externalIdField) | Registers multiple records for upsert using a specific external ID field. |
| global void [doUpsert](#doupsert)([SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm) record) | Registers a record for upsert without an external ID field. |
| global void [doUpsert](#doupsert)([SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm) record, [SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm) externalIdField) | Registers a record for upsert using a specific external ID field. |
| global void [doUpsert](#doupsert)([SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm) child, [SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm) relationshipField, [SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm) externalIdField, [SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm) parent) | Registers a child record for upsert with a parent relationship and external ID field. |
| global virtual void [onCommitWorkFinished](#oncommitworkfinished)([Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) wasSuccessful) | Hook called after the commit process finalizes, indicating success or failure. |
| global virtual void [onCommitWorkFinishing](#oncommitworkfinishing)() | Hook called after DML operations but before finalization. |
| global virtual void [onCommitWorkStarting](#oncommitworkstarting)() | Hook called before the commit process starts. |
| global virtual void [onDMLFinished](#ondmlfinished)() | Hook called after DML operations complete. |
| global virtual void [onDMLStarting](#ondmlstarting)() | Hook called before DML operations start. |
| global void [setAccessLevel](#setaccesslevel)([AccessLevel](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexcode/apex_bulk_sharing_creating_with_apex.htm) accessLevel) | Sets the AccessLevel that will be passed to every DML operation via the DML_SharingProxy three-arg methods. |
| global void [setAllowPartial](#setallowpartial)([Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) allow) | Sets whether partial success is allowed for DML operations. |
| global void [setSuppressLogging](#setsuppresslogging)([Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) suppress) | Sets whether to suppress LOG_Builder error logging for partial DML results. |

### commitWork

<div class="apex-member">

```apex
global virtual void commitWork()
```

Commits all registered DML operations using inherited sharing.

**Example**

```apex
DML_Transaction dmlTransaction = new DML_Transaction();
dmlTransaction.doInsert(new Account(Name = 'Test'));
dmlTransaction.commitWork();
```

</div>

<div class="apex-member">

```apex
global virtual void commitWork(Boolean enforceSharing)
```

Commits all registered DML operations with configurable sharing enforcement.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `enforceSharing` | [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) | If true, enforces sharing; if false, bypasses sharing; if null, inherits sharing. |

**Example**

```apex
DML_Transaction dmlTransaction = new DML_Transaction();
dmlTransaction.doInsert(new Account(Name = 'Test'));
dmlTransaction.commitWork(false);
```

</div>

### doDelete

<div class="apex-member">

```apex
global void doDelete(List<SObject> records)
```

Registers multiple records for deletion.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `records` | [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm) | The list of SObjects to delete. |

**Example**

```apex
DML_Transaction dmlTransaction = new DML_Transaction();
dmlTransaction.doDelete(obsoleteRecords);
dmlTransaction.commitWork();
```

</div>

<div class="apex-member">

```apex
global void doDelete(SObject record)
```

Registers a record for deletion.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `record` | [SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm) | The SObject to delete. |

**Example**

```apex
DML_Transaction dmlTransaction = new DML_Transaction();
dmlTransaction.doDelete(obsoleteRecord);
dmlTransaction.commitWork();
```

</div>

### doInsert

<div class="apex-member">

```apex
global void doInsert(List<SObject> records)
```

Registers multiple records for insertion.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `records` | [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm) | The list of SObjects to insert. |

**Example**

```apex
DML_Transaction dmlTransaction = new DML_Transaction();
dmlTransaction.doInsert(new List<Account>{new Account(Name = 'A'), new Account(Name = 'B')});
dmlTransaction.commitWork();
```

</div>

<div class="apex-member">

```apex
global void doInsert(SObject record)
```

Registers a record for insertion.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `record` | [SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm) | The SObject to insert. |

**Example**

```apex
DML_Transaction dmlTransaction = new DML_Transaction();
dmlTransaction.doInsert(new Account(Name = 'Test'));
dmlTransaction.commitWork();
```

</div>

<div class="apex-member">

```apex
global void doInsert(SObject child, SObjectField relationshipField, SObject parent)
```

Registers a child record for insertion with a relationship to a parent record.
The child's relationship field will be populated with the parent's Id after commit.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `child` | [SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm) | The child SObject to insert. |
| `relationshipField` | [SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm) | The field linking the child to the parent (e.g., Contact.AccountId). |
| `parent` | [SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm) | The parent SObject. |

**Example**

```apex
DML_Transaction dmlTransaction = new DML_Transaction();
Account parent = new Account(Name = 'Parent');
Contact child = new Contact(LastName = 'Child');
dmlTransaction.doInsert(parent);
dmlTransaction.doInsert(child, Contact.AccountId, parent);
dmlTransaction.commitWork();
```

</div>

### doSave

<div class="apex-member">

```apex
global void doSave(SObject record)
```

Saves a record by inserting (if no Id) or updating (if Id exists).
Convenience method for mixed operations.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `record` | [SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm) | The SObject to save. |

**Example**

```apex
DML_Transaction dmlTransaction = new DML_Transaction();
dmlTransaction.doSave(new Account(Name = 'Test'));
dmlTransaction.commitWork();
```

</div>

### doUndelete

<div class="apex-member">

```apex
global void doUndelete(List<SObject> records)
```

Registers multiple records for undelete.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `records` | [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm) | The list of SObjects to undelete. |

**Example**

```apex
DML_Transaction dmlTransaction = new DML_Transaction();
dmlTransaction.doUndelete(deletedAccounts);
dmlTransaction.commitWork();
```

</div>

<div class="apex-member">

```apex
global void doUndelete(SObject record)
```

Registers a record for undelete.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `record` | [SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm) | The SObject to undelete. |

**Example**

```apex
DML_Transaction dmlTransaction = new DML_Transaction();
dmlTransaction.doUndelete(deletedAccount);
dmlTransaction.commitWork();
```

</div>

### doUpdate

<div class="apex-member">

```apex
global void doUpdate(List<SObject> records)
```

Registers multiple records for update.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `records` | [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm) | The list of SObjects to update. |

**Example**

```apex
DML_Transaction dmlTransaction = new DML_Transaction();
dmlTransaction.doUpdate(existingAccounts);
dmlTransaction.commitWork();
```

</div>

<div class="apex-member">

```apex
global void doUpdate(SObject record)
```

Registers a record for update.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `record` | [SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm) | The SObject to update. |

**Example**

```apex
DML_Transaction dmlTransaction = new DML_Transaction();
dmlTransaction.doUpdate(existingAccount);
dmlTransaction.commitWork();
```

</div>

<div class="apex-member">

```apex
global void doUpdate(SObject record, SObjectField relationshipField, SObject parent)
```

Registers a record for update with a relationship to a parent record.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `record` | [SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm) | The SObject to update. |
| `relationshipField` | [SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm) | The field linking the record to the parent. |
| `parent` | [SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm) | The parent SObject whose Id will be set on the relationship field. |

**Example**

```apex
DML_Transaction dmlTransaction = new DML_Transaction();
dmlTransaction.doUpdate(contact, Contact.AccountId, newAccount);
dmlTransaction.commitWork();
```

</div>

### doUpsert

<div class="apex-member">

```apex
global void doUpsert(List<SObject> records)
```

Registers multiple records for upsert without an external ID field.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `records` | [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm) | The list of SObjects to upsert. |

**Example**

```apex
DML_Transaction dmlTransaction = new DML_Transaction();
dmlTransaction.doUpsert(accounts);
dmlTransaction.commitWork();
```

</div>

<div class="apex-member">

```apex
global void doUpsert(List<SObject> records, SObjectField externalIdField)
```

Registers multiple records for upsert using a specific external ID field.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `records` | [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm) | The list of SObjects to upsert. |
| `externalIdField` | [SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm) | The external ID field for matching. |

**Example**

```apex
DML_Transaction dmlTransaction = new DML_Transaction();
dmlTransaction.doUpsert(accounts, Account.ExternalId__c);
dmlTransaction.commitWork();
```

</div>

<div class="apex-member">

```apex
global void doUpsert(SObject record)
```

Registers a record for upsert without an external ID field.
Uses the record's Id field for matching if present.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `record` | [SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm) | The SObject to upsert. |

**Example**

```apex
DML_Transaction dmlTransaction = new DML_Transaction();
dmlTransaction.doUpsert(account);
dmlTransaction.commitWork();
```

</div>

<div class="apex-member">

```apex
global void doUpsert(SObject record, SObjectField externalIdField)
```

Registers a record for upsert using a specific external ID field.
All records of the same SObjectType within a single transaction must use the same external ID field.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `record` | [SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm) | The SObject to upsert. |
| `externalIdField` | [SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm) | The external ID field for matching. |

**Example**

```apex
DML_Transaction dmlTransaction = new DML_Transaction();
dmlTransaction.doUpsert(account, Account.ExternalId__c);
dmlTransaction.commitWork();
```

</div>

<div class="apex-member">

```apex
global void doUpsert(SObject child, SObjectField relationshipField, SObjectField externalIdField, SObject parent)
```

Registers a child record for upsert with a parent relationship and external ID field.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `child` | [SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm) | The child SObject to upsert. |
| `relationshipField` | [SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm) | The field linking the child to the parent. |
| `externalIdField` | [SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm) | The external ID field for matching. |
| `parent` | [SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm) | The parent SObject. |

**Example**

```apex
DML_Transaction dmlTransaction = new DML_Transaction();
dmlTransaction.doUpsert(child, Contact.AccountId, Contact.ExternalId__c, parent);
dmlTransaction.commitWork();
```

</div>

### onCommitWorkFinished

<div class="apex-member">

```apex
global virtual void onCommitWorkFinished(Boolean wasSuccessful)
```

Hook called after the commit process finalizes, indicating success or failure.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `wasSuccessful` | [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) | Whether the commit was successful. |

**Example**

```apex
global override void onCommitWorkFinished(Boolean wasSuccessful)
{
    super.onCommitWorkFinished(wasSuccessful);
    if(wasSuccessful)
    {
        // custom post-commit logic
    }
}
```

</div>

### onCommitWorkFinishing

<div class="apex-member">

```apex
global virtual void onCommitWorkFinishing()
```

Hook called after DML operations but before finalization.

**Example**

```apex
global override void onCommitWorkFinishing()
{
    super.onCommitWorkFinishing();
    // custom pre-finalization logic
}
```

</div>

### onCommitWorkStarting

<div class="apex-member">

```apex
global virtual void onCommitWorkStarting()
```

Hook called before the commit process starts.

**Example**

```apex
global override void onCommitWorkStarting()
{
    super.onCommitWorkStarting();
    // custom pre-commit logic
}
```

</div>

### onDMLFinished

<div class="apex-member">

```apex
global virtual void onDMLFinished()
```

Hook called after DML operations complete.

**Example**

```apex
global override void onDMLFinished()
{
    super.onDMLFinished();
    // custom post-DML logic
}
```

</div>

### onDMLStarting

<div class="apex-member">

```apex
global virtual void onDMLStarting()
```

Hook called before DML operations start.

**Example**

```apex
global override void onDMLStarting()
{
    super.onDMLStarting();
    // custom pre-DML logic
}
```

</div>

### setAccessLevel

<div class="apex-member">

```apex
global void setAccessLevel(AccessLevel accessLevel)
```

Sets the `AccessLevel` that will be passed to every DML operation via the
`DML_SharingProxy` three-arg methods. When null, the proxy resolves to the flag-driven
default (`UserModeDml_Enabled`).

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `accessLevel` | [AccessLevel](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexcode/apex_bulk_sharing_creating_with_apex.htm) | The AccessLevel to apply; null to inherit the flag-driven default. |

**Example**

```apex
DML_Transaction transaction = new DML_Transaction();
transaction.setAccessLevel(AccessLevel.SYSTEM_MODE);
transaction.doInsert(records);
transaction.commitWork();
```

</div>

### setAllowPartial

<div class="apex-member">

```apex
global void setAllowPartial(Boolean allow)
```

Sets whether partial success is allowed for DML operations.
When enabled, failed records do not cause the entire transaction to roll back.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `allow` | [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) | True to allow partial success, false for all-or-nothing (default). |

**Example**

```apex
DML_Transaction dmlTransaction = new DML_Transaction();
dmlTransaction.setAllowPartial(true);
dmlTransaction.doInsert(records);
dmlTransaction.commitWork();
```

</div>

### setSuppressLogging

<div class="apex-member">

```apex
global void setSuppressLogging(Boolean suppress)
```

Sets whether to suppress LOG_Builder error logging for partial DML results.
When enabled, partial failures are not logged.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `suppress` | [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) | True to suppress logging, false to allow logging (default). |

**Example**

```apex
DML_Transaction dmlTransaction = new DML_Transaction();
dmlTransaction.setAllowPartial(true);
dmlTransaction.setSuppressLogging(true);
dmlTransaction.doInsert(records);
dmlTransaction.commitWork();
```

</div>

## Constructors

| Constructor | Description |
|-------------|-------------|
| global [DML_Transaction](#constructors)() | Initializes a new transaction with empty collections for managing DML operations. |

### DML_Transaction()

<div class="apex-member">

```apex
global DML_Transaction()
```

Initializes a new transaction with empty collections for managing DML operations.

**Example**

```apex
DML_Transaction dmlTransaction = new DML_Transaction();
```

</div>

