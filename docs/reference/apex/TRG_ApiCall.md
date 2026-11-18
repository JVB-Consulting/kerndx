---
title: "TRG_ApiCall"
type: trigger
pageClass: reference
description: "Trigger on ApiCall__c. It registers every trigger event, so a trigger action row you add for this object runs on any of them. The package's own rows use the before events. Before insert and update the"
author: "Jason Van Beukering"
group: "Web Services"
date: "November 2023, November 2026"
category: apex
---

# TRG_ApiCall

**Trigger** · Group: `Web Services`

<div class="apex-member apex-class">

```apex
trigger TRG_ApiCall on ApiCall__c ( before insert, after insert, before update, after update, before delete, after delete, after undelete )
```

Trigger on ApiCall__c. It registers every trigger event, so a trigger action row you add for this object runs on any of them. The package's own rows use the before events. Before insert and update the trigger masks the record's data. Before a delete it runs the action that refuses the delete to every user the Bypass API Record Delete Guard feature flag is off for (out of the box, everyone without the Delete API Records permission), then the content-document cleanup.

**See Also:** [ApiCall__c](../objects/ApiCall__c.md)

</div>

---

