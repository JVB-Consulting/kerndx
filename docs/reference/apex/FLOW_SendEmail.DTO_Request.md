---
title: "FLOW_SendEmail.DTO_Request"
type: class
pageClass: reference
description: "Data Transfer Object (DTO) representing the input parameters for a single email request."
since: "1.0"
category: apex
---

# FLOW_SendEmail.DTO_Request

**Class**

```apex
global inherited sharing class FLOW_SendEmail.DTO_Request
```

Data Transfer Object (DTO) representing the input parameters for a single email request.

**Since:** 1.0

---

## Fields

| Field | Description |
|-------|-------------|
| global [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[Id](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_id.htm)> [fileIds](#fileids) | A list of ContentVersion IDs to attach to the email. |
| global [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[DTO_NameValue](DTO_NameValue.md)> [mergeFields](#mergefields) | A list of custom key-value pairs to replace placeholders in the email body (e.g., [InvoiceNumber]). |
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [orgWideEmailAddress](#orgwideemailaddress) | The email address defined in Organization-Wide Email Addresses to be used as the sender. |
| global [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) [saveAsActivity](#saveasactivity) | Determines if a Task should be created. |
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [templateUniqueName](#templateuniquename) | The DeveloperName of the Email Template. |
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [toAddress](#toaddress) | The recipient. |
| global [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) [useStandardLogActivity](#usestandardlogactivity) | Controls the mechanism used for Activity Logging. |
| global [Id](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_id.htm) [whatId](#whatid) | The ID of the record that the email is related to (e.g., Opportunity, Case). |

---

## Field Details

### fileIds

```apex
@InvocableVariable(required=false description='A list of ContentVersion or Document Ids to attach as files to the email.' label='List of File Ids for Attachments') global List<Id> fileIds
```

**Type:** [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)

A list of ContentVersion IDs to attach to the email.

**Since:** 1.0

### mergeFields

```apex
@InvocableVariable(required=false description='List of name-value pairs for custom merge fields to replace in the email body. Placeholders must be in the format [mergefieldname].' label='Custom Merge Fields') global List<DTO_NameValue> mergeFields
```

**Type:** [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)

A list of custom key-value pairs to replace placeholders in the email body (e.g., [InvoiceNumber]).

**Since:** 1.0

### orgWideEmailAddress

```apex
@InvocableVariable(required=true description='The org-wide email address to be used as the sender (From address).' label='Sender Org Wide Email Address') global String orgWideEmailAddress
```

**Type:** [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)

The email address defined in Organization-Wide Email Addresses to be used as the sender.

**Since:** 1.0

### saveAsActivity

```apex
@InvocableVariable(description='Indicates if an activity (Task) should be logged against the Related To Id (WhatId). Ignored if Related To Id is null.' label='Save as Activity' placeholderText='false' defaultValue='false') global Boolean saveAsActivity
```

**Type:** [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm)

Determines if a Task should be created.
Note: This is ignored if whatId is null or if useStandardLogActivity is enabled (which handles logging natively).

**Since:** 1.0

### templateUniqueName

```apex
@InvocableVariable(required=true description='The unique name (DeveloperName) of the email template to generate the email content.' label='Email Template Unique Name') global String templateUniqueName
```

**Type:** [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)

The DeveloperName of the Email Template.

**Since:** 1.0

### toAddress

```apex
@InvocableVariable(required=false description='The Id of the Contact, Lead, or User, or the recipient email address. Used to resolve "TargetObjectId".' label='To Address or Target WhoId') global String toAddress
```

**Type:** [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)

The recipient. Can be a standard Email Address or the Salesforce ID of a Contact, Lead, or User.

**Since:** 1.0

### useStandardLogActivity

```apex
@InvocableVariable(description='If True, standard activity logging is used. If False, custom activity logging is performed via the internal Flow.' label='Use Standard Activity Logging' placeholderText='false' defaultValue='false') global Boolean useStandardLogActivity
```

**Type:** [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm)

Controls the mechanism used for Activity Logging.

    true: Uses standard Messaging.SingleEmailMessage activity logging (counts towards limits).
    false: Uses a custom Task insertion approach (via Workflow Engine/Flow).

**Since:** 1.0

### whatId

```apex
@InvocableVariable(required=true description='The Id of a record related to the email for merge field data (WhatId).' label='Related To WhatId') global Id whatId
```

**Type:** [Id](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_id.htm)

The ID of the record that the email is related to (e.g., Opportunity, Case). Used for merge fields.

**Since:** 1.0

