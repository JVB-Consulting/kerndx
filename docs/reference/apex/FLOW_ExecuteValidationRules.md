---
title: "FLOW_ExecuteValidationRules"
type: class
pageClass: reference
description: "Flow invocable action to execute validation rules against records. Use this in Record-Triggered Flows or Screen Flows to validate records before DML and display user-friendly error messages. Usage in "
author: "Jason Van Beukering"
group: "Validation"
date: "January 2026, May 2026"
since: "1.0"
category: apex
---

# FLOW_ExecuteValidationRules

**Class** · Group: `Validation`

<div class="apex-member apex-class">

```apex
global inherited sharing class FLOW_ExecuteValidationRules
```

Flow invocable action to execute validation rules against records. Use this in Record-Triggered Flows or Screen Flows to validate records before DML and display user-friendly error messages. Usage in Screen Flow (Pre-DML Validation): User fills in fields on a screen Before "Create Records" element, add "Action" element Call this invocable with the record(s) to validate Check HasErrors output - if true, display errors and loop back to edit screen If false, proceed to Create Records

**Example**

`// Flow Configuration: Action: Execute Validation Rules Input: ` Records: {!$Record} or collection TriggerContext: BEFORE_INSERT OldRecords: (leave empty for insert; use {!$Record__Prior} for update) Output: HasErrors: Boolean - check in Decision element HasWarnings: Boolean - check for non-blocking warnings Errors: List<DTO_FlowValidationError> - display in lwcValidationErrors component Warnings: List<DTO_FlowValidationError> - display shadow mode or warning-severity results `ErrorMessage: String - concatenated message for simple display `

**See Also:** [UTIL_ValidationRule](UTIL_ValidationRule.md), [FLOW_BypassValidation](FLOW_BypassValidation.md)

</div>

---

## Methods

| Method | Description |
|--------|-------------|
| global static [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[FLOW_ExecuteValidationRules.DTO_Response](FLOW_ExecuteValidationRules.DTO_Response.md)> [execute](#execute)([List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[FLOW_ExecuteValidationRules.DTO_Request](FLOW_ExecuteValidationRules.DTO_Request.md)> requests) | Executes validation rules against the provided records. |

### execute

<div class="apex-member">

```apex
@InvocableMethod(category='Validation' description='Validates records against formula-driven validation rules. Returns errors/warnings without blocking save.' label='Execute Validation Rules') global static List<FLOW_ExecuteValidationRules.DTO_Response> execute(List<FLOW_ExecuteValidationRules.DTO_Request> requests)
```

Executes validation rules against the provided records.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `requests` | [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm) | List of validation requests (typically just one from Flow) |

**Returns** [FLOW_ExecuteValidationRules.DTO_Response](FLOW_ExecuteValidationRules.DTO_Response.md) — List of validation responses with errors and warnings

**Example**

```apex
// Programmatic usage example
FLOW_ExecuteValidationRules.DTO_Request request = new FLOW_ExecuteValidationRules.DTO_Request();
request.records = new List<SObject>{account};
request.triggerContext = 'BEFORE_INSERT';
List<FLOW_ExecuteValidationRules.DTO_Response> responses =
    FLOW_ExecuteValidationRules.execute(new List<FLOW_ExecuteValidationRules.DTO_Request>{request});
if(responses[0].hasErrors)
{
    // Handle validation errors
}
```

</div>

## Inner Classes

| Class | Description |
|-------|-------------|
| [DTO_Request](FLOW_ExecuteValidationRules.DTO_Request.md) | Request DTO for the Execute Validation Rules invocable action. |
| [DTO_Response](FLOW_ExecuteValidationRules.DTO_Response.md) | Response DTO for the Execute Validation Rules invocable action. |

---

