---
title: "UTIL_Email.DeliverabilityAccessLevel"
type: class
pageClass: reference
description: "Enum representing the three possible email deliverability settings in a Salesforce org."
since: "1.0"
category: apex
---

# UTIL_Email.DeliverabilityAccessLevel

**Class**

```apex
global enum UTIL_Email.DeliverabilityAccessLevel
```

Enum representing the three possible email deliverability settings in a Salesforce org.

**Since:** 1.0

---

## Values

| Value | Description |
|----------|-------------|
| global  [ALL_EMAIL](#all_email) | All outbound email — user-initiated and Apex — is permitted. |
| global  [NO_ACCESS](#no_access) | No outbound email is permitted. |
| global  [SYSTEM_EMAIL_ONLY](#system_email_only) | Only system-generated email (e.g., password resets) is permitted. |

---

## Value Details

### ALL_EMAIL

```apex
global ALL_EMAIL
```

All outbound email — user-initiated and Apex — is permitted.

### NO_ACCESS

```apex
global NO_ACCESS
```

No outbound email is permitted.

### SYSTEM_EMAIL_ONLY

```apex
global SYSTEM_EMAIL_ONLY
```

Only system-generated email (e.g., password resets) is permitted.

