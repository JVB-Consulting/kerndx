---
title: "TRG_ApiCall"
type: trigger
pageClass: reference
description: "Trigger on ApiCall__c. Fires the configured trigger actions for data masking before insert and update, and before a delete the action that refuses the delete to every user the Bypass API Record Delete"
author: "Jason Van Beukering"
date: "November 2023, October 2026"
category: apex
---

# TRG_ApiCall

**Trigger**

<div class="apex-member apex-class">

```apex
trigger TRG_ApiCall on ApiCall__c ( before insert, before update, before delete )
```

Trigger on ApiCall__c. Fires the configured trigger actions for data masking before insert and update, and before a delete the action that refuses the delete to every user the Bypass API Record Delete Guard feature flag is off for (out of the box, everyone without the Delete API Records permission), then the content-document cleanup.

**See Also:** [ApiCall__c](../objects/ApiCall__c.md)

</div>

---

