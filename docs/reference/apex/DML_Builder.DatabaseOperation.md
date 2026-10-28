---
title: "DML_Builder.DatabaseOperation"
type: class
pageClass: reference
description: "Enum to specify the type of DML operation for external use."
since: "1.0"
category: apex
---

# DML_Builder.DatabaseOperation

**Class**

<div class="apex-member apex-class">

```apex
global enum DML_Builder.DatabaseOperation
```

Enum to specify the type of DML operation for external use.

</div>

---

## Inner Classes

| Class | Description |
|-------|-------------|
| [DML_DELETE](#dml_delete) | Remove records that already exist, found by their Id. |
| [DML_INSERT](#dml_insert) | Create records that are not in the database yet. |
| [DML_UNDELETE](#dml_undelete) | Bring back records that were deleted, found by their Id. |
| [DML_UPDATE](#dml_update) | Save changes to records that already exist. |
| [DML_UPSERT](#dml_upsert) | Create each record that does not exist yet and update each one that does. |

---

## Value Details

### DML_DELETE

```apex
global DML_DELETE
```

Remove records that already exist, found by their Id. DML_UNDELETE can bring them back.

### DML_INSERT

```apex
global DML_INSERT
```

Create records that are not in the database yet.

### DML_UNDELETE

```apex
global DML_UNDELETE
```

Bring back records that were deleted, found by their Id.

### DML_UPDATE

```apex
global DML_UPDATE
```

Save changes to records that already exist. Each record is found by its Id.

### DML_UPSERT

```apex
global DML_UPSERT
```

Create each record that does not exist yet and update each one that does.
Records are matched by Id, or by an external ID field when one is given.

