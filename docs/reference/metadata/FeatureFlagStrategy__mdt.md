---
title: "FeatureFlagStrategy__mdt"
type: sobject
pageClass: reference
description: "Defines a single evaluation rule for a parent Feature Flag. A Feature Flag can have multiple strategies, which are processed in the order specified by the 'Order' field. The first strategy to return '"
category: metadata
---

# FeatureFlagStrategy__mdt

**Sobject**

<div class="apex-member apex-class">

```apex
global class FeatureFlagStrategy__mdt extends SObject
```

**Extends:** [SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm)

Defines a single evaluation rule for a parent Feature Flag. A Feature Flag can have multiple strategies, which are processed in the order specified by the 'Order' field. The first strategy to return 'true' enables the feature.

</div>

---

## Fields

| Field | Description |
|-------|-------------|
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [CustomHandler__c](#customhandler__c) | Optional. |
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [ExpectedValue__c](#expectedvalue__c) | Optional. |
| global [Id](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_id.htm) [FeatureFlag__c](#featureflag__c) | Master-detail relationship to the parent FeatureFlag__mdt record. |
| global [FeatureFlag__mdt](../metadata/FeatureFlag__mdt.md) [FeatureFlag__r](#featureflag__r) | Master-detail relationship to the parent FeatureFlag__mdt record. |
| global [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) [IsActive__c](#isactive__c) | Controls whether this specific strategy is evaluated. |
| global [Decimal](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_decimal.htm) [Order__c](#order__c) | The execution priority for this strategy relative to other strategies for the same Feature Flag. |
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [Target__c](#target__c) | The identifier, name, or path of the item to evaluate. |
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [Type__c](#type__c) | The type of evaluation strategy to execute. |

---

## Field Details

### CustomHandler__c

```apex
global String CustomHandler__c
```

Optional. The name of an Apex class that implements the framework's feature flag strategy interface. If provided, this class executes instead of the standard logic for the selected Type.

**Field Attributes:**

| Attribute | Value |
|-----------|-------|
| Data Type | Text(255) |
| Required | false |
| Unique | false |
| External ID | false |

### ExpectedValue__c

```apex
global String ExpectedValue__c
```

Optional. The value to compare against the 'Target'. If the 'Target' is a field path, this field is compared (with type-safety) against the value *in* that field. If this field is blank, the logic defaults to checking if the 'Target' field's value is 'true'.

**Field Attributes:**

| Attribute | Value |
|-----------|-------|
| Data Type | Text(255) |
| Required | false |
| Unique | false |
| External ID | false |

### FeatureFlag__c

```apex
global Id FeatureFlag__c
```

Master-detail relationship to the parent FeatureFlag__mdt record. This links the strategy rule to the feature it controls.

**Field Attributes:**

| Attribute | Value |
|-----------|-------|
| Data Type | FeatureFlag__mdt |
| Required | true |
| Unique | false |

### FeatureFlag__r

```apex
global FeatureFlag__mdt FeatureFlag__r
```

Master-detail relationship to the parent FeatureFlag__mdt record. This links the strategy rule to the feature it controls.

**Field Attributes:**

| Attribute | Value |
|-----------|-------|
| Data Type | FeatureFlag__mdt |
| Required | true |
| Unique | false |

### IsActive__c

```apex
global Boolean IsActive__c
```

Controls whether this specific strategy is evaluated. If unchecked (false), this strategy is skipped, and the framework moves to the next strategy based on the 'Order' field.

**Field Attributes:**

| Attribute | Value |
|-----------|-------|
| Data Type | Checkbox |
| Default Value | false |

### Order__c

```apex
global Decimal Order__c
```

The execution priority for this strategy relative to other strategies for the same Feature Flag. Strategies are evaluated in ascending order (e.g., 1, then 2, then 3).

**Field Attributes:**

| Attribute | Value |
|-----------|-------|
| Data Type | Number(2,0) |
| Required | false |
| Unique | false |
| External ID | false |

### Target__c

```apex
global String Target__c
```

The identifier, name, or path of the item to evaluate. The required format depends on the 'Type' field. For Custom Permission type: unprefixed names check local/subscriber permissions, 'core.' prefix checks package permissions, and 'namespace__' syntax checks fully-qualified namespaced permissions.

**Field Attributes:**

| Attribute | Value |
|-----------|-------|
| Data Type | Text(255) |
| Required | false |
| Unique | false |
| External ID | false |

### Type__c

```apex
global String Type__c
```

The type of evaluation strategy to execute. Determines which logic path is used and dictates the required format for the Target field. Options: Custom Permission (user has permission), Profile (user's profile matches), Permission Set Group (user is assigned), Public Group (user is member), Hierarchical Custom Setting (field value), List Custom Setting (record field value), Custom Metadata (record field value).

**Field Attributes:**

| Attribute | Value |
|-----------|-------|
| Data Type | Picklist |
| Required | true |

**Picklist Values:**

| API Name | Label | Active |
|----------|-------|--------|
| `Custom Permission` | Custom Permission | Yes |
| `Hierarchical Custom Setting` | Hierarchical Custom Setting | No |
| `Permission Set Group` | Permission Set Group | No |
| `Profile` | Profile | No |
| `Public Group` | Public Group | No |
| `Custom Metadata` | Custom Metadata | No |
| `List Custom Setting` | List Custom Setting | No |

