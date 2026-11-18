---
title: "QRY_Builder.AggregateRow"
type: class
pageClass: reference
description: "Typed wrapper around AggregateResult for convenient value access. Provides typed accessors that eliminate the need for manual casting from Object. In a test, a row can also hold the values of a row re"
since: "1.0"
category: apex
---

# QRY_Builder.AggregateRow

**Class**

<div class="apex-member apex-class">

```apex
global inherited sharing class QRY_Builder.AggregateRow
```

Typed wrapper around AggregateResult for convenient value access. Provides typed accessors that eliminate the need for manual casting from Object. In a test, a row can also hold the values of a row registered with TST_Mock.registerAggregateRows or QRY_Builder.setAggregateMock. Such a row answers as a real row does: an alias is matched without regard to case, and reading an alias the row does not hold throws IllegalArgumentException. Its number getters also accept a whole number written as an Integer, a Long or a Decimal.

**Example**

```apex
QRY_Builder.AggregateRow row = QRY_Builder.selectFrom(Account.SObjectType)
    .count(Account.Id, 'total')
    .groupBy(Account.Industry)
    .toAggregateList()[0];
Integer total = row.getInteger('total');
String industry = row.getString('Industry');
```

</div>

---

## Methods

| Method | Description |
|--------|-------------|
| global [Object](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_System_Object.htm) [get](#get)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) alias) | Gets a raw Object value by alias. |
| global [Date](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_date.htm) [getDate](#getdate)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) alias) | Reads a date, such as the MIN or MAX of a date field. |
| global [Decimal](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_decimal.htm) [getDecimal](#getdecimal)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) alias) | Reads a number with decimals, such as the SUM or AVG of an amount. |
| global [Id](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_id.htm) [getId](#getid)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) alias) | Reads a record Id, such as a grouped lookup field. |
| global [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) [getInteger](#getinteger)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) alias) | Reads a whole number, such as a COUNT. |
| global [Long](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_long.htm) [getLong](#getlong)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) alias) | Reads a whole number as a Long. |
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [getString](#getstring)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) alias) | Reads a text value, such as a grouped text or picklist field. |

### get

<div class="apex-member">

```apex
global Object get(String alias)
```

Gets a raw Object value by alias.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `alias` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The aggregate alias or field name |

**Returns** [Object](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_System_Object.htm) — The raw value

**Example**

```apex
QRY_Builder.AggregateRow row = QRY_Builder.selectFrom(Opportunity.SObjectType)
    .sum(Opportunity.Amount, 'total')
    .getFirstAggregate();
Object value = row.get('total');
```

</div>

### getDate

<div class="apex-member">

```apex
global Date getDate(String alias)
```

Reads a date, such as the MIN or MAX of a date field. Returns null when the row holds null under the
alias.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `alias` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The aggregate alias or field name |

**Returns** [Date](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_date.htm) — The Date value

**Example**

```apex
QRY_Builder.AggregateRow row = QRY_Builder.selectFrom(Opportunity.SObjectType)
    .min(Opportunity.CloseDate, 'earliest')
    .getFirstAggregate();
Date earliest = row.getDate('earliest');
```

</div>

### getDecimal

<div class="apex-member">

```apex
global Decimal getDecimal(String alias)
```

Reads a number with decimals, such as the SUM or AVG of an amount. Returns null when the row holds null
under the alias.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `alias` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The aggregate alias or field name |

**Returns** [Decimal](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_decimal.htm) — The Decimal value

**Example**

```apex
QRY_Builder.AggregateRow row = QRY_Builder.selectFrom(Opportunity.SObjectType)
    .sum(Opportunity.Amount, 'total')
    .getFirstAggregate();
Decimal total = row.getDecimal('total');
```

</div>

### getId

<div class="apex-member">

```apex
global Id getId(String alias)
```

Reads a record Id, such as a grouped lookup field. A grouped field with no alias is read by its field name,
such as 'AccountId'. Returns null when the row holds null under the alias.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `alias` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The aggregate alias or field name |

**Returns** [Id](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_id.htm) — The Id value

**Example**

```apex
Id accountId = row.getId('AccountId');
```

</div>

### getInteger

<div class="apex-member">

```apex
global Integer getInteger(String alias)
```

Reads a whole number, such as a COUNT. A row that a test registered with TST_Mock.registerAggregateRows
may hold the number as a Long or a Decimal; a whole number held either way is converted to an Integer, and a number
with a fraction, such as 2.5, throws a TypeException. Returns null when the row holds null under the alias.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `alias` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The aggregate alias or field name |

**Returns** [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) — The Integer value

**Example**

```apex
QRY_Builder.AggregateRow row = QRY_Builder.selectFrom(Opportunity.SObjectType)
    .count(Opportunity.Id, 'total')
    .getFirstAggregate();
Integer count = row.getInteger('total');
```

</div>

### getLong

<div class="apex-member">

```apex
global Long getLong(String alias)
```

Reads a whole number as a Long. A value held as an Integer, such as a COUNT, is returned as a Long too.
Returns null when the row holds null under the alias.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `alias` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The aggregate alias or field name |

**Returns** [Long](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_long.htm) — The Long value

**Example**

```apex
QRY_Builder.AggregateRow row = QRY_Builder.selectFrom(Opportunity.SObjectType)
    .count(Opportunity.Id, 'total')
    .getFirstAggregate();
Long total = row.getLong('total');
```

</div>

### getString

<div class="apex-member">

```apex
global String getString(String alias)
```

Reads a text value, such as a grouped text or picklist field. A grouped field with no alias is read by its
field name, such as 'Industry'. Returns null when the row holds null under the alias.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `alias` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The aggregate alias or field name |

**Returns** [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) — The String value

**Example**

```apex
String industry = row.getString('Industry');
```

</div>

