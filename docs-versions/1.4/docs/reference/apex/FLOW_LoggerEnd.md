---
title: "FLOW_LoggerEnd"
type: class
pageClass: reference
description: "Ends a logging correlation for a Flow. Use this at the end of a Flow to log completion status."
author: "Jason Van Beukering"
group: "Logging"
date: "December 2025, May 2026"
since: "1.0"
category: apex
---

# FLOW_LoggerEnd

**Class** · Group: `Logging`

<div class="apex-member apex-class">

```apex
global inherited sharing class FLOW_LoggerEnd
```

Ends a logging correlation for a Flow. Use this at the end of a Flow to log completion status.

**Example**

`In Flow Builder: ` Add "End Flow Correlation" action at the end of your Flow Pass the Correlation ID from "Start Flow Correlation" Set Flow Name and Success status `Optionally set Error Message if the Flow failed `

</div>

---

## Methods

| Method | Description |
|--------|-------------|
| global static void [execute](#execute)([List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[FLOW_LoggerEnd.DTO_Request](FLOW_LoggerEnd.DTO_Request.md)> inputs) | Ends a correlation context for Flow logging. |

### execute

<div class="apex-member">

```apex
@InvocableMethod(category='Logging' description='Ends logging correlation for a Flow and logs completion status.' label='End Flow Correlation') global static void execute(List<FLOW_LoggerEnd.DTO_Request> inputs)
```

Ends a correlation context for Flow logging.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `inputs` | [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm) | List of input parameters |

**Example**

```apex
FLOW_LoggerEnd.execute(new List<DTO_Request>());
```

</div>

## Inner Classes

| Class | Description |
|-------|-------------|
| [DTO_Request](FLOW_LoggerEnd.DTO_Request.md) | Input parameters for ending Flow correlation. |

---

