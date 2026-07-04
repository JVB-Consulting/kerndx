---
title: "DTO_BaseTable"
type: class
pageClass: reference
description: "A Data Transfer Object (DTO) class that structures webservice handler responses into a common table format, providing column and row handling for a unified data view. Supports functionality for dynami"
author: "Jason Van Beukering"
group: "Data Transfer Objects"
date: "February 2026, May 2026"
since: "1.0"
category: apex
---

# DTO_BaseTable

**Class** · Group: `Data Transfer Objects`

<div class="apex-member apex-class">

```apex
@JsonAccess(serializable='always' deserializable='always') global virtual class DTO_BaseTable extends DTO_JsonBase
```

**Extends:** [DTO_JsonBase](DTO_JsonBase.md)

A Data Transfer Object (DTO) class that structures webservice handler responses into a common table format, providing column and row handling for a unified data view. Supports functionality for dynamic column definition and row addition.

**Example**

```apex
DTO_BaseTable table = new DTO_BaseTable();
table.addColumn('Account Name', 'name', 'text', true);
table.addColumn('Revenue', 'revenue', 'currency');
table.addRow(new Map<String, Object>{'name' => 'Acme Corp', 'revenue' => 50000});
```

</div>

---

## Methods

| Method | Description |
|--------|-------------|
| global void [addColumn](#addcolumn)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) label, [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) fieldName, [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) type) | Adds a new column to the table with the specified label, field name, and type. |
| global void [addColumn](#addcolumn)([String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) label, [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) fieldName, [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) type, [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) sortable) | Adds a new column to the table with specified label, field name, type, and sortable property. |
| global void [addRow](#addrow)([Object](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_System_Object.htm) anObject) | Adds a new data row to the table. |

### addColumn

<div class="apex-member">

```apex
global void addColumn(String label, String fieldName, String type)
```

Adds a new column to the table with the specified label, field name, and type.
The column will not be sortable by default. Useful for defining table structure for row data.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `label` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The display text for the column header. |
| `fieldName` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The field name to map data from rows to this column. |
| `type` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The data type of the column (e.g., 'text', 'number'), see documentation for types here: @link https://developer.salesforce.com/docs/component-library/bundle/lightning-datatable/documentation |

**Example**

```apex
instance.addColumn('My Label', 'myName', 'value');
```

</div>

<div class="apex-member">

```apex
global void addColumn(String label, String fieldName, String type, Boolean sortable)
```

Adds a new column to the table with specified label, field name, type, and sortable
property. Supports column sorting where applicable and customizable table views.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `label` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The display text for the column header. |
| `fieldName` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The field name to map data from rows to this column. |
| `type` | [String](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_string.htm) | The data type of the column (e.g., 'text', 'number'). |
| `sortable` | [Boolean](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_boolean.htm) | A Boolean indicating if the column should support sorting. @link https://developer.salesforce.com/docs/component-library/bundle/lightning-datatable/documentation |

**Example**

```apex
instance.addColumn('My Label', 'myName', 'value', true);
```

</div>

### addRow

<div class="apex-member">

```apex
global void addRow(Object anObject)
```

Adds a new data row to the table. The data should be structured to match the
columns defined in the table. Extending classes may override this method for custom row handling.

**Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `anObject` | [Object](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_System_Object.htm) | The data object representing a row to be added to the table. |

**Example**

```apex
instance.addRow('value');
```

</div>

## Properties

| Property | Description |
|----------|-------------|
| global [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[DTO_BaseTable.DTO_Column](DTO_BaseTable.DTO_Column.md)> [columns](#columns) | Retrieves the list of columns defined in the table. |
| global [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[Object](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_System_Object.htm)> [rows](#rows) | Retrieves all rows added to the table. |

### columns

```apex
@AuraEnabled global List<DTO_BaseTable.DTO_Column> columns
```

**Type:** [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)

Retrieves the list of columns defined in the table. Each column can have a label,
field name, data type, and sortable setting. Enables access to the column
definitions for display and sorting purposes.

### rows

```apex
@AuraEnabled global List<Object> rows
```

**Type:** [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)

Retrieves all rows added to the table. Each row contains data matching the
fields and types specified in the column definitions.

## Fields

| Field | Description |
|-------|-------------|
| global transient [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[DTO_BaseTable.DTO_Column](DTO_BaseTable.DTO_Column.md)> [tableColumns](#tablecolumns) | List of table columns within this table |
| global transient [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)<[Object](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_System_Object.htm)> [tableRows](#tablerows) | List of table rows within this table |

### tableColumns

```apex
global transient List<DTO_BaseTable.DTO_Column> tableColumns
```

**Type:** [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)

List of table columns within this table

**Example**

```apex
DTO_BaseTable table = new DTO_BaseTable();
table.addColumn('Account Name', 'name', 'text', true);
table.addColumn('Revenue', 'revenue', 'currency');
List<DTO_BaseTable.DTO_Column> columns = table.tableColumns;
```

### tableRows

```apex
global transient List<Object> tableRows
```

**Type:** [List](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_methods_system_list.htm)

List of table rows within this table

**Example**

```apex
DTO_BaseTable table = new DTO_BaseTable();
table.addRow(new Map<String, Object>{'name' => 'Acme Corp', 'revenue' => 50000});
table.addRow(new Map<String, Object>{'name' => 'Global Inc', 'revenue' => 75000});
List<Object> rows = table.tableRows;
```

## Inner Classes

| Class | Description |
|-------|-------------|
| [DTO_Column](DTO_BaseTable.DTO_Column.md) | Represents a column in the DTO_BaseTable, containing properties for label, field name, type, and sorting ability. |

---

