# DML - Guide

**Framework:** KernDX
**Package Type:** Managed Package

**Target Audience:**
- **Developers** - Implementing secure DML operations using Unit of Work, bulk processing, and test data factories
- **Architects** - Designing transactional patterns with proper sharing enforcement and permission checking
- **Business Analysts** - Understanding data operation capabilities, security controls, and testing patterns

---

## Table of Contents

<details>
<summary>Expand</summary>

1. [Quick Navigation](#quick-navigation)
2. [Overview](#overview)
3. [Architecture](#architecture)
   - [Architecture Diagram](#architecture-diagram)
   - [Layer 1: DML_Transaction](#layer-1-dml_transaction)
   - [Layer 2: DML_Builder](#layer-2-dml_builder)
   - [Layer 3: Sharing Proxy](#layer-3-sharing-proxy)
   - [Layer 4: FLOW_CheckObjectPermissions](#layer-4-flow_checkobjectpermissions)
4. [Quick Start](#quick-start)
5. [Transactional DML Pattern (DML_Builder)](#transactional-dml-pattern-dml_builder)
   - [Basic Usage](#basic-usage)
   - [Managing Dependencies](#managing-dependencies)
   - [Registering Relationships](#registering-relationships)
   - [Upsert with External ID](#upsert-with-external-id)
   - [Mixed Operations](#mixed-operations)
6. [Bulk DML Operations (DML_Builder)](#bulk-dml-operations-dml_builder)
   - [Insert Operations](#insert-operations)
   - [Update Operations](#update-operations)
   - [Delete Operations](#delete-operations)
   - [Upsert Operations](#upsert-operations)
   - [Undelete Operations](#undelete-operations)
7. [Sharing Enforcement](#sharing-enforcement)
   - [Context-Driven Sharing](#context-driven-sharing)
   - [Operation-Level Sharing](#operation-level-sharing)
   - [Access Mode (USER_MODE / SYSTEM_MODE)](#access-mode-user_mode--system_mode)
   - [Bypass vs Enforce vs Inherited](#bypass-vs-enforce-vs-inherited)
8. [Permission Checking (FLOW_CheckObjectPermissions)](#permission-checking-flow_checkobjectpermissions)
   - [Object-Level Permissions](#object-level-permissions)
   - [Before DML Checks](#before-dml-checks)
   - [Field-Level Security](#field-level-security)
9. [Test Data Factory](#test-data-factory)
   - [TST_Builder](#tst_builder)
   - [Basic Usage](#basic-usage-1)
   - [Field Overrides](#field-overrides)
   - [Bulk Record Creation](#bulk-record-creation)
   - [Record Type Support](#record-type-support)
   - [Parent-Child Relationships](#parent-child-relationships)
     - [Pattern 1: Simple Child Creation (No Field Overrides)](#pattern-1-simple-child-creation-no-field-overrides)
     - [Pattern 2: Children with Field Overrides](#pattern-2-children-with-field-overrides)
     - [Pattern 3: Children Using Builder (Complex Configuration)](#pattern-3-children-using-builder-complex-configuration)
     - [Pattern 4: Multiple Child Types](#pattern-4-multiple-child-types)
     - [Pattern 5: Explicit Relationship Name (Edge Cases)](#pattern-5-explicit-relationship-name-edge-cases)
     - [In-Memory Parent-Child Graphs (No DML)](#in-memory-parent-child-graphs-no-dml)
     - [Bulk Parents with Children](#bulk-parents-with-children)
   - [Optional and Defaulted Fields](#optional-and-defaulted-fields)
     - [Force Optional Fields to be Populated](#force-optional-fields-to-be-populated)
     - [Multi-Level Relationship Paths](#multi-level-relationship-paths)
     - [Mark Required Fields as Optional](#mark-required-fields-as-optional)
   - [Advanced Features](#advanced-features)
     - [Mock ID Generation for Query Mocking](#mock-id-generation-for-query-mocking)
     - [Auto-Default Marker](#auto-default-marker)
     - [Custom Default Value Provider](#custom-default-value-provider)
     - [Custom Factory Provider](#custom-factory-provider)
   - [Complete Example](#complete-example)
10. [Bulk Utilities (UTIL_BulkUpdates & UTIL_PurgeRecords)](#bulk-utilities-util_bulkupdates--util_purgerecords)
    - [Bulk Field Updates](#bulk-field-updates)
    - [Purge Records (UTIL_PurgeRecords)](#purge-records-util_purgerecords)
    - [Deactivate Users](#deactivate-users)
    - [Batch Processing](#batch-processing)
11. [Testing](#testing)
12. [Capability Matrix (for Analysts)](#capability-matrix-for-analysts)
13. [Anti-Patterns](#anti-patterns)
14. [Best Practices](#best-practices)
    - [1. Use Transactional DML for Complex Transactions](#1-use-transactional-dml-for-complex-transactions)
    - [2. Always Use DML_Builder for DML](#2-always-use-dml_builder-for-dml)
    - [3. Be Explicit About Sharing](#3-be-explicit-about-sharing)
    - [4. Check Permissions Before DML](#4-check-permissions-before-dml)
    - [5. Use TST_Builder in Tests](#5-use-tst_builder-in-tests)
    - [6. Handle DML Errors Properly](#6-handle-dml-errors-properly)
    - [7. Use Bulk Operations](#7-use-bulk-operations)
    - [8. Leverage Batch Apex for Large Volumes](#8-leverage-batch-apex-for-large-volumes)
    - [9. Use UTIL_BulkUpdates for Common Bulk Operations](#9-use-util_bulkupdates-for-common-bulk-operations)
    - [10. Create Fresh Transactions](#10-create-fresh-transactions)
    - [11. Document DML Operations](#11-document-dml-operations)
    - [12. Use All-or-Nothing Appropriately](#12-use-all-or-nothing-appropriately)
    - [13. Reset Sharing After Operations](#13-reset-sharing-after-operations)
    - [14. Use Purge Utilities for Cleanup](#14-use-purge-utilities-for-cleanup)
15. [Related Documentation](#related-documentation)

</details>

---

## Quick Navigation

| I am a...     | I need to...                      | Go to...                                                                     |
|---------------|-----------------------------------|------------------------------------------------------------------------------|
| **Architect** | Design transaction patterns       | [Architecture](#architecture)                                                |
| **Architect** | Understand sharing enforcement    | [Sharing Enforcement](#sharing-enforcement)                                  |
| **Developer** | Perform DML operations            | [Quick Start](#quick-start)                                                  |
| **Developer** | Build test data                   | [Test Data Factory](#test-data-factory)                                      |
| **Developer** | Handle complex transactions       | [Transactional DML Pattern](#transactional-dml-pattern-dml_builder)          |
| **Analyst**   | Understand permission checking    | [Permission Checking](#permission-checking-flow_checkobjectpermissions)      |
| **Analyst**   | Know DML capabilities             | [Capability Matrix](#capability-matrix-for-analysts)                         |

---

## Overview

The DML Operations framework provides enterprise-grade patterns for managing [database operations](https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/langCon_apex_dml.htm) in Salesforce. It implements industry-standard patterns including Unit of Work, bulk DML processing, sharing enforcement, and permission checking to ensure secure, performant, and maintainable data operations.

The framework consists of four complementary layers:

1. **[`DML_Transaction`](reference/apex/DML_Transaction.md)** - Unit of Work pattern for managing complex transactions
2. **[`DML_Builder`](reference/apex/DML_Builder.md)** - Bulk DML operations with sharing control
3. **Sharing Proxy** - Sharing enforcement mechanisms
4. **[`FLOW_CheckObjectPermissions`](reference/apex/FLOW_CheckObjectPermissions.md)** - Permission checking utilities

Additional utilities include:
- **[`TST_Builder`](reference/apex/TST_Builder.md)** - Test data factory with builder pattern
- **`UTIL_PurgeRecords`** - Bulk record deletion utilities
- **`UTIL_BulkUpdates`** - Bulk update operations

> **DML Framework Scope:** 6 DML classes providing transactional Unit of Work, bulk operations, sharing control, and partial success handling.
> The test data factory (`TST_Builder`, `TST_Factory`, `TST_Mock`) spans 10 utility classes used across 165 test classes and ~3,359 Apex
> test methods (see [Metrics](Strategic%20Guide%20-%20Metrics.md)).

> **Responsibilities:** The DML framework manages database writes (insert, update, delete, upsert, undelete) with transactional integrity,
> sharing control, and error handling. It does not query data -- use selectors for that. It does not contain business logic.

> **When NOT to use this pattern:**
> - Single-record field assignments in before-trigger actions where direct field mutation on `Trigger.new` suffices (no DML needed)
> - Anonymous Apex scripts or data loader operations where the overhead of `DML_Builder` adds no value

**Key Benefits:**
- **Transaction Management** - Unit of Work pattern for complex multi-object transactions
- **Bulk Processing** - Efficient handling of large data volumes
- **Sharing Control** - Explicit enforcement or bypass of [sharing rules](https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_security_sharing_rules.htm)
- **Permission Checking** - Validate user permissions before DML operations
- **Test Data** - Builder pattern for clean, maintainable test data creation
- **Consistency** - Standardized DML patterns across the codebase

---

## Architecture

### Architecture Diagram

```text
+---------------------------------------------------------------------------+
|                       DML FRAMEWORK ARCHITECTURE                          |
+---------------------------------------------------------------------------+
|                                                                           |
|  Your Code / Trigger Action / Flow Invocable                              |
|        |                                                                  |
|        v                                                                  |
|  +-------------------------------------------------------------------+   |
|  |  Layer 4: FLOW_CheckObjectPermissions                             |   |
|  |  - Validates CRUD/FLS before DML                                  |   |
|  |  - Invocable for Flow integration                                 |   |
|  +-------------------------------+-----------------------------------+   |
|                                  |                                       |
|                                  v                                       |
|  +-------------------------------------------------------------------+   |
|  |  Layer 1: DML_Transaction (Unit of Work)                          |   |
|  |  - Registers insert, update, delete, upsert, undelete            |   |
|  |  - Manages parent-child relationship resolution                   |   |
|  |  - Single atomic commit or full rollback                          |   |
|  +-------------------------------+-----------------------------------+   |
|                                  |                                       |
|                                  v                                       |
|  +-------------------------------------------------------------------+   |
|  |  Layer 2: DML_Builder (Standardized DML)                          |   |
|  |  - Fluent API: newTransaction().doInsert().execute()              |   |
|  |  - Partial success (.allowPartial()) or all-or-nothing           |   |
|  |  - TransactionResult with error inspection                        |   |
|  +-------------------------------+-----------------------------------+   |
|                                  |                                       |
|                                  v                                       |
|  +-------------------------------------------------------------------+   |
|  |  Layer 3: Sharing Proxy                                           |   |
|  |  - BYPASS: without sharing context                                |   |
|  |  - ENFORCE: with sharing context                                  |   |
|  |  - INHERITED: caller's sharing context (default)                  |   |
|  +-------------------------------+-----------------------------------+   |
|                                  |                                       |
|                                  v                                       |
|                     +------------------------+                           |
|                     |    Database.*           |                           |
|                     |  (Salesforce DML)       |                           |
|                     +------------------------+                           |
|                                                                           |
+---------------------------------------------------------------------------+
```

### Layer 1: [`DML_Transaction`](reference/apex/DML_Transaction.md)

**Purpose:** Implements Martin Fowler's [Unit of Work](https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/langCon_apex_transaction.htm) pattern to manage complex DML operations across multiple SObjects in a single transaction.

**When to Use:** When you need to perform multiple DML operations that must succeed or fail as a single unit, especially with relationship management between objects.

**Key Features:**
- Register records for insert, update, delete, upsert, and undelete
- Automatic dependency management
- Parent-child relationship resolution
- Single transaction commit
- Rollback on failure

**Example:**
```apex
// Creates an Account with related Contacts in a single transaction
DML_Builder.newTransaction()
	.doInsert(account)
	.doInsert(contact1, Contact.AccountId, account)
	.doInsert(contact2, Contact.AccountId, account)
	.execute(); // All objects inserted in correct order with relationships maintained
```

### Layer 2: [`DML_Builder`](reference/apex/DML_Builder.md)

**Purpose:** Provides standardized methods for performing [DML operations](https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/langCon_apex_dml.htm) with built-in sharing control and error handling.

**When to Use:** For all database [insert](https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/langCon_apex_dml_examples_insert.htm), [update](https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/langCon_apex_dml_examples_update.htm), [delete](https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/langCon_apex_dml_examples_delete.htm), [upsert](https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/langCon_apex_dml_examples_upsert.htm), and [undelete](https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/langCon_apex_dml_examples_undelete.htm) operations.

**Key Features:**
- Bulk processing support
- Sharing enforcement options
- All-or-nothing vs partial commit
- Comprehensive error handling
- [Database.SaveResult](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_database_saveresult.htm)/[Database.DeleteResult](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_database_deleteresult.htm) management

**Example:**
```apex
// Bulk inserts accounts with sharing enforced
List<Account> accounts = new List<Account>
{
	new Account(Name = 'Account 1'),
	new Account(Name = 'Account 2'),
	new Account(Name = 'Account 3')
};

DML_Builder.TransactionResult result = DML_Builder.newTransaction()
	.doInsert(accounts)
	.execute();
```

### Layer 3: Sharing Proxy

**Purpose:** Controls how [sharing rules](https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_security_sharing_rules.htm) and access mode are applied during DML operations.

**When to Use:** When you need explicit control over access mode (USER_MODE / SYSTEM_MODE) or sharing (proxy class selection) for specific operations.

**Key Features:**
- Secure-by-default: USER_MODE (CRUD + FLS + sharing enforced) via `FeatureFlag.UserModeDml_Enabled`
- `.withUserMode()` / `.withSystemMode()` for explicit access-mode selection
- `.bypassSharing()` for `without sharing` proxy routing (in SYSTEM_MODE)
- Operation-level control via fluent builder methods
- [AccessLevel.SYSTEM_MODE](https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_classes_enforce_usermode.htm) support

**Example:**
```apex
// Default (USER_MODE): CRUD + FLS + sharing all enforced at the database level
DML_Builder.newTransaction().doInsert(accounts).execute();

// Bypass sharing for system operations (routes through `without sharing` proxy)
DML_Builder.newTransaction().doInsert(accounts).bypassSharing().execute();

// Framework-internal writes (e.g., log rows) — bypass CRUD/FLS
DML_Builder.newTransaction().doInsert(logEntries).withSystemMode().execute();
```

### Layer 4: [`FLOW_CheckObjectPermissions`](reference/apex/FLOW_CheckObjectPermissions.md)

**Purpose:** Validates user [permissions](https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_classes_perms_enforcing.htm) before attempting DML operations.

**When to Use:** Before performing DML operations in user-facing features or public sites/communities.

**Key Features:**
- [Object-level permission](https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_methods_system_sobject_describe.htm) checking
- Create, read, update, delete access validation
- Invocable method for Flow integration
- SObject describe-based checks

**Example:**
```apex
// Checks if user can create Account records
FLOW_CheckObjectPermissions.DTO_Request request = new FLOW_CheckObjectPermissions.DTO_Request();
request.objectApiName = 'Account';

List<FLOW_CheckObjectPermissions.DTO_Response> results =
	FLOW_CheckObjectPermissions.checkPermissions(new List<FLOW_CheckObjectPermissions.DTO_Request>{request});

if(results[0].hasCreateAccess)
{
	Account account = new Account(Name = 'New Account');
	DML_Builder.newTransaction().doInsert(account).execute();
}
else
{
	LOG_Builder.build().error('User does not have permission to create Account records').emitAt('MyClass.myMethod');
}
```

---

## Quick Start

The most common DML pattern in KernDX uses `DML_Builder` for straightforward insert, update, and delete operations. For related multi-object transactions, use `DML_Transaction`.

> **Step-by-step walkthrough:** [Fast Start - DML](Fast%20Start%20-%20DML.md) covers implementation,
> testing, and common pitfalls.

**Simple bulk insert:**

```apex
List<Account> accounts = new List<Account>
{
	new Account(Name = 'Acme Corp'),
	new Account(Name = 'Global Industries')
};

DML_Builder.newTransaction().doInsert(accounts).execute();
```

**Related objects in a single transaction:**

```apex
Account account = new Account(Name = 'Acme Corp');
Contact contact = new Contact(FirstName = 'Jane', LastName = 'Doe');

DML_Builder.newTransaction()
	.doInsert(account)
	.doInsert(contact, Contact.AccountId, account)
	.execute();
```

For deeper coverage, continue reading the sections below.

---

## Transactional DML Pattern ([`DML_Builder`](reference/apex/DML_Builder.md))

The transactional DML pattern tracks changes to SObjects and commits them in a single transaction, maintaining referential integrity and dependency order. `DML_Builder` is the public facade; [`DML_Transaction`](reference/apex/DML_Transaction.md) is the internal engine.

### Basic Usage

Use `DML_Builder.newTransaction()` to create a fluent transaction and chain DML operations.

**Example:**
```apex
// Basic transactional DML for creating related records
Account account = new Account(Name = 'Acme Corporation', Industry = 'Technology');
Contact contact = new Contact(FirstName = 'John', LastName = 'Doe', Email = 'john.doe@acme.com');
Opportunity opportunity = new Opportunity(Name = 'Big Deal', StageName = 'Prospecting', CloseDate = Date.today().addDays(30));

DML_Builder.newTransaction()
	.doInsert(account)
	.doInsert(contact, Contact.AccountId, account)
	.doInsert(opportunity, Opportunity.AccountId, account)
	.execute();
```

### Managing Dependencies

The framework automatically resolves parent-child dependency order using the relationship fields specified in `doInsert` calls. Parents are inserted before children, and child foreign keys are populated automatically.

**Example:**
```apex
// DML_Builder resolves dependency order automatically from relationship fields
Account account1 = new Account(Name = 'Account 1');
Account account2 = new Account(Name = 'Account 2');

Contact contact1 = new Contact(LastName = 'Smith');
Contact contact2 = new Contact(LastName = 'Jones');

Opportunity opportunity = new Opportunity(Name = 'Deal', StageName = 'Closed Won', CloseDate = Date.today());

DML_Builder.newTransaction()
	.doInsert(account1)
	.doInsert(account2)
	.doInsert(contact1, Contact.AccountId, account1)
	.doInsert(contact2, Contact.AccountId, account2)
	.doInsert(opportunity, Opportunity.AccountId, account1)
	.execute();
```

### Registering Relationships

Use the three-argument `doInsert` to register relationships between new records that don't have Ids yet. The framework automatically populates foreign keys after parent records are inserted.

**Example:**
```apex
// Register relationships between new records
Account account = new Account(Name = 'Parent Account');

Contact contact1 = new Contact(FirstName = 'John', LastName = 'Doe');
Contact contact2 = new Contact(FirstName = 'Jane', LastName = 'Smith');

Opportunity opportunity = new Opportunity(
	Name = 'Big Opportunity',
	StageName = 'Prospecting',
	CloseDate = Date.today().addDays(60)
);

DML_Builder.newTransaction()
	.doInsert(account)
	.doInsert(contact1, Contact.AccountId, account)
	.doInsert(contact2, Contact.AccountId, account)
	.doInsert(opportunity, Opportunity.AccountId, account)
	.execute();
```

### Upsert with External ID

Use `doUpsert` with an external ID field to match existing records for [upsert](https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/langCon_apex_dml_examples_upsert.htm) operations.

**Single Record:**
```apex
// Upsert using external ID field for matching
Account account = new Account(Name = 'Acme Corp', ExternalId__c = 'EXT-001');

DML_Builder.newTransaction()
	.doUpsert(account, Account.ExternalId__c)
	.execute(); // Inserts new record or updates existing record matching ExternalId__c
```

**Multiple Records:**
```apex
// Bulk upsert using external ID field
List<Account> accounts = new List<Account>
{
	new Account(Name = 'Account 1', ExternalId__c = 'EXT-001'),
	new Account(Name = 'Account 2', ExternalId__c = 'EXT-002'),
	new Account(Name = 'Account 3', ExternalId__c = 'EXT-003')
};

DML_Builder.newTransaction()
	.doUpsert(accounts, Account.ExternalId__c)
	.execute(); // Upserts all records using ExternalId__c for matching
```

**With Parent-Child Relationships:**
```apex
// Upsert parent with related child inserts
Account account = new Account(Name = 'Parent Account', ExternalId__c = 'EXT-PARENT');
Contact contact = new Contact(FirstName = 'John', LastName = 'Doe');

DML_Builder.newTransaction()
	.doUpsert(account, Account.ExternalId__c)
	.doInsert(contact, Contact.AccountId, account)
	.execute();
```

> **Important:** All records of the same SObjectType within a single transaction must use the same external ID field. Attempting to register records with different external ID fields for the same SObjectType throws an `IllegalStateException`.

**Example - Conflicting External ID Fields (Invalid):**
```apex
// This will throw an IllegalStateException
Account account1 = new Account(Name = 'Account 1', ExternalId__c = 'EXT-001');
Account account2 = new Account(Name = 'Account 2', AlternateExternalId__c = 'ALT-001');

DML_Builder.newTransaction()
	.doUpsert(account1, Account.ExternalId__c)
	.doUpsert(account2, Account.AlternateExternalId__c) // Throws IllegalStateException!
	.execute();

// Error: Cannot use different external ID fields for the same SObjectType in a single transaction
```

### Mixed Operations

Combine inserts, updates, and deletes in a single transaction.

**Example:**
```apex
// Mixed DML operations with error handling
try
{
	Account newAccount = new Account(Name = 'New Account');

	Account existingAccount = (Account)QRY_Builder.selectFrom(Account.SObjectType)
		.fields(new List<SObjectField>{Account.Id, Account.Name})
		.withLimit(1)
		.getFirst();
	existingAccount.Name = 'Updated Account';

	Account oldAccount = (Account)QRY_Builder.selectFrom(Account.SObjectType)
		.fields(new List<SObjectField>{Account.Id})
		.condition(Account.CreatedDate).lessThan(Date.today().addYears(-1))
		.withLimit(1)
		.getFirst();

	DML_Builder.newTransaction()
		.doInsert(newAccount)
		.doUpdate(existingAccount)
		.doDelete(oldAccount)
		.execute();
}
catch(Exception error)
{
	LOG_Builder.build().error(error).emitAt('MyClass.commitChanges');
	// All changes are rolled back automatically
}
```

---

## Bulk DML Operations ([`DML_Builder`](reference/apex/DML_Builder.md))

### Insert Operations

[Insert](https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/langCon_apex_dml_examples_insert.htm) single or multiple records with sharing control.

**Example:**
```apex
// Bulk insert with error handling
List<Account> accounts = new List<Account>();
for(Integer i = 0; i < 200; i++)
{
	accounts.add(new Account(Name = 'Bulk Account ' + i, Industry = 'Technology'));
}

// Insert with partial commit allowed
DML_Builder.newTransaction()
	.doInsert(accounts)
	.allowPartial()
	.execute();
```

### Update Operations

[Update](https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/langCon_apex_dml_examples_update.htm) existing records with sharing control.

**Example:**
```apex
// Bulk update with sharing enforced
List<Account> accounts = QRY_Builder.selectFrom(Account.SObjectType)
	.fields(new List<SObjectField>{Account.Id, Account.Name, Account.Industry})
	.condition(Account.Industry).equals('Technology')
	.withLimit(200)
	.toList();

for(Account account : accounts)
{
	account.Industry = 'Software';
	account.Description = 'Updated via bulk operation';
}

// Enforce sharing for update operation
DML_Builder.newTransaction()
	.doUpdate(accounts)
	.execute();
```

### Delete Operations

[Delete](https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/langCon_apex_dml_examples_delete.htm) records with sharing control.

**Example:**
```apex
// Bulk delete with permission check
// Check delete permission first
FLOW_CheckObjectPermissions.DTO_Request request = new FLOW_CheckObjectPermissions.DTO_Request();
request.objectApiName = 'Contact';

List<FLOW_CheckObjectPermissions.DTO_Response> permissions =
	FLOW_CheckObjectPermissions.checkPermissions(new List<FLOW_CheckObjectPermissions.DTO_Request>{request});

if(permissions[0].hasDeleteAccess)
{
	List<Contact> contactsToDelete = QRY_Builder.selectFrom(Contact.SObjectType)
		.fields(new List<SObjectField>{Contact.Id})
		.condition(Contact.Email).contains('@test.com')
		.withLimit(100)
		.toList();

	DML_Builder.newTransaction()
		.doDelete(contactsToDelete)
		.allowPartial()
		.execute();
}
else
{
	LOG_Builder.build().error('User does not have delete permission').emitAt('MyClass.deleteContacts');
}
```

### Upsert Operations

Insert or update records based on external ID or record Id. The external ID field determines how records are matched for updates.

**Basic Upsert (by Record Id):**
```apex
// Upsert using record Id for matching (default behavior)
List<Account> accounts = new List<Account>
{
	new Account(Name = 'New Account'),  // No Id - will insert
	new Account(Id = existingId, Name = 'Updated Account')  // Has Id - will update
};

DML_Builder.newTransaction()
	.doUpsert(accounts)
	.execute();
```

**Upsert with External ID Field:**
```apex
// Bulk upsert using external ID field for matching
List<Account> accounts = new List<Account>
{
	new Account(Name = 'Account 1', ExternalId__c = 'EXT-001'),
	new Account(Name = 'Account 2', ExternalId__c = 'EXT-002'),
	new Account(Name = 'Account 3', ExternalId__c = 'EXT-003')
};

// First upsert creates new records (no matching external IDs exist)
DML_Builder.newTransaction()
	.doUpsert(accounts, Account.ExternalId__c)
	.execute();

// Modify and upsert again - will update existing records
for(Account account : accounts)
{
	account.Industry = 'Technology';
}

DML_Builder.newTransaction()
	.doUpsert(accounts, Account.ExternalId__c)
	.execute();
```

**Upsert with Sharing Enforcement:**
```apex
// External ID upsert with sharing rules enforced
DML_Builder.newTransaction()
	.doUpsert(accounts, Account.ExternalId__c)
	.execute();
```

### Undelete Operations

Restore previously deleted records.

**Example:**
```apex
// Undelete soft-deleted records
List<Account> deletedAccounts = QRY_Builder.selectFrom(Account.SObjectType)
	.fields(new List<SObjectField>{Account.Id, Account.Name})
	.condition(Account.IsDeleted).equals(true)
	.allRows()
	.toList();

if(!deletedAccounts.isEmpty())
{
	DML_Builder.newTransaction()
		.doUndelete(deletedAccounts)
		.execute();
}
```

---

## Sharing Enforcement

### Context-Driven Sharing

Each `DML_Builder` chain inherits the calling class's sharing context by default. Combine explicit class-level
sharing declarations (`with sharing` for user-facing code, `without sharing` for system maintenance) with the
per-call fluent methods (`.bypassSharing()`, `.withUserMode()`, `.withSystemMode()`) for precise, auditable
control.

**Example:**
```apex
// USER_MODE default + with-sharing class for community/portal contexts
public with sharing class CommunityAccountController
{
	public void createAccount(String accountName)
	{
		Account account = new Account(Name = accountName);
		DML_Builder.newTransaction()
			.doInsert(account)
			.execute();
	}

	public void updateAccount(Id accountId, String newName)
	{
		Account account = new Account(Id = accountId, Name = newName);
		DML_Builder.newTransaction()
			.doUpdate(account)
			.execute();
	}
}

// In a system-level batch or trigger
public without sharing class SystemBatchProcess implements Database.Batchable<SObject>
{
	public void execute(Database.BatchableContext context, List<SObject> scope)
	{
		// Bypass sharing for system operations
		DML_Builder.newTransaction()
			.doUpdate(scope)
			.bypassSharing()
			.execute();
	}
}
```

### Operation-Level Sharing

`DML_Builder` defaults to `AccessLevel.USER_MODE` (CRUD + FLS + sharing enforced at the database level). Use
`.bypassSharing()` to route through the `without sharing` proxy, or `.withSystemMode()` to bypass CRUD / FLS
entirely for framework-internal writes.

### Access Mode (USER_MODE / SYSTEM_MODE)

Subscriber-reachable DML calls default to `AccessLevel.USER_MODE` — the running user's FLS and CRUD are enforced
on every insert/update/delete/upsert/undelete. The default is driven by the `FeatureFlag.UserModeDml_Enabled`
custom metadata record (`IsEnabledByDefault__c = true`).

**Force a specific mode:**

```apex
// Force USER_MODE (subscriber-reachable DML enforcing the running user's FLS)
DML_Builder.newTransaction()
	.withUserMode()
	.doInsert(record)
	.execute();

// Force SYSTEM_MODE (framework-internal writes — logs, orchestration records, etc.)
DML_Builder.newTransaction()
	.withSystemMode()
	.doInsert(logEntry)
	.execute();
```

**Emergency kill-switch:** flip `FeatureFlag.UserModeDml_Enabled.IsEnabledByDefault__c` to `false` via metadata
deploy. Takes effect on next transaction — every call without explicit `.withUserMode()` / `.withSystemMode()`
reverts to `AccessLevel.SYSTEM_MODE`. See [Security Guide — Secure-by-Default Defaults](Security%20-%20Guide.md#secure-by-default-defaults).


**Example:**
```apex
// Operation-level sharing control
Account account = new Account(Name = 'Test Account');
Contact contact = new Contact(FirstName = 'Test', LastName = 'User');

DML_Builder.newTransaction()
	.doInsert(account)
	.doInsert(contact, Contact.AccountId, account)
	.execute();
```

### Bypass vs Enforce vs Inherited

Understanding the three sharing modes.

**Example:**
```apex
// Sharing mode examples
List<Account> accounts = new List<Account>{new Account(Name = 'Test')};

// BYPASS: Routes DML through the `without sharing` proxy (sharing rules ignored)
DML_Builder.newTransaction()
	.doInsert(accounts)
	.bypassSharing()
	.execute();
// User can insert records they normally could not access

// DEFAULT: USER_MODE (CRUD + FLS + sharing enforced at the database level)
// via the `UserModeDml_Enabled` feature flag shipped `true`
DML_Builder.newTransaction()
	.doInsert(accounts)
	.execute();
// Inserts fail if the running user lacks CRUD, FLS, or sharing access
```

---

## Permission Checking ([`FLOW_CheckObjectPermissions`](reference/apex/FLOW_CheckObjectPermissions.md))

### Object-Level Permissions

Check user [permissions](https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_classes_perms_enforcing.htm) before DML operations.

**Example:**
```apex
// Check object permissions before DML
public static void safeCreateAccount(String accountName)
{
	// Check permissions first
	FLOW_CheckObjectPermissions.DTO_Request request = new FLOW_CheckObjectPermissions.DTO_Request();
	request.objectApiName = 'Account';

	List<FLOW_CheckObjectPermissions.DTO_Response> permissions =
		FLOW_CheckObjectPermissions.checkPermissions(
			new List<FLOW_CheckObjectPermissions.DTO_Request>{request}
		);

	FLOW_CheckObjectPermissions.DTO_Response accountPerms = permissions[0];

	if(accountPerms.hasCreateAccess)
	{
		Account account = new Account(Name = accountName);
		DML_Builder.newTransaction().doInsert(account).execute();
	}
	else
	{
		throw new SecurityException('User does not have permission to create Account records');
	}
}
```

### Before DML Checks

Validate permissions for multiple operations.

**Example:**
```apex
// Check all CRUD permissions
public with sharing class AccountManager
{
	private FLOW_CheckObjectPermissions.DTO_Response accountPermissions;

	public AccountManager()
	{
		// Check permissions once during initialization
		FLOW_CheckObjectPermissions.DTO_Request request = new FLOW_CheckObjectPermissions.DTO_Request();
		request.objectApiName = 'Account';

		List<FLOW_CheckObjectPermissions.DTO_Response> results =
			FLOW_CheckObjectPermissions.checkPermissions(
				new List<FLOW_CheckObjectPermissions.DTO_Request>{request}
			);

		accountPermissions = results[0];
	}

	public void createAccount(Account account)
	{
		if(!accountPermissions.hasCreateAccess)
		{
			throw new SecurityException('No create permission');
		}
		DML_Builder.newTransaction().doInsert(account).execute();
	}

	public void updateAccount(Account account)
	{
		if(!accountPermissions.hasEditAccess)
		{
			throw new SecurityException('No edit permission');
		}
		DML_Builder.newTransaction().doUpdate(account).execute();
	}

	public void deleteAccount(Account account)
	{
		if(!accountPermissions.hasDeleteAccess)
		{
			throw new SecurityException('No delete permission');
		}
		DML_Builder.newTransaction().doDelete(account).execute();
	}
}
```

### Field-Level Security

Check [field-level access](https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_classes_perms_enforcing.htm) using describe methods.

**Example:**
```apex
// Check field-level security
public static Boolean canUpdateAccountRevenue()
{
	DescribeFieldResult fieldDescribe = Account.AnnualRevenue.getDescribe();
	return fieldDescribe.isUpdateable();
}

public static void safeUpdateRevenue(Id accountId, Decimal newRevenue)
{
	if(!canUpdateAccountRevenue())
	{
		throw new SecurityException('User cannot update AnnualRevenue field');
	}

	Account account = new Account(Id = accountId, AnnualRevenue = newRevenue);
	DML_Builder.newTransaction().doUpdate(account).execute();
}
```

---

## Test Data Factory

### [TST_Builder](reference/apex/TST_Builder.md)

The [`TST_Builder`](reference/apex/TST_Builder.md) provides a powerful, fluent builder pattern for creating test data in Apex tests. It automatically handles required fields, supports complex parent-child relationships, and offers fine-grained control over field population.

**Key Features:**
- **Automatic Required Field Population** - Framework automatically fills required fields with valid defaults
- **Flexible Field Overrides** - Override specific fields using String names or type-safe SObjectField tokens
- **Bulk Record Creation** - Create multiple records efficiently with `withCount()` and `buildList()`
- **Parent-Child Relationships** - Build complex object graphs with automatic foreign key assignment
- **Record Type Support** - Set record types using developer names
- **Optional/Defaulted Field Control** - Fine-tune which optional fields get populated
- **Customizable** - Extend default value generation for custom requirements

---

### Basic Usage

Create a single record with all required fields automatically populated:

```apex
@IsTest
private static void testBasicAccountCreation()
{
	Test.startTest();

	// Create and insert account with auto-generated required fields
	Account account = (Account)TST_Builder.of(Account.SObjectType).build();

	Test.stopTest();

	Assert.isNotNull(account.Id, 'Account should be inserted');
	Assert.isNotNull(account.Name, 'Required field should be auto-populated');
}
```

Create without database insertion:

```apex
@IsTest
private static void testInMemoryAccount()
{
	Test.startTest();

	// Create account in memory only (no DML)
	Account account = (Account)TST_Builder.of(Account.SObjectType)
		.withoutInsertion()
		.build();

	Test.stopTest();

	Assert.isNull(account.Id, 'Account should not be inserted');
	Assert.isNotNull(account.Name, 'Required fields still populated');
}
```

---

### Field Overrides

Override specific fields using **String field names** or **type-safe SObjectField tokens**:

**Single Field Override:**
```apex
@IsTest
private static void testFieldOverrides()
{
	Test.startTest();

	// Using SObjectField tokens (recommended - compile-time safety)
	Account account = (Account)TST_Builder.of(Account.SObjectType)
		.withOverride(Account.Name, 'ACME Corp')
		.withOverride(Account.Industry, 'Technology')
		.withOverride(Account.AnnualRevenue, 1000000)
		.build();

	Test.stopTest();

	Assert.areEqual('ACME Corp', account.Name);
	Assert.areEqual('Technology', account.Industry);
	Assert.areEqual(1000000, account.AnnualRevenue);
}
```

**Multiple Field Overrides:**
```apex
@IsTest
private static void testBulkOverrides()
{
	Test.startTest();

	// Using Map for multiple overrides
	Account account = (Account)TST_Builder.of(Account.SObjectType)
		.withOverrides(new Map<SObjectField, Object>
		{
			Account.Name => 'Test Account',
			Account.Phone => '555-1234',
			Account.Industry => 'Finance',
			Account.NumberOfEmployees => 500
		})
		.build();

	Test.stopTest();

	Assert.areEqual('Test Account', account.Name);
	Assert.areEqual('555-1234', account.Phone);
}
```

**String-Based Overrides** (when SObjectField tokens aren't available):
```apex
Contact contact = (Contact)TST_Builder.of(Contact.SObjectType)
	.withOverride('FirstName', 'John')
	.withOverride('LastName', 'Doe')
	.withOverrides(new Map<String, Object>{'Email' => 'john@example.com'})
	.build();
```

---

### Bulk Record Creation

Use `withCount()` and `buildList()` to create multiple records efficiently:

```apex
@IsTest
private static void testBulkCreation()
{
	Test.startTest();

	// Create and insert 200 accounts in bulk
	List<Account> accounts = (List<Account>)TST_Builder.of(Account.SObjectType)
		.withCount(200)
		.withOverride(Account.Industry, 'Technology')
		.buildList();

	Test.stopTest();

	Assert.areEqual(200, accounts.size());
	Assert.isNotNull(accounts[0].Id, 'Records should be inserted');
	Assert.areEqual('Technology', accounts[0].Industry);
}
```

**Pattern for Custom Bulk Data:**
```apex
@IsTest
private static void testCustomBulkData()
{
	Integer numberOfAccounts = 100;
	List<Account> accounts = new List<Account>();

	Test.startTest();

	// Create records in memory with custom values per record
	for(Integer i = 0; i < numberOfAccounts; i++)
	{
		Account account = (Account)TST_Builder.of(Account.SObjectType)
			.withOverrides(new Map<SObjectField, Object>
			{
				Account.Name => 'Account ' + i,
				Account.AnnualRevenue => 100000 * i
			})
			.withoutInsertion()
			.build();
		accounts.add(account);
	}

	// Insert all at once using DML_Builder
	DML_Builder.newTransaction().doInsert(accounts).execute();

	Test.stopTest();

	Assert.areEqual(numberOfAccounts, accounts.size());
}
```

---

### Record Type Support

Set record types using developer names:

```apex
@IsTest
private static void testRecordType()
{
	Test.startTest();

	Account account = (Account)TST_Builder.of(Account.SObjectType)
		.withRecordType('Enterprise_Account')
		.withOverride(Account.Name, 'Enterprise Corp')
		.build();

	Test.stopTest();

	Assert.isNotNull(account.RecordTypeId);
	// Verify it's the correct record type
	RecordType recordType = (RecordType)QRY_Builder.selectFrom(RecordType.SObjectType)
		.fields(new List<SObjectField>{RecordType.DeveloperName})
		.condition(RecordType.Id).equals(account.RecordTypeId)
		.getFirst();
	Assert.areEqual('Enterprise_Account', recordType.DeveloperName);
}
```

**Error Handling:**
```apex
try
{
	TST_Builder.of(Account.SObjectType)
		.withRecordType('NonExistent_RecordType')
		.build();
	Assert.fail('Should throw IllegalArgumentException');
}
catch(Exception error)
{
	Assert.isInstanceOfType(error, IllegalArgumentException.class, 'Incorrect Exception Type');
}
```

---

### Parent-Child Relationships

Build complex object graphs with automatic foreign key assignment. The framework supports multiple patterns for creating parent-child relationships.

#### Pattern 1: Simple Child Creation (No Field Overrides)

```apex
@IsTest
private static void testSimpleChildren()
{
	Test.startTest();

	// Create account with 3 contacts (all fields auto-defaulted)
	Account account = (Account)TST_Builder.of(Account.SObjectType)
		.withOverride(Account.Name, 'Parent Account')
		.withChildren(Contact.SObjectType, 3)
		.build();

	Test.stopTest();

	Assert.isNotNull(account.Id);
	List<Contact> contacts = QRY_Builder.selectFrom(Contact.SObjectType)
		.fields(new List<SObjectField>{Contact.Id, Contact.AccountId})
		.condition(Contact.AccountId).equals(account.Id)
		.toList();
	Assert.areEqual(3, contacts.size(), 'Should have 3 child contacts');
	Assert.areEqual(account.Id, contacts[0].AccountId, 'Foreign key should be set');
}
```

#### Pattern 2: Children with Field Overrides

```apex
@IsTest
private static void testChildrenWithOverrides()
{
	Test.startTest();

	// Create account with 2 contacts with specific field values
	Account account = (Account)TST_Builder.of(Account.SObjectType)
		.withOverride(Account.Name, 'ACME Corp')
		.withChildren(Contact.SObjectType, 2, new Map<SObjectField, Object>
		{
			Contact.FirstName => 'John',
			Contact.LastName => 'Smith',
			Contact.Email => 'john.smith@acme.com'
		})
		.build();

	Test.stopTest();

	List<Contact> contacts = QRY_Builder.selectFrom(Contact.SObjectType)
		.fields(new List<SObjectField>{Contact.FirstName, Contact.LastName, Contact.Email})
		.condition(Contact.AccountId).equals(account.Id)
		.toList();
	Assert.areEqual(2, contacts.size());
	Assert.areEqual('John', contacts[0].FirstName);
	Assert.areEqual('Smith', contacts[0].LastName);
}
```

#### Pattern 3: Children Using Builder (Complex Configuration)

```apex
@IsTest
private static void testChildrenWithBuilder()
{
	Test.startTest();

	// Create account with opportunities using nested builder for complex config
	Account account = (Account)TST_Builder.of(Account.SObjectType)
		.withOverride(Account.Name, 'Sales Account')
		.withChildren(
			TST_Builder.of(Opportunity.SObjectType)
				.withCount(5)
				.withOverride(Opportunity.StageName, 'Prospecting')
				.withOverride(Opportunity.CloseDate, Date.today().addDays(30))
				.withDefaultedField(Opportunity.Description) // Force optional field population
		)
		.build();

	Test.stopTest();

	List<Opportunity> opportunities = QRY_Builder.selectFrom(Opportunity.SObjectType)
		.fields(new List<SObjectField>{Opportunity.Id, Opportunity.StageName, Opportunity.AccountId})
		.condition(Opportunity.AccountId).equals(account.Id)
		.toList();
	Assert.areEqual(5, opportunities.size());
	Assert.areEqual('Prospecting', opportunities[0].StageName);
}
```

#### Pattern 4: Multiple Child Types

```apex
@IsTest
private static void testMultipleChildTypes()
{
	Test.startTest();

	// Create account with both contacts and opportunities
	Account account = (Account)TST_Builder.of(Account.SObjectType)
		.withOverride(Account.Name, 'Multi-Child Account')
		.withChildren(Contact.SObjectType, 3, new Map<SObjectField, Object>
		{
			Contact.LastName => 'Contact'
		})
		.withChildren(Opportunity.SObjectType, 2, new Map<SObjectField, Object>
		{
			Opportunity.StageName => 'Closed Won',
			Opportunity.CloseDate => Date.today()
		})
		.build();

	Test.stopTest();

	List<Contact> contacts = QRY_Builder.selectFrom(Contact.SObjectType)
		.fields(new List<SObjectField>{Contact.Id})
		.condition(Contact.AccountId).equals(account.Id)
		.toList();
	List<Opportunity> opportunities = QRY_Builder.selectFrom(Opportunity.SObjectType)
		.fields(new List<SObjectField>{Opportunity.Id})
		.condition(Opportunity.AccountId).equals(account.Id)
		.toList();

	Assert.areEqual(3, contacts.size());
	Assert.areEqual(2, opportunities.size());
}
```

#### Pattern 5: Explicit Relationship Name (Edge Cases)

For objects with **multiple lookup relationships** to the same parent type:

```apex
@IsTest
private static void testExplicitRelationshipName()
{
	Test.startTest();

	// Custom object with two lookups to Contact: PrimaryContact__c and SecondaryContact__c
	// Must specify explicit relationship name when there are multiple relationships
	Foobar__c foobar = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
		.withOverride(Foobar__c.Name, 'Test')
		.withChildren('PrimaryContacts__r',
			TST_Builder.of(Contact.SObjectType).withCount(2)
		)
		.withChildren('SecondaryContacts__r',
			TST_Builder.of(Contact.SObjectType).withCount(1)
		)
		.build();

	Test.stopTest();
}
```

#### In-Memory Parent-Child Graphs (No DML)

```apex
@IsTest
private static void testInMemoryGraph()
{
	Test.startTest();

	// Create entire graph in memory without database insertion
	Account account = (Account)TST_Builder.of(Account.SObjectType)
		.withOverride(Account.Name, 'Test Account')
		.withChildren(Contact.SObjectType, 2, new Map<SObjectField, Object>
		{
			Contact.LastName => 'Smith'
		})
		.withoutInsertion()
		.build();

	Test.stopTest();

	Assert.isNull(account.Id, 'Parent should not be inserted');
	Assert.areEqual(2, account.Contacts.size(), 'Should have 2 contacts in memory');
	Assert.areEqual('Smith', account.Contacts[0].LastName);
	Assert.isNull(account.Contacts[0].Id, 'Children should not be inserted');
}
```

#### Bulk Parents with Children

```apex
@IsTest
private static void testBulkParentsWithChildren()
{
	Test.startTest();

	// Create 10 accounts, each with 3 contacts
	List<Account> accounts = (List<Account>)TST_Builder.of(Account.SObjectType)
		.withCount(10)
		.withOverride(Account.Name, 'Bulk Parent')
		.withChildren(Contact.SObjectType, 3, new Map<SObjectField, Object>
		{
			Contact.LastName => 'Child'
		})
		.buildList();

	Test.stopTest();

	Assert.areEqual(10, accounts.size());

	// Verify each account has 3 contacts
	Set<Id> accountIds = new Map<Id, Account>(accounts).keySet();
	List<Contact> allContacts = QRY_Builder.selectFrom(Contact.SObjectType)
		.fields(new List<SObjectField>{Contact.Id, Contact.AccountId})
		.condition(Contact.AccountId).isIn(new List<Id>(accountIds))
		.toList();

	// Group contacts by account to verify counts
	Map<Id, List<Contact>> contactsByAccount = new Map<Id, List<Contact>>();
	for(Contact contact : allContacts)
	{
		if(!contactsByAccount.containsKey(contact.AccountId))
		{
			contactsByAccount.put(contact.AccountId, new List<Contact>());
		}
		contactsByAccount.get(contact.AccountId).add(contact);
	}

	for(Account account : accounts)
	{
		Assert.areEqual(3, contactsByAccount.get(account.Id).size(), 'Each account should have 3 contacts');
	}
}
```

---

### Optional and Defaulted Fields

Control which optional fields get populated automatically:

#### Force Optional Fields to be Populated

```apex
@IsTest
private static void testDefaultedFields()
{
	Test.startTest();

	// Force Description (optional field) to be auto-populated
	Account account = (Account)TST_Builder.of(Account.SObjectType)
		.withOverride(Account.Name, 'Test Account')
		.withDefaultedField(Account.Description)
		.withDefaultedField(Account.Website)
		.build();

	Test.stopTest();

	Assert.isNotNull(account.Description, 'Optional field should be populated');
	Assert.isNotNull(account.Website, 'Optional field should be populated');
}
```

**Using List:**
```apex
Account account = (Account)TST_Builder.of(Account.SObjectType)
	.withDefaultedFields(new List<Object>
	{
		Account.Description,
		Account.Industry,
		Account.Website
	})
	.build();
```

#### Multi-Level Relationship Paths

Use dot notation to automatically populate fields in parent or grandparent relationships. The framework accepts both **relationship names** (e.g., `'Account.Parent'`) and **field names** (e.g., `'AccountId.ParentId'`) interchangeably:

```apex
@IsTest
private static void testMultiLevelRelationships()
{
	Test.startTest();

	// Using relationship names (traditional style)
	Contact contact1 = (Contact)TST_Builder.of(Contact.SObjectType)
		.withDefaultedField('Account.Parent.Name')  // Account -> Parent Account -> Name
		.build();

	// Using field names (also supported)
	Contact contact2 = (Contact)TST_Builder.of(Contact.SObjectType)
		.withDefaultedField('AccountId.ParentId.Name')  // Same result as above
		.build();

	// Mixed format also works
	Contact contact3 = (Contact)TST_Builder.of(Contact.SObjectType)
		.withDefaultedField('AccountId.Parent.Name')  // Field name + relationship name
		.build();

	Test.stopTest();

	// All three create the same hierarchy: Contact -> Account -> Parent Account
	Assert.isNotNull(contact1.Account.ParentId, 'Parent Account should be created');
	Assert.isNotNull(contact1.Account.Parent.Name, 'Parent Account Name should be populated');
}
```

**Custom Lookup Fields:**
```apex
// For custom lookups, both formats work
// Relationship name: Lookup__r.Lookup__r.Name
// Field name: Lookup__c.Lookup__c.Name

Foobar__c record = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
	.withDefaultedField('Lookup__c.Lookup__c.Name')  // Using field names
	.build();
```

**Polymorphic Fields:**

Polymorphic lookup fields (fields that can reference multiple object types, like `OwnerId` which can be User or Queue) are automatically skipped. The framework logs an informational message when this occurs:

```apex
@IsTest
private static void testPolymorphicFieldHandling()
{
	// OwnerId is polymorphic (can be User or Queue)
	// The framework will skip it and log an info message
	Case caseRecord = (Case)TST_Builder.of(Case.SObjectType)
		.withDefaultedField(Case.OwnerId)  // Skipped - polymorphic
		.withDefaultedField(Case.AccountId)  // Populated normally
		.build();

	// OwnerId is not auto-populated due to polymorphism
	// Use withOverride() to set an explicit value if needed
	Case caseWithOwner = (Case)TST_Builder.of(Case.SObjectType)
		.withOverride(Case.OwnerId, UserInfo.getUserId())  // Explicit value
		.build();
}
```

#### Mark Required Fields as Optional

Prevent the framework from auto-populating specific fields:

```apex
@IsTest
private static void testOptionalFields()
{
	Test.startTest();

	// Prevent BusinessHoursId (normally auto-populated) from being set
	Case caseRecord = (Case)TST_Builder.of(Case.SObjectType)
		.withOptionalField(Case.BusinessHoursId)
		.withoutInsertion()
		.build();

	Test.stopTest();

	Assert.isNull(caseRecord.BusinessHoursId, 'Field marked optional should be null');
}
```

**Using List:**
```apex
Case caseRecord = (Case)TST_Builder.of(Case.SObjectType)
	.withOptionalFields(new List<Object>
	{
		Case.BusinessHoursId,
		Case.EntitlementId
	})
	.withoutInsertion()
	.build();
```

**Global Optional Fields** (transaction-wide):
```apex
@IsTest
private static void testGlobalOptionalFields()
{
	// Mark Phone as optional for ALL builds in this transaction
	TST_Builder.optionalFields.add('Phone');

	Account account1 = (Account)TST_Builder.of(Account.SObjectType)
		.withoutInsertion()
		.build();

	Account account2 = (Account)TST_Builder.of(Account.SObjectType)
		.withoutInsertion()
		.build();

	Assert.isNull(account1.Phone);
	Assert.isNull(account2.Phone);
}
```

---

### Advanced Features

#### Mock ID Generation for Query Mocking

Use `withoutInsertion(true)` to create records with auto-generated mock IDs without database insertion. This is essential when using the Query Mocking feature in tests.

**Difference between `withoutInsertion()` and `withoutInsertion(true)`:**

| Method | ID Generated | Use Case |
|--------|--------------|----------|
| `withoutInsertion()` | No (null) | Simple in-memory objects for unit testing |
| `withoutInsertion(true)` | Yes (mock ID) | Query mocking, code that requires valid IDs |

**Example - Creating mock records with IDs:**

```apex
@IsTest
private static void testMockIdGeneration()
{
	Test.startTest();

	// withoutInsertion() - No ID generated
	Account accountNoId = (Account)TST_Builder.of(Account.SObjectType)
		.withOverride(Account.Name, 'No ID Account')
		.withoutInsertion()
		.build();

	Assert.isNull(accountNoId.Id, 'ID should be null');

	// withoutInsertion(true) - Mock ID generated
	Account accountWithMockId = (Account)TST_Builder.of(Account.SObjectType)
		.withOverride(Account.Name, 'Mock ID Account')
		.withoutInsertion(true)
		.build();

	Assert.isNotNull(accountWithMockId.Id, 'Mock ID should be generated');
	Assert.areEqual(18, accountWithMockId.Id.length(), 'Should be valid 18-char ID');

	Test.stopTest();
}
```

**Using with Query Mocking:**

```apex
@IsTest
private static void testWithQueryMocking()
{
	// Create mock records with IDs for query mocking
	List<Account> mockAccounts = new List<Account>();
	for(Integer i = 0; i < 5; i++)
	{
		Account mockAccount = (Account)TST_Builder.of(Account.SObjectType)
			.withOverrides(new Map<SObjectField, Object>
			{
				Account.Name => 'Mock Account ' + i,
				Account.Industry => 'Technology'
			})
			.withoutInsertion(true) // Generate mock ID
			.build();
		mockAccounts.add(mockAccount);
	}

	// Configure query mock (see Selectors - Guide for full details)
	QRY_Builder.setMock(Account.SObjectType, mockAccounts);

	Test.startTest();
	// All QRY_Builder calls for Account now return mock data
	List<Account> results = QRY_Builder.selectFrom(Account.SObjectType)
		.fields(new List<SObjectField>{Account.Name, Account.Industry})
		.toList();
	Test.stopTest();

	Assert.areEqual(5, results.size());
	Assert.isNotNull(results[0].Id, 'Mock records have IDs');

	// Cleanup
	QRY_Builder.clearMocks();
}
```

**When to use `withoutInsertion(true)`:**
- Query mocking scenarios (records need realistic IDs)
- Testing code that validates `record.Id != null`
- Creating records for Map keys or Set membership based on Id
- Testing relationship lookups where foreign key Ids are required

**See Also:** [Selectors - Guide](Selectors%20-%20Guide.md#testing) for complete Query Mocking documentation.

---

#### Auto-Default Marker

Use `autoDefaultFieldValueProvider` to request automatic value generation within override maps:

```apex
Account account = (Account)TST_Builder.of(Account.SObjectType)
	.withOverrides(new Map<String, Object>
	{
		'Name' => 'Test Account',
		'Description' => TST_Builder.autoDefaultFieldValueProvider // Auto-generate value
	})
	.withoutInsertion()
	.build();

Assert.isNotNull(account.Description, 'Auto-default marker triggers value generation');
```

#### Custom Default Value Provider

Extend [`TST_Builder.DefaultValueProvider`](reference/apex/TST_Builder.DefaultValueProvider.md) to customize default value generation:

```apex
public inherited sharing class CustomDefaultProvider extends TST_Builder.DefaultValueProvider
{
	public override Map<String, TST_Builder.DefaultFieldValueProvider> getDefaultMapOfValues(
		SObjectType sObjectType,
		Map<String, Object> mapOfValuesOverride)
	{
		Map<String, TST_Builder.DefaultFieldValueProvider> defaults = super.getDefaultMapOfValues(sObjectType, mapOfValuesOverride);

		// Custom logic: Always use specific domain for email fields
		if(sObjectType == Contact.SObjectType)
		{
			defaults.put('Email', new StaticValueProvider('test@mycustomdomain.com'));
		}

		return defaults;
	}
}

// In test setup
TST_Builder.defaultValueProvider = new CustomDefaultProvider();
```

#### Custom Factory Provider

Implement a custom factory provider for complete control over record creation (advanced):

```apex
public inherited sharing class CustomFactoryProvider implements TST_Builder.FactoryProvider
{
	public TST_Builder.Factory createFactory(SObjectType sObjectType)
	{
		// Return custom factory implementation
		return new MyCustomFactory(sObjectType);
	}
}

// In test setup
TST_Builder.factoryProvider = new CustomFactoryProvider();
```

---

### Complete Example

A comprehensive example demonstrating multiple features:

```apex
@IsTest
private static void testCompleteExample()
{
	Test.startTest();

	// Create account with:
	// - Specific record type
	// - Field overrides
	// - Optional field population
	// - Multiple child types
	Account account = (Account)TST_Builder.of(Account.SObjectType)
		.withRecordType('Enterprise_Account')
		.withOverrides(new Map<SObjectField, Object>
		{
			Account.Name => 'Enterprise Corp',
			Account.Industry => 'Technology',
			Account.AnnualRevenue => 5000000
		})
		.withDefaultedField(Account.Description)
		.withDefaultedField(Account.Website)
		.withChildren(Contact.SObjectType, 3, new Map<SObjectField, Object>
		{
			Contact.LastName => 'Executive',
			Contact.Department => 'Leadership'
		})
		.withChildren(
			TST_Builder.of(Opportunity.SObjectType)
				.withCount(2)
				.withOverride(Opportunity.StageName, 'Prospecting')
				.withOverride(Opportunity.CloseDate, Date.today().addDays(30))
				.withDefaultedField(Opportunity.Description)
		)
		.build();

	Test.stopTest();

	// Verify parent
	Assert.isNotNull(account.Id);
	Assert.areEqual('Enterprise Corp', account.Name);
	Assert.isNotNull(account.Description, 'Optional field should be populated');

	// Verify children
	List<Contact> contacts = QRY_Builder.selectFrom(Contact.SObjectType)
		.fields(new List<SObjectField>{Contact.Id, Contact.LastName})
		.condition(Contact.AccountId).equals(account.Id)
		.toList();
	List<Opportunity> opportunities = QRY_Builder.selectFrom(Opportunity.SObjectType)
		.fields(new List<SObjectField>{Opportunity.Id, Opportunity.StageName})
		.condition(Opportunity.AccountId).equals(account.Id)
		.toList();

	Assert.areEqual(3, contacts.size());
	Assert.areEqual('Executive', contacts[0].LastName);
	Assert.areEqual(2, opportunities.size());
	Assert.areEqual('Prospecting', opportunities[0].StageName);
}
```

---

## Bulk Utilities (`UTIL_BulkUpdates` & `UTIL_PurgeRecords`)

### Bulk Field Updates

`UTIL_BulkUpdates` provides utility methods for batch updating fields across multiple records.

**Example:**
```apex
// Invalidate email fields in bulk
// Invalidate all Account email addresses
UTIL_BulkUpdates.invalidateEmailFields(Account.PersonEmail);

// Invalidate Contact emails with custom batch size
UTIL_BulkUpdates.invalidateEmailFields(Contact.Email, 200);

// Invalidate with all-or-nothing transaction control
UTIL_BulkUpdates.invalidateEmailFields('Lead', 'Email', 100, true);
```

**Bulk Owner Updates:**
```apex
// Update record ownership in bulk
UTIL_BulkUpdates.updateOwner('Account', 'Support Rep', 'jane.smith@example.com', 200, true);
```

**Generic Field Updates:**
```apex
// Update any field with search conditions
// Archive all Closed Won opportunities with Status__c = 'Archived'
QRY_Condition.Evaluable searchConditions = new QRY_Condition.AndCondition()
	.add(new QRY_Condition.FieldCondition('StageName').equals('Closed Won'));

UTIL_BulkUpdates.updateField(
	'Opportunity',
	'Status__c',
	'Archived',
	searchConditions,
	200,
	false
);
```

**Deactivate Users in Bulk:**
```apex
// Deactivate inactive users by profile
// Deactivate users inactive for 180 days
Set<String> profiles = new Set<String>{'Standard User', 'Chatter Free User'};
UTIL_BulkUpdates.deactivateUsers(profiles, 180);

// With custom batch size and all-or-nothing
Set<String> supportProfiles = new Set<String>{'Support Rep'};
UTIL_BulkUpdates.deactivateUsers(
	supportProfiles,
	90,
	200,
	true
);
```

### Purge Records (`UTIL_PurgeRecords`)

Delete all or old records for data cleanup.

**Example:**
```apex
// Purge old records using batch processing
// Delete all test data
UTIL_PurgeRecords.deleteAllRecords(Account.SObjectType);

// Delete records older than 90 days
UTIL_PurgeRecords.deleteOlderThanNDays('Contact', 90);

// Delete records older than 30 days based on custom date field
UTIL_PurgeRecords.deleteOlderThanNDays('Task', 'ActivityDate', 30);

// Delete with specific batch size and atomicity
UTIL_PurgeRecords.deleteAllRecords('Lead', false, 200);
```

### Deactivate Users

Batch deactivate inactive users.

**Example:**
```apex
// Schedule user deactivation job
// Schedule job to deactivate users inactive for 180 days
String cronExpression = '0 0 2 * * ?'; // Daily at 2 AM

SCHED_DeactivateUsers job = new SCHED_DeactivateUsers();
job.setAttributes(new DTO_NameValues(new Map<String, String>
{
	'profileNames' => 'Standard User|Chatter Free User',
	'minimumNumberOfDays' => '180',
	'batchSize' => '200',
	'allOrNothing' => 'false'
}));

System.schedule('Deactivate Inactive Users', cronExpression, job);
```

### Batch Processing

Leverage [batch Apex](https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_batch_interface.htm) for large-scale DML operations.

**Example:**
```apex
// Custom batch for bulk updates
public with sharing class BATCH_UpdateAccountIndustry implements Database.Batchable<SObject>
{
	public Database.QueryLocator start(Database.BatchableContext context)
	{
		return QRY_Builder.selectFrom(Account.SObjectType)
			.fields(new List<SObjectField>{Account.Id, Account.Industry})
			.condition(Account.Industry).isNull()
			.toQueryLocator();
	}

	public void execute(Database.BatchableContext context, List<Account> scope)
	{
		for(Account account : scope)
		{
			account.Industry = 'Other';
		}

		// Use DML_Builder for bulk update with sharing bypass
		DML_Builder.newTransaction()
			.doUpdate(scope)
			.bypassSharing()
			.allowPartial()
			.execute();
	}

	public void finish(Database.BatchableContext context)
	{
		LOG_Builder.build().info('Batch complete').emitAt('BATCH_UpdateAccountIndustry.finish');
	}
}

// Execute batch
Database.executeBatch(new BATCH_UpdateAccountIndustry(), 200);
```

---

## Testing

Testing DML operations in KernDX relies on `TST_Builder` for test data creation and `TST_Mock` for DML-free query interception. The framework ensures that all test
records are created through the builder pattern rather than inline DML, maintaining consistency and readability.

**Testing DML_Builder operations:**

```apex
@IsTest(SeeAllData=false IsParallel=true)
private class MyService_TEST
{
	@IsTest
	private static void shouldInsertRecordsSuccessfully()
	{
		List<Foobar__c> records = (List<Foobar__c>)TST_Builder.of(Foobar__c.SObjectType)
			.withCount(3)
			.withoutInsertion()
			.buildList();

		Test.startTest();
		DML_Builder.TransactionResult result = DML_Builder.newTransaction()
			.doInsert(records)
			.execute();
		Test.stopTest();

		Assert.isTrue(result.isSuccess(), 'All records should insert successfully');
	}
}
```

**Testing transactional DML:**

```apex
@IsTest
private static void shouldCommitRelatedRecords()
{
	Foobar__c parent = (Foobar__c)TST_Builder.of(Foobar__c.SObjectType)
		.withoutInsertion()
		.build();

	Test.startTest();
	DML_Builder.newTransaction()
		.doInsert(parent)
		.execute();
	Test.stopTest();

	List<Foobar__c> inserted = QRY_Builder.selectFrom(Foobar__c.SObjectType).toList();
	Assert.areEqual(1, inserted.size(), 'One record should be committed');
}
```

**Testing with mock data (no DML):**

When testing business logic that reads data via selectors, use `TST_Mock` to register mock records. This avoids DML entirely and keeps tests fast:

```apex
@IsTest
private static void shouldProcessMockedRecords()
{
	Foobar__c mock = (Foobar__c)TST_Mock.of(Foobar__c.SObjectType)
		.withOverride(Foobar__c.Name, 'Test Record')
		.build();

	Foobar__c result = (Foobar__c)new SEL_Foobar().findById(mock.Id);

	Assert.areEqual('Test Record', result.Name, 'Should return mocked record');

	TST_Mock.clear();
}
```

---

## Capability Matrix (for Analysts)

| Capability | Control Point | Class/Method | Notes |
|---|---|---|---|
| Transactional DML | Unit of Work pattern | `DML_Builder.newTransaction()` | Commits all changes atomically |
| USER_MODE default | Database-level access enforcement | `DML_Builder` (default) | CRUD + FLS + sharing enforced; shipped via `FeatureFlag.UserModeDml_Enabled = true` |
| USER_MODE / SYSTEM_MODE (per-op) | Access-mode override | `.withUserMode()` / `.withSystemMode()` | Explicit per-transaction override of the flag-driven default |
| Access-mode kill-switch | Metadata-only emergency rollback | `FeatureFlag.UserModeDml_Enabled` | Flip `IsEnabledByDefault__c = false` to revert all DML to SYSTEM_MODE |
| Sharing enforcement (per-op) | Proxy class routing | `.bypassSharing()` | Routes through `without sharing` proxy (only meaningful in SYSTEM_MODE) |
| Async DML preserves access mode | Access-level propagation | `.async().execute()` | The chosen access mode propagates through queueable execution |
| Partial success | Error handling | `.allowPartial()` | Continues on individual record failures |
| Object permission checking | Flow invocable | `FLOW_CheckObjectPermissions` | Validates CRUD before DML in Flows |
| Field-level security | Query-level enforcement | `QRY_Builder.withUserMode()` / `.stripInaccessible()` | FLS enforcement at the query level |
| Parent-child chaining | Relationship linking | `.doInsert(child, field, parent)` | Auto-sets lookup after parent insert |

---

## Anti-Patterns

| Anti-Pattern | Why It's Wrong | Instead |
|---|---|---|
| Raw `insert`/`update`/`delete` statements | Bypasses sharing enforcement, error handling, and framework consistency | Use `DML_Builder.newTransaction().doInsert(records).execute()` |
| Separate DML calls for related objects | If the second DML fails, the first remains committed -- no rollback | Use `DML_Transaction` (Unit of Work) to commit all changes atomically |
| DML inside a loop | Hits governor limits on bulk operations | Collect records into a list, then perform a single bulk DML call |
| Ignoring `Database.SaveResult` errors | Silent failures corrupt data and hide bugs | Use `.allowPartial()` with `DML_Builder` and log failures via `LOG_Builder` |
| Performing DML in a selector or query class | Violates separation of concerns and makes the selector untestable in isolation | Keep DML in trigger actions, service classes, or controllers |

---

## Best Practices

### 1. **Use Transactional DML for Complex Transactions**

When dealing with multiple related objects, always use `DML_Builder.newTransaction()`.

**DO:**
```apex
// Use DML_Builder for related objects to maintain transactional integrity
Account account = new Account(Name = 'Test');
Contact contact = new Contact(LastName = 'Doe');

DML_Builder.newTransaction()
	.doInsert(account)
	.doInsert(contact, Contact.AccountId, account)
	.execute();
```

**DON'T:**
```apex
// Don't manually manage relationships - leads to poor error handling and inconsistency
Account account = new Account(Name = 'Test');
insert account;
Contact contact = new Contact(LastName = 'Doe', AccountId = account.Id);
insert contact; // If this fails, Account remains in database - no rollback
```

### 2. **Always Use [DML_Builder](reference/apex/DML_Builder.md) for DML**

Centralize DML operations through the framework.

**DO:**
```apex
// Use framework methods for consistent DML operations
DML_Builder.newTransaction().doInsert(account).execute();
```

**DON'T:**
```apex
// Avoid direct DML - bypasses framework's sharing and error handling capabilities
insert account; // No sharing control, no standardized error handling
```

### 3. **Be Explicit About Sharing**

Always set sharing enforcement when security is a concern.

```apex
// Explicitly control sharing enforcement for security-sensitive operations
// In public-facing code
DML_Builder.newTransaction().doInsert(records).execute();

// In system-level code
DML_Builder.newTransaction().doInsert(records).bypassSharing().execute();
```

### 4. **Check Permissions Before DML**

Validate user permissions in user-facing features.

```apex
// Check user permissions before attempting DML operations
FLOW_CheckObjectPermissions.DTO_Request request = new FLOW_CheckObjectPermissions.DTO_Request();
request.objectApiName = 'Account';
List<FLOW_CheckObjectPermissions.DTO_Response> perms =
	FLOW_CheckObjectPermissions.checkPermissions(new List<FLOW_CheckObjectPermissions.DTO_Request>{request});

if(perms[0].hasCreateAccess)
{
	// Proceed with DML
}
```

### 5. **Use [TST_Builder](reference/apex/TST_Builder.md) in Tests**

Create test data with the builder pattern for maintainability and readability.

**DO:**
```apex
// Use builder pattern with type-safe field tokens and parent-child relationships
@IsTest
private static void testMethod()
{
	// Create account with related contacts using builder
	Account account = (Account)TST_Builder.of(Account.SObjectType)
		.withOverrides(new Map<SObjectField, Object>
		{
			Account.Name => 'Test Account',
			Account.Industry => 'Technology'
		})
		.withChildren(Contact.SObjectType, 3, new Map<SObjectField, Object>
		{
			Contact.LastName => 'Test Contact'
		})
		.build();

	// Test with properly structured data
	Assert.isNotNull(account.Id);
	Integer contactCount = QRY_Builder.selectFrom(Contact.SObjectType)
		.condition(Contact.AccountId).equals(account.Id)
		.toList()
		.size();
	Assert.areEqual(3, contactCount);
}
```

**Use key builder features:**
- **Type-safe overrides** - Use `SObjectField` tokens instead of strings (e.g., `Account.Name` not `'Name'`)
- **Parent-child relationships** - Use `withChildren()` to create object graphs atomically
- **Record types** - Use `withRecordType('DeveloperName')` for record type-specific testing
- **Bulk creation** - Use `withCount()` and `buildList()` for bulk test scenarios
- **Optional field control** - Use `withDefaultedField()` or `withOptionalField()` for fine control

**DON'T:**
```apex
// Avoid manual DML and relationship management in tests
@IsTest
private static void testMethod()
{
	Account account = new Account(Name = 'Test');
	insert account; // Manual DML - verbose, no defaults

	List<Contact> contacts = new List<Contact>();
	for(Integer i = 0; i < 3; i++)
	{
		contacts.add(new Contact(LastName = 'Test', AccountId = account.Id));
	}
	insert contacts; // Separate DML - not atomic, harder to maintain
}
```

### 6. **Handle DML Errors Properly**

Always check [Database.SaveResult](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_database_saveresult.htm)/[Database.DeleteResult](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_database_deleteresult.htm) for errors.

```apex
// Always check and handle DML operation results
DML_Builder.newTransaction()
	.doInsert(accounts)
	.allowPartial()
	.execute();
```

### 7. **Use Bulk Operations**

Process records in bulk, not one at a time.

**DO:**
```apex
// Process records in bulk to avoid governor limits
List<Account> accounts = getAccountsToUpdate();
DML_Builder.newTransaction().doUpdate(accounts).execute();
```

**DON'T:**
```apex
// Don't process records individually in a loop - causes governor limit violations
for(Account account : accounts)
{
	DML_Builder.newTransaction().doUpdate(account).execute(); // GOVERNOR LIMIT VIOLATION - Too many DML statements
}
```

### 8. **Leverage Batch Apex for Large Volumes**

Use [batch processing](https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_batch_interface.htm) for operations on thousands of records.

```apex
// Use batch processing for large-scale operations
Database.executeBatch(new BATCH_ProcessRecords(), 200);
```

### 9. **Use UTIL_BulkUpdates for Common Bulk Operations**

Leverage built-in utilities for common bulk update scenarios.

**DO:**
```apex
// Use utility methods for common bulk operations
// Invalidate all Contact email addresses with built-in batch processing
UTIL_BulkUpdates.invalidateEmailFields(Contact.Email, 200);
```

**DON'T:**
```apex
// Don't reinvent the wheel with custom batch classes for common operations
// Bad: Manual query + loop + single DML (no batch processing, no error handling)
List<Contact> contacts = QRY_Builder.selectFrom(Contact.SObjectType)
	.fields(new List<SObjectField>{Contact.Id, Contact.Email})
	.condition(Contact.Email).isNotNull()
	.toList();
for(Contact contact : contacts)
{
	contact.Email = contact.Email + '.invalid';
}
update contacts; // Missing batch processing, error handling, transaction control
```

### 10. **Create Fresh Transactions**

Each `DML_Builder.newTransaction()` call creates a clean transaction context.

```apex
// Create a new transaction for each logical unit of work
DML_Builder.newTransaction()
	.doInsert(firstBatch)
	.execute();

// New transaction for separate operation
DML_Builder.newTransaction()
	.doUpdate(secondBatch)
	.execute();
```

### 11. **Document DML Operations**

All DML methods must have comprehensive ApexDoc.

```apex
/**
 * @description Creates a new account with related contacts
 *
 * @param accountName Name for the new account
 * @param contactNames List of contact last names
 *
 * @return The created Account record with Id populated
 *
 * @example
 * ```apex
 * Account account = createAccountWithContacts('Acme Corp', new List<String>{'Smith', 'Jones'});
 * ```
 */
public static Account createAccountWithContacts(String accountName, List<String> contactNames)
{
	// Implementation
}
```

### 12. **Use All-or-Nothing Appropriately**

Choose between atomic and partial commits based on requirements.

```apex
// Choose between atomic and partial commits based on business requirements
// Atomic - all must succeed (default)
DML_Builder.newTransaction().doInsert(records).execute();

// Partial - allow some to succeed
DML_Builder.newTransaction().doInsert(records).allowPartial().execute();
```

### 13. **Reset Sharing After Operations**

Use operation-level sharing control instead of global state when possible.

```apex
// Prefer operation-level sharing control
DML_Builder.newTransaction()
	.doInsert(records)
	.execute();
```

### 14. **Use Purge Utilities for Cleanup**

Leverage built-in utilities for data cleanup operations.

```apex
// Use purge utilities for data cleanup operations
// Clean up test data in tests
@TestSetup
static void setupTestData()
{
	// Create test data
}

@IsTest
static void testCleanup()
{
	Test.startTest();
	UTIL_PurgeRecords.deleteAllRecords(Account.SObjectType);
	Test.stopTest();
}
```

---

## Related Documentation

- [Selectors - Guide](Selectors%20-%20Guide.md) - Query patterns paired with DML operations
- [Triggers - Guide](Triggers%20-%20Guide.md) - Trigger actions that perform DML via `DML_Builder`
- [Web Services - Guide](Web%20Services%20-%20Guide.md) - API classes with DML operations
- [Logging - Guide](Logging%20-%20Guide.md) - DML error logging via `LOG_Builder.errorDMLOperationResults()`
- [Validation - Guide](Validation%20-%20Guide.md) - Validation before DML operations
