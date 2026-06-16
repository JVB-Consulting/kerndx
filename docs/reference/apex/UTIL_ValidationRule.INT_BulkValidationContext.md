---
title: "UTIL_ValidationRule.INT_BulkValidationContext"
type: class
pageClass: reference
description: "Optional interface for bulk-optimized validation contexts. Implement this in addition to INT_SObjectFormulaEvaluationContext when your context class needs to query related data. The preLoad() method i"
since: "1.0"
category: apex
---

# UTIL_ValidationRule.INT_BulkValidationContext

**Class**

```apex
global interface UTIL_ValidationRule.INT_BulkValidationContext
```

Optional interface for bulk-optimized validation contexts. Implement this in addition to INT_SObjectFormulaEvaluationContext when your context class needs to query related data. The preLoad() method is called once per batch of records BEFORE the record loop, allowing you to perform bulk queries and cache results for use in setContext().

**Since:** 1.0

**Example:**

```apex
global class VAL_AccountWithContactsContext
    implements UTIL_FormulaFilter.INT_SObjectFormulaEvaluationContext,
               UTIL_ValidationRule.INT_BulkValidationContext
{
    private Map<Id, Integer> contactCountByAccountId = new Map<Id, Integer>();
    global Integer ContactCount { get; set; }
    global void preLoad(List<SObject> newRecords, List<SObject> oldRecords)
    {
        Set<Id> accountIds = UTIL_SObject.extractIds(newRecords);
        List<AggregateResult> results = QRY_Builder.selectFrom(Contact.SObjectType)
            .count('Id')
            .groupBy(Contact.AccountId)
            .condition(Contact.AccountId).isIn(new List<Id>(accountIds))
            .toList();
        for(AggregateResult result : results)
        {
            contactCountByAccountId.put((Id)result.get('AccountId'), (Integer)result.get('count_Id'));
        }
    }
    global void setContext(SObject oldRecord, SObject newRecord)
    {
        Account account = (Account)newRecord;
        this.ContactCount = contactCountByAccountId.get(account.Id) ?? 0;
    }
}
```

---

## Methods

| Method | Description |
|--------|-------------|
| global abstract void [preLoad](#preload)([List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm)> newRecords, [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm)> oldRecords) | Called once per batch before the record loop. |

---

## Method Details

### preLoad

<div class="apex-member">

```apex
global abstract void preLoad(List<SObject> newRecords, List<SObject> oldRecords)
```

Called once per batch before the record loop.
Use this to perform bulk queries and cache results.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `newRecords` | [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm) | The list of new records (Trigger.new) |
| `oldRecords` | [SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm) | The list of old records (Trigger.old), may be null for insert |

</div>

