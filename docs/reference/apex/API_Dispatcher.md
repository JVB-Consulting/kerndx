---
title: "API_Dispatcher"
type: class
description: "Factory class for orchestrating the execution of web service handlers. Manages the lifecycle of API calls, including handler initiation, error handling, and change commitment. Supports both single and"
author: "Jason Van Beukering"
group: "Web Services"
date: "February 2026, May 2026"
since: "1.0"
category: apex
---

# API_Dispatcher

**Class** · Group: `Web Services`

```apex
global inherited sharing class API_Dispatcher
```

Factory class for orchestrating the execution of web service handlers. Manages the lifecycle of API calls, including handler initiation, error handling, and change commitment. Supports both single and batch processing of web service requests.

**Since:** 1.0

**Example:**

```apex
// Process an inbound REST service
API_Dispatcher.processInboundService(API_UpdateInvoice.class.getName());
// Execute an outbound API call
ApiCall__c apiCall = TST_Factory.newOutboundApiCall('API_SendEmail', recordId, parameters);
API_Base handler = API_Dispatcher.execute(apiCall);
```

---

## Methods

| Method | Description |
|--------|-------------|
| global static [API_Base](API_Base.md) [execute](#execute)([ApiCall__c](../objects/ApiCall__c.md) apiCall) | Executes a single API callout for the provided API call record. |
| global static [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[API_Base](API_Base.md)> [execute](#execute)([List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[ApiCall__c](../objects/ApiCall__c.md)> apiCalls) | Processes a list of API callout requests by executing multiple web service handlers. |
| global static [API_Base](API_Base.md) [processInboundService](#processinboundservice)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) serviceName) | Processes a single inbound web service request by executing the specified handler. |

---

## Method Details

### execute

```apex
global static API_Base execute(ApiCall__c apiCall)
```

Executes a single API callout for the provided API call record.

**Parameters:**

- `apiCall` ([ApiCall__c](../objects/ApiCall__c.md)) - A ApiCall__c record containing details of the API call to execute.

**Returns:** [API_Base](API_Base.md) - The `API_Base` handler that processed the request, or `null` if no handler was executed.

**Since:** 1.0

**Example:**

```apex
ApiCall__c apiCall = TST_Factory.newInboundApiCall('MyServiceHandler');
API_Base handler = API_Dispatcher.execute(apiCall);
```

```apex
global static List<API_Base> execute(List<ApiCall__c> apiCalls)
```

Processes a list of API callout requests by executing multiple web service handlers.
Manages batch processing, commits successful transactions, and logs failures for retries.

**Parameters:**

- `apiCalls` ([List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)) - A list of ApiCall__c records representing API calls to process.

**Returns:** [API_Base](API_Base.md) - A list of `API_Base` handlers that successfully processed the requests.

**Since:** 1.0

**Example:**

```apex
List<ApiCall__c> apiCalls = [SELECT Id, Service__c FROM ApiCall__c WHERE Status__c = 'Pending'];
List<API_Base> handlers = API_Dispatcher.execute(apiCalls);
```

### processInboundService

```apex
global static API_Base processInboundService(String serviceName)
```

Processes a single inbound web service request by executing the specified handler.

**Parameters:**

- `serviceName` ([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)) - The name of the web service handler class to execute.

**Returns:** [API_Base](API_Base.md) - The `API_Base` handler that processed the request, or `null` if no handler was executed.

**Since:** 1.0

**Example:**

```apex
API_Base handler = API_Dispatcher.processInboundService('MyServiceHandler');
```

