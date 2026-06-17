---
title: "API_MockFactory"
type: class
pageClass: reference
description: "Central factory for mock response management. Provides test isolation via scoped registries and supports both memory-based (unit tests) and metadata-based (runtime) mocking. Features: Memory mocks for"
author: "Jason Van Beukering"
group: "Web Services"
date: "February 2026, May 2026"
since: "1.0"
category: apex
---

# API_MockFactory

**Class** · Group: `Web Services`

<div class="apex-member apex-class">

```apex
global inherited sharing class API_MockFactory
```

Central factory for mock response management. Provides test isolation via scoped registries and supports both memory-based (unit tests) and metadata-based (runtime) mocking. Features: Memory mocks for unit tests with test isolation Metadata mocks for runtime/sandbox configuration Call verification for asserting mock invocations Dynamic response interpolation ({{request.field}}) Fault simulation (delays, failure rates)

**Example**

```apex
// Register a custom mock response for an outbound service
API_MockFactory.forService(API_SendEmail.class.getName())
    .body('{"messageId":"msg-123"}').statusCode(200).register();
// Register an error mock
API_MockFactory.registerErrorMock(API_SendEmail.class.getName());
```

</div>

---

## Methods

| Method | Description |
|--------|-------------|
| global static void [clearMocks](#clearmocks)() | Clears all registered memory mocks and invocation history. |
| global static [API_MockFactory.MockBuilder](API_MockFactory.MockBuilder.md) [forService](#forservice)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) serviceClassName) | Creates a fluent builder for registering a mock response. |
| global static [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) [lastRequestContains](#lastrequestcontains)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) serviceClassName, [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) expectedContent) | Verifies that the last invocation contained specific text in the request body. |
| global static void [registerErrorMock](#registererrormock)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) serviceClassName) | Registers an error mock (500 Internal Server Error) for the given service. |
| global static void [registerParseFailMock](#registerparsefailmock)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) serviceClassName) | Registers a parse-fail mock (200 OK with unparseable body) for the given service. |
| global static [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) [wasCalled](#wascalled)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) serviceClassName) | Verifies that a mock was called at least once. |
| global static [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) [wasNeverCalled](#wasnevercalled)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) serviceClassName) | Verifies that a mock was never called. |

### clearMocks

<div class="apex-member">

```apex
global static void clearMocks()
```

Clears all registered memory mocks and invocation history.

</div>

### forService

<div class="apex-member">

```apex
global static API_MockFactory.MockBuilder forService(String serviceClassName)
```

Creates a fluent builder for registering a mock response.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `serviceClassName` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The fully qualified service class name |

**Returns** [API_MockFactory.MockBuilder](API_MockFactory.MockBuilder.md) — A new MockBuilder for chaining

**Example**

```apex
API_MockFactory.forService('API_SendEmail')
    .body('{"messageId":"msg-123"}')
    .statusCode(200)
    .register();
```

</div>

### lastRequestContains

<div class="apex-member">

```apex
global static Boolean lastRequestContains(String serviceClassName, String expectedContent)
```

Verifies that the last invocation contained specific text in the request body.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `serviceClassName` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The service class name |
| `expectedContent` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | Text that should be present in the request body |

**Returns** [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) — True if the last request body contains the expected content

</div>

### registerErrorMock

<div class="apex-member">

```apex
global static void registerErrorMock(String serviceClassName)
```

Registers an error mock (500 Internal Server Error) for the given service.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `serviceClassName` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The service class name to register an error mock for |

**Example**

```apex
API_MockFactory.registerErrorMock(API_SendEmail.class.getName());
```

</div>

### registerParseFailMock

<div class="apex-member">

```apex
global static void registerParseFailMock(String serviceClassName)
```

Registers a parse-fail mock (200 OK with unparseable body) for the given service.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `serviceClassName` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The service class name to register a parse-fail mock for |

**Example**

```apex
API_MockFactory.registerParseFailMock(API_SendEmail.class.getName());
```

</div>

### wasCalled

<div class="apex-member">

```apex
global static Boolean wasCalled(String serviceClassName)
```

Verifies that a mock was called at least once.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `serviceClassName` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The service class name to verify |

**Returns** [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) — True if the mock was invoked at least once

</div>

### wasNeverCalled

<div class="apex-member">

```apex
global static Boolean wasNeverCalled(String serviceClassName)
```

Verifies that a mock was never called.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `serviceClassName` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The service class name to verify |

**Returns** [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) — True if the mock was never invoked

</div>

## Inner Classes

| Class | Description |
|-------|-------------|
| [MockBuilder](API_MockFactory.MockBuilder.md) | Fluent builder for constructing and registering mock responses. |
| [MockResponse](API_MockFactory.MockResponse.md) | Represents a mock HTTP response with fault simulation options. |

---

