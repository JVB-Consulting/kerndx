---
title: "FLOW_SendEmail.DTO_Response"
type: class
pageClass: reference
description: "Data Transfer Object (DTO) representing the outcome of an email request."
since: "1.0"
category: apex
---

# FLOW_SendEmail.DTO_Response

**Class**

```apex
global inherited sharing class FLOW_SendEmail.DTO_Response
```

Data Transfer Object (DTO) representing the outcome of an email request.

**Since:** 1.0

---

## Fields

| Field | Description |
|-------|-------------|
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [errors](#errors) | Detailed error message if success is false. |
| global [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) [success](#success) | true if the email was successfully handed off to the delivery mechanism; false otherwise. |

---

## Field Details

### errors

```apex
@InvocableVariable(required=false description='A string of errors encountered during the email send or activity logging attempt.' label='Errors') global String errors
```

**Type:** [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)

Detailed error message if success is false.

**Since:** 1.0

### success

```apex
@InvocableVariable(required=true description='Indicates whether the email was successfully submitted (true) or failed validation/internal process (false).' label='Send Successful') global Boolean success
```

**Type:** [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm)

true if the email was successfully handed off to the delivery mechanism; false otherwise.

**Since:** 1.0

