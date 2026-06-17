---
title: "UTIL_HttpClient"
type: class
pageClass: reference
description: "Fluent HTTP client facade over the API_Dispatcher pipeline. Provides zero-boilerplate callouts with automatic retry, circuit breaker, failure logging, performance timing, sensitive data masking, and A"
author: "Jason Van Beukering"
group: "Web Services"
date: "February 2026, May 2026"
since: "1.0"
category: apex
---

# UTIL_HttpClient

**Class** · Group: `Web Services`

<div class="apex-member apex-class">

```apex
global inherited sharing class UTIL_HttpClient
```

Fluent HTTP client facade over the API_Dispatcher pipeline. Provides zero-boilerplate callouts with automatic retry, circuit breaker, failure logging, performance timing, sensitive data masking, and ApiCall__c lifecycle management — all routed through API_Dispatcher.execute(). Supports two usage modes: Ad-hoc mode: Direct HTTP calls via get()/post()/put()/del()/patch() entry points Delegation mode: Subscriber handlers via useHandler() entry point

**Example**

```apex
HttpResponse response = UTIL_HttpClient.post('PaymentGateway', '/charges')
   .body(chargeRequest)
   .withRetry(3)
   .send();
```

</div>

---

## Methods

| Method | Description |
|--------|-------------|
| global static [UTIL_HttpClient.RequestBuilder](UTIL_HttpClient.RequestBuilder.md) [del](#del)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) credential, [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) path) | Creates a DELETE request for the specified credential and path. |
| global static [UTIL_HttpClient.RequestBuilder](UTIL_HttpClient.RequestBuilder.md) [get](#get)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) credential, [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) path) | Creates a GET request for the specified credential and path. |
| global static [UTIL_HttpClient.RequestBuilder](UTIL_HttpClient.RequestBuilder.md) [patch](#patch)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) credential, [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) path) | Creates a PATCH request for the specified credential and path. |
| global static [UTIL_HttpClient.RequestBuilder](UTIL_HttpClient.RequestBuilder.md) [post](#post)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) credential, [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) path) | Creates a POST request for the specified credential and path. |
| global static [UTIL_HttpClient.RequestBuilder](UTIL_HttpClient.RequestBuilder.md) [put](#put)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) credential, [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) path) | Creates a PUT request for the specified credential and path. |
| global static [UTIL_HttpClient.RequestBuilder](UTIL_HttpClient.RequestBuilder.md) [useHandler](#usehandler)([Type](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_type.htm) handlerType) | Creates a delegation mode request for the specified subscriber handler. |

### del

<div class="apex-member">

```apex
global static UTIL_HttpClient.RequestBuilder del(String credential, String path)
```

Creates a DELETE request for the specified credential and path.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `credential` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The Named Credential or ApiCredential__mdt DeveloperName |
| `path` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The URL path to append to the endpoint |

**Returns** [UTIL_HttpClient.RequestBuilder](UTIL_HttpClient.RequestBuilder.md) — A RequestBuilder for further configuration

**Example**

```apex
HttpResponse response = UTIL_HttpClient.del('CRM', '/contacts/{id}')
   .pathParam('id', contactId)
   .send();
```

</div>

### get

<div class="apex-member">

```apex
global static UTIL_HttpClient.RequestBuilder get(String credential, String path)
```

Creates a GET request for the specified credential and path.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `credential` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The Named Credential or ApiCredential__mdt DeveloperName |
| `path` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The URL path to append to the endpoint |

**Returns** [UTIL_HttpClient.RequestBuilder](UTIL_HttpClient.RequestBuilder.md) — A RequestBuilder for further configuration

**Example**

```apex
HttpResponse response = UTIL_HttpClient.get('CRM', '/accounts/{id}')
   .pathParam('id', accountId)
   .send();
```

</div>

### patch

<div class="apex-member">

```apex
global static UTIL_HttpClient.RequestBuilder patch(String credential, String path)
```

Creates a PATCH request for the specified credential and path.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `credential` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The Named Credential or ApiCredential__mdt DeveloperName |
| `path` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The URL path to append to the endpoint |

**Returns** [UTIL_HttpClient.RequestBuilder](UTIL_HttpClient.RequestBuilder.md) — A RequestBuilder for further configuration

**Example**

```apex
HttpResponse response = UTIL_HttpClient.patch('CRM', '/contacts/{id}')
   .pathParam('id', contactId)
   .body(patchPayload)
   .send();
```

</div>

### post

<div class="apex-member">

```apex
global static UTIL_HttpClient.RequestBuilder post(String credential, String path)
```

Creates a POST request for the specified credential and path.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `credential` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The Named Credential or ApiCredential__mdt DeveloperName |
| `path` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The URL path to append to the endpoint |

**Returns** [UTIL_HttpClient.RequestBuilder](UTIL_HttpClient.RequestBuilder.md) — A RequestBuilder for further configuration

**Example**

```apex
HttpResponse response = UTIL_HttpClient.post('EmailService', '/send')
   .body(emailPayload)
   .send();
```

</div>

### put

<div class="apex-member">

```apex
global static UTIL_HttpClient.RequestBuilder put(String credential, String path)
```

Creates a PUT request for the specified credential and path.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `credential` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The Named Credential or ApiCredential__mdt DeveloperName |
| `path` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The URL path to append to the endpoint |

**Returns** [UTIL_HttpClient.RequestBuilder](UTIL_HttpClient.RequestBuilder.md) — A RequestBuilder for further configuration

**Example**

```apex
HttpResponse response = UTIL_HttpClient.put('CRM', '/contacts/{id}')
   .pathParam('id', contactId)
   .body(contactPayload)
   .send();
```

</div>

### useHandler

<div class="apex-member">

```apex
global static UTIL_HttpClient.RequestBuilder useHandler(Type handlerType)
```

Creates a delegation mode request for the specified subscriber handler.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `handlerType` | [Type](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_type.htm) | The API_Outbound subclass Type to delegate to |

**Returns** [UTIL_HttpClient.RequestBuilder](UTIL_HttpClient.RequestBuilder.md) — A RequestBuilder configured for delegation mode

**Example**

```apex
API_Outbound handler = UTIL_HttpClient.useHandler(API_SendEmail.class)
   .credential('EmailGateway')
   .withParameter(API_SendEmail.PARAM_RECIPIENT, email)
   .invoke();
```

</div>

## Inner Classes

| Class | Description |
|-------|-------------|
| [FailureAction](UTIL_HttpClient.FailureAction.md) | Defines the action to take when an HTTP call fails. |
| [RequestBuilder](UTIL_HttpClient.RequestBuilder.md) | Fluent builder for configuring and executing HTTP requests through API_Dispatcher. |

---

