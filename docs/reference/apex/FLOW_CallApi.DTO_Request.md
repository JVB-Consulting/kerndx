---
title: "FLOW_CallApi.DTO_Request"
type: class
description: "Data Transfer Object representing the web service call request."
since: "1.0"
category: apex
---

# FLOW_CallApi.DTO_Request

**Class**

```apex
global inherited sharing class FLOW_CallApi.DTO_Request
```

Data Transfer Object representing the web service call request.

**Since:** 1.0

---

## Fields

| Field | Description |
|-------|-------------|
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [apiName](#apiname) | The full class name of the API handler to invoke. |
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [extractPath](#extractpath) | A JSONPath expression to extract a specific element from the response body. |
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [idempotencyKey](#idempotencykey) | Explicit idempotency key for duplicate detection. |
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [inputDelimiter](#inputdelimiter) | The delimiter used to split input parameters, defaults to a comma. |
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [inputs](#inputs) | A comma-delimited list of parameters in the format paramName=paramValue. |
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [recordId](#recordid) | The ID of the record triggering the callout. |

---

## Field Details

### apiName

```apex
@InvocableVariable(required=true description='The full class name of the API handler' label='API Name') global String apiName
```

**Type:** [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)

The full class name of the API handler to invoke.

**Since:** 1.0

### extractPath

```apex
@InvocableVariable(required=false description='Element to extract from the JSON response, using JsonPath Notation' label='Extract Path (JSONPath)') global String extractPath
```

**Type:** [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)

A JSONPath expression to extract a specific element from the response body.

**Since:** 1.0

### idempotencyKey

```apex
@InvocableVariable(required=false description='Explicit idempotency key for duplicate detection. If blank, auto-generated when enabled.' label='Idempotency Key') global String idempotencyKey
```

**Type:** [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)

Explicit idempotency key for duplicate detection. If blank, auto-generated when enabled.

**Since:** 1.0

### inputDelimiter

```apex
@InvocableVariable(required=false description='The delimiter to use when splitting parameters, defaults to a comma' label='Input Delimiter') global String inputDelimiter
```

**Type:** [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)

The delimiter used to split input parameters, defaults to a comma.

**Since:** 1.0

### inputs

```apex
@InvocableVariable(required=false description='A list of parameters in the format paramName=paramValue,paramName2=paramValue2' label='Inputs') global String inputs
```

**Type:** [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)

A comma-delimited list of parameters in the format paramName=paramValue.

**Since:** 1.0

### recordId

```apex
@InvocableVariable(required=false description='The ID of the object triggering the callout' label='Record Id') global String recordId
```

**Type:** [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)

The ID of the record triggering the callout.

**Since:** 1.0

