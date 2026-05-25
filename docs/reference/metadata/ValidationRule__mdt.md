---
title: "ValidationRule__mdt"
type: sobject
description: "Defines an individual validation rule with a formula-based condition, error message, and configuration options. Rules are grouped by ValidationRuleGroup__mdt and evaluated during trigger execution."
category: metadata
---

# ValidationRule__mdt

**Sobject**

```apex
global class ValidationRule__mdt extends SObject
```

**Extends:** [SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm)

Defines an individual validation rule with a formula-based condition, error message, and configuration options. Rules are grouped by ValidationRuleGroup__mdt and evaluated during trigger execution.

---

## Fields

| Field | Description |
|-------|-------------|
| global [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) [BypassExecution__c](#bypassexecution__c) | When checked, this individual validation rule is completely skipped during trigger execution. |
| global [Id](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_id.htm) [BypassFeatureFlag__c](#bypassfeatureflag__c) | Optional. |
| global [FeatureFlag__mdt](../metadata/FeatureFlag__mdt.md) [BypassFeatureFlag__r](#bypassfeatureflag__r) | Optional. |
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [ContextClassName__c](#contextclassname__c) | Overrides the group-level context class for this specific rule. |
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [Description__c](#description__c) | Detailed description of what this validation rule checks. |
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [ErrorDisplayField__c](#errordisplayfield__c) | Optional. |
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [ErrorMessage__c](#errormessage__c) | The error message displayed when validation fails. |
| global [Decimal](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_decimal.htm) [Order__c](#order__c) | Execution order relative to other rules in the same group. |
| global [Id](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_id.htm) [RequiredFeatureFlag__c](#requiredfeatureflag__c) | Optional. |
| global [FeatureFlag__mdt](../metadata/FeatureFlag__mdt.md) [RequiredFeatureFlag__r](#requiredfeatureflag__r) | Optional. |
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [RuleFormula__c](#ruleformula__c) | Boolean formula that defines when validation FAILS. |
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [Severity__c](#severity__c) | Determines what happens when the rule formula evaluates to TRUE. |
| global [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) [ShadowMode__c](#shadowmode__c) | When enabled, rule violations are logged with [SHADOW] tag but do not block save, regardless of Severity setting. |
| global [Id](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_id.htm) [ValidationRuleGroup__c](#validationrulegroup__c) | Links this rule to a validation rule group. |
| global [ValidationRuleGroup__mdt](../metadata/ValidationRuleGroup__mdt.md) [ValidationRuleGroup__r](#validationrulegroup__r) | Links this rule to a validation rule group. |

---

## Field Details

### BypassExecution__c

```apex
global Boolean BypassExecution__c
```

When checked, this individual validation rule is completely skipped during trigger execution. Unlike permission-based bypasses, this is an unconditional kill switch that applies to all users regardless of permissions or context.

**Field Attributes:**

| Attribute | Value |
|-----------|-------|
| Data Type | Checkbox |
| Default Value | false |

### BypassFeatureFlag__c

```apex
global Id BypassFeatureFlag__c
```

Optional. This rule is SKIPPED when the Feature Flag is enabled.

**Field Attributes:**

| Attribute | Value |
|-----------|-------|
| Data Type | FeatureFlag__mdt |
| Required | false |
| Unique | false |

### BypassFeatureFlag__r

```apex
global FeatureFlag__mdt BypassFeatureFlag__r
```

Optional. This rule is SKIPPED when the Feature Flag is enabled.

**Field Attributes:**

| Attribute | Value |
|-----------|-------|
| Data Type | FeatureFlag__mdt |
| Required | false |
| Unique | false |

### ContextClassName__c

```apex
global String ContextClassName__c
```

Overrides the group-level context class for this specific rule. Specifies the Apex class providing context for formula evaluation. For standard objects, leave blank to inherit from the group or use built-in contexts.

**Field Attributes:**

| Attribute | Value |
|-----------|-------|
| Data Type | Text(100) |
| Required | false |
| Unique | false |
| External ID | false |

### Description__c

```apex
global String Description__c
```

Detailed description of what this validation rule checks. Should explain the business requirement and when this rule would fail. Reference any relevant policy documents or requirements.

**Field Attributes:**

| Attribute | Value |
|-----------|-------|
| Data Type | Long Text Area(32768) |

### ErrorDisplayField__c

```apex
global String ErrorDisplayField__c
```

Optional. API name of the field where the error message should be displayed. If blank, the error appears as a page-level error. Use field API names without the object prefix (e.g., "Status__c" not "Account.Status__c").

**Field Attributes:**

| Attribute | Value |
|-----------|-------|
| Data Type | Text(255) |
| Required | false |
| Unique | false |
| External ID | false |

### ErrorMessage__c

```apex
global String ErrorMessage__c
```

The error message displayed when validation fails. Supports merge fields using {!FieldName} syntax referencing context class properties. Use Custom Labels with {$Label.LabelName} for internationalization.

**Field Attributes:**

| Attribute | Value |
|-----------|-------|
| Data Type | Long Text Area(4000) |

### Order__c

```apex
global Decimal Order__c
```

Execution order relative to other rules in the same group. Lower numbers execute first. Use gaps like 10, 20, 30 for easy insertion of new rules.

**Field Attributes:**

| Attribute | Value |
|-----------|-------|
| Data Type | Number(4,0) |
| Required | true |
| Unique | false |
| External ID | false |
| Default Value | 10 |

### RequiredFeatureFlag__c

```apex
global Id RequiredFeatureFlag__c
```

Optional. This rule ONLY RUNS when the Feature Flag is enabled.

**Field Attributes:**

| Attribute | Value |
|-----------|-------|
| Data Type | FeatureFlag__mdt |
| Required | false |
| Unique | false |

### RequiredFeatureFlag__r

```apex
global FeatureFlag__mdt RequiredFeatureFlag__r
```

Optional. This rule ONLY RUNS when the Feature Flag is enabled.

**Field Attributes:**

| Attribute | Value |
|-----------|-------|
| Data Type | FeatureFlag__mdt |
| Required | false |
| Unique | false |

### RuleFormula__c

```apex
global String RuleFormula__c
```

Boolean formula that defines when validation FAILS. If this formula evaluates to TRUE, the validation error is shown. Uses Salesforce FormulaEval syntax with access to oldRecord, newRecord, and context class properties. Supports standard formula functions and global variables ($User, $Permission, $Profile, $Label).

**Field Attributes:**

| Attribute | Value |
|-----------|-------|
| Data Type | Long Text Area(32768) |

### Severity__c

```apex
global String Severity__c
```

Determines what happens when the rule formula evaluates to TRUE. Error: Blocks the save and shows the error message. Warning: Allows save but logs the violation to LogEntry__c.

**Field Attributes:**

| Attribute | Value |
|-----------|-------|
| Data Type | Picklist |
| Required | true |

**Picklist Values:**

| API Name | Label | Active |
|----------|-------|--------|
| `Error` | Error | Yes |
| `Warning` | Warning | No |

### ShadowMode__c

```apex
global Boolean ShadowMode__c
```

When enabled, rule violations are logged with [SHADOW] tag but do not block save, regardless of Severity setting. Use during initial deployment to monitor impact before enforcement. Logged violations include context data for analysis.

**Field Attributes:**

| Attribute | Value |
|-----------|-------|
| Data Type | Checkbox |
| Default Value | false |

### ValidationRuleGroup__c

```apex
global Id ValidationRuleGroup__c
```

Links this rule to a validation rule group. The group determines which object and trigger contexts this rule applies to.

**Field Attributes:**

| Attribute | Value |
|-----------|-------|
| Data Type | ValidationRuleGroup__mdt |
| Required | true |
| Unique | false |

### ValidationRuleGroup__r

```apex
global ValidationRuleGroup__mdt ValidationRuleGroup__r
```

Links this rule to a validation rule group. The group determines which object and trigger contexts this rule applies to.

**Field Attributes:**

| Attribute | Value |
|-----------|-------|
| Data Type | ValidationRuleGroup__mdt |
| Required | true |
| Unique | false |

