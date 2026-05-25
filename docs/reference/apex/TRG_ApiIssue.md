---
title: "TRG_ApiIssue"
type: trigger
description: "Trigger on ApiIssue__c. Fires the configured trigger actions for data masking before insert and update so sensitive payload fragments captured in the diagnostic record are redacted before persistence,"
author: "Jason Van Beukering"
date: "April 2026, May 2026"
category: apex
---

# TRG_ApiIssue

**Trigger**

```apex
trigger TRG_ApiIssue on ApiIssue__c ( before insert, before update )
```

Trigger on ApiIssue__c. Fires the configured trigger actions for data masking before insert and update so sensitive payload fragments captured in the diagnostic record are redacted before persistence, regardless of whether the issue was created by the web-service framework or by subscriber Apex.

**See Also:** [ApiIssue__c](../objects/ApiIssue__c.md)

---

