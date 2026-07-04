---
title: "SCHED_DeactivateUsers"
type: class
description: "Scheduled job to automatically deactivate users who haven't logged in for a specified number of days. Configurable with parameters such as profile names, minimum inactivity days, batch size, and trans"
author: "Jason Van Beukering"
group: "Bulk DML"
date: "February 2026, May 2026"
since: "1.0"
category: apex
---

# SCHED_DeactivateUsers

**Class** · Group: `Bulk DML`

```apex
global inherited sharing class SCHED_DeactivateUsers extends SCHED_Base
```

**Extends:** [SCHED_Base](SCHED_Base.md)

Scheduled job to automatically deactivate users who haven't logged in for a specified number of days. Configurable with parameters such as profile names, minimum inactivity days, batch size, and transaction behavior.

**Since:** 1.0

**Example:**

```apex
SCHED_DeactivateUsers job = new SCHED_DeactivateUsers();
DTO_NameValues attributes = new DTO_NameValues();
attributes.add('profileNames', 'Standard User|Chatter Free User');
attributes.add('minimumNumberOfDays', '90');
job.setParameterValues(attributes);
System.schedule('Deactivate Inactive Users', '0 0 2 * * ?', job);
```

**See Also:** [SCHED_Base](SCHED_Base.md), [UTIL_BulkUpdates.deactivateUsers](UTIL_BulkUpdates.md#deactivateusers)

---

