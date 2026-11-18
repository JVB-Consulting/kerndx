---
navOrder: 60
navLabel: "Validation (checking record data)"
movedAnchors: {"why-choose-this-over-standard-validation-rules": "/#validation", "what-you-can-do-with-it": "/#validation", "what-it-does-and-does-not-do": "/validation-guide#how-does-it-work", "salesforce-out-of-the-box-alternatives": "/#validation", "pros-cons-comparison": "/#validation", "pros--cons-comparison": "/#validation"}
---

# Validation - Guide

**Who this page is for:** developers building validation rules with cross-object queries, custom context classes,
and programmatic bypass logic; architects designing validation strategies with the bypass hierarchy, execution
strategies, and bulk patterns; and admins configuring validation rules via custom metadata, Flow integration, and
shadow mode testing.

New to it? Try [Fast Start - Custom Validations](Fast%20Start%20-%20Custom%20Validations.md) first: it covers
implementation, testing, and common pitfalls. Deciding whether to use KernDX? See
[Why KernDX](Strategic%20Guide%20-%20Overview.md).

## Copy this first

The rules themselves are configuration records, not code: the [Quick Start](#quick-start) shows one. This is how
your Apex runs them:

```apex
List<kern.UTIL_ValidationRule.ValidationResult> results =
	kern.UTIL_ValidationRule.validate(accounts, null, TriggerOperation.BEFORE_INSERT);

for(kern.UTIL_ValidationRule.ValidationResult result : results)
{
	if(!result.isValid)
	{
		for(kern.UTIL_ValidationRule.ValidationError error : result.errors)
		{
			kern.LOG_Builder.build().error(error.message).emitAt('MyClass.myMethod');
		}
	}
}
```

**What this does:** runs your org's active rules for new accounts on the records in `accounts`, without saving them.
You get one result for each record. For each record that breaks a rule, the loop saves each error message as an ERROR
log record.

**Read next:** [Write a rule](#quick-start), [Put the errors on the records](#direct-validation),
[Test a rule](#using-util_validationtesthelper), [Switch rules off on purpose](#bypass-methods).

---

## Quick Navigation

| I need to...                                                         | Go to...                                                                        |
|----------------------------------------------------------------------|---------------------------------------------------------------------------------|
| Look up every field on a group or a rule                             | [How do I configure this?](#how-do-i-configure-this)                            |
| Check related records, or a total of child records                   | [How do I access related data?](#how-do-i-access-related-data)                  |
| Read related data without hitting the query limit                    | [Bulk Context Pattern](#bulk-context-pattern)                                   |
| Write a formula, or spot a changed field                             | [Formula Syntax](#formula-syntax)                                               |
| Put a value from the record in the error message                     | [Error Message Merge Fields](#error-message-merge-fields)                       |
| Show every error at once, or stop at the first                       | [Execution Strategies](#execution-strategies)                                   |
| Run cheap checks before expensive ones                               | [Rule Ordering Across Groups](#rule-ordering-across-groups)                     |
| Validate in a Flow and show the errors on a screen                   | [How do I connect it to a Flow?](#how-do-i-connect-it-to-a-flow)                |
| Switch rules off on purpose, for example for a data load             | [Bypass Hierarchy](#bypass-hierarchy), [Bypass Options for Bulk Loads](#bypass-options-for-bulk-loads) |
| See who switched validation off, and why                             | [Bypass Audit Trail](#bypass-audit-trail)                                       |
| Run the rules from Apex and put the errors on the records            | [Direct Validation](#direct-validation)                                         |
| Test a rule without saving a record                                  | [Using UTIL_ValidationTestHelper](#using-util_validationtesthelper)             |
| Try a rule without blocking saves, or only warn                      | [Shadow Mode](#shadow-mode), [Severity Levels](#severity-levels)                |
| Show error messages in more than one language                        | [Multi-Language Support](#multi-language-support)                               |
| Load a large amount of data                                          | [Bulk Data Load Considerations](#bulk-data-load-considerations)                 |
| Ship a sample rule in my own package                                 | [Demo rules you ship in your own package](#demo-rules-you-ship-in-your-own-package) |
| Find the slow rules                                                  | [Enabling Performance Monitoring](#enabling-performance-monitoring)             |
| Fix a rule that does not run, a formula error or a query limit error | [Common Issues](#common-issues)                                                 |
| Understand how the framework runs your rules, and the parts involved | [How does it work?](Validation%20-%20Guide.md#how-does-it-work), [What are the moving parts?](#what-are-the-moving-parts) |
| See why KernDX is worth using                                        | [Why KernDX](/)                                                                 |

---

## Quick Start

The rules themselves are configuration records: to create one, you add a `ValidationRule__mdt` record, with no Apex.
Then pick where the rules run:

| The rules should run...                    | What to set up                                                                                                         |
|--------------------------------------------|------------------------------------------------------------------------------------------------------------------------|
| Every time a record is saved               | A trigger on the object and a `TriggerAction__mdt` record that points at the built-in `TRG_ExecuteValidationRules` action: [Fast Start - Custom Validations](Fast%20Start%20-%20Custom%20Validations.md#trigger-integration) |
| Inside a Flow                              | The **Execute Validation Rules** action: [Validating Records in Flow](#validating-records-in-flow)                     |
| From your own Apex, without saving         | `UTIL_ValidationRule.validate()`, as under [Copy this first](#copy-this-first): [Direct Validation](#direct-validation) |

The example below requires Enterprise accounts to have an Industry:

```text
ValidationRule__mdt key fields:
  RuleFormula__c     = TEXT(newRecord.Type) = 'Enterprise' && ISBLANK(TEXT(newRecord.Industry))
  ErrorMessage__c    = Industry is required for Enterprise accounts
  ErrorDisplayField__c = Industry
  Severity__c        = Error
  Order__c           = 10
```

> **Namespaces in code samples:** `kern.` on a class and `kern__` on an object, field, or metadata type mark the managed package's namespace.
> On the managed package, framework references need those prefixes even where a sample omits them; repackaged under your own namespace, replace `kern`/`kern__`
> with your prefix; on an unmanaged deploy, drop them. See [How to read the code samples](Installation.md#how-to-read-the-code-samples).

---

## What problem does this solve?

Sometimes bad data gets saved that a plain Salesforce validation rule cannot catch. A standard rule only sees the one record being saved, so it cannot look across objects or add up related records. The check you need, "an Account must have at least one Contact before it becomes a Customer", is out of its reach.

This framework fills that gap. You still write the check as a formula in the same language you already know from Flow
entry criteria, but you store it as a configuration record rather than code. That gives you four things a standard
rule cannot:

- a rule can query related records;
- the same rule runs from both Apex and Flow;
- you can roll a rule out quietly before it starts blocking saves;
- you can turn rules off in a controlled, audited way.

Read this if you enforce data quality and you have hit the limits of standard validation rules: checks that span more than one object, checks that need to add up child records, or rules you want to test in production first.

## Mental model

Think of the framework as a nightclub bouncer with a clipboard. A plain Salesforce validation rule is a doorman who
only checks the one ID in front of him. This bouncer does more:

- he checks the VIP list (a cross-object query to related records);
- he counts how many people are already at the table (an aggregate of child records);
- he can flag the dress code without turning the guest away (a Warning that logs the issue versus an Error that blocks
  the save);
- he can work in watch-only mode for a night, noting who he would have stopped without actually stopping anyone
  (shadow mode).

## Use this when

- the check needs a query to **related records** (for example, "Account must have at least one Contact")
- the check is an **aggregate**: a total, count, or sum of child records against a parent limit
- you want a rule that **warns** and logs a data-quality issue without stopping the save
- you want to **try a new rule in production first**, watch-only, before it starts blocking (shadow mode)
- a rule should be **skipped on a condition**, based on user permissions or feature flags
- you want to **manage rules in one place** across many objects, and run the same rule from a trigger and from a Flow

## Don't use this when

A standard Salesforce validation rule is enough when the check is simple and self-contained. Use it, and skip this framework, for:

- **simple field-level checks** (required, format, range) that standard validation rules already handle
- **single-object checks** with formulas under 5,000 characters and no bypass requirement
- **duplicate detection**, which Salesforce Duplicate Rules handle directly

Being honest about the boundary matters: these rules run in Apex, which costs more processing time per record than a native rule, so a standard rule is both simpler and cheaper when it can do the job.

---

## How does it work?

There are three layers:

- you write rules as configuration records;
- the framework evaluates them in Apex;
- three entry points (a trigger, Flow actions, and a screen component) feed records in and show the results.

The diagram below maps those layers, and the tables that follow name each piece.

> **What it does and does not do.** It evaluates rules and reports the errors they find. It does not save records,
> change field values, or hold business logic beyond deciding pass or fail.
>
> When a rule needs extra data to make its decision (such as a cross-object lookup), that data is loaded in a context
> class (see [How do I access related data?](#how-do-i-access-related-data)).
>
> The scope is formula-driven rules that run on Salesforce's `FormulaEval` engine, configured through the
> `ValidationRule__mdt` and `ValidationRuleGroup__mdt` custom metadata types. That scope includes Flow integration,
> shadow mode, and the three-level bypass hierarchy.

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

### What are the moving parts?

You only touch a few of these directly: the two metadata types when you author rules, and the test helper when you write tests. The rest are the moving parts the framework runs for you.

| Component                                                                                                          | Type            | Purpose                                                     |
|--------------------------------------------------------------------------------------------------------------------|-----------------|-------------------------------------------------------------|
| [`ValidationRuleGroup__mdt`](reference/metadata/ValidationRuleGroup__mdt.md)                                       | Custom Metadata | Groups rules by object and trigger context                  |
| [`ValidationRule__mdt`](reference/metadata/ValidationRule__mdt.md)                                                 | Custom Metadata | Individual validation rule configuration                    |
| [`UTIL_ValidationRule`](reference/apex/UTIL_ValidationRule.md)                                                     | Apex Class      | Core validation engine with bypass methods                  |
| [`UTIL_ValidationRule.ValidationResult`](reference/apex/UTIL_ValidationRule.ValidationResult.md)                   | Inner Class     | Result object containing errors and validity status         |
| [`UTIL_ValidationRule.ValidationError`](reference/apex/UTIL_ValidationRule.ValidationError.md)                     | Inner Class     | Error details with @AuraEnabled for LWC                     |
| [`UTIL_ValidationRule.INT_BulkValidationContext`](reference/apex/UTIL_ValidationRule.INT_BulkValidationContext.md) | Interface       | Interface for bulk query optimisation                       |
| [`UTIL_ValidationTestHelper`](reference/apex/UTIL_ValidationTestHelper.md)                                         | Apex Class      | Global test utility you can call from your own tests        |
| `SEL_ValidationRules`                                                                                              | Apex Class      | Internal selector with rule caching                         |
| [`TRG_ExecuteValidationRules`](reference/apex/TRG_ExecuteValidationRules.md)                                       | Apex Class      | Pre-built trigger action                                    |
| [`FLOW_ExecuteValidationRules`](reference/apex/FLOW_ExecuteValidationRules.md)                                     | Apex Class      | Flow invocable action                                       |
| [`FLOW_BypassValidation`](reference/apex/FLOW_BypassValidation.md)                                                 | Apex Class      | Flow bypass action                                          |
| [`FLOW_ClearValidationBypass`](reference/apex/FLOW_ClearValidationBypass.md)                                       | Apex Class      | Flow clear bypass action                                    |
| [`DTO_FlowValidationError`](reference/apex/DTO_FlowValidationError.md)                                             | Apex Class      | A small data-holder class (a DTO) that carries one validation error in and out of Flow |
| `validationErrors`                                                                                                 | LWC             | Error display component for Screen Flows                    |

### Bypass Hierarchy

Sometimes you need to switch validation off on purpose, for example during a data migration or a one-off fix. The framework lets you do that at three levels, from broadest to narrowest, so you only turn off as much as you need:

```text
1. Object Level    -> Bypasses ALL rules for an object
2. Group Level     -> Bypasses all rules in a specific group
3. Rule Level      -> Bypasses a single rule
```

You have three ways to trigger a bypass at any level:

- **From code:** call [`UTIL_ValidationRule`](reference/apex/UTIL_ValidationRule.md)`.bypassObject/Group/Rule()` in Apex
- **By feature flag:** set `BypassFeatureFlag__c` or `RequiredFeatureFlag__c` on the group or rule, so a flag controls whether rules run
- **By a checkbox:** tick the `BypassExecution__c` field on the metadata record

### Execution Strategies

When a record breaks several rules, you decide whether the user sees every problem at once or just the first. That choice is the execution strategy:

| Strategy                 | Behaviour                                       | Use Case                                      |
|--------------------------|-------------------------------------------------|-----------------------------------------------|
| **Accumulate** (default) | Collects all validation errors before returning | Friendlier for users: shows every issue at once |
| **Fail Fast**            | Stops after the first error per record          | Faster: rejects invalid data without running the rest |

Set this with the `ExecutionStrategy__c` picklist on `ValidationRuleGroup__mdt`.

### Rule Ordering Across Groups

You often want a cheap check to run before an expensive one, even when they sit in different groups. Ordering is controlled at the rule level, not the group level, which makes that possible.

**Important:** Groups do not have an `Order__c` field. Instead, **rule-level `Order__c` provides global ordering across all groups** for a given object and trigger context.

So you can interleave lightweight and expensive validations no matter which group each one belongs to:

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

| Rule                          | Group               | Order | Type        |
|-------------------------------|---------------------|-------|-------------|
| `Account_Require_Name`        | Field_Validations   | 10    | Lightweight |
| `Account_Require_Industry`    | Field_Validations   | 20    | Lightweight |
| `Account_Has_Primary_Contact` | Cross_Object_Checks | 100   | Expensive   |
| `Account_Credit_Limit_Check`  | Cross_Object_Checks | 110   | Expensive   |

---

## How do I configure this?

You configure validation with two metadata types. A group says which object and when (the trigger context) a set of rules applies to, and a rule is the individual check. The two tables below list every field on each, when it is required, and what it does. Both are collapsed: open the one you need.

### [`ValidationRuleGroup__mdt`](reference/metadata/ValidationRuleGroup__mdt.md)

A group ties a set of rules to one object and one trigger context (for example, Account on before-insert).

<details>
<summary>Every <code>ValidationRuleGroup__mdt</code> field</summary>

| Field                  | Type                                   | Required | Description                                                     |
|------------------------|----------------------------------------|----------|-----------------------------------------------------------------|
| TriggerSetting__c      | MetadataRelationship                   | Yes      | Links to the object's TriggerSetting                            |
| TriggerTiming__c       | Text                                   | Yes      | Semicolon-separated: `Before`, `After`                          |
| TriggerOperations__c   | Text                                   | Yes      | Semicolon-separated: `Insert`, `Update`, `Delete`, `Undelete`   |
| Description__c         | Long Text                              | Yes      | Business purpose of this group                                  |
| ContextClassName__c    | Text                                   | No       | Default context class for rules in this group                   |
| ExecutionStrategy__c   | Picklist                               | No       | `Accumulate` (default) or `Fail Fast`                           |
| BypassExecution__c     | Checkbox                               | No       | Bypass all rules in this group                                  |
| BypassFeatureFlag__c   | MetadataRelationship(FeatureFlag__mdt) | No       | Feature Flag that bypasses all rules in this group when enabled |
| RequiredFeatureFlag__c | MetadataRelationship(FeatureFlag__mdt) | No       | Feature Flag required for rules to execute                      |

</details>

#### Timing + Operations Examples

| Timing       | Operations           | Result                                   |
|--------------|----------------------|------------------------------------------|
| Before       | Insert;Update        | BEFORE_INSERT, BEFORE_UPDATE             |
| After        | Insert;Update;Delete | AFTER_INSERT, AFTER_UPDATE, AFTER_DELETE |
| Before;After | Insert               | BEFORE_INSERT, AFTER_INSERT              |

### [`ValidationRule__mdt`](reference/metadata/ValidationRule__mdt.md)

A rule is the individual check: the formula, the message, where to show the error, and how the rule behaves.

<details>
<summary>Every <code>ValidationRule__mdt</code> field</summary>

| Field                  | Type                                   | Required | Description                                              |
|------------------------|----------------------------------------|----------|----------------------------------------------------------|
| ValidationRuleGroup__c | MetadataRelationship                   | Yes      | Parent group                                             |
| RuleFormula__c         | Long Text                              | Yes      | Formula that returns `true` when validation **fails**    |
| ErrorMessage__c        | Long Text                              | Yes      | Message shown when validation fails                      |
| ErrorDisplayField__c   | Text                                   | No       | API name of field to attach error to                     |
| Severity__c            | Picklist                               | Yes      | `Error` (blocks save) or `Warning` (logs only)           |
| Order__c               | Number                                 | Yes      | Global execution order across all groups (lower = first). Defaults to 10 |
| Description__c         | Long Text                              | Yes      | Business purpose of this rule                            |
| ContextClassName__c    | Text                                   | No       | Override context class for this rule                     |
| ShadowMode__c          | Checkbox                               | No       | Log but don't block (testing mode)                       |
| BypassExecution__c     | Checkbox                               | No       | Bypass this rule                                         |
| BypassFeatureFlag__c   | MetadataRelationship(FeatureFlag__mdt) | No       | Feature Flag that bypasses this rule when enabled        |
| RequiredFeatureFlag__c | MetadataRelationship(FeatureFlag__mdt) | No       | Feature Flag required for this rule to execute           |

</details>

---

## How do I access related data?

A formula can only check data it can see. A context class is what makes data visible to the formula: it holds the
record being saved (and its previous version), plus any extra values you have looked up, and exposes them as named
properties the formula can reference.

For a simple single-object rule the framework supplies the context for you; you write a context class only when you
need a custom object (other than API Call and API Issue) or extra data.

### Built-in Context Classes

For the common standard objects, and for API Call and API Issue, the framework already provides a context class and picks it automatically, so you write no Apex. Each one exposes the record before the save (`oldRecord`) and after (`newRecord`). The detection happens through [`UTIL_FormulaContext`](reference/apex/UTIL_FormulaContext.md):

| Object      | Context Class                            | Properties               |
|-------------|------------------------------------------|--------------------------|
| Account     | `UTIL_FormulaContext.AccountContext`     | `oldRecord`, `newRecord` |
| Contact     | `UTIL_FormulaContext.ContactContext`     | `oldRecord`, `newRecord` |
| Lead        | `UTIL_FormulaContext.LeadContext`        | `oldRecord`, `newRecord` |
| Opportunity | `UTIL_FormulaContext.OpportunityContext` | `oldRecord`, `newRecord` |
| Case        | `UTIL_FormulaContext.CaseContext`        | `oldRecord`, `newRecord` |
| Campaign    | `UTIL_FormulaContext.CampaignContext`    | `oldRecord`, `newRecord` |
| Task        | `UTIL_FormulaContext.TaskContext`        | `oldRecord`, `newRecord` |
| Event       | `UTIL_FormulaContext.EventContext`       | `oldRecord`, `newRecord` |
| User        | `UTIL_FormulaContext.UserContext`        | `oldRecord`, `newRecord` |
| API Call    | `UTIL_FormulaContext.ApiCallContext`     | `oldRecord`, `newRecord` |
| API Issue   | `UTIL_FormulaContext.ApiIssueContext`    | `oldRecord`, `newRecord` |

**Important:** Do not extend the built-in `UTIL_FormulaContext` classes. When you need extra properties (for example, to support a cross-object query), write a fresh context class that implements the interface directly. Extending a framework class ties your code to internal details that can change between versions, which makes your class brittle.

### Creating Custom Context Classes

When you validate a custom object, or you need data the built-in context does not provide, you write your own context class. It implements the framework's interface and exposes the records (and any extra values) your formula needs.

Put `@JsonAccess(serializable='always')` on every context class you write. The framework fills the merge fields in an
error message by turning your context class into JSON, and Salesforce only lets the installed package do that when
your class allows it with this annotation.

- Without it, every merge field that reads your class comes back blank, and the framework logs a warning that names
  the class.
- The built-in context classes already work and need nothing from you.
- The scan rule [`KernJsonReadClassNeedsJsonAccess`](Code%20Scanning%20-%20Guide.md#kernjsonreadclassneedsjsonaccess)
  flags a context class that is missing the annotation.

```apex
/**
 * @description Context class for CustomObject__c validation rules.
 */
@JsonAccess(serializable='always')
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

Once written, point a rule or group at it by putting the class name in the `ContextClassName__c` field on the ValidationRuleGroup or ValidationRule.

### Bulk Context Pattern

The bulk context pattern loads related data once for the whole batch, up front, then each record reads from the
result. The naive approach (query inside the per-record loop) hits Salesforce's limit on the number of queries and
fails the moment you save records in bulk.

Implement the [`INT_BulkValidationContext`](reference/apex/UTIL_ValidationRule.INT_BulkValidationContext.md)
interface, which adds a `preLoad()` method that runs once before any record is processed:

```apex
/**
 * @description Bulk context for Account validation with Contact data.
 * Demonstrates efficient cross-object validation.
 */
@JsonAccess(serializable='always')
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

		// One grouped count for the whole batch, read through your own Contact selector (a class that extends SEL_Base)
		List<QRY_Builder.AggregateRow> results = new SEL_Contacts().query
			.count('Id')
			.groupBy(Contact.AccountId)
			.condition(Contact.AccountId).isIn(new List<Id>(accountIds))
			.toAggregateList();

		// count('Id') names its result count_Id
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

The value `preLoad()` computed (here, `ContactCount`) is now just another property the formula can reference. This rule fails a Customer account that has no contacts:

```text
TEXT(newRecord.Type) = 'Customer' && ContactCount = 0
```

---

## Formula Syntax

The good news for anyone who has written a Salesforce formula before: this is the same formula language. You already know most of it.

### Supported Functions

Your rule formulas run on Salesforce's [`FormulaEval` namespace](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_namespace_formulaeval.htm), so the functions are the standard Salesforce formula functions. For background on the engine itself, see [Formula Evaluation in Apex](https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_formulaeval.htm).

These are the functions you will use most:

| Category   | Functions                                                                 |
|------------|---------------------------------------------------------------------------|
| Logical    | `AND()`, `OR()`, `NOT()`, `IF()`, `CASE()`, `ISBLANK()`, `ISNULL()`       |
| Text       | `TEXT()`, `LEFT()`, `RIGHT()`, `MID()`, `LEN()`, `CONTAINS()`, `BEGINS()` |
| Math       | `ABS()`, `CEILING()`, `FLOOR()`, `ROUND()`, `MAX()`, `MIN()`              |
| Date       | `TODAY()`, `NOW()`, `DATE()`, `YEAR()`, `MONTH()`, `DAY()`                |
| Comparison | `=`, `<>`, `<`, `>`, `<=`, `>=`                                           |

For the complete list of supported functions,
see [Formula Operators and Functions](https://help.salesforce.com/s/articleView?id=platform.customize_functions_parent.htm&language=en_US&type=5) in Salesforce Help.

**Global Variables:**

Formulas can also read the usual Salesforce [global variables](https://help.salesforce.com/s/articleView?language=en_US&id=sf.dev_understanding_global_variables.htm), which is how you make a rule depend on who is saving the record (for example, to skip it for a given permission):

| Variable        | Description            | Example                         |
|-----------------|------------------------|---------------------------------|
| `$User`         | Current user fields    | `$User.Id`, `$User.ProfileId`   |
| `$Profile`      | Current user's profile | `$Profile.Name`                 |
| `$Permission`   | Custom permissions     | `$Permission.Bypass_Validation` |
| `$Organization` | Org-level info         | `$Organization.Id`              |
| `$Label`        | Custom labels          | `$Label.MyCustomLabel`          |

### Accessing Context Properties

To read a value the context class exposes, name it directly in the formula. The record being saved is `newRecord`, its previous version is `oldRecord`, and any value you computed in the context class is referenced by its property name:

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

Salesforce's `ISCHANGED` function is not available here, but you can express the same idea by comparing `newRecord` against `oldRecord`. The patterns below cover the common cases (a field changed to a specific value, any change at all, and detecting a brand-new record). A picklist field works
only inside certain functions, so turn it into text with `TEXT()` before you compare it:

```text
// Field changed from any value to specific value (Status__c is a picklist, so it is turned into text)
TEXT(newRecord.Status__c) = 'Closed' && TEXT(oldRecord.Status__c) <> 'Closed'

// Any change to field
newRecord.OwnerId <> oldRecord.OwnerId

// Any change to a picklist field (turn it into text first)
TEXT(newRecord.Type) <> TEXT(oldRecord.Type)

// Insert detection (ISNEW equivalent)
ISBLANK(oldRecord.Id)
```

### Error Message Merge Fields

A good error message names the actual record or value at fault, not a generic "this is invalid". Drop a value into the message with the `{!PropertyName}` syntax, and the framework fills it in when the rule fails:

```text
Account {!newRecord.Name} requires at least one contact before converting to Customer status.
```

**Supported merge patterns:**

- `{!newRecord.FieldName}`: a field on the record being saved
- `{!oldRecord.FieldName}`: a field on the record's previous version
- `{!CustomProperty}`: a value your context class computed
- `{!$Label.MyLabel}`: a Custom Label, shown in the language of the user who saves the record (see
  [Multi-Language Support](#multi-language-support))

If you wrote the context class yourself, it needs `@JsonAccess(serializable='always')`, or the merge fields filled from it
come back blank (see [Creating Custom Context Classes](#creating-custom-context-classes)). Both fields and properties with
a getter are filled in.

---

## How do I connect it to a Flow?

The same rules you run from a trigger can run from a Flow, with no extra Apex. This keeps one set of rules in one
place, whether the save comes through a trigger or a screen. The framework ships:

- ready-made Flow actions to run validation, to turn it off, and to turn it back on;
- a screen component to show the results to the user.

### Validating Records in Flow

To run your rules inside a Flow, drop in the **Execute Validation Rules** invocable action ([`FLOW_ExecuteValidationRules`](reference/apex/FLOW_ExecuteValidationRules.md)). You hand it the records; it hands back whether they passed and the list of any errors:

**Input Variables:**
| Variable | Type | Required | Description |
|----------|------|----------|-------------|
| records | SObject Collection | Yes | Records to validate |
| oldRecords | SObject Collection | No | Old versions (for update context) |
| triggerContext | Text | No | Override context: `BEFORE_INSERT`, `BEFORE_UPDATE`, etc. |

Flow Builder offers the `triggerContext` values as a picklist in the action's property panel, so you pick a context rather than typing the raw value.

**Output Variables:**
| Variable | Type | Description |
|----------|------|-------------|
| hasErrors | Boolean | True if blocking errors exist |
| hasWarnings | Boolean | True if warnings exist |
| errorMessage | Text | Combined error message |
| errors | [`DTO_FlowValidationError`](reference/apex/DTO_FlowValidationError.md)[] | List of error details |
| warnings | [`DTO_FlowValidationError`](reference/apex/DTO_FlowValidationError.md)[] | List of warning details |

### Bypassing Validation in Flow

When a Flow needs to update records without tripping validation (a bulk fix, say), turn validation off first with the **Bypass Validation** invocable action ([`FLOW_BypassValidation`](reference/apex/FLOW_BypassValidation.md)), then turn it back on afterwards:

**Input Variables:**
| Variable | Type | Required | Description |
|----------|------|----------|-------------|
| bypassType | Text | No | `OBJECT_NAME` (default), `GROUP_NAME`, or `RULE_NAME` |
| name | Text | Yes | API name to bypass |

Flow Builder offers the `bypassType` values as a picklist in the action's property panel.

To turn validation back on, use the **Clear Validation Bypass** invocable action ([`FLOW_ClearValidationBypass`](reference/apex/FLOW_ClearValidationBypass.md)). Always pair a bypass with a clear, so validation does not stay off by accident:

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

To show a user what went wrong, add the `validationErrors` component to a Screen element and feed it the errors and warnings the validation action returned:

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

## How do I run it from Apex?

Sometimes you need to drive validation from Apex directly: turn rules off inside a batch job, or run the rules yourself and handle the results.

### Bypass Methods

These calls turn rules off and on from Apex. Use them to wrap a piece of code that should skip validation (a migration, say). Each one mirrors a level of the bypass hierarchy:

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

Turning off a safety check should never be silent. So every time you call `bypassObject`, `bypassGroup`, `bypassRule`, `clearBypass`, or `clearAllBypasses`, the framework records what happened. The benefit: an audit later can show exactly when validation was switched off, on what, and why.

Each call publishes a `LogEntryEvent__e` with category `BypassEvent`. The entry records:

- `surface = 'validation'`;
- the action (`BYPASS`, `CLEAR`, or `CLEAR_ALL`);
- the target with a scope prefix (`object:`, `group:`, or `rule:`);
- an optional reason you set with `kern.TRG_Base.setBypassReason(String)`, which applies to every bypass in the
  transaction.

Trigger bypasses, and query and save bypasses made through the builders, write to the same channel, so you query every recorded bypass the same way.

The package does not give you a log selector to call, so the log reads on this page go through a short selector of
your own, in its own class file:

- It is the selector the [Security Guide](Security%20-%20Guide.md#how-do-i-see-who-turned-a-check-off) shows, with
  two more fields (`Message__c` and `DurationMs__c`) for the timing read under
  [Enabling Performance Monitoring](#enabling-performance-monitoring).
- It leaves `systemModeRequired()` alone, so it reads in user mode while the `UserModeQueries_Enabled` flag is on, as
  it ships.
- The reads run with your own permissions: you need read access to log entries and, because log entries are private,
  the right to see every entry. The permission set Kern Log Console Read Only (`LogConsoleReadOnly`) grants both.

```apex
public with sharing class SEL_LogEntries extends SEL_Base
{
	public SEL_LogEntries()
	{
		super(LogEntry__c.SObjectType);
	}

	public override List<SObjectField> getFields()
	{
		return new List<SObjectField>{
			LogEntry__c.UserId__c,
			LogEntry__c.ShortMessage__c,
			LogEntry__c.ClassMethod__c,
			LogEntry__c.CreatedDate,
			LogEntry__c.ContextData__c,
			LogEntry__c.OccurrenceCount__c,
			LogEntry__c.LastModifiedDate,
			LogEntry__c.Message__c,
			LogEntry__c.DurationMs__c
		};
	}
}
```

Every recorded validation bypass, newest first:

```apex
List<LogEntry__c> validationBypasses = new SEL_LogEntries().query
	.condition(LogEntry__c.Fingerprint__c).startsWith('detail:bypass:')
	.andCondition(LogEntry__c.ShortMessage__c).endsWith('(validation)')
	.orderBy(LogEntry__c.CreatedDate).descending()
	.toList();
```

Each row is one distinct bypass:

- **The user** is in `UserId__c` (not `CreatedById`, which is always the Automated Process user).
- **The short message** reads like `BYPASS object:Account (validation)`.
- **The reason** is in `ContextData__c`.
- **A repeat** of the same bypass adds no new row.

The [Security Guide](Security%20-%20Guide.md#how-do-i-see-who-turned-a-check-off) shows how to read the daily counts of
repeats, and which settings turn these entries off. The log level is not one of them: the entries are saved at every
level, ERROR included.

The `BypassAudit_Enabled` `FeatureFlag__mdt` is a master off-switch you can flip without a deployment (a kill-switch), and it is on by default. If the volume of audit entries is too high in a particular environment, you can turn the recording off there with a `FeatureFlagStrategy__mdt` override.

### Direct Validation

When you want to run the rules yourself, rather than letting a trigger or Flow do it, call `validate()` with the records and the trigger context. It returns a result per record, so you decide what to do with the failures: log them, show them, or apply them back onto the records as save errors with `applyErrors()`:

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

## How do I test rules?

A rule you cannot test is a rule you cannot trust. The good news: you test these rules in plain Apex tests, without saving a record. You build a sample record in memory and assert that a named rule passes or fails on it, which is fast and keeps each test focused on one rule.

### Using UTIL_ValidationTestHelper

[`UTIL_ValidationTestHelper`](reference/apex/UTIL_ValidationTestHelper.md) gives you assertion methods that test a rule without the usual setup boilerplate:

> **How to test from your own org.** `UTIL_ValidationTestHelper` is the supported way to test validation rules from your tests. Drive every validation test through `UTIL_ValidationTestHelper.assertRuleFails` and `assertRulePasses`, or fall back to a full save inside `Test.startTest()` and `Test.stopTest()` when you need the real DML path.

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
	 * rejects a change to Type (`TEXT(newRecord.Type) <> TEXT(oldRecord.Type)`; Type is a picklist,
	 * so the formula turns it into text first) unless an approval flag is set.
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

| Method                                                     | Description                                     |
|------------------------------------------------------------|-------------------------------------------------|
| `assertRuleFails(record, ruleName)`                        | Assert a specific rule fails (insert context)   |
| `assertRuleFails(record, oldRecord, ruleName, operation)`  | Assert a specific rule fails (any context)      |
| `assertRulePasses(record, ruleName)`                       | Assert a specific rule passes (insert context)  |
| `assertRulePasses(record, oldRecord, ruleName, operation)` | Assert a specific rule passes (any context)     |
| `validate(record)`                                         | Get full ValidationResult for custom assertions |
| `validate(record, oldRecord, operation)`                   | Get full ValidationResult with context          |

### Testing Best Practices

1. **Test each rule individually:** use `assertRuleFails` and `assertRulePasses` so a failing test points at one rule
2. **Test both the pass and the fail:** confirm a valid record passes, not just that an invalid one fails
3. **Test the update path:** use old/new record pairs for rules that fire on update
4. **Test the bypass path:** confirm a rule is skipped when it is bypassed
5. **Use ValidationResult for richer checks:** read the error details, counts, and field names when a simple pass/fail is not enough

---

## What else can it do?

### Shadow Mode

Turning on a brand-new rule in production is risky: if it is too strict, it starts blocking real saves the moment it goes live. Shadow mode removes that risk. The rule runs watch-only: it logs what it would have blocked but does not actually block anything, so you can see the real-world impact before you enforce it.

To use it:

1. Set `ShadowMode__c = true` on the validation rule
2. When the rule fails:
    - The violation is logged to `LogEntry__c` as a `WARN`, with a `[SHADOW]` prefix on its `ShortMessage__c` field
    - The save is **not** blocked
    - The violation is captured so you can review it

**When this helps:**

- Trying a new rule before it starts enforcing
- Watching data quality without disrupting users
- Rolling a rule out gradually

#### Querying Shadow Violations

To find out what a shadow-mode rule would have blocked, read the `WARN` log entries carrying the `[SHADOW]` prefix,
through the `SEL_LogEntries` selector shown under [Bypass Audit Trail](#bypass-audit-trail):

```apex
List<LogEntry__c> shadowViolations = new SEL_LogEntries().query
	.condition(LogEntry__c.LogLevel__c).equals('WARN')
	.andCondition(LogEntry__c.ShortMessage__c).contains('[SHADOW]')
	.orderBy(LogEntry__c.CreatedDate).descending()
	.withLimit(100)
	.toList();
```

### Severity Levels

Not every data problem should stop a save. A rule's severity decides whether a failure blocks the user (Error) or just records a note for you to follow up on (Warning):

| Severity    | Behaviour                                                                                                             |
|-------------|-----------------------------------------------------------------------------------------------------------------------|
| **Error**   | Blocks save, adds error to record via `record.addError()`                                                             |
| **Warning** | Logs to LogEntry__c via [`LOG_Builder`](reference/apex/LOG_Builder.md)`.build().warn().emitAt()`, does not block save |

**Warning use cases:**

- Data quality monitoring
- Soft deprecation notices
- Informational alerts

### Multi-Language Support

The framework shows the text in `ErrorMessage__c` as you wrote it. The only parts it replaces are merge fields. A merge
field such as `{!ContactCount}` is filled from the context class. A merge field such as `{!$Label.MyLabel}` is filled
from your org's Custom Labels.

To show the same message in several languages, put a Custom Label in the message:

- Write `{!$Label.MyLabel}` in `ErrorMessage__c`. Each user sees the label in their own language.
- Write `{!$Label.ns__MyLabel}` for a label from a managed package with the namespace `ns`.
- A label needs no property on your context class.
- A label that does not exist stays in the message as written, so the mistake shows. One warning in the log names it for
  each transaction.
- Every other merge field is filled from the context class.

The framework does not apply
[Translation Workbench](https://help.salesforce.com/s/articleView?id=sf.workbench_overview.htm&language=en_US&type=5)
translations of the `ErrorMessage__c` field. Each rule record holds one message. If your users work in several
languages, use a Custom Label and translate the label. If your org uses one language, write the message in that language.

You can also add a property to your context class that returns a Custom Label (`System.Label.YourLabel`) and put
`{!YourProperty}` in `ErrorMessage__c`. As with every context class merge field, this works only when your context class
has `@JsonAccess(serializable='always')`. Without it, the property comes back blank.

---

## Anti-Patterns

These are the common mistakes (anti-patterns) people make with this framework, what goes wrong in each case, and what to do instead:

| Anti-Pattern                                               | Why It's Wrong                                                                                              | Instead                                                                                                                                                                |
|------------------------------------------------------------|-------------------------------------------------------------------------------------------------------------|------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| Using the framework for simple required-field checks       | Adds unnecessary overhead for validations that standard required fields or validation rules handle natively | Use standard validation rules for simple `ISBLANK()` checks; reserve the framework for cross-object or complex logic                                                   |
| Embedding complex formula logic in `RuleFormula__c` fields | Long formulas are hard to debug, maintain, and test                                                         | Use custom context classes to pre-compute values, then reference them with simple formulas                                                                             |
| Ignoring bulk context in custom context classes            | Queries inside `setContext()` run once per record, causing SOQL limit exceptions in bulk operations         | Implement `INT_BulkValidationContext` and query once for all records in `preLoad()`, which runs once per batch, then cache results                                     |
| Not providing bypass mechanisms for data loads             | Bulk data loads fail or run slowly due to unnecessary validation                                            | Use `FLOW_BypassValidation`, `BypassExecution__c`, or one of the `UTIL_ValidationRule.bypassObject()` / `.bypassGroup()` / `.bypassRule()` runtime APIs for migrations |
| Skipping shadow mode testing for new rules                 | Rules go live with unexpected failures or false positives                                                   | Enable `ShadowMode__c` on new rules first to log violations without blocking records                                                                                   |

---

## Best Practices

> **Performance Warning:** While this framework is bulkified, Apex-based formula evaluation consumes more CPU time than native validation rules. For massive data loads (e.g.,
> 10,000+ records via Data Loader), bypass the framework using `BypassExecution__c` or a Feature Flag to ensure stability.
> See [Bulk Data Load Considerations](#bulk-data-load-considerations) below.

1. **Use standard validation rules first:** reach for this framework only when a standard rule cannot do the job

2. **Implement bulk context:** always use [`INT_BulkValidationContext`](reference/apex/UTIL_ValidationRule.INT_BulkValidationContext.md) for cross-object queries

3. **Keep formulas simple:** compute complex logic in context class properties, then reference the result

4. **Use meaningful names:** make the DeveloperName say what the rule does

5. **Document rules:** always fill in the Description__c field

6. **Test with shadow mode:** run a new rule in shadow mode before you enforce it

7. **Order rules using `Order__c`:** give lightweight checks low values (10-50) and expensive cross-object queries high values (100+). With the Fail Fast strategy, that rejects bad data before the expensive work runs.

8. **Use appropriate severity:** reserve "Error" for issues that should block a save

9. **Use bypass hierarchy:** use an object or group bypass for bulk operations

10. **Monitor performance:** check LogEntry__c for slow validation rules

11. **Use UTIL_ValidationTestHelper:** lean on the test helper for clean, focused validation tests

### Demo rules you ship in your own package

If you ship a demo or sample validation rule inside your own managed package, set `BypassExecution__c = true`
on the `ValidationRule__mdt` record before you package it. The people who install your package then switch the
rule on themselves by clearing that flag in their configuration UI.

The reason to ship it off by default: an always-on sample rule would fire on every record insert, including in
unrelated tests in the installer's org, which is rarely what they want.

### Bulk Data Load Considerations

These rules run in Apex, which costs more processing time per record than a native Salesforce validation rule. For everyday saves that does not matter, but a large data load can run up against the platform's CPU limit. Use this guide to decide when to let the framework run and when to switch it off for the load:

| Volume                 | Recommendation                                            |
|------------------------|-----------------------------------------------------------|
| < 1,000 records        | Framework operates normally                               |
| 1,000 - 10,000 records | Monitor CPU time; consider Fail Fast strategy             |
| > 10,000 records       | Bypass framework via `BypassExecution__c` or Feature Flag |

#### Bypass Options for Bulk Loads

You have three ways to switch validation off for a load, depending on whether you control it through configuration or code:

1. **Metadata Bypass:** set `BypassExecution__c = true` on the ValidationRuleGroup before the load, then clear it after
2. **Feature Flag Bypass:** configure `BypassFeatureFlag__c` with a Feature Flag that targets your integration users
3. **Programmatic Bypass:** call `UTIL_ValidationRule.bypassObject('Account')` in your batch Apex before the save

**Why bypass at all?** These rules evaluate in Apex (`FormulaEval`), which uses more processing time than a native validation rule compiled into the database itself. For very large loads, a native validation rule or a post-load data-quality report is the better fit.

---

## Troubleshooting

### Common Issues

When a rule does not behave as expected, the cause is usually one of a handful of setup mismatches. Under each symptom, check the items in order:

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
- Check the class is `global`, or `public` with a Type Resolver set up (see [Type Resolution](Utilities%20-%20Guide.md#type-resolution-util_typeresolver))

**"SOQL limit exceeded"**

- Implement [`INT_BulkValidationContext`](reference/apex/UTIL_ValidationRule.INT_BulkValidationContext.md) for cross-object queries
- Move queries to `preLoad()` method
- Use aggregate queries where possible

### Enabling Performance Monitoring

To find out which validation is slowing a save down, the framework times how long each context class takes to do its work, and logs the ones that run long. This is on by default (the `EnableValidationPerformanceLogging__c` hierarchy setting). The timer covers a context class's whole job:

- the `preLoad()` step (bulk queries, loop processing, map building)
- every formula evaluation that uses that context

**Configuration via `LogSetting__c`:**

| Field                                   | Default | Description                                          |
|-----------------------------------------|---------|------------------------------------------------------|
| `EnableValidationPerformanceLogging__c` | `true`  | Enable/disable validation context timing             |
| `ValidationPerformanceThresholdMs__c`   | `100`   | Log context processing exceeding this threshold (ms) |

To tune or disable:

1. **Create or edit a `LogSetting__c` record** (a hierarchy custom setting you can set at org-default, profile, or user level)
2. **Set `EnableValidationPerformanceLogging__c = false`** to turn monitoring off, or leave the default `true` to keep it on
3. **Set `ValidationPerformanceThresholdMs__c`** to your threshold (e.g., 100 = log context processing >100ms)

Once enabled, each context class logs:

- Total elapsed time (preLoad + formula evaluations)
- Rule count and record count
- Nested within trigger action context for tracing

**Why time the context class, not each formula?** A single formula evaluation is sub-millisecond, so timing it tells you nothing useful. The real cost is in `preLoad()` (bulk queries, heavy loops). Timing the whole context class points straight at the culprit: if `VAL_AccountWithContactsContext` is slow, you know exactly which context class to optimise.

**Nested Tracing:** Validation performance logs appear nested within trigger action logs, providing drill-down visibility:

```text
TRG_ExecuteValidationRules (BEFORE_INSERT) completed in 450ms
  +-- VAL_AccountWithContactsContext validation completed in 380ms (Rules: 5, Records: 200)
```

To pull up the slowest validations, read the performance log entries (they are logged at the `DEBUG` level), ordered
by how long they took, through the `SEL_LogEntries` selector shown under [Bypass Audit Trail](#bypass-audit-trail):

```apex
List<LogEntry__c> validationLogs = new SEL_LogEntries().query
	.condition(LogEntry__c.LogLevel__c).equals('DEBUG')
	.andCondition(LogEntry__c.ClassMethod__c).contains('UTIL_ValidationRule/processRulesForContext')
	.orderBy(LogEntry__c.DurationMs__c).descending()
	.withLimit(50)
	.toList();
```

### Debugging Tips

To see exactly what a rule is doing, turn on logging, run a sample record through and read the errors, or test a formula on its own:

1. **Enable debug logging:**
   ```apex
   LOG_Builder.ignoreTestMode = true;
   ```

2. **Inspect validation results for a sample record:**
   ```apex
   // Runs in any org via the global test helper — drive a sample record
   // through the validation engine and inspect the resulting errors.
   Account sample = (Account)TST_Builder.of(Account.SObjectType)
   	.withOverrides(new Map<SObjectField, Object>{ Account.Name => 'Test', Account.Type => 'Enterprise' })
   	.withoutInsertion()
   	.build();
   UTIL_ValidationRule.ValidationResult result = UTIL_ValidationTestHelper.validate(sample);
   for (UTIL_ValidationRule.ValidationError error : result.errors)
   {
   	LOG_Builder.build().info('Validation error: ' + error.message).emitAt('UTIL_ValidationTestHelper');
   }
   ```

3. **Test formula in isolation:**
   ```apex
   UTIL_FormulaFilter filter = new UTIL_FormulaFilter(
   	'ValidationRule:Test',
   	'UTIL_FormulaContext.AccountContext',
   	'TEXT(newRecord.Type) = \'Enterprise\' && ISBLANK(TEXT(newRecord.Industry))'
   );
   UTIL_FormulaFilter.DTO_FilterResults results = filter.filter(
   	null, new List<Account>{ account }
   );
   Boolean formulaMatched = !results.newRecords.isEmpty();
   ```

---

## Related Documentation

- [Triggers - Guide](Triggers%20-%20Guide.md): the Trigger Action Framework and how `TRG_ExecuteValidationRules` plugs into it
- [Selectors - Guide](Selectors%20-%20Guide.md): the query patterns used in bulk validation context classes
- [Logging - Guide](Logging%20-%20Guide.md): shadow mode logging and validation performance monitoring
- [DML - Guide](DML%20-%20Guide.md): test data factories for validation test setup
- [Web Services - Guide](Web%20Services%20-%20Guide.md): API validation patterns using `getValidationErrors()`
