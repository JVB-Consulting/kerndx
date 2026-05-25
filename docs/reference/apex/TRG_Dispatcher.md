---
title: "TRG_Dispatcher"
type: class
description: "Factory class for instantiating and executing configured trigger actions. Manages the lifecycle of trigger actions and supports bypassing specific actions. Adapted from: Apex Trigger Actions Framework"
author: "Jason Van Beukering"
group: "Triggers"
date: "February 2026, May 2026"
since: "1.0"
category: apex
---

# TRG_Dispatcher

**Class** · Group: `Triggers`

```apex
global inherited sharing class TRG_Dispatcher
```

Factory class for instantiating and executing configured trigger actions. Manages the lifecycle of trigger actions and supports bypassing specific actions. Adapted from: Apex Trigger Actions Framework

**Since:** 1.0

**Example:**

```apex
trigger TRG_Foobar on Foobar__c (before insert, before update)
{
    new TRG_Dispatcher().run();
}
```

---

## Methods

| Method | Description |
|--------|-------------|
| global void [run](#run)() | Entry point for trigger execution. |

---

## Method Details

### run

```apex
global void run()
```

Entry point for trigger execution. Reads the trigger context, checks bypass status,
and dispatches to configured trigger action handlers.

**Throws:**

- [UTIL_Exceptions.ConfigurationException](UTIL_Exceptions.ConfigurationException.md) - If a TriggerAction__mdt row reaches dispatch with both ApexClassName__c and FlowName__c blank.
The MutuallyExclusiveTarget validation rule blocks this configuration at deploy time, so the path is reachable only via Tooling-API insertion that bypasses the VR.
- [UTIL_Exceptions.IllegalStateException](UTIL_Exceptions.IllegalStateException.md) - If called outside of a trigger execution context.

**Since:** 1.0

**Example:**

```apex
trigger TRG_Foobar on Foobar__c (before insert, before update)
{
    new TRG_Dispatcher().run();
}
```

