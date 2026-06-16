---
title: "AsynchronousJobSetting__mdt"
type: sobject
pageClass: reference
description: "Declarative configuration for asynchronous job classes. The DeveloperName of each record should match the Apex class name it configures."
category: metadata
---

# AsynchronousJobSetting__mdt

**Sobject**

<div class="apex-member apex-class">

```apex
global class AsynchronousJobSetting__mdt extends SObject
```

**Extends:** [SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm)

Declarative configuration for asynchronous job classes. The DeveloperName of each record should match the Apex class name it configures.

</div>

---

## Fields

| Field | Description |
|-------|-------------|
| global [Decimal](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_decimal.htm) [BatchSize__c](#batchsize__c) | The number of records to process per execution of the asynchronous job class. |

---

## Field Details

### BatchSize__c

```apex
global Decimal BatchSize__c
```

The number of records to process per execution of the asynchronous job class. The DeveloperName of this record should match the class name. Valid range: 1-2000.

**Field Attributes:**

| Attribute | Value |
|-----------|-------|
| Data Type | Number(4,0) |
| Required | false |
| Unique | false |
| External ID | false |

