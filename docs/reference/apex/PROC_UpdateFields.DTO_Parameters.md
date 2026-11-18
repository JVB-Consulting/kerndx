---
title: "PROC_UpdateFields.DTO_Parameters"
type: class
pageClass: reference
description: "DTO for parameters to query and update records."
group: "Bulk DML"
since: "1.0"
category: apex
---

# PROC_UpdateFields.DTO_Parameters

**Class** · Group: `Bulk DML`

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
| global [AccessLevel](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexcode/apex_bulk_sharing_creating_with_apex.htm) [accessLevel](#accesslevel) | The access level for the query and the save, or null to use the package default. |
| global [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) [allOrNothing](#allornothing) | Indicates if the update requires all-or-nothing behavior (default: false). |
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [objectName](#objectname) | API name of the SObject to update (e.g., 'Account'). |
| global [QRY_Condition.Evaluable](QRY_Condition.Evaluable.md) [searchConditions](#searchconditions) | Conditions to filter records for updating. |
| global [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[PROC_UpdateFields.DTO_Field](PROC_UpdateFields.DTO_Field.md)> [updateFields](#updatefields) | List of field updates to apply to the SObjects. |

### accessLevel

```apex
global AccessLevel accessLevel
```

**Type:** [AccessLevel](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexcode/apex_bulk_sharing_creating_with_apex.htm)

The access level for the query and the save, or null to use the package default. The default
runs with the running user's object, field and sharing access (user mode), unless the package's feature
settings turn it off. UTIL_BulkUpdates leaves this null, so its jobs use the default too. Set
AccessLevel.SYSTEM_MODE to skip those checks, only after your own code has checked that the user may make the
change. Set AccessLevel.USER_MODE to always check the running user's access. A user mode level that adds a
permission set, built with AccessLevel.USER_MODE.withPermissionSetId(...), is used as it is for the query and
the save, so the running user also gets the access that permission set gives.

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

