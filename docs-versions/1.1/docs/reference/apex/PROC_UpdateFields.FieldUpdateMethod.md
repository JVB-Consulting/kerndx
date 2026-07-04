---
title: "PROC_UpdateFields.FieldUpdateMethod"
type: class
description: "Enum defining methods for updating SObject fields."
since: "1.0"
category: apex
---

# PROC_UpdateFields.FieldUpdateMethod

**Class**

```apex
global enum PROC_UpdateFields.FieldUpdateMethod
```

Enum defining methods for updating SObject fields.

**Since:** 1.0

---

## Values

| Value | Description |
|----------|-------------|
| global [PREFIX](#prefix) | Prepends the provided value to the current field value. |
| global [REPLACE](#replace) | Replaces the field value with the provided value. |
| global [SUFFIX](#suffix) | Appends the provided value to the current field value. |

---

## Value Details

### PREFIX

```apex
global PREFIX
```

Prepends the provided value to the current field value.

### REPLACE

```apex
global REPLACE
```

Replaces the field value with the provided value.

### SUFFIX

```apex
global SUFFIX
```

Appends the provided value to the current field value.

