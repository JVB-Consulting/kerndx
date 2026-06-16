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

```apex
global inherited sharing class FLOW_BypassTrigger.DTO_Request
```

Request DTO for the Trigger Bypass invocable action.

**Since:** 1.0

---

## Fields

| Field | Description |
|-------|-------------|
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [action](#action) | The action to perform. |
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [bypassType](#bypasstype) | The type of bypass: either CLASS_NAME or OBJECT_NAME. |
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [name](#name) | The API name of the trigger action class or SObject. |

---

## Field Details

### action

```apex
@InvocableVariable(description='BYPASS, CLEAR, or CLEAR_ALL' label='Action' placeholderText='BYPASS' defaultValue='BYPASS') global String action
```

**Type:** [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)

The action to perform. Valid values:

    BYPASS: Add to the bypass list (default)
    CLEAR: Remove a specific item from the bypass list
    CLEAR_ALL: Clear all items from the bypass list (name is ignored)

**Since:** 1.0

### bypassType

```apex
@InvocableVariable(description='Must be either "CLASS_NAME" or "OBJECT_NAME"' label='Bypass Type' placeholderText='OBJECT_NAME' defaultValue='OBJECT_NAME') global String bypassType
```

**Type:** [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)

The type of bypass: either CLASS_NAME or OBJECT_NAME.

**Since:** 1.0

### name

```apex
@InvocableVariable(required=true description='API Name of the trigger action class or SObject' label='Name') global String name
```

**Type:** [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)

The API name of the trigger action class or SObject. Required for BYPASS and CLEAR actions, ignored for CLEAR_ALL.

**Since:** 1.0

