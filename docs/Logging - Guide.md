---
navOrder: 18
---

# Logging - Guide

**Framework:** KernDX
**Package Type:** Managed Package
**API Version:** 67.0

> **Note if your org uses a custom namespace:** When using KernDX with a custom namespace, prefix framework class references with your namespace (e.g., `ClientNS.LOG_Builder`). See
> the [AI Agent Instructions](AI%20Agent%20Instructions.md) for details.

**Target Audience:**

- **Developers** - Implementing logging across Apex, LWC, and Flows
- **Architects** - Designing observability and traceability patterns
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
5. [Quick Start](#quick-start)
    - [Apex - Log an Error](#apex---log-an-error)
    - [LWC - Log with Correlation](#lwc---log-with-correlation)
    - [Flow - Correlated Logging](#flow---correlated-logging)
6. [What is it, and where is it already wired in?](#what-is-it-and-where-is-it-already-wired-in)
7. [How does it work?](#how-does-it-work)
8. [Apex Logging (LOG_Builder)](#apex-logging-log_builder)
    - [Log Levels](#log-levels)
    - [Exception Logging](#exception-logging)
    - [DML Error Logging](#dml-error-logging)
    - [Batch Logging](#batch-logging)
    - [Log Grouping & Flood Control](#log-grouping--flood-control)
    - [Logging Inside Platform Event & Change Event Triggers](#logging-inside-platform-event--change-event-triggers)
9. [Correlation Tracking](#correlation-tracking)
    - [Starting Correlation](#starting-correlation)
    - [Async Context Propagation](#async-context-propagation)
    - [External Correlation](#external-correlation)
10. [Structured Context](#structured-context)
    - [Global Context](#global-context)
    - [Operation Context Stack](#operation-context-stack)
11. [Performance Logging](#performance-logging)
    - [What Gets Automatically Timed](#what-gets-automatically-timed)
    - [Custom Timing in Your Own Code](#custom-timing-in-your-own-code)
    - [Performance Configuration](#performance-configuration)
12. [Log Buffering](#log-buffering)
13. [LWC Client-Side Logging](#lwc-client-side-logging)
    - [LWC Setup](#lwc-setup)
    - [LWC Basic Usage](#lwc-basic-usage)
    - [LWC Correlation](#lwc-correlation)
    - [LWC Performance Timing](#lwc-performance-timing)
    - [Server Persistence](#server-persistence)
    - [Console Fallback](#console-fallback)
14. [Flow Logging (FLOW_LoggerStart, FLOW_LoggerLog, FLOW_LoggerEnd)](#flow-logging-flow_loggerstart-flow_loggerlog-flow_loggerend)
    - [Flow Simple Logging](#flow-simple-logging)
    - [Flow Bookend Pattern](#flow-bookend-pattern)
15. [Testing](#testing)
16. [The Log Console](#the-log-console)
    - [Where It Lives](#where-it-lives)
    - [The Two Views](#the-two-views)
    - [The Summary Ribbon](#the-summary-ribbon)
    - [Filters, Search, and Date Range](#filters-search-and-date-range)
    - [The Detail Drawer](#the-detail-drawer)
    - [The Timeline Tab](#the-timeline-tab)
    - [To and From the Chain Monitor](#to-and-from-the-chain-monitor)
    - [What the Log Console Does Not Do](#what-the-log-console-does-not-do)
17. [Querying Log Entries](#querying-log-entries)
    - [Why](#why)
    - [Right vs wrong](#right-vs-wrong)
    - [Reports and dashboards](#reports-and-dashboards)
    - [Cleanup scripts](#cleanup-scripts)
    - [Sharing considerations](#sharing-considerations)
18. [How do I configure this?](#how-do-i-configure-this)
    - [LogSetting__c Fields](#logsetting__c-fields)
    - [TriggerSetting__mdt Fields (Trigger Performance)](#triggersetting__mdt-fields-trigger-performance)
    - [TriggerAction__mdt Fields (Action-Level Control)](#triggeraction__mdt-fields-action-level-control)
19. [Anti-Patterns](#anti-patterns)
20. [Best Practices](#best-practices)
    - [Always Include Context](#always-include-context)
    - [Use Appropriate Log Levels](#use-appropriate-log-levels)
    - [Never Log Sensitive Data](#never-log-sensitive-data)
    - [Use Correlation for Async Operations](#use-correlation-for-async-operations)
    - [Clean Up Context](#clean-up-context)
    - [Enable Performance Logging for Critical Operations](#enable-performance-logging-for-critical-operations)
21. [Troubleshooting](#troubleshooting)
    - [Logs Not Appearing](#logs-not-appearing)
    - [Missing Correlation](#missing-correlation)
    - [Performance Logs Missing](#performance-logs-missing)
    - [Context Not Appearing](#context-not-appearing)
22. [Related Documentation](#related-documentation)

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
import {ComponentBuilder} from 'c/componentBuilder';
import {startCorrelation, info, error} from 'c/utilityLogger';

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
Start Logger (flowName) → Log Message (correlationId, message) → End Logger (correlationId)
```

For deeper coverage, continue reading the sections below.

---

## What is it, and where is it already wired in?

> **What it does and does not do:** This framework only records diagnostic and operational data to `LogEntry__c`. It does not enforce business rules, write to your business
> objects, or change how your code runs. Its single job is to give you a kept, searchable record of what happened.

The framework is 4 `LOG_*` classes plus 1 platform event (`LogEntryEvent__e`), and it works the same way from Apex, LWC, and Flow. You do not have to add logging everywhere yourself: it is already built into all 14 API outbound services, every trigger handler, and the async processing framework, so those parts of the framework log for you.

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

You rarely need to do this reading by hand. [The Log Console](#the-log-console)'s **Problem summary** view performs the fold for you: one row per fingerprint, carrying the sample's message and the summed occurrence count. The rules above matter when you build your own reports or queries over the raw rows.

**Framework bypass audit** uses this mechanism automatically. (A "bypass" is when a developer turns off a safety check; the framework records who did it, on which surface, and against what target.) Each distinct bypass identity keeps exactly one detail row in retained logs plus daily counters, so a bypass that fires inside a hot loop can no longer flood the log table. A *new* bypass identity appearing in production, such as a new code path or a new user, still lands loudly as a fresh detail row, so you are not blind to genuinely new activity.

> **Note:** flood control reduces how many rows are *stored*, not how many events are *published*. Each occurrence still publishes a platform event and uses up your event allocations. If you need to stop the bypass-audit events themselves, the `BypassAudit_Enabled` feature flag is the off switch for that.

### Logging Inside Platform Event & Change Event Triggers

There is one place where logging needs special care, and the framework handles it for you so you do not have to think about it. Normally a log is published as a `LogEntryEvent__e`
platform event and saved a moment later (see [How does it work?](#how-does-it-work)). But if you log **while your code is running inside a platform event (`__e`) or Change Data Capture
(`*ChangeEvent`) trigger**, publishing a brand-new platform event from inside an event trigger can make the platform redeliver the original event. A "log on every delivery" pattern
would then turn into an endless redelivery loop.

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
		String externalCorrelationId = req.headers.get('X-Correlation-ID');

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

As your code runs, the framework automatically records which operation produced each log: the trigger action, the API call, the async chain step. It does this at every dispatcher
entry point, so the context is filled in for you without any work on your part. `TRG_Dispatcher` adds it around each trigger action, `API_Dispatcher` around each inbound and outbound
call, and `UTIL_AsyncChain` around each chain step. You do not manage this yourself; the framework keeps it accurate behind the scenes.

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

All of this performance logging is off by default and only fires once an operation crosses a threshold. You turn it on and set the thresholds in `LogSetting__c` (see
[Performance Configuration](#performance-configuration) below).

### Custom Timing in Your Own Code

When you want to time a piece of your own code (a custom batch step, a callout) the same way the framework times itself, wrap the work in a `LOG_Builder.scope()` block. The scope
records when the work started and finished and emits a `LogEntryEvent__e` that joins the same correlation chain as the framework's automatic timers, so your custom timing shows up
right alongside everything else for the same user action.

```apex
kern.LOG_Builder.LogScope scope = kern.LOG_Builder.scope();
try
{
	// ... do work ...
}
finally
{
	scope.close();
}
```

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
| `MaskerPerformanceThresholdMs__c`       | Threshold for masking on a trigger batch (ms)         | `100`   |

Masker performance logging emits one combined `LogEntryEvent__e` per trigger batch, but only when `EnableMaskerPerformanceLogging__c` is true and the masker's elapsed time meets the
threshold. It is off by default so you pay zero log volume unless you ask for it. Turn it on when you are investigating slow saves and want to know how much of the time is data
masking. Each entry carries the target SObject name in `ClassMethod__c` (for example `UTIL_MaskerPerformanceTimer/Foobar__c`), so you can group the results by object.

---

## Log Buffering

A batch job that logs once per record can publish thousands of platform events, and those events count against your org's allocations. To use far fewer, tell the framework to hold
logs and publish them together rather than one at a time. This is buffering, and it
[reduces platform event publishes](https://developer.salesforce.com/docs/atlas.en-us.platform_events.meta/platform_events/platform_events_publish.htm):

```apex
public void processBulkRecords(List<SObject> records)
{
	// Suspend immediate publishing - logs are buffered
	LOG_Builder.suspendSaving();

	try
	{
		for(SObject record : records)
		{
			LOG_Builder.build().debug('Processing: ' + record.Id).emitAt('BulkProcessor.process');
			processRecord(record);

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

---

## LWC Client-Side Logging

You can log from your Lightning components the same way you log from Apex, and those client-side logs land in the same place with the same tracking ID. The `utilityLogger` module gives
your component that logging, and it tracks the correlation ID for you so a click in the browser and the Apex it triggers show up together.

### LWC Setup

Import the logging functions your component needs (a default export bundling all of them is also available):

```javascript
import {debug, info, warn, error} from 'c/utilityLogger';
```

### LWC Basic Usage

When you catch an error, pass the `Error` object itself as the second argument to `error()`. The framework keeps both halves: the error's message lands in the entry's context, and its JavaScript stack is saved as the entry's stack trace, so the record you open later shows what actually failed in the browser.

```javascript
import {ComponentBuilder} from 'c/componentBuilder';
import {debug, info, error} from 'c/utilityLogger';

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
import {ComponentBuilder} from 'c/componentBuilder';
import {startCorrelation, endCorrelation, info, error} from 'c/utilityLogger';
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
import {startTimer, error} from 'c/utilityLogger';

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
messages, and a three-action "bookend" pattern when you want every log in the flow tied together.

### Flow Simple Logging

When you just need to drop a single log message and do not need it linked to anything else, use the one-shot [`FLOW_WriteLog`](reference/apex/FLOW_WriteLog.md) action:

**[`FLOW_WriteLog`](reference/apex/FLOW_WriteLog.md)** (Full control):

- `message` (Required) - The message to log
- `logLevel` (Optional) - DEBUG, INFO, WARN, ERROR (Flow Builder offers these as a picklist)
- `shortMessage` (Optional) - Brief summary
- `classMethod` (Optional) - Context identifier
- `recordId` (Optional) - Associated record
- `correlationId` (Optional) - Link to existing correlation

### Flow Bookend Pattern

When you want every log from a flow tied together (so you can see the whole run as one story), use the bookend pattern: one action to start, one to log each message, and one to end.
You start the correlation once, pass the returned ID into each log along the way, and close it out at the end. The three invocable actions are:

**1. [`FLOW_LoggerStart`](reference/apex/FLOW_LoggerStart.md)** - Begin correlation

| Input                    | Description         |
|--------------------------|---------------------|
| `flowName` (Required)    | Name of the Flow    |
| `flowVersion` (Optional) | Flow version number |
| `recordId` (Optional)    | Associated record   |

| Output          | Description              |
|-----------------|--------------------------|
| `correlationId` | Generated correlation ID |

**2. [`FLOW_LoggerLog`](reference/apex/FLOW_LoggerLog.md)** - Log messages

| Input                      | Description              |
|----------------------------|--------------------------|
| `correlationId` (Required) | From FLOW_LoggerStart    |
| `message` (Required)       | Log message              |
| `logLevel` (Optional)      | DEBUG, INFO, WARN, ERROR (picklist in Flow Builder) |
| `shortMessage` (Optional)  | Brief summary            |
| `recordId` (Optional)      | Associated record        |
| `stepName` (Optional)      | Current Flow step        |

**3. [`FLOW_LoggerEnd`](reference/apex/FLOW_LoggerEnd.md)** - End correlation

| Input                      | Description            |
|----------------------------|------------------------|
| `correlationId` (Required) | From FLOW_LoggerStart  |
| `status` (Optional)        | SUCCESS, FAILURE, etc. |
| `message` (Optional)       | Final message          |

**Example Flow:**

```text
+----------------------------------------+
|  Start Flow Logger                     |
|  flowName: "Account Approval Flow"     |
|  recordId: {!$Record.Id}              |
|  -> Store correlationId in {!varCorr}  |
+-------------------+--------------------+
                    |
                    v
+----------------------------------------+
|  Log Flow Message                      |
|  correlationId: {!varCorr}             |
|  message: "Approval request created"   |
|  logLevel: "INFO"                      |
|  stepName: "Create Request"            |
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
|  End Flow Logger                       |
|  correlationId: {!varCorr}             |
|  status: {!varFinalStatus}             |
+----------------------------------------+
```

---

## Testing

In unit tests, logging is turned off by default so it does not add noise or side effects to your tests. When the thing you are actually testing *is* the logging, switch it back on
first:

```apex
@IsTest(SeeAllData=false IsParallel=true)
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

### The Two Views

Two buttons at the top switch how the same window of logs is read:

- **Problem summary** (the default) folds the window into distinct problems: one row per recurring event, with its total occurrence count and when it last fired. This is the
  reading side of [Log Grouping & Flood Control](#log-grouping--flood-control): events logged with a fingerprint group into a single row, the daily counters supply the count, and
  the kept sample supplies the message, level, and source. The framework's own bypass audit is fingerprinted for you, so it appears here automatically. Rows sort by occurrence
  count, so the noisiest problem sits at the top.
- **Individual entries** shows the flat rows, newest first: every kept entry, including the ones logged without a fingerprint (which the Problem summary does not group). The
  counter rows that only hold a tally stay out of this list, so everything you see is a real, inspectable entry.

Every column in both views is sortable, and sorting happens on the server, so it orders the full result in your date range, not just the rows you have scrolled through. The
**Log Number** column links straight to the `LogEntry__c` record.

### The Summary Ribbon

Across the top, a ribbon summarises the whole window regardless of how far you have scrolled:

- a **total** card: the total occurrences and how many distinct problems they fold into (in Individual entries, the count of matching rows instead),
- one card per active **level**, showing that level's occurrences and its distinct-problem count (row counts in Individual entries), and
- a **Top sources** card ranking the three sources producing the most activity: each one's share of occurrences in Problem summary, its row count in Individual entries.

The cards are shortcuts, not just numbers: click a level card to narrow the list to that level, or click a source to drill into it.

**When totals show as approximate.** A very busy window can hold more grouped activity than the console reads in one pass. When that happens, the total card carries a
**Totals approximate** badge: the counts cover the most recent activity, and the true total may be higher. The badge is the console being honest about a best-effort number instead
of presenting it as exact. Narrow the date range and it disappears.

### Filters, Search, and Date Range

- **Log levels.** Toggle ERROR, WARN, INFO, and DEBUG independently. ERROR and WARN start on, so the console opens showing problems rather than routine tracing.
- **Execution context.** Filter to where the code was running: Batch Apex, Queueable, Queueable finalizer, Scheduled, Future, Aura / LWC, REST API, Synchronous, or Anonymous Apex.
- **Date range.** One picklist covers rolling windows (Last 15 minutes up to Last 30 days), calendar ranges (Today, Yesterday, This week, Last week, This month) computed in your
  time zone, and a custom From/To date-and-time pair. The default is the last 24 hours.
- **Search.** One box searches messages and problem text, stack traces, source class and method names, and correlation IDs, re-querying when you pause typing. Problem-text and
  correlation matches are immediate; matches inside a long message body or stack trace go through Salesforce's search index, so an entry saved seconds ago can take a moment to
  become findable by its body.

Results load a page at a time as you scroll, while the ribbon keeps describing the whole window. If a search matches more rows than the console will page through, a banner says so
and asks you to narrow the filters. **Refresh** re-runs everything; **Clear all** returns every filter to its default.

### The Detail Drawer

Click any row and a drawer opens with the entry's full story, in four tabs:

- **Overview**: the full message, plus a details grid: the log number, the source (`Class.method:line`), the execution context, the user who produced the entry (shown by name; the
  console resolves the stored user ID for you, sidestepping the `CreatedById` trap described under [Querying Log Entries](#querying-log-entries)), the correlation ID, and the
  transaction and parent-transaction IDs. In Problem summary the drawer also shows the occurrence count and the first-seen and last-seen times. Below that sit the
  **governor limits at capture**: usage bars for each limit the transaction had consumed when the entry was saved, showing only the limits actually used.
- **Stack trace**: the stored stack trace, with a copy button. For an entry logged from a Lightning component this is the client's JavaScript stack (see
  [Server Persistence](#server-persistence)).
- **Context**: the entry's context data as JSON, the key-value pairs attached through global context, `.withContext(...)`, or a client-side log call.
- **Timeline**: the correlated execution, described next.

**Open record** opens the standard `LogEntry__c` record page for the entry.

### The Timeline Tab

The timeline reconstructs the whole operation the entry belongs to. Every entry sharing the correlation ID is grouped into its Apex transactions and laid out in time order, so you
see the operation the way it actually ran: a click, the synchronous transaction it started, and the queueables, batch steps, and finalizers that followed.

Each transaction group shows where the work ran, when it started relative to the first entry (`start`, `+3s`, `+2m`), how long it spanned, how many entries it holds, and a colour
for its worst severity. A breadcrumb notes which transaction spawned it, and a gap marker calls out a hop that started long after its parent ended (it was queued, or a step may be
missing). For long chains, a compact overview strip at the top maps the whole run; click a segment to jump to that transaction.

Click any entry in the timeline to focus it in place: its full message, stack trace, and context appear inline, so you can walk hop by hop through the operation without losing
your place in the console. A very long trace is capped, and the drawer points you to the Chain Monitor for the rest.

An entry with no correlation ID shows a single-entry timeline and says so plainly: it stands alone.

### To and From the Chain Monitor

When the correlated operation is a registered [async chain](Async%20Processing%20-%20Guide.md), the drawer offers **Open in Chain Monitor**, which opens that chain's live status
view. The console verifies that a chain really exists for the correlation before showing the action, so you never land on an empty monitor. Entries that are correlated but not
part of a registered chain get a timeline note saying so instead.

The link works in the other direction too: the Chain Monitor's detail panel has a **View logs** action that opens the Log Console pre-filtered to that chain's correlation ID. A
deep link like that lands on Individual entries with all four levels on and the widest rolling window, so an older chain's rows are still visible, and the pinned correlation shows
as a removable pill, so you can see, and clear, exactly what is filtering the list.

### What the Log Console Does Not Do

- **It never changes your data.** Browsing, filtering, and drilling are reads. There is no edit, delete, or purge in the console.
- **It reads this framework's log table only.** It shows `LogEntry__c` rows. Salesforce debug logs and other packages' log stores do not appear here.
- **The Problem summary groups fingerprinted events.** An entry logged without a fingerprint appears in Individual entries but is not folded into a problem row. Give your
  recurring events a [fingerprint](#log-grouping--flood-control) and the grouping works for you.
- **It is not an analytics dashboard.** For charts, trends, and scheduled reporting, build reports and dashboards on `LogEntry__c` (see
  [Querying Log Entries](#querying-log-entries)). The console is for finding and diagnosing problems now.

---

## Querying Log Entries

When you want to browse or diagnose logs interactively, [the Log Console](#the-log-console) is the front door and needs no query at all. This section is for when you query
`LogEntry__c` yourself: in reports, dashboards, cleanup scripts, or Apex.

There is one trap to know about before you query your logs. When you want the logs for a particular user (in reports, dashboards, cleanup scripts, or audit
queries), **filter by `UserId__c`, NOT by `CreatedById`**. Filtering by `CreatedById` looks correct but silently returns nothing, and the next section explains why.

### Why

Remember that logs are saved asynchronously: `LOG_Builder.emit()` publishes a `LogEntryEvent__e` Platform Event, and `TRG_PersistLogEntry` (a Platform Event subscriber trigger)
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

Because `TRG_PersistLogEntry` runs `inherited sharing`, the organization-wide default sharing on
`LogEntry__c` is judged against the Automated Process user's record access, not the access of the
user who emitted the log. If you want each user to see their own logs without giving them the
broad "View All" permission, add a criteria-based sharing rule keyed on `UserId__c`. That closes
the visibility gap for exactly those records.

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
time your own code as well, wrap the work in a `LOG_Builder.scope()` block:

```apex
kern.LOG_Builder.LogScope scope = kern.LOG_Builder.scope();
try
{
	kern.UTIL_HttpClient.post('MyGateway', '/charges').body(payload).send();
}
finally
{
	scope.close();
}
```

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
3. **Check timer API**: Ensure `stop()` is called (not `stopSilent()`)

### Context Not Appearing

1. **Check setGlobalContext()**: Verify called before logging
2. **Check push/pop balance**: Ensure `popOperationContext()` matches pushes
3. **Check MaxContextDataSize__c**: Large context may be truncated

---

## Related Documentation

- [Objects & Metadata - Guide](Objects%20%26%20Metadata%20-%20Guide.md) - LogEntry__c, LogSetting__c details
- [Administration Tools - Guide](Administration%20Tools%20-%20Guide.md) - The consoles on the Kern Home page, the Log Console included
- [Async Processing - Guide](Async%20Processing%20-%20Guide.md) - Async context propagation patterns and the Chain Monitor
- [Web Services - Guide](Web%20Services%20-%20Guide.md) - Automatic API logging
- [Triggers - Guide](Triggers%20-%20Guide.md) - Trigger action logging
- [Fast Start - Logging](Fast%20Start%20-%20Logging.md) - Quick-start primer for logging

---

**Last Updated:** July 2026
**Guide Version:** 2.2
