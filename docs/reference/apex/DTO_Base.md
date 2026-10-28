---
title: "DTO_Base"
type: class
pageClass: reference
description: "An empty base class for Data Transfer Objects (DTOs). A DTO is a small class that holds the fields you move in or out of your org. This class only declares the methods; on their own they do nothing: s"
author: "Jason Van Beukering"
group: "Data Transfer Objects"
date: "February 2026, October 2026"
since: "1.0"
category: apex
---

# DTO_Base

**Class** · Group: `Data Transfer Objects`

<div class="apex-member apex-class">

```apex
@JsonAccess(serializable='always' deserializable='always') global inherited sharing virtual class DTO_Base
```

**Known Derived Types:** [DTO_BaseTable](DTO_BaseTable.md), [DTO_JsonBase](DTO_JsonBase.md), [DTO_NameValues](DTO_NameValues.md), [DTO_ScheduledParameterDefinition](DTO_ScheduledParameterDefinition.md)

An empty base class for Data Transfer Objects (DTOs). A DTO is a small class that holds the fields you move in or out of your org. This class only declares the methods; on their own they do nothing: serialize() returns an empty string, deserialize() returns the same instance, and populate() and transform() change nothing. Your subclass overrides the methods it needs. For DTOs that convert to and from JSON, extend DTO_JsonBase instead.

**Example**

```apex
public class DTO_AccountSummary extends DTO_Base
{
    public String accountName;
    public override void populate(Id recordId)
    {
        accountName = 'Name read for ' + recordId;
    }
}
DTO_AccountSummary summary = new DTO_AccountSummary();
summary.populate(recordId, new DTO_NameValues());
```

</div>

---

## Methods

| Method | Description |
|--------|-------------|
| global virtual [DTO_Base](DTO_Base.md) [deserialize](#deserialize)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) dtoString) | Turns a string back into a DTO. |
| global virtual void [populate](#populate)([Id](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_id.htm) recordId) | Populates the current DTO instance using the specified triggering object ID. |
| global virtual void [populate](#populate)([Id](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_id.htm) recordId, [DTO_NameValues](DTO_NameValues.md) dtoRequestParameters) | Populates the current DTO instance using the specified triggering object ID and additional request parameters. |
| global virtual [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [serialize](#serialize)() | Returns the DTO as a string. |
| global virtual void [transform](#transform)([DTO_Base](DTO_Base.md) dtoBase) | Transforms the current DTO using another DTO as input. |

### deserialize

<div class="apex-member">

```apex
global virtual DTO_Base deserialize(String dtoString)
```

Turns a string back into a DTO. In this base class it ignores the string and
returns the same instance; override it in your subclass, or extend DTO_JsonBase, to read JSON.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `dtoString` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The string to read. This base class does not read it. |

**Returns** [DTO_Base](DTO_Base.md) — The same instance, unchanged, in this base class.

**Example**

```apex
DTO_Base result = instance.deserialize('value');
```

</div>

### populate

<div class="apex-member">

```apex
global virtual void populate(Id recordId)
```

Populates the current DTO instance using the specified triggering object ID.
This method enables retrieval of relevant data using an ID parameter.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `recordId` | [Id](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_id.htm) | The ID of the object to retrieve data for population. |

**Example**

```apex
instance.populate(recordId);
```

</div>

<div class="apex-member">

```apex
global virtual void populate(Id recordId, DTO_NameValues dtoRequestParameters)
```

Populates the current DTO instance using the specified triggering object ID and
additional request parameters. Allows customized data retrieval and population.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `recordId` | [Id](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_id.htm) | The ID of the object to retrieve data for population. |
| `dtoRequestParameters` | [DTO_NameValues](DTO_NameValues.md) | A list of name values that can be used to change the query or the population of the request DTO |

**Example**

```apex
instance.populate(recordId, new DTO_NameValues());
```

</div>

### serialize

<div class="apex-member">

```apex
global virtual String serialize()
```

Returns the DTO as a string. In this base class it returns an empty string;
override it in your subclass, or extend DTO_JsonBase, to get JSON.

**Returns** [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) — An empty string in this base class.

**Example**

```apex
String result = instance.serialize();
```

</div>

### transform

<div class="apex-member">

```apex
global virtual void transform(DTO_Base dtoBase)
```

Transforms the current DTO using another DTO as input. This method allows
flexibility for child classes to implement their own transformation logic.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `dtoBase` | [DTO_Base](DTO_Base.md) | The input DTO to transform from. |

**Example**

```apex
instance.transform(new DTO_Base());
```

</div>

