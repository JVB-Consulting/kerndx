---
navOrder: 12
---

# Fast Start - Selectors

**Framework:** KernDX | **Total time:** ~30 minutes

**What this is:** A way to keep every database query (SOQL) for an object in one reusable Apex class, so the same field lists and filters are used everywhere you read that object. **Why it exists:** When queries are scattered across the codebase, field lists drift, a renamed field breaks at runtime, and the same query gets rewritten over and over. Putting them in one place fixes all three: you get ready-made query methods you inherit for free, and the compiler catches a missing or renamed field before it ships. **Who should care:** Developers writing Apex queries, and tech leads who want consistent, testable data access. **When to use it:** Any time you query the same object from more than one place; for a true one-off, a quick inline query is fine.

> **Namespaces in code samples:** `kern.` on a class and `kern__` on an object, field, or metadata type mark the managed package's namespace.
> On the managed package, framework references need those prefixes even where a sample omits them; repackaged under your own namespace, replace `kern`/`kern__`
> with your prefix; on an unmanaged deploy, drop them. See [How to read the code samples](Installation.md#how-to-read-the-code-samples).

**What you'll build:** A reusable Account selector with inherited query methods (`findById`, `findByField`),
a custom `findByIndustry` filter, and an aggregate `revenueByIndustry` method, all without writing a
single line of SOQL.

**Success looks like:** You query Accounts through your selector class, get compile-time field validation,
and your test class has 100% coverage.

**In one line:** `List<Account> accounts = new SEL_Accounts().findByField(Account.Industry, 'Technology');` (no
SOQL, compile-time field safety, inherited from the base class).

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
    - [Query Records](#query-records)
    - [Add Conditions](#add-conditions)
    - [Check If Records Exist](#check-if-records-exist)
3. [Tier 2: Build Your Own (~15 minutes)](#tier-2-build-your-own-15-minutes)
    - [Step 1: Create the Selector](#step-1-create-the-selector)
    - [Step 2: Execute](#step-2-execute)
    - [Step 3: Write Tests](#step-3-write-tests)
4. [Tier 3: Production Patterns (~5 minutes)](#tier-3-production-patterns-5-minutes)
    - [Parent Field Access](#parent-field-access)
    - [Ordering and Limits](#ordering-and-limits)
    - [Convenience Terminal Methods](#convenience-terminal-methods)
    - [QRY_Builder for One-Off Queries](#qry_builder-for-one-off-queries)
    - [Security Modes](#security-modes)
    - [Compound Conditions](#compound-conditions)
    - [Date Literals](#date-literals)
    - [Data Category Filtering (Knowledge)](#data-category-filtering-knowledge)
    - [Multi-Field GROUP BY and ROLLUP](#multi-field-group-by-and-rollup)
    - [SOQL Functions (Date, toLabel, FORMAT)](#soql-functions-date-tolabel-format)
    - [Clean up](#clean-up)
5. [Common Issues](#common-issues)
    - [Step 1: Create the Selector](#step-1-create-the-selector-1)
    - [Step 2: Execute](#step-2-execute-1)
    - [Step 3: Write Tests](#step-3-write-tests-1)
    - [Parent Field Access](#parent-field-access-1)
    - [Clean up](#clean-up-1)
6. [What You Now Know](#what-you-now-know)
7. [Next Steps](#next-steps)

</details>

---

## Tier 1: See It Work (~2 minutes)

The fastest way to see the value is a query you can run right now, with nothing to set up first. Use
[`QRY_Builder`](reference/apex/QRY_Builder.md), the fluent query builder, directly from anonymous Apex. No
custom classes needed.

### Query Records

**In Salesforce**, open the Developer Console (the gear icon, then Developer Console), then Debug, then Open Execute
Anonymous Window, and run:

```apex
List<Account> accounts = kern.QRY_Builder.selectFrom(Account.SObjectType)
	.fields(new List<SObjectField>{ Account.Name, Account.Industry })
	.withLimit(5)
	.toList();

for(Account account : accounts)
{
	System.debug(account.Name + ' — ' + account.Industry);
}
```

You should see one line in the log for each Account, up to five, with its name and its industry. This line is from a
test org; yours lists your own Accounts:

```text
Sample Account for Entitlements — null
```

> **No Account records?** Insert one first:
> `insert new Account(Name = 'Quick Test', Industry = 'Technology', Phone = '555-0100', Website = 'https://example.com');`

### Add Conditions

**In Salesforce**, in the same Execute Anonymous window, run:

```apex
List<Account> techAccounts = kern.QRY_Builder.selectFrom(Account.SObjectType)
	.fields(new List<SObjectField>{ Account.Name, Account.Industry })
	.condition(Account.Industry).equals('Technology')
	.orderBy(Account.Name).ascending()
	.toList();

System.debug('Found ' + techAccounts.size() + ' Technology accounts');
```

### Check If Records Exist

**In Salesforce**, in the same Execute Anonymous window, run:

```apex
Boolean hasAccounts = kern.QRY_Builder.selectFrom(Account.SObjectType)
	.condition(Account.Industry).equals('Technology')
	.exists();

System.debug('Has Technology accounts: ' + hasAccounts);
```

> **When to move to Tier 2:** When you query the same object from multiple places and want consistent field
> lists, reusable query methods, and compile-time safety.

---

## Tier 2: Build Your Own (~15 minutes)

> **No local project?** You can create classes directly in the Developer Console (Gear Icon > Developer
> Console > File > New > Apex Class) and run tests from there too (Test > New Run). Paste the code, save,
> and skip the terminal commands.

Now you'll put the queries for one object in their own class so the rest of your code can reuse them. You'll
build a selector for the Account object: it inherits ready-made query methods and adds a custom
`findByIndustry` method of your own.

### Step 1: Create the Selector

The selector is one class that holds the queries for the Account object. You create an empty class with one command,
paste the code into it, then send it to your org.

**1. In the terminal**, from your project's top folder, create the empty class:

```shell
sf apex generate class --name SEL_Accounts --output-dir force-app/main/default/classes
```

You should see two files created in `force-app/main/default/classes`: `SEL_Accounts.cls` and its companion of the
same name ending in `.cls-meta.xml`.

The second file tells Salesforce which API version the class uses. You never edit it, but a deploy fails without it.

**2. In your editor**, open this file, delete what is there, paste the code below in, and save. Paste it exactly as
it is: keep the class name.

```text
force-app/main/default/classes/SEL_Accounts.cls
```

> **Why `public`?** Unlike triggers and APIs, selectors are instantiated directly by your code (`new
> SEL_Accounts()`). The framework never has to look them up by name, so `public` is enough and `global` is
> not required.

> **Why `kern.SEL_Base` (with prefix) but `SEL_Accounts` (no prefix)?** `SEL_Base` is a framework class
> (documented under `docs/reference/apex/`), so it needs the `kern.` prefix to be reachable from your own
> namespace. Your own `SEL_Accounts` lives in your namespace, so adding `kern.` to it throws
> `Invalid type: kern.SEL_Accounts`. The decision rule is short: **framework classes (the ones in the API
> reference) take the prefix; your own classes never do.** See
> [AI Agent Instructions](AI%20Agent%20Instructions.md#critical--namespace-prefix-rule) for the canonical rule.

```apex
/**
 * @description Selector methods for the Account object.
 *
 * @see SEL_Accounts_TEST
 *
 * @author your.name@company.com
 *
 * @group Selectors
 *
 * @date February 2026
 */
// Subscriber selectors default to `with sharing` — the safest default. Framework-internal selectors
// inside the kern namespace use `inherited sharing` to follow the caller's sharing context.
public with sharing class SEL_Accounts extends kern.SEL_Base
{
	/**
	 * @description Constructs the selector for Account.
	 */
	public SEL_Accounts()
	{
		super(Account.SObjectType);
	}

	/**
	 * @description Returns the default fields for all Account queries.
	 *
	 * @return List of Account SObjectField tokens.
	 */
	public override List<SObjectField> getFields()
	{
		return new List<SObjectField>
		{
			Account.Name,
			Account.Industry,
			Account.AnnualRevenue,
			Account.Phone,
			Account.BillingCity
		};
	}

	/**
	 * @description Finds accounts by industry.
	 *
	 * @param industry The industry to filter by.
	 *
	 * @return List of Account records matching the industry.
	 */
	// The query property is inherited from SEL_Base — returns a fresh QRY_Builder.Builder pre-configured
	// with your SObjectType and default fields
	public List<Account> findByIndustry(String industry)
	{
		return query
			.condition(Account.Industry).equals(industry)
			.orderBy(Account.Name).ascending()
			.toList();
	}

	/**
	 * @description Returns aggregate revenue totals grouped by industry.
	 *
	 * @return List of aggregate rows with Industry and summed AnnualRevenue.
	 */
	public List<kern.QRY_Builder.AggregateRow> revenueByIndustry()
	{
		return query
			.groupBy(Account.Industry)
			.sum(Account.AnnualRevenue)
			.toAggregateList();
	}
}
```

**3. In the terminal**, send the class to your org:

```shell
sf project deploy start -o YourOrgAlias -m "ApexClass:SEL_Accounts"
```

You should see `Status: Succeeded`, with `SEL_Accounts` listed as created.

Something went wrong? See [Common Issues, Step 1](#step-1-create-the-selector-1).

### Step 2: Execute

Try the selector from anonymous Apex. The code inserts an `Acme Corp` Account, then reads Accounts back four ways.

**In Salesforce**, open the Developer Console (the gear icon, then Developer Console), then Debug, then Open Execute
Anonymous Window, and run:

```apex
// Insert a test record if needed (DML_Builder, not inline `insert`)
kern.DML_Builder.newTransaction()
	.doInsert(new Account(Name = 'Acme Corp', Industry = 'Technology', AnnualRevenue = 500000, Phone = '555-0100', Website = 'https://example.com'))
	.execute();

// Use inherited findById — returns SObject, cast to Account. Grab any Account via QRY_Builder.
Id accountId = kern.QRY_Builder.selectFrom(Account.SObjectType).getFirst().Id;
Account result = (Account)new SEL_Accounts().findById(accountId);
System.debug('findById: ' + result.Name + ' — ' + result.Industry);

// Use inherited findByField
List<Account> techAccounts = new SEL_Accounts().findByField(Account.Industry, 'Technology');
System.debug('findByField: ' + techAccounts.size() + ' Technology accounts');

// Use custom findByIndustry
List<Account> results = new SEL_Accounts().findByIndustry('Technology');
System.debug('findByIndustry: ' + results.size() + ' results');

// Use aggregate revenueByIndustry
List<kern.QRY_Builder.AggregateRow> rows = new SEL_Accounts().revenueByIndustry();
for(kern.QRY_Builder.AggregateRow row : rows)
{
	System.debug('Industry: ' + row.getString('Industry') + ' Revenue: ' + row.getDecimal('sum_AnnualRevenue'));
}
```

> **Naming tip:** Apex is case-insensitive. A variable named `account` shadows the `Account` type, which makes
> `Account.Industry` read the variable's field instead of the SObjectField token. Pick another name such as
> `result` or `found`.

You should see lines like these in the log. They are from a test org, so yours differ in two ways. The `findById` line
names whichever Account the first query found, which may not be the one you just inserted. The counts include every
Technology Account your org already holds, and the revenue lines every Account, with Accounts that have no industry
adding an `Industry: null` line:

```text
findById: Sample Account for Entitlements — null
findByField: 1 Technology accounts
findByIndustry: 1 results
Industry: null Revenue: null
Industry: Technology Revenue: 500000.0
```

**Why it works (the key patterns):**

- **`extends kern.SEL_Base`**: provides `findById()`, `findByField()`, `query`, `toList()`, `count()`, and more
- **`super(Account.SObjectType)`**: tells the base class which object to query
- **`getFields()`**: defines the default field list for every query from this selector. It uses `SObjectField`
  tokens for compile-time validation, so a renamed field breaks at compile, not at runtime.
- **`query` property**: returns a pre-configured `QRY_Builder.Builder` with your default fields. Always use
  this inside custom query methods, never `QRY_Builder.selectFrom()` (which skips your default fields).
- **Aggregate queries**: chain `.groupBy()` + `.sum()` + `.toAggregateList()` on the same `query` property.
  Access results via `AggregateRow.getString('fieldName')` and `AggregateRow.getDecimal('sum_fieldName')`.
- **Cast results**: `findById()` returns `SObject`, so cast to `Account`

Something went wrong? See [Common Issues, Step 2](#step-2-execute-1).

### Step 3: Write Tests

The test class has four tests: one that checks `findById` brings back your default fields, two for `findByIndustry`
(a match and none) and one for `revenueByIndustry`. You create the empty class with one command, paste the code into
it, send it to your org, then run it.

**1. In the terminal**, from your project's top folder, create the empty test class:

```shell
sf apex generate class --name SEL_Accounts_TEST --output-dir force-app/main/default/classes
```

You should see two files created in `force-app/main/default/classes`: `SEL_Accounts_TEST.cls` and its companion of
the same name ending in `.cls-meta.xml`.

**2. In your editor**, open this file, delete what is there, paste the code below in exactly as it is, and save:

```text
force-app/main/default/classes/SEL_Accounts_TEST.cls
```

```apex
/**
 * @description Unit tests for SEL_Accounts.
 *
 * @see SEL_Accounts
 *
 * @author your.name@company.com
 *
 * @group Selectors
 *
 * @date February 2026
 */
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest(isParallel=true)
private class SEL_Accounts_TEST
{
	/** @description Tests that findById returns the correct account. */
	@IsTest
	private static void shouldReturnAccountById()
	{
		Account account = (Account)kern.TST_Builder.of(Account.SObjectType)
			.withOverride(Account.Name, 'Test Company')
			.withOverride(Account.Industry, 'Technology')
			.build();

		Account result = (Account)new SEL_Accounts().findById(account.Id);

		Assert.isNotNull(result, 'Should return account');
		Assert.areEqual(account.Id, result.Id, 'Should return correct account');
		Assert.areEqual('Technology', result.Industry, 'Should include default fields');
	}

	/** @description Tests that findByIndustry returns matching accounts. */
	@IsTest
	private static void shouldReturnAccountsByIndustry()
	{
		kern.TST_Builder.of(Account.SObjectType)
			.withOverride(Account.Name, 'Tech Co')
			.withOverride(Account.Industry, 'Technology')
			.build();
		kern.TST_Builder.of(Account.SObjectType)
			.withOverride(Account.Name, 'Bank Co')
			.withOverride(Account.Industry, 'Finance')
			.build();

		List<Account> results = new SEL_Accounts().findByIndustry('Technology');

		Assert.areEqual(1, results.size(), 'Should return only Technology account');
		Assert.areEqual('Tech Co', results[0].Name, 'Should return correct account');
	}

	/** @description Tests that findByIndustry returns empty list when no matches. */
	@IsTest
	private static void shouldReturnEmptyListWhenNoMatches()
	{
		kern.TST_Builder.of(Account.SObjectType)
			.withOverride(Account.Name, 'Test Co')
			.withOverride(Account.Industry, 'Technology')
			.build();

		List<Account> results = new SEL_Accounts().findByIndustry('Healthcare');

		Assert.isTrue(results.isEmpty(), 'Should return empty list');
	}

	/** @description Tests that revenueByIndustry returns aggregate rows with summed revenue. */
	@IsTest
	private static void shouldReturnRevenueAggregateByIndustry()
	{
		kern.TST_Builder.of(Account.SObjectType)
			.withOverride(Account.Name, 'Tech A')
			.withOverride(Account.Industry, 'Technology')
			.withOverride(Account.AnnualRevenue, 200000)
			.build();
		kern.TST_Builder.of(Account.SObjectType)
			.withOverride(Account.Name, 'Tech B')
			.withOverride(Account.Industry, 'Technology')
			.withOverride(Account.AnnualRevenue, 300000)
			.build();

		List<kern.QRY_Builder.AggregateRow> rows = new SEL_Accounts().revenueByIndustry();

		Assert.areEqual(1, rows.size(), 'Should return exactly one aggregate row — only Technology was inserted');
		kern.QRY_Builder.AggregateRow row = rows[0];
		Assert.areEqual('Technology', row.getString('Industry'), 'Industry should be Technology');
		Assert.areEqual(500000, row.getDecimal('sum_AnnualRevenue'), 'Revenue should sum to 500000 (200000 + 300000)');
	}
}
```

**3. In the terminal**, send the test class to your org:

```shell
sf project deploy start -o YourOrgAlias -m "ApexClass:SEL_Accounts_TEST"
```

You should see `Status: Succeeded`, with `SEL_Accounts_TEST` listed as created.

**4. In the terminal**, run the test:

```shell
sf apex run test -o YourOrgAlias -t SEL_Accounts_TEST --code-coverage --synchronous --result-format human
```

You should see 4 tests passing and 100% coverage on `SEL_Accounts`: all four tests show `Pass`, the summary line
`Outcome` reads `Passed`, and the coverage table shows `SEL_Accounts` at `100%`.

You only need to test the custom methods you add. The inherited methods (`findById()`, `findByField()`, and the
rest) are already tested by the framework, so don't re-test them.

> **About the annotations:** `@IsTest(isParallel=true)` enables parallel test execution (faster runs).
> `SeeAllData` defaults to `false`, so we omit it. `@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')`
> turns off a static analysis rule (a check that reads your code without running it) about `System.runAs()`.
> That's fine for quick starts, but in production tests consider adding `System.runAs()` to verify profile and
> permission set access.

Something went wrong? See [Common Issues, Step 3](#step-3-write-tests-1).

---

## Tier 3: Production Patterns (~5 minutes)

These patterns build on the `SEL_Accounts` class you created in Tier 2.

### Parent Field Access

Often you need a field from a parent record, such as the account owner's name or email. To pull those in for
every query, override `getFieldPaths()` in `SEL_Accounts` and list the relationship fields you always want.

**In your editor**, in `SEL_Accounts.cls`:

```apex
// Add this method to SEL_Accounts.cls (after getFields())
public override List<String> getFieldPaths()
{
	return new List<String>{ 'Owner.Name', 'Owner.Email' };
}
```

For one-off relationship fields in a specific query method, add a new method to `SEL_Accounts`.

**In your editor**, in `SEL_Accounts.cls`:

```apex
// Add this method to SEL_Accounts.cls
public List<Account> findByTypeWithOwner(String accountType)
{
	return query
		.addFields(new List<String>{ 'Owner.Name', 'Owner.Email' })
		.condition(Account.Type).equals(accountType)
		.toList();
}
```

Send the class to your org again with the deploy command from Step 1, then check the owner fields come back.

**In Salesforce**, in an Execute Anonymous window, run:

```apex
Account result = (Account)new SEL_Accounts().findById(
	kern.QRY_Builder.selectFrom(Account.SObjectType).getFirst().Id
);
System.debug('Account: ' + result.Name);
System.debug('Owner: ' + result.getSObject('Owner').get('Name'));
```

Something went wrong? See [Common Issues, Parent Field Access](#parent-field-access-1).

### Ordering and Limits

To sort results and cap how many come back (for example, the top few accounts in an industry), chain
`.orderBy()` and `.withLimit()`. Add this method to `SEL_Accounts`.

**In your editor**, in `SEL_Accounts.cls`:

```apex
// Add this method to SEL_Accounts.cls
public List<Account> findTopByIndustry(String industry, Integer maxResults)
{
	return query
		.condition(Account.Industry).equals(industry)
		.orderBy(Account.Name).ascending()
		.withLimit(maxResults)
		.toList();
}
```

Send the class to your org again, then try the method.

**In Salesforce**, in an Execute Anonymous window, run:

```apex
List<Account> topTech = new SEL_Accounts().findTopByIndustry('Technology', 3);
System.debug('Top 3 Technology accounts: ' + topTech.size());

for(Account each : topTech)
{
	System.debug('  ' + each.Name);
}
```

### Convenience Terminal Methods

The `query` property returns a `QRY_Builder.Builder` with many terminal methods beyond `toList()`. Try these with
the `SEL_Accounts` you deployed in Tier 2.

**In Salesforce**, in an Execute Anonymous window, run:

```apex
SEL_Accounts selector = new SEL_Accounts();

// First record or null
Account first = (Account)selector.query
	.condition(Account.Industry).equals('Technology').getFirst();
System.debug('First: ' + (first != null ? first.Name : 'none'));

// Count (no records loaded into memory)
Integer accountCount = selector.query
	.condition(Account.Industry).equals('Technology').count();
System.debug('Count: ' + accountCount);

// Exists check (no record loading — most efficient)
Boolean hasAccounts = selector.query
	.condition(Account.Industry).equals('Technology').exists();
System.debug('Exists: ' + hasAccounts);

// Map keyed by Id
Map<Id, SObject> accountMap = selector.query
	.condition(Account.Industry).equals('Technology').asMap();
System.debug('Map size: ' + accountMap.size());

// Map keyed by an arbitrary field (typed-token or string overload)
// Useful when you need Map<Id, Contact> keyed by Contact.AccountId, etc.
Map<Id, SObject> contactsByAccount = kern.QRY_Builder.selectFrom(Contact.SObjectType)
	.fields(new List<SObjectField>{ Contact.Id, Contact.AccountId })
	.condition(Contact.AccountId).isNotNull()
	.asMapById(Contact.AccountId);

// Grouped map preserves duplicates (Map<Id, List<Contact>>)
Map<Id, List<SObject>> contactsGroupedByAccount = kern.QRY_Builder.selectFrom(Contact.SObjectType)
	.fields(new List<SObjectField>{ Contact.Id, Contact.AccountId })
	.condition(Contact.AccountId).isNotNull()
	.asGroupedMapById(Contact.AccountId);

// String-keyed variants for non-Id keys (e.g. unique Account name)
Map<String, SObject> accountByName = kern.QRY_Builder.selectFrom(Account.SObjectType)
	.fields(new List<SObjectField>{ Account.Name })
	.asMapByString(Account.Name);
```

### QRY_Builder for One-Off Queries

Use `QRY_Builder.selectFrom()` directly when you don't need a full selector class: handy for one-off scripts,
anonymous Apex, or querying an object you don't have a selector for.

**In Salesforce**, in an Execute Anonymous window, run:

```apex
// Find Contacts related to a set of Accounts
Set<Id> accountIds = kern.QRY_Builder.selectFrom(Account.SObjectType)
	.condition(Account.Industry).equals('Technology')
	.asIdSet();

List<Contact> contacts = kern.QRY_Builder.selectFrom(Contact.SObjectType)
	.fields(new List<SObjectField>{ Contact.LastName, Contact.Email, Contact.AccountId })
	.condition(Contact.AccountId).isIn(accountIds)
	.orderBy(Contact.LastName).ascending()
	.toList();

System.debug('Found ' + contacts.size() + ' contacts for Technology accounts');
```

> **Rule of thumb:** If you query the same object from two or more places, create a selector. If it's a one-off,
> use `QRY_Builder.selectFrom()` directly.

### Security Modes

By default, a query only returns what the person running it is allowed to see, and only writes what they are
allowed to write. You don't switch that protection on; it is on automatically, and you step outside it only by
deliberate choice.

In Salesforce terms, every `kern.QRY_Builder` query runs in USER_MODE: it respects the current user's
read/write permissions and record sharing (CRUD = object create/read/update/delete permissions, FLS =
field-level security, plus sharing), unless a caller explicitly opts out. The default behaviour is set by the
`UserModeQueries_Enabled` feature flag (`IsEnabledByDefault__c = true` at install time).

**In Salesforce**, run these in an Execute Anonymous window to compare:

```apex
// Default — USER_MODE enforced (CRUD, FLS, and sharing respected)
List<Account> defaultQuery = kern.QRY_Builder.selectFrom(Account.SObjectType)
	.fields(new List<SObjectField>{ Account.Name })
	.withLimit(5)
	.toList();
System.debug('Default (USER_MODE): ' + defaultQuery.size() + ' accounts');

// Explicit SYSTEM_MODE opt-out (framework-internal use; rare in subscriber code)
List<Account> allAccounts = kern.QRY_Builder.selectFrom(Account.SObjectType)
	.fields(new List<SObjectField>{ Account.Name })
	.withSystemMode()
	.withLimit(5)
	.toList();
System.debug('SYSTEM_MODE (bypass): ' + allAccounts.size() + ' accounts');

// Strip inaccessible -- removes fields the user can't see (post-query, complements USER_MODE)
List<Account> stripped = kern.QRY_Builder.selectFrom(Account.SObjectType)
	.fields(new List<SObjectField>{ Account.Name, Account.Phone })
	.stripInaccessible()
	.withLimit(5)
	.toList();
System.debug('Strip inaccessible: ' + stripped.size() + ' accounts');
```

> **Note:** As an admin you'll often see USER_MODE and SYSTEM_MODE return the same rows, because an admin
> already holds every permission. The difference only shows up when you run as a lower-permission user (for
> example via `System.runAs()` in tests). Your own code should almost never need `.withSystemMode()`. It is
> reserved for framework-internal reads that must bypass the running user's permissions, such as audit tables
> and configuration metadata. If a selector genuinely must run in SYSTEM_MODE, subclass `kern.SEL_Base` and
> override `systemModeRequired()` to return `true`. That keeps the opt-out in one selector rather than
> scattered across call sites.
>
> **Kill switch:** if you need to turn this off org-wide during an incident without a deployment, deploy an org
> override of `kern__FeatureFlag.UserModeQueries_Enabled` with `IsEnabledByDefault__c = false` to fall back to
> SYSTEM_MODE framework-wide. Use it for emergencies only, while the offending code is being fixed.

### Compound Conditions

The chained `.condition()` / `.andCondition()` / `.orCondition()` methods handle most queries. When you need
grouped logic, such as `WHERE Industry = 'Tech' AND (Status = 'Active' OR Status = 'Pending')`, use
`OrCondition` / `AndCondition` with `.addCondition()`.

**In your editor**, in your own Apex:

```apex
// Build an OR group
kern.QRY_Condition.OrCondition typeGroup = new kern.QRY_Condition.OrCondition();
typeGroup.add(new kern.QRY_Condition.FieldCondition(
	Account.Type, kern.QRY_Condition.Operator.EQUALS, 'Customer - Direct'
));
typeGroup.add(new kern.QRY_Condition.FieldCondition(
	Account.Type, kern.QRY_Condition.Operator.EQUALS, 'Customer - Channel'
));

// Pass the group into the query
List<Account> results = kern.QRY_Builder.selectFrom(Account.SObjectType)
	.fields(new List<SObjectField>{ Account.Name, Account.Type })
	.condition(Account.Industry).equals('Technology')
	.addCondition(typeGroup)
	.toList();
// WHERE Industry = 'Technology' AND (Type = 'Customer - Direct' OR Type = 'Customer - Channel')
```

### Date Literals

To filter on a moving date range (records from today, or the last several days) without hardcoding a date, use
`DateLiteral` for relative date conditions (TODAY, LAST_N_DAYS, and so on).

**In your editor**, in your own Apex:

```apex
List<Account> recentAccounts = kern.QRY_Builder.selectFrom(Account.SObjectType)
	.fields(new List<SObjectField>{ Account.Name })
	.condition(Account.CreatedDate).greaterThan(
		new kern.QRY_Condition.DateLiteral().lastNDays(30)
	)
	.toList();
```

Other date literal methods: `.today()`, `.yesterday()`, `.tomorrow()`, `.last90Days()`, `.next90Days()`,
`.thisUnit(kern.QRY_Condition.UnitOfTime.QUARTER)`, `.last(n, UnitOfTime)`, `.next(n, UnitOfTime)`.

### Data Category Filtering (Knowledge)

Query Knowledge articles by data category using `.withDataCategory(groupName)` followed by an operator.

**In your editor**, in your own Apex:

```apex
List<SObject> articles = kern.QRY_Builder.selectFrom(KnowledgeArticleVersion.SObjectType)
	.fields(new List<String>{'Id', 'Title'})
	.condition('PublishStatus').equals('Online')
	.condition('Language').equals('en_US')
	.withDataCategory('Product__c').below('Electronics__c')
	.toList();
```

Operators: `.at()` (exact), `.above()` (ancestors), `.below()` (descendants), `.aboveOrBelow()` (both). Chain multiple
`.withDataCategory()` calls for different groups (joined with AND). Knowledge queries require `PublishStatus` in WHERE.

See [Data Category Queries in the Selectors Guide](Selectors%20-%20Guide.md#data-category-queries) for full details.

### Multi-Field GROUP BY and ROLLUP

Call `.groupBy()` multiple times for multi-dimensional aggregation. Add `.rollup()` for subtotals or `.cube()` for
cross-tabulation.

**In your editor**, in your own Apex:

```apex
List<kern.QRY_Builder.AggregateRow> results = kern.QRY_Builder.selectFrom(Opportunity.SObjectType)
	.groupBy(Opportunity.StageName)
	.groupBy(Opportunity.LeadSource)
	.grouping(Opportunity.StageName)
	.sum(Opportunity.Amount)
	.rollup()
	.toAggregateList();
```

### SOQL Functions (Date, toLabel, FORMAT)

The 13 SOQL date functions have typed `QRY_Function` factories (`calendarYear`, `calendarMonth`, `fiscalQuarter`, …) for use with `addField` / `groupBy` / `orderBy`. The `toLabel()` and
`FORMAT()` functions work through string overloads.

**In your editor**, in your own Apex:

```apex
kern.QRY_Builder.selectFrom(Opportunity.SObjectType)
	.addField(kern.QRY_Function.calendarYear(Opportunity.CloseDate), 'yearNumber')
	.groupBy(kern.QRY_Function.calendarYear(Opportunity.CloseDate))
	.sum(Opportunity.Amount)
	.toAggregateList();
```

See [SOQL Functions in the Selectors Guide](Selectors%20-%20Guide.md#soql-functions-in-queries) for all 13 date
functions, toLabel, and FORMAT examples.

### Clean up

If you built this example only to try the framework, run this command when you have finished the guide. The
`Acme Corp` Accounts that Step 2 inserted stay, and so does the `Quick Test` Account if you inserted it in Tier 1;
delete them in the app, or leave them.

**In the terminal**, delete the selector and its test class:

```shell
sf project delete source -o YourOrgAlias -m "ApexClass:SEL_Accounts_TEST" -m "ApexClass:SEL_Accounts" --no-prompt
```

You should see `Status: Succeeded`, then a `Deleted Source` table listing the two classes.

The command deletes the files from your project too.

Something went wrong? See [Common Issues](#clean-up-1).

---

## Common Issues

Trouble with your computer rather than this guide (`sf` is not recognised, scripts are disabled, you are not logged
in, the wrong folder)? Those are answered once, in
[Set Up Your Computer](Set%20Up%20Your%20Computer.md#if-something-went-wrong).

### Step 1: Create the Selector

#### The deploy says there is nothing to deploy

The deploy stops with `No source-backed components present in the package.` The command ran inside another project's
folder, so the CLI looked for the class there and found nothing. Open the terminal in your own project's top folder,
the one that holds `sfdx-project.json`, and run the command again.

#### `@Override specified for non-overriding method`

The deploy fails with this message, naming `getFields()`. The class does not extend `kern.SEL_Base`, so it has no
`getFields()` to override and no inherited `query` property for your methods to use. Add `extends kern.SEL_Base` to
the class line and keep `super(Account.SObjectType)` in the constructor, as in the code in Step 1.

### Step 2: Execute

#### `Method does not exist or incorrect signature: void findByField(String, String) from the type SEL_Accounts`

The code stops before it runs. A variable named `account` shadows the `Account` type (Apex ignores case), so
`Account.Industry` reads that variable's field instead of the field token. Rename the variable, for example to
`result` or `found`, as the naming tip in Step 2 says.

#### `System.NullPointerException: Attempt to de-reference a null object`

Step 2's code always passes the Id of an Account that exists, so you meet this in your own code, when you call
`findById()` with an Id that matches no record. `findById()` then returns `null`, and reading a field of `null`
fails. Check for `null` before you use the result, or call `findByIdOrThrow()` instead: it stops with a message that
starts `Account record not found:` and names the Id, which tells you straight away what was missing.

### Step 3: Write Tests

#### The deploy fails

The test class's deploy fails for the same reasons as the selector's; see the entries under
[Step 1](#step-1-create-the-selector-1).

#### The coverage table shows `SEL_Accounts` below `100%`

A method you added to the selector has no test. Add a test that calls each custom method and asserts the results.
You only need tests for the methods you write: the framework already tests the inherited ones.

### Parent Field Access

#### `SObject row was retrieved via SOQL without querying the requested field`

The code read a field that the query did not fetch, and the message ends with that field. `Account.Owner` means the
check ran before you added `getFieldPaths()` to the selector and sent it to your org again. Any other field means it
is missing from `getFields()`, or a method built its query with `QRY_Builder.selectFrom()`, which starts without your
default fields (the message ends `Account.Industry` when that happens with the guide's selector).

- Add the field to `getFields()`, or add it with `.addField()` in that one query method.
- Name a parent's fields, such as `Owner.Name`, in `getFieldPaths()` or with `.addFields(List<String>)`: a field
  token cannot reach a field on a parent record.
- Inside a selector, start every query from the inherited `query` property, which includes your default fields.

### Clean up

#### `No ApexClass named: SEL_Accounts found`

The command shows `Status: Failed` and a `Component Failures` table with this line, and the same for
`SEL_Accounts_TEST`. The org no longer holds the classes: the clean-up already ran, or they were deleted another way.
There is nothing left to delete.

Still stuck? [Tell us](https://github.com/JVB-Consulting/kerndx/issues/new?template=bug_report.md&title=%5Bdocs%5D%20Selectors) which step and what you saw.

## What You Now Know

After completing this guide, you understand the **selector pattern** in KernDX:

| Concept               | What It Does                                                                 |
|-----------------------|------------------------------------------------------------------------------|
| **`SEL_Base`**        | Base class for all selectors; provides inherited query methods               |
| **`getFields()`**     | Defines default fields for every query (compile-time validated)              |
| **`query` property**  | Pre-configured `QRY_Builder.Builder` with your default fields                |
| **`QRY_Builder`**     | Fluent query builder for ad-hoc queries without a selector                   |
| **Inherited methods** | `findById()`, `findByField()`, `toList()`, `count()`, `exists()`; all free   |

**Key patterns:**

- **One class per object**: all queries for an object go through its `SEL_*` class
- **`with sharing`**: the default this guide uses for your own selectors (framework-internal selectors use `inherited sharing`)
- **`SObjectField` tokens**: compile-time field validation, no hardcoded strings
- **`query` property**: always use inside selectors (not `QRY_Builder.selectFrom()`)
- **Cast results**: `findById()` returns `SObject`, cast to your specific type
- **`public`**: selectors are directly instantiated, so `global` is not required

---

## Next Steps

- [DML Builder (writes)](Fast%20Start%20-%20DML.md)
- [Test Data Patterns](Fast%20Start%20-%20Test%20Data.md)
- [Code Scanning (catch SOQL anti-patterns)](Fast%20Start%20-%20Code%20Scanning.md)
- [Complete Selectors Guide](Selectors%20-%20Guide.md)
- [QRY_Builder Reference](reference/apex/QRY_Builder.md)
- [SEL_Base Reference](reference/apex/SEL_Base.md)
