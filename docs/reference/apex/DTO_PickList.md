---
title: "DTO_PickList"
type: class
pageClass: reference
description: "A Data Transfer Object (DTO) representing a single picklist and all associated values. This class is typically used to retrieve and manage picklist values dynamically, often for use in invocable actio"
author: "Jason Van Beukering"
group: "Data Transfer Objects"
date: "February 2026, May 2026"
since: "1.0"
category: apex
---

# DTO_PickList

**Class** · Group: `Data Transfer Objects`

```apex
global inherited sharing class DTO_PickList
```

A Data Transfer Object (DTO) representing a single picklist and all associated values. This class is typically used to retrieve and manage picklist values dynamically, often for use in invocable actions.

**Since:** 1.0

**Example:**

```apex
DTO_PickList picklist = new DTO_PickList();
picklist.picklistName = 'Status__c';
picklist.values = new List<DTO_PicklistValue>();
```

**See Also:** [FLOW_GetPicklistValues](FLOW_GetPicklistValues.md)

---

## Fields

| Field | Description |
|-------|-------------|
| global [DTO_PicklistValue](DTO_PicklistValue.md) [defaultValue](#defaultvalue) | The default value for the picklist, represented as a DTO_PicklistValue object. |
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [picklistName](#picklistname) | The API name of the picklist field. |
| global [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[DTO_PicklistValue](DTO_PicklistValue.md)> [values](#values) | A list of all available values for this picklist. |

---

## Field Details

### defaultValue

```apex
@AuraEnabled @InvocableVariable(required=false description='The default value for the picklist, or null if there isn't one' label='Default Value') global DTO_PicklistValue defaultValue
```

**Type:** [DTO_PicklistValue](DTO_PicklistValue.md)

The default value for the picklist, represented as a DTO_PicklistValue object.
If there is no default value, this field will be null.

**Since:** 1.0

**Example:**

```apex
DTO_PicklistValue value = instance.defaultValue;
```

### picklistName

```apex
@AuraEnabled @InvocableVariable(required=true description='The API Name for the picklist' label='Api Name') global String picklistName
```

**Type:** [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)

The API name of the picklist field. This name is used for programmatic references
and is case-sensitive.

**Since:** 1.0

**Example:**

```apex
String value = instance.picklistName;
```

### values

```apex
@AuraEnabled @InvocableVariable(required=true description='A list of values for PickList field' label='Values') global List<DTO_PicklistValue> values
```

**Type:** [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)

A list of all available values for this picklist. Each entry is represented as a
DTO_PicklistValue object, which includes both the label and API name of the value.
This list corresponds to the field's available options and respects any record-type-specific
or object-specific restrictions.

**Since:** 1.0

**Example:**

```apex
List<DTO_PicklistValue> value = instance.values;
```

