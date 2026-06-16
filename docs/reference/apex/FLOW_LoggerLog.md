---
title: "FLOW_LoggerLog"
type: class
pageClass: reference
description: "Logs an event within a Flow with correlation support. Use this to log messages, warnings, or errors during Flow execution."
author: "Jason Van Beukering"
group: "Logging"
date: "December 2025, May 2026"
since: "1.0"
category: apex
---

# FLOW_LoggerLog

**Class** · Group: `Logging`

<div class="apex-member apex-class">

```apex
global inherited sharing class FLOW_LoggerLog
```

Logs an event within a Flow with correlation support. Use this to log messages, warnings, or errors during Flow execution.

**Example**

`In Flow Builder: ` Add "Log Flow Event" action anywhere in your Flow Pass the Correlation ID from "Start Flow Correlation" Set Message and optionally Log Level (DEBUG, INFO, WARN, ERROR) `Optionally set Flow Step to identify where in the Flow the log occurred `

</div>

---

## Methods

| Method | Description |
|--------|-------------|
| global static void [execute](#execute)([List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[FLOW_LoggerLog.DTO_Request](FLOW_LoggerLog.DTO_Request.md)> inputs) | Logs an event within a Flow. |

## Inner Classes

| Class | Description |
|-------|-------------|
| [DTO_Request](FLOW_LoggerLog.DTO_Request.md) | Input parameters for logging a Flow event. |

---

## Method Details

### execute

<div class="apex-member">

```apex
@InvocableMethod(category='Logging' description='Logs a message within a Flow with correlation support.' label='Log Flow Event') global static void execute(List<FLOW_LoggerLog.DTO_Request> inputs)
```

Logs an event within a Flow.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `inputs` | [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm) | List of input parameters |

**Example**

```apex
FLOW_LoggerLog.execute(new List<DTO_Request>());
```

</div>

