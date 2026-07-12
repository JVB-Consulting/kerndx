---
title: "UTIL_Exceptions.IllegalStateException"
type: class
pageClass: reference
description: "Thrown when an operation is attempted on an object whose internal state does not support that operation. Use this to enforce lifecycle constraints such as calling methods out of order or re-entering a"
group: "Utilities"
since: "1.0"
category: apex
---

# UTIL_Exceptions.IllegalStateException

**Class** · Group: `Utilities`

<div class="apex-member apex-class">

```apex
global inherited sharing class UTIL_Exceptions.IllegalStateException
```

Thrown when an operation is attempted on an object whose internal state does not support that operation. Use this to enforce lifecycle constraints such as calling methods out of order or re-entering a finalised workflow.

**Example**

```apex
if(isFinished)
{
    throw new UTIL_Exceptions.IllegalStateException('Transaction has already been committed.');
}
```

</div>

---

