---
title: "SCHED_JobRunner"
type: class
pageClass: reference
description: "The job runner's scheduled job. Health Check schedules this class once per chosen minute mark (one to twelve times an hour); each time the platform fires it, it runs one check, which starts every job "
author: "Jason Van Beukering"
group: "Schedulables"
date: "September 2026"
since: "1.8"
category: apex
---

# SCHED_JobRunner

**Class** · Group: `Schedulables`

<div class="apex-member apex-class">

```apex
global inherited sharing class SCHED_JobRunner extends SCHED_Base
```

**Extends:** [SCHED_Base](SCHED_Base.md)

The job runner's scheduled job. Health Check schedules this class once per chosen minute mark (one to twelve times an hour); each time the platform fires it, it runs one check, which starts every job whose record is set to run on the job runner and is due. The class holds no state and takes no parameters, so a package upgrade never invalidates it, and it is the only Kern class a platform scheduled job references for job-runner work. A check refuses to run for a user who does not hold the Manage Job Runner permission, because the jobs it starts run as that user.

**Example**

```apex
// Health Check activates the runner for you. To run one check by hand, schedule the class once at the next minute:
Datetime fireAt = Datetime.now().addSeconds(75);
String cron = '0 ' + fireAt.minute() + ' ' + fireAt.hour() + ' ' + fireAt.day() + ' ' + fireAt.month() + ' ? ' + fireAt.year();
System.schedule('One job runner check', cron, new SCHED_JobRunner());
```

**See Also:** [SCHED_Base](SCHED_Base.md)

</div>

---

