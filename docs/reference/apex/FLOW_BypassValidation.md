---
title: "FLOW_BypassValidation"
type: class
description: "Flow invocable action to bypass validation rules for the current transaction. Use this before DML operations in Flow to temporarily disable validation rules. Important: Bypasses are cleared at the end"
author: "Jason Van Beukering"
group: "Validation"
date: "January 2026, May 2026"
since: "1.0"
category: apex
---

# FLOW_BypassValidation

**Class** · Group: `Validation`

```apex
global inherited sharing class FLOW_BypassValidation
```

Flow invocable action to bypass validation rules for the current transaction. Use this before DML operations in Flow to temporarily disable validation rules. Important: Bypasses are cleared at the end of the transaction. Use FLOW_ClearValidationBypass after your DML to explicitly clear bypasses for clarity.

**Since:** 1.0

**Example:**

`// Flow Configuration: Action: Bypass Validation Input: ` BypassType: OBJECT_NAME (or GROUP_NAME or RULE_NAME) Name: Account // Perform DML... Action: Clear Validation Bypass Input: `Name: Account `

**See Also:** [UTIL_ValidationRule](UTIL_ValidationRule.md), [FLOW_ExecuteValidationRules](FLOW_ExecuteValidationRules.md), [FLOW_ClearValidationBypass](FLOW_ClearValidationBypass.md)

---

## Methods

| Method | Description |
|--------|-------------|
| global static void [bypass](#bypass)([List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[FLOW_BypassValidation.DTO_Request](FLOW_BypassValidation.DTO_Request.md)> requests) | Sets a validation bypass for the current transaction. |

## Inner Classes

| Class | Description |
|-------|-------------|
| [DTO_Request](FLOW_BypassValidation.DTO_Request.md) | Request DTO for the Bypass Validation invocable action. |

---

## Method Details

### bypass

```apex
@InvocableMethod(category='Validation' description='Bypasses validation rules for an object, group, or specific rule for the current transaction.' label='Bypass Validation') global static void bypass(List<FLOW_BypassValidation.DTO_Request> requests)
```

Sets a validation bypass for the current transaction.

**Parameters:**

- `requests` ([List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)) - List of bypass requests

**Throws:**

- [System.NoSuchElementException](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_classes_exception_methods.htm) - if an invalid bypass type is provided (with a user-friendly message)

**Since:** 1.0

**Example:**

```apex
// Bypass all Account validation rules
FLOW_BypassValidation.DTO_Request request = new FLOW_BypassValidation.DTO_Request();
request.bypassType = 'OBJECT_NAME';
request.name = 'Account';
FLOW_BypassValidation.bypass(new List<FLOW_BypassValidation.DTO_Request>{request});
```

