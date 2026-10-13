---
title: "FLOW_CallApi"
type: class
pageClass: reference
description: "Invokes web service calls synchronously, allowing for integration with external systems from Salesforce using Lightning Flow or Process Builder. Receives a list of requests, sends them to their respec"
author: "Jason Van Beukering"
group: "Web Services"
date: "February 2026, May 2026"
since: "1.0"
category: apex
---

# FLOW_CallApi

**Class** · Group: `Web Services`

<div class="apex-member apex-class">

```apex
global inherited sharing class FLOW_CallApi
```

Invokes web service calls synchronously, allowing for integration with external systems from Salesforce using Lightning Flow or Process Builder. Receives a list of requests, sends them to their respective endpoints, and returns responses as structured data.

**Example**

```apex
FLOW_CallApi.DTO_Request request = new FLOW_CallApi.DTO_Request();
request.apiName = 'API_GetCustomerInfo';
request.recordId = recordId;
request.inputs = 'customerId=5678';
List<FLOW_CallApi.DTO_Response> responses = FLOW_CallApi.invokeApiCallSynchronously(new List<FLOW_CallApi.DTO_Request> {request});
```

</div>

---

## Methods

| Method | Description |
|--------|-------------|
| global static [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[FLOW_CallApi.DTO_Response](FLOW_CallApi.DTO_Response.md)> [invokeApiCallSynchronously](#invokeapicallsynchronously)([List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[FLOW_CallApi.DTO_Request](FLOW_CallApi.DTO_Request.md)> requestDataTransferObjects) | Invokes web service calls synchronously using a list of DTO_Request objects. |

### invokeApiCallSynchronously

<div class="apex-member">

```apex
@InvocableMethod(category='Api Callouts' description='Makes a real-time HTTP callout to an external system using a configured API handler. Use when a Flow needs to send or retrieve data from an external service and wait for the response.' label='Invoke Callout Synchronously' callout=true) global static List<FLOW_CallApi.DTO_Response> invokeApiCallSynchronously(List<FLOW_CallApi.DTO_Request> requestDataTransferObjects)
```

Invokes web service calls synchronously using a list of DTO_Request objects.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `requestDataTransferObjects` | [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm) | The list of web service requests to execute. |

**Returns** [FLOW_CallApi.DTO_Response](FLOW_CallApi.DTO_Response.md) — List The results of the calls.

**Example**

```apex
List<FLOW_CallApi.DTO_Request> requests = new List<FLOW_CallApi.DTO_Request>();
FLOW_CallApi.DTO_Request request = new FLOW_CallApi.DTO_Request();
request.apiName = 'API_GetCustomerInfo';
request.inputs = 'customerId=5678';
requests.add(request);
List<FLOW_CallApi.DTO_Response> responses = FLOW_CallApi.invokeApiCallSynchronously(requests);
```

</div>

## Inner Classes

| Class | Description |
|-------|-------------|
| [DTO_Request](FLOW_CallApi.DTO_Request.md) | Data Transfer Object representing the web service call request. |
| [DTO_Response](FLOW_CallApi.DTO_Response.md) | Data Transfer Object representing the web service response or errors. |

---

