---
title: "PROC_UpdateFields.DTO_Parameters"
type: class
pageClass: reference
description: "DTO for parameters to query and update records."
since: "1.0"
category: apex
---

# PROC_UpdateFields.DTO_Parameters

**Class**

<div class="apex-member apex-class">

```apex
global inherited sharing class PROC_UpdateFields.DTO_Parameters
```

DTO for parameters to query and update records.

</div>

---

## Fields

| Field | Description |
|-------|-------------|
| global [AccessLevel](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexcode/apex_bulk_sharing_creating_with_apex.htm) [accessLevel](#accesslevel) | Explicit AccessLevel for the bulk update commit, or null to inherit the flag-driven default resolved by DML_SharingProxy.defaultAccessLevel(). |
| global [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) [allOrNothing](#allornothing) | Indicates if the update requires all-or-nothing behavior (default: false). |
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [objectName](#objectname) | API name of the SObject to update (e.g., 'Account'). |
| global [QRY_Condition.Evaluable](QRY_Condition.Evaluable.md) [searchConditions](#searchconditions) | Conditions to filter records for updating. |
| global [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[PROC_UpdateFields.DTO_Field](PROC_UpdateFields.DTO_Field.md)> [updateFields](#updatefields) | List of field updates to apply to the SObjects. |

### accessLevel

```apex
global AccessLevel accessLevel
```

**Type:** [AccessLevel](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexcode/apex_bulk_sharing_creating_with_apex.htm)

Explicit AccessLevel for the bulk update commit, or null to inherit the
flag-driven default resolved by DML_SharingProxy.defaultAccessLevel(). Framework utilities
that own their lifecycle (e.g. UTIL_BulkUpdates) set this to AccessLevel.SYSTEM_MODE
explicitly so the bulk commit is not gated on the invoking user's FLS. Subscribers calling
PROC_UpdateFields directly may pass AccessLevel.USER_MODE to enforce their secure-by-default
opt-in.

**Example**

```apex
AccessLevel mode = instance.accessLevel;
```

### allOrNothing

```apex
global Boolean allOrNothing
```

**Type:** [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm)

Indicates if the update requires all-or-nothing behavior (default: false).

**Example**

```apex
Boolean value = instance.allOrNothing;
```

### objectName

```apex
global String objectName
```

**Type:** [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)

API name of the SObject to update (e.g., 'Account').

**Example**

```apex
String value = instance.objectName;
```

### searchConditions

```apex
global QRY_Condition.Evaluable searchConditions
```

**Type:** [QRY_Condition.Evaluable](QRY_Condition.Evaluable.md)

Conditions to filter records for updating.

**Example**

```apex
QRY_Condition.Evaluable value = instance.searchConditions;
```

### updateFields

```apex
global List<PROC_UpdateFields.DTO_Field> updateFields
```

**Type:** [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)

List of field updates to apply to the SObjects.

**Example**

```apex
List<DTO_Field> value = instance.updateFields;
```

