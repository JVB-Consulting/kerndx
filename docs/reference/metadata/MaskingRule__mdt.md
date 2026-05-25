---
title: "MaskingRule__mdt"
type: sobject
description: "Defines a rule for masking sensitive data in a field — what to look for and what to replace it with. Each rule has a pattern (regex, JSON keys, literal string, or DTO field paths), a replacement value"
category: metadata
---

# MaskingRule__mdt

**Sobject**

```apex
global class MaskingRule__mdt extends SObject
```

**Extends:** [SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm)

Defines a rule for masking sensitive data in a field — what to look for and what to replace it with. Each rule has a pattern (regex, JSON keys, literal string, or DTO field paths), a replacement value, and a category. Pair a rule with one or more Masking Target records to apply it to specific fields on specific objects.

---

## Fields

| Field | Description |
|-------|-------------|
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [ApplicableFieldTypes__c](#applicablefieldtypes__c) | Optional semicolon-delimited list of field types this rule applies to. |
| global [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) [CaseSensitive__c](#casesensitive__c) | When checked, the Pattern matches only exact case. |
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [Description__c](#description__c) | Plain-language explanation of what this rule detects and why it exists. |
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [FailureAction__c](#failureaction__c) | What to do if applying this rule throws an error at runtime (for example, a bad regex or an unparseable JSON payload). |
| global [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) [IsActive__c](#isactive__c) | Controls whether this rule runs. |
| global [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm) [MaskingTargets__r](#maskingtargets__r) | Reciprocal relationship for MaskingTarget__mdt.Rule__c. |
| global [Decimal](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_decimal.htm) [MinInputLength__c](#mininputlength__c) | Optional minimum field-value length before this rule is evaluated. |
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [Mode__c](#mode__c) | How the Pattern is interpreted. |
| global [Decimal](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_decimal.htm) [Order__c](#order__c) | Execution sequence when multiple rules apply to the same field. |
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [Pattern__c](#pattern__c) | What to look for. |
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [Replacement__c](#replacement__c) | What to replace matched content with. |

---

## Field Details

### ApplicableFieldTypes__c

```apex
global String ApplicableFieldTypes__c
```

Optional semicolon-delimited list of field types this rule applies to. Blank = every text-shaped field on the target object. Allowed values (case-insensitive): STRING (short text), TEXTAREA (long / rich text), URL, EMAIL, PHONE, ENCRYPTEDSTRING. Use this to narrow a rule to the field types where the pattern can match — e.g. MaskCreditCard is scoped STRING;TEXTAREA;ENCRYPTEDSTRING because URL / EMAIL / PHONE grammars cannot hold a card number. Narrowing reduces commit cost and eliminates false positives. Overrides explicit target wiring: if a MaskingTarget__mdt wires this rule to a specific Field__c whose DisplayType is excluded here, the rule will NOT fire — the framework emits a one-time warn log to surface the misconfiguration. Widen this list or remove the target if the wiring is intentional. Example: STRING;TEXTAREA;ENCRYPTEDSTRING.

**Field Attributes:**

| Attribute | Value |
|-----------|-------|
| Data Type | Text(255) |
| Required | false |
| Unique | false |
| External ID | false |

### CaseSensitive__c

```apex
global Boolean CaseSensitive__c
```

When checked, the Pattern matches only exact case. When unchecked, matching is case-insensitive. Ignored in Exact Match mode — Exact Match always matches the exact case of the Pattern.

**Field Attributes:**

| Attribute | Value |
|-----------|-------|
| Data Type | Checkbox |
| Default Value | false |

### Description__c

```apex
global String Description__c
```

Plain-language explanation of what this rule detects and why it exists. Required for all rules so future admins can understand each rule at a glance.

**Field Attributes:**

| Attribute | Value |
|-----------|-------|
| Data Type | Text Area |
| Required | false |

### FailureAction__c

```apex
global String FailureAction__c
```

What to do if applying this rule throws an error at runtime (for example, a bad regex or an unparseable JSON payload). Log and Continue keeps the original value and records the failure. Write Failure Marker replaces the entire field value with a sentinel marker so the original is never persisted. Block DML refuses the save and surfaces an error to the caller.

**Field Attributes:**

| Attribute | Value |
|-----------|-------|
| Data Type | Picklist |
| Required | true |

**Picklist Values:**

| API Name | Label | Active |
|----------|-------|--------|
| `LogAndContinue` | Log and Continue | Yes |
| `WriteFailureMarker` | Write Failure Marker | No |
| `BlockDml` | Block DML | No |

### IsActive__c

```apex
global Boolean IsActive__c
```

Controls whether this rule runs. Uncheck to temporarily disable a rule without deleting it or removing its Masking Target records.

**Field Attributes:**

| Attribute | Value |
|-----------|-------|
| Data Type | Checkbox |
| Default Value | true |

### MaskingTargets__r

```apex
global List<MaskingTarget__mdt> MaskingTargets__r
```

Reciprocal relationship for **`MaskingTarget__mdt.Rule__c`** .

### MinInputLength__c

```apex
global Decimal MinInputLength__c
```

Optional minimum field-value length before this rule is evaluated. If the value being masked is shorter than this number of characters, the rule is skipped entirely — the pattern is not compiled or matched. Leave blank to apply the rule to any value length. Applies to Regex, CreditCard, and ExactMatch modes; JsonKey mode ignores this setting because keys are matched rather than the whole value. Note: this is a value-length check (how long the actual content is), not a schema check — if this minimum exceeds a field's configured maximum length (e.g. MinInputLength = 50 on a Text(20) field), the rule can never fire on that field but the framework does not detect or warn about it. Size the minimum to match the shortest plausible match of the rule's pattern.

**Field Attributes:**

| Attribute | Value |
|-----------|-------|
| Data Type | Number(4,0) |
| Required | false |
| Unique | false |
| External ID | false |

### Mode__c

```apex
global String Mode__c
```

How the Pattern is interpreted. Regex: the Pattern is a regular expression matched against the whole field value. Matches are replaced with the Replacement; $1, $2 etc. may refer to capture groups. JSON by Key: the Pattern is a regex matched against JSON keys in the field value. The VALUE stored under each matching key is replaced with the Replacement. Non-matching keys are untouched. Works at any nesting depth. Example — Pattern: ^(password|token|secret)$, Replacement: ***REDACTED*** Input: {"user":"alice","password":"hunter2","token":"abc123"} Result: {"user":"alice","password":"***REDACTED***","token":"***REDACTED***"} Exact Match: the Pattern is an exact substring to find in the field value; every occurrence is replaced with the Replacement. Credit Card: same as Regex, but each match must also pass the Luhn (mod-10) checksum per ISO/IEC 7812. Use for credit-card redaction to avoid redacting non-card 13-19 digit runs like transaction IDs.

**Field Attributes:**

| Attribute | Value |
|-----------|-------|
| Data Type | Picklist |
| Required | true |

**Picklist Values:**

| API Name | Label | Active |
|----------|-------|--------|
| `Regex` | Regex | Yes |
| `JsonKey` | JSON by Key | No |
| `ExactMatch` | Exact Match | No |
| `CreditCard` | Credit Card | No |

### Order__c

```apex
global Decimal Order__c
```

Execution sequence when multiple rules apply to the same field. Lower numbers run first. Use gaps like 10, 20, 30 so new rules can be inserted between existing ones without renumbering.

**Field Attributes:**

| Attribute | Value |
|-----------|-------|
| Data Type | Number(4,0) |
| Required | true |
| Unique | false |
| External ID | false |

### Pattern__c

```apex
global String Pattern__c
```

What to look for. The format depends on the Mode: a regex matched against the field value in Regex mode, a regex matched against JSON keys in JSON by Key mode, or the exact substring to find in Exact Match mode.

**Field Attributes:**

| Attribute | Value |
|-----------|-------|
| Data Type | Long Text Area(1024) |

### Replacement__c

```apex
global String Replacement__c
```

What to replace matched content with. In Regex mode, use $1, $2 etc. to refer to capture groups from the Pattern. In other modes, $ and \\ are treated as ordinary characters. Blank replacement removes the match entirely; Regex mode requires an explicit replacement.

**Field Attributes:**

| Attribute | Value |
|-----------|-------|
| Data Type | Text(255) |
| Required | false |
| Unique | false |
| External ID | false |

