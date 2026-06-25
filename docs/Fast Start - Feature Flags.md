---
navOrder: 38
---

# Fast Start - Feature Flags

**Framework:** KernDX | **Total time:** ~25 minutes

**What this is:** A way to switch features on and off in a live org by editing a configuration record, with no deployment and no code change. You can flip a feature for everyone, or target it by user, profile, permission, or group. **Why it exists:** Shipping a risky change behind a flag lets you turn it on for a few people first, watch how it behaves, and roll it back instantly if something goes wrong. **Who should follow this:** developers building features they want to release gradually, plus admins and tech leads who manage rollouts. **When to use it:** any time you want to release code one audience at a time, or keep a master off-switch ready for an incident.

**Before you start:**

- [ ] KernDX package installed in your org
- [ ] Org configured post-install (verify with the **Kern** app's Health Check, see the [Installation guide](Installation.md#post-install-configuration))
- [ ] CLI authenticated (`sf org open -o YourOrgAlias` to verify), or just use the Developer Console
  (Gear Icon > Developer Console) for all Apex work
- [ ] Working in a sandbox or scratch org (not production)

**What you'll build:** A pricing service that switches between legacy and new calculation logic based on a
feature flag.

**Success looks like:** Toggling a Custom Metadata record flips your code from one execution path to another, with
no deployment needed.

**In one line:** `if(kern.UTIL_FeatureFlag.isEnabled('NewPricing'))`, where one metadata record controls the
behaviour and is toggled without deployment.

---

## Table of Contents

<details>
<summary>Expand</summary>

1. [Tier 1: See It Work (~2 minutes)](#tier-1-see-it-work-2-minutes)
    - [Check a feature flag](#check-a-feature-flag)
    - [Use a flag in conditional logic](#use-a-flag-in-conditional-logic)
    - [Create the flag and try again](#create-the-flag-and-try-again)
    - [Clean up](#clean-up)
2. [Tier 2: Build Your Own (~15-20 minutes)](#tier-2-build-your-own-15-20-minutes)
    - [Step 1: Create the service class](#step-1-create-the-service-class)
    - [Step 2: Deploy and execute](#step-2-deploy-and-execute)
    - [Step 3: Write the test class](#step-3-write-the-test-class)
    - [Step 4: Deploy and run tests](#step-4-deploy-and-run-tests)
        - [Key Patterns](#key-patterns)
3. [Tier 3: Production Patterns (~5-10 minutes)](#tier-3-production-patterns-5-10-minutes)
    - [Framework-shipped flags you inherit automatically](#framework-shipped-flags-you-inherit-automatically)
    - [Strategy-based targeting](#strategy-based-targeting)
        - [Deploy a Custom Permission strategy](#deploy-a-custom-permission-strategy)
        - [Verify the strategy](#verify-the-strategy)
    - [Evaluation logic](#evaluation-logic)
    - [Check flags for specific users](#check-flags-for-specific-users)
    - [Use in Flows](#use-in-flows)
    - [Use in LWC](#use-in-lwc)
    - [Custom strategy handler](#custom-strategy-handler)
        - [Deploy the handler](#deploy-the-handler)
        - [Wire it to a flag via strategy metadata](#wire-it-to-a-flag-via-strategy-metadata)
        - [Verify](#verify)
    - [Package-bundled API control flags](#package-bundled-api-control-flags)
4. [Common Issues](#common-issues)
5. [What You Now Know](#what-you-now-know)
6. [Next Steps](#next-steps)

</details>

---

## Tier 1: See It Work (~2 minutes)

Run these blocks in **Execute Anonymous** (Developer Console or VS Code) to see feature flags in action.

### Check a feature flag

```apex
Boolean isEnabled = kern.UTIL_FeatureFlag.isEnabled('NewPricingEngine');
System.debug('NewPricingEngine enabled: ' + isEnabled);
```

**Expected output:**

```text
NewPricingEngine enabled: false
```

A flag that doesn't exist returns `false`, so the behaviour is safe by default. Your code won't break if a flag hasn't been created
yet.

### Use a flag in conditional logic

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

**Expected output:**

```text
Using LEGACY pricing engine
```

### Create the flag and try again

<details open>
<summary><strong>Windows (PowerShell)</strong></summary>

```powershell
New-Item -ItemType Directory -Force -Path force-app/main/default/customMetadata | Out-Null
@'
<?xml version="1.0" encoding="UTF-8"?>
<CustomMetadata xmlns="http://soap.sforce.com/2006/04/metadata"
    xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
    xmlns:xsd="http://www.w3.org/2001/XMLSchema">
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
'@ | Set-Content -Path "force-app/main/default/customMetadata/kern__FeatureFlag.NewPricingEngine.md-meta.xml" -Encoding UTF8
sf project deploy start -o YourOrgAlias -m "CustomMetadata:kern__FeatureFlag.NewPricingEngine" --ignore-conflicts
```

</details>

<details>
<summary><strong>macOS/Linux (bash)</strong></summary>

```bash
mkdir -p force-app/main/default/customMetadata
cat > force-app/main/default/customMetadata/kern__FeatureFlag.NewPricingEngine.md-meta.xml << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<CustomMetadata xmlns="http://soap.sforce.com/2006/04/metadata"
    xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
    xmlns:xsd="http://www.w3.org/2001/XMLSchema">
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
EOF
sf project deploy start -o YourOrgAlias \
  -m "CustomMetadata:kern__FeatureFlag.NewPricingEngine" --ignore-conflicts
```

</details>

> **Prefer the UI?** Create this record in **Setup > Custom Metadata Types > Feature Flag > Manage Records > New**:
> Label = `New Pricing Engine`, Feature Flag Name = `NewPricingEngine`, Is Active = checked,
> Is Enabled By Default = checked.

Now re-run the conditional logic block:

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

**Expected output:**

```text
Using NEW pricing engine
```

You just toggled behavior without deploying code.

### Clean up

```bash
sf project delete source -o YourOrgAlias \
  -m "CustomMetadata:kern__FeatureFlag.NewPricingEngine" --no-prompt
```

> **Prefer the UI?** Go to **Setup > Custom Metadata Types > Feature Flag > Manage Records**, click **Del** next
> to `NewPricingEngine`, and confirm.

Re-run the same code and you're back to `Using LEGACY pricing engine`. This confirms the safe default: a missing
flag always returns `false`.

> **When to move to Tier 2:** When you want to build a real service that branches on a flag, with tests covering
> both paths.

---

## Tier 2: Build Your Own (~15-20 minutes)

> **No local project?** You can create classes directly in the Developer Console (Gear Icon > Developer Console >
> File > New > Apex Class) and run tests from there too (Test > New Run). Paste the code, save, and skip the
> `sf project deploy start` and `sf apex run test` commands.

### Step 1: Create the service class

Here is the goal: a pricing service that charges a 5% surcharge today, and a lower 3% surcharge once you turn the new pricing on. A feature flag decides which rate applies, so you can switch behaviour without redeploying the class.

Copy this code exactly as is into `force-app/main/default/classes/FastStart_FeatureFlag_DEMO.cls`:

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

### Step 2: Deploy and execute

```bash
sf project deploy start -o YourOrgAlias -m "ApexClass:FastStart_FeatureFlag_DEMO" --ignore-conflicts
```

Test it from Execute Anonymous:

```apex
FastStart_FeatureFlag_DEMO demo = new FastStart_FeatureFlag_DEMO();
Decimal amount = demo.processWithNewPricing(100.00);
System.debug('Amount: ' + amount);
```

**Expected output** (with the flag not created or inactive; Apex `Decimal` preserves scale, so the value
carries four decimal places):

```text
Amount: 105.0000
```

> **See it in the org:** Create the `FastStart_NewPricing` flag in Setup (as in Tier 1) with Is Active = checked
> and Is Enabled By Default = checked, then re-run. You'll get `103.0000`. Deactivate or delete the flag and you're
> back to `105.0`.

### Step 3: Write the test class

Copy this code exactly as is into `force-app/main/default/classes/FastStart_FeatureFlag_DEMO_TEST.cls`:

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
@IsTest(IsParallel=true)
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

> **About the annotations:** `@IsTest(IsParallel=true)` allows tests to run concurrently for faster feedback.
> `@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')` suppresses a code analysis rule (the scanner that checks code without running it). In production
> tests, wrap your test logic in `System.runAs(testUser)`.

> **Test isolation:** The "disabled" test relies on the flag **not existing** in the org. If you created a
> `FastStart_NewPricing` flag via the UI or CLI, make sure it is inactive or deleted before running tests.
> Custom Metadata records are visible in every test, so use `kern.TST_Factory.newFeatureFlag()` to activate flags in test context.

> **Seeding flags in tests:** `kern.TST_Factory.newFeatureFlag('YourFlag')` seeds an active flag for the test
> in memory, so no Custom Metadata record is created in the org. To test the disabled path, simply don't seed the flag: an
> unseeded flag is treated as off.

### Step 4: Deploy and run tests

```bash
sf project deploy start -o YourOrgAlias -m "ApexClass:FastStart_FeatureFlag_DEMO_TEST" --ignore-conflicts
sf apex run test -o YourOrgAlias -t FastStart_FeatureFlag_DEMO_TEST --code-coverage --synchronous --result-format human
```

**Expected output:**

```text
=== Test Results
Test Run Id      [ID]
Tests Ran        2
Passing          2
Failing          0
```

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
The framework reads them directly from Apex to control how it behaves across your org. Several of them act as a kill-switch: a master off-switch you can flip in an incident without a deployment. Two of them also choose whether queries and saves run with the current user's read/write permissions and record sharing enforced (USER_MODE) or skip all of those checks (SYSTEM_MODE). In the table below, CRUD means object create/read/update/delete permissions and FLS means field-level security.

| Flag                                                                  | Purpose                                                                                                                                                                                            | Default | Emergency Rollback                                                       |
|-----------------------------------------------------------------------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|---------|--------------------------------------------------------------------------|
| `UserModeQueries_Enabled`                                             | Controls the default `AccessLevel` on `QRY_Builder` / `SEL_Base.query`. `true` → USER_MODE (CRUD/FLS/sharing enforced); `false` → SYSTEM_MODE.                                                     | `true`  | Setup → CMDT → FeatureFlag → edit → set `IsEnabledByDefault__c = false`. |
| `UserModeDml_Enabled`                                                 | Controls the default `AccessLevel` on `DML_Builder.newTransaction()` operations. Same true/false semantics as above.                                                                               | `true`  | Same metadata flip path.                                                 |
| `MaskingFramework_Enabled`                                            | Kill-switch for the data-masking framework (`MaskingTarget__mdt` / `MaskingRule__mdt`). `true` → rules are applied before `LogEntryEvent__e` publishes; `false` → pipeline skips masking entirely. | `true`  | Same metadata flip path.                                                 |
| `AsyncChain`                                                          | Kill-switch for `UTIL_AsyncChain` orchestration. `true` → chains execute; `false` → chains short-circuit immediately.                                                                              | `true`  | Same metadata flip path.                                                 |
| `DisableAllInboundAPIs` / `DisableAllOutboundAPIs` / `DisableAllAPIs` | Runtime kill-switches for the web-service framework.                                                                                                                                               | `false` | Same metadata flip path.                                                 |
| `MockAllAPIs` / `MockAllInboundAPIs`                                  | Test-mode toggles used by `API_MockFactory`.                                                                                                                                                       | `false` | Same metadata flip path.                                                 |

> The package also ships a `TestFeatureFlag` record (`protected=true`) used by the framework's own test classes. It isn't meant for your org to use. The flags listed above are the
> complete set visible to you.

See [Security Guide, Safe by Default](Security%20-%20Guide.md#safe-by-default) for how
`UserModeQueries_Enabled` and `UserModeDml_Enabled` interact with `.withSystemMode()`, `.withUserMode()`, and
the `systemModeRequired()` hook on `SEL_Base`.

### Strategy-based targeting

Most rollouts start with a small audience, not the whole org. A **strategy** lets you turn a flag on only for the users you choose, by permission, profile, group, or setting, instead of for everyone at once. This example adds a
Custom Permission strategy to the `NewPricingEngine` flag you created in Tier 2.

| Strategy Type               | Target Example                   | Use Case                         |
|-----------------------------|----------------------------------|----------------------------------|
| Custom Permission           | `Edit_Confidential_Records`      | Permission-based feature rollout |
| Permission Set Group        | `Sales_Team`                     | Team-based rollout               |
| Profile                     | `System Administrator`           | Admin-only features              |
| Public Group                | `Beta_Testers`                   | Opt-in beta programs             |
| Hierarchical Custom Setting | `MySettings__c.EnableFeature__c` | Org/profile/user hierarchy       |
| Custom Metadata             | `Config__mdt.Setting.Field__c`   | Configuration-driven flags       |

> **SOQL cost:** each `isEnabled(...)` call usually runs one query (SOQL) behind the scenes. Two cases avoid that query: a namespaced or `core.` Custom Permission check for the running user, and the no-strategy
> `IsEnabledByDefault__c` fast path. One query per call is fine for everyday synchronous code, but it adds up
> inside record loops, batches, and scheduled jobs. If you call flags in tight loops, or read several flags off the same Custom
> Setting, see [Feature Flags - Guide, Performance and SOQL Cost](Feature%20Flags%20-%20Guide.md#performance-and-soql-cost) for the per-strategy
> cost table, the pattern for reading a flag once and reusing the result, and a `getInstance()`-based custom handler that avoids the query for Custom Setting strategies.

#### Deploy a Custom Permission strategy

First, re-deploy the `NewPricingEngine` flag from Tier 1 with `IsEnabledByDefault = false`. With the default off, the strategy
decides who gets access:

<details open>
<summary><strong>Windows (PowerShell)</strong></summary>

```powershell
New-Item -ItemType Directory -Force -Path force-app/main/default/customMetadata | Out-Null
@'
<?xml version="1.0" encoding="UTF-8"?>
<CustomMetadata xmlns="http://soap.sforce.com/2006/04/metadata"
    xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
    xmlns:xsd="http://www.w3.org/2001/XMLSchema">
    <label>New Pricing Engine</label>
    <protected>false</protected>
    <values>
        <field>kern__IsActive__c</field>
        <value xsi:type="xsd:boolean">true</value>
    </values>
    <values>
        <field>kern__IsEnabledByDefault__c</field>
        <value xsi:type="xsd:boolean">false</value>
    </values>
</CustomMetadata>
'@ | Set-Content -Path "force-app/main/default/customMetadata/kern__FeatureFlag.NewPricingEngine.md-meta.xml" -Encoding UTF8
sf project deploy start -o YourOrgAlias -m "CustomMetadata:kern__FeatureFlag.NewPricingEngine" --ignore-conflicts
```

</details>

<details>
<summary><strong>macOS/Linux (bash)</strong></summary>

```bash
mkdir -p force-app/main/default/customMetadata
cat > force-app/main/default/customMetadata/kern__FeatureFlag.NewPricingEngine.md-meta.xml << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<CustomMetadata xmlns="http://soap.sforce.com/2006/04/metadata"
    xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
    xmlns:xsd="http://www.w3.org/2001/XMLSchema">
    <label>New Pricing Engine</label>
    <protected>false</protected>
    <values>
        <field>kern__IsActive__c</field>
        <value xsi:type="xsd:boolean">true</value>
    </values>
    <values>
        <field>kern__IsEnabledByDefault__c</field>
        <value xsi:type="xsd:boolean">false</value>
    </values>
</CustomMetadata>
EOF
sf project deploy start -o YourOrgAlias \
  -m "CustomMetadata:kern__FeatureFlag.NewPricingEngine" --ignore-conflicts
```

</details>

Now create the Custom Permission, a Permission Set to hold it, and a strategy that targets it:

<details open>
<summary><strong>Windows (PowerShell)</strong></summary>

```powershell
New-Item -ItemType Directory -Force -Path force-app/main/default/customPermissions | Out-Null
@'
<?xml version="1.0" encoding="UTF-8"?>
<CustomPermission xmlns="http://soap.sforce.com/2006/04/metadata">
    <label>New Pricing Engine Access</label>
    <isLicensed>false</isLicensed>
</CustomPermission>
'@ | Set-Content -Path "force-app/main/default/customPermissions/NewPricingEngineAccess.customPermission-meta.xml" -Encoding UTF8
New-Item -ItemType Directory -Force -Path force-app/main/default/permissionsets | Out-Null
@'
<?xml version="1.0" encoding="UTF-8"?>
<PermissionSet xmlns="http://soap.sforce.com/2006/04/metadata">
    <label>New Pricing Engine</label>
    <hasActivationRequired>false</hasActivationRequired>
    <customPermissions>
        <enabled>true</enabled>
        <name>NewPricingEngineAccess</name>
    </customPermissions>
</PermissionSet>
'@ | Set-Content -Path "force-app/main/default/permissionsets/NewPricingEngine.permissionset-meta.xml" -Encoding UTF8
@'
<?xml version="1.0" encoding="UTF-8"?>
<CustomMetadata xmlns="http://soap.sforce.com/2006/04/metadata"
    xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
    xmlns:xsd="http://www.w3.org/2001/XMLSchema">
    <label>NewPricingEngine - Custom Permission</label>
    <protected>false</protected>
    <values>
        <field>kern__FeatureFlag__c</field>
        <value xsi:type="xsd:string">NewPricingEngine</value>
    </values>
    <values>
        <field>kern__IsActive__c</field>
        <value xsi:type="xsd:boolean">true</value>
    </values>
    <values>
        <field>kern__Order__c</field>
        <value xsi:type="xsd:double">1.0</value>
    </values>
    <values>
        <field>kern__Target__c</field>
        <value xsi:type="xsd:string">NewPricingEngineAccess</value>
    </values>
    <values>
        <field>kern__Type__c</field>
        <value xsi:type="xsd:string">Custom Permission</value>
    </values>
</CustomMetadata>
'@ | Set-Content -Path "force-app/main/default/customMetadata/kern__FeatureFlagStrategy.NewPricingEngine_CustomPermission.md-meta.xml" -Encoding UTF8
sf project deploy start -o YourOrgAlias `
  -m "CustomPermission:NewPricingEngineAccess" `
  -m "PermissionSet:NewPricingEngine" `
  -m "CustomMetadata:kern__FeatureFlagStrategy.NewPricingEngine_CustomPermission" `
  --ignore-conflicts
```

</details>

<details>
<summary><strong>macOS/Linux (bash)</strong></summary>

```bash
mkdir -p force-app/main/default/customPermissions
cat > force-app/main/default/customPermissions/NewPricingEngineAccess.customPermission-meta.xml << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<CustomPermission xmlns="http://soap.sforce.com/2006/04/metadata">
    <label>New Pricing Engine Access</label>
    <isLicensed>false</isLicensed>
</CustomPermission>
EOF
mkdir -p force-app/main/default/permissionsets
cat > force-app/main/default/permissionsets/NewPricingEngine.permissionset-meta.xml << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<PermissionSet xmlns="http://soap.sforce.com/2006/04/metadata">
    <label>New Pricing Engine</label>
    <hasActivationRequired>false</hasActivationRequired>
    <customPermissions>
        <enabled>true</enabled>
        <name>NewPricingEngineAccess</name>
    </customPermissions>
</PermissionSet>
EOF
cat > force-app/main/default/customMetadata/kern__FeatureFlagStrategy.NewPricingEngine_CustomPermission.md-meta.xml << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<CustomMetadata xmlns="http://soap.sforce.com/2006/04/metadata"
    xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
    xmlns:xsd="http://www.w3.org/2001/XMLSchema">
    <label>NewPricingEngine - Custom Permission</label>
    <protected>false</protected>
    <values>
        <field>kern__FeatureFlag__c</field>
        <value xsi:type="xsd:string">NewPricingEngine</value>
    </values>
    <values>
        <field>kern__IsActive__c</field>
        <value xsi:type="xsd:boolean">true</value>
    </values>
    <values>
        <field>kern__Order__c</field>
        <value xsi:type="xsd:double">1.0</value>
    </values>
    <values>
        <field>kern__Target__c</field>
        <value xsi:type="xsd:string">NewPricingEngineAccess</value>
    </values>
    <values>
        <field>kern__Type__c</field>
        <value xsi:type="xsd:string">Custom Permission</value>
    </values>
</CustomMetadata>
EOF
sf project deploy start -o YourOrgAlias \
  -m "CustomPermission:NewPricingEngineAccess" \
  -m "PermissionSet:NewPricingEngine" \
  -m "CustomMetadata:kern__FeatureFlagStrategy.NewPricingEngine_CustomPermission" \
  --ignore-conflicts
```

</details>

> **Prefer the UI?** Create the Custom Permission in **Setup > Custom Permissions > New** (Label = `New Pricing
> Engine Access`). Create the Permission Set in **Setup > Permission Sets > New** (Label = `New Pricing Engine`),
> then add the custom permission to it. Create the strategy in **Setup > Custom Metadata Types > Feature Flag
> Strategy > Manage Records > New**: Feature Flag = `NewPricingEngine`, Type = `Custom Permission`,
> Target = `NewPricingEngineAccess`, Is Active = checked, Order = `1`.

#### Verify the strategy

```apex
// Without the permission set — flag is disabled (IsEnabledByDefault = false, no strategy match)
Boolean before = kern.UTIL_FeatureFlag.isEnabled('NewPricingEngine');
System.debug('Before assignment: ' + before);
```

**Expected output:**

```text
Before assignment: false
```

Assign the permission set to yourself: **Setup > Permission Sets > New Pricing Engine > Manage Assignments >
Add Assignment > (select your user)**. Then re-run:

```apex
// With the permission set — strategy matches, flag is enabled for you
Boolean after = kern.UTIL_FeatureFlag.isEnabled('NewPricingEngine');
System.debug('After assignment: ' + after);
```

**Expected output:**

```text
After assignment: true
```

The flag is now enabled only for users who have the `NewPricingEngine` permission set. Everyone else still gets
`false`.

### Evaluation logic

When you ask whether a flag is on, the framework checks a fixed sequence of conditions and stops at the first one that decides the answer. Knowing this order helps you predict what a flag will return. Run this to watch the fallback path in action:

```apex
// Path 1: Flag doesn't exist → returns false (safe default)
System.debug('Non-existent flag: ' + kern.UTIL_FeatureFlag.isEnabled('NoSuchFlag'));

// Path 2: Flag exists, IsActive = true, no strategies → returns IsEnabledByDefault
System.debug('NewPricingEngine (with strategy): ' + kern.UTIL_FeatureFlag.isEnabled('NewPricingEngine'));
```

**Expected output:**

```text
Non-existent flag: false
NewPricingEngine (with strategy): true (if permission assigned) / false (if not)
```

The full evaluation flow:

```text
1. IsActive = false?           → return false (kill switch)
2. No strategies defined?      → return IsEnabledByDefault
3. Strategies exist:
   - First strategy match true → return true
   - Any strategy match false  → return false
   - No strategy matches       → return ResultOnNoMatch
```

### Check flags for specific users

Sometimes the user you care about isn't the one running the code: a batch job, a platform event, or a security policy may act on behalf of someone else. For those cases, pass a specific user (by Id or username) so the flag is evaluated against that person, not the running user:

```apex
// Check for a specific user by ID
Id userId = UserInfo.getUserId();
Boolean enabledForUser = kern.UTIL_FeatureFlag.isEnabled('NewPricingEngine', userId);
System.debug('Enabled for ' + UserInfo.getName() + ': ' + enabledForUser);

// Check by username
Boolean enabledByUsername = kern.UTIL_FeatureFlag.isEnabled('NewPricingEngine', UserInfo.getUserName());
System.debug('Enabled for ' + UserInfo.getUserName() + ': ' + enabledByUsername);
```

**Expected output** (varies based on permission set assignment):

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
5. Set the **featureFlagName** input to the text value `NewPricingEngine`
6. Click **Done**
7. Add a **Decision** element after the action:
    - **Label:** `Is Flag Enabled?`
    - **Outcome 1 Label:** `Flag Enabled`
    - **Condition:** `{!Check_Pricing_Engine_Flag.isEnabled}` **Equals** `{!$GlobalConstant.True}`
    - **Default Outcome Label:** `Flag Disabled`
8. Add different logic in each branch (e.g., different screens or assignments)
9. **Save** and **Activate** the Flow

> **Note:** The invocable action name in the API is `FLOW_CheckFeatureFlag`. The label shown in the Flow
> Builder UI is **Is Feature Flag Enabled**.

### Use in LWC

You can check the same flags from a Lightning component, so the screen shows or hides parts of the page to match what your Apex code does. Import `c/featureFlag` and call `isFlagEnabled(flagName)` to read the same result your Apex code sees:

```javascript
import {ComponentBuilder} from 'c/componentBuilder';
import {isFlagEnabled} from 'c/featureFlag';

export default class MyComponent extends ComponentBuilder('notification')
{
	checkoutEnabled = false;

	async connectedCallback()
	{
		this.checkoutEnabled = await isFlagEnabled('NewPricingEngine');
	}
}
```

Behind the scenes this calls `CTRL_FeatureFlag.isEnabled` (`@AuraEnabled(cacheable=true)`), so a component sees the same per-user
result your Apex sees. One caution: because the result is cached on the client, it can be briefly out of date after you assign or
remove a permission set that changes a flag for the running user. The cache refreshes on a page reload, but not when
a `@wire` simply re-fires. So use this to shape the user experience (showing or hiding a panel or section), not to decide whether someone is
allowed to do something. Treat real authorization in Apex. See [LWC Guide, Feature Flag Bridge](LWC%20-%20Guide.md) for the full caveats.

### Custom strategy handler

The built-in strategy types (permission, profile, group, and so on) cover most rollouts. When your "who gets this flag" rule is more involved, for example matching on a user's locale or a value from another record, you write a small Apex class that decides, and point a strategy at it.

> **Naming convention:** The strategy interface is `kern.UTIL_FeatureFlag.INT_FeatureFlagStrategy`. Note the
> `INT_*` prefix, not `IF_*`. Top-level framework interfaces use the `IF_*` prefix, while inner interfaces nested inside
> `UTIL_*` classes use the `INT_*` prefix. This is a deliberate codebase convention, so don't rename it.

> **Why `global`?** Declaring the class `global` lets the framework find and create it at runtime with no extra setup.
> If you prefer `public with sharing`, you'll need a Type Resolver class, which is how the framework finds the Apex classes in your namespace: you tell it where to look. The Kern home page health check
> provides that code, or see [Type Resolution](Utilities%20-%20Guide.md#type-resolution-util_typeresolver).

#### Deploy the handler

> **No local project?** You can create classes directly in the Developer Console (Gear Icon > Developer Console >
> File > New > Apex Class) and run tests from there too (Test > New Run). Paste the code, save, and skip the
> `sf project deploy start` and `sf apex run test` commands.

<details open>
<summary><strong>Windows (PowerShell)</strong></summary>

```powershell
New-Item -ItemType Directory -Force -Path force-app/main/default/classes | Out-Null
@'
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
'@ | Set-Content -Path "force-app/main/default/classes/MY_RegionStrategy.cls" -Encoding UTF8
@'
<?xml version="1.0" encoding="UTF-8"?>
<ApexClass xmlns="http://soap.sforce.com/2006/04/metadata">
    <apiVersion>67.0</apiVersion>
    <status>Active</status>
</ApexClass>
'@ | Set-Content -Path "force-app/main/default/classes/MY_RegionStrategy.cls-meta.xml" -Encoding UTF8
sf project deploy start -o YourOrgAlias -m "ApexClass:MY_RegionStrategy" --ignore-conflicts
```

</details>

<details>
<summary><strong>macOS/Linux (bash)</strong></summary>

```bash
mkdir -p force-app/main/default/classes
cat > force-app/main/default/classes/MY_RegionStrategy.cls << 'CLSEOF'
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
CLSEOF
cat > force-app/main/default/classes/MY_RegionStrategy.cls-meta.xml << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<ApexClass xmlns="http://soap.sforce.com/2006/04/metadata">
    <apiVersion>67.0</apiVersion>
    <status>Active</status>
</ApexClass>
EOF
sf project deploy start -o YourOrgAlias \
  -m "ApexClass:MY_RegionStrategy" --ignore-conflicts
```

</details>

#### Wire it to a flag via strategy metadata

Create a strategy that points at your custom handler. Set the **Custom Handler** field to the class name, and set
**Target** to the locale prefix you want to match (for example, `de_DE` for the German locale):

<details open>
<summary><strong>Windows (PowerShell)</strong></summary>

```powershell
@'
<?xml version="1.0" encoding="UTF-8"?>
<CustomMetadata xmlns="http://soap.sforce.com/2006/04/metadata"
    xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
    xmlns:xsd="http://www.w3.org/2001/XMLSchema">
    <label>NewPricingEngine - Region</label>
    <protected>false</protected>
    <values>
        <field>kern__CustomHandler__c</field>
        <value xsi:type="xsd:string">MY_RegionStrategy</value>
    </values>
    <values>
        <field>kern__FeatureFlag__c</field>
        <value xsi:type="xsd:string">NewPricingEngine</value>
    </values>
    <values>
        <field>kern__IsActive__c</field>
        <value xsi:type="xsd:boolean">true</value>
    </values>
    <values>
        <field>kern__Order__c</field>
        <value xsi:type="xsd:double">2.0</value>
    </values>
    <values>
        <field>kern__Target__c</field>
        <value xsi:type="xsd:string">de_DE</value>
    </values>
    <values>
        <field>kern__Type__c</field>
        <value xsi:type="xsd:string">Custom Permission</value>
    </values>
</CustomMetadata>
'@ | Set-Content -Path "force-app/main/default/customMetadata/kern__FeatureFlagStrategy.NewPricingEngine_Region.md-meta.xml" -Encoding UTF8
sf project deploy start -o YourOrgAlias -m "CustomMetadata:kern__FeatureFlagStrategy.NewPricingEngine_Region" --ignore-conflicts
```

</details>

<details>
<summary><strong>macOS/Linux (bash)</strong></summary>

```bash
cat > force-app/main/default/customMetadata/kern__FeatureFlagStrategy.NewPricingEngine_Region.md-meta.xml << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<CustomMetadata xmlns="http://soap.sforce.com/2006/04/metadata"
    xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
    xmlns:xsd="http://www.w3.org/2001/XMLSchema">
    <label>NewPricingEngine - Region</label>
    <protected>false</protected>
    <values>
        <field>kern__CustomHandler__c</field>
        <value xsi:type="xsd:string">MY_RegionStrategy</value>
    </values>
    <values>
        <field>kern__FeatureFlag__c</field>
        <value xsi:type="xsd:string">NewPricingEngine</value>
    </values>
    <values>
        <field>kern__IsActive__c</field>
        <value xsi:type="xsd:boolean">true</value>
    </values>
    <values>
        <field>kern__Order__c</field>
        <value xsi:type="xsd:double">2.0</value>
    </values>
    <values>
        <field>kern__Target__c</field>
        <value xsi:type="xsd:string">de_DE</value>
    </values>
    <values>
        <field>kern__Type__c</field>
        <value xsi:type="xsd:string">Custom Permission</value>
    </values>
</CustomMetadata>
EOF
sf project deploy start -o YourOrgAlias \
  -m "CustomMetadata:kern__FeatureFlagStrategy.NewPricingEngine_Region" --ignore-conflicts
```

</details>

> **Prefer the UI?** Create this record in **Setup > Custom Metadata Types > Feature Flag Strategy > Manage
> Records > New**: Feature Flag = `NewPricingEngine`, Type = `Custom Permission`,
> Custom Handler = `MY_RegionStrategy`, Target = `de_DE`, Is Active = checked, Order = `2`.
>
> The `Type` value doesn't matter when `Custom Handler` is populated: the framework runs your custom
> handler class regardless of the selected type.

#### Verify

```apex
System.debug('User locale: ' + UserInfo.getLocale());
System.debug('NewPricingEngine enabled: ' + kern.UTIL_FeatureFlag.isEnabled('NewPricingEngine'));
```

**Expected output** (for an en_US user **with the `NewPricingEngine` permission unassigned**):

```text
User locale: en_US
NewPricingEngine enabled: false
```

The region strategy targets `de_DE` (the German locale), so it won't match an `en_US` user. **One catch:** if
you still have the `NewPricingEngine` Custom Permission assigned from the earlier *Verify the strategy*
step, the Order-1 Custom Permission strategy matches first and the flag returns `true`. Remove that
assignment (**Setup > Permission Sets > New Pricing Engine > Manage Assignments > Del**) to let the region
strategy decide. If you then change your locale to German (Setup > Personal Information > Locale), the flag
returns `true`.

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

These work with the web services framework automatically, with no code needed. Verify from Execute Anonymous:

```apex
// These are pre-packaged flags — check their current state
System.debug('DisableAllAPIs: ' + kern.UTIL_FeatureFlag.isEnabled('DisableAllAPIs'));
System.debug('MockAllAPIs: ' + kern.UTIL_FeatureFlag.isEnabled('MockAllAPIs'));
```

**Expected output:**

```text
DisableAllAPIs: false
MockAllAPIs: false
```

To use these in tests, activate them with `TST_Factory`:

```apex
// In a @IsTest method:
kern.TST_Factory.newFeatureFlag('DisableAllAPIs');
// All API calls in this test will be disabled
```

---

## Common Issues

| Problem                                         | Cause                                                      | Fix                                                                                                                                                                                                                   |
|-------------------------------------------------|------------------------------------------------------------|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `isEnabled()` always returns `false`            | Flag doesn't exist or `IsActive` unchecked                 | Create the `FeatureFlag__mdt` record and check **Is Active**                                                                                                                                                          |
| Flag enabled globally but not for specific user | Strategy `IsActive` not checked                            | Check **Is Active** on each `FeatureFlagStrategy__mdt` record                                                                                                                                                         |
| "Disabled" test fails, flag returns `true`      | `FeatureFlag__mdt` record exists in the org                | Delete or deactivate the flag from Setup. Custom Metadata is visible in all tests. Use `kern.TST_Factory.newFeatureFlag()` for the enabled path only                                                                  |
| `TST_Factory.newFeatureFlag()` not found        | Missing namespace prefix                                   | Use `kern.TST_Factory.newFeatureFlag('FlagName')`                                                                                                                                                                     |
| Custom permission strategy not matching         | Permission not assigned to test user                       | Verify Custom Permission → Permission Set → User assignment chain                                                                                                                                                     |
| Custom handler class not found                  | Wrong class name, missing namespace, or class not `global` | Declare the class `global`, not `public`. The framework creates it via `Type.newInstance()`, which only reaches a `global` class in your org. Use the fully qualified name if your code lives in a namespace (e.g., `mypkg.MY_RegionStrategy`) |
| "Type is not visible" on custom strategy        | Class declared `public` instead of `global`                | Change the class declaration to `global with sharing`                                                                                                                                                                 |

---

## What You Now Know

| Concept                                             | What it does                                                       |
|-----------------------------------------------------|--------------------------------------------------------------------|
| `kern.UTIL_FeatureFlag.isEnabled(flagName)`         | Checks if a feature is enabled for the running user                |
| `kern.UTIL_FeatureFlag.isEnabled(flagName, userId)` | Checks if a feature is enabled for a specific user                 |
| `FeatureFlag__mdt`                                  | Custom Metadata record defining the flag and its default behavior  |
| `FeatureFlagStrategy__mdt`                          | Child record defining targeting rules (permission, profile, group) |
| `kern.TST_Factory.newFeatureFlag(flagName)`         | Registers an active in-memory flag in test context                 |
| `FLOW_CheckFeatureFlag`                             | Invocable action for checking flags in Flows                       |
| `isFlagEnabled(flagName)` from `c/featureFlag`      | LWC bridge that reads the same evaluation result as Apex           |
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
