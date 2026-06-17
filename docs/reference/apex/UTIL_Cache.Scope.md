---
title: "UTIL_Cache.Scope"
type: class
pageClass: reference
description: "Cache type enumeration"
since: "1.0"
category: apex
---

# UTIL_Cache.Scope

**Class**

<div class="apex-member apex-class">

```apex
global enum UTIL_Cache.Scope
```

Cache type enumeration

</div>

---

## Inner Classes

| Class | Description |
|-------|-------------|
| [AUTO](#auto) | Auto-select dispatch: Session first, fallback to Org. |
| [IN_TRANSACTION](#in_transaction) | Transaction cache (in-memory, lifetime = current Apex transaction). |
| [ORG](#org) | Org cache (TTL: 5 minutes to 48 hours) |
| [SESSION](#session) | Session cache (TTL: 5 minutes to 8 hours) |

---

## Value Details

### AUTO

```apex
global AUTO
```

Auto-select dispatch: Session first, fallback to Org. Durable-only —
this scope does not silently fall back to per-transaction storage when Platform Cache
is unallocated. Subscribers that want graceful degradation use the
autoWithTransactionFallback() factory instead.

### IN_TRANSACTION

```apex
global IN_TRANSACTION
```

Transaction cache (in-memory, lifetime = current Apex transaction).
Used by inTransaction() and as the fallback tier in autoWithTransactionFallback().
Never serializes; no key-name restrictions; no quota; always available.
Identifier is IN_TRANSACTION because TRANSACTION is a reserved Apex identifier.

### ORG

```apex
global ORG
```

Org cache (TTL: 5 minutes to 48 hours)

### SESSION

```apex
global SESSION
```

Session cache (TTL: 5 minutes to 8 hours)

