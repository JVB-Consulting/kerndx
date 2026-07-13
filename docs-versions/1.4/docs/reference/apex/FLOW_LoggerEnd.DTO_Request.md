---
title: "FLOW_LoggerEnd.DTO_Request"
type: class
pageClass: reference
description: "Input parameters for ending Flow correlation."
since: "1.0"
category: apex
---

# FLOW_LoggerEnd.DTO_Request

**Class**

<div class="apex-member apex-class">

```apex
global inherited sharing class FLOW_LoggerEnd.DTO_Request
```

Input parameters for ending Flow correlation.

</div>

---

## Fields

| Field | Description |
|-------|-------------|
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [correlationId](#correlationid) | Correlation ID from Start Flow Correlation |
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [errorMessage](#errormessage) | Error message if Flow failed |
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [flowName](#flowname) | Name of the Flow for logging |
| global [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) [success](#success) | Whether the Flow completed successfully |

### correlationId

```apex
@InvocableVariable(required=true description='Correlation ID from Start Flow Correlation' label='Correlation ID') global String correlationId
```

**Type:** [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)

Correlation ID from Start Flow Correlation

**Example**

```apex
String value = instance.correlationId;
```

### errorMessage

```apex
@InvocableVariable(description='Error message if Flow failed' label='Error Message') global String errorMessage
```

**Type:** [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)

Error message if Flow failed

**Example**

```apex
String value = instance.errorMessage;
```

### flowName

```apex
@InvocableVariable(required=true description='Name of the Flow for logging' label='Flow Name') global String flowName
```

**Type:** [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)

Name of the Flow for logging

**Example**

```apex
String value = instance.flowName;
```

### success

```apex
@InvocableVariable(description='Whether the Flow completed successfully' label='Success') global Boolean success
```

**Type:** [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm)

Whether the Flow completed successfully

**Example**

```apex
Boolean value = instance.success;
```

