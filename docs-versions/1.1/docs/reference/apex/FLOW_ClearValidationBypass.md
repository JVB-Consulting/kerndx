---
title: "FLOW_ClearValidationBypass"
type: class
description: "Flow invocable action to clear validation rule bypasses for the current transaction. Use this after DML operations in Flow to explicitly clear bypasses set by FLOW_BypassValidation. Important: While b"
author: "Jason Van Beukering"
group: "Validation"
date: "January 2026, May 2026"
since: "1.0"
category: apex
---

# FLOW_ClearValidationBypass

**Class** · Group: `Validation`

```apex
global inherited sharing class FLOW_ClearValidationBypass
```

Flow invocable action to clear validation rule bypasses for the current transaction. Use this after DML operations in Flow to explicitly clear bypasses set by FLOW_BypassValidation. Important: While bypasses are automatically cleared at the end of the transaction, explicitly clearing them after DML improves code clarity and prevents accidental bypass of subsequent validation in the same transaction.

**Since:** 1.0

**Example:**

`// Flow Configuration - Clear specific bypass: Action: Clear Validation Bypass Input: ` Name: Account // Flow Configuration - Clear all bypasses: Action: Clear Validation Bypass Input: `ClearAll: true `

**See Also:** [UTIL_ValidationRule](UTIL_ValidationRule.md), [FLOW_BypassValidation](FLOW_BypassValidation.md)

---

## Methods

| Method | Description |
|--------|-------------|
| global static void [clearBypass](#clearbypass)([List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[FLOW_ClearValidationBypass.DTO_Request](FLOW_ClearValidationBypass.DTO_Request.md)> requests) | Clears validation rule bypasses for the current transaction. |

## Inner Classes

| Class | Description |
|-------|-------------|
| [DTO_Request](FLOW_ClearValidationBypass.DTO_Request.md) | Request DTO for the Clear Validation Bypass invocable action. |

---

## Method Details

### clearBypass

```apex
@InvocableMethod(category='Validation' description='Clears validation rule bypasses for an object, group, or specific rule for the current transaction.' label='Clear Validation Bypass') global static void clearBypass(List<FLOW_ClearValidationBypass.DTO_Request> requests)
```

Clears validation rule bypasses for the current transaction.
If clearAll is true, all active bypasses are removed. Otherwise, the specified
name is removed from all bypass lists (object, group, and rule).

**Parameters:**

- `requests` ([List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)) - List of clear bypass requests

**Since:** 1.0

**Example:**

```apex
// Clear Account bypass
FLOW_ClearValidationBypass.DTO_Request request = new FLOW_ClearValidationBypass.DTO_Request();
request.name = 'Account';
FLOW_ClearValidationBypass.clearBypass(new List<FLOW_ClearValidationBypass.DTO_Request>{request});
```

