---
title: "SVC_Omnistudio.OmniCallable"
type: class
pageClass: reference
description: "A global inner interface that allows the SVC_Omnistudio class to instantiate a class and perform an operation within the Omnistudio framework. Classes implementing this interface are expected to defin"
since: "1.0"
category: apex
---

# SVC_Omnistudio.OmniCallable

**Class**

<div class="apex-member apex-class">

```apex
global interface SVC_Omnistudio.OmniCallable
```

A global inner interface that allows the SVC_Omnistudio class to instantiate a class and perform an operation within the Omnistudio framework. Classes implementing this interface are expected to define the call method to execute custom logic using provided parameters.

</div>

---

## Methods

| Method | Description |
|--------|-------------|
| global abstract void [call](#call)([SVC_Omnistudio.Parameters](SVC_Omnistudio.Parameters.md) parameters) | Will execute an operation based on the parameters provided |

---

## Method Details

### call

<div class="apex-member">

```apex
global abstract void call(SVC_Omnistudio.Parameters parameters)
```

Will execute an operation based on the parameters provided

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `parameters` | [SVC_Omnistudio.Parameters](SVC_Omnistudio.Parameters.md) | The Omnistudio input, output and options parameters |

</div>

