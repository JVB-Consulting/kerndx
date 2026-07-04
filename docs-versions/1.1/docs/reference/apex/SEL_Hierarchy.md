---
title: "SEL_Hierarchy"
type: class
description: "Data Access Layer for managing self-referencing hierarchical relationships. Provides methods to traverse hierarchies, find ultimate parents (root ancestors), and propagate updates to descendants.  Wor"
author: "Jason Van Beukering"
group: "Selectors"
date: "January 2026, June 2026"
since: "1.0"
category: apex
---

# SEL_Hierarchy

**Class** · Group: `Selectors`

```apex
global inherited sharing class SEL_Hierarchy
```

Data Access Layer for managing self-referencing hierarchical relationships.
Provides methods to traverse hierarchies, find ultimate parents (root ancestors), and propagate
updates to descendants.

Works with any SObject that has a self-referencing lookup field (e.g., Account.ParentId).

**Performance Optimizations:**

    - Queries up to 5 parent levels per SOQL (Salesforce maximum)

    - Bulkified operations minimize query count

    - Caches field metadata within Selector instance

    - Uses efficient Map-based lookups over iterations

**Since:** 1.0

**Example:**

```apex
// Simple usage - find ultimate parent
Id ultimateParent = SEL_Hierarchy.forField(Account.ParentId)
    .findUltimateParent(childAccountId);
// Reusable selector for multiple operations
SEL_Hierarchy.Selector accountHierarchy = SEL_Hierarchy.forField(Account.ParentId);
Id root = accountHierarchy.findUltimateParent(accountId);
Set<Id> children = accountHierarchy.findAllDescendants(root);
// Bulk operation
Map<Id, Id> ultimateParents = accountHierarchy.findUltimateParents(accountIds);
// Propagate ultimate parent to descendants (for trigger context)
List<SObject> updates = accountHierarchy.propagateToDescendants
(
    changedAccountIds,
    Account.UltimateParent__c
);
update updates;
```

---

## Methods

| Method | Description |
|--------|-------------|
| global static [SEL_Hierarchy.Selector](SEL_Hierarchy.Selector.md) [forField](#forfield)([SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm) parentField) | Creates a Selector for hierarchy operations using the specified parent field. |

## Inner Classes

| Class | Description |
|-------|-------------|
| [Selector](SEL_Hierarchy.Selector.md) | Selector class that provides hierarchy operations for a specific SObject type. |

---

## Method Details

### forField

```apex
global static SEL_Hierarchy.Selector forField(SObjectField parentField)
```

Creates a Selector for hierarchy operations using the specified parent field.
The SObjectType is automatically inferred from the field.

**Parameters:**

- `parentField` ([SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm)) - The self-referencing lookup field (e.g., Account.ParentId).

**Returns:** [SEL_Hierarchy.Selector](SEL_Hierarchy.Selector.md) - A configured Selector ready for hierarchy operations.

**Since:** 1.0

**Example:**

```apex
// Simple one-liner
Id ultimateParent = SEL_Hierarchy.forField(Account.ParentId).findUltimateParent(accountId);
// Reusable selector
SEL_Hierarchy.Selector accountHierarchy = SEL_Hierarchy.forField(Account.ParentId);
Id root = accountHierarchy.findUltimateParent(childId);
Set<Id> descendants = accountHierarchy.findAllDescendants(root);
```

