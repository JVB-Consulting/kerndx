---
title: "TRG_Base.BypassType"
type: class
description: "Indicates the type of trigger bypass being applied."
since: "1.0"
category: apex
---

# TRG_Base.BypassType

**Class**

```apex
global enum TRG_Base.BypassType
```

Indicates the type of trigger bypass being applied.

**Since:** 1.0

---

## Values

| Value | Description |
|----------|-------------|
| global  [CLASS_NAME](#class_name) | Bypass a specific trigger action class by class name. |
| global  [OBJECT_NAME](#object_name) | Bypass all triggers for a specific SObject by object API name. |

---

## Value Details

### CLASS_NAME

```apex
global CLASS_NAME
```

Bypass a specific trigger action class by class name.

### OBJECT_NAME

```apex
global OBJECT_NAME
```

Bypass all triggers for a specific SObject by object API name.

