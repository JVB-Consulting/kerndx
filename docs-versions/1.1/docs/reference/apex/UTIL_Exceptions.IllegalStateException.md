---
title: "UTIL_Exceptions.IllegalStateException"
type: class
description: "Thrown when an operation is attempted on an object whose internal state does not support that operation. Use this to enforce lifecycle constraints such as calling methods out of order or re-entering a"
group: "Utilities"
since: "1.0"
category: apex
---

# UTIL_Exceptions.IllegalStateException

**Class** · Group: `Utilities`

```apex
global inherited sharing class UTIL_Exceptions.IllegalStateException
```

Thrown when an operation is attempted on an object whose internal state does not support that operation. Use this to enforce lifecycle constraints such as calling methods out of order or re-entering a finalised workflow.

**Since:** 1.0

**Example:**

```apex
if(isFinished)
{
    throw new UTIL_Exceptions.IllegalStateException('Transaction has already been committed.');
}
```

---

