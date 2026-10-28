---
title: "FLOW_LoggerStart.DTO_Response"
type: class
pageClass: reference
description: "Output containing the generated correlation ID."
since: "1.0"
category: apex
---

# FLOW_LoggerStart.DTO_Response

**Class**

<div class="apex-member apex-class">

```apex
global inherited sharing class FLOW_LoggerStart.DTO_Response
```

Output containing the generated correlation ID.

</div>

---

## Fields

| Field | Description |
|-------|-------------|
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [correlationId](#correlationid) | Generated correlation ID to pass to subsequent actions |

### correlationId

```apex
@InvocableVariable(description='Generated correlation ID to pass to subsequent actions' label='Correlation ID') global String correlationId
```

**Type:** [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)

Generated correlation ID to pass to subsequent actions

**Example**

```apex
String value = instance.correlationId;
```

