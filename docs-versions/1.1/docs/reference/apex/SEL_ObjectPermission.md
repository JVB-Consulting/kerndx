---
title: "SEL_ObjectPermission"
type: class
description: "Provides methods for querying and evaluating user access permissions on Salesforce objects. Simplifies permission checks by exposing operations such as read or create access for single or multiple use"
author: "Jason Van Beukering"
group: "Selectors"
date: "February 2026, June 2026"
since: "1.0"
category: apex
---

# SEL_ObjectPermission

**Class** · Group: `Selectors`

```apex
global inherited sharing class SEL_ObjectPermission
```

Provides methods for querying and evaluating user access permissions on Salesforce objects. Simplifies permission checks by exposing operations such as read or create access for single or multiple users via PermissionSetAssignment with semi-join into ObjectPermissions.

**Since:** 1.0

**Example:**

```apex
Boolean canRead = SEL_ObjectPermission.hasReadAccess(userId, Account.SObjectType);
Boolean canCreate = SEL_ObjectPermission.hasCreateAccess(userId, Case.SObjectType);
Set<Id> readers = SEL_ObjectPermission.hasReadAccess(userIds, Account.SObjectType);
```

---

## Properties

| Property | Description |
|----------|-------------|
| global enum [ObjectPermissionType](SEL_ObjectPermission.ObjectPermissionType.md) | A Permission that a User might have on a SObjectType. |

## Methods

| Method | Description |
|--------|-------------|
| global static [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) [hasAccess](#hasaccess)([SEL_ObjectPermission.ObjectPermissionType](SEL_ObjectPermission.ObjectPermissionType.md) objectAccessLevel, [Id](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_id.htm) userId, [SObjectType](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectType.htm) objectType) | Checks if a specific user has the required access level for a particular SObjectType. |
| global static [Set](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_set.htm) [hasAccess](#hasaccess)([SEL_ObjectPermission.ObjectPermissionType](SEL_ObjectPermission.ObjectPermissionType.md) objectAccessLevel, [Set](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_set.htm)<[Id](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_id.htm)> userIds, [SObjectType](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectType.htm) objectType) | Verifies if multiple users have a specified access level for a given object type. |
| global static [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) [hasCreateAccess](#hascreateaccess)([Id](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_id.htm) userId, [SObjectType](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectType.htm) objectType) | Checks if a specified user has create access to a particular object type. |
| global static [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) [hasReadAccess](#hasreadaccess)([Id](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_id.htm) userId, [SObjectType](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectType.htm) objectType) | Determines if a specified user has read access to a particular Salesforce object type. |
| global static [Set](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_set.htm) [hasReadAccess](#hasreadaccess)([Set](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_set.htm)<[Id](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_id.htm)> userIds, [SObjectType](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectType.htm) objectType) | Checks if a set of specified users has read access to a given object type. |

---

## Method Details

### hasAccess

```apex
global static Boolean hasAccess(SEL_ObjectPermission.ObjectPermissionType objectAccessLevel, Id userId, SObjectType objectType)
```

Checks if a specific user has the required access level for a particular SObjectType.

**Parameters:**

- `objectAccessLevel` ([SEL_ObjectPermission.ObjectPermissionType](SEL_ObjectPermission.ObjectPermissionType.md)) - The ObjectPermissionType (e.g., CREATE, READ) to check for
- `userId` ([Id](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_id.htm)) - The Id of the user to check access for
- `objectType` ([SObjectType](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectType.htm)) - The SObjectType of the object for which access is being checked

**Returns:** [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) - True if the user has the specified access level; otherwise, false

**Since:** 1.0

**Example:**

```apex
Boolean result = SEL_ObjectPermission.hasAccess(new ObjectPermissionType(), recordId, Account.SObjectType);
```

### hasAccess

```apex
global static Set<Id> hasAccess(SEL_ObjectPermission.ObjectPermissionType objectAccessLevel, Set<Id> userIds, SObjectType objectType)
```

Verifies if multiple users have a specified access level for a given object type.

**Parameters:**

- `objectAccessLevel` ([SEL_ObjectPermission.ObjectPermissionType](SEL_ObjectPermission.ObjectPermissionType.md)) - The ObjectPermissionType (e.g., MODIFY_ALL, VIEW_ALL) to check for
- `userIds` ([Set](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_set.htm)) - A Set of User Ids to check access for
- `objectType` ([Id](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_id.htm)) - The SObjectType of the object for which access is being checked

**Returns:** [Id](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_id.htm) - The Ids of users that have the required access level

**Since:** 1.0

**Example:**

```apex
Set<Id> result = SEL_ObjectPermission.hasAccess(new ObjectPermissionType(), recordIds, Account.SObjectType);
```

### hasCreateAccess

```apex
global static Boolean hasCreateAccess(Id userId, SObjectType objectType)
```

Checks if a specified user has create access to a particular object type.

**Parameters:**

- `userId` ([Id](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_id.htm)) - The Id of the User to check for create access
- `objectType` ([SObjectType](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectType.htm)) - The SObjectType of the object to check access for

**Returns:** [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) - True if the user has create access; otherwise, false

**Since:** 1.0

**Example:**

```apex
Boolean result = SEL_ObjectPermission.hasCreateAccess(recordId, Account.SObjectType);
```

### hasReadAccess

```apex
global static Boolean hasReadAccess(Id userId, SObjectType objectType)
```

Determines if a specified user has read access to a particular Salesforce object type.

**Parameters:**

- `userId` ([Id](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_id.htm)) - The Id of the User to check for read access
- `objectType` ([SObjectType](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectType.htm)) - The SObjectType of the object to check access for

**Returns:** [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) - True if the user has read access to the object; otherwise, false

**Since:** 1.0

**Example:**

```apex
Boolean result = SEL_ObjectPermission.hasReadAccess(recordId, Account.SObjectType);
```

### hasReadAccess

```apex
global static Set<Id> hasReadAccess(Set<Id> userIds, SObjectType objectType)
```

Checks if a set of specified users has read access to a given object type.

**Parameters:**

- `userIds` ([Set](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_set.htm)) - A Set of User Ids to check for read access
- `objectType` ([Id](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_id.htm)) - The SObjectType of the object to check access for

**Returns:** [Id](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_id.htm) - The Ids of users that have read access to the object type

**Since:** 1.0

**Example:**

```apex
Set<Id> result = SEL_ObjectPermission.hasReadAccess(recordIds, Account.SObjectType);
```

