---
title: "UTIL_BulkUpdates"
type: class
pageClass: reference
description: "Utility methods used to initialize adaptive async jobs to update fields on multiple objects. Provides methods for bulk updating Salesforce records, such as invalidating email fields, updating ownershi"
author: "Jason Van Beukering"
group: "Bulk DML"
date: "February 2026, May 2026"
since: "1.0"
category: apex
---

# UTIL_BulkUpdates

**Class** · Group: `Bulk DML`

<div class="apex-member apex-class">

```apex
global inherited sharing class UTIL_BulkUpdates
```

Utility methods used to initialize adaptive async jobs to update fields on multiple objects. Provides methods for bulk updating Salesforce records, such as invalidating email fields, updating ownership, and deactivating users. Operations are performed using adaptive async processing which automatically selects between Queueable and Batch execution based on data volume and governor limits. All entry points inherit the flag-driven default AccessLevel resolved by DML_SharingProxy.defaultAccessLevel() — under the secure-by-default posture this is USER_MODE, so the invoking user must have CRUD and FLS on the target object and fields for the bulk update to succeed. This is deliberate: UTIL_BulkUpdates is global, and silently elevating to SYSTEM_MODE would let a low-privilege subscriber Apex caller mutate records and fields they have no native right to edit. Integrations that genuinely need admin-mandate semantics should construct a PROC_UpdateFields directly with DTO_Parameters.accessLevel = AccessLevel.SYSTEM_MODE behind a caller-side permission check; the framework declines to make that elevation implicit.

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

---

## Method Details

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
		.add(new QRY_Condition.FieldCondition('Status').equals('Closed'));
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

