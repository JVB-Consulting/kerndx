---
title: "SCHED_Base"
type: class
pageClass: reference
description: "Abstract base class for scheduled jobs that support configurable parameters. Implements IF_Schedulable, providing parameter storage, typed parameter resolution, and a default empty parameter definitio"
author: "Jason Van Beukering"
group: "Schedulables"
date: "March 2026, May 2026"
since: "1.0"
category: apex
---

# SCHED_Base

**Class** · Group: `Schedulables`

<div class="apex-member apex-class">

```apex
global abstract inherited sharing class SCHED_Base implements IF_Schedulable
```

**Implements:** [IF_Schedulable](IF_Schedulable.md)

**Known Derived Types:** [SCHED_DeactivateUsers](SCHED_DeactivateUsers.md), [SCHED_PurgeRecords](SCHED_PurgeRecords.md), [IF_Schedulable.getParameterDefinitions()](IF_Schedulable.md#getparameterdefinitions), [IF_Schedulable.setParameterValues(DTO_NameValues)](IF_Schedulable.md#setparametervalues)

Abstract base class for scheduled jobs that support configurable parameters. Implements IF_Schedulable, providing parameter storage, typed parameter resolution, and a default empty parameter definition list. Subscribers extend this class, override getParameterDefinitions() to declare their parameters, and implement execute(SchedulableContext) for job logic. When setParameterValues() is called by the framework, the base class resolves raw string values into typed values (String, Integer, Boolean) based on the DataType declared in getParameterDefinitions(), applying default values where configured. Subclasses read typed values via getTextParameter(), getNumericParameter(), and getBooleanParameter().

**Example**

```apex
global class SCHED_MyJob extends SCHED_Base
{
    public override List<DTO_ScheduledParameterDefinition> getParameterDefinitions()
    {
        return new List<DTO_ScheduledParameterDefinition>
        {
            DTO_ScheduledParameterDefinition.of('objectName').required(),
            DTO_ScheduledParameterDefinition.of('batchSize').asNumeric().withDefault('2000')
        };
    }
    public void execute(SchedulableContext context)
    {
        String objectName = getTextParameter('objectName');
        Integer batchSize = getNumericParameter('batchSize');
    }
}
```

**See Also:** [DTO_NameValues](DTO_NameValues.md), [DTO_ScheduledParameterDefinition](DTO_ScheduledParameterDefinition.md), [IF_Schedulable](IF_Schedulable.md)

</div>

---

## Methods

| Method | Description |
|--------|-------------|
| global [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) [getBooleanParameter](#getbooleanparameter)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) name) | Returns a FLAG (boolean) parameter value. |
| global [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) [getNumericParameter](#getnumericparameter)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) name) | Returns a NUMERIC parameter value. |
| global virtual [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[DTO_ScheduledParameterDefinition](DTO_ScheduledParameterDefinition.md)> [getParameterDefinitions](#getparameterdefinitions)() | Returns the parameter definitions supported by this scheduled job. |
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [getTextParameter](#gettextparameter)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) name) | Returns a TEXT parameter value. |
| global void [setParameterValues](#setparametervalues)([DTO_NameValues](DTO_NameValues.md) parameterValues) | Stores the provided parameter values. |

---

## Method Details

### getBooleanParameter

<div class="apex-member">

```apex
global Boolean getBooleanParameter(String name)
```

Returns a FLAG (boolean) parameter value.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `name` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The parameter name. |

**Returns** [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) — The boolean value, defaulting to false if not set.

</div>

### getNumericParameter

<div class="apex-member">

```apex
global Integer getNumericParameter(String name)
```

Returns a NUMERIC parameter value.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `name` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The parameter name. |

**Returns** [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) — The integer value, or null if not set or not numeric.

</div>

### getParameterDefinitions

<div class="apex-member">

```apex
global virtual List<DTO_ScheduledParameterDefinition> getParameterDefinitions()
```

Returns the parameter definitions supported by this scheduled job.
Override in subclasses to declare parameters for dynamic form rendering.
Returns an empty list by default.

**Returns** [DTO_ScheduledParameterDefinition](DTO_ScheduledParameterDefinition.md) — List of parameter definitions.

**Example**

```apex
public override List<DTO_ScheduledParameterDefinition> getParameterDefinitions()
{
    return new List<DTO_ScheduledParameterDefinition>
    {
        DTO_ScheduledParameterDefinition.of('batchSize').asNumeric()
            .withDefault('2000')
    };
}
```

</div>

### getTextParameter

<div class="apex-member">

```apex
global String getTextParameter(String name)
```

Returns a TEXT parameter value.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `name` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The parameter name. |

**Returns** [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) — The string value, or null if not set.

</div>

### setParameterValues

<div class="apex-member">

```apex
global void setParameterValues(DTO_NameValues parameterValues)
```

Stores the provided parameter values. The property setter automatically
resolves raw values into typed parameters.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `parameterValues` | [DTO_NameValues](DTO_NameValues.md) | The name-value pairs containing the resolved parameter values. |

</div>

