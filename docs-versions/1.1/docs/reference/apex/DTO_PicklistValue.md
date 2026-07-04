---
title: "DTO_PicklistValue"
type: class
description: "A Data Transfer Object (DTO) representing a single picklist value. This object includes details about the picklist value's display label, API name, and any dependency constraints if the picklist is a "
author: "Jason Van Beukering"
group: "Data Transfer Objects"
date: "February 2026, May 2026"
since: "1.0"
category: apex
---

# DTO_PicklistValue

**Class** · Group: `Data Transfer Objects`

```apex
global inherited sharing class DTO_PicklistValue
```

A Data Transfer Object (DTO) representing a single picklist value. This object includes details about the picklist value's display label, API name, and any dependency constraints if the picklist is a dependent picklist.

**Since:** 1.0

**Example:**

```apex
DTO_PicklistValue entry = new DTO_PicklistValue();
entry.label = 'Active';
entry.value = 'Active';
```

**See Also:** [FLOW_GetPicklistValues](FLOW_GetPicklistValues.md)

---

## Fields

| Field | Description |
|-------|-------------|
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [label](#label) | The display label of the picklist value, intended for use in the user interface (UI). |
| global [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm) [validFor](#validfor) | If the picklist is a dependent picklist, the property contains a list of the controlling value indexes for which this value is valid. |
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [value](#value) | The API value of the picklist, used for programmatic access within Apex code and integrations. |

---

## Field Details

### label

```apex
@AuraEnabled @InvocableVariable(required=true description='The displayable value of the picklist' label='Label') global String label
```

**Type:** [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)

The display label of the picklist value, intended for use in the user interface (UI).
This value is typically user-friendly and may differ from the API name of the picklist value.

**Since:** 1.0

**Example:**

```apex
String value = instance.label;
```

### validFor

```apex
@AuraEnabled @InvocableVariable(required=false description='If the picklist is a dependent picklist, the property contains a list of the controlling values for which this value is valid' label='ValidFor') global List<String> validFor
```

**Type:** [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)

If the picklist is a dependent picklist, the property contains a list of the controlling value indexes for which this value is valid.
If the picklist is an independent picklist, the list is empty.

**Since:** 1.0

### value

```apex
@AuraEnabled @InvocableVariable(required=true description='The value of the picklist to use in the API' label='Value') global String value
```

**Type:** [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)

The API value of the picklist, used for programmatic access within Apex code and integrations.
This value is often less user-friendly and is typically consistent across languages and locales.

**Since:** 1.0

**Example:**

```apex
String value = instance.value;
```

