---
title: "SVC_Omnistudio"
type: class
description: "SVC_Omnistudio is a factory class that implements the Callable interface and is designed to instantiate and execute operations on specific classes based on a provided class name. It is mainly used wit"
author: "Jason Van Beukering"
group: "Omnistudio"
date: "February 2026, May 2026"
since: "1.0"
category: apex
---

# SVC_Omnistudio

**Class** · Group: `Omnistudio`

```apex
global virtual inherited sharing class SVC_Omnistudio implements Callable
```

**Implements:** [Callable](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_interface_System_Callable.htm)

SVC_Omnistudio is a factory class that implements the Callable interface and is designed to instantiate and execute operations on specific classes based on a provided class name. It is mainly used within the Omnistudio framework to dynamically manage actions on classes. This class supports passing and handling parameters for both input and output operations.

**Since:** 1.0

**Example:**

```apex
// Implement an OmniCallable action
public class MyOmniAction implements SVC_Omnistudio.OmniCallable
{
    public void call(SVC_Omnistudio.Parameters parameters)
    {
        String input = (String)parameters.getInputVariable('name');
        parameters.setOutputVariable('result', 'Hello ' + input);
    }
}
```

---

## Properties

| Property | Description |
|----------|-------------|
| global interface [OmniCallable](SVC_Omnistudio.OmniCallable.md) | A global inner interface that allows the SVC_Omnistudio class to instantiate a class and perform an operation within the Omnistudio framework. |

## Methods

| Method | Description |
|--------|-------------|
| global [Object](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_System_Object.htm) [call](#call)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) className, [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm), [Object](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_System_Object.htm)> parameterMap) | This global method dynamically instantiates a class based on the provided className and executes a method within the instantiated class to perform the requested operation. |

## Inner Classes

| Class | Description |
|-------|-------------|
| [Parameters](SVC_Omnistudio.Parameters.md) | A Data Transfer Object (DTO) used to wrap the original parameters provided by Omnistudio, organizing them into distinct input, output, and option maps. |

---

## Method Details

### call

```apex
global Object call(String className, Map<String, Object> parameterMap)
```

This global method dynamically instantiates a class based on the provided `className`
and executes a method within the instantiated class to perform the requested operation. The method
takes a `parameterMap` containing arguments necessary for the operation and manages the
interaction through the `Parameters` DTO.

**Parameters:**

- `className` ([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)) - The name of the class to instantiate; this class must implement Callable.
- `parameterMap` ([Map](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_map.htm)) - A map of arguments to be used by the specified class for executing its logic.

**Returns:** [Object](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_System_Object.htm) - Returns `true` if the operation is successful.

**Throws:**

- [Exception](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_classes_exception_methods.htm) - This method may throw an exception if the specified class cannot be instantiated
or if an error occurs during method execution. The exception will be logged.

**Since:** 1.0

**Example:**

```apex
Object result = instance.call('SVC_Omnistudio', new Map<String, Object>{'key' => 'value'});
```

