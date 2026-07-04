---
title: "ScheduledJob__c"
type: sobject
description: "Declarative scheduled job configuration. Each record defines a schedulable Apex class, cron expression, and activation status. The trigger framework automatically starts, stops, and monitors jobs base"
category: objects
---

# ScheduledJob__c

**Sobject**

```apex
global class ScheduledJob__c extends SObject
```

**Extends:** [SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm)

Declarative scheduled job configuration. Each record defines a schedulable Apex class, cron expression, and activation status. The trigger framework automatically starts, stops, and monitors jobs based on record changes.

---

## Fields

| Field | Description |
|-------|-------------|
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [ClassName__c](#classname__c) | The fully qualified name of the Apex class to schedule. |
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [CronExpression__c](#cronexpression__c) | Salesforce-format cron expression that defines when this job runs. |
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [Description__c](#description__c) | Free-text description of the scheduled job purpose and execution frequency. |
| global [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) [IsActive__c](#isactive__c) | Activates this scheduled job. |
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [Parameters__c](#parameters__c) | JSON-serialized DTO_NameValues containing name/value pairs passed to the scheduled class at runtime. |
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [ScheduledJobId__c](#scheduledjobid__c) | The Salesforce CronTrigger Id for the scheduled job. |
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [SchedulerName__c](#schedulername__c) | User-friendly name for this scheduled job, used in the Job Name formula and displayed in Scheduled Jobs setup. |
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [Timezone__c](#timezone__c) | IANA TimeZoneSidKey (e.g., Africa/Johannesburg) of the user who authored the cron expression. |

---

## Field Details

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

### Parameters__c

```apex
global String Parameters__c
```

JSON-serialized DTO_NameValues containing name/value pairs passed to the scheduled class at runtime. The scheduled class must implement IF_Schedulable to receive these parameters.

**Field Attributes:**

| Attribute | Value |
|-----------|-------|
| Data Type | Long Text Area(131072) |

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

