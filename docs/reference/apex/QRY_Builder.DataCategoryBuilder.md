---
title: "QRY_Builder.DataCategoryBuilder"
type: class
pageClass: reference
description: "Fluent builder for WITH DATA CATEGORY filters."
since: "1.0"
category: apex
---

# QRY_Builder.DataCategoryBuilder

**Class**

```apex
global inherited sharing class QRY_Builder.DataCategoryBuilder
```

Fluent builder for WITH DATA CATEGORY filters.

**Since:** 1.0

**Example:**

```apex
List<SObject> articles = QRY_Builder.selectFrom(KnowledgeArticleVersion.SObjectType)
    .fields(new List<String>{'Id', 'Title'})
    .condition('PublishStatus').equals('Online')
    .withDataCategory('Geography__c').at('USA__c')
    .withDataCategory('Product__c').below('Electronics__c')
    .toList();
```

---

## Methods

| Method | Description |
|--------|-------------|
| global [QRY_Builder.Builder](QRY_Builder.Builder.md) [above](#above)([List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)> categoryNames) | Filters to categories above any of the specified categories in the hierarchy. |
| global [QRY_Builder.Builder](QRY_Builder.Builder.md) [above](#above)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) categoryName) | Filters to categories above the specified category in the hierarchy. |
| global [QRY_Builder.Builder](QRY_Builder.Builder.md) [aboveOrBelow](#aboveorbelow)([List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)> categoryNames) | Filters to categories above or below any of the specified categories in the hierarchy. |
| global [QRY_Builder.Builder](QRY_Builder.Builder.md) [aboveOrBelow](#aboveorbelow)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) categoryName) | Filters to categories above or below the specified category in the hierarchy. |
| global [QRY_Builder.Builder](QRY_Builder.Builder.md) [at](#at)([List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)> categoryNames) | Filters to any of the specified categories. |
| global [QRY_Builder.Builder](QRY_Builder.Builder.md) [at](#at)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) categoryName) | Filters to the exact specified category. |
| global [QRY_Builder.Builder](QRY_Builder.Builder.md) [below](#below)([List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)> categoryNames) | Filters to categories below any of the specified categories in the hierarchy. |
| global [QRY_Builder.Builder](QRY_Builder.Builder.md) [below](#below)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) categoryName) | Filters to categories below the specified category in the hierarchy. |

---

## Method Details

### above

<div class="apex-member">

```apex
global QRY_Builder.Builder above(List<String> categoryNames)
```

Filters to categories above any of the specified categories in the hierarchy.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `categoryNames` | [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm) | The category API names |

**Returns** [QRY_Builder.Builder](QRY_Builder.Builder.md) — Builder for chaining

**Throws**

| Exception | Description |
|-----------|-------------|
| [IllegalArgumentException](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_classes_exception_methods.htm) | if categoryNames is null or empty |

**Example**

```apex
.withDataCategory('Geography__c').above(new List<String>{'USA__c', 'Canada__c'})
```

</div>

<div class="apex-member">

```apex
global QRY_Builder.Builder above(String categoryName)
```

Filters to categories above the specified category in the hierarchy.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `categoryName` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The category API name |

**Returns** [QRY_Builder.Builder](QRY_Builder.Builder.md) — Builder for chaining

**Throws**

| Exception | Description |
|-----------|-------------|
| [IllegalArgumentException](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_classes_exception_methods.htm) | if categoryName is blank |

**Example**

```apex
.withDataCategory('Geography__c').above('USA__c')
```

</div>

### aboveOrBelow

<div class="apex-member">

```apex
global QRY_Builder.Builder aboveOrBelow(List<String> categoryNames)
```

Filters to categories above or below any of the specified categories in the hierarchy.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `categoryNames` | [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm) | The category API names |

**Returns** [QRY_Builder.Builder](QRY_Builder.Builder.md) — Builder for chaining

**Throws**

| Exception | Description |
|-----------|-------------|
| [IllegalArgumentException](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_classes_exception_methods.htm) | if categoryNames is null or empty |

**Example**

```apex
.withDataCategory('Audience__c').aboveOrBelow(new List<String>{'External', 'Internal'})
```

</div>

<div class="apex-member">

```apex
global QRY_Builder.Builder aboveOrBelow(String categoryName)
```

Filters to categories above or below the specified category in the hierarchy.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `categoryName` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The category API name |

**Returns** [QRY_Builder.Builder](QRY_Builder.Builder.md) — Builder for chaining

**Throws**

| Exception | Description |
|-----------|-------------|
| [IllegalArgumentException](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_classes_exception_methods.htm) | if categoryName is blank |

**Example**

```apex
.withDataCategory('Audience__c').aboveOrBelow('External')
```

</div>

### at

<div class="apex-member">

```apex
global QRY_Builder.Builder at(List<String> categoryNames)
```

Filters to any of the specified categories.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `categoryNames` | [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm) | The category API names |

**Returns** [QRY_Builder.Builder](QRY_Builder.Builder.md) — Builder for chaining

**Throws**

| Exception | Description |
|-----------|-------------|
| [IllegalArgumentException](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_classes_exception_methods.htm) | if categoryNames is null or empty |

**Example**

```apex
.withDataCategory('Geography__c').at(new List<String>{'USA__c', 'Canada__c'})
```

</div>

<div class="apex-member">

```apex
global QRY_Builder.Builder at(String categoryName)
```

Filters to the exact specified category.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `categoryName` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The category API name |

**Returns** [QRY_Builder.Builder](QRY_Builder.Builder.md) — Builder for chaining

**Throws**

| Exception | Description |
|-----------|-------------|
| [IllegalArgumentException](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_classes_exception_methods.htm) | if categoryName is blank |

**Example**

```apex
.withDataCategory('Geography__c').at('USA__c')
```

</div>

### below

<div class="apex-member">

```apex
global QRY_Builder.Builder below(List<String> categoryNames)
```

Filters to categories below any of the specified categories in the hierarchy.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `categoryNames` | [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm) | The category API names |

**Returns** [QRY_Builder.Builder](QRY_Builder.Builder.md) — Builder for chaining

**Throws**

| Exception | Description |
|-----------|-------------|
| [IllegalArgumentException](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_classes_exception_methods.htm) | if categoryNames is null or empty |

**Example**

```apex
.withDataCategory('Product__c').below(new List<String>{'Electronics__c', 'Clothing__c'})
```

</div>

<div class="apex-member">

```apex
global QRY_Builder.Builder below(String categoryName)
```

Filters to categories below the specified category in the hierarchy.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `categoryName` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The category API name |

**Returns** [QRY_Builder.Builder](QRY_Builder.Builder.md) — Builder for chaining

**Throws**

| Exception | Description |
|-----------|-------------|
| [IllegalArgumentException](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_classes_exception_methods.htm) | if categoryName is blank |

**Example**

```apex
.withDataCategory('Product__c').below('Electronics__c')
```

</div>

