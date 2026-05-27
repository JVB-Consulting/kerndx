# Fast Start - DML

**Framework:** KernDX | **Total time:** ~30 minutes

> Replace direct DML (`insert`, `update`, `delete`) with a fluent builder that handles error logging,
> parent-child relationships, partial success, and sharing control.

**Before you start:**

- [ ] KernDX package installed in your org
- [ ] Org configured post-install — verify with the **Kern** app's Health Check (see [Installation guide](Installation.md#post-install-configuration))
- [ ] CLI authenticated (`sf org open -o YourOrgAlias` to verify) — or just use the Developer Console
  (Gear Icon > Developer Console) for all Apex work
- [ ] Working in a sandbox or scratch org (not production)

**What you'll build:** A service class that creates an Account with related Contacts and an Opportunity
in a single atomic transaction -- with automatic parent-child foreign key resolution.

**Success looks like:** You call your service, verify the Account and its children were created with correct
relationships, and your test class has 100% coverage.

**In one line:** `kern.DML_Builder.newTransaction().doInsert(newAccount).doInsert(newContact, Contact.AccountId, newAccount).execute();` --
parent-child foreign keys are resolved automatically.

---

## Table of Contents

<details>
<summary>Expand</summary>

1. [Tier 1: See It Work (~2 minutes)](#tier-1-see-it-work-2-minutes)
   - [Insert a Record](#insert-a-record)
   - [Update a Record](#update-a-record)
   - [Parent-Child Insert](#parent-child-insert)
2. [Tier 2: Build Your Own (~20 minutes)](#tier-2-build-your-own-20-minutes)
   - [Step 1: Create the Service Class](#step-1-create-the-service-class)
   - [Step 2: Execute](#step-2-execute)
   - [Step 3: Write Tests](#step-3-write-tests)
3. [Tier 3: Production Patterns (~5 minutes)](#tier-3-production-patterns-5-minutes)
   - [All DML Operations](#all-dml-operations)
   - [TransactionResult](#transactionresult)
   - [Partial Success](#partial-success)
   - [Security, Sharing, Suppression, and Async](#security-sharing-suppression-and-async)
4. [Common Issues](#common-issues)
5. [What You Now Know](#what-you-now-know)
6. [Next Steps](#next-steps)

</details>

---

## Tier 1: See It Work (~2 minutes)

Use [`DML_Builder`](reference/apex/DML_Builder.md) directly from anonymous Apex. No custom classes needed.

### Insert a Record

Open **Developer Console > Debug > Open Execute Anonymous Window** and run:

```apex
Account account = new Account(Name = 'Quick Test', Phone = '555-0100');

kern.DML_Builder.TransactionResult result = kern.DML_Builder.newTransaction()
	.doInsert(account)
	.execute();

System.debug('Success: ' + result.isSuccess());
System.debug('Account Id: ' + account.Id);
System.debug('Inserted IDs: ' + result.getInsertedIds());
```

**Expected output** (ID will vary):

```text
Success: true
Account Id: 001...
Inserted IDs: (001...)
```

### Update a Record

```apex
Account found = (Account)kern.QRY_Builder.selectFrom(Account.SObjectType)
	.fields(new List<SObjectField>{ Account.Name, Account.Industry })
	.condition(Account.Name).equals('Quick Test')
	.getFirst();

found.Industry = 'Technology';

kern.DML_Builder.newTransaction()
	.doUpdate(found)
	.execute();

System.debug('Updated Industry: ' + found.Industry);
```

### Parent-Child Insert

Insert an Account and a Contact in one transaction -- the Contact's `AccountId` is auto-populated:

```apex
Account newAccount = new Account(Name = 'Parent Co', Phone = '555-0100');
Contact newContact = new Contact(LastName = 'Smith', FirstName = 'Jane');

kern.DML_Builder.newTransaction()
	.doInsert(newAccount)
	// .doInsert(child, lookupField, parent) — framework sets child.lookupField = parent.Id after parent insert
	.doInsert(newContact, Contact.AccountId, newAccount)
	.execute();

System.debug('Account Id: ' + newAccount.Id);
System.debug('Contact AccountId: ' + newContact.AccountId);
```

**Expected output:**

```text
Account Id: 001...
Contact AccountId: 001...
```

The Contact's `AccountId` matches the Account's `Id` -- set automatically by the framework.

> **Naming tip:** Don't name a variable `contact` (lowercase) in anonymous Apex when using `Contact.AccountId`
> -- the variable shadows the SObject type, and `Contact.AccountId` resolves as a field value (Id) instead of
> a field token (SObjectField). Use `newContact`, `result`, or another name. Same applies to `account`/`Account`.

> **When to move to Tier 2:** When you need to encapsulate DML operations in a reusable service class
> with proper test coverage.

---

## Tier 2: Build Your Own (~20 minutes)

> **No local project?** You can create classes directly in the Developer Console (Gear Icon > Developer
> Console > File > New > Apex Class) and run tests from there too (Test > New Run). Paste the code, save,
> and skip the `sf project deploy start` and `sf apex run test` commands.

Build an Account onboarding service that creates an Account with related Contacts and an Opportunity
in a single atomic transaction.

### Step 1: Create the Service Class

Create a new file named `SVC_AccountOnboarding.cls`. Copy the following code exactly as is -- do not
modify the class name or `kern.*` namespace references.

> **Why `public`?** Unlike triggers and APIs, service classes are called directly by your code. The
> framework doesn't need to resolve them by name, so `global` is not required.

```apex
/**
 * @description Account onboarding service. Creates an Account with related Contacts
 * and an Opportunity in a single transaction.
 *
 * @see SVC_AccountOnboarding_TEST
 *
 * @author your.name@company.com
 *
 * @group Services
 *
 * @date February 2026
 */
public with sharing class SVC_AccountOnboarding
{
	/**
	 * @description Creates an Account with related Contacts and an Opportunity.
	 *
	 * @param accountName The name for the new Account.
	 * @param contactLastNames Last names for the Contacts to create.
	 * @param opportunityName The name for the Opportunity.
	 *
	 * @return The result of the transaction.
	 */
	public kern.DML_Builder.TransactionResult createAccount
	(
		String accountName,
		List<String> contactLastNames,
		String opportunityName
	)
	{
		Account newAccount = new Account(Name = accountName, Industry = 'Technology', Phone = '555-0100', Website = 'https://example.com');

		Opportunity newOpportunity = new Opportunity
		(
			Name = opportunityName,
			StageName = 'Prospecting',
			CloseDate = Date.today().addDays(30)
		);

		kern.DML_Builder dmlTransaction = kern.DML_Builder.newTransaction()
			.doInsert(newAccount)
			.doInsert(newOpportunity, Opportunity.AccountId, newAccount);

		for(String lastName : contactLastNames)
		{
			Contact newContact = new Contact(LastName = lastName);
			dmlTransaction.doInsert(newContact, Contact.AccountId, newAccount);
		}

		return dmlTransaction.execute();
	}
}
```

> **Naming tip:** Avoid naming variables `account`, `contact`, or `opportunity` (lowercase) when using
> `Account.SomeField`, `Contact.AccountId`, or `Opportunity.AccountId` as SObjectField tokens. Apex is
> case-insensitive, so the variable shadows the SObject type and the field reference resolves as a value
> instead of a token. Use `newAccount`, `newContact`, etc.

**Deploy:**

```bash
sf project deploy start -o YourOrgAlias -m "ApexClass:SVC_AccountOnboarding"
```

### Step 2: Execute

Test from anonymous Apex (paste both snippets in one Execute Anonymous window — the second depends on `result` from the first):

```apex
List<String> contactLastNames = new List<String>{ 'Smith', 'Jones' };

kern.DML_Builder.TransactionResult result =
	new SVC_AccountOnboarding().createAccount('Acme Corp', contactLastNames, 'Acme Deal');

System.debug('Success: ' + result.isSuccess());
System.debug('Inserted IDs: ' + result.getInsertedIds());
System.debug('Success count: ' + result.getSuccessCount());
```

**Expected output:**

```text
Success: true
Inserted IDs: (001..., 006..., 003..., 003...)
Success count: 4
```

Verify the relationships in the org:

```apex
Id accountId = result.getInsertedIds()[0];

List<Contact> childContacts = kern.QRY_Builder.selectFrom(Contact.SObjectType)
	.fields(new List<SObjectField>{ Contact.LastName })
	.condition(Contact.AccountId).equals(accountId)
	.toList();

List<Opportunity> opportunities = kern.QRY_Builder.selectFrom(Opportunity.SObjectType)
	.fields(new List<SObjectField>{ Opportunity.Name })
	.condition(Opportunity.AccountId).equals(accountId)
	.toList();

System.debug('Contacts: ' + childContacts.size());
System.debug('Opportunities: ' + opportunities.size());
```

**Expected output:**

```text
Contacts: 2
Opportunities: 1
```

**Why it works -- key patterns:**

- **`DML_Builder.newTransaction()`** -- Creates a new transaction builder
- **`.doInsert(record)`** -- Registers a record for insertion
- **`.doInsert(child, field, parent)`** -- Registers a child with a parent relationship. The parent must
  be registered first. After `execute()`, the child's lookup field is auto-populated with the parent's ID.
- **`.execute()`** -- Commits all operations atomically, in registration order. After each parent inserts,
  the framework populates its children's lookup fields. If any operation fails, all are rolled back.
- **`TransactionResult`** -- Contains `isSuccess()`, `getInsertedIds()`, `getErrors()`, `getSuccessCount()`,
  `getFailureCount()`

### Step 3: Write Tests

Create a new file named `SVC_AccountOnboarding_TEST.cls`. Copy the following code exactly as is:

```apex
/**
 * @description Unit tests for SVC_AccountOnboarding.
 *
 * @see SVC_AccountOnboarding
 *
 * @author your.name@company.com
 *
 * @group Services
 *
 * @date February 2026
 */
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest(IsParallel=true)
private class SVC_AccountOnboarding_TEST
{
	/** @description Tests that an Account is created with Contacts and an Opportunity. */
	@IsTest
	private static void shouldCreateAccountWithRelatedRecords()
	{
		List<String> contactLastNames = new List<String>{ 'Smith', 'Jones' };

		kern.DML_Builder.TransactionResult result =
			new SVC_AccountOnboarding().createAccount('Test Corp', contactLastNames, 'Test Deal');

		Assert.isTrue(result.isSuccess(), 'Transaction should succeed');
		Assert.areEqual(4, result.getSuccessCount(), 'Should insert 4 records (1 Account + 1 Opportunity + 2 Contacts)');

		// Verify parent-child relationships using QRY_Builder
		List<Contact> contacts = kern.QRY_Builder.selectFrom(Contact.SObjectType)
			.fields(new List<SObjectField>{ Contact.LastName, Contact.AccountId })
			.condition(Contact.AccountId).equals(result.getInsertedIds()[0])
			.toList();
		Assert.areEqual(2, contacts.size(), 'Should create two Contacts');

		List<Opportunity> opportunities = kern.QRY_Builder.selectFrom(Opportunity.SObjectType)
			.fields(new List<SObjectField>{ Opportunity.Name, Opportunity.AccountId })
			.condition(Opportunity.AccountId).equals(result.getInsertedIds()[0])
			.toList();
		Assert.areEqual(1, opportunities.size(), 'Should create one Opportunity');
		Assert.areEqual('Test Deal', opportunities[0].Name, 'Opportunity name should match');
	}

	/** @description Tests that the transaction result contains the inserted IDs. */
	@IsTest
	private static void shouldReturnInsertedIds()
	{
		kern.DML_Builder.TransactionResult result =
			new SVC_AccountOnboarding().createAccount('ID Test Corp', new List<String>{ 'Doe' }, 'ID Deal');

		Assert.isTrue(result.isSuccess(), 'Transaction should succeed');
		List<Id> insertedIds = result.getInsertedIds();
		Assert.areEqual(3, insertedIds.size(), 'Should return 3 inserted IDs');
		Assert.isTrue(result.getErrors().isEmpty(), 'Should have no errors');
	}

	/** @description Tests that the service handles an empty contact list. */
	@IsTest
	private static void shouldCreateAccountWithNoContacts()
	{
		kern.DML_Builder.TransactionResult result =
			new SVC_AccountOnboarding().createAccount('Solo Corp', new List<String>(), 'Solo Deal');

		Assert.isTrue(result.isSuccess(), 'Transaction should succeed');
		Assert.areEqual(2, result.getSuccessCount(), 'Should insert 2 records (1 Account + 1 Opportunity)');

		List<Contact> contacts = kern.QRY_Builder.selectFrom(Contact.SObjectType)
			.fields(new List<SObjectField>{ Contact.LastName })
			.condition(Contact.AccountId).equals(result.getInsertedIds()[0])
			.toList();
		Assert.isTrue(contacts.isEmpty(), 'Should have no Contacts');
	}
}
```

**Deploy and run:**

```bash
sf project deploy start -o YourOrgAlias -m "ApexClass:SVC_AccountOnboarding_TEST"
sf apex run test -o YourOrgAlias -t SVC_AccountOnboarding_TEST --code-coverage --synchronous --result-format human
```

**Expected:** 3 tests passing, 100% coverage on `SVC_AccountOnboarding`.

> **About the annotations:** `@IsTest(IsParallel=true)` enables parallel test execution (faster runs).
> `SeeAllData` defaults to `false`, so we omit it. `@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')`
> suppresses a static analysis rule about `System.runAs()` -- fine for quick starts, but consider adding
> `System.runAs()` in production tests to verify profile and permission set access.

---

## Tier 3: Production Patterns (~5 minutes)

### All DML Operations

`DML_Builder` supports every DML operation. See the [DML Guide](DML%20-%20Guide.md) for the full API
reference including upsert by external ID, undelete, and bulk patterns.

Run this from Execute Anonymous to see insert, update, and delete in a single transaction:

```apex
Account newAccount = new Account(Name = 'DML Demo Corp', Phone = '555-0100');

kern.DML_Builder.TransactionResult insertResult = kern.DML_Builder.newTransaction()
	.doInsert(newAccount)
	.execute();

System.debug('Insert success: ' + insertResult.isSuccess());
System.debug('Account Id: ' + newAccount.Id);

newAccount.Industry = 'Technology';

kern.DML_Builder.TransactionResult updateResult = kern.DML_Builder.newTransaction()
	.doUpdate(newAccount)
	.execute();

System.debug('Update success: ' + updateResult.isSuccess());

kern.DML_Builder.TransactionResult deleteResult = kern.DML_Builder.newTransaction()
	.doDelete(newAccount)
	.execute();

System.debug('Delete success: ' + deleteResult.isSuccess());
```

**Expected output:**
```text
Insert success: true
Account Id: 001...
Update success: true
Delete success: true
```

### TransactionResult

Inspect the result after `execute()`:

```apex
Account validAccount = new Account(Name = 'Valid Corp', Phone = '555-0100');
Account invalidAccount = new Account(); // Name is required — will fail

kern.DML_Builder.TransactionResult result = kern.DML_Builder.newTransaction()
	.doInsert(validAccount)
	.doInsert(invalidAccount)
	.allowPartial()
	.execute();

System.debug('Overall success: ' + result.isSuccess());
System.debug('Inserted IDs: ' + result.getInsertedIds());
System.debug('Success count: ' + result.getSuccessCount());
System.debug('Failure count: ' + result.getFailureCount());

for(Database.Error error : result.getErrors())
{
	System.debug('Error: ' + error.getMessage());
}
```

**Expected output:**
```text
Overall success: false
Inserted IDs: (001...)
Success count: 1
Failure count: 1
Error: Required fields are missing: [Name]
```

### Partial Success

By default, DML is all-or-nothing -- if one record fails, all are rolled back. Chain `.allowPartial()`
to save valid records and log failures:

```apex
List<Account> mixedAccounts = new List<Account>
{
	new Account(Name = 'Good Account 1', Phone = '555-0100'),
	new Account(),
	new Account(Name = 'Good Account 2', Phone = '555-0100')
};

kern.DML_Builder.TransactionResult result = kern.DML_Builder.newTransaction()
	.doInsert(mixedAccounts)
	.allowPartial()
	.execute();

System.debug('Succeeded: ' + result.getSuccessCount());
System.debug('Failed: ' + result.getFailureCount());
System.debug('Inserted IDs: ' + result.getInsertedIds());
```

**Expected output:**
```text
Succeeded: 2
Failed: 1
Inserted IDs: (001..., 001...)
```

Failed records are automatically logged via `LOG_Builder` — check **App Launcher > Kern > Log Entries**.

### Security, Sharing, Suppression, and Async

These are situational patterns. See the [DML Guide](DML%20-%20Guide.md) for detailed examples.

**Default access mode.** At v1.0 GA, `kern.DML_Builder.newTransaction()` runs in `AccessLevel.USER_MODE` — CRUD and FLS are enforced against the running user, and sharing is honoured. This is driven by the `UserModeDml_Enabled` feature flag (ships `true`). Override per call with `.withSystemMode()` (bypasses CRUD/FLS) or belt-and-braces with `.withUserMode()` even when the flag is flipped. `.bypassSharing()` only affects sharing — it does NOT turn off USER_MODE's CRUD/FLS enforcement. See [Security Guide — Secure-by-Default Defaults](Security%20-%20Guide.md#secure-by-default-defaults).

```apex
// Explicit USER_MODE (redundant when the flag is on, belt-and-braces otherwise)
kern.DML_Builder.newTransaction().doUpdate(records).withUserMode().execute();

// Bypass CRUD/FLS (framework-owned records that must run as system)
kern.DML_Builder.newTransaction().doUpdate(records).withSystemMode().execute();

// Bypass sharing rules (still enforces CRUD/FLS when USER_MODE default is on)
kern.DML_Builder.newTransaction().doUpdate(records).bypassSharing().execute();

// Suppress exceptions (log instead of throw)
kern.DML_Builder.newTransaction().doInsert(records).suppressExceptions().execute();

// Async DML (returns void; fire-and-forget background job)
kern.DML_Builder.newTransaction().doUpdate(records).async().withBatchSize(200).execute();

// Suppress automatic error logging
kern.DML_Builder.newTransaction().doInsert(records).allowPartial().suppressLogging().execute();
```

---

## Common Issues

| Problem | Cause | Fix |
|---------|-------|-----|
| Child lookup field is `null` after execute | Child registered without relationship | Use `.doInsert(child, Contact.AccountId, parent)` instead of `.doInsert(child)` |
| `DmlException` thrown | All-or-nothing mode (default) and a record failed | Use `.allowPartial()` for partial success, or `.suppressExceptions()` to log instead of throw |
| Second `.execute()` does nothing | Transaction is consumed after first execute | Register all operations, execute once |
| Using direct `insert`/`update` | Bypasses framework error logging | Use `kern.DML_Builder.newTransaction().doInsert(record).execute()` |
| Child lookup is `null` and parent appears after child in chain | `.doInsert(child, field, parent)` requires parent registered first | Move the parent's `.doInsert()` call above the child's -- the framework does not re-order operations |
| `System.NullPointerException` on result | Accessing result fields incorrectly | Use `result.isSuccess()`, `result.getInsertedIds()`, `result.getErrors()` |
| `Method does not exist: doInsert(Contact, Id, Account)` | Variable named `contact` shadows `Contact` type | Rename the variable (e.g., `newContact`) so `Contact.AccountId` resolves as SObjectField |

---

## What You Now Know

After completing this guide, you understand the **DML builder pattern** in KernDX:

| Concept | What It Does |
|---------|-------------|
| **`DML_Builder`** | Fluent builder for all DML operations -- replaces direct `insert`/`update`/`delete` |
| **`.doInsert(child, field, parent)`** | Auto-populates foreign keys after parent insert |
| **`.execute()`** | Commits all operations atomically — parents before children |
| **`TransactionResult`** | Inspection API: `isSuccess()`, `getInsertedIds()`, `getErrors()`, counts |

**Key patterns:**

- **Always use `DML_Builder`** -- not direct DML. The framework provides automatic error logging.
- **Register parent before child** -- use the 3-argument `.doInsert(child, field, parent)` overload
- **One `execute()` per transaction** -- register all operations first, then execute once
- **`public` visibility** -- service classes using DML_Builder don't need `global`
- **`TransactionResult`** -- always check `isSuccess()` when using `.allowPartial()` or `.suppressExceptions()`

---

## Next Steps

| Topic | Link |
|-------|------|
| Selectors (query patterns) | [Fast Start - Selectors](Fast%20Start%20-%20Selectors.md) |
| Trigger Actions (DML in after context) | [Fast Start - Trigger Actions](Fast%20Start%20-%20Trigger%20Actions.md) |
| Test Data Patterns | [Fast Start - Test Data](Fast%20Start%20-%20Test%20Data.md) |
| Async Processing (background DML and chains) | [Fast Start - Async Processing](Fast%20Start%20-%20Async%20Processing.md) |
| Code Scanning (catch DML anti-patterns) | [Fast Start - Code Scanning](Fast%20Start%20-%20Code%20Scanning.md) |
| Complete DML Guide | [DML - Guide](DML%20-%20Guide.md) |
| DML_Builder Reference | [reference/apex/DML_Builder.md](reference/apex/DML_Builder.md) |

> **Drift guard:** `FastStart_DML_DEMO` + `FastStart_DML_DEMO_TEST` in `release-testing/subscriber/classes/`
> are the companion classes for this guide. Deploy and run `FastStart_DML_DEMO_TEST` against a subscriber
> scratch org to confirm the parent-child auto-link and partial-success patterns work end-to-end.
