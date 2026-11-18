---
title: "FLOW_CallApiAsync"
type: class
pageClass: reference
description: "Asynchronously invokes web service calls, allowing large or delayed API callouts to be processed outside of immediate flows or triggers. Leverages the adaptive asynchronous processor to manage API req"
author: "Jason Van Beukering"
group: "Web Services"
date: "February 2026, November 2026"
since: "1.0"
category: apex
---

# FLOW_CallApiAsync

**Class** · Group: `Web Services`

<div class="apex-member apex-class">

```apex
global inherited sharing class FLOW_CallApiAsync
```

Asynchronously invokes web service calls, allowing large or delayed API callouts to be processed outside of immediate flows or triggers. Leverages the adaptive asynchronous processor to manage API requests efficiently.

**Example**

```apex
List<ApiCall__c> apiCalls = new List<ApiCall__c>();
ApiCall__c apiCall = TST_Factory.newOutboundApiCall('API_GetCustomerInfo', recordId, new Map<String, String>{'customerId' => '5678'});
apiCalls.add(apiCall);
FLOW_CallApiAsync.invokeApiCallAsynchronously(apiCalls);
```

</div>

---

## Methods

| Method | Description |
|--------|-------------|
| global static void [invokeApiCallAsynchronously](#invokeapicallasynchronously)([List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[ApiCall__c](../objects/ApiCall__c.md)> apiCalls) | Invokes web service calls asynchronously by enqueuing Queueable jobs for each set of API calls. |

### invokeApiCallAsynchronously

<div class="apex-member">

```apex
@InvocableMethod(category='Api Callouts' description='Queues an HTTP callout asynchronously. Use when a Flow sends data to an external service and does not need to wait for the response.' label='Invoke Callout Asynchronously') global static void invokeApiCallAsynchronously(List<ApiCall__c> apiCalls)
```

Invokes web service calls asynchronously by enqueuing Queueable jobs for each set of API calls.
Falls back to Batch job if Queueable limits are exceeded. The job size is read from
`AsynchronousJobSetting__mdt.FLOW_CallApiAsync` (default: 20) to keep each execution within
the 100-callout governor limit.

Before the jobs start, every call whose Status__c is Retry is saved with the status Retrying, so the Retry
Outbound Api Call flow does not pick it up a second time. Calls at any other status are not changed here.

The saves this method makes ignore record sharing, so they work whoever the flow runs as. This means the method
changes the calls it is given even when the running user cannot see or edit them.

If the save of a call to Retrying is refused anyway, for example by a validation rule, that call is not sent this
time. It stays at Retry, and one warning log entry lists the Ids of the calls that were not sent. Where the outbound
retry watchdog job is scheduled, it gives those calls a new retry time.

If the save to Retrying is refused for every call given, no job is started.

Salesforce can refuse to start a background job, for example when the org has used its daily allowance of
background jobs. This method then returns normally, and the save that called it does not fail:

- Each call whose job did not start is saved at Status__c Retry, with a later NextRetry__c and the reason in
ErrorMessages__c. A call that was not saved yet is saved as a new call. The Retry Outbound Api Call flow sends
the call at that time.

- Retries__c does not change and no API issue is raised, because the request was never sent.

- The wait is twice the call's last wait, never less than 15 minutes and never more than 240. A call that is not
at Retry waits 15 minutes, and each new refusal of the same call doubles the wait.

- Calls whose job did start are sent as usual and are not changed.

- One warning log entry says how many calls wait and when the first one is tried again. No error entry is written
for the refused start. A call whose save at Retry is refused is not counted as waiting; it gets an error log entry.

A job refused later, in a send split into a chain of jobs or in a send that runs as one batch job, is only logged
as an ERROR. Its calls are not changed, and a call that was not saved yet is lost. Inside a batch, queueable or
future job, save your calls before you pass them.

The Web Services guide gives the full rules, under "What happens when Salesforce refuses to start a send?" and
"Which refused sends are only logged?".

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

