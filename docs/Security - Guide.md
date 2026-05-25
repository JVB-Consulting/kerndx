# Security - Guide

**Framework:** KernDX
**Package Type:** Managed Package

> **Note for Subscriber Implementations:** When using KernDX as a managed package dependency, prefix framework class references with your installed namespace (e.g., `AcmeLib.QRY_Builder`).

**Target Audience:**
- **Developers** - Implementing secure code with data encryption, sharing enforcement, and security-aware data access
- **Architects** - Designing security patterns for sensitive data protection and security-aware data access
- **Business Analysts** - Understanding security capabilities, encryption options, and compliance features
- **Security Reviewers** - Auditing sharing enforcement points and bypass mechanisms

---

## Table of Contents

<details>
<summary>Expand</summary>

1. [Quick Navigation](#quick-navigation)
2. [Overview](#overview)
   - [Key Concepts](#key-concepts)
   - [Framework Philosophy](#framework-philosophy)
3. [Architecture](#architecture)
   - [Architecture Diagram](#architecture-diagram)
4. [Secure-by-Default Defaults](#secure-by-default-defaults)
5. [Quick Start](#quick-start)
6. [Data Encryption & Decryption (UTIL_SessionEncryption)](#data-encryption--decryption-util_sessionencryption)
   - [Overview](#overview-1)
     - [CRITICAL ARCHITECTURAL WARNING](#critical-architectural-warning)
   - [KernDX vs OOTB: Encryption Comparison](#kerndx-vs-ootb-encryption-comparison)
     - [Salesforce Out-of-the-Box Alternatives](#salesforce-out-of-the-box-alternatives)
     - [Pros & Cons Comparison](#pros--cons-comparison)
     - [When to Use KernDX UTIL_SessionEncryption](#when-to-use-kerndx-util_sessionencryption)
     - [When to Use OOTB Encryption](#when-to-use-ootb-encryption)
     - [Example Comparison](#example-comparison)
     - [Critical Warning: Data Loss Risk](#critical-warning-data-loss-risk)
   - [Why Use This Utility?](#why-use-this-utility)
   - [Encryption Methods](#encryption-methods)
     - [Encrypt Plain Text](#encrypt-plain-text)
     - [Decrypt Encrypted Text](#decrypt-encrypted-text)
   - [How Automatic Key Management Works](#how-automatic-key-management-works)
   - [Use Cases](#use-cases)
     - [Secure Multi-Step Wizard State](#secure-multi-step-wizard-state)
     - [Temporary OAuth Token Caching](#temporary-oauth-token-caching)
     - [Secure Parameter Passing via Platform Events](#secure-parameter-passing-via-platform-events)
   - [Important Considerations](#important-considerations)
7. [Record Sharing](#record-sharing)
   - [Sharing Architecture](#sharing-architecture)
     - [Sharing Control Points](#sharing-control-points)
     - [Class Hierarchy](#class-hierarchy)
   - [DML Sharing Enforcement](#dml-sharing-enforcement)
     - [DML_Builder](#dml_builder)
     - [Per-Transaction Sharing Control](#per-transaction-sharing-control)
     - [How the Proxy Pattern Works](#how-the-proxy-pattern-works)
     - [AccessLevel Selection](#accesslevel-selection)
   - [Query Sharing Enforcement](#query-sharing-enforcement)
     - [QRY_Builder Sharing Control](#qry_builder-sharing-control)
     - [How Query Sharing Works](#how-query-sharing-works)
     - [Org-Wide Access Mode Override](#org-wide-access-mode-override)
     - [QRY_Builder Security Methods](#qry_builder-security-methods)
   - [Configuring Sharing at Runtime](#configuring-sharing-at-runtime)
     - [Org-Wide Access Mode Kill-Switches](#org-wide-access-mode-kill-switches)
     - [Per-Transaction DML Control](#per-transaction-dml-control)
     - [Per-Query Sharing Control](#per-query-sharing-control)
     - [DML_Transaction Sharing Control](#dml_transaction-sharing-control)
   - [Share Object Management](#share-object-management)
   - [Classes with Explicit Sharing Declarations](#classes-with-explicit-sharing-declarations)
     - [Without Sharing Classes](#without-sharing-classes)
     - [With Sharing Classes](#with-sharing-classes)
     - [Inherited Sharing Classes](#inherited-sharing-classes)
   - [Extending Sharing Control](#extending-sharing-control)
     - [Creating Custom Selectors with Sharing Control](#creating-custom-selectors-with-sharing-control)
     - [Adding New Sharing Modes](#adding-new-sharing-modes)
   - [Testing Sharing Behavior](#testing-sharing-behavior)
     - [Testing with Different Users](#testing-with-different-users)
     - [Verifying Sharing Enforcement](#verifying-sharing-enforcement)
8. [Sharing Rules & Access](#sharing-rules--access)
   - [Security vs Sharing](#security-vs-sharing)
     - [Field-Level Security (FLS)](#field-level-security-fls)
     - [Object-Level Security (CRUD)](#object-level-security-crud)
     - [Record-Level Security (Sharing)](#record-level-security-sharing)
     - [AccessLevel Modes](#accesslevel-modes)
     - [Combining All Three Security Layers](#combining-all-three-security-layers)
   - [Common Sharing Patterns](#common-sharing-patterns)
     - [Public Site / Community Controllers](#public-site--community-controllers)
     - [System Batch Processing](#system-batch-processing)
     - [Trigger Actions](#trigger-actions)
     - [Logging Operations](#logging-operations)
   - [Security Considerations](#security-considerations)
     - [When to Bypass Sharing](#when-to-bypass-sharing)
     - [When to Enforce Sharing](#when-to-enforce-sharing)
     - [Cache Security](#cache-security)
9. [Testing](#testing)
10. [Capability Matrix (for Analysts)](#capability-matrix-for-analysts)
11. [Anti-Patterns](#anti-patterns)
12. [Best Practices](#best-practices)
    - [1. Always Enforce CRUD/FLS in User-Facing Code](#1-always-enforce-crudfls-in-user-facing-code)
    - [2. Handle Security Exceptions Gracefully](#2-handle-security-exceptions-gracefully)
    - [3. Encrypt Sensitive Data in Transit](#3-encrypt-sensitive-data-in-transit)
    - [4. Be Explicit About Sharing Context](#4-be-explicit-about-sharing-context)
    - [5. Keep Sharing Decisions at the Call Site](#5-keep-sharing-decisions-at-the-call-site)
    - [6. Don't Log Sensitive Data](#6-dont-log-sensitive-data)
    - [7. Combine Security Layers](#7-combine-security-layers)
    - [8. Decrypt Only When Necessary](#8-decrypt-only-when-necessary)
    - [9. Use inherited sharing for Security Classes](#9-use-inherited-sharing-for-security-classes)
    - [10. Use Inherited Sharing for Reusable Code](#10-use-inherited-sharing-for-reusable-code)
    - [11. Document Sharing Decisions](#11-document-sharing-decisions)
    - [12. Combine Sharing with FLS/CRUD Checks](#12-combine-sharing-with-flscrud-checks)
    - [13. Test Sharing Behavior](#13-test-sharing-behavior)
    - [14. Audit Sharing Bypasses](#14-audit-sharing-bypasses)
13. [Quick Reference](#quick-reference)
    - [Encryption/Decryption](#encryptiondecryption)
    - [Sharing Reference Table](#sharing-reference-table)
    - [Common Patterns](#common-patterns)
14. [Related Documentation](#related-documentation)

</details>

---

## Quick Navigation

| I am a...     | I need to...                      | Go to...                                                                                             |
|---------------|-----------------------------------|------------------------------------------------------------------------------------------------------|
| **Architect** | Design security patterns          | [Architecture](#architecture)                                                                        |
| **Architect** | Plan sharing enforcement          | [Record Sharing](#record-sharing)                                                                    |
| **Developer** | Enforce CRUD/FLS via queries      | [Quick Start](#quick-start)                                                                          |
| **Developer** | Encrypt sensitive data            | [Data Encryption & Decryption](#data-encryption--decryption-util_sessionencryption)                  |
| **Analyst**   | Understand security controls      | [Capability Matrix](#capability-matrix-for-analysts)                                                 |
| **Analyst**   | Review security quick reference   | [Quick Reference](#quick-reference)                                                                  |

---

## Overview

This guide covers all security capabilities provided by the KernDX framework, including data encryption, record-level sharing, and sharing enforcement patterns. These utilities help developers enforce Salesforce security best practices, protect sensitive data, and control record access.

> **Responsibilities:** The Security framework enforces access control (CRUD, FLS, sharing) and protects sensitive data (encryption). It does
> not contain business logic or make data access decisions -- it verifies that the current user is allowed to perform an operation and throws
> exceptions when they are not.

The framework provides three main security capabilities:

1. **Data Encryption** ([`UTIL_SessionEncryption`](reference/apex/UTIL_SessionEncryption.md)) - Encrypt and decrypt sensitive data with automatic key management
2. **Record Sharing** ([`UTIL_Sharing`](reference/apex/UTIL_Sharing.md), [`DML_Builder`](reference/apex/DML_Builder.md)) - Runtime control over Salesforce sharing rules
3. **Query Security** ([`QRY_Builder`](reference/apex/QRY_Builder.md)) - Independent, combinable security options for queries (CRUD/FLS via `.withUserMode()`, `.stripInaccessible()`)

> **Security Framework Scope:** Session encryption (`UTIL_SessionEncryption`), sharing control across both query (`QRY_Builder`) and DML
> (`DML_Builder`) operations, and CRUD/FLS enforcement via `QRY_Builder.withUserMode()` and `QRY_Builder.stripInaccessible()`.

> **Namespace Note:** All code examples in this guide omit the namespace prefix. If you are using KernDX as a managed package dependency in a subscriber org, prefix framework class references with the installed namespace (e.g., `YourNamespace.QRY_Builder`).

### Key Concepts

| Term | Description |
|------|-------------|
| **[Sharing Rules](https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_security_sharing_rules.htm)** | Salesforce record-level security determining which users can access which records |
| **[CRUD](https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_classes_perms_enforcing.htm)** | Object-level permissions (Create, Read, Update, Delete) |
| **[FLS](https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_classes_perms_fls.htm)** | Field-Level Security - permissions on individual fields |
| **[AccessLevel](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_enum_System_AccessLevel.htm)** | Salesforce's programmatic mode for Database operations (`SYSTEM_MODE` vs `USER_MODE`) |
| **Sharing Proxy** | Inner class pattern that executes operations with specific sharing context |

### Framework Philosophy

KernDX follows these security principles:

1. **Explicit Over Implicit** - Sharing behavior should be consciously chosen, not accidentally inherited
2. **Configurable at Runtime** - Different contexts (UI, batch, triggers) may need different sharing behavior
3. **Centralized Control** - All DML and queries flow through framework classes that can enforce policy
4. **Defense in Depth** - Sharing, FLS, and CRUD are separate concerns that can be enforced independently

---

## Architecture

### Architecture Diagram

```text
+---------------------------------------------------------------------------+
|                      SECURITY FRAMEWORK ARCHITECTURE                      |
+---------------------------------------------------------------------------+
|                                                                           |
|  DATA PROTECTION                      CRUD/FLS ENFORCEMENT                |
|  ===============                      ====================                |
|                                                                           |
|  +-----------------------------+     +-----------------------------+      |
|  |  UTIL_SessionEncryption     |     |  QRY_Builder                |      |
|  +-----------------------------+     +-----------------------------+      |
|  | - AES-256 encryption        |     | .withUserMode()             |      |
|  | - Automatic key management  |     |   (CRUD + FLS + Sharing)    |      |
|  | - encrypt() / decrypt()     |     | .stripInaccessible()        |      |
|  +-----------------------------+     |   (post-query FLS)          |      |
|                                      +-----------------------------+      |
|                                                                           |
+---------------------------------------------------------------------------+
|                                                                           |
|  RECORD-LEVEL SHARING                                                     |
|  ====================                                                     |
|                                                                           |
|  +-------------------------------+   +-------------------------------+    |
|  |  DML Sharing (DML_Builder)    |   |  Query Sharing (QRY_Builder)  |    |
|  +-------------------------------+   +-------------------------------+    |
|  | .withUserMode()               |   | .withUserMode()               |    |
|  |   (CRUD + FLS + Sharing)      |   |   (CRUD + FLS + Sharing)      |    |
|  | .withSystemMode()             |   | .withSystemMode()             |    |
|  | .bypassSharing()              |   | .withSharing()                |    |
|  |   -> without sharing proxy    |   | .bypassSharing()              |    |
|  | Default: flag-driven          |   | .stripInaccessible()          |    |
|  |   (UserModeDml_Enabled)       |   | Default: flag-driven          |    |
|  |                               |   |   (UserModeQueries_Enabled)   |    |
|  +-------------------------------+   +-------------------------------+    |
|                                                                           |
+---------------------------------------------------------------------------+
```

KernDX's security framework operates at multiple layers, each independently configurable and combinable:

1. **CRUD/FLS Enforcement** - `QRY_Builder.withUserMode()` enforces CRUD and FLS at the database level; `QRY_Builder.stripInaccessible()` removes inaccessible fields post-query
2. **Record-Level (Sharing)** - `DML_Builder` and `QRY_Builder` use a proxy pattern to execute operations under
   `with sharing`, `without sharing`, or `inherited sharing` context at runtime
3. **Query Security** - `QRY_Builder` offers `withUserMode()` (enforces CRUD, FLS, and sharing at database
   level), `stripInaccessible()` (removes inaccessible fields post-query), and `withSharing()` /
   `bypassSharing()` (sharing proxy for SYSTEM_MODE queries)
4. **Data Protection** - `UTIL_SessionEncryption` provides AES-256 encryption with automatic key management for sensitive field values

These layers are independent: you can enforce FLS without sharing enforcement, or use sharing proxies without
CRUD checks. **Subscriber-reachable queries and DML default to `AccessLevel.USER_MODE`** — the running user's FLS,
CRUD, and sharing are enforced automatically. Framework-internal selectors (CMDT readers, framework-owned sObjects,
system-schema lookups) override this via the `systemModeRequired()` hook on `SEL_Base`. Emergency kill-switch is a
metadata flip on `FeatureFlag.UserModeQueries_Enabled` / `UserModeDml_Enabled` — see [Secure-by-Default Defaults](#secure-by-default-defaults) below.

---

## Secure-by-Default Defaults

Every subscriber-reachable query and DML call defaults to `AccessLevel.USER_MODE`. Concretely:

- `new SEL_Account().findById(id)` → USER_MODE (FLS / CRUD / sharing enforced).
- `QRY_Builder.selectFrom(Account.SObjectType)...toList()` → USER_MODE.
- `DML_Builder.newTransaction().doInsert(record).execute()` → USER_MODE.

Two `FeatureFlag__mdt` records drive the default:

- `FeatureFlag.UserModeQueries_Enabled` — controls `QRY_Builder` / `SEL_Base.query`.
- `FeatureFlag.UserModeDml_Enabled` — controls `DML_Builder` / `DML_SharingProxy.defaultAccessLevel`.

Both ship with `IsEnabledByDefault__c = true`.

**Opting individual calls out of the default:**

```apex
// Query that must run SYSTEM_MODE (framework-internal CMDT read, etc.)
QRY_Builder.selectFrom(TriggerAction__mdt.SObjectType)
	.withSystemMode()
	.fields(...)
	.toList();

// DML that must run SYSTEM_MODE
DML_Builder.newTransaction()
	.withSystemMode()
	.doInsert(logEntry)
	.execute();
```

**Opting a whole selector out (for subscribers writing their own `SEL_*`):**

```apex
global inherited sharing class SEL_MyInternalCmdt extends SEL_Base
{
	global SEL_MyInternalCmdt() { super(MyInternalCmdt__mdt.SObjectType); }

	global override Boolean systemModeRequired()
	{
		return true;
	}
}
```

The `systemModeRequired()` hook on `SEL_Base` is `global virtual`. Every `findById` / `findByField` / `query`-getter call through a selector that returns `true` runs in `AccessLevel.SYSTEM_MODE` regardless of the flag state.

**Emergency kill-switch (metadata-only, no deploy needed):**

Setup → Custom Metadata Types → FeatureFlag → `UserModeQueries_Enabled` → edit → set `IsEnabledByDefault__c = false` → save. Next transaction picks it up — all subscriber-reachable queries revert to `SYSTEM_MODE`. Same for `UserModeDml_Enabled`.

**Bypass audit trail (framework-wide):** every bypass call across the trigger (`TRG_Base.bypass*`), query (`QRY_Builder.withSystemMode` / `bypassSharing` / `withoutSecurity`), DML (`DML_Builder.withSystemMode` / `bypassSharing`), and validation (`UTIL_ValidationRule.bypassObject` / `bypassGroup` / `bypassRule`) surfaces emits a `LogEntryEvent__e` with category `BypassEvent` via `UTIL_BypassAudit.emit` (user, action, surface, target, optional reason via `UTIL_BypassAudit.setBypassReason(String)`). The `BypassAudit_Enabled` `FeatureFlag__mdt` is a master kill-switch (default-on; subscribers disable via `FeatureFlagStrategy__mdt` override). Query via `SEL_LogEntry.query.condition(LogEntry__c.ContextData__c).contains('"category":"BypassEvent"')`.

---

## Quick Start

The most common security pattern is enforcing CRUD/FLS at the query level. Here is the simplest usage:

```apex
// Enforce CRUD, FLS, and sharing in a single query
List<Account> accounts = QRY_Builder.selectFrom(Account.SObjectType)
	.fields(new List<String>{'Name', 'Industry'})
	.withUserMode()
	.toList();
```

For sharing enforcement without FLS (SYSTEM_MODE), use sharing proxies:

```apex
// Enforce sharing and strip inaccessible fields
List<Account> accounts = QRY_Builder.selectFrom(Account.SObjectType)
	.fields(new List<String>{'Name', 'Industry'})
	.withSharing()
	.stripInaccessible()
	.toList();
```

For deeper coverage, continue reading the sections below.

---

## Data Encryption & Decryption ([`UTIL_SessionEncryption`](reference/apex/UTIL_SessionEncryption.md))

### Overview

[`UTIL_SessionEncryption`](reference/apex/UTIL_SessionEncryption.md) provides bi-directional encryption and decryption using AES256 encryption with HMAC-SHA256 (Encrypt-then-MAC) and automatic key management.

#### CRITICAL ARCHITECTURAL WARNING

**This utility uses EPHEMERAL STORAGE (Platform Cache) for encryption keys.**

Keys are **NOT persisted to the database**. If the cache expires, is flushed, or the session ends, the key is **LOST FOREVER** and any data encrypted with it becomes **permanently unrecoverable**.

**DO NOT USE THIS CLASS FOR:**
- Persisting encrypted data to SObjects or Custom Settings
- Long-term data storage
- Data that must survive beyond an 8-hour session

**USE THIS CLASS ONLY FOR:**
- Short-lived data passing (e.g., ViewState, temporary token exchange)
- Session-scoped data where data loss is acceptable upon session expiry
- Temporary credentials that expire within hours

**Key Features:**
- AES256 encryption with HMAC-SHA256 for integrity validation
- Automatic key generation and management via Platform Cache
- Platform cache integration with 8-hour maximum key expiry
- User-scoped keys (unique per user session)
- Base64-encoded output for safe storage in text fields
- Automatic key rotation on cache expiry

---

### KernDX vs OOTB: Encryption Comparison

#### Salesforce Out-of-the-Box Alternatives

Salesforce provides several native encryption options:

1. **[Crypto.encrypt() / Crypto.decrypt()](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_classes_restful_crypto.htm)** - Manual encryption with your own keys
2. **[Shield Platform Encryption](https://developer.salesforce.com/docs/atlas.en-us.securityImplGuide.meta/securityImplGuide/security_pe_overview.htm)** - Transparent field encryption at rest (requires Shield license)
3. **Crypto.encryptWithManagedIV() / Crypto.decryptWithManagedIV()** - Automatic IV management

#### Pros & Cons Comparison

| Feature | KernDX [`UTIL_SessionEncryption`](reference/apex/UTIL_SessionEncryption.md) | Salesforce OOTB |
|---------|----------------------------------------|-----------------|
| **Key Management** | Automatic key generation and caching | Manual key management required |
| **Automatic IV** | Random IV per encryption, included in output | `encryptWithManagedIV()` available but still requires key management |
| **HMAC Integrity** | Automatic HMAC-SHA256 for tamper detection | Must manually implement |
| **User-Scoped Keys** | Unique keys per user via Platform Cache | Must manually implement key scoping |
| **Key Rotation** | Automatic on cache expiry (8 hours) | Manual key rotation required |
| **Long-Term Storage** | Keys expire, data becomes unrecoverable | [Shield Platform Encryption](https://developer.salesforce.com/docs/atlas.en-us.securityImplGuide.meta/securityImplGuide/security_pe_overview.htm) for persistent data |
| **Setup Complexity** | Requires Platform Cache configuration | [Crypto](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_classes_restful_crypto.htm) class works out of box |
| **License Cost** | No additional license required | Shield Platform Encryption requires Shield license |
| **Data Persistence** | EPHEMERAL ONLY (max 8 hours) | Shield supports long-term encrypted storage |
| **Key Storage** | Platform Cache (ephemeral) | Shield stores keys securely with HSM |
| **Performance** | Slight overhead from cache lookups | Direct encryption, no cache dependency |
| **Compliance** | Not suitable for compliance requirements | Shield meets HIPAA, PCI-DSS, etc. |

#### When to Use KernDX UTIL_SessionEncryption

- **Temporary encryption** for session data, ViewState, temporary tokens
- **Short-lived credentials** that expire within hours
- **Automatic key management** without manual key handling
- **User-scoped encryption** where each user has unique keys
- **No Shield license** available
- **HMAC integrity validation** to detect tampering

#### When to Use OOTB Encryption

**Use [Crypto.encrypt()](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_classes_restful_crypto.htm) when:**
- You need **full control** over encryption keys
- You have **external key management** systems
- You want **zero dependencies** on Platform Cache
- You're building **custom encryption frameworks**

**Use [Shield Platform Encryption](https://developer.salesforce.com/docs/atlas.en-us.securityImplGuide.meta/securityImplGuide/security_pe_overview.htm) when:**
- You need **long-term encrypted data** storage
- You require **compliance** (HIPAA, PCI-DSS, GDPR)
- You want **transparent encryption** without code changes
- You need **key backup and recovery**
- You have **Shield license** available
- You need **field-level encryption** for sensitive SObjects

#### Example Comparison

**OOTB Crypto (Manual Key Management):**
```apex
// Must manually manage encryption keys
Blob encryptionKey = Crypto.generateAesKey(256);

// Must store key somewhere (Custom Setting, Named Credential, etc.)
// WARNING: Storing keys in Salesforce is security risk!

// Manual encryption with IV
Blob data = Blob.valueOf('sensitive data');
Blob encryptedData = Crypto.encryptWithManagedIV('AES256', encryptionKey, data);

// Must separately compute HMAC if integrity validation needed
Blob hmacKey = Crypto.generateMac('HmacSHA256', data, encryptionKey);

// Decryption
Blob decryptedData = Crypto.decryptWithManagedIV('AES256', encryptionKey, encryptedData);
```

**KernDX UTIL_SessionEncryption (Automatic):**
```apex
// Automatic key generation, caching, IV management, and HMAC
String sensitiveData = 'sensitive data';

// One-line encryption (key generated automatically)
String encrypted = UTIL_SessionEncryption.encrypt(sensitiveData);

// One-line decryption (key retrieved from cache)
String decrypted = UTIL_SessionEncryption.decrypt(encrypted);

// HMAC validation happens automatically during decryption
// Throws exception if data has been tampered with
```

**[Shield Platform Encryption](https://developer.salesforce.com/docs/atlas.en-us.securityImplGuide.meta/securityImplGuide/security_pe_overview.htm) (Transparent):**
```apex
// No code changes required - just enable encryption on field
// Account.SSN__c is encrypted automatically at rest

Account account = new Account(Name = 'Acme', SSN__c = '123-45-6789');
insert account; // SSN automatically encrypted in database

// Query and use normally - decryption is transparent
Account retrieved = [SELECT SSN__c FROM Account WHERE Id = :account.Id];
// retrieved.SSN__c is automatically decrypted: '123-45-6789'
```

#### Critical Warning: Data Loss Risk

**KernDX UTIL_SessionEncryption:**
```apex
// DANGER: Data encrypted today may be unrecoverable tomorrow!

// Day 1: Encrypt and store
String encrypted = UTIL_SessionEncryption.encrypt('secret');
account.EncryptedToken__c = encrypted;
update account;

// Day 2: Cache expires or org is refreshed
// THIS WILL FAIL - Key is gone forever:
String decrypted = UTIL_SessionEncryption.decrypt(account.EncryptedToken__c);
// Exception: Cache.CacheException: Unable to decrypt - key not found
```

**Recommendation:** For any data that must be decrypted beyond an 8-hour window, use [Shield Platform Encryption](https://developer.salesforce.com/docs/atlas.en-us.securityImplGuide.meta/securityImplGuide/security_pe_overview.htm) or external key management.

---

### Why Use This Utility?

Salesforce provides [`Crypto.encrypt()` and `Crypto.decrypt()`](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_classes_restful_crypto.htm), but these require you to manually manage encryption keys. [`UTIL_SessionEncryption`](reference/apex/UTIL_SessionEncryption.md) simplifies this by:

1. **Auto-generating keys** when needed
2. **Caching keys** in platform cache for performance
3. **Rotating keys** automatically (8-hour expiry)
4. **Handling multiple cache strategies** (session vs. org cache)

This makes it easy to encrypt sensitive data like API tokens, credentials, or personally identifiable information (PII).

### Encryption Methods

#### Encrypt Plain Text

```apex
/**
 * @description Encrypts a plain text string using AES256 encryption
 *
 * @param plainTextValue The plain text to encrypt
 *
 * @return Base64-encoded encrypted string
 */
global static String encrypt(String plainTextValue)
```

**Example:**
```apex
// Encrypt sensitive data for secure session-scoped passing
String apiToken = 'sk_live_1234567890abcdef';
String encryptedToken = UTIL_SessionEncryption.encrypt(apiToken);

// Pass encrypted token through page state, cache, or between controllers
// Key remains in platform cache for up to 8 hours

// encryptedToken is a Base64-encoded string like "xK7j9mP3nQ8wR5sT6uV1yZ2..."
```

#### Decrypt Encrypted Text

```apex
/**
 * @description Decrypts an encrypted string back to plain text
 *
 * @param encryptedTextValue The Base64-encoded encrypted string
 *
 * @return Decrypted plain text string
 */
global static String decrypt(String encryptedTextValue)
```

**Example:**
```apex
// Decrypt within the same session (key must still be in cache)
String plainTextToken = UTIL_SessionEncryption.decrypt(encryptedToken);

// Use decrypted token for API callout
HttpRequest request = new HttpRequest();
request.setHeader('Authorization', 'Bearer ' + plainTextToken);
```

### How Automatic Key Management Works

1. **First Encryption Request:**
   - Generates a random 256-bit AES key using `Crypto.generateAesKey(256)`
   - Stores key in user-scoped platform cache with 8-hour TTL (28,800 seconds)
   - Generates HMAC key by deriving from AES key using SHA-256
   - Encrypts the plain text using AES256 with random IV (Initialization Vector)
   - Appends HMAC for integrity validation (Encrypt-then-MAC pattern)
   - Returns Base64-encoded encrypted string: `IV:Cipher:HMAC`

2. **Subsequent Requests:**
   - Retrieves user-scoped key from platform cache
   - If key not found or cache unavailable, throws exception
   - Uses cached key for encryption/decryption
   - Validates HMAC before decryption to detect tampering

3. **Key Rotation:**
   - Keys automatically expire after 8 hours (maximum session cache TTL)
   - **WARNING**: Once a key expires, all data encrypted with it is permanently lost
   - Key is user-scoped (unique per user) for security isolation

**Cache Strategy:**
```apex
// Uses Platform Cache with AUTO mode (Session -> Org fallback)
// Keys are unique per user for security isolation
// Cache availability is verified before operations
// Throws Cache.CacheException if cache is unavailable or misconfigured
```

### Use Cases

#### Secure Multi-Step Wizard State

Encrypt sensitive data entered in an early step for use in a later step, all within a single user session:

```apex
public inherited sharing class WizardController
{
	/**
	 * @description Encrypts credentials entered in step 1 for use in step 3.
	 * Encrypted value is passed through page state, not persisted.
	 */
	@AuraEnabled
	public static String encryptCredentials(String externalPassword)
	{
		return UTIL_SessionEncryption.encrypt(externalPassword);
	}

	/**
	 * @description Decrypts credentials in step 3 to authenticate with external system.
	 * Must be called within the same session (key expires after 8 hours).
	 */
	@AuraEnabled
	public static String completeIntegration(String encryptedPassword, String endpoint)
	{
		String password = UTIL_SessionEncryption.decrypt(encryptedPassword);

		HttpRequest request = new HttpRequest();
		request.setEndpoint(endpoint);
		request.setHeader('Authorization', 'Basic ' + EncodingUtil.base64Encode(
			Blob.valueOf('user:' + password)
		));

		HttpResponse response = new Http().send(request);
		return response.getBody();
	}
}
```

#### Temporary OAuth Token Caching

Encrypt an OAuth token returned from an external auth flow for reuse during the current session:

```apex
public inherited sharing class OAuthSessionManager
{
	/**
	 * @description Caches encrypted access token for reuse during the session.
	 * Token is encrypted in memory/cache, never persisted to database.
	 */
	public static String cacheAccessToken(String accessToken)
	{
		String encrypted = UTIL_SessionEncryption.encrypt(accessToken);
		Cache.Session.put('oauth_token', encrypted, 3600); // 1 hour
		return encrypted;
	}

	/**
	 * @description Retrieves and decrypts access token for API callout.
	 */
	public static String getAccessToken()
	{
		String encrypted = (String)Cache.Session.get('oauth_token');

		if(String.isBlank(encrypted))
		{
			throw new AuthException('Session expired. Please re-authenticate.');
		}

		return UTIL_SessionEncryption.decrypt(encrypted);
	}

	private class AuthException extends Exception {}
}
```

#### Secure Parameter Passing via Platform Events

Encrypt sensitive data before publishing through Platform Events within a single transaction context:

```apex
public inherited sharing class SecureEventPublisher
{
	/**
	 * @description Publishes encrypted payload via Platform Event.
	 * Consuming subscriber must decrypt within the same cache window.
	 */
	public static void publishSecureEvent(String sensitivePayload)
	{
		String encrypted = UTIL_SessionEncryption.encrypt(sensitivePayload);

		Secure_Event__e event = new Secure_Event__e(
			Encrypted_Payload__c = encrypted
		);

		EventBus.publish(event);
	}

	/**
	 * @description Decrypts payload received from Platform Event.
	 * Only works if the encryption key is still in the subscriber's cache.
	 */
	public static String decryptEventPayload(String encryptedPayload)
	{
		return UTIL_SessionEncryption.decrypt(encryptedPayload);
	}
}
```

> **Note:** Platform Event encryption only works when the publisher and subscriber share the same user-scoped cache (e.g., same user context). For cross-user event encryption, use `Crypto.encrypt()` with a shared key stored in a Named Credential or Protected Custom Setting.

### Important Considerations

**Key Expiry and Data Persistence:**
- **CRITICAL**: Encrypted data can only be decrypted while the original key is in cache (max 8 hours)
- **CRITICAL**: If cache expires, is cleared, or org is refreshed, keys are lost FOREVER
- For long-term storage, use Salesforce [Shield Platform Encryption](https://developer.salesforce.com/docs/atlas.en-us.securityImplGuide.meta/securityImplGuide/security_pe_overview.htm) instead
- This utility is best for **temporary encryption** (session tokens, temporary credentials, ViewState)

**Cache Availability:**
- Requires Platform Cache to be allocated and configured in the org
- Uses AUTO mode (Session -> Org fallback)
- `isAvailable()` method checks cache availability before operations
- Throws `Cache.CacheException` if cache is unavailable

**Performance:**
- First encryption operation generates new 256-bit AES key
- Subsequent operations are fast due to platform cache
- User-scoped keys prevent cross-user key reuse
- HMAC validation adds minimal overhead for integrity checks

**Security:**
- Keys stored in ephemeral platform cache (NOT persisted to database)
- Keys expire after 8 hours maximum (session cache limit)
- Uses AES256 encryption with HMAC-SHA256 (Encrypt-then-MAC)
- Random IV per encryption prevents pattern analysis
- User-scoped keys isolate encryption between users
- HMAC validation detects tampering or corruption
- Keys never exposed in debug logs or API responses

**When NOT to Use:**
- Long-term data encryption (use [Shield Platform Encryption](https://developer.salesforce.com/docs/atlas.en-us.securityImplGuide.meta/securityImplGuide/security_pe_overview.htm))
- Credit card data (use PCI-compliant tokenization service)
- Data requiring compliance-mandated encryption key management
- Data that must survive org refreshes or cache flushes
- Data persisted beyond an 8-hour session

---

## Record Sharing

This section covers runtime control over Salesforce [sharing rules](https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_security_sharing_rules.htm). Unlike standard Apex where sharing is determined at compile-time via class declarations (`with sharing`, `without sharing`, `inherited sharing`), KernDX allows you to **choose sharing behavior at execution time** through a proxy pattern.

### Sharing Architecture

#### Sharing Control Points

The framework provides sharing control at four key points:

```text
+-----------------------------------------------------------------------------+
|                           APPLICATION CODE                                   |
+-----------------------------------------------------------------------------+
                                    |
                                    v
+-----------------------------------------------------------------------------+
|                        FRAMEWORK ENTRY POINTS                                |
|  +---------------------+  +---------------------+  +---------------------+  |
|  |   QRY_Builder       |  | DML_Builder         |  | DML_Transaction     |  |
|  |   (Queries)         |  | (DML Operations)    |  | (Transactions)      |  |
|  +----------+----------+  +----------+----------+  +----------+----------+  |
+-------------+----------------------------+----------------------------+------+
              |                            |                            |
              v                            v                            v
+-----------------------------------------------------------------------------+
|                          SHARING PROXY LAYER                                 |
|  +---------------------------------+  +---------------------------------+   |
|  |        QRY_Builder              |  |   DML_Builder                   |   |
|  |  +----------------------------+ |  |  +----------------------------+ |   |
|  |  | SharingProxy (inherited)   | |  |  | DatabaseUpdateProxy        | |   |
|  |  | WithSharingProxy (with)    | |  |  | ...WithoutSharing (without)| |   |
|  |  | NoSharingProxy (without)   | |  |  | ...WithSharing (with)      | |   |
|  |  +----------------------------+ |  |  +----------------------------+ |   |
|  +---------------------------------+  +---------------------------------+   |
+-----------------------------------------------------------------------------+
                                    |
                                    v
+-----------------------------------------------------------------------------+
|                          SALESFORCE DATABASE                                 |
|              Database.insert() / Database.query() / etc.                     |
+-----------------------------------------------------------------------------+
```

#### Class Hierarchy

**DML Operations:**
```text
DML_Transaction (inherited sharing)
    +-- DML_Builder (inherited sharing)
            +-- DML_SharingProxy.DatabaseProxy (inherited sharing, virtual base)
                    +-- DatabaseProxyWithoutSharing (without sharing)
                    +-- DatabaseProxyWithSharing (with sharing)
```

**Query Operations:**
```text
QRY_Builder (inherited sharing)
    +-- SEL_Base (inherited sharing)
            +-- QRY_Engine (inherited sharing)
                    +-- WithSharingExecutor (with sharing)
                    +-- WithoutSharingExecutor (without sharing)
```

### DML Sharing Enforcement

#### DML_Builder

[`DML_Builder`](reference/apex/DML_Builder.md) is the core class controlling sharing enforcement for all DML operations. It uses the **Strategy Pattern** with inner proxy classes that have different sharing declarations, selected per transaction via fluent builder methods.

**Class Declaration:**
```apex
global inherited sharing class DML_Builder
```

**Key Components:**

1. **Access-mode methods** - `.withUserMode()` / `.withSystemMode()` select the `AccessLevel` for the transaction
2. **Sharing control** - `.bypassSharing()` selects the `without sharing` proxy
3. **Inner Proxy Classes** - Execute DML with specific sharing context (`DML_SharingProxy.SharingType` enum, internal)

#### Per-Transaction Sharing Control

`DML_Builder` offers a single programmatic sharing override: `.bypassSharing()`. When not called, the transaction inherits the caller's sharing context via the `inherited sharing` proxy.

| Builder Method | Proxy Used | Effect |
|----------------|------------|--------|
| *(default)* | `inherited sharing` proxy | DML inherits caller's sharing context |
| `.bypassSharing()` | `without sharing` proxy | DML ignores sharing rules |

There is no `.withSharing()` method on `DML_Builder` — to enforce sharing on a DML transaction, call the transaction from a `with sharing` class (or one whose `inherited sharing` caller is `with sharing`). For full CRUD/FLS enforcement, use `.withUserMode()` (see [Secure-by-Default Defaults](#secure-by-default-defaults)).

#### How the Proxy Pattern Works

The framework implements the **Strategy Pattern** using inner proxy classes (on `DML_SharingProxy`) with different [sharing declarations](https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_classes_keywords_sharing.htm). The `DML_SharingProxy.SharingType` enum is package-internal (`public`, not `global`) — subscribers drive proxy selection through the fluent builder methods rather than referencing the enum directly:

| Builder Method | Proxy Class (internal) | Sharing Declaration | Effect |
|----------------|------------------------|---------------------|--------|
| `.bypassSharing()` | `DML_SharingProxy.DatabaseProxyWithoutSharing` | `without sharing` | DML ignores sharing rules |
| *(default, with sharing caller)* | `DML_SharingProxy.DatabaseProxyWithSharing` | `with sharing` | DML respects sharing rules |
| *(default, inherited caller)* | `DML_SharingProxy.DatabaseProxy` | `inherited sharing` | DML inherits caller's context |

**Why This Matters:**

In standard Apex, sharing behavior is determined at compile-time by the class declaration. You cannot change it at runtime. The proxy pattern solves this by delegating DML operations to inner classes with the desired sharing declaration.

**Key Capability:** The proxy layer can override the caller's sharing context when needed. Even if your code is in a `without sharing` class, running DML from inside a dedicated `with sharing` class that calls `DML_Builder.newTransaction()...execute()` will execute DML through the `with sharing` proxy. Conversely, `.bypassSharing()` on the builder explicitly elects the `without sharing` proxy. Pair this with `.withUserMode()` to also enforce CRUD/FLS at the database level.

#### AccessLevel Selection

Every `DML_Builder` transaction resolves an `AccessLevel` when `.execute()` runs:

1. `.withUserMode()` → forces `AccessLevel.USER_MODE` (CRUD + FLS + sharing enforced).
2. `.withSystemMode()` → forces `AccessLevel.SYSTEM_MODE` (CRUD + FLS bypassed; sharing controlled by proxy).
3. *(neither called)* → the `UserModeDml_Enabled` feature flag drives the default. When the flag is `true` (package default), USER_MODE is used; when the flag is flipped to `false` via metadata, SYSTEM_MODE is used.

```apex
// User-facing DML: enforce CRUD, FLS, sharing
DML_Builder.newTransaction()
	.doInsert(accountFromUi)
	.withUserMode()
	.execute();

// Framework-internal DML (log events, orchestration rows): bypass CRUD/FLS
DML_Builder.newTransaction()
	.doInsert(logEntryEvent)
	.withSystemMode()
	.execute();
```

> **Important:** `AccessLevel.SYSTEM_MODE` bypasses FLS/CRUD, but the sharing declaration on the proxy (`with sharing` / `without sharing` / `inherited sharing`) still controls record-level access.

### Query Sharing Enforcement

#### QRY_Builder Sharing Control

[`QRY_Builder`](reference/apex/QRY_Builder.md) provides the same proxy pattern for queries. It offers both **per-query** and **global** sharing control.

**Class Declaration:**
```apex
global inherited sharing class QRY_Builder
```

#### How Query Sharing Works

Similar to DML operations, [`QRY_Builder`](reference/apex/QRY_Builder.md) uses inner proxy classes to control sharing at query time. The sharing methods determine which proxy executes the query:

| Sharing Method | Proxy Used | Effect |
|----------------|------------|--------|
| *(default)* | `SharingProxy` | Query inherits caller's sharing context |
| `.withSharing()` | `WithSharingProxy` | Query enforces sharing rules |
| `.bypassSharing()` | `NoSharingProxy` | Query bypasses sharing rules |

**Three-State Logic:**

The sharing proxy methods provide three distinct behaviors:
- **Default (no method called)** - Respects the calling class's sharing declaration. If your class is `with sharing`, queries enforce sharing. If `without sharing`, they bypass.
- **`.withSharing()`** - Always enforces sharing regardless of caller's context. Use for user-facing features.
- **`.bypassSharing()`** - Always bypasses sharing regardless of caller's context. Use for system operations.

This approach lets you write flexible code that can operate in different security contexts without changing the code itself.

#### Org-Wide Access Mode Override

There is **no per-transaction singleton flag** for flipping every query between `with` / `without` sharing. When you need consistent behaviour across many queries, use one of the three mechanisms below.

**1. Per-call on each query.** Chain `.withSharing()` / `.bypassSharing()` on individual `QRY_Builder` calls, or `.withUserMode()` / `.withSystemMode()` to also control CRUD/FLS.

**2. Per-selector lock.** Subscriber `SEL_*` classes that must always run SYSTEM_MODE (framework-internal CMDT readers, system-schema selectors) override `systemModeRequired()`:

```apex
global inherited sharing class SEL_MyInternalCmdt extends SEL_Base
{
	global SEL_MyInternalCmdt() { super(MyInternalCmdt__mdt.SObjectType); }

	global override Boolean systemModeRequired()
	{
		return true;
	}
}
```

**3. Org-wide emergency kill-switch.** Flip the `kern__FeatureFlag.UserModeQueries_Enabled` custom metadata record to `IsEnabledByDefault__c = false`. Every subscriber-reachable query falls back to SYSTEM_MODE on the next transaction. The companion flag `UserModeDml_Enabled` does the same for `DML_Builder`. See [Secure-by-Default Defaults](#secure-by-default-defaults).

> **When to use which:** per-call for one-off exceptions, per-selector override for framework-internal classes, metadata kill-switch only for emergency rollback of the secure-by-default posture. Do not flip the metadata flag as a routine configuration lever — it weakens the security posture of every subscriber-reachable query.

#### QRY_Builder Security Methods

[`QRY_Builder`](reference/apex/QRY_Builder.md) (the fluent query builder) is the recommended approach for 95% of queries. It provides independent, combinable security options:

##### Security Method Summary

| Method | Effect | When to Use |
|--------|--------|-------------|
| `withUserMode()` | Runs in USER_MODE (enforces CRUD, FLS, sharing at DB level) | User-facing code requiring full security |
| `stripInaccessible()` | Removes inaccessible fields from results post-query | When null values for inaccessible fields are problematic |
| `withSharing()` | Uses `with sharing` proxy class | Enforce sharing in SYSTEM_MODE queries |
| `bypassSharing()` | Uses `without sharing` proxy class | Bypass sharing in SYSTEM_MODE (use with caution) |
| `withoutSecurity()` | Clears USER_MODE, strip, and sharing selections (SYSTEM_MODE + inherited sharing) | System-level queries that must opt out of the secure-by-default posture |

##### Default Behaviour

Subscriber-reachable queries run in **USER_MODE** with **inherited sharing** by default — driven by the `UserModeQueries_Enabled` feature flag (shipped `true`). USER_MODE enforces CRUD, FLS, and sharing at the database level. Framework-internal selectors opt out via `systemModeRequired()` returning `true`, and individual calls opt out via `.withSystemMode()`. If the org flips `UserModeQueries_Enabled` to `false` (emergency kill-switch), every query falls back to SYSTEM_MODE on the next transaction.

##### USER_MODE vs Sharing Proxy

When using `withUserMode()`, sharing is enforced at the database level regardless of `withSharing()`/`bypassSharing()` settings. The sharing proxy methods only have effect in SYSTEM_MODE.

##### Code Examples

```apex
// Default query - USER_MODE (FLS/CRUD/sharing enforced) when UserModeQueries_Enabled is true
List<Account> accounts = QRY_Builder.selectFrom(Account.SObjectType)
	.fields(new List<String>{'Name', 'Industry'})
	.condition(Account.Type).equals('Customer')
	.toList();

// USER_MODE - explicit opt-in (overrides flag if kill-switch has disabled it)
List<Account> userModeAccounts = QRY_Builder.selectFrom(Account.SObjectType)
	.fields(new List<String>{'Name', 'Industry'})
	.withUserMode()
	.toList();

// SYSTEM_MODE - explicit opt-out for framework-internal / CMDT reads
List<Account> internalAccounts = QRY_Builder.selectFrom(Account.SObjectType)
	.fields(new List<String>{'Name', 'Industry'})
	.withSystemMode()
	.toList();

// Strip inaccessible fields from results
List<Account> secureAccounts = QRY_Builder.selectFrom(Account.SObjectType)
	.fields(new List<String>{'Name', 'AnnualRevenue'})
	.stripInaccessible()
	.toList();

// Enforce sharing via proxy class (SYSTEM_MODE only — redundant under USER_MODE default)
List<Account> sharedAccounts = QRY_Builder.selectFrom(Account.SObjectType)
	.fields(new List<String>{'Name', 'Industry'})
	.withSystemMode()
	.withSharing()
	.toList();

// Bypass sharing via proxy class (SYSTEM_MODE only)
List<Account> allAccounts = QRY_Builder.selectFrom(Account.SObjectType)
	.fields(new List<String>{'Name', 'Industry'})
	.withSystemMode()
	.bypassSharing()
	.toList();

// Combine options as needed
List<Account> fullSecurityAccounts = QRY_Builder.selectFrom(Account.SObjectType)
	.fields(new List<String>{'Name', 'AnnualRevenue'})
	.withUserMode()
	.stripInaccessible()
	.toList();
```

### Configuring Sharing at Runtime

#### Org-Wide Access Mode Kill-Switches

There is **no per-transaction singleton flag** for DML sharing. The only org-wide controls are the two `FeatureFlag__mdt` records that drive the secure-by-default posture:

```text
Setup -> Custom Metadata Types -> FeatureFlag -> UserModeQueries_Enabled
   -> IsEnabledByDefault__c = true   (package default — USER_MODE for all queries)
   -> IsEnabledByDefault__c = false  (emergency kill-switch — SYSTEM_MODE for all queries)

Setup -> Custom Metadata Types -> FeatureFlag -> UserModeDml_Enabled
   -> IsEnabledByDefault__c = true   (package default — USER_MODE for all DML)
   -> IsEnabledByDefault__c = false  (emergency kill-switch — SYSTEM_MODE for all DML)
```

Flipping a flag affects the next transaction in the org. Treat this as an emergency rollback lever only — do not use it as a routine configuration knob.

#### Per-Transaction DML Control

Use [`DML_Builder`](reference/apex/DML_Builder.md) for specific operations with explicit access mode or sharing:

```apex
// USER_MODE: enforce CRUD + FLS + sharing for this transaction
DML_Builder.newTransaction()
	.doInsert(accountFromUi)
	.withUserMode()
	.execute();

// SYSTEM_MODE: bypass CRUD + FLS (e.g. framework log writes)
DML_Builder.newTransaction()
	.doInsert(logEntryEvent)
	.withSystemMode()
	.execute();

// Sharing bypass (runs through without-sharing proxy)
DML_Builder.newTransaction()
	.doUpdate(records)
	.bypassSharing()
	.execute();

// Default (no access-mode or sharing method): follows the
// UserModeDml_Enabled flag (USER_MODE when true) + inherits caller's sharing
DML_Builder.newTransaction()
	.doUpdate(records)
	.execute();
```

#### Per-Query Sharing Control

When you need to control sharing or access mode for a specific query (without affecting other queries), use the fluent [`QRY_Builder`](reference/apex/QRY_Builder.md) API:

```apex
// USER_MODE: full CRUD + FLS + sharing enforcement for this query only
List<Account> accounts = QRY_Builder.selectFrom(Account.SObjectType)
	.fields(new List<String>{'Id', 'Name', 'Industry'})
	.withUserMode()
	.toList();

// SYSTEM_MODE + with-sharing proxy (sharing proxy only has effect in SYSTEM_MODE)
List<Account> sharedAccounts = QRY_Builder.selectFrom(Account.SObjectType)
	.fields(new List<String>{'Id', 'Name', 'Industry'})
	.withSystemMode()
	.withSharing()
	.toList();

// SYSTEM_MODE + without-sharing proxy
List<Account> allAccounts = QRY_Builder.selectFrom(Account.SObjectType)
	.fields(new List<String>{'Id', 'Name', 'Industry'})
	.withSystemMode()
	.bypassSharing()
	.toList();

// Clear all previously-chained security selections on this builder
// (falls back to SYSTEM_MODE + inherited sharing — opts out of USER_MODE even when the flag is true)
List<Account> defaultedAccounts = QRY_Builder.selectFrom(Account.SObjectType)
	.fields(new List<String>{'Id', 'Name', 'Industry'})
	.withoutSecurity()
	.toList();
```

#### DML_Transaction Sharing Control

[`DML_Builder`](reference/apex/DML_Builder.md) supports sharing control at the transaction level via `.bypassSharing()`:

```apex
// Bypass sharing for the entire transaction
DML_Builder.newTransaction()
	.doInsert(account)
	.doInsert(contact, Contact.AccountId, account)
	.bypassSharing()
	.execute();

// Default: inherits caller's sharing context
DML_Builder.newTransaction()
	.doInsert(account)
	.execute();
```

### Share Object Management

Creating and deleting Share records (like `AccountShare`, `OpportunityShare`, etc.) requires elevated permissions. The [`UTIL_Sharing`](reference/apex/UTIL_Sharing.md) utility handles this by explicitly bypassing sharing for Share object DML.

**Why bypass sharing for shares?** A user granting access to their records may not have direct access to the underlying Share objects. For example, a manager sharing their Accounts with an assistant needs the Share records created even though the manager can't query `AccountShare` directly. The framework handles this complexity so you can focus on the business logic.

**Usage:**
```apex
// Grant permanent access to records
List<SObject> shares = UTIL_Sharing.grant(accounts, groupId, 'Read');

// Grant temporary access (auto-revoked after specified minutes)
List<SObject> tempShares = UTIL_Sharing.grantTemporary(accounts, groupId, 'Read', 30);
```

The framework creates the appropriate Share records with `BYPASS` sharing mode, ensuring the operation succeeds regardless of the calling user's permissions on Share objects.

### Classes with Explicit Sharing Declarations

#### Without Sharing Classes

These framework classes are declared `without sharing`, meaning their internal operations bypass sharing rules by default:

| Class | Purpose | Rationale |
|-------|---------|-----------|
| [`TST_Builder`](reference/apex/TST_Builder.md) | Test data creation | Tests need to create data regardless of running user's access |

**TST_Builder:**
```apex
@SuppressWarnings('PMD.ApexCRUDViolation')
global without sharing class TST_Builder
```
- Creates test data, custom metadata, permission assignments
- Must operate regardless of test user's permissions

> **Important:** Even though these classes are declared `without sharing`, DML operations that use the framework's [`DML_Builder`](reference/apex/DML_Builder.md) methods flow through the sharing proxy. A `with sharing` inner proxy can override a `without sharing` caller — so you can still enforce sharing on DML operations from a `without sharing` class by calling the builder from a dedicated `with sharing` wrapper, or pair the call with `.withUserMode()` to enforce CRUD + FLS + sharing at the database level regardless of caller context.

#### With Sharing Classes

These classes always enforce sharing:

| Class | Purpose | Rationale |
|-------|---------|-----------|
| [`UTIL_SessionEncryption`](reference/apex/UTIL_SessionEncryption.md) | Session-based encryption | Security-sensitive operations should respect access |

**UTIL_SessionEncryption:**
```apex
global with sharing class UTIL_SessionEncryption
```
- Manages session-based encryption and decryption
- Enforces sharing to ensure only authorized users can access encrypted data

#### Inherited Sharing Classes

Most framework classes use `inherited sharing` to respect the caller's context:

| Class | Purpose |
|-------|---------|
| [`DML_Builder`](reference/apex/DML_Builder.md) | Bulk DML operations |
| [`DML_Transaction`](reference/apex/DML_Transaction.md) | Transaction management |
| [`SEL_Base`](reference/apex/SEL_Base.md) | Generic selector methods |
| [`QRY_Builder`](reference/apex/QRY_Builder.md) | Fluent query builder |
| [`UTIL_Sharing`](reference/apex/UTIL_Sharing.md) | Record sharing management |
| All `SEL_*` selector classes | Object-specific selectors |

### Extending Sharing Control

#### Creating Custom Selectors with Sharing Control

You can create custom selectors that leverage the sharing proxy pattern through [`SEL_Base`](reference/apex/SEL_Base.md) and [`QRY_Builder`](reference/apex/QRY_Builder.md):

```apex
public inherited sharing class SEL_CustomObject extends SEL_Base
{
	public SEL_CustomObject()
	{
		super(CustomObject__c.SObjectType);
	}

	public override List<SObjectField> getFields()
	{
		return new List<SObjectField>
		{
			CustomObject__c.Name,
			CustomObject__c.Status__c
		};
	}

	/**
	 * @description Finds records by status with explicit sharing control.
	 *
	 * @param status The status value to filter by.
	 *
	 * @return List of matching records.
	 */
	public List<CustomObject__c> findByStatus(String status)
	{
		return query.condition(CustomObject__c.Status__c).equals(status)
			.withSharing()
			.toList();
	}
}
```

#### Adding New Sharing Modes

The framework's proxy pattern can be extended by creating new inner classes with different behaviors. However, the current three modes (BYPASS, ENFORCE, INHERITED) cover the standard use cases.

For specialized needs, consider:

##### Combining with FLS Enforcement
```apex
// Enforce both sharing AND FLS via USER_MODE
List<Account> accounts = QRY_Builder.selectFrom(Account.SObjectType)
	.fields(new List<String>{'Id', 'Name'})
	.withUserMode()
	.toList();
```

##### Creating Wrapper Methods
Create wrapper methods that set both sharing and security:
```apex
public static List<Account> findByIdSecure(Id accountId)
{
	// Enforce both sharing AND FLS using USER_MODE + stripInaccessible
	return QRY_Builder.selectFrom(Account.SObjectType)
		.fields(new List<String>{'Id', 'Name'})
		.condition(Account.Id).equals(accountId)
		.withUserMode()
		.stripInaccessible()
		.toList();
}
```

### Testing Sharing Behavior

#### Testing with Different Users

Create test users with different permissions to verify sharing:

```apex
@IsTest
private static void shouldRespectSharingRulesWhenEnforced()
{
	// Create a restricted user
	User restrictedUser = (User)TST_Builder.of(User.SObjectType)
		.withOverride(User.ProfileId, getRestrictedProfileId())
		.build();

	// Create a record the restricted user cannot access
	Account privateAccount = (Account)TST_Builder.of(Account.SObjectType)
		.withOverride(Account.Name, 'Private Account')
		.build();

	Test.startTest();

	System.runAs(restrictedUser)
	{
		// Query with sharing enforced
		List<Account> results = QRY_Builder.selectFrom(Account.SObjectType)
			.fields(new List<String>{'Name'})
			.condition(Account.Id).equals(privateAccount.Id)
			.withSharing()
			.toList();

		// Should not find the record due to sharing
		Assert.isTrue(results.isEmpty(), 'Restricted user should not see private account');
	}

	Test.stopTest();
}
```

#### Verifying Sharing Enforcement

```apex
@IsTest
private static void shouldBypassSharingWhenConfigured()
{
	User restrictedUser = (User)TST_Builder.of(User.SObjectType)
		.withOverride(User.ProfileId, getRestrictedProfileId())
		.build();

	Account privateAccount = (Account)TST_Builder.of(Account.SObjectType)
		.withOverride(Account.Name, 'Private Account')
		.build();

	Test.startTest();

	System.runAs(restrictedUser)
	{
		// Query with sharing bypassed
		List<Account> results = QRY_Builder.selectFrom(Account.SObjectType)
			.fields(new List<String>{'Name'})
			.condition(Account.Id).equals(privateAccount.Id)
			.bypassSharing()
			.toList();

		// Should find the record with sharing bypassed
		Assert.areEqual(1, results.size(), 'Should find private account with sharing bypassed');
	}

	Test.stopTest();
}
```

---

## Sharing Rules & Access

### Security vs Sharing

KernDX distinguishes between three security layers. Each layer can be enforced independently for maximum flexibility.

| Security Layer | What It Controls | Key Framework Class |
|----------------|------------------|---------------------|
| **Field-Level Security (FLS)** | Which fields a user can read/write | [`QRY_Builder`](reference/apex/QRY_Builder.md) (`.withUserMode()`, `.stripInaccessible()`) |
| **Object-Level Security (CRUD)** | Create/Read/Update/Delete on objects | [`QRY_Builder`](reference/apex/QRY_Builder.md) (`.withUserMode()`) |
| **Record-Level Security (Sharing)** | Which specific records a user can access | [`DML_Builder`](reference/apex/DML_Builder.md) / [`QRY_Builder`](reference/apex/QRY_Builder.md) |

#### Field-Level Security (FLS)

Controls which fields a user can read or modify.

**Option 1: Query-Level Enforcement via `withUserMode()`:**

Using `.withUserMode()` on [`QRY_Builder`](reference/apex/QRY_Builder.md) causes the query to execute with `AccessLevel.USER_MODE`. This enforces both FLS and CRUD directly in the SOQL execution:

- **FLS Enforcement:** Fields the user cannot read are automatically stripped from the results
- **CRUD Enforcement:** If the user lacks Read access to the object, the query throws an exception
- **Cache Bypass:** Caching is automatically disabled when security is enforced (prevents data leakage between users)

```apex
// If user lacks FLS access to AnnualRevenue, it's stripped from results
// If user lacks CRUD Read on Account, query throws exception
List<Account> accounts = QRY_Builder.selectFrom(Account.SObjectType)
	.fields(new List<String>{'Name', 'AnnualRevenue', 'Industry'})
	.withUserMode()
	.toList();
```

**Option 2: Post-Query Strip with `stripInaccessible()`:**
```apex
// Strip inaccessible fields after query execution
List<Account> accounts = QRY_Builder.selectFrom(Account.SObjectType)
	.fields(new List<String>{'Name', 'AnnualRevenue', 'Industry'})
	.stripInaccessible()
	.toList();
```

#### Object-Level Security (CRUD)

Controls Create, Read, Update, Delete permissions on objects.

**Option 1: Flow Integration with [`FLOW_CheckObjectPermissions`](reference/apex/FLOW_CheckObjectPermissions.md):**
```apex
FLOW_CheckObjectPermissions.DTO_Request request = new FLOW_CheckObjectPermissions.DTO_Request();
request.objectApiName = 'Account';

List<FLOW_CheckObjectPermissions.DTO_Response> perms =
	FLOW_CheckObjectPermissions.checkPermissions(new List<FLOW_CheckObjectPermissions.DTO_Request>{request});

if(perms[0].hasCreateAccess)
{
	// Proceed with insert
}
```

**Option 2: Query-Level Enforcement via `withUserMode()`:**
```apex
// Enforce CRUD at the query level — throws exception if user lacks Read access
List<Account> accounts = QRY_Builder.selectFrom(Account.SObjectType)
	.fields(new List<String>{'Name', 'Industry'})
	.withUserMode()
	.toList();
```

#### Record-Level Security (Sharing)

Controls which specific records a user can access. Controlled via sharing proxies as described in the [Record Sharing](#record-sharing) section.

#### AccessLevel Modes

Salesforce's [`AccessLevel`](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_enum_System_AccessLevel.htm) parameter controls FLS/CRUD enforcement at the database operation level:

| Mode | FLS/CRUD | Sharing | When Used |
|------|----------|---------|-----------|
| `AccessLevel.USER_MODE` | Enforced | Enforced (runs through user's sharing) | **Secure-by-default** for subscriber-reachable queries and DML (shipped package behaviour) |
| `AccessLevel.SYSTEM_MODE` | Bypassed | Controlled by proxy (class declaration / `.withSharing()` / `.bypassSharing()`) | Framework-internal reads, CMDT readers, log/orchestration writes — opt in via `.withSystemMode()` or `systemModeRequired()` |

Subscriber-reachable `QRY_Builder` and `DML_Builder` calls default to `USER_MODE` under the secure-by-default posture (v1.0 GA). SYSTEM_MODE is reserved for framework-internal operations and narrow, documented opt-outs. Framework-internal selectors override `SEL_Base.systemModeRequired()` to return `true`; individual calls use `.withSystemMode()`. An org-wide flip is available on `FeatureFlag.UserModeQueries_Enabled` / `UserModeDml_Enabled` as an emergency kill-switch only — see [Secure-by-Default Defaults](#secure-by-default-defaults). For details on how the sharing proxy classes layer on top of `AccessLevel.SYSTEM_MODE`, see [Record Sharing > AccessLevel Selection](#accesslevel-selection).

#### Combining All Three Security Layers

For maximum security in user-facing features, enforce CRUD + FLS + sharing on both the query and the DML transaction with `.withUserMode()`:

```apex
public with sharing class SecureAccountController
{
	public void createAccount(Account account)
	{
		// Insert with CRUD + FLS + sharing all enforced at the database level
		DML_Builder.newTransaction()
			.doInsert(account)
			.withUserMode()
			.execute();
	}

	public List<Account> queryAccounts()
	{
		// Query with CRUD + FLS + sharing all enforced via withUserMode()
		return QRY_Builder.selectFrom(Account.SObjectType)
			.fields(new List<String>{'Name', 'Industry'})
			.withUserMode()
			.toList();
	}
}
```

> Under the secure-by-default posture (v1.0), `.withUserMode()` is the runtime default for both queries and DML — the explicit call above documents intent and guards against an org that has flipped the `UserModeQueries_Enabled` / `UserModeDml_Enabled` kill-switch to `false`.

### Common Sharing Patterns

#### Public Site / Community Controllers

Community and portal users should only see records they have access to. Configure sharing enforcement in the controller constructor to ensure all operations respect the user's permissions.

**Why enforce sharing here?** External users accessing your application through [Experience Cloud](https://developer.salesforce.com/docs/atlas.en-us.communities_dev.meta/communities_dev/communities_dev_intro.htm) or a public site should never see records belonging to other users or organizations. Even if the OWD (Organization-Wide Default) is set correctly, explicitly enforcing sharing provides defense-in-depth.

```apex
public with sharing class CommunityAccountController
{
	public List<Account> getMyAccounts()
	{
		// USER_MODE enforces CRUD + FLS + sharing at the database level
		return QRY_Builder.selectFrom(Account.SObjectType)
			.fields(new List<String>{'Name', 'Industry'})
			.withUserMode()
			.toList();
	}

	public void updateAccount(Account account)
	{
		// USER_MODE DML fails if the community user lacks CRUD/FLS/sharing on the record
		DML_Builder.newTransaction()
			.doUpdate(account)
			.withUserMode()
			.execute();
	}
}
```

> `public with sharing` on the controller already enforces sharing for any inline SOQL, and `.withUserMode()` enforces CRUD + FLS + sharing at the database level for every `QRY_Builder` / `DML_Builder` call inside it — belt-and-braces for guest / external-user contexts.

#### System Batch Processing

Batch jobs often need to process all records in an object regardless of the running user's access. This is common for data maintenance, synchronization, and cleanup operations.

**Why bypass sharing here?** Batch jobs typically run as a specific user (often a service account or the user who scheduled the job). Without bypassing sharing, the batch would only process records that user can see, potentially leaving some records unprocessed. For system-level operations, you want to process the entire dataset.

```apex
public without sharing class BATCH_ProcessAllAccounts implements Database.Batchable<SObject>
{
	public Database.QueryLocator start(Database.BatchableContext context)
	{
		// SYSTEM_MODE + without-sharing proxy: process every record regardless of running user
		return QRY_Builder.selectFrom(Account.SObjectType)
			.fields(new List<String>{'Id', 'Name', 'Status__c'})
			.withSystemMode()
			.bypassSharing()
			.toQueryLocator();
	}

	public void execute(Database.BatchableContext context, List<Account> scope)
	{
		for(Account account : scope)
		{
			account.Status__c = 'Processed';
		}

		// SYSTEM_MODE DML + sharing bypass — explicit opt-out from the secure-by-default posture
		DML_Builder.newTransaction()
			.doUpdate(scope)
			.withSystemMode()
			.bypassSharing()
			.execute();
	}

	public void finish(Database.BatchableContext context)
	{
		// No static state to reset — each DML_Builder / QRY_Builder call is scoped to its
		// transaction via the fluent methods above. Log bypass rationale for audit:
		LOG_Builder.build()
			.info('BATCH_ProcessAllAccounts finished with sharing bypass (system maintenance)')
			.emitAt('BATCH_ProcessAllAccounts.finish');
	}
}
```

> `without sharing` on the class + `.withSystemMode().bypassSharing()` on each builder call makes the bypass explicit at every layer. Prefer this over a single top-of-transaction flag — the explicit chaining shows up in code review and leaves an audit trail at the call site.

#### Trigger Actions

Trigger actions should use `inherited sharing` to respect whatever context the trigger runs in. Triggers execute with the permissions of the user who caused the DML operation, but typically have system-level access to the records being processed.

**Why inherited sharing here?** Trigger actions are reusable components that may be invoked in different contexts. Using `inherited sharing` ensures they work correctly whether called from a user context (enforcing sharing) or a system context (bypassing sharing). When a trigger action needs to override the caller's context for a specific DML or query call, use the fluent `.withSystemMode()` / `.withUserMode()` / `.bypassSharing()` methods on the relevant `DML_Builder` / `QRY_Builder` call at the point of use.

```apex
public inherited sharing class TRG_AccountSetDefaults extends TRG_Base implements IF_Trigger.BeforeInsert
{
	public override void beforeInsert(List<SObject> newRecords)
	{
		// inherited sharing - trigger runs in the caller's sharing context.
		// This handler mutates in-memory only (no DML) so no access-mode decisions are needed.
		for(Account account : (List<Account>)newRecords)
		{
			if(String.isBlank(account.Industry))
			{
				account.Industry = 'Other';
			}
		}
	}
}
```

#### Logging Operations

[`LOG_Builder`](reference/apex/LOG_Builder.md) internally bypasses sharing to ensure logging always succeeds:

```apex
// Logging works regardless of current user's sharing context
LOG_Builder.build().error(exception).emitAt('MyClass.myMethod');
```

**Why?** Error logs must be captured regardless of the current user's permissions. Logging failures would hide important diagnostic information.

### Security Considerations

#### When to Bypass Sharing

Bypass sharing with `.withSystemMode().bypassSharing()` on the relevant `QRY_Builder` / `DML_Builder` call, and log the rationale via `TRG_Base.setBypassReason(String)`:

| Scenario | Example |
|----------|---------|
| System batch processing | Nightly data cleanup jobs |
| Platform event triggers | Processing events from any context |
| Integration handlers | Receiving data from external systems |
| Logging and auditing | Ensuring all errors are captured |
| Share object management | Creating/deleting share records |
| Scheduled jobs | Jobs running as a specific user but needing full access |
| Test data factories | Tests need to create data regardless of test user |

#### When to Enforce Sharing

Enforce CRUD + FLS + sharing with `.withUserMode()` on the relevant `QRY_Builder` / `DML_Builder` call. Under the secure-by-default posture, this is the framework default for subscriber-reachable calls — the explicit method makes intent clear and guards against the kill-switch flag being flipped.

| Scenario | Example |
|----------|---------|
| Community/Portal pages | External users accessing data |
| Public sites | Unauthenticated or guest users |
| User-initiated actions | Any UI-driven operation |
| REST APIs exposed to partners | External system access |
| Reports and dashboards | User-facing data views |
| Lightning components | User interface interactions |

#### Cache Security

The framework automatically disables caching when security is enforced:

```apex
// Caching disabled when using withUserMode() - prevents data leakage across users
List<Account> accounts = QRY_Builder.selectFrom(Account.SObjectType)
	.fields(new List<String>{'Name'})
	.withUserMode()
	.toList();
```

**Why?** Cached query results could leak data between users with different access levels.

---

## Testing

Security features are tested by verifying that permission checks throw the correct exceptions for unauthorized
users and that sharing enforcement restricts record visibility. The framework's internal security classes are
tested by KernDX itself; your tests should focus on verifying that your code correctly calls the security APIs and
handles exceptions.

**Testing CRUD/FLS enforcement via `withUserMode()`:**

```apex
@IsTest
private static void shouldEnforceCrudWithUserMode()
{
	User restrictedUser = TST_Factory.newUser('Standard User');

	System.runAs(restrictedUser)
	{
		try
		{
			QRY_Builder.selectFrom(Account.SObjectType)
				.fields(new List<String>{'Name'})
				.withUserMode()
				.toList();
			Assert.fail('Should throw exception for user without Account read access');
		}
		catch(Exception error)
		{
			Assert.isNotNull(error.getMessage(), 'Error message should be set');
		}
	}
}
```

**Testing sharing enforcement with QRY_Builder:**

```apex
@IsTest
private static void shouldRespectSharingRules()
{
	Account privateAccount = (Account)TST_Builder.of(Account.SObjectType).build();

	User restrictedUser = TST_Factory.newUser('Standard User');

	System.runAs(restrictedUser)
	{
		List<Account> results = QRY_Builder.selectFrom(Account.SObjectType)
			.condition(Account.Id).equals(privateAccount.Id)
			.withSharing()
			.toList();

		Assert.areEqual(0, results.size(), 'Should not see records outside sharing rules');
	}
}
```

**Testing encryption round-trips:**

```apex
@IsTest
private static void shouldEncryptAndDecryptSuccessfully()
{
	String plainText = 'sensitive-api-token-123';

	String encrypted = UTIL_SessionEncryption.encrypt(plainText);
	Assert.areNotEqual(plainText, encrypted, 'Encrypted value should differ from plain text');

	String decrypted = UTIL_SessionEncryption.decrypt(encrypted);
	Assert.areEqual(plainText, decrypted, 'Decrypted value should match original');
}
```

For detailed sharing test patterns including `System.runAs()` and share record verification, see the
[Testing Sharing Behavior](#testing-sharing-behavior) subsection under Record Sharing.

---

## Capability Matrix (for Analysts)

| Capability | Control Point | Class/Method | Notes |
|---|---|---|---|
| CRUD/FLS enforcement | Query-level enforcement | `QRY_Builder.withUserMode()` | Enforces CRUD and FLS at database level |
| CRUD/FLS enforcement | DML-level enforcement | `DML_Builder.withUserMode()` | Enforces CRUD and FLS on DML transactions |
| Post-query FLS strip | Field removal after query | `QRY_Builder.stripInaccessible()` | Removes inaccessible fields from results |
| Session encryption | Runtime data protection | `UTIL_SessionEncryption.encrypt()` / `.decrypt()` | AES-256 with automatic key management |
| Query sharing enforcement | Per-query control | `.withSharing()` / `.bypassSharing()` / `.withUserMode()` | Applied on `QRY_Builder` queries |
| DML sharing enforcement | Per-transaction control | `DML_Builder.newTransaction().bypassSharing()` | Applied on DML transactions |
| Selector-wide SYSTEM_MODE lock | Selector-level override | `SEL_Base.systemModeRequired()` override | Framework-internal selectors opt out of USER_MODE default |
| Org-wide access mode kill-switch | Custom metadata flag | `FeatureFlag.UserModeQueries_Enabled` / `UserModeDml_Enabled` | Emergency rollback only — flips all queries/DML to SYSTEM_MODE |
| Bypass audit trail | Platform event | `TRG_Base.bypass*()` + `LogEntryEvent__e` category `BypassEvent` | Attach reason via `TRG_Base.setBypassReason(String)` |

---

## Anti-Patterns

| Anti-Pattern | Why It's Wrong | Instead |
|---|---|---|
| Performing DML without CRUD/FLS checks in user-facing code | Exposes data to unauthorized access and fails Salesforce security review | Use `.withUserMode()` on queries or `.stripInaccessible()` for post-query FLS |
| Using hardcoded field API name strings for security checks | Breaks silently when fields are renamed or deleted | Use `SObjectField` token references (e.g., `Account.Name`) for compile-time safety |
| Storing secrets in plain text (custom fields, custom settings) | Credentials are visible to admins and exposed in SOQL queries | Use `UTIL_SessionEncryption` for runtime encryption or Named Credentials for API secrets |
| Relying solely on `inherited sharing` for security | Sharing context depends on the caller and may be unpredictable | Be explicit: use `with sharing` for user-facing code and `without sharing` only when justified |
| Using `.bypassSharing()` without documentation | Unauditable privilege escalation that may violate compliance requirements | Document every sharing bypass with a code comment explaining the business justification |

---

## Best Practices

### 1. Always Enforce CRUD/FLS in User-Facing Code

```apex
// WRONG: No permission checks
public static List<Account> getAccounts()
{
	return [SELECT Id, Name FROM Account]; // Executes even if user lacks read permission
}

// CORRECT: Enforce CRUD/FLS at the query level
public static List<Account> getAccounts()
{
	return QRY_Builder.selectFrom(Account.SObjectType)
		.fields(new List<String>{'Name', 'Industry'})
		.withUserMode()
		.toList();
}
```

### 2. Handle Security Exceptions Gracefully

```apex
public static List<Account> performSecureQuery()
{
	try
	{
		return QRY_Builder.selectFrom(Account.SObjectType)
			.fields(new List<String>{'Name', 'AnnualRevenue'})
			.withUserMode()
			.toList();
	}
	catch(Exception e)
	{
		// Log the error
		LOG_Builder.build().error(e).emitAt('MyClass.performSecureQuery');

		// Show user-friendly message
		throw new AuraHandledException('You do not have permission to perform this operation.');
	}
}
```

### 3. Encrypt Sensitive Data in Transit

```apex
// WRONG: Passing sensitive data in plain text between controllers
String token = userProvidedToken;
Cache.Session.put('api_token', token);

// CORRECT: Encrypt before passing through session state
String encryptedToken = UTIL_SessionEncryption.encrypt(userProvidedToken);
Cache.Session.put('api_token', encryptedToken);

// For persistent storage, use Shield Platform Encryption or Crypto.encrypt()
// with external key management instead of UTIL_SessionEncryption
```

### 4. Be Explicit About Sharing Context

Declare sharing explicitly on the class and call the relevant access-mode method on each `DML_Builder` / `QRY_Builder` call when it matters for the feature:

```apex
// DO: Explicit sharing declaration + explicit USER_MODE on secure calls
public with sharing class MyController
{
	@AuraEnabled
	public static List<Account> getAccounts()
	{
		return QRY_Builder.selectFrom(Account.SObjectType)
			.fields(new List<String>{'Name', 'Industry'})
			.withUserMode()
			.toList();
	}

	@AuraEnabled
	public static void saveAccount(Account account)
	{
		DML_Builder.newTransaction()
			.doUpdate(account)
			.withUserMode()
			.execute();
	}
}

// DON'T: Rely on implicit/unknown sharing
public class MyController
{
	// Missing sharing declaration — defaults are org-dependent
}
```

### 5. Keep Sharing Decisions at the Call Site

Access mode and sharing are chosen per-call via fluent methods — there is no transaction-scoped static flag to save and restore. Make the bypass explicit at the exact call that needs it:

```apex
// Temporary, localised system operation — no cleanup needed
DML_Builder.newTransaction()
	.doUpdate(records)
	.withSystemMode()
	.bypassSharing()
	.execute();

// Surrounding calls still follow the secure-by-default posture (USER_MODE)
List<Account> userVisibleAccounts = QRY_Builder.selectFrom(Account.SObjectType)
	.fields(new List<String>{'Id', 'Name'})
	.toList();
```

Each builder chain carries its own access mode and sharing selection — they do not leak between calls.

### 6. Don't Log Sensitive Data

```apex
// WRONG: Logs plain text password
LOG_Builder.build().debug('User password: ' + password).emitAt('MyClass.login');

// CORRECT: Never log sensitive data
LOG_Builder.build().debug('Password validation completed').emitAt('MyClass.login');
```

### 7. Combine Security Layers

```apex
public with sharing class SecureAccountManager
{
	public static List<Account> getAccounts()
	{
		// Layer 1: Enforce CRUD + FLS + sharing via withUserMode()
		return QRY_Builder.selectFrom(Account.SObjectType)
			.fields(new List<String>{'Name', 'Industry'})
			.withUserMode()
			.toList();
	}

	public static void createAccount(String name)
	{
		// Layer 1: USER_MODE DML enforces CRUD + FLS + sharing at database level
		Account account = new Account(Name = name);
		DML_Builder.newTransaction()
			.doInsert(account)
			.withUserMode()
			.execute();

		// Layer 2: Audit logging
		LOG_Builder.build().info('Account created').emitAt('SecureAccountManager.createAccount');
	}
}
```

### 8. Decrypt Only When Necessary

```apex
// WRONG: Decrypt and store in memory longer than needed
String decryptedToken = UTIL_SessionEncryption.decrypt(encryptedToken);
// ... many lines of code ...
makeApiCall(decryptedToken);

// CORRECT: Decrypt just before use
makeApiCall(UTIL_SessionEncryption.decrypt(encryptedToken));
```

### 9. Use `inherited sharing` for Security Classes

```apex
// CORRECT: Respect caller's sharing model
public inherited sharing class SecureDataAccess
{
	public static List<Account> getAccounts()
	{
		// This query respects the calling context's sharing rules
		return QRY_Builder.selectFrom(Account.SObjectType)
			.fields(new List<String>{'Id', 'Name'})
			.toList();
	}
}
```

### 10. Use Inherited Sharing for Reusable Code

When creating utility methods called from different contexts:

```apex
// DO: Use inherited sharing for utilities
public inherited sharing class MyUtility
{
	public static void processRecords(List<SObject> records)
	{
		// Sharing determined by caller's context
		DML_Builder.newTransaction().doUpdate(records).execute();
	}
}

// DON'T: Hardcode sharing in reusable code
public without sharing class MyUtility  // Always bypasses - may be security risk
```

### 11. Document Sharing Decisions

Add ApexDoc comments explaining why a specific sharing mode is used, and record the bypass rationale via `TRG_Base.setBypassReason(String)` so it lands on the `LogEntryEvent__e` audit trail with category `BypassEvent`:

```apex
/**
 * @description Processes all accounts regardless of user access.
 * Uses sharing bypass because this is a system-level batch operation that must
 * process every record for data-integrity reconciliation.
 */
public void execute(Database.BatchableContext context, List<Account> scope)
{
	TRG_Base.setBypassReason('Nightly data-integrity reconciliation batch');

	DML_Builder.newTransaction()
		.doUpdate(scope)
		.withSystemMode()
		.bypassSharing()
		.execute();
}
```

### 12. Combine Sharing with FLS/CRUD Checks

For user-facing features, enforce both sharing and security:

```apex
// Enforce complete security for user-initiated operations
List<Account> accounts = QRY_Builder.selectFrom(Account.SObjectType)
	.fields(new List<String>{'Id', 'Name', 'Industry'})
	.withUserMode()
	.stripInaccessible()
	.toList();
```

### 13. Test Sharing Behavior

Include tests that verify sharing works as expected:

```apex
@IsTest
private static void shouldEnforceSharingForCommunityUser()
{
	// Test with restricted user
	// Verify expected records are/aren't accessible
}

@IsTest
private static void shouldBypassSharingForBatchProcess()
{
	// Test with restricted user running batch
	// Verify batch can access all records
}
```

### 14. Audit Sharing Bypasses

Maintain a list of code locations that bypass sharing and review periodically:

| Class | Method | Bypass Reason |
|-------|--------|---------------|
| `BATCH_ProcessAllAccounts` | `execute()` | System batch requires full access |
| `TRG_LogEntryEvent` | `afterInsert()` | Logging must always succeed |
| `API_IntegrationHandler` | `processPayload()` | Integration data from trusted source |

---

## Quick Reference

### Encryption/Decryption

| Operation | Method | Returns |
|-----------|--------|---------|
| Encrypt plain text | `UTIL_SessionEncryption.encrypt(String)` | Base64-encoded encrypted string |
| Decrypt encrypted text | `UTIL_SessionEncryption.decrypt(String)` | Plain text string |

**Key Management:**
- Algorithm: AES256 with SHA-256 digest
- Key Storage: Platform cache (session cache preferred, org cache fallback)
- Key Expiry: 8 hours (28,800 seconds)
- Automatic rotation: Yes

### Sharing Reference Table

| Class | Sharing Declaration | Purpose |
|-------|---------------------|---------|
| [`DML_Builder`](reference/apex/DML_Builder.md) | `inherited sharing` | Bulk DML operations with sharing proxy factory |
| `DML_SharingProxy.DatabaseProxy` | `inherited sharing` | Base DML proxy (virtual) |
| `DML_SharingProxy.DatabaseProxyWithoutSharing` | `without sharing` | DML with sharing bypassed |
| `DML_SharingProxy.DatabaseProxyWithSharing` | `with sharing` | DML with sharing enforced |
| [`QRY_Builder`](reference/apex/QRY_Builder.md) | `inherited sharing` | Fluent query builder |
| `QRY_Engine` | `inherited sharing` | Query executor |
| `QRY_Engine.WithSharingExecutor` | `with sharing` | Query with sharing enforced |
| `QRY_Engine.WithoutSharingExecutor` | `without sharing` | Query with sharing bypassed |
| [`DML_Transaction`](reference/apex/DML_Transaction.md) | `inherited sharing` | Transaction management |
| [`TST_Builder`](reference/apex/TST_Builder.md) | `without sharing` | Test data factory |
| [`UTIL_Sharing`](reference/apex/UTIL_Sharing.md) | `inherited sharing` | Share record management |
| [`UTIL_SessionEncryption`](reference/apex/UTIL_SessionEncryption.md) | `with sharing` | Session encryption |

### Common Patterns

**Secure Query Pattern (CRUD + FLS + Sharing):**
```apex
List<Account> accounts = QRY_Builder.selectFrom(Account.SObjectType)
	.fields(new List<String>{'Name', 'AnnualRevenue'})
	.withUserMode()
	.toList();
```

**Secure Query Pattern (Strip Inaccessible, preserves partial results):**
```apex
List<Account> accounts = QRY_Builder.selectFrom(Account.SObjectType)
	.fields(new List<String>{'Name', 'AnnualRevenue'})
	.withUserMode()
	.stripInaccessible()
	.toList();
```

**Secure DML Pattern (CRUD + FLS + Sharing):**
```apex
DML_Builder.newTransaction()
	.doInsert(accountList)
	.withUserMode()
	.execute();
```

**Sharing-Bypass DML Pattern (system operations only):**
```apex
DML_Builder.newTransaction()
	.doInsert(accountList)
	.withSystemMode()
	.bypassSharing()
	.execute();
```

**Encryption Pattern (Session-Scoped):**
```apex
// Encrypt for secure session-scoped passing
String encrypted = UTIL_SessionEncryption.encrypt(sensitiveData);
Cache.Session.put('secure_payload', encrypted);

// Decrypt within the same session
String decrypted = UTIL_SessionEncryption.decrypt(
	(String)Cache.Session.get('secure_payload')
);
```

---

## Related Documentation
- [DML - Guide](DML%20-%20Guide.md) - [`TST_Builder`](reference/apex/TST_Builder.md) for secure test data, DML_Transaction and bulk DML patterns
- [Utilities - Guide](Utilities%20-%20Guide.md) - [`LOG_Builder`](reference/apex/LOG_Builder.md) for security event logging
- [Web Services - Guide](Web%20Services%20-%20Guide.md) - API integration patterns
- [Selectors - Guide](Selectors%20-%20Guide.md) - Query patterns with [`QRY_Builder`](reference/apex/QRY_Builder.md)
- [Logging - Guide](Logging%20-%20Guide.md) - Error logging that bypasses sharing
- [Triggers - Guide](Triggers%20-%20Guide.md) - Trigger action patterns with inherited sharing

**External References:**
- [Salesforce Apex Security Guide](https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_security_sharing_chapter.htm)
- [Salesforce Crypto Class Reference](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_classes_restful_crypto.htm)
- [Shield Platform Encryption](https://developer.salesforce.com/docs/atlas.en-us.securityImplGuide.meta/securityImplGuide/security_pe_overview.htm)
- [OWASP Top 10](https://owasp.org/www-project-top-ten/)
- [Salesforce Sharing and Visibility Designer Guide](https://developer.salesforce.com/docs/atlas.en-us.securityImplGuide.meta/securityImplGuide/security_data_access.htm)

**Framework Classes:**
- [`UTIL_SessionEncryption`](reference/apex/UTIL_SessionEncryption.md) - Encryption/decryption
- [`DML_Builder`](reference/apex/DML_Builder.md) - DML operations with sharing proxy
- [`QRY_Builder`](reference/apex/QRY_Builder.md) - Fluent query builder with sharing and CRUD/FLS control
- [`DML_Transaction`](reference/apex/DML_Transaction.md) - Transaction management
- [`UTIL_Sharing`](reference/apex/UTIL_Sharing.md) - Share record management
- [`TST_Builder`](reference/apex/TST_Builder.md) - Test data factory
- [`FLOW_CheckObjectPermissions`](reference/apex/FLOW_CheckObjectPermissions.md) - Object permission checks for Flows

---

*This guide is part of the KernDX Developer Documentation. For questions or contributions, please contact the library maintainers.*
