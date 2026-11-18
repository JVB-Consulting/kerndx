---
title: "UTIL_FormulaContext.ApiCallContext"
type: class
pageClass: reference
description: "Formula evaluation context for ApiCall__c records, the records that log each API call. A context class is the class that gives a formula its values. This one gives a formula the API call record before"
group: "Utilities"
since: "1.12"
category: apex
---

# UTIL_FormulaContext.ApiCallContext

**Class** · Group: `Utilities`

<div class="apex-member apex-class">

```apex
global inherited sharing class UTIL_FormulaContext.ApiCallContext implements UTIL_FormulaFilter.INT_SObjectFormulaEvaluationContext
```

**Implements:** [UTIL_FormulaFilter.INT_SObjectFormulaEvaluationContext](UTIL_FormulaFilter.INT_SObjectFormulaEvaluationContext.md)

Formula evaluation context for ApiCall__c records, the records that log each API call. A context class is the class that gives a formula its values. This one gives a formula the API call record before and after the save, so a trigger action on ApiCall__c can use an entry formula. The Trigger Action Framework finds this class by itself when EntryCriteriaContextClassName__c is blank. You can also use it directly in your own Apex. Formula Variable Names: oldRecord, newRecord

**Example**

```apex
// Trigger Action Framework formulas:
// TEXT(newRecord.Status__c) = "Failed"
// TEXT(newRecord.Status__c) <> TEXT(oldRecord.Status__c)
// Direct Apex usage:
FormulaEval.FormulaInstance formula = Formula.builder()
    .withFormula('newRecord.ServiceName__c = \'MyService\'')
    .withReturnType(FormulaEval.FormulaReturnType.BOOLEAN)
    .withType(UTIL_FormulaContext.ApiCallContext.class)
    .build();
UTIL_FormulaContext.ApiCallContext context = new UTIL_FormulaContext.ApiCallContext();
context.setContext(null, apiCall); // null = no old record (insert scenario)
Boolean matches = (Boolean)formula.evaluate(context);
```

**See Also:** [UTIL_FormulaFilter.INT_SObjectFormulaEvaluationContext](UTIL_FormulaFilter.INT_SObjectFormulaEvaluationContext.md)

</div>

---

## Fields

| Field | Description |
|-------|-------------|
| global [ApiCall__c](../objects/ApiCall__c.md) [newRecord](#newrecord) | ApiCall__c record state AFTER DML (null on delete). |
| global [ApiCall__c](../objects/ApiCall__c.md) [oldRecord](#oldrecord) | ApiCall__c record state BEFORE DML (null on insert). |

### newRecord

```apex
global ApiCall__c newRecord
```

**Type:** [ApiCall__c](../objects/ApiCall__c.md)

ApiCall__c record state AFTER DML (null on delete).

**Example**

```apex
ApiCall__c value = instance.newRecord;
```

### oldRecord

```apex
global ApiCall__c oldRecord
```

**Type:** [ApiCall__c](../objects/ApiCall__c.md)

ApiCall__c record state BEFORE DML (null on insert).

**Example**

```apex
ApiCall__c value = instance.oldRecord;
```

