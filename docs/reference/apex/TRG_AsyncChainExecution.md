---
title: "TRG_AsyncChainExecution"
type: trigger
pageClass: reference
description: "Trigger on AsyncChainExecution__c. It registers every trigger event, so a trigger action row you add for this object runs on any of them. The package's own rows use the before events. Before insert an"
author: "Jason Van Beukering"
group: "Async"
date: "April 2026, November 2026"
category: apex
---

# TRG_AsyncChainExecution

**Trigger** · Group: `Async`

<div class="apex-member apex-class">

```apex
trigger TRG_AsyncChainExecution on AsyncChainExecution__c ( before insert, after insert, before update, after update, before delete, after delete, after undelete )
```

Trigger on AsyncChainExecution__c. It registers every trigger event, so a trigger action row you add for this object runs on any of them. The package's own rows use the before events. Before insert and update the trigger masks the record's data, so context data, step logs, and error messages persisted across the chain's Queueable transactions are redacted before storage.

**See Also:** [AsyncChainExecution__c](../objects/AsyncChainExecution__c.md)

</div>

---

