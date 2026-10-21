---
title: "FLOW_RetryApiIssues"
type: class
pageClass: reference
description: "Runs the failed calls of the API issues you select again, in one background job: from the Retry Selected action on the API Issues list, from your own flow, or from Apex. The issues that are still open"
author: "Jason Van Beukering"
group: "Web Services"
date: "October 2026"
since: "1.8"
category: apex
---

# FLOW_RetryApiIssues

**Class** · Group: `Web Services`

<div class="apex-member apex-class">

```apex
global inherited sharing class FLOW_RetryApiIssues
```

Runs the failed calls of the API issues you select again, in one background job: from the Retry Selected action on the API Issues list, from your own flow, or from Apex. The issues that are still open are handed to the job. The job sends each distinct request once and marks resolved every issue whose call succeeds. It skips an issue whose external system may already have acted, an issue whose call or record still has a call in progress, and an issue whose service is paused or does not allow retries (Retry Issues is off in its API setting). It also skips an issue whose call failed in a way a new run cannot fix, and an issue of a call your org received when the call no longer holds the request exactly as it was received. A request your org received is run again from the call that received it. You need the Retry API Issue permission; without it nothing is queued and the message says so.

**Example**

```apex
FLOW_RetryApiIssues.DTO_Request request = new FLOW_RetryApiIssues.DTO_Request();
request.apiIssueIds = new List<String> {issueId};
FLOW_RetryApiIssues.DTO_Response response = FLOW_RetryApiIssues.retryApiIssues(new List<FLOW_RetryApiIssues.DTO_Request> {request}).get(0);
```

</div>

---

## Methods

| Method | Description |
|--------|-------------|
| global static [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[FLOW_RetryApiIssues.DTO_Response](FLOW_RetryApiIssues.DTO_Response.md)> [retryApiIssues](#retryapiissues)([List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[FLOW_RetryApiIssues.DTO_Request](FLOW_RetryApiIssues.DTO_Request.md)> requests) | Queues a retry of the open issues among the ids you pass and tells you how many were queued. |

### retryApiIssues

<div class="apex-member">

```apex
@InvocableMethod(category='Api Callouts' description='Runs the failed calls of the API issues you select again, in one background job. Needs the Retry API Issue permission.' label='Retry API Issues') global static List<FLOW_RetryApiIssues.DTO_Response> retryApiIssues(List<FLOW_RetryApiIssues.DTO_Request> requests)
```

Queues a retry of the open issues among the ids you pass and tells you how many were queued. Ids that are
not record ids and ids of other objects are left out. An issue is not queued, and stays open, when it is not open, when
the external system may already have acted on it, when its service is paused or does not allow retries, when its call
failed in a way a new run cannot fix, or, for a call your org received, when the call no longer holds the request
exactly as it was received; the message says how many of the open issues you named were queued and why the rest were not. The
job may still skip a few, for example when a call for the same record is still running, and each issue shows its own
result. The answer carries no count of the issues it left out.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `requests` | [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm) | Exactly one request, holding the ids of the API issues to run again. |

**Returns** [FLOW_RetryApiIssues.DTO_Response](FLOW_RetryApiIssues.DTO_Response.md) — One response: whether the request was accepted, the job id (null when nothing was queued), how many issues were queued, and a message.

**Throws**

| Exception | Description |
|-----------|-------------|
| [IllegalArgumentException](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_classes_exception_methods.htm) | When the list does not hold exactly one request. |

**Example**

```apex
FLOW_RetryApiIssues.DTO_Request request = new FLOW_RetryApiIssues.DTO_Request();
request.apiIssueIds = new List<String> {firstIssueId, secondIssueId};
FLOW_RetryApiIssues.DTO_Response response = FLOW_RetryApiIssues.retryApiIssues(new List<FLOW_RetryApiIssues.DTO_Request> {request}).get(0);
Assert.areEqual(2, response.queuedCount);
```

</div>

## Inner Classes

| Class | Description |
|-------|-------------|
| [DTO_Request](FLOW_RetryApiIssues.DTO_Request.md) | What the action is asked: the API issues to run again. |
| [DTO_Response](FLOW_RetryApiIssues.DTO_Response.md) | What the action answers: the job, the count and a message for the person who asked. |

---

