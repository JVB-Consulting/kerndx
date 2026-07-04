# Async Processing - Guide

**Framework:** KernDX
**Package Type:** Managed Package

**Target Audience:**

- **Developers** - Building schedulable jobs, batch processing, and asynchronous operations with automatic strategy selection
- **Architects** - Designing scalable async processing patterns with governor limit awareness and adaptive execution
- **Business Analysts** - Understanding scheduled job configuration, execution strategies, and monitoring capabilities

---

## Table of Contents

<details>
<summary>Expand</summary>

1. [Quick Navigation](#quick-navigation)
2. [Overview](#overview)
3. [Quick Start](#quick-start)
4. [Escape Hatches](#escape-hatches)
5. [KernDX vs OOTB: Async Framework Comparison](#kerndx-vs-ootb-async-framework-comparison)
    - [Salesforce Out-of-the-Box Alternative](#salesforce-out-of-the-box-alternative)
    - [Pros & Cons Comparison](#pros--cons-comparison)
    - [When to Use KernDX Async Framework](#when-to-use-kerndx-async-framework)
    - [When to Use OOTB Batch/Queueable](#when-to-use-ootb-batchqueueable)
    - [Example Comparison](#example-comparison)
5. [Architecture](#architecture)
    - [System Architecture Diagram](#system-architecture-diagram)
    - [Execution Strategy Flow](#execution-strategy-flow)
    - [Execution Strategy Comparison](#execution-strategy-comparison)
6. [Architecture Decision Guide](#architecture-decision-guide)
    - [When to Use This Framework](#when-to-use-this-framework)
    - [Framework Selection Matrix (for Architects)](#framework-selection-matrix-for-architects)
7. [Processor Interfaces](#processor-interfaces)
    - [Interface Hierarchy](#interface-hierarchy)
    - [IF_Async.Processable (Required)](#if_asyncprocessable-required)
    - [IF_Async.Finishable (Optional)](#if_asyncfinishable-optional)
8. [Async Chain Orchestration](#async-chain-orchestration)
    - [When to Use Chains](#when-to-use-chains)
    - [Architecture](#architecture-1)
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
9. [Scheduler Framework](#scheduler-framework)
    - [Scheduler Architecture](#scheduler-architecture)
    - [Declarative Scheduling with ScheduledJob__c](#declarative-scheduling-with-scheduledjob__c)
        - [How It Works](#how-it-works)
        - [ScheduledJob__c Fields](#scheduledjob__c-fields)
        - [Example: Create a Purge Job via UI](#example-create-a-purge-job-via-ui)
        - [Common Cron Expressions](#common-cron-expressions)
        - [Timezone Awareness](#timezone-awareness)
    - [Built-in Schedulers](#built-in-schedulers)
    - [Creating Custom Configurable Schedulers](#creating-custom-configurable-schedulers)
10. [Transaction Correlation in Async Operations](#transaction-correlation-in-async-operations)
    - [Why Correlation Matters](#why-correlation-matters)
    - [Correlation Flow](#correlation-flow)
    - [Queueable Pattern with Correlation](#queueable-pattern-with-correlation)
    - [Batch Apex Pattern with Correlation](#batch-apex-pattern-with-correlation)
    - [Key Correlation Methods](#key-correlation-methods)
11. [Capability Matrix (for Analysts)](#capability-matrix-for-analysts)
    - [What Can Be Scheduled?](#what-can-be-scheduled)
    - [Configuration Reference: SCHED_PurgeRecords](#configuration-reference-sched_purgerecords)
    - [Configuration Reference: SCHED_DeactivateUsers](#configuration-reference-sched_deactivateusers)
12. [Monitoring and Troubleshooting](#monitoring-and-troubleshooting)
    - [Monitoring Scheduled Jobs](#monitoring-scheduled-jobs)
    - [Monitoring Async Job Execution](#monitoring-async-job-execution)
    - [Monitoring Async Chain Failures](#monitoring-async-chain-failures)
13. [Testing](#testing)
14. [Common Pitfalls](#common-pitfalls)
15. [Anti-Patterns](#anti-patterns)
16. [Best Practices](#best-practices)
    - [For Developers](#for-developers)
    - [For Architects](#for-architects)
    - [For Administrators](#for-administrators)
17. [Related Documentation](#related-documentation)
18. [Summary](#summary)

</details>

---

## Quick Navigation

| I am a...     | I need to...                      | Go to...                                                                   |
|---------------|-----------------------------------|----------------------------------------------------------------------------|
| **Architect** | Decide when to use async patterns | [Architecture Decision Guide](#architecture-decision-guide)                |
| **Architect** | Compare with OOTB Batch/Queueable | [KernDX vs OOTB](#kerndx-vs-ootb-async-framework-comparison)               |
| **Developer** | Process records asynchronously    | [Quick Start](#quick-start)                                                |
| **Developer** | Create a scheduled job            | [Scheduler Framework](#scheduler-framework)                                |
| **Developer** | Implement custom processing       | [Processor Interfaces](#processor-interfaces)                              |
| **Developer** | Build multi-step async workflows  | [Async Chain Orchestration](#async-chain-orchestration)                    |
| **Analyst**   | Know what's available             | [Capability Matrix](#capability-matrix-for-analysts)                       |
| **Analyst**   | Configure scheduled jobs          | [ScheduledJob Configuration](#declarative-scheduling-with-scheduledjob__c) |

---

## Overview

The Asynchronous Operations framework provides **enterprise-grade patterns** for running long-running processes, scheduled jobs,
and bulk data processing. It abstracts away the complexity of choosing between Salesforce's async mechanisms
([Queueable](https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_queueing_jobs.htm),
[Batch Apex](https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_batch_interface.htm),
[Scheduled Apex](https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_scheduler.htm))
and automatically optimizes execution based on data volume and governor limits.

The framework consists of six complementary layers:

1. **[`UTIL_AsynchronousJobLauncher`](reference/apex/UTIL_AsynchronousJobLauncher.md)** — Simplified entry point for launching async jobs with adaptive strategy selection
2. **[`IF_Async.Processable`](reference/apex/IF_Async.Processable.md)** — Interface for defining processing logic
3. **`UTIL_AdaptiveAsynchronousProcessor`** — Adaptive processing engine (internal) — selects Queueable, Batch, or synchronous based on data volume
4. **[`UTIL_AsyncChain`](reference/apex/UTIL_AsyncChain.md)** — Chain orchestration with shared context, execution tracking, error/completion handlers, and built-in [`ApiStep`](reference/apex/UTIL_AsyncChain.ApiStep.md) web service bridge
5. **[`IF_Schedulable`](reference/apex/IF_Schedulable.md)** — Interface for configurable scheduled jobs with parameter definitions, managed via [`ScheduledJob__c`](reference/objects/ScheduledJob__c.md)
6. **`CTRL_ChainMonitor`** — Real-time Chain Monitor UI (4 LWC components: `chainMonitor`, `chainMonitorList`, `chainMonitorDetail`, `chainStepTimeline`) with streaming updates,
   step timeline, and error detail panels

> **Responsibilities:** The Async framework launches and manages long-running or deferred work. It does not contain business logic itself --
> that belongs in your `Processable` implementation. It does not query data; pass records or a `Builder` to the launcher.

> **When NOT to use this pattern:**
> - Small synchronous operations (under 100 records) that complete well within governor limits
> - Simple scheduled jobs that a declarative Scheduled Flow can handle without code

**Key Benefits:**

- **Automatic Strategy Selection** — Framework chooses Queueable or Batch based on volume
- **Simplified API** — Simple entry point for complex async operations
- **Chain Orchestration** — Multi-step workflows with shared context, error/completion handlers, and persistent execution tracking
- **Web Service Bridge** — `ApiStep` wraps any `API_Outbound` handler as a chain step with zero changes
- **Real-Time Monitoring** — Chain Monitor UI with streaming updates, step timeline, and error panels
- **Configurable Schedulers** — Parameterized scheduled jobs without code changes
- **Governor Limit Aware** — Automatically handles governor limit constraints
- **Consistent Error Handling** — Standardized error handling and logging across all async patterns
- **Testable** — Built-in test support with configurable behavior

> **Async Framework Scope:** Adaptive strategy selection (Queueable vs Batch), chain orchestration with shared context and `ApiStep` web service bridge, declarative scheduling via
`ScheduledJob__c`, real-time Chain Monitor UI, and four pre-built schedulable reference implementations (`SCHED_DeactivateUsers`, `SCHED_PerformBatchedCallouts`,
`SCHED_ProcessLoginHistory`, `SCHED_PurgeRecords`) extending the abstract `SCHED_Base`.

> **Declarative Scheduling:** Configure recurring jobs entirely through [`ScheduledJob__c`](reference/objects/ScheduledJob__c.md)
> records — set a class name, cron expression, and activate. No code deployment needed to schedule, reschedule, or
> deactivate jobs.

---

## Quick Start

Implement `IF_Async.Processable` and launch with `UTIL_AsynchronousJobLauncher` -- the framework picks the optimal strategy.

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

## Escape Hatches

The async framework provides three execution strategies and adapts between them automatically. `UTIL_AsyncChain` is **one** option — for sequenced, dependent work with shared
state. Parallel execution is a separate, first-class strategy. Subscribers always retain full control of the platform's native async primitives.

| You need                                                                         | Use                                                                                                                                                                    | See                                                                       |
|----------------------------------------------------------------------------------|------------------------------------------------------------------------------------------------------------------------------------------------------------------------|---------------------------------------------------------------------------|
| **Parallel Queueables** (multiple jobs running concurrently)                     | `UTIL_AsynchronousJobLauncher.process()` auto-selects `PARALLEL_QUEUEABLES` when the 10-concurrent platform limit allows.                                              | [Execution Strategy Comparison](#execution-strategy-comparison)           |
| **Direct `System.enqueueJob()`** for an independent Queueable                    | Works unmodified — nothing intercepts `enqueueJob`. Subscribers freely write `implements Queueable` and enqueue independently of any chain.                            | [Queueable Pattern with Correlation](#queueable-pattern-with-correlation) |
| **Native `Database.Batchable` / `Database.Stateful`**                            | Write your own batch class as you always would. No mandatory base class. The framework's `IF_Async.Processable` interface is optional.                                 | [When to Use OOTB Batch/Queueable](#when-to-use-ootb-batchqueueable)      |
| **Change Data Capture / Platform Event triggers**                                | Subscribers write `trigger MyTrigger on Account__ChangeEvent` directly. Framework code calls `EventBus.publishWithAccessLevel()` without wrapping subscriber triggers. | —                                                                         |
| **Force a specific execution strategy** instead of letting the dispatcher choose | `IF_Async.AsynchronousExecutionStrategy` enum exposes `PARALLEL_QUEUEABLES`, `CHAINABLE`, `BATCH` — pass it to the launcher.                                           | [Execution Strategy Comparison](#execution-strategy-comparison)           |
| **10-concurrent-limit awareness for adaptive degradation**                       | The adaptive processor reads `UTIL_Limits.queueableJobs().remaining()` and degrades PARALLEL → CHAINABLE → BATCH automatically.                                        | [Execution Strategy Flow](#execution-strategy-flow)                       |

`UTIL_AsyncChain` is for one specific pattern: sequenced, dependent steps with shared context across transactions. It does **not** preclude parallel execution — it's the wrong tool
for that, and the framework names the right one (`PARALLEL_QUEUEABLES`) explicitly.

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

| Feature                     | KernDX Async Framework                                                                 | Salesforce OOTB Batch/Queueable                    |
|-----------------------------|----------------------------------------------------------------------------------------|----------------------------------------------------|
| **Auto Strategy Selection** | AUTO mode chooses optimal approach                                                     | Developer must decide upfront                      |
| **Unified API**             | One interface for Batch & Queueable                                                    | Different interfaces (Batchable vs Queueable)      |
| **Declarative Scheduling**  | [`ScheduledJob__c`](reference/objects/ScheduledJob__c.md) custom object                | Requires code deployment                           |
| **Configurable Jobs**       | [`IF_Schedulable`](reference/apex/IF_Schedulable.md) with parameter definitions        | Must hard-code or use custom settings              |
| **Parallel Queueables**     | `PARALLEL_QUEUEABLES` strategy                                                         | Manual enqueue loop required                       |
| **Chained Queueables**      | `CHAINABLE` with auto-chaining                                                         | Manual chaining in execute()                       |
| **Error Events**            | Queueable crashes captured by a finalizer → durable `LogEntry__c`                                             | Native Batch fires `BatchApexErrorEvent`; Queueables surface nothing                  |
| **Finalization**            | [`IF_Async.Finishable`](reference/apex/IF_Async.Finishable.md) works for both          | Only Batch has finish(), Queueable needs Finalizer |
| **Log Correlation**         | [`LOG_Builder`](reference/apex/LOG_Builder.md) `serializeContext()`/`hydrateContext()` | Must implement manually                            |
| **Query-Based Processing**  | Pass [`QRY_Builder.Builder`](reference/apex/QRY_Builder.md)                            | `Database.QueryLocator` in Batch                   |
| **Callout Support**         | `Database.AllowsCallouts` included                                                     | Must add interface manually                        |
| **Test Support**            | `AsyncOptions` for controlled testing                                                  | Standard Test.startTest()/stopTest()               |
| **Simplicity**              | Requires learning framework                                                            | Standard Salesforce patterns                       |
| **Learning Curve**          | Framework-specific knowledge                                                           | Standard Apex knowledge                            |
| **Performance**             | Minimal framework overhead                                                             | Direct platform execution                          |
| **Flexibility**             | Must use framework patterns                                                            | Full control over implementation                   |

### When to Use KernDX Async Framework

- **Variable data volumes** - Framework auto-selects Queueable vs Batch
- **Reusable processing logic** - Same processor works across strategies
- **Declarative job management** - Admin-managed schedules via [`ScheduledJob__c`](reference/objects/ScheduledJob__c.md)
- **Log correlation required** - Track async operations back to source via [`LOG_Builder`](reference/apex/LOG_Builder.md)
- **Parallel queueable patterns** - Framework handles chunking and enqueuing
- **Consistent error handling** - Framework provides standardized error events
- **Multiple developers** - Enforces consistent patterns
- **Enterprise applications** - Full lifecycle management

### When to Use OOTB Batch/Queueable

- **Simple one-off jobs** - Basic batch or queueable without reuse
- **Maximum control** - Need custom start/execute/finish behavior
- **Performance critical** - Avoid any framework overhead
- **Stateful batch** - Need `Database.Stateful` for cross-batch state
- **Custom chaining logic** - Complex conditional chaining requirements
- **Small codebase** - Few async jobs, minimal consistency needs
- **Developers prefer** - Direct Salesforce patterns

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

## Architecture

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

## Processor Interfaces

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

The core interface for your processing logic. Implement this to define what happens to each batch of records.

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

Implement this alongside [`IF_Async.Processable`](reference/apex/IF_Async.Processable.md) when you need cleanup or notification after all processing completes.

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

Async chains sequence multiple steps across separate Queueable transactions with shared state, automatic progress tracking,
and built-in error handling. Each step runs in its own transaction with fresh governor limits.

### When to Use Chains

| Pattern                                   | Best for                                                                                   |
|-------------------------------------------|--------------------------------------------------------------------------------------------|
| Single processor (`IF_Async.Processable`) | Processing a collection of records with the same logic                                     |
| Scheduler (`IF_Schedulable`)              | Recurring jobs on a cron schedule                                                          |
| **Async chain**                           | Multi-step workflows where steps must run sequentially, each needing fresh governor limits |

Use chains when your workflow has distinct phases that depend on each other -- for example, load data, transform it,
then send a notification. Each step can make callouts, run DML, and query without competing for the same transaction's limits.

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

Extend `UTIL_AsyncChain.ChainStep` and implement `work(ChainContext)`. Return a `StepResult` to indicate success or failure.

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

Build and execute chains fluently with `UTIL_AsyncChain.newChain()`:

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
| `.withAsyncOptions(AsyncOptions)` | Sets queueable stack depth (for tests)                                            |
| `.onError(IF_Chain.Step)`         | Registers a handler that runs when a step fails                                   |
| `.onComplete(IF_Chain.Step)`      | Registers a handler that runs after all steps succeed                             |
| `.execute()`                      | Persists config, enqueues the first step, returns the `AsyncChainExecution__c` ID |
| `.execute(correlationId)`         | Same as above with a caller-supplied correlation ID                               |

### Context Sharing

The `ChainContext` object is serialized between transactions, so all values must be JSON-serializable.
Prefer IDs and primitives over full SObject graphs.

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

**onError handler:** Runs when any step fails (unless the failing step has `continueOnError = true`). The handler
executes in its own Queueable transaction (`HandlerExecutor`), guaranteeing fresh governor limits and allowing
callouts even if the failed step performed DML. Receives the full context, including the previous step's failure result.

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

**continueOnError:** Use the `then(step, true)` overload to allow the chain to proceed past a step failure.

```apex
UTIL_AsyncChain.newChain('ResilientChain')
	.then(new CriticalStep())
	.then(new CleanupStep(), true)
	.then(new FinalStep())
	.execute();
```

**onComplete handler:** Runs after all steps complete successfully, in its own Queueable transaction (`HandlerExecutor`).
Callouts are safe even if the final step performed DML. If the handler throws, the chain is marked as Failed.

**Chain statuses:** `Running` → `Completed` | `Failed` | `Aborted`

### Monitoring

Query chain status programmatically or inspect `AsyncChainExecution__c` records directly.

```apex
Map<String, Object> status = UTIL_AsyncChain.getStatus(executionId);
String currentStatus = (String)status.get('status');
Decimal completedSteps = (Decimal)status.get('completedSteps');
Decimal totalSteps = (Decimal)status.get('totalSteps');
```

**AsyncChainExecution__c fields:**

| Field                | Description                                                                          |
|----------------------|--------------------------------------------------------------------------------------|
| `ChainName__c`       | Descriptive name from `newChain()`                                                   |
| `Status__c`          | Running, Completed, Failed, or Aborted                                               |
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

The chain framework minimises log noise. Progress is tracked on the `AsyncChainExecution__c` record (Status,
CompletedSteps, CurrentStepName, DurationMs). `CompletedSteps__c` counts only steps that succeeded — failed
steps (including `continueOnError`) are not counted. Logs are reserved for actionable events only:

| Event                        | Level | When                                                                |
|------------------------------|-------|---------------------------------------------------------------------|
| Step exception (stack trace) | Error | Step throws an unhandled exception                                  |
| Step failed but continuing   | Warn  | `continueOnError` step fails — includes failure reason and duration |
| Chain crashed                | Error | Finalizer catches unhandled Queueable crash (governor limits)       |
| Chain aborted                | Warn  | Kill switch active or max steps exceeded                            |
| Execution record deleted     | Warn  | Rare — record removed externally while chain running                |

**Performance logging** is automatic via `UTIL_PerformanceTimer`. Each step is timed; if the step duration
exceeds the threshold in `LogSetting__c.PerformanceThresholdMs__c`, a structured performance log is emitted
with CPU, heap, SOQL, and DML deltas. No manual configuration needed — just enable
`LogSetting__c.EnablePerformanceLogging__c`.

**Non-fatal failure tracking:** When `continueOnError` steps fail, the failure summaries are appended to
`ErrorMessage__c` on the execution record (e.g., "Non-fatal step failures: CleanupStep: Timeout; OptionalStep:
Service unavailable"). Status remains `Completed` — admins can filter on ErrorMessage to find chains with issues.

### Log Correlation

Chains automatically inherit the current `LOG_Builder` correlation context. When a chain spans multiple Queueable
transactions, `LOG_Builder.serializeContext()` and `hydrateContext()` are called internally to preserve the
correlation ID, parent transaction ID, and custom context data across transaction boundaries.

All log entries emitted within chain steps share the same correlation ID, making it straightforward to trace
an entire chain execution in **App Launcher > Kern > Log Entries**.

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

**Idempotency:** The framework does not enforce idempotency — this is the step author's responsibility.
Steps that perform side effects (DML, callouts) should be safe to run more than once, because manual
reprocessing, multiple entry points, or partial failures followed by re-execution can cause repeated
invocations. Use upsert with external IDs, check-before-insert, or idempotent downstream APIs.

### Kill Switch

The `FeatureFlag.AsyncChain` custom metadata record acts as a global kill switch. When disabled, any running chain
executor immediately aborts with the message "Kill switch active" and no further steps are enqueued.

This is controlled via `UTIL_FeatureFlag.isEnabled('AsyncChain')` and ships enabled by default.

### ApiStep: Web Service Integration

[`UTIL_AsyncChain.ApiStep`](reference/apex/UTIL_AsyncChain.ApiStep.md) bridges any existing
[`API_Outbound`](reference/apex/API_Outbound.md) handler into a chain step with zero changes to the handler class —
including non-POST verbs (override `getHttpMethod()` in the handler; see [Web Services - Guide](Web%20Services%20-%20Guide.md)).
The adapter wraps the full web service lifecycle — validation, callout, response parsing, DML, and `ApiCall__c`
persistence — via [`UTIL_HttpClient`](reference/apex/UTIL_HttpClient.md) delegation mode.

**Key design:** ApiStep configuration is stored in the `ChainContext` (not on the step instance) because steps are
serialized as class names and reconstructed via reflection. At build-time, the `ChainBuilder` persists the step's
configuration into the initial context. At execution-time, `work()` reads it back using the step index.

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

After an `ApiStep` executes, its result is stored in the context under the key `__apiResult_{stepIndex}` as a
`Map<String, Object>` with keys: `success` (Boolean), `statusCode` (Integer), `apiCallId` (String), and
`errors` (String, present only on failure). The full response body lives on the `ApiCall__c` record — downstream
steps can query it by ID if needed.

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

The same `API_Outbound` handler works in both modes with zero changes:

| Mode           | Entry Point                                                                   | Lifecycle                         |
|----------------|-------------------------------------------------------------------------------|-----------------------------------|
| **Standalone** | `UTIL_HttpClient.useHandler(API_SendEmail.class).withParameter(...).invoke()` | Synchronous, caller controls      |
| **Chain step** | `.then(new UTIL_AsyncChain.ApiStep(API_SendEmail.class).withParameter(...))`  | Async, chain controls error/retry |

#### Error Handling

When the API call fails, the `ApiStep` returns `UTIL_AsyncChain.failed()` with the handler's error messages. The
chain's `onError()` handler fires (if configured), and the `ApiCall__c` record is persisted for audit. Synchronous
retries within the step's Queueable transaction happen normally via `UTIL_HttpClient`; async retries are not
scheduled because the chain owns the error flow.

Use `continueOnError` when a failed API call should not stop the chain:

```apex
.then(new UTIL_AsyncChain.ApiStep(API_SendNotification.class)
    .triggeringRecordFrom('orderId'), true)  // non-fatal
```

### Testing Chains

Chains run as Queueables, so wrap execution in `Test.startTest()` / `Test.stopTest()`. For multi-step chains,
provide `AsyncOptions` (the platform built-in `System.AsyncOptions`, not a kern-namespaced type) with
`maximumQueueableStackDepth` matching your chain depth to allow the platform to execute chained Queueables
synchronously within the test context.

The `AsyncChain` feature flag ships `IsEnabledByDefault__c = true`, so the chain is enabled by default — no
seeding needed in subscriber tests.

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

> **Why `maximumQueueableStackDepth`?** In production, the framework automatically sets the stack depth to
> `steps.size() + 1`. In tests, Salesforce defaults to a stack depth of 1, which prevents chained Queueables.
> Pass `withAsyncOptions()` to override this for test execution.

> **`ChainContext` is not directly instantiable.** The constructor is `@TestVisible private` to the kern namespace,
> so subscriber tests cannot call `new UTIL_AsyncChain.ChainContext(...)`. Drive chains through
> `newChain().then().execute()` inside `Test.startTest()`/`Test.stopTest()` and let the framework wire up the
> context automatically.

---

## Scheduler Framework

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

1. **Create** a [`ScheduledJob__c`](reference/objects/ScheduledJob__c.md) record with class name, cron expression, and optional attributes
2. **Trigger fires** on insert/update/delete
3. **Handler validates** the class exists and implements correct interface
4. **Job is scheduled** automatically when `IsActive__c = true`
5. **Job ID stored** in `ScheduledJobId__c` for monitoring
6. **Changes are automatic** - update record = reschedule, delete = abort

#### ScheduledJob__c Fields

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

`System.schedule()` interprets cron expressions in the **running user's timezone**. If User A (SAST, UTC+2) creates a job for noon and User B (PST, UTC-8) later activates it, the
job fires at noon PST — 10 hours late. The scheduler framework solves this automatically.

**How it works:**

1. When a `ScheduledJob__c` record is saved via the LWC editor, `Timezone__c` is populated with the authoring user's IANA TimeZoneSidKey
2. When the trigger schedules the job, the framework automatically adjusts the cron hours (and minutes for half-hour timezones like India UTC+5:30) from the stored timezone to the
   running user's timezone
3. The adjusted cron is passed to `System.schedule()`, ensuring the job fires at the originally intended absolute time

**Edge cases handled:**

| Scenario                                       | Behaviour                                                     |
|------------------------------------------------|---------------------------------------------------------------|
| Same timezone (author = runner)                | No shift — short-circuit                                      |
| Half-hour timezones (e.g., India UTC+5:30)     | Minutes field also shifted                                    |
| Day rollover (hours cross midnight)            | Day-of-week and day-of-month shifted accordingly              |
| Day-of-month boundary (would produce 0 or >31) | Day-of-month left unchanged to avoid invalid cron             |
| Wildcard/step hours (`*`, `*/2`)               | Not shifted — fires at regular intervals regardless           |
| `L`/`W` day-of-month suffixes                  | Not shifted — relative expressions cannot be reliably shifted |

### Built-in Schedulers

| Scheduler                                                                        | Purpose                   | Key Attributes                                                    |
|----------------------------------------------------------------------------------|---------------------------|-------------------------------------------------------------------|
| [`SCHED_PurgeRecords`](reference/apex/SCHED_PurgeRecords.md)                     | Delete old records        | `objectName`, `minimumNumberOfDays`, `dateFieldName`, `batchSize` |
| [`SCHED_DeactivateUsers`](reference/apex/SCHED_DeactivateUsers.md)               | Deactivate inactive users | `profileNames`, `minimumNumberOfDays`, `batchSize`                |
| [`SCHED_PerformBatchedCallouts`](reference/apex/SCHED_PerformBatchedCallouts.md) | Process queued callouts   | `batchSize`                                                       |
| [`SCHED_ProcessLoginHistory`](reference/apex/SCHED_ProcessLoginHistory.md)       | Process login records     | `batchSize`                                                       |

> **See Also:** [`DTO_NameValues`](reference/apex/DTO_NameValues.md) for attribute parsing utilities.

### Creating Custom Configurable Schedulers

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

Transaction correlation uses [`LOG_Builder`](reference/apex/LOG_Builder.md) to track related log entries across async boundaries.

### Why Correlation Matters

When a synchronous operation spawns async jobs, logs from those jobs appear disconnected. Correlation IDs link them together:

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

A Queueable that fails on an **uncatchable** error — a governor-limit crash that no `try/catch` inside the step can trap — would otherwise
vanish: `AsyncApexJob` marks it `Failed` with little detail, and a hand-rolled chain could sit stuck in a `Running` state forever. The async
chain framework closes that gap with a
[Transaction Finalizer](https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_transaction_finalizers.htm) on every step.
The finalizer receives fresh governor limits even after the crash and does two things:

1. **Logs the failure.** It writes an `Error` `LogEntry__c` carrying the chain's correlation ID and the failure reason, so the crash is durable
   and correlated even though the Queueable itself died (see the [Logging Guide](Logging%20-%20Guide.md#async-context-propagation)).
2. **Marks the chain Failed.** It sets the `AsyncChainExecution__c` record's `Status__c` to `Failed` (with the reason in `ErrorMessage__c`), so the
   chain never lingers as a zombie in `Running`.

To find failed chains, filter `AsyncChainExecution__c` on `Status__c = 'Failed'` — in a report, a list view, or the Developer Console:

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

Use each row's `CorrelationId__c` to pull the full correlated trace from `LogEntry__c`. The chain
[Monitoring](#monitoring) section above lists every `AsyncChainExecution__c` field, and the
[Logging Strategy](#logging-strategy) table records the exact events the framework logs. For a single chain whose Id you already hold,
`UTIL_AsyncChain.getStatus(executionId)` returns its live status with no query.

---

## Testing

Async processors are tested using `Test.startTest()` / `Test.stopTest()` which forces asynchronous operations to
execute synchronously. The framework's internal Batch and Queueable infrastructure is tested by the framework
itself; your tests should focus on verifying that your `Processable.execute()` logic produces the expected
results.

**Testing a processor with list-based input:**

`MyProcessor` (defined earlier in this guide) casts its input to `List<Account>`, so the test must seed
accounts to match. If your processor is typed for a different object, adjust the `TST_Builder` call and
the `QRY_Builder` query to match.

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

**Testing finalization logic:**

When your processor implements `Finishable`, `Test.stopTest()` triggers the `finish()` method after all
batches complete. Assert on the side effects of your `finish()` method (status records created, emails sent via
mock, etc.).

---

## Common Pitfalls

| Issue                   | Cause                  | Solution                                                                                    |
|-------------------------|------------------------|---------------------------------------------------------------------------------------------|
| Job doesn't start       | `IsActive__c` = false  | Set `IsActive__c` = true                                                                    |
| Job fails immediately   | Invalid class name     | Check `ClassName__c` includes namespace                                                     |
| Job runs but errors     | Processing logic issue | Check [`LogEntry__c`](reference/objects/LogEntry__c.md) for errors with job's CorrelationId |
| Job stuck in Processing | Apex error or timeout  | Check `AsyncApexJob.ExtendedStatus`, abort if needed                                        |
| Schedule not updating   | Old job not aborted    | Framework handles this - check trigger is active                                            |

---

## Anti-Patterns

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

1. **Use the framework** - Don't build custom Batch/Queueable from scratch
2. **Let AUTO decide** - Framework optimizes execution strategy
3. **Declarative scheduling** - [`ScheduledJob__c`](reference/objects/ScheduledJob__c.md) for production jobs
4. **Correlation is automatic** - Web service framework handles it; manual for custom async using [`LOG_Builder`](reference/apex/LOG_Builder.md)
5. **Monitor proactively** - Query `AsyncApexJob` for failures
