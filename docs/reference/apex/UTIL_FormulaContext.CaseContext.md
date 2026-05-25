---
title: "UTIL_FormulaContext.CaseContext"
type: class
description: "Formula evaluation context for Case object. Provides typed access to Case records in formula evaluations. Auto-detected by Trigger Action Framework when EntryCriteriaContextClassName__c is blank. Can "
since: "1.0"
category: apex
---

# UTIL_FormulaContext.CaseContext

**Class**

```apex
global inherited sharing class UTIL_FormulaContext.CaseContext implements UTIL_FormulaFilter.INT_SObjectFormulaEvaluationContext
```

**Implements:** [UTIL_FormulaFilter.INT_SObjectFormulaEvaluationContext](UTIL_FormulaFilter.INT_SObjectFormulaEvaluationContext.md)

Formula evaluation context for Case object. Provides typed access to Case records in formula evaluations. Auto-detected by Trigger Action Framework when EntryCriteriaContextClassName__c is blank. Can also be used directly in custom Apex. Note: Class is named CaseContext because Case is an Apex reserved keyword. Formula Variable Names: oldRecord, newRecord

**Since:** 1.0

**Example:**

```apex
// Trigger Action Framework formulas:
// newRecord.Priority = "High"
// newRecord.Status <> oldRecord.Status
// newRecord.IsClosed && NOT(oldRecord.IsClosed)
// Direct Apex usage:
FormulaEval.FormulaInstance formula = Formula.builder()
    .withFormula('newRecord.IsEscalated && newRecord.Priority = "High"')
    .withReturnType(FormulaEval.FormulaReturnType.BOOLEAN)
    .withType(UTIL_FormulaContext.CaseContext.class)
    .build();
UTIL_FormulaContext.CaseContext context = new UTIL_FormulaContext.CaseContext();
context.setContext(null, caseRecord); // null = no old record (insert scenario)
Boolean matches = (Boolean)formula.evaluate(context);
```

**See Also:** [UTIL_FormulaFilter.INT_SObjectFormulaEvaluationContext](UTIL_FormulaFilter.INT_SObjectFormulaEvaluationContext.md)

---

## Fields

| Field | Description |
|-------|-------------|
| global [Case](https://developer.salesforce.com/docs/atlas.en-us.object_reference.meta/object_reference/sforce_api_objects_case.htm) [newRecord](#newrecord) | Case record state AFTER DML (null on delete). |
| global [Case](https://developer.salesforce.com/docs/atlas.en-us.object_reference.meta/object_reference/sforce_api_objects_case.htm) [oldRecord](#oldrecord) | Case record state BEFORE DML (null on insert). |

---

## Field Details

### newRecord

```apex
global Case newRecord
```

**Type:** [Case](https://developer.salesforce.com/docs/atlas.en-us.object_reference.meta/object_reference/sforce_api_objects_case.htm)

Case record state AFTER DML (null on delete).

**Since:** 1.0

**Example:**

```apex
Case value = instance.newRecord;
```

### oldRecord

```apex
global Case oldRecord
```

**Type:** [Case](https://developer.salesforce.com/docs/atlas.en-us.object_reference.meta/object_reference/sforce_api_objects_case.htm)

Case record state BEFORE DML (null on insert).

**Since:** 1.0

**Example:**

```apex
Case value = instance.oldRecord;
```

