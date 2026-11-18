---
title: "UTIL_Sharing"
type: class
pageClass: reference
description: "Utility class for managing SObject record sharing. Provides methods for both permanent and time-bound (temporary) sharing. How share records are saved. Every save of a share record runs with .withSyst"
author: "Jason Van Beukering"
group: "Utilities"
date: "January 2026, October 2026"
since: "1.0"
category: apex
---

# UTIL_Sharing

**Class** · Group: `Utilities`

<div class="apex-member apex-class">

```apex
global inherited sharing class UTIL_Sharing
```

Utility class for managing SObject record sharing. Provides methods for both permanent and time-bound (temporary) sharing. How share records are saved. Every save of a share record runs with .withSystemMode().bypassSharing(). This holds on both paths: the grant path (grant and grantTemporary) and the revoke path. System mode means the save skips the running user's object and field permissions, and bypassSharing() means it also skips their record sharing. The revoke path needs this. A time-bound share is removed by a queued job that runs hours after the grant, when the session of the user who granted it may no longer be valid. On the grant path, the target is the share table of a parent object the caller chooses, not a record the framework owns. So a caller with few permissions in your org can grant access to records they could not share themselves. UTIL_PurgeRecords and UTIL_BulkUpdates work differently: they save with the access the User Mode DML feature flag selects, which by default is the running user's object and field permissions. Supports any SObject type that has a corresponding Share object (custom objects with __Share and standard objects like AccountShare, CaseShare, etc.).

**Example**

```apex
List<Account> accounts = QRY_Builder.selectFrom(Account.SObjectType)
    .fields(new List<String>{'Id'})
    .withLimit(10)
    .toList();
Id groupId = new SEL_Group().findByName('AllUsers').Id;
// Permanent sharing - grant read access indefinitely
List<SObject> shares = UTIL_Sharing.grant(accounts, groupId, 'Read');
// Temporary sharing - grant read access for 30 minutes
List<SObject> tempShares = UTIL_Sharing.grantTemporary(accounts, groupId, 'Read', 30);
```

**See Also:** [UTIL_AsynchronousJobLauncher](UTIL_AsynchronousJobLauncher.md)

</div>

---

## Methods

| Method | Description |
|--------|-------------|
| global static [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm)> [grant](#grant)([List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm)> records, [Id](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_id.htm) userOrGroupId, [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) accessLevel) | Grants permanent access to the specified records for a user or group. |
| global static [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm)> [grantTemporary](#granttemporary)([List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm)> records, [Id](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_id.htm) userOrGroupId, [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) accessLevel, [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) validityMinutes) | Grants temporary access to the specified records for a user or group. |

### grant

<div class="apex-member">

```apex
global static List<SObject> grant(List<SObject> records, Id userOrGroupId, String accessLevel)
```

Grants permanent access to the specified records for a user or group.
Creates share records that remain until explicitly deleted.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `records` | [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm) | The SObject records to share (must have an Id). |
| `userOrGroupId` | [SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm) | The ID of the User or Group to grant access to. |
| `accessLevel` | [Id](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_id.htm) | The level of access to grant ('Read', 'Edit', or 'All'). |

**Returns** [SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm) — The created share records.

**Throws**

| Exception | Description |
|-----------|-------------|
| [IllegalArgumentException](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_classes_exception_methods.htm) | if any parameter is invalid. |

**Example**

```apex
List<Account> accounts = QRY_Builder.selectFrom(Account.SObjectType)
    .fields(new List<String>{'Id'})
    .withLimit(10)
    .toList();
Id groupId = new SEL_Group().findByName('AllUsers').Id;
List<SObject> shares = UTIL_Sharing.grant(accounts, groupId, 'Edit');
```

</div>

### grantTemporary

<div class="apex-member">

```apex
global static List<SObject> grantTemporary(List<SObject> records, Id userOrGroupId, String accessLevel, Integer validityMinutes)
```

Grants temporary access to the specified records for a user or group.
Creates share records and schedules their automatic revocation after the validity period.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `records` | [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm) | The SObject records to share (must have an Id). |
| `userOrGroupId` | [SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm) | The ID of the User or Group to grant access to. |
| `accessLevel` | [Id](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_id.htm) | The level of access to grant ('Read', 'Edit', or 'All'). |
| `validityMinutes` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The duration in minutes before access is revoked. |

**Returns** [SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm) — The created share records.

**Throws**

| Exception | Description |
|-----------|-------------|
| [IllegalArgumentException](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_classes_exception_methods.htm) | if any parameter is invalid. |

**Example**

```apex
List<Account> accounts = QRY_Builder.selectFrom(Account.SObjectType)
    .fields(new List<String>{'Id'})
    .withLimit(10)
    .toList();
Id groupId = new SEL_Group().findByName('AllUsers').Id;
List<SObject> shares = UTIL_Sharing.grantTemporary(accounts, groupId, 'Edit', 60);
```

</div>

