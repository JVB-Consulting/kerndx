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

**Success looks like:** Two test methods pass at 100% coverage, and you can query live CMDT records
to see exactly what's configured.

**In one line:** `kern.UTIL_ValidationTestHelper.assertRuleFails(record, 'MyRule');` — test any
metadata-configured rule without DML or triggers.

---

## Table of Contents

<details>
<summary>Expand</summary>

1. [Tier 1: See It Work (~3 minutes)](#tier-1-see-it-work-3-minutes)
2. [Tier 2: Build Your Own (~15-17 minutes)](#tier-2-build-your-own-15-17-minutes)
   - [Step 1: Deploy the DEMO class and test](#step-1-deploy-the-demo-class-and-test)
   - [Step 2: Deploy the CMDT fixtures](#step-2-deploy-the-cmdt-fixtures)
   - [Step 3: Run the tests](#step-3-run-the-tests)
   - [What the test class demonstrates](#what-the-test-class-demonstrates)
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

## Tier 1: See It Work (~3 minutes)

Custom validations are metadata-driven — you define rules as CMDT records, not Apex code. Three
record types form a parent-child hierarchy:

```text
TriggerSetting__mdt (Account)
 └── ValidationRuleGroup__mdt (AccountValidation)
      └── ValidationRule__mdt (PhoneOrWebsiteRequired)
```

The subscriber test org ships with these records already deployed. Query them now to see what's
configured:

```apex
List<kern__ValidationRuleGroup__mdt> groups =
[
    SELECT DeveloperName, kern__TriggerOperations__c, kern__ExecutionStrategy__c
    FROM kern__ValidationRuleGroup__mdt
    WHERE kern__TriggerSetting__c = 'Account'
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
    WHERE kern__ValidationRuleGroup__c = 'AccountValidation'
    LIMIT 10
];
for(kern__ValidationRule__mdt rule : rules)
{
    System.debug(rule.DeveloperName + ': ' + rule.kern__ErrorMessage__c);
}
```

Now run a rule in-memory against a record — no DML, no trigger needed:

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
Error: Either Phone or Website is required (field: null)
```

Fix the record and validate again:

```apex
Account validAccount = new Account(Name = 'Test Corp', Phone = '1234567890');
kern.UTIL_ValidationRule.ValidationResult result = kern.UTIL_ValidationTestHelper.validate(validAccount);
System.debug('Valid: ' + result.isValid + ' — Errors: ' + result.errors.size());
```

**Expected output:**
```text
Valid: true — Errors: 0
```

> **Formula logic is inverted:** formula returns `true` = validation **fails** (record is invalid).
> `ISBLANK(newRecord.Phone)` returns `true` when Phone is blank — the rule fires. When Phone is
> populated the formula returns `false` — the rule is satisfied.

---

## Tier 2: Build Your Own (~15-17 minutes)

> **No local project?** Create classes directly in Developer Console (Gear Icon > Developer Console >
> File > New > Apex Class) and run tests from there (Test > New Run). Paste the code, save, and skip
> the `sf project deploy start` and `sf apex run test` commands.

### Step 1: Deploy the DEMO class and test

The subscriber release-testing folder ships with `FastStart_Validation_DEMO.cls` and
`FastStart_Validation_DEMO_TEST.cls`. Deploy them:

```bash
sf project deploy start -o YourOrgAlias \
  -m "ApexClass:FastStart_Validation_DEMO" \
  -m "ApexClass:FastStart_Validation_DEMO_TEST" \
  --ignore-conflicts
```

> **Prefer the UI?** In Developer Console, create two new Apex Classes with the names above and
> paste the source from `release-testing/subscriber/classes/`.

### Step 2: Deploy the CMDT fixtures

Two metadata records ship with the subscriber release-testing folder:

- `kern__ValidationRuleGroup.FastStart_AccountRules` — groups the Fast Start demo rules for Account
- `kern__ValidationRule.FastStart_RequiresDescription` — formula `ISBLANK(newRecord.Description)`,
  error message "Description is required"

Both are deployed with `IsActive = false` so they do not fire on live DML in the subscriber org.
The test class activates them in-memory via `kern.TST_Factory.newValidationRule()`.

```bash
sf project deploy start -o YourOrgAlias \
  -m "CustomMetadata:kern__ValidationRuleGroup.FastStart_AccountRules" \
  -m "CustomMetadata:kern__ValidationRule.FastStart_RequiresDescription" \
  --ignore-conflicts
```

### Step 3: Run the tests

```bash
sf apex run test -o YourOrgAlias -t FastStart_Validation_DEMO_TEST \
  --code-coverage --synchronous --result-format human
```

**Expected output:**
```text
=== Test Results
Tests Ran        2
Passing          2
Failing          0
=== Code Coverage
FastStart_Validation_DEMO  100%
```

### What the test class demonstrates

> **Trap:** `kern.TST_Factory.newValidationRule()` is `@TestVisible private` — it works inside
> `@IsTest` context only. It cannot be called from anonymous Apex (Developer Console Execute
> Anonymous). For anonymous-Apex demos, query deployed CMDT records using inline SOQL as shown
> in Tier 1.

The full source is in `release-testing/subscriber/classes/FastStart_Validation_DEMO_TEST.cls`.
The core pattern for the failing case:

```apex
@IsTest
private static void shouldFailWhenDescriptionBlank()
{
    // Bypass all existing Account validation groups so org fixtures don't interfere.
    // bypassObject takes a String — NOT an SObjectType.
    kern.UTIL_ValidationRule.bypassObject('Account');

    // Activate the FastStart rule in-memory — @IsTest context only, NOT anon Apex.
    kern.TST_Factory.newValidationRule(
        'FastStart_RequiresDescription',
        'ISBLANK(newRecord.Description)',
        'Description is required'
    );

    Account record = (Account)kern.TST_Builder.of(Account.SObjectType).withoutInsertion().build();
    kern.UTIL_ValidationTestHelper.assertRuleFails(record, 'FastStart_RequiresDescription');
}
```

### Key patterns

| Pattern | Why |
|---------|-----|
| `bypassObject('Account')` (String param) | Bypasses ALL active Account validation groups — prevents existing org fixtures from interfering |
| `TST_Factory.newValidationRule(name, formula, message)` | Registers a rule in-memory for the current test only — no CMDT deploy needed |
| `assertRuleFails(record, ruleName)` | Evaluates one rule in-memory — no DML, no trigger |
| `withoutInsertion()` | Builds an in-memory record with a fake Id — no database write |
| Formula returns `true` = fails | `ISBLANK(newRecord.Description)` fires when Description is blank |
| `ISPICKVAL()` for picklists | `ISPICKVAL(newRecord.Industry, "Technology")` — use this, not `=`, for picklist values |

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

| Function | Example | Description |
|----------|---------|-------------|
| `ISBLANK(field)` | `ISBLANK(newRecord.Description)` | Field is empty |
| `ISPICKVAL(field, value)` | `ISPICKVAL(newRecord.Industry, "Technology")` | Picklist equals value — use this, not `=` |
| `NOT(condition)` | `NOT(ISBLANK(newRecord.Email))` | Negate a condition |
| `AND(a, b)` | `AND(ISBLANK(newRecord.Phone), ISBLANK(newRecord.Email))` | Both conditions true |
| `OR(a, b)` | `OR(ISBLANK(newRecord.Phone), ISBLANK(newRecord.Email))` | Either condition true |
| `ISCHANGED(old, new, field)` | `ISCHANGED(oldRecord, newRecord, Industry)` | Field value changed on update |

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

| Field | Effect |
|-------|--------|
| `BypassFeatureFlag__c` (on group or rule) | Skip the group/rule when this flag is **enabled** |
| `RequiredFeatureFlag__c` (on group or rule) | Only run the group/rule when this flag is **enabled** |

### Execution strategies and error severity

| Strategy | Behaviour |
|----------|-----------|
| **Accumulate** (default) | Evaluate all rules, collect all errors |
| **Fail Fast** | Stop after the first error per record |

| Severity | Behaviour |
|----------|-----------|
| **Error** | Blocks save, attaches error to record |
| **Warning** | Allows save, logs to Log Entries |

See [Validation - Guide](Validation%20-%20Guide.md) for the complete reference.

---

## Common Issues

| Problem | Cause | Fix |
|---------|-------|-----|
| Rule doesn't fire | Formula syntax error | Check Log Entries for formula compilation errors |
| Picklist comparison fails | Using `=` instead of `ISPICKVAL()` | Use `ISPICKVAL(newRecord.Field, "Value")` for picklists |
| `assertRuleFails` says rule passed | Formula logic inverted | Formula returning `true` means invalid — check your condition |
| Rule fires on insert but not update | `TriggerOperations__c` missing `Update` | Add `Update` to the semicolon-separated list |
| Error not on the right field | Wrong `ErrorDisplayField__c` | Use the field API name only (e.g., `Description` not `Account.Description`) |
| Rules don't fire via trigger | Missing `TriggerAction__mdt` | Create action pointing to `TRG_ExecuteValidationRules` |
| Multiple rules — only first fires | `ExecutionStrategy__c` set to `Fail Fast` | Change to `Accumulate` |
| `newValidationRule` fails from anon Apex | `@TestVisible private` trap | Only callable from `@IsTest` context — use inline SOQL in anon Apex instead |

---

## What You Now Know

| Concept | What it does |
|---------|--------------|
| `ValidationRuleGroup__mdt` | Groups rules for an object and trigger context |
| `ValidationRule__mdt` | Individual formula-based check with error message |
| `UTIL_ValidationTestHelper.validate(record)` | Evaluates all rules in-memory, returns a `ValidationResult` |
| `UTIL_ValidationTestHelper.assertRuleFails(record, ruleName)` | Asserts one rule fires — no DML |
| `UTIL_ValidationTestHelper.assertRulePasses(record, ruleName)` | Asserts one rule is satisfied |
| `UTIL_ValidationRule.bypassObject('Account')` | Bypasses all Account rules — String param |
| `TST_Factory.newValidationRule(name, formula, message)` | Registers a rule in-memory — `@IsTest` only |
| `TRG_ExecuteValidationRules` | Built-in trigger action that enforces rules on save |

**Key patterns:**
- Formulas return `true` when the record is **invalid** (inverted logic)
- Use `ISPICKVAL()` for picklist comparisons, not `=`
- Tests use `UTIL_ValidationTestHelper` — no DML needed, no trigger needed
- `bypassObject` takes a **String** (`'Account'`), not an `SObjectType`
- Deploy validation metadata as XML for version control; use `IsActive = false` to avoid
  cross-demo interference

---

## Next Steps

| Topic | Link |
|-------|------|
| Fast Start - Trigger Actions | [Fast Start - Trigger Actions](Fast%20Start%20-%20Trigger%20Actions.md) |
| Fast Start - Feature Flags | [Fast Start - Feature Flags](Fast%20Start%20-%20Feature%20Flags.md) |
| Fast Start - Logging | [Fast Start - Logging](Fast%20Start%20-%20Logging.md) |
| Custom Validations Developer Guide | [Validation - Guide](Validation%20-%20Guide.md) |
| UTIL_ValidationRule API Reference | [reference/apex/UTIL_ValidationRule.md](reference/apex/UTIL_ValidationRule.md) |
| Formula Functions Reference | [reference/apex/UTIL_FormulaFilter.md](reference/apex/UTIL_FormulaFilter.md) |
