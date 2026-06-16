---
title: "UTIL_FormulaFilter.INT_SObjectFormulaEvaluationContext"
type: class
pageClass: reference
description: "Interface for providing context data to dynamic formula evaluations using Salesforce's FormulaEval namespace. Implementing classes supply the necessary context for evaluating formulas using SObjects."
since: "1.0"
category: apex
---

# UTIL_FormulaFilter.INT_SObjectFormulaEvaluationContext

**Class**

```apex
global interface UTIL_FormulaFilter.INT_SObjectFormulaEvaluationContext
```

**Known Derived Types:** [UTIL_FormulaContext.AccountContext](UTIL_FormulaContext.AccountContext.md), [UTIL_FormulaContext.CampaignContext](UTIL_FormulaContext.CampaignContext.md), [UTIL_FormulaContext.CaseContext](UTIL_FormulaContext.CaseContext.md), [UTIL_FormulaContext.ContactContext](UTIL_FormulaContext.ContactContext.md), [UTIL_FormulaContext.EventContext](UTIL_FormulaContext.EventContext.md), [UTIL_FormulaContext.FoobarContext](UTIL_FormulaContext.FoobarContext.md), [UTIL_FormulaContext.LeadContext](UTIL_FormulaContext.LeadContext.md), [UTIL_FormulaContext.OpportunityContext](UTIL_FormulaContext.OpportunityContext.md), [UTIL_FormulaContext.TaskContext](UTIL_FormulaContext.TaskContext.md), [UTIL_FormulaContext.UserContext](UTIL_FormulaContext.UserContext.md)

Interface for providing context data to dynamic formula evaluations using Salesforce's FormulaEval namespace. Implementing classes supply the necessary context for evaluating formulas using SObjects.

**Since:** 1.0

---

## Methods

| Method | Description |
|--------|-------------|
| global abstract void [setContext](#setcontext)([SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm) oldRecord, [SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm) newRecord) | Sets the context for formula evaluation by providing the current and previous states of the SObject record being processed. |

---

## Method Details

### setContext

<div class="apex-member">

```apex
global abstract void setContext(SObject oldRecord, SObject newRecord)
```

Sets the context for formula evaluation by providing the current and previous states of the SObject record being processed.
This method is invoked during trigger execution to supply the formula with relevant data for evaluation.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `oldRecord` | [SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm) | The state of the record before the DML operation. |
| `newRecord` | [SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm) | The state of the record after the DML operation. |

</div>

