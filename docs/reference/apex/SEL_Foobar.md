---
title: "SEL_Foobar"
type: class
pageClass: reference
description: "Selector for the Foobar__c SObject. Provides query methods and field/metadata constants for the framework's test data object."
author: "Jason Van Beukering"
group: "Selectors"
date: "February 2026, May 2026"
since: "1.0"
category: apex
---

# SEL_Foobar

**Class** · Group: `Selectors`

```apex
global inherited sharing class SEL_Foobar extends SEL_Base
```

**Extends:** [SEL_Base](SEL_Base.md)

Selector for the Foobar__c SObject. Provides query methods and field/metadata constants for the framework's test data object.

**Since:** 1.0

**Example:**

```apex
Foobar__c record = (Foobar__c)new SEL_Foobar().findById(recordId);
List<Foobar__c> children = new SEL_Foobar().findByParentId(parentId);
List<Foobar__c> records = new SEL_Foobar().findByField(Foobar__c.Picklist__c, 'Active');
```

**See Also:** [SEL_Base](SEL_Base.md)

---

