---
navOrder: 60
---

# Fast Start - Custom Validations

**Framework:** KernDX | **Total time:** ~25 minutes

**What this is:** A way to stop bad data from being saved (required fields, conditional rules, cross-field checks) by writing formula rules as configuration records instead of Apex code. **Why it exists:** Standard Salesforce validation rules live one-per-object and are hard to test, bypass, or roll out gradually. KernDX rules are grouped, unit-testable without saving a record, and can run in a log-only "shadow" mode first. **Who should care:** developers and admins enforcing data quality, plus tech leads who want validation logic that is version-controlled and tested. **When to use it:** any time you would otherwise write a Salesforce validation rule but want testability, gradual rollout, and a single place to manage the rules for an object. If a single rule on one object is all you need and you'll never test or stage it, a standard Salesforce validation rule is simpler. Choose KernDX once you want any of those three things.

> **Namespaces in code samples:** `kern.` on a class and `kern__` on an object, field, or metadata type mark the managed package's namespace.
> On the managed package, framework references need those prefixes even where a sample omits them; repackaged under your own namespace, replace `kern`/`kern__`
> with your prefix; on an unmanaged deploy, drop them. See [How to read the code samples](Installation.md#how-to-read-the-code-samples).

**What you'll build:** Account validation rules that enforce required fields and conditional logic,
all configured through Custom Metadata, with a test class proving every rule works.

**Success looks like:** Two test methods pass (proving your rule fires when the record is invalid and
is satisfied when it's valid), and you can query your CMDT records to see exactly what's configured.

**In one line:** `kern.UTIL_ValidationTestHelper.assertRuleFails(record, 'MyRule');` tests any
metadata-configured rule without saving a record or running a trigger.

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
2. [Tier 1: See It Work (~5 minutes)](#tier-1-see-it-work-5-minutes)
    - [Step 1: Create the three records](#step-1-create-the-three-records)
    - [Step 2: See the rule work](#step-2-see-the-rule-work)
3. [Tier 2: Test Your Rules (~10 minutes)](#tier-2-test-your-rules-10-minutes)
    - [Step 3: Write and run the test](#step-3-write-and-run-the-test)
    - [Key patterns](#key-patterns)
4. [Tier 3: Production Patterns (~5-10 minutes)](#tier-3-production-patterns-5-10-minutes)
    - [Trigger integration](#trigger-integration)
    - [Formula reference](#formula-reference)
    - [Bypass mechanisms](#bypass-mechanisms)
    - [Shadow mode](#shadow-mode)
    - [Feature flag integration](#feature-flag-integration)
    - [Execution strategies and error severity](#execution-strategies-and-error-severity)
    - [Clean up](#clean-up)
5. [Common Issues](#common-issues)
    - [Step 1: Create the three records](#step-1-create-the-three-records-1)
    - [Step 2: See the rule work](#step-2-see-the-rule-work-1)
    - [Step 3: Write and run the test](#step-3-write-and-run-the-test-1)
    - [Trigger integration](#trigger-integration-1)
    - [Clean up](#clean-up-1)
6. [What You Now Know](#what-you-now-know)
7. [Next Steps](#next-steps)

</details>

---

## Tier 1: See It Work (~5 minutes)

The goal here is to block a save when the data is wrong, without writing any Apex. You do that by
creating configuration records (Custom Metadata, or CMDT) instead of code. Three record types nest
inside each other, parent to child:

```text
TriggerSetting__mdt (Account)
 └── ValidationRuleGroup__mdt (AccountValidation)
      └── ValidationRule__mdt (DescriptionRequired)
```

### Step 1: Create the three records

You author these records yourself: a fresh org ships with no Account rules. You create each one in Setup, parent
first, then pull all three into your project so they are under source control with your code. The relationship
fields (**Trigger Setting** on the group, **Validation Rule Group** on the rule) are lookups to the parent records,
which is why the parent must exist first.

#### Step 1.1: Create the trigger setting

Skip this record if it exists from the [Trigger Actions guide](Fast%20Start%20-%20Trigger%20Actions.md).

**In Salesforce**, open Setup, then Custom Metadata Types, then **Trigger Setting**, then **Manage Trigger
Settings**, then **New**, and save a record with these values:

| Field                | API name                   | Value     |
|----------------------|----------------------------|-----------|
| Label                | `MasterLabel`              | `Account` |
| Trigger Setting Name | `DeveloperName`            | `Account` |
| SObject Type         | `kern__SObjectType__c`     | `Account` |
| Bypass Execution     | `kern__BypassExecution__c` | unchecked |

#### Step 1.2: Create the validation rule group

**In Salesforce**, open Setup, then Custom Metadata Types, then **Validation Rule Group**, then **Manage Validation
Rule Groups**, then **New**, and save a record with these values:

| Field                      | API name                      | Value                                   |
|----------------------------|-------------------------------|-----------------------------------------|
| Label                      | `MasterLabel`                 | `Account Validation`                    |
| Validation Rule Group Name | `DeveloperName`               | `AccountValidation`                     |
| Description                | `kern__Description__c`        | `Validation rules for Account records.` |
| Execution Strategy         | `kern__ExecutionStrategy__c`  | `Accumulate`                            |
| Trigger Operations         | `kern__TriggerOperations__c`  | `Insert;Update`                         |
| Trigger Setting            | `kern__TriggerSetting__c`     | `Account`                               |
| Trigger Timing             | `kern__TriggerTiming__c`      | `Before`                                |

#### Step 1.3: Create the validation rule

The rule uses the formula `ISBLANK(newRecord.Description)` and is active by default: leave **Bypass Execution**
(`kern__BypassExecution__c`) unchecked.

**In Salesforce**, open Setup, then Custom Metadata Types, then **Validation Rule**, then **Manage Validation
Rules**, then **New**, and save a record with these values:

| Field                 | API name                       | Value                                    |
|-----------------------|--------------------------------|------------------------------------------|
| Label                 | `MasterLabel`                  | `Description Required`                   |
| Validation Rule Name  | `DeveloperName`                | `DescriptionRequired`                    |
| Description           | `kern__Description__c`         | `Account Description must be populated.` |
| Error Display Field   | `kern__ErrorDisplayField__c`   | `Description`                            |
| Error Message         | `kern__ErrorMessage__c`        | `Description is required`                |
| Rule Formula          | `kern__RuleFormula__c`         | `ISBLANK(newRecord.Description)`         |
| Severity              | `kern__Severity__c`            | `Error`                                  |
| Validation Rule Group | `kern__ValidationRuleGroup__c` | `AccountValidation`                      |

#### Step 1.4: Pull the three records into your project

**In the terminal**, pull all three records in one command:

```shell
sf project retrieve start -o YourOrgAlias -m "CustomMetadata:kern__TriggerSetting.Account" -m "CustomMetadata:kern__ValidationRuleGroup.AccountValidation" -m "CustomMetadata:kern__ValidationRule.DescriptionRequired"
```

You should see three files created under `force-app/main/default/customMetadata`, each named after its record.

Something went wrong? See [Common Issues, Step 1](#step-1-create-the-three-records-1).

### Step 2: See the rule work

Query the records to see what's configured, then run the rule against a record in memory. The parent links are
MetadataRelationship fields, so filter on the parent's `DeveloperName` through the `__r` relationship, **not** a
string literal on the `__c` field.

**In Salesforce**, open the Developer Console (the gear icon, then Developer Console), then Debug, then Open Execute
Anonymous Window, and run:

```apex
List<kern__ValidationRuleGroup__mdt> groups =
[
    SELECT DeveloperName, kern__TriggerOperations__c, kern__ExecutionStrategy__c
    FROM kern__ValidationRuleGroup__mdt
    WHERE kern__TriggerSetting__r.DeveloperName = 'Account'
    LIMIT 10
];
for(kern__ValidationRuleGroup__mdt grp : groups)
{
    System.debug(grp.DeveloperName + ' — ' + grp.kern__TriggerOperations__c);
}

List<kern__ValidationRule__mdt> rules =
[
    SELECT DeveloperName, kern__RuleFormula__c, kern__ErrorMessage__c, kern__Severity__c
    FROM kern__ValidationRule__mdt
    WHERE kern__ValidationRuleGroup__r.DeveloperName = 'AccountValidation'
    LIMIT 10
];
for(kern__ValidationRule__mdt rule : rules)
{
    System.debug(rule.DeveloperName + ': ' + rule.kern__ErrorMessage__c);
}
```

You should see two lines in the log: `AccountValidation — Insert;Update` for the group and
`DescriptionRequired: Description is required` for the rule.

Now run the rule against a record in memory, with nothing saved and no trigger involved.

**In Salesforce**, in the same Execute Anonymous window, run:

```apex
Account invalidAccount = new Account(Name = 'Test Corp');
kern.UTIL_ValidationRule.ValidationResult result = kern.UTIL_ValidationTestHelper.validate(invalidAccount);
System.debug('Valid: ' + result.isValid);
for(kern.UTIL_ValidationRule.ValidationError error : result.errors)
{
    System.debug('Error: ' + error.message + ' (field: ' + error.fieldName + ')');
}
```

You should see these lines in the log:

```text
Valid: false
Error: Description is required (field: Description)
```

Populate the field and validate again.

**In Salesforce**, in the same window, run:

```apex
Account validAccount = new Account(Name = 'Test Corp', Description = 'A real description');
kern.UTIL_ValidationRule.ValidationResult result = kern.UTIL_ValidationTestHelper.validate(validAccount);
System.debug('Valid: ' + result.isValid + ' — Errors: ' + result.errors.size());
```

You should see this line in the log:

```text
Valid: true — Errors: 0
```

> **Formula logic is inverted:** a formula that returns `true` means validation **fails** (the record is invalid).
> `ISBLANK(newRecord.Description)` returns `true` when Description is blank, so the rule fires. When
> Description is populated the formula returns `false`, so the rule is satisfied.

Something went wrong? See [Common Issues, Step 2](#step-2-see-the-rule-work-1).

---

## Tier 2: Test Your Rules (~10 minutes)

> **No local project?** Create the class directly in Developer Console (Gear Icon > Developer Console >
> File > New > Apex Class) and run it from there (Test > New Run). Paste the code, save, and skip the
> terminal commands.

A test gives you confidence that each rule does what you think: it blocks an invalid record and lets a valid one
through. Because the rules are configuration rather than your own Apex, there is no code of yours to cover,
but a test still proves the behaviour and fails loudly if someone later breaks a rule.
`kern.UTIL_ValidationTestHelper` evaluates a single deployed rule against a record in memory, with nothing
saved and no trigger involved. Both helpers are `global`, so you can call them from your own `@IsTest` class.

### Step 3: Write and run the test

The test class checks both cases: the rule fires when Description is blank, and it is satisfied when Description is
filled in. You create the empty class with one command, paste the code into it, send it to your org, then run it.

**1. In the terminal**, from your project's top folder, create the empty test class:

```shell
sf apex generate class --name AccountValidation_TEST --output-dir force-app/main/default/classes
```

You should see two files created in `force-app/main/default/classes`: `AccountValidation_TEST.cls` and its
companion of the same name ending in `.cls-meta.xml`.

**2. In your editor**, open this file, delete what is there, paste the code below in, and save:

```text
force-app/main/default/classes/AccountValidation_TEST.cls
```

```apex
/**
 * @description Tests the DescriptionRequired validation rule.
 *
 * @author your.name@company.com
 *
 * @group Custom Validations
 *
 * @date February 2026
 */
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest(seeAllData=false isParallel=true)
private class AccountValidation_TEST
{
    /** @description The rule fires when Description is blank. */
    @IsTest
    private static void shouldFailWhenDescriptionBlank()
    {
        Account record = (Account)kern.TST_Builder.of(Account.SObjectType)
            .withOverride(Account.Description, null)
            .withoutInsertion()
            .build();

        kern.UTIL_ValidationTestHelper.assertRuleFails(record, 'DescriptionRequired');
    }

    /** @description The rule is satisfied when Description is populated. */
    @IsTest
    private static void shouldPassWhenDescriptionPresent()
    {
        Account record = (Account)kern.TST_Builder.of(Account.SObjectType)
            .withOverride(Account.Description, 'A valid description')
            .withoutInsertion()
            .build();

        kern.UTIL_ValidationTestHelper.assertRulePasses(record, 'DescriptionRequired');
    }
}
```

**3. In the terminal**, send the test class to your org:

```shell
sf project deploy start -o YourOrgAlias -m "ApexClass:AccountValidation_TEST"
```

You should see `Status: Succeeded`, with `AccountValidation_TEST` listed as created.

**4. In the terminal**, run the test:

```shell
sf apex run test -o YourOrgAlias -t AccountValidation_TEST --code-coverage --synchronous --result-format human
```

You should see both tests show `Pass` and the summary line `Outcome` reads `Passed`, among these lines:

```text
Outcome      Passed
Tests Ran    2
Pass Rate    100%
Fail Rate    0%
```

The coverage table may list other Apex classes from your org, with figures that depend on your org. The rules are
configuration, so this test has no code of yours to cover.

> **`assertRuleFails` / `assertRulePasses` evaluate the *deployed* rule by DeveloperName.** The rule must
> be deployed and active (`kern__BypassExecution__c = false`, as in Tier 1). They evaluate the formula
> directly and need no trigger file in place. `kern.TST_Builder.of(...).withoutInsertion()` builds a record
> in memory (with a fake Id) so nothing is written to the database.

> **Test against your deployed rule.** Create the rule as a record in your org (Step 1), then assert against it with
> `kern.UTIL_ValidationTestHelper.assertRuleFails` / `assertRulePasses`: both are `global` and callable
> from your `@IsTest` class. They evaluate your deployed rule directly, so you don't need to register a rule
> in memory. This is the supported path in your own org.

Something went wrong? See [Common Issues, Step 3](#step-3-write-and-run-the-test-1).

### Key patterns

| Pattern                                          | Why                                                                          |
|--------------------------------------------------|------------------------------------------------------------------------------|
| `validate(record)`                               | Evaluates ALL active rules for the object in memory and returns a `ValidationResult` |
| `assertRuleFails(record, ruleName)`              | Asserts one deployed, active rule fires (nothing saved, no trigger)          |
| `assertRulePasses(record, ruleName)`             | Asserts one deployed, active rule is satisfied                               |
| `withoutInsertion()`                             | Builds a record in memory with a fake Id (no database write)                |
| Formula returns `true` = fails                   | `ISBLANK(newRecord.Description)` fires when Description is blank             |
| `ISPICKVAL()` for picklists                      | `ISPICKVAL(newRecord.Industry, "Technology")`: use this, not `=`, for picklist values |

---

## Tier 3: Production Patterns (~5-10 minutes)

### Trigger integration

So far you have tested the rules by hand. To have them run automatically every time a record is saved,
point a `TriggerAction__mdt` record at the built-in `TRG_ExecuteValidationRules` action. No custom Apex needed.

This requires a trigger on the object (see [Fast Start - Trigger Actions](Fast%20Start%20-%20Trigger%20Actions.md)
for creating and deploying one). If you kept the Trigger Actions example, you have this file already: add
`before update` to its events and deploy it again.

**In your editor**, the trigger file:

```text
force-app/main/default/triggers/TRG_Account.trigger
```

```apex
trigger TRG_Account on Account (before insert, before update)
{
    new kern.TRG_Dispatcher().run();
}
```

**In Salesforce**, open Setup, then Custom Metadata Types, then **Trigger Action**, then **Manage Trigger
Actions**, then **New**, and save a record with these values (and a Trigger Action Name of your choice), then pull
it as in Step 1.4:

| Field                    | API name                         | Value                                             |
|--------------------------|----------------------------------|---------------------------------------------------|
| Label                    | `MasterLabel`                    | `Account Validations - Before Insert`             |
| Description              | `kern__Description__c`           | `Runs the Account validation rule group on save.` |
| Apex Class Name          | `kern__ApexClassName__c`         | `TRG_ExecuteValidationRules`                      |
| Allow Non Self-Initiated | `kern__AllowNonSelfInitiated__c` | checked                                           |
| Event                    | `kern__Event__c`                 | `Before Insert`                                   |
| Order                    | `kern__Order__c`                 | `50`                                              |
| Trigger Setting          | `kern__TriggerSetting__c`        | `Account`                                         |

> **Note:** `kern__ApexClassName__c` is `TRG_ExecuteValidationRules` (no `kern.` prefix). The Type
> Resolver locates the framework class in the managed namespace for you.

If you kept the Trigger Actions guide's example, its trigger action stamps a default Description on a blank one
before this action runs (its Order is 10, lower runs first), so the insert below would succeed. Check **Bypass
Execution** on that example's trigger action, or delete it, before you verify.

Verify it: **In Salesforce**, in the Developer Console's Execute Anonymous window, run:

```apex
try
{
    Account invalidAccount = new Account(Name = 'No Description Account');
    insert invalidAccount;
    System.debug('ERROR: insert should have been blocked');
}
catch(DmlException error)
{
    System.debug('Validation fired: ' + error.getDmlMessage(0));
}
```

Something went wrong? See [Common Issues, Trigger integration](#trigger-integration-1).

### Formula reference

| Function                     | Example                                                   | Description                               |
|------------------------------|-----------------------------------------------------------|-------------------------------------------|
| `ISBLANK(field)`             | `ISBLANK(newRecord.Description)`                          | Field is empty                            |
| `ISPICKVAL(field, value)`    | `ISPICKVAL(newRecord.Industry, "Technology")`             | Picklist equals value (use this, not `=`) |
| `NOT(condition)`             | `NOT(ISBLANK(newRecord.Email))`                           | Negate a condition                        |
| `AND(a, b)`                  | `AND(ISBLANK(newRecord.Phone), ISBLANK(newRecord.Email))` | Both conditions true                      |
| `OR(a, b)`                   | `OR(ISBLANK(newRecord.Phone), ISBLANK(newRecord.Email))`  | Either condition true                     |
| `ISCHANGED(old, new, field)` | `ISCHANGED(oldRecord, newRecord, Industry)`               | Field value changed on update             |

Operators `&&`, `||`, `!`, `>`, `<`, `>=`, `<=`, `==`, `!=` work inline.

### Bypass mechanisms

**In your editor**, in the Apex that needs the rules off:

```apex
// Bypass all validation rules for Account
kern.UTIL_ValidationRule.bypassObject('Account');     // String param

// Bypass a specific rule group
kern.UTIL_ValidationRule.bypassGroup('AccountValidation');

// Bypass a single rule
kern.UTIL_ValidationRule.bypassRule('PhoneOrWebsiteRequired');

// Clear all bypasses
kern.UTIL_ValidationRule.clearAllBypasses();
```

### Shadow mode

Shadow mode lets a new rule run watch-only in production: it logs what it would have blocked but doesn't
block the save yet, so you can confirm a rule behaves before you let it stop real users. Set
`ShadowMode__c = true` on a rule to turn this on. Violations appear in **App Launcher > Kern > Log Entries**
with a `[SHADOW]` tag.

To try it, open Setup, then Custom Metadata Types, then **Validation Rule**, then **Manage Validation Rules**, then
your rule, then **Edit**; check **Shadow Mode** and save.

### Feature flag integration

You can turn a rule (or a whole group) on or off with a [Feature Flag](Fast%20Start%20-%20Feature%20Flags.md),
which is handy for staged rollouts or for switching a rule off in an incident without a deployment:

| Field                                       | Effect                                                |
|---------------------------------------------|-------------------------------------------------------|
| `BypassFeatureFlag__c` (on group or rule)   | Skip the group/rule when this flag is **enabled**     |
| `RequiredFeatureFlag__c` (on group or rule) | Only run the group/rule when this flag is **enabled** |

### Execution strategies and error severity

| Strategy                 | Behaviour                              |
|--------------------------|----------------------------------------|
| **Accumulate** (default) | Evaluate all rules, collect all errors |
| **Fail Fast**            | Stop after the first error per record  |

| Severity    | Behaviour                             |
|-------------|---------------------------------------|
| **Error**   | Blocks save, attaches error to record |
| **Warning** | Allows save, logs to Log Entries      |

See [Validation - Guide](Validation%20-%20Guide.md) for the complete reference.

### Clean up

If you built this example only to try the framework, run these three commands when you have finished the guide. Run
them in this order: the org refuses to delete a validation rule group while a rule still points at it, and a trigger
setting while a group still points at it. Skip the third if the trigger setting is from the Trigger Actions guide
and you are keeping that example. If you also created the Tier 3 trigger action record, delete it in Setup before the
third command, for the same reason, and delete the file you pulled for it from `force-app/main/default/customMetadata`
too, or a later deploy would create the record again. Delete the Tier 3 trigger the way you created it. If the
trigger is the Trigger Actions example's and you are keeping it, leave it (or put its events back to `before insert`)
instead of deleting it. If you checked
**Bypass Execution** on the Trigger Actions example's trigger action before the Tier 3 verify, clear it again.

**1. In the terminal**, delete the test class and the validation rule:

```shell
sf project delete source -o YourOrgAlias -m "ApexClass:AccountValidation_TEST" -m "CustomMetadata:kern__ValidationRule.DescriptionRequired" --no-prompt
```

You should see `Status: Succeeded`, then a `Deleted Source` table listing the test class and the validation rule.

**2. In the terminal**, delete the validation rule group:

```shell
sf project delete source -o YourOrgAlias -m "CustomMetadata:kern__ValidationRuleGroup.AccountValidation" --no-prompt
```

You should see `Status: Succeeded`, then a `Deleted Source` table listing the validation rule group.

**3. In the terminal**, delete the trigger setting:

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

### Step 1: Create the three records

#### The form will not save

The Validation Rule Group form needs **Trigger Operations**, **Trigger Setting** and **Trigger Timing** before it
saves, and the Validation Rule form needs **Validation Rule Group**. Fill in every value in the tables, then save
again. Create the records in order, parent first (Step 1.1, then 1.2, then 1.3), so that each lookup can find its
parent.

#### The pull creates no file

A record's name in Setup does not match the name in the command. The command asks for `Account`,
`AccountValidation` and `DescriptionRequired`; check the **Trigger Setting Name**, **Validation Rule Group Name** and
**Validation Rule Name** on the records, fix the one that differs, and pull again.

### Step 2: See the rule work

#### `Valid: true` when you expected `Valid: false`

The rule did not fire. Check three things:

- The rule is switched on: **Bypass Execution** (`kern__BypassExecution__c`) is unchecked on both the rule and its
  group.
- The formula is valid. A formula with a syntax error does not fire; look in **App Launcher > Kern > Log Entries**
  for the formula's error.
- The formula's logic is the right way round: a formula that returns `true` means the record is invalid.

#### The error names the wrong field

**Error Display Field** (`kern__ErrorDisplayField__c`) holds the field's API name only: `Description`, not
`Account.Description`. Fix the value on the rule and run the check again.

#### A rule you wrote on a picklist never fires

A picklist compared with `=` never matches. Use `ISPICKVAL(newRecord.Field, "Value")` for a picklist, as the
[Formula reference](#formula-reference) shows.

#### Only the first of several rules reports an error

The group's **Execution Strategy** (`kern__ExecutionStrategy__c`) is `Fail Fast`, which stops after the first error
per record. Change it to `Accumulate` to collect every error.

### Step 3: Write and run the test

#### `assertRuleFails` says the rule passed

The formula's logic is inverted. A formula returning `true` means the record is invalid, so check your condition
against the record the test builds.

### Trigger integration

#### Saving an Account does not run the rules

The rules run on save only through a trigger action. Create the Trigger Action record that points at
`TRG_ExecuteValidationRules` and the trigger that declares the events, as
[Trigger integration](#trigger-integration) shows. If you kept the Trigger Actions guide's example, it fills in a
blank Description first, so the rule has nothing to block: check **Bypass Execution** on that example's trigger action.

#### The rule fires on insert but not on update

The trigger action runs only for the event on its record, and the one in
[Trigger integration](#trigger-integration) has **Event** `Before Insert` only. Create a second Trigger Action record
with **Event** `Before Update`. Also check that the group's **Trigger Operations** (`kern__TriggerOperations__c`)
includes `Update` (Step 1.2 sets `Insert;Update`). Also check that your `TRG_Account` trigger declares
`before update`, as the [Trigger integration](#trigger-integration) block shows, and deploy it again if you add it.

### Clean up

#### `Your attempt to delete Account Validation could not be completed`

The validation rule group was deleted while a rule still pointed at it, and the org refuses that. The trigger setting
refuses the same way (`Your attempt to delete Account could not be completed`) while a group still points at it. Run
the three clean-up commands in order: the rule first, then the group, then the trigger setting.

Still stuck? [Tell us](https://github.com/JVB-Consulting/kerndx/issues/new?template=bug_report.md&title=%5Bdocs%5D%20Custom%20Validations) which step and what you saw.

## What You Now Know

| Concept                                                        | What it does                                                |
|----------------------------------------------------------------|-------------------------------------------------------------|
| `ValidationRuleGroup__mdt`                                     | Groups rules for an object and trigger context              |
| `ValidationRule__mdt`                                          | Individual formula-based check with error message           |
| `UTIL_ValidationTestHelper.validate(record)`                   | Evaluates all rules in-memory, returns a `ValidationResult` |
| `UTIL_ValidationTestHelper.assertRuleFails(record, ruleName)`  | Asserts one rule fires (nothing saved)                      |
| `UTIL_ValidationTestHelper.assertRulePasses(record, ruleName)` | Asserts one rule is satisfied                               |
| `UTIL_ValidationRule.bypassObject('Account')`                  | Bypasses all Account rules (takes a String)                 |
| `TST_Builder.of(type).withoutInsertion()`                      | Builds an in-memory record (fake Id) for in-memory rule evaluation |
| `TRG_ExecuteValidationRules`                                   | Built-in trigger action that enforces rules on save         |

**Key patterns:**

- Formulas return `true` when the record is **invalid** (inverted logic)
- Use `ISPICKVAL()` for picklist comparisons, not `=`
- Tests use `UTIL_ValidationTestHelper` (nothing saved, no trigger needed)
- `bypassObject` takes a **String** (`'Account'`), not an `SObjectType`
- Pull validation records into your project so they are under version control. To deactivate a group or rule
  without removing it, set `kern__BypassExecution__c = true` on it

---

## Next Steps

- [Fast Start - Trigger Actions](Fast%20Start%20-%20Trigger%20Actions.md)
- [Fast Start - Feature Flags](Fast%20Start%20-%20Feature%20Flags.md)
- [Fast Start - Logging](Fast%20Start%20-%20Logging.md)
- [Custom Validations Developer Guide](Validation%20-%20Guide.md)
- [UTIL_ValidationRule API Reference](reference/apex/UTIL_ValidationRule.md)
- [Formula Functions Reference](reference/apex/UTIL_FormulaFilter.md)
