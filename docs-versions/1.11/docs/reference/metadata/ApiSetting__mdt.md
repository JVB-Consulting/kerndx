---
title: "ApiSetting__mdt"
type: sobject
pageClass: reference
description: "Configures outbound web service handlers with endpoint paths, retry behavior, circuit breaker settings, and failure logging options."
category: metadata
---

# ApiSetting__mdt

**Sobject**

<div class="apex-member apex-class">

```apex
global class ApiSetting__mdt extends SObject
```

**Extends:** [SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm)

Configures outbound web service handlers with endpoint paths, retry behavior, circuit breaker settings, and failure logging options.

</div>

---

## Fields

| Field | Description |
|-------|-------------|
| global [Id](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_id.htm) [ApiCredential__c](#apicredential__c) | The API Credential record that holds the sign-in details the handler of this service uses with the endpoint it calls. |
| global [ApiCredential__mdt](../metadata/ApiCredential__mdt.md) [ApiCredential__r](#apicredential__r) | The API Credential record that holds the sign-in details the handler of this service uses with the endpoint it calls. |
| global [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[ApiMock__mdt](../metadata/ApiMock__mdt.md)> [ApiMocks__r](#apimocks__r) | Reciprocal relationship for ApiMock__mdt.ApiSetting__c. |
| global [Id](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_id.htm) [BypassFeatureFlag__c](#bypassfeatureflag__c) | Optional. |
| global [FeatureFlag__mdt](../metadata/FeatureFlag__mdt.md) [BypassFeatureFlag__r](#bypassfeatureflag__r) | Optional. |
| global [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) [CircuitBreakerEnabled__c](#circuitbreakerenabled__c) | Enable circuit breaker pattern to prevent cascading failures when the external service is down |
| global [Decimal](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_decimal.htm) [CircuitBreakerFailureThreshold__c](#circuitbreakerfailurethreshold__c) | Number of consecutive failures before opening the circuit (default: 10 for high tolerance) |
| global [Decimal](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_decimal.htm) [CircuitBreakerSuccessThreshold__c](#circuitbreakersuccessthreshold__c) | Number of consecutive successes in half-open state to close the circuit (default: 2) |
| global [Decimal](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_decimal.htm) [CircuitBreakerTimeout__c](#circuitbreakertimeout__c) | Seconds to wait before attempting to close the circuit (default: 60) |
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [ClassName__c](#classname__c) | The name of the Apex class that handles this service, such as API_Handler or MyNamespace.API_Handler. |
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [Direction__c](#direction__c) | Indicates whether this API setting applies to inbound requests or outbound calls. |
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [EndpointPath__c](#endpointpath__c) | The path of this service. |
| global [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) [IdempotencyEnabled__c](#idempotencyenabled__c) | Idempotency means that processing the same request twice has the same effect as processing it once. |
| global [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) [IsActive__c](#isactive__c) | Turns this service on or off, for outgoing and incoming services alike. |
| global [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) [LogIssues__c](#logissues__c) | When ticked, a failed call of this service leaves an API issue that a person can review, run again or dismiss. |
| global [Decimal](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_decimal.htm) [MaxRetryCount__c](#maxretrycount__c) | Maximum number of automatic retries for a failed outgoing call. |
| global [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) [MockingEnabled__c](#mockingenabled__c) | Picks this service for mocking, outgoing or incoming. |
| global [Decimal](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_decimal.htm) [Priority__c](#priority__c) | Chooses between active inbound services whose matching paths are the same length; outgoing calls do not read it. |
| global [Id](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_id.htm) [RequiredFeatureFlag__c](#requiredfeatureflag__c) | Optional. |
| global [FeatureFlag__mdt](../metadata/FeatureFlag__mdt.md) [RequiredFeatureFlag__r](#requiredfeatureflag__r) | Optional. |
| global [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) [ResolveIssues__c](#resolveissues__c) | When ticked, a later successful call closes the open API issues of the same request. |
| global [Decimal](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_decimal.htm) [RetryBackoffSeconds__c](#retrybackoffseconds__c) | The number of seconds to wait between retry attempts under the default linear backoff. |
| global [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) [RetryIssues__c](#retryissues__c) | Lets a person run a failed call of this service again from its API issue: the Retry action, Retry Selected on the API Issues list, and the Retry API Issues flow action. |

### ApiCredential__c

```apex
global Id ApiCredential__c
```

The API Credential record that holds the sign-in details the handler of this service uses with the endpoint it calls.

**Field Attributes:**

| Attribute | Value |
|-----------|-------|
| Data Type | ApiCredential__mdt |
| Required | false |
| Unique | false |

### ApiCredential__r

```apex
global ApiCredential__mdt ApiCredential__r
```

The API Credential record that holds the sign-in details the handler of this service uses with the endpoint it calls.

**Field Attributes:**

| Attribute | Value |
|-----------|-------|
| Data Type | ApiCredential__mdt |
| Required | false |
| Unique | false |

### ApiMocks__r

```apex
global List<ApiMock__mdt> ApiMocks__r
```

Reciprocal relationship for **`ApiMock__mdt.ApiSetting__c`** .

### BypassFeatureFlag__c

```apex
global Id BypassFeatureFlag__c
```

Optional. The service is SKIPPED when the Feature Flag is enabled.

**Field Attributes:**

| Attribute | Value |
|-----------|-------|
| Data Type | FeatureFlag__mdt |
| Required | false |
| Unique | false |

### BypassFeatureFlag__r

```apex
global FeatureFlag__mdt BypassFeatureFlag__r
```

Optional. The service is SKIPPED when the Feature Flag is enabled.

**Field Attributes:**

| Attribute | Value |
|-----------|-------|
| Data Type | FeatureFlag__mdt |
| Required | false |
| Unique | false |

### CircuitBreakerEnabled__c

```apex
global Boolean CircuitBreakerEnabled__c
```

Enable circuit breaker pattern to prevent cascading failures when the external service is down

**Field Attributes:**

| Attribute | Value |
|-----------|-------|
| Data Type | Checkbox |
| Default Value | false |

### CircuitBreakerFailureThreshold__c

```apex
global Decimal CircuitBreakerFailureThreshold__c
```

Number of consecutive failures before opening the circuit (default: 10 for high tolerance)

**Field Attributes:**

| Attribute | Value |
|-----------|-------|
| Data Type | Number(3,0) |
| Required | false |
| Unique | false |
| External ID | false |

### CircuitBreakerSuccessThreshold__c

```apex
global Decimal CircuitBreakerSuccessThreshold__c
```

Number of consecutive successes in half-open state to close the circuit (default: 2)

**Field Attributes:**

| Attribute | Value |
|-----------|-------|
| Data Type | Number(2,0) |
| Required | false |
| Unique | false |
| External ID | false |

### CircuitBreakerTimeout__c

```apex
global Decimal CircuitBreakerTimeout__c
```

Seconds to wait before attempting to close the circuit (default: 60)

**Field Attributes:**

| Attribute | Value |
|-----------|-------|
| Data Type | Number(5,0) |
| Required | false |
| Unique | false |
| External ID | false |

### ClassName__c

```apex
global String ClassName__c
```

The name of the Apex class that handles this service, such as API_Handler or MyNamespace.API_Handler. When an incoming request is routed by its path, a name without a namespace takes the namespace of this setting record.

**Field Attributes:**

| Attribute | Value |
|-----------|-------|
| Data Type | Text(100), case-insensitive |
| Required | false |
| Unique | true |
| External ID | false |

### Direction__c

```apex
global String Direction__c
```

Indicates whether this API setting applies to inbound requests or outbound calls.

**Field Attributes:**

| Attribute | Value |
|-----------|-------|
| Data Type | Picklist |
| Required | false |

**Picklist Values:**

| API Name | Label | Active |
|----------|-------|--------|
| `Outbound` | Outbound | Yes |
| `Inbound` | Inbound | No |

### EndpointPath__c

```apex
global String EndpointPath__c
```

The path of this service. Outgoing and incoming services both use it. Outbound: the path is added after the service's address, which is usually the Named Credential named on the API Credential, for example /api/v1/accounts. Inbound: an incoming request reaches this service when its path matches this one. The match ignores upper and lower case, and a * matches any characters. When the paths of several active inbound services match, the longest path wins, and Priority decides between paths of the same length.

**Field Attributes:**

| Attribute | Value |
|-----------|-------|
| Data Type | Text(255) |
| Required | false |
| Unique | false |
| External ID | false |

### IdempotencyEnabled__c

```apex
global Boolean IdempotencyEnabled__c
```

Idempotency means that processing the same request twice has the same effect as processing it once. Inbound: a request whose Idempotency-Key header the same user already sent to this service is not run again. It gets the stored response when the earlier call completed with the same body, and HTTP 409 when the body differs. A key another user sent is a separate request. A retry with the same key and body after a failure links to the failed call (Previous Attempt), and with Resolve Issues on, a success resolves the earlier failures' issues. Outbound: a key is built as a SHA-256 hash of the endpoint, the request parameters and the body, and sent as the Idempotency-Key header; a retry is safe only if the remote system honours that header, and two calls with identical endpoint, parameters and body share a key.

**Field Attributes:**

| Attribute | Value |
|-----------|-------|
| Data Type | Checkbox |
| Default Value | false |

### IsActive__c

```apex
global Boolean IsActive__c
```

Turns this service on or off, for outgoing and incoming services alike. When unticked, the service is off but its setting is kept. Outbound: the service sends no call. Inbound: the service does not run for an incoming request. For both kinds of service, the Retry actions do not run its failed calls again, and the API Test Harness does not list the service.

**Field Attributes:**

| Attribute | Value |
|-----------|-------|
| Data Type | Checkbox |
| Default Value | true |

### LogIssues__c

```apex
global Boolean LogIssues__c
```

When ticked, a failed call of this service leaves an API issue that a person can review, run again or dismiss. Outbound: a call your org sent that failed or was refused. Inbound: a request your org received that failed in the service's code, was refused by its checks, or whose changes could not be saved. The inbound issue links to its call, which keeps the request. A request refused because it reused an Idempotency-Key with another body writes no issue, and neither does a failed run of an issue's request again.

**Field Attributes:**

| Attribute | Value |
|-----------|-------|
| Data Type | Checkbox |
| Default Value | false |

### MaxRetryCount__c

```apex
global Decimal MaxRetryCount__c
```

Maximum number of automatic retries for a failed outgoing call. Set to 0 to disable retries. A Retry Backoff of 0 also disables them, except while the circuit breaker is open: then the retry waits for the breaker's cool-off.

**Field Attributes:**

| Attribute | Value |
|-----------|-------|
| Data Type | Number(2,0) |
| Required | false |
| Unique | false |
| External ID | false |

### MockingEnabled__c

```apex
global Boolean MockingEnabled__c
```

Picks this service for mocking, outgoing or incoming. It takes effect only for the users that the Mock Selected APIs feature flag is on for. For those users, the service answers from its API Mock records instead of calling the real system or running its own code. With the flag off, the box changes nothing. The Health Check lists every active service with this box ticked.

**Field Attributes:**

| Attribute | Value |
|-----------|-------|
| Data Type | Checkbox |
| Default Value | false |

### Priority__c

```apex
global Decimal Priority__c
```

Chooses between active inbound services whose matching paths are the same length; outgoing calls do not read it. When an incoming request matches the Endpoint Path of several active inbound services, the longest path wins. Between paths of the same length, the service with the lower number wins.

**Field Attributes:**

| Attribute | Value |
|-----------|-------|
| Data Type | Number(3,0) |
| Required | false |
| Unique | false |
| External ID | false |
| Default Value | 100 |

### RequiredFeatureFlag__c

```apex
global Id RequiredFeatureFlag__c
```

Optional. The service is aborted when the Feature Flag is not enabled.

**Field Attributes:**

| Attribute | Value |
|-----------|-------|
| Data Type | FeatureFlag__mdt |
| Required | false |
| Unique | false |

### RequiredFeatureFlag__r

```apex
global FeatureFlag__mdt RequiredFeatureFlag__r
```

Optional. The service is aborted when the Feature Flag is not enabled.

**Field Attributes:**

| Attribute | Value |
|-----------|-------|
| Data Type | FeatureFlag__mdt |
| Required | false |
| Unique | false |

### ResolveIssues__c

```apex
global Boolean ResolveIssues__c
```

When ticked, a later successful call closes the open API issues of the same request. Outbound: a successful call with the same triggering record, service and request parameters marks every open issue of that request Resolved. Inbound: this also needs Idempotency Enabled. A request answered with a status from 200 to 299 marks Resolved the open issues of the earlier failed requests that the same user sent to this service with the same Idempotency-Key, whatever their body. A request without a key resolves nothing.

**Field Attributes:**

| Attribute | Value |
|-----------|-------|
| Data Type | Checkbox |
| Default Value | false |

### RetryBackoffSeconds__c

```apex
global Decimal RetryBackoffSeconds__c
```

The number of seconds to wait between retry attempts under the default linear backoff. 0 means no automatic retry, except while the circuit breaker is open: then the retry waits for its cool-off. Works with Max Retry Count to control retry timing.

**Field Attributes:**

| Attribute | Value |
|-----------|-------|
| Data Type | Number(3,0) |
| Required | false |
| Unique | false |
| External ID | false |

### RetryIssues__c

```apex
global Boolean RetryIssues__c
```

Lets a person run a failed call of this service again from its API issue: the Retry action, Retry Selected on the API Issues list, and the Retry API Issues flow action. Outbound: the request is sent again. Inbound: the request is read from the call and run again in your org; turn this on only when the callers of the service do not send failed requests again themselves. Retry never runs a call marked Permanent Failure, nor an inbound request the call does not hold an exact copy of. This is not the automatic retry: that is governed by Max Retry Count and Retry Backoff.

**Field Attributes:**

| Attribute | Value |
|-----------|-------|
| Data Type | Checkbox |
| Default Value | false |

