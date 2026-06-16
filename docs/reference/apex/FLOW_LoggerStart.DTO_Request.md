---
title: "FLOW_LoggerStart.DTO_Request"
type: class
pageClass: reference
description: "Input parameters for starting Flow correlation."
since: "1.0"
category: apex
---

# FLOW_LoggerStart.DTO_Request

**Class**

<div class="apex-member apex-class">

```apex
global inherited sharing class FLOW_LoggerStart.DTO_Request
```

Input parameters for starting Flow correlation.

</div>

---

## Fields

| Field | Description |
|-------|-------------|
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [additionalContext](#additionalcontext) | Additional context to include with the log entry |
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [flowName](#flowname) | Name of the Flow for logging |
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [recordId](#recordid) | Optional record ID for context |

---

## Field Details

### additionalContext

```apex
@InvocableVariable(description='Additional context to include with the log entry' label='Additional Context') global String additionalContext
```

**Type:** [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)

Additional context to include with the log entry

**Example**

```apex
String value = instance.additionalContext;
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

### recordId

```apex
@InvocableVariable(description='Optional record ID for context' label='Record ID') global String recordId
```

**Type:** [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)

Optional record ID for context

**Example**

```apex
String value = instance.recordId;
```

