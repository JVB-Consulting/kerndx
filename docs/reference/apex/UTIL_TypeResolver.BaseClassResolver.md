---
title: "UTIL_TypeResolver.BaseClassResolver"
type: class
pageClass: reference
description: "Abstract base class for implementing custom type resolvers, typically registered via custom metadata."
since: "1.0"
category: apex
---

# UTIL_TypeResolver.BaseClassResolver

**Class**

<div class="apex-member apex-class">

```apex
global abstract class UTIL_TypeResolver.BaseClassResolver implements UTIL_TypeResolver.INT_ClassTypeResolver
```

**Implements:** [UTIL_TypeResolver.INT_ClassTypeResolver](UTIL_TypeResolver.INT_ClassTypeResolver.md)

**Known Derived Types:** [UTIL_TypeResolver.INT_ClassTypeResolver.resolveType(String)](UTIL_TypeResolver.INT_ClassTypeResolver.md#resolvetype)

Abstract base class for implementing custom type resolvers, typically registered via custom metadata.

**See Also:** [ClassTypeResolver__mdt](../metadata/ClassTypeResolver__mdt.md)

</div>

---

## Methods

| Method | Description |
|--------|-------------|
| global abstract [Type](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_type.htm) [resolveType](#resolvetype)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) typeName) | Override this in your own resolver. |

### resolveType

<div class="apex-member">

```apex
global abstract Type resolveType(String typeName)
```

Override this in your own resolver. Return the Type of the named class when your code can find it.
Otherwise return nextResolver?.resolveType(typeName): nextResolver is null on the last resolver in the chain,
so that call gives null when no resolver finds the class. Do not throw: an exception stops the chain and
reaches the caller.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `typeName` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The name of the class to resolve. |

**Returns** [Type](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_type.htm) — The resolved Type object, or null if not found.

**Example**

```apex
global with sharing class MyCompany_TypeResolver extends UTIL_TypeResolver.BaseClassResolver
{
    public override Type resolveType(String typeName)
    {
        return Type.forName(typeName) ?? nextResolver?.resolveType(typeName);
    }
}
UTIL_TypeResolver.BaseClassResolver resolver = new MyCompany_TypeResolver();
Type resolvedType = resolver.resolveType('MyCompany_Service');
```

</div>

## Fields

| Field | Description |
|-------|-------------|
| global [UTIL_TypeResolver.INT_ClassTypeResolver](UTIL_TypeResolver.INT_ClassTypeResolver.md) [nextResolver](#nextresolver) | Holds the reference to the next resolver in the chain. |

### nextResolver

```apex
global UTIL_TypeResolver.INT_ClassTypeResolver nextResolver
```

**Type:** [UTIL_TypeResolver.INT_ClassTypeResolver](UTIL_TypeResolver.INT_ClassTypeResolver.md)

Holds the reference to the next resolver in the chain.

**Example**

```apex
INT_ClassTypeResolver value = instance.nextResolver;
```

