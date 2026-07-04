---
title: "QRY_Function"
type: class
description: "Typed SOQL date-function expressions (CALENDAR_MONTH, DAY_IN_MONTH, FISCAL_QUARTER, ...) for use in the query builder's SELECT, GROUP BY and ORDER BY clauses. One static factory per function; the retu"
author: "Jason Van Beukering"
group: "Query Infrastructure"
date: "June 2026"
since: "1.1"
category: apex
---

# QRY_Function

**Class** · Group: `Query Infrastructure`

```apex
global inherited sharing class QRY_Function
```

Typed SOQL date-function expressions (CALENDAR_MONTH, DAY_IN_MONTH, FISCAL_QUARTER, ...) for use in the query builder's SELECT, GROUP BY and ORDER BY clauses. One static factory per function; the returned value is an immutable carrier that resolves its wrapped field name once and renders to a finished SOQL expression, so the builder can project, group and sort by the same date part from a single source without hand-spelling raw SOQL. Use the factories with the matching QRY_Builder.Builder overloads — addField, groupBy and orderBy — to bucket records by a date part for reporting.

**Since:** 1.1

**Example:**

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
| global static [QRY_Function](QRY_Function.md) [fiscalMonth](#fiscalmonth)([SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm) field) | Wraps a date/datetime field in FISCAL_MONTH (1–12 within the org's fiscal year). |
| global static [QRY_Function](QRY_Function.md) [fiscalQuarter](#fiscalquarter)([SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm) field) | Wraps a date/datetime field in FISCAL_QUARTER (1–4 within the org's fiscal year). |
| global static [QRY_Function](QRY_Function.md) [fiscalYear](#fiscalyear)([SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm) field) | Wraps a date/datetime field in FISCAL_YEAR (the org's fiscal year). |
| global static [QRY_Function](QRY_Function.md) [hourInDay](#hourinday)([SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm) field) | Wraps a datetime field in HOUR_IN_DAY (0–23, in the running user's time zone). |
| global static [QRY_Function](QRY_Function.md) [weekInMonth](#weekinmonth)([SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm) field) | Wraps a date/datetime field in WEEK_IN_MONTH (1–6). |
| global static [QRY_Function](QRY_Function.md) [weekInYear](#weekinyear)([SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm) field) | Wraps a date/datetime field in WEEK_IN_YEAR (1–53). |

---

## Method Details

### calendarMonth

```apex
global static QRY_Function calendarMonth(SObjectField field)
```

Wraps a date/datetime field in CALENDAR_MONTH (1–12 in the calendar year).

**Parameters:**

- `field` ([SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm)) - The date or datetime field to bucket.

**Returns:** [QRY_Function](QRY_Function.md) - A QRY_Function carrying CALENDAR_MONTH(field) for use in SELECT, GROUP BY or ORDER BY.

**Since:** 1.1

**Example:**

```apex
.groupBy(QRY_Function.calendarMonth(Opportunity.CloseDate))
```

### calendarQuarter

```apex
global static QRY_Function calendarQuarter(SObjectField field)
```

Wraps a date/datetime field in CALENDAR_QUARTER (1–4 in the calendar year).

**Parameters:**

- `field` ([SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm)) - The date or datetime field to bucket.

**Returns:** [QRY_Function](QRY_Function.md) - A QRY_Function carrying CALENDAR_QUARTER(field) for use in SELECT, GROUP BY or ORDER BY.

**Since:** 1.1

**Example:**

```apex
.groupBy(QRY_Function.calendarQuarter(Opportunity.CloseDate))
```

### calendarYear

```apex
global static QRY_Function calendarYear(SObjectField field)
```

Wraps a date/datetime field in CALENDAR_YEAR (the four-digit calendar year).

**Parameters:**

- `field` ([SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm)) - The date or datetime field to bucket.

**Returns:** [QRY_Function](QRY_Function.md) - A QRY_Function carrying CALENDAR_YEAR(field) for use in SELECT, GROUP BY or ORDER BY.

**Since:** 1.1

**Example:**

```apex
.groupBy(QRY_Function.calendarYear(Opportunity.CloseDate))
```

### dayInMonth

```apex
global static QRY_Function dayInMonth(SObjectField field)
```

Wraps a date/datetime field in DAY_IN_MONTH (1–31).

**Parameters:**

- `field` ([SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm)) - The date or datetime field to bucket.

**Returns:** [QRY_Function](QRY_Function.md) - A QRY_Function carrying DAY_IN_MONTH(field) for use in SELECT, GROUP BY or ORDER BY.

**Since:** 1.1

**Example:**

```apex
.groupBy(QRY_Function.dayInMonth(Opportunity.CloseDate))
```

### dayInWeek

```apex
global static QRY_Function dayInWeek(SObjectField field)
```

Wraps a date/datetime field in DAY_IN_WEEK (1 for Sunday through 7 for Saturday).

**Parameters:**

- `field` ([SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm)) - The date or datetime field to bucket.

**Returns:** [QRY_Function](QRY_Function.md) - A QRY_Function carrying DAY_IN_WEEK(field) for use in SELECT, GROUP BY or ORDER BY.

**Since:** 1.1

**Example:**

```apex
.groupBy(QRY_Function.dayInWeek(Opportunity.CreatedDate))
```

### dayInYear

```apex
global static QRY_Function dayInYear(SObjectField field)
```

Wraps a date/datetime field in DAY_IN_YEAR (1–366).

**Parameters:**

- `field` ([SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm)) - The date or datetime field to bucket.

**Returns:** [QRY_Function](QRY_Function.md) - A QRY_Function carrying DAY_IN_YEAR(field) for use in SELECT, GROUP BY or ORDER BY.

**Since:** 1.1

**Example:**

```apex
.groupBy(QRY_Function.dayInYear(Opportunity.CloseDate))
```

### dayOnly

```apex
global static QRY_Function dayOnly(SObjectField field)
```

Wraps a datetime field in DAY_ONLY, returning the date with the time component
dropped. Read back with `AggregateRow.getDate(alias)`, not `getInteger` — DAY_ONLY yields a
Date, unlike the other date functions which yield an Integer date part.

**Parameters:**

- `field` ([SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm)) - The datetime field to truncate to a date.

**Returns:** [QRY_Function](QRY_Function.md) - A QRY_Function carrying DAY_ONLY(field) for use in SELECT, GROUP BY or ORDER BY.

**Since:** 1.1

**Example:**

```apex
.addField(QRY_Function.dayOnly(Opportunity.CreatedDate), 'createdOn')
// ... row.getDate('createdOn')
```

### fiscalMonth

```apex
global static QRY_Function fiscalMonth(SObjectField field)
```

Wraps a date/datetime field in FISCAL_MONTH (1–12 within the org's fiscal year).

**Parameters:**

- `field` ([SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm)) - The date or datetime field to bucket.

**Returns:** [QRY_Function](QRY_Function.md) - A QRY_Function carrying FISCAL_MONTH(field) for use in SELECT, GROUP BY or ORDER BY.

**Since:** 1.1

**Example:**

```apex
.groupBy(QRY_Function.fiscalMonth(Opportunity.CloseDate))
```

### fiscalQuarter

```apex
global static QRY_Function fiscalQuarter(SObjectField field)
```

Wraps a date/datetime field in FISCAL_QUARTER (1–4 within the org's fiscal year).

**Parameters:**

- `field` ([SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm)) - The date or datetime field to bucket.

**Returns:** [QRY_Function](QRY_Function.md) - A QRY_Function carrying FISCAL_QUARTER(field) for use in SELECT, GROUP BY or ORDER BY.

**Since:** 1.1

**Example:**

```apex
.groupBy(QRY_Function.fiscalQuarter(Opportunity.CloseDate))
```

### fiscalYear

```apex
global static QRY_Function fiscalYear(SObjectField field)
```

Wraps a date/datetime field in FISCAL_YEAR (the org's fiscal year).

**Parameters:**

- `field` ([SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm)) - The date or datetime field to bucket.

**Returns:** [QRY_Function](QRY_Function.md) - A QRY_Function carrying FISCAL_YEAR(field) for use in SELECT, GROUP BY or ORDER BY.

**Since:** 1.1

**Example:**

```apex
.groupBy(QRY_Function.fiscalYear(Opportunity.CloseDate))
```

### hourInDay

```apex
global static QRY_Function hourInDay(SObjectField field)
```

Wraps a datetime field in HOUR_IN_DAY (0–23, in the running user's time zone).

**Parameters:**

- `field` ([SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm)) - The datetime field to bucket.

**Returns:** [QRY_Function](QRY_Function.md) - A QRY_Function carrying HOUR_IN_DAY(field) for use in SELECT, GROUP BY or ORDER BY.

**Since:** 1.1

**Example:**

```apex
.groupBy(QRY_Function.hourInDay(Opportunity.CreatedDate))
```

### weekInMonth

```apex
global static QRY_Function weekInMonth(SObjectField field)
```

Wraps a date/datetime field in WEEK_IN_MONTH (1–6).

**Parameters:**

- `field` ([SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm)) - The date or datetime field to bucket.

**Returns:** [QRY_Function](QRY_Function.md) - A QRY_Function carrying WEEK_IN_MONTH(field) for use in SELECT, GROUP BY or ORDER BY.

**Since:** 1.1

**Example:**

```apex
.groupBy(QRY_Function.weekInMonth(Opportunity.CloseDate))
```

### weekInYear

```apex
global static QRY_Function weekInYear(SObjectField field)
```

Wraps a date/datetime field in WEEK_IN_YEAR (1–53).

**Parameters:**

- `field` ([SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm)) - The date or datetime field to bucket.

**Returns:** [QRY_Function](QRY_Function.md) - A QRY_Function carrying WEEK_IN_YEAR(field) for use in SELECT, GROUP BY or ORDER BY.

**Since:** 1.1

**Example:**

```apex
.groupBy(QRY_Function.weekInYear(Opportunity.CloseDate))
```

