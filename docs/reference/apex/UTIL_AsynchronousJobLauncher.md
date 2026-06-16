---
title: "UTIL_AsynchronousJobLauncher"
type: class
pageClass: reference
description: "Provides a simplified, static entry point for running complex asynchronous jobs using the UTIL_AdaptiveAsynchronousProcessor engine."
author: "Jason Van Beukering"
group: "Async Processing"
date: "September 2025, May 2026"
since: "1.0"
category: apex
---

# UTIL_AsynchronousJobLauncher

**Class** · Group: `Async Processing`

<div class="apex-member apex-class">

```apex
global inherited sharing class UTIL_AsynchronousJobLauncher
```

Provides a simplified, static entry point for running complex asynchronous jobs using the UTIL_AdaptiveAsynchronousProcessor engine.

**Example**

```apex
List<Object> items = new List<Object>{ 'item1', 'item2', 'item3' };
IF_Async.Processable processor = new MyCustomProcessor();
Id jobId = UTIL_AsynchronousJobLauncher.process(items, processor, 50);
```

**See Also:** [IF_Async](IF_Async.md)

</div>

---

## Methods

| Method | Description |
|--------|-------------|
| global static [Id](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_id.htm) [process](#process)([List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[Object](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_System_Object.htm)> items, [IF_Async.Processable](IF_Async.Processable.md) processor) | Starts an adaptive asynchronous job with automatic execution strategy selection. |
| global static [Id](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_id.htm) [process](#process)([List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[Object](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_System_Object.htm)> items, [IF_Async.Processable](IF_Async.Processable.md) processor, [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) jobSize) | Starts an adaptive asynchronous job with a custom job size for batch or queueable processing. |
| global static [Id](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_id.htm) [process](#process)([UTIL_AsynchronousJobLauncher.DTO_AsynchronousJobRequest](UTIL_AsynchronousJobLauncher.DTO_AsynchronousJobRequest.md) request, [IF_Async.Processable](IF_Async.Processable.md) processor) | Starts an adaptive asynchronous job with full configuration control via a request object. |

## Inner Classes

| Class | Description |
|-------|-------------|
| [DTO_AsynchronousJobRequest](UTIL_AsynchronousJobLauncher.DTO_AsynchronousJobRequest.md) | Request object for initiating an asynchronous process. |

---

## Method Details

### process

<div class="apex-member">

```apex
global static Id process(List<Object> items, IF_Async.Processable processor)
```

Starts an adaptive asynchronous job with automatic execution strategy selection.
The framework automatically chooses between Queueable and Batch Apex based on the number of items
and available governor limits, optimizing for performance.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `items` | [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm) | The Items to process |
| `processor` | [Object](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_System_Object.htm) | An instance of a class that implements Processable. |

**Returns** [Id](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_id.htm) — The ID of the started asynchronous job.

**Example**

```apex
// Process a list of accounts using a custom processor
List<Account> accounts = [SELECT Id, Name FROM Account LIMIT 100];
IF_Async.Processable processor = new MyAccountProcessor();
Id jobId = UTIL_AsynchronousJobLauncher.process(accounts, processor);
System.debug('Job started with ID: ' + jobId);
```

</div>

<div class="apex-member">

```apex
global static Id process(List<Object> items, IF_Async.Processable processor, Integer jobSize)
```

Starts an adaptive asynchronous job with a custom job size for batch or queueable processing.
The job size controls how many records are processed in each batch execution or queueable transaction.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `items` | [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm) | The Items to process |
| `processor` | [Object](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_System_Object.htm) | An instance of a class that implements Processable. |
| `jobSize` | [IF_Async.Processable](IF_Async.Processable.md) | The size of each job to be executed |

**Returns** [Id](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_id.htm) — The ID of the started asynchronous job.

**Example**

```apex
// Process contacts with a custom batch size of 50
List<Contact> contacts = [SELECT Id, Email FROM Contact WHERE Email != null LIMIT 500];
IF_Async.Processable processor = new EmailValidationProcessor();
Id jobId = UTIL_AsynchronousJobLauncher.process(contacts, processor, 50);
System.debug('Processing 500 contacts in batches of 50. Job ID: ' + jobId);
```

</div>

<div class="apex-member">

```apex
global static Id process(UTIL_AsynchronousJobLauncher.DTO_AsynchronousJobRequest request, IF_Async.Processable processor)
```

Starts an adaptive asynchronous job with full configuration control via a request object.
This method provides maximum flexibility, allowing you to configure batch size, queueable job size,
execution strategy, and other advanced settings through the DTO_AsynchronousJobRequest object.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `request` | [UTIL_AsynchronousJobLauncher.DTO_AsynchronousJobRequest](UTIL_AsynchronousJobLauncher.DTO_AsynchronousJobRequest.md) | The AsynchronousJobRequest containing the data and configuration. |
| `processor` | [IF_Async.Processable](IF_Async.Processable.md) | An instance of a class that implements Processable. |

**Returns** [Id](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_id.htm) — The ID of the started asynchronous job.

**Example**

```apex
// Process opportunities with advanced configuration
List<Opportunity> opportunities = [SELECT Id, Amount FROM Opportunity WHERE StageName = 'Closed Won' LIMIT 1000];
DTO_AsynchronousJobRequest request = new DTO_AsynchronousJobRequest(opportunities)
    .withBatchSize(100)
    .withQueueableJobSize(50)
    .withExecutionStrategy(IF_Async.AsynchronousExecutionStrategy.BATCH);
IF_Async.Processable processor = new OpportunityProcessor();
Id jobId = UTIL_AsynchronousJobLauncher.process(request, processor);
System.debug('Advanced processing started with Job ID: ' + jobId);
```

</div>

