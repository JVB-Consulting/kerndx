---
title: "SEL_Profile"
type: class
description: "Selector for the Profile SObject. Provides default field configuration, query methods, and commonly used profile name constants."
author: "Jason Van Beukering"
group: "Selectors"
date: "February 2026, May 2026"
since: "1.0"
category: apex
---

# SEL_Profile

**Class** · Group: `Selectors`

```apex
global inherited sharing class SEL_Profile extends SEL_Base
```

**Extends:** [SEL_Base](SEL_Base.md)

Selector for the Profile SObject. Provides default field configuration, query methods, and commonly used profile name constants.

**Since:** 1.0

**Example:**

```apex
Profile adminProfile = new SEL_Profile().findByName('System Administrator');
Profile standardUser = new SEL_Profile().findByName('Standard User');
Profile profile = (Profile)new SEL_Profile().findById(profileId);
```

**See Also:** [SEL_Base](SEL_Base.md)

---

## Methods

| Method | Description |
|--------|-------------|
| global [Profile](https://developer.salesforce.com/docs/atlas.en-us.object_reference.meta/object_reference/sforce_api_objects_profile.htm) [findByName](#findbyname)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) profileName) | Finds a Profile record by name. |
| global override [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm)> [getFields](#getfields)() | Returns the core fields for Profile queries. |
| global  [SEL_Profile](#sel_profile)() | Constructs a Profile selector with the Profile SObjectType. |

---

## Method Details

### SEL_Profile

```apex
global SEL_Profile()
```

Constructs a Profile selector with the Profile SObjectType.

**Since:** 1.0

**Example:**

```apex
SEL_Profile instance = new SEL_Profile();
```

### findByName

```apex
global Profile findByName(String profileName)
```

Finds a Profile record by name. Results are cached within the transaction
to avoid repeated SOQL queries for the same profile.

**Parameters:**

- `profileName` ([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)) - The name of the profile to retrieve

**Returns:** [Profile](https://developer.salesforce.com/docs/atlas.en-us.object_reference.meta/object_reference/sforce_api_objects_profile.htm) - The matching Profile record, or null if not found

**Since:** 1.0

**Example:**

```apex
Profile adminProfile = new SEL_Profile().findByName('System Administrator');
```

### getFields

```apex
global override List<SObjectField> getFields()
```

Returns the core fields for Profile queries.

**Returns:** [SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm) - List of Profile SObjectField tokens

**Since:** 1.0

**Example:**

```apex
List<SObjectField> result = instance.getFields();
```

