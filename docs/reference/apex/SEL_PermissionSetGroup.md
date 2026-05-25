---
title: "SEL_PermissionSetGroup"
type: class
description: "Selector for the PermissionSetGroup SObject. Provides default field configuration and query methods for PermissionSetGroup records. In test context, automatically recalculates groups that are not yet "
author: "Jason Van Beukering"
group: "Selectors"
date: "February 2026, May 2026"
since: "1.0"
category: apex
---

# SEL_PermissionSetGroup

**Class** · Group: `Selectors`

```apex
global inherited sharing class SEL_PermissionSetGroup extends SEL_Base
```

**Extends:** [SEL_Base](SEL_Base.md)

Selector for the PermissionSetGroup SObject. Provides default field configuration and query methods for PermissionSetGroup records. In test context, automatically recalculates groups that are not yet updated.

**Since:** 1.0

**Example:**

```apex
PermissionSetGroup foundGroup = new SEL_PermissionSetGroup().findByName('ReadOnly');
List<PermissionSetGroup> groups = new SEL_PermissionSetGroup().findByName(new Set<String>{'ReadOnly', 'EditAccess'});
```

**See Also:** [SEL_Base](SEL_Base.md)

---

## Methods

| Method | Description |
|--------|-------------|
| global [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm) [findByName](#findbyname)([Set](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_set.htm)<[String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)> groupNames) | Finds PermissionSetGroups by developer names. |
| global [PermissionSetGroup](https://developer.salesforce.com/docs/atlas.en-us.object_reference.meta/object_reference/sforce_api_objects_permissionsetgroup.htm) [findByName](#findbyname)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) developerName) | Finds a PermissionSetGroup by developer name. |
| global override [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm) [getFields](#getfields)() | Returns the core fields for PermissionSetGroup queries. |
| global [SEL_PermissionSetGroup](#sel_permissionsetgroup)() | Constructs a PermissionSetGroup selector with the PermissionSetGroup SObjectType. |

---

## Method Details

### SEL_PermissionSetGroup

```apex
global SEL_PermissionSetGroup()
```

Constructs a PermissionSetGroup selector with the PermissionSetGroup SObjectType.

**Since:** 1.0

**Example:**

```apex
SEL_PermissionSetGroup instance = new SEL_PermissionSetGroup();
```

### findByName

```apex
global List<PermissionSetGroup> findByName(Set<String> groupNames)
```

Finds PermissionSetGroups by developer names. In test context, recalculates
groups that are not yet updated.

**Parameters:**

- `groupNames` ([Set](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_set.htm)) - A set of unique developer names of the PermissionSetGroup records to retrieve

**Returns:** [PermissionSetGroup](https://developer.salesforce.com/docs/atlas.en-us.object_reference.meta/object_reference/sforce_api_objects_permissionsetgroup.htm) - A list of PermissionSetGroup records that match the specified names

**Since:** 1.0

**Example:**

```apex
Set<String> names = new Set<String>{'ReadOnly', 'EditAccess'};
List<PermissionSetGroup> groups = new SEL_PermissionSetGroup().findByName(names);
```

### findByName

```apex
global PermissionSetGroup findByName(String developerName)
```

Finds a PermissionSetGroup by developer name. Returns the first match or null.

**Parameters:**

- `developerName` ([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)) - The unique developer name of the PermissionSetGroup to retrieve

**Returns:** [PermissionSetGroup](https://developer.salesforce.com/docs/atlas.en-us.object_reference.meta/object_reference/sforce_api_objects_permissionsetgroup.htm) - The PermissionSetGroup record that matches the specified name, or null if no match is found

**Since:** 1.0

**Example:**

```apex
PermissionSetGroup foundGroup = new SEL_PermissionSetGroup().findByName('ReadOnly');
```

### getFields

```apex
global override List<SObjectField> getFields()
```

Returns the core fields for PermissionSetGroup queries.

**Returns:** [SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm) - List of PermissionSetGroup SObjectField tokens

**Since:** 1.0

**Example:**

```apex
List<SObjectField> result = instance.getFields();
```

