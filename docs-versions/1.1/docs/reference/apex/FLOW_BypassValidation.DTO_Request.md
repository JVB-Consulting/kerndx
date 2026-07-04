---
title: "FLOW_BypassValidation.DTO_Request"
type: class
description: "Request DTO for the Bypass Validation invocable action. Specifies which validation rules to bypass by type (object, group, or rule) and name."
since: "1.0"
category: apex
---

# FLOW_BypassValidation.DTO_Request

**Class**

```apex
global inherited sharing class FLOW_BypassValidation.DTO_Request
```

Request DTO for the Bypass Validation invocable action. Specifies which validation rules to bypass by type (object, group, or rule) and name.

**Since:** 1.0

---

## Fields

| Field | Description |
|-------|-------------|
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [bypassType](#bypasstype) | The type of bypass to apply. |
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [name](#name) | The name of the object, group, or rule to bypass. |

---

## Field Details

### bypassType

```apex
@InvocableVariable(description='Type of bypass: OBJECT_NAME, GROUP_NAME, or RULE_NAME' label='Bypass Type') global String bypassType
```

**Type:** [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)

The type of bypass to apply. Determines how the Name field is interpreted.
Valid values are:

    OBJECT_NAME: Bypasses all validation rules for the specified SObject type
    GROUP_NAME: Bypasses all validation rules in the specified ValidationRuleGroup__mdt
    RULE_NAME: Bypasses a specific ValidationRule__mdt by its DeveloperName

Defaults to OBJECT_NAME if not specified.

To clear bypasses, use the FLOW_ClearValidationBypass action instead.

**Since:** 1.0

### name

```apex
@InvocableVariable(required=true description='Object API name, group DeveloperName, or rule DeveloperName to bypass.' label='Name') global String name
```

**Type:** [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)

The name of the object, group, or rule to bypass. Interpretation depends on bypassType:

    For OBJECT_NAME: The SObject API name (e.g., 'Account', 'MyCustomObject__c')
    For GROUP_NAME: The ValidationRuleGroup__mdt DeveloperName
    For RULE_NAME: The ValidationRule__mdt DeveloperName

Required for all bypass types.

**Since:** 1.0

