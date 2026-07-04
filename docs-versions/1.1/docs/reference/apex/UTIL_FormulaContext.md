---
title: "UTIL_FormulaContext"
type: class
description: "Container for pre-built formula evaluation context classes for standard Salesforce objects.  This class provides typed context implementations for Salesforce's `FormulaEval` namespace, enabling dynami"
author: "Jason Van Beukering"
group: "Utilities"
date: "January 2026, May 2026"
since: "1.0"
category: apex
---

# UTIL_FormulaContext

**Class** · Group: `Utilities`

```apex
global inherited sharing class UTIL_FormulaContext
```

Container for pre-built formula evaluation context classes for standard Salesforce objects.

This class provides typed context implementations for Salesforce's `FormulaEval` namespace,
enabling dynamic formula evaluation against standard object records. These contexts can be used
in any scenario requiring formula evaluation, including but not limited to:

    - **Trigger Action Framework** - Entry criteria formulas on `TriggerAction__mdt`

    - **Custom Business Rules** - Configurable filtering or validation logic

    - **Flow Extensions** - Dynamic formula evaluation in Apex-backed Flow actions

    - **Batch Processing** - Record filtering based on formula criteria

**Supported Objects:** Account, Contact, Lead, Opportunity, Case, Campaign, Task, Event, User, Foobar__c (test object)

**Formula Variable Names:**

    - `oldRecord` - Record state BEFORE an operation (null when no prior state exists)

    - `newRecord` - Record state AFTER an operation (null when record is being removed)

Inner classes are GLOBAL because Salesforce `FormulaEval.FormulaInstance.evaluate()`
requires runtime access to context properties. The `global` visibility ensures
cross-namespace access when the managed package evaluates formulas in subscriber orgs.

**Why global visibility is required:**

    - Member variables must be accessible by FormulaEval at runtime

    - For managed packages, `global` guarantees visibility across all scenarios

    - Subscriber org context classes must also use `global` for the same reason

**Since:** 1.0

**Example:**

```apex
// Direct usage with Formula.builder()
FormulaEval.FormulaInstance formula = Formula.builder()
    .withFormula('newRecord.AnnualRevenue > 1000000 && newRecord.Industry = "Technology"')
    .withReturnType(FormulaEval.FormulaReturnType.BOOLEAN)
    .withType(UTIL_FormulaContext.AccountContext.class)
    .build();
UTIL_FormulaContext.AccountContext context = new UTIL_FormulaContext.AccountContext();
context.setContext(null, account);
Boolean matches = (Boolean)formula.evaluate(context);
```

**See Also:** [UTIL_FormulaFilter](UTIL_FormulaFilter.md), [UTIL_FormulaFilter.INT_SObjectFormulaEvaluationContext](UTIL_FormulaFilter.INT_SObjectFormulaEvaluationContext.md), [FormulaEval.FormulaInstance](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_formulaeval_FormulaInstance.htm)

---

## Inner Classes

| Class | Description |
|-------|-------------|
| [AccountContext](UTIL_FormulaContext.AccountContext.md) | Formula evaluation context for Account object. |
| [CampaignContext](UTIL_FormulaContext.CampaignContext.md) | Formula evaluation context for Campaign object. |
| [CaseContext](UTIL_FormulaContext.CaseContext.md) | Formula evaluation context for Case object. |
| [ContactContext](UTIL_FormulaContext.ContactContext.md) | Formula evaluation context for Contact object. |
| [EventContext](UTIL_FormulaContext.EventContext.md) | Formula evaluation context for Event object. |
| [FoobarContext](UTIL_FormulaContext.FoobarContext.md) | Formula evaluation context for Foobar__c test object. |
| [LeadContext](UTIL_FormulaContext.LeadContext.md) | Formula evaluation context for Lead object. |
| [OpportunityContext](UTIL_FormulaContext.OpportunityContext.md) | Formula evaluation context for Opportunity object. |
| [TaskContext](UTIL_FormulaContext.TaskContext.md) | Formula evaluation context for Task object. |
| [UserContext](UTIL_FormulaContext.UserContext.md) | Formula evaluation context for User object. |

