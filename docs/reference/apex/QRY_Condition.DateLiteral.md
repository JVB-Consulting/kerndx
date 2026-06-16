---
title: "QRY_Condition.DateLiteral"
type: class
description: "Provides SOQL date literal values for use in QRY_Builder conditions. Implements Evaluable so date literals can be passed as condition values to FieldCondition and through the QRY_Builder fluent API. D"
since: "1.0"
category: apex
---

# QRY_Condition.DateLiteral

**Class**

```apex
global inherited sharing class QRY_Condition.DateLiteral implements QRY_Condition.Evaluable
```

**Implements:** [QRY_Condition.Evaluable](QRY_Condition.Evaluable.md)

Provides SOQL date literal values for use in QRY_Builder conditions. Implements Evaluable so date literals can be passed as condition values to FieldCondition and through the QRY_Builder fluent API. Date literals are special SOQL keywords (TODAY, LAST_N_DAYS:30, etc.) that represent relative date/time ranges and cannot be expressed as bind variables.

**Since:** 1.0

**Example:**

```apex
// Records created in the last 30 days
List<Account> accounts = QRY_Builder.selectFrom(Account.SObjectType)
    .condition('CreatedDate').equals(new QRY_Condition.DateLiteral().lastNDays(30))
    .toList();
// Records created today
List<Account> accounts = QRY_Builder.selectFrom(Account.SObjectType)
    .condition('CreatedDate').equals(new QRY_Condition.DateLiteral().today())
    .toList();
```

---

## Methods

| Method | Description |
|--------|-------------|
| global [QRY_Condition.DateLiteral](QRY_Condition.DateLiteral.md) [last](#last)([Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) numberOfUnits, [QRY_Condition.UnitOfTime](QRY_Condition.UnitOfTime.md) unit) | Sets the date literal to LAST_N_*:n. |
| global [QRY_Condition.DateLiteral](QRY_Condition.DateLiteral.md) [last](#last)([QRY_Condition.UnitOfTime](QRY_Condition.UnitOfTime.md) unit) | Sets the date literal to LAST_* for a given unit (e.g., LAST_QUARTER). |
| global [QRY_Condition.DateLiteral](QRY_Condition.DateLiteral.md) [last90Days](#last90days)() | Sets the date literal to LAST_90_DAYS. |
| global [QRY_Condition.DateLiteral](QRY_Condition.DateLiteral.md) [lastNDays](#lastndays)([Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) numberOfDays) | Sets the date literal to LAST_N_DAYS:n. |
| global [QRY_Condition.DateLiteral](QRY_Condition.DateLiteral.md) [next](#next)([Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) numberOfUnits, [QRY_Condition.UnitOfTime](QRY_Condition.UnitOfTime.md) unit) | Sets the date literal to NEXT_N_*:n. |
| global [QRY_Condition.DateLiteral](QRY_Condition.DateLiteral.md) [next](#next)([QRY_Condition.UnitOfTime](QRY_Condition.UnitOfTime.md) unit) | Sets the date literal to NEXT_* for a given unit (e.g., NEXT_QUARTER). |
| global [QRY_Condition.DateLiteral](QRY_Condition.DateLiteral.md) [next90Days](#next90days)() | Sets the date literal to NEXT_90_DAYS. |
| global [QRY_Condition.DateLiteral](QRY_Condition.DateLiteral.md) [nextNDays](#nextndays)([Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) numberOfDays) | Sets the date literal to NEXT_N_DAYS:n. |
| global [QRY_Condition.DateLiteral](QRY_Condition.DateLiteral.md) [thisUnit](#thisunit)([QRY_Condition.UnitOfTime](QRY_Condition.UnitOfTime.md) unit) | Sets the date literal to a THIS_* value for the given unit. |
| global [QRY_Condition.DateLiteral](QRY_Condition.DateLiteral.md) [today](#today)() | Sets the date literal to TODAY. |
| global [QRY_Condition.DateLiteral](QRY_Condition.DateLiteral.md) [tomorrow](#tomorrow)() | Sets the date literal to TOMORROW. |
| global [QRY_Condition.DateLiteral](QRY_Condition.DateLiteral.md) [yesterday](#yesterday)() | Sets the date literal to YESTERDAY. |

---

## Method Details

### last

```apex
global QRY_Condition.DateLiteral last(Integer numberOfUnits, QRY_Condition.UnitOfTime unit)
```

Sets the date literal to LAST_N_*:n.

**Parameters:**

- `numberOfUnits` ([Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm)) - The number of units
- `unit` ([QRY_Condition.UnitOfTime](QRY_Condition.UnitOfTime.md)) - The unit of time

**Returns:** [QRY_Condition.DateLiteral](QRY_Condition.DateLiteral.md) - The DateLiteral instance for method chaining.

**Since:** 1.0

**Example:**

```apex
new QRY_Condition.DateLiteral().last(4, QRY_Condition.UnitOfTime.QUARTER)
```

```apex
global QRY_Condition.DateLiteral last(QRY_Condition.UnitOfTime unit)
```

Sets the date literal to LAST_* for a given unit (e.g., LAST_QUARTER).

**Parameters:**

- `unit` ([QRY_Condition.UnitOfTime](QRY_Condition.UnitOfTime.md)) - The unit of time

**Returns:** [QRY_Condition.DateLiteral](QRY_Condition.DateLiteral.md) - The DateLiteral instance for method chaining.

**Since:** 1.0

**Example:**

```apex
new QRY_Condition.DateLiteral().last(QRY_Condition.UnitOfTime.QUARTER)
```

### last90Days

```apex
global QRY_Condition.DateLiteral last90Days()
```

Sets the date literal to LAST_90_DAYS.

**Returns:** [QRY_Condition.DateLiteral](QRY_Condition.DateLiteral.md) - The DateLiteral instance for method chaining.

**Since:** 1.0

**Example:**

```apex
new QRY_Condition.DateLiteral().last90Days()
```

### lastNDays

```apex
global QRY_Condition.DateLiteral lastNDays(Integer numberOfDays)
```

Sets the date literal to LAST_N_DAYS:n.

**Parameters:**

- `numberOfDays` ([Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm)) - The number of days

**Returns:** [QRY_Condition.DateLiteral](QRY_Condition.DateLiteral.md) - The DateLiteral instance for method chaining.

**Since:** 1.0

**Example:**

```apex
new QRY_Condition.DateLiteral().lastNDays(30)
```

### next

```apex
global QRY_Condition.DateLiteral next(Integer numberOfUnits, QRY_Condition.UnitOfTime unit)
```

Sets the date literal to NEXT_N_*:n.

**Parameters:**

- `numberOfUnits` ([Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm)) - The number of units
- `unit` ([QRY_Condition.UnitOfTime](QRY_Condition.UnitOfTime.md)) - The unit of time

**Returns:** [QRY_Condition.DateLiteral](QRY_Condition.DateLiteral.md) - The DateLiteral instance for method chaining.

**Since:** 1.0

**Example:**

```apex
new QRY_Condition.DateLiteral().next(2, QRY_Condition.UnitOfTime.FISCAL_YEAR)
```

```apex
global QRY_Condition.DateLiteral next(QRY_Condition.UnitOfTime unit)
```

Sets the date literal to NEXT_* for a given unit (e.g., NEXT_QUARTER).

**Parameters:**

- `unit` ([QRY_Condition.UnitOfTime](QRY_Condition.UnitOfTime.md)) - The unit of time

**Returns:** [QRY_Condition.DateLiteral](QRY_Condition.DateLiteral.md) - The DateLiteral instance for method chaining.

**Since:** 1.0

**Example:**

```apex
new QRY_Condition.DateLiteral().next(QRY_Condition.UnitOfTime.QUARTER)
```

### next90Days

```apex
global QRY_Condition.DateLiteral next90Days()
```

Sets the date literal to NEXT_90_DAYS.

**Returns:** [QRY_Condition.DateLiteral](QRY_Condition.DateLiteral.md) - The DateLiteral instance for method chaining.

**Since:** 1.0

**Example:**

```apex
new QRY_Condition.DateLiteral().next90Days()
```

### nextNDays

```apex
global QRY_Condition.DateLiteral nextNDays(Integer numberOfDays)
```

Sets the date literal to NEXT_N_DAYS:n.

**Parameters:**

- `numberOfDays` ([Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm)) - The number of days

**Returns:** [QRY_Condition.DateLiteral](QRY_Condition.DateLiteral.md) - The DateLiteral instance for method chaining.

**Since:** 1.0

**Example:**

```apex
new QRY_Condition.DateLiteral().nextNDays(60)
```

### thisUnit

```apex
global QRY_Condition.DateLiteral thisUnit(QRY_Condition.UnitOfTime unit)
```

Sets the date literal to a THIS_* value for the given unit.

**Parameters:**

- `unit` ([QRY_Condition.UnitOfTime](QRY_Condition.UnitOfTime.md)) - The unit of time

**Returns:** [QRY_Condition.DateLiteral](QRY_Condition.DateLiteral.md) - The DateLiteral instance for method chaining.

**Since:** 1.0

**Example:**

```apex
new QRY_Condition.DateLiteral().thisUnit(QRY_Condition.UnitOfTime.MONTH)
new QRY_Condition.DateLiteral().thisUnit(QRY_Condition.UnitOfTime.DAY)  // returns TODAY
```

### today

```apex
global QRY_Condition.DateLiteral today()
```

Sets the date literal to TODAY.

**Returns:** [QRY_Condition.DateLiteral](QRY_Condition.DateLiteral.md) - The DateLiteral instance for method chaining.

**Since:** 1.0

**Example:**

```apex
new QRY_Condition.DateLiteral().today()
```

### tomorrow

```apex
global QRY_Condition.DateLiteral tomorrow()
```

Sets the date literal to TOMORROW.

**Returns:** [QRY_Condition.DateLiteral](QRY_Condition.DateLiteral.md) - The DateLiteral instance for method chaining.

**Since:** 1.0

**Example:**

```apex
new QRY_Condition.DateLiteral().tomorrow()
```

### yesterday

```apex
global QRY_Condition.DateLiteral yesterday()
```

Sets the date literal to YESTERDAY.

**Returns:** [QRY_Condition.DateLiteral](QRY_Condition.DateLiteral.md) - The DateLiteral instance for method chaining.

**Since:** 1.0

**Example:**

```apex
new QRY_Condition.DateLiteral().yesterday()
```

