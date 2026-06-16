---
title: "UTIL_Exceptions.MaskingBlockedException"
type: class
pageClass: reference
description: "Thrown when a masking rule configured with FailureAction__c = BlockDml fails. Propagates out of UTIL_FrameworkMasker.RecordMasker.apply and (via the trigger dispatcher pre-step) the surrounding DML so"
group: "Data Masking"
since: "1.0"
category: apex
---

# UTIL_Exceptions.MaskingBlockedException

**Class** · Group: `Data Masking`

```apex
global inherited sharing class UTIL_Exceptions.MaskingBlockedException
```

Thrown when a masking rule configured with FailureAction__c = BlockDml fails. Propagates out of UTIL_FrameworkMasker.RecordMasker.apply and (via the trigger dispatcher pre-step) the surrounding DML so the record is never persisted with sensitive data that could not be reliably redacted. Subscribers catch this type to detect that the framework aborted a write because masking could not complete safely.

**Since:** 1.0

**Example:**

```apex
try
{
    insert account;
}
catch(UTIL_Exceptions.MaskingBlockedException blocked)
{
    handleMaskingFailure(blocked);
}
```

---

