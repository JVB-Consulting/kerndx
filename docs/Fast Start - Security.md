---
navOrder: 16
---

# Fast Start - Security

**Framework:** KernDX | **Total time:** ~30 minutes

**What this is:** A way to have every database read and write automatically respect the running user's
permissions, so you never hand-write a security check. **Why it matters:** Forgetting one of those checks
is how data quietly leaks to someone who should not see it. KernDX makes the safe behaviour the default, so
the gap can't happen by accident. **Who should follow this:** developers writing Apex that touches data, plus
the architects and tech leads who set security standards for a team. **When to reach for it:** any time your
code queries or saves records, which is nearly always.

In plain terms: object create/read/update/delete permissions (CRUD) and field-level security (FLS) are
enforced for you on every query and every write, with no manual `Security.stripInaccessible()` plumbing and
no `WITH USER_MODE` clauses to remember.

**Before you start:**

- [ ] KernDX package installed in your org
- [ ] Org configured post-install. Verify with the **Kern** app's Health Check (see [Installation guide](Installation.md#post-install-configuration))
- [ ] CLI authenticated (`sf org open -o YourOrgAlias` to verify), or just use the Developer Console
  (Gear Icon > Developer Console) for all Apex work
- [ ] Working in a sandbox or scratch org (not production)

> **Subscriber orgs:** Use `kern.ClassName` when calling framework classes (e.g., `kern.QRY_Builder`,
> `kern.DML_Builder`). Your own classes don't need a namespace prefix. The framework's Type Resolver (how the
> framework finds the Apex classes in your namespace) handles resolution automatically.

**What you'll build:** A service class that reads and writes records through the framework. It gets CRUD and
FLS enforced against the running user by default, and it strips fields the user can't see out of untrusted
query results, all without writing a single `Security.stripInaccessible()` call.

**Success looks like:** Your queries and DML respect the running user's permissions automatically, a
lower-permission user can't read or write fields they lack access to, and your test class has 100% coverage.

**In one line:** Every `kern.QRY_Builder` query and `kern.DML_Builder` transaction runs in
`AccessLevel.USER_MODE` by default, so CRUD, field-level security, and sharing are enforced against the running
user with no extra code.

---

## Table of Contents

<details>
<summary>Expand</summary>

1. [Tier 1: See It Work (~2 minutes)](#tier-1-see-it-work-2-minutes)
    - [Secure Query by Default](#secure-query-by-default)
    - [Secure DML by Default](#secure-dml-by-default)
    - [Strip Inaccessible Fields](#strip-inaccessible-fields)
2. [Tier 2: Build Your Own (~20 minutes)](#tier-2-build-your-own-20-minutes)
    - [Step 1: Create the Service Class](#step-1-create-the-service-class)
    - [Step 2: Execute](#step-2-execute)
    - [Step 3: Write Tests](#step-3-write-tests)
3. [Tier 3: Production Patterns (~5 minutes)](#tier-3-production-patterns-5-minutes)
    - [Query Security Methods](#query-security-methods)
    - [DML Security Methods](#dml-security-methods)
    - [When to Opt Out of USER_MODE](#when-to-opt-out-of-user_mode)
    - [The Org-Wide Kill Switch](#the-org-wide-kill-switch)
    - [Field Encryption](#field-encryption)
4. [Common Issues](#common-issues)
5. [What You Now Know](#what-you-now-know)
6. [Next Steps](#next-steps)

</details>

---

## Tier 1: See It Work (~2 minutes)

KernDX queries and DML are secure by default. You don't add a security call: you get one for free on every
`kern.QRY_Builder` and `kern.DML_Builder` call. The sections below show what that means in practice.

### Secure Query by Default

Open **Developer Console > Debug > Open Execute Anonymous Window** and run:

```apex
// No security method chained — this still runs in USER_MODE.
// CRUD, FLS, and sharing are enforced against YOU, the running user.
List<Account> accounts = kern.QRY_Builder.selectFrom(Account.SObjectType)
		.fields(new List<SObjectField> {Account.Name, Account.AnnualRevenue})
		.withLimit(5)
		.toList();

System.debug('Rows returned: ' + accounts.size());
```

**Expected output** (your data will vary):

```text
Rows returned: 5
```

As a system administrator you see every field and every row, so this looks unremarkable. The difference shows
up for a lower-permission user: if that user lacks read access on `AnnualRevenue`, the query throws a
`System.QueryException` instead of silently leaking the value. That is USER_MODE doing its job. USER_MODE means
the query runs with the current user's read and write permissions and record sharing enforced; SYSTEM_MODE
skips all of those checks.

> **Want to prove it?** USER_MODE and SYSTEM_MODE behave identically for an admin (you hold every
> permission). The gap only appears when running as a lower-permission user, which is exactly what the
> `System.runAs()` test in [Tier 2](#step-3-write-tests) demonstrates.

### Secure DML by Default

Writes are secured the same way. A plain `kern.DML_Builder` transaction runs in USER_MODE:

```apex
Account account = new Account(Name = 'Secure Test', Phone = '555-0100');

// No .withUserMode() needed — USER_MODE is the default. Insert is checked
// against the running user's create permission on Account and its fields.
kern.DML_Builder.TransactionResult result = kern.DML_Builder.newTransaction()
		.doInsert(account)
		.execute();

System.debug('Insert success: ' + result.isSuccess());
System.debug('Account Id: ' + account.Id);
```

**Expected output** (ID will vary):

```text
Insert success: true
Account Id: 001...
```

If the running user lacked create access on `Account`, or write access on a field you set, the insert would
fail with a security error rather than writing data the user was never allowed to touch.

### Strip Inaccessible Fields

USER_MODE throws when a query touches a field the user can't read. Sometimes you'd rather **drop** the
unreadable fields and keep going, for example when you query a generous field list but only need whatever the
user is actually allowed to see. Chain `.stripInaccessible()`:

```apex
// Returns rows with inaccessible fields removed (set to null) instead of throwing.
List<Account> stripped = kern.QRY_Builder.selectFrom(Account.SObjectType)
		.fields(new List<SObjectField> {Account.Name, Account.AnnualRevenue})
		.stripInaccessible()
		.withLimit(5)
		.toList();

System.debug('Rows returned: ' + stripped.size());
```

Under the hood the framework runs `Security.stripInaccessible(AccessType.READABLE, records)` on the result set
after the query returns, so any field the running user can't read is removed from the records you get back.

> **When to move to Tier 2:** When you want to encapsulate secure reads and writes in a reusable service class
> and verify the enforcement with a `System.runAs()` test.

---

## Tier 2: Build Your Own (~20 minutes)

> **No local project?** You can create classes directly in the Developer Console (Gear Icon > Developer
> Console > File > New > Apex Class) and run tests from there too (Test > New Run). Paste the code, save,
> and skip the `sf project deploy start` and `sf apex run test` commands.

Build a small contact-directory service that reads Contacts through the framework and creates new ones. Both
the read and the write inherit USER_MODE, so the service automatically respects whatever the calling user is
allowed to see and do.

### Step 1: Create the Service Class

Create a new file named `SVC_ContactDirectory.cls`. Copy the following code exactly as is: do not modify the
class name or `kern.*` namespace references.

> **Why `public`?** Unlike triggers and APIs, service classes are called directly by your code. The
> framework doesn't need to resolve them by name, so `global` is not required.

> **Why `with sharing`?** Declaring the service `with sharing` makes the class's record-visibility intent
> explicit. CRUD and FLS already come from USER_MODE, and `with sharing` documents that this class enforces
> record-level sharing too.

```apex
/**
 * @description Contact directory service. Reads and creates Contacts through the framework,
 * inheriting USER_MODE so CRUD and field-level security are enforced against the running user.
 *
 * @see SVC_ContactDirectory_TEST
 *
 * @author your.name@company.com
 *
 * @group Services
 *
 * @date February 2026
 */
public with sharing class SVC_ContactDirectory
{
	/**
	 * @description Returns Contacts whose last name matches, with any fields the running user
	 * cannot read stripped from the results rather than throwing.
	 *
	 * @param lastName The last name to filter by.
	 *
	 * @return Contacts the running user is allowed to see, with inaccessible fields removed.
	 */
	public List<Contact> findByLastName(String lastName)
	{
		return kern.QRY_Builder.selectFrom(Contact.SObjectType)
				.fields(new List<SObjectField> {Contact.FirstName, Contact.LastName, Contact.Email})
				.condition(Contact.LastName).equals(lastName)
				.stripInaccessible()
				.toList();
	}

	/**
	 * @description Creates a Contact. Runs in USER_MODE by default, so the create is checked
	 * against the running user's create access on Contact and on each field set.
	 *
	 * @param firstName The Contact's first name.
	 * @param lastName The Contact's last name.
	 *
	 * @return The result of the insert transaction.
	 */
	public kern.DML_Builder.TransactionResult createContact(String firstName, String lastName)
	{
		Contact newContact = new Contact(FirstName = firstName, LastName = lastName);

		return kern.DML_Builder.newTransaction()
				.doInsert(newContact)
				.execute();
	}
}
```

**Deploy:**

```bash
sf project deploy start -o YourOrgAlias -m "ApexClass:SVC_ContactDirectory"
```

### Step 2: Execute

Test from anonymous Apex (paste both snippets in one Execute Anonymous window, since the second depends on the
first):

```apex
kern.DML_Builder.TransactionResult result =
		new SVC_ContactDirectory().createContact('Jane', 'Directory');

System.debug('Create success: ' + result.isSuccess());

List<Contact> found = new SVC_ContactDirectory().findByLastName('Directory');
System.debug('Found: ' + found.size());

for(Contact each : found)
{
	System.debug(each.FirstName + ' ' + each.LastName);
}
```

**Expected output:**

```text
Create success: true
Found: 1
Jane Directory
```

**Why it works, the key patterns:**

- **`kern.QRY_Builder.selectFrom(...)`**: the query runs in USER_MODE by default, so CRUD, FLS, and sharing are
  enforced against the running user with no extra method call.
- **`.stripInaccessible()`**: removes fields the user can't read from the returned rows (post-query), so the
  read degrades gracefully instead of throwing on an inaccessible field.
- **`kern.DML_Builder.newTransaction()...execute()`**: the insert runs in USER_MODE by default, so the create
  is checked against the user's object and field permissions.
- **No security boilerplate**: you never wrote `WITH USER_MODE`, `Security.stripInaccessible(...)`, or a
  manual `Schema.sObjectType.Contact.isCreateable()` check. The framework supplied all of it.

### Step 3: Write Tests

Create a new file named `SVC_ContactDirectory_TEST.cls`. Copy the following code exactly as is. The third test
uses `System.runAs()` with a minimum-access user to prove the enforcement is real, and not just the admin's
all-permissions view.

```apex
/**
 * @description Unit tests for SVC_ContactDirectory.
 *
 * @see SVC_ContactDirectory
 *
 * @author your.name@company.com
 *
 * @group Services
 *
 * @date February 2026
 */
@IsTest(IsParallel=false)
private class SVC_ContactDirectory_TEST
{
	/** @description Tests that createContact inserts a Contact in USER_MODE. */
	@IsTest
	private static void shouldCreateContact()
	{
		kern.DML_Builder.TransactionResult result =
				new SVC_ContactDirectory().createContact('Test', 'Person');

		Assert.isTrue(result.isSuccess(), 'Create should succeed for an admin running the test');
		Assert.areEqual(1, result.getSuccessCount(), 'Should insert exactly one Contact');
	}

	/** @description Tests that findByLastName returns matching Contacts. */
	@IsTest
	private static void shouldFindContactsByLastName()
	{
		kern.TST_Builder.of(Contact.SObjectType)
				.withOverride(Contact.FirstName, 'Find')
				.withOverride(Contact.LastName, 'Target')
				.build();

		List<Contact> found = new SVC_ContactDirectory().findByLastName('Target');

		Assert.areEqual(1, found.size(), 'Should return the matching Contact');
		Assert.areEqual('Find', found[0].FirstName, 'Should return the correct Contact');
	}

	/**
	 * @description Proves USER_MODE enforces the *running user's* permissions. A minimum-access user
	 * with no Contact access is rejected by the secure read — the admin running the test would have
	 * sailed straight through, which is exactly the trap USER_MODE closes.
	 */
	@IsTest
	private static void shouldEnforceRunningUserPermissionsOnRead()
	{
		kern.TST_Builder.of(Contact.SObjectType)
				.withOverride(Contact.FirstName, 'Scoped')
				.withOverride(Contact.LastName, 'Reader')
				.build();

		User minimumAccessUser = buildMinimumAccessUser();
		Boolean rejected = false;

		System.runAs(minimumAccessUser)
		{
			try
			{
				new SVC_ContactDirectory().findByLastName('Reader');
			}
			catch(Exception error)
			{
				rejected = true;
			}
		}

		Assert.isTrue(rejected,
				'USER_MODE must reject a user without Contact access — proving the framework enforces '
				+ 'the running user\'s permissions, not the admin\'s');
	}

	/**
	 * @description Builds a minimum-access user for running-user enforcement tests.
	 *
	 * @return A User assigned the Minimum Access profile.
	 */
	private static User buildMinimumAccessUser()
	{
		Profile minimumAccess = (Profile)kern.QRY_Builder.selectFrom(Profile.SObjectType)
				.fields(new List<SObjectField> {Profile.Id})
				.condition(Profile.Name).equals('Minimum Access - Salesforce')
				.getFirst();

		return (User)kern.TST_Builder.of(User.SObjectType)
				.withOverride(User.ProfileId, minimumAccess.Id)
				.withOverride(User.LastName, 'Scoped')
				.withOverride(User.Alias, 'scoped')
				.withOverride(User.Email, 'scoped.reader@example.com')
				.withOverride(User.Username, 'scoped.reader.' + DateTime.now().getTime() + '@example.com')
				.withOverride(User.EmailEncodingKey, 'UTF-8')
				.withOverride(User.LanguageLocaleKey, 'en_US')
				.withOverride(User.LocaleSidKey, 'en_US')
				.withOverride(User.TimeZoneSidKey, 'America/Los_Angeles')
				.build();
	}
}
```

**Deploy and run:**

```bash
sf project deploy start -o YourOrgAlias -m "ApexClass:SVC_ContactDirectory_TEST"
sf apex run test -o YourOrgAlias -t SVC_ContactDirectory_TEST --code-coverage --synchronous --result-format human
```

**Expected:** 3 tests passing, 100% coverage on `SVC_ContactDirectory`.

> **About the annotations:** This class uses `@IsTest(IsParallel=false)` because `buildMinimumAccessUser()`
> inserts a `User`, and Salesforce blocks DML on setup objects like `User` inside *parallel* test runs. Most
> test classes should prefer `@IsTest(IsParallel=true)` for faster runs. Reach for `IsParallel=false` only
> when a test does setup-object DML, as this one does. `SeeAllData` defaults to `false`, so we omit it. The
> `System.runAs()` block in the third test is the right habit for security code: it verifies the framework
> enforces the *running user's* permissions, which is the entire point of USER_MODE. (The
> `Minimum Access - Salesforce` profile must exist in your org; it ships with every org by default.)

---

## Tier 3: Production Patterns (~5 minutes)

### Query Security Methods

`kern.QRY_Builder` gives you independent security options you can combine. Run these from Execute Anonymous to
compare:

```apex
// Default — USER_MODE (CRUD + FLS + sharing enforced against the running user)
List<Account> defaultQuery = kern.QRY_Builder.selectFrom(Account.SObjectType)
		.fields(new List<SObjectField> {Account.Name})
		.withLimit(5)
		.toList();

// Explicit USER_MODE — redundant under the default, useful as belt-and-braces
// (it overrides the org-wide kill switch even if that has been flipped off)
List<Account> userMode = kern.QRY_Builder.selectFrom(Account.SObjectType)
		.fields(new List<SObjectField> {Account.Name})
		.withUserMode()
		.withLimit(5)
		.toList();

// Strip inaccessible fields from the results instead of throwing
List<Account> stripped = kern.QRY_Builder.selectFrom(Account.SObjectType)
		.fields(new List<SObjectField> {Account.Name, Account.AnnualRevenue})
		.stripInaccessible()
		.withLimit(5)
		.toList();
```

The full menu of query security methods:

| Method                 | Effect                                                                           | When to Use                                                      |
|------------------------|----------------------------------------------------------------------------------|------------------------------------------------------------------|
| *(none, the default)*  | USER_MODE: CRUD, FLS, and sharing enforced against the running user              | Every query your users reach                                     |
| `.withUserMode()`      | Forces USER_MODE even if the org-wide kill switch has been flipped off           | Belt-and-braces enforcement on a critical user-facing read       |
| `.stripInaccessible()` | Removes fields the user can't read from results (post-query) instead of throwing | When you'd rather drop unreadable fields than fail the query     |
| `.withSystemMode()`    | Forces SYSTEM_MODE: bypasses CRUD/FLS for this query only                        | Framework-internal reads (configuration, framework-owned tables) |
| `.withSharing()`       | Uses a `with sharing` proxy (only has effect in SYSTEM_MODE)                     | Enforce sharing on a SYSTEM_MODE query                           |
| `.bypassSharing()`     | Uses a `without sharing` proxy (only has effect in SYSTEM_MODE)                  | Bypass sharing on a SYSTEM_MODE query (use with caution)         |
| `.withoutSecurity()`   | Clears all security selections: SYSTEM_MODE plus inherited sharing               | System-level queries that must opt out of the secure default     |

> **`withUserMode()` wins over the sharing proxy.** Under USER_MODE, sharing is enforced at the database level
> regardless of `.withSharing()` or `.bypassSharing()`. Those two proxy methods only take effect in SYSTEM_MODE.

### DML Security Methods

`kern.DML_Builder` follows the same secure-by-default rule. Here are the access-mode and sharing controls:

| Method              | Effect                                                                 | When to Use                                                 |
|---------------------|------------------------------------------------------------------------|-------------------------------------------------------------|
| *(none, the default)* | USER_MODE: CRUD and FLS enforced; caller's sharing context inherited | Every write your users reach                                |
| `.withUserMode()`   | Forces USER_MODE even if the org-wide kill switch has been flipped off | Belt-and-braces enforcement on a critical user-facing write |
| `.withSystemMode()` | Forces SYSTEM_MODE: bypasses CRUD/FLS for this transaction only        | Framework-owned writes (logs, orchestration rows)           |
| `.bypassSharing()`  | Routes through a `without sharing` proxy (sharing only; not CRUD/FLS)  | Isolated calculations that must ignore record-level sharing |

```apex
// User-facing write: enforce CRUD + FLS (USER_MODE is already the default;
// .withUserMode() makes the intent explicit and survives the kill switch)
kern.DML_Builder.newTransaction()
		.doInsert(accountFromUi)
		.withUserMode()
		.execute();

// Framework-owned write that must run as system (bypass CRUD/FLS)
kern.DML_Builder.newTransaction()
		.doInsert(orchestrationRecord)
		.withSystemMode()
		.execute();
```

> **There is no write-side `stripInaccessible()`.** Stripping inaccessible fields is a read concept. To make an
> untrusted write respect the user's field permissions, rely on the USER_MODE default (or `.withUserMode()`).
> It rejects writes to fields the running user can't update, which is the correct behaviour for a write.
> `.bypassSharing()` affects sharing only; it does **not** turn off USER_MODE's CRUD/FLS enforcement.

### When to Opt Out of USER_MODE

SYSTEM_MODE is for framework-internal reads and writes: configuration that the running user has no permission
on by design (custom metadata, framework-owned objects, system-schema lookups). Your application code should
almost never need it. When you do, prefer keeping the opt-out local:

- **One query or one transaction:** chain `.withSystemMode()` on that single call.
- **A whole selector that always reads framework-internal data:** subclass `kern.SEL_Base` and override
  `systemModeRequired()` to return `true`. Every query through that selector then runs in SYSTEM_MODE, keeping
  the opt-out in one place instead of scattered across call sites.

```apex
public with sharing class SEL_MyInternalSetting extends kern.SEL_Base
{
	public SEL_MyInternalSetting()
	{
		// MyInternalSetting__mdt is a stand-in — replace it with your own object or custom metadata type.
		super(MyInternalSetting__mdt.SObjectType);
	}

	public override Boolean systemModeRequired()
	{
		return true;
	}
}
```

### The Org-Wide Kill Switch

If a code change suddenly breaks security enforcement in production, you need a way to turn the secure default
off org-wide without waiting for a deployment. That master off-switch you can flip in an incident is the
kill-switch. Two custom metadata records hold it, and each controls the secure-by-default behaviour across the
whole org:

- `kern__FeatureFlag.UserModeQueries_Enabled` controls the default for every `kern.QRY_Builder` query.
- `kern__FeatureFlag.UserModeDml_Enabled` controls the default for every `kern.DML_Builder` transaction.

Both ship enabled (`IsEnabledByDefault__c = true`). To temporarily fall back to SYSTEM_MODE framework-wide,
**for emergency rollback only, while offending code is fixed**, set the relevant flag's
`IsEnabledByDefault__c` to `false` in **Setup > Custom Metadata Types > FeatureFlag**. The next transaction
picks it up, and no deploy is required. Do not flip these as a routine configuration lever: doing so weakens the
security posture of every query or write your users reach. A call that chained `.withUserMode()` keeps
enforcing USER_MODE even with the flag off, which is why critical user-facing paths should opt in explicitly.

### Field Encryption

Sometimes you need to encrypt a short-lived, session-scoped value, such as a temporary token or wizard state,
without managing keys yourself. For that case, with automatic key management, see the
[Security Guide: Data Encryption](Security%20-%20Guide.md#data-encryption--decryption-util_sessionencryption).
For long-term encrypted storage, use Salesforce Shield Platform Encryption.

---

## Common Issues

| Problem                                                              | Cause                                                              | Fix                                                                                                       |
|----------------------------------------------------------------------|--------------------------------------------------------------------|-----------------------------------------------------------------------------------------------------------|
| `System.QueryException` on a field the user can't read               | USER_MODE (default) enforces FLS and throws on an unreadable field | Chain `.stripInaccessible()` to drop the field instead of throwing, or grant the user FLS                 |
| Insert/update fails for a lower-permission user                      | USER_MODE (default) enforces CRUD/FLS on the write                 | Grant the user the needed object/field permission, or use `.withSystemMode()` for a framework-owned write |
| Admin test passes but real users see errors                          | Admin holds every permission, masking the enforcement              | Add a `System.runAs()` test with a `Minimum Access - Salesforce` user                                     |
| `.withSharing()` / `.bypassSharing()` seems to do nothing on a query | Those proxy methods only take effect in SYSTEM_MODE                | Chain `.withSystemMode()` first, or rely on USER_MODE which already enforces sharing                      |
| Looking for `.stripInaccessible()` on `DML_Builder`                  | Strip-inaccessible is a read-side concept                          | For untrusted writes, use the USER_MODE default (or `.withUserMode()`), which rejects unwritable fields   |
| Every query suddenly runs in SYSTEM_MODE                             | `UserModeQueries_Enabled` flag was flipped off                     | Set `IsEnabledByDefault__c = true` on the flag, or chain `.withUserMode()` on critical calls              |

---

## What You Now Know

After completing this guide, you understand **secure-by-default data access** in KernDX:

| Concept                    | What It Does                                                                          |
|----------------------------|---------------------------------------------------------------------------------------|
| **USER_MODE default**      | Every `kern.QRY_Builder` query and `kern.DML_Builder` write enforces CRUD/FLS/sharing |
| **`.stripInaccessible()`** | Removes fields the user can't read from query results instead of throwing             |
| **`.withSystemMode()`**    | Per-call opt-out for framework-internal reads/writes (bypasses CRUD/FLS)              |
| **`systemModeRequired()`** | Per-selector opt-out so framework-internal selectors always run SYSTEM_MODE           |
| **Kill-switch flags**      | `UserModeQueries_Enabled` and `UserModeDml_Enabled`, for emergency org-wide rollback only |

**Key patterns:**

- **Write nothing for the common case:** USER_MODE is the default, so secure reads and writes need no extra code.
- **`.stripInaccessible()` for graceful reads:** drop unreadable fields instead of failing the query.
- **`System.runAs()` in tests:** prove enforcement with a lower-permission user, because admins mask it.
- **Opt out locally, not globally:** `.withSystemMode()` per call or `systemModeRequired()` per selector, and
  reserve the kill-switch flags for emergencies.
- **There is no write-side strip:** for untrusted writes, USER_MODE rejects fields the user can't update.

---

## Next Steps

- [Selectors (secure query patterns)](Fast%20Start%20-%20Selectors.md)
- [DML Builder (secure writes)](Fast%20Start%20-%20DML.md)
- [Test Data Patterns](Fast%20Start%20-%20Test%20Data.md)
- [Code Scanning (catch security anti-patterns)](Fast%20Start%20-%20Code%20Scanning.md)
- [Complete Security Guide](Security%20-%20Guide.md)
- [QRY_Builder Reference](reference/apex/QRY_Builder.md)
- [DML_Builder Reference](reference/apex/DML_Builder.md)
