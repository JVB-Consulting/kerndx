---
title: "SEL_User"
type: class
pageClass: reference
description: "Selector for the User SObject. Provides default field configuration and query methods for User records, including retrieval by ID, role, profile, or other fields, as well as generating aliases and com"
author: "Jason Van Beukering"
group: "Selectors"
date: "February 2026, June 2026"
since: "1.0"
category: apex
---

# SEL_User

**Class** · Group: `Selectors`

<div class="apex-member apex-class">

```apex
global virtual inherited sharing class SEL_User extends SEL_Base
```

**Extends:** [SEL_Base](SEL_Base.md)

Selector for the User SObject. Provides default field configuration and query methods for User records, including retrieval by ID, role, profile, or other fields, as well as generating aliases and community nicknames.

**Example**

```apex
User currentUser = new SEL_User().getCurrentUser();
User foundUser = new SEL_User().findByUsername('admin@example.com');
List<User> admins = new SEL_User().findActiveByProfileName('System Administrator');
List<User> roleUsers = new SEL_User().findByRoleId(roleIds);
```

**See Also:** [SEL_Base](SEL_Base.md), [User](https://developer.salesforce.com/docs/atlas.en-us.object_reference.meta/object_reference/sforce_api_objects_user.htm)

</div>

---

## Methods

| Method | Description |
|--------|-------------|
| global [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[User](https://developer.salesforce.com/docs/atlas.en-us.object_reference.meta/object_reference/sforce_api_objects_user.htm)> [findActiveByProfileAndPermissionSetName](#findactivebyprofileandpermissionsetname)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) profileName, [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) permissionSetOrGroupName) | Retrieves active users with the specified profile and permission set or group, using default fields. |
| global [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[User](https://developer.salesforce.com/docs/atlas.en-us.object_reference.meta/object_reference/sforce_api_objects_user.htm)> [findActiveByProfileName](#findactivebyprofilename)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) profileName) | Retrieves active users with the specified profile name, using default fields. |
| global [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[User](https://developer.salesforce.com/docs/atlas.en-us.object_reference.meta/object_reference/sforce_api_objects_user.htm)> [findActiveUsers](#findactiveusers)([Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) numberOfUsers) | Retrieves a specified number of active users, using default User fields. |
| global [User](https://developer.salesforce.com/docs/atlas.en-us.object_reference.meta/object_reference/sforce_api_objects_user.htm) [findByCompanyName](#findbycompanyname)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) companyName) | Retrieves a user by their company name, using default User fields. |
| global [User](https://developer.salesforce.com/docs/atlas.en-us.object_reference.meta/object_reference/sforce_api_objects_user.htm) [findByFederationId](#findbyfederationid)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) federationId) | Retrieves a user by their federation ID, using default User fields. |
| global [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[User](https://developer.salesforce.com/docs/atlas.en-us.object_reference.meta/object_reference/sforce_api_objects_user.htm)> [findByProfileName](#findbyprofilename)([Set](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_set.htm)<[String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)> profileNames) | Retrieves a list of users by their profile names, using default User fields. |
| global [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[User](https://developer.salesforce.com/docs/atlas.en-us.object_reference.meta/object_reference/sforce_api_objects_user.htm)> [findByRoleId](#findbyroleid)([Set](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_set.htm)<[Id](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_id.htm)> roleIds) | Retrieves a list of users based on a set of role IDs, using default User fields. |
| global [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[User](https://developer.salesforce.com/docs/atlas.en-us.object_reference.meta/object_reference/sforce_api_objects_user.htm)> [findByUsername](#findbyusername)([Set](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_set.htm)<[String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)> userNames) | Retrieves a list of users by their usernames, using default User fields. |
| global [User](https://developer.salesforce.com/docs/atlas.en-us.object_reference.meta/object_reference/sforce_api_objects_user.htm) [findByUsername](#findbyusername)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) username) | Finds a user record by username. |
| global [Id](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_id.htm) [findProfileIdByUserId](#findprofileidbyuserid)([Id](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_id.htm) userId) | Retrieves the Profile ID for a specific user. |
| global [User](https://developer.salesforce.com/docs/atlas.en-us.object_reference.meta/object_reference/sforce_api_objects_user.htm) [findRandomActiveByProfileAndPermissionSetName](#findrandomactivebyprofileandpermissionsetname)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) profileName, [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) permissionSetOrGroupName) | Retrieves a random active user with the specified profile and permission set or group, using default fields. |
| global [User](https://developer.salesforce.com/docs/atlas.en-us.object_reference.meta/object_reference/sforce_api_objects_user.htm) [findRandomActiveByProfileName](#findrandomactivebyprofilename)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) profileName) | Retrieves a random active user with the specified profile name, using default fields. |
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [generateAlias](#generatealias)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) fullName) | Generates an alias from a user's full name, adhering to the User.Alias field length. |
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [generateUniqueCommunityNickname](#generateuniquecommunitynickname)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) fullName) | Generates a unique community nickname from a user's full name, checking for existing nicknames. |
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [generateUniqueCommunityNickname](#generateuniquecommunitynickname)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) fullName, [Set](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_set.htm)<[String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)> existingNicknames) | Generates a unique community nickname from a user's full name, ensuring uniqueness against existing nicknames. |
| global [User](https://developer.salesforce.com/docs/atlas.en-us.object_reference.meta/object_reference/sforce_api_objects_user.htm) [getCurrentUser](#getcurrentuser)() | Retrieves the current user's details using default fields. |
| global virtual override [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)> [getFieldPaths](#getfieldpaths)() | Returns relationship field paths for User queries. |
| global virtual override [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm)> [getFields](#getfields)() | Returns the core SObjectField tokens for User queries. |
| global [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) [isCurrentUserSystemAdmin](#iscurrentusersystemadmin)() | Checks if the current user has the System Administrator profile. |
| global  [SEL_User](#sel_user)() | Constructs a User selector with the User SObjectType. |

---

## Method Details

### SEL_User

<div class="apex-member">

```apex
global SEL_User()
```

Constructs a User selector with the User SObjectType.

**Example**

```apex
SEL_User instance = new SEL_User();
```

</div>

### findActiveByProfileAndPermissionSetName

<div class="apex-member">

```apex
global List<User> findActiveByProfileAndPermissionSetName(String profileName, String permissionSetOrGroupName)
```

Retrieves active users with the specified profile and permission set or group, using default fields.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `profileName` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The name of the profile to filter by. |
| `permissionSetOrGroupName` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The name of the permission set or group to filter by. |

**Returns** [User](https://developer.salesforce.com/docs/atlas.en-us.object_reference.meta/object_reference/sforce_api_objects_user.htm) — A list of active User records matching both criteria, or an empty list if none found.

**Example**

```apex
List<User> hrAdmins = new SEL_User().findActiveByProfileAndPermissionSetName('HR Admin', 'HR_Permissions');
```

</div>

### findActiveByProfileName

<div class="apex-member">

```apex
global List<User> findActiveByProfileName(String profileName)
```

Retrieves active users with the specified profile name, using default fields.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `profileName` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The name of the profile to filter by. |

**Returns** [User](https://developer.salesforce.com/docs/atlas.en-us.object_reference.meta/object_reference/sforce_api_objects_user.htm) — A list of active User records matching the profile, or an empty list if none found.

**Example**

```apex
List<User> admins = new SEL_User().findActiveByProfileName('System Administrator');
```

</div>

### findActiveUsers

<div class="apex-member">

```apex
global List<User> findActiveUsers(Integer numberOfUsers)
```

Retrieves a specified number of active users, using default User fields.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `numberOfUsers` | [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) | The maximum number of users to return. |

**Returns** [User](https://developer.salesforce.com/docs/atlas.en-us.object_reference.meta/object_reference/sforce_api_objects_user.htm) — A list of active User records, up to the specified number, or an empty list if none found.

**Example**

```apex
List<User> activeUsers = new SEL_User().findActiveUsers(5);
```

</div>

### findByCompanyName

<div class="apex-member">

```apex
global User findByCompanyName(String companyName)
```

Retrieves a user by their company name, using default User fields.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `companyName` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The company name to query. |

**Returns** [User](https://developer.salesforce.com/docs/atlas.en-us.object_reference.meta/object_reference/sforce_api_objects_user.htm) — A User record matching the company name, or null if not found.

**Example**

```apex
User testUser = new SEL_User().findByCompanyName('my-test-user-identifier');
```

</div>

### findByFederationId

<div class="apex-member">

```apex
global User findByFederationId(String federationId)
```

Retrieves a user by their federation ID, using default User fields.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `federationId` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The federation ID to query. |

**Returns** [User](https://developer.salesforce.com/docs/atlas.en-us.object_reference.meta/object_reference/sforce_api_objects_user.htm) — A User record matching the federation ID, or null if not found.

**Example**

```apex
User user = new SEL_User().findByFederationId('fed123456');
```

</div>

### findByProfileName

<div class="apex-member">

```apex
global List<User> findByProfileName(Set<String> profileNames)
```

Retrieves a list of users by their profile names, using default User fields.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `profileNames` | [Set](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_set.htm) | The set of profile names to query. |

**Returns** [User](https://developer.salesforce.com/docs/atlas.en-us.object_reference.meta/object_reference/sforce_api_objects_user.htm) — A list of User records matching the profile names, or an empty list if none found.

**Example**

```apex
Set<String> profileNames = new Set<String>{'System Administrator', 'Standard User'};
List<User> users = new SEL_User().findByProfileName(profileNames);
```

</div>

### findByRoleId

<div class="apex-member">

```apex
global List<User> findByRoleId(Set<Id> roleIds)
```

Retrieves a list of users based on a set of role IDs, using default User fields.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `roleIds` | [Set](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_set.htm) | The set of role IDs to query. |

**Returns** [User](https://developer.salesforce.com/docs/atlas.en-us.object_reference.meta/object_reference/sforce_api_objects_user.htm) — A list of User records assigned to the specified roles, or an empty list if none found.

**Example**

```apex
Set<Id> roleIds = new Set<Id>{'00E3X00000R1AbC'};
List<User> users = new SEL_User().findByRoleId(roleIds);
```

</div>

### findByUsername

<div class="apex-member">

```apex
global List<User> findByUsername(Set<String> userNames)
```

Retrieves a list of users by their usernames, using default User fields.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `userNames` | [Set](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_set.htm) | The set of usernames to query. |

**Returns** [User](https://developer.salesforce.com/docs/atlas.en-us.object_reference.meta/object_reference/sforce_api_objects_user.htm) — A list of User records matching the usernames, or an empty list if none found.

**Example**

```apex
Set<String> userNames = new Set<String>{'test.user@example.com'};
List<User> users = new SEL_User().findByUsername(userNames);
```

</div>

<div class="apex-member">

```apex
global User findByUsername(String username)
```

Finds a user record by username.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `username` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The username (email format) to search for |

**Returns** [User](https://developer.salesforce.com/docs/atlas.en-us.object_reference.meta/object_reference/sforce_api_objects_user.htm) — The User record with default fields, or null if not found

**Example**

```apex
User foundUser = new SEL_User().findByUsername('test.user@example.com');
```

</div>

### findProfileIdByUserId

<div class="apex-member">

```apex
global Id findProfileIdByUserId(Id userId)
```

Retrieves the Profile ID for a specific user.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `userId` | [Id](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_id.htm) | The user ID to look up |

**Returns** [Id](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_id.htm) — The user's Profile ID, or null if user not found

**Example**

```apex
Id profileId = new SEL_User().findProfileIdByUserId(someUserId);
```

</div>

### findRandomActiveByProfileAndPermissionSetName

<div class="apex-member">

```apex
global User findRandomActiveByProfileAndPermissionSetName(String profileName, String permissionSetOrGroupName)
```

Retrieves a random active user with the specified profile and permission set or group, using default fields.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `profileName` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The name of the profile to filter by. |
| `permissionSetOrGroupName` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The name of the permission set or group to filter by. |

**Returns** [User](https://developer.salesforce.com/docs/atlas.en-us.object_reference.meta/object_reference/sforce_api_objects_user.htm) — A random active User record matching both criteria, or null if none found.

**Example**

```apex
User randomHrAdmin = new SEL_User().findRandomActiveByProfileAndPermissionSetName('HR Admin', 'HR_Permissions');
```

</div>

### findRandomActiveByProfileName

<div class="apex-member">

```apex
global User findRandomActiveByProfileName(String profileName)
```

Retrieves a random active user with the specified profile name, using default fields.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `profileName` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The name of the profile to filter by. |

**Returns** [User](https://developer.salesforce.com/docs/atlas.en-us.object_reference.meta/object_reference/sforce_api_objects_user.htm) — A random active User record matching the profile, or null if none found.

**Example**

```apex
User randomAdmin = new SEL_User().findRandomActiveByProfileName('System Administrator');
```

</div>

### generateAlias

<div class="apex-member">

```apex
global String generateAlias(String fullName)
```

Generates an alias from a user's full name, adhering to the User.Alias field length.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `fullName` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The user's full name (including first, middle, last names, prefixes, or suffixes). |

**Returns** [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) — A generated alias string, or an empty string if the input is blank.

**Example**

```apex
String alias = SEL_User.generateAlias('Jason van Thor Bob');
```

</div>

### generateUniqueCommunityNickname

<div class="apex-member">

```apex
global String generateUniqueCommunityNickname(String fullName)
```

Generates a unique community nickname from a user's full name, checking for existing nicknames.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `fullName` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The user's full name. |

**Returns** [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) — A unique community nickname string, or a random name if the input is blank.

**Example**

```apex
String nickname = new SEL_User().generateUniqueCommunityNickname('Billy Bob Thornton');
```

</div>

<div class="apex-member">

```apex
global String generateUniqueCommunityNickname(String fullName, Set<String> existingNicknames)
```

Generates a unique community nickname from a user's full name, ensuring uniqueness against existing nicknames.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `fullName` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The user's full name. |
| `existingNicknames` | [Set](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_set.htm) | A set of existing nicknames to check against, or null to ignore. |

**Returns** [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) — A unique community nickname string, or a random name if the input is blank.

**Example**

```apex
Set<String> existing = new Set<String>{'BillyBobThornton'};
String nickname = SEL_User.generateUniqueCommunityNickname('Billy Bob Thornton', existing);
```

</div>

### getCurrentUser

<div class="apex-member">

```apex
global User getCurrentUser()
```

Retrieves the current user's details using default fields.
Caches the result so subsequent calls within the same transaction do not re-query.

**Returns** [User](https://developer.salesforce.com/docs/atlas.en-us.object_reference.meta/object_reference/sforce_api_objects_user.htm) — The User record for the current user, or null if not found.

**Example**

```apex
User currentUser = new SEL_User().getCurrentUser();
```

</div>

### getFieldPaths

<div class="apex-member">

```apex
global virtual override List<String> getFieldPaths()
```

Returns relationship field paths for User queries.

**Returns** [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) — List of relationship field path strings

**Example**

```apex
SEL_User selector = new SEL_User();
List<String> paths = selector.getFieldPaths();
System.debug('Relationship paths: ' + paths); // ['Profile.Name']
```

</div>

### getFields

<div class="apex-member">

```apex
global virtual override List<SObjectField> getFields()
```

Returns the core SObjectField tokens for User queries.

**Returns** [SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm) — List of User SObjectField tokens

**Example**

```apex
SEL_User selector = new SEL_User();
List<SObjectField> userFields = selector.getFields();
System.debug('User selector has ' + userFields.size() + ' core fields');
```

</div>

### isCurrentUserSystemAdmin

<div class="apex-member">

```apex
global Boolean isCurrentUserSystemAdmin()
```

Checks if the current user has the System Administrator profile.

**Returns** [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) — True if the current user is a System Administrator, false otherwise.

**Example**

```apex
if(new SEL_User().isCurrentUserSystemAdmin())
{
    // Current user is a System Administrator
}
```

</div>

