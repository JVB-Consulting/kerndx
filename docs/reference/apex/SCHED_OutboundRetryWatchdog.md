---
title: "SCHED_OutboundRetryWatchdog"
type: class
pageClass: reference
description: "A scheduled job that finds outbound calls the Retry Outbound Api Call flow will never send again, and deals with each one in a fixed way. It never sends a request itself. Schedule it through the job r"
author: "Jason Van Beukering"
group: "Web Services"
date: "November 2026"
since: "1.12"
category: apex
---

# SCHED_OutboundRetryWatchdog

**Class** · Group: `Web Services`

<div class="apex-member apex-class">

```apex
global inherited sharing class SCHED_OutboundRetryWatchdog extends SCHED_Base
```

**Extends:** [SCHED_Base](SCHED_Base.md)

A scheduled job that finds outbound calls the Retry Outbound Api Call flow will never send again, and deals with each one in a fixed way. It never sends a request itself. Schedule it through the job runner (a ScheduledJob__c record with this class name), for example every hour. Each run reads three kinds of stale outbound call. A call is stale when the time it is judged by is older than the stale limit (the StaleThresholdMinutes parameter, 60 minutes by default): A call at Retry whose retry time (NextRetry__c) is stale gets a new retry time, so the flow sends it again. The new wait is twice the last wait, from 15 to 240 minutes. Its retry count does not change. One warning is logged. A call at Retrying whose retry time is stale is being sent again by a background job that has not finished. While a job of the class that sends outbound calls is waiting or running, and was created after the call's retry time, that job may still send it, so the call is left as it is and checked again on the next run. After one day, or when no such job is live, the call is marked Failed, with text that says the request may have been sent. When the service's API setting logs issues, an API issue is raised that says the other system may have acted on it. A call at Queued that has not changed for longer than the stale limit is only reported, in one warning. A call at Retry with no retry time is left as it is. Each run looks at no more than the batch size (the BatchSize parameter, 50 by default and never more than 50) of each kind; the rest wait for the next run. The job reads and saves the calls without record sharing, so a run changes the calls of every user, whoever runs it. A warning or an API issue is written only for a call whose change was saved: a call the save refused is not reported as changed.

**Example**

```apex
SCHED_OutboundRetryWatchdog job = new SCHED_OutboundRetryWatchdog();
DTO_NameValues attributes = new DTO_NameValues();
attributes.add('StaleThresholdMinutes', '60');
attributes.add('BatchSize', '50');
job.setParameterValues(attributes);
System.schedule('Outbound Retry Watchdog', '0 0 * * * ?', job);
```

**See Also:** [SCHED_Base](SCHED_Base.md), [SEL_ApiCall](SEL_ApiCall.md)

</div>

---

