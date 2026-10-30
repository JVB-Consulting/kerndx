---
title: "DTO_JsonBase"
type: class
pageClass: reference
description: "A Data Transfer Object (DTO) base class for JSON serialization and deserialization, providing a framework for transforming JSON data into structured objects and vice versa. Inherited by other DTO clas"
author: "Jason Van Beukering"
group: "Web Services"
date: "February 2026, October 2026"
since: "1.0"
category: apex
---

# DTO_JsonBase

**Class** · Group: `Web Services`

<div class="apex-member apex-class">

```apex
@JsonAccess(serializable='always' deserializable='always') global inherited sharing virtual class DTO_JsonBase extends DTO_Base
```

**Extends:** [DTO_Base](DTO_Base.md)

**Known Derived Types:** [DTO_BaseTable](DTO_BaseTable.md), [DTO_NameValues](DTO_NameValues.md), [DTO_ScheduledParameterDefinition](DTO_ScheduledParameterDefinition.md)

A Data Transfer Object (DTO) base class for JSON serialization and deserialization, providing a framework for transforming JSON data into structured objects and vice versa. Inherited by other DTO classes that require JSON handling capabilities.

**Example**

```apex
@JsonAccess(serializable='always' deserializable='always')
public class DTO_Invoice extends DTO_JsonBase
{
    public String invoiceId;
    public String status;
    protected override Type getObjectType()
    {
        return DTO_Invoice.class;
    }
}
```

</div>

---

## Methods

| Method | Description |
|--------|-------------|
| global override virtual [DTO_Base](DTO_Base.md) [deserialize](#deserialize)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) dtoString) | Deserializes a JSON string into an instance of the current DTO class. |
| global virtual [Type](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_type.htm) [getObjectType](#getobjecttype)() | Returns the type of the current DTO. |
| global override virtual [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [serialize](#serialize)() | Serializes the current DTO instance into a JSON string, omitting null values to create a compact JSON representation. |

### deserialize

<div class="apex-member">

```apex
global override virtual DTO_Base deserialize(String dtoString)
```

Deserializes a JSON string into an instance of the current DTO class. Uses the
`getObjectType` method to identify the appropriate class for deserialization.
The returned instance is populated with values from the provided JSON string.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `dtoString` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | A JSON string representing the serialized data for the DTO. |

**Returns** [DTO_Base](DTO_Base.md) — A deserialized DTO instance populated with values from the JSON string.

**Example**

```apex
DTO_Base result = instance.deserialize('value');
```

**See Also** [DTO_JsonBase.getObjectType](#getobjecttype)

</div>

### getObjectType

<div class="apex-member">

```apex
global virtual Type getObjectType()
```

Returns the type of the current DTO. It is used when JSON is turned back into an instance of your class.
By default the package looks up your class by its name. It can find the class only when the class is global, or when you
have registered a type resolver (a class that tells the framework where to find the Apex classes in your namespace).
If neither is true, override this method in your DTO and return its type.

**Returns** [Type](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_type.htm) — The class type of the DTO.

**Throws**

| Exception | Description |
|-----------|-------------|
| [IllegalArgumentException](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_classes_exception_methods.htm) | if the package cannot find your class by its name and you did not override this method |

**Example**

```apex
public class DTO_Invoice extends DTO_JsonBase
{
    protected override Type getObjectType()
    {
        return DTO_Invoice.class;
    }
}
```

</div>

### serialize

<div class="apex-member">

```apex
global override virtual String serialize()
```

Serializes the current DTO instance into a JSON string, omitting null values
to create a compact JSON representation. Useful for sending structured data
over web services in a lightweight format.

**Returns** [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) — A JSON string representation of the current DTO, excluding null values.

**Example**

```apex
String result = instance.serialize();
```

</div>

