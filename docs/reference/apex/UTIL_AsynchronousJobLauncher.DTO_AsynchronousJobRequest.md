---
title: "UTIL_AsynchronousJobLauncher.DTO_AsynchronousJobRequest"
type: class
description: "Request object for initiating an asynchronous process."
since: "1.0"
category: apex
---

# UTIL_AsynchronousJobLauncher.DTO_AsynchronousJobRequest

**Class**

```apex
global inherited sharing class UTIL_AsynchronousJobLauncher.DTO_AsynchronousJobRequest
```

Request object for initiating an asynchronous process.

**Since:** 1.0

---

## Properties

| Property | Description |
|----------|-------------|
| global [AsyncOptions](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_System_AsyncOptions.htm) [asyncOptions](#asyncoptions) | AsyncOptions for configuring queueable behavior, especially useful for tests. |
| global [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) [batchJobSize](#batchjobsize) | The number of records to process in each Batch Apex transaction. |
| global [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) [delayMinutes](#delayminutes) | The delay in minutes before processing starts. |
| global [IF_Async.AsynchronousExecutionStrategy](IF_Async.AsynchronousExecutionStrategy.md) [executionStrategy](#executionstrategy) | The execution strategy for queueable processing. |
| global [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[Object](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_System_Object.htm)> [itemsToProcess](#itemstoprocess) | The list of objects to process. |
| global [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) [limitAtWhichToBatch](#limitatwhichtobatch) | The record count threshold at which the framework switches from Queueable to Batch Apex. |
| global [IF_Queryable](IF_Queryable.md) [queryable](#queryable) | The queryable used for query-based jobs. |
| global [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) [queueableJobSize](#queueablejobsize) | The number of records to process in each Queueable job transaction. |

## Methods

| Method | Description |
|--------|-------------|
| global  [DTO_AsynchronousJobRequest](#dto_asynchronousjobrequest)([IF_Queryable](IF_Queryable.md) queryable) | Constructor for processing records retrieved from an IF_Queryable. |
| global  [DTO_AsynchronousJobRequest](#dto_asynchronousjobrequest)([List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[Object](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_System_Object.htm)> items) | Constructor for processing a predefined list of objects. |
| global [UTIL_AsynchronousJobLauncher.DTO_AsynchronousJobRequest](UTIL_AsynchronousJobLauncher.DTO_AsynchronousJobRequest.md) [withAsyncOptions](#withasyncoptions)([AsyncOptions](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_System_AsyncOptions.htm) options) | Sets the maximum stack depth for chaining |
| global [UTIL_AsynchronousJobLauncher.DTO_AsynchronousJobRequest](UTIL_AsynchronousJobLauncher.DTO_AsynchronousJobRequest.md) [withBatchSize](#withbatchsize)([Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) size) | Sets the batch job size for Batch Apex execution. |
| global [UTIL_AsynchronousJobLauncher.DTO_AsynchronousJobRequest](UTIL_AsynchronousJobLauncher.DTO_AsynchronousJobRequest.md) [withDelayMinutes](#withdelayminutes)([Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) minutes) | Sets the delay in minutes before processing starts. |
| global [UTIL_AsynchronousJobLauncher.DTO_AsynchronousJobRequest](UTIL_AsynchronousJobLauncher.DTO_AsynchronousJobRequest.md) [withExecutionStrategy](#withexecutionstrategy)([IF_Async.AsynchronousExecutionStrategy](IF_Async.AsynchronousExecutionStrategy.md) strategy) | Sets the execution strategy for determine what job type to use |
| global [UTIL_AsynchronousJobLauncher.DTO_AsynchronousJobRequest](UTIL_AsynchronousJobLauncher.DTO_AsynchronousJobRequest.md) [withLimitAtWhichToBatch](#withlimitatwhichtobatch)([Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) threshold) | Sets the threshold at which processing switches from Queueable to Batch Apex. |
| global [UTIL_AsynchronousJobLauncher.DTO_AsynchronousJobRequest](UTIL_AsynchronousJobLauncher.DTO_AsynchronousJobRequest.md) [withQueueableJobSize](#withqueueablejobsize)([Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) size) | Sets the chunk size for Queueable execution. |

---

## Property Details

### asyncOptions

```apex
global AsyncOptions asyncOptions
```

**Type:** [AsyncOptions](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_System_AsyncOptions.htm)

AsyncOptions for configuring queueable behavior, especially useful for tests.
When set, this will be passed to System.enqueueJob calls.

Since:


Example:

### batchJobSize

```apex
global Integer batchJobSize
```

**Type:** [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm)

The number of records to process in each Batch Apex transaction.

Since:


Example:

### delayMinutes

```apex
global Integer delayMinutes
```

**Type:** [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm)

The delay in minutes before processing starts.
For delays greater than 10 minutes, the framework automatically chains queueables until the delay expires.

Since:


Example:

### executionStrategy

```apex
global IF_Async.AsynchronousExecutionStrategy executionStrategy
```

**Type:** [IF_Async.AsynchronousExecutionStrategy](IF_Async.AsynchronousExecutionStrategy.md)

The execution strategy for queueable processing.
Default: AUTO (framework decides based on context and limits).

Since:


Example:

### itemsToProcess

```apex
global List<Object> itemsToProcess
```

**Type:** [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)

The list of objects to process. Null for query-based jobs.

Since:


Example:

### limitAtWhichToBatch

```apex
global Integer limitAtWhichToBatch
```

**Type:** [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm)

The record count threshold at which the framework switches from Queueable to Batch Apex.

Since:


Example:

### queryable

```apex
global IF_Queryable queryable
```

**Type:** [IF_Queryable](IF_Queryable.md)

The queryable used for query-based jobs. Null for list-based jobs.

Since:


Example:

### queueableJobSize

```apex
global Integer queueableJobSize
```

**Type:** [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm)

The number of records to process in each Queueable job transaction.

Since:


Example:

---

## Method Details

### DTO_AsynchronousJobRequest

```apex
global DTO_AsynchronousJobRequest(IF_Queryable queryable)
```

Constructor for processing records retrieved from an IF_Queryable.
Supports QRY_Builder.Builder and SEL_Base instances directly.

**Parameters:**

- `queryable` ([IF_Queryable](IF_Queryable.md)) - The IF_Queryable defining the records to process.

**Since:** 1.0

**Example:**

```apex
IF_Queryable query = QRY_Builder.selectFrom(Account.SObjectType)
    .fields(new List<String>{'Id', 'Name'})
    .condition(Account.Industry).equals('Technology');
DTO_AsynchronousJobRequest request = new DTO_AsynchronousJobRequest(query)
    .withBatchSize(100);
Id jobId = UTIL_AsynchronousJobLauncher.process(request, new MyProcessor());
```

```apex
global DTO_AsynchronousJobRequest(List<Object> items)
```

Constructor for processing a predefined list of objects.

**Parameters:**

- `items` ([List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)) - The list of objects to process.

**Since:** 1.0

**Example:**

```apex
UTIL_AsynchronousJobLauncher.DTO_AsynchronousJobRequest instance = new UTIL_AsynchronousJobLauncher.DTO_AsynchronousJobRequest(new List<Object>{'a', 'b'});
```

### withAsyncOptions

```apex
global UTIL_AsynchronousJobLauncher.DTO_AsynchronousJobRequest withAsyncOptions(AsyncOptions options)
```

Sets the maximum stack depth for chaining

**Parameters:**

- `options` ([AsyncOptions](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_System_AsyncOptions.htm)) - The asynchronous options to use

**Returns:** [UTIL_AsynchronousJobLauncher.DTO_AsynchronousJobRequest](UTIL_AsynchronousJobLauncher.DTO_AsynchronousJobRequest.md) - The AsynchronousJobRequest instance for method chaining.

**Since:** 1.0

**Example:**

```apex
DTO_AsynchronousJobRequest result = instance.withAsyncOptions(new AsyncOptions());
```

### withBatchSize

```apex
global UTIL_AsynchronousJobLauncher.DTO_AsynchronousJobRequest withBatchSize(Integer size)
```

Sets the batch job size for Batch Apex execution.

**Parameters:**

- `size` ([Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm)) - The number of items per batch execution.

**Returns:** [UTIL_AsynchronousJobLauncher.DTO_AsynchronousJobRequest](UTIL_AsynchronousJobLauncher.DTO_AsynchronousJobRequest.md) - The AsynchronousJobRequest instance for method chaining.

**Since:** 1.0

**Example:**

```apex
DTO_AsynchronousJobRequest result = instance.withBatchSize(10);
```

### withDelayMinutes

```apex
global UTIL_AsynchronousJobLauncher.DTO_AsynchronousJobRequest withDelayMinutes(Integer minutes)
```

Sets the delay in minutes before processing starts.
For delays greater than 10 minutes, the framework automatically chains queueables
until the delay expires, making this suitable for any duration.

**Parameters:**

- `minutes` ([Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm)) - The delay in minutes before processing begins (0 or greater).

**Returns:** [UTIL_AsynchronousJobLauncher.DTO_AsynchronousJobRequest](UTIL_AsynchronousJobLauncher.DTO_AsynchronousJobRequest.md) - The AsynchronousJobRequest instance for method chaining.

**Throws:**

- [IllegalArgumentException](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_classes_exception_methods.htm) - if minutes is less than 0.

**Since:** 1.0

**Example:**

```apex
// Process immediately (default)
DTO_AsynchronousJobRequest request = new DTO_AsynchronousJobRequest(items);
// Process after 5 minutes
DTO_AsynchronousJobRequest request = new DTO_AsynchronousJobRequest(items)
    .withDelayMinutes(5);
// Process after 45 minutes (automatically chains for delays > 10 min)
DTO_AsynchronousJobRequest request = new DTO_AsynchronousJobRequest(items)
    .withDelayMinutes(45);
Id jobId = UTIL_AsynchronousJobLauncher.process(request, new MyProcessor());
```

### withExecutionStrategy

```apex
global UTIL_AsynchronousJobLauncher.DTO_AsynchronousJobRequest withExecutionStrategy(IF_Async.AsynchronousExecutionStrategy strategy)
```

Sets the execution strategy for determine what job type to use

**Parameters:**

- `strategy` ([IF_Async.AsynchronousExecutionStrategy](IF_Async.AsynchronousExecutionStrategy.md)) - The execution strategy to employ

**Returns:** [UTIL_AsynchronousJobLauncher.DTO_AsynchronousJobRequest](UTIL_AsynchronousJobLauncher.DTO_AsynchronousJobRequest.md) - The AsynchronousJobRequest instance for method chaining.

**Since:** 1.0

**Example:**

```apex
DTO_AsynchronousJobRequest result = instance.withExecutionStrategy(new IF_Async.AsynchronousExecutionStrategy());
```

### withLimitAtWhichToBatch

```apex
global UTIL_AsynchronousJobLauncher.DTO_AsynchronousJobRequest withLimitAtWhichToBatch(Integer threshold)
```

Sets the threshold at which processing switches from Queueable to Batch Apex.

**Parameters:**

- `threshold` ([Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm)) - The number of items that will trigger Batch Apex execution.

**Returns:** [UTIL_AsynchronousJobLauncher.DTO_AsynchronousJobRequest](UTIL_AsynchronousJobLauncher.DTO_AsynchronousJobRequest.md) - The AsynchronousJobRequest instance for method chaining.

**Since:** 1.0

**Example:**

```apex
DTO_AsynchronousJobRequest result = instance.withLimitAtWhichToBatch(10);
```

### withQueueableJobSize

```apex
global UTIL_AsynchronousJobLauncher.DTO_AsynchronousJobRequest withQueueableJobSize(Integer size)
```

Sets the chunk size for Queueable execution.

**Parameters:**

- `size` ([Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm)) - The number of items per Queueable execution.

**Returns:** [UTIL_AsynchronousJobLauncher.DTO_AsynchronousJobRequest](UTIL_AsynchronousJobLauncher.DTO_AsynchronousJobRequest.md) - The AsynchronousJobRequest instance for method chaining.

**Since:** 1.0

**Example:**

```apex
DTO_AsynchronousJobRequest result = instance.withQueueableJobSize(10);
```

