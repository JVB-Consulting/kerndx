---
title: "IF_Trigger.PostActionEntryCriteria"
type: class
pageClass: reference
description: "Optional entry-criteria contract for a post-trigger action. Implementing classes are referenced from PostTriggerAction__mdt.EntryCriteriaContextClassName__c and consulted before the post-action's exec"
since: "1.1"
category: apex
---

# IF_Trigger.PostActionEntryCriteria

**Class**

<div class="apex-member apex-class">

```apex
global interface IF_Trigger.PostActionEntryCriteria
```

Optional entry-criteria contract for a post-trigger action. Implementing classes are referenced from PostTriggerAction__mdt.EntryCriteriaContextClassName__c and consulted before the post-action's execute(context) is invoked. Returning false skips the row; returning true proceeds to execution. Use for context-level gating (e.g. "only run when Account records were touched AND feature flag X is enabled"). Evaluators should be cheap — configuration lookups, feature-flag checks, Set membership tests, at most one bounded SOQL. Expensive evaluators undermine the cost benefit of having an entry criteria at all.

</div>

---

## Methods

| Method | Description |
|--------|-------------|
| global abstract [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) [shouldRun](#shouldrun)([IF_Trigger.PostActionContext](IF_Trigger.PostActionContext.md) context) | Called once per outermost dispatch before the gated post-action. |

---

## Method Details

### shouldRun

<div class="apex-member">

```apex
global abstract Boolean shouldRun(IF_Trigger.PostActionContext context)
```

Called once per outermost dispatch before the gated post-action.
Returning false skips the post-action; returning true proceeds to execution.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `context` | [IF_Trigger.PostActionContext](IF_Trigger.PostActionContext.md) | The post-action context for this dispatch. Carries the set of SObject types whose triggers participated in the transaction. |

**Returns** [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) — `true` if the gated post-action should run; `false` to skip it.

**Example**

```apex
public class TRG_PostActionEntryBrandA implements IF_Trigger.PostActionEntryCriteria
{
    public Boolean shouldRun(IF_Trigger.PostActionContext context)
    {
        if(!context.touchedSObjectTypes.contains(Account.SObjectType)) return false;
        return UTIL_FeatureFlag.isEnabled('BrandA_Sales_Enabled');
    }
}
```

</div>

