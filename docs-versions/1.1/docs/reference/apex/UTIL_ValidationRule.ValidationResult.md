---
title: "UTIL_ValidationRule.ValidationResult"
type: class
description: "Result of validating a single record. Contains all validation errors/warnings for that record."
since: "1.0"
category: apex
---

# UTIL_ValidationRule.ValidationResult

**Class**

```apex
global class UTIL_ValidationRule.ValidationResult
```

Result of validating a single record. Contains all validation errors/warnings for that record.

**Since:** 1.0

---

## Properties

| Property | Description |
|----------|-------------|
| global [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm) [errors](#errors) | List of validation errors/warnings for this record. |
| global [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) [isValid](#isvalid) | True if the record passed all validation rules. |

## Fields

| Field | Description |
|-------|-------------|
| global [Id](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_id.htm) [recordId](#recordid) | The record ID (available in all contexts except before insert). |
| global [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) [recordIndex](#recordindex) | The index of the record in the trigger list (for before insert correlation). |

## Methods

| Method | Description |
|--------|-------------|
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [getErrorMessage](#geterrormessage)() | Gets concatenated error message string. |
| global [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm) [getErrorsBySeverity](#geterrorsbyseverity)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) severity) | Gets errors filtered by severity. |
| global [ValidationResult](#validationresult)([Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) recordIndex, [Id](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_id.htm) recordId) | Constructs a new ValidationResult for the given record. |

---

## Property Details

### errors

```apex
global List<UTIL_ValidationRule.ValidationError> errors
```

**Type:** [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)

List of validation errors/warnings for this record.

Since:


Example:

### isValid

```apex
global Boolean isValid
```

**Type:** [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm)

True if the record passed all validation rules.

Since:


Example:

---

## Method Details

### ValidationResult

```apex
global ValidationResult(Integer recordIndex, Id recordId)
```

Constructs a new ValidationResult for the given record.

**Parameters:**

- `recordIndex` ([Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm)) - The index in the trigger list
- `recordId` ([Id](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_id.htm)) - The record ID (may be null for before insert)

**Since:** 1.0

**Example:**

```apex
UTIL_ValidationRule.ValidationResult instance = new UTIL_ValidationRule.ValidationResult(10, recordId);
```

### getErrorMessage

```apex
global String getErrorMessage()
```

Gets concatenated error message string.

**Returns:** [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) - All error messages joined by newlines

**Since:** 1.0

**Example:**

```apex
String result = instance.getErrorMessage();
```

### getErrorsBySeverity

```apex
global List<UTIL_ValidationRule.ValidationError> getErrorsBySeverity(String severity)
```

Gets errors filtered by severity.

**Parameters:**

- `severity` ([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)) - The severity to filter by ('Error' or 'Warning')

**Returns:** [UTIL_ValidationRule.ValidationError](UTIL_ValidationRule.ValidationError.md) - List of errors matching the severity

**Since:** 1.0

**Example:**

```apex
List<ValidationError> result = instance.getErrorsBySeverity('Error');
```

---

## Field Details

### recordId

```apex
global Id recordId
```

**Type:** [Id](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_id.htm)

The record ID (available in all contexts except before insert).

**Since:** 1.0

**Example:**

```apex
Id value = instance.recordId;
```

### recordIndex

```apex
global Integer recordIndex
```

**Type:** [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm)

The index of the record in the trigger list (for before insert correlation).

**Since:** 1.0

**Example:**

```apex
Integer value = instance.recordIndex;
```

