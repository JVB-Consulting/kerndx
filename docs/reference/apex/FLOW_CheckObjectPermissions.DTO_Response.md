---
title: "FLOW_CheckObjectPermissions.DTO_Response"
type: class
description: "DTO containing the permissions per object provided in request."
since: "1.0"
category: apex
---

# FLOW_CheckObjectPermissions.DTO_Response

**Class**

```apex
global inherited sharing class FLOW_CheckObjectPermissions.DTO_Response
```

DTO containing the permissions per object provided in request.

**Since:** 1.0

---

## Fields

| Field | Description |
|-------|-------------|
| global [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) [hasCreateAccess](#hascreateaccess) | Whether the running user has create access to the object. |
| global [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) [hasDeleteAccess](#hasdeleteaccess) | Whether the running user has delete access to the object. |
| global [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) [hasEditAccess](#haseditaccess) | Whether the running user has edit access to the object. |
| global [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) [hasReadAccess](#hasreadaccess) | Whether the running user has read access to the object. |
| global [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) [isValidObject](#isvalidobject) | Whether the provided object API name resolves to a valid SObject type. |
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [objectApiName](#objectapiname) | The API name of the object these permissions apply to. |

---

## Field Details

### hasCreateAccess

```apex
@InvocableVariable(required=true description='Whether the running user can create records of this object type' label='Has Create Access') global Boolean hasCreateAccess
```

**Type:** [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm)

Whether the running user has create access to the object.

**Since:** 1.0

### hasDeleteAccess

```apex
@InvocableVariable(required=true description='Whether the running user can delete records of this object type' label='Has Delete Access') global Boolean hasDeleteAccess
```

**Type:** [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm)

Whether the running user has delete access to the object.

**Since:** 1.0

### hasEditAccess

```apex
@InvocableVariable(required=true description='Whether the running user can edit records of this object type' label='Has Edit Access') global Boolean hasEditAccess
```

**Type:** [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm)

Whether the running user has edit access to the object.

**Since:** 1.0

### hasReadAccess

```apex
@InvocableVariable(required=true description='Whether the running user can read records of this object type' label='Has Read Access') global Boolean hasReadAccess
```

**Type:** [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm)

Whether the running user has read access to the object.

**Since:** 1.0

### isValidObject

```apex
@InvocableVariable(description='Whether the provided object API name resolves to a valid SObject type' label='Is Valid Object') global Boolean isValidObject
```

**Type:** [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm)

Whether the provided object API name resolves to a valid SObject type.

**Since:** 1.0

### objectApiName

```apex
@InvocableVariable(required=true description='The API name of the object these permissions apply to' label='Object Name') global String objectApiName
```

**Type:** [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)

The API name of the object these permissions apply to.

**Since:** 1.0

