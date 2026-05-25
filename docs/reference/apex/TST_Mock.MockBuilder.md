---
title: "TST_Mock.MockBuilder"
type: class
description: "Fluent builder wrapper that delegates to TST_Builder.Builder for record construction and auto-registers built records with TST_Mock."
since: "1.0"
category: apex
---

# TST_Mock.MockBuilder

**Class**

```apex
global inherited sharing class TST_Mock.MockBuilder
```

Fluent builder wrapper that delegates to TST_Builder.Builder for record construction and auto-registers built records with TST_Mock.

**Since:** 1.0

---

## Methods

| Method | Description |
|--------|-------------|
| global [SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm) [build](#build)() | Builds a single mock record with a mock ID and registers it with TST_Mock for query interception. |
| global [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm) [buildList](#buildlist)() | Builds a list of mock records with mock IDs and registers them with TST_Mock for query interception. |
| global [TST_Mock.MockBuilder](TST_Mock.MockBuilder.md) [withChildren](#withchildren)([SObjectType](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectType.htm) childType, [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) count) | Adds child records to the parent mock without field overrides. |
| global [TST_Mock.MockBuilder](TST_Mock.MockBuilder.md) [withChildren](#withchildren)([SObjectType](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectType.htm) childType, [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) count, [Map](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_map.htm)<[SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm), [Object](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_System_Object.htm)> overrides) | Adds child records to the parent mock using SObjectField token overrides. |
| global [TST_Mock.MockBuilder](TST_Mock.MockBuilder.md) [withChildren](#withchildren)([SObjectType](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectType.htm) childType, [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) count, [Map](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_map.htm)<[String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm), [Object](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_System_Object.htm)> overrides) | Adds child records to the parent mock using String field name overrides. |
| global [TST_Mock.MockBuilder](TST_Mock.MockBuilder.md) [withChildren](#withchildren)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) relationshipName, [TST_Builder.Builder](TST_Builder.Builder.md) childBuilder) | Adds child records using a pre-configured TST_Builder.Builder with an explicit relationship name. |
| global [TST_Mock.MockBuilder](TST_Mock.MockBuilder.md) [withChildren](#withchildren)([TST_Builder.Builder](TST_Builder.Builder.md) childBuilder) | Adds child records using a pre-configured TST_Builder.Builder with auto-detected relationship name. |
| global [TST_Mock.MockBuilder](TST_Mock.MockBuilder.md) [withCount](#withcount)([Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) count) | Sets the number of mock records to build. |
| global [TST_Mock.MockBuilder](TST_Mock.MockBuilder.md) [withCycle](#withcycle)([SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm) field, [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[Object](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_System_Object.htm)> values) | Assigns a list of values that cycle across mock records built by buildList(). |
| global [TST_Mock.MockBuilder](TST_Mock.MockBuilder.md) [withCycle](#withcycle)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) fieldName, [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[Object](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_System_Object.htm)> values) | Assigns a list of values that cycle across mock records built by buildList(). |
| global [TST_Mock.MockBuilder](TST_Mock.MockBuilder.md) [withDefaultedField](#withdefaultedfield)([SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm) field) | Specifies a single field to populate with a default value using an SObjectField token. |
| global [TST_Mock.MockBuilder](TST_Mock.MockBuilder.md) [withDefaultedField](#withdefaultedfield)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) fieldName) | Specifies a single field to populate with a default value using a String name. |
| global [TST_Mock.MockBuilder](TST_Mock.MockBuilder.md) [withDefaultedFields](#withdefaultedfields)([List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[Object](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_System_Object.htm)> fields) | Specifies fields to populate with default values, even if not required. |
| global [TST_Mock.MockBuilder](TST_Mock.MockBuilder.md) [withOptionalField](#withoptionalfield)([SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm) field) | Specifies a field to treat as optional using an SObjectField token. |
| global [TST_Mock.MockBuilder](TST_Mock.MockBuilder.md) [withOptionalField](#withoptionalfield)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) fieldName) | Specifies a field to treat as optional using a String name. |
| global [TST_Mock.MockBuilder](TST_Mock.MockBuilder.md) [withOptionalFields](#withoptionalfields)([List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[Object](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_System_Object.htm)> fields) | Specifies fields to treat as optional, preventing auto-population. |
| global [TST_Mock.MockBuilder](TST_Mock.MockBuilder.md) [withOverride](#withoverride)([SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm) field, [Object](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_System_Object.htm) value) | Sets a single field value override for the mock records. |
| global [TST_Mock.MockBuilder](TST_Mock.MockBuilder.md) [withOverride](#withoverride)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) fieldName, [Object](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_System_Object.htm) value) | Sets a single field value override using a String field name. |
| global [TST_Mock.MockBuilder](TST_Mock.MockBuilder.md) [withOverrides](#withoverrides)([Map](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_map.htm)<[SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm), [Object](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_System_Object.htm)> fieldOverrides) | Sets field value overrides for the mock records. |
| global [TST_Mock.MockBuilder](TST_Mock.MockBuilder.md) [withOverrides](#withoverrides)([Map](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_map.htm)<[String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm), [Object](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_System_Object.htm)> overrides) | Sets field value overrides using String field names. |
| global [TST_Mock.MockBuilder](TST_Mock.MockBuilder.md) [withRecordType](#withrecordtype)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) recordTypeDeveloperName) | Sets the Record Type for the mock records using the Record Type's DeveloperName. |

---

## Method Details

### build

```apex
global SObject build()
```

Builds a single mock record with a mock ID and registers it with TST_Mock
for query interception.

**Returns:** [SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm) - The built mock SObject record.

**Since:** 1.0

**Example:**

```apex
Foobar__c mock = (Foobar__c)TST_Mock.of(Foobar__c.SObjectType).build();
```

### buildList

```apex
global List<SObject> buildList()
```

Builds a list of mock records with mock IDs and registers them with TST_Mock
for query interception.

**Returns:** [SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm) - The list of built mock SObject records.

**Since:** 1.0

**Example:**

```apex
List<SObject> mocks = TST_Mock.of(Foobar__c.SObjectType)
    .withCount(3)
    .buildList();
```

### withChildren

```apex
global TST_Mock.MockBuilder withChildren(SObjectType childType, Integer count)
```

Adds child records to the parent mock without field overrides.

**Parameters:**

- `childType` ([SObjectType](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectType.htm)) - The SObjectType of the child records.
- `count` ([Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm)) - Number of child records to create.

**Returns:** [TST_Mock.MockBuilder](TST_Mock.MockBuilder.md) - This MockBuilder instance for method chaining.

**Since:** 1.0

**Example:**

```apex
Account mock = (Account)TST_Mock.of(Account.SObjectType)
    .withChildren(Contact.SObjectType, 3)
    .build();
```

### withChildren

```apex
global TST_Mock.MockBuilder withChildren(SObjectType childType, Integer count, Map<SObjectField, Object> overrides)
```

Adds child records to the parent mock using SObjectField token overrides.

**Parameters:**

- `childType` ([SObjectType](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectType.htm)) - The SObjectType of the child records.
- `count` ([Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm)) - Number of child records to create.
- `overrides` ([Map](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_map.htm)) - Field overrides for child records using SObjectField tokens.

**Returns:** [TST_Mock.MockBuilder](TST_Mock.MockBuilder.md) - This MockBuilder instance for method chaining.

**Since:** 1.0

**Example:**

```apex
Account mock = (Account)TST_Mock.of(Account.SObjectType)
    .withChildren(Contact.SObjectType, 3, new Map<SObjectField, Object>{
        Contact.LastName => 'Doe'
    })
    .build();
```

### withChildren

```apex
global TST_Mock.MockBuilder withChildren(SObjectType childType, Integer count, Map<String, Object> overrides)
```

Adds child records to the parent mock using String field name overrides.

**Parameters:**

- `childType` ([SObjectType](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectType.htm)) - The SObjectType of the child records.
- `count` ([Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm)) - Number of child records to create.
- `overrides` ([Map](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_map.htm)) - Field overrides for child records using String field names.

**Returns:** [TST_Mock.MockBuilder](TST_Mock.MockBuilder.md) - This MockBuilder instance for method chaining.

**Since:** 1.0

**Example:**

```apex
Account mock = (Account)TST_Mock.of(Account.SObjectType)
    .withChildren(Contact.SObjectType, 2, new Map<String, Object>{
        'LastName' => 'Smith'
    })
    .build();
```

### withChildren

```apex
global TST_Mock.MockBuilder withChildren(String relationshipName, TST_Builder.Builder childBuilder)
```

Adds child records using a pre-configured TST_Builder.Builder with
an explicit relationship name. Use when multiple relationships exist between
the same parent and child types.

**Parameters:**

- `relationshipName` ([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)) - The child relationship name (e.g., 'Contacts').
- `childBuilder` ([TST_Builder.Builder](TST_Builder.Builder.md)) - A pre-configured Builder instance for the child records.

**Returns:** [TST_Mock.MockBuilder](TST_Mock.MockBuilder.md) - This MockBuilder instance for method chaining.

**Since:** 1.0

**Example:**

```apex
Foobar__c mock = (Foobar__c)TST_Mock.of(Foobar__c.SObjectType)
    .withChildren('PrimaryContacts__r',
        TST_Builder.of(Contact.SObjectType).withCount(2)
    )
    .build();
```

### withChildren

```apex
global TST_Mock.MockBuilder withChildren(TST_Builder.Builder childBuilder)
```

Adds child records using a pre-configured TST_Builder.Builder with
auto-detected relationship name.

**Parameters:**

- `childBuilder` ([TST_Builder.Builder](TST_Builder.Builder.md)) - A pre-configured Builder instance for the child records.

**Returns:** [TST_Mock.MockBuilder](TST_Mock.MockBuilder.md) - This MockBuilder instance for method chaining.

**Since:** 1.0

**Example:**

```apex
Account mock = (Account)TST_Mock.of(Account.SObjectType)
    .withChildren(
        TST_Builder.of(Contact.SObjectType)
            .withCount(2)
            .withOverride(Contact.LastName, 'Doe')
    )
    .build();
```

### withCount

```apex
global TST_Mock.MockBuilder withCount(Integer count)
```

Sets the number of mock records to build.

**Parameters:**

- `count` ([Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm)) - The number of records to create.

**Returns:** [TST_Mock.MockBuilder](TST_Mock.MockBuilder.md) - This MockBuilder instance for method chaining.

**Since:** 1.0

**Example:**

```apex
List<SObject> mocks = TST_Mock.of(Foobar__c.SObjectType)
    .withCount(5)
    .buildList();
```

### withCycle

```apex
global TST_Mock.MockBuilder withCycle(SObjectField field, List<Object> values)
```

Assigns a list of values that cycle across mock records built by `buildList()`.
When more records are built than values provided, the values repeat from the beginning.

**Parameters:**

- `field` ([SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm)) - The SObjectField token of the field to cycle.
- `values` ([List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)) - The list of values to cycle through. Must not be null or empty.

**Returns:** [TST_Mock.MockBuilder](TST_Mock.MockBuilder.md) - This MockBuilder instance for method chaining.

**Since:** 1.0

**Example:**

```apex
List<SObject> mocks = TST_Mock.of(Foobar__c.SObjectType)
    .withCycle(Foobar__c.Picklist__c, new List<Object>{'Alpha', 'Beta', 'Gamma'})
    .withCount(6)
    .buildList();
```

### withCycle

```apex
global TST_Mock.MockBuilder withCycle(String fieldName, List<Object> values)
```

Assigns a list of values that cycle across mock records built by `buildList()`.
When more records are built than values provided, the values repeat from the beginning.

**Parameters:**

- `fieldName` ([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)) - The API name of the field to cycle.
- `values` ([List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)) - The list of values to cycle through. Must not be null or empty.

**Returns:** [TST_Mock.MockBuilder](TST_Mock.MockBuilder.md) - This MockBuilder instance for method chaining.

**Since:** 1.0

**Example:**

```apex
List<SObject> mocks = TST_Mock.of(Foobar__c.SObjectType)
    .withCycle('Picklist__c', new List<Object>{'Alpha', 'Beta', 'Gamma'})
    .withCount(6)
    .buildList();
```

### withDefaultedField

```apex
global TST_Mock.MockBuilder withDefaultedField(SObjectField field)
```

Specifies a single field to populate with a default value using an SObjectField token.

**Parameters:**

- `field` ([SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm)) - The SObjectField token of the field.

**Returns:** [TST_Mock.MockBuilder](TST_Mock.MockBuilder.md) - This MockBuilder instance for method chaining.

**Since:** 1.0

**Example:**

```apex
TST_Mock.of(Account.SObjectType)
    .withDefaultedField(Account.Description)
    .build();
```

### withDefaultedField

```apex
global TST_Mock.MockBuilder withDefaultedField(String fieldName)
```

Specifies a single field to populate with a default value using a String name.

**Parameters:**

- `fieldName` ([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)) - The API name of the field.

**Returns:** [TST_Mock.MockBuilder](TST_Mock.MockBuilder.md) - This MockBuilder instance for method chaining.

**Since:** 1.0

**Example:**

```apex
TST_Mock.of(Foobar__c.SObjectType)
    .withDefaultedField('Description')
    .build();
```

### withDefaultedFields

```apex
global TST_Mock.MockBuilder withDefaultedFields(List<Object> fields)
```

Specifies fields to populate with default values, even if not required.

**Parameters:**

- `fields` ([List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)) - A list of fields (SObjectField tokens or String API names).

**Returns:** [TST_Mock.MockBuilder](TST_Mock.MockBuilder.md) - This MockBuilder instance for method chaining.

**Since:** 1.0

**Example:**

```apex
TST_Mock.of(Account.SObjectType)
    .withDefaultedFields(new List<Object>{ 'Description', Account.Industry })
    .build();
```

### withOptionalField

```apex
global TST_Mock.MockBuilder withOptionalField(SObjectField field)
```

Specifies a field to treat as optional using an SObjectField token.

**Parameters:**

- `field` ([SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm)) - The SObjectField token of the field to mark as optional.

**Returns:** [TST_Mock.MockBuilder](TST_Mock.MockBuilder.md) - This MockBuilder instance for method chaining.

**Since:** 1.0

**Example:**

```apex
TST_Mock.of(Account.SObjectType)
    .withOptionalField(Account.Name)
    .build();
```

### withOptionalField

```apex
global TST_Mock.MockBuilder withOptionalField(String fieldName)
```

Specifies a field to treat as optional using a String name.

**Parameters:**

- `fieldName` ([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)) - The API name of the field to mark as optional.

**Returns:** [TST_Mock.MockBuilder](TST_Mock.MockBuilder.md) - This MockBuilder instance for method chaining.

**Since:** 1.0

**Example:**

```apex
TST_Mock.of(Account.SObjectType)
    .withOptionalField('Name')
    .build();
```

### withOptionalFields

```apex
global TST_Mock.MockBuilder withOptionalFields(List<Object> fields)
```

Specifies fields to treat as optional, preventing auto-population.

**Parameters:**

- `fields` ([List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)) - A list of fields (SObjectField tokens or String API names).

**Returns:** [TST_Mock.MockBuilder](TST_Mock.MockBuilder.md) - This MockBuilder instance for method chaining.

**Since:** 1.0

**Example:**

```apex
TST_Mock.of(Account.SObjectType)
    .withOptionalFields(new List<Object>{ 'Name', Account.Type })
    .build();
```

### withOverride

```apex
global TST_Mock.MockBuilder withOverride(SObjectField field, Object value)
```

Sets a single field value override for the mock records.

**Parameters:**

- `field` ([SObjectField](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectField.htm)) - The SObject field to override.
- `value` ([Object](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_System_Object.htm)) - The value to set.

**Returns:** [TST_Mock.MockBuilder](TST_Mock.MockBuilder.md) - This MockBuilder instance for method chaining.

**Since:** 1.0

**Example:**

```apex
TST_Mock.of(Foobar__c.SObjectType)
    .withOverride(Foobar__c.Name, 'Test')
    .build();
```

### withOverride

```apex
global TST_Mock.MockBuilder withOverride(String fieldName, Object value)
```

Sets a single field value override using a String field name. Supports
relationship traversal paths like 'Account.Name'.

**Parameters:**

- `fieldName` ([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)) - The API name of the field.
- `value` ([Object](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_System_Object.htm)) - The value to set.

**Returns:** [TST_Mock.MockBuilder](TST_Mock.MockBuilder.md) - This MockBuilder instance for method chaining.

**Since:** 1.0

**Example:**

```apex
TST_Mock.of(Foobar__c.SObjectType)
    .withOverride('Name', 'Test')
    .build();
```

### withOverrides

```apex
global TST_Mock.MockBuilder withOverrides(Map<SObjectField, Object> fieldOverrides)
```

Sets field value overrides for the mock records.

**Parameters:**

- `fieldOverrides` ([Map](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_map.htm)) - Map of SObjectField to override values.

**Returns:** [TST_Mock.MockBuilder](TST_Mock.MockBuilder.md) - This MockBuilder instance for method chaining.

**Since:** 1.0

**Example:**

```apex
TST_Mock.of(Foobar__c.SObjectType)
    .withOverrides(new Map<SObjectField, Object>{ Foobar__c.Name => 'Test' })
    .build();
```

### withOverrides

```apex
global TST_Mock.MockBuilder withOverrides(Map<String, Object> overrides)
```

Sets field value overrides using String field names. Supports relationship
traversal paths like 'Account.Name'.

**Parameters:**

- `overrides` ([Map](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_map.htm)) - Map of field API names to override values.

**Returns:** [TST_Mock.MockBuilder](TST_Mock.MockBuilder.md) - This MockBuilder instance for method chaining.

**Since:** 1.0

**Example:**

```apex
TST_Mock.of(Foobar__c.SObjectType)
    .withOverrides(new Map<String, Object>{ 'Name' => 'Test', 'Account.Name' => 'Parent' })
    .build();
```

### withRecordType

```apex
global TST_Mock.MockBuilder withRecordType(String recordTypeDeveloperName)
```

Sets the Record Type for the mock records using the Record Type's DeveloperName.

**Parameters:**

- `recordTypeDeveloperName` ([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)) - The DeveloperName of the Record Type.

**Returns:** [TST_Mock.MockBuilder](TST_Mock.MockBuilder.md) - This MockBuilder instance for method chaining.

**Since:** 1.0

**Example:**

```apex
TST_Mock.of(Account.SObjectType)
    .withRecordType('Enterprise_Account')
    .build();
```

