---
title: "QRY_Function"
type: class
pageClass: reference
description: "Typed SOQL function expressions for use in the query builder's SELECT, GROUP BY, WHERE and ORDER BY clauses: the date-part functions (CALENDAR_MONTH, DAY_IN_MONTH, FISCAL_QUARTER, ...) and the geoloca"
author: "Jason Van Beukering"
group: "Query Infrastructure"
date: "June 2026"
since: "1.1"
category: apex
---

# QRY_Function

**Class** · Group: `Query Infrastructure`

<div class="apex-member apex-class">

```apex
global inherited sharing class QRY_Function
```

Typed SOQL function expressions for use in the query builder's SELECT, GROUP BY, WHERE and ORDER BY clauses: the date-part functions (CALENDAR_MONTH, DAY_IN_MONTH, FISCAL_QUARTER, ...) and the geolocation DISTANCE function. One static factory per function; the returned value is an immutable carrier that resolves its wrapped field name once and renders to a finished SOQL expression, so the builder can project, group, filter and sort by the same expression from a single source without hand-spelling raw SOQL. Use the factories with the matching QRY_Builder.Builder overloads: addField, groupBy and orderBy to bucket records by a date part for reporting, and condition (WHERE) together with the geolocation distance factories for proximity filtering and nearest-first ordering.

**Example**

```apex
List<QRY_Builder.AggregateRow> rows = QRY_Builder.selectFrom(Opportunity.SObjectType)
    .addField(QRY_Function.calendarMonth(Opportunity.CloseDate), 'closeMonth')
    .count('Id')
    .groupBy(QRY_Function.calendarMonth(Opportunity.CloseDate))
    .orderBy(QRY_Function.calendarMonth(Opportunity.CloseDate))
    .toAggregateList();
for(QRY_Builder.AggregateRow row : rows)
{
    Integer month = row.getInteger('closeMonth');
    Integer total = row.getInteger('count_Id');
}
```

**See Also:** [QRY_Builder](QRY_Builder.md)

</div>

---

## Methods

| Method | Description |
|--------|-------------|
| global static [QRY_Function](QRY_Function.md) [calendarMonth](#calendarmonth)([SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm) field) | Wraps a date/datetime field in CALENDAR_MONTH (1–12 in the calendar year). |
| global static [QRY_Function](QRY_Function.md) [calendarQuarter](#calendarquarter)([SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm) field) | Wraps a date/datetime field in CALENDAR_QUARTER (1–4 in the calendar year). |
| global static [QRY_Function](QRY_Function.md) [calendarYear](#calendaryear)([SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm) field) | Wraps a date/datetime field in CALENDAR_YEAR (the four-digit calendar year). |
| global static [QRY_Function](QRY_Function.md) [dayInMonth](#dayinmonth)([SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm) field) | Wraps a date/datetime field in DAY_IN_MONTH (1–31). |
| global static [QRY_Function](QRY_Function.md) [dayInWeek](#dayinweek)([SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm) field) | Wraps a date/datetime field in DAY_IN_WEEK (1 for Sunday through 7 for Saturday). |
| global static [QRY_Function](QRY_Function.md) [dayInYear](#dayinyear)([SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm) field) | Wraps a date/datetime field in DAY_IN_YEAR (1–366). |
| global static [QRY_Function](QRY_Function.md) [dayOnly](#dayonly)([SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm) field) | Wraps a datetime field in DAY_ONLY, returning the date with the time component dropped. |
| global static [QRY_Function](QRY_Function.md) [distanceInKilometers](#distanceinkilometers)([SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm) field, [Decimal](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_decimal.htm) latitude, [Decimal](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_decimal.htm) longitude) | Wraps a geolocation or compound address field in the SOQL DISTANCE function, measuring the straight-line distance in kilometres from each record to a fixed reference point. |
| global static [QRY_Function](QRY_Function.md) [distanceInKilometers](#distanceinkilometers)([SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm) field, [System.Location](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_system_Location.htm) location) | Wraps a geolocation or compound address field in the SOQL DISTANCE function, measuring the straight-line distance in kilometres to a System.Location reference point. |
| global static [QRY_Function](QRY_Function.md) [distanceInMiles](#distanceinmiles)([SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm) field, [Decimal](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_decimal.htm) latitude, [Decimal](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_decimal.htm) longitude) | Wraps a geolocation or compound address field in the SOQL DISTANCE function, measuring the straight-line distance in statute miles from each record to a fixed reference point. |
| global static [QRY_Function](QRY_Function.md) [distanceInMiles](#distanceinmiles)([SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm) field, [System.Location](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_system_Location.htm) location) | Wraps a geolocation or compound address field in the SOQL DISTANCE function, measuring the straight-line distance in statute miles to a System.Location reference point. |
| global static [QRY_Function](QRY_Function.md) [fiscalMonth](#fiscalmonth)([SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm) field) | Wraps a date/datetime field in FISCAL_MONTH (1–12 within the org's fiscal year). |
| global static [QRY_Function](QRY_Function.md) [fiscalQuarter](#fiscalquarter)([SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm) field) | Wraps a date/datetime field in FISCAL_QUARTER (1–4 within the org's fiscal year). |
| global static [QRY_Function](QRY_Function.md) [fiscalYear](#fiscalyear)([SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm) field) | Wraps a date/datetime field in FISCAL_YEAR (the org's fiscal year). |
| global static [QRY_Function](QRY_Function.md) [hourInDay](#hourinday)([SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm) field) | Wraps a datetime field in HOUR_IN_DAY (0–23, in the running user's time zone). |
| global static [QRY_Function](QRY_Function.md) [weekInMonth](#weekinmonth)([SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm) field) | Wraps a date/datetime field in WEEK_IN_MONTH (1–6). |
| global static [QRY_Function](QRY_Function.md) [weekInYear](#weekinyear)([SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm) field) | Wraps a date/datetime field in WEEK_IN_YEAR (1–53). |

### calendarMonth

<div class="apex-member">

```apex
global static QRY_Function calendarMonth(SObjectField field)
```

Wraps a date/datetime field in CALENDAR_MONTH (1–12 in the calendar year).

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `field` | [SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm) | The date or datetime field to bucket. |

**Returns** [QRY_Function](QRY_Function.md) — A QRY_Function carrying CALENDAR_MONTH(field) for use in SELECT, GROUP BY or ORDER BY.

**Example**

```apex
.groupBy(QRY_Function.calendarMonth(Opportunity.CloseDate))
```

</div>

### calendarQuarter

<div class="apex-member">

```apex
global static QRY_Function calendarQuarter(SObjectField field)
```

Wraps a date/datetime field in CALENDAR_QUARTER (1–4 in the calendar year).

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `field` | [SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm) | The date or datetime field to bucket. |

**Returns** [QRY_Function](QRY_Function.md) — A QRY_Function carrying CALENDAR_QUARTER(field) for use in SELECT, GROUP BY or ORDER BY.

**Example**

```apex
.groupBy(QRY_Function.calendarQuarter(Opportunity.CloseDate))
```

</div>

### calendarYear

<div class="apex-member">

```apex
global static QRY_Function calendarYear(SObjectField field)
```

Wraps a date/datetime field in CALENDAR_YEAR (the four-digit calendar year).

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `field` | [SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm) | The date or datetime field to bucket. |

**Returns** [QRY_Function](QRY_Function.md) — A QRY_Function carrying CALENDAR_YEAR(field) for use in SELECT, GROUP BY or ORDER BY.

**Example**

```apex
.groupBy(QRY_Function.calendarYear(Opportunity.CloseDate))
```

</div>

### dayInMonth

<div class="apex-member">

```apex
global static QRY_Function dayInMonth(SObjectField field)
```

Wraps a date/datetime field in DAY_IN_MONTH (1–31).

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `field` | [SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm) | The date or datetime field to bucket. |

**Returns** [QRY_Function](QRY_Function.md) — A QRY_Function carrying DAY_IN_MONTH(field) for use in SELECT, GROUP BY or ORDER BY.

**Example**

```apex
.groupBy(QRY_Function.dayInMonth(Opportunity.CloseDate))
```

</div>

### dayInWeek

<div class="apex-member">

```apex
global static QRY_Function dayInWeek(SObjectField field)
```

Wraps a date/datetime field in DAY_IN_WEEK (1 for Sunday through 7 for Saturday).

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `field` | [SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm) | The date or datetime field to bucket. |

**Returns** [QRY_Function](QRY_Function.md) — A QRY_Function carrying DAY_IN_WEEK(field) for use in SELECT, GROUP BY or ORDER BY.

**Example**

```apex
.groupBy(QRY_Function.dayInWeek(Opportunity.CreatedDate))
```

</div>

### dayInYear

<div class="apex-member">

```apex
global static QRY_Function dayInYear(SObjectField field)
```

Wraps a date/datetime field in DAY_IN_YEAR (1–366).

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `field` | [SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm) | The date or datetime field to bucket. |

**Returns** [QRY_Function](QRY_Function.md) — A QRY_Function carrying DAY_IN_YEAR(field) for use in SELECT, GROUP BY or ORDER BY.

**Example**

```apex
.groupBy(QRY_Function.dayInYear(Opportunity.CloseDate))
```

</div>

### dayOnly

<div class="apex-member">

```apex
global static QRY_Function dayOnly(SObjectField field)
```

Wraps a datetime field in DAY_ONLY, returning the date with the time component
dropped. Read back with `AggregateRow.getDate(alias)`, not `getInteger` — DAY_ONLY yields a
Date, unlike the other date functions which yield an Integer date part.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `field` | [SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm) | The datetime field to truncate to a date. |

**Returns** [QRY_Function](QRY_Function.md) — A QRY_Function carrying DAY_ONLY(field) for use in SELECT, GROUP BY or ORDER BY.

**Example**

```apex
.addField(QRY_Function.dayOnly(Opportunity.CreatedDate), 'createdOn')
// ... row.getDate('createdOn')
```

</div>

### distanceInKilometers

<div class="apex-member">

```apex
global static QRY_Function distanceInKilometers(SObjectField field, Decimal latitude, Decimal longitude)
```

Wraps a geolocation or compound address field in the SOQL DISTANCE function, measuring
the straight-line distance in kilometres from each record to a fixed reference point. Use it for
proximity filtering and nearest-first ordering (field service, store locator, dispatch). Renders
DISTANCE(field, GEOLOCATION(latitude,longitude), 'km'). Place it on the WHERE side with
`QRY_Builder.Builder.condition(QRY_Function)` and on the sort side with the existing
`orderBy(QRY_Function)` overload (ascending is nearest-first).

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `field` | [SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm) | The geolocation (or compound address) field to measure from. |
| `latitude` | [Decimal](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_decimal.htm) | The latitude of the reference point, in degrees. |
| `longitude` | [Decimal](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_decimal.htm) | The longitude of the reference point, in degrees. |

**Returns** [QRY_Function](QRY_Function.md) — A QRY_Function carrying DISTANCE(field, GEOLOCATION(latitude,longitude), 'km').

**Example**

```apex
List<Account> nearby = QRY_Builder.selectFrom(Account.SObjectType)
    .condition(QRY_Function.distanceInKilometers(Account.BillingAddress, 37.775, -122.418)).lessThan(16)
    .orderBy(QRY_Function.distanceInKilometers(Account.BillingAddress, 37.775, -122.418)).ascending()
    .toList();
```

</div>

<div class="apex-member">

```apex
global static QRY_Function distanceInKilometers(SObjectField field, System.Location location)
```

Wraps a geolocation or compound address field in the SOQL DISTANCE function, measuring
the straight-line distance in kilometres to a `System.Location` reference point. Convenience
overload of `distanceInKilometers(SObjectField, Decimal, Decimal)` for callers that already hold a
Location (for example a user's current position). Renders the identical
DISTANCE(field, GEOLOCATION(latitude,longitude), 'km') form.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `field` | [SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm) | The geolocation (or compound address) field to measure from. |
| `location` | [System.Location](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_system_Location.htm) | The reference point to measure distance to. |

**Returns** [QRY_Function](QRY_Function.md) — A QRY_Function carrying DISTANCE(field, GEOLOCATION(latitude,longitude), 'km').

**Example**

```apex
System.Location origin = System.Location.newInstance(37.775, -122.418);
QRY_Function nearest = QRY_Function.distanceInKilometers(Account.BillingAddress, origin);
```

</div>

### distanceInMiles

<div class="apex-member">

```apex
global static QRY_Function distanceInMiles(SObjectField field, Decimal latitude, Decimal longitude)
```

Wraps a geolocation or compound address field in the SOQL DISTANCE function, measuring
the straight-line distance in statute miles from each record to a fixed reference point. Use it for
proximity filtering and nearest-first ordering (field service, store locator, dispatch). Renders
DISTANCE(field, GEOLOCATION(latitude,longitude), 'mi'). Place it on the WHERE side with
`QRY_Builder.Builder.condition(QRY_Function)` and on the sort side with the existing
`orderBy(QRY_Function)` overload (ascending is nearest-first).

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `field` | [SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm) | The geolocation (or compound address) field to measure from. |
| `latitude` | [Decimal](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_decimal.htm) | The latitude of the reference point, in degrees. |
| `longitude` | [Decimal](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_decimal.htm) | The longitude of the reference point, in degrees. |

**Returns** [QRY_Function](QRY_Function.md) — A QRY_Function carrying DISTANCE(field, GEOLOCATION(latitude,longitude), 'mi').

**Example**

```apex
List<Account> nearby = QRY_Builder.selectFrom(Account.SObjectType)
    .condition(QRY_Function.distanceInMiles(Account.BillingAddress, 37.775, -122.418)).lessThan(10)
    .orderBy(QRY_Function.distanceInMiles(Account.BillingAddress, 37.775, -122.418)).ascending()
    .toList();
```

</div>

<div class="apex-member">

```apex
global static QRY_Function distanceInMiles(SObjectField field, System.Location location)
```

Wraps a geolocation or compound address field in the SOQL DISTANCE function, measuring
the straight-line distance in statute miles to a `System.Location` reference point. Convenience
overload of `distanceInMiles(SObjectField, Decimal, Decimal)` for callers that already hold a Location
(for example a user's current position). Renders the identical
DISTANCE(field, GEOLOCATION(latitude,longitude), 'mi') form.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `field` | [SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm) | The geolocation (or compound address) field to measure from. |
| `location` | [System.Location](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_system_Location.htm) | The reference point to measure distance to. |

**Returns** [QRY_Function](QRY_Function.md) — A QRY_Function carrying DISTANCE(field, GEOLOCATION(latitude,longitude), 'mi').

**Example**

```apex
System.Location origin = System.Location.newInstance(37.775, -122.418);
QRY_Function nearest = QRY_Function.distanceInMiles(Account.BillingAddress, origin);
```

</div>

### fiscalMonth

<div class="apex-member">

```apex
global static QRY_Function fiscalMonth(SObjectField field)
```

Wraps a date/datetime field in FISCAL_MONTH (1–12 within the org's fiscal year).

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `field` | [SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm) | The date or datetime field to bucket. |

**Returns** [QRY_Function](QRY_Function.md) — A QRY_Function carrying FISCAL_MONTH(field) for use in SELECT, GROUP BY or ORDER BY.

**Example**

```apex
.groupBy(QRY_Function.fiscalMonth(Opportunity.CloseDate))
```

</div>

### fiscalQuarter

<div class="apex-member">

```apex
global static QRY_Function fiscalQuarter(SObjectField field)
```

Wraps a date/datetime field in FISCAL_QUARTER (1–4 within the org's fiscal year).

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `field` | [SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm) | The date or datetime field to bucket. |

**Returns** [QRY_Function](QRY_Function.md) — A QRY_Function carrying FISCAL_QUARTER(field) for use in SELECT, GROUP BY or ORDER BY.

**Example**

```apex
.groupBy(QRY_Function.fiscalQuarter(Opportunity.CloseDate))
```

</div>

### fiscalYear

<div class="apex-member">

```apex
global static QRY_Function fiscalYear(SObjectField field)
```

Wraps a date/datetime field in FISCAL_YEAR (the org's fiscal year).

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `field` | [SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm) | The date or datetime field to bucket. |

**Returns** [QRY_Function](QRY_Function.md) — A QRY_Function carrying FISCAL_YEAR(field) for use in SELECT, GROUP BY or ORDER BY.

**Example**

```apex
.groupBy(QRY_Function.fiscalYear(Opportunity.CloseDate))
```

</div>

### hourInDay

<div class="apex-member">

```apex
global static QRY_Function hourInDay(SObjectField field)
```

Wraps a datetime field in HOUR_IN_DAY (0–23, in the running user's time zone).

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `field` | [SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm) | The datetime field to bucket. |

**Returns** [QRY_Function](QRY_Function.md) — A QRY_Function carrying HOUR_IN_DAY(field) for use in SELECT, GROUP BY or ORDER BY.

**Example**

```apex
.groupBy(QRY_Function.hourInDay(Opportunity.CreatedDate))
```

</div>

### weekInMonth

<div class="apex-member">

```apex
global static QRY_Function weekInMonth(SObjectField field)
```

Wraps a date/datetime field in WEEK_IN_MONTH (1–6).

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `field` | [SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm) | The date or datetime field to bucket. |

**Returns** [QRY_Function](QRY_Function.md) — A QRY_Function carrying WEEK_IN_MONTH(field) for use in SELECT, GROUP BY or ORDER BY.

**Example**

```apex
.groupBy(QRY_Function.weekInMonth(Opportunity.CloseDate))
```

</div>

### weekInYear

<div class="apex-member">

```apex
global static QRY_Function weekInYear(SObjectField field)
```

Wraps a date/datetime field in WEEK_IN_YEAR (1–53).

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `field` | [SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm) | The date or datetime field to bucket. |

**Returns** [QRY_Function](QRY_Function.md) — A QRY_Function carrying WEEK_IN_YEAR(field) for use in SELECT, GROUP BY or ORDER BY.

**Example**

```apex
.groupBy(QRY_Function.weekInYear(Opportunity.CloseDate))
```

</div>

