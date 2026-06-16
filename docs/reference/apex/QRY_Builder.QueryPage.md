---
title: "QRY_Builder.QueryPage"
type: class
description: "Result container for paged queries, providing records and pagination metadata."
since: "1.0"
category: apex
---

# QRY_Builder.QueryPage

**Class**

```apex
global class QRY_Builder.QueryPage
```

Result container for paged queries, providing records and pagination metadata.

**Since:** 1.0

---

## Properties

| Property | Description |
|----------|-------------|
| global [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) [hasMorePages](#hasmorepages) | True if there are more pages after the current page. |
| global [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) [hasPriorPages](#haspriorpages) | True if there are pages before the current page. |
| global [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) [totalPages](#totalpages) | Total number of pages available. |

## Fields

| Field | Description |
|-------|-------------|
| global [Database.PaginationCursor](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Database_PaginationCursor.htm) [cursor](#cursor) | The PaginationCursor state for LWC round-trips. |
| global [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) [deletedRecords](#deletedrecords) | Number of records deleted since the cursor was created. |
| global [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) [pageNumber](#pagenumber) | The current page number (1-based). |
| global [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) [pageSize](#pagesize) | Number of records per page. |
| global [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[SObject](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_sobject.htm)> [records](#records) | The records for the requested page. |
| global [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm) [totalRecords](#totalrecords) | Total number of records matching the query criteria. |

---

## Property Details

### hasMorePages

```apex
global Boolean hasMorePages
```

**Type:** [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm)

True if there are more pages after the current page.

Since:


Example:

### hasPriorPages

```apex
global Boolean hasPriorPages
```

**Type:** [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm)

True if there are pages before the current page.

Since:


Example:

### totalPages

```apex
global Integer totalPages
```

**Type:** [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm)

Total number of pages available.

Since:


Example:

---

## Field Details

### cursor

```apex
global Database.PaginationCursor cursor
```

**Type:** [Database.PaginationCursor](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Database_PaginationCursor.htm)

The PaginationCursor state for LWC round-trips.
Can be passed back to the server for stable pagination across requests.

**Since:** 1.0

**Example:**

```apex
QRY_Builder.QueryPage page = QRY_Builder.selectFrom(Account.SObjectType)
    .getPage(1, 25);
Database.PaginationCursor cursor = page.cursor;
```

### deletedRecords

```apex
global Integer deletedRecords
```

**Type:** [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm)

Number of records deleted since the cursor was created.
Useful for detecting data changes between page fetches.

**Since:** 1.0

**Example:**

```apex
QRY_Builder.QueryPage page = QRY_Builder.selectFrom(Account.SObjectType)
    .getPage(1, 25);
Integer deleted = page.deletedRecords;
```

### pageNumber

```apex
global Integer pageNumber
```

**Type:** [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm)

The current page number (1-based).

**Since:** 1.0

**Example:**

```apex
QRY_Builder.QueryPage page = QRY_Builder.selectFrom(Account.SObjectType)
    .getPage(2, 25);
Integer currentPage = page.pageNumber; // 2
```

### pageSize

```apex
global Integer pageSize
```

**Type:** [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm)

Number of records per page.

**Since:** 1.0

**Example:**

```apex
QRY_Builder.QueryPage page = QRY_Builder.selectFrom(Account.SObjectType)
    .getPage(1, 25);
Integer size = page.pageSize; // 25
```

### records

```apex
global List<SObject> records
```

**Type:** [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)

The records for the requested page.

**Since:** 1.0

**Example:**

```apex
QRY_Builder.QueryPage page = QRY_Builder.selectFrom(Account.SObjectType)
    .getPage(1, 25);
List<SObject> pageRecords = page.records;
```

### totalRecords

```apex
global Integer totalRecords
```

**Type:** [Integer](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_integer.htm)

Total number of records matching the query criteria.

**Since:** 1.0

**Example:**

```apex
QRY_Builder.QueryPage page = QRY_Builder.selectFrom(Account.SObjectType)
    .getPage(1, 25);
Integer total = page.totalRecords;
```

