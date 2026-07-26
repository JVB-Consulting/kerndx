---
title: "SEL_UserRole"
type: class
pageClass: reference
description: "Selector for the UserRole SObject. Provides query methods for retrieving user roles and traversing the role hierarchy."
author: "Jason Van Beukering"
group: "Selectors"
date: "October 2024, May 2026"
since: "1.0"
category: apex
---

# SEL_UserRole

**Class** · Group: `Selectors`

<div class="apex-member apex-class">

```apex
global inherited sharing class SEL_UserRole extends SEL_Base
```

**Extends:** [SEL_Base](SEL_Base.md)

Selector for the UserRole SObject. Provides query methods for retrieving user roles and traversing the role hierarchy.

**Example**

```apex
UserRole role = (UserRole)new SEL_UserRole().findById(roleId);
List<UserRole> childRoles = new SEL_UserRole().findAllChildRoles(new Set<Id>{parentRoleId});
```

**See Also:** [SEL_Base](SEL_Base.md)

</div>

---

## Methods

| Method | Description |
|--------|-------------|
| global [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[UserRole](https://developer.salesforce.com/docs/atlas.en-us.object_reference.meta/object_reference/sforce_api_objects_userrole.htm)> [findAllChildRoles](#findallchildroles)([Set](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_set.htm)<[Id](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_id.htm)> parentRoleIds) | Recursively finds all child roles (direct and indirect descendants) for the given parent role Ids. |
| global override [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm)> [getFields](#getfields)() | Returns the core fields for UserRole queries. |

### findAllChildRoles

<div class="apex-member">

```apex
global List<UserRole> findAllChildRoles(Set<Id> parentRoleIds)
```

Recursively finds all child roles (direct and indirect descendants) for
the given parent role Ids. Useful for determining the full role hierarchy beneath one
or more starting roles.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `parentRoleIds` | [Set](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_set.htm) | Set of starting parent UserRole Ids |

**Returns** [UserRole](https://developer.salesforce.com/docs/atlas.en-us.object_reference.meta/object_reference/sforce_api_objects_userrole.htm) — List of all descendant UserRole records (excluding the original parent roles)

**Example**

```apex
List<UserRole> result = instance.findAllChildRoles(recordIds);
```

</div>

### getFields

<div class="apex-member">

```apex
global override List<SObjectField> getFields()
```

Returns the core fields for UserRole queries.

**Returns** [SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm) — List of UserRole SObjectField tokens

**Example**

```apex
List<SObjectField> result = instance.getFields();
```

</div>

## Constructors

| Constructor | Description |
|-------------|-------------|
| global [SEL_UserRole](#constructors)() | Constructs a UserRole selector. |

### SEL_UserRole()

<div class="apex-member">

```apex
global SEL_UserRole()
```

Constructs a UserRole selector.

**Example**

```apex
SEL_UserRole instance = new SEL_UserRole();
```

</div>

