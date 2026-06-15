---
title: "UTIL_SObjectDescribe"
type: class
description: "A semi-intelligent wrapper for standard Apex Schema methods, providing internal caching to avoid hitting describe limits and helper methods for handling relationship field names and namespaces."
author: "Jason Van Beukering"
group: "Utilities"
date: "February 2026, June 2026"
since: "1.0"
category: apex
---

# UTIL_SObjectDescribe

**Class** · Group: `Utilities`

```apex
global inherited sharing class UTIL_SObjectDescribe
```

A semi-intelligent wrapper for standard Apex Schema methods, providing internal caching to avoid hitting describe limits and helper methods for handling relationship field names and namespaces.

**Since:** 1.0

**Example:**

```apex
UTIL_SObjectDescribe describe = UTIL_SObjectDescribe.getDescribe(Account.SObjectType);
SObjectField nameField = describe.getNameField();
String fieldName = UTIL_SObjectDescribe.getCachedFieldName(Account.Industry);
```

---

## Methods

| Method | Description |
|--------|-------------|
| global static [Set](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_set.htm) [extractValidObjectFieldNames](#extractvalidobjectfieldnames)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) objectName, [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)> fieldNames) | Filters a set of field names, returning only those that are valid for the given object. |
| global static void [flushCache](#flushcache)() | Clears the cache of global describe and SObject describe instances to free heap space. |
| global static [Set](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_set.htm) [getAllFieldNames](#getallfieldnames)([SObjectType](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectType.htm) objectType) | Returns all queryable field names for an object by SObjectType (includes record type fields). |
| global static [Set](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_set.htm) [getAllFieldNames](#getallfieldnames)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) objectName) | Returns all queryable field names for an object by API name (includes record type fields). |
| global static [Set](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_set.htm) [getAllFieldNames](#getallfieldnames)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) objectName, [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) includeRecordType) | Returns all queryable field names for an object, optionally including record type fields. |
| global static [DescribeFieldResult](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_fields_describe.htm) [getCachedFieldDescribe](#getcachedfielddescribe)([SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm) field) | Static accessor for field describes that enables context-agnostic lookups. |
| global static [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [getCachedFieldName](#getcachedfieldname)([SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm) field) | Static convenience method to get a field's API name directly from an SObjectField token. |
| global static [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [getDefaultPicklistValue](#getdefaultpicklistvalue)([DescribeFieldResult](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_fields_describe.htm) fieldDescribe) | Retrieves the default picklist value for a given field describe. |
| global static [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [getDefaultPicklistValue](#getdefaultpicklistvalue)([DescribeFieldResult](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_fields_describe.htm) fieldDescribe, [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) returnFirstEntryIfNoDefault) | Retrieves the default picklist value for a given field describe. |
| global static [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [getDefaultPicklistValue](#getdefaultpicklistvalue)([SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm) objectField) | Retrieves the default picklist value for a given SObject field. |
| global static [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [getDefaultPicklistValue](#getdefaultpicklistvalue)([SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm) objectField, [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) returnFirstEntryIfNoDefault) | Retrieves the default picklist value for a given SObject field. |
| global static [Id](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_id.htm) [getDefaultRecordType](#getdefaultrecordtype)([SObjectType](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectType.htm) objectType) | Retrieves the Id of the default record type for an SObject. |
| global [DescribeSObjectResult](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject_describe.htm) [getDescribe](#getdescribe)() | Retrieves the raw DescribeSObjectResult for the described object. |
| global static [UTIL_SObjectDescribe](UTIL_SObjectDescribe.md) [getDescribe](#getdescribe)([DescribeSObjectResult](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject_describe.htm) describeResult) | Retrieves a cached UTIL_SObjectDescribe instance for the specified DescribeSObjectResult. |
| global static [UTIL_SObjectDescribe](UTIL_SObjectDescribe.md) [getDescribe](#getdescribe)([SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm) instance) | Retrieves a cached UTIL_SObjectDescribe instance for the specified SObject instance. |
| global static [UTIL_SObjectDescribe](UTIL_SObjectDescribe.md) [getDescribe](#getdescribe)([SObjectType](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectType.htm) objectType) | Retrieves a cached UTIL_SObjectDescribe instance for the specified SObject type. |
| global static [UTIL_SObjectDescribe](UTIL_SObjectDescribe.md) [getDescribe](#getdescribe)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) sObjectName) | Retrieves a cached UTIL_SObjectDescribe instance for the specified SObject name. |
| global [SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm) [getField](#getfield)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) name) | Retrieves an SObjectField by name, with namespace handling enabled by default. |
| global [SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm) [getField](#getfield)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) fieldName, [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) implyNamespace) | Retrieves an SObjectField by name, handling relationship notation (e.g., 'Account' vs. |
| global [DescribeFieldResult](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_fields_describe.htm) [getFieldDescribe](#getfielddescribe)([SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm) field) | Retrieves a cached DescribeFieldResult for the given SObjectField token. |
| global [DescribeFieldResult](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_fields_describe.htm) [getFieldDescribe](#getfielddescribe)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) fieldName) | Retrieves a cached DescribeFieldResult for the given field name. |
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [getFieldName](#getfieldname)([SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm) field) | Retrieves the API name for the given SObjectField token. |
| global [UTIL_SObjectDescribe.FieldsMap](UTIL_SObjectDescribe.FieldsMap.md) [getFields](#getfields)() | Retrieves a wrapped map of fields with namespace handling for the described object. |
| global [Map](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_map.htm) [getFieldSetsMap](#getfieldsetsmap)() | Retrieves a map of field set names to FieldSet objects for the described object. |
| global [Map](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_map.htm) [getFieldsMap](#getfieldsmap)() | Retrieves a map of field API names to SObjectField instances. |
| global static [UTIL_SObjectDescribe.GlobalDescribeMap](UTIL_SObjectDescribe.GlobalDescribeMap.md) [getGlobalDescribe](#getglobaldescribe)() | Retrieves a wrapped map of global SObjectType names to SObjectType instances with namespace handling. |
| global [SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm) [getNameField](#getnamefield)() | Retrieves the name field of the SObject (where isNameField() is true). |
| global static [Set](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_set.htm) [getNestableFieldNames](#getnestablefieldnames)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) objectName) | Walks the object tree and returns all fields for related objects (one level deep). |
| global static [Set](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_set.htm) [getNestableFieldNames](#getnestablefieldnames)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) objectName, [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) levels) | Walks the object tree and returns all fields for related objects up to the specified depth. |
| global static [Map](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_map.htm) [getObjectFieldMap](#getobjectfieldmap)([SObjectType](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectType.htm) objectType) | Returns the field map for an object by SObjectType. |
| global static [Map](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_map.htm) [getObjectFieldMap](#getobjectfieldmap)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) objectName) | Returns the field map for an object by API name. |
| global static [Map](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_map.htm) [getObjectFieldReferenceMap](#getobjectfieldreferencemap)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) objectName) | Returns a map of reference (lookup/master-detail) fields keyed by relationship name. |
| global static [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [getObjectNameFromId](#getobjectnamefromid)([Id](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_id.htm) objectId) | Returns the API name of an object based on its ID. |
| global static [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [getObjectNameFromType](#getobjectnamefromtype)([SObjectType](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectType.htm) objectType) | Will get the API name for the SObject given a specific type. |
| global static [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm) [getPicklistEntries](#getpicklistentries)([SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm) pickField) | Returns a list of picklist entries for a given SObject field reference. |
| global static [Map](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_map.htm) [getPicklistEntriesMap](#getpicklistentriesmap)([SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm) pickField) | Returns a map of picklist label-to-value pairs for a given SObject field reference. |
| global static [Map](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_map.htm) [getPicklistEntriesMap](#getpicklistentriesmap)([SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm) pickField, [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) useLabelAsKey) | Returns a map of picklist entries with configurable key for a given SObject field reference. |
| global static [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm) [getPicklistValues](#getpicklistvalues)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) objectApiName, [Id](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_id.htm) recordTypeId) | Returns all picklist values for a given object and record type combination as a list of DTO_PickList objects, including dependent picklist relationships. |
| global static ConnectApi.PicklistValuesCollection [getPicklistValuesByRecordType](#getpicklistvaluesbyrecordtype)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) objectApiName, [Id](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_id.htm) recordTypeId) | Returns all picklist values for a given object and record type combination, including dependent picklist relationships. |
| global static [Map](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_map.htm) [getRawGlobalDescribe](#getrawglobaldescribe)() | Retrieves a cached map of global SObjectType names to SObjectType instances. |
| global static [Id](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_id.htm) [getRecordTypeByDeveloperName](#getrecordtypebydevelopername)([SObjectType](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectType.htm) objectType, [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) recordTypeName) | Retrieves the Id of a record type for an SObject by its developer name. |
| global static [Set](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_set.htm) [getSObjectFieldNames](#getsobjectfieldnames)([Set](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_set.htm)<[SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm)> objectFields) | Converts a set of SObjectField tokens to their API name strings. |
| global [SObjectType](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectType.htm) [getSObjectType](#getsobjecttype)() | Returns the SObjectType this instance is based on, useful for retrieving metadata about the specific object. |
| global static [SObjectType](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectType.htm) [getSObjectTypeById](#getsobjecttypebyid)([Id](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_id.htm) objectId) | Returns the SObjectType token for a given record ID. |
| global static [SObjectType](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectType.htm) [getSObjectTypeByName](#getsobjecttypebyname)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) objectApiName) | Returns the SObjectType token for a given object API name. |
| global static [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) [isPersonAccountEnabled](#ispersonaccountenabled)() | Determines whether Person Accounts are enabled by checking for the isPersonAccount field on Account. |
| global static [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) [isRecordTypeAvailable](#isrecordtypeavailable)([SObjectType](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectType.htm) objectType, [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) recordTypeName) | Reports whether a record type, identified by its developer name, is available to the running user for the given SObject. |

## Inner Classes

| Class | Description |
|-------|-------------|
| [FieldListBuilder](UTIL_SObjectDescribe.FieldListBuilder.md) | Builds a comma-separated field list from SObjectField tokens and optional FieldSet definitions. |
| [FieldsMap](UTIL_SObjectDescribe.FieldsMap.md) | A subclass of NamespacedAttributeMap for handling field maps returned by DescribeSObjectResult.fields.getMap(). |
| [GlobalDescribeMap](UTIL_SObjectDescribe.GlobalDescribeMap.md) | A subclass of NamespacedAttributeMap for handling global describe data returned by getGlobalDescribe. |

---

## Method Details

### extractValidObjectFieldNames

```apex
global static Set<String> extractValidObjectFieldNames(String objectName, Set<String> fieldNames)
```

Filters a set of field names, returning only those that are valid for the given object.

**Parameters:**

- `objectName` ([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)) - The API name of the object
- `fieldNames` ([Set](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_set.htm)) - The field names to check

**Returns:** [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) - A set containing only the valid field names

**Since:** 1.0

**Example:**

```apex
Set<String> fields = new Set<String>{ 'Name', 'InvalidField__c', 'Industry' };
Set<String> validFields = UTIL_SObjectDescribe.extractValidObjectFieldNames('Account', fields);
```

### flushCache

```apex
global static void flushCache()
```

Clears the cache of global describe and SObject describe instances to free heap space.

**Since:** 1.0

**Example:**

```apex
UTIL_SObjectDescribe.flushCache();
System.debug(UTIL_SObjectDescribe.getDescribe('Account')); // Forces new describe instance
```

### getAllFieldNames

```apex
global static Set<String> getAllFieldNames(SObjectType objectType)
```

Returns all queryable field names for an object by SObjectType (includes record type fields).

**Parameters:**

- `objectType` ([SObjectType](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectType.htm)) - The SObjectType

**Returns:** [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) - A set of field names for the object

**Since:** 1.0

**Example:**

```apex
Set<String> fieldNames = UTIL_SObjectDescribe.getAllFieldNames(Account.SObjectType);
```

### getAllFieldNames

```apex
global static Set<String> getAllFieldNames(String objectName)
```

Returns all queryable field names for an object by API name (includes record type fields).

**Parameters:**

- `objectName` ([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)) - The API name of the object

**Returns:** [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) - A set of field names for the object

**Since:** 1.0

**Example:**

```apex
Set<String> fieldNames = UTIL_SObjectDescribe.getAllFieldNames('Account');
```

### getAllFieldNames

```apex
global static Set<String> getAllFieldNames(String objectName, Boolean includeRecordType)
```

Returns all queryable field names for an object, optionally including record type fields.

**Parameters:**

- `objectName` ([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)) - The API name of the object
- `includeRecordType` ([Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm)) - Whether to include RecordType relationship fields

**Returns:** [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) - A set of field names for the object

**Since:** 1.0

**Example:**

```apex
Set<String> fieldNames = UTIL_SObjectDescribe.getAllFieldNames('Account', false);
```

### getCachedFieldDescribe

```apex
global static DescribeFieldResult getCachedFieldDescribe(SObjectField field)
```

Static accessor for field describes that enables context-agnostic lookups.
This method allows classes like QRY_Generator and QRY_Builder to resolve field names
without needing to know the parent SObjectType.

**Parameters:**

- `field` ([SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm)) - The SObjectField token to describe.

**Returns:** [DescribeFieldResult](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_fields_describe.htm) - The cached `DescribeFieldResult` for the field, or null if the field is null.

**Since:** 1.0

**Example:**

```apex
String fieldName = UTIL_SObjectDescribe.getCachedFieldDescribe(Account.Name)?.getName();
System.debug(fieldName); // Outputs: Name
```

### getCachedFieldName

```apex
global static String getCachedFieldName(SObjectField field)
```

Static convenience method to get a field's API name directly from an SObjectField token.
Uses the global field describe cache for efficiency. This is the preferred method when you only
need the field name and don't require the full DescribeFieldResult.

**Parameters:**

- `field` ([SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm)) - The SObjectField token to get the name for.

**Returns:** [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) - The field's API name, or null if the field is null.

**Since:** 1.0

**Example:**

```apex
String fieldName = UTIL_SObjectDescribe.getCachedFieldName(Account.Name);
System.debug(fieldName); // Outputs: Name
```

### getDefaultPicklistValue

```apex
global static String getDefaultPicklistValue(DescribeFieldResult fieldDescribe)
```

Retrieves the default picklist value for a given field describe.

**Parameters:**

- `fieldDescribe` ([DescribeFieldResult](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_fields_describe.htm)) - The DescribeFieldResult to retrieve a picklist value for.

**Returns:** [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) - The default picklist value, or null if no default is available.

**Since:** 1.0

**Example:**

```apex
String picklistValue = UTIL_SObjectDescribe.getDefaultPicklistValue(Foobar__c.Picklist__c.getDescribe());
```

### getDefaultPicklistValue

```apex
global static String getDefaultPicklistValue(DescribeFieldResult fieldDescribe, Boolean returnFirstEntryIfNoDefault)
```

Retrieves the default picklist value for a given field describe.

**Parameters:**

- `fieldDescribe` ([DescribeFieldResult](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_fields_describe.htm)) - The DescribeFieldResult to retrieve a picklist value for.
- `returnFirstEntryIfNoDefault` ([Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm)) - If no default is found, return the first entry if available.

**Returns:** [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) - The default picklist value, or null if no default (or first entry) is available.

**Since:** 1.0

**Example:**

```apex
String picklistValue = UTIL_SObjectDescribe.getDefaultPicklistValue(Foobar__c.Picklist__c.getDescribe(), true);
```

### getDefaultPicklistValue

```apex
global static String getDefaultPicklistValue(SObjectField objectField)
```

Retrieves the default picklist value for a given SObject field.

**Parameters:**

- `objectField` ([SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm)) - The SObject field to retrieve a picklist value for.

**Returns:** [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) - The default picklist value, or null if no default is available.

**Since:** 1.0

**Example:**

```apex
String picklistValue = UTIL_SObjectDescribe.getDefaultPicklistValue(Foobar__c.Picklist__c);
```

### getDefaultPicklistValue

```apex
global static String getDefaultPicklistValue(SObjectField objectField, Boolean returnFirstEntryIfNoDefault)
```

Retrieves the default picklist value for a given SObject field.

**Parameters:**

- `objectField` ([SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm)) - The SObject field to retrieve a picklist value for.
- `returnFirstEntryIfNoDefault` ([Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm)) - If no default is found, return the first entry if available.

**Returns:** [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) - The default picklist value, or null if no default (or first entry) is available.

**Since:** 1.0

**Example:**

```apex
String picklistValue = UTIL_SObjectDescribe.getDefaultPicklistValue(Foobar__c.Picklist__c, true);
```

### getDefaultRecordType

```apex
global static Id getDefaultRecordType(SObjectType objectType)
```

Retrieves the Id of the default record type for an SObject.

**Parameters:**

- `objectType` ([SObjectType](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectType.htm)) - The SObject type.

**Returns:** [Id](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_id.htm) - The Id of the default record type, or null if not found.

**Since:** 1.0

**Example:**

```apex
Id recordTypeId = UTIL_SObjectDescribe.getDefaultRecordType(Account.SObjectType);
```

### getDescribe

```apex
global DescribeSObjectResult getDescribe()
```

Retrieves the raw `DescribeSObjectResult` for the described object.

**Returns:** [DescribeSObjectResult](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject_describe.htm) - The `DescribeSObjectResult` containing detailed metadata for the object.

**Since:** 1.0

**Example:**

```apex
UTIL_SObjectDescribe describe = UTIL_SObjectDescribe.getDescribe('Account');
DescribeSObjectResult result = describe.getDescribe();
System.debug(result.getLabel()); // Outputs: Account
```

### getDescribe

```apex
global static UTIL_SObjectDescribe getDescribe(DescribeSObjectResult describeResult)
```

Retrieves a cached `UTIL_SObjectDescribe` instance for the specified `DescribeSObjectResult`.

**Parameters:**

- `describeResult` ([DescribeSObjectResult](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject_describe.htm)) - The DescribeSObjectResult for the SObject.

**Returns:** [UTIL_SObjectDescribe](UTIL_SObjectDescribe.md) - A `UTIL_SObjectDescribe` instance, or null if the describe result is null.

**Since:** 1.0

**Example:**

```apex
DescribeSObjectResult result = Account.SObjectType.getDescribe();
UTIL_SObjectDescribe describe = UTIL_SObjectDescribe.getDescribe(result);
System.debug(describe.getSObjectType()); // Outputs: Account
```

### getDescribe

```apex
global static UTIL_SObjectDescribe getDescribe(SObject instance)
```

Retrieves a cached `UTIL_SObjectDescribe` instance for the specified SObject instance.

**Parameters:**

- `instance` ([SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm)) - The SObject instance.

**Returns:** [UTIL_SObjectDescribe](UTIL_SObjectDescribe.md) - A `UTIL_SObjectDescribe` instance, or null if the instance is null.

**Since:** 1.0

**Example:**

```apex
Account acc = new Account();
UTIL_SObjectDescribe describe = UTIL_SObjectDescribe.getDescribe(acc);
System.debug(describe.getNameField().getDescribe().name); // Outputs: Name
```

### getDescribe

```apex
global static UTIL_SObjectDescribe getDescribe(SObjectType objectType)
```

Retrieves a cached `UTIL_SObjectDescribe` instance for the specified SObject type.

**Parameters:**

- `objectType` ([SObjectType](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectType.htm)) - The SObject type.

**Returns:** [UTIL_SObjectDescribe](UTIL_SObjectDescribe.md) - A `UTIL_SObjectDescribe` instance, or null if the object type is null.

**Since:** 1.0

**Example:**

```apex
UTIL_SObjectDescribe describe = UTIL_SObjectDescribe.getDescribe(Account.SObjectType);
System.debug(describe.getDescribe().name); // Outputs: Account
```

### getDescribe

```apex
global static UTIL_SObjectDescribe getDescribe(String sObjectName)
```

Retrieves a cached `UTIL_SObjectDescribe` instance for the specified SObject name.

**Parameters:**

- `sObjectName` ([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)) - The API name of the SObject.

**Returns:** [UTIL_SObjectDescribe](UTIL_SObjectDescribe.md) - A `UTIL_SObjectDescribe` instance, or null if the SObject name is invalid.

**Since:** 1.0

**Example:**

```apex
UTIL_SObjectDescribe describe = UTIL_SObjectDescribe.getDescribe('Account');
System.debug(describe.getSObjectType()); // Outputs: Account
```

### getField

```apex
global SObjectField getField(String name)
```

Retrieves an `SObjectField` by name, with namespace handling enabled by default.

**Parameters:**

- `name` ([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)) - The API name of the field to retrieve.

**Returns:** [SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm) - The `SObjectField` corresponding to the provided name, or null if not found.

**Since:** 1.0

**Example:**

```apex
UTIL_SObjectDescribe describe = UTIL_SObjectDescribe.getDescribe('Contact');
SObjectField field = describe.getField('LastName');
System.debug(field.getDescribe().getLabel()); // Outputs: Last Name
```

### getField

```apex
global SObjectField getField(String fieldName, Boolean implyNamespace)
```

Retrieves an `SObjectField` by name, handling relationship notation (e.g., 'Account' vs. 'AccountId') and optional namespace prefixing.

**Parameters:**

- `fieldName` ([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)) - The API name of the field to retrieve.
- `implyNamespace` ([Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm)) - Whether to automatically handle namespace prefixes.

**Returns:** [SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm) - The `SObjectField` corresponding to the provided name, or null if not found.

**Since:** 1.0

**Example:**

```apex
UTIL_SObjectDescribe describe = UTIL_SObjectDescribe.getDescribe('Contact');
SObjectField field = describe.getField('Account', false);
System.debug(field?.getDescribe().name); // Outputs: AccountId
```

### getFieldDescribe

```apex
global DescribeFieldResult getFieldDescribe(SObjectField field)
```

Retrieves a cached `DescribeFieldResult` for the given `SObjectField` token.
This overload accepts an `SObjectField` directly, providing type safety and avoiding string lookups.
Delegates to the static `getCachedFieldDescribe` method to ensure both instance-based and
static-based lookups share the same global cache.

**Parameters:**

- `field` ([SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm)) - The SObjectField token to describe.

**Returns:** [DescribeFieldResult](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_fields_describe.htm) - The `DescribeFieldResult` for the field, or null if the field is null.

**Since:** 1.0

**Example:**

```apex
UTIL_SObjectDescribe describe = UTIL_SObjectDescribe.getDescribe('Account');
DescribeFieldResult fieldDescribe = describe.getFieldDescribe(Account.Name);
System.debug(fieldDescribe.getLabel()); // Outputs: Account Name
```

### getFieldDescribe

```apex
global DescribeFieldResult getFieldDescribe(String fieldName)
```

Retrieves a cached `DescribeFieldResult` for the given field name.
This method provides significant performance benefits when repeatedly accessing field metadata,
as it caches the describe result after the first call.

**Parameters:**

- `fieldName` ([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)) - The API name of the field to describe.

**Returns:** [DescribeFieldResult](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_fields_describe.htm) - The `DescribeFieldResult` for the field, or null if the field doesn't exist.

**Since:** 1.0

**Example:**

```apex
UTIL_SObjectDescribe describe = UTIL_SObjectDescribe.getDescribe('Account');
DescribeFieldResult fieldDescribe = describe.getFieldDescribe('Name');
System.debug(fieldDescribe.getLabel()); // Outputs: Account Name
```

### getFieldName

```apex
global String getFieldName(SObjectField field)
```

Retrieves the API name for the given `SObjectField` token.
Delegates to the static `getCachedFieldName` method to ensure both instance-based and
static-based lookups share the same global cache.

**Parameters:**

- `field` ([SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm)) - The SObjectField token to get the name for.

**Returns:** [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) - The field's API name, or null if the field is null.

**Since:** 1.0

**Example:**

```apex
UTIL_SObjectDescribe describe = UTIL_SObjectDescribe.getDescribe('Account');
String fieldName = describe.getFieldName(Account.Name);
System.debug(fieldName); // Outputs: Name
```

### getFields

```apex
global UTIL_SObjectDescribe.FieldsMap getFields()
```

Retrieves a wrapped map of fields with namespace handling for the described object.

**Returns:** [UTIL_SObjectDescribe.FieldsMap](UTIL_SObjectDescribe.FieldsMap.md) - A `FieldsMap` containing the fields of the described object.

**Since:** 1.0

**Example:**

```apex
UTIL_SObjectDescribe describe = UTIL_SObjectDescribe.getDescribe('Account');
UTIL_SObjectDescribe.FieldsMap fields = describe.getFields();
System.debug(fields.get('Name')?.getDescribe().getLabel()); // Outputs: Name
```

### getFieldSetsMap

```apex
global Map<String, FieldSet> getFieldSetsMap()
```

Retrieves a map of field set names to `FieldSet` objects for the described object.

**Returns:** [FieldSet](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_fieldsets_describe.htm) - A map of field set names to `FieldSet` objects.

**Since:** 1.0

**Example:**

```apex
UTIL_SObjectDescribe describe = UTIL_SObjectDescribe.getDescribe('Account');
Map<String, FieldSet> fieldSets = describe.getFieldSetsMap();
System.debug(fieldSets.keySet()); // Outputs: Set of field set names
```

### getFieldsMap

```apex
global Map<String, SObjectField> getFieldsMap()
```

Retrieves a map of field API names to `SObjectField` instances. Use `getFields()` for namespace handling.

**Returns:** [SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm) - A map of field API names to `SObjectField` instances.

**Since:** 1.0

**Example:**

```apex
UTIL_SObjectDescribe describe = UTIL_SObjectDescribe.getDescribe('Account');
Map<String, SObjectField> fieldMap = describe.getFieldsMap();
System.debug(fieldMap.keySet().size()); // Outputs: Number of fields on Account
```

### getGlobalDescribe

```apex
global static UTIL_SObjectDescribe.GlobalDescribeMap getGlobalDescribe()
```

Retrieves a wrapped map of global `SObjectType` names to `SObjectType` instances with namespace handling.

**Returns:** [UTIL_SObjectDescribe.GlobalDescribeMap](UTIL_SObjectDescribe.GlobalDescribeMap.md) - A `GlobalDescribeMap` containing global `SObjectType` data.

**Since:** 1.0

**Example:**

```apex
UTIL_SObjectDescribe.GlobalDescribeMap globalDescribe = UTIL_SObjectDescribe.getGlobalDescribe();
System.debug(globalDescribe.get('Account')?.getDescribe().getLabel()); // Outputs: Account
```

### getNameField

```apex
global SObjectField getNameField()
```

Retrieves the name field of the SObject (where `isNameField()` is true).

**Returns:** [SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm) - The `SObjectField` where `isNameField()` is true, or null if no such field exists.

**Since:** 1.0

**Example:**

```apex
UTIL_SObjectDescribe describe = UTIL_SObjectDescribe.getDescribe('Account');
SObjectField nameField = describe.getNameField();
System.debug(nameField.getDescribe().name); // Outputs: Name
```

### getNestableFieldNames

```apex
global static Set<String> getNestableFieldNames(String objectName)
```

Walks the object tree and returns all fields for related objects (one level deep).

**Parameters:**

- `objectName` ([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)) - The name of the starting object

**Returns:** [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) - A set of fields using multipart dot notation (e.g. Account.Name)

**Since:** 1.0

**Example:**

```apex
Set<String> fields = UTIL_SObjectDescribe.getNestableFieldNames('Contact');
```

### getNestableFieldNames

```apex
global static Set<String> getNestableFieldNames(String objectName, Integer levels)
```

Walks the object tree and returns all fields for related objects up to the specified depth.

**Parameters:**

- `objectName` ([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)) - The name of the starting object
- `levels` ([Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm)) - The number of levels to traverse (maximum 5)

**Returns:** [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) - A set of fields using multipart dot notation (e.g. Account.Name)

**Since:** 1.0

**Example:**

```apex
Set<String> fields = UTIL_SObjectDescribe.getNestableFieldNames('Contact', 2);
```

### getObjectFieldMap

```apex
global static Map<String, SObjectField> getObjectFieldMap(SObjectType objectType)
```

Returns the field map for an object by SObjectType.

**Parameters:**

- `objectType` ([SObjectType](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectType.htm)) - The type of the object for which to retrieve a field map

**Returns:** [SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm) - A Map of SObject Fields keyed by field API name

**Since:** 1.0

**Example:**

```apex
Map<String, SObjectField> fields = UTIL_SObjectDescribe.getObjectFieldMap(Account.SObjectType);
```

### getObjectFieldMap

```apex
global static Map<String, SObjectField> getObjectFieldMap(String objectName)
```

Returns the field map for an object by API name.

**Parameters:**

- `objectName` ([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)) - The name of the object to retrieve fields for

**Returns:** [SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm) - A Map of SObject Fields keyed by field API name

**Since:** 1.0

**Example:**

```apex
Map<String, SObjectField> fields = UTIL_SObjectDescribe.getObjectFieldMap('Account');
```

### getObjectFieldReferenceMap

```apex
global static Map<String, SObjectField> getObjectFieldReferenceMap(String objectName)
```

Returns a map of reference (lookup/master-detail) fields keyed by relationship name.

**Parameters:**

- `objectName` ([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)) - The name of the object to retrieve fields map for

**Returns:** [SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm) - A Map of SObject Fields keyed by relationship name; non-reference fields are excluded

**Since:** 1.0

**Example:**

```apex
Map<String, SObjectField> refFields = UTIL_SObjectDescribe.getObjectFieldReferenceMap('Contact');
```

### getObjectNameFromId

```apex
global static String getObjectNameFromId(Id objectId)
```

Returns the API name of an object based on its ID.

**Parameters:**

- `objectId` ([Id](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_id.htm)) - An Id of an SObject

**Returns:** [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) - The API name of the object, or null if the ID is invalid.

**Since:** 1.0

**Example:**

```apex
String objectName = UTIL_SObjectDescribe.getObjectNameFromId(recordId); // e.g. 'Account'
```

### getObjectNameFromType

```apex
global static String getObjectNameFromType(SObjectType objectType)
```

Will get the API name for the SObject given a specific type. Uses a describe cache

**Parameters:**

- `objectType` ([SObjectType](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectType.htm)) - The object type for which to get the name

**Returns:** [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) - The Name of the object

**Since:** 1.0

**Example:**

```apex
String result = UTIL_SObjectDescribe.getObjectNameFromType(Account.SObjectType);
```

**See Also:** [UTIL_SObjectDescribe.getDescribe](#getdescribe)

### getPicklistEntries

```apex
global static List<PicklistEntry> getPicklistEntries(SObjectField pickField)
```

Returns a list of picklist entries for a given SObject field reference.

**Parameters:**

- `pickField` ([SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm)) - SObject Field reference for the picklist field

**Returns:** [PicklistEntry](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_PicklistEntry.htm) - List of picklist entries

**Since:** 1.0

**Example:**

```apex
List<PicklistEntry> entries = UTIL_SObjectDescribe.getPicklistEntries(Account.Industry);
```

### getPicklistEntriesMap

```apex
global static Map<String, String> getPicklistEntriesMap(SObjectField pickField)
```

Returns a map of picklist label-to-value pairs for a given SObject field reference.

**Parameters:**

- `pickField` ([SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm)) - The Object Field which to retrieve entries

**Returns:** [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) - A map of picklist values keyed by label

**Since:** 1.0

**Example:**

```apex
Map<String, String> valueByLabel = UTIL_SObjectDescribe.getPicklistEntriesMap(Account.Industry);
```

### getPicklistEntriesMap

```apex
global static Map<String, String> getPicklistEntriesMap(SObjectField pickField, Boolean useLabelAsKey)
```

Returns a map of picklist entries with configurable key for a given SObject field reference.

**Parameters:**

- `pickField` ([SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm)) - The Object Field for which to retrieve entries
- `useLabelAsKey` ([Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm)) - If true the key will be the picklist label, else it will be the API value

**Returns:** [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) - A map of the found items

**Since:** 1.0

**Example:**

```apex
Map<String, String> labelByValue = UTIL_SObjectDescribe.getPicklistEntriesMap(Account.Industry, false);
```

### getPicklistValues

```apex
global static List<DTO_PickList> getPicklistValues(String objectApiName, Id recordTypeId)
```

Returns all picklist values for a given object and record type combination
as a list of DTO_PickList objects, including dependent picklist relationships.
Uses ConnectApi.RecordUi natively and transforms the results into framework DTOs.

**Parameters:**

- `objectApiName` ([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)) - The API name of the SObject
- `recordTypeId` ([Id](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_id.htm)) - The record type ID

**Returns:** [DTO_PickList](DTO_PickList.md) - A list of DTO_PickList objects containing picklist names and their values

**Since:** 1.0

**Example:**

```apex
List<DTO_PickList> pickLists = UTIL_SObjectDescribe.getPicklistValues('Account', recordTypeId);
```

### getPicklistValuesByRecordType

```apex
global static ConnectApi.PicklistValuesCollection getPicklistValuesByRecordType(String objectApiName, Id recordTypeId)
```

Returns all picklist values for a given object and record type combination,
including dependent picklist relationships. Uses ConnectApi.RecordUi natively.

**Parameters:**

- `objectApiName` ([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)) - The API name of the SObject
- `recordTypeId` ([Id](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_id.htm)) - The record type ID

**Returns:** The ConnectApi picklist values collection

**Since:** 1.0

**Example:**

```apex
ConnectApi.PicklistValuesCollection collection = UTIL_SObjectDescribe.getPicklistValuesByRecordType('Account', recordTypeId);
```

### getRawGlobalDescribe

```apex
global static Map<String, SObjectType> getRawGlobalDescribe()
```

Retrieves a cached map of global `SObjectType` names to `SObjectType` instances.

**Returns:** [SObjectType](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectType.htm) - A map of `SObjectType` names to `SObjectType` instances.

**Since:** 1.0

**Example:**

```apex
Map<String, SObjectType> globalDescribe = UTIL_SObjectDescribe.getRawGlobalDescribe();
System.debug(globalDescribe.containsKey('Account')); // Outputs: true
```

### getRecordTypeByDeveloperName

```apex
global static Id getRecordTypeByDeveloperName(SObjectType objectType, String recordTypeName)
```

Retrieves the Id of a record type for an SObject by its developer name.

**Parameters:**

- `objectType` ([SObjectType](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectType.htm)) - The SObject type.
- `recordTypeName` ([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)) - The developer name of the record type.

**Returns:** [Id](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_id.htm) - The Id of the record type, or null if not found.

**Since:** 1.0

**Example:**

```apex
Id recordTypeId = UTIL_SObjectDescribe.getRecordTypeByDeveloperName(Account.SObjectType, 'Customer');
```

### getSObjectFieldNames

```apex
global static Set<String> getSObjectFieldNames(Set<SObjectField> objectFields)
```

Converts a set of SObjectField tokens to their API name strings.

**Parameters:**

- `objectFields` ([Set](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_set.htm)) - The fields for which to get field names

**Returns:** [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) - A set of SObject field API names

**Since:** 1.0

**Example:**

```apex
Set<SObjectField> fields = new Set<SObjectField>{ Account.Name, Account.Industry };
Set<String> names = UTIL_SObjectDescribe.getSObjectFieldNames(fields); // {'Name', 'Industry'}
```

### getSObjectType

```apex
global SObjectType getSObjectType()
```

Returns the `SObjectType` this instance is based on, useful for retrieving metadata about the specific object.

**Returns:** [SObjectType](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectType.htm) - The `SObjectType` of the described object.

**Since:** 1.0

**Example:**

```apex
UTIL_SObjectDescribe describe = UTIL_SObjectDescribe.getDescribe('Account');
SObjectType objType = describe.getSObjectType();
System.debug(objType); // Outputs: Account
```

### getSObjectTypeById

```apex
global static SObjectType getSObjectTypeById(Id objectId)
```

Returns the SObjectType token for a given record ID.

**Parameters:**

- `objectId` ([Id](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_id.htm)) - An Id of an SObject

**Returns:** [SObjectType](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectType.htm) - The SObjectType for the record, or null if the ID is null.

**Since:** 1.0

**Example:**

```apex
SObjectType accountType = UTIL_SObjectDescribe.getSObjectTypeById(someAccountId);
```

### getSObjectTypeByName

```apex
global static SObjectType getSObjectTypeByName(String objectApiName)
```

Returns the SObjectType token for a given object API name.

**Parameters:**

- `objectApiName` ([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)) - The API name of the object

**Returns:** [SObjectType](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectType.htm) - The corresponding SObjectType or null if the API name is invalid.

**Since:** 1.0

**Example:**

```apex
SObjectType accountType = UTIL_SObjectDescribe.getSObjectTypeByName('Account');
```

### isPersonAccountEnabled

```apex
global static Boolean isPersonAccountEnabled()
```

Determines whether Person Accounts are enabled by checking for the `isPersonAccount` field on Account.

**Returns:** [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) - `true` if Person Accounts are enabled, `false` otherwise.

**Since:** 1.0

**Example:**

```apex
Boolean isPersonAccountEnabled = UTIL_SObjectDescribe.isPersonAccountEnabled();
System.debug(isPersonAccountEnabled); // Outputs: true or false based on org configuration
```

### isRecordTypeAvailable

```apex
global static Boolean isRecordTypeAvailable(SObjectType objectType, String recordTypeName)
```

Reports whether a record type, identified by its developer name, is available to the
running user for the given SObject. A record type is available only when it exists, is active, and
is assigned to the running user's profile or a permission set. Check this before stamping a
RecordTypeId so an insert does not fail with INVALID_CROSS_REFERENCE_KEY when the type is not
assigned to the running user — for example a packaged record type that a subscriber has not
assigned to the profile the code runs under.

**Parameters:**

- `objectType` ([SObjectType](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectType.htm)) - The SObject type.
- `recordTypeName` ([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)) - The developer name of the record type.

**Returns:** [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) - true when the record type exists and is available to the running user; false otherwise.

**Since:** 1.1

**Example:**

```apex
if(UTIL_SObjectDescribe.isRecordTypeAvailable(Account.SObjectType, 'Customer'))
{
    account.RecordTypeId = UTIL_SObjectDescribe.getRecordTypeByDeveloperName(Account.SObjectType, 'Customer');
}
```

