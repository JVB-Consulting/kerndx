// SPDX-License-Identifier: BUSL-1.1
/**
 * @description A Data Transfer Object (DTO) class that structures webservice handler responses
 * into a common table format, providing column and row handling for a unified data view.
 * Supports functionality for dynamic column definition and row addition.
 *
 * @see DTO_BaseTable_TEST
 *
 * @author Jason van Beukering
 *
 * @group Data Transfer Objects
 *
 * @date February 2026, May 2026
 *
 * @since 1.0
 *
 * @example
 * ```apex
 * DTO_BaseTable table = new DTO_BaseTable();
 * table.addColumn('Account Name', 'name', 'text', true);
 * table.addColumn('Revenue', 'revenue', 'currency');
 * table.addRow(new Map<String, Object>{'name' => 'Acme Corp', 'revenue' => 50000});
 * ```
 */
@SuppressWarnings('PMD.AvoidGlobalModifier,PMD.AvoidBooleanMethodParameters')
@JsonAccess(Serializable='always' Deserializable='always')
global virtual class DTO_BaseTable extends DTO_JsonBase
{
	/**
	 * @description List of table columns within this table
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * DTO_BaseTable table = new DTO_BaseTable();
	 * table.addColumn('Account Name', 'name', 'text', true);
	 * table.addColumn('Revenue', 'revenue', 'currency');
	 * List<DTO_BaseTable.DTO_Column> columns = table.tableColumns;
	 * ```
	 */
	global transient protected List<DTO_Column> tableColumns;
	/**
	 * @description List of table rows within this table
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * DTO_BaseTable table = new DTO_BaseTable();
	 * table.addRow(new Map<String, Object>{'name' => 'Acme Corp', 'revenue' => 50000});
	 * table.addRow(new Map<String, Object>{'name' => 'Global Inc', 'revenue' => 75000});
	 * List<Object> rows = table.tableRows;
	 * ```
	 */
	global transient protected List<Object> tableRows = new List<Object>();

	/**
	 * @description Retrieves the list of columns defined in the table. Each column can have a label,
	 * field name, data type, and sortable setting. Enables access to the column
	 * definitions for display and sorting purposes.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * List<DTO_Column> value = instance.columns;
	 * ```
	 */
	@AuraEnabled
	global List<DTO_Column> columns
	{
		get
		{
			return tableColumns;
		}
	}

	/**
	 * @description Retrieves all rows added to the table. Each row contains data matching the
	 * fields and types specified in the column definitions.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * List<Object> value = instance.rows;
	 * ```
	 */
	@AuraEnabled
	global List<Object> rows
	{
		get
		{
			return tableRows;
		}
	}

	/**
	 * @description Adds a new column to the table with the specified label, field name, and type.
	 * The column will not be sortable by default. Useful for defining table structure for row data.
	 *
	 * @param label The display text for the column header.
	 * @param fieldName The field name to map data from rows to this column.
	 * @param type The data type of the column (e.g., 'text', 'number'), see documentation for types here:
	 *
	 * @link https://developer.salesforce.com/docs/component-library/bundle/lightning-datatable/documentation
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * instance.addColumn('My Label', 'myName', 'value');
	 * ```
	 */
	global void addColumn(String label, String fieldName, String type)
	{
		addColumn(label, fieldName, type, false);
	}

	/**
	 * @description Adds a new column to the table with specified label, field name, type, and sortable
	 * property. Supports column sorting where applicable and customizable table views.
	 *
	 * @param label The display text for the column header.
	 * @param fieldName The field name to map data from rows to this column.
	 * @param type The data type of the column (e.g., 'text', 'number').
	 * @param sortable A Boolean indicating if the column should support sorting.
	 *
	 * @link https://developer.salesforce.com/docs/component-library/bundle/lightning-datatable/documentation
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * instance.addColumn('My Label', 'myName', 'value', true);
	 * ```
	 */
	global void addColumn(String label, String fieldName, String type, Boolean sortable)
	{
		if(tableColumns == null)
		{
			tableColumns = new List<DTO_Column>();
		}

		DTO_Column column = new DTO_Column();

		column.label = label;
		column.fieldName = fieldName;
		column.type = type;
		column.sortable = sortable;

		tableColumns.add(column);
	}

	/**
	 * @description Adds a new data row to the table. The data should be structured to match the
	 * columns defined in the table. Extending classes may override this method for custom row handling.
	 *
	 * @param anObject The data object representing a row to be added to the table.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * instance.addRow('value');
	 * ```
	 */
	global void addRow(Object anObject)
	{
		tableRows.add(anObject);
	}

	/**
	 * @description Represents a column in the `DTO_BaseTable`, containing properties for label,
	 * field name, type, and sorting ability. This nested class provides structure
	 * for defining table columns.n
	 *
	 * @since 1.0
	 */
	global inherited sharing class DTO_Column
	{
		/**
		 * @description Column Label
		 */
		@AuraEnabled
		public String label;
		/**
		 * @description Which row field should be displayed for this column
		 */
		@AuraEnabled
		public String fieldName;
		/**
		 * @description Column type
		 */
		@AuraEnabled
		public String type;
		/**
		 * @description Indicates if column should be sortable
		 */
		@AuraEnabled
		public Boolean sortable;
	}
}