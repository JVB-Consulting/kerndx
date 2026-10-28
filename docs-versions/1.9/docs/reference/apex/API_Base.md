---
title: "API_Base"
type: class
pageClass: reference
description: "Base class for all API web service calls (outbound and inbound). Provides common functionality for HTTP request handling, error management, and data persistence."
author: "Jason Van Beukering"
group: "Web Services"
date: "February 2026, October 2026"
since: "1.0"
category: apex
---

# API_Base

**Class** · Group: `Web Services`

<div class="apex-member apex-class">

```apex
global abstract inherited sharing class API_Base extends DML_Transaction
```

**Extends:** [DML_Transaction](DML_Transaction.md)

**Known Derived Types:** [API_CallCurrentOrg](API_CallCurrentOrg.md), [API_Inbound](API_Inbound.md), [API_Outbound](API_Outbound.md)

Base class for all API web service calls (outbound and inbound). Provides common functionality for HTTP request handling, error management, and data persistence.

**Example**

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

</div>

---

## Methods

| Method | Description |
|--------|-------------|
| global virtual void [configure](#configure)() | Initializes global variables and timers. |
| global virtual [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [getBody](#getbody)() | Returns the HTTP request body. |
| global abstract [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [getEncoding](#getencoding)() | Returns the HTTP character encoding. |
| global virtual [API_Base.HttpMethod](API_Base.HttpMethod.md) [getHttpMethod](#gethttpmethod)() | Returns the HTTP method for the service. |
| global virtual [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)> [getValidationErrors](#getvalidationerrors)() | Determines if the web service request should be aborted. |
| global virtual void [handleError](#handleerror)([Exception](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_classes_exception_methods.htm) exceptionThrown) | Handles errors encountered during the service call. |
| global virtual [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) [isDisabled](#isdisabled)() | Checks if the API is disabled for the current user. |
| global override virtual void [onDMLFinished](#ondmlfinished)() | Runs after the commit has written its records to the database, and before onCommitWorkFinishing and onCommitWorkFinished. |
| global virtual void [onSuccess](#onsuccess)() | Registers database changes after a successful call. |

### configure

<div class="apex-member">

```apex
global virtual void configure()
```

Initializes global variables and timers. Override this method to configure
DTOs, mock types, timeouts, and other service-specific settings.

**Example**

```apex
global override void configure()
{
    super.configure();
    requestPayload = new DTO_Request();
    responsePayload = new DTO_Response();
    defaultMockBody = '{"success": true}';
}
```

</div>

### getBody

<div class="apex-member">

```apex
global virtual String getBody()
```

Returns the HTTP request body.

**Returns** [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) — String The request body, empty by default.

**Example**

```apex
global override String getBody()
{
    return requestPayload.serialize();
}
```

</div>

### getEncoding

<div class="apex-member">

```apex
global abstract String getEncoding()
```

Returns the HTTP character encoding.

**Returns** [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) — String The encoding scheme, must be implemented by subclasses.

**Example**

```apex
global override String getEncoding()
{
    return 'application/xml';
}
```

</div>

### getHttpMethod

<div class="apex-member">

```apex
global virtual API_Base.HttpMethod getHttpMethod()
```

Returns the HTTP method for the service.

**Returns** [API_Base.HttpMethod](API_Base.HttpMethod.md) — The HTTP method enum value, or null by default.

**Example**

```apex
global override HttpMethod getHttpMethod()
{
    return HttpMethod.GET;
}
```

</div>

### getValidationErrors

<div class="apex-member">

```apex
global virtual List<String> getValidationErrors()
```

Determines if the web service request should be aborted. Returns a list of validation error messages.
Subscribers override this to add custom validation. Framework validation is handled internally
by performValidation() — no super call needed.

**Returns** [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) — A list of error messages. Empty list means validation passed.

**Example**

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

</div>

### handleError

<div class="apex-member">

```apex
global virtual void handleError(Exception exceptionThrown)
```

Handles errors encountered during the service call.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `exceptionThrown` | [Exception](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_classes_exception_methods.htm) | The exception to handle. |

**Example**

```apex
global override void handleError(Exception exceptionThrown)
{
    super.handleError(exceptionThrown);
    // custom error handling
}
```

</div>

### isDisabled

<div class="apex-member">

```apex
global virtual Boolean isDisabled()
```

Checks if the API is disabled for the current user.
Override to add custom disable logic.

**Returns** [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) — Boolean True if the API is disabled, otherwise false.

**Example**

```apex
global override Boolean isDisabled()
{
    return super.isDisabled() || customDisableCheck();
}
```

</div>

### onDMLFinished

<div class="apex-member">

```apex
global override virtual void onDMLFinished()
```

Runs after the commit has written its records to the database, and before onCommitWorkFinishing and
onCommitWorkFinished. It keeps a copy of the call record's field values as they were written. The call record is
saved once more after the commit, to write the timings and the outcome. Because of the copy, that second save sends
only the fields that changed after the commit, such as the response the inbound commit writes in
onCommitWorkFinishing. When an attempt fails after this point, the copy is dropped again. Your handler class may
override this method. Your override must call super.onDMLFinished() first. If it does not, the second save sends
the whole call record again.

**Example**

```apex
global override void onDMLFinished()
{
    super.onDMLFinished();
    // your own work, after the commit has written its records
}
```

</div>

### onSuccess

<div class="apex-member">

```apex
global virtual void onSuccess()
```

Registers database changes after a successful call.

**Example**

```apex
global override void onSuccess()
{
    super.onSuccess();
    doUpdate(updatedRecord);
}
```

</div>

## Properties

| Property | Description |
|----------|-------------|
| global [ApiCall__c](../objects/ApiCall__c.md) [apiCall](#apicall) | The ApiCall__c object that initiated the service call. |
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [correlationId](#correlationid) | The unique correlation ID for this handler instance. |
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [errorText](#errortext) | Returns errors encountered during the request or the error payload if no error is logged. |
| global [DTO_NameValues](DTO_NameValues.md) [inputs](#inputs) | DTO containing parameters passed to the API. |
| global [API_Base.ServiceCallResult](API_Base.ServiceCallResult.md) [result](#result) | Tracks the request, response, and status of a web service call. |
| global [ApiSetting__mdt](../metadata/ApiSetting__mdt.md) [setting](#setting) | API settings metadata for this service, lazy-loaded from ApiSetting__mdt. |

### apiCall

```apex
global ApiCall__c apiCall
```

**Type:** [ApiCall__c](../objects/ApiCall__c.md)

The ApiCall__c object that initiated the service call.

Its payload fields (the request, the response, the address and the request parameters) are not always masked,
even after the call was saved. A payload that fits its field is masked when the call is saved to the database,
but this record still holds the raw text the call sent or received: the save does not copy the masked text back
into it. A payload field holds masked text only when the payload is longer than the field (the masked text is then
cut to fit), or, in some cases, when the payload was masked again to make its file. So code that reads this record
after a save must never pass a payload field on as if it were masked. To get the masked text, read the saved call
back from the database by its Id.

### correlationId

```apex
global String correlationId
```

**Type:** [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)

The unique correlation ID for this handler instance.

### errorText

```apex
global String errorText
```

**Type:** [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)

Returns errors encountered during the request or the error payload if no error is logged.

### inputs

```apex
global DTO_NameValues inputs
```

**Type:** [DTO_NameValues](DTO_NameValues.md)

DTO containing parameters passed to the API.

### result

```apex
global API_Base.ServiceCallResult result
```

**Type:** [API_Base.ServiceCallResult](API_Base.ServiceCallResult.md)

Tracks the request, response, and status of a web service call.

### setting

```apex
global ApiSetting__mdt setting
```

**Type:** [ApiSetting__mdt](../metadata/ApiSetting__mdt.md)

API settings metadata for this service, lazy-loaded from ApiSetting__mdt.

## Inner Classes

| Class | Description |
|-------|-------------|
| [HttpMethod](API_Base.HttpMethod.md) | HTTP method verbs for web service calls. |
| [ServiceCallResult](API_Base.ServiceCallResult.md) | Tracks the request, response, and status of a web service call. |
| [WebserviceStatus](API_Base.WebserviceStatus.md) | Enum representing the status of a web service call. |

---

