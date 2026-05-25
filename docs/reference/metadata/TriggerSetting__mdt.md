---
title: "TriggerSetting__mdt"
type: sobject
description: "Parent configuration for all trigger actions on a single object. Links to an EntityDefinition to identify the SObject, and provides object-level bypass, permission gating, and performance logging cont"
category: metadata
---

# TriggerSetting__mdt

**Sobject**

```apex
global class TriggerSetting__mdt extends SObject
```

**Extends:** [SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm)

Parent configuration for all trigger actions on a single object. Links to an EntityDefinition to identify the SObject, and provides object-level bypass, permission gating, and performance logging controls that cascade to every child Trigger Action record.

---

## Fields

| Field | Description |
|-------|-------------|
| global [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) [ApplyMasking__c](#applymasking__c) | When checked, the trigger dispatcher calls the data masking framework on every before-insert and before-update for this object before any configured TriggerAction handlers run. |
| global [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) [BypassExecution__c](#bypassexecution__c) | When checked, ALL trigger actions for this object are completely skipped. |
| global [Id](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_id.htm) [BypassFeatureFlag__c](#bypassfeatureflag__c) | Optional. |
| global [FeatureFlag__mdt](../metadata/FeatureFlag__mdt.md) [BypassFeatureFlag__r](#bypassfeatureflag__r) | Optional. |
| global [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) [EnablePerformanceLogging__c](#enableperformancelogging__c) | Master switch for performance logging on this object. |
| global [Decimal](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_decimal.htm) [PerformanceThresholdMs__c](#performancethresholdms__c) | Object-level performance threshold in milliseconds. |
| global [Id](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_id.htm) [RequiredFeatureFlag__c](#requiredfeatureflag__c) | Optional. |
| global [FeatureFlag__mdt](../metadata/FeatureFlag__mdt.md) [RequiredFeatureFlag__r](#requiredfeatureflag__r) | Optional. |
| global [Id](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_id.htm) [SObjectType__c](#sobjecttype__c) | EntityDefinition relationship that identifies which SObject this trigger setting governs. |
| global [EntityDefinition](https://developer.salesforce.com/docs/atlas.en-us.object_reference.meta/object_reference/sforce_api_objects_entitydefinition.htm) [SObjectType__r](#sobjecttype__r) | EntityDefinition relationship that identifies which SObject this trigger setting governs. |
| global [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm) [TriggerActions__r](#triggeractions__r) | Reciprocal relationship for TriggerAction__mdt.TriggerSetting__c. |
| global [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm) [ValidationRuleGroups__r](#validationrulegroups__r) | Reciprocal relationship for ValidationRuleGroup__mdt.TriggerSetting__c. |

---

## Field Details

### ApplyMasking__c

```apex
global Boolean ApplyMasking__c
```

When checked, the trigger dispatcher calls the data masking framework on every before-insert and before-update for this object before any configured TriggerAction handlers run. Only fires when the MaskingFramework_Enabled feature flag is on. Defaults to true so objects with a TriggerSetting are masked automatically; uncheck to opt this one object out.

**Field Attributes:**

| Attribute | Value |
|-----------|-------|
| Data Type | Checkbox |
| Default Value | true |

### BypassExecution__c

```apex
global Boolean BypassExecution__c
```

When checked, ALL trigger actions for this object are completely skipped. This is an object-level kill switch that overrides individual action settings. Unlike permission-based bypasses, this applies unconditionally to all users.

**Field Attributes:**

| Attribute | Value |
|-----------|-------|
| Data Type | Checkbox |
| Default Value | false |

### BypassFeatureFlag__c

```apex
global Id BypassFeatureFlag__c
```

Optional. ALL trigger actions for this object are SKIPPED when the Feature Flag is enabled.

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

Optional. ALL trigger actions for this object are SKIPPED when the Feature Flag is enabled.

**Field Attributes:**

| Attribute | Value |
|-----------|-------|
| Data Type | FeatureFlag__mdt |
| Required | false |
| Unique | false |

### EnablePerformanceLogging__c

```apex
global Boolean EnablePerformanceLogging__c
```

Master switch for performance logging on this object. When enabled, execution times are tracked for all child trigger actions and logged when they exceed the threshold. Individual actions can override via Suppress Performance Logging or Force Performance Logging.

**Field Attributes:**

| Attribute | Value |
|-----------|-------|
| Data Type | Checkbox |
| Default Value | true |

### PerformanceThresholdMs__c

```apex
global Decimal PerformanceThresholdMs__c
```

Object-level performance threshold in milliseconds. Actions on this object are logged when their execution time exceeds this value. Overrides the global threshold. Individual actions can further override with their own threshold. Leave blank to use the global default.

**Field Attributes:**

| Attribute | Value |
|-----------|-------|
| Data Type | Number(8,0) |
| Required | false |
| Unique | false |
| External ID | false |

### RequiredFeatureFlag__c

```apex
global Id RequiredFeatureFlag__c
```

Optional. ALL trigger actions for this object ONLY RUN when the Feature Flag is enabled.

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

Optional. ALL trigger actions for this object ONLY RUN when the Feature Flag is enabled.

**Field Attributes:**

| Attribute | Value |
|-----------|-------|
| Data Type | FeatureFlag__mdt |
| Required | false |
| Unique | false |

### SObjectType__c

```apex
global Id SObjectType__c
```

EntityDefinition relationship that identifies which SObject this trigger setting governs. Validated by the platform — only real objects can be selected, preventing misconfiguration from typos or deleted objects.

**Field Attributes:**

| Attribute | Value |
|-----------|-------|
| Data Type | EntityDefinition |
| Required | true |
| Unique | false |

### SObjectType__r

```apex
global EntityDefinition SObjectType__r
```

EntityDefinition relationship that identifies which SObject this trigger setting governs. Validated by the platform — only real objects can be selected, preventing misconfiguration from typos or deleted objects.

**Field Attributes:**

| Attribute | Value |
|-----------|-------|
| Data Type | EntityDefinition |
| Required | true |
| Unique | false |

### TriggerActions__r

```apex
global List<TriggerAction__mdt> TriggerActions__r
```

Reciprocal relationship for **`TriggerAction__mdt.TriggerSetting__c`** .

### ValidationRuleGroups__r

```apex
global List<ValidationRuleGroup__mdt> ValidationRuleGroups__r
```

Reciprocal relationship for **`ValidationRuleGroup__mdt.TriggerSetting__c`** .

