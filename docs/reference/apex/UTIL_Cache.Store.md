---
title: "UTIL_Cache.Store"
type: class
pageClass: reference
description: "Interface for Platform Cache operations"
since: "1.0"
category: apex
---

# UTIL_Cache.Store

**Class**

<div class="apex-member apex-class">

```apex
global interface UTIL_Cache.Store
```

Interface for Platform Cache operations

</div>

---

## Methods

| Method | Description |
|--------|-------------|
| global abstract [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) [contains](#contains)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) key) | Checks if a key exists in cache |
| global abstract [Object](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_System_Object.htm) [get](#get)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) key) | Retrieves a value from cache. |
| global abstract [Map](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_map.htm)<[String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm), [Object](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_System_Object.htm)> [getAll](#getall)([Set](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_set.htm)<[String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)> keys) | Retrieves multiple values from cache |
| global abstract [UTIL_Cache.OperationResult](UTIL_Cache.OperationResult.md) [getLastOperationResult](#getlastoperationresult)() | Gets the result of the last cache operation for diagnostics |
| global abstract [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) [isCacheAvailable](#iscacheavailable)() | Checks if Platform Cache is available for the configured partition |
| global abstract [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) [put](#put)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) key, [Object](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_System_Object.htm) value) | Stores a value in cache with default TTL. |
| global abstract [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) [put](#put)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) key, [Object](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_System_Object.htm) value, [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) ttlSeconds) | Stores a value in cache with custom TTL. |
| global abstract [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) [putAll](#putall)([Map](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_map.htm)<[String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm), [Object](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_System_Object.htm)> valuesMap) | Stores multiple values in cache with default TTL |
| global abstract [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) [putAll](#putall)([Map](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_map.htm)<[String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm), [Object](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_System_Object.htm)> valuesMap, [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) ttlSeconds) | Stores multiple values in cache with custom TTL |
| global abstract [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) [remove](#remove)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) key) | Removes a value from cache |
| global abstract [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) [removeAll](#removeall)([Set](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_set.htm)<[String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)> keys) | Removes multiple keys from cache |
| global abstract [UTIL_Cache.Store](UTIL_Cache.Store.md) [withPartition](#withpartition)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) partitionName) | Sets the partition name (fluent API) |
| global abstract [UTIL_Cache.Store](UTIL_Cache.Store.md) [withScope](#withscope)([UTIL_Cache.Scope](UTIL_Cache.Scope.md) cacheType) | Sets the cache type preference (fluent API) |
| global abstract [UTIL_Cache.Store](UTIL_Cache.Store.md) [withUserScope](#withuserscope)([Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) userScoped) | Enables or disables user-scoped keys (fluent API) |

### contains

<div class="apex-member">

```apex
global abstract Boolean contains(String key)
```

Checks if a key exists in cache

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `key` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The cache key |

**Returns** [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) — True if key exists in cache

</div>

### get

<div class="apex-member">

```apex
global abstract Object get(String key)
```

Retrieves a value from cache.

**Warning — read-modify-write is unsafe across parallel transactions.** A `get`
paired with a subsequent `put` to mutate the value is non-atomic; concurrent
transactions reading the same key see the same pre-mutation value and overwrite
each other on `put`. See the class-level "Concurrency model" note.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `key` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The cache key |

**Returns** [Object](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_System_Object.htm) — The cached value or null if not found

</div>

### getAll

<div class="apex-member">

```apex
global abstract Map<String, Object> getAll(Set<String> keys)
```

Retrieves multiple values from cache

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `keys` | [Set](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_set.htm) | Set of keys to retrieve |

**Returns** [Object](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_System_Object.htm) — Map of Key -> Value (found items only)

</div>

### getLastOperationResult

<div class="apex-member">

```apex
global abstract UTIL_Cache.OperationResult getLastOperationResult()
```

Gets the result of the last cache operation for diagnostics

**Returns** [UTIL_Cache.OperationResult](UTIL_Cache.OperationResult.md) — Last operation result with detailed status information

</div>

### isCacheAvailable

<div class="apex-member">

```apex
global abstract Boolean isCacheAvailable()
```

Checks if Platform Cache is available for the configured partition

**Returns** [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) — True if cache is available

</div>

### put

<div class="apex-member">

```apex
global abstract Boolean put(String key, Object value)
```

Stores a value in cache with default TTL.

**Warning — non-atomic against concurrent writes.** Platform Cache exposes no
compare-and-swap and no cross-transaction lock, so a read-modify-write loop
(`get` → mutate → `put`) loses 80-95% of writes under 50-100 parallel transaction
contention. For counter-style use cases (rate limiters, dedupe, semaphores) use a
custom object with SOQL `FOR UPDATE` row locks instead.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `key` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The cache key |
| `value` | [Object](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_System_Object.htm) | The value to cache |

**Returns** [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) — True if stored successfully

</div>

<div class="apex-member">

```apex
global abstract Boolean put(String key, Object value, Integer ttlSeconds)
```

Stores a value in cache with custom TTL.

**Warning — non-atomic against concurrent writes.** Same caveat as the no-TTL
overload: read-modify-write across parallel transactions silently loses writes.
See the class-level "Concurrency model" note.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `key` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The cache key |
| `value` | [Object](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_System_Object.htm) | The value to cache |
| `ttlSeconds` | [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) | TTL in seconds (null uses default) |

**Returns** [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) — True if stored successfully

</div>

### putAll

<div class="apex-member">

```apex
global abstract Boolean putAll(Map<String, Object> valuesMap)
```

Stores multiple values in cache with default TTL

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `valuesMap` | [Map](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_map.htm) | Map of Key -> Value to store |

**Returns** [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) — True if operation was attempted

</div>

<div class="apex-member">

```apex
global abstract Boolean putAll(Map<String, Object> valuesMap, Integer ttlSeconds)
```

Stores multiple values in cache with custom TTL

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `valuesMap` | [Map](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_map.htm) | Map of Key -> Value to store |
| `ttlSeconds` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | TTL in seconds |

**Returns** [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) — True if operation was attempted

</div>

### remove

<div class="apex-member">

```apex
global abstract Boolean remove(String key)
```

Removes a value from cache

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `key` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The cache key |

**Returns** [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) — True if removed successfully

</div>

### removeAll

<div class="apex-member">

```apex
global abstract Boolean removeAll(Set<String> keys)
```

Removes multiple keys from cache

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `keys` | [Set](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_set.htm) | Set of keys to remove |

**Returns** [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) — True if operation completed

</div>

### withPartition

<div class="apex-member">

```apex
global abstract UTIL_Cache.Store withPartition(String partitionName)
```

Sets the partition name (fluent API)

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `partitionName` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The fully qualified partition name (e.g., 'local.MyPartition') |

**Returns** [UTIL_Cache.Store](UTIL_Cache.Store.md) — This instance

</div>

### withScope

<div class="apex-member">

```apex
global abstract UTIL_Cache.Store withScope(UTIL_Cache.Scope cacheType)
```

Sets the cache type preference (fluent API)

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `cacheType` | [UTIL_Cache.Scope](UTIL_Cache.Scope.md) | The cache type to prefer (SESSION, ORG, AUTO) |

**Returns** [UTIL_Cache.Store](UTIL_Cache.Store.md) — This instance

</div>

### withUserScope

<div class="apex-member">

```apex
global abstract UTIL_Cache.Store withUserScope(Boolean userScoped)
```

Enables or disables user-scoped keys (fluent API)

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `userScoped` | [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) | Whether to scope keys by current user |

**Returns** [UTIL_Cache.Store](UTIL_Cache.Store.md) — This instance

</div>

