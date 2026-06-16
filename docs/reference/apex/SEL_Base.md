---
title: "SEL_Base"
type: class
pageClass: reference
description: "Abstract base class for all selectors. Provides lazy-loaded field management and IF_Queryable implementation. Subclasses define their SObjectType and core fields; the base class handles query builder "
author: "Jason Van Beukering"
group: "Selectors"
date: "February 2026, May 2026"
since: "1.0"
category: apex
---

# SEL_Base

**Class** · Group: `Selectors`

<div class="apex-member apex-class">

```apex
global abstract inherited sharing class SEL_Base implements IF_Queryable
```

**Implements:** [IF_Queryable](IF_Queryable.md)

**Known Derived Types:** [SEL_ApiCall](SEL_ApiCall.md), [SEL_ApiIssue](SEL_ApiIssue.md), [SEL_ContentVersion](SEL_ContentVersion.md), [SEL_EmailTemplate](SEL_EmailTemplate.md), [SEL_Foobar](SEL_Foobar.md), [SEL_Group](SEL_Group.md), [SEL_OrgWideEmailAddress](SEL_OrgWideEmailAddress.md), [SEL_PermissionSet](SEL_PermissionSet.md), [SEL_PermissionSetGroup](SEL_PermissionSetGroup.md), [SEL_Profile](SEL_Profile.md), [SEL_User](SEL_User.md), [SEL_UserRole](SEL_UserRole.md), [IF_Queryable.count()](IF_Queryable.md#count), [IF_Queryable.exists()](IF_Queryable.md#exists), [IF_Queryable.getFirst()](IF_Queryable.md#getfirst), [IF_Queryable.toList()](IF_Queryable.md#tolist), [IF_Queryable.toQueryLocator()](IF_Queryable.md#toquerylocator)

Abstract base class for all selectors. Provides lazy-loaded field management and IF_Queryable implementation. Subclasses define their SObjectType and core fields; the base class handles query builder creation with all configured fields.

**Example**

```apex
global class SEL_Account extends SEL_Base
{
global SEL_Account()
{
	super(Account.SObjectType);
}
global override List<SObjectField> getFields()
{
	return new List<SObjectField> { Account.Id, Account.Name };
}
global override List<String> getFieldPaths()
{
	return new List<String> { 'Owner.Name', 'CreatedBy.Email' };
}
global List<Account> findByIndustry(String industry)
{
	return query.condition(Account.Industry).equals(industry).toList();
}
}
```

**See Also:** [IF_Queryable](IF_Queryable.md)

</div>

---

## Properties

| Property | Description |
|----------|-------------|
| global final [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)> [fieldPaths](#fieldpaths) | Core field path strings for this selector, supporting relationship traversal syntax (e.g., 'Owner.Name'). |
| global final [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm)> [fields](#fields) | Core SObjectField tokens for this selector. |
| global [QRY_Builder.Builder](QRY_Builder.Builder.md) [query](#query) | Returns a new query builder pre-configured with this selector's SObjectType and all field sources. |

## Methods

| Method | Description |
|--------|-------------|
| global [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) [count](#count)() | Returns the count of all records matching the default query. |
| global [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) [exists](#exists)() | Returns true if any records match the default query. |
| global [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm)> [findByField](#findbyfield)([SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm) field, [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[Object](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_System_Object.htm)> values) | Finds records matching multiple values on a field. |
| global [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm)> [findByField](#findbyfield)([SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm) field, [Object](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_System_Object.htm) value) | Finds records matching a single field value. |
| global [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm)> [findByField](#findbyfield)([SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm) field, [Set](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_set.htm)<[Object](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_System_Object.htm)> values) | Finds records matching multiple values on a field. |
| global [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm)> [findByFields](#findbyfields)([Map](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_map.htm)<[SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm), [Object](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_System_Object.htm)> fieldValues) | Finds records matching multiple field-value pairs combined with AND logic. |
| global [SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm) [findById](#findbyid)([Id](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_id.htm) recordId) | Finds a single record by its Id. |
| global [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm)> [findById](#findbyid)([Set](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_set.htm)<[Id](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_id.htm)> recordIds) | Finds multiple records by their Ids. |
| global [SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm) [findByIdOrThrow](#findbyidorthrow)([Id](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_id.htm) recordId) | Finds a single record by its Id, throwing NotFoundException if not found. |
| global [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm)> [findByIdOrThrow](#findbyidorthrow)([Set](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_set.htm)<[Id](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_id.htm)> recordIds) | Finds multiple records by their Ids, throwing NotFoundException if any Id is missing. |
| global [SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm) [findFirstByField](#findfirstbyfield)([SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm) field, [Object](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_System_Object.htm) value) | Finds the first record matching a single field value, or null if not found. |
| global [SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm) [findFirstByFields](#findfirstbyfields)([Map](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_map.htm)<[SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm), [Object](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_System_Object.htm)> fieldValues) | Finds the first record matching multiple field-value pairs combined with AND logic, or null if not found. |
| global virtual [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)> [getFieldPaths](#getfieldpaths)() | Returns core field paths as strings, supporting relationship traversal syntax (e.g., 'Owner.Name', 'Contact.Email'). |
| global virtual [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm)> [getFields](#getfields)() | Returns the core SObjectField tokens always included in queries from this selector. |
| global [SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm) [getFirst](#getfirst)() | Executes the default query and returns the first record, or null. |
| global virtual [SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm) [getRandomItem](#getrandomitem)() | Returns a random record matching the default query, or null if none exist. |
| global  [SEL_Base](#sel_base)([SObjectType](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectType.htm) objectType) | Constructs a selector for the given SObjectType. |
| global virtual [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) [systemModeRequired](#systemmoderequired)() | Declares whether this selector's queries must run in AccessLevel.SYSTEM_MODE regardless of the UserModeQueries_Enabled feature flag. |
| global [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm)> [toList](#tolist)() | Executes the default query and returns all matching records. |
| global [Database.QueryLocator](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_database_batch.htm) [toQueryLocator](#toquerylocator)() | Returns a QueryLocator for the default query. |

---

## Property Details

### fieldPaths

```apex
global final List<String> fieldPaths
```

**Type:** [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)

Core field path strings for this selector, supporting relationship traversal
syntax (e.g., 'Owner.Name'). Lazy-loaded from getCoreFieldPaths() on first access.

Since:


Example:

### fields

```apex
global final List<SObjectField> fields
```

**Type:** [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)

Core SObjectField tokens for this selector. Lazy-loaded from getCoreFields()
on first access. Subscribers can inspect a selector's field configuration via this property.

Since:


Example:

### query

```apex
global QRY_Builder.Builder query
```

**Type:** [QRY_Builder.Builder](QRY_Builder.Builder.md)

Returns a new query builder pre-configured with this selector's SObjectType
and all field sources. Each access creates a fresh builder instance to prevent state
leaking between queries. When systemModeRequired() returns true, the builder has
systemModeInternal() applied so framework-internal reads (CMDT, framework-owned
sObjects) run in SYSTEM_MODE without polluting the BypassEvent audit trail —
a static systemModeRequired() design choice is not a runtime bypass. Selectors that
leave systemModeRequired() at the default (false) inherit the UserModeQueries_Enabled
flag-driven default.

Since:


Example:

---

## Method Details

### SEL_Base

<div class="apex-member">

```apex
global SEL_Base(SObjectType objectType)
```

Constructs a selector for the given SObjectType.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `objectType` | [SObjectType](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectType.htm) | The SObjectType this selector queries |

**Example**

```apex
SEL_Account.SEL_Base instance = new SEL_Account.SEL_Base(Account.SObjectType);
```

</div>

### count

<div class="apex-member">

```apex
global Integer count()
```

Returns the count of all records matching the default query.

**Returns** [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) — Number of matching records

**Example**

```apex
Integer result = instance.count();
```

</div>

### exists

<div class="apex-member">

```apex
global Boolean exists()
```

Returns true if any records match the default query.

**Returns** [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) — True if at least one record matches

**Example**

```apex
Boolean result = instance.exists();
```

</div>

### findByField

<div class="apex-member">

```apex
global List<SObject> findByField(SObjectField field, List<Object> values)
```

Finds records matching multiple values on a field.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `field` | [SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm) | The SObjectField to filter on |
| `values` | [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm) | The values to match |

**Returns** [SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm) — List of matching records, or empty list if no values provided

**Example**

```apex
List<SObject> result = instance.findByField(Account.Name, new List<Object>{'a', 'b'});
```

</div>

<div class="apex-member">

```apex
global List<SObject> findByField(SObjectField field, Object value)
```

Finds records matching a single field value.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `field` | [SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm) | The SObjectField to filter on |
| `value` | [Object](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_System_Object.htm) | The value to match |

**Returns** [SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm) — List of matching records

**Example**

```apex
List<SObject> result = instance.findByField(Account.Name, 'value');
```

</div>

<div class="apex-member">

```apex
global List<SObject> findByField(SObjectField field, Set<Object> values)
```

Finds records matching multiple values on a field.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `field` | [SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm) | The SObjectField to filter on |
| `values` | [Set](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_set.htm) | The values to match |

**Returns** [SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm) — List of matching records, or empty list if no values provided

**Example**

```apex
List<SObject> result = instance.findByField(Account.Name, new Set<Object>{'value'});
```

</div>

### findByFields

<div class="apex-member">

```apex
global List<SObject> findByFields(Map<SObjectField, Object> fieldValues)
```

Finds records matching multiple field-value pairs combined with AND logic.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `fieldValues` | [Map](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_map.htm) | Map of SObjectField tokens to their expected values |

**Returns** [SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm) — List of matching records, or empty list if fieldValues is null or empty

**Example**

```apex
List<SObject> records = new SEL_Foobar().findByFields
(
    new Map<SObjectField, Object>
    {
        Foobar__c.Text__c => 'Alpha',
        Foobar__c.Email__c => 'test@example.com'
    }
);
```

</div>

### findById

<div class="apex-member">

```apex
global SObject findById(Id recordId)
```

Finds a single record by its Id.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `recordId` | [Id](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_id.htm) | The Id of the record to retrieve |

**Returns** [SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm) — The matching record or null if not found

**Example**

```apex
SObject result = instance.findById(recordId);
```

</div>

<div class="apex-member">

```apex
global List<SObject> findById(Set<Id> recordIds)
```

Finds multiple records by their Ids.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `recordIds` | [Set](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_set.htm) | The set of Ids to retrieve |

**Returns** [SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm) — List of matching records, or empty list if no Ids provided

**Example**

```apex
List<SObject> result = instance.findById(recordIds);
```

</div>

### findByIdOrThrow

<div class="apex-member">

```apex
global SObject findByIdOrThrow(Id recordId)
```

Finds a single record by its Id, throwing NotFoundException if not found.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `recordId` | [Id](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_id.htm) | The Id of the record to retrieve |

**Returns** [SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm) — The matching record

**Throws**

| Exception | Description |
|-----------|-------------|
| [UTIL_Exceptions.NotFoundException](UTIL_Exceptions.NotFoundException.md) | If no record exists with the given Id |

**Example**

```apex
Foobar__c record = (Foobar__c)new SEL_Foobar().findByIdOrThrow(recordId);
```

</div>

<div class="apex-member">

```apex
global List<SObject> findByIdOrThrow(Set<Id> recordIds)
```

Finds multiple records by their Ids, throwing NotFoundException if any Id is missing.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `recordIds` | [Set](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_set.htm) | The set of Ids to retrieve |

**Returns** [SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm) — List of matching records

**Throws**

| Exception | Description |
|-----------|-------------|
| [UTIL_Exceptions.NotFoundException](UTIL_Exceptions.NotFoundException.md) | If any of the requested Ids were not found |

**Example**

```apex
List<Foobar__c> records = new SEL_Foobar().findByIdOrThrow(recordIds);
```

</div>

### findFirstByField

<div class="apex-member">

```apex
global SObject findFirstByField(SObjectField field, Object value)
```

Finds the first record matching a single field value, or null if not found.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `field` | [SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm) | The SObjectField to filter on |
| `value` | [Object](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_System_Object.htm) | The value to match |

**Returns** [SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm) — The first matching record or null

**Example**

```apex
SObject result = instance.findFirstByField(Account.Name, 'value');
```

</div>

### findFirstByFields

<div class="apex-member">

```apex
global SObject findFirstByFields(Map<SObjectField, Object> fieldValues)
```

Finds the first record matching multiple field-value pairs combined with AND logic,
or null if not found.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `fieldValues` | [Map](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_map.htm) | Map of SObjectField tokens to their expected values |

**Returns** [SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm) — The first matching record or null

**Example**

```apex
SObject record = new SEL_Foobar().findFirstByFields
(
    new Map<SObjectField, Object>
    {
        Foobar__c.Text__c => 'Alpha',
        Foobar__c.Email__c => 'test@example.com'
    }
);
```

</div>

### getFieldPaths

<div class="apex-member">

```apex
global virtual List<String> getFieldPaths()
```

Returns core field paths as strings, supporting relationship traversal
syntax (e.g., 'Owner.Name', 'Contact.Email'). Override to include relationship
fields in the default query. Returns an empty list by default.

**Returns** [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) — List of field path strings

**Example**

```apex
List<String> result = instance.getFieldPaths();
```

</div>

### getFields

<div class="apex-member">

```apex
global virtual List<SObjectField> getFields()
```

Returns the core SObjectField tokens always included in queries from this selector.
Override to define the default field set. Returns an empty list by default.

**Returns** [SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm) — List of core SObjectFields

**Example**

```apex
List<SObjectField> result = instance.getFields();
```

</div>

### getFirst

<div class="apex-member">

```apex
global SObject getFirst()
```

Executes the default query and returns the first record, or null.

**Returns** [SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm) — First matching record or null

**Example**

```apex
SObject result = instance.getFirst();
```

</div>

### getRandomItem

<div class="apex-member">

```apex
global virtual SObject getRandomItem()
```

Returns a random record matching the default query, or null if none exist.

**Returns** [SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm) — A random matching record or null

**Example**

```apex
SObject result = instance.getRandomItem();
```

</div>

### systemModeRequired

<div class="apex-member">

```apex
global virtual Boolean systemModeRequired()
```

Declares whether this selector's queries must run in `AccessLevel.SYSTEM_MODE`
regardless of the `UserModeQueries_Enabled` feature flag. Framework-internal selectors that
read CMDT, framework-owned sObjects, or system-schema tables override this to return `true`
so they continue working when the running user lacks FLS/CRUD on those objects by design.

Subscriber-reachable selectors should leave this at the default (`false`) so they inherit
the flag-driven default — secure-by-default when the flag is enabled.

**Returns** [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) — `true` when this selector's queries must run in SYSTEM_MODE.

**Example**

```apex
public inherited sharing class SEL_Cases extends SEL_Base
{
    public SEL_Cases()
    {
        super(Case.SObjectType);
    }
    public override Boolean systemModeRequired()
    {
        return true;
    }
}
```

</div>

### toList

<div class="apex-member">

```apex
global List<SObject> toList()
```

Executes the default query and returns all matching records.

**Returns** [SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm) — List of all records with default fields

**Example**

```apex
List<SObject> result = instance.toList();
```

</div>

### toQueryLocator

<div class="apex-member">

```apex
global Database.QueryLocator toQueryLocator()
```

Returns a QueryLocator for the default query. Suitable for batch processing.

**Returns** [Database.QueryLocator](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_database_batch.htm) — QueryLocator for the default query

**Example**

```apex
global class BatchProcessAccounts implements Database.Batchable
{
    global Database.QueryLocator start(Database.BatchableContext context)
    {
        return new SEL_Account().toQueryLocator();
    }
}
```

</div>

