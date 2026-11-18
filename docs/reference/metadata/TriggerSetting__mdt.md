---
title: "TriggerSetting__mdt"
type: sobject
pageClass: reference
description: "Parent configuration for all trigger actions on a single object. Links to an EntityDefinition to identify the SObject, and provides object-level bypass, permission gating, and performance logging cont"
category: metadata
---

# TriggerSetting__mdt

**Sobject**

<div class="apex-member apex-class">

```apex
global class TriggerSetting__mdt extends SObject
```

**Extends:** [SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm)

Parent configuration for all trigger actions on a single object. Links to an EntityDefinition to identify the SObject, and provides object-level bypass, permission gating, and performance logging controls that cascade to every child Trigger Action record.

</div>

---

## Fields

| Field | Description |
|-------|-------------|
| global [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) [ApplyMasking__c](#applymasking__c) | When checked, data masking runs on each insert and update of this object, before its trigger actions. |
| global [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) [BypassExecution__c](#bypassexecution__c) | When checked, ALL trigger actions for this object are completely skipped. |
| global [Id](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_id.htm) [BypassFeatureFlag__c](#bypassfeatureflag__c) | Optional. |
| global [FeatureFlag__mdt](../metadata/FeatureFlag__mdt.md) [BypassFeatureFlag__r](#bypassfeatureflag__r) | Optional. |
| global [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) [EnablePerformanceLogging__c](#enableperformancelogging__c) | Deprecated. |
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [ObjectApiNameOverride__c](#objectapinameoverride__c) | Optional text override for the Object Type relationship above. |
| global [Decimal](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_decimal.htm) [PerformanceThresholdMs__c](#performancethresholdms__c) | Performance threshold in milliseconds for the trigger actions and post-trigger actions registered under this trigger setting. |
| global [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[PostTriggerAction__mdt](../metadata/PostTriggerAction__mdt.md)> [PostTriggerActions__r](#posttriggeractions__r) | Reciprocal relationship for PostTriggerAction__mdt.TriggerSetting__c. |
| global [Id](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_id.htm) [RequiredFeatureFlag__c](#requiredfeatureflag__c) | Optional. |
| global [FeatureFlag__mdt](../metadata/FeatureFlag__mdt.md) [RequiredFeatureFlag__r](#requiredfeatureflag__r) | Optional. |
| global [Id](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_id.htm) [SObjectType__c](#sobjecttype__c) | EntityDefinition relationship that identifies which SObject this trigger setting governs. |
| global [EntityDefinition](https://developer.salesforce.com/docs/atlas.en-us.object_reference.meta/object_reference/sforce_api_objects_entitydefinition.htm) [SObjectType__r](#sobjecttype__r) | EntityDefinition relationship that identifies which SObject this trigger setting governs. |
| global [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[TriggerAction__mdt](../metadata/TriggerAction__mdt.md)> [TriggerActions__r](#triggeractions__r) | Reciprocal relationship for TriggerAction__mdt.TriggerSetting__c. |
| global [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[ValidationRuleGroup__mdt](../metadata/ValidationRuleGroup__mdt.md)> [ValidationRuleGroups__r](#validationrulegroups__r) | Reciprocal relationship for ValidationRuleGroup__mdt.TriggerSetting__c. |

### ApplyMasking__c

```apex
global Boolean ApplyMasking__c
```

When checked, data masking runs on each insert and update of this object, before its trigger actions. Needs the MaskingFramework_Enabled flag. Checked by default. With two or more settings for one object, masking is skipped only if all are unchecked.

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

Deprecated. This checkbox has no effect. To control slow-action logging for the actions registered under this trigger setting, use Performance Threshold (ms) on this trigger setting. Leave it blank to follow Log Setting. Set a number to log every run that takes that many milliseconds or longer, even when Enable Trigger Performance Logging is off in Log Setting. Set a very high number to stop those entries.

**Field Attributes:**

| Attribute | Value |
|-----------|-------|
| Data Type | Checkbox |
| Default Value | true |

### ObjectApiNameOverride__c

```apex
global String ObjectApiNameOverride__c
```

Optional text override for the Object Type relationship above. When populated, this value is used as the SObject API name at dispatch time instead of the relationship. Primary use case is Change Data Capture entities (e.g. AccountChangeEvent, Foobar__ChangeEvent), which the platform excludes from the relationship's picklist filter. For CDC rows, populate the Object Type relationship with the source SObject (e.g. Foobar__c) for admin documentation, and this field with the Change Event API name (e.g. Foobar__ChangeEvent). Leave blank for standard objects, custom objects, and platform events — the relationship covers those directly.

**Field Attributes:**

| Attribute | Value |
|-----------|-------|
| Data Type | Text(255) |
| Required | false |
| Unique | false |
| External ID | false |

### PerformanceThresholdMs__c

```apex
global Decimal PerformanceThresholdMs__c
```

Performance threshold in milliseconds for the trigger actions and post-trigger actions registered under this trigger setting. Blank: those actions follow Log Setting (Enable Trigger Performance Logging and Trigger Performance Threshold (ms)). A number: a run that takes that long or longer is logged, even when Enable Trigger Performance Logging is off in Log Setting. 0 logs every run. A very high number stops those entries. An action's own threshold, Force Performance Logging and Suppress Performance Logging win over this value. It applies only to the actions registered under this trigger setting, not to other trigger settings for the same object.

**Field Attributes:**

| Attribute | Value |
|-----------|-------|
| Data Type | Number(8,0) |
| Required | false |
| Unique | false |
| External ID | false |

### PostTriggerActions__r

```apex
global List<PostTriggerAction__mdt> PostTriggerActions__r
```

Reciprocal relationship for **`PostTriggerAction__mdt.TriggerSetting__c`** .

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

EntityDefinition relationship that identifies which SObject this trigger setting governs. Validated by the platform — only real objects can be selected, preventing misconfiguration from typos or deleted objects. Optional when Object API Name Override is populated (the platform's restricted-picklist filter excludes Change Data Capture entities from this relationship; CDC rows use the override instead). A validation rule enforces that at least one of the two is populated.

**Field Attributes:**

| Attribute | Value |
|-----------|-------|
| Data Type | EntityDefinition |
| Required | false |
| Unique | false |

### SObjectType__r

```apex
global EntityDefinition SObjectType__r
```

EntityDefinition relationship that identifies which SObject this trigger setting governs. Validated by the platform — only real objects can be selected, preventing misconfiguration from typos or deleted objects. Optional when Object API Name Override is populated (the platform's restricted-picklist filter excludes Change Data Capture entities from this relationship; CDC rows use the override instead). A validation rule enforces that at least one of the two is populated.

**Field Attributes:**

| Attribute | Value |
|-----------|-------|
| Data Type | EntityDefinition |
| Required | false |
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

