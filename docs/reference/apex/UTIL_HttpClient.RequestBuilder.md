---
title: "UTIL_HttpClient.RequestBuilder"
type: class
pageClass: reference
description: "Fluent builder for configuring and executing HTTP requests through API_Dispatcher."
since: "1.0"
category: apex
---

# UTIL_HttpClient.RequestBuilder

**Class**

```apex
global inherited sharing class UTIL_HttpClient.RequestBuilder
```

Fluent builder for configuring and executing HTTP requests through API_Dispatcher.

**Since:** 1.0

**Example:**

```apex
Map<String, Object> result = UTIL_HttpClient.get('MyService', '/status')
   .header('X-Custom', 'value')
   .timeout(30000)
   .asMap();
```

---

## Methods

| Method | Description |
|--------|-------------|
| global [Map](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_map.htm)<[String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm), [Object](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_System_Object.htm)> [asMap](#asmap)() | Executes the request and deserializes the response body as an untyped Map. |
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [asString](#asstring)() | Executes the request and returns the response body as a String. |
| global [UTIL_HttpClient.RequestBuilder](UTIL_HttpClient.RequestBuilder.md) [body](#body)([Object](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_System_Object.htm) requestBody) | Sets the request body by JSON-serializing the provided object. |
| global [UTIL_HttpClient.RequestBuilder](UTIL_HttpClient.RequestBuilder.md) [body](#body)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) requestBody) | Sets the request body as a raw string. |
| global [UTIL_HttpClient.RequestBuilder](UTIL_HttpClient.RequestBuilder.md) [credential](#credential)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) credential) | Sets the Named Credential for the endpoint. |
| global [Object](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_System_Object.htm) [deserialize](#deserialize)([Type](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_type.htm) responseType) | Executes the request and deserializes the response body into the specified type. |
| global [UTIL_HttpClient.RequestBuilder](UTIL_HttpClient.RequestBuilder.md) [header](#header)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) name, [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) value) | Adds a single header to the request. |
| global [UTIL_HttpClient.RequestBuilder](UTIL_HttpClient.RequestBuilder.md) [headers](#headers)([Map](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_map.htm)<[String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm), [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)> headerMap) | Adds multiple headers to the request. |
| global [API_Outbound](API_Outbound.md) [invoke](#invoke)() | Executes in delegation mode and returns the delegate handler instance. |
| global [UTIL_HttpClient.RequestBuilder](UTIL_HttpClient.RequestBuilder.md) [method](#method)([API_Base.HttpMethod](API_Base.HttpMethod.md) httpMethod) | Sets the HTTP method for the request. |
| global [UTIL_HttpClient.RequestBuilder](UTIL_HttpClient.RequestBuilder.md) [onFailure](#onfailure)([UTIL_HttpClient.FailureAction](UTIL_HttpClient.FailureAction.md) action) | Sets the failure handling strategy. |
| global [UTIL_HttpClient.RequestBuilder](UTIL_HttpClient.RequestBuilder.md) [path](#path)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) urlPath) | Sets the URL path for the request. |
| global [UTIL_HttpClient.RequestBuilder](UTIL_HttpClient.RequestBuilder.md) [pathParam](#pathparam)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) name, [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) value) | Replaces a {name} placeholder in the URL path with a value. |
| global [UTIL_HttpClient.RequestBuilder](UTIL_HttpClient.RequestBuilder.md) [queryParam](#queryparam)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) name, [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) value) | Adds a query parameter to the request URL. |
| global [UTIL_HttpClient.RequestBuilder](UTIL_HttpClient.RequestBuilder.md) [replaceRequestToken](#replacerequesttoken)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) searchToken, [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) replaceToken) | Registers a single request body replacement token. |
| global [UTIL_HttpClient.RequestBuilder](UTIL_HttpClient.RequestBuilder.md) [replaceRequestTokens](#replacerequesttokens)([Map](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_map.htm)<[String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm), [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)> tokens) | Registers multiple request body replacement tokens. |
| global [UTIL_HttpClient.RequestBuilder](UTIL_HttpClient.RequestBuilder.md) [replaceResponseToken](#replaceresponsetoken)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) searchToken, [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) replaceToken) | Registers a single response body replacement token. |
| global [UTIL_HttpClient.RequestBuilder](UTIL_HttpClient.RequestBuilder.md) [replaceResponseTokens](#replaceresponsetokens)([Map](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_map.htm)<[String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm), [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)> tokens) | Registers multiple response body replacement tokens. |
| global [UTIL_HttpClient.RequestBuilder](UTIL_HttpClient.RequestBuilder.md) [retryOn](#retryon)([Set](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_set.htm)<[Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm)> statusCodes) | Restricts retry to specific HTTP status codes. |
| global [HttpResponse](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_classes_restful_http_httpresponse.htm) [send](#send)() | Executes the HTTP request and returns the raw HttpResponse. |
| global [UTIL_HttpClient.RequestBuilder](UTIL_HttpClient.RequestBuilder.md) [skipLogging](#skiplogging)() | Skips ApiCall__c persistence for this request. |
| global [UTIL_HttpClient.RequestBuilder](UTIL_HttpClient.RequestBuilder.md) [timeout](#timeout)([Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) milliseconds) | Sets the request timeout in milliseconds. |
| global [UTIL_HttpClient.RequestBuilder](UTIL_HttpClient.RequestBuilder.md) [withCircuitBreaker](#withcircuitbreaker)() | Enables circuit breaker protection using the credential name as identifier. |
| global [UTIL_HttpClient.RequestBuilder](UTIL_HttpClient.RequestBuilder.md) [withCircuitBreaker](#withcircuitbreaker)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) circuitName) | Enables circuit breaker protection with a custom identifier. |
| global [UTIL_HttpClient.RequestBuilder](UTIL_HttpClient.RequestBuilder.md) [withCorrelationId](#withcorrelationid)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) correlationId) | Sets a correlation ID for cross-transaction log tracing. |
| global [UTIL_HttpClient.RequestBuilder](UTIL_HttpClient.RequestBuilder.md) [withExponentialBackoff](#withexponentialbackoff)([Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) maxRetries, [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) baseBackoffSeconds) | Enables synchronous retry with exponential backoff. |
| global [UTIL_HttpClient.RequestBuilder](UTIL_HttpClient.RequestBuilder.md) [withIdempotencyKey](#withidempotencykey)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) idempotencyKey) | Sets an explicit idempotency key for duplicate detection. |
| global [UTIL_HttpClient.RequestBuilder](UTIL_HttpClient.RequestBuilder.md) [withMockResponse](#withmockresponse)([API_MockFactory.MockResponse](API_MockFactory.MockResponse.md) mockResponse) | Sets a mock response to inject at framework level, overriding the handler's own mock. |
| global [UTIL_HttpClient.RequestBuilder](UTIL_HttpClient.RequestBuilder.md) [withParameter](#withparameter)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) name, [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) value) | Adds a request parameter for subscriber handler mode. |
| global [UTIL_HttpClient.RequestBuilder](UTIL_HttpClient.RequestBuilder.md) [withParameters](#withparameters)([Map](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_map.htm)<[String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm), [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)> parameters) | Adds multiple request parameters for subscriber handler mode. |
| global [UTIL_HttpClient.RequestBuilder](UTIL_HttpClient.RequestBuilder.md) [withRetry](#withretry)([Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) maxRetries) | Enables synchronous retry with the specified maximum attempts. |
| global [UTIL_HttpClient.RequestBuilder](UTIL_HttpClient.RequestBuilder.md) [withRetry](#withretry)([Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) maxRetries, [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) backoffSeconds) | Enables synchronous retry with a linear backoff. |
| global [UTIL_HttpClient.RequestBuilder](UTIL_HttpClient.RequestBuilder.md) [withTriggeringRecord](#withtriggeringrecord)([Id](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_id.htm) recordId) | Links this callout to a triggering business record. |

---

## Method Details

### asMap

<div class="apex-member">

```apex
global Map<String, Object> asMap()
```

Executes the request and deserializes the response body as an untyped Map.

**Returns** [Object](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_System_Object.htm) — The deserialized response as Map of String to Object

**Example**

```apex
Map<String, Object> data = UTIL_HttpClient.get('MyService', '/data').asMap();
```

</div>

### asString

<div class="apex-member">

```apex
global String asString()
```

Executes the request and returns the response body as a String.

**Returns** [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) — The response body string

**Example**

```apex
String body = UTIL_HttpClient.get('MyService', '/data').asString();
```

</div>

### body

<div class="apex-member">

```apex
global UTIL_HttpClient.RequestBuilder body(Object requestBody)
```

Sets the request body by JSON-serializing the provided object.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `requestBody` | [Object](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_System_Object.htm) | The object to serialize as JSON |

**Returns** [UTIL_HttpClient.RequestBuilder](UTIL_HttpClient.RequestBuilder.md) — This builder for method chaining

**Example**

```apex
UTIL_HttpClient.post('MyService', '/send')
   .body(new Map<String, String>{'key' => 'value'})
   .send();
```

</div>

<div class="apex-member">

```apex
global UTIL_HttpClient.RequestBuilder body(String requestBody)
```

Sets the request body as a raw string.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `requestBody` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The raw body string |

**Returns** [UTIL_HttpClient.RequestBuilder](UTIL_HttpClient.RequestBuilder.md) — This builder for method chaining

**Example**

```apex
UTIL_HttpClient.post('MyService', '/send')
   .body('{"key": "value"}')
   .send();
```

</div>

### credential

<div class="apex-member">

```apex
global UTIL_HttpClient.RequestBuilder credential(String credential)
```

Sets the Named Credential for the endpoint.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `credential` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The Named Credential name |

**Returns** [UTIL_HttpClient.RequestBuilder](UTIL_HttpClient.RequestBuilder.md) — This builder for method chaining

**Example**

```apex
UTIL_HttpClient.useHandler(API_SendEmail.class)
   .credential('EmailGateway')
   .invoke();
```

</div>

### deserialize

<div class="apex-member">

```apex
global Object deserialize(Type responseType)
```

Executes the request and deserializes the response body into the specified type.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `responseType` | [Type](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_type.htm) | The Apex Type to deserialize into |

**Returns** [Object](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_System_Object.htm) — The deserialized response object

**Example**

```apex
MyDTO result = (MyDTO)UTIL_HttpClient.get('MyService', '/data')
   .deserialize(MyDTO.class);
```

</div>

### header

<div class="apex-member">

```apex
global UTIL_HttpClient.RequestBuilder header(String name, String value)
```

Adds a single header to the request.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `name` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The header name |
| `value` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The header value |

**Returns** [UTIL_HttpClient.RequestBuilder](UTIL_HttpClient.RequestBuilder.md) — This builder for method chaining

**Example**

```apex
UTIL_HttpClient.post('MyService', '/send')
   .header('X-Custom', 'value')
   .send();
```

</div>

### headers

<div class="apex-member">

```apex
global UTIL_HttpClient.RequestBuilder headers(Map<String, String> headerMap)
```

Adds multiple headers to the request.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `headerMap` | [Map](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_map.htm) | Map of header names to values |

**Returns** [UTIL_HttpClient.RequestBuilder](UTIL_HttpClient.RequestBuilder.md) — This builder for method chaining

**Example**

```apex
UTIL_HttpClient.post('MyService', '/send')
   .headers(new Map<String, String>{'X-Custom' => 'value', 'X-Trace' => 'abc'})
   .send();
```

</div>

### invoke

<div class="apex-member">

```apex
global API_Outbound invoke()
```

Executes in delegation mode and returns the delegate handler instance.

**Returns** [API_Outbound](API_Outbound.md) — The executed API_Outbound delegate handler

**Example**

```apex
API_Outbound handler = UTIL_HttpClient.useHandler(API_SendEmail.class)
   .withTriggeringRecord(recordId)
   .invoke();
API_SendEmail.DTO_Response dto = (API_SendEmail.DTO_Response)handler.responsePayload;
```

</div>

### method

<div class="apex-member">

```apex
global UTIL_HttpClient.RequestBuilder method(API_Base.HttpMethod httpMethod)
```

Sets the HTTP method for the request.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `httpMethod` | [API_Base.HttpMethod](API_Base.HttpMethod.md) | The HTTP method enum value |

**Returns** [UTIL_HttpClient.RequestBuilder](UTIL_HttpClient.RequestBuilder.md) — This builder for method chaining

**Example**

```apex
UTIL_HttpClient.post('MyService', '/data')
   .method(API_Base.HttpMethod.PUT)
   .send();
```

</div>

### onFailure

<div class="apex-member">

```apex
global UTIL_HttpClient.RequestBuilder onFailure(UTIL_HttpClient.FailureAction action)
```

Sets the failure handling strategy.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `action` | [UTIL_HttpClient.FailureAction](UTIL_HttpClient.FailureAction.md) | The failure action to apply |

**Returns** [UTIL_HttpClient.RequestBuilder](UTIL_HttpClient.RequestBuilder.md) — This builder for method chaining

**Example**

```apex
UTIL_HttpClient.post('MyService', '/send')
   .onFailure(UTIL_HttpClient.FailureAction.LOG_FAILURE)
   .send();
```

</div>

### path

<div class="apex-member">

```apex
global UTIL_HttpClient.RequestBuilder path(String urlPath)
```

Sets the URL path for the request.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `urlPath` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The URL path to append |

**Returns** [UTIL_HttpClient.RequestBuilder](UTIL_HttpClient.RequestBuilder.md) — This builder for method chaining

**Example**

```apex
UTIL_HttpClient.post('MyService', '/api')
   .path('/v2/send')
   .send();
```

</div>

### pathParam

<div class="apex-member">

```apex
global UTIL_HttpClient.RequestBuilder pathParam(String name, String value)
```

Replaces a {name} placeholder in the URL path with a value.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `name` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The placeholder name (without braces) |
| `value` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The replacement value |

**Returns** [UTIL_HttpClient.RequestBuilder](UTIL_HttpClient.RequestBuilder.md) — This builder for method chaining

**Example**

```apex
UTIL_HttpClient.get('CRM', '/accounts/{id}')
   .pathParam('id', accountId)
   .send();
```

</div>

### queryParam

<div class="apex-member">

```apex
global UTIL_HttpClient.RequestBuilder queryParam(String name, String value)
```

Adds a query parameter to the request URL.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `name` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The parameter name |
| `value` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The parameter value |

**Returns** [UTIL_HttpClient.RequestBuilder](UTIL_HttpClient.RequestBuilder.md) — This builder for method chaining

**Example**

```apex
UTIL_HttpClient.get('MyService', '/search')
   .queryParam('q', 'test')
   .queryParam('limit', '10')
   .send();
```

</div>

### replaceRequestToken

<div class="apex-member">

```apex
global UTIL_HttpClient.RequestBuilder replaceRequestToken(String searchToken, String replaceToken)
```

Registers a single request body replacement token. The search token in the serialized request
body will be replaced with the replace token before sending.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `searchToken` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The token to search for in the request body |
| `replaceToken` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The token to replace it with |

**Returns** [UTIL_HttpClient.RequestBuilder](UTIL_HttpClient.RequestBuilder.md) — This builder for method chaining

**Example**

```apex
UTIL_HttpClient.post('PaymentGateway', '/charges')
   .body(chargeRequest)
   .replaceRequestToken('currencyIsoCode', 'currency')
   .send();
```

</div>

### replaceRequestTokens

<div class="apex-member">

```apex
global UTIL_HttpClient.RequestBuilder replaceRequestTokens(Map<String, String> tokens)
```

Registers multiple request body replacement tokens. Each search token in the serialized
request body will be replaced with its corresponding replace token before sending.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `tokens` | [Map](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_map.htm) | Map of search tokens to their replacement values |

**Returns** [UTIL_HttpClient.RequestBuilder](UTIL_HttpClient.RequestBuilder.md) — This builder for method chaining

**Example**

```apex
UTIL_HttpClient.post('PaymentGateway', '/charges')
   .body(chargeRequest)
   .replaceRequestTokens(new Map<String, String>{'currencyIsoCode' => 'currency', 'groupName' => 'group'})
   .send();
```

</div>

### replaceResponseToken

<div class="apex-member">

```apex
global UTIL_HttpClient.RequestBuilder replaceResponseToken(String searchToken, String replaceToken)
```

Registers a single response body replacement token. The search token in the response
body will be replaced with the replace token after receiving.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `searchToken` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The token to search for in the response body |
| `replaceToken` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The token to replace it with |

**Returns** [UTIL_HttpClient.RequestBuilder](UTIL_HttpClient.RequestBuilder.md) — This builder for method chaining

**Example**

```apex
HttpResponse response = UTIL_HttpClient.get('PaymentGateway', '/charges')
   .replaceResponseToken('currency', 'currencyIsoCode')
   .send();
```

</div>

### replaceResponseTokens

<div class="apex-member">

```apex
global UTIL_HttpClient.RequestBuilder replaceResponseTokens(Map<String, String> tokens)
```

Registers multiple response body replacement tokens. Each search token in the response
body will be replaced with its corresponding replace token after receiving.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `tokens` | [Map](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_map.htm) | Map of search tokens to their replacement values |

**Returns** [UTIL_HttpClient.RequestBuilder](UTIL_HttpClient.RequestBuilder.md) — This builder for method chaining

**Example**

```apex
HttpResponse response = UTIL_HttpClient.get('PaymentGateway', '/charges')
   .replaceResponseTokens(new Map<String, String>{'currency' => 'currencyIsoCode', 'group' => 'groupName'})
   .send();
```

</div>

### retryOn

<div class="apex-member">

```apex
global UTIL_HttpClient.RequestBuilder retryOn(Set<Integer> statusCodes)
```

Restricts retry to specific HTTP status codes.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `statusCodes` | [Set](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_set.htm) | The status codes eligible for retry |

**Returns** [UTIL_HttpClient.RequestBuilder](UTIL_HttpClient.RequestBuilder.md) — This builder for method chaining

**Example**

```apex
UTIL_HttpClient.post('MyService', '/send')
   .withRetry(3)
   .retryOn(new Set<Integer>{500, 503})
   .send();
```

</div>

### send

<div class="apex-member">

```apex
global HttpResponse send()
```

Executes the HTTP request and returns the raw HttpResponse.

**Returns** [HttpResponse](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_classes_restful_http_httpresponse.htm) — The HttpResponse from the callout

**Example**

```apex
HttpResponse response = UTIL_HttpClient.get('MyService', '/data').send();
```

</div>

### skipLogging

<div class="apex-member">

```apex
global UTIL_HttpClient.RequestBuilder skipLogging()
```

Skips ApiCall__c persistence for this request.

**Returns** [UTIL_HttpClient.RequestBuilder](UTIL_HttpClient.RequestBuilder.md) — This builder for method chaining

**Example**

```apex
UTIL_HttpClient.get('MyService', '/healthCheck')
   .skipLogging()
   .send();
```

</div>

### timeout

<div class="apex-member">

```apex
global UTIL_HttpClient.RequestBuilder timeout(Integer milliseconds)
```

Sets the request timeout in milliseconds.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `milliseconds` | [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) | The timeout value |

**Returns** [UTIL_HttpClient.RequestBuilder](UTIL_HttpClient.RequestBuilder.md) — This builder for method chaining

**Example**

```apex
UTIL_HttpClient.get('MyService', '/data')
   .timeout(30000)
   .send();
```

</div>

### withCircuitBreaker

<div class="apex-member">

```apex
global UTIL_HttpClient.RequestBuilder withCircuitBreaker()
```

Enables circuit breaker protection using the credential name as identifier.

**Returns** [UTIL_HttpClient.RequestBuilder](UTIL_HttpClient.RequestBuilder.md) — This builder for method chaining

**Example**

```apex
UTIL_HttpClient.post('MyService', '/send')
   .withCircuitBreaker()
   .send();
```

</div>

<div class="apex-member">

```apex
global UTIL_HttpClient.RequestBuilder withCircuitBreaker(String circuitName)
```

Enables circuit breaker protection with a custom identifier.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `circuitName` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The circuit breaker identifier |

**Returns** [UTIL_HttpClient.RequestBuilder](UTIL_HttpClient.RequestBuilder.md) — This builder for method chaining

**Example**

```apex
UTIL_HttpClient.post('MyService', '/send')
   .withCircuitBreaker('payment-gateway')
   .send();
```

</div>

### withCorrelationId

<div class="apex-member">

```apex
global UTIL_HttpClient.RequestBuilder withCorrelationId(String correlationId)
```

Sets a correlation ID for cross-transaction log tracing.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `correlationId` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The correlation identifier |

**Returns** [UTIL_HttpClient.RequestBuilder](UTIL_HttpClient.RequestBuilder.md) — This builder for method chaining

**Example**

```apex
UTIL_HttpClient.post('MyService', '/send')
   .withCorrelationId('txn-12345')
   .send();
```

</div>

### withExponentialBackoff

<div class="apex-member">

```apex
global UTIL_HttpClient.RequestBuilder withExponentialBackoff(Integer maxRetries, Integer baseBackoffSeconds)
```

Enables synchronous retry with exponential backoff.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `maxRetries` | [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) | The maximum number of retry attempts |
| `baseBackoffSeconds` | [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) | The base backoff period in seconds |

**Returns** [UTIL_HttpClient.RequestBuilder](UTIL_HttpClient.RequestBuilder.md) — This builder for method chaining

**Example**

```apex
UTIL_HttpClient.post('MyService', '/send')
   .withExponentialBackoff(3, 2)
   .send();
```

</div>

### withIdempotencyKey

<div class="apex-member">

```apex
global UTIL_HttpClient.RequestBuilder withIdempotencyKey(String idempotencyKey)
```

Sets an explicit idempotency key for duplicate detection.
When set, this key takes priority over auto-generated keys.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `idempotencyKey` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The idempotency key value |

**Returns** [UTIL_HttpClient.RequestBuilder](UTIL_HttpClient.RequestBuilder.md) — This builder for method chaining

**Example**

```apex
UTIL_HttpClient.post('PaymentGateway', '/charges')
   .body(chargeRequest)
   .withIdempotencyKey('order-12345')
   .send();
```

</div>

### withMockResponse

<div class="apex-member">

```apex
global UTIL_HttpClient.RequestBuilder withMockResponse(API_MockFactory.MockResponse mockResponse)
```

Sets a mock response to inject at framework level, overriding the handler's own mock.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `mockResponse` | [API_MockFactory.MockResponse](API_MockFactory.MockResponse.md) | The mock response to inject |

**Returns** [UTIL_HttpClient.RequestBuilder](UTIL_HttpClient.RequestBuilder.md) — This builder for method chaining

**Example**

```apex
API_MockFactory.MockResponse mock = new API_MockFactory.MockResponse();
mock.body = '{"id": "12345"}';
UTIL_HttpClient.post('MyService', '/send')
   .withMockResponse(mock)
   .send();
```

</div>

### withParameter

<div class="apex-member">

```apex
global UTIL_HttpClient.RequestBuilder withParameter(String name, String value)
```

Adds a request parameter for subscriber handler mode.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `name` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The parameter name |
| `value` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The parameter value |

**Returns** [UTIL_HttpClient.RequestBuilder](UTIL_HttpClient.RequestBuilder.md) — This builder for method chaining

**Example**

```apex
UTIL_HttpClient.useHandler(API_SendEmail.class)
   .withParameter(API_SendEmail.PARAM_SUBJECT, 'Hello')
   .invoke();
```

</div>

### withParameters

<div class="apex-member">

```apex
global UTIL_HttpClient.RequestBuilder withParameters(Map<String, String> parameters)
```

Adds multiple request parameters for subscriber handler mode.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `parameters` | [Map](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_map.htm) | Map of parameter names to values |

**Returns** [UTIL_HttpClient.RequestBuilder](UTIL_HttpClient.RequestBuilder.md) — This builder for method chaining

**Example**

```apex
Map<String, String> parameters = new Map<String, String>{'key' => 'value'};
UTIL_HttpClient.useHandler(API_SendEmail.class)
   .withParameters(parameters)
   .invoke();
```

</div>

### withRetry

<div class="apex-member">

```apex
global UTIL_HttpClient.RequestBuilder withRetry(Integer maxRetries)
```

Enables synchronous retry with the specified maximum attempts.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `maxRetries` | [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) | The maximum number of retry attempts |

**Returns** [UTIL_HttpClient.RequestBuilder](UTIL_HttpClient.RequestBuilder.md) — This builder for method chaining

**Example**

```apex
UTIL_HttpClient.post('MyService', '/send')
   .withRetry(3)
   .send();
```

</div>

<div class="apex-member">

```apex
global UTIL_HttpClient.RequestBuilder withRetry(Integer maxRetries, Integer backoffSeconds)
```

Enables synchronous retry with a linear backoff.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `maxRetries` | [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) | The maximum number of retry attempts |
| `backoffSeconds` | [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) | The backoff period in seconds |

**Returns** [UTIL_HttpClient.RequestBuilder](UTIL_HttpClient.RequestBuilder.md) — This builder for method chaining

**Example**

```apex
UTIL_HttpClient.post('MyService', '/send')
   .withRetry(3, 5)
   .send();
```

</div>

### withTriggeringRecord

<div class="apex-member">

```apex
global UTIL_HttpClient.RequestBuilder withTriggeringRecord(Id recordId)
```

Links this callout to a triggering business record.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `recordId` | [Id](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_id.htm) | The Salesforce record Id |

**Returns** [UTIL_HttpClient.RequestBuilder](UTIL_HttpClient.RequestBuilder.md) — This builder for method chaining

**Example**

```apex
UTIL_HttpClient.post('MyService', '/send')
   .withTriggeringRecord(record.Id)
   .send();
```

</div>

