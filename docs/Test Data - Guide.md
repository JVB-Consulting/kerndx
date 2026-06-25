---
navOrder: 68
---

# Test Data - Guide

**Framework:** KernDX
**Package Type:** Managed Package

**Target Audience:**

- **Developers** - Building test records, relationships, mock Ids, and bulk data for Apex unit tests
- **Architects** - Designing a consistent, low-boilerplate test-data strategy across a team
- **Business Analysts** - Understanding what the test-data layer guarantees and where its limits are

---

## In one paragraph

Every Apex unit test needs example records to run against, and setting them up by hand is slow and
fragile: you fill in fields the test does not care about, that setup breaks every time a field is
renamed, and saving many records inside a loop quickly hits Salesforce's safety limits. This layer
builds those records for you. You name only the fields your test actually checks, and it fills in
the rest, then either saves the records or keeps them in memory. Developers use it for every test
that needs data; architects use it to give the whole team one consistent way to set up tests. Reach
for it whenever a test needs records, and skip it when a single plain `new Account(...)` would do.

---

## Table of Contents

<details>
<summary>Expand</summary>

1. [Quick Navigation](#quick-navigation)
2. [Overview](#overview)
3. [Quick Start](#quick-start)
4. [Escape Hatches](#escape-hatches)
5. [Architecture](#architecture)
    - [KernDX vs OOTB: Test Data Comparison](#kerndx-vs-ootb-test-data-comparison)
    - [Layer 1: TST_Builder](#layer-1-tst_builder)
    - [Layer 2: TST_Factory](#layer-2-tst_factory)
6. [Building Records](#building-records)
    - [A Single Record](#a-single-record)
    - [Overriding Fields](#overriding-fields)
    - [Token Maps vs String Maps](#token-maps-vs-string-maps)
    - [Building by API Name](#building-by-api-name)
    - [Defaulting Optional Fields](#defaulting-optional-fields)
    - [Marking Fields Optional](#marking-fields-optional)
    - [Record Types](#record-types)
7. [Bulk Creation](#bulk-creation)
    - [withCount and buildList](#withcount-and-buildlist)
    - [Cycling Values Across Records](#cycling-values-across-records)
8. [Insertion Modes](#insertion-modes)
    - [Insert (Default)](#insert-default)
    - [In-Memory, No Id](#in-memory-no-id)
    - [In-Memory with Mock Ids](#in-memory-with-mock-ids)
    - [Choosing a Mode](#choosing-a-mode)
9. [Relationships](#relationships)
    - [Adding Child Records](#adding-child-records)
    - [Child Builders](#child-builders)
    - [Explicit Relationship Names](#explicit-relationship-names)
    - [Mock Ids Across a Graph](#mock-ids-across-a-graph)
10. [The Factory Pattern](#the-factory-pattern)
    - [Why a Factory](#why-a-factory)
    - [Users and Permission Sets](#users-and-permission-sets)
    - [Feature Flags](#feature-flags)
    - [Framework Metadata: Triggers and Validations](#framework-metadata-triggers-and-validations)
    - [Custom Metadata Records](#custom-metadata-records)
    - [Logger Configuration](#logger-configuration)
11. [Extending the Defaults](#extending-the-defaults)
    - [Custom Default Value Provider](#custom-default-value-provider)
    - [Auto-Default Marker](#auto-default-marker)
12. [Capability Matrix (for Analysts)](#capability-matrix-for-analysts)
13. [Anti-Patterns](#anti-patterns)
14. [Best Practices](#best-practices)
    - [Override Only What Matters](#override-only-what-matters)
    - [Prefer In-Memory Builds for Pure Logic](#prefer-in-memory-builds-for-pure-logic)
    - [Bulk With One DML](#bulk-with-one-dml)
    - [Use Mock Ids Only When the Code Needs an Id](#use-mock-ids-only-when-the-code-needs-an-id)
    - [Build Relationships With withChildren](#build-relationships-with-withchildren)
    - [Prefer Token Overloads in Hand-Written Tests](#prefer-token-overloads-in-hand-written-tests)
    - [Centralise Shared Setup in TST_Factory](#centralise-shared-setup-in-tst_factory)
    - [Assert on User-Facing Text Through Custom Labels](#assert-on-user-facing-text-through-custom-labels)
    - [Let Salesforce Reset Static State](#let-salesforce-reset-static-state)
15. [Related Documentation](#related-documentation)

</details>

---

## Quick Navigation

| I am a...     | I need to...                      | Go to...                                             |
|---------------|-----------------------------------|------------------------------------------------------|
| **Developer** | Build one record fast             | [Quick Start](#quick-start)                          |
| **Developer** | Build records in bulk             | [Bulk Creation](#bulk-creation)                      |
| **Developer** | Build records with no DML         | [Insertion Modes](#insertion-modes)                  |
| **Developer** | Build parent-child graphs         | [Relationships](#relationships)                      |
| **Architect** | Standardise team test data        | [The Factory Pattern](#the-factory-pattern)          |
| **Architect** | Customise auto-populated defaults | [Extending the Defaults](#extending-the-defaults)    |
| **Analyst**   | Understand guarantees and limits  | [Capability Matrix](#capability-matrix-for-analysts) |

---

## Overview

The Test Data layer builds the example records your Apex unit tests run against, and it keeps the
setup short. You name the kind of record you want and override only the fields the test actually
cares about. The framework fills in the rest of the required fields, saves the record (or keeps it
in memory), and hands it back. So your test stays focused on what it is checking, not on the
plumbing of constructing a valid record.

**Managed Package Context:**

This framework is exposed as `global` classes in a managed package. When calling these classes from
your org's Apex, use the `kern.` namespace prefix, for example `kern.TST_Builder` and
`kern.TST_Factory`. The framework source is also available if you build and manage the package
yourself.

The layer has two classes that work together:

1. **[`TST_Builder`](reference/apex/TST_Builder.md)** is the primary tool. You configure it with short
   chained calls, then one call builds the record and returns it. It works for any SObject and
   handles overrides, bulk creation, cycling values across records, parent-child relationships, and
   three ways of saving (or not saving) the record.
2. **[`TST_Factory`](reference/apex/TST_Factory.md)** is a convenience layer on top. It offers ready-made
   builders for records nearly every test needs (users, permission set assignments, feature flags),
   plus helpers for the framework's own configuration records (trigger settings, validation rules,
   custom metadata).

> **Scope:** This guide is the deep reference for the test-data layer. There is also a way to feed
> in-memory records to a query without touching the database, so `kern.QRY_Builder` returns them as
> if it had run a real query. That is handled by `TST_Mock`, which shares the same chained build
> calls as `TST_Builder`; the [Test Data Fast Start](Fast%20Start%20-%20Test%20Data.md) covers it end to
> end.

> **Responsibilities:** This layer only builds records (and optionally saves them) for tests. It does
> not run production business logic, and most of it is meant to be called from test code (`@IsTest`).
> `TST_Builder` and the `TST_Factory` methods run from anonymous Apex and from a subscriber
> `@IsTest` class. To set up framework configuration records (trigger settings, validation rules,
> masking) for your tests, deploy the relevant `CustomMetadata` records via XML (see
> [Framework Metadata](#framework-metadata-triggers-and-validations)).

**Key Benefits:**

- **Less setup code.** Override only what matters; required fields are filled in for you.
- **Type safety.** Passing the field as a token (`SObjectField`) lets the compiler catch field-name typos before the test ever runs.
- **Bulk in one statement.** `withCount(n).buildList()` creates many records with a single save, so you stay within Salesforce's per-transaction limits.
- **Build without saving.** Build records in memory, with or without mock Ids, for fast tests that never touch the database.
- **Relationships.** Build a parent and its children together and save them as one all-or-nothing unit: they all commit, or none do (a Unit of Work).
- **Consistency.** `TST_Factory` keeps the setup every test class would otherwise repeat in one place.

---

## Quick Start

Use [`TST_Builder`](reference/apex/TST_Builder.md) directly. No custom class is required.

> **Step-by-step walkthrough:** the [Test Data Fast Start](Fast%20Start%20-%20Test%20Data.md) covers
> a full build-and-test cycle, plus `TST_Mock` for DML-free query testing.

```apex
// Build and insert a single Account; required fields are auto-populated
Account account = (Account)kern.TST_Builder.of(Account.SObjectType)
		.withOverride(Account.Industry, 'Technology')
		.build();

System.debug('Id: ' + account.Id + ', Industry: ' + account.Industry);
```

`build()` returns one record (saved to the database by default). `buildList()` returns a
`List<SObject>` and respects `withCount(n)`. Cast the result to your concrete type.

For deeper coverage, continue reading the sections below.

---

## Escape Hatches

Sometimes you want to step outside the builder, and you can. The test-data layer is opt-in: when it
does not fit, plain Apex record creation still works exactly as it always has. Nothing in the
framework gets in the way.

| You need                                                                  | Use                                                                                                | See                                                       |
|---------------------------------------------------------------------------|----------------------------------------------------------------------------------------------------|-----------------------------------------------------------|
| **A plain record with no auto-population**                                | `new Account(Name = 'X')` then `insert` (standard Apex, no wrapper).                               | —                                                         |
| **One field that the builder shouldn't default**                          | `withOptionalField(field)` to skip a required field, or build the record by hand.                  | [Marking Fields Optional](#marking-fields-optional)       |
| **DML-free query interception (records flow through `kern.QRY_Builder`)** | `kern.TST_Mock` (same chained build calls as `TST_Builder`, auto-registers for query mocking).     | [Test Data Fast Start](Fast%20Start%20-%20Test%20Data.md) |
| **Aggregate-query test data**                                             | Insert real records via `TST_Builder`. `AggregateResult` cannot be mocked (platform limitation).   | [Anti-Patterns](#anti-patterns)                           |
| **Custom default values for a field type**                                | Extend `kern.TST_Builder.DefaultValueProvider` and assign `kern.TST_Builder.defaultValueProvider`. | [Extending the Defaults](#extending-the-defaults)         |

The builder saves you time; it does not lock you in. Reach for it when its features pay off, and
skip it when they don't.

---

## Architecture

If you want to know how the pieces fit before using them, here is the shape. Your test code calls
either the convenience layer (`TST_Factory`) or the builder directly (`TST_Builder`); the builder
fills in field defaults through a part you can replace if you need to (`DefaultValueProvider`). The
diagram below shows that flow, top to bottom.

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

### KernDX vs OOTB: Test Data Comparison

Salesforce has no built-in test-data factory. The standard approach is to hand-construct records:

```apex
Account account = new Account(Name = 'Test', Industry = 'Technology');
insert account;
```

| Feature                       | KernDX Test Data Layer                                             | Hand-Written Test Data                                      |
|-------------------------------|--------------------------------------------------------------------|-------------------------------------------------------------|
| **Required-field population** | ✅ Auto-populated; override only what the test needs                | ❌ Every required field set by hand on every record          |
| **Field type safety**         | ✅ `SObjectField` token overloads (`withOverride(Account.Name, …)`) | ✅ Direct field access is compile-checked too                |
| **Bulk creation**             | ✅ `withCount(n).buildList()` (single DML statement)                | ⚠️ Manual loop; easy to accidentally DML inside the loop    |
| **Cycling values**            | ✅ `withCycle(field, values)` rotates across records                | ❌ Manual index arithmetic                                   |
| **In-memory / mock Ids**      | ✅ `withoutInsertion()` / `withoutInsertion(true)`                  | ⚠️ Manual; mock Ids require a separate helper               |
| **Parent-child graphs**       | ✅ `withChildren(...)` (parent and children saved as one unit)      | ⚠️ Insert parent, set foreign keys, insert children by hand |
| **Consistency across a team** | ✅ `TST_Factory` centralises shared setup                           | ⚠️ Each test class repeats its own boilerplate              |
| **Simplicity for one field**  | ⚠️ Builder API to learn                                            | ✅ A single `new` expression is familiar to everyone         |

Use the builder when its features pay off (bulk, relationships, no-DML, shared setup). For a single
throwaway record in one test, a plain `new` expression is perfectly fine.

### Layer 1: [TST_Builder](reference/apex/TST_Builder.md)

**Purpose:** Build a valid record without listing every required field. You configure it with short
chained calls, then one call builds the record (and saves it, unless you ask it not to). It fills in
the fields Salesforce requires for you.

**When to Use:** For building records in any test. One caveat in a subscriber org: if you have added
custom validation rules, a record may need extra `withOverride()` calls to satisfy them, beyond the
Salesforce-required fields the builder already fills in.

**Where you start a build:**

- `kern.TST_Builder.of(SObjectType)`: start a build for a typed SObject.
- `kern.TST_Builder.of(String)`: start a build by SObject API name (resolved via describe).

**How you configure it** (every call below chains onto the previous one and returns the `Builder`):

- `withOverride(field, value)` / `withOverride(fieldName, value)`: set one field.
- `withOverrides(Map<SObjectField, Object>)` / `withOverrides(Map<String, Object>)`: set many.
- `withCycle(field, values)` / `withCycle(fieldName, values)`: rotate values across `buildList()`.
- `withDefaultedField(...)` / `withDefaultedFields(List<Object>)`: also default a non-required field.
- `withOptionalField(...)` / `withOptionalFields(List<Object>)`: skip auto-populating a field.
- `withCount(Integer)`: number of records for `buildList()`.
- `withRecordType(String developerName)`: set the record type by developer name.
- `withChildren(...)`: attach child records (several overloads).
- `withoutInsertion()` / `withoutInsertion(Boolean)`: control DML and mock Ids.

**The call that finishes the build and returns the records:**

- `build()`: returns a single `SObject`.
- `buildList()`: returns a `List<SObject>` of `withCount(n)` records.

### Layer 2: [TST_Factory](reference/apex/TST_Factory.md)

**Purpose:** Skip the repeated setup. These are ready-made builders for the records nearly every
test needs, plus helpers for the framework's own configuration records.

**When to Use:** When a record needs the same setup across many tests (a `User` on a given profile, a
permission set assignment, an active feature flag), or when you need to wire up framework
configuration (trigger settings, validation rules) for a test.

**Methods you can call:**

- `kern.TST_Factory.newUser(profileName)` / `newUser(profileName, companyName)`: an unsaved `User` (you choose when to insert it).
- `kern.TST_Factory.newUsers(profileName, count)`: a list of unsaved `User` records.
- `kern.TST_Factory.newUserWithPermissionSet(profileName, companyName, permissionSetName)`: inserts a
  user and assigns a permission set (or permission set group).
- `kern.TST_Factory.createPermissionSetAssignments(users, permissionSetOrGroupName)`: assign a
  permission set to existing users.
- `kern.TST_Factory.newFeatureFlag(flagName)`: register an active feature flag for the transaction.

To set up framework configuration (trigger settings, trigger actions, and validation rules) for a
test, deploy the relevant `CustomMetadata` records via XML (see
[Framework Metadata](#framework-metadata-triggers-and-validations)).

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

Override only the fields the test cares about. Everything else the test doesn't name is either
auto-populated (if required) or left null.

```apex
Account account = (Account)kern.TST_Builder.of(Account.SObjectType)
		.withOverride(Account.Name, 'Acme Corp')
		.withOverride(Account.Industry, 'Technology')
		.build();

Assert.areEqual('Acme Corp', account.Name, 'Name override should apply');
```

### Token Maps vs String Maps

When you want to set several fields at once, pass a map. Prefer the field-token form
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

> Prefer the `SObjectField` token overloads in hand-written tests so the compiler catches renamed or
> deleted fields. Reach for the `String` overloads only when the field name genuinely varies at
> runtime.

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

When a record needs a specific record type, set it by its developer name. An unknown developer name
throws an `IllegalArgumentException`. A blank name is ignored.

```apex
Account account = (Account)kern.TST_Builder.of(Account.SObjectType)
		.withRecordType('Enterprise_Account')
		.withOverride(Account.Name, 'Enterprise Corp')
		.build();
```

> In a subscriber org a packaged record type may not be assigned to the running profile. If a build
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

Sometimes you want a batch of records to cover several variations of one field, say a few different
industries, without writing a separate test method for each. `withCycle(field, values)` does that:
it rotates your list of values across the records that `buildList()` produces. If there are more
records than values, the values repeat from the start. The value list must not be null or empty.

```apex
List<SObject> records = kern.TST_Builder.of(Account.SObjectType)
		.withCycle(Account.Industry, new List<Object> {'Technology', 'Finance', 'Healthcare'})
		.withCount(6)
		.buildList();
// Industries: Technology, Finance, Healthcare, Technology, Finance, Healthcare
```

---

## Insertion Modes

Not every test needs to save its records. Some only read fields, so saving them is wasted time and
governor-limit cost. You pick one of three modes, depending on whether the record needs to reach the
database and whether your code needs an Id on it.

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

Tests often need a parent record with related children, and wiring the foreign keys by hand is
fiddly. The builder constructs the whole parent-child graph for you. When you save it, parent and
children commit together as one all-or-nothing unit (a Unit of Work): they all save, or none do.
When you build in memory instead, the child relationship is filled in so it reads back just like a
subquery result.

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

### Why a Factory

Some records need the same multi-field setup in test after test: a `User` on a specific profile, a
permission set assignment, an active feature flag, or the framework's own configuration metadata.
[`TST_Factory`](reference/apex/TST_Factory.md) wraps `TST_Builder` with pre-configured builders for
these cases so the setup lives in one place instead of being copied across every test class.

### Users and Permission Sets

`newUser` returns an **unsaved** `User`, so you decide when to insert it. One platform rule to
remember: Salesforce forbids inserting `User` records in parallel tests, so remove `IsParallel=true`
from the test class header whenever the test inserts a `User`.

```apex
@IsTest
private static void shouldRunAsStandardUser()
{
	User testUser = kern.TST_Factory.newUser('Standard User');
	insert testUser;

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

Assign a permission set (or permission set group) to existing users with
`createPermissionSetAssignments`. It throws an `AssertException` if the named permission set cannot
be resolved.

```apex
List<User> users = kern.TST_Factory.newUsers('Standard User', 2);
insert users;
kern.TST_Factory.createPermissionSetAssignments(users, 'My_Permission_Set');
```

When you need a saved admin user that test methods reach through `System.runAs`,
`newUserWithPermissionSet` builds the user, inserts it, and assigns the permission set in one call.
That makes it a good fit inside `@TestSetup`.

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

To exercise framework trigger or validation behaviour in your tests, deploy the relevant framework
configuration (trigger settings, trigger actions, validation rules, and validation rule groups) as
`CustomMetadata` records via XML. Those records are in place for every test that runs against the
org, so a test simply builds a record and asserts on the resulting trigger or validation behaviour.

> **Setting up framework metadata for tests.** Deploy the `TriggerSetting__mdt`,
> `TriggerAction__mdt`, `ValidationRule__mdt`, and related records your tests rely on as
> `CustomMetadata` via XML. See the
> [Trigger Actions Fast Start](Fast%20Start%20-%20Trigger%20Actions.md) and
> [Custom Validations Fast Start](Fast%20Start%20-%20Custom%20Validations.md) for that pattern.

Once the trigger action metadata is deployed, a test builds a record and asserts that the action
fired:

```apex
@IsTest
private static void shouldFireTriggerAction()
{
	Account account = (Account)kern.TST_Builder.of(Account.SObjectType).build();
	Assert.isNotNull(account.Id, 'Record inserted and trigger action should have fired');
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
<CustomMetadata xmlns="http://soap.sforce.com/2006/04/metadata">
    <label>Mask Contact Email</label>
    <values>
        <field>kern__SObjectType__c</field>
        <value xsi:type="xsd:string">Contact</value>
    </values>
    <values>
        <field>kern__Rule__c</field>
        <value xsi:type="xsd:string">kern__Mask_Email</value>
    </values>
</CustomMetadata>
```

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

The logging framework runs inside tests using your org's configuration, so the logs you generate in
a test go through the same code path as in production. By default it discards log records during
tests, to avoid cluttering them. When a test needs to check what was logged, set the global
`kern.LOG_Builder.ignoreTestMode` flag to `true`:

```apex
kern.LOG_Builder.ignoreTestMode = true;
```

> The flag is reset between test methods along with all other static state, so enabling it in one
> test never leaks into another.

---

## Extending the Defaults

### Custom Default Value Provider

The values the builder fills in come from a default value provider. If you need to change how those
defaults are generated (say, to satisfy an unusual required-field setup), extend
`kern.TST_Builder.DefaultValueProvider` and assign an instance to
`kern.TST_Builder.defaultValueProvider`. It is a `global virtual` class rather than an interface, so
the framework can add methods in future releases without breaking your subclass.

```apex
public class MyDefaultProvider extends kern.TST_Builder.DefaultValueProvider
{
	public override Map<String, kern.TST_Builder.DefaultFieldValueProvider> getDefaultMapOfValues(
			SObjectType sObjectType,
			Map<String, Object> overrides)
	{
		Map<String, kern.TST_Builder.DefaultFieldValueProvider> defaults =
				super.getDefaultMapOfValues(sObjectType, overrides);
		// add or replace field-level default providers here
		return defaults;
	}
}

// Apply it for the transaction
kern.TST_Builder.defaultValueProvider = new MyDefaultProvider();
```

> A custom provider is set per transaction. Salesforce resets static state between test methods, so
> the assignment does not leak into other tests.

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

## Capability Matrix (for Analysts)

If you are evaluating what this layer does without reading the code, this table is your summary. Each
row names a capability, the method that provides it, and anything worth knowing about its limits.

| Capability                        | How it is expressed                            | Notes                                                              |
|-----------------------------------|------------------------------------------------|--------------------------------------------------------------------|
| Auto-populate required fields     | Default behaviour of `build()` / `buildList()` | Custom validation rules may require additional overrides           |
| Override specific fields          | `withOverride` / `withOverrides`               | Token overloads are compile-checked                                |
| Bulk creation, single DML         | `withCount(n).buildList()`                     | Keeps tests within governor limits                                 |
| Rotate values across records      | `withCycle(field, values)`                     | Repeats the list when records exceed values                        |
| Build without DML                 | `withoutInsertion()`                           | No Id; fastest path                                                |
| Build without DML, with an Id     | `withoutInsertion(true)`                       | Valid mock Id for `Id != null` logic and query mocking             |
| Parent-child graphs               | `withChildren(...)`                            | Single Unit of Work on insert; in-memory linkage without insert    |
| Record types                      | `withRecordType(developerName)`                | Falls back to master when the packaged type is unavailable         |
| Common records (users, flags)     | `TST_Factory` methods                          | Centralises repeated setup                                         |
| Framework metadata for tests      | Deploy `CustomMetadata` records via XML        | Sets up trigger and validation behaviour for your tests           |
| Customise auto-populated defaults | Extend `DefaultValueProvider`                  | Per-transaction; reset between test methods                        |

---

## Anti-Patterns

These are the common mistakes worth avoiding. Each row pairs a tempting shortcut with the problem it
causes and the safer approach to use instead.

| Anti-Pattern                                               | Why It's Wrong                                                                           | Instead                                                                 |
|------------------------------------------------------------|------------------------------------------------------------------------------------------|-------------------------------------------------------------------------|
| Calling `build()` inside a loop                            | One DML statement per iteration, which hits governor limits fast                        | `withCount(n).buildList()` (a single DML statement)                     |
| Setting every required field by hand                       | Verbose and brittle; renamed required fields break silently                              | Override only what the test asserts on; let the builder fill the rest   |
| Using `withoutInsertion(true)` when no Id is needed        | Generates a mock Id the test never uses, adding noise                                    | `withoutInsertion()` (no argument) for pure in-memory logic tests       |
| Trying to mock aggregate queries                           | `AggregateResult` has no public constructor, so it cannot be instantiated                | Insert real records via `TST_Builder`, then run the aggregate query     |
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

If the code under test only reads fields, `withoutInsertion()` skips DML entirely, giving you faster
tests at no governor cost.

### Bulk With One DML

Always create many records with `withCount(n).buildList()`, never a loop of `build()` calls.

### Use Mock Ids Only When the Code Needs an Id

Reach for `withoutInsertion(true)` when logic checks `Id != null`, keys a map by Id, or registers a
query mock. Otherwise use `withoutInsertion()`.

### Build Relationships With `withChildren`

Let the builder set the foreign keys for you. On insert it saves the whole graph as one all-or-nothing
unit (a Unit of Work). In memory it links the graph so children read back like subquery results.

### Prefer Token Overloads in Hand-Written Tests

`withOverride(Account.Name, …)` is compile-checked. Use the `String` overloads only when the field
name is genuinely dynamic.

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
- [Triggers - Guide](Triggers%20-%20Guide.md) - Trigger actions tested with factory-built metadata
- [Validation - Guide](Validation%20-%20Guide.md) - Validation rules tested with factory-built metadata
