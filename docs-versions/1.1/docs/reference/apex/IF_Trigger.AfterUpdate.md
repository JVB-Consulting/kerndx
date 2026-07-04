---
title: "IF_Trigger.AfterUpdate"
type: class
description: "Handler contract for the after-update trigger event."
since: "1.0"
category: apex
---

# IF_Trigger.AfterUpdate

**Class**

```apex
global interface IF_Trigger.AfterUpdate
```

**Known Derived Types:** [TRG_ExecuteValidationRules](TRG_ExecuteValidationRules.md), [TRG_ExecuteValidationRules.afterUpdate(List<SObject>,List<SObject>)](TRG_ExecuteValidationRules.md#afterupdate)

Handler contract for the after-update trigger event.

**Since:** 1.0

---

## Methods

| Method | Description |
|--------|-------------|
| global abstract void [afterUpdate](#afterupdate)([List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm)> oldRecords) | Called after records have been updated and committed, enabling cascading updates to related objects, notifications, or audit trail entries. |

---

## Method Details

### afterUpdate

```apex
global abstract void afterUpdate(List<SObject> newRecords, List<SObject> oldRecords)
```

Called after records have been updated and committed, enabling
cascading updates to related objects, notifications, or audit trail entries.

**Parameters:**

- `newRecords` ([List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)) - The batch of SObjects with their committed field values.
- `oldRecords` ([SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm)) - The batch of SObjects with their values prior to the update.

**Since:** 1.0

**Example:**

```apex
public class TRG_SyncAccountToExternal extends TRG_Base implements IF_Trigger.AfterUpdate
{
    public void afterUpdate(List<SObject> newRecords, List<SObject> oldRecords)
    {
        for(Integer i = 0; i < newRecords.size(); i++)
        {
            if(newRecords[i].get('Name') != oldRecords[i].get('Name'))
            {
                LOG_Builder.build().info('Name changed').emitAt('TRG_SyncAccountToExternal');
            }
        }
    }
}
```

