---
navOrder: 66
---

# Fast Start - Test Data

**Framework:** KernDX | **Total time:** ~30 minutes

> Create test records with automatic field population, bulk creation, parent-child relationships,
> and DML-free query mocking -- override only what your test cares about.

**Before you start:**

- [ ] KernDX package installed in your org
- [ ] Org configured post-install — verify with the **Kern** app's Health Check (see [Installation guide](Installation.md#post-install-configuration))
- [ ] CLI authenticated (`sf org open -o YourOrgAlias` to verify) — or just use the Developer Console
  (Gear Icon > Developer Console) for all Apex work
- [ ] Working in a sandbox or scratch org (not production)

**What you'll build:** A test class that uses `TST_Builder` for clean test data creation and `TST_Mock`
for DML-free query testing -- with 100% coverage on a simple utility class.

**Success looks like:** Your tests create Accounts with auto-populated fields, bulk cycling values, and
DML-free mocks -- all without hardcoding boilerplate setup code.

**In one line:** `kern.TST_Builder.of(Account.SObjectType).withOverride(Account.Industry, 'Technology').build();` --
auto-populates required fields, inserts, and returns the record in one expression.

---

## Table of Contents

<details>
<summary>Expand</summary>

1. [Tier 1: See It Work (~2 minutes)](#tier-1-see-it-work-2-minutes)
    - [Create a Record with Auto-Populated Fields](#create-a-record-with-auto-populated-fields)
    - [Override Specific Fields](#override-specific-fields)
    - [Bulk Creation](#bulk-creation)
    - [In-Memory Records (No DML)](#in-memory-records-no-dml)
2. [Tier 2: Build Your Own (~20 minutes)](#tier-2-build-your-own-20-minutes)
    - [Step 1: Create the Utility Class](#step-1-create-the-utility-class)
    - [Step 2: Create the Test Class](#step-2-create-the-test-class)
3. [Tier 3: Production Patterns (~5 minutes)](#tier-3-production-patterns-5-minutes)
    - [Multiple Field Overrides](#multiple-field-overrides)
    - [Mock IDs (No DML)](#mock-ids-no-dml)
    - [TST_Mock for DML-Free Query Interception](#tst_mock-for-dml-free-query-interception)
    - [TST_Factory for Users](#tst_factory-for-users)
    - [TST_Factory for Feature Flags](#tst_factory-for-feature-flags)
    - [Framework Metadata: Trigger and Validation Setup](#framework-metadata-trigger-and-validation-setup)
4. [Common Issues](#common-issues)
5. [What You Now Know](#what-you-now-know)
6. [Next Steps](#next-steps)

</details>

---

## Tier 1: See It Work (~2 minutes)

Use [`TST_Builder`](reference/apex/TST_Builder.md) directly from anonymous Apex. No custom classes needed.

### Create a Record with Auto-Populated Fields

Open **Developer Console > Debug > Open Execute Anonymous Window** and run:

```apex
Account newAccount = (Account)kern.TST_Builder.of(Account.SObjectType)
	.withOverride(Account.Phone, '555-0100').build();

System.debug('Name: ' + newAccount.Name);
System.debug('Id: ' + newAccount.Id);
```

**Expected output** (name is randomly generated):

```text
Name: cqpcCtfZke0
Id: 001...
```

`TST_Builder` populates Salesforce-required fields automatically. Custom validation rules may require additional
`.withOverride()` calls.

### Override Specific Fields

```apex
Account newAccount = (Account)kern.TST_Builder.of(Account.SObjectType)
	.withOverride(Account.Name, 'Acme Corp')
	.withOverride(Account.Industry, 'Technology')
	.withOverride(Account.Phone, '555-0100')
	.withOverride(Account.Website, 'https://example.com')
	.build();

System.debug('Name: ' + newAccount.Name + ', Industry: ' + newAccount.Industry);
```

**Expected output:**

```text
Name: Acme Corp, Industry: Technology
```

### Bulk Creation

Create multiple records with a single DML statement:

```apex
List<SObject> accounts = kern.TST_Builder.of(Account.SObjectType)
	.withOverride(Account.Phone, '555-0100')
	.withCount(3)
	.buildList();

System.debug('Created ' + accounts.size() + ' accounts');
```

### In-Memory Records (No DML)

`.withoutInsertion()` = in-memory only (no Id). `.withoutInsertion(true)` = in-memory with mock Id (for code
that checks `record.Id != null`).

```apex
Account inMemory = (Account)kern.TST_Builder.of(Account.SObjectType)
	.withOverride(Account.Name, 'In-Memory Co')
	.withoutInsertion()
	.build();

System.debug('Id: ' + inMemory.Id + ', Name: ' + inMemory.Name);
```

**Expected output:**

```text
Id: null, Name: In-Memory Co
```

> **When to move to Tier 2:** When you want to use `TST_Builder` in real test classes with parent-child
> relationships, cycling values, and query mocking.

---

## Tier 2: Build Your Own (~20 minutes)

> **No local project?** You can create classes directly in the Developer Console (Gear Icon > Developer
> Console > File > New > Apex Class) and run tests from there too (Test > New Run). Paste the code, save,
> and skip the `sf project deploy start` and `sf apex run test` commands.

Build a utility class that counts Accounts by industry, then write tests using `TST_Builder` and `TST_Mock`.

### Step 1: Create the Utility Class

Create a new file named `FastStart_TestData_DEMO.cls`:

```apex
/**
 * @description Counts Account records by Industry.
 *
 * @see FastStart_TestData_DEMO_TEST
 *
 * @author your.name@company.com
 *
 * @group Utilities
 *
 * @date May 2026
 */
public with sharing class FastStart_TestData_DEMO
{
	/**
	 * @description Returns the number of Accounts whose Industry matches the given value.
	 *
	 * @param industry The Industry picklist value to filter on.
	 *
	 * @return The count of matching Account records.
	 */
	public static Integer countAccountsByIndustry(String industry)
	{
		return kern.QRY_Builder.selectFrom(Account.SObjectType)
			.condition(Account.Industry).equals(industry)
			.count();
	}
}
```

**Deploy:**

```bash
sf project deploy start -o YourOrgAlias -m "ApexClass:FastStart_TestData_DEMO"
```

### Step 2: Create the Test Class

Create a new file named `FastStart_TestData_DEMO_TEST.cls`:

```apex
/**
 * @description Unit tests for FastStart_TestData_DEMO.
 * Demonstrates TST_Builder (real DML), TST_Mock (DML-free), and cycling values.
 *
 * @see FastStart_TestData_DEMO
 *
 * @author your.name@company.com
 *
 * @group Utilities
 *
 * @date May 2026
 */
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest(SeeAllData=false IsParallel=true)
private class FastStart_TestData_DEMO_TEST
{
	/** @description Industry value used in insert-based tests. */
	private static final String INDUSTRY_TECH = 'Technology';

	/** @description Industry value used in mock-based tests. */
	private static final String INDUSTRY_FINANCE = 'Finance';

	/** @description Industry that should yield no results. */
	private static final String INDUSTRY_OTHER = 'Education';

	/** @description Verifies that 5 inserted accounts are counted correctly. */
	@IsTest
	private static void shouldCountRealInsertedAccounts()
	{
		kern.TST_Builder.of(Account.SObjectType)
			.withOverride(Account.Industry, INDUSTRY_TECH)
			.withCount(5)
			.buildList();

		Integer result = FastStart_TestData_DEMO.countAccountsByIndustry(INDUSTRY_TECH);

		Assert.areEqual(5, result, 'Count should match the 5 inserted Technology accounts');
	}

	/** @description Verifies cycling values produce the expected mix of industries. */
	@IsTest
	private static void shouldBuildListWithCyclingIndustryValues()
	{
		List<SObject> records = kern.TST_Builder.of(Account.SObjectType)
			.withCycle(Account.Industry, new List<Object>{ INDUSTRY_TECH, INDUSTRY_FINANCE })
			.withCount(4)
			.buildList();

		Assert.areEqual(4, records.size(), 'buildList should return 4 records');
		Assert.areEqual(2, FastStart_TestData_DEMO.countAccountsByIndustry(INDUSTRY_TECH), 'Should have 2 Technology accounts');
		Assert.areEqual(2, FastStart_TestData_DEMO.countAccountsByIndustry(INDUSTRY_FINANCE), 'Should have 2 Finance accounts');
	}

	/** @description Verifies TST_Mock registers a record without DML so QRY_Builder returns it. */
	@IsTest
	private static void shouldCountMockedAccountWithoutDml()
	{
		kern.TST_Mock.of(Account.SObjectType)
			.withOverride(Account.Industry, INDUSTRY_FINANCE)
			.build();

		Integer result = FastStart_TestData_DEMO.countAccountsByIndustry(INDUSTRY_FINANCE);

		Assert.areEqual(1, result, 'Mock-registered Finance account should be returned by QRY_Builder count');
	}

	/** @description Verifies an in-memory record does not affect the database count. */
	@IsTest
	private static void shouldReturnZeroWhenNoMatchingAccounts()
	{
		kern.TST_Builder.of(Account.SObjectType)
			.withOverride(Account.Industry, INDUSTRY_TECH)
			.withoutInsertion()
			.build();

		Integer result = FastStart_TestData_DEMO.countAccountsByIndustry(INDUSTRY_OTHER);

		Assert.areEqual(0, result, 'In-memory record should not affect the database count for a different industry');
	}
}
```

**Deploy and run:**

```bash
sf project deploy start -o YourOrgAlias -m "ApexClass:FastStart_TestData_DEMO" -m "ApexClass:FastStart_TestData_DEMO_TEST"
sf apex run test -o YourOrgAlias -t FastStart_TestData_DEMO_TEST --code-coverage --synchronous --result-format human
```

**Expected:** 4 tests passing, 100% coverage on `FastStart_TestData_DEMO`.

**Why it works -- key patterns:**

- **`TST_Builder.of(SObjectType)`** -- Creates a builder for any SObject type. Auto-populates required fields.
- **`.withOverride(field, value)`** -- Sets specific field values. Override only what matters for the test.
- **`.withoutInsertion()`** -- Builds in-memory (no DML). Use when testing logic that doesn't need a real record.
- **`.withCycle(field, values)`** -- Rotates values across records in `buildList()`. One call covers multiple scenarios.
- **`.withCount(n).buildList()`** -- Bulk creation with a single DML statement.
- **`TST_Mock.of(SObjectType).build()`** -- Creates a record without DML and auto-registers it so that
  `QRY_Builder` queries return mock data instead of hitting the database.

> **About the annotations:** `@IsTest(SeeAllData=false IsParallel=true)` is the standard declaration for
> classes that don't insert `User` / `Group` / `PermissionSet` records. `@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')`
> suppresses a static analysis rule about `System.runAs()` -- fine for quick starts, but consider adding
> `System.runAs()` in production tests to verify profile and permission set access. Remove `IsParallel=true`
> if your test class inserts `User` records (Salesforce forbids `User` DML in parallel tests).

---

## Tier 3: Production Patterns (~5 minutes)

### Multiple Field Overrides

Use a map when overriding many fields:

```apex
Account record = (Account)kern.TST_Builder.of(Account.SObjectType)
	.withOverrides(new Map<SObjectField, Object>
	{
		Account.Name => 'Acme Corp',
		Account.Industry => 'Technology',
		Account.AnnualRevenue => 5000000,
		Account.Phone => '555-0100',
		Account.Website => 'https://example.com'
	})
	.build();
```

### Mock IDs (No DML)

Generate fake IDs for records that need an ID but don't need database insertion:

```apex
Account mockAccount = (Account)kern.TST_Builder.of(Account.SObjectType)
	.withOverride(Account.Name, 'Mock Corp')
	.withoutInsertion(true)
	.build();

System.debug('Mock Id: ' + mockAccount.Id); // e.g., 001000000000001AAA
```

Use `.withoutInsertion(true)` when you need an ID for logic that checks `record.Id != null` but don't
want to hit the database.

### TST_Mock for DML-Free Query Interception

[`TST_Mock`](reference/apex/TST_Mock.md) creates mock records and automatically registers them so that
`QRY_Builder` queries return mock data instead of hitting the database.

> **`@IsTest` context only:** `TST_Mock` works exclusively inside test classes. The examples below show
> how to use it in test methods -- they cannot be run from Execute Anonymous.

```apex
/** @description Tests that the classifier handles mock data without DML. */
@IsTest
private static void shouldClassifyMockedAccount()
{
	kern.TST_Mock.of(Account.SObjectType)
		.withOverride(Account.Name, 'Mock Corp')
		.withOverride(Account.Industry, 'Technology')
		.build();

	Account result = (Account)kern.QRY_Builder.selectFrom(Account.SObjectType)
		.fields(new List<SObjectField>{ Account.Name, Account.Industry })
		.getFirst();

	Assert.areEqual('Mock Corp', result.Name, 'Should return mock record');
	Assert.areEqual('Technology', result.Industry, 'Should have mocked Industry');
}
```

Multiple mocks with bulk cycling:

```apex
@IsTest
private static void shouldReturnBulkMocks()
{
	kern.TST_Mock.of(Account.SObjectType)
		.withCycle(Account.Industry, new List<Object>{ 'Technology', 'Finance' })
		.withCount(4)
		.buildList();

	List<Account> results = kern.QRY_Builder.selectFrom(Account.SObjectType)
		.fields(new List<SObjectField>{ Account.Name, Account.Industry })
		.toList();

	Assert.areEqual(4, results.size(), 'Should return 4 mock records');
}
```

Clear mocks when needed (Salesforce resets static state between test methods automatically):

```apex
kern.TST_Mock.clear();                      // Clear all types
kern.TST_Mock.clear(Account.SObjectType);   // Clear one type
```

#### Negative-Path: Simulate a SOQL Failure

`kern.TST_Mock.throwsException(SObjectType[, Exception/String])` registers an exception that fires the next
time the framework queries the specified type. Use it to exercise catch blocks around a SOQL call without
having to mock at a different layer.

```apex
/** @description Verifies the caller surfaces a friendly error when the underlying SOQL fails. */
@IsTest
private static void shouldHandleQueryFailureGracefully()
{
	Id accountId = kern.UTIL_Random.randomId(Account.SObjectType);
	kern.TST_Mock.throwsException(Account.SObjectType, new QueryException('Simulated SOQL failure'));

	try
	{
		new SEL_Accounts().findById(accountId);
		Assert.fail('Expected the SEL_Accounts query to throw');
	}
	catch(QueryException error)
	{
		Assert.areEqual('Simulated SOQL failure', error.getMessage(), 'Should rethrow the simulated failure');
	}
}
```

> **`SEL_Accounts` is the selector you build in the [Selectors Fast Start](Fast%20Start%20-%20Selectors.md)** —
> it isn't part of the package. If you haven't created it, swap in a selector you already have, or query inline
> with `kern.QRY_Builder.selectFrom(Account.SObjectType)...` so this snippet is self-contained.

Three overloads are available; pick the shortest that names the failure:

```apex
// Throw a custom exception (most explicit)
kern.TST_Mock.throwsException(Account.SObjectType, new QueryException('Simulated failure'));

// Throw a QueryException with a message (most common)
kern.TST_Mock.throwsException(Account.SObjectType, 'Simulated failure');

// Throw a generic QueryException naming the SObjectType (quickest)
kern.TST_Mock.throwsException(Account.SObjectType);
```

**Coexistence with record mocks:** if both an exception and records are registered for the same
`SObjectType`, the exception is thrown first -- the record path is unreachable. Both registrations are
wiped by `kern.TST_Mock.clear()` and `kern.TST_Mock.clear(SObjectType)`.

### TST_Factory for Users

Create test users with specific profiles. Remove `IsParallel=true` from the test class header when inserting
`User` records -- Salesforce forbids `User` DML in parallel tests.

```apex
/** @description Tests behaviour as a Standard User. */
@IsTest
private static void shouldRunAsStandardUser()
{
	User testUser = kern.TST_Factory.newUser('Standard User');
	kern.DML_Builder.newTransaction().doInsert(testUser).execute();

	System.runAs(testUser)
	{
		Account record = (Account)kern.TST_Builder.of(Account.SObjectType)
			.withOverride(Account.Industry, 'Technology')
			.withoutInsertion()
			.build();

		Assert.areEqual('Technology', record.Industry, 'Industry should be set');
	}
}
```

### TST_Factory for Feature Flags

Create and activate a feature flag for testing flag-gated code paths:

```apex
kern.TST_Factory.newFeatureFlag('MyFeatureFlag');

Boolean isEnabled = kern.UTIL_FeatureFlag.isEnabled('MyFeatureFlag');
Assert.isTrue(isEnabled, 'Flag should be enabled');
```

### Framework Metadata: Trigger and Validation Setup

To exercise framework Trigger Action or Validation Rule behaviour in your tests -- or to set up that
metadata from a setup script -- deploy the relevant `CustomMetadata` records via XML. See
[Fast Start - Trigger Actions](Fast%20Start%20-%20Trigger%20Actions.md) and
[Fast Start - Custom Validations](Fast%20Start%20-%20Custom%20Validations.md) for the XML deploy pattern.

Once the metadata is in place, the action or validation fires through the normal trigger path, so your
test simply builds a record and asserts the resulting behaviour:

```apex
@IsTest
private static void shouldFireTriggerAction()
{
	Account record = (Account)kern.TST_Builder.of(Account.SObjectType).build();
	Assert.isNotNull(record.Id, 'Record should be inserted and the trigger action should have fired');
}
```

---

## Common Issues

| Problem                                                            | Cause                                                      | Fix                                                                      |
|--------------------------------------------------------------------|------------------------------------------------------------|--------------------------------------------------------------------------|
| `SObject` type mismatch                                            | Forgot to cast `.build()` result                           | Cast: `(Account)kern.TST_Builder.of(Account.SObjectType).build()`        |
| `REQUIRED_FIELD_MISSING` on insert                                 | Field marked required but builder doesn't know about it    | Add `.withOverride(field, value)` for the missing field                  |
| Records created in a loop                                          | Using `.build()` inside a loop                             | Use `.withCount(n).buildList()` for bulk creation (single DML)           |
| Mock IDs when not needed                                           | Using `.withoutInsertion(true)` for simple in-memory tests | Use `.withoutInsertion()` (no argument) when IDs aren't needed           |
| Mocks leaking between tests                                        | Forgetting to clear `TST_Mock` state                       | Salesforce resets static state between tests -- no manual cleanup needed |
| `null` for optional fields                                         | Builder only auto-populates required fields                | Use `.withOverride()` to set optional fields your test needs             |
| Trigger action or validation rule doesn't fire in a test           | The framework metadata isn't present in the org            | Deploy the relevant `CustomMetadata` records via XML for triggers and validations |

---

## What You Now Know

After completing this guide, you understand the **three test data tools** in KernDX:

| Tool              | When to Use                              | What You Get                                                                     |
|-------------------|------------------------------------------|----------------------------------------------------------------------------------|
| **`TST_Builder`** | All SObject construction in tests        | Auto-populated fields, bulk, cycling, parent-child, real DML                     |
| **`TST_Mock`**    | DML-free query interception in `@IsTest` | Mock records auto-registered for `QRY_Builder` without touching the database     |
| **`TST_Factory`** | Users and feature flags                  | Test users and feature flags ready for your tests                                |

**Key patterns:**

- **Override only what matters** -- let `TST_Builder` handle required fields. Tests stay focused on behaviour.
- **`.withoutInsertion()` for logic tests** -- skip DML when testing pure logic (faster tests, no governor cost)
- **`.withCycle()` for multiple scenarios** -- test different values without writing separate test methods
- **`.withChildren()` for relationships** -- auto-handles foreign key assignment
- **`TST_Mock` for query mocking** -- no DML, no database, mock data flows through `QRY_Builder`
- **Framework metadata via XML** -- to exercise trigger or validation behaviour in your tests, deploy the
  relevant `CustomMetadata` records via XML

---

## Next Steps

- [Selectors (query patterns)](Fast%20Start%20-%20Selectors.md)
- [DML Builder (writes)](Fast%20Start%20-%20DML.md)
- [Trigger Actions (testing triggers)](Fast%20Start%20-%20Trigger%20Actions.md)
- [Custom Validations](Fast%20Start%20-%20Custom%20Validations.md)
- [E2E Testing (Playwright + RunLocalTests harness)](Fast%20Start%20-%20E2E%20Testing.md)
- [TST_Builder Reference](reference/apex/TST_Builder.md)
- [TST_Mock Reference](reference/apex/TST_Mock.md)
- [TST_Factory Reference](reference/apex/TST_Factory.md)
