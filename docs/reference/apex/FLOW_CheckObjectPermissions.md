---
title: "FLOW_CheckObjectPermissions"
type: class
description: "Will check what the current user's object permissions are"
author: "Jason Van Beukering"
group: "Utilities"
date: "February 2026, May 2026"
since: "1.0"
category: apex
---

# FLOW_CheckObjectPermissions

**Class** · Group: `Utilities`

```apex
global inherited sharing class FLOW_CheckObjectPermissions
```

Will check what the current user's object permissions are

**Since:** 1.0

**Example:**

```apex
FLOW_CheckObjectPermissions.DTO_Request request = new FLOW_CheckObjectPermissions.DTO_Request();
request.objectApiName = 'Account';
List<FLOW_CheckObjectPermissions.DTO_Response> results = FLOW_CheckObjectPermissions.checkPermissions(new List<FLOW_CheckObjectPermissions.DTO_Request> {request});
Boolean canCreate = results[0].hasCreateAccess;
```

---

## Methods

| Method | Description |
|--------|-------------|
| global static [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[FLOW_CheckObjectPermissions.DTO_Response](FLOW_CheckObjectPermissions.DTO_Response.md)> [checkPermissions](#checkpermissions)([List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[FLOW_CheckObjectPermissions.DTO_Request](FLOW_CheckObjectPermissions.DTO_Request.md)> dtoRequests) | Method to check the running users' access to the object names provided |

## Inner Classes

| Class | Description |
|-------|-------------|
| [DTO_Request](FLOW_CheckObjectPermissions.DTO_Request.md) | DTO containing the name of the object for which to object permissions |
| [DTO_Response](FLOW_CheckObjectPermissions.DTO_Response.md) | DTO containing the permissions per object provided in request. |

---

## Method Details

### checkPermissions

```apex
@InvocableMethod(category='Utilities' description='Checks whether the current user has read, create, edit, and delete access to a specified Salesforce object. Use to conditionally show or hide UI elements based on permissions.' label='Check Object Permissions') global static List<FLOW_CheckObjectPermissions.DTO_Response> checkPermissions(List<FLOW_CheckObjectPermissions.DTO_Request> dtoRequests)
```

Method to check the running users' access to the object names provided

**Parameters:**

- `dtoRequests` ([List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)) - List of objects for whom to retrieve permissions

**Returns:** [FLOW_CheckObjectPermissions.DTO_Response](FLOW_CheckObjectPermissions.DTO_Response.md) - List of items contain users objects permissions

**Since:** 1.0

**Example:**

```apex
FLOW_CheckObjectPermissions.DTO_Request request = new FLOW_CheckObjectPermissions.DTO_Request();
request.objectApiName = 'Account';
List<FLOW_CheckObjectPermissions.DTO_Response> results = FLOW_CheckObjectPermissions.checkPermissions(new List<FLOW_CheckObjectPermissions.DTO_Request>{request});
if(results[0].hasCreateAccess)
{
	LOG_Builder.build().info('User can create Account records').emitAt('MyFlow.checkPermissions');
}
```

