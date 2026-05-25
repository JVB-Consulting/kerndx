---
title: "SCHED_PurgeRecords"
type: class
description: "A scheduled job that deletes records from a specified Salesforce object based on age or all records, configurable via attributes."
author: "Jason Van Beukering"
group: "Bulk DML"
date: "February 2026, May 2026"
since: "1.0"
category: apex
---

# SCHED_PurgeRecords

**Class** · Group: `Bulk DML`

```apex
global inherited sharing class SCHED_PurgeRecords extends SCHED_Base
```

**Extends:** [SCHED_Base](SCHED_Base.md)

A scheduled job that deletes records from a specified Salesforce object based on age or all records, configurable via attributes.

**Since:** 1.0

**Example:**

```apex
SCHED_PurgeRecords job = new SCHED_PurgeRecords();
DTO_NameValues attributes = new DTO_NameValues();
attributes.add('objectName', 'LogEntry__c');
attributes.add('minimumNumberOfDays', '30');
job.setParameterValues(attributes);
System.schedule('Purge Old Logs', '0 0 1 * * ?', job);
```

**See Also:** [SCHED_Base](SCHED_Base.md), [UTIL_PurgeRecords](UTIL_PurgeRecords.md)

---

