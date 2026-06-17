---
title: "UTIL_SObjectDescribe.GlobalDescribeMap"
type: class
pageClass: reference
description: "A subclass of NamespacedAttributeMap for handling global describe data returned by getGlobalDescribe."
since: "1.0"
category: apex
---

# UTIL_SObjectDescribe.GlobalDescribeMap

**Class**

<div class="apex-member apex-class">

```apex
global inherited sharing class UTIL_SObjectDescribe.GlobalDescribeMap extends UTIL_SObjectDescribe.NamespacedAttributeMap
```

A subclass of NamespacedAttributeMap for handling global describe data returned by getGlobalDescribe.

</div>

---

## Methods

| Method | Description |
|--------|-------------|
| global override [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) [containsKey](#containskey)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) name) | Checks if the map contains a key with namespace handling enabled by default. |
| global override [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) [containsKey](#containskey)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) name, [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) implyNamespace) | Checks if the map contains a key with optional namespace handling. |
| global [SObjectType](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectType.htm) [get](#get)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) name) | Retrieves an SObjectType by name with namespace handling enabled by default. |
| global [SObjectType](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectType.htm) [get](#get)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) name, [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) implyNamespace) | Retrieves an SObjectType by name with optional namespace handling. |
| global override [Set](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_set.htm)<[String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)> [keySet](#keyset)() | Returns the key set of the map with namespace handling disabled by default. |
| global override [Set](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_set.htm)<[String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)> [keySet](#keyset)([Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) implyNamespace) | Returns the key set of the map with optional namespace handling. |
| global override [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) [size](#size)() | Returns the number of entries in the map. |
| global [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[SObjectType](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectType.htm)> [values](#values)() | Returns the list of SObjectType values in the global describe map. |

### containsKey

<div class="apex-member">

```apex
global override Boolean containsKey(String name)
```

Checks if the map contains a key with namespace handling enabled by default.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `name` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The key to check. |

**Returns** [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) — `true` if the key exists, `false` otherwise.

**Example**

```apex
Boolean result = instance.containsKey('myName');
```

</div>

<div class="apex-member">

```apex
global override Boolean containsKey(String name, Boolean implyNamespace)
```

Checks if the map contains a key with optional namespace handling.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `name` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The key to check. |
| `implyNamespace` | [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) | Whether to handle namespace prefixes. |

**Returns** [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) — `true` if the key exists, `false` otherwise.

**Example**

```apex
Boolean result = instance.containsKey('myName', true);
```

</div>

### get

<div class="apex-member">

```apex
global SObjectType get(String name)
```

Retrieves an `SObjectType` by name with namespace handling enabled by default.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `name` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The API name of the SObject. |

**Returns** [SObjectType](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectType.htm) — The `SObjectType`, or null if not found.

**Example**

```apex
UTIL_SObjectDescribe.GlobalDescribeMap globalDescribe = UTIL_SObjectDescribe.getGlobalDescribe();
SObjectType objType = globalDescribe.get('Account');
System.debug(objType?.getDescribe().getLabel()); // Outputs: Account
```

</div>

<div class="apex-member">

```apex
global SObjectType get(String name, Boolean implyNamespace)
```

Retrieves an `SObjectType` by name with optional namespace handling.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `name` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The API name of the SObject. |
| `implyNamespace` | [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) | Whether to handle namespace prefixes. |

**Returns** [SObjectType](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectType.htm) — The `SObjectType`, or null if not found.

**Example**

```apex
UTIL_SObjectDescribe.GlobalDescribeMap globalDescribe = UTIL_SObjectDescribe.getGlobalDescribe();
SObjectType objType = globalDescribe.get('Account', false);
System.debug(objType?.getDescribe().name); // Outputs: Account
```

</div>

### keySet

<div class="apex-member">

```apex
global override Set<String> keySet()
```

Returns the key set of the map with namespace handling disabled by default.

**Returns** [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) — A set of keys in the map.

**Example**

```apex
Set<String> result = instance.keySet();
```

</div>

<div class="apex-member">

```apex
global override Set<String> keySet(Boolean implyNamespace)
```

Returns the key set of the map with optional namespace handling.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `implyNamespace` | [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) | Whether to strip namespace prefixes from keys. |

**Returns** [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) — A set of keys in the map.

**Example**

```apex
Set<String> result = instance.keySet(true);
```

</div>

### size

<div class="apex-member">

```apex
global override Integer size()
```

Returns the number of entries in the map.

**Returns** [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) — The size of the map.

**Example**

```apex
Integer result = instance.size();
```

</div>

### values

<div class="apex-member">

```apex
global List<SObjectType> values()
```

Returns the list of `SObjectType` values in the global describe map.

**Returns** [SObjectType](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectType.htm) — A list of `SObjectType` instances.

**Example**

```apex
UTIL_SObjectDescribe.GlobalDescribeMap globalDescribe = UTIL_SObjectDescribe.getGlobalDescribe();
List<SObjectType> objTypes = globalDescribe.values();
System.debug(objTypes.size()); // Outputs: Number of SObject types
```

</div>

