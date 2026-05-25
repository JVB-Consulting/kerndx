---
title: "UTIL_FormulaContext.FoobarContext"
type: class
description: "Formula evaluation context for Foobar__c test object. Provides typed access to Foobar__c records in formula evaluations. This context class enables comprehensive testing of formula evaluation function"
since: "1.0"
category: apex
---

# UTIL_FormulaContext.FoobarContext

**Class**

```apex
global inherited sharing class UTIL_FormulaContext.FoobarContext implements UTIL_FormulaFilter.INT_SObjectFormulaEvaluationContext
```

**Implements:** [UTIL_FormulaFilter.INT_SObjectFormulaEvaluationContext](UTIL_FormulaFilter.INT_SObjectFormulaEvaluationContext.md)

Formula evaluation context for Foobar__c test object. Provides typed access to Foobar__c records in formula evaluations. This context class enables comprehensive testing of formula evaluation functionality within the managed package without requiring subscriber-created classes. Auto-detected by Trigger Action Framework when EntryCriteriaContextClassName__c is blank. Can also be used directly in custom Apex for testing purposes. Formula Variable Names: oldRecord, newRecord

**Since:** 1.0

**Example:**

```apex
// Trigger Action Framework formulas:
// newRecord.Checkbox__c = true
// newRecord.NumberInteger__c > oldRecord.NumberInteger__c
// newRecord.Picklist__c <> oldRecord.Picklist__c
// Direct Apex usage:
FormulaEval.FormulaInstance formula = Formula.builder()
    .withFormula('newRecord.Checkbox__c && newRecord.NumberInteger__c > 100')
    .withReturnType(FormulaEval.FormulaReturnType.BOOLEAN)
    .withType(UTIL_FormulaContext.FoobarContext.class)
    .build();
UTIL_FormulaContext.FoobarContext context = new UTIL_FormulaContext.FoobarContext();
context.setContext(null, foobar); // null = no old record (insert scenario)
Boolean matches = (Boolean)formula.evaluate(context);
```

**See Also:** [UTIL_FormulaFilter.INT_SObjectFormulaEvaluationContext](UTIL_FormulaFilter.INT_SObjectFormulaEvaluationContext.md)

---

## Fields

| Field | Description |
|-------|-------------|
| global [Foobar__c](../objects/Foobar__c.md) [newRecord](#newrecord) | Foobar__c record state AFTER DML (null on delete). |
| global [Foobar__c](../objects/Foobar__c.md) [oldRecord](#oldrecord) | Foobar__c record state BEFORE DML (null on insert). |

---

## Field Details

### newRecord

```apex
global Foobar__c newRecord
```

**Type:** [Foobar__c](../objects/Foobar__c.md)

Foobar__c record state AFTER DML (null on delete).

**Since:** 1.0

**Example:**

```apex
Foobar__c value = instance.newRecord;
```

### oldRecord

```apex
global Foobar__c oldRecord
```

**Type:** [Foobar__c](../objects/Foobar__c.md)

Foobar__c record state BEFORE DML (null on insert).

**Since:** 1.0

**Example:**

```apex
Foobar__c value = instance.oldRecord;
```

