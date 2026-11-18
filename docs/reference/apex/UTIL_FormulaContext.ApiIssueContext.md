---
title: "UTIL_FormulaContext.ApiIssueContext"
type: class
pageClass: reference
description: "Formula evaluation context for ApiIssue__c records, the records that log each failed API call. A context class is the class that gives a formula its values. This one gives a formula the API issue reco"
group: "Utilities"
since: "1.12"
category: apex
---

# UTIL_FormulaContext.ApiIssueContext

**Class** · Group: `Utilities`

<div class="apex-member apex-class">

```apex
global inherited sharing class UTIL_FormulaContext.ApiIssueContext implements UTIL_FormulaFilter.INT_SObjectFormulaEvaluationContext
```

**Implements:** [UTIL_FormulaFilter.INT_SObjectFormulaEvaluationContext](UTIL_FormulaFilter.INT_SObjectFormulaEvaluationContext.md)

Formula evaluation context for ApiIssue__c records, the records that log each failed API call. A context class is the class that gives a formula its values. This one gives a formula the API issue record before and after the save, so a trigger action on ApiIssue__c can use an entry formula. The Trigger Action Framework finds this class by itself when EntryCriteriaContextClassName__c is blank. You can also use it directly in your own Apex. Formula Variable Names: oldRecord, newRecord

**Example**

```apex
// Trigger Action Framework formulas:
// TEXT(newRecord.Status__c) = "Open"
// TEXT(newRecord.Status__c) <> TEXT(oldRecord.Status__c)
// Direct Apex usage:
FormulaEval.FormulaInstance formula = Formula.builder()
    .withFormula('newRecord.ServiceName__c = \'MyService\'')
    .withReturnType(FormulaEval.FormulaReturnType.BOOLEAN)
    .withType(UTIL_FormulaContext.ApiIssueContext.class)
    .build();
UTIL_FormulaContext.ApiIssueContext context = new UTIL_FormulaContext.ApiIssueContext();
context.setContext(null, apiIssue); // null = no old record (insert scenario)
Boolean matches = (Boolean)formula.evaluate(context);
```

**See Also:** [UTIL_FormulaFilter.INT_SObjectFormulaEvaluationContext](UTIL_FormulaFilter.INT_SObjectFormulaEvaluationContext.md)

</div>

---

## Fields

| Field | Description |
|-------|-------------|
| global [ApiIssue__c](../objects/ApiIssue__c.md) [newRecord](#newrecord) | ApiIssue__c record state AFTER DML (null on delete). |
| global [ApiIssue__c](../objects/ApiIssue__c.md) [oldRecord](#oldrecord) | ApiIssue__c record state BEFORE DML (null on insert). |

### newRecord

```apex
global ApiIssue__c newRecord
```

**Type:** [ApiIssue__c](../objects/ApiIssue__c.md)

ApiIssue__c record state AFTER DML (null on delete).

**Example**

```apex
ApiIssue__c value = instance.newRecord;
```

### oldRecord

```apex
global ApiIssue__c oldRecord
```

**Type:** [ApiIssue__c](../objects/ApiIssue__c.md)

ApiIssue__c record state BEFORE DML (null on insert).

**Example**

```apex
ApiIssue__c value = instance.oldRecord;
```

