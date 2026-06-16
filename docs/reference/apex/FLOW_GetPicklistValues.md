---
title: "FLOW_GetPicklistValues"
type: class
pageClass: reference
description: "Invocable method to get all the picklist values for a particular object for a given record type. Delegates to UTIL_SObjectDescribe for ConnectApi retrieval and transformation. Caches responses in org "
author: "Jason Van Beukering"
group: "Utilities"
date: "February 2026, May 2026"
since: "1.0"
category: apex
---

# FLOW_GetPicklistValues

**Class** · Group: `Utilities`

```apex
global inherited sharing class FLOW_GetPicklistValues
```

Invocable method to get all the picklist values for a particular object for a given record type. Delegates to UTIL_SObjectDescribe for ConnectApi retrieval and transformation. Caches responses in org cache to reduce repeated ConnectApi calls for the same requests.

**Since:** 1.0

**Example:**

```apex
FLOW_GetPicklistValues.DTO_Request request = new FLOW_GetPicklistValues.DTO_Request();
request.objectApiName = 'Contact';
request.recordTypeApiName = 'Customer_Contact';
List<FLOW_GetPicklistValues.DTO_Response> responses = FLOW_GetPicklistValues.getPickListValues(new List<FLOW_GetPicklistValues.DTO_Request> {request});
List<DTO_PickList> pickLists = responses[0].pickLists;
```

**See Also:** [DTO_PickList](DTO_PickList.md), [DTO_PicklistValue](DTO_PicklistValue.md), [UTIL_SObjectDescribe](UTIL_SObjectDescribe.md)

---

## Methods

| Method | Description |
|--------|-------------|
| global static [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[FLOW_GetPicklistValues.DTO_Response](FLOW_GetPicklistValues.DTO_Response.md)> [getPickListValues](#getpicklistvalues)([List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[FLOW_GetPicklistValues.DTO_Request](FLOW_GetPicklistValues.DTO_Request.md)> dtoRequests) | Retrieves the picklist values for an SObject and record type combination. |

## Inner Classes

| Class | Description |
|-------|-------------|
| [DTO_Request](FLOW_GetPicklistValues.DTO_Request.md) | Request DTO containing the information required to retrieve picklist values. |
| [DTO_Response](FLOW_GetPicklistValues.DTO_Response.md) | Provides the outcome of the picklist values retrieval. |

---

## Method Details

### getPickListValues

<div class="apex-member">

```apex
@InvocableMethod(category='Utilities' description='Returns the available picklist values for a specified object and record type. Use to dynamically populate choice lists or validate picklist selections in a Flow.' label='Get PickList Values') global static List<FLOW_GetPicklistValues.DTO_Response> getPickListValues(List<FLOW_GetPicklistValues.DTO_Request> dtoRequests)
```

Retrieves the picklist values for an SObject and record type combination.
Checks the org cache for stored values first and only calls ConnectApi if the values are not cached.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `dtoRequests` | [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm) | A list of requests indicating for which object and record type combination to retrieve picklist values |

**Returns** [FLOW_GetPicklistValues.DTO_Response](FLOW_GetPicklistValues.DTO_Response.md) — A list of responses (only will ever contain 1 item)

**Throws**

| Exception | Description |
|-----------|-------------|
| [IllegalArgumentException](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_classes_exception_methods.htm) | If more than one request provided, an exception will be thrown |

**Example**

```apex
List<DTO_Request> dtoRequests = new List<DTO_Request>();
DTO_Request request = new DTO_Request();
request.objectApiName = 'Contact';
request.recordTypeApiName = 'Customer_Contact';
dtoRequests.add(request);
List<DTO_Response> responses = FLOW_GetPicklistValues.getPickListValues(dtoRequests);
```

</div>

