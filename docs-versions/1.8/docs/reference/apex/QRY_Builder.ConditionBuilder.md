---
title: "QRY_Builder.ConditionBuilder"
type: class
pageClass: reference
description: "Fluent builder for field-level conditions (WHERE and HAVING)."
since: "1.0"
category: apex
---

# QRY_Builder.ConditionBuilder

**Class**

<div class="apex-member apex-class">

```apex
global inherited sharing class QRY_Builder.ConditionBuilder
```

Fluent builder for field-level conditions (WHERE and HAVING).

</div>

---

## Methods

| Method | Description |
|--------|-------------|
| global [QRY_Builder.Builder](QRY_Builder.Builder.md) [contains](#contains)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) value) | Adds a LIKE condition with wildcards on both sides (contains). |
| global [QRY_Builder.Builder](QRY_Builder.Builder.md) [endsWith](#endswith)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) value) | Adds a LIKE condition with wildcard at start (ends with). |
| global [QRY_Builder.Builder](QRY_Builder.Builder.md) [equals](#equals)([Object](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_System_Object.htm) value) | Adds an = condition. |
| global [QRY_Builder.Builder](QRY_Builder.Builder.md) [equals](#equals)([SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm) record) | Adds an = condition comparing to an SObject's Id. |
| global [QRY_Builder.Builder](QRY_Builder.Builder.md) [excludes](#excludes)([List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[Object](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_System_Object.htm)> values) | Adds an EXCLUDES condition for multi-picklist fields. |
| global [QRY_Builder.Builder](QRY_Builder.Builder.md) [excludes](#excludes)([Set](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_set.htm)<[Object](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_System_Object.htm)> values) | Adds an EXCLUDES condition for multi-picklist fields using a Set. |
| global [QRY_Builder.Builder](QRY_Builder.Builder.md) [excludesStrict](#excludesstrict)([List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[Object](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_System_Object.htm)> values) | Adds an EXCLUDES condition with strict empty list handling. |
| global [QRY_Builder.Builder](QRY_Builder.Builder.md) [excludesStrict](#excludesstrict)([Set](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_set.htm)<[Object](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_System_Object.htm)> values) | Adds an EXCLUDES condition with strict empty set handling. |
| global [QRY_Builder.Builder](QRY_Builder.Builder.md) [greaterThan](#greaterthan)([Object](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_System_Object.htm) value) | Adds a > condition. |
| global [QRY_Builder.Builder](QRY_Builder.Builder.md) [greaterThanOrEquals](#greaterthanorequals)([Object](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_System_Object.htm) value) | Adds a >= condition. |
| global [QRY_Builder.Builder](QRY_Builder.Builder.md) [includes](#includes)([List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[Object](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_System_Object.htm)> values) | Adds an INCLUDES condition for multi-picklist fields. |
| global [QRY_Builder.Builder](QRY_Builder.Builder.md) [includes](#includes)([Set](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_set.htm)<[Object](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_System_Object.htm)> values) | Adds an INCLUDES condition for multi-picklist fields using a Set. |
| global [QRY_Builder.Builder](QRY_Builder.Builder.md) [includesStrict](#includesstrict)([List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[Object](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_System_Object.htm)> values) | Adds an INCLUDES condition with strict empty list handling. |
| global [QRY_Builder.Builder](QRY_Builder.Builder.md) [includesStrict](#includesstrict)([Set](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_set.htm)<[Object](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_System_Object.htm)> values) | Adds an INCLUDES condition with strict empty set handling. |
| global [QRY_Builder.Builder](QRY_Builder.Builder.md) [isIn](#isin)([List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[Object](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_System_Object.htm)> values) | Adds an IN condition using a List. |
| global [QRY_Builder.Builder](QRY_Builder.Builder.md) [isIn](#isin)([List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm)> records) | Adds an IN condition using a List of SObjects. |
| global [QRY_Builder.Builder](QRY_Builder.Builder.md) [isIn](#isin)([List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm)> records, [SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm) field) | Adds an IN condition by extracting field values from SObjects. |
| global [QRY_Builder.Builder](QRY_Builder.Builder.md) [isIn](#isin)([QRY_Builder.Builder](QRY_Builder.Builder.md) subquery) | Adds a semi-join IN condition using a subquery. |
| global [QRY_Builder.Builder](QRY_Builder.Builder.md) [isIn](#isin)([Set](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_set.htm)<[Object](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_System_Object.htm)> values) | Adds an IN condition using a Set. |
| global [QRY_Builder.Builder](QRY_Builder.Builder.md) [isInStrict](#isinstrict)([List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[Object](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_System_Object.htm)> values) | Adds an IN condition with strict empty list handling. |
| global [QRY_Builder.Builder](QRY_Builder.Builder.md) [isInStrict](#isinstrict)([List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm)> records) | Adds an IN condition using SObjects with strict handling. |
| global [QRY_Builder.Builder](QRY_Builder.Builder.md) [isInStrict](#isinstrict)([List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm)> records, [SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm) field) | Adds an IN condition by extracting field values with strict handling. |
| global [QRY_Builder.Builder](QRY_Builder.Builder.md) [isInStrict](#isinstrict)([Set](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_set.htm)<[Object](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_System_Object.htm)> values) | Adds an IN condition with strict empty set handling. |
| global [QRY_Builder.Builder](QRY_Builder.Builder.md) [isNotNull](#isnotnull)() | Adds an IS NOT NULL condition. |
| global [QRY_Builder.Builder](QRY_Builder.Builder.md) [isNull](#isnull)() | Adds an IS NULL condition. |
| global [QRY_Builder.Builder](QRY_Builder.Builder.md) [lessThan](#lessthan)([Object](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_System_Object.htm) value) | Adds a < condition. |
| global [QRY_Builder.Builder](QRY_Builder.Builder.md) [lessThanOrEquals](#lessthanorequals)([Object](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_System_Object.htm) value) | Adds a <= condition. |
| global [QRY_Builder.Builder](QRY_Builder.Builder.md) [notEquals](#notequals)([Object](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_System_Object.htm) value) | Adds a != condition. |
| global [QRY_Builder.Builder](QRY_Builder.Builder.md) [notEquals](#notequals)([SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm) record) | Adds a != condition comparing to an SObject's Id. |
| global [QRY_Builder.Builder](QRY_Builder.Builder.md) [notIn](#notin)([QRY_Builder.Builder](QRY_Builder.Builder.md) subquery) | Adds an anti-join NOT IN condition using a subquery. |
| global [QRY_Builder.Builder](QRY_Builder.Builder.md) [notInSet](#notinset)([List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[Object](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_System_Object.htm)> values) | Adds a NOT IN condition using a List. |
| global [QRY_Builder.Builder](QRY_Builder.Builder.md) [notInSet](#notinset)([List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm)> records) | Adds a NOT IN condition using a List of SObjects. |
| global [QRY_Builder.Builder](QRY_Builder.Builder.md) [notInSet](#notinset)([List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm)> records, [SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm) field) | Adds a NOT IN condition by extracting field values from SObjects. |
| global [QRY_Builder.Builder](QRY_Builder.Builder.md) [notInSet](#notinset)([Set](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_set.htm)<[Object](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_System_Object.htm)> values) | Adds a NOT IN condition using a Set. |
| global [QRY_Builder.Builder](QRY_Builder.Builder.md) [notInSetStrict](#notinsetstrict)([List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[Object](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_System_Object.htm)> values) | Adds a NOT IN condition with strict empty list handling. |
| global [QRY_Builder.Builder](QRY_Builder.Builder.md) [notInSetStrict](#notinsetstrict)([List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm)> records) | Adds a NOT IN condition using SObjects with strict handling. |
| global [QRY_Builder.Builder](QRY_Builder.Builder.md) [notInSetStrict](#notinsetstrict)([List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm)> records, [SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm) field) | Adds a NOT IN condition by extracting field values with strict handling. |
| global [QRY_Builder.Builder](QRY_Builder.Builder.md) [notInSetStrict](#notinsetstrict)([Set](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_set.htm)<[Object](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_System_Object.htm)> values) | Adds a NOT IN condition with strict empty set handling. |
| global [QRY_Builder.Builder](QRY_Builder.Builder.md) [startsWith](#startswith)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) value) | Adds a LIKE condition with wildcard at end (starts with). |

### contains

<div class="apex-member">

```apex
global QRY_Builder.Builder contains(String value)
```

Adds a LIKE condition with wildcards on both sides (contains).

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `value` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | Text to search for |

**Returns** [QRY_Builder.Builder](QRY_Builder.Builder.md) — Builder for chaining

**Example**

```apex
List<Account> accounts = QRY_Builder.selectFrom(Account.SObjectType)
    .condition(Account.Name).contains('Corp')
    .toList();
```

</div>

### endsWith

<div class="apex-member">

```apex
global QRY_Builder.Builder endsWith(String value)
```

Adds a LIKE condition with wildcard at start (ends with).

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `value` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | Text suffix |

**Returns** [QRY_Builder.Builder](QRY_Builder.Builder.md) — Builder for chaining

**Example**

```apex
List<Account> accounts = QRY_Builder.selectFrom(Account.SObjectType)
    .condition(Account.Name).endsWith('Inc.')
    .toList();
```

</div>

### equals

<div class="apex-member">

```apex
global QRY_Builder.Builder equals(Object value)
```

Adds an = condition.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `value` | [Object](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_System_Object.htm) | Value to compare against |

**Returns** [QRY_Builder.Builder](QRY_Builder.Builder.md) — Builder for chaining

**Example**

```apex
List<Account> accounts = QRY_Builder.selectFrom(Account.SObjectType)
    .condition(Account.Name).equals('Acme Corp')
    .toList();
```

</div>

<div class="apex-member">

```apex
global QRY_Builder.Builder equals(SObject record)
```

Adds an = condition comparing to an SObject's Id.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `record` | [SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm) | SObject whose Id to compare against |

**Returns** [QRY_Builder.Builder](QRY_Builder.Builder.md) — Builder for chaining

**Example**

```apex
List<Contact> contacts = QRY_Builder.selectFrom(Contact.SObjectType)
    .condition(Contact.AccountId).equals(account)
    .toList();
```

</div>

### excludes

<div class="apex-member">

```apex
global QRY_Builder.Builder excludes(List<Object> values)
```

Adds an EXCLUDES condition for multi-picklist fields.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `values` | [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm) | Values that must not be selected |

**Returns** [QRY_Builder.Builder](QRY_Builder.Builder.md) — Builder for chaining

**Example**

```apex
List<Object> excluded = new List<Object>{'Inactive', 'Archived'};
List<Lead> leads = QRY_Builder.selectFrom(Lead.SObjectType)
    .condition('Tags__c').excludes(excluded)
    .toList();
```

</div>

<div class="apex-member">

```apex
global QRY_Builder.Builder excludes(Set<Object> values)
```

Adds an EXCLUDES condition for multi-picklist fields using a Set.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `values` | [Set](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_set.htm) | Values that must not be selected |

**Returns** [QRY_Builder.Builder](QRY_Builder.Builder.md) — Builder for chaining

**Example**

```apex
Set<Object> excluded = new Set<Object>{'Inactive', 'Archived'};
List<Lead> leads = QRY_Builder.selectFrom(Lead.SObjectType)
    .condition('Tags__c').excludes(excluded)
    .toList();
```

</div>

### excludesStrict

<div class="apex-member">

```apex
global QRY_Builder.Builder excludesStrict(List<Object> values)
```

Adds an EXCLUDES condition with strict empty list handling.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `values` | [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm) | Values that must not be selected (must not be null or empty) |

**Returns** [QRY_Builder.Builder](QRY_Builder.Builder.md) — Builder for chaining

**Throws**

| Exception | Description |
|-----------|-------------|
| [IllegalArgumentException](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_classes_exception_methods.htm) | if values is null or empty |

**Example**

```apex
List<Object> excluded = new List<Object>{'Inactive', 'Archived'};
List<Lead> leads = QRY_Builder.selectFrom(Lead.SObjectType)
    .condition('Tags__c').excludesStrict(excluded)
    .toList();
```

</div>

<div class="apex-member">

```apex
global QRY_Builder.Builder excludesStrict(Set<Object> values)
```

Adds an EXCLUDES condition with strict empty set handling.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `values` | [Set](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_set.htm) | Values that must not be selected (must not be null or empty) |

**Returns** [QRY_Builder.Builder](QRY_Builder.Builder.md) — Builder for chaining

**Throws**

| Exception | Description |
|-----------|-------------|
| [IllegalArgumentException](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_classes_exception_methods.htm) | if values is null or empty |

**Example**

```apex
Set<Object> excluded = new Set<Object>{'Inactive', 'Archived'};
List<Lead> leads = QRY_Builder.selectFrom(Lead.SObjectType)
    .condition('Tags__c').excludesStrict(excluded)
    .toList();
```

</div>

### greaterThan

<div class="apex-member">

```apex
global QRY_Builder.Builder greaterThan(Object value)
```

Adds a > condition.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `value` | [Object](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_System_Object.htm) | Value to compare against |

**Returns** [QRY_Builder.Builder](QRY_Builder.Builder.md) — Builder for chaining

**Example**

```apex
List<Account> accounts = QRY_Builder.selectFrom(Account.SObjectType)
    .condition(Account.AnnualRevenue).greaterThan(1000000)
    .toList();
```

</div>

### greaterThanOrEquals

<div class="apex-member">

```apex
global QRY_Builder.Builder greaterThanOrEquals(Object value)
```

Adds a >= condition.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `value` | [Object](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_System_Object.htm) | Value to compare against |

**Returns** [QRY_Builder.Builder](QRY_Builder.Builder.md) — Builder for chaining

**Example**

```apex
List<Account> accounts = QRY_Builder.selectFrom(Account.SObjectType)
    .condition(Account.NumberOfEmployees).greaterThanOrEquals(100)
    .toList();
```

</div>

### includes

<div class="apex-member">

```apex
global QRY_Builder.Builder includes(List<Object> values)
```

Adds an INCLUDES condition for multi-picklist fields.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `values` | [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm) | Values that must all be selected |

**Returns** [QRY_Builder.Builder](QRY_Builder.Builder.md) — Builder for chaining

**Example**

```apex
List<Object> interests = new List<Object>{'Technology', 'Finance'};
List<Lead> leads = QRY_Builder.selectFrom(Lead.SObjectType)
    .condition('Interests__c').includes(interests)
    .toList();
```

</div>

<div class="apex-member">

```apex
global QRY_Builder.Builder includes(Set<Object> values)
```

Adds an INCLUDES condition for multi-picklist fields using a Set.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `values` | [Set](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_set.htm) | Values that must all be selected |

**Returns** [QRY_Builder.Builder](QRY_Builder.Builder.md) — Builder for chaining

**Example**

```apex
Set<Object> interests = new Set<Object>{'Technology', 'Finance'};
List<Lead> leads = QRY_Builder.selectFrom(Lead.SObjectType)
    .condition('Interests__c').includes(interests)
    .toList();
```

</div>

### includesStrict

<div class="apex-member">

```apex
global QRY_Builder.Builder includesStrict(List<Object> values)
```

Adds an INCLUDES condition with strict empty list handling.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `values` | [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm) | Values that must all be selected (must not be null or empty) |

**Returns** [QRY_Builder.Builder](QRY_Builder.Builder.md) — Builder for chaining

**Throws**

| Exception | Description |
|-----------|-------------|
| [IllegalArgumentException](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_classes_exception_methods.htm) | if values is null or empty |

**Example**

```apex
List<Object> interests = new List<Object>{'Technology', 'Finance'};
List<Lead> leads = QRY_Builder.selectFrom(Lead.SObjectType)
    .condition('Interests__c').includesStrict(interests)
    .toList();
```

</div>

<div class="apex-member">

```apex
global QRY_Builder.Builder includesStrict(Set<Object> values)
```

Adds an INCLUDES condition with strict empty set handling.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `values` | [Set](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_set.htm) | Values that must all be selected (must not be null or empty) |

**Returns** [QRY_Builder.Builder](QRY_Builder.Builder.md) — Builder for chaining

**Throws**

| Exception | Description |
|-----------|-------------|
| [IllegalArgumentException](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_classes_exception_methods.htm) | if values is null or empty |

**Example**

```apex
Set<Object> interests = new Set<Object>{'Technology', 'Finance'};
List<Lead> leads = QRY_Builder.selectFrom(Lead.SObjectType)
    .condition('Interests__c').includesStrict(interests)
    .toList();
```

</div>

### isIn

<div class="apex-member">

```apex
global QRY_Builder.Builder isIn(List<Object> values)
```

Adds an IN condition using a List.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `values` | [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm) | Values to include |

**Returns** [QRY_Builder.Builder](QRY_Builder.Builder.md) — Builder for chaining

**Example**

```apex
List<Object> types = new List<Object>{'Customer', 'Partner'};
List<Account> accounts = QRY_Builder.selectFrom(Account.SObjectType)
    .condition(Account.Type).isIn(types)
    .toList();
```

</div>

<div class="apex-member">

```apex
global QRY_Builder.Builder isIn(List<SObject> records)
```

Adds an IN condition using a List of SObjects.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `records` | [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm) | SObjects to include (their Ids will be matched) |

**Returns** [QRY_Builder.Builder](QRY_Builder.Builder.md) — Builder for chaining

**Example**

```apex
List<Contact> contacts = QRY_Builder.selectFrom(Contact.SObjectType)
    .condition(Contact.AccountId).isIn(parentAccounts)
    .toList();
```

</div>

<div class="apex-member">

```apex
global QRY_Builder.Builder isIn(List<SObject> records, SObjectField field)
```

Adds an IN condition by extracting field values from SObjects.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `records` | [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm) | SObjects to extract values from |
| `field` | [SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm) | The field to extract values from |

**Returns** [QRY_Builder.Builder](QRY_Builder.Builder.md) — Builder for chaining

**Example**

```apex
List<Account> accounts = QRY_Builder.selectFrom(Account.SObjectType)
    .condition(Account.Id).isIn(contacts, Contact.AccountId)
    .toList();
```

</div>

<div class="apex-member">

```apex
global QRY_Builder.Builder isIn(QRY_Builder.Builder subquery)
```

Adds a semi-join IN condition using a subquery.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `subquery` | [QRY_Builder.Builder](QRY_Builder.Builder.md) | Builder representing the subquery |

**Returns** [QRY_Builder.Builder](QRY_Builder.Builder.md) — Builder for chaining

**Example**

```apex
QRY_Builder.Builder subquery = QRY_Builder.selectFrom(Contact.SObjectType)
    .fields(new List<SObjectField>{Contact.AccountId})
    .condition(Contact.Email).isNotNull();
List<Account> accounts = QRY_Builder.selectFrom(Account.SObjectType)
    .condition(Account.Id).isIn(subquery)
    .toList();
```

</div>

<div class="apex-member">

```apex
global QRY_Builder.Builder isIn(Set<Object> values)
```

Adds an IN condition using a Set.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `values` | [Set](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_set.htm) | Values to include |

**Returns** [QRY_Builder.Builder](QRY_Builder.Builder.md) — Builder for chaining

**Example**

```apex
Set<Object> industries = new Set<Object>{'Technology', 'Finance'};
List<Account> accounts = QRY_Builder.selectFrom(Account.SObjectType)
    .condition(Account.Industry).isIn(industries)
    .toList();
```

</div>

### isInStrict

<div class="apex-member">

```apex
global QRY_Builder.Builder isInStrict(List<Object> values)
```

Adds an IN condition with strict empty list handling.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `values` | [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm) | Values to include (must not be null or empty) |

**Returns** [QRY_Builder.Builder](QRY_Builder.Builder.md) — Builder for chaining

**Throws**

| Exception | Description |
|-----------|-------------|
| [IllegalArgumentException](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_classes_exception_methods.htm) | if values is null or empty |

**Example**

```apex
List<Object> statuses = new List<Object>{'Active', 'Pending'};
List<Account> accounts = QRY_Builder.selectFrom(Account.SObjectType)
    .condition(Account.Type).isInStrict(statuses)
    .toList();
```

</div>

<div class="apex-member">

```apex
global QRY_Builder.Builder isInStrict(List<SObject> records)
```

Adds an IN condition using SObjects with strict handling.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `records` | [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm) | SObjects to include (must not be null or empty) |

**Returns** [QRY_Builder.Builder](QRY_Builder.Builder.md) — Builder for chaining

**Throws**

| Exception | Description |
|-----------|-------------|
| [IllegalArgumentException](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_classes_exception_methods.htm) | if records is null or empty |

**Example**

```apex
List<Account> parents = [SELECT Id FROM Account LIMIT 10];
List<Contact> contacts = QRY_Builder.selectFrom(Contact.SObjectType)
    .condition(Contact.AccountId).isInStrict(parents)
    .toList();
```

</div>

<div class="apex-member">

```apex
global QRY_Builder.Builder isInStrict(List<SObject> records, SObjectField field)
```

Adds an IN condition by extracting field values with strict handling.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `records` | [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm) | SObjects to extract values from (must not be null or empty) |
| `field` | [SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm) | The field to extract values from |

**Returns** [QRY_Builder.Builder](QRY_Builder.Builder.md) — Builder for chaining

**Throws**

| Exception | Description |
|-----------|-------------|
| [IllegalArgumentException](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_classes_exception_methods.htm) | if records is null or empty |

**Example**

```apex
List<Contact> contacts = [SELECT AccountId FROM Contact LIMIT 10];
List<Account> accounts = QRY_Builder.selectFrom(Account.SObjectType)
    .condition(Account.Id).isInStrict(contacts, Contact.AccountId)
    .toList();
```

</div>

<div class="apex-member">

```apex
global QRY_Builder.Builder isInStrict(Set<Object> values)
```

Adds an IN condition with strict empty set handling.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `values` | [Set](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_set.htm) | Values to include (must not be null or empty) |

**Returns** [QRY_Builder.Builder](QRY_Builder.Builder.md) — Builder for chaining

**Throws**

| Exception | Description |
|-----------|-------------|
| [IllegalArgumentException](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_classes_exception_methods.htm) | if values is null or empty |

**Example**

```apex
Set<Object> statuses = new Set<Object>{'Active', 'Pending'};
List<Account> accounts = QRY_Builder.selectFrom(Account.SObjectType)
    .condition(Account.Type).isInStrict(statuses)
    .toList();
```

</div>

### isNotNull

<div class="apex-member">

```apex
global QRY_Builder.Builder isNotNull()
```

Adds an IS NOT NULL condition.

**Returns** [QRY_Builder.Builder](QRY_Builder.Builder.md) — Builder for chaining

**Example**

```apex
List<Contact> contacts = QRY_Builder.selectFrom(Contact.SObjectType)
    .condition(Contact.Email).isNotNull()
    .toList();
```

</div>

### isNull

<div class="apex-member">

```apex
global QRY_Builder.Builder isNull()
```

Adds an IS NULL condition.

**Returns** [QRY_Builder.Builder](QRY_Builder.Builder.md) — Builder for chaining

**Example**

```apex
List<Contact> contacts = QRY_Builder.selectFrom(Contact.SObjectType)
    .condition(Contact.Email).isNull()
    .toList();
```

</div>

### lessThan

<div class="apex-member">

```apex
global QRY_Builder.Builder lessThan(Object value)
```

Adds a < condition.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `value` | [Object](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_System_Object.htm) | Value to compare against |

**Returns** [QRY_Builder.Builder](QRY_Builder.Builder.md) — Builder for chaining

**Example**

```apex
List<Account> accounts = QRY_Builder.selectFrom(Account.SObjectType)
    .condition(Account.AnnualRevenue).lessThan(50000)
    .toList();
```

</div>

### lessThanOrEquals

<div class="apex-member">

```apex
global QRY_Builder.Builder lessThanOrEquals(Object value)
```

Adds a <= condition.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `value` | [Object](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_System_Object.htm) | Value to compare against |

**Returns** [QRY_Builder.Builder](QRY_Builder.Builder.md) — Builder for chaining

**Example**

```apex
List<Account> accounts = QRY_Builder.selectFrom(Account.SObjectType)
    .condition(Account.NumberOfEmployees).lessThanOrEquals(10)
    .toList();
```

</div>

### notEquals

<div class="apex-member">

```apex
global QRY_Builder.Builder notEquals(Object value)
```

Adds a != condition.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `value` | [Object](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_System_Object.htm) | Value to compare against |

**Returns** [QRY_Builder.Builder](QRY_Builder.Builder.md) — Builder for chaining

**Example**

```apex
List<Account> accounts = QRY_Builder.selectFrom(Account.SObjectType)
    .condition(Account.Industry).notEquals('Government')
    .toList();
```

</div>

<div class="apex-member">

```apex
global QRY_Builder.Builder notEquals(SObject record)
```

Adds a != condition comparing to an SObject's Id.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `record` | [SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm) | SObject whose Id to exclude |

**Returns** [QRY_Builder.Builder](QRY_Builder.Builder.md) — Builder for chaining

**Example**

```apex
List<Contact> contacts = QRY_Builder.selectFrom(Contact.SObjectType)
    .condition(Contact.AccountId).notEquals(excludedAccount)
    .toList();
```

</div>

### notIn

<div class="apex-member">

```apex
global QRY_Builder.Builder notIn(QRY_Builder.Builder subquery)
```

Adds an anti-join NOT IN condition using a subquery.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `subquery` | [QRY_Builder.Builder](QRY_Builder.Builder.md) | Builder representing the subquery |

**Returns** [QRY_Builder.Builder](QRY_Builder.Builder.md) — Builder for chaining

**Example**

```apex
QRY_Builder.Builder subquery = QRY_Builder.selectFrom(Contact.SObjectType)
    .fields(new List<SObjectField>{Contact.AccountId})
    .condition(Contact.HasOptedOutOfEmail).equals(true);
List<Account> accounts = QRY_Builder.selectFrom(Account.SObjectType)
    .condition(Account.Id).notIn(subquery)
    .toList();
```

</div>

### notInSet

<div class="apex-member">

```apex
global QRY_Builder.Builder notInSet(List<Object> values)
```

Adds a NOT IN condition using a List.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `values` | [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm) | Values to exclude |

**Returns** [QRY_Builder.Builder](QRY_Builder.Builder.md) — Builder for chaining

**Example**

```apex
List<Object> excluded = new List<Object>{'Competitor', 'Other'};
List<Account> accounts = QRY_Builder.selectFrom(Account.SObjectType)
    .condition(Account.Type).notInSet(excluded)
    .toList();
```

</div>

<div class="apex-member">

```apex
global QRY_Builder.Builder notInSet(List<SObject> records)
```

Adds a NOT IN condition using a List of SObjects.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `records` | [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm) | SObjects to exclude |

**Returns** [QRY_Builder.Builder](QRY_Builder.Builder.md) — Builder for chaining

**Example**

```apex
List<Account> excluded = [SELECT Id FROM Account WHERE Type = 'Competitor'];
List<Contact> contacts = QRY_Builder.selectFrom(Contact.SObjectType)
    .condition(Contact.AccountId).notInSet(excluded)
    .toList();
```

</div>

<div class="apex-member">

```apex
global QRY_Builder.Builder notInSet(List<SObject> records, SObjectField field)
```

Adds a NOT IN condition by extracting field values from SObjects.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `records` | [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm) | SObjects to extract values from |
| `field` | [SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm) | The field to extract values from |

**Returns** [QRY_Builder.Builder](QRY_Builder.Builder.md) — Builder for chaining

**Example**

```apex
List<Contact> contacts = [SELECT AccountId FROM Contact WHERE IsDeleted = true];
List<Account> accounts = QRY_Builder.selectFrom(Account.SObjectType)
    .condition(Account.Id).notInSet(contacts, Contact.AccountId)
    .toList();
```

</div>

<div class="apex-member">

```apex
global QRY_Builder.Builder notInSet(Set<Object> values)
```

Adds a NOT IN condition using a Set.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `values` | [Set](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_set.htm) | Values to exclude |

**Returns** [QRY_Builder.Builder](QRY_Builder.Builder.md) — Builder for chaining

**Example**

```apex
Set<Object> excluded = new Set<Object>{'Competitor', 'Other'};
List<Account> accounts = QRY_Builder.selectFrom(Account.SObjectType)
    .condition(Account.Type).notInSet(excluded)
    .toList();
```

</div>

### notInSetStrict

<div class="apex-member">

```apex
global QRY_Builder.Builder notInSetStrict(List<Object> values)
```

Adds a NOT IN condition with strict empty list handling.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `values` | [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm) | Values to exclude (must not be null or empty) |

**Returns** [QRY_Builder.Builder](QRY_Builder.Builder.md) — Builder for chaining

**Throws**

| Exception | Description |
|-----------|-------------|
| [IllegalArgumentException](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_classes_exception_methods.htm) | if values is null or empty |

**Example**

```apex
List<Object> excluded = new List<Object>{'Competitor', 'Other'};
List<Account> accounts = QRY_Builder.selectFrom(Account.SObjectType)
    .condition(Account.Type).notInSetStrict(excluded)
    .toList();
```

</div>

<div class="apex-member">

```apex
global QRY_Builder.Builder notInSetStrict(List<SObject> records)
```

Adds a NOT IN condition using SObjects with strict handling.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `records` | [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm) | SObjects to exclude (must not be null or empty) |

**Returns** [QRY_Builder.Builder](QRY_Builder.Builder.md) — Builder for chaining

**Throws**

| Exception | Description |
|-----------|-------------|
| [IllegalArgumentException](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_classes_exception_methods.htm) | if records is null or empty |

**Example**

```apex
List<Account> excluded = [SELECT Id FROM Account WHERE Type = 'Competitor'];
List<Contact> contacts = QRY_Builder.selectFrom(Contact.SObjectType)
    .condition(Contact.AccountId).notInSetStrict(excluded)
    .toList();
```

</div>

<div class="apex-member">

```apex
global QRY_Builder.Builder notInSetStrict(List<SObject> records, SObjectField field)
```

Adds a NOT IN condition by extracting field values with strict handling.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `records` | [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm) | SObjects to extract values from (must not be null or empty) |
| `field` | [SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm) | The field to extract values from |

**Returns** [QRY_Builder.Builder](QRY_Builder.Builder.md) — Builder for chaining

**Throws**

| Exception | Description |
|-----------|-------------|
| [IllegalArgumentException](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_classes_exception_methods.htm) | if records is null or empty |

**Example**

```apex
List<Contact> contacts = [SELECT AccountId FROM Contact WHERE IsDeleted = true];
List<Account> accounts = QRY_Builder.selectFrom(Account.SObjectType)
    .condition(Account.Id).notInSetStrict(contacts, Contact.AccountId)
    .toList();
```

</div>

<div class="apex-member">

```apex
global QRY_Builder.Builder notInSetStrict(Set<Object> values)
```

Adds a NOT IN condition with strict empty set handling.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `values` | [Set](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_set.htm) | Values to exclude (must not be null or empty) |

**Returns** [QRY_Builder.Builder](QRY_Builder.Builder.md) — Builder for chaining

**Throws**

| Exception | Description |
|-----------|-------------|
| [IllegalArgumentException](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_classes_exception_methods.htm) | if values is null or empty |

**Example**

```apex
Set<Object> excluded = new Set<Object>{'Competitor', 'Other'};
List<Account> accounts = QRY_Builder.selectFrom(Account.SObjectType)
    .condition(Account.Type).notInSetStrict(excluded)
    .toList();
```

</div>

### startsWith

<div class="apex-member">

```apex
global QRY_Builder.Builder startsWith(String value)
```

Adds a LIKE condition with wildcard at end (starts with).

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `value` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | Text prefix |

**Returns** [QRY_Builder.Builder](QRY_Builder.Builder.md) — Builder for chaining

**Example**

```apex
List<Account> accounts = QRY_Builder.selectFrom(Account.SObjectType)
    .condition(Account.Name).startsWith('Acme')
    .toList();
```

</div>

