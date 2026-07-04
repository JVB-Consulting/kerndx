---
title: "DML_Transaction"
type: class
description: "Transaction engine for managing complex DML operations across multiple SObjects. Handles dependency ordering via topological sort, parent-child relationship resolution, and lifecycle hooks for extensi"
author: "Jason Van Beukering"
group: "DML"
date: "February 2026, May 2026"
since: "1.0"
category: apex
---

# DML_Transaction

**Class** · Group: `DML`

```apex
global virtual inherited sharing class DML_Transaction
```

**Known Derived Types:** [API_Base](API_Base.md), [API_CallCurrentOrg](API_CallCurrentOrg.md), [API_Inbound](API_Inbound.md), [API_Outbound](API_Outbound.md)

Transaction engine for managing complex DML operations across multiple SObjects. Handles dependency ordering via topological sort, parent-child relationship resolution, and lifecycle hooks for extensibility.

**Since:** 1.0

**Example:**

```apex
DML_Transaction aTransaction = new DML_Transaction();
aTransaction.registerInsert(account);
aTransaction.registerInsert(contact, Contact.AccountId, account);
aTransaction.commitWork();
```

**See Also:** [DML_Builder](DML_Builder.md)

---

## Methods

| Method | Description |
|--------|-------------|
| global virtual void [commitWork](#commitwork)() | Commits all registered DML operations using inherited sharing. |
| global virtual void [commitWork](#commitwork)([Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) enforceSharing) | Commits all registered DML operations with configurable sharing enforcement. |
| global [DML_Transaction](#dml_transaction)() | Initializes a new transaction with empty collections for managing DML operations. |
| global void [doDelete](#dodelete)([List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm)> records) | Registers multiple records for deletion. |
| global void [doDelete](#dodelete)([SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm) record) | Registers a record for deletion. |
| global void [doInsert](#doinsert)([List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm)> records) | Registers multiple records for insertion. |
| global void [doInsert](#doinsert)([SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm) record) | Registers a record for insertion. |
| global void [doInsert](#doinsert)([SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm) child, [SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm) relationshipField, [SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm) parent) | Registers a child record for insertion with a relationship to a parent record. |
| global void [doSave](#dosave)([SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm) record) | Saves a record by inserting (if no Id) or updating (if Id exists). |
| global void [doUndelete](#doundelete)([List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm)> records) | Registers multiple records for undelete. |
| global void [doUndelete](#doundelete)([SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm) record) | Registers a record for undelete. |
| global void [doUpdate](#doupdate)([List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm)> records) | Registers multiple records for update. |
| global void [doUpdate](#doupdate)([SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm) record) | Registers a record for update. |
| global void [doUpdate](#doupdate)([SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm) record, [SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm) relationshipField, [SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm) parent) | Registers a record for update with a relationship to a parent record. |
| global void [doUpsert](#doupsert)([List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm)> records) | Registers multiple records for upsert without an external ID field. |
| global void [doUpsert](#doupsert)([List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm)> records, [SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm) externalIdField) | Registers multiple records for upsert using a specific external ID field. |
| global void [doUpsert](#doupsert)([SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm) record) | Registers a record for upsert without an external ID field. |
| global void [doUpsert](#doupsert)([SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm) record, [SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm) externalIdField) | Registers a record for upsert using a specific external ID field. |
| global void [doUpsert](#doupsert)([SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm) child, [SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm) relationshipField, [SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm) externalIdField, [SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm) parent) | Registers a child record for upsert with a parent relationship and external ID field. |
| global virtual void [onCommitWorkFinished](#oncommitworkfinished)([Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) wasSuccessful) | Hook called after the commit process finalizes, indicating success or failure. |
| global virtual void [onCommitWorkFinishing](#oncommitworkfinishing)() | Hook called after DML operations but before finalization. |
| global virtual void [onCommitWorkStarting](#oncommitworkstarting)() | Hook called before the commit process starts. |
| global virtual void [onDMLFinished](#ondmlfinished)() | Hook called after DML operations complete. |
| global virtual void [onDMLStarting](#ondmlstarting)() | Hook called before DML operations start. |
| global void [setAccessLevel](#setaccesslevel)([AccessLevel](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexcode/apex_bulk_sharing_creating_with_apex.htm) accessLevel) | Sets the AccessLevel that will be passed to every DML operation via the DML_SharingProxy three-arg methods. |
| global void [setAllowPartial](#setallowpartial)([Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) allow) | Sets whether partial success is allowed for DML operations. |
| global void [setSuppressLogging](#setsuppresslogging)([Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) suppress) | Sets whether to suppress LOG_Builder error logging for partial DML results. |

---

## Method Details

### DML_Transaction

```apex
global DML_Transaction()
```

Initializes a new transaction with empty collections for managing DML operations.

**Since:** 1.0

**Example:**

```apex
DML_Transaction dmlTransaction = new DML_Transaction();
```

### commitWork

```apex
global virtual void commitWork()
```

Commits all registered DML operations using inherited sharing.

**Since:** 1.0

**Example:**

```apex
DML_Transaction dmlTransaction = new DML_Transaction();
dmlTransaction.doInsert(new Account(Name = 'Test'));
dmlTransaction.commitWork();
```

### commitWork

```apex
global virtual void commitWork(Boolean enforceSharing)
```

Commits all registered DML operations with configurable sharing enforcement.

**Parameters:**

- `enforceSharing` ([Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm)) - If true, enforces sharing; if false, bypasses sharing; if null, inherits sharing.

**Since:** 1.0

**Example:**

```apex
DML_Transaction dmlTransaction = new DML_Transaction();
dmlTransaction.doInsert(new Account(Name = 'Test'));
dmlTransaction.commitWork(false);
```

### doDelete

```apex
global void doDelete(List<SObject> records)
```

Registers multiple records for deletion.

**Parameters:**

- `records` ([List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)) - The list of SObjects to delete.

**Since:** 1.0

**Example:**

```apex
DML_Transaction dmlTransaction = new DML_Transaction();
dmlTransaction.doDelete(obsoleteRecords);
dmlTransaction.commitWork();
```

### doDelete

```apex
global void doDelete(SObject record)
```

Registers a record for deletion.

**Parameters:**

- `record` ([SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm)) - The SObject to delete.

**Since:** 1.0

**Example:**

```apex
DML_Transaction dmlTransaction = new DML_Transaction();
dmlTransaction.doDelete(obsoleteRecord);
dmlTransaction.commitWork();
```

### doInsert

```apex
global void doInsert(List<SObject> records)
```

Registers multiple records for insertion.

**Parameters:**

- `records` ([List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)) - The list of SObjects to insert.

**Since:** 1.0

**Example:**

```apex
DML_Transaction dmlTransaction = new DML_Transaction();
dmlTransaction.doInsert(new List<Account>{new Account(Name = 'A'), new Account(Name = 'B')});
dmlTransaction.commitWork();
```

### doInsert

```apex
global void doInsert(SObject record)
```

Registers a record for insertion.

**Parameters:**

- `record` ([SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm)) - The SObject to insert.

**Since:** 1.0

**Example:**

```apex
DML_Transaction dmlTransaction = new DML_Transaction();
dmlTransaction.doInsert(new Account(Name = 'Test'));
dmlTransaction.commitWork();
```

### doInsert

```apex
global void doInsert(SObject child, SObjectField relationshipField, SObject parent)
```

Registers a child record for insertion with a relationship to a parent record.
The child's relationship field will be populated with the parent's Id after commit.

**Parameters:**

- `child` ([SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm)) - The child SObject to insert.
- `relationshipField` ([SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm)) - The field linking the child to the parent (e.g., Contact.AccountId).
- `parent` ([SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm)) - The parent SObject.

**Since:** 1.0

**Example:**

```apex
DML_Transaction dmlTransaction = new DML_Transaction();
Account parent = new Account(Name = 'Parent');
Contact child = new Contact(LastName = 'Child');
dmlTransaction.doInsert(parent);
dmlTransaction.doInsert(child, Contact.AccountId, parent);
dmlTransaction.commitWork();
```

### doSave

```apex
global void doSave(SObject record)
```

Saves a record by inserting (if no Id) or updating (if Id exists).
Convenience method for mixed operations.

**Parameters:**

- `record` ([SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm)) - The SObject to save.

**Since:** 1.0

**Example:**

```apex
DML_Transaction dmlTransaction = new DML_Transaction();
dmlTransaction.doSave(new Account(Name = 'Test'));
dmlTransaction.commitWork();
```

### doUndelete

```apex
global void doUndelete(List<SObject> records)
```

Registers multiple records for undelete.

**Parameters:**

- `records` ([List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)) - The list of SObjects to undelete.

**Since:** 1.0

**Example:**

```apex
DML_Transaction dmlTransaction = new DML_Transaction();
dmlTransaction.doUndelete(deletedAccounts);
dmlTransaction.commitWork();
```

### doUndelete

```apex
global void doUndelete(SObject record)
```

Registers a record for undelete.

**Parameters:**

- `record` ([SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm)) - The SObject to undelete.

**Since:** 1.0

**Example:**

```apex
DML_Transaction dmlTransaction = new DML_Transaction();
dmlTransaction.doUndelete(deletedAccount);
dmlTransaction.commitWork();
```

### doUpdate

```apex
global void doUpdate(List<SObject> records)
```

Registers multiple records for update.

**Parameters:**

- `records` ([List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)) - The list of SObjects to update.

**Since:** 1.0

**Example:**

```apex
DML_Transaction dmlTransaction = new DML_Transaction();
dmlTransaction.doUpdate(existingAccounts);
dmlTransaction.commitWork();
```

### doUpdate

```apex
global void doUpdate(SObject record)
```

Registers a record for update.

**Parameters:**

- `record` ([SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm)) - The SObject to update.

**Since:** 1.0

**Example:**

```apex
DML_Transaction dmlTransaction = new DML_Transaction();
dmlTransaction.doUpdate(existingAccount);
dmlTransaction.commitWork();
```

### doUpdate

```apex
global void doUpdate(SObject record, SObjectField relationshipField, SObject parent)
```

Registers a record for update with a relationship to a parent record.

**Parameters:**

- `record` ([SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm)) - The SObject to update.
- `relationshipField` ([SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm)) - The field linking the record to the parent.
- `parent` ([SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm)) - The parent SObject whose Id will be set on the relationship field.

**Since:** 1.0

**Example:**

```apex
DML_Transaction dmlTransaction = new DML_Transaction();
dmlTransaction.doUpdate(contact, Contact.AccountId, newAccount);
dmlTransaction.commitWork();
```

### doUpsert

```apex
global void doUpsert(List<SObject> records)
```

Registers multiple records for upsert without an external ID field.

**Parameters:**

- `records` ([List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)) - The list of SObjects to upsert.

**Since:** 1.0

**Example:**

```apex
DML_Transaction dmlTransaction = new DML_Transaction();
dmlTransaction.doUpsert(accounts);
dmlTransaction.commitWork();
```

### doUpsert

```apex
global void doUpsert(List<SObject> records, SObjectField externalIdField)
```

Registers multiple records for upsert using a specific external ID field.

**Parameters:**

- `records` ([List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)) - The list of SObjects to upsert.
- `externalIdField` ([SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm)) - The external ID field for matching.

**Since:** 1.0

**Example:**

```apex
DML_Transaction dmlTransaction = new DML_Transaction();
dmlTransaction.doUpsert(accounts, Account.ExternalId__c);
dmlTransaction.commitWork();
```

### doUpsert

```apex
global void doUpsert(SObject record)
```

Registers a record for upsert without an external ID field.
Uses the record's Id field for matching if present.

**Parameters:**

- `record` ([SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm)) - The SObject to upsert.

**Since:** 1.0

**Example:**

```apex
DML_Transaction dmlTransaction = new DML_Transaction();
dmlTransaction.doUpsert(account);
dmlTransaction.commitWork();
```

### doUpsert

```apex
global void doUpsert(SObject record, SObjectField externalIdField)
```

Registers a record for upsert using a specific external ID field.
All records of the same SObjectType within a single transaction must use the same external ID field.

**Parameters:**

- `record` ([SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm)) - The SObject to upsert.
- `externalIdField` ([SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm)) - The external ID field for matching.

**Since:** 1.0

**Example:**

```apex
DML_Transaction dmlTransaction = new DML_Transaction();
dmlTransaction.doUpsert(account, Account.ExternalId__c);
dmlTransaction.commitWork();
```

### doUpsert

```apex
global void doUpsert(SObject child, SObjectField relationshipField, SObjectField externalIdField, SObject parent)
```

Registers a child record for upsert with a parent relationship and external ID field.

**Parameters:**

- `child` ([SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm)) - The child SObject to upsert.
- `relationshipField` ([SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm)) - The field linking the child to the parent.
- `externalIdField` ([SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm)) - The external ID field for matching.
- `parent` ([SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm)) - The parent SObject.

**Since:** 1.0

**Example:**

```apex
DML_Transaction dmlTransaction = new DML_Transaction();
dmlTransaction.doUpsert(child, Contact.AccountId, Contact.ExternalId__c, parent);
dmlTransaction.commitWork();
```

### onCommitWorkFinished

```apex
global virtual void onCommitWorkFinished(Boolean wasSuccessful)
```

Hook called after the commit process finalizes, indicating success or failure.

**Parameters:**

- `wasSuccessful` ([Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm)) - Whether the commit was successful.

**Since:** 1.0

**Example:**

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

### onCommitWorkFinishing

```apex
global virtual void onCommitWorkFinishing()
```

Hook called after DML operations but before finalization.

**Since:** 1.0

**Example:**

```apex
global override void onCommitWorkFinishing()
{
    super.onCommitWorkFinishing();
    // custom pre-finalization logic
}
```

### onCommitWorkStarting

```apex
global virtual void onCommitWorkStarting()
```

Hook called before the commit process starts.

**Since:** 1.0

**Example:**

```apex
global override void onCommitWorkStarting()
{
    super.onCommitWorkStarting();
    // custom pre-commit logic
}
```

### onDMLFinished

```apex
global virtual void onDMLFinished()
```

Hook called after DML operations complete.

**Since:** 1.0

**Example:**

```apex
global override void onDMLFinished()
{
    super.onDMLFinished();
    // custom post-DML logic
}
```

### onDMLStarting

```apex
global virtual void onDMLStarting()
```

Hook called before DML operations start.

**Since:** 1.0

**Example:**

```apex
global override void onDMLStarting()
{
    super.onDMLStarting();
    // custom pre-DML logic
}
```

### setAccessLevel

```apex
global void setAccessLevel(AccessLevel accessLevel)
```

Sets the `AccessLevel` that will be passed to every DML operation via the
`DML_SharingProxy` three-arg methods. When null, the proxy resolves to the flag-driven
default (`UserModeDml_Enabled`).

**Parameters:**

- `accessLevel` ([AccessLevel](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexcode/apex_bulk_sharing_creating_with_apex.htm)) - The AccessLevel to apply; null to inherit the flag-driven default.

**Since:** 1.0

**Example:**

```apex
DML_Transaction transaction = new DML_Transaction();
transaction.setAccessLevel(AccessLevel.SYSTEM_MODE);
transaction.doInsert(records);
transaction.commitWork();
```

### setAllowPartial

```apex
global void setAllowPartial(Boolean allow)
```

Sets whether partial success is allowed for DML operations.
When enabled, failed records do not cause the entire transaction to roll back.

**Parameters:**

- `allow` ([Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm)) - True to allow partial success, false for all-or-nothing (default).

**Since:** 1.0

**Example:**

```apex
DML_Transaction dmlTransaction = new DML_Transaction();
dmlTransaction.setAllowPartial(true);
dmlTransaction.doInsert(records);
dmlTransaction.commitWork();
```

### setSuppressLogging

```apex
global void setSuppressLogging(Boolean suppress)
```

Sets whether to suppress LOG_Builder error logging for partial DML results.
When enabled, partial failures are not logged.

**Parameters:**

- `suppress` ([Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm)) - True to suppress logging, false to allow logging (default).

**Since:** 1.0

**Example:**

```apex
DML_Transaction dmlTransaction = new DML_Transaction();
dmlTransaction.setAllowPartial(true);
dmlTransaction.setSuppressLogging(true);
dmlTransaction.doInsert(records);
dmlTransaction.commitWork();
```

