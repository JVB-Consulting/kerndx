---
title: "API_InboundTestHelper"
type: class
description: "Class has base methods that can be used to assist with testing inbound service calls"
author: "Jason Van Beukering"
group: "Testing"
date: "February 2026, May 2026"
since: "1.0"
category: apex
---

# API_InboundTestHelper

**Class** · Group: `Testing`

```apex
global inherited sharing class API_InboundTestHelper
```

Class has base methods that can be used to assist with testing inbound service calls

**Since:** 1.0

**Example:**

```apex
API_UpdateInvoice.DTO_Request request = new API_UpdateInvoice.DTO_Request();
request.invoiceId = invoice.Id;
request.status = 'Paid';
API_InboundTestHelper.setupRestContext(request);
API_Base handler = API_InboundTestHelper.assertCallSuccessful(API_UpdateInvoice.class.getName());
```

---

## Methods

| Method | Description |
|--------|-------------|
| global static [API_Base](API_Base.md) [assertCallAborted](#assertcallaborted)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) serviceName) | Executes a callout and ensures that the call was aborted due to the API being disabled. |
| global static [API_Base](API_Base.md) [assertCallAborted](#assertcallaborted)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) serviceName, [DTO_Base](DTO_Base.md) dtoRequest, [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) exceptionMessage) | Executes a callout and ensures that the call was aborted due to the API being disabled. |
| global static [API_Base](API_Base.md) [assertCallAborted](#assertcallaborted)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) serviceName, [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) exceptionMessage) | Executes a callout and ensures that the call was aborted due to the API being disabled. |
| global static [API_Base](API_Base.md) [assertCallFailed](#assertcallfailed)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) serviceName) | Executes an inbound service call and asserts that it failed. |
| global static [API_Base](API_Base.md) [assertCallFailed](#assertcallfailed)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) serviceName, [DTO_Base](DTO_Base.md) dtoRequest) | Executes an inbound service call with a DTO body and asserts that it failed. |
| global static [API_Base](API_Base.md) [assertCallSuccessful](#assertcallsuccessful)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) serviceName) | Executes an inbound service call and asserts that it completed successfully. |
| global static [API_Base](API_Base.md) [assertCallSuccessful](#assertcallsuccessful)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) serviceName, [DTO_Base](DTO_Base.md) dtoRequest) | Executes an inbound service call with a DTO body and asserts that it completed successfully. |
| global static [API_Base](API_Base.md) [assertCallSuccessful](#assertcallsuccessful)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) serviceName, [DTO_Base](DTO_Base.md) dtoRequest, [Map](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_map.htm)<[String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm), [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)> headers) | Executes an inbound service call with a DTO body and custom headers, asserts successful completion. |
| global static void [setupRestContext](#setuprestcontext)() | Sets up the RestContext objects of "request" and "response" to prepare for testing inbound service calls. |
| global static void [setupRestContext](#setuprestcontext)([DTO_Base](DTO_Base.md) dtoRequest) | Sets up the RestContext objects of "request" and "response" for testing purposes. |
| global static void [setupRestContext](#setuprestcontext)([DTO_Base](DTO_Base.md) dtoRequest, [Map](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_map.htm)<[String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm), [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)> headers) | Sets up the RestContext with a serialized DTO body and custom headers. |

---

## Method Details

### assertCallAborted

```apex
global static API_Base assertCallAborted(String serviceName)
```

Executes a callout and ensures that the call was aborted due to the API being disabled.
This method takes a service name and returns an instance of the handler for further checks.

**Parameters:**

- `serviceName` ([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)) - The name of the inbound  webservice handler

**Returns:** [API_Base](API_Base.md) - An instance of the handler, in case further checks are necessary

**Since:** 1.0

**Example:**

```apex
API_Base result = API_InboundTestHelper.assertCallAborted('API_InboundTestHelper');
```

```apex
global static API_Base assertCallAborted(String serviceName, DTO_Base dtoRequest, String exceptionMessage)
```

Executes a callout and ensures that the call was aborted due to the API being disabled.
This method takes a service name and the request DTO, sets up the RestContext, and verifies that the expected exception message is present in the response.

**Parameters:**

- `serviceName` ([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)) - The name of the inbound  webservice handler
- `dtoRequest` ([DTO_Base](DTO_Base.md)) - The request being sent the handler
- `exceptionMessage` ([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)) - The message expected in the response/errors payload

**Returns:** [API_Base](API_Base.md) - An instance of the handler, in case further checks are necessary

**Since:** 1.0

**Example:**

```apex
API_Base result = API_InboundTestHelper.assertCallAborted('API_InboundTestHelper', new DTO_Base(), 'An error occurred');
```

```apex
global static API_Base assertCallAborted(String serviceName, String exceptionMessage)
```

Executes a callout and ensures that the call was aborted due to the API being disabled.
This method takes a service name and checks if the expected exception message is present in the response/errors payload.

**Parameters:**

- `serviceName` ([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)) - The name of the inbound  webservice handler
- `exceptionMessage` ([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)) - The message expected in the response/errors payload

**Returns:** [API_Base](API_Base.md) - An instance of the handler, in case further checks are necessary

**Since:** 1.0

**Example:**

```apex
API_Base result = API_InboundTestHelper.assertCallAborted('API_InboundTestHelper', 'An error occurred');
```

### assertCallFailed

```apex
global static API_Base assertCallFailed(String serviceName)
```

Executes an inbound service call and asserts that it failed.

**Parameters:**

- `serviceName` ([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)) - The name of the inbound webservice handler

**Returns:** [API_Base](API_Base.md) - An instance of the handler for further assertions

**Since:** 1.0

**Example:**

```apex
API_Base handler = API_InboundTestHelper.assertCallFailed('API_Echo');
```

```apex
global static API_Base assertCallFailed(String serviceName, DTO_Base dtoRequest)
```

Executes an inbound service call with a DTO body and asserts that it failed.

**Parameters:**

- `serviceName` ([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)) - The name of the inbound webservice handler
- `dtoRequest` ([DTO_Base](DTO_Base.md)) - The DTO that should be serialized as the request body

**Returns:** [API_Base](API_Base.md) - An instance of the handler for further assertions

**Since:** 1.0

**Example:**

```apex
API_Base handler = API_InboundTestHelper.assertCallFailed('API_Echo', new DTO_Base());
```

### assertCallSuccessful

```apex
global static API_Base assertCallSuccessful(String serviceName)
```

Executes an inbound service call and asserts that it completed successfully.
Sets up RestContext internally before executing. Mirrors the outbound test helper pattern.

**Parameters:**

- `serviceName` ([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)) - The name of the inbound webservice handler

**Returns:** [API_Base](API_Base.md) - An instance of the handler for further assertions

**Since:** 1.0

**Example:**

```apex
API_Base handler = API_InboundTestHelper.assertCallSuccessful('API_Echo');
```

```apex
global static API_Base assertCallSuccessful(String serviceName, DTO_Base dtoRequest)
```

Executes an inbound service call with a DTO body and asserts that it completed successfully.

**Parameters:**

- `serviceName` ([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)) - The name of the inbound webservice handler
- `dtoRequest` ([DTO_Base](DTO_Base.md)) - The DTO that should be serialized as the request body

**Returns:** [API_Base](API_Base.md) - An instance of the handler for further assertions

**Since:** 1.0

**Example:**

```apex
API_Base handler = API_InboundTestHelper.assertCallSuccessful('API_Echo', new DTO_Base());
```

```apex
global static API_Base assertCallSuccessful(String serviceName, DTO_Base dtoRequest, Map<String, String> headers)
```

Executes an inbound service call with a DTO body and custom headers, asserts successful completion.

**Parameters:**

- `serviceName` ([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)) - The name of the inbound webservice handler
- `dtoRequest` ([DTO_Base](DTO_Base.md)) - The DTO that should be serialized as the request body
- `headers` ([Map](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_map.htm)) - Map of header name-value pairs to add to the request

**Returns:** [API_Base](API_Base.md) - An instance of the handler for further assertions

**Since:** 1.0

**Example:**

```apex
API_Base handler = API_InboundTestHelper.assertCallSuccessful('API_Echo', new DTO_Base(), new Map<String, String>{'Idempotency-Key' => 'abc'});
```

### setupRestContext

```apex
global static void setupRestContext()
```

Sets up the RestContext objects of "request" and "response" to prepare for testing inbound service calls.
This method initializes the request and response objects with default values.

**Since:** 1.0

**Example:**

```apex
API_InboundTestHelper.setupRestContext();
```

```apex
global static void setupRestContext(DTO_Base dtoRequest)
```

Sets up the RestContext objects of "request" and "response" for testing purposes.
This method serializes the provided DTO into the request body to simulate a real inbound request.

**Parameters:**

- `dtoRequest` ([DTO_Base](DTO_Base.md)) - The DTO that should be serialized and represents the JSON sent in a request.

**Since:** 1.0

**Example:**

```apex
API_InboundTestHelper.setupRestContext(new DTO_Base());
```

```apex
global static void setupRestContext(DTO_Base dtoRequest, Map<String, String> headers)
```

Sets up the RestContext with a serialized DTO body and custom headers.
Merges custom headers (e.g., idempotency keys, trace parents) into the RestContext request.

**Parameters:**

- `dtoRequest` ([DTO_Base](DTO_Base.md)) - The DTO that should be serialized and represents the JSON sent in a request.
- `headers` ([Map](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_map.htm)) - Map of header name-value pairs to add to the request.

**Since:** 1.0

**Example:**

```apex
API_InboundTestHelper.setupRestContext(new DTO_Base(), new Map<String, String>{'Idempotency-Key' => 'abc-123'});
```

