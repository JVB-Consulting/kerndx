---
title: "IF_Trigger.PostActionContext"
type: class
pageClass: reference
description: "Context handed to a post-trigger action when the dispatcher unwinds the outermost trigger dispatch. Carries the set of SObject types whose triggers participated in the transaction so the post-action c"
since: "1.1"
category: apex
---

# IF_Trigger.PostActionContext

**Class**

<div class="apex-member apex-class">

```apex
global class IF_Trigger.PostActionContext
```

Context handed to a post-trigger action when the dispatcher unwinds the outermost trigger dispatch. Carries the set of SObject types whose triggers participated in the transaction so the post-action can branch on which objects were touched without re-querying. The framework constructs and supplies this object — subscribers should not need to construct it directly outside of unit tests. Why Set&lt;SObjectType&gt; rather than record IDs: the post-action runs once per outermost dispatch with no per-record context, so the type-level discriminator is what's load-bearing. Per-record IDs would (1) carry an unbounded heap cost in batch contexts, (2) leak record material across post-actions written by different teams in the same org. Subscribers needing per-record context should maintain their own domain-specific statics during their trigger actions and consult them inside the post-action.

**Example**

```apex
// Inside a PostAction.execute(context):
if(context.touchedSObjectTypes.contains(Account.SObjectType))
{
    // Account triggers participated; run Account-domain work.
}
```

</div>

---

## Constructors

| Constructor | Description |
|-------------|-------------|
| global [PostActionContext](#constructors)([Set](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_set.htm)<[SObjectType](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectType.htm)> touched) | Constructs a post-action context with the supplied set of touched SObject types. |

### PostActionContext(Set<SObjectType> touched)

<div class="apex-member">

```apex
global PostActionContext(Set<SObjectType> touched)
```

Constructs a post-action context with the supplied set of touched
SObject types. A null argument is normalised to an empty Set so subscribers can
safely call `.contains(...)` without null-checking. Intended for framework and
unit-test construction; subscribers receive instances via `PostAction.execute`.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `touched` | [Set](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_set.htm) | The set of SObject types whose triggers participated, or null. |

</div>

## Properties

| Property | Description |
|----------|-------------|
| global [Set](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_set.htm)<[SObjectType](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectType.htm)> [touchedSObjectTypes](#touchedsobjecttypes) | The SObject types whose triggers participated in the transaction. |

### touchedSObjectTypes

```apex
global Set<SObjectType> touchedSObjectTypes
```

**Type:** [Set](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_set.htm)

The SObject types whose triggers participated in the transaction.
The framework stores a defensive copy on construction and the setter is private,
so the framework's own source set cannot be mutated through this reference;
subscribers must still treat the returned Set as read-only — a single context
instance is shared across every post-action in the dispatch, so mutating it has
no defined effect and could affect other post-actions. An empty set is possible —
a post-action that ran solely because of a bypassed-but-still-fired trigger could
see an empty context. Subscribers should null-check defensively even though the
constructor guarantees a non-null Set.

