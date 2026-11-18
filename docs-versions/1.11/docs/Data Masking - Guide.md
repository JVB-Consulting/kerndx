---
navOrder: 64
---

# Data Masking - Guide

**Framework:** KernDX
**Package Type:** Managed Package

> **Namespaces in code samples:** `kern.` on a class and `kern__` on an object, field, or metadata type mark the managed package's namespace.
> On the managed package, framework references need those prefixes even where a sample omits them; repackaged under your own namespace, replace `kern`/`kern__`
> with your prefix; on an unmanaged deploy, drop them. See [How to read the code samples](Installation.md#how-to-read-the-code-samples).

**Target Audience:**

- **Developers** - Redacting sensitive values in logs, callouts, async jobs, and on records before they are stored
- **Admins** - Configuring which objects and fields are masked, without writing Apex
- **Security & Compliance** - Reviewing masking coverage and exporting a regulated-field inventory

---

## What problem does this solve?

Sensitive values (a credit-card number, an API secret, a Social Security number) have a way of leaking into places they should never be stored: debug logs, saved API request bodies, background-job records, or a free-text field on a record.

Data masking replaces those values with a harmless marker so the real data is never written down. KernDX does this two ways. It redacts secrets in its own logs and integration records with no setup from you, and, for any object you choose, it blanks a sensitive field on the record just before it is saved. Admins and security reviewers configure all of this through a point-and-click console, with no Apex required.

Read this guide when you need to keep sensitive data out of logs and stored records, prove what is covered for an audit, or mask a field on one of your own objects. One thing to set expectations: masking is one-way redaction, not encryption and not access control, so it sits alongside Salesforce Shield and field-level security rather than replacing them.

---

## Mental model

Think of masking as a black marker held over a value on its way to being written down. As the value passes through one of the framework's own paths (a log, an outbound call, a background job), or as a record is about to be saved, the marker strikes out the sensitive part and leaves a harmless placeholder in its place. The pen only works at the moment of writing, it does not go back over pages already filed, and once a value is struck out there is no way to read what was underneath.

---

## Use this when

- You want secrets kept out of the framework's own logs, callout records, and background-job records. This is already on, with nothing to configure.
- You want a known-sensitive field on one of your own objects (an SSN, a bank account) blanked the moment a record is saved.
- You need to show an auditor which fields hold regulated data and which of them are protected today.
- You want admins or security reviewers to manage coverage through a point-and-click console rather than Apex.

## Don't use this when

- You need to control *who can see* a field. That is field-level security and sharing, not masking. A masked field is still visible to anyone whose permissions let them read it.
- You need the original value back. Masking is one-way with no decrypt path. For reversible, at-rest protection, use Shield Platform Encryption.
- You need to scrub data that is *already stored*. Masking only acts at write time. For a one-off clean-up of existing rows, use a batch tool such as the `mask-sobject` open-source library.
- You need to mask a number, date, picklist, or other non-text field. Only text-shaped fields can be masked.

---

## Table of Contents

<details>
<summary>Expand</summary>

1. [Quick Navigation](#quick-navigation)
2. [Quick Start](#quick-start)
3. [What does masking do?](#what-does-masking-do)
    - [What Masking Is Not](#what-masking-is-not)
    - [How does it work?](#how-does-it-work)
4. [What Ships Masked by Default](#what-ships-masked-by-default)
5. [Masking Rules](#masking-rules)
    - [Modes](#modes)
    - [How does a JSON-key rule read a value?](#how-does-a-json-key-rule-read-a-value)
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
    - [Card Rule Findings](#card-rule-findings)
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

## Quick Start

**See the default redaction (no setup).** Emit a log entry whose message carries a secret-bearing JSON key, then read the stored entry. The value is already redacted for you:

```apex
kern.LOG_Builder.build()
    .info('{"user":"alice","api_key":"sk-live-9f8e7d6c5b4a"}')
    .at('Demo.maskingQuickStart')
    .emit();
// The persisted LogEntry message reads: {"user":"alice","api_key":"***SECRET***"}
```

**Confirm masking is enabled** from anywhere (your own Apex, anonymous Apex, a test):

```apex
Boolean maskingOn = kern.UTIL_FeatureFlag.isEnabled('MaskingFramework_Enabled'); // true by default
```

**Mask a field on your own object.** The recommended path is the Data Masking Advisor. Open **Data Masking Advisor** from the App Launcher, pick your object,
assign a rule to the sensitive field, and click **Export** to download a ready-to-deploy configuration. The Advisor writes the metadata for you, and you deploy it. See
[The Coverage Workflow](#the-coverage-workflow).

---

## What does masking do?

The goal is simple: stop sensitive values from being written somewhere you do not want them. KernDX masking replaces a sensitive value with a harmless marker before it is stored. It does this in **two ways**:

1. **In the framework's own logs and integration records (on by default).** Whenever KernDX writes its own data (debug logs, outbound API call records, async-chain execution records, and platform events), it redacts credit-card numbers and secret-bearing JSON keys (and JSON Web Tokens on API call records and API issues) before saving them. You configure nothing to get this protection; it is already running.

2. **On records of objects you choose (you opt in).** For any object you set up with a masking target, the sensitive value is blanked **on the record itself**, in the moment just before it is saved (the `before insert` / `before update` window). Both your other trigger logic and the saved row see the masked value, not the original.

Both ways run through one engine and one shared set of rules. The only difference is *where* the value gets redacted: while it passes through one of the framework's own paths, or on a record you own.

> The single source of truth for the two-mode scope is the Advisor's own banner: *"Masking redacts sensitive values in two ways: as the framework's own data
> flows out (debug logs, outbound API callouts, async jobs, and platform events), and — for any object you configure with a masking target — on the record
> itself, just before it is inserted or updated. It is not encryption-at-rest: it does not change values that are already stored, and it does not restrict who
> can view a field beyond your field-level security."*

### What Masking Is Not

Masking is one-way redaction, and that is all it is. Knowing these boundaries keeps you from reaching for masking where a different control is the right tool:

| Masking is **not**...    | Because...                                                                                                                                              | Use instead                                  |
|--------------------------|---------------------------------------------------------------------------------------------------------------------------------------------------------|----------------------------------------------|
| **Retroactive**          | Record-value masking runs on `before insert` / `before update` only. It redacts records as they are written. It does **not** scan or rewrite rows already stored. | A one-time batch scrub for existing data     |
| **Reversible**           | The transform is a regex / literal / JSON-key substitution with no key and no ciphertext. There is no decrypt path; the original value is not retained. | Shield Platform Encryption (at-rest, reversible) |
| **Encryption**           | Masking replaces characters with a marker; it does not encrypt. Distinct from Shield Platform Encryption and from Salesforce Data Mask (sandbox-only).  | Shield, for encryption-at-rest               |
| **Access control**       | A masked field is still visible to anyone whose field-level security lets them read it. Masking changes the stored or emitted *value*, not *who can see it*.       | Field-Level Security, sharing                |
| **For non-text fields**  | Only text-shaped fields can be masked (see [What Record-Value Masking Does Not Do](#what-record-value-masking-does-not-do)).                              | A validation rule or a different field type  |

For scrubbing **existing** data on a schedule (a sandbox refresh, or periodic anonymisation), use a batch tool such as the `mask-sobject` open-source library.
That is a different job than this framework's in-flight redaction.

### How does it work?

The whole subsystem comes down to three moving parts plus a console to manage them:

```text
┌──────────────────────────────────────────────────────────────────┐
│  Rules (MaskingRule__mdt)        — WHAT to look for + how to redact│
│  18 shipped (3 active; 15 dormant: 14 templates, 1 older rule)     │
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

Read the three parts as *what*, *where*, and *do it*. A **rule** says *what* a sensitive value looks like and *how* to redact it. A **target** says *where* to apply a rule: an object, optionally a specific field, optionally a specific calling class. The **engine** does the work, applying every active target on the paths shown above. The **Advisor** sitting above them is a point-and-click console for reviewing coverage and producing a configuration you can deploy; on its own it never changes your org.

---

## What Ships Masked by Default

You get protection on day one with no configuration. The framework handles credit-card numbers, API secrets and access tokens on your behalf all the time (in logs, callouts, and background jobs), so it must never write those values down. Three rules do that masking work on the framework's own objects:

| Active rule        | Redacts                                                   | Wired to                                                                 |
|--------------------|-----------------------------------------------------------|--------------------------------------------------------------------------|
| `MaskPaymentCard`  | 13–19 digit payment-card numbers that pass the Luhn check | `ApiCall__c`, `ApiIssue__c`, `AsyncChainExecution__c`, `LogEntryEvent__e` |
| `MaskSecretKeys`   | Values under secret-bearing JSON keys (`password`, `token`, `api_key`, `authorization`, `bearer`, `client_secret`, `access_token`, `refresh_token`, …) | the same four framework objects |
| `MaskJwt`          | JSON Web Tokens, the signed access tokens many APIs pass around. Each one starts with `eyJ` and has three dot-separated parts | `ApiCall__c`, `ApiIssue__c` |

These are wired through **10 masking targets**: one payment-card target and one secret target on each of the four framework objects, plus one JSON Web Token target on each of `ApiCall__c` and `ApiIssue__c`. Each is an
*object-wide wildcard* (no specific field named, so every text-shaped field on the object is covered, whoever saves the record; see [Step 2](#step-2---declare-a-masking-target) for the few fields it leaves out). Concretely, this is what gets redacted before it is saved:

- **Logs:** `LogEntryEvent__e` messages and context (the logger path).
- **Outbound API records:** `ApiCall__c` request content, including request bodies stored as attachments (the outbound path).
- **API issues and async-chain records:** `ApiIssue__c` and `AsyncChainExecution__c` payloads.

Each request and response on an API call is masked once when the call is saved. When a payload is too long for its field, the whole masked text is saved in a file
attached to the call, so the file carries the same redaction as the record.

A fourth rule also ships, switched off: `MaskCreditCard`, the original credit-card rule that `MaskPaymentCard` replaces. Its four framework targets
(`ApiCall_All_Card`, `Chain_All_Card`, `Event_All_Card` and `Issue_All_Card`) ship switched off too. The newer rule finds the same cards, and the older rule has a cost:
on a long text full of digits, its pattern can use so much processing time that the save stops with an error no code can catch.

If you decide to use the older rule, switch it and its four targets on together. To stop using it, switch all five off together. A target that is on while its rule
is off masks nothing, and the Advisor and Health Check both flag it.

Your own customisations always win. If you change a setting that decides what a card rule masks (its pattern, mode, replacement, case setting, minimum input length or
field types), that change takes effect: a customised `MaskCreditCard` runs everywhere it is switched on and wired, and customising `MaskPaymentCard` switches the
takeover off, so both rules run. A changed failure action does not count as a customisation. It decides what happens when a rule fails, not what the rule masks, so
the payment-card rule still does the work.

> **No business object is masked out of the box.** None of the shipped targets point at Contact, Account, Case, or any custom object. Masking records on your own
> objects is opt-in, covered in the next sections.

The whole subsystem has one master off-switch: the `MaskingFramework_Enabled` feature flag, which defaults **on**. Turning it off disables all masking. That is useful only for a
deliberate, temporary diagnostic.

---

## Masking Rules

A rule is the recipe for finding and hiding one kind of sensitive value: what to look for, what to replace it with, and what to do if something goes wrong. Each rule lives in a `MaskingRule__mdt` record. KernDX ships 18 ready-made rules, and you can add your own.

### Modes

The mode decides *how* a rule recognises a sensitive value, so picking the right one is the difference between catching real secrets and accidentally scrubbing innocent text. Every rule runs in exactly one of four **modes** (`Mode__c`):

| Mode         | What it matches                                                                                                            |
|--------------|----------------------------------------------------------------------------------------------------------------------------|
| `Regex`      | A standard regular expression. Matched substrings are replaced. Honours the rule's `CaseSensitive__c` flag.                 |
| `CreditCard` | A regex **plus** a Luhn (mod-10) checksum, so only matches that are valid card numbers get redacted. A 16-digit order number survives. |
| `JsonKey`    | Treats the value as JSON and redacts the value under each matching **key**, recursing into nested objects. Text that is not JSON goes to a text search for `"key":"value"` pairs (see [How does a JSON-key rule read a value?](#how-does-a-json-key-rule-read-a-value)). The rule does not look inside JSON that is stored as text in another JSON value. |
| `ExactMatch` | The pattern is matched as a literal substring (no regex metacharacters).                                                    |

An unrecognised mode does nothing at all: the value passes through unchanged.

### How does a JSON-key rule read a value?

The shipped `MaskSecretKeys` rule is a JSON-key rule, so this is how secrets in API payloads and logs get found. How the rule reads a value depends on its shape
and size:

1. **A quick check before reading JSON.** If no key name the rule matches can appear anywhere in a JSON value, the value is left as it is, without reading it.
   A value longer than 16,384 characters is checked in pieces of that length. Two pieces in a row share 512 characters. So a key name that your rule matches, and
   that is longer than 512 characters, can be missed where one piece ends and the next begins. The value under that key is then not masked. This cannot happen
   with the shipped `MaskSecretKeys` rule, whose key names are short. The check is skipped, and the value is always read, when the value holds a backslash, or
   when your pattern has an open-ended repeat (`*`, `+` or `{n,}`) or a repeat with an upper count of three or more digits.
2. **Most JSON is read as a whole.** A JSON object or list with up to 500 opening brackets (`{` and `[` counted together) is read whole, and every key is checked
   down to 50 levels deep. A matching key nested deeper than 50 levels in such a value is not masked.
3. **Large or deeply nested JSON is read one piece at a time.** A JSON value with more than 500 opening brackets is read one name or value at a time, so every key is checked at
   any depth, however deep the nesting.
4. **Everything else goes to a text search.** Text that does not start and end like a JSON object or list (including JSON followed by other text, such as
   `{"token":"a"} and more`), and JSON that the platform's reader refuses, is searched as text for `"key":"value"` pairs.

The text search masks every plain value under a matching key: a text, a number, `true`, `false` or `null`. When a matching key holds an object, a list, or a value
whose end the search cannot find, the search cannot hide it safely, so the whole field is saved as `[MASKING_FAILURE]` instead. The field loses its detail, but no
secret is stored. A value counts as ended only when a comma, a closing brace or bracket, a space or the end of the text follows it. So `{"password":"x"}.` is masked
in place, but in `{"password":"x".}` a full stop follows the secret text, and the whole field gets the marker.

**Long JSON in a synchronous save.** In a save that someone waits for (a user's click, or an API request), JSON longer than 196,608 characters also goes to the text
search, because reading it as JSON takes too long. A request that runs longer than 5 seconds counts toward a platform limit on long-running requests, and new requests
are refused once that limit is reached. With the text search, a 2 MB JSON body masks in about 3 seconds in a synchronous save. Queueable, Batch, future and Scheduled
jobs have no one waiting, so they read JSON as JSON at any length.

A few limits of the text search are worth knowing:

- **Keys written with escapes.** A key written with JSON escapes (for example `p\u0061ssword` for `password`) is read by the name it stands for. A key with a
  backslash that JSON cannot read gives the search no name to check, so the whole field gets `[MASKING_FAILURE]`. Ordinary text with such a key does too: for example,
  a Windows path written as `"C:\path": 1`.
- **Very long keys.** The search reads long values in overlapping pieces. A key written longer than 512 characters (escapes count as written) can be missed where
  one piece ends and the next begins.
- **Values the search cannot read whole.** When the search cannot read a key together with its whole value, it cannot tell what the value holds, so the
  whole field gets `[MASKING_FAILURE]`. This can happen to a value that holds no secret too. Nothing secret is stored.
- **Key patterns with an open-ended or large repeat.** A key pattern with a repeat that has no upper limit, such as `.*secret.*`, can take so many steps on text full
  of quotes that the platform stops the save. A repeat whose upper count has three or more digits, such as `{1,100}`, is treated the same way, because the search
  cannot tell how many steps it takes. So the text search does not run with such a pattern: every value that goes to the text search and holds a quote gets
  `[MASKING_FAILURE]`. Nothing secret is stored, and the marker tells you the rule needs a narrower pattern, such as `^(secret|client_secret)$`.

### Failure Actions

Masking can occasionally hit an error while processing a value (for example, a rule whose pattern cannot compile), and you decide what happens next. The choice is a real trade-off: keep the original value, save a visible failure marker in its place, or refuse the save. A rule's `FailureAction__c` field sets that behaviour. Every shipped rule uses `WriteFailureMarker` or `BlockDml`, and `WriteFailureMarker` is the field's default for a rule you create.

| Action               | What happens to the value                                                                                       | What your code sees                                                    |
|----------------------|-----------------------------------------------------------------------------------------------------------------|------------------------------------------------------------------------|
| `LogAndContinue`     | The value is saved as it is, unmasked. The rule is then skipped for the rest of the transaction, so every later value it covers is saved unmasked too. | The save goes ahead, and a warning log entry names the rule.            |
| `WriteFailureMarker` | The value the rule failed on is saved as `[MASKING_FAILURE]`, and no later rule changes it. The rule keeps running on every other value. If the rule's pattern cannot compile, the rule can never mask anything, so every value it covers gets the marker. | The save goes ahead, the field holds `[MASKING_FAILURE]`, and a warning log entry names the rule. |
| `BlockDml`           | The value is not saved. The rule keeps blocking for the rest of the transaction, so every later save it meets is refused too. | It depends on what was being saved (see the list below).               |

The warning is written once for each rule in a transaction, so a bulk save that fails on many values adds one log entry, not hundreds. A failure on a log entry itself writes no warning, so the logger cannot start a loop.

What a `BlockDml` rule refuses depends on what was being saved:

- **A record save** (a record on your own object, or one of the framework's own records): the save fails with `kern.UTIL_Exceptions.MaskingBlockedException`, which your code can catch (see [Programmatic Access](#programmatic-access)).
- **The files an outbound call attaches for content too long for the call record:** no files are attached, the block is recorded among the call's errors, and the call still returns its answer to your code.
- **A log entry:** that one entry is dropped instead of being published unmasked, and the rest of your transaction carries on.

**The card rules ship with `WriteFailureMarker`.** Both `MaskPaymentCard` and `MaskCreditCard` use it. If a card rule fails on a value, the field holds
`[MASKING_FAILURE]`, which means masking failed on that value and the original was not stored. The save goes ahead, so an API call's log record is still saved. On
`BlockDml`, the same failure would refuse the call's log record, and the whole save that carries it would fail. The Data Masking Advisor flags a card rule that is
set to `BlockDml` (see [Card rule findings](#card-rule-findings)).

### The Shipped Rules

You do not have to write rules for common sensitive values; the framework already includes them. KernDX ships **18 rules**. Three are **active** (wired to the framework objects above). The other **15 are dormant**: 14 templates (ready-made patterns you switch on when you need them),
and the older card rule `MaskCreditCard`, which ships switched off together with its four targets (see
[What Ships Masked by Default](#what-ships-masked-by-default)). Activating a template takes two things: an active target that references it, and (because it is one of the dormant rules) setting the rule's own
`IsActive__c` to true.

<details>
<summary>All 18 shipped rules</summary>

| Rule                        | Mode       | Active | Redacts                                                            |
|-----------------------------|------------|--------|-------------------------------------------------------------------|
| `MaskPaymentCard`           | CreditCard | Yes    | 13–19 digit Luhn-valid card numbers → `[CARD_REDACTED]`           |
| `MaskSecretKeys`            | JsonKey    | Yes    | Secret-bearing JSON key values → `***SECRET***`                    |
| `MaskJwt`                   | Regex      | Yes    | `eyJ`-prefixed JSON Web Tokens → `[JWT_REDACTED]`                 |
| `MaskCreditCard`            | CreditCard | No     | Issuer-prefixed card numbers (replaced by `MaskPaymentCard`; ships switched off with its four targets) |
| `MaskAddress`               | Regex      | No     | Whole field → `[ADDRESS_REDACTED]`                                 |
| `MaskAuthHeader`            | Regex      | No     | HTTP `Authorization` header value (consumes a `Bearer` prefix)    |
| `MaskAwsAccessKey`          | Regex      | No     | `AKIA` / `ASIA` AWS access-key IDs                                 |
| `MaskEmail`                 | Regex      | No     | Email local part (keeps the domain)                               |
| `MaskFreeText`              | Regex      | No     | Whole field → `[TEXT_REDACTED]`                                   |
| `MaskHealthKeywords`        | JsonKey    | No     | PHI JSON keys (`diagnosis`, `mrn`, `rx_number`, …) → `***PHI***`  |
| `MaskIban`                  | Regex      | No     | IBAN account numbers                                              |
| `MaskIpv4Private`           | Regex      | No     | RFC 1918 + loopback IPv4 addresses                                |
| `MaskMedicareBeneficiaryId` | Regex      | No     | 11-character CMS Medicare Beneficiary Identifiers                 |
| `MaskPhoneInternational`    | Regex      | No     | Whole field → `[PHONE_REDACTED]`                                  |
| `MaskPhoneUS`               | Regex      | No     | US-format phone numbers                                           |
| `MaskSsn`                   | Regex      | No     | US Social Security Numbers → `XXX-XX-XXXX`                        |
| `MaskSwiftBic`              | Regex      | No     | 8/11-character SWIFT/BIC codes                                    |
| `MaskUrlBasicAuth`          | Regex      | No     | `user:password@` credentials embedded in URLs                     |

</details>

> **A note on the whole-field redactors.** `MaskAddress`, `MaskFreeText`, and `MaskPhoneInternational` use the pattern `(?s).+`, which redacts the *entire field
> value*. They are named for the kind of field you would point them at, not for a value-shaped pattern they detect. They are the natural choice for record-value
> masking, where you want a known-sensitive field blanked rather than just a substring scrubbed out of free text. `MaskPhoneUS`, by contrast, detects US phone-number
> *shapes* inside a larger string.

### Rule Fields

When you create or tune a rule, these are the fields you set. Each `MaskingRule__mdt` carries the following:

<details>
<summary>Every rule field</summary>

| Field                      | Purpose                                                                                                                      |
|----------------------------|-----------------------------------------------------------------------------------------------------------------------------|
| `Mode__c`                  | One of the four modes above.                                                                                                 |
| `Pattern__c`               | The regex (Regex / CreditCard), key pattern (JsonKey), or literal (ExactMatch).                                              |
| `Replacement__c`           | The text written in place of a match (e.g. `***SECRET***`).                                                                  |
| `IsActive__c`              | Whether the rule may run at all.                                                                                             |
| `FailureAction__c`         | `LogAndContinue` / `WriteFailureMarker` / `BlockDml`.                                                                        |
| `CaseSensitive__c`         | Whether matching is case-sensitive (default false).                                                                          |
| `Order__c`                 | Rules run in ascending `Order__c` (lower numbers first).                                                                     |
| `MinInputLength__c`        | The engine skips inputs shorter than this length before running the rule (e.g. `MaskPaymentCard` uses `13`). Blank = no floor. |
| `ApplicableFieldTypes__c`  | A semicolon list (`STRING;TEXTAREA;URL;EMAIL;PHONE;ENCRYPTEDSTRING`) limiting which field types the rule fires on. Blank = all text-shaped types. |
| `Description__c`           | Free-text description shown in the Advisor.                                                                                  |
| `Category__c`              | Optional short category label (up to 40 characters) shown beside the rule in the Advisor. Shipped rules use Contact, Personal, Payment, Health, Credentials, Financial, Identity or Network; reuse one, or enter your own. |
| `Replaces__c`              | On a shipped replacement rule: the developer name of the older rule it replaces. While both rules still carry their original shipped values, the newer rule does the work wherever both are wired to the same object. Managed by the package, so leave it blank on your own rules. |
| `ReplacesFingerprint__c`   | Fingerprint of the replaced rule's original shipped values. Any customisation you make to the older rule keeps it running. Managed by the package. |
| `ShippedFingerprint__c`    | Fingerprint of this rule's own shipped values. Customising the replacement rule turns the takeover off, so both rules then run. Managed by the package. |

</details>

### Naming Your Own Rules

A unique name keeps your rule from accidentally colliding with a shipped one, which is what causes the most common avoidable mistake here. So give every rule you create a developer name no shipped rule already uses.

That common mistake happens when you customise a *packaged* rule through a metadata deployment. To update the packaged rule, the record name needs the namespace prefix (`kern__MaskingRule.kern__MaskPaymentCard`). Deploy the same record under the
unprefixed name (`kern__MaskingRule.MaskPaymentCard`) instead, and the platform does not update the packaged rule at all: it creates a second, org-local rule with the same
developer name. (Editing a packaged rule's values in Setup carries no such risk.)

A duplicate name is tolerated, so masking keeps running. The engine notices the clash and switches to a slightly slower read of the masking configuration, and a
warning appears in the stored log entries listing the duplicated names. That tells you exactly which org-local record to rename or remove. Treat the warning as
housekeeping, not an emergency: nothing stops masking, but the slower read repeats in every transaction until the duplicate is gone. The same tolerance
covers duplicated masking-target names.

---

## Masking Records on Your Own Objects

You want a sensitive field on one of your own objects (say a `Contact.SSN__c` or an `Application__c.Bank_Account__c`) blanked before it is ever saved. Redaction on the framework's own paths is automatic, but masking a record you own is opt-in. You turn it on by adding configuration, with no
Apex required.

### The Three Gates

If your field is not getting masked, it is almost always because one of these conditions is not met. Record-value masking fires for a record only when **all three** of these hold, and only when the operation is `before insert` or `before update`:

1. The `MaskingFramework_Enabled` feature flag is on (it is, by default).
2. The object's `TriggerSetting__mdt` has `ApplyMasking__c` checked.
3. At least one **active** masking target resolves a field on that object.

Masking runs as a pre-step **before** your configured trigger actions. That ordering is deliberate: it means every downstream handler, and the stored row itself, sees the redacted value rather than the original.

### Step 1 - Enable Masking on the Object

Your goal here is to make sure the object even knows masking applies to it. The catch is subtle. `ApplyMasking__c` (a checkbox on `kern__TriggerSetting__mdt`) defaults to **true**, but that default only reaches objects that *already have* a
`TriggerSetting__mdt` record. The shipped trigger settings cover the framework's own objects, so a business object such as `Contact` typically has **no**
`TriggerSetting__mdt` yet, and an object with no trigger setting is **not** masked.

So the first step for a business object is to give it a `kern__TriggerSetting__mdt` record with `kern__ApplyMasking__c = true`. If the object already runs
through the KernDX trigger framework (it has a trigger setting because you use trigger actions on it), masking is already enabled there; just confirm the checkbox is on.

> The Data Masking Advisor's export bundle does not include this trigger setting. Create it yourself as described above, whether you deploy your targets from the Advisor's bundle or by hand.

### Step 2 - Declare a Masking Target

Now you point a rule at the exact place it should run. That connection is a `MaskingTarget__mdt` record, and it has five fields:

| Field             | Meaning                                                                                                                          | Required |
|-------------------|---------------------------------------------------------------------------------------------------------------------------------|----------|
| `Rule__c`         | The `MaskingRule__mdt` to apply (its developer name, e.g. `MaskSecretKeys`).                                                     | Yes      |
| `SObjectType__c`  | The object API name (e.g. `kern__ApiCall__c`, or your own `Contact`).                                                            | Yes      |
| `Field__c`        | A specific field. **Leave blank for an object-wide wildcard** (every text-shaped field on the object, whoever saves the record, except the fields explained below). | No       |
| `CallerClass__c`  | One service's API calls and API issues only (blank = any caller). See [Caller-Class Scoping](#caller-class-scoping).             | No       |
| `IsActive__c`     | Turn the target on or off without deleting it. Defaults to true.                                                                  | No       |

A **specific-field** target (one with `Field__c` set) takes precedence over a wildcard target for the same rule and caller. That lets you blanket an object and still carve out
exceptions.

A wildcard never touches a field that identifies the record (a unique field or an external id), however text-shaped it is. Masking rewrites the value it matches; on a key,
that rewrite destroys the key. A correlation id or order number long enough to look like a card number would come out as `[CARD_REDACTED]`, and the next record whose key
masks to the same constant would fail to save on a unique index. If you really do want a rule on such a field, name it explicitly in `Field__c`. An explicit target is
honoured; only the wildcard steps around it.

**Which fields a wildcard covers.** A wildcard covers every text field of the object: Text, Text Area, Long Text Area, Rich Text Area, URL, Email, Phone and
Encrypted Text. It leaves out a formula, a roll-up summary, an auto-number, a field that identifies the record (above), and two fields the
framework uses to track a chain run. On a platform event
it covers custom fields only. The list depends on what each field is, never on who saves the record. A user who cannot see or edit a field, such
as an integration user or the Automated Process user, has that field masked all the same. A few standard text fields pass these tests although
no one can write them (for example the contact email on a case, which the platform copies from the contact). If the platform refuses the masked
value for such a field, the framework skips the field for the rest of the transaction and writes one warning, and the save goes ahead.

Here is a shipped wildcard target, the secret-key target on `ApiCall__c`, as a worked example of the XML shape:

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

> **In your own org**, the type is `kern__MaskingTarget__mdt`, and its fields and the packaged rule name carry the `kern__` prefix (`kern__Rule__c`,
> `kern__SObjectType__c`, and a packaged rule reference such as `kern__MaskSecretKeys`). Getting these namespace forms exactly right by hand is fiddly, which is why
> the **Advisor export is the recommended path**: it generates the correct metadata for your org, namespacing and all.

### Caller-Class Scoping

Sometimes one integration needs a field redacted while other code may legitimately store the same field in full. The `CallerClass__c` field handles exactly that case: it narrows a target to calls coming from one Apex class. Leave it blank and the target applies to every caller (this is how all shipped targets
work). Set it to a class name and the target fires only when that class invoked the masking path. All shipped targets leave it blank.

A target with `CallerClass__c` set can only fire where the masking knows which class is calling. That is true in two places:

- **API call and API issue records** (`ApiCall__c` and `ApiIssue__c`). The calling class is the handler class that your API setting names for the record's
  service. Write the class name in `CallerClass__c` the same way the API setting writes it. A target scoped this way masks that service's calls and issues, and
  no others. A service with no API setting, or a setting with no class name, has no calling class.
- **The Advisor's Test this rule preview**, which masks your sample for the caller class the target names.

Saves of every other object have no calling class: your own objects, async-chain records and log events. There, a target with `CallerClass__c` set never fires,
and only targets with it blank apply.

### What Record-Value Masking Does Not Do

Set these limits with your stakeholders up front so no one expects a control masking does not provide:

- **It is write-time, not retroactive.** Masking changes the record in the `before` window, just before it is saved. It never scans or rewrites rows already in the
  database. Existing data stays as it is until the record is next inserted or updated.
- **It is destructive.** The masked value overwrites the field. The original plaintext is not kept anywhere, and there is no reverse mapping back to it.
- **It only applies to text-shaped fields:** Text, Text Area, Long Text Area, Rich Text Area, URL, Email, Phone, and Encrypted Text. Numbers, dates, checkboxes, picklists,
  lookups, and formula or read-only fields cannot be masked.
- **A `BlockDml` rule aborts the whole save.** If a `BlockDml` rule cannot redact a value, it throws `MaskingBlockedException` and the insert or update fails. That is by
  design, so an unmaskable secret never lands.
- **It is not encryption and not access control.** See [What Masking Is Not](#what-masking-is-not).

### Deploying the Configuration

Your masking rules and targets are custom metadata, so they take effect once you deploy them. You have two ways to do that:

- **Recommended: the Advisor export.** The [Data Masking Advisor](#the-data-masking-advisor) generates a deployable bundle (the targets, plus an
  activation file for each dormant rule you choose to switch on; the trigger setting is not included) and shows you the exact CLI line to run from the unzipped folder,
  with the org alias you type filled in:

  ```shell
  sf project deploy start --metadata-dir metadata -o YourOrgAlias
  ```

- **By hand.** Write the `MaskingTarget__mdt` XML (and, if needed, `MaskingRule__mdt` and `TriggerSetting__mdt`) under your project's `customMetadata/` directory and
  deploy with the standard targeted command:

  ```shell
  sf project deploy start -o YourOrgAlias -m "CustomMetadata:MaskingTarget.YourRecordName"
  ```

Because the Advisor produces drift-free, correctly-namespaced metadata, prefer it for anything beyond a one-line tweak.

---

## The Data Masking Advisor

If you would rather not hand-write metadata, this is your tool. The Data Masking Advisor is a point-and-click Lightning console for seeing what is masked, assigning rules to fields, and producing a configuration you can deploy. It is the front door for admins and security
reviewers who do not write Apex.

### Where It Lives

Open it from the **App Launcher** (search "Data Masking Advisor") or navigate directly to `/lightning/n/DataMaskingAdvisor`. A masking finding also surfaces in the
KernDX **Health Check** console, where a **Review masking** action links straight through to the Advisor.

### The Coverage Workflow

To go from "I think this object has sensitive fields" to deployable masking configuration, you work through one object at a time:

1. **Pick an object.** The picker lists customisable, trigger-capable objects (masking runs through the trigger framework, so objects that cannot have triggers are excluded).
2. **Review its fields.** The Advisor classifies each field, using Salesforce's native data classification where it is present and a name-and-type heuristic where it is not, then
   groups them into **Ready to mask**, **Needs review**, and **Other**. Each field shows whether a target already covers it.
3. **Assign rules.** Pick a masking rule per field from a searchable dropdown. The masking cell shows the assignment as a chip.
4. **Export.** Click **Export** to download a deployable bundle (the targets, plus an activation file for each dormant rule you chose to switch on) plus the CLI line to deploy it. The bundle
   does not include the object's trigger setting: create that separately, as the step that enables masking on the object describes.

### Scanning Custom Objects

Rather than review objects one by one, you can ask the Advisor to find the gaps for you. It sweeps your custom objects for likely-sensitive fields that have no masking. The scan is **on-demand**: you press **Scan**, it works through a few objects at a
time using the same field analysis, reports the objects that need attention, and can be cancelled at any point while keeping what it has found so far. It is bounded rather than
exhaustive, and it changes nothing in your org.

### Exporting a Regulated-Field Inventory

When an auditor asks "which fields hold regulated data, and which of them are protected?", you can answer with a single export. The Advisor produces a **regulated-field inventory**: a spreadsheet-ready list of fields that hold (or likely hold)
regulated data, each row marked whether it is masked today. You choose the scope (custom objects scanned, objects with masking configured, or all objects), a format
(**CSV (spreadsheet)** or **JSON**), and an optional **Sensitive fields only** filter that narrows the export to fields classified Sensitive. The export is
read-only, so nothing changes in your org.

### Testing a Rule

Before you commit to a rule, you can check it does what you expect. The Advisor's rule detail offers a live **Test this rule** preview: type a sample value, pick a rule, and see the masked
output. For a JSON-key rule it prompts for JSON input. The preview runs the real engine against your sample, and it never reads or writes record data.

### Card Rule Findings

The Advisor's **Configuration health** list checks the two card rules the package ships, and adds up to one finding for each. A finding has no title: the
Advisor shows its message, which explains the problem and what to do. The first column below gives the opening words of each message.

| The message starts with                    | When it shows                                                                                                                                                                    | What to do                                                                                                                                                       |
|--------------------------------------------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| Masking rule "MaskCreditCard" is the older card number rule, and it still runs. | `MaskCreditCard` is switched on and the payment-card rule does not replace it: `MaskPaymentCard` is off, or a setting that decides what one of the two rules masks was changed. A changed failure action does not count. | Keep `MaskPaymentCard` on. Switch `MaskCreditCard` off together with its four targets. If you decide to keep the older rule, switch the rule and its targets on together. |
| Masking rule "MaskPaymentCard" has the failure action Block DML. | `MaskPaymentCard` runs with the failure action `BlockDml`. If it fails on a value, the save stops: for an API call, the call's log record is refused and the whole save that carries it fails. | Change the rule's failure action to `WriteFailureMarker`. The field then holds the marker that says masking failed, and the original value is not stored. |

When the older rule both runs and is set to `BlockDml`, its one finding carries both pieces of advice. The older rule matters because, on a long text with many
digits, its pattern can use up all the processing time a save is allowed, and then the save fails.

### What the Advisor Does Not Do

Three honest boundaries to keep in mind:

- **It never writes to your org.** Every output (the export bundle and the inventory) is generated text that you download and deploy yourself. The Advisor has no
  "apply" button that changes metadata.
- **Its counts are as-configured, not a field scan.** "Objects with masking configured" reflects the masking targets you have set up, not a field-by-field crawl of
  your schema. The custom-object scan is the one place it actively inspects fields, and only on demand.
- **It is a point-in-time review tool, not continuous monitoring.** It analyses when you open it or press a button. It is not a background watcher or a compliance
  scanner. KernDX is an accelerator, and ongoing org monitoring belongs to tools built for that job (Salesforce Shield, Security Health Check, and the like).

> **One classification nuance to know:** the Advisor flags a field as Sensitive whenever it carries *any* non-blank Salesforce data classification, including
> `Public` or `Internal`. If a field you consider low-risk shows up as Sensitive in the inventory or coverage scan, check its **Compliance Categorization** and
> **Data Sensitivity Level** in the field's setup. The Advisor is simply reflecting that metadata.

### Health Check Cards

So you spot masking problems even when you are not actively reviewing, the KernDX Health Check surfaces masking as two cards:

- **Masking configuration:** flags masking targets that are active but point at an inactive or missing rule, so they silently mask nothing despite looking
  configured.
- **Masking coverage (custom objects):** a bounded sweep that lists custom objects holding likely-sensitive fields with no masking.

Both cards link into the Advisor so you can resolve what they find.

---

## Programmatic Access

Masking is **configuration-driven by design**. You set it up with custom metadata and the Advisor rather than by calling code, which keeps your masking declarative and visible in the Advisor's coverage view. So the supported programmatic surface is deliberately small, and it covers the two things you genuinely need from Apex: checking that masking is on, and reacting when a blocking rule refuses a save.

**Confirm masking is enabled.** This is the supported probe, and you can call it from your own Apex, anonymous Apex, or a test:

```apex
if (kern.UTIL_FeatureFlag.isEnabled('MaskingFramework_Enabled'))
{
    // masking is active
}
```

**Catch a blocking failure.** A `BlockDml` rule that cannot redact a value throws an exception you can catch:

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

**Redact an ad-hoc string.** For the occasional case where you need to scrub a string in your own code (not record or framework masking), `kern.UTIL_String`
exposes string helpers such as `maskString` and `abbreviate`. These are general-purpose string utilities, not the masking engine, so use configuration-driven
masking for anything that should be governed by your rule catalogue.

> The right way to mask a field you own is a `MaskingTarget__mdt` plus `ApplyMasking__c`, reviewed in the Advisor, rather than an Apex call. That keeps masking
> declarative, auditable, and visible in the Advisor's coverage view.

---

## Capability Matrix (for Analysts)

If you are evaluating masking rather than configuring it, this table is the at-a-glance answer to "what can it do, and what can it not?". A check mark means the capability is supported; a cross means it is out of scope, with the right alternative noted.

| Capability                                  | Supported | Notes                                                                                 |
|---------------------------------------------|-----------|---------------------------------------------------------------------------------------|
| Redact framework logs / callouts by default | ✅        | Three active rules on four framework objects (the older credit-card rule ships switched off); on out of the box |
| Mask records on an object you own           | ✅        | `MaskingTarget__mdt` + `ApplyMasking__c`; `before insert` / `before update`            |
| Regex / credit-card / JSON-key / literal    | ✅        | Four modes; credit-card adds a Luhn check                                              |
| Fail-open / marker / block-save behaviour   | ✅        | `LogAndContinue` / `WriteFailureMarker` / `BlockDml`                                    |
| Per-field, per-object, per-caller scope     | ✅        | Wildcard or specific field; optional caller-class scope on API call and API issue records |
| No-code review and configuration            | ✅        | Data Masking Advisor (review, assign rules, export)                                    |
| Regulated-field inventory export            | ✅        | CSV / JSON, optional Sensitive-only filter                                             |
| Mask existing stored data                   | ❌        | Write-time only; use a batch scrub for data already saved                              |
| Reversible / decrypt                        | ❌        | One-way redaction; use Shield for encryption-at-rest                                   |
| Mask non-text fields                        | ❌        | Text-shaped fields only                                                                |
| Restrict who can view a field               | ❌        | Use Field-Level Security; masking changes the value, not visibility                    |

---

## Testing

You test masking the way it actually runs: by checking the resulting behaviour, not by calling the engine directly. Here are the patterns to use.

**Assert the flag state** drives a code path:

```apex
@IsTest
static void maskingIsEnabledByDefault()
{
    Assert.isTrue(kern.UTIL_FeatureFlag.isEnabled('MaskingFramework_Enabled'), 'Masking should be enabled by default');
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
        Assert.fail('Expected MaskingBlockedException');
    }
    catch (kern.UTIL_Exceptions.MaskingBlockedException e)
    {
        // expected
    }
    Test.stopTest();
}
```

**Assert the stored value is redacted** after a masked write. Query the field back and assert it no longer contains the sensitive value (and, where applicable,
that it contains the rule's replacement marker). Because masking runs in the `before` window, the redaction is present the moment the record is committed.

> Toggle masking off for a control test by deploying the `MaskingFramework_Enabled` flag off for that scenario, or use an object with no masking
> target as your negative case.

---

## Performance

You can leave masking on without worrying that it will slow your triggers and bulk saves to a crawl. It is built to run inside triggers and bulk DML without becoming the bottleneck, in three ways:

- **Per-transaction caching.** The engine builds each object's masking plan once and reuses it across all the records in a transaction, so a 200-record bulk update
  resolves rules and targets once, not 200 times.
- **Cheap gates first.** A record is only examined when the master flag is on and the object opts in. An input shorter than a rule's `MinInputLength__c` is skipped
  before the more expensive pattern runs.
- **Luhn before replace.** Credit-card masking validates the checksum on each candidate match before redacting, so it does not rewrite numbers that merely look
  card-shaped. The check has a budget: in one value, the first 50 card-shaped numbers are checked, and every card-shaped number after those 50 is hidden without the
  check. A text with that many long numbers is not an ordinary message, so some numbers that are not cards can be hidden there too.
- **Long values are searched in pieces.** A pattern (`Regex`) rule searches a value longer than 131,072 characters in pieces of that length, each piece overlapping
  the one before by 32,768 characters, so one search never takes so many steps that the platform stops the save. A single match longer than 32,768 characters can be
  cut where two pieces meet, and its tail is then left unmasked. No JSON Web Token comes near that length; it matters only for a pattern of your own that can match
  very long text.

**Large and unusual input.** The shipped rules are built so that none of the inputs measured below ends your save, but very large payloads still
have limits (see **Large API responses and memory** below). Masking a value takes CPU time, and a save that runs out of CPU time fails as a
whole, not only its masking, so this matters most for fields that hold what another system sent. Measured on a development org, with each
field filled to its full 131,072 characters (the 2,000-level nest is 12,003), times in your org will differ with its data and setup:

| What the field held | What that looks like in real life | CPU time masking took |
|---|---|---|
| About 7,700 card numbers, one space apart | a payment batch, a card export or a test file pasted into a request | about 140 ms |
| About 6,500 numbers of 19 digits (the longest a card number can be) that pass the card checksum | a list of gift-card or loyalty numbers | about 125 ms |
| One long run of single digits with a space or a hyphen between each | a fixed-width file, a table of quantities or codes: no card in it, but a card number may contain spaces and hyphens, so every digit could be where one starts | about 80 ms (most of the digits are hidden: see **Luhn before replace** above) |
| A JSON list of about 9,000 entries, each holding a value under the key `token` | an API response that lists access tokens or keys | about 500 ms |
| The same list, cut short | a long response stored cut to the length of its field, which is no longer valid JSON | about 150 ms; the whole field is saved as `[MASKING_FAILURE]` |
| JSON nested 2,000 or 21,000 levels deep | rarely real data: a broken payload, or one built to break the receiver | 21 to 41 ms |
| A whole API save with a request, parameters and response each holding one of the inputs above (the worst mix measured) | an integration that sends or receives bulk data | about 990 ms for the save |

A 2 MB request body masks in about 1 to 3 seconds in a synchronous save (one someone waits for), with no secret left in it. Each API call
payload is masked once per save. These figures hold for the rules and patterns the package ships: a pattern of your own, or the older card
rule `MaskCreditCard` if you switch it on, can still end the save on such text. The secret-key rule does not mask a key and its value
written as JSON inside another JSON text value, with each quote escaped as `\"` (for example `{"title":"{\"password\":\"x\"}"}`). This is
true in every field and in the attached file. Card numbers in such text are still masked.

To benchmark your own configuration, run masking under a representative bulk load and watch CPU time. The cost scales with the number of *active targets* and
the size of the text being scanned, not with the size of the rule catalogue (dormant rules cost nothing).

**Large API responses and memory.** Masking a large payload needs room in memory (the platform calls it heap) for the text and its masked copy. Two 2 MB responses
in one synchronous `kern.API_Dispatcher.execute` call reach the platform's 10 MB heap limit for a synchronous transaction. A Queueable job has 25 MB: two such
responses fit, and three reach the limit. If your integrations receive large responses, make fewer calls in each transaction or job, and run them in a Queueable
job rather than while a user waits.

**Seeing the time masking takes.** Masker performance logging is off by default (see the [Logging - Guide](Logging%20-%20Guide.md)). When you switch it on, each
masking run that takes at least your threshold writes one log entry, and the entry's class and method name (`ClassMethod__c`) says what was masked:

- `UTIL_MaskerPerformanceTimer/<object>` (for example `UTIL_MaskerPerformanceTimer/Foobar__c`): masking a batch of records in a trigger.
- `UTIL_MaskerPerformanceTimer/ApiCall__c.<field>` (for example `UTIL_MaskerPerformanceTimer/ApiCall__c.Request__c`): masking an API call payload that is too long
  for its field, once, when it is written to the call.
- `UTIL_MaskerPerformanceTimer/ContentVersion`: the step that builds a call's payload files had to mask a payload again.

---

## Anti-Patterns

These are the common mistakes (the tempting-but-wrong ways to use masking) and what to do instead. Each row names the trap, why it bites, and the right tool for the job.

| Anti-Pattern                                                        | Problem                                                                 | Better Approach                                                            |
|---------------------------------------------------------------------|-------------------------------------------------------------------------|----------------------------------------------------------------------------|
| **Masking to hide a field from a user**                             | Masking changes the stored/emitted value for everyone, not visibility   | Use Field-Level Security or sharing                                        |
| **Expecting masking to scrub existing rows**                        | Masking is write-time; old data is untouched                            | Run a one-time batch scrub, then let masking keep new writes clean         |
| **Masking a number/date/picklist field**                            | Only text-shaped fields are maskable                                    | Store the sensitive value in a text field, or use a different control      |
| **Hand-authoring `MaskingTarget__mdt` XML for many fields**         | Namespace and field-reference mistakes are easy and silent              | Use the Advisor export, which generates correct metadata                     |
| **Treating the Advisor as a compliance monitor**                    | It is a point-in-time review tool, not a background scanner             | Pair it with a monitoring product for ongoing posture                      |
| **Trying to drive masking from Apex instead of configuration**      | Masking is configuration-driven by design, so an Apex call is the wrong tool and bypasses the Advisor's coverage view | Configure `MaskingTarget__mdt` + `ApplyMasking__c`; probe the flag         |

---

## Best Practices

A short checklist to get masking right and keep it that way.

**Do:**

- Let the default framework-path redaction run: keep `MaskingFramework_Enabled` on.
- Use the Advisor to review coverage and export configuration, then deploy the metadata it produces.
- Choose the failure action deliberately. `WriteFailureMarker` is the shipped choice: a failure leaves a visible marker instead of the sensitive value, and the save
  still goes ahead. Choose `BlockDml` when an unmasked value must never be stored and a refused save is the better outcome, and `LogAndContinue` only for a field
  where keeping the original value matters more than a missed redaction.
- Add a `TriggerSetting__mdt` with `ApplyMasking__c` for any business object you mask.
- Test masking through behaviour: the flag probe, the exception, and the stored value.

**Don't:**

- Don't rely on masking for access control or to protect data already stored.
- Don't expect a decrypt path; masking is one-way.
- Don't try to drive masking from Apex; configure it with metadata instead.

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
