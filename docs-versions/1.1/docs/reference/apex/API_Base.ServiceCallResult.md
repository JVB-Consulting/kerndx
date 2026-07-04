---
title: "API_Base.ServiceCallResult"
type: class
description: "Tracks the request, response, and status of a web service call."
since: "1.0"
category: apex
---

# API_Base.ServiceCallResult

**Class**

```apex
global inherited sharing class API_Base.ServiceCallResult
```

Tracks the request, response, and status of a web service call.

**Since:** 1.0

**Example:**

```apex
API_Base.ServiceCallResult result = handler.result;
Boolean success = result.isSuccess;
```

---

## Properties

| Property | Description |
|----------|-------------|
| global [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) [hasFailed](#hasfailed) | Indicates if the service call failed. |
| global [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) [isAborted](#isaborted) | Indicates if the service call was aborted. |
| global [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) [isSuccess](#issuccess) | Indicates if the service call completed successfully. |
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [statusText](#statustext) | Text representation of the service status. |

## Fields

| Field | Description |
|-------|-------------|
| global [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm) [errors](#errors) | List of errors encountered during the service call. |
| global [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) [isMocked](#ismocked) | Indicates if the service call response was mocked. |
| global [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) [parseError](#parseerror) | Indicates the response was successfully received from the remote endpoint but parseResponse() failed (typically a JSON deserialization error or unexpected payload shape). |
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [requestBody](#requestbody) | The request body sent. |
| global [DTO_NameValues](DTO_NameValues.md) [requestHeaders](#requestheaders) | Request headers as name-value pairs. |
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [responseBody](#responsebody) | The response body received. |
| global [DTO_NameValues](DTO_NameValues.md) [responseHeaders](#responseheaders) | Response headers as name-value pairs. |
| global [API_Base.WebserviceStatus](API_Base.WebserviceStatus.md) [status](#status) | The status of the web service call. |
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [statusCode](#statuscode) | The HTTP status code for the request. |
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [url](#url) | The URL of the endpoint accessed. |

---

## Property Details

### hasFailed

```apex
global Boolean hasFailed
```

**Type:** [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm)

Indicates if the service call failed.

Since:

### isAborted

```apex
global Boolean isAborted
```

**Type:** [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm)

Indicates if the service call was aborted.

Since:

### isSuccess

```apex
global Boolean isSuccess
```

**Type:** [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm)

Indicates if the service call completed successfully.

Since:

### statusText

```apex
global String statusText
```

**Type:** [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)

Text representation of the service status.

Since:

---

## Field Details

### errors

```apex
global List<String> errors
```

**Type:** [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)

List of errors encountered during the service call.

**Since:** 1.0

### isMocked

```apex
global Boolean isMocked
```

**Type:** [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm)

Indicates if the service call response was mocked.

**Since:** 1.0

### parseError

```apex
global Boolean parseError
```

**Type:** [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm)

Indicates the response was successfully received from the remote
endpoint but parseResponse() failed (typically a JSON deserialization error
or unexpected payload shape). When true the transport itself succeeded — the
status code and body are populated — but responsePayload is unreliable.
Subscribers branch on this to distinguish parse failure from transport failure
without inspecting errors[] strings.

**Since:** 1.0

### requestBody

```apex
global String requestBody
```

**Type:** [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)

The request body sent.

**Since:** 1.0

### requestHeaders

```apex
global DTO_NameValues requestHeaders
```

**Type:** [DTO_NameValues](DTO_NameValues.md)

Request headers as name-value pairs.

**Since:** 1.0

### responseBody

```apex
global String responseBody
```

**Type:** [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)

The response body received.

**Since:** 1.0

### responseHeaders

```apex
global DTO_NameValues responseHeaders
```

**Type:** [DTO_NameValues](DTO_NameValues.md)

Response headers as name-value pairs.

**Since:** 1.0

### status

```apex
global API_Base.WebserviceStatus status
```

**Type:** [API_Base.WebserviceStatus](API_Base.WebserviceStatus.md)

The status of the web service call.

**Since:** 1.0

### statusCode

```apex
global String statusCode
```

**Type:** [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)

The HTTP status code for the request.

**Since:** 1.0

### url

```apex
global String url
```

**Type:** [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)

The URL of the endpoint accessed.

**Since:** 1.0

