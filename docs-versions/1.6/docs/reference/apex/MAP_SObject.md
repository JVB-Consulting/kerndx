---
title: "MAP_SObject"
type: class
pageClass: reference
description: "In-memory index for SObjects, indexed by one or more fields. Supports cross-object field references, case-insensitive matching, and hierarchical multi-field indexing.  **Performance & Usage Guidelines"
author: "Jason Van Beukering"
group: "Utilities"
date: "February 2026, May 2026"
since: "1.0"
category: apex
---

# MAP_SObject

**Class** · Group: `Utilities`

<div class="apex-member apex-class">

```apex
global inherited sharing class MAP_SObject
```

In-memory index for SObjects, indexed by one or more fields. Supports cross-object field references,
case-insensitive matching, and hierarchical multi-field indexing.

**Performance & Usage Guidelines**

Use MAP_SObject when:

    - **Grouping (1-to-Many):** You need to map a key to multiple records (e.g., "Get all Contacts by AccountId").
  MAP_SObject handles list creation automatically, eliminating boilerplate null-checks.

    - **Cross-Object Fields:** You need to index by relationship fields (e.g., `Account.Owner.Name`).

    - **Composite Keys:** You need hierarchical indexing by multiple fields (e.g., AccountId then LastName).

    - **Case-Insensitive Matching:** You need to match keys regardless of case without manual string normalization.

Use native `Map<Id, SObject>` instead when:

    - **Unique Primary Keys:** You are indexing by Id or a unique field where 1 Key = 1 Record.
  Native Apex Maps are approximately 5-10x faster and consume less heap memory than this utility.
  Always prefer native Maps for simple ID lookups in performance-critical code paths (e.g., triggers).

```apex
// BAD: Using MAP_SObject for unique ID lookups
MAP_SObject accountsById = MAP_SObject.of(accounts, 'Id');
Account account = (Account)accountsById.get(someId);

// GOOD: Using native Map for unique ID lookups
Map<Id, Account> accountsById = new Map<Id, Account>(accounts);
Account account = accountsById.get(someId);

// GOOD: Using MAP_SObject for 1-to-Many grouping
MAP_SObject contactsByAccountId = MAP_SObject.of(contacts, 'AccountId');
List<Contact> accountContacts = contactsByAccountId.getAll(someAccountId);

```

Adapted from: SObjectIndex

**Example**

```apex
MAP_SObject contactsByAccountId = MAP_SObject.of(contacts, 'AccountId');
List<Contact> accountContacts = contactsByAccountId.getAll(someAccountId);
Contact first = (Contact)contactsByAccountId.get(someAccountId);
```

</div>

---

## Methods

| Method | Description |
|--------|-------------|
| global [MAP_SObject](MAP_SObject.md) [caseInsensitive](#caseinsensitive)() | Enables case-insensitive key matching. |
| global void [clear](#clear)() | Removes all records from the index, allowing it to be reused or explicitly freeing memory. |
| global [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) [containsKey](#containskey)([Object](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_System_Object.htm) key) | Checks if the index contains records for the specified key at the first index level. |
| global [SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm) [get](#get)([Object](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_System_Object.htm) key) | Retrieves a single SObject matching the specified key. |
| global [SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm) [get](#get)([SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm) specification) | Retrieves a single SObject matching the specification SObject on all indexed fields. |
| global [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm)> [getAll](#getall)([Map](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_map.htm)<[String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm), [Object](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_System_Object.htm)> fieldValueMap) | Retrieves all SObjects matching the field-value map for indexed fields. |
| global [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm)> [getAll](#getall)([Object](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_System_Object.htm) key) | Retrieves all SObjects matching the specified key. |
| global [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm)> [getAll](#getall)([SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm) specification) | Retrieves all SObjects matching the specification SObject on all indexed fields. |
| global [MAP_SObject](MAP_SObject.md) [getSubIndex](#getsubindex)([Object](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_System_Object.htm) key) | Retrieves a sub-index for entries matching the specified key. |
| global [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) [isEmpty](#isempty)() | Checks if the index is empty. |
| global [Set](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_set.htm)<[String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)> [keySet](#keyset)() | Retrieves the set of unique keys for the current index level. |
| global [Set](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_set.htm)<[String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)> [keySet](#keyset)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) field) | Retrieves the set of unique keys for a specific field in the index. |
| global static [MAP_SObject](MAP_SObject.md) [of](#of)([List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm)> records, [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)> fieldNames) | Creates an index from a list of records indexed by multiple fields. |
| global static [MAP_SObject](MAP_SObject.md) [of](#of)([List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm)> records, [SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm) field) | Creates an index from a list of records indexed by a single field token. |
| global static [MAP_SObject](MAP_SObject.md) [of](#of)([List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm)> records, [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) fieldName) | Creates an index from a list of records indexed by a single field. |
| global [MAP_SObject](MAP_SObject.md) [put](#put)([SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm) sObjectToAdd) | Adds a single SObject to the index. |
| global [MAP_SObject](MAP_SObject.md) [putAll](#putall)([List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm)> sObjectsToAdd) | Adds a list of SObjects to the index. |
| global [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm)> [remove](#remove)([Map](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_map.htm)<[String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm), [Object](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_System_Object.htm)> fieldValueMap) | Removes SObjects matching the field-value map from the index. |
| global [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm)> [remove](#remove)([SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm) specification) | Removes SObjects matching the specification SObject from the index. |
| global [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) [size](#size)() | Returns the total number of SObjects stored in the index. |
| global override [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [toString](#tostring)() | Returns a string representation of the index structure for debugging purposes. |
| global [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm)> [values](#values)() | Retrieves all SObjects stored in the index. |

### caseInsensitive

<div class="apex-member">

```apex
global MAP_SObject caseInsensitive()
```

Enables case-insensitive key matching. Must be called on an empty index.

**Returns** [MAP_SObject](MAP_SObject.md) — This MAP_SObject instance for method chaining.

**Example**

```apex
MAP_SObject index = MAP_SObject.of(contacts, 'Email').caseInsensitive();
Contact c = (Contact)index.get('JOHN@EXAMPLE.COM');
```

</div>

### clear

<div class="apex-member">

```apex
global void clear()
```

Removes all records from the index, allowing it to be reused or explicitly freeing memory.

**Example**

```apex
MAP_SObject index = MAP_SObject.of(accounts, 'Industry');
index.clear();
Assert.isTrue(index.isEmpty());
```

</div>

### containsKey

<div class="apex-member">

```apex
global Boolean containsKey(Object key)
```

Checks if the index contains records for the specified key at the first index level.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `key` | [Object](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_System_Object.htm) | A value for the first indexed field. |

**Returns** [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) — `true` if records exist for the key, `false` otherwise.

**Example**

```apex
MAP_SObject index = MAP_SObject.of(accounts, 'Industry');
if(index.containsKey('Technology'))
{
    // Process technology accounts
}
```

</div>

### get

<div class="apex-member">

```apex
global SObject get(Object key)
```

Retrieves a single SObject matching the specified key.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `key` | [Object](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_System_Object.htm) | A value for the indexed field. |

**Returns** [SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm) — A matching SObject, or null if no match is found (returns the first match if multiple exist).

**Example**

```apex
MAP_SObject index = MAP_SObject.of(accounts, 'Id');
Account acc = (Account)index.get(someAccountId);
```

</div>

<div class="apex-member">

```apex
global SObject get(SObject specification)
```

Retrieves a single SObject matching the specification SObject on all indexed fields.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `specification` | [SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm) | An SObject with values for all indexed fields. |

**Returns** [SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm) — A matching SObject, or null if no match is found (returns the first match if multiple exist).

**Example**

```apex
MAP_SObject index = MAP_SObject.of(contacts, new List<String>{'AccountId', 'LastName'});
Contact c = (Contact)index.get(new Contact(AccountId = accId, LastName = 'Smith'));
```

</div>

### getAll

<div class="apex-member">

```apex
global List<SObject> getAll(Map<String, Object> fieldValueMap)
```

Retrieves all SObjects matching the field-value map for indexed fields.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `fieldValueMap` | [Map](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_map.htm) | A map of field names to values. |

**Returns** [SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm) — A list of matching SObjects, or an empty list if no matches are found.

**Example**

```apex
MAP_SObject index = MAP_SObject.of(contacts, new List<String>{'AccountId', 'LastName'});
Map<String, Object> spec = new Map<String, Object>{ 'LastName' => 'Smith' };
List<Contact> results = index.getAll(spec);
```

</div>

<div class="apex-member">

```apex
global List<SObject> getAll(Object key)
```

Retrieves all SObjects matching the specified key.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `key` | [Object](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_System_Object.htm) | A value for the indexed field. |

**Returns** [SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm) — A list of matching SObjects, or an empty list if no matches are found.

**Example**

```apex
MAP_SObject index = MAP_SObject.of(contacts, 'AccountId');
List<Contact> accountContacts = index.getAll(someAccountId);
```

</div>

<div class="apex-member">

```apex
global List<SObject> getAll(SObject specification)
```

Retrieves all SObjects matching the specification SObject on all indexed fields.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `specification` | [SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm) | An SObject with values for all indexed fields. |

**Returns** [SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm) — A list of matching SObjects, or an empty list if no matches are found.

**Example**

```apex
MAP_SObject index = MAP_SObject.of(contacts, new List<String>{'AccountId', 'LastName'});
List<Contact> results = index.getAll(new Contact(AccountId = accId, LastName = 'Smith'));
```

</div>

### getSubIndex

<div class="apex-member">

```apex
global MAP_SObject getSubIndex(Object key)
```

Retrieves a sub-index for entries matching the specified key.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `key` | [Object](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_System_Object.htm) | A value for the first indexed field. |

**Returns** [MAP_SObject](MAP_SObject.md) — A MAP_SObject for matching entries, or null if no match is found.

**Example**

```apex
MAP_SObject index = MAP_SObject.of(contacts, new List<String>{'AccountId', 'LastName'});
MAP_SObject accountContacts = index.getSubIndex(someAccountId);
List<Contact> smiths = accountContacts.getAll('Smith');
```

</div>

### isEmpty

<div class="apex-member">

```apex
global Boolean isEmpty()
```

Checks if the index is empty.

**Returns** [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) — `true` if the index is empty, `false` otherwise.

**Example**

```apex
MAP_SObject index = new MAP_SObject('Name');
Boolean isEmpty = index.isEmpty(); // Returns true
```

</div>

### keySet

<div class="apex-member">

```apex
global Set<String> keySet()
```

Retrieves the set of unique keys for the current index level.

**Returns** [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) — A set of string keys.

**Example**

```apex
MAP_SObject index = MAP_SObject.of(accounts, 'Industry');
Set<String> industries = index.keySet();
```

</div>

<div class="apex-member">

```apex
global Set<String> keySet(String field)
```

Retrieves the set of unique keys for a specific field in the index.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `field` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The field name to retrieve keys for. |

**Returns** [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) — A set of string keys.

**Example**

```apex
MAP_SObject index = MAP_SObject.of(contacts, new List<String>{'AccountId', 'LastName'});
Set<String> lastNames = index.keySet('LastName');
```

</div>

### of

<div class="apex-member">

```apex
global static MAP_SObject of(List<SObject> records, List<String> fieldNames)
```

Creates an index from a list of records indexed by multiple fields.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `records` | [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm) | The records to index. |
| `fieldNames` | [SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm) | The fields to index by (hierarchical). |

**Returns** [MAP_SObject](MAP_SObject.md) — A new MAP_SObject containing the indexed records.

**Example**

```apex
MAP_SObject contactsByAccountAndName = MAP_SObject.of(contacts, new List<String>{'AccountId', 'LastName'});
List<Contact> contacts = contactsByAccountAndName.getAll(new Contact(AccountId = accId, LastName = 'Smith'));
```

</div>

<div class="apex-member">

```apex
global static MAP_SObject of(List<SObject> records, SObjectField field)
```

Creates an index from a list of records indexed by a single field token.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `records` | [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm) | The records to index. |
| `field` | [SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm) | The field token to index by. |

**Returns** [MAP_SObject](MAP_SObject.md) — A new MAP_SObject containing the indexed records.

**Example**

```apex
MAP_SObject accountsById = MAP_SObject.of(accounts, Account.Id);
Account acc = (Account)accountsById.get(someId);
```

</div>

<div class="apex-member">

```apex
global static MAP_SObject of(List<SObject> records, String fieldName)
```

Creates an index from a list of records indexed by a single field.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `records` | [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm) | The records to index. |
| `fieldName` | [SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm) | The field to index by. |

**Returns** [MAP_SObject](MAP_SObject.md) — A new MAP_SObject containing the indexed records.

**Example**

```apex
MAP_SObject accountsById = MAP_SObject.of(accounts, 'Id');
Account acc = (Account)accountsById.get(someId);
```

</div>

### put

<div class="apex-member">

```apex
global MAP_SObject put(SObject sObjectToAdd)
```

Adds a single SObject to the index.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `sObjectToAdd` | [SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm) | The SObject to add. |

**Returns** [MAP_SObject](MAP_SObject.md) — This MAP_SObject instance for method chaining.

**Example**

```apex
MAP_SObject index = new MAP_SObject('Name');
index.put(new Account(Name='Acme'));
```

</div>

### putAll

<div class="apex-member">

```apex
global MAP_SObject putAll(List<SObject> sObjectsToAdd)
```

Adds a list of SObjects to the index.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `sObjectsToAdd` | [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm) | List of SObjects to add. |

**Returns** [MAP_SObject](MAP_SObject.md) — This MAP_SObject instance for method chaining.

**Example**

```apex
MAP_SObject index = new MAP_SObject('Name');
index.putAll(new List<Account>{new Account(Name='Acme')});
```

</div>

### remove

<div class="apex-member">

```apex
global List<SObject> remove(Map<String, Object> fieldValueMap)
```

Removes SObjects matching the field-value map from the index.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `fieldValueMap` | [Map](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_map.htm) | A map of field names to values. |

**Returns** [SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm) — A list of removed SObjects, or an empty list if no matches are found.

**Example**

```apex
MAP_SObject index = MAP_SObject.of(contacts, new List<String>{'AccountId', 'LastName'});
Map<String, Object> spec = new Map<String, Object>{ 'LastName' => 'Smith' };
List<SObject> removed = index.remove(spec);
```

</div>

<div class="apex-member">

```apex
global List<SObject> remove(SObject specification)
```

Removes SObjects matching the specification SObject from the index.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `specification` | [SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm) | An SObject with values for all indexed fields. |

**Returns** [SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm) — A list of removed SObjects, or an empty list if no matches are found.

**Example**

```apex
MAP_SObject index = MAP_SObject.of(contacts, 'AccountId');
List<SObject> removed = index.remove(new Contact(AccountId = accId));
```

</div>

### size

<div class="apex-member">

```apex
global Integer size()
```

Returns the total number of SObjects stored in the index. More efficient than `values().size()`
as it counts recursively without materializing the full list.

**Returns** [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) — The total count of indexed SObjects.

**Example**

```apex
MAP_SObject index = MAP_SObject.of(contacts, 'AccountId');
System.debug('Indexed ' + index.size() + ' contacts');
```

</div>

### toString

<div class="apex-member">

```apex
global override String toString()
```

Returns a string representation of the index structure for debugging purposes.

**Returns** [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) — A string showing the index field, depth, and current keys.

**Example**

```apex
MAP_SObject index = MAP_SObject.of(contacts, new List<String>{'AccountId', 'LastName'});
System.debug(index); // Outputs: MAP_SObject[field=AccountId, depth=0, keys={001...}]
```

</div>

### values

<div class="apex-member">

```apex
global List<SObject> values()
```

Retrieves all SObjects stored in the index.

**Returns** [SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm) — A list of all SObjects in the index.

**Example**

```apex
MAP_SObject index = MAP_SObject.of(accounts, 'Industry');
List<SObject> allAccounts = index.values();
```

</div>

## Constructors

| Constructor | Description |
|-------------|-------------|
| global [MAP_SObject](#constructors)([List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)> indexFields) | Initializes a new MAP_SObject with multiple indexed fields. |
| global [MAP_SObject](#constructors)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) fieldName) | Initializes a new MAP_SObject with a single indexed field. |

### MAP_SObject(List<String> indexFields)

<div class="apex-member">

```apex
global MAP_SObject(List<String> indexFields)
```

Initializes a new MAP_SObject with multiple indexed fields.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `indexFields` | [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm) | The list of fields to index. |

**Example**

```apex
MAP_SObject index = new MAP_SObject(new List<String>{'AccountId', 'LastName'});
```

</div>

### MAP_SObject(String fieldName)

<div class="apex-member">

```apex
global MAP_SObject(String fieldName)
```

Initializes a new MAP_SObject with a single indexed field.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `fieldName` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The name of the field to index. |

**Example**

```apex
MAP_SObject index = new MAP_SObject('Name');
```

</div>

