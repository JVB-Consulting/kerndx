---
title: "QRY_Condition.OrCondition"
type: class
description: "Represents a SOQL \"OR\" condition group."
since: "1.0"
category: apex
---

# QRY_Condition.OrCondition

**Class**

```apex
global inherited sharing class QRY_Condition.OrCondition extends QRY_Condition.ConditionGroup
```

**Known Derived Types:** [QRY_Condition.Nestable.add(QRY_Condition.Evaluable)](QRY_Condition.Nestable.md#add)

Represents a SOQL "OR" condition group.

**Since:** 1.0

**Example:**

```apex
QRY_Condition.OrCondition group = new QRY_Condition.OrCondition();
group.add(new QRY_Condition.FieldCondition('Status__c', QRY_Condition.Operator.EQUALS, 'Active'));
group.add(new QRY_Condition.FieldCondition('Status__c', QRY_Condition.Operator.EQUALS, 'Pending'));
```

---

## Methods

| Method | Description |
|--------|-------------|
| global override [QRY_Condition.Nestable](QRY_Condition.Nestable.md) [add](#add)([QRY_Condition.Evaluable](QRY_Condition.Evaluable.md) condition) | Adds a condition to this OR group. |
| global [OrCondition](#orcondition)() | Constructor for creating an OR condition group. |

---

## Method Details

### OrCondition

```apex
global OrCondition()
```

Constructor for creating an OR condition group.

**Since:** 1.0

**Example:**

```apex
QRY_Condition.OrCondition instance = new QRY_Condition.OrCondition();
```

### add

```apex
global override QRY_Condition.Nestable add(QRY_Condition.Evaluable condition)
```

Adds a condition to this OR group.

**Parameters:**

- `condition` ([QRY_Condition.Evaluable](QRY_Condition.Evaluable.md)) - The condition to add.

**Returns:** [QRY_Condition.Nestable](QRY_Condition.Nestable.md) - The current Nestable with the added condition.

**Since:** 1.0

**Example:**

```apex
QRY_Condition.OrCondition group = new QRY_Condition.OrCondition();
group.add(new QRY_Condition.FieldCondition('Status__c', QRY_Condition.Operator.EQUALS, 'Active'));
group.add(new QRY_Condition.FieldCondition('Status__c', QRY_Condition.Operator.EQUALS, 'Pending'));
```

