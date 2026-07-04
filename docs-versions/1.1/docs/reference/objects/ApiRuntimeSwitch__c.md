---
title: "ApiRuntimeSwitch__c"
type: sobject
description: "Hierarchical custom setting that provides runtime API kill switches at the org, profile, or user level. User-level overrides profile-level, which overrides org-level. For granular per-service control,"
category: objects
---

# ApiRuntimeSwitch__c

**Sobject**

```apex
global class ApiRuntimeSwitch__c extends SObject
```

**Extends:** [SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm)

Hierarchical custom setting that provides runtime API kill switches at the org, profile, or user level. User-level overrides profile-level, which overrides org-level. For granular per-service control, use ApiSetting__mdt.IsActive__c instead.

---

## Fields

| Field | Description |
|-------|-------------|
| global [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) [DisableAllApis__c](#disableallapis__c) | When enabled, every API call (inbound and outbound) is disabled for the applicable user, profile, or org. |

---

## Field Details

### DisableAllApis__c

```apex
global Boolean DisableAllApis__c
```

When enabled, every API call (inbound and outbound) is disabled for the applicable user, profile, or org. This is a hierarchical custom setting — user-level overrides profile-level, which overrides org-level.

**Field Attributes:**

| Attribute | Value |
|-----------|-------|
| Data Type | Checkbox |
| Default Value | false |

