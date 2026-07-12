---
title: "FLOW_BypassTrigger"
type: class
pageClass: reference
description: "Flow invocable action to manage trigger bypasses. Supports bypassing a specific trigger action or object, clearing a specific bypass, and clearing all bypasses in a single action."
author: "Jason Van Beukering"
group: "Triggers"
date: "February 2026, July 2026"
since: "1.0"
category: apex
---

# FLOW_BypassTrigger

**Class** · Group: `Triggers`

<div class="apex-member apex-class">

```apex
global inherited sharing class FLOW_BypassTrigger
```

Flow invocable action to manage trigger bypasses. Supports bypassing a specific trigger action or object, clearing a specific bypass, and clearing all bypasses in a single action.

**Example**

```apex
FLOW_BypassTrigger.DTO_Request request = new FLOW_BypassTrigger.DTO_Request();
request.action = 'BYPASS';
request.bypassType = 'OBJECT_NAME';
request.name = 'Account';
FLOW_BypassTrigger.execute(new List<FLOW_BypassTrigger.DTO_Request> {request});
```

**See Also:** [FLOW_CheckTriggerBypassed](FLOW_CheckTriggerBypassed.md), [TRG_Base](TRG_Base.md)

</div>

---

## Methods

| Method | Description |
|--------|-------------|
| global static void [execute](#execute)([List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[FLOW_BypassTrigger.DTO_Request](FLOW_BypassTrigger.DTO_Request.md)> requests) | Manages trigger bypasses based on the requested action. |

### execute

<div class="apex-member">

```apex
@InvocableMethod(category='Trigger Actions' description='Bypass, clear, or clear all trigger bypasses for an object or action class.' label='Trigger Bypass') global static void execute(List<FLOW_BypassTrigger.DTO_Request> requests)
```

Manages trigger bypasses based on the requested action.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `requests` | [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm) | A list of bypass requests to process |

**Throws**

| Exception | Description |
|-----------|-------------|
| [IllegalArgumentException](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_classes_exception_methods.htm) | if more than one request is provided |
| [NoSuchElementException](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_classes_exception_methods.htm) | if the bypass type or action is invalid |

**Example**

```apex
FLOW_BypassTrigger.DTO_Request request = new FLOW_BypassTrigger.DTO_Request();
request.action = 'BYPASS';
request.bypassType = 'OBJECT_NAME';
request.name = 'Account';
FLOW_BypassTrigger.execute(new List<FLOW_BypassTrigger.DTO_Request>{request});
```

</div>

## Inner Classes

| Class | Description |
|-------|-------------|
| [DTO_Request](FLOW_BypassTrigger.DTO_Request.md) | Request DTO for the Trigger Bypass invocable action. |

---

