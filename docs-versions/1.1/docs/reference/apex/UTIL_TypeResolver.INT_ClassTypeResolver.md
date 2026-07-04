---
title: "UTIL_TypeResolver.INT_ClassTypeResolver"
type: class
description: "Interface for resolving Type objects from class names and chaining resolvers. Custom resolvers must be exception-safe. The default chain implementation (PackageClassResolver.resolveType) delegates to "
since: "1.0"
category: apex
---

# UTIL_TypeResolver.INT_ClassTypeResolver

**Class**

```apex
global interface UTIL_TypeResolver.INT_ClassTypeResolver
```

**Known Derived Types:** [UTIL_TypeResolver.BaseClassResolver](UTIL_TypeResolver.BaseClassResolver.md), [UTIL_TypeResolver.BaseClassResolver.resolveType(String)](UTIL_TypeResolver.BaseClassResolver.md#resolvetype)

Interface for resolving Type objects from class names and chaining resolvers. Custom resolvers must be exception-safe. The default chain implementation (PackageClassResolver.resolveType) delegates to nextResolver?.resolveType(...) via the ?? operator and DOES NOT catch and fall through on exception. A custom resolver that throws will propagate the exception to the caller, bypassing any later resolver in the chain. Implementations should either return null for "I cannot resolve this — try the next resolver" OR catch their own exceptions and convert them to null before returning.

**Since:** 1.0

---

## Methods

| Method | Description |
|--------|-------------|
| global abstract [Type](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_type.htm) [resolveType](#resolvetype)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) typeName) | Resolves a Type object from a class name. |
| global abstract [UTIL_TypeResolver.INT_ClassTypeResolver](UTIL_TypeResolver.INT_ClassTypeResolver.md) [setNext](#setnext)([UTIL_TypeResolver.INT_ClassTypeResolver](UTIL_TypeResolver.INT_ClassTypeResolver.md) nextTypeResolver) | Sets the next resolver in the chain. |

---

## Method Details

### resolveType

```apex
global abstract Type resolveType(String typeName)
```

Resolves a Type object from a class name. Returning `null` signals
"I cannot resolve this — chain falls through to the next resolver." Throwing
propagates to the caller without consulting later resolvers — see the
exception-safety contract on the interface ApexDoc.

**Parameters:**

- `typeName` ([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)) - The name of the class to resolve.

**Returns:** [Type](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_type.htm) - The resolved Type object, or null if not found.

**Since:** 1.0

**Example:**

```apex
INT_ClassTypeResolver resolver = new UTIL_TypeResolver.PackageClassResolver();
Type resolvedType = resolver.resolveType('UTIL_TypeResolver_TEST.MyPackagePrivateClass');
```

### setNext

```apex
global abstract UTIL_TypeResolver.INT_ClassTypeResolver setNext(UTIL_TypeResolver.INT_ClassTypeResolver nextTypeResolver)
```

Sets the next resolver in the chain.

**Parameters:**

- `nextTypeResolver` ([UTIL_TypeResolver.INT_ClassTypeResolver](UTIL_TypeResolver.INT_ClassTypeResolver.md)) - The next resolver to try if this one fails.

**Returns:** [UTIL_TypeResolver.INT_ClassTypeResolver](UTIL_TypeResolver.INT_ClassTypeResolver.md) - The next resolver in the chain.

**Since:** 1.0

**Example:**

```apex
INT_ClassTypeResolver resolver = new UTIL_TypeResolver.PackageClassResolver();
INT_ClassTypeResolver nextResolver = new CustomClassResolver();
resolver.setNext(nextResolver);
```

