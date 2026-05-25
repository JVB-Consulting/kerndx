---
title: "UTIL_FormulaContext.ContactContext"
type: class
description: "Formula evaluation context for Contact object. Provides typed access to Contact records in formula evaluations. Auto-detected by Trigger Action Framework when EntryCriteriaContextClassName__c is blank"
since: "1.0"
category: apex
---

# UTIL_FormulaContext.ContactContext

**Class**

```apex
global inherited sharing class UTIL_FormulaContext.ContactContext implements UTIL_FormulaFilter.INT_SObjectFormulaEvaluationContext
```

**Implements:** [UTIL_FormulaFilter.INT_SObjectFormulaEvaluationContext](UTIL_FormulaFilter.INT_SObjectFormulaEvaluationContext.md)

Formula evaluation context for Contact object. Provides typed access to Contact records in formula evaluations. Auto-detected by Trigger Action Framework when EntryCriteriaContextClassName__c is blank. Can also be used directly in custom Apex. Formula Variable Names: oldRecord, newRecord

**Since:** 1.0

**Example:**

```apex
// Trigger Action Framework formulas:
// newRecord.Email <> oldRecord.Email
// ISBLANK(oldRecord.AccountId) && NOT(ISBLANK(newRecord.AccountId))
// Direct Apex usage:
FormulaEval.FormulaInstance formula = Formula.builder()
    .withFormula('newRecord.HasOptedOutOfEmail = false')
    .withReturnType(FormulaEval.FormulaReturnType.BOOLEAN)
    .withType(UTIL_FormulaContext.ContactContext.class)
    .build();
UTIL_FormulaContext.ContactContext context = new UTIL_FormulaContext.ContactContext();
context.setContext(null, contact); // null = no old record (insert scenario)
Boolean matches = (Boolean)formula.evaluate(context);
```

**See Also:** [UTIL_FormulaFilter.INT_SObjectFormulaEvaluationContext](UTIL_FormulaFilter.INT_SObjectFormulaEvaluationContext.md)

---

## Fields

| Field | Description |
|-------|-------------|
| global [Contact](https://developer.salesforce.com/docs/atlas.en-us.object_reference.meta/object_reference/sforce_api_objects_contact.htm) [newRecord](#newrecord) | Contact record state AFTER DML (null on delete). |
| global [Contact](https://developer.salesforce.com/docs/atlas.en-us.object_reference.meta/object_reference/sforce_api_objects_contact.htm) [oldRecord](#oldrecord) | Contact record state BEFORE DML (null on insert). |

---

## Field Details

### newRecord

```apex
global Contact newRecord
```

**Type:** [Contact](https://developer.salesforce.com/docs/atlas.en-us.object_reference.meta/object_reference/sforce_api_objects_contact.htm)

Contact record state AFTER DML (null on delete).

**Since:** 1.0

**Example:**

```apex
Contact value = instance.newRecord;
```

### oldRecord

```apex
global Contact oldRecord
```

**Type:** [Contact](https://developer.salesforce.com/docs/atlas.en-us.object_reference.meta/object_reference/sforce_api_objects_contact.htm)

Contact record state BEFORE DML (null on insert).

**Since:** 1.0

**Example:**

```apex
Contact value = instance.oldRecord;
```

