---
title: "TST_Factory"
type: class
pageClass: reference
description: "Factory class that builds test data for your unit tests. It has helpers for: users (new or inserted, with or without a permission set), permission set assignments, feature flag records, API call recor"
author: "Jason Van Beukering"
group: "Testing"
date: "February 2026, October 2026"
since: "1.0"
category: apex
---

# TST_Factory

**Class** · Group: `Testing`

<div class="apex-member apex-class">

```apex
global without sharing class TST_Factory
```

Factory class that builds test data for your unit tests. It has helpers for: users (new or inserted, with or without a permission set), permission set assignments, feature flag records, API call records (inbound and outbound), API setting records (inbound and outbound), and content versions (files).

**Example**

```apex
User testUser = TST_Factory.insertUser('Standard User');
```

</div>

---

## Methods

| Method | Description |
|--------|-------------|
| global static void [createPermissionSetAssignments](#createpermissionsetassignments)([List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[User](https://developer.salesforce.com/docs/atlas.en-us.object_reference.meta/object_reference/sforce_api_objects_user.htm)> users, [Id](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_id.htm) permissionSetOrGroupId) | Creates PermissionSetAssignment records for a list of users and a permission set Id. |
| global static void [createPermissionSetAssignments](#createpermissionsetassignments)([List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[User](https://developer.salesforce.com/docs/atlas.en-us.object_reference.meta/object_reference/sforce_api_objects_user.htm)> users, [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) permissionSetOrGroupName) | Creates PermissionSetAssignment records for a list of users and a permission set. |
| global static [User](https://developer.salesforce.com/docs/atlas.en-us.object_reference.meta/object_reference/sforce_api_objects_user.htm) [insertUser](#insertuser)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) profileName) | Creates and saves a single User record with the specified profile, inside the factory's own guard, ready for System.runAs. |
| global static [User](https://developer.salesforce.com/docs/atlas.en-us.object_reference.meta/object_reference/sforce_api_objects_user.htm) [insertUser](#insertuser)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) profileName, [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) companyName) | Creates and saves a User record with a custom company name, inside the factory's own guard. |
| global static [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[User](https://developer.salesforce.com/docs/atlas.en-us.object_reference.meta/object_reference/sforce_api_objects_user.htm)> [insertUsers](#insertusers)([List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[User](https://developer.salesforce.com/docs/atlas.en-us.object_reference.meta/object_reference/sforce_api_objects_user.htm)> users) | Saves the given User records inside the factory's own guard, so a test can save ordinary records before or after this call in the same transaction without a System.runAs block of its own. |
| global static [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[User](https://developer.salesforce.com/docs/atlas.en-us.object_reference.meta/object_reference/sforce_api_objects_user.htm)> [insertUsers](#insertusers)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) profileName, [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) numberOfUsers) | Creates and saves a list of User records with the specified profile, inside the factory's own guard. |
| global static [ApiCall__c](../objects/ApiCall__c.md) [newApiCall](#newapicall)() | Creates an uncommitted ApiCall__c record for a web service call. |
| global static [ApiCall__c](../objects/ApiCall__c.md) [newApiCall](#newapicall)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) serviceName) | Creates an uncommitted ApiCall__c record with a specified service name. |
| global static [ContentVersion](https://developer.salesforce.com/docs/atlas.en-us.object_reference.meta/object_reference/sforce_api_objects_contentversion.htm) [newContentVersion](#newcontentversion)([Id](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_id.htm) linkToObjectId, [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) fileName, [Blob](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_blob.htm) body) | Creates an uncommitted ContentVersion record from file data. |
| global static [FeatureFlag__mdt](../metadata/FeatureFlag__mdt.md) [newFeatureFlag](#newfeatureflag)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) flagName) | Activates a feature flag for testing by injecting it into the selector cache. |
| global static [ApiCall__c](../objects/ApiCall__c.md) [newInboundApiCall](#newinboundapicall)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) serviceName) | Creates an uncommitted ApiCall__c record for an inbound web service call. |
| global static [ApiSetting__mdt](../metadata/ApiSetting__mdt.md) [newInboundApiSetting](#newinboundapisetting)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) className, [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) endpointPath) | Creates a mock inbound ApiSetting__mdt record via TST_Mock for test routing. |
| global static [ApiSetting__mdt](../metadata/ApiSetting__mdt.md) [newInboundApiSetting](#newinboundapisetting)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) className, [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) endpointPath, [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) priority) | Creates a mock inbound ApiSetting__mdt record with a custom priority, registered with TST_Mock for query interception. |
| global static [ApiSetting__mdt](../metadata/ApiSetting__mdt.md) [newInboundApiSetting](#newinboundapisetting)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) className, [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) endpointPath, [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) priority, [Map](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_map.htm)<[SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm), [Object](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_System_Object.htm)> overrides) | Creates a mock inbound ApiSetting__mdt record with a custom priority and additional field overrides, registered with TST_Mock for query interception. |
| global static [ApiCall__c](../objects/ApiCall__c.md) [newOutboundApiCall](#newoutboundapicall)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) serviceName) | Creates an uncommitted ApiCall__c record for an outbound web service call. |
| global static [ApiCall__c](../objects/ApiCall__c.md) [newOutboundApiCall](#newoutboundapicall)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) serviceName, [Id](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_id.htm) recordId) | Creates an uncommitted ApiCall__c record for an outbound web service call with a triggering object. |
| global static [ApiCall__c](../objects/ApiCall__c.md) [newOutboundApiCall](#newoutboundapicall)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) serviceName, [Id](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_id.htm) recordId, [Map](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_map.htm)<[String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm), [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)> requestParameters) | Creates an uncommitted ApiCall__c record for an outbound web service call with parameters. |
| global static [ApiCall__c](../objects/ApiCall__c.md) [newOutboundApiCall](#newoutboundapicall)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) serviceName, [Id](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_id.htm) recordId, [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) parameterName, [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) parameterValue) | Creates an uncommitted ApiCall__c record for an outbound web service call with a single parameter. |
| global static [ApiSetting__mdt](../metadata/ApiSetting__mdt.md) [newOutboundApiSetting](#newoutboundapisetting)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) className, [Map](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_map.htm)<[SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm), [Object](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_System_Object.htm)> overrides) | Creates a mock outbound ApiSetting__mdt record via TST_Mock for query interception. |
| global static [User](https://developer.salesforce.com/docs/atlas.en-us.object_reference.meta/object_reference/sforce_api_objects_user.htm) [newUser](#newuser)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) profileName) | Creates a single uncommitted User record with the specified profile. |
| global static [User](https://developer.salesforce.com/docs/atlas.en-us.object_reference.meta/object_reference/sforce_api_objects_user.htm) [newUser](#newuser)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) profileName, [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) companyName) | Creates an uncommitted User record with a custom company name. |
| global static [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[User](https://developer.salesforce.com/docs/atlas.en-us.object_reference.meta/object_reference/sforce_api_objects_user.htm)> [newUsers](#newusers)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) profileName, [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) numberOfUsers) | Creates a list of uncommitted User records with the specified profile. |
| global static [User](https://developer.salesforce.com/docs/atlas.en-us.object_reference.meta/object_reference/sforce_api_objects_user.htm) [newUserWithPermissionSet](#newuserwithpermissionset)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) profileName, [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) companyName, [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) permissionSetName) | Creates and inserts a User with the specified profile + company name, then assigns the named permission set (or permission set group). |

### createPermissionSetAssignments

<div class="apex-member">

```apex
global static void createPermissionSetAssignments(List<User> users, Id permissionSetOrGroupId)
```

Creates PermissionSetAssignment records for a list of users and a permission set Id. The assignments
are saved in one statement, inside the factory's own guard while a test runs, so ordinary records a test saves before
or after this call in the same transaction do not collide with them.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `users` | [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm) | The list of users to assign the permission set to. |
| `permissionSetOrGroupId` | [User](https://developer.salesforce.com/docs/atlas.en-us.object_reference.meta/object_reference/sforce_api_objects_user.htm) | The Id of the permission set. |

**Example**

```apex
List<User> users = TST_Factory.insertUsers('Standard User', 2);
PermissionSet permissionSet = new SEL_PermissionSet().findByName('CustomPermissionSet');
TST_Factory.createPermissionSetAssignments(users, permissionSet.Id);
```

</div>

<div class="apex-member">

```apex
global static void createPermissionSetAssignments(List<User> users, String permissionSetOrGroupName)
```

Creates PermissionSetAssignment records for a list of users and a permission set. The assignments
are saved in one statement, inside the factory's own guard while a test runs, so ordinary records a test saves before
or after this call in the same transaction do not collide with them.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `users` | [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm) | The list of users to assign the permission set to. |
| `permissionSetOrGroupName` | [User](https://developer.salesforce.com/docs/atlas.en-us.object_reference.meta/object_reference/sforce_api_objects_user.htm) | The name of the permission set. |

**Throws**

| Exception | Description |
|-----------|-------------|
| [AssertException](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_classes_exception_methods.htm) | If no permission set is found for the specified name. |

**Example**

```apex
List<User> users = TST_Factory.insertUsers('Standard User', 2);
TST_Factory.createPermissionSetAssignments(users, 'CustomPermissionSet');
```

</div>

### insertUser

<div class="apex-member">

```apex
global static User insertUser(String profileName)
```

Creates and saves a single User record with the specified profile, inside the factory's own guard,
ready for System.runAs.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `profileName` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The name of the profile to assign to the user. |

**Returns** [User](https://developer.salesforce.com/docs/atlas.en-us.object_reference.meta/object_reference/sforce_api_objects_user.htm) — A saved User record.

**Throws**

| Exception | Description |
|-----------|-------------|
| [DmlException](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_classes_exception_methods.htm) | If the user cannot be saved, for example when no licence seat is free for its profile's licence. |

**Example**

```apex
User testUser = TST_Factory.insertUser('Standard User');
System.runAs(testUser)
{
    // test body
}
```

</div>

<div class="apex-member">

```apex
global static User insertUser(String profileName, String companyName)
```

Creates and saves a User record with a custom company name, inside the factory's own guard. The
company name can be used as a unique identifier to later retrieve this specific user.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `profileName` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The Profile name to assign to the user. |
| `companyName` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | A unique company name for this user. |

**Returns** [User](https://developer.salesforce.com/docs/atlas.en-us.object_reference.meta/object_reference/sforce_api_objects_user.htm) — A saved User record with the specified company name.

**Throws**

| Exception | Description |
|-----------|-------------|
| [DmlException](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_classes_exception_methods.htm) | If the user cannot be saved, for example when no licence seat is free for its profile's licence. |

**Example**

```apex
@TestSetup
private static void setupTestData()
{
    TST_Factory.insertUser('Standard User', 'my-test-user');
}
private static User getTestUser()
{
    return new SEL_User().findByCompanyName('my-test-user');
}
```

</div>

### insertUsers

<div class="apex-member">

```apex
global static List<User> insertUsers(List<User> users)
```

Saves the given User records inside the factory's own guard, so a test can save ordinary records
before or after this call in the same transaction without a System.runAs block of its own. Build the users with
newUser or newUsers, set any field your org's User rules need (a role, a required custom field), then hand them
here. Each user needs a free licence seat for its profile's licence; the platform's own error is thrown when there
is none.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `users` | [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm) | The unsaved User records to save. |

**Returns** [User](https://developer.salesforce.com/docs/atlas.en-us.object_reference.meta/object_reference/sforce_api_objects_user.htm) — The same records, saved, with Ids.

**Throws**

| Exception | Description |
|-----------|-------------|
| [DmlException](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_classes_exception_methods.htm) | If a user cannot be saved, for example when no licence seat is free for its profile's licence. |

**Example**

```apex
User manager = TST_Factory.newUser('Standard User');
manager.Title = 'Regional Manager';
TST_Factory.insertUsers(new List<User> {manager});
```

</div>

<div class="apex-member">

```apex
global static List<User> insertUsers(String profileName, Integer numberOfUsers)
```

Creates and saves a list of User records with the specified profile, inside the factory's own guard.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `profileName` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The name of the profile to assign to the users. |
| `numberOfUsers` | [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) | The number of users to create and save. |

**Returns** [User](https://developer.salesforce.com/docs/atlas.en-us.object_reference.meta/object_reference/sforce_api_objects_user.htm) — A list of saved User records.

**Throws**

| Exception | Description |
|-----------|-------------|
| [DmlException](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_classes_exception_methods.htm) | If a user cannot be saved, for example when no licence seat is free for its profile's licence. |

**Example**

```apex
List<User> users = TST_Factory.insertUsers('Standard User', 3);
```

</div>

### newApiCall

<div class="apex-member">

```apex
global static ApiCall__c newApiCall()
```

Creates an uncommitted ApiCall__c record for a web service call.

**Returns** [ApiCall__c](../objects/ApiCall__c.md) — An uncommitted ApiCall__c record.

**Example**

```apex
ApiCall__c apiCall = TST_Factory.newApiCall();
insert apiCall;
Assert.isNotNull(apiCall.Id, 'Expected the call record to be saved');
```

</div>

<div class="apex-member">

```apex
global static ApiCall__c newApiCall(String serviceName)
```

Creates an uncommitted ApiCall__c record with a specified service name.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `serviceName` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The name of the web service class. |

**Returns** [ApiCall__c](../objects/ApiCall__c.md) — An uncommitted ApiCall__c record.

**Example**

```apex
ApiCall__c apiCall = TST_Factory.newApiCall('MyService');
insert apiCall;
Assert.areEqual('MyService', apiCall.ServiceName__c, 'Expected the given service name');
```

</div>

### newContentVersion

<div class="apex-member">

```apex
global static ContentVersion newContentVersion(Id linkToObjectId, String fileName, Blob body)
```

Creates an uncommitted ContentVersion record from file data.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `linkToObjectId` | [Id](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_id.htm) | The Id of the object to link the content version to. |
| `fileName` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The name of the file. |
| `body` | [Blob](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_blob.htm) | The binary data of the file. |

**Returns** [ContentVersion](https://developer.salesforce.com/docs/atlas.en-us.object_reference.meta/object_reference/sforce_api_objects_contentversion.htm) — An uncommitted ContentVersion record.

**Example**

```apex
Account account = (Account)TST_Builder.of(Account.SObjectType).build();
ContentVersion version = TST_Factory.newContentVersion(account.Id, 'test.pdf', Blob.valueOf('Test data'));
insert version;
Assert.areEqual('test.pdf', version.Title, 'Expected the file name to be the title');
```

</div>

### newFeatureFlag

<div class="apex-member">

```apex
global static FeatureFlag__mdt newFeatureFlag(String flagName)
```

Activates a feature flag for testing by injecting it into the selector cache.
`UTIL_FeatureFlag.isEnabled(flagName)` will return `true` after this call.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `flagName` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The developer name of the feature flag to activate. |

**Returns** [FeatureFlag__mdt](../metadata/FeatureFlag__mdt.md) — The activated FeatureFlag__mdt record.

**Example**

```apex
TST_Factory.newFeatureFlag('MyFeatureFlag');
```

</div>

### newInboundApiCall

<div class="apex-member">

```apex
global static ApiCall__c newInboundApiCall(String serviceName)
```

Creates an uncommitted ApiCall__c record for an inbound web service call.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `serviceName` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The name of the web service class. |

**Returns** [ApiCall__c](../objects/ApiCall__c.md) — An uncommitted ApiCall__c record.

**Example**

```apex
ApiCall__c inboundApiCall = TST_Factory.newInboundApiCall('InboundService');
insert inboundApiCall;
Assert.isNotNull(inboundApiCall.Id, 'Expected the inbound call record to be saved');
```

</div>

### newInboundApiSetting

<div class="apex-member">

```apex
global static ApiSetting__mdt newInboundApiSetting(String className, String endpointPath)
```

Creates a mock inbound ApiSetting__mdt record via TST_Mock for test routing.
The setting is registered in the mock cache and will be returned by SEL_ApiSetting queries.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `className` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The fully qualified name of the inbound API handler class |
| `endpointPath` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The URL path pattern for routing (e.g., '/echo/*') |

**Returns** [ApiSetting__mdt](../metadata/ApiSetting__mdt.md) — A mock ApiSetting__mdt record

**Example**

```apex
ApiSetting__mdt setting = TST_Factory.newInboundApiSetting('API_Echo', '/echo/*');
```

</div>

<div class="apex-member">

```apex
global static ApiSetting__mdt newInboundApiSetting(String className, String endpointPath, Integer priority)
```

Creates a mock inbound ApiSetting__mdt record with a custom priority, registered
with TST_Mock for query interception.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `className` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The API handler class name |
| `endpointPath` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The URL path pattern for routing (e.g., '/echo/*') |
| `priority` | [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) | The routing priority (lower number wins when paths are equal) |

**Returns** [ApiSetting__mdt](../metadata/ApiSetting__mdt.md) — A mock ApiSetting__mdt record

**Example**

```apex
ApiSetting__mdt setting = TST_Factory.newInboundApiSetting('API_Echo', '/echo/*', 50);
```

</div>

<div class="apex-member">

```apex
global static ApiSetting__mdt newInboundApiSetting(String className, String endpointPath, Integer priority, Map<SObjectField, Object> overrides)
```

Creates a mock inbound ApiSetting__mdt record with a custom priority and additional
field overrides, registered with TST_Mock for query interception.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `className` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The API handler class name |
| `endpointPath` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The URL path pattern for routing (e.g., '/echo/*') |
| `priority` | [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) | The routing priority (lower number wins when paths are equal) |
| `overrides` | [Map](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_map.htm) | Additional field values to apply on top of the defaults (may be null) |

**Returns** [ApiSetting__mdt](../metadata/ApiSetting__mdt.md) — A mock ApiSetting__mdt record

**Example**

```apex
ApiSetting__mdt setting = TST_Factory.newInboundApiSetting('API_Echo', '/echo/*', 100, new Map<SObjectField, Object>
{
    ApiSetting__mdt.LogIssues__c => true
});
```

</div>

### newOutboundApiCall

<div class="apex-member">

```apex
global static ApiCall__c newOutboundApiCall(String serviceName)
```

Creates an uncommitted ApiCall__c record for an outbound web service call.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `serviceName` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The name of the web service class. |

**Returns** [ApiCall__c](../objects/ApiCall__c.md) — An uncommitted ApiCall__c record.

**Example**

```apex
ApiCall__c outboundApiCall = TST_Factory.newOutboundApiCall('OutboundService');
insert outboundApiCall;
Assert.isNotNull(outboundApiCall.Id, 'Expected the outbound call record to be saved');
```

</div>

<div class="apex-member">

```apex
global static ApiCall__c newOutboundApiCall(String serviceName, Id recordId)
```

Creates an uncommitted ApiCall__c record for an outbound web service call with a triggering object.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `serviceName` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The name of the web service class. |
| `recordId` | [Id](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_id.htm) | The Id of the object triggering the service. |

**Returns** [ApiCall__c](../objects/ApiCall__c.md) — An uncommitted ApiCall__c record.

**Example**

```apex
Account account = (Account)TST_Builder.of(Account.SObjectType).build();
ApiCall__c apiCall = TST_Factory.newOutboundApiCall('OutboundService', account.Id);
insert apiCall;
Assert.isNotNull(apiCall.Id, 'Expected the call record to be saved');
```

</div>

<div class="apex-member">

```apex
global static ApiCall__c newOutboundApiCall(String serviceName, Id recordId, Map<String, String> requestParameters)
```

Creates an uncommitted ApiCall__c record for an outbound web service call with parameters.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `serviceName` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The name of the web service class. |
| `recordId` | [Id](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_id.htm) | The Id of the object triggering the service. |
| `requestParameters` | [Map](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_map.htm) | A map of name-value pairs for request parameters. |

**Returns** [ApiCall__c](../objects/ApiCall__c.md) — An uncommitted ApiCall__c record.

**Example**

```apex
Account account = (Account)TST_Builder.of(Account.SObjectType).build();
Map<String, String> params = new Map<String, String>
{
    'key' => 'value'
};
ApiCall__c apiCall = TST_Factory.newOutboundApiCall('OutboundService', account.Id, params);
insert apiCall;
Assert.isNotNull(apiCall.Id, 'Expected the call record to be saved');
```

</div>

<div class="apex-member">

```apex
global static ApiCall__c newOutboundApiCall(String serviceName, Id recordId, String parameterName, String parameterValue)
```

Creates an uncommitted ApiCall__c record for an outbound web service call with a single parameter.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `serviceName` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The name of the web service class. |
| `recordId` | [Id](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_id.htm) | The Id of the object triggering the service. |
| `parameterName` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The name of the additional parameter. |
| `parameterValue` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The value of the additional parameter. |

**Returns** [ApiCall__c](../objects/ApiCall__c.md) — An uncommitted ApiCall__c record.

**Example**

```apex
Account account = (Account)TST_Builder.of(Account.SObjectType).build();
ApiCall__c apiCall = TST_Factory.newOutboundApiCall('OutboundService', account.Id, 'key', 'value');
insert apiCall;
Assert.isNotNull(apiCall.Id, 'Expected the call record to be saved');
```

</div>

### newOutboundApiSetting

<div class="apex-member">

```apex
global static ApiSetting__mdt newOutboundApiSetting(String className, Map<SObjectField, Object> overrides)
```

Creates a mock outbound ApiSetting__mdt record via TST_Mock for query interception.
The setting defaults to active and Outbound direction; overrides can replace any field value
including IsActive__c. Pass null when no overrides are needed.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `className` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The fully qualified name of the outbound API handler class |
| `overrides` | [Map](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_map.htm) | Additional field values to apply on top of the defaults (may be null) |

**Returns** [ApiSetting__mdt](../metadata/ApiSetting__mdt.md) — A mock ApiSetting__mdt record

**Example**

```apex
ApiSetting__mdt setting = TST_Factory.newOutboundApiSetting('API_SendEmail', null);
```

</div>

### newUser

<div class="apex-member">

```apex
global static User newUser(String profileName)
```

Creates a single uncommitted User record with the specified profile.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `profileName` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The name of the profile to assign to the user. |

**Returns** [User](https://developer.salesforce.com/docs/atlas.en-us.object_reference.meta/object_reference/sforce_api_objects_user.htm) — An uncommitted User record.

**Example**

```apex
User testUser = TST_Factory.newUser('System Administrator');
insert testUser;
Assert.isNotNull(testUser.Id, 'Expected the user to be saved');
```

</div>

<div class="apex-member">

```apex
global static User newUser(String profileName, String companyName)
```

Creates an uncommitted User record with a custom company name.

The company name can be used as a unique identifier to later retrieve this specific user

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `profileName` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The Profile name to assign to the user. |
| `companyName` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | A unique company name for this user. |

**Returns** [User](https://developer.salesforce.com/docs/atlas.en-us.object_reference.meta/object_reference/sforce_api_objects_user.htm) — An uncommitted User record with the specified company name.

**Example**

```apex
@TestSetup
private static void setupTestData()
{
    User testUser = TST_Factory.newUser('Standard User', 'my-test-user');
    insert testUser;
}
private static User getTestUser()
{
    return new SEL_User().findByCompanyName('my-test-user');
}
```

</div>

### newUsers

<div class="apex-member">

```apex
global static List<User> newUsers(String profileName, Integer numberOfUsers)
```

Creates a list of uncommitted User records with the specified profile.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `profileName` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The name of the profile to assign to the users. |
| `numberOfUsers` | [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) | The number of users to create. |

**Returns** [User](https://developer.salesforce.com/docs/atlas.en-us.object_reference.meta/object_reference/sforce_api_objects_user.htm) — A list of uncommitted User records.

**Example**

```apex
List<User> mockUsers = TST_Factory.newUsers('Standard User', 5);
insert mockUsers;
for (User u : mockUsers)
{
Assert.isNotNull(u.Id, 'Expected each user to be saved');
}
```

</div>

### newUserWithPermissionSet

<div class="apex-member">

```apex
global static User newUserWithPermissionSet(String profileName, String companyName, String permissionSetName)
```

Creates and inserts a User with the specified profile + company name, then assigns
the named permission set (or permission set group). Composes insertUser(profileName, companyName) and
createPermissionSetAssignments(List , String), so both setup writes run inside the factory's own guard
and the test can save ordinary records before or after this call in the same transaction.

Intended for use in @TestSetup as a committed test admin that test methods reach via
System.runAs. Because runAs re-evaluates permissions for the inner scope, the test admin
receives a fresh permission cache, bypassing the stale-cache issue that affects mutation
of the currently-running user's permission set mid-transaction (the failure mode that made
assignAdministratorPermissionSet() unreliable in the 2GP synthetic validation org).

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `profileName` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The Profile name to assign to the user. |
| `companyName` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | A unique company name for this user. Used as the retrieval discriminator via SEL_User.findByCompanyName. |
| `permissionSetName` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The API name of the permission set (or permission set group) to assign. |

**Returns** [User](https://developer.salesforce.com/docs/atlas.en-us.object_reference.meta/object_reference/sforce_api_objects_user.htm) — The committed User record with the permission set assigned.

**Throws**

| Exception | Description |
|-----------|-------------|
| [AssertException](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_classes_exception_methods.htm) | If the profile or permission set cannot be resolved for the target org. |

**Example**

```apex
private static final String TEST_ADMIN_COMPANY = 'MyClass_TEST-admin';
@TestSetup
private static void setupTestAdmin()
{
    TST_Factory.newUserWithPermissionSet(
            'System Administrator',
            TEST_ADMIN_COMPANY,
            'Administrator'
    );
}
private static User getTestAdmin()
{
    return new SEL_User().findByCompanyName(TEST_ADMIN_COMPANY);
}
@IsTest
private static void shouldDoX()
{
    System.runAs(getTestAdmin())
    {
        // test body
    }
}
```

</div>

