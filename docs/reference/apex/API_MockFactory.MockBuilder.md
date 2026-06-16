---
title: "API_MockFactory.MockBuilder"
type: class
pageClass: reference
description: "Fluent builder for constructing and registering mock responses."
since: "1.0"
category: apex
---

# API_MockFactory.MockBuilder

**Class**

```apex
global class API_MockFactory.MockBuilder
```

Fluent builder for constructing and registering mock responses.

**Since:** 1.0

**Example:**

```apex
API_MockFactory.forService('API_SendEmail')
    .body('{"messageId":"msg-123"}')
    .statusCode(200)
    .register();
```

---

## Methods

| Method | Description |
|--------|-------------|
| global [API_MockFactory.MockBuilder](API_MockFactory.MockBuilder.md) [body](#body)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) body) | Sets the response body. |
| global [API_MockFactory.MockBuilder](API_MockFactory.MockBuilder.md) [fromResponse](#fromresponse)([HttpResponse](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_classes_restful_http_httpresponse.htm) response) | Populates the builder from an existing HttpResponse. |
| global void [register](#register)() | Registers the mock response in the factory. |
| global [API_MockFactory.MockBuilder](API_MockFactory.MockBuilder.md) [status](#status)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) status) | Sets the HTTP status text. |
| global [API_MockFactory.MockBuilder](API_MockFactory.MockBuilder.md) [statusCode](#statuscode)([Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) statusCode) | Sets the HTTP status code. |
| global [API_MockFactory.MockBuilder](API_MockFactory.MockBuilder.md) [withFailureRate](#withfailurerate)([Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) failureRate) | Sets the failure rate percentage for fault injection. |
| global [API_MockFactory.MockBuilder](API_MockFactory.MockBuilder.md) [withHeader](#withheader)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) name, [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) value) | Adds a single response header. |
| global [API_MockFactory.MockBuilder](API_MockFactory.MockBuilder.md) [withHeaders](#withheaders)([Map](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_map.htm)<[String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm), [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)> headers) | Adds multiple response headers. |

---

## Method Details

### body

<div class="apex-member">

```apex
global API_MockFactory.MockBuilder body(String body)
```

Sets the response body.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `body` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The response body (supports {{request.field}} interpolation) |

**Returns** [API_MockFactory.MockBuilder](API_MockFactory.MockBuilder.md) — This builder for chaining

</div>

### fromResponse

<div class="apex-member">

```apex
global API_MockFactory.MockBuilder fromResponse(HttpResponse response)
```

Populates the builder from an existing HttpResponse.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `response` | [HttpResponse](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_classes_restful_http_httpresponse.htm) | The HttpResponse to extract body, status code, and headers from |

**Returns** [API_MockFactory.MockBuilder](API_MockFactory.MockBuilder.md) — This builder for chaining

</div>

### register

<div class="apex-member">

```apex
global void register()
```

Registers the mock response in the factory.

</div>

### status

<div class="apex-member">

```apex
global API_MockFactory.MockBuilder status(String status)
```

Sets the HTTP status text.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `status` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The HTTP status text (e.g., "OK", "Internal Server Error") |

**Returns** [API_MockFactory.MockBuilder](API_MockFactory.MockBuilder.md) — This builder for chaining

</div>

### statusCode

<div class="apex-member">

```apex
global API_MockFactory.MockBuilder statusCode(Integer statusCode)
```

Sets the HTTP status code.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `statusCode` | [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) | The HTTP status code |

**Returns** [API_MockFactory.MockBuilder](API_MockFactory.MockBuilder.md) — This builder for chaining

</div>

### withFailureRate

<div class="apex-member">

```apex
global API_MockFactory.MockBuilder withFailureRate(Integer failureRate)
```

Sets the failure rate percentage for fault injection.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `failureRate` | [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) | Percentage of requests to fail (0-100) |

**Returns** [API_MockFactory.MockBuilder](API_MockFactory.MockBuilder.md) — This builder for chaining

</div>

### withHeader

<div class="apex-member">

```apex
global API_MockFactory.MockBuilder withHeader(String name, String value)
```

Adds a single response header.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `name` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The header name |
| `value` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The header value |

**Returns** [API_MockFactory.MockBuilder](API_MockFactory.MockBuilder.md) — This builder for chaining

</div>

### withHeaders

<div class="apex-member">

```apex
global API_MockFactory.MockBuilder withHeaders(Map<String, String> headers)
```

Adds multiple response headers.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `headers` | [Map](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_map.htm) | Map of header key-value pairs |

**Returns** [API_MockFactory.MockBuilder](API_MockFactory.MockBuilder.md) — This builder for chaining

</div>

