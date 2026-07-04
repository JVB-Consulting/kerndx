---
title: "DTO_ScheduledParameterDefinition"
type: class
description: "A Data Transfer Object describing a single parameter definition supported by a scheduled job class. Used by classes implementing IF_Schedulable to declare their configurable parameters via getParamete"
author: "Jason Van Beukering"
group: "Schedulables"
date: "March 2026, May 2026"
since: "1.0"
category: apex
---

# DTO_ScheduledParameterDefinition

**Class** · Group: `Schedulables`

```apex
@JsonAccess(serializable='always' deserializable='always') global inherited sharing class DTO_ScheduledParameterDefinition extends DTO_JsonBase
```

**Extends:** [DTO_JsonBase](DTO_JsonBase.md)

A Data Transfer Object describing a single parameter definition supported by a scheduled job class. Used by classes implementing IF_Schedulable to declare their configurable parameters via getParameterDefinitions(), enabling dynamic form rendering in the scheduledJobEditor LWC component. Uses a fluent builder pattern.

**Since:** 1.0

**Example:**

```apex
DTO_ScheduledParameterDefinition.of('profileNames')
    .required()
    .withDescription('Pipe-separated profile names to target')
```

**See Also:** [IF_Schedulable](IF_Schedulable.md), [SCHED_Base](SCHED_Base.md), [DTO_JsonBase](DTO_JsonBase.md)

---

## Properties

| Property | Description |
|----------|-------------|
| global enum [DataType](DTO_ScheduledParameterDefinition.DataType.md) | Enumeration of supported input data types for scheduled job parameters. |

## Fields

| Field | Description |
|-------|-------------|
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [dataType](#datatype) | The input data type name determining which UI control to render. |
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [defaultValue](#defaultvalue) | The default value pre-populated when the parameter is not yet configured. |
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [description](#description) | Help text describing the parameter's purpose and expected format. |
| global [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) [isRequired](#isrequired) | Whether this parameter must be provided for the job to function. |
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [label](#label) | The user-facing display label for the parameter. |
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [name](#name) | The API name of the parameter (key used in DTO_NameValues). |

## Methods

| Method | Description |
|--------|-------------|
| global [DTO_ScheduledParameterDefinition](DTO_ScheduledParameterDefinition.md) [asBoolean](#asboolean)() | Sets the data type to FLAG (boolean). |
| global [DTO_ScheduledParameterDefinition](DTO_ScheduledParameterDefinition.md) [asNumeric](#asnumeric)() | Sets the data type to NUMERIC (whole number input). |
| global static [DTO_ScheduledParameterDefinition](DTO_ScheduledParameterDefinition.md) [of](#of)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) name) | Creates a new TEXT parameter definition with a label derived from the API name. |
| global static [DTO_ScheduledParameterDefinition](DTO_ScheduledParameterDefinition.md) [of](#of)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) name, [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) label) | Creates a new TEXT parameter definition with an explicit label. |
| global [DTO_ScheduledParameterDefinition](DTO_ScheduledParameterDefinition.md) [required](#required)() | Marks this parameter as required. |
| global [DTO_ScheduledParameterDefinition](DTO_ScheduledParameterDefinition.md) [withDefault](#withdefault)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) defaultValue) | Sets the default value for this parameter. |
| global [DTO_ScheduledParameterDefinition](DTO_ScheduledParameterDefinition.md) [withDescription](#withdescription)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) description) | Sets the help text description for this parameter. |

---

## Method Details

### asBoolean

```apex
global DTO_ScheduledParameterDefinition asBoolean()
```

Sets the data type to FLAG (boolean).

**Returns:** [DTO_ScheduledParameterDefinition](DTO_ScheduledParameterDefinition.md) - This parameter instance for method chaining.

**Since:** 1.0

**Example:**

```apex
DTO_ScheduledParameterDefinition.of('allOrNothing', 'All or Nothing').asBoolean().withDefault('false')
```

### asNumeric

```apex
global DTO_ScheduledParameterDefinition asNumeric()
```

Sets the data type to NUMERIC (whole number input).

**Returns:** [DTO_ScheduledParameterDefinition](DTO_ScheduledParameterDefinition.md) - This parameter instance for method chaining.

**Since:** 1.0

**Example:**

```apex
DTO_ScheduledParameterDefinition.of('batchSize', 'Batch Size').asNumeric().withDefault('2000')
```

### of

```apex
global static DTO_ScheduledParameterDefinition of(String name)
```

Creates a new TEXT parameter definition with a label derived from the API name.
Optional by default. Use `.withLabel()` to override the label,
`.asNumeric()` or `.asBoolean()` to change the data type.

**Parameters:**

- `name` ([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)) - The API name of the parameter. Also used to generate the display label
by splitting on camelCase boundaries (e.g., 'profileNames' becomes 'Profile Names').

**Returns:** [DTO_ScheduledParameterDefinition](DTO_ScheduledParameterDefinition.md) - A new DTO_ScheduledParameterDefinition instance with TEXT data type.

**Since:** 1.0

**Example:**

```apex
DTO_ScheduledParameterDefinition.of('profileNames')
    .required()
    .withDescription('Pipe-separated profile names to target')
```

### of

```apex
global static DTO_ScheduledParameterDefinition of(String name, String label)
```

Creates a new TEXT parameter definition with an explicit label. Optional by default.
Use `.asNumeric()` or `.asBoolean()` to change the data type.

**Parameters:**

- `name` ([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)) - The API name of the parameter.
- `label` ([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)) - The display label for the parameter.

**Returns:** [DTO_ScheduledParameterDefinition](DTO_ScheduledParameterDefinition.md) - A new DTO_ScheduledParameterDefinition instance with TEXT data type.

**Since:** 1.0

**Example:**

```apex
DTO_ScheduledParameterDefinition.of('minimumNumberOfDays', 'Minimum Age (Days)').asNumeric()
```

### required

```apex
global DTO_ScheduledParameterDefinition required()
```

Marks this parameter as required.

**Returns:** [DTO_ScheduledParameterDefinition](DTO_ScheduledParameterDefinition.md) - This parameter instance for method chaining.

**Since:** 1.0

**Example:**

```apex
DTO_ScheduledParameterDefinition.of('objectName', 'Object Name').required()
```

### withDefault

```apex
global DTO_ScheduledParameterDefinition withDefault(String defaultValue)
```

Sets the default value for this parameter.

**Parameters:**

- `defaultValue` ([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)) - The default value as a string.

**Returns:** [DTO_ScheduledParameterDefinition](DTO_ScheduledParameterDefinition.md) - This parameter instance for method chaining.

**Since:** 1.0

**Example:**

```apex
DTO_ScheduledParameterDefinition.of('batchSize').asNumeric()
    .withDefault('2000')
```

### withDescription

```apex
global DTO_ScheduledParameterDefinition withDescription(String description)
```

Sets the help text description for this parameter.

**Parameters:**

- `description` ([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)) - The description text to display as field-level help.

**Returns:** [DTO_ScheduledParameterDefinition](DTO_ScheduledParameterDefinition.md) - This parameter instance for method chaining.

**Since:** 1.0

**Example:**

```apex
DTO_ScheduledParameterDefinition.of('profileNames', 'Profile Names')
    .withDescription('Pipe-separated profile names to target')
```

---

## Field Details

### dataType

```apex
@AuraEnabled global String dataType
```

**Type:** [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)

The input data type name determining which UI control to render.
Stored as the DataType enum name string (TEXT, NUMERIC, FLAG) because the Aura
transport serializes Apex enums as empty objects.

**Since:** 1.0

### defaultValue

```apex
@AuraEnabled global String defaultValue
```

**Type:** [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)

The default value pre-populated when the parameter is not yet configured.

**Since:** 1.0

### description

```apex
@AuraEnabled global String description
```

**Type:** [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)

Help text describing the parameter's purpose and expected format.

**Since:** 1.0

### isRequired

```apex
@AuraEnabled global Boolean isRequired
```

**Type:** [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm)

Whether this parameter must be provided for the job to function.

**Since:** 1.0

### label

```apex
@AuraEnabled global String label
```

**Type:** [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)

The user-facing display label for the parameter.

**Since:** 1.0

### name

```apex
@AuraEnabled global String name
```

**Type:** [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)

The API name of the parameter (key used in DTO_NameValues).

**Since:** 1.0

