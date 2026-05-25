---
title: "SVC_Omnistudio.OmniCallable"
type: class
description: "A global inner interface that allows the SVC_Omnistudio class to instantiate a class and perform an operation within the Omnistudio framework. Classes implementing this interface are expected to defin"
since: "1.0"
category: apex
---

# SVC_Omnistudio.OmniCallable

**Class**

```apex
global interface SVC_Omnistudio.OmniCallable
```

A global inner interface that allows the SVC_Omnistudio class to instantiate a class and perform an operation within the Omnistudio framework. Classes implementing this interface are expected to define the call method to execute custom logic using provided parameters.

**Since:** 1.0

---

## Methods

| Method | Description |
|--------|-------------|
| global abstract void [call](#call)([SVC_Omnistudio.Parameters](SVC_Omnistudio.Parameters.md) parameters) | Will execute an operation based on the parameters provided |

---

## Method Details

### call

```apex
global abstract void call(SVC_Omnistudio.Parameters parameters)
```

Will execute an operation based on the parameters provided

**Parameters:**

- `parameters` ([SVC_Omnistudio.Parameters](SVC_Omnistudio.Parameters.md)) - The Omnistudio input, output and options parameters

