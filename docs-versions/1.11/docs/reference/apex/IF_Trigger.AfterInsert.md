---
title: "IF_Trigger.AfterInsert"
type: class
pageClass: reference
description: "Handler contract for the after-insert trigger event."
since: "1.0"
category: apex
---

# IF_Trigger.AfterInsert

**Class**

<div class="apex-member apex-class">

```apex
global interface IF_Trigger.AfterInsert
```

**Known Derived Types:** [TRG_ExecuteValidationRules](TRG_ExecuteValidationRules.md), [TRG_ExecuteValidationRules.afterInsert(List<SObject>)](TRG_ExecuteValidationRules.md#afterinsert)

Handler contract for the after-insert trigger event.

</div>

---

## Methods

| Method | Description |
|--------|-------------|
| global abstract void [afterInsert](#afterinsert)([List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm)> newRecords) | Called after records have been inserted and assigned IDs, enabling cross-object updates, platform event publishing, or asynchronous follow-up work. |

### afterInsert

<div class="apex-member">

```apex
global abstract void afterInsert(List<SObject> newRecords)
```

Called after records have been inserted and assigned IDs, enabling
cross-object updates, platform event publishing, or asynchronous follow-up work.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `newRecords` | [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm) | The batch of SObjects that were inserted (with IDs populated). |

**Example**

```apex
public class TRG_PublishAccountEvent extends TRG_Base implements IF_Trigger.AfterInsert
{
    public void afterInsert(List<SObject> newRecords)
    {
        for(SObject record : newRecords)
        {
            LOG_Builder.build().info('Created ' + record.Id).emitAt('TRG_PublishAccountEvent');
        }
    }
}
```

</div>

