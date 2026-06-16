---
navOrder: 10
---

# Triggers - Guide

**Framework:** KernDX
**Package Type:** Managed Package

**Target Audience:**

- **Developers** - Implementing trigger logic with modular, metadata-driven actions
- **Architects** - Designing scalable trigger frameworks with proper separation of concerns
- **Business Analysts** - Understanding trigger behavior and configuration options

---

## Table of Contents

<details>
<summary>Expand</summary>

1. [Quick Navigation](#quick-navigation)
2. [Overview](#overview)
    - [Framework Benefits](#framework-benefits)
    - [Architecture](#architecture)
    - [KernDX vs OOTB: Trigger Patterns Comparison](#kerndx-vs-ootb-trigger-patterns-comparison)
        - [Salesforce Out-of-the-Box Approach](#salesforce-out-of-the-box-approach)
        - [Pros & Cons Comparison](#pros--cons-comparison)
        - [When to Use KernDX Trigger Action Framework](#when-to-use-kerndx-trigger-action-framework)
        - [When to Use OOTB Trigger Patterns](#when-to-use-ootb-trigger-patterns)
        - [Example Comparison](#example-comparison)
    - [Legacy Handler Pattern](#legacy-handler-pattern)
3. [Quick Start](#quick-start)
4. [Architecture Components](#architecture-components)
    - [Core Classes](#core-classes)
        - [TRG_Base](#trg_base)
        - [TRG_Dispatcher](#trg_dispatcher)
    - [Interfaces](#interfaces)
        - [IF_Trigger](#if_trigger)
    - [Custom Metadata Types](#custom-metadata-types)
        - [TriggerSetting__mdt](#triggersetting__mdt)
        - [TriggerAction__mdt](#triggeraction__mdt)
5. [Custom Metadata Configuration](#custom-metadata-configuration)
    - [TriggerSetting__mdt Field Reference](#triggersetting__mdt-field-reference)
        - [SObjectType__c (Required)](#sobjecttype__c-required)
        - [BypassExecution__c (Subscriber Controlled)](#bypassexecution__c-subscriber-controlled)
        - [BypassFeatureFlag__c (Subscriber Controlled)](#bypassfeatureflag__c-subscriber-controlled)
        - [RequiredFeatureFlag__c (Subscriber Controlled)](#requiredfeatureflag__c-subscriber-controlled)
        - [EnablePerformanceLogging__c (Subscriber Controlled)](#enableperformancelogging__c-subscriber-controlled)
        - [PerformanceThresholdMs__c (Subscriber Controlled)](#performancethresholdms__c-subscriber-controlled)
        - [ApplyMasking__c (Subscriber Controlled)](#applymasking__c-subscriber-controlled)
    - [TriggerAction__mdt Field Reference](#triggeraction__mdt-field-reference)
        - [ApexClassName__c](#apexclassname__c)
        - [Event__c (Required)](#event__c-required)
        - [TriggerSetting__c (Required)](#triggersetting__c-required)
        - [Order__c (Required)](#order__c-required)
        - [AllowRecursion__c (Developer Controlled)](#allowrecursion__c-developer-controlled)
        - [AllowNonSelfInitiated__c (Developer Controlled)](#allownonselfinitiated__c-developer-controlled)
        - [BypassExecution__c (Subscriber Controlled)](#bypassexecution__c-subscriber-controlled-1)
        - [Entry Criteria Fields (Developer Controlled)](#entry-criteria-fields-developer-controlled)
        - [Description__c (Required)](#description__c-required)
6. [Flow as a Trigger Action](#flow-as-a-trigger-action)
    - [TriggerAction__mdt fields used by flow actions](#triggeraction__mdt-fields-used-by-flow-actions)
    - [Variable contract on the registered flow](#variable-contract-on-the-registered-flow)
    - [LogSetting__c volume gate](#logsetting__c-volume-gate)
    - [Mock harness](#mock-harness)
    - [When to use a flow action vs a record-triggered flow](#when-to-use-a-flow-action-vs-a-record-triggered-flow)
    - [Failure-action strategies](#failure-action-strategies)
    - [Cross-namespace flow resolution](#cross-namespace-flow-resolution)
    - [Recommended-default pattern matrix](#recommended-default-pattern-matrix)
    - [Audit volume control](#audit-volume-control)
    - [Bypass and rollback](#bypass-and-rollback)
    - [Migrating from TAF to KernDX](#migrating-from-taf-to-kerndx)
7. [Change Data Capture Actions](#change-data-capture-actions)
    - [The Change Event trigger](#the-change-event-trigger)
    - [Registering a Change Event action](#registering-a-change-event-action)
    - [Reading the change header](#reading-the-change-header)
    - [Block DML is unavailable for Change Data Capture](#block-dml-is-unavailable-for-change-data-capture)
8. [Post-Trigger Actions](#post-trigger-actions)
    - [When post-trigger actions fire](#when-post-trigger-actions-fire)
    - [The no-DML contract](#the-no-dml-contract)
    - [Intended uses and anti-patterns](#intended-uses-and-anti-patterns)
    - [Writing a post-trigger action](#writing-a-post-trigger-action)
    - [Registering a post-trigger action](#registering-a-post-trigger-action)
9. [Trigger Action Interfaces](#trigger-action-interfaces)
    - [IF_Trigger.BeforeInsert](#if_triggerbeforeinsert)
    - [IF_Trigger.AfterInsert](#if_triggerafterinsert)
    - [IF_Trigger.BeforeUpdate](#if_triggerbeforeupdate)
    - [IF_Trigger.AfterUpdate](#if_triggerafterupdate)
    - [IF_Trigger.BeforeDelete](#if_triggerbeforedelete)
    - [IF_Trigger.AfterDelete](#if_triggerafterdelete)
    - [IF_Trigger.AfterUndelete](#if_triggerafterundelete)
10. [Caching with Trigger Actions](#caching-with-trigger-actions)
- [Caching Pattern Overview](#caching-pattern-overview)
- [Implementation Pattern](#implementation-pattern)
- [Execution Flow](#execution-flow)
- [Best Practices for Caching](#best-practices-for-caching)
- [Testing Cached Actions](#testing-cached-actions)
11. [Function-Like Coordination](#function-like-coordination)
- [Coordination Patterns](#coordination-patterns)
    - [Pattern 1: Sequential Processing](#pattern-1-sequential-processing)
    - [Pattern 2: Data Preparation - Processing](#pattern-2-data-preparation---processing)
    - [Pattern 3: Conditional Execution via Entry Criteria](#pattern-3-conditional-execution-via-entry-criteria)
    - [Pattern 4: Progressive Enhancement](#pattern-4-progressive-enhancement)
    - [Pattern 5: Functional Composition](#pattern-5-functional-composition)
- [Real-World Coordination Example](#real-world-coordination-example)
12. [Advanced Features](#advanced-features)
    - [Recursion Prevention](#recursion-prevention)
    - [Self-Initiated Control](#self-initiated-control)
    - [Bypass Mechanisms](#bypass-mechanisms)
        - [Object-Level Bypass (TriggerSetting__mdt)](#object-level-bypass-triggersetting__mdt)
        - [Action-Level Bypass (TriggerAction__mdt)](#action-level-bypass-triggeraction__mdt)
        - [Bypass Audit Trail](#bypass-audit-trail)
        - [Flow-Based Bypass (FLOW_BypassTrigger)](#flow-based-bypass-flow_bypasstrigger)
        - [Feature Flag Bypass](#feature-flag-bypass)
        - [Feature Flag Gating](#feature-flag-gating)
    - [Feature Flag Integration](#feature-flag-integration)
    - [Entry Criteria Formulas](#entry-criteria-formulas)
        - [Simple Entry Criteria](#simple-entry-criteria)
        - [Complex Entry Criteria](#complex-entry-criteria)
13. [Common Patterns](#common-patterns)
    - [Validation Pattern](#validation-pattern)
    - [Field Population Pattern](#field-population-pattern)
    - [Related Record Creation Pattern](#related-record-creation-pattern)
    - [Cascade Update Pattern](#cascade-update-pattern)
    - [Audit Trail Pattern](#audit-trail-pattern)
14. [Testing](#testing)
    - [Testing Individual Actions](#testing-individual-actions)
    - [Testing with Bypass](#testing-with-bypass)
    - [Testing Action Coordination](#testing-action-coordination)
    - [Testing Multiple Actions in Order](#testing-multiple-actions-in-order)
    - [Testing Entry Criteria](#testing-entry-criteria)
15. [Performance Logging](#performance-logging)
    - [Performance Logging Overview](#performance-logging-overview)
    - [Configuration Hierarchy](#configuration-hierarchy)
    - [How Performance Logging Works](#how-performance-logging-works)
    - [Viewing Performance Logs](#viewing-performance-logs)
16. [Capability Matrix (for Analysts)](#capability-matrix-for-analysts)
17. [Anti-Patterns](#anti-patterns)
18. [Best Practices](#best-practices)
19. [Troubleshooting](#troubleshooting)
    - [Common Issues](#common-issues)
        - [Issue: Action Not Executing](#issue-action-not-executing)
        - [Issue: Wrong Execution Order](#issue-wrong-execution-order)
        - [Issue: Entry Criteria Not Working](#issue-entry-criteria-not-working)
        - [Issue: Governor Limits Exceeded](#issue-governor-limits-exceeded)
        - [Issue: Recursion Loop](#issue-recursion-loop)
        - [Issue: Type Exception](#issue-type-exception)
    - [Debugging Tips](#debugging-tips)
        - [Enable Debug Logs](#enable-debug-logs)
        - [Add Strategic Log Statements](#add-strategic-log-statements)
        - [Test in Isolation](#test-in-isolation)
        - [Query Metadata Configuration](#query-metadata-configuration)
20. [Related Documentation](#related-documentation)

</details>

---

## Quick Navigation

| I am a...     | I need to...                     | Go to...                                                    |
|---------------|----------------------------------|-------------------------------------------------------------|
| **Architect** | Understand trigger architecture  | [Architecture Components](#architecture-components)         |
| **Architect** | Design coordination patterns     | [Function-Like Coordination](#function-like-coordination)   |
| **Developer** | Create a trigger action          | [Quick Start](#quick-start)                                 |
| **Developer** | Test trigger actions             | [Testing](#testing)                                         |
| **Developer** | Use bypass mechanisms            | [Advanced Features](#advanced-features)                     |
| **Developer** | React to committed changes (CDC) | [Change Data Capture Actions](#change-data-capture-actions) |
| **Developer** | Run logic once per transaction   | [Post-Trigger Actions](#post-trigger-actions)               |
| **Analyst**   | Configure trigger settings       | [Capability Matrix](#capability-matrix-for-analysts)        |
| **Analyst**   | Monitor trigger performance      | [Performance Logging](#performance-logging)                 |

---

## Overview

The KernDX framework provides a **metadata-driven Trigger Action Framework** that enables modular,
configurable [trigger](https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_triggers.htm) logic without code deployment. Trigger actions are small, focused
classes that implement specific business logic and can be:

- **Ordered**: Execute in a specific sequence via metadata configuration
- **Coordinated**: Act like functions that can be composed and orchestrated
- **Cached**: Share data between actions using proper ordering
- **Conditional**: Execute only when entry criteria formulas evaluate to true
- **Bypassed**: Disabled at runtime without code changes
- **Reusable**: Applied to multiple objects via metadata

> **Trigger Framework Scope:** 7 `TRG_*` handler classes, 6 physical triggers (`TRG_ApiCall`, `TRG_ApiIssue`, `TRG_AsyncChainExecution`, `TRG_Foobar`, `TRG_LogEntryEvent`,
`TRG_ScheduledJob`) — all config-driven via `TriggerSetting__mdt`
> and `TriggerAction__mdt` custom metadata. Supports object-level and action-level bypass, entry criteria formulas, ordered execution, and a bypass audit trail on every
> programmatic bypass call.

> **Responsibilities:** Trigger actions execute discrete units of work (validation, field defaulting, related record creation). They do not
> query data inline -- use selectors for that. They do not contain reusable business logic -- extract that to service classes.

> **When NOT to use this pattern:**
> - Simple field updates that a formula field or record-triggered Flow can handle declaratively
> - One-time data fixes or migration scripts that run outside normal transaction flow
> - Logic that only applies in a single context and will never be reused or reordered

### Framework Benefits

- **Metadata-Driven**: Configure trigger behavior without code deployment
- **Modular**: Small, focused actions with single responsibilities
- **Coordinated**: Actions execute in order like function calls
- **Cacheable**: Early actions cache data for later actions
- **Testable**: Each action can be tested independently
- **Reusable**: Same action class works on multiple objects
- **Bulkified**: Built-in support for processing records in bulk
- **Safe**: Automatic recursion prevention and bypass mechanisms

### Architecture

```text
+---------------------------------------------------------------------------+
|                    TRIGGER ACTION FRAMEWORK ARCHITECTURE                   |
+---------------------------------------------------------------------------+
|                                                                           |
|   DML Operation (Insert/Update/Delete)                                    |
|           |                                                               |
|           v                                                               |
|   +-------------------------------------------------------------------+   |
|   |  Physical Trigger (e.g., TRG_Account)                             |   |
|   |  trigger TRG_Account on Account (...) { new TRG_Dispatcher().run(); } |
|   +-------------------------------+-----------------------------------+   |
|                                   |                                       |
|                                   v                                       |
|   +-------------------------------------------------------------------+   |
|   |  TRG_Dispatcher                                                   |   |
|   |  - Queries TriggerSetting__mdt for object                         |   |
|   |  - Queries TriggerAction__mdt for context (before/after, ins/etc) |   |
|   +-------------------------------+-----------------------------------+   |
|                                   |                                       |
|                                   v                                       |
|   +-------------------------------------------------------------------+   |
|   |  For each TriggerAction__mdt (ordered by Order__c):               |   |
|   |                                                                   |   |
|   |  +---------------------------------------------------------------+|   |
|   |  |  1. Check if action is Active                                 ||   |
|   |  |  2. Evaluate Entry Criteria (formula)                         ||   |
|   |  |  3. Check Required Feature Flag                                ||   |
|   |  |  4. Instantiate TRG_* class                                   ||   |
|   |  |  5. Execute interface method (beforeInsert, afterUpdate, etc)  ||   |
|   |  +---------------------------------------------------------------+|   |
|   +-------------------------------------------------------------------+   |
|                                                                           |
|   INTERFACES:                                                             |
|   +-------------+ +-------------+ +--------------+ +--------------+       |
|   |IF_Trigger.  | |IF_Trigger.  | |IF_Trigger.   | |IF_Trigger.   |       |
|   |BeforeInsert | |AfterInsert  | |BeforeUpdate  | |AfterUpdate   | ...   |
|   +-------------+ +-------------+ +--------------+ +--------------+       |
|                                                                           |
+---------------------------------------------------------------------------+
```

---

### KernDX vs OOTB: Trigger Patterns Comparison

#### Salesforce Out-of-the-Box Approach

Salesforce provides [triggers](https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_triggers.htm) as a platform feature, but does not include a framework
for organizing trigger logic. Developers typically use one of these patterns:

1. **Monolithic Trigger** - All logic in the trigger file
2. **Helper Class Pattern** - Trigger calls static helper methods
3. **Handler Class Pattern** - Trigger instantiates and calls a handler class

```apex
// Pattern 1: Monolithic (not recommended)
trigger AccountTrigger on Account (before insert, after update) {
    if(Trigger.isBefore && Trigger.isInsert) {
        for(Account acc : Trigger.new) {
            // Validation logic here
        }
    }
}

// Pattern 2: Helper Class (common)
trigger AccountTrigger on Account (before insert, after update) {
    if(Trigger.isBefore && Trigger.isInsert) {
        AccountTriggerHelper.handleBeforeInsert(Trigger.new);
    }
}

// Pattern 3: Handler Class (recommended OOTB pattern)
trigger AccountTrigger on Account (before insert, after update) {
    new AccountTriggerHandler().execute();
}
```

#### Pros & Cons Comparison

| Feature                  | KernDX Trigger Action Framework                                                              | OOTB Trigger Patterns (Helper/Handler)                    |
|--------------------------|----------------------------------------------------------------------------------------------|-----------------------------------------------------------|
| **Execution Order**      | Metadata-controlled via `Order__c` field                                                     | Manual control with if/else ordering or method calls      |
| **Modular Actions**      | Small, focused classes implementing interfaces                                               | Manually create helper/handler classes                    |
| **Configuration**        | Enable/disable actions via metadata without deployment                                       | Requires code deployment to change behavior               |
| **Bypass Control**       | Global, object-level, and action-level bypass                                                | Must manually implement bypass logic (static flags)       |
| **Recursion Prevention** | Built-in — `TRG_Dispatcher` tracks the execution stack and short-circuits re-entrant actions | Must manually implement recursion tracking (static flags) |
| **Entry Criteria**       | Declarative formula evaluation per action                                                    | Must code all conditional logic in if statements          |
| **Reusability**          | Same action class on multiple objects via metadata                                           | Can create reusable helpers, but requires manual wiring   |
| **Testing**              | Test each action independently                                                               | Typically test entire trigger flow together               |
| **Feature Flag Gating**  | `RequiredFeatureFlag__c` field for conditional execution                                     | Must manually check permissions in code                   |
| **Data Caching**         | Actions share cached data via execution order                                                | Must manually implement caching patterns                  |
| **Setup Complexity**     | Requires custom metadata configuration + framework knowledge                                 | Familiar trigger pattern, no extra configuration          |
| **Performance**          | Framework overhead (metadata queries, reflection)                                            | Direct method calls, minimal overhead                     |
| **Learning Curve**       | Must learn framework patterns and interfaces                                                 | Standard Apex patterns familiar to most developers        |

#### When to Use KernDX Trigger Action Framework

- **Enterprise orgs** with multiple trigger requirements
- **Complex trigger logic** requiring ordered execution
- **Frequent changes** to trigger behavior without deployments
- **Multiple developers** working on same object triggers
- **Reusable validation** logic across multiple objects
- **Bypass requirements** for data loads, integrations, testing
- **Declarative control** over trigger execution
- **Entry criteria formulas** to conditionally execute logic

#### When to Use OOTB Trigger Patterns

- **Simple triggers** with minimal logic
- **One-time implementations** that rarely change
- **Maximum performance** is critical (avoid framework overhead)
- **Small teams** with simple requirements
- **Prototype/POC** projects
- **Team familiarity** with traditional trigger patterns
- **No metadata configuration** desired

#### Example Comparison

**OOTB Standard Trigger (Monolithic):**

```apex
trigger AccountTrigger on Account (before insert, before update, after insert, after update) {
    // All logic in one file or scattered across helper classes

    if(Trigger.isBefore) {
        if(Trigger.isInsert) {
            // Validation 1
            for(Account acc : Trigger.new) {
                if(String.isBlank(acc.Name)) {
                    acc.Name.addError('Name is required');
                }
            }

            // Validation 2
            for(Account acc : Trigger.new) {
                if(acc.AnnualRevenue < 0) {
                    acc.AnnualRevenue.addError('Revenue cannot be negative');
                }
            }

            // Field population
            for(Account acc : Trigger.new) {
                acc.AccountNumber = generateAccountNumber();
            }
        }

        if(Trigger.isUpdate) {
            // Update logic...
        }
    }

    if(Trigger.isAfter) {
        // After logic...
    }
}
```

**KernDX Trigger Action (Modular):**

```apex
// Physical trigger (one line)
trigger TRG_Account on Account (before insert, before update, after insert, after update)
{
	new TRG_Dispatcher().run();
}

// Validation Action 1
public inherited sharing class TRG_AccountValidateName extends TRG_Base
	implements IF_Trigger.BeforeInsert
{
	public void beforeInsert(List<Account> newAccounts)
	{
		for(Account account : newAccounts)
		{
			if(String.isBlank(account.Name))
			{
				account.Name.addError('Name is required');
			}
		}
	}
}

// Validation Action 2
public inherited sharing class TRG_AccountValidateRevenue extends TRG_Base
	implements IF_Trigger.BeforeInsert
{
	public void beforeInsert(List<Account> newAccounts)
	{
		for(Account account : newAccounts)
		{
			if(account.AnnualRevenue < 0)
			{
				account.AnnualRevenue.addError('Revenue cannot be negative');
			}
		}
	}
}

// Field Population Action
public inherited sharing class TRG_AccountPopulateNumber extends TRG_Base
	implements IF_Trigger.BeforeInsert
{
	public void beforeInsert(List<Account> newAccounts)
	{
		for(Account account : newAccounts)
		{
			account.AccountNumber = generateAccountNumber();
		}
	}
}

// Metadata Configuration (TriggerAction__mdt):
// 1. TRG_AccountValidateName (Order__c: 10)
// 2. TRG_AccountValidateRevenue (Order__c: 20)
// 3. TRG_AccountPopulateNumber (Order__c: 30)

// Enable/disable actions without code deployment!
// Update TriggerAction__mdt.BypassExecution__c = true
```

**Key Advantages Demonstrated:**

1. Each action is independently testable
2. Execution order controlled by metadata
3. Actions can be enabled/disabled without deployment
4. Actions can be reused on other objects
5. New actions can be added without modifying existing code
6. Bypass control at action, object, or global level

---

### Legacy Handler Pattern

The Handler Pattern (TRH_* classes) is **retained for backward compatibility** in the managed package but has been replaced by the Trigger Action Framework. New implementations
should use the TRG_* pattern exclusively.

---

## Quick Start

Extend `TRG_Base` and implement a `IF_Trigger` context interface to create metadata-driven trigger actions.

> **Step-by-step walkthrough:** [Fast Start - Trigger Actions](Fast%20Start%20-%20Trigger%20Actions.md) covers implementation,
> testing, and common pitfalls.

```apex
public inherited sharing class TRG_SetDefaults extends TRG_Base implements IF_Trigger.BeforeInsert
{
	public void beforeInsert(List<SObject> newRecords)
	{
		for(SObject newRecord : newRecords)
		{
			if(newRecord.get('Status__c') == null)
			{
				newRecord.put('Status__c', 'New');
			}
		}
	}
}
```

For deeper coverage, continue reading the sections below.

---

## Architecture Components

### Core Classes

#### [TRG_Base](reference/apex/TRG_Base.md)

Base class that all trigger actions extend. Provides common functionality
and [trigger context](https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_triggers_context_variables.htm) access:

```apex
global virtual inherited sharing class TRG_Base
{
	// Protected properties accessible to subclasses
	global protected String sObjectName { get; private set; }
	global protected TriggerOperation context { get; private set; }
	global protected List<SObject> triggerNew { get; private set; }
	global protected List<SObject> triggerOld { get; private set; }

	// Main execution method
	global void run()

	// Bypass control methods (object-level)
	global static void bypass(SObjectType sObjectType)           // type-safe
	global static void bypass(String sObjectName)                // string-based
	global static void clearBypass(SObjectType sObjectType)
	global static void clearBypass(String sObjectName)
	global static Boolean isBypassed(SObjectType sObjectType)
	global static Boolean isBypassed(String sObjectName)
	global static void clearAllBypasses()

	// Bypass control methods (action-level)
	global static void bypassAction(String actionClassName)
	global static Boolean isActionBypassed(String actionClassName)
	global static void clearActionBypass(String actionClassName)
	global static void clearAllActionBypasses()

	// Audit-trail helper: attach a reason to subsequent bypass events
	global static void setBypassReason(String reason)

	// Enum returned by resolveBypassAction(String) for audit-trail parsing
	global enum BypassAction { BYPASS, CLEAR, CLEAR_ALL }
}
```

**Key Features:**

- Automatically populates trigger context properties
- Validates execution only within trigger context
- Provides object-level bypass control
- Calls appropriate interface method based on [trigger operation](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_enum_System_TriggerOperation.htm)

#### [TRG_Dispatcher](reference/apex/TRG_Dispatcher.md)

Factory class that orchestrates trigger action execution:

```apex
global inherited sharing class TRG_Dispatcher
{
	// Entry point for trigger execution
	global void run()
}
```

**Key Features:**

- Reads `TriggerAction__mdt` and `TriggerSetting__mdt` configuration
- Executes actions in Order__c sequence
- Evaluates entry criteria formulas per record
- Manages recursion detection per action
- Supports self-initiated vs non-self-initiated control

> **Note:** Bypass control methods (`bypass`, `clearBypass`, `isBypassed`, `bypassAction`, `clearActionBypass`,
> `clearAllBypasses`, `clearAllActionBypasses`) are on [`TRG_Base`](#trg_base), not `TRG_Dispatcher`.

### Interfaces

#### [IF_Trigger](reference/apex/IF_Trigger.md)

Collection of interfaces defining methods for each trigger context:

```apex
global interface BeforeInsert { void beforeInsert(List<SObject> newRecords); }
global interface AfterInsert { void afterInsert(List<SObject> newRecords); }
global interface BeforeUpdate { void beforeUpdate(List<SObject> newRecords, List<SObject> oldRecords); }
global interface AfterUpdate { void afterUpdate(List<SObject> newRecords, List<SObject> oldRecords); }
global interface BeforeDelete { void beforeDelete(List<SObject> oldRecords); }
global interface AfterDelete { void afterDelete(List<SObject> oldRecords); }
global interface AfterUndelete { void afterUndelete(List<SObject> newRecords); }
```

**Key Characteristics:**

- Each interface has a single method
- Methods receive lists of SObjects (bulk processing)
- newRecords/oldRecords naming matches [Trigger context variables](https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_triggers_context_variables.htm)
- Actions can implement multiple interfaces

### Custom Metadata Types

#### TriggerSetting__mdt

Defines per-object configuration for trigger actions:

| Field                    | Type                                   | Purpose                                             |
|--------------------------|----------------------------------------|-----------------------------------------------------|
| `SObjectType__c`         | MetadataRelationship(EntityDefinition) | The SObject this trigger setting applies to         |
| `BypassExecution__c`     | Checkbox                               | Bypass all actions for this object                  |
| `BypassFeatureFlag__c`   | MetadataRelationship(FeatureFlag__mdt) | Feature Flag that bypasses all actions when enabled |
| `RequiredFeatureFlag__c` | MetadataRelationship(FeatureFlag__mdt) | Feature Flag required for actions to run            |
| `ApplyMasking__c`        | Checkbox                               | Mask configured sensitive fields before actions run |

#### TriggerAction__mdt

Defines individual trigger actions and their behavior:

| Field                              | Type                                      | Purpose                                                                                                                                                                                                                               |
|------------------------------------|-------------------------------------------|---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `ApexClassName__c`                 | Text(100)                                 | Fully qualified Apex class name. Set this for Apex actions; leave blank for flow actions (the framework dispatches to its built-in flow runner when `FlowName__c` is populated).                                                      |
| `FlowName__c`                      | Text(80)                                  | Bare flow API name for flow-based actions. Leave blank for Apex actions.                                                                                                                                                              |
| `FailureAction__c`                 | Picklist                                  | How the dispatcher handles uncaught errors raised by the action. `LogAndContinue` (default) emits a log entry and lets DML proceed; `BlockDml` calls `record.addError(...)` to halt the save. Applies to Apex and flow actions alike. |
| `Event__c`                         | Picklist (Required)                       | [Trigger event](https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_triggers_order_of_execution.htm): Before Insert, After Insert, Before Update, After Update, Before Delete, After Delete, After Undelete |
| `TriggerSetting__c`                | MetadataRelationship(TriggerSetting__mdt) | Link to the parent TriggerSetting for the target SObject                                                                                                                                                                              |
| `Order__c`                         | Number(4,0)                               | Execution order (lower = earlier)                                                                                                                                                                                                     |
| `AllowRecursion__c`                | Checkbox                                  | Allow recursive execution                                                                                                                                                                                                             |
| `AllowNonSelfInitiated__c`         | Checkbox                                  | Allow execution from other triggers                                                                                                                                                                                                   |
| `BypassExecution__c`               | Checkbox                                  | Runtime bypass flag                                                                                                                                                                                                                   |
| `BypassFeatureFlag__c`             | MetadataRelationship(FeatureFlag__mdt)    | Feature Flag that bypasses this action when enabled                                                                                                                                                                                   |
| `RequiredFeatureFlag__c`           | MetadataRelationship(FeatureFlag__mdt)    | Feature Flag required for this action to run                                                                                                                                                                                          |
| `EntryCriteriaFormula__c`          | Long Text Area                            | Formula for conditional execution                                                                                                                                                                                                     |
| `EntryCriteriaContextClassName__c` | Text(100)                                 | Context class for formula evaluation (auto-detected for standard objects)                                                                                                                                                             |
| `Description__c`                   | Long Text Area                            | Required description                                                                                                                                                                                                                  |
| `ForcePerformanceLogging__c`       | Checkbox                                  | Always log performance for this action                                                                                                                                                                                                |
| `SuppressPerformanceLogging__c`    | Checkbox                                  | Never log performance for this action                                                                                                                                                                                                 |
| `PerformanceThresholdMs__c`        | Number(8,0)                               | Log if duration exceeds threshold (ms)                                                                                                                                                                                                |

> **Validation rule:** `MutuallyExclusiveTarget` enforces XOR on `(ApexClassName__c, FlowName__c)` — exactly one must be populated. A row with both populated is ambiguous; a row
> with neither has no dispatch target. The deploy fails if either invariant is violated.

---

## Custom Metadata Configuration

### TriggerSetting__mdt Field Reference

#### SObjectType__c (Required)

**Purpose:** Identifies which SObject this setting applies to via
a [MetadataRelationship](https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_class_System_TriggerOperation.htm) to `EntityDefinition`.

**Format:** Select the SObject from the EntityDefinition lookup (e.g., `Account`, `Contact`, `Foobar__c`).

**Example:**

```text
SObject Type: Account
```

**Usage:** Referenced by TriggerAction__mdt records via `TriggerSetting__c` to associate actions with objects. Use `SObjectType__r.QualifiedApiName` in SOQL to resolve the API
name.

#### BypassExecution__c (Subscriber Controlled)

**Purpose:** Runtime bypass for all trigger actions on this object.

**Default:** `false`

**When to Use:**

- Data migrations requiring trigger bypass
- Bulk operations where validation should be skipped
- Temporary disablement during maintenance

**Example:**

```text
Bypass Execution: true
```

**Effect:** All trigger actions for this object are skipped.

#### BypassFeatureFlag__c (Subscriber Controlled)

**Purpose:** Feature Flag that bypasses all actions when enabled for the running user.

**Type:** MetadataRelationship — lookup to a `FeatureFlag__mdt` record (e.g., `Bypass_Account_Triggers`). Selected via dropdown picker in the CMDT UI.

**When to Use:**

- Emergency kill switches for trigger logic
- Targeted bypass for specific user groups via Feature Flag strategies
- Data migration processes with controlled bypass

**Example:**

```text
Bypass Feature Flag: Bypass_Account_Triggers
```

**Effect:** When the referenced Feature Flag evaluates to `true` for the running user, all trigger actions for this object are skipped.

> **Tip:** For permission-based bypass, create a Feature Flag with a `Custom Permission` strategy type in `FeatureFlagStrategy__mdt`.

#### RequiredFeatureFlag__c (Subscriber Controlled)

**Purpose:** Feature Flag required for actions to execute.

**Type:** MetadataRelationship — lookup to a `FeatureFlag__mdt` record (e.g., `Enable_Account_Validation`). Selected via dropdown picker in the CMDT UI.

**When to Use:**

- Gradual rollout of new trigger logic
- Restrict trigger execution to targeted user groups
- Enable features only for specific profiles or permission set groups

**Example:**

```text
Required Feature Flag: Enable_Account_Validation
```

**Effect:** Actions only execute if the referenced Feature Flag evaluates to `true` for the running user.

> **Tip:** For permission-based gating, create a Feature Flag with a `Custom Permission` strategy type in `FeatureFlagStrategy__mdt`.

#### EnablePerformanceLogging__c (Subscriber Controlled)

**Purpose:** Enable performance logging for all trigger actions on this object.

**Default:** `false`

**When to Use:**

- Monitor trigger performance for high-volume objects
- Identify slow actions during optimization efforts
- Stricter monitoring than global settings

**Example:**

```text
Enable Performance Logging: true
```

**Effect:** Overrides global `LogSetting__c.EnableTriggerPerformanceLogging__c` for this object.

#### PerformanceThresholdMs__c (Subscriber Controlled)

**Purpose:** Threshold in milliseconds for logging trigger action performance.

**Default:** Inherits from `LogSetting__c.TriggerPerformanceThresholdMs__c`

**When to Use:**

- Set stricter thresholds for critical objects
- Override global threshold for specific objects

**Example:**

```text
Performance Threshold Ms: 200
```

**Effect:** Actions on this object log when duration exceeds this threshold (if performance logging is enabled).

> **See Also:** [Performance Logging](#performance-logging) for detailed configuration and usage.

#### ApplyMasking__c (Subscriber Controlled)

**Purpose:** Runs the [data masking](Security%20-%20Guide.md#data-masking) pass on this object before any trigger actions execute, so configured sensitive
fields are redacted on save.

**Default:** `true` — every object with a Trigger Setting is masked automatically. Uncheck it to opt one object out.

**How it runs:** On every **before-insert** and **before-update**, the dispatcher masks the records *before* the first trigger action fires — so downstream
actions, and the database, only ever see the masked values. The pass runs only when the `MaskingFramework_Enabled` feature flag is on, and only redacts fields you
have wired up with a `MaskingTarget__mdt` record. It runs in the `before` phase and writes onto the record in memory, so it adds no extra DML.

**When to Use:**

- Leave it checked for objects that hold sensitive text (the default).
- Uncheck it for objects with no sensitive data to skip the masking pass for a small performance saving.

**Example:**

```text
Apply Masking: true
```

**Effect:** Sensitive values matching your masking rules are redacted on this object before any trigger action — Apex or flow — sees them, and before the record
is committed.

> **See Also:** [Data Masking](Security%20-%20Guide.md#data-masking) in the Security Guide for rule and target configuration, the honest caveats (masking is
> destructive, text-only, and not retroactive), and the Data Masking Advisor.

### TriggerAction__mdt Field Reference

#### ApexClassName__c

**Purpose:** Fully qualified name of the trigger action class. Set this for Apex actions; leave blank for flow-based actions (set `FlowName__c` instead).

**Format:**

- Unmanaged: `TRG_SetExternalReference`
- Managed: `namespace__TRG_SetExternalReference` or `namespace.TRG_SetExternalReference`

**Validation:**

- Exactly one of `ApexClassName__c` or `FlowName__c` must be populated (enforced by the `MutuallyExclusiveTarget` validation rule).
- When set, the class must exist and implement the appropriate [IF_Trigger](reference/apex/IF_Trigger.md) interface for the configured `Event__c`.

**Example:**

```text
Apex Class Name: TRG_SetExternalReference
```

#### Event__c (Required)

**Purpose:** Specifies the trigger event this action responds to.

**Type:** Restricted picklist with the following values:

- `Before Insert`
- `After Insert`
- `Before Update`
- `After Update`
- `Before Delete`
- `After Delete`
- `After Undelete`

**Rules:**

- Exactly one event per TriggerAction__mdt record
- To run the same action in multiple contexts, create multiple TriggerAction__mdt records (one per event)

**Example:**

```text
Event: Before Insert
```

#### TriggerSetting__c (Required)

**Purpose:** Links this action to a TriggerSetting__mdt record (and therefore to a specific SObject).

**Type:** MetadataRelationship to TriggerSetting__mdt

**Rules:**

- Must reference an existing TriggerSetting__mdt record
- The referenced TriggerSetting determines which SObject this action applies to

**Example:**

```text
Trigger Setting: Foobar (references TriggerSetting__mdt for Foobar__c)
```

#### Order__c (Required)

**Purpose:** Controls execution sequence within the same trigger context.

**Format:** Number (recommended: 10, 20, 30, etc.)

**How It Works:**

- Lower numbers execute first
- Actions with same Order__c may execute in any sequence
- Allows gaps for inserting actions later without renumbering

**Caching Pattern:**

```text
Order 10: TRG_CacheRelatedData (loads data for later actions)
Order 20: TRG_ValidateFields (uses cached data)
Order 30: TRG_PopulateFields (uses cached data)
Order 40: TRG_CreateRelatedRecords (final operations)
```

**Example:**

```text
Order: 10
```

#### AllowRecursion__c (Developer Controlled)

**Purpose:** Controls whether action can execute recursively.

**Default:** `true`

**When true:**

- Action can execute multiple times in same transaction
- Use when action doesn't cause DML on same object

**When false:**

- Action executes only once per transaction
- Prevents infinite loops
- Use when action might trigger itself

**Example:**

```text
Allow Recursion: false
```

#### AllowNonSelfInitiated__c (Developer Controlled)

**Purpose:** Controls whether action executes when called from another trigger.

**Default:** `true`

**When true:**

- Action executes even when triggered by another object's trigger
- Example: Contact action runs when Account trigger creates Contacts

**When false:**

- Action only executes for direct DML on the object
- Prevents cascading trigger execution

**Example:**

```text
Allow Non Self-Initiated: true
```

#### BypassExecution__c (Subscriber Controlled)

**Purpose:** Runtime bypass for this specific action.

**Default:** `false`

**When to Use:**

- Temporarily disable problematic action
- A/B testing different action configurations
- Gradual rollout of new functionality

**Example:**

```text
Bypass Execution: true
```

#### Entry Criteria Fields (Developer Controlled)

**EntryCriteriaFormula__c**

**Purpose:** Formula evaluated per record for conditional execution.

**Format:** Formula expression using context class properties

**How It Works:**

1. Framework instantiates context class
2. Sets newRecord/oldRecord properties
3. Evaluates formula using FormulaEval
4. Only records where formula = true are passed to action

**Example:**

```text
Entry Criteria Formula: isPremiumTier && statusChanged
```

**EntryCriteriaContextClassName__c**

**Purpose:** Apex class providing properties for formula evaluation.

**Format:** Fully qualified class name (blank for standard objects with pre-built contexts)

**Auto-detection for Supported Objects:**

For the following objects, you can leave this field **blank** - the framework automatically uses pre-built context classes from `UTIL_FormulaContext`:

- Account, Campaign, Case, Contact, Event, Foobar__c, Lead, Opportunity, Task, User

These pre-built contexts provide `oldRecord` and `newRecord` typed to the specific SObject, supporting formulas like:

```text
newRecord.Industry <> oldRecord.Industry
```

**Custom Context Classes (for custom objects or advanced business logic):**

**Requirements:**

- Must be declared `global` (required for managed package visibility)
- Must implement `UTIL_FormulaFilter.INT_SObjectFormulaEvaluationContext` interface
- Must implement the `setContext(SObject oldRecord, SObject newRecord)` method
- Must have `global` properties referenced in formula
- Should have oldRecord and newRecord properties (typed to specific SObject)
- Should use `@SuppressWarnings('PMD.AvoidGlobalModifier')` annotation

**Example:**

```text
Entry Criteria Context Class Name: UTIL_AccountContext
```

**Context Class Example:**

```apex
/**
 * @description Formula evaluation context for Account records. Provides old and new record states
 *              for formula-based filtering and evaluation in trigger and automation contexts.
 *
 * @see UTIL_FormulaFilter.INT_SObjectFormulaEvaluationContext
 *
 * @author <your-author-tag>
 *
 * @date January 2025
 */
@SuppressWarnings('PMD.AvoidGlobalModifier')
global with sharing class UTIL_AccountContext implements UTIL_FormulaFilter.INT_SObjectFormulaEvaluationContext
{
	/**
	 * @description The Account record state before the DML operation
	 */
	global Account oldRecord;

	/**
	 * @description The Account record state after the DML operation
	 */
	global Account newRecord;

	/**
	 * @description Checks if the account is premium tier
	 */
	global Boolean isPremiumTier
	{
		get { return newRecord?.Type == 'Premium'; }
	}

	/**
	 * @description Checks if the status field changed
	 */
	global Boolean statusChanged
	{
		get { return oldRecord != null && newRecord?.Status__c != oldRecord.Status__c; }
	}

	/**
	 * @description Sets the context for formula evaluation with old and new Account records
	 *
	 * @param oldSObject The record state before the DML operation
	 * @param newSObject The record state after the DML operation
	 */
	public void setContext(SObject oldSObject, SObject newSObject)
	{
		oldRecord = (Account)oldSObject ?? new Account();
		newRecord = (Account)newSObject ?? new Account();
	}
}
```

#### Description__c (Required)

**Purpose:** Documents what the action does.

**Validation:** Required by validation rule.

**Best Practices:**

- Describe the business logic
- Note any dependencies
- Mention data requirements

**Example:**

```text
Description: Populates ExternalReference__c field with a UUID if the field is blank.
This allows bulk imports to preset values while ensuring all records have a unique identifier.
```

---

## Flow as a Trigger Action

The framework includes a built-in flow runner that invokes an auto-launched Flow as a trigger action. Subscribers
register a flow as a trigger action by deploying a `TriggerAction__mdt` row with `FlowName__c` populated and
`ApexClassName__c` left blank — the framework auto-resolves the dispatch target to its built-in flow runner. The
dispatcher constructs the flow interview, supplies the trigger record, executes the flow, and copies the
populated fields back onto the trigger record. The action inherits ordering, bypass, recursion control,
performance monitoring, audit logging, and feature-flag gating from the standard dispatcher path.

**For a copy-paste quick start** see the [Fast Start - Trigger Actions](Fast%20Start%20-%20Trigger%20Actions.md#using-flow-as-a-trigger-action)
walkthrough. The decision criteria, error strategies, audit gating, bypass / rollback options, and TAF migration
recipe live in this guide below.

### TriggerAction__mdt fields used by flow actions

| Field              | Type      | Required                          | Default          | Allowed values                          | Purpose                                                                                                                                                                                                                                                                                                                           |
|--------------------|-----------|-----------------------------------|------------------|-----------------------------------------|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `FlowName__c`      | Text(80)  | Yes (XOR with `ApexClassName__c`) | —                | Bare flow API name, no namespace prefix | Flow API name bound to this action. The framework resolves the namespace internally. Validated at deploy by the `npm run scan:flow-references` CI scanner rule (existence + active state + variable contract).                                                                                                                    |
| `ApexClassName__c` | Text(100) | Leave blank for flow actions      | —                | —                                       | Leave this field blank when configuring a flow action. The `MutuallyExclusiveTarget` validation rule rejects rows with both fields populated.                                                                                                                                                                                     |
| `FailureAction__c` | Picklist  | No (defaulted)                    | `LogAndContinue` | `LogAndContinue`, `BlockDml`            | How the framework handles uncaught flow errors. `LogAndContinue` (default) emits a `LogEntryEvent__e` and lets DML proceed; `BlockDml` calls `record.addError(...)` to stop the save and surface the flow error to the user. See [Failure-action strategies](#failure-action-strategies) — the field applies to Apex actions too. |

### Variable contract on the registered flow

The framework owns the flow's input/output variable map. Every flow registered as a trigger action declares
one or two variables, exactly as listed below:

| Variable      | Type                                | Direction          | Required for                      |
|---------------|-------------------------------------|--------------------|-----------------------------------|
| `record`      | The trigger object (e.g. `Account`) | **Input + Output** | All 7 contexts                    |
| `recordPrior` | The trigger object (e.g. `Account`) | **Input only**     | Before Update / After Update only |

The variable type must match the dispatching `TriggerSetting__mdt.SObjectType__c` exactly. A flow whose `record`
variable is typed `Contact` cannot be registered against an `Account` trigger setting — type mismatch is
unrecoverable at runtime. The deploy-time CI scanner rule (`npm run scan:flow-references`) catches this before
merge by reading the active flow's `Metadata.variables` via Tooling API and comparing the `objectType` to the
dispatching trigger setting.

### LogSetting__c volume gate

| Field                                      | Type     | Default      | Allowed values                  | Purpose                                                                                                                                                                                                                                                                                                                                                                                    |
|--------------------------------------------|----------|--------------|---------------------------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `LogSetting__c.EnableFlowActionLogging__c` | Text(40) | `ErrorsOnly` | `Off`, `ErrorsOnly`, `AlwaysOn` | Controls how often the framework writes flow-action audit log entries. `Off` disables audit logging entirely. `ErrorsOnly` (default) logs one entry per failed flow run, with the failed record identified. `AlwaysOn` logs one summary entry per successful batch plus one entry per failed record — use this only in orgs that need compliance-grade evidence of every flow trigger run. |

The volume gate is layered per-user in the same way as the existing `LogSetting__c.LogLevelThreshold__c` field —
each user can have their own `LogSetting__c` record overriding the org-default. Performance logging is
controlled separately via the existing `LogSetting__c.TriggerPerformanceThresholdMs__c` field.

### Mock harness

`TST_InvokeFlowMock.forFlow(name)...register()` short-circuits `Flow.Interview` at test time — see
[Fast Start - Trigger Actions: Testing Flow Actions with TST_InvokeFlowMock](Fast%20Start%20-%20Trigger%20Actions.md#testing-flow-actions-with-tst_invokeflowmock) for the helper
reference and the worked example.

### When to use a flow action vs a record-triggered flow

Both options run a flow in response to a DML event but sit in different layers of the platform. The deciding question
is whether the flow needs to **interleave** with Apex trigger actions (ordering, shared recursion blocking, shared
bypass, shared audit) or run **alongside** them as an independent unit. Interleaving is the flow-action use case.

| Use case                                                                                         | Recommendation                                                                                                                                               |
|--------------------------------------------------------------------------------------------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------|
| Mixed Apex + Flow logic that needs to run under one bypass / recursion / audit / perf umbrella   | Flow action (`FlowName__c` populated)                                                                                                                        |
| Pure-Flow logic with no need for ordered interleaving with Apex                                  | Native record-triggered flow                                                                                                                                 |
| Validation flows that must respect existing `UTIL_ValidationRule` bypass / group-of-rules wiring | Flow action with `FailureAction__c = 'BlockDml'`                                                                                                             |
| Async / scheduled-path Flow logic                                                                | Native record-triggered flow (a flow action runs synchronously inside the trigger)                                                                           |
| Flow needs to abort the save with a custom message                                               | Flow action with `FailureAction__c = 'BlockDml'` (the framework copies the flow's error to `record.addError(...)` with the flow name and record id appended) |
| Flow only updates the same record's fields and runs once per save                                | Either — flow action if other Apex actions are already configured on the object; native RTF otherwise                                                        |

### Failure-action strategies

`FailureAction__c` is a per-row error-handling policy applied to **every** trigger action — Apex and flow alike. The
dispatcher wraps each action invocation in a try/catch and routes any uncaught `Exception` through the configured
policy.

| Strategy                   | Behaviour on action error                                                                                                                                      | Recommended for                                                                                                                                                                 |
|----------------------------|----------------------------------------------------------------------------------------------------------------------------------------------------------------|---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `LogAndContinue` (default) | Emits a `LogEntryEvent__e` via `LOG_Builder` with `LogLevel__c = ERROR`, the action identity, the record id, and the original error message. **DML proceeds.** | Orchestration, derived-field population, notifications, supplemental logging — anything where a single action's failure should be visible but should not block the user's save. |
| `BlockDml`                 | Calls `record.addError(formattedMessage)` to block DML. Surfaces the error to the user.                                                                        | Validation actions where the trigger should reject records that fail the action's checks.                                                                                       |

The formatted error message for flow actions has the shape:

```text
[{flowName}] {originalActionError} (record: {recordId})
```

The action-identity prefix lets a user (or admin debugging from the Setup audit log) identify which
`TriggerAction__mdt` row produced the error. The record id suffix correlates against the `LogEntry__c` audit
history for the same record.

> **Governor exceptions always rethrow.** `System.LimitException` (CPU, heap, SOQL row limits) is rethrown
> regardless of `FailureAction__c`. The dispatcher only intercepts business-logic exceptions; it never swallows
> a governor breach.

### Cross-namespace flow resolution

`FlowName__c` accepts a **bare flow API name** — never a namespace-qualified name. The framework resolves the namespace
internally by calling the 2-arg form `Flow.Interview.createInterview(flowName, variables)`, which returns the active
flow regardless of whether it lives in the kern namespace or the subscriber namespace.

- A `FlowName__c` value of `Account_SetDefaults` resolves to the subscriber-namespace flow when the dispatching CMDT
  row is in the subscriber's package, and to the kern-namespace flow when the row is in the kern package. Both work
  from the same field shape.
- Authors should not prefix `FlowName__c` with `kern.` or any other namespace. A namespace prefix in this field
  produces a deploy-time scanner error and a runtime configuration error.

### Recommended-default pattern matrix

When you ship a flow-action row, default these fields based on the flow's purpose:

| Flow purpose                                                              | `FailureAction__c` | `AllowRecursion__c` | Notes                                                                    |
|---------------------------------------------------------------------------|--------------------|---------------------|--------------------------------------------------------------------------|
| Orchestration (set defaults, populate derived fields, send notifications) | `LogAndContinue`   | `true`              | Default shape — production-resilient, audit-visible.                     |
| Validation (reject records that fail business rules)                      | `BlockDml`         | `true`              | Surfaces the flow's error to the user.                                   |
| Cascading update (writes to related records)                              | `LogAndContinue`   | `false`             | Block recursion on the originating object to avoid unintended self-fire. |

### Audit volume control

Every flow-action invocation can emit a `LogEntryEvent__e` audit entry. Volume is controlled by
`LogSetting__c.EnableFlowActionLogging__c` — a 3-state field shared by the org or layered per-user (mirrors the
existing `LogLevelThreshold__c` precedent on the same custom setting):

| Value                  | Success path                                                                                                           | Error path                                                                 | When to use                                                                                                                       |
|------------------------|------------------------------------------------------------------------------------------------------------------------|----------------------------------------------------------------------------|-----------------------------------------------------------------------------------------------------------------------------------|
| `Off`                  | No emission                                                                                                            | No emission                                                                | Integration-only orgs where audit volume is excessive and external observability already covers the path.                         |
| `ErrorsOnly` (default) | No emission                                                                                                            | One entry per failed record (with `RecordId__c` set, queryable per-record) | Production default — bounded volume, full forensic coverage of failures.                                                          |
| `AlwaysOn`             | One per-batch summary entry per dispatch (record ids serialised into `ContextData__c.recordIds`, `RecordId__c = null`) | One entry per failed record                                                | High-regulation orgs where every flow trigger run must be evidenced. Heavy DML multiplies entry volume — measure before flipping. |

Performance logging is separate from audit logging and is always sparse (only emits when an action exceeds its
`PerformanceThresholdMs__c`). The two log streams can be queried independently, and the perf log entry includes
`flowName` as a context dimension so subscribers can filter perf logs by flow.

### Bypass and rollback

Two options, in priority order from most-surgical to most-broad:

1. **Per-row declarative bypass (recommended for surgical disable).** Set `BypassExecution__c = true` on the specific
   `TriggerAction__mdt` row. One-row CMDT deploy disables this flow action and only this flow action.
2. **Per-row feature-flag bypass (recommended for staged rollout).** Set the row's `RequiredFeatureFlag__c` to a
   `FeatureFlag__mdt` record and flip its `IsEnabledByDefault__c` to `false`. Useful when several flow actions need
   to be gated together — point them all at the same feature flag and flip the flag once.

Per-flow surgical bypass via Apex (e.g. `bypassFlow('Account_SetDefaults')`) is not provided. To disable a specific
flow action, use option 1 or option 2 above.

### Migrating from TAF to KernDX

Both frameworks invoke a flow once per record and follow the same authoring contract — the auto-launched flow
declares a `record` variable matching the trigger object. Migration is a metadata-only field rename on the
`Trigger_Action__mdt` records:

```xml
<!-- BEFORE (TAF) -->
<values><field>Apex_Class_Name__c</field><value xsi:type="xsd:string">TriggerActionFlow</value></values>
<values><field>Flow_Name__c</field><value xsi:type="xsd:string">Account_SetDefaults</value></values>

<!-- AFTER (KernDX) -->
<values><field>kern__FlowName__c</field><value xsi:type="xsd:string">Account_SetDefaults</value></values>
<values><field>kern__FailureAction__c</field><value xsi:type="xsd:string">LogAndContinue</value></values>
```

The flow itself does not change. Note that `kern__ApexClassName__c` is **omitted** from KernDX flow rows — the
framework dispatches via its built-in flow runner whenever `FlowName__c` is populated and `ApexClassName__c` is
blank. Setting both fields fails the `MutuallyExclusiveTarget` validation rule.

`FailureAction__c` defaults to `LogAndContinue` if left blank — explicitly specify it on every record so future
readers don't have to look up framework defaults to know how the row will behave.

---

## Change Data Capture Actions

[Change Data Capture](https://developer.salesforce.com/docs/atlas.en-us.change_data_capture.meta/change_data_capture/cdc_intro.htm)
publishes a Change Event whenever a record is created, updated, deleted, or undeleted. KernDX runs trigger actions on
those Change Events through the same metadata-driven framework you already use for object triggers — so you can react
to committed changes (including changes made by Bulk API jobs, integrations, or other packages) with ordered,
bypassable, feature-flag-gated actions written in Apex or Flow.

A Change Event action runs **after** the change has committed. There is no before-phase and nothing to roll back: the
event is a notification that the change already happened.

### The Change Event trigger

A Change Event entity gets the same one-line physical trigger as any object. Change Events are insert-only from the
subscriber's side, so the trigger handles `after insert`:

```apex
trigger TRG_FoobarChangeEvent on Foobar__ChangeEvent (after insert)
{
	new TRG_Dispatcher().run();
}
```

Each delivered event is one record in the action's incoming list. A single event can represent a change to several
records of the same object, because the platform batches changes committed together.

> **Enabling Change Data Capture:** the Change Event entity (`Foobar__ChangeEvent`) only exists once CDC is switched
> on for the object — in **Setup → Change Data Capture**, or by deploying a `PlatformEventChannel` and
> `PlatformEventChannelMember`. The framework does not enable CDC for you.

### Registering a Change Event action

Change Event entities cannot be selected in the **SObject Type** relationship picklist on `TriggerSetting__mdt` — the
platform excludes them from that lookup. Register the setting with the **Object API Name Override** field instead:

| Field                      | Value for a CDC setting                                                                                    |
|----------------------------|------------------------------------------------------------------------------------------------------------|
| `ObjectApiNameOverride__c` | The Change Event API name, e.g. `Foobar__ChangeEvent`. This is what the dispatcher routes on.              |
| `SObjectType__c`           | Optional. Set it to the source object (`Foobar__c`) for documentation; the override wins at dispatch time. |

At least one of the two fields must be populated. If both are blank, the deploy fails with the `RequireObjectIdentifier`
validation rule:

> Set either SObject Type (for standard objects, custom objects, and platform events) or Object API Name Override (for
> Change Data Capture entities). At least one must be populated.

Once the setting exists, register `TriggerAction__mdt` rows against it exactly as you would for any object — set
`Event__c` to `After Insert`, and populate either `ApexClassName__c` (for an Apex action) or `FlowName__c` (for a flow
action).

### Reading the change header

Every Change Event carries a header describing what changed — the change type, the affected record IDs, the changed
field names, and commit metadata.

**Apex actions** read the platform header straight off the event record:

```apex
public inherited sharing class TRG_FoobarChangeAudit extends TRG_Base implements IF_Trigger.AfterInsert
{
	public void afterInsert(List<SObject> changeEvents)
	{
		for(SObject changeEvent : changeEvents)
		{
			EventBus.ChangeEventHeader header =
				(EventBus.ChangeEventHeader)changeEvent.get('ChangeEventHeader');

			LOG_Builder.build()
				.info(header.changeType + ' affected ' + header.recordIds.size() + ' record(s)')
				.emitAt('TRG_FoobarChangeAudit');
		}
	}
}
```

**Flow actions** receive the header as a strongly-typed input variable. Beyond the standard `record` input (which holds
the Change Event itself), a flow registered against a Change Event entity also receives a variable named `header` of
type [`DTO_ChangeEventHeader`](reference/apex/DTO_ChangeEventHeader.md). Declare an Apex-defined variable on the flow:

- **Variable name:** `header`
- **Type:** Apex-Defined
- **Apex Class:** `DTO_ChangeEventHeader`

The framework projects the platform header onto the DTO and populates `header` before the interview runs — you write no
Apex to bridge it. Read its fields in assignments and decisions, for example `header.changeType`, `header.recordIds`,
and `header.changedFields`.

The header exposes the supported subset of the platform's change-event metadata:

| Field                                             | Description                                                                                       |
|---------------------------------------------------|---------------------------------------------------------------------------------------------------|
| `changeType`                                      | `CREATE`, `UPDATE`, `DELETE`, `UNDELETE`, or a `GAP_*` replay-gap notification.                   |
| `recordIds`                                       | The source record IDs this event covers.                                                          |
| `changedFields`                                   | The fields whose values changed in this commit.                                                   |
| `entityName`                                      | The source object API name (`Foobar__c`) — not the Change Event suffix.                           |
| `changeOrigin`                                    | The change's origin; useful for filtering out self-initiated changes.                             |
| `commitTimestamp` / `commitUser` / `commitNumber` | Commit metadata — note `commitTimestamp` is Unix epoch milliseconds (a `Long`), not a `Datetime`. |
| `transactionKey` / `sequenceNumber`               | Correlate changes from the same atomic transaction.                                               |
| `nulledFields` / `diffFields`                     | Fields nulled, and large/complex fields that differ from the prior commit.                        |

See the [`DTO_ChangeEventHeader` reference](reference/apex/DTO_ChangeEventHeader.md) for the full field list.

### Block DML is unavailable for Change Data Capture

`FailureAction__c = BlockDml` cannot apply to a Change Event action. Block DML works by calling `addError(...)` to abort
an in-progress save — but a Change Event is delivered *after* the change has already committed, so there is nothing left
to block. Two layers keep you from configuring it by accident:

- **At deploy:** the flow-reference scanner (`npm run scan:flow-references`) rejects a Change Event *flow* row whose
  `FailureAction__c` is `BlockDml`, and points you to `LogAndContinue`. (Apex Change Event actions are caught by the
  runtime layer below.)
- **At runtime:** if such a row reaches dispatch anyway, the framework degrades it to `LogAndContinue` and emits a
  distinct warning audit entry so you can find the misconfiguration:

> BlockDml is not supported on Change Event dispatch (cannot roll back a committed change) — degraded to LogAndContinue:
> {flow name}

Always use `LogAndContinue` (the default) for Change Event actions. A failed Change Event action records the error and
the dispatch continues; the underlying data is already committed regardless.

> **Audit volume:** when a Change Event flow action emits an audit entry, the affected record IDs are aggregated into a
> single entry per dispatch rather than one entry per record, so high-throughput CDC does not flood the audit log.

---

## Post-Trigger Actions

A **post-trigger action** is an Apex class that runs **once at the very end of a trigger transaction**, after every
trigger action on every object has finished. It exists for transaction-scoped or cross-object work that does not belong
inside any single object's trigger action — for example, aggregating one audit summary for the whole transaction,
enqueuing a single asynchronous job, or emitting transaction-wide telemetry.

Post-trigger actions are registered with `PostTriggerAction__mdt` and inherit the framework's ordering, feature-flag
gating, bypass, and performance monitoring.

### When post-trigger actions fire

Post-trigger actions fire **once per outermost trigger dispatch**:

- **Nested DML does not re-fire them.** If a trigger action performs DML on another object, that nested dispatch does
  not run post-actions — the framework fires them only when the outermost dispatch unwinds, so they run exactly once no
  matter how deeply triggers nest.
- **Multiple top-level DML statements fire them multiple times.** A transaction with several independent top-level DML
  statements runs post-actions once for each of them — once as each top-level dispatch completes. Write post-actions to
  be safe to run more than once in a transaction.
- **Asynchronous and platform-event work gets its own firing.** A Queueable, future, scheduled job, or platform-event
  subscriber runs in a fresh transaction, so its triggers produce their own outermost dispatch and their own
  post-action firing.

### The no-DML contract

**A post-trigger action must not perform synchronous DML.** After your `execute(...)` returns, the framework checks
whether any synchronous DML ran and throws if it did — and this **always fails the transaction**, regardless of the
row's Failure Action, because it is a contract violation rather than a runtime fault. The error names the offending
class:

> Post-trigger action "{class}" performed synchronous DML. Post-trigger actions run once after all trigger actions
> complete and must not perform synchronous DML (compute, log, or enqueue async only).

To change data from a post-action, use an **asynchronous** path: enqueue a Queueable, future, or scheduled job, or
publish a Platform Event. These are the supported escape hatches and do not trip the guard.

### Intended uses and anti-patterns

| Good fit (use a post-trigger action)                                        | Poor fit (use a normal trigger action instead)                 |
|-----------------------------------------------------------------------------|----------------------------------------------------------------|
| Aggregating one audit or telemetry summary for the whole transaction        | Per-record validation or field defaulting                      |
| Enqueuing a single async job for everything touched in the transaction      | Creating or updating related records (that is synchronous DML) |
| Cross-object orchestration that must run after all object triggers complete | Logic that needs per-record old/new values                     |
| Transaction-wide metrics or instrumentation                                 | Object-specific business logic                                 |

A post-trigger action has no per-record context — only the set of SObject *types* whose triggers fired — and cannot do
synchronous DML. Anything that needs a specific record's values, or that writes data, belongs in a normal trigger action
on the relevant object.

### Writing a post-trigger action

Implement `IF_Trigger.PostAction`:

```apex
public inherited sharing class TRG_EmitTransactionAudit implements IF_Trigger.PostAction
{
	public void execute(IF_Trigger.PostActionContext context)
	{
		if(context.touchedSObjectTypes.isEmpty())
		{
			return;
		}

		LOG_Builder.build()
			.info('Transaction touched ' + context.touchedSObjectTypes.size() + ' SObject type(s)')
			.emitAt('TRG_EmitTransactionAudit');
	}
}
```

`context.touchedSObjectTypes` is a read-only `Set<SObjectType>` — the SObject types whose triggers participated in the
transaction. Branch on it to decide what to do:

```apex
if(context.touchedSObjectTypes.contains(Account.SObjectType))
{
	// Account triggers ran in this transaction — do Account-domain follow-up.
}
```

The set carries types, not record IDs, by design: a post-action runs once for the whole transaction with no per-record
context, and type-level scoping keeps it bounded in batch operations while keeping one post-action from accidentally
seeing record data that another post-action staged. If you need per-record context, have your trigger actions record it
in their own static variable and read that static from the post-action.

### Registering a post-trigger action

Create a `PostTriggerAction__mdt` record. See the
[`PostTriggerAction__mdt` reference](reference/metadata/PostTriggerAction__mdt.md) for the complete field list.

| Field                                                      | Purpose                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                           |
|------------------------------------------------------------|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `ApexClassName__c`                                         | The class implementing `IF_Trigger.PostAction`.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                   |
| `Order__c`                                                 | Execution sequence (lower runs first). Rows sharing an order value have no guaranteed sequence.                                                                                                                                                                                                                                                                                                                                                                                                                                   |
| `Description__c`                                           | What the post-action does and why it exists.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      |
| `FailureAction__c`                                         | How an unhandled error is handled. **Log and Continue** (the default) records the error in the audit log and lets the transaction proceed — best for non-critical follow-up such as notifications or telemetry. **Block DML** rethrows the error so the originating DML rolls back — choose it when the post-action must be guaranteed to complete before any data is committed. Either way, governor-limit exceptions always propagate, and a synchronous-DML violation always fails the transaction regardless of this setting. |
| `RequiredFeatureFlag__c` / `BypassFeatureFlag__c`          | Feature-flag gating — run only when a flag is on, or skip when a flag is on. Same model as trigger actions.                                                                                                                                                                                                                                                                                                                                                                                                                       |
| `BypassExecution__c`                                       | Unconditional kill switch — when checked, the post-action is skipped for everyone.                                                                                                                                                                                                                                                                                                                                                                                                                                                |
| `TriggerSetting__c`                                        | Optional scope. Leave blank to fire on every outermost dispatch (cross-object work). Set it to a Trigger Setting to fire **only** when that setting's object participated in the transaction.                                                                                                                                                                                                                                                                                                                                     |
| `EntryCriteriaContextClassName__c`                         | Optional Apex evaluator implementing `IF_Trigger.PostActionEntryCriteria`. Its `shouldRun(context)` gates the action — return `false` to skip. Use for conditions richer than the Trigger Setting scope.                                                                                                                                                                                                                                                                                                                          |
| `PerformanceThresholdMs__c` / `ForcePerformanceLogging__c` | Per-action performance monitoring — log when the action runs longer than the threshold, or force its timing to be logged every time. Inherits the global default when blank.                                                                                                                                                                                                                                                                                                                                                      |

Bypass Execution is applied first, at query time — the framework loads only non-bypassed rows. The surviving rows are
then gated in order, cheapest check first, and the framework stops at the first gate that excludes a row: feature flags
→ Trigger Setting scope → entry-criteria evaluator → run.

An entry-criteria evaluator looks like:

```apex
public inherited sharing class TRG_PostActionRequireAccount implements IF_Trigger.PostActionEntryCriteria
{
	public Boolean shouldRun(IF_Trigger.PostActionContext context)
	{
		return context.touchedSObjectTypes.contains(Account.SObjectType)
			&& UTIL_FeatureFlag.isEnabled('Account_Followup_Enabled');
	}
}
```

---

## Trigger Action Interfaces

### [IF_Trigger.BeforeInsert](reference/apex/IF_Trigger.BeforeInsert.md)

**Purpose:** Execute logic before records are inserted.

**Method Signature:**

```apex
void beforeInsert(List<SObject> newRecords)
```

**Parameters:**

- `newRecords` - List of SObjects being inserted (mutable, no IDs)

**Use Cases:**

- Set default field values
- Populate calculated fields
- Validate data before save
- Cross-record validation

**Example:**

```apex
public inherited sharing class TRG_ValidateAccount extends TRG_Base implements IF_Trigger.BeforeInsert
{
	public void beforeInsert(List<Account> newAccounts)
	{
		for(Account account : newAccounts)
		{
			// Validate: Annual revenue must be positive
			if(account.AnnualRevenue != null && account.AnnualRevenue < 0)
			{
				account.AnnualRevenue.addError('Annual Revenue must be positive');
			}

			// Default: Set industry if blank
			if(String.isBlank(account.Industry))
			{
				account.Industry = 'Other';
			}
		}
	}
}
```

### [IF_Trigger.AfterInsert](reference/apex/IF_Trigger.AfterInsert.md)

**Purpose:** Execute logic after records are inserted.

**Method Signature:**

```apex
void afterInsert(List<SObject> newRecords)
```

**Parameters:**

- `newRecords` - List of inserted SObjects (read-only, have IDs)

**Use Cases:**

- Create related records
- Send notifications
- Publish [platform events](https://developer.salesforce.com/docs/atlas.en-us.platform_events.meta/platform_events/platform_events_intro.htm)
- Update parent/child records

**Example:**

```apex
public inherited sharing class TRG_CreateWelcomeTask extends TRG_Base implements IF_Trigger.AfterInsert
{
	public void afterInsert(List<Account> newAccounts)
	{
		List<Task> tasksToInsert = new List<Task>();

		for(Account account : newAccounts)
		{
			tasksToInsert.add(new Task(
				WhatId = account.Id,
				Subject = 'Welcome New Account',
				OwnerId = account.OwnerId,
				ActivityDate = System.today().addDays(7),
				Priority = 'Normal'
			));
		}

		if(!tasksToInsert.isEmpty())
		{
			DML_Builder.newTransaction().doInsert(tasksToInsert).execute();
		}
	}
}
```

### [IF_Trigger.BeforeUpdate](reference/apex/IF_Trigger.BeforeUpdate.md)

**Purpose:** Execute logic before records are updated.

**Method Signature:**

```apex
void beforeUpdate(List<SObject> newRecords, List<SObject> oldRecords)
```

**Parameters:**

- `newRecords` - List of SObjects being updated (mutable)
- `oldRecords` - List of SObjects before update (read-only)

**Use Cases:**

- Track field changes
- Validate changes
- Update audit fields
- Prevent updates under conditions

**Example:**

```apex
public inherited sharing class TRG_TrackStatusChange extends TRG_Base implements IF_Trigger.BeforeUpdate
{
	public void beforeUpdate(List<Account> newAccounts, List<Account> oldAccounts)
	{
		for(Integer i = 0; i < newAccounts.size(); i++)
		{
			Account newAccount = newAccounts.get(i);
			Account oldAccount = oldAccounts.get(i);

			// Track status changes
			if(newAccount.Status__c != oldAccount.Status__c)
			{
				newAccount.StatusChangeDate__c = System.now();
				newAccount.PreviousStatus__c = oldAccount.Status__c;
			}
		}
	}
}
```

### [IF_Trigger.AfterUpdate](reference/apex/IF_Trigger.AfterUpdate.md)

**Purpose:** Execute logic after records are updated.

**Method Signature:**

```apex
void afterUpdate(List<SObject> newRecords, List<SObject> oldRecords)
```

**Parameters:**

- `newRecords` - List of updated SObjects (read-only)
- `oldRecords` - List of SObjects before update (read-only)

**Use Cases:**

- Cascade updates to related records
- Create history records
- Send change notifications
- Update rollup summaries

**Example:**

```apex
public inherited sharing class TRG_CascadePhoneUpdate extends TRG_Base implements IF_Trigger.AfterUpdate
{
	public void afterUpdate(List<Account> newAccounts, List<Account> oldAccounts)
	{
		Map<Id, String> accountIdToNewPhone = new Map<Id, String>();

		// Identify accounts with phone changes
		for(Integer i = 0; i < newAccounts.size(); i++)
		{
			Account newAccount = newAccounts.get(i);
			Account oldAccount = oldAccounts.get(i);

			if(newAccount.Phone != oldAccount.Phone)
			{
				accountIdToNewPhone.put(newAccount.Id, newAccount.Phone);
			}
		}

		if(!accountIdToNewPhone.isEmpty())
		{
			// Query and update contacts using QRY_Builder
			List<Contact> contactsToUpdate = QRY_Builder.selectFrom(Contact.SObjectType)
				.addFields(new List<SObjectField>{Contact.Id, Contact.AccountId, Contact.Phone})
				.condition(Contact.AccountId).isIn(accountIdToNewPhone.keySet())
				.toList();

			for(Contact contact : contactsToUpdate)
			{
				contact.Phone = accountIdToNewPhone.get(contact.AccountId);
			}

			if(!contactsToUpdate.isEmpty())
			{
				DML_Builder.newTransaction().doUpdate(contactsToUpdate).execute();
			}
		}
	}
}
```

### [IF_Trigger.BeforeDelete](reference/apex/IF_Trigger.BeforeDelete.md)

**Purpose:** Execute logic before records are deleted.

**Method Signature:**

```apex
void beforeDelete(List<SObject> oldRecords)
```

**Parameters:**

- `oldRecords` - List of SObjects being deleted (read-only)

**Use Cases:**

- Prevent deletion under conditions
- Validate deletion is allowed
- Archive data before deletion

**Example:**

```apex
public inherited sharing class TRG_PreventStrategicAccountDeletion extends TRG_Base implements IF_Trigger.BeforeDelete
{
	public void beforeDelete(List<Account> oldAccounts)
	{
		for(Account account : oldAccounts)
		{
			if(account.Type == 'Strategic' || account.Type == 'Partner')
			{
				account.addError('Cannot delete Strategic or Partner accounts. Please contact your administrator.');
			}
		}
	}
}
```

### [IF_Trigger.AfterDelete](reference/apex/IF_Trigger.AfterDelete.md)

**Purpose:** Execute logic after records are deleted.

**Method Signature:**

```apex
void afterDelete(List<SObject> oldRecords)
```

**Parameters:**

- `oldRecords` - List of deleted SObjects (read-only)

**Use Cases:**

- Clean up related records
- Log deletions
- Archive deleted data
- Update summary counts

**Example:**

```apex
public inherited sharing class TRG_LogAccountDeletion extends TRG_Base implements IF_Trigger.AfterDelete
{
	public void afterDelete(List<Account> oldAccounts)
	{
		List<AuditLog__c> logsToInsert = new List<AuditLog__c>();

		for(Account account : oldAccounts)
		{
			logsToInsert.add(new AuditLog__c(
				Type__c = 'Account Deletion',
				Message__c = 'Account deleted: ' + account.Name,
				RecordId__c = account.Id,
				DeletedBy__c = UserInfo.getUserId(),
				DeletedDate__c = System.now()
			));
		}

		if(!logsToInsert.isEmpty())
		{
			DML_Builder.newTransaction().doInsert(logsToInsert).execute();
		}
	}
}
```

### [IF_Trigger.AfterUndelete](reference/apex/IF_Trigger.AfterUndelete.md)

**Purpose:** Execute logic after records are undeleted.

**Method Signature:**

```apex
void afterUndelete(List<SObject> newRecords)
```

**Parameters:**

- `newRecords` - List of undeleted SObjects (read-only, have IDs)

**Use Cases:**

- Restore related records
- Send notifications
- Create review tasks
- Reset fields

**Example:**

```apex
public inherited sharing class TRG_CreateRestoreReviewTask extends TRG_Base implements IF_Trigger.AfterUndelete
{
	public void afterUndelete(List<Account> newAccounts)
	{
		List<Task> tasksToInsert = new List<Task>();

		for(Account account : newAccounts)
		{
			tasksToInsert.add(new Task(
				WhatId = account.Id,
				Subject = 'Review Restored Account',
				OwnerId = account.OwnerId,
				Priority = 'High',
				ActivityDate = System.today(),
				Description = 'This account was restored from the Recycle Bin. Please review and verify data integrity.'
			));
		}

		if(!tasksToInsert.isEmpty())
		{
			DML_Builder.newTransaction().doInsert(tasksToInsert).execute();
		}
	}
}
```

---

## Caching with Trigger Actions

One of the most powerful features of the Trigger Action Framework is the ability to cache data using ordered actions. **Early actions can query and cache data that later actions
consume**, eliminating redundant SOQL queries and improving performance.

### Caching Pattern Overview

**Concept:** Trigger actions act like functions in a pipeline. An early action can cache data in a static variable, and later actions can access that cache.

**Benefits:**

- Avoid SOQL in loops
- Reduce total SOQL queries
- Share data between multiple actions
- Improve performance
- Maintain bulkification

### Implementation Pattern

#### Step 1: Create Caching Action

```apex
/**
 * @description Caches related Contact data for Account trigger actions.
 * This action runs first (Order: 10) to load data for later actions.
 *
 * @see TRG_CacheAccountContacts_TEST
 *
 * @author <your-author-tag>
 *
 * @group Trigger Actions
 *
 * @date January 2025
 */
public inherited sharing class TRG_CacheAccountContacts extends TRG_Base implements
	IF_Trigger.BeforeUpdate,
	IF_Trigger.AfterUpdate
{
	/**
	 * @description Static cache shared across all actions in this transaction.
	 * Key: Account Id
	 * Value: List of Contacts for that Account
	 */
	@TestVisible
	private static Map<Id, List<Contact>> contactsByAccountId;

	/**
	 * @description Queries and caches Contact data before update context.
	 *
	 * @param newAccounts Accounts being updated
	 * @param oldAccounts Accounts before update
	 */
	public void beforeUpdate(List<Account> newAccounts, List<Account> oldAccounts)
	{
		loadContactCache(newAccounts);
	}

	/**
	 * @description Queries and caches Contact data after update context.
	 *
	 * @param newAccounts Updated accounts
	 * @param oldAccounts Accounts before update
	 */
	public void afterUpdate(List<Account> newAccounts, List<Account> oldAccounts)
	{
		loadContactCache(newAccounts);
	}

	/**
	 * @description Loads Contact data into static cache for use by other actions.
	 *
	 * @param accounts Accounts to cache contacts for
	 */
	private static void loadContactCache(List<Account> accounts)
	{
		contactsByAccountId = new Map<Id, List<Contact>>();
		Set<Id> accountIds = new Map<Id, Account>(accounts).keySet();

		// Query all contacts for these accounts
		List<Contact> contacts = QRY_Builder.selectFrom(Contact.SObjectType)
			.addFields(new List<SObjectField>{Contact.Id, Contact.AccountId, Contact.FirstName, Contact.LastName, Contact.Email, Contact.Phone, Contact.Title})
			.condition(Contact.AccountId).isIn(accountIds)
			.toList();

		// Build cache map
		for(Contact contact : contacts)
		{
			if(!contactsByAccountId.containsKey(contact.AccountId))
			{
				contactsByAccountId.put(contact.AccountId, new List<Contact>());
			}
			contactsByAccountId.get(contact.AccountId).add(contact);
		}
	}

	/**
	 * @description Public getter for other actions to access cached data.
	 *
	 * @param accountId The Account Id to get contacts for
	 *
	 * @return List of Contacts for the account, or empty list if none
	 */
	public static List<Contact> getCachedContacts(Id accountId)
	{
		if(contactsByAccountId == null || !contactsByAccountId.containsKey(accountId))
		{
			return new List<Contact>();
		}
		return contactsByAccountId.get(accountId);
	}

	/**
	 * @description Clears the cache (useful for testing).
	 */
	@TestVisible
	private static void clearCache()
	{
		contactsByAccountId = null;
	}
}
```

#### Step 2: Create Actions That Use Cache

```apex
/**
 * @description Validates that premium accounts have at least one contact.
 * Uses cached Contact data from TRG_CacheAccountContacts.
 *
 * @see TRG_ValidatePremiumAccountContacts_TEST
 *
 * @author <your-author-tag>
 *
 * @group Trigger Actions
 *
 * @date January 2025
 */
public inherited sharing class TRG_ValidatePremiumAccountContacts extends TRG_Base implements IF_Trigger.BeforeUpdate
{
	/**
	 * @description Validates premium accounts have contacts.
	 * Consumes data from TRG_CacheAccountContacts cache.
	 *
	 * @param newAccounts Accounts being updated
	 * @param oldAccounts Accounts before update
	 */
	public void beforeUpdate(List<Account> newAccounts, List<Account> oldAccounts)
	{
		for(Account account : newAccounts)
		{
			if(account.Type == 'Premium')
			{
				// Get cached contacts (no SOQL query!)
				List<Contact> contacts = TRG_CacheAccountContacts.getCachedContacts(account.Id);

				if(contacts.isEmpty())
				{
					account.addError('Premium accounts must have at least one contact. Please add a contact before changing to Premium tier.');
				}
			}
		}
	}
}
```

```apex
/**
 * @description Updates Account summary fields based on Contact data.
 * Uses cached Contact data from TRG_CacheAccountContacts.
 *
 * @see TRG_UpdateAccountContactSummary_TEST
 *
 * @author <your-author-tag>
 *
 * @group Trigger Actions
 *
 * @date January 2025
 */
public inherited sharing class TRG_UpdateAccountContactSummary extends TRG_Base implements IF_Trigger.BeforeUpdate
{
	/**
	 * @description Updates contact count and primary contact name.
	 * Consumes data from TRG_CacheAccountContacts cache.
	 *
	 * @param newAccounts Accounts being updated
	 * @param oldAccounts Accounts before update
	 */
	public void beforeUpdate(List<Account> newAccounts, List<Account> oldAccounts)
	{
		for(Account account : newAccounts)
		{
			// Get cached contacts (no SOQL query!)
			List<Contact> contacts = TRG_CacheAccountContacts.getCachedContacts(account.Id);

			// Update contact count
			account.NumberOfContacts__c = contacts.size();

			// Set primary contact name
			if(!contacts.isEmpty())
			{
				Contact primaryContact = contacts[0]; // First contact
				account.PrimaryContactName__c = primaryContact.FirstName + ' ' + primaryContact.LastName;
			}
			else
			{
				account.PrimaryContactName__c = null;
			}
		}
	}
}
```

#### Step 3: Configure Metadata with Correct Order

**TriggerAction__mdt for Caching Action:**

```text
Label: Cache Account Contacts
Developer Name: Account_CacheContacts
Apex Class Name: TRG_CacheAccountContacts
Before Update: Account_Trigger_Setting
Order: 10
Description: Queries and caches Contact data for use by later actions
```

**TriggerAction__mdt for Validation Action:**

```text
Label: Validate Premium Account Contacts
Developer Name: Account_ValidatePremiumContacts
Apex Class Name: TRG_ValidatePremiumAccountContacts
Before Update: Account_Trigger_Setting
Order: 20
Description: Validates premium accounts have at least one contact using cached data
```

**TriggerAction__mdt for Summary Action:**

```text
Label: Update Account Contact Summary
Developer Name: Account_UpdateContactSummary
Apex Class Name: TRG_UpdateAccountContactSummary
Before Update: Account_Trigger_Setting
Order: 30
Description: Updates NumberOfContacts__c and PrimaryContactName__c using cached data
```

### Execution Flow

```text
Trigger fires on Account update
|
TRG_Dispatcher.run()
|
1. Order 10: TRG_CacheAccountContacts.beforeUpdate()
   +-- Queries Contacts, populates contactsByAccountId cache
|
2. Order 20: TRG_ValidatePremiumAccountContacts.beforeUpdate()
   +-- Calls TRG_CacheAccountContacts.getCachedContacts()
   +-- Uses cached data (no SOQL!)
|
3. Order 30: TRG_UpdateAccountContactSummary.beforeUpdate()
   +-- Calls TRG_CacheAccountContacts.getCachedContacts()
   +-- Uses cached data (no SOQL!)
```

### Best Practices for Caching

- **Use Static Variables**: Cache data in `private static` variables
- **Order Matters**: Caching action must have lower Order__c
- **Provide Getters**: Expose cached data via public static methods
- **Handle Nulls**: Return empty collections if cache not populated
- **Clear in Tests**: Provide `@TestVisible` clear methods for tests
- **Document Dependencies**: Note in ApexDoc which actions depend on cache
- **Same Context**: Caching only works within same trigger context

### Testing Cached Actions

```apex
/**
 * @description Tests TRG_ValidatePremiumAccountContacts uses cache correctly
 *
 * @see TRG_ValidatePremiumAccountContacts
 *
 * @author <your-author-tag>
 *
 * @date January 2025
 */
@IsTest(SeeAllData=false IsParallel=true)
private class TRG_ValidatePremiumAccountContacts_TEST
{
	/**
	 * @description Tests validation fails when no contacts and uses cache
	 */
	@IsTest
	private static void beforeUpdate_givenPremiumWithNoContacts_shouldError()
	{
		Account testAccount = (Account)TST_Builder.of(Account.SObjectType)
			.withOverrides(new Map<String, Object>
			{
				'Name' => 'Test Account',
				'Type' => 'Standard'
			})
			.build();

		Test.startTest();
		testAccount.Type = 'Premium';
		Database.SaveResult result = Database.update(testAccount, false);
		Test.stopTest();

		Assert.isFalse(result.isSuccess(), 'Should fail validation');
		Assert.isTrue(result.getErrors()[0].getMessage().contains('contact'), 'Error should mention contacts');
	}

	/**
	 * @description Tests validation passes when contacts exist
	 */
	@IsTest
	private static void beforeUpdate_givenPremiumWithContacts_shouldSucceed()
	{
		Account testAccount = (Account)TST_Builder.of(Account.SObjectType)
			.withOverrides(new Map<String, Object>
			{
				'Name' => 'Test Account',
				'Type' => 'Standard'
			})
			.build();

		Contact testContact = (Contact)TST_Builder.of(Contact.SObjectType)
			.withOverrides(new Map<String, Object>
			{
				'AccountId' => testAccount.Id,
				'LastName' => 'Test Contact'
			})
			.build();

		Test.startTest();
		testAccount.Type = 'Premium';
		DML_Builder.newTransaction().doUpdate(testAccount).execute();
		Test.stopTest();

		testAccount = (Account)QRY_Builder.selectFrom(Account.SObjectType)
			.addField(Account.Type)
			.condition(Account.Id).equals(testAccount.Id)
			.getFirst();
		Assert.areEqual('Premium', testAccount.Type, 'Should update to Premium successfully');
	}
}
```

---

## Function-Like Coordination

Trigger actions act like **functions in a pipeline**, where:

- Each action has a **single, focused responsibility**
- Actions execute in a **defined order** (like function calls)
- Actions can be **composed** to create complex behavior
- Data flows through actions via **shared caches or DML results**

### Coordination Patterns

#### Pattern 1: Sequential Processing

**Use Case:** Multiple validations that must all pass.

**Configuration:**

```text
Order 10: TRG_ValidateRequiredFields
Order 20: TRG_ValidateBusinessRules
Order 30: TRG_ValidateRelatedRecords
```

**Effect:** Each validation runs in sequence. If Order 10 adds an error, Orders 20 and 30 still execute (all errors are collected).

#### Pattern 2: Data Preparation - Processing

**Use Case:** Load data, then use it for multiple operations.

**Configuration:**

```text
Order 10: TRG_CacheRelatedData (queries and caches)
Order 20: TRG_ValidateUsingCache (uses cache)
Order 30: TRG_PopulateFieldsUsingCache (uses cache)
Order 40: TRG_CreateRelatedRecords (uses cache)
```

**Effect:** Single SOQL query in Order 10, reused by all later actions.

#### Pattern 3: Conditional Execution via Entry Criteria

**Use Case:** Different actions for different record types.

**Configuration:**

```text
Order 10: TRG_ProcessPremiumAccounts
  Entry Criteria: isPremiumTier

Order 20: TRG_ProcessStandardAccounts
  Entry Criteria: NOT(isPremiumTier)
```

**Effect:** Actions only receive records matching their criteria.

#### Pattern 4: Progressive Enhancement

**Use Case:** Build up record data through multiple stages.

**Configuration:**

```text
Order 10: TRG_SetDefaultValues (populate defaults)
Order 20: TRG_CalculateDerivedFields (calculate based on defaults)
Order 30: TRG_EnrichFromExternalData (API callout if needed)
Order 40: TRG_FinalizeRecord (final validation)
```

**Effect:** Each action builds on previous actions' work.

#### Pattern 5: Functional Composition

**Use Case:** Reuse actions across objects with different orderings.

**Account Configuration:**

```text
Order 10: TRG_SetExternalReference
Order 20: TRG_ValidateEmailFormat
Order 30: TRG_NotifyOwner
```

**Contact Configuration:**

```text
Order 10: TRG_SetExternalReference (same action!)
Order 20: TRG_ValidateEmailFormat (same action!)
Order 30: TRG_UpdateAccountSummary (different action)
```

**Effect:** Actions are like pure functions that work on any object implementing required fields.

### Real-World Coordination Example

**Scenario:** Complex Case Response workflow with multiple validations and actions.

**Trigger Actions:**

1. **TRG_CacheQuestionData** (Order 10)
    - Queries parent Question Cases
    - Caches question status, reviewers, response count
    - Shares cache via static getter

2. **TRG_ValidateResponseStatus** (Order 20)
    - Uses cached question data
    - Validates response status transitions
    - Ensures question is not closed

3. **TRG_PreventSameOwnerReviewer** (Order 30)
    - Uses cached question data
    - Validates owner != reviewer
    - Checks sibling responses for conflicts

4. **TRG_UpdateQuestionProgress** (Order 40)
    - Uses cached question data
    - Calculates completion percentage
    - Updates parent Question

5. **TRG_NotifyReviewers** (Order 50)
    - Uses cached question data
    - Sends email to reviewers
    - Creates tasks

**Metadata Configuration:**

```text
All actions:
  Before Update: Case_Trigger_Setting
  Allow Recursion: false (prevent infinite loops)

TRG_CacheQuestionData:
  Order: 10

TRG_ValidateResponseStatus:
  Order: 20
  Entry Criteria: isResponseRecordType

TRG_PreventSameOwnerReviewer:
  Order: 30
  Entry Criteria: isResponseRecordType && (ownerChanged || reviewerChanged)

TRG_UpdateQuestionProgress:
  Order: 40
  Entry Criteria: isResponseRecordType && statusChanged

TRG_NotifyReviewers:
  Order: 50
  Entry Criteria: isResponseRecordType && statusChanged && status == 'Submitted'
```

**Benefits:**

- Single SOQL query (Order 10)
- Each action has single responsibility
- Actions can be tested independently
- Entry criteria filters records per action
- Easy to add/remove/reorder actions via metadata

---

## Advanced Features

### Recursion Prevention

Actions can control recursive execution to prevent infinite loops.

**How It Works:**

- [TRG_Dispatcher](reference/apex/TRG_Dispatcher.md) maintains a stack of executing actions
- Before executing, checks if action is already in stack
- If `AllowRecursion__c = false` and action in stack, skips execution

**Configuration:**

```text
TriggerAction__mdt:
  Allow Recursion: false
```

**When to Use:**

- Action performs DML that might retrigger itself
- Action updates fields that trigger the same action
- Want to ensure action runs only once per transaction

**Example:**

```apex
public inherited sharing class TRG_UpdateAccountFromContact extends TRG_Base implements IF_Trigger.AfterUpdate
{
	public void afterUpdate(List<Contact> newContacts, List<Contact> oldContacts)
	{
		Set<Id> accountIds = new Set<Id>();

		for(Contact contact : newContacts)
		{
			accountIds.add(contact.AccountId);
		}

		List<Account> accountsToUpdate = QRY_Builder.selectFrom(Account.SObjectType)
			.addFields(new List<SObjectField>{Account.Id, Account.LastContactUpdateDate__c})
			.condition(Account.Id).isIn(accountIds)
			.toList();

		for(Account account : accountsToUpdate)
		{
			account.LastContactUpdateDate__c = System.now();
		}

		// This update might trigger Account trigger
		// If AllowRecursion = false, won't cause issues
		DML_Builder.newTransaction().doUpdate(accountsToUpdate).execute();
	}
}
```

### Self-Initiated Control

Actions can control whether they execute when triggered indirectly.

**How It Works:**

- [TRG_Dispatcher](reference/apex/TRG_Dispatcher.md) tracks the first action in the stack
- If `AllowNonSelfInitiated__c = false`, action only runs if it's first in stack
- Prevents cascading trigger execution

**Configuration:**

```text
TriggerAction__mdt:
  Allow Non Self-Initiated: false
```

**When to Use:**

- Action should only run for direct DML on the object
- Don't want action to fire when related triggers create records
- Need strict control over execution context

**Example:**

```apex
// Contact action configured with AllowNonSelfInitiated = false

// Scenario 1: Direct Contact insert
DML_Builder.newTransaction().doInsert(new Contact(LastName = 'Test')).execute();
// Contact trigger fires
// TRG_ContactAction executes (self-initiated)

// Scenario 2: Account trigger creates Contact
trigger TRG_Account on Account (after insert)
{
	new TRG_Dispatcher().run();
}

public inherited sharing class TRG_CreateDefaultContact ...
{
	public void afterInsert(List<Account> newAccounts)
	{
		DML_Builder.newTransaction().doInsert(new Contact(AccountId = newAccounts[0].Id, LastName = 'Default')).execute();
		// Contact trigger fires
		// TRG_ContactAction does NOT execute (non-self-initiated)
	}
}
```

### Bypass Mechanisms

Multiple levels of bypass control for runtime flexibility. Every programmatic bypass call (object-level and
action-level) emits a `LogEntryEvent__e` at WARN level with a `BypassEvent` category — creating an audit trail
of who bypassed which actions and why.

#### Object-Level Bypass (TriggerSetting__mdt)

**Via BypassExecution__c:**

```text
TriggerSetting__mdt:
  Object API Name: Account
  Bypass Execution: true
```

**Effect:** ALL actions for Account are bypassed.

**Programmatic Bypass:**

```apex
// Bypass all actions for Account (type-safe — recommended)
TRG_Base.bypass(Account.SObjectType);

// Or bypass using string-based API
TRG_Base.bypass('Account');

// Perform DML - no actions execute
DML_Builder.newTransaction().doInsert(new Account(Name = 'Test')).execute();

// Clear bypass
TRG_Base.clearBypass(Account.SObjectType);
```

#### Action-Level Bypass (TriggerAction__mdt)

**Via BypassExecution__c:**

```text
TriggerAction__mdt:
  Apex Class Name: TRG_ValidateAccount
  Bypass Execution: true
```

**Effect:** Only TRG_ValidateAccount is bypassed.

**Programmatic Bypass:**

```apex
// Bypass specific action
TRG_Base.bypassAction('TRG_ValidateAccount');

// Perform DML - only this action is bypassed
DML_Builder.newTransaction().doInsert(new Account(Name = 'Test')).execute();

// Clear bypass
TRG_Base.clearActionBypass('TRG_ValidateAccount');

// Clear all action bypasses
TRG_Base.clearAllActionBypasses();
```

#### Bypass Audit Trail

Every call to `TRG_Base.bypass*()` / `clearBypass*()` / `clearAll*Bypasses()` emits a WARN-level
`LogEntryEvent__e` tagged with `category = 'BypassEvent'` via `UTIL_BypassAudit.emit`. The event captures
the running user, the action (`BYPASS`, `CLEAR`, `CLEAR_ALL`), the surface (`trigger-object` /
`trigger-action`), the target (SObject API name or class name), and the optional reason set via
`TRG_Base.setBypassReason(String)`.

The same audit channel covers query (`QRY_Builder.withSystemMode` / `bypassSharing` / `withoutSecurity` →
`surface = 'query'`), DML (`DML_Builder.withSystemMode` / `bypassSharing` → `surface = 'dml'`), and validation
(`UTIL_ValidationRule.bypassObject` / `bypassGroup` / `bypassRule` → `surface = 'validation'`) bypasses.
Subscribers can disable runtime emission in noisy environments via a `FeatureFlagStrategy__mdt` override on
the `BypassAudit_Enabled` `FeatureFlag__mdt` record (default-on).

```apex
// Attach a business reason to any bypasses emitted in this transaction
TRG_Base.setBypassReason('Nightly data-integrity reconciliation batch');

TRG_Base.bypass(Account.SObjectType);
TRG_Base.bypassAction('TRG_ValidateAccount');
```

The `TRG_Base.BypassAction` enum is `global` and subscribers can reason about bypass events directly. To
query the audit log:

```apex
List<LogEntry__c> bypassEvents = QRY_Builder.selectFrom(LogEntry__c.SObjectType)
	.addFields(new List<String>{'ShortMessage__c', 'ContextData__c', 'CreatedById', 'CreatedDate'})
	.condition('ContextData__c').contains('"category":"BypassEvent"')
	.orderBy('CreatedDate').descending()
	.withLimit(100)
	.toList();
```

**Why this matters:** bypasses weaken security and automation guarantees. The audit trail answers "which user
bypassed which action, when, and why?" without requiring every bypass call-site to remember to log the event.

#### Flow-Based Bypass ([`FLOW_BypassTrigger`](reference/apex/FLOW_BypassTrigger.md))

Declarative orgs can toggle bypasses from Flow without Apex. The `FLOW_BypassTrigger` invocable accepts a
`DTO_Request` with `action` (`BYPASS` / `CLEAR` / `CLEAR_ALL`), `bypassType` (`OBJECT_NAME` / `CLASS_NAME`),
and `name` (the SObject API name or action class name). The companion `FLOW_CheckTriggerBypassed` invocable
reports whether a bypass is currently in effect. Both emit the same `BypassEvent`-category audit log as the
Apex API, so Flow-driven bypasses show up in the same audit trail.

#### Feature Flag Bypass

**Via BypassFeatureFlag__c:**

The `BypassFeatureFlag__c` field on `TriggerSetting__mdt` and `TriggerAction__mdt` is a **MetadataRelationship** lookup to `FeatureFlag__mdt`. When the referenced Feature Flag
evaluates to `true` for the running user, the associated trigger actions are bypassed.

1. Create Feature Flag:
    - Create a `FeatureFlag__mdt` record with DeveloperName `Bypass_Account_Triggers`
    - Optionally add targeting strategies via `FeatureFlagStrategy__mdt`

2. Configure Metadata:

```text
TriggerSetting__mdt:
  Bypass Feature Flag: Bypass_Account_Triggers
```

3. Target Users:
    - Use `FeatureFlagStrategy__mdt` to target by Profile, Permission Set Group, or custom logic
    - Or set `IsEnabledByDefault__c = true` to bypass for all users

**Use Cases:**

- Emergency kill switches (enable flag to bypass — no deployment required)
- Targeted bypass for integration users via Permission Set Group strategy
- Data migration bypass controlled by Feature Flag

> **Tip:** For permission-based bypass, create a Feature Flag with a `Custom Permission` strategy type in `FeatureFlagStrategy__mdt`.

#### Feature Flag Gating

**Via RequiredFeatureFlag__c:**

The `RequiredFeatureFlag__c` field on `TriggerSetting__mdt` and `TriggerAction__mdt` is a **MetadataRelationship** lookup to `FeatureFlag__mdt`. Actions only execute when the
referenced Feature Flag evaluates to `true` for the running user.

1. Create Feature Flag:
    - Create a `FeatureFlag__mdt` record with DeveloperName `Enable_Account_Validation`
    - Add targeting strategies via `FeatureFlagStrategy__mdt`

2. Configure Metadata:

```text
TriggerAction__mdt:
  Required Feature Flag: Enable_Account_Validation
```

3. Target Users:
    - Use `FeatureFlagStrategy__mdt` to control which users get the feature

**Use Cases:**

- Gradual rollout of new trigger logic to targeted user groups
- Premium features only for specific profiles
- Controlled enablement of new validation rules

### Feature Flag Integration

The `BypassFeatureFlag__c` and `RequiredFeatureFlag__c` fields on both `TriggerSetting__mdt` and `TriggerAction__mdt` are **MetadataRelationship** lookups to `FeatureFlag__mdt`
records managed through the [Feature Flag framework](reference/apex/UTIL_FeatureFlag.md). They appear as dropdown pickers in the Custom Metadata UI, providing referential integrity
and preventing typos.

**How It Works:**

```text
1. If no Feature Flag is selected -> Condition not met (no bypass/no requirement)
2. Resolve the referenced FeatureFlag__mdt record
3. Evaluate the Feature Flag for the running user (strategies, defaults, active state)
4. If Feature Flag is enabled -> Condition is met (bypass applies / requirement satisfied)
```

Custom Permissions are not referenced directly in these fields. To use permission-based targeting, create a Feature Flag with a `Custom Permission` strategy type in
`FeatureFlagStrategy__mdt`.

**Example 1: Gradual Rollout with Feature Flag**

```apex
// Step 1: Create Feature Flag for new validation
// FeatureFlag__mdt:
//   DeveloperName: 'Enable_New_Account_Validation'
//   IsActive__c: true
//   IsEnabledByDefault__c: false (disabled for most users)
//
// FeatureFlagStrategy__mdt:
//   Strategy: Permission Set Group
//   TargetValue: 'Beta_Testers'
//   IsEnabled: true

// Step 2: Configure TriggerAction__mdt
// RequiredFeatureFlag__c: 'Enable_New_Account_Validation'

// Result: Action ONLY runs for users in the Beta_Testers Permission Set Group
// When ready for GA: Set FeatureFlag IsEnabledByDefault__c = true
```

**Example 2: Kill Switch with Feature Flag**

```apex
// Step 1: Create Feature Flag for emergency bypass
// FeatureFlag__mdt:
//   DeveloperName: 'Disable_Account_Sync'
//   IsActive__c: true
//   IsEnabledByDefault__c: false (sync normally runs)

// Step 2: Configure TriggerAction__mdt
// BypassFeatureFlag__c: 'Disable_Account_Sync'

// Normal operation: Flag is disabled -> Sync action runs
// Emergency: Set IsEnabledByDefault__c = true -> Sync action is BYPASSED
// No deployment required!
```

**Example 3: Profile-Based Targeting**

```apex
// Step 1: Create Feature Flag with Profile strategy
// FeatureFlag__mdt:
//   DeveloperName: 'Enable_Premium_Validation'
//   IsActive__c: true
//
// FeatureFlagStrategy__mdt:
//   Strategy: Profile
//   TargetValue: 'Premium_User_Profile'
//   IsEnabled: true

// Step 2: Configure TriggerAction__mdt
// RequiredFeatureFlag__c: 'Enable_Premium_Validation'

// Result: Action only runs for users with Premium_User_Profile
```

**Logging:**

When an action is skipped due to bypass or missing required condition, an INFO log is written:

```text
Trigger action "Account_ValidateRevenue" on Account SKIPPED. Action bypass: Disable_Account_Validation
Trigger action "Account_SyncExternal" on Account SKIPPED. Setting required not met: Enable_External_Sync
```

### Entry Criteria Formulas

Execute actions conditionally based on formula evaluation per record.

#### Simple Entry Criteria

**Context Class:**

```apex
/**
 * @description Formula evaluation context for Account records. Provides old and new record states
 *              for formula-based filtering and evaluation in trigger and automation contexts.
 *
 * @see UTIL_FormulaFilter.INT_SObjectFormulaEvaluationContext
 *
 * @author <your-author-tag>
 *
 * @date January 2025
 */
@SuppressWarnings('PMD.AvoidGlobalModifier')
global with sharing class UTIL_AccountContext implements UTIL_FormulaFilter.INT_SObjectFormulaEvaluationContext
{
	/**
	 * @description The Account record state before the DML operation
	 */
	global Account oldRecord;

	/**
	 * @description The Account record state after the DML operation
	 */
	global Account newRecord;

	/**
	 * @description Checks if the account is premium tier
	 */
	global Boolean isPremium
	{
		get { return newRecord?.Type == 'Premium'; }
	}

	/**
	 * @description Sets the context for formula evaluation with old and new Account records
	 *
	 * @param oldSObject The record state before the DML operation
	 * @param newSObject The record state after the DML operation
	 */
	public void setContext(SObject oldSObject, SObject newSObject)
	{
		oldRecord = (Account)oldSObject ?? new Account();
		newRecord = (Account)newSObject ?? new Account();
	}
}
```

**Formula:**

```text
isPremium
```

**Effect:** Action only receives Premium accounts.

#### Complex Entry Criteria

**Context Class:**

```apex
/**
 * @description Formula evaluation context for Account records with complex business logic.
 *              Provides old and new record states for formula-based filtering and evaluation.
 *
 * @see UTIL_FormulaFilter.INT_SObjectFormulaEvaluationContext
 *
 * @author <your-author-tag>
 *
 * @date January 2025
 */
@SuppressWarnings('PMD.AvoidGlobalModifier')
global with sharing class UTIL_AccountContext implements UTIL_FormulaFilter.INT_SObjectFormulaEvaluationContext
{
	/**
	 * @description The Account record state before the DML operation
	 */
	global Account oldRecord;

	/**
	 * @description The Account record state after the DML operation
	 */
	global Account newRecord;

	/**
	 * @description Checks if the account is premium tier
	 */
	global Boolean isPremium
	{
		get { return newRecord?.Type == 'Premium'; }
	}

	/**
	 * @description Checks if the status field changed
	 */
	global Boolean statusChanged
	{
		get { return oldRecord != null && newRecord?.Status__c != oldRecord.Status__c; }
	}

	/**
	 * @description Checks if the account is active
	 */
	global Boolean isActive
	{
		get { return newRecord?.Status__c == 'Active'; }
	}

	/**
	 * @description Checks if the account has high annual revenue
	 */
	global Boolean isHighValue
	{
		get { return newRecord?.AnnualRevenue != null && newRecord.AnnualRevenue > 1000000; }
	}

	/**
	 * @description Sets the context for formula evaluation with old and new Account records
	 *
	 * @param oldSObject The record state before the DML operation
	 * @param newSObject The record state after the DML operation
	 */
	public void setContext(SObject oldSObject, SObject newSObject)
	{
		oldRecord = (Account)oldSObject ?? new Account();
		newRecord = (Account)newSObject ?? new Account();
	}
}
```

**Formula Examples:**

```text
isPremium && statusChanged
isPremium && isActive
isHighValue && (statusChanged || oldRecord == null)
(isPremium || isHighValue) && isActive
```

**Effect:** Framework evaluates formula for each record and only passes matching records to action.

---

## Common Patterns

### Validation Pattern

**Use Case:** Validate record data before save.

**Implementation:**

```apex
/**
 * @description Validates Account fields before insert/update.
 *
 * @author <your-author-tag>
 *
 * @date January 2025
 */
public inherited sharing class TRG_ValidateAccount extends TRG_Base implements
	IF_Trigger.BeforeInsert,
	IF_Trigger.BeforeUpdate
{
	public void beforeInsert(List<Account> newAccounts)
	{
		validate(newAccounts);
	}

	public void beforeUpdate(List<Account> newAccounts, List<Account> oldAccounts)
	{
		validate(newAccounts);
	}

	private static void validate(List<Account> accounts)
	{
		for(Account account : accounts)
		{
			// Validate: Annual Revenue must be positive
			if(account.AnnualRevenue != null && account.AnnualRevenue < 0)
			{
				account.AnnualRevenue.addError('Annual Revenue cannot be negative');
			}

			// Validate: Premium accounts need phone
			if(account.Type == 'Premium' && String.isBlank(account.Phone))
			{
				account.Phone.addError('Phone is required for Premium accounts');
			}

			// Validate: Email format
			if(String.isNotBlank(account.Email__c) && !account.Email__c.contains('@'))
			{
				account.Email__c.addError('Invalid email format');
			}
		}
	}
}
```

### Field Population Pattern

**Use Case:** Auto-populate fields based on business rules.

**Implementation:**

```apex
/**
 * @description Populates calculated and default fields on Account.
 *
 * @author <your-author-tag>
 *
 * @date January 2025
 */
public inherited sharing class TRG_PopulateAccountFields extends TRG_Base implements IF_Trigger.BeforeInsert
{
	public void beforeInsert(List<Account> newAccounts)
	{
		for(Account account : newAccounts)
		{
			// Set default industry
			if(String.isBlank(account.Industry))
			{
				account.Industry = 'Other';
			}

			// Generate account number
			if(String.isBlank(account.AccountNumber))
			{
				account.AccountNumber = 'ACC-' + String.valueOf(System.now().getTime());
			}

			// Set tier based on revenue
			if(account.AnnualRevenue != null)
			{
				if(account.AnnualRevenue > 10000000)
				{
					account.Tier__c = 'Platinum';
				}
				else if(account.AnnualRevenue > 1000000)
				{
					account.Tier__c = 'Gold';
				}
				else
				{
					account.Tier__c = 'Silver';
				}
			}
		}
	}
}
```

### Related Record Creation Pattern

**Use Case:** Create related records after parent insert/update.

**Implementation:**

```apex
/**
 * @description Creates default Contact for new Accounts.
 *
 * @author <your-author-tag>
 *
 * @date January 2025
 */
public inherited sharing class TRG_CreateDefaultContact extends TRG_Base implements IF_Trigger.AfterInsert
{
	public void afterInsert(List<Account> newAccounts)
	{
		List<Contact> contactsToInsert = new List<Contact>();

		for(Account account : newAccounts)
		{
			contactsToInsert.add(new Contact(
				AccountId = account.Id,
				LastName = account.Name + ' Contact',
				Email = account.Email__c,
				Phone = account.Phone
			));
		}

		if(!contactsToInsert.isEmpty())
		{
			DML_Builder.newTransaction().doInsert(contactsToInsert).execute();
		}
	}
}
```

### Cascade Update Pattern

**Use Case:** Update related records when parent changes.

**Implementation:**

```apex
/**
 * @description Cascades Account phone updates to related Contacts.
 *
 * @author <your-author-tag>
 *
 * @date January 2025
 */
public inherited sharing class TRG_CascadePhoneToContacts extends TRG_Base implements IF_Trigger.AfterUpdate
{
	public void afterUpdate(List<Account> newAccounts, List<Account> oldAccounts)
	{
		Map<Id, String> accountIdToNewPhone = new Map<Id, String>();

		// Identify phone changes
		for(Integer i = 0; i < newAccounts.size(); i++)
		{
			Account newAccount = newAccounts.get(i);
			Account oldAccount = oldAccounts.get(i);

			if(newAccount.Phone != oldAccount.Phone)
			{
				accountIdToNewPhone.put(newAccount.Id, newAccount.Phone);
			}
		}

		if(!accountIdToNewPhone.isEmpty())
		{
			// Query contacts using QRY_Builder
			List<Contact> contactsToUpdate = QRY_Builder.selectFrom(Contact.SObjectType)
				.addFields(new List<SObjectField>{Contact.Id, Contact.AccountId, Contact.Phone})
				.condition(Contact.AccountId).isIn(accountIdToNewPhone.keySet())
				.toList();

			// Update phones
			for(Contact contact : contactsToUpdate)
			{
				contact.Phone = accountIdToNewPhone.get(contact.AccountId);
			}

			if(!contactsToUpdate.isEmpty())
			{
				DML_Builder.newTransaction().doUpdate(contactsToUpdate).execute();
			}
		}
	}
}
```

### Audit Trail Pattern

**Use Case:** Log field changes for compliance.

**Implementation:**

```apex
/**
 * @description Logs Account status changes to audit trail.
 *
 * @author <your-author-tag>
 *
 * @date January 2025
 */
public inherited sharing class TRG_AuditStatusChanges extends TRG_Base implements IF_Trigger.AfterUpdate
{
	public void afterUpdate(List<Account> newAccounts, List<Account> oldAccounts)
	{
		List<AuditLog__c> logsToInsert = new List<AuditLog__c>();

		for(Integer i = 0; i < newAccounts.size(); i++)
		{
			Account newAccount = newAccounts.get(i);
			Account oldAccount = oldAccounts.get(i);

			if(newAccount.Status__c != oldAccount.Status__c)
			{
				logsToInsert.add(new AuditLog__c(
					RecordId__c = newAccount.Id,
					ObjectType__c = 'Account',
					FieldName__c = 'Status__c',
					OldValue__c = oldAccount.Status__c,
					NewValue__c = newAccount.Status__c,
					ChangedBy__c = UserInfo.getUserId(),
					ChangedDate__c = System.now()
				));
			}
		}

		if(!logsToInsert.isEmpty())
		{
			DML_Builder.newTransaction().doInsert(logsToInsert).execute();
		}
	}
}
```

---

## Testing

### Testing Individual Actions

```apex
/**
 * @description Test class for TRG_ValidateAccount
 *
 * @see TRG_ValidateAccount
 *
 * @author <your-author-tag>
 *
 * @date January 2025
 */
@IsTest(SeeAllData=false IsParallel=true)
private class TRG_ValidateAccount_TEST
{
	/**
	 * @description Tests that negative revenue fails validation
	 */
	@IsTest
	private static void beforeInsert_givenNegativeRevenue_shouldError()
	{
		Test.startTest();
		Database.SaveResult result = Database.insert(
			(Account)TST_Builder.of(Account.SObjectType)
				.withOverrides(new Map<String, Object>
				{
					'Name' => 'Test Account',
					'AnnualRevenue' => -1000
				})
				.withoutInsertion()
				.build(),
			false
		);
		Test.stopTest();

		Assert.isFalse(result.isSuccess(), 'Should fail validation');
		Assert.isTrue(result.getErrors()[0].getMessage().contains('negative'), 'Error should mention negative');
	}

	/**
	 * @description Tests that premium without phone fails
	 */
	@IsTest
	private static void beforeInsert_givenPremiumWithoutPhone_shouldError()
	{
		Test.startTest();
		Database.SaveResult result = Database.insert(
			(Account)TST_Builder.of(Account.SObjectType)
				.withOverrides(new Map<String, Object>
				{
					'Name' => 'Test Account',
					'Type' => 'Premium',
					'Phone' => null
				})
				.withoutInsertion()
				.build(),
			false
		);
		Test.stopTest();

		Assert.isFalse(result.isSuccess(), 'Should fail validation');
		Assert.isTrue(result.getErrors()[0].getMessage().contains('Phone'), 'Error should mention phone');
	}

	/**
	 * @description Tests valid account passes
	 */
	@IsTest
	private static void beforeInsert_givenValidAccount_shouldSucceed()
	{
		Test.startTest();
		Account testAccount = (Account)TST_Builder.of(Account.SObjectType)
			.withOverrides(new Map<String, Object>
			{
				'Name' => 'Test Account',
				'Type' => 'Premium',
				'Phone' => '555-1234',
				'AnnualRevenue' => 1000000
			})
			.build();
		Test.stopTest();

		Assert.isNotNull(testAccount.Id, 'Account should be created');
	}
}
```

### Testing with Bypass

```apex
/**
 * @description Tests bypass functionality
 */
@IsTest
private static void bypass_givenBypassed_shouldSkipAction()
{
	TRG_Base.bypassAction('TRG_ValidateAccount');

	Test.startTest();
	Account testAccount = (Account)TST_Builder.of(Account.SObjectType)
		.withOverrides(new Map<String, Object>
		{
			'Name' => 'Test Account',
			'AnnualRevenue' => -1000 // Invalid!
		})
		.build();
	Test.stopTest();

	// Should succeed (validation was bypassed)
	Assert.isNotNull(testAccount.Id, 'Account should be created despite invalid data');

	TRG_Base.clearAllActionBypasses();
}
```

### Testing Action Coordination

```apex
/**
 * @description Tests that caching action provides data to validation action
 */
@IsTest
private static void coordination_givenCacheAndValidation_shouldWork()
{
	Account testAccount = (Account)TST_Builder.of(Account.SObjectType)
		.withOverrides(new Map<String, Object>
		{
			'Name' => 'Test Account',
			'Type' => 'Standard'
		})
		.build();

	Test.startTest();
	testAccount.Type = 'Premium';
	Database.SaveResult result = Database.update(testAccount, false);
	Test.stopTest();

	// Should fail (validation used cached data showing no contacts)
	Assert.isFalse(result.isSuccess(), 'Should fail validation');
}
```

### Testing Multiple Actions in Order

```apex
/**
 * @description Tests that actions execute in correct order
 */
@IsTest
private static void ordering_givenMultipleActions_shouldExecuteInOrder()
{
	Test.startTest();
	Account testAccount = (Account)TST_Builder.of(Account.SObjectType)
		.withOverrides(new Map<String, Object>
		{
			'Name' => 'Test Account',
			'ExternalReference__c' => null, // Order 10 populates
			'Industry' => null, // Order 20 populates
			'AccountNumber' => null // Order 30 populates
		})
		.build();
	Test.stopTest();

	testAccount = (Account)QRY_Builder.selectFrom(Account.SObjectType)
		.addFields(new List<SObjectField>{Account.Id, Account.ExternalReference__c, Account.Industry, Account.AccountNumber})
		.condition(Account.Id).equals(testAccount.Id)
		.getFirst();

	Assert.isNotNull(testAccount.ExternalReference__c, 'Order 10 should populate');
	Assert.areEqual('Other', testAccount.Industry, 'Order 20 should populate');
	Assert.isNotNull(testAccount.AccountNumber, 'Order 30 should populate');
}
```

### Testing Entry Criteria

```apex
/**
 * @description Tests entry criteria filters records
 */
@IsTest
private static void entryCriteria_givenNonPremium_shouldNotExecute()
{
	Test.startTest();
	Account testAccount = (Account)TST_Builder.of(Account.SObjectType)
		.withOverrides(new Map<String, Object>
		{
			'Name' => 'Test Account',
			'Type' => 'Standard',
			'PremiumValidation__c' => 'NotRun' // Action would set this
		})
		.build();
	Test.stopTest();

	testAccount = (Account)QRY_Builder.selectFrom(Account.SObjectType)
		.addFields(new List<SObjectField>{Account.Id, Account.PremiumValidation__c})
		.condition(Account.Id).equals(testAccount.Id)
		.getFirst();
	Assert.areEqual('NotRun', testAccount.PremiumValidation__c, 'Action should not run for non-premium');
}
```

---

## Performance Logging

The Trigger Action Framework includes built-in performance monitoring that automatically times trigger action execution and logs slow operations. This helps identify performance
bottlenecks without adding instrumentation code to your trigger actions.

### Performance Logging Overview

When enabled, the framework:

1. Times each trigger action's execution
2. Compares duration against configurable thresholds
3. Logs entries to `LogEntry__c` when thresholds are exceeded
4. Captures rich context (action name, trigger operation, object, record count)

**Performance Log Entry Example:**

```text
LogEntry__c:
  ShortMessage__c: "Trigger Performance: TRG_AccountValidateName"
  Message__c: "Action: TRG_AccountValidateName | Operation: BEFORE_INSERT | Object: Account | Records: 200 | Duration: 1523ms"
  LogLevel__c: "INFO"
  ContextData__c: {"operationType":"TRIGGER_ACTION","actionName":"TRG_AccountValidateName","triggerOperation":"BEFORE_INSERT","objectName":"Account","recordCount":200,...}
```

### Configuration Hierarchy

Performance logging uses a **3-tier configuration hierarchy** (highest priority first):

```text
+-------------------------------------------------------------+
|  1. TriggerAction__mdt (Action-Level) - Highest Priority     |
|     ForcePerformanceLogging__c = true -> Always log           |
|     SuppressPerformanceLogging__c = true -> Never log         |
|     PerformanceThresholdMs__c = 100 -> Custom threshold       |
+-------------------------------------------------------------+
|  2. TriggerSetting__mdt (Object-Level)                       |
|     EnablePerformanceLogging__c = true -> Enable for object   |
|     PerformanceThresholdMs__c = 500 -> Object threshold       |
+-------------------------------------------------------------+
|  3. LogSetting__c (Global)                                        |
|     EnableTriggerPerformanceLogging__c = true -> Enable all   |
|     TriggerPerformanceThresholdMs__c = 500 -> Global default  |
+-------------------------------------------------------------+
```

**Configuration Fields:**

| Level  | Metadata Type         | Field                                | Description                                |
|--------|-----------------------|--------------------------------------|--------------------------------------------|
| Action | `TriggerAction__mdt`  | `ForcePerformanceLogging__c`         | Always log this action (ignores threshold) |
| Action | `TriggerAction__mdt`  | `SuppressPerformanceLogging__c`      | Never log this action                      |
| Action | `TriggerAction__mdt`  | `PerformanceThresholdMs__c`          | Custom threshold for this action (ms)      |
| Object | `TriggerSetting__mdt` | `EnablePerformanceLogging__c`        | Enable logging for this object's triggers  |
| Object | `TriggerSetting__mdt` | `PerformanceThresholdMs__c`          | Threshold for this object (ms)             |
| Global | `LogSetting__c`       | `EnableTriggerPerformanceLogging__c` | Enable trigger performance logging         |
| Global | `LogSetting__c`       | `TriggerPerformanceThresholdMs__c`   | Default threshold (ms)                     |

**Typical Configuration:**

```text
LogSetting__c (Org Default):
  EnableTriggerPerformanceLogging__c: true
  TriggerPerformanceThresholdMs__c: 500  <- Log actions taking > 500ms

TriggerSetting__mdt (Account_Trigger_Setting):
  EnablePerformanceLogging__c: true
  PerformanceThresholdMs__c: 200  <- Account triggers: stricter 200ms threshold

TriggerAction__mdt (TRG_AccountExternalSync):
  ForcePerformanceLogging__c: true  <- Always log this slow action
  PerformanceThresholdMs__c: null   <- Uses object threshold (200ms)

TriggerAction__mdt (TRG_AccountSetDefaults):
  SuppressPerformanceLogging__c: true  <- Never log (known to be fast)
```

### How Performance Logging Works

The [TRG_Dispatcher](reference/apex/TRG_Dispatcher.md) class uses `UTIL_TriggerPerformanceTimer` internally to time each action:

```text
+----------------------------------------------------------------------+
|                   new TRG_Dispatcher().run()                          |
+----------------------------------------------------------------------+
|  for each TriggerAction__mdt in execution order:                      |
|                                                                       |
|    1. Check configuration hierarchy for logging settings              |
|    2. Create UTIL_TriggerPerformanceTimer                             |
|    3. timer.start()                                                   |
|    4. Execute action (e.g., beforeInsert())                           |
|    5. timer.stop()                                                    |
|       -> If duration > threshold AND logging enabled:                 |
|         -> Publish LogEntryEvent__e with performance data               |
|                                                                       |
+----------------------------------------------------------------------+
```

**What Gets Captured:**

| Field             | Description                                                  |
|-------------------|--------------------------------------------------------------|
| Action Name       | Fully qualified class name (e.g., `TRG_AccountValidateName`) |
| Trigger Operation | `BEFORE_INSERT`, `AFTER_UPDATE`, etc.                        |
| Object Name       | SObject API name (e.g., `Account`)                           |
| Record Count      | Number of records in `Trigger.new` or `Trigger.old`          |
| Duration (ms)     | Actual execution time in milliseconds                        |
| Governor Limits   | CPU time, heap, SOQL count deltas (when available)           |

### Viewing Performance Logs

**Query Performance Logs:**

```apex
// Find slow trigger actions in the last 24 hours
List<LogEntry__c> slowTriggers = QRY_Builder.selectFrom(LogEntry__c.SObjectType)
	.addFields(new List<String>{'ShortMessage__c', 'Message__c', 'DurationMs__c', 'ContextData__c', 'CreatedDate'})
	.condition('ShortMessage__c').contains('Trigger Performance:')
	.andCondition('CreatedDate').greaterThanOrEquals(System.now().addDays(-1))
	.orderBy('DurationMs__c').descending()
	.withLimit(50)
	.toList();

for(LogEntry__c log : slowTriggers)
{
	LOG_Builder.build().info(log.DurationMs__c + 'ms - ' + log.ShortMessage__c).emitAt('TriggerPerformance.review');
}
```

**Sample Report Filter:**

Create a report on `LogEntry__c` with:

- Filter: `ShortMessage__c` contains "Trigger Performance"
- Group by: `ShortMessage__c` (action name)
- Summarize: `AVG(DurationMs__c)`, `MAX(DurationMs__c)`, `COUNT(Id)`

**Best Practices:**

| Practice                                                | Rationale                                   |
|---------------------------------------------------------|---------------------------------------------|
| Start with global threshold of 500ms                    | Catches significant issues without noise    |
| Use `ForcePerformanceLogging__c` for known slow actions | Monitor integrations, complex validations   |
| Use `SuppressPerformanceLogging__c` for trivial actions | Reduce log volume for simple field defaults |
| Review logs weekly                                      | Identify degrading performance trends       |
| Set stricter thresholds for high-volume objects         | Catch issues before they impact users       |

> **See Also:** For comprehensive logging documentation including correlation tracking, context stack, and other performance timers, see [Logging - Guide](Logging%20-%20Guide.md).

---

## Capability Matrix (for Analysts)

| Capability             | Custom Metadata       | Field                                            | Notes                                                                                                                                                                                                     |
|------------------------|-----------------------|--------------------------------------------------|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| Object-level bypass    | `TriggerSetting__mdt` | `BypassExecution__c`                             | Disables all trigger actions for an object                                                                                                                                                                |
| Feature Flag bypass    | `TriggerSetting__mdt` | `BypassFeatureFlag__c`                           | Bypasses all actions when the specified Feature Flag is enabled                                                                                                                                           |
| Feature Flag gating    | `TriggerSetting__mdt` | `RequiredFeatureFlag__c`                         | Only executes when the specified Feature Flag is enabled                                                                                                                                                  |
| Performance logging    | `TriggerSetting__mdt` | `EnablePerformanceLogging__c`                    | Logs execution timing per trigger action                                                                                                                                                                  |
| Performance threshold  | `TriggerSetting__mdt` | `PerformanceThresholdMs__c`                      | Only logs actions exceeding this millisecond threshold                                                                                                                                                    |
| Action-level bypass    | `TriggerAction__mdt`  | `BypassExecution__c`                             | Disables a single trigger action                                                                                                                                                                          |
| Execution ordering     | `TriggerAction__mdt`  | `Order__c`                                       | Controls execution sequence within an event                                                                                                                                                               |
| Recursion control      | `TriggerAction__mdt`  | `AllowRecursion__c`                              | Allows re-execution in the same transaction                                                                                                                                                               |
| Self-initiated control | `TriggerAction__mdt`  | `AllowNonSelfInitiated__c`                       | Controls behavior for framework-initiated DML                                                                                                                                                             |
| Entry criteria         | `TriggerAction__mdt`  | `EntryCriteriaFormula__c`                        | Formula-based conditional execution                                                                                                                                                                       |
| Bypass audit trail     | Platform event        | `LogEntryEvent__e` tagged `category=BypassEvent` | Every programmatic bypass call across trigger / query / DML / validation surfaces emits a WARN log with user, action, surface, target, and optional reason; `BypassAudit_Enabled` flag is the kill-switch |

---

## Anti-Patterns

| Anti-Pattern                                        | Why It's Wrong                                                                     | Instead                                                                    |
|-----------------------------------------------------|------------------------------------------------------------------------------------|----------------------------------------------------------------------------|
| Inline SOQL inside a trigger action                 | Duplicates queries, makes bulk processing fragile, and bypasses selector caching   | Use `SEL_*` selectors or `QRY_Builder`; share data via caching actions     |
| Multiple responsibilities in one action             | Hard to test, hard to reorder, and violates single responsibility principle        | Split into separate actions with distinct `Order__c` values                |
| Hardcoded bypass flags (`static Boolean`)           | Not metadata-driven, invisible to admins, and cannot be toggled per-environment    | Use `BypassExecution__c` on `TriggerAction__mdt` or `BypassFeatureFlag__c` |
| Business logic in the physical trigger file         | Cannot be tested independently, cannot be reused, and makes the trigger monolithic | Move all logic into `TRG_*` action classes configured via metadata         |
| Relying on trigger execution order without metadata | Execution order is unpredictable when multiple triggers exist on the same object   | Use `Order__c` on `TriggerAction__mdt` to guarantee sequence               |

---

## Best Practices

1. **One responsibility per action** - Each trigger action class should handle a single concern (e.g., validation, field defaulting, related record
   creation). Avoid combining multiple unrelated operations in the same action class.

2. **Use metadata ordering intentionally** - Assign `Order__c` values with gaps (10, 20, 30) to allow future actions to be inserted between
   existing ones without renumbering. Place validation actions before field population actions, and field population before related record creation.

3. **Prefer `inherited sharing` on action classes** - Use `inherited sharing` unless your action has a specific requirement for `with sharing`
   or `without sharing`. This respects the calling context and avoids unexpected permission issues.

4. **Always set `AllowRecursion__c` deliberately** - Default to `false` for most actions to prevent infinite loops. Only enable recursion for
   actions that must re-execute when their own changes trigger the object again (e.g., cascade updates).

5. **Use entry criteria to reduce processing** - Configure `EntryCriteriaFormula__c` on `TriggerAction__mdt` to skip actions when records do
   not meet conditions. This avoids unnecessary class instantiation and execution for irrelevant records.

6. **Leverage caching actions for shared queries** - When multiple actions need the same related data, create a dedicated caching action with a
   low `Order__c` value that queries once and stores results in a static variable. Subsequent actions read from the cache instead of re-querying.

7. **Do not bypass triggers in production without a plan** - Use `BypassExecution__c` or `BypassFeatureFlag__c` sparingly. Document why a bypass
   exists and who should have it. Prefer Feature Flag-based bypasses over metadata checkboxes so that only targeted users skip trigger logic.

8. **Test actions in isolation** - Each trigger action should have its own test class that configures the required `TriggerSetting__mdt` and
   `TriggerAction__mdt` via `TST_Factory`, inserts records via `TST_Builder`, and asserts the expected outcome.

---

## Troubleshooting

### Common Issues

#### Issue: Action Not Executing

**Symptoms:** Code doesn't run, no errors.

**Possible Causes:**

1. `BypassExecution__c` is checked in metadata
2. Object-level `BypassExecution__c` is checked
3. `BypassFeatureFlag__c` is enabled for the user
4. `RequiredFeatureFlag__c` is not enabled for the user
5. Entry criteria formula evaluates to false for all records
6. Wrong trigger context configured
7. `AllowRecursion__c = false` and action executing recursively
8. `AllowNonSelfInitiated__c = false` and triggered indirectly

**Solutions:**

1. Check metadata configuration:

```apex
List<TriggerAction__mdt> actions = SEL_TriggerAction.findActiveByObjectNameAndTriggerOperation('Account', TriggerOperation.BEFORE_INSERT);
LOG_Builder.build().debug(String.valueOf(actions)).emitAt('TriggerDebug.checkMetadata');
```

2. Check bypass status:

```apex
Boolean isActionBypassed = TRG_Base.isActionBypassed('TRG_MyAction');
Boolean isObjectBypassed = TRG_Base.isBypassed('Account');
LOG_Builder.build().debug('Action bypassed: ' + isActionBypassed).emitAt('TriggerDebug.checkBypass');
LOG_Builder.build().debug('Object bypassed: ' + isObjectBypassed).emitAt('TriggerDebug.checkBypass');
```

3. Add debug logging in action:

```apex
public void beforeInsert(List<Account> newAccounts)
{
	LOG_Builder.build().debug('beforeInsert - START').emitAt('TRG_MyAction.beforeInsert');
	LOG_Builder.build().debug('Record count: ' + newAccounts.size()).emitAt('TRG_MyAction.beforeInsert');
	// ... logic
	LOG_Builder.build().debug('beforeInsert - END').emitAt('TRG_MyAction.beforeInsert');
}
```

4. Verify trigger exists and calls framework:

```apex
trigger TRG_Account on Account (before insert, before update)
{
	LOG_Builder.build().debug('Trigger firing').emitAt('TRG_Account.trigger');
	new TRG_Dispatcher().run();
}
```

#### Issue: Wrong Execution Order

**Symptoms:** Actions run in unexpected sequence.

**Possible Causes:**

1. `Order__c` not set correctly
2. Multiple actions with same `Order__c`

**Solutions:**

1. Query and verify order:

```apex
List<TriggerAction__mdt> actions = SEL_TriggerAction.findActiveByObjectNameAndTriggerOperation('Account', TriggerOperation.BEFORE_INSERT);
for(TriggerAction__mdt action : actions)
{
	String target = String.isNotBlank(action.ApexClassName__c) ? action.ApexClassName__c : 'Flow:' + action.FlowName__c;
	LOG_Builder.build().debug(action.Order__c + ': ' + target).emitAt('Troubleshooting.verifyOrder');
}
```

2. Update order to use increments of 10:

```text
Order 10: TRG_CacheData
Order 20: TRG_Validate
Order 30: TRG_Populate
Order 40: TRG_CreateRelated
```

#### Issue: Entry Criteria Not Working

**Symptoms:** Action executes for all records or wrong records.

**Possible Causes:**

1. Formula syntax error
2. Context class properties don't match formula
3. Context class not instantiable

**Solutions:**

1. Test context class independently:

```apex
Account testAccount = (Account)TST_Builder.of(Account.SObjectType)
	.withOverrides(new Map<SObjectField, Object>{ Account.Type => 'Premium', Account.Status__c => 'Active' })
	.withoutInsertion()
	.build();
UTIL_AccountContext context = new UTIL_AccountContext();
context.newRecord = testAccount;
Assert.isTrue(context.isPremium, 'Account Type "Premium" should set isPremium to true');
Assert.isTrue(context.isActive, 'Account Status "Active" should set isActive to true');
```

2. Check formula syntax in metadata

3. Temporarily remove formula to verify action works without it

#### Issue: Governor Limits Exceeded

**Symptoms:** [SOQL query limit](https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_gov_limits.htm), DML row limit, or CPU time exceeded.

**Possible Causes:**

1. SOQL in loops
2. Not using caching pattern
3. Multiple actions querying same data

**Solutions:**

1. Implement caching pattern:

```apex
// BAD - Each action queries separately
public class TRG_Action1 {
	public void beforeUpdate(List<Account> accounts) {
		List<Contact> contacts = [SELECT...]; // Query 1
	}
}
public class TRG_Action2 {
	public void beforeUpdate(List<Account> accounts) {
		List<Contact> contacts = [SELECT...]; // Query 2 (duplicate!)
	}
}

// GOOD - Cache in Order 10, reuse in later actions
public inherited sharing class TRG_CacheContacts extends TRG_Base
{
	private static Map<Id, List<Contact>> cache;

	public void beforeUpdate(List<Account> accounts)
	{
		// Query once, cache
	}

	public static List<Contact> getCached(Id accountId)
	{
		return cache.get(accountId);
	}
}

public inherited sharing class TRG_Action1 extends TRG_Base
{
	public void beforeUpdate(List<Account> accounts)
	{
		List<Contact> contacts = TRG_CacheContacts.getCached(account.Id); // No query!
	}
}
```

2. Use bulkification:

```apex
// BAD - DML in loop
for(Account acc : accounts) {
	insert new Task(WhatId = acc.Id);
}

// GOOD - Collect and DML once
List<Task> tasks = new List<Task>();
for(Account account : accounts)
{
	tasks.add(new Task(WhatId = account.Id));
}
DML_Builder.newTransaction().doInsert(tasks).execute();
```

#### Issue: Recursion Loop

**Symptoms:** Stack depth exceeded, governor limits.

**Possible Causes:**

1. `AllowRecursion__c = true` (default)
2. Action causes DML that triggers itself

**Solutions:**

1. Set `AllowRecursion__c = false` in metadata

2. Add static flag:

```apex
private static Boolean hasExecuted = false;

public void afterUpdate(List<Account> accounts)
{
	if(hasExecuted) return;
	hasExecuted = true;

	// ... logic that might cause recursion
}
```

#### Issue: Type Exception

**Symptoms:** "does not implement required interface"

**Possible Causes:**

1. Class doesn't implement correct interface for context
2. Typo in class name in metadata

**Solutions:**

1. Verify class implements interface:

```apex
// For Before Insert context
public inherited sharing class TRG_MyAction extends TRG_Base implements IF_Trigger.BeforeInsert
{
	public void beforeInsert(List<SObject> newRecords) { }
}
```

2. Verify class name in metadata matches exactly

### Debugging Tips

#### Enable Debug Logs

1. **Setup** > **Debug Logs** > **New**
2. Select user
3. Set **Apex Code** to **FINEST**
4. Reproduce issue

#### Add Strategic Log Statements

```apex
public void beforeInsert(List<Account> newAccounts)
{
	LOG_Builder.build().debug('START beforeInsert, record count: ' + newAccounts.size()).emitAt('TRG_MyAction.beforeInsert');

	// ... logic

	LOG_Builder.build().debug('END beforeInsert').emitAt('TRG_MyAction.beforeInsert');
}
```

#### Test in Isolation

```apex
@IsTest
private static void isolatedTest()
{
	// Bypass all other actions
	TRG_Base.bypassAction('TRG_Action1');
	TRG_Base.bypassAction('TRG_Action2');

	// Test only TRG_MyAction
	Account account = (Account)TST_Builder.of(Account.SObjectType).build();

	// Clear bypasses
	TRG_Base.clearAllActionBypasses();
}
```

#### Query Metadata Configuration

```apex
List<TriggerAction__mdt> actions = SEL_TriggerAction.findActiveByObjectNameAndTriggerOperation('Account', TriggerOperation.BEFORE_INSERT);

for(TriggerAction__mdt action : actions)
{
	String target = String.isNotBlank(action.ApexClassName__c) ? action.ApexClassName__c : 'Flow:' + action.FlowName__c;
	LOG_Builder.build().debug(
		action.Order__c + ': ' + target
		+ ' | Bypassed: ' + action.BypassExecution__c
		+ ' | Allow Recursion: ' + action.AllowRecursion__c
		+ ' | Entry Criteria: ' + action.EntryCriteriaFormula__c
	).emitAt('Troubleshooting.queryMetadata');
}
```

---

## Related Documentation

- [Logging - Guide](Logging%20-%20Guide.md) - Trigger performance logging and correlation tracking
- [Validation - Guide](Validation%20-%20Guide.md) - Formula-driven validation via `TRG_ExecuteValidationRules`
- [DML - Guide](DML%20-%20Guide.md) - DML operations and test data factories
- [Selectors - Guide](Selectors%20-%20Guide.md) - Query patterns used within trigger actions
- [Web Services - Guide](Web%20Services%20-%20Guide.md) - API callout orchestration from trigger contexts
- [Security - Guide](Security%20-%20Guide.md#data-masking) - The data masking pass that `ApplyMasking__c` runs before trigger actions

---

**End of Document**
