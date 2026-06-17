---
title: "DTO_NameValue"
type: class
pageClass: reference
description: "DTO class for name-value pairs, used in invocable methods for data mapping, such as merge fields or configuration settings. Designed for flexibility in flows, Aura components, or Apex logic, supportin"
author: "Jason Van Beukering"
group: "Data Transfer Objects"
date: "September 2025, May 2026"
since: "1.0"
category: apex
---

# DTO_NameValue

**Class** · Group: `Data Transfer Objects`

<div class="apex-member apex-class">

```apex
global inherited sharing class DTO_NameValue
```

DTO class for name-value pairs, used in invocable methods for data mapping, such as merge fields or configuration settings. Designed for flexibility in flows, Aura components, or Apex logic, supporting scenarios like email template merge fields, parameter passing, or custom metadata updates.

**Example**

```apex
DTO_NameValue pair = new DTO_NameValue();
pair.name = 'MergeField';
pair.value = 'Hello World';
```

</div>

---

## Constructors

| Constructor | Description |
|-------------|-------------|
| global [DTO_NameValue](#constructors)() | Default no-argument constructor for flow and invocable compatibility. |
| global [DTO_NameValue](#constructors)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) name, [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) value) | Constructs a new name-value pair with the specified key and value. |

### DTO_NameValue()

<div class="apex-member">

```apex
global DTO_NameValue()
```

Default no-argument constructor for flow and invocable compatibility.

**Example**

```apex
DTO_NameValue pair = new DTO_NameValue();
pair.name = 'MergeField';
pair.value = 'Hello World';
```

</div>

### DTO_NameValue(String name, String value)

<div class="apex-member">

```apex
global DTO_NameValue(String name, String value)
```

Constructs a new name-value pair with the specified key and value.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `name` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The name of the data field or placeholder. |
| `value` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The value associated with the field name. |

**Example**

```apex
DTO_NameValue pair = new DTO_NameValue('MergeField', 'Hello World');
```

</div>

## Fields

| Field | Description |
|-------|-------------|
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [name](#name) | The name of the data field or placeholder, used as a key in invocable methods. |
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [value](#value) | The value associated with the field name, used for substitution or configuration. |

### name

```apex
@AuraEnabled @InvocableVariable(required=true description='The name of the data field or placeholder, used as a key in invocable methods (e.g., merge field placeholder or parameter key).' label='Field Name') global String name
```

**Type:** [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)

The name of the data field or placeholder, used as a key in invocable methods.

### value

```apex
@AuraEnabled @InvocableVariable(required=false description='The value to associate with the field name, used for substitution or configuration in invocable methods (e.g., email body merge fields or parameter values).' label='Field Value') global String value
```

**Type:** [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)

The value associated with the field name, used for substitution or configuration.

