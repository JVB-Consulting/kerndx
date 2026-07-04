---
title: "API_OutboundTestHelper"
type: class
description: "Class has base methods that can be used to test an outbound service."
author: "Jason Van Beukering"
group: "Testing"
date: "February 2026, May 2026"
since: "1.0"
category: apex
---

# API_OutboundTestHelper

**Class** · Group: `Testing`

```apex
global inherited sharing class API_OutboundTestHelper
```

Class has base methods that can be used to test an outbound service.

**Since:** 1.0

**Example:**

```apex
API_OutboundTestHelper.assertCallSuccessful(SERVICE_NAME, record.Id, parameters);
```

---

## Methods

| Method | Description |
|--------|-------------|
| global static void [assertCallAborted](#assertcallaborted)([ApiCall__c](../objects/ApiCall__c.md) apiCall, [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) exceptionMessage) | Tests that an API call aborts with a specific error message. |
| global static [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm) [assertCallAborted](#assertcallaborted)([List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[ApiCall__c](../objects/ApiCall__c.md)> apiCalls) | Tests that a web service call is aborted as expected. |
| global static void [assertCallAborted](#assertcallaborted)([List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[ApiCall__c](../objects/ApiCall__c.md)> apiCalls, [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) exceptionMessage) | Tests that an API call aborts with a specific error message. |
| global static [API_Base](API_Base.md) [assertCallAborted](#assertcallaborted)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) serviceName, [Id](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_id.htm) recordId) | Tests that a web service call is aborted as expected. |
| global static [API_Base](API_Base.md) [assertCallAborted](#assertcallaborted)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) serviceName, [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm), [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)> parameters) | Tests that an API call aborts as expected with parameters. |
| global static [API_Base](API_Base.md) [assertCallAborted](#assertcallaborted)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) serviceName, [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)> parameterNames) | Tests an aborted API call with parameter names. |
| global static [API_Base](API_Base.md) [assertCallAborted](#assertcallaborted)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) serviceName, [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) parameterName) | Tests an aborted API call with a single parameter name. |
| global static [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm) [assertCallFailed](#assertcallfailed)([List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[ApiCall__c](../objects/ApiCall__c.md)> apiCalls) | Tests that a web service call fails as expected. |
| global static [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm) [assertCallSuccessful](#assertcallsuccessful)([List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[ApiCall__c](../objects/ApiCall__c.md)> apiCalls) | Tests that a web service call is executed successfully for each of the provided API calls. |
| global static [API_Base](API_Base.md) [assertCallSuccessful](#assertcallsuccessful)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) serviceName, [Id](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_id.htm) recordId) | Tests the successful execution of a web service call. |
| global static [API_Base](API_Base.md) [assertCallSuccessful](#assertcallsuccessful)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) serviceName, [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm), [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)> parameters) | Tests the successful execution of a web service call, passing a map of parameters. |
| global static [API_Base](API_Base.md) [assertCallSuccessful](#assertcallsuccessful)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) serviceName, [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)> parameterNames) | Tests the successful execution of a web service call, passing a set of parameters. |
| global static [API_Base](API_Base.md) [assertCallSuccessful](#assertcallsuccessful)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) serviceName, [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) parameterName) | Tests the successful execution of a web service call, passing a single parameter. |
| global static [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm) [assertParseFailed](#assertparsefailed)([List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[ApiCall__c](../objects/ApiCall__c.md)> apiCalls) | Tests that a web service call fails to parse the response. |

---

## Method Details

### assertCallAborted

```apex
global static void assertCallAborted(ApiCall__c apiCall, String exceptionMessage)
```

Tests that an API call aborts with a specific error message.

**Parameters:**

- `apiCall` ([ApiCall__c](../objects/ApiCall__c.md)) - The API call containing the service and parameters to call
- `exceptionMessage` ([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)) - The error message that must exist in the response

**Since:** 1.0

**Example:**

```apex
ApiCall__c apiCall = TST_Factory.newOutboundApiCall(SERVICE_NAME, record.Id);
API_OutboundTestHelper.assertCallAborted(apiCall, 'Expected error message');
```

### assertCallAborted

```apex
global static List<API_Base> assertCallAborted(List<ApiCall__c> apiCalls)
```

Tests that a web service call is aborted as expected.

**Parameters:**

- `apiCalls` ([List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)) - The API calls containing the services and parameters to call

**Returns:** [API_Base](API_Base.md) - A list of handlers that processed the requests.

**Since:** 1.0

**Example:**

```apex
List<ApiCall__c> apiCalls = TST_Factory.newOutboundApiCall(SERVICE_NAME, record.Id);
List<API_Base> handlers = API_OutboundTestHelper.assertCallAborted(apiCalls);
```

### assertCallAborted

```apex
global static void assertCallAborted(List<ApiCall__c> apiCalls, String exceptionMessage)
```

Tests that an API call aborts with a specific error message.

**Parameters:**

- `apiCalls` ([List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)) - The API calls containing the services and parameters to call
- `exceptionMessage` ([ApiCall__c](../objects/ApiCall__c.md)) - The message string which is checked in the abort message

**Since:** 1.0

**Example:**

```apex
List<ApiCall__c> apiCalls = TST_Factory.newOutboundApiCall(SERVICE_NAME, record.Id);
API_OutboundTestHelper.assertCallAborted(apiCalls, 'Expected error message');
```

### assertCallAborted

```apex
global static API_Base assertCallAborted(String serviceName, Id recordId)
```

Tests that a web service call is aborted as expected.

**Parameters:**

- `serviceName` ([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)) - The class name of the API handler
- `recordId` ([Id](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_id.htm)) - The object that triggered the callout (optional)

**Returns:** [API_Base](API_Base.md) - The handler executing the web service call.

**Since:** 1.0

**Example:**

```apex
API_Base handler = API_OutboundTestHelper.assertCallAborted(SERVICE_NAME, record.Id);
```

### assertCallAborted

```apex
global static API_Base assertCallAborted(String serviceName, Id recordId, Map<String, String> parameters)
```

Tests that an API call aborts as expected with parameters.

**Parameters:**

- `serviceName` ([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)) - The name of the web service handler
- `recordId` ([Id](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_id.htm)) - id of the triggering object (optional)
- `parameters` ([Map](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_map.htm)) - Map of parameters to pass to the API call

**Returns:** [API_Base](API_Base.md) - The handler executing the API call

**Since:** 1.0

**Example:**

```apex
Map<String, String> parameters = new Map<String, String>{API_MyService.PARAM_KEY => 'value'};
API_Base handler = API_OutboundTestHelper.assertCallAborted(SERVICE_NAME, record.Id, parameters);
```

### assertCallAborted

```apex
global static API_Base assertCallAborted(String serviceName, Id recordId, Set<String> parameterNames)
```

Tests an aborted API call with parameter names.

**Parameters:**

- `serviceName` ([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)) - The name of the web service handler
- `recordId` ([Id](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_id.htm)) - id of the triggering object (optional)
- `parameterNames` ([Set](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_set.htm)) - Names of parameters to pass to the service handler

**Returns:** [API_Base](API_Base.md) - The handler executing the API call

**Since:** 1.0

**Example:**

```apex
Set<String> parameterNames = new Set<String>{'param1', 'param2'};
API_Base handler = API_OutboundTestHelper.assertCallAborted(SERVICE_NAME, record.Id, parameterNames);
```

### assertCallAborted

```apex
global static API_Base assertCallAborted(String serviceName, Id recordId, String parameterName)
```

Tests an aborted API call with a single parameter name.

**Parameters:**

- `serviceName` ([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)) - The name of the web service handler
- `recordId` ([Id](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_id.htm)) - id of the triggering object (optional)
- `parameterName` ([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)) - Name of a parameter to pass to the service handler

**Returns:** [API_Base](API_Base.md) - The handler executing the API call

**Since:** 1.0

**Example:**

```apex
API_Base handler = API_OutboundTestHelper.assertCallAborted(SERVICE_NAME, record.Id, API_MyService.PARAM_KEY);
```

### assertCallFailed

```apex
global static List<API_Base> assertCallFailed(List<ApiCall__c> apiCalls)
```

Tests that a web service call fails as expected.

**Parameters:**

- `apiCalls` ([List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)) - The API calls containing the services and parameters to call

**Returns:** [API_Base](API_Base.md) - A list of handlers that processed the request

**Since:** 1.0

**Example:**

```apex
List<ApiCall__c> apiCalls = TST_Factory.newOutboundApiCall(SERVICE_NAME, record.Id);
List<API_Base> handlers = API_OutboundTestHelper.assertCallFailed(apiCalls);
```

### assertCallSuccessful

```apex
global static List<API_Base> assertCallSuccessful(List<ApiCall__c> apiCalls)
```

Tests that a web service call is executed successfully for each of the provided API calls.

**Parameters:**

- `apiCalls` ([List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)) - The API calls containing the services and parameters to call

**Returns:** [API_Base](API_Base.md) - A list of handlers that processed the request

**Since:** 1.0

**Example:**

```apex
List<ApiCall__c> apiCalls = TST_Factory.newOutboundApiCall(SERVICE_NAME, record.Id);
List<API_Base> handlers = API_OutboundTestHelper.assertCallSuccessful(apiCalls);
```

### assertCallSuccessful

```apex
global static API_Base assertCallSuccessful(String serviceName, Id recordId)
```

Tests the successful execution of a web service call.

**Parameters:**

- `serviceName` ([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)) - The name of the web service handler
- `recordId` ([Id](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_id.htm)) - Id of the triggering object (optional)

**Returns:** [API_Base](API_Base.md) - The handler executing the API call

**Since:** 1.0

**Example:**

```apex
API_Base handler = API_OutboundTestHelper.assertCallSuccessful(SERVICE_NAME, record.Id);
```

### assertCallSuccessful

```apex
global static API_Base assertCallSuccessful(String serviceName, Id recordId, Map<String, String> parameters)
```

Tests the successful execution of a web service call, passing a map of parameters.

**Parameters:**

- `serviceName` ([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)) - The name of the web service handler
- `recordId` ([Id](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_id.htm)) - id of the triggering object (optional)
- `parameters` ([Map](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_map.htm)) - Map of parameters to pass to the API call

**Returns:** [API_Base](API_Base.md) - The handler executing the API call

**Since:** 1.0

**Example:**

```apex
Map<String, String> parameters = new Map<String, String>{API_MyService.PARAM_KEY => 'value'};
API_Base handler = API_OutboundTestHelper.assertCallSuccessful(SERVICE_NAME, record.Id, parameters);
```

### assertCallSuccessful

```apex
global static API_Base assertCallSuccessful(String serviceName, Id recordId, Set<String> parameterNames)
```

Tests the successful execution of a web service call, passing a set of parameters.

**Parameters:**

- `serviceName` ([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)) - The name of the web service handler
- `recordId` ([Id](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_id.htm)) - id of the triggering object (optional)
- `parameterNames` ([Set](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_set.htm)) - Names of parameters to pass to the service handler

**Returns:** [API_Base](API_Base.md) - The handler executing the API call

**Since:** 1.0

**Example:**

```apex
Set<String> parameterNames = new Set<String>{'param1', 'param2'};
API_Base handler = API_OutboundTestHelper.assertCallSuccessful(SERVICE_NAME, record.Id, parameterNames);
```

### assertCallSuccessful

```apex
global static API_Base assertCallSuccessful(String serviceName, Id recordId, String parameterName)
```

Tests the successful execution of a web service call, passing a single parameter.

**Parameters:**

- `serviceName` ([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)) - The name of the web service handler
- `recordId` ([Id](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_id.htm)) - id of the triggering object (optional)
- `parameterName` ([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)) - Name of a parameter to pass to the service handler

**Returns:** [API_Base](API_Base.md) - The handler executing the API call

**Since:** 1.0

**Example:**

```apex
API_Base handler = API_OutboundTestHelper.assertCallSuccessful(SERVICE_NAME, record.Id, API_MyService.PARAM_KEY);
```

### assertParseFailed

```apex
global static List<API_Base> assertParseFailed(List<ApiCall__c> apiCalls)
```

Tests that a web service call fails to parse the response.

**Parameters:**

- `apiCalls` ([List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)) - The API calls containing the services and parameters to call

**Returns:** [API_Base](API_Base.md) - A list of handlers that processed the request

**Since:** 1.0

**Example:**

```apex
List<ApiCall__c> apiCalls = TST_Factory.newOutboundApiCall(SERVICE_NAME, record.Id);
List<API_Base> handlers = API_OutboundTestHelper.assertParseFailed(apiCalls);
```

