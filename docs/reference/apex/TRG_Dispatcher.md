---
title: "TRG_Dispatcher"
type: class
pageClass: reference
description: "Factory class for instantiating and executing configured trigger actions. Manages the lifecycle of trigger actions and supports bypassing specific actions. Adapted from: Apex Trigger Actions Framework"
author: "Jason Van Beukering"
group: "Triggers"
date: "February 2026, June 2026"
since: "1.0"
category: apex
---

# TRG_Dispatcher

**Class** · Group: `Triggers`

<div class="apex-member apex-class">

```apex
global inherited sharing class TRG_Dispatcher
```

Factory class for instantiating and executing configured trigger actions. Manages the lifecycle of trigger actions and supports bypassing specific actions. Adapted from: Apex Trigger Actions Framework

**Example**

```apex
trigger TRG_Foobar on Foobar__c (before insert, before update)
{
    new TRG_Dispatcher().run();
}
```

</div>

---

## Methods

| Method | Description |
|--------|-------------|
| global void [run](#run)() | Entry point for trigger execution. |

---

## Method Details

### run

<div class="apex-member">

```apex
global void run()
```

Entry point for trigger execution. Reads the trigger context, checks bypass status,
dispatches to configured trigger action handlers, and — at the outermost dispatch unwind — runs
any configured post-trigger actions.

**Post-trigger-action hook.** Each invocation records the dispatched object's `SObjectType` and,
when the current dispatch is the outermost one (`ACTION_STACK` empty after action execution) and
it completed without an unhandled exception, hands the accumulated touched-type set to
`UTIL_PostTriggerAction.run`. Outermost detection reuses `ACTION_STACK` — a self-initiated DML
that re-enters `run()` unwinds while the outer action frame is still on the stack, so only the
true outermost unwind fires. A dispatch that is object-bypassed or that aborts via a throwing
action does not fire post-actions (post-actions run only after the trigger-action chain
completes). Because each trigger timing (before/after) is a separate top-level dispatch,
post-actions can fire once per timing per DML operation; post-actions are expected to be
idempotent or to gate on `touchedSObjectTypes`.

**Throws**

| Exception | Description |
|-----------|-------------|
| [UTIL_Exceptions.ConfigurationException](UTIL_Exceptions.ConfigurationException.md) | If a TriggerAction__mdt row reaches dispatch with both ApexClassName__c and FlowName__c blank. The MutuallyExclusiveTarget validation rule blocks this configuration at deploy time, so the path is reachable only via Tooling-API insertion that bypasses the VR. |
| [UTIL_Exceptions.IllegalStateException](UTIL_Exceptions.IllegalStateException.md) | If called outside of a trigger execution context. |

**Example**

```apex
trigger TRG_Foobar on Foobar__c (before insert, before update)
{
    new TRG_Dispatcher().run();
}
```

</div>

