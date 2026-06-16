---
title: "API_Outbound"
type: class
pageClass: reference
description: "Base class for all outbound web service calls. Extends API_Base to provide functionality for making HTTP callouts, handling responses, managing retries, and token replacements."
author: "Jason Van Beukering"
group: "Web Services"
date: "February 2026, May 2026"
since: "1.0"
category: apex
---

# API_Outbound

**Class** · Group: `Web Services`

<div class="apex-member apex-class">

```apex
global virtual inherited sharing class API_Outbound extends API_Base
```

**Extends:** [API_Base](API_Base.md)

**Known Derived Types:** [API_CallCurrentOrg](API_CallCurrentOrg.md)

Base class for all outbound web service calls. Extends API_Base to provide functionality for making HTTP callouts, handling responses, managing retries, and token replacements.

**Example**

```apex
public with sharing class API_SendEmail extends API_Outbound
{
    public override void configure()
    {
        super.configure();
        requestPayload = new DTO_Request();
        responsePayload = new DTO_Response();
        defaultMockBody = '{"messageId": "msg-12345"}';
    }
}
```

</div>

---

## Properties

| Property | Description |
|----------|-------------|
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [baseUrl](#baseurl) | Returns the base URL of the web service. |
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [defaultMockBody](#defaultmockbody) | Default mock response body for unit tests and mock mode. |
| global [HttpRequest](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_classes_restful_http_httprequest.htm) [request](#request) | The request object used by the API handler to make an outbound call. |
| global [DTO_Base](DTO_Base.md) [requestPayload](#requestpayload) | The DTO that should be serialized for the request body in outbound service calls. |
| global [HttpResponse](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_classes_restful_http_httpresponse.htm) [response](#response) | The response object containing the results of the HTTP callout. |
| global [DTO_Base](DTO_Base.md) [responsePayload](#responsepayload) | The DTO that will deserialize the response body of the external web service call. |

## Fields

| Field | Description |
|-------|-------------|
| global [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) [requiresTriggeringRecord](#requirestriggeringrecord) | Whether this service requires a triggering object ID. |

## Methods

| Method | Description |
|--------|-------------|
| global override virtual void [configure](#configure)() | Initializes global variables; override in descendant classes if needed. |
| global virtual [HttpRequest](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_classes_restful_http_httprequest.htm) [createRequest](#createrequest)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) requestBody) | Constructs the HttpRequest object used to make the outbound API call. |
| global virtual [UTIL_Retry.Strategy](UTIL_Retry.Strategy.md) [createRetryStrategy](#createretrystrategy)() | Creates the retry strategy for failed service calls. |
| global virtual [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [getAuthorisationToken](#getauthorisationtoken)() | Returns the authorization token required for outbound API requests. |
| global virtual override [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [getBody](#getbody)() | Generates the request body using the type of the requestPayload. |
| global override virtual [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [getEncoding](#getencoding)() | Retrieves the HTTP encoding. |
| global override virtual [API_Base.HttpMethod](API_Base.HttpMethod.md) [getHttpMethod](#gethttpmethod)() | Retrieves the HTTP method used for making the outbound request. |
| global virtual [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [getQueryParameters](#getqueryparameters)() | Retrieves relevant query parameters. |
| global virtual void [getRequestReplacementTokens](#getrequestreplacementtokens)([List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)> searchTokens, [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)> replaceTokens) | Specifies token replacements for the request body before serialization. |
| global virtual [Set](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_set.htm)<[String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)> [getRequiredInputs](#getrequiredinputs)() | Indicates required service inputs. |
| global virtual [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [getResponseBody](#getresponsebody)() | Retrieves the current response body; override to manipulate response body first. |
| global virtual void [getResponseReplacementTokens](#getresponsereplacementtokens)([List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)> searchTokens, [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)> replaceTokens) | Specifies token replacements for the response body before deserialization. |
| global virtual [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) [getTimeout](#gettimeout)() | Retrieves the HTTP Service Timeout. |
| global virtual [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [getWebServiceEndPoint](#getwebserviceendpoint)() | Constructs and returns the full URL endpoint for the web service, resolving Named Credentials and appending the API path. |
| global virtual [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) [hasArrayResponse](#hasarrayresponse)() | Checks if the JSON response is in the form of an array without a key. |
| global override [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) [isDisabled](#isdisabled)() | Checks whether the API has been disabled for the current user by verifying custom settings or feature switches. |
| global virtual void [parseResponse](#parseresponse)() | Called if request is successful; override to consume response. |
| global virtual void [prepareRequest](#preparerequest)() | Prepares the outbound request by querying Salesforce data and populating the request DTO. |
| global virtual void [setHeaders](#setheaders)() | Sets the HTTP headers for the request. |

---

## Property Details

### baseUrl

```apex
global String baseUrl
```

**Type:** [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)

Returns the base URL of the web service. This resolves Named Credentials to handle secure credential management in Salesforce.

Since:


Example:

### defaultMockBody

```apex
global String defaultMockBody
```

**Type:** [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)

Default mock response body for unit tests and mock mode.
Set this in configure() to declare the handler's default mock response.
When set, API_MockFactory.CalloutMock uses this as fallback when no factory mock is registered.

Since:


Example:

### request

```apex
@TestVisible global HttpRequest request
```

**Type:** [HttpRequest](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_classes_restful_http_httprequest.htm)

The request object used by the API handler to make an outbound call.
The HttpRequest object is initialized lazily when it's first accessed.




Since:


Example:

**See Also:** [HttpRequest](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_classes_restful_http_httprequest.htm)

### requestPayload

```apex
global DTO_Base requestPayload
```

**Type:** [DTO_Base](DTO_Base.md)

The DTO that should be serialized for the request body in outbound service calls.
This object contains the data that will be sent to the external service as part of the HTTP request.

Since:


Example:

### response

```apex
@TestVisible global HttpResponse response
```

**Type:** [HttpResponse](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_classes_restful_http_httpresponse.htm)

The response object containing the results of the HTTP callout.
This object is populated after the HTTP call is executed.




Since:


Example:

**See Also:** [HttpResponse](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_classes_restful_http_httpresponse.htm)

### responsePayload

```apex
@TestVisible global DTO_Base responsePayload
```

**Type:** [DTO_Base](DTO_Base.md)

The DTO that will deserialize the response body of the external web service call.
This object will be populated with the response data after the HTTP call completes.

Since:


Example:

---

## Method Details

### configure

<div class="apex-member">

```apex
global override virtual void configure()
```

Initializes global variables; override in descendant classes if needed.

**Example**

```apex
global override void configure()
{
    super.configure();
    requestPayload = new DTO_Request();
    responsePayload = new DTO_Response();
    defaultMockBody = '{"messageId": "msg-12345"}';
}
```

</div>

### createRequest

<div class="apex-member">

```apex
global virtual HttpRequest createRequest(String requestBody)
```

Constructs the `HttpRequest` object used to make the outbound API call. It sets the headers, request body, and endpoint URL.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `requestBody` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The body content of the request. |

**Returns** [HttpRequest](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_classes_restful_http_httprequest.htm) — The fully configured request object.

**Example**

```apex
global override HttpRequest createRequest(String requestBody)
{
    HttpRequest httpRequest = super.createRequest(requestBody);
    // customize request
    return httpRequest;
}
```

</div>

### createRetryStrategy

<div class="apex-member">

```apex
global virtual UTIL_Retry.Strategy createRetryStrategy()
```

Creates the retry strategy for failed service calls.
Override this method in subclasses to provide custom retry strategies.

**Returns** [UTIL_Retry.Strategy](UTIL_Retry.Strategy.md) — Configured instance

**Example**

```apex
global class API_PaymentGateway extends API_Outbound
{
    global override UTIL_Retry.Strategy createRetryStrategy()
    {
        return UTIL_Retry.exponential()
            .withBaseBackoff(5)
            .withMaxRetries(3);
    }
}
```

</div>

### getAuthorisationToken

<div class="apex-member">

```apex
global virtual String getAuthorisationToken()
```

Returns the authorization token required for outbound API requests.

**Returns** [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) — The authorization token to be used in the `Authorization` HTTP header.

**Example**

```apex
global override String getAuthorisationToken()
{
    return 'Bearer ' + accessToken;
}
```

</div>

### getBody

<div class="apex-member">

```apex
global virtual override String getBody()
```

Generates the request body using the type of the requestPayload.
Applies token replacements to the request body before sending.

**Returns** [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) — The serialized request body.

**Example**

```apex
global override String getBody()
{
    return JSON.serialize(customPayload);
}
```

**See Also** [DTO_Base](DTO_Base.md)

</div>

### getEncoding

<div class="apex-member">

```apex
global override virtual String getEncoding()
```

Retrieves the HTTP encoding.

**Returns** [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) — The HTTP encoding, defaults to JSON.

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
global override virtual API_Base.HttpMethod getHttpMethod()
```

Retrieves the HTTP method used for making the outbound request.

**Returns** [API_Base.HttpMethod](API_Base.HttpMethod.md) — The HTTP method to be used. Defaults to POST if not provided by the superclass.

**Example**

```apex
global override HttpMethod getHttpMethod()
{
    return HttpMethod.GET;
}
```

</div>

### getQueryParameters

<div class="apex-member">

```apex
global virtual String getQueryParameters()
```

Retrieves relevant query parameters.

**Returns** [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) — A list of query parameters.

**Example**

```apex
global override String getQueryParameters()
{
    return 'key=' + EncodingUtil.urlEncode(value, 'UTF-8');
}
```

</div>

### getRequestReplacementTokens

<div class="apex-member">

```apex
global virtual void getRequestReplacementTokens(List<String> searchTokens, List<String> replaceTokens)
```

Specifies token replacements for the request body before serialization.
Override to replace reserved words or tokens in the request body before sending.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `searchTokens` | [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm) | The list of search tokens to look for in the request body. |
| `replaceTokens` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The list of replacement tokens to use if matching search tokens are found. |

**Example**

```apex
global override void getRequestReplacementTokens(List<String> searchTokens, List<String> replaceTokens)
{
    searchTokens.add('{TODAY}');
    replaceTokens.add(String.valueOf(Date.today()));
}
```

</div>

### getRequiredInputs

<div class="apex-member">

```apex
global virtual Set<String> getRequiredInputs()
```

Indicates required service inputs.

**Returns** [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) — A set of required service input names.

**Example**

```apex
global override Set<String> getRequiredInputs()
{
    Set<String> requiredInputs = super.getRequiredInputs();
    requiredInputs.add(PARAM_RECIPIENT);
    return requiredInputs;
}
```

</div>

### getResponseBody

<div class="apex-member">

```apex
global virtual String getResponseBody()
```

Retrieves the current response body; override to manipulate response body first.
Automatically wraps array responses and applies token replacements.

**Returns** [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) — The response that will be parsed.

**Example**

```apex
global override String getResponseBody()
{
    String body = super.getResponseBody();
    // manipulate response body before parsing
    return body;
}
```

</div>

### getResponseReplacementTokens

<div class="apex-member">

```apex
global virtual void getResponseReplacementTokens(List<String> searchTokens, List<String> replaceTokens)
```

Specifies token replacements for the response body before deserialization.
Override to replace reserved words or tokens in the response before processing.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `searchTokens` | [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm) | The list of search tokens to look for in the response body. |
| `replaceTokens` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The list of replacement tokens to use if matching search tokens are found. |

**Example**

```apex
global override void getResponseReplacementTokens(List<String> searchTokens, List<String> replaceTokens)
{
    searchTokens.add('currency');
    replaceTokens.add('currencyIsoCode');
}
```

</div>

### getTimeout

<div class="apex-member">

```apex
global virtual Integer getTimeout()
```

Retrieves the HTTP Service Timeout.

**Returns** [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) — The timeout value in milliseconds, defaults to 120000.

**Example**

```apex
global override Integer getTimeout()
{
    return 60000;
}
```

</div>

### getWebServiceEndPoint

<div class="apex-member">

```apex
global virtual String getWebServiceEndPoint()
```

Constructs and returns the full URL endpoint for the web service, resolving Named Credentials and appending the API path.

**Returns** [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) — The full URL endpoint for the web service.

**Example**

```apex
global override String getWebServiceEndPoint()
{
    return super.getWebServiceEndPoint() + '/custom-path';
}
```

</div>

### hasArrayResponse

<div class="apex-member">

```apex
global virtual Boolean hasArrayResponse()
```

Checks if the JSON response is in the form of an array without a key.
Salesforce DTO classes cannot parse arrays directly, so this method helps handle responses that are arrays.

**Returns** [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) — Boolean indicating if the response is an array.

**Example**

```apex
global override Boolean hasArrayResponse()
{
    return true;
}
```

</div>

### isDisabled

<div class="apex-member">

```apex
global override Boolean isDisabled()
```

Checks whether the API has been disabled for the current user by verifying custom settings or feature switches.

**Returns** [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) — True if the API is disabled, false otherwise.

**Example**

```apex
global override Boolean isDisabled()
{
    return super.isDisabled() || customDisableCheck();
}
```

</div>

### parseResponse

<div class="apex-member">

```apex
global virtual void parseResponse()
```

Called if request is successful; override to consume response.

**Example**

```apex
global override void parseResponse()
{
    super.parseResponse();
    DTO_Response dto = (DTO_Response)responsePayload;
    // process the response
}
```

</div>

### prepareRequest

<div class="apex-member">

```apex
global virtual void prepareRequest()
```

Prepares the outbound request by querying Salesforce data and populating the request DTO.

**Example**

```apex
global override void prepareRequest()
{
    super.prepareRequest();
    // additional request preparation
}
```

</div>

### setHeaders

<div class="apex-member">

```apex
global virtual void setHeaders()
```

Sets the HTTP headers for the request. Includes Accept header for JSON responses.
Override in child classes to add additional service-specific headers.

**Example**

```apex
global override void setHeaders()
{
    super.setHeaders();
    request.setHeader('Custom-Header', 'CustomValue');
}
```

</div>

---

## Field Details

### requiresTriggeringRecord

```apex
global Boolean requiresTriggeringRecord
```

**Type:** [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm)

Whether this service requires a triggering object ID.
Override in configure() to set to false for services that don't require a triggering record.

**Example**

```apex
global override void configure()
{
    super.configure();
    requiresTriggeringRecord = false;
}
```

