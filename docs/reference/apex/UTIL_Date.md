---
title: "UTIL_Date"
type: class
description: "Provides date and datetime helper operations such as business day arithmetic, weekday/weekend checks, ISO 8601 serialization, cron generation, and date formatting."
author: "Jason Van Beukering"
group: "Utilities"
date: "February 2026, June 2026"
since: "1.0"
category: apex
---

# UTIL_Date

**Class** · Group: `Utilities`

```apex
global inherited sharing class UTIL_Date
```

Provides date and datetime helper operations such as business day arithmetic, weekday/weekend checks, ISO 8601 serialization, cron generation, and date formatting.

**Since:** 1.0

**Example:**

```apex
Date nextBusinessDay = UTIL_Date.addBusinessDays(Date.today(), 5);
Boolean weekend = UTIL_Date.isWeekend(Date.today());
String cron = UTIL_Date.getCronExpression(Datetime.now().addHours(1));
String iso = UTIL_Date.toIso8601(Date.today());
```

---

## Methods

| Method | Description |
|--------|-------------|
| global static [Date](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_date.htm) [addBusinessDays](#addbusinessdays)([Date](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_date.htm) origin, [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) workingDaysToAdd) | Advances or retreats a date by the given number of business days, skipping weekends. |
| global static [Date](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_date.htm) [dateFromIso8601](#datefromiso8601)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) isoText) | Parses an ISO 8601 string into a Date instance. |
| global static [Datetime](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_datetime.htm) [dateTimeFromIso8601](#datetimefromiso8601)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) isoText) | Parses an ISO 8601 string into a Datetime instance via JSON deserialization. |
| global static [Date](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_date.htm) [firstWeekDay](#firstweekday)([Date](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_date.htm) referenceDate) | Resolves the next weekday on or after the supplied date. |
| global static [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [formatDate](#formatdate)([Date](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_date.htm) inputDate, [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) pattern) | Formats a Date according to a Java SimpleDateFormat pattern string. |
| global static [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [formatDuration](#formatduration)([Long](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_long.htm) milliseconds) | Formats a duration in milliseconds to a human-readable string. |
| global static [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [getCronExpression](#getcronexpression)([Datetime](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_datetime.htm) scheduledTime) | Builds a Salesforce-compatible cron expression from the supplied Datetime for use with System.schedule. |
| global static [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) [isWeekDay](#isweekday)([Date](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_date.htm) inputDate) | Determines whether the supplied Date falls on a weekday (Monday through Friday). |
| global static [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) [isWeekDay](#isweekday)([Datetime](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_datetime.htm) inputDatetime) | Determines whether the supplied Datetime falls on a weekday (Monday through Friday). |
| global static [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) [isWeekend](#isweekend)([Date](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_date.htm) inputDate) | Determines whether the supplied Date falls on a Saturday or Sunday. |
| global static [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) [isWeekend](#isweekend)([Datetime](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_datetime.htm) inputDatetime) | Determines whether the supplied Datetime falls on a Saturday or Sunday. |
| global static [Date](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_date.htm) [lastWeekDay](#lastweekday)() | Resolves the most recent weekday on or before today. |
| global static [Date](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_date.htm) [lastWeekDay](#lastweekday)([Date](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_date.htm) referenceDate) | Resolves the most recent weekday on or before the supplied date. |
| global static [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [toIso8601](#toiso8601)([Date](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_date.htm) inputDate) | Serializes a Date into its ISO 8601 string representation (date portion only). |
| global static [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [toIso8601](#toiso8601)([Datetime](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_datetime.htm) inputDatetime) | Serializes a Datetime into its ISO 8601 string representation, stripping surrounding quotes. |

---

## Method Details

### addBusinessDays

```apex
global static Date addBusinessDays(Date origin, Integer workingDaysToAdd)
```

Advances or retreats a date by the given number of business days, skipping weekends. Negative values move the date backwards.

**Parameters:**

- `origin` ([Date](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_date.htm)) - The starting date.
- `workingDaysToAdd` ([Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm)) - The number of business days to add (positive) or subtract (negative).

**Returns:** [Date](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_date.htm) - The resulting date after traversing the specified business days.

**Since:** 1.0

**Example:**

```apex
Date monday = Date.newInstance(2026, 2, 16);
Date result = UTIL_Date.addBusinessDays(monday, 5);
```

### dateFromIso8601

```apex
global static Date dateFromIso8601(String isoText)
```

Parses an ISO 8601 string into a `Date` instance. When the string contains a time component, the local date is used; otherwise the GMT date is returned.

**Parameters:**

- `isoText` ([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)) - The ISO 8601 string to parse (e.g. 2026-02-18 or 2026-02-18T14:30:00.000Z).

**Returns:** [Date](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_date.htm) - The parsed `Date`, or `null` when the input is blank.

**Since:** 1.0

**Example:**

```apex
Date parsed = UTIL_Date.dateFromIso8601('2026-02-18');
```

### dateTimeFromIso8601

```apex
global static Datetime dateTimeFromIso8601(String isoText)
```

Parses an ISO 8601 string into a `Datetime` instance via JSON deserialization.

**Parameters:**

- `isoText` ([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)) - The ISO 8601 string to parse (e.g. 2026-02-18T14:30:00.000Z).

**Returns:** [Datetime](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_datetime.htm) - The parsed `Datetime`, or `null` when the input is blank.

**Since:** 1.0

**Example:**

```apex
Datetime parsed = UTIL_Date.dateTimeFromIso8601('2026-02-18T14:30:00.000Z');
```

### firstWeekDay

```apex
global static Date firstWeekDay(Date referenceDate)
```

Resolves the next weekday on or after the supplied date. If the date is already a weekday it is returned unchanged.

**Parameters:**

- `referenceDate` ([Date](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_date.htm)) - The date to evaluate.

**Returns:** [Date](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_date.htm) - The same date when it is a weekday, or the following Monday when it is a weekend.

**Since:** 1.0

**Example:**

```apex
Date sunday = Date.newInstance(2026, 2, 22);
Date monday = UTIL_Date.firstWeekDay(sunday);
```

### formatDate

```apex
global static String formatDate(Date inputDate, String pattern)
```

Formats a `Date` according to a Java SimpleDateFormat pattern string.

**Parameters:**

- `inputDate` ([Date](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_date.htm)) - The date to format.
- `pattern` ([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)) - The SimpleDateFormat pattern (e.g. yyyy-MM-dd, dd/MM/yyyy).

**Returns:** [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) - The formatted date string, or `null` when the input date is `null`.

**Since:** 1.0

**Example:**

```apex
Date target = Date.newInstance(2026, 12, 25);
String formatted = UTIL_Date.formatDate(target, 'dd MMMM yyyy');
```

### formatDuration

```apex
global static String formatDuration(Long milliseconds)
```

Formats a duration in milliseconds to a human-readable string.
Returns compact labels: "500ms", "2.1s", "1m 30s", "1h 5m".

**Parameters:**

- `milliseconds` ([Long](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_long.htm)) - The duration in milliseconds. Null returns null.

**Returns:** [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) - Formatted duration string, or null if input is null.

**Since:** 1.0

**Example:**

```apex
String label = UTIL_Date.formatDuration(1500);   // "1.5s"
String label = UTIL_Date.formatDuration(90000);  // "1m 30s"
String label = UTIL_Date.formatDuration(500);    // "500ms"
```

### getCronExpression

```apex
global static String getCronExpression(Datetime scheduledTime)
```

Builds a Salesforce-compatible cron expression from the supplied `Datetime` for use with `System.schedule`.

**Parameters:**

- `scheduledTime` ([Datetime](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_datetime.htm)) - The Datetime to convert into a cron string.

**Returns:** [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) - A cron expression such as `0 30 14 18 2 ? 2026`, or `null` when the input is `null`.

**Since:** 1.0

**Example:**

```apex
Datetime runAt = Datetime.newInstance(2026, 3, 1, 6, 0, 0);
String cron = UTIL_Date.getCronExpression(runAt);
```

### isWeekDay

```apex
global static Boolean isWeekDay(Date inputDate)
```

Determines whether the supplied `Date` falls on a weekday (Monday through Friday).

**Parameters:**

- `inputDate` ([Date](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_date.htm)) - The Date to inspect.

**Returns:** [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) - `true` when the day is Monday through Friday; `false` for Saturday and Sunday.

**Since:** 1.0

**Example:**

```apex
Date monday = Date.newInstance(2026, 2, 16);
Boolean weekday = UTIL_Date.isWeekDay(monday);
```

### isWeekDay

```apex
global static Boolean isWeekDay(Datetime inputDatetime)
```

Determines whether the supplied `Datetime` falls on a weekday (Monday through Friday).

**Parameters:**

- `inputDatetime` ([Datetime](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_datetime.htm)) - The Datetime to inspect.

**Returns:** [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) - `true` when the day is Monday through Friday; `false` for Saturday and Sunday.

**Since:** 1.0

**Example:**

```apex
Datetime tuesday = Datetime.newInstance(2026, 2, 17, 12, 0, 0);
Boolean weekday = UTIL_Date.isWeekDay(tuesday);
```

### isWeekend

```apex
global static Boolean isWeekend(Date inputDate)
```

Determines whether the supplied `Date` falls on a Saturday or Sunday.

**Parameters:**

- `inputDate` ([Date](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_date.htm)) - The Date to inspect.

**Returns:** [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) - `true` when the day is Saturday or Sunday; `false` for Monday through Friday.

**Since:** 1.0

**Example:**

```apex
Date sunday = Date.newInstance(2026, 2, 22);
Boolean weekend = UTIL_Date.isWeekend(sunday);
```

### isWeekend

```apex
global static Boolean isWeekend(Datetime inputDatetime)
```

Determines whether the supplied `Datetime` falls on a Saturday or Sunday.

**Parameters:**

- `inputDatetime` ([Datetime](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_datetime.htm)) - The Datetime to inspect.

**Returns:** [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) - `true` when the day is Saturday or Sunday; `false` for Monday through Friday.

**Since:** 1.0

**Example:**

```apex
Datetime saturday = Datetime.newInstance(2026, 2, 21, 8, 0, 0);
Boolean weekend = UTIL_Date.isWeekend(saturday);
```

### lastWeekDay

```apex
global static Date lastWeekDay()
```

Resolves the most recent weekday on or before today.

**Returns:** [Date](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_date.htm) - Today when it is a weekday, or the preceding Friday when today is a weekend.

**Since:** 1.0

**Example:**

```apex
Date recentWeekday = UTIL_Date.lastWeekDay();
```

### lastWeekDay

```apex
global static Date lastWeekDay(Date referenceDate)
```

Resolves the most recent weekday on or before the supplied date. If the date is already a weekday it is returned unchanged.

**Parameters:**

- `referenceDate` ([Date](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_date.htm)) - The date to evaluate.

**Returns:** [Date](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_date.htm) - The same date when it is a weekday, or the preceding Friday when it is a weekend.

**Since:** 1.0

**Example:**

```apex
Date saturday = Date.newInstance(2026, 2, 21);
Date friday = UTIL_Date.lastWeekDay(saturday);
```

### toIso8601

```apex
global static String toIso8601(Date inputDate)
```

Serializes a `Date` into its ISO 8601 string representation (date portion only).

**Parameters:**

- `inputDate` ([Date](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_date.htm)) - The Date to serialize. When null, the epoch date is used.

**Returns:** [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) - An ISO 8601 date string such as `2026-02-18`.

**Since:** 1.0

**Example:**

```apex
Date invoiceDate = Date.newInstance(2026, 6, 1);
String iso = UTIL_Date.toIso8601(invoiceDate);
```

### toIso8601

```apex
global static String toIso8601(Datetime inputDatetime)
```

Serializes a `Datetime` into its ISO 8601 string representation, stripping surrounding quotes.

**Parameters:**

- `inputDatetime` ([Datetime](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_datetime.htm)) - The Datetime to serialize. When null, the epoch datetime is used.

**Returns:** [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) - An ISO 8601 formatted string such as `2026-02-18T10:00:00.000Z`.

**Since:** 1.0

**Example:**

```apex
Datetime scheduled = Datetime.newInstance(2026, 3, 15, 9, 0, 0);
String iso = UTIL_Date.toIso8601(scheduled);
```

