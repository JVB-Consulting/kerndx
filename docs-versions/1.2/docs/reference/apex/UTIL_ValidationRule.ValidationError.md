---
title: "UTIL_ValidationRule.ValidationError"
type: class
pageClass: reference
description: "Represents a single validation error or warning."
since: "1.0"
category: apex
---

# UTIL_ValidationRule.ValidationError

**Class**

<div class="apex-member apex-class">

```apex
global class UTIL_ValidationRule.ValidationError
```

Represents a single validation error or warning.

</div>

---

## Constructors

| Constructor | Description |
|-------------|-------------|
| global [ValidationError](#constructors)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) ruleName, [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) message, [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) fieldName, [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) severity) | Constructs a new ValidationError. |

### ValidationError(String ruleName, String message, String fieldName, String severity)

<div class="apex-member">

```apex
global ValidationError(String ruleName, String message, String fieldName, String severity)
```

Constructs a new ValidationError.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `ruleName` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The rule DeveloperName |
| `message` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The error message |
| `fieldName` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The field API name (may be null) |
| `severity` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The severity level |

**Example**

```apex
UTIL_ValidationRule.ValidationError instance = new UTIL_ValidationRule.ValidationError('myName', 'An error occurred', 'myName', 'Error');
```

</div>

## Fields

| Field | Description |
|-------|-------------|
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [fieldName](#fieldname) | The field API name to display the error on (may be null for page-level). |
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [groupName](#groupname) | The validation rule group DeveloperName. |
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [message](#message) | The error message to display. |
| global [Id](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_id.htm) [recordId](#recordid) | The record ID (available except in before insert). |
| global [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) [recordIndex](#recordindex) | The record index in the trigger list (for before insert). |
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [ruleName](#rulename) | The DeveloperName of the validation rule that failed. |
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [severity](#severity) | The severity ('Error' or 'Warning'). |
| global [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) [shadowMode](#shadowmode) | True if this error is from a rule in shadow mode. |

### fieldName

```apex
@AuraEnabled global String fieldName
```

**Type:** [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)

The field API name to display the error on (may be null for page-level).

**Example**

```apex
String value = instance.fieldName;
```

### groupName

```apex
@AuraEnabled global String groupName
```

**Type:** [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)

The validation rule group DeveloperName.

**Example**

```apex
String value = instance.groupName;
```

### message

```apex
@AuraEnabled global String message
```

**Type:** [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)

The error message to display.

**Example**

```apex
String value = instance.message;
```

### recordId

```apex
@AuraEnabled global Id recordId
```

**Type:** [Id](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_id.htm)

The record ID (available except in before insert).

**Example**

```apex
Id value = instance.recordId;
```

### recordIndex

```apex
@AuraEnabled global Integer recordIndex
```

**Type:** [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm)

The record index in the trigger list (for before insert).

**Example**

```apex
Integer value = instance.recordIndex;
```

### ruleName

```apex
@AuraEnabled global String ruleName
```

**Type:** [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)

The DeveloperName of the validation rule that failed.

**Example**

```apex
String value = instance.ruleName;
```

### severity

```apex
@AuraEnabled global String severity
```

**Type:** [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)

The severity ('Error' or 'Warning').

**Example**

```apex
String value = instance.severity;
```

### shadowMode

```apex
@AuraEnabled global Boolean shadowMode
```

**Type:** [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm)

True if this error is from a rule in shadow mode.

**Example**

```apex
Boolean value = instance.shadowMode;
```

