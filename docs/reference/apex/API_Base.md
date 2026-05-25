---
title: "API_Base"
type: class
description: "Base class for all API web service calls (outbound and inbound). Provides common functionality for HTTP request handling, error management, and data persistence."
author: "Jason Van Beukering"
group: "Web Services"
date: "February 2026, May 2026"
since: "1.0"
category: apex
---

# API_Base

**Class** · Group: `Web Services`

```apex
global abstract inherited sharing class API_Base extends DML_Transaction
```

**Extends:** [DML_Transaction](DML_Transaction.md)

**Known Derived Types:** [API_CallCurrentOrg](API_CallCurrentOrg.md), [API_Inbound](API_Inbound.md), [API_Outbound](API_Outbound.md)

Base class for all API web service calls (outbound and inbound). Provides common functionality for HTTP request handling, error management, and data persistence.

**Since:** 1.0

**Example:**

```apex
public class API_MyService extends API_Outbound
{
    global override void configure()
    {
        super.configure();
        requestPayload = new DTO_Request();
    }
}
```

---

## Properties

| Property | Description |
|----------|-------------|
| global [ApiCall__c](../objects/ApiCall__c.md) [apiCall](#apicall) | The ApiCall__c object that initiated the service call. |
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [correlationId](#correlationid) | The unique correlation ID for this handler instance. |
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [errorText](#errortext) | Returns errors encountered during the request or the error payload if no error is logged. |
| global enum [HttpMethod](API_Base.HttpMethod.md) | HTTP method verbs for web service calls. |
| global [DTO_NameValues](DTO_NameValues.md) [inputs](#inputs) | DTO containing parameters passed to the API. |
| global [API_Base.ServiceCallResult](API_Base.ServiceCallResult.md) [result](#result) | Tracks the request, response, and status of a web service call. |
| global [ApiSetting__mdt](../metadata/ApiSetting__mdt.md) [setting](#setting) | API settings metadata for this service, lazy-loaded from ApiSetting__mdt. |
| global enum [WebserviceStatus](API_Base.WebserviceStatus.md) | Enum representing the status of a web service call. |

## Methods

| Method | Description |
|--------|-------------|
| global virtual void [configure](#configure)() | Initializes global variables and timers. |
| global virtual [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [getBody](#getbody)() | Returns the HTTP request body. |
| global abstract [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [getEncoding](#getencoding)() | Returns the HTTP character encoding. |
| global virtual [API_Base.HttpMethod](API_Base.HttpMethod.md) [getHttpMethod](#gethttpmethod)() | Returns the HTTP method for the service. |
| global virtual [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm) [getValidationErrors](#getvalidationerrors)() | Determines if the web service request should be aborted. |
| global virtual void [handleError](#handleerror)([Exception](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_classes_exception_methods.htm) exceptionThrown) | Handles errors encountered during the service call. |
| global virtual [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) [isDisabled](#isdisabled)() | Checks if the API is disabled for the current user. |
| global virtual void [onSuccess](#onsuccess)() | Registers database changes after a successful call. |

## Inner Classes

| Class | Description |
|-------|-------------|
| [ServiceCallResult](API_Base.ServiceCallResult.md) | Tracks the request, response, and status of a web service call. |

---

## Property Details

### apiCall

```apex
global ApiCall__c apiCall
```

**Type:** [ApiCall__c](../objects/ApiCall__c.md)

The ApiCall__c object that initiated the service call.

Since:


Example:

### correlationId

```apex
global String correlationId
```

**Type:** [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)

The unique correlation ID for this handler instance.

Since:


Example:

### errorText

```apex
global String errorText
```

**Type:** [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)

Returns errors encountered during the request or the error payload if no error is logged.

Since:


Example:

### inputs

```apex
global DTO_NameValues inputs
```

**Type:** [DTO_NameValues](DTO_NameValues.md)

DTO containing parameters passed to the API.

Since:


Example:

### result

```apex
global API_Base.ServiceCallResult result
```

**Type:** [API_Base.ServiceCallResult](API_Base.ServiceCallResult.md)

Tracks the request, response, and status of a web service call.

Since:


Example:

### setting

```apex
global ApiSetting__mdt setting
```

**Type:** [ApiSetting__mdt](../metadata/ApiSetting__mdt.md)

API settings metadata for this service, lazy-loaded from ApiSetting__mdt.

Since:


Example:

---

## Method Details

### configure

```apex
global virtual void configure()
```

Initializes global variables and timers. Override this method to configure
DTOs, mock types, timeouts, and other service-specific settings.

**Since:** 1.0

**Example:**

```apex
global override void configure()
{
    super.configure();
    requestPayload = new DTO_Request();
    responsePayload = new DTO_Response();
    defaultMockBody = '{"success": true}';
}
```

### getBody

```apex
global virtual String getBody()
```

Returns the HTTP request body.

**Returns:** [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) - String The request body, empty by default.

**Since:** 1.0

**Example:**

```apex
global override String getBody()
{
    return requestPayload.serialize();
}
```

### getEncoding

```apex
global abstract String getEncoding()
```

Returns the HTTP character encoding.

**Returns:** [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) - String The encoding scheme, must be implemented by subclasses.

**Since:** 1.0

**Example:**

```apex
global override String getEncoding()
{
    return 'application/xml';
}
```

### getHttpMethod

```apex
global virtual API_Base.HttpMethod getHttpMethod()
```

Returns the HTTP method for the service.

**Returns:** [API_Base.HttpMethod](API_Base.HttpMethod.md) - The HTTP method enum value, or null by default.

**Since:** 1.0

**Example:**

```apex
global override HttpMethod getHttpMethod()
{
    return HttpMethod.GET;
}
```

### getValidationErrors

```apex
global virtual List<String> getValidationErrors()
```

Determines if the web service request should be aborted. Returns a list of validation error messages.
Subscribers override this to add custom validation. Framework validation is handled internally
by performValidation() — no super call needed.

**Returns:** [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) - A list of error messages. Empty list means validation passed.

**Since:** 1.0

**Example:**

```apex
global override List<String> getValidationErrors()
{
    List<String> errors = new List<String>();
    if(String.isBlank(apiCall.TriggeringRecordId__c))
    {
        errors.add('Triggering record is required');
    }
    return errors;
}
```

### handleError

```apex
global virtual void handleError(Exception exceptionThrown)
```

Handles errors encountered during the service call.

**Parameters:**

- `exceptionThrown` ([Exception](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_classes_exception_methods.htm)) - The exception to handle.

**Since:** 1.0

**Example:**

```apex
global override void handleError(Exception exceptionThrown)
{
    super.handleError(exceptionThrown);
    // custom error handling
}
```

### isDisabled

```apex
global virtual Boolean isDisabled()
```

Checks if the API is disabled for the current user.
Override to add custom disable logic.

**Returns:** [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) - Boolean True if the API is disabled, otherwise false.

**Since:** 1.0

**Example:**

```apex
global override Boolean isDisabled()
{
    return super.isDisabled() || customDisableCheck();
}
```

### onSuccess

```apex
global virtual void onSuccess()
```

Registers database changes after a successful call.

**Since:** 1.0

**Example:**

```apex
global override void onSuccess()
{
    super.onSuccess();
    doUpdate(updatedRecord);
}
```

