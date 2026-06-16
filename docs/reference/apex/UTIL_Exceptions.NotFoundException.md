---
title: "UTIL_Exceptions.NotFoundException"
type: class
pageClass: reference
description: "Thrown when a lookup for a specific record or resource yields no results. Commonly raised by selector findByIdOrThrow methods and resource-loading utilities to distinguish \"not found\" from other fai"
group: "Utilities"
since: "1.0"
category: apex
---

# UTIL_Exceptions.NotFoundException

**Class** · Group: `Utilities`

```apex
global inherited sharing class UTIL_Exceptions.NotFoundException
```

Thrown when a lookup for a specific record or resource yields no results. Commonly raised by selector findByIdOrThrow methods and resource-loading utilities to distinguish "not found" from other failure modes.

**Since:** 1.0

**Example:**

```apex
Account account = new SEL_Account().findById(accountId);
if(account == null)
{
    throw new UTIL_Exceptions.NotFoundException('Account does not exist: ' + accountId);
}
```

---

