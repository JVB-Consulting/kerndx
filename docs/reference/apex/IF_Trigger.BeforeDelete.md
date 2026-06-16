---
title: "IF_Trigger.BeforeDelete"
type: class
pageClass: reference
description: "Handler contract for the before-delete trigger event."
since: "1.0"
category: apex
---

# IF_Trigger.BeforeDelete

**Class**

```apex
global interface IF_Trigger.BeforeDelete
```

**Known Derived Types:** [TRG_ExecuteValidationRules](TRG_ExecuteValidationRules.md), [TRG_ExecuteValidationRules.beforeDelete(List<SObject>)](TRG_ExecuteValidationRules.md#beforedelete)

Handler contract for the before-delete trigger event.

**Since:** 1.0

---

## Methods

| Method | Description |
|--------|-------------|
| global abstract void [beforeDelete](#beforedelete)([List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm)> oldRecords) | Called before records are removed from the database, enabling deletion guards, referential integrity checks, or pre-delete archival logic. |

---

## Method Details

### beforeDelete

<div class="apex-member">

```apex
global abstract void beforeDelete(List<SObject> oldRecords)
```

Called before records are removed from the database, enabling
deletion guards, referential integrity checks, or pre-delete archival logic.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `oldRecords` | [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm) | The batch of SObjects about to be deleted. |

**Example**

```apex
public class TRG_PreventProtectedDelete extends TRG_Base implements IF_Trigger.BeforeDelete
{
    public void beforeDelete(List<SObject> oldRecords)
    {
        for(SObject record : oldRecords)
        {
            if((Boolean)record.get('IsProtected__c') == true)
            {
                record.addError('Protected records cannot be deleted');
            }
        }
    }
}
```

</div>

