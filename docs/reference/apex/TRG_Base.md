---
title: "TRG_Base"
type: class
pageClass: reference
description: "The base class for trigger actions, designed to be extended and implement relevant interfaces. This class provides the core functionality for executing trigger actions based on the trigger context, wi"
author: "Jason Van Beukering"
group: "Triggers"
date: "February 2026, May 2026"
since: "1.0"
category: apex
---

# TRG_Base

**Class** · Group: `Triggers`

<div class="apex-member apex-class">

```apex
global inherited sharing virtual class TRG_Base
```

**Known Derived Types:** [TRG_ExecuteValidationRules](TRG_ExecuteValidationRules.md)

The base class for trigger actions, designed to be extended and implement relevant interfaces. This class provides the core functionality for executing trigger actions based on the trigger context, with support for bypassing specific SObject types. It is adapted from the apex-trigger-actions-framework.

**Example**

```apex
public with sharing class TRG_SetFoobarDefaults extends TRG_Base implements IF_Trigger.BeforeInsert
{
    public void beforeInsert(List<SObject> newRecords)
    {
        for(SObject record : newRecords)
        {
            if(record.get(Foobar__c.Name) == null)
            {
                record.put(Foobar__c.Name, 'Default');
            }
        }
    }
}
```

**See Also:** [TRG_Dispatcher](TRG_Dispatcher.md), [IF_Trigger](IF_Trigger.md)

</div>

---

## Properties

| Property | Description |
|----------|-------------|
| global enum [BypassType](TRG_Base.BypassType.md) | Indicates the type of trigger bypass being applied. |
| global [TriggerOperation](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_enum_System_TriggerOperation.htm) [context](#context) | The current operation type being processed by the trigger action. |
| global [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [sObjectName](#sobjectname) | The API name of the SObject being processed by the trigger action. |
| global [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm)> [triggerNew](#triggernew) | The list of "new" SObjects in the trigger context. |
| global [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm)> [triggerOld](#triggerold) | The list of "old" SObjects in the trigger context. |
| global [Map](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_map.htm)<[Id](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_id.htm), [SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm)> [triggerOldMap](#triggeroldmap) | Map of "old" SObjects keyed by Id, for efficient field change detection in update contexts. |

## Methods

| Method | Description |
|--------|-------------|
| global static void [bypass](#bypass)([SObjectType](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectType.htm) sObjectType) | Bypasses trigger actions for the specified SObject type. |
| global static void [bypass](#bypass)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) sObjectName) | Bypasses trigger actions for the specified SObject type. |
| global static void [bypass](#bypass)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) name, [TRG_Base.BypassType](TRG_Base.BypassType.md) type) | Bypasses a trigger by name, dispatching to the correct bypass set based on the bypass type. |
| global static void [bypassAction](#bypassaction)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) actionClassName) | Bypasses a specific trigger action class by name. |
| global static void [clearActionBypass](#clearactionbypass)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) actionClassName) | Clears the bypass for a specific trigger action class, allowing it to execute. |
| global static void [clearAllActionBypasses](#clearallactionbypasses)() | Clears all action-level bypasses, allowing all trigger action classes to execute. |
| global static void [clearAllBypasses](#clearallbypasses)() | Clears all SObject type bypasses, allowing all trigger actions to execute. |
| global static void [clearAllBypasses](#clearallbypasses)([TRG_Base.BypassType](TRG_Base.BypassType.md) type) | Clears all trigger bypasses, dispatching to the correct bypass set based on the bypass type. |
| global static void [clearBypass](#clearbypass)([SObjectType](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectType.htm) sObjectType) | Clears the bypass for the specified SObject type, allowing trigger actions to execute. |
| global static void [clearBypass](#clearbypass)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) sObjectName) | Clears the bypass for the specified SObject type, allowing trigger actions to execute. |
| global static void [clearBypass](#clearbypass)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) name, [TRG_Base.BypassType](TRG_Base.BypassType.md) type) | Clears a trigger bypass by name, dispatching to the correct bypass set based on the bypass type. |
| global static [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) [isActionBypassed](#isactionbypassed)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) actionClassName) | Checks if a specific trigger action class is bypassed. |
| global static [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) [isBypassed](#isbypassed)([SObjectType](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectType.htm) sObjectType) | Checks if trigger actions are bypassed for the specified SObject type. |
| global static [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) [isBypassed](#isbypassed)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) sObjectName) | Checks if trigger actions are bypassed for the specified SObject type. |
| global static [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) [isBypassed](#isbypassed)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) name, [TRG_Base.BypassType](TRG_Base.BypassType.md) type) | Checks if a trigger is bypassed, dispatching to the correct bypass set based on the bypass type. |
| global static [TRG_Base.BypassType](TRG_Base.BypassType.md) [resolveBypassType](#resolvebypasstype)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) bypassTypeString) | Parses a bypass type string into the corresponding BypassType enum value. |
| global void [run](#run)() | Executes the relevant trigger action based on the implemented interface and trigger context. |
| global static void [setBypassReason](#setbypassreason)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) reason) | Sets an optional transaction-scoped reason string that is attached to every subsequent bypass audit log entry. |

---

## Property Details

### context

```apex
@TestVisible global TriggerOperation context
```

**Type:** [TriggerOperation](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_enum_System_TriggerOperation.htm)

The current operation type being processed by the trigger action.




Since:


Example:

### sObjectName

```apex
@TestVisible global String sObjectName
```

**Type:** [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm)

The API name of the SObject being processed by the trigger action.

Since:


Example:

### triggerNew

```apex
@TestVisible global List<SObject> triggerNew
```

**Type:** [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)

The list of "new" SObjects in the trigger context.




Since:


Example:

### triggerOld

```apex
@TestVisible global List<SObject> triggerOld
```

**Type:** [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)

The list of "old" SObjects in the trigger context.




Since:


Example:

### triggerOldMap

```apex
@TestVisible global Map<Id, SObject> triggerOldMap
```

**Type:** [Map](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_map.htm)

Map of "old" SObjects keyed by Id, for efficient field change detection in update contexts.




Since:


Example:

---

## Method Details

### bypass

<div class="apex-member">

```apex
global static void bypass(SObjectType sObjectType)
```

Bypasses trigger actions for the specified SObject type.
Type-safe overload that accepts an SObjectType token instead of a string name.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `sObjectType` | [SObjectType](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectType.htm) | The SObjectType token of the object to bypass. |

**Example**

```apex
TRG_Base.bypass(Account.SObjectType);
Boolean isBypassed = TRG_Base.isBypassed(Account.SObjectType); // true
```

</div>

<div class="apex-member">

```apex
global static void bypass(String sObjectName)
```

Bypasses trigger actions for the specified SObject type.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `sObjectName` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The API name of the SObject type to bypass. |

**Example**

```apex
TRG_Base.bypass('Account');
Boolean isBypassed = TRG_Base.isBypassed('Account'); // true
```

</div>

<div class="apex-member">

```apex
global static void bypass(String name, TRG_Base.BypassType type)
```

Bypasses a trigger by name, dispatching to the correct bypass set based on the bypass type.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `name` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The object API name or action class name to bypass |
| `type` | [TRG_Base.BypassType](TRG_Base.BypassType.md) | The bypass type (OBJECT_NAME or CLASS_NAME) |

**Example**

```apex
TRG_Base.bypass('Account', TRG_Base.BypassType.OBJECT_NAME);
TRG_Base.bypass('TRG_SetDefaults', TRG_Base.BypassType.CLASS_NAME);
```

</div>

### bypassAction

<div class="apex-member">

```apex
global static void bypassAction(String actionClassName)
```

Bypasses a specific trigger action class by name.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `actionClassName` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The class name of the trigger action to bypass. |

**Example**

```apex
TRG_Base.bypassAction('TRG_SetFoobarDefaults');
Boolean isBypassed = TRG_Base.isActionBypassed('TRG_SetFoobarDefaults'); // true
```

</div>

### clearActionBypass

<div class="apex-member">

```apex
global static void clearActionBypass(String actionClassName)
```

Clears the bypass for a specific trigger action class, allowing it to execute.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `actionClassName` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The class name of the trigger action to clear from bypass. |

**Example**

```apex
TRG_Base.bypassAction('TRG_SetFoobarDefaults');
TRG_Base.clearActionBypass('TRG_SetFoobarDefaults');
Boolean isBypassed = TRG_Base.isActionBypassed('TRG_SetFoobarDefaults'); // false
```

</div>

### clearAllActionBypasses

<div class="apex-member">

```apex
global static void clearAllActionBypasses()
```

Clears all action-level bypasses, allowing all trigger action classes to execute.

**Example**

```apex
TRG_Base.bypassAction('TRG_SetFoobarDefaults');
TRG_Base.bypassAction('TRG_ValidateFields');
TRG_Base.clearAllActionBypasses();
Boolean isBypassed = TRG_Base.isActionBypassed('TRG_SetFoobarDefaults'); // false
```

</div>

### clearAllBypasses

<div class="apex-member">

```apex
global static void clearAllBypasses()
```

Clears all SObject type bypasses, allowing all trigger actions to execute.

**Example**

```apex
TRG_Base.bypass('Account');
TRG_Base.bypass('Contact');
TRG_Base.clearAllBypasses();
Boolean isBypassed = TRG_Base.isBypassed('Account'); // false
```

</div>

<div class="apex-member">

```apex
global static void clearAllBypasses(TRG_Base.BypassType type)
```

Clears all trigger bypasses, dispatching to the correct bypass set based on the bypass type.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `type` | [TRG_Base.BypassType](TRG_Base.BypassType.md) | The bypass type (OBJECT_NAME or CLASS_NAME) |

**Example**

```apex
TRG_Base.bypass('Account', TRG_Base.BypassType.OBJECT_NAME);
TRG_Base.clearAllBypasses(TRG_Base.BypassType.OBJECT_NAME);
Boolean isBypassed = TRG_Base.isBypassed('Account'); // false
```

</div>

### clearBypass

<div class="apex-member">

```apex
global static void clearBypass(SObjectType sObjectType)
```

Clears the bypass for the specified SObject type, allowing trigger actions to execute.
Type-safe overload that accepts an SObjectType token instead of a string name.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `sObjectType` | [SObjectType](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectType.htm) | The SObjectType token of the object to clear from bypass. |

**Example**

```apex
TRG_Base.bypass(Account.SObjectType);
TRG_Base.clearBypass(Account.SObjectType);
Boolean isBypassed = TRG_Base.isBypassed(Account.SObjectType); // false
```

</div>

<div class="apex-member">

```apex
global static void clearBypass(String sObjectName)
```

Clears the bypass for the specified SObject type, allowing trigger actions to execute.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `sObjectName` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The API name of the SObject type to clear from bypass. |

**Example**

```apex
TRG_Base.bypass('Account');
TRG_Base.clearBypass('Account');
Boolean isBypassed = TRG_Base.isBypassed('Account'); // false
```

</div>

<div class="apex-member">

```apex
global static void clearBypass(String name, TRG_Base.BypassType type)
```

Clears a trigger bypass by name, dispatching to the correct bypass set based on the bypass type.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `name` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The object API name or action class name to clear |
| `type` | [TRG_Base.BypassType](TRG_Base.BypassType.md) | The bypass type (OBJECT_NAME or CLASS_NAME) |

**Example**

```apex
TRG_Base.bypass('Account', TRG_Base.BypassType.OBJECT_NAME);
TRG_Base.clearBypass('Account', TRG_Base.BypassType.OBJECT_NAME);
Boolean isBypassed = TRG_Base.isBypassed('Account'); // false
```

</div>

### isActionBypassed

<div class="apex-member">

```apex
global static Boolean isActionBypassed(String actionClassName)
```

Checks if a specific trigger action class is bypassed.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `actionClassName` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The class name of the trigger action to check. |

**Returns** [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) — Boolean True if the action class is bypassed, false otherwise.

**Example**

```apex
TRG_Base.bypassAction('TRG_SetFoobarDefaults');
Boolean isBypassed = TRG_Base.isActionBypassed('TRG_SetFoobarDefaults'); // true
```

</div>

### isBypassed

<div class="apex-member">

```apex
global static Boolean isBypassed(SObjectType sObjectType)
```

Checks if trigger actions are bypassed for the specified SObject type.
Type-safe overload that accepts an SObjectType token instead of a string name.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `sObjectType` | [SObjectType](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Schema_SObjectType.htm) | The SObjectType token of the object to check. |

**Returns** [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) — Boolean True if the SObject type is bypassed, false otherwise.

**Example**

```apex
TRG_Base.bypass(Account.SObjectType);
Boolean isBypassed = TRG_Base.isBypassed(Account.SObjectType); // true
```

</div>

<div class="apex-member">

```apex
global static Boolean isBypassed(String sObjectName)
```

Checks if trigger actions are bypassed for the specified SObject type.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `sObjectName` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The API name of the SObject type to check. |

**Returns** [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) — Boolean True if the SObject type is bypassed, false otherwise.

**Example**

```apex
TRG_Base.bypass('Account');
Boolean isBypassed = TRG_Base.isBypassed('Account'); // true
```

</div>

<div class="apex-member">

```apex
global static Boolean isBypassed(String name, TRG_Base.BypassType type)
```

Checks if a trigger is bypassed, dispatching to the correct bypass set based on the bypass type.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `name` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The object API name or action class name to check |
| `type` | [TRG_Base.BypassType](TRG_Base.BypassType.md) | The bypass type (OBJECT_NAME or CLASS_NAME) |

**Returns** [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) — True if bypassed

**Example**

```apex
TRG_Base.bypass('Account', TRG_Base.BypassType.OBJECT_NAME);
Boolean result = TRG_Base.isBypassed('Account', TRG_Base.BypassType.OBJECT_NAME); // true
```

</div>

### resolveBypassType

<div class="apex-member">

```apex
global static TRG_Base.BypassType resolveBypassType(String bypassTypeString)
```

Parses a bypass type string into the corresponding BypassType enum value.
Wraps the standard valueOf call with a user-friendly error message on failure.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `bypassTypeString` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The string to parse (must be 'OBJECT_NAME' or 'CLASS_NAME') |

**Returns** [TRG_Base.BypassType](TRG_Base.BypassType.md) — The parsed BypassType enum value

**Throws**

| Exception | Description |
|-----------|-------------|
| [System.Exception](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_classes_exception_methods.htm) | If the string does not match a valid BypassType value |

**Example**

```apex
TRG_Base.BypassType type = TRG_Base.resolveBypassType('OBJECT_NAME');
```

</div>

### run

<div class="apex-member">

```apex
global void run()
```

Executes the relevant trigger action based on the implemented interface and trigger context.
This method checks the trigger operation and calls the appropriate interface method if implemented.

**Throws**

| Exception | Description |
|-----------|-------------|
| [TypeException](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_classes_exception_methods.htm) | If the class does not implement the required interface for the current context. |
| [UTIL_Exceptions.IllegalStateException](UTIL_Exceptions.IllegalStateException.md) | If called outside of a trigger execution context. |

**Example**

```apex
public class CustomTriggerAction extends TRG_Base implements IF_Trigger.BeforeInsert
{
    public void beforeInsert(List<SObject> newRecords)
    {
        for (SObject record : newRecords)
        {
            Account accountRecord = (Account)record;
            accountRecord.Name = 'Updated Name';
        }
    }
}
// In a trigger context, calling run() will invoke beforeInsert for BEFORE_INSERT
```

</div>

### setBypassReason

<div class="apex-member">

```apex
global static void setBypassReason(String reason)
```

Sets an optional transaction-scoped reason string that is attached to every
subsequent bypass audit log entry. Use before a batch of bypass calls to document the
operational context (e.g., a data migration or incident response). Pass `null` or empty
to clear.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `reason` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The reason string to record, or null to clear the previously set reason. |

**Example**

```apex
TRG_Base.setBypassReason('Customer data migration 2026-04-19');
TRG_Base.bypass(Account.SObjectType);
TRG_Base.bypass(Contact.SObjectType);
```

</div>

