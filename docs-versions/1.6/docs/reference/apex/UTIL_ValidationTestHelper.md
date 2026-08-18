---
title: "UTIL_ValidationTestHelper"
type: class
pageClass: reference
description: "Reusable utility class for testing validation rules. This is NOT a test class itself but provides assertion methods for subscriber test classes and the framework's own test classes to verify validatio"
author: "Jason Van Beukering"
group: "Testing"
date: "January 2026, May 2026"
since: "1.0"
category: apex
---

# UTIL_ValidationTestHelper

**Class** · Group: `Testing`

<div class="apex-member apex-class">

```apex
global inherited sharing class UTIL_ValidationTestHelper
```

Reusable utility class for testing validation rules. This is NOT a test class itself but provides assertion methods for subscriber test classes and the framework's own test classes to verify validation rule behavior. The class validates records in-memory using the validation framework and provides focused assertions for specific rule failures or passes.

**Example**

```apex
@IsTest
private static void shouldRequireEmail()
{
    Account account = new Account(Name = 'Test');
    UTIL_ValidationTestHelper.assertRuleFails(account, 'Account_Requires_Email');
}
@IsTest
private static void shouldPassWhenEmailProvided()
{
    Account account = new Account(Name = 'Test', Email__c = 'test@test.com');
    UTIL_ValidationTestHelper.assertRulePasses(account, 'Account_Requires_Email');
}
```

**See Also:** [UTIL_ValidationRule](UTIL_ValidationRule.md)

</div>

---

## Methods

| Method | Description |
|--------|-------------|
| global static void [assertRuleFails](#assertrulefails)([SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm) record, [SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm) oldRecord, [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) ruleDeveloperName, [TriggerOperation](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_enum_System_TriggerOperation.htm) operation) | Validates a record and asserts that a specific rule failed, with custom operation. |
| global static void [assertRuleFails](#assertrulefails)([SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm) record, [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) ruleDeveloperName) | Validates a record and asserts that a specific rule failed. |
| global static void [assertRulePasses](#assertrulepasses)([SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm) record, [SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm) oldRecord, [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) ruleDeveloperName, [TriggerOperation](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_enum_System_TriggerOperation.htm) operation) | Validates a record and asserts that a specific rule did NOT fail, with custom operation. |
| global static void [assertRulePasses](#assertrulepasses)([SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm) record, [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) ruleDeveloperName) | Validates a record and asserts that a specific rule did NOT fail. |
| global static [UTIL_ValidationRule.ValidationResult](UTIL_ValidationRule.ValidationResult.md) [validate](#validate)([SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm) record) | Validates a record and returns the full result for advanced assertions. |
| global static [UTIL_ValidationRule.ValidationResult](UTIL_ValidationRule.ValidationResult.md) [validate](#validate)([SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm) record, [SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm) oldRecord, [TriggerOperation](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_enum_System_TriggerOperation.htm) operation) | Validates a record and returns the full result for advanced assertions with operation context. |

### assertRuleFails

<div class="apex-member">

```apex
global static void assertRuleFails(SObject record, SObject oldRecord, String ruleDeveloperName, TriggerOperation operation)
```

Validates a record and asserts that a specific rule failed, with custom operation.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `record` | [SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm) | The new record to validate |
| `oldRecord` | [SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm) | The old version of the record (for update scenarios) |
| `ruleDeveloperName` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The DeveloperName of the validation rule expected to fail |
| `operation` | [TriggerOperation](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_enum_System_TriggerOperation.htm) | The trigger operation context |

**Throws**

| Exception | Description |
|-----------|-------------|
| [System.AssertException](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_classes_exception_methods.htm) | if the rule did not fail for this record |

**Example**

```apex
Account oldAccount = new Account(Name = 'Test', Status__c = 'Draft');
Account newAccount = oldAccount.clone();
newAccount.Status__c = 'Active';
UTIL_ValidationTestHelper.assertRuleFails(newAccount, oldAccount, 'Account_Cannot_Reactivate', TriggerOperation.BEFORE_UPDATE);
```

</div>

<div class="apex-member">

```apex
global static void assertRuleFails(SObject record, String ruleDeveloperName)
```

Validates a record and asserts that a specific rule failed.
The record is validated in-memory against all applicable validation rules,
then the assertion verifies that the specified rule produced an error.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `record` | [SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm) | The record to validate |
| `ruleDeveloperName` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The DeveloperName of the validation rule expected to fail |

**Throws**

| Exception | Description |
|-----------|-------------|
| [System.AssertException](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_classes_exception_methods.htm) | if the rule did not fail for this record |

**Example**

```apex
Account account = new Account(Name = 'Test');
UTIL_ValidationTestHelper.assertRuleFails(account, 'Account_Requires_Email');
```

</div>

### assertRulePasses

<div class="apex-member">

```apex
global static void assertRulePasses(SObject record, SObject oldRecord, String ruleDeveloperName, TriggerOperation operation)
```

Validates a record and asserts that a specific rule did NOT fail, with custom operation.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `record` | [SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm) | The new record to validate |
| `oldRecord` | [SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm) | The old version of the record (for update scenarios) |
| `ruleDeveloperName` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The DeveloperName of the validation rule expected to pass |
| `operation` | [TriggerOperation](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_enum_System_TriggerOperation.htm) | The trigger operation context |

**Throws**

| Exception | Description |
|-----------|-------------|
| [System.AssertException](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_classes_exception_methods.htm) | if the rule failed for this record |

**Example**

```apex
Account oldAccount = new Account(Name = 'Test', Status__c = 'Active');
Account newAccount = oldAccount.clone();
newAccount.Status__c = 'Inactive';
UTIL_ValidationTestHelper.assertRulePasses(newAccount, oldAccount, 'Account_Cannot_Reactivate', TriggerOperation.BEFORE_UPDATE);
```

</div>

<div class="apex-member">

```apex
global static void assertRulePasses(SObject record, String ruleDeveloperName)
```

Validates a record and asserts that a specific rule did NOT fail.
The record is validated in-memory against all applicable validation rules,
then the assertion verifies that the specified rule did not produce an error.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `record` | [SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm) | The record to validate |
| `ruleDeveloperName` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The DeveloperName of the validation rule expected to pass |

**Throws**

| Exception | Description |
|-----------|-------------|
| [System.AssertException](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_classes_exception_methods.htm) | if the rule failed for this record |

**Example**

```apex
Account account = new Account(Name = 'Test', Email__c = 'test@test.com');
UTIL_ValidationTestHelper.assertRulePasses(account, 'Account_Requires_Email');
```

</div>

### validate

<div class="apex-member">

```apex
global static UTIL_ValidationRule.ValidationResult validate(SObject record)
```

Validates a record and returns the full result for advanced assertions.
Use this when you need to make multiple assertions or custom assertions on a single validation run.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `record` | [SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm) | The record to validate |

**Returns** [UTIL_ValidationRule.ValidationResult](UTIL_ValidationRule.ValidationResult.md) — The ValidationResult containing all errors/warnings

**Example**

```apex
Account account = new Account(Name = 'Test');
UTIL_ValidationRule.ValidationResult result = UTIL_ValidationTestHelper.validate(account);
Assert.areEqual(2, result.errors.size(), 'Expected 2 validation errors');
```

</div>

<div class="apex-member">

```apex
global static UTIL_ValidationRule.ValidationResult validate(SObject record, SObject oldRecord, TriggerOperation operation)
```

Validates a record and returns the full result for advanced assertions with operation context.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `record` | [SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm) | The new record to validate |
| `oldRecord` | [SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm) | The old version of the record (for update scenarios) |
| `operation` | [TriggerOperation](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_enum_System_TriggerOperation.htm) | The trigger operation context |

**Returns** [UTIL_ValidationRule.ValidationResult](UTIL_ValidationRule.ValidationResult.md) — The ValidationResult containing all errors/warnings

**Example**

```apex
Account oldAccount = new Account(Id = '001000000000001', Name = 'Test');
Account newAccount = oldAccount.clone(true, true, true, true);
newAccount.Name = 'Updated';
UTIL_ValidationRule.ValidationResult result = UTIL_ValidationTestHelper.validate(newAccount, oldAccount, TriggerOperation.BEFORE_UPDATE);
Assert.isTrue(result.isValid, 'Expected record to pass validation');
```

</div>

