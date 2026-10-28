---
title: "QRY_Condition.DateLiteral"
type: class
pageClass: reference
description: "Provides SOQL date literal values for use in QRY_Builder conditions. Implements Evaluable so date literals can be passed as condition values to FieldCondition and through the QRY_Builder fluent API. D"
since: "1.0"
category: apex
---

# QRY_Condition.DateLiteral

**Class**

<div class="apex-member apex-class">

```apex
global inherited sharing class QRY_Condition.DateLiteral implements QRY_Condition.Evaluable
```

**Implements:** [QRY_Condition.Evaluable](QRY_Condition.Evaluable.md)

Provides SOQL date literal values for use in QRY_Builder conditions. Implements Evaluable so date literals can be passed as condition values to FieldCondition and through the QRY_Builder fluent API. Date literals are special SOQL keywords (TODAY, LAST_N_DAYS:30, etc.) that represent relative date/time ranges and cannot be expressed as bind variables.

**Example**

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

</div>

---

## Methods

| Method | Description |
|--------|-------------|
| global [QRY_Condition.DateLiteral](QRY_Condition.DateLiteral.md) [last](#last)([Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) numberOfUnits, [QRY_Condition.UnitOfTime](QRY_Condition.UnitOfTime.md) unit) | Sets the date literal to LAST_N_*:n. |
| global [QRY_Condition.DateLiteral](QRY_Condition.DateLiteral.md) [last](#last)([QRY_Condition.UnitOfTime](QRY_Condition.UnitOfTime.md) unit) | Sets the date literal to LAST_* for a given unit (e.g., LAST_QUARTER). |
| global [QRY_Condition.DateLiteral](QRY_Condition.DateLiteral.md) [last90Days](#last90days)() | Matches today and the 90 days before it, with the SOQL keyword LAST_90_DAYS. |
| global [QRY_Condition.DateLiteral](QRY_Condition.DateLiteral.md) [lastNDays](#lastndays)([Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) numberOfDays) | Matches today and the n days before it, written as LAST_N_DAYS:n (lastNDays(30) writes LAST_N_DAYS:30). |
| global [QRY_Condition.DateLiteral](QRY_Condition.DateLiteral.md) [next](#next)([Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) numberOfUnits, [QRY_Condition.UnitOfTime](QRY_Condition.UnitOfTime.md) unit) | Sets the date literal to NEXT_N_*:n. |
| global [QRY_Condition.DateLiteral](QRY_Condition.DateLiteral.md) [next](#next)([QRY_Condition.UnitOfTime](QRY_Condition.UnitOfTime.md) unit) | Sets the date literal to NEXT_* for a given unit (e.g., NEXT_QUARTER). |
| global [QRY_Condition.DateLiteral](QRY_Condition.DateLiteral.md) [next90Days](#next90days)() | Matches the next 90 days, starting tomorrow, with the SOQL keyword NEXT_90_DAYS. |
| global [QRY_Condition.DateLiteral](QRY_Condition.DateLiteral.md) [nextNDays](#nextndays)([Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) numberOfDays) | Matches the next n days, starting tomorrow, written as NEXT_N_DAYS:n (nextNDays(60) writes NEXT_N_DAYS:60). |
| global [QRY_Condition.DateLiteral](QRY_Condition.DateLiteral.md) [thisUnit](#thisunit)([QRY_Condition.UnitOfTime](QRY_Condition.UnitOfTime.md) unit) | Matches the current week, month, quarter, year, fiscal quarter or fiscal year, written as THIS_ and the unit name, such as THIS_MONTH. |
| global [QRY_Condition.DateLiteral](QRY_Condition.DateLiteral.md) [today](#today)() | Matches the whole of today, with the SOQL keyword TODAY. |
| global [QRY_Condition.DateLiteral](QRY_Condition.DateLiteral.md) [tomorrow](#tomorrow)() | Matches the whole of the day after today, with the SOQL keyword TOMORROW. |
| global [QRY_Condition.DateLiteral](QRY_Condition.DateLiteral.md) [yesterday](#yesterday)() | Matches the whole of the day before today, with the SOQL keyword YESTERDAY. |

### last

<div class="apex-member">

```apex
global QRY_Condition.DateLiteral last(Integer numberOfUnits, QRY_Condition.UnitOfTime unit)
```

Sets the date literal to LAST_N_*:n.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `numberOfUnits` | [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) | The number of units |
| `unit` | [QRY_Condition.UnitOfTime](QRY_Condition.UnitOfTime.md) | The unit of time |

**Returns** [QRY_Condition.DateLiteral](QRY_Condition.DateLiteral.md) — The DateLiteral instance for method chaining.

**Example**

```apex
new QRY_Condition.DateLiteral().last(4, QRY_Condition.UnitOfTime.QUARTER)
```

</div>

<div class="apex-member">

```apex
global QRY_Condition.DateLiteral last(QRY_Condition.UnitOfTime unit)
```

Sets the date literal to LAST_* for a given unit (e.g., LAST_QUARTER).

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `unit` | [QRY_Condition.UnitOfTime](QRY_Condition.UnitOfTime.md) | The unit of time |

**Returns** [QRY_Condition.DateLiteral](QRY_Condition.DateLiteral.md) — The DateLiteral instance for method chaining.

**Example**

```apex
new QRY_Condition.DateLiteral().last(QRY_Condition.UnitOfTime.QUARTER)
```

</div>

### last90Days

<div class="apex-member">

```apex
global QRY_Condition.DateLiteral last90Days()
```

Matches today and the 90 days before it, with the SOQL keyword LAST_90_DAYS. lastNDays(90)
writes the same keyword.

**Returns** [QRY_Condition.DateLiteral](QRY_Condition.DateLiteral.md) — The DateLiteral instance for method chaining.

**Example**

```apex
new QRY_Condition.DateLiteral().last90Days()
```

</div>

### lastNDays

<div class="apex-member">

```apex
global QRY_Condition.DateLiteral lastNDays(Integer numberOfDays)
```

Matches today and the n days before it, written as LAST_N_DAYS:n (lastNDays(30) writes
LAST_N_DAYS:30). For 90 it writes LAST_90_DAYS. A negative number throws IllegalArgumentException.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `numberOfDays` | [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) | The number of days |

**Returns** [QRY_Condition.DateLiteral](QRY_Condition.DateLiteral.md) — The DateLiteral instance for method chaining.

**Example**

```apex
new QRY_Condition.DateLiteral().lastNDays(30)
```

</div>

### next

<div class="apex-member">

```apex
global QRY_Condition.DateLiteral next(Integer numberOfUnits, QRY_Condition.UnitOfTime unit)
```

Sets the date literal to NEXT_N_*:n.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `numberOfUnits` | [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) | The number of units |
| `unit` | [QRY_Condition.UnitOfTime](QRY_Condition.UnitOfTime.md) | The unit of time |

**Returns** [QRY_Condition.DateLiteral](QRY_Condition.DateLiteral.md) — The DateLiteral instance for method chaining.

**Example**

```apex
new QRY_Condition.DateLiteral().next(2, QRY_Condition.UnitOfTime.FISCAL_YEAR)
```

</div>

<div class="apex-member">

```apex
global QRY_Condition.DateLiteral next(QRY_Condition.UnitOfTime unit)
```

Sets the date literal to NEXT_* for a given unit (e.g., NEXT_QUARTER).

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `unit` | [QRY_Condition.UnitOfTime](QRY_Condition.UnitOfTime.md) | The unit of time |

**Returns** [QRY_Condition.DateLiteral](QRY_Condition.DateLiteral.md) — The DateLiteral instance for method chaining.

**Example**

```apex
new QRY_Condition.DateLiteral().next(QRY_Condition.UnitOfTime.QUARTER)
```

</div>

### next90Days

<div class="apex-member">

```apex
global QRY_Condition.DateLiteral next90Days()
```

Matches the next 90 days, starting tomorrow, with the SOQL keyword NEXT_90_DAYS. nextNDays(90) writes the
same keyword.

**Returns** [QRY_Condition.DateLiteral](QRY_Condition.DateLiteral.md) — The DateLiteral instance for method chaining.

**Example**

```apex
new QRY_Condition.DateLiteral().next90Days()
```

</div>

### nextNDays

<div class="apex-member">

```apex
global QRY_Condition.DateLiteral nextNDays(Integer numberOfDays)
```

Matches the next n days, starting tomorrow, written as NEXT_N_DAYS:n (nextNDays(60) writes
NEXT_N_DAYS:60). For 90 it writes NEXT_90_DAYS. A negative number throws IllegalArgumentException.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `numberOfDays` | [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) | The number of days |

**Returns** [QRY_Condition.DateLiteral](QRY_Condition.DateLiteral.md) — The DateLiteral instance for method chaining.

**Example**

```apex
new QRY_Condition.DateLiteral().nextNDays(60)
```

</div>

### thisUnit

<div class="apex-member">

```apex
global QRY_Condition.DateLiteral thisUnit(QRY_Condition.UnitOfTime unit)
```

Matches the current week, month, quarter, year, fiscal quarter or fiscal year, written as THIS_ and the
unit name, such as THIS_MONTH. DAY gives TODAY, because SOQL has no THIS_DAY. A null unit throws a
NullPointerException.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `unit` | [QRY_Condition.UnitOfTime](QRY_Condition.UnitOfTime.md) | The unit of time |

**Returns** [QRY_Condition.DateLiteral](QRY_Condition.DateLiteral.md) — The DateLiteral instance for method chaining.

**Example**

```apex
new QRY_Condition.DateLiteral().thisUnit(QRY_Condition.UnitOfTime.MONTH)
new QRY_Condition.DateLiteral().thisUnit(QRY_Condition.UnitOfTime.DAY)  // returns TODAY
```

</div>

### today

<div class="apex-member">

```apex
global QRY_Condition.DateLiteral today()
```

Matches the whole of today, with the SOQL keyword TODAY. Pass the result as a condition value, for
example to equals(). It replaces any date set earlier on this object.

**Returns** [QRY_Condition.DateLiteral](QRY_Condition.DateLiteral.md) — The DateLiteral instance for method chaining.

**Example**

```apex
new QRY_Condition.DateLiteral().today()
```

</div>

### tomorrow

<div class="apex-member">

```apex
global QRY_Condition.DateLiteral tomorrow()
```

Matches the whole of the day after today, with the SOQL keyword TOMORROW. Pass the result as a condition
value, for example to equals(). It replaces any date set earlier on this object.

**Returns** [QRY_Condition.DateLiteral](QRY_Condition.DateLiteral.md) — The DateLiteral instance for method chaining.

**Example**

```apex
new QRY_Condition.DateLiteral().tomorrow()
```

</div>

### yesterday

<div class="apex-member">

```apex
global QRY_Condition.DateLiteral yesterday()
```

Matches the whole of the day before today, with the SOQL keyword YESTERDAY. Pass the result as a
condition value, for example to equals(). It replaces any date set earlier on this object.

**Returns** [QRY_Condition.DateLiteral](QRY_Condition.DateLiteral.md) — The DateLiteral instance for method chaining.

**Example**

```apex
new QRY_Condition.DateLiteral().yesterday()
```

</div>

