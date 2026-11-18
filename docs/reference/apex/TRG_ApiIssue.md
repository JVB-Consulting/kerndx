---
title: "TRG_ApiIssue"
type: trigger
pageClass: reference
description: "Trigger on ApiIssue__c. It registers every trigger event, so a trigger action row you add for this object runs on any of them. The package's own rows use the before events. Before insert and update th"
author: "Jason Van Beukering"
group: "Web Services"
date: "April 2026, November 2026"
category: apex
---

# TRG_ApiIssue

**Trigger** · Group: `Web Services`

<div class="apex-member apex-class">

```apex
trigger TRG_ApiIssue on ApiIssue__c ( before insert, after insert, before update, after update, before delete, after delete, after undelete )
```

Trigger on ApiIssue__c. It registers every trigger event, so a trigger action row you add for this object runs on any of them. The package's own rows use the before events. Before insert and update the trigger masks the record's data, so sensitive payload fragments captured in the diagnostic record are redacted before persistence, whether the issue was created by the web-service framework or by subscriber Apex. Before a delete it runs the action that refuses the delete to every user the Bypass API Record Delete Guard feature flag is off for (out of the box, everyone without the Delete API Records permission).

**See Also:** [ApiIssue__c](../objects/ApiIssue__c.md)

</div>

---

