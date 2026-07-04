---
title: "UTIL_AsyncChain.StepResult"
type: class
description: "Immutable result object returned by each ChainStep to indicate success or failure. Use the static factory methods to create instances."
since: "1.0"
category: apex
---

# UTIL_AsyncChain.StepResult

**Class**

```apex
global inherited sharing class UTIL_AsyncChain.StepResult
```

Immutable result object returned by each ChainStep to indicate success or failure. Use the static factory methods to create instances.

**Since:** 1.0

**Example:**

```apex
UTIL_AsyncChain.StepResult result = UTIL_AsyncChain.succeeded('All records processed');
UTIL_AsyncChain.StepResult failure = UTIL_AsyncChain.failed('Missing required field');
```

---

## Properties

| Property | Description |
|----------|-------------|
| global [Object](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_System_Object.htm) [data](#data) | Optional payload data returned by the step. |
| global [Exception](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_classes_exception_methods.htm) [error](#error) | The exception that caused the step to fail, if applicable. |
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [message](#message) | Optional human-readable message describing the outcome. |
| global [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) [success](#success) | Whether the step completed successfully. |

---

## Property Details

### data

```apex
global Object data
```

**Type:** [Object](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_System_Object.htm)

Optional payload data returned by the step.

Since:

### error

```apex
global Exception error
```

**Type:** [Exception](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_classes_exception_methods.htm)

The exception that caused the step to fail, if applicable.

Since:

### message

```apex
global String message
```

**Type:** [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)

Optional human-readable message describing the outcome.

Since:

### success

```apex
global Boolean success
```

**Type:** [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm)

Whether the step completed successfully.

Since:

