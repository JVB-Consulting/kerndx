---
navOrder: 10
---

# Fast Start - Trigger Actions

**Framework:** KernDX | **Total time:** ~20 minutes

**What this is:** A way to put trigger logic into small, focused Apex classes (one per behaviour) and wire them to an object through configuration records, so you can add, reorder, or switch a behaviour off without editing or redeploying the trigger. **Why it exists:** Hand-written triggers tend to grow into one large file that is hard to read, test, or change safely; this keeps each behaviour separate and independently testable. **Who should follow it:** developers and admins adding automation to an object. **When to use it:** any time you'd otherwise write or extend a trigger. If a single Flow or a simple validation rule already covers what you need, use that first; this pattern earns its keep once an object has real Apex logic, several behaviours, or an order you need to control.

> **Namespaces in code samples:** `kern.` on a class and `kern__` on an object, field, or metadata type mark the managed package's namespace.
> On the managed package, framework references need those prefixes even where a sample omits them; repackaged under your own namespace, replace `kern`/`kern__`
> with your prefix; on an unmanaged deploy, drop them. See [How to read the code samples](Installation.md#how-to-read-the-code-samples).

**What you'll build:** A trigger action that stamps default field values on new records. You'll create the
handler class, wire it up with metadata, and add a test class with 100% coverage.

**Success looks like:** You insert an Account, see the default Description populated automatically, and
have 2 passing tests with 100% coverage.

**In one line:** `new kern.TRG_Dispatcher().run();` is the only line in the trigger; all logic lives in handler
classes configured via Custom Metadata.

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
2. [How It Works](#how-it-works)
3. [Tier 1: Build It (~5 minutes)](#tier-1-build-it-5-minutes)
    - [Step 1: Create the trigger action](#step-1-create-the-trigger-action)
    - [Step 2: Create the physical trigger](#step-2-create-the-physical-trigger)
    - [Step 3: Register the action](#step-3-register-the-action)
    - [Step 4: Verify](#step-4-verify)
4. [Tier 2: Test It (~3 minutes)](#tier-2-test-it-3-minutes)
    - [Step 5: Write and run the test](#step-5-write-and-run-the-test)
    - [Testing Flow Actions with TST_InvokeFlowMock](#testing-flow-actions-with-tst_invokeflowmock)
5. [Tier 3: Production Patterns (~10 minutes)](#tier-3-production-patterns-10-minutes)
    - [Available Interfaces](#available-interfaces)
    - [Comparing Old vs New Values (Update Context)](#comparing-old-vs-new-values-update-context)
    - [Bypass Mechanisms](#bypass-mechanisms)
    - [Feature Flag Integration](#feature-flag-integration)
    - [Ordering Multiple Actions](#ordering-multiple-actions)
6. [Using Flow as a Trigger Action](#using-flow-as-a-trigger-action)
    - [Variable contract](#variable-contract)
    - [Configure the TriggerAction__mdt record](#configure-the-triggeraction__mdt-record)
    - [Clean up](#clean-up)
7. [Common Issues](#common-issues)
    - [Step 1: Create the trigger action](#step-1-create-the-trigger-action-1)
    - [Step 2: Create the physical trigger](#step-2-create-the-physical-trigger-1)
    - [Step 3: Register the action](#step-3-register-the-action-1)
    - [Step 4: Verify](#step-4-verify-1)
    - [Step 5: Write and run the test](#step-5-write-and-run-the-test-1)
    - [Clean up](#clean-up-1)
8. [What You Now Know](#what-you-now-know)
9. [Next Steps](#next-steps)

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
> and skip the terminal commands.

Build a trigger action that stamps a default Description on new Account records when the field is blank.

### Step 1: Create the trigger action

A trigger action is one small class that does one job. This one fills in a default Description when someone creates
an Account and leaves it blank. You create an empty class with one command, paste the code into it, then send it to
your org.

**1. In the terminal**, from your project's top folder, create the empty class:

```shell
sf apex generate class --name TRG_AccountSetDefaults --output-dir force-app/main/default/classes
```

You should see two files created in `force-app/main/default/classes`: `TRG_AccountSetDefaults.cls` and its
companion of the same name ending in `.cls-meta.xml`.

The second file tells Salesforce which API version the class uses. You never edit it, but a deploy fails without it.

**2. In your editor**, open this file, delete what is there, paste the code below in, and save:

```text
force-app/main/default/classes/TRG_AccountSetDefaults.cls
```

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

**3. In the terminal**, send the class to your org:

```shell
sf project deploy start -o YourOrgAlias -m "ApexClass:TRG_AccountSetDefaults"
```

You should see `Status: Succeeded`, with `TRG_AccountSetDefaults` listed as created.

Something went wrong? See [Common Issues, Step 1](#step-1-create-the-trigger-action-1).

### Step 2: Create the physical trigger

The physical trigger is the one-line trigger file that hands control to the framework. You need one per object, and
it holds one line of logic. You create it with one command, replace what the command wrote, then send it to your org.

**1. In the terminal**, from your project's top folder, create the trigger:

```shell
sf apex generate trigger --name TRG_Account --sobject Account --event "before insert" --output-dir force-app/main/default/triggers
```

You should see two files created in `force-app/main/default/triggers`: `TRG_Account.trigger` and its
`TRG_Account.trigger-meta.xml` companion.

**2. In your editor**, open this file, delete what is there (the command writes an empty trigger), paste the code
below in, and save:

```text
force-app/main/default/triggers/TRG_Account.trigger
```

```apex
trigger TRG_Account on Account (before insert)
{
	new kern.TRG_Dispatcher().run();
}
```

Only declare the events you actually need. If you later add `before update` actions, add `before update`
to the trigger declaration.

**3. In the terminal**, send the trigger to your org:

```shell
sf project deploy start -o YourOrgAlias -m "ApexTrigger:TRG_Account"
```

You should see `Status: Succeeded`, with `TRG_Account` listed as created.

Something went wrong? See [Common Issues, Step 2](#step-2-create-the-physical-trigger-1).

### Step 3: Register the action

Two configuration records tell the framework which object the trigger belongs to and which class runs on which
event. You create each one in Setup, then pull it into your project so it is under source control with your code.

#### Step 3.1: Create the trigger setting

**1. In Salesforce**, open Setup, then Custom Metadata Types, then **Trigger Setting**, then **Manage Trigger
Settings**, then **New**, and save a record with these values:

| Field                | API name                   | Value     |
|----------------------|----------------------------|-----------|
| Label                | `MasterLabel`              | `Account` |
| Trigger Setting Name | `DeveloperName`            | `Account` |
| SObject Type         | `kern__SObjectType__c`     | `Account` |
| Bypass Execution     | `kern__BypassExecution__c` | unchecked |

**2. In the terminal**, pull the record into your project:

```shell
sf project retrieve start -o YourOrgAlias -m "CustomMetadata:kern__TriggerSetting.Account"
```

You should see one file created under `force-app/main/default/customMetadata`, named after the record.

Something went wrong? See [Common Issues, Step 3](#step-3-register-the-action-1).

#### Step 3.2: Create the trigger action record

**1. In Salesforce**, open Setup, then Custom Metadata Types, then **Trigger Action**, then **Manage Trigger
Actions**, then **New**, and save a record with these values:

| Field                    | API name                         | Value                                                             |
|--------------------------|----------------------------------|-------------------------------------------------------------------|
| Label                    | `MasterLabel`                    | `Account Set Defaults - Before Insert`                            |
| Trigger Action Name      | `DeveloperName`                  | `AccountSetDefaults_BeforeInsert`                                 |
| Apex Class Name          | `kern__ApexClassName__c`         | `TRG_AccountSetDefaults`                                          |
| Event                    | `kern__Event__c`                 | `Before Insert`                                                   |
| Trigger Setting          | `kern__TriggerSetting__c`        | `Account`                                                         |
| Order                    | `kern__Order__c`                 | `10`                                                              |
| Allow Recursion          | `kern__AllowRecursion__c`        | unchecked                                                         |
| Allow Non Self-Initiated | `kern__AllowNonSelfInitiated__c` | checked                                                           |
| Bypass Execution         | `kern__BypassExecution__c`       | unchecked                                                         |
| Description              | `kern__Description__c`           | `Stamps a default Description on new Account records when blank.` |

**2. In the terminal**, pull it in:

```shell
sf project retrieve start -o YourOrgAlias -m "CustomMetadata:kern__TriggerAction.AccountSetDefaults_BeforeInsert"
```

You should see one file created under `force-app/main/default/customMetadata`, named after the record.

> **Apex Class Name** is the simple class name, not namespace-prefixed. **Order** controls the run sequence (lower
> runs first). To run the same class for several events, create one Trigger Action record per event.

Something went wrong? See [Common Issues, Step 3](#step-3-register-the-action-1).

### Step 4: Verify

Insert one Account without a Description and read back what the trigger action stamped on it.

**In Salesforce**, open the Developer Console (the gear icon, then Developer Console), then Debug, then Open Execute
Anonymous Window, and run:

```apex
Account newAccount = new Account(Name = 'Test Company', Phone = '555-0100');
insert newAccount;

Account result = [SELECT Description FROM Account WHERE Id = :newAccount.Id];
System.debug('Description: ' + result.Description);
```

You should see this line in the log:

```text
Description: New account - pending review
```

Something went wrong? See [Common Issues, Step 4](#step-4-verify-1).

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

### Step 5: Write and run the test

The test class checks both cases: a blank Description gets the default, and one that is already filled in is left
alone. You create the empty class with one command, paste the code into it, send it to your org, then run it.

**1. In the terminal**, from your project's top folder, create the empty test class:

```shell
sf apex generate class --name TRG_AccountSetDefaults_TEST --output-dir force-app/main/default/classes
```

You should see two files created in `force-app/main/default/classes`: `TRG_AccountSetDefaults_TEST.cls` and its
companion of the same name ending in `.cls-meta.xml`.

**2. In your editor**, open this file, delete what is there, paste the code below in, and save:

```text
force-app/main/default/classes/TRG_AccountSetDefaults_TEST.cls
```

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
@IsTest(seeAllData=false isParallel=true)
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

**3. In the terminal**, send the test class to your org:

```shell
sf project deploy start -o YourOrgAlias -m "ApexClass:TRG_AccountSetDefaults_TEST"
```

You should see `Status: Succeeded`, with `TRG_AccountSetDefaults_TEST` listed as created.

**4. In the terminal**, run the test:

```shell
sf apex run test -o YourOrgAlias -t TRG_AccountSetDefaults_TEST --code-coverage --synchronous --result-format human
```

You should see 2 tests passing and 100% coverage on `TRG_AccountSetDefaults`: both tests show `Pass`, the summary
line `Outcome` reads `Passed`, and the coverage table shows `TRG_AccountSetDefaults` at `100%`. It may also list the
trigger `TRG_Account` with low or no coverage: the trigger has no test of its own.

> **About the annotations:** `@IsTest(seeAllData=false isParallel=true)` lets the test run in parallel and
> states up front that it touches no org data. `@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')`
> turns off a code-quality rule about `System.runAs()`, which is fine for a quick start.

> **Why invoke the handler directly?** `beforeInsert` is a plain method that takes the trigger records, so
> you can call it straight from the test. You pass it an in-memory `kern.TST_Builder` record, built with
> `.withoutInsertion()` so no DML runs and no validation rules fire. That exercises your logic directly and
> gives 100% coverage with no setup, and it's the supported way to test a handler in your own org. (To check
> the full metadata wiring from end to end, keep the records from Step 3 in your org and assert against an inserted
> record, either from an integration test or from the Verify step above.)

Something went wrong? See [Common Issues, Step 5](#step-5-write-and-run-the-test-1).

### Testing Flow Actions with TST_InvokeFlowMock

Some trigger actions run a flow rather than an Apex class (a `TriggerAction__mdt` record with
`kern__FlowName__c` populated and `kern__ApexClassName__c` blank). For those, `kern.TST_InvokeFlowMock` lets you
unit-test that the right flow is called at the right time, without deploying throwaway flows just for the test.

**In your editor**, in a test class:

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
compare old and new.

**In your editor**, in a new class:

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
at runtime in code, with no metadata change.

**In your editor**, in the Apex that runs the data fix:

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
dark until you're ready to turn it on. Point an action at a flag with `RequiredFeatureFlag__c` on your
`TriggerAction__mdt` record.

Create the `AccountDefaults` Feature Flag first (see [Fast Start - Feature Flags](Fast%20Start%20-%20Feature%20Flags.md)),
because the field only accepts a flag that exists; while that flag is off, the framework skips the action.

**In Salesforce**, add this value to the record, then pull it as in Step 3.2:

| Field                 | API name                       | Value             |
|-----------------------|--------------------------------|-------------------|
| Required Feature Flag | `kern__RequiredFeatureFlag__c` | `AccountDefaults` |

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

**In Salesforce**, create a Trigger Action record with these values, leaving Apex Class Name blank, then pull it
with the Step 3.2 pull line, putting `AccountSetDefaultsFlow_BeforeInsert` in place of
`AccountSetDefaults_BeforeInsert`:

| Field               | API name                  | Value                                                       |
|---------------------|---------------------------|-------------------------------------------------------------|
| Label               | `MasterLabel`             | `Account Set Defaults via Flow - Before Insert`             |
| Trigger Action Name | `DeveloperName`           | `AccountSetDefaultsFlow_BeforeInsert`                       |
| Flow Name           | `kern__FlowName__c`       | `Account_SetDefaults`                                       |
| Failure Action      | `kern__FailureAction__c`  | `Log and Continue` (stored as `LogAndContinue`)             |
| Event               | `kern__Event__c`          | `Before Insert`                                             |
| Order               | `kern__Order__c`          | `100`                                                       |
| Trigger Setting     | `kern__TriggerSetting__c` | `Account`                                                   |
| Description         | `kern__Description__c`    | `Runs the Account_SetDefaults flow on new Account records.` |

`kern__FailureAction__c` decides what happens if the flow fails. `LogAndContinue` (the default) writes a
`LogEntryEvent__e` and lets the save proceed. `BlockDml` calls `record.addError(...)` to stop the save and show
the error to the user. Note that an action can't be both a flow and an Apex class: if you set both
`kern__FlowName__c` and `kern__ApexClassName__c`, the `MutuallyExclusiveTarget` validation rule rejects it.

Full developer reference: [Triggers - Guide → Flow as a Trigger Action](Triggers%20-%20Guide.md#flow-as-a-trigger-action).

### Clean up

If you built this example only to try the framework, run these two commands when you have finished the guide. Run
them in this order: the org refuses to delete the trigger setting while a trigger action still points at it. If you
also created the flow's Trigger Action record above, or the Tier 3 one for `TRG_AccountIndustryChanged`, delete that
record in Setup before command 2, for the same reason, and delete the file you pulled for it from
`force-app/main/default/customMetadata` too, or a later deploy would create the record again. Delete the Tier 3 class
the way you created it. The Verify step's `Test Company` account stays; delete it in the app, or leave it.

**1. In the terminal**, delete the two classes, the trigger and the trigger action record:

```shell
sf project delete source -o YourOrgAlias -m "ApexClass:TRG_AccountSetDefaults_TEST" -m "ApexClass:TRG_AccountSetDefaults" -m "ApexTrigger:TRG_Account" -m "CustomMetadata:kern__TriggerAction.AccountSetDefaults_BeforeInsert" --no-prompt
```

You should see `Status: Succeeded`, then a `Deleted Source` table listing the two classes, the trigger and the
trigger action record.

**2. In the terminal**, delete the trigger setting:

```shell
sf project delete source -o YourOrgAlias -m "CustomMetadata:kern__TriggerSetting.Account" --no-prompt
```

You should see `Status: Succeeded`, then a `Deleted Source` table listing the trigger setting.

The commands delete the files from your project too.

Something went wrong? See [Common Issues](#clean-up-1).

---

## Common Issues

Trouble with your computer rather than this guide (`sf` is not recognised, scripts are disabled, you are not logged
in, the wrong folder)? Those are answered once, in
[Set Up Your Computer](Set%20Up%20Your%20Computer.md#if-something-went-wrong).

### Step 1: Create the trigger action

#### The deploy says there is nothing to deploy

The deploy stops with `No source-backed components present in the package.` The command ran inside another project's
folder, so the CLI looked for the class there and found nothing. Open the terminal in your own project's top folder,
the one that holds `sfdx-project.json`, and run the command again.

#### `Invalid type: kern.TRG_Base`

The org you deployed to does not have KernDX installed, so it cannot find the framework's base class. Install KernDX
in that org first (see the [Installation guide](Installation.md)). If you installed KernDX under your own namespace
or without one, change the `kern.` prefix in the code as the namespace note at the top of this guide explains.

### Step 2: Create the physical trigger

#### The deploy fails

The trigger's deploy fails for the same reasons as the class's, see the entries under
[Step 1](#step-1-create-the-trigger-action-1). When KernDX is missing, the message names the framework class the
trigger uses as an invalid type.

### Step 3: Register the action

#### The form will not save

The Trigger Action form needs **Event**, **Order**, **Trigger Setting** and **Description**, plus exactly one of
**Apex Class Name** or **Flow Name**, before it saves. Fill in every value in the Step 3.2 table, then save again.
Create the trigger setting first (Step 3.1), so that **Trigger Setting** can find `Account`.

#### The pull creates no file

The record's name in Setup does not match the name in the command. The command asks for `Account` and
`AccountSetDefaults_BeforeInsert` (or `AccountSetDefaultsFlow_BeforeInsert` for the flow record); check the
**Trigger Setting Name** and **Trigger Action Name** on the records,
fix the one that differs, and pull again.

### Step 4: Verify

#### The Description stays blank

The action did not run. Two things decide whether it runs:

- The physical trigger must declare the event (Step 2). A trigger only runs for the events it declares, so for this
  guide it needs `before insert`; if you later add `before update` actions, add `before update` too.
- The Trigger Action record must be right (Step 3). Check that its **Apex Class Name** (`kern__ApexClassName__c`),
  **Event** (`kern__Event__c`) and **Trigger Setting** (`kern__TriggerSetting__c`) hold the values in the Step 3.2 table.

When you write your own handlers, keep them bulk-safe: loop over every record in the list rather than processing only
`newRecords[0]`, and collect IDs to query once outside the loop, never inside it (a query inside the loop hits the
SOQL governor limit).

#### The action does nothing and the record's **Bypass Execution** box is checked

The action or the whole object is switched off. Clear **Bypass Execution** (`kern__BypassExecution__c`) on the record
and save; check both the `TriggerSetting__mdt` and the `TriggerAction__mdt` records.

#### `Unable to resolve type for class "TRG_AccountSetDefaults"`

Saving the Account fails with this message. The class is `public`, and the framework cannot see a `public` class in
your org. Make the class `global` (as in Step 1), or set up a Type Resolver so the framework knows where to look (see
[Type Resolution](Utilities%20-%20Guide.md#type-resolution-util_typeresolver)).

### Step 5: Write and run the test

#### Unsure how to test a trigger action handler

Driving the handler through the framework's metadata setup is the hard way. Call your handler directly in the test:
build a record with `kern.TST_Builder` (`.withoutInsertion()`), call the method, then assert, as the test class in
Step 5 does.

### Clean up

#### `Your attempt to delete Account could not be completed`

The trigger setting was deleted while a trigger action still pointed at it, and the org refuses that. Run the two
clean-up commands in order, the trigger action first and the trigger setting second. If you created the flow's Trigger
Action record, delete it in Setup before the second command.

Still stuck? [Tell us](https://github.com/JVB-Consulting/kerndx/issues/new?template=bug_report.md&title=%5Bdocs%5D%20Trigger%20Actions) which step and what you saw.

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
- [Post-trigger actions (run logic once, after all trigger actions for a save finish)](Triggers%20-%20Guide.md#post-trigger-actions)
- [Bypass Mechanisms](Triggers%20-%20Guide.md#bypass-mechanisms)
- [Feature Flag Integration](Triggers%20-%20Guide.md#feature-flag-integration)
