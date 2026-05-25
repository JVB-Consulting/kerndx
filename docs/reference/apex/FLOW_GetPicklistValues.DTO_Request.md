---
title: "FLOW_GetPicklistValues.DTO_Request"
type: class
description: "Request DTO containing the information required to retrieve picklist values."
since: "1.0"
category: apex
---

# FLOW_GetPicklistValues.DTO_Request

**Class**

```apex
global inherited sharing class FLOW_GetPicklistValues.DTO_Request
```

Request DTO containing the information required to retrieve picklist values.

**Since:** 1.0

---

## Fields

| Field | Description |
|-------|-------------|
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [objectApiName](#objectapiname) | The object API name for the SObject whose picklist values are being retrieved. |
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [recordTypeApiName](#recordtypeapiname) | The Record Type API name for which to retrieve specifically configured picklist values. |

---

## Field Details

### objectApiName

```apex
@InvocableVariable(required=true description='The SObject Api Name' label='Object Name') global String objectApiName
```

**Type:** [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)

The object API name for the SObject whose picklist values are being retrieved.

**Since:** 1.0

**Example:**

```apex
String value = instance.objectApiName;
```

### recordTypeApiName

```apex
@InvocableVariable(required=true description='The Record Type Api Name' label='Record Type Name') global String recordTypeApiName
```

**Type:** [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)

The Record Type API name for which to retrieve specifically configured picklist values.

**Since:** 1.0

**Example:**

```apex
String value = instance.recordTypeApiName;
```

