---
title: "TRG_AsyncChainExecution"
type: trigger
description: "Trigger on AsyncChainExecution__c. Fires the configured trigger actions for data masking before insert and update so context data, step logs, and error messages persisted across the chain's Queueable "
author: "Jason Van Beukering"
date: "April 2026, May 2026"
category: apex
---

# TRG_AsyncChainExecution

**Trigger**

```apex
trigger TRG_AsyncChainExecution on AsyncChainExecution__c ( before insert, before update )
```

Trigger on AsyncChainExecution__c. Fires the configured trigger actions for data masking before insert and update so context data, step logs, and error messages persisted across the chain's Queueable transactions are redacted before storage.

**See Also:** [AsyncChainExecution__c](../objects/AsyncChainExecution__c.md)

---

