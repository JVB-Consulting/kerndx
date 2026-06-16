---
title: "FLOW_CallApiAsync"
type: class
pageClass: reference
description: "Asynchronously invokes web service calls, allowing large or delayed API callouts to be processed outside of immediate flows or triggers. Leverages the adaptive asynchronous processor to manage API req"
author: "Jason Van Beukering"
group: "Web Services"
date: "February 2026, May 2026"
since: "1.0"
category: apex
---

# FLOW_CallApiAsync

**Class** · Group: `Web Services`

```apex
global inherited sharing class FLOW_CallApiAsync
```

Asynchronously invokes web service calls, allowing large or delayed API callouts to be processed outside of immediate flows or triggers. Leverages the adaptive asynchronous processor to manage API requests efficiently.

**Since:** 1.0

**Example:**

```apex
List<ApiCall__c> apiCalls = new List<ApiCall__c>();
ApiCall__c apiCall = TST_Factory.newOutboundApiCall('API_GetCustomerInfo', recordId, new Map<String, String>{'customerId' => '5678'});
apiCalls.add(apiCall);
FLOW_CallApiAsync.invokeApiCallAsynchronously(apiCalls);
```

---

## Methods

| Method | Description |
|--------|-------------|
| global static void [invokeApiCallAsynchronously](#invokeapicallasynchronously)([List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[ApiCall__c](../objects/ApiCall__c.md)> apiCalls) | Invokes web service calls asynchronously by enqueuing Queueable jobs for each set of API calls. |

---

## Method Details

### invokeApiCallAsynchronously

<div class="apex-member">

```apex
@InvocableMethod(category='Api Callouts' description='Queues an HTTP callout asynchronously. Use when a Flow sends data to an external service and does not need to wait for the response.' label='Invoke Callout Asynchronously') global static void invokeApiCallAsynchronously(List<ApiCall__c> apiCalls)
```

Invokes web service calls asynchronously by enqueuing Queueable jobs for each set of API calls.
Falls back to Batch job if Queueable limits are exceeded. The job size is read from
`AsynchronousJobSetting__mdt.FLOW_CallApiAsync` (default: 20) to keep each execution within
the 100-callout governor limit.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `apiCalls` | [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm) | The list of API calls containing details for API callouts. |

**Example**

```apex
List<ApiCall__c> apiCalls = new List<ApiCall__c>();
ApiCall__c apiCall = TST_Factory.newOutboundApiCall('API_GetCustomerInfo', null, new Map<String, String>{'customerId' => '5678'});
apiCalls.add(apiCall);
FLOW_CallApiAsync.invokeApiCallAsynchronously(apiCalls);
```

</div>

