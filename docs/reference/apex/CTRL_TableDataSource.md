---
title: "CTRL_TableDataSource"
type: class
pageClass: reference
description: "Controller class responsible for managing the instantiation of a data source class that supports the table data source interface. This controller allows fetching table data from dynamically specified "
author: "Jason Van Beukering"
group: "Controllers"
date: "February 2026, May 2026"
since: "1.0"
category: apex
---

# CTRL_TableDataSource

**Class** · Group: `Controllers`

```apex
global inherited sharing class CTRL_TableDataSource
```

Controller class responsible for managing the instantiation of a data source class that supports the table data source interface. This controller allows fetching table data from dynamically specified classes, providing flexible table-based data retrieval capabilities.

**Since:** 1.0

**Example:**

```apex
DTO_BaseTable result = CTRL_TableDataSource.fetch(
    'AccountTableSource',
    new Map<String, Object>{'industry' => 'Technology'}
);
```

**See Also:** [IF_TableDataSource](IF_TableDataSource.md)

---

## Methods

| Method | Description |
|--------|-------------|
| global static [DTO_BaseTable](DTO_BaseTable.md) [fetch](#fetch)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) controllerName, [Map](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_map.htm)<[String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm), [Object](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_System_Object.htm)> searchParameters) | Dynamically creates an instance of a specified table data source controller and retrieves data based on the provided search parameters. |

---

## Method Details

### fetch

<div class="apex-member">

```apex
@AuraEnabled global static DTO_BaseTable fetch(String controllerName, Map<String, Object> searchParameters)
```

Dynamically creates an instance of a specified table data source controller and retrieves
data based on the provided search parameters. The class specified by `controllerName` must implement
the `IF_TableDataSource` interface.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `controllerName` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The fully qualified class name of the data source controller to instantiate. The class must implement the IF_TableDataSource interface. |
| `searchParameters` | [Map](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_map.htm) | A map of search parameters, where each key-value pair specifies a criterion or filter to apply to the data source. |

**Returns** [DTO_BaseTable](DTO_BaseTable.md) — A `DTO_BaseTable` object containing the search results formatted as a table.

**Example**

```apex
DTO_BaseTable result = CTRL_TableDataSource.fetch('MyDataSource', new Map<String, Object>{'key' => 'value'});
```

</div>

