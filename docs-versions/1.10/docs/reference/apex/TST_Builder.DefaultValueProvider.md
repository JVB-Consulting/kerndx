---
title: "TST_Builder.DefaultValueProvider"
type: class
pageClass: reference
description: "Base class for default value providers. Extend 'UTIL_SObjectBuilderDefaultProvider' (which extends this class) to customize default value generation. @note Using a virtual class instead of an interfac"
since: "1.0"
category: apex
---

# TST_Builder.DefaultValueProvider

**Class**

<div class="apex-member apex-class">

```apex
global virtual class TST_Builder.DefaultValueProvider
```

**Known Derived Types:** [UTIL_SObjectBuilderDefaultProvider](UTIL_SObjectBuilderDefaultProvider.md)

Base class for default value providers. Extend 'UTIL_SObjectBuilderDefaultProvider' (which extends this class) to customize default value generation. @note Using a virtual class instead of an interface allows adding new methods in future managed package versions without breaking the providers you have already written.

</div>

---

## Methods

| Method | Description |
|--------|-------------|
| global virtual [Map](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_map.htm)<[String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm), [TST_Builder.DefaultFieldValueProvider](TST_Builder.DefaultFieldValueProvider.md)> [getDefaultMapOfValues](#getdefaultmapofvalues)([SObjectType](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectType.htm) sObjectType, [Map](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_map.htm)<[String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm), [Object](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_System_Object.htm)> mapOfValuesOverride) | Returns the value providers for the fields the builder fills on a new record. |

### getDefaultMapOfValues

<div class="apex-member">

```apex
global virtual Map<String, TST_Builder.DefaultFieldValueProvider> getDefaultMapOfValues(SObjectType sObjectType, Map<String, Object> mapOfValuesOverride)
```

Returns the value providers for the fields the builder fills on a new record. The builder calls
this once for each build, before it makes the records. It then sets every field named in the map on each
record, and asks that field's provider for the value of each record. This base version returns an empty map.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `sObjectType` | [SObjectType](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectType.htm) | The SObjectType. |
| `mapOfValuesOverride` | [Map](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_map.htm) | A map of override values. |

**Returns** [TST_Builder.DefaultFieldValueProvider](TST_Builder.DefaultFieldValueProvider.md) — A map of default field values, keyed by fully-qualified field name (e.g., 'Name' or 'Account.Name').

**Example**

```apex
global override Map<String, DefaultFieldValueProvider> getDefaultMapOfValues(SObjectType sObjectType, Map<String, Object> mapOfValuesOverride)
{
    Map<String, DefaultFieldValueProvider> defaults = super.getDefaultMapOfValues(sObjectType, mapOfValuesOverride);
    // add custom default providers
    return defaults;
}
```

</div>

