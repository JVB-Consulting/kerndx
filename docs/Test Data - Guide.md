---
navOrder: 68
navLabel: "Test Data (records for tests)"
searchTerms: {"users-and-permission-sets":["run as another user", "System.runAs"]}
movedAnchors: {"why-choose-this-over-hand-written-records": "/#test-data", "how-it-compares-to-hand-written-records": "/#test-data", "capability-matrix-for-analysts": "/#test-data"}
---

# Test Data - Guide

**Who this page is for:** developers who build the records their Apex unit tests run against (single records,
relationships, mock Ids and bulk data), and the architects who give a whole team one short, consistent way to set up
tests.

New to it? Try the [Test Data Fast Start](Fast%20Start%20-%20Test%20Data.md) first: a full build-and-test cycle, plus
`TST_Mock` for query testing with no saved records. Deciding whether to use KernDX? See [Why KernDX](/#test-data).

## Copy this first

```apex
// Build and insert a single Account; required fields are auto-populated
Account account = (Account)kern.TST_Builder.of(Account.SObjectType)
		.withOverride(Account.Industry, 'Technology')
		.build();
```

**What this does:** saves one account in your test with Industry set to Technology. You name only the fields your
test checks, and the builder fills every other required field (such as Name) with a valid value. To keep the record
in memory without saving it, add `.withoutInsertion()` before `.build()`.

**Read next:** [Many records at once](#bulk-creation), [Records that are not saved](#insertion-modes),
[A parent with its children](#relationships), [Shared setup for your team](#the-factory-pattern).

---

## Quick Navigation

| I need to...                                                                | Go to...                                                                                     |
|-----------------------------------------------------------------------------|----------------------------------------------------------------------------------------------|
| Set several fields at once, or a field whose name is only known at run time | [Token Maps vs String Maps](#token-maps-vs-string-maps)                                      |
| Fill in a field that is not required                                        | [Defaulting Optional Fields](#defaulting-optional-fields)                                    |
| Leave a required field empty                                                | [Marking Fields Optional](#marking-fields-optional)                                          |
| Set a record type                                                           | [Record Types](#record-types)                                                                |
| Build many records with one save                                            | [Bulk Creation](#bulk-creation)                                                              |
| Build records without saving them, with or without an Id                    | [Insertion Modes](#insertion-modes)                                                          |
| Build a parent with its children                                            | [Relationships](#relationships)                                                              |
| Create a test user, or give users a permission set                          | [Users and Permission Sets](#users-and-permission-sets)                                      |
| Turn a feature flag on for a test                                           | [Feature Flags](#feature-flags)                                                              |
| Test a trigger action or a validation rule                                  | [Framework Metadata: Triggers and Validations](#framework-metadata-triggers-and-validations) |
| Test a masking rule, or other behaviour set up by custom metadata records   | [Custom Metadata Records](#custom-metadata-records)                                          |
| Check what a test logged                                                    | [Logger Configuration](#logger-configuration)                                                |
| Fill a sandbox or scratch org with records to click through                 | [How do I seed a sandbox or scratch org?](#how-do-i-seed-a-sandbox-or-scratch-org)           |
| Change the values the builder fills in                                      | [Extending the Defaults](#extending-the-defaults)                                            |
| Test an aggregate query, or step outside the builder                        | [How to opt out](#how-to-opt-out)                                                            |
| Look up every builder method                                                | [Layer 1: TST_Builder](#layer-1-tst_builder)                                                 |
| Look up every factory method                                                | [Layer 2: TST_Factory](#layer-2-tst_factory)                                                 |
| Avoid the common mistakes                                                   | [Anti-Patterns](#anti-patterns)                                                              |
| See why KernDX is worth using                                               | [Why KernDX: the test data example](/#test-data)                                             |

---

## Quick Start

Pick the class that fits the records your test needs. No custom class is required for any of them.

- **Records of any type, saved or kept in memory:** [`TST_Builder`](reference/apex/TST_Builder.md) directly, as in
  the sample below.
- **A user, a permission set assignment or a feature flag, set up the same way in every test:**
  [`TST_Factory`](reference/apex/TST_Factory.md), see [The Factory Pattern](#the-factory-pattern).
- **Records that a `kern.QRY_Builder` query returns, with nothing saved:** `kern.TST_Mock`, see the
  [Test Data Fast Start](Fast%20Start%20-%20Test%20Data.md).

```apex
// Build and insert a single Account; required fields are auto-populated
Account account = (Account)kern.TST_Builder.of(Account.SObjectType)
		.withOverride(Account.Industry, 'Technology')
		.build();

System.debug('Id: ' + account.Id + ', Industry: ' + account.Industry);
```

`build()` returns one record (saved to the database by default). `buildList()` returns a
`List<SObject>` and respects `withCount(n)`. Cast the result to your concrete type.

> **Namespaces in code samples:** `kern.` on a class and `kern__` on an object, field, or metadata type mark the managed package's namespace.
> On the managed package, framework references need those prefixes even where a sample omits them; repackaged under your own namespace, replace `kern`/`kern__`
> with your prefix; on an unmanaged deploy, drop them. See [How to read the code samples](Installation.md#how-to-read-the-code-samples).

---

## What problem does this solve?

Every Apex unit test needs example records to run against, and setting them up by hand is slow and
fragile. You fill in fields the test does not care about, that setup breaks every time a field is
renamed, and saving many records inside a loop quickly hits Salesforce's safety limits.

This layer builds those records for you. You name only the fields your test actually checks, and it
fills in the rest, then either saves the records or keeps them in memory.

Use it whenever a test needs records. A plain `new Account(...)` is fine only for a record the test never saves, such
as an argument it hands straight to a method.

## Mental model

Think of it as ordering a coffee. You say what you actually care about (a flat white, oat milk),
and the barista fills in everything else (cup, lid, water, machine settings) to defaults so the
order is complete.

The builder works the same way: you name the few fields your test asserts on, and it supplies valid
values for the rest so the record saves.

## Use this when

- a test needs records and you only care about a handful of fields on them
- you need many records at once, saved in a single statement, to stay within Salesforce's limits
- you want records in memory (with or without an Id) so the test never touches the database
- you need a parent and its children built and saved together as one all-or-nothing unit
- the whole team should set up the same kind of record (a user on a profile, an active flag) the same way
- you want a sandbox or scratch org filled with realistic records to click through, built the same way as your test data

## Don't use this when

- you need an `AggregateResult` object itself: it has no public constructor and cannot be built. For an aggregate query you run through `kern.QRY_Builder`, register the rows it returns instead (see [Mocking an aggregate query](Selectors%20-%20Guide.md#mocking-an-aggregate-query))

---

## What is it?

The layer has two classes that work together. You configure each with short chained calls, then one call builds the
record and returns it.

1. **[`TST_Builder`](reference/apex/TST_Builder.md)** is the primary tool. It works for any SObject and handles
   overrides, bulk creation, cycling values across records, parent-child relationships, and three ways of saving (or not
   saving) the record.
2. **[`TST_Factory`](reference/apex/TST_Factory.md)** is a convenience layer on top. It offers ready-made builders for
   records nearly every test needs (users, permission set assignments, feature flags), plus builders for API call
   records, API settings and content versions. Trigger settings and validation rules are not built by the factory: you
   deploy them as XML.

From your org's Apex, call them with the `kern.` namespace prefix, for example `kern.TST_Builder` and
`kern.TST_Factory`: they are `global` classes in a managed package. The framework source is also available if you
build and manage the package yourself.

> **What this layer does, and what it does not:**
>
> - It only builds records (and optionally saves them) for tests. It does not run production business logic, and most
>   of it is meant to be called from test code (`@IsTest`).
> - `TST_Builder` and the `TST_Factory` methods run from anonymous Apex and from an `@IsTest` class in your org. That
>   is also how you fill a sandbox with records to click through (see
>   [How do I seed a sandbox or scratch org?](#how-do-i-seed-a-sandbox-or-scratch-org)).
> - Framework configuration records for your tests (trigger settings, validation rules, masking) are deployed as
>   `CustomMetadata` records via XML (see [Framework Metadata](#framework-metadata-triggers-and-validations)).

---

## Building Records

These examples use `Account` and `Contact`, but every method works for any SObject, standard or
custom.

### A Single Record

```apex
// Inserted by default; required fields auto-populated
Account account = (Account)kern.TST_Builder.of(Account.SObjectType).build();

System.debug('Name: ' + account.Name); // randomly generated
System.debug('Id: ' + account.Id); // populated because the record was inserted
```

### Overriding Fields

Override only the fields the test cares about, with `withOverride`. Everything else the test doesn't name is either
auto-populated (if required) or left null.

```apex
Account account = (Account)kern.TST_Builder.of(Account.SObjectType)
		.withOverride(Account.Name, 'Acme Corp')
		.withOverride(Account.Industry, 'Technology')
		.build();

Assert.areEqual('Acme Corp', account.Name, 'Name override should apply');
```

### Token Maps vs String Maps

When you want to set several fields at once, pass a map to `withOverrides`. Prefer the field-token form
(`SObjectField`) so the compiler catches a misspelled or renamed field before the test runs. Use the
`String` form only when the field name is not known until the test actually runs.

```apex
// Type-safe: field-name typos are caught at compile time
Account tokenForm = (Account)kern.TST_Builder.of(Account.SObjectType)
		.withOverrides(new Map<SObjectField, Object>
		{
				Account.Name => 'Acme Corp',
				Account.Industry => 'Technology',
				Account.AnnualRevenue => 5000000
		})
		.build();

// String form: useful when the field name is dynamic
Account stringForm = (Account)kern.TST_Builder.of(Account.SObjectType)
		.withOverrides(new Map<String, Object>
		{
				'Name' => 'Beta Corp',
				'Industry' => 'Finance'
		})
		.build();
```

### Building by API Name

When the SObject type itself is dynamic, start from the API name. An invalid name throws an
`IllegalArgumentException` with a descriptive message.

```apex
List<SObject> records = kern.TST_Builder.of('Foobar__c')
		.withCount(5)
		.buildList();
```

### Defaulting Optional Fields

By default the builder fills in only the fields Salesforce requires. Sometimes your test reads a
field that is not required, and you want it populated too (for example, to exercise code that reads
it). List those fields with `withDefaultedField` or `withDefaultedFields`.

```apex
Account account = (Account)kern.TST_Builder.of(Account.SObjectType)
		.withDefaultedField(Account.Description)
		.withDefaultedField(Account.Industry)
		.withoutInsertion()
		.build();

Assert.isNotNull(account.Description, 'Description should be auto-populated');
```

### Marking Fields Optional

Sometimes you want a normally-required field left empty, perhaps to test how your code handles a
missing value. Tell the builder to leave that field alone, and it comes back null.

```apex
Account account = (Account)kern.TST_Builder.of(Account.SObjectType)
		.withOptionalField(Account.Name)
		.withoutInsertion()
		.build();

Assert.isNull(account.Name, 'Name should be left unpopulated');
```

> `withOptionalField` only stops the builder from filling the field in. If the field is genuinely
> required to save the record, inserting it will still fail. So use this together with
> `withoutInsertion()`, or supply the value some other way.

### Record Types

When a record needs a specific record type, set it by its developer name with
`withRecordType(developerName)`. An unknown developer name
throws an `IllegalArgumentException`. A blank name is ignored.

```apex
Account account = (Account)kern.TST_Builder.of(Account.SObjectType)
		.withRecordType('Enterprise_Account')
		.withOverride(Account.Name, 'Enterprise Corp')
		.build();
```

> In your org a packaged record type may not be assigned to the running profile. If a build
> fails with `INVALID_CROSS_REFERENCE_KEY` on `RecordTypeId`, confirm the record type is available
> to the running user, or pass a blank developer name to fall back to the master record type.

---

## Bulk Creation

### withCount and buildList

Tests often need many records, and saving them one at a time quickly hits Salesforce's
per-transaction limits. `withCount(n)` followed by `buildList()` creates `n` records with a
**single** DML statement, which keeps you safely within those limits. (`build()` always returns
exactly one record, no matter what `withCount` says.)

```apex
List<Account> accounts = (List<Account>)kern.TST_Builder.of(Account.SObjectType)
		.withOverride(Account.Industry, 'Technology')
		.withCount(200)
		.buildList();

Assert.areEqual(200, accounts.size(), 'Should build 200 accounts in one DML statement');
```

### Cycling Values Across Records

`withCycle(field, values)` rotates your list of values across the records that `buildList()` produces, so one batch
covers several variations of one field (say a few different industries) without a separate test method for each.

- If there are more records than values, the values repeat from the start.
- The value list must not be null or empty.

```apex
List<SObject> records = kern.TST_Builder.of(Account.SObjectType)
		.withCycle(Account.Industry, new List<Object> {'Technology', 'Finance', 'Healthcare'})
		.withCount(6)
		.buildList();
// Industries: Technology, Finance, Healthcare, Technology, Finance, Healthcare
```

---

## Insertion Modes

Pick one of three modes, depending on whether the record needs to reach the database and whether your code needs an
Id on it ([Choosing a Mode](#choosing-a-mode) compares them). Not every test needs to save its records: some only read
fields, so saving them is wasted time and governor-limit cost.

### Insert (Default)

Without `withoutInsertion()`, records are inserted and come back with real Ids.

```apex
Account account = (Account)kern.TST_Builder.of(Account.SObjectType).build();
Assert.isNotNull(account.Id, 'Inserted record has a real Id');
```

### In-Memory, No Id

`withoutInsertion()` builds the record in memory with **no DML and no Id**. Use it when the code
under test only works with the record's fields and never needs an Id or a database round-trip. This
is the fastest option and the easiest on governor limits.

```apex
Account account = (Account)kern.TST_Builder.of(Account.SObjectType)
		.withOverride(Account.Name, 'In-Memory Co')
		.withoutInsertion()
		.build();

Assert.isNull(account.Id, 'No insertion means no Id');
```

### In-Memory with Mock Ids

Some code needs an Id to work (it checks `record.Id != null`, uses the Id as a map key, or registers
the record for query mocking) but you still do not want to touch the database. `withoutInsertion(true)`
builds in memory but stamps a **valid 18-character mock Id** so that code is satisfied.

```apex
Account account = (Account)kern.TST_Builder.of(Account.SObjectType)
		.withOverride(Account.Name, 'Mock Corp')
		.withoutInsertion(true)
		.build();

Assert.isNotNull(account.Id, 'Mock Id is generated without DML');
```

### Choosing a Mode

| Mode                     | DML | Id     | Use when                                                             |
|--------------------------|-----|--------|----------------------------------------------------------------------|
| (default)                | ✅   | Real   | The test exercises real persistence, queries, triggers, or sharing.  |
| `withoutInsertion()`     | ❌   | `null` | The code under test only reads fields (no Id, no database needed).   |
| `withoutInsertion(true)` | ❌   | Mock   | The code checks `Id != null`, keys by Id, or registers a query mock. |

> **Custom metadata and read-only fields:** custom metadata types (`*__mdt`) cannot be inserted via
> DML, so the framework builds them in memory. Read-only and system fields are applied through a
> serialize/deserialize step so they appear populated on an in-memory record even though Apex would
> normally reject setting them directly.

---

## Relationships

The builder constructs a whole parent-child graph for you, so you never wire the foreign keys by hand.

| You build it    | What you get                                                                                               |
|-----------------|------------------------------------------------------------------------------------------------------------|
| Saved (default) | Parent and children commit together as one all-or-nothing unit (a Unit of Work): they all save, or none do |
| In memory       | The child relationship is filled in, so it reads back just like a subquery result                          |

### Adding Child Records

The simplest form takes a child type and a count. The framework works out the relationship name for
you from the schema.

```apex
Account account = (Account)kern.TST_Builder.of(Account.SObjectType)
		.withOverride(Account.Name, 'ACME Corp')
		.withChildren(Contact.SObjectType, 3)
		.build();

Assert.areEqual(3, account.Contacts.size(), 'Three child contacts should be attached');
```

Add child field overrides with the map overloads (token or string form):

```apex
Account account = (Account)kern.TST_Builder.of(Account.SObjectType)
		.withOverride(Account.Name, 'ACME Corp')
		.withChildren(Contact.SObjectType, 3, new Map<SObjectField, Object>
		{
				Contact.LastName => 'Mock Contact'
		})
		.build();
```

### Child Builders

For richer child configuration, pass a fully-configured child `Builder`. The relationship name is
auto-detected from the child's SObject type.

```apex
Account account = (Account)kern.TST_Builder.of(Account.SObjectType)
		.withChildren(
				kern.TST_Builder.of(Opportunity.SObjectType)
						.withCount(2)
						.withOverride(Opportunity.Name, 'Big Deal')
						.withOverride(Opportunity.StageName, 'Prospecting')
		)
		.build();
```

### Explicit Relationship Names

When parent and child share **more than one** relationship (for example, two lookup fields from the
same child to the same parent), auto-detection cannot choose for you and throws an
`IllegalArgumentException` listing the candidates. Pass the relationship name explicitly:

```apex
Foobar__c foobar = (Foobar__c)kern.TST_Builder.of(Foobar__c.SObjectType)
		.withChildren('PrimaryContacts__r',
				kern.TST_Builder.of(Contact.SObjectType).withCount(2))
		.withChildren('SecondaryContacts__r',
				kern.TST_Builder.of(Contact.SObjectType).withCount(1))
		.build();
```

### Mock Ids Across a Graph

When you call `withoutInsertion(true)` on the parent, the builder generates mock Ids for the
**entire graph** (parents and children) and connects each child's foreign key to its parent's mock
Id. The result is a fully-linked in-memory graph with no DML, ready to register for query mocking.

```apex
Account account = (Account)kern.TST_Builder.of(Account.SObjectType)
		.withOverride(Account.Name, 'Mock Account')
		.withChildren(Contact.SObjectType, 3, new Map<SObjectField, Object>
		{
				Contact.LastName => 'Mock Contact'
		})
		.withoutInsertion(true)
		.build();

Assert.isNotNull(account.Id, 'Parent has a mock Id');
Assert.isNotNull(account.Contacts[0].Id, 'Children have mock Ids');
Assert.areEqual(account.Id, account.Contacts[0].AccountId, 'Child foreign key references the parent');
```

---

## The Factory Pattern

### Why use a factory?

Some records need the same multi-field setup in test after test: a `User` on a specific profile, a
permission set assignment, an active feature flag, or the framework's own configuration metadata.
[`TST_Factory`](reference/apex/TST_Factory.md) wraps `TST_Builder` with pre-configured builders for
these cases so the setup lives in one place instead of being copied across every test class.

### Users and Permission Sets

Most tests need a second user to run as. `insertUser` gives you a saved one on the profile you name,
ready for `System.runAs`.

To run as another user in a test, put the test code inside a `System.runAs(user)` block, as the sample below shows.
The code inside the block runs as that user, so record sharing follows that user. A KernDX read or save in user mode
(the mode that checks the running user's access) also checks that user's object and field permissions.

```apex
@IsTest
private static void shouldRunAsStandardUser()
{
	User testUser = kern.TST_Factory.insertUser('Standard User');

	System.runAs(testUser)
	{
		Account account = (Account)kern.TST_Builder.of(Account.SObjectType)
				.withOverride(Account.Industry, 'Technology')
				.withoutInsertion()
				.build();

		Assert.areEqual('Technology', account.Industry, 'Industry should be set');
	}
}
```

Two platform rules sit behind this:

- **Setup records and ordinary records are saved apart (the factory handles this).** Salesforce will not save "setup"
  records (users, permission set assignments) and ordinary records (accounts, your own objects) in the same stretch of
  a transaction.
  - If you try, the save fails with the platform's mixed DML error, which reads like this:
    `MIXED_DML_OPERATION, DML operation on setup object is not permitted after you have updated a non-setup object (or vice versa)`.
  - In a test, a save inside a `System.runAs` block counts as a separate stretch, so the error does not happen there.
    That is how the factory avoids it.
  - The factory saves its own setup records apart from everything else, so your test can create ordinary records
    before or after any factory call without a wrapper of its own.
- **No user saves in parallel tests (yours to keep).** Salesforce forbids saving `User` records in parallel tests, so
  remove `IsParallel=true` from the test class header whenever the test saves a user.

A saved user needs a free seat for its profile's licence. If your org is at its limit for a licence,
choose a profile whose licence has seats to spare; otherwise the platform reports the licence limit
when the factory saves the user.

`insertUser(profileName, companyName)` also sets the company name, a simple way to find the user again
from another test method with `new kern.SEL_User().findByCompanyName(companyName)`. `insertUsers(profileName, count)`
saves a batch. When your org's User rules need more than the factory sets, or the user needs a role,
build the user with `newUser`, set the fields yourself, and let the factory save it:

```apex
UserRole managerRole = (UserRole)kern.QRY_Builder.selectFrom(UserRole.SObjectType)
		.condition(UserRole.DeveloperName).equals('Manager')
		.toList()
		.iterator()
		.next();
User manager = kern.TST_Factory.newUser('Standard User');
manager.UserRoleId = managerRole.Id;
kern.TST_Factory.insertUsers(new List<User> {manager});
```

`newUser` and `newUsers` return **unsaved** users for the cases where you want to save them yourself.

Assign a permission set (or permission set group) to saved users with
`createPermissionSetAssignments`. It throws an `AssertException` if the named permission set cannot
be resolved, and it keeps its writes apart from your ordinary records in the same way. It saves all
of one call's assignments together, so if one assignment fails, none of them is saved.

```apex
List<User> users = kern.TST_Factory.insertUsers('Standard User', 2);
kern.TST_Factory.createPermissionSetAssignments(users, 'My_Permission_Set');
```

When you need a saved admin user that test methods reach through `System.runAs`,
`newUserWithPermissionSet` builds the user, saves it, and assigns the permission set in one call.
That makes it a good fit inside `@TestSetup`, where you can seed ordinary records right after it.

```apex
@TestSetup
private static void setupAdmin()
{
	kern.TST_Factory.newUserWithPermissionSet(
			'System Administrator',
			'MyClass_TEST-admin',
			'My_Admin_Permission_Set'
	);
}
```

Setup records the factory does not create, such as groups and group members, still need the
platform's own guard. Wrap those inserts in a `System.runAs` block for the running user:

```apex
System.runAs(new User(Id = UserInfo.getUserId()))
{
	insert new Group(Name = 'Reviewers');
}
```

### Feature Flags

When a test needs to run code that is gated behind a feature flag, turn the flag on for that test.
`newFeatureFlag(flagName)` registers an active feature flag for the current transaction, so
`kern.UTIL_FeatureFlag.isEnabled(flagName)` returns `true` afterward. No DML is involved: the flag
is placed straight into the framework's in-memory cache.

```apex
@IsTest
private static void shouldRunFlagGatedPath()
{
	kern.TST_Factory.newFeatureFlag('MyFeatureFlag');

	Assert.isTrue(
			kern.UTIL_FeatureFlag.isEnabled('MyFeatureFlag'),
			'Flag should report enabled after registration'
	);
}
```

### Framework Metadata: Triggers and Validations

Deploy the framework configuration your tests rely on (trigger settings, trigger actions, validation rules, and
validation rule groups: the `TriggerSetting__mdt`, `TriggerAction__mdt`, `ValidationRule__mdt` and related records) as
`CustomMetadata` records via XML. The [Trigger Actions Fast Start](Fast%20Start%20-%20Trigger%20Actions.md) and
[Custom Validations Fast Start](Fast%20Start%20-%20Custom%20Validations.md) show that pattern.

Those records are in place for every test that runs against the org, so a test simply builds a record and asserts on
the resulting trigger or validation behaviour. This example uses the `TRG_AccountSetDefaults` action from the Trigger
Actions Fast Start, which fills in a blank Description when an Account is created.

A before-insert change is not copied back to the record in your test, so the test reads the saved record again:

```apex
@IsTest
private static void shouldFireTriggerAction()
{
	Account account = (Account)kern.TST_Builder.of(Account.SObjectType)
			.withOverride(Account.Description, null)
			.build();

	Account saved = (Account)kern.QRY_Builder.selectFrom(Account.SObjectType)
			.fields(new List<SObjectField>{ Account.Description })
			.condition(Account.Id).equals(account.Id)
			.getFirst();

	Assert.isNotNull(saved.Description, 'The trigger action should fill in a blank Description');
}
```

### Custom Metadata Records

Some framework configuration depends on custom metadata records (masking targets, for example). You
set those up by deploying the relevant `CustomMetadata` records as XML alongside your test classes.
Custom metadata types can't be inserted via DML, so the records ship with your source and are active
for every test run.

Place the records under `force-app/main/default/customMetadata/`, one file per record:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<CustomMetadata xmlns="http://soap.sforce.com/2006/04/metadata" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema">
    <label>Mask Contact Email</label>
    <protected>false</protected>
    <values>
        <field>kern__CallerClass__c</field>
        <value xsi:nil="true"/>
    </values>
    <values>
        <field>kern__Field__c</field>
        <value xsi:nil="true"/>
    </values>
    <values>
        <field>kern__IsActive__c</field>
        <value xsi:type="xsd:boolean">true</value>
    </values>
    <values>
        <field>kern__Rule__c</field>
        <value xsi:type="xsd:string">kern__MaskEmail</value>
    </values>
    <values>
        <field>kern__SObjectType__c</field>
        <value xsi:type="xsd:string">Contact</value>
    </values>
</CustomMetadata>
```

A blank `kern__Field__c` applies the rule to every text field on `Contact`. Masking runs inside the
framework's trigger, so `Contact` also needs the one-line trigger that hands control to the
framework, and a `kern__TriggerSetting__mdt` record with `kern__ApplyMasking__c` checked. The
[Data Masking - Guide](Data%20Masking%20-%20Guide.md) explains both steps.

Once the records are deployed, a test builds a record normally and asserts on the masked behaviour:

```apex
@IsTest
private static void shouldMaskContactEmail()
{
	Contact contact = (Contact)kern.TST_Builder.of(Contact.SObjectType)
			.withOverride(Contact.Email, 'real.person@example.com')
			.build();

	Assert.areNotEqual(
			'real.person@example.com',
			contact.Email,
			'Email should be masked according to the deployed masking target');
}
```

### Logger Configuration

When a test needs to check what was logged, set the global `kern.LOG_Builder.ignoreTestMode` flag to `true`. By
default the logging framework discards log records during tests, to avoid cluttering them. It still runs inside tests
using your org's configuration, so the logs you generate in a test go through the same code path as in production.

```apex
kern.LOG_Builder.ignoreTestMode = true;
```

> The flag is reset between test methods along with all other static state, so enabling it in one
> test never leaks into another.

---

## How do I seed a sandbox or scratch org?

Run the builder and the factory from a script: they fill a fresh sandbox or scratch org with records to click through,
demo, or test by hand. There is nothing to install or switch on. Both are ordinary production classes, so a script
run from your command line saves records exactly as a test would, except that they stay.

```apex
// Three accounts, each with two contacts, saved together as one all-or-nothing unit
List<Account> accounts = (List<Account>)kern.TST_Builder.of(Account.SObjectType)
		.withCount(3)
		.withCycle(Account.Name, new List<Object> {'Northwind Traders', 'Contoso', 'Fabrikam'})
		.withOverride(Account.Industry, 'Technology')
		.withChildren(Contact.SObjectType, 2, new Map<SObjectField, Object> {Contact.LastName => 'Seeded'})
		.buildList();

// A Standard User to try the org as (Setup, Users, Login); the company name is how you find the user again later
User reviewer = kern.TST_Factory.insertUser('Standard User', 'seed-reviewer');
```

Save it as `seed.apex` and run it against the org:

```shell
sf apex run --file seed.apex -o YourOrgAlias
```

Afterwards the org holds:

- three accounts named Northwind Traders, Contoso and Fabrikam;
- two contacts under each, with the last name Seeded;
- an active Standard User whose company name is `seed-reviewer`.

Every field Salesforce requires carries a valid generated value; fields it does not require are left empty. The seeded
user needs a free seat for its profile's licence, and a profile with that exact name; see
[Users and Permission Sets](#users-and-permission-sets).

**Before you run it, know how a seeding run differs from a test:**

- **The data stays.** A test rolls back everything it saved; a script does not. Whatever the script
  builds is in the org until you remove it.
- **Each build is all or nothing.** One `build()` or `buildList()` call saves its whole graph as one
  unit. If the platform refuses a row (a validation rule, a required field your org adds), the call
  throws with the platform's message and nothing from that call is saved.
- **The builder saves with full access.** It saves in system mode, which skips the object and field
  permission checks that apply to the user running the script, so it can fill fields that user could
  not edit on screen. Record sharing is unchanged. Check the result as the people who will use the
  org, not as yourself.
- **Defaults are random, and only required fields are filled.** Every required field you do not
  override gets a valid random value: names, emails, dates, picklist entries.
- **Fields Salesforce does not require stay empty.** List the ones people will see on screen with
  `withDefaultedField` (see [Defaulting Optional Fields](#defaulting-optional-fields)), and override the ones whose
  value matters, as the script does with the account names, the industry and the contacts' last names.
- **Running it twice creates a second set.** A second run inserts three more accounts and another
  user, and a duplicate rule on your objects may refuse the second copy. Usernames never collide,
  though: each run draws a fresh random base for the user's email and username.
- **Users cannot be deleted.** Salesforce never deletes a user, so when you are done, deactivate the
  seeded user instead. Find it by the company name you gave it:

```apex
User reviewer = new kern.SEL_User().findByCompanyName('seed-reviewer');
kern.DML_Builder.newTransaction().doUpdate(new User(Id = reviewer.Id, IsActive = false)).execute();
```

Send only the field you change, as above: the update runs with your own field permissions, and a
user record read back from the database carries fields nobody may edit, which the save would refuse.
If no user has that company name the lookup returns nothing, so check the record is not null before
you use its Id.

The seeded accounts and contacts delete like any other records, but do the deleting in its own
script. A run that updates a user and then deletes ordinary records is refused with a
`MIXED_DML_OPERATION` error, and nothing the run did is kept.

---

## Extending the Defaults

### Custom Default Value Provider

The values the builder fills in come from a default value provider. If you need to change how those
defaults are generated (say, to satisfy an unusual required-field setup), extend
`kern.UTIL_SObjectBuilderDefaultProvider` and assign an instance to
`kern.TST_Builder.defaultValueProvider`. `UTIL_SObjectBuilderDefaultProvider` is a `global virtual` class rather than an interface, so
the framework can add methods in future releases without breaking your subclass.

Extend that class, not the bare `kern.TST_Builder.DefaultValueProvider` it is built on.
`kern.UTIL_SObjectBuilderDefaultProvider` is the one carrying every default the builder normally
supplies, so your subclass changes only what you override and inherits the rest. A subclass of the
bare base starts from nothing.

Override whichever of these hooks you need:

| Hook                                                | What it changes                                                                              |
|-----------------------------------------------------|----------------------------------------------------------------------------------------------|
| `defineSObjectRequiredFields(SObjectType)`          | Which fields the builder treats as required and fills in for you                             |
| `defineSObjectOptionalFields(SObjectType)`          | Which fields the builder leaves alone                                                        |
| `get<Type>DefaultValue(DescribeFieldResult, Integer)` | The value generated for one field type, for example `getEmailDefaultValue` or `getTextDefaultValue` |

```apex
public inherited sharing class MyDefaultProvider extends kern.UTIL_SObjectBuilderDefaultProvider
{
	public override Set<SObjectField> defineSObjectRequiredFields(SObjectType sObjectType)
	{
		if(sObjectType == Account.SObjectType)
		{
			return new Set<SObjectField>{ Account.Industry };
		}
		return super.defineSObjectRequiredFields(sObjectType);
	}

	public override String getEmailDefaultValue(DescribeFieldResult fieldDescribe, Integer recordIndex)
	{
		return 'qa+' + recordIndex + '@example.com';
	}
}

// Apply it for the transaction
kern.TST_Builder.defaultValueProvider = new MyDefaultProvider();
```

> **If you override `defineSObjectOptionalFields`, end it with the `super` call.** Return
> `super.defineSObjectOptionalFields(sObjectType)` for every type you are not handling yourself.
>
> The inherited behaviour marks each `UserPermissions` field on `User` as optional, and that is what keeps
> the builder from tripping over the permission fields your org's licences control when it creates a
> `User`. Replace the method outright and building a `User` starts to fail.

```apex
public override Set<SObjectField> defineSObjectOptionalFields(SObjectType sObjectType)
{
	if(sObjectType == Account.SObjectType)
	{
		return new Set<SObjectField>{ Account.Website };
	}
	return super.defineSObjectOptionalFields(sObjectType);
}
```

> A custom provider is set per transaction, so the assignment does not leak into other tests (see
> [Let Salesforce Reset Static State](#let-salesforce-reset-static-state)).

### Auto-Default Marker

In an override map, the `kern.TST_Builder.autoDefaultFieldValueProvider` marker asks the builder to
generate a default for a field even when you're supplying other fields explicitly:

```apex
Account account = (Account)kern.TST_Builder.of(Account.SObjectType)
		.withOverrides(new Map<String, Object>
		{
				'Name' => 'Test Account',
				'Description' => kern.TST_Builder.autoDefaultFieldValueProvider
		})
		.withoutInsertion()
		.build();
```

---

## How to opt out

The test-data layer is opt-in: when part of it does not fit, step outside that part and keep the rest.

| You need                                                                  | Use                                                                                                | See                                                       |
|---------------------------------------------------------------------------|----------------------------------------------------------------------------------------------------|-----------------------------------------------------------|
| **A plain record with no auto-population**                                | `new Account(Name = 'X')`, saved with `kern.DML_Builder.newTransaction().doInsert(record).execute()`, so the save still goes through KernDX. | —                                                         |
| **One field that the builder shouldn't default**                          | `withOptionalField(field)` to skip a required field, or build the record by hand.                  | [Marking Fields Optional](#marking-fields-optional)       |
| **DML-free query interception (records flow through `kern.QRY_Builder`)** | `kern.TST_Mock` (same chained build calls as `TST_Builder`, auto-registers for query mocking).     | [Test Data Fast Start](Fast%20Start%20-%20Test%20Data.md) |
| **Aggregate-query test data**                                             | `kern.TST_Mock.registerAggregateRows` hands the query the rows it returns, so nothing is inserted. | [Mocking an aggregate query](Selectors%20-%20Guide.md#mocking-an-aggregate-query) |
| **Custom default values for a field type**                                | Extend `kern.UTIL_SObjectBuilderDefaultProvider` and assign `kern.TST_Builder.defaultValueProvider`. | [Extending the Defaults](#extending-the-defaults)         |

---

## How does it work?

Your test code calls either the convenience layer (`TST_Factory`) or the builder directly (`TST_Builder`). The builder
fills in field defaults through a part you can replace if you need to (`DefaultValueProvider`).

```text
┌─────────────────────────────────────────────────────────────────────────────┐
│                          TEST DATA LAYER ARCHITECTURE                         │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                               │
│   @IsTest CODE (and anonymous Apex for TST_Builder)                           │
│   ==================================================                          │
│           │                                                                   │
│           ▼                                                                   │
│   ┌───────────────────────────────────────────────────────────────────────┐  │
│   │  TST_Factory (Convenience — pre-configured builders for common records)│  │
│   │  - newUser, createPermissionSetAssignments, newFeatureFlag             │  │
│   │  - newContentVersion, newApiCall, newOutboundApiSetting                │  │
│   └───────────────────────────────┬───────────────────────────────────────┘  │
│                                   │ delegates to                              │
│                                   ▼                                           │
│   ┌───────────────────────────────────────────────────────────────────────┐  │
│   │  TST_Builder (Primary — fluent builder for any SObject)                │  │
│   │  - of(type).withOverride(...).withCount(n).build()/buildList()         │  │
│   │  - auto-populated required fields, cycling, relationships, mock Ids    │  │
│   └───────────────────────────────┬───────────────────────────────────────┘  │
│                                   │ pluggable                                 │
│                                   ▼                                           │
│   ┌───────────────────────────────────────────────────────────────────────┐  │
│   │  DefaultValueProvider (extension point for custom field defaults)      │  │
│   └───────────────────────────────────────────────────────────────────────┘  │
│                                                                               │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Layer 1: [TST_Builder](reference/apex/TST_Builder.md)

`TST_Builder` builds a valid record without you listing every required field: it fills in the fields Salesforce
requires, and it saves the record unless you ask it not to. Use it for building records in any test. One caveat in
your org: if you have added custom validation rules, a record may need extra `withOverride()` calls to satisfy them.

You start a build, chain any configure calls (each returns the `Builder`), then finish it with the call that builds the
records and returns them:

| Step      | Method                                                                            | What it does                                              |
|-----------|-----------------------------------------------------------------------------------|-----------------------------------------------------------|
| Start     | `kern.TST_Builder.of(SObjectType)`                                                | Start a build for a typed SObject                         |
| Start     | `kern.TST_Builder.of(String)`                                                     | Start a build by SObject API name (resolved via describe) |
| Configure | `withOverride(field, value)` / `withOverride(fieldName, value)`                   | Set one field                                             |
| Configure | `withOverrides(Map<SObjectField, Object>)` / `withOverrides(Map<String, Object>)` | Set many                                                  |
| Configure | `withCycle(field, values)` / `withCycle(fieldName, values)`                       | Rotate values across `buildList()`                        |
| Configure | `withDefaultedField(...)` / `withDefaultedFields(List<Object>)`                   | Also default a non-required field                         |
| Configure | `withOptionalField(...)` / `withOptionalFields(List<Object>)`                     | Skip auto-populating a field                              |
| Configure | `withCount(Integer)`                                                              | Number of records for `buildList()`                       |
| Configure | `withRecordType(String developerName)`                                            | Set the record type by developer name                     |
| Configure | `withChildren(...)`                                                               | Attach child records (several overloads)                  |
| Configure | `withoutInsertion()` / `withoutInsertion(Boolean)`                                | Control DML and mock Ids                                  |
| Finish    | `build()`                                                                         | Returns a single `SObject`                                |
| Finish    | `buildList()`                                                                     | Returns a `List<SObject>` of `withCount(n)` records       |

### Layer 2: [TST_Factory](reference/apex/TST_Factory.md)

`TST_Factory` skips the setup a record needs in test after test (a `User` on a given profile, a permission set
assignment, an active feature flag). It offers ready-made builders for users, permission set assignments, feature
flags, API call records, API settings and content versions. The methods you call most:

| Method                                                                                   | What you get                                                        |
|------------------------------------------------------------------------------------------|---------------------------------------------------------------------|
| `kern.TST_Factory.insertUser(profileName)` / `insertUser(profileName, companyName)`      | A saved `User`, ready for `System.runAs`                            |
| `kern.TST_Factory.insertUsers(profileName, count)` / `insertUsers(users)`                | A saved batch, or users you shaped yourself, saved                  |
| `kern.TST_Factory.newUser(profileName)` / `newUser(profileName, companyName)`            | An unsaved `User` (you choose when to insert it)                    |
| `kern.TST_Factory.newUsers(profileName, count)`                                          | A list of unsaved `User` records                                    |
| `kern.TST_Factory.newUserWithPermissionSet(profileName, companyName, permissionSetName)` | Saves a user and assigns a permission set (or permission set group) |
| `kern.TST_Factory.createPermissionSetAssignments(users, permissionSetOrGroupName)`       | Assigns a permission set to saved users                             |
| `kern.TST_Factory.newFeatureFlag(flagName)`                                              | Registers an active feature flag for the transaction                |

Trigger settings, trigger actions and validation rules: see
[Framework Metadata](#framework-metadata-triggers-and-validations).

---

## Anti-Patterns

| Anti-Pattern                                               | Why It's Wrong                                                                           | Instead                                                                 |
|------------------------------------------------------------|------------------------------------------------------------------------------------------|-------------------------------------------------------------------------|
| Calling `build()` inside a loop                            | One DML statement per iteration, which hits governor limits fast                        | `withCount(n).buildList()` (a single DML statement)                     |
| Setting every required field by hand                       | Verbose and brittle; renamed required fields break silently                              | Override only what the test asserts on; let the builder fill the rest   |
| Using `withoutInsertion(true)` when no Id is needed        | Generates a mock Id the test never uses, adding noise                                    | `withoutInsertion()` (no argument) for pure in-memory logic tests       |
| Building an `AggregateResult` by hand                      | `AggregateResult` has no public constructor, so it cannot be instantiated                | `kern.TST_Mock.registerAggregateRows`, then read with `toAggregateList()` |
| Forgetting `IsParallel=true` removal when inserting `User` | Salesforce forbids `User` DML in parallel tests                                          | Remove `IsParallel=true` from the class header for user-inserting tests |
| Hardcoding field names as strings in hand-written tests    | Breaks silently when fields are renamed or deleted                                       | Use `SObjectField` token overloads (`withOverride(Account.Name, …)`)    |

---

## Best Practices

### Override Only What Matters

Let the builder handle required fields. A test that names only the fields it asserts on stays focused
and survives unrelated schema changes.

```apex
// Good — the test cares about Industry; everything else is filled in
Account account = (Account)kern.TST_Builder.of(Account.SObjectType)
		.withOverride(Account.Industry, 'Technology')
		.build();
```

### Prefer In-Memory Builds for Pure Logic

If the code under test only reads fields, use `withoutInsertion()`: see [In-Memory, No Id](#in-memory-no-id).

### Bulk With One DML

Always create many records with `withCount(n).buildList()`, never a loop of `build()` calls (see
[withCount and buildList](#withcount-and-buildlist)).

### Use Mock Ids Only When the Code Needs an Id

Choose `withoutInsertion(true)` only when the code needs an Id, and `withoutInsertion()` otherwise: see
[Choosing a Mode](#choosing-a-mode).

### Build Relationships With `withChildren`

Let the builder set the foreign keys for you: see [Relationships](#relationships) for what a saved graph and an
in-memory graph give you.

### Prefer Token Overloads in Hand-Written Tests

`withOverride(Account.Name, …)` is compile-checked: see [Token Maps vs String Maps](#token-maps-vs-string-maps).

### Centralise Shared Setup in `TST_Factory`

If many test classes build the same kind of record (a user on a profile, an active flag), use the
existing `TST_Factory` method. For records specific to your own org, follow the same factory pattern
in your own test helper.

### Assert on User-Facing Text Through Custom Labels

When a test asserts on text that surfaces to an end user, compare against the Custom Label rather
than a hardcoded literal: in Apex via `System.Label.X`, in LWC via an import from
`@salesforce/label/c.X`. This keeps the test aligned with text that can be translated and
overridden.

### Let Salesforce Reset Static State

Salesforce resets static state (including any custom default provider you assigned) between test
methods. You do not need manual cleanup between methods for the test-data layer.

---

## Related Documentation

- [Test Data Fast Start](Fast%20Start%20-%20Test%20Data.md) - Build-and-test walkthrough, plus `TST_Mock` for DML-free query interception
- [Selectors - Guide](Selectors%20-%20Guide.md) - Querying records and mocking query results in tests
- [DML - Guide](DML%20-%20Guide.md) - DML operations and Unit of Work transactions
- [Triggers - Guide](Triggers%20-%20Guide.md) - Trigger actions and how to test them
- [Validation - Guide](Validation%20-%20Guide.md) - Validation rules and how to test them
