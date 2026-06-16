---
title: "UTIL_FeatureFlag.INT_UserAwareFeatureFlagStrategy"
type: class
pageClass: reference
description: "Extended interface for custom strategies that support user context evaluation. Implement this interface instead of INT_FeatureFlagStrategy when your custom strategy needs to evaluate for a specific us"
since: "1.0"
category: apex
---

# UTIL_FeatureFlag.INT_UserAwareFeatureFlagStrategy

**Class**

```apex
global interface UTIL_FeatureFlag.INT_UserAwareFeatureFlagStrategy implements UTIL_FeatureFlag.INT_FeatureFlagStrategy
```

**Implements:** [UTIL_FeatureFlag.INT_FeatureFlagStrategy](UTIL_FeatureFlag.INT_FeatureFlagStrategy.md)

Extended interface for custom strategies that support user context evaluation. Implement this interface instead of INT_FeatureFlagStrategy when your custom strategy needs to evaluate for a specific user (not just the running user). IMPORTANT: You must implement BOTH methods: isEnabled() for backward compatibility and running user scenarios isEnabledForUser() for explicit user context scenarios The recommended pattern is to have isEnabled() delegate to isEnabledForUser().

**Since:** 1.0

**Example:**

```apex
public class MY_Region_Strategy implements UTIL_FeatureFlag.INT_UserAwareFeatureFlagStrategy
{
    public Boolean isEnabled(FeatureFlag__mdt flag, FeatureFlagStrategy__mdt strategyToEvaluate)
    {
        return isEnabledForUser(flag, strategyToEvaluate, UserInfo.getUserId());
    }
    public Boolean isEnabledForUser(FeatureFlag__mdt flag, FeatureFlagStrategy__mdt strategyToEvaluate, Id userId)
    {
        User targetUser = new SEL_User().findById(userId);
        List<String> allowedCountries = strategyToEvaluate.Target__c.split(',');
        return allowedCountries.contains(targetUser.Country);
    }
}
```

---

## Methods

| Method | Description |
|--------|-------------|
| global abstract [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) [isEnabledForUser](#isenabledforuser)([FeatureFlag__mdt](../metadata/FeatureFlag__mdt.md) flag, [FeatureFlagStrategy__mdt](../metadata/FeatureFlagStrategy__mdt.md) strategyToEvaluate, [Id](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_id.htm) userId) | Evaluates the strategy for a specific user. |

---

## Method Details

### isEnabledForUser

<div class="apex-member">

```apex
global abstract Boolean isEnabledForUser(FeatureFlag__mdt flag, FeatureFlagStrategy__mdt strategyToEvaluate, Id userId)
```

Evaluates the strategy for a specific user.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `flag` | [FeatureFlag__mdt](../metadata/FeatureFlag__mdt.md) | The parent Feature Flag custom metadata record |
| `strategyToEvaluate` | [FeatureFlagStrategy__mdt](../metadata/FeatureFlagStrategy__mdt.md) | The specific strategy record being evaluated |
| `userId` | [Id](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_id.htm) | The user to evaluate the strategy for (may differ from running user) |

**Returns** [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) — `true` if the feature is enabled for the specified user by this strategy

</div>

