---
title: "QRY_Condition.Evaluable"
type: class
pageClass: reference
description: "Interface for condition classes. Pass to QRY_Builder.addCondition()."
since: "1.0"
category: apex
---

# QRY_Condition.Evaluable

**Class**

```apex
global virtual interface QRY_Condition.Evaluable
```

**Known Derived Types:** [QRY_Condition.DateLiteral](QRY_Condition.DateLiteral.md), [QRY_Condition.FieldCondition](QRY_Condition.FieldCondition.md), [QRY_Condition.Nestable](QRY_Condition.Nestable.md)

Interface for condition classes. Pass to QRY_Builder.addCondition().

**Since:** 1.0

**Example:**

```apex
interface value = instance.Evaluable;
```

---

## Methods

| Method | Description |
|--------|-------------|
| global abstract [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [toSoql](#tosoql)() | Converts the condition to a SOQL query string. |
| global abstract [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [toSoql](#tosoql)([QRY_Condition.SoqlOptions](QRY_Condition.SoqlOptions.md) options) | Converts the condition to a SOQL query string using specific options. |

---

## Method Details

### toSoql

<div class="apex-member">

```apex
global abstract String toSoql()
```

Converts the condition to a SOQL query string.

**Returns** [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) — A valid SOQL query string.

</div>

<div class="apex-member">

```apex
global abstract String toSoql(QRY_Condition.SoqlOptions options)
```

Converts the condition to a SOQL query string using specific options.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `options` | [QRY_Condition.SoqlOptions](QRY_Condition.SoqlOptions.md) | The SOQL options for customization. |

**Returns** [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) — A valid SOQL query string.

</div>

