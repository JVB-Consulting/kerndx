---
title: "LogSetting__c"
type: sobject
pageClass: reference
description: "Controls logging behaviour: log level threshold, class filtering, performance logging thresholds, and context data size limits. Hierarchy: Org > Profile > User."
category: objects
---

# LogSetting__c

**Sobject**

<div class="apex-member apex-class">

```apex
global class LogSetting__c extends SObject
```

**Extends:** [SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm)

Controls logging behaviour: log level threshold, class filtering, performance logging thresholds, and context data size limits. Hierarchy: Org > Profile > User.

</div>

---

## Fields

| Field | Description |
|-------|-------------|
| global [Decimal](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_decimal.htm) [AsyncChainPerformanceThresholdMs__c](#asyncchainperformancethresholdms__c) | Minimum duration in milliseconds before a whole async chain run is logged as a performance entry. |
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [ClassFilter__c](#classfilter__c) | Comma-separated class name patterns. |
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [EnableFlowActionLogging__c](#enableflowactionlogging__c) | Controls how often flow trigger actions write audit log entries. |
| global [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) [EnableMaskerPerformanceLogging__c](#enablemaskerperformancelogging__c) | When enabled, logs performance metrics for data masking on a trigger batch that exceeds MaskerPerformanceThresholdMs. |
| global [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) [EnablePerformanceLogging__c](#enableperformancelogging__c) | When on, logs a performance entry for web service and API operations, and for each async chain step, that take Performance Threshold (ms) or longer. |
| global [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) [EnableQueryPerformanceLogging__c](#enablequeryperformancelogging__c) | When enabled, logs performance metrics for SOQL queries that exceed QueryPerformanceThresholdMs. |
| global [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) [EnableTriggerPerformanceLogging__c](#enabletriggerperformancelogging__c) | When enabled, a trigger action or post-trigger action that takes Trigger Performance Threshold (ms) or longer is logged. |
| global [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) [EnableValidationPerformanceLogging__c](#enablevalidationperformancelogging__c) | When enabled, logs performance metrics for validation rule processing that exceeds ValidationPerformanceThresholdMs. |
| global [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) [IsEnabled__c](#isenabled__c) | Master kill switch for logging. |
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [LogLevelThreshold__c](#loglevelthreshold__c) | Minimum log level to capture for application logs. |
| global [Decimal](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_decimal.htm) [MaskerPerformanceThresholdMs__c](#maskerperformancethresholdms__c) | Minimum masking duration in milliseconds before a trigger batch is logged as a performance entry. |
| global [Decimal](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_decimal.htm) [MaxContextDataSize__c](#maxcontextdatasize__c) | Maximum character length for serialized context data attached to log entries. |
| global [Decimal](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_decimal.htm) [PerformanceThresholdMs__c](#performancethresholdms__c) | Minimum duration in milliseconds before a web service or API operation, or an async chain step, is logged as a performance entry. |
| global [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) [ProblemGroupingDisabled__c](#problemgroupingdisabled__c) | Check this box to stop the Log Console grouping repeated errors on its own. |
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [ProblemGroupingLogLevels__c](#problemgroupingloglevels__c) | Which log levels the Log Console may group on its own: ERROR, WARN, INFO or DEBUG. |
| global [Decimal](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_decimal.htm) [ProblemGroupingMinimumOccurrences__c](#problemgroupingminimumoccurrences__c) | How many times the same error must appear inside the date range you are viewing before the Log Console groups it into Problem summary. |
| global [Decimal](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_decimal.htm) [QueryPerformanceThresholdMs__c](#queryperformancethresholdms__c) | Minimum duration in milliseconds before a SOQL query is logged as a performance entry. |
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [SuppressClassMethod__c](#suppressclassmethod__c) | Comma-separated class name patterns to suppress (denylist). |
| global [Decimal](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_decimal.htm) [TriggerPerformanceThresholdMs__c](#triggerperformancethresholdms__c) | Minimum duration in milliseconds before a trigger action handler is logged as a performance entry. |
| global [Decimal](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_decimal.htm) [ValidationPerformanceThresholdMs__c](#validationperformancethresholdms__c) | Minimum duration in milliseconds before a validation rule processing cycle is logged as a performance entry. |

### AsyncChainPerformanceThresholdMs__c

```apex
global Decimal AsyncChainPerformanceThresholdMs__c
```

Minimum duration in milliseconds before a whole async chain run is logged as a performance entry. Leave this field blank to use Enable Performance Logging and Performance Threshold (ms) instead. When you set a number, a run that took that long or longer is logged, even with Enable Performance Logging turned off. The time runs from the start of the run to its end, waits in the queue included. Only four endings get this entry: a run that finishes all its steps, a run that stops because a step failed and is not retried, a run that fails because the data its steps share grew past its limit, and a run stopped because the AsyncChain feature flag is off. No other run gets it, for example a chain started with no steps, a run an operator aborts, a stalled run, or a run whose background job crashes. Set 0 to log every such run, or a very high number to log none. A negative number works like 0. The entry is a DEBUG log entry: it is saved only when logging is on and the log level allows DEBUG.

**Field Attributes:**

| Attribute | Value |
|-----------|-------|
| Data Type | Number(18,0) |
| Required | false |
| Unique | false |
| External ID | false |

### ClassFilter__c

```apex
global String ClassFilter__c
```

Comma-separated class name patterns. Only log entries from matching classes pass. Supports trailing wildcard (*). Blank means all classes pass.

**Field Attributes:**

| Attribute | Value |
|-----------|-------|
| Data Type | Text(255) |
| Required | false |
| Unique | false |
| External ID | false |

### EnableFlowActionLogging__c

```apex
global String EnableFlowActionLogging__c
```

Controls how often flow trigger actions write audit log entries. Valid values: Off, ErrorsOnly, AlwaysOn. Off disables audit logging entirely. ErrorsOnly (default) records one log entry per failed flow run, with the failed record identified. AlwaysOn records one summary entry per successful batch plus one entry per failed record — use this only in orgs that need compliance-grade evidence of every flow trigger run, since heavy bulk saves multiply the log volume. Defaults to ErrorsOnly.

**Field Attributes:**

| Attribute | Value |
|-----------|-------|
| Data Type | Text(40) |
| Required | false |
| Unique | false |
| External ID | false |
| Default Value | "ErrorsOnly" |

### EnableMaskerPerformanceLogging__c

```apex
global Boolean EnableMaskerPerformanceLogging__c
```

When enabled, logs performance metrics for data masking on a trigger batch that exceeds MaskerPerformanceThresholdMs. One aggregate log entry per batch, not per record. Default off — turn on during investigation of slow commits to attribute the time to masking.

**Field Attributes:**

| Attribute | Value |
|-----------|-------|
| Data Type | Checkbox |
| Default Value | false |

### EnablePerformanceLogging__c

```apex
global Boolean EnablePerformanceLogging__c
```

When on, logs a performance entry for web service and API operations, and for each async chain step, that take Performance Threshold (ms) or longer. It also controls the entry for a whole async chain run when Async Chain Performance Threshold (ms) is blank. When that field holds a number, the whole-run entry follows that number only, even with this setting off.

**Field Attributes:**

| Attribute | Value |
|-----------|-------|
| Data Type | Checkbox |
| Default Value | true |

### EnableQueryPerformanceLogging__c

```apex
global Boolean EnableQueryPerformanceLogging__c
```

When enabled, logs performance metrics for SOQL queries that exceed QueryPerformanceThresholdMs.

**Field Attributes:**

| Attribute | Value |
|-----------|-------|
| Data Type | Checkbox |
| Default Value | true |

### EnableTriggerPerformanceLogging__c

```apex
global Boolean EnableTriggerPerformanceLogging__c
```

When enabled, a trigger action or post-trigger action that takes Trigger Performance Threshold (ms) or longer is logged. This applies only to actions that have no threshold of their own and whose trigger setting has no threshold. A threshold set on an action or on a trigger setting logs even when this is off, and Force Performance Logging always logs. To stop every slow-action entry, turn logging off (Is Enabled) or set Log Level Threshold above DEBUG.

**Field Attributes:**

| Attribute | Value |
|-----------|-------|
| Data Type | Checkbox |
| Default Value | true |

### EnableValidationPerformanceLogging__c

```apex
global Boolean EnableValidationPerformanceLogging__c
```

When enabled, logs performance metrics for validation rule processing that exceeds ValidationPerformanceThresholdMs.

**Field Attributes:**

| Attribute | Value |
|-----------|-------|
| Data Type | Checkbox |
| Default Value | true |

### IsEnabled__c

```apex
global Boolean IsEnabled__c
```

Master kill switch for logging. When false, all log entries except ERROR are dropped.

**Field Attributes:**

| Attribute | Value |
|-----------|-------|
| Data Type | Checkbox |
| Default Value | true |

### LogLevelThreshold__c

```apex
global String LogLevelThreshold__c
```

Minimum log level to capture for application logs. Valid values: DEBUG, INFO, WARN, ERROR. Entries below this threshold are silently dropped. DEBUG captures all; ERROR captures only errors. Bypass audit entries ignore this threshold: they are kept while Is Enabled is checked and the BypassAudit_Enabled feature flag is on.

**Field Attributes:**

| Attribute | Value |
|-----------|-------|
| Data Type | Text(10) |
| Required | false |
| Unique | false |
| External ID | false |
| Default Value | "DEBUG" |

### MaskerPerformanceThresholdMs__c

```apex
global Decimal MaskerPerformanceThresholdMs__c
```

Minimum masking duration in milliseconds before a trigger batch is logged as a performance entry. Applies when Enable Masker Performance Logging is on. Default 100ms.

**Field Attributes:**

| Attribute | Value |
|-----------|-------|
| Data Type | Number(18,0) |
| Required | false |
| Unique | false |
| External ID | false |
| Default Value | 100 |

### MaxContextDataSize__c

```apex
global Decimal MaxContextDataSize__c
```

Maximum character length for serialized context data attached to log entries. Context data exceeding this limit is truncated.

**Field Attributes:**

| Attribute | Value |
|-----------|-------|
| Data Type | Number(18,0) |
| Required | false |
| Unique | false |
| External ID | false |
| Default Value | 32768 |

### PerformanceThresholdMs__c

```apex
global Decimal PerformanceThresholdMs__c
```

Minimum duration in milliseconds before a web service or API operation, or an async chain step, is logged as a performance entry. It also applies to a whole async chain run when Async Chain Performance Threshold (ms) is blank. Used only when Enable Performance Logging is on. When this field is blank, none of these entries is logged.

**Field Attributes:**

| Attribute | Value |
|-----------|-------|
| Data Type | Number(18,0) |
| Required | false |
| Unique | false |
| External ID | false |
| Default Value | 10000 |

### ProblemGroupingDisabled__c

```apex
global Boolean ProblemGroupingDisabled__c
```

Check this box to stop the Log Console grouping repeated errors on its own. In its Problem summary view, errors that were logged without a fingerprint are gathered into one row with a count — same error, same class and method, same level — and the grouping is worked out at the moment you open the list. Check the box and Problem summary shows only the problems your developers tagged with a fingerprint in code; the list does not go empty. This setting changes what the Log Console displays, never what is logged: every entry is still written, still listed under Individual entries, and nothing is deleted. Leave it unchecked (the default) to keep the grouping on — it stays on through package upgrades until you check this box.

**Field Attributes:**

| Attribute | Value |
|-----------|-------|
| Data Type | Checkbox |
| Default Value | false |

### ProblemGroupingLogLevels__c

```apex
global String ProblemGroupingLogLevels__c
```

Which log levels the Log Console may group on its own: ERROR, WARN, INFO or DEBUG. Separate several with a semicolon or a comma. This does not change which levels are captured — that is Log Level Threshold — only which of the captured entries the console may gather into problems. It is a cost ceiling as much as a filter: the grouping is a live query run each time someone opens Problem summary, and most orgs record far more INFO and DEBUG than errors, so adding those levels makes the query much larger and, past a point, the console stops grouping altogether and says so on screen. The console's own level filter narrows within this list and can never widen it, so viewing a level that is not listed here shows tagged problems only. Leave blank for the default, ERROR;WARN — a value holding no level the framework recognises falls back to the same default.

**Field Attributes:**

| Attribute | Value |
|-----------|-------|
| Data Type | Text(255) |
| Required | false |
| Unique | false |
| External ID | false |
| Default Value | "ERROR;WARN" |

### ProblemGroupingMinimumOccurrences__c

```apex
global Decimal ProblemGroupingMinimumOccurrences__c
```

How many times the same error must appear inside the date range you are viewing before the Log Console groups it into Problem summary. The default of 2 keeps one-off errors out of the list. Raise it when the list is still too long to scan; set it to 1 to see every error, including one that has happened only once so far. Nothing is hidden by this number — an error below it simply stays in Individual entries. Leave blank, or set it below 1, to use the default of 2.

**Field Attributes:**

| Attribute | Value |
|-----------|-------|
| Data Type | Number(4,0) |
| Required | false |
| Unique | false |
| External ID | false |
| Default Value | 2 |

### QueryPerformanceThresholdMs__c

```apex
global Decimal QueryPerformanceThresholdMs__c
```

Minimum duration in milliseconds before a SOQL query is logged as a performance entry.

**Field Attributes:**

| Attribute | Value |
|-----------|-------|
| Data Type | Number(18,0) |
| Required | false |
| Unique | false |
| External ID | false |
| Default Value | 1000 |

### SuppressClassMethod__c

```apex
global String SuppressClassMethod__c
```

Comma-separated class name patterns to suppress (denylist). Log entries from matching classes are dropped, even when ClassFilter is blank or includes them. Supports trailing wildcard (*). Blank means no class is suppressed. Applied AFTER the ClassFilter allowlist.

**Field Attributes:**

| Attribute | Value |
|-----------|-------|
| Data Type | Text(255) |
| Required | false |
| Unique | false |
| External ID | false |

### TriggerPerformanceThresholdMs__c

```apex
global Decimal TriggerPerformanceThresholdMs__c
```

Minimum duration in milliseconds before a trigger action handler is logged as a performance entry.

**Field Attributes:**

| Attribute | Value |
|-----------|-------|
| Data Type | Number(18,0) |
| Required | false |
| Unique | false |
| External ID | false |
| Default Value | 500 |

### ValidationPerformanceThresholdMs__c

```apex
global Decimal ValidationPerformanceThresholdMs__c
```

Minimum duration in milliseconds before a validation rule processing cycle is logged as a performance entry.

**Field Attributes:**

| Attribute | Value |
|-----------|-------|
| Data Type | Number(18,0) |
| Required | false |
| Unique | false |
| External ID | false |
| Default Value | 100 |

