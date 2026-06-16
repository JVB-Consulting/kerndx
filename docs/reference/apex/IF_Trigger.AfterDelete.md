---
title: "IF_Trigger.AfterDelete"
type: class
pageClass: reference
description: "Handler contract for the after-delete trigger event."
since: "1.0"
category: apex
---

# IF_Trigger.AfterDelete

**Class**

<div class="apex-member apex-class">

```apex
global interface IF_Trigger.AfterDelete
```

**Known Derived Types:** [TRG_ExecuteValidationRules](TRG_ExecuteValidationRules.md), [TRG_ExecuteValidationRules.afterDelete(List<SObject>)](TRG_ExecuteValidationRules.md#afterdelete)

Handler contract for the after-delete trigger event.

</div>

---

## Methods

| Method | Description |
|--------|-------------|
| global abstract void [afterDelete](#afterdelete)([List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm)> oldRecords) | Called after records have been deleted, enabling cleanup of orphaned child records, external system notifications, or aggregate recalculation. |

---

## Method Details

### afterDelete

<div class="apex-member">

```apex
global abstract void afterDelete(List<SObject> oldRecords)
```

Called after records have been deleted, enabling cleanup of
orphaned child records, external system notifications, or aggregate recalculation.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `oldRecords` | [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm) | The batch of SObjects that were deleted. |

**Example**

```apex
public class TRG_CleanupOrphanedFiles extends TRG_Base implements IF_Trigger.AfterDelete
{
    public void afterDelete(List<SObject> oldRecords)
    {
        Set<Id> deletedIds = new Map<Id, SObject>(oldRecords).keySet();
        LOG_Builder.build().info('Cleaned up ' + deletedIds.size() + ' records').emitAt('TRG_CleanupOrphanedFiles');
    }
}
```

</div>

