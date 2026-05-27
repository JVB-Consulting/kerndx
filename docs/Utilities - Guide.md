# Utilities - Guide

**Framework:** KernDX
**Package Type:** Managed Package

**Target Audience:**
- **Developers** - Quick reference for common utility operations and advanced patterns including retry, circuit breaker, cache, and type resolution
- **Architects** - Understanding available utility capabilities, fault tolerance patterns, and extensibility through type resolvers and feature flags
- **Business Analysts** - Overview of utility functions for data formatting, validation, feature flag management, and Flow invocable methods

---

## Table of Contents

<details>
<summary>Expand</summary>

1. [Quick Navigation](#quick-navigation)
2. [Overview](#overview)
3. [Architecture](#architecture)
4. [Quick Start](#quick-start)
5. [String Utilities](#string-utilities)
   - [UTIL_String](#util_string)
     - [ID Validation](#id-validation)
     - [String Manipulation](#string-manipulation)
     - [String Replacement](#string-replacement)
     - [String Splitting & Joining](#string-splitting--joining)
6. [Date & Time Utilities](#date--time-utilities)
   - [UTIL_Date](#util_date)
     - [Weekend & Weekday Detection](#weekend--weekday-detection)
     - [Business Day Arithmetic](#business-day-arithmetic)
     - [ISO 8601 Conversion](#iso-8601-conversion)
     - [Date Formatting](#date-formatting)
     - [Cron Expressions](#cron-expressions)
7. [Character Utilities](#character-utilities)
   - [UTIL_Character](#util_character)
8. [Collection Utilities](#collection-utilities)
   - [UTIL_List](#util_list)
   - [UTIL_Map](#util_map)
   - [UTIL_Set](#util_set)
   - [Sorting](#sorting)
9. [System & Reflection](#system--reflection)
   - [UTIL_System](#util_system)
     - [Type Resolution](#type-resolution)
     - [Namespace & Environment](#namespace--environment)
   - [UTIL_Exceptions](#util_exceptions)
10. [Data Processing](#data-processing)
    - [UTIL_JsonPath](#util_jsonpath)
11. [Specialized Utilities](#specialized-utilities)
    - [UTIL_Email](#util_email)
      - [Email Validation](#email-validation)
      - [Check Email Deliverability](#check-email-deliverability)
      - [Send Email](#send-email)
      - [Working with Attachments](#working-with-attachments)
    - [UTIL_StopWatch](#util_stopwatch)
    - [UTIL_FormulaFilter](#util_formulafilter)
    - [UTIL_BulkUpdates](#util_bulkupdates)
    - [UTIL_PurgeRecords](#util_purgerecords)
    - [UTIL_Limits](#util_limits)
12. [Quick Reference Tables](#quick-reference-tables)
    - [String Validation Quick Reference](#string-validation-quick-reference)
    - [Date Calculation Quick Reference](#date-calculation-quick-reference)
    - [Collection Operations Quick Reference](#collection-operations-quick-reference)
13. [Retry Strategy Framework (UTIL_Retry)](#retry-strategy-framework-util_retry)
    - [Architecture](#architecture-1)
    - [Built-in Retry Strategies](#built-in-retry-strategies)
      - [Exponential Backoff Strategy (RECOMMENDED)](#exponential-backoff-strategy-recommended)
      - [Linear Backoff Strategy](#linear-backoff-strategy)
    - [Backoff Calculation Algorithms](#backoff-calculation-algorithms)
      - [Exponential Backoff Algorithm](#exponential-backoff-algorithm)
      - [Linear Backoff Algorithm](#linear-backoff-algorithm)
      - [Jitter Implementation](#jitter-implementation)
      - [Custom Exponential Multiplier](#custom-exponential-multiplier)
    - [Basic Usage](#basic-usage)
      - [1. Using Retry Strategy in Web Service Classes](#1-using-retry-strategy-in-web-service-classes)
      - [2. Manual Retry Logic (Advanced)](#2-manual-retry-logic-advanced)
    - [Custom Retry Strategies](#custom-retry-strategies)
    - [Integration with Web Services Framework](#integration-with-web-services-framework)
    - [Best Practices](#best-practices)
    - [Testing Retry Strategies](#testing-retry-strategies)
      - [Testing Strategy Calculations](#testing-strategy-calculations)
    - [Common Patterns](#common-patterns)
      - [Pattern 1: Using Retry Strategy in Web Service Classes](#pattern-1-using-retry-strategy-in-web-service-classes)
      - [Pattern 2: Manual Retry Decision Logic](#pattern-2-manual-retry-decision-logic)
14. [Circuit Breaker Framework (UTIL_CircuitBreaker)](#circuit-breaker-framework-util_circuitbreaker)
    - [Architecture](#architecture-2)
    - [Circuit States](#circuit-states)
      - [1. CLOSED (Normal Operation)](#1-closed-normal-operation)
      - [2. OPEN (Blocking Calls)](#2-open-blocking-calls)
      - [3. HALF_OPEN (Testing Recovery)](#3-half_open-testing-recovery)
    - [State Transition Algorithm](#state-transition-algorithm)
      - [CLOSED → OPEN Transition](#closed--open-transition)
      - [OPEN → HALF_OPEN Transition](#open--half_open-transition)
      - [HALF_OPEN → CLOSED Transition](#half_open--closed-transition)
      - [HALF_OPEN → OPEN Transition](#half_open--open-transition)
      - [HALF_OPEN Request Limiting](#half_open-request-limiting)
      - [Platform Cache State Management](#platform-cache-state-management)
    - [Basic Usage](#basic-usage-1)
      - [1. Using Default Configuration](#1-using-default-configuration)
    - [Metadata Configuration](#metadata-configuration)
      - [Create ApiSetting__mdt Record](#create-apisetting__mdt-record)
      - [Use in Code](#use-in-code)
    - [Integration with Web Services Framework](#integration-with-web-services-framework-1)
    - [Advanced Configuration](#advanced-configuration)
      - [Configuring Failure Threshold](#configuring-failure-threshold)
      - [Configuring Timeout Period](#configuring-timeout-period)
      - [Configuring Half-Open Test Requests](#configuring-half-open-test-requests)
    - [Platform Cache Integration](#platform-cache-integration)
      - [Cache Behavior](#cache-behavior)
      - [Cache TTL Management](#cache-ttl-management)
    - [Best Practices](#best-practices-1)
    - [Testing Circuit Breakers](#testing-circuit-breakers)
      - [Testing Circuit State Transitions](#testing-circuit-state-transitions)
      - [Testing Cache Persistence](#testing-cache-persistence)
    - [Common Patterns](#common-patterns-1)
      - [Pattern 1: Circuit Breaker with Fallback](#pattern-1-circuit-breaker-with-fallback)
      - [Pattern 2: Multiple Circuit Breakers for Microservices](#pattern-2-multiple-circuit-breakers-for-microservices)
15. [Platform Cache Framework (UTIL_Cache)](#platform-cache-framework-util_cache)
    - [Architecture](#architecture-3)
    - [KernDX vs OOTB: Platform Cache Comparison](#kerndx-vs-ootb-platform-cache-comparison)
      - [Salesforce Out-of-the-Box Alternative](#salesforce-out-of-the-box-alternative)
      - [Pros & Cons Comparison](#pros--cons-comparison)
      - [When to Use KernDX UTIL_Cache](#when-to-use-kerndx-util_cache)
      - [When to Use OOTB Platform Cache](#when-to-use-ootb-platform-cache)
      - [Example Comparison](#example-comparison)
    - [Cache Types](#cache-types)
      - [Session Cache (User-Scoped)](#session-cache-user-scoped)
      - [Org Cache (Org-Wide)](#org-cache-org-wide)
      - [Auto Cache (Intelligent Selection)](#auto-cache-intelligent-selection)
    - [Basic Usage](#basic-usage-2)
      - [Storing and Retrieving Data](#storing-and-retrieving-data)
      - [Using Custom Partitions](#using-custom-partitions)
      - [Removing Data](#removing-data)
    - [TTL Management](#ttl-management)
      - [TTL Ranges](#ttl-ranges)
      - [Automatic TTL Enforcement](#automatic-ttl-enforcement)
      - [Default TTL (No Specification)](#default-ttl-no-specification)
    - [Automatic Compression](#automatic-compression)
      - [How Compression Works](#how-compression-works)
      - [Compression Algorithm](#compression-algorithm)
      - [When Compression Occurs](#when-compression-occurs)
      - [Compression Examples](#compression-examples)
      - [Compression Benefits](#compression-benefits)
      - [Performance Considerations](#performance-considerations)
      - [Transparent to Developers](#transparent-to-developers)
      - [Monitoring Compression](#monitoring-compression)
    - [Advanced Patterns](#advanced-patterns)
      - [Pattern 1: Cache-Aside (Lazy Loading)](#pattern-1-cache-aside-lazy-loading)
      - [Pattern 2: Write-Through Caching](#pattern-2-write-through-caching)
      - [Pattern 3: Cache Invalidation](#pattern-3-cache-invalidation)
      - [Pattern 4: Bulk Cache Operations](#pattern-4-bulk-cache-operations)
    - [Graceful Fallback Handling](#graceful-fallback-handling)
    - [Best Practices](#best-practices-2)
    - [Testing with Platform Cache](#testing-with-platform-cache)
      - [Testing Cache Availability](#testing-cache-availability)
      - [Testing Cache Functionality](#testing-cache-functionality)
16. [Type Resolution (UTIL_TypeResolver)](#type-resolution-util_typeresolver)
    - [Architecture](#architecture-4)
    - [Basic Usage](#basic-usage-3)
    - [Implementing a Custom Resolver](#implementing-a-custom-resolver)
    - [Registering Custom Resolvers](#registering-custom-resolvers)
    - [Testing the Custom Resolver](#testing-the-custom-resolver)
17. [Random Data Generation (UTIL_Random)](#random-data-generation-util_random)
    - [Architecture](#architecture-5)
    - [Basic Random Generation](#basic-random-generation)
    - [Salesforce ID Generation](#salesforce-id-generation)
18. [Advanced Data Indexing (MAP_SObject)](#advanced-data-indexing-map_sobject)
    - [Architecture](#architecture-6)
    - [Internal Architecture](#internal-architecture)
      - [Tree Structure Design](#tree-structure-design)
      - [Performance Characteristics](#performance-characteristics)
      - [Case-Insensitive Implementation](#case-insensitive-implementation)
    - [Basic Indexing](#basic-indexing)
    - [Case-Insensitive Indexing](#case-insensitive-indexing)
    - [Reference Field Traversal](#reference-field-traversal)
    - [Advanced Operations](#advanced-operations)
19. [Metadata Introspection (UTIL_SObjectDescribe)](#metadata-introspection-util_sobjectdescribe)
    - [Architecture](#architecture-7)
    - [Basic Usage](#basic-usage-4)
    - [Field Operations](#field-operations)
    - [Field Set Operations](#field-set-operations)
    - [Global Describe Operations](#global-describe-operations)
    - [Namespace Handling](#namespace-handling)
    - [Helper Methods](#helper-methods)
    - [Cache Management](#cache-management)
    - [Advanced Patterns](#advanced-patterns-1)
    - [Best Practices](#best-practices-3)
20. [Feature Flag Management (UTIL_FeatureFlag)](#feature-flag-management-util_featureflag)
    - [Architecture](#architecture-8)
    - [Basic Usage](#basic-usage-5)
    - [Strategy Types](#strategy-types)
    - [Implementing Custom Strategies](#implementing-custom-strategies)
    - [Best Practices](#best-practices-4)
    - [LWC Bridge](#lwc-bridge)
    - [User Context Evaluation](#user-context-evaluation)
    - [Performance and SOQL Cost](#performance-and-soql-cost)
      - [Why custom-setting strategies use SOQL](#why-custom-setting-strategies-use-soql)
      - [When SOQL becomes a problem — and what to do](#when-soql-becomes-a-problem--and-what-to-do)
21. [Logging Framework (LOG_Builder)](#logging-framework-log_builder)
    - [Quick Reference](#quick-reference)
22. [Omnistudio Integration (SVC_Omnistudio)](#omnistudio-integration-svc_omnistudio)
    - [Architecture](#architecture-9)
    - [Implementing Callable Classes](#implementing-callable-classes)
    - [Omnistudio Configuration](#omnistudio-configuration)
23. [Invocable Methods for Flows](#invocable-methods-for-flows)
    - [Logging from Flows (FLOW_WriteLog)](#logging-from-flows-flow_writelog)
    - [Email from Flows (FLOW_SendEmail)](#email-from-flows-flow_sendemail)
24. [Health Check](#health-check)
    - [Opening the Kern app](#opening-the-kern-app)
    - [Reading the results](#reading-the-results)
    - [What it checks](#what-it-checks)
    - [Built-in fixes](#built-in-fixes)
    - [Administration Tools](#administration-tools)
25. [Anti-Patterns](#anti-patterns)
26. [Best Practices](#best-practices-5)
    - [Type Resolution](#type-resolution-1)
    - [Random Data Generation](#random-data-generation)
    - [SObject Indexing](#sobject-indexing)
    - [Metadata Introspection](#metadata-introspection)
    - [Feature Flags](#feature-flags)
    - [Logging](#logging)
    - [Omnistudio Integration](#omnistudio-integration)
    - [Invocable Methods](#invocable-methods)
27. [Testing](#testing)
28. [Related Documentation](#related-documentation)

</details>

---

## Quick Navigation

| I am a...     | I need to...                      | Go to...                                                                                       |
|---------------|-----------------------------------|------------------------------------------------------------------------------------------------|
| **Admin**     | Verify my org is configured       | [Health Check](#health-check)                                                                  |
| **Architect** | Understand utility architecture   | [Architecture](#architecture)                                                                  |
| **Architect** | Design fault tolerance patterns   | [Circuit Breaker Framework](#circuit-breaker-framework-util_circuitbreaker)                     |
| **Developer** | Use common utilities              | [Quick Start](#quick-start)                                                                    |
| **Developer** | Implement retry strategies        | [Retry Strategy Framework](#retry-strategy-framework-util_retry)                               |
| **Developer** | Work with platform cache          | [Platform Cache Framework](#platform-cache-framework-util_cache)                               |
| **Analyst**   | Manage feature flags              | [Feature Flag Management](#feature-flag-management-util_featureflag)                           |
| **Analyst**   | Understand type resolution        | [Type Resolution](#type-resolution-util_typeresolver)                                          |

---

## Overview

This guide provides a comprehensive reference for the fundamental utility classes in the KernDX framework. These utilities cover the most common development tasks including string manipulation, date calculations, number formatting, collection operations, and system utilities.

> **Responsibilities:** Utility classes are stateless helpers. They perform transformations, validations, and calculations on data passed to
> them. They do not perform DML, query data, or manage state. If a utility grows beyond pure transformation, it likely belongs in a service
> class or framework component.

**What's Covered:**
- String operations and validation
- Date and time utilities
- Number formatting and validation
- Collection utilities (List, Map, Set)
- System utilities and type resolution
- JSON path navigation
- Performance timing
- And more...

**What's NOT Covered (See Other Guides):**
- `LOG_Builder` - See [Logging - Guide](Logging%20-%20Guide.md)
- Async utilities - See [Async Processing - Guide](Async%20Processing%20-%20Guide.md)

> **Utilities Scope:** `UTIL_*` classes plus `FLOW_*` invocable classes, covering string, date, collection, system, type resolution,
> circuit breaker, retry, cache, random data, feature flags, and SObject indexing. The Flow invocables expose framework capabilities to
> declarative automation.

---

## Architecture

The utility framework is organised into two tiers:

- **Basic Utilities** - Stateless helper classes for everyday operations: `UTIL_String`, `UTIL_Date`,
  `UTIL_List`, `UTIL_Map`, `UTIL_Set` (internal), `UTIL_Character` (internal),
  `UTIL_System`, `UTIL_Exceptions`, `UTIL_JsonPath`,
  `UTIL_Email`, `UTIL_StopWatch`,
  `UTIL_FormulaFilter`, `UTIL_BulkUpdates`, and `UTIL_PurgeRecords`
- **Advanced Utilities** - Stateful or metadata-driven frameworks: `UTIL_Retry` (retry strategies),
  `UTIL_CircuitBreaker` (fault tolerance), `UTIL_Cache` (platform cache), `UTIL_TypeResolver` (dynamic type
  resolution), `UTIL_Random` (random data generation), `MAP_SObject` (in-memory indexing),
  `UTIL_SObjectDescribe` (metadata introspection), `UTIL_FeatureFlag` (feature flags),
  `LOG_Builder` (logging), `SVC_Omnistudio` (Omnistudio integration), and Flow invocable methods

All utility classes use `global` or `public` access with `with sharing` or `inherited sharing` declarations. They
are designed to be called statically (e.g., `UTIL_String.abbreviate(value, 20)`) without instantiation, except for
builder/fluent APIs like `UTIL_Cache`.

---

## Quick Start

The most commonly used utilities are string validation, date arithmetic, and collection operations. Here are the patterns you will use most often:

```apex
// String validation
Boolean hasValue = String.isNotBlank(inputValue);
Id validId = UTIL_SObject.validateId(idString);

// Date arithmetic
Date nextBusinessDay = UTIL_Date.addBusinessDays(Date.today(), 5);
Boolean isWeekend = UTIL_Date.isWeekend(Date.today());

// Collection operations
List<List<SObject>> chunks = UTIL_List.partition(largeList, 200);
accounts.sort(new RevenueComparator()); // see "Sorting" below for the Comparator<SObject> pattern
```

For deeper coverage, continue reading the sections below.

---

## String Utilities

### [`UTIL_String`](reference/apex/UTIL_String.md)

[`UTIL_String`](reference/apex/UTIL_String.md) provides comprehensive string manipulation, validation, and transformation methods. It extends the capabilities of the standard Apex [`String`](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) class with null-safe operations and additional utilities.

#### ID Validation

```apex
/**
 * @description Safely validates and converts a string to a Salesforce ID.
 * Returns null if the string is not a valid ID format.
 */
Id accountId = UTIL_SObject.validateId('001xx000003DGb2AAG');

// Returns null if the string is not a valid 15 or 18-character ID
Id invalidId = UTIL_SObject.validateId('not-an-id'); // null
```

#### String Manipulation

```apex
// Abbreviate long strings
String abbreviated = UTIL_String.abbreviate('Now is the time for all good men', 20);
// Result: 'Now is the time f...'

// Abbreviate to fit an SObject field (uses field's maximum length)
String truncated = UTIL_String.abbreviate(longErrorMessage, LogEntry__c.Message__c);
// Result: String truncated to fit the Message__c field (32768 chars)

```

#### String Replacement

```apex
// Replace all occurrences
String replaced = UTIL_String.replace('aba', 'a', 'z');
// Result: 'zbz'

// Remove substring
String removed = UTIL_String.remove('Hello World', ' World');
// Result: 'Hello'
```

#### String Splitting & Joining

```apex
// Split by delimiter
List<String> parts = UTIL_String.split('a,b,c', ',');
// Result: ['a', 'b', 'c']

// Split with max
List<String> partMax = UTIL_String.split('a,b,c', ',', 2);
// Result: ['a', 'b,c']

// Join with separator
String joined = UTIL_String.join(new String[]{'a', 'b', 'c'}, ',');
// Result: 'a,b,c'
```

---

## Date & Time Utilities

### [`UTIL_Date`](reference/apex/UTIL_Date.md)

[`UTIL_Date`](reference/apex/UTIL_Date.md) provides weekend detection, business day arithmetic, ISO 8601 conversion, and date formatting utilities. It extends the capabilities of the standard Apex [`Date`](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_date.htm) and [`Datetime`](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_datetime.htm) classes.

#### Weekend & Weekday Detection

```apex
// Check if a date falls on Saturday or Sunday
Boolean isWeekend = UTIL_Date.isWeekend(Date.newInstance(2025, 9, 6));  // true (Saturday)
Boolean isWeekDay = UTIL_Date.isWeekDay(Date.newInstance(2025, 9, 5));  // true (Friday)

// Also works with Datetime
Boolean isWeekendDt = UTIL_Date.isWeekend(Datetime.now());
Boolean isWeekDayDt = UTIL_Date.isWeekDay(Datetime.now());

// Get the last weekday (Friday or earlier) relative to a date
Date lastWeekDay = UTIL_Date.lastWeekDay(Date.newInstance(2025, 9, 7));  // 2025-09-05 (Friday)
Date lastWeekDayToday = UTIL_Date.lastWeekDay();  // last weekday before today

// Get the first weekday (Monday or later) relative to a date
Date firstWeekDay = UTIL_Date.firstWeekDay(Date.newInstance(2025, 9, 7));  // 2025-09-08 (Monday)
```

#### Business Day Arithmetic

```apex
// Add business days (skips weekends)
Date result = UTIL_Date.addBusinessDays(Date.newInstance(2025, 9, 5), 3);
// Result: 2025-09-10 (Wednesday — skips Saturday and Sunday)

// Subtract business days (negative value)
Date earlier = UTIL_Date.addBusinessDays(Date.newInstance(2025, 9, 10), -3);
// Result: 2025-09-05 (Friday — skips weekend going backwards)
```

#### ISO 8601 Conversion

```apex
// Convert Datetime to ISO 8601 string
String isoDatetime = UTIL_Date.toIso8601(Datetime.newInstance(2025, 9, 5, 15, 30, 0));
// Result: '2025-09-05T15:30:00.000Z'

// Convert Date to ISO 8601 string
String isoDate = UTIL_Date.toIso8601(Date.newInstance(2025, 9, 5));
// Result: '2025-09-05'

// Parse ISO 8601 string to Datetime
Datetime parsedDatetime = UTIL_Date.dateTimeFromIso8601('2025-09-05T15:30:00.000Z');

// Parse ISO 8601 string to Date
Date parsedDate = UTIL_Date.dateFromIso8601('2025-09-05');

// Null inputs return Epoch (1970-01-01)
String epochIso = UTIL_Date.toIso8601((Date)null);
// Result: '1970-01-01'
```

#### Date Formatting

```apex
// Format a Date using Java SimpleDateFormat patterns
String formatted = UTIL_Date.formatDate(Date.newInstance(2025, 9, 5), 'MMMM d, yyyy');
// Result: 'September 5, 2025'

String shortDate = UTIL_Date.formatDate(Date.newInstance(2025, 9, 5), 'yyyy-MM-dd');
// Result: '2025-09-05'
```

#### Cron Expressions

```apex
// Generate a cron expression from a Datetime (useful for scheduling)
String cron = UTIL_Date.getCronExpression(Datetime.newInstance(2025, 9, 5, 15, 30, 0));
// Result: '0 30 15 5 9 ? 2025'
```

---


## Character Utilities

### `UTIL_Character`

`UTIL_Character` provides character-level operations used internally by the framework (`UTIL_String`, `UTIL_Random`).

> **Internal class** — `UTIL_Character` is `public` (not `global`). It is not accessible to subscriber code.

```apex
// Check if whitespace
Boolean isWhitespace = UTIL_Character.isWhitespace(' ');  // true

// Convert ASCII value to character
String character = UTIL_Character.toChar(65);  // 'A'

// Validate single-character string
UTIL_Character.validateChar('A');  // no exception
```

---

## Collection Utilities

### [`UTIL_List`](reference/apex/UTIL_List.md)

[`UTIL_List`](reference/apex/UTIL_List.md) provides list manipulation and transformation utilities, extending the standard Apex [`List`](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm) class.

```apex
// Check if list is empty (null-safe)
Boolean empty = UTIL_List.isEmpty(myList);

// Check if list is not empty (null-safe)
Boolean notEmpty = UTIL_List.isNotEmpty(myList);

// Partition list into chunks
List<List<SObject>> batches = UTIL_List.partition(records, 200);
```

> **Sorting:** `UTIL_List.sort(list, comparator)` together with `UTIL_Comparators` is framework-internal (declared `public`, not callable from subscriber Apex). For subscriber code, use the platform-native `Comparator<SObject>` interface directly — see the [Sorting](#sorting) section below.

### [`UTIL_Map`](reference/apex/UTIL_Map.md)

[`UTIL_Map`](reference/apex/UTIL_Map.md) provides map manipulation utilities, extending the standard Apex [`Map`](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_map.htm) class.

```apex
// Flatten map of lists to single list
List<SObject> flat = UTIL_Map.flattenValues(recordsByType);

// Convert map to delimited string
String delimited = UTIL_Map.toDelimitedString(myMap, '|');
```

### `UTIL_Set`

`UTIL_Set` provides set manipulation utilities used internally by the framework. This class is not part of the subscriber API.

### Sorting

Use the platform-native `Comparator<SObject>` interface. `UTIL_List.sort(...)` with `UTIL_Comparators.SObjectFieldComparator` is declared `public` and used only by framework internals; subscribers implement their own comparator and call `List.sort(comparator)`:

```apex
public with sharing class RevenueComparator implements Comparator<SObject>
{
	public Integer compare(SObject first, SObject second)
	{
		Decimal firstRevenue = (Decimal)first.get('AnnualRevenue');
		Decimal secondRevenue = (Decimal)second.get('AnnualRevenue');
		return firstRevenue < secondRevenue ? -1 : firstRevenue > secondRevenue ? 1 : 0;
	}
}

accountList.sort(new RevenueComparator());
```

---

## System & Reflection

### [`UTIL_System`](reference/apex/UTIL_System.md)

[`UTIL_System`](reference/apex/UTIL_System.md) provides system utilities and type resolution.

#### Type Resolution

```apex
// Get Type from class name (subscriber-first resolution via chain of responsibility)
Type myType = UTIL_System.getTypeForClassName('TRG_SetFoobarDefaults');

// Get Type with expected interface validation
Type handlerType = UTIL_System.getTypeForClassName('TRG_SetFoobarDefaults', IF_Trigger.BeforeInsert.class);

// Get runtime type name for an instance
String typeName = UTIL_System.getRuntimeTypeName(new Account());
// Result: 'Account'
```

#### Namespace & Environment

```apex
// Get managed package namespace (e.g., 'kern')
String namespace = UTIL_System.getManagedPackageNamespace();

// Get managed package namespace with delimiter (e.g., 'kern__')
String prefix = UTIL_System.getManagedPackageNamespacePrefix('__');

// Get namespace for a specific class
String classNamespace = UTIL_System.getClassNamespace('TRG_SetFoobarDefaults');

// Get namespace prefix with delimiter (e.g., 'kern.')
String nsPrefix = UTIL_System.getNamespacePrefix('kern', '.');

// Get API-enabled session ID (for callouts requiring session authentication)
String sessionId = UTIL_System.getApiEnabledSessionId();

// Get the org's current API version
String apiVersion = UTIL_System.getOrgApiVersion();
```

### [`UTIL_Exceptions`](reference/apex/UTIL_Exceptions.md)

[`UTIL_Exceptions`](reference/apex/UTIL_Exceptions.md) is a centralised container for framework-specific exception types. It groups related exception classes under a single outer class.

```apex
// Configuration missing or malformed
if(credential == null)
{
	throw new UTIL_Exceptions.ConfigurationException('Named credential not found for service: ' + serviceName);
}

// Record or resource not found
Foobar__c record = (Foobar__c)new SEL_Foobar().findById(recordId);
if(record == null)
{
	throw new UTIL_Exceptions.NotFoundException('Record does not exist: ' + recordId);
}

// Operation attempted on invalid state
if(isFinalized)
{
	throw new UTIL_Exceptions.IllegalStateException('Cannot modify a finalized transaction.');
}
```

---

## Data Processing

### [`UTIL_JsonPath`](reference/apex/UTIL_JsonPath.md)

[`UTIL_JsonPath`](reference/apex/UTIL_JsonPath.md) provides JSONPath navigation for querying JSON structures.

```apex
// Create JsonPath from JSON string
String jsonStr = '{"person":{"name":"John","age":30,"active":true}}';
UTIL_JsonPath jp = new UTIL_JsonPath(jsonStr);

// Get typed values by path
String name = jp.get('person.name').getStringValue();       // 'John'
Integer age = jp.get('person.age').getIntegerValue();        // 30
Boolean active = jp.get('person.active').getBooleanValue();  // true

// Check if path exists
Boolean exists = jp.exists('person.email');  // false

// Navigate to nested node
UTIL_JsonPath person = jp.get('person');
String personName = person.get('name').getStringValue();  // 'John'

// Get array elements
UTIL_JsonPath jpArray = new UTIL_JsonPath('[{"id":1},{"id":2}]');
Integer firstId = jpArray.get('[0].id').getIntegerValue();  // 1
```

---

## Specialized Utilities

### [`UTIL_Email`](reference/apex/UTIL_Email.md)

[`UTIL_Email`](reference/apex/UTIL_Email.md) provides email composition and sending utilities.

#### Email Validation

```apex
// Validate email address format
Boolean isValid = UTIL_Email.isValidEmailAddress('user@example.com');  // true

// Supports international characters
Boolean validIntl = UTIL_Email.isValidEmailAddress('user@example.jp');  // true
```

#### Check Email Deliverability

```apex
// Get org's email deliverability level
UTIL_Email.DeliverabilityAccessLevel level =
	UTIL_Email.getEmailDeliverabilityAccessLevel();

if(level == UTIL_Email.DeliverabilityAccessLevel.ALL_EMAIL)
{
	// Can send all emails
}
else if(level == UTIL_Email.DeliverabilityAccessLevel.SYSTEM_EMAIL_ONLY)
{
	// Only system emails allowed
}
else if(level == UTIL_Email.DeliverabilityAccessLevel.NO_ACCESS)
{
	// Email disabled
}
```

#### Send Email

```apex
// Send simple HTML email (pass null for no attachments)
UTIL_Email.sendEmail(
	new List<String>{'recipient@example.com'},
	'Subject Line',
	'<h1>Email Body</h1>',
	true,  // HTML format
	null   // No attachments
);

// Send plain text email with file attachments
Messaging.EmailFileAttachment fileAttachment = new Messaging.EmailFileAttachment();
fileAttachment.setFileName('report.csv');
fileAttachment.setBody(Blob.valueOf('data'));

UTIL_Email.sendEmail(
	new List<String>{'recipient@example.com'},
	'Subject',
	'Body text',
	false,  // Plain text
	new List<Messaging.EmailFileAttachment>{fileAttachment}
);
```

#### Working with Attachments

```apex
// Build an EmailFileAttachment from a Blob
Messaging.EmailFileAttachment fileAttachment = new Messaging.EmailFileAttachment();
fileAttachment.setFileName('report.csv');
fileAttachment.setContentType('text/csv');
fileAttachment.setBody(Blob.valueOf('Id,Name\n001xx,Acme'));

// Send email with the attachment
UTIL_Email.sendEmail(
	new List<String>{'recipient@example.com'},
	'Monthly Report',
	'<p>Please find the report attached.</p>',
	true,
	new List<Messaging.EmailFileAttachment>{fileAttachment}
);
```

### `UTIL_StopWatch`

`UTIL_StopWatch` is the **framework-internal** base class for the three specialised performance timers (`UTIL_PerformanceTimer`, `UTIL_QueryPerformanceTimer`, `UTIL_TriggerPerformanceTimer`). It is declared `public` (not `global`) and is not intended to be instantiated from subscriber Apex.

Framework consumers already get performance timing automatically: `TriggerSetting__mdt.EnablePerformanceLogging__c` times trigger actions, `ApiSetting__mdt` times API calls, and `UTIL_AsyncChain.ChainContext` carries timing through chain steps. For ad-hoc subscriber timing around a custom batch or callout, wrap the work in a `LOG_Builder.scope()` block — the scope captures start/end timestamps and emits a `LogEntryEvent__e` that feeds the same correlation pipeline.

```apex
kern.LOG_Builder.LogScope scope = kern.LOG_Builder.scope();
try
{
	// ... code to time ...
}
finally
{
	scope.close();
}
```

### [`UTIL_FormulaFilter`](reference/apex/UTIL_FormulaFilter.md)

[`UTIL_FormulaFilter`](reference/apex/UTIL_FormulaFilter.md) evaluates formula-based entry criteria against SObject records. It wraps the `FormulaEval` engine to filter trigger context records using boolean formulas.

```apex
// Create a formula filter with a process name, context class, and formula expression
UTIL_FormulaFilter formulaFilter = new UTIL_FormulaFilter(
	'AccountFilter',
	'UTIL_FormulaContext.AccountContext',
	'Name = "Acme" && Industry = "Technology"'
);

// Filter records — returns DTO_FilterResults with matched old/new record lists
UTIL_FormulaFilter.DTO_FilterResults results = formulaFilter.filter(
	Trigger.old,
	Trigger.new
);

// Access filtered records
List<SObject> matchedNewRecords = results.newRecords;
List<SObject> matchedOldRecords = results.oldRecords;
```

### [`UTIL_BulkUpdates`](reference/apex/UTIL_BulkUpdates.md)

[`UTIL_BulkUpdates`](reference/apex/UTIL_BulkUpdates.md) provides specialised bulk data operations for admin and maintenance tasks such as invalidating email fields, reassigning record ownership, updating fields in bulk, and deactivating inactive users. For standard DML operations, prefer using [`DML_Builder`](reference/apex/DML_Builder.md) instead.

```apex
// Invalidate email fields on an SObject (e.g., for sandbox data masking)
UTIL_BulkUpdates.invalidateEmailFields(Contact.Email);

// Invalidate with custom batch size and partial success
UTIL_BulkUpdates.invalidateEmailFields(Contact.Email, 200, false);

// Reassign record ownership from one profile to a new user
UTIL_BulkUpdates.updateOwner('Account', 'Old Profile', 'newowner@example.com');

// Deactivate users inactive for more than 90 days
UTIL_BulkUpdates.deactivateUsers(new Set<String>{'Standard User'}, 90);
```

### [`UTIL_PurgeRecords`](reference/apex/UTIL_PurgeRecords.md)

[`UTIL_PurgeRecords`](reference/apex/UTIL_PurgeRecords.md) provides batch record deletion utilities for data lifecycle management.

```apex
// Delete all records of an SObject type
UTIL_PurgeRecords.deleteAllRecords(LogEntry__c.SObjectType);

// Delete all records with custom batch size and partial success
UTIL_PurgeRecords.deleteAllRecords('LogEntry__c', false, 200);

// Delete records older than N days (based on CreatedDate)
UTIL_PurgeRecords.deleteOlderThanNDays('LogEntry__c', 90);

// Delete records older than N days using a custom date field
UTIL_PurgeRecords.deleteOlderThanNDays('LogEntry__c', 'EventDate__c', 365);
```


### [`UTIL_Limits`](reference/apex/UTIL_Limits.md)

Fluent interface for inspecting Salesforce governor limits. Wraps `System.Limits` with named factory
methods per limit type for IDE discoverability, threshold checks, and exhaustion guards.

```apex
// Check if callouts are exhausted
if(UTIL_Limits.callouts().isExhausted())
{
	// defer to async
}

// Threshold check — auto-normalises values > 1.0 (80 becomes 0.8)
if(UTIL_Limits.soqlQueries().isNearLimit(0.8))
{
	// approaching query limit
}

// Remaining budget
Integer calloutsLeft = UTIL_Limits.callouts().remaining();
Integer queryRowBudget = UTIL_Limits.soqlQueryRows().remaining();

// Percentage consumed (0.0–1.0)
Decimal cpuPercent = UTIL_Limits.cpuTime().percentUsed();

// Full snapshot for logging
String debugLimits = UTIL_Limits.toDebugString();
```

**Available limit types:** `aggregateQueries()`, `callouts()`, `cpuTime()`, `dmlRows()`,
`dmlStatements()`, `emailInvocations()`, `futureCalls()`, `heapSize()`, `mobilePushApexCalls()`,
`publishImmediateDml()`, `soqlQueries()`, `soqlQueryRows()`, `soqlQueryLocatorRows()`,
`queueableJobs()`, `soslQueries()`

**LimitCheck methods:** `used()`, `maximum()`, `remaining()`, `percentUsed()`, `isExhausted()`,
`isNearLimit(threshold)`


## Quick Reference Tables

### String Validation Quick Reference

| Check | Method | Example |
|-------|--------|---------|
| Is empty | `isEmpty(str)` | `''` -> `true` |
| Is blank | `isBlank(str)` | `'  '` -> `true` |
| Is not blank | `isNotBlank(str)` | `'text'` -> `true` |
| Valid email | `UTIL_Email.isValidEmailAddress(str)` | `'a@b.com'` -> `true` |
| Valid ID | `UTIL_SObject.validateId(str)` | `'001...'` -> `Id` or `null` |

### Date Calculation Quick Reference

| Operation | Method | Example |
|-----------|--------|---------|
| Is weekend | `isWeekend(date)` | `isWeekend(today)` |
| Is weekday | `isWeekDay(date)` | `isWeekDay(today)` |
| Add business days | `addBusinessDays(date, days)` | `addBusinessDays(today, 5)` |
| Last weekday | `lastWeekDay(date)` | `lastWeekDay(saturday)` |
| First weekday | `firstWeekDay(date)` | `firstWeekDay(sunday)` |
| To ISO 8601 | `toIso8601(date)` | `toIso8601(today)` |
| Format date | `formatDate(date, pattern)` | `formatDate(today, 'yyyy-MM-dd')` |
| Cron expression | `getCronExpression(datetime)` | `getCronExpression(scheduledTime)` |

### Collection Operations Quick Reference

| Operation | Method | Example |
|-----------|--------|---------|
| Partition | `UTIL_List.partition(list, size)` | Split into chunks |
| Sort by field | Platform-native `List.sort(comparator)` | Implement `Comparator<SObject>` — `UTIL_List.sort` + `UTIL_Comparators` are framework-internal |

---

## Retry Strategy Framework (UTIL_Retry)

### Architecture

The [`UTIL_Retry`](reference/apex/UTIL_Retry.md) framework provides a flexible, configurable approach to handling transient failures in external service calls, database operations, and other potentially unreliable operations. The framework implements the **Retry Pattern**, automatically calculating retry backoff periods and determining when to stop retrying.

**Key Components:**

1. **[`UTIL_Retry.Strategy`](reference/apex/UTIL_Retry.Strategy.md) Interface** - Contract for all retry strategy implementations
2. **[`UTIL_Retry.Context`](reference/apex/UTIL_Retry.Context.md) Interface** - Retry context containing attempt count, timing, and custom data
3. **Built-in Strategies** - Pre-configured patterns (exponential, linear) via factory methods
4. **Custom Strategy Support** - Extensible architecture for domain-specific retry logic
5. **Integration Points** - Native support in Web Services framework

**Core Capabilities:**

- **Multiple Retry Patterns** - Exponential backoff (recommended), linear backoff
- **Configurable Limits** - Control maximum retries, base backoff, and maximum backoff periods
- **Jitter Support** - Add randomness to backoff periods to prevent thundering herd
- **Circuit Breaker Integration** - Works seamlessly with [`UTIL_CircuitBreaker`](reference/apex/UTIL_CircuitBreaker.md) for fault tolerance
- **Web Service Integration** - Automatic retry for transient HTTP errors (429, 503, 504)
- **Fluent Configuration API** - Chain configuration methods for readable code

---

### Built-in Retry Strategies

The framework provides two pre-built strategies covering most common use cases:

#### Exponential Backoff Strategy (RECOMMENDED)

Doubles the delay after each retry. Recommended for most external API integrations to avoid overwhelming failing services and to handle rate limiting.

**Formula:** `delay = baseBackoff * (2 ^ retryCount)` (with optional jitter)

```apex
// Create exponential backoff: 10s, 20s, 40s, 80s, 160s (max 5 retries)
UTIL_Retry.Strategy strategy = UTIL_Retry.exponential()
	.withMaxRetries(5)
	.withBaseBackoff(10)
	.withJitter(true); // Add randomness to prevent thundering herd

// Use in retry logic
UTIL_Retry.Context context = UTIL_Retry.newContext(1); // First retry
if(strategy.shouldRetry(context))
{
	Integer backoffSeconds = strategy.calculateBackoff(context);
	// Schedule retry after backoffSeconds
}
```

#### Linear Backoff Strategy

Increases delay by a fixed increment after each retry. Suitable for services with predictable recovery patterns or when exponential growth is too aggressive.

**Formula:** `delay = baseBackoff * retryCount` (Note: retry 0 and 1 both use baseBackoff)

```apex
// Create linear backoff: 10s, 10s, 20s, 30s, 40s (max 5 retries)
UTIL_Retry.Strategy strategy = UTIL_Retry.linear()
	.withMaxRetries(5)
	.withBaseBackoff(10);

// Use in retry logic
UTIL_Retry.Context context = UTIL_Retry.newContext(2); // Second retry
if(strategy.shouldRetry(context))
{
	Integer backoffSeconds = strategy.calculateBackoff(context);
	// Schedule retry after backoffSeconds
}
```

---

### Backoff Calculation Algorithms

The framework implements precise mathematical algorithms for calculating retry delays.

#### Exponential Backoff Algorithm

The exponential backoff strategy uses the following calculation:

```text
result = baseBackoff * (multiplier ^ retryCount)
```

**Key Implementation Details:**

1. **Overflow Protection**: For `retryCount >= 31`, returns `maxBackoff` immediately to prevent `Math.pow()` overflow
2. **Multiplier Configuration**: Default multiplier is 2.0, but can be customized via `withExponentialMultiplier()`
3. **Maximum Cap**: Result is capped at `maxBackoff` (default: 300 seconds / 5 minutes)

**Example Progression** (baseBackoff=10, multiplier=2.0):
- Retry 0: 10 seconds
- Retry 1: 20 seconds
- Retry 2: 40 seconds
- Retry 3: 80 seconds
- Retry 4: 160 seconds
- Retry 5: 300 seconds (capped at maxBackoff)

#### Linear Backoff Algorithm

The linear backoff strategy uses a simpler calculation:

```text
result = retryCount <= 0 ? baseBackoff : baseBackoff * retryCount
```

**Example Progression** (baseBackoff=10):
- Retry 0: 10 seconds
- Retry 1: 10 seconds
- Retry 2: 20 seconds
- Retry 3: 30 seconds
- Retry 4: 40 seconds

**Note:** First retry (retry 0 and 1) uses baseBackoff directly.

#### Jitter Implementation

When jitter is enabled via `.withJitter(true)`, the framework adds randomness to prevent the "thundering herd" problem where multiple clients retry simultaneously:

**Algorithm:**
```text
maxJitter = currentBackoff * 0.25  // Up to 25% of calculated backoff
actualJitter = random(0, maxJitter)
finalBackoff = currentBackoff + actualJitter
finalBackoff = Math.min(finalBackoff, maxBackoff) // Ensure cap is respected
```

**Example:** For a calculated backoff of 40 seconds:
- Without jitter: Always 40 seconds
- With jitter: Between 40-50 seconds (randomized by up to 10 seconds)

**Use Case:** Essential for distributed systems where multiple instances might fail simultaneously (e.g., when external API goes down and affects all org users).

#### Custom Exponential Multiplier

For APIs with specific rate limit characteristics, you can customize the exponential growth rate:

```apex
// Faster backoff growth (3x instead of 2x)
UTIL_Retry.Strategy aggressive = UTIL_Retry.exponential()
	.withMaxRetries(5)
	.withBaseBackoff(5)
	.withExponentialMultiplier(3.0)  // 5s, 15s, 45s, 135s, 300s (capped)
	.withJitter(true);

// Slower backoff growth (1.5x)
UTIL_Retry.Strategy gradual = UTIL_Retry.exponential()
	.withMaxRetries(6)
	.withBaseBackoff(10)
	.withExponentialMultiplier(1.5)  // 10s, 15s, 22.5s, 33.75s, 50.6s, 75.9s
	.withJitter(false);
```

**Decision Table:**

| API Characteristic | Recommended Multiplier |
|--------------------|------------------------|
| Strict rate limits (e.g., 10 requests/minute) | 3.0+ (aggressive backoff) |
| Transient network failures | 2.0 (default) |
| Predictable recovery times | 1.5 (gradual backoff) |

---

### Basic Usage

The retry strategy framework is primarily used within the Web Services framework to handle transient failures. Here's how to use it:

#### 1. Using Retry Strategy in Web Service Classes

Override `createRetryStrategy()` in your API class to customize retry behavior:

```apex
public with sharing class API_SendEmail extends API_Outbound
{
	public override void configure()
	{
		super.configure();
		requestPayload = new DTO_EmailRequest();
		responsePayload = new DTO_EmailResponse();
		defaultMockBody = '{"success": true, "messageId": "msg-12345"}';
	}

	// Override to use exponential backoff for rate-limited API
	public override UTIL_Retry.Strategy createRetryStrategy()
	{
		return UTIL_Retry.exponential()
			.withMaxRetries(5)
			.withBaseBackoff(10)    // Start with 10s delay
			.withJitter(true);       // Add randomness
	}
}
```

#### 2. Manual Retry Logic (Advanced)

For custom retry logic outside the Web Services framework:

```apex
public with sharing class MyServiceCaller
{
	public static void callExternalService()
	{
		UTIL_Retry.Strategy strategy = UTIL_Retry.exponential()
			.withMaxRetries(3)
			.withBaseBackoff(5);

		Integer currentRetry = 0;
		Boolean success = false;

		while(!success)
		{
			try
			{
				// Attempt the operation
				makeHttpCallout();
				success = true;
			}
			catch(CalloutException e)
			{
				UTIL_Retry.Context context = UTIL_Retry.newContext(currentRetry);

				if(strategy.shouldRetry(context))
				{
					Integer backoffSeconds = strategy.calculateBackoff(context);
					LOG_Builder.build().debug('Retrying after ' + backoffSeconds + 's').emitAt('MyServiceCaller.callExternalService');

					// In practice, you'd schedule this for later
					// For synchronous operations, use UTIL_System.sleep()
					currentRetry++;
				}
				else
				{
					// Max retries exceeded
					throw e;
				}
			}
		}
	}
}
```

---

### Custom Retry Strategies

For specialized retry logic, implement the `UTIL_Retry.Strategy` interface:

```apex
public with sharing class RateLimitStrategy implements UTIL_Retry.Strategy
{
	private Integer maxRetries = 3;
	private Integer baseBackoff = 60; // 1 minute for rate limits

	public UTIL_Retry.Strategy withMaxRetries(Integer retries)
	{
		this.maxRetries = retries;
		return this;
	}

	public UTIL_Retry.Strategy withBaseBackoff(Integer seconds)
	{
		this.baseBackoff = seconds;
		return this;
	}

	public UTIL_Retry.Strategy withMaximumBackoff(Integer seconds)
	{
		// Not used in this strategy
		return this;
	}

	public UTIL_Retry.Strategy withJitter(Boolean enabled)
	{
		// Not used in this strategy
		return this;
	}

	public UTIL_Retry.Strategy withExponentialMultiplier(Decimal multiplier)
	{
		// Not used in this strategy
		return this;
	}

	public Boolean shouldRetry(UTIL_Retry.Context context)
	{
		// Allow retry if under max attempts
		return context.getRetryCount() < maxRetries;
	}

	public Integer calculateBackoff(UTIL_Retry.Context context)
	{
		// Custom logic: Check if rate limit header exists in context
		Map<String, Object> data = (Map<String, Object>)context.getCustomData();
		String rateLimitReset = data != null ? (String)data.get('X-Rate-Limit-Reset') : null;

		if(String.isNotBlank(rateLimitReset))
		{
			// Calculate seconds until rate limit resets
			Long resetTimestamp = Long.valueOf(rateLimitReset);
			Long currentTimestamp = Datetime.now().getTime() / 1000;
			Integer waitTime = (Integer)(resetTimestamp - currentTimestamp);

			return Math.max(waitTime, baseBackoff);
		}

		// Default backoff if no rate limit header
		return baseBackoff;
	}
}
```

**Usage in API Class:**

```apex
public with sharing class API_RateLimitedService extends API_Outbound
{
	public override UTIL_Retry.Strategy createRetryStrategy()
	{
		return new RateLimitStrategy()
			.withMaxRetries(3)
			.withBaseBackoff(60);
	}
}
```

---

### Integration with Web Services Framework

The Web Services framework automatically uses retry strategies for transient HTTP errors. The retry behavior is configured via:

1. **ApiSetting__mdt metadata** - Default configuration
2. **Override `createRetryStrategy()`** - Custom retry logic per API class

**Default Behavior (from ApiSetting__mdt):**

- Uses `linear()` strategy by default
- `MaxRetriesNo__c` field controls maximum retries (default: 3)
- `BackoffPeriod__c` field controls base backoff in seconds (default: 10)
- Retries on: HTTP 429 (Too Many Requests), 503 (Service Unavailable), 504 (Gateway Timeout)

**Custom Retry Strategy Example:**

```apex
public with sharing class API_SendEmail extends API_Outbound
{
	public override void configure()
	{
		super.configure();
		requestPayload = new DTO_SendEmailRequest();
		responsePayload = new DTO_SendEmailResponse();
		defaultMockBody = '{"success": true, "messageId": "msg-12345"}';
	}

	// Override for rate-limited API with exponential backoff
	public override UTIL_Retry.Strategy createRetryStrategy()
	{
		return UTIL_Retry.exponential()
			.withMaxRetries(5)
			.withBaseBackoff(10)    // 10s, 20s, 40s, 80s, 160s
			.withJitter(true);       // Add randomness to prevent thundering herd
	}
}
```

**How It Works:**

1. API call fails with transient error (429, 503, 504)
2. Framework calls `retry()` method
3. `retry()` calls `createRetryStrategy()` to get strategy instance
4. Framework creates `UTIL_Retry.Context` with current retry count
5. Strategy calculates backoff period via `calculateBackoff()`
6. ApiCall__c record updated with `NextScheduledRetry__c` timestamp
7. Scheduled job retries the call after backoff period

---

### Best Practices

#### 1. Choose the Right Strategy

| Scenario | Recommended Strategy | Rationale |
|----------|---------------------|-----------|
| **Rate-limited APIs (429)** | Exponential with Jitter | Gives service time to recover, prevents thundering herd |
| **Transient network errors** | Exponential with Jitter | Balances recovery time with request backoff |
| **Predictable failures** | Linear | Consistent backoff for known recovery patterns |
| **Custom rate limits** | Custom Strategy | Parse rate limit headers for optimal retry timing |

#### 2. Set Appropriate Maximum Retries

```apex
// BAD - Too many retries with exponential backoff
UTIL_Retry.exponential()
	.withMaxRetries(10)      // Could wait 10,230 seconds (2.8 hours)!
	.withBaseBackoff(10);

// GOOD - Conservative retry limit
UTIL_Retry.exponential()
	.withMaxRetries(5)       // Max wait: 10s + 20s + 40s + 80s + 160s = 310s (~5 min)
	.withBaseBackoff(10);

// ALSO GOOD - Linear for shorter total wait time
UTIL_Retry.linear()
	.withMaxRetries(3)       // Max wait: 10s + 20s + 30s = 60s (1 min)
	.withBaseBackoff(10);
```

#### 3. Retry Only Transient Errors

The Web Services framework automatically retries on transient HTTP errors (429, 503, 504). The `UTIL_Retry.Strategy` interface focuses on **when** and **how long** to wait, not **whether** to retry -- that decision is handled by the API framework based on HTTP status codes.

```apex
// Configure retry timing -- the framework decides which errors trigger retries
public override UTIL_Retry.Strategy createRetryStrategy()
{
	return UTIL_Retry.exponential()
		.withMaxRetries(3)
		.withBaseBackoff(10)
		.withJitter(true);
}
```

#### 4. Consider Governor Limits

```apex
// BAD - Exponential backoff can exceed CPU time limits
UTIL_Retry.exponential()
	.withMaxRetries(8)
	.withBaseBackoff(5000); // Could wait 640 seconds total!

// GOOD - Keep total retry time reasonable
UTIL_Retry.exponential()
	.withMaxRetries(4)
	.withBaseBackoff(1000); // Max wait: 1s + 2s + 4s + 8s = 15s
```

#### 5. Log Retry Attempts

The Web Services framework automatically logs retry attempts via `LOG_Builder`. To add custom logging when using retry strategies manually:

```apex
UTIL_Retry.Strategy strategy = UTIL_Retry.exponential()
	.withMaxRetries(3)
	.withBaseBackoff(10);

UTIL_Retry.Context context = UTIL_Retry.newContext(currentRetry);

if(strategy.shouldRetry(context))
{
	Integer backoffSeconds = strategy.calculateBackoff(context);
	LOG_Builder.build().debug('Scheduling retry ' + currentRetry + ' in ' + backoffSeconds + 's')
		.emitAt('MyClass.callService');
}
else
{
	LOG_Builder.build().error('All ' + currentRetry + ' retries exhausted')
		.emitAt('MyClass.callService');
}
```

#### 6. Use Circuit Breakers for Repeated Failures

For services with frequent failures, combine retry strategies with circuit breakers:

```apex
// Retry handles transient failures (1-3 attempts)
// Circuit breaker prevents cascade failures when service is down
UTIL_CircuitBreaker.Breaker breaker = UTIL_CircuitBreaker.monitor('API_SendEmail');

breaker.execute(new MyCalloutAction());
```

---

### Testing Retry Strategies

#### Testing Strategy Calculations

```apex
@IsTest
private static void shouldCalculateExponentialBackoff()
{
	UTIL_Retry.Strategy strategy = UTIL_Retry.exponential()
		.withMaxRetries(5)
		.withBaseBackoff(10);

	UTIL_Retry.Context firstRetry = UTIL_Retry.newContext(0);
	UTIL_Retry.Context secondRetry = UTIL_Retry.newContext(1);
	UTIL_Retry.Context sixthRetry = UTIL_Retry.newContext(5);

	Assert.isTrue(strategy.shouldRetry(firstRetry), 'Should retry on first attempt');
	Assert.areEqual(10, strategy.calculateBackoff(firstRetry), 'First backoff should be 10s');
	Assert.areEqual(20, strategy.calculateBackoff(secondRetry), 'Second backoff should be 20s');
	Assert.isFalse(strategy.shouldRetry(sixthRetry), 'Should not retry beyond max');
}
```

---

### Common Patterns

#### Pattern 1: Using Retry Strategy in Web Service Classes

The primary use case for `UTIL_Retry` is within the Web Services framework. Override `createRetryStrategy()` to customize how your API handles transient failures:

```apex
public with sharing class API_PaymentGateway extends API_Outbound
{
	public override void configure()
	{
		super.configure();
		requestPayload = new DTO_Request();
		responsePayload = new DTO_Response();
		defaultMockBody = '{"transactionId": "txn-12345"}';
	}

	// Custom retry for rate-limited payment API
	public override UTIL_Retry.Strategy createRetryStrategy()
	{
		return UTIL_Retry.exponential()
			.withMaxRetries(4)
			.withBaseBackoff(10)     // 10s, 20s, 40s, 80s
			.withJitter(true);        // Prevent thundering herd
	}
}
```

#### Pattern 2: Manual Retry Decision Logic

For scenarios outside the Web Services framework, use the strategy to calculate backoff timing:

```apex
UTIL_Retry.Strategy strategy = UTIL_Retry.linear()
	.withMaxRetries(3)
	.withBaseBackoff(10);

Integer currentRetry = 0;
UTIL_Retry.Context context = UTIL_Retry.newContext(currentRetry);

if(strategy.shouldRetry(context))
{
	Integer backoffSeconds = strategy.calculateBackoff(context);
	// Schedule retry after backoffSeconds (e.g., via platform event or scheduled job)
	LOG_Builder.build().debug('Scheduling retry in ' + backoffSeconds + 's').emitAt('MyClass.myMethod');
}
else
{
	// Max retries exceeded, handle failure
	LOG_Builder.build().error('All retry attempts exhausted').emitAt('MyClass.myMethod');
}
```

---

## Circuit Breaker Framework (UTIL_CircuitBreaker)

### Architecture

The [`UTIL_CircuitBreaker`](reference/apex/UTIL_CircuitBreaker.md) framework implements the **Circuit Breaker Pattern** to prevent cascading failures and improve system resilience when calling external services or unreliable operations. It acts as a "smart fuse" that monitors failures and temporarily blocks calls to failing services, allowing them time to recover.

**Key Components:**

1. **[`UTIL_CircuitBreaker.Breaker`](reference/apex/UTIL_CircuitBreaker.Breaker.md) Interface** - Core circuit breaker contract with execute, state, and metrics methods
2. **[`UTIL_CircuitBreaker.ProtectedAction`](reference/apex/UTIL_CircuitBreaker.ProtectedAction.md) Interface** - Contract for operations to wrap with circuit protection
3. **Circuit States** - CLOSED (normal), OPEN (blocking calls), HALF_OPEN (testing recovery)
4. **Failure Tracking** - Monitors consecutive failures and failure rates
5. **Platform Cache Integration** - Persists circuit state across transaction boundaries
6. **Metadata Configuration** - Configure circuit parameters via [`ApiSetting__mdt`](reference/metadata/ApiSetting__mdt.md)

**Core Capabilities:**

- **Automatic State Management** - Transitions between states based on failure thresholds
- **Configurable Thresholds** - Control failure limits, timeout periods, and test intervals
- **Graceful Degradation** - Fast-fail when service is down instead of waiting for timeouts
- **Cross-Transaction Persistence** - Uses Platform Cache to maintain state across requests
- **Web Service Integration** - Automatic circuit breaker for all Web Service framework callouts

---

### Circuit States

The circuit breaker operates in three states:

#### 1. CLOSED (Normal Operation)

- **Behavior:** All requests pass through to the underlying service
- **Monitoring:** Tracks failure count for each request
- **Transition:** Moves to OPEN when consecutive failures exceed threshold

```text
┌─────────────┐
│   CLOSED    │ ◄── Initial state, all calls allowed
│             │
│ ✓ Success   │ ◄── Resets failure count
│ ✗ Failure   │ ◄── Increments failure count
└─────────────┘
      │
      │ Failures >= threshold
      ▼
┌─────────────┐
│    OPEN     │
└─────────────┘
```

#### 2. OPEN (Blocking Calls)

- **Behavior:** Immediately rejects all requests without calling the service
- **Purpose:** Gives failing service time to recover, prevents resource waste
- **Monitoring:** Tracks time since circuit opened
- **Transition:** Moves to HALF_OPEN after timeout period expires

```text
┌─────────────┐
│    OPEN     │ ◄── All calls blocked
│             │
│ ⊘ Blocked   │ ◄── Throws CircuitOpenException
│ ⊘ Blocked   │
└─────────────┘
      │
      │ Timeout expires
      ▼
┌─────────────┐
│ HALF_OPEN   │
└─────────────┘
```

#### 3. HALF_OPEN (Testing Recovery)

- **Behavior:** Allows a limited number of test requests through
- **Purpose:** Verify if service has recovered
- **Monitoring:** Tracks success/failure of test requests
- **Transition:**
  - Success → CLOSED (service recovered)
  - Failure → OPEN (service still failing)

```text
┌─────────────┐
│ HALF_OPEN   │ ◄── Allow test requests
│             │
│ ✓ Success   │ ──► CLOSED (recovered)
│ ✗ Failure   │ ──► OPEN (still failing)
└─────────────┘
```

---

### State Transition Algorithm

The circuit breaker implements a sophisticated state machine with automatic transitions based on failure/success tracking and timeout periods.

#### CLOSED → OPEN Transition

**Trigger:** `failureCount >= failureThreshold` (default: 5 failures)

**What happens:**
- Sets `state = OPEN`
- Records `lastFailureTime = Datetime.now()`
- Resets `consecutiveSuccesses = 0`
- Resets `halfOpenAttempts = 0`
- Sets `skipNextUpdate = true` (prevents immediate re-check)
- Logs warning with failure count

**Example:**
```apex
// Failures accumulate in CLOSED state
breaker.recordFailure(); // failureCount = 1
breaker.recordFailure(); // failureCount = 2
breaker.recordFailure(); // failureCount = 3
breaker.recordFailure(); // failureCount = 4
breaker.recordFailure(); // failureCount = 5 → Transitions to OPEN
```

#### OPEN → HALF_OPEN Transition

**Trigger:** Timeout period elapsed (default: 60 seconds since last failure)

**Algorithm:**
```apex
if(state == OPEN && lastFailureTime != null)
{
	Long secondsSinceFailure = (Datetime.now().getTime() - lastFailureTime.getTime()) / 1000;

	// Check if timeout period has elapsed
	if(secondsSinceFailure > timeoutSeconds)
	{
		// Transition to HALF_OPEN for recovery testing
		state = HALF_OPEN;
		halfOpenAttempts = 0;
		consecutiveSuccesses = 0;
	}
}
```

**What happens:**
- Sets `state = HALF_OPEN`
- Resets `halfOpenAttempts = 0`
- Resets `consecutiveSuccesses = 0`
- Records `stateChangedTime`
- Logs info message

**Example Timeline:**
```text
T=0:00  → Circuit opens (5 failures)
T=0:30  → Still OPEN (timeout not reached)
T=1:00  → Timeout expires → Transitions to HALF_OPEN
T=1:01  → First test request allowed through
```

#### HALF_OPEN → CLOSED Transition

**Trigger:** `consecutiveSuccesses >= successThreshold` (default: 2 successes)

**What happens:**
- Sets `state = CLOSED`
- Resets ALL counters to 0
- Records `stateChangedTime`
- Logs info message

**Example:**
```apex
// In HALF_OPEN state, test recovery
breaker.recordSuccess(); // consecutiveSuccesses = 1
breaker.recordSuccess(); // consecutiveSuccesses = 2 → Transitions to CLOSED (service recovered!)
```

#### HALF_OPEN → OPEN Transition

**Trigger:** ANY failure in HALF_OPEN state

**Rationale:** Conservative approach - service must prove stability with multiple consecutive successes. A single failure indicates service is still unstable.

**What happens:**
- Immediately transitions back to OPEN
- Must wait another full timeout period before retrying

**Example:**
```apex
// In HALF_OPEN state, testing recovery
breaker.recordSuccess(); // consecutiveSuccesses = 1
breaker.recordFailure(); // ANY failure → Back to OPEN immediately
```

#### HALF_OPEN Request Limiting

To prevent overwhelming a recovering service, HALF_OPEN state limits concurrent test requests:

**Default Configuration:** `halfOpenMaxAttempts = 3`

**Behavior:**
```text
when HALF_OPEN
{
	Boolean allowed = halfOpenAttempts < halfOpenMaxAttempts;
	if(allowed)
	{
		halfOpenAttempts++;  // Increment attempt counter
		saveState();  // Persist immediately
	}
	return allowed;
}
```

**Example Scenario:**
1. Circuit opens after 5 failures
2. After 60 seconds timeout, transitions to HALF_OPEN
3. First 3 requests are allowed through (testing recovery)
4. Remaining requests blocked until state changes
5. If all 3 succeed → CLOSED; if any fail → OPEN

#### Platform Cache State Management

**Cache Partition:** Uses framework standard `Library` partition:
- Unmanaged: `local.Library`
- Managed: `{Namespace}.Library`

**TTL Buffer Implementation:**

The framework adds a 5-minute (300 second) buffer to cache TTL to ensure state survives the timeout period:

```apex
// Timeout = 60 seconds, Cache TTL = 60 + 300 = 360 seconds
Integer ttlWithBuffer = timeoutSeconds + 300;
cache.put(circuitId, currentState, ttlWithBuffer);
```

**Why the buffer is critical:**

Without buffer:
```text
T=0    Circuit opens, cache TTL = 60s
T=60   Timeout expires (should transition to HALF_OPEN)
       BUT cache entry also expires → state lost!
       Result: Hard reset to CLOSED, skipping recovery verification
```

With buffer:
```text
T=0    Circuit opens, cache TTL = 360s
T=60   Timeout expires AND state still exists in cache
       Successful transition to HALF_OPEN for recovery testing
T=360  State expires (5 minutes after recovery window)
```

**Graceful Degradation:**

If Platform Cache partition doesn't exist:
- Circuit breaker still functions
- State stored in-memory (per-transaction)
- Suitable for testing, **not production**
- State NOT shared across transactions

---

### Basic Usage

#### 1. Using Default Configuration

```apex
// Create circuit breaker with default settings
UTIL_CircuitBreaker.Breaker breaker = UTIL_CircuitBreaker.monitor('MyService');

// Execute operation with circuit breaker protection
try
{
	Object result = breaker.execute(new MyServiceOperation());
	LOG_Builder.build().info('Operation succeeded: ' + result).emitAt('MyClass.myMethod');
}
catch(UTIL_CircuitBreaker.OpenException e)
{
	// Circuit is open, service unavailable
	LOG_Builder.build().error(e).emitAt('MyClass.myMethod');
	// Handle gracefully (return cached data, show error message, etc.)
}
```

#### 2. Implementing the Circuit Breaker Operation

Use `ProtectedAction` for void operations or `Provider` for operations that return a value:

```apex
// Void operation (no return value)
public with sharing class MyServiceAction implements UTIL_CircuitBreaker.ProtectedAction
{
	public void execute()
	{
		// Your operation logic here
		HttpRequest request = new HttpRequest();
		request.setEndpoint('https://api.example.com/data');
		request.setMethod('POST');
		request.setTimeout(30000);

		Http http = new Http();
		HttpResponse response = http.send(request);

		if(response.getStatusCode() != 200)
		{
			throw new CalloutException('API returned: ' + response.getStatusCode());
		}
	}
}

// Operation with return value
public with sharing class MyServiceProvider implements UTIL_CircuitBreaker.Provider
{
	public Object execute()
	{
		HttpRequest request = new HttpRequest();
		request.setEndpoint('https://api.example.com/data');
		request.setMethod('GET');
		request.setTimeout(30000);

		Http http = new Http();
		HttpResponse response = http.send(request);

		if(response.getStatusCode() != 200)
		{
			throw new CalloutException('API returned: ' + response.getStatusCode());
		}

		return JSON.deserializeUntyped(response.getBody());
	}
}
```

#### 3. Customizing Circuit Breaker Configuration

```apex
// Use fluent API to customize behavior
UTIL_CircuitBreaker.Breaker breaker = UTIL_CircuitBreaker.monitor('MyService')
	.withFailureThreshold(5)        // Open after 5 consecutive failures
	.withTimeout(120)                // Stay open for 2 minutes
	.withHalfOpenMaxAttempts(3);  // Allow 3 test requests when half-open

Object result = breaker.execute(new MyServiceOperation());
```

---

### Metadata Configuration

For production deployments, configure circuit breakers via [`ApiSetting__mdt`](reference/metadata/ApiSetting__mdt.md) custom metadata:

#### Create [`ApiSetting__mdt`](reference/metadata/ApiSetting__mdt.md) Record

| Field | Value | Description |
|-------|-------|-------------|
| **Label** | My External API | Human-readable name |
| **DeveloperName** | My_External_API | Unique identifier (used in code) |
| **CircuitBreakerFailureThreshold__c** | 5 | Open circuit after 5 consecutive failures |
| **CircuitBreakerTimeout__c** | 60 | Keep circuit open for 60 seconds |
| **CircuitBreakerHalfOpenRequests__c** | 2 | Allow 2 test requests when half-open |

#### Use in Code

```apex
// Circuit breaker automatically loads configuration from metadata
UTIL_CircuitBreaker.Breaker breaker =
	UTIL_CircuitBreaker.monitor('My_External_API');

Object result = breaker.execute(new MyAPICallout());
```

**Benefits:**

- ✅ No code deployment to change thresholds
- ✅ Different settings per environment (sandbox vs production)
- ✅ Centralized configuration management
- ✅ Easy A/B testing of different thresholds

---

### Integration with Web Services Framework

The Web Services framework automatically applies circuit breaker protection to all outbound API calls:

```apex
public with sharing class API_SendEmail extends API_Outbound
{
	public override void configure()
	{
		super.configure();
		requestPayload = new DTO_SendEmailRequest();
		responsePayload = new DTO_SendEmailResponse();
	}

	// Circuit breaker is automatically applied!
	// Configuration loaded from ApiSetting__mdt
}
```

**Automatic Behavior:**

1. Framework creates circuit breaker using service name from [`ApiSetting__mdt`](reference/metadata/ApiSetting__mdt.md)
2. All HTTP requests execute through circuit breaker
3. Failures increment circuit failure count
4. When threshold exceeded, circuit opens and blocks subsequent calls
5. After timeout, circuit enters half-open state to test recovery

**Custom Circuit Breaker Configuration (Advanced):**

Configure circuit breaker thresholds per API via [`ApiSetting__mdt`](reference/metadata/ApiSetting__mdt.md) fields (`CircuitBreakerFailureThreshold__c`, `CircuitBreakerTimeout__c`, `CircuitBreakerHalfOpenRequests__c`). No code override is needed -- the framework reads these values from metadata automatically.

---

### Advanced Configuration

#### Configuring Failure Threshold

```apex
// Low threshold - Fail fast for critical services
UTIL_CircuitBreaker.monitor('CriticalPaymentAPI')
	.withFailureThreshold(2)  // Open after 2 failures
	.withTimeout(300);        // Give 5 minutes to recover

// High threshold - More tolerant for flaky services
UTIL_CircuitBreaker.monitor('FlakyReportingAPI')
	.withFailureThreshold(10) // Open after 10 failures
	.withTimeout(60);         // Test recovery after 1 minute
```

#### Configuring Timeout Period

```apex
// Short timeout - Quick recovery testing
UTIL_CircuitBreaker.monitor('FastRecoveryService')
	.withTimeout(30);  // Try again after 30 seconds

// Long timeout - Give service time to fully recover
UTIL_CircuitBreaker.monitor('SlowRecoveryService')
	.withTimeout(600); // Wait 10 minutes before testing
```

#### Configuring Half-Open Test Requests

```apex
// Single test request - Conservative approach
UTIL_CircuitBreaker.monitor('ConservativeService')
	.withHalfOpenMaxAttempts(1); // One test request to verify recovery

// Multiple test requests - More confident recovery detection
UTIL_CircuitBreaker.monitor('RobustService')
	.withHalfOpenMaxAttempts(5); // Require 5 successful tests before closing
```

---

### Platform Cache Integration

Circuit breakers use Platform Cache to persist state across transaction boundaries and org-wide visibility.

#### Cache Behavior

```apex
// Circuit state is automatically cached
UTIL_CircuitBreaker.Breaker breaker = UTIL_CircuitBreaker.monitor('MyService');

// First transaction - Circuit opens due to failures
breaker.execute(new FailingOperation()); // Throws exception

// Second transaction (different user, different request)
// Circuit is still OPEN (state persisted in cache)
breaker.execute(new AnyOperation()); // Immediately throws CircuitOpenException
```

#### Cache TTL Management

The framework automatically manages cache TTL to ensure circuit state persists appropriately:

- **Cache TTL** = `timeout + 300` (adds 5-minute buffer beyond timeout period)
- **Minimum TTL** = 300 seconds (Salesforce platform constraint)
- **Maximum TTL** = 172,800 seconds (48 hours for Org cache)
- **Timeout Control** = Managed by `lastFailureTime` timestamp, not cache expiration

**Example:**

```apex
// Circuit with 60 second timeout
UTIL_CircuitBreaker.monitor('MyService')
	.withTimeout(60);

// Cache TTL = 60 + 300 = 360 seconds
// Circuit timeout controlled by timestamp: lastFailureTime + 60s
// Cache persists state 5 minutes beyond timeout period
```

**Edge Case:** If cache expires before timeout completes, circuit resets to CLOSED state. This is acceptable behavior - the circuit will relearn failure patterns if service is still down.

---

### Best Practices

#### 1. Choose Appropriate Thresholds

| Service Type | Failure Threshold | Timeout | Rationale |
|--------------|-------------------|---------|-----------|
| **Critical Payment APIs** | 2-3 failures | 5-10 minutes | Low tolerance, long recovery |
| **Non-Critical Reporting** | 5-10 failures | 1-2 minutes | Higher tolerance, quick retry |
| **Internal Services** | 3-5 failures | 30-60 seconds | Moderate tolerance, fast recovery |
| **Rate-Limited APIs** | 5 failures | 60 seconds | Match rate limit reset window |

#### 2. Combine with Retry Strategies

```apex
// Circuit breaker prevents cascade failures (service down)
// Retry strategy handles transient errors (network blip)
UTIL_CircuitBreaker.Breaker breaker =
	UTIL_CircuitBreaker.monitor('ExternalAPI');

breaker.execute(new MyRetryableCalloutAction());
```

#### 3. Handle Circuit Open Exceptions Gracefully

```apex
try
{
	Object result = breaker.execute(new MyServiceOperation());
	return result;
}
catch(UTIL_CircuitBreaker.OpenException e)
{
	// Service is down, return cached data or default value
	LOG_Builder.build().error(e).emitAt('MyClass.myMethod');
	return getCachedData(); // Graceful degradation
}
catch(Exception e)
{
	// Actual service failure
	LOG_Builder.build().error(e).emitAt('MyClass.myMethod');
	throw e;
}
```

#### 4. Monitor Circuit State

```apex
UTIL_CircuitBreaker.Breaker breaker = UTIL_CircuitBreaker.monitor('MyService');

// Check circuit state before executing
String state = breaker.getState(); // Returns 'CLOSED', 'OPEN', or 'HALF_OPEN'

if(state == 'OPEN')
{
	LOG_Builder.build().warn('Circuit is open, service unavailable').emitAt('MyClass.myMethod');
	// Use fallback logic without attempting call
	return getCachedData();
}

// Circuit is closed or half-open, safe to proceed
Object result = breaker.execute(new MyServiceOperation());
```

#### 5. Use Unique Circuit IDs

```apex
// BAD - Same circuit ID for different endpoints
UTIL_CircuitBreaker.monitor('ExternalAPI'); // Which endpoint?

// GOOD - Unique circuit ID per endpoint
UTIL_CircuitBreaker.monitor('ExternalAPI_GetCustomers');
UTIL_CircuitBreaker.monitor('ExternalAPI_CreateOrder');
UTIL_CircuitBreaker.monitor('ExternalAPI_UpdateInventory');
```

#### 6. Consider Environment-Specific Configuration

```text
Development - More tolerant for testing
ApiSetting__mdt devSettings:
- CircuitBreakerFailureThreshold__c: 10
- CircuitBreakerTimeout__c: 30

Production - Stricter for reliability
ApiSetting__mdt prodSettings:
- CircuitBreakerFailureThreshold__c: 3
- CircuitBreakerTimeout__c: 300
```

---

### Testing Circuit Breakers

#### Testing Circuit State Transitions

```apex
@IsTest
private static void shouldOpenCircuitAfterFailures()
{
	LOG_Builder.ignoreTestMode = true;

	UTIL_CircuitBreaker.Breaker breaker =
		UTIL_CircuitBreaker.monitor('TestService')
			.withFailureThreshold(3)
			.withTimeout(60);

	// Cause 3 failures to open circuit
	for(Integer i = 0; i < 3; i++)
	{
		try
		{
			breaker.execute(new AlwaysFailOperation());
			Assert.fail('Should have thrown exception');
		}
		catch(Exception e)
		{
			// Expected
		}
	}

	// Circuit should now be open
	try
	{
		breaker.execute(new AnyOperation());
		Assert.fail('Circuit should be open');
	}
	catch(UTIL_CircuitBreaker.OpenException e)
	{
		Assert.isTrue(e.getMessage().contains('Circuit breaker is OPEN'));
	}
}

private class AlwaysFailOperation implements UTIL_CircuitBreaker.ProtectedAction
{
	public void execute()
	{
		throw new CalloutException('Simulated failure');
	}
}
```

#### Testing Cache Persistence

```apex
@IsTest
private static void shouldPersistStateInCache()
{
	LOG_Builder.ignoreTestMode = true;

	UTIL_CircuitBreaker.Breaker breaker1 =
		UTIL_CircuitBreaker.monitor('TestService')
			.withFailureThreshold(2);

	// Open circuit in first instance
	for(Integer i = 0; i < 2; i++)
	{
		try { breaker1.execute(new AlwaysFailOperation()); } catch(Exception e) {}
	}

	// Create new instance - should load OPEN state from cache
	UTIL_CircuitBreaker.Breaker breaker2 =
		UTIL_CircuitBreaker.monitor('TestService');

	try
	{
		breaker2.execute(new AnyOperation());
		Assert.fail('Circuit should be open from cache');
	}
	catch(UTIL_CircuitBreaker.OpenException e)
	{
		// Expected - state loaded from cache
	}
}
```

---

### Common Patterns

#### Pattern 1: Circuit Breaker with Fallback

```apex
public with sharing class CustomerService
{
	private static final UTIL_CircuitBreaker.Breaker breaker =
		UTIL_CircuitBreaker.monitor('CustomerAPI');

	public static Customer getCustomer(Id customerId)
	{
		try
		{
			// Try primary API
			return (Customer)breaker.execute(new GetCustomerOperation(customerId));
		}
		catch(UTIL_CircuitBreaker.OpenException e)
		{
			// Circuit open - use cached data
			LOG_Builder.build().error(e).emitAt('CustomerService.getCustomer');
			return getCustomerFromCache(customerId);
		}
		catch(Exception e)
		{
			// API call failed - log and fallback
			LOG_Builder.build().error(e).emitAt('CustomerService.getCustomer');
			return getCustomerFromCache(customerId);
		}
	}

	private static Customer getCustomerFromCache(Id customerId)
	{
		// Return cached data or default object
		UTIL_Cache.Store cache = UTIL_Cache.org();
		Customer cached = (Customer)cache.get('Customer_' + customerId);
		return cached != null ? cached : new Customer();
	}
}
```

#### Pattern 2: Multiple Circuit Breakers for Microservices

```apex
public with sharing class OrderProcessingService
{
	private static final UTIL_CircuitBreaker.Breaker inventoryBreaker =
		UTIL_CircuitBreaker.monitor('InventoryService');

	private static final UTIL_CircuitBreaker.Breaker paymentBreaker =
		UTIL_CircuitBreaker.monitor('PaymentService');

	private static final UTIL_CircuitBreaker.Breaker shippingBreaker =
		UTIL_CircuitBreaker.monitor('ShippingService');

	public static OrderResult processOrder(Order order)
	{
		// Check inventory
		Boolean inventoryAvailable = (Boolean)inventoryBreaker.execute(
			new CheckInventoryOperation(order)
		);

		if(!inventoryAvailable)
		{
			return new OrderResult(false, 'Inventory unavailable');
		}

		// Process payment
		PaymentResult payment = (PaymentResult)paymentBreaker.execute(
			new ProcessPaymentOperation(order)
		);

		if(!payment.success)
		{
			return new OrderResult(false, 'Payment failed');
		}

		// Create shipment
		ShipmentResult shipment = (ShipmentResult)shippingBreaker.execute(
			new CreateShipmentOperation(order)
		);

		return new OrderResult(true, 'Order processed successfully');
	}
}
```

---

## Platform Cache Framework (UTIL_Cache)

### Architecture

The [`UTIL_Cache`](reference/apex/UTIL_Cache.md) framework provides a robust, intelligent wrapper around Salesforce Platform Cache with automatic compression, automatic fallback, TTL management, and graceful error handling.

**Key Components:**

1. **[`UTIL_Cache.Store`](reference/apex/UTIL_Cache.Store.md) Interface** - Core cache contract with put, get, contains, remove, and clear methods
2. **[`UTIL_Cache.OperationResult`](reference/apex/UTIL_Cache.OperationResult.md)** - Detailed result object with success status and operation metadata
3. **[`UTIL_Cache.Status`](reference/apex/UTIL_Cache.Status.md) Enum** - Status codes for cache operations (SUCCESS, TTL_INVALID, WRITE_FAILURE, etc.)
4. **Automatic Compression** - ZIP compression for payloads >4KB (80-90% space savings)
5. **Cache Type Abstraction** - Session, Org, Auto (durable Session→Org dispatch), and In-Transaction (per-request in-memory tier via the `inTransaction()` factory or the opt-in graceful `autoWithTransactionFallback()` composite)
6. **TTL Enforcement** - Automatic validation of minimum/maximum cache lifetimes
7. **Graceful Fallback** - Continues operation even when cache unavailable
8. **Partition Management** - Automatic partition detection and configuration
9. **Bulk Operations** - Efficient batch put/get for multiple keys

**Core Capabilities:**

- **Transparent Compression** - Large payloads automatically compressed/decompressed using ZIP
- **Automatic Platform Cache Setup** - Detects and uses available partitions
- **TTL Range Enforcement** - Validates 300s minimum, 28,800s/172,800s maximum
- **Cache Availability Detection** - Gracefully handles missing/full partitions
- **User-Scoped Caching** - Session cache for user-specific data
- **Org-Wide Caching** - Org cache for shared data across users
- **Circuit Breaker Integration** - Used by circuit breakers for state persistence

---

### KernDX vs OOTB: Platform Cache Comparison

#### Salesforce Out-of-the-Box Alternative

Salesforce provides **Platform Cache** with direct API access:

1. **Cache.Session** - User session-scoped cache
2. **Cache.Org** - Org-wide cache
3. **Cache.SessionPartition / Cache.OrgPartition** - Partition-based access

#### Pros & Cons Comparison

| Feature | KernDX [`UTIL_Cache`](reference/apex/UTIL_Cache.md) | Salesforce OOTB Cache API |
|---------|-------------------------------------|---------------------------|
| **Automatic Compression** | ✅ Auto-compresses payloads >4KB (ZIP), saves 80-90% cache space | ❌ No compression, full payload cached |
| **Automatic Fallback** | ✅ AUTO mode with Session→Org fallback | ❌ Must manually implement fallback logic |
| **TTL Validation** | ✅ Enforces min/max TTL ranges (300s-28800s/172800s) | ⚠️ Accepts invalid TTLs but may silently fail |
| **Sub-300s TTL Support** | ✅ Wrapper tracks validity for TTLs <300s | ❌ Platform minimum is 300s |
| **Availability Detection** | ✅ `isCacheAvailable()` checks before operations | ❌ Must manually check partition existence |
| **Graceful Degradation** | ✅ Returns false on failure, doesn't throw exceptions | ⚠️ Throws exceptions on invalid partition/full cache |
| **Error Reporting** | ✅ `getLastOperationResult()` with detailed status | ❌ No built-in error reporting |
| **User Scoping** | ✅ `withUserScope(true)` for user-specific keys | ❌ Must manually prefix keys with userId |
| **Bulk Operations** | ✅ `putAll()` and `getAll()` for batch operations | ❌ Must loop manually for multiple keys |
| **Partition Auto-Detection** | ✅ Automatically finds default partition | ❌ Must hardcode partition names |
| **Key Safety** | ✅ Auto-sanitizes keys (hashes long keys, handles special chars) | ⚠️ Manual key sanitization required |
| **Usage Complexity** | ✅ Same simple put/get API as OOTB | ✅ Simple put/get API |
| **Setup** | ⚠️ Requires Platform Cache partition creation | ⚠️ Requires Platform Cache partition creation |
| **Performance** | ⚠️ Overhead from compression + validation (CPU for cache space trade-off) | ✅ Direct cache access, minimal overhead |
| **Flexibility** | ⚠️ Opinionated patterns (e.g., forced compression >4KB) | ✅ Full control over cache operations |

#### When to Use KernDX UTIL_Cache

- ✅ Need automatic fallback between Session and Org cache
- ✅ Want graceful error handling without exceptions
- ✅ Require user-scoped cache keys without manual prefixing
- ✅ Need TTL validation to prevent silent failures
- ✅ Want detailed operation result tracking
- ✅ Building resilient systems that work even when cache is unavailable
- ✅ Need bulk cache operations for multiple keys

#### When to Use OOTB Platform Cache

- ✅ Maximum performance is critical (no wrapper overhead)
- ✅ Simple caching needs with known partition names
- ✅ You want complete control over cache behavior
- ✅ Building low-level cache utilities or frameworks
- ✅ You don't need fallback or error handling logic

#### Example Comparison

**OOTB Platform Cache (Manual Error Handling):**
```apex
// Must manually handle partition errors and TTL validation
try
{
	Cache.OrgPartition partition = Cache.Org.getPartition('local.MyPartition');

	// No TTL validation - could silently fail
	partition.put('myKey', myValue, 100); // Invalid TTL < 300s!

	Object value = partition.get('myKey');
}
catch(Cache.Org.OrgCacheException e)
{
	// Manual error handling required
	LOG_Builder.build().error('Cache error: ' + e.getMessage()).emitAt('MyClass.myMethod');
}
```

**KernDX Platform Cache (Automatic Handling):**
```apex
// Automatic partition detection, sub-300s TTL support, graceful errors
UTIL_Cache.Store cache = UTIL_Cache.org();

// Sub-300s TTL supported via wrapper validity tracking
Boolean success = cache.put('myKey', myValue, 100); // Returns true, valid for 100s

if(!success)
{
	// Check detailed error status (e.g., partition unavailable, entry too large)
	UTIL_Cache.OperationResult result = cache.getLastOperationResult();
	LOG_Builder.build().warn('Cache failed: ' + result.status).emitAt('MyClass.myMethod');
}
```

---

### Cache Types

The framework supports three cache types with automatic TTL validation:

#### Session Cache (User-Scoped)

- **Scope:** Current user session only
- **Lifetime:** 5 minutes to 8 hours (300s - 28,800s)
- **Use Cases:** User preferences, temporary UI state, user-specific API tokens
- **Cleanup:** Automatically cleared when user session ends

```apex
UTIL_Cache.Store cache = UTIL_Cache.session();

// Store user preferences
cache.put('UserTheme', 'dark', 3600); // 1 hour TTL

// Retrieve
String theme = (String)cache.get('UserTheme');
```

#### Org Cache (Org-Wide)

- **Scope:** All users in org
- **Lifetime:** 5 minutes to 48 hours (300s - 172,800s)
- **Use Cases:** Configuration data, picklist values, metadata, circuit breaker state
- **Cleanup:** Expires after TTL or manually removed

```apex
UTIL_Cache.Store cache = UTIL_Cache.org();

// Store configuration (shared across all users)
cache.put('APIEndpoints', endpointMap, 7200); // 2 hour TTL

// Retrieve
Map<String, String> endpoints = (Map<String, String>)cache.get('APIEndpoints');
```

#### Auto Cache (Intelligent Selection)

- **Behavior:** Framework automatically selects Session or Org cache based on availability. `auto()` is durable-only: when neither Session nor Org cache is allocated, the operation reports `Status.CACHE_UNAVAILABLE` instead of silently degrading. Use the opt-in `autoWithTransactionFallback()` factory when graceful in-memory degradation matters more than strict durability — the composite reports `cacheTypeUsed = Scope.IN_TRANSACTION` on the fallback path so callers can detect the degraded scope.
- **Fallback:** If primary cache unavailable, tries secondary cache type
- **Use Case:** When you don't care about scope, just want caching. Choose `auto()` for durability-required workloads (security keys, distributed counters). Choose `autoWithTransactionFallback()` for memoization that prefers Platform Cache but should still work when it's missing.

```apex
UTIL_Cache.Store cache = UTIL_Cache.auto();

// Framework chooses best available cache
cache.put('TempData', data, 600); // 10 minutes TTL
```

---

### Basic Usage

#### Storing and Retrieving Data

```apex
// Get cache instance
UTIL_Cache.Store cache = UTIL_Cache.org();

// Store data
cache.put('ConfigKey', configData, 3600); // 1 hour TTL

// Retrieve data
ConfigData data = (ConfigData)cache.get('ConfigKey');

if(data == null)
{
	// Cache miss - load from database
	data = loadConfigFromDatabase();
	cache.put('ConfigKey', data, 3600);
}
```

#### Using Custom Partitions

```apex
// Use specific partition
UTIL_Cache.Store cache = UTIL_Cache.org()
	.withPartition('local.CustomPartition');

cache.put('Key', 'Value', 600);
```

#### Removing Data

```apex
UTIL_Cache.Store cache = UTIL_Cache.org();

// Remove single key
cache.remove('OldKey');

// Check if key exists
Boolean exists = cache.contains('MyKey');
```

---

### TTL Management

The framework automatically enforces platform cache TTL constraints:

#### TTL Ranges

| Cache Type | Minimum TTL | Maximum TTL | Platform Constraint |
|------------|-------------|-------------|---------------------|
| **Session Cache** | 300 seconds (5 min) | 28,800 seconds (8 hours) | Platform enforced |
| **Org Cache** | 300 seconds (5 min) | 172,800 seconds (48 hours) | Platform enforced |

#### Automatic TTL Enforcement

```apex
UTIL_Cache.Store cache = UTIL_Cache.org();

// ✅ TTL below platform minimum - Wrapper tracks actual validity at 100s,
//    Platform Cache TTL clamped to 300s. Entry expires after 100s via validUntil check.
cache.put('Key1', 'Value', 100); // Returns true, valid for 100s

// ✅ TTL within range - Used as-is
cache.put('Key2', 'Value', 3600); // Stays 3600s (1 hour)

// ❌ TTL above maximum - Automatically capped at 172,800s
cache.put('Key3', 'Value', 200000); // Becomes 172,800s (48 hours)
```

#### Default TTL (No Specification)

```apex
// No TTL specified - Uses default (varies by cache type)
cache.put('Key', 'Value'); // Uses platform default TTL
```

---

### Automatic Compression

The framework **automatically compresses large payloads** to optimize cache space utilization, which is typically more constrained than CPU resources in Salesforce.

#### How Compression Works

**Automatic Threshold-Based Compression:**
```apex
UTIL_Cache.Store cache = UTIL_Cache.org();

// Small payload (< 4KB) - NO compression
String smallData = 'Small configuration value';
cache.put('SmallKey', smallData, 3600); // Stored as-is

// Large payload (> 4KB) - AUTOMATIC compression via ZIP
List<Account> accounts = queryLargeAccountList(); // 500 records, ~100KB serialized
cache.put('Accounts', accounts, 3600); // Automatically compressed to ~10-20KB
```

**Compression Details:**

| Property | Value |
|----------|-------|
| **Compression Method** | ZIP compression via `Compression.ZipWriter` |
| **Threshold** | 4,096 bytes (4 KB) - payloads larger than this are compressed |
| **Typical Compression Ratio** | 80-90% space savings for JSON data |
| **Performance Trade-off** | CPU time for compression vs. cache space savings |
| **Safety Check** | Only uses compressed version if it's actually smaller than original |

#### Compression Algorithm

Location: `UTIL_Cache.cls` (lines 332-356)

```apex
// Internal implementation (simplified)
private static Blob compressData(String jsonString)
{
	Compression.ZipWriter zipWriter = new Compression.ZipWriter();
	zipWriter.addEntry('data.json', Blob.valueOf(jsonString));
	return zipWriter.getArchive();
}

private static String decompressData(Blob compressedData)
{
	Compression.ZipReader zipReader = new Compression.ZipReader(compressedData);
	return zipReader.extract('data.json').toString();
}
```

#### When Compression Occurs

**Compression Decision Tree:**

```text
Put operation
    │
    ├─ Serialize value to JSON
    │
    ├─ Check size
    │   │
    │   ├─ Size ≤ 4KB → Store as-is (no compression)
    │   │
    │   └─ Size > 4KB → Attempt ZIP compression
    │       │
    │       ├─ Compressed size < Original size?
    │       │   │
    │       │   ├─ Yes → Store compressed version
    │       │   │
    │       │   └─ No → Store original (edge case: already compressed data)
    │       │
    │       └─ Compression fails? → Store original (graceful fallback)
```

#### Compression Examples

**Example 1: Large Account List (High Compression)**

```apex
UTIL_Cache.Store cache = UTIL_Cache.org();

// Query 500 accounts with multiple fields
List<Account> accounts = QRY_Builder.selectFrom(Account.SObjectType)
	.fields(new List<SObjectField>
	{
		Account.Id, Account.Name, Account.BillingStreet, Account.BillingCity,
		Account.BillingState, Account.Phone, Account.Industry, Account.AnnualRevenue
	})
	.addField(Account.Description)
	.withLimit(500)
	.toList();

// Original JSON size: ~120 KB
// Compressed size: ~12 KB (90% reduction)
cache.put('LargeAccountList', accounts, 3600);

// Retrieval is transparent - automatic decompression
List<Account> retrieved = (List<Account>)cache.get('LargeAccountList');
```

**Example 2: Small Configuration (No Compression)**

```apex
// Small config map: ~2 KB serialized JSON
Map<String, String> config = new Map<String, String>
{
	'ApiEndpoint' => 'https://api.example.com',
	'ApiTimeout' => '30',
	'RetryCount' => '3'
};

// Below 4 KB threshold - stored without compression
cache.put('ApiConfig', config, 7200);
```

**Example 3: Edge Case - Random Data (Compression Skipped)**

```apex
// Generate random string (doesn't compress well)
String randomData = UTIL_Random.randomAlphabetic(10000); // 10 KB of random data

// Compression attempted but result is larger than original (ZIP overhead)
// Framework detects this and stores ORIGINAL uncompressed version
cache.put('RandomData', randomData, 600);
```

#### Compression Benefits

**Cache Space Optimization:**

Without compression:
- 10 MB cache partition
- 500 KB per large object graph
- **Capacity: ~20 cached objects**

With automatic compression (90% reduction):
- 10 MB cache partition
- 50 KB per compressed object graph
- **Capacity: ~200 cached objects** (10x improvement!)

**Real-World Example:**

```apex
// Circuit breaker state: ~100 bytes uncompressed
UTIL_Cache.Store cache = UTIL_Cache.org();
cache.put('CircuitBreaker_API_SendGrid', circuitState, 360);
// No compression (below threshold)

// Picklist values for all objects: ~150 KB uncompressed
Map<String, List<String>> allPicklists = loadAllPicklistValues();
cache.put('AllPicklists', allPicklists, 7200);
// Compressed to ~15 KB (90% savings)
// Allows caching 10x more data in same partition
```

#### Performance Considerations

**Compression Overhead:**

| Operation | Without Compression | With Compression (>4KB) |
|-----------|---------------------|-------------------------|
| **Put (small)** | ~1-2 ms | ~1-2 ms (no compression) |
| **Put (large)** | ~3-5 ms | ~15-25 ms (ZIP compression) |
| **Get (small)** | ~1-2 ms | ~1-2 ms (no decompression) |
| **Get (large)** | ~3-5 ms | ~8-12 ms (ZIP decompression) |
| **Cache Space** | 100% | 10-20% (80-90% savings) |

**Trade-off Analysis:**

✅ **When Compression is Beneficial:**
- Caching large object graphs (lists of SObjects, complex DTOs)
- Cache partition space is limited
- Data is read frequently (compression cost amortized over many reads)
- Cache hit ratio is high (decompression overhead justified)

⚠️ **When to Avoid Large Payloads:**
- Time-critical operations requiring sub-10ms cache access
- Frequently updated data (compression cost on every write)
- Data that doesn't compress well (already compressed, random data)

#### Transparent to Developers

**Key Point: Compression is completely automatic and transparent:**

```apex
// Put operation - compression happens automatically if payload > 4KB
cache.put('LargeData', myLargeObject, 3600);

// Get operation - decompression happens automatically
Object retrieved = cache.get('LargeData');

// Developer doesn't need to know or care about compression
// Framework handles it internally based on size threshold
```

#### Monitoring Compression

While compression is transparent, you can monitor its effectiveness:

```apex
// Before caching
String serialized = JSON.serialize(myObject);
Integer originalSize = serialized.length();

// After retrieving from cache (check wrapper metadata in tests)
// In production, compression details are abstracted away
UTIL_Cache.Store cache = UTIL_Cache.org();
cache.put('MyKey', myObject, 3600);

// The DTO_CacheEntry wrapper tracks:
// - isCompressed: Boolean flag
// - originalSize: Size before compression
// - data: Blob (if compressed) or String (if not)
```

---

### Advanced Patterns

#### Pattern 1: Cache-Aside (Lazy Loading)

```apex
public with sharing class PicklistValueService
{
	private static final String CACHE_KEY = 'PicklistValues_';
	private static final UTIL_Cache.Store cache =
		UTIL_Cache.org();

	public static List<String> getPicklistValues(String objectName, String fieldName)
	{
		String cacheKey = CACHE_KEY + objectName + '_' + fieldName;

		// Try cache first
		List<String> values = (List<String>)cache.get(cacheKey);

		if(values == null)
		{
			// Cache miss - load from schema
			values = loadPicklistValuesFromSchema(objectName, fieldName);

			// Store in cache for 1 hour
			cache.put(cacheKey, values, 3600);
		}

		return values;
	}

	private static List<String> loadPicklistValuesFromSchema(String objectName, String fieldName)
	{
		// Schema describe logic here
		List<String> values = new List<String>();
		// ... populate from schema
		return values;
	}
}
```

#### Pattern 2: Write-Through Caching

```apex
public with sharing class ConfigurationManager
{
	private static final UTIL_Cache.Store cache =
		UTIL_Cache.org();

	public static void updateConfiguration(String key, String value)
	{
		// Write to database
		Configuration__c config = new Configuration__c(
			Name = key,
			Value__c = value
		);
		DML_Builder.newTransaction().doUpsert(config, Configuration__c.Name).execute();

		// Write to cache (keep in sync)
		cache.put('Config_' + key, value, 7200); // 2 hours
	}

	public static String getConfiguration(String key)
	{
		// Try cache first
		String value = (String)cache.get('Config_' + key);

		if(value == null)
		{
			// Load from database
			Configuration__c config = (Configuration__c)QRY_Builder.selectFrom(Configuration__c.SObjectType)
				.addField(Configuration__c.Value__c)
				.condition(Configuration__c.Name).equals(key)
				.getFirst();

			if(config != null)
			{
				value = config.Value__c;
				cache.put('Config_' + key, value, 7200);
			}
		}

		return value;
	}
}
```

#### Pattern 3: Cache Invalidation

```apex
public with sharing class ProductCatalogService
{
	private static final String CACHE_PREFIX = 'Product_';
	private static final UTIL_Cache.Store cache =
		UTIL_Cache.org();

	public static void updateProduct(Product__c product)
	{
		// Update database
		DML_Builder.newTransaction().doUpdate(product).execute();

		// Invalidate cache
		cache.remove(CACHE_PREFIX + product.Id);
	}

	public static Product__c getProduct(Id productId)
	{
		String cacheKey = CACHE_PREFIX + productId;
		Product__c product = (Product__c)cache.get(cacheKey);

		if(product == null)
		{
			product = (Product__c)QRY_Builder.selectFrom(Product__c.SObjectType)
				.addFields(new List<SObjectField>{Product__c.Id, Product__c.Name, Product__c.Price__c})
				.condition(Product__c.Id).equals(productId)
				.getFirst();
			cache.put(cacheKey, product, 1800); // 30 minutes
		}

		return product;
	}
}
```

#### Pattern 4: Bulk Cache Operations

```apex
public with sharing class BulkCacheLoader
{
	private static final UTIL_Cache.Store cache =
		UTIL_Cache.org();

	public static void loadMultipleConfigurations(Set<String> configKeys)
	{
		Map<String, String> configs = new Map<String, String>();

		// Load from database using QRY_Builder
		List<Configuration__c> configList = QRY_Builder.selectFrom(Configuration__c.SObjectType)
			.addFields(new List<SObjectField>{Configuration__c.Name, Configuration__c.Value__c})
			.condition(Configuration__c.Name).isIn(configKeys)
			.toList();

		for(Configuration__c config : configList)
		{
			configs.put(config.Name, config.Value__c);
		}

		// Bulk put to cache
		for(String key : configs.keySet())
		{
			cache.put('Config_' + key, configs.get(key), 3600);
		}
	}
}
```

---

### Graceful Fallback Handling

The framework gracefully handles cache unavailability:

```apex
UTIL_Cache.Store cache = UTIL_Cache.org();

// Attempt to cache data
Boolean success = cache.put('Key', 'Value', 600);

if(!success)
{
	// Cache write failed (partition full, unavailable, etc.)
	// Application continues without caching
	LOG_Builder.build().debug('Cache unavailable, continuing without cache').emitAt('MyClass.myMethod');
}

// Always safe to attempt retrieval
Object value = cache.get('Key'); // Returns null if cache unavailable
```

---

### Best Practices

#### 1. Choose Appropriate Cache Type

| Data Scope | Cache Type | Example |
|------------|------------|---------|
| **User-specific** | Session | User preferences, UI state, user tokens |
| **Org-wide** | Org | Picklist values, configuration, metadata |
| **Don't care** | Auto | Temporary calculations, non-critical data |

#### 2. Set Appropriate TTL

```apex
// ❌ BAD - Too short, defeats caching purpose
cache.put('Config', data, 300); // 5 minutes - constantly reloading

// ✅ GOOD - Balances freshness and performance
cache.put('Config', data, 3600); // 1 hour - reasonable refresh

// ❌ BAD - Too long, stale data risk
cache.put('ProductPrice', price, 172800); // 48 hours - price changes missed

// ✅ GOOD - Fresh data for volatile information
cache.put('ProductPrice', price, 900); // 15 minutes - recent prices
```

#### 3. Always Handle Cache Misses

```apex
// BAD - Assumes cache always works
Object data = cache.get('Key');
return data; // Might return null!

// GOOD - Handles cache miss gracefully
Object data = cache.get('Key');
if(data == null)
{
	data = loadFromDatabase();
	cache.put('Key', data, 3600);
}
return data;
```

#### 4. Use Consistent Key Naming

```apex
// ✅ GOOD - Consistent, readable key naming
private static final String CACHE_KEY_PREFIX = 'Product_';
String cacheKey = CACHE_KEY_PREFIX + productId;

// ❌ BAD - Inconsistent, hard to debug
cache.put('prod' + id, data);
cache.put('product_' + id, data);
cache.put(id.toString(), data);
```

#### 5. Monitor Cache Size

```apex
// Be mindful of cache partition size limits
// Session cache: typically 10 MB
// Org cache: typically 10 MB (varies by license)

// ❌ BAD - Caching large query results
List<Account> allAccounts = QRY_Builder.selectFrom(Account.SObjectType)
	.addFields(new List<SObjectField>{Account.Id, Account.Name})
	.toList(); // 10,000 records
cache.put('AllAccounts', allAccounts, 3600); // Might exceed cache size!

// ✅ GOOD - Cache smaller, frequently accessed subsets
List<Account> activeAccounts = QRY_Builder.selectFrom(Account.SObjectType)
	.addFields(new List<SObjectField>{Account.Id, Account.Name})
	.condition(Account.IsActive__c).equals(true)
	.withLimit(100)
	.toList();
cache.put('ActiveAccounts', activeAccounts, 3600);
```

#### 6. Invalidate on Updates

```apex
public with sharing class AccountTriggerHandler
{
	private static final UTIL_Cache.Store cache =
		UTIL_Cache.org();

	public static void afterUpdate(List<Account> accounts)
	{
		// Invalidate cache for updated accounts
		for(Account account : accounts)
		{
			cache.remove('Account_' + account.Id);
		}
	}
}
```

#### 7. Don't Use Cache for Counters or Semaphores

`UTIL_Cache` is **not atomic across transactions**. Salesforce Platform Cache exposes no
compare-and-swap, no atomic-increment, and no cross-transaction lock primitive — so a
read-modify-write pattern silently loses writes under concurrent load.

**The wrong pattern (loses 85-94% of writes under 100-parallel contention):**

```apex
// ❌ BAD - read-modify-write is non-atomic; concurrent transactions clobber each other
UTIL_Cache.Store cache = UTIL_Cache.org();
Integer current = (Integer)cache.get('counter') ?? 0;
cache.put('counter', current + 1);
```

Empirically: 100 parallel HTTP POSTs each running the snippet above land the counter at
**6-15** (not 100). All 100 calls return `WRITE_SUCCESS` from their own transaction's
perspective — there is no observable signal that another transaction overwrote your put.

**The right pattern — custom object + `FOR UPDATE` row lock:**

```apex
// ✅ GOOD - SOQL FOR UPDATE is the only Salesforce-native atomic-increment primitive.
//
// Pre-requisites in your subscriber org (NOT shipped with KernDX):
//   1. Create a custom object: RateCounter__c
//   2. Add a Number field: Value__c (length 18, scale 0)
//   3. Seed the counter row at admin / install time (one row per counter name) so the
//      .forUpdate() lock has a row to grab on the first concurrent call. Without seeding,
//      two parallel "first callers" both find the empty list, both build a new
//      RateCounter__c, and race to insert — the lock only protects the second-and-later
//      increments.
public static Integer atomicIncrement(String counterName)
{
	RateCounter__c counter = (RateCounter__c)QRY_Builder.selectFrom(RateCounter__c.SObjectType)
		.fields(new List<SObjectField>{RateCounter__c.Value__c})
		.condition(RateCounter__c.Name).equals(counterName)
		.forUpdate()
		.getFirst();

	if(counter == null)
	{
		throw new IllegalStateException(
			'RateCounter__c row "' + counterName + '" must be seeded before increment');
	}

	counter.Value__c = (counter.Value__c == null ? 0 : counter.Value__c) + 1;
	DML_Builder.newTransaction().doUpdate(counter).execute();
	return counter.Value__c.intValue();
}
```

The `forUpdate()` clause holds a row-level lock until the enclosing transaction commits,
so concurrent transactions queue rather than overwrite. Use this pattern for rate
counters, deduplication caches, distributed semaphores, and any other case where
"the value I write must be based on the current value, atomically". The seed-the-row
prerequisite avoids the "first call has no row to lock" race; if you can't seed at
admin time, an alternative is to upsert against a custom External ID field (so concurrent
inserts are deduplicated by the platform) and then re-query with `forUpdate()` for the
increment — at the cost of a second round-trip on the cold path.

`UTIL_Cache` remains the right choice for **read-mostly** caches: configuration data,
picklist lookups, fully-formed query results, anything where a stale read is acceptable
and writes are infrequent and safe to overwrite.

---

### Testing with Platform Cache

#### Testing Cache Availability

```apex
@IsTest
private static void shouldHandleCacheUnavailable()
{
	LOG_Builder.ignoreTestMode = true;

	// Use invalid partition to simulate cache unavailability
	String invalidPartition = 'local.Invalid_' + System.currentTimeMillis();
	UTIL_Cache.Store cache = UTIL_Cache.org()
		.withPartition(invalidPartition);

	Test.startTest();
	Boolean putResult = cache.put('Key', 'Value', 600);
	Object getValue = cache.get('Key');
	Test.stopTest();

	// Framework should handle gracefully
	Assert.isFalse(putResult, 'Put should fail with invalid partition');
	Assert.isNull(getValue, 'Get should return null');
}
```

#### Testing Cache Functionality

```apex
@IsTest
private static void shouldCacheAndRetrieveData()
{
	UTIL_Cache.Store cache = UTIL_Cache.org();

	Test.startTest();
	Boolean putResult = cache.put('TestKey', 'TestValue', 600);
	Object getValue = cache.get('TestKey');
	Test.stopTest();

	// If cache is available, should work
	if(putResult)
	{
		Assert.areEqual('TestValue', getValue, 'Should retrieve cached value');
	}
	else
	{
		// Cache unavailable in test context (acceptable)
		Assert.isNull(getValue, 'Should return null when cache unavailable');
	}
}
```

---

## Type Resolution (UTIL_TypeResolver)

### Architecture

The [`UTIL_TypeResolver`](reference/apex/UTIL_TypeResolver.md) utility provides a robust mechanism for dynamically resolving and instantiating Apex classes by name, particularly useful in managed package environments where namespace handling and nested classes require special attention.

**Key Components:**

- **[`INT_ClassTypeResolver`](reference/apex/UTIL_TypeResolver.INT_ClassTypeResolver.md)** - Global interface for implementing custom type resolvers
- **[`BaseClassResolver`](reference/apex/UTIL_TypeResolver.BaseClassResolver.md)** - Abstract base class providing chain of responsibility pattern
- **`PackageClassResolver`** - Default resolver handling managed package classes and namespaces
- **Custom Metadata Configuration** - [`ClassTypeResolver__mdt`](reference/metadata/ClassTypeResolver__mdt.md) for registering custom resolvers

**How It Works:**

The type resolver uses the Chain of Responsibility pattern to attempt resolution through multiple strategies:

1. **Package Resolver** - First attempts to resolve types within the managed package namespace
2. **Custom Resolver** - Falls back to a custom resolver registered via custom metadata
3. **Chaining** - Multiple resolvers can be chained together for complex resolution scenarios

### Basic Usage

**Resolving a Type:**

```apex
// Resolve a class type by name using the default resolver chain
// Resolve a standard class
UTIL_TypeResolver.INT_ClassTypeResolver resolver = UTIL_TypeResolver.getClassResolver();
Type myClassType = resolver.resolveType('UTIL_TypeResolver_TEST.MyPackagePrivateClass');

if(myClassType != null)
{
	Object instance = myClassType.newInstance();
	// Successfully instantiated
}
```

### Implementing a Custom Resolver

Subscriber organizations can extend the framework by implementing custom resolvers:

```apex
/**
 * @description Subscriber org resolver implementation
 *
 * @see UTIL_TypeResolver
 *
 * @author your.name@company.com
 *
 * @group Utilities
 *
 * @date March 2025
 */
global with sharing class CMN_UTIL_ClassNameResolver extends kern.UTIL_TypeResolver.BaseClassResolver
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
	 * @param className The class name to resolve (include namespace prefix if required)
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

### Registering Custom Resolvers

Register your custom resolver using the [`ClassTypeResolver__mdt`](reference/metadata/ClassTypeResolver__mdt.md) custom metadata:

1. Create a new [`ClassTypeResolver__mdt`](reference/metadata/ClassTypeResolver__mdt.md) record
2. Set `ClassName__c` to the fully qualified name of your resolver class (e.g., `CMN_UTIL_ClassNameResolver`)
3. The framework automatically loads and chains your resolver

### Testing the Custom Resolver

Write a test class to verify your custom resolver handles all resolution paths: local classes, nested classes, unknown
class names, and blank input. Replace `ACME_ClassTypeResolver` with your resolver class name.

> **Tip:** The Health Check page in the KernDX Home tab includes a code generator that creates both the resolver class
> and test class for you. Click the **Setup** button on the Class Type Resolver row to open it.

```apex
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest(SeeAllData=false IsParallel=true)
private class ACME_ClassTypeResolver_TEST
{
	@IsTest
	private static void shouldResolveLocalClass()
	{
		ACME_ClassTypeResolver resolver = new ACME_ClassTypeResolver();

		Type result = resolver.resolveType(ACME_ClassTypeResolver.class.getName());

		Assert.isNotNull(result, 'Should resolve a local class');
	}

	@IsTest
	private static void shouldResolveNestedClass()
	{
		ACME_ClassTypeResolver resolver = new ACME_ClassTypeResolver();

		Type result = resolver.resolveType(kern.UTIL_TypeResolver.BaseClassResolver.class.getName());

		Assert.isNotNull(result, 'Should resolve a nested class');
	}

	@IsTest
	private static void shouldReturnNullWhenClassNotFound()
	{
		ACME_ClassTypeResolver resolver = new ACME_ClassTypeResolver();

		Type result = resolver.resolveType('NonExistentClassName');

		Assert.isNull(result, 'Should return null when class not found and no next resolver');
	}

	@IsTest
	private static void shouldReturnNullWhenClassNameBlank()
	{
		ACME_ClassTypeResolver resolver = new ACME_ClassTypeResolver();

		Type result = resolver.resolveType('');

		Assert.isNull(result, 'Should return null for blank class name');
	}
}
```

---

## Random Data Generation (UTIL_Random)

### Architecture

The [`UTIL_Random`](reference/apex/UTIL_Random.md) utility provides comprehensive random data generation capabilities for testing, development, and data seeding scenarios. It supports both cryptographically secure random generation and pseudo-random generation with seeding for deterministic tests.

**Key Features:**

- **Primitive Types** - Random boolean, integer, long, double values
- **String Generation** - ASCII, alphabetic, alphanumeric, numeric strings
- **UUID Generation** - Cryptographically secure unique identifiers
- **Salesforce ID Generation** - Mock Salesforce record IDs for any SObject type

### Basic Random Generation

**Generating Random Primitives:**

```apex
// Generate random primitive values for testing and development
// Generate random boolean
Boolean randomFlag = UTIL_Random.nextBoolean();

// Generate random integer (full range)
Integer randomInt = UTIL_Random.randomInteger();

// Generate random integer within specific range
Integer diceRoll = UTIL_Random.nextInteger(1, 6); // 1-6 inclusive
```

**Generating Random Strings:**

```apex
// Generate various types of random strings
// Generate random alphabetic string (a-z, A-Z)
String randomName = UTIL_Random.randomAlphabetic(10);

// Generate random alphanumeric string (a-z, A-Z, 0-9)
String randomCode = UTIL_Random.randomAlphanumeric(15);

// Generate random numeric string
String randomNumber = UTIL_Random.randomNumeric(8);

// Generate cryptographically secure UUID
String uniqueId = UTIL_Random.randomUUID();
// Outputs: e.g., '550e8400-e29b-41d4-a716-446655440000'
```

### Salesforce ID Generation

**Generating Mock Record IDs:**

```apex
// Generate mock Salesforce IDs for testing
// Generate random Account ID
Id mockAccountId = UTIL_Random.randomId(Account.SObjectType);
// Outputs: e.g., '001000000000000AAA'

// Generate random Contact ID
Id mockContactId = UTIL_Random.randomId(Contact.SObjectType);

// Use in test data creation
Account testAccount = new Account(
	Id = UTIL_Random.randomId(Account.SObjectType),
	Name = 'Test Account ' + UTIL_Random.randomAlphanumeric(5)
);
```

---

## Advanced Data Indexing (MAP_SObject)

### Architecture

The [`MAP_SObject`](reference/apex/MAP_SObject.md) utility provides sophisticated multi-field indexing for SObject collections, enabling fast lookups on multiple fields simultaneously. It creates a hierarchical index structure that supports complex queries and filtering scenarios.

**Key Features:**

- **Multi-Field Indexing** - Index by multiple fields in a single structure
- **Case-Insensitive Mode** - Optional case-insensitive string comparisons
- **Reference Field Traversal** - Support for relationship fields (e.g., `Account.Name`)
- **Hierarchical Lookups** - Get items by single field or multiple field combinations
- **Sub-Index Retrieval** - Access portions of the index for partial matches
- **Dynamic Operations** - Add, retrieve, and remove operations on indexed data

---

### Internal Architecture

The utility implements a **tree-based data structure** for hierarchical, multi-field indexing with O(1) lookup complexity per field level.

#### Tree Structure Design

**Node Types:**

1. **Intermediate Nodes** ([`MAP_SObject`](reference/apex/MAP_SObject.md))
   - Represent a single indexed field level
   - Store child nodes in `Map<String, INT_SObjectIndex> children`
   - Each key in the map represents a distinct field value
   - Values point to next level in hierarchy (or leaf nodes)

2. **Leaf Nodes** (`SObjectIndexLeaf`)
   - Terminal nodes storing actual SObjects
   - Contain `List<SObject> objects`
   - Represent complete match path through all indexed fields

**Example Structure:**

For index `new MAP_SObject(new List<String>{'Industry', 'Country', 'Type'})`:

```text
MAP_SObject (Industry level)
├── 'Technology' → MAP_SObject (Country level)
│   ├── 'USA' → MAP_SObject (Type level)
│   │   ├── 'Customer' → SObjectIndexLeaf [Account1, Account2]
│   │   └── 'Partner' → SObjectIndexLeaf [Account3]
│   └── 'Canada' → MAP_SObject (Type level)
│       └── 'Customer' → SObjectIndexLeaf [Account4, Account5]
└── 'Finance' → MAP_SObject (Country level)
    └── 'USA' → MAP_SObject (Type level)
        └── 'Customer' → SObjectIndexLeaf [Account6]
```

**Traversal Algorithm:**

```apex
// Lookup: Industry='Technology', Country='USA', Type='Customer'
// Step 1: children.get('Technology') → Navigate to Technology subtree
// Step 2: children.get('USA') → Navigate to USA subtree
// Step 3: children.get('Customer') → Navigate to leaf node
// Step 4: Return objects from SObjectIndexLeaf
```

#### Performance Characteristics

**Time Complexity:**

| Operation | Complexity | Explanation |
|-----------|------------|-------------|
| **put(SObject)** | O(d) | d = depth (number of indexed fields) |
| **get(Map)** | O(d) | Navigate d levels of tree |
| **get(Object)** | O(1) | Single field lookup in current level's map |
| **getAll(Map)** | O(d + n) | d = depth, n = number of matching objects |
| **keySet()** | O(k) | k = number of unique values for field |
| **remove()** | O(d + n) | Navigate tree + remove n objects |

**Space Complexity:**

| Component | Complexity | Explanation |
|-----------|------------|-------------|
| **Overall** | O(n × d × k) | n objects, d fields, k avg key length |
| **Single Object** | O(d) | Object stored at one leaf node |
| **Intermediate Nodes** | O(v) | v = unique values per field |

**Governor Limit Considerations:**

- **Heap Size**: Each intermediate node adds ~200 bytes (Map overhead)
- **For 10,000 records** with 3 indexed fields:
  - Worst case (all unique): ~6 MB heap
  - Average case (50% duplication): ~3 MB heap
  - Best case (high duplication): <1 MB heap

**Performance Example:**

```apex
// Index 10,000 accounts by 3 fields
MAP_SObject index = new MAP_SObject(new List<String>{'Industry', 'Country', 'Type'});
List<Account> accounts = QRY_Builder.selectFrom(Account.SObjectType)
	.addFields(new List<SObjectField>{Account.Id, Account.Name, Account.Industry, Account.BillingCountry, Account.Type})
	.withLimit(10000)
	.toList();

// Put: O(3) per record = O(30,000) total operations (fast)
index.putAll(accounts);

// Get: O(3) lookup regardless of 10,000 records (constant time per lookup)
List<SObject> results = index.getAll(new Map<String, Object>
{
	'Industry' => 'Technology',
	'BillingCountry' => 'USA',
	'Type' => 'Customer'
});
// ↑ Only 3 map lookups to find matching subset
```

#### Case-Insensitive Implementation

**Key Serialization Strategy:**

The utility uses pluggable **serializers** to control how field values are converted to map keys:

**1. Case-Sensitive (Default):**
```apex
private class StringValueOfSerializer implements SerializerInterface
{
	public String serialize(Object objectToSerialize)
	{
		return String.valueOf(objectToSerialize);
	}
}
```

**2. Case-Insensitive:**
```apex
private class ToLowerCaseSerializer implements SerializerInterface
{
	public String serialize(Object objectToSerialize)
	{
		return objectToSerialize == null ? null : String.valueOf(objectToSerialize).toLowerCase();
	}
}
```

**How It Works:**

```apex
// Case-sensitive index (default)
MAP_SObject index1 = new MAP_SObject('Name');
index1.put(new Contact(Name='John Doe')); // Key: 'John Doe'
index1.get('john doe'); // Returns null (case mismatch)

// Case-insensitive index
MAP_SObject index2 = new MAP_SObject('Name').caseInsensitive();
index2.put(new Contact(Name='John Doe')); // Key: 'john doe' (lowercased)
index2.get('JOHN DOE'); // Returns contact (lookup key lowercased to 'john doe' → match!)
```

**Memory Impact:**

- Case-insensitive mode stores lowercased keys
- Original SObject field values unchanged
- Minimal overhead: ~10-20% depending on average field length

**Limitation:**

`caseInsensitive()` can only be called on an empty index. After adding records, structure is immutable to this setting.

```apex
MAP_SObject index = new MAP_SObject('Name');
index.put(new Contact(Name='Test'));
index.caseInsensitive(); // ❌ Throws exception: cannot change after data added
```

---

### Basic Indexing

**Single Field Index:**

```apex
// Create a simple single-field index for fast lookups
// Create index on Account Industry field
MAP_SObject industryIndex = new MAP_SObject('Industry');

// Add accounts to index
List<Account> accounts = QRY_Builder.selectFrom(Account.SObjectType)
	.addFields(new List<SObjectField>{Account.Id, Account.Name, Account.Industry})
	.withLimit(1000)
	.toList();
industryIndex.putAll(accounts);

// Fast lookup by industry
List<SObject> techAccounts = industryIndex.getAll('Technology');
// e.g., techAccounts.size() = 42
```

**Multi-Field Index:**

```apex
// Create multi-field index for complex lookups
// Create index on multiple fields
List<String> indexFields = new List<String>{'Industry', 'BillingCountry', 'Type'};
MAP_SObject multiIndex = new MAP_SObject(indexFields);

// Add accounts to index
List<Account> accounts = QRY_Builder.selectFrom(Account.SObjectType)
	.addFields(new List<SObjectField>{Account.Id, Account.Name, Account.Industry, Account.BillingCountry, Account.Type})
	.toList();
multiIndex.putAll(accounts);

// Retrieve accounts matching all criteria
Map<String, Object> criteria = new Map<String, Object>
{
	'Industry' => 'Technology',
	'BillingCountry' => 'USA',
	'Type' => 'Customer'
};
List<SObject> matchingAccounts = multiIndex.getAll(criteria);
// e.g., matchingAccounts.size() = 5
```

### Case-Insensitive Indexing

**String Comparison Options:**

```apex
// Use case-insensitive indexing for string fields
// Create case-insensitive index
MAP_SObject nameIndex = new MAP_SObject('Name')
	.caseInsensitive();

// Add contacts
List<Contact> contacts = QRY_Builder.selectFrom(Contact.SObjectType)
	.addFields(new List<SObjectField>{Contact.Id, Contact.Name, Contact.Email})
	.toList();
nameIndex.putAll(contacts);

// Lookup works regardless of case
Contact john1 = (Contact)nameIndex.get('john doe');
Contact john2 = (Contact)nameIndex.get('John Doe');
Contact john3 = (Contact)nameIndex.get('JOHN DOE');

Assert.areEqual(john1.Id, john2.Id, 'Case-insensitive lookup should match');
Assert.areEqual(john2.Id, john3.Id, 'Case-insensitive lookup should match');
```

### Reference Field Traversal

**Indexing Relationship Fields:**

```apex
// Index by relationship fields for cross-object lookups
// Create index on Account.Name via Contact
MAP_SObject accountNameIndex = new MAP_SObject('Account.Name');

// Add contacts with account relationship
List<Contact> contacts = QRY_Builder.selectFrom(Contact.SObjectType)
	.addFields(new List<SObjectField>{Contact.Id, Contact.FirstName, Contact.LastName})
	.relatedField('Account.Name')
	.condition(Contact.AccountId).isNotNull()
	.toList();
accountNameIndex.putAll(contacts);

// Retrieve all contacts for specific account
List<SObject> acmeContacts = accountNameIndex.getAll('Acme Corporation');
// e.g., acmeContacts.size() = 3
```

### Advanced Operations

**Using Specification Objects:**

```apex
// Use SObject specifications for flexible queries
// Create index
List<String> fields = new List<String>{'Industry', 'Rating'};
MAP_SObject index = new MAP_SObject(fields);

// Add accounts
List<Account> accounts = QRY_Builder.selectFrom(Account.SObjectType)
	.addFields(new List<SObjectField>{Account.Id, Account.Name, Account.Industry, Account.Rating})
	.toList();
index.putAll(accounts);

// Create specification object
Account spec = new Account(
	Industry = 'Technology',
	Rating = 'Hot'
);

// Retrieve matching accounts
List<SObject> hotTechAccounts = index.getAll(spec);
// e.g., hotTechAccounts.size() = 7
```

**Getting Key Sets:**

```apex
// Retrieve all unique values for a specific field
// Create and populate index
MAP_SObject index = new MAP_SObject(new List<String>{'Industry', 'Type'});
List<Account> accounts = QRY_Builder.selectFrom(Account.SObjectType)
	.addFields(new List<SObjectField>{Account.Id, Account.Name, Account.Industry, Account.Type})
	.toList();
index.putAll(accounts);

// Get all unique industries
Set<String> industries = index.keySet('Industry');
// e.g., industries.size() = 12

// Get all unique types
Set<String> types = index.keySet('Type');
// e.g., types = {Customer, Partner, Prospect}
```

**Removing Items:**

```apex
// Remove items from index based on criteria
// Create and populate index
MAP_SObject index = new MAP_SObject('Industry');
List<Account> accounts = QRY_Builder.selectFrom(Account.SObjectType)
	.addFields(new List<SObjectField>{Account.Id, Account.Name, Account.Industry})
	.toList();
index.putAll(accounts);

// Remove all technology accounts from index
Map<String, Object> removeSpec = new Map<String, Object>{'Industry' => 'Technology'};
List<SObject> removedAccounts = index.remove(removeSpec);
// e.g., removedAccounts.size() = 8
```

---

## Metadata Introspection (UTIL_SObjectDescribe)

### Architecture

The [`UTIL_SObjectDescribe`](reference/apex/UTIL_SObjectDescribe.md) utility provides a high-performance, namespace-aware wrapper around Salesforce's standard Schema describe methods. It implements internal caching to avoid hitting describe governor limits and provides helper methods for handling relationship fields, namespaces, and field sets.

**Key Features:**

- **Internal Caching** - Prevents redundant describe calls and governor limit consumption
- **Namespace Handling** - Automatic namespace prefix management for managed packages
- **Deferred Loading** - Lazy-loads describe data only when needed
- **Relationship Field Support** - Handles both relationship and ID field naming (e.g., `Account` vs `AccountId`)
- **Global Describe Caching** - Cached access to all SObject types in the org
- **Field Set Access** - Retrieve field sets for dynamic form rendering
- **Person Account Detection** - Helper method to check if Person Accounts are enabled

**How It Works:**

The utility maintains a static cache of [`UTIL_SObjectDescribe`](reference/apex/UTIL_SObjectDescribe.md) instances, preventing redundant Schema describe operations. It uses deferred loading to keep memory footprint minimal until full describe data is needed.

### Basic Usage

**Getting Describe Information:**

```apex
// Retrieve cached describe information for an SObject
// Get describe by string name
UTIL_SObjectDescribe accountDescribe = UTIL_SObjectDescribe.getDescribe('Account');
// accountDescribe.getDescribe().getLabel() = 'Account'
// accountDescribe.getDescribe().getName() = 'Account'

// Get describe by SObjectType
UTIL_SObjectDescribe contactDescribe = UTIL_SObjectDescribe.getDescribe(Contact.SObjectType);
// contactDescribe.getDescribe().isCustom() = false

// Get describe from instance
Account account = new Account();
UTIL_SObjectDescribe instanceDescribe = UTIL_SObjectDescribe.getDescribe(account);
// e.g., instanceDescribe.getDescribe().getRecordTypeInfos().size() = 3
```

### Field Operations

**Retrieving Fields:**

```apex
// Access field metadata with namespace handling
UTIL_SObjectDescribe accountDescribe = UTIL_SObjectDescribe.getDescribe(Account.SObjectType);

// Get specific field
SObjectField nameField = accountDescribe.getField('Name');
// nameField.getDescribe().getLabel() = 'Account Name'
// nameField.getDescribe().getType() = STRING
// !nameField.getDescribe().isNillable() = true

// Get field with relationship notation - automatically converts to ID field
SObjectField accountField = accountDescribe.getField('Parent'); // Returns ParentId field
// accountField.getDescribe().getName() = 'ParentId'
```

**Using FieldsMap:**

```apex
// Use the wrapped FieldsMap for namespace-aware field access
UTIL_SObjectDescribe describe = UTIL_SObjectDescribe.getDescribe('Contact');

// Get fields map with namespace handling
UTIL_SObjectDescribe.FieldsMap fields = describe.getFields();

// Access fields by name
SObjectField emailField = fields.get('Email');
SObjectField phoneField = fields.get('Phone');

// Check if field exists
if(fields.containsKey('CustomField__c'))
{
	SObjectField customField = fields.get('CustomField__c');
	// e.g., customField.getDescribe().getLabel() = 'Custom Field'
}

// Get all field names
Set<String> fieldNames = fields.keySet();
// e.g., fieldNames.size() = 65

// Iterate over all fields
for(SObjectField field : fields.values())
{
	DescribeFieldResult fieldDescribe = field.getDescribe();
	// e.g., 'Email (STRING)', 'Phone (PHONE)', etc.
}
```

**Finding the Name Field:**

```apex
// Get the Name field of an SObject
UTIL_SObjectDescribe accountDescribe = UTIL_SObjectDescribe.getDescribe(Account.SObjectType);

// Get the field where isNameField() == true
SObjectField nameField = accountDescribe.getNameField();
// nameField.getDescribe().getName() = 'Name'

// For custom objects, this returns the Auto Number or custom name field
UTIL_SObjectDescribe customDescribe = UTIL_SObjectDescribe.getDescribe('CustomObject__c');
SObjectField customNameField = customDescribe.getNameField();
// e.g., customNameField.getDescribe().getName() = 'Name' or 'CustomObject_Name__c'
```

### Field Set Operations

**Accessing Field Sets:**

```apex
// Retrieve field sets for dynamic forms and layouts
UTIL_SObjectDescribe accountDescribe = UTIL_SObjectDescribe.getDescribe(Account.SObjectType);

// Get all field sets for the object
Map<String, FieldSet> fieldSets = accountDescribe.getFieldSetsMap();
// e.g., fieldSets.size() = 2

// Access specific field set
if(fieldSets.containsKey('QuickView'))
{
	FieldSet quickViewFS = fieldSets.get('QuickView');
	List<FieldSetMember> fields = quickViewFS.getFields();

	// Build query using QRY_Builder with FieldSet fields
	List<Account> results = QRY_Builder.selectFrom(Account.SObjectType)
		.fieldSet('QuickViewFields')  // FieldSet name
		.toList();
	// e.g., results.size() = 10
}
```

### Global Describe Operations

**Working with Global Describe:**

```apex
// Access cached global describe data
// Get raw global describe map
Map<String, SObjectType> globalDescribe = UTIL_SObjectDescribe.getRawGlobalDescribe();
// e.g., globalDescribe.size() = 847

// Check if object exists
Boolean hasAccount = globalDescribe.containsKey('Account');
// hasAccount = true

// Use wrapped global describe with namespace handling
UTIL_SObjectDescribe.GlobalDescribeMap wrappedDescribe = UTIL_SObjectDescribe.getGlobalDescribe();

// Get SObjectType with automatic namespace handling
SObjectType accountType = wrappedDescribe.get('Account');
// accountType.getDescribe().getLabel() = 'Account'

// Iterate over all SObjects
for(SObjectType objType : wrappedDescribe.values())
{
	if(objType.getDescribe().isCustom())
	{
		// e.g., objType.getDescribe().getName() = 'Foobar__c'
	}
}
```

### Namespace Handling

**Working with Namespaced Fields:**

```apex
// Handle namespace prefixes automatically
UTIL_SObjectDescribe describe = UTIL_SObjectDescribe.getDescribe('Contact');

// Get field with namespace prefix (e.g., in managed package)
// If field is "kern__CustomField__c", you can access it as "CustomField__c"
SObjectField field1 = describe.getField('CustomField__c', true); // Implies namespace
SObjectField field2 = describe.getField('kern__CustomField__c', false); // No namespace handling

Assert.areEqual(field1, field2, 'Both should return same field');

// Check field existence with namespace handling
UTIL_SObjectDescribe.FieldsMap fields = describe.getFields();
Boolean hasField1 = fields.containsKey('CustomField__c', true); // With namespace
Boolean hasField2 = fields.containsKey('kern__CustomField__c', false); // Without namespace

// Get key sets with/without namespace
Set<String> keysWithoutNS = fields.keySet(false); // Returns full names
Set<String> keysWithNS = fields.keySet(true); // Returns stripped names
```

### Helper Methods

**Person Account Detection:**

```apex
// Check if Person Accounts are enabled in the org
// Check Person Account support
Boolean isPersonAccountEnabled = UTIL_SObjectDescribe.isPersonAccountEnabled();

if(isPersonAccountEnabled)
{
	// Person Accounts are enabled - use IsPersonAccount field
}
else
{
	// Person Accounts not enabled
}
```

**Getting Object Name from Type:**

```apex
// Retrieve API name from SObjectType
// Get API name from SObjectType
String accountName = UTIL_SObjectDescribe.getObjectNameFromType(Account.SObjectType);
// accountName = 'Account'

// Useful for dynamic operations
List<SObjectType> objectTypes = new List<SObjectType>{Account.SObjectType, Contact.SObjectType, Lead.SObjectType};
for(SObjectType objType : objectTypes)
{
	String objectName = UTIL_SObjectDescribe.getObjectNameFromType(objType);
	// e.g., objectName = 'Account', 'Contact', 'Lead'
}
```

### Cache Management

**Flushing the Cache:**

```apex
// Clear the describe cache to free heap space
// Perform intensive describe operations
for(Integer i = 0; i < 100; i++)
{
	UTIL_SObjectDescribe describe = UTIL_SObjectDescribe.getDescribe('Account');
	// Process...
}

// Clear cache to free memory
UTIL_SObjectDescribe.flushCache();

// Future describe calls will rebuild cache
UTIL_SObjectDescribe freshDescribe = UTIL_SObjectDescribe.getDescribe('Account');
// Cache rebuilt on demand
```

### Advanced Patterns

**Dynamic Field Introspection:**

```apex
// Dynamically analyze field metadata for validation
public with sharing class FieldValidator
{
	public static Map<String, String> validateRequiredFields(SObject record)
	{
		Map<String, String> errors = new Map<String, String>();
		UTIL_SObjectDescribe describe = UTIL_SObjectDescribe.getDescribe(record);

		// Get all fields
		UTIL_SObjectDescribe.FieldsMap fields = describe.getFields();

		// Check required fields
		for(SObjectField field : fields.values())
		{
			DescribeFieldResult fieldDesc = field.getDescribe();

			// Skip non-required and read-only fields
			if(!fieldDesc.isNillable() && fieldDesc.isCreateable())
			{
				Object value = record.get(fieldDesc.getName());
				if(value == null)
				{
					errors.put(fieldDesc.getName(), fieldDesc.getLabel() + ' is required');
				}
			}
		}

		return errors;
	}
}

// Usage
Account account = new Account();
Map<String, String> validationErrors = FieldValidator.validateRequiredFields(account);
if(!validationErrors.isEmpty())
{
	// e.g., validationErrors = {Name=Account Name is required}
}
```

**Building Dynamic SOQL:**

```apex
// Build type-safe dynamic SOQL using describe metadata
public with sharing class DynamicQueryBuilder
{
	public static String buildQueryForObject(String objectName, String filterField, Object filterValue)
	{
		UTIL_SObjectDescribe describe = UTIL_SObjectDescribe.getDescribe(objectName);

		// Get all queryable fields
		List<String> fieldNames = new List<String>();
		for(SObjectField field : describe.getFields().values())
		{
			DescribeFieldResult fieldDesc = field.getDescribe();
			if(fieldDesc.isAccessible() && fieldDesc.isFilterable())
			{
				fieldNames.add(fieldDesc.getName());
			}
		}

		// Build query
		String query = 'SELECT ' + String.join(fieldNames, ', ');
		query += ' FROM ' + describe.getDescribe().getName();

		// Add filter if provided
		if(String.isNotBlank(filterField) && filterValue != null)
		{
			SObjectField field = describe.getField(filterField);
			if(field != null)
			{
				query += ' WHERE ' + filterField + ' = :filterValue';
			}
		}

		return query;
	}
}

// Usage
String query = DynamicQueryBuilder.buildQueryForObject('Account', 'Industry', 'Technology');
// e.g., query = 'SELECT Name, Industry, ... FROM Account WHERE Industry = :filterValue'
List<SObject> results = Database.query(query);
```

### Best Practices

1. **Use Caching** - Always use `UTIL_SObjectDescribe.getDescribe()` instead of direct Schema calls to leverage caching
2. **Namespace Handling** - Use the default `implyNamespace=true` parameter for managed package compatibility
3. **Relationship Fields** - Use relationship names (e.g., `Account`) and let the utility resolve to ID fields automatically
4. **Global Describe** - Use the wrapped `GlobalDescribeMap` for namespace-aware global describe operations
5. **Cache Management** - Only flush cache when absolutely necessary (e.g., after metadata changes in tests)
6. **Deferred Loading** - The utility uses deferred loading, so getting a describe instance is lightweight
7. **Field Sets** - Use field sets for dynamic forms instead of hardcoding field lists
8. **Person Accounts** - Always check `isPersonAccountEnabled()` before accessing Person Account-specific fields

---

## Feature Flag Management (UTIL_FeatureFlag)

### Architecture

The [`UTIL_FeatureFlag`](reference/apex/UTIL_FeatureFlag.md) utility provides a comprehensive feature toggle system based on custom metadata, enabling granular control over feature availability across different user segments, profiles, permission sets, and custom conditions.

**Key Components:**

- **[`FeatureFlag__mdt`](reference/metadata/FeatureFlag__mdt.md)** - Custom metadata defining features with default behavior
- **[`FeatureFlagStrategy__mdt`](reference/metadata/FeatureFlagStrategy__mdt.md)** - Child metadata defining evaluation strategies per feature
- **[`INT_FeatureFlagStrategy`](reference/apex/UTIL_FeatureFlag.INT_FeatureFlagStrategy.md)** - Global interface for custom strategy implementations
- **Built-in Strategies** - Custom permissions, permission sets, public groups, profiles, hierarchical settings, custom metadata

**How It Works:**

Feature flags are evaluated using a strategy pattern:

1. **Strategy Evaluation** - Each feature can have multiple strategies (conditions)
2. **First Match Wins** - Strategies are evaluated in order until a definitive result (MATCH_TRUE or MATCH_FALSE)
3. **Default Behavior** - If no strategies match, the feature's default setting or `ResultOnNoMatch__c` is used
4. **Custom Handlers** - Complex logic can be implemented via custom strategy classes

### Basic Usage

**Simple Feature Check:**

```apex
// Check if a feature is enabled for the current user
// Simple boolean check
if(UTIL_FeatureFlag.isEnabled('New_Dashboard_UI'))
{
	// Show new dashboard
	return new DashboardController_v2();
}
else
{
	// Show old dashboard
	return new DashboardController_v1();
}
```

**Feature Toggle Pattern:**

```apex
// Use feature flags to control code paths
public void processAccount(Account account)
{
	// Standard processing
	validateAccount(account);

	// Feature-gated processing
	if(UTIL_FeatureFlag.isEnabled('Enhanced_Account_Processing'))
	{
		performEnhancedValidation(account);
		enrichWithExternalData(account);
		applyAdvancedBusinessRules(account);
	}

	// Save
	DML_Builder.newTransaction().doUpdate(account).execute();
}
```

### Strategy Types

**Custom Permission Strategy:**

Configure via [`FeatureFlagStrategy__mdt`](reference/metadata/FeatureFlagStrategy__mdt.md):
- Type__c: `Custom Permission`
- Target__c: Permission API name with optional namespace prefix (see formats below)
- ExpectedValue__c: `true` (feature enabled if user has permission) or `false` (enabled if user lacks permission)

**Target Format (Subscriber-First Resolution):**

| Format | Resolution | Example |
|--------|------------|---------|
| `PermissionName` | Subscriber/local permission first, then package | `Access_Beta_Features` |
| `core.PermissionName` | Package permission only | `core.Access_Beta_Features` |
| `namespace__PermissionName` | Explicit namespace | `OtherPkg__Access_Features` |

This **subscriber-first** approach gives subscribers control when permission names collide between managed packages.

**Permission Set Group Strategy:**

Configure via [`FeatureFlagStrategy__mdt`](reference/metadata/FeatureFlagStrategy__mdt.md):
- Type__c: `Permission Set Group`
- Target__c: `DeveloperName_of_PSG`
- ExpectedValue__c: `true` or `false`

**Profile Strategy:**

Configure via [`FeatureFlagStrategy__mdt`](reference/metadata/FeatureFlagStrategy__mdt.md):
- Type__c: `Profile`
- Target__c: `Profile_Name`
- ExpectedValue__c: `true` or `false`

**Public Group Strategy:**

Configure via [`FeatureFlagStrategy__mdt`](reference/metadata/FeatureFlagStrategy__mdt.md):
- Type__c: `Public Group`
- Target__c: `Group_DeveloperName`
- ExpectedValue__c: `true` or `false`

**Custom Metadata Strategy:**

Configure via [`FeatureFlagStrategy__mdt`](reference/metadata/FeatureFlagStrategy__mdt.md):
- Type__c: `Custom Metadata`
- Target__c: `ObjectName__mdt.RecordDeveloperName.FieldName__c`
- ExpectedValue__c: Value to compare against

**Hierarchical Custom Setting Strategy:**

Configure via [`FeatureFlagStrategy__mdt`](reference/metadata/FeatureFlagStrategy__mdt.md):
- Type__c: `Hierarchical Custom Setting`
- Target__c: `SettingName__c.FieldName__c`
- ExpectedValue__c: Value to compare against

### Implementing Custom Strategies

**Custom Strategy Class:**

```apex
// Implement custom feature flag evaluation logic
// Custom strategy based on business logic
global inherited sharing class FF_RegionalFeatureStrategy implements UTIL_FeatureFlag.INT_FeatureFlagStrategy
{
	public Boolean isEnabled(FeatureFlag__mdt flag, FeatureFlagStrategy__mdt strategy)
	{
		// Custom logic - enable feature only for specific regions
		String allowedRegions = strategy.Target__c; // e.g., 'US,CA,UK'
		String userCountry = UserInfo.getLocale().substring(3, 5);

		List<String> regions = allowedRegions.split(',');
		Boolean isEnabled = regions.contains(userCountry);

		return isEnabled;
	}
}
```

**Time-Based Strategy:**

```apex
// Enable features based on date/time windows
global inherited sharing class FF_TimeWindowStrategy implements UTIL_FeatureFlag.INT_FeatureFlagStrategy
{
	public Boolean isEnabled(FeatureFlag__mdt flag, FeatureFlagStrategy__mdt strategy)
	{
		// Target format: '2025-01-01T00:00:00Z,2025-12-31T23:59:59Z'
		List<String> dates = strategy.Target__c.split(',');
		DateTime startDate = DateTime.valueOf(dates[0].replace('T', ' ').replace('Z', ''));
		DateTime endDate = DateTime.valueOf(dates[1].replace('T', ' ').replace('Z', ''));
		DateTime now = DateTime.now();

		return now >= startDate && now <= endDate;
	}
}
```

**Percentage Rollout Strategy:**

```apex
// Gradually roll out features to percentage of users
global inherited sharing class FF_PercentageRolloutStrategy implements UTIL_FeatureFlag.INT_FeatureFlagStrategy
{
	public Boolean isEnabled(FeatureFlag__mdt flag, FeatureFlagStrategy__mdt strategy)
	{
		// Target: percentage as decimal (e.g., '25' for 25%)
		Decimal targetPercentage = Decimal.valueOf(strategy.Target__c);

		// Use user ID hash for consistent per-user assignment
		String userId = UserInfo.getUserId();
		Integer hashValue = Math.abs(userId.hashCode());
		Decimal userPercentage = Math.mod(hashValue, 100);

		return userPercentage < targetPercentage;
	}
}
```

### Best Practices

1. **Default to Disabled** - Set `IsEnabledByDefault__c = false` for new features
2. **Strategy Order** - Order strategies from most specific to most general
3. **Testing** - Always test both enabled and disabled code paths
4. **Documentation** - Document feature flags and their purpose in custom metadata descriptions
5. **Cleanup** - Remove feature flags after full rollout
6. **Monitoring** - Track feature flag usage to understand adoption

### LWC Bridge

LWC consumers evaluate the same flags through the `c/featureFlag` module, which calls `CTRL_FeatureFlag.isEnabled` server-side and returns the result as a `Promise<boolean>`:

```javascript
import {ComponentBuilder} from 'c/componentBuilder';
import {isFlagEnabled} from 'c/featureFlag';

export default class MyComponent extends ComponentBuilder('notification')
{
	checkoutEnabled = false;

	async connectedCallback()
	{
		this.checkoutEnabled = await isFlagEnabled('NewCheckout_Enabled');
	}
}
```

Because the bridge resolves through the same `UTIL_FeatureFlag.isEnabled()` evaluation path used by
Apex callers, LWC consumers see identical flag state to Apex consumers — no second source of truth.
See [LWC - Guide](LWC%20-%20Guide.md) for the deeper bridge documentation, including LDS cache
staleness considerations.

### User Context Evaluation

By default, `isEnabled()` evaluates feature flags for the **running user**. However, in certain scenarios you need to evaluate flags for a **different user** - such as when implementing `TxnSecurity.EventCondition` policies where the event user differs from the system execution context.

**New Methods:**

| Method | Description |
|--------|-------------|
| `isEnabled(String flagName, Id userId)` | Evaluate flag for a specific user by Salesforce ID |
| `isEnabled(String flagName, String username)` | Evaluate flag for a specific user by username |

**TxnSecurity.EventCondition Example:**

```apex
// Transaction Security policy - evaluate flag for EVENT user, not policy context
global inherited sharing class BlockLargeExportPolicy implements TxnSecurity.EventCondition
{
	public Boolean evaluate(SObject event)
	{
		ReportEvent reportEvent = (ReportEvent)event;

		// WRONG: This checks the POLICY's running user (system context)
		// if(UTIL_FeatureFlag.isEnabled('Block_Large_Export'))

		// CORRECT: Check flag for the USER who triggered the event
		if(UTIL_FeatureFlag.isEnabled('Block_Large_Export', reportEvent.UserId))
		{
			return reportEvent.RowsProcessed > 10000;
		}
		return false;
	}
}
```

**Batch Apex Example:**

```apex
// Evaluate flags for each user being processed in a batch
public void execute(Database.BatchableContext context, List<User> users)
{
	for(User user : users)
	{
		if(UTIL_FeatureFlag.isEnabled('Premium_Feature', user.Id))
		{
			// User has premium feature enabled
			grantPremiumAccess(user);
		}
	}
}
```

**All Built-in Strategies Support User Context:**

- Custom Permission (via [`SEL_PermissionSet`](reference/apex/SEL_PermissionSet.md))
- Permission Set Group
- Profile
- Public Group
- Hierarchical Custom Setting
- Custom Metadata (user-agnostic)
- List Custom Setting (user-agnostic)

**Custom User-Aware Strategies:**

For custom strategies that need user context, implement `INT_UserAwareFeatureFlagStrategy`:

```apex
global inherited sharing class FF_RegionalStrategy implements UTIL_FeatureFlag.INT_UserAwareFeatureFlagStrategy
{
	// Standard method - delegates to user-aware method
	public Boolean isEnabled(FeatureFlag__mdt flag, FeatureFlagStrategy__mdt strategy)
	{
		return isEnabledForUser(flag, strategy, UserInfo.getUserId());
	}

	// User-aware method - contains actual logic
	public Boolean isEnabledForUser(FeatureFlag__mdt flag, FeatureFlagStrategy__mdt strategy, Id userId)
	{
		User targetUser = new SEL_User().findById(userId);
		List<String> allowedCountries = strategy.Target__c.split(',');
		return allowedCountries.contains(targetUser.Country);
	}
}
```

**Performance Notes:**

- Running user checks use `UserInfo.*` methods (zero SOQL)
- Other user checks use efficient caching in `SEL_PermissionSet`
- Profile ID is lazy-loaded only when Profile strategy is evaluated

### Performance and SOQL Cost

The framework caches the flag/strategy custom metadata for the whole transaction, but evaluates each strategy's *target* lookup on every call.
Knowing where SOQL fires lets you keep flag checks cheap.

**Transaction-level caches (free after the first call):**

- `SEL_FeatureFlag.activeFlags` — one CMDT parent-child query loads every active flag and its active strategies on the first
  `isEnabled(...)` call per transaction. Subsequent calls reuse the map; no further SOQL for flag/strategy metadata.
- `SEL_FeatureFlag.allDeveloperNames` — one query for the Strict Definition Priority bootstrap, also memoised per transaction.
- Running user's profile ID — read from `UserInfo.getProfileId()`. Zero SOQL.

**Per-call SOQL cost by strategy type:**

| Strategy | Running user | Other user | Notes |
|---|---|---|---|
| Custom Permission, namespaced (`pkg__Name`) or `core.Name` | 0 | 1 | Running user uses `FeatureManagement.checkPermission()`. |
| Custom Permission, no prefix (subscriber-local) | 1 | 1 | `FeatureManagement` cannot see subscriber-local permissions from a managed-package context — SOQL is the only path. |
| Profile | 1 | 1 | Resolves the target Profile by name. |
| Public Group | 1 | 1 | Group membership lookup. |
| Permission Set Group | 1 | 1 | Permission set assignment lookup. |
| Hierarchical Custom Setting | 1 | 1 (+ profile lookup, lazy) | Reads `SetupOwnerId IN (userId, profileId, orgId)`; picks the highest-precedence non-null in Apex. |
| List Custom Setting | 1 | 1 | Single-record lookup by Name. |
| Custom Metadata | 1 | 1 | Single-record lookup by DeveloperName. |
| Custom Handler | depends | depends | Whatever your `INT_FeatureFlagStrategy` does. |

**Short-circuits (zero SOQL) within the strategy dispatcher:**

- Strategy with a blank or unparseable `Target__c`.
- Flag with no strategies — returns `IsEnabledByDefault__c` immediately.
- Strategy with `CustomHandler__c` populated — type dispatch is bypassed entirely; only the handler runs.

#### Why custom-setting strategies use SOQL

Custom Settings expose platform-cached static APIs (`MyCS__c.getInstance(userId)`, `MyCS__c.getOrgDefaults()`,
`MyType__mdt.getInstance(name)`). The framework cannot reach them generically: those methods live on the *typed* SObject class, and the
strategy dispatcher only knows the SObject *name* (a string) at runtime — `Target__c` is data, not a class reference. There is no
`Schema.SObjectType` API equivalent to `getInstance()`. The framework therefore falls back to dynamic SOQL via `QRY_Builder`, which works
uniformly for any subscriber object without requiring framework code changes.

This is also why the **running user** does not get a faster path for Custom Setting strategies: there's nothing to optimise into.
Custom Permission has `FeatureManagement.checkPermission()`; Custom Settings have no equivalent string-keyed API.

#### When SOQL becomes a problem — and what to do

The synchronous SOQL governor is 100 queries per transaction (200 async). Concrete failure modes and remedies:

| Symptom | Cause | Fix |
|---|---|---|
| 100-SOQL governor hit in a trigger or batch | `isEnabled()` called inside a record loop with a SOQL-bound strategy type | Hoist the result: `Boolean enabled = UTIL_FeatureFlag.isEnabled('My_Flag'); for(Record r : records) { if(enabled) ... }` |
| Repeated SOQL on the same custom setting across many flag checks | No per-transaction cache for strategy *target* values | Replace the built-in strategy with a `CustomHandler__c` that calls `MyCS__c.getInstance(...)` once and dispatches internally. `getInstance()` is platform-cached — zero SOQL after warm. |
| Local custom permission costs SOQL even for the running user | No prefix on `Target__c` → falls to `SEL_CustomPermission.hasLocalPermission` | If the permission lives in your subscriber namespace, qualify it (`acme__My_Permission`) or use `core.Name` for a package permission. Running-user checks then route through `FeatureManagement.checkPermission()`. |
| Per-user batches blow the limit | `isEnabled(flag, userId)` for non-running users adds 1 SOQL for the profile lookup, plus 1 for the strategy | Group records by user up front; cache `Map<Id, Boolean>` results outside the strategy loop. |

**Custom Handler escape hatch — concrete example.** When several flags read fields off the same Hierarchical Custom Setting, replace the
built-in `Hierarchical Custom Setting` strategy with a typed handler that calls `getInstance()` directly. One platform-cached lookup,
zero SOQL after warm:

```apex
global inherited sharing class FF_KillSwitchStrategy implements UTIL_FeatureFlag.INT_FeatureFlagStrategy
{
	public Boolean isEnabled(FeatureFlag__mdt flag, FeatureFlagStrategy__mdt strategy)
	{
		// Target__c carries the field name on MyKillSwitches__c (e.g. "DisableAllApis__c")
		MyKillSwitches__c settings = MyKillSwitches__c.getInstance(UserInfo.getUserId());
		Object value = settings.get(strategy.Target__c);
		return value == true;
	}
}
```

Wire it up by setting `CustomHandler__c = 'FF_KillSwitchStrategy'` on each `FeatureFlagStrategy__mdt` record. The `Type__c` value is
ignored when a handler is populated.

**Why not `QRY_Builder.withCache(...)` on the built-in strategies?** Caching wouldn't help and would actively hurt:

- Custom Settings and Custom Metadata are already platform-cached behind their `getInstance()` APIs. Wrapping the SOQL path in
  `QRY_Builder.withCache(...)` duplicates that cache and burns Session/Org partition capacity.
- Org-config strategies (Profile, Public Group, Permission Set Group, Custom Permission) decide access. Platform Cache has a 5-minute
  TTL floor — staleness on access decisions is usually worse than the 1-SOQL cost.
- The bootstrap query in `SEL_FeatureFlag.getAllActiveWithStrategies` cannot use `QRY_Builder` at all — instantiating the builder
  triggers a `UserModeQueries_Enabled` recursion. It uses raw `Database.query` pinned to `SYSTEM_MODE` for that reason.

If a custom handler genuinely needs SOQL caching for a lookup table that has no `getInstance()` equivalent, `QRY_Builder.withCache(ttl)`
is available — but stay in `withSystemMode()` (USER_MODE disables caching), pick a TTL you can defend against staleness, and remember
that the cache key includes the SOQL plus binds, so user-scoped lookups fan out one entry per user.

**Decision rule.** If a flag is checked once per transaction or only on synchronous UI paths, the built-in strategies are fine —
1 SOQL per check is immaterial. If a flag is checked per record in a trigger, batch, or scheduled job, either hoist the boolean result
or move to a `getInstance()`-based custom handler. Don't keep built-in custom-setting strategies in tight loops.

---

## Logging Framework (LOG_Builder)

> **Full Documentation:** See [Logging - Guide](Logging%20-%20Guide.md) for comprehensive coverage of Apex logging, LWC client-side logging, Flow logging, correlation tracking, performance monitoring, and configuration.

The [`LOG_Builder`](reference/apex/LOG_Builder.md) utility provides end-to-end observability across all Salesforce execution contexts. Unlike `System.debug()` which produces ephemeral debug logs, this framework persists logs to `LogEntry__c` via platform events.

**Key Capabilities:**

| Feature | Description |
|---------|-------------|
| **Multi-Channel** | Log from Apex, LWC, and Flows with consistent API |
| **Correlation Tracking** | Link related logs across async boundaries |
| **Performance Monitoring** | Automatic timing with configurable thresholds |
| **Structured Context** | Attach key-value metadata to log entries |

### Quick Reference

```apex
// Error logging with context
try
{
	processRecord(record);
}
catch(Exception e)
{
	LOG_Builder.build().error(e).at('MyClass.myMethod').forRecord(record.Id).emit();
	throw e;
}

// Correlation for async operations
String context = LOG_Builder.serializeContext();
System.enqueueJob(new MyQueueable(recordId, context));

// In async job - restore context
LOG_Builder.hydrateContext(loggerContext);
```

For detailed usage including LWC logging, Flow integration, and performance timers, see the [Logging - Guide](Logging%20-%20Guide.md).

---

## Omnistudio Integration (SVC_Omnistudio)

### Architecture

The [`SVC_Omnistudio`](reference/apex/SVC_Omnistudio.md) factory class implements Salesforce's [`Callable`](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_interface_system_callable.htm) interface to enable dynamic execution of Apex classes from Omnistudio (formerly Vlocity) components such as OmniScripts and Integration Procedures.

**Key Components:**

- **[`SVC_Omnistudio`](reference/apex/SVC_Omnistudio.md)** - Factory implementing `Callable` interface
- **[`SVC_Omnistudio.OmniCallable`](reference/apex/SVC_Omnistudio.OmniCallable.md)** - Interface for classes callable from Omnistudio
- **[`SVC_Omnistudio.Parameters`](reference/apex/SVC_Omnistudio.Parameters.md)** - DTO wrapping input, output, and option maps

**How It Works:**

1. **Omnistudio Configuration** - Configure Callable Apex action in Omnistudio designer
2. **Dynamic Instantiation** - Factory instantiates specified class using type resolution
3. **Parameter Passing** - Input, output, and options maps are passed to implementation
4. **Execution** - Implementation processes inputs and populates output map
5. **Error Handling** - Exceptions are logged and re-thrown for Omnistudio error handling

### Implementing Callable Classes

**Basic Implementation:**

```apex
// Implement SVC_Omnistudio.OmniCallable for use in Omnistudio
global inherited sharing class OMN_AccountEnrichment implements SVC_Omnistudio.OmniCallable
{
	public void call(SVC_Omnistudio.Parameters parameters)
	{
		// Get input variables
		String accountId = (String)parameters.getInputVariable('accountId');
		Boolean includeContacts = (Boolean)parameters.getInputVariable('includeContacts');

		// Process - Use QRY_Builder for queries
		Account account = (Account)QRY_Builder.selectFrom(Account.SObjectType)
			.fields(new List<String>{'Id', 'Name', 'Industry', 'AnnualRevenue'})
			.condition(Account.Id).equals(accountId)
			.getFirst();
		Map<String, Object> enrichedData = enrichAccountData(account);

		// Set output variables
		parameters.setOutputVariable('accountName', account.Name);
		parameters.setOutputVariable('industry', account.Industry);
		parameters.setOutputVariable('creditRating', enrichedData.get('creditRating'));

		if(includeContacts)
		{
			List<Contact> contacts = QRY_Builder.selectFrom(Contact.SObjectType)
				.fields(new List<String>{'Id', 'Name', 'Email'})
				.condition(Contact.AccountId).equals(accountId)
				.toList();
			parameters.setOutputVariable('contacts', contacts);
			parameters.setOutputVariable('contactCount', contacts.size());
		}
	}

	private Map<String, Object> enrichAccountData(Account account)
	{
		// Enrichment logic
		return new Map<String, Object>
		{
			'creditRating' => calculateCreditRating(account),
			'riskScore' => calculateRiskScore(account)
		};
	}
}
```

**Complex Data Processing:**

```apex
// Process complex data structures from Omnistudio
global inherited sharing class OMN_OpportunityCalculator implements SVC_Omnistudio.OmniCallable
{
	public void call(SVC_Omnistudio.Parameters parameters)
	{
		// Access input map directly for complex structures
		Map<String, Object> opportunityData = (Map<String, Object>)parameters.inputMap.get('opportunityData');
		List<Object> lineItems = (List<Object>)opportunityData.get('lineItems');

		// Process line items
		Decimal totalAmount = 0;
		Decimal totalDiscount = 0;

		for(Object item : lineItems)
		{
			Map<String, Object> lineItem = (Map<String, Object>)item;
			Decimal quantity = (Decimal)lineItem.get('quantity');
			Decimal unitPrice = (Decimal)lineItem.get('unitPrice');
			Decimal discount = (Decimal)lineItem.get('discount');

			totalAmount += (quantity * unitPrice);
			totalDiscount += discount;
		}

		Decimal finalAmount = totalAmount - totalDiscount;

		// Return calculated values
		parameters.setOutputVariable('totalAmount', totalAmount);
		parameters.setOutputVariable('totalDiscount', totalDiscount);
		parameters.setOutputVariable('finalAmount', finalAmount);
		parameters.setOutputVariable('effectiveDiscount', (totalDiscount / totalAmount) * 100);
	}
}
```

**Error Handling:**

```apex
// Implement proper error handling for Omnistudio integration
global inherited sharing class OMN_ExternalIntegration implements SVC_Omnistudio.OmniCallable
{
	public void call(SVC_Omnistudio.Parameters parameters)
	{
		String customerId = (String)parameters.getInputVariable('customerId');

		try
		{
			// Call external service
			HttpResponse response = callExternalAPI(customerId);

			if(response.getStatusCode() == 200)
			{
				Map<String, Object> responseData = (Map<String, Object>)JSON.deserializeUntyped(response.getBody());
				parameters.setOutputVariable('success', true);
				parameters.setOutputVariable('data', responseData);
			}
			else
			{
				parameters.setOutputVariable('success', false);
				parameters.setOutputVariable('errorMessage', 'API returned status: ' + response.getStatusCode());
			}
		}
		catch(Exception e)
		{
			// Log error
			LOG_Builder.build().error(e).emitAt('OMN_ExternalIntegration.call');

			// Return error to Omnistudio
			parameters.setOutputVariable('success', false);
			parameters.setOutputVariable('errorMessage', e.getMessage());
			parameters.setOutputVariable('errorType', e.getTypeName());
		}
	}
}
```

### Omnistudio Configuration

**OmniScript Configuration:**

1. Add "Remote Action" element to OmniScript
2. Select "Apex Class" as Remote Action type
3. Enter `kern__SVC_Omnistudio` as Apex Class
4. Enter your implementation class name (e.g., `OMN_AccountEnrichment`)
5. Map input variables from OmniScript to Apex input parameters
6. Map output variables from Apex to OmniScript variables

**Integration Procedure Configuration:**

1. Add "Apex Action" element to Integration Procedure
2. Select `kern__SVC_Omnistudio` as Callable Class
3. Configure class name parameter with your implementation
4. Map input/output as needed

---

## [Invocable Methods](https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_classes_annotation_InvocableMethod.htm) for Flows

### Logging from Flows ([FLOW_WriteLog](reference/apex/FLOW_WriteLog.md))

**Flow Logging:**

The [`FLOW_WriteLog`](reference/apex/FLOW_WriteLog.md) class provides full logging control including log levels:

```apex
// Log detailed messages with custom log levels from Flow
// In Flow Builder:
// 1. Add "Action" element
// 2. Search for "Write Detailed Log Messages"
// 3. Configure:
//    - logLevel: DEBUG, INFO, WARN, or ERROR
//    - message: Detailed message text
//    - shortMessage: Brief summary
//    - recordId: Related record ID
//    - classMethod: Context identifier (e.g., 'MyFlow.ErrorHandler')

// From Apex (for testing):
FLOW_WriteLog.DTO_Request logRequest =
	new FLOW_WriteLog.DTO_Request();
logRequest.logLevel = 'ERROR';
logRequest.message = 'Account validation failed: missing required Industry field';
logRequest.shortMessage = 'Validation Error';
logRequest.recordId = accountId;
logRequest.classMethod = 'AccountProcessingFlow.ValidationStage';

FLOW_WriteLog.writeLog(
	new List<FLOW_WriteLog.DTO_Request>{logRequest}
);
```

### Email from Flows (FLOW_SendEmail)

**Flow-Based Email Sending:**

The [`FLOW_SendEmail`](reference/apex/FLOW_SendEmail.md) class provides advanced email capabilities for Flows:

```apex
// Send templated emails from Flow with custom merge fields
emailRequest.templateUniqueName = 'Customer_Welcome_Email';
emailRequest.orgWideEmailAddress = 'noreply@company.com';
emailRequest.whatId = opportunityId;
emailRequest.saveAsActivity = true;

List<FLOW_SendEmail.DTO_Response> responses =
	FLOW_SendEmail.sendEmail(new List<FLOW_SendEmail.DTO_Request>{emailRequest});

if(responses[0].success)
{
	// Email sent successfully
}
else
{
	LOG_Builder.build().error('Email failed: ' + responses[0].errors).emitAt('EmailExample.send');
}
```

**Custom Merge Fields:**

```apex
// Use custom merge fields to personalize email templates
// Create custom merge fields
DTO_NameValue mergeField1 = new DTO_NameValue();
mergeField1.name = 'InvoiceNumber';
mergeField1.value = 'INV-2025-001';

DTO_NameValue mergeField2 = new DTO_NameValue();
mergeField2.name = 'PaymentDueDate';
mergeField2.value = '2025-12-31';

// Configure email with merge fields
FLOW_SendEmail.DTO_Request emailRequest = new FLOW_SendEmail.DTO_Request();
emailRequest.toAddress = contactId;
emailRequest.templateUniqueName = 'Invoice_Email';
emailRequest.orgWideEmailAddress = 'billing@company.com';
emailRequest.whatId = accountId;
emailRequest.mergeFields = new List<DTO_NameValue>{mergeField1, mergeField2};

// In email template, use: [InvoiceNumber] and [PaymentDueDate]
// These placeholders will be replaced with actual values

List<FLOW_SendEmail.DTO_Response> responses =
	FLOW_SendEmail.sendEmail(new List<FLOW_SendEmail.DTO_Request>{emailRequest});
```

---

## Health Check

The **Health Check** is a post-install diagnostic built into the **Kern** app. It confirms that the org-level configuration each capability depends on is in place, and offers one-click fixes for the settings it can apply for you. Run it right after installing the package, and again whenever you turn on a new capability.

### Opening the Kern app

If you installed the package as a System Administrator, the **Kern** app is available to you straight away — open the **App Launcher** (the grid icon, top-left), search for **Kern**, and select it. The app's **Home** tab runs the Health Check automatically and shows the results at the top of the page.

To give another user access to the app and its tabs, assign the **Kern Administrator** permission set:

```bash
sf org assign permset -n kern__Administrator -o <username>
```

The check re-runs each time the Home tab loads. Use the refresh icon in the card header to run it again without reloading the page.

### Reading the results

Results are grouped by severity so the items that need attention stay at the top:

- **Action required** — a hard prerequisite is missing, and the capability that depends on it will fail at runtime until you fix it. The most foundational issue sorts first.
- **Review recommended** — the capability works, but a recommended setting is absent. Safe to defer; worth completing before go-live.
- **Passing** — configured and operational. Passing checks collapse into a single row of green chips.

The card header summarises the overall state — for example *Review recommended — 2 warnings*, or *All systems operational* when everything passes.

### What it checks

| Check | When missing | What it verifies |
|-------|--------------|------------------|
| **Organisation Cache** | Action required | Organisation cache is allocated to KernDX's **LibraryCache** partition (the package ships the partition; you allocate the capacity). Without it, automatic integration retries, repeated-error protection, and shared configuration lookups stop working. |
| **Session Cache** | Review recommended | Session cache is allocated to the **LibraryCache** partition. Kern keeps per-user data such as encryption keys here; without it that data falls back to Org Cache. |
| **Trusted Site** | Action required | A Trusted URL is registered for your org domain (Setup &gt; Trusted URLs). Only relevant if you use features that call back into your org, such as streaming channels. |
| **Class Type Resolver** | Review recommended | A custom type resolver is registered so the framework can locate the subscriber Apex classes you reference in configuration. |
| **Data Retention** | Review recommended | A scheduled purge job exists for each framework data object — Log Entries, API Calls, API Issues, and Async Chain Executions. Without one, these records accumulate indefinitely. |

### Built-in fixes

Two checks can repair the configuration for you, without leaving the page:

- **Class Type Resolver → Setup** opens a generator that writes a ready-to-deploy resolver class and its matching test class for you to copy or download. See [Type Resolution](#type-resolution-util_typeresolver) for the resolver pattern and how to register it.
- **Data Retention → Apply Recommended Retention** schedules a nightly purge job for every uncovered object using default retention windows. Choose **Customize each job →** to set the retention period and schedule per object before the jobs are created.

### Administration Tools

Below the Health Check, the Home tab provides quick-launch cards for the framework's operational consoles:

- **API Test Harness** — test inbound and outbound API calls with Safe Mode and mocking control.
- **Streaming Event Monitor** — monitor platform events, change data capture, and custom streaming channels in real time.
- **Chain Monitor** — monitor async chain executions, view step timelines, and diagnose failures in real time.

---

## Anti-Patterns

| Anti-Pattern | Why It's Wrong | Instead |
|---|---|---|
| Writing custom string manipulation instead of using `UTIL_String` | Duplicates framework functionality and increases test burden | Use `UTIL_String` for abbreviation, padding, splitting, joining, and validation |
| Manual date arithmetic (e.g., `date.addDays(1)` loops to skip weekends) | Error-prone for edge cases like holidays and month boundaries | Use `UTIL_Date.addBusinessDays()` and related methods |
| Direct `Schema.describeSObjects()` calls | No caching; repeated calls hit governor limits | Use `UTIL_SObjectDescribe.getDescribe()` for cached, namespace-aware metadata access |
| Using `System.debug()` for logging | Ephemeral output with no queryable persistence or correlation tracking | Use `LOG_Builder.build().info('message').emitAt('Class.method')` |
| Making HTTP callouts without retry or circuit breaker | Single failures cause hard errors with no fault tolerance | Use `UTIL_HttpClient` with `.withRetry()` and `.withCircuitBreaker()` |

---

## Best Practices

### Type Resolution
1. Register custom resolvers via custom metadata for subscriber org extensibility
2. Always check for null before instantiating resolved types
3. Use chain of responsibility for multi-namespace environments
4. Document supported class name formats in resolver implementations

### Random Data Generation
1. Use seeded random for deterministic unit tests
2. Use cryptographically secure UUID for production unique identifiers
3. Don't use random data generation in production business logic
4. Document random data characteristics in test class comments

### SObject Indexing
1. Create indexes before adding large numbers of items
2. Use case-insensitive mode for user-entered data
3. Consider memory usage for large datasets (thousands of records)
4. Document indexed fields and their purpose
5. Clear indexes when no longer needed to free memory

### Metadata Introspection
1. Always use `UTIL_SObjectDescribe.getDescribe()` instead of direct Schema calls to leverage caching
2. Use the default `implyNamespace=true` parameter for managed package compatibility
3. Use relationship names (e.g., `Account`) and let the utility resolve to ID fields automatically
4. Only flush cache when absolutely necessary (e.g., after metadata changes in tests)
5. Use field sets for dynamic forms instead of hardcoding field lists
6. Always check `isPersonAccountEnabled()` before accessing Person Account-specific fields
7. Leverage the wrapped `FieldsMap` and `GlobalDescribeMap` for namespace-aware operations
8. Use deferred loading pattern - getting a describe instance is lightweight

### Feature Flags
1. Default new features to disabled
2. Order strategies from most specific to most general
3. Remove feature flags after full rollout completion
4. Document feature flag purpose and rollout plan
5. Test both enabled and disabled code paths
6. Monitor feature flag usage to understand adoption

### Logging
1. Always include class.method context in log entries
2. Use appropriate log levels (DEBUG, INFO, WARN, ERROR)
3. Associate record IDs when logging relates to specific data
4. Never log sensitive data (passwords, tokens, PII)
5. Use batch logging for related messages
6. Enable test mode only when debugging tests

### Omnistudio Integration
1. Implement error handling in callable classes
2. Return success/error indicators in output variables
3. Log exceptions before returning to Omnistudio
4. Document input/output variable contracts
5. Test callable classes outside Omnistudio first

### Invocable Methods
1. Use descriptive labels and descriptions for Flow discoverability
2. Validate input parameters before processing
3. Return clear success/failure indicators
4. Provide meaningful error messages
5. Test invocable methods both from Apex and Flow

---

## Testing

Utility classes are stateless and straightforward to test. Most utility methods accept primitive inputs and return
primitive outputs, making them ideal for simple assertion-based tests. The framework provides 100% test coverage
for all utility classes; your tests should focus on verifying your own usage of utility methods in your business
logic.

**Testing string utilities:**

```apex
@IsTest
private static void shouldAbbreviateString()
{
	String result = UTIL_String.abbreviate('Now is the time for all good men', 20);
	Assert.areEqual('Now is the time f...', result, 'Should abbreviate to 20 chars');
}
```

**Testing feature flags:**

```apex
@IsTest
private static void shouldRespectFeatureFlag()
{
	TST_Factory.newFeatureFlag('MyFeature');

	Boolean result = UTIL_FeatureFlag.isEnabled('MyFeature');

	Assert.isTrue(result, 'Feature should be enabled');
}
```

**Testing circuit breaker patterns:**

For `UTIL_CircuitBreaker` and `UTIL_Retry`, test both the success path and the failure/recovery paths. Use mock
callouts or deliberately throw exceptions to verify that the circuit opens after the configured failure threshold
and recovers after the reset timeout.

---

## Related Documentation

- **[DML - Guide](DML%20-%20Guide.md)** - Database operations and permissions
- **[Async Processing - Guide](Async%20Processing%20-%20Guide.md)** - Async processing utilities
- **[Web Services - Guide](Web%20Services%20-%20Guide.md)** - API integrations (includes `UTIL_HttpClient` fluent HTTP client)
- **[Selectors - Guide](Selectors%20-%20Guide.md)** - SOQL query utilities
- **[Security - Guide](Security%20-%20Guide.md)** - Security and encryption patterns
- **[Logging - Guide](Logging%20-%20Guide.md)** - Logging framework details
- [Platform Cache Overview](https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_cache_namespace_overview.htm)
- [Platform Event Developer Guide](https://developer.salesforce.com/docs/atlas.en-us.platform_events.meta/platform_events/)
- [Custom Metadata Types](https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_custommetadata.htm)
- [Callable Interface Documentation](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_interface_system_callable.htm)
- [Invocable Methods](https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_classes_annotation_InvocableMethod.htm)
