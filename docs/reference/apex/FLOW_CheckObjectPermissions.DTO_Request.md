---
title: "FLOW_CheckObjectPermissions.DTO_Request"
type: class
pageClass: reference
description: "DTO containing the name of the object for which to object permissions"
since: "1.0"
category: apex
---

# FLOW_CheckObjectPermissions.DTO_Request

**Class**

```apex
global inherited sharing class FLOW_CheckObjectPermissions.DTO_Request
```

DTO containing the name of the object for which to object permissions

**Since:** 1.0

---

## Fields

| Field | Description |
|-------|-------------|
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [objectApiName](#objectapiname) | The API name of the object for which to check permissions. |

---

## Field Details

### objectApiName

```apex
@InvocableVariable(required=true description='The API name of the object for which you want to check permissions' label='Object Name' placeholderText='Foobar__c') global String objectApiName
```

**Type:** [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)

The API name of the object for which to check permissions.

**Since:** 1.0

