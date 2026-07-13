---
title: "QRY_Condition"
type: class
pageClass: reference
description: "Condition infrastructure for building complex SOQL WHERE clauses. Use these classes with QRY_Builder.addCondition() for compound conditions that cannot be expressed with the fluent API alone (e.g., gr"
author: "Jason Van Beukering"
group: "Query Infrastructure"
date: "February 2026, July 2026"
since: "1.0"
category: apex
---

# QRY_Condition

**Class** · Group: `Query Infrastructure`

<div class="apex-member apex-class">

```apex
global inherited sharing class QRY_Condition
```

Condition infrastructure for building complex SOQL WHERE clauses.
Use these classes with QRY_Builder.addCondition() for compound conditions
that cannot be expressed with the fluent API alone (e.g., grouped OR conditions).

**VISIBILITY**: `global` for subscriber access.

    - Evaluable interface: base type for all conditions

    - Operator enum and constants: comparison operators

    - FieldCondition: field comparisons (=, !=, <, >, LIKE, etc.)

    - OrCondition/AndCondition: grouping conditions

**Example**

```apex
QRY_Condition.OrCondition condition = new QRY_Condition.OrCondition();
condition.add(new QRY_Condition.FieldCondition(Account.Industry, QRY_Condition.Operator.EQUALS, 'Technology'));
condition.add(new QRY_Condition.FieldCondition(Account.Name).contains('Acme'));
List<Account> accounts = QRY_Builder.selectFrom(Account.SObjectType)
    .addCondition(condition)
    .toList();
```

**See Also:** [QRY_Builder](QRY_Builder.md)

</div>

---

## Inner Classes

| Class | Description |
|-------|-------------|
| [AndCondition](QRY_Condition.AndCondition.md) | Represents a SOQL "AND" condition group. |
| [DateLiteral](QRY_Condition.DateLiteral.md) | Provides SOQL date literal values for use in QRY_Builder conditions. |
| [Evaluable](QRY_Condition.Evaluable.md) | Interface for condition classes. |
| [FieldCondition](QRY_Condition.FieldCondition.md) | Represents a condition in a SOQL WHERE clause based on a specific field, operator, and value. |
| [Nestable](QRY_Condition.Nestable.md) | Interface for condition containers that support adding nested conditions. |
| [Operator](QRY_Condition.Operator.md) | SOQL comparison operators used to build query conditions. |
| [OrCondition](QRY_Condition.OrCondition.md) | Represents a SOQL "OR" condition group. |
| [SoqlOptions](QRY_Condition.SoqlOptions.md) | Options for SOQL generation. |
| [UnitOfTime](QRY_Condition.UnitOfTime.md) | Units of time for SOQL date literals. |

