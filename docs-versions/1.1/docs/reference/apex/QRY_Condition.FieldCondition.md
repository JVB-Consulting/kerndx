---
title: "QRY_Condition.FieldCondition"
type: class
description: "Represents a condition in a SOQL WHERE clause based on a specific field, operator, and value."
since: "1.0"
category: apex
---

# QRY_Condition.FieldCondition

**Class**

```apex
global virtual class QRY_Condition.FieldCondition implements QRY_Condition.Evaluable, QRY_Condition.BindAware
```

**Implements:** [QRY_Condition.Evaluable](QRY_Condition.Evaluable.md)

Represents a condition in a SOQL WHERE clause based on a specific field, operator, and value.

**Since:** 1.0

**Example:**

```apex
QRY_Condition.FieldCondition condition = new QRY_Condition.FieldCondition(
    'Status__c', QRY_Condition.Operator.EQUALS, 'Active'
);
```

---

## Methods

| Method | Description |
|--------|-------------|
| global [FieldCondition](#fieldcondition)([SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm) objectField, [QRY_Condition.Operator](QRY_Condition.Operator.md) fieldOperator, [Object](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_System_Object.htm) fieldValue) | Constructor for FieldCondition with a specified field, operator, and value. |
| global [FieldCondition](#fieldcondition)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) fieldName, [QRY_Condition.Operator](QRY_Condition.Operator.md) fieldOperator, [Object](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_System_Object.htm) fieldValue) | Constructor for FieldCondition with a specified field, operator, and value. |

---

## Method Details

### FieldCondition

```apex
global FieldCondition(SObjectField objectField, QRY_Condition.Operator fieldOperator, Object fieldValue)
```

Constructor for FieldCondition with a specified field, operator, and value.

**Parameters:**

- `objectField` ([SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm)) - The field to apply the condition to.
- `fieldOperator` ([QRY_Condition.Operator](QRY_Condition.Operator.md)) - The operator for the condition.
- `fieldValue` ([Object](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_System_Object.htm)) - The value to compare against the field.

**Since:** 1.0

**Example:**

```apex
QRY_Condition.FieldCondition instance = new QRY_Condition.FieldCondition(Account.Name, new Operator(), 'value');
```

### FieldCondition

```apex
global FieldCondition(String fieldName, QRY_Condition.Operator fieldOperator, Object fieldValue)
```

Constructor for FieldCondition with a specified field, operator, and value.

**Parameters:**

- `fieldName` ([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)) - The field to apply the condition to.
- `fieldOperator` ([QRY_Condition.Operator](QRY_Condition.Operator.md)) - The operator for the condition.
- `fieldValue` ([Object](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_System_Object.htm)) - The value to compare against the field.

**Since:** 1.0

**Example:**

```apex
QRY_Condition.FieldCondition instance = new QRY_Condition.FieldCondition('myName', new Operator(), 'value');
```

