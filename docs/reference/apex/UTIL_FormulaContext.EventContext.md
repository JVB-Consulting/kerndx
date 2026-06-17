---
title: "UTIL_FormulaContext.EventContext"
type: class
pageClass: reference
description: "Formula evaluation context for Event object. Provides typed access to Event records in formula evaluations. Auto-detected by Trigger Action Framework when EntryCriteriaContextClassName__c is blank. Ca"
since: "1.0"
category: apex
---

# UTIL_FormulaContext.EventContext

**Class**

<div class="apex-member apex-class">

```apex
global inherited sharing class UTIL_FormulaContext.EventContext implements UTIL_FormulaFilter.INT_SObjectFormulaEvaluationContext
```

**Implements:** [UTIL_FormulaFilter.INT_SObjectFormulaEvaluationContext](UTIL_FormulaFilter.INT_SObjectFormulaEvaluationContext.md)

Formula evaluation context for Event object. Provides typed access to Event records in formula evaluations. Auto-detected by Trigger Action Framework when EntryCriteriaContextClassName__c is blank. Can also be used directly in custom Apex. Formula Variable Names: oldRecord, newRecord

**Example**

```apex
// Trigger Action Framework formulas:
// newRecord.IsAllDayEvent = true
// newRecord.StartDateTime <> oldRecord.StartDateTime
// Direct Apex usage:
FormulaEval.FormulaInstance formula = Formula.builder()
    .withFormula('newRecord.IsAllDayEvent && newRecord.IsPrivate = false')
    .withReturnType(FormulaEval.FormulaReturnType.BOOLEAN)
    .withType(UTIL_FormulaContext.EventContext.class)
    .build();
UTIL_FormulaContext.EventContext context = new UTIL_FormulaContext.EventContext();
context.setContext(null, event); // null = no old record (insert scenario)
Boolean matches = (Boolean)formula.evaluate(context);
```

**See Also:** [UTIL_FormulaFilter.INT_SObjectFormulaEvaluationContext](UTIL_FormulaFilter.INT_SObjectFormulaEvaluationContext.md)

</div>

---

## Fields

| Field | Description |
|-------|-------------|
| global [Event](https://developer.salesforce.com/docs/atlas.en-us.object_reference.meta/object_reference/sforce_api_objects_event.htm) [newRecord](#newrecord) | Event record state AFTER DML (null on delete). |
| global [Event](https://developer.salesforce.com/docs/atlas.en-us.object_reference.meta/object_reference/sforce_api_objects_event.htm) [oldRecord](#oldrecord) | Event record state BEFORE DML (null on insert). |

### newRecord

```apex
global Event newRecord
```

**Type:** [Event](https://developer.salesforce.com/docs/atlas.en-us.object_reference.meta/object_reference/sforce_api_objects_event.htm)

Event record state AFTER DML (null on delete).

**Example**

```apex
Event value = instance.newRecord;
```

### oldRecord

```apex
global Event oldRecord
```

**Type:** [Event](https://developer.salesforce.com/docs/atlas.en-us.object_reference.meta/object_reference/sforce_api_objects_event.htm)

Event record state BEFORE DML (null on insert).

**Example**

```apex
Event value = instance.oldRecord;
```

