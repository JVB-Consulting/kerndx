# DTOs - Guide

**Framework:** KernDX
**Package Type:** Managed Package (namespace-agnostic)
**Version:** 1.0
**Last Updated:** April 2026

> **Note for Subscriber Orgs:** When using KernDX as a managed package, prefix framework class references with your installed namespace (e.g., `AcmeLib.DTO_JsonBase` for Acme Inc.).

---

## Table of Contents

<details>
<summary>Expand</summary>

1. [Quick Navigation](#quick-navigation)
2. [Overview](#overview)
   - [Key Benefits](#key-benefits)
   - [DTO Framework Components](#dto-framework-components)
3. [Architecture](#architecture)
   - [DTO Class Hierarchy](#dto-class-hierarchy)
4. [Quick Start](#quick-start)
5. [When to Use DTOs](#when-to-use-dtos)
   - [Use DTOs When:](#use-dtos-when)
   - [Don't Use DTOs When:](#dont-use-dtos-when)
6. [Working with Base DTO Classes](#working-with-base-dto-classes)
   - [DTO_Base - Foundation](#dto_base---foundation)
   - [DTO_JsonBase - JSON Handling](#dto_jsonbase---json-handling)
7. [Built-in DTO Classes](#built-in-dto-classes)
   - [DTO_NameValue](#dto_namevalue)
   - [DTO_NameValues](#dto_namevalues)
     - [DTO_NameValues Properties](#dto_namevalues-properties)
     - [DTO_NameValues Methods](#dto_namevalues-methods)
   - [DTO_BaseTable](#dto_basetable)
     - [Lightning Datatable Column Types](#lightning-datatable-column-types)
     - [LWC Usage](#lwc-usage)
   - [DTO_PickList](#dto_picklist)
8. [Creating Custom DTO Classes](#creating-custom-dto-classes)
   - [Creating JSON DTOs](#creating-json-dtos)
   - [Type Resolution: CRITICAL Requirement for Subscriber Orgs](#type-resolution-critical-requirement-for-subscriber-orgs)
     - [Type Resolution Option 3: Custom Type Resolver (RECOMMENDED)](#type-resolution-option-3-custom-type-resolver-recommended)
   - [Implementing populate() Methods](#implementing-populate-methods)
   - [Implementing transform() Methods](#implementing-transform-methods)
9. [Advanced DTO Patterns](#advanced-dto-patterns)
   - [JsonPath for Reflective Access](#jsonpath-for-reflective-access)
   - [Sorting DTOs with FieldComparator](#sorting-dtos-with-fieldcomparator)
   - [DTO Collections and Equality](#dto-collections-and-equality)
10. [Integration Patterns](#integration-patterns)
    - [DTOs in REST APIs](#dtos-in-rest-apis)
    - [DTOs in LWC Components](#dtos-in-lwc-components)
      - [Passing Complex DTOs as @AuraEnabled Parameters](#passing-complex-dtos-as-auraenabled-parameters)
    - [DTOs in Flow Invocables](#dtos-in-flow-invocables)
11. [Testing](#testing)
12. [Anti-Patterns](#anti-patterns)
13. [Best Practices](#best-practices)
    - [1. Use Appropriate DTO Type](#1-use-appropriate-dto-type)
    - [2. Implement getObjectType() for Private Classes (OR Use Type Resolver)](#2-implement-getobjecttype-for-private-classes-or-use-type-resolver)
    - [3. Use @AuraEnabled for LWC](#3-use-auraenabled-for-lwc)
    - [4. Initialize Collections](#4-initialize-collections)
    - [5. Handle Null Values](#5-handle-null-values)
    - [6. Use Clear Naming](#6-use-clear-naming)
    - [7. Document Complex DTOs](#7-document-complex-dtos)
    - [8. Validate DTO Data](#8-validate-dto-data)
    - [9. Keep DTOs Focused](#9-keep-dtos-focused)
14. [Troubleshooting](#troubleshooting)
    - [Issue: "Type cannot be deserialized as it is not globally visible" or "System.JSONException: Type cannot be constructed"](#issue-type-cannot-be-deserialized-as-it-is-not-globally-visible-or-systemjsonexception-type-cannot-be-constructed)
    - [Issue: "Unable to deserialize to specified type"](#issue-unable-to-deserialize-to-specified-type)
    - [Issue: "Null pointer exception when accessing DTO fields"](#issue-null-pointer-exception-when-accessing-dto-fields)
    - [Issue: "DTO fields not visible in LWC"](#issue-dto-fields-not-visible-in-lwc)
15. [Reference](#reference)
    - [DTO Framework Classes](#dto-framework-classes)
    - [Key Methods](#key-methods)
16. [Related Documentation](#related-documentation)

</details>

---

## Quick Navigation

| I am a...     | I need to...                      | Go to...                                                                     |
|---------------|-----------------------------------|------------------------------------------------------------------------------|
| **Architect** | Understand DTO architecture       | [Architecture](#architecture)                                                |
| **Architect** | Choose integration patterns       | [Integration Patterns](#integration-patterns)                                |
| **Developer** | Create my first DTO               | [Quick Start](#quick-start)                                                  |
| **Developer** | Build custom DTO classes          | [Creating Custom DTO Classes](#creating-custom-dto-classes)                  |
| **Developer** | Implement advanced patterns       | [Advanced DTO Patterns](#advanced-dto-patterns)                              |
| **Analyst**   | Know when to use DTOs             | [When to Use DTOs](#when-to-use-dtos)                                        |

---

## Overview

**Data Transfer Objects (DTOs)** are lightweight objects designed to transfer data between different layers of your application. DTOs provide a structured, type-safe way to serialize and deserialize data for:

- **Web Service Integration** - REST request and response payloads
- **Lightning Web Components** - Structured data from Apex to LWC
- **Flow Integration** - Complex data structures in invocable methods
- **Data Transformation** - Converting between SObjects and external formats
- **Testing** - Creating consistent test data structures

> **DTO Framework Scope:** 13 DTO classes extending `DTO_JsonBase`, supporting JSON serialization, SObject transformation, JsonPath
> navigation, and sorted DTO collections.

> **Responsibilities:** DTOs transport data between layers (Apex to LWC, Apex to external APIs, Flow to Apex). They do not contain business
> logic, perform DML, or query data. Population logic in `populate()` should be limited to mapping fields from selectors and parameters.

### Key Benefits

- **Separation of Concerns** - Decouple external data formats from internal SObject structure
- **Type Safety** - Strongly-typed data structures prevent runtime errors
- **Versioning** - Maintain API contracts without changing SObjects
- **Flexibility** - Transform data between different representations
- **Testability** - Easy to mock and verify in unit tests

### DTO Framework Components

The KernDX framework provides:

1. **Base Classes** - [`DTO_Base`](reference/apex/DTO_Base.md), [`DTO_JsonBase`](reference/apex/DTO_JsonBase.md)
2. **Specialized DTOs** - [`DTO_NameValues`](reference/apex/DTO_NameValues.md), [`DTO_BaseTable`](reference/apex/DTO_BaseTable.md), [`DTO_PickList`](reference/apex/DTO_PickList.md)
3. **Utility Integration** - JsonPath, comparators, serialization helpers

---

## Architecture

The DTO framework follows a layered inheritance model where all DTOs derive from a common abstract base class.
This enables consistent serialization, deserialization, equality, and population behaviour across JSON
formats. The framework sits between your business logic and external consumers (REST APIs, LWC, Flows),
providing a clean separation between internal SObject structures and external data contracts.

The key architectural components are:

- **`DTO_Base`** - Abstract foundation providing `serialize()`, `deserialize()`, `populate()`, `transform()`, `equals()`, and `hashCode()`
- **`DTO_JsonBase`** - JSON-specific implementation with pretty-print serialization, JsonPath integration, and `FieldComparator` sorting
- **Built-in DTOs** - `DTO_NameValues` (key-value parameters), `DTO_BaseTable` (Lightning datatable), `DTO_PickList` (picklist metadata)

### DTO Class Hierarchy

```text
DTO_Base (Abstract base class)
+-- DTO_JsonBase (JSON serialization)
    +-- DTO_NameValues (Key-value collections)
    +-- DTO_BaseTable (Lightning datatable structure)
    +-- [Your custom JSON DTOs]

Standalone DTOs (no inheritance):
+-- DTO_NameValue (Single name-value pair)
+-- DTO_PickList (Picklist metadata)
+-- DTO_PicklistValue (Single picklist value)
```

---

## Quick Start

The most common DTO pattern is creating a JSON DTO for an API integration or LWC response. Here is the simplest path from zero to working DTO:

```apex
@JsonAccess(Serializable='always' Deserializable='always')
public class DTO_OrderSummary extends DTO_JsonBase
{
	@AuraEnabled public String orderId;
	@AuraEnabled public Decimal totalAmount;
}

// Create and serialize
DTO_OrderSummary summary = new DTO_OrderSummary();
summary.orderId = 'ORD-001';
summary.totalAmount = 250.00;
String json = summary.serialize();

// Deserialize from JSON
DTO_OrderSummary parsed = (DTO_OrderSummary)new DTO_OrderSummary().deserialize(json);
```

> **Subscriber Orgs:** Always include `@JsonAccess(Serializable='always' Deserializable='always')` on every DTO that extends a managed package base class — without it, serialization fails at runtime. See [Type Resolution](#type-resolution-critical-requirement-for-subscriber-orgs) for additional requirements.

For deeper coverage, continue reading the sections below.

---

## When to Use DTOs

### Use DTOs When:

**Building REST APIs** - Standardize request/response formats
```apex
// Inbound API with DTO
public with sharing class API_CreateAccount extends API_Inbound
{
	public override void configure()
	{
		super.configure();
		requestPayload = new DTO_AccountRequest();
		responsePayload = new DTO_AccountResponse();
	}
}
```

**Integrating External Systems** - Parse REST responses
```apex
// Parse external API response
DTO_WeatherResponse weather = (DTO_WeatherResponse)
	new DTO_WeatherResponse().deserialize(responseBody);
```

**Returning Complex Data to LWC** - Structure hierarchical data
```apex
@AuraEnabled
public static DTO_BaseTable getAccountData()
{
	DTO_BaseTable table = new DTO_BaseTable();
	// Build table structure...
	return table;
}
```

**Flow Invocable Methods** - Pass complex parameters
```apex
@InvocableMethod
public static List<Results> processData(List<Requests> requests)
{
	// Use DTO_NameValues for flexible parameters
}
```

### Don't Use DTOs When:

**Working Within Apex** - Use SObjects directly
```apex
// BAD: Unnecessary DTO usage
DTO_Account dtoAccount = convertToDto(account);
processAccount(dtoAccount);

// GOOD: Direct SObject usage
processAccount(account);
```

**Simple Data Types** - Use primitives or simple maps
```apex
// BAD: Over-engineering
DTO_StringValue dto = new DTO_StringValue();
dto.value = 'Hello';

// GOOD: Use String directly
String value = 'Hello';
```

**Internal Database Operations** - Use SObjects with DML framework
```apex
// BAD: Converting to DTO for DML
DTO_Account dtoAccount = mapToDto(account);
DML_Builder.newTransaction().doInsert(convertToSObject(dtoAccount)).execute();

// GOOD: Direct SObject DML
DML_Builder.newTransaction().doInsert(account).execute();
```

---

## Working with Base DTO Classes

### [`DTO_Base`](reference/apex/DTO_Base.md) - Foundation

[`DTO_Base`](reference/apex/DTO_Base.md) is the abstract foundation for all DTOs, providing core functionality:

```apex
global abstract class DTO_Base
{
	global virtual String serialize()
	global virtual DTO_Base deserialize(String dtoString)
	global virtual void populate(Id recordId)
	global virtual void populate(Id recordId, DTO_NameValues dtoRequestParameters)
	global virtual void transform(DTO_Base dtoBase)
	public Boolean equals(Object obj)
	public Integer hashCode()
}
```

**Key Methods:**

| Method | Purpose | Override Required |
|--------|---------|-------------------|
| `serialize()` | Convert DTO to string format | Yes (in subclasses) |
| `deserialize()` | Parse string to DTO | Yes (in subclasses) |
| `populate(Id)` | Load DTO from record ID | Optional |
| `transform()` | Convert between DTO types | Optional |
| `equals()` / `hashCode()` | Support collections | No (implemented) |

**Example: Using equals() in Collections**

```apex
Set<DTO_Base> uniqueDtos = new Set<DTO_Base>();
uniqueDtos.add(dto1);
uniqueDtos.add(dto2);
uniqueDtos.add(dto1); // Duplicate ignored

if(dto1.equals(dto2))
{
	// DTOs are equal based on serialized content
}
```

---

### [`DTO_JsonBase`](reference/apex/DTO_JsonBase.md) - JSON Handling

[`DTO_JsonBase`](reference/apex/DTO_JsonBase.md) extends [`DTO_Base`](reference/apex/DTO_Base.md) for [JSON serialization](https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_class_System_Json.htm) with advanced features:

**Key Features:**

1. **Automatic JSON Serialization** - Pretty-print with null suppression
2. **Type-Safe Deserialization** - Automatic type resolution
3. **JsonPath Integration** - Reflective field access via [`UTIL_JsonPath`](reference/apex/UTIL_JsonPath.md) over the serialized DTO
4. **Field Comparator** - Sort DTOs by any field via [`DTO_JsonBase.FieldComparator`](reference/apex/DTO_JsonBase.md)

**Example: Basic JSON DTO**

```apex
public class DTO_Person extends DTO_JsonBase
{
	public String firstName;
	public String lastName;
	public Date birthDate;
	public Decimal salary;

	protected override Type getObjectType()
	{
		return DTO_Person.class;
	}
}

// Usage
DTO_Person person = new DTO_Person();
person.firstName = 'John';
person.lastName = 'Doe';
person.birthDate = Date.today();

// Serialize
String json = person.serialize();
// Output: {"firstName":"John","lastName":"Doe","birthDate":"2026-02-07"}

// Deserialize
DTO_Person deserialized = (DTO_Person)new DTO_Person().deserialize(json);
```

**JsonPath Access:**

```apex
DTO_Person person = new DTO_Person();
person.firstName = 'John';

// Access fields reflectively by serializing through UTIL_JsonPath
UTIL_JsonPath path = new UTIL_JsonPath(person.serialize());
String firstName = path.findNode('firstName').getStringValue();
// firstName: John
```

**Important: Override getObjectType() for Private Classes**

If your DTO class is `private` or not `global`, you **must** override `getObjectType()`:

```apex
// Private DTO class
private class DTO_InternalData extends DTO_JsonBase
{
	public String data;

	// REQUIRED for private classes
	protected override Type getObjectType()
	{
		return DTO_InternalData.class;
	}
}
```

For `global` or `public` classes, this override is optional (auto-resolved).

---

## Built-in DTO Classes

### [`DTO_NameValue`](reference/apex/DTO_NameValue.md)

**Purpose:** Simple DTO for a single name-value pair, designed for use in Flow invocable methods, Aura components, and LWC.

**Common Use Cases:**
- Email template merge fields in Flow
- Parameter passing to invocable methods
- Configuration key-value pairs
- Dynamic field mapping

```apex
/**
 * @description Using DTO_NameValue in an invocable method
 */
@SuppressWarnings('PMD.AvoidGlobalModifier')
global inherited sharing class FLOW_SendEmailWithMergeFields
{
	@InvocableMethod(Category='Email' Label='Send Email with Merge Fields' Description='Sends an email using merge field values.')
	global static void execute(List<DTO_Request> requests)
	{
		if(requests == null || requests.size() != 1)
		{
			throw new IllegalArgumentException('FLOW_SendEmailWithMergeFields expects a single request');
		}
		DTO_Request request = requests.iterator().next();

		for(DTO_NameValue mergeField : request.mergeFields)
		{
			LOG_Builder.build().info('Field: ' + mergeField.name + ' = ' + mergeField.value).emitAt('FLOW_SendEmailWithMergeFields.execute');
		}
	}

	global inherited sharing class DTO_Request
	{
		@InvocableVariable(Label='Template Name' Description='The email template name' Required=true)
		global String templateName;

		@InvocableVariable(Label='Merge Fields' Description='Name-value pairs for merge fields')
		global List<DTO_NameValue> mergeFields;
	}
}
```

**Flow Usage:**

In Flow Builder, [`DTO_NameValue`](reference/apex/DTO_NameValue.md) appears as a structured input allowing users to specify name-value pairs:

| Property | Type | Required | Description |
|----------|------|----------|-------------|
| `name` | String | Yes | The field name or placeholder key |
| `value` | String | No | The value to associate with the name |

**Creating in Apex:**

```apex
// Create a single name-value pair
DTO_NameValue mergeField = new DTO_NameValue();
mergeField.name = 'recipientName';
mergeField.value = 'John Doe';

// Create a list for invocable methods
List<DTO_NameValue> mergeFields = new List<DTO_NameValue>();
mergeFields.add(mergeField);
```

**DTO_NameValue vs DTO_NameValues:**

| Feature | [`DTO_NameValue`](reference/apex/DTO_NameValue.md) | [`DTO_NameValues`](reference/apex/DTO_NameValues.md) |
|---------|-----------------|------------------|
| **Structure** | Single name-value pair | Collection of pairs |
| **Flow Support** | [`@InvocableVariable`](https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_classes_annotation_InvocableVariable.htm) | Not directly invocable |
| **Aura/LWC Support** | [`@AuraEnabled`](https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_classes_annotation_AuraEnabled.htm) | `@AuraEnabled` |
| **Use Case** | Flow inputs, simple params | Complex parameter maps |
| **Inheritance** | Standalone class | Extends [`DTO_JsonBase`](reference/apex/DTO_JsonBase.md) |

---

### [`DTO_NameValues`](reference/apex/DTO_NameValues.md)

**Purpose:** Store and manipulate key-value pairs for parameter passing.

**Common Use Cases:**
- API request parameters
- Dynamic configuration
- Flow variable collections
- Email merge fields

```apex
/**
 * @description Create and use DTO_NameValues
 */
public static void demonstrateNameValues()
{
	// Create from scratch
	DTO_NameValues params = new DTO_NameValues();
	params.add('firstName', 'John');
	params.add('lastName', 'Doe');
	params.add('email', 'john.doe@example.com');

	// Create from delimited string
	DTO_NameValues params2 = new DTO_NameValues('key1=value1,key2=value2');

	// Create from map
	Map<String, String> configMap = new Map<String, String>
	{
		'timeout' => '30000',
		'retryCount' => '3'
	};
	DTO_NameValues config = new DTO_NameValues(configMap);

	// Check existence
	if(params.exists('email'))
	{
		String email = params.get('email');
	}

	// Check multiple required parameters
	Set<String> requiredParams = new Set<String>{'firstName', 'lastName'};
	if(params.allExists(requiredParams, true)) // true = must be non-blank
	{
		// All required parameters present
	}

	// Serialize to JSON
	String json = params.serialize();

	// Convert to parameter string
	String paramString = params.toParameterString();
	// Output: firstName=John,lastName=Doe,email=john.doe@example.com
}
```

#### DTO_NameValues Properties

| Property | Type | Description |
|----------|------|-------------|
| `size` | Integer | Number of name-value pairs |
| `names` | Set&lt;String&gt; | All parameter names |
| `values` | List&lt;String&gt; | All parameter values |

#### DTO_NameValues Methods

| Method | Description |
|--------|-------------|
| `add(String name, String value)` | Add or update a parameter |
| `get(String name)` | Get parameter value (null if not found) |
| `exists(String name)` | Check if parameter exists |
| `exists(String name, Boolean isNonBlank)` | Check existence and optionally validate non-blank |
| `allExists(Set<String> names)` | Check if all parameters exist |
| `isEmpty()` | Check if no parameters exist |
| `toParameterString()` | Convert to "name=value,name=value" format |

---

### [`DTO_BaseTable`](reference/apex/DTO_BaseTable.md)

**Purpose:** Structure data for Lightning datatable components.

**Features:**
- Dynamic column definition via [`DTO_BaseTable.DTO_Column`](reference/apex/DTO_BaseTable.DTO_Column.md)
- Type-safe row data
- Sortable columns
- Lightning datatable compatible

```apex
/**
 * @description Build table data for LWC datatable
 */
@AuraEnabled
public static DTO_BaseTable getAccountTable()
{
	DTO_BaseTable table = new DTO_BaseTable();

	// Define columns (label, fieldName, type, sortable)
	table.addColumn('Account Name', 'name', 'text', true);
	table.addColumn('Industry', 'industry', 'text', true);
	table.addColumn('Annual Revenue', 'revenue', 'currency', true);
	table.addColumn('Website', 'website', 'url', false);
	table.addColumn('Active', 'isActive', 'boolean', false);

	// Add rows (can be any object type)
	List<Account> accounts = QRY_Builder.selectFrom(Account.SObjectType)
		.fields(new List<SObjectField>{Account.Name, Account.Industry, Account.AnnualRevenue, Account.Website})
		.withLimit(10)
		.toList();

	for(Account account : accounts)
	{
		DTO_AccountRow row = new DTO_AccountRow();
		row.name = account.Name;
		row.industry = account.Industry;
		row.revenue = account.AnnualRevenue;
		row.website = account.Website;
		row.isActive = true;

		table.addRow(row);
	}

	return table;
}

/**
 * @description Row DTO for table data
 */
public class DTO_AccountRow
{
	@AuraEnabled
	public String name;
	@AuraEnabled
	public String industry;
	@AuraEnabled
	public Decimal revenue;
	@AuraEnabled
	public String website;
	@AuraEnabled
	public Boolean isActive;
}
```

#### Lightning Datatable Column Types

| Type | Description | Example |
|------|-------------|---------|
| `text` | Plain text | Account Name |
| `number` | Numeric value | 12345 |
| `currency` | Currency formatted | $50,000 |
| `percent` | Percentage | 25% |
| `date` | Date only | 2026-02-07 |
| `date-local` | Date (no timezone) | 2026-02-07 |
| `email` | Email address | user@example.com |
| `phone` | Phone number | (555) 123-4567 |
| `url` | Hyperlink | https://example.com |
| `boolean` | Checkbox | true/false |
| `button` | Button | - |
| `button-icon` | Icon button | - |
| `action` | Row actions | - |

#### LWC Usage

```javascript
// accountTable.js
import { wire } from 'lwc';
import { ComponentBuilder } from 'c/componentBuilder';
import getAccountTable from '@salesforce/apex/AccountController.getAccountTable';

export default class AccountTable extends ComponentBuilder('controller')
{
	tableData;

	@wire(getAccountTable)
	wiredTable({ error, data })
	{
		if(data)
		{
			this.tableData = data;
		}
	}
}
```

```html
<!-- accountTable.html -->
<template>
    <lightning-datatable
        key-field="name"
        data={tableData.rows}
        columns={tableData.columns}
        hide-checkbox-column>
    </lightning-datatable>
</template>
```

---

### [`DTO_PickList`](reference/apex/DTO_PickList.md)

**Purpose:** Represent picklist field metadata for dynamic UI components.

**Structure:**
- **DTO_PickList** - Container for picklist field
  - `picklistName` - Field API name
  - `defaultValue` - Default [`DTO_PicklistValue`](reference/apex/DTO_PicklistValue.md)
  - `values` - List of DTO_PicklistValue objects

- **DTO_PicklistValue** - Individual picklist entry
  - `label` - Display text
  - `value` - API value
  - `validFor` - Controlling field dependencies

**Example: Using with Invocable Method**

```apex
/**
 * @description Get picklist values for Flow
 */
@InvocableMethod(Label='Get Picklist Values' Description='Returns picklist values for a field')
public static List<DTO_PickList> getPicklistValues(List<Request> requests)
{
	List<DTO_PickList> results = new List<DTO_PickList>();

	for(Request req : requests)
	{
		UTIL_SObjectDescribe describe = UTIL_SObjectDescribe.getDescribe(req.objectName);
		Schema.DescribeFieldResult fieldDescribe = describe.getFieldDescribe(req.fieldName);

		DTO_PickList pickList = new DTO_PickList();
		pickList.picklistName = req.fieldName;
		pickList.values = new List<DTO_PicklistValue>();

		for(Schema.PicklistEntry entry : fieldDescribe.getPicklistValues())
		{
			if(entry.isActive())
			{
				DTO_PicklistValue pickValue = new DTO_PicklistValue();
				pickValue.label = entry.getLabel();
				pickValue.value = entry.getValue();

				if(entry.isDefaultValue())
				{
					pickList.defaultValue = pickValue;
				}

				pickList.values.add(pickValue);
			}
		}

		results.add(pickList);
	}

	return results;
}

public class Request
{
	@InvocableVariable(Required=true)
	public String objectName;

	@InvocableVariable(Required=true)
	public String fieldName;
}
```

---

## Creating Custom DTO Classes

### Creating JSON DTOs

**CRITICAL: Managed Package Requirement**

When extending DTOs from a **managed package** (e.g., `DTO_JsonBase`), you **MUST** add the [`@JsonAccess`](https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_classes_annotation_JsonAccess.htm) annotation to your DTO class. This annotation grants the managed package code permission to serialize and deserialize your subscriber org's DTO classes.

**Without `@JsonAccess`, serialization/deserialization will fail with security errors.**

```apex
// CORRECT: @JsonAccess annotation required for managed package DTOs
@JsonAccess(Serializable='always' Deserializable='always')
public class DTO_CustomerOrder extends DTO_JsonBase
{
	// ...
}

// WRONG: Missing @JsonAccess annotation
public class DTO_CustomerOrder extends DTO_JsonBase
{
	// Will fail at runtime when managed package tries to serialize!
}
```

**When to use `@JsonAccess`:**
- `Serializable='always'` - Required when managed package code calls `serialize()` on your DTO
- `Deserializable='always'` - Required when managed package code calls `deserialize()` on your DTO
- Use both when DTOs are used in bidirectional scenarios (request + response)

---

### Type Resolution: CRITICAL Requirement for Subscriber Orgs

**CRITICAL WARNING:** When using KernDX as a managed package, subscriber orgs **MUST** implement type resolution for DTOs. Without this, the managed package cannot dynamically instantiate subscriber org classes, causing runtime failures.

**Where Type Resolution Is Required:**
- DTO Deserialization - `DTO_JsonBase.deserialize()`
- Dynamic Class Instantiation - Framework code using `Type.forName()`
- Polymorphic Collections - Factory patterns and dynamic type creation

**You MUST choose ONE of these three approaches:**

1. **Make all DTOs `global`** - Global classes are always visible to managed package code (simple but exposes classes)
2. **Implement `getObjectType()` in every DTO** - Override method to return the class type (repetitive but explicit)
3. **Register a Type Resolver** (RECOMMENDED) - Automatic type resolution for all classes (flexible and maintainable)

**Without one of these solutions, you will encounter runtime errors:**
```text
System.JSONException: Type cannot be deserialized as it is not globally visible - DTO_CustomerRequest
```

#### Type Resolution Option 3: Custom Type Resolver (RECOMMENDED)

Instead of overriding `getObjectType()` in every DTO or making all classes global, subscriber orgs can register a **custom type resolver** that handles type resolution for all DTOs automatically.

**Benefits:**
- Eliminate repetitive `getObjectType()` overrides in every DTO
- No need to make classes `global` (better encapsulation)
- Centralized type resolution logic
- Easier maintenance and less boilerplate code

**How it works:**

1. **Create a custom type resolver class:**

```apex
/**
 * @description Custom type resolver for subscriber org DTOs
 *
 * @see UTIL_TypeResolver
 */
global with sharing class CustomDTOTypeResolver extends UTIL_TypeResolver.BaseClassResolver
{
	/**
	 * @description Resolves a Type object from a class name
	 *
	 * @param className The name of the class to resolve
	 *
	 * @return Type The resolved Type object or null if not found
	 */
	public override Type resolveType(String className)
	{
		return getTypeForClassName(className) ?? (Type)nextResolver?.resolveType(className);
	}

	/**
	 * @description Resolves the Type for a given class name, handling namespaces and nested classes
	 *
	 * @param className The class name to resolve
	 *
	 * @return The resolved Type object, or null if not found
	 */
	private static Type getTypeForClassName(String className)
	{
		Type classType;

		if(String.isNotBlank(className))
		{
			String namespace = UTIL_System.getNamespacePrefix(
				UTIL_System.getClassNamespace(className),
				UTIL_String.DOT
			);

			classType = Type.forName(namespace, className);
			// Retry without namespace for nested classes (e.g., MyParentClass.MyChildClass)
			classType = classType == null && String.isNotBlank(namespace)
				? Type.forName(UTIL_String.EMPTY, className)
				: classType;
		}

		return classType;
	}
}
```

2. **Register the resolver in custom metadata:**

Create a [`ClassTypeResolver__mdt`](reference/metadata/ClassTypeResolver__mdt.md) record:
- **Label:** Custom DTO Type Resolver
- **DeveloperName:** CustomDTOTypeResolver
- **ClassName__c:** CustomDTOTypeResolver

3. **Simplify your DTOs:**

```apex
// WITH Type Resolver: No getObjectType() override needed!
@JsonAccess(Serializable='always' Deserializable='always')
public class DTO_CustomerOrder extends DTO_JsonBase
{
	@AuraEnabled
	public String orderId;

	@AuraEnabled
	public String customerName;

	// No getObjectType() method needed!
}

// WITHOUT Type Resolver: Must override in every DTO
@JsonAccess(Serializable='always' Deserializable='always')
public class DTO_CustomerOrder extends DTO_JsonBase
{
	@AuraEnabled
	public String orderId;

	protected override Type getObjectType()  // Repetitive boilerplate
	{
		return DTO_CustomerOrder.class;
	}
}
```

**When to use Type Resolver:**
- Subscriber orgs with many custom DTOs (reduces boilerplate)
- Teams wanting centralized type resolution logic
- Complex namespace scenarios

**When to override `getObjectType()`:**
- Single DTO or small number of DTOs
- Private inner classes requiring specific resolution
- No custom metadata configuration desired

---

**Step 1: Define DTO Structure**

```apex
/**
 * @description Custom DTO for complex data structure
 *
 * IMPORTANT: @JsonAccess required because this extends managed package class DTO_JsonBase
 */
@JsonAccess(Serializable='always' Deserializable='always')
public class DTO_CustomerOrder extends DTO_JsonBase
{
	@AuraEnabled
	public String orderId;

	@AuraEnabled
	public String customerName;

	@AuraEnabled
	public Date orderDate;

	@AuraEnabled
	public Decimal totalAmount;

	@AuraEnabled
	public String status;

	@AuraEnabled
	public DTO_Address shippingAddress;

	@AuraEnabled
	public List<DTO_OrderItem> lineItems;

	/**
	 * @description Constructor initializes collections
	 */
	public DTO_CustomerOrder()
	{
		lineItems = new List<DTO_OrderItem>();
	}

	/**
	 * @description Required for deserialization of private classes
	 *
	 * NOTE: This override is only required if your DTO class is private/not globally visible.
	 * If you register a custom type resolver via UTIL_TypeResolver and ClassTypeResolver__mdt,
	 * you can skip implementing this method in all your DTOs.
	 *
	 * @see UTIL_TypeResolver
	 * @see ClassTypeResolver__mdt
	 */
	protected override Type getObjectType()
	{
		return DTO_CustomerOrder.class;
	}
}

/**
 * @description Nested DTO for address
 *
 * IMPORTANT: @JsonAccess required for ALL nested DTOs extending managed package classes
 *
 * NOTE: getObjectType() override optional if custom type resolver registered in ClassTypeResolver__mdt
 */
@JsonAccess(Serializable='always' Deserializable='always')
public class DTO_Address extends DTO_JsonBase
{
	@AuraEnabled
	public String street;

	@AuraEnabled
	public String city;

	@AuraEnabled
	public String state;

	@AuraEnabled
	public String postalCode;

	protected override Type getObjectType()
	{
		return DTO_Address.class;
	}
}

/**
 * @description Nested DTO for line items
 *
 * IMPORTANT: @JsonAccess required for ALL nested DTOs extending managed package classes
 *
 * NOTE: getObjectType() override optional if custom type resolver registered in ClassTypeResolver__mdt
 */
@JsonAccess(Serializable='always' Deserializable='always')
public class DTO_OrderItem extends DTO_JsonBase
{
	@AuraEnabled
	public String productName;

	@AuraEnabled
	public Integer quantity;

	@AuraEnabled
	public Decimal unitPrice;

	@AuraEnabled
	public Decimal totalPrice;

	protected override Type getObjectType()
	{
		return DTO_OrderItem.class;
	}
}
```

**Step 2: Use the DTO**

```apex
// Create DTO
DTO_CustomerOrder order = new DTO_CustomerOrder();
order.orderId = 'ORD-12345';
order.customerName = 'John Doe';
order.orderDate = Date.today();
order.status = 'Processing';

// Add shipping address
DTO_Address address = new DTO_Address();
address.street = '123 Main St';
address.city = 'San Francisco';
address.state = 'CA';
address.postalCode = '94105';
order.shippingAddress = address;

// Add line items
DTO_OrderItem item1 = new DTO_OrderItem();
item1.productName = 'Widget A';
item1.quantity = 2;
item1.unitPrice = 25.00;
item1.totalPrice = 50.00;
order.lineItems.add(item1);

DTO_OrderItem item2 = new DTO_OrderItem();
item2.productName = 'Widget B';
item2.quantity = 1;
item2.unitPrice = 75.00;
item2.totalPrice = 75.00;
order.lineItems.add(item2);

order.totalAmount = 125.00;

// Serialize
String json = order.serialize();

// Deserialize
DTO_CustomerOrder parsedOrder = (DTO_CustomerOrder)
	new DTO_CustomerOrder().deserialize(json);
```

---

### Implementing populate() Methods

The `populate()` method loads DTO data from a Salesforce record ID.

**Use Case:** Lazy-load DTO data from database.

**CRITICAL:** populate() methods **MUST use [SEL_Base](reference/apex/SEL_Base.md) selectors or [QRY_Builder](reference/apex/QRY_Builder.md)**, not inline SOQL. This ensures:
- Centralized field management
- Reusable query logic
- Easier testing and mocking
- Bulk-safe patterns
- Framework convention compliance

```apex
/**
 * @description Account DTO with populate implementation
 */
@JsonAccess(Serializable='always' Deserializable='always')
public class DTO_Account extends DTO_JsonBase
{
	public String accountName;
	public String industry;
	public Decimal annualRevenue;
	public Integer employeeCount;
	public List<DTO_Contact> contacts;

	public DTO_Account()
	{
		contacts = new List<DTO_Contact>();
	}

	/**
	 * @description Populate DTO from Account ID
	 *
	 * @param recordId The Account record ID
	 */
	global override void populate(Id recordId)
	{
		populate(recordId, null);
	}

	/**
	 * @description Populate with optional parameters
	 *
	 * @param recordId The Account record ID
	 * @param dtoRequestParameters Optional parameters controlling population behavior
	 */
	global override void populate(Id recordId, DTO_NameValues dtoRequestParameters)
	{
		// CORRECT: Use SEL_* selector pattern
		Account account = (Account)new SEL_Accounts().findById(recordId);

		if(account == null)
		{
			LOG_Builder.build()
				.error('Account not found: ' + recordId)
				.emitAt('DTO_Account.populate');
			return;
		}

		// Populate fields
		this.accountName = account.Name;
		this.industry = account.Industry;
		this.annualRevenue = account.AnnualRevenue;
		this.employeeCount = account.NumberOfEmployees;

		// Check optional parameters
		Boolean includeContacts = true;
		if(dtoRequestParameters != null && dtoRequestParameters.exists('includeContacts'))
		{
			includeContacts = Boolean.valueOf(dtoRequestParameters.get('includeContacts'));
		}

		// Populate related contacts
		if(includeContacts && account.Contacts != null)
		{
			for(Contact contact : account.Contacts)
			{
				DTO_Contact contactDto = new DTO_Contact();
				contactDto.firstName = contact.FirstName;
				contactDto.lastName = contact.LastName;
				contactDto.email = contact.Email;
				this.contacts.add(contactDto);
			}
		}
	}
}

// Usage
DTO_Account accountDto = new DTO_Account();
accountDto.populate(accountId);

// With parameters
DTO_NameValues params = new DTO_NameValues();
params.add('includeContacts', 'false');
accountDto.populate(accountId, params);
```

---

### Implementing transform() Methods

The `transform()` method converts between different DTO formats.

**Use Case:** Transform internal DTO to external API format.

```apex
/**
 * @description Internal Account DTO
 */
public class DTO_AccountInternal extends DTO_JsonBase
{
	public String name;
	public String industryCode;
	public Decimal revenue;

	protected override Type getObjectType()
	{
		return DTO_AccountInternal.class;
	}
}

/**
 * @description External API Account DTO
 */
public class DTO_AccountExternal extends DTO_JsonBase
{
	public String companyName;
	public String industry;
	public String revenueCategory;

	/**
	 * @description Transform internal DTO to external format
	 */
	global override void transform(DTO_Base dtoBase)
	{
		if(dtoBase instanceof DTO_AccountInternal)
		{
			DTO_AccountInternal internal = (DTO_AccountInternal)dtoBase;

			// Map fields
			this.companyName = internal.name;

			// Transform industry code to readable name
			this.industry = getIndustryName(internal.industryCode);

			// Categorize revenue
			this.revenueCategory = categorizeRevenue(internal.revenue);
		}
	}

	private String getIndustryName(String code)
	{
		Map<String, String> industryMap = new Map<String, String>
		{
			'TECH' => 'Technology',
			'FIN' => 'Financial Services',
			'HEALTH' => 'Healthcare'
		};
		return industryMap.get(code);
	}

	private String categorizeRevenue(Decimal revenue)
	{
		if(revenue == null) return 'Unknown';
		if(revenue < 1000000) return 'Small';
		if(revenue < 10000000) return 'Medium';
		return 'Large';
	}

	protected override Type getObjectType()
	{
		return DTO_AccountExternal.class;
	}
}

// Usage
DTO_AccountInternal internalDto = new DTO_AccountInternal();
internalDto.name = 'Acme Corp';
internalDto.industryCode = 'TECH';
internalDto.revenue = 5000000;

DTO_AccountExternal externalDto = new DTO_AccountExternal();
externalDto.transform(internalDto);

// externalDto.companyName: Acme Corp
// externalDto.industry: Technology
// externalDto.revenueCategory: Medium
```

---

## Advanced DTO Patterns

### JsonPath for Reflective Access

Use [`UTIL_JsonPath`](reference/apex/UTIL_JsonPath.md) over a serialized DTO to access fields dynamically. Each node exposes
typed getters (`getStringValue()`, `getIntegerValue()`, `getDecimalValue()`, `getBooleanValue()`, `getDateValue()`,
`getDatetimeValue()`, `getIdValue()`) — there is no untyped `getValue()`.

```apex
/**
 * @description Demonstrate JsonPath usage
 */
public static void demonstrateJsonPath()
{
	DTO_CustomerOrder order = new DTO_CustomerOrder();
	order.orderId = 'ORD-12345';
	order.customerName = 'John Doe';
	order.totalAmount = 125.00;

	DTO_OrderItem item = new DTO_OrderItem();
	item.productName = 'Widget A';
	item.quantity = 2;
	item.unitPrice = 25.00;
	order.lineItems.add(item);

	// Wrap the serialized DTO in UTIL_JsonPath for path-based reads
	UTIL_JsonPath path = new UTIL_JsonPath(order.serialize());

	// Access fields by path (use the typed getter that matches the underlying field)
	String orderId = path.findNode('orderId').getStringValue();
	// orderId: ORD-12345

	// Access nested fields
	String productName = path.findNode('lineItems[0].productName').getStringValue();
	// productName: Widget A

	// Check field existence
	if(path.exists('totalAmount'))
	{
		Decimal total = path.findNode('totalAmount').getDecimalValue();
	}
}
```

**Common JsonPath Patterns:**

| Pattern | Description | Example |
|---------|-------------|---------|
| `fieldName` | Top-level field | `path.findNode('orderId')` |
| `parent.child` | Nested object | `path.findNode('shippingAddress.city')` |
| `array[0]` | Array index | `path.findNode('lineItems[0]')` |
| `array[0].field` | Array element field | `path.findNode('lineItems[0].productName')` |

---

### Sorting DTOs with FieldComparator

Sort DTO collections by any field using [`DTO_JsonBase.FieldComparator`](reference/apex/DTO_JsonBase.md).

```apex
/**
 * @description Sort DTOs by field values
 */
public static void demonstrateSorting()
{
	List<DTO_CustomerOrder> orders = new List<DTO_CustomerOrder>();

	// Create sample orders
	for(Integer i = 0; i < 5; i++)
	{
		DTO_CustomerOrder order = new DTO_CustomerOrder();
		order.orderId = 'ORD-' + i;
		order.customerName = 'Customer ' + i;
		order.totalAmount = Math.random() * 1000;
		order.orderDate = Date.today().addDays(-i);
		orders.add(order);
	}

	// Sort by total amount (ascending)
	DTO_JsonBase.FieldComparator amountComparator =
		new DTO_JsonBase.FieldComparator('totalAmount', true);
	orders.sort(amountComparator);

	// Sort by customer name (descending)
	DTO_JsonBase.FieldComparator nameComparator =
		new DTO_JsonBase.FieldComparator('customerName', false);
	orders.sort(nameComparator);

	// Sort by date
	DTO_JsonBase.FieldComparator dateComparator =
		new DTO_JsonBase.FieldComparator('orderDate', true);
	orders.sort(dateComparator);
}
```

---

### DTO Collections and Equality

DTOs implement `equals()` and `hashCode()` for collection support.

```apex
/**
 * @description Demonstrate DTO collections
 */
public static void demonstrateCollections()
{
	DTO_CustomerOrder order1 = new DTO_CustomerOrder();
	order1.orderId = 'ORD-001';
	order1.totalAmount = 100.00;

	DTO_CustomerOrder order2 = new DTO_CustomerOrder();
	order2.orderId = 'ORD-001';
	order2.totalAmount = 100.00;

	DTO_CustomerOrder order3 = new DTO_CustomerOrder();
	order3.orderId = 'ORD-002';
	order3.totalAmount = 200.00;

	// Equality based on serialized JSON
	Boolean areEqual = order1.equals(order2); // true (same content)
	Boolean areDifferent = order1.equals(order3); // false (different content)

	// Use in Sets (duplicates removed)
	Set<DTO_JsonBase> uniqueOrders = new Set<DTO_JsonBase>();
	uniqueOrders.add(order1);
	uniqueOrders.add(order2); // Duplicate, not added
	uniqueOrders.add(order3);
	// uniqueOrders.size(): 2

	// Use as Map keys
	Map<DTO_JsonBase, String> orderMap = new Map<DTO_JsonBase, String>();
	orderMap.put(order1, 'Processing');
	orderMap.put(order2, 'Shipped'); // Overwrites order1
	orderMap.put(order3, 'Delivered');
	// orderMap.size(): 2
}
```

---

## Integration Patterns

### DTOs in REST APIs

Complete example showing inbound REST API with DTOs using the [API_Inbound](reference/apex/API_Inbound.md) framework.

```apex
/**
 * @description REST endpoint for order management
 */
@RestResource(UrlMapping='/v1/orders/*')
global inherited sharing class REST_Orders
{
	@HttpPost
	global static void createOrder()
	{
		API_Dispatcher.processInboundService(API_CreateOrder.class.getName());
	}
}

/**
 * @description Create order API implementation
 */
public with sharing class API_CreateOrder extends API_Inbound
{
	private Foobar__c order;

	public override void configure()
	{
		super.configure();
		requestPayload = new DTO_Request();
		responsePayload = new DTO_Response();
	}

	public override List<String> getValidationErrors()
	{
		List<String> errors = new List<String>();
		DTO_Request dto = (DTO_Request)requestPayload;

		if(String.isBlank(dto.customerName))
		{
			errors.add('Customer name is required');
		}

		return errors;
	}

	public override void onSuccess()
	{
		super.onSuccess();
		DTO_Request dto = (DTO_Request)requestPayload;

		order = new Foobar__c();
		order.Name = dto.customerName;

		doInsert(order);
	}

	public override void updateResponseDTO()
	{
		DTO_Response dto = (DTO_Response)responsePayload;

		if(result.isSuccess)
		{
			dto.success = true;
			dto.orderId = order.Id;
			dto.message = 'Order created successfully';
		}
	}

	@JsonAccess(Deserializable='always')
	public class DTO_Request extends DTO_JsonBase
	{
		/**
		 * @description The customer name.
		 */
		public String customerName;

		/**
		 * @description The order date.
		 */
		public Date orderDate;

		/**
		 * @description The total amount.
		 */
		public Decimal totalAmount;
	}

	@JsonAccess(Serializable='always')
	public class DTO_Response extends DTO_JsonBase
	{
		/**
		 * @description Whether the operation was successful.
		 */
		public Boolean success;

		/**
		 * @description The created order ID.
		 */
		public String orderId;

		/**
		 * @description A status message.
		 */
		public String message;
	}
}
```

---

### DTOs in LWC Components

```apex
/**
 * @description LWC controller for customer dashboard
 */
public with sharing class CustomerDashboardController
{
	/**
	 * @description Get customer summary data
	 */
	@AuraEnabled(Cacheable=true)
	public static String getCustomerSummary(Id customerId)
	{
		Account customer = (Account)new SEL_Accounts().findById(customerId);

		DTO_CustomerSummary summary = new DTO_CustomerSummary();
		summary.customerName = customer.Name;
		summary.industry = customer.Industry;
		summary.revenue = customer.AnnualRevenue;
		summary.phone = customer.Phone;

		return summary.serialize();
	}
}

/**
 * @description Customer summary DTO
 */
@JsonAccess(Serializable='always' Deserializable='always')
public class DTO_CustomerSummary extends DTO_JsonBase
{
	@AuraEnabled
	public String customerName;

	@AuraEnabled
	public String industry;

	@AuraEnabled
	public Decimal revenue;

	@AuraEnabled
	public String phone;

	protected override Type getObjectType()
	{
		return DTO_CustomerSummary.class;
	}
}
```

**LWC JavaScript:**

```javascript
import { api, wire } from 'lwc';
import { ComponentBuilder } from 'c/componentBuilder';
import getCustomerSummary from '@salesforce/apex/CustomerDashboardController.getCustomerSummary';

export default class CustomerDashboard extends ComponentBuilder('controller')
{
	@api recordId;
	customerData;

	@wire(getCustomerSummary, { customerId: '$recordId' })
	wiredCustomer({ error, data })
	{
		if(data)
		{
			this.customerData = JSON.parse(data);
		}
	}
}
```

#### Passing Complex DTOs as `@AuraEnabled` Parameters

**Never pass a complex DTO directly as an `@AuraEnabled` method parameter.** LWC Proxy-wraps reactive objects before serializing them, and Aura's
parameter deserializer rejects the Proxy wrapper when the target type is a DTO extending `DTO_JsonBase` (or any class with nested collections).
The callout fails at runtime with messages such as "Unable to deserialize to specified type" or "cannot be deserialized from non-object type".

The working pattern is to accept a `String requestJson` parameter on the controller and deserialize it with `JSON.deserialize(...)` inside the
method. The client stringifies the DTO before calling. This is the pattern used throughout the framework (see `CTRL_ScheduledJob.saveRecord`).

```apex
// CORRECT — accept String, deserialize server-side
@AuraEnabled
public static Id saveRecord(String requestJson)
{
	SaveRequest request = (SaveRequest)JSON.deserialize(requestJson, SaveRequest.class);
	// ... use request.className, request.cronExpression, ...
}

// WRONG — passing the DTO directly fails with LWC Proxy
@AuraEnabled
public static Id saveRecord(SaveRequest request) { /* runtime deserialization error */ }
```

```javascript
// LWC caller stringifies before invoking
await this.callControllerMethod('saveRecord', {requestJson: JSON.stringify(this.request)});
```

This restriction applies only to input parameters. Return values from `@AuraEnabled` methods can be complex DTOs — Aura serializes DTO instances
to JSON correctly on the way out, and LWC consumes them as plain JavaScript objects.

---

### DTOs in Flow Invocables

```apex
/**
 * @description Send email with dynamic merge fields (Flow invocable)
 */
@SuppressWarnings('PMD.AvoidGlobalModifier')
global inherited sharing class FLOW_SendCustomEmail
{
	@InvocableMethod(Category='Email' Label='Send Custom Email' Description='Sends an email with dynamic merge fields.')
	global static List<DTO_Response> execute(List<DTO_Request> requests)
	{
		if(requests == null || requests.size() != 1)
		{
			throw new IllegalArgumentException('FLOW_SendCustomEmail expects a single request');
		}
		DTO_Request request = requests.iterator().next();

		DTO_Response response = new DTO_Response();

		try
		{
			String emailBody = request.templateBody;

			for(DTO_NameValue mergeField : request.mergeFields)
			{
				String placeholder = '{!' + mergeField.name + '}';
				emailBody = emailBody.replace(placeholder, mergeField.value);
			}

			Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
			email.setToAddresses(new List<String>{request.recipientEmail});
			email.setSubject(request.subject);
			email.setPlainTextBody(emailBody);

			Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{email});

			response.success = true;
			response.message = 'Email sent successfully';
		}
		catch(Exception error)
		{
			response.success = false;
			response.message = 'Error: ' + error.getMessage();
			LOG_Builder.build().error(error).emitAt('FLOW_SendCustomEmail.execute');
		}

		return new List<DTO_Response> {response};
	}

	global inherited sharing class DTO_Request
	{
		@InvocableVariable(Label='Recipient Email' Description='The email address to send to' Required=true)
		global String recipientEmail;

		@InvocableVariable(Label='Subject' Description='The email subject line' Required=true)
		global String subject;

		@InvocableVariable(Label='Template Body' Description='The email body template with merge field placeholders' Required=true)
		global String templateBody;

		@InvocableVariable(Label='Merge Fields' Description='Name-value pairs for template merge fields')
		global List<DTO_NameValue> mergeFields;
	}

	global inherited sharing class DTO_Response
	{
		@InvocableVariable(Label='Success' Description='Whether the email was sent successfully')
		global Boolean success;

		@InvocableVariable(Label='Message' Description='Status or error message')
		global String message;
	}
}
```

---

## Testing

DTOs are tested primarily through their integration points: web service tests, LWC controller tests, and Flow
invocable tests. The framework's base classes (`DTO_Base`, `DTO_JsonBase`) are tested by the framework itself,
so your tests should focus on custom DTO behaviour such as `populate()` and `transform()` overrides.

**Testing serialize/deserialize round-trips:**

```apex
@IsTest
private static void shouldSerializeAndDeserializeSuccessfully()
{
	DTO_OrderSummary original = new DTO_OrderSummary();
	original.orderId = 'ORD-001';
	original.totalAmount = 250.00;

	String json = original.serialize();
	DTO_OrderSummary deserialized = (DTO_OrderSummary)new DTO_OrderSummary().deserialize(json);

	Assert.areEqual(original.orderId, deserialized.orderId, 'Order ID should survive round-trip');
	Assert.areEqual(original.totalAmount, deserialized.totalAmount, 'Total amount should survive round-trip');
}
```

**Testing populate() with TST_Mock:**

When your DTO's `populate()` method queries records via selectors, use `TST_Mock` to register mock data for DML-free testing:

```apex
@IsTest
private static void shouldPopulateFromRecord()
{
	Foobar__c mock = (Foobar__c)TST_Mock.of(Foobar__c.SObjectType)
		.withOverride(Foobar__c.Email__c, 'test@example.com')
		.build();

	DTO_Request dto = new DTO_Request();
	dto.populate(mock.Id, null);

	Assert.areEqual('test@example.com', dto.email, 'Email should be populated from record');

	TST_Mock.clear();
}
```

**Testing transform():**

```apex
@IsTest
private static void shouldTransformBetweenFormats()
{
	DTO_AccountInternal internal = new DTO_AccountInternal();
	internal.name = 'Acme Corp';
	internal.industryCode = 'TECH';

	DTO_AccountExternal external = new DTO_AccountExternal();
	external.transform(internal);

	Assert.areEqual('Acme Corp', external.companyName, 'Company name should be mapped');
	Assert.areEqual('Technology', external.industry, 'Industry code should be translated');
}
```

**Testing DTOs in web service context:**

For DTOs used in API classes, testing happens through `API_OutboundTestHelper` assertions. The framework handles
DTO population and serialization internally, so your test verifies the end-to-end flow rather than the DTO in
isolation. See [Web Services - Guide](Web%20Services%20-%20Guide.md) for patterns.

---

## Anti-Patterns

| Anti-Pattern | Why It's Wrong | Instead |
|---|---|---|
| Missing `@JsonAccess` on DTOs in subscriber orgs | Serialization fails at runtime with a security error in managed package context | Always add `@JsonAccess(Serializable='always' Deserializable='always')` on every DTO extending a framework base class |
| Business logic inside `populate()` | Makes the DTO untestable in isolation and violates single responsibility | Keep `populate()` limited to data mapping; move logic to service classes or trigger actions |
| Skipping type resolver registration in subscriber orgs | Deserialization fails with `TypeException` because the managed package cannot resolve subscriber class names | Register a `ClassTypeResolver__mdt` record or implement a custom `UTIL_TypeResolver` |
| Using raw `Map<String, Object>` instead of typed DTOs | No compile-time safety, hard to refactor, error-prone key access | Create a DTO class extending `DTO_JsonBase` for structured data |
| Null-unsafe access to DTO properties | Causes `NullPointerException` at runtime when optional fields are missing | Use null checks or default values before accessing optional DTO properties |
| Passing a complex DTO directly as an `@AuraEnabled` parameter | LWC Proxy-wraps the object and Aura cannot deserialize it into the DTO type — fails with "Unable to deserialize to specified type" | Accept `String requestJson` on the controller, call `JSON.deserialize(...)` server-side; stringify in the LWC caller (see `CTRL_ScheduledJob.saveRecord`) |

---

## Best Practices

### 1. Use Appropriate DTO Type

```apex
// GOOD: JSON API
public class DTO_ApiRequest extends DTO_JsonBase { }
```

### 2. Implement getObjectType() for Private Classes (OR Use Type Resolver)

**Option A: Override `getObjectType()` in each DTO (simple approach):**
```apex
// GOOD for small number of DTOs
private class DTO_InternalData extends DTO_JsonBase
{
	public String data;

	protected override Type getObjectType()
	{
		return DTO_InternalData.class;
	}
}
```

**Option B: Register custom type resolver (recommended for 10+ DTOs):**
```apex
// BETTER for many DTOs - no getObjectType() needed!
// Just register CustomDTOTypeResolver in ClassTypeResolver__mdt

private class DTO_InternalData extends DTO_JsonBase
{
	public String data;
	// No getObjectType() method needed - resolved automatically!
}
```

**See [Type Resolution: CRITICAL Requirement for Subscriber Orgs](#type-resolution-critical-requirement-for-subscriber-orgs) for setup details.**

### 3. Use @AuraEnabled for LWC

When exposing DTO fields to Lightning Web Components, annotate with [`@AuraEnabled`](https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_classes_annotation_AuraEnabled.htm):

```apex
// GOOD
public class DTO_Data extends DTO_JsonBase
{
	@AuraEnabled
	public String fieldName;
}
```

### 4. Initialize Collections

```apex
// GOOD
public class DTO_Order extends DTO_JsonBase
{
	public List<DTO_OrderItem> lineItems;

	public DTO_Order()
	{
		lineItems = new List<DTO_OrderItem>();
	}
}
```

### 5. Handle Null Values

```apex
// GOOD
this.industry = String.isNotBlank(account.Industry) ? account.Industry : 'Unknown';

// BAD
this.industry = account.Industry.toUpperCase(); // Null pointer risk
```

### 6. Use Clear Naming

```apex
// GOOD
public class DTO_CustomerOrderRequest extends DTO_JsonBase { }

// BAD
public class DTO_Data extends DTO_JsonBase { } // Vague
```

### 7. Document Complex DTOs

```apex
/**
 * @description Customer order request DTO for external order management system
 */
public class DTO_CustomerOrderRequest extends DTO_JsonBase
{
	/**
	 * @description Unique order ID from external system
	 */
	public String externalOrderId;
}
```

### 8. Validate DTO Data

```apex
public override List<String> getValidationErrors()
{
	List<String> errors = new List<String>();
	DTO_Request dto = (DTO_Request)requestPayload;

	if(String.isBlank(dto.customerName))
	{
		errors.add('Customer name is required');
	}

	return errors;
}
```

### 9. Keep DTOs Focused

```apex
// GOOD: Focused DTO
public class DTO_AccountBasic extends DTO_JsonBase
{
	public String name;
	public String industry;
}

// BAD: Over-complicated
public class DTO_Everything extends DTO_JsonBase
{
	// Too many unrelated fields
}
```

---

## Troubleshooting

### Issue: "Type cannot be deserialized as it is not globally visible" or "System.JSONException: Type cannot be constructed"

**Cause:** Missing [`@JsonAccess`](https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_classes_annotation_JsonAccess.htm) annotation on DTO extending managed package base class.

**This is the #1 most common error when using KernDX DTOs from a managed package.**

**Error Example:**
```text
System.JSONException: Type cannot be deserialized as it is not globally visible - DTO_CustomerOrder
```

**Solution:**
Add `@JsonAccess(Serializable='always' Deserializable='always')` to your DTO class. See the full WRONG/CORRECT example in
[Type Resolution: CRITICAL Requirement for Subscriber Orgs](#type-resolution-critical-requirement-for-subscriber-orgs).

**Why this is required:**
When your subscriber org's code extends a managed package class (e.g., `YourNamespace.DTO_JsonBase`), and the managed package code tries to serialize/deserialize your class, Salesforce security requires explicit permission via `@JsonAccess` annotation. Without it, the operation fails with a security error.

---

### Issue: "Unable to deserialize to specified type"

**Cause:** Missing `getObjectType()` implementation for private DTO class.

**Solution Option 1 - Override `getObjectType()` in each DTO:**
```apex
protected override Type getObjectType()
{
	return DTO_MyClass.class;
}
```

**Solution Option 2 - Register custom type resolver (recommended for 10+ DTOs):**

1. Create custom resolver (see complete implementation above in "Type Resolution" section)
2. Register in [`ClassTypeResolver__mdt`](reference/metadata/ClassTypeResolver__mdt.md) with `ClassName__c = 'CustomDTOTypeResolver'`
3. Remove `getObjectType()` from all DTOs - type resolution is now automatic!

### Issue: "Null pointer exception when accessing DTO fields"

**Cause:** Collection not initialized.

**Solution:**
```apex
public DTO_Order()
{
	lineItems = new List<DTO_OrderItem>();
}
```

### Issue: "DTO fields not visible in LWC"

**Cause:** Missing [`@AuraEnabled`](https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_classes_annotation_AuraEnabled.htm).

**Solution:**
```apex
@AuraEnabled
public String fieldName;
```

---

## Reference

### DTO Framework Classes

| Class | Purpose | Extends |
|-------|---------|---------|
| [`DTO_Base`](reference/apex/DTO_Base.md) | Abstract base for all DTOs | - |
| [`DTO_JsonBase`](reference/apex/DTO_JsonBase.md) | JSON serialization | DTO_Base |
| [`DTO_NameValues`](reference/apex/DTO_NameValues.md) | Key-value collections | DTO_JsonBase |
| [`DTO_BaseTable`](reference/apex/DTO_BaseTable.md) | Lightning datatable | DTO_JsonBase |
| [`DTO_PickList`](reference/apex/DTO_PickList.md) | Picklist metadata | - |

### Key Methods

**DTO_Base:**
```apex
global virtual String serialize()
global virtual DTO_Base deserialize(String dtoString)
global virtual void populate(Id recordId)
global virtual void transform(DTO_Base dtoBase)
```

---

## Related Documentation

- **[Web Services - Guide](Web%20Services%20-%20Guide.md)** - DTOs in REST APIs
- **[Selectors - Guide](Selectors%20-%20Guide.md)** - Querying data for DTOs
- **[DML - Guide](DML%20-%20Guide.md)** - SObject operations
- **[Triggers - Guide](Triggers%20-%20Guide.md)** - Trigger actions and DTO usage
- **[Security - Guide](Security%20-%20Guide.md)** - `@JsonAccess` requirements for managed package DTOs
