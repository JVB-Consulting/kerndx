---
title: "IF_Trigger.BeforeInsert"
type: class
description: "Handler contract for the before-insert trigger event."
since: "1.0"
category: apex
---

# IF_Trigger.BeforeInsert

**Class**

```apex
global interface IF_Trigger.BeforeInsert
```

**Known Derived Types:** [TRG_ExecuteValidationRules](TRG_ExecuteValidationRules.md), [TRG_ExecuteValidationRules.beforeInsert(List<SObject>)](TRG_ExecuteValidationRules.md#beforeinsert)

Handler contract for the before-insert trigger event.

**Since:** 1.0

---

## Methods

| Method | Description |
|--------|-------------|
| global abstract void [beforeInsert](#beforeinsert)([List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm)> newRecords) | Called before records are committed to the database, allowing field defaulting, validation, or in-memory enrichment of the incoming batch. |

---

## Method Details

### beforeInsert

```apex
global abstract void beforeInsert(List<SObject> newRecords)
```

Called before records are committed to the database, allowing
field defaulting, validation, or in-memory enrichment of the incoming batch.

**Parameters:**

- `newRecords` ([List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)) - The batch of SObjects about to be inserted.

**Since:** 1.0

**Example:**

```apex
public class TRG_SetAccountDefaults extends TRG_Base implements IF_Trigger.BeforeInsert
{
    public void beforeInsert(List<SObject> newRecords)
    {
        for(SObject record : newRecords)
        {
            record.put('Status__c', 'Draft');
        }
    }
}
```

