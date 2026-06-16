---
title: "UTIL_Exceptions.ConfigurationException"
type: class
pageClass: reference
description: "Thrown when required platform configuration is absent or malformed. Typical triggers include missing custom metadata records, unset custom settings, or incompatible configuration values that prevent n"
group: "Utilities"
since: "1.0"
category: apex
---

# UTIL_Exceptions.ConfigurationException

**Class** · Group: `Utilities`

<div class="apex-member apex-class">

```apex
global inherited sharing class UTIL_Exceptions.ConfigurationException
```

Thrown when required platform configuration is absent or malformed. Typical triggers include missing custom metadata records, unset custom settings, or incompatible configuration values that prevent normal operation.

**Example**

```apex
if(credential == null)
{
    throw new UTIL_Exceptions.ConfigurationException('Named credential not found for service: ' + serviceName);
}
```

</div>

---

