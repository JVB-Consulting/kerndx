---
title: "SVC_Omnistudio.Parameters"
type: class
pageClass: reference
description: "A Data Transfer Object (DTO) used to wrap the original parameters provided by Omnistudio, organizing them into distinct input, output, and option maps. This global inherited sharing class is designed "
since: "1.0"
category: apex
---

# SVC_Omnistudio.Parameters

**Class**

<div class="apex-member apex-class">

```apex
global inherited sharing class SVC_Omnistudio.Parameters
```

A Data Transfer Object (DTO) used to wrap the original parameters provided by Omnistudio, organizing them into distinct input, output, and option maps. This global inherited sharing class is designed to simplify the retrieval and management of these parameters within an Omnistudio context.

</div>

---

## Methods

| Method | Description |
|--------|-------------|
| global [Object](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_System_Object.htm) [getInputVariable](#getinputvariable)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) key) | Retrieves the value of an input variable from the input map. |
| global [Object](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_System_Object.htm) [getOptionVariable](#getoptionvariable)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) key) | Retrieves the value of an option variable from the options map. |
| global void [setOutputVariable](#setoutputvariable)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) key, [Object](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_System_Object.htm) value) | Sets the value of an output variable in the output map. |

### getInputVariable

<div class="apex-member">

```apex
global Object getInputVariable(String key)
```

Retrieves the value of an input variable from the input map.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `key` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The name of the input variable to retrieve. |

**Returns** [Object](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_System_Object.htm) — Returns the value associated with the specified key, or null if the key is not found.

**Example**

```apex
Object result = instance.getInputVariable('value');
```

</div>

### getOptionVariable

<div class="apex-member">

```apex
global Object getOptionVariable(String key)
```

Retrieves the value of an option variable from the options map.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `key` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The name of the option variable to retrieve. |

**Returns** [Object](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_System_Object.htm) — Returns the value associated with the specified key, or null if the key is not found.

**Example**

```apex
Object result = instance.getOptionVariable('value');
```

</div>

### setOutputVariable

<div class="apex-member">

```apex
global void setOutputVariable(String key, Object value)
```

Sets the value of an output variable in the output map. This method is used to store
the results of operations for retrieval after method execution.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `key` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The name of the output variable to set. |
| `value` | [Object](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_System_Object.htm) | The value to assign to the specified key in the output map. |

**Example**

```apex
instance.setOutputVariable('value', 'value');
```

</div>

## Properties

| Property | Description |
|----------|-------------|
| global [Map](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_map.htm)<[String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm), [Object](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_System_Object.htm)> [inputMap](#inputmap) | Provides access to all input variables provided in the parameter map. |
| global [Map](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_map.htm)<[String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm), [Object](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_System_Object.htm)> [optionMap](#optionmap) | Provides access to various option parameters that control the behavior of the call operation. |
| global [Map](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_map.htm)<[String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm), [Object](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_System_Object.htm)> [outputMap](#outputmap) | Provides access to the output map where results of the operation can be stored. |

### inputMap

```apex
global Map<String, Object> inputMap
```

**Type:** [Map](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_map.htm)

Provides access to all input variables provided in the parameter map.

### optionMap

```apex
global Map<String, Object> optionMap
```

**Type:** [Map](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_map.htm)

Provides access to various option parameters that control the behavior of the call operation.

### outputMap

```apex
global Map<String, Object> outputMap
```

**Type:** [Map](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_map.htm)

Provides access to the output map where results of the operation can be stored.

