---
title: "UTIL_FormulaContext.UserContext"
type: class
pageClass: reference
description: "Formula evaluation context for User object. Provides typed access to User records in formula evaluations. Auto-detected by Trigger Action Framework when EntryCriteriaContextClassName__c is blank. Can "
since: "1.0"
category: apex
---

# UTIL_FormulaContext.UserContext

**Class**

```apex
global inherited sharing class UTIL_FormulaContext.UserContext implements UTIL_FormulaFilter.INT_SObjectFormulaEvaluationContext
```

**Implements:** [UTIL_FormulaFilter.INT_SObjectFormulaEvaluationContext](UTIL_FormulaFilter.INT_SObjectFormulaEvaluationContext.md)

Formula evaluation context for User object. Provides typed access to User records in formula evaluations. Auto-detected by Trigger Action Framework when EntryCriteriaContextClassName__c is blank. Can also be used directly in custom Apex. Note: Class is named UserContext because User is an Apex reserved keyword. Formula Variable Names: oldRecord, newRecord

**Since:** 1.0

**Example:**

```apex
// Trigger Action Framework formulas:
// newRecord.IsActive <> oldRecord.IsActive
// newRecord.ProfileId <> oldRecord.ProfileId
// Direct Apex usage:
FormulaEval.FormulaInstance formula = Formula.builder()
    .withFormula('newRecord.IsActive && newRecord.ReceivesAdminInfoEmails')
    .withReturnType(FormulaEval.FormulaReturnType.BOOLEAN)
    .withType(UTIL_FormulaContext.UserContext.class)
    .build();
UTIL_FormulaContext.UserContext context = new UTIL_FormulaContext.UserContext();
context.setContext(null, userRecord); // null = no old record (insert scenario)
Boolean matches = (Boolean)formula.evaluate(context);
```

**See Also:** [UTIL_FormulaFilter.INT_SObjectFormulaEvaluationContext](UTIL_FormulaFilter.INT_SObjectFormulaEvaluationContext.md)

---

## Fields

| Field | Description |
|-------|-------------|
| global [User](https://developer.salesforce.com/docs/atlas.en-us.object_reference.meta/object_reference/sforce_api_objects_user.htm) [newRecord](#newrecord) | User record state AFTER DML (null on delete). |
| global [User](https://developer.salesforce.com/docs/atlas.en-us.object_reference.meta/object_reference/sforce_api_objects_user.htm) [oldRecord](#oldrecord) | User record state BEFORE DML (null on insert). |

---

## Field Details

### newRecord

```apex
global User newRecord
```

**Type:** [User](https://developer.salesforce.com/docs/atlas.en-us.object_reference.meta/object_reference/sforce_api_objects_user.htm)

User record state AFTER DML (null on delete).

**Since:** 1.0

**Example:**

```apex
User value = instance.newRecord;
```

### oldRecord

```apex
global User oldRecord
```

**Type:** [User](https://developer.salesforce.com/docs/atlas.en-us.object_reference.meta/object_reference/sforce_api_objects_user.htm)

User record state BEFORE DML (null on insert).

**Since:** 1.0

**Example:**

```apex
User value = instance.oldRecord;
```

