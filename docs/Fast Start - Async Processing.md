---
navOrder: 36
---

# Fast Start - Async Processing

**Framework:** KernDX | **Total time:** ~25 minutes

> Sequence work across separate Apex transactions with shared state, automatic recovery, and per-step
> governor isolation -- without hand-rolled Queueable chains.

**Before you start:**

- [ ] KernDX package installed in your org
- [ ] Org configured post-install — verify with the **Kern** app's Health Check (see [Installation guide](Installation.md#post-install-configuration))
- [ ] CLI authenticated (`sf org open -o YourOrgAlias` to verify) — or just use the Developer Console
  (Gear Icon > Developer Console) for all Apex work
- [ ] Working in a sandbox or scratch org (not production)

> **Subscriber orgs:** Use `kern.ClassName` when extending framework classes (e.g.,
> `kern.UTIL_AsyncChain.ChainStep`). Your own classes don't need a namespace prefix — the framework's
> Type Resolver handles resolution automatically.

**What you'll build:** A two-step async chain that creates an Account, then enriches it in a second
transaction -- plus a paired test class with 100% coverage.

**Success looks like:** Your chain row appears in `AsyncChainExecution__c` with `Status__c = Completed`,
the enriched Account shows the stamped Description, and the test class passes both branches.

**In one line:** `kern.UTIL_AsyncChain.newChain('Foo').then(new MyStep()).execute();` --
chain orchestration, persistent status, error recovery, all built in.

---

## Table of Contents

<details>
<summary>Expand</summary>

1. [How It Works](#how-it-works)
2. [Tier 1: See It Work (~2 minutes)](#tier-1-see-it-work-2-minutes)
3. [Tier 2: Build Your Own (~15 minutes)](#tier-2-build-your-own-15-minutes)
    - [Step 1: Create the chain step](#step-1-create-the-chain-step)
    - [Step 2: Execute the chain](#step-2-execute-the-chain)
    - [Step 3: Write the test class](#step-3-write-the-test-class)
    - [Step 4: Deploy and verify](#step-4-deploy-and-verify)
4. [Tier 3: Production Patterns (~5-10 minutes)](#tier-3-production-patterns-5-10-minutes)
5. [Sensitive data is masked by default](#sensitive-data-is-masked-by-default)
6. [Common Issues](#common-issues)
7. [What You Now Know](#what-you-now-know)
8. [Next Steps](#next-steps)

</details>

---

## How It Works

An async chain sequences steps across separate Queueable transactions. Each step gets a fresh set of
governor limits and a shared `ChainContext` that carries state between steps.

| Component                               | Role                                                            |
|-----------------------------------------|-----------------------------------------------------------------|
| `kern.UTIL_AsyncChain.newChain('Name')` | Entry point — returns a `ChainBuilder`                          |
| `kern.UTIL_AsyncChain.ChainStep`        | Abstract base — extend it and implement `work()`                |
| `kern.UTIL_AsyncChain.ChainContext`     | Shared state between steps (`get` / `put` / `has`)              |
| `kern.UTIL_AsyncChain.StepResult`       | Return value — `succeeded()` / `failed()`                       |
| `kern__AsyncChainExecution__c`          | Tracking row — status, step counts, error message, context data |

**Why a chain instead of a single Queueable?** Each step runs in its own transaction, so callouts +
DML do not conflict, governor limits reset between steps, and the framework records progress and
errors to a queryable row.

---

## Tier 1: See It Work (~2 minutes)

Open **Developer Console > Debug > Open Execute Anonymous Window**. Build a one-step chain that
stamps an Account's Description, then poll status:

```apex
Account record = new Account(Name = 'Async Demo');
insert record;

String executionId = kern.UTIL_AsyncChain.newChain('FastStartDemo')
	.withInitialContext('accountId', record.Id)
	.then(new EnrichStep())
	.execute();

System.debug('Chain executionId: ' + executionId);

public class EnrichStep extends kern.UTIL_AsyncChain.ChainStep
{
	public override kern.UTIL_AsyncChain.StepResult work(kern.UTIL_AsyncChain.ChainContext context)
	{
		Account toUpdate = new Account(Id = (Id)context.get('accountId'), Description = 'Enriched');
		kern.DML_Builder.newTransaction().doUpdate(toUpdate).execute();
		return kern.UTIL_AsyncChain.succeeded();
	}
}
```

Wait a few seconds, then check the status (replace `PASTE_EXECUTION_ID_HERE`):

```apex
Map<String, Object> status = kern.UTIL_AsyncChain.getStatus('PASTE_EXECUTION_ID_HERE');
System.debug('Status: ' + status.get('status'));
System.debug('Completed: ' + status.get('completedSteps') + '/' + status.get('totalSteps'));
```

**Expected output:**

```text
Status: Completed
Completed: 1/1
```

> **See it in the org:** App Launcher > Kern > **AsyncChainExecution** tab lists every chain with
> status, step counts, duration, and error message. This is the operator view.

For single-statement async work without orchestration, skip the chain entirely:
`kern.DML_Builder.newTransaction().doUpdate(records).async().execute();` —
[Fast Start - DML](Fast%20Start%20-%20DML.md) covers this.

> **When to move to Tier 2:** When you want a reusable step class with its own test coverage, a stable
> name in the AsyncChainExecution tab, and composability with other steps.

---

## Tier 2: Build Your Own (~15 minutes)

> **No local project?** You can create classes directly in the Developer Console (Gear Icon > Developer
> Console > File > New > Apex Class) and run tests from there too (Test > New Run). Paste the code, save,
> and skip the `sf project deploy start` and `sf apex run test` commands.

### Step 1: Create the chain step

Build a step that reads an Account Id from the chain context and stamps a Description. Copy this code
exactly as is into `force-app/main/default/classes/EnrichAccountStep.cls`:

> **Why `global`?** This lets the managed package resolve the class at runtime without additional setup.
> If you prefer `public with sharing`, you'll need a Type Resolver class. The Kern home page health check
> provides the code, or see [Type Resolution](Utilities%20-%20Guide.md#type-resolution-util_typeresolver).

```apex
/**
 * @description Async chain step that enriches an Account by stamping a Description.
 *
 * @see EnrichAccountStep_TEST
 *
 * @author your.name@company.com
 *
 * @group Async Processing
 *
 * @date May 2026
 */
global inherited sharing class EnrichAccountStep extends kern.UTIL_AsyncChain.ChainStep
{
	/** @description Chain context key that carries the Account Id to enrich. */
	public static final String CONTEXT_KEY_ACCOUNT_ID = 'accountId';

	/** @description Description value stamped on the enriched Account. */
	@TestVisible
	private static final String ENRICHMENT_NOTE = 'Enriched by Fast Start chain';

	/** @description Error message returned when the context is missing the account Id. */
	@TestVisible
	private static final String ERROR_MISSING_ACCOUNT_ID = 'Missing accountId in chain context';

	/**
	 * @description Reads the Account Id from context, updates the Description.
	 *
	 * @param context Shared chain context from upstream steps.
	 *
	 * @return StepResult — success with the enriched Id, or failure when accountId is missing.
	 */
	global override kern.UTIL_AsyncChain.StepResult work(kern.UTIL_AsyncChain.ChainContext context)
	{
		Id accountId = (Id)context.get(CONTEXT_KEY_ACCOUNT_ID);

		if(accountId == null)
		{
			return kern.UTIL_AsyncChain.failed(ERROR_MISSING_ACCOUNT_ID);
		}

		Account record = new Account(Id = accountId, Description = ENRICHMENT_NOTE);
		kern.DML_Builder.newTransaction().doUpdate(record).execute();

		return kern.UTIL_AsyncChain.succeeded('Account enriched', accountId);
	}
}
```

**Deploy:**

```bash
sf project deploy start -o YourOrgAlias -m "ApexClass:EnrichAccountStep"
```

**Key patterns:**

- `extends kern.UTIL_AsyncChain.ChainStep` — pulls in the `work()` contract
- `global override StepResult work(ChainContext)` — the only required method
- Read inputs via `context.get(key)` — store outputs via `context.put(key, value)`
- Return `kern.UTIL_AsyncChain.succeeded(msg, data)` or `.failed(msg)` — never throw
- Public no-arg constructor (Apex provides one when none are declared) — required for reflection

### Step 2: Execute the chain

Run from Execute Anonymous:

```apex
Account record = new Account(Name = 'Async Demo');
insert record;

String executionId = kern.UTIL_AsyncChain.newChain('AccountEnrichment')
	.withInitialContext(EnrichAccountStep.CONTEXT_KEY_ACCOUNT_ID, record.Id)
	.then(new EnrichAccountStep())
	.execute();

System.debug('Chain executionId: ' + executionId);
```

After a few seconds, query the result:

```apex
Account result = [SELECT Description FROM Account WHERE Name = 'Async Demo' ORDER BY CreatedDate DESC LIMIT 1];
System.debug('Description: ' + result.Description);
```

**Expected output:**

```text
Description: Enriched by Fast Start chain
```

### Step 3: Write the test class

Copy this code exactly as is into `force-app/main/default/classes/EnrichAccountStep_TEST.cls`. Both
tests drive the step through `execute()` rather than calling `work()` directly because
`kern.UTIL_AsyncChain.ChainContext` cannot be instantiated outside the framework.

```apex
/**
 * @description Tests for EnrichAccountStep.
 *
 * @see EnrichAccountStep
 *
 * @author your.name@company.com
 *
 * @group Async Processing
 *
 * @date May 2026
 */
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest(SeeAllData=false IsParallel=true)
private class EnrichAccountStep_TEST
{
	/** @description Chain name used by every test in this class. */
	private static final String CHAIN_NAME = 'EnrichAccountChain';

	/** @description Verifies the step stamps the Description when the context carries an Account Id. */
	@IsTest
	private static void shouldEnrichAccountWhenContextHasId()
	{
		Account record = (Account)kern.TST_Builder.of(Account.SObjectType)
			.withOverride(Account.Name, 'Chain Demo').build();

		Test.startTest();
		kern.UTIL_AsyncChain.newChain(CHAIN_NAME)
			.withInitialContext(EnrichAccountStep.CONTEXT_KEY_ACCOUNT_ID, record.Id)
			.then(new EnrichAccountStep()).execute();
		Test.stopTest();

		Account result = (Account)kern.QRY_Builder.selectFrom(Account.SObjectType)
			.fields(new List<SObjectField>{ Account.Description })
			.condition(Account.Id).equals(record.Id).getFirst();

		Assert.areEqual(EnrichAccountStep.ENRICHMENT_NOTE, result.Description, 'Description should be stamped');
	}

	/** @description Verifies the step fails when the context does not carry an Account Id. */
	@IsTest
	private static void shouldFailWhenContextMissingAccountId()
	{
		Test.startTest();
		String executionId = kern.UTIL_AsyncChain.newChain(CHAIN_NAME)
			.then(new EnrichAccountStep()).execute();
		Test.stopTest();

		Map<String, Object> status = kern.UTIL_AsyncChain.getStatus(executionId);
		Assert.areEqual('Failed', (String)status.get('status'), 'Chain should be Failed');
		Assert.areEqual(EnrichAccountStep.ERROR_MISSING_ACCOUNT_ID, (String)status.get('errorMessage'), 'Error propagated');
	}
}
```

### Step 4: Deploy and verify

```bash
sf project deploy start -o YourOrgAlias -m "ApexClass:EnrichAccountStep_TEST"
sf apex run test -o YourOrgAlias -t EnrichAccountStep_TEST --code-coverage --synchronous --result-format human
```

**Expected:** 2 tests passing, 100% coverage on `EnrichAccountStep`.

> **Why `Test.startTest() / Test.stopTest()`?** Without it, the Queueable enqueued by `execute()`
> never runs in the test transaction. `Test.stopTest()` flushes async work synchronously -- this is
> the single most common chain-test bug.

---

## Tier 3: Production Patterns (~5-10 minutes)

**Handlers** — attach steps that run when the chain fails or finishes. Inside `onError`,
`context.getPreviousStepResult()` returns the failed step's `StepResult` (inspect `message` / `error`):

```apex
kern.UTIL_AsyncChain.newChain('AccountEnrichment')
	.withInitialContext('accountId', record.Id)
	.then(new EnrichAccountStep())
	.onError(new NotifyAdminStep())
	.onComplete(new EmitMetricStep())
	.execute();
```

**Continue past optional failures** — pass `true` to `.then()` to skip over a failed step:

```apex
kern.UTIL_AsyncChain.newChain('OrderProcessing')
	.then(new ChargePaymentStep())
	.then(new SendReceiptStep(), true)   // failure here does not stop the chain
	.then(new MarkOrderShippedStep())
	.execute();
```

**Wrap an outbound API as a step** — `kern.UTIL_AsyncChain.ApiStep` runs any `kern.API_Outbound`
handler with validation, callout, parsing, DML, and `ApiCall__c` logging:

```apex
kern.UTIL_AsyncChain.newChain('OrderConfirmation')
	.withInitialContext('orderId', order.Id)
	.then(new kern.UTIL_AsyncChain.ApiStep(API_ChargePayment.class)
		.triggeringRecordFrom('orderId')
		.withParameter('amount', '99.99'))
	.execute();
```

See [Fast Start - Outbound APIs](Fast%20Start%20-%20Outbound%20APIs.md) for the handler shape.

**Test chains of more than one step** — Apex caps `Test.stopTest()` to one Queueable. Raise it via
`AsyncOptions` (the platform built-in `System.AsyncOptions`, not a kern inner class):

```apex
AsyncOptions options = new AsyncOptions();
options.maximumQueueableStackDepth = 5;

kern.UTIL_AsyncChain.newChain('MultiStep')
	.then(new StepOne()).then(new StepTwo()).then(new StepThree())
	.withAsyncOptions(options)
	.execute();
```

See the [Async Processing Guide](Async%20Processing%20-%20Guide.md) for delayed start, retry strategies, finalizer recovery.

---

## Sensitive data is masked by default

Chain state persisted on `AsyncChainExecution__c` (context data, step logs, error messages) is
redacted by the data masking framework before storage. Out of the box, `MaskSecretKeys` redacts
common secret JSON keys (`password`, `token`, `apiKey`, etc.) and `MaskPaymentCard` redacts
Luhn-validated card numbers. So `context.put('password', userPassword)` is safe at rest — but the
redaction is destructive, so downstream steps re-reading the persisted row see the redacted form.
Don't rely on chain context for authenticated callouts; use a Named Credential instead.

---

## Common Issues

| Problem                                          | Cause                                                             | Fix                                                                        |
|--------------------------------------------------|-------------------------------------------------------------------|----------------------------------------------------------------------------|
| `Failed (Class Not Found: MyStep)`               | Step class is `public`, invisible across the package namespace    | Make the step class `global`, or register a Type Resolver                  |
| Test assertions fail — Description never stamped | Missing `Test.startTest()` / `Test.stopTest()` around `execute()` | Wrap the chain build + execute in `Test.startTest/stopTest`                |
| `Status: Running` indefinitely                   | First step threw an unhandled exception before persisting status  | Check the `kern__LogEntry__c` rows for the chain's `correlationId`         |
| Chain test only runs first step                  | Default `maximumQueueableStackDepth` is 1 in tests                | Pass `.withAsyncOptions(options)` with `maximumQueueableStackDepth` raised |
| `context.get()` returns null                     | Value not JSON-serialisable, or key spelling mismatch             | Store only Ids, primitives, and simple collections; verify the key         |
| `Chain has already been executed`                | Reusing a `ChainBuilder` after `.execute()`                       | Build a fresh chain via `kern.UTIL_AsyncChain.newChain(...)`               |

---

## What You Now Know

- **`kern.UTIL_AsyncChain.newChain(name)`** — entry point that returns a `ChainBuilder`
- **`kern.UTIL_AsyncChain.ChainStep`** — extend and implement `work(ChainContext)`; return
  `kern.UTIL_AsyncChain.succeeded(...)` or `.failed(...)` rather than throwing
- **`ChainContext`** — shared state across transactions via `get` / `put` / `has`;
  `getPreviousStepResult()` for handler steps
- **`kern__AsyncChainExecution__c`** — persistent tracking row (status, step counts, error
  message) queryable from anywhere
- **`kern.UTIL_AsyncChain.ApiStep`** — runs a `kern.API_Outbound` handler as a chain step
- **`global` is required on step classes** — the framework instantiates them by class name
  via reflection across the package namespace boundary
- **`Test.startTest() / Test.stopTest()`** flushes the queueable; raise
  `AsyncOptions.maximumQueueableStackDepth` for chains of more than one step under test
- **Use `kern.DML_Builder.async()`** for single-statement async work; use a chain only when you
  need multi-step orchestration with fresh governor limits between steps

---

## Next Steps

| Topic                        | Link                                                                   |
|------------------------------|------------------------------------------------------------------------|
| Outbound HTTP calls          | [Fast Start - Outbound APIs](Fast%20Start%20-%20Outbound%20APIs.md)    |
| DML Builder (sync and async) | [Fast Start - DML](Fast%20Start%20-%20DML.md)                          |
| Logging and correlation      | [Fast Start - Logging](Fast%20Start%20-%20Logging.md)                  |
| Feature flag gating          | [Fast Start - Feature Flags](Fast%20Start%20-%20Feature%20Flags.md)    |
| Complete async reference     | [Async Processing - Guide](Async%20Processing%20-%20Guide.md)          |
| `UTIL_AsyncChain` API        | [reference/apex/UTIL_AsyncChain.md](reference/apex/UTIL_AsyncChain.md) |
