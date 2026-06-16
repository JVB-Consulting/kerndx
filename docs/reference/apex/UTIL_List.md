---
title: "UTIL_List"
type: class
description: "Various list utilities for manipulating lists of objects and SObjects. This class provides methods for converting, transforming, sorting, and partitioning lists, as well as utility methods for checkin"
author: "Jason Van Beukering"
group: "Utilities"
date: "February 2026, May 2026"
since: "1.0"
category: apex
---

# UTIL_List

**Class** · Group: `Utilities`

```apex
global inherited sharing class UTIL_List
```

Various list utilities for manipulating lists of objects and SObjects. This class provides methods for converting, transforming, sorting, and partitioning lists, as well as utility methods for checking emptiness and creating typed lists.

**Since:** 1.0

**Example:**

```apex
Boolean empty = UTIL_List.isEmpty(records);
List<List<SObject>> batches = UTIL_List.partition(records, 200);
```

---

## Methods

| Method | Description |
|--------|-------------|
| global static [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) [isEmpty](#isempty)([List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[Object](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_System_Object.htm)> items) | Checks if an object array is empty or null. |
| global static [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) [isNotEmpty](#isnotempty)([List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[Object](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_System_Object.htm)> items) | Checks if an object array is not empty. |
| global static [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[Object](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_System_Object.htm)>> [partition](#partition)([List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[Object](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_System_Object.htm)> objects, [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) partitionSize) | Partitions a list into smaller lists of the specified size. |

---

## Method Details

### isEmpty

```apex
global static Boolean isEmpty(List<Object> items)
```

Checks if an object array is empty or null.

**Parameters:**

- `items` ([List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)) - The array to check.

**Returns:** [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) - True if the array is null or empty, false otherwise.

**Since:** 1.0

**Example:**

```apex
List<Object> emptyList = new List<Object>();
Boolean isEmpty = UTIL_List.isEmpty(emptyList);
System.debug(isEmpty); // Outputs: true
```

### isNotEmpty

```apex
global static Boolean isNotEmpty(List<Object> items)
```

Checks if an object array is not empty.

**Parameters:**

- `items` ([List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)) - The array to check.

**Returns:** [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) - True if the array is not null and not empty, false otherwise.

**Since:** 1.0

**Example:**

```apex
List<Object> numbers = new List<Object>{1, 2};
Boolean isNotEmpty = UTIL_List.isNotEmpty(numbers);
System.debug(isNotEmpty); // Outputs: true
```

### partition

```apex
global static List<List<Object>> partition(List<Object> objects, Integer partitionSize)
```

Partitions a list into smaller lists of the specified size.

**Parameters:**

- `objects` ([List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)) - A list of objects
- `partitionSize` ([Object](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_System_Object.htm)) - The maximum size of each sub-list

**Returns:** [Object](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_System_Object.htm) - A list of sub-lists, each no larger than partitionSize

**Since:** 1.0

**Example:**

```apex
List<List<Object>> batches = UTIL_List.partition(records, 200);
```

