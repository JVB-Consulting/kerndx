---
title: "DML_Transaction"
type: class
pageClass: reference
description: "The engine that saves a set of DML operations across many SObjects as one transaction. This set is called a unit of work: the records registered to be saved together. By default, if one record fails, "
author: "Jason Van Beukering"
group: "DML"
date: "February 2026, October 2026"
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

The engine that saves a set of DML operations across many SObjects as one transaction. This set is called a unit of work: the records registered to be saved together. By default, if one record fails, the whole save is rolled back. In partial mode, the records that save stay saved. The engine saves parent object types before their children, by sorting the types so each parent comes first. It fills each child's lookup with its parent's new Id. It also offers hooks, methods a subclass can override to run its own code at fixed points of the save.

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
| global virtual void [commitWork](#commitwork)([Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) enforceSharing) | Saves all registered DML operations, with the record sharing you choose. |
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
| global void [setAccessLevel](#setaccesslevel)([AccessLevel](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexcode/apex_bulk_sharing_creating_with_apex.htm) accessLevel) | Sets the AccessLevel passed to every DML operation through the DML_SharingProxy methods that take an access level. |
| global void [setAllowPartial](#setallowpartial)([Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) allow) | Sets whether partial success is allowed for DML operations. |
| global void [setSuppressLogging](#setsuppresslogging)([Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) suppress) | Sets whether to turn off LOG_Builder error logging for DML failures. |

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

Saves all registered DML operations, with the record sharing you choose. A retry count can be set,
usually through DML_Builder.withRetryOnLock. When it is set and the platform refuses a row lock, the save is
rolled back and runs again. The hooks run once for each attempt. Static values a failed attempt set are not
reset. A retry puts back the registered records as they were when commitWork was called. Records a hook
registers during an attempt are not put back, and a record the hook registers again keeps the Id the
rolled-back attempt gave it. Every attempt empties the transaction's in-memory query cache (the query results
kept in memory for reuse) before its first statement and again when it ends, whatever the outcome. So a read
after a save never gets rows from before the save, or from a save that was rolled back.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `enforceSharing` | [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) | If true, the running user's record sharing is enforced. If null, the sharing of the calling class applies. If false, record sharing is ignored. In user mode (no access level set while the UserModeDml_Enabled flag is on, or setAccessLevel(AccessLevel.USER_MODE)), false still keeps the running user's object and field permissions. A field the user cannot create or edit is left out of the save and logged as a warning, with no error. A save the user has no object permission for, an upsert on an external Id field the user cannot read or edit, and a save that would leave out the field that links a record to its parent are refused as user mode refuses them. A record that names its parent only by an external Id the user cannot read is refused by Salesforce, with a message that does not name the field. These checks use only the running user's own permissions. When user mode is set with a permission set, through setAccessLevel(AccessLevel.USER_MODE.withPermissionSetId(permissionSetId)), a field that only the permission set lets the user edit is still left out. A refused save is sent with that access level, so the platform takes the permission set into account when it decides. That save runs in user mode, so it also applies record sharing. In system mode, set through setAccessLevel(AccessLevel.SYSTEM_MODE) or by turning the flag off, false waives those permission checks too. |

**Example**

```apex
DML_Transaction dmlTransaction = new DML_Transaction();
dmlTransaction.doUpdate(recordOwnedByAnotherUser);
// Ignores record sharing; the running user's object and field permissions still apply.
dmlTransaction.commitWork(false);
DML_Transaction systemTransaction = new DML_Transaction();
systemTransaction.setAccessLevel(AccessLevel.SYSTEM_MODE);
systemTransaction.doUpdate(recordOwnedByAnotherUser);
// Ignores record sharing and the running user's object and field permissions.
systemTransaction.commitWork(false);
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

Hook called after the commit process finalizes, indicating success or failure. It runs after the
transaction's in-memory query cache has been emptied, so a read made here is cached like any other and sees the
rows as they are after the attempt, whether it was saved or rolled back. It runs once for each attempt of the
commit: when the commit is set to try again after a row lock (DML_Builder.withRetryOnLock does that, and an API
handler's commit tries again once), it runs with false after the attempt that was refused and again after the next
attempt. So write what you do here so that it is safe to run more than once, and do work that must happen once only
when the value is true.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `wasSuccessful` | [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) | Whether the attempt that just ended was successful. |

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

Hook called before the commit process starts. Work registered here is committed with the rest
and, in an all-or-nothing commit, rolled back with it when a later statement fails. A read made here is cached
like any other read and is from before this commit's write. It runs once for each attempt of the commit: when the
commit is set to try again after a row lock (DML_Builder.withRetryOnLock does that, and an API handler's commit
tries again once), it runs again for the new attempt. So write what you do here so that it is safe to run more than
once.

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

Hook called before DML operations start. A read made here is cached like any other read and is from
before this commit's write.

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

Sets the `AccessLevel` passed to every DML operation through the `DML_SharingProxy` methods
that take an access level. When it is null, the proxy uses the default that the `UserModeDml_Enabled`
flag sets.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `accessLevel` | [AccessLevel](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexcode/apex_bulk_sharing_creating_with_apex.htm) | The AccessLevel to apply; null to use the default that the flag sets. |

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

Sets whether to turn off LOG_Builder error logging for DML failures. When it is on, failed rows
in a partial save are not logged, and neither is a failed save. That covers the ERROR entry an all-or-nothing
save writes after it rolls back, just before it throws the exception again. It also covers the ERROR entry a
partial save writes when it catches an exception thrown during the save and carries on. It also covers the
warning `commitWork(false)` logs in user mode when it leaves out fields the user cannot create or edit.

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

