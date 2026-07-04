---
title: "DTO_JsonBase"
type: class
description: "A Data Transfer Object (DTO) base class for JSON serialization and deserialization, providing a framework for transforming JSON data into structured objects and vice versa. Inherited by other DTO clas"
author: "Jason Van Beukering"
group: "Web Services"
date: "February 2026, May 2026"
since: "1.0"
category: apex
---

# DTO_JsonBase

**Class** · Group: `Web Services`

```apex
@JsonAccess(serializable='always' deserializable='always') global inherited sharing virtual class DTO_JsonBase extends DTO_Base
```

**Extends:** [DTO_Base](DTO_Base.md)

**Known Derived Types:** [DTO_BaseTable](DTO_BaseTable.md), [DTO_NameValues](DTO_NameValues.md), [DTO_ScheduledParameterDefinition](DTO_ScheduledParameterDefinition.md)

A Data Transfer Object (DTO) base class for JSON serialization and deserialization, providing a framework for transforming JSON data into structured objects and vice versa. Inherited by other DTO classes that require JSON handling capabilities.

**Since:** 1.0

**Example:**

```apex
@JsonAccess(Serializable='always' Deserializable='always')
public class DTO_Invoice extends DTO_JsonBase
{
    public String invoiceId;
    public String status;
}
```

---

## Methods

| Method | Description |
|--------|-------------|
| global override virtual [DTO_Base](DTO_Base.md) [deserialize](#deserialize)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) dtoString) | Deserializes a JSON string into an instance of the current DTO class. |
| global virtual [Type](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_type.htm) [getObjectType](#getobjecttype)() | Retrieves the type of the current DTO, used when deserializing JSON data back into an instance of the specific class. |
| global override virtual [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [serialize](#serialize)() | Serializes the current DTO instance into a JSON string, omitting null values to create a compact JSON representation. |

---

## Method Details

### deserialize

```apex
global override virtual DTO_Base deserialize(String dtoString)
```

Deserializes a JSON string into an instance of the current DTO class. Uses the
`getObjectType` method to identify the appropriate class for deserialization.
The returned instance is populated with values from the provided JSON string.

**Parameters:**

- `dtoString` ([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)) - A JSON string representing the serialized data for the DTO.

**Returns:** [DTO_Base](DTO_Base.md) - A deserialized DTO instance populated with values from the JSON string.

**Since:** 1.0

**Example:**

```apex
DTO_Base result = instance.deserialize('value');
```

**See Also:** [DTO_JsonBase.getObjectType](#getobjecttype)

### getObjectType

```apex
global virtual Type getObjectType()
```

Retrieves the type of the current DTO, used when deserializing JSON data back into an instance of the specific class.
Implementing this method in descendant classes is required only if the class is private; to properly deserialize.

**Returns:** [Type](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_type.htm) - The class type of the DTO.

**Throws:**

- [IllegalArgumentException](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_classes_exception_methods.htm) - if the current class name can't be resolved to a Type (due to the class not being publicly visible)

**Since:** 1.0

**Example:**

```apex
Type result = instance.getObjectType();
```

### serialize

```apex
global override virtual String serialize()
```

Serializes the current DTO instance into a JSON string, omitting null values
to create a compact JSON representation. Useful for sending structured data
over web services in a lightweight format.

**Returns:** [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) - A JSON string representation of the current DTO, excluding null values.

**Since:** 1.0

**Example:**

```apex
String result = instance.serialize();
```

