---
title: "UTIL_JsonPath"
type: class
description: "Utility class to streamline parsing nested JSON data structures. Provides methods to navigate and extract data from JSON using dot notation paths, with support for type-safe value retrieval and existe"
author: "Jason Van Beukering"
group: "Utilities"
date: "February 2026, May 2026"
since: "1.0"
category: apex
---

# UTIL_JsonPath

**Class** · Group: `Utilities`

```apex
global inherited sharing class UTIL_JsonPath
```

Utility class to streamline parsing nested JSON data structures. Provides methods to navigate and extract data from JSON using dot notation paths, with support for type-safe value retrieval and existence checks. Adapted from open-force.

**Since:** 1.0

**Example:**

```apex
UTIL_JsonPath json = new UTIL_JsonPath('{"account": {"name": "Acme", "active": true}}');
String name = json.get('account.name').getStringValue();
Boolean active = json.get('account.active').getBooleanValue();
Boolean exists = json.exists('account.name');
```

---

## Methods

| Method | Description |
|--------|-------------|
| global [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) [exists](#exists)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) path) | Checks if a path exists in the JSON data structure. |
| global [UTIL_JsonPath](UTIL_JsonPath.md) [findNode](#findnode)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) path) | Navigates to a subtree in the JSON data using a dot notation path. |
| global [UTIL_JsonPath](UTIL_JsonPath.md) [get](#get)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) path) | Retrieves a subtree in the JSON data using a dot notation path. |
| global [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) [getBooleanValue](#getbooleanvalue)() | Converts the wrapped JSON data to a Boolean. |
| global [Datetime](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_datetime.htm) [getDatetimeValue](#getdatetimevalue)() | Converts the wrapped JSON data to a Datetime, supporting ISO-8601 strings or timestamps (Long). |
| global [Date](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_date.htm) [getDateValue](#getdatevalue)() | Converts the wrapped JSON data to a Date, supporting ISO-8601 strings or timestamps (Long). |
| global [Decimal](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_decimal.htm) [getDecimalValue](#getdecimalvalue)() | Converts the wrapped JSON data to a Decimal. |
| global [Id](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_id.htm) [getIdValue](#getidvalue)() | Converts the wrapped JSON data to a Salesforce Id, validating the string format. |
| global [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) [getIntegerValue](#getintegervalue)() | Converts the wrapped JSON data to an Integer. |
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [getStringValue](#getstringvalue)() | Converts the wrapped JSON data to a String, excluding objects and arrays. |
| global [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) [isArray](#isarray)() | Checks if the wrapped JSON data is an array (List). |
| global [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) [isObject](#isobject)() | Checks if the wrapped JSON data is an object (Map). |
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [toStringPretty](#tostringpretty)() | Serializes the wrapped JSON data to a pretty-printed JSON string. |
| global [UTIL_JsonPath](#util_jsonpath)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) jsonData) | Constructs a UTIL_JsonPath instance from a serialized JSON string. |

## Inner Classes

| Class | Description |
|-------|-------------|
| [MissingKeyException](UTIL_JsonPath.MissingKeyException.md) | Custom exception thrown when a JSON path key cannot be resolved. |

---

## Method Details

### UTIL_JsonPath

```apex
global UTIL_JsonPath(String jsonData)
```

Constructs a UTIL_JsonPath instance from a serialized JSON string.

**Parameters:**

- `jsonData` ([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)) - The JSON string to parse.

**Since:** 1.0

**Example:**

```apex
UTIL_JsonPath instance = new UTIL_JsonPath('value');
```

### exists

```apex
global Boolean exists(String path)
```

Checks if a path exists in the JSON data structure.

**Parameters:**

- `path` ([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)) - The dot notation path to check.

**Returns:** [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) - True if the path exists, false otherwise.

**Since:** 1.0

**Example:**

```apex
UTIL_JsonPath json = new UTIL_JsonPath('{"data": {"items": [{"id": 1}]}}');
Boolean existsFirst = json.exists('data.items[0]');
Boolean existsSecond = json.exists('data.items[1]');
```

### findNode

```apex
global UTIL_JsonPath findNode(String path)
```

Navigates to a subtree in the JSON data using a dot notation path.

**Parameters:**

- `path` ([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)) - The dot notation path to the desired subtree.

**Returns:** [UTIL_JsonPath](UTIL_JsonPath.md) - A UTIL_JsonPath instance wrapping the targeted subtree, or null if the path does not exist.

**Since:** 1.0

**Example:**

```apex
UTIL_JsonPath result = instance.findNode('value');
```

### get

```apex
global UTIL_JsonPath get(String path)
```

Retrieves a subtree in the JSON data using a dot notation path.

Supports paths with array indices (e.g., `data.items[1]`) and object keys.

**Parameters:**

- `path` ([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)) - The dot notation path to the desired data.

**Returns:** [UTIL_JsonPath](UTIL_JsonPath.md) - A UTIL_JsonPath instance wrapping the targeted subtree.

**Throws:**

- [ListException](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_classes_exception_methods.htm) - If an array index is out of bounds.
- [MissingKeyException](UTIL_JsonPath.MissingKeyException.md) - If a key in the path does not exist in the JSON object.
- [UTIL_Exceptions.IllegalStateException](UTIL_Exceptions.IllegalStateException.md) - If an array index is applied to a non-array node or a key is applied to a non-object node.

**Since:** 1.0

**Example:**

```apex
UTIL_JsonPath json = new UTIL_JsonPath('{"data": {"items": [{"id": 1}, {"id": 2}]}}');
UTIL_JsonPath item = json.get('data.items[1]');
String id = item.getStringValue();
```

### getBooleanValue

```apex
global Boolean getBooleanValue()
```

Converts the wrapped JSON data to a Boolean.

**Returns:** [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) - The value as a Boolean.

**Throws:**

- [TypeException](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_classes_exception_methods.htm) - If the value is not a Boolean or convertible string.

**Since:** 1.0

**Example:**

```apex
UTIL_JsonPath json = new UTIL_JsonPath('{"isActive": true}');
Boolean isActive = json.get('isActive').getBooleanValue();
```

### getDatetimeValue

```apex
global Datetime getDatetimeValue()
```

Converts the wrapped JSON data to a Datetime, supporting ISO-8601 strings or timestamps (Long).

**Returns:** [Datetime](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_datetime.htm) - The value as a Datetime.

**Throws:**

- [TypeException](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_classes_exception_methods.htm) - If the value is not a String or Long.

**Since:** 1.0

**Example:**

```apex
UTIL_JsonPath json = new UTIL_JsonPath('{"timestamp": 1625097600000}');
Datetime dt = json.get('timestamp').getDatetimeValue();
```

### getDateValue

```apex
global Date getDateValue()
```

Converts the wrapped JSON data to a Date, supporting ISO-8601 strings or timestamps (Long).

**Returns:** [Date](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_date.htm) - The value as a Date.

**Throws:**

- [TypeException](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_classes_exception_methods.htm) - If the value is not a String or Long.

**Since:** 1.0

**Example:**

```apex
UTIL_JsonPath json = new UTIL_JsonPath('{"date": "2021-07-01"}');
Date dt = json.get('date').getDateValue();
```

### getDecimalValue

```apex
global Decimal getDecimalValue()
```

Converts the wrapped JSON data to a Decimal.

**Returns:** [Decimal](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_decimal.htm) - The value as a Decimal.

**Throws:**

- [TypeException](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_classes_exception_methods.htm) - If the value is not a Decimal or convertible string.

**Since:** 1.0

**Example:**

```apex
UTIL_JsonPath json = new UTIL_JsonPath('{"amount": "123.45"}');
Decimal amount = json.get('amount').getDecimalValue();
```

### getIdValue

```apex
global Id getIdValue()
```

Converts the wrapped JSON data to a Salesforce Id, validating the string format.

**Returns:** [Id](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_id.htm) - The value as an Id.

**Throws:**

- [StringException](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_classes_exception_methods.htm) - If the string is not a valid Salesforce Id.
- [TypeException](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_classes_exception_methods.htm) - If the value is not a string.

**Since:** 1.0

**Example:**

```apex
UTIL_JsonPath json = new UTIL_JsonPath('{"recordId": "001xx0000000000AAA"}');
Id recordId = json.get('recordId').getIdValue();
```

### getIntegerValue

```apex
global Integer getIntegerValue()
```

Converts the wrapped JSON data to an Integer.

**Returns:** [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) - The value as an Integer.

**Throws:**

- [TypeException](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_classes_exception_methods.htm) - If the value is not an Integer, Decimal, or convertible string.

**Since:** 1.0

**Example:**

```apex
UTIL_JsonPath json = new UTIL_JsonPath('{"count": "42"}');
Integer count = json.get('count').getIntegerValue();
```

### getStringValue

```apex
global String getStringValue()
```

Converts the wrapped JSON data to a String, excluding objects and arrays.

**Returns:** [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) - The value as a String.

**Throws:**

- [TypeException](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_classes_exception_methods.htm) - If the value is a JSON object or array.

**Since:** 1.0

**Example:**

```apex
UTIL_JsonPath json = new UTIL_JsonPath('{"name": "John"}');
String name = json.get('name').getStringValue();
```

### isArray

```apex
global Boolean isArray() global Boolean isObject() global String toStringPretty()
```

Checks if the wrapped JSON data is an array (List ).

**Returns:** [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) - True if the value is a JSON array, false otherwise.

**Since:** 1.0

**Example:**

```apex
UTIL_JsonPath json = new UTIL_JsonPath('[{"id": 1}]');
Boolean result = json.isArray();
```

### isObject

```apex
global Boolean isObject()
```

Checks if the wrapped JSON data is an object (Map ).

**Returns:** [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) - True if the value is a JSON object, false otherwise.

**Since:** 1.0

**Example:**

```apex
UTIL_JsonPath json = new UTIL_JsonPath('{"key": "value"}');
Boolean result = json.isObject();
```

### toStringPretty

```apex
global String toStringPretty()
```

Serializes the wrapped JSON data to a pretty-printed JSON string.

**Returns:** [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) - A formatted JSON string.

**Since:** 1.0

**Example:**

```apex
UTIL_JsonPath json = new UTIL_JsonPath('{"key": "value"}');
String result = json.toStringPretty();
```

