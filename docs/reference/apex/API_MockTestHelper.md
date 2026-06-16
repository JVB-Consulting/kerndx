---
title: "API_MockTestHelper"
type: class
pageClass: reference
description: "Test helper for API mock verification. Provides assertion methods that delegate to API_MockFactory verification API with descriptive error messages."
author: "Jason Van Beukering"
group: "Web Services"
date: "February 2026, May 2026"
since: "1.0"
category: apex
---

# API_MockTestHelper

**Class** · Group: `Web Services`

```apex
global inherited sharing class API_MockTestHelper
```

Test helper for API mock verification. Provides assertion methods that delegate to API_MockFactory verification API with descriptive error messages.

**Since:** 1.0

**Example:**

```apex
API_MockFactory.forService('API_SendEmail').body('{}').statusCode(200).register();
// ... execute callout logic ...
API_MockTestHelper.assertServiceCalled('API_SendEmail');
API_MockTestHelper.assertServiceCalledTimes('API_SendEmail', 1);
```

**See Also:** [API_MockFactory](API_MockFactory.md)

---

## Methods

| Method | Description |
|--------|-------------|
| global static void [assertLastRequestContains](#assertlastrequestcontains)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) serviceName, [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) expectedContent) | Asserts that the last request body contains the expected text. |
| global static void [assertServiceCalled](#assertservicecalled)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) serviceName) | Asserts that a service was called at least once. |
| global static void [assertServiceCalledTimes](#assertservicecalledtimes)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) serviceName, [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) expectedCount) | Asserts that a service was called exactly the specified number of times. |
| global static void [assertServiceNeverCalled](#assertservicenevercalled)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) serviceName) | Asserts that a service was never called. |

---

## Method Details

### assertLastRequestContains

<div class="apex-member">

```apex
global static void assertLastRequestContains(String serviceName, String expectedContent)
```

Asserts that the last request body contains the expected text.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `serviceName` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The service class name to verify |
| `expectedContent` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | Text expected in the last request body |

</div>

### assertServiceCalled

<div class="apex-member">

```apex
global static void assertServiceCalled(String serviceName)
```

Asserts that a service was called at least once.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `serviceName` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The service class name to verify |

</div>

### assertServiceCalledTimes

<div class="apex-member">

```apex
global static void assertServiceCalledTimes(String serviceName, Integer expectedCount)
```

Asserts that a service was called exactly the specified number of times.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `serviceName` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The service class name to verify |
| `expectedCount` | [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) | The expected number of invocations |

</div>

### assertServiceNeverCalled

<div class="apex-member">

```apex
global static void assertServiceNeverCalled(String serviceName)
```

Asserts that a service was never called.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `serviceName` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The service class name to verify |

</div>

