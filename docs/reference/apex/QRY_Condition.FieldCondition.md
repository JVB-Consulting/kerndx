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
| global virtual [QRY_Condition.FieldCondition](QRY_Condition.FieldCondition.md) [containsLiteral](#containsliteral)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) compareValue) | Sets the condition to a LIKE comparison that matches the value literally anywhere in the field. |

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

### containsLiteral

<div class="apex-member">

```apex
global virtual QRY_Condition.FieldCondition containsLiteral(String compareValue)
```

Sets the condition to a LIKE comparison that matches the value literally
anywhere in the field. The three characters that carry meaning inside a LIKE pattern are
escaped first: % (any run of characters), _ (any single character), and \ (the escape
character itself). Use this whenever the value came from a person, such as a search box, a
filter or a report parameter, because contains() deliberately leaves those characters their
wildcard meaning: a search for "100%" otherwise matches every value containing "100", and a
search for "UTIL_HttpClient" also matches "UTILxHttpClient". Use contains() when the pattern
is yours and the wildcards are wanted. The escape travels with the bound value, which is the
form every QRY_Builder query executes; it is not preserved if you render the condition to a
SOQL string with toSoql() and run that string yourself.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `compareValue` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The text to match anywhere in the field, character for character. |

**Returns** [QRY_Condition.FieldCondition](QRY_Condition.FieldCondition.md) — The FieldCondition instance for method chaining.

**Example**

```apex
QRY_Condition.OrCondition userSearch = new QRY_Condition.OrCondition();
userSearch.add(new QRY_Condition.FieldCondition(Account.Name).containsLiteral(searchBoxValue));
userSearch.add(new QRY_Condition.FieldCondition(Account.Website).containsLiteral(searchBoxValue));
```

</div>

## Constructors

| Constructor | Description |
|-------------|-------------|
| global [FieldCondition](#constructors)([SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm) objectField) | Constructor for FieldCondition with a specified SObjectField. |
| global [FieldCondition](#constructors)([SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm) objectField, [QRY_Condition.Operator](QRY_Condition.Operator.md) fieldOperator, [Object](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_System_Object.htm) fieldValue) | Builds a condition that compares one field, given as a field token, with one value. |
| global [FieldCondition](#constructors)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) fieldName) | Constructor for FieldCondition with a specified field. |
| global [FieldCondition](#constructors)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) fieldName, [QRY_Condition.Operator](QRY_Condition.Operator.md) fieldOperator, [Object](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_System_Object.htm) fieldValue) | Builds a condition that compares one field with one value. |

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

Builds a condition that compares one field, given as a field token, with one value. The operator must
compare with a single value: IN_X, NOT_IN, INCLUDES and EXCLUDES throw IllegalArgumentException. A null operator
leaves the comparison unset, for contains() or containsLiteral() to set next. When a QRY_Builder query runs, the
value is passed as a bind variable, so you never escape quotes in text yourself.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `objectField` | [SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm) | The field to apply the condition to. |
| `fieldOperator` | [QRY_Condition.Operator](QRY_Condition.Operator.md) | The operator for the condition. |
| `fieldValue` | [Object](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_System_Object.htm) | The value to compare against the field. |

**Example**

```apex
QRY_Condition.FieldCondition instance = new QRY_Condition.FieldCondition(Account.Name, QRY_Condition.Operator.EQUALS, 'Acme');
```

</div>

### FieldCondition(String fieldName)

<div class="apex-member">

```apex
global FieldCondition(String fieldName)
```

Constructor for FieldCondition with a specified field. Pair with contains() to
complete the condition, or use the field-operator-value constructor for other comparisons. The field may also be a
date or distance function from QRY_Function, or toLabel around a field name. Text that comes from a page or a user
must first be matched to a field through a list of fields you allow.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `fieldName` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | A field API name, such as Name or Account.Owner.Name |

**Throws**

| Exception | Description |
|-----------|-------------|
| [IllegalArgumentException](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_classes_exception_methods.htm) | if the text is blank or is not a field name |

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

Builds a condition that compares one field with one value. The field name is trimmed, and a blank name
throws IllegalArgumentException. The operator must compare with a single value: IN_X, NOT_IN, INCLUDES and EXCLUDES
throw IllegalArgumentException. A null operator leaves the comparison unset, for contains() or containsLiteral() to
set next. When a QRY_Builder query runs, the value is passed as a bind variable, so you never escape quotes in text
yourself. The field may also be a date or distance function from QRY_Function, or toLabel around a field name. Text
that comes from a page or a user must first be matched to a field through a list of fields you allow.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `fieldName` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | A field API name, such as Name or Account.Owner.Name |
| `fieldOperator` | [QRY_Condition.Operator](QRY_Condition.Operator.md) | The operator for the condition. |
| `fieldValue` | [Object](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_System_Object.htm) | The value to compare against the field. |

**Throws**

| Exception | Description |
|-----------|-------------|
| [IllegalArgumentException](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_classes_exception_methods.htm) | if the field text is blank or is not a field name, or the operator compares with a list |

**Example**

```apex
QRY_Condition.FieldCondition instance = new QRY_Condition.FieldCondition('Name', QRY_Condition.Operator.EQUALS, 'Acme');
```

</div>

