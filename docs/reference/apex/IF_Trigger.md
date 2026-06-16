---
title: "IF_Trigger"
type: class
pageClass: reference
description: "Contracts for metadata-driven trigger action handlers. Each nested interface corresponds to a Salesforce trigger event and defines the callback signature that handler classes must implement. Handlers "
author: "Jason Van Beukering"
group: "Triggers"
date: "February 2026, May 2026"
since: "1.0"
category: apex
---

# IF_Trigger

**Class** · Group: `Triggers`

<div class="apex-member apex-class">

```apex
global inherited sharing class IF_Trigger
```

Contracts for metadata-driven trigger action handlers. Each nested interface corresponds to a Salesforce trigger event and defines the callback signature that handler classes must implement. Handlers extend TRG_Base and declare the interfaces matching the events they handle; the TRG_Dispatcher invokes the correct callback at runtime based on TriggerAction__mdt configuration. Adapted from: apex-trigger-actions-framework

**Example**

```apex
public class TRG_SetDefaults extends TRG_Base implements IF_Trigger.BeforeInsert
{
    public void beforeInsert(List<SObject> newRecords)
    {
        for(SObject record : newRecords)
        {
            record.put('Status__c', 'New');
        }
    }
}
```

**See Also:** [TRG_Base](TRG_Base.md)

</div>

---

## Properties

| Property | Description |
|----------|-------------|
| global interface [AfterDelete](IF_Trigger.AfterDelete.md) | Handler contract for the after-delete trigger event. |
| global interface [AfterInsert](IF_Trigger.AfterInsert.md) | Handler contract for the after-insert trigger event. |
| global interface [AfterUndelete](IF_Trigger.AfterUndelete.md) | Handler contract for the after-undelete trigger event. |
| global interface [AfterUpdate](IF_Trigger.AfterUpdate.md) | Handler contract for the after-update trigger event. |
| global interface [BeforeDelete](IF_Trigger.BeforeDelete.md) | Handler contract for the before-delete trigger event. |
| global interface [BeforeInsert](IF_Trigger.BeforeInsert.md) | Handler contract for the before-insert trigger event. |
| global interface [BeforeUpdate](IF_Trigger.BeforeUpdate.md) | Handler contract for the before-update trigger event. |
| global interface [PostAction](IF_Trigger.PostAction.md) | Handler contract for a post-trigger action — an Apex class that runs exactly once at the end of a trigger transaction, after every trigger action on every touched SObject has completed. |
| global interface [PostActionEntryCriteria](IF_Trigger.PostActionEntryCriteria.md) | Optional entry-criteria contract for a post-trigger action. |

## Inner Classes

| Class | Description |
|-------|-------------|
| [PostActionContext](IF_Trigger.PostActionContext.md) | Context handed to a post-trigger action when the dispatcher unwinds the outermost trigger dispatch. |

