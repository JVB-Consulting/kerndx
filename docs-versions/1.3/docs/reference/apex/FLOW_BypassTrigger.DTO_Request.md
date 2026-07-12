---
title: "FLOW_BypassTrigger.DTO_Request"
type: class
pageClass: reference
description: "Request DTO for the Trigger Bypass invocable action."
since: "1.0"
category: apex
---

# FLOW_BypassTrigger.DTO_Request

**Class**

<div class="apex-member apex-class">

```apex
global inherited sharing class FLOW_BypassTrigger.DTO_Request
```

Request DTO for the Trigger Bypass invocable action.

</div>

---

## Fields

| Field | Description |
|-------|-------------|
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [action](#action) | The action to perform. |
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [bypassType](#bypasstype) | The type of bypass: Class (stored as CLASS_NAME) targets one trigger action class; Object (stored as OBJECT_NAME) targets every trigger action on the object. |
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [name](#name) | The API name of the trigger action class or SObject. |

### action

```apex
@InvocableVariable(description='Pick Bypass to add a bypass, Clear to remove one, or Clear All to remove every bypass. Stored values are BYPASS, CLEAR, and CLEAR_ALL; the field shows the stored value.' label='Action' placeholderText='BYPASS' defaultValue='BYPASS') global String action
```

**Type:** [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)

The action to perform. Valid values:

    BYPASS: Add to the bypass list (default)
    CLEAR: Remove a specific item from the bypass list
    CLEAR_ALL: Clear all items from the bypass list (name is ignored)

### bypassType

```apex
@InvocableVariable(description='Pick Class to bypass one trigger action class, or Object to bypass every trigger action on an object. Stored values are CLASS_NAME and OBJECT_NAME; the field shows the stored value.' label='Bypass Type' placeholderText='OBJECT_NAME' defaultValue='OBJECT_NAME') global String bypassType
```

**Type:** [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)

The type of bypass: Class (stored as CLASS_NAME) targets one trigger action class;
Object (stored as OBJECT_NAME) targets every trigger action on the object.

### name

```apex
@InvocableVariable(required=true description='API Name of the trigger action class or SObject' label='Name') global String name
```

**Type:** [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)

The API name of the trigger action class or SObject. Required for BYPASS and CLEAR actions, ignored for CLEAR_ALL.

