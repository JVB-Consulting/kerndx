---
title: "FLOW_CheckTriggerBypassed"
type: class
description: "This class is used to check whether certain triggers or actions are bypassed in the system. The class provides a method that can be invoked from a flow or Apex to determine if an object-level, Apex tr"
author: "Jason Van Beukering"
group: "Triggers"
date: "February 2026, May 2026"
since: "1.0"
category: apex
---

# FLOW_CheckTriggerBypassed

**Class** · Group: `Triggers`

```apex
global inherited sharing class FLOW_CheckTriggerBypassed
```

This class is used to check whether certain triggers or actions are bypassed in the system. The class provides a method that can be invoked from a flow or Apex to determine if an object-level, Apex trigger class-level, or flow action-level bypass is active. It is based on the metadata-driven trigger actions framework that enables trigger execution to be turned on or off based on metadata configuration. adapted from:apex-trigger-actions-framework

**Since:** 1.0

**Example:**

```apex
FLOW_CheckTriggerBypassed.DTO_Request request = new FLOW_CheckTriggerBypassed.DTO_Request();
request.name = 'Account';
request.bypassType = 'OBJECT_NAME';
List<Boolean> results = FLOW_CheckTriggerBypassed.isBypassed(new List<FLOW_CheckTriggerBypassed.DTO_Request> {request});
Boolean isBypassed = results[0];
```

---

## Methods

| Method | Description |
|--------|-------------|
| global static [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm)> [isBypassed](#isbypassed)([List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[FLOW_CheckTriggerBypassed.DTO_Request](FLOW_CheckTriggerBypassed.DTO_Request.md)> dtoRequests) | Returns if the bypass for this object, apex action, or flow action is set to true. |

## Inner Classes

| Class | Description |
|-------|-------------|
| [DTO_Request](FLOW_CheckTriggerBypassed.DTO_Request.md) | A DTO indicating what action has been bypassed |

---

## Method Details

### isBypassed

```apex
@InvocableMethod(category='Trigger Actions' description='Returns if the bypass for an Object or Apex trigger action class is set to true.' label='Is Bypassed') global static List<Boolean> isBypassed(List<FLOW_CheckTriggerBypassed.DTO_Request> dtoRequests)
```

Returns if the bypass for this object, apex action, or flow action is set to true.
The DTO_Request class represents the request to check if a specific bypass is active.
Each request contains the name of the object or Apex class to be checked, and the type of the bypass
(either for a class name or object name). This object is passed into the isBypassed method to specify
the bypass type and target.

**Parameters:**

- `dtoRequests` ([List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)) - A list of Action Names and Types

**Returns:** [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) - If the action has been bypassed

**Throws:**

- [IllegalArgumentException](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_classes_exception_methods.htm) - Will throw exception if more than one request is provided or the bypass type is invalid

**Since:** 1.0

**Example:**

```apex
List<DTO_Request> requests = new List<DTO_Request>();
DTO_Request request = new DTO_Request();
request.name = 'Account';
request.bypassType = 'OBJECT_NAME';
requests.add(request);
List<Boolean> isBypassedResult = FLOW_CheckTriggerBypassed.isBypassed(requests);
```

