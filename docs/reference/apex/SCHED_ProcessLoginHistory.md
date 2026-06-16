---
title: "SCHED_ProcessLoginHistory"
type: class
pageClass: reference
description: "Scheduled job that runs daily to process login history data. Launches PROC_LoginFrequencyAggregator via the adaptive async framework using Batch Apex. Batch is required because finish() updates Schedu"
author: "Jason Van Beukering"
group: "Schedulables"
date: "February 2026, May 2026"
since: "1.0"
category: apex
---

# SCHED_ProcessLoginHistory

**Class** · Group: `Schedulables`

```apex
global inherited sharing class SCHED_ProcessLoginHistory implements Schedulable
```

**Implements:** [Schedulable](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_interface_system_schedulable.htm)

Scheduled job that runs daily to process login history data. Launches PROC_LoginFrequencyAggregator via the adaptive async framework using Batch Apex. Batch is required because finish() updates ScheduleSetting__c (a setup object), which must run in a separate transaction from execute()'s LoginFrequency__c DML to avoid MIXED_DML_OPERATION.

**Since:** 1.0

**Example:**

```apex
System.schedule('Daily Login History', '0 0 2 * * ?', new SCHED_ProcessLoginHistory());
```

---

## Methods

| Method | Description |
|--------|-------------|
| global void [execute](#execute)([SchedulableContext](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_interface_system_schedulablecontext.htm) context) | Executes the scheduled Apex job to process login history data. |

---

## Method Details

### execute

<div class="apex-member">

```apex
global void execute(SchedulableContext context)
```

Executes the scheduled Apex job to process login history data. Reads the watermark
from ScheduleSetting__c, builds the LoginHistory query, and dispatches processing via the
adaptive async framework.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `context` | [SchedulableContext](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_interface_system_schedulablecontext.htm) | Contains the job id |

**Example**

```apex
System.schedule('Daily Login History Processing', '0 0 2 * * ?', new SCHED_ProcessLoginHistory());
```

</div>

