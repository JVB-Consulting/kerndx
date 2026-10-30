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

<div class="apex-member apex-class">

```apex
global enum QRY_Condition.Operator
```

SOQL comparison operators used to build query conditions. Operator SOQL Description EQUALS = Equal to NOT_EQUALS != Not equal to LESS_THAN < Less than LESS_THAN_OR_EQUAL_TO <= Less than or equal to GREATER_THAN > Greater than GREATER_THAN_OR_EQUAL_TO >= Greater than or equal to LIKE_X LIKE Pattern matching IN_X IN Value in set NOT_IN NOT IN Value not in set INCLUDES INCLUDES Multi-select picklist includes EXCLUDES EXCLUDES Multi-select picklist excludes

</div>

---

## Inner Classes

| Class | Description |
|-------|-------------|
| [EQUALS](#equals) | The field holds exactly the given value (SOQL =). |
| [EXCLUDES](#excludes) | Multi-select picklist excludes |
| [GREATER_THAN](#greater_than) | The field is larger than the given value (SOQL >); for a date or a time, later. |
| [GREATER_THAN_OR_EQUAL_TO](#greater_than_or_equal_to) | The field is equal to the given value or larger (SOQL >=); for a date or a time, the same or later. |
| [IN_X](#in_x) | The field holds any one of a list of values, or any value a subquery returns (SOQL IN). |
| [INCLUDES](#includes) | Multi-select picklist includes |
| [LESS_THAN](#less_than) | The field is smaller than the given value (SOQL <); for a date or a time, earlier. |
| [LESS_THAN_OR_EQUAL_TO](#less_than_or_equal_to) | The field is equal to the given value or smaller (SOQL <=); for a date or a time, the same or earlier. |
| [LIKE_X](#like_x) | Pattern matching (LIKE) |
| [NOT_EQUALS](#not_equals) | The field does not hold the given value (SOQL !=). |
| [NOT_IN](#not_in) | The field holds none of a list of values, or none of the values a subquery returns (SOQL NOT IN). |

---

## Value Details

### EQUALS

```apex
global EQUALS
```

The field holds exactly the given value (SOQL =). With a null value, the field is blank.

### EXCLUDES

```apex
global EXCLUDES
```

Multi-select picklist excludes

### GREATER_THAN

```apex
global GREATER_THAN
```

The field is larger than the given value (SOQL >); for a date or a time, later.

### GREATER_THAN_OR_EQUAL_TO

```apex
global GREATER_THAN_OR_EQUAL_TO
```

The field is equal to the given value or larger (SOQL >=); for a date or a time, the same or later.

### IN_X

```apex
global IN_X
```

The field holds any one of a list of values, or any value a subquery returns (SOQL IN). The name ends in
_X because IN is a reserved word in Apex.

### INCLUDES

```apex
global INCLUDES
```

Multi-select picklist includes

### LESS_THAN

```apex
global LESS_THAN
```

The field is smaller than the given value (SOQL <); for a date or a time, earlier.

### LESS_THAN_OR_EQUAL_TO

```apex
global LESS_THAN_OR_EQUAL_TO
```

The field is equal to the given value or smaller (SOQL <=); for a date or a time, the same or earlier.

### LIKE_X

```apex
global LIKE_X
```

Pattern matching (LIKE)

### NOT_EQUALS

```apex
global NOT_EQUALS
```

The field does not hold the given value (SOQL !=). With a null value, the field has a value.

### NOT_IN

```apex
global NOT_IN
```

The field holds none of a list of values, or none of the values a subquery returns (SOQL NOT IN).

