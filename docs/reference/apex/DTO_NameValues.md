---
title: "DTO_NameValues"
type: class
pageClass: reference
description: "Class for managing and transferring key-value pairs, represented as names and values, between classes. Provides functionalities to store, retrieve, and manipulate these name-value pairs."
author: "Jason Van Beukering"
group: "Data Transfer Objects"
date: "February 2026, May 2026"
since: "1.0"
category: apex
---

# DTO_NameValues

**Class** · Group: `Data Transfer Objects`

<div class="apex-member apex-class">

```apex
@JsonAccess(serializable='always' deserializable='always') global inherited sharing class DTO_NameValues extends DTO_JsonBase
```

**Extends:** [DTO_JsonBase](DTO_JsonBase.md)

Class for managing and transferring key-value pairs, represented as names and values, between classes. Provides functionalities to store, retrieve, and manipulate these name-value pairs.

**Example**

```apex
DTO_NameValues params = new DTO_NameValues();
params.add('recipient', 'user@example.com');
params.add('subject', 'Hello');
String recipient = params.get('recipient');
Boolean hasAll = params.allExists(new Set<String>{'recipient', 'subject'}, true);
```

</div>

---

## Properties

| Property | Description |
|----------|-------------|
| global transient [Set](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_set.htm)<[String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)> [names](#names) | Returns all the names for registered name-value pairs |
| global transient [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) [size](#size) | Returns the number of name-value pairs |
| global transient [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)> [values](#values) | Returns all the values for registered name-value pairs |

## Methods

| Method | Description |
|--------|-------------|
| global void [add](#add)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) name, [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) value) | Adds a new key-value pair to the map, or updates the value if the key already exists. |
| global [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) [allExists](#allexists)([Set](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_set.htm)<[String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)> names) | Checks to see if all the parameter names provided exist in the list |
| global [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) [allExists](#allexists)([Set](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_set.htm)<[String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)> namesToMatch, [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) isNonBlank) | Determines if all keys in the provided set exist in the map, and optionally ensures that all have non-blank values. |
| global  [DTO_NameValues](#dto_namevalues)() | Constructor that initializes an empty name-value map to store key-value pairs. |
| global  [DTO_NameValues](#dto_namevalues)([Map](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_map.htm)<[String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm), [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)> nameValues) | Constructor that populates name-value pairs from a provided map. |
| global  [DTO_NameValues](#dto_namevalues)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) separatedNameValues) | Constructor that accepts a delimited string of name-value pairs, converting them into key-value entries within the map. |
| global  [DTO_NameValues](#dto_namevalues)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) separatedNameValues, [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) separator) | Constructor that accepts a delimited string of name-value pairs, with a specified separator, and converts them into key-value entries within the map. |
| global [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) [exists](#exists)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) nameToMatch) | Returns true if the objects contains a value for the specified name |
| global [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) [exists](#exists)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) nameToMatch, [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) isNonBlank) | Determines if a key exists in the map and, optionally, if it is non-blank. |
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [get](#get)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) name) | Retrieves the value associated with the specified key in the map. |
| global override [Type](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_type.htm) [getObjectType](#getobjecttype)() | Returns the type of this DTO for deserialization purposes, useful for reconstructing the object from JSON. |
| global [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) [isEmpty](#isempty)() | Checks if the DTO contains no key-value pairs. |
| global override [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [serialize](#serialize)() | Serializes the map to a JSON string. |
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [toParameterString](#toparameterstring)() | Converts the name-value pairs in the map into a parameter string in the format "name1=value1,name2=value2". |

---

## Property Details

### names

```apex
global transient Set<String> names
```

**Type:** [Set](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_set.htm)

Returns all the names for registered name-value pairs

Since:


Example:

### size

```apex
global transient Integer size
```

**Type:** [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm)

Returns the number of name-value pairs

Since:


Example:

### values

```apex
global transient List<String> values
```

**Type:** [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)

Returns all the values for registered name-value pairs

Since:


Example:

---

## Method Details

### DTO_NameValues

<div class="apex-member">

```apex
global DTO_NameValues()
```

Constructor that initializes an empty name-value map to store key-value pairs.

**Example**

```apex
DTO_NameValues instance = new DTO_NameValues();
```

</div>

<div class="apex-member">

```apex
global DTO_NameValues(Map<String, String> nameValues)
```

Constructor that populates name-value pairs from a provided map.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `nameValues` | [Map](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_map.htm) | A map of key-value pairs where both keys and values are strings. |

**Example**

```apex
DTO_NameValues instance = new DTO_NameValues(new Map<String, String>{'key' => 'value'});
```

</div>

<div class="apex-member">

```apex
global DTO_NameValues(String separatedNameValues)
```

Constructor that accepts a delimited string of name-value pairs, converting
them into key-value entries within the map.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `separatedNameValues` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | A string of name-value pairs separated by a comma, e.g., "paramName=paramValue,paramName2=paramValue2". |

**Example**

```apex
DTO_NameValues instance = new DTO_NameValues('value');
```

</div>

<div class="apex-member">

```apex
global DTO_NameValues(String separatedNameValues, String separator)
```

Constructor that accepts a delimited string of name-value pairs, with a specified separator,
and converts them into key-value entries within the map.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `separatedNameValues` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | A string of name-value pairs, e.g., "paramName=paramValue\|paramName2=paramValue2". |
| `separator` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The delimiter to separate each name-value pair. If null, defaults to a comma. |

**Example**

```apex
DTO_NameValues instance = new DTO_NameValues('value', ',');
```

</div>

### add

<div class="apex-member">

```apex
global void add(String name, String value)
```

Adds a new key-value pair to the map, or updates the value if the key already exists.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `name` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The key to add or update. |
| `value` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The value to associate with the key. |

**Example**

```apex
instance.add('myName', 'value');
```

</div>

### allExists

<div class="apex-member">

```apex
global Boolean allExists(Set<String> names)
```

Checks to see if all the parameter names provided exist in the list

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `names` | [Set](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_set.htm) | A list of names on which to match (please note this is case sensitive) |

**Returns** [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) — True if ALL the parameters exist

**Example**

```apex
Boolean result = instance.allExists(new Set<String>{'a', 'b'});
```

</div>

<div class="apex-member">

```apex
global Boolean allExists(Set<String> namesToMatch, Boolean isNonBlank)
```

Determines if all keys in the provided set exist in the map, and optionally
ensures that all have non-blank values.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `namesToMatch` | [Set](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_set.htm) | A set of keys to check for existence. Case-sensitive. |
| `isNonBlank` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | If true, requires that all specified keys have non-blank values. |

**Returns** [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) — true if all keys exist (and have non-blank values if specified).

**Example**

```apex
Boolean result = instance.allExists(new Set<String>{'a', 'b'}, true);
```

</div>

### exists

<div class="apex-member">

```apex
global Boolean exists(String nameToMatch)
```

Returns true if the objects contains a value for the specified name

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `nameToMatch` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | Name against which to find a key, note the compare is case-sensitive |

**Returns** [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) — Null or the item found

**Example**

```apex
Boolean result = instance.exists('value');
```

</div>

<div class="apex-member">

```apex
global Boolean exists(String nameToMatch, Boolean isNonBlank)
```

Determines if a key exists in the map and, optionally, if it is non-blank.
A non-blank value is neither null nor an empty string.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `nameToMatch` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | Name against which to find a key, note the compare is case-sensitive |
| `isNonBlank` | [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) | Will return false if item exists and it's blank (either null or empty string) |

**Returns** [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) — true if the key exists (and has a non-blank value if specified).

**Example**

```apex
Boolean result = instance.exists('value', true);
```

</div>

### get

<div class="apex-member">

```apex
global String get(String name)
```

Retrieves the value associated with the specified key in the map.
If the key does not exist, returns null.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `name` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The key for which to retrieve the value. Case-sensitive. |

**Returns** [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) — The value associated with the specified key, or null if the key is absent.

**Example**

```apex
String result = instance.get('myName');
```

</div>

### getObjectType

<div class="apex-member">

```apex
global override Type getObjectType()
```

Returns the type of this DTO for deserialization purposes, useful for reconstructing
the object from JSON.

**Returns** [Type](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_type.htm) — The type class of DTO_NameValues.

**Example**

```apex
Type result = instance.getObjectType();
```

</div>

### isEmpty

<div class="apex-member">

```apex
global Boolean isEmpty()
```

Checks if the DTO contains no key-value pairs.
Returns true if the object has zero key-value pairs.

**Returns** [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) — true if there are no entries, false otherwise.

**Example**

```apex
Boolean result = instance.isEmpty();
```

</div>

### serialize

<div class="apex-member">

```apex
global override String serialize()
```

Serializes the map to a JSON string. If the map is empty, returns an empty JSON object `{}`.

**Returns** [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) — A JSON string representation of the map.

**Example**

```apex
String result = instance.serialize();
```

</div>

### toParameterString

<div class="apex-member">

```apex
global String toParameterString()
```

Converts the name-value pairs in the map into a parameter string in the format `"name1=value1,name2=value2"`.

**Returns** [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) — A string of comma-separated name-value pairs.

**Example**

```apex
String result = instance.toParameterString();
```

</div>

