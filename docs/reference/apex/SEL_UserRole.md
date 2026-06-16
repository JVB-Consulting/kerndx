---
title: "SEL_UserRole"
type: class
description: "Selector for the UserRole SObject. Provides query methods for retrieving user roles and traversing the role hierarchy."
author: "Jason Van Beukering"
group: "Selectors"
date: "October 2024, May 2026"
since: "1.0"
category: apex
---

# SEL_UserRole

**Class** · Group: `Selectors`

```apex
global inherited sharing class SEL_UserRole extends SEL_Base
```

**Extends:** [SEL_Base](SEL_Base.md)

Selector for the UserRole SObject. Provides query methods for retrieving user roles and traversing the role hierarchy.

**Since:** 1.0

**Example:**

```apex
UserRole role = (UserRole)new SEL_UserRole().findById(roleId);
List<UserRole> childRoles = new SEL_UserRole().findAllChildRoles(new Set<Id>{parentRoleId});
```

**See Also:** [SEL_Base](SEL_Base.md)

---

## Methods

| Method | Description |
|--------|-------------|
| global [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[UserRole](https://developer.salesforce.com/docs/atlas.en-us.object_reference.meta/object_reference/sforce_api_objects_userrole.htm)> [findAllChildRoles](#findallchildroles)([Set](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_set.htm)<[Id](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_id.htm)> parentRoleIds) | Recursively finds all child roles (direct and indirect descendants) for the given parent role Ids. |
| global override [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm)> [getFields](#getfields)() | Returns the core fields for UserRole queries. |
| global  [SEL_UserRole](#sel_userrole)() | Constructs a UserRole selector. |

---

## Method Details

### SEL_UserRole

```apex
global SEL_UserRole()
```

Constructs a UserRole selector.

**Since:** 1.0

**Example:**

```apex
SEL_UserRole instance = new SEL_UserRole();
```

### findAllChildRoles

```apex
global List<UserRole> findAllChildRoles(Set<Id> parentRoleIds)
```

Recursively finds all child roles (direct and indirect descendants) for
the given parent role Ids. Useful for determining the full role hierarchy beneath one
or more starting roles.

**Parameters:**

- `parentRoleIds` ([Set](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_set.htm)) - Set of starting parent UserRole Ids

**Returns:** [UserRole](https://developer.salesforce.com/docs/atlas.en-us.object_reference.meta/object_reference/sforce_api_objects_userrole.htm) - List of all descendant UserRole records (excluding the original parent roles)

**Since:** 1.0

**Example:**

```apex
List<UserRole> result = instance.findAllChildRoles(recordIds);
```

### getFields

```apex
global override List<SObjectField> getFields()
```

Returns the core fields for UserRole queries.

**Returns:** [SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm) - List of UserRole SObjectField tokens

**Since:** 1.0

**Example:**

```apex
List<SObjectField> result = instance.getFields();
```

