---
title: "UTIL_Cache.Status"
type: class
pageClass: reference
description: "Operation status enumeration"
since: "1.0"
category: apex
---

# UTIL_Cache.Status

**Class**

```apex
global enum UTIL_Cache.Status
```

Operation status enumeration

**Since:** 1.0

---

## Values

| Value | Description |
|----------|-------------|
| global  [CACHE_MISS](#cache_miss) | Cache miss (one or more keys not found, but operation was successful) |
| global  [CACHE_UNAVAILABLE](#cache_unavailable) | Cache partition not available or not configured |
| global  [READ_FAILURE](#read_failure) | Read operation failed due to exception |
| global  [READ_SUCCESS](#read_success) | Read operation succeeded (all requested keys found) |
| global  [REMOVE_FAILURE](#remove_failure) | Remove operation failed due to exception |
| global  [REMOVE_SUCCESS](#remove_success) | Remove operation succeeded |
| global  [WRITE_FAILURE](#write_failure) | Write operation failed due to exception |
| global  [WRITE_SUCCESS](#write_success) | Write operation succeeded |

---

## Value Details

### CACHE_MISS

```apex
global CACHE_MISS
```

Cache miss (one or more keys not found, but operation was successful)

### CACHE_UNAVAILABLE

```apex
global CACHE_UNAVAILABLE
```

Cache partition not available or not configured

### READ_FAILURE

```apex
global READ_FAILURE
```

Read operation failed due to exception

### READ_SUCCESS

```apex
global READ_SUCCESS
```

Read operation succeeded (all requested keys found)

### REMOVE_FAILURE

```apex
global REMOVE_FAILURE
```

Remove operation failed due to exception

### REMOVE_SUCCESS

```apex
global REMOVE_SUCCESS
```

Remove operation succeeded

### WRITE_FAILURE

```apex
global WRITE_FAILURE
```

Write operation failed due to exception

### WRITE_SUCCESS

```apex
global WRITE_SUCCESS
```

Write operation succeeded

