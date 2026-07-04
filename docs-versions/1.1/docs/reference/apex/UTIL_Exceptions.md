---
title: "UTIL_Exceptions"
type: class
description: "Centralised container for framework-specific exception types. Groups related exception classes under a single outer class to minimise top-level file count while keeping each exception independently re"
author: "Jason Van Beukering"
group: "Utilities"
date: "February 2026, May 2026"
since: "1.0"
category: apex
---

# UTIL_Exceptions

**Class** · Group: `Utilities`

```apex
global inherited sharing class UTIL_Exceptions
```

Centralised container for framework-specific exception types. Groups related exception classes under a single outer class to minimise top-level file count while keeping each exception independently referenceable.

**Since:** 1.0

**Example:**

```apex
if(config == null)
{
    throw new UTIL_Exceptions.ConfigurationException('Missing required configuration.');
}
```

---

## Inner Classes

| Class | Description |
|-------|-------------|
| [ConfigurationException](UTIL_Exceptions.ConfigurationException.md) | Thrown when required platform configuration is absent or malformed. |
| [IllegalStateException](UTIL_Exceptions.IllegalStateException.md) | Thrown when an operation is attempted on an object whose internal state does not support that operation. |
| [MaskingBlockedException](UTIL_Exceptions.MaskingBlockedException.md) | Thrown when a masking rule configured with FailureAction__c = BlockDml fails. |
| [NotFoundException](UTIL_Exceptions.NotFoundException.md) | Thrown when a lookup for a specific record or resource yields no results. |

