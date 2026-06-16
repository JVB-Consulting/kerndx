---
title: "PostTriggerAction__mdt"
type: sobject
pageClass: reference
description: "Registers a single post-trigger action: one Apex class that runs once at the end of a trigger transaction, after all trigger actions on every object have completed. Use for cross-object work that cann"
category: metadata
---

# PostTriggerAction__mdt

**Sobject**

```apex
global class PostTriggerAction__mdt extends SObject
```

**Extends:** [SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm)

Registers a single post-trigger action: one Apex class that runs once at the end of a trigger transaction, after all trigger actions on every object have completed. Use for cross-object work that cannot be done from inside an individual trigger action — aggregate audit emission, asynchronous job enqueue, transaction-scoped telemetry. Post-trigger actions must not perform DML; the dispatcher rethrows if they do.

---

## Fields

| Field | Description |
|-------|-------------|
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [ApexClassName__c](#apexclassname__c) | Fully qualified Apex class implementing IF_Trigger.PostAction. |
| global [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) [BypassExecution__c](#bypassexecution__c) | When checked, this post-trigger action is completely skipped. |
| global [Id](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_id.htm) [BypassFeatureFlag__c](#bypassfeatureflag__c) | Optional. |
| global [FeatureFlag__mdt](../metadata/FeatureFlag__mdt.md) [BypassFeatureFlag__r](#bypassfeatureflag__r) | Optional. |
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [Description__c](#description__c) | Human-readable explanation of what this post-trigger action does and why it exists. |
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [EntryCriteriaContextClassName__c](#entrycriteriacontextclassname__c) | Optional. |
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [FailureAction__c](#failureaction__c) | Controls how this post-trigger action handles unhandled Apex exceptions. |
| global [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) [ForcePerformanceLogging__c](#forceperformancelogging__c) | When checked, execution time is always logged for this post-action regardless of whether it exceeds the threshold. |
| global [Decimal](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_decimal.htm) [Order__c](#order__c) | Determines execution sequence relative to other post-trigger actions in the same transaction. |
| global [Decimal](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_decimal.htm) [PerformanceThresholdMs__c](#performancethresholdms__c) | Optional. |
| global [Id](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_id.htm) [RequiredFeatureFlag__c](#requiredfeatureflag__c) | Optional. |
| global [FeatureFlag__mdt](../metadata/FeatureFlag__mdt.md) [RequiredFeatureFlag__r](#requiredfeatureflag__r) | Optional. |
| global [Id](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_id.htm) [TriggerSetting__c](#triggersetting__c) | Optional. |
| global [TriggerSetting__mdt](../metadata/TriggerSetting__mdt.md) [TriggerSetting__r](#triggersetting__r) | Optional. |

---

## Field Details

### ApexClassName__c

```apex
global String ApexClassName__c
```

Fully qualified Apex class implementing IF_Trigger.PostAction. Runs once after all trigger actions complete, for cross-object/transaction-level work (audit aggregation, async enqueue, telemetry). DML is not permitted inside a post-trigger action.

**Field Attributes:**

| Attribute | Value |
|-----------|-------|
| Data Type | Text(100) |
| Required | false |
| Unique | false |
| External ID | false |

### BypassExecution__c

```apex
global Boolean BypassExecution__c
```

When checked, this post-trigger action is completely skipped. Unlike permission-based bypasses, this is an unconditional kill switch that applies to all users regardless of permissions or context.

**Field Attributes:**

| Attribute | Value |
|-----------|-------|
| Data Type | Checkbox |
| Default Value | false |

### BypassFeatureFlag__c

```apex
global Id BypassFeatureFlag__c
```

Optional. This post-trigger action is SKIPPED when the Feature Flag is enabled.

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

Optional. This post-trigger action is SKIPPED when the Feature Flag is enabled.

**Field Attributes:**

| Attribute | Value |
|-----------|-------|
| Data Type | FeatureFlag__mdt |
| Required | false |
| Unique | false |

### Description__c

```apex
global String Description__c
```

Human-readable explanation of what this post-trigger action does and why it exists. Document the post-action's purpose so future maintainers understand its role in the transaction.

**Field Attributes:**

| Attribute | Value |
|-----------|-------|
| Data Type | Text(255) |
| Required | false |
| Unique | false |
| External ID | false |

### EntryCriteriaContextClassName__c

```apex
global String EntryCriteriaContextClassName__c
```

Optional. Apex class implementing IF_Trigger.PostActionEntryCriteria. When set, the framework consults the evaluator's shouldRun(context) method before invoking the post-action. Returning false skips this row; returning true proceeds to execution. Use for context-level gating (e.g. "only run when Account records were touched AND feature flag X is enabled"). Leave blank to run unconditionally subject to feature-flag and Trigger Setting filters. Unlike the field of the same name on Trigger Action, this is the evaluator itself, not a context provider for a formula.

**Field Attributes:**

| Attribute | Value |
|-----------|-------|
| Data Type | Text(100) |
| Required | false |
| Unique | false |
| External ID | false |

### FailureAction__c

```apex
global String FailureAction__c
```

Controls how this post-trigger action handles unhandled Apex exceptions. Log and Continue (default) records the error in the audit log and lets the transaction proceed — recommended for non-critical post-actions like notifications, async enqueues, or supplemental telemetry. Block DML stops the save and surfaces the action's error message back to the user — recommended only when the post-action must be guaranteed to complete before any data is committed. Governor exceptions (CPU limit, SOQL limit, etc.) always propagate regardless of this setting. A post-trigger action that performs DML always fails the transaction, regardless of this setting, because DML is contractually prohibited inside post-trigger actions.

**Field Attributes:**

| Attribute | Value |
|-----------|-------|
| Data Type | Picklist |
| Required | false |

**Picklist Values:**

| API Name | Label | Active |
|----------|-------|--------|
| `LogAndContinue` | Log and Continue | Yes |
| `BlockDml` | Block DML | No |

### ForcePerformanceLogging__c

```apex
global Boolean ForcePerformanceLogging__c
```

When checked, execution time is always logged for this post-action regardless of whether it exceeds the threshold. Overrides the threshold setting. Useful for diagnosing specific slow post-actions during performance investigations.

**Field Attributes:**

| Attribute | Value |
|-----------|-------|
| Data Type | Checkbox |
| Default Value | false |

### Order__c

```apex
global Decimal Order__c
```

Determines execution sequence relative to other post-trigger actions in the same transaction. Lower numbers execute first. Actions sharing the same order value have no guaranteed sequence. Subscriber-controlled to allow reordering without package upgrades.

**Field Attributes:**

| Attribute | Value |
|-----------|-------|
| Data Type | Number(3,0) |
| Required | false |
| Unique | false |
| External ID | false |

### PerformanceThresholdMs__c

```apex
global Decimal PerformanceThresholdMs__c
```

Optional. Post-action-level performance threshold in milliseconds. When set, the post-action is logged if its execution time exceeds this value. Overrides the global default. Leave blank to inherit from the global Log Setting default. Post-actions can do arbitrary work (aggregate SOQL, computed audit, telemetry roll-ups) so per-row thresholds let admins tune alerting per action.

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

Optional. This post-trigger action ONLY RUNS when the Feature Flag is enabled.

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

Optional. This post-trigger action ONLY RUNS when the Feature Flag is enabled.

**Field Attributes:**

| Attribute | Value |
|-----------|-------|
| Data Type | FeatureFlag__mdt |
| Required | false |
| Unique | false |

### TriggerSetting__c

```apex
global Id TriggerSetting__c
```

Optional. When set, this post-trigger action runs only when the parent Trigger Setting's SObject participated in the transaction (i.e. at least one trigger on that SObject fired during this outermost dispatch). Leave blank to fire on every outermost dispatch regardless of which SObjects were touched, for cross-object or transaction-scoped work (audit aggregation, async enqueue, transaction-wide telemetry).

**Field Attributes:**

| Attribute | Value |
|-----------|-------|
| Data Type | TriggerSetting__mdt |
| Required | false |
| Unique | false |

### TriggerSetting__r

```apex
global TriggerSetting__mdt TriggerSetting__r
```

Optional. When set, this post-trigger action runs only when the parent Trigger Setting's SObject participated in the transaction (i.e. at least one trigger on that SObject fired during this outermost dispatch). Leave blank to fire on every outermost dispatch regardless of which SObjects were touched, for cross-object or transaction-scoped work (audit aggregation, async enqueue, transaction-wide telemetry).

**Field Attributes:**

| Attribute | Value |
|-----------|-------|
| Data Type | TriggerSetting__mdt |
| Required | false |
| Unique | false |

