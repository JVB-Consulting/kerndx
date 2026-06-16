---
title: "FLOW_WriteLog.DTO_Request"
type: class
description: "Data Transfer Object (DTO) for log requests, specifying log level, message details, and context."
since: "1.0"
category: apex
---

# FLOW_WriteLog.DTO_Request

**Class**

```apex
global inherited sharing class FLOW_WriteLog.DTO_Request
```

Data Transfer Object (DTO) for log requests, specifying log level, message details, and context.

**Since:** 1.0

---

## Fields

| Field | Description |
|-------|-------------|
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [classMethod](#classmethod) | An optional class and method name for context. |
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [correlationId](#correlationid) | An optional correlation ID for tracing across transactions. |
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [logLevel](#loglevel) | The logging level (DEBUG, INFO, WARN, ERROR). |
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [message](#message) | The detailed (long) message to log. |
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [recordId](#recordid) | An optional record ID associated with the log entry. |
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [shortMessage](#shortmessage) | An optional short summary of the message. |

---

## Field Details

### classMethod

```apex
@InvocableVariable(required=false description='The class and method name for logging context (defaults to FLOW_WriteLog.writeLog)' label='Class.Method' placeholderText='MyFlow.ErrorHandler') global String classMethod
```

**Type:** [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)

An optional class and method name for context.

**Since:** 1.0

### correlationId

```apex
@InvocableVariable(required=false description='Links this log to related logs across transactions' label='Correlation Id') global String correlationId
```

**Type:** [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)

An optional correlation ID for tracing across transactions.

**Since:** 1.0

### logLevel

```apex
@InvocableVariable(description='The level at which to log the message' label='Log Level' placeholderText='Use one of the following values: DEBUG|INFO|WARN|ERROR' defaultValue='INFO') global String logLevel
```

**Type:** [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)

The logging level (DEBUG, INFO, WARN, ERROR).

**Since:** 1.0

### message

```apex
@InvocableVariable(required=true description='The detailed message to be logged' label='Message') global String message
```

**Type:** [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)

The detailed (long) message to log.

**Since:** 1.0

**Example:**

```apex
String value = instance.message;
```

### recordId

```apex
@InvocableVariable(required=false description='The Id of the record related to this log' label='Record Id') global String recordId
```

**Type:** [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)

An optional record ID associated with the log entry.

**Since:** 1.0

**Example:**

```apex
String value = instance.recordId;
```

### shortMessage

```apex
@InvocableVariable(required=false description='A brief summary of the message' label='Short Summary') global String shortMessage
```

**Type:** [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)

An optional short summary of the message.

**Since:** 1.0

**Example:**

```apex
String value = instance.shortMessage;
```

