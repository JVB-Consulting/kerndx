---
title: "UTIL_Map.CaseInsensitiveMap"
type: class
description: "A Map implementation that performs case-insensitive key lookups. Keys are normalised to lower case for internal storage and retrieval, but the original casing is retained for display and export operat"
since: "1.0"
category: apex
---

# UTIL_Map.CaseInsensitiveMap

**Class**

```apex
global inherited sharing class UTIL_Map.CaseInsensitiveMap
```

A Map implementation that performs case-insensitive key lookups. Keys are normalised to lower case for internal storage and retrieval, but the original casing is retained for display and export operations.

**Since:** 1.0

**Example:**

```apex
UTIL_Map.CaseInsensitiveMap ciMap = new UTIL_Map.CaseInsensitiveMap();
ciMap.put('Acme Ltd', myAccount);
Account a = (Account) ciMap.get('ACME LTD');
```

---

## Methods

| Method | Description |
|--------|-------------|
| global  [CaseInsensitiveMap](#caseinsensitivemap)() | Constructs an empty CaseInsensitiveMap. |
| global  [CaseInsensitiveMap](#caseinsensitivemap)([Map](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_map.htm)<[String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm), [Object](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_System_Object.htm)> sourceMap) | Constructs a new CaseInsensitiveMap pre-populated with entries from the provided standard map. |
| global void [clear](#clear)() | Empties this map, discarding all stored entries. |
| global [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) [containsKey](#containskey)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) key) | Checks whether this map holds an entry for the specified key, ignoring letter case. |
| global [UTIL_Map.CaseInsensitiveMap](UTIL_Map.CaseInsensitiveMap.md) [copy](#copy)() | Produces a shallow copy of this CaseInsensitiveMap. |
| global [Object](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_System_Object.htm) [get](#get)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) key) | Retrieves the value mapped to the supplied key using a case-insensitive comparison. |
| global [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) [isEmpty](#isempty)() | Indicates whether this map is empty, containing zero entries. |
| global [Set](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_set.htm)<[String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)> [keySet](#keyset)() | Returns the set of keys in their original, caller-supplied casing. |
| global void [put](#put)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) key, [Object](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_System_Object.htm) value) | Stores a value under the given key. |
| global void [putAll](#putall)([Map](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_map.htm)<[String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm), [Object](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_System_Object.htm)> sourceMap) | Inserts all entries from the supplied map into this map. |
| global [Object](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_System_Object.htm) [remove](#remove)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) key) | Deletes the entry for the given key (case-insensitive match) and returns the previously associated value. |
| global [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) [size](#size)() | Returns the current number of key-value mappings stored in this map. |
| global [Map](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_map.htm)<[String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm), [Object](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_System_Object.htm)> [toMap](#tomap)() | Exports the contents of this map to a standard Map, restoring the original key casing. |
| global [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[Object](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_System_Object.htm)> [values](#values)() | Returns all values stored in this map as an ordered list. |

---

## Method Details

### CaseInsensitiveMap

```apex
global CaseInsensitiveMap()
```

Constructs an empty CaseInsensitiveMap.

**Since:** 1.0

**Example:**

```apex
UTIL_Map.CaseInsensitiveMap instance = new UTIL_Map.CaseInsensitiveMap();
```

```apex
global CaseInsensitiveMap(Map<String, Object> sourceMap)
```

Constructs a new CaseInsensitiveMap pre-populated with entries
from the provided standard map.

**Parameters:**

- `sourceMap` ([Map](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_map.htm)) - The map whose entries are to be placed into this map.

**Since:** 1.0

**Example:**

```apex
UTIL_Map.CaseInsensitiveMap instance = new UTIL_Map.CaseInsensitiveMap(new Map<String, Object>{'key' => 'value'});
```

### clear

```apex
global void clear()
```

Empties this map, discarding all stored entries.

**Since:** 1.0

**Example:**

```apex
instance.clear();
```

### containsKey

```apex
global Boolean containsKey(String key)
```

Checks whether this map holds an entry for the specified key,
ignoring letter case.

**Parameters:**

- `key` ([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)) - The key whose presence in this map is to be tested.

**Returns:** [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) - Boolean `true` if this map contains a mapping for the specified key, otherwise `false`.

**Since:** 1.0

**Example:**

```apex
Boolean result = instance.containsKey('value');
```

### copy

```apex
global UTIL_Map.CaseInsensitiveMap copy()
```

Produces a shallow copy of this CaseInsensitiveMap. The returned
instance is independent; mutations do not propagate between the original and the copy.

**Returns:** [UTIL_Map.CaseInsensitiveMap](UTIL_Map.CaseInsensitiveMap.md) - A new CaseInsensitiveMap instance that is a copy of this one.

**Since:** 1.0

**Example:**

```apex
CaseInsensitiveMap result = instance.copy();
```

### get

```apex
global Object get(String key)
```

Retrieves the value mapped to the supplied key using a
case-insensitive comparison. Returns null when no mapping exists.

**Parameters:**

- `key` ([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)) - The key whose associated value is to be returned.

**Returns:** [Object](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_System_Object.htm) - The value associated with the key, or null if no mapping exists.

**Since:** 1.0

**Example:**

```apex
Object result = instance.get('value');
```

### isEmpty

```apex
global Boolean isEmpty()
```

Indicates whether this map is empty, containing zero entries.

**Returns:** [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) - Boolean `true` if the map is empty, otherwise `false`.

**Since:** 1.0

**Example:**

```apex
Boolean result = instance.isEmpty();
```

### keySet

```apex
global Set<String> keySet()
```

Returns the set of keys in their original, caller-supplied casing.

**Returns:** [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) - A Set of the original keys in the map.

**Since:** 1.0

**Example:**

```apex
Set<String> result = instance.keySet();
```

### put

```apex
global void put(String key, Object value)
```

Stores a value under the given key. If a mapping already exists
for the same key (regardless of letter case), it is replaced.

**Parameters:**

- `key` ([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)) - The key with which the specified value is to be associated.
- `value` ([Object](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_System_Object.htm)) - The value to be associated with the specified key.

**Since:** 1.0

**Example:**

```apex
instance.put('value', 'value');
```

### putAll

```apex
global void putAll(Map<String, Object> sourceMap)
```

Inserts all entries from the supplied map into this map.
Existing mappings whose keys match (case-insensitively) are overwritten.

**Parameters:**

- `sourceMap` ([Map](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_map.htm)) - The map whose entries are to be placed into this map.

**Since:** 1.0

**Example:**

```apex
instance.putAll(new Map<String, Object>{'key' => 'value'});
```

### remove

```apex
global Object remove(String key)
```

Deletes the entry for the given key (case-insensitive match)
and returns the previously associated value.

**Parameters:**

- `key` ([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)) - The key whose mapping is to be removed from the map.

**Returns:** [Object](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_System_Object.htm) - The previous value associated with the key, or null if there was no mapping for the key.

**Since:** 1.0

**Example:**

```apex
Object result = instance.remove('value');
```

### size

```apex
global Integer size()
```

Returns the current number of key-value mappings stored in this map.

**Returns:** [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) - The number of entries in the map.

**Since:** 1.0

**Example:**

```apex
Integer result = instance.size();
```

### toMap

```apex
global Map<String, Object> toMap()
```

Exports the contents of this map to a standard Map ,
restoring the original key casing.

**Returns:** [Object](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_System_Object.htm) - A new `Map<String, Object>` containing all entries from this map.

**Since:** 1.0

**Example:**

```apex
Map<String, Object> result = instance.toMap();
```

### values

```apex
global List<Object> values()
```

Returns all values stored in this map as an ordered list.

**Returns:** [Object](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_System_Object.htm) - A List of the values in the map.

**Since:** 1.0

**Example:**

```apex
List<Object> result = instance.values();
```

