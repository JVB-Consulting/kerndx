---
title: "API_Inbound"
type: class
pageClass: reference
description: "Base class for all inbound REST API web service calls. Provides foundational functionality for handling incoming HTTP requests, processing them, parsing request/response DTOs, and sending appropriate "
author: "Jason Van Beukering"
group: "Web Services"
date: "February 2026, May 2026"
since: "1.0"
category: apex
---

# API_Inbound

**Class** · Group: `Web Services`

<div class="apex-member apex-class">

```apex
global virtual inherited sharing class API_Inbound extends API_Base
```

**Extends:** [API_Base](API_Base.md)

Base class for all inbound REST API web service calls. Provides foundational functionality for handling incoming HTTP requests, processing them, parsing request/response DTOs, and sending appropriate responses.

**Example**

```apex
@RestResource(urlMapping='/api/echo/*')
global with sharing class API_Echo
{
    @HttpPost
    global static void doPost()
    {
        new EchoHandler().execute();
    }
    private class EchoHandler extends API_Inbound
    {
        global override void processRequest()
        {
            // handle the request
        }
    }
}
```

</div>

---

## Properties

| Property | Description |
|----------|-------------|
| global [RestRequest](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_restrequest.htm) [request](#request) | Reference to the current inbound REST request. |
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [requestBody](#requestbody) | Returns the request body from the current inbound HTTP request. |
| global [DTO_JsonBase](DTO_JsonBase.md) [requestPayload](#requestpayload) | The DTO that will be populated from the inbound request body. |
| global [RestResponse](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_restresponse.htm) [response](#response) | Reference to the current REST response object. |
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [responseBody](#responsebody) | Manages the response body that will be sent to the client. |
| global [DTO_JsonBase](DTO_JsonBase.md) [responsePayload](#responsepayload) | The DTO that will be serialized to populate the response body. |

## Methods

| Method | Description |
|--------|-------------|
| global  [API_Inbound](#api_inbound)() | Constructor. |
| global override virtual void [configure](#configure)() | Initializes class variables and sets up request details including headers and URL parameters. |
| global override virtual [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [getEncoding](#getencoding)() | Retrieves the HTTP character encoding for the request. |
| global override [API_Base.HttpMethod](API_Base.HttpMethod.md) [getHttpMethod](#gethttpmethod)() | Retrieves the HTTP method of the current inbound request. |
| global override virtual void [handleError](#handleerror)([Exception](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_classes_exception_methods.htm) error) | Handles exceptions during request processing, setting appropriate status codes and writing the response. |
| global override [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) [isDisabled](#isdisabled)() | Checks custom settings to determine if the API has been disabled for the current user. |
| global override virtual void [onCommitWorkFinishing](#oncommitworkfinishing)() | Performs actions after a commit is completed, such as setting the response and updating the API call. |
| global override virtual void [onCommitWorkStarting](#oncommitworkstarting)() | Performs actions before committing changes to the database. |
| global override virtual void [onSuccess](#onsuccess)() | Registers database changes after a successful call. |
| global virtual void [parseRequest](#parserequest)() | Parses the inbound request body and populates the requestPayload with deserialized JSON data. |
| global virtual void [processRequest](#processrequest)() | Handles the processing of the received request. |
| global virtual void [updateCallResult](#updatecallresult)() | Updates the results of the call, such as status and response body. |
| global virtual void [updateResponseDTO](#updateresponsedto)() | Updates the response DTO with relevant information before the response is sent. |
| global virtual void [writeResponse](#writeresponse)() | Writes the response to the client based on the call result. |

---

## Property Details

### request

```apex
global RestRequest request
```

**Type:** [RestRequest](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_restrequest.htm)

Reference to the current inbound REST request. Provides access to the details of the incoming request,
such as headers, parameters, and the request body.




Since:


Example:

**See Also:** [RestRequest](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_restrequest.htm)

### requestBody

```apex
global String requestBody
```

**Type:** [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)

Returns the request body from the current inbound HTTP request.
If the request body is null or empty, it returns an empty string.

Since:


Example:

### requestPayload

```apex
global DTO_JsonBase requestPayload
```

**Type:** [DTO_JsonBase](DTO_JsonBase.md)

The DTO that will be populated from the inbound request body.
Handles the request data in JSON format and ensures proper initialization and deserialization.

Since:


Example:

### response

```apex
global RestResponse response
```

**Type:** [RestResponse](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_restresponse.htm)

Reference to the current REST response object. Allows manipulation of the response that will be sent
back to the client, including setting the response body and status code.




Since:


Example:

**See Also:** [RestResponse](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_restresponse.htm)

### responseBody

```apex
global String responseBody
```

**Type:** [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)

Manages the response body that will be sent to the client.
Ensures that the value is stored as a Blob in the response object.

Since:


Example:

### responsePayload

```apex
global DTO_JsonBase responsePayload
```

**Type:** [DTO_JsonBase](DTO_JsonBase.md)

The DTO that will be serialized to populate the response body.
Handles the response data in JSON format and ensures proper initialization and serialization.

Since:


Example:

---

## Method Details

### API_Inbound

<div class="apex-member">

```apex
global API_Inbound()
```

Constructor. Initializes the object and parses the inbound request body.

**Example**

```apex
// Called automatically when the REST endpoint is invoked
private class MyHandler extends API_Inbound { }
```

</div>

### configure

<div class="apex-member">

```apex
global override virtual void configure()
```

Initializes class variables and sets up request details including headers and URL parameters.

**Example**

```apex
global override void configure()
{
    super.configure();
    requestPayload = new DTO_Request();
    responsePayload = new DTO_Response();
}
```

</div>

### getEncoding

<div class="apex-member">

```apex
global override virtual String getEncoding()
```

Retrieves the HTTP character encoding for the request.

**Returns** [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) — The content type header from the incoming request.

**Example**

```apex
global override String getEncoding()
{
    return 'application/xml';
}
```

</div>

### getHttpMethod

<div class="apex-member">

```apex
global override API_Base.HttpMethod getHttpMethod()
```

Retrieves the HTTP method of the current inbound request.

**Returns** [API_Base.HttpMethod](API_Base.HttpMethod.md) — The HTTP method of the current request.

**Example**

```apex
HttpMethod method = getHttpMethod(); // Returns the inbound request's HTTP method
```

</div>

### handleError

<div class="apex-member">

```apex
global override virtual void handleError(Exception error)
```

Handles exceptions during request processing, setting appropriate status codes and writing the response.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `error` | [Exception](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_classes_exception_methods.htm) | The exception that needs to be managed. |

**Example**

```apex
global override void handleError(Exception error)
{
    super.handleError(error);
    // custom error handling
}
```

</div>

### isDisabled

<div class="apex-member">

```apex
global override Boolean isDisabled()
```

Checks custom settings to determine if the API has been disabled for the current user.

**Returns** [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) — True if the API is disabled, false otherwise.

**Example**

```apex
global override Boolean isDisabled()
{
    return super.isDisabled() || customDisableCheck();
}
```

</div>

### onCommitWorkFinishing

<div class="apex-member">

```apex
global override virtual void onCommitWorkFinishing()
```

Performs actions after a commit is completed, such as setting the response and updating the API call.

**Example**

```apex
global override void onCommitWorkFinishing()
{
    super.onCommitWorkFinishing();
    // post-commit logic
}
```

</div>

### onCommitWorkStarting

<div class="apex-member">

```apex
global override virtual void onCommitWorkStarting()
```

Performs actions before committing changes to the database.

**Example**

```apex
global override void onCommitWorkStarting()
{
    super.onCommitWorkStarting();
    // pre-commit logic
}
```

</div>

### onSuccess

<div class="apex-member">

```apex
global override virtual void onSuccess()
```

Registers database changes after a successful call.
Simulates an error for testing if `returnErrorResponse` is set.

**Example**

```apex
global override void onSuccess()
{
    super.onSuccess();
    doInsert(newRecord);
}
```

</div>

### parseRequest

<div class="apex-member">

```apex
global virtual void parseRequest()
```

Parses the inbound request body and populates the requestPayload with deserialized JSON data.

**Example**

```apex
global override void parseRequest()
{
    super.parseRequest();
    // additional request parsing
}
```

</div>

### processRequest

<div class="apex-member">

```apex
global virtual void processRequest()
```

Handles the processing of the received request.
Implement in descendant classes to define specific logic for handling API endpoints.

**Example**

```apex
global override void processRequest()
{
    DTO_Request dto = (DTO_Request)requestPayload;
    // process the inbound request
}
```

</div>

### updateCallResult

<div class="apex-member">

```apex
global virtual void updateCallResult()
```

Updates the results of the call, such as status and response body.
Override in descendant classes to implement specific update logic.

**Example**

```apex
global override void updateCallResult()
{
    super.updateCallResult();
    // customize the response body
}
```

</div>

### updateResponseDTO

<div class="apex-member">

```apex
global virtual void updateResponseDTO()
```

Updates the response DTO with relevant information before the response is sent.
Override in inheriting classes to customize the response body data.

**Example**

```apex
global override void updateResponseDTO()
{
    DTO_Response dto = (DTO_Response)responsePayload;
    dto.recordId = newRecord.Id;
}
```

</div>

### writeResponse

<div class="apex-member">

```apex
global virtual void writeResponse()
```

Writes the response to the client based on the call result.
Override to modify the response written to the client.

**Example**

```apex
global override void writeResponse()
{
    super.writeResponse();
    // customize response writing
}
```

</div>

