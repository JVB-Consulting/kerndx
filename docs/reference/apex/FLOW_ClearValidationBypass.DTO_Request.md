---
title: "FLOW_ClearValidationBypass.DTO_Request"
type: class
description: "Request DTO for the Clear Validation Bypass invocable action. Specifies which bypass to clear by name or clears all bypasses."
since: "1.0"
category: apex
---

# FLOW_ClearValidationBypass.DTO_Request

**Class**

```apex
global inherited sharing class FLOW_ClearValidationBypass.DTO_Request
```

Request DTO for the Clear Validation Bypass invocable action. Specifies which bypass to clear by name or clears all bypasses.

**Since:** 1.0

---

## Fields

| Field | Description |
|-------|-------------|
| global [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) [clearAll](#clearall) | When true, clears all active bypasses. |
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [name](#name) | The name of the bypassed object, group, or rule to clear. |

---

## Field Details

### clearAll

```apex
@InvocableVariable(description='When true, clears all active bypasses (Name is ignored)' label='Clear All') global Boolean clearAll
```

**Type:** [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm)

When true, clears all active bypasses. The Name field is ignored.

**Since:** 1.0

### name

```apex
@InvocableVariable(description='Object API name, group DeveloperName, or rule DeveloperName to clear from bypass list.' label='Name') global String name
```

**Type:** [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)

The name of the bypassed object, group, or rule to clear.
This should match the name used when creating the bypass with FLOW_BypassValidation.
The bypass is cleared from all lists (object, group, and rule) regardless of how it was set.
Ignored when clearAll is true.

**Since:** 1.0

