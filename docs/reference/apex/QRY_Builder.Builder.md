---
title: "QRY_Builder.Builder"
type: class
description: "Extensible query builder class. Maintains internal query state and uses QRY_Generator for SOQL building and QRY_Engine for execution."
since: "1.0"
category: apex
---

# QRY_Builder.Builder

**Class**

```apex
global virtual inherited sharing class QRY_Builder.Builder implements IF_Queryable
```

**Implements:** [IF_Queryable](IF_Queryable.md)

**Known Derived Types:** [IF_Queryable.count()](IF_Queryable.md#count), [IF_Queryable.exists()](IF_Queryable.md#exists), [IF_Queryable.getFirst()](IF_Queryable.md#getfirst), [IF_Queryable.toList()](IF_Queryable.md#tolist), [IF_Queryable.toQueryLocator()](IF_Queryable.md#toquerylocator)

Extensible query builder class. Maintains internal query state and uses QRY_Generator for SOQL building and QRY_Engine for execution.

**Since:** 1.0

**Example:**

```apex
QRY_Builder.Builder query = QRY_Builder.selectFrom(Account.SObjectType)
    .addField(Account.Name)
    .condition(Account.Industry).equals('Technology');
List<Account> accounts = query.toList();
```

---

## Properties

| Property | Description |
|----------|-------------|
| global [SObjectType](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectType.htm) [objectType](#objecttype) | The SObjectType being queried by this builder. |

## Methods

| Method | Description |
|--------|-------------|
| global [QRY_Builder.Builder](QRY_Builder.Builder.md) [addCondition](#addcondition)([QRY_Condition.Evaluable](QRY_Condition.Evaluable.md) condition) | Adds a pre-built condition to the query. |
| global virtual [QRY_Builder.Builder](QRY_Builder.Builder.md) [addField](#addfield)([QRY_Function](QRY_Function.md) functionField, [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) alias) | Projects a SOQL date-function expression into SELECT under an explicit alias, for read-back via AggregateRow (e.g. |
| global [QRY_Builder.Builder](QRY_Builder.Builder.md) [addField](#addfield)([SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm) objectField) | Adds a single field without disabling default fields. |
| global [QRY_Builder.Builder](QRY_Builder.Builder.md) [addField](#addfield)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) fieldName) | Adds a single field without disabling default fields. |
| global [QRY_Builder.Builder](QRY_Builder.Builder.md) [addFields](#addfields)([List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm)> objectFields) | Adds fields to the selection without disabling default fields. |
| global [QRY_Builder.Builder](QRY_Builder.Builder.md) [addFields](#addfields)([List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)> fieldNames) | Adds fields to the selection without disabling default fields. |
| global [QRY_Builder.Builder](QRY_Builder.Builder.md) [addFieldSet](#addfieldset)([FieldSet](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_fieldsets_describe.htm) aFieldset) | Adds fields from a FieldSet token without disabling default fields. |
| global [QRY_Builder.Builder](QRY_Builder.Builder.md) [addFieldSet](#addfieldset)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) fieldSetName) | Adds fields from a FieldSet without disabling default fields. |
| global [QRY_Builder.Builder](QRY_Builder.Builder.md) [allRows](#allrows)() | Includes deleted and archived records (ALL ROWS). |
| global [QRY_Builder.ConditionBuilder](QRY_Builder.ConditionBuilder.md) [andCondition](#andcondition)([SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm) field) | Starts an AND condition on a field using an SObjectField token. |
| global [QRY_Builder.ConditionBuilder](QRY_Builder.ConditionBuilder.md) [andCondition](#andcondition)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) fieldName) | Starts an AND condition on a field using its API name. |
| global [QRY_Builder.Builder](QRY_Builder.Builder.md) [ascending](#ascending)() | Sets the last ORDER BY clause to ASCENDING. |
| global [Map](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_map.htm)<[Id](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_id.htm), [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm)>> [asGroupedMapById](#asgroupedmapbyid)([SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm) keyField) | Executes the query and returns the results grouped by an Id field (e.g. |
| global [Map](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_map.htm)<[Id](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_id.htm), [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm)>> [asGroupedMapById](#asgroupedmapbyid)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) fieldName) | Executes the query and returns the results grouped by an Id field. |
| global [Map](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_map.htm)<[String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm), [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm)>> [asGroupedMapByString](#asgroupedmapbystring)([SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm) keyField) | Executes the query and returns the results grouped by a String field value. |
| global [Map](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_map.htm)<[String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm), [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm)>> [asGroupedMapByString](#asgroupedmapbystring)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) fieldName) | Executes the query and returns the results grouped by a String field value. |
| global [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[Id](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_id.htm)> [asIdList](#asidlist)() | Returns the results as a List of Ids. |
| global [Set](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_set.htm)<[Id](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_id.htm)> [asIdSet](#asidset)() | Executes the query and returns a Set of record Ids. |
| global [Map](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_map.htm)<[Id](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_id.htm), [SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm)> [asMap](#asmap)() | Executes the query and returns results as a Map. |
| global [Map](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_map.htm)<[Id](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_id.htm), [SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm)> [asMapById](#asmapbyid)([SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm) keyField) | Executes the query and returns the results as a Map keyed by the specified Id field (e.g. |
| global [Map](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_map.htm)<[Id](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_id.htm), [SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm)> [asMapById](#asmapbyid)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) fieldName) | Executes the query and returns the results as a Map keyed by the specified Id field. |
| global [Map](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_map.htm)<[String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm), [SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm)> [asMapByString](#asmapbystring)([SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm) keyField) | Executes the query and returns the results as a Map keyed by a String field value. |
| global [Map](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_map.htm)<[String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm), [SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm)> [asMapByString](#asmapbystring)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) fieldName) | Executes the query and returns the results as a Map keyed by a String field value. |
| global [Set](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_set.htm)<[String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)> [asStringSet](#asstringset)([SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm) field) | Executes the query and returns a Set of distinct String values for the specified field. |
| global [Set](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_set.htm)<[String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)> [asStringSet](#asstringset)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) fieldName) | Executes the query and returns a Set of distinct String values for the specified field. |
| global [Set](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_set.htm)<[Object](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_System_Object.htm)> [asValueSet](#asvalueset)([SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm) field) | Executes the query and returns a Set of distinct values for the specified field. |
| global [Set](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_set.htm)<[Object](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_System_Object.htm)> [asValueSet](#asvalueset)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) fieldName) | Executes the query and returns a Set of distinct values for the specified field. |
| global [QRY_Builder.Builder](QRY_Builder.Builder.md) [avg](#avg)([SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm) field) | Applies an AVG aggregate function. |
| global  [Builder](#builder)() | Default constructor. |
| global  [Builder](#builder)([SObjectType](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectType.htm) sObjectType) | Constructor that sets the SObject type. |
| global [QRY_Builder.Builder](QRY_Builder.Builder.md) [bypassSharing](#bypasssharing)() | Bypasses sharing rules using a without sharing proxy class. |
| global [QRY_Builder.ConditionBuilder](QRY_Builder.ConditionBuilder.md) [condition](#condition)([SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm) objectField) | Starts a WHERE condition on a field using an SObjectField token. |
| global [QRY_Builder.ConditionBuilder](QRY_Builder.ConditionBuilder.md) [condition](#condition)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) fieldName) | Starts a WHERE condition on a field using its API name. |
| global [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) [count](#count)() | Returns the number of records that match the query criteria. |
| global [QRY_Builder.Builder](QRY_Builder.Builder.md) [count](#count)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) fieldName) | Applies a COUNT aggregate function. |
| global [QRY_Builder.Builder](QRY_Builder.Builder.md) [countDistinct](#countdistinct)([SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm) field) | Applies a COUNT_DISTINCT aggregate function. |
| global [QRY_Builder.Builder](QRY_Builder.Builder.md) [countDistinct](#countdistinct)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) fieldName) | Applies a COUNT_DISTINCT aggregate function. |
| global [QRY_Builder.Builder](QRY_Builder.Builder.md) [cube](#cube)() | Flags the GROUP BY clause as CUBE for cross-tabulation. |
| global [QRY_Builder.Builder](QRY_Builder.Builder.md) [descending](#descending)() | Sets the last ORDER BY clause to DESCENDING. |
| global [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) [exists](#exists)() | Checks whether any records exist matching the query criteria. |
| global [QRY_Builder.Builder](QRY_Builder.Builder.md) [fields](#fields)([List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm)> objectFields) | Explicitly select fields using SObjectField tokens. |
| global [QRY_Builder.Builder](QRY_Builder.Builder.md) [fields](#fields)([List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)> fieldNames) | Explicitly select fields by API name. |
| global [QRY_Builder.Builder](QRY_Builder.Builder.md) [fieldSet](#fieldset)([FieldSet](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_fieldsets_describe.htm) aFieldset) | Selects fields from a FieldSet token. |
| global [QRY_Builder.Builder](QRY_Builder.Builder.md) [fieldSet](#fieldset)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) fieldSetName) | Selects fields from a FieldSet. |
| global [QRY_Builder.Builder](QRY_Builder.Builder.md) [forcePerformanceLogging](#forceperformancelogging)() | Forces performance logging regardless of threshold for this query. |
| global [QRY_Builder.Builder](QRY_Builder.Builder.md) [forReference](#forreference)() | Locks returned records FOR REFERENCE. |
| global [QRY_Builder.Builder](QRY_Builder.Builder.md) [forUpdate](#forupdate)() | Locks returned records FOR UPDATE. |
| global [QRY_Builder.Builder](QRY_Builder.Builder.md) [forView](#forview)() | Locks returned records FOR VIEW. |
| global virtual [Set](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_set.htm)<[String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)> [getDefaultFields](#getdefaultfields)() | Override to provide default fields for this selector. |
| global [SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm) [getFirst](#getfirst)() | Executes the query and returns the first record (or null). |
| global [QRY_Builder.AggregateRow](QRY_Builder.AggregateRow.md) [getFirstAggregate](#getfirstaggregate)() | Executes an aggregate query and returns the first result as a typed AggregateRow. |
| global [QRY_Builder.QueryPage](QRY_Builder.QueryPage.md) [getPage](#getpage)([Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) requestedPageNumber, [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) requestedPageSize) | Executes a paged query and returns results with pagination metadata. |
| global [SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm) [getRandomItem](#getrandomitem)() | Returns a single random record matching the query criteria. |
| global [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm)> [getRandomItems](#getrandomitems)([Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) randomCount) | Returns multiple random records matching the query criteria. |
| global virtual [QRY_Builder.Builder](QRY_Builder.Builder.md) [groupBy](#groupby)([QRY_Function](QRY_Function.md) functionField) | Adds a SOQL date-function expression to the GROUP BY clause (e.g. |
| global [QRY_Builder.Builder](QRY_Builder.Builder.md) [groupBy](#groupby)([SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm) groupField) | Adds a field to the GROUP BY clause using an SObjectField token. |
| global [QRY_Builder.Builder](QRY_Builder.Builder.md) [groupBy](#groupby)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) groupField) | Adds a GROUP BY clause. |
| global [QRY_Builder.Builder](QRY_Builder.Builder.md) [grouping](#grouping)([SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm) field) | Adds a GROUPING(field) expression to the SELECT clause for use with ROLLUP or CUBE. |
| global [QRY_Builder.Builder](QRY_Builder.Builder.md) [grouping](#grouping)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) fieldName) | Adds a GROUPING(field) expression to the SELECT clause by field name. |
| global [QRY_Builder.ConditionBuilder](QRY_Builder.ConditionBuilder.md) [havingAvgOf](#havingavgof)([SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm) field) | Starts a HAVING condition on the AVG of a field. |
| global [QRY_Builder.ConditionBuilder](QRY_Builder.ConditionBuilder.md) [havingCount](#havingcount)() | Starts a HAVING condition on the global COUNT(). |
| global [QRY_Builder.ConditionBuilder](QRY_Builder.ConditionBuilder.md) [havingCountOf](#havingcountof)([SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm) field) | Starts a HAVING condition on the COUNT of a field. |
| global [QRY_Builder.ConditionBuilder](QRY_Builder.ConditionBuilder.md) [havingMaxOf](#havingmaxof)([SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm) field) | Starts a HAVING condition on the MAX of a field. |
| global [QRY_Builder.ConditionBuilder](QRY_Builder.ConditionBuilder.md) [havingMinOf](#havingminof)([SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm) field) | Starts a HAVING condition on the MIN of a field. |
| global [QRY_Builder.ConditionBuilder](QRY_Builder.ConditionBuilder.md) [havingSumOf](#havingsumof)([SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm) field) | Starts a HAVING condition on the SUM of a field. |
| global [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) [isCached](#iscached)() | Indicates whether the last execution retrieved results from cache. |
| global [QRY_Builder.Builder](QRY_Builder.Builder.md) [logPerformanceIfSlowerThan](#logperformanceifslowerthan)([Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) thresholdMs) | Sets a custom performance threshold for this query. |
| global [QRY_Builder.Builder](QRY_Builder.Builder.md) [max](#max)([SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm) field) | Applies a MAX aggregate function. |
| global [QRY_Builder.Builder](QRY_Builder.Builder.md) [min](#min)([SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm) field) | Applies a MIN aggregate function. |
| global [QRY_Builder.Builder](QRY_Builder.Builder.md) [nullsFirst](#nullsfirst)() | Sets the last ORDER BY clause to NULLS FIRST. |
| global [QRY_Builder.Builder](QRY_Builder.Builder.md) [nullsLast](#nullslast)() | Sets the last ORDER BY clause to NULLS LAST. |
| global [QRY_Builder.ConditionBuilder](QRY_Builder.ConditionBuilder.md) [orCondition](#orcondition)([SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm) field) | Starts an OR condition on a field using an SObjectField token. |
| global [QRY_Builder.ConditionBuilder](QRY_Builder.ConditionBuilder.md) [orCondition](#orcondition)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) fieldName) | Starts an OR condition on a field using its API name. |
| global virtual [QRY_Builder.Builder](QRY_Builder.Builder.md) [orderBy](#orderby)([QRY_Function](QRY_Function.md) functionField) | Orders by a SOQL date-function expression, ascending (e.g. |
| global virtual [QRY_Builder.Builder](QRY_Builder.Builder.md) [orderBy](#orderby)([QRY_Function](QRY_Function.md) functionField, [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) sortDescending) | Orders by a SOQL date-function expression, ascending or descending. |
| global [QRY_Builder.Builder](QRY_Builder.Builder.md) [orderBy](#orderby)([SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm) field) | Adds an ORDER BY clause (default ascending). |
| global [QRY_Builder.Builder](QRY_Builder.Builder.md) [orderBy](#orderby)([SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm) field, [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) sortDescending) | Adds an ORDER BY clause with a dynamic sort direction. |
| global [QRY_Builder.Builder](QRY_Builder.Builder.md) [orderBy](#orderby)([SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm) field, [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) sortDescending, [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) nullsLast) | Adds an ORDER BY clause with a dynamic sort direction and nulls placement. |
| global [QRY_Builder.Builder](QRY_Builder.Builder.md) [orderBy](#orderby)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) fieldName) | Adds an ORDER BY clause (default ascending). |
| global [QRY_Builder.Builder](QRY_Builder.Builder.md) [orderBy](#orderby)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) fieldName, [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) sortDescending) | Adds an ORDER BY clause with a dynamic sort direction. |
| global [QRY_Builder.Builder](QRY_Builder.Builder.md) [orderBy](#orderby)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) fieldName, [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) sortDescending, [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) nullsLast) | Adds an ORDER BY clause with a dynamic sort direction and nulls placement. |
| global [QRY_Builder.Builder](QRY_Builder.Builder.md) [relatedField](#relatedfield)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) parentField) | Adds a single parent field. |
| global [QRY_Builder.Builder](QRY_Builder.Builder.md) [relatedFields](#relatedfields)([List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)> parentFields) | Adds parent (related) fields to the selection. |
| global [QRY_Builder.Builder](QRY_Builder.Builder.md) [rollup](#rollup)() | Flags the GROUP BY clause as ROLLUP for subtotals. |
| global [QRY_Builder.Builder](QRY_Builder.Builder.md) [selectAllFields](#selectallfields)() | Configures the query to select ALL fields on the object. |
| global [QRY_Builder.Builder](QRY_Builder.Builder.md) [stripInaccessible](#stripinaccessible)() | Strips inaccessible fields from results. |
| global [QRY_Builder.Builder](QRY_Builder.Builder.md) [subselect](#subselect)([QRY_Builder.Builder](QRY_Builder.Builder.md) childQuery, [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) relationshipName) | Adds a child subquery (child relationship query). |
| global [QRY_Builder.Builder](QRY_Builder.Builder.md) [sum](#sum)([SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm) field) | Applies a SUM aggregate function. |
| global [QRY_Builder.Builder](QRY_Builder.Builder.md) [suppressPerformanceLogging](#suppressperformancelogging)() | Suppresses performance logging for this query. |
| global [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[QRY_Builder.AggregateRow](QRY_Builder.AggregateRow.md)> [toAggregateList](#toaggregatelist)() | Executes an aggregate query and returns results as typed AggregateRow wrappers. |
| global [Database.Cursor](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Database_Cursor.htm) [toCursor](#tocursor)() | Returns a Database.Cursor for large data set traversal. |
| global [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm)> [toList](#tolist)() | Executes the query and returns a List of SObjects. |
| global [Database.QueryLocator](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_database_batch.htm) [toQueryLocator](#toquerylocator)() | Returns a Database.QueryLocator for batch processing. |
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [toSoql](#tosoql)() | Generates and returns the SOQL string without executing it. |
| global [QRY_Builder.Builder](QRY_Builder.Builder.md) [usingScope](#usingscope)([QRY_Builder.Scope](QRY_Builder.Scope.md) scopeValue) | Filters records by visibility scope using USING SCOPE clause. |
| global [QRY_Builder.Builder](QRY_Builder.Builder.md) [withCache](#withcache)([Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) ttlSeconds) | Enables platform caching for this query. |
| global [QRY_Builder.DataCategoryBuilder](QRY_Builder.DataCategoryBuilder.md) [withDataCategory](#withdatacategory)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) groupName) | Starts a WITH DATA CATEGORY filter for the specified data category group. |
| global [QRY_Builder.Builder](QRY_Builder.Builder.md) [withLimit](#withlimit)([Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) recordLimit) | Sets the maximum number of records to return (LIMIT). |
| global [QRY_Builder.Builder](QRY_Builder.Builder.md) [withOffset](#withoffset)([Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) rowNumber) | Sets the record offset (OFFSET). |
| global [QRY_Builder.Builder](QRY_Builder.Builder.md) [withoutSecurity](#withoutsecurity)() | Disables all security enforcement. |
| global [QRY_Builder.Builder](QRY_Builder.Builder.md) [withSharing](#withsharing)() | Enforces sharing rules using a with sharing proxy class. |
| global [QRY_Builder.Builder](QRY_Builder.Builder.md) [withSystemMode](#withsystemmode)() | Forces SYSTEM_MODE execution regardless of the UserModeQueries_Enabled feature flag. |
| global [QRY_Builder.Builder](QRY_Builder.Builder.md) [withUserMode](#withusermode)() | Runs the query in USER_MODE. |

---

## Property Details

### objectType

```apex
global SObjectType objectType
```

**Type:** [SObjectType](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectType.htm)

The SObjectType being queried by this builder.

Since:


Example:

---

## Method Details

### Builder

```apex
global Builder()
```

Default constructor.

**Since:** 1.0

**Example:**

```apex
QRY_Builder.Builder query = new QRY_Builder.Builder();
```

```apex
global Builder(SObjectType sObjectType)
```

Constructor that sets the SObject type.

**Parameters:**

- `sObjectType` ([SObjectType](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectType.htm)) - The SObject to query

**Since:** 1.0

**Example:**

```apex
QRY_Builder.Builder query = new QRY_Builder.Builder(Account.SObjectType);
```

### addCondition

```apex
global QRY_Builder.Builder addCondition(QRY_Condition.Evaluable condition)
```

Adds a pre-built condition to the query.
Use this for complex condition groups that cannot be expressed with the fluent API.

**Parameters:**

- `condition` ([QRY_Condition.Evaluable](QRY_Condition.Evaluable.md)) - The condition to add (created via QRY_Condition classes)

**Returns:** [QRY_Builder.Builder](QRY_Builder.Builder.md) - Builder for chaining

**Since:** 1.0

**Example:**

```apex
QRY_Condition.OrCondition statusGroup = new QRY_Condition.OrCondition();
statusGroup.add(new QRY_Condition.FieldCondition('Status__c', QRY_Condition.Operator.EQUALS, 'Active'));
statusGroup.add(new QRY_Condition.FieldCondition('Status__c', QRY_Condition.Operator.EQUALS, 'Pending'));
List<Account> accounts = QRY_Builder.selectFrom(Account.SObjectType)
    .condition(Account.Industry).equals('Technology')
    .addCondition(statusGroup)
    .toList();
```

### addField

```apex
global virtual QRY_Builder.Builder addField(QRY_Function functionField, String alias)
```

Projects a SOQL date-function expression into SELECT under an explicit alias, for
read-back via AggregateRow (e.g. CALENDAR_MONTH(CloseDate) closeMonth -> row.getInteger('closeMonth')).
Pair with groupBy(QRY_Function) using the same factory so the SELECT and GROUP BY expressions match.

**Parameters:**

- `functionField` ([QRY_Function](QRY_Function.md)) - The date-function expression, from a QRY_Function factory
- `alias` ([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)) - The read-back alias for the projected expression

**Returns:** [QRY_Builder.Builder](QRY_Builder.Builder.md) - Builder for chaining

**Since:** 1.1

**Example:**

```apex
QRY_Builder.selectFrom(Opportunity.SObjectType)
    .addField(QRY_Function.calendarMonth(Opportunity.CloseDate), 'closeMonth')
    .count('Id')
    .groupBy(QRY_Function.calendarMonth(Opportunity.CloseDate))
    .toAggregateList();
```

```apex
global QRY_Builder.Builder addField(SObjectField objectField)
```

Adds a single field without disabling default fields.

**Parameters:**

- `objectField` ([SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm)) - SObjectField token

**Returns:** [QRY_Builder.Builder](QRY_Builder.Builder.md) - Builder for chaining

**Since:** 1.0

**Example:**

```apex
List<Account> accounts = QRY_Builder.selectFrom(Account.SObjectType)
    .addField(Account.Website)
    .toList();
```

```apex
global QRY_Builder.Builder addField(String fieldName)
```

Adds a single field without disabling default fields.

**Parameters:**

- `fieldName` ([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)) - API name

**Returns:** [QRY_Builder.Builder](QRY_Builder.Builder.md) - Builder for chaining

**Since:** 1.0

**Example:**

```apex
List<Account> accounts = QRY_Builder.selectFrom(Account.SObjectType)
    .addField('Website')
    .toList();
```

### addFields

```apex
global QRY_Builder.Builder addFields(List<SObjectField> objectFields)
```

Adds fields to the selection without disabling default fields.

**Parameters:**

- `objectFields` ([List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)) - List of SObjectField tokens

**Returns:** [QRY_Builder.Builder](QRY_Builder.Builder.md) - Builder for chaining

**Since:** 1.0

**Example:**

```apex
List<Account> accounts = QRY_Builder.selectFrom(Account.SObjectType)
    .addFields(new List<SObjectField>{Account.Phone, Account.Website})
    .toList();
```

```apex
global QRY_Builder.Builder addFields(List<String> fieldNames)
```

Adds fields to the selection without disabling default fields.

**Parameters:**

- `fieldNames` ([List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)) - List of field API names

**Returns:** [QRY_Builder.Builder](QRY_Builder.Builder.md) - Builder for chaining

**Since:** 1.0

**Example:**

```apex
List<Account> accounts = QRY_Builder.selectFrom(Account.SObjectType)
    .addFields(new List<String>{'Phone', 'Website'})
    .toList();
```

### addFieldSet

```apex
global QRY_Builder.Builder addFieldSet(FieldSet aFieldset)
```

Adds fields from a FieldSet token without disabling default fields.

**Parameters:**

- `aFieldset` ([FieldSet](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_fieldsets_describe.htm)) - The Schema.FieldSet token

**Returns:** [QRY_Builder.Builder](QRY_Builder.Builder.md) - Builder for chaining

**Since:** 1.0

**Example:**

```apex
FieldSet fs = SObjectType.Account.fieldSets.Account_Summary;
List<Account> accounts = QRY_Builder.selectFrom(Account.SObjectType)
    .addFieldSet(fs)
    .toList();
```

```apex
global QRY_Builder.Builder addFieldSet(String fieldSetName)
```

Adds fields from a FieldSet without disabling default fields.

**Parameters:**

- `fieldSetName` ([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)) - The API Name of the FieldSet

**Returns:** [QRY_Builder.Builder](QRY_Builder.Builder.md) - Builder for chaining

**Since:** 1.0

**Example:**

```apex
List<Account> accounts = QRY_Builder.selectFrom(Account.SObjectType)
    .addFieldSet('Account_Summary')
    .toList();
```

### allRows

```apex
global QRY_Builder.Builder allRows()
```

Includes deleted and archived records (ALL ROWS).

**Returns:** [QRY_Builder.Builder](QRY_Builder.Builder.md) - Builder for chaining

**Since:** 1.0

**Example:**

```apex
List<Account> accounts = QRY_Builder.selectFrom(Account.SObjectType)
    .condition(Account.IsDeleted).equals(true)
    .allRows()
    .toList();
```

### andCondition

```apex
global QRY_Builder.ConditionBuilder andCondition(SObjectField field)
```

Starts an AND condition on a field using an SObjectField token.

**Parameters:**

- `field` ([SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm)) - Field token

**Returns:** [QRY_Builder.ConditionBuilder](QRY_Builder.ConditionBuilder.md) - ConditionBuilder for specifying the operator

**Since:** 1.0

**Example:**

```apex
List<Account> accounts = QRY_Builder.selectFrom(Account.SObjectType)
    .condition(Account.Industry).equals('Technology')
    .andCondition(Account.Type).equals('Customer')
    .toList();
```

```apex
global QRY_Builder.ConditionBuilder andCondition(String fieldName)
```

Starts an AND condition on a field using its API name.

**Parameters:**

- `fieldName` ([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)) - Field API name

**Returns:** [QRY_Builder.ConditionBuilder](QRY_Builder.ConditionBuilder.md) - ConditionBuilder for specifying the operator

**Since:** 1.0

**Example:**

```apex
List<Account> accounts = QRY_Builder.selectFrom(Account.SObjectType)
    .condition('Industry').equals('Technology')
    .andCondition('Type').equals('Customer')
    .toList();
```

### ascending

```apex
global QRY_Builder.Builder ascending()
```

Sets the last ORDER BY clause to ASCENDING.

**Returns:** [QRY_Builder.Builder](QRY_Builder.Builder.md) - Builder for chaining

**Since:** 1.0

**Example:**

```apex
List<Account> accounts = QRY_Builder.selectFrom(Account.SObjectType)
    .orderBy(Account.Name).ascending()
    .toList();
```

### asGroupedMapById

```apex
global Map<Id, List<SObject>> asGroupedMapById(SObjectField keyField)
```

Executes the query and returns the results grouped by an Id field
(e.g. a parent-lookup field). Duplicates are preserved as separate entries within
each group. Delegates to UTIL_SObject.groupByKey.

**Parameters:**

- `keyField` ([SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm)) - The SObjectField token whose value will be used as the map key.
Must reference an Id-typed field on the returned SObject.

**Returns:** [SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm) - Map > keyed by the field value. Records with a null key field are grouped under the null key. Returns an empty map if the query yields no results.

**Since:** 1.0

**Example:**

```apex
Map<Id, List<SObject>> contactsByAccount = QRY_Builder.selectFrom(Contact.SObjectType)
    .addFields(new List<SObjectField>{Contact.Id, Contact.AccountId})
    .condition(Contact.AccountId).isNotNull()
    .asGroupedMapById(Contact.AccountId);
```

```apex
global Map<Id, List<SObject>> asGroupedMapById(String fieldName)
```

Executes the query and returns the results grouped by an Id field.
Supports dot-notation for parent fields. Delegates to UTIL_SObject.groupByKey.

**Parameters:**

- `fieldName` ([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)) - The API name of the Id field whose value will be used as the map key.

**Returns:** [SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm) - Map > keyed by the field value. Records with a null key field are grouped under the null key. Returns an empty map when the query yields no results.

**Since:** 1.0

**Example:**

```apex
Map<Id, List<SObject>> contactsByOwner = QRY_Builder.selectFrom(Contact.SObjectType)
    .addField(Contact.OwnerId)
    .asGroupedMapById('OwnerId');
```

### asGroupedMapByString

```apex
global Map<String, List<SObject>> asGroupedMapByString(SObjectField keyField)
```

Executes the query and returns the results grouped by a String field
value. Duplicates are preserved as separate entries within each group. Key casing
is preserved. Delegates to UTIL_SObject.groupByStringKey.

**Parameters:**

- `keyField` ([SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm)) - The SObjectField token whose value will be used as the map key.

**Returns:** [SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm) - Map > keyed by the stringified field value. Returns an empty map when the query yields no results.

**Since:** 1.0

**Example:**

```apex
Map<String, List<SObject>> accountsByIndustry = QRY_Builder.selectFrom(Account.SObjectType)
    .addField(Account.Industry)
    .asGroupedMapByString(Account.Industry);
```

```apex
global Map<String, List<SObject>> asGroupedMapByString(String fieldName)
```

Executes the query and returns the results grouped by a String field
value. Supports dot-notation for parent fields. Key casing is preserved.
Delegates to UTIL_SObject.groupByStringKey.

**Parameters:**

- `fieldName` ([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)) - The API name of the field whose value will be used as the map key.

**Returns:** [SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm) - Map > keyed by the stringified field value. Returns an empty map when the query yields no results.

**Since:** 1.0

**Example:**

```apex
Map<String, List<SObject>> accountsByOwnerName = QRY_Builder.selectFrom(Account.SObjectType)
    .addField(Account.OwnerId)
    .relatedField('Owner.Name')
    .asGroupedMapByString('Owner.Name');
```

### asIdList

```apex
global List<Id> asIdList()
```

Returns the results as a List of Ids.

**Returns:** [Id](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_id.htm) - List

**Since:** 1.0

**Example:**

```apex
List<Id> accountIds = QRY_Builder.selectFrom(Account.SObjectType)
    .condition(Account.Type).equals('Customer')
    .asIdList();
```

### asIdSet

```apex
global Set<Id> asIdSet()
```

Executes the query and returns a Set of record Ids.

**Returns:** [Id](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_id.htm) - Set

**Since:** 1.0

**Example:**

```apex
Set<Id> accountIds = QRY_Builder.selectFrom(Account.SObjectType)
    .condition(Account.Type).equals('Customer')
    .asIdSet();
```

### asMap

```apex
global Map<Id, SObject> asMap()
```

Executes the query and returns results as a Map .

**Returns:** [SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm) - Map

**Since:** 1.0

**Example:**

```apex
Map<Id, SObject> accountMap = QRY_Builder.selectFrom(Account.SObjectType)
    .condition(Account.Type).equals('Customer')
    .asMap();
```

### asMapById

```apex
global Map<Id, SObject> asMapById(SObjectField keyField)
```

Executes the query and returns the results as a Map keyed by the
specified Id field (e.g. a parent-lookup field). Last record wins when key values
collide. Delegates to UTIL_SObject.indexById.

**Parameters:**

- `keyField` ([SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm)) - The SObjectField token whose value will be used as the map key.
Must reference an Id-typed field on the returned SObject.

**Returns:** [SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm) - Map keyed by the field value. Records with a null key field are mapped under the null key. Returns an empty map when the query yields no results.

**Since:** 1.0

**Example:**

```apex
Map<Id, SObject> contactsByAccount = QRY_Builder.selectFrom(Contact.SObjectType)
    .addFields(new List<SObjectField>{Contact.Id, Contact.AccountId})
    .condition(Contact.AccountId).isNotNull()
    .asMapById(Contact.AccountId);
```

```apex
global Map<Id, SObject> asMapById(String fieldName)
```

Executes the query and returns the results as a Map keyed by the
specified Id field. Supports dot-notation for parent fields (e.g. 'Account.OwnerId').
Delegates to UTIL_SObject.indexById.

**Parameters:**

- `fieldName` ([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)) - The API name of the Id field whose value will be used as the map key.

**Returns:** [SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm) - Map keyed by the field value. Records with a null key field are mapped under the null key. Returns an empty map when the query yields no results.

**Since:** 1.0

**Example:**

```apex
Map<Id, SObject> contactsByOwner = QRY_Builder.selectFrom(Contact.SObjectType)
    .addField(Contact.OwnerId)
    .asMapById('OwnerId');
```

### asMapByString

```apex
global Map<String, SObject> asMapByString(SObjectField keyField)
```

Executes the query and returns the results as a Map keyed by a String
field value. Last record wins when key values collide. Key casing is preserved
(no implicit lowering). Delegates to UTIL_SObject.indexByStringKey.

**Parameters:**

- `keyField` ([SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm)) - The SObjectField token whose value will be used as the map key.

**Returns:** [SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm) - Map keyed by the stringified field value. Returns an empty map when the query yields no results.

**Since:** 1.0

**Example:**

```apex
Map<String, SObject> accountByName = QRY_Builder.selectFrom(Account.SObjectType)
    .addField(Account.Name)
    .asMapByString(Account.Name);
```

```apex
global Map<String, SObject> asMapByString(String fieldName)
```

Executes the query and returns the results as a Map keyed by a String
field value. Supports dot-notation for parent fields (e.g. 'Owner.Name'). Key casing
is preserved. Delegates to UTIL_SObject.indexByStringKey.

**Parameters:**

- `fieldName` ([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)) - The API name of the field whose value will be used as the map key.

**Returns:** [SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm) - Map keyed by the stringified field value. Returns an empty map when the query yields no results.

**Since:** 1.0

**Example:**

```apex
Map<String, SObject> accountByOwnerName = QRY_Builder.selectFrom(Account.SObjectType)
    .addField(Account.OwnerId)
    .relatedField('Owner.Name')
    .asMapByString('Owner.Name');
```

### asStringSet

```apex
global Set<String> asStringSet(SObjectField field)
```

Executes the query and returns a Set of distinct String values for the specified field.

**Parameters:**

- `field` ([SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm)) - The field token to extract String values from

**Returns:** [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) - Set of String field values (nulls excluded)

**Since:** 1.0

**Example:**

```apex
Set<String> nicknames = QRY_Builder.selectFrom(User.SObjectType)
    .addField(User.CommunityNickname)
    .condition(User.CommunityNickname).startsWith('Billy')
    .asStringSet(User.CommunityNickname);
```

```apex
global Set<String> asStringSet(String fieldName)
```

Executes the query and returns a Set of distinct String values for the specified field.

**Parameters:**

- `fieldName` ([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)) - The field API name to extract String values from

**Returns:** [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) - Set of String field values (nulls excluded)

**Since:** 1.0

**Example:**

```apex
Set<String> ownerNames = QRY_Builder.selectFrom(Account.SObjectType)
    .relatedField('Owner.Name')
    .asStringSet('Owner.Name');
```

### asValueSet

```apex
global Set<Object> asValueSet(SObjectField field)
```

Executes the query and returns a Set of distinct values for the specified field.

**Parameters:**

- `field` ([SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm)) - The field token to extract values from

**Returns:** [Object](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_System_Object.htm) - Set of field values

**Since:** 1.0

**Example:**

```apex
Set<Object> industries = QRY_Builder.selectFrom(Account.SObjectType)
    .addField(Account.Industry)
    .asValueSet(Account.Industry);
```

```apex
global Set<Object> asValueSet(String fieldName)
```

Executes the query and returns a Set of distinct values for the specified field.

**Parameters:**

- `fieldName` ([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)) - The field API name to extract values from

**Returns:** [Object](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_System_Object.htm) - Set of field values

**Since:** 1.0

**Example:**

```apex
Set<Object> ownerNames = QRY_Builder.selectFrom(Account.SObjectType)
    .relatedField('Owner.Name')
    .asValueSet('Owner.Name');
```

### avg

```apex
global QRY_Builder.Builder avg(SObjectField field)
```

Applies an AVG aggregate function.

**Parameters:**

- `field` ([SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm)) - The field to aggregate

**Returns:** [QRY_Builder.Builder](QRY_Builder.Builder.md) - Builder for chaining

**Since:** 1.0

**Example:**

```apex
List<AggregateResult> results = QRY_Builder.selectFrom(Opportunity.SObjectType)
    .groupBy(Opportunity.StageName)
    .avg(Opportunity.Amount)
    .toList();
```

### bypassSharing

```apex
global QRY_Builder.Builder bypassSharing()
```

Bypasses sharing rules using a `without sharing` proxy class.

**Returns:** [QRY_Builder.Builder](QRY_Builder.Builder.md) - Builder for chaining

**Since:** 1.0

**Example:**

```apex
List<Account> accounts = QRY_Builder.selectFrom(Account.SObjectType)
    .bypassSharing()
    .toList();
```

### condition

```apex
global QRY_Builder.ConditionBuilder condition(SObjectField objectField)
```

Starts a WHERE condition on a field using an SObjectField token.

**Parameters:**

- `objectField` ([SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm)) - Field token

**Returns:** [QRY_Builder.ConditionBuilder](QRY_Builder.ConditionBuilder.md) - ConditionBuilder for specifying the operator

**Since:** 1.0

**Example:**

```apex
List<Account> accounts = QRY_Builder.selectFrom(Account.SObjectType)
    .condition(Account.Industry).equals('Technology')
    .toList();
```

```apex
global QRY_Builder.ConditionBuilder condition(String fieldName)
```

Starts a WHERE condition on a field using its API name.

**Parameters:**

- `fieldName` ([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)) - Field API name

**Returns:** [QRY_Builder.ConditionBuilder](QRY_Builder.ConditionBuilder.md) - ConditionBuilder for specifying the operator

**Since:** 1.0

**Example:**

```apex
List<Account> accounts = QRY_Builder.selectFrom(Account.SObjectType)
    .condition('Industry').equals('Technology')
    .toList();
```

### count

```apex
global Integer count()
```

Returns the number of records that match the query criteria.

**Returns:** [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) - Integer count

**Since:** 1.0

**Example:**

```apex
Integer total = QRY_Builder.selectFrom(Account.SObjectType)
    .condition(Account.Type).equals('Customer')
    .count();
```

```apex
global QRY_Builder.Builder count(String fieldName)
```

Applies a COUNT aggregate function.

**Parameters:**

- `fieldName` ([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)) - The field to count (or null for COUNT())

**Returns:** [QRY_Builder.Builder](QRY_Builder.Builder.md) - Builder for chaining

**Since:** 1.0

**Example:**

```apex
List<AggregateResult> results = QRY_Builder.selectFrom(Account.SObjectType)
    .groupBy(Account.Industry)
    .count('Id')
    .toList();
```

### countDistinct

```apex
global QRY_Builder.Builder countDistinct(SObjectField field)
```

Applies a COUNT_DISTINCT aggregate function.

**Parameters:**

- `field` ([SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm)) - The field to count distinct values

**Returns:** [QRY_Builder.Builder](QRY_Builder.Builder.md) - Builder for chaining

**Since:** 1.0

**Example:**

```apex
List<AggregateResult> results = QRY_Builder.selectFrom(Contact.SObjectType)
    .groupBy(Contact.AccountId)
    .countDistinct(Contact.Email)
    .toList();
```

```apex
global QRY_Builder.Builder countDistinct(String fieldName)
```

Applies a COUNT_DISTINCT aggregate function.

**Parameters:**

- `fieldName` ([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)) - The field name to count distinct values

**Returns:** [QRY_Builder.Builder](QRY_Builder.Builder.md) - Builder for chaining

**Since:** 1.0

**Example:**

```apex
List<AggregateResult> results = QRY_Builder.selectFrom(Contact.SObjectType)
    .groupBy(Contact.AccountId)
    .countDistinct('Email')
    .toList();
```

### cube

```apex
global QRY_Builder.Builder cube()
```

Flags the GROUP BY clause as CUBE for cross-tabulation.

**Returns:** [QRY_Builder.Builder](QRY_Builder.Builder.md) - Builder for chaining

**Since:** 1.0

**Example:**

```apex
List<QRY_Builder.AggregateRow> results = QRY_Builder.selectFrom(Opportunity.SObjectType)
    .groupBy(Opportunity.StageName)
    .groupBy(Opportunity.LeadSource)
    .sum(Opportunity.Amount)
    .cube()
    .toAggregateList();
```

### descending

```apex
global QRY_Builder.Builder descending()
```

Sets the last ORDER BY clause to DESCENDING.

**Returns:** [QRY_Builder.Builder](QRY_Builder.Builder.md) - Builder for chaining

**Since:** 1.0

**Example:**

```apex
List<Account> accounts = QRY_Builder.selectFrom(Account.SObjectType)
    .orderBy(Account.CreatedDate).descending()
    .toList();
```

### exists

```apex
global Boolean exists()
```

Checks whether any records exist matching the query criteria.

**Returns:** [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) - Boolean true if at least one record exists

**Since:** 1.0

**Example:**

```apex
Boolean hasCustomers = QRY_Builder.selectFrom(Account.SObjectType)
    .condition(Account.Type).equals('Customer')
    .exists();
```

### fields

```apex
global QRY_Builder.Builder fields(List<SObjectField> objectFields)
```

Explicitly select fields using SObjectField tokens.

**Parameters:**

- `objectFields` ([List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)) - List of SObjectField tokens

**Returns:** [QRY_Builder.Builder](QRY_Builder.Builder.md) - Builder for chaining

**Since:** 1.0

**Example:**

```apex
List<Account> accounts = QRY_Builder.selectFrom(Account.SObjectType)
    .fields(new List<SObjectField>{Account.Name, Account.Industry})
    .toList();
```

```apex
global QRY_Builder.Builder fields(List<String> fieldNames)
```

Explicitly select fields by API name.

**Parameters:**

- `fieldNames` ([List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)) - List of field API names

**Returns:** [QRY_Builder.Builder](QRY_Builder.Builder.md) - Builder for chaining

**Since:** 1.0

**Example:**

```apex
List<Account> accounts = QRY_Builder.selectFrom(Account.SObjectType)
    .fields(new List<String>{'Name', 'Industry', 'AnnualRevenue'})
    .toList();
```

### fieldSet

```apex
global QRY_Builder.Builder fieldSet(FieldSet aFieldset)
```

Selects fields from a FieldSet token.

**Parameters:**

- `aFieldset` ([FieldSet](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_fieldsets_describe.htm)) - The Schema.FieldSet token

**Returns:** [QRY_Builder.Builder](QRY_Builder.Builder.md) - Builder for chaining

**Since:** 1.0

**Example:**

```apex
FieldSet fs = SObjectType.Account.fieldSets.Account_Summary;
List<Account> accounts = QRY_Builder.selectFrom(Account.SObjectType)
    .fieldSet(fs)
    .toList();
```

```apex
global QRY_Builder.Builder fieldSet(String fieldSetName)
```

Selects fields from a FieldSet.

**Parameters:**

- `fieldSetName` ([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)) - The API Name of the FieldSet

**Returns:** [QRY_Builder.Builder](QRY_Builder.Builder.md) - Builder for chaining

**Since:** 1.0

**Example:**

```apex
List<Account> accounts = QRY_Builder.selectFrom(Account.SObjectType)
    .fieldSet('Account_Summary')
    .toList();
```

### forcePerformanceLogging

```apex
global QRY_Builder.Builder forcePerformanceLogging()
```

Forces performance logging regardless of threshold for this query.

**Returns:** [QRY_Builder.Builder](QRY_Builder.Builder.md) - Builder for chaining

**Since:** 1.0

**Example:**

```apex
List<Account> accounts = QRY_Builder.selectFrom(Account.SObjectType)
    .forcePerformanceLogging()
    .toList();
```

### forReference

```apex
global QRY_Builder.Builder forReference()
```

Locks returned records FOR REFERENCE.

**Returns:** [QRY_Builder.Builder](QRY_Builder.Builder.md) - Builder for chaining

**Since:** 1.0

**Example:**

```apex
List<Account> accounts = QRY_Builder.selectFrom(Account.SObjectType)
    .condition(Account.Id).equals(accountId)
    .forReference()
    .toList();
```

### forUpdate

```apex
global QRY_Builder.Builder forUpdate()
```

Locks returned records FOR UPDATE.

**Returns:** [QRY_Builder.Builder](QRY_Builder.Builder.md) - Builder for chaining

**Since:** 1.0

**Example:**

```apex
List<Account> accounts = QRY_Builder.selectFrom(Account.SObjectType)
    .condition(Account.Id).equals(accountId)
    .forUpdate()
    .toList();
```

### forView

```apex
global QRY_Builder.Builder forView()
```

Locks returned records FOR VIEW.

**Returns:** [QRY_Builder.Builder](QRY_Builder.Builder.md) - Builder for chaining

**Since:** 1.0

**Example:**

```apex
List<Account> accounts = QRY_Builder.selectFrom(Account.SObjectType)
    .condition(Account.Id).equals(accountId)
    .forView()
    .toList();
```

### getDefaultFields

```apex
global virtual Set<String> getDefaultFields()
```

Override to provide default fields for this selector.

**Returns:** [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) - Set of field API names

**Since:** 1.0

**Example:**

```apex
public override Set<String> getDefaultFields()
{
    return new Set<String>{'Name', 'Industry', 'Type'};
}
```

### getFirst

```apex
global SObject getFirst()
```

Executes the query and returns the first record (or null).

**Returns:** [SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm) - Single SObject or null

**Since:** 1.0

**Example:**

```apex
Account account = (Account)QRY_Builder.selectFrom(Account.SObjectType)
    .condition(Account.Id).equals(accountId)
    .getFirst();
```

### getFirstAggregate

```apex
global QRY_Builder.AggregateRow getFirstAggregate()
```

Executes an aggregate query and returns the first result as a typed AggregateRow.
Convenience method for single-row aggregates (e.g., SUM without GROUP BY).

**Returns:** [QRY_Builder.AggregateRow](QRY_Builder.AggregateRow.md) - Single AggregateRow or null if no results

**Since:** 1.0

**Example:**

```apex
QRY_Builder.AggregateRow row = QRY_Builder.selectFrom(Opportunity.SObjectType)
    .sum('Amount')
    .getFirstAggregate();
Decimal totalAmount = row.getDecimal('expr0');
```

### getPage

```apex
global QRY_Builder.QueryPage getPage(Integer requestedPageNumber, Integer requestedPageSize)
```

Executes a paged query and returns results with pagination metadata.

**Parameters:**

- `requestedPageNumber` ([Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm)) - The page number to retrieve (1-based)
- `requestedPageSize` ([Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm)) - Number of records per page

**Returns:** [QRY_Builder.QueryPage](QRY_Builder.QueryPage.md) - Page containing records and pagination metadata

**Since:** 1.0

**Example:**

```apex
QRY_Builder.QueryPage page = QRY_Builder.selectFrom(Account.SObjectType)
    .condition(Account.Type).equals('Customer')
    .orderBy(Account.Name).ascending()
    .getPage(2, 25);
```

### getRandomItem

```apex
global SObject getRandomItem()
```

Returns a single random record matching the query criteria.

**Returns:** [SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm) - Single random SObject or null

**Since:** 1.0

**Example:**

```apex
Account random = (Account)QRY_Builder.selectFrom(Account.SObjectType)
    .condition(Account.Type).equals('Customer')
    .getRandomItem();
```

### getRandomItems

```apex
global List<SObject> getRandomItems(Integer randomCount)
```

Returns multiple random records matching the query criteria.
Uses a Database.Cursor to fetch records at a random offset, eliminating
the 2,000 SOQL OFFSET limitation. Supports random selection across the
full result set (up to 50 million records).

When mocks are active, falls back to standard SOQL OFFSET (capped at 2,000).

**Parameters:**

- `randomCount` ([Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm)) - Maximum number of random records to return

**Returns:** [SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm) - List of random SObjects

**Since:** 1.0

**Example:**

```apex
List<Account> randoms = QRY_Builder.selectFrom(Account.SObjectType)
    .condition(Account.Type).equals('Customer')
    .getRandomItems(5);
```

### groupBy

```apex
global virtual QRY_Builder.Builder groupBy(QRY_Function functionField)
```

Adds a SOQL date-function expression to the GROUP BY clause (e.g. CALENDAR_MONTH(CloseDate)),
bucketing records by that date part. Use the same QRY_Function factory in addField to project the bucket.

**Parameters:**

- `functionField` ([QRY_Function](QRY_Function.md)) - The date-function expression, from a QRY_Function factory

**Returns:** [QRY_Builder.Builder](QRY_Builder.Builder.md) - Builder for chaining

**Since:** 1.1

**Example:**

```apex
QRY_Builder.selectFrom(Opportunity.SObjectType)
    .addField(QRY_Function.calendarMonth(Opportunity.CloseDate), 'closeMonth')
    .count('Id')
    .groupBy(QRY_Function.calendarMonth(Opportunity.CloseDate))
    .toAggregateList();
```

```apex
global QRY_Builder.Builder groupBy(SObjectField groupField)
```

Adds a field to the GROUP BY clause using an SObjectField token.
Call multiple times for multi-field grouping (max 3 per SOQL spec).

**Parameters:**

- `groupField` ([SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm)) - The field to group by

**Returns:** [QRY_Builder.Builder](QRY_Builder.Builder.md) - Builder for chaining

**Since:** 1.0

**Example:**

```apex
List<QRY_Builder.AggregateRow> results = QRY_Builder.selectFrom(Account.SObjectType)
    .groupBy(Account.Industry)
    .groupBy(Account.Rating)
    .count('Id')
    .toAggregateList();
```

```apex
global QRY_Builder.Builder groupBy(String groupField)
```

Adds a GROUP BY clause.

**Parameters:**

- `groupField` ([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)) - The field to group by

**Returns:** [QRY_Builder.Builder](QRY_Builder.Builder.md) - Builder for chaining

**Since:** 1.0

**Example:**

```apex
List<AggregateResult> results = QRY_Builder.selectFrom(Account.SObjectType)
    .groupBy('Industry')
    .count('Id')
    .toList();
```

### grouping

```apex
global QRY_Builder.Builder grouping(SObjectField field)
```

Adds a GROUPING(field) expression to the SELECT clause for use with ROLLUP or CUBE.
Returns 1 for subtotal rows and 0 for regular data rows.

**Parameters:**

- `field` ([SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm)) - The field to wrap in GROUPING()

**Returns:** [QRY_Builder.Builder](QRY_Builder.Builder.md) - Builder for chaining

**Since:** 1.0

**Example:**

```apex
List<QRY_Builder.AggregateRow> results = QRY_Builder.selectFrom(Opportunity.SObjectType)
    .groupBy(Opportunity.StageName)
    .grouping(Opportunity.StageName)
    .sum(Opportunity.Amount)
    .rollup()
    .toAggregateList();
```

```apex
global QRY_Builder.Builder grouping(String fieldName)
```

Adds a GROUPING(field) expression to the SELECT clause by field name.

**Parameters:**

- `fieldName` ([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)) - The field API name to wrap in GROUPING()

**Returns:** [QRY_Builder.Builder](QRY_Builder.Builder.md) - Builder for chaining

**Since:** 1.0

**Example:**

```apex
.groupBy('Industry').grouping('Industry').rollup()
```

### havingAvgOf

```apex
global QRY_Builder.ConditionBuilder havingAvgOf(SObjectField field)
```

Starts a HAVING condition on the AVG of a field.

**Parameters:**

- `field` ([SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm)) - The field to aggregate

**Returns:** [QRY_Builder.ConditionBuilder](QRY_Builder.ConditionBuilder.md) - ConditionBuilder configured for HAVING

**Since:** 1.0

**Example:**

```apex
List<AggregateResult> results = QRY_Builder.selectFrom(Opportunity.SObjectType)
    .groupBy(Opportunity.AccountId)
    .avg(Opportunity.Amount)
    .havingAvgOf(Opportunity.Amount).greaterThan(50000)
    .toList();
```

### havingCount

```apex
global QRY_Builder.ConditionBuilder havingCount()
```

Starts a HAVING condition on the global COUNT().

**Returns:** [QRY_Builder.ConditionBuilder](QRY_Builder.ConditionBuilder.md) - ConditionBuilder configured for HAVING

**Since:** 1.0

**Example:**

```apex
List<AggregateResult> results = QRY_Builder.selectFrom(Contact.SObjectType)
    .groupBy(Contact.AccountId)
    .count('Id')
    .havingCount().greaterThan(5)
    .toList();
```

### havingCountOf

```apex
global QRY_Builder.ConditionBuilder havingCountOf(SObjectField field)
```

Starts a HAVING condition on the COUNT of a field.

**Parameters:**

- `field` ([SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm)) - The field to count

**Returns:** [QRY_Builder.ConditionBuilder](QRY_Builder.ConditionBuilder.md) - ConditionBuilder configured for HAVING

**Since:** 1.0

**Example:**

```apex
List<AggregateResult> results = QRY_Builder.selectFrom(Contact.SObjectType)
    .groupBy(Contact.AccountId)
    .count('Id')
    .havingCountOf(Contact.Id).greaterThan(10)
    .toList();
```

### havingMaxOf

```apex
global QRY_Builder.ConditionBuilder havingMaxOf(SObjectField field)
```

Starts a HAVING condition on the MAX of a field.

**Parameters:**

- `field` ([SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm)) - The field to aggregate

**Returns:** [QRY_Builder.ConditionBuilder](QRY_Builder.ConditionBuilder.md) - ConditionBuilder configured for HAVING

**Since:** 1.0

**Example:**

```apex
List<AggregateResult> results = QRY_Builder.selectFrom(Opportunity.SObjectType)
    .groupBy(Opportunity.AccountId)
    .max(Opportunity.Amount)
    .havingMaxOf(Opportunity.Amount).lessThan(1000000)
    .toList();
```

### havingMinOf

```apex
global QRY_Builder.ConditionBuilder havingMinOf(SObjectField field)
```

Starts a HAVING condition on the MIN of a field.

**Parameters:**

- `field` ([SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm)) - The field to aggregate

**Returns:** [QRY_Builder.ConditionBuilder](QRY_Builder.ConditionBuilder.md) - ConditionBuilder configured for HAVING

**Since:** 1.0

**Example:**

```apex
List<AggregateResult> results = QRY_Builder.selectFrom(Opportunity.SObjectType)
    .groupBy(Opportunity.AccountId)
    .min(Opportunity.Amount)
    .havingMinOf(Opportunity.Amount).greaterThan(1000)
    .toList();
```

### havingSumOf

```apex
global QRY_Builder.ConditionBuilder havingSumOf(SObjectField field)
```

Starts a HAVING condition on the SUM of a field.

**Parameters:**

- `field` ([SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm)) - The field to aggregate

**Returns:** [QRY_Builder.ConditionBuilder](QRY_Builder.ConditionBuilder.md) - ConditionBuilder configured for HAVING

**Since:** 1.0

**Example:**

```apex
List<AggregateResult> results = QRY_Builder.selectFrom(Opportunity.SObjectType)
    .groupBy(Opportunity.AccountId)
    .sum(Opportunity.Amount)
    .havingSumOf(Opportunity.Amount).greaterThan(100000)
    .toList();
```

### isCached

```apex
global Boolean isCached()
```

Indicates whether the last execution retrieved results from cache.

**Returns:** [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) - true if results came from cache

**Since:** 1.0

**Example:**

```apex
QRY_Builder.Builder query = QRY_Builder.selectFrom(Account.SObjectType).withCache(300);
List<SObject> results = query.toList();
Boolean fromCache = query.isCached();
```

### logPerformanceIfSlowerThan

```apex
global QRY_Builder.Builder logPerformanceIfSlowerThan(Integer thresholdMs)
```

Sets a custom performance threshold for this query.
The query will be logged only if duration exceeds this threshold.

**Parameters:**

- `thresholdMs` ([Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm)) - Custom threshold in milliseconds

**Returns:** [QRY_Builder.Builder](QRY_Builder.Builder.md) - Builder for chaining

**Since:** 1.0

**Example:**

```apex
List<Account> accounts = QRY_Builder.selectFrom(Account.SObjectType)
    .logPerformanceIfSlowerThan(500)
    .toList();
```

### max

```apex
global QRY_Builder.Builder max(SObjectField field)
```

Applies a MAX aggregate function.

**Parameters:**

- `field` ([SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm)) - The field to aggregate

**Returns:** [QRY_Builder.Builder](QRY_Builder.Builder.md) - Builder for chaining

**Since:** 1.0

**Example:**

```apex
List<AggregateResult> results = QRY_Builder.selectFrom(Opportunity.SObjectType)
    .groupBy(Opportunity.StageName)
    .max(Opportunity.Amount)
    .toList();
```

### min

```apex
global QRY_Builder.Builder min(SObjectField field)
```

Applies a MIN aggregate function.

**Parameters:**

- `field` ([SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm)) - The field to aggregate

**Returns:** [QRY_Builder.Builder](QRY_Builder.Builder.md) - Builder for chaining

**Since:** 1.0

**Example:**

```apex
List<AggregateResult> results = QRY_Builder.selectFrom(Opportunity.SObjectType)
    .groupBy(Opportunity.StageName)
    .min(Opportunity.CloseDate)
    .toList();
```

### nullsFirst

```apex
global QRY_Builder.Builder nullsFirst()
```

Sets the last ORDER BY clause to NULLS FIRST.

**Returns:** [QRY_Builder.Builder](QRY_Builder.Builder.md) - Builder for chaining

**Since:** 1.0

**Example:**

```apex
List<Account> accounts = QRY_Builder.selectFrom(Account.SObjectType)
    .orderBy(Account.Industry).ascending().nullsFirst()
    .toList();
```

### nullsLast

```apex
global QRY_Builder.Builder nullsLast()
```

Sets the last ORDER BY clause to NULLS LAST.

**Returns:** [QRY_Builder.Builder](QRY_Builder.Builder.md) - Builder for chaining

**Since:** 1.0

**Example:**

```apex
List<Account> accounts = QRY_Builder.selectFrom(Account.SObjectType)
    .orderBy(Account.Industry).ascending().nullsLast()
    .toList();
```

### orCondition

```apex
global QRY_Builder.ConditionBuilder orCondition(SObjectField field)
```

Starts an OR condition on a field using an SObjectField token.

**Parameters:**

- `field` ([SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm)) - Field token

**Returns:** [QRY_Builder.ConditionBuilder](QRY_Builder.ConditionBuilder.md) - ConditionBuilder for specifying the operator

**Since:** 1.0

**Example:**

```apex
List<Account> accounts = QRY_Builder.selectFrom(Account.SObjectType)
    .condition(Account.Industry).equals('Technology')
    .orCondition(Account.Industry).equals('Finance')
    .toList();
```

```apex
global QRY_Builder.ConditionBuilder orCondition(String fieldName)
```

Starts an OR condition on a field using its API name.

**Parameters:**

- `fieldName` ([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)) - Field API name

**Returns:** [QRY_Builder.ConditionBuilder](QRY_Builder.ConditionBuilder.md) - ConditionBuilder for specifying the operator

**Since:** 1.0

**Example:**

```apex
List<Account> accounts = QRY_Builder.selectFrom(Account.SObjectType)
    .condition('Industry').equals('Technology')
    .orCondition('Industry').equals('Finance')
    .toList();
```

### orderBy

```apex
global virtual QRY_Builder.Builder orderBy(QRY_Function functionField)
```

Orders by a SOQL date-function expression, ascending (e.g. ORDER BY CALENDAR_MONTH(CloseDate)).

**Parameters:**

- `functionField` ([QRY_Function](QRY_Function.md)) - The date-function expression, from a QRY_Function factory

**Returns:** [QRY_Builder.Builder](QRY_Builder.Builder.md) - Builder for chaining

**Since:** 1.1

**Example:**

```apex
.orderBy(QRY_Function.calendarMonth(Opportunity.CloseDate))
```

```apex
global virtual QRY_Builder.Builder orderBy(QRY_Function functionField, Boolean sortDescending)
```

Orders by a SOQL date-function expression, ascending or descending.

**Parameters:**

- `functionField` ([QRY_Function](QRY_Function.md)) - The date-function expression, from a QRY_Function factory
- `sortDescending` ([Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm)) - When true, sorts DESCENDING; otherwise ASCENDING

**Returns:** [QRY_Builder.Builder](QRY_Builder.Builder.md) - Builder for chaining

**Since:** 1.1

**Example:**

```apex
.orderBy(QRY_Function.calendarMonth(Opportunity.CloseDate), true)
```

```apex
global QRY_Builder.Builder orderBy(SObjectField field)
```

Adds an ORDER BY clause (default ascending).

**Parameters:**

- `field` ([SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm)) - Field token to sort by

**Returns:** [QRY_Builder.Builder](QRY_Builder.Builder.md) - Builder for chaining

**Since:** 1.0

**Example:**

```apex
List<Account> accounts = QRY_Builder.selectFrom(Account.SObjectType)
    .orderBy(Account.Name).ascending()
    .toList();
```

```apex
global QRY_Builder.Builder orderBy(SObjectField field, Boolean sortDescending)
```

Adds an ORDER BY clause with a dynamic sort direction. Nulls placement
defaults to standard SOQL behavior (NULLS FIRST for ASC, NULLS LAST for DESC).

**Parameters:**

- `field` ([SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm)) - Field token to sort by
- `sortDescending` ([Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm)) - When true, sorts DESCENDING; otherwise ASCENDING

**Returns:** [QRY_Builder.Builder](QRY_Builder.Builder.md) - Builder for chaining

**Since:** 1.0

**Example:**

```apex
Boolean isDescending = true;
List<Account> accounts = QRY_Builder.selectFrom(Account.SObjectType)
    .orderBy(Account.Name, isDescending)
    .toList();
```

```apex
global QRY_Builder.Builder orderBy(SObjectField field, Boolean sortDescending, Boolean nullsLast)
```

Adds an ORDER BY clause with a dynamic sort direction and nulls placement.

**Parameters:**

- `field` ([SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm)) - Field token to sort by
- `sortDescending` ([Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm)) - When true, sorts DESCENDING; otherwise ASCENDING
- `nullsLast` ([Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm)) - When true, places nulls last; otherwise places nulls first

**Returns:** [QRY_Builder.Builder](QRY_Builder.Builder.md) - Builder for chaining

**Since:** 1.0

**Example:**

```apex
Boolean isDescending = true;
Boolean isNullsLast = true;
List<Account> accounts = QRY_Builder.selectFrom(Account.SObjectType)
    .orderBy(Account.Name, isDescending, isNullsLast)
    .toList();
```

```apex
global QRY_Builder.Builder orderBy(String fieldName)
```

Adds an ORDER BY clause (default ascending).

**Parameters:**

- `fieldName` ([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)) - Field API name to sort by

**Returns:** [QRY_Builder.Builder](QRY_Builder.Builder.md) - Builder for chaining

**Since:** 1.0

**Example:**

```apex
List<Account> accounts = QRY_Builder.selectFrom(Account.SObjectType)
    .orderBy('CreatedDate').descending()
    .toList();
```

```apex
global QRY_Builder.Builder orderBy(String fieldName, Boolean sortDescending)
```

Adds an ORDER BY clause with a dynamic sort direction. Nulls placement
defaults to standard SOQL behavior (NULLS FIRST for ASC, NULLS LAST for DESC).

**Parameters:**

- `fieldName` ([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)) - Field API name to sort by
- `sortDescending` ([Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm)) - When true, sorts DESCENDING; otherwise ASCENDING

**Returns:** [QRY_Builder.Builder](QRY_Builder.Builder.md) - Builder for chaining

**Since:** 1.0

**Example:**

```apex
Boolean isDescending = false;
List<Account> accounts = QRY_Builder.selectFrom(Account.SObjectType)
    .orderBy('CreatedDate', isDescending)
    .toList();
```

```apex
global QRY_Builder.Builder orderBy(String fieldName, Boolean sortDescending, Boolean nullsLast)
```

Adds an ORDER BY clause with a dynamic sort direction and nulls placement.

**Parameters:**

- `fieldName` ([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)) - Field API name to sort by
- `sortDescending` ([Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm)) - When true, sorts DESCENDING; otherwise ASCENDING
- `nullsLast` ([Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm)) - When true, places nulls last; otherwise places nulls first

**Returns:** [QRY_Builder.Builder](QRY_Builder.Builder.md) - Builder for chaining

**Since:** 1.0

**Example:**

```apex
Boolean isDescending = true;
Boolean isNullsLast = false;
List<Account> accounts = QRY_Builder.selectFrom(Account.SObjectType)
    .orderBy('CreatedDate', isDescending, isNullsLast)
    .toList();
```

### relatedField

```apex
global QRY_Builder.Builder relatedField(String parentField)
```

Adds a single parent field.

**Parameters:**

- `parentField` ([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)) - Field path (e.g., 'Account.Owner.Name')

**Returns:** [QRY_Builder.Builder](QRY_Builder.Builder.md) - Builder for chaining

**Since:** 1.0

**Example:**

```apex
List<Contact> contacts = QRY_Builder.selectFrom(Contact.SObjectType)
    .relatedField('Account.Owner.Name')
    .toList();
```

### relatedFields

```apex
global QRY_Builder.Builder relatedFields(List<String> parentFields)
```

Adds parent (related) fields to the selection.

**Parameters:**

- `parentFields` ([List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)) - List of field paths (e.g., 'Account.Name')

**Returns:** [QRY_Builder.Builder](QRY_Builder.Builder.md) - Builder for chaining

**Since:** 1.0

**Example:**

```apex
List<Contact> contacts = QRY_Builder.selectFrom(Contact.SObjectType)
    .relatedFields(new List<String>{'Account.Name', 'Account.Industry'})
    .toList();
```

### rollup

```apex
global QRY_Builder.Builder rollup()
```

Flags the GROUP BY clause as ROLLUP for subtotals.

**Returns:** [QRY_Builder.Builder](QRY_Builder.Builder.md) - Builder for chaining

**Since:** 1.0

**Example:**

```apex
List<QRY_Builder.AggregateRow> results = QRY_Builder.selectFrom(Opportunity.SObjectType)
    .groupBy(Opportunity.StageName)
    .groupBy(Opportunity.AccountId)
    .sum(Opportunity.Amount)
    .rollup()
    .toAggregateList();
```

### selectAllFields

```apex
global QRY_Builder.Builder selectAllFields()
```

Configures the query to select ALL fields on the object.

**Returns:** [QRY_Builder.Builder](QRY_Builder.Builder.md) - Builder for chaining

**Since:** 1.0

**Example:**

```apex
List<Account> accounts = QRY_Builder.selectFrom(Account.SObjectType)
    .selectAllFields()
    .withLimit(10)
    .toList();
```

### stripInaccessible

```apex
global QRY_Builder.Builder stripInaccessible()
```

Strips inaccessible fields from results.

**Returns:** [QRY_Builder.Builder](QRY_Builder.Builder.md) - Builder for chaining

**Since:** 1.0

**Example:**

```apex
List<Account> accounts = QRY_Builder.selectFrom(Account.SObjectType)
    .stripInaccessible()
    .toList();
```

### subselect

```apex
global QRY_Builder.Builder subselect(QRY_Builder.Builder childQuery, String relationshipName)
```

Adds a child subquery (child relationship query).

**Parameters:**

- `childQuery` ([QRY_Builder.Builder](QRY_Builder.Builder.md)) - Configured Builder for the child object
- `relationshipName` ([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)) - The child relationship API name (e.g., 'Contacts')

**Returns:** [QRY_Builder.Builder](QRY_Builder.Builder.md) - Builder for chaining

**Since:** 1.0

**Example:**

```apex
QRY_Builder.Builder contactQuery = new QRY_Builder.Builder(Contact.SObjectType)
    .fields(new List<SObjectField>{Contact.FirstName, Contact.LastName});
List<Account> accounts = QRY_Builder.selectFrom(Account.SObjectType)
    .subselect(contactQuery, 'Contacts')
    .toList();
```

### sum

```apex
global QRY_Builder.Builder sum(SObjectField field)
```

Applies a SUM aggregate function.

**Parameters:**

- `field` ([SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm)) - The field to aggregate

**Returns:** [QRY_Builder.Builder](QRY_Builder.Builder.md) - Builder for chaining

**Since:** 1.0

**Example:**

```apex
List<AggregateResult> results = QRY_Builder.selectFrom(Opportunity.SObjectType)
    .groupBy(Opportunity.StageName)
    .sum(Opportunity.Amount)
    .toList();
```

### suppressPerformanceLogging

```apex
global QRY_Builder.Builder suppressPerformanceLogging()
```

Suppresses performance logging for this query.

**Returns:** [QRY_Builder.Builder](QRY_Builder.Builder.md) - Builder for chaining

**Since:** 1.0

**Example:**

```apex
List<Account> accounts = QRY_Builder.selectFrom(Account.SObjectType)
    .suppressPerformanceLogging()
    .toList();
```

### toAggregateList

```apex
global List<QRY_Builder.AggregateRow> toAggregateList()
```

Executes an aggregate query and returns results as typed AggregateRow wrappers.
Use with aggregate methods like count(), sum(), avg(), min(), max() and groupBy().

**Returns:** [QRY_Builder.AggregateRow](QRY_Builder.AggregateRow.md) - List of AggregateRow wrappers

**Since:** 1.0

**Example:**

```apex
List<QRY_Builder.AggregateRow> rows = QRY_Builder.selectFrom(Account.SObjectType)
    .count('Id')
    .groupBy('Industry')
    .toAggregateList();
for(QRY_Builder.AggregateRow row : rows)
{
    System.debug(row.getString('Industry') + ': ' + row.getInteger('expr0'));
}
```

### toCursor

```apex
global Database.Cursor toCursor()
```

Returns a Database.Cursor for large data set traversal.

**Returns:** [Database.Cursor](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Database_Cursor.htm) - Database.Cursor

**Since:** 1.0

**Example:**

```apex
Database.Cursor cursor = QRY_Builder.selectFrom(Account.SObjectType)
    .condition(Account.Type).equals('Customer')
    .toCursor();
```

### toList

```apex
global List<SObject> toList()
```

Executes the query and returns a List of SObjects.

**Returns:** [SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm) - List results

**Since:** 1.0

**Example:**

```apex
List<Account> accounts = QRY_Builder.selectFrom(Account.SObjectType)
    .condition(Account.Industry).equals('Technology')
    .toList();
```

### toQueryLocator

```apex
global Database.QueryLocator toQueryLocator()
```

Returns a Database.QueryLocator for batch processing.

**Returns:** [Database.QueryLocator](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_database_batch.htm) - Database.QueryLocator

**Since:** 1.0

**Example:**

```apex
Database.QueryLocator locator = QRY_Builder.selectFrom(Account.SObjectType)
    .condition(Account.Type).equals('Customer')
    .toQueryLocator();
```

### toSoql

```apex
global String toSoql()
```

Generates and returns the SOQL string without executing it.

**Returns:** [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) - The built SOQL query string

**Since:** 1.0

**Example:**

```apex
String soql = QRY_Builder.selectFrom(Account.SObjectType)
    .condition(Account.Industry).equals('Technology')
    .toSoql();
```

### usingScope

```apex
global QRY_Builder.Builder usingScope(QRY_Builder.Scope scopeValue)
```

Filters records by visibility scope using USING SCOPE clause.

**Parameters:**

- `scopeValue` ([QRY_Builder.Scope](QRY_Builder.Scope.md)) - The scope to apply

**Returns:** [QRY_Builder.Builder](QRY_Builder.Builder.md) - Builder for chaining

**Since:** 1.0

**Example:**

```apex
List<Account> accounts = QRY_Builder.selectFrom(Account.SObjectType)
    .usingScope(QRY_Builder.Scope.MINE)
    .toList();
```

### withCache

```apex
global QRY_Builder.Builder withCache(Integer ttlSeconds)
```

Enables platform caching for this query.

**Parameters:**

- `ttlSeconds` ([Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm)) - Time-to-live in seconds

**Returns:** [QRY_Builder.Builder](QRY_Builder.Builder.md) - Builder for chaining

**Since:** 1.0

**Example:**

```apex
Account account = (Account)QRY_Builder.selectFrom(Account.SObjectType)
    .condition(Account.Id).equals(accountId)
    .withCache(300)
    .getFirst();
```

### withDataCategory

```apex
global QRY_Builder.DataCategoryBuilder withDataCategory(String groupName)
```

Starts a WITH DATA CATEGORY filter for the specified data category group.

**Parameters:**

- `groupName` ([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)) - The data category group API name

**Returns:** [QRY_Builder.DataCategoryBuilder](QRY_Builder.DataCategoryBuilder.md) - DataCategoryBuilder for operator selection

**Throws:**

- [IllegalArgumentException](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_classes_exception_methods.htm) - if groupName is blank

**Since:** 1.0

**Example:**

```apex
List<SObject> articles = QRY_Builder.selectFrom(KnowledgeArticleVersion.SObjectType)
    .fields(new List<String>{'Id', 'Title'})
    .condition('PublishStatus').equals('Online')
    .withDataCategory('Geography__c').at('USA__c')
    .withDataCategory('Product__c').below('Electronics__c')
    .toList();
```

### withLimit

```apex
global QRY_Builder.Builder withLimit(Integer recordLimit)
```

Sets the maximum number of records to return (LIMIT).

**Parameters:**

- `recordLimit` ([Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm)) - Maximum number of records

**Returns:** [QRY_Builder.Builder](QRY_Builder.Builder.md) - Builder for chaining

**Since:** 1.0

**Example:**

```apex
List<Account> accounts = QRY_Builder.selectFrom(Account.SObjectType)
    .withLimit(100)
    .toList();
```

### withOffset

```apex
global QRY_Builder.Builder withOffset(Integer rowNumber)
```

Sets the record offset (OFFSET).

**Parameters:**

- `rowNumber` ([Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm)) - Number of records to skip

**Returns:** [QRY_Builder.Builder](QRY_Builder.Builder.md) - Builder for chaining

**Since:** 1.0

**Example:**

```apex
List<Account> accounts = QRY_Builder.selectFrom(Account.SObjectType)
    .withLimit(25)
    .withOffset(50)
    .toList();
```

### withoutSecurity

```apex
global QRY_Builder.Builder withoutSecurity()
```

Disables all security enforcement.

**Returns:** [QRY_Builder.Builder](QRY_Builder.Builder.md) - Builder for chaining

**Since:** 1.0

**Example:**

```apex
List<Account> accounts = QRY_Builder.selectFrom(Account.SObjectType)
    .withoutSecurity()
    .toList();
```

### withSharing

```apex
global QRY_Builder.Builder withSharing()
```

Enforces sharing rules using a `with sharing` proxy class.

**Returns:** [QRY_Builder.Builder](QRY_Builder.Builder.md) - Builder for chaining

**Since:** 1.0

**Example:**

```apex
List<Account> accounts = QRY_Builder.selectFrom(Account.SObjectType)
    .withSharing()
    .toList();
```

### withSystemMode

```apex
global QRY_Builder.Builder withSystemMode()
```

Forces SYSTEM_MODE execution regardless of the `UserModeQueries_Enabled`
feature flag. Framework-internal queries that read CMDT, framework-owned sObjects, or
system-schema tables must use this method so they continue working when the subscriber's
running user lacks FLS/CRUD on those objects by design.

**Returns:** [QRY_Builder.Builder](QRY_Builder.Builder.md) - Builder for chaining

**Since:** 1.0

**Example:**

```apex
TriggerSetting__mdt setting = (TriggerSetting__mdt)QRY_Builder.selectFrom(TriggerSetting__mdt.SObjectType)
    .withSystemMode()
    .condition(TriggerSetting__mdt.SObjectType__c).equals('Account')
    .getFirst();
```

### withUserMode

```apex
global QRY_Builder.Builder withUserMode()
```

Runs the query in USER_MODE.

**Returns:** [QRY_Builder.Builder](QRY_Builder.Builder.md) - Builder for chaining

**Since:** 1.0

**Example:**

```apex
List<Account> accounts = QRY_Builder.selectFrom(Account.SObjectType)
    .withUserMode()
    .toList();
```

