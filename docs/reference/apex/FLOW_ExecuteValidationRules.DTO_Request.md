---
title: "FLOW_ExecuteValidationRules.DTO_Request"
type: class
pageClass: reference
description: "Request DTO for the Execute Validation Rules invocable action. Contains the records to validate and the trigger context for rule evaluation."
since: "1.0"
category: apex
---

# FLOW_ExecuteValidationRules.DTO_Request

**Class**

<div class="apex-member apex-class">

```apex
global inherited sharing class FLOW_ExecuteValidationRules.DTO_Request
```

Request DTO for the Execute Validation Rules invocable action. Contains the records to validate and the trigger context for rule evaluation.

</div>

---

## Fields

| Field | Description |
|-------|-------------|
| global [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm)> [oldRecords](#oldrecords) | The previous record values before the change. |
| global [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm)> [records](#records) | The new/current records to validate. |
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [triggerContext](#triggercontext) | The trigger operation context that determines which validation rules to execute. |

---

## Field Details

### oldRecords

```apex
@InvocableVariable(description='The previous record values before the change. Required for BEFORE_UPDATE and AFTER_UPDATE to enable change detection in validation formulas. Leave empty for insert, delete, and undelete operations.' label='Old Records') global List<SObject> oldRecords
```

**Type:** [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)

The previous record values before the change. Required for BEFORE_UPDATE and
AFTER_UPDATE operations to enable change detection in validation formulas (e.g., ISCHANGED,
PRIORVALUE functions). Leave empty for insert, delete, and undelete operations.
In Record-Triggered Flows, use {!$Record__Prior} to populate this field.

### records

```apex
@InvocableVariable(required=true description='The new/current records to validate. For insert: the records being created. For update: the records with new values. For delete: the records being deleted.' label='Records') global List<SObject> records
```

**Type:** [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)

The new/current records to validate. For insert operations, these are the records
being created. For update operations, these are the records with their new field values.
For delete operations, these are the records being deleted. This field is required.

### triggerContext

```apex
@InvocableVariable(description='The trigger operation context matching TriggerOperation enum: BEFORE_INSERT, BEFORE_UPDATE, BEFORE_DELETE, AFTER_INSERT, AFTER_UPDATE, AFTER_DELETE, or AFTER_UNDELETE.' label='Trigger Context' placeholderText='BEFORE_INSERT' defaultValue='BEFORE_INSERT') global String triggerContext
```

**Type:** [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)

The trigger operation context that determines which validation rules to execute.
Must match a TriggerOperation enum value: BEFORE_INSERT, BEFORE_UPDATE, BEFORE_DELETE,
AFTER_INSERT, AFTER_UPDATE, AFTER_DELETE, or AFTER_UNDELETE. Defaults to BEFORE_INSERT
if not specified.

