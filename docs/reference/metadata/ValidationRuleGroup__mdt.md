---
title: "ValidationRuleGroup__mdt"
type: sobject
pageClass: reference
description: "Groups validation rules for a specific object and trigger context. Binds to a TriggerSetting and defines when validation rules in this group should execute (timing and operations). Enables application"
category: metadata
---

# ValidationRuleGroup__mdt

**Sobject**

<div class="apex-member apex-class">

```apex
global class ValidationRuleGroup__mdt extends SObject
```

**Extends:** [SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm)

Groups validation rules for a specific object and trigger context. Binds to a TriggerSetting and defines when validation rules in this group should execute (timing and operations). Enables application/domain segmentation of validation logic.

</div>

---

## Fields

| Field | Description |
|-------|-------------|
| global [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) [BypassExecution__c](#bypassexecution__c) | When checked, ALL validation rules in this group are completely skipped during trigger execution. |
| global [Id](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_id.htm) [BypassFeatureFlag__c](#bypassfeatureflag__c) | Optional. |
| global [FeatureFlag__mdt](../metadata/FeatureFlag__mdt.md) [BypassFeatureFlag__r](#bypassfeatureflag__r) | Optional. |
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [ContextClassName__c](#contextclassname__c) | Specifies the default Apex class providing context for formula evaluation for all rules in this group. |
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [Description__c](#description__c) | Brief description of what this validation rule group validates. |
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [ExecutionStrategy__c](#executionstrategy__c) | Controls how validation rules execute within this group. |
| global [Id](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_id.htm) [RequiredFeatureFlag__c](#requiredfeatureflag__c) | Optional. |
| global [FeatureFlag__mdt](../metadata/FeatureFlag__mdt.md) [RequiredFeatureFlag__r](#requiredfeatureflag__r) | Optional. |
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [TriggerOperations__c](#triggeroperations__c) | Semicolon-separated list of DML operations when rules in this group should run. |
| global [Id](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_id.htm) [TriggerSetting__c](#triggersetting__c) | Links this validation rule group to a specific object via TriggerSetting. |
| global [TriggerSetting__mdt](../metadata/TriggerSetting__mdt.md) [TriggerSetting__r](#triggersetting__r) | Links this validation rule group to a specific object via TriggerSetting. |
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [TriggerTiming__c](#triggertiming__c) | Semicolon-separated list of when rules in this group should run. |
| global [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[ValidationRule__mdt](../metadata/ValidationRule__mdt.md)> [ValidationRules__r](#validationrules__r) | Reciprocal relationship for ValidationRule__mdt.ValidationRuleGroup__c. |

### BypassExecution__c

```apex
global Boolean BypassExecution__c
```

When checked, ALL validation rules in this group are completely skipped during trigger execution. This is a group-level kill switch that overrides individual rule settings. Applies unconditionally to all users.

**Field Attributes:**

| Attribute | Value |
|-----------|-------|
| Data Type | Checkbox |
| Default Value | false |

### BypassFeatureFlag__c

```apex
global Id BypassFeatureFlag__c
```

Optional. All validation rules in this group are SKIPPED when the Feature Flag is enabled.

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

Optional. All validation rules in this group are SKIPPED when the Feature Flag is enabled.

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

Specifies the default Apex class providing context for formula evaluation for all rules in this group. For standard objects (Account, Contact, Lead, Opportunity, Case, Campaign, Task, Event, User), leave blank to use built-in context classes. Can be overridden at the individual rule level.

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

Brief description of what this validation rule group validates. Documents the business purpose and scope.

**Field Attributes:**

| Attribute | Value |
|-----------|-------|
| Data Type | Long Text Area(32768) |

### ExecutionStrategy__c

```apex
global String ExecutionStrategy__c
```

Controls how validation rules execute within this group. Accumulate (default): Run all rules and collect all errors. Fail Fast: Stop processing remaining rules for a record after the first error is found.

**Field Attributes:**

| Attribute | Value |
|-----------|-------|
| Data Type | Picklist |
| Required | false |
| Default Value | 'Accumulate' |

**Picklist Values:**

| API Name | Label | Active |
|----------|-------|--------|
| `Accumulate` | Accumulate | Yes |
| `Fail Fast` | Fail Fast | No |

### RequiredFeatureFlag__c

```apex
global Id RequiredFeatureFlag__c
```

Optional. All validation rules in this group ONLY RUN when the Feature Flag is enabled.

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

Optional. All validation rules in this group ONLY RUN when the Feature Flag is enabled.

**Field Attributes:**

| Attribute | Value |
|-----------|-------|
| Data Type | FeatureFlag__mdt |
| Required | false |
| Unique | false |

### TriggerOperations__c

```apex
global String TriggerOperations__c
```

Semicolon-separated list of DML operations when rules in this group should run. Valid values: Insert, Update, Delete, Undelete. Combined with Trigger Timing to determine exact trigger contexts (e.g., Before + Insert = BEFORE_INSERT).

**Field Attributes:**

| Attribute | Value |
|-----------|-------|
| Data Type | Text(100) |
| Required | true |
| Unique | false |
| External ID | false |

### TriggerSetting__c

```apex
global Id TriggerSetting__c
```

Links this validation rule group to a specific object via TriggerSetting. All rules in this group will validate records of the object defined in the TriggerSetting.

**Field Attributes:**

| Attribute | Value |
|-----------|-------|
| Data Type | TriggerSetting__mdt |
| Required | true |
| Unique | false |

### TriggerSetting__r

```apex
global TriggerSetting__mdt TriggerSetting__r
```

Links this validation rule group to a specific object via TriggerSetting. All rules in this group will validate records of the object defined in the TriggerSetting.

**Field Attributes:**

| Attribute | Value |
|-----------|-------|
| Data Type | TriggerSetting__mdt |
| Required | true |
| Unique | false |

### TriggerTiming__c

```apex
global String TriggerTiming__c
```

Semicolon-separated list of when rules in this group should run. Valid values: Before, After. Combined with Trigger Operations to determine exact trigger contexts.

**Field Attributes:**

| Attribute | Value |
|-----------|-------|
| Data Type | Text(20) |
| Required | true |
| Unique | false |
| External ID | false |

### ValidationRules__r

```apex
global List<ValidationRule__mdt> ValidationRules__r
```

Reciprocal relationship for **`ValidationRule__mdt.ValidationRuleGroup__c`** .

