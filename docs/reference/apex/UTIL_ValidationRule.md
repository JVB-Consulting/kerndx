---
title: "UTIL_ValidationRule"
type: class
pageClass: reference
description: "Formula-driven declarative validation framework for advanced validation scenarios that standard Salesforce validation rules cannot handle. This framework enables: Cross-object validation requiring que"
author: "Jason Van Beukering"
group: "Validation"
date: "January 2026, June 2026"
since: "1.0"
category: apex
---

# UTIL_ValidationRule

**Class** · Group: `Validation`

<div class="apex-member apex-class">

```apex
global inherited sharing class UTIL_ValidationRule
```

Formula-driven declarative validation framework for advanced validation scenarios that standard Salesforce validation rules cannot handle. This framework enables: Cross-object validation requiring queries Complex conditional logic exceeding native formula limits Validation with sophisticated bypass rules Shadow mode for safe production testing Warning severity that logs but allows save Important: This framework complements standard validation rules. Use native Salesforce validation rules for simple field checks. Use this framework for advanced scenarios.

**Example**

```apex
List<UTIL_ValidationRule.ValidationResult> results =
    UTIL_ValidationRule.validate(Trigger.new, Trigger.old, TriggerOperation.BEFORE_UPDATE);
UTIL_ValidationRule.applyErrors(Trigger.new, results);
```

**See Also:** [ValidationRuleGroup__mdt](../metadata/ValidationRuleGroup__mdt.md), [ValidationRule__mdt](../metadata/ValidationRule__mdt.md), [TRG_ExecuteValidationRules](TRG_ExecuteValidationRules.md)

</div>

## Usage Patterns

### Trigger Integration (Recommended)

Configure via `TRG_ExecuteValidationRules` trigger action:

```apex
// No code required - configure via TriggerAction__mdt to use TRG_ExecuteValidationRules

```

### Direct Programmatic Usage

```apex
// Validate records programmatically
List<UTIL_ValidationRule.ValidationResult> results =
    UTIL_ValidationRule.validate(Trigger.new, Trigger.old, TriggerOperation.BEFORE_INSERT);

// Apply errors to records
UTIL_ValidationRule.applyErrors(Trigger.new, results);

```

### Bypass Usage

```apex
// Bypass all validation for an object
UTIL_ValidationRule.bypassObject('Account');
try
{
    insert accounts;
}
finally
{
    UTIL_ValidationRule.clearBypass('Account');
}

```

---

## Properties

| Property | Description |
|----------|-------------|
| global interface [INT_BulkValidationContext](UTIL_ValidationRule.INT_BulkValidationContext.md) | Optional interface for bulk-optimized validation contexts. |

## Methods

| Method | Description |
|--------|-------------|
| global static void [applyErrors](#applyerrors)([List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm)> records, [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[UTIL_ValidationRule.ValidationResult](UTIL_ValidationRule.ValidationResult.md)> results) | Applies validation errors to the trigger records. |
| global static void [bypassGroup](#bypassgroup)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) groupDeveloperName) | Bypasses all validation rules in the specified group. |
| global static void [bypassObject](#bypassobject)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) objectApiName) | Bypasses all validation rules for the specified object. |
| global static void [bypassRule](#bypassrule)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) ruleDeveloperName) | Bypasses a specific validation rule. |
| global static void [clearAllBypasses](#clearallbypasses)() | Clears all bypasses for the current transaction. |
| global static void [clearBypass](#clearbypass)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) identifier) | Clears a specific bypass (object, group, or rule). |
| global static void [executeForTrigger](#executefortrigger)([List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm)> newRecords, [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm)> oldRecords, [TriggerOperation](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_enum_System_TriggerOperation.htm) operation) | Executes validation rules for the current trigger context. |
| global static [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) [isBypassed](#isbypassed)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) identifier) | Checks if a specific bypass is currently active. |
| global static [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[UTIL_ValidationRule.ValidationResult](UTIL_ValidationRule.ValidationResult.md)> [validate](#validate)([List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm)> newRecords, [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm)> oldRecords, [TriggerOperation](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_enum_System_TriggerOperation.htm) operation) | Validates a list of records against all applicable validation rules. |

## Inner Classes

| Class | Description |
|-------|-------------|
| [ValidationError](UTIL_ValidationRule.ValidationError.md) | Represents a single validation error or warning. |
| [ValidationResult](UTIL_ValidationRule.ValidationResult.md) | Result of validating a single record. |

---

## Method Details

### applyErrors

<div class="apex-member">

```apex
global static void applyErrors(List<SObject> records, List<UTIL_ValidationRule.ValidationResult> results)
```

Applies validation errors to the trigger records.
Error severity violations call record.addError() to block save.
Warning severity violations are logged but don't block save.

**Page-level addError calls coalesce in Database.SaveResult.** When the validation rule
targets the whole record (i.e. `kern__ErrorDisplayField__c` is blank — page-level error),
each violation invokes `record.addError(message)`. Salesforce's platform behaviour for
page-level addError is to COALESCE multiple calls on the same record into a SINGLE
`Database.SaveResult.Error` entry — only the LAST rule's message is surfaced via
`getErrors()`. Field-level addError (`record.addError(field, message)`, used when
`kern__ErrorDisplayField__c` is set) is per-field unique and does NOT coalesce.

Subscribers that want to see ALL violations on a record should consult the framework's
own `ValidationResult.errors` collection, which preserves every violation regardless of
page vs field scope. The `Database.SaveResult.getErrors()` collection should be treated
as a "save blocked" / "save succeeded" boolean, not as a complete error inventory.

Empirically: a record violating two page-level rules (e.g. `RequireAccountIndustry` +
`PhoneOrWebsiteRequired`) returns `getErrors().size() == 1` with only the second rule's
message — but `ValidationResult.errors.size() == 2` reports both correctly.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `records` | [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm) | The list of records (Trigger.new) |
| `results` | [SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm) | The validation results |

**Example**

```apex
UTIL_ValidationRule.applyErrors(records, new List<ValidationResult>());
```

</div>

### bypassGroup

<div class="apex-member">

```apex
global static void bypassGroup(String groupDeveloperName)
```

Bypasses all validation rules in the specified group.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `groupDeveloperName` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The DeveloperName of the ValidationRuleGroup__mdt to bypass |

**Example**

```apex
UTIL_ValidationRule.bypassGroup('SalesCloud_Account_Validations');
```

</div>

### bypassObject

<div class="apex-member">

```apex
global static void bypassObject(String objectApiName)
```

Bypasses all validation rules for the specified object.
This is the highest level of bypass and takes precedence over group and rule bypasses.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `objectApiName` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The API name of the object to bypass (e.g., 'Account') |

**Example**

```apex
UTIL_ValidationRule.bypassObject('Account');
try
{
    insert accounts; // No validation rules fire
}
finally
{
    UTIL_ValidationRule.clearBypass('Account');
}
```

</div>

### bypassRule

<div class="apex-member">

```apex
global static void bypassRule(String ruleDeveloperName)
```

Bypasses a specific validation rule.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `ruleDeveloperName` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The DeveloperName of the ValidationRule__mdt to bypass |

**Example**

```apex
UTIL_ValidationRule.bypassRule('Account_Requires_Primary_Contact');
```

</div>

### clearAllBypasses

<div class="apex-member">

```apex
global static void clearAllBypasses()
```

Clears all bypasses for the current transaction.

**Example**

```apex
UTIL_ValidationRule.clearAllBypasses();
```

</div>

### clearBypass

<div class="apex-member">

```apex
global static void clearBypass(String identifier)
```

Clears a specific bypass (object, group, or rule). For each bypass type the
identifier was actually registered under, emits a `validation` `CLEAR` audit entry carrying the
matching prefixed target (`object:`/`group:`/`rule:`) so the clear correlates to its originating
bypass. An identifier that is not currently bypassed removes nothing and emits nothing.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `identifier` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The object API name, group DeveloperName, or rule DeveloperName to clear |

**Example**

```apex
UTIL_ValidationRule.clearBypass('Account');
```

</div>

### executeForTrigger

<div class="apex-member">

```apex
global static void executeForTrigger(List<SObject> newRecords, List<SObject> oldRecords, TriggerOperation operation)
```

Executes validation rules for the current trigger context.
This is the main entry point for trigger-based validation.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `newRecords` | [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm) | The list of new records (Trigger.new) |
| `oldRecords` | [SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm) | The list of old records (Trigger.old), may be null for insert |
| `operation` | [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm) | The trigger operation |

**Example**

```apex
// In a trigger action class
UTIL_ValidationRule.executeForTrigger(newRecords, oldRecords, TriggerOperation.BEFORE_UPDATE);
```

</div>

### isBypassed

<div class="apex-member">

```apex
global static Boolean isBypassed(String identifier)
```

Checks if a specific bypass is currently active.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `identifier` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The object API name, group DeveloperName, or rule DeveloperName |

**Returns** [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) — True if bypassed

**Example**

```apex
Boolean result = UTIL_ValidationRule.isBypassed('value');
```

</div>

### validate

<div class="apex-member">

```apex
global static List<UTIL_ValidationRule.ValidationResult> validate(List<SObject> newRecords, List<SObject> oldRecords, TriggerOperation operation)
```

Validates a list of records against all applicable validation rules.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `newRecords` | [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm) | The list of new records to validate |
| `oldRecords` | [SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm) | The list of old records (may be null for insert) |
| `operation` | [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm) | The trigger operation determining which rules apply |

**Returns** [UTIL_ValidationRule.ValidationResult](UTIL_ValidationRule.ValidationResult.md) — List of ValidationResult objects, one per record

**Example**

```apex
List<ValidationResult> result = UTIL_ValidationRule.validate(records, records, TriggerOperation.BEFORE_INSERT);
```

</div>

