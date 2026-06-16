---
title: "MaskingTarget__mdt"
type: sobject
pageClass: reference
description: "Applies a Masking Rule to a specific field on a specific object. Each record says \"use this rule on this field\". Pick the object first, then the Field picklist filters to fields on that object. Crea"
category: metadata
---

# MaskingTarget__mdt

**Sobject**

<div class="apex-member apex-class">

```apex
global class MaskingTarget__mdt extends SObject
```

**Extends:** [SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm)

Applies a Masking Rule to a specific field on a specific object. Each record says "use this rule on this field". Pick the object first, then the Field picklist filters to fields on that object. Create as many records as you need — the same rule can apply to many fields across many objects.

</div>

---

## Fields

| Field | Description |
|-------|-------------|
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [CallerClass__c](#callerclass__c) | Optional. |
| global [Id](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_id.htm) [Field__c](#field__c) | The field on the chosen object to mask. |
| global [FieldDefinition](https://developer.salesforce.com/docs/atlas.en-us.object_reference.meta/object_reference/sforce_api_objects_fielddefinition.htm) [Field__r](#field__r) | The field on the chosen object to mask. |
| global [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) [IsActive__c](#isactive__c) | Controls whether this wiring is in effect. |
| global [Id](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_id.htm) [Rule__c](#rule__c) | The Masking Rule that will be applied to the field. |
| global [MaskingRule__mdt](../metadata/MaskingRule__mdt.md) [Rule__r](#rule__r) | The Masking Rule that will be applied to the field. |
| global [Id](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_id.htm) [SObjectType__c](#sobjecttype__c) | The object that contains the field to mask. |
| global [EntityDefinition](https://developer.salesforce.com/docs/atlas.en-us.object_reference.meta/object_reference/sforce_api_objects_entitydefinition.htm) [SObjectType__r](#sobjecttype__r) | The object that contains the field to mask. |

---

## Field Details

### CallerClass__c

```apex
global String CallerClass__c
```

Optional. Leave blank to apply the rule whenever the field is masked. Set to an Apex class name (e.g. API_SendEmail) to restrict the rule to calls from that class only — useful when you want a rule to apply only in the context of one API service or integration and not everywhere that field is used.

**Field Attributes:**

| Attribute | Value |
|-----------|-------|
| Data Type | Text(100) |
| Required | false |
| Unique | false |
| External ID | false |

### Field__c

```apex
global Id Field__c
```

The field on the chosen object to mask. Only fields from the selected SObject Type appear in the picklist. Leave blank to apply the rule to every updateable text-shaped field on the object (Text, Text Area, Long Text Area, URL, Email, Phone, Encrypted Text); pick a specific field to scope the rule to one field, or to override or disable the wildcard behavior on that one field.

**Field Attributes:**

| Attribute | Value |
|-----------|-------|
| Data Type | FieldDefinition |
| Required | false |
| Unique | false |

### Field__r

```apex
global FieldDefinition Field__r
```

The field on the chosen object to mask. Only fields from the selected SObject Type appear in the picklist. Leave blank to apply the rule to every updateable text-shaped field on the object (Text, Text Area, Long Text Area, URL, Email, Phone, Encrypted Text); pick a specific field to scope the rule to one field, or to override or disable the wildcard behavior on that one field.

**Field Attributes:**

| Attribute | Value |
|-----------|-------|
| Data Type | FieldDefinition |
| Required | false |
| Unique | false |

### IsActive__c

```apex
global Boolean IsActive__c
```

Controls whether this wiring is in effect. Uncheck to temporarily disable masking on this specific field without changing the underlying rule.

**Field Attributes:**

| Attribute | Value |
|-----------|-------|
| Data Type | Checkbox |
| Default Value | true |

### Rule__c

```apex
global Id Rule__c
```

The Masking Rule that will be applied to the field. Pick from rules shipped with the package or rules you have created yourself.

**Field Attributes:**

| Attribute | Value |
|-----------|-------|
| Data Type | MaskingRule__mdt |
| Required | true |
| Unique | false |

### Rule__r

```apex
global MaskingRule__mdt Rule__r
```

The Masking Rule that will be applied to the field. Pick from rules shipped with the package or rules you have created yourself.

**Field Attributes:**

| Attribute | Value |
|-----------|-------|
| Data Type | MaskingRule__mdt |
| Required | true |
| Unique | false |

### SObjectType__c

```apex
global Id SObjectType__c
```

The object that contains the field to mask. Select first — the Field picklist filters to fields on whatever object you pick here.

**Field Attributes:**

| Attribute | Value |
|-----------|-------|
| Data Type | EntityDefinition |
| Required | true |
| Unique | false |

### SObjectType__r

```apex
global EntityDefinition SObjectType__r
```

The object that contains the field to mask. Select first — the Field picklist filters to fields on whatever object you pick here.

**Field Attributes:**

| Attribute | Value |
|-----------|-------|
| Data Type | EntityDefinition |
| Required | true |
| Unique | false |

