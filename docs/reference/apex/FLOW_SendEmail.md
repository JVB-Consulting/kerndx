---
title: "FLOW_SendEmail"
type: class
description: "Provides an invocable entry point for sending emails via Salesforce Flow with advanced capabilities. Supports: Hybrid execution (Direct Apex or delegating to a secondary Flow). Custom Merge Fields (re"
author: "Jason Van Beukering"
group: "Email"
date: "February 2026, May 2026"
since: "1.0"
category: apex
---

# FLOW_SendEmail

**Class** · Group: `Email`

```apex
global inherited sharing class FLOW_SendEmail
```

Provides an invocable entry point for sending emails via Salesforce Flow with advanced capabilities. Supports: Hybrid execution (Direct Apex or delegating to a secondary Flow). Custom Merge Fields (replacing [placeholder] text). Conditional Activity Logging (using standard TargetObjectId or the Workflow Engine).

**Since:** 1.0

**Example:**

```apex
FLOW_SendEmail.DTO_Request request = new FLOW_SendEmail.DTO_Request();
request.toAddress = 'customer@example.com';
request.templateUniqueName = 'Customer_Welcome_Email';
request.orgWideEmailAddress = 'noreply@company.com';
request.whatId = opportunityId;
request.saveAsActivity = true;
List<FLOW_SendEmail.DTO_Response> responses = FLOW_SendEmail.sendEmail(new List<FLOW_SendEmail.DTO_Request> {request});
```

---

## Methods

| Method | Description |
|--------|-------------|
| global static [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[FLOW_SendEmail.DTO_Response](FLOW_SendEmail.DTO_Response.md)> [sendEmail](#sendemail)([List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[FLOW_SendEmail.DTO_Request](FLOW_SendEmail.DTO_Request.md)> dtoEmails) | Invocable method to process email requests. |

## Inner Classes

| Class | Description |
|-------|-------------|
| [DTO_Request](FLOW_SendEmail.DTO_Request.md) | Data Transfer Object (DTO) representing the input parameters for a single email request. |
| [DTO_Response](FLOW_SendEmail.DTO_Response.md) | Data Transfer Object (DTO) representing the outcome of an email request. |

---

## Method Details

### sendEmail

```apex
@InvocableMethod(category='Email' description='Sends an email using a template by delegating to an internal Flow. Optionally logs an activity, using either standard email limits or the Workflow Engine.' label='Send Email (Flow-Delegated) and Log Activity') global static List<FLOW_SendEmail.DTO_Response> sendEmail(List<FLOW_SendEmail.DTO_Request> dtoEmails)
```

Invocable method to process email requests.

**Parameters:**

- `dtoEmails` ([List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)) - A list of DTO_Request objects configured in the Flow.

**Returns:** [FLOW_SendEmail.DTO_Response](FLOW_SendEmail.DTO_Response.md) - A list of `DTO_Response` objects indicating success or failure for each request.

**Since:** 1.0

**Example:**

```apex
FLOW_SendEmail.DTO_Request emailRequest = new FLOW_SendEmail.DTO_Request();
emailRequest.toAddress = 'customer@example.com';
emailRequest.templateUniqueName = 'Customer_Welcome_Email';
emailRequest.orgWideEmailAddress = 'noreply@company.com';
emailRequest.whatId = opportunityId;
emailRequest.saveAsActivity = true;
List<FLOW_SendEmail.DTO_Response> responses = FLOW_SendEmail.sendEmail(new List<FLOW_SendEmail.DTO_Request>{emailRequest});
if(responses[0].success)
{
	LOG_Builder.build().info('Email sent successfully').emitAt('MyFlow.sendEmail');
}
```

