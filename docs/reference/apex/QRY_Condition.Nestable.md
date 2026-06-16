---
title: "QRY_Condition.Nestable"
type: class
pageClass: reference
description: "Interface for condition containers that support adding nested conditions. Extends Evaluable so groups can be passed to QRY_Builder.addCondition()."
since: "1.0"
category: apex
---

# QRY_Condition.Nestable

**Class**

<div class="apex-member apex-class">

```apex
global interface QRY_Condition.Nestable implements QRY_Condition.Evaluable
```

**Implements:** [QRY_Condition.Evaluable](QRY_Condition.Evaluable.md)

**Known Derived Types:** [QRY_Condition.AndCondition.add(QRY_Condition.Evaluable)](QRY_Condition.AndCondition.md#add), [QRY_Condition.OrCondition.add(QRY_Condition.Evaluable)](QRY_Condition.OrCondition.md#add)

Interface for condition containers that support adding nested conditions. Extends Evaluable so groups can be passed to QRY_Builder.addCondition().

</div>

---

## Methods

| Method | Description |
|--------|-------------|
| global abstract [QRY_Condition.Nestable](QRY_Condition.Nestable.md) [add](#add)([QRY_Condition.Evaluable](QRY_Condition.Evaluable.md) condition) | Adds a condition to this group. |

---

## Method Details

### add

<div class="apex-member">

```apex
global abstract QRY_Condition.Nestable add(QRY_Condition.Evaluable condition)
```

Adds a condition to this group.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `condition` | [QRY_Condition.Evaluable](QRY_Condition.Evaluable.md) | The condition to add. |

**Returns** [QRY_Condition.Nestable](QRY_Condition.Nestable.md) — The updated Nestable with the new condition added.

</div>

