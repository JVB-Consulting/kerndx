---
navOrder: 34
---

# Async Processing - Guide

**Framework:** KernDX
**Package Type:** Managed Package

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
    - [Monitoring](#monitoring)
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
15. [Scheduler Framework](#scheduler-framework)
    - [Scheduler Architecture](#scheduler-architecture)
    - [Declarative Scheduling with ScheduledJob__c](#declarative-scheduling-with-scheduledjob__c)
        - [How It Works](#how-it-works)
        - [ScheduledJob__c Fields](#scheduledjob__c-fields)
        - [Example: Create a Purge Job via UI](#example-create-a-purge-job-via-ui)
        - [Common Cron Expressions](#common-cron-expressions)
        - [Timezone Awareness](#timezone-awareness)
    - [Built-in Schedulers](#built-in-schedulers)
    - [Creating Custom Configurable Schedulers](#creating-custom-configurable-schedulers)
16. [Transaction Correlation in Async Operations](#transaction-correlation-in-async-operations)
    - [Why Correlation Matters](#why-correlation-matters)
    - [Correlation Flow](#correlation-flow)
    - [Queueable Pattern with Correlation](#queueable-pattern-with-correlation)
    - [Batch Apex Pattern with Correlation](#batch-apex-pattern-with-correlation)
    - [Key Correlation Methods](#key-correlation-methods)
17. [Capability Matrix (for Analysts)](#capability-matrix-for-analysts)
    - [What Can Be Scheduled?](#what-can-be-scheduled)
    - [Configuration Reference: SCHED_PurgeRecords](#configuration-reference-sched_purgerecords)
    - [Configuration Reference: SCHED_DeactivateUsers](#configuration-reference-sched_deactivateusers)
18. [Monitoring and Troubleshooting](#monitoring-and-troubleshooting)
    - [Monitoring Scheduled Jobs](#monitoring-scheduled-jobs)
    - [Monitoring Async Job Execution](#monitoring-async-job-execution)
    - [Monitoring Async Chain Failures](#monitoring-async-chain-failures)
19. [Testing](#testing)
20. [Common Pitfalls](#common-pitfalls)
21. [Anti-Patterns](#anti-patterns)
22. [Best Practices](#best-practices)
    - [For Developers](#for-developers)
    - [For Architects](#for-architects)
    - [For Administrators](#for-administrators)
23. [Related Documentation](#related-documentation)
24. [Summary](#summary)

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
3. **`UTIL_AdaptiveAsynchronousProcessor`** is the engine that picks Queueable, Batch, or synchronous execution based on data volume. The framework drives it for you.
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
| **Parallel Queueables** (multiple jobs running concurrently)                     | `UTIL_AsynchronousJobLauncher.process()` auto-selects `PARALLEL_QUEUEABLES` when the 10-concurrent platform limit allows.                                              | [Execution Strategy Comparison](#execution-strategy-comparison)           |
| **Direct `System.enqueueJob()`** for an independent Queueable                    | Works unchanged. Nothing intercepts `enqueueJob`. You freely write `implements Queueable` and enqueue independently of any chain.                            | [Queueable Pattern with Correlation](#queueable-pattern-with-correlation) |
| **Native `Database.Batchable` / `Database.Stateful`**                            | Write your own batch class as you always would. There is no mandatory base class. The framework's `IF_Async.Processable` interface is optional.                                 | [When to Use OOTB Batch/Queueable](#when-to-use-ootb-batchqueueable)      |
| **Change Data Capture / Platform Event triggers**                                | You write `trigger MyTrigger on Account__ChangeEvent` directly. Framework code calls `EventBus.publishWithAccessLevel()` without wrapping your triggers. | —                                                                         |
| **Force a specific execution strategy** instead of letting the dispatcher choose | `IF_Async.AsynchronousExecutionStrategy` enum exposes `PARALLEL_QUEUEABLES`, `CHAINABLE`, `BATCH`; pass the one you want to the launcher.                                           | [Execution Strategy Comparison](#execution-strategy-comparison)           |
| **10-concurrent-limit awareness for adaptive degradation**                       | The adaptive processor reads `UTIL_Limits.queueableJobs().remaining()` and steps down PARALLEL → CHAINABLE → BATCH automatically as slots run low.                                        | [Execution Strategy Flow](#execution-strategy-flow)                       |

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
| **Error Events**            | Queueable crashes captured by a finalizer → durable `LogEntry__c`                                             | Native Batch fires `BatchApexErrorEvent`; Queueables surface nothing                  |
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
// Small dataset -> PARALLEL_QUEUEABLES (fastest)
// Medium dataset -> CHAINABLE queueables
// Large dataset -> BATCH Apex
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
|  |   |   |   Items <= 50 ----------> PARALLEL_QUEUEABLES           | |  |      |
|  |   |   |   (and slots available)   (Fastest - concurrent)        | |  |      |
|  |   |   |                                                         | |  |      |
|  |   |   |   Items <= threshold ---> CHAINABLE                     | |  |      |
|  |   |   |   (limited slots)         (Sequential queueables)       | |  |      |
|  |   |   |                                                         | |  |      |
|  |   |   |   Items > threshold ----> BATCH                        | |  |      |
|  |   |   |   (or query-based)        (Batch Apex)                  | |  |      |
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
| `.withDelayMinutes(Integer)`      | Delays the first step by 0 to 10 minutes, best-effort (see below)                 |
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

### Error Handling

**onError handler:** This runs when any step fails (unless the failing step is marked `continueOnError = true`). It runs
in its own fresh transaction (`HandlerExecutor`), so it starts with clean governor limits and can make callouts even when
the failed step already performed DML. It receives the full context, including the failure result from the step that
broke.

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

**Chain statuses:** `Running` → `Completed` | `Failed` | `Aborted`

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

`isRunning()`, `isTerminal()` (Completed, Failed, or Aborted), and `isFailed()` answer the common questions directly.
The raw `status` is still there as a String if you need it, and it can also read `Delayed` or `Stalled` for a chain that
is waiting or has stopped making progress. For a chain that is still running, `durationMs` is filled in live from its
start time, so it matches what the Chain Monitor shows.

A `ChainStatus` is a single-record summary and deliberately carries no per-step list. When you need step-by-step detail,
open the chain in the Chain Monitor. To look up several chains at once, `getChainStatuses(Set<Id>)` returns a map of Id
to `ChainStatus` in one query, so it is safe to call inside a loop. Both accessors return only the chains you have access
to, exactly as `getStatus` does.

**AsyncChainExecution__c fields:**

| Field                | Description                                                                          |
|----------------------|--------------------------------------------------------------------------------------|
| `ChainName__c`       | Descriptive name from `newChain()`                                                   |
| `Status__c`          | Running, Completed, Failed, Aborted, Delayed, or Stalled                             |
| `TotalSteps__c`      | Number of steps in the chain                                                         |
| `CompletedSteps__c`  | Steps that succeeded (failed steps are not counted)                                  |
| `CurrentStepName__c` | Name of the currently executing step                                                 |
| `ErrorMessage__c`    | Error details if failed; non-fatal failure summaries if completed with issues        |
| `DurationMs__c`      | Total chain execution duration in milliseconds                                       |
| `StepLog__c`         | JSON log of each step: className, success, durationMs, message (enriched at runtime) |
| `CorrelationId__c`   | Correlation ID for log tracing                                                       |
| `ContextData__c`     | Serialized chain context (JSON)                                                      |
| `StartedAt__c`       | When the chain started                                                               |
| `CompletedAt__c`     | When the chain finished                                                              |

The object has field history tracking enabled on `Status__c`, `CompletedSteps__c`, `CurrentStepName__c`, and
`CompletedAt__c`, providing a full audit trail of chain progression step by step.

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
| Chain aborted                | Warn  | Kill switch active or max steps exceeded                            |
| Execution record deleted     | Warn  | Rare: a record was removed externally while the chain was running                |

**Performance logging** happens automatically through `UTIL_PerformanceTimer`. Each step is timed, and if a step runs
longer than the threshold in `LogSetting__c.PerformanceThresholdMs__c`, the framework writes a structured performance log
showing the CPU, heap, SOQL, and DML it used. There is nothing to configure by hand: just enable
`LogSetting__c.EnablePerformanceLogging__c`.

**Non-fatal failure tracking:** When `continueOnError` steps fail, their failure summaries are added to
`ErrorMessage__c` on the execution record (for example, "Non-fatal step failures: CleanupStep: Timeout; OptionalStep:
Service unavailable"). The status stays `Completed`, so admins can filter on `ErrorMessage__c` to find chains that
finished but had problems along the way.

### Log Correlation

A correlation ID is one tracking ID that follows a single user action across triggers, queries, callouts, and jobs, so
you can pull every log from one action together later. Chains inherit the current `LOG_Builder` correlation context
automatically. When a chain spans several Queueable transactions, the framework calls `LOG_Builder.serializeContext()`
and `hydrateContext()` for you behind the scenes, carrying the correlation ID, the parent transaction ID, and any custom
context data across each transaction boundary.

Because every log a chain's steps write shares the same correlation ID, you can trace a whole chain run in one place:
**App Launcher > Kern > Log Entries**.

To supply a specific correlation ID:

```apex
UTIL_AsyncChain.newChain('MyChain')
	.then(new MyStep())
	.execute('my-custom-correlation-id');
```

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
custom metadata record is that master off-switch you can flip in an incident. When you disable it, any running chain
aborts at once with the message "Kill switch active" and no further steps are enqueued.

It is read through `UTIL_FeatureFlag.isEnabled('AsyncChain')` and ships enabled by default, so chains work out of the
box.

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
Retries that happen inside the step's own transaction run normally via `UTIL_HttpClient`. Async retries are not
scheduled, because the chain, not the handler, owns what happens on failure.

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

The `AsyncChain` feature flag ships with `IsEnabledByDefault__c = true`, so chains are on by default. You don't need to
seed anything to enable them in your tests.

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

> **Why `maximumQueueableStackDepth`?** In production the framework sets the stack depth to `steps.size() + 1`
> automatically. In tests, Salesforce defaults to a depth of 1, which blocks chained Queueables from running. Pass
> `withAsyncOptions()` to raise that limit for the test.

> **The framework creates and wires up the `ChainContext` for you.** You never construct it yourself. Drive chains
> through `newChain().then().execute()` inside `Test.startTest()`/`Test.stopTest()`, and the framework builds the
> context and hands it to each step. If you need to read or assert on the context, do it from inside your step's
> `work(ChainContext context)` override (where the context is handed to you), then check the chain's outcome with
> `UTIL_AsyncChain.getStatus(executionId)`.

---

## Scheduler Framework

When you need a job to run on a recurring schedule (nightly, hourly, every Monday), you have two routes. The recommended
one lets admins create and change schedules as configuration records, with no code deployment. The other is the
platform's own `System.schedule()` call, for full programmatic control. This section covers both.

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

| Field               | Type                   | Description                                                                                                                        |
|---------------------|------------------------|------------------------------------------------------------------------------------------------------------------------------------|
| `SchedulerName__c`  | Text                   | Human-readable name for the job                                                                                                    |
| `ClassName__c`      | Text                   | Fully qualified class name (with namespace if needed)                                                                              |
| `CronExpression__c` | Text                   | Standard Salesforce [cron expression](https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_scheduler.htm) |
| `IsActive__c`       | Checkbox               | When true, job runs; when false, job stopped                                                                                       |
| `Parameters__c`     | Long Text Area(131072) | JSON-serialized `DTO_NameValues` containing name/value pairs for configurable schedulers                                           |
| `Description__c`    | Long Text              | Documentation of job purpose                                                                                                       |
| `Timezone__c`       | Text                   | IANA TimeZoneSidKey of the cron author (e.g., `Africa/Johannesburg`). Used for timezone-aware scheduling                           |
| `ScheduledJobId__c` | Text                   | Auto-populated with CronTrigger ID                                                                                                 |

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
| Every 15 minutes        | `0 0,15,30,45 * * * ?` | At :00, :15, :30, :45      |
| Weekly Sunday 1 AM      | `0 0 1 ? * SUN`        | Every Sunday at 1:00 AM    |
| Monthly 1st at midnight | `0 0 0 1 * ?`          | First of month at midnight |
| Weekdays 8 AM           | `0 0 8 ? * MON-FRI`    | Monday-Friday at 8:00 AM   |

#### Timezone Awareness

Here is a subtle trap the framework removes for you. `System.schedule()` reads cron expressions in the **running user's
timezone**, not the author's. So if User A (SAST, UTC+2) sets up a job for noon and User B (PST, UTC-8) later activates
it, the job fires at noon PST, 10 hours later than intended. The scheduler framework corrects this automatically.

**How it works:**

1. When a `ScheduledJob__c` record is saved via the LWC editor, `Timezone__c` is populated with the authoring user's IANA TimeZoneSidKey
2. When the trigger schedules the job, the framework automatically adjusts the cron hours (and minutes for half-hour timezones like India UTC+5:30) from the stored timezone to the
   running user's timezone
3. The adjusted cron is passed to `System.schedule()`, ensuring the job fires at the originally intended absolute time

**Edge cases handled:**

| Scenario                                       | Behaviour                                                     |
|------------------------------------------------|---------------------------------------------------------------|
| Same timezone (author = runner)                | No shift needed; the framework short-circuits                                      |
| Half-hour timezones (e.g., India UTC+5:30)     | Minutes field also shifted                                    |
| Day rollover (hours cross midnight)            | Day-of-week and day-of-month shifted accordingly              |
| Day-of-month boundary (would produce 0 or >31) | Day-of-month left unchanged to avoid invalid cron             |
| Wildcard/step hours (`*`, `*/2`)               | Not shifted; it fires at regular intervals regardless           |
| `L`/`W` day-of-month suffixes                  | Not shifted; relative expressions cannot be reliably shifted |

### Built-in Schedulers

Four common housekeeping jobs ship ready to use. You schedule them by configuration alone, no code:

| Scheduler                                                                        | Purpose                   | Key Attributes                                                    |
|----------------------------------------------------------------------------------|---------------------------|-------------------------------------------------------------------|
| [`SCHED_PurgeRecords`](reference/apex/SCHED_PurgeRecords.md)                     | Delete old records        | `objectName`, `minimumNumberOfDays`, `dateFieldName`, `batchSize` |
| [`SCHED_DeactivateUsers`](reference/apex/SCHED_DeactivateUsers.md)               | Deactivate inactive users | `profileNames`, `minimumNumberOfDays`, `batchSize`                |
| [`SCHED_PerformBatchedCallouts`](reference/apex/SCHED_PerformBatchedCallouts.md) | Process queued callouts   | `batchSize`                                                       |
| [`SCHED_ProcessLoginHistory`](reference/apex/SCHED_ProcessLoginHistory.md)       | Process login records     | `batchSize`                                                       |

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

| Method                           | When to Use                         | Description                             |
|----------------------------------|-------------------------------------|-----------------------------------------|
| `startCorrelation()`             | Start of user action/API call       | Generates new CorrelationId             |
| `serializeContext()`             | Before enqueuing async job          | Returns JSON string of current context  |
| `hydrateContext(String)`         | Start of async job execute()        | Restores context from serialized string |
| `setCorrelationId(String)`       | When receiving external correlation | Sets specific ID from external system   |
| `setParentTransactionId(String)` | Manual parent linking               | Links to specific parent transaction    |

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
| `batchSize`           | No       | 200           | Records per batch transaction                     |
| `allOrNothing`        | No       | false         | If true, rollback batch on any error              |

**Example Parameters__c value** (set via `DTO_NameValues`)**:**

```json
{"objectName":"LogEntry__c","minimumNumberOfDays":"90","batchSize":"1000"}
```

### Configuration Reference: [`SCHED_DeactivateUsers`](reference/apex/SCHED_DeactivateUsers.md)

| Attribute             | Required | Default | Description                                        |
|-----------------------|----------|---------|----------------------------------------------------|
| `profileNames`        | **Yes**  | -       | Pipe-separated profile names (e.g., `Standard User |Chatter User`) |
| `minimumNumberOfDays` | No       | 180     | Days since last login                              |
| `batchSize`           | No       | 200     | Records per batch transaction                      |
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

1. **Use the framework.** Don't build custom Batch or Queueable jobs from scratch.
2. **Let AUTO decide.** The framework picks the execution strategy for you.
3. **Schedule declaratively.** Use [`ScheduledJob__c`](reference/objects/ScheduledJob__c.md) records for production jobs.
4. **Correlation is automatic** in chains and the web service framework; wire it up by hand for custom async using [`LOG_Builder`](reference/apex/LOG_Builder.md).
5. **Monitor proactively.** Query `AsyncApexJob` for failures.
