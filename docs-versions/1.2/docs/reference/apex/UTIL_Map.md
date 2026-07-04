---
title: "UTIL_Map"
type: class
pageClass: reference
description: "Static helper methods for common Map operations in Apex, including key-value transformation, entry joining, equality comparison, SObject indexing, and case-insensitive lookups."
author: "Jason Van Beukering"
group: "Utilities"
date: "February 2026, May 2026"
since: "1.0"
category: apex
---

# UTIL_Map

**Class** · Group: `Utilities`

<div class="apex-member apex-class">

```apex
global inherited sharing class UTIL_Map
```

Static helper methods for common Map operations in Apex, including key-value transformation, entry joining, equality comparison, SObject indexing, and case-insensitive lookups.

**Example**

```apex
Map<String, String> params = new Map<String, String>{'key' => 'value', 'name' => 'test'};
String delimited = UTIL_Map.toDelimitedString(params, ',');
```

</div>

---

## Methods

| Method | Description |
|--------|-------------|
| global static [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm)> [flattenValues](#flattenvalues)([Map](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_map.htm)<[Id](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_id.htm), [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm)>> idMap) | Collapses an Id-keyed map of SObject lists into a single flat list containing every record. |
| global static [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm)> [flattenValues](#flattenvalues)([Map](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_map.htm)<[String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm), [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm)>> stringMap) | Collapses a String-keyed map of SObject lists into a single flat list containing every record. |
| global static [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [toDelimitedString](#todelimitedstring)([Map](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_map.htm)<[String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm), [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)> valuesByNameMap, [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) separator) | Serialises a map of name-value pairs into a single delimited string of the form name=value[separator]name=value. |

### flattenValues

<div class="apex-member">

```apex
global static List<SObject> flattenValues(Map<Id, List<SObject>> idMap)
```

Collapses an Id-keyed map of SObject lists into a single flat list containing every record.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `idMap` | [Map](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_map.htm) | A map where the value is a list of SObjects and the key is an Id |

**Returns** [SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm) — A list containing all the SObjects from the map

**Example**

```apex
Map<Id, List<SObject>> contactsByAccount = new Map<Id, List<SObject>>();
List<SObject> allContacts = UTIL_Map.flattenValues(contactsByAccount);
```

</div>

<div class="apex-member">

```apex
global static List<SObject> flattenValues(Map<String, List<SObject>> stringMap)
```

Collapses a String-keyed map of SObject lists into a single flat list containing every record.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `stringMap` | [Map](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_map.htm) | A map where the value is a list of SObjects and the key is a string |

**Returns** [SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm) — A list containing all the SObjects from the map

**Example**

```apex
Map<String, List<SObject>> recordsByType = new Map<String, List<SObject>>();
List<SObject> allRecords = UTIL_Map.flattenValues(recordsByType);
```

</div>

### toDelimitedString

<div class="apex-member">

```apex
global static String toDelimitedString(Map<String, String> valuesByNameMap, String separator)
```

Serialises a map of name-value pairs into a single delimited string of the form name=value[separator]name=value.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `valuesByNameMap` | [Map](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_map.htm) | A map of name and values |
| `separator` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The separator to use between pairs; defaults to comma if null |

**Returns** [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) — A string in the format paramName=paramValue[separator]paramName2=paramValue2

**Example**

```apex
Map<String, String> params = new Map<String, String>{ 'key1' => 'value1', 'key2' => 'value2' };
String result = UTIL_Map.toDelimitedString(params, ',');
```

</div>

## Inner Classes

| Class | Description |
|-------|-------------|
| [CaseInsensitiveMap](UTIL_Map.CaseInsensitiveMap.md) | A Map implementation that performs case-insensitive key lookups. |

---

