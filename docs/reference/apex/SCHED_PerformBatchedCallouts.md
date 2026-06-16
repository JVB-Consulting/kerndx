---
title: "SCHED_PerformBatchedCallouts"
type: class
pageClass: reference
description: "The SCHED_PerformBatchedCallouts class is a scheduled job responsible for processing batched API calls that are queued for outbound processing. This class retrieves a list of queued API calls, updates"
author: "Jason Van Beukering"
group: "Web Services"
date: "February 2026, June 2026"
since: "1.0"
category: apex
---

# SCHED_PerformBatchedCallouts

**Class** · Group: `Web Services`

```apex
global inherited sharing class SCHED_PerformBatchedCallouts implements Schedulable
```

**Implements:** [Schedulable](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_interface_system_schedulable.htm)

The SCHED_PerformBatchedCallouts class is a scheduled job responsible for processing batched API calls that are queued for outbound processing. This class retrieves a list of queued API calls, updates their status to indicate readiness for processing, and commits the updates to the database. This enables efficient handling and scheduling of multiple API requests.

**Since:** 1.0

**Example:**

```apex
System.schedule('Process Batched Callouts', '0 0 0 * * ?', new SCHED_PerformBatchedCallouts());
```

---

## Methods

| Method | Description |
|--------|-------------|
| global void [execute](#execute)([SchedulableContext](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_interface_system_schedulablecontext.htm) context) | Executes the scheduled job, retrieving a list of API calls that are batched and ready for outbound processing, updating their status to indicate they are queued, and committing the updated records to the database. |

---

## Method Details

### execute

<div class="apex-member">

```apex
global void execute(SchedulableContext context)
```

Executes the scheduled job, retrieving a list of API calls that are batched and ready for outbound
processing, updating their status to indicate they are queued, and committing the updated records to the database.
This method allows for controlled and consistent processing of API callouts on a scheduled basis.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `context` | [SchedulableContext](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_interface_system_schedulablecontext.htm) | relevant context |

**Example**

```apex
// Schedule the job to run every day at midnight to process batched API calls.
System.schedule('Process Batched API Calls', '0 0 0 * * ?', new SCHED_PerformBatchedCallouts());
```

</div>

