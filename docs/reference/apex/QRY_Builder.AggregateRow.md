---
title: "QRY_Builder.AggregateRow"
type: class
pageClass: reference
description: "Typed wrapper around AggregateResult for convenient value access. Provides typed accessors that eliminate the need for manual casting from Object."
since: "1.0"
category: apex
---

# QRY_Builder.AggregateRow

**Class**

```apex
global inherited sharing class QRY_Builder.AggregateRow
```

Typed wrapper around AggregateResult for convenient value access. Provides typed accessors that eliminate the need for manual casting from Object.

**Since:** 1.0

**Example:**

```apex
QRY_Builder.AggregateRow row = QRY_Builder.selectFrom(Account.SObjectType)
    .count('Id')
    .groupBy('Industry')
    .toAggregateList()[0];
Integer total = row.getInteger('expr0');
String industry = row.getString('Industry');
```

---

## Methods

| Method | Description |
|--------|-------------|
| global [Object](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_System_Object.htm) [get](#get)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) alias) | Gets a raw Object value by alias. |
| global [Date](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_date.htm) [getDate](#getdate)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) alias) | Gets a Date value by alias. |
| global [Decimal](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_decimal.htm) [getDecimal](#getdecimal)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) alias) | Gets a Decimal value by alias. |
| global [Id](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_id.htm) [getId](#getid)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) alias) | Gets an Id value by alias. |
| global [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) [getInteger](#getinteger)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) alias) | Gets an Integer value by alias. |
| global [Long](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_long.htm) [getLong](#getlong)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) alias) | Gets a Long value by alias. |
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [getString](#getstring)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) alias) | Gets a String value by alias. |

---

## Method Details

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
Object value = row.get('expr0');
```

</div>

### getDate

<div class="apex-member">

```apex
global Date getDate(String alias)
```

Gets a Date value by alias.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `alias` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The aggregate alias or field name |

**Returns** [Date](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_date.htm) — The Date value

**Example**

```apex
Date earliest = row.getDate('expr0');
```

</div>

### getDecimal

<div class="apex-member">

```apex
global Decimal getDecimal(String alias)
```

Gets a Decimal value by alias.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `alias` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The aggregate alias or field name |

**Returns** [Decimal](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_decimal.htm) — The Decimal value

**Example**

```apex
Decimal total = row.getDecimal('expr0');
```

</div>

### getId

<div class="apex-member">

```apex
global Id getId(String alias)
```

Gets an Id value by alias.

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

Gets an Integer value by alias.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `alias` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The aggregate alias or field name |

**Returns** [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) — The Integer value

**Example**

```apex
Integer count = row.getInteger('expr0');
```

</div>

### getLong

<div class="apex-member">

```apex
global Long getLong(String alias)
```

Gets a Long value by alias.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `alias` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The aggregate alias or field name |

**Returns** [Long](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_long.htm) — The Long value

**Example**

```apex
Long total = row.getLong('expr0');
```

</div>

### getString

<div class="apex-member">

```apex
global String getString(String alias)
```

Gets a String value by alias.

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

