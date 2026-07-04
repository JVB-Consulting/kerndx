---
title: "UTIL_Cache"
type: class
description: "Factory for Platform Cache instances with nested interface pattern. Provides intelligent cache management with automatic fallback from Session to Org cache, bulk operations, and user-scoped keys.  Key"
author: "Jason Van Beukering"
group: "Utilities"
date: "December 2025, May 2026"
since: "1.0"
category: apex
---

# UTIL_Cache

**Class** · Group: `Utilities`

```apex
global inherited sharing class UTIL_Cache
```

Factory for Platform Cache instances with nested interface pattern.
Provides intelligent cache management with automatic fallback from Session to Org cache,
bulk operations, and user-scoped keys.

Key Features:

    - **Framework Safe**: Defaults to UTIL_System.getPlatformCacheName() for internal package usage.

    - **Subscriber Ready**: Supports custom partitions via .withPartition().

    - **Governor Friendly**: Uses putAll and getAll to minimize cache commits/reads.

    - **Bulk Optimized**: getAll() uses native Platform Cache bulk retrieval for optimal performance.

    - **Graceful Failure**: Silently handles missing partitions or cache unavailability.

Performance Notes:

    - getAll() and getFromCache() use optimized single-key get() instead of contains() + get() pattern.

    - contains() uses get() instead of contains() to reduce network round-trips.

    - putAll() and removeAll() iterate as Platform Cache does not support bulk operations with TTL.

    - Each cache operation reduces round-trips by eliminating redundant contains() checks.

**Concurrency model — non-atomic across transactions:**
All cache operations are per-transaction. Salesforce Platform Cache exposes NO
compare-and-swap, NO atomic-increment, and NO cross-transaction lock primitive — so a
read-modify-write pattern (e.g. `Integer current = (Integer)cache.get(KEY); cache.put(KEY, current + 1);`)
silently loses 80-95% of writes under realistic 50-100 parallel transaction load (last-writer-wins).
Empirically: the parallel-cache-contention extended load test runs 100 parallel HTTP POSTs each
incrementing the same counter; final counter is consistently `[1, 100]` rather than 100 — i.e. 85-94
lost updates per run. All 100 calls return `WRITE_SUCCESS` from their own transaction's perspective.
For counter-style use cases (rate limiters, dedupe caches, distributed semaphores) persist to a
custom object instead and use SOQL `FOR UPDATE` row locks; that is the only Salesforce-native atomic
primitive. See "Don't Use Cache for Counters or Semaphores" in the Utilities Developer Guide
(Platform Cache Framework → Best Practices) for the full pattern with the seed-the-row prerequisite.

**Since:** 1.0

**Example:**

```apex
UTIL_Cache.Store cache = UTIL_Cache.org();
cache.put('configKey', configValue, 3600);
Object cached = cache.get('configKey');
```

**See Also:** [UTIL_System](UTIL_System.md)

---

## Properties

| Property | Description |
|----------|-------------|
| global enum [Scope](UTIL_Cache.Scope.md) | Cache type enumeration |
| global enum [Status](UTIL_Cache.Status.md) | Operation status enumeration |
| global interface [Store](UTIL_Cache.Store.md) | Interface for Platform Cache operations |

## Methods

| Method | Description |
|--------|-------------|
| global static [UTIL_Cache.Store](UTIL_Cache.Store.md) [auto](#auto)() | Creates a new cache instance backed by Platform Cache (Session → Org). |
| global static [UTIL_Cache.Store](UTIL_Cache.Store.md) [autoWithTransactionFallback](#autowithtransactionfallback)() | Returns a Store that tries Session → Org Platform Cache first and falls back to per-transaction in-memory storage when no Platform Cache scope is available. |
| global static [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [getPlatformCacheName](#getplatformcachename)() | Returns the name of the platform cache partition used by the framework. |
| global static [UTIL_Cache.Store](UTIL_Cache.Store.md) [inTransaction](#intransaction)() | Convenience factory for transaction-scope cache (in-memory, per-Apex-transaction). |
| global static [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) [isAllocated](#isallocated)() | Checks whether the cache partition has capacity allocated by performing a put/get round-trip on each scope independently. |
| global static [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) [isAvailable](#isavailable)() | Checks if Platform Cache is available (static utility) |
| global static [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) [isAvailable](#isavailable)([UTIL_Cache.Scope](UTIL_Cache.Scope.md) cacheType) | Checks if a specific cache type is available (static utility) |
| global static [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) [isOrgAllocated](#isorgallocated)() | Checks whether the Organisation cache scope has capacity allocated by performing a put/get round-trip probe. |
| global static [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) [isSessionAllocated](#issessionallocated)() | Checks whether the Session cache scope has capacity allocated by performing a put/get round-trip probe. |
| global static [UTIL_Cache.Store](UTIL_Cache.Store.md) [org](#org)() | Convenience factory for Org cache with default partition. |
| global static [UTIL_Cache.Store](UTIL_Cache.Store.md) [partition](#partition)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) partitionName) | Convenience factory for custom partition (subscriber orgs). |
| global static [UTIL_Cache.Store](UTIL_Cache.Store.md) [session](#session)() | Convenience factory for Session cache with default partition. |

## Inner Classes

| Class | Description |
|-------|-------------|
| [OperationResult](UTIL_Cache.OperationResult.md) | Result of a cache operation with detailed status information |

---

## Method Details

### auto

```apex
global static UTIL_Cache.Store auto()
```

Creates a new cache instance backed by Platform Cache (Session → Org).
Defaults to the Framework partition defined in UTIL_System.

**Durable-only.** When Platform Cache is unallocated (Session and Org both unavailable),
put/get operations return false / null and OperationResult reports Status.CACHE_UNAVAILABLE
— the failure is loud and visible. This factory does NOT silently fall back to
per-transaction in-memory storage. Use this factory when durability matters (security
keys, distributed counters, cross-transaction state). UTIL_SessionEncryption is the
canonical durability-required caller.

For graceful degradation to per-transaction memory when Platform Cache is missing, use
autoWithTransactionFallback() instead.

**Returns:** [UTIL_Cache.Store](UTIL_Cache.Store.md) - New cache instance

**Since:** 1.0

**Example:**

Basic usage with default configuration:

```apex
UTIL_Cache.Store cache = UTIL_Cache.auto();
cache.put('myKey', 'myValue');
String value = (String)cache.get('myKey');
```

### autoWithTransactionFallback

```apex
global static UTIL_Cache.Store autoWithTransactionFallback()
```

Returns a Store that tries Session → Org Platform Cache first and falls back
to per-transaction in-memory storage when no Platform Cache scope is available.

Use this factory when graceful degradation matters more than strict durability — e.g.
memorizing an expensive describe that benefits from cross-request reuse when available
but does not break if Platform Cache is unallocated.

Behavior:

- When Platform Cache is allocated: identical to auto() (Session → Org).

- When neither Platform Cache scope is allocated: the call succeeds via IN_TRANSACTION
scope. OperationResult.cacheTypeUsed reports the actual scope used (IN_TRANSACTION
when the fallback fired) so callers can detect the degraded path.

- Durability-critical callers (security keys, distributed state, cross-transaction
counters) MUST use auto() — not this factory — so the loud failure signal stays loud
when Platform Cache is missing.

**Returns:** [UTIL_Cache.Store](UTIL_Cache.Store.md) - Store with Session → Org → Transaction fallback chain

**Since:** 1.0

**Example:**

```apex
UTIL_Cache.Store cache = UTIL_Cache.autoWithTransactionFallback();
cache.put('expensiveDescribe', describeResult);
UTIL_Cache.OperationResult result = cache.getLastOperationResult();
if(result.cacheTypeUsed == UTIL_Cache.Scope.IN_TRANSACTION)
{
    // Degraded — Platform Cache unallocated. Cache works for this transaction only.
}
```

### getPlatformCacheName

```apex
global static String getPlatformCacheName()
```

Returns the name of the platform cache partition used by the framework.

**Returns:** [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) - Cache name prefixed with framework namespace (e.g. 'kern.Library')

**Since:** 1.0

**Example:**

```apex
String cacheName = UTIL_Cache.getPlatformCacheName();
```

### inTransaction

```apex
global static UTIL_Cache.Store inTransaction()
```

Convenience factory for transaction-scope cache (in-memory, per-Apex-transaction).
Use for memorizing expensive describes, lazy-loaded singletons, or any value worth computing
once per request but that does not need to survive into the next transaction.

Unlike SESSION and ORG, transaction cache:

- Never serializes (no JSON round-trips, no compression).

- Has no key-name restrictions imposed by Platform Cache.

- Has no quota or partition allocation requirements.

- Is always available (isCacheAvailable() returns true unconditionally).

- Ignores ttlSeconds — implicit TTL is end-of-transaction.

Storage is shared across every inTransaction()-returned Store within the same transaction;
each Store instance has its own getLastOperationResult() so independent callers do not
trample each other's diagnostic state.

**Returns:** [UTIL_Cache.Store](UTIL_Cache.Store.md) - Store backed by the per-transaction in-memory Map

**Since:** 1.0

**Example:**

```apex
UTIL_Cache.Store cache = UTIL_Cache.inTransaction();
cache.put('expensiveDescribe', myDescribeResult);
Object cached = cache.get('expensiveDescribe');
```

### isAllocated

```apex
global static Boolean isAllocated()
```

Checks whether the cache partition has capacity allocated by performing
a put/get round-trip on each scope independently. Tests Org cache first, then Session.
Returns true if either scope can store and retrieve a value.

This approach avoids the AUTO mode fallback issue where Session put reports success
(partition exists) but silently drops data when 0 capacity is allocated.

**Returns:** [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) - True if at least one cache scope (Org or Session) is functional

**Since:** 1.0

**Example:**

```apex
if(UTIL_Cache.isAllocated())
{
    System.debug('Platform Cache is functional');
}
```

### isAvailable

```apex
global static Boolean isAvailable()
```

Checks if Platform Cache is available (static utility)

**Returns:** [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) - True if any cache type is available

**Since:** 1.0

**Example:**

Check if Platform Cache is configured in the org:

```apex
if(UTIL_Cache.isAvailable())
{
    UTIL_Cache.Store cache = UTIL_Cache.auto();
    cache.put('myKey', 'myValue');
}
else
{
    System.debug('Platform Cache not configured');
}
```

### isAvailable

```apex
global static Boolean isAvailable(UTIL_Cache.Scope cacheType)
```

Checks if a specific cache type is available (static utility)

**Parameters:**

- `cacheType` ([UTIL_Cache.Scope](UTIL_Cache.Scope.md)) - The cache type to check

**Returns:** [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) - True if the cache type is available

**Since:** 1.0

**Example:**

Check if a specific cache type is available:

```apex
if(UTIL_Cache.isAvailable(UTIL_Cache.Scope.SESSION))
{
    System.debug('Session cache is available');
}
if(UTIL_Cache.isAvailable(UTIL_Cache.Scope.ORG))
{
    System.debug('Org cache is available');
}
```

### isOrgAllocated

```apex
global static Boolean isOrgAllocated()
```

Checks whether the Organisation cache scope has capacity allocated by performing
a put/get round-trip probe.

**Returns:** [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) - True if Organisation cache can store and retrieve data

**Since:** 1.0

**Example:**

```apex
if(UTIL_Cache.isOrgAllocated())
{
    System.debug('Organisation Cache is functional');
}
```

### isSessionAllocated

```apex
global static Boolean isSessionAllocated()
```

Checks whether the Session cache scope has capacity allocated by performing
a put/get round-trip probe.

**Returns:** [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) - True if Session cache can store and retrieve data

**Since:** 1.0

**Example:**

```apex
if(UTIL_Cache.isSessionAllocated())
{
    System.debug('Session Cache is functional');
}
```

### org

```apex
global static UTIL_Cache.Store org()
```

Convenience factory for Org cache with default partition.
"Easy Button" for the most common use case - persistent org-wide caching.

**Returns:** [UTIL_Cache.Store](UTIL_Cache.Store.md) - Org cache instance using framework default partition

**Since:** 1.0

**Example:**

Quick access to Org cache for persistent data:

```apex
UTIL_Cache.Store cache = UTIL_Cache.org();
cache.put('globalConfig', myConfigObject);
```

### partition

```apex
global static UTIL_Cache.Store partition(String partitionName)
```

Convenience factory for custom partition (subscriber orgs).
"Easy Button" for subscribers to use their local partitions.

**Parameters:**

- `partitionName` ([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)) - Fully qualified partition name (e.g., 'local.MyPartition')

**Returns:** [UTIL_Cache.Store](UTIL_Cache.Store.md) - Cache instance configured for the specified partition

**Since:** 1.0

**Example:**

Subscriber org using custom partition:

```apex
UTIL_Cache.Store cache = UTIL_Cache.partition('local.MyPartition');
cache.put('subscriberData', myData);
```

### session

```apex
global static UTIL_Cache.Store session()
```

Convenience factory for Session cache with default partition.
"Easy Button" for session-scoped caching (max 8 hours).

**Returns:** [UTIL_Cache.Store](UTIL_Cache.Store.md) - Session cache instance using framework default partition

**Since:** 1.0

**Example:**

Quick access to Session cache for temporary user data:

```apex
UTIL_Cache.Store cache = UTIL_Cache.session();
cache.put('userPreferences', prefsMap);
```

