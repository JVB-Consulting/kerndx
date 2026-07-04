---
title: "SEL_OrgWideEmailAddress"
type: class
description: "Selector for the OrgWideEmailAddress SObject. Provides query methods for retrieving organization-wide email addresses configured in Salesforce."
author: "Jason Van Beukering"
group: "Selectors"
date: "February 2026, May 2026"
since: "1.0"
category: apex
---

# SEL_OrgWideEmailAddress

**Class** · Group: `Selectors`

```apex
global inherited sharing class SEL_OrgWideEmailAddress extends SEL_Base
```

**Extends:** [SEL_Base](SEL_Base.md)

Selector for the OrgWideEmailAddress SObject. Provides query methods for retrieving organization-wide email addresses configured in Salesforce.

**Since:** 1.0

**Example:**

```apex
List<OrgWideEmailAddress> addresses = new SEL_OrgWideEmailAddress().findByName(new Set<String>{'noreply@company.com'});
OrgWideEmailAddress randomAddress = (OrgWideEmailAddress)new SEL_OrgWideEmailAddress().getRandomItem();
```

**See Also:** [SEL_Base](SEL_Base.md)

---

## Methods

| Method | Description |
|--------|-------------|
| global [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm) [findByName](#findbyname)([Set](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_set.htm)<[String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)> addresses) | Retrieves OrgWideEmailAddress records matching the provided email addresses. |
| global override [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm) [getFields](#getfields)() | Returns the core fields for OrgWideEmailAddress queries. |
| global override [SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm) [getRandomItem](#getrandomitem)() | Retrieves a random OrgWideEmailAddress that is available to all profiles. |
| global [SEL_OrgWideEmailAddress](#sel_orgwideemailaddress)() | Constructs an OrgWideEmailAddress selector. |

---

## Method Details

### SEL_OrgWideEmailAddress

```apex
global SEL_OrgWideEmailAddress()
```

Constructs an OrgWideEmailAddress selector.

**Since:** 1.0

**Example:**

```apex
SEL_OrgWideEmailAddress instance = new SEL_OrgWideEmailAddress();
```

### findByName

```apex
global List<OrgWideEmailAddress> findByName(Set<String> addresses)
```

Retrieves OrgWideEmailAddress records matching the provided email addresses.

**Parameters:**

- `addresses` ([Set](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_set.htm)) - A set of email addresses to search for

**Returns:** [OrgWideEmailAddress](https://developer.salesforce.com/docs/atlas.en-us.object_reference.meta/object_reference/sforce_api_objects_orgwideemailaddress.htm) - List of matching OrgWideEmailAddress records

**Since:** 1.0

**Example:**

```apex
List<OrgWideEmailAddress> addresses = new SEL_OrgWideEmailAddress()
    .findByName(new Set<String>{'noreply@company.com'});
```

### getFields

```apex
global override List<SObjectField> getFields()
```

Returns the core fields for OrgWideEmailAddress queries.

**Returns:** [SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm) - List of OrgWideEmailAddress SObjectField tokens

**Since:** 1.0

**Example:**

```apex
List<SObjectField> result = instance.getFields();
```

### getRandomItem

```apex
global override SObject getRandomItem()
```

Retrieves a random OrgWideEmailAddress that is available to all profiles.

**Returns:** [SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm) - A random OrgWideEmailAddress available to all profiles, or null if none found

**Since:** 1.0

**Example:**

```apex
OrgWideEmailAddress randomEmail = new SEL_OrgWideEmailAddress().getRandomItem();
```

