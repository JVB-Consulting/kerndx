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

```apex
global inherited sharing class FLOW_CheckTriggerBypassed.DTO_Request
```

A DTO indicating what action has been bypassed

**Since:** 1.0

**Example:**

```apex
DTO_Request request = new DTO_Request();
request.name = 'Account';
request.bypassType = 'OBJECT_NAME';
```

---

## Fields

| Field | Description |
|-------|-------------|
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [bypassType](#bypasstype) | The type of bypass: either CLASS_NAME or OBJECT_NAME. |
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [name](#name) | The API name of the trigger action class or SObject to check bypass status for. |

---

## Field Details

### bypassType

```apex
@InvocableVariable(description='Must be either "CLASS_NAME" or "OBJECT_NAME"' label='Bypass Type' placeholderText='OBJECT_NAME' defaultValue='OBJECT_NAME') global String bypassType
```

**Type:** [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)

The type of bypass: either CLASS_NAME or OBJECT_NAME.

**Since:** 1.0

### name

```apex
@InvocableVariable(required=true description='API Name of the trigger action class nane, or SObject API Name' label='Item Name') global String name
```

**Type:** [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)

The API name of the trigger action class or SObject to check bypass status for.

**Since:** 1.0

