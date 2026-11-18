---
navOrder: 12
navLabel: "Selectors (queries and SOQL)"
movedAnchors: {"kerndx-vs-ootb-selector-framework-comparison": "/#selectors", "salesforce-out-of-the-box-alternative": "/#selectors", "pros-cons-comparison": "/#selectors", "when-to-use-kerndx-selector-framework": "/#selectors", "when-to-use-ootb-inline-soql": "/#selectors", "example-comparison": "/#selectors", "capability-matrix-for-analysts": "/#selectors", "security-methods-overview": "/selectors-guide#where-the-security-methods-are-described", "custom-reusable-selectors-5-use-case": "/selectors-guide#extending-qry-builder-builder-directly", "layer-1-qry-builder-recommended-default-for-your-org": "/selectors-guide#layer-1-qry-builder-the-engine-every-selector-runs-on", "use-query-property-inside-selectors-qry-builder-for-one-off": "/selectors-guide#read-through-the-selector-inside-and-outside-it", "aggregate-queries-1": "/selectors-guide#aggregate-queries", "simple-aggregation": "/selectors-guide#group-by", "aggregation-with-having-clause": "/selectors-guide#aggregate-queries", "querylocator-for-batch-apex-1": "/selectors-guide#querylocator-for-batch-apex", "query-conditions-not-evaluated": "/selectors-guide#which-query-conditions-a-mock-checks", "multiple-grouping-fields": "/selectors-guide#multi-field-grouping"}
---

# Selectors - Guide

**Who this page is for:** developers who read records in Apex and want type-safe queries with sharing enforcement and
reusable query logic; the architects who design the data access layer, its abstraction and its security controls; and
the business analysts who need to understand what the queries can do and which sharing and access rules they enforce.

New to it? Try [Fast Start - Selectors](Fast%20Start%20-%20Selectors.md) first: a step-by-step walkthrough that covers
implementation, testing, and common pitfalls. Deciding whether to use KernDX? See
[Why KernDX](Strategic%20Guide%20-%20Overview.md).

## Copy this first

```apex
List<Account> accounts = kern.QRY_Builder.selectFrom(Account.SObjectType)
	.fields(new List<SObjectField>{ Account.Name, Account.Industry })
	.condition(Account.Industry).equals('Technology')
	.orderBy(Account.Name).ascending()
	.toList();
```

**What this does:** returns the accounts in the Technology industry, with Name and Industry filled in, sorted by Name.
The read checks the current user's object and field permissions, and record sharing. Switch the
[user mode flag](#user_mode-security) off and the permission checks stop; record sharing then follows your class's
sharing keyword.

**Read next:** [More filters](#complex-where-conditions), [Counts and totals](#aggregate-functions),
[A reusable selector class](#custom-selector-classes), [Fake query results in a test](#basic-query-mocking).

---

## Quick Navigation

| I need to... | Go to... |
|---|---|
| Add my own query method to a selector, and test it | [Custom Selector Classes](#custom-selector-classes), [Read Through the Selector, Inside and Outside It](Selectors%20-%20Guide.md#read-through-the-selector-inside-and-outside-it), [Extending QRY_Builder.Builder directly](Selectors%20-%20Guide.md#extending-qry-builder-builder-directly) |
| Find records by Id or by a field value | [Basic Queries](#basic-queries) |
| Add a field for one read without changing the selector | [Adding a field for one read](#adding-a-field-for-one-read) |
| Filter with AND, OR and grouped conditions | [Complex WHERE Conditions](#complex-where-conditions) |
| Sort and limit results, or sort by a column a user clicks | [ORDER BY and LIMIT](#order-by-and-limit) |
| Let a page or a user choose a field safely | [Field names from a page or a user](#field-names-from-a-page-or-a-user) |
| Search for text a person typed | [Searching for text a person typed](#searching-for-text-a-person-typed) |
| Page through large result sets | [Pagination](#pagination) |
| Count, total or group records, or keep only groups that pass a limit | [Aggregate Functions](#aggregate-functions), [GROUP BY](Selectors%20-%20Guide.md#group-by), [Aggregate Queries](Selectors%20-%20Guide.md#aggregate-queries), [Multi-Field Grouping](Selectors%20-%20Guide.md#multi-field-grouping) |
| Read child records with their parent | [Parent-to-Child Subqueries](#parent-to-child-subqueries) |
| Understand sharing, and see what each setting returns for a user with no share and no object permission | [Sharing Enforcement](#sharing-enforcement), [What does each setting return?](#what-does-each-setting-return) |
| Read records whatever their sharing (use with caution) | [Bypassing Sharing](#bypassing-sharing) |
| Run one selector in system mode, or turn the user-mode default off for every query that runs through the framework | [Switching a selector, or the whole framework, to system mode](#switching-a-selector-or-the-whole-framework-to-system-mode) |
| Cache query results | [Caching Queries](#caching-queries) |
| Process many records: Batch Apex or a cursor | [QueryLocator for Batch Apex](Selectors%20-%20Guide.md#querylocator-for-batch-apex), [Cursor-Based Processing](#cursor-based-processing) |
| Fake query results in a test, aggregates too | [Basic Query Mocking](#basic-query-mocking), [Mocking an aggregate query](#mocking-an-aggregate-query) |
| Avoid the common mistakes | [Anti-Patterns](#anti-patterns) |
| How it works, every method, and where the security methods are described | [How does it work?](#how-does-it-work), [Layer 1: QRY_Builder](Selectors%20-%20Guide.md#layer-1-qry-builder-the-engine-every-selector-runs-on), [Where the security methods are described](Selectors%20-%20Guide.md#where-the-security-methods-are-described) |
| See why KernDX is worth using | [Why KernDX](/) |

---

## Quick Start

Pick the case that fits:

| Your case | What to write |
|---|---|
| The object has no selector yet | A selector: extend `SEL_Base` once, list that object's default fields, and you get ready-made `findById()` and `findByField()` methods for free. The sample below |
| The object has a selector, and you need a query it does not have yet | A method on the selector that starts from its `query` property: [Custom Selector Classes](#custom-selector-classes) |
| One read needs fields the defaults leave out | One call on the selector's `query` property: [Adding a field for one read](#adding-a-field-for-one-read) |

```apex
public with sharing class SEL_Accounts extends SEL_Base
{
	public SEL_Accounts()
	{
		super(Account.SObjectType);
	}

	public override List<SObjectField> getFields()
	{
		return new List<SObjectField>{ Account.Name, Account.Industry };
	}
}

// Usage
Account account = (Account)new SEL_Accounts().findById(accountId);
```

> **Namespaces in code samples:** `kern.` on a class and `kern__` on an object, field, or metadata type mark the managed package's namespace.
> On the managed package, framework references need those prefixes even where a sample omits them; repackaged under your own namespace, replace `kern`/`kern__`
> with your prefix; on an unmanaged deploy, drop them. See [How to read the code samples](Installation.md#how-to-read-the-code-samples).

---

## What problem does this solve?

Every Salesforce app reads data, and most teams scatter SOQL queries (Salesforce's query language) across dozens of classes. The same field list gets copied from place to place, typos slip through, and it is easy to accidentally show a user records they should not see.

This framework gives you one consistent, type-checked way to query data. A query reads cleanly, runs the right security checks by default, and lives in one place you can reuse. You write queries by chaining short method calls instead of building strings by hand.

Use it whenever your code reads records. KernDX expects every read to go through a selector, because that is how a query gets the security checks, caching, logging and test mocks described below.

## Mental model

Think of a selector as a recipe card for one object. The card lists the fields you usually want and the named queries you run again and again, so anyone reading from that object follows the same recipe instead of writing it from scratch each time.

Under the card sits a query engine that does the actual cooking: you tell it what you want with short chained calls, and it builds and runs the SOQL for you.

## Use this when

- Your code reads records, and you want every query on an object to share one field list and one set of named methods.
- You want field references checked when you compile, so a renamed or deleted field is caught early instead of failing at runtime.
- You need clear, per-query control over who sees what (the org's sharing rules), or you want field-level security and object permissions enforced automatically.
- You query large datasets and want paging past the 2,000-record OFFSET ceiling, cursors for millions of rows, or built-in result caching, without writing that plumbing yourself.
- You want to feed a query fake results in a test, so business logic can be tested without touching the database.

## Don't use this when

KernDX is opinionated here: every read goes through a selector. There are only two real exceptions.

- The framework cannot express the query you need. Raise it with the KernDX team so the gap can be closed, and keep the plain `[SELECT … FROM …]` in one place until then. The Kern scanner rule `KernNoInlineSOQL` flags inline SOQL in your pipeline, so mark that one place with `@SuppressWarnings('PMD.KernNoInlineSOQL')`.
- The code runs where the framework does not reach: A Lightning component should use Salesforce's native client-side caching (`@wire(getRecord)` and friends) instead of an Apex query. The framework's own components do exactly that.

## What is it, and what do you get?

These classes ship as part of a managed package: you call them with the package namespace (see the note under
[Quick Start](#quick-start)), and you also get the full source and can build and manage the package yourself.

The framework has three small layers, each with a clear job, and all of them finally call Salesforce's standard
`Database.query()`:

1. **[QRY_Builder](reference/apex/QRY_Builder.md)** is the query engine. You configure a query with short chained calls, then one call runs it and returns the result. It handles caching, paging through large result sets, and reshaping results.
2. **[SEL_Base](reference/apex/SEL_Base.md)** is the production pattern. You extend it once per object to make a reusable "selector" that already knows that object's default fields and ready-made query methods.
3. **[QRY_Condition](reference/apex/QRY_Condition.md)** holds the low-level building blocks for filter conditions and operators, used by the two layers above.

**For production code, create selectors.** Extend [`SEL_Base`](reference/apex/SEL_Base.md) (for example, `SEL_Accounts` or `SEL_Contacts`). You get a default field set, inherited `findById()` and `findByField()` methods, and a place to add your own query methods that use the `query` property. Every query for that object lives in one class, so a field change or a new filter is made once.

**Every read goes through a selector.** If an object has no selector yet, write one: it takes a few lines (see [Quick Start](#quick-start)), and every later query on that object reuses it. Selectors run on [`QRY_Builder`](reference/apex/QRY_Builder.md) internally through the `query` property, so QRY_Builder is the engine under every selector, not a second way to query.

| What | In short |
|---|---|
| Scope | The framework ships 14 ready-made `SEL_*` selectors you can call (most extend `SEL_Base`), plus the `QRY_Builder` query engine with caching, paging, semi-joins (filtering one query by another query's results), aggregates, and 6 security methods. |
| Responsibilities | Selectors only read data. They never save, update, or delete records, and they hold no business logic. All data changes belong in trigger actions, service classes, or the DML framework, which keeps selectors simple and easy to test. |

**What you get:**

- **Fewer typos.** You reference a field by its type-checked token (`Account.Name`) instead of a string, so a misspelled or deleted field is caught when you compile, not at runtime.
- **Clear control over who sees what.** You decide, per query, whether to enforce or bypass the org's sharing rules (which records each user is allowed to see).
- **Easy testing.** You can feed a query fake results in a test, so business logic can be tested without touching the database.
- **One place to change.** All of an object's query logic sits in its selector class, so edits happen once.
- **Safe by default.** Queries run with the current user's read permissions and record sharing enforced. A value, or a field name passed to the condition, sort, group and count methods, cannot change the query. Field names you select are not checked: pass them as tokens or constants. How this works: [Field names from a page or a user](#field-names-from-a-page-or-a-user).
- **Consistency.** Every query follows the same shape across your codebase.
- **Performance.** Passing values as bind variables lets Salesforce reuse its query plans.

## How to opt out

A read through a selector gets these for free. A read written as plain SOQL loses all of them:

- **Security by default.** The query runs with the current user's object permissions, field security and record sharing (USER_MODE).
- **Caching.** One override on the selector caches every read it makes.
- **Logging.** Slow queries are logged when performance logging is on, and every switched-off safety check is recorded.
- **Test mocks.** `TST_Mock` can feed the query fake results in a test.

The rules, and the only ways out:

- Every read goes through a `SEL_Base` selector. Its default fields cover the usual case.
- When one query needs other fields, change them with one call on the selector's `query` property. `addField`, `addFields`, `addFieldSet` and `relatedFields` add fields; `fields` and `fieldSet` replace the list.
- `QRY_Builder` is the engine selectors run on, not an everyday alternative.
- Plain SOQL is only for a query the framework cannot express (raise it with the KernDX team), or for code the framework does not reach. The framework's own Lightning components query through Salesforce's standard client-side caching directly.

| You need                                                        | Use                                                                                                                                                                                                                                                                   | See                                                           |
|-----------------------------------------------------------------|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|---------------------------------------------------------------|
| **A query the framework cannot express**                        | Raise it with the KernDX team. Until it is fixed, write standard `[SELECT … FROM …]` in one place and mark it with `@SuppressWarnings('PMD.KernNoInlineSOQL')`, because the Kern scanner rule `KernNoInlineSOQL` flags inline SOQL in your pipeline.                  | [Don't use this when](#dont-use-this-when)                    |
| **Bypass sharing for a single query**                           | `QRY_Builder.bypassSharing()`, which routes through `without sharing` for that query only. In USER_MODE the user's object and field permissions still apply.                                                                                                              | [Bypassing Sharing](#bypassing-sharing)                       |
| **USER_MODE enforcement per query**                             | `QRY_Builder.withUserMode()`, which enforces field-level security and object permissions at query time.                                                                                                                                                                                                     | [USER_MODE Security](#user_mode-security)                     |
| **Native Lightning Data Service caching in LWC**                | `@wire(getRecord)`, `@wire(getObjectInfo)`, `@wire(getRecordCreateDefaults)` from `lightning/uiRecordApi` / `lightning/uiObjectInfoApi`, used by framework components like `scheduledJobDetail`, `sObjectLookup`, `createForm`. No lint or scanner rule blocks them. | [LWC - Guide](LWC%20-%20Guide.md)                             |
| **Cacheable Apex bridge for LWC**                               | `@AuraEnabled(cacheable=true)` on a controller method, used in framework code like `CTRL_FeatureFlag`.                                                                                                                                                               | [LWC - Guide](LWC%20-%20Guide.md)                             |
| **Raw `Database.query()` / `Database.queryWithBinds()`**        | Works, but nothing intercepts platform SOQL: the read gets none of the checks, caching, logging or mocks above, and `KernNoInlineSOQL` flags it. Only for the same two causes as inline SOQL.                                                                          | —                                                             |

KernDX is opinionated here on purpose: its security, caching, logging and test mocks only reach the reads that go through a selector.

---

## Basic Queries

These examples assume a custom selector class `SEL_Accounts` extending [SEL_Base](reference/apex/SEL_Base.md):

```apex
public with sharing class SEL_Accounts extends SEL_Base
{
	public SEL_Accounts()
	{
		super(Account.SObjectType);
	}

	public override List<SObjectField> getFields()
	{
		return new List<SObjectField>
		{
			Account.Name,
			Account.Industry,
			Account.AnnualRevenue
		};
	}
}
```

### findById

Retrieve records by their Salesforce Id using [SEL_Base.findById](reference/apex/SEL_Base.md).

**Example:**

```apex
// Retrieves a single account by Id
Account account = (Account)new SEL_Accounts().findById(accountId);

// Retrieves multiple accounts by Ids
List<Account> accounts = new SEL_Accounts().findById(accountIds);
```

#### Adding a field for one read

When one read needs a field the defaults leave out, add it with one call on the selector's `query` property, a [QRY_Builder](reference/apex/QRY_Builder.md) that starts with the default fields:

```apex
Account account = (Account)new SEL_Accounts().query
	.addField(Account.Phone)
	.condition(Account.Id).equals(accountId)
	.getFirst();
```

### findByField

Retrieve records by any field value(s).

**Example:**

```apex
// Finds accounts by industry
List<Account> accounts = new SEL_Accounts().findByField(Account.Industry, 'Technology');
```

For more complex field-based queries, use the selector's `query` property, a [QRY_Builder](reference/apex/QRY_Builder.md) with the default fields already set:

```apex
// Finds accounts by multiple industries
List<Account> accounts = new SEL_Accounts().query
	.condition(Account.Industry).isIn(new List<String>{'Technology', 'Finance', 'Healthcare'})
	.toList();
```

---

## Custom Selector Classes

Create custom selector classes for each SObject by extending [SEL_Base](reference/apex/SEL_Base.md) to centralise and standardise queries.

**Pattern:**

```apex
/**
 * @description Selector for Contact queries.
 *
 * @see SEL_Contacts_TEST
 *
 * @author your.name@company.com
 *
 * @group Selectors
 *
 * @date January 2026
 */
public with sharing class SEL_Contacts extends SEL_Base
{
	public SEL_Contacts()
	{
		super(Contact.SObjectType);
	}

	/**
	 * @description Returns consistent minimal set of fields for Contact queries.
	 *
	 * @return List of Contact SObjectField tokens
	 */
	public override List<SObjectField> getFields()
	{
		return new List<SObjectField>
		{
			Contact.FirstName,
			Contact.LastName,
			Contact.Email,
			Contact.Phone,
			Contact.AccountId
		};
	}

	/**
	 * @description Finds active contacts for specific accounts.
	 *
	 * @param accountIds Set of account Ids to filter by
	 *
	 * @return List of active contacts
	 *
	 * @example
	 * ```apex
	 * List<Contact> contacts = new SEL_Contacts().findActiveByAccountIds(accountIds);
	 * ```
	 */
	public List<Contact> findActiveByAccountIds(Set<Id> accountIds)
	{
		return (List<Contact>)query
			.condition(Contact.AccountId).isIn(new List<Id>(accountIds))
			.andCondition(Contact.Active__c).equals(true)
			.orderBy(Contact.LastName).ascending()
			.toList();
	}
}
```

**Test Class Pattern:**

```apex
/**
 * @description Unit tests for SEL_Contacts.
 *
 * @see SEL_Contacts
 *
 * @author your.name@company.com
 *
 * @group Selectors
 *
 * @date January 2026
 */
@IsTest(seeAllData=false isParallel=true)
private class SEL_Contacts_TEST
{
	/**
	 * @description Tests finding active contacts by account Ids.
	 */
	@IsTest
	private static void shouldReturnActiveContactsForAccounts()
	{
		Account testAccount = (Account)TST_Builder.of(Account.SObjectType).build();

		Contact activeContact = (Contact)TST_Builder.of(Contact.SObjectType)
			.withOverrides(new Map<SObjectField, Object>
			{
				Contact.AccountId => testAccount.Id,
				Contact.Active__c => true,
				Contact.LastName => 'Smith'
			})
			.build();

		Contact inactiveContact = (Contact)TST_Builder.of(Contact.SObjectType)
			.withOverrides(new Map<SObjectField, Object>
			{
				Contact.AccountId => testAccount.Id,
				Contact.Active__c => false,
				Contact.LastName => 'Jones'
			})
			.build();

		Test.startTest();
		List<Contact> foundContacts = new SEL_Contacts().findActiveByAccountIds(
			new Set<Id>{testAccount.Id}
		);
		Test.stopTest();

		Assert.areEqual(1, foundContacts.size(), 'Should find only active contact');
		Assert.areEqual('Smith', foundContacts[0].LastName, 'Should find the active contact');
	}
}
```

---

## How does it work?

```text
┌─────────────────────────────────────────────────────────────────────────────┐
│                        SELECTOR FRAMEWORK ARCHITECTURE                        │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                               │
│   YOUR ORG'S CODE                                                             │
│   ===============                                                             │
│           │                                                                   │
│           ▼                                                                   │
│   ┌───────────────────────────────────────────────────────────────────────┐  │
│   │  SEL_Base (Production Pattern — reusable selectors)                    │  │
│   │  - Extend for custom selectors (SEL_Accounts, SEL_Contacts)          │  │
│   │  - Default fields, findById, findByField, custom query methods       │  │
│   └───────────────────────────────┬───────────────────────────────────────┘  │
│                                   │ uses `query` property                     │
│                                   ▼                                           │
│   ┌───────────────────────────────────────────────────────────────────────┐  │
│   │  QRY_Builder (Query Engine — runs every selector query)                │  │
│   │  - Chained calls: selectFrom().fields().condition().toList()          │  │
│   │  - Caching, pagination, result transformation                         │  │
│   └───────────────────────────────┬───────────────────────────────────────┘  │
│                                   │                                           │
│                                   ▼                                           │
│   ┌───────────────────────────────────────────────────────────────────────┐  │
│   │  QRY_Condition                                                        │  │
│   │  - Low-level condition builders and operators                         │  │
│   │  - AND/OR condition trees                                             │  │
│   └───────────────────────────────┬───────────────────────────────────────┘  │
│                                   │                                           │
│                                   ▼                                           │
│                        ┌─────────────────────┐                               │
│                        │   Database.query()  │                               │
│                        └─────────────────────┘                               │
│                                                                               │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

<a id="layer-1-qry-builder-the-engine-every-selector-runs-on"></a>
### Layer 1: [QRY_Builder](reference/apex/QRY_Builder.md) (the engine every selector runs on)

**What it does:** Lets you build and run a [SOQL query](https://developer.salesforce.com/docs/atlas.en-us.soql_sosl.meta/soql_sosl/sforce_api_calls_soql.htm) by chaining short, readable method calls instead of assembling a string by hand. It also handles result caching, paging through large result sets, and sharing enforcement (which records each user is allowed to see).

**When to Use:** Through your selector. A selector's `query` property hands you a `QRY_Builder.Builder` with the selector's default fields already set, so every method below is one you call on `query`. Calling `QRY_Builder.selectFrom()` yourself skips the selector's default fields, its cache settings and its system-mode setting.

**Key Features:**

**Field Selection:**

- `selectFrom()` - Entry point - specify SObject type to query
- `fields()` / `addFields()` - Define fields to retrieve (SObjectField or String)
- `addField()` - Add a single field
- `selectAllFields()` - Select all fields on object (use with caution)
- `fieldSet()` / `addFieldSet()` - Select fields from FieldSet
- `relatedField()` / `relatedFields()` - Add parent relationship fields
- `subselect()` - Add child relationship subquery

**WHERE Conditions:**

- `condition()` / `andCondition()` / `orCondition()` - Build WHERE conditions
- `addCondition()` - Explicit condition grouping for complex logic (accepts `OrCondition` / `AndCondition`)
- Operators: `equals()`, `notEquals()`, `greaterThan()`, `greaterThanOrEquals()`, `lessThan()`, `lessThanOrEquals()`
- Collection operators: `isIn()`, `notInSet()` (safe empty list handling), `isInStrict()`, `notInSetStrict()` (throws on empty)
- SObject operators: `isIn(List<SObject>)`, `isIn(List<SObject>, SObjectField)`, `notInSet(List<SObject>)`, `notInSet(List<SObject>, SObjectField)`, `equals(SObject)`,
  `notEquals(SObject)`
- Semi-join subqueries: `isIn(Builder)`, `notIn(Builder)`
- Null checks: `isNull()`, `isNotNull()`
- String matching: `contains()`, `startsWith()`, `endsWith()`
- Multi-picklist: `includes()`, `excludes()` (safe empty list handling), `includesStrict()`, `excludesStrict()` (throws on empty)

> **SQL Precedence:** AND binds tighter than OR. For example, `A AND B OR C AND D` produces `(A AND B) OR (C AND D)`. Use `addCondition()` with `QRY_Condition.OrCondition` /
`QRY_Condition.AndCondition` when you need explicit control over grouping.

**Aggregates & Grouping:**

- `sum()` / `avg()` / `min()` / `max()` / `count()` / `countDistinct()` - Aggregate functions (one aggregate per query)
- `sum(field, alias)` / `avg(field, alias)` / `min(field, alias)` / `max(field, alias)` / `count(field, alias)` / `countDistinct(field, alias)` - Aliased aggregates; each call adds one more selection, so a single query returns several aggregates and you read each back by its alias on the `AggregateRow` (see [Several aggregates in one query](#several-aggregates-in-one-query))
- `groupBy()` - Group by a field (`String` or `SObjectField`); call multiple times for multi-field grouping
- `havingSumOf()` / `havingAvgOf()` / `havingMinOf()` / `havingMaxOf()` / `havingCountOf()` / `havingCount()` - HAVING conditions

**Ordering & Limits:**

- `orderBy()` then `ascending()` / `descending()` / `nullsFirst()` / `nullsLast()` - Define sorting
- `orderBy(field, sortDescending)` / `orderBy(field, sortDescending, nullsLast)` - Dynamic sorting with booleans
- `orderByCount(field, sortDescending)` - Order grouped rows by COUNT of a field; pair with `withLimit()` to read the top N groups (see [Ranking groups by size](#ranking-groups-by-size))
- `withLimit()` / `withOffset()` - Control result sets

**Security & Performance:**

Two terms matter here, and two acronyms appear throughout:

| Term            | What it means                                                                                                                                                                      |
|-----------------|------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| **USER_MODE**   | The query runs with the current user's read/write permissions and record sharing enforced, so it only returns what that user is allowed to see.                                   |
| **SYSTEM_MODE** | The query skips the object and field permission checks only. Record sharing still follows the sharing keyword of the calling class, and `.bypassSharing()` is the separate setting for that. |
| **FLS**         | Field-level security: which fields a user may read or edit.                                                                                                                       |
| **CRUD**        | Object create/read/update/delete permissions.                                                                                                                                      |

- **Default access mode:** Your queries run in `AccessLevel.USER_MODE` by default (CRUD, FLS, and sharing enforced), controlled by the `UserModeQueries_Enabled` feature flag. The framework's own internal selectors opt into `AccessLevel.SYSTEM_MODE` by overriding the `systemModeRequired()` hook on `SEL_Base`.
  See [Security Guide: Safe by Default](Security%20-%20Guide.md#safe-by-default).
- `withUserMode()` - Force `AccessLevel.USER_MODE` (enforces CRUD, FLS, and sharing at DB level) regardless of flag state
- `withSystemMode()` - Force `AccessLevel.SYSTEM_MODE` (bypasses CRUD/FLS; typically paired with `.bypassSharing()` for framework-internal reads) regardless of flag state
- `stripInaccessible()` - Remove inaccessible fields from results after the query runs, in SYSTEM_MODE (in USER_MODE, the query fails if it selects a field the user cannot read)
- `withSharing()` - Enforce sharing via proxy class (changes something only in SYSTEM_MODE: USER_MODE always enforces sharing)
- `bypassSharing()` - Ignore sharing via proxy class. In USER_MODE the user's object and field permissions still apply: see [Bypassing Sharing](#bypassing-sharing)
- `withoutSecurity()` - Waives object and field permission checks and record sharing in one call
  (SYSTEM_MODE plus the sharing bypass); use `withSystemMode()` to keep the calling class's sharing
- `withCache(ttl)` / `withCache(scope, ttl)` - Cache this query's results, in memory for the transaction or in Platform Cache (see [Caching Queries](#caching-queries))
- `withoutCache()` - Read from the database, whatever caching the selector or an earlier call asked for

**Query Performance Logging:**

- `forcePerformanceLogging()` - Force logging this query regardless of threshold settings
- `logPerformanceIfSlowerThan(ms)` - Log if query exceeds custom threshold (overrides global setting)
- `suppressPerformanceLogging()` - Prevent performance logging for this query (use for high-frequency internal queries)

**Row Locking & Special Clauses:**

- `forUpdate()` / `forReference()` / `forView()` - Row locking
- `allRows()` - Include archived/deleted records
- `usingScope()` - Filter by visibility scope (MINE, MY_TERRITORY, TEAM, etc.)

**Execution & Results:**

- `toSoql()` - Generate SOQL string without executing
- `toList()` - Execute query and return results as List
- `getFirst()` - Get first matching record
- `count()` - Count matching records
- `exists()` - Check if any records exist (more efficient than count())
- `toQueryLocator()` - Get QueryLocator for batch processing
- `toCursor()` - Get Database.Cursor for efficient large dataset traversal (bypasses 2K OFFSET limit)

**Result Transformation:**

- `asMap()` - Convert results to Map<Id, SObject> keyed by record Id
- `asMapById(field)` / `asMapByString(field)` - Convert results to Map keyed by any Id or String field
- `asGroupedMapById(field)` / `asGroupedMapByString(field)` - Group records by any Id or String field (preserves duplicates)
- `asIdSet()` / `asIdList()` - Extract record Ids as Set or List
- `asValueSet()` - Extract field values as Set
- `isCached()` - Check if last results came from cache

**Extensibility:**

- Custom selectors via `SEL_Base` extension (the production pattern for reusable queries)

**Why every read goes through it, never inline SOQL:** inline SOQL skips all of these gains, and the `KernNoInlineSOQL`
scanner rule flags it. Besides the gains in [What is it, and what do you get?](#what-is-it-and-what-do-you-get) (type-checked field
references that catch typos at compile time, caching handled for you, security enforced the same way every time), the
engine picks cursor or OFFSET automatically for large datasets, chained calls cut repetitive boilerplate, and built-in
methods reshape results (to maps, sets, and so on). In your code you reach it through a selector's `query` property.

**Example:**

```apex
/**
 * @description Retrieves technology accounts with high revenue
 *
 * @param minimumRevenue Minimum annual revenue threshold
 *
 * @return List of matching Account records
 */
public static List<Account> findHighValueTechnologyAccounts(Decimal minimumRevenue)
{
	return QRY_Builder.selectFrom(Account.SObjectType)
		.fields(new List<SObjectField>{ Account.Name, Account.Industry, Account.AnnualRevenue })
		.condition(Account.Industry).equals('Technology')
		.andCondition(Account.AnnualRevenue).greaterThan(minimumRevenue)
		.orderBy(Account.AnnualRevenue).descending()
		.withLimit(100)
		.toList();
}
```

**Caching Example:**

```apex
/**
 * @description Retrieves frequently accessed account data with caching
 *
 * @param accountId Account Id to retrieve
 *
 * @return Account record with cached data
 */
public static Account findByIdCached(Id accountId)
{
	return (Account)QRY_Builder.selectFrom(Account.SObjectType)
		.fields(new List<SObjectField>{Account.Name, Account.Industry, Account.Phone})
		.condition(Account.Id).equals(accountId)
		.withSystemMode()
		.withSharing()
		.withCache(300) // Cache for 5 minutes
		.getFirst();
}
```

**Custom Selector Pattern (the production standard for reusable queries):**

```apex
/**
 * @description Selector for Contact queries with default fields and reusable methods.
 */
public with sharing class SEL_Contacts extends SEL_Base
{
	public SEL_Contacts()
	{
		super(Contact.SObjectType);
	}

	public override List<SObjectField> getFields()
	{
		return new List<SObjectField>
		{
			Contact.FirstName, Contact.LastName, Contact.Email, Contact.Phone, Contact.AccountId
		};
	}

	public List<Contact> findByAccountId(Id accountId)
	{
		return query.condition(Contact.AccountId).equals(accountId).toList();
	}
}

// Usage — default fields included automatically
List<Contact> contacts = new SEL_Contacts().findByAccountId(accountId);
Contact contact = (Contact)new SEL_Contacts().findById(contactId);
```

### Layer 2: [SEL_Base](reference/apex/SEL_Base.md)

**What it does:** Acts as the base class you extend to make a [selector](https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_enterprise_patterns_selector_layer.htm) for one object: a single class that knows that object's default fields and holds its reusable query methods.

**When to Use:** Extend `SEL_Base` for every object your code reads, so every query on it shares one default field set and gets the framework's security, caching, logging and test mocks.

**Key Features:**

- `findById()` - Query by record ID(s)
- `findByField()` - Query by any field value(s)
- `getFields()` - Override to define consistent field sets per object
- `cacheScope()` / `cacheTimeToLiveSeconds()` - Override to cache every list or record read the selector makes (see [Caching every read from a selector](#caching-every-read-from-a-selector))

**Example:** Uses the same `SEL_Accounts` structure shown in [Basic Queries](#basic-queries) above, with `findById()` and `findByField()` inherited from `SEL_Base`:

```apex
Account account = (Account)new SEL_Accounts().findById(accountId);
List<Account> accounts = new SEL_Accounts().findByField(Account.Industry, 'Technology');
```

### Layer 3: [QRY_Condition](reference/apex/QRY_Condition.md)

**What it does:** Holds the building blocks for [WHERE conditions](https://developer.salesforce.com/docs/atlas.en-us.soql_sosl.meta/soql_sosl/sforce_api_calls_soql_select_conditionexpression.htm): the operators and field comparisons that make up a filter.

**When to Use:** Reach for it when you need to build complex filter logic by hand for a [QRY_Builder](reference/apex/QRY_Builder.md) query or a [SEL_Base](reference/apex/SEL_Base.md) selector, for example grouping several OR conditions inside an AND.

**Key Features:**

- `FieldCondition` built from a field, a `QRY_Condition.Operator` value (`EQUALS`, `NOT_EQUALS`, `GREATER_THAN`, `LESS_THAN`, `LIKE_X` and friends), and a comparison value
- `FieldCondition` built from just the field, completed with `contains()` for a text match anywhere in the field (the wildcards are handled for you), or with `containsLiteral()` when the text came from a search box and should match exactly as typed
- Nestable conditions: `AndCondition`, `OrCondition`
- `OrderBy` for sorting specifications

**Example:**

```apex
/**
 * @description Creates complex OR condition for account search
 *
 * @param industry Industry value
 * @param type Account type value
 *
 * @return OrCondition combining multiple criteria
 *
 * @example
 * ```apex
 * QRY_Condition.OrCondition condition = buildAccountCondition('Technology', 'Customer');
 * ```
 */
public static QRY_Condition.OrCondition buildAccountCondition(String industry, String type)
{
	QRY_Condition.OrCondition orCondition = new QRY_Condition.OrCondition();
	orCondition.add(new QRY_Condition.FieldCondition(Account.Industry, QRY_Condition.Operator.EQUALS, industry));
	orCondition.add(new QRY_Condition.FieldCondition(Account.Type, QRY_Condition.Operator.EQUALS, type));
	return orCondition;
}
```

For a contains-style text match, construct the `FieldCondition` with only the field and complete it with `contains()`, which wraps your value in leading and trailing `%` wildcards so you never assemble `'%' + value + '%'` patterns by hand:

```apex
// Name LIKE '%Acme%' OR Website LIKE '%acme%'
QRY_Condition.OrCondition textMatch = new QRY_Condition.OrCondition();
textMatch.add(new QRY_Condition.FieldCondition(Account.Name).contains('Acme'));
textMatch.add(new QRY_Condition.FieldCondition(Account.Website).contains('acme'));
```

#### Searching for text a person typed

`contains()` leaves three characters their special search meaning:

| Character | Meaning in `contains()`               |
|-----------|---------------------------------------|
| `%`       | Any run of characters                 |
| `_`       | Any single character                  |
| `\`       | The next character is ordinary        |

That is what you want when the pattern is yours. It is rarely what you want when the text came from a person: someone searching for `100%` matches every record containing `100`, and someone searching for `UTIL_HttpClient` also matches `UTILxHttpClient`.

`containsLiteral()` is the same match with those three characters taken at face value, so the search finds the text as typed:

```apex
// Finds the text "100%" itself, not every record containing "100"
QRY_Condition.OrCondition userSearch = new QRY_Condition.OrCondition();
userSearch.add(new QRY_Condition.FieldCondition(Account.Name).containsLiteral(searchBoxValue));
userSearch.add(new QRY_Condition.FieldCondition(Account.Website).containsLiteral(searchBoxValue));
```

Use `contains()` when you wrote the pattern and want the wildcards. Use `containsLiteral()` for anything a person typed: a search box, a filter, a report parameter.

---

## Advanced Queries

### Complex WHERE Conditions

Combine multiple conditions using AND/OR logic with [QRY_Builder](reference/apex/QRY_Builder.md).

**Example:**

```apex
/**
 * @description Finds accounts matching complex business criteria
 *
 * @param industries Set of industries to include
 * @param minimumAnnualRevenue Minimum annual revenue
 * @param types Set of account types to include
 *
 * @return List of matching accounts
 *
 * @example
 * ```apex
 * Set<String> industries = new Set<String>{'Technology', 'Finance'};
 * Set<String> types = new Set<String>{'Customer', 'Partner'};
 * List<Account> accounts = findByComplexCriteria(industries, 1000000, types);
 * ```
 */
public static List<Account> findByComplexCriteria(Set<String> industries, Decimal minimumAnnualRevenue, Set<String> types)
{
	return QRY_Builder.selectFrom(Account.SObjectType)
		.fields(new List<SObjectField>{ Account.Name, Account.Industry, Account.Type, Account.AnnualRevenue })
		.condition(Account.Industry).isIn(new List<String>(industries))
		.andCondition(Account.AnnualRevenue).greaterThanOrEquals(minimumAnnualRevenue)
		.orCondition(Account.Type).isIn(new List<String>(types))
		.toList();
}
```

### ORDER BY and LIMIT

Sort and limit query results.

**Example:**
```apex
/**
 * @description Gets top N accounts by revenue
 *
 * @param topN Number of accounts to return
 *
 * @return List of top N accounts by revenue
 *
 * @example
 * ```apex
 * List<Account> topAccounts = getTopAccountsByRevenue(10);
 * ```
 */
public static List<Account> getTopAccountsByRevenue(Integer topN)
{
	return QRY_Builder.selectFrom(Account.SObjectType)
		.fields(new List<SObjectField>{ Account.Name, Account.AnnualRevenue, Account.Industry })
		.condition(Account.AnnualRevenue).isNotNull()
		.orderBy(Account.AnnualRevenue).descending()
		.withLimit(topN)
		.toList();
}
```

**Dynamic sorting:** when the sort direction comes from a variable (for example, a user clicking a column header), use the boolean overloads to avoid `if/else` blocks:

```apex
public static List<Account> getAccountsSorted(SObjectField sortField, Boolean sortDescending)
{
	return QRY_Builder.selectFrom(Account.SObjectType)
		.fields(new List<SObjectField>{Account.Name, Account.AnnualRevenue})
		.orderBy(sortField, sortDescending)
		.toList();
}
```

The three-parameter variant also controls nulls placement:

```apex
.orderBy(Account.AnnualRevenue, true, true)  // DESC NULLS LAST
```

Both `SObjectField` and `String` field name variants are available. The `String` variant of `orderBy(field, sortDescending)` takes a field name, or a list of sort items whose last item has no direction and no nulls order: write `orderBy('Name', true)`, never `orderBy('Name DESC', true)`, because the method adds the direction itself.

Salesforce does not accept `toLabel()` inside ORDER BY, so you cannot sort by the translated label of a picklist value. Sort by the field itself.

### Field names from a page or a user

Values you pass to a query, such as the text in `.equals(searchText)`, are always sent as bind variables or escaped. A bind variable is a value sent beside the query text, never inside it. An escaped value has its quote marks made harmless. So a value cannot change a query.

Field names are different, because a field name is part of the query text. A method that takes a field name as text for a condition, a sort or a grouping (`condition`, `andCondition`, `orCondition`, `orderBy` and `groupBy`) accepts only these:

- a field API name, such as `Name`;
- a path through a lookup to a related record's field, such as `Account.Owner.Name`;
- a date or distance expression of the kind `QRY_Function` writes, such as `CALENDAR_YEAR(CloseDate)`. In a distance
  expression, a space after a comma is fine and a space before a comma is refused: `DISTANCE(Location__c, GEOLOCATION(37.77, -122.41), 'mi')`
  is accepted, and `DISTANCE(Location__c , GEOLOCATION(37.77 , -122.41) , 'mi')` is not;
- where SOQL allows it, an aggregate such as `SUM(Amount)`, or `toLabel()`, around a field name;
- in a sort, any of these followed by `ASC` or `DESC`, and by `NULLS FIRST` or `NULLS LAST`;
- for `orderBy` and `groupBy`, a list of those, joined by commas.

Methods that take one name, such as `count`, `relatedField` and `subselect`, accept a field name or a path only. Any other text makes the method throw an `IllegalArgumentException` before a query runs.

The check stops text from changing the shape of the query. It does not check who may see the field: a real field name that the running user may not see is still a real field name. This matters most in system mode, where the query skips the user's field permissions.

So never let a page or a user choose a field by its name. Instead:

- Pass fields as field tokens, such as `Account.Name` (an `SObjectField`, which Apex checks when it compiles your code), or as constants you wrote.
- Map a page's choice to a field through a list of the fields you allow, and fall back to a default field when the choice is not on the list.

The same rule holds for the fields you select with `fields()` and `addField()`:

```apex
private static final Map<String, SObjectField> ALLOWED_SORT_FIELDS = new Map<String, SObjectField>
{
	'name' => Account.Name,
	'industry' => Account.Industry,
	'revenue' => Account.AnnualRevenue
};

public static List<Account> getAccountsSortedBy(String sortColumn, Boolean sortDescending)
{
	return QRY_Builder.selectFrom(Account.SObjectType)
		.fields(new List<SObjectField>{Account.Name, Account.Industry, Account.AnnualRevenue})
		.orderBy(ALLOWED_SORT_FIELDS.get(sortColumn) ?? Account.Name, sortDescending)
		.toList();
}
```

The page sends `revenue`, not `AnnualRevenue`. A column name that is not on the list sorts by `Account.Name`.

On an object that comes with KernDX (its API name starts with `kern__`), a field of yours with the same name as a
package field, such as your `Status__c` beside the package's `kern__Status__c`, cannot be read through a selector or
the query builder, by name or by token: the query reads the package's field, and no error tells you. Give your field
another name.

### Pagination

Implement efficient [pagination](https://developer.salesforce.com/docs/atlas.en-us.soql_sosl.meta/soql_sosl/sforce_api_calls_soql_select_offset.htm) for large result sets.

**Example:**

```apex
/**
 * @description Retrieves a paginated list of contacts
 *
 * @param pageNumber Page number (1-based)
 * @param pageSize Records per page
 *
 * @return QueryPage with results and pagination metadata
 *
 * @example
 * ```apex
 * QRY_Builder.QueryPage page1 = getPaginatedContacts(1, 25);
 * ```
 */
public static QRY_Builder.QueryPage getPaginatedContacts(Integer pageNumber, Integer pageSize)
{
	return QRY_Builder.selectFrom(Contact.SObjectType)
		.fields(new List<SObjectField>{ Contact.FirstName, Contact.LastName, Contact.Email, Contact.Phone })
		.orderBy(Contact.LastName).ascending()
		.getPage(pageNumber, pageSize);
}
```

---

## Query Builder

[QRY_Builder](reference/apex/QRY_Builder.md) is the engine under every selector: configure a query with short chained calls, then one call runs it. In your code you reach it through a selector's `query` property. The examples below start from `QRY_Builder.selectFrom()` only so that each one shows the whole query.

You get control over sharing enforcement (which records each user can
see) and field-level security options, paging through large result sets, caching and result reshaping, all in chained,
readable syntax.

### SELECT and FROM

Build a query with short chained calls, then one call runs it and returns the result.

**Example:**
```apex
// Simple SELECT query
List<Account> accounts = QRY_Builder.selectFrom(Account.SObjectType)
	.fields(new List<SObjectField>{ Account.Name, Account.Industry, Account.Phone })
	.toList();
```

### WHERE Conditions

Add filtering to queries.

**Example:**

```apex
// Query with WHERE clause
List<Account> accounts = QRY_Builder.selectFrom(Account.SObjectType)
	.fields(new List<SObjectField>{ Account.Name, Account.AnnualRevenue })
	.condition(Account.Industry).equals('Technology')
	.andCondition(Account.AnnualRevenue).greaterThan(1000000)
	.toList();
```

### Aggregate Functions

Use COUNT, SUM, AVG, MIN, MAX with [QRY_Builder](reference/apex/QRY_Builder.md).

**Example:**

```apex
// Count accounts by industry
List<QRY_Builder.AggregateRow> results = QRY_Builder.selectFrom(Account.SObjectType)
	.count('Id')
	.groupBy(Account.Industry)
	.toAggregateList();
```

#### Several aggregates in one query

The single-argument overloads above apply one aggregate per query. To fold several aggregates into one query, use the aliased overloads: pass the field plus a result alias, and each call adds one more selection. Read each value back by its alias on the `AggregateRow`:

```apex
// Count rows and find the earliest record per stage, in one query
List<QRY_Builder.AggregateRow> rows = QRY_Builder.selectFrom(Opportunity.SObjectType)
	.groupBy(Opportunity.StageName)
	.count(Opportunity.Id, 'rowTotal')
	.min(Opportunity.CreatedDate, 'firstSeen')
	.toAggregateList();

for(QRY_Builder.AggregateRow row : rows)
{
	Object total = row.get('rowTotal');
	Object earliest = row.get('firstSeen');
}
```

The alias must be a bare identifier (a letter followed by letters, digits or underscores); anything else fails fast with an `IllegalArgumentException`, and a duplicate alias is rejected when the query builds. All six aggregate functions have an aliased form: `count()`, `countDistinct()`, `sum()`, `avg()`, `min()` and `max()`.

A single-argument aggregate gets a default alias, `<function>_<field API name>`: `.sum(Opportunity.Amount)` is read back with `row.getDecimal('sum_Amount')`, and `.count('Id')` with `row.getInteger('count_Id')`. In a namespaced package the field API name in the alias carries its namespace prefix.

#### Ranking groups by size

`orderByCount()` orders the grouped rows by how many records each group holds (the SOQL `ORDER BY COUNT(field)` form). Combine it with `withLimit()` to read the top N groups:

```apex
// The three stages holding the most opportunities
List<QRY_Builder.AggregateRow> topStages = QRY_Builder.selectFrom(Opportunity.SObjectType)
	.groupBy(Opportunity.StageName)
	.count(Opportunity.Id, 'rowTotal')
	.orderByCount(Opportunity.Id, true)
	.withLimit(3)
	.toAggregateList();
```

Passing `true` sorts descending (largest groups first); `false` sorts ascending.

### GROUP BY

Group aggregated results.

**Example:**

```apex
/**
 * @description Calculates total revenue by industry
 *
 * @return List of AggregateRow with total revenue per industry
 */
public static List<QRY_Builder.AggregateRow> getTotalRevenueByIndustry()
{
	return QRY_Builder.selectFrom(Account.SObjectType)
		.sum(Account.AnnualRevenue)
		.groupBy(Account.Industry)
		.orderBy('Industry').ascending()
		.toAggregateList();
}
```

### Aggregate Queries

Perform aggregations with [GROUP BY](https://developer.salesforce.com/docs/atlas.en-us.soql_sosl.meta/soql_sosl/sforce_api_calls_soql_select_groupby.htm), and keep only the groups that pass a HAVING filter (here
`havingSumOf(...)`).

**Example:**

```apex
/**
 * @description Gets total revenue by industry with filtering
 *
 * @param minimumTotalRevenue Minimum total revenue threshold
 *
 * @return List of AggregateRow with industry and total revenue
 */
public static List<QRY_Builder.AggregateRow> getTotalRevenueByIndustry(Decimal minimumTotalRevenue)
{
	return QRY_Builder.selectFrom(Account.SObjectType)
		.sum(Account.AnnualRevenue)
		.groupBy(Account.Industry)
		.havingSumOf(Account.AnnualRevenue).greaterThan(minimumTotalRevenue)
		.orderBy('Industry').ascending()
		.toAggregateList();
}
```

### Multi-Field Grouping

Call `.groupBy()` multiple times for multi-dimensional aggregation (max 3 fields per SOQL spec):

```apex
List<QRY_Builder.AggregateRow> results = QRY_Builder.selectFrom(Opportunity.SObjectType)
	.groupBy(Opportunity.StageName)
	.groupBy('CALENDAR_YEAR(CloseDate)')
	.sum(Opportunity.Amount)
	.toAggregateList();
```

The same idea as a method you can call: group accounts by industry and by type, and keep only the groups with a count
above 5:

```apex
/**
 * @description Counts accounts by industry and type
 *
 * @return List of AggregateRow grouped by industry and type
 */
public static List<QRY_Builder.AggregateRow> countAccountsByIndustryAndType()
{
	return QRY_Builder.selectFrom(Account.SObjectType)
		.count('Id')
		.groupBy(Account.Industry)
		.groupBy(Account.Type)
		.havingCount().greaterThan(5)
		.toAggregateList();
}
```

#### GROUP BY ROLLUP (Subtotals)

Add `.rollup()` to generate subtotals at each grouping level. Use `.grouping(field)` to distinguish subtotal rows
(returns 1) from data rows (returns 0):

```apex
List<QRY_Builder.AggregateRow> results = QRY_Builder.selectFrom(Opportunity.SObjectType)
	.groupBy(Opportunity.StageName)
	.groupBy(Opportunity.LeadSource)
	.grouping(Opportunity.StageName)
	.grouping(Opportunity.LeadSource)
	.sum(Opportunity.Amount)
	.rollup()
	.toAggregateList();
```

#### GROUP BY CUBE (Cross-Tabulation)

Add `.cube()` for all possible dimension combinations:

```apex
List<QRY_Builder.AggregateRow> results = QRY_Builder.selectFrom(Opportunity.SObjectType)
	.groupBy(Opportunity.StageName)
	.groupBy(Opportunity.LeadSource)
	.sum(Opportunity.Amount)
	.cube()
	.toAggregateList();
```

---

## Sharing Enforcement

By default, queries run in USER_MODE (the current user's permissions and sharing enforced), driven by the `UserModeQueries_Enabled` feature flag, which ships with `IsEnabledByDefault__c=true`.

You often need to decide whether a query should respect the org's sharing rules (which records each user is allowed to see) or read past them for a system task. The framework gives you that [control](https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_classes_keywords_sharing.htm), and the security options on [QRY_Builder](reference/apex/QRY_Builder.md) can be combined.

| Method                 | Effect                                                                                                                        | When to Use                                                                                 |
|------------------------|-------------------------------------------------------------------------------------------------------------------------------|---------------------------------------------------------------------------------------------|
| `.withUserMode()`      | Explicitly runs in USER_MODE (the shipped default)                                                                            | Your code that must enforce the running user's permissions                                  |
| `.withSystemMode()`    | Runs in SYSTEM_MODE, skipping the CRUD and FLS checks. **Sharing is not affected** (see the note below)                       | Framework-internal reads of configuration or audit data; rare in your own code              |
| `.stripInaccessible()` | Removes inaccessible fields from results after the query runs, in SYSTEM_MODE. In USER_MODE, the query fails if it selects a field the user cannot read | With `.withSystemMode()`, when you want rows back without the hidden fields rather than an error |
| `.withSharing()`       | Uses `with sharing` proxy class (SYSTEM_MODE only: USER_MODE enforces sharing anyway)                                         | Enforce sharing while bypassing CRUD/FLS                                                    |
| `.bypassSharing()`     | Uses `without sharing` proxy class. In USER_MODE the object and field checks still apply and hidden fields are removed        | Read records whatever their sharing (use with caution)                                      |
| `.withoutSecurity()`   | Waives object and field checks AND record sharing in one call (SYSTEM_MODE plus the sharing bypass); ignores the flag default | System-level reads that must span every record; audited as both a mode and a sharing bypass |

> **SYSTEM_MODE does not bypass sharing.** `withSystemMode()` sets aside object and field permission checks only.
>
> - Record sharing keeps following the sharing keyword of the class your query runs in, because `QRY_Builder` and `SEL_Base` both inherit sharing from their caller.
> - To read past sharing as well, add `.bypassSharing()`. To waive all three in one call, use `.withoutSecurity()`.
> - A `with sharing` class that calls `.withSystemMode()` on its own gets **zero rows** for a record the running user cannot see through sharing, and no exception either. Nothing downstream can tell that result from a legitimately empty one.

### What does each setting return?

Take a selector declared `with sharing`, reading a record on a custom object whose
org-wide default is Private, running as a user who has neither a share on that record nor read permission on the object:

| Setting                             | What that user gets                                                               |
|-------------------------------------|-----------------------------------------------------------------------------------|
| Neither (the USER_MODE default)     | `QueryException: sObject type '...' is not supported`, a loud and correct refusal |
| `.withSystemMode()` on its own      | **Zero rows, and no exception**                                                   |
| `.bypassSharing()` on its own       | A `QueryException` before any query runs: the user cannot read the object, and the bypass keeps that check |
| `.withSystemMode().bypassSharing()` | The record, which is the right answer for a system read                           |

The table shows four separate cases side by side, not four steps on one scale from strict to open. The first two rows fail for unrelated reasons:

- Row 1 is USER_MODE refusing the query because the user has no permission on the object.
- Row 2 is the sharing filter quietly dropping the record. It is the one that fails silently, which makes it the one nobody thinks to test.

Row 3 ignores sharing but keeps the object check, so it refuses the read as row 1 does.

Cover both halves in your own test suite: a `.withSystemMode()` read run as a user without a share must come back empty from
`toList()`, and adding `.bypassSharing()` must return the rows.

### Enforcing Sharing

```apex
/**
 * @description Queries contacts with sharing enforced via withSharing() proxy
 *
 * @param accountIds Account Ids to filter by
 *
 * @return List of contacts respecting user's sharing rules
 */
public static List<Contact> findContactsWithSharing(Set<Id> accountIds)
{
	return QRY_Builder.selectFrom(Contact.SObjectType)
		.fields(new List<SObjectField>{ Contact.FirstName, Contact.LastName, Contact.Email })
		.condition(Contact.AccountId).isIn(new List<Id>(accountIds))
		.withSharing()
		.toList();
}
```

### Bypassing Sharing

```apex
/**
 * @description Queries all contacts regardless of sharing rules
 * WARNING: Allows access to records the user normally cannot see.
 * The user's object and field permissions still apply: fields the user cannot read are removed.
 *
 * @param accountIds Account Ids to filter by
 *
 * @return All matching contacts, whatever their sharing
 */
public static List<Contact> findAllContactsWithoutSharing(Set<Id> accountIds)
{
	return QRY_Builder.selectFrom(Contact.SObjectType)
		.fields(new List<SObjectField>{ Contact.FirstName, Contact.LastName, Contact.Email })
		.condition(Contact.AccountId).isIn(new List<Id>(accountIds))
		.bypassSharing()
		.toList();
}
```

**Note:** `withUserMode()` (and the USER_MODE default) already enforces sharing at the database level. So in USER_MODE, `withSharing()` has no effect on its own. It matters in two cases: after `bypassSharing()`, where it cancels the bypass, and after `withSystemMode()`. `bypassSharing()` does take effect in USER_MODE: it ignores sharing and keeps the user's object and field permissions.

- A hidden field is removed from the rows and not reported when it is a field of the queried object, or the last field of a path whose lookups and parent objects the user can read, such as `Phone` in `Account.Phone`. This holds in child rows and in rows taken from the query cache too.
- The read is refused, before any query runs, when it selects a path through a lookup or a parent object the user cannot read. This holds wherever the path comes from: `fields()`, `relatedField()`, a field set, a selector's default fields, a child query, or inside a function such as `toLabel()`.
  - A hidden lookup, such as `What.Name` without read on `WhatId`, gives `UTIL_Exceptions.IllegalStateException` (label `QueryBuilder_BypassSharingLookup_NotReadable`).
  - A hidden parent object, such as `Account.Name` on a contact for a user who cannot read accounts, gives a `QueryException` that names the object.
  - A `TYPEOF` needs read on its lookup and on each object after `WHEN`.
- The read is refused when a child query added with `subselect()` goes through a lookup the user cannot read, such as `WhatId` for the `Events` of an account, even when it selects only `Id`. The child query is checked as the object its relationship reads.
- Selected text the builder cannot check is refused with `UTIL_Exceptions.IllegalStateException` (label `QueryBuilder_BypassSharingSelectedText_NotCheckable`), even for a user who can read everything. Add a child query with `subselect()`, never as text, and write each `TYPEOF` as a field of its own: `TYPEOF What WHEN Account THEN Name, Phone ELSE Name END`.
- The read is refused before any query runs, with a `QueryException`, when the user cannot read the object (or the object of a child query, or of a query inside `isIn()` or `notIn()`).
- The read is refused before any query runs, with `UTIL_Exceptions.IllegalStateException`, when a filter or a sort you build with the builder (`condition(...)`, `orderBy(...)`) uses a field the user cannot read.
- `toQueryLocator()`, `toCursor()`, `toAggregateList()`, `getFirstAggregate()` and any read of a grouped query (`count()` included) are refused with `UTIL_Exceptions.IllegalStateException`, because KernDX cannot remove hidden fields from them. Add `withSystemMode()` to such a read; it also turns off the object and field checks.
- `getPage()` returns the page without hidden fields and with `page.cursor` set to null. Ask for each later page with `getPage()`.
- `count()` and `exists()` read no fields and no child rows, so the checks on selected fields and on a child query's lookup do not apply to them. They still check a child query's object, as the object its relationship reads, and its filters and sorts.

The filter and sort check also looks inside functions and through parent records, in the main query and in every inner query:

- **Functions.** A field inside a date function such as `CALENDAR_YEAR(CloseDate)` (with or without `convertTimezone()` inside it), `toLabel()` or `DISTANCE()` is checked. This works whether you write the function as text or build it with `QRY_Function`.
- **Parent paths.** A path such as `Account.Owner.Email` is checked up to five parents deep. If the user cannot read a parent object on the path, the read is refused with a `QueryException` that names the object. If the user cannot read a lookup on the path or the last field, the read is refused with `UTIL_Exceptions.IllegalStateException` that names the path.
- **Lookups to more than one object.** A lookup such as `What` (Related To on a task or event), `Who` (Name) or `Owner` is read through a shared Name record, as a USER_MODE query reads it. The Name record is one Salesforce record (the `Name` object) that stands for the related record, whatever its object. It holds only a few values, such as the record's name and its type. A filter, a sort or a selected field through it, such as `What.Name`, needs read on the lookup field (`WhatId`) only, not on the objects it can point to.
  - For some users Salesforce hides the Name record's `ProfileId`, `UserRoleId` and `RecordTypeId`. For them a filter or sort on those fields, such as `What.ProfileId`, and a path through them, such as `Owner.Profile.Name` or `What.RecordType.Name`, is refused.
  - Because the read ignores sharing, it covers every record of the queried object in the org: for `What` and `Who`, every task and event. It can return the name of the related record, or find a row by that name, even when the user cannot open that record or read its object. For a person that includes the first and last name, and for a lead the company.

A filter you write in your own `QRY_Condition.Evaluable` is not checked. Its rows can still show something about a field the user cannot read, so do not filter on such a field that way with `bypassSharing()`.

When a read is refused because of a selected path or a child query, give the user read access to the lookup field or the parent object, or take the related fields (or the child query) out of the read. Or add `withSystemMode()`, which also turns off the object and field checks for that read.

### USER_MODE Security

When a query must respect everything the running user is allowed to do, call `.withUserMode()`. It enforces [object permissions, field-level security, and sharing](https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_classes_enforce_usermode.htm) right at the database:

```apex
/**
 * @description Queries accounts with full security enforcement via USER_MODE
 *
 * @return List of accounts (throws exception if user lacks object READ access)
 */
public static List<Account> findAccountsWithSecurity()
{
	return QRY_Builder.selectFrom(Account.SObjectType)
		.fields(new List<SObjectField>{ Account.Name, Account.Industry, Account.AnnualRevenue })
		.withUserMode()
		.toList();
}
```

### Strip Inaccessible Fields

The strip runs after the query, so the query must run in SYSTEM_MODE: in USER_MODE the platform refuses a selected field the user cannot read before the strip can run. SYSTEM_MODE does not check the object permission, so keep sharing with `.withSharing()` and use this only for an object the user may read.

```apex
// Removes inaccessible fields from results post-query
List<Account> accounts = QRY_Builder.selectFrom(Account.SObjectType)
	.fields(new List<SObjectField>{ Account.Name, Account.Industry, Account.AnnualRevenue })
	.withSystemMode()
	.withSharing()
	.stripInaccessible()
	.toList();
```

---

## Complex Examples

### Parent-to-Child Subqueries

Query parent records with related child records using [QRY_Builder.subselect()](reference/apex/QRY_Builder.md).

**Example:**

```apex
/**
 * @description Queries accounts with their contacts
 *
 * @param accountIds Set of account Ids
 *
 * @return List of accounts with nested contact data
 */
public static List<Account> getAccountsWithContacts(Set<Id> accountIds)
{
	QRY_Builder.Builder contactSubquery = QRY_Builder.selectFrom(Contact.SObjectType)
		.fields(new List<SObjectField>{ Contact.FirstName, Contact.LastName, Contact.Email });

	return QRY_Builder.selectFrom(Account.SObjectType)
		.fields(new List<SObjectField>{ Account.Name, Account.Industry })
		.subselect(contactSubquery, 'Contacts')
		.condition(Account.Id).isIn(new List<Id>(accountIds))
		.toList();
}
```

### Semi-Join Subqueries

Sometimes you want to filter one query by the results of another, for example "users who appear in this permission-set query" or "accounts that do not appear in this contacts query". Pass one builder into `isIn(Builder)` or `notIn(Builder)` to do that in a single query (in SOQL this is called a [semi-join](https://developer.salesforce.com/docs/atlas.en-us.soql_sosl.meta/soql_sosl/sforce_api_calls_soql_select_semi_join.htm)).

**Semi-Join (IN subquery):**

```apex
/**
 * @description Finds users assigned to specific permission sets
 *
 * @param permissionSetNames Set of permission set names
 *
 * @return List of matching users
 */
public static List<User> findUsersWithPermissionSets(Set<String> permissionSetNames)
{
	QRY_Builder.Builder subquery = QRY_Builder.selectFrom(PermissionSetAssignment.SObjectType)
		.fields(new List<SObjectField>{ PermissionSetAssignment.AssigneeId })
		.condition('PermissionSet.Name').isIn(new List<String>(permissionSetNames));

	return QRY_Builder.selectFrom(User.SObjectType)
		.fields(new List<SObjectField>{ User.Name, User.Email })
		.condition(User.IsActive).equals(true)
		.condition('Id').isIn(subquery)
		.toList();
}
```

**Anti-Join Pattern (NOT IN):**

```apex
/**
 * @description Finds accounts without any contacts
 *
 * @return List of accounts without contacts
 */
public static List<Account> findAccountsWithoutContacts()
{
	QRY_Builder.Builder contactSubquery = QRY_Builder.selectFrom(Contact.SObjectType)
		.fields(new List<SObjectField>{ Contact.AccountId })
		.condition(Contact.AccountId).isNotNull();

	return QRY_Builder.selectFrom(Account.SObjectType)
		.fields(new List<SObjectField>{ Account.Name, Account.Industry })
		.condition('Id').notIn(contactSubquery)
		.toList();
}
```

> **Nested Semi-Joins:** Nested semi-joins are not supported. Salesforce does not allow a semi-join subquery inside another semi-join subquery, so a subquery passed to `isIn()` cannot itself contain an `isIn()` condition with a subquery.

### QueryLocator for Batch Apex

Get a [QueryLocator](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Database_QueryLocator.htm) for batch processing.

**Example:**

```apex
/**
 * @description Batch class to process accounts
 */
public with sharing class BATCH_ProcessAccounts implements Database.Batchable<SObject>
{
	/**
	 * @description Returns QueryLocator for batch processing
	 *
	 * @param context Batch context
	 *
	 * @return Database.QueryLocator for accounts to process
	 */
	public Database.QueryLocator start(Database.BatchableContext context)
	{
		return QRY_Builder.selectFrom(Account.SObjectType)
			.fields(new List<SObjectField>{Account.Name, Account.Industry, Account.AnnualRevenue, Account.OwnerId})
			.condition(Account.Type).equals('Customer')
			.andCondition(Account.AnnualRevenue).greaterThan(1000000)
			.toQueryLocator();
	}

	/**
	 * @description Processes each batch of accounts
	 *
	 * @param context Batch context
	 * @param accounts List of accounts in this batch
	 */
	public void execute(Database.BatchableContext context, List<Account> accounts)
	{
		for(Account account : accounts)
		{
			// Business logic here
		}
	}

	/**
	 * @description Completes batch processing
	 *
	 * @param context Batch context
	 */
	public void finish(Database.BatchableContext context)
	{
		LOG_Builder.build().info('Batch complete').emitAt('MyBatch.finish');
	}
}
```

---

## QRY_Builder Examples

### Basic Queries

#### Simple Field Selection

```apex
/**
 * @description Retrieves accounts with basic field selection
 *
 * @return List of Account records
 */
public static List<Account> getBasicAccounts()
{
	return QRY_Builder.selectFrom(Account.SObjectType)
		.fields(new List<SObjectField>{ Account.Name, Account.Industry, Account.Phone, Account.Website })
		.orderBy(Account.Name).ascending()
		.toList();
}
```

#### Query with Single Condition

```apex
/**
 * @description Finds accounts by industry
 *
 * @param industry The industry to filter by
 *
 * @return List of matching accounts
 */
public static List<Account> findByIndustry(String industry)
{
	return QRY_Builder.selectFrom(Account.SObjectType)
		.addFields(new List<SObjectField>{Account.Name, Account.Industry, Account.AnnualRevenue})
		.condition(Account.Industry).equals(industry)
		.orderBy(Account.Name).ascending()
		.toList();
}
```

#### Query with Multiple AND Conditions

```apex
/**
 * @description Finds high-value technology accounts
 *
 * @param minimumRevenue Minimum annual revenue threshold
 *
 * @return List of matching accounts
 */
public static List<Account> findHighValueTechAccounts(Decimal minimumRevenue)
{
	return QRY_Builder.selectFrom(Account.SObjectType)
		.fields(new List<SObjectField>{ Account.Name, Account.Industry, Account.AnnualRevenue, Account.Type })
		.condition(Account.Industry).equals('Technology')
		.andCondition(Account.AnnualRevenue).greaterThanOrEquals(minimumRevenue)
		.andCondition(Account.Type).equals('Customer')
		.orderBy(Account.AnnualRevenue).descending()
		.withLimit(100)
		.toList();
}
```

#### Query with OR Conditions

```apex
/**
 * @description Finds accounts in multiple industries
 *
 * @return List of accounts in technology or finance industries
 */
public static List<Account> findTechOrFinanceAccounts()
{
	return QRY_Builder.selectFrom(Account.SObjectType)
		.fields(new List<SObjectField>{ Account.Name, Account.Industry, Account.AnnualRevenue })
		.condition(Account.Industry).equals('Technology')
		.orCondition(Account.Industry).equals('Finance')
		.orderBy(Account.Name).ascending()
		.toList();
}
```

#### Explicit Condition Grouping

When you need exact control over how AND and OR group together, build the group yourself with `QRY_Condition.OrCondition` or `QRY_Condition.AndCondition` and pass it to `addCondition()`:

```apex
/**
 * @description Finds tech accounts that are either active or pending.
 * Demonstrates explicit grouping: Industry = 'Technology' AND (Status = 'Active' OR Status = 'Pending')
 *
 * @return List of matching accounts
 */
public static List<Account> findActiveTechAccounts()
{
	// Build the OR group for status
	QRY_Condition.OrCondition statusGroup = new QRY_Condition.OrCondition();
	statusGroup.add(new QRY_Condition.FieldCondition('Status__c', QRY_Condition.Operator.EQUALS, 'Active'));
	statusGroup.add(new QRY_Condition.FieldCondition('Status__c', QRY_Condition.Operator.EQUALS, 'Pending'));

	return QRY_Builder.selectFrom(Account.SObjectType)
		.fields(new List<String>{'Name', 'Industry', 'Status__c'})
		.condition(Account.Industry).equals('Technology')
		.addCondition(statusGroup)
		.toList();
}
```

> **Note:** Without explicit grouping, conditions follow standard SQL precedence where AND binds tighter than OR. For example, `A AND B OR C` evaluates as `(A AND B) OR C`.

Inside a hand-built group, a text match works the same way as in the builder: construct the `FieldCondition` with only the field, then complete it with `contains()`, or with `containsLiteral()` when the text came from a person and should match exactly as typed. See [Layer 3: QRY_Condition](#layer-3-qry_condition) for an example.

### Advanced Filtering

#### Using IN Operator with Collection

```apex
/**
 * @description Finds accounts by multiple types
 *
 * @param accountTypes Set of account types to include
 *
 * @return List of matching accounts
 */
public static List<Account> findByTypes(Set<String> accountTypes)
{
	return QRY_Builder.selectFrom(Account.SObjectType)
		.fields(new List<SObjectField>{ Account.Name, Account.Type, Account.Industry })
		.condition(Account.Type).isIn(new List<String>(accountTypes))
		.orderBy(Account.Name).ascending()
		.toList();
}
```

#### Using IN Operator with SObjects

Pass `List<SObject>` directly to `isIn()` without manual Id extraction. Salesforce automatically extracts Ids from the SObject list:

```apex
/**
 * @description Finds contacts belonging to the given accounts
 *
 * @param accounts List of accounts to find contacts for
 *
 * @return List of contacts for the accounts
 */
public static List<Contact> findByAccounts(List<Account> accounts)
{
	return QRY_Builder.selectFrom(Contact.SObjectType)
		.fields(new List<SObjectField>{ Contact.FirstName, Contact.LastName, Contact.Email })
		.condition(Contact.AccountId).isIn(accounts)
		.orderBy(Contact.LastName).ascending()
		.toList();
}
```

**Extract any field value from SObjects** using the field extraction overload:

```apex
/**
 * @description Finds accounts by contact email domains
 *
 * @param contacts List of contacts to extract AccountIds from
 *
 * @return List of accounts
 */
public static List<Account> findAccountsForContacts(List<Contact> contacts)
{
	return QRY_Builder.selectFrom(Account.SObjectType)
		.fields(new List<SObjectField>{ Account.Name, Account.Industry })
		.condition(Account.Id).isIn(contacts, Contact.AccountId)
		.toList();
}
```

`isIn` and `isInStrict` skip a record you pass in whose key field is blank. To match rows whose field is blank as well, add `.orCondition(field).isNull()`.
`notInSet` and `notInSetStrict` keep the blank key. So if one record you pass in has a blank key, the rows whose field is blank are left out of the result.

**Empty list handling:**

| Method                          | Empty/Null Behaviour              |
|---------------------------------|-----------------------------------|
| `isIn(List<SObject>)`           | Returns no results (safe)         |
| `isInStrict(List<SObject>)`     | Throws `IllegalArgumentException` |
| `notInSet(List<SObject>)`       | Excludes nothing (safe)           |
| `notInSetStrict(List<SObject>)` | Throws `IllegalArgumentException` |

**Important: Id/String Type Coercion**

Watch out for one Apex platform behaviour (not a framework limitation): when you use `List<Object>` with `isIn()` or `notInSet()`, Apex automatically turns strings that look like valid Salesforce IDs (15 or 18 characters) into Id values. That can make a text-field query miss matches.

```apex
// PROBLEMATIC: ID-like strings in List<Object> are treated as Ids
List<Object> mixedValues = new List<Object>{'001000000000001AAA', 'text-value'};
.condition(TextField__c).isIn(mixedValues)  // May not work for text field queries

// RECOMMENDED: Use strongly-typed collections
List<String> textValues = new List<String>{'001000000000001AAA', 'text-value'};
.condition(TextField__c).isIn(textValues)  // Works correctly for text fields

List<Id> idValues = new List<Id>{accountId1, accountId2};
.condition(Account.Id).isIn(idValues)  // Works correctly for Id fields
```

**Best practices:**

- Use `List<Id>` or `List<SObject>` when querying Id/lookup fields
- Use `List<String>` when querying text fields, even if values look like IDs
- Avoid `List<Object>` when your collection may contain mixed Id and String values

**Single SObject comparison:**

```apex
// Match by single SObject's Id
.condition(Contact.AccountId).equals(parentAccount)

// Exclude by single SObject's Id
.condition(Contact.AccountId).notEquals(excludedAccount)
```

#### String Pattern Matching

```apex
/**
 * @description Finds accounts whose names contain specific text
 *
 * @param searchText Text to search for in account names
 *
 * @return List of matching accounts
 */
public static List<Account> searchAccountsByName(String searchText)
{
	return QRY_Builder.selectFrom(Account.SObjectType)
		.fields(new List<SObjectField>{ Account.Name, Account.Industry, Account.Phone })
		.condition(Account.Name).contains(searchText)
		.orderBy(Account.Name).ascending()
		.withLimit(50)
		.toList();
}
```

This example owns its pattern, so the wildcards in `contains()` are wanted. When the text comes from
a person instead, a search box, a filter or a report parameter, the `%` and `_` characters they type
would otherwise act as wildcards.

For that text, build the condition with `QRY_Condition.FieldCondition` and finish it with `containsLiteral()`, then
pass it in with `addCondition()`. See [Searching for text a person typed](#searching-for-text-a-person-typed).

#### Multi-Picklist Field Filtering

```apex
/**
 * @description Finds contacts with specific interests (multi-picklist)
 *
 * @param requiredInterests Set of interests that must be present
 *
 * @return List of matching contacts
 */
public static List<Contact> findByInterests(Set<String> requiredInterests)
{
	return QRY_Builder.selectFrom(Contact.SObjectType)
		.fields(new List<SObjectField>{ Contact.FirstName, Contact.LastName, Contact.Email, Contact.Interests__c })
		.condition(Contact.Interests__c).includes(new List<String>(requiredInterests))
		.orderBy(Contact.LastName).ascending()
		.toList();
}
```

#### Date Literal Conditions

When you want to filter by a relative date (today, the last N days, this quarter) rather than a fixed date, use `QRY_Condition.DateLiteral`. It keeps the filter correct over time instead of baking in a date that goes stale:

```apex
/**
 * @description Finds accounts created in the last N days.
 *
 * @param days Number of days to look back
 *
 * @return List of recently created accounts
 */
public static List<Account> findRecentlyCreated(Integer days)
{
	return QRY_Builder.selectFrom(Account.SObjectType)
		.fields(new List<SObjectField>{Account.Name, Account.CreatedDate})
		.condition(Account.CreatedDate).equals(new QRY_Condition.DateLiteral().lastNDays(days))
		.orderBy(Account.CreatedDate).descending()
		.toList();
}

/**
 * @description Finds opportunities closing this quarter.
 *
 * @return List of opportunities closing in the current quarter
 */
public static List<Opportunity> findClosingThisQuarter()
{
	return QRY_Builder.selectFrom(Opportunity.SObjectType)
		.fields(new List<SObjectField>{Opportunity.Name, Opportunity.CloseDate, Opportunity.Amount})
		.condition(Opportunity.CloseDate).equals(new QRY_Condition.DateLiteral().thisUnit(QRY_Condition.UnitOfTime.QUARTER))
		.condition(Opportunity.IsClosed).equals(false)
		.toList();
}
```

**Available methods:** `.today()`, `.yesterday()`, `.tomorrow()`, `.lastNDays(n)`, `.nextNDays(n)`, `.last90Days()`, `.next90Days()`,
`.thisUnit(UnitOfTime)`, `.last(UnitOfTime)`, `.next(UnitOfTime)`, `.last(n, UnitOfTime)`, `.next(n, UnitOfTime)`.

**UnitOfTime values:** `DAY`, `WEEK`, `MONTH`, `QUARTER`, `YEAR`, `FISCAL_QUARTER`, `FISCAL_YEAR`.

### Parent Relationship Queries

#### Querying Related Fields

```apex
/**
 * @description Retrieves contacts with account information
 *
 * @param accountId Account Id to filter by
 *
 * @return List of contacts with parent account data
 */
public static List<Contact> findContactsWithAccountInfo(Id accountId)
{
	return QRY_Builder.selectFrom(Contact.SObjectType)
		.fields(new List<SObjectField>{ Contact.FirstName, Contact.LastName, Contact.Email })
		.relatedFields(new List<String>{'Account.Name', 'Account.Industry', 'Account.Type'})
		.condition(Contact.AccountId).equals(accountId)
		.orderBy(Contact.LastName).ascending()
		.toList();
}
```

#### Parents that can be different objects (TYPEOF)

Some lookups can point to more than one kind of record. Salesforce calls these polymorphic lookups:

- an event's `What` can be an account, an opportunity or a case;
- a task's `Who` can be a contact or a lead.

SOQL's `TYPEOF` clause lets you pick different parent fields for each kind of parent in one query. Pass the clause to
`addField` as text:

```apex
List<Event> events = QRY_Builder.selectFrom(Event.SObjectType)
	.fields(new List<SObjectField>{ Event.Id, Event.Subject })
	.addField('TYPEOF What WHEN Account THEN Phone, Industry WHEN Opportunity THEN Amount ELSE Name END')
	.toList();
```

The same works for a task's `Who`:

```apex
List<Task> tasks = QRY_Builder.selectFrom(Task.SObjectType)
	.fields(new List<SObjectField>{ Task.Id, Task.Subject })
	.addField('TYPEOF Who WHEN Contact THEN Email, Phone WHEN Lead THEN Company ELSE Name END')
	.toList();
```

**Reading the parent.** Put the parent in an `SObject` variable and use `switch on` to find out which kind it is:

```apex
for(Event event : events)
{
	SObject parent = event.What;
	switch on parent
	{
		when Account account
		{
			String phone = account.Phone;
		}
		when Opportunity opportunity
		{
			Decimal amount = opportunity.Amount;
		}
		when null
		{
			// the event has no parent
		}
		when else
		{
			// Any other parent: only its Name was selected
			String parentName = (String)parent.get('Name');
		}
	}
}
```

Do not cast the parent straight to one object, as in `(Account)event.What`. For a row that matched the `ELSE` branch, the parent is a
`Name` record (Salesforce's general type for a polymorphic parent), so the cast throws a `TypeException`.

**Two rules to know:**

- **TYPEOF chooses fields, it never filters rows.** Every event comes back, whatever its parent is. To keep only some kinds of parent,
  add a condition as well.
- **It cannot be combined with aggregate functions** such as `count()` or `sum()` in the same query.

A TYPEOF query works in user mode, and a cached TYPEOF query is served from the cache on the second read.

### Caching Queries

The same read often runs several times in one transaction: three trigger actions each look up the same parent accounts, or a service and the
validation it calls both read the same settings. Each repeat costs a query against the governor limit of 100.

When a selector opts into caching, the first read goes to the database. Every repeat with the same query, binds, user and access mode comes
back from the cache, so the repeats cost no query at all.

Each caller gets its own copy of the rows, so a caller that changes a record it was given changes nothing for the next caller. A write through
the framework empties the in-memory cache (see [What empties the cache?](#what-empties-the-cache)), so a read kept in memory sees the write.

In this section, a **transaction** is the save that fired the trigger and everything it runs synchronously; each Queueable, batch chunk or future
call starts fresh.

#### Caching every read from a selector

Override `cacheScope()` on your selector, and every list or record read it makes through `query`, the inherited `findById` and `findByField`
methods included, is cached. Counts (`count()`, `exists()`) and query locators (`toQueryLocator()`) always go to the database:

```apex
public with sharing class SEL_Accounts extends SEL_Base
{
	public SEL_Accounts()
	{
		super(Account.SObjectType);
	}

	public override List<SObjectField> getFields()
	{
		return new List<SObjectField>{ Account.Name, Account.Industry, Account.OwnerId };
	}

	public override UTIL_Cache.Scope cacheScope()
	{
		return UTIL_Cache.Scope.IN_TRANSACTION;
	}
}

// The first call queries; the second, with the same Ids, comes from memory
List<SObject> parents = new SEL_Accounts().findById(parentIds);
List<SObject> sameParents = new SEL_Accounts().findById(parentIds);
```

This selector keeps its rows for one transaction only. Rows are kept beyond one transaction, in Platform Cache, only when all three of these
hold:

- the scope is `AUTO`, `SESSION` or `ORG`, not `IN_TRANSACTION` (overriding only `cacheTimeToLiveSeconds()` means `AUTO`);
- the read runs in system mode: the selector overrides `systemModeRequired()` to return `true`, the method calls `withSystemMode()` (or
  `withoutSecurity()`, which includes it and also bypasses sharing), the method calls `bypassSharing()` (the read ignores sharing; the
  fields each user cannot read are removed when the rows are handed to that user), or the
  `UserModeQueries_Enabled` feature flag is switched off;
- the method states its sharing with `withSharing()`, `bypassSharing()` or `withoutSecurity()`.

Even then, the rows stay in memory for the transaction only where your org has no Platform Cache space for that scope. A user-mode read
never keeps rows beyond the transaction (except a `bypassSharing()` read), whatever the selector overrides.

`cacheTimeToLiveSeconds()` is the number of seconds Platform Cache may keep the rows; a scope with no time-to-live uses 900 seconds. The
time-to-live does not apply to rows kept in memory, which last until the transaction ends or a write empties the cache.

Both methods are called each time the selector's `query` builder is built, so return a constant from them rather than working a value out.

#### Where are cached rows kept?

The scope says where a read may be kept. Kern keeps each read only where it is safe for that read:

| Scope (`UTIL_Cache.Scope`) | Where the rows are kept                                                                                                   |
|----------------------------|---------------------------------------------------------------------------------------------------------------------------|
| `IN_TRANSACTION`           | In memory, for the rest of the transaction.                                                                               |
| `AUTO`                     | Platform Cache for a system-mode read whose sharing is stated, where a partition keeps it; in memory otherwise.           |
| `SESSION`                  | Platform Cache's session cache, for a system-mode read whose sharing is stated; in memory for the transaction otherwise.  |
| `ORG`                      | Platform Cache's org cache, for a system-mode read whose sharing is stated; in memory for the transaction otherwise.      |

- **A user-mode read, the default,** runs with the current user's object, field and sharing checks enforced, so its rows are kept in memory
  for the transaction only and never reach Platform Cache.
- **A read with `.bypassSharing()` is the exception:** it runs in system mode without sharing, so it can reach Platform Cache, and the fields
  each user cannot read are removed when the rows are handed to that user. See "What can reach Platform Cache" in [Platform Cache Integration](#platform-cache-integration).
- **Where your org has no Platform Cache space allocated for a scope,** a read asked for that scope is kept in memory for the transaction
  instead, so caching still saves the repeats within each transaction.

#### Changing the caching for one query

Inside a selector method, `query.withoutCache()` makes that one read go to the database, whatever the selector's `cacheScope()` says, and
`query.withCache(scope, ttlSeconds)` gives that one read a different scope or time-to-live. The last caching call on a builder wins, so a
method's own call always beats the selector's default.

```apex
List<SObject> fresh = new SEL_Accounts().query.withoutCache().condition(Account.Id).isIn(new List<Id>(accountIds)).toList();
```

#### Telling callers how old the rows may be

A method that caches across transactions says so in its ApexDoc, and the selector offers a fresh version beside it for the callers that
cannot accept older rows.

The reason: a selector method returns rows, not a builder, so its caller cannot change how the query runs. The scope and time-to-live are
therefore part of what a selector promises its callers about how old the rows may be.

The selector below runs its reads in system mode, so each method states its sharing (here through the shared `recentOrders` builder), which is
what lets the rows be cached at all:

```apex
public with sharing class SEL_Orders extends SEL_Base
{
	public SEL_Orders()
	{
		super(Order.SObjectType);
	}

	public override Boolean systemModeRequired()
	{
		return true;
	}

	/**
	 * @description Finds the accounts' orders, newest first. Where your org has an Org Cache partition, the rows are
	 * kept for up to an hour; otherwise only for the transaction. An order saved or changed in that time can be
	 * missing or out of date; use findRecentOrdersFresh when that matters.
	 *
	 * @param accountIds The accounts whose orders to find
	 *
	 * @return The orders, newest first
	 */
	public List<Order> findRecentOrders(Set<Id> accountIds)
	{
		return (List<Order>)recentOrders(accountIds).withCache(UTIL_Cache.Scope.ORG, 3600).toList();
	}

	/**
	 * @description Finds the accounts' orders, newest first, always from the database.
	 *
	 * @param accountIds The accounts whose orders to find
	 *
	 * @return The orders, newest first
	 */
	public List<Order> findRecentOrdersFresh(Set<Id> accountIds)
	{
		return (List<Order>)recentOrders(accountIds).withoutCache().toList();
	}

	private QRY_Builder.Builder recentOrders(Set<Id> accountIds)
	{
		return query.withSharing().condition(Order.AccountId).isIn(new List<Id>(accountIds)).orderBy(Order.EffectiveDate).descending();
	}
}
```

#### What empties the cache?

Every write through `DML_Builder` empties the whole in-memory cache before the save starts and again when it ends, saved or rolled back. So do
the framework's other writes:

- inbound web services;
- the test data builders (`TST_Factory`, `TST_Builder`);
- the Flow email action's activity Task.

The whole cache is emptied, even for a write to an unrelated object. One write can change other objects' rows through roll-up summaries,
formulas, cascading deletes and sharing recalculation, and the cache cannot tell which.

| Kind of write                                                                                                                       | Does it empty the in-memory cache?                                                                                                                   |
|-------------------------------------------------------------------------------------------------------------------------------------|------------------------------------------------------------------------------------------------------------------------------------------------------|
| A log entry, normally                                                                                                               | No. Logging usually leaves the cache alone: a log entry is normally published as a platform event, which saves nothing in your transaction, so nothing is emptied. |
| A log entry inside a platform-event or change-event trigger                                                                         | Yes. The entries are saved straight away through `DML_Builder` instead, and that save empties the in-memory cache like any other.                   |
| A log entry under flood control (where repeats of the same entry are counted rather than each saved), inside such a trigger          | No: these are saved without emptying it.                                                                                                             |
| A write the framework does not make: a Flow, a plain `insert` or `update` statement, another package, or a class built on `DML_Transaction` that runs its own DML statements | No: these writes are not seen. If your code writes that way and then reads the same rows back through a caching selector in the same transaction, read with `withoutCache()`. |

Rows kept in Platform Cache are not emptied by any write: they can stay until their time-to-live runs out. That is why a method that caches across
transactions says so, and why its selector offers a fresh version.

#### Seeing what the cache did

When a query's performance is logged (see [Query Performance Logging](#query-performance-logging)), the entry records a cache status that says what
happened to the read and, when it was not cached, why:

| Cache status                 | What happened                                                                                     |
|------------------------------|---------------------------------------------------------------------------------------------------|
| `MEMORY_HIT`                 | Served from memory                                                                                |
| `HIT`                        | Served from Platform Cache                                                                        |
| `STORED`                     | Read from the database and kept in Platform Cache                                                 |
| `MEMORY_STORED`              | Read from the database and kept in memory, as the transaction scope asked                         |
| `MEMORY_STORED_USER_MODE`    | Read from the database and kept in memory only, because it is a user-mode read                    |
| `MEMORY_STORED_NO_PARTITION` | Read from the database and kept in memory only, because no Platform Cache partition kept it       |
| `DECLINED_INHERITED_SHARING` | Not cached: a system-mode read that left its sharing to the calling class                         |
| `DECLINED_ROW_CAP`           | Not cached: more than 200 rows, for a read only memory could keep                                 |
| `DECLINED_HEAP_GUARD`        | Not cached: heap stayed at or over 40% of its limit, for a read only memory could keep            |
| `DECLINED_AGGREGATE`         | Not cached in memory: an aggregate query                                                          |
| `DECLINED_CHILD_SUBQUERY`    | Not cached in memory: a query with a child subquery                                               |
| `BYPASS`                     | No caching was asked for, or this kind of read is never cached                                    |

#### System-mode selectors and sharing

A system-mode read is cached only when the method states its sharing with `withSharing()` or `bypassSharing()`. A read that leaves its sharing
to the calling class is not cached at all, because the cache cannot tell one calling class's sharing from another's.

So a selector that overrides `systemModeRequired()` caches only in the methods that set sharing, as `SEL_Orders` does above. The same holds for
every selector while the `UserModeQueries_Enabled` feature flag is switched off, because its reads then run in system mode.

#### Custom metadata selectors

Caching a custom metadata selector usually saves little: most custom metadata queries do not count against the 100-query limit. A custom
metadata query counts only when it selects a long text area field at the top level of the query, so that is the case where caching saves
queries.

If a custom metadata selector does cache, declare `IN_TRANSACTION`. The reasons:

- Custom metadata does not change within a transaction, but a deployment can change it between transactions.
- A custom metadata selector that reads in system mode (`systemModeRequired()`) and states its sharing would, with `AUTO` (or a time-to-live
  alone), keep its rows in Platform Cache. A deployed change could then stay invisible until the time-to-live runs out.

Such a selector also states the sharing in each method, or its reads are not cached at all:

```apex
public override UTIL_Cache.Scope cacheScope()
{
	return UTIL_Cache.Scope.IN_TRANSACTION;
}
```

#### Caching in tests

A test that saves its data through `TST_Factory` or `TST_Builder` needs nothing extra: they empty the cache before they write.

A test that inserts data another way (a plain `insert`, for example) after a caching selector has already read, and then reads that data back
through the same selector, uses `withoutCache()` for that read, or it gets the rows from before the insert.

#### What is never kept in memory?

Some reads are never kept in memory, whatever the scope. Declining is silent: the read goes to the database and costs one query, as it would
without caching.

- **Results over 200 rows.** A larger result would take too much of the heap to copy for each caller.
- **Aggregate queries** (`toAggregateList`).
- **Queries with a child subquery.** Copying their rows would share the child records between callers. The check reads the query text, so a
  subquery added as a raw string counts, and a semi-join (`IN (SELECT ...)`) does not. In a caching selector, read the children in a
  separate method, so both reads are cached.
- **Any new result while heap use stays at or over 40% of the transaction's limit.**
  - The oldest entries are dropped first to make room, so a long bulk load keeps caching its newest reads.
  - The framework measures heap while the query runs, and once the query returns its rows count for a little more. So a transaction that
    leans heavily on the cache can use up to about half of the heap limit for cached and returned rows together.
  - There is nothing you need to do: the 40% guard already leaves room for it.

These limits are for memory only. A read that may use Platform Cache (a system-mode read with its sharing stated, under a scope other than
`IN_TRANSACTION`) can still be kept there, where your org's partition keeps it.

A few kinds of read are never cached anywhere, in memory or in Platform Cache: row-locking reads (`FOR UPDATE`, `FOR REFERENCE`, `FOR VIEW`),
`ALL ROWS` reads, random picks (`getRandomItem()`), paged and cursor reads (`getPage()`, `toCursor()`), counts (`count()`, `exists()`) and
query locators (`toQueryLocator()`).

#### Platform Cache Integration

`withCache(ttl)` caches one query. With a time-to-live it behaves like the `AUTO` scope above: a system-mode read whose sharing is stated is kept
in Platform Cache, and every other read is kept in memory for the transaction.

```apex
/**
 * @description Retrieves frequently accessed account with caching
 *
 * @param accountId Account Id to retrieve
 *
 * @return Cached account record
 */
public static Account getCachedAccount(Id accountId)
{
	return (Account)QRY_Builder.selectFrom(Account.SObjectType)
		.fields(new List<SObjectField>{Account.Name, Account.Industry, Account.Phone, Account.Website})
		.condition(Account.Id).equals(accountId)
		.withSystemMode()
		.withSharing()
		.withCache(300) // Cache for 5 minutes (300 seconds)
		.getFirst();
}

/**
 * @description Checks if last query result came from cache
 *
 * @example
 * QRY_Builder.Builder query = QRY_Builder.selectFrom(Account.SObjectType).withSystemMode().withSharing().withCache(600);
 * List<Account> accounts = query.toList();
 * if(query.isCached())
 * {
 * 	LOG_Builder.build().debug('Results retrieved from cache').emitAt('MyClass.myMethod');
 * }
 */
```

**How cached rows are kept apart.** Cached results are keyed per sharing setting and, where sharing applies, per user, so one caller never
receives rows another caller cached under a different setting.

A read with sharing bypassed is cached once for the whole org, unless the query itself shows that its rows or values depend on the user.
Those reads are cached per user:

- a scope other than everything;
- one of the SOQL functions `toLabel`, `FORMAT`, `convertCurrency` or `convertTimezone`;
- a relative date such as `TODAY` or `THIS_FISCAL_QUARTER`, which is read in the user's time zone.

A value the platform translates with nothing in the query to say so, such as a record type's name, is not detected: cache that read with
`.withSharing()`, or select it through `toLabel`.

**What can reach Platform Cache.**

- A read in user mode, the default, never reaches Platform Cache: see [Where are cached rows kept?](#where-are-cached-rows-kept).
- A read with `.bypassSharing()` is the exception: it runs in system mode without sharing, so it can reach Platform Cache, and the fields each
  user cannot read are removed when the rows are handed to that user.
- To keep a read in Platform Cache across transactions, call `.withSystemMode()` and state the sharing setting on the builder: `.withSharing()`
  or `.bypassSharing()`.
- Because a system-mode read skips the object and field permission checks, cache only data that every caller of that code is allowed to see.
- A system-mode read that leaves the sharing setting to the calling class is not cached either: see
  [System-mode selectors and sharing](#system-mode-selectors-and-sharing).

Paged and cursor reads (`getPage()`, `toCursor()`) are never cached, in memory or in Platform Cache: a cached page could not carry its total or
its cursor.

### Query Performance Logging

Slow queries are a common cause of hard-to-find performance problems. QRY_Builder records how long a query took and logs it automatically when it crosses a threshold, so you can spot and fix slow queries without changing the query code.

> **See Also:** [Logging - Guide](Logging%20-%20Guide.md) covers the logging framework in full, including correlation tracking (one tracking ID that follows a single user action across triggers, queries, callouts, and jobs), context management, and troubleshooting.

**Configuration via [`LogSetting__c`](reference/objects/LogSetting__c.md):**

- `EnableQueryPerformanceLogging__c` - Master switch (default: true)
- `QueryPerformanceThresholdMs__c` - Threshold in ms (default: 1000 = 1 second)

#### Force Logging a Query

```apex
/**
 * @description Always logs this query's performance, regardless of threshold settings.
 * Use for critical queries you always want to monitor.
 */
public static List<Account> getCriticalAccounts()
{
	return QRY_Builder.selectFrom(Account.SObjectType)
		.fields(new List<SObjectField>{ Account.Name, Account.Industry })
		.condition(Account.Type).equals('Critical')
		.forcePerformanceLogging()  // Always log this query
		.toList();
}
```

#### Custom Threshold per Query

```apex
/**
 * @description Logs if query exceeds custom threshold, overriding global setting.
 * Use when you need stricter monitoring for specific queries.
 */
public static List<Contact> getFastContacts(Id accountId)
{
	return QRY_Builder.selectFrom(Contact.SObjectType)
		.fields(new List<SObjectField>{ Contact.Name, Contact.Email })
		.condition(Contact.AccountId).equals(accountId)
		.logPerformanceIfSlowerThan(100)  // Log if > 100ms (stricter than global 1s default)
		.toList();
}
```

#### Suppress Logging

```apex
/**
 * @description Prevents performance logging for high-frequency internal queries.
 * Use for queries that execute frequently and would generate excessive logs.
 *
 * @param accountId The account whose contacts to read
 *
 * @return The contacts of the account
 */
public static List<Contact> getContactsForAccount(Id accountId)
{
	return QRY_Builder.selectFrom(Contact.SObjectType)
		.fields(new List<SObjectField>{ Contact.Name, Contact.Email })
		.condition(Contact.AccountId).equals(accountId)
		.suppressPerformanceLogging()  // Never log this query's performance
		.toList();
}
```

#### Logging Hierarchy

The logging hierarchy (most to least specific):

1. `.suppressPerformanceLogging()` - Never log this query
2. `.forcePerformanceLogging()` - Always log this query
3. `.logPerformanceIfSlowerThan(ms)` - Log if exceeds custom threshold
4. `QueryPerformanceThresholdMs__c` - Global threshold from LogSetting__c
5. `EnableQueryPerformanceLogging__c` - Master switch

### SOQL Functions in Queries

Date functions and distance checks have typed `QRY_Function` helpers, shown below. `toLabel()` and `FORMAT()` work through
the existing versions of the methods that take the field as text:

#### Date Functions in GROUP BY

Often you want to group by part of a date, for example "count opportunities per calendar month". `QRY_Function` gives you one helper per SOQL date function, so you pick it from autocomplete instead of typing the expression by hand and risking a typo.

Use the same helper in `addField` (with an alias so you can read the value back), in `groupBy`, and in `orderBy`, which keeps the SELECT and GROUP BY expressions in sync:

```apex
List<QRY_Builder.AggregateRow> results = QRY_Builder.selectFrom(Opportunity.SObjectType)
	.addField(QRY_Function.calendarMonth(Opportunity.CloseDate), 'monthNumber')
	.count('Id')
	.groupBy(QRY_Function.calendarMonth(Opportunity.CloseDate))
	.orderBy(QRY_Function.calendarMonth(Opportunity.CloseDate))
	.toAggregateList();

for(QRY_Builder.AggregateRow row : results)
{
	Integer month = row.getInteger('monthNumber');
	Integer total = row.getInteger('count_Id');
}
```

All 13 SOQL date functions have a factory: `calendarMonth`, `calendarQuarter`, `calendarYear`, `dayInMonth`,
`dayInWeek`, `dayInYear`, `dayOnly`, `fiscalMonth`, `fiscalQuarter`, `fiscalYear`, `hourInDay`, `weekInMonth`,
`weekInYear`. Each yields an `Integer` date part except `dayOnly`, which yields a `Date` (read it back with
`row.getDate(alias)`).

When the field is only known at runtime, map it to a field token through a list of the fields you allow, then
pass the token to the factory: `QRY_Function.calendarMonth(ALLOWED_DATE_FIELDS.get(choice) ?? Opportunity.CloseDate)`.
Never build the expression as text from a name you were given (see
[Field names from a page or a user](#field-names-from-a-page-or-a-user)).

#### Proximity Filtering and Nearest-First Ordering

`QRY_Function` answers proximity questions with two helpers, `distanceInMiles(...)` and `distanceInKilometers(...)`. Use them when you need the nearest stores, the closest field engineers, or every account within ten miles of a point.

Each one wraps the SOQL `DISTANCE` function (which returns the straight-line distance between two geolocation points), so you can both filter and sort records by how far each one sits from a fixed location, without hand-writing the raw expression.

You choose the unit by the helper you call, so there is no unit string to mistype. Give the helper a geolocation or compound address field and a reference latitude and longitude, filter on the result with `.condition(...)`, and sort nearest-first with `.orderBy(...).ascending()`:

```apex
List<Account> nearby = QRY_Builder.selectFrom(Account.SObjectType)
	.condition(QRY_Function.distanceInMiles(Account.BillingAddress, 37.775, -122.418)).lessThan(10)
	.orderBy(QRY_Function.distanceInMiles(Account.BillingAddress, 37.775, -122.418)).ascending()
	.toList();
```

That reads as "accounts whose billing address is within 10 miles of the point, closest first". Swap `.ascending()` for `.descending()` to sort farthest-first instead, and call `distanceInKilometers(...)` in place of `distanceInMiles(...)` when you want kilometres.

If you already hold the origin as a `System.Location`, for example the running user's current position, pass it straight in. Both helpers also take a `System.Location`:

```apex
System.Location origin = System.Location.newInstance(37.775, -122.418);

List<Account> nearby = QRY_Builder.selectFrom(Account.SObjectType)
	.condition(QRY_Function.distanceInKilometers(Account.BillingAddress, origin)).lessThan(25)
	.orderBy(QRY_Function.distanceInKilometers(Account.BillingAddress, origin)).ascending()
	.toList();
```

#### toLabel (Picklist Translation)

```apex
List<SObject> records = QRY_Builder.selectFrom(Opportunity.SObjectType)
	.addField('toLabel(StageName)')
	.toList();
```

#### FORMAT (Localised Formatting)

```apex
List<SObject> records = QRY_Builder.selectFrom(Account.SObjectType)
	.addField('FORMAT(AnnualRevenue) formattedRevenue')
	.toList();
```

### Result Transformation

#### Converting to Map

```apex
/**
 * @description Retrieves accounts as a Map for quick lookup
 *
 * @param accountIds Set of account Ids
 *
 * @return Map of accounts indexed by Id
 */
public static Map<Id, Account> getAccountMap(Set<Id> accountIds)
{
	return (Map<Id, Account>)QRY_Builder.selectFrom(Account.SObjectType)
		.fields(new List<SObjectField>{ Account.Name, Account.Industry, Account.Type })
		.condition(Account.Id).isIn(new List<Id>(accountIds))
		.asMap();
}
```

#### Extracting Id Sets

```apex
/**
 * @description Gets Ids of technology accounts
 *
 * @return Set of account Ids
 */
public static Set<Id> getTechnologyAccountIds()
{
	return QRY_Builder.selectFrom(Account.SObjectType)
		.condition(Account.Industry).equals('Technology')
		.asIdSet();
}
```

#### Extracting Field Values

```apex
/**
 * @description Gets all unique industries from accounts
 *
 * @return Set of industry values
 */
public static Set<String> getAllIndustries()
{
	Set<Object> industries = QRY_Builder.selectFrom(Account.SObjectType)
		.addField(Account.Industry)
		.asValueSet(Account.Industry);

	// Convert Set<Object> to Set<String>
	Set<String> industryStrings = new Set<String>();
	for(Object industry : industries)
	{
		if(industry != null)
		{
			industryStrings.add((String)industry);
		}
	}
	return industryStrings;
}
```

### Existence Checks

#### Checking if Records Exist

```apex
/**
 * @description Checks if any open cases exist for an account
 *
 * @param accountId Account Id to check
 *
 * @return true if open cases exist
 */
public static Boolean hasOpenCases(Id accountId)
{
	return QRY_Builder.selectFrom(Case.SObjectType)
		.condition(Case.AccountId).equals(accountId)
		.andCondition(Case.IsClosed).equals(false)
		.exists(); // More efficient than count() > 0
}
```

### Security & Row Locking

The security options can be combined freely. The default access mode, the table of security methods and the warning that SYSTEM_MODE does
not bypass sharing are set out once, in [Sharing Enforcement](#sharing-enforcement).

#### Where the security methods are described

- What each method does and when to use it: the table in [Sharing Enforcement](#sharing-enforcement).
- What `withSharing()` and `bypassSharing()` change in USER_MODE and in SYSTEM_MODE: the note in [Bypassing Sharing](#bypassing-sharing).

#### Switching a selector, or the whole framework, to system mode

**Per-selector opt-out:** the framework's own internal selectors that must always run in SYSTEM_MODE (for example, those reading `*__mdt` configuration or `LogEntry__c` audit data) override `systemModeRequired()` on `SEL_Base` to return `true`. That one override pins every query going through the selector's `query` property to SYSTEM_MODE, no matter what the flag default is.

**Org-wide off switch:** in an emergency you can fall back to SYSTEM_MODE across the whole framework without a code change. Set `IsEnabledByDefault__c` to `false` on the `FeatureFlag.UserModeQueries_Enabled` record (a `kern__FeatureFlag__mdt` record in your org), in Setup or with a metadata deploy. Treat this as a last-resort rollback only, used while the offending code is being fixed.

#### USER_MODE Security (CRUD, FLS, and Sharing)

```apex
/**
 * @description Retrieves accounts with full security enforcement via USER_MODE.
 * Throws exception if user lacks object READ access.
 *
 * Throws exception if user cannot read one of the selected fields.
 *
 * @return List of accounts
 */
public static List<Account> getAccountsWithUserMode()
{
	return QRY_Builder.selectFrom(Account.SObjectType)
		.fields(new List<SObjectField>{ Account.Name, Account.Industry, Account.AnnualRevenue, Account.Description })
		.withUserMode() // Enforces CRUD, FLS, and sharing at database level
		.toList();
}
```

#### Strip Inaccessible Fields

```apex
/**
 * @description Retrieves accounts with inaccessible fields removed from results.
 * Runs in SYSTEM_MODE, because in USER_MODE a hidden field refuses the query before the strip runs.
 * SYSTEM_MODE does not check the object permission; withSharing() keeps record sharing.
 *
 * @return List of accounts with only accessible fields populated
 */
public static List<Account> getAccountsWithStrippedFields()
{
	return QRY_Builder.selectFrom(Account.SObjectType)
		.fields(new List<SObjectField>{ Account.Name, Account.Industry, Account.AnnualRevenue, Account.Description })
		.withSystemMode()
		.withSharing()
		.stripInaccessible() // Removes inaccessible fields post-query
		.toList();
}
```

#### Combining Security Options

```apex
/**
 * @description Retrieves accounts whatever their sharing, with the running user's object and field permissions kept.
 * Refused if the user cannot read Account; fields the user cannot read are removed from the rows.
 *
 * @return List of accounts with only accessible fields populated
 */
public static List<Account> getAccountsWhateverTheirSharing()
{
	return QRY_Builder.selectFrom(Account.SObjectType)
		.fields(new List<SObjectField>{ Account.Name, Account.Industry, Account.AnnualRevenue, Account.Description })
		.withUserMode()
		.bypassSharing() // Ignores sharing, keeps the object and field checks in USER_MODE
		.toList();
}
```

#### Sharing Control

```apex
/**
 * @description Retrieves accounts with enforced sharing rules.
 * Uses a with sharing proxy class (only changes something in SYSTEM_MODE: USER_MODE enforces sharing anyway).
 *
 * @return List of accounts respecting sharing rules
 */
public static List<Account> getAccountsWithSharing()
{
	return QRY_Builder.selectFrom(Account.SObjectType)
		.fields(new List<SObjectField>{ Account.Name, Account.Industry })
		.withSharing() // Enforces sharing via proxy class
		.toList();
}

/**
 * @description Retrieves accounts bypassing sharing rules.
 * WARNING: Allows access to records the user normally cannot see.
 * In USER_MODE the user's object and field permissions still apply: fields the user cannot read are removed.
 *
 * @return List of all accounts regardless of sharing rules
 */
public static List<Account> getAccountsBypassingSharing()
{
	return QRY_Builder.selectFrom(Account.SObjectType)
		.fields(new List<SObjectField>{ Account.Name, Account.Industry })
		.bypassSharing() // Bypasses sharing via proxy class
		.toList();
}
```

#### Row Locking for Updates

```apex
/**
 * @description Retrieves accounts with row locks for update
 *
 * @param accountIds Set of account Ids to lock
 *
 * @return List of locked account records
 */
public static List<Account> lockAccountsForUpdate(Set<Id> accountIds)
{
	return QRY_Builder.selectFrom(Account.SObjectType)
		.fields(new List<String>{'Name', 'Industry', 'Status__c'})
		.condition(Account.Id).isIn(new List<Id>(accountIds))
		.forUpdate() // Locks records for update
		.toList();
}
```

### Scoped Queries

#### Using USING SCOPE

```apex
/**
 * @description Retrieves only accounts owned by current user
 *
 * @return List of user's accounts
 */
public static List<Account> getMyAccounts()
{
	return QRY_Builder.selectFrom(Account.SObjectType)
		.fields(new List<String>{'Name', 'Industry', 'Owner.Name'})
		.usingScope(QRY_Builder.Scope.MINE) // Only my records
		.orderBy(Account.Name).ascending()
		.toList();
}

/**
 * @description Retrieves accounts visible to the entire team
 *
 * @return List of team accounts
 */
public static List<Account> getTeamAccounts()
{
	return QRY_Builder.selectFrom(Account.SObjectType)
		.fields(new List<String>{'Name', 'Industry', 'Owner.Name'})
		.usingScope(QRY_Builder.Scope.TEAM) // Team's records
		.orderBy(Account.CreatedDate).descending()
		.toList();
}
```

### Data Category Queries

If you query Salesforce Knowledge articles (or other objects organised into data categories), you often want only the articles in a given category, such as a region or product line. The `WITH DATA CATEGORY` clause does that. Start a filter with `.withDataCategory(groupName)`, then chain an operator to finish it.

#### Operators

| Operator         | Method            | Description                           |
|------------------|-------------------|---------------------------------------|
| `AT`             | `.at()`           | Exact category match                  |
| `ABOVE`          | `.above()`        | Ancestors of the specified category   |
| `BELOW`          | `.below()`        | Descendants of the specified category |
| `ABOVE_OR_BELOW` | `.aboveOrBelow()` | Both ancestors and descendants        |

Each operator has two overloads: `(String categoryName)` for a single category, and `(List<String> categoryNames)` for
multiple categories in one group (rendered as a parenthesized list in SOQL).

#### Single Category Filter

```apex
List<SObject> articles = QRY_Builder.selectFrom(KnowledgeArticleVersion.SObjectType)
	.fields(new List<SObjectField>{ KnowledgeArticleVersion.Id, KnowledgeArticleVersion.Title })
	.condition('PublishStatus').equals('Online')
	.condition('Language').equals('en_US')
	.withDataCategory('Geography__c').at('USA__c')
	.toList();
```

#### Multiple Categories in One Group

```apex
List<SObject> articles = QRY_Builder.selectFrom(KnowledgeArticleVersion.SObjectType)
	.fields(new List<SObjectField>{ KnowledgeArticleVersion.Id, KnowledgeArticleVersion.Title })
	.condition('PublishStatus').equals('Online')
	.condition('Language').equals('en_US')
	.withDataCategory('Geography__c').at(new List<String>{'USA__c', 'Canada__c', 'Mexico__c'})
	.toList();
```

#### Multiple Groups (AND)

Chain multiple `.withDataCategory()` calls for different groups. Groups are joined with `AND` in the generated SOQL.

```apex
List<SObject> articles = QRY_Builder.selectFrom(KnowledgeArticleVersion.SObjectType)
	.fields(new List<SObjectField>{ KnowledgeArticleVersion.Id, KnowledgeArticleVersion.Title })
	.condition('PublishStatus').equals('Online')
	.condition('Language').equals('en_US')
	.withDataCategory('Geography__c').at('USA__c')
	.withDataCategory('Product__c').below('Electronics__c')
	.toList();
```

#### Hierarchy Traversal with BELOW

Use `.below()` to query all descendants of a category. This is useful for querying an entire branch of the hierarchy.

```apex
List<SObject> articles = QRY_Builder.selectFrom(KnowledgeArticleVersion.SObjectType)
	.fields(new List<SObjectField>{ KnowledgeArticleVersion.Id, KnowledgeArticleVersion.Title })
	.condition('PublishStatus').equals('Online')
	.condition('Language').equals('en_US')
	.withDataCategory('Product__c').below('All')
	.toList();
```

#### Constraints

- **One filter per group.** Adding two filters for the same group throws `IllegalArgumentException`.
- **Knowledge queries require `PublishStatus` in WHERE.** Salesforce returns an error if it is omitted.
- **`Language` is required when Translation Workbench is enabled.** Add `.condition('Language').equals('en_US')`.

### Batch Processing

For Batch Apex, `toQueryLocator()` in the batch's `start()` method is shown in
[QueryLocator for Batch Apex](#querylocator-for-batch-apex).

#### Cursor-Based Processing

`toCursor()` lets you fetch records in chunks on demand, when you need to walk through a large result set in your own code (not in Batch Apex). It goes past the 2,000-record OFFSET ceiling, supports up to 50 million records, and never loads everything into memory at once.

The cursor is opened under the builder's sharing setting, so what its fetches return follows the same rules as every other read. That holds even when you fetch from a later transaction, such as a queueable that walks the result set in stages.

```apex
/**
 * @description Process large dataset using cursor-based pagination
 */
public static void processLargeDataset()
{
	Database.Cursor cursor = QRY_Builder.selectFrom(Account.SObjectType)
		.fields(new List<SObjectField>{Account.Name, Account.Industry})
		.condition(Account.Industry).equals('Technology')
		.toCursor();

	// Get total record count
	Integer totalRecords = cursor.getNumRecords();
	LOG_Builder.build().info('Total records to process: ' + totalRecords).emitAt('MyClass.processLargeDataset');

	// Process in batches of 200
	Integer batchSize = 200;
	Integer processed = 0;

	while(processed < totalRecords)
	{
		List<SObject> batch = cursor.fetch(processed, batchSize);
		for(SObject record : batch)
		{
			// Process each record
		}
		processed += batch.size();
	}
}
```

**Cursor vs QueryLocator vs OFFSET:**

| Feature         | `toCursor()`        | `toQueryLocator()`      | OFFSET              |
|-----------------|---------------------|-------------------------|---------------------|
| **Max Records** | 50 million          | 50 million              | 2,000 (with OFFSET) |
| **Use Case**    | Apex code traversal | Batch Apex `start()`    | Simple pagination   |
| **Memory**      | Fetch on demand     | Batch framework handles | All in memory       |
| **Subqueries**  | ❌ Not supported     | ❌ Not supported         | ✅ Supported         |
| **Aggregates**  | ❌ Not supported     | ❌ Not supported         | ✅ Supported         |
| **FOR UPDATE**  | ❌ Not supported     | ❌ Not supported         | ✅ Supported         |

**When to Use Cursors:**

- Processing more than 2,000 records outside of batch context
- Need random access to large result sets
- Memory-efficient traversal of millions of records

<a id="extending-qry-builder-builder-directly"></a>
### Extending QRY_Builder.Builder directly

#### Extending Builder

```apex
/**
 * @description Custom reusable selector for Account queries with defaults
 */
public with sharing class AccountSelector extends QRY_Builder.Builder
{
	public AccountSelector()
	{
		super(Account.SObjectType);
	}

	/**
	 * @description Default fields included in all Account queries
	 */
	public override Set<String> getDefaultFields()
	{
		return new Set<String>{'Id', 'Name', 'Industry', 'Type', 'AnnualRevenue'};
	}

	/**
	 * @description Finds active customer accounts by industry
	 *
	 * @param industry Industry to filter by
	 *
	 * @return List of matching accounts
	 */
	public List<Account> findActiveCustomersByIndustry(String industry)
	{
		return (List<Account>)this.condition(Account.Industry).equals(industry)
			.andCondition(Account.Type).equals('Customer')
			.andCondition(Account.Active__c).equals('Yes')
			.toList();
	}

	/**
	 * @description Finds high-value accounts
	 *
	 * @param minimumRevenue Minimum annual revenue
	 *
	 * @return List of high-value accounts
	 */
	public List<Account> findHighValueAccounts(Decimal minimumRevenue)
	{
		return (List<Account>)this.condition(Account.AnnualRevenue).greaterThanOrEquals(minimumRevenue)
			.toList();
	}
}

// Usage:
AccountSelector selector = new AccountSelector();
List<Account> techAccounts = selector.findActiveCustomersByIndustry('Technology');
List<Account> highValueAccounts = selector.findHighValueAccounts(5000000);
```

`getDefaultFields()` is the hook your org overrides on a custom builder. The builder carries two more hooks, one for a condition applied to every query and one for a default sort order. Both are internal to the package today, so put that behaviour in your finder methods instead.

A shared filter becomes an `.andCondition(...)` and a house sort order becomes an `.orderBy(...)`, written once per finder:

```apex
public List<Account> findActiveCustomersByIndustry(String industry)
{
	return (List<Account>)this.condition(Account.Industry).equals(industry)
		.andCondition(Account.Type).equals('Customer')
		.andCondition(Account.Active__c).equals('Yes')
		.orderBy(Account.Name).ascending()
		.toList();
}
```

### Combining Multiple Patterns

#### Complex Real-World Example

```apex
/**
 * @description Finds recently modified high-value opportunities with caching
 *
 * @param minimumAmount Minimum opportunity amount
 * @param days Number of days to look back
 *
 * @return List of opportunities with account information
 */
public static List<Opportunity> findRecentHighValueOpportunities(Decimal minimumAmount, Integer days)
{
	Date cutoffDate = Date.today().addDays(-days);

	return QRY_Builder.selectFrom(Opportunity.SObjectType)
		.fields(new List<SObjectField>{ Opportunity.Name, Opportunity.StageName, Opportunity.Amount, Opportunity.CloseDate, Opportunity.LastModifiedDate })
		.relatedFields(new List<String>{'Account.Name', 'Account.Industry', 'Owner.Name'})
		// Add conditions
		.condition(Opportunity.Amount).greaterThanOrEquals(minimumAmount)
		.andCondition(Opportunity.LastModifiedDate).greaterThanOrEquals(cutoffDate)
		.andCondition(Opportunity.StageName).isIn(new List<String>{'Prospecting', 'Qualification', 'Proposal'})
		// Ordering
		.orderBy(Opportunity.LastModifiedDate).descending()
		.orderBy(Opportunity.Amount).descending().nullsLast()
		// Performance & Security
		.withSystemMode()
		.withSharing()
		.withCache(600) // Cache for 10 minutes
		.stripInaccessible()
		// Limit results
		.withLimit(100)
		.toList();
}
```

---

## Testing

In a test you can hand a query a set of fake records to return, so you can test the business logic around it without inserting anything into the database.

Tests run quicker with no database round-trips, test the logic rather
than the state of the database, see exactly the records you decide, and can use data that real validation rules in
your org would reject.

### Basic Query Mocking

Use `QRY_Builder.setMock()` to configure mock results and `QRY_Builder.clearMocks()` to reset. The query below has a
condition on `Industry`, a picklist field. The mock checks it, and both mock accounts have the Technology industry, so
both come back:

```apex
@IsTest
private static void testWithMockedQuery()
{
	List<Account> mockAccounts = (List<Account>)TST_Builder.of(Account.SObjectType)
		.withCount(2)
		.withOverride(Account.Name, 'Mock Account 1')
		.withOverride(Account.Industry, 'Technology')
		.withoutInsertion(true)
		.buildList();

	// Configure mock: these records answer every Account read, checked against its conditions
	QRY_Builder.setMock(Account.SObjectType, mockAccounts);

	Test.startTest();
	List<Account> results = QRY_Builder.selectFrom(Account.SObjectType)
		.fields(new List<SObjectField>{ Account.Name })
		.condition(Account.Industry).equals('Technology')
		.toList();
	Test.stopTest();

	Assert.areEqual(2, results.size(), 'Should return mocked records');
	Assert.areEqual('Mock Account 1', results[0].Name);

	QRY_Builder.clearMocks();
}
```

**Important:** When mocks are active, the mock checks only some query conditions. See
[Which Query Conditions a Mock Checks](Selectors%20-%20Guide.md#which-query-conditions-a-mock-checks).

### Creating Mock Records

Use `TST_Builder.withoutInsertion(true)` to create records with auto-generated mock IDs:

```apex
@IsTest
private static void testWithFactoryMockRecords()
{
	List<Account> mockAccounts = new List<Account>();

	// withoutInsertion(true) generates valid mock IDs without database insertion
	for(Integer i = 0; i < 5; i++)
	{
		Account mockAccount = (Account)TST_Builder.of(Account.SObjectType)
			.withOverrides(new Map<SObjectField, Object>
			{
				Account.Name => 'Mock Account ' + i,
				Account.Industry => 'Technology',
				Account.AnnualRevenue => 100000 * i
			})
			.withoutInsertion(true) // Generate mock ID without DML
			.build();
		mockAccounts.add(mockAccount);
	}

	// Configure mock
	QRY_Builder.setMock(Account.SObjectType, mockAccounts);

	Test.startTest();
	Account result = (Account)QRY_Builder.selectFrom(Account.SObjectType)
		.fields(new List<SObjectField>{ Account.Name, Account.Industry, Account.AnnualRevenue })
		.condition(Account.Id).equals(mockAccounts[2].Id)
		.getFirst();
	Test.stopTest();

	Assert.isNotNull(result);
	// On a standard object the mock checks the Id condition, so getFirst() returns the account asked for
	Assert.areEqual('Mock Account 2', result.Name);

	QRY_Builder.clearMocks();
}
```

**Difference between `withoutInsertion()` and `withoutInsertion(true)`:**

- `withoutInsertion()` - Creates record in memory with **no ID** (null Id)
- `withoutInsertion(true)` - Creates record in memory with **auto-generated mock ID** (valid 18-character Id)

Use `withoutInsertion(true)` when you need records with IDs for:

- Query mocking (records need IDs for realistic testing)
- Code that checks `record.Id != null`
- Map keys or Set membership based on Id

### Multiple Query Mocking

Mock multiple SObject types in the same test:

```apex
@IsTest
private static void testWithMultipleMockedTypes()
{
	List<Account> mockAccounts = new List<Account>
	{
		(Account)TST_Builder.of(Account.SObjectType)
			.withOverride(Account.Name, 'Acme Corp')
			.withoutInsertion(true)
			.build()
	};

	List<Contact> mockContacts = new List<Contact>
	{
		(Contact)TST_Builder.of(Contact.SObjectType)
			.withOverrides(new Map<SObjectField, Object>
			{
				Contact.FirstName => 'John',
				Contact.LastName => 'Doe',
				Contact.AccountId => mockAccounts[0].Id
			})
			.withoutInsertion(true)
			.build()
	};

	// Configure mocks for both types
	QRY_Builder.setMock(Account.SObjectType, mockAccounts);
	QRY_Builder.setMock(Contact.SObjectType, mockContacts);

	Test.startTest();
	List<Account> accounts = QRY_Builder.selectFrom(Account.SObjectType)
		.fields(new List<SObjectField>{ Account.Name })
		.toList();

	List<Contact> contacts = QRY_Builder.selectFrom(Contact.SObjectType)
		.fields(new List<SObjectField>{ Contact.FirstName, Contact.LastName })
		.condition(Contact.AccountId).equals(mockAccounts[0].Id)
		.toList();
	Test.stopTest();

	Assert.areEqual(1, accounts.size());
	Assert.areEqual('Acme Corp', accounts[0].Name);
	Assert.areEqual(1, contacts.size());
	Assert.areEqual('John', contacts[0].FirstName);

	QRY_Builder.clearMocks();
}
```

### Mocking with TST_Mock

For a friendlier way to do the same thing, use [TST_Mock](reference/apex/TST_Mock.md). It builds the fake record and registers it for query interception in one step:

```apex
@IsTest
private static void shouldReturnMockData()
{
	// Build mock + auto-register for query interception
	Account mock = (Account)TST_Mock.of(Account.SObjectType)
		.withOverride(Account.Name, 'Mock Account')
		.withOverride(Account.Industry, 'Finance')
		.build();

	// QRY_Builder queries now return mock data
	Test.startTest();
	List<Account> results = QRY_Builder.selectFrom(Account.SObjectType)
		.fields(new List<SObjectField>{ Account.Name, Account.Industry })
		.condition(Account.Industry).equals('Technology')
		.toList();
	Test.stopTest();

	Assert.areEqual(1, results.size());
	Assert.areEqual('Finance', results[0].Industry);

	TST_Mock.clear();
}
```

### Mocking an aggregate query

An aggregate query counts, adds up or groups records instead of returning them: the number of opportunities in each stage, or the total
amount of the pipeline. In a test you can hand such a query the rows it returns, so you can test the code that reads the totals without
inserting any records.

Register the rows with `TST_Mock.registerAggregateRows`. Each map is one row. Its keys are the aliases your code reads back (the names
you give each total in the query), and its values are what each alias holds:

```apex
@IsTest
private static void shouldReadMockedStageTotals()
{
	TST_Mock.registerAggregateRows(Opportunity.SObjectType, new List<Map<String, Object>>
	{
		new Map<String, Object>{ 'total' => 3, 'StageName' => 'Prospecting' },
		new Map<String, Object>{ 'total' => 2, 'StageName' => 'Closed Won' }
	});

	Test.startTest();
	List<QRY_Builder.AggregateRow> rows = QRY_Builder.selectFrom(Opportunity.SObjectType)
		.count(Opportunity.Id, 'total')
		.groupBy(Opportunity.StageName)
		.toAggregateList();
	Test.stopTest();

	Assert.areEqual(2, rows.size(), 'Expected one row for each registered map');
	Assert.areEqual(3, rows[0].getInteger('total'), 'Expected the rows in the order they were registered');
	Assert.areEqual('Prospecting', rows[0].getString('StageName'), 'Expected the stage the first row was registered with');

	TST_Mock.clear();
}
```

Use `TST_Mock.registerAggregateRows(type, row)` with a single map for a query you read with `getFirstAggregate()`. To answer only the next
aggregate query, and then go back to the registered rows, use `TST_Mock.registerNextAggregateRows` with the same two forms. A second
call to `TST_Mock.registerAggregateRows` for the same object adds its rows after the first ones, as `TST_Mock.register` adds records.

**Which keys does a row need?** The keys are the aliases your code reads:

- Give each aggregate its own alias in any query a test will mock: `count(Opportunity.Id, 'total')`, `sum(Opportunity.Amount, 'pipeline')`.
- A grouped field is read by its field API name (`StageName`).
- If you leave the alias out, the builder picks a default name, such as `count_Id` or `sum_Amount` (see
  [Several aggregates in one query](#several-aggregates-in-one-query)).
  In a namespaced package that name carries the field's namespace prefix too (`sum_acme__Total__c`), which is one more reason to choose
  the alias yourself.

**A registered row reads like a real one:**

- Keys are matched without regard to case, so `getInteger('TOTAL')` reads the key `total`. Two keys that differ only in case, such as
  `'Total'` and `'total'`, throw an `IllegalArgumentException` when the row is read.
- Reading an alias the row does not hold throws an `IllegalArgumentException` that lists the aliases it does hold, so a spelling mistake
  shows at once. A key that holds `null` reads as `null`.
- `getInteger`, `getLong` and `getDecimal` accept a number written as an Integer, a Long, a Double or a Decimal. `getInteger` and
  `getLong` throw a `TypeException` on a fraction, as a real row does. `getDate` and `getId` accept only their own type.
- Each read gets its own copy of the rows, so a change you make to a registered map after a read does not reach the rows that read
  returned.

**Only `LIMIT` applies to the rows.** They come back in the order you registered them. The query's conditions, `ORDER BY`, `GROUP BY`
and `HAVING` never filter, sort or group them.

**Record mocks never answer an aggregate query.** If a type has record mocks (from `TST_Mock.of(...).build()`, `TST_Mock.register` or
`QRY_Builder.setMock`) and no aggregate rows, every read of the aggregate query, `toList()` included, throws a
`UTIL_Exceptions.IllegalStateException` that names `TST_Mock.registerAggregateRows`.

The fix is one line: register the aggregate rows the query should return. To have it find nothing, register an empty list:

```apex
TST_Mock.registerAggregateRows(Opportunity.SObjectType, new List<Map<String, Object>>());
```

**Read a mocked aggregate query with `toAggregateList()` or `getFirstAggregate()`.** Once aggregate rows answer a query, `toList()`,
`getFirst()`, `getPage()`, `asMap()` and every other read that returns records throw a `UTIL_Exceptions.IllegalStateException` that
points you to `toAggregateList()`.

The `count()` that ends a query and returns a number is not an aggregate read. Like `toList()` on a query that does not aggregate, it is
answered by record mocks or by the database, never by aggregate rows.

**From the builder side.** `QRY_Builder.setAggregateMock(type, rows)` registers rows beside `QRY_Builder.setMock()`. Like `setMock`,
it replaces any rows set earlier for the object instead of adding to them:

```apex
QRY_Builder.setAggregateMock(Opportunity.SObjectType, new List<Map<String, Object>>
{
	new Map<String, Object>{ 'pipeline' => 250000 }
});
```

**Removing the rows.** `TST_Mock.clear()` removes every registration, aggregate rows included, and `TST_Mock.clear(type)` removes those for
one type. `TST_Mock.registerAggregateRows` does not take `null` as a way to clear: a `null` list throws. On the builder side,
`QRY_Builder.setAggregateMock(type, null)` removes the rows set for that type, and `QRY_Builder.clearMocks()` removes them along with every
other mock.

### Limitations

#### Which Query Conditions a Mock Checks

On a standard object (Account, Contact and so on) the mock checks the query in memory against the mock records: it
returns only the records that match the conditions, sorts them, and applies `LIMIT`. Some conditions it cannot check;
for those it returns every mock record:

```apex
// Mock accounts named 'Mock Account Technology', 'Mock Account Finance' and 'Mock Account Technology',
// each with the industry in its name
QRY_Builder.selectFrom(Account.SObjectType).condition(Account.Name).equals('Mock Account Finance').toList(); // 1 record
QRY_Builder.selectFrom(Account.SObjectType).orderBy(Account.Name).ascending().toList(); // Finance first
QRY_Builder.selectFrom(Account.SObjectType).withLimit(1).toList(); // 1 record

// A condition on a picklist field is checked too: 1 record
QRY_Builder.selectFrom(Account.SObjectType).condition(Account.Industry).equals('Finance').toList();
```

The mock skips the conditions, and applies only `LIMIT` and paging, when:

- the object is a custom object with no context class registered through `QRY_Builder.registerMockContextClass()`.
  API Call (`ApiCall__c`) and API Issue (`ApiIssue__c`) are custom objects with built-in context classes, so their mocks
  are checked with no registration;
- an `IN` or `NOT IN` list is too long. The mock checks a long list in several steps, up to a size. With 200 mocks or
  fewer, that is one list of 4,000 Ids on a field with a short name such as `Id`, or about 3,000 on a field with a long
  name such as `TriggeringRecordIndex__c`; or two lists of 280 Ids each (about 210 each on fields with long names). With
  1,000 mocks, it is one list of 800 Ids (about 600 on a long name). A condition too long to split, with no list in it
  or with one value too long on its own, is skipped too;
- a condition reads a field through a relationship, such as `Account.Owner.Name`, or uses `INCLUDES` or `EXCLUDES`;
- a condition compares a multi-select picklist field with a value, or asks whether a picklist field is greater or less
  than a value. A test of whether a multi-select picklist field is blank, or not blank, returns only the matching mocks.

If you need to test condition logic the mock does not check, either:

1. Use real database records
2. Pre-filter your mock data to match expected conditions

Rows registered for an aggregate query are different: only the query's `LIMIT` is applied to them (see
[Mocking an aggregate query](#mocking-an-aggregate-query)).

#### Mock Scope

Mocks are active for the **entire test transaction** until cleared. Always call `clearMocks()` in test cleanup or between test scenarios to prevent test pollution.

---

## Anti-Patterns

The common mistakes that cause trouble with selectors and queries:

| Anti-Pattern                                              | Why It's Wrong                                                                       | Instead                                                                                 |
|-----------------------------------------------------------|--------------------------------------------------------------------------------------|-----------------------------------------------------------------------------------------|
| Inline SOQL scattered across classes                      | Duplicates field lists, makes refactoring error-prone, and bypasses sharing controls | Use a custom `SEL_*` selector class                                                     |
| Business logic inside a selector                          | Selectors become untestable and violate single responsibility                        | Keep selectors pure: move logic to trigger actions or service classes                 |
| Querying inside a loop                                    | Causes SOQL governor limit exceptions on bulk operations                             | Collect IDs first, query once, then iterate over results                                |
| Ignoring sharing declarations                             | Runs queries with unpredictable sharing context inherited from the caller            | Always use `.withSharing()`, `.bypassSharing()`, or `.withUserMode()` explicitly        |
| Hardcoded field name strings in selectors                 | Breaks silently when fields are renamed or deleted                                   | Use `SObjectField` token references (e.g., `Account.Name`)                              |
| Using `QRY_Builder.selectFrom()` inside a selector method | Bypasses the selector's default fields and breaks reusability                        | Use the inherited `query` property which returns a pre-configured `QRY_Builder.Builder` |

---

## Best Practices

### **Always Use Selector Classes**

**DO:**

```apex
// Use selector methods
List<Account> accounts = new SEL_Accounts().findById(accountIds);
```

**DON'T:**

```apex
// Avoid inline SOQL
List<Account> accounts = [SELECT Name, Industry FROM Account WHERE Id IN :accountIds];
```

### **Read Through the Selector, Inside and Outside It**

Inside a selector class, always use the inherited `query` property. It hands you a `QRY_Builder.Builder` already set up with your default fields. Outside the selector, call its methods or its `query` property. If the object has no selector yet, write one.

**DO:**

```apex
// Inside a selector — uses default fields automatically
public List<Account> findCustomers()
{
	return query.condition(Account.Type).equals('Customer').toList();
}

// Outside the selector: one call replaces the field list for this query
List<Account> accounts = new SEL_Accounts().query
	.fields(new List<SObjectField>{Account.Name, Account.Industry})
	.condition(Account.Type).equals('Customer')
	.toList();
```

**DON'T:**

```apex
// Inside a selector — bypasses default fields
public List<Account> findCustomers()
{
	return QRY_Builder.selectFrom(Account.SObjectType)
		.fields(new List<SObjectField>{ Account.Name, Account.Industry })
		.condition(Account.Type).equals('Customer')
		.toList();
}
```

### **Create Custom Selector Classes for Each SObject**

Centralise all queries for an SObject in a dedicated selector class extending [SEL_Base](reference/apex/SEL_Base.md):

- `SEL_Contacts` for Contact queries
- `SEL_Accounts` for Account queries
- Define `getFields()` method for consistent field sets

### **Use Type-Safe Field References**

**DO:**

```apex
.condition(Account.Industry).equals('Technology')
.orderBy(Account.AnnualRevenue).descending()
```

**DON'T:**

```apex
.condition('Industy').equals('Technology') // String field names prone to typos
```

### **Be Explicit About Sharing**

Always explicitly set sharing when security is a concern:

```apex
// For queries in SYSTEM_MODE - enforce sharing (USER_MODE enforces it anyway)
.withSharing()

// For user-facing queries - full CRUD/FLS/sharing enforcement
.withUserMode()

// For system operations - bypass sharing (in USER_MODE the object and field checks still apply)
.bypassSharing()
```

### **Choose the Right Layer**

- **Every read:** extend [SEL_Base](reference/apex/SEL_Base.md) for each object you query.
    - Default fields, inherited `findById()`, `findByField()`
    - Custom query methods using the `query` property
    - Reusable, testable, mockable
- **Other fields for one query:** one call on the selector's `query` property.
    - Add fields with `addField`, `addFields`, `addFieldSet` or `relatedFields`
    - Replace the list with `fields` or `fieldSet`
- **[QRY_Builder](reference/apex/QRY_Builder.md):** the engine under every selector.
    - Its caching, pagination and result transformation are all reached through `query`

**Rule of thumb:** Every object you read gets a selector. When one query needs other fields, change them on the selector's `query` property instead of starting a new `QRY_Builder.selectFrom()`.

**Example:**

```apex
// Production — selector with default fields and reusable method
Account foundAccount = (Account)new SEL_Accounts().findById(accountId);
List<Account> techAccounts = (List<Account>)new SEL_Accounts().findByField(Account.Industry, 'Technology');

// One query needs another field: add it on the selector's query property
List<Account> accounts = new SEL_Accounts().query
	.addField(Account.NumberOfEmployees)
	.condition(Account.AnnualRevenue).greaterThan(1000000)
	.withSystemMode()
	.withSharing()
	.withCache(300)
	.toList();
```

### **Use QueryLocator for Batch Apex**

Always use `QRY_Builder.toQueryLocator()` in batch `start()` methods:

```apex
public Database.QueryLocator start(Database.BatchableContext context)
{
	return new SEL_Accounts().query
		.condition(Account.Type).equals('Customer')
		.toQueryLocator();
}
```

### **Avoid Query Loops**

**DO:**

```apex
// Query once, process many
Set<Id> accountIds = new Set<Id>();
for(Opportunity opportunity : opportunities)
{
	accountIds.add(opportunity.AccountId);
}
List<Account> accounts = new SEL_Accounts().findById(accountIds);
Map<Id, Account> accountMap = new Map<Id, Account>(accounts);
```

**DON'T:**

```apex
// Query inside loop - GOVERNOR LIMIT VIOLATION
for(Opportunity opportunity : opportunities)
{
	Account account = (Account)new SEL_Accounts().findById(opportunity.AccountId);
}
```

### **Test with [TST_Builder](reference/apex/TST_Builder.md)**

Use the builder pattern for test data creation:

```apex
@IsTest
private static void shouldReturnResults()
{
	Account testAccount = (Account)TST_Builder.of(Account.SObjectType)
		.withOverrides(new Map<SObjectField, Object>
		{
			Account.Industry => 'Technology',
			Account.AnnualRevenue => 1000000
		})
		.build();

	Test.startTest();
	List<Account> results = new SEL_Accounts().findByField(Account.Industry, 'Technology');
	Test.stopTest();

	Assert.isNotNull(results, 'Results should not be null');
}
```

### **Document Query Methods**

Give every query method full ApexDoc, so the next person knows what it returns and why:

```apex
/**
 * @description Finds the contacts that belong to the given accounts, sorted by last name.
 *
 * @param accountIds The Ids of the accounts whose contacts to read
 *
 * @return The contacts of those accounts, or an empty list when none are found
 *
 * @example
 * ```apex
 * Set<Id> accountIds = new Set<Id>{acc1.Id, acc2.Id};
 * List<Contact> contacts = new SEL_Contacts().findByAccountIds(accountIds);
 * ```
 */
public List<Contact> findByAccountIds(Set<Id> accountIds)
{
	return (List<Contact>)query
		.condition(Contact.AccountId).isIn(new List<Id>(accountIds))
		.orderBy(Contact.LastName).ascending()
		.toList();
}
```

### **Handle Null and Empty Collections**

**Option A: Manual validation (return early)**

```apex
// A method on your SEL_Contacts selector
public List<Contact> findByAccountIds(Set<Id> accountIds)
{
	if(accountIds == null || accountIds.isEmpty())
	{
		return new List<Contact>();
	}

	return query
		.fields(new List<SObjectField>{Contact.Id, Contact.Name})
		.condition(Contact.AccountId).isIn(new List<Id>(accountIds))
		.toList();
}
```

**Option B: Use safe empty collection handling (non-strict methods)**

The non-strict collection methods (`isIn()`, `notInSet()`, `includes()`, `excludes()`) handle empty/null collections safely:

| Method       | Empty/Null Behaviour                              |
|--------------|---------------------------------------------------|
| `isIn()`     | Returns zero results (adds impossible `Id` match) |
| `notInSet()` | Skips condition (excludes nothing)                |
| `includes()` | Skips condition (matches all)                     |
| `excludes()` | Skips condition (matches all)                     |

**Option C: Use strict methods to surface bugs**

When an empty collection indicates a programming error, use strict variants to fail fast:

```apex
// A method on your SEL_Contacts selector
public List<Contact> findByAccountIds(Set<Id> accountIds)
{
	// Throws IllegalArgumentException if accountIds is null or empty
	return query
		.fields(new List<SObjectField>{Contact.Id, Contact.Name})
		.condition(Contact.AccountId).isInStrict(new List<Id>(accountIds))
		.toList();
}
```

Strict methods: `isInStrict()`, `notInSetStrict()`, `includesStrict()`, `excludesStrict()`

### **Use Pagination for Large Result Sets**

Prevent governor limit issues with built-in pagination:

```apex
// Use getPage() for paginated results with metadata
QRY_Builder.QueryPage result = new SEL_Accounts().query
	.condition(Account.Type).equals('Customer')
	.getPage(1, 200); // Page 1, 200 records per page

// Access results and metadata
List<SObject> records = result.records;
Integer totalRecords = result.totalRecords;
Boolean hasMore = result.hasMorePages;
Integer deletedSinceCursorCreated = result.deletedRecords;
Database.PaginationCursor cursor = result.cursor;
```

Ask for page 1 or later, and for a page size between 1 and 2,000. A page holds at most 2,000 records, which is all Salesforce hands back in one fetch. Anything outside that range fails straight away rather than quietly returning something you did not ask for.

**When `cursor` is null.** `cursor` comes back null whenever the page was served without a pagination cursor:

- **Why:** usually more records match than the paging allowance left in the transaction. That allowance is 100,000 records today, and it is shared across every paged read you make in one go, so a second read has only what the first one left.
- **What still works:** those pages are fetched another way instead. Your records, `totalRecords`, and the page flags are all still correct, and only `deletedRecords` is unavailable, so it reads 0.
- **What to do:** check `cursor` for null before you pass it back for the next page.

One genuinely unreachable corner exists: after roughly fifty of these oversized paged reads in a single transaction, a page past row 2,000 can no longer be served by any route, and `getPage()` throws a `kern.UTIL_Exceptions.IllegalStateException` that says so. Spread the paged reads across transactions, or narrow the query.

### **Use Subqueries for Efficiency**

Use parent-to-child subqueries to reduce query count:

```apex
// ONE query returning accounts with contacts
List<Account> accountsWithContacts = getAccountsWithContacts(accountIds);

// Instead of TWO separate queries
List<Account> accounts = getAccounts(accountIds);
List<Contact> contacts = getContactsByAccountIds(accountIds);
```

---

## Related Documentation

- [Triggers - Guide](Triggers%20-%20Guide.md) - Trigger actions that use selectors for cross-object queries
- [DML - Guide](DML%20-%20Guide.md) - DML operations paired with selector queries
- [Validation - Guide](Validation%20-%20Guide.md) - Validation context classes that use selectors for bulk data loading
- [Logging - Guide](Logging%20-%20Guide.md) - Query performance logging and correlation tracking
- [Web Services - Guide](Web%20Services%20-%20Guide.md) - DTO population via selectors in API classes
