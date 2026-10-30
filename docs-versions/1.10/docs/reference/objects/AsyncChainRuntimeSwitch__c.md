---
title: "AsyncChainRuntimeSwitch__c"
type: sobject
pageClass: reference
description: "Hierarchical custom setting that controls whether async chain processing runs, at the org, profile, or user level. User-level overrides profile-level, which overrides org-level. The Chain Monitor's su"
category: objects
---

# AsyncChainRuntimeSwitch__c

**Sobject**

<div class="apex-member apex-class">

```apex
global class AsyncChainRuntimeSwitch__c extends SObject
```

**Extends:** [SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm)

Hierarchical custom setting that controls whether async chain processing runs, at the org, profile, or user level. User-level overrides profile-level, which overrides org-level. The Chain Monitor's suspend and resume actions write the org-level record; rows at the other levels are manual overrides.

</div>

---

## Fields

| Field | Description |
|-------|-------------|
| global [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) [ChainsEnabled__c](#chainsenabled__c) | Whether async chain processing runs for the applicable user, profile, or org. |

### ChainsEnabled__c

```apex
global Boolean ChainsEnabled__c
```

Whether async chain processing runs for the applicable user, profile, or org. Uncheck to suspend it: running chains stop at their next step boundary and new chains stop at once. This is a hierarchical custom setting — user-level overrides profile-level, which overrides org-level — and an org with no record at all keeps chains enabled.

**Field Attributes:**

| Attribute | Value |
|-----------|-------|
| Data Type | Checkbox |
| Default Value | true |

