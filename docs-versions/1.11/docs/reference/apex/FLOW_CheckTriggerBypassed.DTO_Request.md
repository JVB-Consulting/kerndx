---
title: "FLOW_CheckTriggerBypassed.DTO_Request"
type: class
pageClass: reference
description: "A DTO indicating what action has been bypassed"
since: "1.0"
category: apex
---

# FLOW_CheckTriggerBypassed.DTO_Request

**Class**

<div class="apex-member apex-class">

```apex
global inherited sharing class FLOW_CheckTriggerBypassed.DTO_Request
```

A DTO indicating what action has been bypassed

**Example**

```apex
DTO_Request request = new DTO_Request();
request.name = 'Account';
request.bypassType = 'OBJECT_NAME';
```

</div>

---

## Fields

| Field | Description |
|-------|-------------|
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [bypassType](#bypasstype) | The type of bypass to check: Class (stored as CLASS_NAME) checks one trigger action class; Object (stored as OBJECT_NAME) checks an object-wide bypass. |
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [name](#name) | The API name of the trigger action class or SObject to check bypass status for. |

### bypassType

```apex
@InvocableVariable(description='Pick Class to check a trigger action class bypass, or Object to check an object-wide bypass. Stored values are CLASS_NAME and OBJECT_NAME; the field shows the stored value.' label='Bypass Type' placeholderText='OBJECT_NAME' defaultValue='OBJECT_NAME') global String bypassType
```

**Type:** [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)

The type of bypass to check: Class (stored as CLASS_NAME) checks one trigger action class;
Object (stored as OBJECT_NAME) checks an object-wide bypass.

### name

```apex
@InvocableVariable(required=true description='API name of the trigger action class or SObject to check' label='Item Name') global String name
```

**Type:** [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)

The API name of the trigger action class or SObject to check bypass status for.

