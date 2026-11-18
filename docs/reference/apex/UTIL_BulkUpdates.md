---
title: "UTIL_BulkUpdates"
type: class
pageClass: reference
description: "Utility methods used to initialize adaptive async jobs to update fields on multiple objects. Provides methods for bulk updating Salesforce records, such as invalidating email fields, updating ownershi"
author: "Jason Van Beukering"
group: "Bulk DML"
date: "February 2026, November 2026"
since: "1.0"
category: apex
---

# UTIL_BulkUpdates

**Class** · Group: `Bulk DML`

<div class="apex-member apex-class">

```apex
global inherited sharing class UTIL_BulkUpdates
```

Utility methods used to initialize adaptive async jobs to update fields on multiple objects. Provides methods for bulk updating Salesforce records, such as invalidating email fields, updating ownership, and deactivating users. Operations are performed using adaptive async processing which automatically selects between Queueable and Batch execution based on data volume and governor limits. Every method here uses the default access level that DML_SharingProxy.defaultAccessLevel() returns. That level comes from the package's feature settings, and by default it is USER_MODE. In user mode, the user who calls the method must be able to edit the object and each field it changes, or the bulk update fails. This is on purpose: UTIL_BulkUpdates is global, and if it moved to SYSTEM_MODE on its own, Apex code run by a user with few rights could change records and fields that the user cannot edit. Code that must change records whatever the user's rights should first check the user's permission itself, then build a PROC_UpdateFields with DTO_Parameters.accessLevel = AccessLevel.SYSTEM_MODE. The package never makes that change for you. copyField also needs the user to be able to read the field it copies from, and to edit the field it copies into, whatever the feature settings say.

**Example**

```apex
UTIL_BulkUpdates.invalidateEmailFields(Contact.Email);
UTIL_BulkUpdates.updateOwner('Opportunity', 'Sales Rep', 'admin@example.com');
UTIL_BulkUpdates.deactivateUsers(new Set<String>{'Chatter Free User'}, 365);
```

**See Also:** [PROC_UpdateFields](PROC_UpdateFields.md)

</div>

---

## Methods

| Method | Description |
|--------|-------------|
| global static void [copyField](#copyfield)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) sObjectName, [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) sourceFieldApiName, [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) targetFieldApiName, [QRY_Condition.Evaluable](QRY_Condition.Evaluable.md) searchConditions, [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) recordsPerBatch, [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) isAllOrNothing) | Copies one field into another field of the same row, on every record that matches the search conditions. |
| global static void [deactivateUsers](#deactivateusers)([Set](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_set.htm)<[String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)> profileNames, [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) minimumDaysInactive) | Deactivates users based on their profile names and the number of days since their last login or creation. |
| global static void [deactivateUsers](#deactivateusers)([Set](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_set.htm)<[String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)> profileNames, [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) minimumDaysInactive, [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) isAllOrNothing) | Deactivates users based on their profile names and last login or creation date, with transaction control. |
| global static void [deactivateUsers](#deactivateusers)([Set](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_set.htm)<[String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)> profileNames, [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) minimumDaysInactive, [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) recordsPerBatch, [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) isAllOrNothing) | Deactivates users based on their profile names and last login or creation date, with custom batch size and transaction control. |
| global static void [invalidateEmailFields](#invalidateemailfields)([SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm) emailFieldToInvalidate) | Invalidates all valid email addresses for the specified email field. |
| global static void [invalidateEmailFields](#invalidateemailfields)([SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm) emailFieldToInvalidate, [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) recordsPerBatch) | Invalidates all valid email addresses for the specified email field, with a custom batch size. |
| global static void [invalidateEmailFields](#invalidateemailfields)([SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm) emailFieldToInvalidate, [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) recordsPerBatch, [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) isAllOrNothing) | Invalidates all valid email addresses for the specified email field, with batch size and transaction control. |
| global static void [invalidateEmailFields](#invalidateemailfields)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) sObjectName, [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) fieldApiName) | Invalidates all valid email addresses for the specified field in a Salesforce object. |
| global static void [invalidateEmailFields](#invalidateemailfields)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) sObjectName, [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) fieldApiName, [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) isAllOrNothing) | Invalidates all valid email addresses for the specified field in a Salesforce object, with transaction control. |
| global static void [invalidateEmailFields](#invalidateemailfields)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) sObjectName, [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) fieldApiName, [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) recordsPerBatch, [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) isAllOrNothing) | Invalidates all valid email addresses for the specified field in a Salesforce object, with custom batch size and transaction control. |
| global static void [updateField](#updatefield)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) sObjectName, [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) fieldApiName, [Object](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_System_Object.htm) fieldValue, [QRY_Condition.Evaluable](QRY_Condition.Evaluable.md) searchConditions, [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) recordsPerBatch, [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) isAllOrNothing) | Updates a specific field on records in a Salesforce object based on the given search conditions. |
| global static void [updateOwner](#updateowner)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) sObjectName, [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) existingOwnerProfileName, [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) newOwnerUsername) | Updates the ownership of records based on the existing owner profile name and new owner username. |
| global static void [updateOwner](#updateowner)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) sObjectName, [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) existingOwnerProfileName, [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) newOwnerUsername, [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) recordsPerBatch, [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) isAllOrNothing) | Updates the ownership of records based on the current owner profile, new owner username, batch size, and transaction control. |

### copyField

<div class="apex-member">

```apex
global static void copyField(String sObjectName, String sourceFieldApiName, String targetFieldApiName, QRY_Condition.Evaluable searchConditions, Integer recordsPerBatch, Boolean isAllOrNothing)
```

Copies one field into another field of the same row, on every record that matches the search
conditions. Each row gets its own source value. The work runs in a background job, as with updateField.

Before the job starts, the method checks that both fields exist on the object and are two different fields. It
also refuses a pair of fields when the target cannot take a value of the source field's type. A text field or a
lookup field takes text or a record Id. A decimal number field (number, currency or percent) takes any number. A
whole number field takes only a whole number: Salesforce will not put a decimal number into it, and that error
would fail every row in the chunk, not only one row. A date, a date and time, or a checkbox field takes only its
own type. It refuses a source field that the running user cannot read. It also refuses a target field that the
running user cannot change, such as a formula field, a roll-up summary field, an auto number field, a field set
by Salesforce (for example CreatedDate), or a field the user has read-only access to. Field lengths are not
compared, so you can copy a longer text field into a shorter one. A value that does not fit fails its own row
when the row is saved, and so does a text value copied into a lookup field that is not a valid record Id. A
failed row fails every row read with it only when isAllOrNothing is true. When that happens, a Batch run goes on
with its other chunks of rows, while a run chained through queued jobs, one after another, stops at that chunk.

The job runs as the user who calls this method, with that user's object, field and sharing access, unless your
org has turned that check off in the package's feature settings. A row the user cannot edit is not changed.

The user needs read access to the source field and edit access to the target field. These two field checks do
not follow that setting: they apply either way.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `sObjectName` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The API name of the object (e.g., 'Contact'). |
| `sourceFieldApiName` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The API name of the field to copy from. |
| `targetFieldApiName` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The API name of the field to copy into. |
| `searchConditions` | [QRY_Condition.Evaluable](QRY_Condition.Evaluable.md) | The conditions used to find the records to update, or null for every record. |
| `recordsPerBatch` | [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) | The number of records to process in each batch. |
| `isAllOrNothing` | [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) | Whether one failed row fails every row read with it. |

**Throws**

| Exception | Description |
|-----------|-------------|
| [IllegalArgumentException](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_classes_exception_methods.htm) | When either field does not exist on the object, both names are the same field, the target field cannot take a value of the source field's type, the running user cannot read the source field, or the running user cannot change the target field. |

**Example**

```apex
QRY_Condition.Evaluable condition = new QRY_Condition.AndCondition()
		.add(new QRY_Condition.FieldCondition('MobilePhone', QRY_Condition.Operator.EQUALS, null))
		.add(new QRY_Condition.FieldCondition('Phone', QRY_Condition.Operator.NOT_EQUALS, null));
UTIL_BulkUpdates.copyField('Contact', 'Phone', 'MobilePhone', condition, 200, false);
```

</div>

### deactivateUsers

<div class="apex-member">

```apex
global static void deactivateUsers(Set<String> profileNames, Integer minimumDaysInactive)
```

Deactivates users based on their profile names and the number of days since their last login or creation.
Uses the maximum batch size for processing.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `profileNames` | [Set](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_set.htm) | The profile names of the users to deactivate. |
| `minimumDaysInactive` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The minimum number of days since their last login or creation. |

**Example**

```apex
Set<String> profiles = new Set<String>{'Sales Rep', 'Support Rep'};
UTIL_BulkUpdates.deactivateUsers(profiles, 365);
```

</div>

<div class="apex-member">

```apex
global static void deactivateUsers(Set<String> profileNames, Integer minimumDaysInactive, Boolean isAllOrNothing)
```

Deactivates users based on their profile names and last login or creation date, with transaction control.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `profileNames` | [Set](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_set.htm) | The profile names of the users to deactivate. |
| `minimumDaysInactive` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The minimum number of days since their last login or creation. |
| `isAllOrNothing` | [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) | Whether to abort the operation if any record fails. |

**Example**

```apex
Set<String> profiles = new Set<String>{'Support Rep'};
UTIL_BulkUpdates.deactivateUsers(profiles, 180, true);
```

</div>

<div class="apex-member">

```apex
global static void deactivateUsers(Set<String> profileNames, Integer minimumDaysInactive, Integer recordsPerBatch, Boolean isAllOrNothing)
```

Deactivates users based on their profile names and last login or creation date, with custom batch size and transaction control.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `profileNames` | [Set](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_set.htm) | The profile names of the users to deactivate. |
| `minimumDaysInactive` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The minimum number of days since their last login or creation. |
| `recordsPerBatch` | [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) | The number of records to process in each batch. |
| `isAllOrNothing` | [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) | Whether to abort the operation if any record fails. |

**Example**

```apex
Set<String> profiles = new Set<String>{'Sales Rep'};
UTIL_BulkUpdates.deactivateUsers(profiles, 90, 200, false);
```

</div>

### invalidateEmailFields

<div class="apex-member">

```apex
global static void invalidateEmailFields(SObjectField emailFieldToInvalidate)
```

Invalidates all valid email addresses for the specified email field.
Uses the maximum batch size for efficient processing.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `emailFieldToInvalidate` | [SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm) | The email field to query and invalidate in records. |

**Example**

```apex
SObjectField emailField = Account.Email;
UTIL_BulkUpdates.invalidateEmailFields(emailField);
```

</div>

<div class="apex-member">

```apex
global static void invalidateEmailFields(SObjectField emailFieldToInvalidate, Integer recordsPerBatch)
```

Invalidates all valid email addresses for the specified email field, with a custom batch size.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `emailFieldToInvalidate` | [SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm) | The email field to query and invalidate. |
| `recordsPerBatch` | [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) | The number of records to process in each batch. |

**Example**

```apex
SObjectField emailField = Contact.Email;
UTIL_BulkUpdates.invalidateEmailFields(emailField, 200);
```

</div>

<div class="apex-member">

```apex
global static void invalidateEmailFields(SObjectField emailFieldToInvalidate, Integer recordsPerBatch, Boolean isAllOrNothing)
```

Invalidates all valid email addresses for the specified email field, with batch size and transaction control.
If isAllOrNothing is true, the entire transaction is rolled back if any record fails.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `emailFieldToInvalidate` | [SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm) | The email field to query and invalidate. |
| `recordsPerBatch` | [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) | The number of records to process in each batch. |
| `isAllOrNothing` | [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) | Whether to abort the transaction on failure (true = abort on any failure). |

**Example**

```apex
SObjectField emailField = Lead.Email;
UTIL_BulkUpdates.invalidateEmailFields(emailField, 100, true);
```

</div>

<div class="apex-member">

```apex
global static void invalidateEmailFields(String sObjectName, String fieldApiName)
```

Invalidates all valid email addresses for the specified field in a Salesforce object.
Uses the maximum batch size for processing.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `sObjectName` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The name of the Salesforce object (e.g., 'Account'). |
| `fieldApiName` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The API name of the field (e.g., 'Email') to check and invalidate. |

**Example**

```apex
UTIL_BulkUpdates.invalidateEmailFields('Account', 'Email');
```

</div>

<div class="apex-member">

```apex
global static void invalidateEmailFields(String sObjectName, String fieldApiName, Boolean isAllOrNothing)
```

Invalidates all valid email addresses for the specified field in a Salesforce object, with transaction control.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `sObjectName` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The name of the Salesforce object (e.g., 'Opportunity'). |
| `fieldApiName` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The API name of the field (e.g., 'Email') to check and invalidate. |
| `isAllOrNothing` | [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) | Whether to abort the transaction on failure. |

**Example**

```apex
UTIL_BulkUpdates.invalidateEmailFields('Opportunity', 'Email', true);
```

</div>

<div class="apex-member">

```apex
global static void invalidateEmailFields(String sObjectName, String fieldApiName, Integer recordsPerBatch, Boolean isAllOrNothing)
```

Invalidates all valid email addresses for the specified field in a Salesforce object, with custom batch size and transaction control.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `sObjectName` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The name of the Salesforce object (e.g., 'Case'). |
| `fieldApiName` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The API name of the field (e.g., 'Email') to check and invalidate. |
| `recordsPerBatch` | [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) | The number of records to process in each batch. |
| `isAllOrNothing` | [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) | Whether to abort the transaction on failure. |

**Example**

```apex
UTIL_BulkUpdates.invalidateEmailFields('Case', 'Email', 500, false);
```

</div>

### updateField

<div class="apex-member">

```apex
global static void updateField(String sObjectName, String fieldApiName, Object fieldValue, QRY_Condition.Evaluable searchConditions, Integer recordsPerBatch, Boolean isAllOrNothing)
```

Updates a specific field on records in a Salesforce object based on the given search conditions.
Processes updates in batches with control over partial transaction behavior.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `sObjectName` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The name of the Salesforce object (e.g., 'Opportunity'). |
| `fieldApiName` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The API name of the field to update. |
| `fieldValue` | [Object](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_System_Object.htm) | The new value to set for the field. |
| `searchConditions` | [QRY_Condition.Evaluable](QRY_Condition.Evaluable.md) | The conditions used to find the records to update. |
| `recordsPerBatch` | [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) | The number of records to process in each batch. |
| `isAllOrNothing` | [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) | Whether to abort the transaction on failure. |

**Example**

```apex
QRY_Condition.Evaluable condition = new QRY_Condition.AndCondition()
		.add(new QRY_Condition.FieldCondition('StageName', QRY_Condition.Operator.EQUALS, 'Closed Won'));
UTIL_BulkUpdates.updateField('Opportunity', 'OwnerId', '005D0000001ABCD', condition, 100, false);
```

</div>

### updateOwner

<div class="apex-member">

```apex
global static void updateOwner(String sObjectName, String existingOwnerProfileName, String newOwnerUsername)
```

Updates the ownership of records based on the existing owner profile name and new owner username.
Uses the maximum batch size for processing.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `sObjectName` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The name of the Salesforce object (e.g., 'Opportunity'). |
| `existingOwnerProfileName` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The profile name of the current record owners. |
| `newOwnerUsername` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The username of the new owner to assign to the records. |

**Example**

```apex
UTIL_BulkUpdates.updateOwner('Opportunity', 'Sales Rep', 'john.doe@example.com');
```

</div>

<div class="apex-member">

```apex
global static void updateOwner(String sObjectName, String existingOwnerProfileName, String newOwnerUsername, Integer recordsPerBatch, Boolean isAllOrNothing)
```

Updates the ownership of records based on the current owner profile, new owner username, batch size, and transaction control.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `sObjectName` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The name of the Salesforce object (e.g., 'Account'). |
| `existingOwnerProfileName` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The profile name of the current record owners. |
| `newOwnerUsername` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The username of the new owner to assign to the records. |
| `recordsPerBatch` | [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) | The number of records to process in each batch. |
| `isAllOrNothing` | [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) | Whether to abort the transaction on failure. |

**Example**

```apex
UTIL_BulkUpdates.updateOwner('Account', 'Support Rep', 'jane.smith@example.com', 200, true);
```

</div>

