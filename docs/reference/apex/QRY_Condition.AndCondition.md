---
title: "QRY_Condition.AndCondition"
type: class
pageClass: reference
description: "Represents a SOQL \"AND\" condition group."
since: "1.0"
category: apex
---

# QRY_Condition.AndCondition

**Class**

<div class="apex-member apex-class">

```apex
global inherited sharing class QRY_Condition.AndCondition extends QRY_Condition.ConditionGroup
```

**Known Derived Types:** [QRY_Condition.Nestable.add(QRY_Condition.Evaluable)](QRY_Condition.Nestable.md#add)

Represents a SOQL "AND" condition group.

**Example**

```apex
QRY_Condition.AndCondition group = new QRY_Condition.AndCondition();
group.add(new QRY_Condition.FieldCondition('Status__c', QRY_Condition.Operator.EQUALS, 'Active'));
group.add(new QRY_Condition.FieldCondition('Type__c', QRY_Condition.Operator.EQUALS, 'Customer'));
```

</div>

---

## Methods

| Method | Description |
|--------|-------------|
| global override [QRY_Condition.Nestable](QRY_Condition.Nestable.md) [add](#add)([QRY_Condition.Evaluable](QRY_Condition.Evaluable.md) condition) | Adds a condition to this AND group. |
| global  [AndCondition](#andcondition)() | Constructor for creating an AND condition group. |

---

## Method Details

### AndCondition

<div class="apex-member">

```apex
global AndCondition()
```

Constructor for creating an AND condition group.

**Example**

```apex
QRY_Condition.AndCondition instance = new QRY_Condition.AndCondition();
```

</div>

### add

<div class="apex-member">

```apex
global override QRY_Condition.Nestable add(QRY_Condition.Evaluable condition)
```

Adds a condition to this AND group.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `condition` | [QRY_Condition.Evaluable](QRY_Condition.Evaluable.md) | The condition to add. |

**Returns** [QRY_Condition.Nestable](QRY_Condition.Nestable.md) — The current Nestable with the added condition.

**Example**

```apex
QRY_Condition.AndCondition group = new QRY_Condition.AndCondition();
group.add(new QRY_Condition.FieldCondition('Status__c', QRY_Condition.Operator.EQUALS, 'Active'));
group.add(new QRY_Condition.FieldCondition('Type__c', QRY_Condition.Operator.EQUALS, 'Customer'));
```

</div>

