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

```apex
global inherited sharing class FLOW_LoggerLog.DTO_Request
```

Input parameters for logging a Flow event.

**Since:** 1.0

---

## Fields

| Field | Description |
|-------|-------------|
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [additionalContext](#additionalcontext) | Additional context to include with the log entry |
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [correlationId](#correlationid) | Correlation ID from Start Flow Correlation |
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [flowStep](#flowstep) | Current step/screen name for context |
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [logLevel](#loglevel) | DEBUG, INFO, WARN, or ERROR (default: INFO) |
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [message](#message) | Log message |

---

## Field Details

### additionalContext

```apex
@InvocableVariable(description='Additional context to include with the log entry' label='Additional Context') global String additionalContext
```

**Type:** [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)

Additional context to include with the log entry

**Since:** 1.0

**Example:**

```apex
String value = instance.additionalContext;
```

### correlationId

```apex
@InvocableVariable(required=true description='Correlation ID from Start Flow Correlation' label='Correlation ID') global String correlationId
```

**Type:** [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)

Correlation ID from Start Flow Correlation

**Since:** 1.0

**Example:**

```apex
String value = instance.correlationId;
```

### flowStep

```apex
@InvocableVariable(description='Current step/screen name for context' label='Flow Step') global String flowStep
```

**Type:** [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)

Current step/screen name for context

**Since:** 1.0

**Example:**

```apex
String value = instance.flowStep;
```

### logLevel

```apex
@InvocableVariable(description='DEBUG, INFO, WARN, or ERROR (default: INFO)' label='Log Level') global String logLevel
```

**Type:** [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)

DEBUG, INFO, WARN, or ERROR (default: INFO)

**Since:** 1.0

**Example:**

```apex
String value = instance.logLevel;
```

### message

```apex
@InvocableVariable(required=true description='Log message' label='Message') global String message
```

**Type:** [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)

Log message

**Since:** 1.0

**Example:**

```apex
String value = instance.message;
```

