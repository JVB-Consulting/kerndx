---
navOrder: 36
---

# Feature Flags - Guide

**Framework:** KernDX
**Package Type:** Managed Package

**Target Audience:**

- **Developers** - Branching code paths on runtime flags, targeting features to user segments, and testing both paths
- **Architects** - Designing rollout strategies, kill switches, and configuration-driven feature control
- **Business Analysts** - Toggling features and configuring targeting rules through Custom Metadata, no deployment

---

## In one paragraph

Sometimes you want to ship a feature to production but keep it switched off, then turn it on for a few users, then for everyone, all without redeploying code. A feature flag does exactly that: it is a runtime on/off switch that your Apex, Flow, and Lightning component code reads to decide whether a piece of behaviour runs. You flip the switch by editing a record in Setup, and the next transaction sees the change. Read this guide if you build features that need a gradual rollout, an instant off-switch in an incident, or different behaviour for different user groups. Reach for it whenever "should this run?" is a decision you want to control after deployment, not bake into compiled code.

---

## Table of Contents

<details>
<summary>Expand</summary>

1. [Quick Navigation](#quick-navigation)
2. [Overview](#overview)
3. [Quick Start](#quick-start)
4. [How to opt out](#how-to-opt-out)
5. [Architecture](#architecture)
    - [How a Flag Is Defined](#how-a-flag-is-defined)
    - [The Custom Metadata Behind a Flag](#the-custom-metadata-behind-a-flag)
    - [Evaluation Order](#evaluation-order)
6. [Defining a Flag](#defining-a-flag)
    - [FeatureFlag__mdt Fields](#featureflag__mdt-fields)
    - [Create a Flag with the CLI](#create-a-flag-with-the-cli)
    - [Create a Flag in Setup](#create-a-flag-in-setup)
7. [Evaluating a Flag in Apex](#evaluating-a-flag-in-apex)
    - [Running-User Check](#running-user-check)
    - [Specific-User Check](#specific-user-check)
    - [Check by Username](#check-by-username)
8. [Scoping a Flag with Strategies](#scoping-a-flag-with-strategies)
    - [FeatureFlagStrategy__mdt Fields](#featureflagstrategy__mdt-fields)
    - [Strategy Types](#strategy-types)
    - [ExpectedValue and the Three Outcomes](#expectedvalue-and-the-three-outcomes)
    - [Custom Permission Target Formats](#custom-permission-target-formats)
    - [Multiple Strategies and Order](#multiple-strategies-and-order)
9. [Custom Strategy Handlers](#custom-strategy-handlers)
    - [INT_FeatureFlagStrategy](#int_featureflagstrategy)
    - [INT_UserAwareFeatureFlagStrategy](#int_userawarefeatureflagstrategy)
    - [Wiring a Handler to a Flag](#wiring-a-handler-to-a-flag)
10. [Evaluating a Flag in Flows](#evaluating-a-flag-in-flows)
11. [Evaluating a Flag in LWC](#evaluating-a-flag-in-lwc)
12. [Framework-Owned Flags](#framework-owned-flags)
13. [Performance and SOQL Cost](#performance-and-soql-cost)
14. [Testing Flags](#testing-flags)
    - [Seeding a Flag In-Memory](#seeding-a-flag-in-memory)
    - [Testing the Disabled Path](#testing-the-disabled-path)
    - [Testing a Custom Handler](#testing-a-custom-handler)
15. [Best Practices](#best-practices)
16. [Common Pitfalls](#common-pitfalls)
17. [Related Documentation](#related-documentation)

</details>

---

## Quick Navigation

| I am a...     | I need to...                            | Go to...                                                          |
|---------------|-----------------------------------------|-------------------------------------------------------------------|
| **Developer** | Branch code on a flag                   | [Evaluating a Flag in Apex](#evaluating-a-flag-in-apex)           |
| **Developer** | Target a feature to specific users      | [Scoping a Flag with Strategies](#scoping-a-flag-with-strategies) |
| **Developer** | Write custom targeting logic            | [Custom Strategy Handlers](#custom-strategy-handlers)             |
| **Developer** | Test both flag paths                    | [Testing Flags](#testing-flags)                                   |
| **Architect** | Understand the evaluation model         | [Architecture](#architecture)                                     |
| **Architect** | Keep flag checks cheap in loops/batches | [Performance and SOQL Cost](#performance-and-soql-cost)           |
| **Analyst**   | Toggle a feature without code           | [Defining a Flag](#defining-a-flag)                               |

---

## Overview

The switch is stored as a Custom Metadata record. Your code asks the framework "is this feature enabled?" and branches on the answer. Because the answer comes from a record you can edit, not from compiled code, you change the behaviour without a deployment.

When you call the framework from your own org, use the `kern` namespace prefix exactly as shown throughout this guide (for example, [`kern.UTIL_FeatureFlag.isEnabled(...)`](reference/apex/UTIL_FeatureFlag.md)). The framework is delivered as a managed package, and that prefix is how your code reaches it.

The system has two pieces of Custom Metadata and one entry-point class:

1. **[`FeatureFlag__mdt`](reference/metadata/FeatureFlag__mdt.md)** - Defines the flag and its default behaviour.
2. **[`FeatureFlagStrategy__mdt`](reference/metadata/FeatureFlagStrategy__mdt.md)** - Optional child records that
   target the flag to specific users, profiles, permissions, groups, or configuration values.
3. **[`UTIL_FeatureFlag`](reference/apex/UTIL_FeatureFlag.md)** - The class your code calls. Its `isEnabled(...)`
   methods read the metadata and return a `Boolean`.

> **Step-by-step walkthrough:** [Fast Start - Feature Flags](Fast%20Start%20-%20Feature%20Flags.md) builds a working
> pricing service that branches on a flag, with tests for both paths, in about 25 minutes. This Guide is the deep
> reference behind that Fast Start.

**Key Benefits:**

- **No deployment to toggle.** Flip a Custom Metadata record in Setup and the next transaction sees the change, so you can react in minutes instead of waiting for a release.
- **Safe by default.** A flag that does not exist returns `false`, so your code never breaks because a flag has not been created yet.
- **Targeted rollout.** Strategies enable a feature for one profile, permission set, public group, or any logic you write, instead of for everyone at once, so you can pilot before going wide.
- **One source of truth.** Apex, Flows, and LWC all resolve the same flag through the same evaluation path, so a flag means the same thing everywhere.
- **Kill switches.** A kill switch is a master off-switch you can flip in an incident without a deployment. Deactivate a flag to disable a feature instantly across the whole org.

> **Responsibilities:** Feature flags decide *whether* a code path runs. They do not contain the feature logic itself, query data, or perform DML (database create/read/update/delete). That work belongs in your service classes, trigger actions, or DML operations. A flag is a switch, not a behaviour.

> **When NOT to use this pattern:**
> - Hard authorization gates that must enforce on the server. A flag shapes behaviour; it is not a substitute for object and field permission checks (CRUD/FLS), record sharing, or permission checks on a protected operation.
> - Static configuration that never changes at runtime. A plain Custom Metadata or Custom Setting record is simpler when there is no on/off decision to make.

---

## Quick Start

Check a flag for the running user from anywhere in Apex:

```apex
if(kern.UTIL_FeatureFlag.isEnabled('New_Pricing_Engine'))
{
	// New behaviour
}
else
{
	// Existing behaviour
}
```

If `New_Pricing_Engine` does not exist, or exists but is inactive, the call returns `false` and the `else`
branch runs. To turn the feature on, create (or activate) the `FeatureFlag__mdt` record, as covered in
[Defining a Flag](#defining-a-flag).

For deeper coverage, continue reading the sections below.

---

## How to opt out

You are never locked into the framework. Feature flags are opt-in: the `kern.UTIL_FeatureFlag.isEnabled(...)` call is a convenience over reading Custom Metadata yourself, and nothing forces you through it. When the framework does not fit your case, the plain Salesforce building blocks are always available, and the table below points you at the right one.

| You need                                     | Use                                                                                                                        | See                                                                   |
|----------------------------------------------|----------------------------------------------------------------------------------------------------------------------------|-----------------------------------------------------------------------|
| **A plain on/off value with no targeting**   | A `Boolean` field on your own `FeatureFlag__mdt` record read directly, or your own Custom Metadata / Custom Setting.       | [How a Flag Is Defined](#how-a-flag-is-defined)                       |
| **Zero-SOQL config reads in a tight loop**   | A `CustomHandler__c` strategy that calls your typed `MyCS__c.getInstance(...)`. This reads from the platform cache, so it costs no SOQL.                 | [Performance and SOQL Cost](#performance-and-soql-cost)               |
| **A package-permission check, nothing else** | `FeatureManagement.checkPermission('YourPermission')` directly. This is the platform API the framework uses for the running user. | [Custom Permission Target Formats](#custom-permission-target-formats) |
| **A flag value on the client**               | The `isFlagEnabled(flagName)` bridge from `c/featureFlag` (UX-shaping only, not authorization).                            | [Evaluating a Flag in LWC](#evaluating-a-flag-in-lwc)                 |

The flag layer is a productivity convenience, not a wall. Reach for it when its features pay off, and skip it when they do not.

---

## Architecture

### How a Flag Is Defined

Start with the simplest case: a switch that is either on or off for everyone. That is one [`FeatureFlag__mdt`](reference/metadata/FeatureFlag__mdt.md) record. The record's `DeveloperName` (its API Name) is the string you pass to `isEnabled(...)`, and the `IsEnabledByDefault__c` checkbox decides whether the switch is on. With no child records, that is all there is to it.

When you want the feature on for only some users, not everyone, you add targeting. Attach one or more [`FeatureFlagStrategy__mdt`](reference/metadata/FeatureFlagStrategy__mdt.md) child records. Each strategy describes a condition (a profile, a permission, a group, a configuration value, or custom Apex), and the framework checks that condition against the user being evaluated.

```text
┌─────────────────────────────────────────────────────────────────────┐
│                      FEATURE FLAG EVALUATION                         │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│   Your code:  kern.UTIL_FeatureFlag.isEnabled('My_Flag')            │
│                          │                                          │
│                          ▼                                          │
│   ┌──────────────────────────────────────────────────────────────┐ │
│   │  FeatureFlag__mdt  ("My_Flag")                                │ │
│   │  - IsActive__c, IsEnabledByDefault__c, ResultOnNoMatch__c    │ │
│   └───────────────────────────────┬──────────────────────────────┘ │
│                                   │ has 0..many                     │
│                                   ▼                                 │
│   ┌──────────────────────────────────────────────────────────────┐ │
│   │  FeatureFlagStrategy__mdt  (Profile / Custom Permission /     │ │
│   │  Public Group / Permission Set Group / Custom Setting /       │ │
│   │  Custom Metadata / Custom Handler)                            │ │
│   │  - evaluated in Order__c ascending, first definitive wins    │ │
│   └───────────────────────────────┬──────────────────────────────┘ │
│                                   │                                 │
│                                   ▼                                 │
│                          Boolean (true / false)                    │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

### The Custom Metadata Behind a Flag

You manage both objects the same way you manage any Custom Metadata Type: edit records in Setup, or deploy them as source. The framework reads them at runtime, so you never write Apex to populate them.

- [`FeatureFlag__mdt`](reference/metadata/FeatureFlag__mdt.md) holds one record per flag. Its fields are `IsActive__c`, `IsEnabledByDefault__c`, `ResultOnNoMatch__c`, and `Description__c`.
- [`FeatureFlagStrategy__mdt`](reference/metadata/FeatureFlagStrategy__mdt.md) holds zero or more records per flag, each pointing back to its parent flag through `FeatureFlag__c`. Its fields are `Type__c`, `Target__c`, `ExpectedValue__c`, `Order__c`, `IsActive__c`, and `CustomHandler__c`.

### Evaluation Order

When you ask "is this flag on?", the framework works through the flag and its strategies in a fixed order, and the first clear answer wins. Knowing that order tells you exactly why any flag returned the value it did. One rule shapes the whole thing: only **active** flags and **active** strategies are loaded, so an inactive flag is never found and returns `false`.

```text
1. Flag not found (missing or IsActive__c = false)  → return false (safe default / kill switch)
2. Flag found, no active strategies                 → return IsEnabledByDefault__c
3. Flag found, active strategies exist — evaluate each by Order__c ascending:
     - first strategy that matches and is satisfied  → return true
     - first strategy that matches but is NOT satisfied → return false
     - no strategy applies to this user               → return ResultOnNoMatch__c
```

The "first definitive result wins" rule is why `Order__c` matters: a strategy that returns a clear `true` or `false` match stops the rest from running. A strategy that does not apply (for example, a Profile strategy whose target profile does not match the user) is skipped, and evaluation moves on to the next strategy.

---

## Defining a Flag

### FeatureFlag__mdt Fields

| Field                   | Type       | Purpose                                                                                                          |
|-------------------------|------------|------------------------------------------------------------------------------------------------------------------|
| `DeveloperName`         | (built-in) | The API Name you pass to `isEnabled(...)`. This is the flag's identity.                                          |
| `IsActive__c`           | Checkbox   | When unchecked, the flag is left out of evaluation entirely (this is the master off-switch). `isEnabled(...)` returns `false`. |
| `IsEnabledByDefault__c` | Checkbox   | The result when the flag has no active strategies. `true` = on for everyone; `false` = off for everyone.         |
| `ResultOnNoMatch__c`    | Checkbox   | The result when active strategies exist but none apply to the user being checked.                                |
| `Description__c`        | Text Area  | Document the flag's purpose so other developers and admins know what it controls.                                |

The simplest flag has `IsActive__c = true`, `IsEnabledByDefault__c = true`, and no strategies: on for everyone. To turn it off for the whole org, uncheck `IsActive__c` (the master off-switch) or uncheck `IsEnabledByDefault__c`.

### Create a Flag with the CLI

A flag record is a `.md-meta.xml` file under `customMetadata/`. Replace `YourOrgAlias` with your org alias.

```bash
sf project deploy start -o YourOrgAlias \
  -m "CustomMetadata:kern__FeatureFlag.New_Pricing_Engine" --ignore-conflicts
```

The record file sets the package-namespaced fields:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<CustomMetadata xmlns="http://soap.sforce.com/2006/04/metadata" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema">
	<label>New Pricing Engine</label>
	<protected>false</protected>
	<values>
		<field>kern__IsActive__c</field>
		<value xsi:type="xsd:boolean">true</value>
	</values>
	<values>
		<field>kern__IsEnabledByDefault__c</field>
		<value xsi:type="xsd:boolean">true</value>
	</values>
</CustomMetadata>
```

The [Fast Start - Feature Flags](Fast%20Start%20-%20Feature%20Flags.md#create-the-flag-and-try-again) guide
includes copy-paste blocks for both Windows (PowerShell) and macOS/Linux (bash) that create this file for you.

### Create a Flag in Setup

Prefer the UI? Go to **Setup > Custom Metadata Types > Feature Flag > Manage Records > New**:

- **Label:** `New Pricing Engine`
- **Feature Flag Name:** `New_Pricing_Engine` (this becomes the `DeveloperName` you pass to `isEnabled`)
- **Is Active:** checked
- **Is Enabled By Default:** checked

Save, and the next transaction that calls `isEnabled('New_Pricing_Engine')` returns `true`.

---

## Evaluating a Flag in Apex

You want your Apex to take one path when a feature is on and another when it is off. The [`UTIL_FeatureFlag`](reference/apex/UTIL_FeatureFlag.md) class gives you three ways to ask the question, depending on *which* user you are asking about. All three return a `Boolean`, and all three return `false` when the flag is missing or inactive, so the off path is always the safe default.

### Running-User Check

This is the common case: evaluate the flag for whoever is executing the current transaction.

```apex
if(kern.UTIL_FeatureFlag.isEnabled('Enhanced_Account_Processing'))
{
	performEnhancedValidation(account);
}
```

### Specific-User Check

Sometimes the user you care about is not the one running the code. A batch job processes other users' records, a platform-event handler runs as the automated user, or a Transaction Security policy fires under a system context while the event belongs to someone else. For those cases, pass the user's `Id` and the framework evaluates the flag for that user. The call returns `false` when `userId` is blank.

```apex
// Evaluate the flag for each user being processed, not for the batch's running user.
for(User user : usersToProcess)
{
	if(kern.UTIL_FeatureFlag.isEnabled('Premium_Feature', user.Id))
	{
		grantPremiumAccess(user);
	}
}
```

A Transaction Security policy must check the **event** user, not the policy's system context:

```apex
global class BlockLargeExportPolicy implements TxnSecurity.EventCondition
{
	public Boolean evaluate(SObject event)
	{
		ReportEvent reportEvent = (ReportEvent)event;

		// Check the flag for the user who triggered the event.
		if(kern.UTIL_FeatureFlag.isEnabled('Block_Large_Export', reportEvent.UserId))
		{
			return reportEvent.RowsProcessed > 10000;
		}
		return false;
	}
}
```

All built-in strategy types fully support specific-user evaluation. A custom handler receives the user only if it implements [`INT_UserAwareFeatureFlagStrategy`](#int_userawarefeatureflagstrategy). A handler that implements only `INT_FeatureFlagStrategy` falls back to evaluating the running user instead.

### Check by Username

When you have a username (typically the email-format login) rather than a record `Id`, pass that instead. The framework looks the user up first, then evaluates the flag for them. It returns `false` if no user matches the username.

```apex
Boolean enabled = kern.UTIL_FeatureFlag.isEnabled('Premium_Feature', 'john.doe@company.com');
```

---

## Scoping a Flag with Strategies

You rarely want a feature on for absolutely everyone the moment you turn it on. More often you want it on for one team, one profile, or a beta group first. A plain flag is all-or-nothing (it just reads `IsEnabledByDefault__c`). To narrow a feature to a *subset* of users, attach one or more [`FeatureFlagStrategy__mdt`](reference/metadata/FeatureFlagStrategy__mdt.md) child records, each describing who should get the feature.

### FeatureFlagStrategy__mdt Fields

| Field              | Purpose                                                                                                         |
|--------------------|-----------------------------------------------------------------------------------------------------------------|
| `FeatureFlag__c`   | The `DeveloperName` of the parent `FeatureFlag__mdt` record this strategy belongs to.                           |
| `Type__c`          | Which built-in strategy to run (see [Strategy Types](#strategy-types)). Ignored when `CustomHandler__c` is set. |
| `Target__c`        | The strategy's target: a permission name, profile name, group name, or a `Object.Record.Field` path.           |
| `ExpectedValue__c` | Optional. The value the target must equal for the strategy to be satisfied (see below).                         |
| `Order__c`         | Evaluation order, ascending. The first strategy to return a definitive result wins.                             |
| `IsActive__c`      | When unchecked, the strategy is excluded from evaluation.                                                       |
| `CustomHandler__c` | Optional. The name of an Apex class implementing a custom strategy interface. Overrides `Type__c`.              |

### Strategy Types

The framework ships seven built-in strategy types. The `Type__c` value is the exact string in the second column.

| Strategy                    | `Type__c` value               | `Target__c` example                   | Use case                        |
|-----------------------------|-------------------------------|---------------------------------------|---------------------------------|
| Custom Permission           | `Custom Permission`           | `Edit_Confidential_Records`           | Permission-based rollout        |
| Permission Set Group        | `Permission Set Group`        | `Sales_Team`                          | Team-based rollout              |
| Profile                     | `Profile`                     | `System Administrator`                | Profile-scoped features         |
| Public Group                | `Public Group`                | `Beta_Testers`                        | Opt-in beta programs            |
| Hierarchical Custom Setting | `Hierarchical Custom Setting` | `My_Settings__c.Enable_Feature__c`    | Org / profile / user precedence |
| List Custom Setting         | `List Custom Setting`         | `My_Settings__c.RecordName.Enable__c` | Named configuration record      |
| Custom Metadata             | `Custom Metadata`             | `My_Config__mdt.RecordName.Enable__c` | Configuration-driven flags      |

For the Custom Metadata, List Custom Setting, and Hierarchical Custom Setting strategies, `Target__c` is a dotted path that points at a field. The framework reads that field's value and compares it against `ExpectedValue__c`. The Hierarchical Custom Setting strategy follows the standard Salesforce precedence when picking the value: a user-level setting wins over a profile-level one, which wins over the org-level default.

### ExpectedValue and the Three Outcomes

Every strategy resolves to one of three outcomes, and these outcomes drive the
[evaluation order](#evaluation-order):

- **Match true:** the strategy applies and its condition is satisfied. `isEnabled(...)` returns `true`
  immediately.
- **Match false:** the strategy applies but its condition is *not* satisfied. `isEnabled(...)` returns `false`
  immediately.
- **No match:** the strategy does not apply to this user (for example, a Profile strategy whose target profile
  does not match). Evaluation continues to the next strategy, and if none apply, the flag falls back to
  `ResultOnNoMatch__c`.

`ExpectedValue__c` controls how a found condition maps to those outcomes:

- **Left blank** for membership-style strategies (Custom Permission, Profile, Public Group, Permission Set
  Group): if the user *has* the permission, profile, or membership, the result is match true; if not, the result
  is no match (so evaluation continues).
- **Set to `true` or `false`** to assert an exact expectation. If the actual condition equals the expected value
  the result is match true; otherwise match false. This lets you write "enabled when the user is *not* in this
  group" by setting `ExpectedValue__c = false`.
- **For value-reading strategies** (Custom Metadata, the two Custom Setting types): `ExpectedValue__c` is the
  value the field must equal. The comparison is type-aware: `'true'` matches a Boolean `true`, `'5'` matches a
  numeric `5` or `5.0`, and string comparison ignores case. A blank `ExpectedValue__c` reads the field
  value as a Boolean.

### Custom Permission Target Formats

When the Custom Permission strategy looks up `Target__c`, it checks your own org's permissions first. Most custom permissions in your org are ones you created, so a name with no prefix is treated as a local permission you own. You add a prefix only when you want to point at a permission from the package or another namespace.

| `Target__c` format          | Resolves to                                             | Example                     |
|-----------------------------|---------------------------------------------------------|-----------------------------|
| `PermissionName`            | A local custom permission you created in your own org   | `Edit_Confidential_Records` |
| `core.PermissionName`       | A package (KernDX) custom permission, by explicit alias | `core.Admin_Access`         |
| `namespace__PermissionName` | A fully-qualified namespaced permission                 | `acme__Beta_Access`         |

For the **running user**, namespaced and `core.`-prefixed permissions resolve through `FeatureManagement.checkPermission()` with zero SOQL. A permission with no prefix (one local to your org) always costs one SOQL, because the package cannot see your org's local permissions through `FeatureManagement` and has to query for them. See [Performance and SOQL Cost](#performance-and-soql-cost).

### Multiple Strategies and Order

When a flag carries several strategies, they evaluate in `Order__c` ascending and the first clear result wins. Put your most specific rule first and your broadest rule last. For example, place a deny rule (`ExpectedValue__c = false` on a specific group) ahead of a broad allow rule, so the specific case is decided before the general one ever runs.

---

## Custom Strategy Handlers

Some targeting rules are too specific for the built-in strategies: a percentage rollout, a time window, a region check. For those, you write your own logic in an Apex class (a custom handler) and point a strategy at it with `CustomHandler__c`. Once `CustomHandler__c` is filled in, `Type__c` is ignored and only your handler runs.

> **Naming convention:** The strategy interface is `kern.UTIL_FeatureFlag.INT_FeatureFlagStrategy`. Note the `INT_` prefix: interfaces nested inside a `UTIL_*` class use `INT_*`, while top-level framework interfaces use `IF_*`. This is a deliberate codebase convention.

> **Declare the class `global`.** The package finds your handler by name at runtime and can only see classes you have declared `global`. A handler declared `public` fails with a "Type is not visible" error, so declare it `global with sharing`. (If you would rather keep it `public`, register it with the Type Resolver, which is how you tell the framework where to find your Apex classes: see [Type Resolution](Utilities%20-%20Guide.md#type-resolution-util_typeresolver).)

### INT_FeatureFlagStrategy

Use this interface when your logic only needs to look at the running user. It has one method:

```apex
Boolean isEnabled(FeatureFlag__mdt flag, FeatureFlagStrategy__mdt strategyToEvaluate);
```

A region-targeting handler that reads `Target__c` as a comma-separated country list:

```apex
/**
 * @description Enables a flag only for users whose country is in the strategy's target list.
 *
 * @author your.name@company.com
 *
 * @group Feature Flags
 *
 * @date January 2026
 */
global with sharing class FF_RegionStrategy implements kern.UTIL_FeatureFlag.INT_FeatureFlagStrategy
{
	/**
	 * @description Evaluates whether the running user's country is in the target list.
	 *
	 * @param flag The feature flag being evaluated.
	 * @param strategyToEvaluate The strategy record carrying the comma-separated country list in Target__c.
	 *
	 * @return True when the running user's country matches one of the target countries.
	 */
	public Boolean isEnabled(kern__FeatureFlag__mdt flag, kern__FeatureFlagStrategy__mdt strategyToEvaluate)
	{
		List<String> allowedCountries = strategyToEvaluate.kern__Target__c.split(',');
		return allowedCountries.contains(UserInfo.getCountry());
	}
}
```

> Inside a class in your own org, reference the package's Custom Metadata Types and their fields with the `kern`
> namespace: `kern__FeatureFlag__mdt`, `kern__Target__c`, and so on. The interface itself is
> `kern.UTIL_FeatureFlag.INT_FeatureFlagStrategy`.

### INT_UserAwareFeatureFlagStrategy

Use this interface instead when your handler needs to evaluate a **specific** user, so it behaves correctly under `isEnabled(flagName, userId)` and `isEnabled(flagName, username)`. It extends `INT_FeatureFlagStrategy`, which means you implement **both** methods. The recommended pattern is to have `isEnabled(...)` delegate to `isEnabledForUser(...)`, so the two stay in step:

```apex
Boolean isEnabledForUser(FeatureFlag__mdt flag, FeatureFlagStrategy__mdt strategyToEvaluate, Id userId);
```

```apex
global with sharing class FF_RegionStrategy implements kern.UTIL_FeatureFlag.INT_UserAwareFeatureFlagStrategy
{
	public Boolean isEnabled(kern__FeatureFlag__mdt flag, kern__FeatureFlagStrategy__mdt strategy)
	{
		return isEnabledForUser(flag, strategy, UserInfo.getUserId());
	}

	public Boolean isEnabledForUser(kern__FeatureFlag__mdt flag, kern__FeatureFlagStrategy__mdt strategy, Id userId)
	{
		User targetUser = (User)new kern.SEL_User().findById(userId);
		List<String> allowedCountries = strategy.kern__Target__c.split(',');
		return allowedCountries.contains(targetUser.Country);
	}
}
```

When `isEnabled(flagName, userId)` runs for someone other than the running user, the framework calls `isEnabledForUser(...)` with that user's `Id`. A handler that implements only `INT_FeatureFlagStrategy` would instead fall back to `isEnabled(...)`, which checks the running user. That is usually the wrong answer in a batch or policy context, where the running user is not the user you care about.

> **Errors in a handler are contained.** If a custom handler throws, the framework logs the error and treats the strategy as no match. It does not let the exception reach your `isEnabled(...)` caller, so one buggy handler cannot break the calls around it.

### Wiring a Handler to a Flag

Once your handler class exists, you connect it to a flag with a strategy record. Create a `FeatureFlagStrategy__mdt` record whose `CustomHandler__c` is the handler's class name, and set `Target__c` to whatever your handler reads (here, a country list):

| Field          | Value                |
|----------------|----------------------|
| Feature Flag   | `New_Pricing_Engine` |
| Custom Handler | `FF_RegionStrategy`  |
| Target         | `US,CA,GB`           |
| Is Active      | checked              |
| Order          | `1`                  |

Create the record at **Setup > Custom Metadata Types > Feature Flag Strategy > Manage Records > New**. While `CustomHandler__c` is populated, the `Type__c` value is ignored.

---

## Evaluating a Flag in Flows

You can branch a Flow on a feature flag the same way your Apex does, with no code. The package ships a ready-made action you drop into Flow Builder.

1. In Flow Builder, add an **Action** element.
2. Search for **Is Feature Flag Enabled** and select it.
3. Set the **featureFlagName** input to your flag's API Name (for example, `New_Pricing_Engine`).
4. Add a **Decision** element after the action and branch on the action's `isEnabled` output equal to
   `{!$GlobalConstant.True}`.

> The action's API name is `FLOW_CheckFeatureFlag`; the label shown in Flow Builder is **Is Feature Flag
> Enabled**.

---

## Evaluating a Flag in LWC

You want a Lightning component to show or hide something based on a flag. Import the `isFlagEnabled` bridge from the `c/featureFlag` module and call it. It gives you the same per-user answer your Apex sees (it runs through the `CTRL_FeatureFlag.isEnabled` cacheable Apex method) and returns a `Promise<boolean>` you await.

```javascript
import {ComponentBuilder} from 'c/componentBuilder';
import {isFlagEnabled} from 'c/featureFlag';

export default class MyComponent extends ComponentBuilder('notification')
{
	checkoutEnabled = false;

	async connectedCallback()
	{
		try
		{
			this.checkoutEnabled = await isFlagEnabled('New_Checkout_Enabled');
		}
		catch(error)
		{
			this.checkoutEnabled = false;
		}
	}
}
```

> **The bridge rejects on error; it does not silently resolve to `false`.** The Apex calls return `false` for a missing or inactive flag, but the client bridge behaves differently: when the controller errors, it *rejects* the promise instead. So wrap the call in `try/catch` (or chain `.catch()`) and fall back to your chosen default, as shown above, so a one-off failure does not leave the value unset.

Any text the component renders should come from a Custom Label, not a hardcoded string. Import labels with `import LABEL_NAME from '@salesforce/label/c.Label_Name';` so the copy stays translatable.

> **Not for client-side authorization.** `CTRL_FeatureFlag.isEnabled` is marked `@AuraEnabled(cacheable=true)`, so Salesforce may keep serving a cached result after an admin assigns or revokes a permission set that would flip the flag for that user. The cache clears on a full page reload, but not when the same wire re-fires. So use the bridge for shaping the experience (which panel to show, whether a hint is visible). For a real authorization decision, evaluate the flag inside the Apex method that performs the protected operation, where no cache can get stale. See [LWC - Guide → featureFlag Bridge](LWC%20-%20Guide.md#featureflag---feature-flag-bridge).

---

## Framework-Owned Flags

KernDX uses feature flags on itself. A small set of `FeatureFlag__mdt` records ships with the package and controls framework-wide behaviour, which gives you the same instant off-switch over the framework that you have over your own features. You do not create these flags, since they arrive with the package, but you can toggle them in Setup.

Two terms appear in the table below. A flag that runs in **USER_MODE** enforces the current user's read/write permissions and record sharing; **SYSTEM_MODE** skips all of those checks. A kill switch is the master off-switch described earlier: flip it in an incident with no deployment.

| Flag                                                                  | Purpose                                                                                                                          | Default |
|-----------------------------------------------------------------------|----------------------------------------------------------------------------------------------------------------------------------|---------|
| `UserModeQueries_Enabled`                                             | Controls the default access mode on selector queries. `true` enforces CRUD/FLS/sharing (USER_MODE); `false` runs in SYSTEM_MODE. | `true`  |
| `UserModeDml_Enabled`                                                 | Controls the default access mode on DML operations, with the same true/false meaning.                                            | `true`  |
| `MaskingFramework_Enabled`                                            | Kill switch for the data-masking framework. `true` applies masking rules before logs publish; `false` skips masking.             | `true`  |
| `AsyncChain`                                                          | Kill switch for async chain orchestration. `true` runs chains; `false` short-circuits them.                                      | `true`  |
| `DisableAllAPIs` / `DisableAllInboundAPIs` / `DisableAllOutboundAPIs` | Runtime kill switches for the web-services framework.                                                                            | `false` |
| `MockAllAPIs` / `MockAllInboundAPIs`                                  | Test-mode toggles for the web-services framework.                                                                                | `false` |

To roll one back in an emergency, edit the `FeatureFlag__mdt` record in Setup and flip `IsEnabledByDefault__c`, or uncheck `IsActive__c` to disable it entirely. The framework reads these flags itself, so your own code never references them. For how `UserModeQueries_Enabled` and `UserModeDml_Enabled` interact with the per-query `withUserMode()` and `withSystemMode()` overrides, see [Selectors - Guide → Sharing Enforcement](Selectors%20-%20Guide.md#sharing-enforcement).

---

## Performance and SOQL Cost

A flag check is cheap on a normal page, but the same check repeated thousands of times in a loop or batch can run you into SOQL limits. The cost comes from one place: the framework caches the flag-and-strategy Custom Metadata for the whole transaction, but it re-checks each strategy's *target* on every `isEnabled(...)` call. Knowing exactly where SOQL fires lets you keep flag checks free where it matters.

**Transaction-level caches (free after the first call):**

- The first `isEnabled(...)` call per transaction runs one Custom Metadata parent-child query that loads every
  active flag and its active strategies. Every later call reuses that cached map, so no further metadata SOQL fires.
- The running user's profile ID comes from `UserInfo.getProfileId()`, which costs zero SOQL.

**Per-call SOQL cost by strategy type:**

| Strategy                                                   | Running user | Other user                | Notes                                                                                              |
|------------------------------------------------------------|--------------|---------------------------|----------------------------------------------------------------------------------------------------|
| Custom Permission, namespaced (`pkg__Name`) or `core.Name` | 0            | 1                         | Running user uses `FeatureManagement.checkPermission()`.                                           |
| Custom Permission, no prefix (local to your org)            | 1            | 1                         | The package cannot see your org's local permissions through `FeatureManagement`, so it must use SOQL. |
| Profile                                                    | 1            | 1                         | Resolves the target profile by name.                                                               |
| Public Group                                               | 1            | 1                         | Group-membership lookup.                                                                           |
| Permission Set Group                                       | 1            | 1                         | Permission-set-assignment lookup.                                                                  |
| Hierarchical Custom Setting                                | 1            | 1 (+ lazy profile lookup) | Reads `SetupOwnerId IN (userId, profileId, orgId)` and picks the highest-precedence non-null.      |
| List Custom Setting                                        | 1            | 1                         | Single-record lookup by Name.                                                                      |
| Custom Metadata                                            | 1            | 1                         | Single-record lookup by DeveloperName.                                                             |
| Custom Handler                                             | depends      | depends                   | Whatever your handler does.                                                                        |

**Zero-SOQL short-circuits.** Some checks cost nothing at all: a strategy whose `Target__c` is blank or cannot be parsed; a flag with no strategies (it just returns `IsEnabledByDefault__c`); and a strategy with `CustomHandler__c` set, where the built-in type lookup is skipped and only your handler runs.

**Keeping flag checks cheap.** One SOQL per check does not matter on a single page load. It does matter inside a record loop, a trigger, or a batch, where the same check can fire once per record. Two fixes:

1. **Hoist the boolean out of the loop** when the flag value does not change per record:

   ```apex
   Boolean enabled = kern.UTIL_FeatureFlag.isEnabled('My_Flag');
   for(Record record : records)
   {
       if(enabled) { /* ... */ }
   }
   ```

2. **Use a `getInstance()`-based custom handler** when several flags read the same Custom Setting. A handler that calls your typed `MyCS__c.getInstance(...)` reads from the platform cache and costs no SOQL once it is warm. The built-in Custom Setting strategy, by contrast, issues one SOQL per check (see the per-strategy cost table above).

---

## Testing Flags

You want a test to control whether a flag is on, without depending on whatever records happen to exist in the org. That is harder than it sounds: Custom Metadata records are visible in every test, so a real `FeatureFlag__mdt` record would leak into tests you did not intend. The framework gives you an in-memory way to set flag state for a single test instead, so each test controls its own world.

### Seeding a Flag In-Memory

`kern.TST_Factory.newFeatureFlag(flagName)` registers an active flag in memory for the current test. It creates no org metadata, and the registration clears itself between tests, so one test cannot affect another.

```apex
@IsTest
private static void shouldUseNewPathWhenFlagEnabled()
{
	kern.TST_Factory.newFeatureFlag('New_Pricing_Engine');

	Test.startTest();
	Decimal result = new PricingService().calculate(100);
	Test.stopTest();

	Assert.areEqual(103, result, 'New pricing path should apply when the flag is enabled');
}
```

> **Usage:** Call `kern.TST_Factory.newFeatureFlag(String flagName)` to register the named flag as active for the
> current test.

### Testing the Disabled Path

To test the "disabled" path, you leave the flag **unregistered**. Write a test that simply does not call `newFeatureFlag(...)`, and the missing flag returns `false` by default:

```apex
@IsTest
private static void shouldUseLegacyPathWhenFlagDisabled()
{
	// No flag seeded — isEnabled(...) returns false.

	Test.startTest();
	Decimal result = new PricingService().calculate(100);
	Test.stopTest();

	Assert.areEqual(105, result, 'Legacy pricing path should apply when the flag is disabled');
}
```

If you previously created a real `FeatureFlag__mdt` record in the org with the same name, deactivate or delete it. Otherwise it is visible in tests and the "disabled" assertion fails. `newFeatureFlag(...)` is the right way to control flag state in a test, so do not deploy `FeatureFlag__mdt` records as part of your test setup.

### Testing a Custom Handler

Test your handler through `isEnabled(...)`, just as production calls it, and cover both the case where it should match and the case where it should not. Keep the flag name in one place by storing it as a `@TestVisible private static final String` constant on the class under test, so your production code and your test always use the same value.

---

## Best Practices

1. **Store flag names as constants.** A `@TestVisible private static final String` constant gives you one source
   of truth, so production code and tests reference the same name.
2. **Test both paths.** Every class that branches on a flag needs a test with the flag seeded and one without.
3. **Default new features to off.** Set `IsEnabledByDefault__c = false` for a new feature, then roll out with a
   strategy.
4. **Order strategies most-specific first.** The first definitive result wins, so place narrow deny/allow rules
   ahead of broad ones.
5. **Document the flag.** Fill in `Description__c` so the next person knows what the flag controls.
6. **Retire flags after rollout.** Once a feature is fully on, remove the flag and the branch it gated. A flag left
   behind after its rollout is dead weight that future readers have to puzzle over.
7. **Do not gate authorization on the LWC bridge.** Use `c/featureFlag` to shape the experience, and enforce real
   authorization in Apex.
8. **Keep flag checks out of tight loops.** Hoist the boolean or use a `getInstance()`-based custom handler (see
   [Performance and SOQL Cost](#performance-and-soql-cost)).

---

## Common Pitfalls

| Problem                                       | Cause                                                         | Fix                                                                                                                    |
|-----------------------------------------------|---------------------------------------------------------------|------------------------------------------------------------------------------------------------------------------------|
| `isEnabled(...)` always returns `false`       | Flag does not exist, or `IsActive__c` is unchecked            | Create the `FeatureFlag__mdt` record and check **Is Active**.                                                          |
| Flag is on for everyone but not for one user  | The strategy's `IsActive__c` is unchecked                     | Check **Is Active** on each `FeatureFlagStrategy__mdt` record.                                                         |
| A "disabled" test fails (the flag returns `true`) | A real `FeatureFlag__mdt` record exists in the org            | Deactivate or delete it; Custom Metadata is visible in all tests. Use `newFeatureFlag(...)` for the enabled path only. |
| `TST_Factory.newFeatureFlag(...)` not found   | Missing namespace prefix                                      | Call `kern.TST_Factory.newFeatureFlag('Flag_Name')`.                                                                   |
| Custom Permission strategy never matches      | Permission not assigned, or wrong target prefix               | Verify the Custom Permission → Permission Set → User assignment chain; check the `Target__c` prefix format.            |
| "Type is not visible" on a custom handler     | The handler class is declared `public` instead of `global`    | Declare it `global with sharing` so the managed package can instantiate it.                                            |
| 100-SOQL governor hit in a trigger or batch   | `isEnabled(...)` called per record with a SOQL-bound strategy | Hoist the boolean out of the loop, or move to a `getInstance()`-based custom handler.                                  |

---

## Related Documentation

- [Fast Start - Feature Flags](Fast%20Start%20-%20Feature%20Flags.md) - Hands-on, build-a-feature walkthrough with both flag paths under test
- [UTIL_FeatureFlag API Reference](reference/apex/UTIL_FeatureFlag.md) - Method-by-method API for the feature-flag utility
- [Selectors - Guide](Selectors%20-%20Guide.md#sharing-enforcement) - How `UserModeQueries_Enabled` shapes default query access mode
- [LWC - Guide](LWC%20-%20Guide.md#featureflag---feature-flag-bridge) - The `c/featureFlag` client bridge and its cache caveats
