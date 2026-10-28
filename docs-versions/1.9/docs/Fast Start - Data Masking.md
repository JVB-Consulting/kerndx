---
navOrder: 64
---

# Fast Start - Data Masking

**Framework:** KernDX | **Total time:** ~20 minutes

**What this is:** A way to redact card numbers, secrets, and personal data on a record *before it is ever saved*, using configuration records instead of Apex code. **Why it matters:** Sensitive values that slip into a free-text note or an integration payload are a compliance and breach risk; here the readable value never reaches the database. **Who should follow it:** developers and admins protecting regulated data, and tech leads who want data-protection rules that are version-controlled and reviewable. **When to use it:** any time a field could capture data you don't want stored in the clear.

> **Namespaces in code samples:** `kern.` on a class and `kern__` on an object, field, or metadata type mark the managed package's namespace.
> On the managed package, framework references need those prefixes even where a sample omits them; repackaged under your own namespace, replace `kern`/`kern__`
> with your prefix; on an unmanaged deploy, drop them. See [How to read the code samples](Installation.md#how-to-read-the-code-samples).

**What you'll build:** You will watch the framework redact a card number and a secret with zero setup, then
configure masking on a field of **your own** object and verify the value is redacted before it is saved.

**Success looks like:** A `Contact` you insert with `Description` = `"Note — SSN 123-45-6789"` reads back as
`"Note — SSN XXX-XX-XXXX"`. The sensitive value never reached the database.

**In one line:** masking is **configuration, not code**. Wire a `kern__MaskingTarget__mdt` at a field and the
sensitive value is redacted on `before insert` / `before update`, before it is ever stored.

## Before you start

Open your terminal in your project's top folder, the one that holds `sfdx-project.json`; on Windows that terminal is
Command Prompt. Run the four-line check on [Set Up Your Computer](Set%20Up%20Your%20Computer.md#check-you-are-ready)
once: it proves your terminal, the CLI, your login and the KernDX package, and answers what goes wrong. Done that
today? Carry on. Work in a sandbox or a scratch org, never production. Every command below writes `YourOrgAlias`
where your org's alias goes: the name you gave it when you logged in.

---

## Table of Contents

<details>
<summary>Expand</summary>

1. [Before you start](#before-you-start)
2. [Tier 1: See It Work (~2 minutes)](#tier-1-see-it-work-2-minutes)
    - [Watch a record get redacted on save](#watch-a-record-get-redacted-on-save)
    - [Confirm masking is on](#confirm-masking-is-on)
3. [Tier 2: Mask a Field on Your Own Object (~12 minutes)](#tier-2-mask-a-field-on-your-own-object-12-minutes)
    - [The three gates](#the-three-gates)
    - [Step 1: Put the object on the trigger framework](#step-1-put-the-object-on-the-trigger-framework)
    - [Step 2: Assign a rule and export the configuration](#step-2-assign-a-rule-and-export-the-configuration)
    - [Step 3: Deploy](#step-3-deploy)
    - [Step 4: Verify the redaction](#step-4-verify-the-redaction)
4. [Tier 3: Production Patterns (~6 minutes)](#tier-3-production-patterns-6-minutes)
    - [Rule modes](#rule-modes)
    - [Failure actions](#failure-actions)
    - [The Data Masking Advisor](#the-data-masking-advisor)
    - [Testing your masking](#testing-your-masking)
    - [Clean up](#clean-up)
5. [Common Issues](#common-issues)
    - [Tier 1: See It Work](#tier-1-see-it-work)
    - [Step 1: Put the object on the trigger framework](#step-1-put-the-object-on-the-trigger-framework-1)
    - [Step 3: Deploy](#step-3-deploy-1)
    - [Step 4: Verify the redaction](#step-4-verify-the-redaction-1)
    - [Tier 3: Production Patterns](#tier-3-production-patterns)
6. [What Masking Is Not](#what-masking-is-not)
7. [What You Now Know](#what-you-now-know)
8. [Next Steps](#next-steps)

</details>

---

## Tier 1: See It Work (~2 minutes)

You can see masking work before you configure anything. KernDX already has it switched on for one of its own
records, the API-audit object `ApiCall__c`, so the redaction happens with no setup from you.

### Watch a record get redacted on save

**In Salesforce**, open the Developer Console (the gear icon, then Developer Console), then Debug, then Open Execute
Anonymous Window, and run:

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

You should see this line in the log: the **stored** value, already redacted. (The framework re-serialises the JSON,
so the keys come back in a different order. Only the redacted values matter.)

```text
{"password":"***SECRET***","card":"[CARD_REDACTED]"}
```

The card number was caught by the `MaskPaymentCard` rule (a Luhn-checked match). The secret under the `password`
key was caught by the `MaskSecretKeys` rule. Both fired on the `before insert` pass, so the readable values never
reached the database.

> **Why `ApiCall__c`?** It is the one object that ships with masking already configured. Your own objects are
> **not** masked until you configure them, which is Tier 2.

### Confirm masking is on

You can check the master switch from anywhere: subscriber Apex, anonymous Apex, or a test.

**In Salesforce**, in the same Execute Anonymous window, run:

```apex
Boolean maskingOn = kern.UTIL_FeatureFlag.isEnabled('MaskingFramework_Enabled'); // true by default
System.debug('Masking enabled: ' + maskingOn);
```

You should see `Masking enabled: true` in the log.

`MaskingFramework_Enabled` is the framework's kill-switch: a master off-switch you can flip in an incident without
a deployment. It defaults **on**. Turn it off only for a deliberate, temporary diagnostic against raw data in a
sandbox.

Something went wrong? See [Common Issues, Tier 1](#tier-1-see-it-work).

> **When to move to Tier 2:** When you want this same redaction on a field of *your own* object.

---

## Tier 2: Mask a Field on Your Own Object (~12 minutes)

Masking your own data is **configuration, not Apex**: you do not write a masking class. You declare *where* a
rule applies, deploy that metadata, and the framework does the rest. To make it concrete, we'll redact Social
Security Numbers that end up in a `Contact.Description` note.

### The three gates

Masking fires for a record only when **all three** of these conditions hold, and the operation is `before insert`
or `before update`:

1. The `MaskingFramework_Enabled` feature flag is on (it is, by default).
2. The object's `kern__TriggerSetting__mdt` has `kern__ApplyMasking__c` checked.
3. At least one **active** masking target resolves a field on that object.

### Step 1: Put the object on the trigger framework

Masking runs as a step inside the KernDX trigger dispatcher, so the object has to route through it, and the object's
trigger setting switches masking on (Gate 2). If you already use KernDX trigger actions on this object, the trigger
is already wired: skip to Step 1.2.

#### Step 1.1: Add the trigger

Add a one-line trigger file that hands control to the framework (see
[Fast Start - Trigger Actions](Fast%20Start%20-%20Trigger%20Actions.md) for the full pattern). You create it with one
command, replace what the command wrote, then send it to your org.

**1. In the terminal**, from your project's top folder, create the trigger:

```shell
sf apex generate trigger --name ContactTrigger --sobject Contact --event "before insert" --output-dir force-app/main/default/triggers
```

You should see two files created in `force-app/main/default/triggers`: `ContactTrigger.trigger` and its companion of
the same name ending in `.trigger-meta.xml`.

**2. In your editor**, open this file, delete what is there (the command writes an empty trigger), paste the code
below in, and save:

```text
force-app/main/default/triggers/ContactTrigger.trigger
```

```apex
trigger ContactTrigger on Contact (before insert, before update)
{
	new kern.TRG_Dispatcher().run();
}
```

**3. In the terminal**, send the trigger to your org:

```shell
sf project deploy start -o YourOrgAlias -m "ApexTrigger:ContactTrigger"
```

You should see `Status: Succeeded`, with `ContactTrigger` listed as created.

Something went wrong? See [Common Issues, Step 1](#step-1-put-the-object-on-the-trigger-framework-1).

#### Step 1.2: Create the trigger setting

The trigger setting with **Apply Masking** checked is Gate 2. The Advisor's export in Step 2 does not include this
record, so make it whichever path you take.

If you skipped Step 1.1 because the object is already on the trigger framework, it already has a trigger setting: do
not create a second one. Open that existing record instead, confirm **Apply Masking** is checked (it is by default),
and pull it with the command below, putting its **Trigger Setting Name** in place of `Contact`.

**1. In Salesforce**, open Setup, then Custom Metadata Types, then **Trigger Setting**, then **Manage Trigger
Settings**, then **New**, and save a record with these values:

| Field                | API name                   | Value     |
|----------------------|----------------------------|-----------|
| Label                | `MasterLabel`              | `Contact` |
| Trigger Setting Name | `DeveloperName`            | `Contact` |
| SObject Type         | `kern__SObjectType__c`     | `Contact` |
| Apply Masking        | `kern__ApplyMasking__c`    | checked   |
| Bypass Execution     | `kern__BypassExecution__c` | unchecked |

**2. In the terminal**, pull the record into your project:

```shell
sf project retrieve start -o YourOrgAlias -m "CustomMetadata:kern__TriggerSetting.Contact"
```

You should see one file created under `force-app/main/default/customMetadata`, named after the record.

Something went wrong? See [Common Issues, Step 1](#step-1-put-the-object-on-the-trigger-framework-1).

### Step 2: Assign a rule and export the configuration

The fastest path, and the one least likely to introduce mistakes, is the **Data Masking Advisor**.

**In Salesforce**, open it from the **App Launcher** (search "Data Masking Advisor"):

1. **Pick your object:** `Contact`. The Advisor lists its fields and flags the ones that look sensitive.
2. **Assign a rule:** on the `Description` field, choose a rule such as **Mask US Social Security Numbers** from the
   dropdown.
3. **Export:** click **Export**. The Advisor bundles what Gate 3 needs: the masking target wiring the rule to
   `Contact.Description`, and a file that activates the rule if it is a dormant template. It does not include the
   Trigger Setting (Gate 2): that is the record you made in Step 1.2.

The Advisor never writes to your org. Instead it generates correctly-namespaced metadata that *you* deploy.
Prefer it over hand-authoring, because getting the `kern__` prefixes and field references right by hand is fiddly.
([Step 3.1](#step-31-the-two-records-by-hand) shows the masking target it bundles, made by hand instead.)

### Step 3: Deploy

**In the terminal**, from the unzipped export folder, run the line the Advisor shows you:

```shell
sf project deploy start --metadata-dir metadata -o YourOrgAlias
```

You should see the deploy succeed and list the masking records from the export.

Something went wrong? See [Common Issues, Step 3](#step-3-deploy-1).

#### Step 3.1: The two records by hand

If you would rather make the configuration yourself instead of deploying the export, the by-hand path needs **two**
records: the **Trigger Setting** you made in [Step 1.2](#step-12-create-the-trigger-setting), which turns masking on
for the object (Gate 2), and the **masking target** the Advisor would otherwise bundle, which wires a rule to the
field (Gate 3). Make the masking target now: a `kern__MaskingTarget__mdt` record wiring the SSN rule to `Contact`.
Because the type is the **packaged** `kern__MaskingTarget__mdt`, its field names carry the `kern__` prefix and the
packaged rule is referenced as `kern__MaskSsn`.

**1. In Salesforce**, open Setup, then Custom Metadata Types, then **Masking Target**, then **Manage Masking
Targets**, then **New**, and save a record with these values:

| Field               | API name               | Value                                                               |
|---------------------|------------------------|---------------------------------------------------------------------|
| Label               | `MasterLabel`          | `SSN / Contact`                                                     |
| Masking Target Name | `DeveloperName`        | `Mask_Contact_Ssn`                                                  |
| Rule                | `kern__Rule__c`        | `Mask US Social Security Numbers` (the packaged `kern__MaskSsn`)    |
| SObject Type        | `kern__SObjectType__c` | `Contact`                                                           |
| Active              | `kern__IsActive__c`    | checked                                                             |
| Field               | `kern__Field__c`       | left blank                                                          |
| Caller Class        | `kern__CallerClass__c` | left blank                                                          |

**2. In the terminal**, pull the record into your project:

```shell
sf project retrieve start -o YourOrgAlias -m "CustomMetadata:kern__MaskingTarget.Mask_Contact_Ssn"
```

You should see one file created under `force-app/main/default/customMetadata`, named after the record.

A blank `kern__Field__c` is an **object-wide wildcard**: the SSN rule scans every text field on `Contact` (Text, Text Area, Long Text
Area, URL, Email, Phone and Encrypted Text), whoever saves the record, so the note's SSN is caught wherever it lands in ordinary text.
A unique field or an external id is never touched by a wildcard, because rewriting a key breaks it, and neither is a formula, roll-up
summary or auto-number field, because the platform works out those values and there is nothing to rewrite. If you do want a rule on
a key field, name that field explicitly in `kern__Field__c`: an explicit target is treated as your deliberate choice
and is honoured. To narrow the target to a single field, let the Advisor build the field reference for you, because
getting the namespaced field path right by hand is the fiddly part the export removes.

> **Activating the packaged `MaskSsn` rule.** The target points at a rule that must be **active**, and `MaskSsn`
> ships as a dormant template. **Active** (`kern__IsActive__c`) is a field your org controls on a packaged rule, so a
> deploy that carries only the **Active** value activates it: that is what the **Data Masking Advisor** export's
> activation file does. By hand, open Setup, then Custom Metadata Types, then **Masking Rule**, then **Manage Masking
> Rules**, then **Mask US Social Security Numbers** (the `MaskSsn` record), then **Edit**; check **Active** and save.

Something went wrong? See [Common Issues, Step 3](#step-3-deploy-1).

### Step 4: Verify the redaction

Insert a `Contact` whose note carries an SSN, then read it back.

**In Salesforce**, open the Developer Console's Execute Anonymous window, as in Tier 1, and run:

```apex
Contact c = new Contact(LastName = 'Masking Demo', Description = 'Internal note — SSN 123-45-6789');
insert c;

c = [SELECT Description FROM Contact WHERE Id = :c.Id];
System.debug(c.Description);
```

You should see this line in the log, the stored `Description`:

```text
Internal note — SSN XXX-XX-XXXX
```

The SSN was redacted on the `before insert` pass. The readable value never reached the database, and every
downstream trigger and the saved row see only the masked text.

Something went wrong? See [Common Issues, Step 4](#step-4-verify-the-redaction-1).

---

## Tier 3: Production Patterns (~6 minutes)

### Rule modes

A masking rule (`kern__MaskingRule__mdt`) matches in one of four modes. KernDX ships 18 rules: 3 active, and 15
dormant ones you activate by wiring a target to them. (One dormant rule is the original `kern__MaskCreditCard`, which
`kern__MaskPaymentCard` replaces. It ships switched off with its four targets; switch all five on or off together.)

| Mode         | What it matches                                                                                      |
|--------------|------------------------------------------------------------------------------------------------------|
| `Regex`      | A regular expression; matched substrings are replaced (the `MaskSsn` rule above is a Regex rule).     |
| `CreditCard` | A regex **plus** a Luhn (mod-10) check, so a 16-digit order number survives.                         |
| `JsonKey`    | Treats the value as JSON and redacts the value under each matching **key**, recursing nested objects.|
| `ExactMatch` | A literal substring (no regex metacharacters). No shipped rule uses this mode; it is there for custom rules. |

### Failure actions

Each rule's failure action decides what happens if it errors while masking a value:

| Action               | Behaviour                                                                                      |
|----------------------|------------------------------------------------------------------------------------------------|
| `LogAndContinue`     | Logs a warning and keeps the original value. The rule is skipped for the rest of the transaction, so later values it covers stay unmasked too. |
| `WriteFailureMarker` | Saves `[MASKING_FAILURE]` in place of the value it failed on, and keeps masking every other value. The default for a rule you create. |
| `BlockDml`           | Throws `kern.UTIL_Exceptions.MaskingBlockedException`, so the record save fails. On the framework's own log entries and call files, it drops what it could not mask. |

### The Data Masking Advisor

Beyond assigning rules, the Advisor is a standing review console:

- **Scan custom objects** for likely-sensitive fields that have no masking, on demand, a few objects at a time.
- **Export a regulated-field inventory:** a CSV or JSON census of fields that hold (or likely hold) regulated
  data, each marked whether it is masked today, with an optional **Sensitive fields only** filter.
- **Read the two Health Check cards.** **Masking configuration** flags targets pointing at an inactive or
  missing rule, and **Masking coverage (custom objects)** shows where masking is absent. Both deep-link back
  into the Advisor.

It is a point-in-time review tool, not continuous monitoring: it analyses when you open it or press a button.

### Testing your masking

In an `@IsTest` class you cannot deploy a `kern__MaskingTarget__mdt` (there is no Metadata API in tests), but you
**can** inject one as a mock. `kern.TST_Mock` is the supported, global way to do this.

**In your editor**, in a test class:

```apex
kern.TST_Mock.register(
	kern__MaskingTarget__mdt.SObjectType,
	new List<kern__MaskingTarget__mdt>{ /* your mock target + rule */ }
);
```

This lets a test exercise a rule against one of the **framework's own objects** (`ApiCall__c`, `LogEntryEvent__e`,
and the like), which already ship with a trigger and a Trigger Setting: insert the record and the mocked target
fires. It does **not** unlock *your own* object. A mock target satisfies one gate, but the masking pass also needs
the object to have a real trigger and a Trigger Setting, and neither can be conjured in a test. So for masking on
your own object the trustworthy proof is the **deploy-and-verify of Step 4 against a sandbox**. Treat that as the
gate before you promote the configuration.

### Clean up

If you built this example only to try the framework, run these two commands when you have finished the guide. If
`Contact` was already on the trigger framework before this guide, leave its trigger out of the first command and
skip the second, so you keep its trigger and trigger setting. If you deployed the Advisor's export instead of making
the masking target in Step 3.1, the export named the target itself: leave `Mask_Contact_Ssn` out of the first
command and delete that target in Setup instead (its name starts with `Mask_Contact_`). Some things the commands do
not delete: the `Masking Demo` contact from Step 4 and the `Masking Demo` API call record from Tier 1 (delete them in
the app, or leave them), and the `MaskSsn` rule's **Active** box (clear it in Setup if you activated the rule only for
this guide).

**1. In the terminal**, delete the trigger and the masking target:

```shell
sf project delete source -o YourOrgAlias -m "ApexTrigger:ContactTrigger" -m "CustomMetadata:kern__MaskingTarget.Mask_Contact_Ssn" --no-prompt
```

You should see `Status: Succeeded`, then a `Deleted Source` table listing the trigger and the masking target.

**2. In the terminal**, delete the trigger setting:

```shell
sf project delete source -o YourOrgAlias -m "CustomMetadata:kern__TriggerSetting.Contact" --no-prompt
```

You should see `Status: Succeeded`, then a `Deleted Source` table listing the trigger setting.

The commands delete the files from your project too.

Something went wrong? See [Common Issues](#common-issues).

---

## Common Issues

Trouble with your computer rather than this guide (`sf` is not recognised, scripts are disabled, you are not logged
in, the wrong folder)? Those are answered once, in
[Set Up Your Computer](Set%20Up%20Your%20Computer.md#if-something-went-wrong).

### Tier 1: See It Work

#### A card-shaped number is not redacted

It failed the Luhn check, or was shorter than the rule's `kern__MinInputLength__c`. Confirm it is a real card number:
`MaskPaymentCard` deliberately skips digit runs that fail the Luhn check and inputs with fewer than 13 characters.

### Step 1: Put the object on the trigger framework

#### The trigger's deploy fails

The trigger's deploy fails for the same reasons as a class's deploy in the Trigger Actions guide: the command ran
outside your project's top folder, or the org does not have KernDX installed. See
[its Common Issues, Step 1](Fast%20Start%20-%20Trigger%20Actions.md#step-1-create-the-trigger-action-1).

#### The pull creates no file

The record's name in Setup does not match the name in the command. The command asks for `Contact`; check the
**Trigger Setting Name** on the record, fix it, and pull again.

### Step 3: Deploy

#### The export's deploy fails

Run the command from the unzipped export folder, the one that holds the `metadata` folder: the command names that
folder, so it finds nothing from anywhere else. If the deploy reports a component failure instead, its table names
the record that failed and why. You can also make the records by hand, as Step 3.1 shows.

#### The Masking Target form will not save

The form needs **Rule** and **SObject Type** before it saves. Fill in every value in the Step 3.1 table, then save
again.

#### The Masking Target pull creates no file

The record's name in Setup does not match the name in the command. The command asks for `Mask_Contact_Ssn`; check
the **Masking Target Name** on the record, fix it, and pull again.

### Step 4: Verify the redaction

#### The `Description` comes back unmasked

One of the three gates is not met. Check them in order:

- The object has no KernDX trigger, or its trigger setting does not have **Apply Masking**
  (`kern__ApplyMasking__c`) checked. Add the one-line trigger and the trigger setting as in Step 1.
- The target is active but its rule is inactive or missing. Activate the rule (**Active**,
  `kern__MaskingRule__mdt.kern__IsActive__c`, as the note in Step 3.1 shows), or check the **Masking
  configuration** Health Check card.
- Masking is switched off: run the Tier 1 check, which should show `Masking enabled: true`.

#### Existing rows still show raw values

Masking is write-time, not retroactive. Re-save the records (a one-off batch) so they pass back through the masking
pass.

### Tier 3: Production Patterns

#### `Variable does not exist: MaskingTarget__mdt`

Your Apex names the packaged type without its namespace prefix. Use the `kern__` prefix on the type, its fields, and
any packaged rule reference.

#### A `BlockDml` rule stops an insert

The rule could not redact a value and is set to block the save. This is by design: fix the data or change the rule's
failure action, and catch `kern.UTIL_Exceptions.MaskingBlockedException`.

Still stuck? [Tell us](https://github.com/JVB-Consulting/kerndx/issues/new?template=bug_report.md&title=%5Bdocs%5D%20Data%20Masking) which step and what you saw.

## What Masking Is Not

Knowing the boundaries keeps you from using masking where a different control belongs:

- **It is write-time, not retroactive.** Masking redacts records as they are inserted or updated. It does not
  scan or rewrite rows already stored. To clean up existing data, re-save it through a one-off batch.
- **It is one-way.** The redacted value overwrites the original; there is no key and no decrypt path. Use
  [Shield Platform Encryption](Security%20-%20Guide.md#data-masking) when you need the value back.
- **It is not access control.** A masked field is still visible to anyone with field-level security to read it.
  Masking changes the stored *value*, not *who can see it*. Use Field-Level Security and sharing for that.
- **It covers text-shaped fields only:** Text, Text Area, Long Text Area, URL, Email, Phone, and Encrypted Text.
  Numbers, dates, checkboxes, picklists, and lookups cannot be masked.

---

## What You Now Know

| Concept                                                       | What it does                                                              |
|---------------------------------------------------------------|---------------------------------------------------------------------------|
| `kern.UTIL_FeatureFlag.isEnabled('MaskingFramework_Enabled')` | The supported, global way to check whether masking is switched on         |
| `before insert` / `before update` masking pass                | Redacts text-shaped fields on the record before it is written             |
| `kern__MaskingRule__mdt`                                      | A reusable redaction recipe: pattern, replacement, mode, failure action   |
| `kern__MaskingTarget__mdt`                                    | Wires a rule to an object (and optionally a field and caller)             |
| `kern__TriggerSetting__mdt.kern__ApplyMasking__c`             | The per-object switch that opts an object into masking                    |
| Data Masking Advisor                                          | No-code review and a deployable export; never writes to your org          |
| `kern.TST_Mock`                                               | The global way to inject a mock masking target in a test                  |

**Key patterns:**

- Mask your own object with a `kern__MaskingTarget__mdt` plus `kern__ApplyMasking__c`: configuration, not Apex.
- Use the Data Masking Advisor to review coverage and export correctly-namespaced metadata.
- Verify masking by deploying to a sandbox and reading the stored value back. The masking pass needs a real
  trigger, so a sandbox is the trustworthy proof.
- Choose the failure action deliberately: use `BlockDml` for values that must never persist unmasked.

---

## Next Steps

- [Data Masking Developer Guide](Data%20Masking%20-%20Guide.md)
- [Masking in the broader security picture](Security%20-%20Guide.md#data-masking)
- [`ApplyMasking__c` and the trigger framework](Triggers%20-%20Guide.md)
- [Put an object on the trigger framework](Fast%20Start%20-%20Trigger%20Actions.md)
- [A worked masking example on outbound callouts](Web%20Services%20-%20Guide.md)
- [The Data Masking Advisor component family](LWC%20-%20Guide.md)
- [`MaskingRule__mdt` and `MaskingTarget__mdt` schema](Objects%20%26%20Metadata%20-%20Guide.md)
