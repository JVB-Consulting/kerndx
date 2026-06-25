---
navOrder: 10
---

# Fast Start - Trigger Actions

**Framework:** KernDX | **Total time:** ~20 minutes

**What this is:** A way to put trigger logic into small, focused Apex classes (one per behaviour) and wire them to an object through configuration records, so you can add, reorder, or switch a behaviour off without editing or redeploying the trigger. **Why it exists:** Hand-written triggers tend to grow into one large file that is hard to read, test, or change safely; this keeps each behaviour separate and independently testable. **Who should follow it:** developers and admins adding automation to an object. **When to use it:** any time you'd otherwise write or extend a trigger.

**Before you start:**

- [ ] KernDX package installed in your org
- [ ] Org configured post-install (verify with the **Kern** app's Health Check, see [Installation guide](Installation.md#post-install-configuration))
- [ ] CLI authenticated (`sf org open -o YourOrgAlias` to verify), or just use the Developer Console
  (Gear Icon > Developer Console) for all Apex work
- [ ] Working in a sandbox or scratch org (not production)

> **Subscriber orgs:** Use `kern.ClassName` when extending framework classes (e.g., `kern.TRG_Base`,
> `kern.IF_Trigger.BeforeInsert`). Your own classes don't need a namespace prefix: the framework's
> Type Resolver (how it finds the Apex classes in your namespace, once you tell it where to look) handles
> this for you.

**What you'll build:** A trigger action that stamps default field values on new records. You'll create the
handler class, wire it up with metadata, and add a test class with 100% coverage.

**Success looks like:** You insert an Account, see the default Description populated automatically, and
have 2 passing tests with 100% coverage.

**In one line:** `new kern.TRG_Dispatcher().run();` is the only line in the trigger; all logic lives in handler
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

The aim is to keep each trigger behaviour small, separate, and easy to switch on or off without a code change.
To get there, the framework splits the work into four pieces:

| Component                                     | Role                                          | You Create           |
|-----------------------------------------------|-----------------------------------------------|----------------------|
| **Physical trigger** (`TRG_Account`)          | The one-line trigger file that hands control to the framework | Once per object      |
| **Trigger action** (`TRG_AccountSetDefaults`) | One class per behaviour                        | One per action       |
| **`TriggerSetting__mdt`**                     | Per-object configuration                      | One per object       |
| **`TriggerAction__mdt`**                      | Wires actions to events and controls their run order | One per action+event |

**Why?** Adding a behaviour, removing one, or changing the order they run becomes a configuration change rather
than a code change. Each behaviour lives in its own class, so you can test it on its own. And you never end up
with one large trigger file that everyone is afraid to touch.

---

## Tier 1: Build It (~5 minutes)

> **No local project?** You can create classes directly in the Developer Console (Gear Icon > Developer
> Console > File > New > Apex Class) and run tests from there too (Test > New Run). Paste the code, save,
> and skip the `sf project deploy start` and `sf apex run test` commands.

Build a trigger action that stamps a default Description on new Account records when the field is blank.

### Step 1: Create the Trigger Action

Create a new file named `TRG_AccountSetDefaults.cls`:

> **Why `global`?** Marking the class `global` lets the framework find and run it at runtime with no extra
> setup. If you'd rather keep it `public inherited sharing`, you'll need a Type Resolver class so the
> framework knows where to look. The Kern home page health check provides that code, or see
> [Type Resolution](Utilities%20-%20Guide.md#type-resolution-util_typeresolver).

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

- **`extends kern.TRG_Base`**: gives you trigger context, bypass control, and `triggerOldMap`
- **`implements kern.IF_Trigger.BeforeInsert`**: each interface maps to one trigger event
- **`inherited sharing`**: respects the calling context's sharing mode
- **Loop over all records**: always bulk-safe, because you process every record in the list
- **Before context**: modify records directly, no DML needed

---

## Tier 2: Test It (~3 minutes)

> **Testing a trigger action in your own org:** call the handler directly. Build an in-memory record with
> `kern.TST_Builder` (using `.withoutInsertion()` so no DML runs), call your handler's method, and assert on
> the record. This needs no framework metadata setup and fully covers your handler's logic. Calling the
> handler directly is the supported pattern.

Create `TRG_AccountSetDefaults_TEST.cls`:

```apex
/**
 * @description Tests for TRG_AccountSetDefaults.
 *
 * Invokes the handler directly (unit-style) -- the supported pattern for testing a trigger
 * action in a subscriber org. This exercises the handler logic with no framework metadata setup.
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
	/** @description Tests that Description defaults when blank. */
	@IsTest
	private static void shouldStampDefaultDescriptionWhenBlank()
	{
		Account record = (Account)kern.TST_Builder.of(Account.SObjectType)
			.withOverride(Account.Description, null)
			.withoutInsertion()
			.build();

		new TRG_AccountSetDefaults().beforeInsert(new List<SObject>{ record });

		Assert.areEqual
		(
			TRG_AccountSetDefaults.DEFAULT_DESCRIPTION,
			record.Description,
			'Description should be stamped when blank'
		);
	}

	/** @description Tests that a pre-populated Description is not overwritten. */
	@IsTest
	private static void shouldPreserveDescriptionWhenAlreadySet()
	{
		Account record = (Account)kern.TST_Builder.of(Account.SObjectType)
			.withOverride(Account.Description, 'Custom description')
			.withoutInsertion()
			.build();

		new TRG_AccountSetDefaults().beforeInsert(new List<SObject>{ record });

		Assert.areEqual('Custom description', record.Description, 'Existing Description should be preserved');
	}
}
```

**Deploy and run:**

```bash
sf project deploy start -o YourOrgAlias -m "ApexClass:TRG_AccountSetDefaults_TEST"
sf apex run test -o YourOrgAlias -t TRG_AccountSetDefaults_TEST --code-coverage --synchronous --result-format human
```

**Expected:** 2 tests passing, 100% coverage on `TRG_AccountSetDefaults`.

> **About the annotations:** `@IsTest(SeeAllData=false IsParallel=true)` lets the test run in parallel and
> states up front that it touches no org data. `@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')`
> turns off a code-quality rule about `System.runAs()`, which is fine for a quick start.

> **Why invoke the handler directly?** `beforeInsert` is a plain method that takes the trigger records, so
> you can call it straight from the test. You pass it an in-memory `kern.TST_Builder` record, built with
> `.withoutInsertion()` so no DML runs and no validation rules fire. That exercises your logic directly and
> gives 100% coverage with no setup, and it's the supported way to test a handler in your own org. (To check
> the full metadata wiring from end to end, deploy the CMDT from Tier 1 and assert against an inserted record,
> either from an integration test or from the Verify step above.)

### Testing Flow Actions with TST_InvokeFlowMock

Some trigger actions run a flow rather than an Apex class (a `TriggerAction__mdt` record with
`kern__FlowName__c` populated and `kern__ApexClassName__c` blank). For those, `kern.TST_InvokeFlowMock` lets you
unit-test that the right flow is called at the right time, without deploying throwaway flows just for the test.

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

> `TST_InvokeFlowMock` checks that the framework called the right flow at the right time. It does not test what
> the flow itself does. To verify the flow's own logic end to end, write a separate `_INTEGRATION_TEST` class.

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

In an update, you often need to know what a field was before the change. `kern.TRG_Base` gives you
`triggerOldMap`, a `Map<Id, SObject>` of the prior record values (loaded only when you ask for it), so you can
compare old and new:

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

Sometimes you need to turn a trigger off for a moment, for example during a one-off data fix. You can do this
at runtime in code, with no metadata change:

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

You can also do it without code: set `BypassExecution__c = true` on the `TriggerSetting__mdt` record (turns off
all actions for the object) or on a `TriggerAction__mdt` record (turns off a single action).

> **Every bypass is audit-logged.** Whenever a trigger is bypassed, the framework records what happened, so the
> off-switch can't be used quietly. `bypass()`, `bypassAction()`, and their clear counterparts each write a WARN
> `LogEntry__c` with category `BypassEvent`, capturing the action, the type, the target, and a reason if one was
> given. Later you can query `kern__LogEntry__c` to answer "who bypassed which trigger, when, and why?" See the
> [Triggers Guide](Triggers%20-%20Guide.md#bypass-mechanisms) for the full bypass API.

### Feature Flag Integration

You can make a trigger action depend on a Feature Flag, an on/off switch you control without a deployment.
When the flag is off or missing, the action is skipped automatically, so you can release the logic but keep it
dark until you're ready to turn it on. Point an action at a flag with `RequiredFeatureFlag__c`. Add this field
to your `TriggerAction__mdt` record:

```xml
<values>
    <field>kern__RequiredFeatureFlag__c</field>
    <value xsi:type="xsd:string">AccountDefaults</value>
</values>
```

See [Fast Start - Feature Flags](Fast%20Start%20-%20Feature%20Flags.md) for creating `FeatureFlag__mdt` records.

### Ordering Multiple Actions

When several actions run on the same event, you control the sequence with the `Order__c` field on each
`TriggerAction__mdt` record. Lower numbers run first:

| Order | Action                 | Purpose                  |
|-------|------------------------|--------------------------|
| 10    | TRG_AccountSetDefaults | Set defaults             |
| 20    | TRG_AccountValidate    | Validate required fields |
| 30    | TRG_AccountNotify      | Send notifications       |

---

## Using Flow as a Trigger Action

A trigger action doesn't have to be Apex. You can run an auto-launched flow instead, which lets an admin build
the behaviour with no code. To do this, set `kern__FlowName__c` on a `TriggerAction__mdt` row and leave
`kern__ApexClassName__c` blank. The framework runs the flow for you, and the flow gets the same ordering,
bypass, recursion control, and feature-flag gating that an Apex action does.

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

`kern__FailureAction__c` decides what happens if the flow fails. `LogAndContinue` (the default) writes a
`LogEntryEvent__e` and lets the save proceed. `BlockDml` calls `record.addError(...)` to stop the save and show
the error to the user. Note that an action can't be both a flow and an Apex class: if you set both
`kern__FlowName__c` and `kern__ApexClassName__c`, the `MutuallyExclusiveTarget` validation rule rejects it.

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
| Unsure how to test a trigger action handler | Trying to drive the handler through framework metadata setup | Call your handler directly in the test: build a record with `kern.TST_Builder` (`.withoutInsertion()`), call the method, then assert (see Tier 2) |

---

## What You Now Know

| Concept                   | What It Does                                                        |
|---------------------------|---------------------------------------------------------------------|
| **Physical trigger**      | One per object; holds only `new kern.TRG_Dispatcher().run()`        |
| **`TRG_Base`**            | The base class your handlers extend; provides context, bypass control, and `triggerOldMap` |
| **`IF_Trigger.*`**        | One interface per event (`BeforeInsert`, `AfterUpdate`, and so on)  |
| **`TriggerSetting__mdt`** | Per-object config; links an SObject to the framework                |
| **`TriggerAction__mdt`**  | Per-action config; wires a class to an event and sets its order     |

**Key patterns:**

- **One class per action**: each does one thing and can be tested on its own
- **`inherited sharing`**: the default sharing mode for trigger actions
- **Configuration-driven ordering**: `Order__c` controls the run sequence
- **Bypass without code**: the `BypassExecution__c` checkbox, no deployment needed
- **Audit-logged bypass**: every bypass call writes a WARN `LogEntry__c` with category `BypassEvent`
- **`global`**: required for classes in your own org (or `public` with a Type Resolver)
- **Bulk-safe**: always loop over all records, and never put SOQL inside a loop
- **Test setup**: call your handler directly with a `kern.TST_Builder` record (built
  `.withoutInsertion()`); no framework metadata setup needed

---

## Next Steps

- [Custom Validations (metadata-driven rules)](Fast%20Start%20-%20Custom%20Validations.md)
- [Selectors (query patterns)](Fast%20Start%20-%20Selectors.md)
- [DML Builder (after context)](Fast%20Start%20-%20DML.md)
- [E2E Testing (verify triggers fire end-to-end)](Fast%20Start%20-%20E2E%20Testing.md)
- [Complete Triggers Guide](Triggers%20-%20Guide.md)
- [Change Data Capture actions (react to committed changes)](Triggers%20-%20Guide.md#change-data-capture-actions)
- [Post-trigger actions (run logic once per transaction)](Triggers%20-%20Guide.md#post-trigger-actions)
- [Bypass Mechanisms](Triggers%20-%20Guide.md#bypass-mechanisms)
- [Feature Flag Integration](Triggers%20-%20Guide.md#feature-flag-integration)
