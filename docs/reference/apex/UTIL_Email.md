---
title: "UTIL_Email"
type: class
pageClass: reference
description: "Utility class for validating and sending emails within the Salesforce platform. Includes a unicode-aware email validation pattern and a two-step deliverability detection mechanism."
author: "Jason Van Beukering"
group: "Email"
date: "February 2026, May 2026"
since: "1.0"
category: apex
---

# UTIL_Email

**Class** · Group: `Email`

<div class="apex-member apex-class">

```apex
global inherited sharing class UTIL_Email
```

Utility class for validating and sending emails within the Salesforce platform. Includes a unicode-aware email validation pattern and a two-step deliverability detection mechanism.

**Example**

```apex
Boolean valid = UTIL_Email.isValidEmailAddress('user@example.com');
UTIL_Email.sendEmail(new List<String>{'admin@example.com'}, 'Alert', 'System notification body', false, null);
UTIL_Email.DeliverabilityAccessLevel level = UTIL_Email.getEmailDeliverabilityAccessLevel();
```

</div>

---

## Properties

| Property | Description |
|----------|-------------|
| global enum [DeliverabilityAccessLevel](UTIL_Email.DeliverabilityAccessLevel.md) | Enum representing the three possible email deliverability settings in a Salesforce org. |

## Methods

| Method | Description |
|--------|-------------|
| global static [UTIL_Email.DeliverabilityAccessLevel](UTIL_Email.DeliverabilityAccessLevel.md) [getEmailDeliverabilityAccessLevel](#getemaildeliverabilityaccesslevel)() | Determines the org's current email deliverability access level. |
| global static [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) [isNotValidEmailAddress](#isnotvalidemailaddress)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) address) | Convenience inverse of isValidEmailAddress(String). |
| global static [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) [isValidEmailAddress](#isvalidemailaddress)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) address) | Checks whether the supplied address matches the default email pattern. |
| global static void [sendEmail](#sendemail)([List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)> toAddresses, [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) subject, [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) body, [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) isHtml, [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[Messaging.EmailFileAttachment](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_classes_email_outbound_attachment.htm)> fileAttachments) | Internal send method that assembles and dispatches a SingleEmailMessage. |

---

## Method Details

### getEmailDeliverabilityAccessLevel

<div class="apex-member">

```apex
global static UTIL_Email.DeliverabilityAccessLevel getEmailDeliverabilityAccessLevel()
```

Determines the org's current email deliverability access level.
First attempts a capacity reservation; if that throws, falls back to parsing the
email-admin settings page to extract the selected option.

**Returns** [UTIL_Email.DeliverabilityAccessLevel](UTIL_Email.DeliverabilityAccessLevel.md) — The detected DeliverabilityAccessLevel. Defaults to NO_ACCESS on failure.

</div>

### isNotValidEmailAddress

<div class="apex-member">

```apex
global static Boolean isNotValidEmailAddress(String address)
```

Convenience inverse of **`isValidEmailAddress(String)`** .

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `address` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The address to validate. |

**Returns** [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) — True when the address is invalid.

</div>

### isValidEmailAddress

<div class="apex-member">

```apex
global static Boolean isValidEmailAddress(String address)
```

Checks whether the supplied address matches the default email pattern.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `address` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The address to validate. |

**Returns** [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) — True when the address is syntactically valid.

</div>

### sendEmail

<div class="apex-member">

```apex
global static void sendEmail(List<String> toAddresses, String subject, String body, Boolean isHtml, List<Messaging.EmailFileAttachment> fileAttachments)
```

Internal send method that assembles and dispatches a SingleEmailMessage.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `toAddresses` | [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm) | Recipient addresses. Exits silently when null or empty. |
| `subject` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | Email subject. |
| `body` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | Body content. |
| `isHtml` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | True to set HTML body, false for plain text. |
| `fileAttachments` | [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) | Optional file attachments. |

</div>

