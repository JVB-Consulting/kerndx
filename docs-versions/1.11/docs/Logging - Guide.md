---
navOrder: 18
---

# Logging - Guide

**Framework:** KernDX
**Package Type:** Managed Package

> **Namespaces in code samples:** `kern.` on a class and `kern__` on an object, field, or metadata type mark the managed package's namespace.
> On the managed package, framework references need those prefixes even where a sample omits them; repackaged under your own namespace, replace `kern`/`kern__`
> with your prefix; on an unmanaged deploy, drop them. See [How to read the code samples](Installation.md#how-to-read-the-code-samples).

**Target Audience:**

- **Developers** - Implementing logging across Apex, LWC, and Flows
- **Architects** - Designing observability (seeing what your code actually did in production, as a searchable, kept record) and traceability patterns
- **DevOps** - Monitoring and debugging production systems

---

## What problem does this solve?

Salesforce's built-in `System.debug()` writes to debug logs that expire and that you cannot search or chart. So when something fails in production, the evidence is often gone by the time you go looking for it.

This framework instead saves every log as a real record you can report on, filter, and keep, so the evidence is still there next week. You log the same way from Apex, screen flows, and Lightning components, and the framework can stitch a single user action together even when it spans a button click, a trigger, a callout, and a background job.

Developers use it to capture errors, architects use it to design traceability, and DevOps teams use it to monitor live systems. Use it whenever you would otherwise reach for `System.debug()`.

---

## Mental model

Think of it as a flight recorder for your code. Every action leaves a timestamped, kept record, and one tracking ID ties together everything that happened during a single user action, so after a problem you can replay exactly what occurred rather than guess.

---

## Use this when

- You need the evidence of a production failure to still be there days later, not lost when the debug log rotates.
- You want to report on, chart, or filter your logs as ordinary records.
- One user action spans several places (a click, a trigger, a callout, a background job) and you want to see all of its logs together.
- You log from more than one layer (Apex, Lightning components, Flows) and want them in one place with one tracking ID.

## Don't use this when

- A quick, throwaway trace during local development is all you need. Plain `System.debug()` is simpler, and these records cost a platform event each.
- You only need Salesforce's own automatic error capture. If the built-in flow fault paths or unhandled-exception emails already tell you enough, start there and add this when you outgrow them.
- You are tempted to log personal data or secrets to make debugging easier. Don't: see the [Anti-Patterns](#anti-patterns) below.

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
    - [Apex - Log an Error](#apex---log-an-error)
    - [LWC - Log with Correlation](#lwc---log-with-correlation)
    - [Flow - Correlated Logging](#flow---correlated-logging)
7. [What is it, and where is it already wired in?](#what-is-it-and-where-is-it-already-wired-in)
8. [How does it work?](#how-does-it-work)
9. [Apex Logging (LOG_Builder)](#apex-logging-log_builder)
    - [Log Levels](#log-levels)
    - [Exception Logging](#exception-logging)
    - [DML Error Logging](#dml-error-logging)
    - [Batch Logging](#batch-logging)
    - [Log Grouping & Flood Control](#log-grouping--flood-control)
    - [Logging Inside Platform Event & Change Event Triggers](#logging-inside-platform-event--change-event-triggers)
10. [Correlation Tracking](#correlation-tracking)
    - [Starting Correlation](#starting-correlation)
    - [Async Context Propagation](#async-context-propagation)
    - [External Correlation](#external-correlation)
11. [Structured Context](#structured-context)
    - [Global Context](#global-context)
    - [Operation Context Stack](#operation-context-stack)
12. [Performance Logging](#performance-logging)
    - [What Gets Automatically Timed](#what-gets-automatically-timed)
    - [Custom Timing in Your Own Code](#custom-timing-in-your-own-code)
    - [Performance Configuration](#performance-configuration)
13. [Log Buffering](#log-buffering)
14. [LWC Client-Side Logging](#lwc-client-side-logging)
    - [LWC Setup](#lwc-setup)
    - [LWC Basic Usage](#lwc-basic-usage)
    - [LWC Correlation](#lwc-correlation)
    - [LWC Performance Timing](#lwc-performance-timing)
    - [Server Persistence](#server-persistence)
    - [Console Fallback](#console-fallback)
15. [Flow Logging (FLOW_LoggerStart, FLOW_LoggerLog, FLOW_LoggerEnd)](#flow-logging-flow_loggerstart-flow_loggerlog-flow_loggerend)
    - [Flow Simple Logging](#flow-simple-logging)
    - [Flow Bookend Pattern](#flow-bookend-pattern)
16. [Testing](#testing)
17. [The Log Console](#the-log-console)
    - [Where It Lives](#where-it-lives)
    - [The Two Views](#the-two-views)
    - [Problem Grouping](#problem-grouping)
    - [The Summary Ribbon](#the-summary-ribbon)
    - [Filters, Search, and Date Range](#filters-search-and-date-range)
    - [The Detail Drawer](#the-detail-drawer)
    - [The Timeline Tab](#the-timeline-tab)
    - [The Whole Action](#the-whole-action)
    - [To and From the Chain Monitor](#to-and-from-the-chain-monitor)
    - [What the Log Console Does Not Do](#what-the-log-console-does-not-do)
18. [Querying Log Entries](#querying-log-entries)
    - [Why](#why)
    - [Right vs wrong](#right-vs-wrong)
    - [Reports and dashboards](#reports-and-dashboards)
    - [Cleanup scripts](#cleanup-scripts)
    - [Sharing considerations](#sharing-considerations)
19. [How do I configure this?](#how-do-i-configure-this)
    - [LogSetting__c Fields](#logsetting__c-fields)
    - [TriggerSetting__mdt Fields (Trigger Performance)](#triggersetting__mdt-fields-trigger-performance)
    - [TriggerAction__mdt Fields (Action-Level Control)](#triggeraction__mdt-fields-action-level-control)
20. [Anti-Patterns](#anti-patterns)
21. [Best Practices](#best-practices)
    - [Always Include Context](#always-include-context)
    - [Use Appropriate Log Levels](#use-appropriate-log-levels)
    - [Never Log Sensitive Data](#never-log-sensitive-data)
    - [Use Correlation for Async Operations](#use-correlation-for-async-operations)
    - [Clean Up Context](#clean-up-context)
    - [Enable Performance Logging for Critical Operations](#enable-performance-logging-for-critical-operations)
22. [Troubleshooting](#troubleshooting)
    - [Logs Not Appearing](#logs-not-appearing)
    - [Missing Correlation](#missing-correlation)
    - [Performance Logs Missing](#performance-logs-missing)
    - [Context Not Appearing](#context-not-appearing)
23. [Related Documentation](#related-documentation)

</details>

---

## Quick Navigation

| I am a...     | I need to...                  | Go to...                                                                     |
|---------------|-------------------------------|------------------------------------------------------------------------------|
| **Architect** | Design observability patterns | [How does it work?](#how-does-it-work)                                        |
| **Architect** | Plan correlation tracking     | [Correlation Tracking](#correlation-tracking)                                |
| **Developer** | Log my first error            | [Quick Start](#quick-start)                                                  |
| **Developer** | Add client-side logging       | [LWC Client-Side Logging](#lwc-client-side-logging)                          |
| **Developer** | Test logging behaviour        | [Testing](#testing)                                                          |
| **Developer** | Query persisted log entries   | [Querying Log Entries](#querying-log-entries)                                |
| **DevOps**    | Diagnose a production problem | [The Log Console](#the-log-console)                                          |
| **Analyst**   | Configure log filtering       | [How do I configure this?](#how-do-i-configure-this)                         |
| **Analyst**   | Integrate logging in Flows    | [Flow Logging](#flow-logging-flow_loggerstart-flow_loggerlog-flow_loggerend) |

---

## Quick Start

> **Step-by-step walkthrough:** [Fast Start - Logging](Fast%20Start%20-%20Logging.md) covers implementation,
> testing, and common pitfalls.

### Apex - Log an Error

```apex
try
{
	// Your code
}
catch(Exception e)
{
	LOG_Builder.build().error(e).emitAt('MyClass.myMethod');
	throw e;
}
```

### LWC - Log with Correlation

```javascript
import {ComponentBuilder} from 'kern/componentBuilder';
import {startCorrelation, info, error} from 'kern/utilityLogger';

export default class MyComponent extends ComponentBuilder('notification')
{
	connectedCallback()
	{
		startCorrelation('MyComponent.load');
		info('Component loaded');
	}

	handleError(err)
	{
		error('Component action failed', err);
	}
}
```

### Flow - Correlated Logging

```text
Start Flow Correlation (flowName) → Log Flow Event (correlationId, message) → End Flow Correlation (correlationId)
```

For deeper coverage, continue reading the sections below.

---

## What is it, and where is it already wired in?

> **What it does and does not do:** This framework only records diagnostic and operational data to `LogEntry__c`. It does not enforce business rules, write to your business
> objects, or change how your code runs. Its single job is to give you a kept, searchable record of what happened.

The framework is 2 `LOG_*` classes plus 1 platform event (`LogEntryEvent__e`), and it works the same way from Apex, LWC, and Flow. You do not have to add logging everywhere yourself: it is already built into every outbound service, every trigger handler, and the async processing framework, so those parts of the framework log for you.

**What you get:**

- **One way to log from everywhere.** Write logs the same way from Apex, Lightning components, and Flows, so you learn one approach and use it across every layer.
- **See one user action end to end.** Correlation tracking tags every related log with one tracking ID, so you can follow a single action across triggers, callouts, and background jobs instead of piecing it together by hand.
- **Find production problems without writing a query.** The [Log Console](#the-log-console) groups recurring events into problems with occurrence counts, and its detail drawer walks one operation end to end, so diagnosis starts with a click rather than a SOQL query.
- **Know which operation produced each log.** The context stack captures nested operation detail (query details, trigger info, and the like) automatically, so a log tells you where it came from.
- **Surface only the slow operations.** Performance monitoring times operations automatically and logs only the ones that cross a threshold you set, so fast work stays quiet.
- **Attach the details that matter to each entry.** Structured context lets you add key-value metadata to a log, so a record carries the account, user, or anything else you need to filter on later.
- **Spend fewer platform events on bulk jobs.** Log buffering holds logs and publishes them in batches, so a job that logs once per record does not exhaust your event allocations.

---

## How does it work?

```text
+---------------------------------------------------------------------------+
|                           Entry Points                                    |
+--------------+--------------+--------------+---------------+--------------+
|    LWC       |    Flow      |   Apex       |  Trigger      |  Webservice  |
| utilityLogger| FLOW_Logger* | LOG_Builder  | TRG_*         |  API_*       |
+------+-------+------+-------+------+-------+------+--------+------+-------+
       |              |              |              |                |
       +--------------+--------------+--------------+----------------+
                                     |
                                     v
                      +------------------------------+
                      |         LOG_Engine           |
                      |  - Correlation ID tracking   |
                      |  - Context stack management  |
                      |  - Log event publishing      |
                      +-------------+----------------+
                                    |
                                    v
                      +------------------------------+
                      |      LogEntryEvent__e          |
                      |    (Platform Event)          |
                      +-------------+----------------+
                                    |
                                    v
                      +------------------------------+
                      |   TRG_LogEntryEvent (Trigger)  |
                      +-------------+----------------+
                                    |
                                    v
                      +------------------------------+
                      |        LogEntry__c             |
                      |   (Persistent Storage)       |
                      +------------------------------+
```

**What happens when you log something:** your code never waits for the log to be saved. It hands the entry off and carries on, and the record lands in `LogEntry__c` a moment later.
The steps are:

1. Code calls logging methods ([`LOG_Builder`](reference/apex/LOG_Builder.md), `utilityLogger`, [`FLOW_LoggerStart`](reference/apex/FLOW_LoggerStart.md) / [`FLOW_LoggerLog`](reference/apex/FLOW_LoggerLog.md) / [`FLOW_LoggerEnd`](reference/apex/FLOW_LoggerEnd.md))
2. `LOG_Engine` manages correlation IDs and context
3. Log entries are published as [platform events](https://developer.salesforce.com/docs/atlas.en-us.platform_events.meta/platform_events/platform_events_intro.htm) (`LogEntryEvent__e`) (non-blocking, so your transaction is not slowed down)
4. [`TRG_LogEntryEvent`](reference/apex/TRG_LogEntryEvent.md) trigger inserts records into `LogEntry__c`

The settings that control how `TRG_LogEntryEvent` receives those events, including the largest number of events it is handed in one run, live in its Platform
Events Subscriber Config. From Winter '27, in Developer, Enterprise, Performance and Unlimited edition orgs, you can see and edit that record in Setup, in Event
Studio, where it is labelled Apex Trigger Details; before that it was reachable only through the Metadata or Tooling API. The framework ships no such record, so
your org's platform defaults apply until you add one.

**The trade-off behind the hand-off:** delivery is deliberately best-effort. The logger is designed never to fail or roll back your business transaction, and the price of that
guarantee is that a log entry can be silently lost. If the platform-event publish fails, the framework does not retry and does not fall back to writing `LogEntry__c` directly:
a publish that throws leaves at most a debug line that is visible only while an Apex trace flag is active, and per-event publish errors reported by the platform are not
inspected at all (those leave no trace whatsoever), so a dropped entry looks exactly like an entry that was never logged. A buffered flush also clears the buffer whether or not the publish succeeded. If a particular record of events is
evidence you cannot afford to lose, write it to an SObject of your own inside the same transaction rather than relying on the log stream.

---

## Apex Logging ([`LOG_Builder`](reference/apex/LOG_Builder.md))

When you want to log something from Apex, [`LOG_Builder`](reference/apex/LOG_Builder.md) is the class you call. You configure the entry with a few short chained calls, then one
final call sends it. Behind the scenes, every method hands the work to `LOG_Engine`, which takes care of publishing the event and tracking context.

### Log Levels

| Level | Method    | Use Case                                  |
|-------|-----------|-------------------------------------------|
| DEBUG | `debug()` | Development tracing, detailed diagnostics |
| INFO  | `info()`  | Operational events, business milestones   |
| WARN  | `warn()`  | Potential issues, degraded functionality  |
| ERROR | `error()` | Failures requiring attention              |

```apex
// DEBUG - Development tracing
LOG_Builder.build().debug('Processing started for account: ' + account.Name).emitAt('AccountService.process');

// INFO - Business events
LOG_Builder.build().info('Order #' + order.OrderNumber + ' totaling ' + order.TotalAmount)
	.withSummary('Order Completed')
	.emitAt('OrderService.completeOrder');

// WARN - Potential issues
LOG_Builder.build().warn('API calls at 80% of daily limit')
	.withSummary('Rate limit approaching')
	.emitAt('IntegrationService.callAPI');

// ERROR - Failures
LOG_Builder.build().error('Gateway returned: ' + errorMessage)
	.withSummary('Payment failed')
	.emitAt('PaymentService.processPayment');
```

### Exception Logging

```apex
// Log exception with full stack trace
try
{
	processRecord(record);
}
catch(Exception e)
{
	// Basic exception logging
	LOG_Builder.build().error(e).emitAt('MyClass.myMethod');

	// With record ID
	LOG_Builder.build().error(e).at('MyClass.myMethod').forRecord(record.Id).emit();

	throw e; // Re-throw if needed
}
```

Every entry records the code that led to it, with or without an exception: the frames of the code that logged the entry, the logging framework's own steps left out. When you pass an exception, its own trace is kept instead. The Log Console shows it on the entry's Stack trace tab. An entry can have no frames to show: one the framework wrote from inside its own work, because Salesforce hides an installed package's code; one logged from a Flow; or one from a component that reported no error. For those the tab says so and names where the entry was logged from.

### DML Error Logging

When you save records in bulk and allow partial success, some rows save and others fail. To capture every failure in one call instead of looping through the results yourself, pass
the result collection to `errorDMLOperationResults()`. It pulls out and logs all the errors from a `Database.SaveResult`, `Database.DeleteResult`, or `Database.UpsertResult`
collection.

```apex
// Automatically extract and log all DML errors
List<Database.SaveResult> results = Database.insert(accounts, false);
Boolean hasErrors = LOG_Builder.errorDMLOperationResults(results, 'AccountService.bulkInsert');

if(hasErrors)
{
	// Handle partial failure
}
```

### Batch Logging

```apex
// Log multiple related messages efficiently
List<String> messages = new List<String>();
for(Account account : failedAccounts)
{
	messages.add('Failed to process: ' + account.Name + ' - ' + account.ErrorReason__c);
}
LOG_Builder.build().warn(messages).emitAt('BatchProcessor.execute');
```

---

### Log Grouping & Flood Control

Sometimes the same event happens thousands of times in a row: a retry loop, a flaky integration, a batch job that logs once per record. Left alone, that floods your log table with
near-identical rows. To collapse them, tag the event with a stable label (a "fingerprint") so the framework can group the repeats:

```apex
LOG_Builder.build()
		.warn('Payment gateway retry failed')
		.withFingerprint('payment-gateway-retry')
		.emitAt('PaymentSync.run');
```

The first occurrence is kept in full: that is the row whose **Fingerprint** starts with `detail:`. After that, repeats roll up into one counter row per day (the `rollup:` prefix) that carries an **Occurrence Count**. The result is that thousands of identical entries collapse to two rows: one full sample, plus one running count.

**Choosing a key:** pick a stable label for the *kind* of event, never something that changes every time. `'payment-gateway-retry'` groups well. A key that contains a record Id or a timestamp makes every entry unique, which defeats the purpose and produces more rows than logging normally would. Keys are trimmed automatically. A key longer than 200 characters, or one starting with the reserved `bypass:` prefix, is hashed for you; when that happens, the original key is saved on the detail row's context under `fingerprintSource`, so a hashed fingerprint always traces back to what you passed.

**Reading grouped logs:**

- **To see what happened (one example per event kind):** filter **Fingerprint** starting with `detail:`. That gives you one full sample of each event kind.
- **To count how often it happened:** SUM **Occurrence Count** over rows whose Fingerprint starts with `rollup:`. The sampled occurrence is already included in that count, so the rollup rows alone are the true total. Counting detail and rollup rows together double-counts, so do not add them.
- A detail row's **Created Date** is the oldest retained sample, not the most recent. If your log purge job removes it, the next occurrence simply re-creates it. Rollup rows are counts, not forensic records, so their message reflects the window's first occurrence.

You rarely need to do this reading by hand. [The Log Console](#the-log-console)'s **Problem summary** view does it for you: one row per fingerprint, carrying the sample's message and the summed occurrence count. It also groups recurring entries that were never fingerprinted, working each problem out from the entries themselves as it reads (see [Problem Grouping](#problem-grouping)). The rules above matter when you build your own reports or queries over the raw rows.

**Framework bypass audit** uses this mechanism automatically. (A "bypass" is when a developer turns off a safety check; the framework records who did it, on which surface, and against what target.) Each distinct bypass identity keeps exactly one detail row in retained logs plus daily counters, so a bypass that fires inside a hot loop can no longer flood the log table. A *new* bypass identity appearing in production, such as a new code path or a new user, still lands loudly as a fresh detail row, so you are not blind to genuinely new activity.

> **Note:** flood control reduces how many rows are *stored*, not how many events are *published*. Each occurrence still publishes a platform event and uses up your event allocations. If you need to stop the bypass-audit events themselves, the `BypassAudit_Enabled` feature flag is the off switch for that.

### Logging Inside Platform Event & Change Event Triggers

There is one place where logging needs special care, and the framework handles it for you so you do not have to think about it. Normally a log is published as a `LogEntryEvent__e`
platform event and saved a moment later (see [How does it work?](#how-does-it-work)). But if you log **while your code is running inside a platform event (`__e`) or Change Data Capture
(`*ChangeEvent`) trigger**, publishing a brand-new platform event from inside an event trigger can make the platform redeliver the original event. A "log on every delivery" pattern
would then turn into an endless redelivery loop. A trigger on one of Salesforce's own platform events, such as `BatchApexErrorEvent`, is covered in the same way, even though its
name carries neither ending.

To prevent that, when a log is emitted while a platform-event or change-event trigger is on the stack, the engine skips the event publish and instead saves the entry directly in the
same transaction. You get the same `LogEntry__c` rows, with no second platform event and no loop. There is nothing to configure: logging from a Change Data Capture trigger action or
a platform-event subscriber is safe by default.

Flood control works on this path too. Fingerprinted entries collapse into one detail row plus per-day rollup counters exactly as they do on the normal asynchronous path (see
[Log Grouping & Flood Control](#log-grouping--flood-control)), so even a high-volume change-event stream cannot flood `LogEntry__c`.

---

## Correlation Tracking

One user action often touches several disconnected places: a button click, a trigger, a callout, then a background job. When something goes wrong, you want to see all of those logs
together rather than hunting through them one at a time. A correlation ID makes that possible: it is one tracking ID that follows a single user action across triggers, queries,
callouts, and jobs, so every log produced along the way carries the same ID. The framework stores that ID on each `LogEntryEvent__e` and then on every `LogEntry__c` record, so you
can filter for the whole story of one action in a `SEL_LogEntry` query.

When a background chain continues an action under a tracking ID of its own, each of its entries carries two IDs: the
run's own correlation ID and the root correlation ID, the ID of the action that started everything. Your own entries
outside any chain normally carry the same value in both. `LOG_Builder.rootCorrelationId` answers the root at any point, the Log
Console search matches either ID, and a query on `LogEntry__c.RootCorrelationId__c` returns the whole action in one
go. Entries written before the framework recorded roots carry no root; they are still found by their correlation ID.

### Starting Correlation

```apex
// Generate new correlation ID
String correlationId = LOG_Builder.startCorrelation();

// All subsequent logs in this transaction share this correlationId
LOG_Builder.build().info('Step 1').emitAt('MyClass.myMethod');
LOG_Builder.build().info('Step 2').emitAt('MyClass.myMethod');
```

### Async Context Propagation

A correlation ID lives in one transaction. When you kick off a background job (Queueable, Batch, Future), that job runs in a separate transaction and would otherwise start with a
fresh, unrelated ID. To keep the chain joined up, save the context before you start the job and restore it inside the job:

```apex
// Parent transaction - serialize context
public void initiateAsync(Id recordId)
{
	LOG_Builder.startCorrelation();
	LOG_Builder.build().info('Initiating async processing').emitAt('MyClass.initiateAsync');

	// Capture context for async job
	String context = LOG_Builder.serializeContext();
	System.enqueueJob(new MyQueueable(recordId, context));
}

// Child transaction - restore context
public with sharing class MyQueueable implements Queueable
{
	private Id recordId;
	private String loggerContext;

	public MyQueueable(Id recordId, String loggerContext)
	{
		this.recordId = recordId;
		this.loggerContext = loggerContext;
	}

	public void execute(QueueableContext ctx)
	{
		// Restore correlation - logs now linked to parent
		LOG_Builder.hydrateContext(loggerContext);

		LOG_Builder.build().info('Async processing started').emitAt('MyQueueable.execute');
		// Process...
	}
}
```

> **You may not need to do this by hand.** The pattern above is the manual approach for a Queueable you wrote yourself. If you use the
> [async chain framework](Async%20Processing%20-%20Guide.md) instead, it does the saving and restoring for you across every step. It also attaches a
> [Transaction Finalizer](https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_transaction_finalizers.htm) that logs any **unhandled**
> exception (including governor-limit crashes that a step's own `try/catch` cannot trap) and marks the chain Failed rather than leaving it stuck in a Running state.
> So even an async step that dies still produces a correlated error log you can find later.

### External Correlation

When another system calls your endpoint and already has its own tracking ID for the request, you can adopt that ID instead of generating a new one. Your logs then line up with the
caller's logs, which makes a cross-system problem far easier to trace:

```apex
// REST endpoint receiving external correlation
@RestResource(urlMapping='/api/v1/orders/*')
global inherited sharing class OrderAPI
{
	@HttpPost
	global static void createOrder()
	{
		RestRequest req = RestContext.request;
		String externalCorrelationId = (String)new kern.UTIL_Map.CaseInsensitiveMap(req.headers).get('X-Correlation-ID');

		if(String.isNotBlank(externalCorrelationId))
		{
			LOG_Builder.setCorrelationId(externalCorrelationId);
		}
		else
		{
			LOG_Builder.startCorrelation();
		}

		LOG_Builder.build().info('Order request received').emitAt('OrderAPI.createOrder');
	}
}
```

---

## Structured Context

### Global Context

When you set up a piece of work, you often want every log from that point on to carry the same details (which account, which user, which industry) without repeating them on every
call. Global context lets you set those key-value pairs once, and they attach to all later log entries in the transaction:

```apex
public void processAccount(Account account)
{
	// Set context - appears in ContextData__c JSON
	LOG_Builder.setGlobalContext('accountId', account.Id);
	LOG_Builder.setGlobalContext('accountName', account.Name);
	LOG_Builder.setGlobalContext('industry', account.Industry);

	try
	{
		LOG_Builder.build().info('Processing started').emitAt('AccountService.processAccount');
		// Log entry includes: {"accountId":"001...","accountName":"Acme","industry":"Technology"}

		validateAccount(account);
		enrichAccount(account);

		LOG_Builder.build().info('Processing completed').emitAt('AccountService.processAccount');
	}
	finally
	{
		// Always clean up context
		LOG_Builder.clearGlobalContext('accountId');
		LOG_Builder.clearGlobalContext('accountName');
		LOG_Builder.clearGlobalContext('industry');
		// Or: LOG_Builder.clearAllGlobalContext();
	}
}
```

### Operation Context Stack

As your code runs, the framework automatically records which operation produced each log: the trigger action or the API call. It does this each time it hands work
to your code, so the context is filled in for you without any work on your part. `TRG_Dispatcher` adds it around each trigger action, and `API_Dispatcher` around each inbound and
outbound call. You do not manage this yourself; the framework keeps it accurate behind the scenes.

When you want to attach your own context to a single log entry, the positive path is `.withContext(key, value)`, which adds the pair right on that entry:

```apex
kern.LOG_Builder.build()
	.debug('Executing query')
	.withContext('queryType', 'SOQL')
	.withContext('objectName', 'Account')
	.withContext('soql', 'SELECT Id FROM Account WHERE Industry = :industry')
	.emitAt('MyClass.runQuery');
```

In your `LogEntry__c` records you will see operation types of `API_CALL`, `API_BATCH`, `TRIGGER_ACTION`, `QUERY`, `FLOW`, `LWC`, and `VALIDATION`. The dispatchers set all of these
for you, so you can filter logs by where they came from without doing anything extra.

---

## Performance Logging

To find what is making a transaction slow, you usually have to add timing code by hand. This framework does it for you: it times your queries, triggers, and API calls automatically,
with no code to write. Every timer also tracks how much of each governor limit the operation consumed (CPU time, heap, SOQL queries, DML), and it only writes a log when the
operation crosses a threshold you set, so fast operations stay quiet and only the slow ones surface.

### What Gets Automatically Timed

**Query performance.** Every `QRY_Builder` and `SEL_*` query is timed for you. The log entry records the SOQL statement, the row count, the object name, and the cache status
(hit/miss/stored). That lets you spot slow queries and N+1 patterns (the same query run once per record in a loop) without adding timing to each selector by hand.

**Trigger action performance.** Each action dispatched by `TRG_Dispatcher` is timed with full context: the action class name, the trigger operation (for example `BEFORE_INSERT`), the
object name, and the record count. This tells you which trigger actions are taking the most of your transaction time.

**API operation performance.** Outbound and inbound API calls that go through the web services framework are timed for you, capturing the HTTP method, the endpoint, and the response
status, so you can see which integrations are slow.

These timers are on by default, and each one writes a log only when an operation runs longer than its threshold. Only data-masking timing is off by default. You
turn each timer on or off and set the thresholds in `LogSetting__c` (see
[Performance Configuration](#performance-configuration) below).

### Custom Timing in Your Own Code

The timers above belong to the framework's own operations; there is no timer to call for a piece of your own code. To time a custom batch step or a callout the same way, measure
it yourself and log the result as context. The duration is kept as context data on the entry (the duration column the framework's own timers fill is theirs alone), and the entry
lands in the same searchable log stream and carries the tracking ID of the user action it belongs to, so your timing shows up alongside everything else that ran.

```apex
Long startedAt = System.currentTimeMillis();
// ... do work ...
kern.LOG_Builder.build().info('Reconciliation finished').withContext('durationMs', System.currentTimeMillis() - startedAt).emitAt('ReconciliationJob.execute');
```

`LOG_Builder.scope()` is not a timer. It records nothing about when work started or finished and writes no log entry of its own: it holds the entries you emit inside it and
publishes them together when you close it, which is what keeps a busy loop under the platform's publish cap. [Log Buffering](#log-buffering) explains it.

### Performance Configuration

Configure via `LogSetting__c` (Setup > Custom Settings > Log Setting):

| Field                                   | Description                                           | Default |
|-----------------------------------------|-------------------------------------------------------|---------|
| `EnablePerformanceLogging__c`           | Enable general performance logging                    | `true`  |
| `PerformanceThresholdMs__c`             | Threshold for general operations (ms)                 | `10000` |
| `EnableQueryPerformanceLogging__c`      | Enable query performance logging                      | `true`  |
| `QueryPerformanceThresholdMs__c`        | Threshold for queries (ms)                            | `1000`  |
| `EnableTriggerPerformanceLogging__c`    | Enable trigger performance logging                    | `true`  |
| `TriggerPerformanceThresholdMs__c`      | Threshold for trigger actions (ms)                    | `500`   |
| `EnableValidationPerformanceLogging__c` | Enable validation performance logging                 | `true`  |
| `ValidationPerformanceThresholdMs__c`   | Threshold for validation processing (ms)              | `100`   |
| `EnableMaskerPerformanceLogging__c`     | Enable data-masking performance logging (default OFF) | `false` |
| `MaskerPerformanceThresholdMs__c`       | Threshold for one masking run (ms)                    | `100`   |

Masker performance logging emits one combined `LogEntryEvent__e` per masking run (for example, one per trigger batch), but only when `EnableMaskerPerformanceLogging__c` is true
and the masker's elapsed time meets the threshold. It is off by default so you pay zero log volume unless you ask for it. Turn it on when you are investigating slow saves and want
to know how much of the time is data masking. Each entry's `ClassMethod__c` says what was masked, so you can group the results:

- `UTIL_MaskerPerformanceTimer/<object>` (for example `UTIL_MaskerPerformanceTimer/Foobar__c`): masking a batch of records in a trigger.
- `UTIL_MaskerPerformanceTimer/ApiCall__c.<field>` (for example `UTIL_MaskerPerformanceTimer/ApiCall__c.Request__c`): masking an API call payload that is too long
  for its field, once, when it is written to the call.
- `UTIL_MaskerPerformanceTimer/ContentVersion`: the step that builds a call's payload files had to mask a payload again.

---

## Log Buffering

Each `.emit()` publishes a `LogEntryEvent__e` straight away: the event goes out as soon as it is published, not when your transaction commits, so it is not rolled back if the
transaction later fails, and each publish call counts against the platform's limit of 150 immediate publishes per transaction. A long loop of emits can use them all up, so a later
publish in the same transaction fails, such as a scope's flush or your own `EventBus.publish` call, and every event counts against your org's platform-event allocations. To use
far fewer publish calls, tell the framework to hold entries and publish them together rather than one at a time. This is buffering, and it
[reduces platform event publishes](https://developer.salesforce.com/docs/atlas.en-us.platform_events.meta/platform_events/platform_events_publish.htm).

The simplest form is a scope. Open one, emit as usual inside a try/finally, and close it: every entry below ERROR level emitted inside is held, then published together when
`scope.close()` runs, in chunks of 50 events per publish call so a large batch stays within the platform's payload limit.

```apex
kern.LOG_Builder.LogScope scope = kern.LOG_Builder.scope();
try
{
	for(SObject record : records)
	{
		kern.LOG_Builder.build().debug('Processing: ' + record.Id).emitAt('BulkProcessor.process');
		processRecord(record);
	}
}
finally
{
	scope.close();
}
```

`suspendSaving()`, `flushBuffer()` and `resumeSaving()` are the same mechanism by hand, for when you want to flush part-way through a long loop:

```apex
public void processBulkRecords(List<SObject> records)
{
	// Suspend immediate publishing - logs are buffered
	LOG_Builder.suspendSaving();

	try
	{
		Integer processedCount = 0;

		for(SObject record : records)
		{
			LOG_Builder.build().debug('Processing: ' + record.Id).emitAt('BulkProcessor.process');
			processRecord(record);
			processedCount++;

			// Optionally flush periodically to avoid memory issues
			if(Math.mod(processedCount, 100) == 0)
			{
				LOG_Builder.flushBuffer();
			}
		}
	}
	finally
	{
		// Resume and flush all remaining logs
		LOG_Builder.resumeSaving();
	}
}
```

> **Note:** ERROR-level logs skip the buffer and are sent immediately, even while buffering is on. That way an error is never sitting unpublished in the buffer when you need to see it.
> The one exception is a trigger the framework runs on a platform event or change event: there an ERROR waits with the rest and is written when the trigger ends.
> A buffer that reaches 500 entries publishes itself without waiting for the close, so memory stays bounded in a long loop. A flush that fails loses the entries in it, as the
> trade-off under [How does it work?](#how-does-it-work) explains.

---

## LWC Client-Side Logging

You can log from your Lightning components the same way you log from Apex, and those client-side logs land in the same place with the same tracking ID. The `utilityLogger` module gives
your component that logging, and it tracks the correlation ID for you so a click in the browser and the Apex it triggers show up together.

### LWC Setup

Import the logging functions your component needs (a default export bundling all of them is also available):

```javascript
import {debug, info, warn, error} from 'kern/utilityLogger';
```

A user who is not a System Administrator needs access to the Apex class the logger writes through, or the entries are refused. Assign the **Kern Component Access**
permission set (it also grants the Flow logging actions), or add Apex class access for `kern.CTRL_Logger` (the name Setup shows under Apex Class Access) to a
permission set they already have. Kern Administrator includes it.

### LWC Basic Usage

When you catch an error, pass the `Error` object itself as the second argument to `error()`. The framework keeps both halves: the error's message lands in the entry's context, and its JavaScript stack is saved as the entry's stack trace, so the record you open later shows what actually failed in the browser.

```javascript
import {ComponentBuilder} from 'kern/componentBuilder';
import {debug, info, error} from 'kern/utilityLogger';

export default class MyComponent extends ComponentBuilder('notification')
{
	connectedCallback()
	{
		info('Component initialized');
	}

	handleButtonClick()
	{
		debug('Button clicked');

		try
		{
			this.processData();
		}
		catch(err)
		{
			// Pass the Error itself: its message and JavaScript stack persist with the entry
			error('Processing failed', err);
		}
	}

	processData()
	{
		info('Processing data', {
			recordCount: this.records.length
		});
	}
}
```

### LWC Correlation

```javascript
import {ComponentBuilder} from 'kern/componentBuilder';
import {startCorrelation, endCorrelation, info, error} from 'kern/utilityLogger';
import processRecords from '@salesforce/apex/MyController.processRecords';

export default class MyComponent extends ComponentBuilder('notification', 'controller')
{
	async handleProcess()
	{
		// Start correlation for this user action
		const correlationId = startCorrelation('Process records');

		try
		{
			// Pass correlation to Apex - logs will be linked
			const result = await processRecords({
				recordIds: this.selectedIds,
				correlationId: correlationId
			});

			info('Process completed', {
				successCount: result.successCount
			});
		}
		catch(err)
		{
			error('Process failed', err);
		}
		finally
		{
			// Closes the correlation and flushes the buffered logs to the server
			endCorrelation();
		}
	}
}
```

If you would rather not manage the start/end pair yourself, `withCorrelation(actionName, asyncFn)` wraps it for you; see the [LWC guide](LWC%20-%20Guide.md#utilitylogger---client-side-logging) for the full `utilityLogger` surface.

### LWC Performance Timing

```javascript
import {startTimer, error} from 'kern/utilityLogger';

async loadData()
{
	const timer = startTimer('LoadAccountData');

	try
	{
		const data = await getAccountData({accountId: this.recordId});
		timer.stop(); // Logs duration

		this.accountData = data;
	}
	catch(err)
	{
		timer.stop();
		error('Failed to load data', err);
	}
}
```

### Server Persistence

Logs you write in the browser are not useful until they reach Salesforce and become records. The `utilityLogger` module sends its buffered logs to the server for you. A framework
controller receives them and joins the browser's correlation ID to the server-side entries, so the whole user action stays linked from the click through to the Apex.

The payload you logged survives the trip too: your context keys are saved on the entry in `ContextData__c`, and a JavaScript error's stack becomes the entry's stack trace. What you
open later in [the Log Console](#the-log-console) is the client's story, not server plumbing.

**How It Works:**

```text
+----------------------+     +----------------------+     +------------------+
|   utilityLogger.js   |---->|  Server Controller   |---->|    LOG_Engine    |
|   (LWC Module)       |     |                      |     |                  |
|                      |     |                      |     |                  |
| - Buffers logs       |     | - Sets correlation   |     | - Publishes      |
| - Auto-flush on end  |     | - Pushes LWC context |     |   LogEntryEvent__e |
+----------------------+     +----------------------+     +------------------+
```

**Client Log Entry Structure:**

| Property        | Type          | Description                                                                                                 |
|-----------------|---------------|-------------------------------------------------------------------------------------------------------------|
| `timestamp`     | Datetime      | When the log was created                                                                                    |
| `level`         | LoggingLevel  | DEBUG, INFO, WARN, ERROR                                                                                    |
| `message`       | String        | Log message                                                                                                 |
| `correlationId` | String        | Links related logs                                                                                          |
| `context`       | String (JSON) | Key-value context data, saved on the entry in `ContextData__c`; an `errorStack` key becomes the stack trace |

**Server-Side Processing:**

When logs arrive from LWC, the server controller:

1. Extracts the correlation ID from the first log entry
2. Links it with any subsequent server-side logs
3. Pushes an LWC operation context onto the context stack
4. Logs each entry via [`LOG_Builder`](reference/apex/LOG_Builder.md): the client context is saved on the entry in `ContextData__c`, a client JavaScript error stack (the `errorStack` key) becomes the entry's stack trace, and the action name you gave `startCorrelation` becomes the entry's source label (`LWC/<action>`)
5. Pops the LWC context

This ensures LWC logs appear in `LogEntry__c` with proper correlation, context, and stack trace, exactly as [the Log Console](#the-log-console)'s detail drawer shows them.

### Console Fallback

If the logs cannot reach the server (for example the Apex call fails), they are not lost: the framework writes them to the browser console instead, so you can still see them while
debugging:

```text
[utilityLogger] Server persistence failed: [error details]
[utilityLogger] Buffered entries:
  [INFO] 2025-01-15T10:30:00.000Z | abc-123-def | Component initialized {...}
  [ERROR] 2025-01-15T10:30:01.000Z | abc-123-def | Process failed {...}
```

---

## Flow Logging ([`FLOW_LoggerStart`](reference/apex/FLOW_LoggerStart.md), [`FLOW_LoggerLog`](reference/apex/FLOW_LoggerLog.md), [`FLOW_LoggerEnd`](reference/apex/FLOW_LoggerEnd.md))

Admins and flow builders can log from a screen flow or record-triggered flow without writing Apex, using invocable actions. There are two ways to do it: a single action for one-off
messages, and a three-action "bookend" pattern when you want every log in the flow tied together. A user who is not a System Administrator and runs a screen flow
with these actions needs access to the Apex classes behind them: assign the **Kern Component Access** permission set, or add Apex class access for the action
classes to a permission set they already have.

### Flow Simple Logging

When you just need to drop a single log message and do not need it linked to anything else, use the one-shot [`FLOW_WriteLog`](reference/apex/FLOW_WriteLog.md) action:

**[`FLOW_WriteLog`](reference/apex/FLOW_WriteLog.md)** (Full control):

- `message` (Required) - The message to log
- `logLevel` (Optional) - DEBUG, INFO, WARN, ERROR (Flow Builder offers these as a picklist)
- `shortMessage` (Optional) - Brief summary
- `classMethod` (Optional) - Context identifier
- `recordId` (Optional) - Associated record
- `correlationId` (Optional) - Link to existing correlation

Entries written by this action carry the origin Flow. Their source is the class name you pass in `classMethod`, or `FLOW_WriteLog` when you leave it blank.

### Flow Bookend Pattern

When you want every log from a flow tied together (so you can see the whole run as one story), use the bookend pattern: one action to start, one to log each message, and one to end.
You start the correlation once, pass the returned ID into each log along the way, and close it out at the end. Entries from these three actions carry the origin Flow; the start and end entries name the Flow as their source, and each logged message names the Flow as its source when you fill in its Flow Name input; left blank, it names the step you give it in the Flow Step input, or `action` when that is blank too. The three invocable actions are:

**1. [`FLOW_LoggerStart`](reference/apex/FLOW_LoggerStart.md)** - Begin correlation (shown in Flow Builder as **Start Flow Correlation**)

| Input                          | Description                            |
|--------------------------------|----------------------------------------|
| `flowName` (Required)          | Name of the Flow                       |
| `recordId` (Optional)          | Associated record                      |
| `additionalContext` (Optional) | Extra context to store with the entry  |

| Output          | Description              |
|-----------------|--------------------------|
| `correlationId` | Generated correlation ID |

**2. [`FLOW_LoggerLog`](reference/apex/FLOW_LoggerLog.md)** - Log messages (shown in Flow Builder as **Log Flow Event**)

| Input                          | Description                                                                 |
|--------------------------------|-----------------------------------------------------------------------------|
| `correlationId` (Required)     | From FLOW_LoggerStart                                                       |
| `message` (Required)           | Log message                                                                 |
| `logLevel` (Optional)          | DEBUG, INFO, WARN, ERROR (picklist in Flow Builder)                         |
| `flowStep` (Optional)          | Current Flow step, shown as **Flow Step**                                   |
| `flowName` (Optional)          | Name of the Flow, so the entry is filed under the Flow rather than the step |
| `recordId` (Optional)          | Associated record                                                           |
| `additionalContext` (Optional) | Extra context to store with the entry                                       |

**3. [`FLOW_LoggerEnd`](reference/apex/FLOW_LoggerEnd.md)** - End correlation (shown in Flow Builder as **End Flow Correlation**)

| Input                      | Description                                  |
|----------------------------|----------------------------------------------|
| `correlationId` (Required) | From FLOW_LoggerStart                        |
| `flowName` (Required)      | Name of the Flow                             |
| `success` (Optional)       | Whether the Flow finished successfully       |
| `errorMessage` (Optional)  | What went wrong, when it did not             |

**Example Flow:**

```text
+----------------------------------------+
|  Start Flow Correlation                |
|  flowName: "Account Approval Flow"     |
|  recordId: {!$Record.Id}              |
|  -> Store correlationId in {!varCorr}  |
+-------------------+--------------------+
                    |
                    v
+----------------------------------------+
|  Log Flow Event                        |
|  correlationId: {!varCorr}             |
|  message: "Approval request created"   |
|  logLevel: "INFO"                      |
|  flowStep: "Create Request"            |
+-------------------+--------------------+
                    |
                    v
          +-----------------+
          |  Decision Node  |
          +--------+--------+
                   |
        +----------+----------+
        |                     |
        v                     v
+---------------+     +---------------+
|  Log: Approved|     |  Log: Rejected|
|  logLevel:INFO|     |  logLevel:WARN|
+-------+-------+     +-------+-------+
        |                     |
        +----------+----------+
                   |
                   v
+----------------------------------------+
|  End Flow Correlation                  |
|  correlationId: {!varCorr}             |
|  flowName: "Account Approval Flow"     |
|  success: {!varApproved}               |
+----------------------------------------+
```

---

## Testing

In unit tests, logging is turned off by default so it does not add noise or side effects to your tests. When the thing you are actually testing *is* the logging, switch it back on
first:

```apex
@IsTest(seeAllData=false isParallel=true)
private class MyService_TEST
{
	@IsTest
	private static void shouldLogErrorOnFailure()
	{
		LOG_Builder.ignoreTestMode = true;

		Test.startTest();

		try
		{
			MyService.processInvalidData();
			Assert.fail('Expected exception');
		}
		catch(Exception e)
		{
			// Expected
		}

		Test.stopTest();

		List<LogEntry__c> logs = QRY_Builder.selectFrom(LogEntry__c.SObjectType)
			.fields(new List<SObjectField>{LogEntry__c.Id, LogEntry__c.LogLevel__c, LogEntry__c.Message__c})
			.toList();
		Assert.isFalse(logs.isEmpty(), 'Error should be logged');
		Assert.areEqual('ERROR', logs[0].LogLevel__c);
	}
}
```

---

## The Log Console

When something breaks in production, the question is rarely "show me every log row". It is "what is failing, how often, and what happened around it?". The Log Console answers that
in two moves: a grouped view that surfaces distinct problems with occurrence counts, and a detail drawer that walks one occurrence end to end, across every trigger, background job,
and callout that shared its tracking ID.

You never write a query to use it. Filtering, search, grouping, and the timeline all work over the `LogEntry__c` rows the framework has already saved, and browsing changes
nothing: the console only reads.

### Where It Lives

Open it from the **App Launcher** (search "Log Console"), from its launch card on the **Kern Home** page, or navigate directly to `/lightning/n/LogConsole`. The
[Administration Tools guide](Administration%20Tools%20-%20Guide.md) tours it alongside the other consoles.

Access sits behind the **Kern Administrator** permission set. The console deliberately shows every user's log rows, not just your own, so a production problem is visible no matter
whose click triggered it. That breadth is exactly why access is gated to administrators.
Log entries are private records owned by the background process that saves them, so outside the console a user sees them only through View All
Records, which the Kern Administrator set includes (see [Who can see the framework's own records?](Security%20-%20Guide.md#who-can-see-the-frameworks-own-records)).

### The Two Views

Two buttons at the top switch how the same window of logs is read:

- **Problem summary** (the default) folds the window into distinct problems: one row per recurring event, with its total occurrence count and when it last fired. Rows reach it
  two ways. Events logged with a fingerprint group into a single row, where the daily counters supply the count and the kept sample supplies the message, level, and source (the
  reading side of [Log Grouping & Flood Control](#log-grouping--flood-control)); those rows carry a **Tagged** badge. Errors and warnings it can attribute are grouped as it reads,
  gathering entries that share a source, an error type and a level. [Problem Grouping](#problem-grouping) covers both, and what controls them. The framework's own bypass audit
  is fingerprinted for you, so it appears here automatically. Rows sort by severity, worst first; within a severity, the most frequent problem sits at the top.
- **Individual entries** shows the flat rows, newest first: every kept entry, including the ones no problem row covers. The counter rows that only hold a tally stay out of this
  list, so everything you see is a real, inspectable entry.

Every column is sortable, apart from Chain in Individual entries, and sorting happens on the server, so it orders the full result in your date range, not just the rows
on the page you are looking at. The Source column sorts by the name of the class, Flow or component that wrote each entry. The **Log Number** column links straight to the
`LogEntry__c` record.

### Problem Grouping

Most production problems are not one bad log line. They are the same failure repeating. Problem
summary is built for that: instead of a wall of near-identical rows, it shows one row per problem,
with how many times it happened and when it last fired.

Two different things put a row there, and it is worth knowing which is which.

**The console groups your logs for you.** When you open Problem summary, the console reads the
entries in your date range and gathers together the ones that share the same source, the same error
type, and the same level. Nothing is written, nothing is deleted, and every occurrence stays a full
entry you can still open from Individual entries. This happens on any org with no code change and no
setup at all, and it is on unless somebody turns it off.

The error type it groups on is the entry's `ExceptionType__c`: the Apex exception class where one was thrown, and for an entry logged from a Lightning web component either the
JavaScript error's name or the Apex type relayed from a failed server call. Failures from your components therefore group the same way Apex ones do, and the same field is what you
filter or report on when you want one kind of error.

**Or you name a problem yourself in code.** When you tag an event with a fingerprint, the framework
stops storing every repeat and starts counting them instead (this is
[Log Grouping & Flood Control](#log-grouping--flood-control)). Those problems carry a **Tagged**
badge in the list, and they appear whatever level they were logged at.

| | Grouped for you | Tagged in code |
|---|---|---|
| How the problem forms | The console works it out each time you open the list | Your code names it with `withFingerprint(...)` |
| What is stored | Every occurrence stays a full, openable entry | The first occurrence is kept in full, later repeats become daily counters |
| What holds the problem together | Its source, error type and level, taken together | The key you chose, on its own |
| How the row is marked | **Grouped** in the Log Number column, and *Any context* in the Context column | A **Tagged** badge |
| What the count means | The entries still on file inside the window you selected | Every repeat your code has reported, added up across its counter rows |

The two never overlap, so nothing is counted twice: an entry the framework has already folded into a
counter is never grouped again at read time.

Because the counts are measured differently, they can move differently. A grouped problem's count
falls when your purge job removes the entries behind it, since it counts what is still on file. A
tagged problem's count does not, and it can be far higher than the one entry you can open, because
it is the tally your code reported.

**Three things keep an entry out of the grouped half:**

- **It has to say something about itself.** Grouping needs an entry to carry either the class and
  method it came from or the type of error that occurred. Everything the logger writes now carries
  at least one of the two: a bare `warn('something happened')` with no `.at(...)` is stamped with
  the class and method that called it, read from the call stack, and an entry logged from an
  exception carries the exception's type. What still has nothing to group on is an entry with
  neither, such as a row written straight into `LogEntry__c` by something other than the logger, or
  a bare entry written before this version was installed; those stay in Individual entries. The
  drawer's one-line fix, described below, is still the way to group a problem under a name you
  choose rather than the class it came from.
- **It has to repeat.** A one-off is not a problem. By default something must happen at least twice
  inside your date range before it earns a row.
- **It has to be at a level grouping covers.** Out of the box that is ERROR and WARN, which is where
  problems worth chasing live and what keeps the reading cheap on a busy org. Whenever grouping runs, a
  caption above the list tells you which levels are covered: *"Problem grouping covers ERROR and WARN.
  Problems tagged in code appear at every level."* When grouping is skipped, the status bar described
  below takes that spot instead. Switch on a level outside that scope and its entries still appear in
  Individual entries, and your tagged problems still appear here, but nothing at that level is grouped
  for you. Its card in the ribbon says so, marked **(tagged only)**.

#### Settings

Three fields on `LogSetting__c` control grouping (Setup > Custom Settings > Log Setting). Like the
rest of that object they are hierarchical, so you can set a value for the whole org and override it
for a profile or a single user. None of them changes what gets logged, and none of them deletes
anything: they only change what the console does when it reads.

| Field | Type | Default | What it does |
|---|---|---|---|
| `ProblemGroupingDisabled__c` | Checkbox | unchecked (grouping on) | Tick it to stop the console grouping your logs. Problem summary then lists only the problems you tagged in code. This is the off-switch to reach for in an incident: no deployment, effective on the next read. |
| `ProblemGroupingMinimumOccurrences__c` | Number | 2 | How many times something must happen inside your date range before it counts as a problem. Leave it blank for 2. Raise it on a noisy org to see only what repeats a lot. |
| `ProblemGroupingLogLevels__c` | Text(255) | `ERROR;WARN` | Which log levels grouping is allowed to look at. Separate them with semicolons or commas, either works. Leave it blank for `ERROR;WARN`. |

`ProblemGroupingLogLevels__c` is a ceiling, not a preference. The console's own level buttons narrow
within it and can never widen it, so setting it to `ERROR` means INFO is never grouped no matter what
you switch on in the toolbar. That is deliberate: the setting is what bounds the cost of the read.
A level the framework does not recognise is ignored rather than passed on, so a typo can narrow the
scope but never widen it, and a value with no usable level in it falls back to `ERROR;WARN` rather
than switching the feature off quietly.

#### When Grouping Does Not Run

Grouping can be skipped, and when it is, Problem summary says so in a bar above the list rather than
showing you a short list and letting you assume it is the whole story. In all four cases the problems
you tagged in code are still listed, so the view is never empty of everything.

| What happened | What the console says | The action it offers |
|---|---|---|
| Somebody ticked `ProblemGroupingDisabled__c` | "Problem grouping is off, so this list shows only the errors you have tagged yourself." | **Open Log Settings** |
| You have typed a search term | "Problem grouping cannot apply your search, so these are your tagged problems only. Individual entries searches every word of every log." | **Search every log in Individual entries** |
| The levels you are viewing sit outside `ProblemGroupingLogLevels__c` | "Problem grouping is set up for ERROR and WARN, and the levels you are viewing are not among them. Showing tagged problems only." | **Open Log Settings** |
| The date range holds too many entries to read in one pass | "This date range holds too many entries for the console to group them, so only your tagged problems are shown." | **Narrow the date range** |

Search is the one that surprises people, so it is worth saying plainly why: grouping has to gather
entries by their source and error type, and it cannot do that and match free text inside a message
body at the same time. Individual entries can, which is where the console points you.

The empty state tells you which situation you are in too. If grouping ran and simply found nothing
repeating, you get *"No repeating problems match these filters."* If grouping did not run and you
have nothing tagged, you get *"No problems match these filters."* with a line pointing back at the
bar above it. An empty grid never leaves you guessing whether your logs went missing.

#### Opening a Grouped Problem

Click a grouped row and the drawer shows the problem rather than a single entry:

- **Overview** carries the message from the most recent occurrence, the occurrence count, and
  **First seen** and **Last seen** with both the relative time and the exact instant.
- **Open latest occurrence** opens the newest entry behind the problem, with its own stack trace,
  context and timeline.
- **View occurrences** takes you to Individual entries filtered to that problem's source and level,
  with a line reconciling the two numbers, for example: *"This problem was counted 16 times in this
  window. The list shows the 16 entries still on file from its source and level."*
- **Track this as a named problem** is the tagging affordance, covered next. When the entries were
  logged without a source you get **Name the source of these errors** instead, which hands you the
  same snippet without the fingerprint line, shaped around `.emitAt(...)` so the entries gain a source
  to group on.
- If nothing behind the problem can be opened (your purge job removed the entries between the reading
  and the click), the drawer says *"None of the entries behind this problem can be opened right now,
  so only the grouped summary is shown."* and shows the summary rather than failing. The Stack trace
  tab says the same thing in its own words.

#### Tagging a Problem in Code

Grouping works out a problem from its source, error type and level. That is a good identity until
someone renames the class or moves the method, at which point the old problem stops and a new one
starts. Tagging gives the problem a name you own instead, and the name survives a refactor.

The drawer writes the code for you. Open a grouped problem, expand **Track this as a named problem**,
and copy the snippet. It is built from that problem's own level, error type and source, so it pastes
straight into the code that produced it and compiles as it stands. It looks like this:

```apex
kern.LOG_Builder.build()
	.error(caughtException)
	.withFingerprint('PaymentSync.run:System.CalloutException')
	.emitAt('PaymentSync.run');
```

Replace `caughtException` with whatever your `catch` block calls the exception. Two things to know
before you paste it:

- **Tagging changes how those errors are stored.** From then on the first occurrence is kept in full
  and every repeat becomes a lightweight counter rather than its own record. That is the point (it is
  what stops a hot loop flooding the table), but it does mean you can no longer open each occurrence
  individually. Entries already logged are untouched.
- **A fingerprint groups by your key alone.** It carries no level and no error type, so tagging merges
  across levels where grouping separates by them. If you want an ERROR and a WARN of the same event
  counted separately, give them different keys.

#### When the Range Is Too Big to Group

Grouping reads the entries in your window to work the problems out, so a wide window over a busy org
eventually asks for more than one request can safely read. Rather than failing the page, the console
declines in advance and tells you.

**Problem summary stops grouping when the window you have selected holds more than about 35,000
entries that grouping would look at**, meaning untagged entries at the covered levels that carry a
source or an error type. You still get your tagged problems, and the status bar above the list tells
you what happened. Three things bring grouping back, cheapest first: narrow the levels you are viewing
with the console's own level buttons, narrow the date range, or tighten the
`ProblemGroupingLogLevels__c` scope. Note that this counts entries inside the window, not rows in the
table, so a very large log table with a quarter-hour window is entirely fine.

There is a separate, similar limit on the other view. **Individual entries stops breaking its summary
ribbon down by level and source above roughly 22,000 entries in the window.** When that happens the
ribbon still shows you the exact total and says *"This range holds too many entries to break down by
level and source. Narrow the range or the level filter to see the breakdown."* The list itself keeps
working normally, and a search-scoped ribbon is not affected at all.

#### A Worked Example

Overnight, a payment gateway starts timing out. Your integration class catches the exception and logs
it once per failed order, and by morning there are 900 of them.

You open the Log Console, leave the range on the last 24 hours, and switch nothing else. Problem
summary shows one ERROR row:

```text
Log Number   Message                             Level   Source            Count   Last seen
Grouped      Gateway timed out after 30000 ms    ERROR   PaymentSync.run     900   4 minutes ago
```

One row, not 900. You click it, read the newest occurrence's message, open that occurrence to see the
stack trace and the correlation timeline, and click **View occurrences** to scan the individual
failures for a pattern in the order sizes.

Nothing was configured to make that happen, and nothing was lost: all 900 entries are still there in
Individual entries.

Now you decide this one is worth watching properly. You expand **Track this as a named problem**, copy
the snippet, and paste it into the `catch` block:

```apex
try
{
	gateway.charge(order);
}
catch(CalloutException e)
{
	kern.LOG_Builder.build()
		.error(e)
		.withFingerprint('PaymentSync.run:System.CalloutException')
		.emitAt('PaymentSync.run');
	throw e;
}
```

Next time the gateway has a bad night you get one full entry plus a running count instead of 900
rows, the problem keeps its name if you rename the class, and the row carries a **Tagged** badge so
you can see at a glance that somebody chose to watch it.

### The Summary Ribbon

Across the top, a ribbon summarises the whole window whichever page of the list you are on:

- a **total** card: the total occurrences and how many distinct problems they fold into (in Individual entries, the count of matching rows instead),
- one card per active **level**, showing that level's occurrences and its distinct-problem count (row counts in Individual entries), and
- a **Top sources** card ranking the three writers producing the most activity, each shown with its origin (Framework, Apex, Flow or Component, or Mixed when the problem's entries span more than one): its share of occurrences in Problem summary, its row count in Individual entries.

The cards are shortcuts, not just numbers: click a level card to narrow the list to that level, or click a source to pin the list to exactly that writer. The pin shows as a removable pill and the Origin filter follows the writer's origin, so the count on the card is the count in the list, and a Mixed writer is pinned by name across every origin. Removing the pill leaves the Origin filter where the drill set it, so you can widen to the whole origin in one click; **Clear all** puts it back to every origin. An **Origin** filter beside Context narrows either view to one origin on its own.

**When totals show as approximate.** Two different things can leave the number best-effort, and the badge's help text tells you which one you are looking at. A very busy window
can hold more grouped activity than the console reads in one pass, so the counts cover the most recent activity only and the true total is higher. Or part of the list could not be
worked out for the date range at all, in which case its share is missing from the totals rather than trimmed, and the help text says so instead. Either way the
**Totals approximate** badge is the console being honest about a best-effort number instead of presenting it as exact. Narrow the date range and it disappears.

#### Who wrote an entry

Every entry records two facts about its writer at the moment it is written:

- **Origin**: Framework (Kern's own code), Apex (your Apex), Flow (an entry written through the framework's Flow actions), or Component (an entry written through the framework's component logger). Origin says who wrote the entry, not where the code was running: Apex a component called is Apex, and the Context filter's Aura / LWC is what tells you it ran in a component's request.
- **Source**: the class, Flow or component that wrote it, as a plain name: `UTIL_AsyncChain`, `Order Intake`, `orderPanel`. In the list, this column shows that name, then the method and line the entry recorded, with who wrote it shown beside it (Framework, Apex, Flow, Component, or Mixed on a problem whose entries span more than one); clicking the column heading sorts by the writer's name. Entries written before this version was installed show their class and method as before, with nothing beside them saying who wrote it.

The class-method field still holds the exact location, class and method. Origin and Source are ordinary fields on the log entry (`Origin__c` and `Source__c`), so your own reports and list views can group by them, and the entry's record page shows both to anyone whose permission sets grant the two fields. The Administrator permission set that ships with Kern grants them; if your org gives log access through permission sets of its own, add the two fields there as well. The Log Console shows them either way. A problem whose entries were written under more than one origin shows Mixed.

If you leave `.at('Class.method')` out, the framework reads the class and method from the call stack, so the entry still names a writer and can reach the Top sources card. The writer it reads is the method that called `emit()`: if a helper of your own wraps the logger, the helper is what gets named, so pass `.at(...)` from the helper when you want the business class instead. A class and method you give always wins over the one the framework reads, and an entry you log from an exception is the one case where nothing is read: it carries the exception's own trace, so pass `.at(...)` when you want that entry to say who wrote it.

Entries written before this version was installed carry neither value: they still count in the totals and the level cards, and the Top sources card leaves them out until they age out of your retention window.

Where Kern is deployed from source rather than installed as the managed package, its code cannot be told apart from yours: in an org with no namespace every Apex entry, the framework's included, shows as Apex, and in an org with its own namespace every entry whose class carries that namespace shows as Framework, the framework's and yours alike; Flow and component entries keep their own origin either way. With the managed package installed in an org that has a namespace of its own, the class read from the call stack carries that namespace; the framework recognises a namespace it can see a class in and removes it, so those entries group under the class name, and a class and method you pass with the namespace in it group the same way.

### Filters, Search, and Date Range

- **Log levels.** Toggle ERROR, WARN, INFO, and DEBUG independently. ERROR and WARN start on, so the console opens showing problems rather than routine tracing.
- **Execution context.** Filter to where the code was running: Batch Apex, Queueable, Queueable finalizer, Scheduled, Future, Aura / LWC, REST API, Synchronous, or Anonymous Apex.
- **Origin.** Narrow to the entries the framework wrote, the ones your Apex wrote, the ones a Flow wrote, or the ones a component wrote. Drilling into a writer on the Top sources card sets this for you.
- **Date range.** One picklist covers rolling windows (Last 15 minutes up to Last 30 days), calendar ranges (Today, Yesterday, This week, Last week, This month) computed in your
  time zone, and a custom From/To date-and-time pair. The default is the last 24 hours.
- **Search.** One box searches messages and problem text, stack traces, source class and method names, and tracking IDs, re-querying when you pause typing. Paste a whole tracking
  ID and the console recognises it: an action's ID pins the whole action, a chain run's ID pins that run, and the box clears; anything else is searched as text. What you type is
  looked for as text: `*`, `?` and words such as `OR` are characters and words to find, not instructions to the search, and several words are found together, in the order you
  typed them. Problem text and tracking IDs match on any part of their text and match immediately; a message body or stack trace matches on whole words through Salesforce's
  search index, so an entry saved seconds ago can take a moment to become findable by its body.

Results come a page at a time: a position line under the list says which rows you are looking at, Previous and Next move through them, page numbers appear while there are few
enough to use, and you can show 25, 50 or 100 rows a page. The ribbon keeps describing the whole window whichever page is showing. If a search matches more rows than the console
will page through, a banner says so and asks you to narrow the filters. **Refresh** re-runs everything; **Clear all** returns every filter to its default.

### The Detail Drawer

Click any row and a drawer opens with the entry's full story, in four tabs:

- **Overview**: the full message, plus a details grid: the log number, the source (`Class.method:line`), the execution context, the user who produced the entry (shown by name; the
  console resolves the stored user ID for you, sidestepping the `CreatedById` trap described under [Querying Log Entries](#querying-log-entries)), the action the entry belongs to
  (with a note when the entry was written by the action itself, outside any chain, when the entry's own chain started the action, or when it predates action tracking), the
  correlation ID, named with its chain when a chain run holds it, and the transaction and parent-transaction IDs. In Problem summary the drawer also shows the occurrence count and
  the first-seen and last-seen times. Below that sit the **governor limits at capture**: usage bars for each limit the transaction had consumed when the entry was saved, showing
  only the limits actually used.
- **Stack trace**: the stored stack trace, with a copy button. For an Apex entry this is the code that led to the entry, the logging framework's own steps left
  out; for an entry logged from a Lightning component it is the client's JavaScript stack (see [Server Persistence](#server-persistence)). When nothing was
  recorded, the tab says so and names where the entry was logged from. Every copy button in the drawer says exactly what it copies: message, action ID, correlation ID,
  code, stack trace, context.
- **Context**: the entry's context data as JSON, the key-value pairs attached through global context, `.withContext(...)`, or a client-side log call.
- **Timeline**: the correlated execution, described next.

**Open record** opens the standard `LogEntry__c` record page for the entry.

**Show the whole action** pins the action the entry belongs to; the next section describes what that shows. It hides while that action is already pinned.

### The Timeline Tab

The timeline reconstructs the whole operation the entry belongs to. Every entry sharing the correlation ID is grouped into its Apex transactions and laid out in time order, so you
see the operation the way it actually ran: a click, the synchronous transaction it started, and the queueables, batch steps, and finalizers that followed.

Each transaction group shows where the work ran, when it started relative to the first entry (`start`, `+3s`, `+2m`), how long it spanned, how many entries it holds, and a colour
for its worst severity. A breadcrumb notes which transaction spawned it, and a gap marker calls out a hop that started long after its parent ended (it was queued, or a step may be
missing). For long chains, a compact overview strip at the top maps the whole run; click a segment to jump to that transaction.

Click any entry in the timeline to focus it in place: its full message, stack trace, and context appear inline, so you can walk hop by hop through the operation without losing
your place in the console. A very long trace is capped, and the drawer points you to the Chain Monitor for the rest.

An entry with no correlation ID shows a single-entry timeline and says so plainly: it stands alone.

### The Whole Action

An action is one thing a user or a job did: a click, a scheduled run, an inbound call. Log entries carry the action's tracking ID beside their own, so the console can show
you everything the action did, the entries the action wrote itself and the entries of every chain it launched, however many that is.

Pin an action from the drawer's **Show the whole action**, from the Chain Monitor's **Show the action's logs**, or by pasting the action's ID into the search box. The console then
switches to Individual entries, turns ERROR, WARN and INFO on (DEBUG stays as you had it), lists the entries oldest first, and sets the date range to the action's lifetime, from
its first entry to its last, with a status line under the date range that says so. That line stays until you change the range yourself, so you are never left on a range you did not
choose without the sentence that explains it. Removing the pill keeps the range; **Clear all** returns everything to its default.

Each pin is part of the page's address. Pin an action, or narrow it to one chain, and the browser's Back button undoes that one step; a refresh keeps what you pinned; and you can
share the address with a colleague, who opens the console on the same pins.

Under the ribbon, one banner tells the action's story in a sentence: when it started, how long it ran (or how long it has been running), how many chains ran under it and how many
failed. Every number is exact, however large the action. At most five chains follow as chips, the failed ones first. A chip says how its chain entered the action when that was not
the action itself: launched by a named chain (a step of that chain launched it), a restart of a named run, or the run that started the action. Click a chip and the list narrows to
that chain, shown as a removable pill named after the chain; remove it and you are back to the whole action. The rest of the chains are a number, and **Open the chains in the
Chain Monitor** lists all of them there.

The **Chain** column names the chain behind each row (its name and number), says "this action" for an entry the action wrote itself, and shows a dash when no chain holds the
entry's tracking ID and the action did not write the entry itself. It is not sortable.

An action recorded before chains were tracked by action has no root on its entries. Its own correlation ID stands in: the drawer's Action row says so, the banner says the action
was recorded before chains were tracked by action, and when a chain adopted the action's ID that chain is the one chip.

Nothing here draws a tree. Nesting shows in words on the chips, and in full in the Chain Monitor's Launched under column, which the next section describes.

### To and From the Chain Monitor

When the correlated operation is a registered [async chain](Async%20Processing%20-%20Guide.md), the drawer offers **Open in Chain Monitor**, which opens that chain's live status
view. The console verifies that a chain really exists for the correlation before showing the action, so you never land on an empty monitor. Entries that are correlated but not
part of a registered chain get a timeline note saying so instead.

The link works in the other direction too: the Chain Monitor's detail panel has a **View logs** action that opens the Log Console pre-filtered to that chain's correlation ID. A
deep link like that lands on Individual entries with all four levels on and the widest rolling window, so an older chain's rows are still visible, and the pinned correlation shows
as a removable pill, so you can see, and clear, exactly what is filtering the list. That pinned run and its window are part of the address too, so a refresh keeps them and Back
returns you to the Chain Monitor.

The two consoles also link at the level of a whole action. The banner's **Open the chains in the Chain Monitor** lists the action's chains there, with a Launched under column that
says what launched each one; the Chain Monitor's **Show the action's logs**, beside its pill and in a run's detail, brings you back here with the whole action pinned. An
action-level link carries no date window: the console sets the range from the action's lifetime instead.

For a single chain the Chain Monitor also carries its own [live activity stream](Async%20Processing%20-%20Guide.md#the-live-activity-stream): the run's entries, seeded newest-first
and then streaming in as they happen. The console remains the place to browse, search, and diagnose across chains and everything else your code logged.

### What the Log Console Does Not Do

- **It never changes your data.** Browsing, filtering, and drilling are reads. There is no edit, delete, or purge in the console.
- **It reads this framework's log table only.** It shows `LogEntry__c` rows. Salesforce debug logs and other packages' log stores do not appear here.
- **Grouping needs something to group on.** An entry that records neither the class and method it came from nor an error type has no shape the console can recognise, so it
  appears in Individual entries but never in a problem row. The logger stamps one or the other on everything it writes (a call with no `.at('Class.method')` is stamped with
  the class and method that made it, read from the call stack), so such an entry is rare: a row written straight into `LogEntry__c` by something other than the logger, or a
  bare entry written before this version was installed. Give such an event a [fingerprint](#log-grouping--flood-control) in code and it joins the problems.
  Grouping also stays inside the log levels it is configured for, and stands down on a date range too large to read in one pass; see [Problem Grouping](#problem-grouping).
- **It is not an analytics dashboard.** For charts, trends, and scheduled reporting, build reports and dashboards on `LogEntry__c` (see
  [Querying Log Entries](#querying-log-entries)). The console is for finding and diagnosing problems now.

---

## Querying Log Entries

When you want to browse or diagnose logs interactively, [the Log Console](#the-log-console) is the front door and needs no query at all. This section is for when you query
`LogEntry__c` yourself: in reports, dashboards, cleanup scripts, or Apex.

There is one trap to know about before you query your logs. When you want the logs for a particular user (in reports, dashboards, cleanup scripts, or audit
queries), **filter by `UserId__c`, NOT by `CreatedById`**. Filtering by `CreatedById` looks correct but silently returns nothing, and the next section explains why.

### Why

Remember that logs are saved asynchronously: `LOG_Builder.emit()` publishes a `LogEntryEvent__e` Platform Event, and the framework's trigger action that saves log entries (run by the `TRG_LogEntryEvent` trigger)
inserts the `LogEntry__c` row. Salesforce runs Platform Event triggers as the **Automated Process** user (for example `autoproc@<orgid>`), no matter who fired the event. So every saved
`LogEntry__c.CreatedById` is the Automated Process user, never the person whose code logged the message.

The real user is captured separately. At publish time the framework records the emitting user's Id on `LogEntryEvent__e.UserId__c`, and `TRG_PersistLogEntry` copies it onto
`LogEntry__c.UserId__c`. That field, not `CreatedById`, is the one to use when you ask "which user produced this log".

### Right vs wrong

```apex
// RIGHT — returns logs from the running user
List<LogEntry__c> myLogs = QRY_Builder.selectFrom(LogEntry__c.SObjectType)
    .condition(LogEntry__c.UserId__c).equals(UserInfo.getUserId())
    .orderBy(LogEntry__c.CreatedDate).descending()
    .toList();

// WRONG — silently returns ZERO rows on persisted entries
List<LogEntry__c> brokenQuery = QRY_Builder.selectFrom(LogEntry__c.SObjectType)
    .condition(LogEntry__c.CreatedById).equals(UserInfo.getUserId())
    .toList();
```

### Reports and dashboards

The same rule applies to declarative reports, dashboards, and list views. To filter by the user who emitted the log, add a column or filter on **User ID** (`kern__UserId__c`), not
Created By.

One thing to know: `UserId__c` is a Text(18) field, not a Lookup, so you cannot traverse `UserId__r.Name` to get the user's name. To filter or display by user name, build a report
type that joins `LogEntry__c.UserId__c` to the `User` object, using a Report Type Cross-Filter or a custom report formula. There is a companion field, `UserLink__c`, which is a formula
that renders an "Open" hyperlink to the user record, so a report can include a one-click jump from a log row to the User detail page. Use `UserLink__c` for navigation and `UserId__c`
for filtering.

### Cleanup scripts

Cleanup queries should filter by `UserId__c` too. You can still use a `WHERE CreatedDate < ...`
clause against the Automated Process user's records; the user running the cleanup just needs delete
access to `LogEntry__c`.

```apex
// Delete logs older than 30 days emitted by a specific user
List<LogEntry__c> stale = QRY_Builder.selectFrom(LogEntry__c.SObjectType)
    .condition(LogEntry__c.UserId__c).equals(targetUserId)
    .andCondition(LogEntry__c.CreatedDate).lessThan(Datetime.now().addDays(-30))
    .toList();
DML_Builder.newTransaction().doDelete(stale).execute();
```

### Sharing considerations

Log entries are private by default, and the automated user that saves them in the background owns every one, so no person owns a log entry.
A person therefore sees a log entry in one of two ways: they hold View All Records on `LogEntry__c` (the Kern Administrator permission set
includes it), or a sharing rule shares the entry with them. If a team needs to see some log entries without View All Records, add a
criteria-based sharing rule. For example, a rule with a condition on `UserId__c` shares the entries of the user you name with a public group
or a role you choose. The [Security Guide](Security%20-%20Guide.md#who-can-see-the-frameworks-own-records) explains who can see the
framework's other records.

---

## How do I configure this?

### `LogSetting__c` Fields

These settings control what gets logged and when, with no deployment needed. They are a hierarchical custom setting, which means you can set a value for the whole org and then
override it for a profile or an individual user (Org, then Profile, then User). Configure them in Setup > Custom Settings > Log Setting.

<details>
<summary>All <code>LogSetting__c</code> fields</summary>

| Field                                   | Type      | Default | Description                                                                                                       |
|-----------------------------------------|-----------|---------|-------------------------------------------------------------------------------------------------------------------|
| `IsEnabled__c`                          | Checkbox  | true    | Master off-switch you can flip in an incident without a deployment. When false, all non-ERROR logs are dropped.   |
| `LogLevelThreshold__c`                  | Text(10)  | DEBUG   | Minimum level to log (DEBUG, INFO, WARN, ERROR)                                                                   |
| `ClassFilter__c`                        | Text(255) | blank   | Comma-separated class name patterns with trailing `*` wildcard (e.g., `API_*,SVC_Payment*`). Blank = all classes. |
| `MaxContextDataSize__c`                 | Number    | 32768   | Max characters for ContextData__c                                                                                 |
| `ProblemGroupingDisabled__c`            | Checkbox  | false   | Stops [the Log Console grouping your logs into problems](#problem-grouping). Tagged problems still appear. Nothing is logged differently and nothing is deleted. |
| `ProblemGroupingMinimumOccurrences__c`  | Number    | 2       | How many times something must happen inside the date range before it counts as a problem. Blank means 2.          |
| `ProblemGroupingLogLevels__c`           | Text(255) | ERROR;WARN | Which log levels problem grouping may look at, separated by semicolons or commas. Blank means ERROR;WARN.      |
| `EnablePerformanceLogging__c`           | Checkbox  | true    | Enable general performance logging                                                                                |
| `PerformanceThresholdMs__c`             | Number    | 10000   | Threshold for general timers (ms)                                                                                 |
| `EnableQueryPerformanceLogging__c`      | Checkbox  | true    | Enable query performance logging                                                                                  |
| `QueryPerformanceThresholdMs__c`        | Number    | 1000    | Threshold for query timers (ms)                                                                                   |
| `EnableTriggerPerformanceLogging__c`    | Checkbox  | true    | Enable trigger performance logging                                                                                |
| `TriggerPerformanceThresholdMs__c`      | Number    | 500     | Threshold for trigger timers (ms)                                                                                 |
| `EnableValidationPerformanceLogging__c` | Checkbox  | true    | Enable validation performance logging                                                                             |
| `ValidationPerformanceThresholdMs__c`   | Number    | 100     | Threshold for validation timers (ms)                                                                              |
| `EnableMaskerPerformanceLogging__c`     | Checkbox  | false   | Enable masker performance logging (off by default; opt in)                                                        |
| `MaskerPerformanceThresholdMs__c`       | Number    | 100     | Threshold for masking on a trigger batch (ms)                                                                     |

</details>

### `TriggerSetting__mdt` Fields (Trigger Performance)

| Field                         | Type     | Description                            |
|-------------------------------|----------|----------------------------------------|
| `EnablePerformanceLogging__c` | Checkbox | Override LogSetting__c for this object |
| `PerformanceThresholdMs__c`   | Number   | Threshold for this object's triggers   |

### `TriggerAction__mdt` Fields (Action-Level Control)

| Field                           | Type     | Description                      |
|---------------------------------|----------|----------------------------------|
| `ForcePerformanceLogging__c`    | Checkbox | Always log this action           |
| `SuppressPerformanceLogging__c` | Checkbox | Never log this action            |
| `PerformanceThresholdMs__c`     | Number   | Custom threshold for this action |

When the same setting is defined in more than one place, the most specific one wins. The order, from highest priority to lowest, is:

1. TriggerAction__mdt (action-specific)
2. TriggerSetting__mdt (object-specific)
3. LogSetting__c (global)

---

## Anti-Patterns

These are the common mistakes people make when logging (an "anti-pattern" is a tempting approach that causes problems later). Each row shows what to avoid, why it bites you, and what
to do instead.

| Anti-Pattern                                     | Why It's Wrong                                                        | Instead                                                                                                                                                                                                                |
|--------------------------------------------------|-----------------------------------------------------------------------|------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| Using `System.debug()`                           | Output is ephemeral, not queryable, and lost after debug log rotation | Use `LOG_Builder.build().error(e).emitAt('Class.method')`                                                                                                                                                              |
| Logging without class.method context             | Impossible to trace which code generated a log entry                  | Always provide context via `.emitAt('ClassName.methodName')` or `.at('ClassName.methodName')`                                                                                                                          |
| Logging personal data or secrets (passwords, tokens, SSNs) | Breaks compliance rules and creates security holes | The data masking framework (`MaskingRule__mdt` + `MaskingTarget__mdt`) is on by default and redacts the patterns it is configured for on every `LogEntryEvent__e`. Add your own rules if your data has patterns the defaults do not cover |
| Missing correlation in async operations          | Cannot trace a logical operation across transaction boundaries        | Use `LOG_Builder.setCorrelationId(correlationId)` or `serializeContext()`/`hydrateContext()` to propagate correlation IDs across async boundaries                                                                      |
| Forgetting to close log scopes                   | Buffered log entries may not be emitted, causing silent data loss     | Always call `scope.close()` in a `finally` block                                                                                                                                                                       |

---

## Best Practices

### Always Include Context

```apex
// Good - includes class.method context and record correlation
LOG_Builder.build().error(e).at('OrderService.processOrder').forRecord(orderId).emit();

// Bad - no context
LOG_Builder.build().error(e.getMessage()).emit();
```

### Use Appropriate Log Levels

| Level | When to Use                          |
|-------|--------------------------------------|
| DEBUG | Detailed tracing during development  |
| INFO  | Business events, milestones          |
| WARN  | Potential issues, recoverable errors |
| ERROR | Failures requiring attention         |

### Never Log Sensitive Data

```apex
// Bad - logs password
LOG_Builder.build().debug('Password: ' + password).emitAt('AuthService.login');

// Good - no sensitive data
LOG_Builder.build().debug('Login attempt for user: ' + username).emitAt('AuthService.login');
```

### Use Correlation for Async Operations

```apex
// Always propagate context to async jobs
public void initiateProcess(Id recordId)
{
	LOG_Builder.startCorrelation();
	String context = LOG_Builder.serializeContext();
	System.enqueueJob(new ProcessQueueable(recordId, context));
}
```

### Clean Up Context

```apex
// Always use try/finally for context cleanup
LOG_Builder.setGlobalContext('accountId', account.Id);
try
{
	// Process...
}
finally
{
	LOG_Builder.clearGlobalContext('accountId');
}
```

### Enable Performance Logging for Critical Operations

Turn on performance logging in `LogSetting__c` to surface your slow operations. The framework already times queries, trigger actions, and API calls for you, with no code changes. To
time your own code as well, measure it and log the duration as context, as [Custom Timing in Your Own Code](#custom-timing-in-your-own-code) shows.

---

## Troubleshooting

### Logs Not Appearing

1. **Check test mode**: Ensure `LOG_Builder.ignoreTestMode = true` in tests
2. **Check IsEnabled**: Verify `LogSetting__c.IsEnabled__c` is `true` (Setup > Custom Settings > Log Setting)
3. **Check threshold**: Ensure `LogLevelThreshold__c` allows your log level (e.g., `DEBUG` captures all)
4. **Check class filter**: If `ClassFilter__c` is set, verify your class matches the pattern
5. **Check platform event limits**:
   Monitor [event publishing limits](https://developer.salesforce.com/docs/atlas.en-us.platform_events.meta/platform_events/platform_event_limits.htm)
6. **Remember that a failed publish is silent**: if the event publish itself fails, the entry is dropped with no retry and no fallback write. A publish that throws leaves at
   most a `FAILED TO PUBLISH LOG EVENTS` debug line, visible only while an Apex trace flag is active; a per-event rejection reported by the platform (for example on allocation
   exhaustion) leaves no trace at all

### Missing Correlation

1. **Verify startCorrelation() called**: Must be called at entry point
2. **Check async propagation**: Ensure `serializeContext()`/`hydrateContext()` used
3. **Check LWC**: Ensure correlationId passed to Apex methods

### Performance Logs Missing

1. **Check enable flags**: Verify `EnablePerformanceLogging__c` is true
2. **Check threshold**: Operation may be faster than threshold
3. **Check your own timing**: The framework times only its own operations. For your own code, measure the duration yourself and add it with `.withContext(key, value)`

### Context Not Appearing

1. **Check setGlobalContext()**: Verify called before logging
2. **Check clear calls**: Ensure no `clearGlobalContext(key)` or `clearAllGlobalContext()` call removed the key before you logged. For a single entry, use `.withContext(key, value)`
3. **Check MaxContextDataSize__c**: Large context may be truncated

---

## Related Documentation

- [Objects & Metadata - Guide](Objects%20%26%20Metadata%20-%20Guide.md) - LogEntry__c, LogSetting__c details
- [Administration Tools - Guide](Administration%20Tools%20-%20Guide.md) - The consoles on the Kern Home page, the Log Console included
- [Async Processing - Guide](Async%20Processing%20-%20Guide.md) - Async context propagation patterns and the Chain Monitor
- [Web Services - Guide](Web%20Services%20-%20Guide.md) - Automatic API logging
- [Triggers - Guide](Triggers%20-%20Guide.md) - Trigger action logging
- [Fast Start - Logging](Fast%20Start%20-%20Logging.md) - Quick-start primer for logging
