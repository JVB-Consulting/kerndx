---
navOrder: 14
navLabel: "DML (saving records)"
searchTerms: {"handle-dml-errors-properly":["Database.SaveResult"]}
movedAnchors: {"why-choose-this-over-the-built-in-option": "/#saving-records", "capability-matrix-for-analysts": "/#saving-records"}
---

# DML - Guide

**Who this page is for:** developers who save records in Apex and want every insert, update, and delete to be safe,
bulk-ready, and easy to test.

It also serves architects who want one consistent way to handle transactions, security, and permission checks across
the whole codebase, and business analysts who need to understand what the data layer can do, how it protects data, and
how it gets tested.

New to it? Try [Fast Start - DML](Fast%20Start%20-%20DML.md) first: a step-by-step walkthrough that covers
implementation, testing, and common pitfalls. Deciding whether to use KernDX? See
[Why KernDX](Strategic%20Guide%20-%20Overview.md).

## Copy this first

```apex
List<Account> accounts = new List<Account>
{
	new Account(Name = 'Acme Corp'),
	new Account(Name = 'Global Industries')
};

kern.DML_Builder.newTransaction().doInsert(accounts).execute();
```

**What this does:** saves both accounts in one step. It is all or nothing: if one account cannot be saved, the save
throws an error and neither account is saved. The save checks the current user's object and field permissions, and
record sharing. Switch the [user mode flag](#access-mode-user_mode--system_mode) off and the permission checks stop;
record sharing then follows your class's sharing keyword.

**Read next:** [Parents and children in one save](#registering-relationships), [Updates, deletes and upserts](#bulk-dml-operations-dml_builder),
[Sharing and access mode](#sharing-enforcement), [Save some rows when others fail](#how-to-opt-out).

---

## Quick Navigation

| I need to...                                                           | Go to...                                                                                            |
|------------------------------------------------------------------------|-----------------------------------------------------------------------------------------------------|
| Know when to save without `DML_Builder`                                | [Don't use this when](#dont-use-this-when)                                                          |
| Save some rows when others fail, or more than 10K rows                 | [How to opt out](#how-to-opt-out)                                                                   |
| Merge records, convert a lead, or save with `Database.DMLOptions`      | [How to opt out](#how-to-opt-out)                                                                   |
| Save a parent and its children in one transaction                      | [Registering Relationships](#registering-relationships)                                             |
| Insert or update records matched by an external ID                     | [Upsert with External ID](#upsert-with-external-id)                                                 |
| Mix inserts, updates, and deletes, and roll them all back on a failure | [Mixed Operations and Rollback](#mixed-operations-and-rollback)                                     |
| Try a save again when another transaction holds the row                | [Retrying When Another Transaction Holds the Row](#retrying-when-another-transaction-holds-the-row) |
| Insert, update, delete, upsert, or undelete in bulk                    | [Bulk DML Operations](#bulk-dml-operations-dml_builder)                                             |
| Log a refusal I expect at WARN, not ERROR                              | [Logging a refusal you expect below ERROR](#logging-a-refusal-you-expect-below-error)               |
| Understand how sharing applies to a save                               | [Sharing Enforcement](#sharing-enforcement)                                                         |
| Choose between user mode and system mode, or switch user mode off      | [Access Mode (USER_MODE / SYSTEM_MODE)](#access-mode-user_mode--system_mode)                        |
| Check a user's permissions before I save                               | [Permission Checking](#permission-checking-flow_checkobjectpermissions)                             |
| Build test records                                                     | [Test Data Factory](#test-data-factory)                                                             |
| Build test records with Ids but no save, for query mocking             | [Mock ID Generation for Query Mocking](#mock-id-generation-for-query-mocking)                       |
| Change one field on many records, or purge old records                 | [Bulk Utilities](#bulk-utilities-util_bulkupdates--util_purgerecords)                               |
| Deactivate users who have been inactive                                | [Deactivate Users](#deactivate-users)                                                               |
| Test code that saves records                                           | [Testing](#testing)                                                                                 |
| Avoid the common mistakes                                              | [Anti-Patterns](#anti-patterns)                                                                     |
| Understand how the framework is built, and what it can do              | [How does it work?](#how-does-it-work)                                                              |
| See why KernDX is worth using                                          | [Why KernDX: the saving records example](/#saving-records)                                          |

---

## Quick Start

Pick the shape that fits your save:

| Your save                                                   | What to write                                                                                                                                                                                                           |
|-------------------------------------------------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| Everyday inserts, updates, and deletes                      | One call to `DML_Builder`: start a transaction, add the operation, run it. The first sample below, the same as the one under [Copy this first](#copy-this-first)                                                        |
| Several related records that must save together as one unit | One transaction, started with `kern.DML_Builder.newTransaction()`, that holds every record, each child registered with its parent: the second sample below, and [Registering Relationships](#registering-relationships) |

**Simple bulk insert:**

```apex
List<Account> accounts = new List<Account>
{
	new Account(Name = 'Acme Corp'),
	new Account(Name = 'Global Industries')
};

DML_Builder.newTransaction().doInsert(accounts).execute();
```

**Related objects in a single transaction:**

```apex
Account account = new Account(Name = 'Acme Corp');
Contact newContact = new Contact(FirstName = 'Jane', LastName = 'Doe');

DML_Builder.newTransaction()
	.doInsert(account)
	.doInsert(newContact, Contact.AccountId, account)
	.execute();
```

> **Namespaces in code samples:** `kern.` on a class and `kern__` on an object, field, or metadata type mark the managed package's namespace.
> On the managed package, framework references need those prefixes even where a sample omits them; repackaged under your own namespace, replace `kern`/`kern__`
> with your prefix; on an unmanaged deploy, drop them. See [How to read the code samples](Installation.md#how-to-read-the-code-samples).

---

## What problem does this solve?

When you save records in Apex by hand, four things go wrong again and again:

- A multi-step save fails halfway and leaves orphaned records behind.
- A loop trips governor limits.
- Code lets a user write data they should never touch.
- Test setup grows into a wall of boilerplate.

KernDX's data layer gives you one consistent way to save records so every insert, update, and delete is safe, bulk-ready, and easy to test. You build up the changes you want, then run them in a single all-or-nothing transaction that enforces the running user's permissions by default.

Use it whenever code writes data: KernDX expects every save to go through `DML_Builder`.

---

## Mental model

Think of it as a removals firm for your records. You hand over the boxes (the records you want to save) and say which ones are parents and which are children. The firm works out the right order to load the van and carries everything in one trip.

If anything breaks on the way, the firm brings the whole load back, so you're never left half moved-in. You also decide up front whether the movers are allowed into rooms the current user isn't cleared to enter.

---

## Use this when

- **Several records must succeed or fail together.** A parent and its children, or a mix of inserts, updates, and deletes that should all commit or all roll back.
- **You're saving in bulk.** One call handles large volumes without you writing loop-and-batch plumbing.
- **The running user's permissions must be respected.** User-facing features, public sites, and communities where a user should only write what they're allowed to.
- **You want one consistent way to write data** so every team member's code looks and behaves the same.

## Don't use this when

KernDX is opinionated here: every save goes through `DML_Builder`. There are only two real exceptions.

- **You're only setting a field on `Trigger.new` in a before-trigger.** Direct field assignment needs no DML at all; the framework adds nothing here.
- **The framework cannot express the save you need.** Today that means four operations: merging records, converting a lead, saving with `Database.DMLOptions` (assignment rules, or saving past a duplicate rule), and emptying the recycle bin. Keep the raw `Database.*` call in one place, and pass `AccessLevel.USER_MODE` wherever the platform method takes one. The last row of [How to opt out](#how-to-opt-out) says which methods take one.

---

## How to opt out

Every common case the standard methods don't cover by default has a documented way out on the same builder. Only the last row leaves the builder, and only for a save the framework cannot express.

| You need                                                              | Use                                                                                                                                                                                                                                                               | See                                                                                   |
|-----------------------------------------------------------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|---------------------------------------------------------------------------------------|
| **Partial-success DML** (`Database.insert(records, false)` semantics) | `DML_Builder.allowPartial()`. Failed rows surface as `Database.SaveResult` errors while the rest commit.                                                                                                                                                         | [Anti-Patterns](#anti-patterns), [Insert Operations](#insert-operations)              |
| **>10K rows in one logical transaction**                              | `DML_Builder.async()` streams operations through queueables/batches. The access mode you chose travels with the job, and so does `.bypassSharing()`; without it the job enforces record sharing. The framework throws `kern.UTIL_Exceptions.IllegalStateException` before saving, with a message that names `.async()` as the fix, when a synchronous save would exceed `UTIL_Limits.dmlRows().maximum()`. | [Bulk Utilities → Batch Processing](#batch-processing)                                |
| **Per-transaction `AccessLevel` override**                            | `.withUserMode()` for explicit USER_MODE, `.withSystemMode()` for SYSTEM_MODE. Either overrides the flag-driven default.                                                                                                                                                | [Access Mode (USER_MODE / SYSTEM_MODE)](#access-mode-user_mode--system_mode)          |
| **Bypass sharing for one operation**                                  | `.bypassSharing()` routes through the `without sharing` proxy for that transaction only. In USER_MODE the user's object and field permissions still apply: fields the user cannot create or edit are left out of the save.                                       | [Bypass vs Enforce vs Inherited](#bypass-vs-enforce-vs-inherited)                     |
| **Inspect platform `SaveResult` / `UpsertResult` errors directly**    | `TransactionResult.getErrors()` returns the underlying platform errors after `.execute()`.                                                                                                                                                                        | [Anti-Patterns](#anti-patterns)                                                       |
| **A save the framework cannot express**                               | Merging records, converting a lead, saving with `Database.DMLOptions`, or emptying the recycle bin: `DML_Builder` and `DML_Transaction` do not offer these. Call the platform directly, for example `Database.merge(masterAccount, duplicateAccount, AccessLevel.USER_MODE)`, and keep that call in one place. In a class saved at API version 66.0 or earlier, the raw call runs in system mode unless you pass `AccessLevel.USER_MODE`; from 67.0, Salesforce makes user mode the default. Pass it anyway, wherever the platform method takes one, so the call stays safe whatever the class's version: `Database.merge`, `Database.convertLead`, and `Database.insert` / `Database.update` with `Database.DMLOptions` all take an `AccessLevel`; `Database.emptyRecycleBin` does not. Nothing intercepts raw platform DML. The framework does not see that save, so it writes no log entry for a failure.  | [Don't use this when](#dont-use-this-when)                                            |

---

## Transactional DML Pattern ([`DML_Builder`](reference/apex/DML_Builder.md))

This pattern collects the record changes you want, then commits them in one transaction. It keeps your records linked correctly and saves parents before children. You call `DML_Builder`; it drives [`DML_Transaction`](reference/apex/DML_Transaction.md) behind the scenes.

### Basic Usage

Call `DML_Builder.newTransaction()` to start a transaction, then chain on the operations you want with short method calls.

**Example:**

```apex
// Basic transactional DML for creating related records
Account account = new Account(Name = 'Acme Corporation', Industry = 'Technology');
Contact newContact = new Contact(FirstName = 'John', LastName = 'Doe', Email = 'john.doe@acme.com');
Opportunity newOpportunity = new Opportunity(Name = 'Big Deal', StageName = 'Prospecting', CloseDate = Date.today().addDays(30));

DML_Builder.newTransaction()
	.doInsert(account)
	.doInsert(newContact, Contact.AccountId, account)
	.doInsert(newOpportunity, Opportunity.AccountId, account)
	.execute();
```

### Managing Dependencies

You don't have to insert parents first and wire up the lookups yourself. The framework reads the relationship fields you pass to `doInsert`, inserts parents before children, and fills in each child's lookup to its parent for you.

**Example:**

```apex
// DML_Builder resolves dependency order automatically from relationship fields
Account account1 = new Account(Name = 'Account 1');
Account account2 = new Account(Name = 'Account 2');

Contact contact1 = new Contact(LastName = 'Smith');
Contact contact2 = new Contact(LastName = 'Jones');

Opportunity newOpportunity = new Opportunity(Name = 'Deal', StageName = 'Closed Won', CloseDate = Date.today());

DML_Builder.newTransaction()
	.doInsert(account1)
	.doInsert(account2)
	.doInsert(contact1, Contact.AccountId, account1)
	.doInsert(contact2, Contact.AccountId, account2)
	.doInsert(newOpportunity, Opportunity.AccountId, account1)
	.execute();
```

### Registering Relationships

When you want to link two new records that don't have Ids yet, use the three-argument form of `doInsert`. The framework inserts the parent first, then sets the child's lookup once the parent's Id exists.

**Example:**

```apex
// Register relationships between new records
Account account = new Account(Name = 'Parent Account');

Contact contact1 = new Contact(FirstName = 'John', LastName = 'Doe');
Contact contact2 = new Contact(FirstName = 'Jane', LastName = 'Smith');

Opportunity newOpportunity = new Opportunity(
	Name = 'Big Opportunity',
	StageName = 'Prospecting',
	CloseDate = Date.today().addDays(60)
);

DML_Builder.newTransaction()
	.doInsert(account)
	.doInsert(contact1, Contact.AccountId, account)
	.doInsert(contact2, Contact.AccountId, account)
	.doInsert(newOpportunity, Opportunity.AccountId, account)
	.execute();
```

### Upsert with External ID

An [upsert](https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/langCon_apex_dml_examples_upsert.htm) inserts a record if it's new and updates it if it already exists. Pass an external ID field to `doUpsert` so the framework knows how to match an incoming record to an existing one.

**Single Record:**

```apex
// Upsert using external ID field for matching
Account newAccount = new Account(Name = 'Acme Corp', ExternalId__c = 'EXT-001');

DML_Builder.newTransaction()
	.doUpsert(newAccount, Account.ExternalId__c)
	.execute(); // Inserts new record or updates existing record matching ExternalId__c
```

**Multiple Records:**

```apex
// Bulk upsert using external ID field
List<Account> accounts = new List<Account>
{
	new Account(Name = 'Account 1', ExternalId__c = 'EXT-001'),
	new Account(Name = 'Account 2', ExternalId__c = 'EXT-002'),
	new Account(Name = 'Account 3', ExternalId__c = 'EXT-003')
};

DML_Builder.newTransaction()
	.doUpsert(accounts, Account.ExternalId__c)
	.execute(); // Upserts all records using ExternalId__c for matching
```

**With Parent-Child Relationships:**

```apex
// Upsert parent with related child inserts
Account newAccount = new Account(Name = 'Parent Account', ExternalId__c = 'EXT-PARENT');
Contact newContact = new Contact(FirstName = 'John', LastName = 'Doe');

DML_Builder.newTransaction()
	.doUpsert(newAccount, Account.ExternalId__c)
	.doInsert(newContact, Contact.AccountId, newAccount)
	.execute();
```

> **Important:** All records of the same SObjectType within a single transaction must use the same external ID field. Attempting to register records with different external ID
> fields for the same SObjectType throws a `kern.UTIL_Exceptions.IllegalStateException`.

**Example - Conflicting External ID Fields (Invalid):**

```apex
// This will throw a kern.UTIL_Exceptions.IllegalStateException
Account account1 = new Account(Name = 'Account 1', ExternalId__c = 'EXT-001');
Account account2 = new Account(Name = 'Account 2', AlternateExternalId__c = 'ALT-001');

DML_Builder.newTransaction()
	.doUpsert(account1, Account.ExternalId__c)
	.doUpsert(account2, Account.AlternateExternalId__c)
	.execute(); // Throws kern.UTIL_Exceptions.IllegalStateException!

// Error: Cannot use different external ID fields for the same SObjectType in a single transaction
```

### Mixed Operations and Rollback

<a id="mixed-operations"></a>You can mix inserts, updates, and deletes in the same transaction. They all commit together, or all roll back if any one fails.

If one record fails, every record in the transaction rolls back and nothing is saved. To keep the records that saved and
get the failed ones back as errors instead, add `.allowPartial()`.

"Mixed" here means different kinds of save in one transaction. It is not the platform's mixed DML error
(`MIXED_DML_OPERATION`), which is about saving setup records, such as users, together with ordinary records. For that
error, see [Users and Permission Sets](Test%20Data%20-%20Guide.md#users-and-permission-sets) in the Test Data Guide.

**Example:**

```apex
// Mixed DML operations with error handling
try
{
	Account newAccount = new Account(Name = 'New Account');

	Account existingAccount = (Account)QRY_Builder.selectFrom(Account.SObjectType)
		.fields(new List<SObjectField>{Account.Id, Account.Name})
		.withLimit(1)
		.getFirst();
	existingAccount.Name = 'Updated Account';

	Account oldAccount = (Account)QRY_Builder.selectFrom(Account.SObjectType)
		.fields(new List<SObjectField>{Account.Id})
		.condition(Account.CreatedDate).lessThan(Date.today().addYears(-1))
		.withLimit(1)
		.getFirst();

	DML_Builder.newTransaction()
		.doInsert(newAccount)
		.doUpdate(existingAccount)
		.doDelete(oldAccount)
		.execute();
}
catch(Exception error)
{
	LOG_Builder.build().error(error).emitAt('MyClass.commitChanges');
	// All changes are rolled back automatically
}
```

### Retrying When Another Transaction Holds the Row

Ask the builder to try a write again when another transaction holds the row. Salesforce refuses such
a write after waiting about ten seconds for it: the refusal reads `UNABLE_TO_LOCK_ROW`. A batch job
updating rows that users are editing, or two jobs touching the same parent, meets it regularly:

```apex
DML_Builder.newTransaction()
	.doUpdate(records)
	.withRetryOnLock()
	.execute();
```

A row refused because another transaction holds its lock is tried again, up to the number of times
you asked for, before the refusal reaches you. Any other refusal surfaces at once, untried a second time.

- `withRetryOnLock()` retries once.
- `withRetryOnLock(retries)` accepts 1 to 5. Any other count, null included, raises `IllegalArgumentException`.

What "tried again" means follows the mode you chose:

| Mode | What is tried again |
|---|---|
| All-or-nothing | The platform refused the whole commit, so the whole commit re-runs. |
| Partial (`.allowPartial()`) | Only the rows refused for a lock are re-issued, before the commit moves on. The rows that saved stay saved. |

**What it costs.**

- There is no pause between attempts: the platform already waits up to about ten seconds for the lock
  before refusing, so each attempt carries its own wait.
- A contended commit costs roughly ten seconds per attempt, twenty seconds at the default, sixty at the ceiling.
- In partial mode the wait applies to each statement the commit issues, so a commit that spans several
  contended statements can take several times that.
- An uncontended commit costs nothing extra.
- Keep the default on interactive paths and put larger counts in background work. A synchronous request
  longer than five seconds counts toward your org's limit of ten concurrent long-running requests, and a
  contended commit already crosses that during the platform's first wait. Background work is outside that limit.
- The retries stop early when the remaining DML limits cannot cover another attempt; the log entry then says so.

**What you see.**

- A commit that met a row lock writes one WARN entry once it is through, with the retries used, the
  rows recovered and still refused, and what stopped the retries if something did.
- A commit still refused after the last attempt fails exactly as it would without a retry. Its usual
  ERROR entry carries those same details instead.
- `.suppressLogging()` silences both.
- The retry setting travels with `.async()`, where every batch retries its own refusals inside its own limits.

**When not to use it.** Three cases:

- A commit whose triggers publish events, send notifications or hand work to integrations. Rolling
  back an attempt does not take those back, so a retried attempt repeats them and duplicates what went
  downstream.
- A trigger that keeps its own "already ran" flag for the transaction. Rolling back does not reset
  it, so the retried attempt skips that trigger's work. Move the logic into a trigger action, whose
  re-entrancy the framework tracks for you ([Triggers Guide](Triggers%20-%20Guide.md#recursion-prevention)),
  or decide from the record's values rather than from a flag. If neither is possible, do not retry that commit.
- An interactive request that cannot afford the wait. Let the refusal surface and tell the user to try
  again.

---

## Bulk DML Operations ([`DML_Builder`](reference/apex/DML_Builder.md))

Failed DML is never silent unless you ask for silence with `.suppressLogging()`:

- A partial commit logs each failed row.
- An all-or-nothing failure writes one ERROR entry before it rolls back and rethrows.
- A failure that partial mode swallows mid-commit writes one ERROR entry recording that the operations not yet performed never ran.

### Insert Operations

[Insert](https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/langCon_apex_dml_examples_insert.htm) one record or many in a single call, with sharing control applied.

**Example:**

```apex
// Bulk insert with error handling
List<Account> accounts = new List<Account>();
for(Integer i = 0; i < 200; i++)
{
	accounts.add(new Account(Name = 'Bulk Account ' + i, Industry = 'Technology'));
}

// Insert with partial commit allowed
DML_Builder.newTransaction()
	.doInsert(accounts)
	.allowPartial()
	.execute();
```

#### Logging a refusal you expect below ERROR

Declare a refusal that is part of the design, and a partial commit logs it at WARN. Without the declaration, a partial commit logs every failed row at ERROR, so such a refusal looks like an incident every time.

An example is a unique field that backstops a rare race, where the second writer is meant to lose:

```apex
DML_Builder.newTransaction()
	.doInsert(contacts)
	.allowPartial()
	.expectRefusal(StatusCode.DUPLICATE_VALUE)
	.execute();
```

- A row refused only for a declared reason is logged at WARN.
- Every other failed row still logs at ERROR, and a row that also carries an undeclared error logs at ERROR too.
- Nothing else changes: the row still counts as a failure in the result, so your code still decides what to do with it.
- Call `.expectRefusal()` once per status code.
- It has no effect in all-or-nothing mode, where any refusal fails the whole transaction.
- The declaration travels with `.async()`, so a background job logs the same refusal at WARN.
- A WARN row obeys your log-level threshold like any other, so an org that keeps only ERROR entries will not see expected refusals at all.

### Update Operations

[Update](https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/langCon_apex_dml_examples_update.htm) existing records in bulk, with sharing control applied.

**Example:**

```apex
// Bulk update with sharing enforced
List<Account> accounts = QRY_Builder.selectFrom(Account.SObjectType)
	.fields(new List<SObjectField>{Account.Id, Account.Name, Account.Industry})
	.condition(Account.Industry).equals('Technology')
	.withLimit(200)
	.toList();

for(Account account : accounts)
{
	account.Industry = 'Software';
	account.Description = 'Updated via bulk operation';
}

// Enforce sharing for update operation
DML_Builder.newTransaction()
	.doUpdate(accounts)
	.execute();
```

### Delete Operations

[Delete](https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/langCon_apex_dml_examples_delete.htm) records in bulk, with sharing control applied.

**Example:**

```apex
// Bulk delete with permission check
// Check delete permission first
FLOW_CheckObjectPermissions.DTO_Request request = new FLOW_CheckObjectPermissions.DTO_Request();
request.objectApiName = 'Contact';

List<FLOW_CheckObjectPermissions.DTO_Response> permissions =
	FLOW_CheckObjectPermissions.checkPermissions(new List<FLOW_CheckObjectPermissions.DTO_Request>{request});

if(permissions[0].hasDeleteAccess)
{
	List<Contact> contactsToDelete = QRY_Builder.selectFrom(Contact.SObjectType)
		.fields(new List<SObjectField>{Contact.Id})
		.condition(Contact.Email).contains('@test.com')
		.withLimit(100)
		.toList();

	DML_Builder.newTransaction()
		.doDelete(contactsToDelete)
		.allowPartial()
		.execute();
}
else
{
	LOG_Builder.build().error('User does not have delete permission').emitAt('MyClass.deleteContacts');
}
```

### Upsert Operations

Upsert inserts new records and updates existing ones in the same call. By default it matches on the record Id; pass an external ID field to match on that instead.

**Basic Upsert (by Record Id):**

```apex
// Upsert using record Id for matching (default behavior)
List<Account> accounts = new List<Account>
{
	new Account(Name = 'New Account'),  // No Id - will insert
	new Account(Id = existingId, Name = 'Updated Account')  // Has Id - will update
};

DML_Builder.newTransaction()
	.doUpsert(accounts)
	.execute();
```

**Upsert with External ID Field:**

```apex
// Bulk upsert using external ID field for matching
List<Account> accounts = new List<Account>
{
	new Account(Name = 'Account 1', ExternalId__c = 'EXT-001'),
	new Account(Name = 'Account 2', ExternalId__c = 'EXT-002'),
	new Account(Name = 'Account 3', ExternalId__c = 'EXT-003')
};

// First upsert creates new records (no matching external IDs exist)
DML_Builder.newTransaction()
	.doUpsert(accounts, Account.ExternalId__c)
	.execute();

// Modify and upsert again - will update existing records
for(Account account : accounts)
{
	account.Industry = 'Technology';
}

DML_Builder.newTransaction()
	.doUpsert(accounts, Account.ExternalId__c)
	.execute();
```

**Upsert with Sharing Enforcement:**

```apex
// External ID upsert with sharing rules enforced
DML_Builder.newTransaction()
	.doUpsert(accounts, Account.ExternalId__c)
	.execute();
```

### Undelete Operations

Restore records that were deleted but are still in the recycle bin.

**Example:**

```apex
// Undelete soft-deleted records
List<Account> deletedAccounts = QRY_Builder.selectFrom(Account.SObjectType)
	.fields(new List<SObjectField>{Account.Id, Account.Name})
	.condition(Account.IsDeleted).equals(true)
	.allRows()
	.toList();

if(!deletedAccounts.isEmpty())
{
	DML_Builder.newTransaction()
		.doUndelete(deletedAccounts)
		.execute();
}
```

---

## Sharing Enforcement

### Context-Driven Sharing

By default, a `DML_Builder` chain runs in USER_MODE, where the platform always enforces the running user's record sharing. In SYSTEM_MODE the chain follows the sharing rules of the class that called it. You set that at the class level:

- `with sharing` for user-facing code.
- `without sharing` for system maintenance.

When you need finer control for one write, the per-call methods (`.bypassSharing()`, `.withUserMode()`, `.withSystemMode()`) override the default. The framework records each use of `.withSystemMode()` and `.bypassSharing()`, so you can audit the decision later. `.withUserMode()` turns no check off, so it is not recorded.

**Example:**

```apex
// USER_MODE default + with-sharing class for community/portal contexts
public with sharing class CommunityAccountController
{
	public void createAccount(String accountName)
	{
		Account account = new Account(Name = accountName);
		DML_Builder.newTransaction()
			.doInsert(account)
			.execute();
	}

	public void updateAccount(Id accountId, String newName)
	{
		Account account = new Account(Id = accountId, Name = newName);
		DML_Builder.newTransaction()
			.doUpdate(account)
			.execute();
	}
}

// In a system-level batch or trigger
public without sharing class SystemBatchProcess implements Database.Batchable<SObject>
{
	public void execute(Database.BatchableContext context, List<SObject> scope)
	{
		// Bypass sharing for system operations; in USER_MODE the running user's
		// object and field permissions still apply
		DML_Builder.newTransaction()
			.doUpdate(scope)
			.bypassSharing()
			.execute();
	}
}
```

### Operation-Level Sharing

By default `DML_Builder` runs in `AccessLevel.USER_MODE`: object and field permissions and sharing are all enforced (see [Access Mode](#access-mode-user_mode--system_mode)). To loosen that for a specific write:

| Call | What it turns off |
|---|---|
| `.bypassSharing()` | Record sharing only, by routing through a `without sharing` path. |
| `.withSystemMode()` | The permission checks entirely, for framework-internal writes. |

`.bypassSharing()` alone keeps the running user's object and field permissions:

| The save | What happens |
|---|---|
| Sets a field the user cannot create (on an insert) or edit (on an update) | The field is left out of the save, without an error. One warning in the log names the object and the fields, never their values. With `.suppressLogging()` no warning is written. |
| Sets a formula field, an auto-number field or a system field Salesforce fills in itself | The field is left out without a warning. |
| Needs an object permission the user does not have (create, edit, delete or undelete) | Refused, as user mode refuses it. |
| Is an upsert that matches on a key field the user cannot read or cannot edit | Refused. |
| Would leave out a lookup field you registered with its parent record | Refused. |

A refused save gives you the same error user mode gives in an all-or-nothing save. Under `.allowPartial()` you get an error on each refused row instead.

To save a field the user cannot edit, add `.withSystemMode()` as well. It turns off the object and field permission checks too.

The `.bypassSharing()` checks above do not run if you save through `DML_Transaction` and call `setAccessLevel(AccessLevel.USER_MODE.withPermissionSetId(permissionSetId))`. Salesforce then applies the user's permissions plus the permission set's, and record sharing. So `commitWork(false)`, the transaction's own way to ignore record sharing, does not ignore it for that save.

### Access Mode (USER_MODE / SYSTEM_MODE)

Your DML calls default to `AccessLevel.USER_MODE`, which enforces the running user's field and object permissions on every insert, update, delete, upsert, and undelete. That default comes from the `FeatureFlag.UserModeDml_Enabled` custom metadata record, which ships with `IsEnabledByDefault__c = true`.

**Force a specific mode:**

```apex
// Force USER_MODE (user-facing DML enforcing the running user's FLS)
DML_Builder.newTransaction()
	.withUserMode()
	.doInsert(record)
	.execute();

// Force SYSTEM_MODE (framework-internal writes — logs, orchestration records, etc.)
DML_Builder.newTransaction()
	.withSystemMode()
	.doInsert(logEntry)
	.execute();
```

**Emergency kill-switch (a master off-switch you can flip in an incident without a deployment of code):**

- Set `IsEnabledByDefault__c` to `false` on the `FeatureFlag.UserModeDml_Enabled` record (a `kern__FeatureFlag__mdt` record in your org), in Setup or with a metadata deploy.
- It takes effect on the next transaction.
- From then on, every call that doesn't explicitly use `.withUserMode()` or `.withSystemMode()` reverts to `AccessLevel.SYSTEM_MODE`.

See [Security Guide, Safe by Default](Security%20-%20Guide.md#safe-by-default).

**Example:**

```apex
// Operation-level sharing control
Account account = new Account(Name = 'Test Account');
Contact newContact = new Contact(FirstName = 'Test', LastName = 'User');

DML_Builder.newTransaction()
	.doInsert(account)
	.doInsert(newContact, Contact.AccountId, account)
	.execute();
```

### Bypass vs Enforce vs Inherited

There are three ways sharing can apply to a write: bypass it, enforce it, or inherit whatever the calling class uses.

**Example:**

```apex
// Sharing mode examples
List<Account> accounts = new List<Account>{new Account(Name = 'Test')};

// BYPASS: Routes DML through the `without sharing` proxy (sharing rules ignored;
// in USER_MODE the object and field permissions still apply)
DML_Builder.newTransaction()
	.doInsert(accounts)
	.bypassSharing()
	.execute();
// User can insert records they normally could not access

// DEFAULT: USER_MODE (CRUD + FLS + sharing enforced at the database level)
// via the `UserModeDml_Enabled` feature flag shipped `true`
DML_Builder.newTransaction()
	.doInsert(accounts)
	.execute();
// Inserts fail if the running user lacks CRUD, FLS, or sharing access
```

---

## Permission Checking ([`FLOW_CheckObjectPermissions`](reference/apex/FLOW_CheckObjectPermissions.md))

### Object-Level Permissions

Confirm a user is allowed to create, read, edit, or delete an object before you write to it, so you can return a clear message instead of letting the save fail. (Background: [enforcing permissions](https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_classes_perms_enforcing.htm).)

**Example:**

```apex
// Check object permissions before DML
public static void safeCreateAccount(String accountName)
{
	// Check permissions first
	FLOW_CheckObjectPermissions.DTO_Request request = new FLOW_CheckObjectPermissions.DTO_Request();
	request.objectApiName = 'Account';

	List<FLOW_CheckObjectPermissions.DTO_Response> permissions =
		FLOW_CheckObjectPermissions.checkPermissions(
			new List<FLOW_CheckObjectPermissions.DTO_Request>{request}
		);

	FLOW_CheckObjectPermissions.DTO_Response accountPerms = permissions[0];

	if(accountPerms.hasCreateAccess)
	{
		Account account = new Account(Name = accountName);
		DML_Builder.newTransaction().doInsert(account).execute();
	}
	else
	{
		throw new SecurityException('User does not have permission to create Account records');
	}
}
```

### Before DML Checks

Check the permissions once and reuse the result for several operations, rather than checking again for each write.

**Example:**

```apex
// Check all CRUD permissions
public with sharing class AccountManager
{
	private FLOW_CheckObjectPermissions.DTO_Response accountPermissions;

	public AccountManager()
	{
		// Check permissions once during initialization
		FLOW_CheckObjectPermissions.DTO_Request request = new FLOW_CheckObjectPermissions.DTO_Request();
		request.objectApiName = 'Account';

		List<FLOW_CheckObjectPermissions.DTO_Response> results =
			FLOW_CheckObjectPermissions.checkPermissions(
				new List<FLOW_CheckObjectPermissions.DTO_Request>{request}
			);

		accountPermissions = results[0];
	}

	public void createAccount(Account account)
	{
		if(!accountPermissions.hasCreateAccess)
		{
			throw new SecurityException('No create permission');
		}
		DML_Builder.newTransaction().doInsert(account).execute();
	}

	public void updateAccount(Account account)
	{
		if(!accountPermissions.hasEditAccess)
		{
			throw new SecurityException('No edit permission');
		}
		DML_Builder.newTransaction().doUpdate(account).execute();
	}

	public void deleteAccount(Account account)
	{
		if(!accountPermissions.hasDeleteAccess)
		{
			throw new SecurityException('No delete permission');
		}
		DML_Builder.newTransaction().doDelete(account).execute();
	}
}
```

### Field-Level Security

When you need to check access to one specific field rather than the whole object, read its [field-level access](https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_classes_perms_enforcing.htm) from the field's describe information.

**Example:**

```apex
// Check field-level security
public static Boolean canUpdateAccountRevenue()
{
	DescribeFieldResult fieldDescribe = Account.AnnualRevenue.getDescribe();
	return fieldDescribe.isUpdateable();
}

public static void safeUpdateRevenue(Id accountId, Decimal newRevenue)
{
	if(!canUpdateAccountRevenue())
	{
		throw new SecurityException('User cannot update AnnualRevenue field');
	}

	Account account = new Account(Id = accountId, AnnualRevenue = newRevenue);
	DML_Builder.newTransaction().doUpdate(account).execute();
}
```

---

## Test Data Factory

### [TST_Builder](reference/apex/TST_Builder.md)

[`TST_Builder`](reference/apex/TST_Builder.md) writes your test data for you. You name the object, override the fields you care about, and it fills in the rest with valid defaults. You configure it with short chained calls, then one call builds the record.

By hand, you would set every required field, link parents to children, and repeat it in every test.

**What it does for you:**

- **Fills required fields automatically.** You only set what your test cares about; valid defaults cover the rest.
- **Lets you override any field.** Use String field names or type-safe `SObjectField` tokens. Prefer tokens (for example `Account.Name`, not `'Name'`), so a typo is caught at compile time.
- **Creates many records at once.** Use `withCount()` and `buildList()` for bulk data.
- **Builds parent-child graphs.** Use `withChildren()`; children get linked to their parent automatically.
- **Sets record types by developer name.** Use `withRecordType('DeveloperName')` to test record-type-specific behaviour.
- **Controls optional fields.** Use `withDefaultedField()` or `withOptionalField()` to decide which optional fields get populated.
- **Can be extended.** Customise how default values are generated when you need to.

---

### Basic Usage

Build one record. Every required field is filled in for you:

```apex
@IsTest
private static void testBasicAccountCreation()
{
	Test.startTest();

	// Create and insert account with auto-generated required fields
	Account account = (Account)TST_Builder.of(Account.SObjectType).build();

	Test.stopTest();

	Assert.isNotNull(account.Id, 'Account should be inserted');
	Assert.isNotNull(account.Name, 'Required field should be auto-populated');
}
```

Build a record in memory only, without saving it to the database:

```apex
@IsTest
private static void testInMemoryAccount()
{
	Test.startTest();

	// Create account in memory only (no DML)
	Account account = (Account)TST_Builder.of(Account.SObjectType)
		.withoutInsertion()
		.build();

	Test.stopTest();

	Assert.isNull(account.Id, 'Account should not be inserted');
	Assert.isNotNull(account.Name, 'Required fields still populated');
}
```

---

### Field Overrides

Set the fields you care about, either with **String field names** or with **type-safe `SObjectField` tokens** (tokens are preferred, since the compiler catches a typo):

**Single Field Override:**

```apex
@IsTest
private static void testFieldOverrides()
{
	Test.startTest();

	// Using SObjectField tokens (recommended - compile-time safety)
	Account account = (Account)TST_Builder.of(Account.SObjectType)
		.withOverride(Account.Name, 'ACME Corp')
		.withOverride(Account.Industry, 'Technology')
		.withOverride(Account.AnnualRevenue, 1000000)
		.build();

	Test.stopTest();

	Assert.areEqual('ACME Corp', account.Name);
	Assert.areEqual('Technology', account.Industry);
	Assert.areEqual(1000000, account.AnnualRevenue);
}
```

**Multiple Field Overrides:**

```apex
@IsTest
private static void testBulkOverrides()
{
	Test.startTest();

	// Using Map for multiple overrides
	Account account = (Account)TST_Builder.of(Account.SObjectType)
		.withOverrides(new Map<SObjectField, Object>
		{
			Account.Name => 'Test Account',
			Account.Phone => '555-1234',
			Account.Industry => 'Finance',
			Account.NumberOfEmployees => 500
		})
		.build();

	Test.stopTest();

	Assert.areEqual('Test Account', account.Name);
	Assert.areEqual('555-1234', account.Phone);
}
```

**String-Based Overrides** (when SObjectField tokens aren't available):

```apex
Contact contact = (Contact)TST_Builder.of(Contact.SObjectType)
	.withOverride('FirstName', 'John')
	.withOverride('LastName', 'Doe')
	.withOverrides(new Map<String, Object>{'Email' => 'john@example.com'})
	.build();
```

---

### Bulk Record Creation

To create many records at once, set how many with `withCount()` and build them with `buildList()`:

```apex
@IsTest
private static void testBulkCreation()
{
	Test.startTest();

	// Create and insert 200 accounts in bulk
	List<Account> accounts = (List<Account>)TST_Builder.of(Account.SObjectType)
		.withCount(200)
		.withOverride(Account.Industry, 'Technology')
		.buildList();

	Test.stopTest();

	Assert.areEqual(200, accounts.size());
	Assert.isNotNull(accounts[0].Id, 'Records should be inserted');
	Assert.areEqual('Technology', accounts[0].Industry);
}
```

**Pattern for Custom Bulk Data:**

```apex
@IsTest
private static void testCustomBulkData()
{
	Integer numberOfAccounts = 100;
	List<Account> accounts = new List<Account>();

	Test.startTest();

	// Create records in memory with custom values per record
	for(Integer i = 0; i < numberOfAccounts; i++)
	{
		Account account = (Account)TST_Builder.of(Account.SObjectType)
			.withOverrides(new Map<SObjectField, Object>
			{
				Account.Name => 'Account ' + i,
				Account.AnnualRevenue => 100000 * i
			})
			.withoutInsertion()
			.build();
		accounts.add(account);
	}

	// Insert all at once using DML_Builder
	DML_Builder.newTransaction().doInsert(accounts).execute();

	Test.stopTest();

	Assert.areEqual(numberOfAccounts, accounts.size());
}
```

---

### Record Type Support

Assign a record type by its developer name:

```apex
@IsTest
private static void testRecordType()
{
	Test.startTest();

	Account account = (Account)TST_Builder.of(Account.SObjectType)
		.withRecordType('Enterprise_Account')
		.withOverride(Account.Name, 'Enterprise Corp')
		.build();

	Test.stopTest();

	Assert.isNotNull(account.RecordTypeId);
	// Verify it's the correct record type
	RecordType recordType = (RecordType)QRY_Builder.selectFrom(RecordType.SObjectType)
		.fields(new List<SObjectField>{RecordType.DeveloperName})
		.condition(RecordType.Id).equals(account.RecordTypeId)
		.getFirst();
	Assert.areEqual('Enterprise_Account', recordType.DeveloperName);
}
```

**Error Handling:**

```apex
try
{
	TST_Builder.of(Account.SObjectType)
		.withRecordType('NonExistent_RecordType')
		.build();
	Assert.fail('Should throw IllegalArgumentException');
}
catch(Exception error)
{
	Assert.isInstanceOfType(error, IllegalArgumentException.class, 'Incorrect Exception Type');
}
```

---

### Parent-Child Relationships

Build a parent and its children together; the framework links each child to its parent for you. There are several ways to do this, depending on how much you need to customise the children. The numbered patterns go from simplest to most flexible.

#### Pattern 1: Simple Child Creation (No Field Overrides)

```apex
@IsTest
private static void testSimpleChildren()
{
	Test.startTest();

	// Create account with 3 contacts (all fields auto-defaulted)
	Account account = (Account)TST_Builder.of(Account.SObjectType)
		.withOverride(Account.Name, 'Parent Account')
		.withChildren(Contact.SObjectType, 3)
		.build();

	Test.stopTest();

	Assert.isNotNull(account.Id);
	List<Contact> contacts = QRY_Builder.selectFrom(Contact.SObjectType)
		.fields(new List<SObjectField>{Contact.Id, Contact.AccountId})
		.condition(Contact.AccountId).equals(account.Id)
		.toList();
	Assert.areEqual(3, contacts.size(), 'Should have 3 child contacts');
	Assert.areEqual(account.Id, contacts[0].AccountId, 'Foreign key should be set');
}
```

#### Pattern 2: Children with Field Overrides

```apex
@IsTest
private static void testChildrenWithOverrides()
{
	Test.startTest();

	// Create account with 2 contacts with specific field values
	Account account = (Account)TST_Builder.of(Account.SObjectType)
		.withOverride(Account.Name, 'ACME Corp')
		.withChildren(Contact.SObjectType, 2, new Map<SObjectField, Object>
		{
			Contact.FirstName => 'John',
			Contact.LastName => 'Smith',
			Contact.Email => 'john.smith@acme.com'
		})
		.build();

	Test.stopTest();

	List<Contact> contacts = QRY_Builder.selectFrom(Contact.SObjectType)
		.fields(new List<SObjectField>{Contact.FirstName, Contact.LastName, Contact.Email})
		.condition(Contact.AccountId).equals(account.Id)
		.toList();
	Assert.areEqual(2, contacts.size());
	Assert.areEqual('John', contacts[0].FirstName);
	Assert.areEqual('Smith', contacts[0].LastName);
}
```

#### Pattern 3: Children Using Builder (Complex Configuration)

```apex
@IsTest
private static void testChildrenWithBuilder()
{
	Test.startTest();

	// Create account with opportunities using nested builder for complex config
	Account account = (Account)TST_Builder.of(Account.SObjectType)
		.withOverride(Account.Name, 'Sales Account')
		.withChildren(
			TST_Builder.of(Opportunity.SObjectType)
				.withCount(5)
				.withOverride(Opportunity.StageName, 'Prospecting')
				.withOverride(Opportunity.CloseDate, Date.today().addDays(30))
				.withDefaultedField(Opportunity.Description) // Force optional field population
		)
		.build();

	Test.stopTest();

	List<Opportunity> opportunities = QRY_Builder.selectFrom(Opportunity.SObjectType)
		.fields(new List<SObjectField>{Opportunity.Id, Opportunity.StageName, Opportunity.AccountId})
		.condition(Opportunity.AccountId).equals(account.Id)
		.toList();
	Assert.areEqual(5, opportunities.size());
	Assert.areEqual('Prospecting', opportunities[0].StageName);
}
```

#### Pattern 4: Multiple Child Types

```apex
@IsTest
private static void testMultipleChildTypes()
{
	Test.startTest();

	// Create account with both contacts and opportunities
	Account account = (Account)TST_Builder.of(Account.SObjectType)
		.withOverride(Account.Name, 'Multi-Child Account')
		.withChildren(Contact.SObjectType, 3, new Map<SObjectField, Object>
		{
			Contact.LastName => 'Contact'
		})
		.withChildren(Opportunity.SObjectType, 2, new Map<SObjectField, Object>
		{
			Opportunity.StageName => 'Closed Won',
			Opportunity.CloseDate => Date.today()
		})
		.build();

	Test.stopTest();

	List<Contact> contacts = QRY_Builder.selectFrom(Contact.SObjectType)
		.fields(new List<SObjectField>{Contact.Id})
		.condition(Contact.AccountId).equals(account.Id)
		.toList();
	List<Opportunity> opportunities = QRY_Builder.selectFrom(Opportunity.SObjectType)
		.fields(new List<SObjectField>{Opportunity.Id})
		.condition(Opportunity.AccountId).equals(account.Id)
		.toList();

	Assert.areEqual(3, contacts.size());
	Assert.areEqual(2, opportunities.size());
}
```

#### Pattern 5: Explicit Relationship Name (Edge Cases)

When an object has **more than one lookup to the same parent type**, name the relationship explicitly so the framework knows which one you mean:

```apex
@IsTest
private static void testExplicitRelationshipName()
{
	Test.startTest();

	// Custom object with two lookups to Contact: PrimaryContact__c and SecondaryContact__c
	// Must specify explicit relationship name when there are multiple relationships
	Foobar__c foobar = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
		.withOverride(Foobar__c.Name, 'Test')
		.withChildren('PrimaryContacts__r',
			TST_Builder.of(Contact.SObjectType).withCount(2)
		)
		.withChildren('SecondaryContacts__r',
			TST_Builder.of(Contact.SObjectType).withCount(1)
		)
		.build();

	Test.stopTest();
}
```

#### In-Memory Parent-Child Graphs (No DML)

```apex
@IsTest
private static void testInMemoryGraph()
{
	Test.startTest();

	// Create entire graph in memory without database insertion
	Account account = (Account)TST_Builder.of(Account.SObjectType)
		.withOverride(Account.Name, 'Test Account')
		.withChildren(Contact.SObjectType, 2, new Map<SObjectField, Object>
		{
			Contact.LastName => 'Smith'
		})
		.withoutInsertion()
		.build();

	Test.stopTest();

	Assert.isNull(account.Id, 'Parent should not be inserted');
	Assert.areEqual(2, account.Contacts.size(), 'Should have 2 contacts in memory');
	Assert.areEqual('Smith', account.Contacts[0].LastName);
	Assert.isNull(account.Contacts[0].Id, 'Children should not be inserted');
}
```

#### Bulk Parents with Children

```apex
@IsTest
private static void testBulkParentsWithChildren()
{
	Test.startTest();

	// Create 10 accounts, each with 3 contacts
	List<Account> accounts = (List<Account>)TST_Builder.of(Account.SObjectType)
		.withCount(10)
		.withOverride(Account.Name, 'Bulk Parent')
		.withChildren(Contact.SObjectType, 3, new Map<SObjectField, Object>
		{
			Contact.LastName => 'Child'
		})
		.buildList();

	Test.stopTest();

	Assert.areEqual(10, accounts.size());

	// Verify each account has 3 contacts
	Set<Id> accountIds = new Map<Id, Account>(accounts).keySet();
	List<Contact> allContacts = QRY_Builder.selectFrom(Contact.SObjectType)
		.fields(new List<SObjectField>{Contact.Id, Contact.AccountId})
		.condition(Contact.AccountId).isIn(new List<Id>(accountIds))
		.toList();

	// Group contacts by account to verify counts
	Map<Id, List<Contact>> contactsByAccount = new Map<Id, List<Contact>>();
	for(Contact contact : allContacts)
	{
		if(!contactsByAccount.containsKey(contact.AccountId))
		{
			contactsByAccount.put(contact.AccountId, new List<Contact>());
		}
		contactsByAccount.get(contact.AccountId).add(contact);
	}

	for(Account account : accounts)
	{
		Assert.areEqual(3, contactsByAccount.get(account.Id).size(), 'Each account should have 3 contacts');
	}
}
```

---

### Optional and Defaulted Fields

By default, optional fields are left empty. Use these methods to force one to be populated, or to stop a normally-populated field from being set:

#### Force Optional Fields to be Populated

```apex
@IsTest
private static void testDefaultedFields()
{
	Test.startTest();

	// Force Description (optional field) to be auto-populated
	Account account = (Account)TST_Builder.of(Account.SObjectType)
		.withOverride(Account.Name, 'Test Account')
		.withDefaultedField(Account.Description)
		.withDefaultedField(Account.Website)
		.build();

	Test.stopTest();

	Assert.isNotNull(account.Description, 'Optional field should be populated');
	Assert.isNotNull(account.Website, 'Optional field should be populated');
}
```

**Using List:**

```apex
Account account = (Account)TST_Builder.of(Account.SObjectType)
	.withDefaultedFields(new List<Object>
	{
		Account.Description,
		Account.Industry,
		Account.Website
	})
	.build();
```

#### Multi-Level Relationship Paths

To populate a field on a parent or grandparent record, write the path with dots. The framework accepts either **relationship names** (such as `'Account.Parent'`) or **field names** (such as `'AccountId.ParentId'`), and you can mix the two:

```apex
@IsTest
private static void testMultiLevelRelationships()
{
	Test.startTest();

	// Using relationship names (traditional style)
	Contact contact1 = (Contact)TST_Builder.of(Contact.SObjectType)
		.withDefaultedField('Account.Parent.Name')  // Account -> Parent Account -> Name
		.build();

	// Using field names (also supported)
	Contact contact2 = (Contact)TST_Builder.of(Contact.SObjectType)
		.withDefaultedField('AccountId.ParentId.Name')  // Same result as above
		.build();

	// Mixed format also works
	Contact contact3 = (Contact)TST_Builder.of(Contact.SObjectType)
		.withDefaultedField('AccountId.Parent.Name')  // Field name + relationship name
		.build();

	Test.stopTest();

	// All three create the same hierarchy: Contact -> Account -> Parent Account
	Assert.isNotNull(contact1.Account.ParentId, 'Parent Account should be created');
	Assert.isNotNull(contact1.Account.Parent.Name, 'Parent Account Name should be populated');
}
```

**Custom Lookup Fields:**

```apex
// For custom lookups, both formats work
// Relationship name: Lookup__r.Lookup__r.Name
// Field name: Lookup__c.Lookup__c.Name

Foobar__c record = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
	.withDefaultedField('Lookup__c.Lookup__c.Name')  // Using field names
	.build();
```

**Polymorphic Fields:**

Some lookup fields can point to more than one object type. For example, `OwnerId` can be a User or a Queue. The framework can't guess which one you want, so it skips these fields automatically and logs an informational message:

```apex
@IsTest
private static void testPolymorphicFieldHandling()
{
	// OwnerId is polymorphic (can be User or Queue)
	// The framework will skip it and log an info message
	Case caseRecord = (Case)TST_Builder.of(Case.SObjectType)
		.withDefaultedField(Case.OwnerId)  // Skipped - polymorphic
		.withDefaultedField(Case.AccountId)  // Populated normally
		.build();

	// OwnerId is not auto-populated due to polymorphism
	// Use withOverride() to set an explicit value if needed
	Case caseWithOwner = (Case)TST_Builder.of(Case.SObjectType)
		.withOverride(Case.OwnerId, UserInfo.getUserId())  // Explicit value
		.build();
}
```

#### Mark Required Fields as Optional

Stop the framework from filling in a field it would normally populate:

```apex
@IsTest
private static void testOptionalFields()
{
	Test.startTest();

	// Prevent BusinessHoursId (normally auto-populated) from being set
	Case caseRecord = (Case)TST_Builder.of(Case.SObjectType)
		.withOptionalField(Case.BusinessHoursId)
		.withoutInsertion()
		.build();

	Test.stopTest();

	Assert.isNull(caseRecord.BusinessHoursId, 'Field marked optional should be null');
}
```

**Using List:**

```apex
Case caseRecord = (Case)TST_Builder.of(Case.SObjectType)
	.withOptionalFields(new List<Object>
	{
		Case.BusinessHoursId,
		Case.EntitlementId
	})
	.withoutInsertion()
	.build();
```

**Global Optional Fields** (transaction-wide):

```apex
@IsTest
private static void testGlobalOptionalFields()
{
	// Mark Phone as optional for ALL builds in this transaction
	TST_Builder.optionalFields.add('Phone');

	Account account1 = (Account)TST_Builder.of(Account.SObjectType)
		.withoutInsertion()
		.build();

	Account account2 = (Account)TST_Builder.of(Account.SObjectType)
		.withoutInsertion()
		.build();

	Assert.isNull(account1.Phone);
	Assert.isNull(account2.Phone);
}
```

---

### Advanced Features

#### Mock ID Generation for Query Mocking

Sometimes you need a record that has an Id but was never saved to the database, for example when you mock a query so your test runs without DML. `withoutInsertion(true)` gives you exactly that: a record with a generated mock Id and no database write.

**Difference between `withoutInsertion()` and `withoutInsertion(true)`:**

| Method                   | ID Generated  | Use Case                                    |
|--------------------------|---------------|---------------------------------------------|
| `withoutInsertion()`     | No (null)     | Simple in-memory objects for unit testing   |
| `withoutInsertion(true)` | Yes (mock ID) | Query mocking, code that requires valid IDs |

**Example - Creating mock records with IDs:**

```apex
@IsTest
private static void testMockIdGeneration()
{
	Test.startTest();

	// withoutInsertion() - No ID generated
	Account accountNoId = (Account)TST_Builder.of(Account.SObjectType)
		.withOverride(Account.Name, 'No ID Account')
		.withoutInsertion()
		.build();

	Assert.isNull(accountNoId.Id, 'ID should be null');

	// withoutInsertion(true) - Mock ID generated
	Account accountWithMockId = (Account)TST_Builder.of(Account.SObjectType)
		.withOverride(Account.Name, 'Mock ID Account')
		.withoutInsertion(true)
		.build();

	Assert.isNotNull(accountWithMockId.Id, 'Mock ID should be generated');
	Assert.areEqual(18, accountWithMockId.Id.length(), 'Should be valid 18-char ID');

	Test.stopTest();
}
```

**Using with Query Mocking:**

```apex
@IsTest
private static void testWithQueryMocking()
{
	// Create mock records with IDs for query mocking
	List<Account> mockAccounts = new List<Account>();
	for(Integer i = 0; i < 5; i++)
	{
		Account mockAccount = (Account)TST_Builder.of(Account.SObjectType)
			.withOverrides(new Map<SObjectField, Object>
			{
				Account.Name => 'Mock Account ' + i,
				Account.Industry => 'Technology'
			})
			.withoutInsertion(true) // Generate mock ID
			.build();
		mockAccounts.add(mockAccount);
	}

	// Configure query mock (see Selectors - Guide for full details)
	QRY_Builder.setMock(Account.SObjectType, mockAccounts);

	Test.startTest();
	// All QRY_Builder calls for Account now return mock data
	List<Account> results = QRY_Builder.selectFrom(Account.SObjectType)
		.fields(new List<SObjectField>{Account.Name, Account.Industry})
		.toList();
	Test.stopTest();

	Assert.areEqual(5, results.size());
	Assert.isNotNull(results[0].Id, 'Mock records have IDs');

	// Cleanup
	QRY_Builder.clearMocks();
}
```

**When to use `withoutInsertion(true)`:**

- Query mocking scenarios (records need realistic IDs)
- Testing code that validates `record.Id != null`
- Creating records for Map keys or Set membership based on Id
- Testing relationship lookups where foreign key Ids are required

**See Also:** [Selectors - Guide](Selectors%20-%20Guide.md#testing) for complete Query Mocking documentation.

---

#### Auto-Default Marker

When you pass an override map but want one field to keep its auto-generated value, set that field to `autoDefaultFieldValueProvider`:

```apex
Account account = (Account)TST_Builder.of(Account.SObjectType)
	.withOverrides(new Map<String, Object>
	{
		'Name' => 'Test Account',
		'Description' => TST_Builder.autoDefaultFieldValueProvider // Auto-generate value
	})
	.withoutInsertion()
	.build();

Assert.isNotNull(account.Description, 'Auto-default marker triggers value generation');
```

#### Custom Default Value Provider

When the built-in defaults don't suit your org, you can change how default values are generated by extending [`UTIL_SObjectBuilderDefaultProvider`](reference/apex/UTIL_SObjectBuilderDefaultProvider.md). Extend that class rather than the bare `TST_Builder.DefaultValueProvider` it is built on: it carries every default the builder normally supplies, so your subclass changes only what you override and inherits the rest.

```apex
public inherited sharing class CustomDefaultProvider extends UTIL_SObjectBuilderDefaultProvider
{
	public override String getEmailDefaultValue(DescribeFieldResult fieldDescribe, Integer recordIndex)
	{
		// Custom logic: always use a specific domain for email fields
		return 'test' + recordIndex + '@mycustomdomain.com';
	}

	public override Set<SObjectField> defineSObjectOptionalFields(SObjectType sObjectType)
	{
		if(sObjectType == Contact.SObjectType)
		{
			return new Set<SObjectField>{ Contact.Department };
		}
		return super.defineSObjectOptionalFields(sObjectType);
	}
}

// In test setup
TST_Builder.defaultValueProvider = new CustomDefaultProvider();
```

> **End a `defineSObjectOptionalFields` override with the `super` call**, as above, for every type you
> are not handling yourself. Replace the method outright and building a `User` starts to fail.
>
> The reason: the inherited behaviour marks each `UserPermissions` field on `User` as optional. That
> keeps the builder from tripping over the permission fields your org's licences control when it creates a `User`.

---

### Complete Example

This example pulls several features together: a record type, field overrides, optional fields, and two kinds of children.

```apex
@IsTest
private static void testCompleteExample()
{
	Test.startTest();

	// Create account with:
	// - Specific record type
	// - Field overrides
	// - Optional field population
	// - Multiple child types
	Account account = (Account)TST_Builder.of(Account.SObjectType)
		.withRecordType('Enterprise_Account')
		.withOverrides(new Map<SObjectField, Object>
		{
			Account.Name => 'Enterprise Corp',
			Account.Industry => 'Technology',
			Account.AnnualRevenue => 5000000
		})
		.withDefaultedField(Account.Description)
		.withDefaultedField(Account.Website)
		.withChildren(Contact.SObjectType, 3, new Map<SObjectField, Object>
		{
			Contact.LastName => 'Executive',
			Contact.Department => 'Leadership'
		})
		.withChildren(
			TST_Builder.of(Opportunity.SObjectType)
				.withCount(2)
				.withOverride(Opportunity.StageName, 'Prospecting')
				.withOverride(Opportunity.CloseDate, Date.today().addDays(30))
				.withDefaultedField(Opportunity.Description)
		)
		.build();

	Test.stopTest();

	// Verify parent
	Assert.isNotNull(account.Id);
	Assert.areEqual('Enterprise Corp', account.Name);
	Assert.isNotNull(account.Description, 'Optional field should be populated');

	// Verify children
	List<Contact> contacts = QRY_Builder.selectFrom(Contact.SObjectType)
		.fields(new List<SObjectField>{Contact.Id, Contact.LastName})
		.condition(Contact.AccountId).equals(account.Id)
		.toList();
	List<Opportunity> opportunities = QRY_Builder.selectFrom(Opportunity.SObjectType)
		.fields(new List<SObjectField>{Opportunity.Id, Opportunity.StageName})
		.condition(Opportunity.AccountId).equals(account.Id)
		.toList();

	Assert.areEqual(3, contacts.size());
	Assert.areEqual('Executive', contacts[0].LastName);
	Assert.areEqual(2, opportunities.size());
	Assert.areEqual('Prospecting', opportunities[0].StageName);
}
```

---

## Bulk Utilities (`UTIL_BulkUpdates` & `UTIL_PurgeRecords`)

### Bulk Field Updates

When you want to apply the same field change to many records, `UTIL_BulkUpdates` does it in batches for you, so you don't write the query-loop-and-save code yourself.

**Example:**

```apex
// Invalidate email fields in bulk
// Invalidate all Account email addresses
UTIL_BulkUpdates.invalidateEmailFields(Account.PersonEmail);

// Invalidate Contact emails with custom batch size
UTIL_BulkUpdates.invalidateEmailFields(Contact.Email, 200);

// Invalidate with all-or-nothing transaction control
UTIL_BulkUpdates.invalidateEmailFields('Lead', 'Email', 100, true);
```

**Bulk Owner Updates:**

```apex
// Update record ownership in bulk
UTIL_BulkUpdates.updateOwner('Account', 'Support Rep', 'jane.smith@example.com', 200, true);
```

**Generic Field Updates:**

```apex
// Update any field with search conditions
// Archive all Closed Won opportunities with Status__c = 'Archived'
QRY_Condition.Evaluable searchConditions = new QRY_Condition.AndCondition()
	.add(new QRY_Condition.FieldCondition('StageName', QRY_Condition.Operator.EQUALS, 'Closed Won'));

UTIL_BulkUpdates.updateField(
	'Opportunity',
	'Status__c',
	'Archived',
	searchConditions,
	200,
	false
);
```

### Purge Records (`UTIL_PurgeRecords`)

Clean up data by deleting every record of a type, or only the records older than a cutoff.

**Example:**

```apex
// Purge old records using batch processing
// Delete all test data
UTIL_PurgeRecords.deleteAllRecords(Account.SObjectType);

// Delete records older than 90 days
UTIL_PurgeRecords.deleteOlderThanNDays('Contact', 90);

// Delete records older than 30 days based on custom date field
UTIL_PurgeRecords.deleteOlderThanNDays('Task', 'ActivityDate', 30);

// Delete with specific batch size and atomicity
UTIL_PurgeRecords.deleteAllRecords('Lead', false, 200);
```

### Deactivate Users

Deactivate users who have been inactive, in batches, and on a schedule if you want it to run regularly.

**Deactivate Users in Bulk:**

```apex
// Deactivate inactive users by profile
// Deactivate users inactive for 180 days
Set<String> profiles = new Set<String>{'Standard User', 'Chatter Free User'};
UTIL_BulkUpdates.deactivateUsers(profiles, 180);

// With custom batch size and all-or-nothing
Set<String> supportProfiles = new Set<String>{'Support Rep'};
UTIL_BulkUpdates.deactivateUsers(
	supportProfiles,
	90,
	200,
	true
);
```

**On a schedule:**

```apex
// Schedule user deactivation job
// Schedule job to deactivate users inactive for 180 days
String cronExpression = '0 0 2 * * ?'; // Daily at 2 AM

SCHED_DeactivateUsers job = new SCHED_DeactivateUsers();
job.setParameterValues(new DTO_NameValues(new Map<String, String>
{
	'profileNames' => 'Standard User|Chatter Free User',
	'minimumNumberOfDays' => '180',
	'batchSize' => '200',
	'allOrNothing' => 'false'
}));

System.schedule('Deactivate Inactive Users', cronExpression, job);
```

### Batch Processing

For very large volumes, run your writes in [batch Apex](https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_batch_interface.htm) and call `DML_Builder` inside each batch chunk.

**Example:**

```apex
// Custom batch for bulk updates
public with sharing class BATCH_UpdateAccountIndustry implements Database.Batchable<SObject>
{
	public Database.QueryLocator start(Database.BatchableContext context)
	{
		return QRY_Builder.selectFrom(Account.SObjectType)
			.fields(new List<SObjectField>{Account.Id, Account.Industry})
			.condition(Account.Industry).isNull()
			.toQueryLocator();
	}

	public void execute(Database.BatchableContext context, List<Account> scope)
	{
		for(Account account : scope)
		{
			account.Industry = 'Other';
		}

		// Use DML_Builder for bulk update with sharing bypass
		DML_Builder.newTransaction()
			.doUpdate(scope)
			.bypassSharing()
			.allowPartial()
			.execute();
	}

	public void finish(Database.BatchableContext context)
	{
		LOG_Builder.build().info('Batch complete').emitAt('BATCH_UpdateAccountIndustry.finish');
	}
}

// Execute batch
Database.executeBatch(new BATCH_UpdateAccountIndustry(), 200);
```

---

## How does it work?

The framework is made of four parts that build on each other, plus three helpers:

| Part | What it does |
|---|---|
| [`DML_Transaction`](reference/apex/DML_Transaction.md) | Keeps a complex, multi-object save together: register everything, then commit it all or roll it all back (the Unit of Work pattern). |
| [`DML_Builder`](reference/apex/DML_Builder.md) | The everyday tool you call. It runs bulk inserts, updates, and deletes and lets you decide how sharing applies. |
| Sharing Proxy | Decides whether a write respects the running user's record visibility or runs with elevated access. |
| [`FLOW_CheckObjectPermissions`](reference/apex/FLOW_CheckObjectPermissions.md) | Confirms a user is allowed to create, read, update, or delete an object before you write to it. |
| [`TST_Builder`](reference/apex/TST_Builder.md) (helper) | Builds test records, with required fields filled in for you, so test setup stays short. |
| `UTIL_PurgeRecords` (helper) | Deletes records in bulk for cleanup. |
| `UTIL_BulkUpdates` (helper) | Applies the same field change across many records at once. |

> **Responsibilities:** The DML framework manages database writes (insert, update, delete, upsert, undelete) with transactional integrity,
> sharing control, and error handling. It does not query data (use selectors for that), and it does not contain business logic.

### Architecture Diagram

```text
+---------------------------------------------------------------------------+
|                       DML FRAMEWORK ARCHITECTURE                          |
+---------------------------------------------------------------------------+
|                                                                           |
|  Your Code / Trigger Action / Flow Invocable                              |
|        |                                                                  |
|        v                                                                  |
|  +-------------------------------------------------------------------+   |
|  |  Layer 4: FLOW_CheckObjectPermissions                             |   |
|  |  - Validates CRUD/FLS before DML                                  |   |
|  |  - Invocable for Flow integration                                 |   |
|  +-------------------------------+-----------------------------------+   |
|                                  |                                       |
|                                  v                                       |
|  +-------------------------------------------------------------------+   |
|  |  Layer 1: DML_Transaction (Unit of Work)                          |   |
|  |  - Registers insert, update, delete, upsert, undelete            |   |
|  |  - Manages parent-child relationship resolution                   |   |
|  |  - Single atomic commit or full rollback                          |   |
|  +-------------------------------+-----------------------------------+   |
|                                  |                                       |
|                                  v                                       |
|  +-------------------------------------------------------------------+   |
|  |  Layer 2: DML_Builder (Standardized DML)                          |   |
|  |  - Chained calls: newTransaction().doInsert().execute()           |   |
|  |  - Partial success (.allowPartial()) or all-or-nothing           |   |
|  |  - TransactionResult with error inspection                        |   |
|  +-------------------------------+-----------------------------------+   |
|                                  |                                       |
|                                  v                                       |
|  +-------------------------------------------------------------------+   |
|  |  Layer 3: Sharing Proxy                                           |   |
|  |  - BYPASS: without sharing context                                |   |
|  |  - ENFORCE: with sharing context                                  |   |
|  |  - INHERITED: caller's sharing context (default)                  |   |
|  +-------------------------------+-----------------------------------+   |
|                                  |                                       |
|                                  v                                       |
|                     +------------------------+                           |
|                     |    Database.*           |                           |
|                     |  (Salesforce DML)       |                           |
|                     +------------------------+                           |
|                                                                           |
+---------------------------------------------------------------------------+
```

### Layer 1: [`DML_Transaction`](reference/apex/DML_Transaction.md)

**What it does:** Lets you register a set of related records, then save them all in a single transaction. Either every change commits, or if anything fails, all of them roll back. This is the [Unit of Work](https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/langCon_apex_transaction.htm) pattern.

**When to use it:** When several records must succeed or fail together, especially when some of them are parents and children that need linking.

**What it handles for you:**

- Registers records for insert, update, delete, upsert, and undelete
- Works out the save order so parents go in before children
- Fills in the child's lookup to its parent automatically
- Commits everything in one transaction
- Rolls the whole transaction back if any part fails

**Example:**

```apex
// Creates an Account with related Contacts in a single transaction
DML_Builder.newTransaction()
	.doInsert(account)
	.doInsert(contact1, Contact.AccountId, account)
	.doInsert(contact2, Contact.AccountId, account)
	.execute(); // All objects inserted in correct order with relationships maintained
```

### Layer 2: [`DML_Builder`](reference/apex/DML_Builder.md)

**What it does:** Gives you one set of methods for every [database write](https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/langCon_apex_dml.htm), with sharing control and error handling already built in, so you don't repeat that boilerplate everywhere.

**When to use it:** For every
database [insert](https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/langCon_apex_dml_examples_insert.htm), [update](https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/langCon_apex_dml_examples_update.htm), [delete](https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/langCon_apex_dml_examples_delete.htm), [upsert](https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/langCon_apex_dml_examples_upsert.htm),
and [undelete](https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/langCon_apex_dml_examples_undelete.htm). This is the layer you call day to day.

**What it handles for you:**

- Bulk processing of many records in one call
- Choosing how sharing is enforced
- Deciding between all-or-nothing and partial commit
- Catching and surfacing errors
- Managing the platform [Database.SaveResult](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_database_saveresult.htm)/[Database.DeleteResult](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_database_deleteresult.htm)
  objects for you

**Example:**

```apex
// Bulk inserts accounts with sharing enforced
List<Account> accounts = new List<Account>
{
	new Account(Name = 'Account 1'),
	new Account(Name = 'Account 2'),
	new Account(Name = 'Account 3')
};

DML_Builder.TransactionResult result = DML_Builder.newTransaction()
	.doInsert(accounts)
	.execute();
```

### Layer 3: Sharing Proxy

**What it does:** Decides how strictly a write respects security. A write can run with the current user's read/write permissions and record sharing enforced (USER_MODE), or skip the object and field permission checks for system work (SYSTEM_MODE, which leaves record sharing following the calling class). It also controls how [sharing rules](https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_security_sharing_rules.htm) apply.

**When to use it:** When you want explicit control over that security level, or over sharing, for a particular operation.

**What it handles for you:**

- A safe default that's on automatically: USER_MODE enforces FLS (field-level security), CRUD (object create/read/update/delete permissions), and sharing, governed by the `FeatureFlag.UserModeDml_Enabled` record
- `.withUserMode()` / `.withSystemMode()` to pick the security level explicitly
- `.bypassSharing()` to route a write through a `without sharing` path. In USER_MODE the user's object and field permissions still apply; add `.withSystemMode()` to turn those checks off too
- Per-operation control through short chained method calls
- [AccessLevel.SYSTEM_MODE](https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_classes_enforce_usermode.htm) support

**Example:**

```apex
// Default (USER_MODE): CRUD + FLS + sharing all enforced at the database level
DML_Builder.newTransaction().doInsert(accounts).execute();

// Bypass sharing for system operations (routes through `without sharing` proxy;
// object and field permissions still apply, and fields the user cannot create are left out)
DML_Builder.newTransaction().doInsert(accounts).bypassSharing().execute();

// Framework-internal writes (e.g., log rows) — bypass CRUD/FLS
DML_Builder.newTransaction().doInsert(logEntries).withSystemMode().execute();
```

### Layer 4: [`FLOW_CheckObjectPermissions`](reference/apex/FLOW_CheckObjectPermissions.md)

**What it does:** Checks whether a user is allowed to perform an operation before you attempt it, so you can stop a forbidden write with a clear message instead of an unhandled error. (See the Salesforce reference on [enforcing permissions](https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_classes_perms_enforcing.htm).)

**When to use it:** Before a write in user-facing features, or on public sites and communities where users may have limited access.

**What it handles for you:**

- [Object-level permission](https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_methods_system_sobject_describe.htm) checks
- Confirms create, read, update, and delete access
- An invocable method so Flows can call it too
- Checks based on the object's describe information

**Example:**

```apex
// Checks if user can create Account records
FLOW_CheckObjectPermissions.DTO_Request request = new FLOW_CheckObjectPermissions.DTO_Request();
request.objectApiName = 'Account';

List<FLOW_CheckObjectPermissions.DTO_Response> results =
	FLOW_CheckObjectPermissions.checkPermissions(new List<FLOW_CheckObjectPermissions.DTO_Request>{request});

if(results[0].hasCreateAccess)
{
	Account account = new Account(Name = 'New Account');
	DML_Builder.newTransaction().doInsert(account).execute();
}
else
{
	LOG_Builder.build().error('User does not have permission to create Account records').emitAt('MyClass.myMethod');
}
```

---

## Testing

To test code that writes data, you have two tools. `TST_Builder` creates the test records, and `TST_Mock` lets you stand in mock query results so a test can run without touching the database. Building records through the builder instead of inline DML keeps tests short and easy to read.

**Testing DML_Builder operations:**

```apex
@IsTest(seeAllData=false isParallel=true)
private class MyService_TEST
{
	@IsTest
	private static void shouldInsertRecordsSuccessfully()
	{
		List<Foobar__c> records = (List<Foobar__c>)TST_Builder.of(Foobar__c.SObjectType)
			.withCount(3)
			.withoutInsertion()
			.buildList();

		Test.startTest();
		DML_Builder.TransactionResult result = DML_Builder.newTransaction()
			.doInsert(records)
			.execute();
		Test.stopTest();

		Assert.isTrue(result.isSuccess(), 'All records should insert successfully');
	}
}
```

**Testing transactional DML:**

```apex
@IsTest
private static void shouldCommitRelatedRecords()
{
	Foobar__c parent = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
		.withoutInsertion()
		.build();

	Test.startTest();
	DML_Builder.newTransaction()
		.doInsert(parent)
		.execute();
	Test.stopTest();

	List<Foobar__c> inserted = QRY_Builder.selectFrom(Foobar__c.SObjectType).toList();
	Assert.areEqual(1, inserted.size(), 'One record should be committed');
}
```

**Testing with mock data (no DML):**

When your code reads data through selectors, register mock records with `TST_Mock` so the selector returns them. The test skips DML entirely, which keeps it fast:

```apex
@IsTest
private static void shouldProcessMockedRecords()
{
	Foobar__c mock = (Foobar__c)TST_Mock.of(Foobar__c.SObjectType)
		.withOverride(Foobar__c.Name, 'Test Record')
		.build();

	Foobar__c result = (Foobar__c)new SEL_Foobar().findById(mock.Id);

	Assert.areEqual('Test Record', result.Name, 'Should return mocked record');

	TST_Mock.clear();
}
```

---

## Anti-Patterns

Common mistakes when writing data by hand, and what to do instead.

<details>
<summary>Full anti-pattern table</summary>

| Anti-Pattern                                | Why It's Wrong                                                                 | Instead                                                                     |
|---------------------------------------------|--------------------------------------------------------------------------------|-----------------------------------------------------------------------------|
| Raw `insert`/`update`/`delete` statements   | Bypasses sharing enforcement, error handling, and framework consistency        | Use `DML_Builder.newTransaction().doInsert(records).execute()`              |
| Separate DML calls for related objects      | If the second DML fails, the first stays committed, with no way to roll it back | Use `kern.DML_Builder.newTransaction()` (Unit of Work) to commit all changes atomically |
| DML inside a loop                           | Hits governor limits on bulk operations                                        | Collect records into a list, then perform a single bulk DML call            |
| Ignoring `Database.SaveResult` errors       | Silent failures corrupt data and hide bugs                                     | Use `.allowPartial()` with `DML_Builder` and log failures via `LOG_Builder`; declare the refusals you expect with `.expectRefusal()` so they log at WARN |
| Hand-rolled retry loops around the builder  | The loop has to clear rolled-back Ids, restore what the commit consumed and watch the DML limits, and it hides the retry from the log | Use `.withRetryOnLock()`; it does all of that and writes one WARN entry per retried commit |
| Performing DML in a selector or query class | Violates separation of concerns and makes the selector untestable in isolation | Keep DML in trigger actions, service classes, or controllers                |

</details>

---

## Best Practices

### **Use Transactional DML for Complex Transactions**

When you save several related objects, register them in one `DML_Builder.newTransaction()` so a partial failure can't leave the data half-saved.

**DO:**

```apex
// Use DML_Builder for related objects to maintain transactional integrity
Account account = new Account(Name = 'Test');
Contact newContact = new Contact(LastName = 'Doe');

DML_Builder.newTransaction()
	.doInsert(account)
	.doInsert(newContact, Contact.AccountId, account)
	.execute();
```

**DON'T:**

```apex
// Don't manually manage relationships - leads to poor error handling and inconsistency
Account account = new Account(Name = 'Test');
insert account;
Contact contact = new Contact(LastName = 'Doe', AccountId = account.Id);
insert contact; // If this fails, Account remains in database - no rollback
```

### **Always Use [DML_Builder](reference/apex/DML_Builder.md) for DML**

Route every write through the framework so sharing control and error handling are applied consistently, instead of scattering raw DML statements.

**DO:**

```apex
// Use framework methods for consistent DML operations
DML_Builder.newTransaction().doInsert(account).execute();
```

**DON'T:**

```apex
// Avoid direct DML - bypasses framework's sharing and error handling capabilities
insert account; // No sharing control, no standardized error handling
```

### **Be Explicit About Sharing**

When security matters, state the sharing behaviour you want rather than relying on whatever the caller happens to use.

```apex
// Explicitly control sharing enforcement for security-sensitive operations
// In public-facing code
DML_Builder.newTransaction().doInsert(records).execute();

// In system-level code
DML_Builder.newTransaction().doInsert(records).bypassSharing().execute();
```

### **Check Permissions Before DML**

In user-facing features, check the user's permissions first so a forbidden action returns a clear message instead of an unhandled error.

```apex
// Check user permissions before attempting DML operations
FLOW_CheckObjectPermissions.DTO_Request request = new FLOW_CheckObjectPermissions.DTO_Request();
request.objectApiName = 'Account';
List<FLOW_CheckObjectPermissions.DTO_Response> perms =
	FLOW_CheckObjectPermissions.checkPermissions(new List<FLOW_CheckObjectPermissions.DTO_Request>{request});

if(perms[0].hasCreateAccess)
{
	// Proceed with DML
}
```

### **Use [TST_Builder](reference/apex/TST_Builder.md) in Tests**

Build test data with the builder instead of hand-written inserts, so your tests stay short and easy to read.

**DO:**

```apex
// Use builder pattern with type-safe field tokens and parent-child relationships
@IsTest
private static void testMethod()
{
	// Create account with related contacts using builder
	Account account = (Account)TST_Builder.of(Account.SObjectType)
		.withOverrides(new Map<SObjectField, Object>
		{
			Account.Name => 'Test Account',
			Account.Industry => 'Technology'
		})
		.withChildren(Contact.SObjectType, 3, new Map<SObjectField, Object>
		{
			Contact.LastName => 'Test Contact'
		})
		.build();

	// Test with properly structured data
	Assert.isNotNull(account.Id);
	Integer contactCount = QRY_Builder.selectFrom(Contact.SObjectType)
		.condition(Contact.AccountId).equals(account.Id)
		.toList()
		.size();
	Assert.areEqual(3, contactCount);
}
```

**Use these builder features:** type-safe overrides, parent-child relationships, record types, bulk creation and
optional field control. Each is listed with its method under "What it does for you" in [TST_Builder](#tst_builder).

**DON'T:**

```apex
// Avoid manual DML and relationship management in tests
@IsTest
private static void testMethod()
{
	Account account = new Account(Name = 'Test');
	insert account; // Manual DML - verbose, no defaults

	List<Contact> contacts = new List<Contact>();
	for(Integer i = 0; i < 3; i++)
	{
		contacts.add(new Contact(LastName = 'Test', AccountId = account.Id));
	}
	insert contacts; // Separate DML - not atomic, harder to maintain
}
```

### **Handle DML Errors Properly**

Check the results of every write so failures don't pass silently. The
[Database.SaveResult](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_database_saveresult.htm)/[Database.DeleteResult](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_database_deleteresult.htm)
objects carry the per-row errors.

```apex
// Always check and handle DML operation results
DML_Builder.TransactionResult result = DML_Builder.newTransaction()
	.doInsert(accounts)
	.allowPartial()
	.execute();

if(!result.isSuccess())
{
	for(Database.Error error : result.getErrors())
	{
		// Handle each refused row here, for example log error.getMessage()
	}
}
```

If an error stops the partial save itself, no row carries it, so `getErrors()` can be empty while `isSuccess()` is
false. Read the reason from `result.getFailureMessage()`. It returns null when the save only refused some rows.

### **Use Bulk Operations**

Save a whole list of records in one call rather than one record at a time, so a loop can't blow the limit on DML statements.

**DO:**

```apex
// Process records in bulk to avoid governor limits
List<Account> accounts = getAccountsToUpdate();
DML_Builder.newTransaction().doUpdate(accounts).execute();
```

**DON'T:**

```apex
// Don't process records individually in a loop - causes governor limit violations
for(Account account : accounts)
{
	DML_Builder.newTransaction().doUpdate(account).execute(); // GOVERNOR LIMIT VIOLATION - Too many DML statements
}
```

### **Use Batch Apex for Large Volumes**

For operations on thousands of records, run them in [batch Apex](https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_batch_interface.htm) so each chunk stays within platform limits.

```apex
// Use batch processing for large-scale operations
Database.executeBatch(new BATCH_ProcessRecords(), 200);
```

### **Use UTIL_BulkUpdates for Common Bulk Operations**

For common bulk updates, use the built-in utilities instead of writing your own query-and-loop code each time.

**DO:**

```apex
// Use utility methods for common bulk operations
// Invalidate all Contact email addresses with built-in batch processing
UTIL_BulkUpdates.invalidateEmailFields(Contact.Email, 200);
```

**DON'T:**

```apex
// Don't reinvent the wheel with custom batch classes for common operations
// Bad: Manual query + loop + single DML (no batch processing, no error handling)
List<Contact> contacts = QRY_Builder.selectFrom(Contact.SObjectType)
	.fields(new List<SObjectField>{Contact.Id, Contact.Email})
	.condition(Contact.Email).isNotNull()
	.toList();
for(Contact contact : contacts)
{
	contact.Email = contact.Email + '.invalid';
}
update contacts; // Missing batch processing, error handling, transaction control
```

### **Create Fresh Transactions**

Start a fresh `DML_Builder.newTransaction()` for each separate unit of work; each call gives you a clean transaction with nothing carried over from the last.

```apex
// Create a new transaction for each logical unit of work
DML_Builder.newTransaction()
	.doInsert(firstBatch)
	.execute();

// New transaction for separate operation
DML_Builder.newTransaction()
	.doUpdate(secondBatch)
	.execute();
```

### **Document DML Operations**

Give every DML method clear ApexDoc, so the next person knows what it does and how to call it.

```apex
/**
 * @description Creates a new account with related contacts
 *
 * @param accountName Name for the new account
 * @param contactNames List of contact last names
 *
 * @return The created Account record with Id populated
 *
 * @example
 * ```apex
 * Account account = createAccountWithContacts('Acme Corp', new List<String>{'Smith', 'Jones'});
 * ```
 */
public static Account createAccountWithContacts(String accountName, List<String> contactNames)
{
	Account newAccount = new Account(Name = accountName);
	DML_Builder builder = DML_Builder.newTransaction().doInsert(newAccount);
	for(String contactName : contactNames)
	{
		builder.doInsert(new Contact(LastName = contactName), Contact.AccountId, newAccount);
	}
	builder.execute();
	return newAccount;
}

```

### **Use All-or-Nothing Appropriately**

Decide whether everything must succeed together (all-or-nothing) or whether the good rows can commit while bad ones are reported (partial). Pick based on what the work needs.

```apex
// Choose between atomic and partial commits based on business requirements
// Atomic - all must succeed (default)
DML_Builder.newTransaction().doInsert(records).execute();

// Partial - allow some to succeed
DML_Builder.newTransaction().doInsert(records).allowPartial().execute();
```

### **Set Sharing per Operation**

Set sharing per operation rather than flipping a shared, global setting, so one write can't accidentally change the behaviour of another.

```apex
// Prefer operation-level sharing control
DML_Builder.newTransaction()
	.doInsert(records)
	.execute();
```

### **Use Purge Utilities for Cleanup**

For data cleanup, use the built-in purge utilities instead of hand-written delete logic.

```apex
// Use purge utilities for data cleanup operations
// Clean up test data in tests
@TestSetup
static void setupTestData()
{
	// Create test data
}

@IsTest
static void testCleanup()
{
	Test.startTest();
	UTIL_PurgeRecords.deleteAllRecords(Account.SObjectType);
	Test.stopTest();
}
```

---

## Related Documentation

- [Selectors - Guide](Selectors%20-%20Guide.md) - Query patterns paired with DML operations
- [Triggers - Guide](Triggers%20-%20Guide.md) - Trigger actions that perform DML via `DML_Builder`
- [Web Services - Guide](Web%20Services%20-%20Guide.md) - API classes with DML operations
- [Logging - Guide](Logging%20-%20Guide.md) - DML error logging via `LOG_Builder.errorDMLOperationResults()`
- [Validation - Guide](Validation%20-%20Guide.md) - Validation before DML operations
