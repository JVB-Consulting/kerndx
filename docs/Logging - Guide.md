# Logging - Guide

**Framework:** KernDX
**Package Type:** Managed Package
**API Version:** 66.0

> **Note for Subscriber Implementations:** When using KernDX with a custom namespace, prefix framework class references with your namespace (e.g., `ClientNS.LOG_Builder`). See the [AI Agent Instructions](AI%20Agent%20Instructions.md) for details.

**Target Audience:**
- **Developers** - Implementing logging across Apex, LWC, and Flows
- **Architects** - Designing observability and traceability patterns
- **DevOps** - Monitoring and debugging production systems

---

## Table of Contents

<details>
<summary>Expand</summary>

1. [Quick Navigation](#quick-navigation)
2. [Overview](#overview)
3. [Architecture](#architecture)
4. [Quick Start](#quick-start)
   - [Apex - Log an Error](#apex---log-an-error)
   - [LWC - Log with Correlation](#lwc---log-with-correlation)
   - [Flow - Correlated Logging](#flow---correlated-logging)
5. [Apex Logging (LOG_Builder)](#apex-logging-log_builder)
   - [Log Levels](#log-levels)
   - [Exception Logging](#exception-logging)
   - [DML Error Logging](#dml-error-logging)
   - [Batch Logging](#batch-logging)
6. [Correlation Tracking](#correlation-tracking)
   - [Starting Correlation](#starting-correlation)
   - [Async Context Propagation](#async-context-propagation)
   - [External Correlation](#external-correlation)
7. [Structured Context](#structured-context)
   - [Global Context](#global-context)
   - [Operation Context Stack](#operation-context-stack)
8. [Performance Logging](#performance-logging)
   - [What Gets Automatically Timed](#what-gets-automatically-timed)
   - [Custom Timing in Subscriber Code](#custom-timing-in-subscriber-code)
   - [Performance Configuration](#performance-configuration)
9. [Log Buffering](#log-buffering)
10. [LWC Client-Side Logging](#lwc-client-side-logging)
    - [LWC Setup](#lwc-setup)
    - [LWC Basic Usage](#lwc-basic-usage)
    - [LWC Correlation](#lwc-correlation)
    - [LWC Performance Timing](#lwc-performance-timing)
    - [Server Persistence](#server-persistence)
    - [Console Fallback](#console-fallback)
11. [Flow Logging (FLOW_LoggerStart, FLOW_LoggerLog, FLOW_LoggerEnd)](#flow-logging-flow_loggerstart-flow_loggerlog-flow_loggerend)
    - [Flow Simple Logging](#flow-simple-logging)
    - [Flow Bookend Pattern](#flow-bookend-pattern)
12. [Testing](#testing)
13. [Querying Log Entries](#querying-log-entries)
    - [Why](#why)
    - [Right vs wrong](#right-vs-wrong)
    - [Reports and dashboards](#reports-and-dashboards)
    - [Cleanup scripts](#cleanup-scripts)
    - [Sharing considerations](#sharing-considerations)
14. [Configuration Reference](#configuration-reference)
    - [LogSetting__c Fields](#logsetting__c-fields)
    - [TriggerSetting__mdt Fields (Trigger Performance)](#triggersetting__mdt-fields-trigger-performance)
    - [TriggerAction__mdt Fields (Action-Level Control)](#triggeraction__mdt-fields-action-level-control)
15. [Anti-Patterns](#anti-patterns)
16. [Best Practices](#best-practices)
    - [1. Always Include Context](#1-always-include-context)
    - [2. Use Appropriate Log Levels](#2-use-appropriate-log-levels)
    - [3. Never Log Sensitive Data](#3-never-log-sensitive-data)
    - [4. Use Correlation for Async Operations](#4-use-correlation-for-async-operations)
    - [5. Clean Up Context](#5-clean-up-context)
    - [6. Enable Performance Logging for Critical Operations](#6-enable-performance-logging-for-critical-operations)
17. [Troubleshooting](#troubleshooting)
    - [Logs Not Appearing](#logs-not-appearing)
    - [Missing Correlation](#missing-correlation)
    - [Performance Logs Missing](#performance-logs-missing)
    - [Context Not Appearing](#context-not-appearing)
18. [Related Documentation](#related-documentation)

</details>

---

## Quick Navigation

| I am a...     | I need to...                      | Go to...                                                                                               |
|---------------|-----------------------------------|--------------------------------------------------------------------------------------------------------|
| **Architect** | Design observability patterns     | [Architecture](#architecture)                                                                          |
| **Architect** | Plan correlation tracking         | [Correlation Tracking](#correlation-tracking)                                                          |
| **Developer** | Log my first error                | [Quick Start](#quick-start)                                                                            |
| **Developer** | Add client-side logging           | [LWC Client-Side Logging](#lwc-client-side-logging)                                                    |
| **Developer** | Test logging behavior             | [Testing](#testing)                                                                                    |
| **Developer** | Query persisted log entries       | [Querying Log Entries](#querying-log-entries)                                                          |
| **Analyst**   | Configure log filtering           | [Configuration Reference](#configuration-reference)                                                    |
| **Analyst**   | Integrate logging in Flows        | [Flow Logging](#flow-logging-flow_loggerstart-flow_loggerlog-flow_loggerend)                           |

---

## Overview

The KernDX Logging Framework provides end-to-end observability across all Salesforce execution contexts. Unlike `System.debug()` which produces ephemeral debug logs, this framework persists logs to a queryable custom object (`LogEntry__c`) via [platform events](https://developer.salesforce.com/docs/atlas.en-us.platform_events.meta/platform_events/platform_events_intro.htm) (`LogEntryEvent__e`).

> **Responsibilities:** The Logging Framework persists diagnostic and operational data to `LogEntry__c`. It does not enforce business rules,
> perform DML on business objects, or control execution flow. Use it for observability only.

**Key Capabilities:**

| Feature | Description |
|---------|-------------|
| **Multi-Channel** | Log from Apex, LWC, and Flows with consistent API |
| **Correlation Tracking** | Link related logs across async boundaries with correlation IDs |
| **Context Stack** | Capture nested operation context (query details, trigger info, etc.) |
| **Performance Monitoring** | Automatic timing with configurable thresholds |
| **Structured Context** | Attach key-value metadata to log entries |
| **Log Buffering** | Batch logs for efficient publishing |

> **Logging Framework Scope:** 4 `LOG_*` classes, 1 platform event (`LogEntryEvent__e`), and multi-channel support (Apex, LWC, Flow). Logging
> is integrated across all 14 API outbound services, all trigger handlers, and the async processing framework.

---

## Architecture

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

**Flow:**
1. Code calls logging methods ([`LOG_Builder`](reference/apex/LOG_Builder.md), `utilityLogger`, [`FLOW_LoggerStart`](reference/apex/FLOW_LoggerStart.md) / [`FLOW_LoggerLog`](reference/apex/FLOW_LoggerLog.md) / [`FLOW_LoggerEnd`](reference/apex/FLOW_LoggerEnd.md))
2. `LOG_Engine` manages correlation IDs and context
3. Log entries are published as [platform events](https://developer.salesforce.com/docs/atlas.en-us.platform_events.meta/platform_events/platform_events_intro.htm) (`LogEntryEvent__e`) (non-blocking)
4. [`TRG_LogEntryEvent`](reference/apex/TRG_LogEntryEvent.md) trigger inserts records into `LogEntry__c`

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
import {logger} from 'c/utilityLogger';

export default class MyComponent extends ComponentBuilder('notification')
{
	connectedCallback()
	{
		logger.startCorrelation();
		logger.info('Component loaded', 'MyComponent.connectedCallback');
	}

	handleError(error)
	{
		logger.error(error.message, 'MyComponent.handleError');
	}
}
```

### Flow - Correlated Logging

```text
Start Logger (flowName) → Log Message (correlationId, message) → End Logger (correlationId)
```

For deeper coverage, continue reading the sections below.

---

## Apex Logging ([`LOG_Builder`](reference/apex/LOG_Builder.md))

[`LOG_Builder`](reference/apex/LOG_Builder.md) is the primary Apex interface for logging. All methods delegate to `LOG_Engine` for event publishing and context management.

### Log Levels

| Level | Method | Use Case |
|-------|--------|----------|
| DEBUG | `debug()` | Development tracing, detailed diagnostics |
| INFO | `info()` | Operational events, business milestones |
| WARN | `warn()` | Potential issues, degraded functionality |
| ERROR | `error()` | Failures requiring attention |

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

For partial DML operations, use `errorDMLOperationResults()` to extract and log all errors from `Database.SaveResult`, `Database.DeleteResult`, or `Database.UpsertResult` collections.

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

## Correlation Tracking

Correlation IDs link related log entries across transaction boundaries, making it possible to trace a user action from LWC through to async processing. The correlation ID is stored on each `LogEntryEvent__e` and subsequently on every `LogEntry__c` record, enabling filtering in `SEL_LogEntry` queries.

### Starting Correlation

```apex
// Generate new correlation ID
String correlationId = LOG_Builder.startCorrelation();

// All subsequent logs in this transaction share this correlationId
LOG_Builder.build().info('Step 1').emitAt('MyClass.myMethod');
LOG_Builder.build().info('Step 2').emitAt('MyClass.myMethod');
```

### Async Context Propagation

When spawning async work (Queueable, Batch, Future), serialize and restore context:

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

### External Correlation

When receiving requests from external systems with their own correlation IDs:

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

Attach key-value pairs to all subsequent log entries in the transaction:

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

The framework maintains an internal operation-context stack that is pushed and popped automatically at every dispatcher entry point — `TRG_Dispatcher` around each trigger action, `API_Dispatcher` around each inbound and outbound call, `UTIL_AsyncChain` around each chain step. Subscribers do not interact with the stack directly (`LOG_Engine.pushOperationContext` / `popOperationContext` are `public` framework-internal methods, not callable from subscriber Apex).

For per-call subscriber context, attach it directly to the log entry via `.withContext(key, value)`:

```apex
kern.LOG_Builder.build()
	.debug('Executing query')
	.withContext('queryType', 'SOQL')
	.withContext('objectName', 'Account')
	.withContext('soql', 'SELECT Id FROM Account WHERE Industry = :industry')
	.emitAt('MyClass.runQuery');
```

The framework-managed operation types you will see in `LogEntry__c` records are `API_CALL`, `API_BATCH`, `TRIGGER_ACTION`, `QUERY`, `FLOW`, `LWC`, and `VALIDATION` — all set automatically by the dispatchers.

---

## Performance Logging

The framework automatically times operations across queries, triggers, and API calls. No subscriber code is needed — timing is built into the framework infrastructure. All timers track governor limit deltas (CPU time, heap, SOQL queries, DML) and log only when configured thresholds are exceeded.

### What Gets Automatically Timed

**Query performance** — Every `QRY_Builder` and `SEL_*` query is timed automatically. Log entries include the SOQL statement, row count, object name, and cache status (hit/miss/stored). This helps identify slow queries and N+1 patterns without instrumenting individual selectors.

**Trigger action performance** — Each action dispatched by `TRG_Dispatcher` is timed with full context: action class name, trigger operation (e.g., `BEFORE_INSERT`), object name, and record count. This surfaces which trigger actions contribute most to transaction time.

**API operation performance** — Outbound and inbound API calls processed through the web services framework are timed automatically, capturing HTTP method, endpoint, and response status.

All performance logging is threshold-based and disabled by default. Enable and configure thresholds via `LogSetting__c` (see [Performance Configuration](#performance-configuration) below).

### Custom Timing in Subscriber Code

`UTIL_StopWatch` is the framework-internal base class used by the three specialised performance timers. It is declared `public` and is not intended for direct subscriber use. For ad-hoc timing around a custom batch step or callout, wrap the work in a `LOG_Builder.scope()` block — the scope captures start/end timestamps and emits a `LogEntryEvent__e` that joins the same correlation pipeline as the framework's automatic timers.

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

| Field | Description | Default |
|-------|-------------|---------|
| `EnablePerformanceLogging__c` | Enable general performance logging | `true` |
| `PerformanceThresholdMs__c` | Threshold for general operations (ms) | `10000` |
| `EnableQueryPerformanceLogging__c` | Enable query performance logging | `true` |
| `QueryPerformanceThresholdMs__c` | Threshold for queries (ms) | `1000` |
| `EnableTriggerPerformanceLogging__c` | Enable trigger performance logging | `true` |
| `TriggerPerformanceThresholdMs__c` | Threshold for trigger actions (ms) | `500` |
| `EnableValidationPerformanceLogging__c` | Enable validation performance logging | `true` |
| `ValidationPerformanceThresholdMs__c` | Threshold for validation processing (ms) | `100` |
| `EnableMaskerPerformanceLogging__c` | Enable data-masking performance logging (default OFF) | `false` |
| `MaskerPerformanceThresholdMs__c` | Threshold for masking on a trigger batch (ms) | `100` |

Masker performance logging emits one aggregate `LogEntryEvent__e` per trigger batch when `EnableMaskerPerformanceLogging__c` is true and the masker's elapsed time meets the threshold. Default off so subscribers pay zero log volume by default — turn on during investigation of slow commits to attribute the time to masking. Entries carry the target SObject name in `ClassMethod__c` (e.g., `UTIL_MaskerPerformanceTimer/Foobar__c`) for per-object aggregation.

---

## Log Buffering

For batch operations, buffer logs to reduce [platform event](https://developer.salesforce.com/docs/atlas.en-us.platform_events.meta/platform_events/platform_events_publish.htm) publishes:

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

> **Note:** ERROR-level logs bypass the buffer and trigger an immediate flush. This ensures error visibility even when buffering is active.

---

## LWC Client-Side Logging

The `utilityLogger` LWC module provides client-side logging with automatic correlation tracking.

### LWC Setup

Import the logger in your component:

```javascript
import {logger} from 'c/utilityLogger';
```

### LWC Basic Usage

```javascript
import {ComponentBuilder} from 'c/componentBuilder';
import {logger} from 'c/utilityLogger';

export default class MyComponent extends ComponentBuilder('notification')
{
	connectedCallback()
	{
		logger.info('Component initialized', 'MyComponent.connectedCallback');
	}

	handleButtonClick()
	{
		logger.debug('Button clicked', 'MyComponent.handleButtonClick');

		try
		{
			this.processData();
		}
		catch(error)
		{
			logger.error(error.message, 'MyComponent.handleButtonClick', {
				errorName: error.name,
				stack: error.stack
			});
		}
	}

	processData()
	{
		logger.info('Processing data', 'MyComponent.processData', {
			recordCount: this.records.length
		});
	}
}
```

### LWC Correlation

```javascript
import {ComponentBuilder} from 'c/componentBuilder';
import {logger} from 'c/utilityLogger';
import processRecords from '@salesforce/apex/MyController.processRecords';

export default class MyComponent extends ComponentBuilder('notification', 'controller')
{
	async handleProcess()
	{
		// Start correlation for this user action
		const correlationId = logger.startCorrelation();

		logger.info('Starting process', 'MyComponent.handleProcess');

		try
		{
			// Pass correlation to Apex - logs will be linked
			const result = await processRecords({
				recordIds: this.selectedIds,
				correlationId: correlationId
			});

			logger.info('Process completed', 'MyComponent.handleProcess', {
				successCount: result.successCount
			});
		}
		catch(error)
		{
			logger.error('Process failed: ' + error.body?.message, 'MyComponent.handleProcess');
		}
	}
}
```

### LWC Performance Timing

```javascript
import {logger} from 'c/utilityLogger';

async loadData()
{
	const timer = logger.startTimer('LoadAccountData');

	try
	{
		const data = await getAccountData({accountId: this.recordId});
		timer.stop(); // Logs duration

		this.accountData = data;
	}
	catch(error)
	{
		timer.stop();
		logger.error('Failed to load data', 'MyComponent.loadData');
	}
}
```

### Server Persistence

The `utilityLogger` module automatically persists buffered logs to the server. A framework controller bridges client-side and server-side logging, linking correlation IDs from the client with server-side log entries.

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

| Property | Type | Description |
|----------|------|-------------|
| `timestamp` | Datetime | When the log was created |
| `level` | LoggingLevel | DEBUG, INFO, WARN, ERROR |
| `message` | String | Log message |
| `correlationId` | String | Links related logs |
| `context` | Map<String, Object> | Additional context data |

**Server-Side Processing:**

When logs arrive from LWC, the server controller:
1. Extracts the correlation ID from the first log entry
2. Links it with any subsequent server-side logs
3. Pushes an LWC operation context onto the context stack
4. Logs each entry via [`LOG_Builder`](reference/apex/LOG_Builder.md)
5. Pops the LWC context

This ensures LWC logs appear in `LogEntry__c` with proper correlation and context.

### Console Fallback

If Apex persistence fails, logs automatically fall back to browser console:

```text
[utilityLogger] Failed to persist logs to server: [error details]
[utilityLogger] Fallback - buffered logs:
  [INFO] 2025-01-15T10:30:00.000Z | abc-123-def | Component initialized {...}
  [ERROR] 2025-01-15T10:30:01.000Z | abc-123-def | Process failed {...}
```

---

## Flow Logging ([`FLOW_LoggerStart`](reference/apex/FLOW_LoggerStart.md), [`FLOW_LoggerLog`](reference/apex/FLOW_LoggerLog.md), [`FLOW_LoggerEnd`](reference/apex/FLOW_LoggerEnd.md))

### Flow Simple Logging

For logging without correlation, use [`FLOW_WriteLog`](reference/apex/FLOW_WriteLog.md):

**[`FLOW_WriteLog`](reference/apex/FLOW_WriteLog.md)** (Full control):
- `message` (Required) - The message to log
- `logLevel` (Optional) - DEBUG, INFO, WARN, ERROR
- `shortMessage` (Optional) - Brief summary
- `classMethod` (Optional) - Context identifier
- `recordId` (Optional) - Associated record
- `correlationId` (Optional) - Link to existing correlation

### Flow Bookend Pattern

For correlated logging across a Flow, use the bookend pattern with three invocable actions:

**1. [`FLOW_LoggerStart`](reference/apex/FLOW_LoggerStart.md)** - Begin correlation

| Input | Description |
|-------|-------------|
| `flowName` (Required) | Name of the Flow |
| `flowVersion` (Optional) | Flow version number |
| `recordId` (Optional) | Associated record |

| Output | Description |
|--------|-------------|
| `correlationId` | Generated correlation ID |

**2. [`FLOW_LoggerLog`](reference/apex/FLOW_LoggerLog.md)** - Log messages

| Input | Description |
|-------|-------------|
| `correlationId` (Required) | From FLOW_LoggerStart |
| `message` (Required) | Log message |
| `logLevel` (Optional) | DEBUG, INFO, WARN, ERROR |
| `shortMessage` (Optional) | Brief summary |
| `recordId` (Optional) | Associated record |
| `stepName` (Optional) | Current Flow step |

**3. [`FLOW_LoggerEnd`](reference/apex/FLOW_LoggerEnd.md)** - End correlation

| Input | Description |
|-------|-------------|
| `correlationId` (Required) | From FLOW_LoggerStart |
| `status` (Optional) | SUCCESS, FAILURE, etc. |
| `message` (Optional) | Final message |

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

By default, logging is suppressed in unit tests to avoid side effects. Enable logging when testing logging behavior:

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

## Querying Log Entries

When filtering `LogEntry__c` records by user — in reports, dashboards, cleanup scripts, or audit
queries — **filter by `UserId__c`, NOT by `CreatedById`**.

### Why

The framework persists log entries asynchronously: `LOG_Builder.emit()` publishes a
`LogEntryEvent__e` Platform Event, and `TRG_PersistLogEntry` (a Platform Event subscriber trigger)
inserts the `LogEntry__c` row. Salesforce executes Platform Event triggers as the **Automated
Process** user (e.g. `autoproc@<orgid>`) regardless of who fired the event, so EVERY persisted
`LogEntry__c.CreatedById` is the Automated Process user.

The framework captures the emitting user's Id at publish time on `LogEntryEvent__e.UserId__c` and
`TRG_PersistLogEntry` propagates it to `LogEntry__c.UserId__c`. That field — not `CreatedById` —
is the correct join key for "which user emitted this log".

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

The same applies to declarative reports, dashboards, and list views. To filter by emitting user,
add a column or filter on **User ID** (`kern__UserId__c`), not Created By.

`UserId__c` is a Text(18) — not a Lookup — so `UserId__r.Name` traversal is NOT available. To
filter or display by user name, build a report type that joins `LogEntry__c.UserId__c` to the
`User` object via a Report Type Cross-Filter or a custom report formula. The companion field
`UserLink__c` is a formula that renders an "Open" hyperlink to the user record (so reports can
include a one-click jump from a log row to the User detail page); use it for navigation, and
`UserId__c` for filtering.

### Cleanup scripts

Cleanup queries should also filter by `UserId__c`. The platform allows `WHERE CreatedDate < ...`
clauses against the Automated Process user's records — the cleanup user just needs delete
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

`TRG_PersistLogEntry` runs `inherited sharing`, so the OWD model on `LogEntry__c` applies to the
Automated Process user's record-level access — not the emitting user's. If subscribers want
emitting users to see their own logs without granting "View All", a criteria-based sharing rule
keyed on `UserId__c` closes that visibility gap.

---

## Configuration Reference

### `LogSetting__c` Fields

Hierarchical custom setting (Org > Profile > User). Configure via Setup > Custom Settings > Log Setting.

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `IsEnabled__c` | Checkbox | true | Master kill switch. When false, all non-ERROR logs are dropped. |
| `LogLevelThreshold__c` | Text(10) | DEBUG | Minimum level to log (DEBUG, INFO, WARN, ERROR) |
| `ClassFilter__c` | Text(255) | blank | Comma-separated class name patterns with trailing `*` wildcard (e.g., `API_*,SVC_Payment*`). Blank = all classes. |
| `MaxContextDataSize__c` | Number | 32768 | Max characters for ContextData__c |
| `EnablePerformanceLogging__c` | Checkbox | true | Enable general performance logging |
| `PerformanceThresholdMs__c` | Number | 10000 | Threshold for general timers (ms) |
| `EnableQueryPerformanceLogging__c` | Checkbox | true | Enable query performance logging |
| `QueryPerformanceThresholdMs__c` | Number | 1000 | Threshold for query timers (ms) |
| `EnableTriggerPerformanceLogging__c` | Checkbox | true | Enable trigger performance logging |
| `TriggerPerformanceThresholdMs__c` | Number | 500 | Threshold for trigger timers (ms) |
| `EnableValidationPerformanceLogging__c` | Checkbox | true | Enable validation performance logging |
| `ValidationPerformanceThresholdMs__c` | Number | 100 | Threshold for validation timers (ms) |
| `EnableMaskerPerformanceLogging__c` | Checkbox | false | Enable masker performance logging (default OFF — opt-in) |
| `MaskerPerformanceThresholdMs__c` | Number | 100 | Threshold for masking on a trigger batch (ms) |

### `TriggerSetting__mdt` Fields (Trigger Performance)

| Field | Type | Description |
|-------|------|-------------|
| `EnablePerformanceLogging__c` | Checkbox | Override LogSetting__c for this object |
| `PerformanceThresholdMs__c` | Number | Threshold for this object's triggers |

### `TriggerAction__mdt` Fields (Action-Level Control)

| Field | Type | Description |
|-------|------|-------------|
| `ForcePerformanceLogging__c` | Checkbox | Always log this action |
| `SuppressPerformanceLogging__c` | Checkbox | Never log this action |
| `PerformanceThresholdMs__c` | Number | Custom threshold for this action |

**Configuration Hierarchy** (highest priority first):
1. TriggerAction__mdt (action-specific)
2. TriggerSetting__mdt (object-specific)
3. LogSetting__c (global)

---

## Anti-Patterns

| Anti-Pattern | Why It's Wrong | Instead |
|---|---|---|
| Using `System.debug()` | Output is ephemeral, not queryable, and lost after debug log rotation | Use `LOG_Builder.build().error(e).emitAt('Class.method')` |
| Logging without class.method context | Impossible to trace which code generated a log entry | Always provide context via `.emitAt('ClassName.methodName')` or `.at('ClassName.methodName')` |
| Logging PII or secrets (passwords, tokens, SSNs) | Violates compliance requirements and creates security vulnerabilities | The data masking framework (`MaskingRule__mdt` + `MaskingTarget__mdt`) is on by default and redacts configured patterns on every `LogEntryEvent__e`. Ship custom rules if your payload shape needs additional patterns |
| Missing correlation in async operations | Cannot trace a logical operation across transaction boundaries | Use `LOG_Builder.setCorrelationId(correlationId)` or `serializeContext()`/`hydrateContext()` to propagate correlation IDs across async boundaries |
| Forgetting to close log scopes | Buffered log entries may not be emitted, causing silent data loss | Always call `scope.close()` in a `finally` block |

---

## Best Practices

### 1. Always Include Context

```apex
// Good - includes class.method context and record correlation
LOG_Builder.build().error(e).at('OrderService.processOrder').forRecord(orderId).emit();

// Bad - no context
LOG_Builder.build().error(e.getMessage()).emit();
```

### 2. Use Appropriate Log Levels

| Level | When to Use |
|-------|-------------|
| DEBUG | Detailed tracing during development |
| INFO | Business events, milestones |
| WARN | Potential issues, recoverable errors |
| ERROR | Failures requiring attention |

### 3. Never Log Sensitive Data

```apex
// Bad - logs password
LOG_Builder.build().debug('Password: ' + password).emitAt('AuthService.login');

// Good - no sensitive data
LOG_Builder.build().debug('Login attempt for user: ' + username).emitAt('AuthService.login');
```

### 4. Use Correlation for Async Operations

```apex
// Always propagate context to async jobs
public void initiateProcess(Id recordId)
{
	LOG_Builder.startCorrelation();
	String context = LOG_Builder.serializeContext();
	System.enqueueJob(new ProcessQueueable(recordId, context));
}
```

### 5. Clean Up Context

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

### 6. Enable Performance Logging for Critical Operations

Enable performance logging via `LogSetting__c` to surface slow operations. The framework automatically times queries, trigger actions, and API calls — no code changes required. For custom timing in subscriber code, wrap the work in a `LOG_Builder.scope()` block:

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
5. **Check platform event limits**: Monitor [event publishing limits](https://developer.salesforce.com/docs/atlas.en-us.platform_events.meta/platform_events/platform_event_limits.htm)

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
- [Async Processing - Guide](Async%20Processing%20-%20Guide.md) - Async context propagation patterns
- [Web Services - Guide](Web%20Services%20-%20Guide.md) - Automatic API logging
- [Triggers - Guide](Triggers%20-%20Guide.md) - Trigger action logging
- [Fast Start - Logging](Fast%20Start%20-%20Logging.md) - Quick-start primer for logging

---

**Last Updated:** April 2026
**Guide Version:** 2.1
