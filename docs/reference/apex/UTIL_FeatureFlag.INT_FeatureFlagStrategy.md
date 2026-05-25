---
title: "UTIL_FeatureFlag.INT_FeatureFlagStrategy"
type: class
description: "The global interface for all feature evaluation strategies. Implement this interface and reference your class from FeatureFlagStrategy__mdt.CustomHandler__c to replace any built-in strategy. This is t"
since: "1.0"
category: apex
---

# UTIL_FeatureFlag.INT_FeatureFlagStrategy

**Class**

```apex
global interface UTIL_FeatureFlag.INT_FeatureFlagStrategy
```

**Known Derived Types:** [UTIL_FeatureFlag.INT_UserAwareFeatureFlagStrategy](UTIL_FeatureFlag.INT_UserAwareFeatureFlagStrategy.md)

The global interface for all feature evaluation strategies. Implement this interface and reference your class from FeatureFlagStrategy__mdt.CustomHandler__c to replace any built-in strategy. This is the recommended escape hatch when the built-in Hierarchical/List Custom Setting or Custom Metadata strategies cause SOQL hot spots: a custom handler can call typed MyCS__c.getInstance(userId) / MyType__mdt.getInstance(name) directly for zero-SOQL platform-cached reads. See the Utilities Guide → "Performance and SOQL Cost".

**Since:** 1.0

**Example:**

```apex
// Example implementation of a custom strategy
public class MY_Region_Strategy implements UTIL_FeatureFlag.INT_FeatureFlagStrategy
{
    public Boolean isEnabled(FeatureFlag__mdt flag, FeatureFlagStrategy__mdt strategyToEvaluate)
    {
        // Custom logic to enable feature only for users in the 'US'
        Boolean isFeatureEnabled = UserInfo.getCountry() == 'US';
        return isFeatureEnabled;
    }
}
```

---

## Methods

| Method | Description |
|--------|-------------|
| global abstract [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) [isEnabled](#isenabled)([FeatureFlag__mdt](../metadata/FeatureFlag__mdt.md) flag, [FeatureFlagStrategy__mdt](../metadata/FeatureFlagStrategy__mdt.md) strategyToEvaluate) | Evaluates the strategy and determines if the feature should be enabled. |

---

## Method Details

### isEnabled

```apex
global abstract Boolean isEnabled(FeatureFlag__mdt flag, FeatureFlagStrategy__mdt strategyToEvaluate)
```

Evaluates the strategy and determines if the feature should be enabled.

**Parameters:**

- `flag` ([FeatureFlag__mdt](../metadata/FeatureFlag__mdt.md)) - The Feature Flag custom metadata record.
- `strategyToEvaluate` ([FeatureFlagStrategy__mdt](../metadata/FeatureFlagStrategy__mdt.md)) - The specific strategy record to evaluate.

**Returns:** [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) - `true` if the feature is enabled by this strategy, `false` otherwise.

**Since:** 1.0

**Example:**

```apex
public Boolean isEnabled(FeatureFlag__mdt flag, FeatureFlagStrategy__mdt strategyToEvaluate)
{
    // Check if the strategy's target value matches our condition
    Boolean isTargetMet = strategyToEvaluate.TargetValue__c == 'Some_Value';
    return isTargetMet;
}
```

