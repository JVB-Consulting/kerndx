---
title: "UTIL_System"
type: class
pageClass: reference
description: "Namespace, type resolution, and platform utility methods. Provides runtime introspection for managed package namespace detection, class type resolution, API version retrieval, and session management."
author: "Jason Van Beukering"
group: "Utilities"
date: "February 2026, June 2026"
since: "1.0"
category: apex
---

# UTIL_System

**Class** · Group: `Utilities`

<div class="apex-member apex-class">

```apex
global inherited sharing class UTIL_System
```

Namespace, type resolution, and platform utility methods. Provides runtime introspection for managed package namespace detection, class type resolution, API version retrieval, and session management.

**Example**

```apex
String namespace = UTIL_System.getManagedPackageNamespace();
Type handlerType = UTIL_System.getTypeForClassName('TRG_SetFoobarDefaults');
Type validated = UTIL_System.getTypeForClassName('TRG_SetFoobarDefaults', IF_Trigger.BeforeInsert.class);
```

</div>

---

## Methods

| Method | Description |
|--------|-------------|
| global static [Type](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_type.htm) [findTypeForClassName](#findtypeforclassname)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) className) | Resolves a class name to a Type via the UTIL_TypeResolver chain without throwing an exception. |
| global static [Type](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_type.htm) [findTypeForClassName](#findtypeforclassname)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) className, [Type](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_type.htm) expectedType) | Resolves a class name to a Type via the UTIL_TypeResolver chain and verifies it is assignable to the expected type. |
| global static [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [getApiEnabledSessionId](#getapienabledsessionid)() | Will render a VF page to retrieve an API Enabled Session Id for current user To improve performance, session will be cached |
| global static [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [getClassNamespace](#getclassnamespace)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) className) | Will extract the namespace out of a class name, expects the class to be a top level class |
| global static [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [getManagedPackageNamespace](#getmanagedpackagenamespace)() | Will determine the namespace for the current execution context; ie. |
| global static [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [getManagedPackageNamespacePrefix](#getmanagedpackagenamespaceprefix)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) delimiter) | Will determine the namespace for the current execution context; ie. |
| global static [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [getNamespacePrefix](#getnamespaceprefix)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) namespace, [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) delimiter) | Will calculate namespace prefix as follows: if the namespace exists - namespace + delimiter else Empty String |
| global static [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [getOrgApiVersion](#getorgapiversion)() | Will determine the current Salesforce Org Api Version |
| global static [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [getRuntimeTypeName](#getruntimetypename)([Object](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_System_Object.htm) anObject) | This method serves to retrieve the type name of the provided object |
| global static [Type](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_type.htm) [getTypeForClassName](#gettypeforclassname)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) className) | Will return the Type for a given object class name |
| global static [Type](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_type.htm) [getTypeForClassName](#gettypeforclassname)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) className, [Type](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_type.htm) expectedType) | Will return the Type for a given object class name |

### findTypeForClassName

<div class="apex-member">

```apex
global static Type findTypeForClassName(String className)
```

Resolves a class name to a Type via the UTIL_TypeResolver chain without throwing
an exception. Returns null when the class cannot be found or has compilation errors.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `className` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The class name to resolve. |

**Returns** [Type](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_type.htm) — The resolved Type, or null if not found.

**Example**

```apex
Type classType = UTIL_System.findTypeForClassName('SCHED_DeactivateUsers');
```

</div>

<div class="apex-member">

```apex
global static Type findTypeForClassName(String className, Type expectedType)
```

Resolves a class name to a Type via the UTIL_TypeResolver chain and verifies it
is assignable to the expected type. Returns null when the class cannot be found or does not
implement the expected type.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `className` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The class name to resolve. |
| `expectedType` | [Type](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_type.htm) | The type the resolved class must be assignable to. |

**Returns** [Type](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_type.htm) — The resolved Type, or null if not found or not assignable.

**Example**

```apex
Type classType = UTIL_System.findTypeForClassName('SCHED_DeactivateUsers', Schedulable.class);
```

</div>

### getApiEnabledSessionId

<div class="apex-member">

```apex
global static String getApiEnabledSessionId()
```

Will render a VF page to retrieve an API Enabled Session Id for current user
To improve performance, session will be cached

**Returns** [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) — API enabled Session Id

**Example**

```apex
String sessionId = UTIL_System.getApiEnabledSessionId();
```

</div>

### getClassNamespace

<div class="apex-member">

```apex
global static String getClassNamespace(String className)
```

Will extract the namespace out of a class name, expects the class to be a top level class

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `className` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The name of the class |

**Returns** [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) — Empty String or the namespace

**Example**

```apex
String namespace = UTIL_System.getClassNamespace('kern.UTIL_System'); // 'kern'
String empty = UTIL_System.getClassNamespace('MyClass'); // ''
```

</div>

### getManagedPackageNamespace

<div class="apex-member">

```apex
global static String getManagedPackageNamespace()
```

Will determine the namespace for the current execution context;
ie. Is code currently running sitting in a package and the namespace of the package

**Returns** [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) — Empty String or the package namespace

**Example**

```apex
String namespace = UTIL_System.getManagedPackageNamespace(); // e.g. 'kern' or ''
```

</div>

### getManagedPackageNamespacePrefix

<div class="apex-member">

```apex
global static String getManagedPackageNamespacePrefix(String delimiter)
```

Will determine the namespace for the current execution context;
ie. Is code currently running sitting in a package and the namespace of the package
and add the provided delimiter (if a namespace exists)

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `delimiter` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The delimiter for the item |

**Returns** [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) — Empty String or the namespace with prefix

**Example**

```apex
// Returns 'Sfdc_Surveys.' when namespace exists with '.' delimiter
String namespaceWithDot = UTIL_System.getManagedPackageNamespacePrefix('.');
// Returns 'Sfdc_Surveys__' when namespace exists with '__' delimiter
String namespaceWithUnderscores = UTIL_System.getManagedPackageNamespacePrefix('__');
// Returns '' when namespace does not exist
```

</div>

### getNamespacePrefix

<div class="apex-member">

```apex
global static String getNamespacePrefix(String namespace, String delimiter)
```

Will calculate namespace prefix as follows:
if the namespace exists - namespace + delimiter
else Empty String

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `namespace` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The provided namespace |
| `delimiter` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The delimiter for the item |

**Returns** [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) — Empty String or the namespace with prefix

**Example**

```apex
String prefix = UTIL_System.getNamespacePrefix('kern', '.'); // 'kern.'
```

</div>

### getOrgApiVersion

<div class="apex-member">

```apex
global static String getOrgApiVersion()
```

Will determine the current Salesforce Org Api Version

**Returns** [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) — the version in the form of "59.0"

**Example**

```apex
String version = UTIL_System.getOrgApiVersion(); // e.g. '65.0'
```

</div>

### getRuntimeTypeName

<div class="apex-member">

```apex
global static String getRuntimeTypeName(Object anObject)
```

This method serves to retrieve the type name of the provided object

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `anObject` | [Object](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_System_Object.htm) | The object to evaluate |

**Returns** [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) — Name of Class of the Object provided

**Example**

```apex
String typeName = UTIL_System.getRuntimeTypeName((Object)'Hello'); // 'String'
```

</div>

### getTypeForClassName

<div class="apex-member">

```apex
global static Type getTypeForClassName(String className)
```

Will return the Type for a given object class name

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `className` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The class name to find a type for (please ensure that you prefix namespace if required) |

**Returns** [Type](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_type.htm) — The type of the object

**Throws**

| Exception | Description |
|-----------|-------------|
| [IllegalArgumentException](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_classes_exception_methods.htm) | If no type if found for the given class name |

**Example**

```apex
Type classType = UTIL_System.getTypeForClassName('UTIL_System');
```

</div>

<div class="apex-member">

```apex
global static Type getTypeForClassName(String className, Type expectedType)
```

Will return the Type for a given object class name

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `className` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The class name to find a type for (please ensure that you prefix namespace if required) |
| `expectedType` | [Type](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_type.htm) | The expected type that the type for the class is assignable from |

**Returns** [Type](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_type.htm) — The type of the object

**Throws**

| Exception | Description |
|-----------|-------------|
| [IllegalArgumentException](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_classes_exception_methods.htm) | If no type if found for the given class name |
| [TypeException](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_classes_exception_methods.htm) | if the type is not compatible with the expected type |

**Example**

```apex
Type classType = UTIL_System.getTypeForClassName('UTIL_System', Object.class);
```

</div>

