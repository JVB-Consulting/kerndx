---
navOrder: 10
---

# Fast Start - Trigger Actions

**Framework:** KernDX | **Total time:** ~20 minutes

> Modular, metadata-driven trigger logic -- one class per action, ordered and toggled without deployment.

**Before you start:**

- [ ] KernDX package installed in your org
- [ ] Org configured post-install — verify with the **Kern** app's Health Check (see [Installation guide](Installation.md#post-install-configuration))
- [ ] CLI authenticated (`sf org open -o YourOrgAlias` to verify) — or just use the Developer Console
  (Gear Icon > Developer Console) for all Apex work
- [ ] Working in a sandbox or scratch org (not production)

> **Subscriber orgs:** Use `kern.ClassName` when extending framework classes (e.g., `kern.TRG_Base`,
> `kern.IF_Trigger.BeforeInsert`). Your own classes don't need a namespace prefix — the framework's
> Type Resolver handles resolution automatically.

**What you'll build:** A trigger action that stamps default field values on new records -- handler class,
metadata wiring, and a test class with 100% coverage.

**Success looks like:** You insert an Account, see the default Description populated automatically, and
have 2 passing tests with 100% coverage.

**In one line:** `new kern.TRG_Dispatcher().run();` -- one line in the trigger, all logic lives in handler
classes configured via Custom Metadata.

---

## Table of Contents

<details>
<summary>Expand</summary>

1. [How It Works](#how-it-works)
2. [Tier 1: Build It (~5 minutes)](#tier-1-build-it-5-minutes)
    - [Step 1: Create the Trigger Action](#step-1-create-the-trigger-action)
    - [Step 2: Create the Physical Trigger](#step-2-create-the-physical-trigger)
    - [Step 3: Register Metadata](#step-3-register-metadata)
        - [3a. Create TriggerSetting (one per object)](#3a-create-triggersetting-one-per-object)
        - [3b. Create TriggerAction (one per action+event)](#3b-create-triggeraction-one-per-actionevent)
    - [Step 4: Verify](#step-4-verify)
3. [Tier 2: Test It (~3 minutes)](#tier-2-test-it-3-minutes)
    - [Testing Flow Actions with TST_InvokeFlowMock](#testing-flow-actions-with-tst_invokeflowmock)
4. [Tier 3: Production Patterns (~10 minutes)](#tier-3-production-patterns-10-minutes)
    - [Available Interfaces](#available-interfaces)
    - [Comparing Old vs New Values (Update Context)](#comparing-old-vs-new-values-update-context)
    - [Bypass Mechanisms](#bypass-mechanisms)
    - [Feature Flag Integration](#feature-flag-integration)
    - [Ordering Multiple Actions](#ordering-multiple-actions)
5. [Using Flow as a Trigger Action](#using-flow-as-a-trigger-action)
    - [Variable contract](#variable-contract)
    - [Configure the TriggerAction__mdt record](#configure-the-triggeraction__mdt-record)
6. [Common Issues](#common-issues)
7. [What You Now Know](#what-you-now-know)
8. [Next Steps](#next-steps)

</details>

---

## How It Works

The trigger framework splits responsibilities:

| Component                                     | Role                                          | You Create           |
|-----------------------------------------------|-----------------------------------------------|----------------------|
| **Physical trigger** (`TRG_Account`)          | Delegates to framework -- single line of code | Once per object      |
| **Trigger action** (`TRG_AccountSetDefaults`) | One class per behavior                        | One per action       |
| **`TriggerSetting__mdt`**                     | Per-object configuration                      | One per object       |
| **`TriggerAction__mdt`**                      | Wires actions to events, controls ordering    | One per action+event |

**Why?** Adding/removing/reordering trigger behavior is a metadata change, not a code change. Each action is
independently testable. No monolithic trigger file.

---

## Tier 1: Build It (~5 minutes)

> **No local project?** You can create classes directly in the Developer Console (Gear Icon > Developer
> Console > File > New > Apex Class) and run tests from there too (Test > New Run). Paste the code, save,
> and skip the `sf project deploy start` and `sf apex run test` commands.

Build a trigger action that stamps a default Description on new Account records when the field is blank.

### Step 1: Create the Trigger Action

Create a new file named `TRG_AccountSetDefaults.cls`:

> **Why `global`?** This lets the managed package resolve the class at runtime without additional setup.
> If you prefer `public inherited sharing`, you'll need a Type Resolver class. The Kern home page health
> check provides the code, or see [Type Resolution](Utilities%20-%20Guide.md#type-resolution-util_typeresolver).

```apex
/**
 * @description Sets a default Description on new Account records.
 *
 * @see TRG_AccountSetDefaults_TEST
 *
 * @author your.name@company.com
 *
 * @group Trigger Actions
 *
 * @date February 2026
 */
global inherited sharing class TRG_AccountSetDefaults extends kern.TRG_Base
	implements kern.IF_Trigger.BeforeInsert
{
	/** @description Default description stamped when the field is blank. */
	@TestVisible
	private static final String DEFAULT_DESCRIPTION = 'New account - pending review';

	/**
	 * @description Stamps a default Description on each Account that has a blank Description.
	 *
	 * @param newRecords The list of Account records being inserted.
	 */
	public void beforeInsert(List<SObject> newRecords)
	{
		for(SObject record : newRecords)
		{
			Account account = (Account)record;

			if(String.isBlank(account.Description))
			{
				account.Description = DEFAULT_DESCRIPTION;
			}
		}
	}
}
```

**Deploy:**

```bash
sf project deploy start -o YourOrgAlias -m "ApexClass:TRG_AccountSetDefaults"
```

### Step 2: Create the Physical Trigger

Create `TRG_Account.trigger`. One per object, one line of logic:

```apex
trigger TRG_Account on Account (before insert)
{
	new kern.TRG_Dispatcher().run();
}
```

Only declare the events you actually need. If you later add `before update` actions, add `before update`
to the trigger declaration.

**Deploy:**

```bash
sf project deploy start -o YourOrgAlias -m "ApexTrigger:TRG_Account"
```

### Step 3: Register Metadata

Create two custom metadata records to wire your action to the trigger event.

#### 3a. Create TriggerSetting (one per object)

<details open>
<summary><strong>macOS/Linux (bash)</strong></summary>

```bash
mkdir -p force-app/main/default/customMetadata
cat > force-app/main/default/customMetadata/kern__TriggerSetting.Account.md-meta.xml << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<CustomMetadata xmlns="http://soap.sforce.com/2006/04/metadata"
    xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
    xmlns:xsd="http://www.w3.org/2001/XMLSchema">
    <label>Account</label>
    <protected>false</protected>
    <values>
        <field>kern__BypassExecution__c</field>
        <value xsi:type="xsd:boolean">false</value>
    </values>
    <values>
        <field>kern__SObjectType__c</field>
        <value xsi:type="xsd:string">Account</value>
    </values>
</CustomMetadata>
EOF
sf project deploy start -o YourOrgAlias \
  -m "CustomMetadata:kern__TriggerSetting.Account" --ignore-conflicts
```

</details>

<details>
<summary><strong>Windows (PowerShell)</strong></summary>

```powershell
New-Item -ItemType Directory -Force -Path force-app/main/default/customMetadata | Out-Null
@'
<?xml version="1.0" encoding="UTF-8"?>
<CustomMetadata xmlns="http://soap.sforce.com/2006/04/metadata"
    xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
    xmlns:xsd="http://www.w3.org/2001/XMLSchema">
    <label>Account</label>
    <protected>false</protected>
    <values>
        <field>kern__BypassExecution__c</field>
        <value xsi:type="xsd:boolean">false</value>
    </values>
    <values>
        <field>kern__SObjectType__c</field>
        <value xsi:type="xsd:string">Account</value>
    </values>
</CustomMetadata>
'@ | Set-Content -Path "force-app/main/default/customMetadata/kern__TriggerSetting.Account.md-meta.xml" -Encoding UTF8
sf project deploy start -o YourOrgAlias -m "CustomMetadata:kern__TriggerSetting.Account" --ignore-conflicts
```

</details>

> **Prefer the UI?** Create this in **Setup > Custom Metadata Types > TriggerSetting > Manage Records > New**:
> Label = `Account`, Name = `Account`, SObjectType__c = `Account`, BypassExecution__c = unchecked.

#### 3b. Create TriggerAction (one per action+event)

<details open>
<summary><strong>macOS/Linux (bash)</strong></summary>

```bash
cat > force-app/main/default/customMetadata/kern__TriggerAction.AccountSetDefaults_BeforeInsert.md-meta.xml << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<CustomMetadata xmlns="http://soap.sforce.com/2006/04/metadata"
    xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
    xmlns:xsd="http://www.w3.org/2001/XMLSchema">
    <label>Account Set Defaults - Before Insert</label>
    <protected>false</protected>
    <values>
        <field>kern__AllowNonSelfInitiated__c</field>
        <value xsi:type="xsd:boolean">true</value>
    </values>
    <values>
        <field>kern__AllowRecursion__c</field>
        <value xsi:type="xsd:boolean">false</value>
    </values>
    <values>
        <field>kern__ApexClassName__c</field>
        <value xsi:type="xsd:string">TRG_AccountSetDefaults</value>
    </values>
    <values>
        <field>kern__BypassExecution__c</field>
        <value xsi:type="xsd:boolean">false</value>
    </values>
    <values>
        <field>kern__Description__c</field>
        <value xsi:type="xsd:string">Stamps a default Description on new Account records when blank.</value>
    </values>
    <values>
        <field>kern__Event__c</field>
        <value xsi:type="xsd:string">Before Insert</value>
    </values>
    <values>
        <field>kern__Order__c</field>
        <value xsi:type="xsd:double">10.0</value>
    </values>
    <values>
        <field>kern__TriggerSetting__c</field>
        <value xsi:type="xsd:string">Account</value>
    </values>
</CustomMetadata>
EOF
sf project deploy start -o YourOrgAlias \
  -m "CustomMetadata:kern__TriggerAction.AccountSetDefaults_BeforeInsert" --ignore-conflicts
```

</details>

<details>
<summary><strong>Windows (PowerShell)</strong></summary>

```powershell
@'
<?xml version="1.0" encoding="UTF-8"?>
<CustomMetadata xmlns="http://soap.sforce.com/2006/04/metadata"
    xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
    xmlns:xsd="http://www.w3.org/2001/XMLSchema">
    <label>Account Set Defaults - Before Insert</label>
    <protected>false</protected>
    <values>
        <field>kern__AllowNonSelfInitiated__c</field>
        <value xsi:type="xsd:boolean">true</value>
    </values>
    <values>
        <field>kern__AllowRecursion__c</field>
        <value xsi:type="xsd:boolean">false</value>
    </values>
    <values>
        <field>kern__ApexClassName__c</field>
        <value xsi:type="xsd:string">TRG_AccountSetDefaults</value>
    </values>
    <values>
        <field>kern__BypassExecution__c</field>
        <value xsi:type="xsd:boolean">false</value>
    </values>
    <values>
        <field>kern__Description__c</field>
        <value xsi:type="xsd:string">Stamps a default Description on new Account records when blank.</value>
    </values>
    <values>
        <field>kern__Event__c</field>
        <value xsi:type="xsd:string">Before Insert</value>
    </values>
    <values>
        <field>kern__Order__c</field>
        <value xsi:type="xsd:double">10.0</value>
    </values>
    <values>
        <field>kern__TriggerSetting__c</field>
        <value xsi:type="xsd:string">Account</value>
    </values>
</CustomMetadata>
'@ | Set-Content -Path "force-app/main/default/customMetadata/kern__TriggerAction.AccountSetDefaults_BeforeInsert.md-meta.xml" -Encoding UTF8
sf project deploy start -o YourOrgAlias -m "CustomMetadata:kern__TriggerAction.AccountSetDefaults_BeforeInsert" --ignore-conflicts
```

</details>

> **Prefer the UI?** Create in **Setup > Custom Metadata Types > TriggerAction > Manage Records > New**:
> Label = `Account Set Defaults - Before Insert`, Name = `AccountSetDefaults_BeforeInsert`,
> ApexClassName__c = `TRG_AccountSetDefaults`, Event__c = `Before Insert`,
> TriggerSetting__c = (select) `Account`, Order__c = `10`, AllowRecursion__c = unchecked,
> AllowNonSelfInitiated__c = checked.

> **ApexClassName__c** is the simple class name, not namespace-prefixed. **Order__c** controls execution
> sequence (lower runs first). To run the same class for multiple events, create multiple TriggerAction records.

### Step 4: Verify

Open **Developer Console > Debug > Open Execute Anonymous Window** and run:

```apex
Account newAccount = new Account(Name = 'Test Company', Phone = '555-0100');
insert newAccount;

Account result = [SELECT Description FROM Account WHERE Id = :newAccount.Id];
System.debug('Description: ' + result.Description);
```

**Expected output:**

```text
Description: New account - pending review
```

**Key patterns:**

- **`extends kern.TRG_Base`** -- Provides trigger context, bypass control, and `triggerOldMap`
- **`implements kern.IF_Trigger.BeforeInsert`** -- Each interface maps to one trigger event
- **`inherited sharing`** -- Respects the calling context's sharing mode
- **Loop over all records** -- Always bulk-safe (process every record in the list)
- **Before context** -- Modify records directly, no DML needed

---

## Tier 2: Test It (~3 minutes)

> **Setting up trigger action metadata for tests:**
>
> - From a subscriber `@IsTest` class: `kern.TST_Factory.newTriggerActionForContext(handlerClass, kern.TST_Factory.newTriggerSetting('Account'), TriggerOperation.BEFORE_INSERT)` works.
> - From anonymous Apex or production setup scripts: those factory methods are `@TestVisible private` and not callable. Deploy CMDT records via XML instead (as shown in Tier 1).

Create `TRG_AccountSetDefaults_TEST.cls`:

```apex
/**
 * @description Tests for TRG_AccountSetDefaults.
 *
 * @see TRG_AccountSetDefaults
 *
 * @author your.name@company.com
 *
 * @group Trigger Actions
 *
 * @date February 2026
 */
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest(SeeAllData=false IsParallel=true)
private class TRG_AccountSetDefaults_TEST
{
	/** @description Handler class name used to activate the trigger action in tests. */
	private static final String HANDLER_CLASS = TRG_AccountSetDefaults.class.getName();

	/** @description Tests that Description defaults when blank. */
	@IsTest
	private static void shouldStampDefaultDescriptionWhenBlank()
	{
		kern.UTIL_ValidationRule.bypassObject('Account');

		kern.TST_Factory.newTriggerActionForContext
		(
			HANDLER_CLASS,
			kern.TST_Factory.newTriggerSetting('Account'),
			TriggerOperation.BEFORE_INSERT
		);

		Account record = (Account)kern.TST_Builder.of(Account.SObjectType)
			.withOverride(Account.Description, null)
			.build();

		Account result = [SELECT Description FROM Account WHERE Id = :record.Id];
		Assert.areEqual
		(
			TRG_AccountSetDefaults.DEFAULT_DESCRIPTION,
			result.Description,
			'Description should be stamped when blank'
		);
	}

	/** @description Tests that a pre-populated Description is not overwritten. */
	@IsTest
	private static void shouldPreserveDescriptionWhenAlreadySet()
	{
		kern.UTIL_ValidationRule.bypassObject('Account');

		kern.TST_Factory.newTriggerActionForContext
		(
			HANDLER_CLASS,
			kern.TST_Factory.newTriggerSetting('Account'),
			TriggerOperation.BEFORE_INSERT
		);

		Account record = (Account)kern.TST_Builder.of(Account.SObjectType)
			.withOverride(Account.Description, 'Custom description')
			.build();

		Account result = [SELECT Description FROM Account WHERE Id = :record.Id];
		Assert.areEqual('Custom description', result.Description, 'Existing Description should be preserved');
	}
}
```

**Deploy and run:**

```bash
sf project deploy start -o YourOrgAlias -m "ApexClass:TRG_AccountSetDefaults_TEST"
sf apex run test -o YourOrgAlias -t TRG_AccountSetDefaults_TEST --code-coverage --synchronous --result-format human
```

**Expected:** 2 tests passing, 100% coverage on `TRG_AccountSetDefaults`.

> **About the annotations:** `@IsTest(SeeAllData=false IsParallel=true)` enables parallel execution and
> explicitly declares no org data access. `@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')`
> suppresses a static analysis rule about `System.runAs()` -- fine for quick starts.

> **Why `kern.UTIL_ValidationRule.bypassObject('Account')` at the start of each test?**
> The subscriber org ships with Account validation rules. Bypassing them isolates the trigger action
> under test from unrelated validation failures.

> **Why `kern.TST_Factory.newTriggerActionForContext` instead of relying on deployed metadata?**
> This in-memory activation is scoped to the test transaction only and prevents deployed CMDT records
> from interfering. It works from any subscriber `@IsTest` class. For anonymous Apex or production
> setup scripts, deploy the CMDT records as XML (Tier 1 Step 3) instead -- those factory methods are
> `@TestVisible private` and not callable outside `@IsTest` context.

### Testing Flow Actions with TST_InvokeFlowMock

If you have `TriggerAction__mdt` records configured as flow actions (`kern__FlowName__c` populated,
`kern__ApexClassName__c` blank), `kern.TST_InvokeFlowMock` lets you unit-test orchestration without
deploying throwaway flows.

```apex
@IsTest
private static void shouldRouteFlowFailureThroughLogAndContinue()
{
	kern.TST_InvokeFlowMock.forFlow('Account_SetDefaults')
		.fail('Synthetic flow failure for orchestration test')
		.register();

	Account record = (Account)kern.TST_Builder.of(Account.SObjectType)
		.withOverride(Account.Industry, 'Technology')
		.build();

	kern.TST_InvokeFlowMock.assertInvoked('Account_SetDefaults', 1);

	Account observed = (Account)kern.TST_InvokeFlowMock.getLastInputRecord('Account_SetDefaults');
	Assert.areEqual('Technology', observed.Industry, 'Flow should see post-Apex Industry value');
}
```

| Method                                                                      | Purpose                                              |
|-----------------------------------------------------------------------------|------------------------------------------------------|
| `kern.TST_InvokeFlowMock.forFlow(name).succeed().register()`                | Mock a successful flow run                           |
| `kern.TST_InvokeFlowMock.forFlow(name).fail(message).register()`            | Mock a flow that returns an error                    |
| `kern.TST_InvokeFlowMock.forFlow(name).withOutputRecord(record).register()` | Mock a flow that returns an output record            |
| `kern.TST_InvokeFlowMock.forFlow(name).throwOnStart(exception).register()`  | Mock a runtime exception                             |
| `kern.TST_InvokeFlowMock.assertInvoked(name, count)`                        | Assert the flow was invoked an exact number of times |
| `kern.TST_InvokeFlowMock.assertNotInvoked(name)`                            | Assert the flow was never invoked                    |
| `kern.TST_InvokeFlowMock.getLastInputRecord(name)`                          | Inspect the `record` SObject the flow received       |
| `kern.TST_InvokeFlowMock.getLastInputPriorRecord(name)`                     | Inspect `recordPrior` for update-context tests       |
| `kern.TST_InvokeFlowMock.clear()`                                           | Reset all registered mocks and invocation history    |

> `TST_InvokeFlowMock` tests orchestration -- that the framework called the right flow at the right time.
> It does not test flow logic. Write a separate `_INTEGRATION_TEST` class for end-to-end flow verification.

---

## Tier 3: Production Patterns (~10 minutes)

### Available Interfaces

| Interface                       | Method                                       | Use Case                 |
|---------------------------------|----------------------------------------------|--------------------------|
| `kern.IF_Trigger.BeforeInsert`  | `beforeInsert(List<SObject>)`                | Set defaults, validate   |
| `kern.IF_Trigger.BeforeUpdate`  | `beforeUpdate(List<SObject>, List<SObject>)` | Validate changes         |
| `kern.IF_Trigger.AfterInsert`   | `afterInsert(List<SObject>)`                 | Create related records   |
| `kern.IF_Trigger.AfterUpdate`   | `afterUpdate(List<SObject>, List<SObject>)`  | Cascade updates          |
| `kern.IF_Trigger.BeforeDelete`  | `beforeDelete(List<SObject>)`                | Prevent deletion         |
| `kern.IF_Trigger.AfterDelete`   | `afterDelete(List<SObject>)`                 | Clean up related records |
| `kern.IF_Trigger.AfterUndelete` | `afterUndelete(List<SObject>)`               | Restore related data     |

### Comparing Old vs New Values (Update Context)

`triggerOldMap` is a lazy-loaded `Map<Id, SObject>` on `kern.TRG_Base`. Use it in update contexts to compare old and new values:

```apex
global inherited sharing class TRG_AccountIndustryChanged extends kern.TRG_Base
	implements kern.IF_Trigger.AfterUpdate
{
	/**
	 * @description Logs when an Account's Industry field changes.
	 *
	 * @param newRecords The list of updated Account records.
	 * @param oldRecords The list of Account records before the update.
	 */
	public void afterUpdate(List<SObject> newRecords, List<SObject> oldRecords)
	{
		for(Integer i = 0; i < newRecords.size(); i++)
		{
			Account newAccount = (Account)newRecords[i];
			Account oldAccount = (Account)oldRecords[i];

			if(newAccount.Industry != oldAccount.Industry)
			{
				kern.LOG_Builder.build()
					.info('Industry changed from ' + oldAccount.Industry + ' to ' + newAccount.Industry)
					.at('TRG_AccountIndustryChanged.afterUpdate')
					.forRecord(newAccount.Id)
					.emit();
			}
		}
	}
}
```

Update the physical trigger to declare `after update`, create a matching `TriggerAction__mdt` record
with `Event__c = After Update` and `TriggerSetting__c = Account`.

### Bypass Mechanisms

Bypass triggers at runtime without metadata changes:

```apex
// Bypass a single action
kern.TRG_Base.bypassAction('TRG_AccountSetDefaults');
insert new Account(Name = 'Bypass Test', Phone = '555-0100');
kern.TRG_Base.clearActionBypass('TRG_AccountSetDefaults');

// Bypass all actions for an object
kern.TRG_Base.bypass(Account.SObjectType);
// ... DML here won't fire any Account triggers ...
kern.TRG_Base.clearBypass(Account.SObjectType);
```

Or declaratively: set `BypassExecution__c = true` on the `TriggerSetting__mdt` (all actions) or
`TriggerAction__mdt` (single action) record.

> **Every bypass is audit-logged.** `bypass()`, `bypassAction()`, and their clear counterparts each emit
> a WARN `LogEntry__c` with category `BypassEvent` -- capturing action, type, target, and (if set) reason.
> Query `kern__LogEntry__c` after the fact to answer "who bypassed which trigger, when, and why?" See the
> [Triggers Guide](Triggers%20-%20Guide.md#bypass-mechanisms) for the full bypass API.

### Feature Flag Integration

Gate a trigger action on a Feature Flag using `RequiredFeatureFlag__c`. When the flag is disabled or
missing, the action is skipped automatically. Add this field to your `TriggerAction__mdt` record:

```xml
<values>
    <field>kern__RequiredFeatureFlag__c</field>
    <value xsi:type="xsd:string">AccountDefaults</value>
</values>
```

See [Fast Start - Feature Flags](Fast%20Start%20-%20Feature%20Flags.md) for creating `FeatureFlag__mdt` records.

### Ordering Multiple Actions

Set `Order__c` on each `TriggerAction__mdt` record. Lower values run first:

| Order | Action                 | Purpose                  |
|-------|------------------------|--------------------------|
| 10    | TRG_AccountSetDefaults | Set defaults             |
| 20    | TRG_AccountValidate    | Validate required fields |
| 30    | TRG_AccountNotify      | Send notifications       |

---

## Using Flow as a Trigger Action

Register an auto-launched flow as a trigger action by setting `kern__FlowName__c` on a
`TriggerAction__mdt` row and leaving `kern__ApexClassName__c` blank. The framework dispatches via its
built-in flow runner, and the flow inherits ordering, bypass, recursion control, and feature-flag gating.

### Variable contract

| Variable      | Type                                | Direction      | Required for                      |
|---------------|-------------------------------------|----------------|-----------------------------------|
| `record`      | The trigger object (e.g. `Account`) | Input + Output | All 7 contexts                    |
| `recordPrior` | The trigger object (e.g. `Account`) | Input only     | Before Update / After Update only |

### Configure the TriggerAction__mdt record

```xml
<?xml version="1.0" encoding="UTF-8"?>
<CustomMetadata xmlns="http://soap.sforce.com/2006/04/metadata"
    xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema">
    <label>Account Set Defaults via Flow - Before Insert</label>
    <protected>false</protected>
    <values><field>kern__FlowName__c</field><value xsi:type="xsd:string">Account_SetDefaults</value></values>
    <values><field>kern__FailureAction__c</field><value xsi:type="xsd:string">LogAndContinue</value></values>
    <values><field>kern__Event__c</field><value xsi:type="xsd:string">Before Insert</value></values>
    <values><field>kern__Order__c</field><value xsi:type="xsd:double">100.0</value></values>
    <values><field>kern__TriggerSetting__c</field><value xsi:type="xsd:string">Account</value></values>
</CustomMetadata>
```

`kern__FailureAction__c`: `LogAndContinue` (default) emits a `LogEntryEvent__e` and lets DML proceed;
`BlockDml` calls `record.addError(...)` to stop the save and surface the error to the user. Setting both
`kern__FlowName__c` and `kern__ApexClassName__c` fails the `MutuallyExclusiveTarget` validation rule.

Full developer reference: [Triggers - Guide → Flow as a Trigger Action](Triggers%20-%20Guide.md#flow-as-a-trigger-action).

---

## Common Issues

| Problem                                                               | Cause                                          | Fix                                                                                            |
|-----------------------------------------------------------------------|------------------------------------------------|------------------------------------------------------------------------------------------------|
| `Type for Class Name not found`                                       | Class is `public`, not visible cross-namespace | Make the class `global`, or set up a Type Resolver                                             |
| Action doesn't fire                                                   | Missing or misconfigured metadata              | Check `TriggerAction__mdt` has correct `ApexClassName__c`, `Event__c`, and `TriggerSetting__c` |
| Trigger doesn't fire                                                  | Physical trigger missing the event             | Add the event to the trigger declaration (e.g., `before update`)                               |
| `BypassExecution__c` is checked                                       | Action or setting is bypassed                  | Uncheck on both the `TriggerSetting__mdt` and `TriggerAction__mdt` records                     |
| Governor limit: SOQL in loop                                          | Querying inside the record loop                | Collect IDs first, query once outside the loop                                                 |
| Not bulk-safe                                                         | Processing only `newRecords[0]`                | Always loop over all records in the list                                                       |
| Sharing not declared                                                  | Missing sharing keyword on class               | Add `inherited sharing` (default) or `with sharing`                                            |
| `kern.TST_Factory.newTriggerActionForContext` fails in anonymous Apex | Method is `@TestVisible private`               | Call it only from `@IsTest` classes; use deployed CMDT XML for anonymous Apex setup            |

---

## What You Now Know

| Concept                   | What It Does                                                        |
|---------------------------|---------------------------------------------------------------------|
| **Physical trigger**      | One per object -- `new kern.TRG_Dispatcher().run()`                 |
| **`TRG_Base`**            | Base class -- provides context, bypass control, and `triggerOldMap` |
| **`IF_Trigger.*`**        | Interfaces for each event -- `BeforeInsert`, `AfterUpdate`, etc.    |
| **`TriggerSetting__mdt`** | Per-object config -- links an SObject to the framework              |
| **`TriggerAction__mdt`**  | Per-action config -- wires a class to an event with ordering        |

**Key patterns:**

- **One class per action** -- single responsibility, independently testable
- **`inherited sharing`** -- default sharing mode for trigger actions
- **Metadata-driven ordering** -- `Order__c` controls execution sequence
- **Declarative bypass** -- `BypassExecution__c` checkbox, no code deployment needed
- **Audit-logged bypass** -- every bypass call emits a WARN `LogEntry__c` with category `BypassEvent`
- **`global`** -- required for subscriber classes (or `public` with Type Resolver)
- **Bulk-safe** -- always loop over all records, no SOQL inside loops
- **Test setup** -- `kern.TST_Factory.newTriggerActionForContext` works from `@IsTest` classes only;
  deploy CMDT XML for any other context

---

## Next Steps

| Topic                                                    | Link                                                                          |
|----------------------------------------------------------|-------------------------------------------------------------------------------|
| Custom Validations (metadata-driven rules)               | [Fast Start - Custom Validations](Fast%20Start%20-%20Custom%20Validations.md) |
| Selectors (query patterns)                               | [Fast Start - Selectors](Fast%20Start%20-%20Selectors.md)                     |
| DML Builder (after context)                              | [Fast Start - DML](Fast%20Start%20-%20DML.md)                                 |
| E2E Testing (verify triggers fire end-to-end)            | [Fast Start - E2E Testing](Fast%20Start%20-%20E2E%20Testing.md)               |
| Complete Triggers Guide                                  | [Triggers - Guide](Triggers%20-%20Guide.md)                                   |
| Change Data Capture actions (react to committed changes) | [Triggers - Guide](Triggers%20-%20Guide.md#change-data-capture-actions)       |
| Post-trigger actions (run logic once per transaction)    | [Triggers - Guide](Triggers%20-%20Guide.md#post-trigger-actions)              |
| Bypass Mechanisms                                        | [Triggers - Guide](Triggers%20-%20Guide.md#bypass-mechanisms)                 |
| Feature Flag Integration                                 | [Triggers - Guide](Triggers%20-%20Guide.md#feature-flag-integration)          |
