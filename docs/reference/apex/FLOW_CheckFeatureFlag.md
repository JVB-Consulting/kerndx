---
title: "FLOW_CheckFeatureFlag"
type: class
pageClass: reference
description: "This class is used in Flows to check whether a specific feature flag is enabled. It provides a method that can be invoked from a flow to determine if a feature is active for the current user based on "
author: "Jason Van Beukering"
group: "Feature Flags"
date: "November 2025, May 2026"
since: "1.0"
category: apex
---

# FLOW_CheckFeatureFlag

**Class** · Group: `Feature Flags`

```apex
global inherited sharing class FLOW_CheckFeatureFlag
```

This class is used in Flows to check whether a specific feature flag is enabled. It provides a method that can be invoked from a flow to determine if a feature is active for the current user based on the UTIL_FeatureFlag utility.

**Since:** 1.0

**Example:**

```apex
List<Boolean> results = FLOW_CheckFeatureFlag.isEnabled(new List<String> {'NewDashboard'});
Boolean isEnabled = results[0];
```

**See Also:** [UTIL_FeatureFlag](UTIL_FeatureFlag.md)

---

## Methods

| Method | Description |
|--------|-------------|
| global static [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm)> [isEnabled](#isenabled)([List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)> flagNames) | Returns if the specified feature flag is enabled for the current user. |

---

## Method Details

### isEnabled

<div class="apex-member">

```apex
@InvocableMethod(category='Utilities' description='Returns true if the specified Feature Flag is enabled for the current user.' label='Is Feature Flag Enabled') global static List<Boolean> isEnabled(List<String> flagNames)
```

Returns if the specified feature flag is enabled for the current user.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `flagNames` | [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm) | A list containing a single DTO_Request with the feature flag's API name. |

**Returns** [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) — A list containing whether flags provided are enabled or not

**Example**

```apex
List<Boolean> results = FLOW_CheckFeatureFlag.isEnabled(new List<String>{'NewDashboard', 'BetaFeature'});
if(results[0])
{
	LOG_Builder.build().info('NewDashboard feature is enabled').emitAt('MyFlow.checkFlag');
}
```

</div>

