---
title: "IF_Trigger.AfterUndelete"
type: class
pageClass: reference
description: "Handler contract for the after-undelete trigger event."
since: "1.0"
category: apex
---

# IF_Trigger.AfterUndelete

**Class**

<div class="apex-member apex-class">

```apex
global interface IF_Trigger.AfterUndelete
```

**Known Derived Types:** [TRG_ExecuteValidationRules](TRG_ExecuteValidationRules.md), [TRG_ExecuteValidationRules.afterUndelete(List<SObject>)](TRG_ExecuteValidationRules.md#afterundelete)

Handler contract for the after-undelete trigger event.

</div>

---

## Methods

| Method | Description |
|--------|-------------|
| global abstract void [afterUndelete](#afterundelete)([List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm)> newRecords) | Called after records have been restored from the Recycle Bin, enabling re-linking of relationships, reactivation of dependent processes, or synchronisation with external systems. |

---

## Method Details

### afterUndelete

<div class="apex-member">

```apex
global abstract void afterUndelete(List<SObject> newRecords)
```

Called after records have been restored from the Recycle Bin,
enabling re-linking of relationships, reactivation of dependent processes,
or synchronisation with external systems.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `newRecords` | [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm) | The batch of SObjects that were restored. |

**Example**

```apex
public class TRG_RestoreRelatedData extends TRG_Base implements IF_Trigger.AfterUndelete
{
    public void afterUndelete(List<SObject> newRecords)
    {
        for(SObject record : newRecords)
        {
            LOG_Builder.build().info('Restored ' + record.Id).emitAt('TRG_RestoreRelatedData');
        }
    }
}
```

</div>

