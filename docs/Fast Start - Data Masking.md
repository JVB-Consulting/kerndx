---
navOrder: 64
---

# Fast Start - Data Masking

**Framework:** KernDX | **Total time:** ~20 minutes

> Redact card numbers, secrets, and personal data on a record *before it is saved* — configuration, not Apex.

**Before you start:**

- [ ] KernDX package installed in your org
- [ ] Org configured post-install — verify with the **Kern** app's Health Check (see [Installation guide](Installation.md#post-install-configuration))
- [ ] CLI authenticated (`sf org open -o YourOrgAlias` to verify) — or just use the Developer Console
  (Gear Icon > Developer Console) for all Apex work
- [ ] Working in a sandbox or scratch org (not production)

**What you'll build:** You will watch the framework redact a card number and a secret with zero setup, then
configure masking on a field of **your own** object and verify the value is redacted before it is saved.

**Success looks like:** A `Contact` you insert with `Description` = `"Note — SSN 123-45-6789"` reads back as
`"Note — SSN XXX-XX-XXXX"`. The sensitive value never reached the database.

**In one line:** masking is **configuration, not code** — wire a `kern__MaskingTarget__mdt` at a field and the
sensitive value is redacted on `before insert` / `before update`, before it is ever stored.

---

## Table of Contents

<details>
<summary>Expand</summary>

1. [Tier 1: See It Work (~2 minutes)](#tier-1-see-it-work-2-minutes)
    - [Watch a record get redacted on save](#watch-a-record-get-redacted-on-save)
    - [Confirm masking is on](#confirm-masking-is-on)
2. [Tier 2: Mask a Field on Your Own Object (~12 minutes)](#tier-2-mask-a-field-on-your-own-object-12-minutes)
    - [The three gates](#the-three-gates)
    - [Step 1: Put the object on the trigger framework](#step-1-put-the-object-on-the-trigger-framework)
    - [Step 2: Assign a rule and export the configuration](#step-2-assign-a-rule-and-export-the-configuration)
    - [Step 3: Deploy](#step-3-deploy)
    - [Step 4: Verify the redaction](#step-4-verify-the-redaction)
        - [The metadata, by hand](#the-metadata-by-hand)
3. [Tier 3: Production Patterns (~6 minutes)](#tier-3-production-patterns-6-minutes)
    - [Rule modes](#rule-modes)
    - [Failure actions](#failure-actions)
    - [The Data Masking Advisor](#the-data-masking-advisor)
    - [Testing your masking](#testing-your-masking)
4. [What Masking Is Not](#what-masking-is-not)
5. [Common Issues](#common-issues)
6. [What You Now Know](#what-you-now-know)
7. [Next Steps](#next-steps)

</details>

---

## Tier 1: See It Work (~2 minutes)

KernDX ships masking **pre-wired on its own API-audit object**, `ApiCall__c`, so you can watch the before-save
redaction with zero setup. Run this in **Execute Anonymous** (Developer Console or VS Code):

### Watch a record get redacted on save

```apex
kern__ApiCall__c call = new kern__ApiCall__c();
call.kern__ServiceName__c = 'Masking Demo';
call.kern__Direction__c = 'Inbound';
call.kern__Status__c = 'Completed';
call.kern__Request__c = '{"card":"4111111111111111","password":"hunter2"}';
insert call;

kern__ApiCall__c stored = [SELECT kern__Request__c FROM kern__ApiCall__c WHERE Id = :call.Id];
System.debug(stored.kern__Request__c);
```

The debug log shows the **stored** value — already redacted:

```text
{"card":"[CARD_REDACTED]","password":"***SECRET***"}
```

The card number was caught by the `MaskPaymentCard` rule (a Luhn-checked match), the secret under the `password`
key by the `MaskSecretKeys` rule. Both fired on the `before insert` pass, so the readable values never reached the
database.

> **Why `ApiCall__c`?** It is the one object that ships with masking already configured. Your own objects are
> **not** masked until you configure them — that is Tier 2.

### Confirm masking is on

From anywhere — subscriber Apex, anonymous Apex, or a test — check the master switch:

```apex
Boolean maskingOn = kern.UTIL_FeatureFlag.isEnabled('MaskingFramework_Enabled'); // true by default
System.debug('Masking enabled: ' + maskingOn);
```

`MaskingFramework_Enabled` is the framework's kill switch. It defaults **on**; turn it off only for a deliberate,
temporary diagnostic against raw data in a sandbox.

> **When to move to Tier 2:** When you want this same redaction on a field of *your own* object.

---

## Tier 2: Mask a Field on Your Own Object (~12 minutes)

Masking your own data is **configuration, not Apex** — you do not write a masking class. You declare *where* a
rule applies, deploy that metadata, and the framework does the rest. We'll redact Social Security Numbers that end
up in a `Contact.Description` note.

### The three gates

Record-value masking fires for a record only when **all three** hold, and the operation is `before insert` or
`before update`:

1. The `MaskingFramework_Enabled` feature flag is on (it is, by default).
2. The object's `kern__TriggerSetting__mdt` has `kern__ApplyMasking__c` checked.
3. At least one **active** masking target resolves a field on that object.

### Step 1: Put the object on the trigger framework

Masking runs as a step inside the KernDX trigger dispatcher, so the object has to route through it. If you already
use KernDX trigger actions on this object, it is already wired — skip to Step 2. Otherwise add a one-line trigger
(see [Fast Start - Trigger Actions](Fast%20Start%20-%20Trigger%20Actions.md) for the full pattern):

```apex
trigger ContactTrigger on Contact (before insert, before update)
{
	new kern.TRG_Dispatcher().run();
}
```

The object's `kern__TriggerSetting__mdt` with `kern__ApplyMasking__c = true` (Gate 2) is generated for you by the
export in the next step.

### Step 2: Assign a rule and export the configuration

The fastest, drift-free path is the **Data Masking Advisor**. Open it from the **App Launcher** (search "Data
Masking Advisor"):

1. **Pick your object** — `Contact`. The Advisor lists its fields and flags the ones that look sensitive.
2. **Assign a rule** — on the `Description` field, choose a rule such as **Mask SSN** from the dropdown.
3. **Export** — click **Export**. The Advisor bundles everything Gate 2 and Gate 3 need: the active rule, the
   masking target wiring it to `Contact.Description`, and the Trigger Setting with **Apply Masking** on.

The Advisor never writes to your org — it generates correctly-namespaced metadata that *you* deploy. (Prefer it
over hand-authoring; getting the `kern__` prefixes and field references right by hand is fiddly. The shapes it
generates are shown in [The metadata, by hand](#the-metadata-by-hand).)

### Step 3: Deploy

From the unzipped export folder, run the line the Advisor shows you:

```bash
sf project deploy start --metadata-dir metadata -o YourOrgAlias
```

### Step 4: Verify the redaction

Insert a `Contact` whose note carries an SSN, then read it back — in **Execute Anonymous**:

```apex
Contact c = new Contact(LastName = 'Masking Demo', Description = 'Internal note — SSN 123-45-6789');
insert c;

c = [SELECT Description FROM Contact WHERE Id = :c.Id];
System.debug(c.Description);
```

The stored `Description` reads:

```text
Internal note — SSN XXX-XX-XXXX
```

The SSN was redacted on the `before insert` pass — the readable value never reached the database, and every
downstream trigger and the saved row see only the masked text.

#### The metadata, by hand

If you would rather author the metadata yourself, here is the masking target — a `kern__MaskingTarget__mdt` record
wiring the SSN rule to `Contact`. Because the type is the **packaged** `kern__MaskingTarget__mdt`, its field names
carry the `kern__` prefix and the packaged rule is referenced as `kern__MaskSsn`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!-- customMetadata/kern__MaskingTarget.Mask_Contact_Ssn.md-meta.xml -->
<CustomMetadata xmlns="http://soap.sforce.com/2006/04/metadata" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema">
    <label>SSN / Contact</label>
    <protected>false</protected>
    <values>
        <field>kern__CallerClass__c</field>
        <value xsi:nil="true"/>
    </values>
    <values>
        <field>kern__Field__c</field>
        <value xsi:nil="true"/>
    </values>
    <values>
        <field>kern__IsActive__c</field>
        <value xsi:type="xsd:boolean">true</value>
    </values>
    <values>
        <field>kern__Rule__c</field>
        <value xsi:type="xsd:string">kern__MaskSsn</value>
    </values>
    <values>
        <field>kern__SObjectType__c</field>
        <value xsi:type="xsd:string">Contact</value>
    </values>
</CustomMetadata>
```

A blank `kern__Field__c` is an **object-wide wildcard** — the SSN rule scans every text-shaped field on `Contact`
(so the note's SSN is caught wherever it lands). To narrow it to a single field, let the Advisor build the field
reference for you — getting the namespaced field path right by hand is the fiddly part the export removes. Deploy
with:

```bash
sf project deploy start -m "CustomMetadata:kern__MaskingTarget.Mask_Contact_Ssn" -o YourOrgAlias
```

> The target points at a rule that must be **active**. `MaskSsn` ships as a dormant template, so activate it first —
> the Advisor export does this for you, or set `kern__IsActive__c = true` on the rule under
> **Setup → Custom Metadata Types → Masking Rule** (its `kern__IsActive__c` is subscriber-editable).

---

## Tier 3: Production Patterns (~6 minutes)

### Rule modes

A masking rule (`kern__MaskingRule__mdt`) matches in one of four modes. KernDX ships 18 rules — 3 active and 15
dormant templates you activate by wiring a target to them. (Two of the active rules overlap: `kern__MaskPaymentCard`
replaces the original `kern__MaskCreditCard`, which still ships for compatibility.)

| Mode         | What it matches                                                                                      |
|--------------|------------------------------------------------------------------------------------------------------|
| `Regex`      | A regular expression; matched substrings are replaced (the `MaskSsn` rule above is a Regex rule).     |
| `CreditCard` | A regex **plus** a Luhn (mod-10) check — so a 16-digit order number survives.                        |
| `JsonKey`    | Treats the value as JSON and redacts the value under each matching **key**, recursing nested objects.|
| `ExactMatch` | A literal substring (no regex metacharacters). No shipped rule uses this mode — it is there for custom rules. |

### Failure actions

Each rule's failure action decides what happens if it errors while masking a value:

| Action               | Behaviour                                                                                      |
|----------------------|------------------------------------------------------------------------------------------------|
| `LogAndContinue`     | Logs a warning and keeps the original value.                                                    |
| `WriteFailureMarker` | Replaces the field with `[MASKING_FAILURE]`, so a failed redaction can never leak the value.   |
| `BlockDml`           | Throws `kern.UTIL_Exceptions.MaskingBlockedException`, aborting the save.                       |

### The Data Masking Advisor

Beyond assigning rules, the Advisor is a standing review console:

- **Scan custom objects** for likely-sensitive fields that have no masking — on demand, a few objects at a time.
- **Export a regulated-field inventory** — a CSV or JSON census of fields that hold (or likely hold) regulated
  data, each marked whether it is masked today, with an optional **Sensitive fields only** filter.
- **Read the two Health Check cards** — **Masking configuration** (flags targets pointing at an inactive or
  missing rule) and **Masking coverage (custom objects)** — both deep-link back into the Advisor.

It is a point-in-time review tool, not continuous monitoring — it analyses when you open it or press a button.

### Testing your masking

In an `@IsTest` class you cannot deploy a `kern__MaskingTarget__mdt` (no Metadata API in tests), but you **can**
inject one as a mock. `kern.TST_Mock` is the supported, global seam:

```apex
kern.TST_Mock.register(
	kern__MaskingTarget__mdt.SObjectType,
	new List<kern__MaskingTarget__mdt>{ /* your mock target + rule */ }
);
```

This lets a test exercise a rule against one of the **framework's own objects** (`ApiCall__c`, `LogEntryEvent__e`,
and the like), which already ship with a trigger and a Trigger Setting — insert the record and the mocked target
fires. It does **not** unlock *your own* object: a mock target satisfies one gate, but the masking pass also needs
the object to have a real trigger and a Trigger Setting, and neither can be conjured in a test. So for masking on
your own object the trustworthy proof is the **deploy-and-verify of Step 4 against a sandbox** — treat that as the
gate before you promote the configuration.

---

## What Masking Is Not

Knowing the boundaries keeps you from reaching for masking where a different control belongs:

- **It is write-time, not retroactive.** Masking redacts records as they are inserted or updated — it does not
  scan or rewrite rows already stored. To clean up existing data, re-save it through a one-off batch.
- **It is one-way.** The redacted value overwrites the original; there is no key and no decrypt path. Use
  [Shield Platform Encryption](Security%20-%20Guide.md#data-masking) when you need the value back.
- **It is not access control.** A masked field is still visible to anyone with field-level security to read it —
  masking changes the stored *value*, not *who can see it*. Use Field-Level Security and sharing for that.
- **It covers text-shaped fields only** — Text, Text Area, Long Text Area, URL, Email, Phone, and Encrypted Text.
  Numbers, dates, checkboxes, picklists, and lookups cannot be masked.

---

## Common Issues

| Problem                                              | Cause                                                                      | Fix                                                                                                                  |
|------------------------------------------------------|----------------------------------------------------------------------------|--------------------------------------------------------------------------------------------------------------------|
| My object's values are not masked                    | The object has no KernDX trigger, or no `kern__TriggerSetting__mdt`         | Add the one-line trigger (Gate 1) and a Trigger Setting with `kern__ApplyMasking__c = true` (the Advisor export bundles one) |
| A target is active but masks nothing                 | Its rule is inactive or missing                                            | Activate the rule (`kern__MaskingRule__mdt.kern__IsActive__c = true`) — or check the **Masking configuration** Health Check card |
| A card-shaped number is not redacted                 | It failed the Luhn check, or was shorter than the rule's `MinInputLength__c` | Confirm it is a real card number; `MaskPaymentCard` deliberately skips non-Luhn digit runs and inputs with fewer than 13 characters |
| `Variable does not exist: kern__MaskingTarget__mdt`  | Missing namespace prefix in a subscriber org                               | Use the `kern__` prefix on the type, its fields, and any packaged rule reference                                    |
| Existing rows still show raw values                  | Masking is write-time, not retroactive                                     | Re-save the records (a one-off batch) so they pass back through the masking pass                                    |
| A `BlockDml` rule aborts an insert                   | The rule could not redact a value and is configured to block               | This is by design — fix the data or change the rule's failure action; catch `kern.UTIL_Exceptions.MaskingBlockedException` |

---

## What You Now Know

| Concept                                                       | What it does                                                              |
|---------------------------------------------------------------|---------------------------------------------------------------------------|
| `kern.UTIL_FeatureFlag.isEnabled('MaskingFramework_Enabled')` | The supported, global probe for masking state                             |
| `before insert` / `before update` masking pass                | Redacts text-shaped fields on the record before it is written             |
| `kern__MaskingRule__mdt`                                      | A reusable redaction recipe — pattern, replacement, mode, failure action  |
| `kern__MaskingTarget__mdt`                                    | Wires a rule to an object (and optionally a field and caller)             |
| `kern__TriggerSetting__mdt.kern__ApplyMasking__c`             | The per-object switch that opts an object into masking                    |
| Data Masking Advisor                                          | No-code review and a deployable export — never writes to your org         |
| `kern.TST_Mock`                                               | The global seam for injecting a mock masking target in a test             |

**Key patterns:**

- Mask your own object with a `kern__MaskingTarget__mdt` plus `kern__ApplyMasking__c` — configuration, not Apex.
- Use the Data Masking Advisor to review coverage and export correctly-namespaced metadata.
- Verify masking by deploying to a sandbox and reading the stored value back — the masking pass needs a real
  trigger, so a sandbox is the trustworthy proof.
- Choose the failure action deliberately — `BlockDml` for values that must never persist unmasked.

---

## Next Steps

| Topic                                        | Link                                                                     |
|----------------------------------------------|--------------------------------------------------------------------------|
| Data Masking Developer Guide                 | [Data Masking - Guide](Data%20Masking%20-%20Guide.md)                    |
| Masking in the broader security picture      | [Security - Guide](Security%20-%20Guide.md#data-masking)                 |
| `ApplyMasking__c` and the trigger framework  | [Triggers - Guide](Triggers%20-%20Guide.md)                              |
| Put an object on the trigger framework       | [Fast Start - Trigger Actions](Fast%20Start%20-%20Trigger%20Actions.md)  |
| A worked masking example on outbound callouts | [Web Services - Guide](Web%20Services%20-%20Guide.md)                    |
| The Data Masking Advisor component family    | [LWC - Guide](LWC%20-%20Guide.md)                                        |
| `MaskingRule__mdt` and `MaskingTarget__mdt` schema | [Objects & Metadata - Guide](Objects%20%26%20Metadata%20-%20Guide.md) |
