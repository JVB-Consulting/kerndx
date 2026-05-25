---
title: "FeatureFlag__mdt"
type: sobject
description: "This object is the master record for a single feature flag. It acts as the parent and defines the feature's name, its master on/off switch, and its final fallback behavior."
category: metadata
---

# FeatureFlag__mdt

**Sobject**

```apex
global class FeatureFlag__mdt extends SObject
```

**Extends:** [SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm)

This object is the master record for a single feature flag. It acts as the parent and defines the feature's name, its master on/off switch, and its final fallback behavior.

---

## Fields

| Field | Description |
|-------|-------------|
| global [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm) [BypassApiSettings__r](#bypassapisettings__r) | Reciprocal relationship for ApiSetting__mdt.BypassFeatureFlag__c. |
| global [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm) [BypassTriggerActions__r](#bypasstriggeractions__r) | Reciprocal relationship for TriggerAction__mdt.BypassFeatureFlag__c. |
| global [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm) [BypassTriggerSettings__r](#bypasstriggersettings__r) | Reciprocal relationship for TriggerSetting__mdt.BypassFeatureFlag__c. |
| global [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm) [BypassValidationRuleGroups__r](#bypassvalidationrulegroups__r) | Reciprocal relationship for ValidationRuleGroup__mdt.BypassFeatureFlag__c. |
| global [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm) [BypassValidationRules__r](#bypassvalidationrules__r) | Reciprocal relationship for ValidationRule__mdt.BypassFeatureFlag__c. |
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [Description__c](#description__c) | A description of the feature flag and what it's being used for |
| global [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm) [FeatureFlagStrategies__r](#featureflagstrategies__r) | Reciprocal relationship for FeatureFlagStrategy__mdt.FeatureFlag__c. |
| global [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) [IsActive__c](#isactive__c) | A master on/off switch. |
| global [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) [IsEnabledByDefault__c](#isenabledbydefault__c) | The default value for the flag if no strategies are defined. |
| global [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm) [RequiredApiSettings__r](#requiredapisettings__r) | Reciprocal relationship for ApiSetting__mdt.RequiredFeatureFlag__c. |
| global [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm) [RequiredTriggerActions__r](#requiredtriggeractions__r) | Reciprocal relationship for TriggerAction__mdt.RequiredFeatureFlag__c. |
| global [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm) [RequiredTriggerSettings__r](#requiredtriggersettings__r) | Reciprocal relationship for TriggerSetting__mdt.RequiredFeatureFlag__c. |
| global [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm) [RequiredValidationRuleGroups__r](#requiredvalidationrulegroups__r) | Reciprocal relationship for ValidationRuleGroup__mdt.RequiredFeatureFlag__c. |
| global [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm) [RequiredValidationRules__r](#requiredvalidationrules__r) | Reciprocal relationship for ValidationRule__mdt.RequiredFeatureFlag__c. |
| global [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) [ResultOnNoMatch__c](#resultonnomatch__c) | The fallback result to use if strategies exist, but none of them return true. |

---

## Field Details

### BypassApiSettings__r

```apex
global List<ApiSetting__mdt> BypassApiSettings__r
```

Reciprocal relationship for **`ApiSetting__mdt.BypassFeatureFlag__c`** .

### BypassTriggerActions__r

```apex
global List<TriggerAction__mdt> BypassTriggerActions__r
```

Reciprocal relationship for **`TriggerAction__mdt.BypassFeatureFlag__c`** .

### BypassTriggerSettings__r

```apex
global List<TriggerSetting__mdt> BypassTriggerSettings__r
```

Reciprocal relationship for **`TriggerSetting__mdt.BypassFeatureFlag__c`** .

### BypassValidationRuleGroups__r

```apex
global List<ValidationRuleGroup__mdt> BypassValidationRuleGroups__r
```

Reciprocal relationship for **`ValidationRuleGroup__mdt.BypassFeatureFlag__c`** .

### BypassValidationRules__r

```apex
global List<ValidationRule__mdt> BypassValidationRules__r
```

Reciprocal relationship for **`ValidationRule__mdt.BypassFeatureFlag__c`** .

### Description__c

```apex
global String Description__c
```

A description of the feature flag and what it's being used for

**Field Attributes:**

| Attribute | Value |
|-----------|-------|
| Data Type | Text Area |
| Required | false |

### FeatureFlagStrategies__r

```apex
global List<FeatureFlagStrategy__mdt> FeatureFlagStrategies__r
```

Reciprocal relationship for **`FeatureFlagStrategy__mdt.FeatureFlag__c`** .

### IsActive__c

```apex
global Boolean IsActive__c
```

A master on/off switch. If false, the feature is disabled for everyone, and child strategies are not evaluated.

**Field Attributes:**

| Attribute | Value |
|-----------|-------|
| Data Type | Checkbox |
| Default Value | false |

### IsEnabledByDefault__c

```apex
global Boolean IsEnabledByDefault__c
```

The default value for the flag if no strategies are defined. If true, the flag is ON by default. If false, it's OFF by default. This field is *only* used when the 'Feature Flag Strategies' related list is empty.

**Field Attributes:**

| Attribute | Value |
|-----------|-------|
| Data Type | Checkbox |
| Default Value | false |

### RequiredApiSettings__r

```apex
global List<ApiSetting__mdt> RequiredApiSettings__r
```

Reciprocal relationship for **`ApiSetting__mdt.RequiredFeatureFlag__c`** .

### RequiredTriggerActions__r

```apex
global List<TriggerAction__mdt> RequiredTriggerActions__r
```

Reciprocal relationship for **`TriggerAction__mdt.RequiredFeatureFlag__c`** .

### RequiredTriggerSettings__r

```apex
global List<TriggerSetting__mdt> RequiredTriggerSettings__r
```

Reciprocal relationship for **`TriggerSetting__mdt.RequiredFeatureFlag__c`** .

### RequiredValidationRuleGroups__r

```apex
global List<ValidationRuleGroup__mdt> RequiredValidationRuleGroups__r
```

Reciprocal relationship for **`ValidationRuleGroup__mdt.RequiredFeatureFlag__c`** .

### RequiredValidationRules__r

```apex
global List<ValidationRule__mdt> RequiredValidationRules__r
```

Reciprocal relationship for **`ValidationRule__mdt.RequiredFeatureFlag__c`** .

### ResultOnNoMatch__c

```apex
global Boolean ResultOnNoMatch__c
```

The fallback result to use if strategies *exist*, but *none* of them return true. If true, the flag is ON. If false (default), the flag is OFF. This field is *only* used if at least one strategy exists and all strategies fail to match.

**Field Attributes:**

| Attribute | Value |
|-----------|-------|
| Data Type | Checkbox |
| Default Value | false |

