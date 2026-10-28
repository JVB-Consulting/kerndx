---
title: "UTIL_FormulaContext.LeadContext"
type: class
pageClass: reference
description: "Formula evaluation context for Lead object. Provides typed access to Lead records in formula evaluations. Auto-detected by Trigger Action Framework when EntryCriteriaContextClassName__c is blank. Can "
since: "1.0"
category: apex
---

# UTIL_FormulaContext.LeadContext

**Class**

<div class="apex-member apex-class">

```apex
global inherited sharing class UTIL_FormulaContext.LeadContext implements UTIL_FormulaFilter.INT_SObjectFormulaEvaluationContext
```

**Implements:** [UTIL_FormulaFilter.INT_SObjectFormulaEvaluationContext](UTIL_FormulaFilter.INT_SObjectFormulaEvaluationContext.md)

Formula evaluation context for Lead object. Provides typed access to Lead records in formula evaluations. Auto-detected by Trigger Action Framework when EntryCriteriaContextClassName__c is blank. Can also be used directly in custom Apex. Formula Variable Names: oldRecord, newRecord

**Example**

```apex
// Trigger Action Framework formulas:
// newRecord.Status = "Working"
// newRecord.LeadSource <> oldRecord.LeadSource
// Direct Apex usage:
FormulaEval.FormulaInstance formula = Formula.builder()
    .withFormula('newRecord.IsConverted = false && newRecord.Status = "Qualified"')
    .withReturnType(FormulaEval.FormulaReturnType.BOOLEAN)
    .withType(UTIL_FormulaContext.LeadContext.class)
    .build();
UTIL_FormulaContext.LeadContext context = new UTIL_FormulaContext.LeadContext();
context.setContext(null, lead); // null = no old record (insert scenario)
Boolean matches = (Boolean)formula.evaluate(context);
```

**See Also:** [UTIL_FormulaFilter.INT_SObjectFormulaEvaluationContext](UTIL_FormulaFilter.INT_SObjectFormulaEvaluationContext.md)

</div>

---

## Fields

| Field | Description |
|-------|-------------|
| global [Lead](https://developer.salesforce.com/docs/atlas.en-us.object_reference.meta/object_reference/sforce_api_objects_lead.htm) [newRecord](#newrecord) | Lead record state AFTER DML (null on delete). |
| global [Lead](https://developer.salesforce.com/docs/atlas.en-us.object_reference.meta/object_reference/sforce_api_objects_lead.htm) [oldRecord](#oldrecord) | Lead record state BEFORE DML (null on insert). |

### newRecord

```apex
global Lead newRecord
```

**Type:** [Lead](https://developer.salesforce.com/docs/atlas.en-us.object_reference.meta/object_reference/sforce_api_objects_lead.htm)

Lead record state AFTER DML (null on delete).

**Example**

```apex
Lead value = instance.newRecord;
```

### oldRecord

```apex
global Lead oldRecord
```

**Type:** [Lead](https://developer.salesforce.com/docs/atlas.en-us.object_reference.meta/object_reference/sforce_api_objects_lead.htm)

Lead record state BEFORE DML (null on insert).

**Example**

```apex
Lead value = instance.oldRecord;
```

