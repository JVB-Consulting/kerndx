---
title: "FLOW_LoggerLog.DTO_Request"
type: class
pageClass: reference
description: "Input parameters for logging a Flow event."
since: "1.0"
category: apex
---

# FLOW_LoggerLog.DTO_Request

**Class**

<div class="apex-member apex-class">

```apex
global inherited sharing class FLOW_LoggerLog.DTO_Request
```

Input parameters for logging a Flow event.

</div>

---

## Fields

| Field | Description |
|-------|-------------|
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [additionalContext](#additionalcontext) | Additional context to include with the log entry |
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [correlationId](#correlationid) | Correlation ID from Start Flow Correlation |
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [flowStep](#flowstep) | Current step/screen name for context |
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [logLevel](#loglevel) | The log level: Debug, Info, Warning, or Error (stored as DEBUG, INFO, WARN, or ERROR). |
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [message](#message) | Log message |
| global [Id](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_id.htm) [recordId](#recordid) | Optional record to associate with this log entry. |

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

### flowStep

```apex
@InvocableVariable(description='Current step/screen name for context' label='Flow Step') global String flowStep
```

**Type:** [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)

Current step/screen name for context

**Example**

```apex
String value = instance.flowStep;
```

### logLevel

```apex
@InvocableVariable(description='Pick Debug, Info, Warning, or Error. Defaults to Info when left empty. Stored values are DEBUG, INFO, WARN, and ERROR.' label='Log Level') global String logLevel
```

**Type:** [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)

The log level: Debug, Info, Warning, or Error (stored as DEBUG, INFO, WARN, or ERROR).
Defaults to INFO when left empty.

**Example**

```apex
String value = instance.logLevel;
```

### message

```apex
@InvocableVariable(required=true description='Log message' label='Message') global String message
```

**Type:** [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)

Log message

**Example**

```apex
String value = instance.message;
```

### recordId

```apex
@InvocableVariable(description='Optional record to associate with this log entry' label='Record ID') global Id recordId
```

**Type:** [Id](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_id.htm)

Optional record to associate with this log entry. When set, the
record is linked to the log entry so every log for that record can be filtered
and reported on together. Leave blank when the log is not about a specific record.

**Example**

```apex
Id value = instance.recordId;
```

