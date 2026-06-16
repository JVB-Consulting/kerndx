---
title: "API_MockFactory.MockResponse"
type: class
pageClass: reference
description: "Represents a mock HTTP response with fault simulation options."
since: "1.0"
category: apex
---

# API_MockFactory.MockResponse

**Class**

<div class="apex-member apex-class">

```apex
global class API_MockFactory.MockResponse
```

Represents a mock HTTP response with fault simulation options.

</div>

---

## Fields

| Field | Description |
|-------|-------------|
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [body](#body) | The response body content (supports {{request.field}} interpolation). |
| global [Map](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_map.htm)<[String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm), [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)> [headers](#headers) | Response headers as key-value pairs. |
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [status](#status) | The HTTP status text (e.g., "OK", "Internal Server Error"). |
| global [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) [statusCode](#statuscode) | The HTTP status code. |

---

## Field Details

### body

```apex
global String body
```

**Type:** [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)

The response body content (supports {{request.field}} interpolation).

### headers

```apex
global Map<String, String> headers
```

**Type:** [Map](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_map.htm)

Response headers as key-value pairs.

### status

```apex
global String status
```

**Type:** [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)

The HTTP status text (e.g., "OK", "Internal Server Error").

### statusCode

```apex
global Integer statusCode
```

**Type:** [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm)

The HTTP status code.

