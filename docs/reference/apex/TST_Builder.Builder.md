---
title: "TST_Builder.Builder"
type: class
pageClass: reference
description: "A fluid builder for configuring and creating SObject records. Obtain an instance via TST_Builder.of(SObjectType)."
since: "1.0"
category: apex
---

# TST_Builder.Builder

**Class**

```apex
global inherited sharing class TST_Builder.Builder
```

A fluid builder for configuring and creating SObject records. Obtain an instance via TST_Builder.of(SObjectType).

**Since:** 1.0

---

## Methods

| Method | Description |
|--------|-------------|
| global [SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm) [build](#build)() | Executes the build operation and creates a single SObject record. |
| global [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm)> [buildList](#buildlist)() | Executes the build operation and creates a list of SObject records. |
| global [TST_Builder.Builder](TST_Builder.Builder.md) [withChildren](#withchildren)([SObjectType](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectType.htm) childType, [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) count) | Adds child records to the parent being built without field overrides. |
| global [TST_Builder.Builder](TST_Builder.Builder.md) [withChildren](#withchildren)([SObjectType](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectType.htm) childType, [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) count, [Map](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_map.htm)<[SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm), [Object](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_System_Object.htm)> overrides) | Adds child records to the parent being built using SObjectField tokens. |
| global [TST_Builder.Builder](TST_Builder.Builder.md) [withChildren](#withchildren)([SObjectType](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectType.htm) childType, [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) count, [Map](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_map.htm)<[String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm), [Object](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_System_Object.htm)> overrides) | Adds child records to the parent being built using String field names. |
| global [TST_Builder.Builder](TST_Builder.Builder.md) [withChildren](#withchildren)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) relationshipName, [TST_Builder.Builder](TST_Builder.Builder.md) childBuilder) | Adds child records using a pre-configured Builder instance with explicit relationship name. |
| global [TST_Builder.Builder](TST_Builder.Builder.md) [withChildren](#withchildren)([TST_Builder.Builder](TST_Builder.Builder.md) childBuilder) | Adds child records using a pre-configured Builder instance with auto-detected relationship name. |
| global [TST_Builder.Builder](TST_Builder.Builder.md) [withCount](#withcount)([Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) count) | Sets the number of SObject records to create when calling buildList(). |
| global [TST_Builder.Builder](TST_Builder.Builder.md) [withCycle](#withcycle)([SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm) field, [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[Object](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_System_Object.htm)> values) | Assigns a list of values that cycle across records built by buildList(). |
| global [TST_Builder.Builder](TST_Builder.Builder.md) [withCycle](#withcycle)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) fieldName, [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[Object](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_System_Object.htm)> values) | Assigns a list of values that cycle across records built by buildList(). |
| global [TST_Builder.Builder](TST_Builder.Builder.md) [withDefaultedField](#withdefaultedfield)([SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm) field) | Specifies an optional field to populate with a default value using an SObjectField token. |
| global [TST_Builder.Builder](TST_Builder.Builder.md) [withDefaultedField](#withdefaultedfield)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) fieldName) | Specifies an optional field to populate with a default value, even though it is not marked as required. |
| global [TST_Builder.Builder](TST_Builder.Builder.md) [withDefaultedFields](#withdefaultedfields)([List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[Object](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_System_Object.htm)> fields) | Specifies a list of optional fields to populate with default values, even though they are not marked as required. |
| global [TST_Builder.Builder](TST_Builder.Builder.md) [withOptionalField](#withoptionalfield)([SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm) field) | Specifies a field to treat as optional using an SObjectField token, preventing the factory from auto-populating it as a required field. |
| global [TST_Builder.Builder](TST_Builder.Builder.md) [withOptionalField](#withoptionalfield)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) fieldName) | Specifies a field to treat as optional, preventing the factory from auto-populating it as a required field. |
| global [TST_Builder.Builder](TST_Builder.Builder.md) [withOptionalFields](#withoptionalfields)([List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[Object](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_System_Object.htm)> fields) | Specifies a list of fields to treat as optional, preventing the factory from auto-populating them as required fields. |
| global [TST_Builder.Builder](TST_Builder.Builder.md) [withoutInsertion](#withoutinsertion)() | Configures the build to not insert the records into the database. |
| global [TST_Builder.Builder](TST_Builder.Builder.md) [withoutInsertion](#withoutinsertion)([Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) withMockIds) | Configures the build to not insert the records into the database, with an option to generate mock IDs for the entire object graph. |
| global [TST_Builder.Builder](TST_Builder.Builder.md) [withOverride](#withoverride)([SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm) field, [Object](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_System_Object.htm) value) | Applies a specific field value override using an SObjectField token. |
| global [TST_Builder.Builder](TST_Builder.Builder.md) [withOverride](#withoverride)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) fieldName, [Object](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_System_Object.htm) value) | Applies a specific field value override. |
| global [TST_Builder.Builder](TST_Builder.Builder.md) [withOverrides](#withoverrides)([Map](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_map.htm)<[SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm), [Object](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_System_Object.htm)> overrides) | Applies a map of specific field values using SObjectField tokens, overriding defaults. |
| global [TST_Builder.Builder](TST_Builder.Builder.md) [withOverrides](#withoverrides)([Map](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_map.htm)<[String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm), [Object](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_System_Object.htm)> overrides) | Applies a map of specific field values, overriding defaults. |
| global [TST_Builder.Builder](TST_Builder.Builder.md) [withRecordType](#withrecordtype)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) recordTypeDeveloperName) | Sets the Record Type for the SObject(s) to be built, using the Record Type's DeveloperName. |

---

## Method Details

### build

<div class="apex-member">

```apex
global SObject build()
```

Executes the build operation and creates a single SObject record.
If `withCount()` was called, this method still only returns one record.

**Returns** [SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm) — The created SObject record (inserted by default unless `withoutInsertion()` was called).

**Example**

```apex
// Build and insert a single Account
Account account = (Account)TST_Builder.of(Account.SObjectType)
	.withOverride('Name', 'Test Account')
	.build();
Assert.isNotNull(account.Id);
```

</div>

### buildList

<div class="apex-member">

```apex
global List<SObject> buildList()
```

Executes the build operation and creates a list of SObject records.
The number of records is determined by the value passed to `withCount()` (defaults to 1).

**Returns** [SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm) — A list of the created SObject records (inserted by default unless `withoutInsertion()` was called).

**Example**

```apex
// Build and insert 5 Contact records
List<Contact> contacts = (List<Contact>)TST_Builder.of(Contact.SObjectType)
	.withCount(5)
	.withOverride('LastName', 'Smith')
	.buildList();
Assert.areEqual(5, contacts.size());
Assert.isNotNull(contacts[0].Id);
```

</div>

### withChildren

<div class="apex-member">

```apex
global TST_Builder.Builder withChildren(SObjectType childType, Integer count)
```

Adds child records to the parent being built without field overrides.
The simplest way to add child records - relationship name is auto-detected.
All child fields will use framework defaults.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `childType` | [SObjectType](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectType.htm) | The SObjectType of the child records |
| `count` | [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) | Number of child records to create |

**Returns** [TST_Builder.Builder](TST_Builder.Builder.md) — Builder for method chaining

**Example**

```apex
Account account = (Account)TST_Builder.of(Account.SObjectType)
    .withOverride(Account.Name, 'ACME Corp')
    .withChildren(Contact.SObjectType, 3)
    .build();
Assert.areEqual(3, account.Contacts.size());
```

</div>

<div class="apex-member">

```apex
global TST_Builder.Builder withChildren(SObjectType childType, Integer count, Map<SObjectField, Object> overrides)
```

Adds child records to the parent being built using SObjectField tokens.
The child records will be assigned to the appropriate relationship field.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `childType` | [SObjectType](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectType.htm) | The SObjectType of the child records |
| `count` | [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) | Number of child records to create |
| `overrides` | [Map](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_map.htm) | Field overrides for child records using SObjectField tokens |

**Returns** [TST_Builder.Builder](TST_Builder.Builder.md) — Builder for method chaining

**Example**

```apex
Account account = (Account)TST_Builder.of(Account.SObjectType)
    .withOverride(Account.Name, 'ACME Corp')
    .withChildren(Contact.SObjectType, 3, new Map<SObjectField, Object>{
        Contact.FirstName => 'John',
        Contact.LastName => 'Doe'
    })
    .build();
Assert.areEqual(3, account.Contacts.size());
```

</div>

<div class="apex-member">

```apex
global TST_Builder.Builder withChildren(SObjectType childType, Integer count, Map<String, Object> overrides)
```

Adds child records to the parent being built using String field names.
The child records will be assigned to the appropriate relationship field.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `childType` | [SObjectType](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectType.htm) | The SObjectType of the child records |
| `count` | [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) | Number of child records to create |
| `overrides` | [Map](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_map.htm) | Field overrides for child records using String field names |

**Returns** [TST_Builder.Builder](TST_Builder.Builder.md) — Builder for method chaining

**Example**

```apex
Account account = (Account)TST_Builder.of(Account.SObjectType)
    .withOverride('Name', 'ACME Corp')
    .withChildren(Contact.SObjectType, 2, new Map<String, Object>{
        'LastName' => 'Smith'
    })
    .build();
```

</div>

<div class="apex-member">

```apex
global TST_Builder.Builder withChildren(String relationshipName, TST_Builder.Builder childBuilder)
```

Adds child records using a pre-configured Builder instance with explicit relationship name.
EDGE CASE ONLY: Use this variant when there are multiple relationships between the same parent and child types
(e.g., self-referential with multiple lookup fields, or objects with multiple lookups to the same parent).
For most cases, use withChildren(Builder) which auto-detects the relationship name.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `relationshipName` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The child relationship name (e.g., 'Contacts', 'Opportunities', 'PrimaryContacts__r') |
| `childBuilder` | [TST_Builder.Builder](TST_Builder.Builder.md) | A pre-configured Builder instance for the child records |

**Returns** [TST_Builder.Builder](TST_Builder.Builder.md) — Builder for method chaining

**Example**

```apex
// Edge case: Foobar__c has TWO lookup fields to Contact (PrimaryContact__c, SecondaryContact__c)
Foobar__c foobar = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
    .withChildren('PrimaryContacts__r',
        TST_Builder.of(Contact.SObjectType).withCount(2)
    )
    .withChildren('SecondaryContacts__r',
        TST_Builder.of(Contact.SObjectType).withCount(1)
    )
    .build();
```

</div>

<div class="apex-member">

```apex
global TST_Builder.Builder withChildren(TST_Builder.Builder childBuilder)
```

Adds child records using a pre-configured Builder instance with auto-detected relationship name.
The relationship name is automatically determined from the child Builder's SObjectType.
Allows for complex child record configuration using fluent Builder API.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `childBuilder` | [TST_Builder.Builder](TST_Builder.Builder.md) | A pre-configured Builder instance for the child records |

**Returns** [TST_Builder.Builder](TST_Builder.Builder.md) — Builder for method chaining

**Example**

```apex
Account account = (Account)TST_Builder.of(Account.SObjectType)
    .withChildren(
        TST_Builder.of(Opportunity.SObjectType)
            .withCount(2)
            .withOverride(Opportunity.Name, 'Big Deal')
            .withOverride(Opportunity.StageName, 'Prospecting')
    )
    .build();
```

</div>

### withCount

<div class="apex-member">

```apex
global TST_Builder.Builder withCount(Integer count)
```

Sets the number of SObject records to create when calling `buildList()`.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `count` | [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) | The number of records to create. |

**Returns** [TST_Builder.Builder](TST_Builder.Builder.md) — This Builder instance for further chaining.

**Example**

```apex
// Build 10 Account records and insert them
List<Account> accounts = (List<Account>)TST_Builder.of(Account.SObjectType)
	.withCount(10)
	.buildList();
Assert.areEqual(10, accounts.size());
```

</div>

### withCycle

<div class="apex-member">

```apex
global TST_Builder.Builder withCycle(SObjectField field, List<Object> values)
```

Assigns a list of values that cycle across records built by `buildList()`.
When more records are built than values provided, the values repeat from the beginning.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `field` | [SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm) | The SObjectField token of the field to cycle. |
| `values` | [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm) | The list of values to cycle through. Must not be null or empty. |

**Returns** [TST_Builder.Builder](TST_Builder.Builder.md) — This Builder instance for further chaining.

**Example**

```apex
List<SObject> foobars = TST_Builder.of(Foobar__c.SObjectType)
    .withCycle(Foobar__c.Picklist__c, new List<Object>{'Alpha', 'Beta', 'Gamma'})
    .withCount(6)
    .withoutInsertion()
    .buildList();
// Alpha, Beta, Gamma, Alpha, Beta, Gamma
```

</div>

<div class="apex-member">

```apex
global TST_Builder.Builder withCycle(String fieldName, List<Object> values)
```

Assigns a list of values that cycle across records built by `buildList()`.
When more records are built than values provided, the values repeat from the beginning.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `fieldName` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The API name of the field to cycle. |
| `values` | [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm) | The list of values to cycle through. Must not be null or empty. |

**Returns** [TST_Builder.Builder](TST_Builder.Builder.md) — This Builder instance for further chaining.

**Example**

```apex
List<SObject> foobars = TST_Builder.of(Foobar__c.SObjectType)
    .withCycle('Picklist__c', new List<Object>{'Alpha', 'Beta', 'Gamma'})
    .withCount(6)
    .withoutInsertion()
    .buildList();
// Alpha, Beta, Gamma, Alpha, Beta, Gamma
```

</div>

### withDefaultedField

<div class="apex-member">

```apex
global TST_Builder.Builder withDefaultedField(SObjectField field)
```

Specifies an optional field to populate with a default value using an SObjectField token.
This provides compile-time checking for field names.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `field` | [SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm) | The SObjectField token of the field. |

**Returns** [TST_Builder.Builder](TST_Builder.Builder.md) — This Builder instance for further chaining.

**Example**

```apex
// Build an Account with type-safe defaulted fields
Account account = (Account)TST_Builder.of(Account.SObjectType)
	.withDefaultedField(Account.Description)
	.withDefaultedField(Account.Industry)
	.withoutInsertion()
	.build();
```

</div>

<div class="apex-member">

```apex
global TST_Builder.Builder withDefaultedField(String fieldName)
```

Specifies an optional field to populate with a default value,
even though it is not marked as required.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `fieldName` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The API name of the field. |

**Returns** [TST_Builder.Builder](TST_Builder.Builder.md) — This Builder instance for further chaining.

**Example**

```apex
// Build an Account with Description field automatically populated
Account account = (Account)TST_Builder.of(Account.SObjectType)
	.withDefaultedField('Description')
	.withDefaultedField('Industry')
	.withoutInsertion()
	.build();
```

</div>

### withDefaultedFields

<div class="apex-member">

```apex
global TST_Builder.Builder withDefaultedFields(List<Object> fields)
```

Specifies a list of optional fields to populate with default values,
even though they are not marked as required.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `fields` | [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm) | A list of fields (SObjectField tokens or String API names). |

**Returns** [TST_Builder.Builder](TST_Builder.Builder.md) — This Builder instance for further chaining.

**Example**

```apex
// Build an Account with optional fields automatically populated
Account account = (Account)TST_Builder.of(Account.SObjectType)
	.withDefaultedFields(new List<Object>{ 'Description', 'Industry', 'Website' })
	.withoutInsertion()
	.build();
```

</div>

### withOptionalField

<div class="apex-member">

```apex
global TST_Builder.Builder withOptionalField(SObjectField field)
```

Specifies a field to treat as optional using an SObjectField token,
preventing the factory from auto-populating it as a required field.
This provides compile-time checking for field names.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `field` | [SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm) | The SObjectField token of the field to mark as optional. |

**Returns** [TST_Builder.Builder](TST_Builder.Builder.md) — This Builder instance for further chaining.

**Example**

```apex
// Build an Account without populating the Name field using type-safe field reference
Account account = (Account)TST_Builder.of(Account.SObjectType)
	.withOptionalField(Account.Name)
	.withoutInsertion()
	.build();
Assert.isNull(account.Name);
```

</div>

<div class="apex-member">

```apex
global TST_Builder.Builder withOptionalField(String fieldName)
```

Specifies a field to treat as optional,
preventing the factory from auto-populating it as a required field.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `fieldName` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The API name of the field to mark as optional. |

**Returns** [TST_Builder.Builder](TST_Builder.Builder.md) — This Builder instance for further chaining.

**Example**

```apex
// Build an Account without populating the Name field (normally required)
Account account = (Account)TST_Builder.of(Account.SObjectType)
	.withOptionalField('Name')
	.withoutInsertion()
	.build();
Assert.isNull(account.Name);
```

</div>

### withOptionalFields

<div class="apex-member">

```apex
global TST_Builder.Builder withOptionalFields(List<Object> fields)
```

Specifies a list of fields to treat as optional,
preventing the factory from auto-populating them as required fields.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `fields` | [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm) | A list of fields (SObjectField tokens or String API names). |

**Returns** [TST_Builder.Builder](TST_Builder.Builder.md) — This Builder instance for further chaining.

**Example**

```apex
// Build an Account without populating multiple normally-required fields
Account account = (Account)TST_Builder.of(Account.SObjectType)
	.withOptionalFields(new List<Object>{ 'Name', Account.Type })
	.withoutInsertion()
	.build();
```

</div>

### withoutInsertion

<div class="apex-member">

```apex
global TST_Builder.Builder withoutInsertion()
```

Configures the build to *not* insert the records into the database.
By default, records are inserted. Use this when you need in-memory records for testing
without DML operations.

**Returns** [TST_Builder.Builder](TST_Builder.Builder.md) — This Builder instance for further chaining.

**Example**

```apex
// Build an Account in memory without inserting it
Account account = (Account)TST_Builder.of(Account.SObjectType)
	.withOverride('Name', 'Test Account')
	.withoutInsertion()
	.build();
Assert.isNull(account.Id);
```

</div>

<div class="apex-member">

```apex
global TST_Builder.Builder withoutInsertion(Boolean withMockIds)
```

Configures the build to *not* insert the records into the database,
with an option to generate mock IDs for the entire object graph.
Use this when you need in-memory records with IDs for query mocking.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `withMockIds` | [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) | If true, generates unique mock IDs for all records in the graph (parents and children). Foreign key fields on children are automatically set to reference their parent's mock ID. |

**Returns** [TST_Builder.Builder](TST_Builder.Builder.md) — This Builder instance for further chaining.

**Example**

```apex
// Build mock Account with Contacts - all with generated IDs
Account mockAccount = (Account)TST_Builder.of(Account.SObjectType)
	.withOverride(Account.Name, 'Mock Account')
	.withChildren(Contact.SObjectType, 3, new Map<SObjectField, Object>{
		Contact.LastName => 'Mock Contact'
	})
	.withoutInsertion(true)
	.build();
Assert.isNotNull(mockAccount.Id, 'Parent should have mock ID');
Assert.areEqual(3, mockAccount.Contacts.size());
Assert.isNotNull(mockAccount.Contacts[0].Id, 'Children should have mock IDs');
Assert.areEqual(mockAccount.Id, mockAccount.Contacts[0].AccountId, 'FK should reference parent');
// Register for query mocking
QRY_Builder.setMock(Account.SObjectType, new List<Account>{mockAccount});
```

</div>

### withOverride

<div class="apex-member">

```apex
global TST_Builder.Builder withOverride(SObjectField field, Object value)
```

Applies a specific field value override using an SObjectField token.
This provides compile-time checking for field names.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `field` | [SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm) | The SObjectField token of the field. |
| `value` | [Object](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_System_Object.htm) | The override value. |

**Returns** [TST_Builder.Builder](TST_Builder.Builder.md) — This Builder instance for further chaining.

**Example**

```apex
// Build an Account with type-safe field overrides
Account account = (Account)TST_Builder.of(Account.SObjectType)
	.withOverride(Account.Name, 'Test Account')
	.withOverride(Account.AnnualRevenue, 1000000)
	.withoutInsertion()
	.build();
```

</div>

<div class="apex-member">

```apex
global TST_Builder.Builder withOverride(String fieldName, Object value)
```

Applies a specific field value override.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `fieldName` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The API name of the field. |
| `value` | [Object](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_System_Object.htm) | The override value. |

**Returns** [TST_Builder.Builder](TST_Builder.Builder.md) — This Builder instance for further chaining.

**Example**

```apex
// Build an Account with a single field override
Account account = (Account)TST_Builder.of(Account.SObjectType)
	.withOverride('Name', 'Test Account')
	.withOverride('Phone', '555-9999')
	.withoutInsertion()
	.build();
```

</div>

### withOverrides

<div class="apex-member">

```apex
global TST_Builder.Builder withOverrides(Map<SObjectField, Object> overrides)
```

Applies a map of specific field values using SObjectField tokens, overriding defaults.
This provides compile-time checking for field names.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `overrides` | [Map](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_map.htm) | A map of SObjectField tokens to their override values. |

**Returns** [TST_Builder.Builder](TST_Builder.Builder.md) — This Builder instance for further chaining.

**Example**

```apex
Account account = (Account)TST_Builder.of(Account.SObjectType)
.withOverrides(new Map<SObjectField, Object>
   {
		Account.Name => 'Token Account',
		Account.Phone => '111-222-3333'
	})
.withoutInsertion()
.build();
```

</div>

<div class="apex-member">

```apex
global TST_Builder.Builder withOverrides(Map<String, Object> overrides)
```

Applies a map of specific field values, overriding defaults.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `overrides` | [Map](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_map.htm) | A map of field names to their override values. |

**Returns** [TST_Builder.Builder](TST_Builder.Builder.md) — This Builder instance for further chaining.

**Example**

```apex
// Build an Account with multiple field overrides
Account account = (Account)TST_Builder.of(Account.SObjectType)
	.withOverrides(new Map<String, Object>
	{
		'Name' => 'Acme Corp',
		'Phone' => '555-1234',
		'Industry' => 'Technology'
	})
	.withoutInsertion()
	.build();
```

</div>

### withRecordType

<div class="apex-member">

```apex
global TST_Builder.Builder withRecordType(String recordTypeDeveloperName)
```

Sets the Record Type for the SObject(s) to be built, using the Record Type's DeveloperName.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `recordTypeDeveloperName` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The DeveloperName of the Record Type. |

**Returns** [TST_Builder.Builder](TST_Builder.Builder.md) — This Builder instance for further chaining.

**Throws**

| Exception | Description |
|-----------|-------------|
| [IllegalArgumentException](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_classes_exception_methods.htm) | if the Record Type DeveloperName is not found; ignores blank DeveloperName's |

**Example**

```apex
// Build an Account with a specific record type
Account account = (Account)TST_Builder.of(Account.SObjectType)
	.withRecordType('Enterprise_Account')
	.withOverride('Name', 'Enterprise Corp')
	.withoutInsertion()
	.build();
```

</div>

