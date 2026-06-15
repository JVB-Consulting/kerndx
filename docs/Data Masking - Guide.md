# Data Masking - Guide

**Framework:** KernDX
**Package Type:** Managed Package

**Target Audience:**

- **Developers** - Redacting sensitive values in logs, callouts, async jobs, and on records before they are stored
- **Admins** - Configuring which objects and fields are masked, without writing Apex
- **Security & Compliance** - Reviewing masking coverage and exporting a regulated-field inventory

---

## Table of Contents

<details>
<summary>Expand</summary>

1. [Quick Navigation](#quick-navigation)
2. [Overview](#overview)
    - [What Masking Does](#what-masking-does)
    - [What Masking Is Not](#what-masking-is-not)
    - [Architecture](#architecture)
3. [Quick Start](#quick-start)
4. [What Ships Masked by Default](#what-ships-masked-by-default)
5. [Masking Rules](#masking-rules)
    - [Modes](#modes)
    - [Failure Actions](#failure-actions)
    - [The Shipped Rules](#the-shipped-rules)
    - [Rule Fields](#rule-fields)
    - [Naming Your Own Rules](#naming-your-own-rules)
6. [Masking Records on Your Own Objects](#masking-records-on-your-own-objects)
    - [The Three Gates](#the-three-gates)
    - [Step 1 - Enable Masking on the Object](#step-1---enable-masking-on-the-object)
    - [Step 2 - Declare a Masking Target](#step-2---declare-a-masking-target)
    - [Caller-Class Scoping](#caller-class-scoping)
    - [What Record-Value Masking Does Not Do](#what-record-value-masking-does-not-do)
    - [Deploying the Configuration](#deploying-the-configuration)
7. [The Data Masking Advisor](#the-data-masking-advisor)
    - [Where It Lives](#where-it-lives)
    - [The Coverage Workflow](#the-coverage-workflow)
    - [Scanning Custom Objects](#scanning-custom-objects)
    - [Exporting a Regulated-Field Inventory](#exporting-a-regulated-field-inventory)
    - [Testing a Rule](#testing-a-rule)
    - [What the Advisor Does Not Do](#what-the-advisor-does-not-do)
    - [Health Check Cards](#health-check-cards)
8. [Programmatic Access](#programmatic-access)
9. [Capability Matrix](#capability-matrix-for-analysts)
10. [Testing](#testing)
11. [Performance](#performance)
12. [Anti-Patterns](#anti-patterns)
13. [Best Practices](#best-practices)
14. [Related Documentation](#related-documentation)

</details>

---

## Quick Navigation

| I want to...                                  | Go to                                                                 |
|-----------------------------------------------|-----------------------------------------------------------------------|
| Get masking working in a few minutes          | [Fast Start - Data Masking](Fast%20Start%20-%20Data%20Masking.md)      |
| Understand what is masked out of the box       | [What Ships Masked by Default](#what-ships-masked-by-default)          |
| Mask fields on my own object                   | [Masking Records on Your Own Objects](#masking-records-on-your-own-objects) |
| Review coverage without writing Apex           | [The Data Masking Advisor](#the-data-masking-advisor)                  |
| Check masking state from Apex                  | [Programmatic Access](#programmatic-access)                           |
| Understand the limits of masking               | [What Masking Is Not](#what-masking-is-not)                            |
| See the masking story from a security angle    | [Security - Guide](Security%20-%20Guide.md#data-masking)              |

---

## Overview

### What Masking Does

KernDX data masking redacts sensitive values so they never reach a place they should not be. It works in **two ways**:

1. **Framework-path redaction (on by default).** As the framework's own data flows outward — debug logs, outbound API call records, async-chain execution
   records, and platform events — credit-card numbers and secret-bearing JSON keys are redacted before the value is persisted. You configure nothing to get this.

2. **Record-value masking (you opt in per object).** For any object you configure with a masking target, the value is redacted **on the record itself**, in the
   `before insert` / `before update` window, just before it is written. Downstream trigger logic and the saved row both see the masked value.

Both modes run through one engine and one rule catalogue. The difference is *where* the value is redacted — in transit through a framework path, or on a record you own.

> The single source of truth for the two-mode scope is the Advisor's own banner: *"Masking redacts sensitive values in two ways: as the framework's own data
> flows out (debug logs, outbound API callouts, async jobs, and platform events), and — for any object you configure with a masking target — on the record
> itself, just before it is inserted or updated. It is not encryption-at-rest: it does not change values that are already stored, and it does not restrict who
> can view a field beyond your field-level security."*

### What Masking Is Not

Masking is a one-way redaction. Knowing its boundaries keeps you from reaching for it where a different control belongs:

| Masking is **not**...    | Because...                                                                                                                                              | Use instead                                  |
|--------------------------|---------------------------------------------------------------------------------------------------------------------------------------------------------|----------------------------------------------|
| **Retroactive**          | Record-value masking runs on `before insert` / `before update` only. It redacts records as they are written — it does **not** scan or rewrite rows already stored. | A one-time batch scrub for existing data     |
| **Reversible**           | The transform is a regex / literal / JSON-key substitution with no key and no ciphertext. There is no decrypt path; the original value is not retained. | Shield Platform Encryption (at-rest, reversible) |
| **Encryption**           | Masking replaces characters with a marker; it does not encrypt. Distinct from Shield Platform Encryption and from Salesforce Data Mask (sandbox-only).  | Shield, for encryption-at-rest               |
| **Access control**       | A masked field is still visible to anyone with field-level security to read it — masking changes the stored/emitted *value*, not *who can see it*.       | Field-Level Security, sharing                |
| **For non-text fields**  | Only text-shaped fields can be masked (see [What Record-Value Masking Does Not Do](#what-record-value-masking-does-not-do)).                              | A validation rule or a different field type  |

For scrubbing **existing** data on a schedule (sandbox refresh, periodic anonymisation), reach for a batch tool such as the `mask-sobject` open-source library —
that is a different job than this framework's in-flight redaction.

### Architecture

Three pieces work together:

```text
┌──────────────────────────────────────────────────────────────────┐
│  Rules (MaskingRule__mdt)        — WHAT to look for + how to redact│
│  18 shipped (3 active, 15 dormant templates)                       │
├──────────────────────────────────────────────────────────────────┤
│  Targets (MaskingTarget__mdt)    — WHERE to apply a rule           │
│  Rule × Object × Field (+ optional caller scope)                   │
├──────────────────────────────────────────────────────────────────┤
│  Engine                          — applies active targets          │
│  Framework paths (logger / DML / outbound)  +  before-save records │
└──────────────────────────────────────────────────────────────────┘
            ▲
            │  reviewed and configured with no Apex via
┌──────────────────────────────────────────────────────────────────┐
│  Data Masking Advisor (LWC console)  — review coverage, assign     │
│  rules, export a deployable configuration                          │
└──────────────────────────────────────────────────────────────────┘
```

A **rule** says *what* a sensitive value looks like and *how* to redact it. A **target** wires a rule to a *where* — an object, optionally a specific field, optionally
a specific calling class. The **engine** applies every active target on the paths above. The **Advisor** is a point-and-click console for reviewing coverage and
producing a deployable configuration — it never changes your org on its own.

---

## Quick Start

**See the default redaction (no setup).** Emit a log entry whose message carries a secret-bearing JSON key, then read the stored entry — the value is already redacted:

```apex
kern.LOG_Builder.build()
    .info('{"user":"alice","api_key":"sk-live-9f8e7d6c5b4a"}')
    .at('Demo.maskingQuickStart')
    .emit();
// The persisted LogEntry message reads: {"user":"alice","api_key":"***SECRET***"}
```

**Confirm masking is enabled** from anywhere (subscriber Apex, anonymous Apex, a test):

```apex
Boolean maskingOn = kern.UTIL_FeatureFlag.isEnabled('MaskingFramework_Enabled'); // true by default
```

**Mask a field on your own object** — the recommended path is the Data Masking Advisor: open **Data Masking Advisor** from the App Launcher, pick your object,
assign a rule to the sensitive field, and click **Export** to download a ready-to-deploy configuration. The Advisor writes the metadata for you; you deploy it. See
[The Coverage Workflow](#the-coverage-workflow).

---

## What Ships Masked by Default

Two rules do the masking work on the framework's own objects, so the framework never persists secrets it handled on your behalf:

| Active rule        | Redacts                                                   | Wired to                                                                 |
|--------------------|-----------------------------------------------------------|--------------------------------------------------------------------------|
| `MaskPaymentCard`  | 13–19 digit payment-card numbers that pass the Luhn check | `ApiCall__c`, `ApiIssue__c`, `AsyncChainExecution__c`, `LogEntryEvent__e` |
| `MaskSecretKeys`   | Values under secret-bearing JSON keys (`password`, `token`, `api_key`, `authorization`, `bearer`, `client_secret`, `access_token`, `refresh_token`, …) | the same four framework objects |

These are wired through **8 masking targets** — one payment-card target and one secret target on each of the four framework objects — and each is an
*object-wide wildcard* (no specific field, so every text-shaped field on the object is covered). Concretely, this is what gets redacted before persistence:

- **Logs** — `LogEntryEvent__e` messages and context (the logger path).
- **Outbound API records** — `ApiCall__c` request content, including request bodies stored as attachments (the outbound path).
- **API issues and async-chain records** — `ApiIssue__c` and `AsyncChainExecution__c` payloads.

A third rule also ships active: `MaskCreditCard`, the original credit-card rule that `MaskPaymentCard` replaces. It still ships — along with its four framework targets — so
existing configurations that reference it keep working, but on the four framework objects above the payment-card rule does the work. If you have customised either rule (changed
its pattern, replacement, or other behaviour), your customisation wins: a customised `MaskCreditCard` keeps running everywhere it is wired, and customising `MaskPaymentCard`
turns the takeover off so both rules run.

> **No business object is masked out of the box.** None of the shipped targets point at Contact, Account, Case, or any custom object. Masking records on your own
> objects is opt-in — see the next sections.

The whole subsystem has a master switch: the `MaskingFramework_Enabled` feature flag, which defaults **on**. Turning it off disables all masking (useful only for a
deliberate, temporary diagnostic).

---

## Masking Rules

A `MaskingRule__mdt` record defines a pattern, a redaction, and how to behave on failure. KernDX ships 18; you can add your own.

### Modes

Every rule runs in exactly one of four **modes** (`Mode__c`):

| Mode         | What it matches                                                                                                            |
|--------------|----------------------------------------------------------------------------------------------------------------------------|
| `Regex`      | A standard regular expression. Matched substrings are replaced. Honours the rule's `CaseSensitive__c` flag.                 |
| `CreditCard` | A regex **plus** a Luhn (mod-10) checksum — only matches that are valid card numbers are redacted, so a 16-digit order number survives. |
| `JsonKey`    | Treats the value as JSON and redacts the value under each matching **key**, recursing into nested objects. Non-JSON input falls back to a regex pass. |
| `ExactMatch` | The pattern is matched as a literal substring (no regex metacharacters).                                                    |

An unrecognised mode is a no-op — the value passes through unchanged.

### Failure Actions

If a rule throws while masking a value, its `FailureAction__c` decides what happens:

| Action               | Behaviour                                                                                                                 |
|----------------------|---------------------------------------------------------------------------------------------------------------------------|
| `LogAndContinue`     | Logs a warning and keeps the original value. The safest default for non-critical fields.                                   |
| `WriteFailureMarker` | Replaces the field with the marker `[MASKING_FAILURE]` so a failed redaction can never silently leak the real value.       |
| `BlockDml`           | Throws `kern.UTIL_Exceptions.MaskingBlockedException`, aborting the surrounding save. Use when an unmasked value must never persist. |

When a rule fails, the engine also disables that rule for the rest of the transaction (so one bad value does not repeatedly throw across a bulk batch) and records
the failure on the masking result it returns internally.

### The Shipped Rules

KernDX ships **18 rules**. Three are **active** (wired to the framework objects above); the other **15 are dormant templates** — proven patterns you activate by wiring
a target to them. Activating a template takes two things: an active target that references it, and (if it is one of the dormant rules) flipping the rule's own
`IsActive__c` to true.

| Rule                        | Mode       | Active | Redacts                                                            |
|-----------------------------|------------|--------|-------------------------------------------------------------------|
| `MaskPaymentCard`           | CreditCard | Yes    | 13–19 digit Luhn-valid card numbers → `[CARD_REDACTED]`           |
| `MaskSecretKeys`            | JsonKey    | Yes    | Secret-bearing JSON key values → `***SECRET***`                    |
| `MaskCreditCard`            | CreditCard | Yes    | Issuer-prefixed card numbers — replaced by `MaskPaymentCard`; kept for compatibility |
| `MaskAddress`               | Regex      | No     | Whole field → `[ADDRESS_REDACTED]`                                 |
| `MaskAuthHeader`            | Regex      | No     | HTTP `Authorization` header value (consumes a `Bearer` prefix)    |
| `MaskAwsAccessKey`          | Regex      | No     | `AKIA` / `ASIA` AWS access-key IDs                                 |
| `MaskEmail`                 | Regex      | No     | Email local part (keeps the domain)                               |
| `MaskFreeText`              | Regex      | No     | Whole field → `[TEXT_REDACTED]`                                   |
| `MaskHealthKeywords`        | JsonKey    | No     | PHI JSON keys (`diagnosis`, `mrn`, `rx_number`, …) → `***PHI***`  |
| `MaskIban`                  | Regex      | No     | IBAN account numbers                                              |
| `MaskIpv4Private`           | Regex      | No     | RFC 1918 + loopback IPv4 addresses                                |
| `MaskJwt`                   | Regex      | No     | `eyJ`-prefixed JSON Web Tokens                                    |
| `MaskMedicareBeneficiaryId` | Regex      | No     | 11-character CMS Medicare Beneficiary Identifiers                 |
| `MaskPhoneInternational`    | Regex      | No     | Whole field → `[PHONE_REDACTED]`                                  |
| `MaskPhoneUS`               | Regex      | No     | US-format phone numbers                                           |
| `MaskSsn`                   | Regex      | No     | US Social Security Numbers → `XXX-XX-XXXX`                        |
| `MaskSwiftBic`              | Regex      | No     | 8/11-character SWIFT/BIC codes                                    |
| `MaskUrlBasicAuth`          | Regex      | No     | `user:password@` credentials embedded in URLs                     |

> **A note on the whole-field redactors.** `MaskAddress`, `MaskFreeText`, and `MaskPhoneInternational` use the pattern `(?s).+`, which redacts the *entire field
> value*. They are named for the kind of field you would point them at, not for a value-shaped pattern they detect. They are the natural choice for record-value
> masking, where you want a known-sensitive field blanked rather than a substring within free text scrubbed. `MaskPhoneUS`, by contrast, detects US phone-number
> *shapes* inside a larger string.

### Rule Fields

Each `MaskingRule__mdt` carries these fields:

| Field                      | Purpose                                                                                                                      |
|----------------------------|-----------------------------------------------------------------------------------------------------------------------------|
| `Mode__c`                  | One of the four modes above.                                                                                                 |
| `Pattern__c`               | The regex (Regex / CreditCard), key pattern (JsonKey), or literal (ExactMatch).                                              |
| `Replacement__c`           | The text written in place of a match (e.g. `***SECRET***`).                                                                  |
| `IsActive__c`              | Whether the rule may run at all.                                                                                             |
| `FailureAction__c`         | `LogAndContinue` / `WriteFailureMarker` / `BlockDml`.                                                                        |
| `CaseSensitive__c`         | Whether matching is case-sensitive (default false).                                                                          |
| `Order__c`                 | Rules run in ascending `Order__c` — lower numbers first.                                                                     |
| `MinInputLength__c`        | The engine skips inputs shorter than this length before running the rule (e.g. `MaskPaymentCard` uses `13`). Blank = no floor. |
| `ApplicableFieldTypes__c`  | A semicolon list (`STRING;TEXTAREA;URL;EMAIL;PHONE;ENCRYPTEDSTRING`) limiting which field types the rule fires on. Blank = all text-shaped types. |
| `Description__c`           | Free-text description shown in the Advisor.                                                                                  |
| `Replaces__c`              | On a shipped replacement rule: the developer name of the older rule it replaces. While both rules still carry their original shipped values, the newer rule does the work wherever both are wired to the same object. Managed by the package — leave blank on your own rules. |
| `ReplacesFingerprint__c`   | Fingerprint of the replaced rule's original shipped values. Any customisation you make to the older rule keeps it running. Managed by the package. |
| `ShippedFingerprint__c`    | Fingerprint of this rule's own shipped values. Customising the replacement rule turns the takeover off — both rules then run. Managed by the package. |

### Naming Your Own Rules

Give every rule you create a developer name of its own — one no shipped rule already uses. The most common duplicate is accidental: when customising a *packaged*
rule through a metadata deployment, the record name needs the namespace prefix (`kern__MaskingRule.kern__MaskPaymentCard`). Deploy the same record under the
unprefixed name (`kern__MaskingRule.MaskPaymentCard`) and the platform does not update the packaged rule — it creates a second, org-local rule with the same
developer name. (Editing a packaged rule's values in Setup carries no such risk.)

A duplicate name is tolerated. Masking keeps running — the engine detects the clash and switches to a slightly slower read of the masking configuration — and a
warning appears in the stored log entries listing the duplicated names, so you can find the org-local record and rename or remove it. Treat the warning as
housekeeping rather than an emergency: nothing stops masking, but the slower read repeats in every transaction until the duplicate is gone. The same tolerance
covers duplicated masking-target names.

---

## Masking Records on Your Own Objects

Framework-path redaction is automatic. To mask values **on a record you own** — a `Contact.SSN__c`, an `Application__c.Bank_Account__c` — you add configuration. No
Apex required.

### The Three Gates

Record-value masking fires for a record only when **all three** of these hold, and the operation is `before insert` or `before update`:

1. The `MaskingFramework_Enabled` feature flag is on (it is, by default).
2. The object's `TriggerSetting__mdt` has `ApplyMasking__c` checked.
3. At least one **active** masking target resolves a field on that object.

Masking runs as a pre-step **before** your configured trigger actions, so every downstream handler — and the stored row — sees the redacted value.

### Step 1 - Enable Masking on the Object

`ApplyMasking__c` (a checkbox on `kern__TriggerSetting__mdt`) defaults to **true**, but a subtlety matters: the default only reaches objects that *have* a
`TriggerSetting__mdt` record. The shipped trigger settings cover the framework's own objects, so a business object such as `Contact` typically has **no**
`TriggerSetting__mdt` yet — and an object with no trigger setting is **not** masked.

So the first step for a business object is to ensure it has a `kern__TriggerSetting__mdt` record with `kern__ApplyMasking__c = true`. If the object already runs
through the KernDX trigger framework (it has a trigger setting because you use trigger actions on it), masking is already enabled there — confirm the checkbox is on.

> The Data Masking Advisor's export bundle includes this trigger setting for you when the object needs one — another reason to prefer the Advisor over hand-authoring.

### Step 2 - Declare a Masking Target

A `MaskingTarget__mdt` record wires a rule to a place. It has five fields:

| Field             | Meaning                                                                                                                          | Required |
|-------------------|---------------------------------------------------------------------------------------------------------------------------------|----------|
| `Rule__c`         | The `MaskingRule__mdt` to apply (its developer name, e.g. `MaskSecretKeys`).                                                     | Yes      |
| `SObjectType__c`  | The object API name (e.g. `kern__ApiCall__c`, or your own `Contact`).                                                            | Yes      |
| `Field__c`        | A specific field. **Leave blank for an object-wide wildcard** — every text-shaped field on the object.                           | No       |
| `CallerClass__c`  | Restrict the target to calls from one Apex class (blank = any caller). See [Caller-Class Scoping](#caller-class-scoping).        | No       |
| `IsActive__c`     | Turn the target on or off without deleting it. Defaults to true.                                                                  | No       |

A **specific-field** target (a set `Field__c`) takes precedence over a wildcard target for the same rule and caller, so you can blanket an object and carve out
exceptions.

Here is a shipped wildcard target — the secret-key target on `ApiCall__c` — as a worked example of the XML shape:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<CustomMetadata xmlns="http://soap.sforce.com/2006/04/metadata" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema">
    <label>Secret / ApiCall__c.*</label>
    <protected>false</protected>
    <values>
        <field>CallerClass__c</field>
        <value xsi:nil="true"/>          <!-- blank = applies to every caller -->
    </values>
    <values>
        <field>Field__c</field>
        <value xsi:nil="true"/>          <!-- blank = object-wide wildcard -->
    </values>
    <values>
        <field>IsActive__c</field>
        <value xsi:type="xsd:boolean">true</value>
    </values>
    <values>
        <field>Rule__c</field>
        <value xsi:type="xsd:string">MaskSecretKeys</value>
    </values>
    <values>
        <field>SObjectType__c</field>
        <value xsi:type="xsd:string">ApiCall__c</value>
    </values>
</CustomMetadata>
```

> **In a subscriber org**, the type is `kern__MaskingTarget__mdt` and its fields and the packaged rule name carry the `kern__` prefix (`kern__Rule__c`,
> `kern__SObjectType__c`, and a packaged rule reference such as `kern__MaskSecretKeys`). Getting these namespace forms exactly right by hand is fiddly — which is why
> the **Advisor export is the recommended path**: it generates the correct metadata for your org, namespacing and all.

### Caller-Class Scoping

`CallerClass__c` narrows a target to calls originating from one Apex class. Leave it blank and the target applies to every caller (this is how all shipped targets
work). Set it to a class name and the target fires only when that class invoked the masking path — useful when one integration must redact a field that others may
legitimately store in full. All shipped targets leave it blank.

### What Record-Value Masking Does Not Do

State these limits to your stakeholders up front:

- **It is write-time, not retroactive.** Masking mutates the record in the `before` window before it is saved. It never scans or rewrites rows already in the
  database. Existing data stays as-is until the record is next inserted or updated.
- **It is destructive.** The masked value overwrites the field. The original plaintext is not retained anywhere and there is no reverse mapping.
- **It only applies to text-shaped fields** — Text, Text Area, Long Text Area, URL, Email, Phone, and Encrypted Text. Numbers, dates, checkboxes, picklists,
  lookups, and formula/read-only fields cannot be masked.
- **A `BlockDml` rule aborts the whole save.** If a `BlockDml` rule cannot redact a value, it throws `MaskingBlockedException` and the insert/update fails — by
  design, so an unmaskable secret never lands.
- **It is not encryption and not access control** — see [What Masking Is Not](#what-masking-is-not).

### Deploying the Configuration

Custom metadata is deployed metadata. Two paths:

- **Recommended — the Advisor export.** The [Data Masking Advisor](#the-data-masking-advisor) generates a deployable bundle (the rules, the targets, and any trigger
  setting the object needs) and shows you the exact CLI line to run from the unzipped folder. The line it produces is:

  ```bash
  sf project deploy start --metadata-dir metadata -o <your-org-alias>
  ```

- **By hand.** Author the `MaskingTarget__mdt` (and, if needed, `MaskingRule__mdt` and `TriggerSetting__mdt`) XML under your project's `customMetadata/` directory and
  deploy with the standard targeted command:

  ```bash
  sf project deploy start -m "CustomMetadata:MaskingTarget.<RecordName>" -o <your-org-alias>
  ```

Because the Advisor produces drift-free, correctly-namespaced metadata, prefer it for anything beyond a one-line tweak.

---

## The Data Masking Advisor

The Data Masking Advisor is a Lightning console for reviewing masking coverage and producing a deployable configuration — the front door for admins and security
reviewers who do not write Apex.

### Where It Lives

Open it from the **App Launcher** (search "Data Masking Advisor") or navigate directly to `/lightning/n/DataMaskingAdvisor`. A masking finding also surfaces in the
KernDX **Health Check** console, where a **Review masking** action deep-links to the Advisor.

### The Coverage Workflow

The Advisor centres on one object at a time:

1. **Pick an object.** The picker lists customisable, trigger-capable objects (masking runs through the trigger framework, so non-triggerable objects are excluded).
2. **Review its fields.** The Advisor classifies each field — using Salesforce's native data classification where present, and a name/type heuristic where not — and
   groups them into **Ready to mask**, **Needs review**, and **Other**. Each field shows whether a target already covers it.
3. **Assign rules.** Pick a masking rule per field from a searchable dropdown. The masking cell shows the assignment as a chip.
4. **Export.** Click **Export** to download a deployable bundle — the rules, the targets, and any trigger setting the object needs — plus the CLI line to deploy it.

### Scanning Custom Objects

The Advisor can sweep your custom objects for likely-sensitive fields that have no masking. The scan is **on-demand** — you press **Scan**, it runs a few objects at a
time through the same field analysis, reports the objects that need attention, and can be cancelled at any point while keeping what it found. It is bounded, not
exhaustive, and it changes nothing in your org.

### Exporting a Regulated-Field Inventory

For an audit or a data-protection review, the Advisor exports a **regulated-field inventory** — a spreadsheet-ready list of fields that hold (or likely hold)
regulated data, each row marked whether it is masked today. You choose the scope (custom objects scanned, objects with masking configured, or all objects), a format
(**CSV (spreadsheet)** or **JSON**), and an optional **Sensitive fields only** filter that narrows the export to fields classified Sensitive. The export is
read-only — nothing changes in your org.

### Testing a Rule

Before you commit to a rule, try it. The Advisor's rule detail offers a live **Test this rule** preview: type a sample value, pick a rule, and see the masked
output. For a JSON-key rule it prompts for JSON input. The preview runs the real engine against your sample — it never reads or writes record data.

### What the Advisor Does Not Do

Three honest boundaries:

- **It never writes to your org.** Every output — the export bundle, the inventory — is generated text you download and deploy yourself. The Advisor has no
  "apply" button that mutates metadata.
- **Its counts are as-configured, not a field scan.** "Objects with masking configured" reflects the masking targets you have set up, not a field-by-field crawl of
  your schema. The custom-object scan is the one place it actively inspects fields, and only on demand.
- **It is a point-in-time review tool, not continuous monitoring.** It analyses when you open it or press a button. It is not a background watcher or a compliance
  scanner — KernDX is an accelerator, and ongoing org monitoring belongs to tools built for it (Salesforce Shield, Security Health Check, and the like).

> **One classification nuance to know:** the Advisor flags a field as Sensitive whenever it carries *any* non-blank Salesforce data classification — including
> `Public` or `Internal`. If a field you consider low-risk shows up as Sensitive in the inventory or coverage scan, check its **Compliance Categorization** /
> **Data Sensitivity Level** in the field's setup; the Advisor is reflecting that metadata.

### Health Check Cards

The KernDX Health Check surfaces masking as two cards:

- **Masking configuration** — flags masking targets that are active but point at an inactive or missing rule, so they silently mask nothing despite appearing
  configured.
- **Masking coverage (custom objects)** — a bounded sweep that lists custom objects holding likely-sensitive fields with no masking.

Both deep-link into the Advisor to resolve what they find.

---

## Programmatic Access

Masking is **configuration-driven by design**. A subscriber wires up masking with custom metadata and the Advisor, not by calling an engine from Apex. The engine
that performs redaction is part of the package internals and is not part of the public Apex API, so the supported programmatic surface is deliberately small:

**Confirm masking is enabled** — the supported probe, callable from subscriber Apex, anonymous Apex, or a test:

```apex
if (kern.UTIL_FeatureFlag.isEnabled('MaskingFramework_Enabled'))
{
    // masking is active
}
```

**Catch a blocking failure** — a `BlockDml` rule that cannot redact a value throws an exception you can catch:

```apex
try
{
    insert sensitiveRecord;
}
catch (kern.UTIL_Exceptions.MaskingBlockedException e)
{
    // a BlockDml rule refused to let an unmasked value persist
}
```

**Redact an ad-hoc string** — for the occasional case where you need to scrub a string in your own code (not record or framework masking), `kern.UTIL_String`
exposes string helpers such as `maskString` and `abbreviate`. These are general-purpose string utilities, not the masking engine; reach for configuration-driven
masking for anything that should be governed by your rule catalogue.

> The right way to mask a field a subscriber owns is a `MaskingTarget__mdt` plus `ApplyMasking__c`, reviewed in the Advisor — not an Apex call. That keeps masking
> declarative, auditable, and visible to the Advisor's coverage view.

---

## Capability Matrix (for Analysts)

| Capability                                  | Supported | Notes                                                                                 |
|---------------------------------------------|-----------|---------------------------------------------------------------------------------------|
| Redact framework logs / callouts by default | ✅        | Three active rules on four framework objects (two do the masking work; the legacy credit-card rule ships for compatibility); on out of the box |
| Mask records on a subscriber object         | ✅        | `MaskingTarget__mdt` + `ApplyMasking__c`; `before insert` / `before update`            |
| Regex / credit-card / JSON-key / literal    | ✅        | Four modes; credit-card adds a Luhn check                                              |
| Fail-open / marker / block-save behaviour   | ✅        | `LogAndContinue` / `WriteFailureMarker` / `BlockDml`                                    |
| Per-field, per-object, per-caller scope     | ✅        | Wildcard or specific field; optional caller-class scope                                |
| No-code review and configuration            | ✅        | Data Masking Advisor (review, assign rules, export)                                    |
| Regulated-field inventory export            | ✅        | CSV / JSON, optional Sensitive-only filter                                             |
| Mask existing stored data                   | ❌        | Write-time only; use a batch scrub for data already saved                              |
| Reversible / decrypt                        | ❌        | One-way redaction; use Shield for encryption-at-rest                                   |
| Mask non-text fields                        | ❌        | Text-shaped fields only                                                                |
| Restrict who can view a field               | ❌        | Use Field-Level Security; masking changes the value, not visibility                    |

---

## Testing

You verify masking the way the framework runs it — through behaviour, not by calling the engine. Patterns:

**Assert the flag state** drives a code path:

```apex
@IsTest
static void maskingIsEnabledByDefault()
{
    System.Assert.isTrue(kern.UTIL_FeatureFlag.isEnabled('MaskingFramework_Enabled'));
}
```

**Assert a `BlockDml` rule aborts a save** by expecting the exception:

```apex
@IsTest
static void blockDmlRuleStopsTheInsert()
{
    Test.startTest();
    try
    {
        insert recordThatTripsABlockDmlRule;
        System.Assert.fail('Expected MaskingBlockedException');
    }
    catch (kern.UTIL_Exceptions.MaskingBlockedException e)
    {
        // expected
    }
    Test.stopTest();
}
```

**Assert the stored value is redacted** after a masked write — query the field back and assert it no longer contains the sensitive value (and, where applicable,
that it contains the rule's replacement marker). Because masking runs in the `before` window, the redaction is present the moment the record is committed.

> Toggle masking off for a control test by deploying the `MaskingFramework_Enabled` flag off for that scenario, or assert behaviour on an object with no masking
> target as your negative case.

---

## Performance

Masking is built to run inside triggers and bulk DML without becoming the bottleneck:

- **Per-transaction caching.** The engine builds each object's masking plan once and reuses it across the records in a transaction, so a 200-record bulk update
  resolves rules and targets once, not 200 times.
- **Cheap gates first.** A record is only examined when the master flag is on and the object opts in; an input shorter than a rule's `MinInputLength__c` is skipped
  before the (more expensive) pattern runs.
- **Luhn before replace.** Credit-card masking validates the checksum on each candidate match before redacting, so it does not rewrite numbers that merely look
  card-shaped.

For benchmarking your own configuration, run masking under a representative bulk load and watch CPU time; the cost scales with the number of *active targets* and
the size of the text being scanned, not with the rule catalogue size (dormant rules cost nothing).

---

## Anti-Patterns

| Anti-Pattern                                                        | Problem                                                                 | Better Approach                                                            |
|---------------------------------------------------------------------|-------------------------------------------------------------------------|----------------------------------------------------------------------------|
| **Masking to hide a field from a user**                             | Masking changes the stored/emitted value for everyone, not visibility   | Use Field-Level Security or sharing                                        |
| **Expecting masking to scrub existing rows**                        | Masking is write-time; old data is untouched                            | Run a one-time batch scrub, then let masking keep new writes clean         |
| **Masking a number/date/picklist field**                            | Only text-shaped fields are maskable                                    | Store the sensitive value in a text field, or use a different control      |
| **Hand-authoring `MaskingTarget__mdt` XML for many fields**         | Namespace and field-reference mistakes are easy and silent              | Use the Advisor export — it generates correct metadata                     |
| **Treating the Advisor as a compliance monitor**                    | It is a point-in-time review tool, not a background scanner             | Pair it with a monitoring product for ongoing posture                      |
| **Calling the masking engine from subscriber Apex**                 | The engine is package-internal and not callable across the namespace    | Configure `MaskingTarget__mdt` + `ApplyMasking__c`; probe the flag         |

---

## Best Practices

**Do:**

- Let the default framework-path redaction run — keep `MaskingFramework_Enabled` on.
- Use the Advisor to review coverage and export configuration; deploy the metadata it produces.
- Choose the failure action deliberately — `BlockDml` for values that must never persist unmasked, `WriteFailureMarker` to make failures visible, `LogAndContinue`
  for best-effort fields.
- Add a `TriggerSetting__mdt` with `ApplyMasking__c` for any business object you mask.
- Test masking through behaviour — the flag probe, the exception, and the stored value.

**Don't:**

- Don't rely on masking for access control or to protect data already stored.
- Don't expect a decrypt path — masking is one-way.
- Don't reach for the engine in Apex; configure it instead.

---

## Related Documentation

| Document                                                                | Description                                              |
|-------------------------------------------------------------------------|----------------------------------------------------------|
| [Fast Start - Data Masking](Fast%20Start%20-%20Data%20Masking.md)       | Get masking working in a few minutes                     |
| [Security - Guide](Security%20-%20Guide.md#data-masking)                | Masking in the broader security picture                  |
| [Triggers - Guide](Triggers%20-%20Guide.md)                             | `ApplyMasking__c` and the trigger framework              |
| [Web Services - Guide](Web%20Services%20-%20Guide.md)                   | A worked masking example on outbound callouts            |
| [LWC - Guide](LWC%20-%20Guide.md)                                       | The Data Masking Advisor component family                |
| [Objects & Metadata - Guide](Objects%20%26%20Metadata%20-%20Guide.md)   | `MaskingRule__mdt` and `MaskingTarget__mdt` schema       |
