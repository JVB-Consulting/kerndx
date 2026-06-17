---
title: "SEL_ApiIssue"
type: class
pageClass: reference
description: "Selector for the ApiIssue__c SObject. Provides query methods for retrieving and filtering failed API calls, including deduplication via request parameter hash and status-based filtering."
author: "Jason Van Beukering"
group: "Web Services"
date: "February 2026, May 2026"
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

**See Also:** [SEL_Base](SEL_Base.md)

</div>

---

## Methods

| Method | Description |
|--------|-------------|
| global [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[ApiIssue__c](../objects/ApiIssue__c.md)> [findByFailedApiCall](#findbyfailedapicall)([Id](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_id.htm) recordId, [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) serviceName, [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) hashParameter) | Finds failed API call records matching the triggering object, service name, and request hash. |
| global [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[ApiIssue__c](../objects/ApiIssue__c.md)> [getAll](#getall)() | Retrieves all ApiIssue__c records. |
| global override [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm)> [getFields](#getfields)() | Returns the core fields for ApiIssue__c queries. |

### findByFailedApiCall

<div class="apex-member">

```apex
global List<ApiIssue__c> findByFailedApiCall(Id recordId, String serviceName, String hashParameter)
```

Finds failed API call records matching the triggering object, service name, and request hash.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `recordId` | [Id](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_id.htm) | The Id of the triggering record |
| `serviceName` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The name of the web service |
| `hashParameter` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The request parameters hash to match |

**Returns** [ApiIssue__c](../objects/ApiIssue__c.md) — List of matching failed ApiIssue__c records

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
| global [SEL_ApiIssue](#constructors)() | Constructs an ApiIssue selector. |

### SEL_ApiIssue()

<div class="apex-member">

```apex
global SEL_ApiIssue()
```

Constructs an ApiIssue selector.

**Example**

```apex
SEL_ApiIssue instance = new SEL_ApiIssue();
```

</div>

