---
title: "UTIL_PurgeRecords"
type: class
pageClass: reference
description: "Provides utility methods for purging records from Salesforce objects using adaptive async processing. Automatically selects between Queueable and Batch execution based on data volume and governor limi"
author: "Jason Van Beukering"
group: "Bulk DML"
date: "February 2026, October 2026"
since: "1.0"
category: apex
---

# UTIL_PurgeRecords

**Class** · Group: `Bulk DML`

<div class="apex-member apex-class">

```apex
global inherited sharing class UTIL_PurgeRecords
```

Provides utility methods for purging records from Salesforce objects using adaptive async processing. Automatically selects between Queueable and Batch execution based on data volume and governor limits. Supports deleting all records or records older than a specified number of days. All entry points inherit the flag-driven default AccessLevel resolved by DML_SharingProxy.defaultAccessLevel() — under the secure-by-default posture this is USER_MODE, so the invoking user must have delete CRUD on the target object for the purge to succeed. This is deliberate: UTIL_PurgeRecords is global, so any Apex caller in your org can reach it, and silently elevating to SYSTEM_MODE would let a low-privilege user destructively delete records they have no native right to delete. Integrations that genuinely need admin-mandate semantics (for example, cleanup utilities behind a custom permission gate) should construct a PROC_ExecuteDML(operation, allOrNothing, AccessLevel.SYSTEM_MODE) explicitly and pair it with a caller-side permission check; the framework declines to make that elevation implicit. API calls and API issues can be deleted only by a user the BypassApiRecordDeleteGuard feature flag is on for. A built-in rule turns the flag on for every holder of the Delete API Records permission, which the Kern Administrator permission set grants, and your org can widen it to more users. A purge of either, run by anyone else, deletes nothing, starts no job and logs one warning that says so. Schedule such a purge as a user the flag is on for. A purge of API calls leaves out every call that still has an open API issue, because such a call is never deleted, not even by an administrator. The purge reads as the user who runs it, so it leaves out such a call only when that user can read every open issue. The Kern Administrator permission set gives this access. When the user cannot see the open issue of a call, the delete guard refuses that call, one call at a time, and logs each refusal. A user who cannot read API issues is told so in one warning, and the purge of API calls does not start. A call that is left out is purged by a later run, once its issue is resolved or dismissed.

**Example**

```apex
UTIL_PurgeRecords.deleteAllRecords(LogEntry__c.SObjectType);
UTIL_PurgeRecords.deleteOlderThanNDays('LogEntry__c', 90);
UTIL_PurgeRecords.deleteOlderThanNDays('Task', 'CreatedDate', 30, false, 200);
```

**See Also:** [PROC_ExecuteDML](PROC_ExecuteDML.md), [UTIL_FeatureFlag](UTIL_FeatureFlag.md)

</div>

---

## Methods

| Method | Description |
|--------|-------------|
| global static void [deleteAllRecords](#deleteallrecords)([SObjectType](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectType.htm) sObjectType) | Deletes all records of the specified SObject type with default non-atomic behavior. |
| global static void [deleteAllRecords](#deleteallrecords)([SObjectType](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectType.htm) sObjectType, [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) isAtomic) | Deletes all records of the specified SObject type with configurable atomicity. |
| global static void [deleteAllRecords](#deleteallrecords)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) objectApiName) | Deletes all records of the specified SObject type with default non-atomic behavior. |
| global static void [deleteAllRecords](#deleteallrecords)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) objectApiName, [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) isAtomic) | Deletes all records of the specified SObject type with specified atomicity. |
| global static void [deleteAllRecords](#deleteallrecords)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) objectApiName, [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) isAtomic, [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) batchSize) | Deletes all records of the specified SObject type with customizable atomicity and batch size. |
| global static void [deleteOlderThanNDays](#deleteolderthanndays)([SObjectType](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectType.htm) sObjectType, [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) daysThreshold) | Deletes records older than the specified number of days from the given SObject type, using CreatedDate as the default date field. |
| global static void [deleteOlderThanNDays](#deleteolderthanndays)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) objectApiName, [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) daysThreshold) | Deletes records older than the specified number of days from the given SObject type, using CreatedDate as the default date field. |
| global static void [deleteOlderThanNDays](#deleteolderthanndays)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) objectApiName, [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) dateFieldApiName, [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) daysThreshold) | Deletes records older than the specified number of days based on the specified date field. |
| global static void [deleteOlderThanNDays](#deleteolderthanndays)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) objectApiName, [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) dateFieldApiName, [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) daysThreshold, [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) isAtomic) | Deletes records older than the specified number of days with configurable atomicity. |
| global static void [deleteOlderThanNDays](#deleteolderthanndays)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) objectApiName, [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) dateFieldApiName, [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) daysThreshold, [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) isAtomic, [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) batchSize) | Deletes records older than the specified number of days with customizable date field, atomicity, and batch size. |

### deleteAllRecords

<div class="apex-member">

```apex
global static void deleteAllRecords(SObjectType sObjectType)
```

Deletes all records of the specified SObject type with default non-atomic behavior.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `sObjectType` | [SObjectType](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectType.htm) | The SObject type containing records to delete. |

**Example**

```apex
UTIL_PurgeRecords.deleteAllRecords(Account.SObjectType);
```

</div>

<div class="apex-member">

```apex
global static void deleteAllRecords(SObjectType sObjectType, Boolean isAtomic)
```

Deletes all records of the specified SObject type with configurable atomicity.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `sObjectType` | [SObjectType](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectType.htm) | The SObject type containing records to delete. |
| `isAtomic` | [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) | If true, ensures the entire operation is atomic; if false, allows partial deletes. |

**Example**

```apex
UTIL_PurgeRecords.deleteAllRecords(Account.SObjectType, true);
```

</div>

<div class="apex-member">

```apex
global static void deleteAllRecords(String objectApiName)
```

Deletes all records of the specified SObject type with default non-atomic behavior.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `objectApiName` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The API name of the SObject containing the records to delete. |

**Example**

```apex
UTIL_PurgeRecords.deleteAllRecords('Account');
```

</div>

<div class="apex-member">

```apex
global static void deleteAllRecords(String objectApiName, Boolean isAtomic)
```

Deletes all records of the specified SObject type with specified atomicity.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `objectApiName` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The API name of the SObject containing the records to delete. |
| `isAtomic` | [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) | If true, ensures the entire operation is atomic; if false, allows partial deletes. |

**Example**

```apex
UTIL_PurgeRecords.deleteAllRecords('Contact', true);
// An asynchronous job now deletes the Contact records, so they are not gone yet when this line runs.
```

</div>

<div class="apex-member">

```apex
global static void deleteAllRecords(String objectApiName, Boolean isAtomic, Integer batchSize)
```

Deletes all records of the specified SObject type with customizable atomicity and batch size.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `objectApiName` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The API name of the SObject containing the records to delete. |
| `isAtomic` | [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) | If true, ensures the entire operation is atomic; if false, allows partial deletes. |
| `batchSize` | [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) | The size of each batch for processing records. Defaults to maximum batch size if null. |

**Example**

```apex
UTIL_PurgeRecords.deleteAllRecords('Lead', false, 200);
// An asynchronous job now deletes the Lead records, 200 records in each batch.
```

</div>

### deleteOlderThanNDays

<div class="apex-member">

```apex
global static void deleteOlderThanNDays(SObjectType sObjectType, Integer daysThreshold)
```

Deletes records older than the specified number of days from the given SObject type,
using CreatedDate as the default date field.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `sObjectType` | [SObjectType](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectType.htm) | The SObject type containing records to delete. |
| `daysThreshold` | [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) | Records older than this number of days will be deleted. |

**Example**

```apex
UTIL_PurgeRecords.deleteOlderThanNDays(Task.SObjectType, 30);
```

</div>

<div class="apex-member">

```apex
global static void deleteOlderThanNDays(String objectApiName, Integer daysThreshold)
```

Deletes records older than the specified number of days from the given SObject type,
using CreatedDate as the default date field.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `objectApiName` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The API name of the SObject containing the records to delete. |
| `daysThreshold` | [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) | Records older than this number of days will be deleted. |

**Example**

```apex
UTIL_PurgeRecords.deleteOlderThanNDays('Task', 30);
// An asynchronous job now deletes the Task records created more than 30 days ago.
```

</div>

<div class="apex-member">

```apex
global static void deleteOlderThanNDays(String objectApiName, String dateFieldApiName, Integer daysThreshold)
```

Deletes records older than the specified number of days based on the specified date field.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `objectApiName` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The API name of the SObject containing the records to delete. |
| `dateFieldApiName` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The API name of the date field used for filtering records. |
| `daysThreshold` | [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) | Records with a date field value older than this number of days will be deleted. |

**Example**

```apex
UTIL_PurgeRecords.deleteOlderThanNDays('Task', 'CreatedDate', 30);
```

</div>

<div class="apex-member">

```apex
global static void deleteOlderThanNDays(String objectApiName, String dateFieldApiName, Integer daysThreshold, Boolean isAtomic)
```

Deletes records older than the specified number of days with configurable atomicity.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `objectApiName` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The API name of the SObject containing the records to delete. |
| `dateFieldApiName` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The API name of the date field used for filtering records. |
| `daysThreshold` | [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) | Records with a date field value older than this number of days will be deleted. |
| `isAtomic` | [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) | If true, ensures the entire operation is atomic; if false, allows partial deletes. |

**Example**

```apex
UTIL_PurgeRecords.deleteOlderThanNDays('Task', 'CreatedDate', 30, true);
```

</div>

<div class="apex-member">

```apex
global static void deleteOlderThanNDays(String objectApiName, String dateFieldApiName, Integer daysThreshold, Boolean isAtomic, Integer batchSize)
```

Deletes records older than the specified number of days with customizable date field, atomicity, and batch size.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `objectApiName` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The API name of the SObject containing the records to delete. |
| `dateFieldApiName` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The API name of the date field to filter records by. Defaults to CreatedDate if null. |
| `daysThreshold` | [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) | Records older than this number of days will be deleted. |
| `isAtomic` | [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) | If true, ensures the entire operation is atomic; if false, allows partial deletes. |
| `batchSize` | [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) | The size of each batch for processing records. Defaults to maximum batch size. |

**Example**

```apex
UTIL_PurgeRecords.deleteOlderThanNDays('Opportunity', 'CloseDate', 180, false, 100);
// An asynchronous job now deletes the Opportunity records whose CloseDate is more than 180 days ago, 100 records in each batch.
```

</div>

