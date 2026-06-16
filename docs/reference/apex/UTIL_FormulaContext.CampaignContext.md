---
title: "UTIL_FormulaContext.CampaignContext"
type: class
pageClass: reference
description: "Formula evaluation context for Campaign object. Provides typed access to Campaign records in formula evaluations. Auto-detected by Trigger Action Framework when EntryCriteriaContextClassName__c is bla"
since: "1.0"
category: apex
---

# UTIL_FormulaContext.CampaignContext

**Class**

<div class="apex-member apex-class">

```apex
global inherited sharing class UTIL_FormulaContext.CampaignContext implements UTIL_FormulaFilter.INT_SObjectFormulaEvaluationContext
```

**Implements:** [UTIL_FormulaFilter.INT_SObjectFormulaEvaluationContext](UTIL_FormulaFilter.INT_SObjectFormulaEvaluationContext.md)

Formula evaluation context for Campaign object. Provides typed access to Campaign records in formula evaluations. Auto-detected by Trigger Action Framework when EntryCriteriaContextClassName__c is blank. Can also be used directly in custom Apex. Formula Variable Names: oldRecord, newRecord

**Example**

```apex
// Trigger Action Framework formulas:
// newRecord.IsActive = true
// newRecord.Status <> oldRecord.Status
// Direct Apex usage:
FormulaEval.FormulaInstance formula = Formula.builder()
    .withFormula('newRecord.IsActive && newRecord.Type = "Email"')
    .withReturnType(FormulaEval.FormulaReturnType.BOOLEAN)
    .withType(UTIL_FormulaContext.CampaignContext.class)
    .build();
UTIL_FormulaContext.CampaignContext context = new UTIL_FormulaContext.CampaignContext();
context.setContext(null, campaign); // null = no old record (insert scenario)
Boolean matches = (Boolean)formula.evaluate(context);
```

**See Also:** [UTIL_FormulaFilter.INT_SObjectFormulaEvaluationContext](UTIL_FormulaFilter.INT_SObjectFormulaEvaluationContext.md)

</div>

---

## Fields

| Field | Description |
|-------|-------------|
| global [Campaign](https://developer.salesforce.com/docs/atlas.en-us.object_reference.meta/object_reference/sforce_api_objects_campaign.htm) [newRecord](#newrecord) | Campaign record state AFTER DML (null on delete). |
| global [Campaign](https://developer.salesforce.com/docs/atlas.en-us.object_reference.meta/object_reference/sforce_api_objects_campaign.htm) [oldRecord](#oldrecord) | Campaign record state BEFORE DML (null on insert). |

---

## Field Details

### newRecord

```apex
global Campaign newRecord
```

**Type:** [Campaign](https://developer.salesforce.com/docs/atlas.en-us.object_reference.meta/object_reference/sforce_api_objects_campaign.htm)

Campaign record state AFTER DML (null on delete).

**Example**

```apex
Campaign value = instance.newRecord;
```

### oldRecord

```apex
global Campaign oldRecord
```

**Type:** [Campaign](https://developer.salesforce.com/docs/atlas.en-us.object_reference.meta/object_reference/sforce_api_objects_campaign.htm)

Campaign record state BEFORE DML (null on insert).

**Example**

```apex
Campaign value = instance.oldRecord;
```

