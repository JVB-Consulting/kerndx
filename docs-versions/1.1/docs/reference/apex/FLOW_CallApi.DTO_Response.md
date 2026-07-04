---
title: "FLOW_CallApi.DTO_Response"
type: class
description: "Data Transfer Object representing the web service response or errors."
since: "1.0"
category: apex
---

# FLOW_CallApi.DTO_Response

**Class**

```apex
global inherited sharing class FLOW_CallApi.DTO_Response
```

Data Transfer Object representing the web service response or errors.

**Since:** 1.0

---

## Fields

| Field | Description |
|-------|-------------|
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [apiCallId](#apicallid) | The ID of the ApiCall__c record for this callout. |
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [extractedValue](#extractedvalue) | The value extracted from the JSON response using the specified JSONPath. |
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [responseBody](#responsebody) | The JSON payload containing the response body or failure message. |
| global [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) [success](#success) | Whether the API callout completed successfully. |

---

## Field Details

### apiCallId

```apex
@InvocableVariable(description='Id of the API Call record for the callout' label='API Call Id') global String apiCallId
```

**Type:** [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)

The ID of the ApiCall__c record for this callout.

**Since:** 1.0

### extractedValue

```apex
@InvocableVariable(description='The extracted element from the JSON response' label='Extracted Value') global String extractedValue
```

**Type:** [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)

The value extracted from the JSON response using the specified JSONPath.

**Since:** 1.0

### responseBody

```apex
@InvocableVariable(description='The JSON payload containing the response of the callout or failure message if applicable' label='Response Body') global String responseBody
```

**Type:** [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)

The JSON payload containing the response body or failure message.

**Since:** 1.0

### success

```apex
@InvocableVariable(description='A boolean representation of the success or failure of the callout' label='API Response Success Indicator') global Boolean success
```

**Type:** [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm)

Whether the API callout completed successfully.

**Since:** 1.0

