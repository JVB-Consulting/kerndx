---
title: "UTIL_FormulaFilter"
type: class
pageClass: reference
description: "Class that can filter list of SObject based on Formula Information provided adapted from:apex-trigger-actions-framework"
author: "Jason Van Beukering"
group: "Utilities"
date: "April 2025, May 2026"
since: "1.0"
category: apex
---

# UTIL_FormulaFilter

**Class** · Group: `Utilities`

```apex
global inherited sharing class UTIL_FormulaFilter
```

Class that can filter list of SObject based on Formula Information provided adapted from:apex-trigger-actions-framework

**Since:** 1.0

**Example:**

```apex
UTIL_FormulaFilter filter = new UTIL_FormulaFilter(
    'MyProcess', 'UTIL_FormulaContext.AccountContext', 'newRecord.Industry == "Technology"'
);
UTIL_FormulaFilter.DTO_FilterResults results = filter.filter(oldRecords, newRecords);
```

---

## Properties

| Property | Description |
|----------|-------------|
| global interface [INT_SObjectFormulaEvaluationContext](UTIL_FormulaFilter.INT_SObjectFormulaEvaluationContext.md) | Interface for providing context data to dynamic formula evaluations using Salesforce's FormulaEval namespace. |

## Methods

| Method | Description |
|--------|-------------|
| global [UTIL_FormulaFilter.DTO_FilterResults](UTIL_FormulaFilter.DTO_FilterResults.md) [filter](#filter)([List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm)> oldRecords, [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm)> newRecords) | Filters the given lists of new and old SObjects based on the entry criteria formula. |
| global  [UTIL_FormulaFilter](#util_formulafilter)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) processName, [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) contextClassName, [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) formula) | Constructs a new instance with the formula details |

## Inner Classes

| Class | Description |
|-------|-------------|
| [DTO_FilterResults](UTIL_FormulaFilter.DTO_FilterResults.md) | Inner class representing the result of the filter method. |

---

## Method Details

### UTIL_FormulaFilter

<div class="apex-member">

```apex
global UTIL_FormulaFilter(String processName, String contextClassName, String formula)
```

Constructs a new instance with the formula details

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `processName` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The name of the process calling the filter, will be used if an error is generated during process so logging will be specific |
| `contextClassName` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The class that will provide the relevant variables, context to the formula. |
| `formula` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The boolean formula to execute |

**Example**

```apex
UTIL_FormulaFilter instance = new UTIL_FormulaFilter('value', 'value', 'RecordType.Name = \'Default\'');
```

</div>

### filter

<div class="apex-member">

```apex
global UTIL_FormulaFilter.DTO_FilterResults filter(List<SObject> oldRecords, List<SObject> newRecords)
```

Filters the given lists of new and old SObjects based on the entry criteria formula.

This method evaluates the entry criteria formula for each record in the `triggerNew` and `triggerOld`.
If the formula evaluates to true for a record, it is included in the filtered lists.

*NOTE: Make sure that if both the old and new records lists are not null they are the same size*

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `oldRecords` | [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm) | The list of old SObjects to filter. |
| `newRecords` | [SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm) | The list of new SObjects to filter. |

**Returns** [UTIL_FormulaFilter.DTO_FilterResults](UTIL_FormulaFilter.DTO_FilterResults.md) — An object containing the filtered lists of new and old SObjects.

**Throws**

| Exception | Description |
|-----------|-------------|
| [Exception](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_classes_exception_methods.htm) | Exception could be thrown if the any of the formula build method's fail |

**Example**

```apex
DTO_FilterResults result = instance.filter(records, records);
```

</div>

