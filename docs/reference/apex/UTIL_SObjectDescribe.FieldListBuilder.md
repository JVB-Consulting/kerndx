---
title: "UTIL_SObjectDescribe.FieldListBuilder"
type: class
description: "Builds a comma-separated field list from SObjectField tokens and optional FieldSet definitions."
since: "1.0"
category: apex
---

# UTIL_SObjectDescribe.FieldListBuilder

**Class**

```apex
global inherited sharing class UTIL_SObjectDescribe.FieldListBuilder extends UTIL_String.DelimitedListBuilder
```

Builds a comma-separated field list from SObjectField tokens and optional FieldSet definitions.

**Since:** 1.0

---

## Methods

| Method | Description |
|--------|-------------|
| global  [FieldListBuilder](#fieldlistbuilder)([List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm)> objectFields) | Initializes a FieldListBuilder with a list of SObjectField tokens. |
| global  [FieldListBuilder](#fieldlistbuilder)([List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm)> objectFields, [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[FieldSet](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_fieldsets_describe.htm)> fieldSets) | Initializes a FieldListBuilder with fields and optional FieldSets. |

---

## Method Details

### FieldListBuilder

```apex
global FieldListBuilder(List<SObjectField> objectFields)
```

Initializes a FieldListBuilder with a list of SObjectField tokens.

**Parameters:**

- `objectFields` ([List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)) - A list of SObject fields to initialize the builder.

**Since:** 1.0

**Example:**

```apex
UTIL_SObjectDescribe.FieldListBuilder builder = new UTIL_SObjectDescribe.FieldListBuilder(new List<SObjectField>{Account.Name});
```

```apex
global FieldListBuilder(List<SObjectField> objectFields, List<FieldSet> fieldSets)
```

Initializes a FieldListBuilder with fields and optional FieldSets.

**Parameters:**

- `objectFields` ([List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)) - A list of SObject fields.
- `fieldSets` ([SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm)) - A list of FieldSets for concatenation.

**Since:** 1.0

**Example:**

```apex
UTIL_SObjectDescribe.FieldListBuilder builder = new UTIL_SObjectDescribe.FieldListBuilder(new List<SObjectField>{Account.Name}, new List<FieldSet>());
```

