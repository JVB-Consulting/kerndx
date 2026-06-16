---
title: "QRY_Condition"
type: class
pageClass: reference
description: "Condition infrastructure for building complex SOQL WHERE clauses. Use these classes with QRY_Builder.addCondition() for compound conditions that cannot be expressed with the fluent API alone (e.g., gr"
author: "Jason Van Beukering"
group: "Query Infrastructure"
date: "February 2026, May 2026"
since: "1.0"
category: apex
---

# QRY_Condition

**Class** · Group: `Query Infrastructure`

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

**Since:** 1.0

**Example:**

```apex
QRY_Condition.Evaluable condition = new QRY_Condition.OrCondition()
    .add(new QRY_Condition.FieldCondition(Account.Industry).equals('Tech'))
    .add(new QRY_Condition.FieldCondition(Account.Industry).equals('Finance'));
List<Account> accounts = QRY_Builder.selectFrom(Account.SObjectType)
    .addCondition(condition)
    .toList();
```

**See Also:** [QRY_Builder](QRY_Builder.md)

---

## Properties

| Property | Description |
|----------|-------------|
| global virtual interface [Evaluable](QRY_Condition.Evaluable.md) | Interface for condition classes. |
| global interface [Nestable](QRY_Condition.Nestable.md) | Interface for condition containers that support adding nested conditions. |
| global enum [Operator](QRY_Condition.Operator.md) | SOQL comparison operators used to build query conditions. |
| global enum [UnitOfTime](QRY_Condition.UnitOfTime.md) | Units of time for SOQL date literals. |

## Inner Classes

| Class | Description |
|-------|-------------|
| [AndCondition](QRY_Condition.AndCondition.md) | Represents a SOQL "AND" condition group. |
| [DateLiteral](QRY_Condition.DateLiteral.md) | Provides SOQL date literal values for use in QRY_Builder conditions. |
| [FieldCondition](QRY_Condition.FieldCondition.md) | Represents a condition in a SOQL WHERE clause based on a specific field, operator, and value. |
| [OrCondition](QRY_Condition.OrCondition.md) | Represents a SOQL "OR" condition group. |
| [SoqlOptions](QRY_Condition.SoqlOptions.md) | Options for SOQL generation. |

