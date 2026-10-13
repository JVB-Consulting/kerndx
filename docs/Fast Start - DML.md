---
navOrder: 14
---

# Fast Start - DML

**Framework:** KernDX | **Total time:** ~30 minutes

**What this is:** A safer way to write records to Salesforce in Apex. Instead of plain `insert`, `update`, and `delete`, you build up the changes you want and run them as one transaction. **Why it matters:** That single path gives you automatic error logging, parent-to-child relationships wired up for you, partial-success handling, and control over security and sharing, all without repeating boilerplate. **Who should follow it:** any developer who writes Apex that saves data. **When to use it:** any time your code creates, changes, or removes records. A bare `insert` of a single record with no related children is fine on its own; the benefit of the builder shows once you have parent-child links, partial-success handling, or want consistent error logging across your codebase.

> **Namespaces in code samples:** `kern.` on a class and `kern__` on an object, field, or metadata type mark the managed package's namespace.
> On the managed package, framework references need those prefixes even where a sample omits them; repackaged under your own namespace, replace `kern`/`kern__`
> with your prefix; on an unmanaged deploy, drop them. See [How to read the code samples](Installation.md#how-to-read-the-code-samples).

**What you'll build:** A service class that creates an Account with related Contacts and an Opportunity
in a single atomic (all-or-nothing) transaction, with the parent-child foreign keys filled in automatically.

**Success looks like:** You call your service, verify the Account and its children were created with correct
relationships, and your test class has 100% coverage.

**In one line:** `kern.DML_Builder.newTransaction().doInsert(newAccount).doInsert(newContact, Contact.AccountId, newAccount).execute();`
(parent-child foreign keys are resolved automatically).

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
    - [Insert a Record](#insert-a-record)
    - [Update a Record](#update-a-record)
    - [Parent-Child Insert](#parent-child-insert)
3. [Tier 2: Build Your Own (~20 minutes)](#tier-2-build-your-own-20-minutes)
    - [Step 1: Create the Service Class](#step-1-create-the-service-class)
    - [Step 2: Execute](#step-2-execute)
    - [Step 3: Write Tests](#step-3-write-tests)
4. [Tier 3: Production Patterns (~5 minutes)](#tier-3-production-patterns-5-minutes)
    - [All DML Operations](#all-dml-operations)
    - [TransactionResult](#transactionresult)
    - [Partial Success](#partial-success)
    - [Security, Sharing, Suppression, and Async](#security-sharing-suppression-and-async)
    - [Clean up](#clean-up)
5. [Common Issues](#common-issues)
    - [Parent-Child Insert](#parent-child-insert-1)
    - [Step 1: Create the Service Class](#step-1-create-the-service-class-1)
    - [Step 2: Execute](#step-2-execute-1)
    - [Step 3: Write Tests](#step-3-write-tests-1)
    - [All DML Operations](#all-dml-operations-1)
    - [Partial Success](#partial-success-1)
    - [Clean up](#clean-up-1)
6. [What You Now Know](#what-you-now-know)
7. [Next Steps](#next-steps)

</details>

---

## Tier 1: See It Work (~2 minutes)

See the builder work straight away. You can call [`DML_Builder`](reference/apex/DML_Builder.md) directly from anonymous Apex, with no custom classes to create first.

### Insert a Record

**In Salesforce**, open the Developer Console (the gear icon, then Developer Console), then Debug, then Open Execute
Anonymous Window, and run:

```apex
Account account = new Account(Name = 'Quick Test', Phone = '555-0100');

kern.DML_Builder.TransactionResult result = kern.DML_Builder.newTransaction()
	.doInsert(account)
	.execute();

System.debug('Success: ' + result.isSuccess());
System.debug('Account Id: ' + account.Id);
System.debug('Inserted IDs: ' + result.getInsertedIds());
```

You should see these lines in the log, with your record's Id in place of `001...`:

```text
Success: true
Account Id: 001...
Inserted IDs: (001...)
```

### Update a Record

**In Salesforce**, in the same Execute Anonymous window, run:

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

You should see this line in the log:

```text
Updated Industry: Technology
```

### Parent-Child Insert

Insert an Account and a Contact in one transaction. The framework fills in the Contact's `AccountId` for you.

**In Salesforce**, in the same Execute Anonymous window, run:

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

You should see these lines in the log, with the same Id on both:

```text
Account Id: 001...
Contact AccountId: 001...
```

The Contact's `AccountId` matches the Account's `Id`, set automatically by the framework.

> **Naming tip:** Don't name a variable `contact` (lowercase) in anonymous Apex when using `Contact.AccountId`.
> The variable shadows the SObject type, so `Contact.AccountId` resolves as a field value (Id) instead of
> a field token (SObjectField). Use `newContact`, `result`, or another name. The same applies to `account` and `Account`.

Something went wrong? See [Common Issues, Parent-Child Insert](#parent-child-insert-1).

> **When to move to Tier 2:** When you need to encapsulate DML operations in a reusable service class
> with proper test coverage.

---

## Tier 2: Build Your Own (~20 minutes)

> **No local project?** You can create classes directly in the Developer Console (Gear Icon > Developer
> Console > File > New > Apex Class) and run tests from there too (Test > New Run). Paste the code, save,
> and skip the terminal commands.

Build an Account onboarding service that creates an Account with related Contacts and an Opportunity
in a single atomic transaction.

### Step 1: Create the Service Class

The service is one class with one method that saves the Account and its related records together. You create an
empty class with one command, paste the code into it, then send it to your org.

**1. In the terminal**, from your project's top folder, create the empty class:

```shell
sf apex generate class --name SVC_AccountOnboarding --output-dir force-app/main/default/classes
```

You should see two files created in `force-app/main/default/classes`: `SVC_AccountOnboarding.cls` and its companion
of the same name ending in `.cls-meta.xml`.

The second file tells Salesforce which API version the class uses. You never edit it, but a deploy fails without it.

**2. In your editor**, open this file, delete what is there, paste the code below in, and save. Paste it exactly as
it is: keep the class name.

```text
force-app/main/default/classes/SVC_AccountOnboarding.cls
```

> **Why `public`?** Unlike triggers and APIs, service classes are called directly by your own code, so
> the framework never has to look them up by name. That means `public` is enough; `global` is not required.

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
		Account newAccount = new Account(Name = accountName, Industry = 'Technology');

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
> instead of a token. Use `newAccount`, `newContact`, and so on.

**3. In the terminal**, send the class to your org:

```shell
sf project deploy start -o YourOrgAlias -m "ApexClass:SVC_AccountOnboarding"
```

You should see `Status: Succeeded`, with `SVC_AccountOnboarding` listed as created.

Something went wrong? See [Common Issues, Step 1](#step-1-create-the-service-class-1).

### Step 2: Execute

Try the service from anonymous Apex. Paste both snippets in one Execute Anonymous window, because the second depends
on `result` from the first.

**In Salesforce**, open the Developer Console (the gear icon, then Developer Console), then Debug, then Open Execute
Anonymous Window, and paste the first snippet:

```apex
List<String> contactLastNames = new List<String>{ 'Smith', 'Jones' };

kern.DML_Builder.TransactionResult result =
	new SVC_AccountOnboarding().createAccount('Acme Corp', contactLastNames, 'Acme Deal');

System.debug('Success: ' + result.isSuccess());
System.debug('Inserted IDs: ' + result.getInsertedIds());
System.debug('Success count: ' + result.getSuccessCount());
```

**In Salesforce**, in the same window and below the first snippet, paste the second, which checks the relationships
in the org, then run both:

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

You should see these lines in the log, with your own record Ids in the second line (the Account's first, then the
Opportunity's, then the two Contacts'):

```text
Success: true
Inserted IDs: (001..., 006..., 003..., 003...)
Success count: 4
```

followed by the counts of related records:

```text
Contacts: 2
Opportunities: 1
```

**Why it works, step by step:**

- **`DML_Builder.newTransaction()`**: creates a new transaction builder.
- **`.doInsert(record)`**: registers a record for insertion.
- **`.doInsert(child, field, parent)`**: registers a child with a parent relationship. Register the parent
  with its own `.doInsert()` too, before or after the child: the framework inserts parents before their children
  whatever order you register them in. After `execute()`, the child's lookup field is auto-populated with the parent's ID.
- **`.execute()`**: commits all operations atomically, parent records before their children. After each parent inserts,
  the framework populates its children's lookup fields. If any operation fails, all are rolled back.
- **`TransactionResult`**: contains `isSuccess()`, `getInsertedIds()`, `getErrors()`, `getSuccessCount()`,
  `getFailureCount()`.

Something went wrong? See [Common Issues, Step 2](#step-2-execute-1).

### Step 3: Write Tests

The test class checks the service three ways: with two Contacts, with one, and with none. You create the empty class
with one command, paste the code into it, send it to your org, then run it.

**1. In the terminal**, from your project's top folder, create the empty test class:

```shell
sf apex generate class --name SVC_AccountOnboarding_TEST --output-dir force-app/main/default/classes
```

You should see two files created in `force-app/main/default/classes`: `SVC_AccountOnboarding_TEST.cls` and its
companion of the same name ending in `.cls-meta.xml`.

**2. In your editor**, open this file, delete what is there, paste the code below in exactly as it is, and save:

```text
force-app/main/default/classes/SVC_AccountOnboarding_TEST.cls
```

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
@IsTest(isParallel=true)
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

**3. In the terminal**, send the test class to your org:

```shell
sf project deploy start -o YourOrgAlias -m "ApexClass:SVC_AccountOnboarding_TEST"
```

You should see `Status: Succeeded`, with `SVC_AccountOnboarding_TEST` listed as created.

**4. In the terminal**, run the test:

```shell
sf apex run test -o YourOrgAlias -t SVC_AccountOnboarding_TEST --code-coverage --synchronous --result-format human
```

You should see 3 tests passing and 100% coverage on `SVC_AccountOnboarding`: all three tests show `Pass`, the
summary line `Outcome` reads `Passed`, and the coverage table shows `SVC_AccountOnboarding` at `100%`.

> **About the annotations:** `@IsTest(isParallel=true)` enables parallel test execution (faster runs).
> `SeeAllData` defaults to `false`, so we omit it. `@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')`
> turns off a code-quality warning about `System.runAs()`, which is fine for quick starts. In production tests,
> consider adding `System.runAs()` to verify profile and permission set access.

Something went wrong? See [Common Issues, Step 3](#step-3-write-tests-1).

---

## Tier 3: Production Patterns (~5 minutes)

### All DML Operations

`DML_Builder` supports every DML operation. See the [DML Guide](DML%20-%20Guide.md) for the full API
reference including upsert by external ID, undelete, and bulk patterns.

**In Salesforce**, run this in an Execute Anonymous window to see insert, update, and delete in a single transaction:

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

You should see these lines in the log, with your record's Id in place of `001...`:

```text
Insert success: true
Account Id: 001...
Update success: true
Delete success: true
```

Something went wrong? See [Common Issues, All DML Operations](#all-dml-operations-1).

### TransactionResult

Inspect the result after `execute()`.

**In Salesforce**, in an Execute Anonymous window, run:

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

You should see these lines in the log, with your record's Id in place of `001...`:

```text
Overall success: false
Inserted IDs: (001...)
Success count: 1
Failure count: 1
Error: Required fields are missing: [Name]
```

### Partial Success

By default, DML is all-or-nothing: if one record fails, all are rolled back. Chain `.allowPartial()`
to save the valid records and log the failures instead.

**In Salesforce**, in an Execute Anonymous window, run:

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

You should see these lines in the log, with your records' Ids in place of `001...`:

```text
Succeeded: 2
Failed: 1
Inserted IDs: (001..., 001...)
```

Failed records are automatically logged via `LOG_Builder`. To see them, open **App Launcher > Kern > Log Entries**.

Something went wrong? See [Common Issues, Partial Success](#partial-success-1).

### Security, Sharing, Suppression, and Async

These are situational patterns. See the [DML Guide](DML%20-%20Guide.md) for detailed examples.

**Default access mode.** By default, `kern.DML_Builder.newTransaction()` runs in `AccessLevel.USER_MODE`: it saves data with the current user's read/write permissions and record sharing
enforced, rather than skipping those checks (the alternative, `SYSTEM_MODE`). In practice that means CRUD (object create/read/update/delete permissions) and FLS (field-level security)
are both checked against the running user, and sharing rules are honoured. This safe default is controlled by the `UserModeDml_Enabled` feature flag, which ships set to `true`.
You can override it on a single call with `.withSystemMode()` (which skips the CRUD and FLS checks), or be explicit and pass `.withUserMode()` even when the flag is on.
`.bypassSharing()` affects sharing only: it does NOT turn off the CRUD and FLS enforcement that USER_MODE provides.
See [Security Guide: Safe by Default](Security%20-%20Guide.md#safe-by-default).

**In your editor**, in your own Apex, where `records` is the list of records you are saving:

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

To keep the log but soften a refusal you expect, declare it: in partial-success mode the declared
refusal is logged at WARN and everything else at ERROR.

**In your editor**, in your own Apex:

```apex
// A duplicate here is expected, so it lands in the log at WARN
kern.DML_Builder.newTransaction().doInsert(records).allowPartial().expectRefusal(StatusCode.DUPLICATE_VALUE).execute();
```

Four of the choices above travel with a background job: the access mode (`.withUserMode()` /
`.withSystemMode()`), partial success (`.allowPartial()`), the sharing bypass (`.bypassSharing()`),
and the expected refusals you declared (`.expectRefusal()`). If you do not call `.bypassSharing()`,
the background job enforces record sharing. `.suppressExceptions()` and `.suppressLogging()` do not
travel: they shape the result the synchronous call hands back, and a background job has no caller
waiting for one, so its failures are always logged.

### Clean up

If you built this example only to try the framework, run this command when you have finished the guide. The records
the Apex above inserted stay: the `Quick Test`, `Parent Co`, `Acme Corp`, `Valid Corp`, `Good Account 1` and
`Good Account 2` Accounts, with the Contacts and the Opportunity linked to them; delete them in the app, or leave them.

**In the terminal**, delete the service and its test class:

```shell
sf project delete source -o YourOrgAlias -m "ApexClass:SVC_AccountOnboarding_TEST" -m "ApexClass:SVC_AccountOnboarding" --no-prompt
```

You should see `Status: Succeeded`, then a `Deleted Source` table listing the two classes.

The command deletes the files from your project too.

Something went wrong? See [Common Issues](#clean-up-1).

---

## Common Issues

Trouble with your computer rather than this guide (`sf` is not recognised, scripts are disabled, you are not logged
in, the wrong folder)? Those are answered once, in
[Set Up Your Computer](Set%20Up%20Your%20Computer.md#if-something-went-wrong).

### Parent-Child Insert

#### `Contact AccountId: null`

The Contact was registered with `.doInsert(newContact)` alone, so the framework was never told which field links it
to which parent. Register it with the lookup field and the parent: `.doInsert(child, Contact.AccountId, parent)`.

#### `Method does not exist or incorrect signature: void doInsert(Contact, Id, Account) from the type kern.DML_Builder`

The code stops before it runs. A variable named `contact` shadows the `Contact` type (Apex ignores case), so
`Contact.AccountId` reads that variable's field value, an Id, instead of the field token. Rename the variable, for
example to `newContact`, as the naming tip above says.

### Step 1: Create the Service Class

#### The deploy says there is nothing to deploy

The deploy stops with `No source-backed components present in the package.` The command ran inside another project's
folder, so the CLI looked for the class there and found nothing. Open the terminal in your own project's top folder,
the one that holds `sfdx-project.json`, and run the command again.

### Step 2: Execute

#### `Variable does not exist: result`

The code stops before it runs. The second snippet ran on its own, and it uses `result` from the first. Paste both
snippets into one Execute Anonymous window and run them together.

### Step 3: Write Tests

#### The deploy fails

The test class's deploy fails for the same reasons as the service's; see the entries under
[Step 1](#step-1-create-the-service-class-1).

### All DML Operations

#### `cannot specify Id in an insert call`

The code called `execute()` a second time on the same transaction. That runs the registered operations again, and the
records it inserted the first time now have Ids, so the insert is refused with a message that starts
`System.DmlException: Insert failed.` Register all the operations, then execute once; for more work afterwards, start
a new transaction with `kern.DML_Builder.newTransaction()`, as the code above does.

### Partial Success

#### `System.DmlException: Insert failed.`

The message goes on to name the failing row and the reason, for example `Required fields are missing: [Name]`. A
transaction is all-or-nothing by default: one record failed, so nothing was saved and the error
stopped your code. Chain `.allowPartial()` to save the valid records and read the failures from the result, or
`.suppressExceptions()` to log the failure instead of throwing it.

If the reason is `cannot specify Id in an insert call`, see [All DML Operations](#all-dml-operations-1).

### Clean up

#### `No ApexClass named: SVC_AccountOnboarding found`

The command shows `Status: Failed` and a `Component Failures` table with this line, and the same for
`SVC_AccountOnboarding_TEST`. The org no longer holds the classes: the clean-up already ran, or they were deleted
another way. There is nothing left to delete.

Still stuck? [Tell us](https://github.com/JVB-Consulting/kerndx/issues/new?template=bug_report.md&title=%5Bdocs%5D%20DML) which step and what you saw.

## What You Now Know

After completing this guide, you understand the **DML builder pattern** in KernDX:

| Concept                               | What It Does                                                                        |
|---------------------------------------|-------------------------------------------------------------------------------------|
| **`DML_Builder`**                     | One builder for all DML operations; it replaces direct `insert`/`update`/`delete`   |
| **`.doInsert(child, field, parent)`** | Auto-populates foreign keys after parent insert                                     |
| **`.execute()`**                      | Commits all operations atomically: parents before children                          |
| **`TransactionResult`**               | Tells you what happened after a save: `isSuccess()`, `getInsertedIds()`, `getErrors()`, counts            |

**Key patterns:**

- **Always use `DML_Builder`**, not direct DML: the framework provides automatic error logging.
- **Link each child to its parent**: use the 3-argument `.doInsert(child, field, parent)` overload, and register the
  parent with `.doInsert()` too; the framework inserts the parent first.
- **One `execute()` per transaction**: register all operations first, then execute once.
- **`public` visibility**: service classes using DML_Builder don't need `global`.
- **`TransactionResult`**: always check `isSuccess()` when using `.allowPartial()` or `.suppressExceptions()`.

---

## Next Steps

- [Selectors (query patterns)](Fast%20Start%20-%20Selectors.md)
- [Trigger Actions (DML in after context)](Fast%20Start%20-%20Trigger%20Actions.md)
- [Test Data Patterns](Fast%20Start%20-%20Test%20Data.md)
- [Async Processing (background DML and chains)](Fast%20Start%20-%20Async%20Processing.md)
- [Code Scanning (catch DML anti-patterns)](Fast%20Start%20-%20Code%20Scanning.md)
- [Complete DML Guide](DML%20-%20Guide.md)
- [DML_Builder Reference](reference/apex/DML_Builder.md)

> **Drift guard:** `FastStart_DML_DEMO` + `FastStart_DML_DEMO_TEST` in `release-testing/subscriber/classes/`
> are the companion classes for this guide. Deploy and run `FastStart_DML_DEMO_TEST` against a subscriber
> scratch org to confirm the parent-child auto-link and partial-success patterns work end-to-end.
