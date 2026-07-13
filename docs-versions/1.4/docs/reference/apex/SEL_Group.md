---
title: "SEL_Group"
type: class
pageClass: reference
description: "Selector for Salesforce Group objects. Provides query methods for group lookup and recursive group membership resolution including role-based groups, role hierarchies, and nested group membership."
author: "Jason Van Beukering"
group: "Selectors"
date: "October 2024, May 2026"
since: "1.0"
category: apex
---

# SEL_Group

**Class** · Group: `Selectors`

<div class="apex-member apex-class">

```apex
global inherited sharing class SEL_Group extends SEL_Base
```

**Extends:** [SEL_Base](SEL_Base.md)

Selector for Salesforce Group objects. Provides query methods for group lookup and recursive group membership resolution including role-based groups, role hierarchies, and nested group membership.

**Example**

```apex
Group foundGroup = new SEL_Group().findByName('Approvers');
Boolean isMember = new SEL_Group().userIsInGroup(userId, 'Approvers');
List<User> members = new SEL_Group().findAllUsers(new Set<Id>{groupId});
```

**See Also:** [SEL_Base](SEL_Base.md)

</div>

---

## Methods

| Method | Description |
|--------|-------------|
| global [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[User](https://developer.salesforce.com/docs/atlas.en-us.object_reference.meta/object_reference/sforce_api_objects_user.htm)> [findAllUsers](#findallusers)([Set](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_set.htm)<[Id](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_id.htm)> parentGroupIds) | Recursively finds all users contained within the specified public groups, including users from embedded roles, role hierarchies, and nested groups. |
| global [Group](https://developer.salesforce.com/docs/atlas.en-us.object_reference.meta/object_reference/sforce_api_objects_group.htm) [findByName](#findbyname)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) groupName) | Finds a Group by its Name field. |
| global override [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm)> [getFields](#getfields)() | Returns the default fields for Group queries. |
| global [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) [userIsInGroup](#userisingroup)([Id](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_id.htm) userId, [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) groupName) | Checks whether a user is a member of a named group. |

### findAllUsers

<div class="apex-member">

```apex
global List<User> findAllUsers(Set<Id> parentGroupIds)
```

Recursively finds all users contained within the specified public groups,
including users from embedded roles, role hierarchies, and nested groups.
This method handles complex group structures by:

- Processing Role and RoleAndSubordinates groups

- Traversing nested group memberships

- Collecting users from role hierarchies

- Avoiding infinite loops through iterative processing

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `parentGroupIds` | [Set](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_set.htm) | Set of Group IDs to analyze for user membership. |

**Returns** [User](https://developer.salesforce.com/docs/atlas.en-us.object_reference.meta/object_reference/sforce_api_objects_user.htm) — List of User records that are members of the specified groups (directly or indirectly).

**Example**

```apex
Set<Id> groupIds = new Set<Id>{ '00G3X000001AbcD' };
List<User> allUsers = new SEL_Group().findAllUsers(groupIds);
```

</div>

### findByName

<div class="apex-member">

```apex
global Group findByName(String groupName)
```

Finds a Group by its Name field.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `groupName` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The Name to search for. |

**Returns** [Group](https://developer.salesforce.com/docs/atlas.en-us.object_reference.meta/object_reference/sforce_api_objects_group.htm) — The found Group, or null if not found.

**Example**

```apex
Group result = instance.findByName('myName');
```

</div>

### getFields

<div class="apex-member">

```apex
global override List<SObjectField> getFields()
```

Returns the default fields for Group queries.

**Returns** [SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm) — List of SObjectField tokens to include in queries.

**Example**

```apex
List<SObjectField> result = instance.getFields();
```

</div>

### userIsInGroup

<div class="apex-member">

```apex
global Boolean userIsInGroup(Id userId, String groupName)
```

Checks whether a user is a member of a named group.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `userId` | [Id](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_id.htm) | The User Id to check. |
| `groupName` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The Name of the group to check membership in. |

**Returns** [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) — True if the user is a member of the group.

**Example**

```apex
Boolean result = instance.userIsInGroup(recordId, 'myName');
```

</div>

## Constructors

| Constructor | Description |
|-------------|-------------|
| global [SEL_Group](#constructors)() | Constructs a new SEL_Group selector instance. |

### SEL_Group()

<div class="apex-member">

```apex
global SEL_Group()
```

Constructs a new SEL_Group selector instance.

**Example**

```apex
SEL_Group instance = new SEL_Group();
```

</div>

