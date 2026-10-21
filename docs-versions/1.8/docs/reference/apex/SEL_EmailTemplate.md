---
title: "SEL_EmailTemplate"
type: class
pageClass: reference
description: "Selector for the EmailTemplate SObject. Provides default field configuration and query methods for EmailTemplate records."
author: "Jason Van Beukering"
group: "Selectors"
date: "February 2026, May 2026"
since: "1.0"
category: apex
---

# SEL_EmailTemplate

**Class** · Group: `Selectors`

<div class="apex-member apex-class">

```apex
global inherited sharing class SEL_EmailTemplate extends SEL_Base
```

**Extends:** [SEL_Base](SEL_Base.md)

Selector for the EmailTemplate SObject. Provides default field configuration and query methods for EmailTemplate records.

**Example**

```apex
List<EmailTemplate> templates = new SEL_EmailTemplate().findByName(new Set<String>{'WelcomeTemplate'});
EmailTemplate template = (EmailTemplate)new SEL_EmailTemplate().findById(templateId);
```

**See Also:** [SEL_Base](SEL_Base.md)

</div>

---

## Methods

| Method | Description |
|--------|-------------|
| global [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[EmailTemplate](https://developer.salesforce.com/docs/atlas.en-us.object_reference.meta/object_reference/sforce_api_objects_emailtemplate.htm)> [findByName](#findbyname)([Set](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_set.htm)<[String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)> uniqueNames) | Retrieves a list of EmailTemplate records by their DeveloperName field values. |
| global override [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm)> [getFields](#getfields)() | Returns the core fields for EmailTemplate queries. |

### findByName

<div class="apex-member">

```apex
global List<EmailTemplate> findByName(Set<String> uniqueNames)
```

Retrieves a list of EmailTemplate records by their DeveloperName field values.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `uniqueNames` | [Set](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_set.htm) | A set of DeveloperName values for the EmailTemplate records to retrieve |

**Returns** [EmailTemplate](https://developer.salesforce.com/docs/atlas.en-us.object_reference.meta/object_reference/sforce_api_objects_emailtemplate.htm) — A list of EmailTemplate records that match the specified DeveloperName values

**Example**

```apex
Set<String> templateNames = new Set<String>{'WelcomeTemplate', 'ReminderTemplate'};
List<EmailTemplate> templates = new SEL_EmailTemplate().findByName(templateNames);
```

</div>

### getFields

<div class="apex-member">

```apex
global override List<SObjectField> getFields()
```

Returns the core fields for EmailTemplate queries.

**Returns** [SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm) — List of EmailTemplate SObjectField tokens

**Example**

```apex
List<SObjectField> result = instance.getFields();
```

</div>

## Constructors

| Constructor | Description |
|-------------|-------------|
| global [SEL_EmailTemplate](#constructors)() | Constructs an EmailTemplate selector with the EmailTemplate SObjectType. |

### SEL_EmailTemplate()

<div class="apex-member">

```apex
global SEL_EmailTemplate()
```

Constructs an EmailTemplate selector with the EmailTemplate SObjectType.

**Example**

```apex
SEL_EmailTemplate instance = new SEL_EmailTemplate();
```

</div>

