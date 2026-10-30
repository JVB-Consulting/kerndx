---
navOrder: 34
---

# Async Processing - Guide

**Framework:** KernDX
**Package Type:** Managed Package

> **Namespaces in code samples:** `kern.` on a class and `kern__` on an object, field, or metadata type mark the managed package's namespace.
> On the managed package, framework references need those prefixes even where a sample omits them; repackaged under your own namespace, replace `kern`/`kern__`
> with your prefix; on an unmanaged deploy, drop them. See [How to read the code samples](Installation.md#how-to-read-the-code-samples).

**Target Audience:**

- **Developers** - Building schedulable jobs, batch processing, and asynchronous operations with automatic strategy selection
- **Architects** - Designing scalable async processing patterns with governor limit awareness and adaptive execution
- **Business Analysts** - Understanding scheduled job configuration, execution strategies, and monitoring capabilities

---

## What problem does this solve?

Some background work is too big or too slow to run while a user waits: processing tens of thousands of records, calling
external systems, or running on a nightly schedule. Salesforce gives you three separate tools for this, and choosing the
right one (and switching between them as data volumes change) is a recurring source of bugs and governor-limit failures.

This framework lets you write your processing logic once and have it run at the right scale automatically. It picks
Queueable, Batch, or parallel execution for you, based on how many records there are and how close you are to platform
limits.

Read it if you build background jobs, design for governor-limit safety, or configure and monitor scheduled jobs. Use it
for asynchronous record processing, multi-step workflows, and recurring scheduled jobs.

---

## Mental model

Think of the framework as a freight dispatcher at a depot. You hand it the cargo (your records) and the job to do; it
looks at how much there is and how much capacity is free right now, then chooses whether to send a few fast vans
(parallel Queueables), a relay of vans passing the load along (chained Queueables), or one big lorry (Batch Apex). You
describe the work once; the dispatcher decides how to move it.

---

## Use this when

- The work is too large or slow to finish while a user waits, and you don't want to hand-pick Queueable versus Batch as
  data volumes change.
- You need a job to run on a recurring schedule, and you want admins to create or change those schedules as
  configuration records rather than through a code deployment.
- You have a multi-step workflow where each phase needs its own fresh set of governor limits (load, then transform, then
  notify).
- You want every async run traceable: the same tracking ID across triggers, queries, callouts, and jobs, plus a
  searchable record of what happened.
- Several developers work on background jobs and you want them all following one pattern instead of inventing their own.

## Don't use this when

- The operation is small and synchronous (under 100 records) and finishes well within governor limits. Plain Apex is
  simpler.
- A declarative Scheduled Flow already handles the recurring job without code. Use it; it is less to maintain.
- You need a one-off batch or queueable you will never reuse, or you want full custom control over `start` / `execute` /
  `finish`. The platform's own Batch and Queueable patterns are a better fit, and the framework never blocks you from
  using them directly (see [How to opt out](#how-to-opt-out)).

---

## Table of Contents

<details>
<summary>Expand</summary>

1. [What problem does this solve?](#what-problem-does-this-solve)
2. [Mental model](#mental-model)
3. [Use this when](#use-this-when)
4. [Don't use this when](#dont-use-this-when)
5. [Quick Navigation](#quick-navigation)
6. [Quick Start](#quick-start)
7. [Why choose this over the built-in option?](#why-choose-this-over-the-built-in-option)
8. [What are the moving parts?](#what-are-the-moving-parts)
9. [How to opt out](#how-to-opt-out)
10. [KernDX vs OOTB: Async Framework Comparison](#kerndx-vs-ootb-async-framework-comparison)
    - [Salesforce Out-of-the-Box Alternative](#salesforce-out-of-the-box-alternative)
    - [Pros & Cons Comparison](#pros--cons-comparison)
    - [When to Use KernDX Async Framework](#when-to-use-kerndx-async-framework)
    - [When to Use OOTB Batch/Queueable](#when-to-use-ootb-batchqueueable)
    - [Example Comparison](#example-comparison)
11. [How does it work?](#how-does-it-work)
    - [System Architecture Diagram](#system-architecture-diagram)
    - [Execution Strategy Flow](#execution-strategy-flow)
    - [Execution Strategy Comparison](#execution-strategy-comparison)
12. [Architecture Decision Guide](#architecture-decision-guide)
    - [When to Use This Framework](#when-to-use-this-framework)
    - [Framework Selection Matrix (for Architects)](#framework-selection-matrix-for-architects)
13. [How do I write the processing logic?](#how-do-i-write-the-processing-logic)
    - [Interface Hierarchy](#interface-hierarchy)
    - [IF_Async.Processable (Required)](#if_asyncprocessable-required)
    - [IF_Async.Finishable (Optional)](#if_asyncfinishable-optional)
14. [Async Chain Orchestration](#async-chain-orchestration)
    - [When to Use Chains](#when-to-use-chains)
    - [Architecture](#architecture)
    - [Building Steps](#building-steps)
    - [Chain Builder API](#chain-builder-api)
    - [Context Sharing](#context-sharing)
    - [Error Handling](#error-handling)
    - [Retrying a failed step](#retrying-a-failed-step)
    - [Preventing duplicate runs](#preventing-duplicate-runs)
    - [Monitoring](#monitoring)
    - [What happens to a stalled step?](#what-happens-to-a-stalled-step)
    - [Stopping a chain from the Chain Monitor](#stopping-a-chain-from-the-chain-monitor)
    - [Re-driving a failed chain](#re-driving-a-failed-chain)
    - [Restarting a chain from the start](#restarting-a-chain-from-the-start)
    - [Clearing stalled chains](#clearing-stalled-chains)
    - [The operations control](#the-operations-control)
    - [The live activity stream](#the-live-activity-stream)
    - [Logging Strategy](#logging-strategy)
    - [Log Correlation](#log-correlation)
    - [Step Design Guidance](#step-design-guidance)
    - [Kill Switch](#kill-switch)
    - [ApiStep: Web Service Integration](#apistep-web-service-integration)
        - [Basic Usage](#basic-usage)
        - [Builder Methods](#builder-methods)
        - [Reading Results from Downstream Steps](#reading-results-from-downstream-steps)
        - [Standalone vs. Chain Execution](#standalone-vs-chain-execution)
        - [Error Handling](#error-handling-1)
    - [Testing Chains](#testing-chains)
15. [Common Patterns](#common-patterns)
    - [Protecting a struggling integration with a circuit breaker](#protecting-a-struggling-integration-with-a-circuit-breaker)
    - [Pausing for an approval: two chains and a hand-off](#pausing-for-an-approval-two-chains-and-a-hand-off)
    - [Running a chain on a schedule](#running-a-chain-on-a-schedule)
    - [Calling an external system only after the transaction commits](#calling-an-external-system-only-after-the-transaction-commits)
16. [Scheduler Framework](#scheduler-framework)
    - [Scheduler Architecture](#scheduler-architecture)
    - [Declarative Scheduling with ScheduledJob__c](#declarative-scheduling-with-scheduledjob__c)
        - [How It Works](#how-it-works)
        - [ScheduledJob__c Fields](#scheduledjob__c-fields)
        - [Example: Create a Purge Job via UI](#example-create-a-purge-job-via-ui)
        - [Common Cron Expressions](#common-cron-expressions)
        - [Timezone Awareness](#timezone-awareness)
    - [Running many jobs on one job runner](#running-many-jobs-on-one-job-runner)
    - [Built-in Schedulers](#built-in-schedulers)
    - [Creating Custom Configurable Schedulers](#creating-custom-configurable-schedulers)
17. [Transaction Correlation in Async Operations](#transaction-correlation-in-async-operations)
    - [Why Correlation Matters](#why-correlation-matters)
    - [Correlation Flow](#correlation-flow)
    - [Queueable Pattern with Correlation](#queueable-pattern-with-correlation)
    - [Batch Apex Pattern with Correlation](#batch-apex-pattern-with-correlation)
    - [Key Correlation Methods](#key-correlation-methods)
18. [Capability Matrix (for Analysts)](#capability-matrix-for-analysts)
    - [What Can Be Scheduled?](#what-can-be-scheduled)
    - [Configuration Reference: SCHED_PurgeRecords](#configuration-reference-sched_purgerecords)
    - [Configuration Reference: SCHED_DeactivateUsers](#configuration-reference-sched_deactivateusers)
19. [Monitoring and Troubleshooting](#monitoring-and-troubleshooting)
    - [Monitoring Scheduled Jobs](#monitoring-scheduled-jobs)
    - [Monitoring Async Job Execution](#monitoring-async-job-execution)
    - [Monitoring Async Chain Failures](#monitoring-async-chain-failures)
    - [Expected entries in your debug logs](#expected-entries-in-your-debug-logs)
20. [Testing](#testing)
21. [Common Pitfalls](#common-pitfalls)
22. [Anti-Patterns](#anti-patterns)
23. [Best Practices](#best-practices)
    - [For Developers](#for-developers)
    - [Choosing a Batch Size](#choosing-a-batch-size)
    - [For Architects](#for-architects)
    - [For Administrators](#for-administrators)
24. [Related Documentation](#related-documentation)
25. [Summary](#summary)

</details>

---

## Quick Navigation

| I am a...     | I need to...                      | Go to...                                                                   |
|---------------|-----------------------------------|----------------------------------------------------------------------------|
| **Architect** | Decide when to use async patterns | [Architecture Decision Guide](#architecture-decision-guide)                |
| **Architect** | Compare with OOTB Batch/Queueable | [KernDX vs OOTB](#kerndx-vs-ootb-async-framework-comparison)               |
| **Developer** | Process records asynchronously    | [Quick Start](#quick-start)                                                |
| **Developer** | Create a scheduled job            | [Scheduler Framework](#scheduler-framework)                                |
| **Developer** | Implement custom processing       | [Processing logic](#how-do-i-write-the-processing-logic)                   |
| **Developer** | Build multi-step async workflows  | [Async Chain Orchestration](#async-chain-orchestration)                    |
| **Developer** | Reuse proven chain patterns       | [Common Patterns](#common-patterns)                                        |
| **Analyst**   | Know what's available             | [Capability Matrix](#capability-matrix-for-analysts)                       |
| **Analyst**   | Configure scheduled jobs          | [ScheduledJob Configuration](#declarative-scheduling-with-scheduledjob__c) |

---

## Quick Start

To process records in the background, you write one class that holds your logic and hand it to the launcher. Put your
logic in a class that implements `IF_Async.Processable`, then launch it with `UTIL_AsynchronousJobLauncher`. The
framework picks the right execution strategy for you.

> **Step-by-step walkthrough:** [Fast Start - Async Processing](Fast%20Start%20-%20Async%20Processing.md) covers implementation,
> testing, and common pitfalls.

```apex
public with sharing class MyProcessor implements IF_Async.Processable
{
	public void execute(List<Object> items)
	{
		List<Account> accounts = (List<Account>)items;
		for(Account account : accounts)
		{
			account.Description = 'Processed: ' + DateTime.now();
		}
		DML_Builder.newTransaction().doUpdate(accounts).execute();
	}
}

// Launch
Id jobId = UTIL_AsynchronousJobLauncher.process(records, new MyProcessor());
```

For deeper coverage, continue reading the sections below.

---

## Why choose this over the built-in option?

The three Salesforce tools this framework sits on top of are
[Queueable](https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_queueing_jobs.htm),
[Batch Apex](https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_batch_interface.htm), and
[Scheduled Apex](https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_scheduler.htm). The native
tools are entirely usable on their own. ("Governor limits" are the platform's per-transaction caps on how much work Apex
can do at once.) What the framework adds is this:

- **It picks Queueable or Batch for you, by volume.** You don't guess the right tool upfront or rewrite the call when
  data grows: the same code keeps working as volumes change.
- **One entry point launches complex async work.** A single method call replaces hand-wiring each native mechanism.
- **Multi-step workflows share data and survive limits.** Chains run phases in order, pass data between steps, carry
  built-in error and completion handlers, and keep a durable record of progress.
- **An existing outbound integration becomes a chain step unchanged.** `ApiStep` wraps any `API_Outbound` handler with no
  edits to that handler.
- **You can watch a run happen.** The Chain Monitor UI shows live updates, a step-by-step timeline, and error detail
  panels, with a **View logs** button that jumps to the run's correlated logs in the Log Console.
- **Admins change a job's parameters without touching code.** Configurable schedulers read their settings from a record.
- **Errors and logs look the same everywhere.** One consistent pattern across every async strategy, instead of one per
  mechanism.
- **It stays inside the platform's per-transaction caps automatically.** Governor-limit awareness is built in, so you
  don't track those limits by hand.
- **Tests can control async behaviour.** Built-in test support lets you drive async work from `@IsTest` code.

For the cases where the native tools are the better choice (a one-off job, full control over `start` / `execute` /
`finish`, or avoiding even a thin layer), see the full comparison in
[KernDX vs OOTB](#kerndx-vs-ootb-async-framework-comparison) and
[How to opt out](#how-to-opt-out).

---

## What are the moving parts?

The framework is made up of six pieces that work together:

1. **[`UTIL_AsynchronousJobLauncher`](reference/apex/UTIL_AsynchronousJobLauncher.md)** is the entry point: one place to launch async jobs, with the right strategy chosen for you.
2. **[`IF_Async.Processable`](reference/apex/IF_Async.Processable.md)** is the interface where you put your processing logic.
3. **`UTIL_AdaptiveAsynchronousProcessor`** is the engine that picks parallel Queueables, chained Queueables or Batch Apex, based on data volume and the free Queueable slots. The framework drives it for you.
4. **[`UTIL_AsyncChain`](reference/apex/UTIL_AsyncChain.md)** runs multi-step workflows that share data, track progress, and have error and completion handlers, including a built-in [`ApiStep`](reference/apex/UTIL_AsyncChain.ApiStep.md) web service bridge.
5. **[`IF_Schedulable`](reference/apex/IF_Schedulable.md)** is the interface for configurable scheduled jobs that accept parameters, managed through [`ScheduledJob__c`](reference/objects/ScheduledJob__c.md) records.
6. **`CTRL_ChainMonitor`** powers the real-time Chain Monitor UI (4 LWC components: `chainMonitor`, `chainMonitorList`, `chainMonitorDetail`, `chainStepTimeline`), with live updates,
   a step timeline, and error detail panels.

> **Responsibilities:** The Async framework launches and manages long-running or deferred work. It does not contain the
> business logic itself: that belongs in your `Processable` implementation. It does not query data either; you pass
> records or a `Builder` to the launcher.

> **Async Framework Scope:** Adaptive strategy selection (Queueable vs Batch), chain orchestration with shared context and `ApiStep` web service bridge, declarative scheduling via
`ScheduledJob__c`, real-time Chain Monitor UI, and four pre-built schedulable reference implementations (`SCHED_DeactivateUsers`, `SCHED_PerformBatchedCallouts`,
`SCHED_ProcessLoginHistory`, `SCHED_PurgeRecords`) extending the abstract `SCHED_Base`.

> **Declarative scheduling:** Configure recurring jobs entirely through [`ScheduledJob__c`](reference/objects/ScheduledJob__c.md)
> records. Set a class name and a cron expression, then activate. No code deployment is needed to schedule, reschedule, or
> deactivate jobs.

---

## How to opt out

Sometimes you want to step outside the framework and use Salesforce's own async tools directly. You can, at any time:
the framework never takes that control away from you.

The framework offers three execution strategies and switches between them automatically. `UTIL_AsyncChain` is just
**one** of your options, meant for sequenced, dependent work that shares state from step to step. Running jobs in
parallel is a separate, equally supported strategy. The table below maps each thing you might want to do to the
direct route that gives it to you.

| You need                                                                         | Use                                                                                                                                                                    | See                                                                       |
|----------------------------------------------------------------------------------|------------------------------------------------------------------------------------------------------------------------------------------------------------------------|---------------------------------------------------------------------------|
| **Parallel Queueables** (multiple jobs running concurrently)                     | `UTIL_AsynchronousJobLauncher.process()` auto-selects `PARALLEL_QUEUEABLES` when the per-transaction Queueable limit allows.                                           | [Execution Strategy Comparison](#execution-strategy-comparison)           |
| **Direct `System.enqueueJob()`** for an independent Queueable                    | Works unchanged. Nothing intercepts `enqueueJob`. You freely write `implements Queueable` and enqueue independently of any chain.                            | [Queueable Pattern with Correlation](#queueable-pattern-with-correlation) |
| **Native `Database.Batchable` / `Database.Stateful`**                            | Write your own batch class as you always would. There is no mandatory base class. The framework's `IF_Async.Processable` interface is optional.                                 | [When to Use OOTB Batch/Queueable](#when-to-use-ootb-batchqueueable)      |
| **Change Data Capture / Platform Event triggers**                                | You write `trigger MyTrigger on Account__ChangeEvent` directly. Framework code calls `EventBus.publishWithAccessLevel()` without wrapping your triggers. | —                                                                         |
| **Force a specific execution strategy** instead of letting the dispatcher choose | `IF_Async.AsynchronousExecutionStrategy` enum exposes `PARALLEL_QUEUEABLES`, `CHAINABLE`, `BATCH`; pass the one you want to the launcher.                                           | [Execution Strategy Comparison](#execution-strategy-comparison)           |
| **Per-transaction Queueable limit awareness for adaptive degradation**           | The adaptive processor reads `UTIL_Limits.queueableJobs().remaining()` and steps down PARALLEL → CHAINABLE → BATCH automatically as slots run low.                                        | [Execution Strategy Flow](#execution-strategy-flow)                       |

A reminder on scope: `UTIL_AsyncChain` is for one specific pattern, sequenced steps that depend on each other and share
context across transactions. It is the wrong tool for parallel work, but that does not mean parallel work is unavailable.
The framework names the right tool for that case (`PARALLEL_QUEUEABLES`) explicitly.

---

## KernDX vs OOTB: Async Framework Comparison

### Salesforce Out-of-the-Box Alternative

Salesforce provides
**[Batch Apex](https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_batch_interface.htm)**,
**[Queueable Apex](https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_queueing_jobs.htm)**,
and **[Scheduled Apex](https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_scheduler.htm)**
as standard async mechanisms:

```apex
// OOTB Batch Apex
public class MyBatch implements Database.Batchable<SObject> {
    public Database.QueryLocator start(Database.BatchableContext ctx) {
        return Database.getQueryLocator('SELECT Id FROM Account');
    }
    public void execute(Database.BatchableContext ctx, List<Account> scope) {
        // Process accounts
    }
    public void finish(Database.BatchableContext ctx) { }
}

// OOTB Queueable Apex
public class MyQueueable implements Queueable {
    public void execute(QueueableContext ctx) {
        // Process data
    }
}
```

### Pros & Cons Comparison

The framework adds convenience and consistency; the native tools win on simplicity and raw control. The full
feature-by-feature breakdown is below.

<details>
<summary>Full feature comparison</summary>

| Feature                     | KernDX Async Framework                                                                 | Salesforce OOTB Batch/Queueable                    |
|-----------------------------|----------------------------------------------------------------------------------------|----------------------------------------------------|
| **Auto Strategy Selection** | AUTO mode chooses optimal approach                                                     | Developer must decide upfront                      |
| **Unified API**             | One interface for Batch & Queueable                                                    | Different interfaces (Batchable vs Queueable)      |
| **Declarative Scheduling**  | [`ScheduledJob__c`](reference/objects/ScheduledJob__c.md) custom object                | Requires code deployment                           |
| **Configurable Jobs**       | [`IF_Schedulable`](reference/apex/IF_Schedulable.md) with parameter definitions        | Must hard-code or use custom settings              |
| **Parallel Queueables**     | `PARALLEL_QUEUEABLES` strategy                                                         | Manual enqueue loop required                       |
| **Chained Queueables**      | `CHAINABLE` with auto-chaining                                                         | Manual chaining in execute()                       |
| **Error Events**            | Queueable crashes are captured by a finalizer the framework attaches to every Queueable it runs, and batch crashes by a listener on the platform's `BatchApexErrorEvent` (your own batch classes included, when they implement `Database.RaisesPlatformEvents`); both land as durable `LogEntry__c` rows     | Native Batch fires `BatchApexErrorEvent`; Queueables surface nothing unless you write a Finalizer yourself, which the `sf template generate apex class --template Queueable` scaffold includes |
| **Finalisation**            | [`IF_Async.Finishable`](reference/apex/IF_Async.Finishable.md) works for both          | Only Batch has finish(), Queueable needs Finalizer |
| **Log Correlation**         | [`LOG_Builder`](reference/apex/LOG_Builder.md) `serializeContext()`/`hydrateContext()` | Must implement manually                            |
| **Query-Based Processing**  | Pass [`QRY_Builder.Builder`](reference/apex/QRY_Builder.md)                            | `Database.QueryLocator` in Batch                   |
| **Callout Support**         | `Database.AllowsCallouts` included                                                     | Must add interface manually                        |
| **Test Support**            | `AsyncOptions` for controlled testing                                                  | Standard Test.startTest()/stopTest()               |
| **Simplicity**              | Requires learning framework                                                            | Standard Salesforce patterns                       |
| **Learning Curve**          | Framework-specific knowledge                                                           | Standard Apex knowledge                            |
| **Performance**             | A thin layer over the platform's own execution                                                             | Direct platform execution                          |
| **Flexibility**             | Must use framework patterns                                                            | Full control over implementation                   |

</details>

### When to Use KernDX Async Framework

- **Variable data volumes.** The framework auto-selects Queueable vs Batch, so the same code keeps working as data grows.
- **Reusable processing logic.** One processor works across every strategy.
- **Declarative job management.** Admins manage schedules through [`ScheduledJob__c`](reference/objects/ScheduledJob__c.md) records, no code deployment.
- **Log correlation required.** Trace async operations back to where they started via [`LOG_Builder`](reference/apex/LOG_Builder.md).
- **Parallel queueable patterns.** The framework handles chunking and enqueuing for you.
- **Consistent error handling.** You get the same standardised error events everywhere.
- **Multiple developers.** Everyone follows the same pattern instead of inventing their own.
- **Long-running applications that need full lifecycle management** (launch, monitor, finalise, and reschedule in one place).

### When to Use OOTB Batch/Queueable

- **Simple one-off jobs.** A basic batch or queueable you won't reuse.
- **Maximum control.** You need custom start, execute, or finish behaviour.
- **Performance critical.** You want to avoid even a thin framework layer.
- **Stateful batch.** You need `Database.Stateful` to keep state across batches.
- **Custom chaining logic.** Your chaining has involved conditional rules.
- **Few async jobs.** A small codebase where shared conventions add little.
- **Team preference.** Your developers prefer working with the platform's patterns directly.

### Example Comparison

**OOTB Batch Apex (Verbose, Separate Classes):**

```apex
// AccountProcessor.cls - Batch implementation
public class AccountProcessor implements Database.Batchable<SObject>
{
	public Database.QueryLocator start(Database.BatchableContext context)
	{
		return Database.getQueryLocator('SELECT Id, Name FROM Account WHERE Industry = \'Technology\'');
	}

	public void execute(Database.BatchableContext context, List<Account> scope)
	{
		for(Account account : scope)
		{
			account.Description = 'Processed: ' + DateTime.now();
		}
		update scope;
	}

	public void finish(Database.BatchableContext context)
	{
		// Send notification email
		Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
		email.setSubject('Batch Complete');
		email.setToAddresses(new List<String>{'admin@company.com'});
		email.setPlainTextBody('Job finished: ' + context.getJobId());
		Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{email});
	}
}

// AccountQueueable.cls - Separate Queueable for small datasets
public class AccountQueueable implements Queueable
{
	private List<Account> accounts;

	public AccountQueueable(List<Account> accounts)
	{
		this.accounts = accounts;
	}

	public void execute(QueueableContext context)
	{
		for(Account account : accounts)
		{
			account.Description = 'Processed: ' + DateTime.now();
		}
		update accounts;
	}
}

// Caller must decide which to use:
if(accounts.size() > 200)
{
	Database.executeBatch(new AccountProcessor(), 200);
}
else
{
	System.enqueueJob(new AccountQueueable(accounts));
}
```

**KernDX Async Framework (Unified, Reusable):**

```apex
// AccountProcessor.cls - One class works for both Batch and Queueable
public with sharing class AccountProcessor implements
	IF_Async.Processable,
	IF_Async.Finishable
{
	public void execute(List<Object> items)
	{
		List<Account> accounts = (List<Account>)items;
		for(Account account : accounts)
		{
			account.Description = 'Processed: ' + DateTime.now();
		}
		DML_Builder.newTransaction().doUpdate(accounts).execute();
	}

	public void finish(Database.BatchableContext context)
	{
		Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
		email.setSubject('Processing Complete');
		email.setToAddresses(new List<String>{'admin@company.com'});
		email.setPlainTextBody('Job finished: ' + context.getJobId());
		Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{email});
	}
}

// Framework auto-selects strategy - no decision needed:
List<Account> accounts = QRY_Builder.selectFrom(Account.SObjectType)
	.fields(new List<SObjectField>{Account.Name, Account.Description})
	.condition(Account.Industry).equals('Technology')
	.toList();
Id jobId = UTIL_AsynchronousJobLauncher.process(accounts, new AccountProcessor());
// From any context: no free Queueable slot, or (for a query) no query room left -> BATCH Apex
// From an async job (Queueable, Batch, future) with a slot free -> CHAINABLE queueables
// From synchronous code with a slot free:
//   More items than limitAtWhichToBatch -> BATCH Apex
//   Items fit the free Queueable slots -> PARALLEL_QUEUEABLES (fastest)
//   Too few free slots for the items -> CHAINABLE queueables
```

**Key Differences:**

- **OOTB:** Two separate classes, manual strategy selection, duplicate logic
- **KernDX:** One processor class, automatic strategy selection, reusable logic

---

## How does it work?

### System Architecture Diagram

```text
+----------------------------------------------------------------------------------+
|                         ASYNCHRONOUS OPERATIONS FRAMEWORK                        |
+----------------------------------------------------------------------------------+
|                                                                                  |
|  +------------------------------------------------------------------------+      |
|  |                        ENTRY POINTS (Choose One)                       |      |
|  +------------------------------------------------------------------------+      |
|  |                                                                        |      |
|  |   +------------------+    +------------------+    +-----------------+  |      |
|  |   |  UTIL_Async-     |    |  ScheduledJob__c |    |   System.       |  |      |
|  |   |  JobLauncher     |    |  (Declarative)   |    |   schedule()    |  |      |
|  |   |                  |    |                  |    |   (Programmatic)|  |      |
|  |   |  * Ad-hoc jobs   |    |  * Recurring     |    |  * One-off      |  |      |
|  |   |  * Trigger-based |    |  * UI-managed    |    |  * Script-based |  |      |
|  |   |  * API-initiated |    |  * No deployment |    |  * Full control |  |      |
|  |   +--------+---------+    +--------+---------+    +--------+--------+  |      |
|  |            |                       |                       |           |      |
|  +------------+-----------------------+-----------------------+-----------+      |
|               |                       |                       |                  |
|               v                       v                       v                  |
|  +------------------------------------------------------------------------+      |
|  |                         PROCESSING ENGINE                              |      |
|  +------------------------------------------------------------------------+      |
|  |                                                                        |      |
|  |   +----------------------------------------------------------------+  |      |
|  |   |            UTIL_AdaptiveAsynchronousProcessor                  |  |      |
|  |   |                                                                |  |      |
|  |   |   +---------------------------------------------------------+ |  |      |
|  |   |   |              STRATEGY SELECTION (AUTO mode)              | |  |      |
|  |   |   |                                                         | |  |      |
|  |   |   |   No Queueable slot free ----> BATCH                    | |  |      |
|  |   |   |   or, for a query, no query     (Batch Apex)            | |  |      |
|  |   |   |   room left                                             | |  |      |
|  |   |   |                                                         | |  |      |
|  |   |   |   Already in an async job ----> CHAINABLE               | |  |      |
|  |   |   |   (Queueable, Batch, future)    (Sequential queueables) | |  |      |
|  |   |   |                                                         | |  |      |
|  |   |   |   Synchronous, items > -------> BATCH                   | |  |      |
|  |   |   |   limitAtWhichToBatch           (Batch Apex)            | |  |      |
|  |   |   |                                                         | |  |      |
|  |   |   |   Synchronous, items <= ------> PARALLEL_QUEUEABLES     | |  |      |
|  |   |   |   limitAtWhichToBatch, and      (Fastest - concurrent)  | |  |      |
|  |   |   |   enough free Queueable slots                           | |  |      |
|  |   |   |   for items / queueableJobSize                          | |  |      |
|  |   |   |                                                         | |  |      |
|  |   |   |   Synchronous, items <= ------> CHAINABLE               | |  |      |
|  |   |   |   limitAtWhichToBatch, but      (Sequential queueables) | |  |      |
|  |   |   |   too few free slots                                    | |  |      |
|  |   |   +---------------------------------------------------------+ |  |      |
|  |   +----------------------------------------------------------------+  |      |
|  |                                                                        |      |
|  +------------------------------------------------------------------------+      |
|                                                                                  |
|  +------------------------------------------------------------------------+      |
|  |                         YOUR BUSINESS LOGIC                            |      |
|  +------------------------------------------------------------------------+      |
|  |                                                                        |      |
|  |   +----------------------+         +----------------------+            |      |
|  |   |   Processable    |         |   Finishable     |            |      |
|  |   |                      |         |   (Optional)         |            |      |
|  |   |   execute(items)     |         |   finish(context)    |            |      |
|  |   |                      |         |                      |            |      |
|  |   |   Your processing    |         |   Cleanup, notify,   |            |      |
|  |   |   logic goes here    |         |   chain next job     |            |      |
|  |   +----------------------+         +----------------------+            |      |
|  |                                                                        |      |
|  +------------------------------------------------------------------------+      |
|                                                                                  |
+----------------------------------------------------------------------------------+
```

### Execution Strategy Flow

```text
                              +-------------------+
                              |   START JOB       |
                              |   .process()      |
                              +--------+----------+
                                       |
                                       v
                         +-------------------------+
                         |  Strategy = AUTO?       |
                         +------------+------------+
                                      |
                    +-----------------+------------------+
                    | YES             |                  | NO
                    v                 |                  v
        +-------------------+        |      +-------------------+
        | Query-based?      |        |      | Use specified     |
        +---------+---------+        |      | strategy directly |
                  |                  |      +-------------------+
         +--------+--------+        |
         | YES             | NO     |
         v                 v        |
   +----------+    +---------------+|
   |Can query?|    | Count items   ||
   |(limits)  |    |               ||
   +----+-----+    +-------+------+ |
        |                  |        |
   NO   | YES              |        |
   -----+                  |        |
        |                  v        |
        |     +--------------------+|
        |     |Items > threshold?  ||
        |     |(default: 50,000)   ||
        |     +---------+----------+|
        |               |           |
        |    +----------+----------+|
        |    | YES                 || NO
        v    v                     v|
   +-----------+         +-------------------+
   |   BATCH   |         | Queueable slots   |
   |   APEX    |         | available?        |
   +-----------+         +---------+---------+
                                   |
                        +----------+----------+
                        | YES                 | NO
                        v                     v
               +-----------------+    +-------------+
               | Enough for all? |    |   BATCH     |
               +--------+--------+    |   APEX      |
                        |             +-------------+
             +----------+----------+
             | YES                 | NO
             v                     v
    +-----------------+   +-----------------+
    |    PARALLEL     |   |   CHAINABLE     |
    |   QUEUEABLES    |   |   QUEUEABLES    |
    |  (concurrent)   |   |  (sequential)   |
    +-----------------+   +-----------------+
```

### Execution Strategy Comparison

| Strategy                | Execution Pattern                       | Best For                          | Limits                            |
|-------------------------|-----------------------------------------|-----------------------------------|-----------------------------------|
| **PARALLEL_QUEUEABLES** | Multiple queueables run concurrently    | Small datasets, fastest execution | Max 50 queueables per transaction |
| **CHAINABLE**           | Sequential queueables, each chains next | Medium datasets, async context    | 1 child per queueable             |
| **BATCH**               | Batch Apex with configurable scope      | Large datasets, query-based       | 5 concurrent batches              |

---

## Architecture Decision Guide

### When to Use This Framework

```text
+------------------------------------------------------------------------------+
|                        SHOULD I USE ASYNC PROCESSING?                        |
+------------------------------------------------------------------------------+

                    +---------------------------------+
                    |  How many records to process?   |
                    +----------------+----------------+
                                     |
              +----------------------+----------------------+
              |                      |                      |
         < 200 records          200-10,000             > 10,000
              |                      |                      |
              v                      v                      v
    +-----------------+    +-----------------+    +-----------------+
    | Consider sync   |    | Use framework   |    | Use framework   |
    | processing      |    | with AUTO       |    | with BATCH      |
    | (if fast enough)|    | strategy        |    | strategy        |
    +-----------------+    +-----------------+    +-----------------+

                    +---------------------------------+
                    |  Is this a recurring operation? |
                    +----------------+----------------+
                                     |
                    +----------------+----------------+
                    | YES                             | NO
                    v                                 v
          +-----------------+               +-----------------+
          | Use ScheduledJob|               | Use UTIL_Async- |
          | (declarative)   |               | JobLauncher     |
          | or SCHED_* class|               | (ad-hoc)        |
          +-----------------+               +-----------------+
```

### Framework Selection Matrix (for Architects)

| Scenario                             | Recommended Approach                                  | Why                                                  |
|--------------------------------------|-------------------------------------------------------|------------------------------------------------------|
| **Trigger processing > 200 records** | [`UTIL_AsynchronousJobLauncher`][ujl] with AUTO       | Offload heavy processing, avoid trigger timeouts     |
| **Nightly data cleanup**             | [`ScheduledJob__c`][js] + [`SCHED_PurgeRecords`][spr] | Declarative, no code deployment for schedule changes |
| **API response processing**          | [`UTIL_AsynchronousJobLauncher`][ujl] with BATCH      | Handle large API responses reliably                  |
| **User-initiated bulk action**       | [`UTIL_AsynchronousJobLauncher`][ujl] with AUTO       | Fast for small sets, scales for large                |
| **Integration sync (hourly)**        | [`ScheduledJob__c`][js] + custom `SCHED_*`            | Configurable, monitorable                            |
| **One-time data migration**          | [`UTIL_AsynchronousJobLauncher`][ujl] with BATCH      | Maximum throughput, query-based                      |
| **Email campaign processing**        | [`UTIL_AsynchronousJobLauncher`][ujl] + callouts      | Handles callout limits per transaction               |

[ujl]: reference/apex/UTIL_AsynchronousJobLauncher.md

[js]: reference/objects/ScheduledJob__c.md

[spr]: reference/apex/SCHED_PurgeRecords.md

---

## How do I write the processing logic?

### Interface Hierarchy

```text
+-----------------------------------------------------------------+
|                     IF_Async                                    |
|                     (Container class)                           |
+-----------------------------------------------------------------+
|                                                                 |
|   +-------------------------+   +-------------------------+    |
|   |   Processable       |   |   Finishable        |    |
|   |   (Required)            |   |   (Optional)            |    |
|   +-------------------------+   +-------------------------+    |
|   |                         |   |                         |    |
|   |   execute(List<Object>) |   |   finish(BatchContext)  |    |
|   |                         |   |                         |    |
|   |   Called for each       |   |   Called once after     |    |
|   |   batch/chunk of items  |   |   all items processed   |    |
|   |                         |   |                         |    |
|   +-------------------------+   +-------------------------+    |
|                                                                 |
|   +---------------------------------------------------------+  |
|   |   AsynchronousExecutionStrategy (Enum)                   |  |
|   +---------------------------------------------------------+  |
|   |   AUTO              - Framework decides (recommended)    |  |
|   |   BATCH             - Force Batch Apex                   |  |
|   |   CHAINABLE         - Force chained queueables           |  |
|   |   PARALLEL_QUEUEABLES - Force parallel queueables        |  |
|   +---------------------------------------------------------+  |
|                                                                 |
+-----------------------------------------------------------------+
```

### [`IF_Async.Processable`](reference/apex/IF_Async.Processable.md) (Required)

This is where your work lives. Implement this interface to define what happens to each batch of records the framework
hands you.

```apex
public with sharing class MyProcessor implements IF_Async.Processable
{
	/**
	 * @description Called for each batch/chunk of items.
	 *              For BATCH strategy: called once per batch execution
	 *              For QUEUEABLE strategies: called once per queueable
	 *
	 * @param items List of objects to process (cast to your type)
	 */
	public void execute(List<Object> items)
	{
		// Cast to your specific type
		List<Account> accounts = (List<Account>)items;

		// Your business logic here
		for(Account account : accounts)
		{
			// Process each record
		}

		// Perform DML
		DML_Builder.newTransaction().doUpdate(accounts).execute();
	}
}
```

### [`IF_Async.Finishable`](reference/apex/IF_Async.Finishable.md) (Optional)

Add this interface alongside [`IF_Async.Processable`](reference/apex/IF_Async.Processable.md) when you need to clean up or
send a notification once all the records are processed. The framework calls your `finish()` method one time, after the
last batch.

```apex
public with sharing class MyProcessor implements
	IF_Async.Processable,
	IF_Async.Finishable
{
	private Integer totalProcessed = 0;
	private List<String> errors = new List<String>();

	public void execute(List<Object> items)
	{
		List<Lead> leads = (List<Lead>)items;
		totalProcessed += leads.size();
		// ... processing
	}

	/**
	 * @description Called once after all batches/queueables complete.
	 *              Use for: notifications, status updates, chaining jobs
	 *
	 * @param context Provides job ID for monitoring
	 */
	public void finish(Database.BatchableContext context)
	{
		// Log completion
		LOG_Builder.build().info(
			'Processed ' + totalProcessed + ' leads with ' + errors.size() + ' errors'
		).emitAt('MyProcessor.finish');

		// Update status record
		ProcessingStatus__c status = new ProcessingStatus__c(
			JobId__c = context.getJobId(),
			RecordsProcessed__c = totalProcessed,
			Status__c = 'Complete'
		);
		DML_Builder.newTransaction().doInsert(status).execute();
	}
}
```

---

## Async Chain Orchestration

Some work has distinct phases that must run in order, where one phase is too much to fit in a single transaction with the
next. An async chain runs those phases as separate steps, one after another, each in its own transaction. Steps share
data, progress is tracked automatically, and errors are handled for you. Because each step is a fresh transaction, it
starts with a clean set of governor limits.

### When to Use Chains

| Pattern                                   | Best for                                                                                   |
|-------------------------------------------|--------------------------------------------------------------------------------------------|
| Single processor (`IF_Async.Processable`) | Processing a collection of records with the same logic                                     |
| Scheduler (`IF_Schedulable`)              | Recurring jobs on a cron schedule                                                          |
| **Async chain**                           | Multi-step workflows where steps must run sequentially, each needing fresh governor limits |

Use chains when your workflow has distinct phases that depend on each other: for example, load data, transform it, then
send a notification. Each step can make callouts, run DML, and query without competing for the same transaction's limits.

### Architecture

```text
+-----------------------------------------------------------------------------------+
|                          ASYNC CHAIN ORCHESTRATION                                |
+-----------------------------------------------------------------------------------+
|                                                                                   |
|   +-------------------+        +--------------------------+                       |
|   |   ChainBuilder    |        | AsyncChainExecution__c   |                       |
|   |                   |        |                          |                       |
|   |   .then(step)     +------->|   ChainName, Status,     |                       |
|   |   .onError(h)     |  DML   |   StepLog,       |                       |
|   |   .onComplete(h)  | Insert |   ContextData,           |                       |
|   |   .execute()      |        |   CorrelationId          |                       |
|   +-------------------+        +------------+-------------+                       |
|                                             |                                     |
|                                    System.enqueueJob()                            |
|                                             |                                     |
|   +-------------------------------------------------------------------------+     |
|   |                     QUEUEABLE TRANSACTION (per step)                    |     |
|   +-------------------------------------------------------------------------+     |
|   |                                                                         |     |
|   |   +------------------+      +------------------+      +--------------+  |     |
|   |   | ChainExecutor    |      | Your ChainStep   |      | StepResult   |  |     |
|   |   |                  |      |                  |      |              |  |     |
|   |   | 1. Hydrate log   +----->| work(context)    +----->| success=true |  |     |
|   |   |    context       |      |                  |      | message=...  |  |     |
|   |   | 2. Deserialize   |      | - DML operations |      | data=...     |  |     |
|   |   |    chain context |      | - API callouts   |      +--------------+  |     |
|   |   | 3. Run step      |      | - Context reads  |                        |     |
|   |   | 4. Persist state |      | - Context writes |                        |     |
|   |   +------------------+      +------------------+                        |     |
|   |                                                                         |     |
|   +-----------------------------------+-------------------------------------+     |
|                                       |                                           |
|                              +--------+--------+                                  |
|                              |    FINALIZER     |                                  |
|                              +---------+--------+                                  |
|                                        |                                          |
|                    +-------------------+-------------------+                       |
|                    |                                       |                       |
|              SUCCESS + more steps                   UNHANDLED EXCEPTION            |
|                    |                                       |                       |
|                    v                                       v                       |
|       +------------------------+              +------------------------+           |
|       | Enqueue next           |              | Mark chain FAILED      |           |
|       | ChainExecutor          |              | Log crash details      |           |
|       | (fresh governor limits)|              +------------------------+           |
|       +------------------------+                                                  |
|                    |                                                              |
|              (repeat until last step)                                             |
|                    |                                                              |
|                    v                                                              |
|       +------------------------+                                                  |
|       | handleChainCompletion  |                                                  |
|       |                        |                                                  |
|       | Run onComplete handler |                                                  |
|       | Mark chain COMPLETED   |                                                  |
|       +------------------------+                                                  |
|                                                                                   |
+-----------------------------------------------------------------------------------+
```

**Execution Flow:**

1. `ChainBuilder` validates and persists the chain configuration to `AsyncChainExecution__c`
2. `ChainExecutor` (a Queueable) hydrates logging context, deserializes chain state, runs one step
3. The Finalizer (fresh governor limits) enqueues the next `ChainExecutor` for the next step
4. Context is serialized to `AsyncChainExecution__c.ContextData__c` between transactions
5. On unhandled crash (governor limits), the Finalizer marks the chain as Failed

**Error Flow:**

```text
+------------------+     +------------------+     +------------------+
| Step fails       |     | Error handler    |     | Final state      |
| (StepResult or   +---->| onError(handler) +---->| Status = Failed  |
|  exception)      |     | own Queueable    |     | ErrorMessage set |
+------------------+     +------------------+     +------------------+

+------------------+     +------------------+     +------------------+
| Step fails with  |     | Chain continues  |     | Next step runs   |
| continueOnError  +---->| to next step     +---->| with fresh       |
| = true           |     | (logged as warn) |     | governor limits  |
+------------------+     +------------------+     +------------------+
```

### Building Steps

Each step in a chain is a small class you write. Extend `UTIL_AsyncChain.ChainStep` and implement `work(ChainContext)`,
then return a `StepResult` to say whether the step succeeded or failed.

```apex
public class LoadDataStep extends UTIL_AsyncChain.ChainStep
{
	public override UTIL_AsyncChain.StepResult work(UTIL_AsyncChain.ChainContext context)
	{
		List<Account> accounts = new SEL_Account().toList();
		context.put('accountCount', accounts.size());
		context.put('accountIds', new Map<Id, Account>(accounts).keySet());
		return UTIL_AsyncChain.succeeded('Loaded ' + accounts.size() + ' accounts');
	}
}
```

```apex
public class TransformDataStep extends UTIL_AsyncChain.ChainStep
{
	public override UTIL_AsyncChain.StepResult work(UTIL_AsyncChain.ChainContext context)
	{
		Integer count = (Integer)context.get('accountCount');

		if(count == 0)
		{
			return UTIL_AsyncChain.failed('No accounts to transform');
		}

		context.put('transformed', true);
		return UTIL_AsyncChain.succeeded('Transformed ' + count + ' accounts');
	}
}
```

**StepResult factories:**

| Method                                     | Use                                   |
|--------------------------------------------|---------------------------------------|
| `UTIL_AsyncChain.succeeded()`              | Success, no message                   |
| `UTIL_AsyncChain.succeeded(message)`       | Success with descriptive message      |
| `UTIL_AsyncChain.succeeded(message, data)` | Success with message and payload data |
| `UTIL_AsyncChain.failed(message)`          | Failure with descriptive message      |
| `UTIL_AsyncChain.failed(exception)`        | Failure from caught exception         |
| `UTIL_AsyncChain.failedPermanently(message)`   | Failure that must never be retried, whatever the retry budget |
| `UTIL_AsyncChain.failedPermanently(exception)` | Permanent failure from a caught exception             |

### Chain Builder API

You configure a chain with a series of short chained calls, then one call runs it. Start with
`UTIL_AsyncChain.newChain()`:

```apex
String executionId = UTIL_AsyncChain.newChain('OrderProcessing')
	.then(new ValidateOrderStep())
	.then(new ProcessPaymentStep())
	.then(new SendConfirmationStep())
	.withInitialContext('orderId', order.Id)
	.withInitialContext('amount', order.Total__c)
	.onError(new NotifyAdminStep())
	.onComplete(new AuditLogStep())
	.execute();
```

| Method                            | Description                                                                       |
|-----------------------------------|-----------------------------------------------------------------------------------|
| `.then(IF_Chain.Step)`            | Appends a step to the chain (accepts interface or ChainStep)                      |
| `.then(IF_Chain.Step, Boolean)`   | Appends a step with explicit `continueOnError` control                            |
| `.withInitialContext(key, value)` | Seeds the context with a key-value pair (additive)                                |
| `.withMaxSteps(Integer)`          | Maximum steps allowed (default: 50)                                               |
| `.withMaxContextSize(Integer)`    | Maximum serialised context size in characters (default: 32768)                    |
| `.withDelayMinutes(Integer)`      | Delays the first step by 0 to 10 minutes, best-effort (see below)                 |
| `.withDeduplicationKey(String)`   | Blocks a second overlapping run while one with the same key is active (see [Preventing duplicate runs](#preventing-duplicate-runs)) |
| `.allowRestart()`                 | Declares the chain safe to restart from its first step and captures the as-built context (see [Restarting a chain from the start](#restarting-a-chain-from-the-start)) |
| `.withAsyncOptions(AsyncOptions)` | Sets queueable stack depth (for tests)                                            |
| `.onError(IF_Chain.Step)`         | Registers a handler that runs when a step fails                                   |
| `.onComplete(IF_Chain.Step)`      | Registers a handler that runs after all steps succeed                             |
| `.execute()`                      | Persists config, enqueues the first step, returns the `AsyncChainExecution__c` ID |
| `.execute(correlationId)`         | Same as above with a caller-supplied correlation ID                               |

**Delaying the first step.** `withDelayMinutes` holds the chain's first step back for a few minutes, which is useful
for spacing work out or giving an upstream system a moment to settle. Treat it as "about N minutes" rather than a
precise timer, and keep these limits in mind:

- The delay is capped at 0 to 10 minutes, the platform's own ceiling. A value outside that range is clamped, and 0 or
  no value starts the chain immediately, exactly as before.
- Only the first step waits. Every later step still runs as soon as the one before it finishes.
- If your org has turned the platform's queued-job delay off, the chain simply starts straight away.
- While it waits, the Chain Monitor shows the chain as Running with 0 of N steps done. It has not stalled; it is
  waiting to begin.

```apex
UTIL_AsyncChain.newChain('NightlyRollup')
	.then(new AggregateStep())
	.withDelayMinutes(5)
	.execute();
```

### Context Sharing

Steps pass data to each other through a shared `ChainContext` object. Because that object is saved (serialized) between
transactions, every value you put in it must be JSON-serializable. Prefer record IDs and simple values over full SObject
graphs, which are heavier to carry across each transaction boundary.

```apex
public override UTIL_AsyncChain.StepResult work(UTIL_AsyncChain.ChainContext context)
{
	context.put('batchSize', 200);
	context.put('recordId', record.Id);

	Integer batchSize = (Integer)context.get('batchSize');
	Boolean hasKey = context.has('recordId');
	List<String> names = (List<String>)context.getAs('nameList', List<String>.class);

	UTIL_AsyncChain.StepResult previous = context.getPreviousStepResult();
	Integer stepIndex = context.getCurrentStepIndex();
	String executionId = context.getChainExecutionId();
	String correlationId = context.getCorrelationId();

	return UTIL_AsyncChain.succeeded();
}
```

| Method                    | Returns      | Description                                                                          |
|---------------------------|--------------|--------------------------------------------------------------------------------------|
| `get(key)`                | `Object`     | Raw value lookup                                                                     |
| `getAs(key, Type)`        | `Object`     | Deserializes to specified type (for complex objects crossing transaction boundaries) |
| `put(key, value)`         | `void`       | Stores a value                                                                       |
| `has(key)`                | `Boolean`    | Checks key existence                                                                 |
| `getPreviousStepResult()` | `StepResult` | Result of the last completed step (null for first step)                              |
| `getCurrentStepIndex()`   | `Integer`    | Zero-based index of the current step                                                 |
| `getChainExecutionId()`   | `String`     | ID of the `AsyncChainExecution__c` tracking record                                   |
| `getCorrelationId()`      | `String`     | Correlation ID for log tracing                                                       |
| `getAttempt()`            | `Integer`    | Which attempt this is for the current step, starting at 1 (see Retrying a failed step) |
| `isFinalAttempt()`        | `Boolean`    | True on the current step's last allowed attempt, judged from the attempt budget (see Retrying a failed step) |
| `isFinalAttempt(error)`   | `Boolean`    | True when failing with that exact exception would be final, filters included (see Retrying a failed step) |

### Error Handling

**onError handler:** This runs when any step fails (unless the failing step is marked `continueOnError = true`). It runs
in its own fresh transaction (`HandlerExecutor`), so it starts with clean governor limits and can make callouts even when
the failed step already performed DML. It receives the full context, including the failure result from the step that
broke.
Inside the handler, `getAttempt()` and `isFinalAttempt()` reflect the failure that triggered
it: a failure that reached your handler was final, and `isFinalAttempt()` reads true even when
a filter refused the retry with budget still remaining.

```apex
public class NotifyAdminStep extends UTIL_AsyncChain.ChainStep
{
	public override UTIL_AsyncChain.StepResult work(UTIL_AsyncChain.ChainContext context)
	{
		UTIL_AsyncChain.StepResult failedResult = context.getPreviousStepResult();
		String errorMessage = failedResult != null ? failedResult.message : 'Unknown error';

		LOG_Builder.build().error('Chain failed: ' + errorMessage)
			.at('NotifyAdminStep.work')
			.forRecord(context.getChainExecutionId())
			.emit();

		return UTIL_AsyncChain.succeeded();
	}
}
```

**continueOnError:** When a step is allowed to fail without stopping the whole chain, pass `true` to the
`then(step, true)` overload. The chain logs the failure and moves on to the next step.

```apex
UTIL_AsyncChain.newChain('ResilientChain')
	.then(new CriticalStep())
	.then(new CleanupStep(), true)
	.then(new FinalStep())
	.execute();
```

**onComplete handler:** This runs after every step has succeeded, again in its own fresh transaction
(`HandlerExecutor`). Callouts are safe here even if the final step performed DML. If this handler throws, the chain is
marked as Failed.

**Chain statuses:** `Running` → `Completed` | `Failed` | `Aborted`, with `Stalled` as a recoverable
in-between state when a chain loses its background job (see [Monitoring](#monitoring)).

### Retrying a failed step

When a step fails for a temporary reason (a locked row, a brief callout timeout, a rate limit), you
often want it to try again rather than fail the whole chain. By default a step gets one attempt: if it
throws, the chain stops and is marked `Failed`. A step can opt into automatic retry instead.

You opt in by overriding `createRetryStrategy()` on your step and returning a retry strategy. Return
`null`, which is the default, and nothing changes: one attempt, no retry, exactly as before. This
matters on upgrade: a step that was never written to be safe to run twice is never retried behind your
back.

Retry treats a thrown exception and a returned failed result the same way. A step that returns
`failed(exception)` is filtered by the same exception allowlists and denylists as a step that
throws; only a message-only `failed(message)` carries no exception, so nothing but the attempt
budget decides it. When a step recognises a failure that can never succeed on a re-run (a
validation verdict, a record already rejected upstream), return
`UTIL_AsyncChain.failedPermanently(message)` instead: the chain fails on that attempt without
spending the remaining budget, and the audit category reads `Step Exception` rather than
`Retries Exhausted`, because the budget was refused, not used up.

```apex
public class ChargeCardStep extends UTIL_AsyncChain.ChainStep
{
	public override UTIL_AsyncChain.StepResult work(UTIL_AsyncChain.ChainContext context)
	{
		// ... do the work ...
		return UTIL_AsyncChain.succeeded();
	}

	public override UTIL_Retry.Strategy createRetryStrategy()
	{
		return UTIL_Retry.exponential().withMaxRetries(2).withBaseBackoff(0);
	}
}
```

Build the strategy with `UTIL_Retry.exponential()` (or `linear()`) and shape it with `withMaxRetries`,
`withBaseBackoff`, and the other options. To retry only certain failures, wrap it in an allowlist so an
unexpected exception fails fast instead of being retried pointlessly:

```apex
public override UTIL_Retry.Strategy createRetryStrategy()
{
	return UTIL_Retry.retryOnlyOnException(
		UTIL_Retry.exponential().withMaxRetries(3),
		new Set<Type>{ CalloutException.class }
	);
}
```

Prefer this allowlisted form over any "just try N times" shortcut. You decide which failures are worth
retrying, and a genuine bug surfaces immediately rather than being retried three times first.

**A retry waits at least a minute.** The chain schedules each retry through the platform's delayed-job
window, which counts in whole minutes and tops out at ten. Any backoff above zero therefore waits a
full minute at least; a base backoff of `0` re-enqueues immediately. Size your backoff in that light,
because seconds-level precision is not available here.

**Know which attempt you are on.** Inside `work()`, `context.getAttempt()` gives the attempt number (1
for the first try) and `context.isFinalAttempt()` is true on the last allowed attempt, so a step can,
for example, alert someone only when it is about to give up for good.
`isFinalAttempt()` is judged from the attempt budget alone, before your code runs, so it cannot
know that an exception filter will refuse the retry afterwards. To ask "would failing with this
exact exception be final?", call `context.isFinalAttempt(error)` with the exception you are
about to fail with: it consults your strategy's filters too, so the give-up alert fires on the
attempt that really is the last one. Both read correctly for your own `ChainStep` subclasses.
`getPreviousStepResult()` on a retried attempt returns that step's own
previous failed result, so you can see what went wrong last time.

When a chain runs out of retries it is marked `Failed`, and its `FailureCategory__c` reads `Retries
Exhausted` rather than `Step Exception`, so the audit trail shows the difference between a step that
failed once and one that used up every attempt.
A failure declared permanent with `failedPermanently(...)`, and a first-attempt failure whose
exception the filter refuses, both read `Step Exception`: in neither case was the budget used
up.

Before you turn retry on, check the step is safe to repeat:

- Running it twice produces the same result (it is idempotent). If it writes to an outside system,
  pair it with `idempotencyKey()` so a repeat is not double-counted.
- A duplicate external side effect is either impossible or harmless.
- The step still behaves correctly if recovery re-drives the chain while a retry is waiting (see
  [Preventing duplicate runs](#preventing-duplicate-runs) and [Monitoring](#monitoring)).

A step that passes this checklist can say so: override `isIdempotent()` in the step to return `true`. Do this on every
step that is safe to run twice. The declaration does not change a normal run; it matters only when something goes wrong.
It lets the watchdog run the step again after the chain stalls (see
[What happens to a stalled step](#what-happens-to-a-stalled-step)), and it unlocks the Chain Monitor's operator retry for the
step, described in [Re-driving a failed chain](#re-driving-a-failed-chain). An `ApiStep` whose request is safe to repeat
(the handler sends a GET, PUT or DELETE, or its service setting has Idempotency Enabled turned on) makes this declaration by
itself. Keep it an override, not a constructor: the framework
creates each step from its class name on every hop, and a step class that declares its own constructor cannot be
created that way from inside the package (see the note under the example below).

### Preventing duplicate runs

Some chains should never run twice at once. A nightly job can fire twice when a schedule overlaps; an
action button can be double-clicked. Give the chain a deduplication key and the framework lets only one
run with that key be active at a time.

```apex
UTIL_AsyncChain.newChain('NightlyAccountSync')
	.then(new SyncAccountsStep())
	.withDeduplicationKey('nightly-account-sync')
	.execute();
```

While a run with that key is active, a second `execute()` using the same key does not start a new
chain. It lands on the run already in flight and returns that run's Id, so the caller gets a handle to
the live chain rather than a duplicate. Keys are compared without regard to case, so `'Nightly'` and
`'NIGHTLY'` count as the same key. A blank key, or one longer than 255 characters, is rejected when you
build the chain, not later at run time.

The key is tied to the run's state, never to a clock: there is no expiry timer. The key is released the
moment the chain reaches any end state (`Completed`, `Failed`, or `Aborted`), so the next scheduled run
is free to start. A stalled chain keeps its key until recovery finishes or it resolves, which is
deliberate: releasing it on a timer would reopen the very overlap the key exists to prevent.

**This is not the same as `idempotencyKey()`.** The two sound alike and do opposite jobs. A
deduplication key stops two runs of the *chain* from overlapping. An idempotency key makes one *step's*
external side effect safe to replay, so a retry does not double-charge a card or double-post a record.
Use both together when a chain must not overlap and also contains a step that writes to an outside
system. If what you need is a limit on how often a chain may run in sequence rather than in parallel,
read the current run's state with `getChainStatus` and decide in your own code; the deduplication key
is only about overlap.

A natural key for a scheduled chain is the schedule's own name, so every firing of that schedule shares
one key and can never lap itself.

### Monitoring

To see how a chain is doing, you can either ask for its status in code or open the `AsyncChainExecution__c` records
directly. Every chain you run leaves one of these records behind.

```apex
Map<String, Object> status = UTIL_AsyncChain.getStatus(executionId);
String currentStatus = (String)status.get('status');
Decimal completedSteps = (Decimal)status.get('completedSteps');
Decimal totalSteps = (Decimal)status.get('totalSteps');
```

The map is handy for a quick read, but you have to know each key's name and cast every value yourself. When you would
rather work with a typed object, use `getChainStatus` instead. It returns a `ChainStatus` with every field named and
typed, plus three ready-made checks so you never compare status strings by hand:

```apex
UTIL_AsyncChain.ChainStatus status = UTIL_AsyncChain.getChainStatus(executionId);

if(status != null && status.isFailed())
{
	String reason = status.errorMessage;
}

Integer done = status.completedSteps;   // already an Integer, no casting
String elapsed = status.durationLabel;  // for example "1m 30s"
```

`isRunning()`, `isTerminal()`, and `isFailed()` answer the common questions directly.
The raw `status` is still there as a String if you need it. The framework writes five values: `Running` (a chain waiting
on a scheduled delay also shows as Running, with no completed steps yet), `Completed`, `Failed`, `Aborted`, and
`Stalled`. A chain goes `Stalled` when it loses the background job that would carry it forward, so recovery is either
waiting to step in or already acting: the watchdog can revive a stalled chain and let it finish. `isTerminal()` reports
the end states `Completed`, `Failed`, and `Aborted`, and also any chain that carries a completion timestamp. That last
case catches the rare row where recovery briefly overwrites an already-finished chain back to `Stalled`: the completion
timestamp survives, so it stays the reliable end-of-life signal. When a step without a retry strategy throws an unhandled exception, or a failure is refused by
the step's retry filters, the chain is marked `Failed` straight away, with no further attempt
and no backoff. Automatic recovery still never touches a Failed chain: the watchdog revives chains that stall, not ones
that have already failed. What a Failed chain can get is operator attention, and only when it opted in: if the failed
step declares itself safe to re-run, the Chain Monitor offers [a retry from the failed step](#re-driving-a-failed-chain),
and a chain built with `allowRestart()` can be [restarted from the start as a new run](#restarting-a-chain-from-the-start).
Both actions ship switched off and stay unavailable until those declarations are made. `durationMs` is the same number
the Chain Monitor shows in its Duration column, worked out as the next paragraph describes, so a chain that is
`Running` or `Stalled` reports how long it has been going so far.

**Duration counts a run that is still going.** The Chain Monitor's Duration column sorts by the same number it shows:
how long a run took, or how long it has been going if it has not finished. A run stalled for an hour and a half sorts
as an hour and a half, in among the finished runs, instead of sorting as empty. That number is the **Elapsed (ms)**
field on the run record, so list views and reports can use it too. A run that ended without storing a duration, such
as one whose background job crashed, shows the time between its start and its end, and sorts by it. While you page through a list sorted by Duration, a run that is still going keeps growing,
so it can move to another page between two page requests; refresh the list to see the current order.

**A step that never ran says so.** Once a run has ended, a step it never reached reads "Did not run" instead of
"Pending". A step the run may still have been working on when it ended reads "No result recorded": nothing was recorded
for it, so the Chain Monitor cannot say whether it ran.

**Turn on stalled-chain recovery.** The watchdog that revives stalled chains (when it can prove a chain died, it runs the stalled step again only if that is safe and otherwise ends the chain `Failed`; it flags anything it cannot prove dead for a person; [What happens to a stalled step?](#what-happens-to-a-stalled-step) says which steps it runs again) is itself a scheduled job, and a managed package cannot ship one, so it stays dormant until an admin schedules it. The quickest way is one click: the Health Check on the Kern app's Home tab spots a missing watchdog and schedules it for you (hourly, with a 30-minute stale threshold and up to 50 chains per sweep). Until you do, only one class of stall surfaces on its own: a chain whose next step could not be queued is marked `Stalled` immediately, but a run whose background job died without leaving a trace stays on `Running` until the watchdog's sweep picks it up, recovering it when it can prove the job died or marking it `Stalled` when it cannot, and neither class is re-driven until the watchdog is scheduled. Schedule it once, the same declarative way as the built-in housekeeping jobs: create a [`ScheduledJob__c`](reference/objects/ScheduledJob__c.md) record whose `ClassName__c` is `SCHED_ChainWatchdog`, running hourly (`0 0 * * * ?`); see [Declarative Scheduling with `ScheduledJob__c`](#declarative-scheduling-with-scheduledjob__c). Two optional attributes tune it: `StaleThresholdMinutes` (how many minutes a chain may sit idle before it counts as stalled, default 30) and `BatchSize` (how many chains one sweep inspects, default 50). If you would rather schedule it in Apex, `System.schedule('Chain Watchdog', '0 0 * * * ?', new SCHED_ChainWatchdog());` does the same job. The [Installation guide](Installation.md#post-install-configuration) lists this next to the other one-time setup steps.

The first time a chain with no `onError` handler registered goes `Stalled`, that stall is recorded at ERROR level, so it
stands out in the Log Console even when nobody is watching the Chain Monitor. Chains with a handler keep the WARN-level
entry alongside their notification. Two stalls stay at WARN whatever handlers the chain has: a chain that was already
`Stalled` and gets marked again, and a chain the watchdog parks because your org has run out of background-job capacity.
In the parked case the notification was held back to protect that capacity, not because the chain lacks a handler, so it
is deliberately not reported as one.

A `ChainStatus` is a single-record summary and deliberately carries no per-step list. When you need step-by-step detail,
open the chain in the Chain Monitor. To look up several chains at once, `getChainStatuses(Set<Id>)` returns a map of Id
to `ChainStatus` in one query, so it is safe to call inside a loop. Both accessors return only the chains you have access
to, exactly as `getStatus` does.

**AsyncChainExecution__c fields:**

| Field                | Description                                                                          |
|----------------------|--------------------------------------------------------------------------------------|
| `ChainName__c`       | Descriptive name from `newChain()`                                                   |
| `ActiveDeduplicationKey__c` | The deduplication key while the chain is active, if you set one; cleared when the chain reaches an end state (see [Preventing duplicate runs](#preventing-duplicate-runs)). Empty when no key was set |
| `Status__c`          | Running, Completed, Failed, Aborted, or Stalled (the picklist also defines Delayed, which the framework does not currently write) |
| `FailureCategory__c` | Why the chain left the happy path: Step Exception, Retries Exhausted, Kill Switch, Stalled, or Operator Abort. Empty on healthy chains |
| `TotalSteps__c`      | Number of steps in the chain                                                         |
| `CompletedSteps__c`  | Steps that succeeded (failed steps are not counted)                                  |
| `CurrentStepName__c` | Name of the currently executing step                                                 |
| `ErrorMessage__c`    | Error details if failed; non-fatal failure summaries if completed with issues        |
| `DurationMs__c`      | Total chain execution duration in milliseconds                                       |
| `ElapsedMs__c`       | How long the run took, or how long it has been going if it has not finished. A Completed, Failed or Aborted run that stored no duration shows the time between its start and its end |
| `LastManualRetryAt__c` | When someone last used Retry on this run after it failed. Blank if nobody has     |
| `StepLog__c`         | JSON log of each step: className, success, durationMs, message (enriched at runtime) |
| `CorrelationId__c`   | Correlation ID for log tracing: the run's own ID, which every entry its steps write carries |
| `LaunchCorrelationId__c` | The tracking ID the run was launched under: the action's ID, or the parent run's ID when a step launched it. Empty when the chain started its own action, and on a restart |
| `RootCorrelationId__c` | The tracking ID of the action the run belongs to (the run's own ID when it started the action) |
| `ContextData__c`     | Serialized chain context (JSON)                                                      |
| `AllowRestart__c`    | Whether the chain was built with `allowRestart()` and may be restarted from the start (see [Restarting a chain from the start](#restarting-a-chain-from-the-start)) |
| `InitialContextData__c` | The initial context as built, captured only for chains that declare `allowRestart()`; a restart replays this snapshot, never the evolved context |
| `SourceExecution__c` | On a restarted run, the record it was restarted from; empty otherwise                |
| `DeclaredDeduplicationKey__c` | The deduplication key the chain was built with, kept after the run ends so a re-drive can re-claim it |
| `StartedAt__c`       | When the chain started                                                               |
| `CompletedAt__c`     | When the chain finished                                                              |

The object has field history tracking enabled on `Status__c`, `CompletedSteps__c`, `CurrentStepName__c`, and
`CompletedAt__c`, providing a full audit trail of chain progression step by step.

### What happens to a stalled step?

When a chain stalls, the watchdog has to decide whether to run the step it stopped on again. Running a step twice is
harmless for some steps and costly for others: a step that sends a payment or creates a record in another system may
already have done its work before the chain lost track of it. So the watchdog runs a stalled step again only when it
knows that is safe:

| The step the chain stalled on | What the watchdog does |
|---|---|
| Never started | Runs it, and the chain carries on |
| Had started, and declares `isIdempotent()` as `true` | Runs it again, and the chain carries on |
| Had started, with no such declaration | Does not run it again. The chain ends `Failed`, with a failure category of `Stalled` |

A step counts as started once the framework has handed it to the platform to run, even if the chain stalled before the
step saved a result. In that case nobody can tell from the chain record whether the step's work happened, so the
framework does not guess.

A chain that ends this way says what to do in its error message, which the Chain Monitor shows on the run and on the step:
"Recovery stopped at step {name}. The step had started when the chain stalled and no result was saved, so it may already
have done its work. It was not run again. Check whether its work landed, then start a replacement." The chain's `onError`
handler, if it has one, is told. The **Clear stalled** button in the Chain Monitor follows the same rule.

**Declare `isIdempotent()` on every step that is safe to run twice**, so the watchdog keeps recovering it on its own (see
[Retrying a failed step](#retrying-a-failed-step) for the checklist). An `ApiStep` whose request is safe to repeat makes
the declaration by itself: its handler sends a GET, PUT or DELETE, or its service setting has Idempotency Enabled turned
on. One case it cannot see: if your handler overrides `createRequest()` and leaves the Idempotency-Key header off, the
step still counts as safe because the setting is on. For such a handler, do not rely on the setting.

**On an org whose background queue is slow,** one step that never ran can also end the chain this way: a step whose job
waited in the queue for longer than the watchdog's stale threshold before the platform could start it. If you see that,
raise the watchdog's `StaleThresholdMinutes` (30 by default) above the longest wait you see.

### Stopping a chain from the Chain Monitor

Sometimes a chain is doing the wrong thing and you want it to stop now, not after you have tracked down the cause. The
Chain Monitor has an **Abort** action for exactly that. It ships switched off, so no one can stop a chain by accident
until you deliberately turn it on.

**Turning it on.** There is nothing to activate. Assign the **Kern Async Chain Abort** permission set to the operations
users who should be allowed to abort a chain, and the action appears for them. The feature flag that governs it ships
active, so the permission set is the only switch you touch to enable the action. One caveat: installing the package for
All Users writes the abort permission into every profile during the install, so in that case the action is already
enabled for everyone. Remove those profile grants to bring the action back under the permission set's control.

To give an operations user view-only access to the Chain Monitor, assign the Kern Async Chain Monitor Read Only
permission set. It grants read access to chain records and the monitor tab and nothing else; pair it with the Kern
Async Chain Abort set for users who may also stop chains.

**Turning it off for everyone.** Deactivate the **Async Chain Abort Enabled** feature-flag record. That is the org-wide
off-switch: it hides the action for every user in one step, with no deployment and without touching anyone's permission
set. The Health Check's **Chain Abort Capability** row tells you where you stand, warning while the flag is deactivated,
while profiles beyond System Administrator hold the abort permission (the footprint of an All Users install), or while
no one holds the permission set. It passes once the flag is active, no profile beyond System Administrator holds the
permission, and at least one user holds the set.

**What abort does.** Abort takes effect at the next step boundary. The step that is running is allowed to finish, and
then the chain stops rather than starting the next one (it can also stop a stalled chain that is waiting on recovery).
An aborted chain cannot be resumed from where it stopped. If the work still needs to run, a chain built with
`allowRestart()` can be [restarted from the start as a new run](#restarting-a-chain-from-the-start); any other chain you
relaunch yourself. The outcome is recorded as `Aborted`, with a failure category of `Operator Abort`.

**A note on live updates.** The admin who presses Abort always sees their own monitor update straight away. On an org
whose logging is turned down to errors only, a common production setting, other admins watching the same chain will not
see the abort appear on its own; they refresh the panel to pick it up. A failure still shows up live either way.

### Re-driving a failed chain

Sometimes a chain fails on a step you know is safe to try again: the outside system was down for an hour, or a row was
locked by a job that has long since finished. Rather than rebuilding and relaunching the whole chain, the Chain Monitor
can re-drive a Failed run from exactly the step that failed. Steps that already completed do not run again, the chain
keeps its record and its tracking ID, and the failed step's retry attempts start again from zero.

**What a retry leaves behind.** The step timeline shows a line above the step that was retried: "Retried manually
after 37m", where the time is how long the run sat failed before someone pressed Retry. When that wait cannot be
worked out, the line reads "Retried manually" with no time. It stays once the step goes on to succeed. Retry the same
step again and the newer line replaces the older one, so a step shows one line at a time; a run retried at two different
steps shows two lines, one above each. On a very long chain whose step log has nearly filled the field
that holds it, the line is left off to make room, and the retry itself still runs.

**What the run record keeps.** The **Last Manual Retry At** field holds when Retry was last used, whether or not the
line is shown, so list views, reports and Flows can find the runs a person had to step into. Only a person pressing
Retry sets it: a step's own automatic retries and the recovery of a stalled run do not. A run restarted from the start
is a new run that nobody has retried, so it starts without the line and without the date; the run it was restarted
from keeps both.

The action stays unavailable until two people opt in: the step's author and your administrator.

**The step author declares the step safe to re-run.** Retry is only offered when the step that failed answers
`true` from `isIdempotent()`:

```apex
public class RefreshExchangeRatesStep extends UTIL_AsyncChain.ChainStep
{
	public override Boolean isIdempotent()
	{
		return true;
	}

	public override UTIL_AsyncChain.StepResult work(UTIL_AsyncChain.ChainContext context)
	{
		// fetch and upsert the day's rates; running this twice writes the same values
		return UTIL_AsyncChain.succeeded();
	}
}
```

Declare it only when a repeat run of `work()` cannot double the step's side effects, either because the work is
naturally safe to repeat or because the step guards itself with `idempotencyKey()` (see
[Step Design Guidance](#step-design-guidance)). The declaration does not change a normal run; it is consulted only when an
operator asks to re-drive and when the watchdog decides whether to run a stalled step again (see
[What happens to a stalled step](#what-happens-to-a-stalled-step)). Chains that ran before the declaration existed are never
eligible.

> **Do not declare a constructor on a step class.** The framework creates every step from its class name in each hop,
> and from inside the package it can only use the constructor Apex provides when a class declares none (or a `global`
> constructor on a `global` class). A step with its own `public` constructor fails on its first hop with a message
> that names this rule. Set anything the step needs by overriding a method, as `isIdempotent()` does above.

**The administrator grants the action.** Assign the **Kern Async Chain Redrive** permission set to the operations users
who may recover chains; it ships assigned to nobody. One set covers all three recovery actions: retry, restart, and
clearing stalled chains. Pair it with the **Kern Async Chain Monitor Read Only** set, which grants the chain data,
tabs, and monitor access the actions work on. As with abort, an org-wide off-switch ships alongside: deactivate the **Async Chain
Redrive Enabled** feature-flag record to hide all three actions for everyone without touching anyone's permission sets.

**What a retry refuses, and why.** The retry button appears on Failed chains and explains itself when it cannot act;
the checks run again on the server when you confirm, so the answer holds even when the screen is stale:

- **The step never declared itself safe to re-run.** The framework will not repeat a step whose author did not promise
  a repeat is safe.
- **The step declared the failure permanent.** A failure recorded through `failedPermanently(...)` cannot succeed on a
  re-run, so retrying it is refused, whatever the step declares.
- **The chain's saved context is not available.** A retry resumes with the context the run had when it failed. If that
  context was never persisted (for example it outgrew its field on the failure path, which the framework records rather
  than truncating) or does not read back cleanly, resuming would run the remaining steps against wrong state, so the
  action is refused.
- **Chain processing is suspended.** Re-driving a chain into a suspension would only create a run that stops at
  once; resume processing first (see [The operations control](#the-operations-control)).
- **Another run of this chain holds its deduplication key.** The re-driven run re-claims the chain's declared key, so
  while a live run holds it the retry is refused, exactly as a duplicate `execute()` would be (see
  [Preventing duplicate runs](#preventing-duplicate-runs)). This one check surfaces only when you confirm, as an error
  message rather than on the button.

A re-driven run executes under the framework's default settings (maximum steps, context-size cap, queueable options)
rather than the settings its original builder set, which are not persisted; its steps, its error and completion
handlers, and its context all carry over, and a context already larger than the default cap is never trimmed to fit. [The live activity stream](#the-live-activity-stream) shows the re-driven
run's entries as it progresses.

### Restarting a chain from the start

Retry resumes a run; restart begins a new one. When a chain declares `.allowRestart()` at build time, the Chain Monitor
can restart a Failed or Aborted run from its first step as a fresh chain: a new record, a new tracking ID, and the
context the chain was originally built with. The original record is not touched; it keeps its status and its
diagnostics as the audit record, and the new run's **Launched under** row names the original as a restart, a link
that re-opens it in the monitor. When you confirm, the monitor moves you to the new run.

```apex
UTIL_AsyncChain.newChain('NightlyAccountSync')
	.then(new SyncAccountsStep())
	.withInitialContext('runDate', String.valueOf(Date.today()))
	.allowRestart()
	.execute();
```

A restart re-runs every step, so declare it only when the whole chain can run twice without doubling its side effects.
The declaration does two things at build time: it marks the run restartable, and it captures the initial context
exactly as built. A restart replays that snapshot, never the evolved context a partial run left behind, so a restarted
run starts from the same place the original did; [context written by steps](#context-sharing) along the way is
deliberately not carried over.

The same **Kern Async Chain Redrive** permission set and **Async Chain Redrive Enabled** feature flag govern restart.
The button explains two refusals up front: the chain never declared `allowRestart()` (chains from before the
declaration existed are never eligible), or chain processing is suspended. Two more checks run when you confirm and
refuse with an error message: the captured context must read back cleanly, and no other run of the chain may hold its
deduplication key. Completed chains are never restartable: the work succeeded, and running it again is a decision for
a new chain. Like a re-driven run, a restarted run executes under the framework's default settings rather than the
ones its original builder set.

### Clearing stalled chains

The watchdog sweeps stalled chains on a schedule; during an incident you may not want to wait for the next sweep. The
**Clear stalled** button in the Chain Monitor's header runs the same sweep on demand. Each stalled chain the sweep
reaches is checked, and it is changed only when the framework can prove its background job died. It is then re-driven
when the step it stalled on never started, or had started and is declared safe to repeat (see
[What happens to a stalled step?](#what-happens-to-a-stalled-step)). It is marked failed when that step had started and
is not declared safe to repeat, or when its saved run state is beyond repair. It is left waiting when its job is still
running, when its job cannot be checked, or when the sweep runs short of its limits. The checks are the scheduled watchdog's own, applied in the same
order with the same caution, so the button never does anything the watchdog would not have done at its next sweep.

The result comes back as a toast: how many stalled chains were checked, how many re-driven, how many marked failed, and
how many are still waiting. One click inspects up to 40 stalled chains (the scheduled sweep's own ceiling is 50 per
run); if more are stalled, run it again. A chain the sweep cannot prove anything about is left exactly as it was, so
the action is safe to repeat.

Clear stalled is covered by the same **Kern Async Chain Redrive** permission set as retry and restart, and it refuses
while chain processing is suspended: re-driving chains during a suspension would only stop them again at once.
One pairing to know about: the sweep re-reads each chain with your permissions, so a stalled chain your user cannot see
is left untouched and counted as still waiting. The **Kern Async Chain Monitor Read Only** set grants View All on chain
records, so operators holding it see and sweep every stalled chain.

### The operations control

The Chain Monitor's header carries an operations control: a badge showing whether chain processing is enabled, the
**Clear stalled** button, and a **Suspend** or **Resume** action. Suspend is the kill switch (the master off-switch you
can flip in an incident without a deployment) made operable from the screen: it stops all chain processing org-wide
until someone resumes it.

Suspending is a hard stop, not a pause. Every running chain stops at its next step boundary and is recorded as
`Aborted` with a failure category of `Kill Switch`; a chain launched during the suspension is recorded as `Aborted`
before its first step runs. Resuming lets new chains run again, but
the chains that were stopped during the suspension stay stopped: re-drive or restart the ones that should run. The
confirmation dialogues say as much before you commit to either side.

Suspend and resume sit behind their own grant, deliberately separate from the re-drive actions: an operator trusted to
recover one chain is not thereby trusted to stop every chain in the org. Assign the **Kern Async Chain Kill Switch**
permission set (it ships assigned to nobody), with its own org-wide off-switch in the **Async Chain Kill Switch
Enabled** feature-flag record. The toggle itself stays available while processing is suspended, so resuming never locks
itself out. Under the hood the control writes the same switch the [Kill Switch](#kill-switch) section describes, so an
admin can reach the same state from Setup when the monitor is not to hand.

### The live activity stream

A chain's detail panel ends with **Live activity**: the run's log entries, streaming in as they happen. It opens seeded
with the newest entries already recorded for the chain (up to 20). Entries are matched both by the chain's tracking ID
and by direct reference to the chain record, so ones logged outside the chain's own transactions (the watchdog's
verdicts, an operator's abort) appear too. New entries then arrive live over the platform's event bus, newest first.

Three caveats keep it honest, and the expanded stream prints the first beneath its entries:

- **Only errors always stream.** Other levels depend on the org's log settings: live delivery rides the same log
  events your org publishes, and those respect the org's logging threshold. On an org logging errors only (a common
  production setting), INFO and WARN entries never arrive live; they are still recorded, and a refresh shows them.
- **A healthy chain may stream nothing.** The chain framework logs quietly by design: ordinary progress is tracked on
  the chain record, not written to the log (see [Logging Strategy](#logging-strategy)), so silence usually means
  nothing is wrong.
- **The stream is best-effort.** If the live feed drops, the panel says so in place of the caveat; entries keep
  recording server-side, and refreshing catches you up.

On a Failed chain the stream starts collapsed so the step timeline and the error stay in view; expand it when you want
the log detail. The stream reads and never writes. Seeing entries requires read access on the framework's log object
(`LogEntry__c`), which none of the chain permission sets grants: it ships in the **Kern Administrator** set, the same
access the [Log Console](Logging%20-%20Guide.md#the-log-console) needs, so an operator without it sees an empty
stream. With it, the seed shows matching entries across all users, the same as the Log Console, and each row carries
only the entry's time, level, and short message.

### Logging Strategy

The chain framework keeps logs quiet so the ones that appear matter. Ordinary progress (Status, CompletedSteps,
CurrentStepName, DurationMs) is tracked on the `AsyncChainExecution__c` record, not written to logs. `CompletedSteps__c`
counts only the steps that succeeded; failed steps (including ones marked `continueOnError`) are not counted. Logs are
reserved for events you can act on:

| Event                        | Level | When                                                                |
|------------------------------|-------|---------------------------------------------------------------------|
| Step exception (stack trace) | Error | Step throws an unhandled exception                                  |
| Step failed but continuing   | Warn  | A `continueOnError` step fails; the log includes the failure reason and duration |
| Chain crashed                | Error | Finalizer catches unhandled Queueable crash (governor limits)       |
| Chain stalled, no handler    | Error | A chain goes `Stalled` for the first time with no `onError` handler to notify |
| Chain stalled                | Warn  | Every other stall, including a repeat mark on a chain that was already `Stalled`, and a watchdog park caused by exhausted background-job capacity |
| Chain completed              | Info  | The chain finished successfully; one entry, so a quiet chain is no longer invisible |
| Chain failed                 | Error | The chain reached its terminal `Failed` state (the outcome marker, separate from any step-level exception above) |
| Chain abort requested        | Warn  | An operator aborts a chain; the running step finishes, then the chain stops         |
| Chain aborted                | Warn  | Kill switch active, max steps exceeded, or an operator aborted it from the Chain Monitor |
| Execution record deleted     | Warn  | Rare: a record was removed externally while the chain was running                |

**Seeing terminal signals in the Chain Monitor.** Every chain now leaves one log entry when it ends,
marking how it finished: an INFO entry for a completion, an ERROR entry for a failure, and a WARN entry
for an abort. This closes the old gap where a healthy chain finished without a trace. Where those
entries show up depends on your log level. ERROR entries clear the log-level threshold whatever it is
set to, so a failure is not hidden by a high threshold. A completion (INFO) or an abort (WARN) is
written only when logging is enabled and the threshold is set to include that level. At the ERROR
threshold many orgs run in production, completions and aborts are filtered out, so a second admin
watching the same chain in the Chain Monitor will not see a completion or an abort appear on its own; a
failure still appears live. The entry is best-effort: the chain records its own outcome first and the
log follows, so a delivery hiccup never changes the chain's result.

**Performance logging** happens automatically through `UTIL_PerformanceTimer`. Each step is timed, and if a step runs
longer than the threshold in `LogSetting__c.PerformanceThresholdMs__c`, the framework writes a structured performance log
showing the CPU, heap, SOQL, and DML it used. There is nothing to configure by hand:
`LogSetting__c.EnablePerformanceLogging__c` is on by default; adjust the threshold if you need to.

**Non-fatal failure tracking:** When `continueOnError` steps fail, their failure summaries are added to
`ErrorMessage__c` on the execution record (for example, "Non-fatal step failures: CleanupStep: Timeout; OptionalStep:
Service unavailable"). The status stays `Completed`, so admins can filter on `ErrorMessage__c` to find chains that
finished but had problems along the way.

### Log Correlation

A correlation ID is one tracking ID that follows a single user action across triggers, queries, callouts, and jobs, so
you can pull every log from one action together later. A chain run carries two of them. Its own correlation ID, minted
when the chain is launched and shown on its tracking record and in the Chain Monitor, is on every log its steps write.
Its root correlation ID is the tracking ID of the action that started everything: the ID that was live when your code
launched the chain, or the chain's own ID when nothing was live (a scheduled job, for example). Every log entry carries
both. In the Log Console, pin an action (from an entry's drawer, from the Chain Monitor, or by pasting the action's ID)
and you see the whole action: its own entries and the entries of every chain it launched and every chain those
launched, with one banner that counts the chains and names the failed ones first, up to five, with a count for the
rest; a run's ID pins that run alone. The Chain Monitor lists the action's chains and says what launched each one. One
search in **App Launcher > Kern > Log Entries** for the action's ID brings back the same entries as a flat list, the
chains' entries included, with no banner and no chips. When a chain spans several Queueable transactions, the framework
carries both IDs, the parent transaction ID and any custom context data across each transaction boundary for you.

To supply the run's own correlation ID yourself:

```apex
UTIL_AsyncChain.newChain('MyChain')
	.then(new MyStep())
	.execute('my-custom-correlation-id');
```

**Launching several chains at once, or a chain from inside a step.** Every run gets an ID of its own, so your code can
launch as many chains as it likes inside one action, and a step or a completion handler can launch one chain of its own.
Each run's tracking record shows the ID it was launched under (the action's ID, or the parent run's ID when a step
launched it), and whenever the launching code has a tracking ID of its own, the framework writes one log entry in the
launching story naming the new run. `LOG_Builder.rootCorrelationId` answers the action's ID from anywhere, a step
included. Three rules apply to a chain launched from inside another. A step or handler may launch one chain each time
it runs, because the platform lets a running background job add one job of its own; a second launch in the same run of
the step is refused with a message that says so, and so is a launch after the step has already added a job of its own.
A chain may sit up to five levels below the first chain of the action, and a launch deeper than that is refused before
anything is written.
And when you set no deduplication key of your own, the framework remembers which chain a step launched, so a step that
is retried after launching one gets the same chain back rather than a second one; a completion handler and an error
handler each get a chain of their own. The new chain's first step runs under the launching chain's maximum queueable
stack depth, because the platform lets a running job pass that maximum on but not change it. The framework's default
maximum leaves room for this and counts from the depth the launching step runs at, so if you set your own maximum on a
chain launched from a step, include that depth; and if the launching chain's maximum leaves no room, the launch is
refused with a message that says so.

If you supply the correlation IDs yourself, give each chain a different one. Reusing an ID that another chain already
holds is refused straight away, with a message naming the ID, the run holding it when you can see that run, and how to
fix it, rather than a database error you have to decode.

### Step Design Guidance

**Context key naming:** Use `<StepName>.<key>` to avoid collisions between steps:

```apex
context.put('CreateAccount.accountId', account.Id);
context.put('SendEmail.messageId', response.messageId);
```

**Safe to run twice (idempotency):** A step is *idempotent* when running it a second time produces the same end state as
running it once, with no duplicate side effects, so running the same step twice does not double-process anything. The
framework does not do this for you; it is the step author's job, because manual reprocessing, multiple entry points, or
a partial failure followed by a re-run can all make a step fire again.

What makes a step safe to re-run is a key that stays *identical* every time the same step replays. Never build that key
from a value that changes between attempts, such as a fresh timestamp or a new job id, or the protection silently
disappears. The context hands you the right key so you cannot get this subtly wrong.

**The default: one key per step.** For a step that does a single unit of work, call `context.idempotencyKey()`. Put the
returned value on an external-id field (a field you mark as an external id so a record can be matched by it) and *upsert*
(insert-or-update in one call), so a replay updates the same record instead of creating a duplicate:

```apex
Invoice__c invoice = new Invoice__c(
	IdempotencyKey__c = context.idempotencyKey(),
	Amount__c = 100
);
upsert invoice IdempotencyKey__c;
```

For a side effect you cannot upsert, such as a callout or an email, stamp that same key on a marker record first and
skip the work when the marker is already there.

**For a step that loops over many records: one key per record.** Pass the record id with
`context.idempotencyKey(recordId)`. This matters when a bulk step dies halfway and replays: with a single step-level key
you would have to re-run every record or skip them all, whereas a per-record key means the replay only touches the rows
that did not make it the first time.

```apex
List<Invoice__c> invoices = new List<Invoice__c>();
for(Account account : accounts)
{
	invoices.add(new Invoice__c(
		IdempotencyKey__c = context.idempotencyKey(account.Id),
		Account__c = account.Id
	));
}
upsert invoices IdempotencyKey__c;
```

**Treat the key as opaque** (use it whole; do not pull it apart). Compare it, or store it as your external-id value, but
do not split it to read back the run or the record. If you need those, you already have them: the record id you passed
in, and the values the context exposes.

**Keep a custom grain short.** When the fan-out unit is not a record id, pass your own short, stable token with
`context.idempotencyKey('orderLine-7')`. An external-id field holds up to 255 characters, so keep the token short; if you
ever need a long one, shorten it yourself first (a one-line hash of just your token) while keeping the readable
run-and-step prefix. An over-long key does not pass silently: the save fails with a clear "value too large" error, so you
find out immediately.

In one line: the chain run is the namespace, the step is the unit of replay, and the record is the grain when a step is
bulk.

### Kill Switch

If chains start misbehaving in production, you want to stop them without a deployment. The `FeatureFlag.AsyncChain`
custom metadata record is that master off-switch you can flip in an incident. While it resolves to disabled, a running
chain aborts at its next step boundary with the message "Kill switch active" and no further steps are enqueued; a
chain launched during the stop is recorded as `Aborted` before its first step runs.

It is read through `UTIL_FeatureFlag.isEnabled('AsyncChain')` and ships enabled by default, so chains work out of the
box. There are two ways to flip it:

- **From the Chain Monitor.** The [operations control](#the-operations-control)'s **Suspend** and **Resume** actions
  are this switch made operable from the screen, behind their own permission set.
- **From Setup.** The flag resolves through a hierarchy custom setting, `AsyncChainRuntimeSwitch__c`, whose
  `ChainsEnabled__c` checkbox decides the answer: no setting record means chains run (the shipped default), an
  org-level record with the box unticked is the kill switch, and with the box ticked chains run. Suspend and Resume
  write exactly that org-level record. Deactivating the `AsyncChain` flag record itself is still the bluntest way to
  switch chains off.

Because it is a hierarchy setting, profile- and user-level records override the org default for those users' chain
transactions: you can exempt one integration user from a suspension, or stop chains for a single user, by adding a
record at that level.

The [Feature Flags guide](Feature%20Flags%20-%20Guide.md#framework-owned-flags) records how the flag record's own
fields interact with the setting after an upgrade, and which edits to avoid.

### ApiStep: Web Service Integration

If you already have an outbound integration written as an [`API_Outbound`](reference/apex/API_Outbound.md) handler, you
can drop it into a chain as one step without changing the handler at all.
[`UTIL_AsyncChain.ApiStep`](reference/apex/UTIL_AsyncChain.ApiStep.md) does the bridging. It works with non-POST verbs
too (override `getHttpMethod()` in the handler; see [Web Services - Guide](Web%20Services%20-%20Guide.md)). Behind the
scenes it runs the full web service lifecycle for you (validation, the callout, parsing the response, DML, and saving an
`ApiCall__c` record) through [`UTIL_HttpClient`](reference/apex/UTIL_HttpClient.md) delegation mode.

**How it works:** Chain steps are saved by class name and rebuilt later, so an `ApiStep` can't keep its settings on the
step object itself. Instead, its configuration is stored in the `ChainContext`. When you build the chain, the
`ChainBuilder` writes the step's configuration into the initial context; when the step runs, `work()` reads it back using
the step's position in the chain.

#### Basic Usage

```apex
UTIL_AsyncChain.newChain('OrderProcessing')
    .withInitialContext('orderId', order.Id)
    .then(new UTIL_AsyncChain.ApiStep(API_ChargePayment.class)
        .triggeringRecordFrom('orderId')
        .withParameter(API_ChargePayment.PARAM_AMOUNT, '99.99'))
    .then(new UTIL_AsyncChain.ApiStep(API_SendConfirmation.class)
        .triggeringRecordFrom('orderId')
        .withParameterFrom('recipient', 'customerEmail'))
    .onError(new NotifyAdminStep())
    .execute();
```

#### Builder Methods

| Method                                      | Purpose                                        |
|---------------------------------------------|------------------------------------------------|
| `new ApiStep(Type)`                         | Wrap an `API_Outbound` subclass                |
| `.credential(String)`                       | Override the Named Credential                  |
| `.withParameter(name, value)`               | Pass a static parameter to the handler         |
| `.withParameterFrom(paramName, contextKey)` | Resolve a parameter from a prior step's output |
| `.triggeringRecord(Id)`                     | Static triggering record ID                    |
| `.triggeringRecordFrom(contextKey)`         | Read triggering record ID from context         |
| `.withRetry(maxAttempts, baseBackoffSeconds)` | Retry the whole call automatically, up to `maxAttempts` tries (see below) |
| `.retryOn(new Set<Integer>{...})`             | Retry only these HTTP status codes; anything else fails permanently (see below) |

**Retrying an API step.** An `ApiStep` can retry a failed call itself, the chain equivalent of a
`ChainStep` opting in with `createRetryStrategy()`. Pass the total number of attempts including the
first, and a base backoff in seconds: `.withRetry(3, 30)` allows up to three tries. When you set this,
the chain owns the retry and the outbound engine's own rescheduling is switched off for that step, so
the call is retried once by the chain, never twice by both. The chain decides, and the handler's own
`createRetryStrategy()` is not asked; the handler's `getRetryableExceptionTypes()` still counts in the
one case described below. Leave `withRetry` off and the call behaves
exactly as before, with the outbound engine keeping sole charge of retries. The same whole-minute
backoff rule applies as for step retries.
By default every failed status is retried, with one exception that protects the external
system. To spend the budget only on failures that might heal, add
`.retryOn(new Set<Integer>{500, 503})`: a failed call whose status is outside the set fails
permanently on that attempt, because a deterministic status (a 400 returns 400 however often you
re-send it) can never be cured by retrying. `retryOn` has no effect without `withRetry`.

**The exception: a request that is not safe to repeat stops when the external system may have
acted on it.** A request is safe to repeat when it is a GET, PUT or DELETE, or when it carried
an Idempotency-Key. For any other request (a POST or PATCH with no key), the step fails for good,
without a retry, in three cases: no response came back, the response was a 500, 502 or 504, or
the external system accepted the request and the call then failed in your org. The external
system may already have done the work, so sending it again could do it twice. The step's message
gives the reason first, after the handler's name. The no-response case has one way back in: if the handler's
`getRetryableExceptionTypes()` returns a set that holds `System.CalloutException.class`, the step
keeps retrying after no response. A status you name in the step's `retryOn(...)` is your explicit choice
and is retried whatever the method, so name a 500, 502 or 504 there only when sending the
request twice is safe. A request that is safe to repeat keeps retrying in all three cases, and
so does a call the platform refused before it ever left your org (nothing reached the external
system). A handler that throws `UTIL_Exceptions.PermanentFailureException` fails the step at
once, whatever the method.

#### Reading Results from Downstream Steps

After an `ApiStep` runs, its result is stored in the context under the key `__apiResult_{stepIndex}` as a
`Map<String, Object>` with these keys: `success` (Boolean), `statusCode` (Integer), `apiCallId` (String), and
`errors` (String, present only on failure). The full response body lives on the `ApiCall__c` record, so a later step can
query it by ID when it needs the body.

```apex
public class ProcessPaymentResultStep extends UTIL_AsyncChain.ChainStep
{
    public override UTIL_AsyncChain.StepResult work(UTIL_AsyncChain.ChainContext context)
    {
        Map<String, Object> paymentResult = (Map<String, Object>)context.get('__apiResult_0');
        Boolean success = (Boolean)paymentResult.get('success');
        String apiCallId = (String)paymentResult.get('apiCallId');
        // Full response body is on ApiCall__c — query by apiCallId if needed
        return UTIL_AsyncChain.succeeded('Payment result processed');
    }
}
```

#### Standalone vs. Chain Execution

You can call the same `API_Outbound` handler on its own or as a chain step. Either way, the handler itself stays the
same:

| Mode           | Entry Point                                                                   | Lifecycle                         |
|----------------|-------------------------------------------------------------------------------|-----------------------------------|
| **Standalone** | `UTIL_HttpClient.useHandler(API_SendEmail.class).withParameter(...).invoke()` | Synchronous, caller controls      |
| **Chain step** | `.then(new UTIL_AsyncChain.ApiStep(API_SendEmail.class).withParameter(...))`  | Async, chain controls error/retry |

#### Error Handling

When the API call fails, the `ApiStep` returns `UTIL_AsyncChain.failed()` carrying the handler's error messages. Your
chain's `onError()` handler then fires (if you configured one), and the `ApiCall__c` record is still saved for audit.
Synchronous retries inside the step's own transaction still run normally via `UTIL_HttpClient`.
Whether asynchronous retries are scheduled depends on who owns the retry: with `withRetry`
configured the chain owns it and the outbound engine's own rescheduling is switched off for
that step; without `withRetry` the outbound engine keeps sole charge, exactly as for a
standalone call. With `withRetry` configured, your `onError` handler fires only after the
attempts are spent or the failure is declared permanent.

Use `continueOnError` when a failed API call should not stop the chain:

```apex
.then(new UTIL_AsyncChain.ApiStep(API_SendNotification.class)
    .triggeringRecordFrom('orderId'), true)  // non-fatal
```

### Testing Chains

Chains run as Queueables, so wrap the execution in `Test.startTest()` / `Test.stopTest()`. For a chain with more than
one step, also provide `AsyncOptions` (the platform built-in `System.AsyncOptions`, not a kern-namespaced type) and set
`maximumQueueableStackDepth` to match your chain's depth. That tells the platform it may run the chained Queueables one
after another inside the test.

Chains are on out of the box, so you don't need to seed anything to enable them in your tests. The `AsyncChain` flag
resolves through the `AsyncChainRuntimeSwitch__c` hierarchy setting, and with no setting record in place the answer is
that chains run.

```apex
@IsTest
private static void shouldCompleteThreeStepChain()
{
	AsyncOptions options = new AsyncOptions();
	options.maximumQueueableStackDepth = 4;

	Test.startTest();
	String executionId = UTIL_AsyncChain.newChain('TestChain')
		.then(new LoadDataStep())
		.then(new TransformDataStep())
		.then(new NotifyStep())
		.withAsyncOptions(options)
		.execute();
	Test.stopTest();

	Map<String, Object> status = UTIL_AsyncChain.getStatus(executionId);
	Assert.areEqual('Completed', (String)status.get('status'), 'Chain should complete');
	Assert.areEqual(3, (Decimal)status.get('totalSteps'), 'Should have 3 steps');
}
```

> **Why `maximumQueueableStackDepth`?** In production the framework sets the stack depth for you: the number of steps
> plus one, plus five spare levels for chains your steps launch. In tests, Salesforce defaults to a depth of 1, which
> blocks chained Queueables from running. Pass `withAsyncOptions()` to raise that limit for the test.

> **The framework creates and wires up the `ChainContext` for you.** You never construct it yourself. Drive chains
> through `newChain().then().execute()` inside `Test.startTest()`/`Test.stopTest()`, and the framework builds the
> context and hands it to each step. If you need to read or assert on the context, do it from inside your step's
> `work(ChainContext context)` override (where the context is handed to you), then check the chain's outcome with
> `UTIL_AsyncChain.getStatus(executionId)`.

---

## Common Patterns

The chain building blocks in this guide are designed to compose with the rest of the framework and the
platform. Each pattern below is complete, copy-ready code built only from the public pieces this guide
has already introduced.

### Protecting a struggling integration with a circuit breaker

When a downstream system starts failing, every new chain you launch at it burns async runs and retry
budget just to fail again. A circuit breaker stops that: after repeated failures the framework pauses
calls to the failing system for a cool-off period, then resumes once it recovers.

Chains do not need breaker machinery of their own. Gate the launch point with
[`UTIL_CircuitBreaker`](Resilience%20-%20Guide.md#circuit-breaker-util_circuitbreaker), and let the
chain's own completion and failure handlers record outcomes on the shared circuit:

```apex
public with sharing class Recipe_ChainCircuitBreaker_DEMO
{
	public static final String CIRCUIT_NAME = 'OrderExport';

	public static UTIL_CircuitBreaker.Breaker monitorCircuit()
	{
		return UTIL_CircuitBreaker.monitor(CIRCUIT_NAME)
				.withFailureThreshold(3)
				.withTimeout(120);
	}

	public static String launch()
	{
		if(!monitorCircuit().allowRequest())
		{
			return null; // you own this branch: skip, park the work, or surface it to the user
		}
		return UTIL_AsyncChain.newChain('Order Export')
				.then(new ExportStep())
				.onError(new RecordExportFailure())
				.onComplete(new RecordExportSuccess())
				.execute();
	}

	public with sharing class ExportStep extends UTIL_AsyncChain.ChainStep
	{
		public override UTIL_AsyncChain.StepResult work(UTIL_AsyncChain.ChainContext context)
		{
			return UTIL_AsyncChain.succeeded();
		}
	}

	public with sharing class RecordExportFailure extends UTIL_AsyncChain.ChainStep
	{
		public override UTIL_AsyncChain.StepResult work(UTIL_AsyncChain.ChainContext context)
		{
			monitorCircuit().recordFailure();
			return UTIL_AsyncChain.succeeded();
		}
	}

	public with sharing class RecordExportSuccess extends UTIL_AsyncChain.ChainStep
	{
		public override UTIL_AsyncChain.StepResult work(UTIL_AsyncChain.ChainContext context)
		{
			monitorCircuit().recordSuccess();
			return UTIL_AsyncChain.succeeded();
		}
	}
}
```

Three things make the composition work:

- **The launch point owns the "open" decision.** Only you know what an open circuit should mean here:
  skip the run, park the work for later, or tell the user. The framework cannot make that call for you,
  which is why the `else` branch is yours.
- **The handlers are the feedback loop.** `onError` records the failure, `onComplete` records the
  success. With `withFailureThreshold(3)`, three failed chains open the circuit and `allowRequest()`
  starts returning false; after the 120-second cool-off the breaker lets a probe through and closes
  again once calls succeed. The thresholds live on each `monitor()` call (only the counts and state
  are shared), which is why the recipe funnels every touch through the one configured method.
- **The circuit is shared across transactions.** Breaker state lives in Platform Cache, so a failure
  recorded by one chain's handler protects every later transaction that checks the same circuit name,
  with no extra plumbing.

Three caveats. The breaker only learns what the handlers tell it: register both `onError` and
`onComplete`, or outcomes go uncounted. A chain stopped by the [kill switch](#kill-switch) runs neither
handler, so those runs never reach the breaker. And a Platform Cache eviction resets the counts: treat
the breaker as a pressure-relief valve, not an exact meter.

See [Error Handling](#error-handling) for how `onError` behaves generally, and the
[Resilience Guide](Resilience%20-%20Guide.md#combining-retry-and-circuit-breaker) for combining the
breaker with retries inside a single callout.

### Pausing for an approval: two chains and a hand-off

A chain cannot sleep for days while a human decides. When your process has an approval in the middle,
end the first chain at the gate and start a second one when the decision lands. The record waiting for
the approval is your durable state, and it is also the join between the two legs.

The first leg prepares the work and stops:

```apex
public with sharing class Recipe_ApprovalHandOff_DEMO
{
	public static String startFirstLeg(Id recordId)
	{
		return UTIL_AsyncChain.newChain('Order Approval - Preparation')
				.withInitialContext('recordId', recordId)
				.then(new PrepareStep())
				.execute();
	}

	public with sharing class PrepareStep extends UTIL_AsyncChain.ChainStep
	{
		public override UTIL_AsyncChain.StepResult work(UTIL_AsyncChain.ChainContext context)
		{
			return UTIL_AsyncChain.succeeded('Prepared; waiting on approval');
		}
	}

	public with sharing class ContinueStep extends UTIL_AsyncChain.ChainStep
	{
		public override UTIL_AsyncChain.StepResult work(UTIL_AsyncChain.ChainContext context)
		{
			return UTIL_AsyncChain.succeeded();
		}
	}
}
```

The second leg is an invocable that a record-triggered flow calls when the approval field changes.
The shipped Flow action covers only asynchronous web-service calls, which is why this pattern brings
its own invocable; it is a dozen lines:

```apex
public with sharing class Recipe_ApprovalContinuation_DEMO
{
	public class Request
	{
		@InvocableVariable(required=true) public Id recordId;
	}

	@InvocableMethod(label='Continue After Approval')
	public static void start(List<Request> requests)
	{
		if(requests.size() != 1)
		{
			throw new IllegalArgumentException('Continue After Approval handles one request per invocation.');
		}
		UTIL_AsyncChain.newChain('Order Approval - Continuation')
				.withInitialContext('recordId', requests[0].recordId)
				.then(new Recipe_ApprovalHandOff_DEMO.ContinueStep())
				.execute();
	}
}
```

Three facts shape the hand-off:

- **The record carries the story, not the chain.** Chain context does not survive the gap: whatever
  the continuation needs must live on the record (or be re-queried from it) and re-enter through
  `withInitialContext`. If you want to navigate back to the first leg later, store the run Id that
  `startFirstLeg` returns in a field on the waiting record.
- **Each leg keeps its own tracking identifier.** A chain run owns its correlation ID exclusively, so
  the two legs are separate runs with separate identifiers. The record joins them: log entries written
  for the record tell the whole story in one place. Each leg's
  [live activity stream](#the-live-activity-stream) follows only its own run, so look the legs up
  separately in the Chain Monitor, or query the record's log entries for both.
- **Nothing times the gap out.** If the approval never comes, nothing runs and nothing alerts. Put the
  deadline on the waiting record (a scheduled path or an escalation flow), not on the chain.

Wire it up declaratively: a record-triggered flow on the approval field change passes the record Id to
the `Continue After Approval` action. See [Context Sharing](#context-sharing) for what belongs in
initial context, and [Monitoring](#monitoring) for finding both runs in the Chain Monitor.

### Running a chain on a schedule

When you want a chain every night, you do not need new machinery: a small schedulable builds the chain,
and a [`ScheduledJob__c`](#declarative-scheduling-with-scheduledjob__c) record decides when it runs,
with what parameters, in which timezone. Admins change the schedule without a deployment. The same recipe
works when the record is set to run on the [job runner](#running-many-jobs-on-one-job-runner).

```apex
@SuppressWarnings('PMD.AvoidGlobalModifier')
global inherited sharing class Recipe_ScheduledChain_DEMO extends SCHED_Base
{
	public static final String DEDUPLICATION_KEY = 'NightlyOrderExport';

	public override List<DTO_ScheduledParameterDefinition> getParameterDefinitions()
	{
		return new List<DTO_ScheduledParameterDefinition>{
				DTO_ScheduledParameterDefinition.of('batchLimit').asNumeric().withDefault('200')
		};
	}

	public void execute(SchedulableContext context)
	{
		startExport(getNumericParameter('batchLimit'));
	}

	public static String startExport(Integer batchLimit)
	{
		return UTIL_AsyncChain.newChain('Nightly Order Export')
				.withInitialContext('batchLimit', batchLimit)
				.withDeduplicationKey(DEDUPLICATION_KEY)
				.then(new ExportStep())
				.execute();
	}

	public with sharing class ExportStep extends UTIL_AsyncChain.ChainStep
	{
		public override UTIL_AsyncChain.StepResult work(UTIL_AsyncChain.ChainContext context)
		{
			return UTIL_AsyncChain.succeeded();
		}
	}
}
```

Then schedule it as a configuration record, the same declarative path as every scheduled job here:

```apex
ScheduledJob__c nightlyExport = new ScheduledJob__c(
		SchedulerName__c = 'Nightly Order Export',
		ClassName__c = 'Recipe_ScheduledChain_DEMO',
		CronExpression__c = '0 0 3 * * ?',
		IsActive__c = true,
		Parameters__c = new DTO_NameValues(new Map<String, String>{ 'batchLimit' => '200' }).serialize()
);
DML_Builder.newTransaction().doInsert(nightlyExport).execute();
```

Three details carry the pattern:

- **The record is the schedule.** Inserting it schedules the class; deactivating it aborts the job. The
  class stays `global` because the framework instantiates it across the namespace boundary, and the
  chain assembly lives in its own method so the run Id stays observable to callers and tests.
- **Parameters flow from configuration to context.** The record's `Parameters__c` feeds the typed
  accessors (`getNumericParameter` here), which feed `withInitialContext`. Change the batch limit on
  the record and the next run picks it up, no deployment involved.
- **Overlap is a non-event.** If last night's run is somehow still active at three in the morning,
  `withDeduplicationKey` hands the new request the active run instead of starting a duplicate. See
  [Preventing duplicate runs](#preventing-duplicate-runs) for the key's full behaviour.

For scheduled work that is not a chain (a batch job, a one-off cleanup), see
[Creating Custom Configurable Schedulers](#creating-custom-configurable-schedulers); the two examples
are siblings on the same declarative path.

### Calling an external system only after the transaction commits

An order completes, and your billing system must hear about it. The tempting shape, calling out first
and saving second, has two famous failure modes: the ghost call (the callout fires, then the save
rolls back, and the far system now believes something your database does not) and the silently lost
intent (fire-and-forget delivery nobody notices failing). This pattern closes both, and converts the
remaining case, committed data whose delivery keeps failing, into a loud one.

The platform hands chains the two guarantees this pattern needs. Callouts are forbidden inside a
trigger, so the callout-first shape is off the table to begin with. And an enqueue is
transaction-bound: if the save rolls back, the enqueue rolls back with it, and no call ever fires.

Three pieces, all composition. The one-line trigger file that hands control to the framework:

```apex
trigger TRG_Case on Case (after update)
{
	new TRG_Dispatcher().run();
}
```

The trigger action that detects the transition and starts ONE chain per trigger invocation (the
platform hands very large saves to the trigger in batches of 200, each starting its own chain),
carrying one web-service step per closed case:

```apex
public with sharing class Recipe_CommittedDelivery_DEMO extends TRG_Base implements IF_Trigger.AfterUpdate
{
	public static final String STATUS_CLOSED = 'Closed';
	public static final String CHAIN_NAME = 'Closed Case Delivery';
	public static final Set<Integer> RETRYABLE_STATUSES = new Set<Integer>{ 500, 502, 503, 504 };

	public void afterUpdate(List<SObject> newRecords, List<SObject> oldRecords)
	{
		Map<Id, Case> oldById = new Map<Id, Case>((List<Case>) oldRecords);
		List<Case> justClosed = new List<Case>();
		for(Case currentCase : (List<Case>) newRecords)
		{
			if(currentCase.Status == STATUS_CLOSED && oldById.get(currentCase.Id)?.Status != STATUS_CLOSED)
			{
				justClosed.add(currentCase);
			}
		}
		if(justClosed.isEmpty())
		{
			return;
		}
		UTIL_AsyncChain.ChainBuilder delivery = UTIL_AsyncChain.newChain(CHAIN_NAME);
		for(Case closedCase : justClosed)
		{
			delivery.then(new UTIL_AsyncChain.ApiStep(Recipe_CaseDelivery_SERVICE.class)
					.triggeringRecord(closedCase.Id)
					.withRetry(3, 60)
					.retryOn(RETRYABLE_STATUSES));
		}
		delivery.execute();
	}
}
```

And the delivery service, an ordinary outbound handler with one addition: it stamps a record-grain
idempotency key before sending, so an at-least-once delivery cannot double-apply (the far system can
recognise a repeat delivery for the same case and return the first result instead of re-running it).
Its request and response DTOs are the standard outbound shape from the
[Web Services Guide](Web%20Services%20-%20Guide.md):

```apex
public with sharing class Recipe_CaseDelivery_SERVICE extends API_Outbound
{
	public static final String IDEMPOTENCY_KEY_PREFIX = 'case-delivery-';

	public override void configure()
	{
		super.configure();
		requestPayload = new DTO_Request();
		responsePayload = new DTO_Response();
		defaultMockBody = '{"status": "received"}';
	}

	public override void prepareRequest()
	{
		super.prepareRequest();
		apiCall.IdempotencyKey__c = IDEMPOTENCY_KEY_PREFIX + apiCall.TriggeringRecordId__c;
	}
}
```

Register the pieces as configuration: a `TriggerSetting` record for `Case`; a `TriggerAction` record
with `Event__c = After Update`, `ApexClassName__c = Recipe_CommittedDelivery_DEMO`, and
`FailureAction__c = LogAndContinue`, so a delivery hiccup never blocks the save; and the service's own
`ApiSetting` record (class name, endpoint, Log Issues). The [Triggers Guide](Triggers%20-%20Guide.md)
walks through the trigger records, and the [Web Services Guide](Web%20Services%20-%20Guide.md) the
service record.

After commit comes the loud half. Each step retries only the statuses worth retrying (`retryOn` keeps
deterministic client errors out of the retry budget). The failure reason lands on the call record. A
delivery that exhausts its retries is set aside as an `ApiIssue__c` record for inspection rather than
silently lost; that safety net is on when the service's `ApiSetting` record has Log Issues enabled, as
the registration above does. The chain's terminal state and log entry name what happened, and the
[watchdog](#monitoring-async-chain-failures) flags anything silently stuck. See
[ApiStep: Web Service Integration](#apistep-web-service-integration) for the step's full surface.

Two warnings. Do not reach for "Publish Immediately" platform events for this job: they fire even when
the publishing transaction rolls back, the exact opposite of what this pattern promises. And a chain
carries up to 50 steps by default; if one save can close more than that, raise the ceiling with
`withMaxSteps` or split the batch.

---

## Scheduler Framework

When you need a job to run on a recurring schedule (nightly, hourly, every Monday), you have two routes. The recommended
one lets admins create and change schedules as configuration records, with no code deployment. The other is the
platform's own `System.schedule()` call, for full programmatic control. This section covers both.

> **Step-by-step walkthrough:** [Fast Start - Scheduled Jobs](Fast%20Start%20-%20Scheduled%20Jobs.md) schedules a class
> with a record, moves it onto the job runner, and reads a succeeded and a failed run, in about 25 minutes. This section
> is the deep reference behind that Fast Start.

### Scheduler Architecture

```text
+---------------------------------------------------------------------------+
|                           SCHEDULER FRAMEWORK                             |
+---------------------------------------------------------------------------+
|                                                                           |
|   +-------------------------------------------------------------------+  |
|   |                    DECLARATIVE (Recommended)                       |  |
|   |                                                                   |  |
|   |   +-----------------+     +-----------------+     +-----------+   |  |
|   |   | ScheduledJob__c |---->| TRG_ScheduledJob |---->| CronTrigger|  |  |
|   |   | (Custom Object) |     | (Trigger)       |     | (Platform) |  |  |
|   |   |                 |     |                 |     |            |  |  |
|   |   | * ClassName     |     | * Validates     |     | * Executes |  |  |
|   |   | * CronExpr      |     | * Starts/Stops  |     |   on       |  |  |
|   |   | * Attributes    |     | * Updates ID    |     |   schedule |  |  |
|   |   | * Active        |     |                 |     |            |  |  |
|   |   +-----------------+     +-----------------+     +------------+  |  |
|   |                                                                   |  |
|   |   Benefits: No deployment, UI-manageable, audit trail, validation |  |
|   +-------------------------------------------------------------------+  |
|                                                                           |
|   +-------------------------------------------------------------------+  |
|   |                    PROGRAMMATIC                                    |  |
|   |                                                                   |  |
|   |   System.schedule('Job Name', cronExpr, new MyScheduler());       |  |
|   |                                                                   |  |
|   |   Benefits: Full control, script-based, one-off jobs              |  |
|   +-------------------------------------------------------------------+  |
|                                                                           |
|   +-------------------------------------------------------------------+  |
|   |                    SCHEDULER TYPES                                 |  |
|   |                                                                   |  |
|   |   +-------------------+         +-----------------------------+   |  |
|   |   |   Schedulable     |<--ext---|   IF_Schedulable              |   |  |
|   |   |   (Standard)      |         |   (KernDX)                    |   |  |
|   |   +-------------------+         +-----------------------------+   |  |
|   |   |                   |         |                             |   |  |
|   |   |   execute(ctx)    |         |   getParameterDefinitions() |   |  |
|   |   |                   |         |   setParameterValues(DTO)   |   |  |
|   |   |   Fixed behavior  |         |   execute(ctx)              |   |  |
|   |   |                   |         |   (SCHED_Base impl)         |   |  |
|   |   +-------------------+         +-----------------------------+   |  |
|   |                                                                   |  |
|   +-------------------------------------------------------------------+  |
|                                                                           |
+---------------------------------------------------------------------------+
```

### Declarative Scheduling with [`ScheduledJob__c`](reference/objects/ScheduledJob__c.md)

**This is the recommended approach** for managing scheduled jobs in production.

#### How It Works

You manage scheduled jobs by editing records, and the framework handles the platform plumbing for you:

1. **You create** a [`ScheduledJob__c`](reference/objects/ScheduledJob__c.md) record with a class name, a cron expression, and any optional attributes.
2. **A trigger fires** on insert, update, or delete.
3. **The handler validates** that the class exists and implements the right interface.
4. **The job is scheduled** automatically once `IsActive__c = true`.
5. **The job ID is stored** in `ScheduledJobId__c` so you can monitor it.
6. **Changes apply by themselves:** updating the record reschedules the job, deleting it aborts the job.

#### ScheduledJob__c Fields

The full field reference for the scheduling record is below.

<details>
<summary>Every ScheduledJob__c field</summary>

| Field               | Type                   | Description                                                                                                                                                  |
|---------------------|------------------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `SchedulerName__c`  | Text                   | Human-readable name for the job                                                                                                                              |
| `ClassName__c`      | Text                   | Fully qualified class name (with namespace if needed)                                                                                                        |
| `CronExpression__c` | Text                   | Standard Salesforce [cron expression](https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_scheduler.htm)                           |
| `IsActive__c`       | Checkbox               | When true, job runs; when false, job stopped                                                                                                                 |
| `Parameters__c`     | Long Text Area(131072) | JSON-serialized `DTO_NameValues` containing name/value pairs for configurable schedulers                                                                     |
| `Description__c`    | Long Text              | Documentation of job purpose                                                                                                                                 |
| `Timezone__c`       | Text                   | IANA TimeZoneSidKey of the cron author (e.g., `Africa/Johannesburg`). Used for timezone-aware scheduling                                                     |
| `ScheduledJobId__c` | Text                   | Auto-populated with CronTrigger ID                                                                                                                           |
| `ExecutionMode__c`  | Picklist               | Where the job runs: its own scheduled job (the default) or the job runner                                                                                    |
| `RunPriority__c`    | Number                 | On the job runner: lower numbers start first when several jobs are due at the same check; blank goes last                                                    |
| `OverlapPolicy__c`  | Picklist               | On the job runner: Skip (the default) records a due run as Skipped while the previous run is still running; Allow starts it anyway                           |
| `NextRunAt__c`      | Datetime               | On the job runner: when the job is next due. Written by the framework                                                                                        |
| `LastRunAt__c`      | Datetime               | When the most recent run on the job runner finished. Written by the framework                                                                                |
| `LastRunOutcome__c` | Picklist               | Succeeded, Failed, Skipped or Parked: the most recent event on a job on the runner. Written by the framework                                                 |
| `LastRunReason__c`  | Picklist               | On the job runner: why the most recent run was skipped or parked, as one of five fixed reasons; blank after a success or a failure. Written by the framework |
| `LastRunJobId__c`   | Text                   | The platform job id of the most recent run, written when the run is queued                                                                                   |

</details>

#### Example: Create a Purge Job via UI

```apex
// Create a job that purges old log records nightly
ScheduledJob__c purgeJob = new ScheduledJob__c();
purgeJob.SchedulerName__c = 'Purge Old Application Logs';
purgeJob.ClassName__c = 'SCHED_PurgeRecords';
purgeJob.CronExpression__c = '0 0 2 * * ?';  // Daily at 2 AM
purgeJob.IsActive__c = true;
purgeJob.Description__c = 'Deletes LogEntry__c records older than 90 days to manage storage';
purgeJob.Parameters__c = new DTO_NameValues(new Map<String, String>{
	'objectName' => 'LogEntry__c', 'minimumNumberOfDays' => '90', 'batchSize' => '2000'
}).serialize();

DML_Builder.newTransaction().doInsert(purgeJob).execute();
// Job starts automatically!
```

#### Common Cron Expressions

| Schedule                | Cron Expression        | Description                |
|-------------------------|------------------------|----------------------------|
| Daily at 2 AM           | `0 0 2 * * ?`          | Every day at 2:00 AM       |
| Hourly                  | `0 0 * * * ?`          | Every hour on the hour     |
| Weekly Sunday 1 AM      | `0 0 1 ? * SUN`        | Every Sunday at 1:00 AM    |
| Monthly 1st at midnight | `0 0 0 1 * ?`          | First of month at midnight |
| Weekdays 8 AM           | `0 0 8 ? * MON-FRI`    | Monday-Friday at 8:00 AM   |

A scheduled job in its own mode fires at most once an hour. Salesforce takes a single number in the minutes field, never `*`, a step
such as `*/15`, or a list such as `0,15,30,45`, and refuses the record at save if you try. To run a job more often than hourly,
put it on the [job runner](#running-many-jobs-on-one-job-runner), which reads the minutes field itself: `0 */15 * * * ?`
then means every fifteen minutes and costs no scheduled-job slot of its own.

#### Timezone Awareness

Here is a subtle trap the framework removes for you. `System.schedule()` reads cron expressions in the **running user's
timezone**, not the author's. So if User A (SAST, UTC+2) sets up a job for noon and User B (PST, UTC-8) later activates
it, the job fires at noon PST, 10 hours later than intended. The scheduler framework corrects this automatically.

**How it works:**

1. When a `ScheduledJob__c` record is saved via the LWC editor, `Timezone__c` is populated with the authoring user's IANA TimeZoneSidKey
2. When the trigger schedules the job, the framework automatically adjusts the cron hours (and minutes for half-hour timezones like India UTC+5:30) from the stored timezone to the
   running user's timezone
3. The adjusted cron is passed to `System.schedule()`, so the job fires at the author's intended local time of day in the running user's timezone

**One caveat, daylight saving.** The timezone offset is worked out once, when the job is scheduled, and
baked into the stored cron. If the author's zone and the runner's zone move onto or off daylight saving
on different dates, the job can fire an hour early or late for the weeks when one zone has shifted and
the other has not, until the job is saved again. For a job that must hit an exact wall-clock time all
year across such a pair of zones, re-save it after a daylight-saving change.

**Edge cases handled:**

| Scenario                                       | Behaviour                                                     |
|------------------------------------------------|---------------------------------------------------------------|
| Same timezone (author = runner)                | No shift needed; the framework short-circuits                                      |
| Half-hour timezones (e.g., India UTC+5:30)     | Minutes field also shifted                                    |
| Day rollover (hours cross midnight)            | Day-of-week and day-of-month shifted accordingly              |
| Day-of-month boundary (would produce 0 or >31) | Day-of-month left unchanged to avoid invalid cron             |
| Wildcard/step hours (`*`, `*/2`)               | Not shifted; it fires at regular intervals regardless           |
| `L`/`W` day-of-month suffixes                  | Not shifted; relative expressions cannot be reliably shifted |

### Running many jobs on one job runner

Salesforce gives an org 100 scheduled-job slots in total, shared with every installed package, and a single scheduled job fires
at most once an hour. A job that must run every five minutes therefore costs twelve of those slots. The job runner removes
both limits for the jobs you put on it: the runner takes a fixed handful of slots (one to twelve, your choice), and every job you
add after that is free and may run as often as every five minutes.

#### What the job runner is, and is not

The runner is a scheduling mechanism, not a second orchestration framework. It is a few ordinary scheduled jobs, one per minute
mark, that each run the same small Kern class, `SCHED_JobRunner`. Every time one of them fires, the runner checks for due jobs
and starts every job whose record is set to run on it and is due. Once a run is started, it is an ordinary scheduled job: the
same class, the same parameters, the same `execute` method. A job that needs several steps builds an async chain, exactly as it
does today.

#### Turning it on

Open Kern Home. The job runner card under the readiness banner offers Activate; choose how often the runner checks for due
jobs. Every hour costs one slot, every 30 minutes two, every 15 minutes four, every 10 minutes six, every 5 minutes twelve. The
runner's own records appear in Scheduled Jobs like any other schedule, named "Job runner :00", ":15" and so on. Only Health
Check may create or replace them. Deleting one is allowed, but the runner then misses that minute mark (an hourly runner stops
altogether) until you Repair it; the Job Runner row in Health Check says so.

#### Putting a job on the runner

Edit the job's record and set Execution mode to Job runner. You need the Manage Job Runner permission (the Kern Job Runner
Management permission set) to do so, because jobs on the runner run as the user who activated it (see below). A job on the runner
keeps its class, parameters, time zone and description; two fields join them:

- Run priority: when several jobs are due at the same check, lower numbers start first and blank goes last. A preference, not a
  guarantee: when a check has already started as many jobs as it may, a low-priority job waits for the next one.
- Overlap policy: Skip (the default) records a due run as Skipped while the previous run is still running; Allow starts it anyway.
  A run that never finishes skips every following occurrence until it does.

The record shows the runner's view of the job: Next run, Last run, Outcome (Succeeded, Failed, Skipped or Parked) and, for a
skipped or parked run, the Reason in a fixed sentence. A failed or parked run's detail is in its log entry, which the View log
link beside the outcome opens. Run now starts the job immediately, as you, without changing its schedule.

#### How a run is timed

- The runner checks for due jobs at a fixed interval. A job runs at the first check on or after its scheduled time: a job set to
  09:17 on a runner that checks every 15 minutes runs at 09:30.
- A due occurrence is used up when its run starts, not when it succeeds. A run that fails does not run again at the next check;
  retrying is the job's own business. Its next occurrence runs as scheduled.
- A missed occurrence (the runner was stopped, or the org was busy) runs once, at the first check after the runner is back. Three
  hours of downtime give one run, not thirty-six.
- On the runner, Kern reads the cron expression itself, so the minutes field may carry `*`, a step such as `*/15`, a range or a
  list. Every other field keeps its Salesforce meaning, including `L`, `W`, `LW`, `nL` and `n#m`. The expression is read in the
  record's time zone.
- Daylight saving follows two rules. When the hours field is `*` (every N minutes), the job fires once per elapsed interval and
  neither skips nor doubles across a change. When the hours field names hours, the job follows the local clock: a time that falls
  into the spring-forward gap fires at the moment the clocks jump, and a time that happens twice in the autumn fires once, at the
  earlier of the two. An hour step such as `*/2` therefore shifts by one hour once a year.
- The runner looks four years ahead for a job's next run: four years, a safety bound rather than a limit you plan around. An
  expression that never fires in that window (a year field in the past, 30 February) is refused at save; if a job's class can no
  longer be found or its next run can no longer be worked out, the job is parked with the reason on its record, and tried again a
  day later, or sooner after an edit to its expression, time zone, mode or active flag.

#### Who the jobs run as

Every job on the runner runs as the user who activated it, because that user owns the runner's scheduled jobs. Activate the runner
as an integration user that holds the Kern Job Runner Management permission set and the permissions every job needs. On its own the
set lets a user create and edit jobs and run them now; deleting one needs the Kern Administrator set, and activating the runner needs
access to Health Check. Run now runs as the person who presses it. Apex cannot schedule a job as another user, so the card cannot
pick a service account for you; it names the activator, shows whether that user is still active, and offers Repair (activation
again, as you) when the activator has left.

#### Calling out, and building chains

A job on the runner executes inside a queued job that allows callouts, so it may call an external system directly. A job that
builds an async chain works unchanged on the runner: the chain runs on queued jobs and costs no slot.

#### If your job reads the scheduling context

A job on the runner receives a Kern scheduling context whose `getTriggerId()` returns the id of the run itself, not of a
scheduled job. Logging or correlating on it works unchanged; do not pass it to `System.abortJob`.

#### When the clock stops, and when not to use it

Health Check reports three readings on the runner: **Job Runner** (whether it has checked for due jobs recently, whether all its
scheduled jobs are still there, and whether the user it runs as is still active), **Jobs Waiting for the Job Runner** (whether a
job is set to run on a runner that is not there) and **Job Runner Capacity** (how many of the org's scheduled-job slots are in
use, and, while a runner is active, whether its last check started every job that was due). The first two each carry the
button that fixes them, Repair on the first and Activate on the second; the capacity reading says what to change instead.
A handful of
daily or weekly jobs is fine on its own slots and gains nothing from the runner. Reach for it when jobs must run more often than
hourly, when the org is near the cap, or when re-scheduling after every upgrade has become a chore.

### Built-in Schedulers

Six housekeeping and framework jobs ship ready to use. You schedule them by configuration alone, no code:

| Scheduler                                                                        | Purpose                                                                      | Key Attributes                                                    |
|----------------------------------------------------------------------------------|------------------------------------------------------------------------------|-------------------------------------------------------------------|
| [`SCHED_PurgeRecords`](reference/apex/SCHED_PurgeRecords.md)                     | Delete old records                                                           | `objectName`, `minimumNumberOfDays`, `dateFieldName`, `batchSize` |
| [`SCHED_DeactivateUsers`](reference/apex/SCHED_DeactivateUsers.md)               | Deactivate inactive users                                                    | `profileNames`, `minimumNumberOfDays`, `batchSize`                |
| [`SCHED_PerformBatchedCallouts`](reference/apex/SCHED_PerformBatchedCallouts.md) | Process queued callouts                                                      | None                                                              |
| [`SCHED_ProcessLoginHistory`](reference/apex/SCHED_ProcessLoginHistory.md)       | Process login records                                                        | None (batch size set by an `AsynchronousJobSetting__mdt` record)  |
| [`SCHED_ChainWatchdog`](reference/apex/SCHED_ChainWatchdog.md)                   | Find silently stuck async chains and mark them Stalled                       | `StaleThresholdMinutes`, `BatchSize`                              |
| [`SCHED_JobRunner`](reference/apex/SCHED_JobRunner.md)                           | Check for jobs due on the job runner; Health Check schedules it for you      | None                                                              |

> **See Also:** [`DTO_NameValues`](reference/apex/DTO_NameValues.md) for attribute parsing utilities.

### Creating Custom Configurable Schedulers

When the built-in jobs don't cover your case, you can write your own scheduler that still accepts parameters from a
record. Extend `SCHED_Base`, declare the parameters your job expects, and read their typed values at run time. The
example below syncs records with an external system, taking its endpoint, object, and batch size from configuration:

```apex
/**
 * @description Custom scheduler that syncs data with external system.
 *              Extends SCHED_Base for runtime configuration with typed parameters.
 */
global inherited sharing class SCHED_ExternalSync extends SCHED_Base
{
	/**
	 * @description Declares the parameters supported by this job.
	 *
	 * @return List of parameter definitions.
	 */
	public override List<DTO_ScheduledParameterDefinition> getParameterDefinitions()
	{
		return new List<DTO_ScheduledParameterDefinition>
		{
				DTO_ScheduledParameterDefinition.of('endpointName').required(),
				DTO_ScheduledParameterDefinition.of('objectName').required(),
				DTO_ScheduledParameterDefinition.of('batchSize').asNumeric().withDefault('200')
		};
	}

	/**
	 * @description Executes the scheduled sync
	 *
	 * @param context The schedulable context
	 */
	public void execute(SchedulableContext context)
	{
		// Get typed configuration from resolved parameters
		String endpointName = getTextParameter('endpointName');
		Integer batchSize = getNumericParameter('batchSize');
		String objectName = getTextParameter('objectName');

		// Query records to sync using QRY_Builder fluent API
		QRY_Builder.Builder query = QRY_Builder.selectFrom(
				UTIL_SObjectDescribe.getSObjectTypeByName(objectName))
			.condition('NeedsSync__c').equals(true);

		// Launch async processing
		UTIL_AsynchronousJobLauncher.DTO_AsynchronousJobRequest request =
			new UTIL_AsynchronousJobLauncher.DTO_AsynchronousJobRequest(query)
				.withBatchSize(batchSize);

		UTIL_AsynchronousJobLauncher.process(request, new SyncProcessor(endpointName));
	}
}

// Configure via ScheduledJob__c:
// Parameters__c = new DTO_NameValues(new Map<String, String>{
//     'endpointName' => 'ExternalCRM', 'objectName' => 'Account', 'batchSize' => '100'
// }).serialize()
```

---

## Transaction Correlation in Async Operations

When you do this yourself in plain Queueable or Batch code (rather than through a chain), you can still link all the logs
from one user action together using a correlation ID, the single tracking ID that follows that action across
transactions. [`LOG_Builder`](reference/apex/LOG_Builder.md) carries that ID across async boundaries for you.

### Why Correlation Matters

When a synchronous operation spawns async jobs, the logs from those jobs look unrelated to where they came from. A
correlation ID stitches them back together:

```text
Without Correlation:                    With Correlation:
---------------------                   -----------------
Log 1: [abc123] Started                 Log 1: [CORR-001] Started
Log 2: [def456] Processing...           Log 2: [CORR-001] Queued async
Log 3: [ghi789] Error!                  Log 3: [CORR-001] Processing... (async)
                                        Log 4: [CORR-001] Error! (async)
(Which logs are related?)               (All logs for CORR-001 are linked!)
```

### Correlation Flow

```text
+---------------------------------------------------------------------------+
|                         CORRELATION ACROSS BOUNDARIES                     |
+---------------------------------------------------------------------------+
|                                                                           |
|   TRANSACTION 1 (Sync)              TRANSACTION 2 (Async)                |
|   ---------------------             ---------------------                |
|                                                                           |
|   +---------------------+           +---------------------+              |
|   | startCorrelation()  |           | hydrateContext()    |              |
|   | CorrelationId: ABC  | --------> | CorrelationId: ABC  |              |
|   | TransactionId: T1   |  context  | TransactionId: T2   |              |
|   |                     |  string   | ParentTxnId: T1     |              |
|   +---------------------+           +---------------------+              |
|           |                                   |                           |
|           v                                   v                           |
|   +---------------------+           +---------------------+              |
|   | Log: "Starting..."  |           | Log: "Processing.." |              |
|   | CorrelationId: ABC  |           | CorrelationId: ABC  |              |
|   +---------------------+           +---------------------+              |
|           |                                   |                           |
|           v                                   v                           |
|   +---------------------+           +---------------------+              |
|   | serializeContext()  |           | Log: "Complete"     |              |
|   | Returns: "{...}"    |           | CorrelationId: ABC  |              |
|   +---------------------+           +---------------------+              |
|                                                                           |
|   All logs with CorrelationId = ABC can be queried together              |
|                                                                           |
+---------------------------------------------------------------------------+
```

### Queueable Pattern with Correlation

```apex
public with sharing class MyAsyncProcessor implements Queueable
{
	private List<Id> recordIds;
	private String loggerContext;  // Stores serialized correlation context

	public MyAsyncProcessor(List<Id> recordIds)
	{
		this.recordIds = recordIds;
		// CAPTURE context before enqueuing (in sync transaction)
		this.loggerContext = LOG_Builder.serializeContext();
	}

	public void execute(QueueableContext context)
	{
		// RESTORE context at start of async transaction
		LOG_Builder.hydrateContext(loggerContext);

		// All logs now have same CorrelationId as the sync transaction
		LOG_Builder.build().info('Processing ' + recordIds.size() + ' records').emitAt('MyAsyncProcessor.execute');

		// ... processing logic ...

		LOG_Builder.build().info('Processing complete').emitAt('MyAsyncProcessor.execute');
	}
}

// Usage:
LOG_Builder.startCorrelation();  // Generate CorrelationId
LOG_Builder.build().info('Queueing async job').emitAt('MyService.process');
System.enqueueJob(new MyAsyncProcessor(recordIds));  // Context captured in constructor
```

### Batch Apex Pattern with Correlation

```apex
public with sharing class MyBatchProcessor implements Database.Batchable<SObject>
{
	private String loggerContext;

	public MyBatchProcessor()
	{
		// Capture context when batch is created (before execution)
		this.loggerContext = LOG_Builder.serializeContext();
	}

	public Database.QueryLocator start(Database.BatchableContext context)
	{
		LOG_Builder.hydrateContext(loggerContext);
		LOG_Builder.build().info('Batch starting').emitAt('MyBatchProcessor.start');
		return QRY_Builder.selectFrom(Account.SObjectType).toQueryLocator();
	}

	public void execute(Database.BatchableContext context, List<Account> scope)
	{
		// MUST restore context in EACH execute - each is separate transaction
		LOG_Builder.hydrateContext(loggerContext);
		LOG_Builder.build().debug('Processing batch of ' + scope.size()).emitAt('MyBatchProcessor.execute');
		// ... processing ...
	}

	public void finish(Database.BatchableContext context)
	{
		LOG_Builder.hydrateContext(loggerContext);
		LOG_Builder.build().info('Batch complete').emitAt('MyBatchProcessor.finish');
	}
}
```

### Key Correlation Methods

All methods are available on [`LOG_Builder`](reference/apex/LOG_Builder.md):

| Method                           | When to Use                            | Description                                                  |
|----------------------------------|----------------------------------------|--------------------------------------------------------------|
| `startCorrelation()`             | Start of user action/API call          | Generates new CorrelationId                                  |
| `serializeContext()`             | Before enqueuing async job             | Returns JSON string of current context                       |
| `serializeContext(String)`       | Giving a separate run its own identity | Returns JSON context carrying the correlation id you pass in |
| `hydrateContext(String)`         | Start of async job execute()           | Restores context from serialized string                      |
| `setCorrelationId(String)`       | When receiving external correlation    | Sets specific ID from external system                        |
| `setParentTransactionId(String)` | Manual parent linking                  | Links to specific parent transaction                         |

The `rootCorrelationId` property answers the tracking ID of the action that started everything, from anywhere, the
way `correlationId` answers the live one; the two differ inside a chain run, where the live ID is the run's own.

The one-argument form matters when a restarted run should read as its own story rather than a continuation of the one that spawned it. Pass the new correlation id and the job you hand it to gets a clean logging identity, with none of the current transaction's lineage attached.

---

## Capability Matrix (for Analysts)

This section is for analysts and admins deciding what they can set up without a developer. It lists the tasks that ship
ready to schedule, the ones that need a small amount of custom code, and the configuration options for the built-in jobs.

### What Can Be Scheduled?

| Task Type                 | Built-in Solution                                                                | Custom Required | Effort         |
|---------------------------|----------------------------------------------------------------------------------|-----------------|----------------|
| Delete old records        | [`SCHED_PurgeRecords`](reference/apex/SCHED_PurgeRecords.md)                     | No              | Configure only |
| Deactivate inactive users | [`SCHED_DeactivateUsers`](reference/apex/SCHED_DeactivateUsers.md)               | No              | Configure only |
| Process queued callouts   | [`SCHED_PerformBatchedCallouts`](reference/apex/SCHED_PerformBatchedCallouts.md) | No              | Configure only |
| Sync with external system | -                                                                                | Yes             | Medium         |
| Generate reports          | -                                                                                | Yes             | Medium         |
| Send batch emails         | -                                                                                | Yes             | Low            |
| Data quality checks       | -                                                                                | Yes             | Medium         |

### Configuration Reference: [`SCHED_PurgeRecords`](reference/apex/SCHED_PurgeRecords.md)

| Attribute             | Required | Default       | Description                                       |
|-----------------------|----------|---------------|---------------------------------------------------|
| `objectName`          | **Yes**  | -             | API name of object to purge (e.g., `LogEntry__c`) |
| `minimumNumberOfDays` | No       | 90            | Records older than this are deleted               |
| `dateFieldName`       | No       | `CreatedDate` | Field to check age against                        |
| `batchSize`           | No       | 2000          | Records per batch transaction                     |
| `allOrNothing`        | No       | false         | If true, rollback batch on any error              |

**Example Parameters__c value** (set via `DTO_NameValues`)**:**

```json
{"objectName":"LogEntry__c","minimumNumberOfDays":"90","batchSize":"1000"}
```

**Purging old chain records safely.** `AsyncChainExecution__c` records build up as chains run, so purge them on a schedule the same way you would application logs, by pointing `SCHED_PurgeRecords` at the object. The setting that matters is the date field: purge by `CompletedAt__c`, not by the default `CreatedDate`.

```json
{"objectName":"AsyncChainExecution__c","dateFieldName":"CompletedAt__c","minimumNumberOfDays":"30","batchSize":"200"}
```

`CompletedAt__c` is filled in only when a chain reaches an end state. A chain that is still `Running`, sitting `Stalled` while it waits for recovery, or waiting out a retry backoff has no completion timestamp yet. An age filter compares each record against a cut-off date, and a record whose date field is empty never falls inside that range, so the purge simply skips those in-flight chains and leaves them for the watchdog to recover. Purge by `CreatedDate` instead and you delete exactly those chains the moment they age past the window, taking with them the very records recovery depends on.

One gap to plan around: this configuration-only recipe has no status filter, so it treats a finished `Failed` chain the same as a completed one. Any chain that has reached an end state, successful or failed, is deleted once it is older than your window. If you keep failed chains to investigate later, size the retention window to cover how long you need that history, or export the failures you care about before they age out.

### Configuration Reference: [`SCHED_DeactivateUsers`](reference/apex/SCHED_DeactivateUsers.md)

| Attribute             | Required | Default | Description                                        |
|-----------------------|----------|---------|----------------------------------------------------|
| `profileNames`        | **Yes**  | -       | Pipe-separated profile names (e.g., `Standard User\|Chatter Free User`) |
| `minimumNumberOfDays` | No       | 180     | Days since last login                              |
| `batchSize`           | No       | 2000    | Records per batch transaction                      |
| `allOrNothing`        | No       | false   | If true, rollback batch on any error               |

**Example Parameters__c value** (set via `DTO_NameValues`)**:**

```json
{"profileNames":"Standard User|Chatter Free User","minimumNumberOfDays":"180","batchSize":"100"}
```

---

## Monitoring and Troubleshooting

### Monitoring Scheduled Jobs

**Note:** The following snippets use inline SOQL for Developer Console use. Production code should use `SEL_ScheduledJob` and `QRY_Builder`.

```apex
// Query all active scheduled jobs from ScheduledJob__c
List<ScheduledJob__c> activeJobs = [
	SELECT SchedulerName__c, ClassName__c, CronExpression__c,
	       ScheduledJobId__c, Description__c, LastModifiedDate
	FROM ScheduledJob__c
	WHERE IsActive__c = true
	ORDER BY SchedulerName__c
];

// For each, get next fire time from CronTrigger
Set<Id> jobIds = new Set<Id>();
for(ScheduledJob__c job : activeJobs)
{
	if(String.isNotBlank(job.ScheduledJobId__c))
	{
		jobIds.add(job.ScheduledJobId__c);
	}
}

Map<Id, CronTrigger> triggerMap = new Map<Id, CronTrigger>([
	SELECT Id, NextFireTime, PreviousFireTime, State
	FROM CronTrigger
	WHERE Id IN :jobIds
]);

for(ScheduledJob__c job : activeJobs)
{
	CronTrigger trigger = triggerMap.get(job.ScheduledJobId__c);
	LOG_Builder.build().info(job.SchedulerName__c + ' - Next run: ' + trigger?.NextFireTime).emitAt('MonitorScheduledJobs');
}
```

### Monitoring Async Job Execution

```apex
// Query recent async job executions
List<AsyncApexJob> recentJobs = [
	SELECT Id, ApexClass.Name, Status, NumberOfErrors,
	       JobItemsProcessed, TotalJobItems, CreatedDate, CompletedDate
	FROM AsyncApexJob
	WHERE CreatedDate = TODAY
	AND JobType IN ('BatchApex', 'Queueable')
	ORDER BY CreatedDate DESC
	LIMIT 50
];

for(AsyncApexJob job : recentJobs)
{
	String progress = job.JobItemsProcessed + '/' + job.TotalJobItems;
	LOG_Builder.build().info(job.ApexClass.Name + ' [' + job.Status + '] ' + progress).emitAt('MonitorAsyncJobs');
}

// Find failed jobs
List<AsyncApexJob> failedJobs = [
	SELECT Id, ApexClass.Name, ExtendedStatus, NumberOfErrors
	FROM AsyncApexJob
	WHERE Status IN ('Failed', 'Aborted')
	AND CreatedDate = LAST_N_DAYS:7
];
```

### Monitoring Async Chain Failures

Some Queueable failures cannot be caught from inside the step: a governor-limit crash that no `try/catch` can trap.
Without help, such a crash would simply disappear. `AsyncApexJob` marks it `Failed` with almost no detail, and a
hand-rolled chain could sit stuck in `Running` forever. The async chain framework closes that gap by attaching a
[Transaction Finalizer](https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_transaction_finalizers.htm) to every step.
A finalizer runs with fresh governor limits even after the crash, and it does two things:

1. **Logs the failure.** It writes an `Error` `LogEntry__c` carrying the chain's correlation ID and the reason, so the crash is kept
   and traceable even though the Queueable itself died (see the [Logging Guide](Logging%20-%20Guide.md#async-context-propagation)).
2. **Marks the chain Failed.** It sets the `AsyncChainExecution__c` record's `Status__c` to `Failed` (with the reason in `ErrorMessage__c`), so the
   chain never lingers stuck in `Running`.

To find failed chains, filter `AsyncChainExecution__c` on `Status__c = 'Failed'` in a report, a list view, or the
Developer Console:

```apex
// Recent chain failures, newest first (Developer Console)
List<AsyncChainExecution__c> failedChains = [
	SELECT ChainName__c, CurrentStepName__c, ErrorMessage__c, CorrelationId__c, CompletedAt__c
	FROM AsyncChainExecution__c
	WHERE Status__c = 'Failed'
	AND CreatedDate = LAST_N_DAYS:7
	ORDER BY CreatedDate DESC
];
```

Use each row's `CorrelationId__c` to pull the full correlated trace from `LogEntry__c`. Or skip the query
entirely: the Chain Monitor's detail panel has a **View logs** button that opens the Log Console already
filtered to that chain's correlation ID, laying the whole run out as a timeline (see
[The Log Console](Logging%20-%20Guide.md#the-log-console) in the Logging Guide). The chain
[Monitoring](#monitoring) section above lists every `AsyncChainExecution__c` field, and the
[Logging Strategy](#logging-strategy) table records the exact events the framework logs. If you already hold a single
chain's Id, `UTIL_AsyncChain.getStatus(executionId)` returns its live status without running a query.

### Expected entries in your debug logs

With Apex debug logging turned on, a running chain leaves a few `System.TypeException` entries in the log that are thrown and immediately caught inside the framework. These are expected and harmless. Salesforce records an exception in the debug log the instant it is thrown, even when the very next line catches it, so a caught exception the framework relies on still shows up. Knowing where each one comes from lets you tell them apart from a real fault:

- **Type detection.** To read the concrete type name of a value, the framework uses a well-known Apex technique that deliberately provokes and then catches a `System.TypeException`. It runs once when a chain is built, once when the chain context is serialised, and once for every non-primitive value you read back through `getAs(...)`. Each is a single, inexpensive caught exception, not an error.
- **A retried step.** When a step is set to retry, each failed attempt logs its own exception. Seeing the same exception two or three times in a row while the chain stays healthy and still finishes is the retry doing its job, not one failure repeating uncontrollably.
- **One entry at the end.** Every chain now writes a terminal `LogEntry__c` as it finishes, subject to your log threshold: INFO for a completion, ERROR for a failure, WARN for an abort (see [Logging Strategy](#logging-strategy) for how the threshold decides which ones you see).

None of these needs any change on your side.

---

## Testing

You test async processors by wrapping the call in `Test.startTest()` / `Test.stopTest()`, which makes the async work run
right away inside the test. The framework already tests its own Batch and Queueable machinery, so your tests can stay
focused on one thing: proving that your `Processable.execute()` logic produces the result you expect.

**Testing a processor with list-based input:**

`MyProcessor` (defined earlier in this guide) casts its input to `List<Account>`, so the test seeds accounts to match. If
your processor is typed for a different object, adjust the `TST_Builder` call and the `QRY_Builder` query to suit.

```apex
@IsTest
private static void shouldProcessRecordsSuccessfully()
{
	List<Account> records = (List<Account>)TST_Builder.of(Account.SObjectType)
		.withCount(5)
		.buildList();

	Test.startTest();
	UTIL_AsynchronousJobLauncher.process(records, new MyProcessor());
	Test.stopTest();

	List<Account> results = QRY_Builder.selectFrom(Account.SObjectType)
		.fields(new List<SObjectField>{ Account.Description })
		.condition(Account.Id).isIn(new List<SObject>(records))
		.toList();
	Assert.areEqual(5, results.size(), 'All records should be processed');
}
```

**Testing a configurable scheduler:**

```apex
@IsTest
private static void shouldExecuteScheduledJob()
{
	DTO_NameValues attributes = new DTO_NameValues();
	attributes.add('objectName', 'Foobar__c');
	attributes.add('batchSize', '200');

	SCHED_MyCustomJob job = new SCHED_MyCustomJob();
	job.setParameterValues(attributes);

	Test.startTest();
	job.execute(null);
	Test.stopTest();
}
```

**Testing finalisation logic:**

When your processor implements `Finishable`, `Test.stopTest()` runs the `finish()` method once all batches have
completed. Assert on what `finish()` produced: status records created, emails sent through a mock, and so on.

---

## Common Pitfalls

If a scheduled or async job isn't behaving, start here. Each row pairs a symptom with its usual cause and the fix:

| Issue                   | Cause                  | Solution                                                                                    |
|-------------------------|------------------------|---------------------------------------------------------------------------------------------|
| Job doesn't start       | `IsActive__c` = false  | Set `IsActive__c` = true                                                                    |
| Job fails immediately   | Invalid class name     | Check `ClassName__c` includes namespace                                                     |
| Job runs but errors     | Processing logic issue | Check [`LogEntry__c`](reference/objects/LogEntry__c.md) for errors with job's CorrelationId |
| Job stuck in Processing | Apex error or timeout  | Check `AsyncApexJob.ExtendedStatus`, abort if needed                                        |
| Schedule not updating   | Old job not aborted    | Framework handles this - check trigger is active                                            |

---

## Anti-Patterns

These are common mistakes (anti-patterns) that look reasonable but cause trouble later, with the better approach for each:

| Anti-Pattern                                                  | Why It's Wrong                                                          | Instead                                                    |
|---------------------------------------------------------------|-------------------------------------------------------------------------|------------------------------------------------------------|
| Hardcoding `System.enqueueJob()` or `Database.executeBatch()` | Bypasses automatic strategy selection and governor-limit-aware chunking | Use `UTIL_AsynchronousJobLauncher.process()`               |
| Loading all records into memory before launching              | Causes heap size exceptions on large datasets                           | Pass a `QRY_Builder.Builder` so Batch Apex streams records |
| Business logic in the schedulable class                       | Cannot be reused, tested independently, or launched outside a schedule  | Implement `Processable` for logic; keep schedulables thin  |
| Ignoring `Finishable` for jobs that need cleanup              | No notification, no error summary, no follow-up action                  | Implement `Finishable` for post-processing or alerting     |

---

## Best Practices

### For Developers

1. **Use AUTO strategy** unless you have specific requirements
2. **Implement [IF_Async.Finishable](reference/apex/IF_Async.Finishable.md)** for notification/cleanup needs
3. **Use query-based processing** for large datasets (>10,000 records)
4. **Size batches based on complexity** - smaller for callouts, larger for simple DML
5. **Always capture logger context** in async job constructors
6. **Test with `Test.startTest()`/`Test.stopTest()`** to execute async synchronously

### Choosing a Batch Size

When a batch job reads its records from a query, the platform fetches them in fixed chunks before handing them to your
code, and one `execute()` call never spans two chunks. The chunk size depends on the batch size you choose:

| Batch size you choose | Chunk the platform reads |
|-----------------------|--------------------------|
| 1 to 100              | 100 records              |
| 101 to 400            | 400 records              |
| 401 to 2,000          | 2,000 records            |

A batch size that does not divide its chunk exactly leaves a short run at the end of every chunk. At a batch size of 75,
for example, each chunk of 100 becomes one call of 75 and one of 25, so a job over 290 records makes six calls instead of
four. Above 100, the sizes that fit are 200, 400, 500, 1,000 and 2,000. At or below 100, any divisor of 100 fits: 1, 2, 4,
5, 10, 20, 25, 50 or 100. Every size the framework uses by default fits; only a size you set yourself, in code, in an
`AsynchronousJobSetting__mdt` record or through a scheduled job's `batchSize` parameter, can miss.

When a query-backed batch is launched with a size that does not fit, the framework writes one WARN entry naming the
size, the chunk, the short run and the nearest sizes that fit, folded into one problem in the Log Console however often
the job runs. A job that processes an in-memory list instead of a query is not affected.

### For Architects

1. **Prefer [`ScheduledJob__c`](reference/objects/ScheduledJob__c.md)** over programmatic scheduling for production jobs
2. **Document job purposes** in `Description__c` field
3. **Use built-in schedulers** ([`SCHED_PurgeRecords`](reference/apex/SCHED_PurgeRecords.md), etc.) when possible
4. **Monitor job execution** via reports on `AsyncApexJob`
5. **Plan for failure** - implement error handling and alerting
6. **Consider callout limits** when designing batch sizes for integrations

### For Administrators

1. **Use ScheduledJob__c UI** to manage scheduled jobs without code
2. **Check ScheduledJobId__c** to verify job is actually scheduled
3. **Set IsActive__c = false** to stop a job (don't delete unless permanent)
4. **Review CronExpression** carefully - test in lower environments first
5. **Monitor with reports** on `AsyncApexJob` for failures

---

## Related Documentation

- **[Objects & Metadata - Guide](Objects%20%26%20Metadata%20-%20Guide.md)** - `ScheduledJob__c`, `AsynchronousJobSetting__mdt`, and `ScheduleSetting__c` object reference
- **[Logging - Guide](Logging%20-%20Guide.md)** - Transaction correlation with `LOG_Builder` across async boundaries
- **[Web Services - Guide](Web%20Services%20-%20Guide.md)** - `SCHED_PerformBatchedCallouts` for queued API calls
- **[Utilities - Guide](Utilities%20-%20Guide.md)** - `UTIL_Retry` and `UTIL_CircuitBreaker` for fault-tolerant async processing
- **[Triggers - Guide](Triggers%20-%20Guide.md)** - Launching async jobs from trigger actions

---

## Summary

| Component                                                                        | Purpose                    | When to Use                  |
|----------------------------------------------------------------------------------|----------------------------|------------------------------|
| [`UTIL_AsynchronousJobLauncher`](reference/apex/UTIL_AsynchronousJobLauncher.md) | Launch ad-hoc async jobs   | Triggers, APIs, user actions |
| [`ScheduledJob__c`](reference/objects/ScheduledJob__c.md)                        | Declarative job scheduling | Recurring jobs (recommended) |
| [`IF_Async.Processable`](reference/apex/IF_Async.Processable.md)                 | Define processing logic    | All async processing         |
| [`IF_Async.Finishable`](reference/apex/IF_Async.Finishable.md)                   | Cleanup/notification       | When post-processing needed  |
| [`IF_Schedulable`](reference/apex/IF_Schedulable.md)                             | Parameterized schedulers   | Flexible recurring jobs      |
| [`SCHED_PurgeRecords`](reference/apex/SCHED_PurgeRecords.md)                     | Delete old records         | Data retention policies      |
| [`SCHED_DeactivateUsers`](reference/apex/SCHED_DeactivateUsers.md)               | Deactivate inactive users  | User lifecycle management    |

**Key Takeaways:**

1. **Use the framework.** Prefer the launcher for reusable processing. Write a native Batch or Queueable job where [How to opt out](#how-to-opt-out) applies.
2. **Let AUTO decide.** The framework picks the execution strategy for you.
3. **Schedule declaratively.** Use [`ScheduledJob__c`](reference/objects/ScheduledJob__c.md) records for production jobs.
4. **Correlation is automatic** in chains and the web service framework; wire it up by hand for custom async using [`LOG_Builder`](reference/apex/LOG_Builder.md).
5. **Monitor proactively.** Query `AsyncApexJob` for failures.
