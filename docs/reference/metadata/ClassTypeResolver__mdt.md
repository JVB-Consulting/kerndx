---
title: "ClassTypeResolver__mdt"
type: sobject
pageClass: reference
description: "Registers a subscriber-org class that resolves Apex class names to Types at runtime. Required when subscriber classes used by the framework (e.g., trigger handlers, web services, DTOs) are not declare"
category: metadata
---

# ClassTypeResolver__mdt

**Sobject**

```apex
global class ClassTypeResolver__mdt extends SObject
```

**Extends:** [SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm)

Registers a subscriber-org class that resolves Apex class names to Types at runtime. Required when subscriber classes used by the framework (e.g., trigger handlers, web services, DTOs) are not declared as global. The registered class must implement the framework's type resolver interface.

---

## Fields

| Field | Description |
|-------|-------------|
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [ClassName__c](#classname__c) | The fully qualified name of the subscriber-org class that implements the framework's type resolver interface. |
| global [Decimal](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_decimal.htm) [Order__c](#order__c) | The execution priority for this resolver relative to other resolvers. |

---

## Field Details

### ClassName__c

```apex
global String ClassName__c
```

The fully qualified name of the subscriber-org class that implements the framework's type resolver interface. Used to resolve non-global class names for web services, triggers, and DTOs.

**Field Attributes:**

| Attribute | Value |
|-----------|-------|
| Data Type | Text(100), case-insensitive |
| Required | false |
| Unique | true |
| External ID | false |

### Order__c

```apex
global Decimal Order__c
```

The execution priority for this resolver relative to other resolvers. Resolvers are chained in ascending order (e.g., 1, then 2, then 3). The first resolver to successfully resolve a class name wins.

**Field Attributes:**

| Attribute | Value |
|-----------|-------|
| Data Type | Number(2,0) |
| Required | false |
| Unique | false |
| External ID | false |

