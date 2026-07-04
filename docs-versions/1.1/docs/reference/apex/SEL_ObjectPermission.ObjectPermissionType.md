---
title: "SEL_ObjectPermission.ObjectPermissionType"
type: class
description: "A Permission that a User might have on a SObjectType."
since: "1.0"
category: apex
---

# SEL_ObjectPermission.ObjectPermissionType

**Class**

```apex
global enum SEL_ObjectPermission.ObjectPermissionType
```

A Permission that a User might have on a SObjectType.

**Since:** 1.0

---

## Values

| Value | Description |
|----------|-------------|
| global [CREATE](#create) | User can create new object (of a given type). |
| global [DEL](#del) | User can delete an existing object (of a given type). |
| global [EDIT](#edit) | User can edit an existing object (of a given type). |
| global [MODIFY_ALL](#modify_all) | User can edit all existing objects (of a given type). |
| global [READ](#read) | User can view/read an existing object (of a given type). |
| global [VIEW_ALL](#view_all) | User can view/read all existing objects (of a given type). |

---

## Value Details

### CREATE

```apex
global CREATE
```

User can create new object (of a given type).

### DEL

```apex
global DEL
```

User can delete an existing object (of a given type). Delete is a reserved word, hence the abbreviation.

### EDIT

```apex
global EDIT
```

User can edit an existing object (of a given type).

### MODIFY_ALL

```apex
global MODIFY_ALL
```

User can edit all existing objects (of a given type).

### READ

```apex
global READ
```

User can view/read an existing object (of a given type).

### VIEW_ALL

```apex
global VIEW_ALL
```

User can view/read all existing objects (of a given type).

