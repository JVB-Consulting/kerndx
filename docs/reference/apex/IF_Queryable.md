---
title: "IF_Queryable"
type: class
pageClass: reference
description: "Interface for any object that can execute a query. Implemented by QRY_Builder.Builder and SEL_Base. Allows polymorphic query execution across framework components such as batch jobs, async processors,"
author: "Jason Van Beukering"
group: "Query Infrastructure"
date: "February 2026, May 2026"
since: "1.0"
category: apex
---

# IF_Queryable

**Class** · Group: `Query Infrastructure`

<div class="apex-member apex-class">

```apex
global interface IF_Queryable
```

**Known Derived Types:** [QRY_Builder.Builder](QRY_Builder.Builder.md), [SEL_ApiCall](SEL_ApiCall.md), [SEL_ApiIssue](SEL_ApiIssue.md), [SEL_Base](SEL_Base.md), [SEL_ContentVersion](SEL_ContentVersion.md), [SEL_EmailTemplate](SEL_EmailTemplate.md), [SEL_Foobar](SEL_Foobar.md), [SEL_Group](SEL_Group.md), [SEL_OrgWideEmailAddress](SEL_OrgWideEmailAddress.md), [SEL_PermissionSet](SEL_PermissionSet.md), [SEL_PermissionSetGroup](SEL_PermissionSetGroup.md), [SEL_Profile](SEL_Profile.md), [SEL_User](SEL_User.md), [SEL_UserRole](SEL_UserRole.md), [QRY_Builder.Builder.count()](QRY_Builder.Builder.md#count), [SEL_Base.count()](SEL_Base.md#count), [QRY_Builder.Builder.exists()](QRY_Builder.Builder.md#exists), [SEL_Base.exists()](SEL_Base.md#exists), [QRY_Builder.Builder.getFirst()](QRY_Builder.Builder.md#getfirst), [SEL_Base.getFirst()](SEL_Base.md#getfirst), [QRY_Builder.Builder.toList()](QRY_Builder.Builder.md#tolist), [SEL_Base.toList()](SEL_Base.md#tolist), [QRY_Builder.Builder.toQueryLocator()](QRY_Builder.Builder.md#toquerylocator), [SEL_Base.toQueryLocator()](SEL_Base.md#toquerylocator)

Interface for any object that can execute a query. Implemented by QRY_Builder.Builder and SEL_Base. Allows polymorphic query execution across framework components such as batch jobs, async processors, and purge utilities.

**Example**

```apex
public class MyQueryable implements IF_Queryable
{
    public List<SObject> toList() { return query.toList(); }
    public SObject getFirst() { return query.getFirst(); }
    public Database.QueryLocator toQueryLocator() { return query.toQueryLocator(); }
    public Integer count() { return query.count(); }
    public Boolean exists() { return query.exists(); }
}
```

**See Also:** [QRY_Builder](QRY_Builder.md), [SEL_Base](SEL_Base.md)

</div>

---

## Methods

| Method | Description |
|--------|-------------|
| global abstract [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) [count](#count)() | Returns the count of matching records. |
| global abstract [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) [exists](#exists)() | Returns true if any records match the query. |
| global abstract [SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm) [getFirst](#getfirst)() | Executes the query and returns the first matching record, or null. |
| global abstract [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm)> [toList](#tolist)() | Executes the query and returns all matching records. |
| global abstract [Database.QueryLocator](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_database_batch.htm) [toQueryLocator](#toquerylocator)() | Returns a QueryLocator for batch processing. |

---

## Method Details

### count

<div class="apex-member">

```apex
global abstract Integer count()
```

Returns the count of matching records.

**Returns** [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) — Number of matching records

</div>

### exists

<div class="apex-member">

```apex
global abstract Boolean exists()
```

Returns true if any records match the query.

**Returns** [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) — True if at least one record matches

</div>

### getFirst

<div class="apex-member">

```apex
global abstract SObject getFirst()
```

Executes the query and returns the first matching record, or null.

**Returns** [SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm) — First matching SObject or null

</div>

### toList

<div class="apex-member">

```apex
global abstract List<SObject> toList()
```

Executes the query and returns all matching records.

**Returns** [SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm) — List of matching SObjects

</div>

### toQueryLocator

<div class="apex-member">

```apex
global abstract Database.QueryLocator toQueryLocator()
```

Returns a QueryLocator for batch processing.

**Returns** [Database.QueryLocator](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_database_batch.htm) — QueryLocator for this query

</div>

