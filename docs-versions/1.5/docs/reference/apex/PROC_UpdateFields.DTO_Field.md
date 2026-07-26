---
title: "PROC_UpdateFields.DTO_Field"
type: class
pageClass: reference
description: "DTO representing a field to update on an SObject."
since: "1.0"
category: apex
---

# PROC_UpdateFields.DTO_Field

**Class**

<div class="apex-member apex-class">

```apex
global inherited sharing class PROC_UpdateFields.DTO_Field
```

DTO representing a field to update on an SObject.

</div>

---

## Methods

| Method | Description |
|--------|-------------|
| global void [setObjectValue](#setobjectvalue)([SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm) currentSObject) | Sets the field value on an SObject based on the specified update method. |

### setObjectValue

<div class="apex-member">

```apex
global void setObjectValue(SObject currentSObject)
```

Sets the field value on an SObject based on the specified update method.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `currentSObject` | [SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm) | The SObject to update. |

**Example**

```apex
instance.setObjectValue(record);
```

</div>

## Fields

| Field | Description |
|-------|-------------|
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [name](#name) | API name of the field to update (e.g., 'Name'). |
| global [PROC_UpdateFields.FieldUpdateMethod](PROC_UpdateFields.FieldUpdateMethod.md) [updateMethod](#updatemethod) | Method to use for updating the field (default: REPLACE). |
| global [Object](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_System_Object.htm) [value](#value) | Value to apply to the field. |

### name

```apex
global String name
```

**Type:** [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)

API name of the field to update (e.g., 'Name').

**Example**

```apex
String value = instance.name;
```

### updateMethod

```apex
global PROC_UpdateFields.FieldUpdateMethod updateMethod
```

**Type:** [PROC_UpdateFields.FieldUpdateMethod](PROC_UpdateFields.FieldUpdateMethod.md)

Method to use for updating the field (default: REPLACE).

**Example**

```apex
FieldUpdateMethod value = instance.updateMethod;
```

### value

```apex
global Object value
```

**Type:** [Object](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_System_Object.htm)

Value to apply to the field.

**Example**

```apex
Object value = instance.value;
```

