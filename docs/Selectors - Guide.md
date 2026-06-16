---
navOrder: 12
---

# Selectors - Guide

**Framework:** KernDX
**Package Type:** Managed Package

**Target Audience:**

- **Developers** - Building type-safe SOQL queries with sharing enforcement and reusable query logic
- **Architects** - Designing data access layers with proper abstraction and security controls
- **Business Analysts** - Understanding query capabilities, sharing rules, and data access patterns

---

## Table of Contents

<details>
<summary>Expand</summary>

1. [Quick Navigation](#quick-navigation)
2. [Overview](#overview)
3. [Quick Start](#quick-start)
4. [Escape Hatches](#escape-hatches)
5. [Architecture](#architecture)
    - [KernDX vs OOTB: Selector Framework Comparison](#kerndx-vs-ootb-selector-framework-comparison)
        - [Salesforce Out-of-the-Box Alternative](#salesforce-out-of-the-box-alternative)
        - [Pros & Cons Comparison](#pros--cons-comparison)
        - [When to Use KernDX Selector Framework](#when-to-use-kerndx-selector-framework)
        - [When to Use OOTB Inline SOQL](#when-to-use-ootb-inline-soql)
        - [Example Comparison](#example-comparison)
    - [Layer 1: QRY_Builder (Recommended Default for Subscriber Orgs)](#layer-1-qry_builder-recommended-default-for-subscriber-orgs)
    - [Layer 2: SEL_Base](#layer-2-sel_base)
    - [Layer 3: QRY_Condition](#layer-3-qry_condition)
5. [Basic Queries](#basic-queries)
    - [findById](#findbyid)
    - [findByField](#findbyfield)
6. [Advanced Queries](#advanced-queries)
    - [Complex WHERE Conditions](#complex-where-conditions)
    - [ORDER BY and LIMIT](#order-by-and-limit)
    - [Pagination](#pagination)
7. [Query Builder](#query-builder)
    - [SELECT and FROM](#select-and-from)
    - [WHERE Conditions](#where-conditions)
    - [Aggregate Functions](#aggregate-functions)
    - [GROUP BY](#group-by)
8. [Sharing Enforcement](#sharing-enforcement)
    - [Enforcing Sharing](#enforcing-sharing)
    - [Bypassing Sharing](#bypassing-sharing)
    - [USER_MODE Security](#user_mode-security)
    - [Strip Inaccessible Fields](#strip-inaccessible-fields)
9. [Complex Examples](#complex-examples)
    - [Parent-to-Child Subqueries](#parent-to-child-subqueries)
    - [Semi-Join Subqueries](#semi-join-subqueries)
    - [Aggregate Queries](#aggregate-queries)
    - [QueryLocator for Batch Apex](#querylocator-for-batch-apex)
10. [Custom Selector Classes](#custom-selector-classes)
11. [QRY_Builder Examples](#qry_builder-examples)
    - [Basic Queries](#basic-queries-1)
        - [Simple Field Selection](#simple-field-selection)
        - [Query with Single Condition](#query-with-single-condition)
        - [Query with Multiple AND Conditions](#query-with-multiple-and-conditions)
        - [Query with OR Conditions](#query-with-or-conditions)
        - [Explicit Condition Grouping](#explicit-condition-grouping)
    - [Advanced Filtering](#advanced-filtering)
        - [Using IN Operator with Collection](#using-in-operator-with-collection)
        - [Using IN Operator with SObjects](#using-in-operator-with-sobjects)
        - [String Pattern Matching](#string-pattern-matching)
        - [Multi-Picklist Field Filtering](#multi-picklist-field-filtering)
        - [Date Literal Conditions](#date-literal-conditions)
    - [Parent Relationship Queries](#parent-relationship-queries)
        - [Querying Related Fields](#querying-related-fields)
    - [Caching Queries](#caching-queries)
        - [Platform Cache Integration](#platform-cache-integration)
    - [Query Performance Logging](#query-performance-logging)
        - [Force Logging a Query](#force-logging-a-query)
        - [Custom Threshold per Query](#custom-threshold-per-query)
        - [Suppress Logging](#suppress-logging)
        - [Logging Hierarchy](#logging-hierarchy)
    - [Aggregate Queries](#aggregate-queries-1)
        - [Simple Aggregation](#simple-aggregation)
        - [Aggregation with HAVING Clause](#aggregation-with-having-clause)
        - [Multiple Grouping Fields](#multiple-grouping-fields)
    - [Multi-Field Grouping](#multi-field-grouping)
        - [GROUP BY ROLLUP (Subtotals)](#group-by-rollup-subtotals)
        - [GROUP BY CUBE (Cross-Tabulation)](#group-by-cube-cross-tabulation)
    - [SOQL Functions in Queries](#soql-functions-in-queries)
        - [Date Functions in GROUP BY](#date-functions-in-group-by)
        - [toLabel (Picklist Translation)](#tolabel-picklist-translation)
        - [FORMAT (Localized Formatting)](#format-localized-formatting)
    - [Result Transformation](#result-transformation)
        - [Converting to Map](#converting-to-map)
        - [Extracting Id Sets](#extracting-id-sets)
        - [Extracting Field Values](#extracting-field-values)
    - [Existence Checks](#existence-checks)
        - [Checking if Records Exist](#checking-if-records-exist)
    - [Security & Row Locking](#security--row-locking)
        - [Security Methods Overview](#security-methods-overview)
        - [USER_MODE Security (CRUD, FLS, and Sharing)](#user_mode-security-crud-fls-and-sharing)
        - [Strip Inaccessible Fields](#strip-inaccessible-fields-1)
        - [Combining Security Options](#combining-security-options)
        - [Sharing Control (SYSTEM_MODE only)](#sharing-control-system_mode-only)
        - [Conditional Field Addition Based on Access](#conditional-field-addition-based-on-access)
        - [Row Locking for Updates](#row-locking-for-updates)
    - [Scoped Queries](#scoped-queries)
        - [Using USING SCOPE](#using-using-scope)
    - [Data Category Queries](#data-category-queries)
        - [Operators](#operators)
        - [Single Category Filter](#single-category-filter)
        - [Multiple Categories in One Group](#multiple-categories-in-one-group)
        - [Multiple Groups (AND)](#multiple-groups-and)
        - [Hierarchy Traversal with BELOW](#hierarchy-traversal-with-below)
        - [Constraints](#constraints)
    - [Batch Processing](#batch-processing)
        - [QueryLocator for Batch Apex](#querylocator-for-batch-apex-1)
        - [Cursor-Based Processing](#cursor-based-processing)
    - [Custom Reusable Selectors (5% Use Case)](#custom-reusable-selectors-5-use-case)
        - [Extending Builder](#extending-builder)
    - [Combining Multiple Patterns](#combining-multiple-patterns)
        - [Complex Real-World Example](#complex-real-world-example)
12. [Testing](#testing)
    - [Basic Query Mocking](#basic-query-mocking)
    - [Creating Mock Records](#creating-mock-records)
    - [Multiple Query Mocking](#multiple-query-mocking)
    - [Mocking with TST_Mock](#mocking-with-tst_mock)
    - [Limitations](#limitations)
        - [AggregateResult Mocking Not Supported](#aggregateresult-mocking-not-supported)
        - [Query Conditions Not Evaluated](#query-conditions-not-evaluated)
        - [Mock Scope](#mock-scope)
13. [Capability Matrix (for Analysts)](#capability-matrix-for-analysts)
14. [Anti-Patterns](#anti-patterns)
15. [Best Practices](#best-practices)
    - [Always Use Selector Classes](#always-use-selector-classes)
    - [Use query Property Inside Selectors, QRY_Builder for One-Off](#use-query-property-inside-selectors-qry_builder-for-one-off)
    - [Create Custom Selector Classes for Each SObject](#create-custom-selector-classes-for-each-sobject)
    - [Use Type-Safe Field References](#use-type-safe-field-references)
    - [Be Explicit About Sharing](#be-explicit-about-sharing)
    - [Choose the Right Layer](#choose-the-right-layer)
    - [Use QueryLocator for Batch Apex](#use-querylocator-for-batch-apex)
    - [Avoid Query Loops](#avoid-query-loops)
    - [Test with TST_Builder](#test-with-tst_builder)
    - [Document Query Methods](#document-query-methods)
    - [Handle Null and Empty Collections](#handle-null-and-empty-collections)
    - [Use Pagination for Large Result Sets](#use-pagination-for-large-result-sets)
    - [Leverage Subqueries for Efficiency](#leverage-subqueries-for-efficiency)
16. [Related Documentation](#related-documentation)

</details>

---

## Quick Navigation

| I am a...     | I need to...                   | Go to...                                                        |
|---------------|--------------------------------|-----------------------------------------------------------------|
| **Architect** | Understand query architecture  | [Architecture](#architecture)                                   |
| **Architect** | Compare with OOTB SOQL         | [KernDX vs OOTB](#kerndx-vs-ootb-selector-framework-comparison) |
| **Developer** | Query records                  | [Quick Start](#quick-start)                                     |
| **Developer** | Build complex queries          | [QRY_Builder Examples](#qry_builder-examples)                   |
| **Developer** | Create custom selectors        | [Custom Selector Classes](#custom-selector-classes)             |
| **Analyst**   | Understand sharing enforcement | [Capability Matrix](#capability-matrix-for-analysts)            |

---

## Overview

The Selector Framework provides a layered, type-safe approach to querying SObjects in Salesforce without writing hardcoded SOQL strings. It promotes consistency, maintainability,
and security by abstracting database operations into reusable components.

**Managed Package Context:**

This framework is exposed as global classes in a managed package. When calling these classes from a subscriber org, use the appropriate namespace prefix (e.g., [`SEL_Base`](reference/apex/SEL_Base.md)). The framework is shared with clients who can build and manage the package themselves.

The framework consists of three complementary layers:

1. **[SEL_Base](reference/apex/SEL_Base.md)** - **Production pattern** - Object-specific selectors with default fields and reusable query methods
2. **[QRY_Builder](reference/apex/QRY_Builder.md)** - **Query engine** - Fluent query builder with caching, pagination, and result transformation
3. **[QRY_Condition](reference/apex/QRY_Condition.md)** - Low-level condition builders and operators

**For production code, create selectors** by extending [`SEL_Base`](reference/apex/SEL_Base.md) (e.g., `SEL_Accounts`, `SEL_Contacts`) with default field sets, inherited
`findById()`/`findByField()` methods, and custom query methods that use the `query` property.

**For one-off queries** (anonymous Apex, scripts, objects without a selector), use [`QRY_Builder`](reference/apex/QRY_Builder.md) directly. Selectors use QRY_Builder internally via
the `query` property — it's the engine, not the alternative.

> **Selector Framework Scope:** 44 `SEL_*` classes (most extend `SEL_Base`), plus the `QRY_Builder`
> fluent API with caching, pagination, semi-joins, aggregates, and 5 security modes.

> **Responsibilities:** Selectors only query data. They do not perform DML, contain business logic, or mutate
> records. All data modification belongs in trigger actions, service classes, or DML operations.

> **When NOT to use this pattern:**
> - One-off admin scripts or anonymous Apex where inline SOQL is simpler and disposable
> - Tiny throwaway logic where the overhead of a selector class adds no value
> - Tests where inline SOQL against inserted records improves readability and is not reused

**Key Benefits:**

- **Type Safety** - SObjectField references prevent typos and invalid field names
- **Sharing Control** - Explicit enforcement or bypass of sharing rules
- **Testability** - Mockable query logic and consistent patterns
- **Maintainability** - Centralized query logic in selector classes
- **Security** - Built-in USER_MODE enforcement (CRUD, FLS, and sharing at the database level), bind variables, and automatic literal escaping
- **Consistency** - Standardized query patterns across the codebase
- **Performance** - Bind variables enable better query plan caching

## Quick Start

Extend `SEL_Base` to create reusable, object-specific selectors with built-in query methods.

> **Step-by-step walkthrough:** [Fast Start - Selectors](Fast%20Start%20-%20Selectors.md) covers implementation,
> testing, and common pitfalls.

```apex
public inherited sharing class SEL_Accounts extends SEL_Base
{
	public SEL_Accounts()
	{
		super(Account.SObjectType);
	}

	public override List<SObjectField> getFields()
	{
		return new List<SObjectField>{ Account.Name, Account.Industry };
	}
}

// Usage
Account account = (Account)new SEL_Accounts().findById(accountId);
```

For deeper coverage, continue reading the sections below.

---

## Escape Hatches

The selector framework is opt-in. `QRY_Builder` is the recommended default for subscriber orgs; `SEL_Base` is for the ~5% of queries that genuinely benefit from a reusable selector
class. When the abstraction doesn't fit, native SOQL is always available — and the framework's own LWCs use Salesforce's native client-side caching directly.

| You need                                                        | Use                                                                                                                                                                                                                                                                   | See                                                           |
|-----------------------------------------------------------------|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|---------------------------------------------------------------|
| **One-off inline SOQL** (prototype, simple query, debug helper) | Standard `[SELECT … FROM …]` syntax — no framework wrapper required.                                                                                                                                                                                                  | [When to Use OOTB Inline SOQL](#when-to-use-ootb-inline-soql) |
| **Bypass sharing for a single query**                           | `QRY_Builder.bypassSharing()` — routes through `without sharing` for that query only.                                                                                                                                                                                 | [Bypassing Sharing](#bypassing-sharing)                       |
| **USER_MODE enforcement per query**                             | `QRY_Builder.withUserMode()` — enforces FLS + CRUD at query time.                                                                                                                                                                                                     | [USER_MODE Security](#user_mode-security)                     |
| **Native Lightning Data Service caching in LWC**                | `@wire(getRecord)`, `@wire(getObjectInfo)`, `@wire(getRecordCreateDefaults)` from `lightning/uiRecordApi` / `lightning/uiObjectInfoApi` — used by framework components like `scheduledJobDetail`, `sObjectLookup`, `createForm`. No lint or scanner rule blocks them. | [LWC - Guide](LWC%20-%20Guide.md)                             |
| **Cacheable Apex bridge for LWC**                               | `@AuraEnabled(cacheable=true)` on a controller method — used in framework code like `CTRL_FeatureFlag`.                                                                                                                                                               | [LWC - Guide](LWC%20-%20Guide.md)                             |
| **Raw `Database.query()` / `Database.queryWithBinds()`**        | Works unmodified — nothing intercepts platform SOQL.                                                                                                                                                                                                                  | —                                                             |

The selector layer is a productivity convenience, not a wall. Reach for it when its features pay off; skip it when they don't.

---

## Architecture

```text
┌─────────────────────────────────────────────────────────────────────────────┐
│                        SELECTOR FRAMEWORK ARCHITECTURE                        │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                               │
│   SUBSCRIBER ORG CODE                                                         │
│   ==================                                                          │
│           │                                                                   │
│           ▼                                                                   │
│   ┌───────────────────────────────────────────────────────────────────────┐  │
│   │  Layer 1: SEL_Base (Production Pattern — reusable selectors)           │  │
│   │  - Extend for custom selectors (SEL_Accounts, SEL_Contacts)          │  │
│   │  - Default fields, findById, findByField, custom query methods       │  │
│   └───────────────────────────────┬───────────────────────────────────────┘  │
│                                   │ uses `query` property                     │
│                                   ▼                                           │
│   ┌───────────────────────────────────────────────────────────────────────┐  │
│   │  Layer 2: QRY_Builder (Query Engine — also for one-off queries)        │  │
│   │  - Fluent API: selectFrom().fields().condition().toList()             │  │
│   │  - Caching, pagination, result transformation                         │  │
│   └───────────────────────────────┬───────────────────────────────────────┘  │
│                                   │                                           │
│                                   ▼                                           │
│   ┌───────────────────────────────────────────────────────────────────────┐  │
│   │  Layer 3: QRY_Condition                                               │  │
│   │  - Low-level condition builders and operators                         │  │
│   │  - AND/OR condition trees                                             │  │
│   └───────────────────────────────┬───────────────────────────────────────┘  │
│                                   │                                           │
│                                   ▼                                           │
│                        ┌─────────────────────┐                               │
│                        │   Database.query()  │                               │
│                        └─────────────────────┘                               │
│                                                                               │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

### KernDX vs OOTB: Selector Framework Comparison

#### Salesforce Out-of-the-Box Alternative

Salesforce provides **inline SOQL** as the standard query mechanism:

```apex
List<Account> accounts = [SELECT Id, Name, Industry FROM Account WHERE Industry = 'Technology'];
```

#### Pros & Cons Comparison

| Feature                       | KernDX Selector Framework                                                                               | Salesforce OOTB Inline SOQL                                                                           |
|-------------------------------|---------------------------------------------------------------------------------------------------------|-------------------------------------------------------------------------------------------------------|
| **Field Type Safety**         | ✅ `SObjectField` references prevent field name typos                                                    | ✅ Compile-time field checking (both use `SObjectField`)                                               |
| **Centralized Queries**       | ✅ selector classes consolidate all queries for an object                                                | ⚠️ Queries typically scattered across codebase                                                        |
| **Sharing Control**           | ✅ Explicit `withSharing()` / `bypassSharing()` methods                                                  | ✅ `with sharing` / `without sharing` / `inherited sharing` keywords + `WITH USER_MODE` clause |
| **Dynamic Queries**           | ✅ [`QRY_Builder`](reference/apex/QRY_Builder.md) fluent API, type-safe                                  | ⚠️ Requires `Database.query()` with string concatenation                                              |
| **SOQL Injection Protection** | ✅ Bind variables where possible, automatic escaping as fallback                                         | ⚠️ Manual escaping required for dynamic queries                                                       |
| **Result Caching**            | ✅ Built-in Platform Cache integration (`cacheTTL`, `userScopedCache` params)                            | ❌ Manual cache implementation required                                                                |
| **Cursor Support**            | ✅ Automatic `Database.getCursor()` for compatible queries (bypasses 2K OFFSET limit, supports 50M rows) | ⚠️ Manual `Database.getCursor()` implementation required                                              |
| **Pagination**                | ✅ Built-in with auto Cursor/OFFSET selection                                                            | ⚠️ Manual OFFSET (2K limit) or Cursor implementation                                                  |
| **QueryLocator**              | ✅ `getQueryLocator()` method for Batch Apex                                                             | ✅ `Database.getQueryLocator()` available                                                              |
| **Reusability**               | ✅ selector methods called from anywhere                                                                 | ❌ Must duplicate SOQL or create helper classes                                                        |
| **Query Pattern Consistency** | ✅ Enforced patterns across all queries                                                                  | ⚠️ Each developer may structure queries differently                                                   |
| **Refactoring**               | ✅ `SObjectField` auto-updated by IDE in method calls                                                    | ✅ `SObjectField` auto-updated in inline SOQL too                                                      |
| **Complex Conditions**        | ✅ Programmatic `addCondition()` with `OrCondition` / `AndCondition`                                     | ⚠️ Manual parentheses in string for dynamic queries                                                   |
| **Simplicity**                | ⚠️ Requires selector class creation and framework knowledge                                             | ✅ Direct SOQL, familiar to all Salesforce developers                                                  |
| **Performance**               | ⚠️ Framework overhead (minimal, optional caching)                                                       | ✅ Direct database access, no overhead                                                                 |
| **Learning Curve**            | ⚠️ Must learn selector patterns and framework APIs                                                      | ✅ Standard SOQL/Apex knowledge                                                                        |

#### When to Use KernDX Selector Framework

- ✅ **Enterprise applications** with complex data access patterns
- ✅ **Large datasets** requiring pagination beyond 2,000 OFFSET limit (auto Cursor support)
- ✅ **High-volume queries** processing millions of records efficiently
- ✅ **Reusable queries** needed across multiple classes
- ✅ **Query result caching** for frequently-accessed data
- ✅ **Type safety** to prevent field name errors
- ✅ **Dynamic queries** built at runtime
- ✅ **Explicit sharing control** requirements
- ✅ **Centralized query logic** for maintainability
- ✅ **Multiple developers** to ensure consistency

#### When to Use OOTB Inline SOQL

- ✅ **Simple one-off queries** not reused elsewhere
- ✅ **Quick prototypes** or scripts
- ✅ **Maximum performance** is critical
- ✅ **Small codebases** with minimal queries
- ✅ **Small result sets** (< 2,000 rows for pagination)
- ✅ **No sharing complexity** (all queries same sharing model)
- ✅ **Developers prefer** direct SOQL visibility

#### Example Comparison

**OOTB Inline SOQL (Scattered, String-Based):**

```apex
// Query 1: In AccountService.cls
List<Account> accounts = [
    SELECT Id, Name, Industry
    FROM Account
    WHERE Industry = :industry
    AND AnnualRevenue > :minRevenue
    ORDER BY Name
    LIMIT 100
];

// Query 2: In AccountController.cls (duplicate logic)
List<Account> accounts = [
    SELECT Id, Name, Industry // Field list duplicated across classes — refactoring risk
    FROM Account
    WHERE Industry = :industry
    AND AnnualRevenue > :minRevenue
    ORDER BY Name
    LIMIT 100
];

// Query 3: Dynamic query (error-prone)
String query = 'SELECT Id, Name FROM Account WHERE ';
if(industry != null) {
    query += 'Industry = \'' + industry + '\' AND '; // SQL injection risk!
}
query += 'AnnualRevenue > ' + minRevenue;
List<Account> accounts = Database.query(query);
```

**KernDX Selector Framework (Centralized, Type-Safe):**

```apex
// SEL_Accounts.cls - Single source of truth
public inherited sharing class SEL_Accounts extends SEL_Base
{
	public SEL_Accounts()
	{
		super(Account.SObjectType);
	}

	public override List<SObjectField> getFields()
	{
		return new List<SObjectField>
		{
			Account.Name,
			Account.Industry,
			Account.AnnualRevenue
		};
	}

	// Type-safe field references (typos caught at compile time)
	public List<Account> findByIndustryAndRevenue(String industry, Decimal minRevenue)
	{
		return (List<Account>)query
			.condition(Account.Industry).equals(industry)
			.andCondition(Account.AnnualRevenue).greaterThan(minRevenue)
			.orderBy(Account.Name).ascending()
			.withLimit(100)
			.toList();
	}

	// Dynamic query building (safe, type-checked)
	public List<Account> findByDynamicCriteria(String industry, Decimal minRevenue)
	{
		QRY_Builder.Builder builder = query;

		if(String.isNotBlank(industry))
		{
			builder = builder.condition(Account.Industry).equals(industry);
		}

		if(minRevenue != null)
		{
			builder = builder.andCondition(Account.AnnualRevenue).greaterThan(minRevenue);
		}

		return builder.toList();
	}
}

// Usage in any class (consistent, reusable)
List<Account> accounts = new SEL_Accounts().findByIndustryAndRevenue('Technology', 1000000);
```

**Key Advantages Demonstrated:**

1. **Type Safety**: `Account.Industry` vs `"Industry"` string
2. **Centralization**: Single selector class vs scattered queries
3. **Reusability**: Call method from anywhere
4. **Refactoring**: IDE updates `SObjectField` references automatically
5. **No SOQL Injection**: Framework uses bind variables where possible, with literal escaping as fallback
6. **Consistency**: All queries follow same pattern

---

### Layer 1: [QRY_Builder](reference/apex/QRY_Builder.md) **(Recommended Default for Subscriber Orgs)**

**Purpose:** Modern fluent query builder that provides an intuitive API for building and
executing [SOQL queries](https://developer.salesforce.com/docs/atlas.en-us.soql_sosl.meta/soql_sosl/sforce_api_calls_soql.htm). Provides enterprise features like caching,
cursor-based pagination, and sharing enforcement.

**When to Use:** **This is the recommended default for developers in subscriber org implementations.** Use `QRY_Builder` for 95% of your query needs - it combines ease of use with
enterprise capabilities.

**Key Features:**

**Field Selection:**

- `selectFrom()` - Entry point - specify SObject type to query
- `fields()` / `addFields()` - Define fields to retrieve (SObjectField or String)
- `addField()` - Add a single field
- `selectAllFields()` - Select all fields on object (use with caution)
- `fieldSet()` / `addFieldSet()` - Select fields from FieldSet
- `relatedField()` / `relatedFields()` - Add parent relationship fields
- `subselect()` - Add child relationship subquery

**WHERE Conditions:**

- `condition()` / `andCondition()` / `orCondition()` - Build WHERE conditions
- `addCondition()` - Explicit condition grouping for complex logic (accepts `OrCondition` / `AndCondition`)
- Operators: `equals()`, `notEquals()`, `greaterThan()`, `greaterThanOrEquals()`, `lessThan()`, `lessThanOrEquals()`
- Collection operators: `isIn()`, `notInSet()` (safe empty list handling), `isInStrict()`, `notInSetStrict()` (throws on empty)
- SObject operators: `isIn(List<SObject>)`, `isIn(List<SObject>, SObjectField)`, `notInSet(List<SObject>)`, `notInSet(List<SObject>, SObjectField)`, `equals(SObject)`,
  `notEquals(SObject)`
- Semi-join subqueries: `isIn(Builder)`, `notIn(Builder)`
- Null checks: `isNull()`, `isNotNull()`
- String matching: `contains()`, `startsWith()`, `endsWith()`
- Multi-picklist: `includes()`, `excludes()` (safe empty list handling), `includesStrict()`, `excludesStrict()` (throws on empty)

> **SQL Precedence:** AND binds tighter than OR. For example, `A AND B OR C AND D` produces `(A AND B) OR (C AND D)`. Use `addCondition()` with `QRY_Condition.OrCondition` /
`QRY_Condition.AndCondition` when you need explicit control over grouping.

**Aggregates & Grouping:**

- `sum()` / `avg()` / `min()` / `max()` / `count()` - Aggregate functions
- `groupBy()` - Group by a field (`String` or `SObjectField`); call multiple times for multi-field grouping
- `havingSumOf()` / `havingAvgOf()` / `havingMinOf()` / `havingMaxOf()` / `havingCountOf()` / `havingCount()` - HAVING conditions

**Ordering & Limits:**

- `orderBy()` then `ascending()` / `descending()` / `nullsFirst()` / `nullsLast()` - Define sorting
- `orderBy(field, sortDescending)` / `orderBy(field, sortDescending, nullsLast)` - Dynamic sorting with booleans
- `withLimit()` / `withOffset()` - Control result sets

**Security & Performance:**

- **Default access mode:** Subscriber-reachable queries default to `AccessLevel.USER_MODE` (CRUD, FLS, sharing enforced) via the `UserModeQueries_Enabled` feature flag.
  Framework-internal selectors override the `systemModeRequired()` hook on `SEL_Base` to opt into `AccessLevel.SYSTEM_MODE`.
  See [Security Guide — Secure-by-Default Defaults](Security%20-%20Guide.md#secure-by-default-defaults).
- `withUserMode()` - Force `AccessLevel.USER_MODE` (enforces CRUD, FLS, and sharing at DB level) regardless of flag state
- `withSystemMode()` - Force `AccessLevel.SYSTEM_MODE` (bypasses CRUD/FLS; typically paired with `.bypassSharing()` for framework-internal reads) regardless of flag state
- `stripInaccessible()` - Remove inaccessible fields from results post-query
- `withSharing()` / `bypassSharing()` - Control sharing via proxy class (SYSTEM_MODE only)
- `withoutSecurity()` - Clear USER_MODE, strip, and sharing selections (forces SYSTEM_MODE with inherited sharing regardless of the flag default)
- `withCache()` - Enable platform cache for query results
- `fields(List, AccessType)` / `addField(field, AccessType)` - Add fields with security checks

**Query Performance Logging:**

- `forcePerformanceLogging()` - Force logging this query regardless of threshold settings
- `logPerformanceIfSlowerThan(ms)` - Log if query exceeds custom threshold (overrides global setting)
- `suppressPerformanceLogging()` - Prevent performance logging for this query (use for high-frequency internal queries)

**Row Locking & Special Clauses:**

- `forUpdate()` / `forReference()` / `forView()` - Row locking
- `allRows()` - Include archived/deleted records
- `usingScope()` - Filter by visibility scope (MINE, MY_TERRITORY, TEAM, etc.)

**Execution & Results:**

- `toSoql()` - Generate SOQL string without executing
- `toList()` - Execute query and return results as List
- `getFirst()` - Get first matching record
- `count()` - Count matching records
- `exists()` - Check if any records exist (more efficient than count())
- `toQueryLocator()` - Get QueryLocator for batch processing
- `toCursor()` - Get Database.Cursor for efficient large dataset traversal (bypasses 2K OFFSET limit)

**Result Transformation:**

- `asMap()` - Convert results to Map<Id, SObject> keyed by record Id
- `asMapById(field)` / `asMapByString(field)` - Convert results to Map keyed by any Id or String field
- `asGroupedMapById(field)` / `asGroupedMapByString(field)` - Group records by any Id or String field (preserves duplicates)
- `asIdSet()` / `asIdList()` - Extract record Ids as Set or List
- `asValueSet()` - Extract field values as Set
- `isCached()` - Check if last results came from cache
  **Extensibility:**
- Custom selectors via `SEL_Base` extension (the production pattern for reusable queries)

**Advantages Over Inline SOQL:**

- Type-safe field references prevent typos
- Automatic cache management
- Intelligent cursor vs OFFSET selection for large datasets
- Chainable API reduces boilerplate
- Built-in result transformation methods
- Consistent security enforcement

**Example:**

```apex
/**
 * @description Retrieves technology accounts with high revenue
 *
 * @param minimumRevenue Minimum annual revenue threshold
 *
 * @return List of matching Account records
 */
public static List<Account> findHighValueTechnologyAccounts(Decimal minimumRevenue)
{
	return QRY_Builder.selectFrom(Account.SObjectType)
		.fields(new List<SObjectField>{ Account.Name, Account.Industry, Account.AnnualRevenue })
		.condition(Account.Industry).equals('Technology')
		.andCondition(Account.AnnualRevenue).greaterThan(minimumRevenue)
		.orderBy(Account.AnnualRevenue).descending()
		.withLimit(100)
		.toList();
}
```

**Caching Example:**

```apex
/**
 * @description Retrieves frequently accessed account data with caching
 *
 * @param accountId Account Id to retrieve
 *
 * @return Account record with cached data
 */
public static Account findByIdCached(Id accountId)
{
	return (Account)QRY_Builder.selectFrom(Account.SObjectType)
		.fields(new List<SObjectField>{Account.Name, Account.Industry, Account.Phone})
		.condition(Account.Id).equals(accountId)
		.withCache(300) // Cache for 5 minutes
		.getFirst();
}
```

**Custom Selector Pattern (Production — the standard for reusable queries):**

```apex
/**
 * @description Selector for Contact queries with default fields and reusable methods.
 */
public inherited sharing class SEL_Contacts extends SEL_Base
{
	public SEL_Contacts()
	{
		super(Contact.SObjectType);
	}

	public override List<SObjectField> getFields()
	{
		return new List<SObjectField>
		{
			Contact.FirstName, Contact.LastName, Contact.Email, Contact.Phone, Contact.AccountId
		};
	}

	public List<Contact> findByAccountId(Id accountId)
	{
		return query.condition(Contact.AccountId).equals(accountId).toList();
	}
}

// Usage — default fields included automatically
List<Contact> contacts = new SEL_Contacts().findByAccountId(accountId);
Contact contact = (Contact)new SEL_Contacts().findById(contactId);
```

### Layer 2: [SEL_Base](reference/apex/SEL_Base.md)

**Purpose:** Base class for object-specific [selectors](https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_enterprise_patterns_selector_layer.htm) with
default fields and reusable query methods.

**When to Use:** Create custom selector classes extending `SEL_Base` when you need reusable, object-specific queries with consistent default field sets.

**Key Features:**

- `findById()` - Query by record ID(s)
- `findByField()` - Query by any field value(s)
- `getFields()` - Override to define consistent field sets per object

**Example:** Uses the same `SEL_Accounts` structure shown in [Basic Queries](#basic-queries) below, with `findById()` and `findByField()` inherited from `SEL_Base`:

```apex
Account account = (Account)new SEL_Accounts().findById(accountId);
List<Account> accounts = new SEL_Accounts().findByField(Account.Industry, 'Technology');
```

### Layer 3: [QRY_Condition](reference/apex/QRY_Condition.md)

**Purpose:** Building blocks
for [WHERE conditions](https://developer.salesforce.com/docs/atlas.en-us.soql_sosl.meta/soql_sosl/sforce_api_calls_soql_select_conditionexpression.htm), operators, and field
comparisons.

**When to Use:** When constructing complex condition logic for [QRY_Builder](reference/apex/QRY_Builder.md) queries or [SEL_Base](reference/apex/SEL_Base.md) selectors.

**Key Features:**

- Condition builders: `equals()`, `notEquals()`, `greaterThan()`, `lessThan()`, `likeX()`
- Nestable conditions: `AndCondition`, `OrCondition`
- Field conditions with type-safe operators
- `OrderBy` for sorting specifications

**Example:**

```apex
/**
 * @description Creates complex OR condition for account search
 *
 * @param industry Industry value
 * @param type Account type value
 *
 * @return OrCondition combining multiple criteria
 *
 * @example
 * ```apex
 * QRY_Condition.OrCondition condition = buildAccountCondition('Technology', 'Customer');
 * ```

*/
public static QRY_Condition.OrCondition buildAccountCondition(String industry, String type)
{
QRY_Condition.OrCondition orCondition = new QRY_Condition.OrCondition();
orCondition.add(new QRY_Condition.FieldCondition(Account.Industry).equals(industry));
orCondition.add(new QRY_Condition.FieldCondition(Account.Type).equals(type));
return orCondition;
}

```

---

## Basic Queries

These examples assume a custom selector class `SEL_Accounts` extending [SEL_Base](reference/apex/SEL_Base.md):

```apex
public inherited sharing class SEL_Accounts extends SEL_Base
{
	public SEL_Accounts()
	{
		super(Account.SObjectType);
	}

	public override List<SObjectField> getFields()
	{
		return new List<SObjectField>
		{
			Account.Name,
			Account.Industry,
			Account.AnnualRevenue
		};
	}
}
```

### findById

Retrieve records by their Salesforce Id using [SEL_Base.findById](reference/apex/SEL_Base.md).

**Example:**

```apex
// Retrieves a single account by Id
Account account = (Account)new SEL_Accounts().findById(accountId);

// Retrieves multiple accounts by Ids
List<Account> accounts = new SEL_Accounts().findById(accountIds);
```

Alternatively, use [QRY_Builder](reference/apex/QRY_Builder.md) directly:

```apex
Account account = (Account)QRY_Builder.selectFrom(Account.SObjectType)
	.fields(new List<SObjectField>{ Account.Name, Account.Industry, Account.AnnualRevenue })
	.condition(Account.Id).equals(accountId)
	.getFirst();
```

### findByField

Retrieve records by any field value(s).

**Example:**

```apex
// Finds accounts by industry
List<Account> accounts = new SEL_Accounts().findByField(Account.Industry, 'Technology');
```

Or use [QRY_Builder](reference/apex/QRY_Builder.md) for more complex field-based queries:

```apex
// Finds accounts by multiple industries
List<Account> accounts = QRY_Builder.selectFrom(Account.SObjectType)
	.fields(new List<SObjectField>{ Account.Name, Account.Industry, Account.AnnualRevenue })
	.condition(Account.Industry).isIn(new List<String>{'Technology', 'Finance', 'Healthcare'})
	.toList();
```

---

## Advanced Queries

### Complex WHERE Conditions

Combine multiple conditions using AND/OR logic with [QRY_Builder](reference/apex/QRY_Builder.md).

**Example:**

```apex
/**
 * @description Finds accounts matching complex business criteria
 *
 * @param industries Set of industries to include
 * @param minRevenue Minimum annual revenue
 * @param types Set of account types to include
 *
 * @return List of matching accounts
 *
 * @example
 * ```apex
 * Set<String> industries = new Set<String>{'Technology', 'Finance'};
 * Set<String> types = new Set<String>{'Customer', 'Partner'};
 * List<Account> accounts = findByComplexCriteria(industries, 1000000, types);
 * ```

*/
public static List<Account> findByComplexCriteria(Set<String> industries, Decimal minRevenue, Set<String> types)
{
return QRY_Builder.selectFrom(Account.SObjectType)
.fields(new List<SObjectField>{ Account.Name, Account.Industry, Account.Type, Account.AnnualRevenue })
.condition(Account.Industry).isIn(new List<String>(industries))
.andCondition(Account.AnnualRevenue).greaterThanOrEquals(minRevenue)
.orCondition(Account.Type).isIn(new List<String>(types))
.toList();
}

```

### ORDER BY and LIMIT

Sort and limit query results.

**Example:**
```apex
/**
 * @description Gets top N accounts by revenue
 *
 * @param topN Number of accounts to return
 *
 * @return List of top N accounts by revenue
 *
 * @example
 * ```apex
 * List<Account> topAccounts = getTopAccountsByRevenue(10);
 * ```

*/
public static List<Account> getTopAccountsByRevenue(Integer topN)
{
return QRY_Builder.selectFrom(Account.SObjectType)
.fields(new List<SObjectField>{ Account.Name, Account.AnnualRevenue, Account.Industry })
.condition(Account.AnnualRevenue).isNotNull()
.orderBy(Account.AnnualRevenue).descending()
.withLimit(topN)
.toList();
}

```

**Dynamic sorting** — when the sort direction comes from a variable (e.g., UI column sorting), use the boolean overloads to avoid `if/else` blocks:

```apex
public static List<Account> getAccountsSorted(SObjectField sortField, Boolean sortDescending)
{
	return QRY_Builder.selectFrom(Account.SObjectType)
		.fields(new List<SObjectField>{Account.Name, Account.AnnualRevenue})
		.orderBy(sortField, sortDescending)
		.toList();
}
```

The three-parameter variant also controls nulls placement:

```apex
.orderBy(Account.AnnualRevenue, true, true)  // DESC NULLS LAST
```

Both `SObjectField` and `String` field name variants are available.

### Pagination

Implement efficient [pagination](https://developer.salesforce.com/docs/atlas.en-us.soql_sosl.meta/soql_sosl/sforce_api_calls_soql_select_offset.htm) for large result sets.

**Example:**

```apex
/**
 * @description Retrieves a paginated list of contacts
 *
 * @param pageNumber Page number (1-based)
 * @param pageSize Records per page
 *
 * @return QueryPage with results and pagination metadata
 *
 * @example
 * ```apex
 * QRY_Builder.QueryPage page1 = getPaginatedContacts(1, 25);
 * ```

*/
public static QRY_Builder.QueryPage getPaginatedContacts(Integer pageNumber, Integer pageSize)
{
return QRY_Builder.selectFrom(Contact.SObjectType)
.fields(new List<SObjectField>{ Contact.FirstName, Contact.LastName, Contact.Email, Contact.Phone })
.orderBy(Contact.LastName).ascending()
.getPage(pageNumber, pageSize);
}

```

---

## Query Builder

The [QRY_Builder](reference/apex/QRY_Builder.md) fluent API is the recommended approach for building queries. It provides:
- Built-in sharing enforcement control
- Pagination support
- Field-level security options
- Caching and result transformation
- Chainable, readable syntax

### SELECT and FROM

Build queries using the fluent interface.

**Example:**
```apex
// Simple SELECT query
List<Account> accounts = QRY_Builder.selectFrom(Account.SObjectType)
	.fields(new List<SObjectField>{ Account.Name, Account.Industry, Account.Phone })
	.toList();
```

### WHERE Conditions

Add filtering to queries.

**Example:**

```apex
// Query with WHERE clause
List<Account> accounts = QRY_Builder.selectFrom(Account.SObjectType)
	.fields(new List<SObjectField>{ Account.Name, Account.AnnualRevenue })
	.condition(Account.Industry).equals('Technology')
	.andCondition(Account.AnnualRevenue).greaterThan(1000000)
	.toList();
```

### Aggregate Functions

Use COUNT, SUM, AVG, MIN, MAX with [QRY_Builder](reference/apex/QRY_Builder.md).

**Example:**

```apex
// Count accounts by industry
List<QRY_Builder.AggregateRow> results = QRY_Builder.selectFrom(Account.SObjectType)
	.count('Id')
	.groupBy(Account.Industry)
	.toAggregateList();
```

### GROUP BY

Group aggregated results.

**Example:**

```apex
/**
 * @description Calculates total revenue by industry
 *
 * @return List of AggregateRow with total revenue per industry
 */
public static List<QRY_Builder.AggregateRow> getTotalRevenueByIndustry()
{
	return QRY_Builder.selectFrom(Account.SObjectType)
		.sum(Account.AnnualRevenue)
		.groupBy(Account.Industry)
		.orderBy('Industry').ascending()
		.toAggregateList();
}
```

---

## Sharing Enforcement

The Selector Framework provides fine-grained control
over [sharing rule enforcement](https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_classes_keywords_sharing.htm). [QRY_Builder](reference/apex/QRY_Builder.md)
offers independent, combinable security options. By default, queries run in **USER_MODE** (CRUD, FLS, and sharing enforced) — driven by the `UserModeQueries_Enabled` feature flag
which ships with `IsEnabledByDefault__c=true`.

| Method                 | Effect                                                                                                                     | When to Use                                                                      |
|------------------------|----------------------------------------------------------------------------------------------------------------------------|----------------------------------------------------------------------------------|
| `.withUserMode()`      | Explicitly runs in USER_MODE (the shipped default)                                                                         | Subscriber code that must enforce the running user's permissions                 |
| `.withSystemMode()`    | Runs in SYSTEM_MODE — bypasses CRUD/FLS/sharing                                                                            | Framework-internal reads of configuration or audit data; rare in subscriber code |
| `.stripInaccessible()` | Removes inaccessible fields from results post-query                                                                        | Complements USER_MODE when null values are problematic                           |
| `.withSharing()`       | Uses `with sharing` proxy class (SYSTEM_MODE only)                                                                         | Enforce sharing while bypassing CRUD/FLS                                         |
| `.bypassSharing()`     | Uses `without sharing` proxy class (SYSTEM_MODE only)                                                                      | Bypass sharing in SYSTEM_MODE (use with caution)                                 |
| `.withoutSecurity()`   | Clears USER_MODE, strip, and sharing selections (forces SYSTEM_MODE with inherited sharing regardless of the flag default) | System-level queries                                                             |

### Enforcing Sharing

```apex
/**
 * @description Queries contacts with sharing enforced via withSharing() proxy
 *
 * @param accountIds Account Ids to filter by
 *
 * @return List of contacts respecting user's sharing rules
 */
public static List<Contact> findContactsWithSharing(Set<Id> accountIds)
{
	return QRY_Builder.selectFrom(Contact.SObjectType)
		.fields(new List<SObjectField>{ Contact.FirstName, Contact.LastName, Contact.Email })
		.condition(Contact.AccountId).isIn(new List<Id>(accountIds))
		.withSharing()
		.toList();
}
```

### Bypassing Sharing

```apex
/**
 * @description Queries all contacts regardless of sharing rules
 * WARNING: Allows access to records the user normally cannot see.
 *
 * @param accountIds Account Ids to filter by
 *
 * @return All matching contacts regardless of current user's access
 */
public static List<Contact> findAllContactsWithoutSharing(Set<Id> accountIds)
{
	return QRY_Builder.selectFrom(Contact.SObjectType)
		.fields(new List<SObjectField>{ Contact.FirstName, Contact.LastName, Contact.Email })
		.condition(Contact.AccountId).isIn(new List<Id>(accountIds))
		.bypassSharing()
		.toList();
}
```

**Note:** `withUserMode()` enforces sharing at the database level; `withSharing()`/`bypassSharing()` are ignored when combined with it.

### USER_MODE Security

Use `.withUserMode()` for full [CRUD, FLS, and sharing enforcement](https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_classes_enforce_usermode.htm) at
the database level:

```apex
/**
 * @description Queries accounts with full security enforcement via USER_MODE
 *
 * @return List of accounts (throws exception if user lacks object READ access)
 */
public static List<Account> findAccountsWithSecurity()
{
	return QRY_Builder.selectFrom(Account.SObjectType)
		.fields(new List<SObjectField>{ Account.Name, Account.Industry, Account.AnnualRevenue })
		.withUserMode()
		.toList();
}
```

### Strip Inaccessible Fields

```apex
// Removes inaccessible fields from results post-query
List<Account> accounts = QRY_Builder.selectFrom(Account.SObjectType)
	.fields(new List<SObjectField>{ Account.Name, Account.Industry, Account.AnnualRevenue })
	.stripInaccessible()
	.toList();
```

---

## Complex Examples

### Parent-to-Child Subqueries

Query parent records with related child records using [QRY_Builder.subselect()](reference/apex/QRY_Builder.md).

**Example:**

```apex
/**
 * @description Queries accounts with their contacts
 *
 * @param accountIds Set of account Ids
 *
 * @return List of accounts with nested contact data
 */
public static List<Account> getAccountsWithContacts(Set<Id> accountIds)
{
	QRY_Builder.Builder contactSubquery = QRY_Builder.selectFrom(Contact.SObjectType)
		.fields(new List<SObjectField>{ Contact.FirstName, Contact.LastName, Contact.Email });

	return QRY_Builder.selectFrom(Account.SObjectType)
		.fields(new List<SObjectField>{ Account.Name, Account.Industry })
		.subselect(contactSubquery, 'Contacts')
		.condition(Account.Id).isIn(new List<Id>(accountIds))
		.toList();
}
```

### Semi-Join Subqueries

Use `isIn(Builder)` and `notIn(Builder)` for [semi-join](https://developer.salesforce.com/docs/atlas.en-us.soql_sosl.meta/soql_sosl/sforce_api_calls_soql_select_semi_join.htm)
patterns where one query filters based on another query's results.

**Semi-Join (IN subquery):**

```apex
/**
 * @description Finds users assigned to specific permission sets
 *
 * @param permissionSetNames Set of permission set names
 *
 * @return List of matching users
 */
public static List<User> findUsersWithPermissionSets(Set<String> permissionSetNames)
{
	QRY_Builder.Builder subquery = QRY_Builder.selectFrom(PermissionSetAssignment.SObjectType)
		.fields(new List<SObjectField>{ PermissionSetAssignment.AssigneeId })
		.condition('PermissionSet.Name').isIn(new List<String>(permissionSetNames));

	return QRY_Builder.selectFrom(User.SObjectType)
		.fields(new List<SObjectField>{ User.Name, User.Email })
		.condition(User.IsActive).equals(true)
		.condition('Id').isIn(subquery)
		.toList();
}
```

**Anti-Join Pattern (NOT IN):**

```apex
/**
 * @description Finds accounts without any contacts
 *
 * @return List of accounts without contacts
 */
public static List<Account> findAccountsWithoutContacts()
{
	QRY_Builder.Builder contactSubquery = QRY_Builder.selectFrom(Contact.SObjectType)
		.fields(new List<SObjectField>{ Contact.AccountId })
		.condition(Contact.AccountId).isNotNull();

	return QRY_Builder.selectFrom(Account.SObjectType)
		.fields(new List<SObjectField>{ Account.Name, Account.Industry })
		.condition('Id').notIn(contactSubquery)
		.toList();
}
```

> **Nested Semi-Joins:** Subqueries can themselves contain `isIn()` conditions, supporting multiple levels of nesting (up to 5 levels per SOQL limits).

### Aggregate Queries

Perform aggregations with [GROUP BY](https://developer.salesforce.com/docs/atlas.en-us.soql_sosl.meta/soql_sosl/sforce_api_calls_soql_select_groupby.htm).

**Example:**

```apex
/**
 * @description Gets total revenue by industry with filtering
 *
 * @param minRevenue Minimum total revenue threshold
 *
 * @return List of AggregateRow with industry and total revenue
 */
public static List<QRY_Builder.AggregateRow> getTotalRevenueByIndustry(Decimal minRevenue)
{
	return QRY_Builder.selectFrom(Account.SObjectType)
		.sum(Account.AnnualRevenue)
		.groupBy(Account.Industry)
		.havingSumOf(Account.AnnualRevenue).greaterThan(minRevenue)
		.orderBy('Industry').ascending()
		.toAggregateList();
}
```

### QueryLocator for Batch Apex

Get a [QueryLocator](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Database_QueryLocator.htm) for batch processing.

**Example:**

```apex
/**
 * @description Batch class to process accounts
 */
public with sharing class BATCH_ProcessAccounts implements Database.Batchable<SObject>
{
	/**
	 * @description Returns QueryLocator for batch processing
	 *
	 * @param context Batch context
	 *
	 * @return Database.QueryLocator for accounts to process
	 */
	public Database.QueryLocator start(Database.BatchableContext context)
	{
		return QRY_Builder.selectFrom(Account.SObjectType)
			.fields(new List<SObjectField>{Account.Name, Account.Industry, Account.AnnualRevenue, Account.OwnerId})
			.condition(Account.Type).equals('Customer')
			.andCondition(Account.AnnualRevenue).greaterThan(1000000)
			.toQueryLocator();
	}

	/**
	 * @description Processes each batch of accounts
	 *
	 * @param context Batch context
	 * @param accounts List of accounts in this batch
	 */
	public void execute(Database.BatchableContext context, List<Account> accounts)
	{
		for(Account account : accounts)
		{
			// Business logic here
		}
	}

	/**
	 * @description Completes batch processing
	 *
	 * @param context Batch context
	 */
	public void finish(Database.BatchableContext context)
	{
		LOG_Builder.build().info('Batch complete').emitAt('MyBatch.finish');
	}
}
```

---

## Custom Selector Classes

Create custom selector classes for each SObject by extending [SEL_Base](reference/apex/SEL_Base.md) to centralize and standardize queries.

**Pattern:**

```apex
/**
 * @description Selector for Contact queries.
 *
 * @see SEL_Contacts_TEST
 *
 * @author your.name@company.com
 *
 * @group Selectors
 *
 * @date January 2026
 */
public inherited sharing class SEL_Contacts extends SEL_Base
{
	public SEL_Contacts()
	{
		super(Contact.SObjectType);
	}

	/**
	 * @description Returns consistent minimal set of fields for Contact queries.
	 *
	 * @return List of Contact SObjectField tokens
	 */
	public override List<SObjectField> getFields()
	{
		return new List<SObjectField>
		{
			Contact.FirstName,
			Contact.LastName,
			Contact.Email,
			Contact.Phone,
			Contact.AccountId
		};
	}

	/**
	 * @description Finds active contacts for specific accounts.
	 *
	 * @param accountIds Set of account Ids to filter by
	 *
	 * @return List of active contacts
	 *
	 * @example
	 * ```apex
	 * List<Contact> contacts = new SEL_Contacts().findActiveByAccountIds(accountIds);
	 * ```
	 */
	public List<Contact> findActiveByAccountIds(Set<Id> accountIds)
	{
		return (List<Contact>)query
			.condition(Contact.AccountId).isIn(new List<Id>(accountIds))
			.andCondition(Contact.Active__c).equals(true)
			.orderBy(Contact.LastName).ascending()
			.toList();
	}
}
```

**Test Class Pattern:**

```apex
/**
 * @description Unit tests for SEL_Contacts.
 *
 * @see SEL_Contacts
 *
 * @author your.name@company.com
 *
 * @group Selectors
 *
 * @date January 2026
 */
@IsTest(SeeAllData=false IsParallel=true)
private class SEL_Contacts_TEST
{
	/**
	 * @description Tests finding active contacts by account Ids.
	 */
	@IsTest
	private static void shouldReturnActiveContactsForAccounts()
	{
		Account testAccount = (Account)TST_Builder.of(Account.SObjectType).build();

		Contact activeContact = (Contact)TST_Builder.of(Contact.SObjectType)
			.withOverrides(new Map<SObjectField, Object>
			{
				Contact.AccountId => testAccount.Id,
				Contact.Active__c => true,
				Contact.LastName => 'Smith'
			})
			.build();

		Contact inactiveContact = (Contact)TST_Builder.of(Contact.SObjectType)
			.withOverrides(new Map<SObjectField, Object>
			{
				Contact.AccountId => testAccount.Id,
				Contact.Active__c => false,
				Contact.LastName => 'Jones'
			})
			.build();

		Test.startTest();
		List<Contact> foundContacts = new SEL_Contacts().findActiveByAccountIds(
			new Set<Id>{testAccount.Id}
		);
		Test.stopTest();

		Assert.areEqual(1, foundContacts.size(), 'Should find only active contact');
		Assert.areEqual('Smith', foundContacts[0].LastName, 'Should find the active contact');
	}
}
```

---

## QRY_Builder Examples

This section provides practical examples demonstrating common query patterns using `QRY_Builder`. These examples show real-world scenarios you'll encounter when building Salesforce
applications.

### Basic Queries

#### Simple Field Selection

```apex
/**
 * @description Retrieves accounts with basic field selection
 *
 * @return List of Account records
 */
public static List<Account> getBasicAccounts()
{
	return QRY_Builder.selectFrom(Account.SObjectType)
		.fields(new List<SObjectField>{ Account.Name, Account.Industry, Account.Phone, Account.Website })
		.orderBy(Account.Name).ascending()
		.toList();
}
```

#### Query with Single Condition

```apex
/**
 * @description Finds accounts by industry
 *
 * @param industry The industry to filter by
 *
 * @return List of matching accounts
 */
public static List<Account> findByIndustry(String industry)
{
	return QRY_Builder.selectFrom(Account.SObjectType)
		.addFields(new List<SObjectField>{Account.Name, Account.Industry, Account.AnnualRevenue})
		.condition(Account.Industry).equals(industry)
		.orderBy(Account.Name).ascending()
		.toList();
}
```

#### Query with Multiple AND Conditions

```apex
/**
 * @description Finds high-value technology accounts
 *
 * @param minimumRevenue Minimum annual revenue threshold
 *
 * @return List of matching accounts
 */
public static List<Account> findHighValueTechAccounts(Decimal minimumRevenue)
{
	return QRY_Builder.selectFrom(Account.SObjectType)
		.fields(new List<SObjectField>{ Account.Name, Account.Industry, Account.AnnualRevenue, Account.Type })
		.condition(Account.Industry).equals('Technology')
		.andCondition(Account.AnnualRevenue).greaterThanOrEquals(minimumRevenue)
		.andCondition(Account.Type).equals('Customer')
		.orderBy(Account.AnnualRevenue).descending()
		.withLimit(100)
		.toList();
}
```

#### Query with OR Conditions

```apex
/**
 * @description Finds accounts in multiple industries
 *
 * @return List of accounts in technology or finance industries
 */
public static List<Account> findTechOrFinanceAccounts()
{
	return QRY_Builder.selectFrom(Account.SObjectType)
		.fields(new List<SObjectField>{ Account.Name, Account.Industry, Account.AnnualRevenue })
		.condition(Account.Industry).equals('Technology')
		.orCondition(Account.Industry).equals('Finance')
		.orderBy(Account.Name).ascending()
		.toList();
}
```

#### Explicit Condition Grouping

When you need precise control over AND/OR grouping, use `addCondition()` with `QRY_Condition.OrCondition` or `QRY_Condition.AndCondition`:

```apex
/**
 * @description Finds tech accounts that are either active or pending.
 * Demonstrates explicit grouping: Industry = 'Technology' AND (Status = 'Active' OR Status = 'Pending')
 *
 * @return List of matching accounts
 */
public static List<Account> findActiveTechAccounts()
{
	// Build the OR group for status
	QRY_Condition.OrCondition statusGroup = new QRY_Condition.OrCondition();
	statusGroup.add(new QRY_Condition.FieldCondition('Status__c').equals('Active'));
	statusGroup.add(new QRY_Condition.FieldCondition('Status__c').equals('Pending'));

	return QRY_Builder.selectFrom(Account.SObjectType)
		.fields(new List<String>{'Name', 'Industry', 'Status__c'})
		.condition(Account.Industry).equals('Technology')
		.addCondition(statusGroup)
		.toList();
}
```

> **Note:** Without explicit grouping, conditions follow standard SQL precedence where AND binds tighter than OR. For example, `A AND B OR C` evaluates as `(A AND B) OR C`.

### Advanced Filtering

#### Using IN Operator with Collection

```apex
/**
 * @description Finds accounts by multiple types
 *
 * @param accountTypes Set of account types to include
 *
 * @return List of matching accounts
 */
public static List<Account> findByTypes(Set<String> accountTypes)
{
	return QRY_Builder.selectFrom(Account.SObjectType)
		.fields(new List<SObjectField>{ Account.Name, Account.Type, Account.Industry })
		.condition(Account.Type).isIn(new List<String>(accountTypes))
		.orderBy(Account.Name).ascending()
		.toList();
}
```

#### Using IN Operator with SObjects

Pass `List<SObject>` directly to `isIn()` without manual Id extraction. Salesforce automatically extracts Ids from the SObject list:

```apex
/**
 * @description Finds contacts belonging to the given accounts
 *
 * @param accounts List of accounts to find contacts for
 *
 * @return List of contacts for the accounts
 */
public static List<Contact> findByAccounts(List<Account> accounts)
{
	return QRY_Builder.selectFrom(Contact.SObjectType)
		.fields(new List<SObjectField>{ Contact.FirstName, Contact.LastName, Contact.Email })
		.condition(Contact.AccountId).isIn(accounts)
		.orderBy(Contact.LastName).ascending()
		.toList();
}
```

**Extract any field value from SObjects** using the field extraction overload:

```apex
/**
 * @description Finds accounts by contact email domains
 *
 * @param contacts List of contacts to extract AccountIds from
 *
 * @return List of accounts
 */
public static List<Account> findAccountsForContacts(List<Contact> contacts)
{
	return QRY_Builder.selectFrom(Account.SObjectType)
		.fields(new List<SObjectField>{ Account.Name, Account.Industry })
		.condition(Account.Id).isIn(contacts, Contact.AccountId)
		.toList();
}
```

**Empty list handling:**

| Method                          | Empty/Null Behavior               |
|---------------------------------|-----------------------------------|
| `isIn(List<SObject>)`           | Returns no results (safe)         |
| `isInStrict(List<SObject>)`     | Throws `IllegalArgumentException` |
| `notInSet(List<SObject>)`       | Excludes nothing (safe)           |
| `notInSetStrict(List<SObject>)` | Throws `IllegalArgumentException` |

**Important: Id/String Type Coercion**

When using `List<Object>` with `isIn()` or `notInSet()`, be aware that Apex automatically coerces strings that look like valid Salesforce IDs (15 or 18 characters) into Id values.
This is an Apex platform behaviour, not a framework limitation.

```apex
// PROBLEMATIC: ID-like strings in List<Object> are treated as Ids
List<Object> mixedValues = new List<Object>{'001000000000001AAA', 'text-value'};
.condition(TextField__c).isIn(mixedValues)  // May not work for text field queries

// RECOMMENDED: Use strongly-typed collections
List<String> textValues = new List<String>{'001000000000001AAA', 'text-value'};
.condition(TextField__c).isIn(textValues)  // Works correctly for text fields

List<Id> idValues = new List<Id>{accountId1, accountId2};
.condition(Account.Id).isIn(idValues)  // Works correctly for Id fields
```

**Best practices:**

- Use `List<Id>` or `List<SObject>` when querying Id/lookup fields
- Use `List<String>` when querying text fields, even if values look like IDs
- Avoid `List<Object>` when your collection may contain mixed Id and String values

**Single SObject comparison:**

```apex
// Match by single SObject's Id
.condition(Contact.AccountId).equals(parentAccount)

// Exclude by single SObject's Id
.condition(Contact.AccountId).notEquals(excludedAccount)
```

#### String Pattern Matching

```apex
/**
 * @description Finds accounts whose names contain specific text
 *
 * @param searchText Text to search for in account names
 *
 * @return List of matching accounts
 */
public static List<Account> searchAccountsByName(String searchText)
{
	return QRY_Builder.selectFrom(Account.SObjectType)
		.fields(new List<SObjectField>{ Account.Name, Account.Industry, Account.Phone })
		.condition(Account.Name).contains(searchText)
		.orderBy(Account.Name).ascending()
		.withLimit(50)
		.toList();
}
```

#### Multi-Picklist Field Filtering

```apex
/**
 * @description Finds contacts with specific interests (multi-picklist)
 *
 * @param requiredInterests Set of interests that must be present
 *
 * @return List of matching contacts
 */
public static List<Contact> findByInterests(Set<String> requiredInterests)
{
	return QRY_Builder.selectFrom(Contact.SObjectType)
		.fields(new List<SObjectField>{ Contact.FirstName, Contact.LastName, Contact.Email, Contact.Interests__c })
		.condition(Contact.Interests__c).includes(new List<String>(requiredInterests))
		.orderBy(Contact.LastName).ascending()
		.toList();
}
```

#### Date Literal Conditions

Use `QRY_Condition.DateLiteral` for relative date conditions (TODAY, LAST_N_DAYS, etc.) instead of hardcoding dates:

```apex
/**
 * @description Finds accounts created in the last N days.
 *
 * @param days Number of days to look back
 *
 * @return List of recently created accounts
 */
public static List<Account> findRecentlyCreated(Integer days)
{
	return QRY_Builder.selectFrom(Account.SObjectType)
		.fields(new List<SObjectField>{Account.Name, Account.CreatedDate})
		.condition(Account.CreatedDate).equals(new QRY_Condition.DateLiteral().lastNDays(days))
		.orderBy(Account.CreatedDate).descending()
		.toList();
}

/**
 * @description Finds opportunities closing this quarter.
 *
 * @return List of opportunities closing in the current quarter
 */
public static List<Opportunity> findClosingThisQuarter()
{
	return QRY_Builder.selectFrom(Opportunity.SObjectType)
		.fields(new List<SObjectField>{Opportunity.Name, Opportunity.CloseDate, Opportunity.Amount})
		.condition(Opportunity.CloseDate).equals(new QRY_Condition.DateLiteral().thisUnit(QRY_Condition.UnitOfTime.QUARTER))
		.condition(Opportunity.IsClosed).equals(false)
		.toList();
}
```

**Available methods:** `.today()`, `.yesterday()`, `.tomorrow()`, `.lastNDays(n)`, `.nextNDays(n)`, `.last90Days()`, `.next90Days()`,
`.thisUnit(UnitOfTime)`, `.last(UnitOfTime)`, `.next(UnitOfTime)`, `.last(n, UnitOfTime)`, `.next(n, UnitOfTime)`.

**UnitOfTime values:** `DAY`, `WEEK`, `MONTH`, `QUARTER`, `YEAR`, `FISCAL_QUARTER`, `FISCAL_YEAR`.

### Parent Relationship Queries

#### Querying Related Fields

```apex
/**
 * @description Retrieves contacts with account information
 *
 * @param accountId Account Id to filter by
 *
 * @return List of contacts with parent account data
 */
public static List<Contact> findContactsWithAccountInfo(Id accountId)
{
	return QRY_Builder.selectFrom(Contact.SObjectType)
		.fields(new List<SObjectField>{ Contact.FirstName, Contact.LastName, Contact.Email })
		.relatedFields(new List<String>{'Account.Name', 'Account.Industry', 'Account.Type'})
		.condition(Contact.AccountId).equals(accountId)
		.orderBy(Contact.LastName).ascending()
		.toList();
}
```

### Caching Queries

#### Platform Cache Integration

```apex
/**
 * @description Retrieves frequently accessed account with caching
 *
 * @param accountId Account Id to retrieve
 *
 * @return Cached account record
 */
public static Account getCachedAccount(Id accountId)
{
	return (Account)QRY_Builder.selectFrom(Account.SObjectType)
		.fields(new List<SObjectField>{Account.Name, Account.Industry, Account.Phone, Account.Website})
		.condition(Account.Id).equals(accountId)
		.withCache(300) // Cache for 5 minutes (300 seconds)
		.getFirst();
}

/**
 * @description Checks if last query result came from cache
 *
 * @example
 * QRY_Builder.Builder query = QRY_Builder.selectFrom(Account.SObjectType).withCache(600);
 * List<Account> accounts = query.toList();
 * if(query.isCached())
 * {
 * 	LOG_Builder.build().debug('Results retrieved from cache').emitAt('MyClass.myMethod');
 * }
 */
```

### Query Performance Logging

QRY_Builder integrates with the logging framework to automatically log slow queries. This enables monitoring and optimization of database operations without modifying query code.

> **See Also:** [Logging - Guide](Logging%20-%20Guide.md) for comprehensive logging documentation including correlation tracking, context management, and troubleshooting.

**Configuration via [`LogSetting__c`](reference/objects/LogSetting__c.md):**

- `EnableQueryPerformanceLogging__c` - Master switch (default: true)
- `QueryPerformanceThresholdMs__c` - Threshold in ms (default: 1000 = 1 second)

#### Force Logging a Query

```apex
/**
 * @description Always logs this query's performance, regardless of threshold settings.
 * Use for critical queries you always want to monitor.
 */
public static List<Account> getCriticalAccounts()
{
	return QRY_Builder.selectFrom(Account.SObjectType)
		.fields(new List<SObjectField>{ Account.Name, Account.Industry })
		.condition(Account.Type).equals('Critical')
		.forcePerformanceLogging()  // Always log this query
		.toList();
}
```

#### Custom Threshold per Query

```apex
/**
 * @description Logs if query exceeds custom threshold, overriding global setting.
 * Use when you need stricter monitoring for specific queries.
 */
public static List<Contact> getFastContacts(Id accountId)
{
	return QRY_Builder.selectFrom(Contact.SObjectType)
		.fields(new List<SObjectField>{ Contact.Name, Contact.Email })
		.condition(Contact.AccountId).equals(accountId)
		.logPerformanceIfSlowerThan(100)  // Log if > 100ms (stricter than global 1s default)
		.toList();
}
```

#### Suppress Logging

```apex
/**
 * @description Prevents performance logging for high-frequency internal queries.
 * Use for queries that execute frequently and would generate excessive logs.
 */
public static LogSetting__c getLogSetting()
{
	LogSetting__c setting = LogSetting__c.getInstance();
	// LogSetting__c is a hierarchy custom setting — defaults are code-level in LOG_Engine.getLogSetting()
	return setting != null ? setting : LOG_Engine.getLogSetting();
}
```

#### Logging Hierarchy

The logging hierarchy (most to least specific):

1. `.suppressPerformanceLogging()` - Never log this query
2. `.forcePerformanceLogging()` - Always log this query
3. `.logPerformanceIfSlowerThan(ms)` - Log if exceeds custom threshold
4. `QueryPerformanceThresholdMs__c` - Global threshold from LogSetting__c
5. `EnableQueryPerformanceLogging__c` - Master switch

### Aggregate Queries

#### Simple Aggregation

```apex
/**
 * @description Calculates total revenue by industry
 *
 * @return List of AggregateRow with industry and total revenue
 */
public static List<QRY_Builder.AggregateRow> getTotalRevenueByIndustry()
{
	return QRY_Builder.selectFrom(Account.SObjectType)
		.sum(Account.AnnualRevenue)
		.groupBy(Account.Industry)
		.orderBy('Industry').ascending()
		.toAggregateList();
}
```

#### Aggregation with HAVING Clause

```apex
/**
 * @description Finds industries with high total revenue
 *
 * @param minimumTotalRevenue Minimum total revenue threshold
 *
 * @return List of AggregateRow for high-revenue industries
 */
public static List<QRY_Builder.AggregateRow> getHighRevenueIndustries(Decimal minimumTotalRevenue)
{
	return QRY_Builder.selectFrom(Account.SObjectType)
		.sum(Account.AnnualRevenue)
		.groupBy(Account.Industry)
		.havingSumOf(Account.AnnualRevenue).greaterThan(minimumTotalRevenue)
		.orderBy('Industry').ascending()
		.toAggregateList();
}
```

#### Multiple Grouping Fields

```apex
/**
 * @description Counts accounts by industry and type
 *
 * @return List of AggregateRow grouped by industry and type
 */
public static List<QRY_Builder.AggregateRow> countAccountsByIndustryAndType()
{
	return QRY_Builder.selectFrom(Account.SObjectType)
		.count('Id')
		.groupBy(Account.Industry)
		.groupBy(Account.Type)
		.havingCount().greaterThan(5)
		.toAggregateList();
}
```

### Multi-Field Grouping

Call `.groupBy()` multiple times for multi-dimensional aggregation (max 3 fields per SOQL spec):

```apex
List<QRY_Builder.AggregateRow> results = QRY_Builder.selectFrom(Opportunity.SObjectType)
	.groupBy(Opportunity.StageName)
	.groupBy('CALENDAR_YEAR(CloseDate)')
	.sum(Opportunity.Amount)
	.toAggregateList();
```

#### GROUP BY ROLLUP (Subtotals)

Add `.rollup()` to generate subtotals at each grouping level. Use `.grouping(field)` to distinguish subtotal rows
(returns 1) from data rows (returns 0):

```apex
List<QRY_Builder.AggregateRow> results = QRY_Builder.selectFrom(Opportunity.SObjectType)
	.groupBy(Opportunity.StageName)
	.groupBy(Opportunity.LeadSource)
	.grouping(Opportunity.StageName)
	.grouping(Opportunity.LeadSource)
	.sum(Opportunity.Amount)
	.rollup()
	.toAggregateList();
```

#### GROUP BY CUBE (Cross-Tabulation)

Add `.cube()` for all possible dimension combinations:

```apex
List<QRY_Builder.AggregateRow> results = QRY_Builder.selectFrom(Opportunity.SObjectType)
	.groupBy(Opportunity.StageName)
	.groupBy(Opportunity.LeadSource)
	.sum(Opportunity.Amount)
	.cube()
	.toAggregateList();
```

### SOQL Functions in Queries

Date functions, `toLabel()`, and `FORMAT()` work through the existing string overloads — no special API needed:

#### Date Functions in GROUP BY

Bucket records by a part of a date with `QRY_Function` — a typed, discoverable factory per SOQL date
function, so you never hand-spell the expression. Use the same factory in `addField` (with an alias for
read-back), `groupBy`, and `orderBy` so the SELECT and GROUP BY expressions always match:

```apex
List<QRY_Builder.AggregateRow> results = QRY_Builder.selectFrom(Opportunity.SObjectType)
	.addField(QRY_Function.calendarMonth(Opportunity.CloseDate), 'monthNumber')
	.count('Id')
	.groupBy(QRY_Function.calendarMonth(Opportunity.CloseDate))
	.orderBy(QRY_Function.calendarMonth(Opportunity.CloseDate))
	.toAggregateList();

for(QRY_Builder.AggregateRow row : results)
{
	Integer month = row.getInteger('monthNumber');
	Integer total = row.getInteger('count_Id');
}
```

All 13 SOQL date functions have a factory: `calendarMonth`, `calendarQuarter`, `calendarYear`, `dayInMonth`,
`dayInWeek`, `dayInYear`, `dayOnly`, `fiscalMonth`, `fiscalQuarter`, `fiscalYear`, `hourInDay`, `weekInMonth`,
`weekInYear`. Each yields an `Integer` date part except `dayOnly`, which yields a `Date` — read it back with
`row.getDate(alias)`.

When the field name is only known at runtime, the raw-string form still works
(`.addField('CALENDAR_MONTH(' + fieldName + ')')`); the typed factories are the safe, autocompleting path for
the common case.

#### toLabel (Picklist Translation)

```apex
List<SObject> records = QRY_Builder.selectFrom(Opportunity.SObjectType)
	.addField('toLabel(StageName)')
	.toList();
```

#### FORMAT (Localized Formatting)

```apex
List<SObject> records = QRY_Builder.selectFrom(Account.SObjectType)
	.addField('FORMAT(AnnualRevenue) formattedRevenue')
	.toList();
```

### Result Transformation

#### Converting to Map

```apex
/**
 * @description Retrieves accounts as a Map for quick lookup
 *
 * @param accountIds Set of account Ids
 *
 * @return Map of accounts indexed by Id
 */
public static Map<Id, Account> getAccountMap(Set<Id> accountIds)
{
	return (Map<Id, Account>)QRY_Builder.selectFrom(Account.SObjectType)
		.fields(new List<SObjectField>{ Account.Name, Account.Industry, Account.Type })
		.condition(Account.Id).isIn(new List<Id>(accountIds))
		.asMap();
}
```

#### Extracting Id Sets

```apex
/**
 * @description Gets Ids of technology accounts
 *
 * @return Set of account Ids
 */
public static Set<Id> getTechnologyAccountIds()
{
	return QRY_Builder.selectFrom(Account.SObjectType)
		.condition(Account.Industry).equals('Technology')
		.asIdSet();
}
```

#### Extracting Field Values

```apex
/**
 * @description Gets all unique industries from accounts
 *
 * @return Set of industry values
 */
public static Set<String> getAllIndustries()
{
	Set<Object> industries = QRY_Builder.selectFrom(Account.SObjectType)
		.addField(Account.Industry)
		.asValueSet(Account.Industry);

	// Convert Set<Object> to Set<String>
	Set<String> industryStrings = new Set<String>();
	for(Object industry : industries)
	{
		if(industry != null)
		{
			industryStrings.add((String)industry);
		}
	}
	return industryStrings;
}
```

### Existence Checks

#### Checking if Records Exist

```apex
/**
 * @description Checks if any open cases exist for an account
 *
 * @param accountId Account Id to check
 *
 * @return true if open cases exist
 */
public static Boolean hasOpenCases(Id accountId)
{
	return QRY_Builder.selectFrom(Case.SObjectType)
		.condition(Case.AccountId).equals(accountId)
		.andCondition(Case.IsClosed).equals(false)
		.exists(); // More efficient than count() > 0
}
```

### Security & Row Locking

QRY_Builder provides independent, combinable security options. By default, queries run in **USER_MODE** (CRUD, FLS, and sharing enforced) — driven by the `UserModeQueries_Enabled`
feature flag which ships with `IsEnabledByDefault__c=true`.

#### Security Methods Overview

| Method                | Effect                                                                                                                     | When to Use                                                                      |
|-----------------------|----------------------------------------------------------------------------------------------------------------------------|----------------------------------------------------------------------------------|
| `withUserMode()`      | Explicitly runs in USER_MODE (the shipped default)                                                                         | Subscriber code that must enforce the running user's permissions                 |
| `withSystemMode()`    | Runs in SYSTEM_MODE — bypasses CRUD/FLS/sharing                                                                            | Framework-internal reads of configuration or audit data; rare in subscriber code |
| `stripInaccessible()` | Removes inaccessible fields from results post-query                                                                        | Complements USER_MODE when null values are problematic                           |
| `withSharing()`       | Uses `with sharing` proxy class (SYSTEM_MODE only)                                                                         | Enforce sharing while bypassing CRUD/FLS                                         |
| `bypassSharing()`     | Uses `without sharing` proxy class (SYSTEM_MODE only)                                                                      | Bypass sharing in SYSTEM_MODE (use with caution)                                 |
| `withoutSecurity()`   | Clears USER_MODE, strip, and sharing selections (forces SYSTEM_MODE with inherited sharing regardless of the flag default) | System-level queries                                                             |

**Important:** When using `withUserMode()` (or accepting the USER_MODE default), sharing is enforced at the database level regardless of `withSharing()`/`bypassSharing()` settings.
The sharing proxy methods only have effect in SYSTEM_MODE.

**Per-selector opt-out:** framework-internal selectors that must always run in SYSTEM_MODE (e.g. those reading `*__mdt` configuration or `LogEntry__c` audit data) override
`systemModeRequired()` on `SEL_Base` to return `true`. That single override pins every query routed through the selector's `query` property to SYSTEM_MODE regardless of the
flag-driven default.

**Org-wide kill switch:** deploy an override of `kern__FeatureFlag.UserModeQueries_Enabled` with `IsEnabledByDefault__c=false` to temporarily fall back to SYSTEM_MODE
framework-wide — emergency rollback only, while offending code is fixed.

#### USER_MODE Security (CRUD, FLS, and Sharing)

```apex
/**
 * @description Retrieves accounts with full security enforcement via USER_MODE.
 * Throws exception if user lacks object READ access.
 *
 * @return List of accounts (inaccessible fields return null)
 */
public static List<Account> getAccountsWithUserMode()
{
	return QRY_Builder.selectFrom(Account.SObjectType)
		.fields(new List<SObjectField>{ Account.Name, Account.Industry, Account.AnnualRevenue, Account.Description })
		.withUserMode() // Enforces CRUD, FLS, and sharing at database level
		.toList();
}
```

#### Strip Inaccessible Fields

```apex
/**
 * @description Retrieves accounts with inaccessible fields removed from results.
 *
 * @return List of accounts with only accessible fields populated
 */
public static List<Account> getAccountsWithStrippedFields()
{
	return QRY_Builder.selectFrom(Account.SObjectType)
		.fields(new List<SObjectField>{ Account.Name, Account.Industry, Account.AnnualRevenue, Account.Description })
		.stripInaccessible() // Removes inaccessible fields post-query
		.toList();
}
```

#### Combining Security Options

```apex
/**
 * @description Retrieves accounts with USER_MODE and stripped fields.
 * Maximum security: enforces CRUD/FLS/sharing AND removes inaccessible fields.
 *
 * @return List of accounts with full security enforcement
 */
public static List<Account> getAccountsWithFullSecurity()
{
	return QRY_Builder.selectFrom(Account.SObjectType)
		.fields(new List<SObjectField>{ Account.Name, Account.Industry, Account.AnnualRevenue, Account.Description })
		.withUserMode()
		.stripInaccessible() // Can be combined with withUserMode()
		.toList();
}
```

#### Sharing Control (SYSTEM_MODE only)

```apex
/**
 * @description Retrieves accounts with enforced sharing rules.
 * Uses a with sharing proxy class (only effective in SYSTEM_MODE).
 *
 * @return List of accounts respecting sharing rules
 */
public static List<Account> getAccountsWithSharing()
{
	return QRY_Builder.selectFrom(Account.SObjectType)
		.fields(new List<SObjectField>{ Account.Name, Account.Industry })
		.withSharing() // Enforces sharing via proxy class
		.toList();
}

/**
 * @description Retrieves accounts bypassing sharing rules.
 * WARNING: Allows access to records the user normally cannot see.
 *
 * @return List of all accounts regardless of sharing rules
 */
public static List<Account> getAccountsBypassingSharing()
{
	return QRY_Builder.selectFrom(Account.SObjectType)
		.fields(new List<SObjectField>{ Account.Name, Account.Industry })
		.bypassSharing() // Bypasses sharing via proxy class
		.toList();
}
```

#### Conditional Field Addition Based on Access

```apex
/**
 * @description Adds fields only if user has read access
 *
 * @return List of accounts with accessible fields only
 */
public static List<Account> getAccountsWithConditionalFields()
{
	return QRY_Builder.selectFrom(Account.SObjectType)
		.fields(new List<SObjectField>{Account.Name, Account.Industry}, AccessType.READABLE)
		.addField(Account.AnnualRevenue, AccessType.READABLE) // Only added if readable
		.toList();
}
```

#### Row Locking for Updates

```apex
/**
 * @description Retrieves accounts with row locks for update
 *
 * @param accountIds Set of account Ids to lock
 *
 * @return List of locked account records
 */
public static List<Account> lockAccountsForUpdate(Set<Id> accountIds)
{
	return QRY_Builder.selectFrom(Account.SObjectType)
		.fields(new List<String>{'Name', 'Industry', 'Status__c'})
		.condition(Account.Id).isIn(new List<Id>(accountIds))
		.forUpdate() // Locks records for update
		.toList();
}
```

### Scoped Queries

#### Using USING SCOPE

```apex
/**
 * @description Retrieves only accounts owned by current user
 *
 * @return List of user's accounts
 */
public static List<Account> getMyAccounts()
{
	return QRY_Builder.selectFrom(Account.SObjectType)
		.fields(new List<String>{'Name', 'Industry', 'Owner.Name'})
		.usingScope(QRY_Builder.Scope.MINE) // Only my records
		.orderBy(Account.Name).ascending()
		.toList();
}

/**
 * @description Retrieves accounts visible to the entire team
 *
 * @return List of team accounts
 */
public static List<Account> getTeamAccounts()
{
	return QRY_Builder.selectFrom(Account.SObjectType)
		.fields(new List<String>{'Name', 'Industry', 'Owner.Name'})
		.usingScope(QRY_Builder.Scope.TEAM) // Team's records
		.orderBy(Account.CreatedDate).descending()
		.toList();
}
```

### Data Category Queries

The `WITH DATA CATEGORY` clause filters Knowledge articles (and other data-category-enabled objects) by their assigned
data category groups. Use `.withDataCategory(groupName)` to start a filter, then chain an operator to complete it.

#### Operators

| Operator         | Method            | Description                           |
|------------------|-------------------|---------------------------------------|
| `AT`             | `.at()`           | Exact category match                  |
| `ABOVE`          | `.above()`        | Ancestors of the specified category   |
| `BELOW`          | `.below()`        | Descendants of the specified category |
| `ABOVE_OR_BELOW` | `.aboveOrBelow()` | Both ancestors and descendants        |

Each operator has two overloads: `(String categoryName)` for a single category, and `(List<String> categoryNames)` for
multiple categories in one group (rendered as a parenthesized list in SOQL).

#### Single Category Filter

```apex
List<SObject> articles = QRY_Builder.selectFrom(KnowledgeArticleVersion.SObjectType)
	.fields(new List<SObjectField>{ KnowledgeArticleVersion.Id, KnowledgeArticleVersion.Title })
	.condition('PublishStatus').equals('Online')
	.condition('Language').equals('en_US')
	.withDataCategory('Geography__c').at('USA__c')
	.toList();
```

#### Multiple Categories in One Group

```apex
List<SObject> articles = QRY_Builder.selectFrom(KnowledgeArticleVersion.SObjectType)
	.fields(new List<SObjectField>{ KnowledgeArticleVersion.Id, KnowledgeArticleVersion.Title })
	.condition('PublishStatus').equals('Online')
	.condition('Language').equals('en_US')
	.withDataCategory('Geography__c').at(new List<String>{'USA__c', 'Canada__c', 'Mexico__c'})
	.toList();
```

#### Multiple Groups (AND)

Chain multiple `.withDataCategory()` calls for different groups. Groups are joined with `AND` in the generated SOQL.

```apex
List<SObject> articles = QRY_Builder.selectFrom(KnowledgeArticleVersion.SObjectType)
	.fields(new List<SObjectField>{ KnowledgeArticleVersion.Id, KnowledgeArticleVersion.Title })
	.condition('PublishStatus').equals('Online')
	.condition('Language').equals('en_US')
	.withDataCategory('Geography__c').at('USA__c')
	.withDataCategory('Product__c').below('Electronics__c')
	.toList();
```

#### Hierarchy Traversal with BELOW

Use `.below()` to query all descendants of a category. This is useful for querying an entire branch of the hierarchy.

```apex
List<SObject> articles = QRY_Builder.selectFrom(KnowledgeArticleVersion.SObjectType)
	.fields(new List<SObjectField>{ KnowledgeArticleVersion.Id, KnowledgeArticleVersion.Title })
	.condition('PublishStatus').equals('Online')
	.condition('Language').equals('en_US')
	.withDataCategory('Product__c').below('All')
	.toList();
```

#### Constraints

- **One filter per group** — adding two filters for the same group throws `IllegalArgumentException`
- **Mutually exclusive with `WITH USER_MODE`** — combining `.withDataCategory()` with `.withUserMode()` throws a configuration error; scope field-level security separately when querying data categories
- **Knowledge queries require `PublishStatus` in WHERE** — Salesforce returns an error if omitted
- **`Language` required when Translation Workbench is enabled** — add `.condition('Language').equals('en_US')`

### Batch Processing

#### QueryLocator for Batch Apex

```apex
/**
 * @description Batch class example using QRY_Builder
 */
public with sharing class BATCH_ProcessAccounts implements Database.Batchable<SObject>
{
	public Database.QueryLocator start(Database.BatchableContext context)
	{
		return QRY_Builder.selectFrom(Account.SObjectType)
			.fields(new List<SObjectField>{Account.Name, Account.Industry, Account.AnnualRevenue})
			.condition(Account.Type).equals('Customer')
			.andCondition(Account.AnnualRevenue).greaterThan(1000000)
			.toQueryLocator(); // Returns QueryLocator for batch processing
	}

	public void execute(Database.BatchableContext context, List<Account> accounts)
	{
		// Process accounts
		for(Account account : accounts)
		{
			// Business logic here
		}
	}

	public void finish(Database.BatchableContext context)
	{
		LOG_Builder.build().info('Batch complete').emitAt('MyBatch.finish');
	}
}
```

#### Cursor-Based Processing

Use `toCursor()` for efficient traversal of large datasets that exceed the 2,000 OFFSET limit. Cursors support up to 50 million records and don't require loading all records into
memory.

```apex
/**
 * @description Process large dataset using cursor-based pagination
 */
public static void processLargeDataset()
{
	Database.Cursor cursor = QRY_Builder.selectFrom(Account.SObjectType)
		.fields(new List<SObjectField>{Account.Name, Account.Industry})
		.condition(Account.Industry).equals('Technology')
		.toCursor();

	// Get total record count
	Integer totalRecords = cursor.getNumRecords();
	LOG_Builder.build().info('Total records to process: ' + totalRecords).emitAt('MyClass.processLargeDataset');

	// Process in batches of 200
	Integer batchSize = 200;
	Integer processed = 0;

	while(processed < totalRecords)
	{
		List<SObject> batch = cursor.fetch(processed, batchSize);
		for(SObject record : batch)
		{
			// Process each record
		}
		processed += batch.size();
	}
}
```

**Cursor vs QueryLocator vs OFFSET:**

| Feature         | `toCursor()`        | `toQueryLocator()`      | OFFSET              |
|-----------------|---------------------|-------------------------|---------------------|
| **Max Records** | 50 million          | 50 million              | 2,000 (with OFFSET) |
| **Use Case**    | Apex code traversal | Batch Apex `start()`    | Simple pagination   |
| **Memory**      | Fetch on demand     | Batch framework handles | All in memory       |
| **Subqueries**  | ❌ Not supported     | ❌ Not supported         | ✅ Supported         |
| **Aggregates**  | ❌ Not supported     | ❌ Not supported         | ✅ Supported         |
| **FOR UPDATE**  | ❌ Not supported     | ❌ Not supported         | ✅ Supported         |

**When to Use Cursors:**

- Processing more than 2,000 records outside of batch context
- Need random access to large result sets
- Memory-efficient traversal of millions of records

### Custom Reusable Selectors (5% Use Case)

#### Extending Builder

```apex
/**
 * @description Custom reusable selector for Account queries with defaults
 */
public inherited sharing class AccountSelector extends QRY_Builder.Builder
{
	public AccountSelector()
	{
		super(Account.SObjectType);
	}

	/**
	 * @description Default fields included in all Account queries
	 */
	public override Set<String> getDefaultFields()
	{
		return new Set<String>{'Id', 'Name', 'Industry', 'Type', 'AnnualRevenue'};
	}

	/**
	 * @description Base condition applied to all queries (e.g., exclude deleted)
	 */
	public override QRY_Condition.Evaluable getBaseCondition()
	{
		return new QRY_Condition.FieldCondition(Account.IsDeleted).notEquals(true);
	}

	/**
	 * @description Default ordering for all queries
	 */
	public override List<QRY_Generator.OrderBy> getDefaultOrderBy()
	{
		return new List<QRY_Generator.OrderBy>{new QRY_Generator.OrderBy('Name').ascending()};
	}

	/**
	 * @description Finds active customer accounts by industry
	 *
	 * @param industry Industry to filter by
	 *
	 * @return List of matching accounts
	 */
	public List<Account> findActiveCustomersByIndustry(String industry)
	{
		return (List<Account>)this.condition(Account.Industry).equals(industry)
			.andCondition(Account.Type).equals('Customer')
			.andCondition(Account.Active__c).equals('Yes')
			.toList();
	}

	/**
	 * @description Finds high-value accounts
	 *
	 * @param minimumRevenue Minimum annual revenue
	 *
	 * @return List of high-value accounts
	 */
	public List<Account> findHighValueAccounts(Decimal minimumRevenue)
	{
		return (List<Account>)this.condition(Account.AnnualRevenue).greaterThanOrEquals(minimumRevenue)
			.toList();
	}
}

// Usage:
AccountSelector selector = new AccountSelector();
List<Account> techAccounts = selector.findActiveCustomersByIndustry('Technology');
List<Account> highValueAccounts = selector.findHighValueAccounts(5000000);
```

### Combining Multiple Patterns

#### Complex Real-World Example

```apex
/**
 * @description Finds recently modified high-value opportunities with caching
 *
 * @param minimumAmount Minimum opportunity amount
 * @param days Number of days to look back
 *
 * @return List of opportunities with account information
 */
public static List<Opportunity> findRecentHighValueOpportunities(Decimal minimumAmount, Integer days)
{
	Date cutoffDate = Date.today().addDays(-days);

	return QRY_Builder.selectFrom(Opportunity.SObjectType)
		.fields(new List<SObjectField>{ Opportunity.Name, Opportunity.StageName, Opportunity.Amount, Opportunity.CloseDate, Opportunity.LastModifiedDate })
		.relatedFields(new List<String>{'Account.Name', 'Account.Industry', 'Owner.Name'})
		// Add conditions
		.condition(Opportunity.Amount).greaterThanOrEquals(minimumAmount)
		.andCondition(Opportunity.LastModifiedDate).greaterThanOrEquals(cutoffDate)
		.andCondition(Opportunity.StageName).isIn(new List<String>{'Prospecting', 'Qualification', 'Proposal'})
		// Ordering
		.orderBy(Opportunity.LastModifiedDate).descending()
		.orderBy(Opportunity.Amount).descending().nullsLast()
		// Performance & Security
		.withCache(600) // Cache for 10 minutes
		.stripInaccessible()
		// Limit results
		.withLimit(100)
		.toList();
}
```

---

## Testing

The Selector Framework provides built-in support for mocking query results in unit tests. This allows you to test business logic without requiring database operations, making tests
faster and more isolated.

**Key Benefits:**

- **Faster Tests** - No database round-trips means faster test execution
- **Isolated Testing** - Test business logic independent of database state
- **Predictable Results** - Control exactly what data your code receives
- **Avoid Validation Rules** - Test with data that might fail validation rules in subscriber orgs

### Basic Query Mocking

Use `QRY_Builder.setMock()` to configure mock results and `QRY_Builder.clearMocks()` to reset:

```apex
@IsTest
private static void testWithMockedQuery()
{
	List<Account> mockAccounts = (List<Account>)TST_Builder.of(Account.SObjectType)
		.withCount(2)
		.withoutInsertion(true)
		.buildList();

	// Configure mock - all QRY_Builder calls for Account will return these records
	QRY_Builder.setMock(Account.SObjectType, mockAccounts);

	Test.startTest();
	List<Account> results = QRY_Builder.selectFrom(Account.SObjectType)
		.fields(new List<SObjectField>{ Account.Name })
		.condition(Account.Industry).equals('Technology')
		.toList();
	Test.stopTest();

	Assert.areEqual(2, results.size(), 'Should return mocked records');
	Assert.areEqual('Mock Account 1', results[0].Name);

	QRY_Builder.clearMocks();
}
```

**Important:** When mocks are active, query conditions are **not** evaluated. All `QRY_Builder` calls for the mocked SObject type return the configured mock data regardless of
WHERE conditions.

### Creating Mock Records

Use `TST_Builder.withoutInsertion(true)` to create records with auto-generated mock IDs:

```apex
@IsTest
private static void testWithFactoryMockRecords()
{
	List<Account> mockAccounts = new List<Account>();

	// withoutInsertion(true) generates valid mock IDs without database insertion
	for(Integer i = 0; i < 5; i++)
	{
		Account mockAccount = (Account)TST_Builder.of(Account.SObjectType)
			.withOverrides(new Map<SObjectField, Object>
			{
				Account.Name => 'Mock Account ' + i,
				Account.Industry => 'Technology',
				Account.AnnualRevenue => 100000 * i
			})
			.withoutInsertion(true) // Generate mock ID without DML
			.build();
		mockAccounts.add(mockAccount);
	}

	// Configure mock
	QRY_Builder.setMock(Account.SObjectType, mockAccounts);

	Test.startTest();
	Account result = (Account)QRY_Builder.selectFrom(Account.SObjectType)
		.fields(new List<SObjectField>{ Account.Name, Account.Industry, Account.AnnualRevenue })
		.condition(Account.Id).equals(mockAccounts[2].Id)
		.getFirst();
	Test.stopTest();

	Assert.isNotNull(result);
	Assert.areEqual('Mock Account 0', result.Name);

	QRY_Builder.clearMocks();
}
```

**Difference between `withoutInsertion()` and `withoutInsertion(true)`:**

- `withoutInsertion()` - Creates record in memory with **no ID** (null Id)
- `withoutInsertion(true)` - Creates record in memory with **auto-generated mock ID** (valid 18-character Id)

Use `withoutInsertion(true)` when you need records with IDs for:

- Query mocking (records need IDs for realistic testing)
- Code that checks `record.Id != null`
- Map keys or Set membership based on Id

### Multiple Query Mocking

Mock multiple SObject types in the same test:

```apex
@IsTest
private static void testWithMultipleMockedTypes()
{
	List<Account> mockAccounts = new List<Account>
	{
		(Account)TST_Builder.of(Account.SObjectType)
			.withOverride(Account.Name, 'Acme Corp')
			.withoutInsertion(true)
			.build()
	};

	List<Contact> mockContacts = new List<Contact>
	{
		(Contact)TST_Builder.of(Contact.SObjectType)
			.withOverrides(new Map<SObjectField, Object>
			{
				Contact.FirstName => 'John',
				Contact.LastName => 'Doe',
				Contact.AccountId => mockAccounts[0].Id
			})
			.withoutInsertion(true)
			.build()
	};

	// Configure mocks for both types
	QRY_Builder.setMock(Account.SObjectType, mockAccounts);
	QRY_Builder.setMock(Contact.SObjectType, mockContacts);

	Test.startTest();
	List<Account> accounts = QRY_Builder.selectFrom(Account.SObjectType)
		.fields(new List<SObjectField>{ Account.Name })
		.toList();

	List<Contact> contacts = QRY_Builder.selectFrom(Contact.SObjectType)
		.fields(new List<SObjectField>{ Contact.FirstName, Contact.LastName })
		.condition(Contact.AccountId).equals(mockAccounts[0].Id)
		.toList();
	Test.stopTest();

	Assert.areEqual(1, accounts.size());
	Assert.areEqual('Acme Corp', accounts[0].Name);
	Assert.areEqual(1, contacts.size());
	Assert.areEqual('John', contacts[0].FirstName);

	QRY_Builder.clearMocks();
}
```

### Mocking with TST_Mock

Use [TST_Mock](reference/apex/TST_Mock.md) for a friendlier API that auto-registers mocks for query interception:

```apex
@IsTest
private static void shouldReturnMockData()
{
	// Build mock + auto-register for query interception
	Account mock = (Account)TST_Mock.of(Account.SObjectType)
		.withOverride(Account.Name, 'Mock Account')
		.withOverride(Account.Industry, 'Finance')
		.build();

	// QRY_Builder queries now return mock data
	Test.startTest();
	List<Account> results = QRY_Builder.selectFrom(Account.SObjectType)
		.fields(new List<SObjectField>{ Account.Name, Account.Industry })
		.condition(Account.Industry).equals('Technology')
		.toList();
	Test.stopTest();

	Assert.areEqual(1, results.size());
	Assert.areEqual('Finance', results[0].Industry);

	TST_Mock.clear();
}
```

### Limitations

#### AggregateResult Mocking Not Supported

**AggregateResult queries cannot be mocked.** This is a Salesforce platform limitation:

```apex
// ❌ NOT POSSIBLE - AggregateResult cannot be instantiated
List<AggregateResult> mockResults = new List<AggregateResult>
{
	new AggregateResult() // Compilation error - no public constructor
};
```

**Reason:** `AggregateResult` is a final class with no public constructor. There is no way to create instances of `AggregateResult` in Apex code.

Because `toAggregateList()` returns `QRY_Builder.AggregateRow` (a wrapper around `AggregateResult`), test the value-bearing methods on `AggregateRow` directly against real data
inserted via `TST_Builder`.

**Workaround:** For testing aggregate queries, insert real test data:

```apex
@IsTest
private static void testAggregateQuery()
{
	// Must use real data for aggregate queries
	List<SObject> testAccounts = TST_Builder.of(Account.SObjectType)
		.withOverrides(new Map<SObjectField, Object>{ Account.Industry => 'Technology', Account.AnnualRevenue => 100000 })
		.withCount(2)
		.buildList();

	TST_Builder.of(Account.SObjectType)
		.withOverrides(new Map<SObjectField, Object>{ Account.Industry => 'Finance', Account.AnnualRevenue => 150000 })
		.build();

	Test.startTest();
	List<QRY_Builder.AggregateRow> results = QRY_Builder.selectFrom(Account.SObjectType)
		.sum(Account.AnnualRevenue)
		.groupBy(Account.Industry)
		.toAggregateList();
	Test.stopTest();

	Assert.areEqual(2, results.size(), 'Should have 2 industry groups');
}
```

#### Query Conditions Not Evaluated

When mocking is active, **all query conditions are bypassed**. The mock returns all configured records regardless of WHERE clauses, ORDER BY, or LIMIT:

```apex
// These queries return the SAME mock data when mocking is active:
QRY_Builder.selectFrom(Account.SObjectType).condition(Account.Industry).equals('Tech').toList();
QRY_Builder.selectFrom(Account.SObjectType).condition(Account.Industry).equals('Finance').toList();
QRY_Builder.selectFrom(Account.SObjectType).withLimit(1).toList();
```

If you need to test condition logic, either:

1. Use real database records
2. Pre-filter your mock data to match expected conditions

#### Mock Scope

Mocks are active for the **entire test transaction** until cleared. Always call `clearMocks()` in test cleanup or between test scenarios to prevent test pollution.

---

## Capability Matrix (for Analysts)

| Capability                       | Control Point              | Method                 | Notes                                           |
|----------------------------------|----------------------------|------------------------|-------------------------------------------------|
| USER_MODE (CRUD + FLS + Sharing) | Database-level enforcement | `.withUserMode()`      | Full security enforcement at the database level |
| Strip inaccessible fields        | Post-query field removal   | `.stripInaccessible()` | Removes fields the running user cannot access   |
| Sharing enforcement              | Proxy class delegation     | `.withSharing()`       | Runs query in `with sharing` context            |
| Sharing bypass                   | Proxy class delegation     | `.bypassSharing()`     | Runs query in `without sharing` context         |
| Reset to defaults                | Security reset             | `.withoutSecurity()`   | Returns to SYSTEM_MODE with inherited sharing   |
| Row locking                      | FOR UPDATE clause          | `.forUpdate()`         | Locks records for update within the transaction |
| Query caching                    | Platform cache             | `.withCache()`         | Caches query results in platform cache          |

---

## Anti-Patterns

| Anti-Pattern                                              | Why It's Wrong                                                                       | Instead                                                                                 |
|-----------------------------------------------------------|--------------------------------------------------------------------------------------|-----------------------------------------------------------------------------------------|
| Inline SOQL scattered across classes                      | Duplicates field lists, makes refactoring error-prone, and bypasses sharing controls | Use `QRY_Builder` or a custom `SEL_*` selector class                                    |
| Business logic inside a selector                          | Selectors become untestable and violate single responsibility                        | Keep selectors pure -- move logic to trigger actions or service classes                 |
| Querying inside a loop                                    | Causes SOQL governor limit exceptions on bulk operations                             | Collect IDs first, query once, then iterate over results                                |
| Ignoring sharing declarations                             | Runs queries with unpredictable sharing context inherited from the caller            | Always use `.withSharing()`, `.bypassSharing()`, or `.withUserMode()` explicitly        |
| Hardcoded field name strings in selectors                 | Breaks silently when fields are renamed or deleted                                   | Use `SObjectField` token references (e.g., `Account.Name`)                              |
| Using `QRY_Builder.selectFrom()` inside a selector method | Bypasses the selector's default fields and breaks reusability                        | Use the inherited `query` property which returns a pre-configured `QRY_Builder.Builder` |

---

## Best Practices

### **Always Use Selector Classes**

**DO:**

```apex
// Use selector methods
List<Account> accounts = new SEL_Accounts().findById(accountIds);
```

**DON'T:**

```apex
// Avoid inline SOQL
List<Account> accounts = [SELECT Name, Industry FROM Account WHERE Id IN :accountIds];
```

### **Use `query` Property Inside Selectors, QRY_Builder for One-Off**

Inside selector classes, always use the inherited `query` property — it returns a `QRY_Builder.Builder`
pre-configured with your default fields. Use `QRY_Builder.selectFrom()` directly only for one-off
queries where no selector exists.

**DO:**

```apex
// Inside a selector — uses default fields automatically
public List<Account> findCustomers()
{
	return query.condition(Account.Type).equals('Customer').toList();
}

// One-off query without a selector
List<Account> accounts = QRY_Builder.selectFrom(Account.SObjectType)
	.fields(new List<SObjectField>{Account.Name, Account.Industry})
	.condition(Account.Type).equals('Customer')
	.toList();
```

**DON'T:**

```apex
// Inside a selector — bypasses default fields
public List<Account> findCustomers()
{
	return QRY_Builder.selectFrom(Account.SObjectType)
		.fields(new List<SObjectField>{ Account.Name, Account.Industry })
		.condition(Account.Type).equals('Customer')
		.toList();
}
```

### **Create Custom Selector Classes for Each SObject**

Centralize all queries for an SObject in a dedicated selector class extending [SEL_Base](reference/apex/SEL_Base.md):

- `SEL_Contacts` for Contact queries
- `SEL_Accounts` for Account queries
- Define `getFields()` method for consistent field sets

### **Use Type-Safe Field References**

**DO:**

```apex
.condition(Account.Industry).equals('Technology')
.orderBy(Account.AnnualRevenue).descending()
```

**DON'T:**

```apex
.condition('Industy').equals('Technology') // String field names prone to typos
```

### **Be Explicit About Sharing**

Always explicitly set sharing when security is a concern:

```apex
// For user-facing queries - enforce sharing
.withSharing()

// For user-facing queries - full CRUD/FLS/sharing enforcement
.withUserMode()

// For system operations - bypass sharing
.bypassSharing()
```

### **Choose the Right Layer**

- **Production code** — Extend [SEL_Base](reference/apex/SEL_Base.md) for each queried object
    - Default fields, inherited `findById()`, `findByField()`
    - Custom query methods using the `query` property
    - Reusable, testable, mockable
- **One-off / ad-hoc** — Use [QRY_Builder](reference/apex/QRY_Builder.md) directly
    - Anonymous Apex, scripts, objects without a selector
    - Caching, pagination, result transformation

**Rule of thumb:** If you query the same object from two or more places, create a selector. If it's
a one-off, use `QRY_Builder.selectFrom()` directly.

**Example:**

```apex
// Production — selector with default fields and reusable method
Account account = (Account)new SEL_Accounts().findById(accountId);
List<Account> techAccounts = new SEL_Accounts().findByIndustry('Technology');

// One-off — QRY_Builder directly
List<Account> accounts = QRY_Builder.selectFrom(Account.SObjectType)
	.fields(new List<SObjectField>{Account.Name, Account.Industry})
	.condition(Account.AnnualRevenue).greaterThan(1000000)
	.withCache(300)
	.toList();
```

### **Use QueryLocator for Batch Apex**

Always use `QRY_Builder.toQueryLocator()` in batch `start()` methods:

```apex
public Database.QueryLocator start(Database.BatchableContext context)
{
	return QRY_Builder.selectFrom(Account.SObjectType)
		.fields(new List<SObjectField>{Account.Name, Account.Industry})
		.condition(Account.Type).equals('Customer')
		.toQueryLocator();
}
```

### **Avoid Query Loops**

**DO:**

```apex
// Query once, process many
Set<Id> accountIds = new Set<Id>();
for(Opportunity opportunity : opportunities)
{
	accountIds.add(opportunity.AccountId);
}
List<Account> accounts = new SEL_Accounts().findById(accountIds);
Map<Id, Account> accountMap = new Map<Id, Account>(accounts);
```

**DON'T:**

```apex
// Query inside loop - GOVERNOR LIMIT VIOLATION
for(Opportunity opportunity : opportunities)
{
	Account account = (Account)new SEL_Accounts().findById(opportunity.AccountId);
}
```

### **Test with [TST_Builder](reference/apex/TST_Builder.md)**

Use the builder pattern for test data creation:

```apex
@IsTest
private static void shouldReturnResults()
{
	Account testAccount = (Account)TST_Builder.of(Account.SObjectType)
		.withOverrides(new Map<SObjectField, Object>
		{
			Account.Industry => 'Technology',
			Account.AnnualRevenue => 1000000
		})
		.build();

	Test.startTest();
	List<Account> results = new SEL_Accounts().findByField(Account.Industry, 'Technology');
	Test.stopTest();

	Assert.isNotNull(results, 'Results should not be null');
}
```

### **Document Query Methods**

All query methods must have comprehensive ApexDoc:

```apex
// Finds active contacts for the specified accounts
Set<Id> accountIds = new Set<Id>{acc1.Id, acc2.Id};
List<Contact> contacts = new SEL_Contacts().findActiveByAccountIds(accountIds);
```

### **Handle Null and Empty Collections**

**Option A: Manual validation (return early)**

```apex
public static List<Contact> findByAccountIds(Set<Id> accountIds)
{
	if(accountIds == null || accountIds.isEmpty())
	{
		return new List<Contact>();
	}

	return QRY_Builder.selectFrom(Contact.SObjectType)
		.fields(new List<SObjectField>{Contact.Id, Contact.Name})
		.condition(Contact.AccountId).isIn(new List<Id>(accountIds))
		.toList();
}
```

**Option B: Use safe empty collection handling (non-strict methods)**

The non-strict collection methods (`isIn()`, `notInSet()`, `includes()`, `excludes()`) handle empty/null collections safely:

| Method       | Empty/Null Behaviour                              |
|--------------|---------------------------------------------------|
| `isIn()`     | Returns zero results (adds impossible `Id` match) |
| `notInSet()` | Skips condition (excludes nothing)                |
| `includes()` | Skips condition (matches all)                     |
| `excludes()` | Skips condition (matches all)                     |

**Option C: Use strict methods to surface bugs**

When an empty collection indicates a programming error, use strict variants to fail fast:

```apex
public static List<Contact> findByAccountIds(Set<Id> accountIds)
{
	// Throws IllegalArgumentException if accountIds is null or empty
	return QRY_Builder.selectFrom(Contact.SObjectType)
		.fields(new List<SObjectField>{Contact.Id, Contact.Name})
		.condition(Contact.AccountId).isInStrict(new List<Id>(accountIds))
		.toList();
}
```

Strict methods: `isInStrict()`, `notInSetStrict()`, `includesStrict()`, `excludesStrict()`

### **Use Pagination for Large Result Sets**

Prevent governor limit issues with built-in pagination:

```apex
// Use getPage() for paginated results with metadata
QRY_Builder.QueryPage result = QRY_Builder.selectFrom(Account.SObjectType)
	.fields(new List<SObjectField>{ Account.Name, Account.Industry })
	.condition(Account.Type).equals('Customer')
	.getPage(1, 200); // Page 1, 200 records per page

// Access results and metadata
List<SObject> records = result.records;
Integer totalRecords = result.totalRecords;
Boolean hasMore = result.hasMorePages;
Integer deletedSinceCursorCreated = result.deletedRecords;
Database.PaginationCursor cursor = result.cursor;
```

### **Leverage Subqueries for Efficiency**

Use parent-to-child subqueries to reduce query count:

```apex
// ONE query returning accounts with contacts
List<Account> accountsWithContacts = getAccountsWithContacts(accountIds);

// Instead of TWO separate queries
List<Account> accounts = getAccounts(accountIds);
List<Contact> contacts = getContactsByAccountIds(accountIds);
```

---

## Related Documentation

- [Triggers - Guide](Triggers%20-%20Guide.md) - Trigger actions that use selectors for cross-object queries
- [DML - Guide](DML%20-%20Guide.md) - DML operations paired with selector queries
- [Validation - Guide](Validation%20-%20Guide.md) - Validation context classes that use selectors for bulk data loading
- [Logging - Guide](Logging%20-%20Guide.md) - Query performance logging and correlation tracking
- [Web Services - Guide](Web%20Services%20-%20Guide.md) - DTO population via selectors in API classes
