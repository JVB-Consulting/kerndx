---
title: "ApiCredential__mdt"
type: sobject
pageClass: reference
description: "Links outbound API handlers to their Salesforce Named Credential for endpoint resolution and authentication."
category: metadata
---

# ApiCredential__mdt

**Sobject**

```apex
global class ApiCredential__mdt extends SObject
```

**Extends:** [SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm)

Links outbound API handlers to their Salesforce Named Credential for endpoint resolution and authentication.

---

## Fields

| Field | Description |
|-------|-------------|
| global [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[ApiSetting__mdt](../metadata/ApiSetting__mdt.md)> [ApiSettings__r](#apisettings__r) | Reciprocal relationship for ApiSetting__mdt.ApiCredential__c. |
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [NamedCredential__c](#namedcredential__c) | The API name of the Salesforce Named Credential to use for authentication. |

---

## Field Details

### ApiSettings__r

```apex
global List<ApiSetting__mdt> ApiSettings__r
```

Reciprocal relationship for **`ApiSetting__mdt.ApiCredential__c`** .

### NamedCredential__c

```apex
global String NamedCredential__c
```

The API name of the Salesforce Named Credential to use for authentication. When specified, the framework uses this Named Credential for endpoint URL and authentication instead of manual configuration.

**Field Attributes:**

| Attribute | Value |
|-----------|-------|
| Data Type | Text(255) |
| Required | false |
| Unique | false |
| External ID | false |

