---
title: "UTIL_FormulaContext.AccountContext"
type: class
pageClass: reference
description: "Formula evaluation context for Account object.  Provides typed access to Account records in formula evaluations. The Trigger Action Framework automatically uses this context when `EntryCriteriaContext"
since: "1.0"
category: apex
---

# UTIL_FormulaContext.AccountContext

**Class**

```apex
global inherited sharing class UTIL_FormulaContext.AccountContext implements UTIL_FormulaFilter.INT_SObjectFormulaEvaluationContext
```

**Implements:** [UTIL_FormulaFilter.INT_SObjectFormulaEvaluationContext](UTIL_FormulaFilter.INT_SObjectFormulaEvaluationContext.md)

Formula evaluation context for Account object.

Provides typed access to Account records in formula evaluations.
The Trigger Action Framework automatically uses this context when `EntryCriteriaContextClassName__c`
is blank on `TriggerAction__mdt` records for the Account object. This context can also be used
directly in custom Apex code for any formula evaluation scenario.

**Formula Variable Names:**

    - `oldRecord` - Account state before DML (null on insert)

    - `newRecord` - Account state after DML

**Since:** 1.0

**Example:**

```apex
// --- Trigger Action Framework Usage ---
// TriggerAction__mdt.EntryCriteriaFormula__c examples:
// newRecord.Type = "Customer"
// newRecord.Industry <> oldRecord.Industry
// AND(newRecord.AnnualRevenue > 1000000, newRecord.Type = "Customer")
// --- Direct Apex Usage (Batch, Validation, Custom Business Rules) ---
FormulaEval.FormulaInstance formula = Formula.builder()
    .withFormula('newRecord.AnnualRevenue > 1000000 && newRecord.Industry = "Technology"')
    .withReturnType(FormulaEval.FormulaReturnType.BOOLEAN)
    .withType(UTIL_FormulaContext.AccountContext.class)
    .build();
UTIL_FormulaContext.AccountContext context = new UTIL_FormulaContext.AccountContext();
for(Account account : accounts)
{
    context.setContext(null, account);
    if((Boolean)formula.evaluate(context))
    {
        // Account matches criteria
    }
}
```

**See Also:** [UTIL_FormulaFilter.INT_SObjectFormulaEvaluationContext](UTIL_FormulaFilter.INT_SObjectFormulaEvaluationContext.md)

---

## Fields

| Field | Description |
|-------|-------------|
| global [Account](https://developer.salesforce.com/docs/atlas.en-us.object_reference.meta/object_reference/sforce_api_objects_account.htm) [newRecord](#newrecord) | The Account record state AFTER the DML operation. |
| global [Account](https://developer.salesforce.com/docs/atlas.en-us.object_reference.meta/object_reference/sforce_api_objects_account.htm) [oldRecord](#oldrecord) | The Account record state BEFORE the DML operation. |

---

## Field Details

### newRecord

```apex
global Account newRecord
```

**Type:** [Account](https://developer.salesforce.com/docs/atlas.en-us.object_reference.meta/object_reference/sforce_api_objects_account.htm)

The Account record state AFTER the DML operation.
Contains the record with all field values as they will be saved to the database.

**Since:** 1.0

**Example:**

```apex
Account value = instance.newRecord;
```

### oldRecord

```apex
global Account oldRecord
```

**Type:** [Account](https://developer.salesforce.com/docs/atlas.en-us.object_reference.meta/object_reference/sforce_api_objects_account.htm)

The Account record state BEFORE the DML operation.
This property is null during insert operations since no prior record exists.
Use oldRecord.Id = null in formulas to detect insert operations.

**Since:** 1.0

**Example:**

```apex
Account value = instance.oldRecord;
```

