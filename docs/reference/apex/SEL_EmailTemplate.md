---
title: "SEL_EmailTemplate"
type: class
description: "Selector for the EmailTemplate SObject. Provides default field configuration and query methods for EmailTemplate records."
author: "Jason Van Beukering"
group: "Selectors"
date: "February 2026, May 2026"
since: "1.0"
category: apex
---

# SEL_EmailTemplate

**Class** · Group: `Selectors`

```apex
global inherited sharing class SEL_EmailTemplate extends SEL_Base
```

**Extends:** [SEL_Base](SEL_Base.md)

Selector for the EmailTemplate SObject. Provides default field configuration and query methods for EmailTemplate records.

**Since:** 1.0

**Example:**

```apex
List<EmailTemplate> templates = new SEL_EmailTemplate().findByName(new Set<String>{'WelcomeTemplate'});
EmailTemplate template = (EmailTemplate)new SEL_EmailTemplate().findById(templateId);
```

**See Also:** [SEL_Base](SEL_Base.md)

---

## Methods

| Method | Description |
|--------|-------------|
| global [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[EmailTemplate](https://developer.salesforce.com/docs/atlas.en-us.object_reference.meta/object_reference/sforce_api_objects_emailtemplate.htm)> [findByName](#findbyname)([Set](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_set.htm)<[String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)> uniqueNames) | Retrieves a list of EmailTemplate records by their DeveloperName field values. |
| global override [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm)> [getFields](#getfields)() | Returns the core fields for EmailTemplate queries. |
| global  [SEL_EmailTemplate](#sel_emailtemplate)() | Constructs an EmailTemplate selector with the EmailTemplate SObjectType. |

---

## Method Details

### SEL_EmailTemplate

```apex
global SEL_EmailTemplate()
```

Constructs an EmailTemplate selector with the EmailTemplate SObjectType.

**Since:** 1.0

**Example:**

```apex
SEL_EmailTemplate instance = new SEL_EmailTemplate();
```

### findByName

```apex
global List<EmailTemplate> findByName(Set<String> uniqueNames)
```

Retrieves a list of EmailTemplate records by their DeveloperName field values.

**Parameters:**

- `uniqueNames` ([Set](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_set.htm)) - A set of DeveloperName values for the EmailTemplate records to retrieve

**Returns:** [EmailTemplate](https://developer.salesforce.com/docs/atlas.en-us.object_reference.meta/object_reference/sforce_api_objects_emailtemplate.htm) - A list of EmailTemplate records that match the specified DeveloperName values

**Since:** 1.0

**Example:**

```apex
Set<String> templateNames = new Set<String>{'WelcomeTemplate', 'ReminderTemplate'};
List<EmailTemplate> templates = new SEL_EmailTemplate().findByName(templateNames);
```

### getFields

```apex
global override List<SObjectField> getFields()
```

Returns the core fields for EmailTemplate queries.

**Returns:** [SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm) - List of EmailTemplate SObjectField tokens

**Since:** 1.0

**Example:**

```apex
List<SObjectField> result = instance.getFields();
```

