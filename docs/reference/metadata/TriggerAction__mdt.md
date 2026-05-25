---
title: "TriggerAction__mdt"
type: sobject
description: "Registers a single trigger action: one Apex class bound to one trigger event (e.g. Before Insert) on one object. Controls execution order, entry criteria, recursion, bypass, and performance logging. E"
category: metadata
---

# TriggerAction__mdt

**Sobject**

```apex
global class TriggerAction__mdt extends SObject
```

**Extends:** [SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm)

Registers a single trigger action: one Apex class bound to one trigger event (e.g. Before Insert) on one object. Controls execution order, entry criteria, recursion, bypass, and performance logging. Each record belongs to a parent Trigger Setting that identifies the object.

---

## Fields

| Field | Description |
|-------|-------------|
| global [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) [AllowNonSelfInitiated__c](#allownonselfinitiated__c) | Controls whether this action runs during cascading triggers (when a different object's trigger causes this object's trigger to fire). |
| global [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) [AllowRecursion__c](#allowrecursion__c) | Controls whether this action can execute more than once in the same transaction. |
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [ApexClassName__c](#apexclassname__c) | Fully qualified Apex class name that implements the trigger action logic. |
| global [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) [BypassExecution__c](#bypassexecution__c) | When checked, this individual trigger action is completely skipped during trigger execution. |
| global [Id](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_id.htm) [BypassFeatureFlag__c](#bypassfeatureflag__c) | Optional. |
| global [FeatureFlag__mdt](../metadata/FeatureFlag__mdt.md) [BypassFeatureFlag__r](#bypassfeatureflag__r) | Optional. |
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [Description__c](#description__c) | Human-readable explanation of what this trigger action does and why it exists. |
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [EntryCriteriaContextClassName__c](#entrycriteriacontextclassname__c) | Apex class that provides context variables (e.g. |
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [EntryCriteriaFormula__c](#entrycriteriaformula__c) | Runtime formula expression evaluated per record using the FormulaEval namespace. |
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [Event__c](#event__c) | The specific trigger event (e.g. |
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [FailureAction__c](#failureaction__c) | Controls how this trigger action handles unhandled errors raised during dispatch — flow runtime faults for flow actions, uncaught Apex exceptions for Apex actions. |
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [FlowName__c](#flowname__c) | API name of the active flow that runs as this trigger action. |
| global [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) [ForcePerformanceLogging__c](#forceperformancelogging__c) | When checked, execution time is always logged for this action regardless of whether it exceeds the threshold. |
| global [Decimal](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_decimal.htm) [Order__c](#order__c) | Determines execution sequence relative to other actions on the same object and event. |
| global [Decimal](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_decimal.htm) [PerformanceThresholdMs__c](#performancethresholdms__c) | Action-level performance threshold in milliseconds. |
| global [Id](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_id.htm) [RequiredFeatureFlag__c](#requiredfeatureflag__c) | Optional. |
| global [FeatureFlag__mdt](../metadata/FeatureFlag__mdt.md) [RequiredFeatureFlag__r](#requiredfeatureflag__r) | Optional. |
| global [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) [SuppressPerformanceLogging__c](#suppressperformancelogging__c) | When checked, performance logging is completely suppressed for this action even if the parent Trigger Setting has logging enabled. |
| global [Id](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_id.htm) [TriggerSetting__c](#triggersetting__c) | Links this action to its parent Trigger Setting, which identifies the SObject the trigger fires on. |
| global [TriggerSetting__mdt](../metadata/TriggerSetting__mdt.md) [TriggerSetting__r](#triggersetting__r) | Links this action to its parent Trigger Setting, which identifies the SObject the trigger fires on. |

---

## Field Details

### AllowNonSelfInitiated__c

```apex
global Boolean AllowNonSelfInitiated__c
```

Controls whether this action runs during cascading triggers (when a different object's trigger causes this object's trigger to fire). When false, the action only runs when the trigger is initiated directly by the originating DML. Defaults to true (cascading allowed).

**Field Attributes:**

| Attribute | Value |
|-----------|-------|
| Data Type | Checkbox |
| Default Value | true |

### AllowRecursion__c

```apex
global Boolean AllowRecursion__c
```

Controls whether this action can execute more than once in the same transaction. When false, the framework tracks execution and skips the action if the same trigger fires again (e.g. an After Update action that updates the same object). Defaults to true (recursion allowed).

**Field Attributes:**

| Attribute | Value |
|-----------|-------|
| Data Type | Checkbox |
| Default Value | true |

### ApexClassName__c

```apex
global String ApexClassName__c
```

Fully qualified Apex class name that implements the trigger action logic. The class must extend TRG_Base and implement the appropriate IF_Trigger interface (e.g. IF_Trigger.BeforeInsert). For managed package classes, include the namespace prefix (e.g. kern.TRG_SetFoobarDefaults). Set this OR Flow Name, never both — deploys that populate both fields or neither are blocked by a validation rule on this object. Leave blank to configure a flow action via Flow Name.

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

When checked, this individual trigger action is completely skipped during trigger execution. Unlike permission-based bypasses, this is an unconditional kill switch that applies to all users regardless of permissions or context.

**Field Attributes:**

| Attribute | Value |
|-----------|-------|
| Data Type | Checkbox |
| Default Value | false |

### BypassFeatureFlag__c

```apex
global Id BypassFeatureFlag__c
```

Optional. This action is SKIPPED when the Feature Flag is enabled.

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

Optional. This action is SKIPPED when the Feature Flag is enabled.

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

Human-readable explanation of what this trigger action does and why it exists. Required by validation rule to ensure every action is documented for maintainability.

**Field Attributes:**

| Attribute | Value |
|-----------|-------|
| Data Type | Long Text Area(32768) |

### EntryCriteriaContextClassName__c

```apex
global String EntryCriteriaContextClassName__c
```

Apex class that provides context variables (e.g. newRecord, oldRecord) for entry criteria formula evaluation. Built-in contexts exist for standard objects (Account, Contact, Lead, Opportunity, Case, Campaign, Task, Event, User) and Foobar__c — leave blank for those. Custom objects require a class implementing the formula context interface.

**Field Attributes:**

| Attribute | Value |
|-----------|-------|
| Data Type | Text(100) |
| Required | false |
| Unique | false |
| External ID | false |

### EntryCriteriaFormula__c

```apex
global String EntryCriteriaFormula__c
```

Runtime formula expression evaluated per record using the FormulaEval namespace. When the formula returns true, the action executes for that record; when false, the record is excluded. Supports field references via context variables (e.g. newRecord.Status). Requires a Context Class Name for custom objects.

**Field Attributes:**

| Attribute | Value |
|-----------|-------|
| Data Type | Long Text Area(32768) |

### Event__c

```apex
global String Event__c
```

The specific trigger event (e.g. Before Insert, After Update) this action responds to. Combined with the Trigger Setting lookup, this determines exactly when the Apex class executes during the trigger lifecycle.

**Field Attributes:**

| Attribute | Value |
|-----------|-------|
| Data Type | Picklist |
| Required | true |

**Picklist Values:**

| API Name | Label | Active |
|----------|-------|--------|
| `Before Insert` | Before Insert | Yes |
| `After Insert` | After Insert | Yes |
| `Before Update` | Before Update | Yes |
| `After Update` | After Update | Yes |
| `Before Delete` | Before Delete | Yes |
| `After Delete` | After Delete | Yes |
| `After Undelete` | After Undelete | Yes |

### FailureAction__c

```apex
global String FailureAction__c
```

Controls how this trigger action handles unhandled errors raised during dispatch — flow runtime faults for flow actions, uncaught Apex exceptions for Apex actions. Log and Continue (default) records the error in the audit log and lets the save proceed — recommended for non-critical actions like notifications, derived field updates, or supplemental logging. Block DML stops the save and surfaces the action's error message back to the user — recommended for validation-style actions where the trigger should reject records that fail the action's checks. Governor exceptions (CPU limit, SOQL limit, etc.) always propagate regardless of this setting. Defaults to Log and Continue.

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

### FlowName__c

```apex
global String FlowName__c
```

API name of the active flow that runs as this trigger action. The flow must be an active auto-launched flow that declares an input/output variable named "record" matching the object on this trigger setting, plus an input-only variable named "recordPrior" for update events. Set this OR Apex Class Name, never both — deploys that populate both fields or neither are blocked by a validation rule on this object. Apex Class Name can be left blank when this is set; the framework runs the flow automatically. Deploys are blocked when the named flow is missing or inactive.

**Field Attributes:**

| Attribute | Value |
|-----------|-------|
| Data Type | Text(80) |
| Required | false |
| Unique | false |
| External ID | false |

### ForcePerformanceLogging__c

```apex
global Boolean ForcePerformanceLogging__c
```

When checked, execution time is always logged for this action regardless of whether it exceeds the threshold. Overrides both the action-level and object-level threshold settings. Useful for monitoring specific actions during performance investigations.

**Field Attributes:**

| Attribute | Value |
|-----------|-------|
| Data Type | Checkbox |
| Default Value | false |

### Order__c

```apex
global Decimal Order__c
```

Determines execution sequence relative to other actions on the same object and event. Lower numbers execute first. Actions sharing the same order value have no guaranteed sequence. Subscriber-controlled to allow reordering without package upgrades.

**Field Attributes:**

| Attribute | Value |
|-----------|-------|
| Data Type | Number(4,0) |
| Required | true |
| Unique | false |
| External ID | false |

### PerformanceThresholdMs__c

```apex
global Decimal PerformanceThresholdMs__c
```

Action-level performance threshold in milliseconds. When set, the action is logged if its execution time exceeds this value. Overrides both the object-level (Trigger Setting) and global thresholds. Leave blank to inherit from the parent Trigger Setting or global default.

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

Optional. This action ONLY RUNS when the Feature Flag is enabled.

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

Optional. This action ONLY RUNS when the Feature Flag is enabled.

**Field Attributes:**

| Attribute | Value |
|-----------|-------|
| Data Type | FeatureFlag__mdt |
| Required | false |
| Unique | false |

### SuppressPerformanceLogging__c

```apex
global Boolean SuppressPerformanceLogging__c
```

When checked, performance logging is completely suppressed for this action even if the parent Trigger Setting has logging enabled. Use this for lightweight actions where logging overhead is unnecessary. Takes precedence over Force Performance Logging if both are checked.

**Field Attributes:**

| Attribute | Value |
|-----------|-------|
| Data Type | Checkbox |
| Default Value | false |

### TriggerSetting__c

```apex
global Id TriggerSetting__c
```

Links this action to its parent Trigger Setting, which identifies the SObject the trigger fires on. All actions sharing the same Trigger Setting run on the same object and inherit its object-level bypass and performance controls.

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

Links this action to its parent Trigger Setting, which identifies the SObject the trigger fires on. All actions sharing the same Trigger Setting run on the same object and inherit its object-level bypass and performance controls.

**Field Attributes:**

| Attribute | Value |
|-----------|-------|
| Data Type | TriggerSetting__mdt |
| Required | true |
| Unique | false |

