---
title: "UTIL_Sharing"
type: class
pageClass: reference
description: "Utility class for managing SObject record sharing. Provides methods for both permanent and time-bound (temporary) sharing. Known access-mode consistency issue (tracked as a known issue). Share-record "
author: "Jason Van Beukering"
group: "Utilities"
date: "January 2026, May 2026"
since: "1.0"
category: apex
---

# UTIL_Sharing

**Class** · Group: `Utilities`

<div class="apex-member apex-class">

```apex
global inherited sharing class UTIL_Sharing
```

Utility class for managing SObject record sharing. Provides methods for both permanent and time-bound (temporary) sharing. Known access-mode consistency issue (tracked as a known issue). Share-record DML is currently hard-coded to .withSystemMode().bypassSharing(). The time-bound revocation queueable legitimately needs SYSTEM_MODE as a cleanup fallback (it runs hours after grant, so the original user's session may no longer be valid). The grant / grantTemporary insert path is harder to justify: UTIL_Sharing is global and the target is a caller-specified parent object's share table, not a framework-owned bookkeeping object, so silently elevating to SYSTEM_MODE + bypassSharing() lets a low-privilege subscriber caller grant access to records they have no native right to share. This is the same privilege-escalation shape that was corrected for UTIL_PurgeRecords and UTIL_BulkUpdates — those utilities now inherit the flag-driven default so the running user's FLS/CRUD applies. UTIL_Sharing should move to the same posture for the grant path; the change is deferred because it would alter subscriber-visible behaviour of a global API and needs release-note coordination. Supports any SObject type that has a corresponding Share object (custom objects with __Share and standard objects like AccountShare, CaseShare, etc.).

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

