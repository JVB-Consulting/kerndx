---
title: "QRY_Condition.Operator"
type: class
pageClass: reference
description: "SOQL comparison operators used to build query conditions. Operator SOQL Description EQUALS = Equal to NOT_EQUALS != Not equal to LESS_THAN < Less than LESS_THAN_OR_EQUAL_TO <= Less than or equal to GR"
since: "1.0"
category: apex
---

# QRY_Condition.Operator

**Class**

```apex
global enum QRY_Condition.Operator
```

SOQL comparison operators used to build query conditions. Operator SOQL Description EQUALS = Equal to NOT_EQUALS != Not equal to LESS_THAN < Less than LESS_THAN_OR_EQUAL_TO <= Less than or equal to GREATER_THAN > Greater than GREATER_THAN_OR_EQUAL_TO >= Greater than or equal to LIKE_X LIKE Pattern matching IN_X IN Value in set NOT_IN NOT IN Value not in set INCLUDES INCLUDES Multi-select picklist includes EXCLUDES EXCLUDES Multi-select picklist excludes

**Since:** 1.0

---

## Values

| Value | Description |
|----------|-------------|
| global  [EQUALS](#equals) | Equal to (=) |
| global  [EXCLUDES](#excludes) | Multi-select picklist excludes |
| global  [GREATER_THAN](#greater_than) | Greater than (>) |
| global  [GREATER_THAN_OR_EQUAL_TO](#greater_than_or_equal_to) | Greater than or equal to (>=) |
| global  [IN_X](#in_x) | Value in set (IN) |
| global  [INCLUDES](#includes) | Multi-select picklist includes |
| global  [LESS_THAN](#less_than) | Less than (<) |
| global  [LESS_THAN_OR_EQUAL_TO](#less_than_or_equal_to) | Less than or equal to (<=) |
| global  [LIKE_X](#like_x) | Pattern matching (LIKE) |
| global  [NOT_EQUALS](#not_equals) | Not equal to (!=) |
| global  [NOT_IN](#not_in) | Value not in set (NOT IN) |

---

## Value Details

### EQUALS

```apex
global EQUALS
```

Equal to (=)

### EXCLUDES

```apex
global EXCLUDES
```

Multi-select picklist excludes

### GREATER_THAN

```apex
global GREATER_THAN
```

Greater than (>)

### GREATER_THAN_OR_EQUAL_TO

```apex
global GREATER_THAN_OR_EQUAL_TO
```

Greater than or equal to (>=)

### IN_X

```apex
global IN_X
```

Value in set (IN)

### INCLUDES

```apex
global INCLUDES
```

Multi-select picklist includes

### LESS_THAN

```apex
global LESS_THAN
```

Less than (<)

### LESS_THAN_OR_EQUAL_TO

```apex
global LESS_THAN_OR_EQUAL_TO
```

Less than or equal to (<=)

### LIKE_X

```apex
global LIKE_X
```

Pattern matching (LIKE)

### NOT_EQUALS

```apex
global NOT_EQUALS
```

Not equal to (!=)

### NOT_IN

```apex
global NOT_IN
```

Value not in set (NOT IN)

