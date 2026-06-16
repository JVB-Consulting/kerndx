---
title: "TST_Builder"
type: class
pageClass: reference
description: "An advanced factory for creating and inserting SObject records for Apex tests. This class provides a flexible way to generate test data, automatically handling required fields and complex object relat"
author: "Jason Van Beukering"
group: "Testing"
date: "February 2026, May 2026"
since: "1.0"
category: apex
---

# TST_Builder

**Class** · Group: `Testing`

```apex
global inherited sharing class TST_Builder
```

**Known Derived Types:** [UTIL_SObjectBuilderDefaultProvider](UTIL_SObjectBuilderDefaultProvider.md)

An advanced factory for creating and inserting SObject records for Apex tests. This class provides a flexible way to generate test data, automatically handling required fields and complex object relationships using a fluid builder pattern.

**Since:** 1.0

**Example:**

```apex
Account account = (Account)TST_Builder.of(Account.SObjectType).build();
Account inMemory = (Account)TST_Builder.of(Account.SObjectType).withoutInsertion().build();
Account custom = (Account)TST_Builder.of(Account.SObjectType)
    .withOverride(Account.Name, 'Acme Corp').build();
List<SObject> accounts = TST_Builder.of(Account.SObjectType).withCount(5).buildList();
```

**See Also:** [UTIL_SObjectBuilderDefaultProvider](UTIL_SObjectBuilderDefaultProvider.md)

---

## Properties

| Property | Description |
|----------|-------------|
| global static [TST_Builder.DefaultFieldValueProvider](TST_Builder.DefaultFieldValueProvider.md) [autoDefaultFieldValueProvider](#autodefaultfieldvalueprovider) | A special marker value that signals the factory to generate a default value for a field, even if it's not required. |
| global static [TST_Builder.DefaultValueProvider](TST_Builder.DefaultValueProvider.md) [defaultValueProvider](#defaultvalueprovider) | Overrides the default value provider instance with a custom implementation. |
| global static [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[Object](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_System_Object.htm)> [optionalFields](#optionalfields) | A static list of fields to treat as optional for the current transaction's build operations. |

## Methods

| Method | Description |
|--------|-------------|
| global static [TST_Builder.Builder](TST_Builder.Builder.md) [of](#of)([SObjectType](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectType.htm) objectType) | Starts a new SObject build operation for the specified SObjectType. |
| global static [TST_Builder.Builder](TST_Builder.Builder.md) [of](#of)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) sObjectName) | Starts a new SObject build operation for the specified SObject API name. |

## Inner Classes

| Class | Description |
|-------|-------------|
| [Builder](TST_Builder.Builder.md) | A fluid builder for configuring and creating SObject records. |
| [DefaultFieldValueProvider](TST_Builder.DefaultFieldValueProvider.md) | Base class for field-level default value providers. |
| [DefaultValueProvider](TST_Builder.DefaultValueProvider.md) | Base class for default value providers. |

---

## Property Details

### autoDefaultFieldValueProvider

```apex
global static TST_Builder.DefaultFieldValueProvider autoDefaultFieldValueProvider
```

**Type:** [TST_Builder.DefaultFieldValueProvider](TST_Builder.DefaultFieldValueProvider.md)

A special marker value that signals the factory to generate a default value for a field,
even if it's not required. Use this in field override maps to request automatic value generation.

Since:


Example:

### defaultValueProvider

```apex
global static TST_Builder.DefaultValueProvider defaultValueProvider
```

**Type:** [TST_Builder.DefaultValueProvider](TST_Builder.DefaultValueProvider.md)

Overrides the default value provider instance with a custom implementation.
This allows developers to define custom logic for generating default field values.
To customize, extend 'UTIL_SObjectBuilderDefaultProvider' and assign an instance here.

Since:


Example:

### optionalFields

```apex
global static List<Object> optionalFields
```

**Type:** [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)

A static list of fields to treat as optional for the current transaction's build operations.
Fields added to this list will not be automatically populated with default values, even if they are required.

Since:


Example:

---

## Method Details

### of

<div class="apex-member">

```apex
global static TST_Builder.Builder of(SObjectType objectType)
```

Starts a new SObject build operation for the specified SObjectType.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `objectType` | [SObjectType](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectType.htm) | The SObjectType of the SObject to create. |

**Returns** [TST_Builder.Builder](TST_Builder.Builder.md) — A new Builder instance to configure and execute the build.

**Example**

```apex
// Build a single Account in memory with a specific name
Account account = (Account)TST_Builder.of(Account.SObjectType)
	.withOverrides(new Map<String, Object>{ 'Name' => 'Test Account' })
	.withoutInsertion()
	.build();
```

</div>

<div class="apex-member">

```apex
global static TST_Builder.Builder of(String sObjectName)
```

Starts a new SObject build operation for the specified SObject API name.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `sObjectName` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The API name of the SObject to create. |

**Returns** [TST_Builder.Builder](TST_Builder.Builder.md) — A new Builder instance to configure and execute the build.

**Example**

```apex
// Build and insert a list of 5 Foobars
List<SObject> fooBars = TST_Builder.of('Foobar__c')
	.withCount(5)
	.buildList();
```

</div>

