---
title: "FLOW_ExecuteValidationRules.DTO_Response"
type: class
description: "Response DTO for the Execute Validation Rules invocable action. Contains the validation results including errors, warnings, and summary flags. Use hasErrors in a Decision element to determine whether "
since: "1.0"
category: apex
---

# FLOW_ExecuteValidationRules.DTO_Response

**Class**

```apex
global inherited sharing class FLOW_ExecuteValidationRules.DTO_Response
```

Response DTO for the Execute Validation Rules invocable action. Contains the validation results including errors, warnings, and summary flags. Use hasErrors in a Decision element to determine whether to proceed with DML or display errors.

**Since:** 1.0

---

## Fields

| Field | Description |
|-------|-------------|
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [errorMessage](#errormessage) | Combined error message string containing all blocking error messages joined by newlines. |
| global [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[DTO_FlowValidationError](DTO_FlowValidationError.md)> [errors](#errors) | List of blocking validation errors. |
| global [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) [hasErrors](#haserrors) | True if any blocking validation errors occurred. |
| global [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) [hasWarnings](#haswarnings) | True if any warnings occurred. |
| global [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[DTO_FlowValidationError](DTO_FlowValidationError.md)> [warnings](#warnings) | List of validation warnings. |

---

## Field Details

### errorMessage

```apex
@InvocableVariable(description='Combined error message for simple display' label='Error Message') global String errorMessage
```

**Type:** [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)

Combined error message string containing all blocking error messages joined
by newlines. Useful for simple text display in a Flow screen when you don't need to show
individual field-level errors. Empty string if no errors occurred.

**Since:** 1.0

**Example:**

```apex
String value = instance.errorMessage;
```

### errors

```apex
@InvocableVariable(description='List of blocking validation errors' label='Errors') global List<DTO_FlowValidationError> errors
```

**Type:** [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)

List of blocking validation errors. Each error contains the rule name, message,
field name, severity, and record index. Display these in a custom LWC component like
lwcValidationErrors for detailed field-level error presentation.

**Since:** 1.0

**Example:**

```apex
List<DTO_FlowValidationError> value = instance.errors;
```

### hasErrors

```apex
@InvocableVariable(description='True if validation failed with blocking errors' label='Has Errors') global Boolean hasErrors
```

**Type:** [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm)

True if any blocking validation errors occurred. Use this in a Flow Decision
element to determine whether to proceed with record save or redirect back to edit screen.
Only errors with severity 'Error' that are not in shadow mode are considered blocking.

**Since:** 1.0

**Example:**

```apex
Boolean value = instance.hasErrors;
```

### hasWarnings

```apex
@InvocableVariable(description='True if validation produced warnings' label='Has Warnings') global Boolean hasWarnings
```

**Type:** [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm)

True if any warnings occurred. Warnings include validation rules with severity
'Warning' and rules running in shadow mode. These do not block the save operation but may
be displayed to users for informational purposes.

**Since:** 1.0

**Example:**

```apex
Boolean value = instance.hasWarnings;
```

### warnings

```apex
@InvocableVariable(description='List of validation warnings' label='Warnings') global List<DTO_FlowValidationError> warnings
```

**Type:** [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)

List of validation warnings. Includes both warning-severity rules and errors
from rules running in shadow mode. Shadow mode errors are captured here for monitoring
purposes without blocking the save operation.

**Since:** 1.0

**Example:**

```apex
List<DTO_FlowValidationError> value = instance.warnings;
```

