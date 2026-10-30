---
navOrder: 66
---

# Fast Start - Test Data

**Framework:** KernDX | **Total time:** ~30 minutes

**What this is:** A faster way to build the data your Apex tests need. You write one short expression and the framework fills in every required field, so you spell out only the values the test cares about. **Why it exists:** Hand-written test setup is slow, brittle when an admin adds a required field, and wastes governor limits on records you do not need. **Who should care:** Any developer writing Apex tests, and tech leads who want setup that survives schema changes. **When to use it:** Whenever a test needs records, saved, kept in memory, or returned from a query. For a single record with one or two fields, plain `new Account(...)` is still fine; reach for the builder once required fields, bulk data, or query mocking start adding boilerplate.

> **Namespaces in code samples:** `kern.` on a class and `kern__` on an object, field, or metadata type mark the managed package's namespace.
> On the managed package, framework references need those prefixes even where a sample omits them; repackaged under your own namespace, replace `kern`/`kern__`
> with your prefix; on an unmanaged deploy, drop them. See [How to read the code samples](Installation.md#how-to-read-the-code-samples).

**What you'll build:** A test class that uses `TST_Builder` for clean test data creation and `TST_Mock`
for query testing without saving records (no DML), reaching 100% coverage on a simple utility class.

**Success looks like:** Your tests create Accounts with auto-populated fields, bulk cycling values, and
mocks that need no DML, all without hand-writing boilerplate setup code.

**In one line:** `kern.TST_Builder.of(Account.SObjectType).withOverride(Account.Industry, 'Technology').build();`
auto-populates required fields, inserts, and returns the record in one expression.

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
    - [Create a Record with Auto-Populated Fields](#create-a-record-with-auto-populated-fields)
    - [Override Specific Fields](#override-specific-fields)
    - [Bulk Creation](#bulk-creation)
    - [In-Memory Records (No DML)](#in-memory-records-no-dml)
3. [Tier 2: Build Your Own (~20 minutes)](#tier-2-build-your-own-20-minutes)
    - [Step 1: Create the Utility Class](#step-1-create-the-utility-class)
    - [Step 2: Write and run the test](#step-2-write-and-run-the-test)
4. [Tier 3: Production Patterns (~5 minutes)](#tier-3-production-patterns-5-minutes)
    - [Multiple Field Overrides](#multiple-field-overrides)
    - [Mock IDs (No DML)](#mock-ids-no-dml)
    - [TST_Mock for DML-Free Query Interception](#tst_mock-for-dml-free-query-interception)
    - [TST_Factory for Users](#tst_factory-for-users)
    - [TST_Factory for Feature Flags](#tst_factory-for-feature-flags)
    - [Framework Metadata: Trigger and Validation Setup](#framework-metadata-trigger-and-validation-setup)
    - [Clean up](#clean-up)
5. [Common Issues](#common-issues)
    - [Tier 1: See It Work (~2 minutes)](#tier-1-see-it-work-2-minutes-1)
    - [Step 1: Create the Utility Class](#step-1-create-the-utility-class-1)
    - [Step 2: Write and run the test](#step-2-write-and-run-the-test-1)
    - [Tier 3: Production Patterns (~5 minutes)](#tier-3-production-patterns-5-minutes-1)
6. [What You Now Know](#what-you-now-know)
7. [Next Steps](#next-steps)

</details>

---

## Tier 1: See It Work (~2 minutes)

See the builder make a record in under a minute. You can run [`TST_Builder`](reference/apex/TST_Builder.md) straight from anonymous Apex, with no custom classes to write first.

### Create a Record with Auto-Populated Fields

**In Salesforce**, open the Developer Console (the gear icon, then Developer Console), then Debug, then Open Execute
Anonymous Window, and run:

```apex
Account newAccount = (Account)kern.TST_Builder.of(Account.SObjectType)
	.withOverride(Account.Phone, '555-0100').build();

System.debug('Name: ' + newAccount.Name);
System.debug('Id: ' + newAccount.Id);
```

You should see lines like these in the log (the name is randomly generated):

```text
Name: cqpcCtfZke0
Id: 001...
```

You did not have to set a name: `TST_Builder` fills in every Salesforce-required field for you. If your org has custom validation rules that demand specific values, add a `.withOverride()` call for each of those fields.

### Override Specific Fields

**In Salesforce**, in the same Execute Anonymous window, run:

```apex
Account newAccount = (Account)kern.TST_Builder.of(Account.SObjectType)
	.withOverride(Account.Name, 'Acme Corp')
	.withOverride(Account.Industry, 'Technology')
	.withOverride(Account.Phone, '555-0100')
	.withOverride(Account.Website, 'https://example.com')
	.build();

System.debug('Name: ' + newAccount.Name + ', Industry: ' + newAccount.Industry);
```

You should see this line in the log:

```text
Name: Acme Corp, Industry: Technology
```

### Bulk Creation

Create multiple records with a single DML statement.

**In Salesforce**, in the same Execute Anonymous window, run:

```apex
List<SObject> accounts = kern.TST_Builder.of(Account.SObjectType)
	.withOverride(Account.Phone, '555-0100')
	.withCount(3)
	.buildList();

System.debug('Created ' + accounts.size() + ' accounts');
```

You should see `Created 3 accounts` in the log.

### In-Memory Records (No DML)

Sometimes a test only needs a record in memory, never saved to the database, which keeps the test fast and avoids governor-limit cost. Two options cover this:

- `.withoutInsertion()` gives you an in-memory record with no Id.
- `.withoutInsertion(true)` gives you an in-memory record with a fake Id, useful for code that checks `record.Id != null`.

**In Salesforce**, in the same Execute Anonymous window, run:

```apex
Account inMemory = (Account)kern.TST_Builder.of(Account.SObjectType)
	.withOverride(Account.Name, 'In-Memory Co')
	.withoutInsertion()
	.build();

System.debug('Id: ' + inMemory.Id + ', Name: ' + inMemory.Name);
```

You should see this line in the log:

```text
Id: null, Name: In-Memory Co
```

Something went wrong? See [Common Issues, Tier 1](#tier-1-see-it-work-2-minutes-1).

> **When to move to Tier 2:** When you want to use `TST_Builder` in real test classes with parent-child
> relationships, cycling values, and query mocking.

---

## Tier 2: Build Your Own (~20 minutes)

> **No local project?** You can create classes directly in the Developer Console (Gear Icon > Developer
> Console > File > New > Apex Class) and run tests from there too (Test > New Run). Paste the code, save,
> and skip the terminal commands.

Build a utility class that counts Accounts by industry, then write tests using `TST_Builder` and `TST_Mock`.

### Step 1: Create the Utility Class

You create an empty class with one command, paste the code into it, then send it to your org.

**1. In the terminal**, from your project's top folder, create the empty class:

```shell
sf apex generate class --name FastStart_TestData_DEMO --output-dir force-app/main/default/classes
```

You should see two files created in `force-app/main/default/classes`, both named `FastStart_TestData_DEMO`: the
class, ending in `.cls`, and its companion, ending in `.cls-meta.xml`.

The second file tells Salesforce which API version the class uses. You never edit it, but a deploy fails without it.

**2. In your editor**, open this file, delete what is there, paste the code below in, and save:

```text
force-app/main/default/classes/FastStart_TestData_DEMO.cls
```

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

**3. In the terminal**, send the class to your org:

```shell
sf project deploy start -o YourOrgAlias -m "ApexClass:FastStart_TestData_DEMO"
```

You should see `Status: Succeeded`, with `FastStart_TestData_DEMO` listed as created.

Something went wrong? See [Common Issues, Step 1](#step-1-create-the-utility-class-1).

### Step 2: Write and run the test

The test class counts real inserted Accounts, cycles Industry values across a list, counts a mocked Account with no
DML, and checks that an in-memory record leaves the database count alone. You create the empty class with one
command, paste the code into it, send it to your org, then run it.

**1. In the terminal**, from your project's top folder, create the empty test class:

```shell
sf apex generate class --name FastStart_TestData_DEMO_TEST --output-dir force-app/main/default/classes
```

You should see two files created in `force-app/main/default/classes`, both named `FastStart_TestData_DEMO_TEST`:
the class, ending in `.cls`, and its companion, ending in `.cls-meta.xml`.

**2. In your editor**, open this file, delete what is there, paste the code below in, and save:

```text
force-app/main/default/classes/FastStart_TestData_DEMO_TEST.cls
```

```apex
/**
 * @description Unit tests for FastStart_TestData_DEMO. They show TST_Builder saving real records, and TST_Mock answering a
 * query with records that are never saved to the database.
 *
 * @see FastStart_TestData_DEMO
 *
 * @author your.name@company.com
 *
 * @group Fast Start Demos
 *
 * @date May 2026, October 2026
 */
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest(seeAllData=false isParallel=true)
private class FastStart_TestData_DEMO_TEST
{
	/**
	 * @description Industry value used across insert-based tests.
	 */
	private static final String INDUSTRY_TECH = 'Technology';

	/**
	 * @description Industry value used for the mock-based count test.
	 */
	private static final String INDUSTRY_FINANCE = 'Finance';

	/**
	 * @description Verifies that TST_Builder inserts records that are visible to a real SOQL count.
	 * Demonstrates: .withOverride() + .withCount() + .buildList() with a real DML insert.
	 */
	@IsTest
	private static void shouldCountRealInsertedAccounts()
	{
		kern.UTIL_ValidationRule.bypassObject('Account');
		kern.TST_Builder.of(Account.SObjectType)
				.withOverride(Account.Industry, INDUSTRY_TECH)
				.withCount(5)
				.buildList();

		Integer result = FastStart_TestData_DEMO.countAccountsByIndustry(INDUSTRY_TECH);

		Assert.areEqual(5, result, 'Count should match the 5 inserted Technology accounts');
	}

	/**
	 * @description Verifies that TST_Builder bulk-inserts records with cycling values and that
	 * each build() call produces a persisted record with a real Id.
	 * Demonstrates: .withCycle() + .withCount() + .buildList() return values.
	 */
	@IsTest
	private static void shouldBuildListWithCyclingIndustryValues()
	{
		kern.UTIL_ValidationRule.bypassObject('Account');
		List<SObject> records = kern.TST_Builder.of(Account.SObjectType)
				.withCycle(Account.Industry, new List<Object> {INDUSTRY_TECH, INDUSTRY_FINANCE})
				.withCount(4)
				.buildList();

		Assert.areEqual(4, records.size(), 'buildList should return 4 records');

		for(SObject record : records)
		{
			Assert.isNotNull(record.Id, 'Each record should have a real database Id after buildList()');
		}

		Assert.areEqual(2, FastStart_TestData_DEMO.countAccountsByIndustry(INDUSTRY_TECH), 'Should have 2 Technology accounts');
		Assert.areEqual(2, FastStart_TestData_DEMO.countAccountsByIndustry(INDUSTRY_FINANCE), 'Should have 2 Finance accounts');
	}

	/**
	 * @description Verifies that TST_Mock registers a Finance account without DML so that the
	 * QRY_Builder-backed count returns 1 without touching the database.
	 * Shows that TST_Mock.of().withOverride().build() registers the mock record by itself, with no extra call.
	 */
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

		Integer result = FastStart_TestData_DEMO.countAccountsByIndustry(INDUSTRY_TECH);

		Assert.areEqual(0, result, 'An in-memory record is not saved, so the database count should be 0');
	}
}
```

**3. In the terminal**, send both classes to your org:

```shell
sf project deploy start -o YourOrgAlias -m "ApexClass:FastStart_TestData_DEMO" -m "ApexClass:FastStart_TestData_DEMO_TEST"
```

You should see `Status: Succeeded`, with `FastStart_TestData_DEMO_TEST` listed as created and
`FastStart_TestData_DEMO` as unchanged.

**4. In the terminal**, run the test:

```shell
sf apex run test -o YourOrgAlias -t FastStart_TestData_DEMO_TEST --code-coverage --synchronous --result-format human
```

You should see 4 tests passing and 100% coverage on `FastStart_TestData_DEMO`: all four tests show `Pass`, the summary
line `Outcome` reads `Passed`, and the coverage table shows `FastStart_TestData_DEMO` at `100%`.

**Why it works, line by line:**

- **`TST_Builder.of(SObjectType)`** creates a builder for any SObject type and auto-populates its required fields.
- **`.withOverride(field, value)`** sets a specific field value. Override only what matters for the test.
- **`.withoutInsertion()`** builds the record in memory without saving it (no DML). Use it when testing logic that does not need a real record.
- **`.withCycle(field, values)`** rotates through the values across the records in `buildList()`, so one call covers multiple scenarios.
- **`.withCount(n).buildList()`** creates many records with a single DML statement.
- **`TST_Mock.of(SObjectType).build()`** creates a record without saving it (no DML) and registers it automatically, so `QRY_Builder` queries return the mock data instead of reading the database.

> **About the annotations:** `@IsTest(seeAllData=false isParallel=true)` is the standard declaration for
> classes that don't insert `User` / `Group` / `PermissionSet` records. `@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')`
> turns off a code-scanner rule (static analysis, which checks code without running it) that wants every test
> to use `System.runAs()`. That is fine for a quick start, but in production tests consider adding `System.runAs()`
> to verify profile and permission set access. Remove `IsParallel=true` if your test class inserts `User` records,
> because Salesforce forbids `User` DML in parallel tests.

Something went wrong? See [Common Issues, Step 2](#step-2-write-and-run-the-test-1).

---

## Tier 3: Production Patterns (~5 minutes)

### Multiple Field Overrides

Use a map when overriding many fields.

**In your editor**, in a test method:

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

Generate fake IDs for records that need an ID but don't need database insertion.

**In your editor**, in a test method:

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

Some tests need to check how your code reacts to query results without paying to save those records first. [`TST_Mock`](reference/apex/TST_Mock.md) creates records, keeps them in memory, and registers them so `QRY_Builder` queries return that mock data instead of reading the database.

> **`@IsTest` context only:** `TST_Mock` works only inside test classes. The examples below show how to use it
> in test methods. They cannot be run from Execute Anonymous.

**In your editor**, in a test class:

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

Multiple mocks with bulk cycling.

**In your editor**, in a test class:

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

Clear mocks when needed (Salesforce resets static state between test methods automatically).

**In your editor**, in a test method:

```apex
kern.TST_Mock.clear();                      // Clear all types
kern.TST_Mock.clear(Account.SObjectType);   // Clear one type
```

A cleared object queries the database again, so `kern.TST_Mock.clear()` is also the way to switch from mock data to
real rows partway through a test.

#### Different Answers for Consecutive Queries

Some code reads the same object twice and behaves differently when the second read finds what the first one missed: a
find-or-create, a retry, a check that runs again after a save. To script that, register an answer for the next query
only. Each answer serves exactly one query, in the order you registered them, and once they are used up the object goes
back to whatever you registered with `register`, or to the database if you registered nothing.

**In your editor**, in a test class:

```apex
/** @description Verifies the caller creates the row when the first read misses and reuses it when the second read finds it. */
@IsTest
private static void shouldCreateOnTheFirstMissAndReuseOnTheSecondRead()
{
	Account existing = (Account)kern.TST_Builder.of(Account.SObjectType).withOverride(Account.Name, 'Mock Corp').build();
	kern.TST_Mock.registerNext(Account.SObjectType, new List<SObject>());

	Account first = (Account)kern.QRY_Builder.selectFrom(Account.SObjectType).condition(Account.Name).equals('Mock Corp').getFirst();
	Account second = (Account)kern.QRY_Builder.selectFrom(Account.SObjectType).condition(Account.Name).equals('Mock Corp').getFirst();

	Assert.isNull(first, 'The scripted answer makes the first read miss');
	Assert.areEqual(existing.Id, second.Id, 'The second read goes back to the database and finds the row');
}
```

An empty list means "finds nothing". A single record has its own overload: `kern.TST_Mock.registerNext(Account.SObjectType, record)`.
A count uses up an answer too and returns its size. `kern.TST_Mock.clear()` and `kern.TST_Mock.clear(Account.SObjectType)`
drop any answers still queued. The row in this example is saved, because the second read reaches the database to find it.

#### Negative-Path: Simulate a SOQL Failure

Good tests also prove that your code handles a query failure gracefully, not just the happy path. To force a query to fail on demand, call `kern.TST_Mock.throwsException(SObjectType[, Exception/String])`: it registers an exception that is thrown on every query the framework runs against that type, until you clear it. This lets you exercise the catch block around a SOQL call without having to fake anything at a lower layer.

**In your editor**, in a test class:

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

> **`SEL_Accounts` is the selector you build in the [Selectors Fast Start](Fast%20Start%20-%20Selectors.md).**
> It isn't part of the package. If you haven't created it, swap in a selector you already have, or query inline
> with `kern.QRY_Builder.selectFrom(Account.SObjectType)...` so this snippet is self-contained.

Three overloads are available; pick the shortest that names the failure.

**In your editor**, in a test method:

```apex
// Throw a custom exception (most explicit)
kern.TST_Mock.throwsException(Account.SObjectType, new QueryException('Simulated failure'));

// Throw a QueryException with a message (most common)
kern.TST_Mock.throwsException(Account.SObjectType, 'Simulated failure');

// Throw a generic QueryException naming the SObjectType (quickest)
kern.TST_Mock.throwsException(Account.SObjectType);
```

**Coexistence with record mocks:** if both an exception and records are registered for the same
`SObjectType`, the exception is thrown first, so the record path is never reached. A registered exception also
fires before any answer queued with `registerNext`, and leaves that queue in place until you clear it. All three
registrations are wiped by `kern.TST_Mock.clear()` and `kern.TST_Mock.clear(SObjectType)`.

### TST_Factory for Users

When a test needs to run as a particular kind of user, create one with a specific profile in a single call.
Remove `IsParallel=true` from the test class header when inserting `User` records, because Salesforce forbids
`User` DML in parallel tests.

**In your editor**, in a test class:

```apex
/** @description Tests behaviour as a Standard User. */
@IsTest
private static void shouldRunAsStandardUser()
{
	User testUser = kern.TST_Factory.insertUser('Standard User');

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

Create and activate a feature flag for testing flag-gated code paths.

**In your editor**, in a test method:

```apex
kern.TST_Factory.newFeatureFlag('MyFeatureFlag');

Boolean isEnabled = kern.UTIL_FeatureFlag.isEnabled('MyFeatureFlag');
Assert.isTrue(isEnabled, 'Flag should be enabled');
```

### Framework Metadata: Trigger and Validation Setup

To exercise a framework Trigger Action or Validation Rule in your tests, create the relevant `CustomMetadata`
records in Setup, or pull them into your project and deploy them. See
[Fast Start - Trigger Actions](Fast%20Start%20-%20Trigger%20Actions.md) and
[Fast Start - Custom Validations](Fast%20Start%20-%20Custom%20Validations.md), which show how to create them in
Setup and pull them into your project.

Once the metadata is in place, the action or validation fires through the normal trigger path, so your
test simply builds a record and asserts the resulting behaviour. This example uses the
`TRG_AccountSetDefaults` action from [Fast Start - Trigger Actions](Fast%20Start%20-%20Trigger%20Actions.md), which
fills in a blank Description. A change made before the record is saved (a before-insert change) is not copied back to the record in your test, so the test
reads the saved record again.

**In your editor**, in a test class:

```apex
@IsTest
private static void shouldFireTriggerAction()
{
	Account record = (Account)kern.TST_Builder.of(Account.SObjectType)
		.withOverride(Account.Description, null)
		.build();

	Account saved = (Account)kern.QRY_Builder.selectFrom(Account.SObjectType)
		.fields(new List<SObjectField>{ Account.Description })
		.condition(Account.Id).equals(record.Id)
		.getFirst();

	Assert.isNotNull(saved.Description, 'The trigger action should fill in a blank Description');
}
```

### Clean up

If you built this example only to try the framework, run this command when you have finished the guide. The Accounts
the Tier 1 blocks saved (the one with the random name, `Acme Corp` and the three bulk ones) stay; delete them in the
app, or leave them. The test's own records are rolled back when the test ends, so they never stay in your org.

**In the terminal**, delete the two classes:

```shell
sf project delete source -o YourOrgAlias -m "ApexClass:FastStart_TestData_DEMO_TEST" -m "ApexClass:FastStart_TestData_DEMO" --no-prompt
```

You should see `Status: Succeeded`, then a `Deleted Source` table listing the two classes. The command deletes the
files from your project too.

Something went wrong? See [Common Issues](#common-issues).

---

## Common Issues

Trouble with your computer rather than this guide (`sf` is not recognised, scripts are disabled, you are not logged
in, the wrong folder)? Those are answered once, in
[Set Up Your Computer](Set%20Up%20Your%20Computer.md#if-something-went-wrong).

### Tier 1: See It Work (~2 minutes)

#### `Illegal assignment from SObject to Account`

The block does not compile: the `.build()` result was not cast. Cast it:
`(Account)kern.TST_Builder.of(Account.SObjectType).build()`.

#### The insert fails because a required field is missing

The field is marked required but the builder doesn't know about it. Add `.withOverride(field, value)` for the missing
field.

#### A field your code reads is `null`

The builder only auto-populates required fields. Use `.withOverride()` to set the optional fields your test needs.

### Step 1: Create the Utility Class

#### The deploy says there is nothing to deploy

The deploy stops with `No source-backed components present in the package.` The command ran inside another project's
folder, so the CLI looked for the class there and found nothing. Open the terminal in your own project's top folder,
the one that holds `sfdx-project.json`, and run the command again.

### Step 2: Write and run the test

#### The deploy says there is nothing to deploy

The test class's deploy fails for the same reason as the utility class's: see the entry under
[Step 1](#step-1-create-the-utility-class-1).

### Tier 3: Production Patterns (~5 minutes)

#### A trigger action or validation rule doesn't fire in a test

The framework metadata isn't present in the org. Create the relevant `CustomMetadata` records for triggers and
validations in Setup, or pull them into your project and deploy them, as
[Framework Metadata: Trigger and Validation Setup](#framework-metadata-trigger-and-validation-setup) explains.

Still stuck? [Tell us](https://github.com/JVB-Consulting/kerndx/issues/new?template=bug_report.md&title=%5Bdocs%5D%20Test%20Data) which step and what you saw.

## What You Now Know

After completing this guide, you understand the **three test data tools** in KernDX:

| Tool              | When to Use                              | What You Get                                                                     |
|-------------------|------------------------------------------|----------------------------------------------------------------------------------|
| **`TST_Builder`** | All SObject construction in tests        | Auto-populated fields, bulk, cycling, parent-child, real DML                     |
| **`TST_Mock`**    | DML-free query interception in `@IsTest` | Mock records auto-registered for `QRY_Builder` without touching the database     |
| **`TST_Factory`** | Users and feature flags                  | Test users and feature flags ready for your tests                                |

**Key patterns:**

- **Override only what matters.** Let `TST_Builder` handle required fields so tests stay focused on behaviour.
- **`.withoutInsertion()` for logic tests.** Skip DML when testing pure logic (faster tests, no governor cost).
- **`.withCycle()` for multiple scenarios.** Test different values without writing separate test methods.
- **`.withChildren()` for relationships.** Foreign-key assignment is handled for you.
- **`TST_Mock` for query mocking.** No DML, no database: the mock data flows through `QRY_Builder`.
- **Framework metadata from Setup.** To exercise trigger or validation behaviour in your tests, create the
  relevant `CustomMetadata` records in Setup, or pull them into your project and deploy them.

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
