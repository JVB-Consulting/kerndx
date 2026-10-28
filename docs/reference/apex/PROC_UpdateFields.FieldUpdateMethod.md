---
title: "PROC_UpdateFields.FieldUpdateMethod"
type: class
pageClass: reference
description: "Enum defining methods for updating SObject fields."
since: "1.0"
category: apex
---

# PROC_UpdateFields.FieldUpdateMethod

**Class**

<div class="apex-member apex-class">

```apex
global enum PROC_UpdateFields.FieldUpdateMethod
```

Enum defining methods for updating SObject fields.

</div>

---

## Inner Classes

| Class | Description |
|-------|-------------|
| [PREFIX](#prefix) | Prepends the provided value to the current field value. |
| [REPLACE](#replace) | The new value is written as it is and the current value is not kept, so a null value clears the field. |
| [SUFFIX](#suffix) | Appends the provided value to the current field value. |

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

The new value is written as it is and the current value is not kept, so a null value clears
the field. This is the default.

### SUFFIX

```apex
global SUFFIX
```

Appends the provided value to the current field value.

