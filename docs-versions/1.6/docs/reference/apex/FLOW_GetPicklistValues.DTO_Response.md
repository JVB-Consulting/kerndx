---
title: "FLOW_GetPicklistValues.DTO_Response"
type: class
pageClass: reference
description: "Provides the outcome of the picklist values retrieval."
since: "1.0"
category: apex
---

# FLOW_GetPicklistValues.DTO_Response

**Class**

<div class="apex-member apex-class">

```apex
global inherited sharing class FLOW_GetPicklistValues.DTO_Response
```

Provides the outcome of the picklist values retrieval.

</div>

---

## Fields

| Field | Description |
|-------|-------------|
| global [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) [callSuccessful](#callsuccessful) | Indicates if the retrieval was successful. |
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [errorText](#errortext) | If the request was unsuccessful this will contain the error message. |
| global [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[DTO_PickList](DTO_PickList.md)> [pickLists](#picklists) | If the request was successful this will contain a list of picklists and their values for a given object and record type. |

### callSuccessful

```apex
@InvocableVariable(required=true description='Indicates whether an error was encountered when performing a request' label='Call Successful') global Boolean callSuccessful
```

**Type:** [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm)

Indicates if the retrieval was successful.

**Example**

```apex
Boolean value = instance.callSuccessful;
```

### errorText

```apex
@InvocableVariable(required=false description='Will contains the error message(s) if any are encountered' label='Error Text') global String errorText
```

**Type:** [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)

If the request was unsuccessful this will contain the error message.

**Example**

```apex
String value = instance.errorText;
```

### pickLists

```apex
@InvocableVariable(required=false description=' will contain a list of picklist and their values for a given object and record type' label='PickList') global List<DTO_PickList> pickLists
```

**Type:** [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)

If the request was successful this will contain a list of picklists and their values for a given object and record type.

**Example**

```apex
List<DTO_PickList> value = instance.pickLists;
```

