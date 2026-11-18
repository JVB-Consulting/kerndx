---
navOrder: 10
navLabel: "Triggers (when records change)"
searchTerms: {"issue-recursion-loop":["trigger runs twice"], "issue-governor-limits-exceeded":["Too many SOQL queries"]}
movedAnchors: {"why-choose-this-over-standard-salesforce-triggers": "/#triggers", "kerndx-vs-ootb-trigger-patterns-comparison": "/#triggers", "salesforce-out-of-the-box-approach": "/#triggers", "pros-cons-comparison": "/#triggers", "when-to-use-kerndx-trigger-action-framework": "/#triggers", "when-to-use-ootb-trigger-patterns": "/#triggers", "example-comparison": "/#triggers", "capability-matrix-for-analysts": "/#triggers"}
---

# Triggers - Guide

**Who this page is for:** developers who write the small classes that run when records change, the architects who design
their run order and separation of concerns, and the admins and business analysts who manage the settings without touching
Apex.

New to it? Try [Fast Start - Trigger Actions](Fast%20Start%20-%20Trigger%20Actions.md) first: a step-by-step
walkthrough that covers implementation, testing, and common pitfalls. Deciding whether to use KernDX? See
[Why KernDX](Strategic%20Guide%20-%20Overview.md).

## Copy this first

```apex
global inherited sharing class TRG_ValidateAccount extends kern.TRG_Base implements kern.IF_Trigger.BeforeInsert
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

**What this does:** before new accounts are saved, it refuses an account with a negative Annual Revenue, with the error
"Annual Revenue must be positive", and sets a blank Industry to Other. It runs once a `TriggerAction__mdt` record points
at it. The class is `global` so the framework can find it by name; a `public` class needs a Type Resolver (see
[Quick Start](#quick-start)).

**Read next:** [Turn the action on](#quick-start), [Every setting](#how-do-i-configure-this),
[Test an action](#testing-individual-actions), [Run a flow instead](#flow-as-a-trigger-action).

---

## Quick Navigation

| I need to...                                                            | Go to...                                                                                            |
|-------------------------------------------------------------------------|-----------------------------------------------------------------------------------------------------|
| Choose between a `global` and a `public` action class                   | [Quick Start](#quick-start)                                                                         |
| Look up every setting on the two configuration records                  | [How do I configure this?](#how-do-i-configure-this)                                                |
| Run a flow from a trigger                                               | [Flow as a Trigger Action](#flow-as-a-trigger-action)                                               |
| Understand which user's permissions a flow runs with                    | [Which user's permissions does the flow run with?](#which-users-permissions-does-the-flow-run-with) |
| Stop the save, or let it go through, when an action fails               | [Failure-action strategies](#failure-action-strategies)                                             |
| React to changes after they are saved (Change Data Capture)             | [Change Data Capture Actions](#change-data-capture-actions)                                         |
| Run logic at the end of each trigger pass, after its actions finish     | [Post-Trigger Actions](#post-trigger-actions)                                                       |
| Add an action to API Call, API Issue, Scheduled Job or a chain run      | [How do I add actions to KernDX's own objects?](#how-do-i-add-actions-to-kerndxs-own-objects)       |
| Share one query between several actions                                 | [Caching with Trigger Actions](#caching-with-trigger-actions)                                       |
| Design how several actions work together                                | [How do I link actions together?](#how-do-i-link-actions-together)                                  |
| Stop an action from setting itself off again                            | [Recursion Prevention](#recursion-prevention)                                                       |
| Turn an action or a whole object off without a deployment               | [Bypass Mechanisms](#bypass-mechanisms)                                                             |
| See who bypassed a trigger from Apex or a flow, and why                 | [Bypass Audit Trail](#bypass-audit-trail)                                                           |
| Roll an action out to some users, or switch it off, with a feature flag | [Feature Flag Integration](#feature-flag-integration)                                               |
| Run an action only for some records                                     | [Entry Criteria Formulas](#entry-criteria-formulas)                                                 |
| Test trigger actions                                                    | [Testing](#testing)                                                                                 |
| Find the slow actions                                                   | [Performance Logging](#performance-logging)                                                         |
| Find out why an action is not running                                   | [Issue: Action Not Executing](#issue-action-not-executing)                                          |
| Fix wrong order, recursion, limit or type errors                        | [Troubleshooting](#troubleshooting)                                                                 |
| Move from the Trigger Actions Framework (TAF)                           | [Migrating from TAF to KernDX](#migrating-from-taf-to-kerndx)                                       |
| Move your own trigger handler class into trigger actions                | [Moving your own handler](#moving-your-own-trigger-handler-into-trigger-actions)                    |
| Understand how the framework runs your actions                          | [How does it work?](#how-does-it-work)                                                              |
| Understand the classes and records involved                             | [What are the moving parts?](#what-are-the-moving-parts)                                            |
| See why KernDX is worth using                                           | [Why KernDX: the triggers example](/#triggers)                                                      |

---

## Quick Start

Pick the shape that fits your logic:

| Your logic | What to write |
|---|---|
| Apex | A trigger action: a small class that extends `TRG_Base` and implements one `IF_Trigger` context interface (one interface per trigger event, such as before-insert). The framework runs it for you based on a configuration record. The sample below, or the one under [Copy this first](#copy-this-first) |
| A flow an admin builds | An auto-launched flow, named in the `FlowName__c` field of its configuration record, with no Apex: [Flow as a Trigger Action](#flow-as-a-trigger-action) |

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

> **Namespaces in code samples:** `kern.` on a class and `kern__` on an object, field, or metadata type mark the managed package's namespace.
> On the managed package, framework references need those prefixes even where a sample omits them; repackaged under your own namespace, replace `kern`/`kern__`
> with your prefix; on an unmanaged deploy, drop them. See [How to read the code samples](Installation.md#how-to-read-the-code-samples).

> **`global` or `public`?** The framework runs your action class by its name, so it must see the class: declare it
> `global`, or keep it `public` and set up a Type Resolver (it tells the framework where to find your own classes).
> This guide's samples use `public` to stay short. See
> [Type Resolution](Utilities%20-%20Guide.md#type-resolution-util_typeresolver).

**To run it:** give the object its one-line trigger file (`new TRG_Dispatcher().run();`), one `TriggerSetting__mdt`
record, and one `TriggerAction__mdt` record that names the class, the trigger event and the run order
([Fast Start - Trigger Actions](Fast%20Start%20-%20Trigger%20Actions.md#step-2-create-the-physical-trigger), steps 2
and 3; every field is under [How do I configure this?](#how-do-i-configure-this)).

---

## What problem does this solve?

Salesforce gives you triggers but no structure for organising what they do. Most orgs end up with one large trigger file per object that nobody wants to touch, because every change risks breaking unrelated logic buried in the same file.

This framework breaks that logic into small, single-purpose classes called trigger actions. Configuration records, not code, then decide the run order, turn each action on or off, and add conditions. Each piece of logic is testable on its own, safe to reorder, and can be switched off in production without a deployment.

Use it for every object whose records run Apex when they change. KernDX expects that logic to live in trigger actions, because that is how it gets the run order, the off-switches, recursion control and performance logging described below.

## Mental model

Think of the framework as a playlist. Each trigger action is a song, the configuration records decide the running order, and the dispatcher presses play. You can reorder the songs, or skip one, without rewriting the music: change a configuration record, and the same small action classes run in a new order or sit out entirely.

## Use this when

- An object's records run Apex when they change: the logic is split into pieces you can reorder, disable, or test on their own.
- More than one developer works on the same object's triggers and you want them to stop colliding in one file.
- You need to turn a piece of trigger logic off in production (a data load, a migration, an incident) without shipping code.
- The same validation or defaulting logic should run on more than one object.
- You want to gate or roll out trigger logic to a chosen group of users without a deployment.

## Don't use this when

KernDX is opinionated here: Apex that runs when records change goes into trigger actions. Only two things stay outside them.

- The change needs no Apex at all: a formula field or a record-triggered Flow already handles it declaratively. Use that; it is less to maintain.
- It is a one-time data fix or migration script that runs outside normal transaction flow. That is a script, not trigger logic.

---

## How do I configure this?

### TriggerSetting__mdt Field Reference

Each field below is tagged with who can change it: **(Subscriber Controlled)** means you can edit the value in your own org, and **(Developer Controlled)** means the framework sets it and your org cannot change it.

#### SObjectType__c (Required)

**Purpose:** Identifies which SObject this setting applies to via
a MetadataRelationship (a custom metadata relationship field) to `EntityDefinition`.

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

**Type:** MetadataRelationship, a lookup to a `FeatureFlag__mdt` record (e.g., `Bypass_Account_Triggers`). Selected via dropdown picker in the CMDT UI.

**When to Use:**

- Emergency kill switches for trigger logic (a master off-switch you can flip in an incident without a deployment)
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

**Type:** MetadataRelationship, a lookup to a `FeatureFlag__mdt` record (e.g., `Enable_Account_Validation`). Selected via dropdown picker in the CMDT UI.

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

#### EnablePerformanceLogging__c (Deprecated)

**Deprecated.** This checkbox has no effect: the framework does not read it. Its label is now **Enable Performance
Logging (Deprecated)**, and it is no longer on the page layout of a new install.

**Use instead:** `PerformanceThresholdMs__c` on the same trigger setting, described next.

#### PerformanceThresholdMs__c (Subscriber Controlled)

**Purpose:** Controls slow-action logging for the trigger actions and post-trigger actions registered under this
trigger setting. "Slow-action logging" means a log entry for each run of an action that takes a set time or longer.

**Default:** blank.

| Value              | What happens to the actions under this trigger setting                                                                           |
|--------------------|----------------------------------------------------------------------------------------------------------------------------------|
| Blank              | They follow Log Setting (`LogSetting__c.EnableTriggerPerformanceLogging__c` and `TriggerPerformanceThresholdMs__c`).             |
| A number           | A run that takes that many milliseconds or longer is logged, even when Enable Trigger Performance Logging in Log Setting is off. |
| `0`                | Every run is logged.                                                                                                             |
| A very high number | Those actions effectively never log.                                                                                             |

**Example:**

```text
Performance Threshold Ms: 200
```

**Effect:** An action's own threshold, Force Performance Logging and Suppress Performance Logging win over this value.
It applies only to the actions registered under this trigger setting, not to other trigger settings for the same object.

> **See Also:** [Performance Logging](#performance-logging) for detailed configuration and usage.

#### ApplyMasking__c (Subscriber Controlled)

**Purpose:** Runs the [data masking](Security%20-%20Guide.md#data-masking) pass on this object before any trigger actions execute, so configured sensitive
fields are redacted on save.

**Default:** `true`. Every object with a Trigger Setting is masked automatically. Uncheck it to opt one object out.

**When an object has more than one trigger setting** (for example, your own setting on one of
[KernDX's own objects](#how-do-i-add-actions-to-kerndxs-own-objects)):

- Masking is on for the object when **any** of its trigger settings has Apply Masking ticked.
- A setting's Required Feature Flag and Bypass Feature Flag switch that setting's actions on and off. They never change
  masking.
- A setting with Bypass Execution ticked is left out entirely, so its Apply Masking does not count.

There are three ways to switch masking off:

| To switch masking off for | Do this |
|---|---|
| One object | Untick Apply Masking on every trigger setting for that object |
| One setting, with all its actions | Tick Bypass Execution on that setting. The setting is left out entirely, so masking stays on only if another setting for the object has Apply Masking ticked |
| Every object in your org | Turn off the `MaskingFramework_Enabled` feature flag (Masking Framework Enabled) |

**How it runs:**

- **When:** on every **before-insert** and **before-update**, the dispatcher masks the records *before* the first trigger action fires, so
  downstream actions, and the database, only ever see the masked values.
- **Only when switched on:** the pass runs only when the `MaskingFramework_Enabled` feature flag is on.
- **Only wired-up fields:** it never touches a field you have not wired up with a `MaskingTarget__mdt` record. That record is a precondition
  rather than a promise: a target naming one field redacts it, but a wildcard target covering a whole object deliberately steps over unique
  keys and external IDs, because rewriting those would break record identity.
- **No extra DML:** it runs in the `before` phase and writes onto the record in memory.

**When to Use:**

- Leave it checked for objects that hold sensitive text (the default).
- Uncheck it for objects with no sensitive data to skip the masking pass for a small performance saving.

**Example:**

```text
Apply Masking: true
```

**Effect:** Sensitive values matching your masking rules are redacted on this object before any trigger action (Apex or flow) sees them, and before the record
is committed.

> **See Also:** [Data Masking](Security%20-%20Guide.md#data-masking) in the Security Guide for rule and target configuration, the honest caveats (masking is
> destructive, text-only, and not retroactive), and the Data Masking Advisor.

### TriggerAction__mdt Field Reference

#### ApexClassName__c

**Purpose:** Fully qualified name of the trigger action class. Set this for Apex actions; leave blank for flow-based actions (set `FlowName__c` instead).

**Format:**

- Unmanaged: `TRG_SetExternalReference`
- Managed: `namespace.TRG_SetExternalReference`

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
- Actions that share the same Order__c run in a stable, predictable sequence, ordered by their developer name, so the order stays the same across deployments
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

#### AllowRecursion__c (Subscriber Controlled)

**Purpose:** Controls whether action can execute recursively.

**Default:** `true`

**When true:**

- Action can run again even while an earlier run of it is still in progress
- Use when action doesn't cause DML on same object

**When false:**

- The framework skips the action while an earlier run of it is still in progress (a re-fire set off by its own DML, directly or through a chain of other triggers)
- The action still runs for separate, later operations in the same transaction
- Prevents infinite loops
- Use when action might trigger itself

**Example:**

```text
Allow Recursion: false
```

#### AllowNonSelfInitiated__c (Subscriber Controlled)

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

#### Entry Criteria Fields (Subscriber Controlled)

**EntryCriteriaFormula__c**

**Purpose:** Formula evaluated per record for conditional execution.

**Format:** Formula expression using context class properties

**How It Works:**

1. Framework instantiates context class
2. Sets newRecord/oldRecord properties
3. Evaluates formula using FormulaEval
4. Only records where formula = true are passed to action

If your context class also implements `kern.UTIL_ValidationRule.INT_BulkValidationContext`, its `preLoad()` method runs before the formula
is checked, as it does for validation rules:

- **How often:** once for each trigger action that uses it, on each batch of records.
- **Query limit:** each of those runs counts its queries towards the save's query limit (100 queries in a normal save), so check what yours
  queries.
- **Errors:** if `preLoad()` throws an error, the save stops with that error, whatever the action's `FailureAction__c` says, as it does when
  the formula itself is wrong.

**Example:**

```text
Entry Criteria Formula: isPremiumTier && statusChanged
```

**EntryCriteriaContextClassName__c**

**Purpose:** Apex class providing properties for formula evaluation.

**Format:** Fully qualified class name (blank for the objects with pre-built contexts listed below)

**Auto-detection for Supported Objects:**

For the following objects, you can leave this field **blank** - the framework automatically uses pre-built context classes from `UTIL_FormulaContext`:

- Account, Campaign, Case, Contact, Event, Foobar__c, Lead, Opportunity, Task, User
- API Call (`ApiCall__c`, through `UTIL_FormulaContext.ApiCallContext`) and API Issue (`ApiIssue__c`, through
  `UTIL_FormulaContext.ApiIssueContext`)

Every other object, standard or custom, needs a context class name: a row with a formula and a blank context class name is refused
when you save or deploy it.

These pre-built contexts provide `oldRecord` and `newRecord` typed to the specific SObject, supporting formulas like:

```text
TEXT(newRecord.Industry) <> TEXT(oldRecord.Industry)
```

Industry is a picklist field. A formula cannot compare a picklist with `=` or `<>`, so turn it into text with `TEXT()`
first. On API Call and API Issue, write `TEXT(newRecord.Status__c) = "Failed"`, for example.

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
Context Class Name: UTIL_AccountContext
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

Sometimes the logic you want to add is easier to build in Flow than in Apex. You can run an auto-launched Flow as a trigger action and have it behave exactly like an Apex action, with the same run order, bypass, recursion control, performance monitoring, audit logging, and feature-flag gating.

To register a flow, deploy a `TriggerAction__mdt` row with `FlowName__c` populated and
`ApexClassName__c` left blank. The framework then dispatches to its built-in flow runner: it
constructs the flow interview, supplies the trigger record, runs the flow, and copies the
populated fields back onto the trigger record. You write no Apex to wire it up.

**For a copy-paste quick start** see the [Fast Start - Trigger Actions](Fast%20Start%20-%20Trigger%20Actions.md#using-flow-as-a-trigger-action)
walkthrough.

### Which user's permissions does the flow run with?

**Short answer:** with the trigger's system context, unless the flow is saved with User Context–Enforces User
Permissions (API version 68.0 or later). That is the platform's rule for any flow started from Apex or another
automation, not something the framework adds.

| Choose | Whose access the flow runs with | When the flow |
|---|---|---|
| User Context–Enforces User Permissions (in Flow Builder, for flows on API version 68.0 or later, available for screen flows and autolaunched flows) | Always the running user's access level, whatever launched it, a trigger action included. | Must never do more than the user could do on screen, for example when it touches records the user is not meant to reach through automation. |
| The default | The trigger's: a trigger runs in system context, and a flow the framework launches from a trigger action inherits it, so the flow can read and change records that the user who saved the record could not. | Has to act beyond what the user can do directly, such as updating a related record the user cannot edit. |

Without User Context–Enforces User Permissions, the system context holds even for a flow you have configured to run in
user context, because that setting leaves the flow running in user or system context depending on how it is launched.

To set the stricter option, open the flow in Flow Builder, click Save, click Show Advanced, and under How to Run the
Flow choose User Context–Enforces User Permissions.

The framework's part is the same either way: it still builds the interview, supplies the trigger record and copies
the populated fields back, inside the trigger. The
[Security guide](Security%20-%20Guide.md#flow-input-variable-hygiene) covers the portal side of the same question.

### TriggerAction__mdt fields used by flow actions

| Field              | Type      | Required                          | Default          | Allowed values                          | Purpose                                                                                                                                                                                                                                                                                                                           |
|--------------------|-----------|-----------------------------------|------------------|-----------------------------------------|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `FlowName__c`      | Text(80)  | Yes (XOR with `ApexClassName__c`) | —                | Bare flow API name, no namespace prefix | Flow API name bound to this action. The framework resolves the namespace internally. Validated at deploy by the `npm run scan:flow-references` CI scanner rule (existence + active state + variable contract).                                                                                                                    |
| `ApexClassName__c` | Text(100) | Leave blank for flow actions      | —                | —                                       | Leave this field blank when configuring a flow action. The `MutuallyExclusiveTarget` validation rule rejects rows with both fields populated.                                                                                                                                                                                     |
| `FailureAction__c` | Picklist  | No (defaulted)                    | `LogAndContinue` | `LogAndContinue`, `BlockDml`            | How the framework handles uncaught flow errors. `LogAndContinue` (default) emits a `LogEntryEvent__e` and lets DML proceed; `BlockDml` calls `record.addError(...)` to stop the save and surface the flow error to the user. See [Failure-action strategies](#failure-action-strategies); the field applies to Apex actions too. |

### Variable contract on the registered flow

The framework owns the flow's input/output variable map. Every flow registered as a trigger action declares
one or two variables, exactly as listed below:

| Variable      | Type                                | Direction          | Required for                      |
|---------------|-------------------------------------|--------------------|-----------------------------------|
| `record`      | The trigger object (e.g. `Account`) | **Input + Output** | All 7 contexts                    |
| `recordPrior` | The trigger object (e.g. `Account`) | **Input only**     | Before Update / After Update only |

The variable type must match the dispatching `TriggerSetting__mdt.SObjectType__c` exactly. A flow whose `record`
variable is typed `Contact` cannot be registered against an `Account` trigger setting, because a type mismatch
cannot be recovered from at runtime.

The deploy-time CI scanner rule (`npm run scan:flow-references`) catches this before merge: it reads the active flow's
`Metadata.variables` via Tooling API and compares the `objectType` to the dispatching trigger setting.

### LogSetting__c volume gate

| Field                                      | Type     | Default      | Allowed values                  | Purpose                                                                                                                                                                                                                                                                                                                                                                                    |
|--------------------------------------------|----------|--------------|---------------------------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `LogSetting__c.EnableFlowActionLogging__c` | Text(40) | `ErrorsOnly` | `Off`, `ErrorsOnly`, `AlwaysOn` | Controls how often the framework writes flow-action audit log entries. What each value logs, and when to use it: see [Audit volume control](#audit-volume-control). |

The volume gate is layered per-user in the same way as the existing `LogSetting__c.LogLevelThreshold__c` field:
each user can have their own `LogSetting__c` record overriding the org-default. Performance logging is
controlled separately, by the thresholds described in [Performance Logging](#performance-logging).

### Mock harness

In tests you do not want to run a real flow. `TST_InvokeFlowMock.forFlow(name)...register()` short-circuits `Flow.Interview` at test time. See
[Fast Start - Trigger Actions: Testing Flow Actions with TST_InvokeFlowMock](Fast%20Start%20-%20Trigger%20Actions.md#testing-flow-actions-with-tst_invokeflowmock) for the helper
reference and the worked example.

### When to use a flow action vs a record-triggered flow

Choose a flow action when the flow must **interleave** with Apex trigger actions (ordering, shared recursion blocking,
shared bypass, shared audit), and a record-triggered flow when it runs **alongside** them as an independent unit. Both options run a flow in response to a DML event but sit in different layers of the platform.

| Use case                                                                                         | Recommendation                                                                                                                                               |
|--------------------------------------------------------------------------------------------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------|
| Mixed Apex + Flow logic that needs to run under one bypass / recursion / audit / perf umbrella   | Flow action (`FlowName__c` populated)                                                                                                                        |
| Pure-Flow logic with no need for ordered interleaving with Apex                                  | Native record-triggered flow                                                                                                                                 |
| Validation flows that must respect existing `UTIL_ValidationRule` bypass / group-of-rules wiring | Flow action with `FailureAction__c = 'BlockDml'`                                                                                                             |
| Async / scheduled-path Flow logic                                                                | Native record-triggered flow (a flow action runs synchronously inside the trigger)                                                                           |
| Flow needs to abort the save with a custom message                                               | Flow action with `FailureAction__c = 'BlockDml'` (the framework copies the flow's error to `record.addError(...)` with the flow name and record id appended) |
| Flow only updates the same record's fields and runs once per save                                | Either one: a flow action if other Apex actions are already configured on the object; a native record-triggered flow otherwise                               |

### Failure-action strategies

`FailureAction__c` decides whether the user's save still goes through, or is stopped, when an action throws an error.
It is set per row, and it applies to **every** trigger action (Apex and flow alike). The dispatcher wraps each action
invocation in a try/catch and routes any uncaught `Exception` through the configured policy.

| Strategy                   | Behaviour on action error                                                                                                                                      | Recommended for                                                                                                                                                                 |
|----------------------------|----------------------------------------------------------------------------------------------------------------------------------------------------------------|---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `LogAndContinue` (default) | Emits a `LogEntryEvent__e` via `LOG_Builder` with `LogLevel__c = ERROR`, the action identity, the record id, and the original error message. **DML proceeds.** | Orchestration, derived-field population, notifications, supplemental logging: anything where a single action's failure should be visible but should not block the user's save. |
| `BlockDml`                 | Apex action: logs the error, then throws it again, so the whole DML rolls back. Flow action: calls `record.addError(formattedMessage)` on the record whose flow failed. Either way the error reaches the user. | Validation actions where the trigger should reject records that fail the action's checks.                                                                                       |

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

### Bulk behaviour and governor limits

The framework starts one flow interview per record, synchronously, inside the trigger. That sounds expensive for a
200-record data load, but Salesforce batches flow element execution across the interviews in a transaction:

- When the same flow runs for many records, a Get Records element issues one query in total, not one per record.
- The same batching applies to Create and Update elements.
- Measured against the shipped package installed in an org, query and DML statement counts stayed constant whether a
  save carried 1, 10, or 100 records.

Three practical rules follow:

- **Keep queries and DML out of Loop elements.** The batching applies across interviews, not across the iterations of
  a Loop inside your flow. A Get Records or Update Records element inside a Loop body runs once per iteration, exactly
  as it would in a native record-triggered flow. Work on the whole collection outside the loop instead.
- **Watch CPU time, not statement counts.** Each interview adds a few milliseconds of CPU per record per flow action,
  so one flow action on a 200-record save spends well under a second of the 10-second CPU allowance. The cost only
  becomes interesting when several flow actions stack on one high-volume object.
- **Find and move the slow ones.** Set `PerformanceThresholdMs__c` on the row so slow runs surface in the performance
  log, and move genuinely heavy logic to an Apex action on the same registration row.

Failure isolation stays per record in bulk: a record whose interview throws is logged (or blocked) on its own via
`FailureAction__c`, and the other records in the save carry on.

### Cross-namespace flow resolution

`FlowName__c` accepts a **bare flow API name**, never a namespace-qualified name. The framework works out the
namespace itself and calls the namespace-aware form `Flow.Interview.createInterview(namespace, flowName, variables)`,
which returns the active flow whether it lives in the kern namespace or in your own namespace.

- A `FlowName__c` value of `Account_SetDefaults` resolves to the flow in your own namespace when the dispatching CMDT
  row is in your package, and to the kern-namespace flow when the row is in the kern package. Both work
  from the same field shape.
- Authors should not prefix `FlowName__c` with `kern.` or any other namespace. A namespace prefix in this field
  produces a deploy-time scanner error and a runtime configuration error.

### Recommended-default pattern matrix

When you ship a flow-action row, default these fields based on the flow's purpose:

| Flow purpose                                                              | `FailureAction__c` | `AllowRecursion__c` | Notes                                                                    |
|---------------------------------------------------------------------------|--------------------|---------------------|--------------------------------------------------------------------------|
| Orchestration (set defaults, populate derived fields, send notifications) | `LogAndContinue`   | `true`              | Default shape: production-resilient, audit-visible.                      |
| Validation (reject records that fail business rules)                      | `BlockDml`         | `true`              | Surfaces the flow's error to the user.                                   |
| Cascading update (writes to related records)                              | `LogAndContinue`   | `false`             | Block recursion on the originating object to avoid unintended self-fire. |

### Audit volume control

Every flow-action invocation can emit a `LogEntryEvent__e` audit entry. You control how much it logs with
`LogSetting__c.EnableFlowActionLogging__c`, a 3-state field set for the org or layered per-user (see
[LogSetting__c volume gate](#logsetting__c-volume-gate)):

| Value                  | Success path                                                                                                           | Error path                                                                 | When to use                                                                                                                       |
|------------------------|------------------------------------------------------------------------------------------------------------------------|----------------------------------------------------------------------------|-----------------------------------------------------------------------------------------------------------------------------------|
| `Off`                  | No emission                                                                                                            | No emission                                                                | Integration-only orgs where audit volume is excessive and external observability (seeing what your code actually did in production, a searchable, kept record) already covers the path. |
| `ErrorsOnly` (default) | No emission                                                                                                            | One entry per failed record (with `RecordId__c` set, queryable per-record) | Production default: bounded volume, with a kept record of every failure.                                                          |
| `AlwaysOn`             | One per-batch summary entry per dispatch (record ids serialised into `ContextData__c.recordIds`, `RecordId__c = null`) | One entry per failed record                                                | High-regulation orgs where every flow trigger run must be evidenced. Heavy DML multiplies entry volume, so measure before flipping. |

Performance logging is separate from audit logging and is sparse by default. It emits when a run takes as long as the
threshold that applies to the action, or longer, or when Force Performance Logging is ticked (see
[Performance Logging](#performance-logging)).

The two log streams can be queried independently, and the perf log entry includes `flowName` as a context dimension so
you can filter perf logs by flow.

### Bypass and rollback

Two options, in priority order from most-surgical to most-broad:

1. **Per-row declarative bypass (recommended for surgical disable).** Set `BypassExecution__c = true` on the specific
   `TriggerAction__mdt` row. One-row CMDT deploy disables this flow action and only this flow action.
2. **Per-row feature-flag bypass (recommended for staged rollout).** Set the row's `RequiredFeatureFlag__c` to a
   `FeatureFlag__mdt` record and flip its `IsEnabledByDefault__c` to `false`. This is useful when several flow actions need
   to be gated together: point them all at the same feature flag and flip the flag once.

Per-flow surgical bypass via Apex (e.g. `bypassFlow('Account_SetDefaults')`) is not provided. To disable a specific
flow action, use option 1 or option 2 above.

### Migrating from TAF to KernDX

If you run flows through the Trigger Actions Framework (TAF), the flows themselves move to KernDX unchanged. Both
frameworks start a flow once per record and follow the same authoring contract: the auto-launched flow declares a
`record` variable matching the trigger object.

The work is in the metadata. Each TAF flow row on `Trigger_Action__mdt` becomes a new KernDX `TriggerAction__mdt`
record, with its parent `TriggerSetting__mdt` record, its event and its run order. The object's one-line trigger file
calls `TRG_Dispatcher` (`new kern.TRG_Dispatcher().run();`).

Three things behave differently, so set them on each record:

| What happens                          | In TAF                                                                                                                    | The KernDX setting that matches                                                                                                                                                                                         |
|---------------------------------------|---------------------------------------------------------------------------------------------------------------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| A flow fails                          | The save is blocked: the error is added to the record.                                                                    | `FailureAction__c = BlockDml` gives the same result. The default, `LogAndContinue`, logs the error and lets the save through.                                                                                          |
| A record comes back through the trigger | On update, a flow action skips a record it has already seen in the same transaction, unless `Allow_Flow_Recursion__c` is set. | `AllowRecursion__c = false` is the nearest setting, not an identical one: KernDX skips the action only while an earlier run of it is still in progress, and runs it again for a later, separate save. The default is `true`. |
| Where the row belongs                 | A `Trigger_Action__mdt` row, linked to an `sObject_Trigger_Setting__mdt` record through the field for its event, such as `Before_Update__c`. | A `TriggerAction__mdt` record with `TriggerSetting__c` (the parent `TriggerSetting__mdt` record), `Event__c` and `Order__c`.                                                                                            |

```xml
<!-- BEFORE (TAF) -->
<values><field>Apex_Class_Name__c</field><value xsi:type="xsd:string">TriggerActionFlow</value></values>
<values><field>Flow_Name__c</field><value xsi:type="xsd:string">Account_SetDefaults</value></values>

<!-- AFTER (KernDX) -->
<values><field>kern__TriggerSetting__c</field><value xsi:type="xsd:string">Account</value></values>
<values><field>kern__Event__c</field><value xsi:type="xsd:string">Before Update</value></values>
<values><field>kern__Order__c</field><value xsi:type="xsd:double">100.0</value></values>
<values><field>kern__FlowName__c</field><value xsi:type="xsd:string">Account_SetDefaults</value></values>
<values><field>kern__FailureAction__c</field><value xsi:type="xsd:string">BlockDml</value></values>
<values><field>kern__AllowRecursion__c</field><value xsi:type="xsd:boolean">false</value></values>
```

Note that `kern__ApexClassName__c` is **omitted** from KernDX flow rows: the
framework dispatches via its built-in flow runner whenever `FlowName__c` is populated and `ApexClassName__c` is
blank. Setting both fields fails the `MutuallyExclusiveTarget` validation rule.

`FailureAction__c` defaults to `LogAndContinue` if left blank. Set it explicitly on every record so future
readers don't have to look up framework defaults to know how the row will behave.

### Moving your own trigger handler into trigger actions

Many orgs already have a trigger handler of their own: one trigger per object that calls one class, and the class checks
`Trigger.isInsert` or `Trigger.isUpdate` to pick the code to run. You can move (migrate) that class into trigger actions with
very few changes to the code inside it. What changes is how an error is handled, so read step 2 before you deploy.

**1. One `TriggerAction__mdt` row for each event.** `Event__c` holds one event, such as Before Insert. A handler that
handles three events needs three rows. One class can implement several `IF_Trigger` interfaces, so all the rows can
name the same class. See [`Event__c`](#event__c-required).

**2. Choose the Failure Action on each row.** This is where most teams trip.

- A blank Failure Action means Log and Continue. If the action throws an exception, the framework logs it and the save
  goes on. This starts the moment your handler runs as a trigger action, even with its code unchanged: an exception
  that used to stop the save no longer stops it.
- `addError` still fails the record, whatever the Failure Action says.
- Choose Block DML when the old code relied on an exception to stop the save. Block DML throws the error again, so the
  whole save rolls back, as it did before.
- A governor-limit error, such as too many queries, always stops the save.

See [Failure-action strategies](#failure-action-strategies).

**3. Move `if` conditions into entry formulas, if you want to.** An entry formula (`EntryCriteriaFormula__c`) makes the
action run only for the records the formula is true for.

- On Account, Campaign, Case, Contact, Event, Lead, Opportunity, Task and User, and on some KernDX objects, built-in
  contexts give the formula `oldRecord` and `newRecord`. Leave `EntryCriteriaContextClassName__c` blank.
- On every other object, write a context class and name it in `EntryCriteriaContextClassName__c`.
- A row with a formula and no context class, on an object without a built-in context, is refused when you save or
  deploy it.

See [Entry Criteria Fields](#entry-criteria-fields-subscriber-controlled).

**4. Expect slow actions in the log.** Performance logging is on by default: an action that runs for 500 ms or longer
gets a log entry. A large handler moved into one action may show up there. That tells you what to split or speed up.
To change the limit for one action, stop logging one action, or change it for the whole org, see
[Performance Logging](#performance-logging).

**Before:** the trigger calls your own handler, and an exception stops the save.

```apex
trigger AccountTrigger on Account (before insert, before update)
{
	new AccountTriggerHandler().run();
}

public with sharing class AccountTriggerHandler
{
	public void run()
	{
		for(Account account : (List<Account>)Trigger.new)
		{
			if(String.isBlank(account.Industry))
			{
				account.Industry = 'Other';
			}
			if(Trigger.isUpdate && account.AnnualRevenue != null && account.AnnualRevenue < 0)
			{
				throw new IllegalArgumentException('Annual Revenue must be positive');
			}
		}
	}
}
```

**After:** the trigger hands control to the framework, and one action class implements both events.

```apex
trigger AccountTrigger on Account (before insert, before update)
{
	new kern.TRG_Dispatcher().run();
}

public inherited sharing class TRG_AccountRules extends kern.TRG_Base implements kern.IF_Trigger.BeforeInsert, kern.IF_Trigger.BeforeUpdate
{
	public void beforeInsert(List<SObject> newRecords)
	{
		setDefaults((List<Account>)newRecords);
	}

	public void beforeUpdate(List<SObject> newRecords, List<SObject> oldRecords)
	{
		setDefaults((List<Account>)newRecords);
		for(Account account : (List<Account>)newRecords)
		{
			if(account.AnnualRevenue != null && account.AnnualRevenue < 0)
			{
				throw new IllegalArgumentException('Annual Revenue must be positive');
			}
		}
	}

	private void setDefaults(List<Account> accounts)
	{
		for(Account account : accounts)
		{
			if(String.isBlank(account.Industry))
			{
				account.Industry = 'Other';
			}
		}
	}
}
```

Then add one `kern__TriggerSetting__mdt` record for Account, and two `kern__TriggerAction__mdt` records that point at it:

| Row                          | `Event__c`    | `ApexClassName__c` | `Order__c` | `FailureAction__c`                                        |
|------------------------------|---------------|--------------------|------------|-----------------------------------------------------------|
| Account rules, before insert | Before Insert | `TRG_AccountRules` | 10         | `LogAndContinue` (Log and Continue)                       |
| Account rules, before update | Before Update | `TRG_AccountRules` | 10         | `BlockDml` (Block DML), because the exception must still stop the save |

The before-update row needs Block DML only because the code throws an exception. If you change the `throw` to
`account.AnnualRevenue.addError(...)`, the record fails whatever the Failure Action says. Each row also needs a
`Description__c`.

The class is `public` to keep the sample short. The framework finds it by name, so declare it `global` or set up a Type
Resolver, as [Quick Start](#quick-start) explains.

---

## Change Data Capture Actions

KernDX runs trigger actions on Change Events through the same framework you already use for object triggers, so you
can respond to any committed change with ordered, bypassable, feature-flag-gated actions written in Apex or Flow.

Use it when you need to react to a change *after* it has been saved, including changes that did not come through the
normal UI: a Bulk API job, an integration, or another package.
[Change Data Capture](https://developer.salesforce.com/docs/atlas.en-us.change_data_capture.meta/change_data_capture/cdc_intro.htm)
publishes a Change Event whenever a record is created, updated, deleted, or undeleted.

A Change Event action runs **after** the change has committed. There is no before-phase and nothing to roll back: the
event is simply a notification that the change already happened.

### The Change Event trigger

A Change Event entity gets the same one-line trigger file as any object, the one that hands control to the framework. Change Events can only be inserted from your
side, so the trigger handles `after insert`:

```apex
trigger TRG_FoobarChangeEvent on Foobar__ChangeEvent (after insert)
{
	new TRG_Dispatcher().run();
}
```

Each delivered event is one record in the action's incoming list. A single event can represent a change to several
records of the same object, because the platform batches changes committed together.

> **Enabling Change Data Capture:** the Change Event entity (`Foobar__ChangeEvent`) only exists once CDC is switched
> on for the object, either in **Setup → Change Data Capture** or by deploying a `PlatformEventChannel` and
> `PlatformEventChannelMember`. The framework does not enable CDC for you.

### Registering a Change Event action

Change Event entities cannot be selected in the **SObject Type** relationship picklist on `TriggerSetting__mdt`, because the
platform excludes them from that lookup. Register the setting with the **Object API Name Override** field instead:

| Field                      | Value for a CDC setting                                                                                    |
|----------------------------|------------------------------------------------------------------------------------------------------------|
| `ObjectApiNameOverride__c` | The Change Event API name, e.g. `Foobar__ChangeEvent`. This is what the dispatcher routes on.              |
| `SObjectType__c`           | Optional. Set it to the source object (`Foobar__c`) for documentation; the override wins at dispatch time. |

At least one of the two fields must be populated. If both are blank, the deploy fails with the `RequireObjectIdentifier`
validation rule:

> Set either SObject Type (for standard objects, custom objects, and platform events) or Object API Name Override (for
> Change Data Capture entities). At least one must be populated.

Once the setting exists, register `TriggerAction__mdt` rows against it exactly as you would for any object. Set
`Event__c` to `After Insert`, and populate either `ApexClassName__c` (for an Apex action) or `FlowName__c` (for a flow
action).

### Reading the change header

Every Change Event carries a header describing what changed: the change type, the affected record IDs, the changed
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
type [`DTO_ChangeEventHeader`](reference/apex/DTO_ChangeEventHeader.md). (A DTO is a small class holding exactly the fields you want to read.) Declare an Apex-defined variable on the flow:

- **Variable name:** `header`
- **Type:** Apex-Defined
- **Apex Class:** `DTO_ChangeEventHeader`

The framework copies the platform header into that DTO and populates `header` before the interview runs, so you write no
Apex to bridge it. Read its fields in assignments and decisions, for example `header.changeType`, `header.recordIds`,
and `header.changedFields`.

The header exposes the supported subset of the platform's change-event metadata:

| Field                                             | Description                                                                                       |
|---------------------------------------------------|---------------------------------------------------------------------------------------------------|
| `changeType`                                      | `CREATE`, `UPDATE`, `DELETE`, `UNDELETE`, or a `GAP_*` replay-gap notification.                   |
| `recordIds`                                       | The source record IDs this event covers.                                                          |
| `changedFields`                                   | The fields whose values changed in this commit.                                                   |
| `entityName`                                      | The source object API name (`Foobar__c`), not the Change Event suffix.                            |
| `changeOrigin`                                    | The change's origin; useful for filtering out self-initiated changes.                             |
| `commitTimestamp` / `commitUser` / `commitNumber` | Commit metadata. Note `commitTimestamp` is Unix epoch milliseconds (a `Long`), not a `Datetime`.  |
| `transactionKey` / `sequenceNumber`               | Correlate changes from the same atomic transaction.                                               |
| `nulledFields` / `diffFields`                     | Fields nulled, and large/complex fields that differ from the prior commit.                        |

See the [`DTO_ChangeEventHeader` reference](reference/apex/DTO_ChangeEventHeader.md) for the full field list.

### Block DML is unavailable for Change Data Capture

`FailureAction__c = BlockDml` cannot apply to a Change Event action. Block DML works by calling `addError(...)` to abort
an in-progress save, but a Change Event is delivered *after* the change has already committed, so there is nothing left
to block. Two layers keep you from configuring it by accident:

- **At deploy:** the flow-reference scanner (`npm run scan:flow-references`) rejects a Change Event *flow* row whose
  `FailureAction__c` is `BlockDml`, and points you to `LogAndContinue`. (Apex Change Event actions are caught by the
  runtime layer below.)
- **At runtime:** if such a row reaches dispatch anyway, the framework degrades it to `LogAndContinue` and emits a
  distinct warning audit entry so you can find the misconfiguration:

> BlockDml is not supported on Change Event dispatch (cannot roll back a committed change). It is degraded to
> LogAndContinue: {flow name}

Always use `LogAndContinue` (the default) for Change Event actions. A failed Change Event action records the error and
the dispatch continues; the underlying data is already committed regardless.

> **Audit volume:** when a Change Event flow action emits an audit entry, the affected record IDs are aggregated into a
> single entry per dispatch rather than one entry per record, so high-throughput CDC does not flood the audit log.

---

## Post-Trigger Actions

A **post-trigger action** is an Apex class that runs **at the end of each outermost trigger dispatch**, after every
trigger action in that dispatch has finished. One save with a before and an after pass runs it twice, so write it to be
safe to run more than once.

It is for work that should happen at the end of a dispatch, not once per object or per record: one audit summary
for everything that changed, a single background job for the whole batch, or transaction-wide metrics (telemetry). That
work does not belong inside any one object's trigger action.

You register a post-trigger action with `PostTriggerAction__mdt`, and it inherits the framework's ordering, feature-flag
gating, bypass, and performance monitoring.

### When post-trigger actions fire

Post-trigger actions fire **once per outermost trigger dispatch**:

- **Nested DML does not re-fire them.** If a trigger action performs DML on another object, that nested dispatch does
  not run post-actions. The framework fires them only when the outermost dispatch unwinds, so they run exactly once no
  matter how deeply triggers nest.
- **Multiple top-level DML statements fire them multiple times.** A transaction with several independent top-level DML
  statements runs post-actions once for each of them, once as each top-level dispatch completes. Write post-actions to
  be safe to run more than once in a transaction.
- **A save with before and after passes fires them once for each pass.** The before pass and the after pass of one save
  are each an outermost dispatch, so one insert on an object whose trigger registers before and after events runs each
  post-trigger action 2 times. That includes [KernDX's own objects](#how-do-i-add-actions-to-kerndxs-own-objects).
- **Asynchronous and platform-event work gets its own firing.** A Queueable, future, scheduled job, or platform-event
  subscriber runs in a fresh transaction, so its triggers produce their own outermost dispatch and their own
  post-action firing.

### The no-DML contract

**A post-trigger action must not perform synchronous DML.** After your `execute(...)` returns, the framework checks
whether any synchronous DML ran and throws if it did. This **always fails the transaction**, regardless of the
row's Failure Action, because it is a contract violation rather than a runtime fault. The error names the offending
class:

> Post-trigger action "{class}" performed synchronous DML. Post-trigger actions run once after all trigger actions
> complete and must not perform synchronous DML (compute, log, or enqueue async only).

To change data from a post-action, use an **asynchronous** path instead: enqueue a Queueable, future, or scheduled job, or
publish a Platform Event. These are the supported ways to write data from a post-action, and they do not trip the guard.

### Intended uses and anti-patterns

An anti-pattern is a common risky mistake. The right column lists the jobs that do not belong in a post-trigger action.

| Good fit (use a post-trigger action)                                        | Poor fit (use a normal trigger action instead)                 |
|-----------------------------------------------------------------------------|----------------------------------------------------------------|
| Aggregating one audit or telemetry summary for the whole transaction        | Per-record validation or field defaulting                      |
| Enqueuing a single async job for everything touched in the transaction      | Creating or updating related records (that is synchronous DML) |
| Cross-object orchestration that must run after all object triggers complete | Logic that needs per-record old/new values                     |
| Transaction-wide metrics or instrumentation                                 | Object-specific business logic                                 |

A post-trigger action has no per-record context (only the set of SObject *types* whose triggers fired) and cannot do
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

`context.touchedSObjectTypes` is a read-only `Set<SObjectType>`: the SObject types whose triggers participated in the
transaction. Branch on it to decide what to do:

```apex
if(context.touchedSObjectTypes.contains(Account.SObjectType))
{
	// Account triggers ran in this transaction — do Account-domain follow-up.
}
```

The set carries types, not record IDs, by design: a post-action runs once for the whole transaction with no per-record
context. Type-level scoping keeps it bounded in batch operations, and keeps one post-action from accidentally seeing
record data that another post-action staged.

If you need per-record context, have your trigger actions record it in their own static variable and read that static
from the post-action.

### Registering a post-trigger action

Create a `PostTriggerAction__mdt` record. See the
[`PostTriggerAction__mdt` reference](reference/metadata/PostTriggerAction__mdt.md) for the complete field list.

| Field                                                      | Purpose                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                           |
|------------------------------------------------------------|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `ApexClassName__c`                                         | The class implementing `IF_Trigger.PostAction`.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                   |
| `Order__c`                                                 | Execution sequence (lower runs first). Rows sharing an order value run in a stable, predictable sequence, ordered by their developer name, so the order stays the same across deployments.                                                                                                                                                                                                                                                                                                                                                                                                                                   |
| `Description__c`                                           | What the post-action does and why it exists.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      |
| `FailureAction__c`                                         | How an unhandled error is handled. **Log and Continue** (the default): records the error in the audit log and the transaction proceeds; for non-critical follow-up such as notifications or telemetry. Governor-limit errors and synchronous DML still fail the transaction (see below the table). **Block DML**: rethrows the error so the originating DML rolls back; for a post-action that must complete before any data is committed. |
| `RequiredFeatureFlag__c` / `BypassFeatureFlag__c`          | Feature-flag gating: run only when a flag is on, or skip when a flag is on. Same model as trigger actions.                                                                                                                                                                                                                                                                                                                                                                                                                        |
| `BypassExecution__c`                                       | Unconditional kill switch (a master off-switch): when checked, the post-action is skipped for everyone.                                                                                                                                                                                                                                                                                                                                                                                                                           |
| `TriggerSetting__c`                                        | Optional scope. Leave blank to fire on every outermost dispatch (cross-object work). Set it to a Trigger Setting to fire **only** when that setting's object participated in the transaction.                                                                                                                                                                                                                                                                                                                                     |
| `EntryCriteriaContextClassName__c`                         | Optional Apex evaluator implementing `IF_Trigger.PostActionEntryCriteria`. Its `shouldRun(context)` gates the action: return `false` to skip. Use for conditions richer than the Trigger Setting scope.                                                                                                                                                                                                                                                                                                                           |
| `PerformanceThresholdMs__c` / `ForcePerformanceLogging__c` | Per-action performance monitoring: log a run that takes as long as the threshold, or longer, or force its timing to be logged every time. A set threshold or Force logs even when Enable Trigger Performance Logging in Log Setting is off. When blank, the threshold of the linked trigger setting applies, or Log Setting when the row has no trigger setting or that setting has no threshold. |

Whatever `FailureAction__c` says, governor-limit exceptions always propagate, and a synchronous-DML violation always
fails the transaction (see [The no-DML contract](#the-no-dml-contract)).

Bypass Execution is applied first, at query time: the framework loads only non-bypassed rows. The surviving rows are
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

## How do I add actions to KernDX's own objects?

Four of KernDX's own objects have a KernDX trigger that runs all seven trigger events, so you can add trigger actions to
them in the same way as to your own objects. For example, when an outbound call fails, an
after-insert action on API Issue can update the related business record and tell a team.

| Object | API name | One record is |
|---|---|---|
| API Call | `kern__ApiCall__c` | one call to or from another system, with its request, response and status |
| API Issue | `kern__ApiIssue__c` | a problem with an API call, kept for troubleshooting, retry or a fix by hand |
| Scheduled Job | `kern__ScheduledJob__c` | one job on the KernDX job runner |
| Async Chain Execution | `kern__AsyncChainExecution__c` | one run of an async chain |

On Scheduled Job, an action of yours does not switch off KernDX's own checks, unless it bypasses the trigger. When your action, or a flow it starts,
saves a job, KernDX still checks the Manage Job Runner permission, still protects the job runner's own records, and
still schedules the job.

**Add trigger action rows. Never write a trigger of your own on these objects.** KernDX's trigger already runs every
event. If your own trigger also hands its work to the framework, every action on the object runs twice for each event
your trigger registers, KernDX's own actions included. Put that logic in trigger action rows instead.

### Where do your rows go?

A trigger action row names the trigger setting it belongs to. KernDX's own settings for these objects are protected:
your org cannot see them, so a row of yours cannot name them. Create your own `TriggerSetting__mdt` for the object
instead, and put your rows on it.

- **Both settings run.** KernDX reads every trigger setting for an object and runs the actions of each one: its own
  and yours.
- **The order between the two is not defined.** `Order__c` sorts the actions within one setting only. KernDX's own
  actions on these objects use the before events only, so an after-event action of yours never shares an event with
  one of them.
- **Your switches reach only your actions.** Bypass Execution, Required Feature Flag and Bypass Feature Flag on your
  setting switch your actions on or off. KernDX's actions keep running.
- **Apply Masking.** On API Call, API Issue and Async Chain Execution, KernDX's own setting has Apply Masking ticked, so
  these records are masked whatever your setting says. On Scheduled Job, KernDX's setting leaves it unticked: leave
  yours unticked too, unless you add masking targets for Scheduled Job. Masking runs on an object when any of its
  trigger settings has it ticked (see [ApplyMasking__c](#applymasking__c-subscriber-controlled)).

### What happens to KernDX's save when your action fails?

Your action runs inside KernDX's own save of the record. What a failure does depends on the row's `FailureAction__c`:

| When your action fails with | What happens to KernDX's save |
|---|---|
| An error, with `FailureAction__c` blank or `LogAndContinue` | The error is logged and KernDX's save goes through |
| An error, with `FailureAction__c` set to `BlockDml` | The error is thrown again and the whole save rolls back. That removes the very record that started your action. On API Issue, KernDX saves the issue on its own, after the failed call is saved, and does not stop for an error there: the issue is lost, the failed call stays saved, and no error reaches the user. Only the log shows it |
| A governor-limit error (for example, too many queries) | Always thrown again, whatever the row says, so the save rolls back as with `BlockDml` |

**Leave `FailureAction__c` blank on rows on KernDX's objects** (blank means `LogAndContinue`). A failure is logged as a
log entry, never as an API issue, so a failing action on API Issue cannot create another API issue.

A validation rule or record-triggered flow of yours on these objects can already roll back KernDX's save in the same
way. Keep the work in these actions small, and move anything heavy to a background job.

> **Warning:** automation on Async Chain Execution runs inside the chain engine's own jobs, including the watchdog that
> recovers stuck chains, and spends their limits. Read
> [Keep queries and saves out of your automation on chain run records](Async%20Processing%20-%20Guide.md#turn-on-stalled-chain-recovery)
> before you add an after-update action there.

### Example: act after an API issue is saved

The action class. It is `public`, like this guide's other samples; declare it `global` if your org has no Type Resolver
(see [Quick Start](#quick-start)).

```apex
public inherited sharing class TRG_NotifyTeamOfApiIssue extends kern.TRG_Base implements kern.IF_Trigger.AfterInsert
{
	public void afterInsert(List<SObject> newRecords)
	{
		Set<String> serviceNames = new Set<String>();
		for(SObject record : newRecords)
		{
			serviceNames.add(((kern__ApiIssue__c)record).kern__ServiceName__c);
		}
		// Your work goes here, for example: assign the issues to a queue and tell the queue's members.
	}
}
```

Your own trigger setting for API Issue. Its developer name, `MyApiIssueActions`, is the name the action row points to:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<CustomMetadata xmlns="http://soap.sforce.com/2006/04/metadata" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema">
    <label>My API Issue Actions</label>
    <protected>false</protected>
    <values>
        <field>kern__SObjectType__c</field>
        <value xsi:type="xsd:string">kern__ApiIssue__c</value>
    </values>
    <values>
        <field>kern__ApplyMasking__c</field>
        <value xsi:type="xsd:boolean">true</value>
    </values>
    <values>
        <field>kern__BypassExecution__c</field>
        <value xsi:type="xsd:boolean">false</value>
    </values>
</CustomMetadata>
```

Apply Masking stays ticked. API issues then stay masked as they are today, whatever the other settings say, and your
action sees the masked values, because masking runs on the before pass.

The action row, on your setting:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<CustomMetadata xmlns="http://soap.sforce.com/2006/04/metadata" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema">
    <label>Notify Team Of API Issue - After Insert</label>
    <protected>false</protected>
    <values>
        <field>kern__ApexClassName__c</field>
        <value xsi:type="xsd:string">TRG_NotifyTeamOfApiIssue</value>
    </values>
    <values>
        <field>kern__Event__c</field>
        <value xsi:type="xsd:string">After Insert</value>
    </values>
    <values>
        <field>kern__TriggerSetting__c</field>
        <value xsi:type="xsd:string">MyApiIssueActions</value>
    </values>
    <values>
        <field>kern__Order__c</field>
        <value xsi:type="xsd:double">100.0</value>
    </values>
    <values>
        <field>kern__AllowNonSelfInitiated__c</field>
        <value xsi:type="xsd:boolean">true</value>
    </values>
    <values>
        <field>kern__AllowRecursion__c</field>
        <value xsi:type="xsd:boolean">false</value>
    </values>
    <values>
        <field>kern__EntryCriteriaFormula__c</field>
        <value xsi:type="xsd:string">newRecord.kern__ServiceName__c = &apos;PaymentService&apos;</value>
    </values>
    <values>
        <field>kern__Description__c</field>
        <value xsi:type="xsd:string">Tells the team when a call to the payment service fails.</value>
    </values>
</CustomMetadata>
```

- **The formula** runs the action only for issues on the service named `PaymentService`.
- **No context class name.** API Issue has a built-in formula context, so the field stays blank.
- **No `FailureAction__c`.** Left out, it is `LogAndContinue`.

### What about a formula on Scheduled Job or Async Chain Execution?

These two objects have no built-in formula context. To use an entry formula on them, write a `global` context class and
put its name in the row's `EntryCriteriaContextClassName__c`:

```apex
/**
 * @description Gives an entry formula the scheduled job record before and after the save.
 */
@JsonAccess(serializable='always')
@SuppressWarnings('PMD.AvoidGlobalModifier')
global inherited sharing class UTIL_ScheduledJobContext implements kern.UTIL_FormulaFilter.INT_SObjectFormulaEvaluationContext
{
	/**
	 * @description The scheduled job before the save (null on insert).
	 */
	global kern__ScheduledJob__c oldRecord;

	/**
	 * @description The scheduled job after the save (null on delete).
	 */
	global kern__ScheduledJob__c newRecord;

	/**
	 * @description Sets the records the formula reads.
	 *
	 * @param oldSObject The scheduled job before the save
	 * @param newSObject The scheduled job after the save
	 */
	public void setContext(SObject oldSObject, SObject newSObject)
	{
		oldRecord = (kern__ScheduledJob__c)oldSObject;
		newRecord = (kern__ScheduledJob__c)newSObject;
	}
}
```

```text
Context Class Name: UTIL_ScheduledJobContext
Entry Criteria Formula: newRecord.kern__IsActive__c = false
```

A context class for Async Chain Execution has the same shape, with `kern__AsyncChainExecution__c` in place of
`kern__ScheduledJob__c`.

### How often do post-trigger actions run on these objects?

A post-trigger action runs at the end of each pass of a save (see
[When post-trigger actions fire](#when-post-trigger-actions-fire)). These objects now run both a before pass and an
after pass, so one insert of an API issue runs each post-trigger action 2 times. Write post-trigger actions so that they
are safe to run more than once.

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
				.condition(Contact.AccountId).isIn(new List<Id>(accountIdToNewPhone.keySet()))
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

When several actions on the same object need the same related data, query it once and share the result: fewer SOQL
queries, none inside a loop, faster triggers, and actions that stay bulk-safe. Querying it in each action wastes
queries and risks hitting governor limits.

| Way | How it works |
|---|---|
| **Every action reads through the same caching selector** (the simpler one) | The first read queries and the rest come from memory. See [Let the selector share one query](#let-the-selector-share-one-query). |
| **An early action queries and caches the data by hand** | Later actions read from that cache. See [Caching Pattern Overview](#caching-pattern-overview). |

### Let the selector share one query

Opt the selector into caching once, by overriding `cacheScope()`, and let each action call it as if it were the only one:

```apex
public with sharing class SEL_Contacts extends SEL_Base
{
	public SEL_Contacts()
	{
		super(Contact.SObjectType);
	}

	public override List<SObjectField> getFields()
	{
		return new List<SObjectField>{ Contact.AccountId, Contact.FirstName, Contact.LastName, Contact.Email };
	}

	public override UTIL_Cache.Scope cacheScope()
	{
		return UTIL_Cache.Scope.IN_TRANSACTION;
	}

	public List<Contact> findByAccountIds(Set<Id> accountIds)
	{
		return (List<Contact>)query.condition(Contact.AccountId).isIn(new List<Id>(accountIds)).toList();
	}
}

// In each action that needs the contacts, before or after update:
List<Contact> contacts = new SEL_Contacts().findByAccountIds(new Map<Id, Account>(newAccounts).keySet());
```

The first action to call `findByAccountIds` runs the query; every later call in the same transaction with the same Ids gets its own copy of the rows from memory.

The selector is declared `with sharing`, the safe default for the selectors you write. A class declared
`inherited sharing` takes its sharing from the code that calls it: when a class declared `without sharing` calls it,
it runs without sharing too.

The actions stay independent: none of them needs to know which one runs first, an action can be switched off without breaking the others, and each can be tested on its own.

**When the rows are cached.** This selector reads in user mode:

- **User mode** enforces the current user's read and write permissions and record sharing; system mode skips all of those checks.
- User mode is the default while the `UserModeQueries_Enabled` feature flag is on.
- With the flag switched off its reads run in system mode, and because `findByAccountIds` does not state its sharing, they are not cached.
- A selector that reads in system mode caches only in methods that state their sharing with `withSharing()` or `bypassSharing()`.

A write through `DML_Builder` between two actions empties the cache, so the next read queries again and sees the write. The [Selectors Guide](Selectors%20-%20Guide.md#caching-queries) covers the scopes, what empties the cache and which reads are never kept.

### Caching Pattern Overview

**Concept:** The hand-written option. Use it when later actions need the data shaped in a way the query alone does not give them (here, contacts grouped by account), and accept that the actions then depend on their order.

Trigger actions act like functions in a pipeline: an early action can cache data in a static variable, and later actions can access that cache.

**Two ways to hold the cache:**

| Hold it in | Right for |
|---|---|
| Typed static variables on the caching action class (the pattern below), which give later actions strongly typed getters | Structured record data |
| [`UTIL_Cache.inTransaction()`](reference/apex/UTIL_Cache.md), the transaction-scoped store the framework already ships: a name-keyed store (`put`, `get`, `contains`, `remove`) whose contents live only for the current transaction and are shared by every caller in it | Simple values where a holder class is overkill |

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
			.condition(Contact.AccountId).isIn(new List<Id>(accountIds))
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
Event: Before Update
Trigger Setting: Account
Order: 10
Description: Queries and caches Contact data for use by later actions
```

**TriggerAction__mdt for Validation Action:**

```text
Label: Validate Premium Account Contacts
Developer Name: Account_ValidatePremiumContacts
Apex Class Name: TRG_ValidatePremiumAccountContacts
Event: Before Update
Trigger Setting: Account
Order: 20
Description: Validates premium accounts have at least one contact using cached data
```

**TriggerAction__mdt for Summary Action:**

```text
Label: Update Account Contact Summary
Developer Name: Account_UpdateContactSummary
Apex Class Name: TRG_UpdateAccountContactSummary
Event: Before Update
Trigger Setting: Account
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
- **Simple Values**: use `UTIL_Cache.inTransaction()`; keep the typed caching action for structured record data (see [Caching Pattern Overview](#caching-pattern-overview))
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
@IsTest(seeAllData=false isParallel=true)
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

## How do I link actions together?

Because each action is small and runs in a known order, you can build complex behaviour by composing several simple actions rather than writing one large one. Think of the actions as **functions in a pipeline**, where:

- Each action has a **single, focused responsibility**
- Actions execute in a **defined order** (like function calls)
- Actions can be **composed** to create complex behaviour
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
  Event: Before Update
  Trigger Setting: Case
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

The result: a single SOQL query (Order 10), and five actions that each do one job, can be tested on their own and can be
added, removed or reordered in metadata; the four later actions receive only the records their entry criteria pass.

---

## What else can it do?

### Recursion Prevention

An action that updates the same object can trigger itself, which risks an infinite loop. You can stop that by telling the framework to skip an action while an earlier run of it is still in progress. The action still runs for separate, later operations in the same transaction.

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
- Want the framework to stop that re-entry instead of writing your own guard flag

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
			.condition(Account.Id).isIn(new List<Id>(accountIds))
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

Sometimes you want an action to run only when a user changes the object directly, not when another object's trigger changes it as a side effect. This setting gives you that control.

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

The framework gives you several levels of bypass: an entire object, a single action, or a flag-controlled group. Use
them during a data load, migration, or incident, when you need to turn trigger logic off without a deployment. The
flag-controlled kind is under [Feature Flag Bypass](#feature-flag-bypass).

Every programmatic bypass call (object-level and action-level) emits a `LogEntryEvent__e` at WARN level with a
`BypassEvent` category, creating an audit trail of who bypassed which actions and why.

#### Object-Level Bypass (TriggerSetting__mdt)

**Via BypassExecution__c:**

```text
TriggerSetting__mdt:
  SObject Type: Account
  Bypass Execution: true
```

**Effect:** All actions for Account are bypassed.

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

> **How the name is matched.** `bypassAction`, `isActionBypassed` and `clearActionBypass` look the name up against
> the registered trigger actions, ignoring case:
>
> | You pass | What is bypassed |
> |---|---|
> | The exact class name of one of your own actions | Your action. An exact match always wins, so if your action has the same bare name as a packaged one, pass the prefixed name to reach the packaged one. |
> | The bare class name of an action the package ships, such as `'TRG_AsyncChainRunTransition'` | That action, in every org, whatever the package's prefix. |
> | The name with the package prefix: `'kern.'` followed by the bare name | That action, but only in an org where the package's prefix is `kern`. |
> | A name that matches no registered action | Nothing; the real action keeps running. |
>
> A name that matches no action (a misspelling, or a `kern.` prefix in an org without that prefix) still compiles and
> still records a bypass audit entry. That entry carries an `unmatchedTarget` flag in its context, so an ineffective
> bypass shows up in the audit trail instead of passing silently.
>
> When bypassing your own action classes, prefer the compiler-checked form `TRG_Base.bypassAction(TRG_ValidateAccount.class.getName())` over a string literal.

> **Flow actions share one bypass key.** Every flow action runs through the framework's built-in flow runner, so the
> action-level key is that runner's class name, and bypassing it switches off every flow action for the rest of the
> transaction. To switch off a single flow row, set its `BypassExecution__c` or gate it with a feature flag instead.
>
> Pass the bare `'TRG_InvokeFlow'`, which works on a managed install and in an unmanaged deploy
> (`'kern.TRG_InvokeFlow'` also works on a managed install). On a managed install the runner is internal to the
> framework, so you pass the name as a plain string; the compiler-checked `.class.getName()` form above is not
> available for it there.

#### Bypass Audit Trail

Every call to `TRG_Base.bypass*()` / `clearBypass*()` / `clearAll*Bypasses()` emits a WARN-level
`LogEntryEvent__e` tagged with `category = 'BypassEvent'`. The event captures:

- the running user;
- the action (`BYPASS`, `CLEAR`, `CLEAR_ALL`);
- the surface (`trigger-object` / `trigger-action`);
- the target (SObject API name or class name);
- the optional reason set via `TRG_Base.setBypassReason(String)`.

When an action-level bypass or clear names a class that matches no registered trigger action, the entry also carries
`unmatchedTarget: true` in its context: the bypass was recorded, but it can never take effect.

The same audit channel covers query (`QRY_Builder.withSystemMode` / `bypassSharing` / `withoutSecurity` →
`surface = 'query'`), DML (`DML_Builder.withSystemMode` / `bypassSharing` → `surface = 'dml'`), and validation
(`UTIL_ValidationRule.bypassObject` / `bypassGroup` / `bypassRule` → `surface = 'validation'`) bypasses.

In a noisy environment you can turn this runtime emission off via a `FeatureFlagStrategy__mdt` override on
the `BypassAudit_Enabled` `FeatureFlag__mdt` record (it is on by default).

```apex
// Attach a business reason to any bypasses emitted in this transaction
TRG_Base.setBypassReason('Nightly data-integrity reconciliation batch');

TRG_Base.bypass(Account.SObjectType);
TRG_Base.bypassAction('TRG_ValidateAccount');
```

The `TRG_Base.BypassType` enum is available to your own code, so you can name a bypass scope without a string
literal.

To read the audit trail back, use the query in the [Security Guide](Security%20-%20Guide.md#how-do-i-see-who-turned-a-check-off). What to know when you read it:

- **Grouping key.** The query finds bypass entries by their grouping key: `Fingerprint__c` starting with `detail:bypass:`.
- **The user.** The query reads the user from `UserId__c`. Do not read `CreatedById` for this: log entries are saved
  by a background process, so `CreatedById` is always the Automated Process user.
- **Trigger bypasses.** They show the surface at the end of the short message: `ShortMessage__c` ends with
  `(trigger-object)` or `(trigger-action)`.
- **Log level.** Bypass entries are saved at every log level, ERROR included, while logging is on (`IsEnabled__c` on
  `LogSetting__c`) and the `BypassAudit_Enabled` feature flag is on. Those two are the off-switches. A class filter or
  a suppression on the log setting that leaves out a class also hides that class's bypass entries.

**Why this matters:** bypasses weaken security and automation guarantees. The audit trail answers "which user
bypassed which action, when, and why?" without requiring every bypass call-site to remember to log the event.

#### Flow-Based Bypass ([`FLOW_BypassTrigger`](reference/apex/FLOW_BypassTrigger.md))

Declarative orgs can toggle bypasses from Flow without Apex:

| Invocable | What it does |
|---|---|
| `FLOW_BypassTrigger` | Accepts a `DTO_Request` with `action` (`BYPASS` / `CLEAR` / `CLEAR_ALL`), `bypassType` (`OBJECT_NAME` / `CLASS_NAME`), and `name` (the SObject API name or action class name). |
| `FLOW_CheckTriggerBypassed` | The companion: reports whether a bypass is currently in effect. |

Flow Builder offers the `action` and `bypassType` values as picklists in the action's property panel (for both
invocables), so you pick them rather than typing the raw values. Both emit the same `BypassEvent`-category audit log as
the Apex API, so Flow-driven bypasses show up in the same audit trail.

### Feature Flag Integration

Feature flags let you roll an action out to a chosen group of users, or switch it off in an emergency, without redeploying.

The `BypassFeatureFlag__c` and `RequiredFeatureFlag__c` fields on both `TriggerSetting__mdt` and `TriggerAction__mdt` are **MetadataRelationship** lookups to `FeatureFlag__mdt`
records managed through the [Feature Flag framework](reference/apex/UTIL_FeatureFlag.md). They appear as dropdown pickers in the Custom Metadata UI, which keeps the link valid
and prevents typos.

**How It Works:**

```text
1. If no Feature Flag is selected -> Condition not met (no bypass/no requirement)
2. Resolve the referenced FeatureFlag__mdt record
3. Evaluate the Feature Flag for the running user (strategies, defaults, active state)
4. If Feature Flag is enabled -> Condition is met (bypass applies / requirement satisfied)
```

Custom Permissions are not referenced directly in these fields. To use permission-based targeting, create a Feature Flag with a `Custom Permission` strategy type in
`FeatureFlagStrategy__mdt`.

**Is a skipped action logged?**

No. When a bypass flag is on, or a required flag is off, the action is skipped and no log entry is written.
The flag is your own setting, so the flag record already shows why the action did not run.

To find out why an action is not running, check the feature flags named in `BypassFeatureFlag__c` and
`RequiredFeatureFlag__c` on the action and on its trigger setting.

#### Feature Flag Bypass

**Via BypassFeatureFlag__c:** when the Feature Flag named in `BypassFeatureFlag__c` (on `TriggerSetting__mdt` or `TriggerAction__mdt`)
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
    - Use `FeatureFlagStrategy__mdt` to target by Profile, Permission Set or Group, or custom logic
    - Or set `IsEnabledByDefault__c = true` to bypass for all users

**Use Cases:**

- Emergency kill switches, a master off-switch you can flip in an incident (enable the flag to bypass, no deployment required)
- Targeted bypass for integration users via a permission set or permission set group strategy
- Data migration bypass controlled by Feature Flag

**Example: Kill Switch with Feature Flag**

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

#### Feature Flag Gating

**Via RequiredFeatureFlag__c:** actions only execute when the Feature Flag named in `RequiredFeatureFlag__c` (on `TriggerSetting__mdt` or
`TriggerAction__mdt`) evaluates to `true` for the running user.

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

**Example: Gradual Rollout with Feature Flag**

```apex
// Step 1: Create Feature Flag for new validation
// FeatureFlag__mdt:
//   DeveloperName: 'Enable_New_Account_Validation'
//   IsActive__c: true
//   IsEnabledByDefault__c: false (disabled for most users)
//
// FeatureFlagStrategy__mdt:
//   Type__c: Permission Set Group
//   Target__c: 'Beta_Testers'
//   IsActive__c: true

// Step 2: Configure TriggerAction__mdt
// RequiredFeatureFlag__c: 'Enable_New_Account_Validation'

// Result: Action ONLY runs for users in the Beta_Testers Permission Set Group
// When ready for GA: Set FeatureFlag IsEnabledByDefault__c = true
```

**Example: Profile-Based Targeting**

```apex
// Step 1: Create Feature Flag with Profile strategy
// FeatureFlag__mdt:
//   DeveloperName: 'Enable_Premium_Validation'
//   IsActive__c: true
//
// FeatureFlagStrategy__mdt:
//   Type__c: Profile
//   Target__c: 'Premium_User_Profile'
//   IsActive__c: true

// Step 2: Configure TriggerAction__mdt
// RequiredFeatureFlag__c: 'Enable_Premium_Validation'

// Result: Action only runs for users with Premium_User_Profile
```

### Entry Criteria Formulas

To run an action only for certain records (say, only Premium accounts), give it an entry criteria formula. The framework evaluates that formula per record and passes only the matching records to your action, so the action's own code stays free of filtering logic.

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
			if(String.isBlank(account.Description))
			{
				account.Description = 'ACC-' + String.valueOf(System.now().getTime());
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
				.condition(Contact.AccountId).isIn(new List<Id>(accountIdToNewPhone.keySet()))
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

Because each action is a small, self-contained class, you can test it on its own rather than exercising the whole trigger. Two styles are common: a full save through the framework ([Testing Individual Actions](#testing-individual-actions)), and a direct call to one action with no database writes at all ([Testing an Action Without DML](#testing-an-action-without-dml)).

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
@IsTest(seeAllData=false isParallel=true)
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

### Testing an Action Without DML

Every action receives its records as a plain `List<SObject>`, so you can unit-test one in isolation with no `insert`, no dispatcher, and no `TriggerAction__mdt` deployment. Build the trigger records in memory, and if the action reads related data through a selector, register those rows with [`TST_Mock`](reference/apex/TST_Mock.md) so the query returns them without a database round-trip.

```apex
@IsTest(seeAllData=false isParallel=true)
private class TRG_FlagHighValueAccount_TEST
{
	@IsTest
	private static void beforeUpdate_givenRevenueJump_flagsAccount()
	{
		// 1. Trigger rows, in memory — valid mock Ids, no DML.
		Account newRecord = (Account)TST_Mock.of(Account.SObjectType)
			.withOverride(Account.Name, 'Acme')
			.withOverride(Account.AnnualRevenue, 5000000)
			.build();
		Account oldRecord = (Account)TST_Builder.of(Account.SObjectType)
			.withOverride(Account.Id, newRecord.Id)
			.withOverride(Account.AnnualRevenue, 100000)
			.withoutInsertion()
			.build();

		// 2. The action reads Contacts through a selector — mock that read, still no DML.
		TST_Mock.register(Contact.SObjectType, new List<Contact>
		{
			(Contact)TST_Builder.of(Contact.SObjectType)
				.withOverride(Contact.AccountId, newRecord.Id)
				.withoutInsertion()
				.build()
		});

		// 3. Invoke the action method directly and assert.
		Test.startTest();
		new TRG_FlagHighValueAccount().beforeUpdate(
			new List<SObject>{ newRecord },
			new List<SObject>{ oldRecord }
		);
		Test.stopTest();

		Assert.isTrue(newRecord.Priority_Review__c, 'A large revenue jump should flag the account');

		TST_Mock.clear();
	}
}
```

The test exercises one rule's logic with no DML and no setup beyond the records it cares about:

| Call | What it does |
|---|---|
| `TST_Mock.of(...).build()` | Creates a record with a valid mock Id and auto-registers it. |
| `TST_Builder.of(...).withoutInsertion()` | Builds an in-memory record without touching the database. Give it an Id with `withOverride(<Object>.Id, ...)` or `withoutInsertion(true)` when the code under test needs one. |
| `TST_Mock.register(...)` | Makes the action's selector queries return the records you supply. |

**`Trigger.oldMap` is null in this test.** When a test calls the action method directly, no trigger is running. So
`Trigger.oldMap`, and the `triggerOldMap` property your action gets from `TRG_Base`, are null. Read the old version
of a record from the old records list the method receives instead, for example by building a map by Id. The test
passes that list itself, as the sample does with `oldRecord`.

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

When a trigger gets slow, you need to know which action is to blame without scattering timing code through your classes. The framework times every action for you and logs the slow ones, so you can find the bottleneck from a report instead of by guesswork.

### Performance Logging Overview

The framework:

1. Times each trigger action's execution
2. Compares duration against configurable thresholds
3. Logs entries to `LogEntry__c` when a run takes as long as the threshold that applies, or longer
4. Captures rich context (action name, trigger operation, object, record count)

**Performance Log Entry Example:**

```text
LogEntry__c:
  ShortMessage__c: "TRG_AccountValidateName (BEFORE_INSERT) completed in 1523ms"
  Message__c: "CPU: 1490ms, Heap: 48000 bytes, SOQL: 1, DML: 0, Records: 200"
  ClassMethod__c: "TRG_AccountValidateName/before_insert"
  LogLevel__c: "DEBUG"
  ContextData__c: {"contextData" : {"_operationType" : "TRIGGER_ACTION", "actionClassName" : "TRG_AccountValidateName", "triggerOperation" : "BEFORE_INSERT", "objectName" : "Account", "recordCount" : "200", ...}}
```

### Configuration Hierarchy

Performance logging has **three levels**. The strongest rule wins:

```text
+--------------------------------------------------------------+
|  1. TriggerAction__mdt (one action) - strongest              |
|     SuppressPerformanceLogging__c = true -> Never log        |
|     ForcePerformanceLogging__c = true -> Always log          |
|     PerformanceThresholdMs__c = 100 -> Action threshold      |
+--------------------------------------------------------------+
|  2. TriggerSetting__mdt (the actions registered under it)    |
|     PerformanceThresholdMs__c = 500 -> Setting threshold     |
+--------------------------------------------------------------+
|  3. LogSetting__c (org, profile or user)                     |
|     EnableTriggerPerformanceLogging__c = true -> Turned on   |
|     TriggerPerformanceThresholdMs__c = 500 -> Org threshold  |
+--------------------------------------------------------------+
```

How the levels combine for one action:

- **Suppress beats everything.** A suppressed action never logs, even when Force Performance Logging is also ticked.
- **Force logs every run**, even when Enable Trigger Performance Logging in Log Setting is off.
- **The most specific threshold that is set applies:** the action's own threshold, else its trigger setting's.
- **A set threshold logs even when Enable Trigger Performance Logging in Log Setting is off.**
- **When neither threshold is set, Log Setting decides:** the org threshold applies, and only while Enable Trigger
  Performance Logging is on.

A run is logged when it takes as long as the threshold or longer, so `0` logs every run. A very high threshold stops
the entries for those actions.

**Example:** Enable Trigger Performance Logging is off, a trigger setting has a threshold of 500 ms, and one of its
actions has its own threshold of 2000 ms. That action logs a run of 2000 ms or longer. Every other action under the
setting logs a run of 500 ms or longer.

**Configuration Fields:**

| Level           | Metadata Type         | Field                                | Description                                                     |
|-----------------|-----------------------|--------------------------------------|-----------------------------------------------------------------|
| Action          | `TriggerAction__mdt`  | `SuppressPerformanceLogging__c`      | Never log this action, even when Force is also ticked           |
| Action          | `TriggerAction__mdt`  | `ForcePerformanceLogging__c`         | Always log this action, whatever the threshold                  |
| Action          | `TriggerAction__mdt`  | `PerformanceThresholdMs__c`          | Threshold for this action (ms); wins over the trigger setting's |
| Trigger setting | `TriggerSetting__mdt` | `PerformanceThresholdMs__c`          | Threshold for the actions registered under this setting (ms)    |
| Org             | `LogSetting__c`       | `EnableTriggerPerformanceLogging__c` | Turns on the org threshold where no action or setting has one   |
| Org             | `LogSetting__c`       | `TriggerPerformanceThresholdMs__c`   | Org threshold (ms)                                              |

`TriggerSetting__mdt.EnablePerformanceLogging__c` is deprecated and has no effect, so it is not in this table.

**Which trigger setting counts?** The one the action row is registered under (`TriggerSetting__c` on the action row).

- An object can have more than one trigger setting. Each setting's threshold covers only its own actions.
- A post-trigger action with no trigger setting uses its own threshold, else Log Setting.
- The trigger settings that ship with KernDX are protected, so you cannot set their threshold. KernDX's own actions
  therefore follow Log Setting. A threshold on your own trigger setting for a KernDX object affects only your actions.

**Typical Configuration:**

```text
LogSetting__c (Org Default):
  EnableTriggerPerformanceLogging__c: true
  TriggerPerformanceThresholdMs__c: 500  <- Log actions taking 500 ms or longer

TriggerSetting__mdt (Account_Trigger_Setting):
  PerformanceThresholdMs__c: 200  <- Actions under this setting: stricter 200 ms threshold

TriggerAction__mdt (TRG_AccountValidateName):
  PerformanceThresholdMs__c: null   <- Uses the trigger setting's threshold (200 ms)

TriggerAction__mdt (TRG_AccountExternalSync):
  ForcePerformanceLogging__c: true  <- Always log this slow action

TriggerAction__mdt (TRG_AccountSetDefaults):
  SuppressPerformanceLogging__c: true  <- Never log (known to be fast)
```

### How do I stop every slow-action entry?

Turning off Enable Trigger Performance Logging in Log Setting does **not** stop the entries from a threshold set on an
action or a trigger setting, or from Force Performance Logging. To stop every slow-action entry, at the org, profile or
user level, do one of these in Log Setting:

- Turn off **Is Enabled** (`IsEnabled__c`). This stops all logging except errors.
- Set **Log Level Threshold** (`LogLevelThreshold__c`) above DEBUG, for example INFO. Slow-action entries are written
  at DEBUG, so this also stops your other DEBUG entries.

To quiet one trigger action, tick Suppress Performance Logging on it. A post-trigger action has no Suppress setting:
give it a very high threshold instead.

> **Warning:** Do not set a low threshold on your own trigger setting or action for a log object, such as `LogEntryEvent__e`.
> Each slow-action entry is a new log event, which can run that trigger again in a new transaction. A threshold of `0`
> logs every run, so the entries can keep coming. Turning off Enable Trigger Performance Logging does not stop them.

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
|       -> If duration >= the threshold that applies:                   |
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

Read the log entries through a selector of your own. This one keeps the slow-action read in one method:

```apex
public with sharing class SEL_LogEntries extends SEL_Base
{
	public SEL_LogEntries()
	{
		super(LogEntry__c.SObjectType);
	}

	public override List<SObjectField> getFields()
	{
		return new List<SObjectField>
		{
			LogEntry__c.ShortMessage__c,
			LogEntry__c.Message__c,
			LogEntry__c.DurationMs__c,
			LogEntry__c.ContextData__c,
			LogEntry__c.CreatedDate
		};
	}

	public List<LogEntry__c> findSlowTriggerActions(Datetime since, Integer maximumRows)
	{
		return (List<LogEntry__c>)query
			.condition(LogEntry__c.ShortMessage__c).contains(' completed in ')
			.andCondition(LogEntry__c.CreatedDate).greaterThanOrEquals(since)
			.orderBy(LogEntry__c.DurationMs__c).descending()
			.withLimit(maximumRows)
			.toList();
	}
}

// Find slow trigger actions in the last 24 hours
List<LogEntry__c> slowTriggers = new SEL_LogEntries().findSlowTriggerActions(System.now().addDays(-1), 50);

for(LogEntry__c log : slowTriggers)
{
	LOG_Builder.build().info(log.DurationMs__c + 'ms - ' + log.ShortMessage__c).emitAt('TriggerPerformance.review');
}
```

**Sample Report Filter:**

Create a report on `LogEntry__c` with:

- Filter: `ShortMessage__c` contains "completed in" and `LogLevel__c` equals "DEBUG"
- Group by: `ClassMethod__c` (action class and trigger operation, such as `TRG_AccountValidateName/before_insert`)
- Summarise: `AVG(DurationMs__c)`, `MAX(DurationMs__c)`, `COUNT(Id)`

**Best Practices:**

| Practice                                                | Rationale                                   |
|---------------------------------------------------------|---------------------------------------------|
| Start with the Log Setting threshold of 500 ms          | Catches significant issues without noise    |
| Use `ForcePerformanceLogging__c` for known slow actions | Monitor integrations, complex validations   |
| Use `SuppressPerformanceLogging__c` for trivial actions | Reduce log volume for simple field defaults |
| Review logs weekly                                      | Identify degrading performance trends       |
| Set stricter thresholds for high-volume objects         | Catch issues before they impact users       |

> **See Also:** For the full logging documentation, including correlation tracking (one tracking ID that follows a single user action across triggers, queries, callouts, and jobs), the context stack, and other performance timers, see [Logging - Guide](Logging%20-%20Guide.md).

---

## What are the moving parts?

### How does it work?

Each object gets one [trigger](https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_triggers.htm)
file with one line in it, which hands control to `TRG_Dispatcher`. The dispatcher reads the configuration records and
runs each matching action in order:

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

> **Responsibilities:** Trigger actions execute discrete units of work (validation, field defaulting, related record creation). They do not
> query data inline; use selectors for that. They do not contain reusable business logic; extract that to service classes.

Each run has a small cost: the dispatcher reads the configuration records (metadata queries) and creates each action
class by name (reflection).

### Core Classes

#### [TRG_Base](reference/apex/TRG_Base.md)

Every trigger action extends this base class. It hands you the records being changed and the [trigger context](https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_triggers_context_variables.htm) (which trigger event you are in), and gives you the methods that turn actions on and off, so you never rewrite that plumbing in each action:

```apex
global virtual inherited sharing class TRG_Base
{
	// Protected properties accessible to subclasses
	global protected String sObjectName { get; private set; }
	global protected TriggerOperation context { get; private set; }
	global protected List<SObject> triggerNew { get; private set; }
	global protected List<SObject> triggerOld { get; private set; }
	global protected Map<Id, SObject> triggerOldMap { get; private set; }

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

	// Bypass control methods (object or action, chosen by a BypassType)
	global static void bypass(String name, BypassType type)
	global static Boolean isBypassed(String name, BypassType type)
	global static void clearBypass(String name, BypassType type)
	global static void clearAllBypasses(BypassType type)

	// Audit-trail helper: attach a reason to subsequent bypass events
	global static void setBypassReason(String reason)

	// Enum returned by resolveBypassType(String) for bypass-scope parsing
	global enum BypassType { CLASS_NAME, OBJECT_NAME }
	global static BypassType resolveBypassType(String bypassTypeString)
}
```

**Key Features:**

- Automatically populates trigger context properties
- Validates execution only within trigger context
- Provides object-level bypass control
- Calls appropriate interface method based on [trigger operation](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_enum_System_TriggerOperation.htm)

#### [TRG_Dispatcher](reference/apex/TRG_Dispatcher.md)

This is the one class your trigger file calls. It reads your configuration, works out which actions apply to the current object and event, and runs them in order, so you never wire that up by hand:

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

There is one interface per trigger event. Your action implements the one (or ones) that match when it should run, and that single choice is what tells the framework where to invoke it:

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

One record per object you want the framework to manage. It is the switchboard for that object: it turns the framework on, and sets org-wide options such as bypass and masking that apply to every action on the object.

<details>
<summary>Every TriggerSetting__mdt field</summary>

| Field                         | Type                                   | Purpose                                                                      |
|-------------------------------|----------------------------------------|------------------------------------------------------------------------------|
| `SObjectType__c`              | MetadataRelationship(EntityDefinition) | The SObject this trigger setting applies to                                  |
| `ObjectApiNameOverride__c`    | Text(255)                              | API name to dispatch on instead of the relationship, for Change Data Capture |
| `BypassExecution__c`          | Checkbox                               | Bypass all actions for this object                                           |
| `BypassFeatureFlag__c`        | MetadataRelationship(FeatureFlag__mdt) | Feature Flag that bypasses all actions when enabled                          |
| `RequiredFeatureFlag__c`      | MetadataRelationship(FeatureFlag__mdt) | Feature Flag required for actions to run                                     |
| `EnablePerformanceLogging__c` | Checkbox                               | Deprecated: has no effect. Use `PerformanceThresholdMs__c`                   |
| `PerformanceThresholdMs__c`   | Number(8,0)                            | Log a run of the actions registered under this setting that takes this long or longer (ms), even when Enable Trigger Performance Logging in Log Setting is off. Blank follows Log Setting |
| `ApplyMasking__c`             | Checkbox                               | Mask configured sensitive fields before actions run                          |

</details>

#### TriggerAction__mdt

One record per piece of logic. Each row points at an action (an Apex class or a flow), says which trigger event it runs in, sets its run order, and carries its own options such as conditions and bypass:

<details>
<summary>Every TriggerAction__mdt field</summary>

| Field                              | Type                                      | Purpose                                                                                                                                                                                                                               |
|------------------------------------|-------------------------------------------|---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `ApexClassName__c`                 | Text(100)                                 | Fully qualified Apex class name. Set this for Apex actions; leave blank for flow actions (the framework dispatches to its built-in flow runner when `FlowName__c` is populated).                                                      |
| `FlowName__c`                      | Text(80)                                  | Bare flow API name for flow-based actions. Leave blank for Apex actions.                                                                                                                                                              |
| `FailureAction__c`                 | Picklist                                  | How the dispatcher handles uncaught errors raised by the action: `LogAndContinue` (default) emits a log entry and lets DML proceed; `BlockDml` halts the save. See [Failure-action strategies](#failure-action-strategies). |
| `Event__c`                         | Picklist (Required)                       | [Trigger event](https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_triggers_order_of_execution.htm): Before Insert, After Insert, Before Update, After Update, Before Delete, After Delete, After Undelete |
| `TriggerSetting__c`                | MetadataRelationship(TriggerSetting__mdt) | Link to the parent TriggerSetting for the target SObject                                                                                                                                                                              |
| `Order__c`                         | Number(4,0)                               | Execution order (lower = earlier)                                                                                                                                                                                                     |
| `AllowRecursion__c`                | Checkbox                                  | Allow recursive execution                                                                                                                                                                                                             |
| `AllowNonSelfInitiated__c`         | Checkbox                                  | Allow execution from other triggers                                                                                                                                                                                                   |
| `BypassExecution__c`               | Checkbox                                  | Runtime bypass flag                                                                                                                                                                                                                   |
| `BypassFeatureFlag__c`             | MetadataRelationship(FeatureFlag__mdt)    | Feature Flag that bypasses this action when enabled                                                                                                                                                                                   |
| `RequiredFeatureFlag__c`           | MetadataRelationship(FeatureFlag__mdt)    | Feature Flag required for this action to run                                                                                                                                                                                          |
| `EntryCriteriaFormula__c`          | Long Text Area                            | Formula for conditional execution                                                                                                                                                                                                     |
| `EntryCriteriaContextClassName__c` | Text(100)                                 | Context class for formula evaluation (auto-detected for standard objects, API Call and API Issue)                                                                                                                                     |
| `Description__c`                   | Long Text Area                            | Required description                                                                                                                                                                                                                  |
| `ForcePerformanceLogging__c`       | Checkbox                                  | Always log performance for this action, even when Enable Trigger Performance Logging in Log Setting is off                                                                                                                            |
| `SuppressPerformanceLogging__c`    | Checkbox                                  | Never log performance for this action, even when Force Performance Logging is also ticked                                                                                                                                             |
| `PerformanceThresholdMs__c`        | Number(8,0)                               | Log a run that takes this long or longer (ms), even when Enable Trigger Performance Logging in Log Setting is off. Wins over the trigger setting threshold. Blank uses the trigger setting threshold, or Log Setting                  |

</details>

> **Validation rule:** `MutuallyExclusiveTarget` requires exactly one of `(ApexClassName__c, FlowName__c)` to be populated. A row with both populated is ambiguous; a row
> with neither has nothing to run. The deploy fails if either rule is broken.

---

## Anti-Patterns

The common mistakes that make trigger logic hard to maintain:

| Anti-Pattern                                        | Why It's Wrong                                                                     | Instead                                                                    |
|-----------------------------------------------------|------------------------------------------------------------------------------------|----------------------------------------------------------------------------|
| Inline SOQL inside a trigger action                 | Duplicates queries, makes bulk processing fragile, and bypasses selector caching   | Read through a `SEL_*` selector; share data through its cache or a caching action |
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

4. **Always set `AllowRecursion__c` deliberately** - The field defaults to `true`, which suits most actions. Set it to `false` for actions whose
   own changes can fire the same trigger again (e.g., cascade updates that write to related records), so they cannot loop.

5. **Use entry criteria to reduce processing** - Configure `EntryCriteriaFormula__c` on `TriggerAction__mdt` to skip actions when records do
   not meet conditions. This avoids unnecessary class instantiation and execution for irrelevant records.

6. **Use caching actions for shared queries** - When multiple actions need the same related data, create a dedicated caching action with a
   low `Order__c` value that queries once and stores results in a static variable. Subsequent actions read from the cache instead of re-querying.

7. **Do not bypass triggers in production without a plan** - Use `BypassExecution__c` or `BypassFeatureFlag__c` sparingly. Document why a bypass
   exists and who should have it. Prefer Feature Flag-based bypasses over metadata checkboxes so that only targeted users skip trigger logic.

8. **Test actions in isolation** - Each trigger action should have its own test class that builds records with `TST_Builder`, calls the
   action's method directly, and asserts the expected outcome. You do not need any `TriggerSetting__mdt` or `TriggerAction__mdt` setup.

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

1. Check metadata configuration. The object binding lives on the parent setting rather than on the action, so look the setting up first and then read its actions. Both reads go through a selector of your own; the later troubleshooting steps reuse these two:

> **On a managed install**, prefix the metadata types and their fields with `kern__` (`kern__TriggerAction__mdt`, `kern__Order__c`) and Apex classes with `kern.` (`kern.LOG_Builder`). A field path written as a string needs the prefix too, because the compiler cannot check it: `'kern__SObjectType__r.QualifiedApiName'`. These samples use the unprefixed names, as the rest of this guide does.
>
> The selectors read in system mode (`systemModeRequired()`) so that the read works for every user; without it, a user without access to the trigger setup records gets an error (a `QueryException`). `EntryCriteriaFormula__c` is a long text field, so these reads count against the query limit.

```apex
public with sharing class SEL_TriggerSettings extends SEL_Base
{
	public SEL_TriggerSettings()
	{
		super(TriggerSetting__mdt.SObjectType);
	}

	public override List<SObjectField> getFields()
	{
		return new List<SObjectField>{ TriggerSetting__mdt.DeveloperName, TriggerSetting__mdt.BypassExecution__c };
	}

	public override Boolean systemModeRequired()
	{
		return true;
	}

	public List<TriggerSetting__mdt> findByObjectName(String objectName)
	{
		// Custom metadata reads do not support OR, so read each way of naming the object on its own.
		// Keying the settings by Id keeps one copy of a setting that matches both ways.
		Map<Id, TriggerSetting__mdt> settingsById = new Map<Id, TriggerSetting__mdt>((List<TriggerSetting__mdt>)query
			.condition('SObjectType__r.QualifiedApiName').equals(objectName)
			.toList());
		settingsById.putAll((List<TriggerSetting__mdt>)query
			.condition(TriggerSetting__mdt.ObjectApiNameOverride__c).equals(objectName)
			.toList());

		return settingsById.values();
	}
}

public with sharing class SEL_TriggerActions extends SEL_Base
{
	public SEL_TriggerActions()
	{
		super(TriggerAction__mdt.SObjectType);
	}

	public override List<SObjectField> getFields()
	{
		return new List<SObjectField>
		{
			TriggerAction__mdt.DeveloperName,
			TriggerAction__mdt.Order__c,
			TriggerAction__mdt.Event__c,
			TriggerAction__mdt.ApexClassName__c,
			TriggerAction__mdt.FlowName__c,
			TriggerAction__mdt.BypassExecution__c,
			TriggerAction__mdt.AllowRecursion__c,
			TriggerAction__mdt.EntryCriteriaFormula__c
		};
	}

	public override Boolean systemModeRequired()
	{
		return true;
	}

	public List<TriggerAction__mdt> findBySettingsAndEvent(List<TriggerSetting__mdt> settings, String triggerEvent)
	{
		return (List<TriggerAction__mdt>)query
			.condition(TriggerAction__mdt.TriggerSetting__c).isIn(settings)
			.andCondition(TriggerAction__mdt.Event__c).equals(triggerEvent)
			.orderBy(TriggerAction__mdt.Order__c).ascending().nullsFirst()
			.orderBy(TriggerAction__mdt.DeveloperName)
			.toList();
	}
}

// Read the Account setting, then its Before Insert actions in the order the dispatcher runs them
List<TriggerSetting__mdt> settings = new SEL_TriggerSettings().findByObjectName('Account');
List<TriggerAction__mdt> actions = new SEL_TriggerActions().findBySettingsAndEvent(settings, 'Before Insert');

LOG_Builder.build().debug(String.valueOf(actions)).emitAt('TriggerDebug.checkMetadata');
```

> **What the query cannot show you:** feature-flag gating. `BypassFeatureFlag__c` and `RequiredFeatureFlag__c` are evaluated per user while the trigger runs, so an action can appear in these results and still be skipped. Causes 3 and 4 above have to be checked against the flag itself.

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

1. Query and verify order, with the two selectors from [Issue: Action Not Executing](#issue-action-not-executing):

```apex
List<TriggerSetting__mdt> settings = new SEL_TriggerSettings().findByObjectName('Account');
List<TriggerAction__mdt> actions = new SEL_TriggerActions().findBySettingsAndEvent(settings, 'Before Insert');

for(TriggerAction__mdt action : actions)
{
	String target = String.isNotBlank(action.ApexClassName__c) ? action.ApexClassName__c : 'Flow:' + action.FlowName__c;
	LOG_Builder.build().debug(action.Order__c + ': ' + target).emitAt('Troubleshooting.verifyOrder');
}
```

The selector's `ORDER BY` (`Order__c` first, nulls first, then `DeveloperName`) matches how the dispatcher itself sequences actions: lowest `Order__c` first, a blank order ahead of any number, and ties broken by developer name so the sequence never shifts between deployments.

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

When the query limit is the cause, the save fails with this error:

```text
System.LimitException: Too many SOQL queries: 101
```

A normal save may run 100 queries in total. Every trigger action on every object the save touches shares those 100,
and so does any other code in the same save. A query inside a loop over the records runs once for each record, so a
save of 200 records can use up the limit on its own.

Trigger actions avoid this in two ways:

- Each action gets the records as one list (up to 200 at a time in a record trigger), so it can run one query for the whole list.
- Several actions that need the same data can share one query. See
  [Caching with Trigger Actions](#caching-with-trigger-actions).

This error always stops the save, whatever the action's Failure Action says.

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

	public void beforeUpdate(List<Account> newAccounts, List<Account> oldAccounts)
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
	public void beforeUpdate(List<Account> newAccounts, List<Account> oldAccounts)
	{
		for(Account account : newAccounts)
		{
			List<Contact> contacts = TRG_CacheContacts.getCached(account.Id); // No query!
		}
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

With the two selectors from [Issue: Action Not Executing](#issue-action-not-executing):

```apex
List<TriggerSetting__mdt> settings = new SEL_TriggerSettings().findByObjectName('Account');
List<TriggerAction__mdt> actions = new SEL_TriggerActions().findBySettingsAndEvent(settings, 'Before Insert');

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
