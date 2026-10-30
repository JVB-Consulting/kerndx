---
title: "UTIL_FormulaContext.FoobarBulkContext"
type: class
pageClass: reference
description: "For testing only. This class exists only so the framework's own tests can check that the preLoad() method of a context class runs before an entry formula or a validation rule is checked. It is not mea"
since: "1.10"
category: apex
---

# UTIL_FormulaContext.FoobarBulkContext

**Class**

<div class="apex-member apex-class">

```apex
global inherited sharing class UTIL_FormulaContext.FoobarBulkContext implements UTIL_FormulaFilter.INT_SObjectFormulaEvaluationContext, UTIL_ValidationRule.INT_BulkValidationContext
```

**Implements:** [UTIL_FormulaFilter.INT_SObjectFormulaEvaluationContext](UTIL_FormulaFilter.INT_SObjectFormulaEvaluationContext.md), [UTIL_ValidationRule.INT_BulkValidationContext](UTIL_ValidationRule.INT_BulkValidationContext.md)

For testing only. This class exists only so the framework's own tests can check that the preLoad() method of a context class runs before an entry formula or a validation rule is checked. It is not meant for your formulas or your validation rules. Its preLoad() runs a query each time it is called, so naming it in a trigger action or a validation rule would cost one query each time they run. A context class is the class that gives a formula its values. This one works on Foobar__c, the package's own test object. Like FoobarContext, it gives the formula the record before and after the save. It also has properties that only preLoad() fills, so a formula can tell whether preLoad() ran, how many times, and which lists it was given. Formula Variable Names: oldRecord, newRecord, preLoadRunCount, firstListSize, firstRecordName, secondListWasNull, savedFoobarCount

**Example**

```apex
// For the framework's own tests only. This formula is true only when preLoad() ran once and got a list of three records:
// preLoadRunCount = 1 && firstListSize = 3 && NOT(secondListWasNull)
UTIL_FormulaFilter filter = new UTIL_FormulaFilter(null, UTIL_FormulaContext.FoobarBulkContext.class.getName(), formula);
UTIL_FormulaFilter.DTO_FilterResults results = filter.filter(oldFoobars, newFoobars);
```

**See Also:** [UTIL_FormulaFilter.INT_SObjectFormulaEvaluationContext](UTIL_FormulaFilter.INT_SObjectFormulaEvaluationContext.md), [UTIL_ValidationRule.INT_BulkValidationContext](UTIL_ValidationRule.INT_BulkValidationContext.md), [UTIL_FormulaContext.FoobarContext](UTIL_FormulaContext.FoobarContext.md)

</div>

---

## Fields

| Field | Description |
|-------|-------------|
| global [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) [firstListSize](#firstlistsize) | How many records were in the first list that preLoad() was given. |
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [firstRecordName](#firstrecordname) | The name of the first record in the first list that preLoad() was given. |
| global [Foobar__c](../objects/Foobar__c.md) [newRecord](#newrecord) | The Foobar__c record after the save. |
| global [Foobar__c](../objects/Foobar__c.md) [oldRecord](#oldrecord) | The Foobar__c record before the save. |
| global [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) [preLoadRunCount](#preloadruncount) | How many times preLoad() ran since this class was created. |
| global [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) [savedFoobarCount](#savedfoobarcount) | How many Foobar__c records exist in the org and the running user can see when preLoad() last ran. |
| global [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) [secondListWasNull](#secondlistwasnull) | True when the second list that preLoad() was given was null. |

### firstListSize

```apex
global Integer firstListSize
```

**Type:** [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm)

How many records were in the first list that preLoad() was given. It stays zero when preLoad() never ran.

**Example**

```apex
Integer value = instance.firstListSize;
```

### firstRecordName

```apex
global String firstRecordName
```

**Type:** [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)

The name of the first record in the first list that preLoad() was given. It stays null when preLoad() never
ran or the list was empty.

**Example**

```apex
String value = instance.firstRecordName;
```

### newRecord

```apex
global Foobar__c newRecord
```

**Type:** [Foobar__c](../objects/Foobar__c.md)

The Foobar__c record after the save. It is null on a delete.

**Example**

```apex
Foobar__c value = instance.newRecord;
```

### oldRecord

```apex
global Foobar__c oldRecord
```

**Type:** [Foobar__c](../objects/Foobar__c.md)

The Foobar__c record before the save. It is null on an insert.

**Example**

```apex
Foobar__c value = instance.oldRecord;
```

### preLoadRunCount

```apex
global Integer preLoadRunCount
```

**Type:** [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm)

How many times preLoad() ran since this class was created. It stays zero when preLoad() never ran.

**Example**

```apex
Integer value = instance.preLoadRunCount;
```

### savedFoobarCount

```apex
global Integer savedFoobarCount
```

**Type:** [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm)

How many Foobar__c records exist in the org and the running user can see when preLoad() last ran. preLoad() reads it with one query,
so a test can count the queries a save uses. It stays zero when preLoad() never ran.

**Example**

```apex
Integer value = instance.savedFoobarCount;
```

### secondListWasNull

```apex
global Boolean secondListWasNull
```

**Type:** [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm)

True when the second list that preLoad() was given was null. It stays false when preLoad() never ran.

**Example**

```apex
Boolean value = instance.secondListWasNull;
```

