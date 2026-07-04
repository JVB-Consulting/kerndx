---
title: "SEL_PermissionSet"
type: class
description: "Selector for the PermissionSet SObject. Provides default field configuration and query methods for PermissionSet records, including namespace-aware lookup."
author: "Jason Van Beukering"
group: "Selectors"
date: "February 2026, May 2026"
since: "1.0"
category: apex
---

# SEL_PermissionSet

**Class** · Group: `Selectors`

```apex
global inherited sharing class SEL_PermissionSet extends SEL_Base
```

**Extends:** [SEL_Base](SEL_Base.md)

Selector for the PermissionSet SObject. Provides default field configuration and query methods for PermissionSet records, including namespace-aware lookup.

**Since:** 1.0

**Example:**

```apex
PermissionSet adminSet = new SEL_PermissionSet().findByName('Administrator');
PermissionSet permissionSet = (PermissionSet)new SEL_PermissionSet().findById(permissionSetId);
```

**See Also:** [SEL_Base](SEL_Base.md)

---

## Methods

| Method | Description |
|--------|-------------|
| global [PermissionSet](https://developer.salesforce.com/docs/atlas.en-us.object_reference.meta/object_reference/sforce_api_objects_permissionset.htm) [findByName](#findbyname)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) name) | Retrieves a PermissionSet record by name, searching both subscriber org (NamespacePrefix = null) and managed package namespace. |
| global override [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm) [getFields](#getfields)() | Returns the core fields for PermissionSet queries. |
| global [SEL_PermissionSet](#sel_permissionset)() | Constructs a PermissionSet selector with the PermissionSet SObjectType. |

---

## Method Details

### SEL_PermissionSet

```apex
global SEL_PermissionSet()
```

Constructs a PermissionSet selector with the PermissionSet SObjectType.

**Since:** 1.0

**Example:**

```apex
SEL_PermissionSet instance = new SEL_PermissionSet();
```

### findByName

```apex
global PermissionSet findByName(String name)
```

Retrieves a PermissionSet record by name, searching both subscriber org (NamespacePrefix = null)
and managed package namespace. Subscriber org version takes precedence.

**Parameters:**

- `name` ([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)) - The API name of the PermissionSet to retrieve (without namespace prefix)

**Returns:** [PermissionSet](https://developer.salesforce.com/docs/atlas.en-us.object_reference.meta/object_reference/sforce_api_objects_permissionset.htm) - The matching PermissionSet, or null if not found

**Since:** 1.0

**Example:**

```apex
PermissionSet result = new SEL_PermissionSet().findByName('ReadOnly');
```

### getFields

```apex
global override List<SObjectField> getFields()
```

Returns the core fields for PermissionSet queries.

**Returns:** [SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm) - List of PermissionSet SObjectField tokens

**Since:** 1.0

**Example:**

```apex
List<SObjectField> result = instance.getFields();
```

