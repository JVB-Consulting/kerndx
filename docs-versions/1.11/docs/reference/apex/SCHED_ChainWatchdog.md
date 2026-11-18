---
title: "SCHED_ChainWatchdog"
type: class
pageClass: reference
description: "A scheduled job that finds async chains stuck with no recent activity and marks them Stalled, firing each chain's persisted onError notification once per stall. A chain goes silently stuck when the pl"
author: "Jason Van Beukering"
group: "Async"
date: "July 2026, October 2026"
since: "1.6"
category: apex
---

# SCHED_ChainWatchdog

**Class** · Group: `Async`

<div class="apex-member apex-class">

```apex
global inherited sharing class SCHED_ChainWatchdog extends SCHED_Base
```

**Extends:** [SCHED_Base](SCHED_Base.md)

A scheduled job that finds async chains stuck with no recent activity and marks them Stalled, firing each chain's persisted onError notification once per stall. A chain goes silently stuck when the platform stops its next piece of work without ever calling back — this job is the safety net that surfaces such chains for recovery instead of leaving them Running forever. Configurable via attributes: how long a chain may sit idle before it counts as stale, and how many chains one sweep inspects.

**Example**

```apex
SCHED_ChainWatchdog job = new SCHED_ChainWatchdog();
DTO_NameValues attributes = new DTO_NameValues();
attributes.add('StaleThresholdMinutes', '30');
attributes.add('BatchSize', '50');
job.setParameterValues(attributes);
System.schedule('Chain Watchdog', '0 0 * * * ?', job);
```

**See Also:** [SCHED_Base](SCHED_Base.md), [UTIL_AsyncChain](UTIL_AsyncChain.md)

</div>

---

