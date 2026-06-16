---
title: "UTIL_PurgeRecords"
type: class
description: "Provides utility methods for purging records from Salesforce objects using adaptive async processing. Automatically selects between Queueable and Batch execution based on data volume and governor limi"
author: "Jason Van Beukering"
group: "Bulk DML"
date: "February 2026, May 2026"
since: "1.0"
category: apex
---

# UTIL_PurgeRecords

**Class** · Group: `Bulk DML`

```apex
global inherited sharing class UTIL_PurgeRecords
```

Provides utility methods for purging records from Salesforce objects using adaptive async processing. Automatically selects between Queueable and Batch execution based on data volume and governor limits. Supports deleting all records or records older than a specified number of days. All entry points inherit the flag-driven default AccessLevel resolved by DML_SharingProxy.defaultAccessLevel() — under the secure-by-default posture this is USER_MODE, so the invoking user must have delete CRUD on the target object for the purge to succeed. This is deliberate: UTIL_PurgeRecords is global, so any subscriber Apex caller can reach it, and silently elevating to SYSTEM_MODE would let a low-privilege user destructively delete records they have no native right to delete. Integrations that genuinely need admin-mandate semantics (for example, cleanup utilities behind a custom permission gate) should construct a PROC_ExecuteDML(operation, allOrNothing, AccessLevel.SYSTEM_MODE) explicitly and pair it with a caller-side permission check; the framework declines to make that elevation implicit.

**Since:** 1.0

**Example:**

```apex
UTIL_PurgeRecords.deleteAllRecords(LogEntry__c.SObjectType);
UTIL_PurgeRecords.deleteOlderThanNDays('LogEntry__c', 90);
UTIL_PurgeRecords.deleteOlderThanNDays('Task', 'CreatedDate', 30, false, 200);
```

**See Also:** [PROC_ExecuteDML](PROC_ExecuteDML.md)

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

---

## Method Details

### deleteAllRecords

```apex
global static void deleteAllRecords(SObjectType sObjectType)
```

Deletes all records of the specified SObject type with default non-atomic behavior.

**Parameters:**

- `sObjectType` ([SObjectType](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectType.htm)) - The SObject type containing records to delete.

**Since:** 1.0

**Example:**

```apex
UTIL_PurgeRecords.deleteAllRecords(Account.SObjectType);
```

```apex
global static void deleteAllRecords(SObjectType sObjectType, Boolean isAtomic)
```

Deletes all records of the specified SObject type with configurable atomicity.

**Parameters:**

- `sObjectType` ([SObjectType](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectType.htm)) - The SObject type containing records to delete.
- `isAtomic` ([Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm)) - If true, ensures the entire operation is atomic; if false, allows partial deletes.

**Since:** 1.0

**Example:**

```apex
UTIL_PurgeRecords.deleteAllRecords(Account.SObjectType, true);
```

```apex
global static void deleteAllRecords(String objectApiName)
```

Deletes all records of the specified SObject type with default non-atomic behavior.

**Parameters:**

- `objectApiName` ([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)) - The API name of the SObject containing the records to delete.

**Since:** 1.0

**Example:**

```apex
UTIL_PurgeRecords.deleteAllRecords('Account');
```

```apex
global static void deleteAllRecords(String objectApiName, Boolean isAtomic)
```

Deletes all records of the specified SObject type with specified atomicity.

**Parameters:**

- `objectApiName` ([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)) - The API name of the SObject containing the records to delete.
- `isAtomic` ([Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm)) - If true, ensures the entire operation is atomic; if false, allows partial deletes.

**Since:** 1.0

**Example:**

```apex
UTIL_PurgeRecords.deleteAllRecords('Contact', true);
System.debug('All Contact records deleted atomically');
```

```apex
global static void deleteAllRecords(String objectApiName, Boolean isAtomic, Integer batchSize)
```

Deletes all records of the specified SObject type with customizable atomicity and batch size.

**Parameters:**

- `objectApiName` ([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)) - The API name of the SObject containing the records to delete.
- `isAtomic` ([Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm)) - If true, ensures the entire operation is atomic; if false, allows partial deletes.
- `batchSize` ([Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm)) - The size of each batch for processing records. Defaults to maximum batch size if null.

**Since:** 1.0

**Example:**

```apex
UTIL_PurgeRecords.deleteAllRecords('Lead', false, 200);
System.debug('All Lead records deleted in batches of 200');
```

### deleteOlderThanNDays

```apex
global static void deleteOlderThanNDays(SObjectType sObjectType, Integer daysThreshold)
```

Deletes records older than the specified number of days from the given SObject type,
using CreatedDate as the default date field.

**Parameters:**

- `sObjectType` ([SObjectType](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectType.htm)) - The SObject type containing records to delete.
- `daysThreshold` ([Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm)) - Records older than this number of days will be deleted.

**Since:** 1.0

**Example:**

```apex
UTIL_PurgeRecords.deleteOlderThanNDays(Task.SObjectType, 30);
```

```apex
global static void deleteOlderThanNDays(String objectApiName, Integer daysThreshold)
```

Deletes records older than the specified number of days from the given SObject type,
using CreatedDate as the default date field.

**Parameters:**

- `objectApiName` ([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)) - The API name of the SObject containing the records to delete.
- `daysThreshold` ([Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm)) - Records older than this number of days will be deleted.

**Since:** 1.0

**Example:**

```apex
UTIL_PurgeRecords.deleteOlderThanNDays('Task', 30);
System.debug('Deleted Task records older than 30 days');
```

```apex
global static void deleteOlderThanNDays(String objectApiName, String dateFieldApiName, Integer daysThreshold)
```

Deletes records older than the specified number of days based on the specified date field.

**Parameters:**

- `objectApiName` ([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)) - The API name of the SObject containing the records to delete.
- `dateFieldApiName` ([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)) - The API name of the date field used for filtering records.
- `daysThreshold` ([Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm)) - Records with a date field value older than this number of days will be deleted.

**Since:** 1.0

**Example:**

```apex
UTIL_PurgeRecords.deleteOlderThanNDays('Task', 'CreatedDate', 30);
```

```apex
global static void deleteOlderThanNDays(String objectApiName, String dateFieldApiName, Integer daysThreshold, Boolean isAtomic)
```

Deletes records older than the specified number of days with configurable atomicity.

**Parameters:**

- `objectApiName` ([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)) - The API name of the SObject containing the records to delete.
- `dateFieldApiName` ([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)) - The API name of the date field used for filtering records.
- `daysThreshold` ([Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm)) - Records with a date field value older than this number of days will be deleted.
- `isAtomic` ([Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm)) - If true, ensures the entire operation is atomic; if false, allows partial deletes.

**Since:** 1.0

**Example:**

```apex
UTIL_PurgeRecords.deleteOlderThanNDays('Task', 'CreatedDate', 30, true);
```

```apex
global static void deleteOlderThanNDays(String objectApiName, String dateFieldApiName, Integer daysThreshold, Boolean isAtomic, Integer batchSize)
```

Deletes records older than the specified number of days with customizable date field, atomicity, and batch size.

**Parameters:**

- `objectApiName` ([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)) - The API name of the SObject containing the records to delete.
- `dateFieldApiName` ([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)) - The API name of the date field to filter records by. Defaults to CreatedDate if null.
- `daysThreshold` ([Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm)) - Records older than this number of days will be deleted.
- `isAtomic` ([Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm)) - If true, ensures the entire operation is atomic; if false, allows partial deletes.
- `batchSize` ([Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm)) - The size of each batch for processing records. Defaults to maximum batch size.

**Since:** 1.0

**Example:**

```apex
UTIL_PurgeRecords.deleteOlderThanNDays('Opportunity', 'CloseDate', 180, false, 100);
System.debug('Deleted Opportunity records older than 180 days in batches of 100');
```

