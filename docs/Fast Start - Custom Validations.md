---
navOrder: 60
---

# Fast Start - Custom Validations

**Framework:** KernDX | **Total time:** ~25 minutes

> Declarative, formula-based validation rules — no Apex code needed, just metadata records.

**Before you start:**

- [ ] KernDX package installed in your org
- [ ] Org configured post-install — verify with the **Kern** app's Health Check (see [Installation guide](Installation.md#post-install-configuration))
- [ ] CLI authenticated (`sf org open -o YourOrgAlias` to verify) — or just use the Developer Console
  (Gear Icon > Developer Console) for all Apex work
- [ ] Working in a sandbox or scratch org (not production)

> **Subscriber orgs:** Use `kern.ClassName` when calling framework classes (e.g., `kern.UTIL_ValidationRule`).
> Your own classes don't need a namespace prefix — the framework's Type Resolver handles resolution automatically.

**What you'll build:** Account validation rules that enforce required fields and conditional logic —
all configured through Custom Metadata, with a test class proving every rule works.

**Success looks like:** Two test methods pass — proving your rule fires when the record is invalid and
is satisfied when it's valid — and you can query your CMDT records to see exactly what's configured.

**In one line:** `kern.UTIL_ValidationTestHelper.assertRuleFails(record, 'MyRule');` — test any
metadata-configured rule without DML or triggers.

---

## Table of Contents

<details>
<summary>Expand</summary>

1. [Tier 1: See It Work (~5 minutes)](#tier-1-see-it-work-5-minutes)
2. [Tier 2: Test Your Rules (~10 minutes)](#tier-2-test-your-rules-10-minutes)
    - [Step 1: Write the test](#step-1-write-the-test)
    - [Step 2: Deploy and run](#step-2-deploy-and-run)
    - [Key patterns](#key-patterns)
3. [Tier 3: Production Patterns (~5-10 minutes)](#tier-3-production-patterns-5-10-minutes)
    - [Trigger integration](#trigger-integration)
    - [Formula reference](#formula-reference)
    - [Bypass mechanisms](#bypass-mechanisms)
    - [Shadow mode](#shadow-mode)
    - [Feature flag integration](#feature-flag-integration)
    - [Execution strategies and error severity](#execution-strategies-and-error-severity)
4. [Common Issues](#common-issues)
5. [What You Now Know](#what-you-now-know)
6. [Next Steps](#next-steps)

</details>

---

## Tier 1: See It Work (~5 minutes)

Custom validations are metadata-driven — you define rules as CMDT records, not Apex code. Three
record types form a parent-child hierarchy:

```text
TriggerSetting__mdt (Account)
 └── ValidationRuleGroup__mdt (AccountValidation)
      └── ValidationRule__mdt (DescriptionRequired)
```

You author these records yourself — a fresh org ships with no Account rules. Create the three below and
deploy them. Each Custom Metadata record requires a **Description** — the deploy is rejected without one.

`customMetadata/kern__TriggerSetting.Account.md-meta.xml` (skip if you already created it for triggers):

```xml
<?xml version="1.0" encoding="UTF-8"?>
<CustomMetadata xmlns="http://soap.sforce.com/2006/04/metadata"
    xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema">
    <label>Account</label>
    <protected>false</protected>
    <values><field>kern__BypassExecution__c</field><value xsi:type="xsd:boolean">false</value></values>
    <values><field>kern__SObjectType__c</field><value xsi:type="xsd:string">Account</value></values>
</CustomMetadata>
```

`customMetadata/kern__ValidationRuleGroup.AccountValidation.md-meta.xml`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<CustomMetadata xmlns="http://soap.sforce.com/2006/04/metadata"
    xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema">
    <label>Account Validation</label>
    <protected>false</protected>
    <values><field>kern__Description__c</field><value xsi:type="xsd:string">Validation rules for Account records.</value></values>
    <values><field>kern__ExecutionStrategy__c</field><value xsi:type="xsd:string">Accumulate</value></values>
    <values><field>kern__TriggerOperations__c</field><value xsi:type="xsd:string">Insert;Update</value></values>
    <values><field>kern__TriggerSetting__c</field><value xsi:type="xsd:string">Account</value></values>
    <values><field>kern__TriggerTiming__c</field><value xsi:type="xsd:string">Before</value></values>
</CustomMetadata>
```

`customMetadata/kern__ValidationRule.DescriptionRequired.md-meta.xml` — formula
`ISBLANK(newRecord.Description)`, active by default (`kern__BypassExecution__c` defaults to `false`):

```xml
<?xml version="1.0" encoding="UTF-8"?>
<CustomMetadata xmlns="http://soap.sforce.com/2006/04/metadata"
    xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema">
    <label>Description Required</label>
    <protected>false</protected>
    <values><field>kern__Description__c</field><value xsi:type="xsd:string">Account Description must be populated.</value></values>
    <values><field>kern__ErrorDisplayField__c</field><value xsi:type="xsd:string">Description</value></values>
    <values><field>kern__ErrorMessage__c</field><value xsi:type="xsd:string">Description is required</value></values>
    <values><field>kern__RuleFormula__c</field><value xsi:type="xsd:string">ISBLANK(newRecord.Description)</value></values>
    <values><field>kern__Severity__c</field><value xsi:type="xsd:string">Error</value></values>
    <values><field>kern__ValidationRuleGroup__c</field><value xsi:type="xsd:string">AccountValidation</value></values>
</CustomMetadata>
```

```bash
sf project deploy start -o YourOrgAlias \
  -m "CustomMetadata:kern__TriggerSetting.Account" \
  -m "CustomMetadata:kern__ValidationRuleGroup.AccountValidation" \
  -m "CustomMetadata:kern__ValidationRule.DescriptionRequired" \
  --ignore-conflicts
```

> **Prefer the UI?** Create each under **Setup > Custom Metadata Types > [type] > Manage Records > New**.
> The relationship fields (Trigger Setting on the group, Validation Rule Group on the rule) are lookups
> to the parent records.

Query them to see what's configured. The parent links are MetadataRelationship fields, so filter on the
parent's `DeveloperName` via the `__r` relationship — **not** a string literal on the `__c` field:

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

Now run the rule in-memory against a record — no DML, no trigger needed:

```apex
Account invalidAccount = new Account(Name = 'Test Corp');
kern.UTIL_ValidationRule.ValidationResult result = kern.UTIL_ValidationTestHelper.validate(invalidAccount);
System.debug('Valid: ' + result.isValid);
for(kern.UTIL_ValidationRule.ValidationError error : result.errors)
{
    System.debug('Error: ' + error.message + ' (field: ' + error.fieldName + ')');
}
```

**Expected output:**

```text
Valid: false
Error: Description is required (field: Description)
```

Populate the field and validate again:

```apex
Account validAccount = new Account(Name = 'Test Corp', Description = 'A real description');
kern.UTIL_ValidationRule.ValidationResult result = kern.UTIL_ValidationTestHelper.validate(validAccount);
System.debug('Valid: ' + result.isValid + ' — Errors: ' + result.errors.size());
```

**Expected output:**

```text
Valid: true — Errors: 0
```

> **Formula logic is inverted:** formula returns `true` = validation **fails** (record is invalid).
> `ISBLANK(newRecord.Description)` returns `true` when Description is blank — the rule fires. When
> Description is populated the formula returns `false` — the rule is satisfied.

---

## Tier 2: Test Your Rules (~10 minutes)

> **No local project?** Create the class directly in Developer Console (Gear Icon > Developer Console >
> File > New > Apex Class) and run it from there (Test > New Run). Paste the code, save, and skip the
> `sf project deploy start` and `sf apex run test` commands.

Validation rules are metadata, so there is no Apex of your own to cover — but you still want a test that
proves each rule fires when it should and is satisfied when the record is valid.
`kern.UTIL_ValidationTestHelper` evaluates a single deployed rule in-memory, with no DML and no trigger.
Both helpers are `global`, so they are callable from a subscriber `@IsTest` class.

### Step 1: Write the test

Create `AccountValidation_TEST.cls`:

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
@IsTest(SeeAllData=false IsParallel=true)
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

### Step 2: Deploy and run

```bash
sf project deploy start -o YourOrgAlias -m "ApexClass:AccountValidation_TEST" --ignore-conflicts
sf apex run test -o YourOrgAlias -t AccountValidation_TEST --synchronous --result-format human
```

**Expected output:**

```text
Outcome      Passed
Tests Ran    2
Pass Rate    100%
Fail Rate    0%
```

> **`assertRuleFails` / `assertRulePasses` evaluate the *deployed* rule by DeveloperName.** The rule must
> be deployed and active (`kern__BypassExecution__c = false`, as in Tier 1); they evaluate the formula
> directly and need no physical trigger. `kern.TST_Builder.of(...).withoutInsertion()` builds an in-memory
> record (with a fake Id) so nothing is written to the database.

> **Test against your deployed rule.** Deploy the rule as CMDT (Tier 1), then assert against it with
> `kern.UTIL_ValidationTestHelper.assertRuleFails` / `assertRulePasses` — both are `global` and callable
> from your `@IsTest` class. They evaluate your deployed rule directly, so no in-memory rule registration
> is needed. This is the supported subscriber pattern.

### Key patterns

| Pattern                                          | Why                                                                          |
|--------------------------------------------------|------------------------------------------------------------------------------|
| `validate(record)`                               | Evaluates ALL active rules for the object in-memory — returns a `ValidationResult` |
| `assertRuleFails(record, ruleName)`              | Asserts one deployed, active rule fires — no DML, no trigger                  |
| `assertRulePasses(record, ruleName)`             | Asserts one deployed, active rule is satisfied                               |
| `withoutInsertion()`                             | Builds an in-memory record with a fake Id — no database write               |
| Formula returns `true` = fails                   | `ISBLANK(newRecord.Description)` fires when Description is blank             |
| `ISPICKVAL()` for picklists                      | `ISPICKVAL(newRecord.Industry, "Technology")` — use this, not `=`, for picklist values |

---

## Tier 3: Production Patterns (~5-10 minutes)

### Trigger integration

To enforce rules automatically when records are saved, add a `TriggerAction__mdt` record pointing to
the built-in `TRG_ExecuteValidationRules` action. No custom Apex needed.

This requires a trigger on the object (see [Fast Start - Trigger Actions](Fast%20Start%20-%20Trigger%20Actions.md)):

```apex
trigger TRG_Account on Account (before insert, before update)
{
    new kern.TRG_Dispatcher().run();
}
```

Create the trigger action record (XML for source-controlled projects):

```xml
<?xml version="1.0" encoding="UTF-8"?>
<CustomMetadata xmlns="http://soap.sforce.com/2006/04/metadata"
    xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
    xmlns:xsd="http://www.w3.org/2001/XMLSchema">
    <label>Account Validations - Before Insert</label>
    <protected>false</protected>
    <values>
        <field>kern__Description__c</field>
        <value xsi:type="xsd:string">Runs the Account validation rule group on save.</value>
    </values>
    <values>
        <field>kern__ApexClassName__c</field>
        <value xsi:type="xsd:string">TRG_ExecuteValidationRules</value>
    </values>
    <values>
        <field>kern__AllowNonSelfInitiated__c</field>
        <value xsi:type="xsd:boolean">true</value>
    </values>
    <values>
        <field>kern__Event__c</field>
        <value xsi:type="xsd:string">Before Insert</value>
    </values>
    <values>
        <field>kern__Order__c</field>
        <value xsi:type="xsd:double">50.0</value>
    </values>
    <values>
        <field>kern__TriggerSetting__c</field>
        <value xsi:type="xsd:string">Account</value>
    </values>
</CustomMetadata>
```

> **Note:** `kern__ApexClassName__c` is `TRG_ExecuteValidationRules` (no `kern.` prefix) — the Type
> Resolver locates the framework class in the managed namespace automatically.

Verify via Execute Anonymous:

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

### Formula reference

| Function                     | Example                                                   | Description                               |
|------------------------------|-----------------------------------------------------------|-------------------------------------------|
| `ISBLANK(field)`             | `ISBLANK(newRecord.Description)`                          | Field is empty                            |
| `ISPICKVAL(field, value)`    | `ISPICKVAL(newRecord.Industry, "Technology")`             | Picklist equals value — use this, not `=` |
| `NOT(condition)`             | `NOT(ISBLANK(newRecord.Email))`                           | Negate a condition                        |
| `AND(a, b)`                  | `AND(ISBLANK(newRecord.Phone), ISBLANK(newRecord.Email))` | Both conditions true                      |
| `OR(a, b)`                   | `OR(ISBLANK(newRecord.Phone), ISBLANK(newRecord.Email))`  | Either condition true                     |
| `ISCHANGED(old, new, field)` | `ISCHANGED(oldRecord, newRecord, Industry)`               | Field value changed on update             |

Operators `&&`, `||`, `!`, `>`, `<`, `>=`, `<=`, `==`, `!=` work inline.

### Bypass mechanisms

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

Set `ShadowMode__c = true` on a rule to log violations without blocking saves. Useful for testing
new rules in production before enforcing them. Violations appear in **App Launcher > Kern > Log Entries**
with a `[SHADOW]` tag.

To try it: **Setup > Custom Metadata Types > Validation Rule > Manage Records > [your rule] > Edit >
Shadow Mode = checked > Save.**

### Feature flag integration

Gate validation groups or individual rules on [Feature Flags](Fast%20Start%20-%20Feature%20Flags.md):

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

---

## Common Issues

| Problem                                  | Cause                                     | Fix                                                                         |
|------------------------------------------|-------------------------------------------|-----------------------------------------------------------------------------|
| Rule doesn't fire                        | Formula syntax error                      | Check Log Entries for formula compilation errors                            |
| Picklist comparison fails                | Using `=` instead of `ISPICKVAL()`        | Use `ISPICKVAL(newRecord.Field, "Value")` for picklists                     |
| `assertRuleFails` says rule passed       | Formula logic inverted                    | Formula returning `true` means invalid — check your condition               |
| Rule fires on insert but not update      | `TriggerOperations__c` missing `Update`   | Add `Update` to the semicolon-separated list                                |
| Error not on the right field             | Wrong `ErrorDisplayField__c`              | Use the field API name only (e.g., `Description` not `Account.Description`) |
| Rules don't fire via trigger             | Missing `TriggerAction__mdt`              | Create action pointing to `TRG_ExecuteValidationRules`                      |
| Multiple rules — only first fires        | `ExecutionStrategy__c` set to `Fail Fast` | Change to `Accumulate`                                                      |
| Need to register a validation rule from a test | Subscriber tests assert against deployed rules, not in-memory-registered ones | Deploy your rule as CMDT (Tier 1) and assert with `assertRuleFails` / `assertRulePasses` |

---

## What You Now Know

| Concept                                                        | What it does                                                |
|----------------------------------------------------------------|-------------------------------------------------------------|
| `ValidationRuleGroup__mdt`                                     | Groups rules for an object and trigger context              |
| `ValidationRule__mdt`                                          | Individual formula-based check with error message           |
| `UTIL_ValidationTestHelper.validate(record)`                   | Evaluates all rules in-memory, returns a `ValidationResult` |
| `UTIL_ValidationTestHelper.assertRuleFails(record, ruleName)`  | Asserts one rule fires — no DML                             |
| `UTIL_ValidationTestHelper.assertRulePasses(record, ruleName)` | Asserts one rule is satisfied                               |
| `UTIL_ValidationRule.bypassObject('Account')`                  | Bypasses all Account rules — String param                   |
| `TST_Builder.of(type).withoutInsertion()`                      | Builds an in-memory record (fake Id) for in-memory rule evaluation |
| `TRG_ExecuteValidationRules`                                   | Built-in trigger action that enforces rules on save         |

**Key patterns:**

- Formulas return `true` when the record is **invalid** (inverted logic)
- Use `ISPICKVAL()` for picklist comparisons, not `=`
- Tests use `UTIL_ValidationTestHelper` — no DML needed, no trigger needed
- `bypassObject` takes a **String** (`'Account'`), not an `SObjectType`
- Deploy validation metadata as XML for version control; set `kern__BypassExecution__c = true` on a
  group or rule to deactivate it without removing it

---

## Next Steps

- [Fast Start - Trigger Actions](Fast%20Start%20-%20Trigger%20Actions.md)
- [Fast Start - Feature Flags](Fast%20Start%20-%20Feature%20Flags.md)
- [Fast Start - Logging](Fast%20Start%20-%20Logging.md)
- [Custom Validations Developer Guide](Validation%20-%20Guide.md)
- [UTIL_ValidationRule API Reference](reference/apex/UTIL_ValidationRule.md)
- [Formula Functions Reference](reference/apex/UTIL_FormulaFilter.md)
