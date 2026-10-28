---
navOrder: 38
---

# Fast Start - Feature Flags

**Framework:** KernDX | **Total time:** ~25 minutes

**What this is:** A way to switch features on and off in a live org by editing a configuration record, with no deployment and no code change. You can flip a feature for everyone, or target it by user, profile, permission, or group. **Why it exists:** Shipping a risky change behind a flag lets you turn it on for a few people first, watch how it behaves, and roll it back instantly if something goes wrong. **Who should follow this:** developers building features they want to release gradually, plus admins and tech leads who manage rollouts. **When to use it:** any time you want to release code one audience at a time, or keep a master off-switch ready for an incident.

**When the built-in option is enough:** if you only need to gate behaviour on a single Custom Permission or a Custom Setting, plain Apex (`FeatureManagement.checkPermission`, or reading the setting directly) does that without a framework. Use feature flags when you want one named switch you can re-target across permission, profile, group, and setting strategies, toggle without a deploy, and check the same way from Apex, Flow, and LWC.

> **Namespaces in code samples:** `kern.` on a class and `kern__` on an object, field, or metadata type mark the managed package's namespace.
> On the managed package, framework references need those prefixes even where a sample omits them; repackaged under your own namespace, replace `kern`/`kern__`
> with your prefix; on an unmanaged deploy, drop them. See [How to read the code samples](Installation.md#how-to-read-the-code-samples).

**What you'll build:** A pricing service that switches between legacy and new calculation logic based on a
feature flag.

**Success looks like:** Toggling a Custom Metadata record flips your code from one execution path to another, with
no deployment needed.

**In one line:** `if(kern.UTIL_FeatureFlag.isEnabled('NewPricing'))`, where one metadata record controls the
behaviour and is toggled without deployment.

## Before you start

Open your terminal in your project's top folder, the one that holds `sfdx-project.json`; on Windows that terminal is
Command Prompt. Run the four-line check on [Set Up Your Computer](Set%20Up%20Your%20Computer.md#check-you-are-ready)
once: it proves your terminal, the CLI, your login and the KernDX package, and answers what goes wrong. Done that
today? Carry on. Work in a sandbox or a scratch org, never production. Every command below writes `YourOrgAlias`
where your org's alias goes: the name you gave it when you logged in.

---

## Table of Contents

<details>
<summary>Expand</summary>

1. [Before you start](#before-you-start)
2. [Tier 1: See It Work (~2 minutes)](#tier-1-see-it-work-2-minutes)
    - [Check a feature flag](#check-a-feature-flag)
    - [Use a flag in conditional logic](#use-a-flag-in-conditional-logic)
    - [Step 1: Create the flag and try again](#step-1-create-the-flag-and-try-again)
3. [Tier 2: Build Your Own (~15-20 minutes)](#tier-2-build-your-own-15-20-minutes)
    - [Step 2: Create the service class](#step-2-create-the-service-class)
    - [Step 3: Try the service](#step-3-try-the-service)
    - [Step 4: Write and run the test](#step-4-write-and-run-the-test)
4. [Tier 3: Production Patterns (~5-10 minutes)](#tier-3-production-patterns-5-10-minutes)
    - [Framework-shipped flags you inherit automatically](#framework-shipped-flags-you-inherit-automatically)
    - [Strategy-based targeting](#strategy-based-targeting)
    - [Step 5: Add a custom permission strategy](#step-5-add-a-custom-permission-strategy)
    - [Evaluation logic](#evaluation-logic)
    - [Check flags for specific users](#check-flags-for-specific-users)
    - [Use in Flows](#use-in-flows)
    - [Use in LWC](#use-in-lwc)
    - [Package-bundled API control flags](#package-bundled-api-control-flags)
    - [Custom strategy handler](#custom-strategy-handler)
    - [Step 6: Add a custom strategy handler](#step-6-add-a-custom-strategy-handler)
    - [Clean up](#clean-up)
5. [Common Issues](#common-issues)
    - [Step 1: Create the flag and try again](#step-1-create-the-flag-and-try-again-1)
    - [Step 2: Create the service class](#step-2-create-the-service-class-1)
    - [Step 4: Write and run the test](#step-4-write-and-run-the-test-1)
    - [Step 5: Add a custom permission strategy](#step-5-add-a-custom-permission-strategy-1)
    - [Step 6: Add a custom strategy handler](#step-6-add-a-custom-strategy-handler-1)
    - [Clean up](#clean-up-1)
6. [What You Now Know](#what-you-now-know)
7. [Next Steps](#next-steps)

</details>

---

## Tier 1: See It Work (~2 minutes)

You run two short blocks of Apex to see how a flag answers, then create the flag and watch the answer change.

### Check a feature flag

**In Salesforce**, open the Developer Console (the gear icon, then Developer Console), then Debug, then Open Execute
Anonymous Window, and run:

```apex
Boolean isEnabled = kern.UTIL_FeatureFlag.isEnabled('NewPricingEngine');
System.debug('NewPricingEngine enabled: ' + isEnabled);
```

You should see this line in the log:

```text
NewPricingEngine enabled: false
```

A flag that doesn't exist returns `false`, so the behaviour is safe by default. Your code won't break if a flag hasn't been created
yet.

### Use a flag in conditional logic

**In Salesforce**, in the same Execute Anonymous window, run:

```apex
String result;

if(kern.UTIL_FeatureFlag.isEnabled('NewPricingEngine'))
{
	result = 'Using NEW pricing engine';
}
else
{
	result = 'Using LEGACY pricing engine';
}

System.debug(result);
```

You should see this line in the log:

```text
Using LEGACY pricing engine
```

### Step 1: Create the flag and try again

A flag is one configuration record. You create it in Setup, pull it into your project so it is under source control
with your code, then run the same block again.

**1. In Salesforce**, open Setup, then Custom Metadata Types, then **Feature Flag**, then **Manage Feature Flags**, then
**New**, and save a record with these values:

| Field                 | API name                      | Value                |
|-----------------------|-------------------------------|----------------------|
| Label                 | `MasterLabel`                 | `New Pricing Engine` |
| Feature Flag Name     | `DeveloperName`               | `NewPricingEngine`   |
| Is Active             | `kern__IsActive__c`           | checked              |
| Is Enabled By Default | `kern__IsEnabledByDefault__c` | checked              |

**2. In the terminal**, pull the record into your project:

```shell
sf project retrieve start -o YourOrgAlias -m "CustomMetadata:kern__FeatureFlag.NewPricingEngine"
```

You should see one file created under `force-app/main/default/customMetadata`, named after the record.

**3. In Salesforce**, run the conditional logic block again:

```apex
String result;

if(kern.UTIL_FeatureFlag.isEnabled('NewPricingEngine'))
{
	result = 'Using NEW pricing engine';
}
else
{
	result = 'Using LEGACY pricing engine';
}

System.debug(result);
```

You should see this line in the log:

```text
Using NEW pricing engine
```

You just toggled behaviour without deploying code.

Something went wrong? See [Common Issues, Step 1](#step-1-create-the-flag-and-try-again-1).

#### If you stop after Tier 1

Going on to Tier 2 and Tier 3? Keep the flag: Step 5 changes it, and the clean-up at the end of Tier 3 removes it. If
you are stopping here, delete it now.

**In the terminal**, delete the flag:

```shell
sf project delete source -o YourOrgAlias -m "CustomMetadata:kern__FeatureFlag.NewPricingEngine" --no-prompt
```

You should see `Status: Succeeded`, then a `Deleted Source` table listing the flag. The command deletes the file from
your project too.

Run the conditional logic block again and you're back to `Using LEGACY pricing engine`. This confirms the safe default:
a missing flag always returns `false`.

Something went wrong? See [Common Issues, Step 1](#step-1-create-the-flag-and-try-again-1).

> **When to move to Tier 2:** When you want to build a real service that branches on a flag, with tests covering
> both paths.

---

## Tier 2: Build Your Own (~15-20 minutes)

> **No local project?** You can create classes directly in the Developer Console (Gear Icon > Developer Console >
> File > New > Apex Class) and run tests from there too (Test > New Run). Paste the code, save, and skip the
> terminal commands.

### Step 2: Create the service class

Here is the goal: a pricing service that charges a 5% surcharge today, and a lower 3% surcharge once you turn the new pricing on. A feature flag decides which rate applies, so you can switch behaviour without redeploying the class.

You create an empty class with one command, paste the code into it, then send it to your org.

**1. In the terminal**, from your project's top folder, create the empty class:

```shell
sf apex generate class --name FastStart_FeatureFlag_DEMO --output-dir force-app/main/default/classes
```

You should see two files created in `force-app/main/default/classes`: `FastStart_FeatureFlag_DEMO.cls` and its
companion of the same name ending in `.cls-meta.xml`.

**2. In your editor**, open this file, delete what is there, paste the code below in, and save:

```text
force-app/main/default/classes/FastStart_FeatureFlag_DEMO.cls
```

```apex
/**
 * @description Drift-guard demo class for the Fast Start - Feature Flags guide. Demonstrates
 * the core flag-check pattern: branching on a feature flag to switch between legacy and new
 * pricing calculation logic.
 *
 * @see FastStart_FeatureFlag_DEMO_TEST
 *
 * @author your.name@company.com
 *
 * @group Fast Start
 *
 * @date May 2026
 */
public with sharing class FastStart_FeatureFlag_DEMO
{
	/** @description Feature flag name controlling the new pricing calculation. */
	@TestVisible private static final String FLAG_NEW_PRICING = 'FastStart_NewPricing';

	/** @description Legacy surcharge rate applied when the flag is off (5%). */
	@TestVisible private static final Decimal LEGACY_SURCHARGE = 0.05;

	/** @description New surcharge rate applied when the flag is on (3%). */
	@TestVisible private static final Decimal NEW_SURCHARGE = 0.03;

	/**
	 * @description Calculates the final amount after applying the appropriate surcharge.
	 * Branches on kern.UTIL_FeatureFlag.isEnabled to select the legacy (5%) or new (3%) rate.
	 *
	 * @param baseAmount The base amount before surcharge.
	 *
	 * @return The total amount after surcharge.
	 */
	public Decimal processWithNewPricing(Decimal baseAmount)
	{
		if(kern.UTIL_FeatureFlag.isEnabled(FLAG_NEW_PRICING))
		{
			return baseAmount + (baseAmount * NEW_SURCHARGE);
		}

		return baseAmount + (baseAmount * LEGACY_SURCHARGE);
	}
}
```

**What this code does:**

- `kern.UTIL_FeatureFlag.isEnabled(FLAG_NEW_PRICING)` reads the Feature Flag custom metadata at runtime
- When the flag is active and enabled, the new 3% surcharge applies
- When disabled (or missing), the legacy 5% surcharge applies
- The flag name is stored as a `@TestVisible` constant so the test class can reference it directly

**3. In the terminal**, send the class to your org:

```shell
sf project deploy start -o YourOrgAlias -m "ApexClass:FastStart_FeatureFlag_DEMO"
```

You should see `Status: Succeeded`, with `FastStart_FeatureFlag_DEMO` listed as created.

Something went wrong? See [Common Issues, Step 2](#step-2-create-the-service-class-1).

### Step 3: Try the service

**In Salesforce**, in the Execute Anonymous window, run:

```apex
FastStart_FeatureFlag_DEMO demo = new FastStart_FeatureFlag_DEMO();
Decimal amount = demo.processWithNewPricing(100.00);
System.debug('Amount: ' + amount);
```

You should see this line in the log (with the flag not created or inactive; Apex `Decimal` preserves scale, so the
value carries four decimal places):

```text
Amount: 105.0000
```

> **See it in the org:** Create the `FastStart_NewPricing` flag in Setup (as in Step 1) with Is Active = checked
> and Is Enabled By Default = checked, then re-run. You'll get `103.0000`. Deactivate or delete the flag and you're
> back to `105.0000`.

### Step 4: Write and run the test

The test class checks both rates: the legacy 5% when the flag is off, and the new 3% when it is on. You create the empty
class with one command, paste the code into it, send it to your org, then run it.

**1. In the terminal**, from your project's top folder, create the empty test class:

```shell
sf apex generate class --name FastStart_FeatureFlag_DEMO_TEST --output-dir force-app/main/default/classes
```

You should see two files created in `force-app/main/default/classes`: `FastStart_FeatureFlag_DEMO_TEST.cls` and its
companion of the same name ending in `.cls-meta.xml`.

**2. In your editor**, open this file, delete what is there, paste the code below in, and save:

```text
force-app/main/default/classes/FastStart_FeatureFlag_DEMO_TEST.cls
```

```apex
/**
 * @description Unit tests for FastStart_FeatureFlag_DEMO. Validates both the legacy and new
 * pricing branches at 100% coverage using the in-memory flag seeding API.
 *
 * @see FastStart_FeatureFlag_DEMO
 *
 * @author your.name@company.com
 *
 * @group Fast Start
 *
 * @date May 2026
 */
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest(isParallel=true)
private class FastStart_FeatureFlag_DEMO_TEST
{
	/** @description Base amount used across all pricing tests. */
	private static final Decimal BASE_AMOUNT = 100.00;

	/**
	 * @description Verifies the legacy surcharge (5%) is applied when the flag is not active.
	 * No flag is seeded — the missing flag returns false by default.
	 */
	@IsTest
	private static void shouldApplyLegacySurchargeWhenFlagDisabled()
	{
		Decimal result = new FastStart_FeatureFlag_DEMO().processWithNewPricing(BASE_AMOUNT);

		Decimal expected = BASE_AMOUNT + (BASE_AMOUNT * FastStart_FeatureFlag_DEMO.LEGACY_SURCHARGE);
		Assert.areEqual(expected, result, 'Should apply the legacy 5% surcharge when flag is off');
	}

	/**
	 * @description Verifies the new surcharge (3%) is applied when the flag is active.
	 * Uses kern.TST_Factory.newFeatureFlag to seed an in-memory active flag — no CMDT record
	 * is created in the org and no cleanup is needed between tests.
	 */
	@IsTest
	private static void shouldApplyNewSurchargeWhenFlagEnabled()
	{
		kern.TST_Factory.newFeatureFlag(FastStart_FeatureFlag_DEMO.FLAG_NEW_PRICING);

		Decimal result = new FastStart_FeatureFlag_DEMO().processWithNewPricing(BASE_AMOUNT);

		Decimal expected = BASE_AMOUNT + (BASE_AMOUNT * FastStart_FeatureFlag_DEMO.NEW_SURCHARGE);
		Assert.areEqual(expected, result, 'Should apply the new 3% surcharge when flag is on');
	}
}
```

> **About the annotations:** `@IsTest(isParallel=true)` allows tests to run concurrently for faster feedback.
> `@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')` suppresses a code analysis rule (the scanner that checks code without running it). In production
> tests, wrap your test logic in `System.runAs(testUser)`.

> **Test isolation:** The "disabled" test relies on the flag **not existing** in the org. If you created a
> `FastStart_NewPricing` flag via the UI or CLI, make sure it is inactive or deleted before running tests.
> Custom Metadata records are visible in every test, so use `kern.TST_Factory.newFeatureFlag()` to activate flags in test context.

> **Seeding flags in tests:** `kern.TST_Factory.newFeatureFlag('YourFlag')` seeds an active flag for the test
> in memory, so no Custom Metadata record is created in the org. To test the disabled path, simply don't seed the flag: an
> unseeded flag is treated as off.

**3. In the terminal**, send the test class to your org:

```shell
sf project deploy start -o YourOrgAlias -m "ApexClass:FastStart_FeatureFlag_DEMO_TEST"
```

You should see `Status: Succeeded`, with `FastStart_FeatureFlag_DEMO_TEST` listed as created.

**4. In the terminal**, run the test:

```shell
sf apex run test -o YourOrgAlias -t FastStart_FeatureFlag_DEMO_TEST --code-coverage --synchronous --result-format human
```

You should see 2 tests passing and full coverage on `FastStart_FeatureFlag_DEMO`: both tests show `Pass`, the summary
line `Outcome` reads `Passed`, and the coverage table shows `FastStart_FeatureFlag_DEMO` at `100%`.

Something went wrong? See [Common Issues, Step 4](#step-4-write-and-run-the-test-1).

#### Key Patterns

| Pattern                                 | Example                                                     | Why                                                                      |
|-----------------------------------------|-------------------------------------------------------------|--------------------------------------------------------------------------|
| Store flag name as constant             | `@TestVisible private static final String FLAG_NEW_PRICING` | Single source of truth; test references the same name as production code |
| Test both paths                         | One test with flag seeded, one without                      | Guarantees coverage of both execution branches                           |
| `kern.TST_Factory.newFeatureFlag(name)` | Registers an active in-memory flag                          | Resets between tests automatically; no org metadata created              |
| Log which path was taken                | `kern.LOG_Builder.build().info(...)`                        | Production debugging when flags are toggled                              |

---

## Tier 3: Production Patterns (~5-10 minutes)

### Framework-shipped flags you inherit automatically

KernDX ships a small set of framework-owned `FeatureFlag__mdt` records that you don't create or maintain yourself.
The framework reads them directly from Apex to control how it behaves across your org. Several of them act as a kill-switch: a master off-switch you can flip in an incident without a deployment. Two of them also choose whether queries and saves run with the current user's read/write permissions and record sharing enforced (USER_MODE) or skip the object and field permission checks only (SYSTEM_MODE, which leaves record sharing following the calling class). In the table below, CRUD means object create/read/update/delete permissions and FLS means field-level security.

| Flag                                                                  | Purpose                                                                                                                                                                                            | Default | Emergency Rollback                                                       |
|-----------------------------------------------------------------------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|---------|--------------------------------------------------------------------------|
| `UserModeQueries_Enabled`                                             | Controls the default `AccessLevel` on `QRY_Builder` / `SEL_Base.query`. `true` → USER_MODE (CRUD/FLS/sharing enforced); `false` → SYSTEM_MODE.                                                     | `true`  | Setup → CMDT → FeatureFlag → set `IsEnabledByDefault__c` to `false`.     |
| `UserModeDml_Enabled`                                                 | Controls the default `AccessLevel` on `DML_Builder.newTransaction()` operations. Same true/false semantics as above.                                                                               | `true`  | Same metadata flip path.                                                 |
| `MaskingFramework_Enabled`                                            | Kill-switch for the data-masking framework (`MaskingTarget__mdt` / `MaskingRule__mdt`). `true` → rules are applied before `LogEntryEvent__e` publishes; `false` → pipeline skips masking entirely. | `true`  | Same metadata flip path.                                                 |
| `AsyncChain`                                                          | Kill-switch for `UTIL_AsyncChain` orchestration. `true` → chains run; `false` → running chains stop at their next step boundary and new chains stop at once. Resolved from the `AsyncChainRuntimeSwitch__c` hierarchy setting, not from the flag record. | `true`  | Setup → Custom Settings → Async Chain Runtime Switch → Manage → untick `ChainsEnabled__c`. |
| `DisableAllInboundAPIs` / `DisableAllOutboundAPIs` / `DisableAllAPIs` | Runtime kill-switches for the web-service framework.                                                                                                                                               | `false` | These switches are off by default, so in an incident you turn them on. For `DisableAllInboundAPIs` or `DisableAllOutboundAPIs`, tick `IsEnabledByDefault__c` (leave `IsActive__c` ticked). For `DisableAllAPIs`, go to Setup, Custom Settings, API Runtime Switch, Manage, and tick `DisableAllApis__c` (see the note below). Untick the box again to restore. |
| `MockAllAPIs` / `MockAllInboundAPIs`                                  | Test-mode toggles used by `API_MockFactory`.                                                                                                                                                       | `false` | Same metadata flip path.                                                 |
| `MockSelectedAPIs`                                                    | Test-mode toggle for chosen services. For the users this flag is on for, each service whose API Setting has Mocking Enabled ticked answers with mock data, outgoing and incoming.                    | `false` | Same metadata flip path: untick `IsEnabledByDefault__c`, or switch off the strategy records you added. |

> On `AsyncChain` and `DisableAllAPIs` the answer comes from a shipped strategy record rather than from the flag itself, so editing `IsEnabledByDefault__c` on those two changes nothing.
> Flip them through their hierarchy custom settings instead: `AsyncChainRuntimeSwitch__c.ChainsEnabled__c` and `ApiRuntimeSwitch__c.DisableAllApis__c`.
> One field on the flag record still counts: with no hierarchy setting record the strategy finds no match, so the answer falls back to `ResultOnNoMatch__c`. On `AsyncChain` that means `ResultOnNoMatch__c = false` leaves chains off until someone creates the setting, with no obvious cause to point at.

> The package also ships a `TestFeatureFlag` record (`protected=true`) used by the framework's own test classes. It isn't meant for your org to use. Your org also sees
> `AsyncChainAbort_Enabled`, `AsyncChainRedrive_Enabled` and `AsyncChainKillSwitch_Enabled`, which gate the Chain Monitor's operator actions, and `BypassAudit_Enabled`, which controls
> the record the framework keeps whenever a safety check is turned off. The [Feature Flags Guide](Feature%20Flags%20-%20Guide.md#framework-owned-flags) carries the full list.

See [Security Guide, Safe by Default](Security%20-%20Guide.md#safe-by-default) for how
`UserModeQueries_Enabled` and `UserModeDml_Enabled` interact with `.withSystemMode()`, `.withUserMode()`, and
the `systemModeRequired()` hook on `SEL_Base`.

### Strategy-based targeting

Most rollouts start with a small audience, not the whole org. A **strategy** lets you turn a flag on only for the users you choose, by permission, profile, group, or setting, instead of for everyone at once. This example adds a
Custom Permission strategy to the `NewPricingEngine` flag you created in Step 1.

| Strategy Type               | Target Example                   | Use Case                         |
|-----------------------------|----------------------------------|----------------------------------|
| Custom Permission           | `Edit_Confidential_Records`      | Permission-based feature rollout |
| Permission Set Group        | `Sales_Team`                     | Team-based rollout               |
| Profile                     | `System Administrator`           | Admin-only features              |
| Public Group                | `Beta_Testers`                   | Opt-in beta programmes           |
| Hierarchical Custom Setting | `MySettings__c.EnableFeature__c` | Org/profile/user hierarchy       |
| Custom Metadata             | `Config__mdt.Setting.Field__c`   | Configuration-driven flags       |

Despite its name, the `Permission Set Group` strategy matches a permission set *or* a permission set group, whichever the user is assigned. Use a permission set's API name or a permission set group's developer name as the target.

> **SOQL cost:** the first `isEnabled(...)` call in a transaction runs one query (SOQL) that loads every active flag and its strategies. Later calls reuse that result. After that, the cost
> depends on the strategy. A strategy that checks a profile, public group, permission set, or Custom Permission without a namespace runs one query on every call. A Custom Setting or Custom
> Metadata target is read once and kept for the transaction. Three cases need no framework query: a namespaced or `core.` Custom Permission check for the running user, a strategy with a blank target or a custom handler (only
> your handler runs), and the no-strategy `IsEnabledByDefault__c` fast path. One query per call is fine for everyday synchronous code, but it adds up
> inside record loops, batches, and scheduled jobs. If you call flags in tight loops, or read several flags off the same Custom
> Setting, see [Feature Flags - Guide, Performance and SOQL Cost](Feature%20Flags%20-%20Guide.md#performance-and-soql-cost) for the per-strategy
> cost table, the pattern for reading a flag once and reusing the result, and a `getInstance()`-based custom handler that avoids the query for Custom Setting strategies.

### Step 5: Add a custom permission strategy

You turn the flag's default off, then make three records in Setup (a custom permission, a permission set that holds
it, and a strategy that targets it), pulling each into your project, and finally give yourself the permission set.

#### Step 5.1: Turn the flag's default off

With the default off, the strategy decides who gets access.

**1. In Salesforce**, open Setup, then Custom Metadata Types, then **Feature Flag**, then **Manage Feature Flags**, open
**New Pricing Engine**, click **Edit**, change this value, and save:

| Field                 | API name                      | Value     |
|-----------------------|-------------------------------|-----------|
| Is Enabled By Default | `kern__IsEnabledByDefault__c` | unchecked |

If you deleted the flag after Tier 1, create it again as in Step 1, with Is Enabled By Default unchecked.

**2. In the terminal**, pull the record again:

```shell
sf project retrieve start -o YourOrgAlias -m "CustomMetadata:kern__FeatureFlag.NewPricingEngine"
```

You should see the file under `force-app/main/default/customMetadata` named after the record, listed as `Changed`
(or `Created` if you made the flag again).

Something went wrong? See [Common Issues, Step 5](#step-5-add-a-custom-permission-strategy-1).

#### Step 5.2: Create the custom permission

**1. In Salesforce**, open Setup, then Custom Permissions, then **New**, and save one with these values:

| Field | API name        | Value                       |
|-------|-----------------|-----------------------------|
| Label | `MasterLabel`   | `New Pricing Engine Access` |
| Name  | `DeveloperName` | `NewPricingEngineAccess`    |

**2. In the terminal**, pull it into your project:

```shell
sf project retrieve start -o YourOrgAlias -m "CustomPermission:NewPricingEngineAccess"
```

You should see one file created under `force-app/main/default/customPermissions`, named after the custom permission.

Something went wrong? See [Common Issues, Step 5](#step-5-add-a-custom-permission-strategy-1).

#### Step 5.3: Create the permission set

**1. In Salesforce**, open Setup, then Permission Sets, then **New**, and save one with these values:

| Field    | API name | Value                |
|----------|----------|----------------------|
| Label    | `Label`  | `New Pricing Engine` |
| API Name | `Name`   | `NewPricingEngine`   |

Then, on the new permission set, open **Custom Permissions**, click **Edit**, add **New Pricing Engine Access** to the
enabled list, and save.

**2. In the terminal**, pull it into your project:

```shell
sf project retrieve start -o YourOrgAlias -m "PermissionSet:NewPricingEngine"
```

You should see one file created under `force-app/main/default/permissionsets`, named after the permission set.

Something went wrong? See [Common Issues, Step 5](#step-5-add-a-custom-permission-strategy-1).

#### Step 5.4: Create the strategy record

**1. In Salesforce**, open Setup, then Custom Metadata Types, then **Feature Flag Strategy**, then **Manage Feature Flag
Strategies**, then **New**, and save a record with these values:

| Field                      | API name               | Value                                  |
|----------------------------|------------------------|----------------------------------------|
| Label                      | `MasterLabel`          | `NewPricingEngine - Custom Permission` |
| Feature Flag Strategy Name | `DeveloperName`        | `NewPricingEngine_CustomPermission`    |
| Feature Flag               | `kern__FeatureFlag__c` | `NewPricingEngine`                     |
| Is Active                  | `kern__IsActive__c`    | checked                                |
| Order                      | `kern__Order__c`       | `1`                                    |
| Target                     | `kern__Target__c`      | `NewPricingEngineAccess`               |
| Type                       | `kern__Type__c`        | `Custom Permission`                    |

**2. In the terminal**, pull it into your project:

```shell
sf project retrieve start -o YourOrgAlias -m "CustomMetadata:kern__FeatureFlagStrategy.NewPricingEngine_CustomPermission"
```

You should see one file created under `force-app/main/default/customMetadata`, named after the record.

Something went wrong? See [Common Issues, Step 5](#step-5-add-a-custom-permission-strategy-1).

#### Step 5.5: Give yourself the permission set

First check the flag while you do not have the permission set, then assign it to yourself.

**1. In Salesforce**, in the Execute Anonymous window, run:

```apex
// Without the permission set — flag is disabled (IsEnabledByDefault = false, no strategy match)
Boolean before = kern.UTIL_FeatureFlag.isEnabled('NewPricingEngine');
System.debug('Before assignment: ' + before);
```

You should see this line in the log:

```text
Before assignment: false
```

**2. In the terminal**, assign the permission set to yourself:

```shell
sf org assign permset -n NewPricingEngine -o YourOrgAlias
```

You should see a `Permsets Assigned` table with one row: your username and `NewPricingEngine`.

Something went wrong? See [Common Issues, Step 5](#step-5-add-a-custom-permission-strategy-1).

#### Verify the strategy

**In Salesforce**, in the Execute Anonymous window, run:

```apex
// With the permission set — strategy matches, flag is enabled for you
Boolean after = kern.UTIL_FeatureFlag.isEnabled('NewPricingEngine');
System.debug('After assignment: ' + after);
```

You should see this line in the log:

```text
After assignment: true
```

Something went wrong? See [Common Issues, Step 5](#step-5-add-a-custom-permission-strategy-1).

The flag is now enabled only for users who have the `NewPricingEngine` permission set. Everyone else still gets
`false`.

### Evaluation logic

When you ask whether a flag is on, the framework checks a fixed sequence of conditions and stops at the first one that decides the answer. Knowing this order helps you predict what a flag will return.

**In Salesforce**, run this in the Execute Anonymous window to watch the fallback path in action:

```apex
// Path 1: Flag doesn't exist → returns false (safe default)
System.debug('Non-existent flag: ' + kern.UTIL_FeatureFlag.isEnabled('NoSuchFlag'));

// Path 2: Flag exists, IsActive = true, with a strategy → the strategy decides
System.debug('NewPricingEngine (with strategy): ' + kern.UTIL_FeatureFlag.isEnabled('NewPricingEngine'));
```

With the `NewPricingEngine` permission set assigned to you, as in Step 5, you should see these lines in the log (the
second line reads `false` if you do not hold the permission set):

```text
Non-existent flag: false
NewPricingEngine (with strategy): true
```

The full evaluation flow:

```text
1. IsActive = false?           → return false (kill switch)
2. No strategies defined?      → return IsEnabledByDefault
3. Strategies exist (checked in Order__c order; the first definitive result wins):
   - First strategy match true → return true
   - First strategy match false → return false
   - No strategy matches       → return ResultOnNoMatch
```

### Check flags for specific users

Sometimes the user you care about isn't the one running the code: a batch job, a platform event, or a security policy may act on behalf of someone else. For those cases, pass a specific user (by Id or username) so the flag is evaluated against that person, not the running user.

**In Salesforce**, in the Execute Anonymous window, run:

```apex
// Check for a specific user by ID
Id userId = UserInfo.getUserId();
Boolean enabledForUser = kern.UTIL_FeatureFlag.isEnabled('NewPricingEngine', userId);
System.debug('Enabled for ' + UserInfo.getName() + ': ' + enabledForUser);

// Check by username
Boolean enabledByUsername = kern.UTIL_FeatureFlag.isEnabled('NewPricingEngine', UserInfo.getUserName());
System.debug('Enabled for ' + UserInfo.getUserName() + ': ' + enabledByUsername);
```

You should see lines like these in the log (they vary with your name, username and permission set assignment):

```text
Enabled for Admin User: true
Enabled for admin@example.com: true
```

### Use in Flows

Use the **Is Feature Flag Enabled** invocable action to check flags in Flows:

1. Open **Setup > Flows > New Flow > Screen Flow** (or edit an existing Flow)
2. Add an **Action** element
3. In the Action search box, type **Is Feature Flag Enabled** and select it
4. Set the **Label** to `Check Pricing Engine Flag`
5. Set the **flagNames** input to the text value `NewPricingEngine`
6. Click **Done**
7. Add a **Decision** element after the action:
    - **Label:** `Is Flag Enabled?`
    - **Outcome 1 Label:** `Flag Enabled`
    - **Condition:** `{!Check_Pricing_Engine_Flag}` (the action's own true/false output) **Equals** `{!$GlobalConstant.True}`
    - **Default Outcome Label:** `Flag Disabled`
8. Add different logic in each branch (e.g., different screens or assignments)
9. **Save** and **Activate** the Flow

> **Note:** The invocable action name in the API is `FLOW_CheckFeatureFlag`. The label shown in the Flow
> Builder UI is **Is Feature Flag Enabled**.

A user who is not a System Administrator and runs a screen flow with this action needs access to the Apex class behind it: assign the **Kern Component Access**
permission set, or add Apex class access for `kern.FLOW_CheckFeatureFlag` to a permission set they already have.

### Use in LWC

You can check the same flags from a Lightning component, so the screen shows or hides parts of the page to match what your Apex code does. Import `kern/featureFlag`
and call `isFlagEnabled(flagName)` to read the same result your Apex code sees. The module ships inside the managed package, so you import it from `kern/`, not `c/`;
the same rule applies to every KernDX module (see [The namespace gotcha](Fast%20Start%20-%20LWC.md#the-namespace-gotcha) in the LWC Fast Start).

**In your editor**, in your component's JavaScript file:

```javascript
import {ComponentBuilder} from 'kern/componentBuilder';
import {isFlagEnabled} from 'kern/featureFlag';

export default class MyComponent extends ComponentBuilder('notification')
{
	checkoutEnabled = false;

	async connectedCallback()
	{
		try
		{
			this.checkoutEnabled = await isFlagEnabled('NewPricingEngine');
		}
		catch(error)
		{
			this.checkoutEnabled = false;
		}
	}
}
```

The user who opens a page that uses this module needs access to the Apex class behind it. Without it, the page fails with "You do not have access to the Apex class
named 'CTRL_FeatureFlag'". Users with the System Administrator profile or the **Kern Administrator** permission set already have that access. For everyone else,
assign the **Kern Component Access** permission set, which grants the classes behind the package's components and modules (this one included) and nothing more, or
add Apex class access for `kern.CTRL_FeatureFlag` (the name Setup shows under Apex Class Access) to a permission set they already have.

Behind the scenes this calls `CTRL_FeatureFlag.isEnabled` (`@AuraEnabled(cacheable=true)`), so a component sees the same per-user
result your Apex sees. One caution: because the result is cached on the client, it can be briefly out of date after you assign or
remove a permission set that changes a flag for the running user. The cache refreshes on a page reload, but not when
a `@wire` simply re-fires. So use this to shape the user experience (showing or hiding a panel or section), not to decide whether someone is
allowed to do something. Treat real authorisation in Apex. See [LWC Guide, Feature Flag Bridge](LWC%20-%20Guide.md) for the full caveats.

### Package-bundled API control flags

KernDX ships with API control flags, all disabled by default. They are part of the [framework-shipped flags](#framework-shipped-flags-you-inherit-automatically) listed
earlier, and they specifically control the web services framework:

| Flag                     | Purpose                                |
|--------------------------|----------------------------------------|
| `DisableAllAPIs`         | Kill switch for all API calls          |
| `DisableAllInboundAPIs`  | Disable inbound API processing         |
| `DisableAllOutboundAPIs` | Disable outbound API calls             |
| `MockAllAPIs`            | Return mock responses for all APIs     |
| `MockAllInboundAPIs`     | Return mock responses for inbound APIs |
| `MockSelectedAPIs`       | Return mock responses only for the APIs whose API Setting has Mocking Enabled ticked, inbound and outbound |

These work with the web services framework automatically, with no code needed.

**In Salesforce**, check their state from the Execute Anonymous window:

```apex
// These are pre-packaged flags — check their current state
System.debug('DisableAllAPIs: ' + kern.UTIL_FeatureFlag.isEnabled('DisableAllAPIs'));
System.debug('MockAllAPIs: ' + kern.UTIL_FeatureFlag.isEnabled('MockAllAPIs'));
```

You should see these lines in the log:

```text
DisableAllAPIs: false
MockAllAPIs: false
```

**In your editor**, to use these in tests, activate them with `TST_Factory` in a test method:

```apex
// In a @IsTest method:
kern.TST_Factory.newFeatureFlag('DisableAllAPIs');
// All API calls in this test will be disabled
```

### Custom strategy handler

The built-in strategy types (permission, profile, group, and so on) cover most rollouts. When your "who gets this flag" rule is more involved, for example matching on a user's locale or a value from another record, you write a small Apex class that decides, and point a strategy at it.

> **Naming convention:** The strategy interface is `kern.UTIL_FeatureFlag.INT_FeatureFlagStrategy`. Note the
> `INT_*` prefix, not `IF_*`. Top-level framework interfaces use the `IF_*` prefix, while inner interfaces nested inside
> `UTIL_*` classes use the `INT_*` prefix. This is a deliberate codebase convention, so don't rename it.

> **Why `global`?** Declaring the class `global` lets the framework find and create it at runtime with no extra setup.
> If you prefer `public with sharing`, you'll need a Type Resolver class, which is how the framework finds the Apex classes in your namespace: you tell it where to look. The Kern home page health check
> provides that code, or see [Type Resolution](Utilities%20-%20Guide.md#type-resolution-util_typeresolver).

### Step 6: Add a custom strategy handler

You write the handler class, point a second strategy at it, then check which strategy decides.

#### Step 6.1: Create the handler class

You create an empty class with one command, paste the code into it, then send it to your org.

**1. In the terminal**, from your project's top folder, create the empty class:

```shell
sf apex generate class --name MY_RegionStrategy --output-dir force-app/main/default/classes
```

You should see two files created in `force-app/main/default/classes`, both named `MY_RegionStrategy`: the class, ending
in `.cls`, and its companion, ending in `.cls-meta.xml`.

**2. In your editor**, open this file, delete what is there, paste the code below in, and save:

```text
force-app/main/default/classes/MY_RegionStrategy.cls
```

```apex
/**
 * @description Custom strategy handler that enables a flag based on the user's locale.
 *
 * @author your.name@company.com
 *
 * @group Feature Flags
 *
 * @date May 2026
 */
global with sharing class MY_RegionStrategy implements kern.UTIL_FeatureFlag.INT_FeatureFlagStrategy
{
	/**
	 * @description Evaluates whether the current user matches the target locale prefix.
	 *
	 * @param flag The feature flag being evaluated.
	 * @param strategy The strategy record containing targeting configuration.
	 *
	 * @return True if the user's locale starts with the strategy's Target value.
	 */
	public Boolean isEnabled(kern__FeatureFlag__mdt flag, kern__FeatureFlagStrategy__mdt strategy)
	{
		return UserInfo.getLocale().startsWith(strategy.kern__Target__c);
	}
}
```

**3. In the terminal**, send the class to your org:

```shell
sf project deploy start -o YourOrgAlias -m "ApexClass:MY_RegionStrategy"
```

You should see `Status: Succeeded`, with `MY_RegionStrategy` listed as created.

Something went wrong? See [Common Issues, Step 6](#step-6-add-a-custom-strategy-handler-1).

#### Step 6.2: Point a strategy at the handler

A second strategy on the same flag names your class in **Custom Handler Class**, and sets **Target** to the locale
prefix you want to match (for example, `de_DE` for the German locale).

**1. In Salesforce**, open Setup, then Custom Metadata Types, then **Feature Flag Strategy**, then **Manage Feature Flag
Strategies**, then **New**, and save a record with these values:

| Field                      | API name                 | Value                       |
|----------------------------|--------------------------|-----------------------------|
| Label                      | `MasterLabel`            | `NewPricingEngine - Region` |
| Feature Flag Strategy Name | `DeveloperName`          | `NewPricingEngine_Region`   |
| Custom Handler Class       | `kern__CustomHandler__c` | `MY_RegionStrategy`         |
| Feature Flag               | `kern__FeatureFlag__c`   | `NewPricingEngine`          |
| Is Active                  | `kern__IsActive__c`      | checked                     |
| Order                      | `kern__Order__c`         | `2`                         |
| Target                     | `kern__Target__c`        | `de_DE`                     |
| Type                       | `kern__Type__c`          | `Custom Permission`         |

The `Type` value doesn't matter when `Custom Handler Class` is filled in: the framework runs your custom handler class
regardless of the selected type.

**2. In the terminal**, pull it into your project:

```shell
sf project retrieve start -o YourOrgAlias -m "CustomMetadata:kern__FeatureFlagStrategy.NewPricingEngine_Region"
```

You should see one file created under `force-app/main/default/customMetadata`, named after the record.

Something went wrong? See [Common Issues, Step 6](#step-6-add-a-custom-strategy-handler-1).

#### Verify

**In Salesforce**, in the Execute Anonymous window, run:

```apex
System.debug('User locale: ' + UserInfo.getLocale());
System.debug('NewPricingEngine enabled: ' + kern.UTIL_FeatureFlag.isEnabled('NewPricingEngine'));
```

You should see these lines in the log (for an en_US user **with the `NewPricingEngine` permission set unassigned**):

```text
User locale: en_US
NewPricingEngine enabled: false
```

The region strategy targets `de_DE` (the German locale), so it won't match an `en_US` user. **One catch:** if
you still have the `NewPricingEngine` permission set assigned from Step 5.5, the Order-1 Custom Permission strategy
matches first and the flag returns `true`. To let the region strategy decide, open Setup, then Permission Sets, then
**New Pricing Engine**, then **Manage Assignments**, and remove your assignment. If you then change your locale to
German (Setup, then Personal Information, then Locale), the flag returns `true`.

Something went wrong? See [Common Issues, Step 6](#step-6-add-a-custom-strategy-handler-1).

### Clean up

When you have finished the guide, remove what it made from your org. The org refuses to delete a permission set that
is still assigned, or a flag a strategy still points at, so work in this order.

**1. In Salesforce**, if you have not already removed your assignment in the Verify step above, open Setup, then
Permission Sets, then **New Pricing Engine**, then **Manage Assignments**, and remove it.

**2. In the terminal**, delete the two strategy records, the permission set and the three classes:

```shell
sf project delete source -o YourOrgAlias -m "CustomMetadata:kern__FeatureFlagStrategy.NewPricingEngine_CustomPermission" -m "CustomMetadata:kern__FeatureFlagStrategy.NewPricingEngine_Region" -m "PermissionSet:NewPricingEngine" -m "ApexClass:MY_RegionStrategy" -m "ApexClass:FastStart_FeatureFlag_DEMO_TEST" -m "ApexClass:FastStart_FeatureFlag_DEMO" --no-prompt
```

You should see `Status: Succeeded`, then a `Deleted Source` table listing the three classes, the two strategy records
and the permission set.

**3. In the terminal**, delete the flag and the custom permission:

```shell
sf project delete source -o YourOrgAlias -m "CustomMetadata:kern__FeatureFlag.NewPricingEngine" -m "CustomPermission:NewPricingEngineAccess" --no-prompt
```

You should see `Status: Succeeded`, then a `Deleted Source` table listing the flag and the custom permission.

The commands delete the files from your project too. Two things the commands do not touch: if you created a
`FastStart_NewPricing` flag in Setup for Step 3, delete it there (open Setup, then Custom Metadata Types, then **Feature
Flag**, then **Manage Feature Flags**, then **Del** beside it); and if you changed your locale to German, change it back.

Something went wrong? See [Common Issues](#clean-up-1).

---

## Common Issues

Trouble with your computer rather than this guide (`sf` is not recognised, scripts are disabled, you are not logged
in, the wrong folder)? Those are answered once, in
[Set Up Your Computer](Set%20Up%20Your%20Computer.md#if-something-went-wrong).

### Step 1: Create the flag and try again

#### The block still prints `Using LEGACY pricing engine`

The flag record is missing, or it is switched off, so `isEnabled()` returns `false`. Open Setup, then Custom Metadata
Types, then **Feature Flag**, then **Manage Feature Flags**, and open the record. Check that its Feature Flag Name
(`DeveloperName`) is `NewPricingEngine`, then check **Is Active** (`kern__IsActive__c`) and **Is Enabled By Default**
(`kern__IsEnabledByDefault__c`) and save. If there is no record, create it as Step 1 shows.

### Step 2: Create the service class

#### The deploy says there is nothing to deploy

The deploy stops with `No source-backed components present in the package.` The command ran inside another project's
folder, so the CLI looked for the class there and found nothing. Open the terminal in your own project's top folder,
the one that holds `sfdx-project.json`, and run the command again.

### Step 4: Write and run the test

#### `shouldApplyLegacySurchargeWhenFlagDisabled` fails

The test expects the flag to be off, but a `FastStart_NewPricing` flag record exists in your org (for example, from the
"See it in the org" note in Step 3), so the flag reads `true`. Custom Metadata records are visible in every test.
Delete or deactivate the flag in Setup, and use `kern.TST_Factory.newFeatureFlag()` only for the enabled path.

### Step 5: Add a custom permission strategy

#### The check after assignment still reads `false`

One link in the chain from the custom permission to you is missing, or the strategy is switched off. Make sure the
permission set's Custom Permissions list includes **New Pricing Engine Access**, and that the `Permsets Assigned` table
in Step 5.5 named your username. Then open the strategy record, check **Is Active** (`kern__IsActive__c`), make sure
**Target** (`kern__Target__c`) reads `NewPricingEngineAccess`, and save.

### Step 6: Add a custom strategy handler

#### The flag stays `false` for a user your handler should match

Nothing fails on screen: the framework records the error in its log and skips the strategy, because it cannot create
your handler class. The class is `public`, or its name in **Custom Handler Class** is wrong. The framework
creates the handler by name at runtime, which reaches a `global` class in your org, or a `public with sharing` class
once a Type Resolver class is added (as the note above the step says). Declare the class `global`, or add a Type
Resolver class. Check the name is spelled exactly
`MY_RegionStrategy`, or use the fully qualified name if your code lives in a namespace (for example,
`mypkg.MY_RegionStrategy`).

### Clean up

#### `This permission set is assigned to one or more users.`

The first clean-up command stops with this message against `NewPricingEngine`, and deletes nothing. You still have
the permission set assigned. Remove your assignment as the clean-up's first part shows, then run the command again.

#### `Your attempt to delete New Pricing Engine could not be completed`

The flag was deleted before the strategy records that point at it, and the org refuses that. Delete in the clean-up's
order: first the strategy records, the permission set and the classes, then the flag and the custom permission.

Still stuck? [Tell us](https://github.com/JVB-Consulting/kerndx/issues/new?template=bug_report.md&title=%5Bdocs%5D%20Feature%20Flags) which step and what you saw.

## What You Now Know

| Concept                                             | What it does                                                       |
|-----------------------------------------------------|--------------------------------------------------------------------|
| `kern.UTIL_FeatureFlag.isEnabled(flagName)`         | Checks if a feature is enabled for the running user                |
| `kern.UTIL_FeatureFlag.isEnabled(flagName, userId)` | Checks if a feature is enabled for a specific user                 |
| `FeatureFlag__mdt`                                  | Custom Metadata record defining the flag and its default behaviour |
| `FeatureFlagStrategy__mdt`                          | Child record defining targeting rules (permission, profile, group) |
| `kern.TST_Factory.newFeatureFlag(flagName)`         | Registers an active in-memory flag in test context                 |
| `FLOW_CheckFeatureFlag`                             | Invocable action for checking flags in Flows                       |
| `isFlagEnabled(flagName)` from `kern/featureFlag`   | LWC bridge that reads the same evaluation result as Apex           |
| `kern.UTIL_FeatureFlag.INT_FeatureFlagStrategy`     | Interface to implement for custom strategy handlers                |

**Key patterns:**

- Store flag names as `@TestVisible private static final String` constants
- Test both enabled and disabled paths in every class that uses flags
- Use `kern.TST_Factory.newFeatureFlag(flagName)` in tests; don't deploy `FeatureFlag__mdt` as source code
- Use strategies for gradual rollout instead of enabling for everyone
- Custom strategy classes must be `global`, not `public`, so the managed package can create them
- Package-bundled API flags integrate automatically with web services

---

## Next Steps

- [Fast Start - Outbound APIs](Fast%20Start%20-%20Outbound%20APIs.md)
- [Fast Start - Trigger Actions](Fast%20Start%20-%20Trigger%20Actions.md)
- [Fast Start - Logging](Fast%20Start%20-%20Logging.md)
- [Feature Flags Developer Guide](Feature%20Flags%20-%20Guide.md)
- [UTIL_FeatureFlag API Reference](reference/apex/UTIL_FeatureFlag.md)
- [FeatureFlag__mdt Object](reference/metadata/FeatureFlag__mdt.md)
