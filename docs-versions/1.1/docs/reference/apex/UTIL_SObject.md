---
title: "UTIL_SObject"
type: class
description: "SObject runtime operations — filtering, field extraction, list-to-map conversion, and dot-notation field value retrieval."
author: "Jason Van Beukering"
group: "Utilities"
date: "February 2026, May 2026"
since: "1.0"
category: apex
---

# UTIL_SObject

**Class** · Group: `Utilities`

```apex
global inherited sharing class UTIL_SObject
```

SObject runtime operations — filtering, field extraction, list-to-map conversion, and dot-notation field value retrieval.

**Since:** 1.0

**Example:**

```apex
Set<Id> accountIds = UTIL_SObject.extractIds(contacts, Contact.AccountId, true);
Map<Id, List<SObject>> contactsByAccount = UTIL_SObject.groupByKey(contacts, Contact.AccountId);
List<SObject> changed = UTIL_SObject.getChangedRecords(newRecords, oldRecords, Account.Name);
```

---

## Methods

| Method | Description |
|--------|-------------|
| global static [Set](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_set.htm) [extractIds](#extractids)([List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm)> objects) | Extracts a unique set of Ids from a list of SObjects using the Id field. |
| global static [Set](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_set.htm) [extractIds](#extractids)([List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm)> objects, [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) ignoreNulls) | Extracts a unique set of Ids from a list of SObjects using the Id field. |
| global static [Set](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_set.htm) [extractIds](#extractids)([List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm)> objects, [SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm) objectField) | Extracts a unique set of Ids from a list of SObjects using a typed field token. |
| global static [Set](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_set.htm) [extractIds](#extractids)([List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm)> objects, [SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm) objectField, [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) ignoreNulls) | Extracts a unique set of Ids from a list of SObjects using a typed field token with null filtering. |
| global static [Set](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_set.htm) [extractIds](#extractids)([List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm)> objects, [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) fieldName) | Extracts a unique set of Ids from a list of SObjects using a named field. |
| global static [Set](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_set.htm) [extractIds](#extractids)([List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm)> objects, [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) fieldName, [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) ignoreNulls) | Extracts a unique set of Ids from a list of SObjects using a named field with null filtering. |
| global static [Set](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_set.htm) [extractUniqueValues](#extractuniquevalues)([List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm)> objects, [SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm) objectField) | Extracts a unique set of field values as strings from a list of SObjects using a typed field token. |
| global static [Set](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_set.htm) [extractUniqueValues](#extractuniquevalues)([List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm)> objects, [SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm) objectField, [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) ignoreBlankValues) | Extracts a unique set of field values as strings from a list of SObjects using a typed field token with blank filtering. |
| global static [Set](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_set.htm) [extractUniqueValues](#extractuniquevalues)([List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm)> objects, [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) fieldName) | Extracts a unique set of field values as strings from a list of SObjects. |
| global static [Set](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_set.htm) [extractUniqueValues](#extractuniquevalues)([List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm)> objects, [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) fieldName, [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) ignoreBlankValues) | Extracts a unique set of field values as strings from a list of SObjects with blank filtering. |
| global static [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm) [extractValues](#extractvalues)([List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm)> objects, [SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm) objectField) | Extracts field values as strings from a list of SObjects using a typed field token. |
| global static [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm) [extractValues](#extractvalues)([List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm)> objects, [SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm) objectField, [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) ignoreBlankValues) | Extracts field values as strings from a list of SObjects using a typed field token with blank filtering. |
| global static [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm) [extractValues](#extractvalues)([List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm)> objects, [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) fieldName) | Extracts field values as strings from a list of SObjects. |
| global static [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm) [extractValues](#extractvalues)([List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm)> objects, [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) fieldName, [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) ignoreBlankValues) | Extracts field values as strings from a list of SObjects with blank filtering. |
| global static [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm) [findWhere](#findwhere)([List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm)> objects, [Map](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_map.htm)<[String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm), [Object](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_System_Object.htm)> filter) | Filters a list of SObjects by multiple field-value matches. |
| global static [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm) [findWhere](#findwhere)([List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm)> objects, [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) fieldName, [Object](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_System_Object.htm) value) | Filters a list of SObjects by a single field-value match. |
| global static [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm) [findWhereIn](#findwherein)([List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[Object](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_System_Object.htm)> values) | Filters a list of SObjects where a field value is in the provided list. |
| global static [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm) [getChangedRecords](#getchangedrecords)([List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm)> oldRecords, [SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm)> fields) | Returns only the records where any of the specified fields have changed between the old and new versions. |
| global static [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm) [getChangedRecords](#getchangedrecords)([List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm)> oldRecords, [SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm) field) | Returns only the records where a specific field value has changed between the old and new versions. |
| global static [Object](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_System_Object.htm) [getFieldValue](#getfieldvalue)([SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm) anObject, [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) fieldName) | Retrieves the value for a field on an SObject using dot-notation for related objects. |
| global static [Map](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_map.htm) [groupByKey](#groupbykey)([List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm) keyField) | Converts a list of SObjects into a grouped map by an Id field using a typed field token. |
| global static [Map](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_map.htm) [groupByKey](#groupbykey)([List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm) keyFieldName) | Converts a list of SObjects into a grouped map by an Id field. |
| global static [Map](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_map.htm) [groupByStringKey](#groupbystringkey)([List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm) keyField) | Converts a list of SObjects into a grouped map by a String field using a typed field token. |
| global static [Map](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_map.htm) [groupByStringKey](#groupbystringkey)([List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm) keyFieldName) | Converts a list of SObjects into a grouped map by a String field. |
| global static [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) [hasFieldChanged](#hasfieldchanged)([SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm) newRecord, [SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm) oldRecord, [SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm) field) | Checks whether a specific field value has changed between the old and new versions of a record. |
| global static [Map](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_map.htm) [indexById](#indexbyid)([List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm) keyField) | Converts a list of SObjects into a single-value map by an Id field using a typed field token. |
| global static [Map](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_map.htm) [indexById](#indexbyid)([List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm) keyFieldName) | Converts a list of SObjects into a single-value map by an Id field. |
| global static [Map](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_map.htm) [indexByStringKey](#indexbystringkey)([List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm) keyField) | Converts a list of SObjects into a single-value map by a String field using a typed field token. |
| global static [Map](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_map.htm) [indexByStringKey](#indexbystringkey)([List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm) keyFieldName) | Converts a list of SObjects into a single-value map by a String field. |
| global static [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) [matches](#matches)([SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm) obj, [Map](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_map.htm)<[String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm), [Object](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_System_Object.htm)> filterMap) | Checks if an SObject matches the field-value pairs in the provided filter map. |
| global static [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm) [omitWhere](#omitwhere)([List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm)> objects, [Map](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_map.htm)<[String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm), [Object](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_System_Object.htm)> filter) | Removes items from a list where the fields match the filter map. |
| global static [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm) [omitWhere](#omitwhere)([List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm)> objects, [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) fieldName, [Object](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_System_Object.htm) value) | Removes items from a list where the field matches a single value. |
| global static [Id](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_id.htm) [validateId](#validateid)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) stringId) | Will return an Id if the string is a valid Id else null |

---

## Method Details

### extractIds

```apex
global static Set<Id> extractIds(List<SObject> objects)
```

Extracts a unique set of Ids from a list of SObjects using the Id field.

**Parameters:**

- `objects` ([List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)) - The SObjects from which to extract Ids

**Returns:** [Id](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_id.htm) - Extracted Ids, could include a null

**Since:** 1.0

**Example:**

```apex
Set<Id> accountIds = UTIL_SObject.extractIds(accounts);
```

### extractIds

```apex
global static Set<Id> extractIds(List<SObject> objects, Boolean ignoreNulls)
```

Extracts a unique set of Ids from a list of SObjects using the Id field.

**Parameters:**

- `objects` ([List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)) - The SObjects from which to extract Ids
- `ignoreNulls` ([SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm)) - Set to true to exclude null Ids

**Returns:** [Id](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_id.htm) - Extracted Ids

**Since:** 1.0

**Example:**

```apex
Set<Id> accountIds = UTIL_SObject.extractIds(accounts, true);
```

### extractIds

```apex
global static Set<Id> extractIds(List<SObject> objects, SObjectField objectField)
```

Extracts a unique set of Ids from a list of SObjects using a typed field token.

**Parameters:**

- `objects` ([List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)) - The SObjects from which to extract Ids
- `objectField` ([SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm)) - The field token containing the Id

**Returns:** [Id](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_id.htm) - Extracted Ids, could include a null

**Since:** 1.0

**Example:**

```apex
Set<Id> accountIds = UTIL_SObject.extractIds(contacts, Contact.AccountId);
```

### extractIds

```apex
global static Set<Id> extractIds(List<SObject> objects, SObjectField objectField, Boolean ignoreNulls)
```

Extracts a unique set of Ids from a list of SObjects using a typed field token with null filtering.

**Parameters:**

- `objects` ([List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)) - The SObjects from which to extract Ids
- `objectField` ([SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm)) - The field token containing the Id
- `ignoreNulls` ([SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm)) - Set to true to exclude null Ids

**Returns:** [Id](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_id.htm) - Extracted Ids

**Since:** 1.0

**Example:**

```apex
Set<Id> accountIds = UTIL_SObject.extractIds(contacts, Contact.AccountId, true);
```

### extractIds

```apex
global static Set<Id> extractIds(List<SObject> objects, String fieldName)
```

Extracts a unique set of Ids from a list of SObjects using a named field.

**Parameters:**

- `objects` ([List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)) - The SObjects from which to extract Ids
- `fieldName` ([SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm)) - The API name of the field containing the Id (supports dot-notation)

**Returns:** [Id](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_id.htm) - Extracted Ids, could include a null

**Since:** 1.0

**Example:**

```apex
Set<Id> accountIds = UTIL_SObject.extractIds(contacts, 'AccountId');
```

### extractIds

```apex
global static Set<Id> extractIds(List<SObject> objects, String fieldName, Boolean ignoreNulls)
```

Extracts a unique set of Ids from a list of SObjects using a named field with null filtering.

**Parameters:**

- `objects` ([List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)) - The SObjects from which to extract Ids
- `fieldName` ([SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm)) - The API name of the field containing the Id (supports dot-notation)
- `ignoreNulls` ([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)) - Set to true to exclude null Ids

**Returns:** [Id](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_id.htm) - Extracted Ids

**Since:** 1.0

**Example:**

```apex
Set<Id> accountIds = UTIL_SObject.extractIds(contacts, 'AccountId', true);
```

### extractUniqueValues

```apex
global static Set<String> extractUniqueValues(List<SObject> objects, SObjectField objectField)
```

Extracts a unique set of field values as strings from a list of SObjects using a typed field token.

**Parameters:**

- `objects` ([List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)) - The SObjects from which to extract values
- `objectField` ([SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm)) - The field token to extract

**Returns:** [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) - A set of string values (includes blanks)

**Since:** 1.0

**Example:**

```apex
Set<String> industries = UTIL_SObject.extractUniqueValues(accounts, Account.Industry);
```

### extractUniqueValues

```apex
global static Set<String> extractUniqueValues(List<SObject> objects, SObjectField objectField, Boolean ignoreBlankValues)
```

Extracts a unique set of field values as strings from a list of SObjects using a typed field token with blank filtering.

**Parameters:**

- `objects` ([List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)) - The SObjects from which to extract values
- `objectField` ([SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm)) - The field token to extract
- `ignoreBlankValues` ([SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm)) - Set to true to exclude blank values

**Returns:** [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) - A set of string values

**Since:** 1.0

**Example:**

```apex
Set<String> industries = UTIL_SObject.extractUniqueValues(accounts, Account.Industry, true);
```

### extractUniqueValues

```apex
global static Set<String> extractUniqueValues(List<SObject> objects, String fieldName)
```

Extracts a unique set of field values as strings from a list of SObjects.

**Parameters:**

- `objects` ([List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)) - The SObjects from which to extract values
- `fieldName` ([SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm)) - The API name of the field (supports dot-notation)

**Returns:** [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) - A set of string values (includes blanks)

**Since:** 1.0

**Example:**

```apex
Set<String> industries = UTIL_SObject.extractUniqueValues(accounts, 'Industry');
```

### extractUniqueValues

```apex
global static Set<String> extractUniqueValues(List<SObject> objects, String fieldName, Boolean ignoreBlankValues)
```

Extracts a unique set of field values as strings from a list of SObjects with blank filtering.

**Parameters:**

- `objects` ([List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)) - The SObjects from which to extract values
- `fieldName` ([SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm)) - The API name of the field (supports dot-notation)
- `ignoreBlankValues` ([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)) - Set to true to exclude blank values

**Returns:** [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) - A set of string values

**Since:** 1.0

**Example:**

```apex
Set<String> industries = UTIL_SObject.extractUniqueValues(accounts, 'Industry', true);
```

### extractValues

```apex
global static List<String> extractValues(List<SObject> objects, SObjectField objectField)
```

Extracts field values as strings from a list of SObjects using a typed field token.

**Parameters:**

- `objects` ([List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)) - The SObjects from which to extract values
- `objectField` ([SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm)) - The field token to extract

**Returns:** [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) - A list of string values (includes blanks)

**Since:** 1.0

**Example:**

```apex
List<String> names = UTIL_SObject.extractValues(accounts, Account.Name);
```

### extractValues

```apex
global static List<String> extractValues(List<SObject> objects, SObjectField objectField, Boolean ignoreBlankValues)
```

Extracts field values as strings from a list of SObjects using a typed field token with blank filtering.

**Parameters:**

- `objects` ([List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)) - The SObjects from which to extract values
- `objectField` ([SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm)) - The field token to extract
- `ignoreBlankValues` ([SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm)) - Set to true to exclude blank values

**Returns:** [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) - A list of string values

**Since:** 1.0

**Example:**

```apex
List<String> names = UTIL_SObject.extractValues(accounts, Account.Name, true);
```

### extractValues

```apex
global static List<String> extractValues(List<SObject> objects, String fieldName)
```

Extracts field values as strings from a list of SObjects.

**Parameters:**

- `objects` ([List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)) - The SObjects from which to extract values
- `fieldName` ([SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm)) - The API name of the field (supports dot-notation)

**Returns:** [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) - A list of string values (includes blanks)

**Since:** 1.0

**Example:**

```apex
List<String> names = UTIL_SObject.extractValues(accounts, 'Name');
```

### extractValues

```apex
global static List<String> extractValues(List<SObject> objects, String fieldName, Boolean ignoreBlankValues)
```

Extracts field values as strings from a list of SObjects with blank filtering.

**Parameters:**

- `objects` ([List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)) - The SObjects from which to extract values
- `fieldName` ([SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm)) - The API name of the field (supports dot-notation)
- `ignoreBlankValues` ([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)) - Set to true to exclude blank values

**Returns:** [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) - A list of string values

**Since:** 1.0

**Example:**

```apex
List<String> names = UTIL_SObject.extractValues(accounts, 'Name', true);
```

### findWhere

```apex
global static List<SObject> findWhere(List<SObject> objects, Map<String, Object> filter)
```

Filters a list of SObjects by multiple field-value matches.

**Parameters:**

- `objects` ([List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)) - The SObjects to filter
- `filter` ([SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm)) - A map of field API names and their expected values

**Returns:** [SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm) - Matching SObjects

**Since:** 1.0

**Example:**

```apex
Map<String, Object> filter = new Map<String, Object>{ 'Industry' => 'Technology', 'Active__c' => true };
List<SObject> matches = UTIL_SObject.findWhere(accounts, filter);
```

### findWhere

```apex
global static List<SObject> findWhere(List<SObject> objects, String fieldName, Object value)
```

Filters a list of SObjects by a single field-value match.

**Parameters:**

- `objects` ([List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)) - The SObjects to filter
- `fieldName` ([SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm)) - The field API name to match
- `value` ([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)) - The value to match against

**Returns:** [SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm) - Matching SObjects

**Since:** 1.0

**Example:**

```apex
List<SObject> techAccounts = UTIL_SObject.findWhere(accounts, 'Industry', 'Technology');
```

### findWhereIn

```apex
global static List<SObject> findWhereIn(List<SObject> objects, String fieldName, List<Object> values)
```

Filters a list of SObjects where a field value is in the provided list.

**Parameters:**

- `objects` ([List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)) - The SObjects to filter
- `fieldName` ([SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm)) - The field API name to match
- `values` ([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)) - The values to match against

**Returns:** [SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm) - Matching SObjects

**Since:** 1.0

**Example:**

```apex
List<Object> targetIndustries = new List<Object>{ 'Technology', 'Finance' };
List<SObject> filtered = UTIL_SObject.findWhereIn(accounts, 'Industry', targetIndustries);
```

### getChangedRecords

```apex
global static List<SObject> getChangedRecords(List<SObject> newRecords, List<SObject> oldRecords, Set<SObjectField> fields)
```

Returns only the records where any of the specified fields have changed between the old and new
versions. Compares each record in the new list against the corresponding record in the old list by index.

**Parameters:**

- `newRecords` ([List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)) - The new versions of the records (from Trigger.new).
- `oldRecords` ([SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm)) - The old versions of the records (from Trigger.old).
- `fields` ([List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)) - The set of fields to check for changes. A record is included if any field changed.

**Returns:** [SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm) - A list containing only the new records where at least one of the specified fields changed.

**Since:** 1.0

**Example:**

```apex
List<SObject> addressChanged = UTIL_SObject.getChangedRecords
(
    newRecords, oldRecords,
    new Set<SObjectField>{ Foobar__c.Text__c, Foobar__c.Email__c }
);
```

### getChangedRecords

```apex
global static List<SObject> getChangedRecords(List<SObject> newRecords, List<SObject> oldRecords, SObjectField field)
```

Returns only the records where a specific field value has changed between the old and new
versions. Compares each record in the new list against the corresponding record in the old list by index.

**Parameters:**

- `newRecords` ([List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)) - The new versions of the records (from Trigger.new).
- `oldRecords` ([SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm)) - The old versions of the records (from Trigger.old).
- `field` ([List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)) - The field to check for changes.

**Returns:** [SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm) - A list containing only the new records where the specified field value changed.

**Since:** 1.0

**Example:**

```apex
List<SObject> statusChanged = UTIL_SObject.getChangedRecords(newRecords, oldRecords, Foobar__c.Status__c);
```

### getFieldValue

```apex
global static Object getFieldValue(SObject anObject, String fieldName)
```

Retrieves the value for a field on an SObject using dot-notation for related objects.

**Parameters:**

- `anObject` ([SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm)) - The SObject (can include related object data)
- `fieldName` ([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)) - A single field name or dot-notation path (e.g. 'Contact.Name')

**Returns:** [Object](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_System_Object.htm) - The value of the field

**Since:** 1.0

**Example:**

```apex
Object name = UTIL_SObject.getFieldValue(account, 'Name');
Object contactName = UTIL_SObject.getFieldValue(myCase, 'Contact.Name');
```

### groupByKey

```apex
global static Map<Id, List<SObject>> groupByKey(List<SObject> objectList, SObjectField keyField)
```

Converts a list of SObjects into a grouped map by an Id field using a typed field token.

**Parameters:**

- `objectList` ([List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)) - The SObjects to group
- `keyField` ([SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm)) - The field token for the key

**Returns:** [SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm) - A map of Id to list of SObjects

**Since:** 1.0

**Example:**

```apex
Map<Id, List<SObject>> contactsByAccount = UTIL_SObject.groupByKey(contacts, Contact.AccountId);
```

### groupByKey

```apex
global static Map<Id, List<SObject>> groupByKey(List<SObject> objectList, String keyFieldName)
```

Converts a list of SObjects into a grouped map by an Id field.

**Parameters:**

- `objectList` ([List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)) - The SObjects to group
- `keyFieldName` ([SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm)) - The API name of the Id field (supports dot-notation)

**Returns:** [SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm) - A map of Id to list of SObjects

**Since:** 1.0

**Example:**

```apex
Map<Id, List<SObject>> contactsByAccount = UTIL_SObject.groupByKey(contacts, 'AccountId');
```

### groupByStringKey

```apex
global static Map<String, List<SObject>> groupByStringKey(List<SObject> objectList, SObjectField keyField)
```

Converts a list of SObjects into a grouped map by a String field using a typed field token.

**Parameters:**

- `objectList` ([List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)) - The SObjects to group
- `keyField` ([SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm)) - The field token for the key

**Returns:** [SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm) - A map of String to list of SObjects

**Since:** 1.0

**Example:**

```apex
Map<String, List<SObject>> accountsByIndustry = UTIL_SObject.groupByStringKey(accounts, Account.Industry);
```

### groupByStringKey

```apex
global static Map<String, List<SObject>> groupByStringKey(List<SObject> objectList, String keyFieldName)
```

Converts a list of SObjects into a grouped map by a String field.

**Parameters:**

- `objectList` ([List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)) - The SObjects to group
- `keyFieldName` ([SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm)) - The API name of the String field (supports dot-notation)

**Returns:** [SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm) - A map of String to list of SObjects

**Since:** 1.0

**Example:**

```apex
Map<String, List<SObject>> accountsByIndustry = UTIL_SObject.groupByStringKey(accounts, 'Industry');
```

### hasFieldChanged

```apex
global static Boolean hasFieldChanged(SObject newRecord, SObject oldRecord, SObjectField field)
```

Checks whether a specific field value has changed between the old and new versions of a record.

**Parameters:**

- `newRecord` ([SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm)) - The new version of the record (from Trigger.new).
- `oldRecord` ([SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm)) - The old version of the record (from Trigger.oldMap).
- `field` ([SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm)) - The field to check for changes.

**Returns:** [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) - True if the field value differs between the old and new records.

**Since:** 1.0

**Example:**

```apex
if(UTIL_SObject.hasFieldChanged(newRecord, oldRecord, Foobar__c.Status__c))
{
    // Handle status change
}
```

### indexById

```apex
global static Map<Id, SObject> indexById(List<SObject> objectList, SObjectField keyField)
```

Converts a list of SObjects into a single-value map by an Id field using a typed field token.

**Parameters:**

- `objectList` ([List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)) - The SObjects to map
- `keyField` ([SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm)) - The field token for the key

**Returns:** [SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm) - A map of Id to SObject

**Since:** 1.0

**Example:**

```apex
Map<Id, SObject> accountById = UTIL_SObject.indexById(accounts, Account.Id);
```

### indexById

```apex
global static Map<Id, SObject> indexById(List<SObject> objectList, String keyFieldName)
```

Converts a list of SObjects into a single-value map by an Id field.

**Parameters:**

- `objectList` ([List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)) - The SObjects to map
- `keyFieldName` ([SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm)) - The API name of the Id field (supports dot-notation)

**Returns:** [SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm) - A map of Id to SObject

**Since:** 1.0

**Example:**

```apex
Map<Id, SObject> accountById = UTIL_SObject.indexById(accounts, 'Id');
```

### indexByStringKey

```apex
global static Map<String, SObject> indexByStringKey(List<SObject> objectList, SObjectField keyField)
```

Converts a list of SObjects into a single-value map by a String field using a typed field token.

**Parameters:**

- `objectList` ([List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)) - The SObjects to map
- `keyField` ([SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm)) - The field token for the key

**Returns:** [SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm) - A map of String to SObject

**Since:** 1.0

**Example:**

```apex
Map<String, SObject> accountByName = UTIL_SObject.indexByStringKey(accounts, Account.Name);
```

### indexByStringKey

```apex
global static Map<String, SObject> indexByStringKey(List<SObject> objectList, String keyFieldName)
```

Converts a list of SObjects into a single-value map by a String field.

**Parameters:**

- `objectList` ([List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)) - The SObjects to map
- `keyFieldName` ([SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm)) - The API name of the String field (supports dot-notation)

**Returns:** [SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm) - A map of String to SObject

**Since:** 1.0

**Example:**

```apex
Map<String, SObject> accountByName = UTIL_SObject.indexByStringKey(accounts, 'Name');
```

### matches

```apex
global static Boolean matches(SObject obj, Map<String, Object> filterMap)
```

Checks if an SObject matches the field-value pairs in the provided filter map.

**Parameters:**

- `obj` ([SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm)) - The SObject to check.
- `filterMap` ([Map](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_map.htm)) - A map containing field API names and their expected values.

**Returns:** [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) - True if all fields in the filter map match the corresponding SObject fields.

**Since:** 1.0

**Example:**

```apex
SObject account = new Account(Name = 'Test Account', Industry = 'Technology');
Map<String, Object> filterMap = new Map<String, Object>{'Name' => 'Test Account', 'Industry' => 'Technology'};
Boolean doesMatch = UTIL_SObject.matches(account, filterMap); // True
```

### omitWhere

```apex
global static List<SObject> omitWhere(List<SObject> objects, Map<String, Object> filter)
```

Removes items from a list where the fields match the filter map.

**Parameters:**

- `objects` ([List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)) - The SObjects to filter
- `filter` ([SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm)) - A map of fields and values that cause exclusion

**Returns:** [SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm) - SObjects not matching the exclusion criteria

**Since:** 1.0

**Example:**

```apex
Map<String, Object> filter = new Map<String, Object>{ 'Status' => 'Closed', 'IsDeleted' => true };
List<SObject> activeRecords = UTIL_SObject.omitWhere(allRecords, filter);
```

### omitWhere

```apex
global static List<SObject> omitWhere(List<SObject> objects, String fieldName, Object value)
```

Removes items from a list where the field matches a single value.

**Parameters:**

- `objects` ([List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)) - The SObjects to filter
- `fieldName` ([SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm)) - The field API name to match for exclusion
- `value` ([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)) - The value that causes exclusion

**Returns:** [SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm) - SObjects not matching the exclusion criteria

**Since:** 1.0

**Example:**

```apex
List<SObject> nonTech = UTIL_SObject.omitWhere(accounts, 'Industry', 'Technology');
```

### validateId

```apex
global static Id validateId(String stringId)
```

Will return an Id if the string is a valid Id else null

**Parameters:**

- `stringId` ([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)) - A string containing the ID

**Returns:** [Id](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_id.htm) - Either a valid ID or null

**Since:** 1.0

**Example:**

```apex
Id result = UTIL_SObject.validateId('001000000000001');
```

