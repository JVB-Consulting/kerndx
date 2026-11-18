---
title: "SEL_ApiCall"
type: class
pageClass: reference
description: "Selector for the ApiCall__c object. Provides query methods for service call management, status tracking, and assertion utilities for test verification."
author: "Jason Van Beukering"
group: "Web Services"
date: "February 2026, November 2026"
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

**See Also:** [SEL_Base](SEL_Base.md), [SEL_ApiIssue](SEL_ApiIssue.md)

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
| global [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[ApiCall__c](../objects/ApiCall__c.md)> [findByTriggeringRecordIds](#findbytriggeringrecordids)([Set](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_set.htm)<[Id](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_id.htm)> recordIds, [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) rowLimit) | Finds the calls made for the given records, newest first, and returns at most rowLimit of them. |
| global [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[ApiCall__c](../objects/ApiCall__c.md)> [findByTriggeringRecordValues](#findbytriggeringrecordvalues)([Set](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_set.htm)<[String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)> values, [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) rowLimit) | Finds the calls with one of the given values in Triggering Record Index (TriggeringRecordIndex__c), newest first, and returns at most rowLimit of them. |
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

### findByTriggeringRecordIds

<div class="apex-member">

```apex
global List<ApiCall__c> findByTriggeringRecordIds(Set<Id> recordIds, Integer rowLimit)
```

Finds the calls made for the given records, newest first, and returns at most rowLimit of them. Calls
saved at the same moment are ordered by their own Id, newest first, so the order is the same every time.

A call is found by its Triggering Record Index field (TriggeringRecordIndex__c), which holds the record Id exactly
as it was written on the call. This method finds values stored in the full form of 18 characters, which is the form
the framework writes. It does not find a value stored in the short form of 15 characters. Code that sets the
Triggering Record Id field (TriggeringRecordId__c) itself should write the full form, for example
String.valueOf(recordId).

Each call holds only these fields: Id, ServiceName__c, Status__c, CreatedDate and TriggeringRecordIndex__c. To get
the request or the response of a call, read that call by its Id.

Triggering Record Index is filled each time a call is saved. A call saved before the field existed has it blank
until the update script in the release notes is run, and this method does not find it.

The read checks the running user's access. The user needs read access to the API Call object and to each field
above, and gets only the calls that record sharing lets them see. A user without that object or field access gets
an error (a QueryException) instead of a result.

In a test, the mocked calls are filtered the way the query filters saved ones: only those whose Triggering
Record Index holds one of the values come back. A mock is never saved, so Triggering Record Index is not filled
for it: set it on the mock yourself, because a mock that sets only Triggering Record Id is not found. The match in
a test is exact, so a value in another case is not found. An answer scripted
with TST_Mock.registerNext is filtered the same way, so give its mocks the values this method searches for.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `recordIds` | [Set](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_set.htm) | The Ids of the records the calls were made for. A null Id in the set is ignored. The set you pass is not changed. |
| `rowLimit` | [Id](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_id.htm) | The most calls to return: 1 or more. |

**Returns** [ApiCall__c](../objects/ApiCall__c.md) — The calls found, newest first. An empty list when the set holds no Id; then no query is run.

**Throws**

| Exception | Description |
|-----------|-------------|
| [IllegalArgumentException](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_classes_exception_methods.htm) | When recordIds is null, or rowLimit is null or less than 1. |

**Example**

```apex
List<ApiCall__c> calls = new SEL_ApiCall().findByTriggeringRecordIds(new Set<Id> {accountId}, 10);
```

</div>

### findByTriggeringRecordValues

<div class="apex-member">

```apex
global List<ApiCall__c> findByTriggeringRecordValues(Set<String> values, Integer rowLimit)
```

Finds the calls with one of the given values in Triggering Record Index (TriggeringRecordIndex__c),
newest first, and returns at most rowLimit of them. Calls saved at the same moment are ordered by their own Id,
newest first, so the order is the same every time. Use it when the calls were made for something that is not a
record in this org, such as an order number from another system; for record Ids, findByTriggeringRecordIds is
simpler.

Such a value can come from an inbound call, from a call your own code saves, or from an outbound call whose class
sets requiresTriggeringRecord to false. The call keeps the whole value, up to 80 characters.

Triggering Record Index holds the Triggering Record Id field (TriggeringRecordId__c) exactly as it was written on
the call. Each value is matched as you write it, but the match ignores upper and lower case: 'ORD-1' also finds a
call whose Triggering Record Index is 'ord-1'. Do not use this method for record Ids in the short form of 15
characters: the short forms of two different records can differ only by case, so it could return calls made for
another record.

Each call holds only these fields: Id, ServiceName__c, Status__c, CreatedDate and TriggeringRecordIndex__c. To get
the request or the response of a call, read that call by its Id.

Triggering Record Index is filled each time a call is saved. A call saved before the field existed has it blank
until the update script in the release notes is run, and this method does not find it.

The read checks the running user's access. The user needs read access to the API Call object and to each field
above, and gets only the calls that record sharing lets them see. A user without that object or field access gets
an error (a QueryException) instead of a result.

In a test, the mocked calls are filtered the way the query filters saved ones: only those whose Triggering
Record Index holds one of the values come back. A mock is never saved, so Triggering Record Index is not filled
for it: set it on the mock yourself, because a mock that sets only Triggering Record Id is not found. The match in
a test is exact, so a value in another case is not found. An answer scripted
with TST_Mock.registerNext is filtered the same way, so give its mocks the values this method searches for.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `values` | [Set](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_set.htm) | The values to look for. A null or blank value in the set is ignored. The set you pass is not changed. |
| `rowLimit` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The most calls to return: 1 or more. |

**Returns** [ApiCall__c](../objects/ApiCall__c.md) — The calls found, newest first. An empty list when the set holds no value; then no query is run.

**Throws**

| Exception | Description |
|-----------|-------------|
| [IllegalArgumentException](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_classes_exception_methods.htm) | When values is null, or rowLimit is null or less than 1. |

**Example**

```apex
List<ApiCall__c> calls = new SEL_ApiCall().findByTriggeringRecordValues(new Set<String> {'ORD-99182'}, 10);
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
| global [SEL_ApiCall](#constructors)() | Reads ApiCall__c records: the record kept for each web service call, inbound or outbound. |

### SEL_ApiCall()

<div class="apex-member">

```apex
global SEL_ApiCall()
```

Reads ApiCall__c records: the record kept for each web service call, inbound or outbound. Its queries skip the running user's object and field permission
checks (system mode), except the two finders by triggering record, findByTriggeringRecordIds and findByTriggeringRecordValues. Those two run in user mode, so they respect
the running user's object access, field access and record sharing. For the other queries, record sharing follows the class that calls the selector, unless a method says
otherwise. Creating the selector runs no query.

**Example**

```apex
SEL_ApiCall instance = new SEL_ApiCall();
```

</div>

