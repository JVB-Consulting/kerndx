---
title: "TRG_ExecuteValidationRules"
type: class
pageClass: reference
description: "Pre-built trigger action that executes formula-driven validation rules. This class implements all trigger interfaces and automatically executes validation rules configured via ValidationRuleGroup__mdt"
author: "Jason Van Beukering"
group: "Validation"
date: "January 2026, May 2026"
since: "1.0"
category: apex
---

# TRG_ExecuteValidationRules

**Class** · Group: `Validation`

<div class="apex-member apex-class">

```apex
global inherited sharing class TRG_ExecuteValidationRules extends TRG_Base implements IF_Trigger.BeforeInsert, IF_Trigger.AfterInsert, IF_Trigger.BeforeUpdate, IF_Trigger.AfterUpdate, IF_Trigger.BeforeDelete, IF_Trigger.AfterDelete, IF_Trigger.AfterUndelete
```

**Extends:** [TRG_Base](TRG_Base.md)

**Implements:** [IF_Trigger.BeforeInsert](IF_Trigger.BeforeInsert.md), [IF_Trigger.AfterInsert](IF_Trigger.AfterInsert.md), [IF_Trigger.BeforeUpdate](IF_Trigger.BeforeUpdate.md), [IF_Trigger.AfterUpdate](IF_Trigger.AfterUpdate.md), [IF_Trigger.BeforeDelete](IF_Trigger.BeforeDelete.md), [IF_Trigger.AfterDelete](IF_Trigger.AfterDelete.md), [IF_Trigger.AfterUndelete](IF_Trigger.AfterUndelete.md)

**Known Derived Types:** [IF_Trigger.AfterDelete.afterDelete(List<SObject>)](IF_Trigger.AfterDelete.md#afterdelete), [IF_Trigger.AfterInsert.afterInsert(List<SObject>)](IF_Trigger.AfterInsert.md#afterinsert), [IF_Trigger.AfterUndelete.afterUndelete(List<SObject>)](IF_Trigger.AfterUndelete.md#afterundelete), [IF_Trigger.AfterUpdate.afterUpdate(List<SObject>,List<SObject>)](IF_Trigger.AfterUpdate.md#afterupdate), [IF_Trigger.BeforeDelete.beforeDelete(List<SObject>)](IF_Trigger.BeforeDelete.md#beforedelete), [IF_Trigger.BeforeInsert.beforeInsert(List<SObject>)](IF_Trigger.BeforeInsert.md#beforeinsert), [IF_Trigger.BeforeUpdate.beforeUpdate(List<SObject>,List<SObject>)](IF_Trigger.BeforeUpdate.md#beforeupdate)

Pre-built trigger action that executes formula-driven validation rules. This class implements all trigger interfaces and automatically executes validation rules configured via ValidationRuleGroup__mdt and ValidationRule__mdt for the current trigger context. Subscriber Org Setup: Create TriggerSetting__mdt for your object (if not already exists) Create TriggerAction__mdt pointing to kern.TRG_ExecuteValidationRules Configure ValidationRuleGroup__mdt linked to your TriggerSetting Create ValidationRule__mdt records with formulas and error messages

**Example**

```apex
// TriggerAction__mdt configuration (no code required)
DeveloperName: Execute_Account_Validation_Rules
MasterLabel: Execute Account Validation Rules
ApexClassName__c: kern.TRG_ExecuteValidationRules
TriggerSetting__c: Account_Trigger_Setting
Event__c: Before Insert
Order__c: 10
Description__c: Executes formula-driven validation rules for Account records
```

**See Also:** [UTIL_ValidationRule](UTIL_ValidationRule.md), [ValidationRuleGroup__mdt](../metadata/ValidationRuleGroup__mdt.md), [ValidationRule__mdt](../metadata/ValidationRule__mdt.md)

</div>

---

## Methods

| Method | Description |
|--------|-------------|
| global void [afterDelete](#afterdelete)([List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm)> oldRecords) | Executes validation rules after records are deleted. |
| global void [afterInsert](#afterinsert)([List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm)> newRecords) | Executes validation rules after new records are inserted. |
| global void [afterUndelete](#afterundelete)([List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm)> newRecords) | Executes validation rules after records are undeleted. |
| global void [afterUpdate](#afterupdate)([List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm)> newRecords, [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm)> oldRecords) | Executes validation rules after records are updated. |
| global void [beforeDelete](#beforedelete)([List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm)> oldRecords) | Executes validation rules before records are deleted. |
| global void [beforeInsert](#beforeinsert)([List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm)> newRecords) | Executes validation rules before new records are inserted. |
| global void [beforeUpdate](#beforeupdate)([List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm)> newRecords, [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm)> oldRecords) | Executes validation rules before records are updated. |

### afterDelete

<div class="apex-member">

```apex
global void afterDelete(List<SObject> oldRecords)
```

Executes validation rules after records are deleted.
Typically used for warning-only validations that log but don't block.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `oldRecords` | [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm) | The list of deleted records |

**Example**

```apex
instance.afterDelete(records);
```

</div>

### afterInsert

<div class="apex-member">

```apex
global void afterInsert(List<SObject> newRecords)
```

Executes validation rules after new records are inserted.
Typically used for warning-only validations that log but don't block.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `newRecords` | [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm) | The list of newly inserted records |

**Example**

```apex
instance.afterInsert(records);
```

</div>

### afterUndelete

<div class="apex-member">

```apex
global void afterUndelete(List<SObject> newRecords)
```

Executes validation rules after records are undeleted.
Typically used for warning-only validations that log but don't block.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `newRecords` | [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm) | The list of undeleted records |

**Example**

```apex
instance.afterUndelete(records);
```

</div>

### afterUpdate

<div class="apex-member">

```apex
global void afterUpdate(List<SObject> newRecords, List<SObject> oldRecords)
```

Executes validation rules after records are updated.
Typically used for warning-only validations that log but don't block.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `newRecords` | [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm) | The list of records with new values |
| `oldRecords` | [SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm) | The list of records with old values |

**Example**

```apex
instance.afterUpdate(records, records);
```

</div>

### beforeDelete

<div class="apex-member">

```apex
global void beforeDelete(List<SObject> oldRecords)
```

Executes validation rules before records are deleted.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `oldRecords` | [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm) | The list of records to be deleted |

**Example**

```apex
instance.beforeDelete(records);
```

</div>

### beforeInsert

<div class="apex-member">

```apex
global void beforeInsert(List<SObject> newRecords)
```

Executes validation rules before new records are inserted.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `newRecords` | [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm) | The list of new records to validate |

**Example**

```apex
instance.beforeInsert(records);
```

</div>

### beforeUpdate

<div class="apex-member">

```apex
global void beforeUpdate(List<SObject> newRecords, List<SObject> oldRecords)
```

Executes validation rules before records are updated.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `newRecords` | [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm) | The list of records with new values |
| `oldRecords` | [SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm) | The list of records with old values |

**Example**

```apex
instance.beforeUpdate(records, records);
```

</div>

