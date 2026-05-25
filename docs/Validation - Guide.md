# Validation - Guide

**Framework:** KernDX
**Package Type:** Managed Package

> **Note for Client Implementations:** When using KernDX in a subscriber org, prefix framework class references with your organization's namespace (e.g., `AcmeLib.UTIL_ValidationRule`). See the [AI Agent Instructions](AI%20Agent%20Instructions.md) for details.

**Target Audience:**
- **Developers** - Building validation rules with cross-object queries, custom context classes, and programmatic bypass logic
- **Architects** - Designing validation strategies with proper bypass hierarchy, execution strategies, and bulk patterns
- **Admins** - Configuring validation rules via custom metadata, Flow integration, and shadow mode testing

---

## Table of Contents

<details>
<summary>Expand</summary>

1. [Quick Navigation](#quick-navigation)
2. [Overview](#overview)
   - [What is the Validation Framework?](#what-is-the-validation-framework)
   - [Key Benefits](#key-benefits)
   - [KernDX vs OOTB: Validation Comparison](#kerndx-vs-ootb-validation-comparison)
     - [Salesforce Out-of-the-Box Alternatives](#salesforce-out-of-the-box-alternatives)
     - [Pros & Cons Comparison](#pros--cons-comparison)
     - [When to Use KernDX Validation Framework](#when-to-use-kerndx-validation-framework)
     - [When to Use Standard Validation Rules](#when-to-use-standard-validation-rules)
3. [Quick Start](#quick-start)
4. [Architecture](#architecture)
   - [Architecture Diagram](#architecture-diagram)
   - [Component Overview](#component-overview)
   - [Bypass Hierarchy](#bypass-hierarchy)
   - [Execution Strategies](#execution-strategies)
   - [Rule Ordering Across Groups](#rule-ordering-across-groups)
5. [Custom Metadata Configuration](#custom-metadata-configuration)
   - [ValidationRuleGroup__mdt](#validationrulegroup__mdt)
     - [Timing + Operations Examples](#timing--operations-examples)
   - [ValidationRule__mdt](#validationrule__mdt)
6. [Context Classes](#context-classes)
   - [Built-in Context Classes](#built-in-context-classes)
   - [Creating Custom Context Classes](#creating-custom-context-classes)
   - [Bulk Context Pattern](#bulk-context-pattern)
     - [Usage in Formula](#usage-in-formula)
7. [Formula Syntax](#formula-syntax)
   - [Supported Functions](#supported-functions)
   - [Accessing Context Properties](#accessing-context-properties)
     - [Change Detection](#change-detection)
   - [Error Message Merge Fields](#error-message-merge-fields)
8. [Flow Integration](#flow-integration)
   - [Validating Records in Flow](#validating-records-in-flow)
   - [Bypassing Validation in Flow](#bypassing-validation-in-flow)
   - [Displaying Errors in Screen Flows](#displaying-errors-in-screen-flows)
9. [Programmatic Usage](#programmatic-usage)
   - [Bypass Methods](#bypass-methods)
     - [Bypass Audit Trail](#bypass-audit-trail)
   - [Direct Validation](#direct-validation)
10. [Testing](#testing)
    - [Using UTIL_ValidationTestHelper](#using-util_validationtesthelper)
    - [Testing Best Practices](#testing-best-practices)
11. [Advanced Features](#advanced-features)
    - [Shadow Mode](#shadow-mode)
      - [Querying Shadow Violations](#querying-shadow-violations)
    - [Severity Levels](#severity-levels)
    - [Multi-Language Support](#multi-language-support)
      - [Example Setup](#example-setup)
12. [Anti-Patterns](#anti-patterns)
13. [Best Practices](#best-practices)
    - [Subscriber-shipped demo rules](#subscriber-shipped-demo-rules)
    - [Bulk Data Load Considerations](#bulk-data-load-considerations)
      - [Bypass Options for Bulk Loads](#bypass-options-for-bulk-loads)
14. [Troubleshooting](#troubleshooting)
    - [Common Issues](#common-issues)
    - [Enabling Performance Monitoring](#enabling-performance-monitoring)
    - [Debugging Tips](#debugging-tips)
15. [Related Documentation](#related-documentation)

</details>

---

## Quick Navigation

| I am a...     | I need to...                      | Go to...                                                                     |
|---------------|-----------------------------------|------------------------------------------------------------------------------|
| **Architect** | Understand validation architecture| [Architecture](#architecture)                                                |
| **Architect** | Plan bypass strategies            | [Bypass Hierarchy](#bypass-hierarchy)                                        |
| **Developer** | Create a validation rule          | [Quick Start](#quick-start)                                                  |
| **Developer** | Write custom context classes      | [Context Classes](#context-classes)                                          |
| **Developer** | Test validations                  | [Testing](#testing)                                                          |
| **Analyst**   | Configure validation rules        | [Custom Metadata Configuration](#custom-metadata-configuration)              |
| **Analyst**   | Integrate validations in Flows    | [Flow Integration](#flow-integration)                                        |

---

## Overview

### What is the Validation Framework?

The Validation Framework provides **formula-driven declarative validation** for advanced scenarios that standard [Salesforce validation rules](https://help.salesforce.com/s/articleView?id=sf.fields_defining_field_validation_rules.htm&language=en_US&type=5) cannot handle. It leverages Salesforce's [`FormulaEval` namespace](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_namespace_formulaeval.htm) (same technology used by Flow Entry Criteria) to evaluate validation formulas at runtime.

Key capabilities include:

- **Cross-object validation** requiring queries (e.g., "Account must have at least one Contact")
- **Aggregate validation** (e.g., "Total of child records must not exceed parent limit")
- **Conditional bypass logic** based on user permissions or feature flags
- **Shadow mode deployment** for testing rules in production without blocking saves
- **Warning-level validations** that log but don't block
- **Centralized validation management** across multiple objects

> **Responsibilities:** The Validation Framework evaluates rules and surfaces errors. It does not perform DML, modify field values, or
> contain business logic beyond pass/fail evaluation. Data enrichment for validation (cross-object lookups) belongs in context classes.

> **When NOT to use this pattern:**
> - Simple field-level validations (required, format, range) that standard validation rules handle natively
> - Single-object checks with formulas under 5,000 characters and no bypass requirements
> - Duplicate detection -- use Salesforce Duplicate Rules instead

### Key Benefits

| Benefit | Description |
|---------|-------------|
| **Declarative Configuration** | Rules defined via custom metadata - no code deployment for rule changes |
| **Cross-Object Queries** | Bulk context pattern enables efficient validation requiring related data |
| **Three-Level Bypass** | Object --> Group --> Rule hierarchy with permission/feature flag integration |
| **Shadow Mode** | Test rules in production without blocking saves - violations logged for monitoring |
| **Flow Integration** | Invocable actions + `validationErrors` component for Screen Flows |
| **Execution Strategies** | Accumulate (collect all errors) or Fail Fast (stop on first error) |
| **Warning Severity** | Log data quality issues without blocking saves |
| **Test Utilities** | [`UTIL_ValidationTestHelper`](reference/apex/UTIL_ValidationTestHelper.md) for subscriber org testing |

> **Validation Framework Scope:** Formula-driven rules using Salesforce's `FormulaEval` namespace, managed via `ValidationRule__mdt` and
> `ValidationRuleGroup__mdt` custom metadata. Includes Flow integration, shadow mode, and three-level bypass hierarchy.

---

### KernDX vs OOTB: Validation Comparison

#### Salesforce Out-of-the-Box Alternatives

Salesforce provides several native validation capabilities:

1. **[Validation Rules](https://help.salesforce.com/s/articleView?id=sf.fields_defining_field_validation_rules.htm&language=en_US&type=5)** - Formula-based rules on single objects (Setup --> Object --> Validation Rules)
2. **[Flow Decision Elements](https://help.salesforce.com/s/articleView?id=sf.flow_ref_elements_decision.htm&language=en_US&type=5)** - Validate in Flows using Decision elements and Fault paths
3. **Apex Trigger Validation** - Custom `addError()` calls in trigger handlers
4. **[Duplicate Rules](https://help.salesforce.com/s/articleView?id=sf.duplicate_rules_overview.htm&language=en_US&type=5)** - Prevent duplicate records based on matching rules

#### Pros & Cons Comparison

| Feature | KernDX Validation Framework | Standard Validation Rules | Apex Trigger Validation |
|---------|--------------------------|---------------------------|-------------------------|
| **Code Required** | Context class for custom objects | No code (formula only) | Full Apex implementation |
| **Cross-Object Queries** | Via bulk context pattern | Not supported | Manual SOQL |
| **Aggregate Validation** | Via context properties | Not supported | Manual implementation |
| **Conditional Bypass** | Permission/Feature Flag based | Manual formula conditions | Manual implementation |
| **Shadow Mode** | Built-in logging without blocking | Not available | Manual implementation |
| **Warning Severity** | Log-only option | Always blocks | Manual implementation |
| **Flow Integration** | Invocable actions + LWC | Triggers on DML only | Invocables required |
| **Centralized Management** | All rules in custom metadata | Scattered per object | Scattered in code |
| **Test Utilities** | [`UTIL_ValidationTestHelper`](reference/apex/UTIL_ValidationTestHelper.md) | Test via DML only | Manual test setup |
| **Execution Control** | Accumulate or Fail Fast | Always accumulates | Manual implementation |
| **Error Display** | Field-level or record-level | Field-level | Field-level |
| **Formula Engine** | FormulaEval with globals | Standard formula | N/A |
| **Setup Complexity** | Metadata + trigger action | UI-based only | Code deployment |

#### When to Use KernDX Validation Framework

- **Cross-object validation** requiring queries to related records
- **Aggregate validation** checking totals, counts, or sums
- **Conditional bypass** based on Feature Flags
- **Shadow mode testing** for new rules in production
- **Warning-level validations** for data quality monitoring
- **Flow-based validation** with error display in Screen Flows
- **Centralized rule management** across multiple objects
- **Execution strategy control** (fail fast vs accumulate)

#### When to Use Standard Validation Rules

- **Simple field validations** (required, format, range)
- **Single-object validation** without cross-object queries
- **Formulas under 5000 characters** without complex logic
- **No bypass requirements** beyond standard profile/permission controls
- **Quick implementation** without custom metadata setup

---

## Quick Start

Define validation rules declaratively via `ValidationRule__mdt` custom metadata -- no Apex required.

> **Step-by-step walkthrough:** [Fast Start - Custom Validations](Fast%20Start%20-%20Custom%20Validations.md) covers implementation,
> testing, and common pitfalls.

```text
ValidationRule__mdt key fields:
  RuleFormula__c     = newRecord.Type = 'Enterprise' && ISBLANK(newRecord.Industry)
  ErrorMessage__c    = Industry is required for Enterprise accounts
  ErrorDisplayField__c = Industry
  Severity__c        = Error
  Order__c           = 10
```

For deeper coverage, continue reading the sections below.

---

## Architecture

### Architecture Diagram

```text
+-------------------------------------------------------------------------+
|                    VALIDATION FRAMEWORK ARCHITECTURE                      |
+-------------------------------------------------------------------------+
|                                                                           |
|  CONFIGURATION LAYER (Custom Metadata)                                    |
|  =====================================                                    |
|                                                                           |
|  +---------------------------+     +---------------------------+          |
|  |  ValidationRuleGroup__mdt |     |    ValidationRule__mdt    |          |
|  +---------------------------+     +---------------------------+          |
|  | - TriggerSetting__c       |<----| - ValidationRuleGroup__c  |          |
|  | - TriggerTiming__c        |     | - RuleFormula__c          |          |
|  | - TriggerOperations__c    |     | - ErrorMessage__c         |          |
|  | - ExecutionStrategy__c    |     | - Severity__c             |          |
|  | - ContextClassName__c     |     | - ShadowMode__c           |          |
|  | - BypassFeatureFlag__c    |     | - Order__c                |          |
|  +---------------------------+     +---------------------------+          |
|                                                                           |
+-------------------------------------------------------------------------+
|                                                                           |
|  FRAMEWORK LAYER (Apex)                                                   |
|  ======================                                                   |
|                                                                           |
|  +---------------------------+     +---------------------------+          |
|  |    UTIL_ValidationRule    |<----|    SEL_ValidationRules    |          |
|  +---------------------------+     +---------------------------+          |
|  | - validate()              |     | - Caching layer           |          |
|  | - applyErrors()           |     | - Metadata queries        |          |
|  | - bypassObject/Group/Rule |     +---------------------------+          |
|  | - clearAllBypasses()      |                                            |
|  +---------------------------+                                            |
|              |                                                            |
|              v                                                            |
|  +---------------------------+     +---------------------------+          |
|  |    UTIL_FormulaFilter     |     |    UTIL_FormulaContext    |          |
|  +---------------------------+     +---------------------------+          |
|  | - FormulaEval engine      |     | - Built-in contexts       |          |
|  | - evaluate()              |     | - Standard object support |          |
|  +---------------------------+     +---------------------------+          |
|                                                                           |
+-------------------------------------------------------------------------+
|                                                                           |
|  INTEGRATION LAYER                                                        |
|  =================                                                        |
|                                                                           |
|  +------------------+  +----------------------+  +--------------------+   |
|  | TRG_Execute      |  | FLOW_Execute         |  | validationErrors   |   |
|  | ValidationRules  |  | ValidationRules      |  | (LWC)              |   |
|  +------------------+  +----------------------+  +--------------------+   |
|  | Trigger Action   |  | Flow Invocable       |  | Screen Flow LWC    |   |
|  +------------------+  +----------------------+  +--------------------+   |
|                                                                           |
|  +------------------+  +----------------------+                           |
|  | FLOW_Bypass      |  | FLOW_ClearValidation |                           |
|  | Validation       |  | Bypass               |                           |
|  +------------------+  +----------------------+                           |
|  | Flow Bypass      |  | Flow Clear Bypass    |                           |
|  +------------------+  +----------------------+                           |
|                                                                           |
+-------------------------------------------------------------------------+
|                                                                           |
|  BYPASS HIERARCHY                                                         |
|  ================                                                         |
|                                                                           |
|     Level 1: Object     -->  Bypasses ALL rules for an object            |
|         |                                                                 |
|         v                                                                 |
|     Level 2: Group      -->  Bypasses all rules in a specific group      |
|         |                                                                 |
|         v                                                                 |
|     Level 3: Rule       -->  Bypasses a single rule                      |
|                                                                           |
+-------------------------------------------------------------------------+
```

### Component Overview

| Component | Type | Purpose |
|-----------|------|---------|
| [`ValidationRuleGroup__mdt`](reference/metadata/ValidationRuleGroup__mdt.md) | Custom Metadata | Groups rules by object and trigger context |
| [`ValidationRule__mdt`](reference/metadata/ValidationRule__mdt.md) | Custom Metadata | Individual validation rule configuration |
| [`UTIL_ValidationRule`](reference/apex/UTIL_ValidationRule.md) | Apex Class | Core validation engine with bypass methods |
| [`UTIL_ValidationRule.ValidationResult`](reference/apex/UTIL_ValidationRule.ValidationResult.md) | Inner Class | Result object containing errors and validity status |
| [`UTIL_ValidationRule.ValidationError`](reference/apex/UTIL_ValidationRule.ValidationError.md) | Inner Class | Error details with @AuraEnabled for LWC |
| [`UTIL_ValidationRule.INT_BulkValidationContext`](reference/apex/UTIL_ValidationRule.INT_BulkValidationContext.md) | Interface | Interface for bulk query optimization |
| [`UTIL_ValidationTestHelper`](reference/apex/UTIL_ValidationTestHelper.md) | Apex Class | Global test utility for subscriber orgs |
| `SEL_ValidationRules` | Apex Class | Selector with caching (package-internal, public not global) |
| [`TRG_ExecuteValidationRules`](reference/apex/TRG_ExecuteValidationRules.md) | Apex Class | Pre-built trigger action |
| [`FLOW_ExecuteValidationRules`](reference/apex/FLOW_ExecuteValidationRules.md) | Apex Class | Flow invocable action |
| [`FLOW_BypassValidation`](reference/apex/FLOW_BypassValidation.md) | Apex Class | Flow bypass action |
| [`FLOW_ClearValidationBypass`](reference/apex/FLOW_ClearValidationBypass.md) | Apex Class | Flow clear bypass action |
| [`DTO_FlowValidationError`](reference/apex/DTO_FlowValidationError.md) | Apex Class | Validation error DTO for Flow integration |
| `validationErrors` | LWC | Error display component for Screen Flows |

### Bypass Hierarchy

The framework supports three levels of bypass, evaluated in order:

```text
1. Object Level    -> Bypasses ALL rules for an object
2. Group Level     -> Bypasses all rules in a specific group
3. Rule Level      -> Bypasses a single rule
```

Each level can be bypassed via:
- **Programmatic bypass** - [`UTIL_ValidationRule`](reference/apex/UTIL_ValidationRule.md)`.bypassObject/Group/Rule()`
- **Feature Flag bypass** - `BypassFeatureFlag__c` / `RequiredFeatureFlag__c` on group or rule metadata
- **Metadata bypass** - `BypassExecution__c` checkbox

### Execution Strategies

| Strategy | Behavior | Use Case |
|----------|----------|----------|
| **Accumulate** (default) | Collects all validation errors before returning | User-friendly - shows all issues at once |
| **Fail Fast** | Stops after the first error per record | Performance - quick rejection of invalid data |

Configure via `ExecutionStrategy__c` picklist on `ValidationRuleGroup__mdt`.

### Rule Ordering Across Groups

**Important:** Groups do not have an `Order__c` field. Instead, **rule-level `Order__c` provides global ordering across all groups** for a given object and trigger context.

This design enables architects to interleave lightweight and expensive validations regardless of group membership:

```text
+-------------------------------------------------------------+
|  Execution Order (all rules sorted by Order__c globally)     |
+-------------------------------------------------------------+
|  Order 10:  Account_Require_Name      (Group: Field_Checks)  |
|  Order 20:  Account_Require_Industry  (Group: Field_Checks)  |
|  Order 100: Account_Has_Contacts      (Group: Cross_Object)  |
|  Order 110: Account_Revenue_Threshold (Group: Cross_Object)  |
+-------------------------------------------------------------+
```

**Best Practice for Fail Fast:**
- Assign **low Order values (10-50)** to lightweight field checks
- Assign **high Order values (100+)** to expensive cross-object queries
- With Fail Fast, if a lightweight rule fails first, expensive queries are skipped

**Example Configuration:**

| Rule | Group | Order | Type |
|------|-------|-------|------|
| `Account_Require_Name` | Field_Validations | 10 | Lightweight |
| `Account_Require_Industry` | Field_Validations | 20 | Lightweight |
| `Account_Has_Primary_Contact` | Cross_Object_Checks | 100 | Expensive |
| `Account_Credit_Limit_Check` | Cross_Object_Checks | 110 | Expensive |

---

## Custom Metadata Configuration

### [`ValidationRuleGroup__mdt`](reference/metadata/ValidationRuleGroup__mdt.md)

Groups validation rules for a specific object and trigger context.

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| TriggerSetting__c | MetadataRelationship | Yes | Links to the object's TriggerSetting |
| TriggerTiming__c | Text | Yes | Semicolon-separated: `Before`, `After` |
| TriggerOperations__c | Text | Yes | Semicolon-separated: `Insert`, `Update`, `Delete`, `Undelete` |
| Description__c | Long Text | Yes | Business purpose of this group |
| ContextClassName__c | Text | No | Default context class for rules in this group |
| ExecutionStrategy__c | Picklist | No | `Accumulate` (default) or `Fail Fast` |
| BypassExecution__c | Checkbox | No | Bypass all rules in this group |
| BypassFeatureFlag__c | MetadataRelationship(FeatureFlag__mdt) | No | Feature Flag that bypasses all rules in this group when enabled |
| RequiredFeatureFlag__c | MetadataRelationship(FeatureFlag__mdt) | No | Feature Flag required for rules to execute |

#### Timing + Operations Examples

| Timing | Operations | Result |
|--------|------------|--------|
| Before | Insert;Update | BEFORE_INSERT, BEFORE_UPDATE |
| After | Insert;Update;Delete | AFTER_INSERT, AFTER_UPDATE, AFTER_DELETE |
| Before;After | Insert | BEFORE_INSERT, AFTER_INSERT |

### [`ValidationRule__mdt`](reference/metadata/ValidationRule__mdt.md)

Individual validation rule configuration.

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| ValidationRuleGroup__c | MetadataRelationship | Yes | Parent group |
| RuleFormula__c | Long Text | Yes | Formula that returns `true` when validation **fails** |
| ErrorMessage__c | Long Text | Yes | Message shown when validation fails |
| ErrorDisplayField__c | Text | No | API name of field to attach error to |
| Severity__c | Picklist | Yes | `Error` (blocks save) or `Warning` (logs only) |
| Order__c | Number | No | Global execution order across all groups (lower = first) |
| Description__c | Long Text | Yes | Business purpose of this rule |
| ContextClassName__c | Text | No | Override context class for this rule |
| ShadowMode__c | Checkbox | No | Log but don't block (testing mode) |
| BypassExecution__c | Checkbox | No | Bypass this rule |
| BypassFeatureFlag__c | MetadataRelationship(FeatureFlag__mdt) | No | Feature Flag that bypasses this rule when enabled |
| RequiredFeatureFlag__c | MetadataRelationship(FeatureFlag__mdt) | No | Feature Flag required for this rule to execute |

---

## Context Classes

Context classes provide data to validation formulas. They expose properties that formulas can reference.

### Built-in Context Classes

The framework auto-detects context classes for standard objects via [`UTIL_FormulaContext`](reference/apex/UTIL_FormulaContext.md):

| Object | Context Class | Properties |
|--------|---------------|------------|
| Account | `UTIL_FormulaContext.AccountContext` | `oldRecord`, `newRecord` |
| Contact | `UTIL_FormulaContext.ContactContext` | `oldRecord`, `newRecord` |
| Lead | `UTIL_FormulaContext.LeadContext` | `oldRecord`, `newRecord` |
| Opportunity | `UTIL_FormulaContext.OpportunityContext` | `oldRecord`, `newRecord` |
| Case | `UTIL_FormulaContext.CaseContext` | `oldRecord`, `newRecord` |
| Campaign | `UTIL_FormulaContext.CampaignContext` | `oldRecord`, `newRecord` |
| Task | `UTIL_FormulaContext.TaskContext` | `oldRecord`, `newRecord` |
| Event | `UTIL_FormulaContext.EventContext` | `oldRecord`, `newRecord` |
| User | `UTIL_FormulaContext.UserContext` | `oldRecord`, `newRecord` |

**Important:** Do NOT extend the built-in `UTIL_FormulaContext` classes. If you need additional properties (e.g., for cross-object queries), create a fresh context class that implements the interface directly. Extending framework classes creates fragile dependencies on internal code that may change between versions.

### Creating Custom Context Classes

For custom objects or when you need additional context data, create a custom context class:

```apex
/**
 * @description Context class for CustomObject__c validation rules.
 */
global inherited sharing class VAL_CustomObjectContext
	implements UTIL_FormulaFilter.INT_SObjectFormulaEvaluationContext
{
	/**
	 * @description The record state BEFORE the DML operation.
	 */
	global CustomObject__c oldRecord;

	/**
	 * @description The record state AFTER the DML operation.
	 */
	global CustomObject__c newRecord;

	/**
	 * @description Sets the context for formula evaluation.
	 *
	 * @param oldSObject The record before DML
	 * @param newSObject The record after DML
	 */
	public void setContext(SObject oldSObject, SObject newSObject)
	{
		this.oldRecord = (CustomObject__c)oldSObject;
		this.newRecord = (CustomObject__c)newSObject;
	}
}
```

Register the context class in `ContextClassName__c` on the ValidationRuleGroup or ValidationRule.

### Bulk Context Pattern

For validation rules that need to query related data (cross-object validation), implement the [`INT_BulkValidationContext`](reference/apex/UTIL_ValidationRule.INT_BulkValidationContext.md) bulk context pattern to avoid SOQL in loops:

```apex
/**
 * @description Bulk context for Account validation with Contact data.
 * Demonstrates efficient cross-object validation.
 */
global inherited sharing class VAL_AccountWithContactsContext
	implements UTIL_FormulaFilter.INT_SObjectFormulaEvaluationContext,
	UTIL_ValidationRule.INT_BulkValidationContext
{
	global Account oldRecord;
	global Account newRecord;

	/**
	 * @description Number of contacts for this account.
	 * Populated by preLoad(), used in formulas.
	 */
	global Integer ContactCount;

	// Cache populated by preLoad()
	private Map<Id, Integer> contactCountByAccountId = new Map<Id, Integer>();

	/**
	 * @description Called ONCE before processing all records.
	 * Query all related data here to avoid SOQL in loops.
	 */
	global void preLoad(List<SObject> newRecords, List<SObject> oldRecords)
	{
		Set<Id> accountIds = new Set<Id>();
		for(SObject record : newRecords)
		{
			if(record.Id != null)
			{
				accountIds.add(record.Id);
			}
		}

		if(accountIds.isEmpty())
		{
			return;
		}

		// Single bulk query for all records using QRY_Builder
		List<QRY_Builder.AggregateRow> results = QRY_Builder.selectFrom(Contact.SObjectType)
			.count('Id')
			.groupBy(Contact.AccountId)
			.condition(Contact.AccountId).isIn(new List<Id>(accountIds))
			.toAggregateList();

		for(QRY_Builder.AggregateRow result : results)
		{
			contactCountByAccountId.put(
				(Id)result.get('AccountId'),
				(Integer)result.get('count_Id')
			);
		}
	}

	/**
	 * @description Called for EACH record to set current context.
	 */
	public void setContext(SObject oldSObject, SObject newSObject)
	{
		this.oldRecord = (Account)oldSObject;
		this.newRecord = (Account)newSObject;

		// Retrieve pre-loaded data for this record
		Id accountId = this.newRecord?.Id ?? this.oldRecord?.Id;
		this.ContactCount = contactCountByAccountId.get(accountId) ?? 0;
	}
}
```

#### Usage in Formula

```text
newRecord.Type = 'Customer' && ContactCount = 0
```

---

## Formula Syntax

### Supported Functions

The framework uses Salesforce's [`FormulaEval` namespace](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_namespace_formulaeval.htm) for dynamic formula evaluation. See [Formula Evaluation in Apex](https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_formulaeval.htm) for details on the underlying engine.

Common supported functions include:

| Category | Functions |
|----------|-----------|
| Logical | `AND()`, `OR()`, `NOT()`, `IF()`, `CASE()`, `ISBLANK()`, `ISNULL()` |
| Text | `TEXT()`, `LEFT()`, `RIGHT()`, `MID()`, `LEN()`, `CONTAINS()`, `BEGINS()` |
| Math | `ABS()`, `CEILING()`, `FLOOR()`, `ROUND()`, `MAX()`, `MIN()` |
| Date | `TODAY()`, `NOW()`, `DATE()`, `YEAR()`, `MONTH()`, `DAY()` |
| Comparison | `=`, `<>`, `<`, `>`, `<=`, `>=` |

For the complete list of supported functions, see [Formula Operators and Functions](https://help.salesforce.com/s/articleView?id=platform.customize_functions_parent.htm&language=en_US&type=5) in Salesforce Help.

**Global Variables:**

[Global variables](https://help.salesforce.com/s/articleView?language=en_US&id=sf.dev_understanding_global_variables.htm) available in FormulaEval:

| Variable | Description | Example |
|----------|-------------|---------|
| `$User` | Current user fields | `$User.Id`, `$User.ProfileId` |
| `$Profile` | Current user's profile | `$Profile.Name` |
| `$Permission` | Custom permissions | `$Permission.Bypass_Validation` |
| `$Organization` | Org-level info | `$Organization.Id` |
| `$Label` | Custom labels | `$Label.MyCustomLabel` |

### Accessing Context Properties

Formulas access context class properties directly:

```text
// Access new record fields
newRecord.Name
newRecord.Industry
newRecord.AnnualRevenue

// Access old record fields (for update context)
oldRecord.Status
oldRecord.Amount

// Access custom context properties
ContactCount
HasActiveContract
TotalLineItemAmount
```

#### Change Detection

ISCHANGED alternative patterns:

```text
// Field changed from any value to specific value
newRecord.Status__c = 'Closed' && oldRecord.Status__c <> 'Closed'

// Any change to field
newRecord.OwnerId <> oldRecord.OwnerId

// Insert detection (ISNEW equivalent)
ISBLANK(oldRecord)
```

### Error Message Merge Fields

Error messages support merge fields using `{!PropertyName}` syntax:

```text
Account {!newRecord.Name} requires at least one contact before converting to Customer status.
```

**Supported merge patterns:**
- `{!newRecord.FieldName}` - New record field value
- `{!oldRecord.FieldName}` - Old record field value
- `{!CustomProperty}` - Custom context property value

---

## Flow Integration

### Validating Records in Flow

Use the **Execute Validation Rules** invocable action ([`FLOW_ExecuteValidationRules`](reference/apex/FLOW_ExecuteValidationRules.md)):

**Input Variables:**
| Variable | Type | Required | Description |
|----------|------|----------|-------------|
| records | SObject Collection | Yes | Records to validate |
| oldRecords | SObject Collection | No | Old versions (for update context) |
| triggerContext | Text | No | Override context: `BEFORE_INSERT`, `BEFORE_UPDATE`, etc. |

**Output Variables:**
| Variable | Type | Description |
|----------|------|-------------|
| hasErrors | Boolean | True if blocking errors exist |
| hasWarnings | Boolean | True if warnings exist |
| errorMessage | Text | Combined error message |
| errors | [`DTO_FlowValidationError`](reference/apex/DTO_FlowValidationError.md)[] | List of error details |
| warnings | [`DTO_FlowValidationError`](reference/apex/DTO_FlowValidationError.md)[] | List of warning details |

### Bypassing Validation in Flow

Use the **Bypass Validation** invocable action ([`FLOW_BypassValidation`](reference/apex/FLOW_BypassValidation.md)):

**Input Variables:**
| Variable | Type | Required | Description |
|----------|------|----------|-------------|
| bypassType | Text | No | `OBJECT_NAME` (default), `GROUP_NAME`, or `RULE_NAME` |
| name | Text | Yes | API name to bypass |

Use the **Clear Validation Bypass** invocable action ([`FLOW_ClearValidationBypass`](reference/apex/FLOW_ClearValidationBypass.md)) to clear bypasses:

**Input Variables:**
| Variable | Type | Required | Description |
|----------|------|----------|-------------|
| clearAll | Boolean | No | When `true`, clears all active bypasses (`name` is ignored) |
| name | Text | Conditional | API name to clear (required when `clearAll` is `false` or omitted) |

**Example Flow:**
1. Bypass Validation (bypassType: `OBJECT_NAME`, name: `Account`)
2. Update Records
3. Clear Validation Bypass (clearAll: `true`)

### Displaying Errors in Screen Flows

Add the `validationErrors` component to a Screen element:

**Component Properties:**
| Property | Type | Description |
|----------|------|-------------|
| errors | Object[] | Errors from validation action |
| warnings | Object[] | Warnings from validation action |
| errorTitle | String | Custom title for errors section |
| warningTitle | String | Custom title for warnings section |
| showFieldNames | Boolean | Show field names with messages |
| showRuleNames | Boolean | Show rule names (debugging) |

---

## Programmatic Usage

### Bypass Methods

```apex
// Bypass all rules for an object
UTIL_ValidationRule.bypassObject('Account');

// Bypass a specific group
UTIL_ValidationRule.bypassGroup('Account_BeforeInsert');

// Bypass a specific rule
UTIL_ValidationRule.bypassRule('Account_Require_Industry_Enterprise');

// Clear a specific bypass
UTIL_ValidationRule.clearBypass('Account');

// Clear all bypasses
UTIL_ValidationRule.clearAllBypasses();

// Check if bypassed
Boolean isBypassed = UTIL_ValidationRule.isBypassed('Account');
```

#### Bypass Audit Trail

Every `bypassObject` / `bypassGroup` / `bypassRule` / `clearBypass` / `clearAllBypasses` call emits a
`LogEntryEvent__e` with category `BypassEvent` via `UTIL_BypassAudit.emit`. Audit entries record
`surface = 'validation'`, the action (`BYPASS` / `CLEAR` / `CLEAR_ALL`), the target with a scope prefix
(`object:` / `group:` / `rule:`), and the optional reason latched via `UTIL_BypassAudit.setBypassReason(String)`.
The same audit channel covers trigger / query / DML bypasses so subscribers get a single forensic-query
shape across the framework.

```apex
List<LogEntry__c> validationBypasses = QRY_Builder.selectFrom(LogEntry__c.SObjectType)
	.condition(LogEntry__c.ContextData__c).contains('"category":"BypassEvent"')
	.andCondition(LogEntry__c.ContextData__c).contains('"surface":"validation"')
	.orderBy(LogEntry__c.CreatedDate).descending()
	.toList();
```

The `BypassAudit_Enabled` `FeatureFlag__mdt` is a master kill-switch (default-on). Subscribers disable
runtime emission via a `FeatureFlagStrategy__mdt` override when audit volume is too high for an environment.

### Direct Validation

```apex
// Validate records
List<Account> accounts = new List<Account>{account1, account2};
List<UTIL_ValidationRule.ValidationResult> results =
	UTIL_ValidationRule.validate(accounts, null, TriggerOperation.BEFORE_INSERT);

for(UTIL_ValidationRule.ValidationResult result : results)
{
	if(!result.isValid)
	{
		// Handle errors
		for(UTIL_ValidationRule.ValidationError error : result.errors)
		{
			LOG_Builder.build().error(error.message).emitAt('MyClass.myMethod');
		}
	}
}

// Apply errors to records (adds to SObject.addError())
UTIL_ValidationRule.applyErrors(accounts, results);
```

---

## Testing

### Using UTIL_ValidationTestHelper

The [`UTIL_ValidationTestHelper`](reference/apex/UTIL_ValidationTestHelper.md) class provides assertion methods for testing validation rules without boilerplate setup:

> **Cross-namespace surface.** `UTIL_ValidationTestHelper` is the only validation testing surface callable from
> subscriber tests — `kern`-internal `@TestVisible private` factories are not visible across namespaces. Drive
> every subscriber-side validation test through `UTIL_ValidationTestHelper.assertRuleFails` / `assertRulePasses`,
> or fall back to full DML inside `Test.startTest()` / `Test.stopTest()`.

```apex
@IsTest
private class AccountValidation_TEST
{
	/**
	 * @description Tests that Enterprise accounts require Industry.
	 */
	@IsTest
	private static void shouldRequireIndustryForEnterpriseAccounts()
	{
		Account account = (Account)TST_Builder.of(Account.SObjectType)
			.withOverrides(new Map<SObjectField, Object>{ Account.Name => 'Test', Account.Type => 'Enterprise' })
			.withoutInsertion()
			.build();

		// Assert the rule fails
		UTIL_ValidationTestHelper.assertRuleFails(account, 'Account_Require_Industry_Enterprise');
	}

	/**
	 * @description Tests that rule passes when Industry is provided.
	 */
	@IsTest
	private static void shouldPassWhenIndustryProvided()
	{
		Account account = (Account)TST_Builder.of(Account.SObjectType)
			.withOverrides(new Map<SObjectField, Object>{ Account.Name => 'Test', Account.Type => 'Enterprise', Account.Industry => 'Technology' })
			.withoutInsertion()
			.build();

		// Assert the rule passes
		UTIL_ValidationTestHelper.assertRulePasses(account, 'Account_Require_Industry_Enterprise');
	}

	/**
	 * @description Tests update context with old/new record comparison.
	 *
	 * Assumes you have a rule named `Account_Cannot_Change_Type_Without_Approval` that
	 * rejects `ISCHANGED(oldRecord, newRecord, Type)` unless an approval flag is set.
	 * Replace `Account.Type` with any standard or custom field your rule inspects.
	 */
	@IsTest
	private static void shouldValidateTypeChange()
	{
		Account oldAccount = (Account)TST_Builder.of(Account.SObjectType)
			.withOverrides(new Map<SObjectField, Object>{ Account.Name => 'Test', Account.Type => 'Prospect' })
			.withoutInsertion()
			.build();
		Account newAccount = oldAccount.clone();
		newAccount.Type = 'Customer - Direct';

		// Assert rule fails on type change
		UTIL_ValidationTestHelper.assertRuleFails(
			newAccount,
			oldAccount,
			'Account_Cannot_Change_Type_Without_Approval',
			TriggerOperation.BEFORE_UPDATE
		);
	}

	/**
	 * @description Tests advanced assertions using ValidationResult.
	 */
	@IsTest
	private static void shouldReturnMultipleErrors()
	{
		Account account = (Account)TST_Builder.of(Account.SObjectType)
			.withOverride(Account.Name, 'Test')
			.withoutInsertion()
			.build();

		UTIL_ValidationRule.ValidationResult result =
			UTIL_ValidationTestHelper.validate(account);

		Assert.areEqual(2, result.errors.size(), 'Expected 2 validation errors');
		Assert.isFalse(result.isValid, 'Record should be invalid');
	}
}
```

**Available Methods:**

| Method | Description |
|--------|-------------|
| `assertRuleFails(record, ruleName)` | Assert a specific rule fails (insert context) |
| `assertRuleFails(record, oldRecord, ruleName, operation)` | Assert a specific rule fails (any context) |
| `assertRulePasses(record, ruleName)` | Assert a specific rule passes (insert context) |
| `assertRulePasses(record, oldRecord, ruleName, operation)` | Assert a specific rule passes (any context) |
| `validate(record)` | Get full ValidationResult for custom assertions |
| `validate(record, oldRecord, operation)` | Get full ValidationResult with context |

### Testing Best Practices

1. **Test each rule individually** - Use `assertRuleFails` and `assertRulePasses` for focused tests
2. **Test both positive and negative cases** - Ensure rules pass when conditions are met
3. **Test update context** - Use old/new record pairs for update validations
4. **Test bypass behavior** - Verify rules are skipped when bypassed
5. **Use ValidationResult for complex assertions** - Access error details, counts, field names

---

## Advanced Features

### Shadow Mode

Shadow mode allows testing validation rules in production without blocking saves:

1. Set `ShadowMode__c = true` on the validation rule
2. When the rule fails:
   - Error is logged to `LogEntry__c` with `[SHADOW]` prefix
   - Save is **NOT** blocked
   - Violation captured for monitoring

**Use cases:**
- Testing new rules before enforcement
- Monitoring data quality without disruption
- Gradual rollout of validation rules

#### Querying Shadow Violations

```apex
List<LogEntry__c> shadowViolations = QRY_Builder.selectFrom(LogEntry__c.SObjectType)
	.fields(new List<SObjectField>{LogEntry__c.Message__c, LogEntry__c.CreatedDate})
	.condition(LogEntry__c.LogLevel__c).equals('WARN')
	.andCondition(LogEntry__c.Message__c).contains('[SHADOW]')
	.orderBy(LogEntry__c.CreatedDate).descending()
	.withLimit(100)
	.toList();
```

### Severity Levels

| Severity | Behavior |
|----------|----------|
| **Error** | Blocks save, adds error to record via `record.addError()` |
| **Warning** | Logs to LogEntry__c via [`LOG_Builder`](reference/apex/LOG_Builder.md)`.build().warn().emitAt()`, does NOT block save |

**Warning use cases:**
- Data quality monitoring
- Soft deprecation notices
- Informational alerts

### Multi-Language Support

For orgs requiring translated error messages, use [Custom Labels](https://help.salesforce.com/s/articleView?id=sf.cl_about.htm&language=en_US&type=5) with the `{$Label.LabelName}` syntax:

```text
ErrorMessage__c: {$Label.VAL_Account_Email_Required}
```

**Why Custom Labels?**
- Reusable across multiple validation rules
- Proper translation workflow via Setup --> [Translation Workbench](https://help.salesforce.com/s/articleView?id=sf.workbench_overview.htm&language=en_US&type=5)
- Can be packaged and versioned with your application
- Standard Salesforce internationalization pattern

**Important:** The framework does not use `toLabel()` in metadata queries. Direct translations on the `ErrorMessage__c` field via Translation Workbench will **not** be applied at runtime. Always use Custom Labels for multi-language orgs.

#### Example Setup

1. Create a Custom Label:
   - **Name:** `VAL_Account_Email_Required`
   - **Value:** `Email address is required for all accounts.`

2. Add translations via Setup --> Translation Workbench

3. Reference in your validation rule:
   ```
   ErrorMessage__c: {$Label.VAL_Account_Email_Required}
   ```

The framework will resolve the Custom Label at runtime using the user's language preference.

---

## Anti-Patterns

| Anti-Pattern | Why It's Wrong | Instead |
|---|---|---|
| Using the framework for simple required-field checks | Adds unnecessary overhead for validations that standard required fields or validation rules handle natively | Use standard validation rules for simple `ISBLANK()` checks; reserve the framework for cross-object or complex logic |
| Embedding complex formula logic in `RuleFormula__c` fields | Long formulas are hard to debug, maintain, and test | Use custom context classes to pre-compute values, then reference them with simple formulas |
| Ignoring bulk context in custom context classes | Queries inside `preLoad()` run per-record, causing SOQL limit exceptions in bulk operations | Use the `BulkContext` pattern to query once for all records, then cache results |
| Not providing bypass mechanisms for data loads | Bulk data loads fail or run slowly due to unnecessary validation | Use `FLOW_BypassValidation`, `BypassExecution__c`, or one of the `UTIL_ValidationRule.bypassObject()` / `.bypassGroup()` / `.bypassRule()` runtime APIs for migrations |
| Skipping shadow mode testing for new rules | Rules go live with unexpected failures or false positives | Enable `ShadowMode__c` on new rules first to log violations without blocking records |

---

## Best Practices

> **Performance Warning:** While this framework is bulkified, Apex-based formula evaluation consumes more CPU time than native validation rules. For massive data loads (e.g., 10,000+ records via Data Loader), bypass the framework using `BypassExecution__c` or a Feature Flag to ensure stability. See [Bulk Data Load Considerations](#bulk-data-load-considerations) below.

1. **Use standard validation rules first** - Only use this framework for scenarios standard rules cannot handle

2. **Implement bulk context** - Always use [`INT_BulkValidationContext`](reference/apex/UTIL_ValidationRule.INT_BulkValidationContext.md) for cross-object queries

3. **Keep formulas simple** - Complex logic should be computed in context class properties

4. **Use meaningful names** - DeveloperName should clearly indicate purpose

5. **Document rules** - Always fill Description__c field

6. **Test with shadow mode** - Enable shadow mode before enforcing new rules

7. **Order rules using `Order__c`** - Assign low values (10-50) to lightweight checks, high values (100+) to expensive cross-object queries. With Fail Fast strategy, this ensures quick rejection before expensive operations.

8. **Use appropriate severity** - Reserve "Error" for blocking issues

9. **Leverage bypass hierarchy** - Use object/group bypass for bulk operations

10. **Monitor performance** - Check LogEntry__c for slow validation rules

11. **Use Custom Labels for multi-language** - For translated error messages, use `{$Label.LabelName}` syntax

12. **Use UTIL_ValidationTestHelper** - Leverage the test helper for clean, focused validation tests

### Subscriber-shipped demo rules

When you ship a demo or sample validation rule in your own subscriber package, set `BypassExecution__c = true`
on the `ValidationRule__mdt` record. Subscribers then activate the rule by flipping the flag from their
managed-package configuration UI — this prevents the rule from contaminating every record insert across
unrelated tests in their org. The framework's own sample rule follows this convention: it ships with
`BypassExecution__c = true` and is activated only when a subscriber explicitly opts in.

### Bulk Data Load Considerations

When performing bulk data operations (Data Loader, Bulk API, or batch Apex processing large volumes):

| Volume | Recommendation |
|--------|----------------|
| < 1,000 records | Framework operates normally |
| 1,000 - 10,000 records | Monitor CPU time; consider Fail Fast strategy |
| > 10,000 records | Bypass framework via `BypassExecution__c` or Feature Flag |

#### Bypass Options for Bulk Loads

1. **Metadata Bypass:** Set `BypassExecution__c = true` on the ValidationRuleGroup before the load, then uncheck after
2. **Feature Flag Bypass:** Configure `BypassFeatureFlag__c` with a Feature Flag targeting integration users
3. **Programmatic Bypass:** Call `UTIL_ValidationRule.bypassObject('Account')` in batch Apex before DML

**Why bypass?** The framework uses Apex-based `FormulaEval` which has higher CPU overhead than native validation rules compiled into the database engine. For massive loads, native validation rules or post-load data quality reports are more appropriate.

---

## Troubleshooting

### Common Issues

**"No validation rules executed"**
- Verify TriggerAction__mdt is registered for the correct timing
- Check that ValidationRuleGroup timing/operations match the trigger context
- Ensure BypassExecution__c is not checked

**"Formula evaluation failed"**
- Check formula syntax using Formula Builder
- Verify context class exposes required properties as `global`
- Ensure property names match formula references exactly

**"Context class not found"**
- Verify class name is fully qualified (include namespace if needed)
- Ensure class implements [`UTIL_FormulaFilter.INT_SObjectFormulaEvaluationContext`](reference/apex/UTIL_FormulaFilter.INT_SObjectFormulaEvaluationContext.md)
- Check class is `global` or `public`

**"SOQL limit exceeded"**
- Implement [`INT_BulkValidationContext`](reference/apex/UTIL_ValidationRule.INT_BulkValidationContext.md) for cross-object queries
- Move queries to `preLoad()` method
- Use aggregate queries where possible

### Enabling Performance Monitoring

The framework includes built-in performance timing for **context class processing**, **enabled by default** via the `EnableValidationPerformanceLogging__c` hierarchy setting. Each context class's total processing time is measured, including:
- `preLoad()` execution (bulk queries, loop processing, map building)
- All formula evaluations for that context

**Configuration via `LogSetting__c`:**

| Field | Default | Description |
|-------|---------|-------------|
| `EnableValidationPerformanceLogging__c` | `true` | Enable/disable validation context timing |
| `ValidationPerformanceThresholdMs__c` | `100` | Log context processing exceeding this threshold (ms) |

To tune or disable:

1. **Create or edit a `LogSetting__c` record** (hierarchy custom setting — org-default, profile, or user level)
2. **Set `EnableValidationPerformanceLogging__c = false`** to turn monitoring off, or leave the default `true` to keep it on
3. **Set `ValidationPerformanceThresholdMs__c`** to your threshold (e.g., 100 = log context processing >100ms)

Once enabled, each context class logs:
- Total elapsed time (preLoad + formula evaluations)
- Rule count and record count
- Nested within trigger action context for tracing

**Why context-level timing?** Individual formula evaluations are sub-millisecond. The expensive operations happen in `preLoad()` (bulk queries, complex loops). Timing the entire context class processing gives you actionable data - if `VAL_AccountWithContactsContext` is slow, you know exactly which context class needs optimization.

**Nested Tracing:** Validation performance logs appear nested within trigger action logs, providing drill-down visibility:
```text
TRG_ExecuteValidationRules (BEFORE_INSERT) completed in 450ms
  +-- VAL_AccountWithContactsContext validation completed in 380ms (Rules: 5, Records: 200)
```

**Query validation performance logs:**
```apex
List<LogEntry__c> validationLogs = QRY_Builder.selectFrom(LogEntry__c.SObjectType)
	.fields(new List<SObjectField>{LogEntry__c.Message__c, LogEntry__c.DurationMs__c, LogEntry__c.ContextData__c})
	.condition(LogEntry__c.LogLevel__c).equals('PERFORMANCE')
	.andCondition(LogEntry__c.ClassMethod__c).contains('UTIL_ValidationRule/processRulesForContext')
	.orderBy(LogEntry__c.DurationMs__c).descending()
	.withLimit(50)
	.toList();
```

### Debugging Tips

1. **Enable debug logging:**
   ```apex
   LOG_Builder.ignoreTestMode = true;
   ```

2. **Check cached rules (development org only):**
   ```apex
   // Note: SEL_ValidationRules is package-internal (public, not global)
   // This code only works in the development org, not in subscriber orgs
   List<SEL_ValidationRules.ValidationRuleWithGroup> rules =
   	SEL_ValidationRules.findByObjectAndOperation('Account', TriggerOperation.BEFORE_INSERT);
   LOG_Builder.build().info('Found ' + rules.size() + ' rules').emitAt('SEL_ValidationRules');
   ```

3. **Test formula in isolation:**
   ```apex
   UTIL_FormulaFilter filter = new UTIL_FormulaFilter(
   	'ValidationRule:Test',
   	'UTIL_FormulaContext.AccountContext',
   	'newRecord.Type = \'Enterprise\' && ISBLANK(newRecord.Industry)'
   );
   UTIL_FormulaFilter.DTO_FilterResults results = filter.filter(
   	null, new List<Account>{ account }
   );
   Boolean formulaMatched = !results.newRecords.isEmpty();
   ```

---

## Related Documentation

- [Triggers - Guide](Triggers%20-%20Guide.md) - Trigger Action Framework and `TRG_ExecuteValidationRules` integration
- [Selectors - Guide](Selectors%20-%20Guide.md) - Query patterns used in bulk validation context classes
- [Logging - Guide](Logging%20-%20Guide.md) - Shadow mode logging and validation performance monitoring
- [DML - Guide](DML%20-%20Guide.md) - Test data factories for validation test setup
- [Web Services - Guide](Web%20Services%20-%20Guide.md) - API validation patterns using `getValidationErrors()`
