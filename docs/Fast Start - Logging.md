---
navOrder: 18
---

# Fast Start - Logging

**Framework:** KernDX | **Total time:** ~30 minutes

**What this is:** A way to write logs that you can search, report on, and keep, instead of Salesforce's built-in `System.debug()` output, which expires and can't be queried. **Why it matters:** when something fails in production, the evidence is still there days later, linked to the records and the single user action that triggered it. **Who should follow this:** developers capturing errors, plus tech leads and DevOps who need traceability in live systems. **When to use it:** any time you'd otherwise use `System.debug()`. For a one-off value you only need while developing, plain `System.debug()` is still fine; switch to persistent logging when you need the evidence to survive into production.

> What you'll get working: persistent, queryable logging that adds no database writes to your own transaction and survives rollbacks.

**Before you start:**

- [ ] KernDX package installed in your org
- [ ] Org configured post-install (verify with the **Kern** app's Health Check; see [Installation guide](Installation.md#post-install-configuration))
- [ ] CLI authenticated (`sf org open -o YourOrgAlias` to verify), or just use the Developer Console
  (Gear Icon > Developer Console) for all Apex work
- [ ] Working in a sandbox or scratch org (not production)

**What you'll build:** A service class that logs every step of order processing (start, per-record
progress, errors, and completion), with all entries correlated under a single ID.

**Success looks like:** Log entries visible in **App Launcher > Kern > Log Entries**, showing correlated
info/debug/error messages linked to specific Account records. Your test class shows 2/2 passing. (The two
tests cover the happy path; the defensive per-record error handler isn't exercised, so `SVC_OrderProcessor`
lands at ~82% coverage. Add a test that forces a failure inside the loop to take it to 100%.)

**In one line:** `kern.LOG_Builder.build().info('Payment processed').forRecord(accountId).emitAt('SVC.charge');`
persists via platform event and survives rollbacks.

---

## Table of Contents

<details>
<summary>Expand</summary>

1. [Tier 1: See It Work (~2 minutes)](#tier-1-see-it-work-2-minutes)
    - [Log at every level](#log-at-every-level)
    - [Log an exception with full stack trace](#log-an-exception-with-full-stack-trace)
    - [Correlate logs to a record](#correlate-logs-to-a-record)
2. [Tier 2: Build Your Own (~20 minutes)](#tier-2-build-your-own-20-minutes)
    - [Step 1: Create the service class](#step-1-create-the-service-class)
    - [Step 2: Deploy and execute](#step-2-deploy-and-execute)
    - [Step 3: Write the test class](#step-3-write-the-test-class)
    - [Step 4: Deploy and run tests](#step-4-deploy-and-run-tests)
        - [Key Patterns](#key-patterns)
3. [Tier 3: Production Patterns (~5-10 minutes)](#tier-3-production-patterns-5-10-minutes)
    - [Log levels](#log-levels)
    - [Flood control for repeated events](#flood-control-for-repeated-events)
    - [Shorthand: .emitAt()](#shorthand-emitat)
    - [Exception logging](#exception-logging)
    - [Testing with logs](#testing-with-logs)
    - [Scoped logging](#scoped-logging)
    - [Logging from Flows](#logging-from-flows)
    - [Logging from LWC](#logging-from-lwc)
4. [Sensitive data is masked by default](#sensitive-data-is-masked-by-default)
5. [Common Issues](#common-issues)
6. [What You Now Know](#what-you-now-know)
7. [Next Steps](#next-steps)

</details>

---

## Tier 1: See It Work (~2 minutes)

Run these blocks in **Execute Anonymous** (Developer Console or VS Code) to see logging in action.

### Log at every level

```apex
kern.LOG_Builder.LogScope scope = kern.LOG_Builder.scope();

try
{
	kern.LOG_Builder.build().info('Application started').emitAt('MyApp.initialize');
	kern.LOG_Builder.build().debug('Loading configuration').emitAt('MyApp.loadConfig');
	kern.LOG_Builder.build().warn('Configuration missing, using defaults').emitAt('MyApp.loadConfig');
	kern.LOG_Builder.build().error('Failed to connect').emitAt('MyApp.connect');
}
finally
{
	scope.close();
}
```

Open **App Launcher > Kern > Log Entries** to see your four entries. Each has a log level, message, and
class/method context. All four also share the same **Correlation ID**, a single tracking ID that follows
one user action across triggers, queries, callouts, and jobs, so you can filter the four entries as a group.

> **Why the scope wrapper?** Each `.emit()` publishes a platform event, and Salesforce caps a single
> transaction at 150 such immediate publishes (the `PublishImmediate` governor). The scope wrapper keeps
> you safely under that cap: `LOG_Builder.scope()` collects every emission inside the try/finally and
> sends them as one batch when `scope.close()` runs.

### Log an exception with full stack trace

```apex
try
{
	Integer result = 1 / 0;
}
catch(Exception error)
{
	kern.LOG_Builder.build().error(error).emitAt('MyApp.calculate');
}
```

Open the log entry. You'll see the exception type (`MathException`) and the full stack trace, both
captured automatically.

### Correlate logs to a record

```apex
Account newAccount = new Account(Name = 'Logging Demo Corp', Phone = '555-0100');
insert newAccount;

kern.LOG_Builder.build().info('Account created successfully')
	.at('MyApp.createAccount')
	.forRecord(newAccount.Id)
	.emit();

kern.LOG_Builder.build().info('Ready for processing')
	.at('MyApp.createAccount')
	.forRecord(newAccount.Id)
	.withContext('industry', 'Technology')
	.emit();
```

Both log entries link to the Account record. Click **View Record** on any log entry to jump directly to it.

> **When to move to Tier 2:** When you want structured logging inside your own classes with automated test
> coverage.

---

## Tier 2: Build Your Own (~20 minutes)

> **No local project?** You can create classes directly in the Developer Console (Gear Icon > Developer Console >
> File > New > Apex Class) and run tests from there too (Test > New Run). Paste the code, save, and skip the
> `sf project deploy start` and `sf apex run test` commands.

### Step 1: Create the service class

This service processes Account records and logs every step (start, per-record progress, errors, and
completion), correlated under one Scope.

Copy this code exactly as is into `force-app/main/default/classes/SVC_OrderProcessor.cls`:

```apex
/**
 * @description Processes Account records with correlated, structured logging at every step.
 *
 * @see SVC_OrderProcessor_TEST
 *
 * @author your.name@company.com
 *
 * @group Order Management
 *
 * @date February 2026
 */
public with sharing class SVC_OrderProcessor
{
	/** @description Context key for the record count. */
	@TestVisible private static final String CONTEXT_COUNT = 'count';

	/**
	 * @description Processes a list of Account records with full correlated logging.
	 *
	 * @param accounts The Account records to process.
	 */
	public void processOrders(List<Account> accounts)
	{
		kern.LOG_Builder.LogScope scope = kern.LOG_Builder.scope();

		try
		{
			kern.LOG_Builder.build()
				.info('Order processing started')
				.withContext(CONTEXT_COUNT, accounts.size())
				.emitAt('SVC_OrderProcessor.processOrders');

			for(Account account : accounts)
			{
				try
				{
					kern.LOG_Builder.build()
						.debug('Processing account')
						.forRecord(account.Id)
						.emitAt('SVC_OrderProcessor.processOrders');
				}
				catch(Exception error)
				{
					kern.LOG_Builder.build()
						.error(error)
						.forRecord(account.Id)
						.emitAt('SVC_OrderProcessor.processOrders');
				}
			}

			kern.LOG_Builder.build()
				.info('Order processing completed')
				.withContext(CONTEXT_COUNT, accounts.size())
				.emitAt('SVC_OrderProcessor.processOrders');
		}
		finally
		{
			scope.close();
		}
	}

	/**
	 * @description Emits a single ERROR-level alert.
	 *
	 * @param message The alert message to persist.
	 */
	public void criticalAlert(String message)
	{
		kern.LOG_Builder.build()
			.error(message)
			.emitAt('SVC_OrderProcessor.criticalAlert');
	}
}
```

**What this code does:**

- `LOG_Builder.scope()` opens a batch scope: every `.emit()` call inside the try/finally shares one
  Correlation ID and is flushed together at `scope.close()`, staying well under the 150-event limit
- `.info()` / `.debug()` / `.warn()` / `.error()` set the log level
- `.at('ClassName.methodName')` records where the log came from
- `.forRecord(account.Id)` links the log entry to the Account being processed
- `.withContext(key, value)` adds structured key-value data to the entry
- `.emitAt('Class.method')` shorthand for `.at(...).emit()`

### Step 2: Deploy and execute

```bash
sf project deploy start -o YourOrgAlias -m "ApexClass:SVC_OrderProcessor" --ignore-conflicts
```

Test it from Execute Anonymous:

```apex
Account newAccount = new Account(Name = 'Order Demo Corp', Phone = '555-0200', BillingCity = 'Melbourne');
insert newAccount;

new SVC_OrderProcessor().processOrders(new List<Account>{ newAccount });
System.debug('Done — check App Launcher > Kern > Log Entries');
```

> **See it in the org:** Open **App Launcher > Kern > Log Entries**. You'll see three entries (an INFO
> for started, a DEBUG per record, and an INFO for completed), all sharing the same Correlation ID.

### Step 3: Write the test class

Copy this code exactly as is into `force-app/main/default/classes/SVC_OrderProcessor_TEST.cls`:

```apex
/**
 * @description Unit tests for SVC_OrderProcessor.
 *
 * @see SVC_OrderProcessor
 *
 * @author your.name@company.com
 *
 * @group Order Management
 *
 * @date February 2026
 */
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest(SeeAllData=false IsParallel=true)
private class SVC_OrderProcessor_TEST
{
	/** @description Log level string for INFO entries. */
	private static final String LOG_LEVEL_INFO = 'INFO';

	/** @description Log level string for ERROR entries. */
	private static final String LOG_LEVEL_ERROR = 'ERROR';

	/** @description Alert message used in the error path test. */
	private static final String ALERT_MESSAGE = 'Critical system failure';

	/**
	 * @description Verifies that processOrders() creates correlated log entries
	 * queryable by kern__UserId__c after platform event delivery.
	 */
	@IsTest
	private static void shouldCreateScopedLogEntriesForProcessedAccounts()
	{
		Account account = (Account)kern.TST_Builder.of(Account.SObjectType).build();

		kern.LOG_Builder.ignoreTestMode = true;

		Test.startTest();
		new SVC_OrderProcessor().processOrders(new List<Account>{ account });
		Test.getEventBus().deliver();
		Test.stopTest();

		// Query by kern__UserId__c — NOT CreatedById.
		// TRG_PersistLogEntry runs as the Automated Process user, so CreatedById returns zero rows.
		Id currentUserId = UserInfo.getUserId();
		List<kern__LogEntry__c> entries = [
			SELECT kern__LogLevel__c, kern__CorrelationId__c
			FROM kern__LogEntry__c
			WHERE kern__UserId__c = :currentUserId
		];

		Assert.isFalse(entries.isEmpty(), 'Expected correlated log entries after event delivery');

		Boolean foundInfo = false;

		for(kern__LogEntry__c entry : entries)
		{
			if(entry.kern__LogLevel__c == LOG_LEVEL_INFO)
			{
				foundInfo = true;
			}
		}

		Assert.isTrue(foundInfo, 'Expected at least one INFO entry from processOrders()');
	}

	/**
	 * @description Verifies that criticalAlert() persists an ERROR entry with the correct message.
	 */
	@IsTest
	private static void shouldPersistErrorEntryForCriticalAlert()
	{
		kern.LOG_Builder.ignoreTestMode = true;

		Test.startTest();
		new SVC_OrderProcessor().criticalAlert(ALERT_MESSAGE);
		Test.getEventBus().deliver();
		Test.stopTest();

		// Query by kern__UserId__c — NOT CreatedById (see note in test above)
		Id currentUserId = UserInfo.getUserId();
		List<kern__LogEntry__c> entries = [
			SELECT kern__Message__c, kern__LogLevel__c
			FROM kern__LogEntry__c
			WHERE kern__UserId__c = :currentUserId AND kern__LogLevel__c = :LOG_LEVEL_ERROR
		];

		Assert.isFalse(entries.isEmpty(), 'Expected one ERROR entry from criticalAlert()');
		Assert.areEqual(ALERT_MESSAGE, entries[0].kern__Message__c, 'Message should match the alert text');
	}
}
```

> **About the query filter:** Tests must filter `kern__LogEntry__c` by `kern__UserId__c`, not by
> `CreatedById`. The platform trigger that persists log entries (`TRG_PersistLogEntry`) runs as the
> Automated Process user, so a `CreatedById` filter returns zero rows. The `kern__UserId__c` field, by
> contrast, holds the ID of the user who emitted the log.

> **About the annotations:** `@IsTest(SeeAllData=false IsParallel=true)` keeps tests isolated and
> enables parallel execution. `@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')` suppresses a
> code analysis rule. In production tests, consider wrapping logic in `System.runAs(testUser)` to
> verify profile and permission set access.

### Step 4: Deploy and run tests

```bash
sf project deploy start -o YourOrgAlias -m "ApexClass:SVC_OrderProcessor_TEST" --ignore-conflicts
sf apex run test -o YourOrgAlias -t SVC_OrderProcessor_TEST --code-coverage --synchronous --result-format human
```

**Expected output:**

```text
=== Test Results
Tests Ran        2
Passing          2
Failing          0
```

#### Key Patterns

| Pattern                  | Example                                   | Why                                                                    |
|--------------------------|-------------------------------------------|------------------------------------------------------------------------|
| Scope batching           | `LOG_Builder.scope()` + try/finally       | Keeps you under the platform-event publish limit; groups entries under one Correlation ID |
| Log at method boundaries | `.info('started')` + `.info('completed')` | Trace execution flow in production                                     |
| Per-record context       | `.forRecord(account.Id)`                  | All logs for one record queryable together                             |
| Debug inside loops       | `.debug('Processing account')`            | Filtered in production; visible in sandbox                             |
| Catch-log-continue       | `.error(error)` in catch, no rethrow      | Persistent record; processing continues for remaining items            |
| Single-shot alert        | `.error('message').emitAt(...)`           | One-liner for config/startup errors                                    |
| Query by UserId          | `kern__UserId__c = UserInfo.getUserId()`  | NOT `CreatedById` (TRG_PersistLogEntry runs as Automated Process user) |

---

## Tier 3: Production Patterns (~5-10 minutes)

### Log levels

See the [Logging Guide](Logging%20-%20Guide.md) for the complete log level reference and filtering
configuration.

| Level | Method                                     | When to use                                                           |
|-------|--------------------------------------------|-----------------------------------------------------------------------|
| ERROR | `.error(exception)` or `.error('message')` | Failures, exceptions, data corruption                                 |
| WARN  | `.warn('message')`                         | Business rule violations, missing optional data, degraded performance |
| INFO  | `.info('message')`                         | Key business events, state transitions, completion messages           |
| DEBUG | `.debug('message')`                        | Implementation details, variable values (filtered in production)      |

### Flood control for repeated events

When the same event fires repeatedly in a hot loop, you don't want thousands of near-identical rows drowning the log table. Tag the event with a fingerprint instead: the first occurrence keeps a full entry, and repeats roll up into a daily counter.

```apex
kern.LOG_Builder.build()
		.warn('Payment gateway retry failed')
		.withFingerprint('payment-gateway-retry')
		.emitAt('PaymentSync.run');
```

Pick a fingerprint that identifies the *kind* of event, and keep it stable (never use a record Id or timestamp, or every occurrence looks unique and the rollup never kicks in). See [Log Grouping & Flood Control](Logging%20-%20Guide.md#log-grouping--flood-control) in the Logging Guide for reading grouped logs and reporting on occurrence counts.

### Shorthand: `.emitAt()`

When you don't need `.forRecord()` or `.withContext()`, use `.emitAt()` as shorthand for `.at().emit()`:

```apex
// These are equivalent:
kern.LOG_Builder.build().info('Done').at('MyClass.myMethod').emit();
kern.LOG_Builder.build().info('Done').emitAt('MyClass.myMethod');
```

Use `.emitAt()` for simple messages. Use `.at()` + chain + `.emit()` when adding `.forRecord()` or
`.withContext()`.

### Exception logging

Always pass the `Exception` object, never `.getMessage()`:

```apex
catch(Exception error)
{
	// Captures exception type, message, AND full stack trace
	kern.LOG_Builder.build().error(error).at('MyClass.myMethod').forRecord(recordId).emit();
	throw error;
}
```

### Testing with logs

To assert on log entries in a test, you need them to actually be written, and by default they aren't:
logs are suppressed in `@IsTest` context. Two steps turn them on. Set
`kern.LOG_Builder.ignoreTestMode = true` before your log call to enable logging in tests, then call
`Test.getEventBus().deliver()` to deliver the platform events synchronously before you assert.

Here's the complete working pattern:

```apex
kern.LOG_Builder.ignoreTestMode = true;

Test.startTest();
new SVC_OrderProcessor().processOrders(accounts);
Test.getEventBus().deliver();
Test.stopTest();

// Query by kern__UserId__c — NOT CreatedById
Id currentUserId = UserInfo.getUserId();
List<kern__LogEntry__c> entries = [
	SELECT kern__Message__c
	FROM kern__LogEntry__c
	WHERE kern__UserId__c = :currentUserId
];

Assert.isFalse(entries.isEmpty(), 'Should have log entries');
```

> **Key steps:** `ignoreTestMode = true` → emit logs → `Test.getEventBus().deliver()` → query by
> `kern__UserId__c` → assert.

> **Why inline SOQL for `kern__LogEntry__c`?** Plain inline SOQL is the simplest way to query a
> managed-package object from your own tests when no `SEL_*` selector exists for it. The query builder
> hits a snag here: when you reference a managed-package object through
> `kern.QRY_Builder.selectFrom(<kern__sobject>.SObjectType)` and then chain `.condition(<kern__sobject>.<kern__field>)`,
> Apex's namespace tokenizer struggles with the doubly-prefixed field token. This affects only
> managed-package objects: for your own objects, `kern.QRY_Builder` works without issue.

### Scoped logging

When one operation emits many logs, you want them grouped together and you want to avoid the platform
event publish cap. A scope does both. `LOG_Builder.scope()` groups every log entry emitted inside a
try/finally block under a single Correlation ID, and batches their platform event publications into one
flush at `scope.close()`. That single flush keeps you well clear of the 150-event `PublishImmediate`
governor limit.

```apex
kern.LOG_Builder.LogScope scope = kern.LOG_Builder.scope();

try
{
	kern.LOG_Builder.build().info('Batch started').emitAt('BATCH_ProcessAccounts.execute');
	// ... process records ...
	kern.LOG_Builder.build().info('Batch completed').emitAt('BATCH_ProcessAccounts.execute');
}
finally
{
	scope.close();
}
```

Run this from Execute Anonymous to see correlated scoped entries:

```apex
kern.LOG_Builder.LogScope scope = kern.LOG_Builder.scope();

try
{
	kern.LOG_Builder.build().info('Step 1: Loading data').emitAt('MyApp.processRecords');
	kern.LOG_Builder.build().info('Step 2: Validating').emitAt('MyApp.processRecords');
	kern.LOG_Builder.build().info('Step 3: Complete').emitAt('MyApp.processRecords');
}
finally
{
	scope.close();
}

System.debug('Check App Launcher > Kern > Log Entries — all three entries share the same Correlation ID.');
```

### Logging from Flows

Use invocable actions to log from Flows. This creates correlated log entries visible in the same
**Log Entries** tab as Apex logs.

1. Open **Setup > Flows** and edit your Flow (or create a new one)
2. Add an **Action** element:
    - Search for **Start Flow Correlation**
    - Set **Label** to `Start Logging`
    - Set **flowName** to the name of your Flow (e.g., `Account_Onboarding`)
    - Set **recordId** to the record ID variable (e.g., `{!recordId}`)
    - Store the output **correlationId** in a text variable (e.g., `{!correlationId}`)
3. At key steps, add **Action** elements:
    - Search for **Log Flow Event**
    - Set **correlationId** to `{!correlationId}`
    - Set **message** to a description (e.g., `Account created successfully`)
    - Set **Log Level** (input name `logLevel`) to `INFO`, `WARN`, or `ERROR`
4. At the end of the Flow, add an **Action** element:
    - Search for **End Flow Correlation**
    - Set **flowName** to the same Flow name used in step 2
    - Set **correlationId** to `{!correlationId}`
    - Set **Success** (input name `success`) to `{!$GlobalConstant.True}` (or `False` for failure paths)
5. **Save** and **Activate**

All log entries from the Flow share the same Correlation ID, so you can filter them together in
**App Launcher > Kern > Log Entries**.

### Logging from LWC

From a Lightning Web Component, log with the built-in `consoleLog()` and `consoleError()` methods on
ComponentBuilder (the KernDX base class that gives your components their common wiring, such as toasts,
Apex calls, and navigation, already built in). These write to the browser console, not to
`kern__LogEntry__c`. So for server-side persistent logging, use `LOG_Builder` in your Apex controller
methods instead.

```javascript
// In any ComponentBuilder LWC:
this.consoleLog('User clicked save');
this.consoleError('Save failed', error);
```

See the [LWC Guide](LWC%20-%20Guide.md) for the full ComponentBuilder reference, or the
[Logging Guide](Logging%20-%20Guide.md) for server-side logging patterns.

---

## Sensitive data is masked by default

You don't have to remember to scrub secrets out of your logs: every entry passes through the data
masking framework before it is saved. Out of the box, two rules fire:

- **`MaskSecretKeys`** redacts common secret JSON keys (`password`, `token`, `apiKey`, `authorization`,
  `bearer`, `client_secret`, `private_key`, `access_token`, `refresh_token`) anywhere they appear in a
  field value.
- **`MaskPaymentCard`** redacts 13–19 digit sequences that pass the Luhn (mod-10) checksum, covering all
  major card brands (digits may be separated by spaces or hyphens). The Luhn check filters out most
  transaction IDs, order numbers, and other long digit runs that would otherwise false-positive as card
  data. (It replaces the original `MaskCreditCard` rule, which still ships for compatibility.)

So `LOG_Builder.build().info('Payload: ' + JSON.serialize(payload)).emitAt(...)` is safe even if `payload`
contains a `password` or card number: the persisted `LogEntry__c.Message__c` will have them redacted.
Fifteen more rules (SSN, IBAN, SWIFT/BIC, MBI, health keywords, email, US phone, JWT, AWS access key,
URL basic auth, authorization header, private IPv4, postal address, free text, international phone) ship as inactive templates. To switch one on, flip
`kern__MaskingRule__mdt.IsActive__c = true` and add a `kern__MaskingTarget__mdt` record wiring the rule
to the fields that need it.

> **Wiring gotcha.** Wiring a rule to a field doesn't guarantee it fires: a rule carries two optional
> filters that can quietly veto a target. `ApplicableFieldTypes__c` restricts which `DisplayType`s the
> rule applies to, and `MinInputLength__c` sets a minimum value length. If a `MaskingTarget__mdt` points
> at a `Field__c` whose type or value length the filter rejects, the rule will **not** run on that field.
> A type mismatch is at least visible: for an `ApplicableFieldTypes__c` mismatch the framework logs a
> one-time `warn` LogEntry to surface the misconfiguration. A `MinInputLength__c` mismatch is silent.
> The fix in either case is to widen the rule filter or remove the target.

> **Masking performance telemetry.** If you ever suspect masking is slowing down a trigger, you can
> measure it. Masking runs inside trigger dispatch, so enable
> `LogSetting__c.EnableMaskerPerformanceLogging__c` (default off) to emit one aggregate `LogEntry__c` per
> trigger batch, not per record. The log fires only when total masking time for that batch meets or
> exceeds `LogSetting__c.MaskerPerformanceThresholdMs__c` (default 100ms), so it stays quiet until there's
> something worth seeing.

---

## Common Issues

| Problem                                        | Cause                                                      | Fix                                                                                                                                                                        |
|------------------------------------------------|------------------------------------------------------------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| No log entries appear in tests                 | Logs suppressed in test context                            | Set `kern.LOG_Builder.ignoreTestMode = true` before logging                                                                                                                |
| Log entries empty after `ignoreTestMode`       | Platform events not delivered                              | Call `Test.getEventBus().deliver()` after emitting and before asserting                                                                                                    |
| Query returns zero rows in tests               | Filtering by `CreatedById` instead of `kern__UserId__c`    | Use `kern__LogEntry__c.kern__UserId__c = UserInfo.getUserId()`. `TRG_PersistLogEntry` runs as the Automated Process user, so `CreatedById` never matches the running user |
| `Variable does not exist: kern__LogEntry__c`   | Missing namespace prefix                                   | Use `kern__LogEntry__c` and `kern__FieldName__c` (double underscore) for SObjects and fields                                                                               |
| `.error(error.getMessage())` loses stack trace | Passing String instead of Exception                        | Use `.error(error)` to pass the Exception object directly                                                                                                                  |
| Logs have no method context                    | Missing `.at()` or `.emitAt()`                             | Always include `.emitAt('Class.method')` or `.at('Class.method')`                                                                                                          |
| Platform-event limit error after many emits    | >150 `PublishImmediate` events in one transaction          | Wrap emit calls in `kern.LOG_Builder.scope()` + try/finally to batch the flush                                                                                             |
| `Test.getEventBus()` not found                 | Running outside `@IsTest` context                          | `Test.getEventBus().deliver()` only works inside test methods                                                                                                              |
| Sensitive value appears raw in a log           | Field not covered by a masking target, or rule is inactive | Add a `kern__MaskingTarget__mdt` record with the rule, SObjectType, and field (blank `Field__c` for a wildcard). See [Logging Guide](Logging%20-%20Guide.md)              |

---

## What You Now Know

| Concept                                         | What it does                                                         |
|-------------------------------------------------|----------------------------------------------------------------------|
| `kern.LOG_Builder.build()`                      | Creates a fluent log entry builder                                   |
| `.info()` / `.warn()` / `.error()` / `.debug()` | Sets the log level                                                   |
| `.at('Class.method')`                           | Records where the log came from                                      |
| `.forRecord(Id)`                                | Links the log entry to a specific record                             |
| `.withContext(key, value)`                      | Adds structured key-value data                                       |
| `.withSummary(message)`                         | Sets a short searchable summary on the entry                         |
| `.emitAt('Class.method')`                       | Shorthand for `.at().emit()`                                         |
| `.emit()`                                       | Publishes the log as a platform event                                |
| `LOG_Builder.scope()`                           | Batches all emits under one Correlation ID; keeps you under the platform-event publish limit |
| `ignoreTestMode = true`                         | Enables logging in test context                                      |
| `Test.getEventBus().deliver()`                  | Delivers platform events synchronously in tests                      |
| `kern__UserId__c`                               | The field to filter on when querying log entries (NOT `CreatedById`) |

**Key patterns:**

- Wrap bulk logging in `LOG_Builder.scope()` + try/finally (batches emits, keeps you under the platform-event publish limit)
- Log at method boundaries (entry + exit) for execution tracing
- Always pass `Exception` objects, not `.getMessage()` strings
- Use `.forRecord()` on every log call to enable record-level filtering
- Add `.withContext()` for structured data instead of string concatenation
- In tests: `ignoreTestMode = true` → emit → `Test.getEventBus().deliver()` → query by `kern__UserId__c` → assert

---

## Next Steps

- [Fast Start - Feature Flags](Fast%20Start%20-%20Feature%20Flags.md)
- [Fast Start - Test Data](Fast%20Start%20-%20Test%20Data.md)
- [Code Scanning (catch System.debug anti-patterns)](Fast%20Start%20-%20Code%20Scanning.md)
- [Logging Developer Guide](Logging%20-%20Guide.md)
- [LOG_Builder API Reference](reference/apex/LOG_Builder.md)
- [LogEntry__c Object](reference/objects/LogEntry__c.md)
- [Flow Logging](reference/apex/FLOW_LoggerStart.md)
