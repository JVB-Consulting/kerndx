---
navOrder: 36
---

# Fast Start - Async Processing

**Framework:** KernDX | **Total time:** ~25 minutes

**What this is:** A way to run a multi-step background job where each step runs in its own Salesforce transaction but they pass information to each other. **Why it exists:** Some work is too big or too slow to finish while a user waits, and a single background job can run out of Salesforce's per-transaction allowances (governor limits) or hit conflicts between calling an external system and saving records. Splitting the work into a sequence gives each step a fresh start, automatic recovery if one fails, and a record of how far it got, without you writing the wiring by hand. **Who should follow this:** developers building background processing, and the tech leads reviewing it. **When to use it:** any time you have several steps that should run after a user's request returns, and you want each step isolated and the whole run tracked. If you only need a single statement run in the background, the built-in `kern.DML_Builder.async()` is simpler; reach for a chain once there are multiple steps to sequence.

What you'll build in one line: a one-step background job that enriches an Account you create first, in a transaction of its own.

> **Namespaces in code samples:** `kern.` on a class and `kern__` on an object, field, or metadata type mark the managed package's namespace.
> On the managed package, framework references need those prefixes even where a sample omits them; repackaged under your own namespace, replace `kern`/`kern__`
> with your prefix; on an unmanaged deploy, drop them. See [How to read the code samples](Installation.md#how-to-read-the-code-samples).

**What you'll build:** A one-step async chain (a sequence of background steps) that enriches an Account you
create first, in a transaction of its own, plus a paired test class with 100% coverage.

**Success looks like:** Your chain row appears in `kern__AsyncChainExecution__c` with `kern__Status__c = Completed`,
the enriched Account shows the stamped Description, and the test class passes both branches.

**In one line:** `kern.UTIL_AsyncChain.newChain('Foo').then(new MyStep()).execute();` runs your steps in
order, tracks their status as a record, and recovers from errors, all built in.

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
2. [How It Works](#how-it-works)
3. [Tier 1: See It Work](#tier-1-see-it-work)
4. [Tier 2: Build Your Own (~15 minutes)](#tier-2-build-your-own-15-minutes)
    - [Step 1: Create the chain step](#step-1-create-the-chain-step)
    - [Step 2: Execute the chain](#step-2-execute-the-chain)
    - [Step 3: Write and run the test](#step-3-write-and-run-the-test)
5. [Tier 3: Production Patterns (~5-10 minutes)](#tier-3-production-patterns-5-10-minutes)
6. [Sensitive data is masked by default](#sensitive-data-is-masked-by-default)
    - [Clean up](#clean-up)
7. [Common Issues](#common-issues)
    - [Step 1: Create the chain step](#step-1-create-the-chain-step-1)
    - [Step 2: Execute the chain](#step-2-execute-the-chain-1)
    - [Step 3: Write and run the test](#step-3-write-and-run-the-test-1)
    - [Tier 3: Production Patterns (~5-10 minutes)](#tier-3-production-patterns-5-10-minutes-1)
8. [What You Now Know](#what-you-now-know)
9. [Next Steps](#next-steps)

</details>

---

## How It Works

A chain is just a list of steps that run one after another. Each step runs in its own background
transaction (a Queueable), so it starts with a fresh set of Salesforce's per-transaction allowances
(governor limits). A shared object called the `ChainContext` carries information from one step to the
next.

Here are the pieces you'll work with:

| Component                               | Role                                                            |
|-----------------------------------------|-----------------------------------------------------------------|
| `kern.UTIL_AsyncChain.newChain('Name')` | Entry point: returns a `ChainBuilder`                          |
| `kern.UTIL_AsyncChain.ChainStep`        | Abstract base: extend it and implement `work()`                |
| `kern.UTIL_AsyncChain.ChainContext`     | Shared state between steps (`get` / `put` / `has`)              |
| `kern.UTIL_AsyncChain.StepResult`       | Return value: `succeeded()` / `failed()`                       |
| `kern__AsyncChainExecution__c`          | Tracking row: status, step counts, error message, context data |

**Why a chain instead of a single Queueable?** Because each step runs in its own transaction, you get
three things a single job can't give you. A step that calls an external system and a step that saves
records no longer conflict. Each step starts with its allowances reset. And the framework writes
progress and any errors to a record you can query later.

---

## Tier 1: See It Work

The quickest way to see a chain run is [Step 1](#step-1-create-the-chain-step) and
[Step 2](#step-2-execute-the-chain) below: you save one small step class in your org, then start a one-step chain
from the Developer Console and read back the Account it stamped. The step class has to be saved in your org first,
because the chain creates each step again from its class name in a later background job, and a class you declare
inside the Execute Anonymous window no longer exists by then.

If all you need is a single statement run in the background (no multiple steps to sequence), skip the
chain entirely and use `kern.DML_Builder.newTransaction().doUpdate(records).async().execute();`. The
[Fast Start - DML](Fast%20Start%20-%20DML.md) covers this.

---

## Tier 2: Build Your Own (~15 minutes)

> **No local project?** You can create classes directly in the Developer Console (Gear Icon > Developer
> Console > File > New > Apex Class) and run tests from there too (Test > New Run). Paste the code, save,
> and skip the terminal commands.

### Step 1: Create the chain step

Build a step that reads an Account Id from the chain context and stamps a Description. You create an empty class
with one command, paste the code into it, then send it to your org.

**1. In the terminal**, from your project's top folder, create the empty class:

```shell
sf apex generate class --name EnrichAccountStep --output-dir force-app/main/default/classes
```

You should see two files created in `force-app/main/default/classes`, both named `EnrichAccountStep`: the class,
ending in `.cls`, and its companion, ending in `.cls-meta.xml`.

The second file tells Salesforce which API version the class uses. You never edit it, but a deploy fails without it.

**2. In your editor**, open this file, delete what is there, paste the code below in, and save:

```text
force-app/main/default/classes/EnrichAccountStep.cls
```

> **Why `global`?** The framework finds your step class by name at runtime, and marking it `global` lets
> it do that with no extra setup. If you prefer `public with sharing`, you'll instead point the framework
> at your classes with a Type Resolver class (how it finds the Apex classes in your namespace: you tell it
> where to look). The Kern home page health check provides the code, or see
> [Type Resolution](Utilities%20-%20Guide.md#type-resolution-util_typeresolver).

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

**3. In the terminal**, send the class to your org:

```shell
sf project deploy start -o YourOrgAlias -m "ApexClass:EnrichAccountStep"
```

You should see `Status: Succeeded`, with `EnrichAccountStep` listed as created.

**Key patterns:**

- `extends kern.UTIL_AsyncChain.ChainStep` pulls in the `work()` contract
- `global override StepResult work(ChainContext)` is the only required method
- Read inputs via `context.get(key)`, and store outputs via `context.put(key, value)`
- Return `kern.UTIL_AsyncChain.succeeded(msg, data)` or `.failed(msg)`. Use
  `.failedPermanently(msg)` for a failure that must never be retried. Never throw
- Declare no constructor: the framework creates the step from its class name on every hop, and from inside the
  package it can only use the constructor Apex provides when you declare none

Something went wrong? See [Common Issues, Step 1](#step-1-create-the-chain-step-1).

### Step 2: Execute the chain

Start a chain that runs your step on a new Account, then read the Account back.

**In Salesforce**, in the Developer Console's Execute Anonymous window, run:

```apex
Account record = new Account(Name = 'Async Demo');
insert record;

String executionId = kern.UTIL_AsyncChain.newChain('AccountEnrichment')
	.withInitialContext(EnrichAccountStep.CONTEXT_KEY_ACCOUNT_ID, record.Id)
	.then(new EnrichAccountStep())
	.execute();

System.debug('Chain executionId: ' + executionId);
```

The log shows a `Chain executionId:` line with the chain's ID.

**In Salesforce**, wait a few seconds, then check the status: in the same window, run this, with the ID the log printed
in place of `PASTE_EXECUTION_ID_HERE`:

```apex
Map<String, Object> status = kern.UTIL_AsyncChain.getStatus('PASTE_EXECUTION_ID_HERE');
System.debug('Status: ' + status.get('status'));
System.debug('Completed: ' + status.get('completedSteps') + '/' + status.get('totalSteps'));
```

You should see these lines in the log:

```text
Status: Completed
Completed: 1/1
```

> **See it in the org:** App Launcher > Kern > **AsyncChainExecution** tab lists every chain with
> status, step counts, duration, and error message. This is the operator view.

**In Salesforce**, query the result in the same window:

```apex
Account result = [SELECT Description FROM Account WHERE Name = 'Async Demo' ORDER BY CreatedDate DESC LIMIT 1];
System.debug('Description: ' + result.Description);
```

You should see this line in the log:

```text
Description: Enriched by Fast Start chain
```

Something went wrong? See [Common Issues, Step 2](#step-2-execute-the-chain-1).

### Step 3: Write and run the test

Both tests run the step through `execute()` rather than calling `work()` directly, because only the
framework can create a `kern.UTIL_AsyncChain.ChainContext`, so you let it run the chain for you. You create the
empty class with one command, paste the code into it, send it to your org, then run it.

**1. In the terminal**, from your project's top folder, create the empty test class:

```shell
sf apex generate class --name EnrichAccountStep_TEST --output-dir force-app/main/default/classes
```

You should see two files created in `force-app/main/default/classes`, both named `EnrichAccountStep_TEST`: the
class, ending in `.cls`, and its companion, ending in `.cls-meta.xml`.

**2. In your editor**, open this file, delete what is there, paste the code below in, and save:

```text
force-app/main/default/classes/EnrichAccountStep_TEST.cls
```

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
@IsTest(seeAllData=false isParallel=true)
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

**3. In the terminal**, send the test class to your org:

```shell
sf project deploy start -o YourOrgAlias -m "ApexClass:EnrichAccountStep_TEST"
```

You should see `Status: Succeeded`, with `EnrichAccountStep_TEST` listed as created.

**4. In the terminal**, run the test:

```shell
sf apex run test -o YourOrgAlias -t EnrichAccountStep_TEST --code-coverage --synchronous --result-format human
```

You should see 2 tests passing and 100% coverage on `EnrichAccountStep`: both tests show `Pass`, the summary line
`Outcome` reads `Passed`, and the coverage table shows `EnrichAccountStep` at `100%`.

> **Why `Test.startTest() / Test.stopTest()`?** Without it, the background job (Queueable) that
> `execute()` enqueues never actually runs inside the test. `Test.stopTest()` forces that queued work to
> run right then. Forgetting this is the single most common chain-test bug.

Something went wrong? See [Common Issues, Step 3](#step-3-write-and-run-the-test-1).

---

## Tier 3: Production Patterns (~5-10 minutes)

**Handlers:** attach steps that run when the chain fails or finishes, so you can react to either outcome.
Inside `onError`, `context.getPreviousStepResult()` returns the failed step's `StepResult` (inspect
`message` / `error`).

**In your editor**, in the code that starts the chain:

```apex
kern.UTIL_AsyncChain.newChain('AccountEnrichment')
	.withInitialContext('accountId', record.Id)
	.then(new EnrichAccountStep())
	.onError(new NotifyAdminStep())
	.onComplete(new EmitMetricStep())
	.execute();
```

Registering `onError` also changes how loudly a stall reports itself. The first time a chain loses its
background job with no `onError` handler registered, the framework records that stall at ERROR level so
it surfaces in the Log Console on its own. Register a handler and the entry drops to WARN, because the
handler is what raises the alarm. A chain the watchdog parks because your org has run out of
background-job capacity stays at WARN whatever handlers it has.

**Continue past optional failures:** pass `true` to `.then()` to let the chain skip over a failed step
and keep going.

**In your editor**, in the code that starts the chain:

```apex
kern.UTIL_AsyncChain.newChain('OrderProcessing')
	.then(new ChargePaymentStep())
	.then(new SendReceiptStep(), true)   // failure here does not stop the chain
	.then(new MarkOrderShippedStep())
	.execute();
```

**Wrap an outbound API call as a step:** `kern.UTIL_AsyncChain.ApiStep` runs any `kern.API_Outbound`
handler for you, handling validation, the callout, parsing the response, saving records, and `kern__ApiCall__c`
logging.

**In your editor**, in the code that starts the chain:

```apex
kern.UTIL_AsyncChain.newChain('OrderConfirmation')
	.withInitialContext('orderId', order.Id)
	.then(new kern.UTIL_AsyncChain.ApiStep(API_ChargePayment.class)
		.triggeringRecordFrom('orderId')
		.withParameter('amount', '99.99'))
	.execute();
```

See [Fast Start - Outbound APIs](Fast%20Start%20-%20Outbound%20APIs.md) for the handler shape.

**Test chains of more than one step:** in a test, Apex only lets `Test.stopTest()` run one background
job by default. Raise that limit with `AsyncOptions` (the platform built-in `System.AsyncOptions`, not a
kern inner class).

**In your editor**, in a test method:

```apex
AsyncOptions options = new AsyncOptions();
options.maximumQueueableStackDepth = 5;

kern.UTIL_AsyncChain.newChain('MultiStep')
	.then(new StepOne()).then(new StepTwo()).then(new StepThree())
	.withAsyncOptions(options)
	.execute();
```

**Re-run a bulk step safely:** if a step loops over many records, derive a per-record key with
`context.idempotencyKey(record.Id)` and store it on the external-id field you `upsert` against. A replay after a partial
failure then only reprocesses the rows that did not finish the first time. See
[Safe to run twice (idempotency)](Async%20Processing%20-%20Guide.md#step-design-guidance) in the guide for the
step-level and custom-grain forms too.

See the [Async Processing Guide](Async%20Processing%20-%20Guide.md) for delayed start, retry strategies, finalizer recovery.

---

## Sensitive data is masked by default

Anything the chain saves to its tracking row (`kern__AsyncChainExecution__c`) is scrubbed of sensitive values
before it is stored, so secrets don't end up sitting in a queryable record. The chain's context data,
step logs, and error messages all pass through the data masking framework first. Out of the box,
`MaskSecretKeys` blanks out common secret JSON keys (`password`, `token`, `apiKey`, etc.) and
`MaskPaymentCard` blanks out card numbers that pass the standard card-number check (Luhn).

There is one consequence to know about. Putting a secret in the context, such as
`context.put('password', userPassword)`, is safe once stored, but the scrubbing is permanent: a later
step that re-reads the saved row sees only the redacted value, not the original. So don't rely on the
chain context to pass credentials between steps for an authenticated callout. Use a Named Credential
instead.

### Clean up

If you built this example only to try the framework, run this command when you have finished the guide. The
`Async Demo` Account the Step 2 block created, and its chain's tracking row, stay; delete them in the app, or leave
them.

**In the terminal**, delete the two classes:

```shell
sf project delete source -o YourOrgAlias -m "ApexClass:EnrichAccountStep_TEST" -m "ApexClass:EnrichAccountStep" --no-prompt
```

You should see `Status: Succeeded`, then a `Deleted Source` table listing the two classes. The command deletes the
files from your project too.

Something went wrong? See [Common Issues](#common-issues).

---

## Common Issues

Trouble with your computer rather than this guide (`sf` is not recognised, scripts are disabled, you are not logged
in, the wrong folder)? Those are answered once, in
[Set Up Your Computer](Set%20Up%20Your%20Computer.md#if-something-went-wrong).

### Step 1: Create the chain step

#### The deploy says there is nothing to deploy

The deploy stops with `No source-backed components present in the package.` The command ran inside another project's
folder, so the CLI looked for the class there and found nothing. Open the terminal in your own project's top folder,
the one that holds `sfdx-project.json`, and run the command again.

### Step 2: Execute the chain

#### The Execute Anonymous window reports a compile error naming `EnrichAccountStep`

The block names your step class, so it cannot run until the class is saved in your org: Step 1's deploy did not run,
or did not succeed. Run the Step 1 deploy, check it prints `Status: Succeeded`, then run the block again.

#### The Description line does not read `Enriched by Fast Start chain`

The chain has not finished, or it failed. Run the status block again: while the chain has not finished, wait a few
seconds and query the Account again. If it reads `Failed`, open the chain in the **AsyncChainExecution** tab: its error
message says why, and the entries below cover the usual ones.

#### The chain fails with `Cannot create step`

The chain's error message starts `Failed (Cannot create step` and names your step class. It means the chain could
not create the step class from its name. The causes you can reach in this guide:

- You added a constructor to the step class. Declare no constructor on the step (a `global` class may declare a
  `global` one).
- Your org has its own namespace and no Type Resolver class finds the step. Register a Type Resolver.
- The step class was declared inside the Execute Anonymous window instead of saved as its own class (the case a run
  of this guide captured). Save the step as its own class, as Step 1 does.

#### The chain's status stays Running

The chain's background job ended without reporting back, so the chain was never marked finished. Check the
`kern__LogEntry__c` rows for the chain's `correlationId`. A scheduled Chain Watchdog marks such runs `Stalled` and
re-drives the safe ones; the Health Check schedules it in one click.

#### The chain's status is Aborted, with the failure category Kill Switch

Chain processing was suspended org-wide when the chain ran (the [kill switch](Async%20Processing%20-%20Guide.md#kill-switch)).
Resume processing from the Chain Monitor's operations control, then restart or re-drive the chains that were stopped.

### Step 3: Write and run the test

#### A test assertion fails because the Description was never stamped

`Test.startTest()` / `Test.stopTest()` is missing around `execute()`. Wrap the chain build and execute in
`Test.startTest/stopTest`, as both test methods in this step do.

### Tier 3: Production Patterns (~5-10 minutes)

#### A chain test runs only the first step

The default `maximumQueueableStackDepth` is 1 in tests. Pass `.withAsyncOptions(options)` with
`maximumQueueableStackDepth` raised.

#### `context.get()` returns null

The value is not JSON-serialisable, or the key's spelling does not match. Store only Ids, primitives, and simple
collections; check the key.

#### A second `.execute()` on the same builder throws

The code reuses a `ChainBuilder` after `.execute()`. Build a fresh chain with `kern.UTIL_AsyncChain.newChain(...)`.

Still stuck? [Tell us](https://github.com/JVB-Consulting/kerndx/issues/new?template=bug_report.md&title=%5Bdocs%5D%20Async%20Processing) which step and what you saw.

## What You Now Know

- **`kern.UTIL_AsyncChain.newChain(name)`** is the entry point that returns a `ChainBuilder`
- **`kern.UTIL_AsyncChain.ChainStep`** is the base you extend; implement `work(ChainContext)` and return
  `kern.UTIL_AsyncChain.succeeded(...)` or `.failed(...)` rather than throwing
- **`ChainContext`** carries shared state across transactions via `get` / `put` / `has`; use
  `getPreviousStepResult()` in handler steps
- **`kern__AsyncChainExecution__c`** is the tracking row (status, step counts, error message), kept and
  queryable from anywhere
- **`kern.UTIL_AsyncChain.ApiStep`** runs a `kern.API_Outbound` handler as a chain step
- **Step classes declare no constructor**, because the framework creates them from their class name at
  runtime across the package namespace boundary and can only use the constructor Apex provides when
  none is declared (`public` is fine; a `global` class may declare a `global` constructor)
- **`Test.startTest() / Test.stopTest()`** forces the queued background job to run; raise
  `AsyncOptions.maximumQueueableStackDepth` for chains of more than one step under test
- **Use `kern.DML_Builder.async()`** for single-statement background work; use a chain only when you
  need several steps in sequence, each with its allowances reset

---

## Next Steps

- [Outbound HTTP calls](Fast%20Start%20-%20Outbound%20APIs.md)
- [DML Builder (sync and async)](Fast%20Start%20-%20DML.md)
- [Logging and correlation](Fast%20Start%20-%20Logging.md)
- [Feature flag gating](Fast%20Start%20-%20Feature%20Flags.md)
- [Scheduled jobs and the job runner](Fast%20Start%20-%20Scheduled%20Jobs.md)
- [Complete async reference](Async%20Processing%20-%20Guide.md)
- [`UTIL_AsyncChain` API](reference/apex/UTIL_AsyncChain.md)
