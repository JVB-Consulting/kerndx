---
title: "QRY_Condition.FieldCondition"
type: class
pageClass: reference
description: "Represents a condition in a SOQL WHERE clause based on a specific field, operator, and value."
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

## Constructors

| Constructor | Description |
|-------------|-------------|
| global [FieldCondition](#constructors)([SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm) objectField, [QRY_Condition.Operator](QRY_Condition.Operator.md) fieldOperator, [Object](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_System_Object.htm) fieldValue) | Constructor for FieldCondition with a specified field, operator, and value. |
| global [FieldCondition](#constructors)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) fieldName, [QRY_Condition.Operator](QRY_Condition.Operator.md) fieldOperator, [Object](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_System_Object.htm) fieldValue) | Constructor for FieldCondition with a specified field, operator, and value. |

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

