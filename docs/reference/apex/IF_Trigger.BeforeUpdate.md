---
title: "IF_Trigger.BeforeUpdate"
type: class
pageClass: reference
description: "Handler contract for the before-update trigger event."
since: "1.0"
category: apex
---

# IF_Trigger.BeforeUpdate

**Class**

<div class="apex-member apex-class">

```apex
global interface IF_Trigger.BeforeUpdate
```

**Known Derived Types:** [TRG_ExecuteValidationRules](TRG_ExecuteValidationRules.md), [TRG_ExecuteValidationRules.beforeUpdate(List<SObject>,List<SObject>)](TRG_ExecuteValidationRules.md#beforeupdate)

Handler contract for the before-update trigger event.

</div>

---

## Methods

| Method | Description |
|--------|-------------|
| global abstract void [beforeUpdate](#beforeupdate)([List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm)> newRecords, [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm)> oldRecords) | Called before modified records are saved, enabling field-level validation, change detection, or in-memory transformations using old and new state. |

---

## Method Details

### beforeUpdate

<div class="apex-member">

```apex
global abstract void beforeUpdate(List<SObject> newRecords, List<SObject> oldRecords)
```

Called before modified records are saved, enabling field-level
validation, change detection, or in-memory transformations using old and new state.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `newRecords` | [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm) | The batch of SObjects with their proposed field values. |
| `oldRecords` | [SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm) | The batch of SObjects with their values prior to the update. |

**Example**

```apex
public class TRG_TrackStatusChange extends TRG_Base implements IF_Trigger.BeforeUpdate
{
    public void beforeUpdate(List<SObject> newRecords, List<SObject> oldRecords)
    {
        for(Integer i = 0; i < newRecords.size(); i++)
        {
            if(newRecords[i].get('Status__c') != oldRecords[i].get('Status__c'))
            {
                newRecords[i].put('StatusChangedDate__c', System.now());
            }
        }
    }
}
```

</div>

