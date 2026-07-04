---
title: "UTIL_Limits"
type: class
description: "Fluent interface for inspecting Salesforce governor limits. Provides named factory methods per limit type for IDE discoverability and a LimitCheck builder for threshold and exhaustion checks."
author: "Jason Van Beukering"
group: "Utilities"
date: "April 2026, May 2026"
since: "1.0"
category: apex
---

# UTIL_Limits

**Class** · Group: `Utilities`

```apex
global inherited sharing class UTIL_Limits
```

Fluent interface for inspecting Salesforce governor limits. Provides named factory methods per limit type for IDE discoverability and a LimitCheck builder for threshold and exhaustion checks.

**Since:** 1.0

**Example:**

```apex
UTIL_Limits.callouts().isExhausted();
UTIL_Limits.soqlQueries().isNearLimit(0.8);
UTIL_Limits.cpuTime().remaining();
```

---

## Methods

| Method | Description |
|--------|-------------|
| global static [UTIL_Limits.LimitCheck](UTIL_Limits.LimitCheck.md) [aggregateQueries](#aggregatequeries)() | Returns a LimitCheck for aggregate queries. |
| global static [UTIL_Limits.LimitCheck](UTIL_Limits.LimitCheck.md) [callouts](#callouts)() | Returns a LimitCheck for HTTP callouts. |
| global static [UTIL_Limits.LimitCheck](UTIL_Limits.LimitCheck.md) [cpuTime](#cputime)() | Returns a LimitCheck for CPU time (milliseconds). |
| global static [UTIL_Limits.LimitCheck](UTIL_Limits.LimitCheck.md) [dmlRows](#dmlrows)() | Returns a LimitCheck for DML rows. |
| global static [UTIL_Limits.LimitCheck](UTIL_Limits.LimitCheck.md) [dmlStatements](#dmlstatements)() | Returns a LimitCheck for DML statements. |
| global static [UTIL_Limits.LimitCheck](UTIL_Limits.LimitCheck.md) [emailInvocations](#emailinvocations)() | Returns a LimitCheck for email invocations. |
| global static [UTIL_Limits.LimitCheck](UTIL_Limits.LimitCheck.md) [futureCalls](#futurecalls)() | Returns a LimitCheck for future calls. |
| global static [UTIL_Limits.LimitCheck](UTIL_Limits.LimitCheck.md) [heapSize](#heapsize)() | Returns a LimitCheck for heap size (bytes). |
| global static [UTIL_Limits.LimitCheck](UTIL_Limits.LimitCheck.md) [mobilePushApexCalls](#mobilepushapexcalls)() | Returns a LimitCheck for mobile push Apex calls. |
| global static [UTIL_Limits.LimitCheck](UTIL_Limits.LimitCheck.md) [publishImmediateDml](#publishimmediatedml)() | Returns a LimitCheck for publish immediate DML operations. |
| global static [UTIL_Limits.LimitCheck](UTIL_Limits.LimitCheck.md) [queueableJobs](#queueablejobs)() | Returns a LimitCheck for queueable jobs. |
| global static [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm) [snapshot](#snapshot)() | Returns a LimitCheck for every governor limit type. |
| global static [UTIL_Limits.LimitCheck](UTIL_Limits.LimitCheck.md) [soqlQueries](#soqlqueries)() | Returns a LimitCheck for SOQL queries. |
| global static [UTIL_Limits.LimitCheck](UTIL_Limits.LimitCheck.md) [soqlQueryLocatorRows](#soqlquerylocatorrows)() | Returns a LimitCheck for SOQL query locator rows. |
| global static [UTIL_Limits.LimitCheck](UTIL_Limits.LimitCheck.md) [soqlQueryRows](#soqlqueryrows)() | Returns a LimitCheck for SOQL query rows. |
| global static [UTIL_Limits.LimitCheck](UTIL_Limits.LimitCheck.md) [soslQueries](#soslqueries)() | Returns a LimitCheck for SOSL queries. |
| global static [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [toDebugString](#todebugstring)() | Returns a human-readable summary of all governor limits in the format "Label: used of maximum". |

## Inner Classes

| Class | Description |
|-------|-------------|
| [LimitCheck](UTIL_Limits.LimitCheck.md) | Fluent limit inspector scoped to a single governor limit type. |

---

## Method Details

### aggregateQueries

```apex
global static UTIL_Limits.LimitCheck aggregateQueries()
```

Returns a LimitCheck for aggregate queries.

**Returns:** [UTIL_Limits.LimitCheck](UTIL_Limits.LimitCheck.md) - LimitCheck scoped to aggregate queries

**Since:** 1.0

### callouts

```apex
global static UTIL_Limits.LimitCheck callouts()
```

Returns a LimitCheck for HTTP callouts.

**Returns:** [UTIL_Limits.LimitCheck](UTIL_Limits.LimitCheck.md) - LimitCheck scoped to callouts

**Since:** 1.0

### cpuTime

```apex
global static UTIL_Limits.LimitCheck cpuTime()
```

Returns a LimitCheck for CPU time (milliseconds).

**Returns:** [UTIL_Limits.LimitCheck](UTIL_Limits.LimitCheck.md) - LimitCheck scoped to CPU time

**Since:** 1.0

### dmlRows

```apex
global static UTIL_Limits.LimitCheck dmlRows()
```

Returns a LimitCheck for DML rows.

**Returns:** [UTIL_Limits.LimitCheck](UTIL_Limits.LimitCheck.md) - LimitCheck scoped to DML rows

**Since:** 1.0

### dmlStatements

```apex
global static UTIL_Limits.LimitCheck dmlStatements()
```

Returns a LimitCheck for DML statements.

**Returns:** [UTIL_Limits.LimitCheck](UTIL_Limits.LimitCheck.md) - LimitCheck scoped to DML statements

**Since:** 1.0

### emailInvocations

```apex
global static UTIL_Limits.LimitCheck emailInvocations()
```

Returns a LimitCheck for email invocations.

**Returns:** [UTIL_Limits.LimitCheck](UTIL_Limits.LimitCheck.md) - LimitCheck scoped to email invocations

**Since:** 1.0

### futureCalls

```apex
global static UTIL_Limits.LimitCheck futureCalls()
```

Returns a LimitCheck for future calls.

**Returns:** [UTIL_Limits.LimitCheck](UTIL_Limits.LimitCheck.md) - LimitCheck scoped to future calls

**Since:** 1.0

### heapSize

```apex
global static UTIL_Limits.LimitCheck heapSize()
```

Returns a LimitCheck for heap size (bytes).

**Returns:** [UTIL_Limits.LimitCheck](UTIL_Limits.LimitCheck.md) - LimitCheck scoped to heap size

**Since:** 1.0

### mobilePushApexCalls

```apex
global static UTIL_Limits.LimitCheck mobilePushApexCalls()
```

Returns a LimitCheck for mobile push Apex calls.

**Returns:** [UTIL_Limits.LimitCheck](UTIL_Limits.LimitCheck.md) - LimitCheck scoped to mobile push Apex calls

**Since:** 1.0

### publishImmediateDml

```apex
global static UTIL_Limits.LimitCheck publishImmediateDml()
```

Returns a LimitCheck for publish immediate DML operations.

**Returns:** [UTIL_Limits.LimitCheck](UTIL_Limits.LimitCheck.md) - LimitCheck scoped to publish immediate DML

**Since:** 1.0

### queueableJobs

```apex
global static UTIL_Limits.LimitCheck queueableJobs()
```

Returns a LimitCheck for queueable jobs.

**Returns:** [UTIL_Limits.LimitCheck](UTIL_Limits.LimitCheck.md) - LimitCheck scoped to queueable jobs

**Since:** 1.0

### snapshot

```apex
global static List<UTIL_Limits.LimitCheck> snapshot()
```

Returns a LimitCheck for every governor limit type.

**Returns:** [UTIL_Limits.LimitCheck](UTIL_Limits.LimitCheck.md) - List of LimitCheck instances, one per limit type

**Since:** 1.0

**Example:**

```apex
List<UTIL_Limits.LimitCheck> allLimits = UTIL_Limits.snapshot();
```

### soqlQueries

```apex
global static UTIL_Limits.LimitCheck soqlQueries()
```

Returns a LimitCheck for SOQL queries.

**Returns:** [UTIL_Limits.LimitCheck](UTIL_Limits.LimitCheck.md) - LimitCheck scoped to SOQL queries

**Since:** 1.0

### soqlQueryLocatorRows

```apex
global static UTIL_Limits.LimitCheck soqlQueryLocatorRows()
```

Returns a LimitCheck for SOQL query locator rows.

**Returns:** [UTIL_Limits.LimitCheck](UTIL_Limits.LimitCheck.md) - LimitCheck scoped to SOQL query locator rows

**Since:** 1.0

### soqlQueryRows

```apex
global static UTIL_Limits.LimitCheck soqlQueryRows()
```

Returns a LimitCheck for SOQL query rows.

**Returns:** [UTIL_Limits.LimitCheck](UTIL_Limits.LimitCheck.md) - LimitCheck scoped to SOQL query rows

**Since:** 1.0

### soslQueries

```apex
global static UTIL_Limits.LimitCheck soslQueries()
```

Returns a LimitCheck for SOSL queries.

**Returns:** [UTIL_Limits.LimitCheck](UTIL_Limits.LimitCheck.md) - LimitCheck scoped to SOSL queries

**Since:** 1.0

### toDebugString

```apex
global static String toDebugString()
```

Returns a human-readable summary of all governor limits in the format "Label: used of maximum".

**Returns:** [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) - Multi-line string with one line per limit type

**Since:** 1.0

**Example:**

```apex
String limitsDebug = UTIL_Limits.toDebugString();
```

