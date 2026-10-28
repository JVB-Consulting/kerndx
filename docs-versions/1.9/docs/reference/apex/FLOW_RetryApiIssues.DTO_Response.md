---
title: "FLOW_RetryApiIssues.DTO_Response"
type: class
pageClass: reference
description: "What the action answers: the job, the count and a message for the person who asked."
since: "1.8"
category: apex
---

# FLOW_RetryApiIssues.DTO_Response

**Class**

<div class="apex-member apex-class">

```apex
global inherited sharing class FLOW_RetryApiIssues.DTO_Response
```

What the action answers: the job, the count and a message for the person who asked.

</div>

---

## Fields

| Field | Description |
|-------|-------------|
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [jobId](#jobid) | The id of the background job, empty when nothing was queued. |
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [message](#message) | What happened, in words you can show the person who asked. |
| global [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) [queuedCount](#queuedcount) | How many of the issues were open and were handed to the job. |
| global [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) [success](#success) | Whether the request was accepted: true when you hold the Retry API Issue permission and at least one issue was handed to the retry job, false otherwise. |

### jobId

```apex
@InvocableVariable(description='The id of the background job, empty when nothing was queued.' label='Job Id') global String jobId
```

**Type:** [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)

The id of the background job, empty when nothing was queued.

### message

```apex
@InvocableVariable(description='What happened, in words you can show the person who asked.' label='Message') global String message
```

**Type:** [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)

What happened, in words you can show the person who asked.

### queuedCount

```apex
@InvocableVariable(description='How many of the issues were open and were handed to the job.' label='Queued Count') global Integer queuedCount
```

**Type:** [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm)

How many of the issues were open and were handed to the job.

### success

```apex
@InvocableVariable(description='True when the request was accepted: you hold the Retry API Issue permission and at least one issue was handed to the retry job' label='Success') global Boolean success
```

**Type:** [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm)

Whether the request was accepted: true when you hold the Retry API Issue permission and at least one
issue was handed to the retry job, false otherwise.

