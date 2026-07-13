---
title: "SEL_PermissionSetGroup"
type: class
pageClass: reference
description: "Selector for the PermissionSetGroup SObject. Provides default field configuration and query methods for PermissionSetGroup records. In test context, automatically recalculates groups that are not yet "
author: "Jason Van Beukering"
group: "Selectors"
date: "February 2026, May 2026"
since: "1.0"
category: apex
---

# SEL_PermissionSetGroup

**Class** · Group: `Selectors`

<div class="apex-member apex-class">

```apex
global inherited sharing class SEL_PermissionSetGroup extends SEL_Base
```

**Extends:** [SEL_Base](SEL_Base.md)

Selector for the PermissionSetGroup SObject. Provides default field configuration and query methods for PermissionSetGroup records. In test context, automatically recalculates groups that are not yet updated.

**Example**

```apex
PermissionSetGroup foundGroup = new SEL_PermissionSetGroup().findByName('ReadOnly');
List<PermissionSetGroup> groups = new SEL_PermissionSetGroup().findByName(new Set<String>{'ReadOnly', 'EditAccess'});
```

**See Also:** [SEL_Base](SEL_Base.md)

</div>

---

## Methods

| Method | Description |
|--------|-------------|
| global [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[PermissionSetGroup](https://developer.salesforce.com/docs/atlas.en-us.object_reference.meta/object_reference/sforce_api_objects_permissionsetgroup.htm)> [findByName](#findbyname)([Set](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_set.htm)<[String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)> groupNames) | Finds PermissionSetGroups by developer names. |
| global [PermissionSetGroup](https://developer.salesforce.com/docs/atlas.en-us.object_reference.meta/object_reference/sforce_api_objects_permissionsetgroup.htm) [findByName](#findbyname)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) developerName) | Finds a PermissionSetGroup by developer name. |
| global override [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm)> [getFields](#getfields)() | Returns the core fields for PermissionSetGroup queries. |

### findByName

<div class="apex-member">

```apex
global List<PermissionSetGroup> findByName(Set<String> groupNames)
```

Finds PermissionSetGroups by developer names. In test context, recalculates
groups that are not yet updated.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `groupNames` | [Set](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_set.htm) | A set of unique developer names of the PermissionSetGroup records to retrieve |

**Returns** [PermissionSetGroup](https://developer.salesforce.com/docs/atlas.en-us.object_reference.meta/object_reference/sforce_api_objects_permissionsetgroup.htm) — A list of PermissionSetGroup records that match the specified names

**Example**

```apex
Set<String> names = new Set<String>{'ReadOnly', 'EditAccess'};
List<PermissionSetGroup> groups = new SEL_PermissionSetGroup().findByName(names);
```

</div>

<div class="apex-member">

```apex
global PermissionSetGroup findByName(String developerName)
```

Finds a PermissionSetGroup by developer name. Returns the first match or null.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `developerName` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The unique developer name of the PermissionSetGroup to retrieve |

**Returns** [PermissionSetGroup](https://developer.salesforce.com/docs/atlas.en-us.object_reference.meta/object_reference/sforce_api_objects_permissionsetgroup.htm) — The PermissionSetGroup record that matches the specified name, or null if no match is found

**Example**

```apex
PermissionSetGroup foundGroup = new SEL_PermissionSetGroup().findByName('ReadOnly');
```

</div>

### getFields

<div class="apex-member">

```apex
global override List<SObjectField> getFields()
```

Returns the core fields for PermissionSetGroup queries.

**Returns** [SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm) — List of PermissionSetGroup SObjectField tokens

**Example**

```apex
List<SObjectField> result = instance.getFields();
```

</div>

## Constructors

| Constructor | Description |
|-------------|-------------|
| global [SEL_PermissionSetGroup](#constructors)() | Constructs a PermissionSetGroup selector with the PermissionSetGroup SObjectType. |

### SEL_PermissionSetGroup()

<div class="apex-member">

```apex
global SEL_PermissionSetGroup()
```

Constructs a PermissionSetGroup selector with the PermissionSetGroup SObjectType.

**Example**

```apex
SEL_PermissionSetGroup instance = new SEL_PermissionSetGroup();
```

</div>

