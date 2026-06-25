---
navOrder: 66
---

# DTOs - Guide

**Framework:** KernDX
**Package Type:** Managed Package (namespace-agnostic)
**Version:** 1.0
**Last Updated:** April 2026

> **Note for installed packages:** When you install KernDX as a managed package, prefix framework class references with your installed namespace (for example, `AcmeLib.DTO_JsonBase` for Acme
> Inc.).

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
    - [DTO_ChangeEventHeader](#dto_changeeventheader)
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
    - [Use Appropriate DTO Type](#use-appropriate-dto-type)
    - [Implement getObjectType() for Private Classes (OR Use Type Resolver)](#implement-getobjecttype-for-private-classes-or-use-type-resolver)
    - [Use @AuraEnabled for LWC](#use-auraenabled-for-lwc)
    - [Initialize Collections](#initialize-collections)
    - [Handle Null Values](#handle-null-values)
    - [Use Clear Naming](#use-clear-naming)
    - [Document Complex DTOs](#document-complex-dtos)
    - [Validate DTO Data](#validate-dto-data)
    - [Keep DTOs Focused](#keep-dtos-focused)
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

| I am a...     | I need to...                | Go to...                                                    |
|---------------|-----------------------------|-------------------------------------------------------------|
| **Architect** | Understand DTO architecture | [Architecture](#architecture)                               |
| **Architect** | Choose integration patterns | [Integration Patterns](#integration-patterns)               |
| **Developer** | Create my first DTO         | [Quick Start](#quick-start)                                 |
| **Developer** | Build custom DTO classes    | [Creating Custom DTO Classes](#creating-custom-dto-classes) |
| **Developer** | Implement advanced patterns | [Advanced DTO Patterns](#advanced-dto-patterns)             |
| **Analyst**   | Know when to use DTOs       | [When to Use DTOs](#when-to-use-dtos)                       |

---

## Overview

**In one paragraph:** When your code moves data between two places (Apex to a Lightning component, Apex to an outside system, or a screen flow to Apex), you need a tidy package to carry it. A Data Transfer Object, or DTO, is a small class that holds exactly the fields you want to move and knows how to convert itself to and from JSON. This guide shows you how to build and use DTOs in KernDX, so that the shape of the data you send is clear, type-checked by the compiler, and easy to test. Developers reach for DTOs when building APIs, sending structured data to the front end, or passing parameters into flows. Architects use them to keep your internal database structure separate from the formats outside systems see. Read this when you are designing or consuming a data contract.

**Data Transfer Objects (DTOs)** are lightweight objects designed to transfer data between different layers of your application. DTOs provide a structured, type-safe way to
serialize and deserialize data for:

- **Web Service Integration** - REST request and response payloads
- **Lightning Web Components** - Structured data from Apex to LWC
- **Flow Integration** - Complex data structures in invocable methods
- **Data Transformation** - Converting between SObjects and external formats
- **Testing** - Creating consistent test data structures

> **DTO Framework Scope:** a set of base classes plus built-in DTOs (JSON, name-value, datatable, picklist, and CDC change-event header), supporting JSON serialization, SObject transformation, JsonPath
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

You want every DTO to behave the same way: serialize to JSON, parse back, compare for equality, and load itself from a record, without you re-writing that plumbing each time. KernDX gets you this by having all DTOs inherit from one shared base class. So you write only the fields and logic that are specific to your data, and the common behaviour comes for free.

The framework sits between your business logic and the things that consume your data (REST APIs, Lightning components, and flows). That position keeps your internal Salesforce object structure separate from the data formats outside systems expect, so a change to one does not force a change to the other.

The key building blocks are:

- **`DTO_Base`**: the abstract foundation. It provides `serialize()`, `deserialize()`, `populate()`, `transform()`, `equals()`, and `hashCode()`.
- **`DTO_JsonBase`**: the JSON-specific class. It adds readable (pretty-printed) JSON output, JsonPath integration for reading fields by path, and `FieldComparator` sorting.
- **Built-in DTOs** ready to use: `DTO_NameValues` (key-value parameters), `DTO_BaseTable` (Lightning datatable), `DTO_PickList` (picklist metadata), and `DTO_ChangeEventHeader` (the change-event header from Change Data Capture).

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

Most of the time you want a JSON DTO for an API integration or a Lightning component response. Here is the shortest path from nothing to a working DTO:

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

> **When KernDX is installed as a managed package:** Always include `@JsonAccess(Serializable='always' Deserializable='always')` on every DTO that extends a managed package base class. Without it, serialization fails at runtime. See [Type Resolution](#type-resolution-critical-requirement-for-subscriber-orgs) for the other requirement.

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

Every DTO needs the same core behaviour: turn into a string, parse back from a string, load itself from a record, and compare equal to another DTO with the same content. [`DTO_Base`](reference/apex/DTO_Base.md) is the abstract base that gives all DTOs this behaviour:

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

| Method                    | Purpose                      | Override Required   |
|---------------------------|------------------------------|---------------------|
| `serialize()`             | Convert DTO to string format | Yes (in subclasses) |
| `deserialize()`           | Parse string to DTO          | Yes (in subclasses) |
| `populate(Id)`            | Load DTO from record ID      | Optional            |
| `transform()`             | Convert between DTO types    | Optional            |
| `equals()` / `hashCode()` | Support collections          | No (implemented)    |

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

When your data needs to travel as JSON, which is almost always the case for APIs and Lightning components, extend [`DTO_JsonBase`](reference/apex/DTO_JsonBase.md) instead of `DTO_Base` directly. It builds on `DTO_Base` and handles [JSON serialization](https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_class_System_Json.htm) for you, with these conveniences:

**Key Features:**

1. **Automatic JSON serialization**: readable (pretty-printed) output that leaves out null fields.
2. **Type-safe deserialization**: parses JSON straight back into the right class.
3. **JsonPath integration**: read a field by its path through [`UTIL_JsonPath`](reference/apex/UTIL_JsonPath.md) over the serialized DTO, without writing a getter for it.
4. **Field comparator**: sort a list of DTOs by any field through [`DTO_JsonBase.FieldComparator`](reference/apex/DTO_JsonBase.md).

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

When the framework parses JSON back into your DTO, it needs to know which class to build. For a `global` or `public` class it can work that out on its own. For a `private` class it cannot, so you tell it: if your DTO class is `private` or not `global`, you **must** override `getObjectType()` to name the class:

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

For `global` or `public` classes you can skip this override, because the framework resolves the type automatically.

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

| Property | Type   | Required | Description                          |
|----------|--------|----------|--------------------------------------|
| `name`   | String | Yes      | The field name or placeholder key    |
| `value`  | String | No       | The value to associate with the name |

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

| Feature              | [`DTO_NameValue`](reference/apex/DTO_NameValue.md)                                                                                             | [`DTO_NameValues`](reference/apex/DTO_NameValues.md)     |
|----------------------|------------------------------------------------------------------------------------------------------------------------------------------------|----------------------------------------------------------|
| **Structure**        | Single name-value pair                                                                                                                         | Collection of pairs                                      |
| **Flow Support**     | [`@InvocableVariable`](https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_classes_annotation_InvocableVariable.htm) | Not directly invocable                                   |
| **Aura/LWC Support** | [`@AuraEnabled`](https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_classes_annotation_AuraEnabled.htm)             | `@AuraEnabled`                                           |
| **Use Case**         | Flow inputs, simple params                                                                                                                     | Complex parameter maps                                   |
| **Inheritance**      | Standalone class                                                                                                                               | Extends [`DTO_JsonBase`](reference/apex/DTO_JsonBase.md) |

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

| Property | Type               | Description                |
|----------|--------------------|----------------------------|
| `size`   | Integer            | Number of name-value pairs |
| `names`  | Set&lt;String&gt;  | All parameter names        |
| `values` | List&lt;String&gt; | All parameter values       |

#### DTO_NameValues Methods

| Method                                    | Description                                       |
|-------------------------------------------|---------------------------------------------------|
| `add(String name, String value)`          | Add or update a parameter                         |
| `get(String name)`                        | Get parameter value (null if not found)           |
| `exists(String name)`                     | Check if parameter exists                         |
| `exists(String name, Boolean isNonBlank)` | Check existence and optionally validate non-blank |
| `allExists(Set<String> names)`            | Check if all parameters exist                     |
| `isEmpty()`                               | Check if no parameters exist                      |
| `toParameterString()`                     | Convert to "name=value,name=value" format         |

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

| Type          | Description        | Example             |
|---------------|--------------------|---------------------|
| `text`        | Plain text         | Account Name        |
| `number`      | Numeric value      | 12345               |
| `currency`    | Currency formatted | $50,000             |
| `percent`     | Percentage         | 25%                 |
| `date`        | Date only          | 2026-02-07          |
| `date-local`  | Date (no timezone) | 2026-02-07          |
| `email`       | Email address      | user@example.com    |
| `phone`       | Phone number       | (555) 123-4567      |
| `url`         | Hyperlink          | https://example.com |
| `boolean`     | Checkbox           | true/false          |
| `button`      | Button             | -                   |
| `button-icon` | Icon button        | -                   |
| `action`      | Row actions        | -                   |

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

### [`DTO_ChangeEventHeader`](reference/apex/DTO_ChangeEventHeader.md)

**Purpose:** When a Change Data Capture event fires, you often want a flow to read details about what changed and who committed it. This DTO carries the supported part of the event's `ChangeEventHeader` into Flow as a strongly-typed input variable. So your change-event-triggered flows can read the commit and change details directly, with no bridging Apex to write.

**Structure:** every field is `@AuraEnabled`, so it is readable from Flow and LWC.

| Field             | Type           | Description                                                         |
|-------------------|----------------|---------------------------------------------------------------------|
| `entityName`      | `String`       | API name of the changed entity (for example `Account`)              |
| `recordIds`       | `List<String>` | Ids of the records affected by the change                           |
| `changeType`      | `String`       | The change operation (for example CREATE, UPDATE, DELETE, UNDELETE) |
| `changeOrigin`    | `String`       | Origin of the change (the client or integration that made it)       |
| `transactionKey`  | `String`       | Identifier shared by all changes committed in the same transaction  |
| `sequenceNumber`  | `Integer`      | Position of this change within its transaction                      |
| `commitTimestamp` | `Long`         | Commit time as epoch milliseconds                                   |
| `commitUser`      | `String`       | Id of the user who committed the change                             |
| `commitNumber`    | `Long`         | System change number of the commit                                  |
| `nulledFields`    | `List<String>` | Fields the change explicitly set to null                            |
| `diffFields`      | `List<String>` | Large text fields delivered as diffs rather than full values        |
| `changedFields`   | `List<String>` | Fields whose values changed                                         |

**Usage:** the framework populates this DTO automatically for change-event-triggered flows (it has a copy constructor from `EventBus.ChangeEventHeader`), so you do not need to write any bridging Apex. See the [Triggers - Guide](Triggers%20-%20Guide.md) Change Data Capture section for the end-to-end setup, and [`reference/apex/DTO_ChangeEventHeader.md`](reference/apex/DTO_ChangeEventHeader.md) for the complete member list.

---

## Creating Custom DTO Classes

### Creating JSON DTOs

**One required step when KernDX is installed as a managed package**

You want your DTO to serialize and deserialize without failing at runtime. To get that, add one annotation. When your DTO extends a class from an installed managed package (such as `DTO_JsonBase`), you **must** add the [`@JsonAccess`](https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_classes_annotation_JsonAccess.htm) annotation to your DTO class. The annotation gives the package's code permission to serialize and deserialize the DTO classes in your org.

**Why it matters:** without `@JsonAccess`, serialization and deserialization fail with a security error.

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

When the framework parses JSON back into a DTO, it has to build an instance of the right class by name. With a Type Resolver, you tell the framework where to find the Apex classes in your namespace. When KernDX runs as an installed managed package, its code lives in a different namespace from yours, so it cannot find your classes on its own. You have to point it at them. Skip this and deserialization fails at runtime.

**Where this matters:**

- Parsing JSON back into a DTO, through `DTO_JsonBase.deserialize()`.
- Building a class by name, where framework code uses `Type.forName()`.
- Working with mixed-type collections, such as factory patterns that create types on the fly.

**Pick exactly one of these three approaches:**

1. **Make all DTOs `global`.** Global classes are always visible to the package's code. Simple, but it exposes the classes more widely than you may want.
2. **Implement `getObjectType()` in every DTO.** You override one method per class to return its own type. Explicit, but repetitive across many DTOs.
3. **Register a Type Resolver (recommended).** You set this up once, and the framework then resolves every DTO automatically. The most flexible and maintainable option.

**Without one of these, you will hit runtime errors like this:**

```text
System.JSONException: Type cannot be deserialized as it is not globally visible - DTO_CustomerRequest
```

#### Type Resolution Option 3: Custom Type Resolver (RECOMMENDED)

Rather than override `getObjectType()` in every DTO or make all your classes global, you can register one **custom type resolver** that handles the lookup for all DTOs automatically. You set it up once and then forget it.

**What you gain:**

- No repetitive `getObjectType()` override in each DTO.
- No need to make classes `global`, so they stay better encapsulated.
- One place that holds the type-resolution logic.
- Less boilerplate to write and maintain.

**How it works:**

1. **Create a custom type resolver class:**

```apex
/**
 * @description Custom type resolver for subscriber org DTOs
 *
 * @see UTIL_TypeResolver
 */
global with sharing class CustomDTOTypeResolver extends kern.UTIL_TypeResolver.BaseClassResolver
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
			String namespace = kern.UTIL_System.getNamespacePrefix(
				kern.UTIL_System.getClassNamespace(className),
				'.'
			);

			classType = Type.forName(namespace, className);
			// Retry without namespace for nested classes (e.g., MyParentClass.MyChildClass)
			classType = classType == null && String.isNotBlank(namespace)
				? Type.forName('', className)
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

- Your org, when it has many custom DTOs (reduces boilerplate)
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

Sometimes you have a record ID and want a DTO filled in from that record's data. The `populate()` method does exactly that: you give it a Salesforce record ID and it loads the DTO's fields from the matching record. This lets you build the DTO only when you actually need its data.

**One rule when you write `populate()`:** read the record through a [SEL_Base](reference/apex/SEL_Base.md) selector or [QRY_Builder](reference/apex/QRY_Builder.md), never inline SOQL. Doing it this way buys you several things:

- Field selection lives in one place, not scattered across DTOs.
- The query logic is reusable.
- Tests can mock the data, so you can test without touching the database.
- The query stays safe to run on many records at once.
- Your code follows the same convention as the rest of the framework.

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

Sometimes the shape your code uses internally is not the shape an outside system expects. The `transform()` method converts one DTO into another, mapping and reshaping fields as it goes.

**A common case:** turn an internal DTO into the format an external API wants, for example renaming fields or bucketing a number into a category.

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

Sometimes you want to read a field out of a DTO by its path rather than through a property, for example when the field is buried inside a nested object or an array. Serialize the DTO and wrap it in [`UTIL_JsonPath`](reference/apex/UTIL_JsonPath.md), then read fields by path. Each node gives you a typed getter that matches the field's type: `getStringValue()`, `getIntegerValue()`, `getDecimalValue()`, `getBooleanValue()`, `getDateValue()`, `getDatetimeValue()`, and `getIdValue()`. There is no untyped `getValue()`, so you always read the value as the type you expect.

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

| Pattern          | Description         | Example                                     |
|------------------|---------------------|---------------------------------------------|
| `fieldName`      | Top-level field     | `path.findNode('orderId')`                  |
| `parent.child`   | Nested object       | `path.findNode('shippingAddress.city')`     |
| `array[0]`       | Array index         | `path.findNode('lineItems[0]')`             |
| `array[0].field` | Array element field | `path.findNode('lineItems[0].productName')` |

---

### Sorting DTOs with FieldComparator

When you need a list of DTOs in order (by amount, by name, by date), you do not have to write a custom sort each time. [`DTO_JsonBase.FieldComparator`](reference/apex/DTO_JsonBase.md) sorts a list by whichever field you name, ascending or descending.

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

When you want to drop DTOs into a Set to remove duplicates, or use one as a Map key, the platform needs a way to tell whether two DTOs are the same. DTOs handle this for you: they implement `equals()` and `hashCode()`, treating two DTOs as equal when their serialized content matches. So Sets and Maps work as you would expect.

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

When you build a REST endpoint, DTOs give you a clear contract for the request you accept and the response you return. The example below shows a full inbound REST API built on the [API_Inbound](reference/apex/API_Inbound.md) base class: a request DTO carries the incoming data, and a response DTO carries what you send back.

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

When a Lightning component needs structured data from Apex, return it as a serialized DTO and parse it on the client. The Apex controller below builds a DTO, serializes it to JSON, and returns the string; the JavaScript that follows parses it back into a plain object.

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

**Never pass a complex DTO directly as an `@AuraEnabled` method parameter.** Here is why it breaks. LWC wraps reactive objects in a Proxy before serializing them. When the target type is a DTO that extends `DTO_JsonBase` (or any class with nested collections), Aura's parameter deserializer rejects that Proxy wrapper. The call then fails at runtime with messages such as "Unable to deserialize to specified type" or "cannot be deserialized from non-object type".

The pattern that works: accept a `String requestJson` parameter on the controller, then deserialize it with `JSON.deserialize(...)` inside the method. The client stringifies the DTO before calling. This is the pattern used throughout the framework (see `CTRL_ScheduledJob.saveRecord`).

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

This restriction applies only to input parameters. Return values are fine: an `@AuraEnabled` method can return a complex DTO, because Aura serializes DTO instances to JSON correctly on the way out, and LWC consumes them as plain JavaScript objects.

---

### DTOs in Flow Invocables

When an admin calls your Apex from a flow, DTOs let you accept and return structured inputs instead of a long list of loose parameters. The invocable method below takes a request DTO (with a list of name-value merge fields) and returns a response DTO reporting success or failure.

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

You do not need to test the parts of a DTO that the framework already covers. The base classes (`DTO_Base`, `DTO_JsonBase`) come tested. So aim your tests at the behaviour you wrote: your `populate()` and `transform()` overrides, plus a quick round-trip check that your DTO survives serialize-then-deserialize. In practice you test DTOs through the place they are used: a web service test, a Lightning controller test, or a flow invocable test.

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

When your DTO's `populate()` method reads records through a selector, you can test it without inserting any data. Register the record you expect with `TST_Mock`, then call `populate()` and assert on the result:

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

For DTOs used inside API classes, test through `API_OutboundTestHelper` assertions. The framework populates and serializes the DTO for you, so your test checks the whole call end to end rather than the DTO on its own. See [Web Services - Guide](Web%20Services%20-%20Guide.md) for patterns.

---

## Anti-Patterns

These are the common mistakes that bite people when working with DTOs, what goes wrong in each case, and what to do instead.

| Anti-Pattern                                                  | Why It's Wrong                                                                                                                     | Instead                                                                                                                                                   |
|---------------------------------------------------------------|------------------------------------------------------------------------------------------------------------------------------------|-----------------------------------------------------------------------------------------------------------------------------------------------------------|
| Missing `@JsonAccess` on DTOs in subscriber orgs              | Serialization fails at runtime with a security error in managed package context                                                    | Always add `@JsonAccess(Serializable='always' Deserializable='always')` on every DTO extending a framework base class                                     |
| Business logic inside `populate()`                            | Makes the DTO untestable in isolation and violates single responsibility                                                           | Keep `populate()` limited to data mapping; move logic to service classes or trigger actions                                                               |
| Skipping type resolver registration in subscriber orgs        | Deserialization fails with `TypeException` because the managed package cannot resolve subscriber class names                       | Register a `ClassTypeResolver__mdt` record or implement a custom `UTIL_TypeResolver`                                                                      |
| Using raw `Map<String, Object>` instead of typed DTOs         | No compile-time safety, hard to refactor, error-prone key access                                                                   | Create a DTO class extending `DTO_JsonBase` for structured data                                                                                           |
| Null-unsafe access to DTO properties                          | Causes `NullPointerException` at runtime when optional fields are missing                                                          | Use null checks or default values before accessing optional DTO properties                                                                                |
| Passing a complex DTO directly as an `@AuraEnabled` parameter | LWC Proxy-wraps the object and Aura cannot deserialize it into the DTO type, so the call fails with "Unable to deserialize to specified type" | Accept `String requestJson` on the controller, call `JSON.deserialize(...)` server-side; stringify in the LWC caller (see `CTRL_ScheduledJob.saveRecord`) |

---

## Best Practices

A short checklist of habits that keep DTOs easy to read, test, and maintain. Each one is shown with a quick good-versus-bad example.

### Use Appropriate DTO Type

```apex
// GOOD: JSON API
public class DTO_ApiRequest extends DTO_JsonBase { }
```

### Implement getObjectType() for Private Classes (OR Use Type Resolver)

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

### Use @AuraEnabled for LWC

For a DTO field to be readable from a Lightning Web Component, mark it with [`@AuraEnabled`](https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_classes_annotation_AuraEnabled.htm). Fields without it are invisible to the front end:

```apex
// GOOD
public class DTO_Data extends DTO_JsonBase
{
	@AuraEnabled
	public String fieldName;
}
```

### Initialize Collections

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

### Handle Null Values

```apex
// GOOD
this.industry = String.isNotBlank(account.Industry) ? account.Industry : 'Unknown';

// BAD
this.industry = account.Industry.toUpperCase(); // Null pointer risk
```

### Use Clear Naming

```apex
// GOOD
public class DTO_CustomerOrderRequest extends DTO_JsonBase { }

// BAD
public class DTO_Data extends DTO_JsonBase { } // Vague
```

### Document Complex DTOs

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

### Validate DTO Data

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

### Keep DTOs Focused

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

The errors below cover almost every problem people run into with DTOs. Each entry names the likely cause and the fix.

### Issue: "Type cannot be deserialized as it is not globally visible" or "System.JSONException: Type cannot be constructed"

**Cause:** Your DTO extends an installed managed package base class but is missing the [`@JsonAccess`](https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_classes_annotation_JsonAccess.htm) annotation.

**This is the most common error people hit with KernDX DTOs from an installed package.**

**Error Example:**

```text
System.JSONException: Type cannot be deserialized as it is not globally visible - DTO_CustomerOrder
```

**Solution:**
Add `@JsonAccess(Serializable='always' Deserializable='always')` to your DTO class. See the full WRONG/CORRECT example in
[Type Resolution: CRITICAL Requirement for Subscriber Orgs](#type-resolution-critical-requirement-for-subscriber-orgs).

**Why this is required:**
When your code extends a managed package class (for example `YourNamespace.DTO_JsonBase`) and the package's code then tries to serialize or deserialize your class, Salesforce security requires you to grant explicit permission with the `@JsonAccess` annotation. Without it, the operation fails with a security error.

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

| Class                                                | Purpose                    | Extends      |
|------------------------------------------------------|----------------------------|--------------|
| [`DTO_Base`](reference/apex/DTO_Base.md)             | Abstract base for all DTOs | -            |
| [`DTO_JsonBase`](reference/apex/DTO_JsonBase.md)     | JSON serialization         | DTO_Base     |
| [`DTO_NameValues`](reference/apex/DTO_NameValues.md) | Key-value collections      | DTO_JsonBase |
| [`DTO_BaseTable`](reference/apex/DTO_BaseTable.md)   | Lightning datatable        | DTO_JsonBase |
| [`DTO_PickList`](reference/apex/DTO_PickList.md)     | Picklist metadata          | -            |

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
