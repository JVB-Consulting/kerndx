---
title: "UTIL_Cache.OperationResult"
type: class
pageClass: reference
description: "Result of a cache operation with detailed status information"
since: "1.0"
category: apex
---

# UTIL_Cache.OperationResult

**Class**

<div class="apex-member apex-class">

```apex
global inherited sharing class UTIL_Cache.OperationResult
```

Result of a cache operation with detailed status information

</div>

---

## Constructors

| Constructor | Description |
|-------------|-------------|
| global [OperationResult](#constructors)([Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) success, [UTIL_Cache.Status](UTIL_Cache.Status.md) status, [UTIL_Cache.Scope](UTIL_Cache.Scope.md) cacheTypeUsed) | Constructor for success result |
| global [OperationResult](#constructors)([Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) success, [UTIL_Cache.Status](UTIL_Cache.Status.md) status, [UTIL_Cache.Scope](UTIL_Cache.Scope.md) cacheTypeAttempted, [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) errorMessage) | Constructor for failure result |

### OperationResult(Boolean success, UTIL_Cache.Status status, UTIL_Cache.Scope cacheTypeUsed)

<div class="apex-member">

```apex
global OperationResult(Boolean success, UTIL_Cache.Status status, UTIL_Cache.Scope cacheTypeUsed)
```

Constructor for success result

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `success` | [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) | Whether operation succeeded |
| `status` | [UTIL_Cache.Status](UTIL_Cache.Status.md) | Operation status |
| `cacheTypeUsed` | [UTIL_Cache.Scope](UTIL_Cache.Scope.md) | Cache type used |

**Example**

```apex
UTIL_Cache.OperationResult instance = new UTIL_Cache.OperationResult(true, new Status(), new Scope());
```

</div>

### OperationResult(Boolean success, UTIL_Cache.Status status, UTIL_Cache.Scope cacheTypeAttempted, String errorMessage)

<div class="apex-member">

```apex
global OperationResult(Boolean success, UTIL_Cache.Status status, UTIL_Cache.Scope cacheTypeAttempted, String errorMessage)
```

Constructor for failure result

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `success` | [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) | Whether operation succeeded |
| `status` | [UTIL_Cache.Status](UTIL_Cache.Status.md) | Operation status |
| `cacheTypeAttempted` | [UTIL_Cache.Scope](UTIL_Cache.Scope.md) | Cache type attempted |
| `errorMessage` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | Error message |

**Example**

```apex
UTIL_Cache.OperationResult instance = new UTIL_Cache.OperationResult(true, new Status(), new Scope(), 'An error occurred');
```

</div>

## Fields

| Field | Description |
|-------|-------------|
| global [UTIL_Cache.Scope](UTIL_Cache.Scope.md) [cacheTypeUsed](#cachetypeused) | Cache type used (SESSION, ORG, or null if unavailable) |
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [errorMessage](#errormessage) | Error message if operation failed |
| global [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) [keysFound](#keysfound) | Number of keys found (for read operations) |
| global [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) [keysRequested](#keysrequested) | Number of keys requested (for bulk operations) |
| global [UTIL_Cache.Status](UTIL_Cache.Status.md) [status](#status) | Detailed status of the operation |
| global [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) [success](#success) | Whether the operation succeeded (true for SUCCESS statuses and CACHE_MISS) |

### cacheTypeUsed

```apex
global UTIL_Cache.Scope cacheTypeUsed
```

**Type:** [UTIL_Cache.Scope](UTIL_Cache.Scope.md)

Cache type used (SESSION, ORG, or null if unavailable)

**Example**

```apex
Scope value = instance.cacheTypeUsed;
```

### errorMessage

```apex
global String errorMessage
```

**Type:** [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)

Error message if operation failed

**Example**

```apex
String value = instance.errorMessage;
```

### keysFound

```apex
global Integer keysFound
```

**Type:** [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm)

Number of keys found (for read operations)

**Example**

```apex
Integer value = instance.keysFound;
```

### keysRequested

```apex
global Integer keysRequested
```

**Type:** [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm)

Number of keys requested (for bulk operations)

**Example**

```apex
Integer value = instance.keysRequested;
```

### status

```apex
global UTIL_Cache.Status status
```

**Type:** [UTIL_Cache.Status](UTIL_Cache.Status.md)

Detailed status of the operation

**Example**

```apex
Status value = instance.status;
```

### success

```apex
global Boolean success
```

**Type:** [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm)

Whether the operation succeeded (true for SUCCESS statuses and CACHE_MISS)

**Example**

```apex
Boolean value = instance.success;
```

