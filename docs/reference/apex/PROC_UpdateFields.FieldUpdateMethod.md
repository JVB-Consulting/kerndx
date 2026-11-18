---
title: "PROC_UpdateFields.FieldUpdateMethod"
type: class
pageClass: reference
description: "Enum defining methods for updating SObject fields."
group: "Bulk DML"
since: "1.0"
category: apex
---

# PROC_UpdateFields.FieldUpdateMethod

**Class** · Group: `Bulk DML`

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
| [COPY_FROM_FIELD](#copy_from_field) | Copies another field of the same row into the field. |
| [PREFIX](#prefix) | Prepends the provided value to the current field value. |
| [REPLACE](#replace) | The new value is written as it is and the current value is not kept, so a null value clears the field. |
| [SUFFIX](#suffix) | Appends the provided value to the current field value. |

---

## Value Details

### COPY_FROM_FIELD

```apex
global COPY_FROM_FIELD
```

Copies another field of the same row into the field. Here the value is not written itself: it is
the API name of the field to copy from, the source field. Each row gets its own source value. The field must
be able to take the source value: when Salesforce will not put the source value into the field, for example a
decimal number into a whole number field, the error stops the whole chunk of rows and none of them is saved.
UTIL_BulkUpdates.copyField refuses such pairs before it starts the job. Field lengths are not checked: a
value too long for the field fails its row when the row is saved.

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

