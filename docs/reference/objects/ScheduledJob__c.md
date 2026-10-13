---
title: "ScheduledJob__c"
type: sobject
pageClass: reference
description: "Declarative scheduled job configuration. Each record defines a schedulable Apex class, cron expression, and activation status. The trigger framework automatically starts, stops, and monitors jobs base"
category: objects
---

# ScheduledJob__c

**Sobject**

<div class="apex-member apex-class">

```apex
global class ScheduledJob__c extends SObject
```

**Extends:** [SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm)

Declarative scheduled job configuration. Each record defines a schedulable Apex class, cron expression, and activation status. The trigger framework automatically starts, stops, and monitors jobs based on record changes.

</div>

---

## Fields

| Field | Description |
|-------|-------------|
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [ClassName__c](#classname__c) | The fully qualified name of the Apex class to schedule. |
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [CronExpression__c](#cronexpression__c) | Salesforce-format cron expression that defines when this job runs. |
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [Description__c](#description__c) | Free-text description of the scheduled job purpose and execution frequency. |
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [ExecutionMode__c](#executionmode__c) | Where this job runs. |
| global [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) [IsActive__c](#isactive__c) | Activates this scheduled job. |
| global [Datetime](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_datetime.htm) [LastRunAt__c](#lastrunat__c) | When this job's most recent run on the job runner finished. |
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [LastRunJobId__c](#lastrunjobid__c) | The platform job id of the most recent run this job was given on the job runner, written when the run is queued. |
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [LastRunOutcome__c](#lastrunoutcome__c) | What happened at the most recent event on a job that runs on the job runner: Succeeded or Failed from a run, Skipped when a due run was not started because the previous run was still running or the job was inactive when its run began, Parked when the job's class could not be found or its next run time could not be worked out. |
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [LastRunReason__c](#lastrunreason__c) | Why the last run was skipped or parked, written by the job runner. |
| global [Datetime](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_datetime.htm) [NextRunAt__c](#nextrunat__c) | The next time this job is due on the job runner: the first fire time of its expression, in its time zone, after the check that last started or skipped it. |
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [OverlapPolicy__c](#overlappolicy__c) | On the job runner: Skip marks a due run as Skipped while the previous run is still running; Allow starts it anyway. |
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [Parameters__c](#parameters__c) | JSON-serialized DTO_NameValues containing name/value pairs passed to the scheduled class at runtime. |
| global [Decimal](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_decimal.htm) [RunPriority__c](#runpriority__c) | Order among jobs due at the same check of the job runner: lower numbers start first, blank goes last. |
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [ScheduledJobId__c](#scheduledjobid__c) | The Salesforce CronTrigger Id for the scheduled job. |
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [SchedulerName__c](#schedulername__c) | User-friendly name for this scheduled job, used in the Job Name formula and displayed in Scheduled Jobs setup. |
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [Timezone__c](#timezone__c) | IANA TimeZoneSidKey (e.g., Africa/Johannesburg) of the user who authored the cron expression. |

### ClassName__c

```apex
global String ClassName__c
```

The fully qualified name of the Apex class to schedule. Supports outer and inner classes (e.g., Namespace.OuterClass.InnerClass).

**Field Attributes:**

| Attribute | Value |
|-----------|-------|
| Data Type | Text(100) |
| Required | true |
| Unique | false |
| External ID | false |

### CronExpression__c

```apex
global String CronExpression__c
```

Salesforce-format cron expression that defines when this job runs. Uses the 7-field Salesforce cron syntax: Seconds Minutes Hours Day_of_month Month Day_of_week Optional_year.

**Field Attributes:**

| Attribute | Value |
|-----------|-------|
| Data Type | Text(255) |
| Required | true |
| Unique | false |
| External ID | false |

### Description__c

```apex
global String Description__c
```

Free-text description of the scheduled job purpose and execution frequency. Helps administrators understand what the job does without reviewing the code.

**Field Attributes:**

| Attribute | Value |
|-----------|-------|
| Data Type | Text Area |
| Required | false |

### ExecutionMode__c

```apex
global String ExecutionMode__c
```

Where this job runs. Its own scheduled job (the default) gives the record one platform scheduled job of its own. Job runner puts the record on the shared runner, which checks it every few minutes and starts it when it is due, costing no scheduled-job slot of its own. Blank means its own scheduled job.

**Field Attributes:**

| Attribute | Value |
|-----------|-------|
| Data Type | Picklist |
| Required | false |

**Picklist Values:**

| API Name | Label | Active |
|----------|-------|--------|
| `OwnScheduledJob` | Its own scheduled job | Yes |
| `JobRunner` | Job runner | No |

### IsActive__c

```apex
global Boolean IsActive__c
```

Activates this scheduled job. The framework automatically schedules the job when checked. Automatically unchecked if the job fails or is terminated.

**Field Attributes:**

| Attribute | Value |
|-----------|-------|
| Data Type | Checkbox |
| Default Value | true |

### LastRunAt__c

```apex
global Datetime LastRunAt__c
```

When this job's most recent run on the job runner finished. Written by the framework.

**Field Attributes:**

| Attribute | Value |
|-----------|-------|
| Data Type | Date Time |
| Required | false |

### LastRunJobId__c

```apex
global String LastRunJobId__c
```

The platform job id of the most recent run this job was given on the job runner, written when the run is queued. The runner reads it to decide whether the previous run is still running.

**Field Attributes:**

| Attribute | Value |
|-----------|-------|
| Data Type | Text(18), case-insensitive |
| Required | false |
| Unique | false |
| External ID | false |

### LastRunOutcome__c

```apex
global String LastRunOutcome__c
```

What happened at the most recent event on a job that runs on the job runner: Succeeded or Failed from a run, Skipped when a due run was not started because the previous run was still running or the job was inactive when its run began, Parked when the job's class could not be found or its next run time could not be worked out. Written by the framework.

**Field Attributes:**

| Attribute | Value |
|-----------|-------|
| Data Type | Picklist |
| Required | false |

**Picklist Values:**

| API Name | Label | Active |
|----------|-------|--------|
| `Succeeded` | Succeeded | Yes |
| `Failed` | Failed | Yes |
| `Skipped` | Skipped | Yes |
| `Parked` | Parked | Yes |

### LastRunReason__c

```apex
global String LastRunReason__c
```

Why the last run was skipped or parked, written by the job runner. Blank when the last run succeeded or failed; a failure's detail is in the log entry for this record.

**Field Attributes:**

| Attribute | Value |
|-----------|-------|
| Data Type | Picklist |
| Required | false |

**Picklist Values:**

| API Name | Label | Active |
|----------|-------|--------|
| `PreviousRunStillRunning` | Previous run still running | Yes |
| `RecordNoLongerOnRunner` | Record no longer on the job runner | Yes |
| `ClassNotFound` | Class not found | Yes |
| `ExpressionCannotBePlaced` | Next run time could not be worked out | Yes |
| `ExpressionCannotFireWithinHorizon` | Expression never fires within four years | Yes |

### NextRunAt__c

```apex
global Datetime NextRunAt__c
```

The next time this job is due on the job runner: the first fire time of its expression, in its time zone, after the check that last started or skipped it. Written by the framework; edits to the expression, time zone, mode or active flag reset it.

**Field Attributes:**

| Attribute | Value |
|-----------|-------|
| Data Type | Date Time |
| Required | false |

### OverlapPolicy__c

```apex
global String OverlapPolicy__c
```

On the job runner: Skip marks a due run as Skipped while the previous run is still running; Allow starts it anyway. A skipped run is not made up later.

**Field Attributes:**

| Attribute | Value |
|-----------|-------|
| Data Type | Picklist |
| Required | false |

**Picklist Values:**

| API Name | Label | Active |
|----------|-------|--------|
| `Skip` | Skip this run while the previous one is still running | Yes |
| `Allow` | Allow runs to overlap | No |

### Parameters__c

```apex
global String Parameters__c
```

JSON-serialized DTO_NameValues containing name/value pairs passed to the scheduled class at runtime. The scheduled class must implement IF_Schedulable to receive these parameters.

**Field Attributes:**

| Attribute | Value |
|-----------|-------|
| Data Type | Long Text Area(131072) |

### RunPriority__c

```apex
global Decimal RunPriority__c
```

Order among jobs due at the same check of the job runner: lower numbers start first, blank goes last. A preference, not a guarantee; when a check has more due jobs than it may start, a low priority can wait.

**Field Attributes:**

| Attribute | Value |
|-----------|-------|
| Data Type | Number(5,0) |
| Required | false |
| Unique | false |
| External ID | false |

### ScheduledJobId__c

```apex
global String ScheduledJobId__c
```

The Salesforce CronTrigger Id for the scheduled job. System-populated when the job is scheduled.

**Field Attributes:**

| Attribute | Value |
|-----------|-------|
| Data Type | Text(18), case-insensitive |
| Required | false |
| Unique | true |
| External ID | false |

### SchedulerName__c

```apex
global String SchedulerName__c
```

User-friendly name for this scheduled job, used in the Job Name formula and displayed in Scheduled Jobs setup.

**Field Attributes:**

| Attribute | Value |
|-----------|-------|
| Data Type | Text(40) |
| Required | true |
| Unique | false |
| External ID | false |

### Timezone__c

```apex
global String Timezone__c
```

IANA TimeZoneSidKey (e.g., Africa/Johannesburg) of the user who authored the cron expression.

**Field Attributes:**

| Attribute | Value |
|-----------|-------|
| Data Type | Text(100) |
| Required | false |
| Unique | false |
| External ID | false |

