---
title: "FLOW_LoggerStart"
type: class
pageClass: reference
description: "Starts a logging correlation for a Flow. Use this at the beginning of a Flow to generate a correlation ID that links all subsequent log entries."
author: "Jason Van Beukering"
group: "Logging"
date: "December 2025, May 2026"
since: "1.0"
category: apex
---

# FLOW_LoggerStart

**Class** · Group: `Logging`

<div class="apex-member apex-class">

```apex
global inherited sharing class FLOW_LoggerStart
```

Starts a logging correlation for a Flow. Use this at the beginning of a Flow to generate a correlation ID that links all subsequent log entries.

**Example**

`In Flow Builder: ` Add "Start Flow Correlation" action at the beginning Set Flow Name (e.g., "Create Account") Optionally set Record ID for context Store the returned Correlation ID in a variable `Pass this ID to subsequent "Log Flow Event" and "End Flow Correlation" actions `

</div>

---

## Methods

| Method | Description |
|--------|-------------|
| global static [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[FLOW_LoggerStart.DTO_Response](FLOW_LoggerStart.DTO_Response.md)> [execute](#execute)([List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[FLOW_LoggerStart.DTO_Request](FLOW_LoggerStart.DTO_Request.md)> dtoRequests) | Starts a correlation context for Flow logging. |

### execute

<div class="apex-member">

```apex
@InvocableMethod(category='Logging' description='Starts logging correlation for a Flow. Returns a correlation ID to pass to other logging actions.' label='Start Flow Correlation') global static List<FLOW_LoggerStart.DTO_Response> execute(List<FLOW_LoggerStart.DTO_Request> dtoRequests)
```

Starts a correlation context for Flow logging.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `dtoRequests` | [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm) | List of input parameters |

**Returns** [FLOW_LoggerStart.DTO_Response](FLOW_LoggerStart.DTO_Response.md) — List of outputs containing correlation IDs

</div>

## Inner Classes

| Class | Description |
|-------|-------------|
| [DTO_Request](FLOW_LoggerStart.DTO_Request.md) | Input parameters for starting Flow correlation. |
| [DTO_Response](FLOW_LoggerStart.DTO_Response.md) | Output containing the generated correlation ID. |

---

