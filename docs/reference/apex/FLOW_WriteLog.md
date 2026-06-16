---
title: "FLOW_WriteLog"
type: class
pageClass: reference
description: "Provides an invocable method for logging messages at specified levels (DEBUG, INFO, WARN, ERROR) from Salesforce flows. Allows control over log levels and additional details such as short messages and"
author: "Jason Van Beukering"
group: "Logging"
date: "September 2025, May 2026"
since: "1.0"
category: apex
---

# FLOW_WriteLog

**Class** · Group: `Logging`

```apex
global inherited sharing class FLOW_WriteLog
```

Provides an invocable method for logging messages at specified levels (DEBUG, INFO, WARN, ERROR) from Salesforce flows. Allows control over log levels and additional details such as short messages and associated record IDs. Utilizes the LOG_Builder utility to write messages to the application log.

**Since:** 1.0

**Example:**

```apex
FLOW_WriteLog.DTO_Request request = new FLOW_WriteLog.DTO_Request();
request.logLevel = 'ERROR';
request.message = 'Payment processing failed for order';
request.shortMessage = 'Payment failure';
request.classMethod = 'PaymentFlow.ProcessPayment';
request.recordId = orderId;
FLOW_WriteLog.writeLog(new List<FLOW_WriteLog.DTO_Request> {request});
```

**See Also:** [LOG_Builder](LOG_Builder.md)

---

## Methods

| Method | Description |
|--------|-------------|
| global static void [writeLog](#writelog)([List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[FLOW_WriteLog.DTO_Request](FLOW_WriteLog.DTO_Request.md)> dtoRequests) | Logs messages at specified levels with additional context, designed for use in Salesforce flows. |

## Inner Classes

| Class | Description |
|-------|-------------|
| [DTO_Request](FLOW_WriteLog.DTO_Request.md) | Data Transfer Object (DTO) for log requests, specifying log level, message details, and context. |

---

## Method Details

### writeLog

<div class="apex-member">

```apex
@InvocableMethod(category='Logging' description='Writes provided messages to the Application Log, allows setting of LogLevel and other details' label='Write Detailed Log Messages') global static void writeLog(List<FLOW_WriteLog.DTO_Request> dtoRequests)
```

Logs messages at specified levels with additional context, designed for use in Salesforce flows.
Supports multiple messages with customizable log levels, short messages, record IDs, and class/method references for enhanced monitoring and troubleshooting.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `dtoRequests` | [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm) | The list of log requests, each specifying the level, message, and optional details. |

**Example**

```apex
// In a flow, create a DTO_Request variable and pass a list to the action.
FLOW_WriteLog.DTO_Request dtoRequest = new FLOW_WriteLog.DTO_Request();
dtoRequest.classMethod = 'MyFlow.ErrorHandler';
dtoRequest.logLevel = 'ERROR';
dtoRequest.message = 'Detailed error in flow execution';
dtoRequest.recordId = 'a0300000000Nqu7AAC';
dtoRequest.shortMessage = 'Flow error';
FLOW_WriteLog.writeLog(new List<FLOW_WriteLog.DTO_Request>{dtoRequest}); // Logs the message with the specified level and details.
```

</div>

