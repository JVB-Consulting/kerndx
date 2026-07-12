---
title: "SEL_ApiCall"
type: class
pageClass: reference
description: "Selector for the ApiCall__c object. Provides query methods for service call management, status tracking, and assertion utilities for test verification."
author: "Jason Van Beukering"
group: "Web Services"
date: "February 2026, June 2026"
since: "1.0"
category: apex
---

# SEL_ApiCall

**Class** · Group: `Web Services`

<div class="apex-member apex-class">

```apex
global inherited sharing class SEL_ApiCall extends SEL_Base
```

**Extends:** [SEL_Base](SEL_Base.md)

Selector for the ApiCall__c object. Provides query methods for service call management, status tracking, and assertion utilities for test verification.

**Example**

```apex
List<ApiCall__c> calls = new SEL_ApiCall().findByServiceName('API_SendEmail');
ApiCall__c call = (ApiCall__c)new SEL_ApiCall().findById(callId);
ApiCall__c existing = new SEL_ApiCall().findByIdempotencyKey('550e8400-e29b-41d4-a716-446655440000');
```

**See Also:** [SEL_Base](SEL_Base.md)

</div>

---

## Methods

| Method | Description |
|--------|-------------|
| global static [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[ApiCall__c](../objects/ApiCall__c.md)> [assertServiceAborted](#assertserviceaborted)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) serviceName) | Verifies that API calls for a specific service name have an aborted status. |
| global static [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[ApiCall__c](../objects/ApiCall__c.md)> [assertServiceAborted](#assertserviceaborted)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) serviceName, [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) errorPhrase) | Verifies that API calls for a specific service name have an aborted status and optionally checks for a specific error phrase. |
| global static [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[ApiCall__c](../objects/ApiCall__c.md)> [assertServiceCompleted](#assertservicecompleted)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) serviceName) | Verifies that API calls for a specific service name have a completed status. |
| global static [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[ApiCall__c](../objects/ApiCall__c.md)> [assertServiceFailed](#assertservicefailed)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) serviceName) | Verifies that API calls for a specific service name have a failed status. |
| global static [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[ApiCall__c](../objects/ApiCall__c.md)> [assertServiceFailed](#assertservicefailed)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) serviceName, [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) errorPhrase) | Verifies that API calls for a specific service name have a failed status and optionally checks for a specific error phrase. |
| global [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[ApiCall__c](../objects/ApiCall__c.md)> [findByServiceName](#findbyservicename)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) serviceName) | Retrieves ApiCall__c records by a specific service name. |
| global override [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm)> [getFields](#getfields)() | Returns the default fields for ApiCall__c queries. |

### assertServiceAborted

<div class="apex-member">

```apex
global static List<ApiCall__c> assertServiceAborted(String serviceName)
```

Verifies that API calls for a specific service name have an aborted status.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `serviceName` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The name of the API class to check. |

**Returns** [ApiCall__c](../objects/ApiCall__c.md) — List of ApiCall__c records with "Aborted" status for the specified service.

**Example**

```apex
List<ApiCall__c> aborted = SEL_ApiCall.assertServiceAborted('MyExternalService');
```

</div>

<div class="apex-member">

```apex
global static List<ApiCall__c> assertServiceAborted(String serviceName, String errorPhrase)
```

Verifies that API calls for a specific service name have an aborted status
and optionally checks for a specific error phrase.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `serviceName` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The name of the API class to check. |
| `errorPhrase` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | Optional phrase to look for in the Errors__c field (null to ignore). |

**Returns** [ApiCall__c](../objects/ApiCall__c.md) — List of matching aborted ApiCall__c records.

**Example**

```apex
List<ApiCall__c> aborted = SEL_ApiCall.assertServiceAborted('MyExternalService', 'Connection timeout');
```

</div>

### assertServiceCompleted

<div class="apex-member">

```apex
global static List<ApiCall__c> assertServiceCompleted(String serviceName)
```

Verifies that API calls for a specific service name have a completed status.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `serviceName` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The name of the API class to check. |

**Returns** [ApiCall__c](../objects/ApiCall__c.md) — List of ApiCall__c records with "Completed" status for the specified service.

**Example**

```apex
List<ApiCall__c> result = SEL_ApiCall.assertServiceCompleted('SEL_ApiCall');
```

</div>

### assertServiceFailed

<div class="apex-member">

```apex
global static List<ApiCall__c> assertServiceFailed(String serviceName)
```

Verifies that API calls for a specific service name have a failed status.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `serviceName` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The name of the API class to check. |

**Returns** [ApiCall__c](../objects/ApiCall__c.md) — List of ApiCall__c records with "Failed" status for the specified service.

**Example**

```apex
List<ApiCall__c> result = SEL_ApiCall.assertServiceFailed('SEL_ApiCall');
```

</div>

<div class="apex-member">

```apex
global static List<ApiCall__c> assertServiceFailed(String serviceName, String errorPhrase)
```

Verifies that API calls for a specific service name have a failed status
and optionally checks for a specific error phrase.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `serviceName` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The name of the API class to check. |
| `errorPhrase` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | Optional phrase to look for in the Errors__c field (null to ignore). |

**Returns** [ApiCall__c](../objects/ApiCall__c.md) — List of matching failed ApiCall__c records.

**Example**

```apex
List<ApiCall__c> result = SEL_ApiCall.assertServiceFailed('SEL_ApiCall', 'value');
```

</div>

### findByServiceName

<div class="apex-member">

```apex
global List<ApiCall__c> findByServiceName(String serviceName)
```

Retrieves ApiCall__c records by a specific service name.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `serviceName` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The name of the service to filter on. |

**Returns** [ApiCall__c](../objects/ApiCall__c.md) — List of ApiCall__c records with the specified Service__c value.

**Example**

```apex
List<ApiCall__c> apiCalls = new SEL_ApiCall().findByServiceName('MyExternalService');
```

</div>

### getFields

<div class="apex-member">

```apex
global override List<SObjectField> getFields()
```

Returns the default fields for ApiCall__c queries.

**Returns** [SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm) — List of SObjectField tokens to include in queries.

**Example**

```apex
List<SObjectField> result = instance.getFields();
```

</div>

## Constructors

| Constructor | Description |
|-------------|-------------|
| global [SEL_ApiCall](#constructors)() | Constructs a new SEL_ApiCall selector instance. |

### SEL_ApiCall()

<div class="apex-member">

```apex
global SEL_ApiCall()
```

Constructs a new SEL_ApiCall selector instance.

**Example**

```apex
SEL_ApiCall instance = new SEL_ApiCall();
```

</div>

