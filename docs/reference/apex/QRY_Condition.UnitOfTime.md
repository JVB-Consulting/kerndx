---
title: "QRY_Condition.UnitOfTime"
type: class
pageClass: reference
description: "Units of time for SOQL date literals."
since: "1.0"
category: apex
---

# QRY_Condition.UnitOfTime

**Class**

```apex
global enum QRY_Condition.UnitOfTime
```

Units of time for SOQL date literals.

**Since:** 1.0

---

## Values

| Value | Description |
|----------|-------------|
| global  [DAY](#day) | Day unit (LAST_N_DAYS, NEXT_N_DAYS, etc.) |
| global  [FISCAL_QUARTER](#fiscal_quarter) | Fiscal quarter unit (LAST_N_FISCAL_QUARTERS, etc.) |
| global  [FISCAL_YEAR](#fiscal_year) | Fiscal year unit (LAST_N_FISCAL_YEARS, etc.) |
| global  [MONTH](#month) | Month unit (THIS_MONTH, LAST_MONTH - not supported with N) |
| global  [QUARTER](#quarter) | Quarter unit (LAST_N_QUARTERS, etc.) |
| global  [WEEK](#week) | Week unit (THIS_WEEK, LAST_WEEK - not supported with N) |
| global  [YEAR](#year) | Year unit (LAST_N_YEARS, etc.) |

---

## Value Details

### DAY

```apex
global DAY
```

Day unit (LAST_N_DAYS, NEXT_N_DAYS, etc.)

### FISCAL_QUARTER

```apex
global FISCAL_QUARTER
```

Fiscal quarter unit (LAST_N_FISCAL_QUARTERS, etc.)

### FISCAL_YEAR

```apex
global FISCAL_YEAR
```

Fiscal year unit (LAST_N_FISCAL_YEARS, etc.)

### MONTH

```apex
global MONTH
```

Month unit (THIS_MONTH, LAST_MONTH - not supported with N)

### QUARTER

```apex
global QUARTER
```

Quarter unit (LAST_N_QUARTERS, etc.)

### WEEK

```apex
global WEEK
```

Week unit (THIS_WEEK, LAST_WEEK - not supported with N)

### YEAR

```apex
global YEAR
```

Year unit (LAST_N_YEARS, etc.)

