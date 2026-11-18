---
title: "UTIL_FormulaFilter.DTO_FilterResults"
type: class
pageClass: reference
description: "Inner class representing the result of the filter method."
since: "1.0"
category: apex
---

# UTIL_FormulaFilter.DTO_FilterResults

**Class**

<div class="apex-member apex-class">

```apex
global inherited sharing class UTIL_FormulaFilter.DTO_FilterResults
```

Inner class representing the result of the filter method.

**See Also:** [UTIL_FormulaFilter.filter](UTIL_FormulaFilter.md#filter)

</div>

---

## Properties

| Property | Description |
|----------|-------------|
| global [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm)> [newRecords](#newrecords) | The new versions of the records that matched the formula, in the order you passed them. |
| global [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm)> [oldRecords](#oldrecords) | The old versions of the records that matched the formula, in the order you passed them. |

### newRecords

```apex
global List<SObject> newRecords
```

**Type:** [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)

The new versions of the records that matched the formula, in the order you passed them. When the
filter has no formula or no context class, it is the new list you passed in, unchanged. It is never null: an
empty list is returned instead.

### oldRecords

```apex
global List<SObject> oldRecords
```

**Type:** [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)

The old versions of the records that matched the formula, in the order you passed them. When the
filter has no formula or no context class, it is the old list you passed in, unchanged. It is never null: an
empty list is returned instead.

