---
title: "SEL_Hierarchy.Selector"
type: class
description: "Selector class that provides hierarchy operations for a specific SObject type. Created via SEL_Hierarchy.forField(parentField) - caches field metadata for efficient reuse."
since: "1.0"
category: apex
---

# SEL_Hierarchy.Selector

**Class**

```apex
global inherited sharing class SEL_Hierarchy.Selector
```

Selector class that provides hierarchy operations for a specific SObject type. Created via SEL_Hierarchy.forField(parentField) - caches field metadata for efficient reuse.

**Since:** 1.0

---

## Methods

| Method | Description |
|--------|-------------|
| global [Map](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_map.htm)<[Id](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_id.htm), [Id](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_id.htm)> [calculateUltimateParents](#calculateultimateparents)([Set](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_set.htm)<[Id](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_id.htm)> changedRecordIds, [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) includeDescendants) | Calculates ultimate parent values for records without performing DML. |
| global [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm)> [findAllAncestors](#findallancestors)([Id](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_id.htm) recordId) | Finds all ancestors (parents, grandparents, etc.) of a record. |
| global [Map](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_map.htm)<[Id](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_id.htm), [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm)>> [findAllAncestors](#findallancestors)([Set](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_set.htm)<[Id](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_id.htm)> recordIds) | Finds all ancestors for multiple records in a single bulkified operation. |
| global [Set](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_set.htm)<[Id](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_id.htm)> [findAllDescendants](#findalldescendants)([Id](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_id.htm) parentId) | Finds all descendants (children, grandchildren, etc.) of a record. |
| global [Set](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_set.htm)<[Id](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_id.htm)> [findAllDescendants](#findalldescendants)([Set](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_set.htm)<[Id](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_id.htm)> parentIds) | Finds all descendants for multiple parent records. |
| global [Id](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_id.htm) [findUltimateParent](#findultimateparent)([Id](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_id.htm) recordId) | Finds the ultimate parent (root ancestor) for a record. |
| global [Map](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_map.htm)<[Id](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_id.htm), [Id](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_id.htm)> [findUltimateParents](#findultimateparents)([Set](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_set.htm)<[Id](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_id.htm)> recordIds) | Finds ultimate parents for multiple records in a single bulkified operation. |
| global [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm)> [propagateToDescendants](#propagatetodescendants)([Set](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_set.htm)<[Id](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_id.htm)> changedRecordIds, [SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm) ultimateParentField) | Updates all descendants of changed records with the new ultimate parent reference. |
| global [SEL_Hierarchy.Selector](SEL_Hierarchy.Selector.md) [withMaxDepth](#withmaxdepth)([Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) depth) | Sets the maximum hierarchy depth for this selector. |

---

## Method Details

### calculateUltimateParents

```apex
global Map<Id, Id> calculateUltimateParents(Set<Id> changedRecordIds, Boolean includeDescendants)
```

Calculates ultimate parent values for records without performing DML.
Returns a map that can be used for updates or analysis.

**Parameters:**

- `changedRecordIds` ([Set](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_set.htm)) - Records whose parent has changed.
- `includeDescendants` ([Id](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_id.htm)) - Whether to include all descendants in the result.

**Returns:** [Id](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_id.htm) - Map of record Id to its ultimate parent Id.

**Since:** 1.0

**Example:**

```apex
Map<Id, Id> ultimateParents = SEL_Hierarchy.forField(Account.ParentId)
    .calculateUltimateParents(changedAccountIds, true);
```

### findAllAncestors

```apex
global List<SObject> findAllAncestors(Id recordId)
```

Finds all ancestors (parents, grandparents, etc.) of a record.
Returns ancestors ordered from immediate parent to ultimate parent (root).

**Parameters:**

- `recordId` ([Id](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_id.htm)) - The Id of the record to find ancestors for.

**Returns:** [SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm) - List of ancestor SObjects ordered from immediate parent to ultimate parent. Empty list if record has no parent.

**Since:** 1.0

**Example:**

```apex
// Account hierarchy: GrandChild -> Child -> Parent -> GrandParent (no parent)
List<Account> ancestors = (List<Account>)SEL_Hierarchy.forField(Account.ParentId)
    .findAllAncestors(grandChildAccountId);
// Returns: [Child, Parent, GrandParent] - ordered from closest to furthest
```

```apex
global Map<Id, List<SObject>> findAllAncestors(Set<Id> recordIds)
```

Finds all ancestors for multiple records in a single bulkified operation.

**Parameters:**

- `recordIds` ([Set](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_set.htm)) - Set of record Ids to find ancestors for.

**Returns:** [SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm) - Map of record Id to its list of ancestors. Each list is ordered from immediate parent to ultimate parent.

**Since:** 1.0

**Example:**

```apex
Set<Id> accountIds = new Set<Id>{acc1.Id, acc2.Id};
Map<Id, List<SObject>> ancestorsByRecord = SEL_Hierarchy.forField(Account.ParentId)
    .findAllAncestors(accountIds);
for(Id accountId : accountIds)
{
    List<SObject> ancestors = ancestorsByRecord.get(accountId);
    System.debug('Ancestors for ' + accountId + ': ' + ancestors);
}
```

### findAllDescendants

```apex
global Set<Id> findAllDescendants(Id parentId)
```

Finds all descendants (children, grandchildren, etc.) of a record.

**Parameters:**

- `parentId` ([Id](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_id.htm)) - The Id of the parent record.

**Returns:** [Id](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_id.htm) - Set of all descendant record Ids (does not include the parent).

**Since:** 1.0

**Example:**

```apex
Set<Id> allDescendants = SEL_Hierarchy.forField(Account.ParentId)
    .findAllDescendants(parentAccountId);
```

```apex
global Set<Id> findAllDescendants(Set<Id> parentIds)
```

Finds all descendants for multiple parent records.

**Parameters:**

- `parentIds` ([Set](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_set.htm)) - Set of parent record Ids.

**Returns:** [Id](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_id.htm) - Set of all descendant record Ids (does not include the parent Ids).

**Since:** 1.0

**Example:**

```apex
Set<Id> parentIds = new Set<Id>{parent1.Id, parent2.Id};
Set<Id> allDescendants = SEL_Hierarchy.forField(Account.ParentId)
    .findAllDescendants(parentIds);
```

### findUltimateParent

```apex
global Id findUltimateParent(Id recordId)
```

Finds the ultimate parent (root ancestor) for a record.
Traverses up the hierarchy until a record with no parent is found.

**Parameters:**

- `recordId` ([Id](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_id.htm)) - The Id of the record to find the ultimate parent for.

**Returns:** [Id](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_id.htm) - The Id of the ultimate parent, or the record's own Id if it has no parent.

**Since:** 1.0

**Example:**

```apex
// Account hierarchy: GrandChild -> Child -> Parent -> GrandParent (no parent)
Id ultimateParent = SEL_Hierarchy.forField(Account.ParentId)
    .findUltimateParent(grandChildAccountId);
// Returns: GrandParent's Id
```

### findUltimateParents

```apex
global Map<Id, Id> findUltimateParents(Set<Id> recordIds)
```

Finds ultimate parents for multiple records in a single bulkified operation.
Optimizes SOQL by querying in batches and traversing multiple parent levels per query.

**Parameters:**

- `recordIds` ([Set](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_set.htm)) - Set of record Ids to find ultimate parents for.

**Returns:** [Id](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_id.htm) - Map of record Id to its ultimate parent Id. Records with no parent map to themselves.

**Since:** 1.0

**Example:**

```apex
Set<Id> accountIds = new Set<Id>{acc1.Id, acc2.Id, acc3.Id};
Map<Id, Id> ultimateParents = SEL_Hierarchy.forField(Account.ParentId)
    .findUltimateParents(accountIds);
for(Id accountId : accountIds)
{
    System.debug('Ultimate parent: ' + ultimateParents.get(accountId));
}
```

### propagateToDescendants

```apex
global List<SObject> propagateToDescendants(Set<Id> changedRecordIds, SObjectField ultimateParentField)
```

Updates all descendants of changed records with the new ultimate parent reference.
Typically used in trigger context when a record's parent changes.

**Use Case:** When Account A's parent changes, all of A's children (and their children)
need their UltimateParent__c field updated to point to A's new ultimate parent.

**Parameters:**

- `changedRecordIds` ([Set](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_set.htm)) - Records whose parent has changed.
- `ultimateParentField` ([Id](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_id.htm)) - The field to store the ultimate parent reference.

**Returns:** [SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm) - List of updated records (not yet committed to database).

**Since:** 1.0

**Example:**

```apex
// In a trigger action when parent changes:
List<SObject> updates = SEL_Hierarchy.forField(Account.ParentId)
    .propagateToDescendants(changedAccountIds, Account.UltimateParent__c);
update updates;
```

### withMaxDepth

```apex
global SEL_Hierarchy.Selector withMaxDepth(Integer depth)
```

Sets the maximum hierarchy depth for this selector.
Useful for limiting traversal in known shallow hierarchies or testing.

**Parameters:**

- `depth` ([Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm)) - Maximum levels to traverse.

**Returns:** [SEL_Hierarchy.Selector](SEL_Hierarchy.Selector.md) - This selector for method chaining.

**Since:** 1.0

**Example:**

```apex
SEL_Hierarchy.Selector hierarchy = SEL_Hierarchy.forField(Account.ParentId)
    .withMaxDepth(10);
```

