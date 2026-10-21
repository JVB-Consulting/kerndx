---
title: "UTIL_TypeResolver"
type: class
pageClass: reference
description: "Utility class containing type resolution components for resolving Apex class types."
author: "Jason Van Beukering"
group: "Utilities"
date: "March 2025, June 2026"
since: "1.0"
category: apex
---

# UTIL_TypeResolver

**Class** · Group: `Utilities`

<div class="apex-member apex-class">

```apex
global inherited sharing class UTIL_TypeResolver
```

Utility class containing type resolution components for resolving Apex class types.

**Example**

```apex
UTIL_TypeResolver.INT_ClassTypeResolver resolver = UTIL_TypeResolver.getClassResolver();
Type handlerType = resolver.resolveType('TRG_SetFoobarDefaults');
```

</div>

---

## Methods

| Method | Description |
|--------|-------------|
| global static [UTIL_TypeResolver.INT_ClassTypeResolver](UTIL_TypeResolver.INT_ClassTypeResolver.md) [getClassResolver](#getclassresolver)() | Retrieves the configured resolver chain with the package resolver as the first link. |

### getClassResolver

<div class="apex-member">

```apex
global static UTIL_TypeResolver.INT_ClassTypeResolver getClassResolver()
```

Retrieves the configured resolver chain with the package resolver as the first link.

**Returns** [UTIL_TypeResolver.INT_ClassTypeResolver](UTIL_TypeResolver.INT_ClassTypeResolver.md) — The configured resolver chain.

**Example**

```apex
INT_ClassTypeResolver resolver = UTIL_TypeResolver.getClassResolver();
Type resolvedType = resolver.resolveType('UTIL_TypeResolver_TEST.MyPackagePrivateClass');
```

</div>

## Inner Classes

| Class | Description |
|-------|-------------|
| [BaseClassResolver](UTIL_TypeResolver.BaseClassResolver.md) | Abstract base class for implementing custom type resolvers, typically registered via custom metadata. |
| [INT_ClassTypeResolver](UTIL_TypeResolver.INT_ClassTypeResolver.md) | Interface for resolving Type objects from class names and chaining resolvers. |

---

