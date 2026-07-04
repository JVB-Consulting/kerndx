---
title: "IF_TableDataSource"
type: class
description: "Generic Interface for Table data sources"
author: "Jason Van Beukering"
group: "Controllers"
date: "February 2026, May 2026"
since: "1.0"
category: apex
---

# IF_TableDataSource

**Class** · Group: `Controllers`

```apex
global interface IF_TableDataSource
```

Generic Interface for Table data sources

**Since:** 1.0

**Example:**

```apex
public class AccountTableSource implements IF_TableDataSource
{
    public DTO_BaseTable fetch(Map<String, Object> searchParameters)
    {
        DTO_BaseTable table = new DTO_BaseTable();
        table.addColumn('Name', 'name', 'text', true);
        return table;
    }
}
```

---

## Methods

| Method | Description |
|--------|-------------|
| global abstract [DTO_BaseTable](DTO_BaseTable.md) [fetch](#fetch)([Map](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_map.htm)<[String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm), [Object](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_System_Object.htm)> searchParameters) | Table datasource function to be implemented |

---

## Method Details

### fetch

```apex
global abstract DTO_BaseTable fetch(Map<String, Object> searchParameters)
```

Table datasource function to be implemented

**Parameters:**

- `searchParameters` ([Map](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_map.htm)) - Map of fetch parameters - individual implementations can expect differing parameters.

**Returns:** [DTO_BaseTable](DTO_BaseTable.md) - Table Response object. Individual implementations must all use the standard response structure.

**Since:** 1.0

