---
title: "UTIL_ValidationRule.ValidationResult"
type: class
pageClass: reference
description: "Result of validating a single record. Contains all validation errors/warnings for that record."
since: "1.0"
category: apex
---

# UTIL_ValidationRule.ValidationResult

**Class**

<div class="apex-member apex-class">

```apex
global class UTIL_ValidationRule.ValidationResult
```

Result of validating a single record. Contains all validation errors/warnings for that record.

</div>

---

## Methods

| Method | Description |
|--------|-------------|
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [getErrorMessage](#geterrormessage)() | Gets concatenated error message string. |
| global [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[UTIL_ValidationRule.ValidationError](UTIL_ValidationRule.ValidationError.md)> [getErrorsBySeverity](#geterrorsbyseverity)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) severity) | Gets errors filtered by severity. |

### getErrorMessage

<div class="apex-member">

```apex
global String getErrorMessage()
```

Gets concatenated error message string.

**Returns** [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) — All error messages joined by newlines

**Example**

```apex
String result = instance.getErrorMessage();
```

</div>

### getErrorsBySeverity

<div class="apex-member">

```apex
global List<UTIL_ValidationRule.ValidationError> getErrorsBySeverity(String severity)
```

Gets errors filtered by severity.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `severity` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The severity to filter by ('Error' or 'Warning') |

**Returns** [UTIL_ValidationRule.ValidationError](UTIL_ValidationRule.ValidationError.md) — List of errors matching the severity

**Example**

```apex
List<ValidationError> result = instance.getErrorsBySeverity('Error');
```

</div>

## Constructors

| Constructor | Description |
|-------------|-------------|
| global [ValidationResult](#constructors)([Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) recordIndex, [Id](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_id.htm) recordId) | Constructs a new ValidationResult for the given record. |

### ValidationResult(Integer recordIndex, Id recordId)

<div class="apex-member">

```apex
global ValidationResult(Integer recordIndex, Id recordId)
```

Constructs a new ValidationResult for the given record.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `recordIndex` | [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) | The index in the trigger list |
| `recordId` | [Id](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_id.htm) | The record ID (may be null for before insert) |

**Example**

```apex
UTIL_ValidationRule.ValidationResult instance = new UTIL_ValidationRule.ValidationResult(10, recordId);
```

</div>

## Properties

| Property | Description |
|----------|-------------|
| global [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[UTIL_ValidationRule.ValidationError](UTIL_ValidationRule.ValidationError.md)> [errors](#errors) | List of validation errors/warnings for this record. |
| global [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) [isValid](#isvalid) | True if the record passed all validation rules. |

### errors

```apex
global List<UTIL_ValidationRule.ValidationError> errors
```

**Type:** [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)

List of validation errors/warnings for this record.

### isValid

```apex
global Boolean isValid
```

**Type:** [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm)

True if the record passed all validation rules.

## Fields

| Field | Description |
|-------|-------------|
| global [Id](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_id.htm) [recordId](#recordid) | The record ID (available in all contexts except before insert). |
| global [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) [recordIndex](#recordindex) | The index of the record in the trigger list (for before insert correlation). |

### recordId

```apex
global Id recordId
```

**Type:** [Id](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_id.htm)

The record ID (available in all contexts except before insert).

**Example**

```apex
Id value = instance.recordId;
```

### recordIndex

```apex
global Integer recordIndex
```

**Type:** [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm)

The index of the record in the trigger list (for before insert correlation).

**Example**

```apex
Integer value = instance.recordIndex;
```

