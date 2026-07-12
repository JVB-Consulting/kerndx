---
title: "QRY_Condition.FieldCondition"
type: class
pageClass: reference
description: "Represents a condition in a SOQL WHERE clause based on a specific field, operator, and value."
date: "July 2026"
since: "1.0"
category: apex
---

# QRY_Condition.FieldCondition

**Class**

<div class="apex-member apex-class">

```apex
global virtual class QRY_Condition.FieldCondition implements QRY_Condition.Evaluable, QRY_Condition.BindAware
```

**Implements:** [QRY_Condition.Evaluable](QRY_Condition.Evaluable.md)

Represents a condition in a SOQL WHERE clause based on a specific field, operator, and value.

**Example**

```apex
QRY_Condition.FieldCondition condition = new QRY_Condition.FieldCondition(
    'Status__c', QRY_Condition.Operator.EQUALS, 'Active'
);
```

</div>

---

## Methods

| Method | Description |
|--------|-------------|
| global virtual [QRY_Condition.FieldCondition](QRY_Condition.FieldCondition.md) [contains](#contains)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) compareValue) | Sets the condition to a LIKE comparison that matches the value anywhere in the field (a contains match). |

### contains

<div class="apex-member">

```apex
global virtual QRY_Condition.FieldCondition contains(String compareValue)
```

Sets the condition to a LIKE comparison that matches the value anywhere in the
field (a contains match). This differs from the raw LIKE form (the Operator.LIKE_X
constructor argument), which passes your pattern through verbatim and leaves every % and _
wildcard to you: contains owns the wildcards, wrapping the value in a leading and trailing %
so callers never assemble '%' + value + '%' patterns by hand — the same contract as the query
builder's contains().

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `compareValue` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The text to match anywhere in the field. |

**Returns** [QRY_Condition.FieldCondition](QRY_Condition.FieldCondition.md) — The FieldCondition instance for method chaining.

**Example**

```apex
QRY_Condition.OrCondition textMatch = new QRY_Condition.OrCondition();
textMatch.add(new QRY_Condition.FieldCondition(Account.Name).contains('Acme')); // Name LIKE '%Acme%'
textMatch.add(new QRY_Condition.FieldCondition(Account.Website).contains('acme'));
```

</div>

## Constructors

| Constructor | Description |
|-------------|-------------|
| global [FieldCondition](#constructors)([SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm) objectField) | Constructor for FieldCondition with a specified SObjectField. |
| global [FieldCondition](#constructors)([SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm) objectField, [QRY_Condition.Operator](QRY_Condition.Operator.md) fieldOperator, [Object](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_System_Object.htm) fieldValue) | Constructor for FieldCondition with a specified field, operator, and value. |
| global [FieldCondition](#constructors)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) fieldName) | Constructor for FieldCondition with a specified field. |
| global [FieldCondition](#constructors)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) fieldName, [QRY_Condition.Operator](QRY_Condition.Operator.md) fieldOperator, [Object](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_System_Object.htm) fieldValue) | Constructor for FieldCondition with a specified field, operator, and value. |

### FieldCondition(SObjectField objectField)

<div class="apex-member">

```apex
global FieldCondition(SObjectField objectField)
```

Constructor for FieldCondition with a specified SObjectField. Pair with contains()
to complete the condition, or use the field-operator-value constructor for other comparisons.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `objectField` | [SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm) | The ObjectField to apply the condition to. |

**Example**

```apex
QRY_Condition.Evaluable condition = new QRY_Condition.FieldCondition(Account.Name).contains('Acme');
```

</div>

### FieldCondition(SObjectField objectField, QRY_Condition.Operator fieldOperator, Object fieldValue)

<div class="apex-member">

```apex
global FieldCondition(SObjectField objectField, QRY_Condition.Operator fieldOperator, Object fieldValue)
```

Constructor for FieldCondition with a specified field, operator, and value.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `objectField` | [SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm) | The field to apply the condition to. |
| `fieldOperator` | [QRY_Condition.Operator](QRY_Condition.Operator.md) | The operator for the condition. |
| `fieldValue` | [Object](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_System_Object.htm) | The value to compare against the field. |

**Example**

```apex
QRY_Condition.FieldCondition instance = new QRY_Condition.FieldCondition(Account.Name, new Operator(), 'value');
```

</div>

### FieldCondition(String fieldName)

<div class="apex-member">

```apex
global FieldCondition(String fieldName)
```

Constructor for FieldCondition with a specified field. Pair with contains() to
complete the condition, or use the field-operator-value constructor for other comparisons.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `fieldName` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The field to apply the condition to. |

**Example**

```apex
QRY_Condition.Evaluable condition = new QRY_Condition.FieldCondition('Name').contains('Acme');
```

</div>

### FieldCondition(String fieldName, QRY_Condition.Operator fieldOperator, Object fieldValue)

<div class="apex-member">

```apex
global FieldCondition(String fieldName, QRY_Condition.Operator fieldOperator, Object fieldValue)
```

Constructor for FieldCondition with a specified field, operator, and value.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `fieldName` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The field to apply the condition to. |
| `fieldOperator` | [QRY_Condition.Operator](QRY_Condition.Operator.md) | The operator for the condition. |
| `fieldValue` | [Object](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_System_Object.htm) | The value to compare against the field. |

**Example**

```apex
QRY_Condition.FieldCondition instance = new QRY_Condition.FieldCondition('myName', new Operator(), 'value');
```

</div>

