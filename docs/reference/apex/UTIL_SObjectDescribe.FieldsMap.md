---
title: "UTIL_SObjectDescribe.FieldsMap"
type: class
description: "A subclass of NamespacedAttributeMap for handling field maps returned by DescribeSObjectResult.fields.getMap()."
since: "1.0"
category: apex
---

# UTIL_SObjectDescribe.FieldsMap

**Class**

```apex
global inherited sharing class UTIL_SObjectDescribe.FieldsMap extends UTIL_SObjectDescribe.NamespacedAttributeMap
```

A subclass of NamespacedAttributeMap for handling field maps returned by DescribeSObjectResult.fields.getMap().

**Since:** 1.0

---

## Methods

| Method | Description |
|--------|-------------|
| global override [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) [containsKey](#containskey)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) name) | Checks if the map contains a key with namespace handling enabled by default. |
| global override [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) [containsKey](#containskey)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) name, [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) implyNamespace) | Checks if the map contains a key with optional namespace handling. |
| global [SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm) [get](#get)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) name) | Retrieves an SObjectField by name with namespace handling enabled by default. |
| global [SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm) [get](#get)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) name, [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) implyNamespace) | Retrieves an SObjectField by name with optional namespace handling. |
| global override [Set](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_set.htm)<[String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)> [keySet](#keyset)() | Returns the key set of the map with namespace handling disabled by default. |
| global override [Set](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_set.htm)<[String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)> [keySet](#keyset)([Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) implyNamespace) | Returns the key set of the map with optional namespace handling. |
| global override [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) [size](#size)() | Returns the number of entries in the map. |
| global [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm)> [values](#values)() | Returns the list of SObjectField values in the map. |

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
global SObjectField get(String name)
```

Retrieves an `SObjectField` by name with namespace handling enabled by default.

**Parameters:**

- `name` ([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)) - The API name of the field.

**Returns:** [SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm) - The `SObjectField`, or null if not found.

**Since:** 1.0

**Example:**

```apex
UTIL_SObjectDescribe describe = UTIL_SObjectDescribe.getDescribe('Contact');
SObjectField field = describe.getFields().get('Email');
System.debug(field?.getDescribe().getLabel()); // Outputs: Email
```

```apex
global SObjectField get(String name, Boolean implyNamespace)
```

Retrieves an `SObjectField` by name with optional namespace handling.

**Parameters:**

- `name` ([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)) - The API name of the field.
- `implyNamespace` ([Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm)) - Whether to handle namespace prefixes.

**Returns:** [SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm) - The `SObjectField`, or null if not found.

**Since:** 1.0

**Example:**

```apex
UTIL_SObjectDescribe describe = UTIL_SObjectDescribe.getDescribe('Contact');
SObjectField field = describe.getFields().get('Account', false);
System.debug(field?.getDescribe().name); // Outputs: AccountId
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
global List<SObjectField> values()
```

Returns the list of `SObjectField` values in the map.

**Returns:** [SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm) - A list of `SObjectField` instances.

**Since:** 1.0

**Example:**

```apex
UTIL_SObjectDescribe describe = UTIL_SObjectDescribe.getDescribe('Account');
List<SObjectField> fields = describe.getFields().values();
System.debug(fields.size()); // Outputs: Number of fields on Account
```

