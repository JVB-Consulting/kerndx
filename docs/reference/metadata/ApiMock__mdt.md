---
title: "ApiMock__mdt"
type: sobject
pageClass: reference
description: "Configures mock response scenarios for API services. Supports dynamic response interpolation, request body pattern matching, and fault simulation for both inbound and outbound APIs."
category: metadata
---

# ApiMock__mdt

**Sobject**

```apex
global class ApiMock__mdt extends SObject
```

**Extends:** [SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm)

Configures mock response scenarios for API services. Supports dynamic response interpolation, request body pattern matching, and fault simulation for both inbound and outbound APIs.

---

## Fields

| Field | Description |
|-------|-------------|
| global [Id](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_id.htm) [ApiSetting__c](#apisetting__c) | The API Setting this mock belongs to. |
| global [ApiSetting__mdt](../metadata/ApiSetting__mdt.md) [ApiSetting__r](#apisetting__r) | The API Setting this mock belongs to. |
| global [Decimal](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_decimal.htm) [DelayMs__c](#delayms__c) | Simulated latency in milliseconds for fault simulation. |
| global [Decimal](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_decimal.htm) [FailureRate__c](#failurerate__c) | Percentage of requests that should return a simulated failure (0-100). |
| global [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) [IsActive__c](#isactive__c) | Controls whether this mock scenario is active. |
| global [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) [IsRegex__c](#isregex__c) | When checked, the Match Request Body Pattern is treated as a regular expression instead of a simple contains match. |
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [MatchRequestBodyPattern__c](#matchrequestbodypattern__c) | Optional pattern to match against request body. |
| global [Decimal](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_decimal.htm) [Priority__c](#priority__c) | Match priority for this mock. |
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [ResponseBody__c](#responsebody__c) | Mock response body content (JSON or XML). |
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [ResponseHeaders__c](#responseheaders__c) | JSON object of response headers to include in the mock response. |
| global [Decimal](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_decimal.htm) [StatusCode__c](#statuscode__c) | The HTTP status code to return in the mock response. |

---

## Field Details

### ApiSetting__c

```apex
global Id ApiSetting__c
```

The API Setting this mock belongs to. Multiple mocks can reference one setting, ordered by Priority.

**Field Attributes:**

| Attribute | Value |
|-----------|-------|
| Data Type | ApiSetting__mdt |
| Required | true |
| Unique | false |

### ApiSetting__r

```apex
global ApiSetting__mdt ApiSetting__r
```

The API Setting this mock belongs to. Multiple mocks can reference one setting, ordered by Priority.

**Field Attributes:**

| Attribute | Value |
|-----------|-------|
| Data Type | ApiSetting__mdt |
| Required | true |
| Unique | false |

### DelayMs__c

```apex
global Decimal DelayMs__c
```

Simulated latency in milliseconds for fault simulation. Set to 0 for no delay. Used to test timeout handling and retry logic.

**Field Attributes:**

| Attribute | Value |
|-----------|-------|
| Data Type | Number(5,0) |
| Required | false |
| Unique | false |
| External ID | false |
| Default Value | 0 |

### FailureRate__c

```apex
global Decimal FailureRate__c
```

Percentage of requests that should return a simulated failure (0-100). Set to 0 for no failures. Used to test retry logic under partial failure conditions.

**Field Attributes:**

| Attribute | Value |
|-----------|-------|
| Data Type | Percent(3,0) |
| Required | false |
| Default Value | 0 |

### IsActive__c

```apex
global Boolean IsActive__c
```

Controls whether this mock scenario is active. Inactive mocks are skipped during mock resolution.

**Field Attributes:**

| Attribute | Value |
|-----------|-------|
| Data Type | Checkbox |
| Default Value | true |

### IsRegex__c

```apex
global Boolean IsRegex__c
```

When checked, the Match Request Body Pattern is treated as a regular expression instead of a simple contains match.

**Field Attributes:**

| Attribute | Value |
|-----------|-------|
| Data Type | Checkbox |
| Default Value | false |

### MatchRequestBodyPattern__c

```apex
global String MatchRequestBodyPattern__c
```

Optional pattern to match against request body. Uses contains matching by default, or regex when Is Regex is checked.

**Field Attributes:**

| Attribute | Value |
|-----------|-------|
| Data Type | Text(255) |
| Required | false |
| Unique | false |
| External ID | false |

### Priority__c

```apex
global Decimal Priority__c
```

Match priority for this mock. Lower values indicate higher priority. Used when multiple mocks match the same request.

**Field Attributes:**

| Attribute | Value |
|-----------|-------|
| Data Type | Number(3,0) |
| Required | false |
| Unique | false |
| External ID | false |
| Default Value | 100 |

### ResponseBody__c

```apex
global String ResponseBody__c
```

Mock response body content (JSON or XML). Supports dynamic interpolation using {{request.field}} placeholders to echo request data back in the response.

**Field Attributes:**

| Attribute | Value |
|-----------|-------|
| Data Type | Long Text Area(131072) |

### ResponseHeaders__c

```apex
global String ResponseHeaders__c
```

JSON object of response headers to include in the mock response.

**Field Attributes:**

| Attribute | Value |
|-----------|-------|
| Data Type | Long Text Area(131072) |

### StatusCode__c

```apex
global Decimal StatusCode__c
```

The HTTP status code to return in the mock response.

**Field Attributes:**

| Attribute | Value |
|-----------|-------|
| Data Type | Number(3,0) |
| Required | false |
| Unique | false |
| External ID | false |
| Default Value | 200 |

