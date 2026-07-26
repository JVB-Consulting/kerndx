---
navOrder: 16
---

# Security - Guide

**Framework:** KernDX
**Package Type:** Managed Package

> **If you installed KernDX as a managed package:** prefix framework class references with your installed namespace (for example, `AcmeLib.QRY_Builder`).

**Target Audience:**

- **Developers** writing code that reads or writes data and needs to honour the running user's permissions, sharing, and encryption.
- **Architects** designing how an org protects sensitive data and enforces access.
- **Business analysts** who want to understand the security capabilities, the encryption options, and what they do and do not cover for compliance.
- **Security reviewers** auditing where sharing is enforced, and where (and why) it is deliberately bypassed.

---

## What problem does this solve?

Every Salesforce app has to answer the same questions on every read and write: can this user see this object and field, can they see this particular record, and is any sensitive value about to be written down in plain text. Getting one of those wrong is how data leaks reach a security review.

This guide shows you how KernDX answers them for you. By default, queries and saves run with the current user's read/write permissions and record sharing enforced (Salesforce calls this `USER_MODE`), sensitive values can be masked before they ever hit the database, and short-lived secrets can be encrypted in memory.

Read this if you write Apex that reads or writes data, design security patterns for an org, or need to show an auditor where access is enforced. Use it whenever code touches records that not every user should see.

---

## Mental model

Think of KernDX security as a checkpoint that every query and save passes through on its way to the database. By default the checkpoint asks "is this user allowed to do this?" and turns away anything they have no permission for: a field they cannot read, a record they cannot see, an object they cannot change. You can wave a specific operation through the checkpoint on purpose (a system batch that must touch every record), and each time you do, the checkpoint writes down what was waved through and why.

Encryption and masking are separate tools at the same checkpoint: encryption scrambles a value you need back later, and masking redacts a value that should never be stored readable in the first place.

---

## Use this when

- You write Apex that reads or writes records and want the current user's permissions and record sharing enforced without hand-coding the checks.
- You need to choose at run time whether a query or save respects sharing rules, so the same logic can run for a UI user and for a system batch.
- You want to redact secrets or personal data on records before they are saved, configured in metadata rather than code.
- You need to encrypt a short-lived value (a token passed between wizard steps, for example) without managing keys yourself.
- You have to show an auditor where access is enforced, and where it is deliberately bypassed.

## Don't use this when

- The native Salesforce control already does what you need. Plain `with sharing` Apex enforces sharing without the framework; `WITH USER_MODE` SOQL enforces permissions inline. Choose KernDX when you want that behaviour decided at run time, or applied consistently in one place.
- You need long-term encrypted storage or compliance-grade key management. `UTIL_SessionEncryption` keys expire within 8 hours and are lost if the cache clears; use [Shield Platform Encryption](https://developer.salesforce.com/docs/atlas.en-us.securityImplGuide.meta/securityImplGuide/security_pe_overview.htm) or external key management instead.
- You want org-wide security monitoring, config-drift detection, backup, or login-anomaly alerts. KernDX gives you mechanisms inside your own code, not an org-security monitor; see [What KernDX Does Not Monitor](#what-kerndx-does-not-monitor).

---

## Quick Start

You want to read records but only the ones, and only the fields, that the current user is allowed to see. That is the most common security need, and it takes one method. Here is the simplest form:

```apex
// Enforce CRUD, FLS, and sharing in a single query
List<Account> accounts = QRY_Builder.selectFrom(Account.SObjectType)
	.fields(new List<String>{'Name', 'Industry'})
	.withUserMode()
	.toList();
```

If you need sharing enforced but not field-level security (a query running in SYSTEM_MODE), use the sharing controls instead:

```apex
// Enforce sharing and strip inaccessible fields
List<Account> accounts = QRY_Builder.selectFrom(Account.SObjectType)
	.fields(new List<String>{'Name', 'Industry'})
	.withSharing()
	.stripInaccessible()
	.toList();
```

For more detail, keep reading the sections below.

---

## Table of Contents

<details>
<summary>Expand</summary>

1. [What problem does this solve?](#what-problem-does-this-solve)
2. [Mental model](#mental-model)
3. [Use this when](#use-this-when) / [Don't use this when](#dont-use-this-when)
4. [Quick Start](#quick-start)
5. [Quick Navigation](#quick-navigation)
6. [What is the Security framework?](#what-is-the-security-framework)
    - [Key Concepts](#key-concepts)
    - [Framework Philosophy](#framework-philosophy)
7. [How does it work?](#how-does-it-work)
    - [Architecture Diagram](#architecture-diagram)
8. [Safe by Default](#safe-by-default)
9. [How to opt out](#how-to-opt-out)
10. [Data Encryption & Decryption (UTIL_SessionEncryption)](#data-encryption--decryption-util_sessionencryption)
    - [What it does](#what-it-does)
        - [CRITICAL ARCHITECTURAL WARNING](#critical-architectural-warning)
    - [How does it compare to native Salesforce encryption?](#how-does-it-compare-to-native-salesforce-encryption)
        - [Salesforce Out-of-the-Box Alternatives](#salesforce-out-of-the-box-alternatives)
        - [Pros & Cons Comparison](#pros--cons-comparison)
        - [When to Use KernDX UTIL_SessionEncryption](#when-to-use-kerndx-util_sessionencryption)
        - [When to Use OOTB Encryption](#when-to-use-ootb-encryption)
        - [Example Comparison](#example-comparison)
        - [Critical Warning: Data Loss Risk](#critical-warning-data-loss-risk)
    - [Why choose this over the built-in Crypto class?](#why-choose-this-over-the-built-in-crypto-class)
    - [Encryption Methods](#encryption-methods)
        - [Encrypt Plain Text](#encrypt-plain-text)
        - [Decrypt Encrypted Text](#decrypt-encrypted-text)
    - [How Automatic Key Management Works](#how-automatic-key-management-works)
    - [Use Cases](#use-cases)
        - [Secure Multi-Step Wizard State](#secure-multi-step-wizard-state)
        - [Temporary OAuth Token Caching](#temporary-oauth-token-caching)
        - [Secure Parameter Passing via Platform Events](#secure-parameter-passing-via-platform-events)
    - [Important Considerations](#important-considerations)
11. [Data Masking](#data-masking)
    - [What Data Masking Does](#what-data-masking-does)
    - [What Masking Is Not](#what-masking-is-not)
    - [Configuring Masking](#configuring-masking)
    - [Secret Scanning in CI](#secret-scanning-in-ci)
12. [Record Sharing](#record-sharing)
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
13. [Sharing Rules & Access](#sharing-rules--access)
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
14. [Security Governance Evidence](#security-governance-evidence)
    - [Masking Configuration as a Version-Controlled Record](#masking-configuration-as-a-version-controlled-record)
    - [Access-Review Primitives](#access-review-primitives)
15. [Security Boundaries and Portal Hardening](#security-boundaries-and-portal-hardening)
    - [Parameter-Based Record Access in Portals](#parameter-based-record-access-in-portals)
    - [Flow Input-Variable Hygiene](#flow-input-variable-hygiene)
    - [What KernDX Does Not Monitor](#what-kerndx-does-not-monitor)
16. [Testing](#testing)
17. [Capability Matrix (for Analysts)](#capability-matrix-for-analysts)
18. [Anti-Patterns](#anti-patterns)
19. [Best Practices](#best-practices)
    - [Always Enforce CRUD/FLS in User-Facing Code](#always-enforce-crudfls-in-user-facing-code)
    - [Handle Security Exceptions Gracefully](#handle-security-exceptions-gracefully)
    - [Encrypt Sensitive Data in Transit](#encrypt-sensitive-data-in-transit)
    - [Be Explicit About Sharing Context](#be-explicit-about-sharing-context)
    - [Keep Sharing Decisions at the Call Site](#keep-sharing-decisions-at-the-call-site)
    - [Don't Log Sensitive Data](#dont-log-sensitive-data)
    - [Combine Security Layers](#combine-security-layers)
    - [Decrypt Only When Necessary](#decrypt-only-when-necessary)
    - [Use inherited sharing for Security Classes](#use-inherited-sharing-for-security-classes)
    - [Use Inherited Sharing for Reusable Code](#use-inherited-sharing-for-reusable-code)
    - [Document Sharing Decisions](#document-sharing-decisions)
    - [Combine Sharing with FLS/CRUD Checks](#combine-sharing-with-flscrud-checks)
    - [Test Sharing Behavior](#test-sharing-behavior)
    - [Audit Sharing Bypasses](#audit-sharing-bypasses)
20. [Quick Reference](#quick-reference)
    - [Encryption/Decryption](#encryptiondecryption)
    - [Sharing Reference Table](#sharing-reference-table)
    - [Common Patterns](#common-patterns)
21. [Related Documentation](#related-documentation)

</details>

---

## Quick Navigation

| I am a...     | I need to...                    | Go to...                                                                            |
|---------------|---------------------------------|-------------------------------------------------------------------------------------|
| **Architect** | Design security patterns        | [How does it work?](#how-does-it-work)                                              |
| **Architect** | Plan sharing enforcement        | [Record Sharing](#record-sharing)                                                   |
| **Developer** | Enforce CRUD/FLS via queries    | [Quick Start](#quick-start)                                                         |
| **Developer** | Encrypt sensitive data          | [Data Encryption & Decryption](#data-encryption--decryption-util_sessionencryption) |
| **Developer** | Redact sensitive data on save   | [Data Masking](#data-masking)                                                       |
| **Analyst**   | Understand security controls    | [Capability Matrix](#capability-matrix-for-analysts)                                |
| **Analyst**   | Review security quick reference | [Quick Reference](#quick-reference)                                                 |
| **Reviewer**  | Produce governance evidence     | [Security Governance Evidence](#security-governance-evidence)                       |

---

## What is the Security framework?

This guide covers all of the security capabilities KernDX provides: data encryption, record-level sharing, and the patterns that enforce field, object, and record permissions. Together they help you follow Salesforce security best practice, protect sensitive data, and control who can reach which records.

> **What this framework is responsible for:** The Security framework enforces access control (object create/read/update/delete permissions, field-level security, and record sharing) and protects sensitive data through encryption. It does not contain business logic or decide what data your app reads. Its job is narrower: it checks that the current user is allowed to perform an operation, and throws an exception when they are not.

The framework gives you three main security capabilities:

1. **Data encryption** ([`UTIL_SessionEncryption`](reference/apex/UTIL_SessionEncryption.md)): encrypt and decrypt sensitive values in memory, with the key managed for you.
2. **Record sharing** ([`UTIL_Sharing`](reference/apex/UTIL_Sharing.md), [`DML_Builder`](reference/apex/DML_Builder.md)): decide at run time whether Salesforce sharing rules apply, instead of fixing it in code.
3. **Query security** ([`QRY_Builder`](reference/apex/QRY_Builder.md)): combinable options that enforce object create/read/update/delete permissions (CRUD) and field-level security (FLS) on a query, through `.withUserMode()` and `.stripInaccessible()`.

> **What sits inside this framework:** in-memory encryption (`UTIL_SessionEncryption`), sharing control on both queries (`QRY_Builder`) and saves (`DML_Builder`), and CRUD/FLS enforcement through `QRY_Builder.withUserMode()` and `QRY_Builder.stripInaccessible()`.

> **A note on namespaces:** the code examples here leave off the namespace prefix for readability. If you have installed KernDX as a managed package, prefix framework class references with your installed namespace (for example, `YourNamespace.QRY_Builder`).

### Key Concepts

| Term                                                                                                                          | Description                                                                           |
|-------------------------------------------------------------------------------------------------------------------------------|---------------------------------------------------------------------------------------|
| **[Sharing Rules](https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_security_sharing_rules.htm)** | Salesforce record-level security determining which users can access which records     |
| **[CRUD](https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_classes_perms_enforcing.htm)**         | Object-level permissions (Create, Read, Update, Delete)                               |
| **[FLS](https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_classes_perms_fls.htm)**                | Field-Level Security - permissions on individual fields                               |
| **[AccessLevel](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_enum_System_AccessLevel.htm)**    | Salesforce's programmatic mode for Database operations (`SYSTEM_MODE` vs `USER_MODE`) |
| **Sharing Proxy**                                                                                                             | Inner class pattern that executes operations with specific sharing context            |

### Framework Philosophy

Four ideas shape how KernDX handles security. Each one exists to prevent a common way that access controls quietly go wrong.

1. **Choose sharing on purpose, not by accident.** Whether a piece of code respects sharing rules should be a deliberate decision you can see, not something it inherited without anyone noticing.
2. **Let the context decide at run time.** The same logic may run from a UI button, a nightly batch, and a trigger, and each may need different sharing. You set the behaviour when the code runs, not when it compiles.
3. **Route data access through one place.** Queries and saves flow through framework classes, so a security policy can be applied in one spot rather than re-checked everywhere.
4. **Layer the protections.** Record sharing, field-level security, and object permissions are separate concerns. You can turn each on independently, so a gap in one does not silently open the others.

---

## How does it work?

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

The security framework works in layers. You turn each one on independently and combine them as a feature needs:

1. **Object and field permissions (CRUD/FLS).** `QRY_Builder.withUserMode()` enforces object permissions and field-level security right inside the query; `QRY_Builder.stripInaccessible()` quietly drops fields the user cannot read from the results.
2. **Record sharing.** `DML_Builder` and `QRY_Builder` decide at run time whether a query or save respects sharing rules (`with sharing`), ignores them (`without sharing`), or follows whatever the caller chose (`inherited sharing`). They do this through a small "proxy" class, explained below.
3. **Query security options.** On a query, `QRY_Builder` offers `withUserMode()` (enforce object permissions, field security, and sharing at the database), `stripInaccessible()` (remove unreadable fields after the query), and `withSharing()` / `bypassSharing()` (control sharing for a query that runs without full permission enforcement).
4. **Data protection.** `UTIL_SessionEncryption` encrypts sensitive values with AES-256 and manages the key for you.

The layers do not depend on one another: you can enforce field security without enforcing sharing, or control sharing without checking object permissions. The starting point matters most: **every query and save your own code can reach runs with the current user's permissions and sharing enforced by default** (`AccessLevel.USER_MODE`). So a developer who does nothing special still gets the safe behaviour.

A few framework-internal selectors do need to skip those checks, for example readers of custom metadata, framework-owned objects, and system schema. They opt out by overriding the `systemModeRequired()` hook on `SEL_Base`. If you ever need to roll the secure default back across the whole org in an incident, there is a master off-switch you can flip in metadata without a deployment: the `FeatureFlag.UserModeQueries_Enabled` / `UserModeDml_Enabled` records, described in [Safe by Default](#safe-by-default) below.

---

## Safe by Default

The safe behaviour is on automatically. You step outside it only when you choose to. Every query and save your code can reach runs with the current user's permissions and sharing enforced (`AccessLevel.USER_MODE`) unless you say otherwise. In practice:

- `new SEL_Account().findById(id)` runs in USER_MODE (field security, object permissions, and sharing all enforced).
- `QRY_Builder.selectFrom(Account.SObjectType)...toList()` runs in USER_MODE.
- `DML_Builder.newTransaction().doInsert(record).execute()` runs in USER_MODE.

So a developer who writes a normal query gets the protected behaviour without thinking about it. Two configuration records (`FeatureFlag__mdt`) drive this default:

- `FeatureFlag.UserModeQueries_Enabled` controls `QRY_Builder` / `SEL_Base.query`.
- `FeatureFlag.UserModeDml_Enabled` controls `DML_Builder` / `DML_SharingProxy.defaultAccessLevel`.

Both ship turned on (`IsEnabledByDefault__c = true`).

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

**Opting a whole selector out (when you write your own `SEL_*` class):**

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

The `systemModeRequired()` hook on `SEL_Base` is `global virtual`, so you can override it in your own selectors. When it returns `true`, every `findById`, `findByField`, and `query`-getter call through that selector runs in `AccessLevel.SYSTEM_MODE` (all permission and sharing checks skipped), whatever the flag is set to.

**Emergency off-switch (metadata only, no deployment needed):**

Go to Setup, then Custom Metadata Types, then FeatureFlag, edit `UserModeQueries_Enabled`, set `IsEnabledByDefault__c = false`, and save. The next transaction picks it up, and every query your code can reach reverts to `SYSTEM_MODE`. The same applies to `UserModeDml_Enabled`. This is a lever for incidents, not a routine setting.

**Bypass audit trail (across the whole framework).** Whenever a safety check is turned off, KernDX records what was bypassed and why, so a later review can see it. This covers every bypass call: on triggers (`TRG_Base.bypass*`), on queries (`QRY_Builder.withSystemMode` / `bypassSharing` / `withoutSecurity`), on saves (`DML_Builder.withSystemMode` / `bypassSharing`), and on validations (`UTIL_ValidationRule.bypassObject` / `bypassGroup` / `bypassRule`). Each one writes a `LogEntryEvent__e` record with category `BypassEvent` through `UTIL_BypassAudit.emit`, capturing the user, the action, the surface, the target, and an optional reason you set with `UTIL_BypassAudit.setBypassReason(String)`. The `BypassAudit_Enabled` feature flag (`FeatureFlag__mdt`) is the master off-switch for this audit; it ships on, and you can disable it through a `FeatureFlagStrategy__mdt` override. To read the audit trail back, query with `SEL_LogEntry.query.condition(LogEntry__c.ContextData__c).contains('"category":"BypassEvent"')`.

---

## How to opt out

Sometimes the secure default is not what you want, and you need to step outside it for a single call. Every protection here is opt-in per layer and controllable right where you call it: you choose the sharing behaviour, the access mode (`AccessLevel`), and whether object and field permissions are enforced, all on the same line. Nothing is hidden in framework internals. The framework's own classes default to `inherited sharing` (176 of 185 production classes), so the caller's sharing context always flows through unchanged.

| You need                                                         | Use                                                                                                                                              | See                                                                                                                  |
|------------------------------------------------------------------|--------------------------------------------------------------------------------------------------------------------------------------------------|----------------------------------------------------------------------------------------------------------------------|
| **`AccessLevel.USER_MODE` for one transaction**                  | `DML_Builder.withUserMode()` / `QRY_Builder.withUserMode()`. Explicitly overrides the flag-driven default.                                       | [Per-Transaction DML Control](#per-transaction-dml-control), [Per-Query Sharing Control](#per-query-sharing-control) |
| **`AccessLevel.SYSTEM_MODE`** (privileged framework code)        | `.withSystemMode()` on either builder. Skips object and field permission checks for that one operation.                                          | [AccessLevel Selection](#accesslevel-selection)                                                                      |
| **Bypass sharing rules for an isolated calculation**             | `.bypassSharing()` routes through the `without sharing` proxy. Or write your own `without sharing` class: the framework never intercepts those.   | [Without Sharing Classes](#without-sharing-classes)                                                                  |
| **Inherit sharing from the caller**                              | The default for framework classes. The caller's sharing context flows through unchanged.                                                         | [Inherited Sharing Classes](#inherited-sharing-classes)                                                              |
| **Custom sharing modes** beyond BYPASS / ENFORCE / INHERITED     | Extend `DML_SharingProxy.DatabaseProxy` (a virtual class).                                                                                       | [Adding New Sharing Modes](#adding-new-sharing-modes)                                                                |
| **Org-wide off-switch** for the USER_MODE rollout                | The `UserModeDml_Enabled` feature flag. Flip it in metadata; it takes effect on the next transaction.                                            | [Org-Wide Access Mode Kill-Switches](#org-wide-access-mode-kill-switches)                                            |
| **Direct `Database.insert(records, allOrNothing, AccessLevel)`** | Works unchanged. Nothing intercepts raw platform DML.                                                                                            | —                                                                                                                    |

Sharing control is decided where you call it, not buried in framework internals. Every default has a documented override on the same fluent builder (the chain of short method calls you build the query or save with).

---

## Data Encryption & Decryption ([`UTIL_SessionEncryption`](reference/apex/UTIL_SessionEncryption.md))

### What it does

You want to protect a sensitive value for a short while, for example a token you pass between two steps of a wizard, without managing encryption keys yourself. That is what [`UTIL_SessionEncryption`](reference/apex/UTIL_SessionEncryption.md) does: it encrypts and decrypts values using AES256 with HMAC-SHA256 (the Encrypt-then-MAC pattern, which also detects tampering) and manages the key for you. The trade-off, and it is a sharp one, is in the warning below: this is for short-lived data only.

#### CRITICAL ARCHITECTURAL WARNING

**This utility keeps its encryption keys in temporary storage (Platform Cache), not in the database.**

The key is **NOT saved to the database**. If the cache expires, is flushed, or the session ends, the key is **LOST FOREVER**, and any data you encrypted with it becomes **permanently unrecoverable**.

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

### How does it compare to native Salesforce encryption?

#### Salesforce Out-of-the-Box Alternatives

Before reaching for the KernDX utility, know that Salesforce already offers native encryption. Which one fits depends on whether you need the data back later and whether you have a Shield licence:

1. **[Crypto.encrypt() / Crypto.decrypt()](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_classes_restful_crypto.htm):** encryption where you manage the keys yourself.
2. **[Shield Platform Encryption](https://developer.salesforce.com/docs/atlas.en-us.securityImplGuide.meta/securityImplGuide/security_pe_overview.htm):** encrypts fields at rest with no code changes (needs a Shield licence).
3. **Crypto.encryptWithManagedIV() / Crypto.decryptWithManagedIV():** Salesforce manages the initialization vector for you.

#### Pros & Cons Comparison

In short: `UTIL_SessionEncryption` manages keys, the initialization vector, and tamper detection for you, but only for short-lived data. Native Salesforce encryption asks more of you up front (or a Shield licence) but handles long-term, compliance-grade storage. The full side-by-side:

<details>
<summary>Full feature-by-feature comparison</summary>

| Feature               | KernDX [`UTIL_SessionEncryption`](reference/apex/UTIL_SessionEncryption.md) | Salesforce OOTB                                                                                                                                                       |
|-----------------------|-----------------------------------------------------------------------------|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| **Key Management**    | Automatic key generation and caching                                        | Manual key management required                                                                                                                                        |
| **Automatic IV**      | Random IV per encryption, included in output                                | `encryptWithManagedIV()` available but still requires key management                                                                                                  |
| **HMAC Integrity**    | Automatic HMAC-SHA256 for tamper detection                                  | Must manually implement                                                                                                                                               |
| **User-Scoped Keys**  | Unique keys per user via Platform Cache                                     | Must manually implement key scoping                                                                                                                                   |
| **Key Rotation**      | Automatic on cache expiry (8 hours)                                         | Manual key rotation required                                                                                                                                          |
| **Long-Term Storage** | Keys expire, data becomes unrecoverable                                     | [Shield Platform Encryption](https://developer.salesforce.com/docs/atlas.en-us.securityImplGuide.meta/securityImplGuide/security_pe_overview.htm) for persistent data |
| **Setup Complexity**  | Requires Platform Cache configuration                                       | [Crypto](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_classes_restful_crypto.htm) class works out of box                               |
| **License Cost**      | No additional license required                                              | Shield Platform Encryption requires Shield license                                                                                                                    |
| **Data Persistence**  | EPHEMERAL ONLY (max 8 hours)                                                | Shield supports long-term encrypted storage                                                                                                                           |
| **Key Storage**       | Platform Cache (ephemeral)                                                  | Shield stores keys securely with HSM                                                                                                                                  |
| **Performance**       | Slight overhead from cache lookups                                          | Direct encryption, no cache dependency                                                                                                                                |
| **Compliance**        | Not suitable for compliance requirements                                    | Shield meets HIPAA, PCI-DSS, etc.                                                                                                                                     |

</details>

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

**Recommendation:** For any data that must be decrypted beyond an 8-hour window,
use [Shield Platform Encryption](https://developer.salesforce.com/docs/atlas.en-us.securityImplGuide.meta/securityImplGuide/security_pe_overview.htm) or external key management.

---

### Why choose this over the built-in Crypto class?

The native [`Crypto.encrypt()` and `Crypto.decrypt()`](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_classes_restful_crypto.htm) work, but they leave key management to you, which is the part that is easy to get wrong. [`UTIL_SessionEncryption`](reference/apex/UTIL_SessionEncryption.md) takes that off your plate:

1. It **generates a key** the first time you need one.
2. It **caches the key** in platform cache, so repeat operations are fast.
3. It **rotates the key** automatically (it expires after 8 hours).
4. It **picks the right cache** for you (session cache, falling back to org cache).

The result is that encrypting a short-lived API token, credential, or piece of personally identifiable information (PII) is a one-line call.

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

A user enters a credential in step 1 of a wizard that you need again in step 3, and you do not want it sitting in page state as plain text. Encrypt it on the way in and decrypt it on the way out, all within the same session:

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

You get an OAuth token back from an external login and want to reuse it for the rest of the session without writing it to the database. Encrypt it before caching, decrypt it just before each callout:

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

You need to send a sensitive value through a Platform Event but the event payload would otherwise carry it in the clear. Encrypt it before publishing, and have the subscribing code decrypt it, as long as both run under the same user's cache:

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

> **Note:** Platform Event encryption only works when the publisher and subscriber share the same user-scoped cache (e.g., same user context). For cross-user event encryption, use
`Crypto.encrypt()` with a shared key stored in a Named Credential or Protected Custom Setting.

### Important Considerations

**Key Expiry and Data Persistence:**

- **CRITICAL**: Encrypted data can only be decrypted while the original key is in cache (max 8 hours)
- **CRITICAL**: If cache expires, is cleared, or org is refreshed, keys are lost FOREVER
- For long-term storage, use
  Salesforce [Shield Platform Encryption](https://developer.salesforce.com/docs/atlas.en-us.securityImplGuide.meta/securityImplGuide/security_pe_overview.htm) instead
- This utility is best for **temporary encryption** (session tokens, temporary credentials, ViewState)

**Cache Availability:**

- Requires Platform Cache to be allocated and configured in the org
- Uses AUTO mode (Session -> Org fallback)
- `isAvailable()` method checks cache availability before operations
- Throws `Cache.CacheException` if cache is unavailable

**Performance:**

- The first encryption operation generates a new 256-bit AES key.
- After that, operations are fast because the key comes from platform cache.
- User-scoped keys stop one user's key being reused for another.
- The HMAC tamper check adds one extra step on each operation, which costs little.

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

## Data Masking

Some values should never reach the database in readable form in the first place: a secret, a card number, a piece of personal data that slipped into a free-text field. KernDX includes a built-in **data masking** framework that rewrites those values on records *before they are saved*. Masking is **on by default** and already protects the framework's own diagnostic records (API call logs, async-chain payloads, integration error records). To cover your own objects, you deploy a small amount of configuration metadata. No Apex is required.

> **Where the full reference lives.** This section is the security-lens summary: what masking protects, and where its boundaries are. For the setup walkthrough, the rule catalogue, the four matching modes, failure handling, and the no-code Data Masking Advisor, see the **[Data Masking Guide](Data%20Masking%20-%20Guide.md)** (or the [Fast Start - Data Masking](Fast%20Start%20-%20Data%20Masking.md) to mask a field in about twenty minutes).

> **Masking vs. encryption.** These two solve opposite problems. [Session encryption](#data-encryption--decryption-util_sessionencryption) is *reversible*: you encrypt a value, store it, and decrypt it later. Masking is *deliberately one-way*: it overwrites the sensitive value with a redacted one, and the original is gone. Use encryption when you need the data back. Use masking when the value should never have been stored readably at all (for example, an API request body captured for diagnostics that happens to carry a bearer token).

### What Data Masking Does

Masking rewrites the value of **text-shaped fields** as records are saved, following rules you configure. It can recognise a sensitive value in four ways:

| Mode            | What it matches                                                                                        | Typical use                                       |
|-----------------|--------------------------------------------------------------------------------------------------------|---------------------------------------------------|
| **Regex**       | A regular expression matched against the whole value; matches are replaced (capture groups `$1`, `$2` supported) | Free-text redaction                       |
| **JSON by Key** | A regex matched against JSON *keys*; the value under each matching key is replaced, at any nesting depth | Redacting `password` / `token` values inside a JSON payload |
| **Exact Match** | A literal substring; every occurrence is replaced                                                       | A known fixed string                              |
| **Credit Card** | Like Regex, but each match must also pass the Luhn (mod-10) checksum                                    | Card-number redaction without catching ordinary long digit runs |

Out of the box, the logging, web-service, and async-chain subsystems mask their own records. Request and response bodies, async-chain payloads, and integration error records have card numbers and credential-shaped values redacted before they are saved. The shipped rules cover categories such as Contact, Personal, Payment, Health, Credentials, Financial, Identity, and Network.

### What Masking Is Not

Masking is a focused tool. Know its boundaries before you rely on it:

- **It is destructive.** The redacted value *replaces* the original. KernDX does not keep a copy and there is no
  "unmask". If you need the original back, use encryption or a separate secure store, not masking.
- **It covers text fields only.** Masking applies to Text, Text Area, Long Text Area, URL, Email, Phone, and Encrypted
  Text fields. Numbers, dates, checkboxes, picklists, and lookups are never touched.
- **It is not retroactive.** A rule masks records as they are inserted or updated *after* you deploy it. Data already
  in the database is untouched until the next time each record is written. To clean up historical data, re-save the
  records (for example, via a one-off batch) so they pass through the masking step.
- **It is not access control.** Masking decides *what is stored*, not *who can see it*. It does not replace field-level
  security, sharing, or
  [Shield Platform Encryption](https://developer.salesforce.com/docs/atlas.en-us.securityImplGuide.meta/securityImplGuide/security_pe_overview.htm).
  Use those for at-rest protection and per-user visibility. Use masking to keep a sensitive value from being written
  down at all.
- **Your custom objects are not masked until you configure them.** The shipped rules protect KernDX's own diagnostic
  records. Masking does not auto-detect sensitive fields at run time: a field is masked only when a Masking Target
  points a rule at it. The [Data Masking Advisor](Data%20Masking%20-%20Guide.md#the-data-masking-advisor) helps you find the fields that need one.

### Configuring Masking

You configure masking entirely in metadata. A **Masking Rule** (`MaskingRule__mdt`) describes *how* to redact; you wire it to a **Masking Target** (`MaskingTarget__mdt`) that describes *where*. Masking is gated per object by the **Apply Masking** switch on that object's Trigger Setting, and globally by the `MaskingFramework_Enabled` feature flag (on by default).

Two things matter to a security reviewer. First, every masking decision is declarative, version-controlled, and deployable, so there is no imperative "mask this" call buried in Apex to track down. Second, it runs in the `before` phase with no extra DML, so it is safe to run on large data loads.

The full setup walkthrough, the four matching modes, the rule catalogue, the failure-handling options (Log and Continue, Write Failure Marker, Block DML), and the no-code **Data Masking Advisor** (which also exports a regulated-field inventory for auditors) all live in the **[Data Masking Guide](Data%20Masking%20-%20Guide.md)**.

For how the Advisor's artifacts fit a governance or audit process, and what they deliberately do *not* prove, see [Security Governance Evidence](#security-governance-evidence).

### Secret Scanning in CI

Runtime masking keeps secrets out of your *data*. A separate control, this one running at development time, keeps them out of your *source code*. The KernDX delivery pipeline ships a Salesforce-aware **`kerndx secret-scan`** gate that inspects changed files for hardcoded credentials such as API keys, tokens, and private keys, and fails the build before they can merge. It runs as part of the standard CI workflow, and you can suppress a reviewed false positive inline or by fingerprint. See the [Code Scanning Guide](Code%20Scanning%20-%20Guide.md) for setup and rule detail.

---

## Record Sharing

In plain Apex, you decide whether a class respects sharing rules when you write it, by declaring `with sharing`, `without sharing`, or `inherited sharing` on the class. You cannot change that decision later. KernDX lets you **choose the sharing behaviour when the code runs** instead, so the same logic can enforce sharing for a UI user and bypass it for a system batch. This section covers that runtime control over Salesforce [sharing rules](https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_security_sharing_rules.htm), and the small "proxy" class pattern that makes it possible.

### Sharing Architecture

#### Sharing Control Points

You can control sharing at four points in the framework:

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

When you save records, [`DML_Builder`](reference/apex/DML_Builder.md) is the class that decides whether sharing rules apply. Behind the scenes it keeps a few small helper classes, each declared with a different sharing mode, and picks the right one for your transaction based on the methods you chain (this is the Strategy pattern: swap in different behaviour behind one interface).

**Class Declaration:**

```apex
global inherited sharing class DML_Builder
```

**Key parts:**

1. **Access-mode methods.** `.withUserMode()` / `.withSystemMode()` choose the access level (`AccessLevel`) for the transaction.
2. **Sharing control.** `.bypassSharing()` switches to the `without sharing` helper.
3. **Helper classes.** These run the actual save with a specific sharing mode (the internal `DML_SharingProxy.SharingType` enum).

#### Per-Transaction Sharing Control

`DML_Builder` gives you one sharing override in code: `.bypassSharing()`. If you do not call it, the transaction follows the caller's sharing context through the `inherited sharing` helper.

| Builder Method     | Proxy Used                | Effect                                |
|--------------------|---------------------------|---------------------------------------|
| *(default)*        | `inherited sharing` proxy | DML inherits caller's sharing context |
| `.bypassSharing()` | `without sharing` proxy   | DML ignores sharing rules             |

There is no `.withSharing()` method on `DML_Builder`. To enforce sharing on a save, call the transaction from a `with sharing` class (or from one whose `inherited sharing` caller is itself `with sharing`). To enforce object and field permissions as well, add `.withUserMode()` (see [Safe by Default](#safe-by-default)).

#### How the Proxy Pattern Works

KernDX keeps a small helper class for each sharing mode (on `DML_SharingProxy`), each declared with a different [sharing keyword](https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_classes_keywords_sharing.htm), and routes your save through the matching one. The `DML_SharingProxy.SharingType` enum that names these modes is internal to the package, so you drive the choice through the fluent builder methods rather than touching the enum yourself:

| Builder Method                   | Proxy Class (internal)                         | Sharing Declaration | Effect                        |
|----------------------------------|------------------------------------------------|---------------------|-------------------------------|
| `.bypassSharing()`               | `DML_SharingProxy.DatabaseProxyWithoutSharing` | `without sharing`   | DML ignores sharing rules     |
| *(default, with sharing caller)* | `DML_SharingProxy.DatabaseProxyWithSharing`    | `with sharing`      | DML respects sharing rules    |
| *(default, inherited caller)*    | `DML_SharingProxy.DatabaseProxy`               | `inherited sharing` | DML inherits caller's context |

**Why this matters:**

In plain Apex, the class declaration fixes the sharing behaviour when you compile, and you cannot change it at run time. The helper-class approach gets around that by handing the save to a class that already has the sharing mode you want.

**What this buys you:** the helper layer can override the caller's sharing context when you need it to. Even if your code lives in a `without sharing` class, running a save from inside a dedicated `with sharing` class that calls `DML_Builder.newTransaction()...execute()` will run through the `with sharing` helper. The reverse also works: `.bypassSharing()` on the builder deliberately picks the `without sharing` helper. Add `.withUserMode()` to enforce object and field permissions at the database as well.

#### AccessLevel Selection

Every `DML_Builder` transaction settles on an access level (`AccessLevel`) the moment `.execute()` runs:

1. `.withUserMode()` forces `AccessLevel.USER_MODE` (object permissions, field security, and sharing all enforced).
2. `.withSystemMode()` forces `AccessLevel.SYSTEM_MODE` (object and field permission checks skipped; sharing still controlled by the helper class).
3. If you call neither, the `UserModeDml_Enabled` feature flag decides. It ships `true`, so USER_MODE is used; if someone flips it to `false` in metadata, SYSTEM_MODE is used.

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

> **Important:** `AccessLevel.SYSTEM_MODE` skips field and object permission checks, but it does *not* turn off sharing. The sharing mode on the helper class (`with sharing` / `without sharing` / `inherited sharing`) still decides which records the code can reach.

### Query Sharing Enforcement

#### QRY_Builder Sharing Control

[`QRY_Builder`](reference/apex/QRY_Builder.md) uses the same helper-class approach for queries, so you can control sharing one query at a time or set a default for the whole org.

**Class Declaration:**

```apex
global inherited sharing class QRY_Builder
```

#### How Query Sharing Works

Just as with saves, [`QRY_Builder`](reference/apex/QRY_Builder.md) uses helper classes to control sharing on a query. The method you chain decides which helper runs the query:

| Sharing Method     | Proxy Used         | Effect                                  |
|--------------------|--------------------|-----------------------------------------|
| *(default)*        | `SharingProxy`     | Query inherits caller's sharing context |
| `.withSharing()`   | `WithSharingProxy` | Query enforces sharing rules            |
| `.bypassSharing()` | `NoSharingProxy`   | Query bypasses sharing rules            |

**Three choices:**

The sharing methods give you three distinct behaviours:

- **Default (no method called).** Follows the calling class's own sharing declaration. If your class is `with sharing`, the query enforces sharing; if `without sharing`, it bypasses.
- **`.withSharing()`.** Always enforces sharing, whatever the caller's context. Use this for user-facing features.
- **`.bypassSharing()`.** Always bypasses sharing, whatever the caller's context. Use this for system operations.

So the same query can run in different security contexts without you editing the query itself.

#### Org-Wide Access Mode Override

There is **no single per-transaction flag** that flips every query between `with` and `without` sharing at once. When you want consistent behaviour across many queries, use one of the three approaches below.

**1. Per call on each query.** Chain `.withSharing()` / `.bypassSharing()` on individual `QRY_Builder` calls, or `.withUserMode()` / `.withSystemMode()` to also control object and field permissions.

**2. Per selector.** Your own `SEL_*` classes that must always run in SYSTEM_MODE (readers of custom metadata, system-schema selectors) override `systemModeRequired()`:

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

**3. Org-wide emergency off-switch.** Set the `kern__FeatureFlag.UserModeQueries_Enabled` custom metadata record to `IsEnabledByDefault__c = false`. Every query your code can reach falls back to SYSTEM_MODE on the next transaction. The companion flag `UserModeDml_Enabled` does the same for `DML_Builder`. See [Safe by Default](#safe-by-default).

> **Which to use:** the per-call override for one-off exceptions, the per-selector override for framework-internal classes, and the metadata off-switch only to roll the secure default back in an emergency. Do not flip the metadata flag as a routine setting: it weakens the protection on every query your code can reach.

#### QRY_Builder Security Methods

For about 95% of queries, [`QRY_Builder`](reference/apex/QRY_Builder.md) (the fluent query builder, configured with short chained calls) is the recommended way to write them. Its security options are independent and combinable:

##### Security Method Summary

| Method                | Effect                                                                            | When to Use                                                             |
|-----------------------|-----------------------------------------------------------------------------------|-------------------------------------------------------------------------|
| `withUserMode()`      | Runs in USER_MODE (enforces CRUD, FLS, sharing at DB level)                       | User-facing code requiring full security                                |
| `stripInaccessible()` | Removes inaccessible fields from results post-query                               | When null values for inaccessible fields are problematic                |
| `withSharing()`       | Uses `with sharing` proxy class                                                   | Enforce sharing in SYSTEM_MODE queries                                  |
| `bypassSharing()`     | Uses `without sharing` proxy class                                                | Bypass sharing in SYSTEM_MODE (use with caution)                        |
| `withoutSecurity()`   | Clears USER_MODE, strip, and sharing selections (SYSTEM_MODE + inherited sharing) | System-level queries that must opt out of the secure-by-default posture |

##### Default Behaviour

By default, every query your code can reach runs in **USER_MODE** with **inherited sharing**, driven by the `UserModeQueries_Enabled` feature flag (shipped `true`). USER_MODE enforces object permissions, field security, and sharing at the database. Framework-internal selectors opt out by returning `true` from `systemModeRequired()`, and individual calls opt out with `.withSystemMode()`. If someone flips `UserModeQueries_Enabled` to `false` (the emergency off-switch), every query falls back to SYSTEM_MODE on the next transaction.

##### USER_MODE vs Sharing Proxy

When you use `withUserMode()`, sharing is enforced at the database whatever your `withSharing()` / `bypassSharing()` settings say. Those sharing methods only take effect in SYSTEM_MODE.

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

There is **no single per-transaction flag** for DML sharing. The only org-wide controls are the two configuration records (`FeatureFlag__mdt`) that drive the secure default:

```text
Setup -> Custom Metadata Types -> FeatureFlag -> UserModeQueries_Enabled
   -> IsEnabledByDefault__c = true   (package default — USER_MODE for all queries)
   -> IsEnabledByDefault__c = false  (emergency kill-switch — SYSTEM_MODE for all queries)

Setup -> Custom Metadata Types -> FeatureFlag -> UserModeDml_Enabled
   -> IsEnabledByDefault__c = true   (package default — USER_MODE for all DML)
   -> IsEnabledByDefault__c = false  (emergency kill-switch — SYSTEM_MODE for all DML)
```

Flipping a flag takes effect on the next transaction across the org. Treat it as an emergency rollback lever, not a routine setting.

#### Per-Transaction DML Control

When you want to set the access mode or sharing for a specific save, use [`DML_Builder`](reference/apex/DML_Builder.md):

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

When you want to set the sharing or access mode for one query without touching any others, use the fluent [`QRY_Builder`](reference/apex/QRY_Builder.md) API:

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

[`DML_Builder`](reference/apex/DML_Builder.md) lets you control sharing for a whole transaction with `.bypassSharing()`:

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

You want to grant a user access to some records by creating Share records (like `AccountShare` or `OpportunityShare`), but that needs elevated permissions the granting user may not have. The [`UTIL_Sharing`](reference/apex/UTIL_Sharing.md) utility handles this for you by bypassing sharing on the Share-object save.

**Why bypass sharing for shares?** The person granting access may not have direct access to the Share objects themselves. A manager sharing their Accounts with an assistant, for instance, needs the Share records created even though they cannot query `AccountShare` directly. The framework absorbs that complexity so you can focus on the business logic.

**Usage:**

```apex
// Grant permanent access to records
List<SObject> shares = UTIL_Sharing.grant(accounts, groupId, 'Read');

// Grant temporary access (auto-revoked after specified minutes)
List<SObject> tempShares = UTIL_Sharing.grantTemporary(accounts, groupId, 'Read', 30);
```

The framework creates the right Share records with `BYPASS` sharing mode, so the operation succeeds no matter what permissions the calling user has on Share objects.

### Classes with Explicit Sharing Declarations

#### Without Sharing Classes

A few framework classes are declared `without sharing`, which means their internal operations bypass sharing rules by default:

| Class                                          | Purpose            | Rationale                                                     |
|------------------------------------------------|--------------------|---------------------------------------------------------------|
| [`TST_Builder`](reference/apex/TST_Builder.md) | Test data creation | Tests need to create data regardless of running user's access |

**TST_Builder:**

```apex
@SuppressWarnings('PMD.ApexCRUDViolation')
global without sharing class TST_Builder
```

- Creates test data, custom metadata, permission assignments
- Must operate regardless of test user's permissions

> **Important:** Even though these classes are declared `without sharing`, any save you make through the framework's [`DML_Builder`](reference/apex/DML_Builder.md) methods still flows through the sharing helper. A `with sharing` helper can override a `without sharing` caller, so you can still enforce sharing from a `without sharing` class: call the builder from a dedicated `with sharing` wrapper, or add `.withUserMode()` to enforce object permissions, field security, and sharing at the database regardless of the caller's context.

#### With Sharing Classes

These classes always enforce sharing:

| Class                                                                | Purpose                  | Rationale                                           |
|----------------------------------------------------------------------|--------------------------|-----------------------------------------------------|
| [`UTIL_SessionEncryption`](reference/apex/UTIL_SessionEncryption.md) | Session-based encryption | Security-sensitive operations should respect access |

**UTIL_SessionEncryption:**

```apex
global with sharing class UTIL_SessionEncryption
```

- Manages session-based encryption and decryption
- Enforces sharing to ensure only authorised users can access encrypted data

#### Inherited Sharing Classes

Most framework classes use `inherited sharing` so they follow whatever sharing context the caller is in:

| Class                                                  | Purpose                   |
|--------------------------------------------------------|---------------------------|
| [`DML_Builder`](reference/apex/DML_Builder.md)         | Bulk DML operations       |
| [`DML_Transaction`](reference/apex/DML_Transaction.md) | Transaction management    |
| [`SEL_Base`](reference/apex/SEL_Base.md)               | Generic selector methods  |
| [`QRY_Builder`](reference/apex/QRY_Builder.md)         | Fluent query builder      |
| [`UTIL_Sharing`](reference/apex/UTIL_Sharing.md)       | Record sharing management |
| All `SEL_*` selector classes                           | Object-specific selectors |

### Extending Sharing Control

#### Creating Custom Selectors with Sharing Control

You can build your own selectors that use the same sharing controls, through [`SEL_Base`](reference/apex/SEL_Base.md) and [`QRY_Builder`](reference/apex/QRY_Builder.md):

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

You can extend the helper-class approach by adding your own classes with different behaviour. That said, the three built-in modes (BYPASS, ENFORCE, INHERITED) cover the usual cases, so you rarely need to.

For specialised needs, consider these:

##### Combining with FLS Enforcement

```apex
// Enforce both sharing AND FLS via USER_MODE
List<Account> accounts = QRY_Builder.selectFrom(Account.SObjectType)
	.fields(new List<String>{'Id', 'Name'})
	.withUserMode()
	.toList();
```

##### Creating Wrapper Methods

Write a wrapper method that sets both sharing and field/object security in one place:

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

To prove sharing works, create test users with different permissions and check what each one can see:

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

Salesforce access control has three separate layers, and it helps to keep them straight because they answer different questions. KernDX lets you enforce each one on its own:

| Security Layer                      | What It Controls                         | Key Framework Class                                                                             |
|-------------------------------------|------------------------------------------|-------------------------------------------------------------------------------------------------|
| **Field-Level Security (FLS)**      | Which fields a user can read/write       | [`QRY_Builder`](reference/apex/QRY_Builder.md) (`.withUserMode()`, `.stripInaccessible()`)      |
| **Object-Level Security (CRUD)**    | Create/Read/Update/Delete on objects     | [`QRY_Builder`](reference/apex/QRY_Builder.md) (`.withUserMode()`)                              |
| **Record-Level Security (Sharing)** | Which specific records a user can access | [`DML_Builder`](reference/apex/DML_Builder.md) / [`QRY_Builder`](reference/apex/QRY_Builder.md) |

#### Field-Level Security (FLS)

Field-level security controls which fields a user can read or change. You have two ways to enforce it.

**Option 1: Enforce it in the query with `withUserMode()`.**

Adding `.withUserMode()` to a [`QRY_Builder`](reference/apex/QRY_Builder.md) query runs it in `AccessLevel.USER_MODE`, which enforces both field security and object permissions inside the SOQL itself:

- **Field security:** fields the user cannot read are stripped from the results automatically.
- **Object permissions:** if the user lacks Read access to the object, the query throws an exception.
- **Cache turned off:** caching is disabled automatically while security is enforced, which stops results leaking between users with different access.

```apex
// If user lacks FLS access to AnnualRevenue, it's stripped from results
// If user lacks CRUD Read on Account, query throws exception
List<Account> accounts = QRY_Builder.selectFrom(Account.SObjectType)
	.fields(new List<String>{'Name', 'AnnualRevenue', 'Industry'})
	.withUserMode()
	.toList();
```

**Option 2: Strip unreadable fields after the query with `stripInaccessible()`.**

```apex
// Strip inaccessible fields after query execution
List<Account> accounts = QRY_Builder.selectFrom(Account.SObjectType)
	.fields(new List<String>{'Name', 'AnnualRevenue', 'Industry'})
	.stripInaccessible()
	.toList();
```

#### Object-Level Security (CRUD)

Object-level security controls who can create, read, update, and delete a given object. You have two ways to check it.

**Option 1: From a Flow, with [`FLOW_CheckObjectPermissions`](reference/apex/FLOW_CheckObjectPermissions.md).**

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

**Option 2: In the query, with `withUserMode()`.**

```apex
// Enforce CRUD at the query level — throws exception if user lacks Read access
List<Account> accounts = QRY_Builder.selectFrom(Account.SObjectType)
	.fields(new List<String>{'Name', 'Industry'})
	.withUserMode()
	.toList();
```

#### Record-Level Security (Sharing)

Record-level security controls which specific records a user can reach. You control it through the sharing helpers described in the [Record Sharing](#record-sharing) section.

#### AccessLevel Modes

Salesforce's [`AccessLevel`](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_enum_System_AccessLevel.htm) setting decides whether object and field permissions are enforced on a database operation:

| Mode                      | FLS/CRUD | Sharing                                                                         | When Used                                                                                                                   |
|---------------------------|----------|---------------------------------------------------------------------------------|-----------------------------------------------------------------------------------------------------------------------------|
| `AccessLevel.USER_MODE`   | Enforced | Enforced (runs through the user's sharing)                                      | The **secure default** for the queries and saves your code can reach (shipped package behaviour)                            |
| `AccessLevel.SYSTEM_MODE` | Bypassed | Controlled by the helper class (class declaration / `.withSharing()` / `.bypassSharing()`) | Framework-internal reads, custom-metadata readers, log and orchestration writes. Opt in with `.withSystemMode()` or `systemModeRequired()` |

By default, the `QRY_Builder` and `DML_Builder` calls your code can reach run in `USER_MODE`. SYSTEM_MODE is reserved for framework-internal operations and a few narrow, documented opt-outs. Framework-internal selectors override `SEL_Base.systemModeRequired()` to return `true`; individual calls use `.withSystemMode()`. The org-wide flip on `FeatureFlag.UserModeQueries_Enabled` / `UserModeDml_Enabled` is an emergency off-switch only (see [Safe by Default](#safe-by-default)). For how the sharing helper classes layer on top of `AccessLevel.SYSTEM_MODE`, see [Record Sharing > AccessLevel Selection](#accesslevel-selection).

#### Combining All Three Security Layers

For the strongest protection in user-facing features, enforce object permissions, field security, and sharing on both the query and the save with `.withUserMode()`:

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

> Because the secure default already runs both queries and saves in `USER_MODE`, the explicit `.withUserMode()` calls above are not strictly required. They are worth keeping anyway: they document the intent, and they protect you if someone has flipped the `UserModeQueries_Enabled` / `UserModeDml_Enabled` off-switch to `false`.

### Common Sharing Patterns

#### Public Site / Community Controllers

Community and portal users should only see records they are entitled to. Enforce sharing in the controller so every operation respects the user's permissions.

**Why enforce sharing here?** External users reaching your app through [Experience Cloud](https://developer.salesforce.com/docs/atlas.en-us.communities_dev.meta/communities_dev/communities_dev_intro.htm) or a public site must never see records belonging to other users or organisations. Even when the Organization-Wide Default (OWD) is set correctly, enforcing sharing explicitly gives you a second line of defence.

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

> `public with sharing` on the controller already enforces sharing for any inline SOQL, and `.withUserMode()` enforces object permissions, field security, and sharing at the database for every `QRY_Builder` / `DML_Builder` call inside it. Belt and braces for guest and external-user contexts.

#### System Batch Processing

A batch job often needs to process every record of an object, whatever the running user can see. This is common for data maintenance, synchronisation, and cleanup.

**Why bypass sharing here?** A batch job runs as a specific user, usually a service account or whoever scheduled it. If you do not bypass sharing, the job only processes the records that user can see, and the rest go untouched. For a system-level job you want the whole dataset.

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

> `without sharing` on the class plus `.withSystemMode().bypassSharing()` on each builder call makes the bypass explicit at every layer. Prefer this to a single flag set at the top of the transaction: the explicit chaining shows up in code review and leaves a record at the exact call site.

#### Trigger Actions

A trigger action should use `inherited sharing` so it follows whatever context the trigger is running in. A trigger runs with the permissions of the user who caused the change, but usually has system-level access to the records it processes.

**Why inherited sharing here?** Trigger actions are reusable pieces that may run in different contexts. `inherited sharing` keeps them correct whether they are called from a user context (where sharing is enforced) or a system context (where it is bypassed). If a trigger action needs to override the caller's context for one query or save, use the fluent `.withSystemMode()` / `.withUserMode()` / `.bypassSharing()` methods on that specific `DML_Builder` / `QRY_Builder` call.

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

[`LOG_Builder`](reference/apex/LOG_Builder.md) bypasses sharing internally so that logging always succeeds:

```apex
// Logging works regardless of current user's sharing context
LOG_Builder.build().error(exception).emitAt('MyClass.myMethod');
```

**Why?** Error logs have to be captured whatever the current user's permissions are. If logging failed silently, you would lose the diagnostic evidence exactly when you need it.

### Security Considerations

#### When to Bypass Sharing

Bypass sharing with `.withSystemMode().bypassSharing()` on the relevant `QRY_Builder` / `DML_Builder` call, and record why with `TRG_Base.setBypassReason(String)`. Typical cases:

| Scenario                | Example                                                 |
|-------------------------|---------------------------------------------------------|
| System batch processing | Nightly data cleanup jobs                               |
| Platform event triggers | Processing events from any context                      |
| Integration handlers    | Receiving data from external systems                    |
| Logging and auditing    | Ensuring all errors are captured                        |
| Share object management | Creating/deleting share records                         |
| Scheduled jobs          | Jobs running as a specific user but needing full access |
| Test data factories     | Tests need to create data regardless of test user       |

#### When to Enforce Sharing

Enforce object permissions, field security, and sharing with `.withUserMode()` on the relevant `QRY_Builder` / `DML_Builder` call. This is already the default for the calls your code can reach; calling it explicitly makes the intent clear and protects you if the off-switch flag is ever flipped. Typical cases:

| Scenario                      | Example                        |
|-------------------------------|--------------------------------|
| Community/Portal pages        | External users accessing data  |
| Public sites                  | Unauthenticated or guest users |
| User-initiated actions        | Any UI-driven operation        |
| REST APIs exposed to partners | External system access         |
| Reports and dashboards        | User-facing data views         |
| Lightning components          | User interface interactions    |

#### Cache Security

When security is enforced, the framework turns caching off for you:

```apex
// Caching disabled when using withUserMode() - prevents data leakage across users
List<Account> accounts = QRY_Builder.selectFrom(Account.SObjectType)
	.fields(new List<String>{'Name'})
	.withUserMode()
	.toList();
```

**Why?** A cached result from one user could otherwise be served to another user with different access, leaking data between them.

---

## Security Governance Evidence

KernDX is a framework, not a governance system. It does not store approvals, sign-offs, or decision history, and it is **not your security system of record**. What it does provide is durable, version-controlled *evidence* that feeds the governance process you already run. The benefit: the artifacts an auditor asks for come out of source control and reporting, not out of someone's memory.

### Masking Configuration as a Version-Controlled Record

Your masking rules and the fields they protect are defined entirely in metadata (`MaskingRule__mdt` and
`MaskingTarget__mdt`). Because they are metadata, every change is deployable and lives in source control.
So your version history *is* the change record: who committed it, when, the exact before-and-after, and
(in a pull-request workflow) who reviewed it.

The Data Masking Advisor turns this into two exportable artifacts:

- **Deployable masking configuration:** a ready-to-deploy metadata bundle describing exactly which
  fields are masked, with which rule, and whether each assignment is active. You commit it to your own
  repository and deploy it through your pipeline. It is inert text: KernDX performs no deployment and
  writes no records on your behalf.
- **Regulated-field inventory:** a read-only census, downloadable as CSV or JSON, of the fields KernDX
  identifies as sensitive across an object or the whole org, together with their current masking status.
  This is the inventory you hand to an auditor or load into your system of record.

**What this does, and does not, give you.** These artifacts answer *what* is masked, with which rule, in
what state, and as of which deployment. They are **inputs to** your security system of record; they are
not the system of record itself. A metadata record cannot tell you *who* decided to enable or disable
masking on a field, *under whose authority*, or *who approved the exception*, and you should not treat it
as if it can. On most teams the name on a commit belongs to whoever ran the deployment tool, not whoever
made or authorised the decision, and many pipelines commit under a single service account. Attributable,
authorised decisions (with separation between the person who requests a change and the person who
approves it) belong in your change-management approval gates or your governance, risk, and compliance
(GRC) system. KernDX feeds those systems; it does not replace them.

**Recommended use.** Keep masking configuration in source control and deploy it through a pipeline that
requires review and approval, so the approval is captured by *that* gate. Export the regulated-field
inventory before each audit and reconcile it into your system of record. Reserve direct edits to masking
metadata in production Setup for emergencies: those take effect on the next transaction but are recorded
only in the Setup Audit Trail, which is a coarse and time-limited log, so back-port any emergency change
to source promptly.

### Access-Review Primitives

Confirming that each user's access is still appropriate, certified by a business owner with stale access
removed, is a process your organisation owns. KernDX does not run that review or store its sign-offs. It
gives you two building blocks that supply the *evidence* and the *remediation* the review depends on:

- **Login-activity reporting (Login Frequency).** A scheduled processor rolls each user's login
  history up into per-user, per-month records (total logins and unique active days) shown on the
  **Login Frequency** tab. This is the "is this person actually using this access?" evidence that makes a
  review meaningful, and it surfaces dormant accounts before they become an audit finding.
- **Automated deactivation of inactive users.** The **Deactivate Inactive Users** scheduled job
  deactivates users in chosen profiles who have not logged in for a configurable number of days (with
  batch-size and all-or-nothing controls). Schedule it from the Scheduled Job editor to clear out dormant
  access continuously, so each review starts from a cleaner baseline.

**What this does, and does not, give you.** These building blocks produce activity evidence and automate one
common remediation. They do not certify access, capture a business owner's approval, or track remediation
sign-off; that recertification step remains a documented process in your system of record. KernDX is
deliberately not a recertification engine.

---

## Security Boundaries and Portal Hardening

KernDX gives you security *mechanisms*. It does not run org-wide security monitoring or make an org compliant on its own. For the full, control-by-control map of what
KernDX evidences versus what stays your own configuration, see the
[Security Benchmark for Salesforce Alignment](Strategic%20Guide%20-%20Architecture%20%26%20Philosophy.md#security-benchmark-for-salesforce-alignment) section.
This section covers the two patterns that benchmark expects you to get right in your own code, and states plainly what KernDX does not
watch for you.

### Parameter-Based Record Access in Portals

A page that takes a record Id from the URL or an input parameter and then reads or writes that record **without checking the running user** lets a guest,
community, or portal user reach records they should never see. (Security people call this an insecure direct object reference, or IDOR.) This is application-code
security, and it is yours to get right.

Here is the KernDX default that helps you: `QRY_Builder` and `DML_Builder` run in `USER_MODE` by default. So a record the running user cannot see is not returned, and a
write the running user is not permitted to make is not committed, **as long as you do not bypass it.**

```apex
// Portal/guest-reachable controller: trust the platform, not the parameter.
@AuraEnabled
public static Case getCase(Id caseId)
{
	// USER_MODE (the default) enforces the running user's CRUD, FLS, and sharing.
	// A guest user who cannot see this Case gets an empty result — not someone else's record.
	List<Case> cases = QRY_Builder.selectFrom(Case.SObjectType)
		.fields(new List<String>{'Subject', 'Status'})
		.condition(Case.Id).equals(caseId)
		.withUserMode()
		.toList();

	return cases.isEmpty() ? null : cases[0];
}
```

The rule of thumb: on any path a guest or external user can reach, **keep `USER_MODE` on**. Do not reach for `.withSystemMode()` / `.bypassSharing()` to "make
the query work," because that access check is exactly what the request needs. KernDX documents this pattern, but it does not ship a scanner that detects IDOR in
your code; finding it is your application-security review's job. See [When to Enforce Sharing](#when-to-enforce-sharing) for the matching sharing posture.

### Flow Input-Variable Hygiene

An autolaunched flow invoked from a portal, guest, or community context carries the same risk: an input record variable can be controlled by the caller, so treat it as
untrusted. Where the flow calls Apex, route that Apex through `QRY_Builder` / `DML_Builder` in `USER_MODE` so access is enforced on the running user
rather than on the flow's running context. Never pass an input Id straight into a system-mode query. Scope the input variable to the records the flow is meant
to touch, and validate it before acting on it.

### What KernDX Does Not Monitor

KernDX is an accelerator, not an org-security monitor. It deliberately leaves org-wide posture detection to the tools built for it. Concretely:

- **Metadata-change governance.** KernDX owns the *source-control* half: repeatable package builds, a refusal to build from a dirty working tree, and the
  bypass-alert pair on the CI pipeline. Detecting org-wide config drift and unauthorized changes belongs to your deployment platform and to Salesforce Shield or
  AppOmni. KernDX ships no Setup Audit Trail monitor.
- **Backup and recovery.** KernDX ships no org backup. Use a dedicated backup-and-recovery solution.
- **API and login monitoring.** `ApiCall__c` records only the callouts KernDX routes; it is not an org-wide API-usage log. Org-wide API, login, and
  anomaly monitoring is Salesforce Event Monitoring and your SIEM.
- **Org security baseline.** KernDX's own Health Check verifies *KernDX* configuration (cache allocation, masking posture, scheduled jobs). It is **not** the
  native Salesforce Security Health Check, which scores your org against Salesforce's baseline. Run that separately.

---

## Testing

You test security by checking two things: that a permission check throws the right exception for a user who is not allowed, and that sharing enforcement actually hides records the user should not see. KernDX tests its own internal security classes, so your tests can focus on what is yours: that your code calls the security APIs correctly and handles the exceptions.

**Testing object and field permission enforcement with `withUserMode()`:**

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

For more detailed sharing test patterns, including `System.runAs()` and share-record verification, see the
[Testing Sharing Behavior](#testing-sharing-behavior) subsection under Record Sharing.

---

## Capability Matrix (for Analysts)

If you are evaluating what the framework controls rather than writing the code, this table is your one-page summary: each security capability, where it is applied, the method that does it, and what to know about it.

| Capability                       | Control Point             | Class/Method                                                     | Notes                                                          |
|----------------------------------|---------------------------|------------------------------------------------------------------|----------------------------------------------------------------|
| CRUD/FLS enforcement             | Query-level enforcement   | `QRY_Builder.withUserMode()`                                     | Enforces CRUD and FLS at database level                        |
| CRUD/FLS enforcement             | DML-level enforcement     | `DML_Builder.withUserMode()`                                     | Enforces CRUD and FLS on DML transactions                      |
| Post-query FLS strip             | Field removal after query | `QRY_Builder.stripInaccessible()`                                | Removes inaccessible fields from results                       |
| Session encryption               | Runtime data protection   | `UTIL_SessionEncryption.encrypt()` / `.decrypt()`                | AES-256 with automatic key management                          |
| Query sharing enforcement        | Per-query control         | `.withSharing()` / `.bypassSharing()` / `.withUserMode()`        | Applied on `QRY_Builder` queries                               |
| DML sharing enforcement          | Per-transaction control   | `DML_Builder.newTransaction().bypassSharing()`                   | Applied on DML transactions                                    |
| Selector-wide SYSTEM_MODE lock   | Selector-level override   | `SEL_Base.systemModeRequired()` override                         | Framework-internal selectors opt out of USER_MODE default      |
| Org-wide access mode kill-switch | Custom metadata flag      | `FeatureFlag.UserModeQueries_Enabled` / `UserModeDml_Enabled`    | Emergency rollback only: flips all queries and DML to SYSTEM_MODE |
| Bypass audit trail               | Platform event            | `TRG_Base.bypass*()` + `LogEntryEvent__e` category `BypassEvent` | Attach reason via `TRG_Base.setBypassReason(String)`           |

---

## Anti-Patterns

These are the common security mistakes (the risky habits worth catching in review), why each one bites, and what to do instead.

| Anti-Pattern                                                   | Why It's Wrong                                                            | Instead                                                                                        |
|----------------------------------------------------------------|---------------------------------------------------------------------------|------------------------------------------------------------------------------------------------|
| Performing DML without CRUD/FLS checks in user-facing code     | Exposes data to unauthorized access and fails Salesforce security review  | Use `.withUserMode()` on queries or `.stripInaccessible()` for post-query FLS                  |
| Using hardcoded field API name strings for security checks     | Breaks silently when fields are renamed or deleted                        | Use `SObjectField` token references (e.g., `Account.Name`) for compile-time safety             |
| Storing secrets in plain text (custom fields, custom settings) | Credentials are visible to admins and exposed in SOQL queries             | Use `UTIL_SessionEncryption` for runtime encryption or Named Credentials for API secrets       |
| Relying solely on `inherited sharing` for security             | Sharing context depends on the caller and may be unpredictable            | Be explicit: use `with sharing` for user-facing code and `without sharing` only when justified |
| Using `.bypassSharing()` without documentation                 | Unauditable privilege escalation that may violate compliance requirements | Document every sharing bypass with a code comment explaining the business justification        |

---

## Best Practices

### Always Enforce CRUD/FLS in User-Facing Code

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

### Handle Security Exceptions Gracefully

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

### Encrypt Sensitive Data in Transit

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

### Be Explicit About Sharing Context

Declare sharing explicitly on the class, and call the relevant access-mode method on each `DML_Builder` / `QRY_Builder` call where it matters for the feature:

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

### Keep Sharing Decisions at the Call Site

You choose the access mode and sharing per call, through the fluent methods. There is no transaction-wide flag to save and restore, so make the bypass explicit at the exact call that needs it:

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

Each builder chain carries its own access mode and sharing selection, and they do not leak between calls.

### Don't Log Sensitive Data

```apex
// WRONG: Logs plain text password
LOG_Builder.build().debug('User password: ' + password).emitAt('MyClass.login');

// CORRECT: Never log sensitive data
LOG_Builder.build().debug('Password validation completed').emitAt('MyClass.login');
```

### Combine Security Layers

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

### Decrypt Only When Necessary

```apex
// WRONG: Decrypt and store in memory longer than needed
String decryptedToken = UTIL_SessionEncryption.decrypt(encryptedToken);
// ... many lines of code ...
makeApiCall(decryptedToken);

// CORRECT: Decrypt just before use
makeApiCall(UTIL_SessionEncryption.decrypt(encryptedToken));
```

### Use `inherited sharing` for Security Classes

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

### Use Inherited Sharing for Reusable Code

For a utility method that gets called from different contexts:

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

### Document Sharing Decisions

Add ApexDoc comments that explain why a specific sharing mode is used, and record the bypass reason with `TRG_Base.setBypassReason(String)` so it lands on the `LogEntryEvent__e` audit trail under category `BypassEvent`:

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

### Combine Sharing with FLS/CRUD Checks

For user-facing features, enforce both sharing and field/object permissions together:

```apex
// Enforce complete security for user-initiated operations
List<Account> accounts = QRY_Builder.selectFrom(Account.SObjectType)
	.fields(new List<String>{'Id', 'Name', 'Industry'})
	.withUserMode()
	.stripInaccessible()
	.toList();
```

### Test Sharing Behavior

Include tests that prove sharing behaves as expected:

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

### Audit Sharing Bypasses

Keep a list of the places in your code that bypass sharing, and review it periodically:

| Class                      | Method             | Bypass Reason                        |
|----------------------------|--------------------|--------------------------------------|
| `BATCH_ProcessAllAccounts` | `execute()`        | System batch requires full access    |
| `TRG_LogEntryEvent`        | `afterInsert()`    | Logging must always succeed          |
| `API_IntegrationHandler`   | `processPayload()` | Integration data from trusted source |

---

## Quick Reference

A lookup section for when you already know what you want and just need the exact method or pattern.

### Encryption/Decryption

| Operation              | Method                                   | Returns                         |
|------------------------|------------------------------------------|---------------------------------|
| Encrypt plain text     | `UTIL_SessionEncryption.encrypt(String)` | Base64-encoded encrypted string |
| Decrypt encrypted text | `UTIL_SessionEncryption.decrypt(String)` | Plain text string               |

**Key Management:**

- Algorithm: AES256 with SHA-256 digest
- Key Storage: Platform cache (session cache preferred, org cache fallback)
- Key Expiry: 8 hours (28,800 seconds)
- Automatic rotation: Yes

### Sharing Reference Table

| Class                                                                | Sharing Declaration | Purpose                                        |
|----------------------------------------------------------------------|---------------------|------------------------------------------------|
| [`DML_Builder`](reference/apex/DML_Builder.md)                       | `inherited sharing` | Bulk DML operations with sharing proxy factory |
| `DML_SharingProxy.DatabaseProxy`                                     | `inherited sharing` | Base DML proxy (virtual)                       |
| `DML_SharingProxy.DatabaseProxyWithoutSharing`                       | `without sharing`   | DML with sharing bypassed                      |
| `DML_SharingProxy.DatabaseProxyWithSharing`                          | `with sharing`      | DML with sharing enforced                      |
| [`QRY_Builder`](reference/apex/QRY_Builder.md)                       | `inherited sharing` | Fluent query builder                           |
| `QRY_Engine`                                                         | `inherited sharing` | Query executor                                 |
| `QRY_Engine.WithSharingExecutor`                                     | `with sharing`      | Query with sharing enforced                    |
| `QRY_Engine.WithoutSharingExecutor`                                  | `without sharing`   | Query with sharing bypassed                    |
| [`DML_Transaction`](reference/apex/DML_Transaction.md)               | `inherited sharing` | Transaction management                         |
| [`TST_Builder`](reference/apex/TST_Builder.md)                       | `without sharing`   | Test data factory                              |
| [`UTIL_Sharing`](reference/apex/UTIL_Sharing.md)                     | `inherited sharing` | Share record management                        |
| [`UTIL_SessionEncryption`](reference/apex/UTIL_SessionEncryption.md) | `with sharing`      | Session encryption                             |

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
