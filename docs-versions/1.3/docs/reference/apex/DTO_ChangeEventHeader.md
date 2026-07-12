---
title: "DTO_ChangeEventHeader"
type: class
pageClass: reference
description: "A Data Transfer Object (DTO) exposing the supported subset of EventBus.ChangeEventHeader to Flow as a strongly-typed input variable. The platform header type is not Flow-addressable directly; this DTO"
author: "Jason Van Beukering"
group: "Data Transfer Objects"
date: "May 2026"
since: "1.1"
category: apex
---

# DTO_ChangeEventHeader

**Class** · Group: `Data Transfer Objects`

<div class="apex-member apex-class">

```apex
global inherited sharing class DTO_ChangeEventHeader
```

A Data Transfer Object (DTO) exposing the supported subset of EventBus.ChangeEventHeader to Flow as a strongly-typed input variable. The platform header type is not Flow-addressable directly; this DTO mirrors its public fields with the @InvocableVariable + @AuraEnabled annotations required for Flow Apex-defined variables and invocable-action parameters. global is required so subscriber-namespace flows can reference the type cross-namespace. Stability contract: this is a stable additive subset of the platform header. New platform header fields added in future Salesforce releases are added here as new @InvocableVariable fields — never modified or removed — so existing subscriber flows remain compatible.

**Example**

```apex
EventBus.ChangeEventHeader platformHeader =
    (EventBus.ChangeEventHeader)records[0].get('ChangeEventHeader');
DTO_ChangeEventHeader flowHeader = new DTO_ChangeEventHeader(platformHeader);
// Pass flowHeader into a Flow interview as the <code class="explicitCode">header</code> variable.
```

**See Also:** [EventBus.ChangeEventHeader](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_eventbus_ChangeEventHeader.htm)

</div>

---

## Constructors

| Constructor | Description |
|-------------|-------------|
| global [DTO_ChangeEventHeader](#constructors)() | No-arg constructor required by some Flow runtime entry points that instantiate Apex-defined variable types before populating fields. |
| global [DTO_ChangeEventHeader](#constructors)([EventBus.ChangeEventHeader](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_eventbus_ChangeEventHeader.htm) header) | Copy constructor — populates this DTO from a platform EventBus.ChangeEventHeader. |

### DTO_ChangeEventHeader()

<div class="apex-member">

```apex
global DTO_ChangeEventHeader()
```

No-arg constructor required by some Flow runtime entry points that
instantiate Apex-defined variable types before populating fields.

</div>

### DTO_ChangeEventHeader(EventBus.ChangeEventHeader header)

<div class="apex-member">

```apex
global DTO_ChangeEventHeader(EventBus.ChangeEventHeader header)
```

Copy constructor — populates this DTO from a platform
`EventBus.ChangeEventHeader`. Field-by-field assignment so the DTO is fully
detached from the platform instance and safe to mutate without affecting the
original.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `header` | [EventBus.ChangeEventHeader](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_eventbus_ChangeEventHeader.htm) | The platform header to copy from. Must not be null. |

</div>

## Fields

| Field | Description |
|-------|-------------|
| global [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)> [changedFields](#changedfields) | The list of fields whose scalar values changed in this commit. |
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [changeOrigin](#changeorigin) | The origin of the change — typically user/<userId> for user-initiated changes or a system identifier for platform-initiated changes. |
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [changeType](#changetype) | The kind of change — CREATE, UPDATE, DELETE, UNDELETE, or GAP_* for replay-gap notifications. |
| global [Long](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_long.htm) [commitNumber](#commitnumber) | A monotonically increasing commit-ordering number used by the platform for replay sequencing. |
| global [Long](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_long.htm) [commitTimestamp](#committimestamp) | The commit time as Unix epoch milliseconds. |
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [commitUser](#commituser) | The ID of the user (or System) that committed the change. |
| global [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)> [diffFields](#difffields) | The list of fields whose values differ from the prior commit (large / complex types only — most scalar field changes appear in changedFields). |
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [entityName](#entityname) | The fully qualified API name of the source entity (e.g. |
| global [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)> [nulledFields](#nulledfields) | The list of fields whose values were nulled by this change. |
| global [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)> [recordIds](#recordids) | The list of source record IDs affected by this change event. |
| global [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) [sequenceNumber](#sequencenumber) | The ordinal position of this change within the transaction, starting at 1. |
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [transactionKey](#transactionkey) | A platform-assigned identifier that groups all change events from the same atomic transaction. |

### changedFields

```apex
@AuraEnabled @InvocableVariable(description='The list of fields whose scalar values changed in this commit' label='Changed Fields') global List<String> changedFields
```

**Type:** [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)

The list of fields whose scalar values changed in this commit.

### changeOrigin

```apex
@AuraEnabled @InvocableVariable(description='The origin of the change — typically user/<userId> for user-initiated changes' label='Change Origin') global String changeOrigin
```

**Type:** [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)

The origin of the change — typically user/<userId> for user-initiated
changes or a system identifier for platform-initiated changes. Useful for filtering
self-initiated changes out of downstream logic.

### changeType

```apex
@AuraEnabled @InvocableVariable(description='The kind of change — CREATE, UPDATE, DELETE, UNDELETE, or GAP_*' label='Change Type') global String changeType
```

**Type:** [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)

The kind of change — CREATE, UPDATE, DELETE, UNDELETE, or
GAP_* for replay-gap notifications.

### commitNumber

```apex
@AuraEnabled @InvocableVariable(description='A monotonically increasing commit-ordering number used for replay sequencing' label='Commit Number') global Long commitNumber
```

**Type:** [Long](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_long.htm)

A monotonically increasing commit-ordering number used by the platform
for replay sequencing.

### commitTimestamp

```apex
@AuraEnabled @InvocableVariable(description='Commit time as Unix epoch milliseconds' label='Commit Timestamp') global Long commitTimestamp
```

**Type:** [Long](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_long.htm)

The commit time as Unix epoch milliseconds. Use to compare ordering of
change events across transactions.

### commitUser

```apex
@AuraEnabled @InvocableVariable(description='The ID of the user or System that committed the change' label='Commit User') global String commitUser
```

**Type:** [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)

The ID of the user (or System) that committed the change.

### diffFields

```apex
@AuraEnabled @InvocableVariable(description='The list of fields whose values differ from the prior commit (large or complex types)' label='Diff Fields') global List<String> diffFields
```

**Type:** [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)

The list of fields whose values differ from the prior commit (large /
complex types only — most scalar field changes appear in changedFields).

### entityName

```apex
@AuraEnabled @InvocableVariable(description='The fully qualified API name of the source entity for the change event' label='Entity Name') global String entityName
```

**Type:** [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)

The fully qualified API name of the source entity (e.g. Account,
Foobar__c). Carries the standard / custom object name, not the Change Event
suffix.

### nulledFields

```apex
@AuraEnabled @InvocableVariable(description='The list of fields whose values were nulled by this change' label='Nulled Fields') global List<String> nulledFields
```

**Type:** [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)

The list of fields whose values were nulled by this change.

### recordIds

```apex
@AuraEnabled @InvocableVariable(description='The list of source record IDs affected by this change event' label='Record Ids') global List<String> recordIds
```

**Type:** [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)

The list of source record IDs affected by this change event. A single
change event may carry multiple IDs when the platform batches changes for the same
entity within a commit window.

### sequenceNumber

```apex
@AuraEnabled @InvocableVariable(description='Ordinal position of this change within the transaction (starting at 1)' label='Sequence Number') global Integer sequenceNumber
```

**Type:** [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm)

The ordinal position of this change within the transaction, starting
at 1. A multi-entity transaction emits events with sequential sequenceNumbers.

### transactionKey

```apex
@AuraEnabled @InvocableVariable(description='Platform-assigned identifier grouping change events from the same atomic transaction' label='Transaction Key') global String transactionKey
```

**Type:** [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)

A platform-assigned identifier that groups all change events from the
same atomic transaction. Use to correlate cascading changes across multiple
entities.

