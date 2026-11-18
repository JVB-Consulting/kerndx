---
title: "TRG_ScheduledJob"
type: trigger
pageClass: reference
description: "TRG_ScheduledJob activated by saving Scheduled Job records (rule: 1 record per periodic job setting). It registers every trigger event, so a trigger action row you add for this object runs on any of t"
author: "Jason Van Beukering"
group: "Async Processing"
date: "2019, November 2026"
category: apex
---

# TRG_ScheduledJob

**Trigger** · Group: `Async Processing`

<div class="apex-member apex-class">

```apex
trigger TRG_ScheduledJob on ScheduledJob__c ( before insert, after insert, before update, after update, before delete, after delete, after undelete )
```

TRG_ScheduledJob activated by saving Scheduled Job records (rule: 1 record per periodic job setting). It registers every trigger event, so a trigger action row you add for this object runs on any of them. The package's own rows use the before events.

</div>

---

