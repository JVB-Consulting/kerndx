---
title: "UTIL_Limits.LimitCheck"
type: class
pageClass: reference
description: "Fluent limit inspector scoped to a single governor limit type. Provides methods to check remaining budget, usage percentage, exhaustion, and threshold proximity."
since: "1.0"
category: apex
---

# UTIL_Limits.LimitCheck

**Class**

<div class="apex-member apex-class">

```apex
global class UTIL_Limits.LimitCheck
```

Fluent limit inspector scoped to a single governor limit type. Provides methods to check remaining budget, usage percentage, exhaustion, and threshold proximity.

</div>

---

## Methods

| Method | Description |
|--------|-------------|
| global [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) [isExhausted](#isexhausted)() | Returns whether the limit has been fully consumed (no remaining budget). |
| global [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) [isNearLimit](#isnearlimit)([Decimal](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_decimal.htm) threshold) | Returns whether usage has reached or exceeded the given threshold. |
| global [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) [maximum](#maximum)() | Returns the maximum allowed units for this limit type. |
| global [Decimal](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_decimal.htm) [percentUsed](#percentused)() | Returns the percentage of the limit consumed as a value between 0.0 and 1.0. |
| global [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) [remaining](#remaining)() | Returns the number of limit units remaining before the governor limit is hit. |
| global [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) [used](#used)() | Returns the number of limit units consumed in this transaction. |

### isExhausted

<div class="apex-member">

```apex
global Boolean isExhausted()
```

Returns whether the limit has been fully consumed (no remaining budget).

**Returns** [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) — True when remaining() is less than or equal to zero

</div>

### isNearLimit

<div class="apex-member">

```apex
global Boolean isNearLimit(Decimal threshold)
```

Returns whether usage has reached or exceeded the given threshold. Values greater
than 1.0 are automatically normalised by dividing by 100 (e.g. 80 becomes 0.8).

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `threshold` | [Decimal](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_decimal.htm) | The threshold as a decimal (0.0–1.0) or percentage (e.g. 80 for 80%) |

**Returns** [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) — True when percentUsed() is at or above the normalised threshold

</div>

### maximum

<div class="apex-member">

```apex
global Integer maximum()
```

Returns the maximum allowed units for this limit type.

**Returns** [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) — Governor limit maximum

</div>

### percentUsed

<div class="apex-member">

```apex
global Decimal percentUsed()
```

Returns the percentage of the limit consumed as a value between 0.0 and 1.0.

**Returns** [Decimal](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_decimal.htm) — Usage percentage (0.0 = none used, 1.0 = fully exhausted)

</div>

### remaining

<div class="apex-member">

```apex
global Integer remaining()
```

Returns the number of limit units remaining before the governor limit is hit.

**Returns** [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) — Remaining budget (maximum - used)

</div>

### used

<div class="apex-member">

```apex
global Integer used()
```

Returns the number of limit units consumed in this transaction.

**Returns** [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) — Current usage count

</div>

## Fields

| Field | Description |
|-------|-------------|
| global final [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [label](#label) | The human-readable label for this limit type (e.g. |

### label

```apex
global final String label
```

**Type:** [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)

The human-readable label for this limit type (e.g. "Callouts", "Queries").

