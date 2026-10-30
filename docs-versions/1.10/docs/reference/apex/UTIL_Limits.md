---
title: "UTIL_Limits"
type: class
pageClass: reference
description: "Fluent interface for inspecting Salesforce governor limits. Provides named factory methods per limit type for IDE discoverability and a LimitCheck builder for threshold and exhaustion checks."
author: "Jason Van Beukering"
group: "Utilities"
date: "April 2026, October 2026"
since: "1.0"
category: apex
---

# UTIL_Limits

**Class** · Group: `Utilities`

<div class="apex-member apex-class">

```apex
global inherited sharing class UTIL_Limits
```

Fluent interface for inspecting Salesforce governor limits. Provides named factory methods per limit type for IDE discoverability and a LimitCheck builder for threshold and exhaustion checks.

**Example**

```apex
UTIL_Limits.callouts().isExhausted();
UTIL_Limits.soqlQueries().isNearLimit(0.8);
UTIL_Limits.cpuTime().remaining();
```

</div>

---

## Methods

| Method | Description |
|--------|-------------|
| global static [UTIL_Limits.LimitCheck](UTIL_Limits.LimitCheck.md) [aggregateQueries](#aggregatequeries)() | Tracks the child subqueries run inside SOQL queries in this transaction, which the platform calls aggregate queries. |
| global static [UTIL_Limits.LimitCheck](UTIL_Limits.LimitCheck.md) [apexCursorRows](#apexcursorrows)() | Tracks the rows read through Apex cursors, as the platform reports them. |
| global static [UTIL_Limits.LimitCheck](UTIL_Limits.LimitCheck.md) [apexCursors](#apexcursors)() | Returns a LimitCheck for Apex cursors created. |
| global static [UTIL_Limits.LimitCheck](UTIL_Limits.LimitCheck.md) [apexPaginationCursorRows](#apexpaginationcursorrows)() | Tracks the rows read through Apex pagination cursors (the cursor kind built for paging a list on screen), as the platform reports them. |
| global static [UTIL_Limits.LimitCheck](UTIL_Limits.LimitCheck.md) [apexPaginationCursors](#apexpaginationcursors)() | Returns a LimitCheck for Apex pagination cursors created. |
| global static [UTIL_Limits.LimitCheck](UTIL_Limits.LimitCheck.md) [callouts](#callouts)() | Returns a LimitCheck for HTTP callouts. |
| global static [UTIL_Limits.LimitCheck](UTIL_Limits.LimitCheck.md) [cpuTime](#cputime)() | Returns a LimitCheck for CPU time (milliseconds). |
| global static [UTIL_Limits.LimitCheck](UTIL_Limits.LimitCheck.md) [dmlRows](#dmlrows)() | Tracks the records written in this transaction by insert, update, upsert, delete and undelete, added up across all statements. |
| global static [UTIL_Limits.LimitCheck](UTIL_Limits.LimitCheck.md) [dmlStatements](#dmlstatements)() | Tracks the database write statements issued in this transaction. |
| global static [UTIL_Limits.LimitCheck](UTIL_Limits.LimitCheck.md) [emailInvocations](#emailinvocations)() | Tracks the calls that send email from Apex in this transaction. |
| global static [UTIL_Limits.LimitCheck](UTIL_Limits.LimitCheck.md) [fetchCallsOnApexCursor](#fetchcallsonapexcursor)() | Returns a LimitCheck for fetch calls made on Apex cursors. |
| global static [UTIL_Limits.LimitCheck](UTIL_Limits.LimitCheck.md) [futureCalls](#futurecalls)() | Tracks the future methods (code marked to run later, in the background) that this transaction has asked the platform to run. |
| global static [UTIL_Limits.LimitCheck](UTIL_Limits.LimitCheck.md) [heapSize](#heapsize)() | Returns a LimitCheck for heap size (bytes). |
| global static [UTIL_Limits.LimitCheck](UTIL_Limits.LimitCheck.md) [mobilePushApexCalls](#mobilepushapexcalls)() | Tracks the Apex calls that send mobile push notifications in this transaction. |
| global static [UTIL_Limits.LimitCheck](UTIL_Limits.LimitCheck.md) [publishImmediateDml](#publishimmediatedml)() | Returns a LimitCheck for publish immediate DML operations. |
| global static [UTIL_Limits.LimitCheck](UTIL_Limits.LimitCheck.md) [queueableJobs](#queueablejobs)() | Tracks the Queueable jobs (background jobs) this transaction has added to the queue. |
| global static [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[UTIL_Limits.LimitCheck](UTIL_Limits.LimitCheck.md)> [snapshot](#snapshot)() | Returns a LimitCheck for every governor limit type. |
| global static [UTIL_Limits.LimitCheck](UTIL_Limits.LimitCheck.md) [soqlQueries](#soqlqueries)() | Tracks the SOQL queries issued in this transaction. |
| global static [UTIL_Limits.LimitCheck](UTIL_Limits.LimitCheck.md) [soqlQueryLocatorRows](#soqlquerylocatorrows)() | Tracks the records returned through query locators in this transaction. |
| global static [UTIL_Limits.LimitCheck](UTIL_Limits.LimitCheck.md) [soqlQueryRows](#soqlqueryrows)() | Tracks the records returned by SOQL queries in this transaction, added up across all queries. |
| global static [UTIL_Limits.LimitCheck](UTIL_Limits.LimitCheck.md) [soslQueries](#soslqueries)() | Tracks the SOSL searches issued in this transaction. |
| global static [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) [toDebugString](#todebugstring)() | Returns a human-readable summary of all governor limits in the format "Label: used of maximum". |

### aggregateQueries

<div class="apex-member">

```apex
global static UTIL_Limits.LimitCheck aggregateQueries()
```

Tracks the child subqueries run inside SOQL queries in this transaction, which the platform calls
aggregate queries. Each parent-to-child subquery counts once, against a limit separate from the SOQL query limit;
COUNT and GROUP BY queries are not what it counts.

**Returns** [UTIL_Limits.LimitCheck](UTIL_Limits.LimitCheck.md) — LimitCheck scoped to aggregate queries

</div>

### apexCursorRows

<div class="apex-member">

```apex
global static UTIL_Limits.LimitCheck apexCursorRows()
```

Tracks the rows read through Apex cursors, as the platform reports them. To track how many cursors were
created, use apexCursors.

**Returns** [UTIL_Limits.LimitCheck](UTIL_Limits.LimitCheck.md) — LimitCheck scoped to Apex cursor rows

</div>

### apexCursors

<div class="apex-member">

```apex
global static UTIL_Limits.LimitCheck apexCursors()
```

Returns a LimitCheck for Apex cursors created. The platform counts cursor creation
over a trailing 24-hour period, unlike the transaction-scoped limits in this class.

**Returns** [UTIL_Limits.LimitCheck](UTIL_Limits.LimitCheck.md) — LimitCheck scoped to Apex cursors

</div>

### apexPaginationCursorRows

<div class="apex-member">

```apex
global static UTIL_Limits.LimitCheck apexPaginationCursorRows()
```

Tracks the rows read through Apex pagination cursors (the cursor kind built for paging a list on
screen), as the platform reports them. To track how many were created, use apexPaginationCursors.

**Returns** [UTIL_Limits.LimitCheck](UTIL_Limits.LimitCheck.md) — LimitCheck scoped to Apex pagination cursor rows

</div>

### apexPaginationCursors

<div class="apex-member">

```apex
global static UTIL_Limits.LimitCheck apexPaginationCursors()
```

Returns a LimitCheck for Apex pagination cursors created. The platform counts cursor
creation over a trailing 24-hour period, unlike the transaction-scoped limits in this class.

**Returns** [UTIL_Limits.LimitCheck](UTIL_Limits.LimitCheck.md) — LimitCheck scoped to Apex pagination cursors

</div>

### callouts

<div class="apex-member">

```apex
global static UTIL_Limits.LimitCheck callouts()
```

Returns a LimitCheck for HTTP callouts.

**Returns** [UTIL_Limits.LimitCheck](UTIL_Limits.LimitCheck.md) — LimitCheck scoped to callouts

</div>

### cpuTime

<div class="apex-member">

```apex
global static UTIL_Limits.LimitCheck cpuTime()
```

Returns a LimitCheck for CPU time (milliseconds).

**Returns** [UTIL_Limits.LimitCheck](UTIL_Limits.LimitCheck.md) — LimitCheck scoped to CPU time

</div>

### dmlRows

<div class="apex-member">

```apex
global static UTIL_Limits.LimitCheck dmlRows()
```

Tracks the records written in this transaction by insert, update, upsert, delete and undelete, added
up across all statements. Check it before a large save to avoid going over the limit.

**Returns** [UTIL_Limits.LimitCheck](UTIL_Limits.LimitCheck.md) — LimitCheck scoped to DML rows

</div>

### dmlStatements

<div class="apex-member">

```apex
global static UTIL_Limits.LimitCheck dmlStatements()
```

Tracks the database write statements issued in this transaction. One statement that saves 200 records
counts once.

**Returns** [UTIL_Limits.LimitCheck](UTIL_Limits.LimitCheck.md) — LimitCheck scoped to DML statements

</div>

### emailInvocations

<div class="apex-member">

```apex
global static UTIL_Limits.LimitCheck emailInvocations()
```

Tracks the calls that send email from Apex in this transaction. One call that sends several messages
counts once.

**Returns** [UTIL_Limits.LimitCheck](UTIL_Limits.LimitCheck.md) — LimitCheck scoped to email invocations

</div>

### fetchCallsOnApexCursor

<div class="apex-member">

```apex
global static UTIL_Limits.LimitCheck fetchCallsOnApexCursor()
```

Returns a LimitCheck for fetch calls made on Apex cursors.

**Returns** [UTIL_Limits.LimitCheck](UTIL_Limits.LimitCheck.md) — LimitCheck scoped to Apex cursor fetch calls

</div>

### futureCalls

<div class="apex-member">

```apex
global static UTIL_Limits.LimitCheck futureCalls()
```

Tracks the future methods (code marked to run later, in the background) that this transaction has asked
the platform to run.

**Returns** [UTIL_Limits.LimitCheck](UTIL_Limits.LimitCheck.md) — LimitCheck scoped to future calls

</div>

### heapSize

<div class="apex-member">

```apex
global static UTIL_Limits.LimitCheck heapSize()
```

Returns a LimitCheck for heap size (bytes).

**Returns** [UTIL_Limits.LimitCheck](UTIL_Limits.LimitCheck.md) — LimitCheck scoped to heap size

</div>

### mobilePushApexCalls

<div class="apex-member">

```apex
global static UTIL_Limits.LimitCheck mobilePushApexCalls()
```

Tracks the Apex calls that send mobile push notifications in this transaction. One call that reaches
many devices counts once.

**Returns** [UTIL_Limits.LimitCheck](UTIL_Limits.LimitCheck.md) — LimitCheck scoped to mobile push Apex calls

</div>

### publishImmediateDml

<div class="apex-member">

```apex
global static UTIL_Limits.LimitCheck publishImmediateDml()
```

Returns a LimitCheck for publish immediate DML operations.

**Returns** [UTIL_Limits.LimitCheck](UTIL_Limits.LimitCheck.md) — LimitCheck scoped to publish immediate DML

</div>

### queueableJobs

<div class="apex-member">

```apex
global static UTIL_Limits.LimitCheck queueableJobs()
```

Tracks the Queueable jobs (background jobs) this transaction has added to the queue. Check isExhausted
before you add another one.

**Returns** [UTIL_Limits.LimitCheck](UTIL_Limits.LimitCheck.md) — LimitCheck scoped to queueable jobs

</div>

### snapshot

<div class="apex-member">

```apex
global static List<UTIL_Limits.LimitCheck> snapshot()
```

Returns a LimitCheck for every governor limit type.

**Returns** [UTIL_Limits.LimitCheck](UTIL_Limits.LimitCheck.md) — List of LimitCheck instances, one per limit type

**Example**

```apex
List<UTIL_Limits.LimitCheck> allLimits = UTIL_Limits.snapshot();
```

</div>

### soqlQueries

<div class="apex-member">

```apex
global static UTIL_Limits.LimitCheck soqlQueries()
```

Tracks the SOQL queries issued in this transaction. A query counts once, however many records it
returns; use soqlQueryRows to track the records.

**Returns** [UTIL_Limits.LimitCheck](UTIL_Limits.LimitCheck.md) — LimitCheck scoped to SOQL queries

</div>

### soqlQueryLocatorRows

<div class="apex-member">

```apex
global static UTIL_Limits.LimitCheck soqlQueryLocatorRows()
```

Tracks the records returned through query locators in this transaction. A query locator is the query
form that batch jobs and paged lists use to read large sets of records.

**Returns** [UTIL_Limits.LimitCheck](UTIL_Limits.LimitCheck.md) — LimitCheck scoped to SOQL query locator rows

</div>

### soqlQueryRows

<div class="apex-member">

```apex
global static UTIL_Limits.LimitCheck soqlQueryRows()
```

Tracks the records returned by SOQL queries in this transaction, added up across all queries.

**Returns** [UTIL_Limits.LimitCheck](UTIL_Limits.LimitCheck.md) — LimitCheck scoped to SOQL query rows

</div>

### soslQueries

<div class="apex-member">

```apex
global static UTIL_Limits.LimitCheck soslQueries()
```

Tracks the SOSL searches issued in this transaction. A SOSL search is a text search across several
objects at once.

**Returns** [UTIL_Limits.LimitCheck](UTIL_Limits.LimitCheck.md) — LimitCheck scoped to SOSL queries

</div>

### toDebugString

<div class="apex-member">

```apex
global static String toDebugString()
```

Returns a human-readable summary of all governor limits in the format "Label: used of maximum".

**Returns** [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) — Multi-line string with one line per limit type

**Example**

```apex
String limitsDebug = UTIL_Limits.toDebugString();
```

</div>

## Inner Classes

| Class | Description |
|-------|-------------|
| [LimitCheck](UTIL_Limits.LimitCheck.md) | Fluent limit inspector scoped to a single governor limit type. |

---

