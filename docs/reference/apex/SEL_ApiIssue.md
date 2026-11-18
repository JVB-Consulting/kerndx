---
title: "SEL_ApiIssue"
type: class
pageClass: reference
description: "Selector for the ApiIssue__c SObject. Provides query methods for retrieving and filtering failed API calls, including deduplication via request parameter hash and status-based filtering."
author: "Jason Van Beukering"
group: "Web Services"
date: "February 2026, November 2026"
since: "1.0"
category: apex
---

# SEL_ApiIssue

**Class** · Group: `Web Services`

<div class="apex-member apex-class">

```apex
global inherited sharing class SEL_ApiIssue extends SEL_Base
```

**Extends:** [SEL_Base](SEL_Base.md)

Selector for the ApiIssue__c SObject. Provides query methods for retrieving and filtering failed API calls, including deduplication via request parameter hash and status-based filtering.

**Example**

```apex
List<ApiIssue__c> issues = new SEL_ApiIssue().findUnresolvedByService('API_SendEmail');
List<ApiIssue__c> inbound = new SEL_ApiIssue().findUnresolvedInbound();
ApiIssue__c issue = (ApiIssue__c)new SEL_ApiIssue().findById(issueId);
```

**See Also:** [SEL_Base](SEL_Base.md), [SEL_ApiCall](SEL_ApiCall.md)

</div>

---

## Methods

| Method | Description |
|--------|-------------|
| global [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[ApiIssue__c](../objects/ApiIssue__c.md)> [findByFailedApiCall](#findbyfailedapicall)([Id](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_id.htm) recordId, [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) serviceName, [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) hashParameter) | Finds every user's open issues for one request: the same triggering record, service name and request parameters hash. |
| global [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[ApiIssue__c](../objects/ApiIssue__c.md)> [findByTriggeringRecordIds](#findbytriggeringrecordids)([Set](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_set.htm)<[Id](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_id.htm)> recordIds, [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) rowLimit) | Finds the issues raised for calls made for the given records, newest first, and returns at most rowLimit of them. |
| global [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[ApiIssue__c](../objects/ApiIssue__c.md)> [findByTriggeringRecordValues](#findbytriggeringrecordvalues)([Set](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_set.htm)<[String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)> values, [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) rowLimit) | Finds the issues with one of the given values in Triggering Record Index (TriggeringRecordIndex__c), newest first, and returns at most rowLimit of them. |
| global [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[ApiIssue__c](../objects/ApiIssue__c.md)> [getAll](#getall)() | Retrieves all ApiIssue__c records. |
| global override [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm)> [getFields](#getfields)() | Returns the core fields for ApiIssue__c queries. |

### findByFailedApiCall

<div class="apex-member">

```apex
global List<ApiIssue__c> findByFailedApiCall(Id recordId, String serviceName, String hashParameter)
```

Finds every user's open issues for one request: the same triggering record, service name and request
parameters hash. Use it to find out whether a request you know about has failed and is still open, for example to
mark those issues resolved once the request succeeds.

The method reads in system mode and ignores record sharing, so it returns the open issues of every user, not only
the ones the running user owns or can see. That is safe because you must already hold the record Id, the service
name and the request parameters hash to ask: you are asking about a request you know. The framework itself relies on
this answer when a later call for the same request succeeds, and the user whose call succeeds is often not the user
whose call failed. Your code decides what to show to whom: if you show the returned issues to a person, check that
they may see them first.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `recordId` | [Id](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_id.htm) | The Id of the triggering record |
| `serviceName` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The name of the web service |
| `hashParameter` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The request parameters hash to match |

**Returns** [ApiIssue__c](../objects/ApiIssue__c.md) — The open issues for the request, whoever owns them

</div>

### findByTriggeringRecordIds

<div class="apex-member">

```apex
global List<ApiIssue__c> findByTriggeringRecordIds(Set<Id> recordIds, Integer rowLimit)
```

Finds the issues raised for calls made for the given records, newest first, and returns at most
rowLimit of them. Issues saved at the same moment are ordered by their own Id, newest first, so the order is the
same every time.

An issue is found by its Triggering Record Index field (TriggeringRecordIndex__c), which holds the record Id exactly
as it was written on the issue. This method finds values stored in the full form of 18 characters, which is the form
the framework writes. It does not find a value stored in the short form of 15 characters. Code that sets the
Triggering Record Id field (TriggeringRecordId__c) itself should write the full form, for example
String.valueOf(recordId).

Each issue holds only these fields: Id, ServiceName__c, Status__c, CreatedDate and TriggeringRecordIndex__c. To get
the request of an issue, read that issue by its Id.

Triggering Record Index is filled each time an issue is saved. An issue saved before the field existed has it blank
until the update script in the release notes is run, and this method does not find it.

The read checks the running user's access. The user needs read access to the API Issue object and to each field
above, and gets only the issues that record sharing lets them see. A user without that object or field access gets
an error (a QueryException) instead of a result.

In a test, the mocked issues are filtered the way the query filters saved ones: only those whose Triggering
Record Index holds one of the values come back. A mock is never saved, so Triggering Record Index is not filled
for it: set it on the mock yourself, because a mock that sets only Triggering Record Id is not found. The match in
a test is exact, so a value in another case is not found. An answer scripted
with TST_Mock.registerNext is filtered the same way, so give its mocks the values this method searches for.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `recordIds` | [Set](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_set.htm) | The Ids of the records the failed calls were made for. A null Id in the set is ignored. The set you pass is not changed. |
| `rowLimit` | [Id](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_id.htm) | The most issues to return: 1 or more. |

**Returns** [ApiIssue__c](../objects/ApiIssue__c.md) — The issues found, newest first. An empty list when the set holds no Id; then no query is run.

**Throws**

| Exception | Description |
|-----------|-------------|
| [IllegalArgumentException](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_classes_exception_methods.htm) | When recordIds is null, or rowLimit is null or less than 1. |

**Example**

```apex
List<ApiIssue__c> issues = new SEL_ApiIssue().findByTriggeringRecordIds(new Set<Id> {accountId}, 10);
```

</div>

### findByTriggeringRecordValues

<div class="apex-member">

```apex
global List<ApiIssue__c> findByTriggeringRecordValues(Set<String> values, Integer rowLimit)
```

Finds the issues with one of the given values in Triggering Record Index (TriggeringRecordIndex__c),
newest first, and returns at most rowLimit of them. Issues saved at the same moment are ordered by their own Id,
newest first, so the order is the same every time. Use it when the failed calls were made for something that is not
a record in this org, such as an order number from another system; for record Ids, findByTriggeringRecordIds is
simpler.

Such a value can come from an inbound call, from an issue your own code saves, or from an outbound call whose class
sets requiresTriggeringRecord to false. An issue keeps the whole value of the call that failed, up to 80 characters.

Triggering Record Index holds the Triggering Record Id field (TriggeringRecordId__c) exactly as it was written on
the issue. Each value is matched as you write it, but the match ignores upper and lower case: 'ORD-1' also finds an
issue whose Triggering Record Index is 'ord-1'. Do not use this method for record Ids in the short form of 15
characters: the short forms of two different records can differ only by case, so it could return issues raised for
another record.

Each issue holds only these fields: Id, ServiceName__c, Status__c, CreatedDate and TriggeringRecordIndex__c. To get
the request of an issue, read that issue by its Id.

Triggering Record Index is filled each time an issue is saved. An issue saved before the field existed has it blank
until the update script in the release notes is run, and this method does not find it.

The read checks the running user's access. The user needs read access to the API Issue object and to each field
above, and gets only the issues that record sharing lets them see. A user without that object or field access gets
an error (a QueryException) instead of a result.

In a test, the mocked issues are filtered the way the query filters saved ones: only those whose Triggering
Record Index holds one of the values come back. A mock is never saved, so Triggering Record Index is not filled
for it: set it on the mock yourself, because a mock that sets only Triggering Record Id is not found. The match in
a test is exact, so a value in another case is not found. An answer scripted
with TST_Mock.registerNext is filtered the same way, so give its mocks the values this method searches for.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `values` | [Set](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_set.htm) | The values to look for. A null or blank value in the set is ignored. The set you pass is not changed. |
| `rowLimit` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The most issues to return: 1 or more. |

**Returns** [ApiIssue__c](../objects/ApiIssue__c.md) — The issues found, newest first. An empty list when the set holds no value; then no query is run.

**Throws**

| Exception | Description |
|-----------|-------------|
| [IllegalArgumentException](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_classes_exception_methods.htm) | When values is null, or rowLimit is null or less than 1. |

**Example**

```apex
List<ApiIssue__c> issues = new SEL_ApiIssue().findByTriggeringRecordValues(new Set<String> {'ORD-99182'}, 10);
```

</div>

### getAll

<div class="apex-member">

```apex
global List<ApiIssue__c> getAll()
```

Retrieves all ApiIssue__c records. Only executes in test context
to prevent full-table scans in production.

**Returns** [ApiIssue__c](../objects/ApiIssue__c.md) — List of all ApiIssue__c records in test context, empty list in production

**Example**

```apex
List<ApiIssue__c> result = instance.getAll();
```

</div>

### getFields

<div class="apex-member">

```apex
global override List<SObjectField> getFields()
```

Returns the core fields for ApiIssue__c queries.

**Returns** [SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm) — List of ApiIssue__c SObjectField tokens

**Example**

```apex
List<SObjectField> result = instance.getFields();
```

</div>

## Constructors

| Constructor | Description |
|-------------|-------------|
| global [SEL_ApiIssue](#constructors)() | Reads ApiIssue__c records: the issues raised for failed web service calls. |

### SEL_ApiIssue()

<div class="apex-member">

```apex
global SEL_ApiIssue()
```

Reads ApiIssue__c records: the issues raised for failed web service calls. Its queries skip the running user's object and field permission checks (system
mode), except the two finders by triggering record, findByTriggeringRecordIds and findByTriggeringRecordValues. Those two run in user mode, so they respect the running
user's object access, field access and record sharing. For the other queries, record sharing follows the class that calls the selector, unless a method says otherwise.
Creating the selector runs no query.

**Example**

```apex
SEL_ApiIssue instance = new SEL_ApiIssue();
```

</div>

