---
title: "UTIL_SObjectDescribe.GlobalDescribeMap"
type: class
description: "A subclass of NamespacedAttributeMap for handling global describe data returned by getGlobalDescribe."
since: "1.0"
category: apex
---

# UTIL_SObjectDescribe.GlobalDescribeMap

**Class**

```apex
global inherited sharing class UTIL_SObjectDescribe.GlobalDescribeMap extends UTIL_SObjectDescribe.NamespacedAttributeMap
```

A subclass of NamespacedAttributeMap for handling global describe data returned by getGlobalDescribe.

**Since:** 1.0

---

## Methods

| Method | Description |
|--------|-------------|
| global override [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) [containsKey](#containskey)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) name) | Checks if the map contains a key with namespace handling enabled by default. |
| global override [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) [containsKey](#containskey)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) name, [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) implyNamespace) | Checks if the map contains a key with optional namespace handling. |
| global [SObjectType](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectType.htm) [get](#get)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) name) | Retrieves an SObjectType by name with namespace handling enabled by default. |
| global [SObjectType](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectType.htm) [get](#get)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) name, [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) implyNamespace) | Retrieves an SObjectType by name with optional namespace handling. |
| global override [Set](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_set.htm) [keySet](#keyset)() | Returns the key set of the map with namespace handling disabled by default. |
| global override [Set](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_set.htm) [keySet](#keyset)([Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) implyNamespace) | Returns the key set of the map with optional namespace handling. |
| global override [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) [size](#size)() | Returns the number of entries in the map. |
| global [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm) [values](#values)() | Returns the list of SObjectType values in the global describe map. |

---

## Method Details

### containsKey

```apex
global override Boolean containsKey(String name)
```

Checks if the map contains a key with namespace handling enabled by default.

**Parameters:**

- `name` ([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)) - The key to check.

**Returns:** [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) - `true` if the key exists, `false` otherwise.

**Since:** 1.0

**Example:**

```apex
Boolean result = instance.containsKey('myName');
```

### containsKey

```apex
global override Boolean containsKey(String name, Boolean implyNamespace)
```

Checks if the map contains a key with optional namespace handling.

**Parameters:**

- `name` ([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)) - The key to check.
- `implyNamespace` ([Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm)) - Whether to handle namespace prefixes.

**Returns:** [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) - `true` if the key exists, `false` otherwise.

**Since:** 1.0

**Example:**

```apex
Boolean result = instance.containsKey('myName', true);
```

### get

```apex
global SObjectType get(String name)
```

Retrieves an `SObjectType` by name with namespace handling enabled by default.

**Parameters:**

- `name` ([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)) - The API name of the SObject.

**Returns:** [SObjectType](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectType.htm) - The `SObjectType`, or null if not found.

**Since:** 1.0

**Example:**

```apex
UTIL_SObjectDescribe.GlobalDescribeMap globalDescribe = UTIL_SObjectDescribe.getGlobalDescribe();
SObjectType objType = globalDescribe.get('Account');
System.debug(objType?.getDescribe().getLabel()); // Outputs: Account
```

### get

```apex
global SObjectType get(String name, Boolean implyNamespace)
```

Retrieves an `SObjectType` by name with optional namespace handling.

**Parameters:**

- `name` ([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)) - The API name of the SObject.
- `implyNamespace` ([Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm)) - Whether to handle namespace prefixes.

**Returns:** [SObjectType](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectType.htm) - The `SObjectType`, or null if not found.

**Since:** 1.0

**Example:**

```apex
UTIL_SObjectDescribe.GlobalDescribeMap globalDescribe = UTIL_SObjectDescribe.getGlobalDescribe();
SObjectType objType = globalDescribe.get('Account', false);
System.debug(objType?.getDescribe().name); // Outputs: Account
```

### keySet

```apex
global override Set<String> keySet()
```

Returns the key set of the map with namespace handling disabled by default.

**Returns:** [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) - A set of keys in the map.

**Since:** 1.0

**Example:**

```apex
Set<String> result = instance.keySet();
```

### keySet

```apex
global override Set<String> keySet(Boolean implyNamespace)
```

Returns the key set of the map with optional namespace handling.

**Parameters:**

- `implyNamespace` ([Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm)) - Whether to strip namespace prefixes from keys.

**Returns:** [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) - A set of keys in the map.

**Since:** 1.0

**Example:**

```apex
Set<String> result = instance.keySet(true);
```

### size

```apex
global override Integer size()
```

Returns the number of entries in the map.

**Returns:** [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) - The size of the map.

**Since:** 1.0

**Example:**

```apex
Integer result = instance.size();
```

### values

```apex
global List<SObjectType> values()
```

Returns the list of `SObjectType` values in the global describe map.

**Returns:** [SObjectType](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectType.htm) - A list of `SObjectType` instances.

**Since:** 1.0

**Example:**

```apex
UTIL_SObjectDescribe.GlobalDescribeMap globalDescribe = UTIL_SObjectDescribe.getGlobalDescribe();
List<SObjectType> objTypes = globalDescribe.values();
System.debug(objTypes.size()); // Outputs: Number of SObject types
```

