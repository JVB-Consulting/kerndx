---
title: "ApiIssue__c"
type: sobject
pageClass: reference
description: "Tracks API integration issues for troubleshooting, manual resolution, and automatic retry of failed service calls. Each record captures the error details, request parameters, and links to the originat"
category: objects
---

# ApiIssue__c

**Sobject**

<div class="apex-member apex-class">

```apex
global class ApiIssue__c extends SObject
```

**Extends:** [SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm)

Tracks API integration issues for troubleshooting, manual resolution, and automatic retry of failed service calls. Each record captures the error details, request parameters, and links to the originating API call.

</div>

---

## Fields

| Field | Description |
|-------|-------------|
| global [Id](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_id.htm) [ApiCall__c](#apicall__c) | Lookup to the API Call record that produced this issue. |
| global [ApiCall__c](../objects/ApiCall__c.md) [ApiCall__r](#apicall__r) | Lookup to the API Call record that produced this issue. |
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [Direction__c](#direction__c) | Indicates whether this issue originated from an inbound or outbound API call. |
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [ErrorMessages__c](#errormessages__c) | Error messages encountered during API call processing. |
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [IdempotencyKey__c](#idempotencykey__c) | Preserves the idempotency key from the failed API call. |
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [OriginatingRecordId__c](#originatingrecordid__c) | The Salesforce record ID of the originating record associated with this API issue, when different from the triggering record. |
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [RequestBody__c](#requestbody__c) | The inbound request body content. |
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [RequestMethod__c](#requestmethod__c) | The HTTP method of the inbound request (GET, POST, etc.). |
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [RequestParameters__c](#requestparameters__c) | Name-value pairs of the request parameters passed to the API service when the call was made. |
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [RequestParametersHash__c](#requestparametershash__c) | Hash of the request parameters, used to identify duplicate requests and support deduplication during retry processing. |
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [RequestPath__c](#requestpath__c) | The inbound request URI path. |
| global [Datetime](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_datetime.htm) [ResolvedDate__c](#resolveddate__c) | The date and time when this failure was resolved, either through replay or manual resolution. |
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [ServiceName__c](#servicename__c) | The fully qualified Apex class name of the API service handler that produced this issue (e.g. |
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [Status__c](#status__c) | Current status: Open (awaiting investigation or resolution) or Resolved (resolved by automatic retry batch job or manual retry via quick action). |
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [TriggeringRecordId__c](#triggeringrecordid__c) | The 18-character Salesforce record ID that initiated the original API call. |

### ApiCall__c

```apex
global Id ApiCall__c
```

Lookup to the API Call record that produced this issue. Provides access to the full request/response details and processing history.

**Field Attributes:**

| Attribute | Value |
|-----------|-------|
| Data Type | ApiCall__c |
| Required | false |

### ApiCall__r

```apex
global ApiCall__c ApiCall__r
```

Lookup to the API Call record that produced this issue. Provides access to the full request/response details and processing history.

**Field Attributes:**

| Attribute | Value |
|-----------|-------|
| Data Type | ApiCall__c |
| Required | false |

### Direction__c

```apex
global String Direction__c
```

Indicates whether this issue originated from an inbound or outbound API call.

**Field Attributes:**

| Attribute | Value |
|-----------|-------|
| Data Type | Picklist |
| Required | false |

**Picklist Values:**

| API Name | Label | Active |
|----------|-------|--------|
| `Outbound` | Outbound | Yes |
| `Inbound` | Inbound | No |

### ErrorMessages__c

```apex
global String ErrorMessages__c
```

Error messages encountered during API call processing. May contain multiple messages separated by line breaks.

**Field Attributes:**

| Attribute | Value |
|-----------|-------|
| Data Type | Long Text Area(131072) |

### IdempotencyKey__c

```apex
global String IdempotencyKey__c
```

Preserves the idempotency key from the failed API call. When retried, this key is copied to the new API call so the external system treats the retry as a repeat of the original request.

**Field Attributes:**

| Attribute | Value |
|-----------|-------|
| Data Type | Text(255) |
| Required | false |
| Unique | false |
| External ID | false |

### OriginatingRecordId__c

```apex
global String OriginatingRecordId__c
```

The Salesforce record ID of the originating record associated with this API issue, when different from the triggering record.

**Field Attributes:**

| Attribute | Value |
|-----------|-------|
| Data Type | Text(18) |
| Required | false |
| Unique | false |
| External ID | false |

### RequestBody__c

```apex
global String RequestBody__c
```

The inbound request body content. Captured for failure replay functionality. Truncated to 131072 characters.

**Field Attributes:**

| Attribute | Value |
|-----------|-------|
| Data Type | Long Text Area(131072) |

### RequestMethod__c

```apex
global String RequestMethod__c
```

The HTTP method of the inbound request (GET, POST, etc.). Captured for failure replay.

**Field Attributes:**

| Attribute | Value |
|-----------|-------|
| Data Type | Text(10) |
| Required | false |
| Unique | false |
| External ID | false |

### RequestParameters__c

```apex
global String RequestParameters__c
```

Name-value pairs of the request parameters passed to the API service when the call was made. Preserved from the original queue record for retry purposes.

**Field Attributes:**

| Attribute | Value |
|-----------|-------|
| Data Type | Long Text Area(131072) |

### RequestParametersHash__c

```apex
global String RequestParametersHash__c
```

Hash of the request parameters, used to identify duplicate requests and support deduplication during retry processing.

**Field Attributes:**

| Attribute | Value |
|-----------|-------|
| Data Type | Text(50) |
| Required | false |
| Unique | false |
| External ID | false |

### RequestPath__c

```apex
global String RequestPath__c
```

The inbound request URI path. Captured for failure replay functionality.

**Field Attributes:**

| Attribute | Value |
|-----------|-------|
| Data Type | Text(255) |
| Required | false |
| Unique | false |
| External ID | false |

### ResolvedDate__c

```apex
global Datetime ResolvedDate__c
```

The date and time when this failure was resolved, either through replay or manual resolution.

**Field Attributes:**

| Attribute | Value |
|-----------|-------|
| Data Type | Date Time |
| Required | false |

### ServiceName__c

```apex
global String ServiceName__c
```

The fully qualified Apex class name of the API service handler that produced this issue (e.g. API_SendEmail).

**Field Attributes:**

| Attribute | Value |
|-----------|-------|
| Data Type | Text(100) |
| Required | false |
| Unique | false |
| External ID | false |

### Status__c

```apex
global String Status__c
```

Current status: Open (awaiting investigation or resolution) or Resolved (resolved by automatic retry batch job or manual retry via quick action).

**Field Attributes:**

| Attribute | Value |
|-----------|-------|
| Data Type | Picklist |
| Required | false |

**Picklist Values:**

| API Name | Label | Active |
|----------|-------|--------|
| `Open` | Open | Yes |
| `Resolved` | Resolved | Yes |

### TriggeringRecordId__c

```apex
global String TriggeringRecordId__c
```

The 18-character Salesforce record ID that initiated the original API call. Use this to trace the failure back to its source record.

**Field Attributes:**

| Attribute | Value |
|-----------|-------|
| Data Type | Text(18) |
| Required | false |
| Unique | false |
| External ID | false |

