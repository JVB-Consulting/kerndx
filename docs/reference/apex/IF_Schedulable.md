---
title: "IF_Schedulable"
type: class
pageClass: reference
description: "An interface for a Schedulable class that can declare the parameters it supports and receive validated parameter values at scheduling time. Enables dynamic form rendering in the scheduledJobEditor LWC"
author: "Jason Van Beukering"
group: "Schedulables"
date: "February 2026, May 2026"
since: "1.0"
category: apex
---

# IF_Schedulable

**Class** · Group: `Schedulables`

```apex
global interface IF_Schedulable implements Schedulable
```

**Implements:** [Schedulable](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_interface_system_schedulable.htm)

**Known Derived Types:** [SCHED_Base](SCHED_Base.md), [SCHED_DeactivateUsers](SCHED_DeactivateUsers.md), [SCHED_PurgeRecords](SCHED_PurgeRecords.md), [SCHED_Base.getParameterDefinitions()](SCHED_Base.md#getparameterdefinitions), [SCHED_Base.setParameterValues(DTO_NameValues)](SCHED_Base.md#setparametervalues)

An interface for a Schedulable class that can declare the parameters it supports and receive validated parameter values at scheduling time. Enables dynamic form rendering in the scheduledJobEditor LWC and required parameter validation by the trigger framework. Implementors have two paths: Extend SCHED_Base for built-in typed parameter resolution, default values, and accessors. Implement IF_Schedulable directly on an existing Schedulable class for full control.

**Since:** 1.0

**Example:**

```apex
global class SCHED_MyJob extends SCHED_Base
{
    public override List<DTO_ScheduledParameterDefinition> getParameterDefinitions()
    {
        return new List<DTO_ScheduledParameterDefinition>
        {
            DTO_ScheduledParameterDefinition.of('objectName').required()
        };
    }
    public void execute(SchedulableContext context) { }
}
```

**See Also:** [Schedulable](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_interface_system_schedulable.htm), [SCHED_Base](SCHED_Base.md), [DTO_ScheduledParameterDefinition](DTO_ScheduledParameterDefinition.md), [DTO_NameValues](DTO_NameValues.md)

---

## Methods

| Method | Description |
|--------|-------------|
| global abstract [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[DTO_ScheduledParameterDefinition](DTO_ScheduledParameterDefinition.md)> [getParameterDefinitions](#getparameterdefinitions)() | Returns the parameter definitions supported by this scheduled class. |
| global abstract void [setParameterValues](#setparametervalues)([DTO_NameValues](DTO_NameValues.md) parameterValues) | Receives the validated parameter values at scheduling time. |

---

## Method Details

### getParameterDefinitions

<div class="apex-member">

```apex
global abstract List<DTO_ScheduledParameterDefinition> getParameterDefinitions()
```

Returns the parameter definitions supported by this scheduled class.
Used by the scheduledJobEditor LWC to render structured parameter forms
and by the trigger framework for required parameter validation.

**Returns** [DTO_ScheduledParameterDefinition](DTO_ScheduledParameterDefinition.md) — List of parameter definitions, or an empty list if no parameters are supported.

</div>

### setParameterValues

<div class="apex-member">

```apex
global abstract void setParameterValues(DTO_NameValues parameterValues)
```

Receives the validated parameter values at scheduling time.
Called by the trigger framework after required parameter validation succeeds.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `parameterValues` | [DTO_NameValues](DTO_NameValues.md) | The name-value pairs containing the resolved parameter values. |

</div>

