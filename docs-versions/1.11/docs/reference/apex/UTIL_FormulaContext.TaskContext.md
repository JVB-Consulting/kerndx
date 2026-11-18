---
title: "UTIL_FormulaContext.TaskContext"
type: class
pageClass: reference
description: "Formula evaluation context for Task object. Provides typed access to Task records in formula evaluations. Auto-detected by Trigger Action Framework when EntryCriteriaContextClassName__c is blank. Can "
since: "1.0"
category: apex
---

# UTIL_FormulaContext.TaskContext

**Class**

<div class="apex-member apex-class">

```apex
global inherited sharing class UTIL_FormulaContext.TaskContext implements UTIL_FormulaFilter.INT_SObjectFormulaEvaluationContext
```

**Implements:** [UTIL_FormulaFilter.INT_SObjectFormulaEvaluationContext](UTIL_FormulaFilter.INT_SObjectFormulaEvaluationContext.md)

Formula evaluation context for Task object. Provides typed access to Task records in formula evaluations. Auto-detected by Trigger Action Framework when EntryCriteriaContextClassName__c is blank. Can also be used directly in custom Apex. Formula Variable Names: oldRecord, newRecord

**Example**

```apex
// Trigger Action Framework formulas:
// newRecord.Status = "Completed"
// newRecord.Priority = "High" && oldRecord.Status <> "Completed"
// Direct Apex usage:
FormulaEval.FormulaInstance formula = Formula.builder()
    .withFormula('newRecord.IsClosed && newRecord.Priority = "High"')
    .withReturnType(FormulaEval.FormulaReturnType.BOOLEAN)
    .withType(UTIL_FormulaContext.TaskContext.class)
    .build();
UTIL_FormulaContext.TaskContext context = new UTIL_FormulaContext.TaskContext();
context.setContext(null, task); // null = no old record (insert scenario)
Boolean matches = (Boolean)formula.evaluate(context);
```

**See Also:** [UTIL_FormulaFilter.INT_SObjectFormulaEvaluationContext](UTIL_FormulaFilter.INT_SObjectFormulaEvaluationContext.md)

</div>

---

## Fields

| Field | Description |
|-------|-------------|
| global [Task](https://developer.salesforce.com/docs/atlas.en-us.object_reference.meta/object_reference/sforce_api_objects_task.htm) [newRecord](#newrecord) | Task record state AFTER DML (null on delete). |
| global [Task](https://developer.salesforce.com/docs/atlas.en-us.object_reference.meta/object_reference/sforce_api_objects_task.htm) [oldRecord](#oldrecord) | Task record state BEFORE DML (null on insert). |

### newRecord

```apex
global Task newRecord
```

**Type:** [Task](https://developer.salesforce.com/docs/atlas.en-us.object_reference.meta/object_reference/sforce_api_objects_task.htm)

Task record state AFTER DML (null on delete).

**Example**

```apex
Task value = instance.newRecord;
```

### oldRecord

```apex
global Task oldRecord
```

**Type:** [Task](https://developer.salesforce.com/docs/atlas.en-us.object_reference.meta/object_reference/sforce_api_objects_task.htm)

Task record state BEFORE DML (null on insert).

**Example**

```apex
Task value = instance.oldRecord;
```

