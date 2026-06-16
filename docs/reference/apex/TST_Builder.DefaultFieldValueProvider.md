---
title: "TST_Builder.DefaultFieldValueProvider"
type: class
pageClass: reference
description: "Base class for field-level default value providers. @note Using a virtual class instead of an interface allows adding new methods in future managed package versions without breaking existing implement"
since: "1.0"
category: apex
---

# TST_Builder.DefaultFieldValueProvider

**Class**

```apex
global virtual class TST_Builder.DefaultFieldValueProvider
```

Base class for field-level default value providers. @note Using a virtual class instead of an interface allows adding new methods in future managed package versions without breaking existing implementations.

**Since:** 1.0

---

## Methods

| Method | Description |
|--------|-------------|
| global virtual [Object](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_System_Object.htm) [getValue](#getvalue)([Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) recordIndex) | Gets the wrapped value for a given record index. |

---

## Method Details

### getValue

<div class="apex-member">

```apex
global virtual Object getValue(Integer recordIndex)
```

Gets the wrapped value for a given record index.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `recordIndex` | [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) | The index of the record (e.g., 0 for the first record, 1 for the second). |

**Returns** [Object](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_System_Object.htm) — The value for the specified index.

**Example**

```apex
global override Object getValue(Integer recordIndex)
{
    return 'Record ' + recordIndex;
}
```

</div>

