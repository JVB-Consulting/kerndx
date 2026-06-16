---
title: "FieldSetGroup__mdt"
type: sobject
pageClass: reference
description: "Groups multiple field sets for an object into a single configuration record. Used to drive multi-section UI layouts such as accordion panels."
category: metadata
---

# FieldSetGroup__mdt

**Sobject**

<div class="apex-member apex-class">

```apex
global class FieldSetGroup__mdt extends SObject
```

**Extends:** [SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm)

Groups multiple field sets for an object into a single configuration record. Used to drive multi-section UI layouts such as accordion panels.

</div>

---

## Fields

| Field | Description |
|-------|-------------|
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [DefaultActiveSections__c](#defaultactivesections__c) | Comma-separated list of section names (matching field set labels) that should be expanded by default when the UI loads. |
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [FieldSetApiNames__c](#fieldsetapinames__c) | Comma-separated list of field set API names to include in this group. |

---

## Field Details

### DefaultActiveSections__c

```apex
global String DefaultActiveSections__c
```

Comma-separated list of section names (matching field set labels) that should be expanded by default when the UI loads.

**Field Attributes:**

| Attribute | Value |
|-----------|-------|
| Data Type | Long Text Area(32768) |

### FieldSetApiNames__c

```apex
global String FieldSetApiNames__c
```

Comma-separated list of field set API names to include in this group. Each field set renders as a separate section in the UI.

**Field Attributes:**

| Attribute | Value |
|-----------|-------|
| Data Type | Long Text Area(32768) |

