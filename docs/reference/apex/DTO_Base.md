---
title: "DTO_Base"
type: class
description: "A base Data Transfer Object (DTO) class for storing JSON content, providing utility methods for serialization, deserialization, and transformation of DTOs. Supports pretty-print formatting for JSON co"
author: "Jason Van Beukering"
group: "Data Transfer Objects"
date: "February 2026, May 2026"
since: "1.0"
category: apex
---

# DTO_Base

**Class** · Group: `Data Transfer Objects`

```apex
@JsonAccess(serializable='always' deserializable='always') global inherited sharing virtual class DTO_Base
```

**Known Derived Types:** [DTO_BaseTable](DTO_BaseTable.md), [DTO_JsonBase](DTO_JsonBase.md), [DTO_NameValues](DTO_NameValues.md), [DTO_ScheduledParameterDefinition](DTO_ScheduledParameterDefinition.md)

A base Data Transfer Object (DTO) class for storing JSON content, providing utility methods for serialization, deserialization, and transformation of DTOs. Supports pretty-print formatting for JSON content.

**Since:** 1.0

**Example:**

```apex
DTO_Base dto = new DTO_Base();
String json = dto.serialize();
dto.populate(recordId, new DTO_NameValues());
```

---

## Methods

| Method | Description |
|--------|-------------|
| global virtual [DTO_Base](DTO_Base.md) [deserialize](#deserialize)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) dtoString) | Deserializes a JSON string and populates a new instance of DTO_Base with the deserialized data, enabling conversion from JSON format back into a DTO. |
| global virtual void [populate](#populate)([Id](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_id.htm) recordId) | Populates the current DTO instance using the specified triggering object ID. |
| global virtual void [populate](#populate)([Id](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_id.htm) recordId, [DTO_NameValues](DTO_NameValues.md) dtoRequestParameters) | Populates the current DTO instance using the specified triggering object ID and additional request parameters. |
| global virtual [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [serialize](#serialize)() | Serializes the current DTO object to a JSON string. |
| global virtual void [transform](#transform)([DTO_Base](DTO_Base.md) dtoBase) | Transforms the current DTO using another DTO as input. |

---

## Method Details

### deserialize

```apex
global virtual DTO_Base deserialize(String dtoString)
```

Deserializes a JSON string and populates a new instance of `DTO_Base` with
the deserialized data, enabling conversion from JSON format back into a DTO.

**Parameters:**

- `dtoString` ([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)) - A JSON-formatted string that can be converted to a DTO.

**Returns:** [DTO_Base](DTO_Base.md) - A `DTO_Base` instance populated with data from the provided JSON string.

**Since:** 1.0

**Example:**

```apex
DTO_Base result = instance.deserialize('value');
```

### populate

```apex
global virtual void populate(Id recordId)
```

Populates the current DTO instance using the specified triggering object ID.
This method enables retrieval of relevant data using an ID parameter.

**Parameters:**

- `recordId` ([Id](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_id.htm)) - The ID of the object to retrieve data for population.

**Since:** 1.0

**Example:**

```apex
instance.populate(recordId);
```

```apex
global virtual void populate(Id recordId, DTO_NameValues dtoRequestParameters)
```

Populates the current DTO instance using the specified triggering object ID and
additional request parameters. Allows customized data retrieval and population.

**Parameters:**

- `recordId` ([Id](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_id.htm)) - The ID of the object to retrieve data for population.
- `dtoRequestParameters` ([DTO_NameValues](DTO_NameValues.md)) - A list of name values that can be used to change the query or the population of the request DTO

**Since:** 1.0

**Example:**

```apex
instance.populate(recordId, new DTO_NameValues());
```

### serialize

```apex
global virtual String serialize()
```

Serializes the current DTO object to a JSON string. This method provides a
string representation of the DTO for storage or transfer.

**Returns:** [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) - A serialized JSON string representing the DTO.

**Since:** 1.0

**Example:**

```apex
String result = instance.serialize();
```

### transform

```apex
global virtual void transform(DTO_Base dtoBase)
```

Transforms the current DTO using another DTO as input. This method allows
flexibility for child classes to implement their own transformation logic.

**Parameters:**

- `dtoBase` ([DTO_Base](DTO_Base.md)) - The input DTO to transform from.

**Since:** 1.0

**Example:**

```apex
instance.transform(new DTO_Base());
```

