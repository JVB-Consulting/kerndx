---
title: "ScheduleSetting__c"
type: sobject
pageClass: reference
description: "Stores runtime state for scheduled jobs, such as the last successful execution time. Used by scheduled jobs for incremental processing."
category: objects
---

# ScheduleSetting__c

**Sobject**

```apex
global class ScheduleSetting__c extends SObject
```

**Extends:** [SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm)

Stores runtime state for scheduled jobs, such as the last successful execution time. Used by scheduled jobs for incremental processing.

---

## Fields

| Field | Description |
|-------|-------------|
| global [Datetime](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_datetime.htm) [LastSuccessfulRunTime__c](#lastsuccessfulruntime__c) | Holds the last successful run time of the schedule. |

---

## Field Details

### LastSuccessfulRunTime__c

```apex
global Datetime LastSuccessfulRunTime__c
```

Holds the last successful run time of the schedule. Used by scheduled jobs to track execution history and enable incremental processing based on changes since last run.

**Field Attributes:**

| Attribute | Value |
|-----------|-------|
| Data Type | Date Time |
| Required | false |

