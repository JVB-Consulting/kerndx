---
title: "UTIL_FormulaContext.OpportunityContext"
type: class
description: "Formula evaluation context for Opportunity object. Provides typed access to Opportunity records in formula evaluations. Auto-detected by Trigger Action Framework when EntryCriteriaContextClassName__c "
since: "1.0"
category: apex
---

# UTIL_FormulaContext.OpportunityContext

**Class**

```apex
global inherited sharing class UTIL_FormulaContext.OpportunityContext implements UTIL_FormulaFilter.INT_SObjectFormulaEvaluationContext
```

**Implements:** [UTIL_FormulaFilter.INT_SObjectFormulaEvaluationContext](UTIL_FormulaFilter.INT_SObjectFormulaEvaluationContext.md)

Formula evaluation context for Opportunity object. Provides typed access to Opportunity records in formula evaluations. Auto-detected by Trigger Action Framework when EntryCriteriaContextClassName__c is blank. Can also be used directly in custom Apex. Formula Variable Names: oldRecord, newRecord

**Since:** 1.0

**Example:**

```apex
// Trigger Action Framework formulas:
// newRecord.StageName <> oldRecord.StageName
// newRecord.Amount > 100000 && newRecord.StageName = "Closed Won"
// Direct Apex usage:
FormulaEval.FormulaInstance formula = Formula.builder()
    .withFormula('newRecord.IsClosed && newRecord.IsWon')
    .withReturnType(FormulaEval.FormulaReturnType.BOOLEAN)
    .withType(UTIL_FormulaContext.OpportunityContext.class)
    .build();
UTIL_FormulaContext.OpportunityContext context = new UTIL_FormulaContext.OpportunityContext();
context.setContext(null, opportunity); // null = no old record (insert scenario)
Boolean matches = (Boolean)formula.evaluate(context);
```

**See Also:** [UTIL_FormulaFilter.INT_SObjectFormulaEvaluationContext](UTIL_FormulaFilter.INT_SObjectFormulaEvaluationContext.md)

---

## Fields

| Field | Description |
|-------|-------------|
| global [Opportunity](https://developer.salesforce.com/docs/atlas.en-us.object_reference.meta/object_reference/sforce_api_objects_opportunity.htm) [newRecord](#newrecord) | Opportunity record state AFTER DML (null on delete). |
| global [Opportunity](https://developer.salesforce.com/docs/atlas.en-us.object_reference.meta/object_reference/sforce_api_objects_opportunity.htm) [oldRecord](#oldrecord) | Opportunity record state BEFORE DML (null on insert). |

---

## Field Details

### newRecord

```apex
global Opportunity newRecord
```

**Type:** [Opportunity](https://developer.salesforce.com/docs/atlas.en-us.object_reference.meta/object_reference/sforce_api_objects_opportunity.htm)

Opportunity record state AFTER DML (null on delete).

**Since:** 1.0

**Example:**

```apex
Opportunity value = instance.newRecord;
```

### oldRecord

```apex
global Opportunity oldRecord
```

**Type:** [Opportunity](https://developer.salesforce.com/docs/atlas.en-us.object_reference.meta/object_reference/sforce_api_objects_opportunity.htm)

Opportunity record state BEFORE DML (null on insert).

**Since:** 1.0

**Example:**

```apex
Opportunity value = instance.oldRecord;
```

