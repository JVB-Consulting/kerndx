---
title: "IF_Trigger.PostAction"
type: class
description: "Handler contract for a post-trigger action — an Apex class that runs exactly once at the end of a trigger transaction, after every trigger action on every touched SObject has completed. Use for cross-"
since: "1.1"
category: apex
---

# IF_Trigger.PostAction

**Class**

```apex
global interface IF_Trigger.PostAction
```

Handler contract for a post-trigger action — an Apex class that runs exactly once at the end of a trigger transaction, after every trigger action on every touched SObject has completed. Use for cross-object or transaction-scoped work that cannot be done from inside an individual trigger action: audit aggregation, asynchronous job enqueue, transaction-wide telemetry. DML is contractually prohibited — the framework throws if a post-trigger action performs DML, regardless of the row's FailureAction setting. Registered via PostTriggerAction__mdt. The framework fires post-actions at the outermost dispatch unwind, in Order__c ascending. Optional gates apply in order: BypassExecution → BypassFeatureFlag / RequiredFeatureFlag → TriggerSetting scope → EntryCriteriaContextClassName.

**Since:** 1.1

---

## Methods

| Method | Description |
|--------|-------------|
| global abstract void [execute](#execute)([IF_Trigger.PostActionContext](IF_Trigger.PostActionContext.md) context) | Called once per outermost dispatch with the context of touched SObject types. |

---

## Method Details

### execute

```apex
global abstract void execute(IF_Trigger.PostActionContext context)
```

Called once per outermost dispatch with the context of touched
SObject types. Implementations should be idempotent within a single transaction —
a transaction with N top-level DML statements fires post-actions N times.

**Parameters:**

- `context` ([IF_Trigger.PostActionContext](IF_Trigger.PostActionContext.md)) - The post-action context for this dispatch. Carries the set of
SObject types whose triggers participated in the transaction.

**Since:** 1.1

**Example:**

```apex
public class TRG_EmitTransactionAudit implements IF_Trigger.PostAction
{
    public void execute(IF_Trigger.PostActionContext context)
    {
        if(context.touchedSObjectTypes.isEmpty()) return;
        LOG_Builder.build()
            .info('Transaction touched ' + context.touchedSObjectTypes.size() + ' SObject(s)')
            .emitAt('TRG_EmitTransactionAudit');
    }
}
```

