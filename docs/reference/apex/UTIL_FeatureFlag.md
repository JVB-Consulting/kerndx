---
title: "UTIL_FeatureFlag"
type: class
description: "Provides static methods to check if a feature is enabled. It reads Custom Metadata records to determine if a feature should be active for the current user or for a specific user (user context evaluati"
author: "Jason Van Beukering"
group: "Feature Flags"
date: "November 2025, May 2026"
since: "1.0"
category: apex
---

# UTIL_FeatureFlag

**Class** · Group: `Feature Flags`

```apex
global inherited sharing class UTIL_FeatureFlag
```

Provides static methods to check if a feature is enabled. It reads Custom Metadata records to determine if a feature should be active for the current user or for a specific user (user context evaluation). User Context Evaluation: Use isEnabled(flagName, userId) or isEnabled(flagName, username) when you need to evaluate a feature flag for a user other than the currently running user. This is essential for: TxnSecurity.EventCondition implementations (check flags for the event user, not the policy context) Batch Apex processing (evaluate flags for each user being processed) Platform Event handlers (check flags for the event publisher) Admin tools (preview flag status for troubleshooting) Performance and SOQL Cost: The first isEnabled(...) call per transaction loads every active flag and its active strategies in one CMDT query (SEL_FeatureFlag.activeFlags static cache); subsequent calls reuse that cache. Most strategy types then add 1 SOQL per evaluation — Hierarchical/List Custom Setting, Custom Metadata, Profile, Public Group, Permission Set Group, and unprefixed (subscriber-local) Custom Permission. Namespaced or core. Custom Permission for the running user is free (FeatureManagement.checkPermission()). For per-record loops or batch jobs, hoist the boolean out of the loop, or implement an INT_FeatureFlagStrategy handler that calls typed MyCS__c.getInstance(...) to dodge SOQL on Custom Setting reads. See the Utilities Guide → "Performance and SOQL Cost" for the full per-strategy cost table and a worked example.

**Since:** 1.0

**Example:**

```apex
// Simple check to see if a feature is enabled for the running user
if(UTIL_FeatureFlag.isEnabled('My_New_Feature_Api_Name'))
{
    // Execute the new feature logic
    MY_FeatureController.doSomething();
}
// Check feature flag for a specific user (e.g., in TxnSecurity policy)
if(UTIL_FeatureFlag.isEnabled('Block_Large_Export', reportEvent.UserId))
{
    return reportEvent.RowsProcessed > 10000;
}
```

**See Also:** [FeatureFlag__mdt](../metadata/FeatureFlag__mdt.md)

---

## Properties

| Property | Description |
|----------|-------------|
| global interface [INT_FeatureFlagStrategy](UTIL_FeatureFlag.INT_FeatureFlagStrategy.md) | The global interface for all feature evaluation strategies. |
| global interface [INT_UserAwareFeatureFlagStrategy](UTIL_FeatureFlag.INT_UserAwareFeatureFlagStrategy.md) | Extended interface for custom strategies that support user context evaluation. |

## Methods

| Method | Description |
|--------|-------------|
| global static [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) [isEnabled](#isenabled)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) flagName) | Checks if a feature is enabled for the RUNNING user by evaluating its associated strategies. |
| global static [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) [isEnabled](#isenabled)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) flagName, [Id](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_id.htm) userId) | Checks if a feature is enabled for a SPECIFIC user. |
| global static [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) [isEnabled](#isenabled)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) flagName, [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) username) | Checks if a feature is enabled for a user identified by username. |

---

## Method Details

### isEnabled

```apex
global static Boolean isEnabled(String flagName)
```

Checks if a feature is enabled for the RUNNING user by evaluating its associated strategies.

**Parameters:**

- `flagName` ([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)) - The DeveloperName (API Name) of the Feature Flag custom metadata record.

**Returns:** [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) - `true` if the feature is enabled, `false` otherwise.

**Since:** 1.0

**Example:**

```apex
String featureFlagApiName = 'My_Feature_Flag';
if(UTIL_FeatureFlag.isEnabled(featureFlagApiName))
{
    MY_NewFeature_CLASS.doSomething();
}
else
{
    MY_OldLogic_CLASS.doSomething();
}
```

### isEnabled

```apex
global static Boolean isEnabled(String flagName, Id userId)
```

Checks if a feature is enabled for a SPECIFIC user.

Use this method when you need to evaluate a feature flag for a user other than
the currently running user. Common scenarios include:

- TxnSecurity.EventCondition: Check flags for the event user, not the policy context

- Batch Apex: Evaluate flags for each user being processed

- Platform Events: Check flags for the event publisher

- Admin Tools: Preview flag status for troubleshooting

All built-in strategies (Custom Permission, Permission Set Group, Profile,
Public Group, Hierarchical Custom Setting) fully support user context evaluation.

Custom strategies implementing INT_UserAwareFeatureFlagStrategy will receive
the userId parameter. Strategies implementing only INT_FeatureFlagStrategy
will fall back to running user evaluation (backward compatible).

**Parameters:**

- `flagName` ([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)) - The DeveloperName (API Name) of the Feature Flag custom metadata record
- `userId` ([Id](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_id.htm)) - The Salesforce User ID to evaluate the flag for

**Returns:** [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) - `true` if the feature is enabled for the specified user, `false` otherwise

**Since:** 1.0

**Example:**

```apex
// TxnSecurity.EventCondition usage
global class MySecurityPolicy implements TxnSecurity.EventCondition
{
    public Boolean evaluate(SObject event)
    {
        ReportEvent reportEvent = (ReportEvent)event;
        // Check flag for the EVENT USER, not the policy context
        if(UTIL_FeatureFlag.isEnabled('Block_Large_Export', reportEvent.UserId))
        {
            return reportEvent.RowsProcessed > 10000;
        }
        return false;
    }
}
```

### isEnabled

```apex
global static Boolean isEnabled(String flagName, String username)
```

Checks if a feature is enabled for a user identified by username.

This is a convenience method for scenarios where you have a username
(email format) instead of a Salesforce User ID. The method looks up
the user first, then evaluates the flag.

Returns false if the username does not match any user in the org.

**Parameters:**

- `flagName` ([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)) - The DeveloperName (API Name) of the Feature Flag custom metadata record
- `username` ([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)) - The username (typically email format) to look up and evaluate

**Returns:** [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) - `true` if the user exists and the feature is enabled for them, `false` otherwise

**Since:** 1.0

**Example:**

```apex
// Check flag by username (e.g., from external system)
Boolean enabled = UTIL_FeatureFlag.isEnabled('Premium_Feature', 'john.doe@company.com');
if(enabled)
{
    System.debug('Feature is enabled for this user');
}
```

